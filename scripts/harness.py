#!/usr/bin/env python3
"""Native harness file IPC; no game input emulation or external dependencies.

Single: python3 scripts/harness.py --dir /tmp/client-a --command '{"action":"snapshot"}'
Scenario: --scenario steps.json --client a=/tmp/client-a --client b=/tmp/client-b
Steps are [{"client":"a","command":{"action":"snapshot"},"save":"before"},
 {"client":"a","command":{"action":"move","x":1,"seconds":1},
  "expect":[{"path":"state.player.x","op":"gt",
             "from":{"saved":"before","path":"state.player.x"}}]}].
Paths traverse dot-separated keys and numeric array indices (inventory.0.stack).
Assertions use eq/ne/gt/gte/lt/lte with either value or from. Command field values
may also use {"saved":"before","path":"state.inventory.0.id"} references.
Steps may set expect_ok:false to require a native refusal; the default is true.
Exit codes: 0 success, 2 input, 3 native rejection, 4 IPC, 5 timeout, 6 assertion.
A timeout does not cancel a published command: inspect its UUID response before
retrying. Use one coordinator per control directory; files remain as evidence.
"""

import argparse
import json
import math
import operator
import os
from pathlib import Path
import sys
import time
import uuid


class Failure(Exception):
    def __init__(self, code, message, **details):
        super().__init__(message)
        self.code = code
        self.details = details


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Failure(2, message)


def decode(text):
    def invalid(value):
        raise ValueError("non-finite JSON number: " + value)
    return json.loads(text, parse_constant=invalid)


def path_value(document, path):
    if not isinstance(path, str) or not path:
        raise Failure(2, "assertion/reference path must be a nonempty string")
    value = document
    for part in path.split("."):
        try:
            if isinstance(value, list):
                if not part.isdecimal():
                    raise KeyError(part)
                value = value[int(part)]
            elif isinstance(value, dict):
                value = value[part]
            else:
                raise KeyError(part)
        except (KeyError, IndexError) as exc:
            raise Failure(6, "path not present: " + path) from exc
    return value


def reference(spec, saved):
    if not isinstance(spec, dict) or set(spec) != {"saved", "path"}:
        raise Failure(2, "reference must contain exactly saved and path")
    if not isinstance(spec["saved"], str) or spec["saved"] not in saved:
        raise Failure(2, "unknown preceding saved response: " + str(spec["saved"]))
    return path_value(saved[spec["saved"]], spec["path"])


