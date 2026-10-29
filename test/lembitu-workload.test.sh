#!/usr/bin/env bash
# The Workload, ./workloads/lembitu (#114): rendered the way the fleet renders it, then started.
#
#   bash test/lembitu-workload.test.sh
#
# Two tiers.
#
# The render tier runs on every `for t in test/*.test.sh` pass. It commits the working tree into a
# scratch repository, because the fleet renders a commit and never a working tree, and renders it
# with astral-fleet's own project-workload-delivery (its workload-shape package), which also applies
# the fleet's Project rules: the kinds, the namespace, digest pins, priority classes, claim labels
# and the flux schema. Then it checks the render's fields:
#   - the StatefulSet's shape (#114 and the SPEC's item A3): one OrderedReady replica on astral-bicep,
#     fleet-games, a 180 s grace, no API token, the image by digest in the fleet registry;
#   - Guaranteed QoS (3 CPU, 6Gi) and Pod Security `restricted`, with uid, gid and fsGroup 10160,
#     the image's user;
#   - the ports, the labels, the probes (an exec lembitu-ready readiness probe, a 15-minute startup
#     probe, no liveness probe), the Secret's mode and the mounts at the entrypoint's defaults;
#   - the claim template, and that the ConfigMaps rebuild config/enforced and config/dedicated byte
#     for byte;
#   - against the fleet's own side of the contract, read from the same fleet revision: the Services'
#     selectors and target ports, the NetworkPolicy's selector and ports, the PersistentVolume's
#     pre-bound claim, class, size and path, the registration's stage and the namespace's Pod Security;
#   - lembitu-secrets.sops.yaml is listed in the kustomization exactly when it is sealed.
# It needs nix and network access to the fleet's repository (LEMBITU_FLEET_FLAKE, default its dev
# branch); jq and yq come from nix when they aren't on PATH. Without nix it says "skip".
#
# The image tier starts the pinned image the way the render says, on the committed fixture world in
# test/fixtures/lembitu-world (a world this image generated on 2026-10-27, never a copy of
# LembituRun's save). It is opt-in, LEMBITU_IMAGE_TEST=1, and needs rootless docker, about 4 GB of
# memory and about ten minutes. LEMBITU_BUILD_LOCK, if set, is a lock file for the nix build. It
# checks:
#   - the image .#serverImage builds is the digest the StatefulSet pins;
#   - readiness, by the render's own probe command, turns green within the startup probe's budget;
#   - the fixture world is the one that loads, with SeparateSpawns' stored layout from the volume;
#   - every overlay entry is in effect in the running config (scripts/verify-enforced-config.sh), a
#     key only the overlay sets is in the file the mod wrote back, and SeparateSpawns reads its
#     config and roster from its root on the volume;
#   - the map answers GET / with 200, the public route's probe;
#   - SIGTERM, with the render's grace period, saves a fresh generation and the server exits 0.
# LEMBITU_WORKLOAD_REPORT, if set, names a directory that receives the render, the logs and the
# timings.

# The jq programs are single-quoted on purpose: their $names are jq's own.
# shellcheck disable=SC2016
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="$REPO_ROOT/scripts/server-entrypoint.sh"
FLEET="${LEMBITU_FLEET_FLAKE:-git+https://github.com/rakoort/astral-fleet?ref=dev}"
PROJECT=valheim-lembitu
NAMESPACE="project-$PROJECT"

WORK="$(mktemp -d)"
cleanup() {
  local status=$?
  if [[ -f "$WORK/containers" ]]; then
    while read -r name; do docker rm -f "$name" >/dev/null 2>&1 || true; done < "$WORK/containers"
  fi
  if [[ -f "$WORK/volumes" ]]; then
    while read -r name; do docker volume rm "$name" >/dev/null 2>&1 || true; done < "$WORK/volumes"
  fi
  # A directory the container wrote into holds files of its user, which only a container's root can
  # delete under rootless docker; a throwaway busybox empties it.
  if [[ -f "$WORK/bind-dirs" ]]; then
    while read -r dir; do docker run --rm -v "$dir:/x" busybox:1.37 find /x -mindepth 1 -delete >/dev/null 2>&1 || true; done < "$WORK/bind-dirs"
  fi
  if [[ -f "$WORK/images" ]]; then
    while read -r name; do docker rmi "$name" >/dev/null 2>&1 || true; done < "$WORK/images"
  fi
  chmod -R u+w "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT INT TERM

pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@"; then report ok "$what"; else report fail "$what"; fi
}
finish() { printf '\n%d passed, %d failed\n' "$pass" "$fail"; [[ $fail -eq 0 ]]; }

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: the Workload's render needs nix (the fleet's project-workload-delivery)"
  finish; exit
