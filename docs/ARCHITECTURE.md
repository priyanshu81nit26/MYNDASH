# MYNDASH — Production Cloud Architecture (Firebase, Blaze)

This document explains why matchmaking felt slow, what was fixed in the client, and the
production-grade architecture to grow into: cross-device state sync, lock-free matchmaking,
near-zero-latency leaderboards, and the write-contention pitfalls that kill Firebase games.

---

## 1. Why matchmaking was slow or never completed

The old flow read the queue **once**:

```
read queue → nobody there? → host a room → wait 30s → give up
```

Failure modes:

1. **Mutual-wait deadlock.** Two players search within the same second. Both read an empty
   queue, both host, both wait 30 seconds staring at each other's ticket that they will never
   re-read. This is the "search never matches" bug, and it gets *worse* as the app grows,
   because simultaneous searches become more common.
2. **One-shot reads.** A player arriving 2 seconds after you started waiting was invisible —
   there was no listener on the queue.
3. **Stale tickets.** Crashed clients left tickets behind; new searchers wasted their claim
   attempts on dead entries.
4. **Hard 30s cutoff** with no rating-band relaxation: strict filters with a short window.

### The fix (shipped in `account_service.dart` → `quickMatch`)

An event-driven, **lock-free** protocol on RTDB:

- **Ticket keyed by uid** at `queue/{game_sub}/{uid}` — re-searching overwrites instead of
  duplicating; `onDisconnect().remove()` reaps crashes.
- **Host immediately, listen continuously.** Every searcher hosts a room, publishes a ticket,
  and subscribes to both (a) their own room's guest seat and (b) the whole queue.
- **Total-order claim rule.** A player may only claim tickets **older** than their own
  (ties broken by uid). For any pair of waiting players exactly one is the claimer — mutual
  deadlock and claim-each-other livelock are *structurally impossible*, with no locks and no
  coordinator.
- **Two-transaction claim.** Atomically take the ticket, then atomically take the guest seat.
  A lost race just rescans; nobody blocks.
- **Progressive rating bands.** ±300 → ±600 → open over 25s, so quality is preferred but
  nobody starves. 60s total window. Stale tickets (>2 min) are ignored and deleted.

The same total-order fix was applied to the legacy Reflex Duel matcher
(`firebase_service.dart`): after hosting, it watches for **older** entries for ~12s and
migrates into them, so simultaneous searchers always converge.

`.indexOn ["at", "elo"]` was added to queue rules for cheap server-side ordering.

---

## 2. Target architecture at scale

```
┌──────────┐   auth    ┌───────────────┐
│  Client  │──────────▶│ Firebase Auth │
└────┬─────┘           └───────────────┘
     │ realtime state (rooms, presence, queues)
     ▼
┌────────────────────────┐   triggers   ┌──────────────────┐
│ RTDB (regional shards) │─────────────▶│ Cloud Functions   │
│  rooms/  queue/  ...   │◀─────────────│  (2nd gen)        │
└────────────────────────┘   writes     └───────┬──────────┘
     │ durable profile / history                │ hot aggregates
     ▼                                          ▼
┌────────────────┐                     ┌──────────────────────┐
│   Firestore     │                     │ Memorystore (Redis)  │
│ profiles, match │                     │ ZSET leaderboards,   │
│ history, banks  │                     │ matchmaking buckets  │
└────────────────┘                     └──────────────────────┘
```

Principle: **RTDB is the wire, not the database.** Low-latency ephemeral state (rooms,
queues, presence) lives in RTDB; durable data (profiles, history) belongs in Firestore;
hot aggregates (leaderboards, match buckets) in Redis once traffic justifies it.

### 2.1 Cross-device state synchronization pipeline

- **Delta writes only.** Never `set()` a whole room; `update()` leaf paths
  (`rooms/{id}/state/moveNo`). Each listener then receives ~100-byte diffs. (The app
  already does this via `roomWrite(id, path, value)`.)
- **Server-timestamped, monotonic events.** Every mutation carries `ServerValue.timestamp`
  and a per-writer sequence number; receivers ignore out-of-order events. For turn games,
  the move number IS the lock: writes to `state/m{n}` are naturally idempotent.
- **Authoritative side per field.** Host owns round resolution; guests own only their own
  input paths (`results/{uid}`). No two writers ever contend on the same leaf.
- **`keepSynced(true)` on the active room** (already shipped: `pinRoom`) so reconnects
  replay from local cache with no cold start.
- **Clock sync** via `.info/serverTimeOffset` (already shipped) so timed rounds fire at the
  same real instant on both phones.
- **Regional pinning.** The DB is pinned to asia-southeast1 (already shipped). At scale,
  add per-region database instances (`rtdb-asia`, `rtdb-eu`, `rtdb-us`) and route players by
  latency probe at login; only cross-region tournaments pay cross-region RTT.

### 2.2 Lock-free distributed matchmaking service (server-side evolution)

