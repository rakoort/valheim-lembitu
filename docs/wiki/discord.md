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
| Info | `#announcements` | Everyone; only the owner and the bots post | Owner, and a Pack-release webhook |
| Info | `#rules` | Everyone, read-only | Owner |
| Info | `#password` | Player role, read-only | Owner |
| Server | `#status` | Everyone | ServerManager webhook: `server.status`, `server.announcement` |
| Server | `#activity` | Everyone | ServerManager webhook: `player.connection`, `player.death`, `boss.killed`, `raid.status` |
| Server | `#chat` | Player role | ServerManager bot (chat channel) and webhook `chat.shout` |
| Help | `#support` | Everyone | Players and the owner |
| Guilds | one channel per Guild | That Guild's role and the owner | Made by the agent when the Guild forms |
| Admin | `#admin-alerts` | Owner and bots | ServerManager webhook: `security.alert`, `security.admin_bypass`, `character.validation`, `character.shadow_stalled`, `character.revision_observed`, `connection.rejected`, `moderation.action`, `command.executed`, `cron.executed`; and the monitor |
| Admin | `#admin-console` | Owner and bots | ServerManager bot (admin channel for slash commands) |

Roles, highest first: the owner's own, **Lembitu Ops**, **Lembitu Server**, **Player** (given by the
owner to people who may join the game), and one **Guild · name** role per Guild. The web map's link
is posted in `#announcements`. ServerManager's event names are from its README, "Webhooks: game →
Discord".

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
- Both are private applications (Public Bot off), so only the owner can install them
  ([bot authorization](https://docs.discord.com/developers/topics/oauth2#bot-authorization-flow)).
  Separate applications keep the agent's broad rights out of the game server's process.

### Where secrets live

| Value | Secret | Where |
| --- | --- | --- |
| Server, owner and application IDs | No | `~/.config/lembitu/discord.env` on the owner's Mac |
| Lembitu Ops token | Yes | macOS login keychain, service `lembitu.discord.ops` |
| Lembitu Server token | Yes | macOS login keychain, service `lembitu.discord.serverbot`; the agent copies it into the game server's secret environment on astral-bicep |
| Webhook URLs | Yes | Created by the agent; written only to ServerManager's `discord.yml` and the monitor's config on astral-bicep |

No token or webhook URL enters the repository, a Ticket, the wiki or a log.

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
- **Idempotence.** Every run reads the server first and creates or edits only what differs from the
  layout above, so it can be re-run safely.
- **Rate limits.** On `429` it waits `Retry-After` seconds; a `global` limit pauses every call; it
  never retries `401` or `403`
  ([rate limits](https://docs.discord.com/developers/topics/rate-limits)).
- **Limits.** A bot can only grant permissions it holds, and creating a channel cannot set Manage
  Roles on it without Administrator
  ([create channel](https://docs.discord.com/developers/resources/guild#create-guild-channel)). Our
  layout needs neither.

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