fi
tool() {  # tool <command> <nixpkgs attribute>: the command on PATH, else from nix
  command -v "$1" 2>/dev/null || printf '%s/bin/%s\n' "$(nix build --no-link --print-out-paths "nixpkgs#$2^out")" "$1"
}
JQ="$(tool jq jq)"
YQ="$(tool yq yq-go)"
jq() { "$JQ" "$@"; }
jqe() { "$JQ" -e "$@" > /dev/null; }  # jqe <jq test> <file>: true when it holds

# --- the render ---------------------------------------------------------------------------------

SHAPE="$(nix build --no-link --print-out-paths "$FLEET#workload-shape")" \
  || { echo "error: cannot build the fleet's workload-shape from $FLEET" >&2; exit 2; }
FLEET_SRC="$(nix flake metadata --json "$FLEET" | jq -r .path)"
REGISTRY="$(sed -n "s/^export FLEET_REGISTRY=//p" "$SHAPE/bin/project-workload-delivery" | tr -d "'")"
REPORT="${LEMBITU_WORKLOAD_REPORT:-$WORK/report}"
mkdir -p "$REPORT"

# The working tree, tracked and untracked files alike (not ignored ones), as one commit.
CHECKOUT="$WORK/checkout"
mkdir -p "$CHECKOUT"
(cd "$REPO_ROOT" && git ls-files -z --cached --others --exclude-standard | xargs -0 cp --parents -t "$CHECKOUT")
git -C "$CHECKOUT" init -q
git -C "$CHECKOUT" add -A
git -C "$CHECKOUT" -c user.name=test -c user.email=test@localhost -c commit.gpgsign=false commit -q -m snapshot
render() {
  "$SHAPE/bin/project-workload-delivery" "$CHECKOUT" "$PROJECT" ./workloads/lembitu > "$REPORT/render.yaml" 2> "$WORK/render.err"
}
what="the fleet's project-workload-delivery renders ./workloads/lembitu, and its Project rules pass"
if ! render; then
  report fail "$what"
  cat "$WORK/render.err"
  finish; exit
fi
report ok "$what"
"$YQ" ea -o=json -I0 '[.]' "$REPORT/render.yaml" > "$WORK/render.json"
jq '.[] | select(.kind == "StatefulSet")' "$WORK/render.json" > "$WORK/sts.json"
sts() { jq -e "$1" "$WORK/sts.json" > /dev/null; }  # sts <jq test>: true when it holds of the StatefulSet
pod() { sts ".spec.template.spec | $1"; }
server() { sts ".spec.template.spec.containers[0] | $1"; }

check "the render is one StatefulSet, its three ConfigMaps and the sealed Secret lembitu-secrets, nothing else" \
  jqe '([.[].kind] | sort == ["ConfigMap", "ConfigMap", "ConfigMap", "Secret", "StatefulSet"])
    and ([.[] | select(.kind == "Secret") | .metadata.name] == ["lembitu-secrets"])' "$WORK/render.json"
check "StatefulSet lembitu: one replica, OrderedReady" \
  sts '.metadata.name == "lembitu" and .spec.replicas == 1 and .spec.podManagementPolicy == "OrderedReady"'
check "on astral-bicep, at priority fleet-games, with a 180 s grace and no API token" \
  pod '.nodeSelector == {"kubernetes.io/hostname": "astral-bicep"} and .priorityClassName == "fleet-games"
    and .terminationGracePeriodSeconds == 180 and .automountServiceAccountToken == false'
