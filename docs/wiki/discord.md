# Discord server — layout, bots and agent access

The Run gets its own Discord server (owner, 2026-10-07; #106). ServerManager feeds it through
webhooks and runs a bot inside the game server for the chat bridge and admin commands. A second bot,
Lembitu Ops, belongs to the coding agent: with it the agent builds and maintains the server's
channels, roles and webhooks through Discord's REST API, so the owner does only the steps Discord
reserves for a human.
Discord facts below come from its developer documentation, cited inline; nothing here has been run
against a live Discord server yet.

## Decisions

### Layout

The agent builds and keeps this layout; changes go through this page first.

| Category | Channel | Who sees it | Fed by |
| --- | --- | --- | --- |
| Top level | `🟢 Online · N/10` / `🔴 Offline` / `🟠 Restarting` (locked voice channel) | Everyone; nobody joins | Host status timer, Lembitu Server bot |
| Info | `#📖-how-it-works` | Everyone, read-only | The concept and how the server works, guilds first: one Ops-bot post per section of `config/discord/how-it-works.md` (sections split on `---` lines, each at most 2,000 characters). Re-running the layout edits a changed post in place, posts a new section and deletes a removed one, so the file is the only place to change it |
| Info | `#🌍-web-map` | Everyone, read-only | Topic and one pinned message with the map link, posted once by the Ops bot (`topic` and `message` in `config/discord/layout.json`) |
| Info | `#announcements` | Everyone; only the owner and the bots post | Owner, and a Pack-release webhook |
| Info | `#rules` | Everyone, read-only | Owner |
| Info | `#password` | Player role, read-only | Owner |
| Server | `#status` | Everyone | One live status message through STATUS; ServerManager events may also post |
| Server | `#activity` | Everyone | ServerManager webhook: `player.connection`, `player.death`, `boss.killed`, `raid.status` |
| Server | `#chat` | Player role | ServerManager bot (chat channel) and webhook `chat.shout` |
| Help | `#support` | Everyone | Players and the owner |
| Guilds | one channel per Guild | That Guild's role and the owner | Made by the agent when the Guild forms |
| Admin | `#admin-alerts` | Owner and bots | ServerManager webhook: `security.alert`, `security.admin_bypass`, `character.validation`, `character.shadow_stalled`, `character.revision_observed`, `connection.rejected`, `moderation.action`, `command.executed`, `cron.executed`; and the monitor |
| Admin | `#admin-console` | Owner and bots | ServerManager bot (admin channel for slash commands) |

Roles, highest first: the owner's own, **Lembitu Ops**, **Lembitu Server**, **Player** (given by the
owner to people who may join the game), and one **Guild · name** role per Guild. The web map's link
sits in `#🌍-web-map`'s header and pinned message. ServerManager's event names are from its README, "Webhooks: game →
Discord". Player is **mentionable**: a webhook can only ping a mentionable role, and the v17
release post's `@Player` showed as text but notified nobody until this was set (2026-10-09).

### Two bots, two applications