def read_json(path):
    try:
        value = decode(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise ValueError("protocol document must be an object")
        return value
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as exc:
        raise Failure(4, "cannot read " + str(path) + ": " + str(exc)) from exc


def wait_pause(deadline, description, **details):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise Failure(5, "timed out waiting for " + description, **details)
    time.sleep(min(0.05, remaining))


def request(directory, command, timeout):
    if not isinstance(command, dict) or not isinstance(command.get("action"), str):
        raise Failure(2, "command must be an object with a string action")
    if any(isinstance(v, (dict, list)) for v in command.values()):
        raise Failure(2, "command fields must be flat JSON values")
    deadline = time.monotonic() + timeout
    while True:
        status = read_json(directory / "status.json")
        if status is not None:
            if not isinstance(status, dict) or type(status.get("ready")) is not bool:
                raise Failure(4, "invalid harness status", status=status)
            if status.get("error"):
                raise Failure(3, "harness startup failed", status=status)
            if status["ready"]:
                break
        wait_pause(deadline, "harness readiness", directory=str(directory))

    identity = str(uuid.uuid4())
    payload = dict(command, id=identity)
    encoded = json.dumps(payload, allow_nan=False).encode("utf-8")
    if len(encoded) > 16384:
        raise Failure(2, "command exceeds 16 KiB")
    inbox = directory / "inbox"
    temporary = inbox / (identity + ".tmp")
    try:
        inbox.mkdir(exist_ok=True)
        with temporary.open("xb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(inbox / (identity + ".json"))
    finally:
        temporary.unlink(missing_ok=True)
    response_path = directory / "outbox" / (identity + ".json")
    while True:
        response = read_json(response_path)
        if response is not None:
            if (not isinstance(response, dict) or response.get("id") != identity
                    or type(response.get("ok")) is not bool
                    or "state" not in response or "error" not in response):
                raise Failure(4, "invalid harness response", id=identity, response=response)
            return response
        status = read_json(directory / "status.json")
        if isinstance(status, dict) and status.get("error"):
            raise Failure(3, "harness failed during command", id=identity, status=status)
        wait_pause(deadline, "response (command may still execute)", id=identity,
                   response_path=str(response_path))


OPERATORS = {"eq": operator.eq, "ne": operator.ne, "gt": operator.gt,
             "gte": operator.ge, "lt": operator.lt, "lte": operator.le}


def check_assertions(assertions, response, saved):
    for assertion in assertions:
        actual = path_value(response, assertion["path"])
        expected = (reference(assertion["from"], saved) if "from" in assertion
                    else assertion["value"])
        op = assertion["op"]
        numeric = lambda v: type(v) in (int, float)
        if op in ("eq", "ne"):
            equal = (type(actual) is type(expected) or (numeric(actual) and numeric(expected))) and actual == expected
            passed = equal if op == "eq" else not equal
        else:
            if not numeric(actual) or not numeric(expected):
                raise Failure(6, "ordered comparisons require numbers", assertion=assertion,
                              actual=actual, expected=expected)
            passed = OPERATORS[op](actual, expected)
        if not passed:
            raise Failure(6, "scenario assertion failed", assertion=assertion,
                          actual=actual, expected=expected)


def validate_steps(steps, clients):
    if not isinstance(steps, list) or not steps:
        raise Failure(2, "scenario must be a nonempty array of steps")
    names = set()
    for step in steps:
        if not isinstance(step, dict) or not isinstance(step.get("client"), str) or step["client"] not in clients:
            raise Failure(2, "every step must name a configured client")
        if not isinstance(step.get("command"), dict) or not isinstance(step["command"].get("action"), str):
            raise Failure(2, "every step must have a command with string action")
        if type(step.get("expect_ok", True)) is not bool:
            raise Failure(2, "expect_ok must be a boolean")
        assertions = step.get("expect", [])
        if not isinstance(assertions, list):
            raise Failure(2, "expect must be an array")
        refs = [v for v in step["command"].values() if isinstance(v, dict)]
        for assertion in assertions:
            if (not isinstance(assertion, dict) or not isinstance(assertion.get("path"), str)
                    or not assertion["path"] or not isinstance(assertion.get("op"), str)
                    or assertion["op"] not in OPERATORS
                    or ("value" in assertion) == ("from" in assertion)):
                raise Failure(2, "assertions need path, op, and exactly one of value/from")
            if "from" in assertion:
                refs.append(assertion["from"])
        for ref in refs:
            if (not isinstance(ref, dict) or set(ref) != {"saved", "path"}
                    or not isinstance(ref["saved"], str) or ref["saved"] not in names
                    or not isinstance(ref["path"], str) or not ref["path"]):
                raise Failure(2, "references must name a preceding saved response and path")
        if "save" in step:
            name = step["save"]
            if not isinstance(name, str) or not name or name in names:
                raise Failure(2, "save names must be unique nonempty strings")
            names.add(name)


def control_path(value):
    path = Path(value)
    if not path.is_absolute():
        raise Failure(2, "control directory must be absolute: " + value)
    return path


def main():
    parser = Parser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--command", help="flat JSON native command")
    mode.add_argument("--scenario", type=Path, help="JSON array of sequential steps")
    parser.add_argument("--dir", help="absolute control directory for one command")
    parser.add_argument("--client", action="append", default=[], metavar="NAME=DIR")
    parser.add_argument("--timeout", type=float, default=60, help="seconds per step including readiness (default 60)")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        raise Failure(2, "timeout must be a positive finite number")
    if args.command is not None:
        if not args.dir or args.client:
            raise Failure(2, "--command requires --dir and does not accept --client")
        response = request(control_path(args.dir), decode(args.command), args.timeout)
        if not response["ok"]:
            raise Failure(3, "native command rejected", response=response)
        return response
    if args.dir or not args.client:
        raise Failure(2, "--scenario requires --client NAME=DIR, not --dir")
    clients = {}
    for entry in args.client:
        name, separator, directory = entry.partition("=")
        if not name or not separator or not directory or name in clients:
            raise Failure(2, "clients must be unique NAME=DIR entries")
        clients[name] = control_path(directory)
    steps = decode(args.scenario.read_text(encoding="utf-8"))
    validate_steps(steps, clients)
    saved, results = {}, []
    for index, step in enumerate(steps):
        try:
            command = {key: reference(value, saved) if isinstance(value, dict) else value
                       for key, value in step["command"].items()}
            response = request(clients[step["client"]], command, args.timeout)
            results.append({"step": index, "client": step["client"], "response": response})
            expected_ok = step.get("expect_ok", True)
            if response["ok"] != expected_ok:
                raise Failure(6, "unexpected native outcome", expected_ok=expected_ok, response=response)
            check_assertions(step.get("expect", []), response, saved)
            if "save" in step:
                saved[step["save"]] = response
        except Failure as exc:
            exc.details.update(step=index, client=step["client"], results=results)
            raise
    return {"ok": True, "results": results}


if __name__ == "__main__":
    try:
        result = main()
        code = 0
    except Failure as exc:
        result = dict(ok=False, error=str(exc), exit_code=exc.code, **exc.details)
        code = exc.code
    except ValueError as exc:
        result, code = {"ok": False, "error": str(exc), "exit_code": 2}, 2
    except OSError as exc:
        result, code = {"ok": False, "error": str(exc), "exit_code": 4}, 4
    except KeyboardInterrupt:
        result, code = {"ok": False, "error": "interrupted; published commands are not cancelled", "exit_code": 130}, 130
    print(json.dumps(result, allow_nan=False))
    sys.exit(code)