check "one container, no init container, the image pinned by digest in the fleet registry's project path" \
  pod "(.containers | length) == 1 and (has(\"initContainers\") | not)
    and (.containers[0].image | test(\"^\" + (\"$REGISTRY/project/$PROJECT/server@sha256:\" | gsub(\"\\\\.\"; \"\\\\.\")) + \"[0-9a-f]{64}\$\"))"
check "Guaranteed QoS: requests equal limits, 3 CPU and 6Gi" \
  pod 'all(.containers[]; .resources.requests == .resources.limits) and .containers[0].resources.limits == {"cpu": "3", "memory": "6Gi"}'

image_user="$(sed -n 's/^ *User = "\([0-9]*\):\([0-9]*\)";$/\1 \2/p' "$REPO_ROOT/nix/server-image.nix")"
check "uid, gid and fsGroup 10160, the image's user ($image_user)" \
  pod ".securityContext.runAsUser == 10160 and .securityContext.runAsGroup == 10160 and .securityContext.fsGroup == 10160
    and \"$image_user\" == \"10160 10160\""
# Pod Security's restricted profile, rule by rule (kubernetes.io/docs/concepts/security/pod-security-standards).
check "Pod Security restricted: non-root, RuntimeDefault seccomp, no escalation, every capability dropped" \
  pod '.securityContext.runAsNonRoot == true and .securityContext.seccompProfile.type == "RuntimeDefault"
    and all(.containers[]; .securityContext.allowPrivilegeEscalation == false
      and (.securityContext.capabilities.drop | index("ALL"))
      and ((.securityContext.capabilities.add // []) - ["NET_BIND_SERVICE"] | length == 0)
      and (.securityContext.privileged // false) == false and (.securityContext.runAsUser // 1) != 0)'
check "Pod Security restricted: no host namespaces, host ports or volume types outside the profile's" \
  pod '(.hostNetwork // false) == false and (.hostPID // false) == false and (.hostIPC // false) == false
    and all(.containers[].ports[]; has("hostPort") | not)
    and all(.volumes[]; keys - ["name"] | .[0] | IN("configMap", "emptyDir", "projected", "secret", "persistentVolumeClaim", "ephemeral", "downwardAPI", "csi"))'
check "a read-only root, as the image tier ran it" server '.securityContext.readOnlyRootFilesystem == true'
check "ports game 2456/UDP, query 2457/UDP and map 3000/TCP" \
  server '[.ports[] | [.name, .containerPort, .protocol]] == [["game", 2456, "UDP"], ["query", 2457, "UDP"], ["map", 3000, "TCP"]]'
check "the Pod's labels: app.kubernetes.io/name and fleet.astral.ee/egress, both lembitu; the selector is the first" \
  sts '.spec.template.metadata.labels == {"app.kubernetes.io/name": "lembitu", "fleet.astral.ee/egress": "lembitu"}
    and .spec.selector.matchLabels == {"app.kubernetes.io/name": "lembitu"}'
check "readiness is an exec of lembitu-ready, and no liveness probe could restart a saving server" \
  server '.readinessProbe.exec.command == ["lembitu-ready"] and (has("livenessProbe") | not)'
check "the startup probe runs lembitu-ready for 15 minutes before readiness takes over" \
  server '.startupProbe.exec.command == ["lembitu-ready"] and .startupProbe.periodSeconds * .startupProbe.failureThreshold == 900'

# The mounts are where the entrypoint and the image look by default.
default_of() { sed -n "s|^[A-Z_]*=\${$1:-\(.*\)}\$|\1|p" "$ENTRYPOINT"; }
mount_of() { jq -r --arg v "$1" '.spec.template.spec.containers[0].volumeMounts[] | select(.name == $v) | .mountPath' "$WORK/sts.json"; }
volume_of() { jq -c --arg v "$1" '.spec.template.spec.volumes[] | select(.name == $v)' "$WORK/sts.json"; }
password_file="$(default_of LEMBITU_PASSWORD_FILE)"
image_home="$(sed -n 's/^ *"HOME=\(.*\)"$/\1/p' "$REPO_ROOT/nix/server-image.nix")"
mounts_ok() {
  [[ "$(mount_of world)" == "$(default_of LEMBITU_DATA)" && "$(mount_of runtime)" == "$(default_of LEMBITU_RUNTIME)" \
    && "$(mount_of config)" == "$(default_of LEMBITU_CONFIG)" && "$(mount_of dedicated)" == "$(default_of LEMBITU_DEDICATED_CONFIG)" \
    && "$(mount_of secrets)" == "$(dirname "$password_file")" && "$(mount_of home)" == "$image_home" && "$(mount_of tmp)" == /tmp ]] \
    && jq -e '[.spec.template.spec.containers[0].volumeMounts[] | select(.name == "config" or .name == "dedicated" or .name == "secrets") | .readOnly] == [true, true, true]' "$WORK/sts.json" > /dev/null
}
check "the world, runtime, config, SeparateSpawns config and Secret mount where the entrypoint looks; HOME and /tmp too" mounts_ok
check "the runtime tree, HOME and /tmp are emptyDirs" \
  bash -c "for v in runtime home tmp; do [[ \$('$JQ' -c --arg v \$v '.spec.template.spec.volumes[] | select(.name == \$v) | .emptyDir' '$WORK/sts.json') == '{}' ]] || exit 1; done"
secret_volume_ok() {
  jqe --arg p "$(basename "$password_file")" \
    '(.spec.template.spec.volumes[] | select(.name == "secrets") | .secret)
      == {secretName: "lembitu-secrets", defaultMode: 256, items: [{key: "password", path: $p}]}
    and .spec.template.spec.containers[0].env
      == [{name: "SERVERMANAGER_DISCORD_BOT_TOKEN", valueFrom: {secretKeyRef: {name: "lembitu-secrets", key: "discord-bot-token"}}}]' \
    "$WORK/sts.json"
}
check "the Secret lembitu-secrets gives the password file, mode 0400, and ServerManager's bot token" secret_volume_ok
SECRET_FILE="$REPO_ROOT/workloads/lembitu/lembitu-secrets.sops.yaml"
sealed_ok() {
  "$YQ" -o=json -I0 '.' "$SECRET_FILE" > "$WORK/secret.json"
  jqe '.metadata.name == "lembitu-secrets" and (.stringData | keys) == ["discord-bot-token", "password"]
    and all(.stringData[]; startswith("ENC[AES256_GCM,")) and (has("data") | not)
    and (.sops.mac | startswith("ENC[AES256_GCM,"))' "$WORK/secret.json"
}
check "the Secret holds exactly the keys the StatefulSet reads, each value sops ciphertext" sealed_ok
sealed() { [[ "$("$YQ" '.sops != null' "$SECRET_FILE")" == true ]]; }
listed() { "$YQ" -e '.resources[] | select(. == "lembitu-secrets.sops.yaml")' "$REPO_ROOT/workloads/lembitu/kustomization.yaml" > /dev/null 2>&1; }
listing_matches_seal() { if sealed; then listed; elif listed; then return 1; fi; }
check "lembitu-secrets.sops.yaml is listed exactly when it is sealed ($(sealed && echo sealed || echo a placeholder))" listing_matches_seal

claim() { sts ".spec.volumeClaimTemplates | length == 1 and (.[0] | $1)"; }
check "one claim template, world: fleet-lembitu-local, ReadWriteOnce, tier none, with its regeneration" \
  claim '.metadata.name == "world" and .spec.storageClassName == "fleet-lembitu-local" and .spec.accessModes == ["ReadWriteOnce"]
    and .metadata.labels["backup.fleet/tier"] == "none" and (.metadata.annotations["backup.fleet/regeneration"] | test("archives"))'
check "its regeneration names the restore script's --root, which exists" \
  bash -c "'$JQ' -r '.spec.volumeClaimTemplates[0].metadata.annotations[\"backup.fleet/regeneration\"]' '$WORK/sts.json' \
    | grep -q 'scripts/restore-world.sh --archive <newest> --root ' && grep -q -- '--root) ROOT=' '$REPO_ROOT/scripts/restore-world.sh'"

# The ConfigMaps, as the kubelet would lay them out: each projected source's keys at their item paths.
materialize() {  # materialize <volume> <dir>
  local sources name items
  sources="$(volume_of "$1" | jq -c 'if .projected then .projected.sources[].configMap else .configMap end')"
  while read -r source; do
    name="$(jq -r .name <<< "$source")"
    items="$(jq -c '.items // null' <<< "$source")"
    jq -c --arg n "$name" '.[] | select(.kind == "ConfigMap" and .metadata.name == $n)' "$WORK/render.json" > "$WORK/cm.json"
    [[ -s "$WORK/cm.json" ]] || return 1
    jq -e 'has("binaryData") | not' "$WORK/cm.json" > /dev/null || return 1
    while read -r key; do
      path="$key"
      [[ "$items" == null ]] || path="$(jq -r --arg k "$key" '.[] | select(.key == $k) | .path' <<< "$items")"
      [[ -n "$path" ]] || continue
      mkdir -p "$2/$(dirname "$path")"
      jq -j --arg k "$key" '.data[$k]' "$WORK/cm.json" > "$2/$path"
    done < <(jq -r '.data | keys[]' "$WORK/cm.json")
  done <<< "$sources"
}
same_tree() { materialize "$1" "$WORK/mounted/$1" && diff -r "$REPO_ROOT/config/$2" "$WORK/mounted/$1" > "$WORK/$1.diff"; }
check "the config volume rebuilds config/enforced byte for byte, nested files at their paths" same_tree config enforced
check "the dedicated volume rebuilds config/dedicated byte for byte" same_tree dedicated dedicated

# The fleet's side of the contract, from the same revision as the render's rules.
"$YQ" ea -o=json -I0 '[.]' "$FLEET_SRC/cluster/projects/valheim-lembitu-services.yaml" > "$WORK/services.json"
"$YQ" -o=json -I0 '.' "$FLEET_SRC/cluster/projects/valheim-lembitu-network.yaml" > "$WORK/policy.json"
"$YQ" -o=json -I0 '.' "$FLEET_SRC/cluster/projects/valheim-lembitu-world.yaml" > "$WORK/pv.json"
"$YQ" ea -o=json -I0 '[.]' "$FLEET_SRC/cluster/projects/$PROJECT.yaml" > "$WORK/registration.json"
labels="$(jq -c '.spec.template.metadata.labels' "$WORK/sts.json")"
ports="$(jq -c '[.spec.template.spec.containers[0].ports[] | {port: .containerPort, protocol}]' "$WORK/sts.json")"
check "the fleet's Services select this Pod and target its ports, protocol and all" \
  jqe --argjson labels "$labels" --argjson ports "$ports" --arg ns "$NAMESPACE" \
    'length == 2 and all(.[]; .metadata.namespace == $ns and (.spec.selector | to_entries | all(.value == $labels[.key]))
      and all(.spec.ports[]; {port: .targetPort, protocol} as $p | $ports | index([$p])))' "$WORK/services.json"
check "the fleet's NetworkPolicy fleet-lembitu selects this Pod and admits its game, query and map ports" \
  jqe --argjson labels "$labels" --argjson ports "$ports" \
    '(.spec.podSelector.matchLabels | to_entries | all(.value == $labels[.key]))
      and ([.spec.ingress[].ports[] | {port, protocol}] | sort) == ($ports | sort)' "$WORK/policy.json"
pv_ok() {
  local claim_name size
  claim_name="$(jq -r '"\(.spec.volumeClaimTemplates[0].metadata.name)-\(.metadata.name)-0"' "$WORK/sts.json")"
  size="$(jq -r '.spec.volumeClaimTemplates[0].spec.resources.requests.storage' "$WORK/sts.json")"
  jqe --arg ns "$NAMESPACE" --arg claim "$claim_name" --arg size "$size" \
    --argjson sts "$(cat "$WORK/sts.json")" \
    '.spec.local.path as $path
      | .spec.claimRef == {namespace: $ns, name: $claim}
      and .spec.storageClassName == $sts.spec.volumeClaimTemplates[0].spec.storageClassName
      and .spec.capacity.storage == $size and .spec.accessModes == $sts.spec.volumeClaimTemplates[0].spec.accessModes
      and (.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values == [$sts.spec.template.spec.nodeSelector["kubernetes.io/hostname"]])
      and ($sts.spec.volumeClaimTemplates[0].metadata.annotations["backup.fleet/regeneration"] | contains("--root " + $path))' \
    "$WORK/pv.json"
}
check "the fleet's PersistentVolume is pre-bound to this claim, its class, size, node, and the path the regeneration names" pv_ok
check "the fleet's registration delivers ./workloads/lembitu into $NAMESPACE, under Pod Security restricted" \
  jqe --arg ns "$NAMESPACE" \
    'any(.[]; .kind == "Kustomization" and .spec.path == "./workloads/lembitu" and .spec.targetNamespace == $ns)
      and any(.[]; .kind == "Namespace" and .metadata.name == $ns and .metadata.labels["pod-security.kubernetes.io/enforce"] == "restricted")' \
    "$WORK/registration.json"
check "the fleet defines the priority class fleet-games, never preempting" \
  bash -c "'$YQ' ea -e 'select(.metadata.name == \"fleet-games\") | .preemptionPolicy == \"Never\"' '$FLEET_SRC/cluster/workload-shape/priorities.yaml' > /dev/null"

# --- the image tier -----------------------------------------------------------------------------

if [[ "${LEMBITU_IMAGE_TEST:-}" != 1 ]]; then
  echo "skip: the image tier starts the real server; set LEMBITU_IMAGE_TEST=1 (docs/server-image.md)"
  finish; exit
fi
command -v docker >/dev/null 2>&1 || { echo "error: the image tier needs docker" >&2; exit 2; }
locked() {  # locked <command...>: under LEMBITU_BUILD_LOCK when it is set
  if [[ -n "${LEMBITU_BUILD_LOCK:-}" ]]; then flock "$LEMBITU_BUILD_LOCK" "$@"; else "$@"; fi
}
SKOPEO="$(tool skopeo skopeo)"
ARCHIVE="$(locked nix build --no-link --print-out-paths "$REPO_ROOT#serverImage")"
built="$("$SKOPEO" inspect --insecure-policy --format '{{.Digest}}' "oci-archive:$ARCHIVE")"
pinned="$(jq -r '.spec.template.spec.containers[0].image | sub(".*@"; "")' "$WORK/sts.json")"
printf 'built %s\npinned %s\n' "$built" "$pinned" > "$REPORT/digest.txt"
check "the StatefulSet pins the digest .#serverImage builds ($built)" test "$built" == "$pinned"

TAG="valheim-lembitu-server:workload-test-$$"
echo "$TAG" >> "$WORK/images"
host_args=()
[[ -n "${DOCKER_HOST:-}" ]] && host_args=(--dest-daemon-host "$DOCKER_HOST")
"$SKOPEO" --insecure-policy copy --quiet "${host_args[@]}" "oci-archive:$ARCHIVE" "docker-daemon:$TAG"

NAME="lembitu-workload-test-$$"
VOLUME="$NAME-world"
echo "$VOLUME" >> "$WORK/volumes"
docker volume create "$VOLUME" > /dev/null
# The fixture onto the volume, owned by the server's uid, as fsGroup and the fleet's directory make it.
docker run --rm -v "$VOLUME:/data" -v "$REPO_ROOT/test/fixtures/lembitu-world:/fixture:ro" busybox:1.37 \
  sh -c 'cp -a /fixture/. /data/ && chown -R 10160:10160 /data'
# The runtime tree on a host directory rather than tmpfs, so the running config can be read.
RUNTIME_DIR="$WORK/runtime"
mkdir -p "$RUNTIME_DIR" "$WORK/secrets"
chmod 1777 "$RUNTIME_DIR"
echo "$RUNTIME_DIR" >> "$WORK/bind-dirs"
printf 'fixture pass\n' > "$WORK/secrets/password"
# 0444, not the render's 0400: rootless docker maps this file's owner to the container's root, so
# the server's uid reads it through the other bits. The kubelet gives fsGroup the read instead.
chmod 0444 "$WORK/secrets/password"
chmod -R a+rX "$WORK/mounted"
uid="$(jq -r '.spec.template.spec.securityContext | "\(.runAsUser):\(.runAsGroup)"' "$WORK/sts.json")"
limits="$(jq -r '.spec.template.spec.containers[0].resources.limits | "\(.memory | sub("Gi"; "g")) \(.cpu)"' "$WORK/sts.json")"
echo "$NAME" >> "$WORK/containers"
docker run -d --name "$NAME" --user "$uid" --read-only --cap-drop ALL --security-opt no-new-privileges \
  --memory "${limits% *}" --cpus "${limits#* }" -p 127.0.0.1::3000/tcp \
  -v "$VOLUME:$(mount_of world):nocopy" -v "$RUNTIME_DIR:$(mount_of runtime)" \
  --tmpfs "$(mount_of home):rw,size=512m,mode=1777" --tmpfs "$(mount_of tmp):rw,size=512m,mode=1777" \
  -v "$WORK/mounted/config:$(mount_of config):ro" -v "$WORK/mounted/dedicated:$(mount_of dedicated):ro" \
  -v "$WORK/secrets:$(mount_of secrets):ro" -e SERVERMANAGER_DISCORD_BOT_TOKEN= \
  "$TAG" > /dev/null

# Readiness by the render's own command, every 5 s, for as long as the startup probe allows.
mapfile -t probe < <(jq -r '.spec.template.spec.containers[0].readinessProbe.exec.command[]' "$WORK/sts.json")
budget="$(jq -r '.spec.template.spec.containers[0].startupProbe | .periodSeconds * .failureThreshold' "$WORK/sts.json")"
started=$SECONDS ready_at=""
while (( SECONDS - started < budget )); do
  if docker exec "$NAME" "${probe[@]}" > "$REPORT/ready.txt" 2>&1; then ready_at=$((SECONDS - started)); break; fi
  [[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" == true ]] || break
  sleep 5
done
printf 'ready after ~%s s\n' "${ready_at:-never}" > "$REPORT/timings.txt"
check "readiness (${probe[*]}) turns green within the startup probe's ${budget} s (~${ready_at:-never} s)" test -n "$ready_at"

LOG="$RUNTIME_DIR/BepInEx/LogOutput.log"
# SeparateSpawns' bootstrap runs a few seconds after "Opened Steam server", once the world's
# locations are loaded, and says whether it found a layout or made one.
for _ in $(seq 60); do grep -q 'Separate Spawns\] \(Loaded existing\|Generating\) Separate Spawns layout' "$LOG" && break; sleep 2; done
check "the fixture world loads with its stored SeparateSpawns layout, from the volume, not a new one" \
  bash -c "grep -q 'Loaded existing Separate Spawns layout' '$LOG' && ! grep -q 'Generating Separate Spawns layout' '$LOG'"
cp "$LOG" "$REPORT/LogOutput.log" 2>/dev/null || true
check "SeparateSpawns reads its config and roster from its root on the volume" \
  bash -c "grep -qF 'Config file: $(default_of LEMBITU_RUNTIME)/config/bepinex/abortipus.separatespawns.cfg' '$LOG' \
    && grep -qF 'Server roster path: $(default_of LEMBITU_RUNTIME)/config/bepinex/SeparateSpawns.groups.json' '$LOG'"
# The mods write their files back during the start; AdventureBackpacks' sections come last, so one
# more look after a minute tells a slow writer from a key that is not in effect, as on the live server.
verify() { "$REPO_ROOT/scripts/verify-enforced-config.sh" "$RUNTIME_DIR/BepInEx/config" > "$REPORT/verify.txt" 2>&1; }
verify_running() { verify || { sleep 60; verify; }; }
check "every overlay entry is in effect in the running config (scripts/verify-enforced-config.sh)" verify_running
# A key only the overlay sets: the mod wrote the file back with every key it binds, and kept this one.
written_back() {
  local file="$RUNTIME_DIR/BepInEx/config/adrian.valheim.guilds.cfg"
  grep -qx 'TerritoryBaseSize = 50' "$file" \
    && (( $(grep -c ' = ' "$file") > $(grep -c ' = ' "$REPO_ROOT/config/enforced/adrian.valheim.guilds.cfg") ))
}
check "an overlay key reaches the running config: the guilds mod wrote its file back with TerritoryBaseSize = 50" written_back
map_port="$(docker port "$NAME" 3000/tcp | head -n 1)"
map_status() { [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$map_port/")" == 200 ]]; }
check "the map answers GET / with 200, the public route's probe" map_status

grace="$(jq -r '.spec.template.spec.terminationGracePeriodSeconds' "$WORK/sts.json")"
world="$(mount_of world)/save/worlds_local/LembituRun"
stop_started=$SECONDS
docker stop -t "$grace" "$NAME" > /dev/null
stop_took=$((SECONDS - stop_started))
printf 'stopped in %s s\n' "$stop_took" >> "$REPORT/timings.txt"
docker logs "$NAME" > "$REPORT/server.log" 2>&1
check "SIGTERM: the server exits 0 within the ${grace} s grace (took ${stop_took} s)" \
  bash -c "[[ \$(docker inspect -f '{{.State.ExitCode}}' '$NAME') -eq 0 && $stop_took -lt $grace ]]"
docker run --rm -v "$VOLUME:/data:ro" busybox:1.37 sh -c "ls '$world'; ls /data/dedicated/SeparateSpawns/worlds" > "$REPORT/world-after.txt" 2>&1 || true
after="$(grep -oP '^_main\.\K[0-9]+(?=\.fwl2$)' "$REPORT/world-after.txt" | sort -n | tail -n 1 || true)"
check "SIGTERM: the fixture's generation 1 is followed by a fresh .db2 and .fwl2 (now ${after:-none})" \
  bash -c "[[ -n '$after' && '$after' -gt 1 ]] && grep -qx '_main.$after.db2' '$REPORT/world-after.txt'"
check "the world's SeparateSpawns layout is still on the volume" grep -qx '2270623796.json' "$REPORT/world-after.txt"

finish