The shipped client protocol is correct and lock-free, but at ~5k concurrent searchers the
queue node becomes a hot read path. Evolution, in order:

1. **Bucketed queues (no code redesign).** Shard the queue path by rating band:
   `queue/{game_sub}/{eloBucket}/{uid}` with buckets of 200 Elo. Searchers watch their own
   bucket ± 1. Cuts fan-in per listener by ~10×.
2. **Cloud Functions matcher.** An `onCreate` trigger on tickets pairs the two oldest
   compatible tickets and writes `matches/{uid} = roomId` for both. Clients listen to one
   1-key path — zero client scanning. The function is stateless; concurrency-safe because
   it claims tickets with the same delete-transaction the clients use. Cold-start guard:
   keep 1 warm instance (2nd-gen `minInstances: 1`, pennies on Blaze).
3. **Redis-backed matcher (10k+ concurrent).** Tickets go into a Memorystore ZSET scored by
   Elo; a matcher does `ZRANGEBYSCORE` neighbors and `ZREM` both atomically via a Lua
   script — a true lock-free CAS. RTDB then only carries the *result* (`matches/{uid}`).

### 2.3 Near-zero-latency leaderboard aggregation

Today: `orderByChild('contestRating').limitToLast(30)` over `/profiles` — fine to ~50k
profiles **if** `.indexOn: ["contestRating"]` is set (add it — see §4). Beyond that:

1. **Materialized top-N.** A Cloud Function triggered on rating writes maintains
   `leaderboards/global/top100` as a single ≤20 KB node. Every client reads ONE node —
   O(1), CDN-warm, effectively zero latency. Update cost is one write per rating change.
2. **Sharded rank counters.** For "your global rank #12,345", keep a histogram node
   `rank_hist/{bucket} = count` (100-point buckets, incremented transactionally on rating
   change). Rank = prefix-sum of ~30 buckets — one read, no scan.
3. **Redis ZSETs** for exact live ranks at large scale: `ZADD leaderboard elo uid`,
   `ZREVRANK` is O(log n) and single-digit-millisecond. RTDB mirror refreshed every 5s by
   a scheduled function gives spectators a cache-friendly view.
4. **Time-boxed boards** (daily arena, Squad Mania) are naturally small — keep them as
   plain RTDB nodes per day/month key, exactly as shipped (`official_arenas/{day}/…`,
   `squad_mania/{month}/…`), and archive old keys with a scheduled function.

---

## 3. Critical pitfalls & specific fixes

| Pitfall | Symptom | Fix |
|---|---|---|
| **Write contention on one node** (everyone transacting the same counter) | Transactions retry, p99 latency explodes | Shard counters (N sub-keys summed on read); or make writes idempotent per-writer paths (`scores/{uid}`) — the app's score submissions already do this |
| **Hot read path** (every client listening to a big node) | Bandwidth bill, slow first paint | Listen to leaf paths; paginate with indexed queries; materialize top-N views |
| **Unindexed queries** | RTDB downloads the whole node then filters client-side | `.indexOn` for every `orderByChild` (added for queue; add `contestRating` on profiles) |
| **Fan-out writes done client-side** (updating 100 members' views) | Slow, partial failures | One canonical write + Cloud Function fan-out, or store once and read by reference (squad members store stats once — shipped) |
| **Zombie state** (crashed clients leaving tickets/rooms) | "Ghost" opponents, full queues | `onDisconnect()` hooks everywhere (shipped) + scheduled function deleting `rooms` older than 24h and tickets older than 2 min |
| **Whole-object `set()`** | Listeners re-download the world | `update()` with multi-path atomic writes (shipped for social graph accept/unfollow) |
| **One global DB region** | 300ms RTT for far players | Regional instances + latency routing (§2.1) |
| **Transactions across trust boundary** | Cheating clients write any score | Move prize math and score validation into Cloud Functions with security rules `".write": false` for client on payout paths (see §5) |

---

## 4. Immediate low-cost actions (this repo)

1. Deploy the updated `database.rules.json` (queue indexes + new nodes):
   `firebase deploy --only database`.
2. Add to `/profiles` rules: `".indexOn": ["contestRating", "xp"]`.
3. Keep RTDB regional; monitor Usage tab — the biggest early cost is listeners on big
   nodes, not writes.
4. When DAU crosses ~5k: introduce the Cloud Functions matcher (§2.2.2) — the client
   protocol already tolerates it (it would simply find `matches/{uid}` faster than its own
   scan).

## 5. Trust boundary (next hardening step)

Client-side coin awards (arena prizes, Mania claims) are transaction-guarded against
*double* claiming but not against *forged* claiming. Production step: move
`maniaClaim` / arena payouts into a callable Cloud Function that recomputes standings
server-side, and lock `claims/` + `coins` mutation paths to `auth.token.admin == true` in
rules. The data model shipped (write-once transactional claims keyed by user) ports to the
function unchanged.
