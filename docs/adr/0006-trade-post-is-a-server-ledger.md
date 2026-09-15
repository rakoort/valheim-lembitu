# ADR-0006: The Trade Post is a server ledger with mailbox delivery

Date: 2026-09-10
Status: Accepted
Issue: #16

## Context

Cross-clan trade is the mechanism that makes clans interdependent rather than parallel: goods
teleport, players do not, and ore cannot cross a portal, so buying from another clan is cheaper than
hauling. The requirement that makes it hard is asynchrony — the flow must complete while the posting
player is offline, and survive a restart, and not let a client fabricate a fill.

#16 was originally specified as physical infrastructure: an outbound container, an inbound container
and a contract board per post, with escrow held on the post. That is the Valheim-ish shape, and it
puts every hard case in the worst possible place — container ownership, whether the zone is loaded,
who last touched a chest, and what happens across a save. Item duplication bugs live there.

KG Marketplace (deprecated, pre-1.0, binary-only — a design reference, not a dependency) solved the
same problem by splitting it: listings held server-side, a banker holding coin as a balance, and a
mailbox delivering to players at next login.

## Decision

- **Contracts, escrow and balances are server records.** Posting a contract removes the goods from
  the world and records them; escrow is a number, not coins in a chest.
- **Filling delivers through the mailbox.** The counterparty's goods and the filler's payment are
  queued and claimed at next login, which makes the offline case the normal case rather than a
  special one.
- **The buildable Trade Post is the interface.** One per clan, as before, but it renders state
  rather than holding it.
- **Server-authoritative by construction.** A client asks to post or fill; it never asserts a
  transfer. Restart safety comes from the records being saved with the clan registry, not from
  containers surviving.

## Consequences

- Goods in transit cannot be stolen, and a raid cannot take a rival's escrow. That is a deliberate
  loss of drama; an interceptable in-transit window can be layered on later without changing the
  ledger.
- Restricted goods — ore, metal — move through a filled contract while remaining unable to cross a
  portal normally, because the transfer never involves a portal.
- Item identity has to be stable, which is why DataForge is restricted to tuning and no cloned or
  custom items enter the stack (ADR-0004).
- Contract expiry returns escrow automatically, since expiry is a record with a timestamp rather
  than a chest that must be found and emptied.

## Deferred — 2026-09-15

Not built for this run, and not in the pack. The design stands as written; only its scheduling
changes (ADR-0010).

Adding it mid-run is safe, and this decision is the reason why: contracts, escrow and balances are
server records saved with the clan registry, so nothing about them enters the world save and no
existing saved object has to be reinterpreted. The one exception is the buildable Trade Post itself.
A new prefab can be added at any time, because nothing references it yet; from the day it ships it
inherits ADR-0009's one-way property, since removing it would leave saved objects pointing at a
prefab that no longer exists.

Two constraints must therefore survive the deferral: DataForge stays restricted to tuning, so item
identities remain stable enough for a ledger to describe goods, and any later pack bump that adds
the piece has to reach every client on the same day.