- **Lembitu Ops** is the agent's. Its invite grants Manage Channels, View Channel, Send Messages,
  Embed Links, Attach Files, Read Message History, Manage Roles, Manage Webhooks and Pin Messages,
  permissions integer `2251800619109392`, and never Administrator, which bypasses every channel
  overwrite ([permissions](https://docs.discord.com/developers/topics/permissions)). It needs no
  privileged intent: the operations above are REST calls
  ([HTTP restrictions](https://docs.discord.com/developers/events/gateway#http-restrictions)).
- **Lembitu Server** is ServerManager's. Its invite grants View Channel, Send Messages, Embed Links
  and Read Message History (`84992`), and its application has the Message Content intent on,
  because the chat bridge reads ordinary messages (ServerManager README, bot section). The game
  server reads its token from `SERVERMANAGER_DISCORD_BOT_TOKEN`.
  The layout grants its role View Channel, Connect and Manage Channels (`1049616`) **only on the
  locked status voice channel**, not server-wide. Discord refuses to rename a voice channel for a
  bot that cannot Connect to it, which the first live run showed with `1040`. Everyone else can
  see that channel but cannot Connect (`1048576` denied). The Ops token stays on the Mac.
- Both are private applications (Public Bot off), so only the owner can install them
  ([bot authorization](https://docs.discord.com/developers/topics/oauth2#bot-authorization-flow)).
  Separate applications keep the agent's broad rights out of the game server's process.

### Where secrets live

| Value | Secret | Where |
| --- | --- | --- |
| Server, owner, application, Player role and status voice-channel IDs | No | `~/.config/lembitu/discord.env` on the Mac; copied to astral-bicep for the status timer |
| Lembitu Ops token | Yes | macOS login keychain, service `lembitu.discord.ops` |
| Lembitu Server token | Yes | macOS keychain `lembitu.discord.serverbot`; game-server secret environment and `~/.config/lembitu/discord-serverbot.env` on astral-bicep (`DISCORD_SERVER_BOT_TOKEN`, 0600) |
| Webhook URLs | Yes | `~/.config/lembitu/discord-webhooks.env` (0600) on Mac and astral-bicep; also ServerManager's private `discord.yml` |

No token or webhook URL enters the repository, a Ticket, the wiki or a log.

**ServerManager's `discord.yml` is generated, not edited.** `scripts/servermanager-discord.py`
writes it from `discord.env` and `discord-webhooks.env` before every start
(`scripts/launch-server.sh`, after the policy check): the Server status, Activity, Chat and Admin
alerts routes with the events in the layout table (only Admin alerts carries Steam IDs), and the
bot for this guild with the owner as the only admin user, `#admin-console` as its admin channel and
`#chat` as its chat channel. It holds no token; the container receives
`SERVERMANAGER_DISCORD_BOT_TOKEN` from the launch secret file. The MONITOR and PACK_RELEASES routes
stay ours. `discord-layout.sh` records the chat and admin-console channel IDs for it.
`test/servermanager-discord.test.sh` covers it.

**The status channel was created twice (2026-10-09).** The first, with Connect denied for
everyone and no bot exception, locked both bots out, so they could neither rename nor delete it,
and creating a channel with a Manage Roles overwrite is refused without Administrator. The layout
now grants each bot View, Connect and Manage Channels on that channel, and the replacement renamed
itself to `🟢 Online · 0/10` on its first run. The first one stays until the owner deletes it.

### Giving the agent access: the owner's part

Run `scripts/wizard-discord.sh` on the Mac. It walks through seven stages and stores each value
where the table above says; tokens are typed into the keychain's own hidden prompt. The same steps
by hand:

1. **Account.** Enable two-factor authentication on your Discord account, because a server that
   requires 2FA for moderation refuses role and channel management from bots whose owner lacks it
   ([2FA requirement](https://docs.discord.com/developers/topics/oauth2#two-factor-authentication-requirement)).
   Turn on User Settings → Advanced → Developer Mode, so IDs can be copied
   ([finding IDs](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID)).
2. **Server.** Create the server (Add a Server → Create My Own). Copy its Server ID and your User ID.
3. **Lembitu Ops application.** In the [Developer Portal](https://discord.com/developers/applications),
   create the application, copy its Application ID, turn Public Bot off, leave the privileged intents
   off, then Bot → Reset Token and store the token. Discord shows it once
   ([getting started](https://docs.discord.com/developers/quick-start/getting-started#step-1-creating-an-app)).
4. **Install Lembitu Ops** with the URL the wizard builds: scopes `bot applications.commands`,
   `permissions=2251800619109392`, the server preselected. Then drag its role to the top, below your
   own: a bot manages only roles below its highest one.
5. **Lembitu Server application.** The same as step 3, but turn the Message Content intent on, and
   install it with `permissions=84992`.
6. **Community, optional.** Enabling Community gives a rules screen and followable announcements. A
   bot needs Administrator to enable it
   ([modify guild](https://docs.discord.com/developers/resources/guild#modify-guild)), so the owner
   does it by hand: Server Settings → Enable Community.
7. **Check.** The wizard asks Discord, with the Ops token, for the bot's name and the server's name.
   Then tell the agent the wizard finished.

### How the agent configures the server

- **Credentials.** The agent reads the token with `security find-generic-password -a "$USER" -s
  lembitu.discord.ops -w` inside the command that uses it, never echoing it, and the IDs from
  `~/.config/lembitu/discord.env`.
- **Requests.** `https://discord.com/api/v10` with headers `Authorization: Bot <token>`,
  `Content-Type: application/json` and `User-Agent: DiscordBot (https://github.com/rakoort/valheim-lembitu, 1)`
  ([API reference](https://docs.discord.com/developers/reference)).
- **Calls it uses.** `GET /guilds/{guild}/channels` to read the current layout;
  `POST /guilds/{guild}/channels` to create a category (`type` 4) or text channel (`type` 0, with
  `parent_id`); `PATCH /channels/{channel}` to rename or move; `PUT
  /channels/{channel}/permissions/{role}` with `type` 0 and `allow`/`deny` bit strings for the
  visibility above; `POST /guilds/{guild}/roles` for roles; `POST /channels/{channel}/webhooks`,
  whose answer gives `https://discord.com/api/webhooks/{id}/{token}`; `POST
  /channels/{channel}/messages` and `PUT /channels/{channel}/messages/pins/{message}` for the rules
  and password posts
  ([guild](https://docs.discord.com/developers/resources/guild),
  [channel](https://docs.discord.com/developers/resources/channel),
  [webhook](https://docs.discord.com/developers/resources/webhook),
  [message](https://docs.discord.com/developers/resources/message)).
- **The script.** `scripts/discord-layout.sh` applies `config/discord/layout.json` (#106):
  `--dry-run` prints the differences and writes nothing; `apply` creates or edits only what differs
  and never deletes anything outside the layout; `guild 'Name' slug` adds a Guild's role and
  private channel, and repeating it changes nothing. A slug that names a layout channel, or a
  channel outside the Guilds category or belonging to another Guild, is refused before anything
  changes. It reads the token from the keychain and hands
  it to `curl` on standard input, never as an argument, and writes the six route URLs atomically to
  `~/.config/lembitu/discord-webhooks.env` (0600) as `DISCORD_WEBHOOK_STATUS`, `_ACTIVITY`,
  `_CHAT`, `_ADMIN_ALERTS`, `_MONITOR` and `_PACK_RELEASES`. The integrator copies that file to the
  same path on astral-bicep. `test/discord-layout.test.sh` proves it against a fake API (42
  checks): a second apply sends no writes, a `429` pauses every request, a `401` or `403` stops at
  once, and neither token nor webhook secret is printed. It has not yet run against Discord.
- **Rate limits.** On `429` it waits `Retry-After` seconds; a `global` limit pauses every call; it
  never retries `401` or `403`
  ([rate limits](https://docs.discord.com/developers/topics/rate-limits)).
- **Limits.** A bot can only grant permissions it holds, and creating a channel cannot set Manage
  Roles on it without Administrator
  ([create channel](https://docs.discord.com/developers/resources/guild#create-guild-channel)). Our
  layout needs neither.

### Live status and Pack releases (owner, 2026-10-09)

`scripts/discord-status.sh` runs once a minute through `config/discord-status/`. It creates one
STATUS webhook message with `?wait=true`, stores the returned ID in
`~/.local/state/lembitu/discord-status.json`, then edits it; a missing message (`404`) is recreated.
It shows online/offline/restarting, players N/10 and character names, game and Pack versions,
container uptime, the next 06:00 Europe/Oslo maintenance restart and
`https://lembitu-map.astral.ee`. Online means the container is running and OdinEye answers; a valid
maintenance marker takes precedence and shows restarting. An unanswered player query shows an
unknown count rather than inventing zero players. OdinEye 1.2.37's `/players` DTO uses `Name`
(decompiled staged `OdinEye.Models.Api.Player`, `PlayersController` and its Utf8Json serializer).
The game version is read only from this container boot's logs. The Pack version comes from the
installer's host-side `.lembitu-pack-version`, not a guess at the newest GitHub release.

The voice display uses `DISCORD_STATUS_VOICE_CHANNEL_ID` written by the layout. Its name changes
only when the text differs and at least five minutes have elapsed since the last rename attempt;
unchanged text makes no request. This respects Discord's two-renames-per-ten-minutes limit.
Webhook and channel failures warn without stopping future timer runs; missing webhook or bot
credentials skip only that display. Credentials reach curl through stdin, never argv or logs.
`test/discord-status.test.sh` exercises the cycle with fakes and real curl against a local fake
HTTP server; live Discord and astral-bicep deployment remain unverified.

`scripts/publish-pack.sh` creates the GitHub release and then posts through PACK_RELEASES to
`#announcements`: version, the explicit `--changes` summary, download link, **reinstall required**
and `@Player`. It permits only the recorded Player role ID in `allowed_mentions.roles`; other
mentions cannot ping. Its dry run publishes nothing. See `docs/wiki/pack.md`, Distribution.
The layout preserves its non-secret IDs file while recording `DISCORD_ROLE_PLAYER_ID` and the
status channel ID, and identifies the voice channel by ID after the status timer renames it.

API references: [execute/edit webhook](https://docs.discord.com/developers/resources/webhook)
(`POST ?wait=true`, `PATCH /messages/{id}`) and
[modify channel](https://docs.discord.com/developers/resources/channel#modify-channel)
(`PATCH /channels/{id}`), verified against Discord's current API documentation.

## Exclusions

- **Administrator for Lembitu Ops.** Not granted: it bypasses channel overwrites, and the only task
  needing it, enabling Community, is a one-time click for the owner.
- **One bot for both jobs.** Not used: the game server would then hold a token able to restructure
  the whole Discord server.
- **An external bot host.** Not needed: ServerManager's bot runs inside the game server, which is
  why the 2026-10-04 objection to bot mods (`docs/modstack.md:493`) no longer applies.
- **Tokens in files.** Not used on the Mac: the keychain is the only store, so a token never sits
  in a plain file there.

## Lessons

- **Discord calls a server a guild.** In this project a Guild is only the in-game group; the API's
  `guild` paths mean the Discord server (`CONTEXT.md`, Discord server).
- **A bot's reach is its role's position.** The Ops role must sit above every role it manages, or
  role and overwrite edits fail with `403`.
- **Status is a snapshot, not an event feed.** Retaining the webhook message ID avoids a new post
  every minute, and retaining the voice channel ID avoids duplicate channels after dynamic renames.
