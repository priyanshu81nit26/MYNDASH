# ⚡ Reflex Duel Arena — VISION

**Mission:** make the fastest 3-minute duel on mobile — a game people open "for one match" and stay for ten because *every loss feels winnable* and *every win demands a witness.*

The pillars that everything below must serve:

1. **Instant stakes** — you are always 30 seconds from glory or heartbreak.
2. **Visible mastery** — your growth must be measurable, displayable, braggable.
3. **Social gravity** — every feature should pull one more friend into the arena.
4. **Fair fire** — skill decides everything; lag, money and luck decide nothing.

---

## 1 · New Round Types (grow 5 → 12)

The duel stays "easy to learn" because every round is one instruction. Depth comes from the *mix*.

| Round | Instruction | The skill it secretly trains |
|---|---|---|
| **Mirror** | Copy your opponent's tap — but flipped left/right | Spatial inversion under pressure |
| **Freeze** | Hold your finger down; FIRST to lift when it flashes wins | Stillness + explosive release |
| **Swarm** | 6 dots appear, only one is green — hit it | Visual scanning |
| **Countdown** | Numbers 1→5 scattered on screen, tap in order | Ordered targeting |
| **Liar** | The word "BLUE" written in red — tap the *color*, not the word | Stroop-effect focus (brutal, hilarious) |
| **Heartbeat** | A pulse beats 4×, screen goes dark, tap on the *5th silent beat* | Internal rhythm |
| **Sudden Death** | At 3–3, the final round is ALWAYS pure Strike, but the wait can last up to 9 s | Nerve. Pure nerve. |

**Design rule:** every new round must be explainable in ≤ 7 words and lose-able by being *too eager* — hesitation vs. impulse is the emotional core of the game.

## 2 · Ranked Ladder 2.0 — "The Climb"

XP ranks (Bronze→Legend) stay as *lifetime* progression. On top, add a **seasonal competitive ladder**:

- **Duel Rating (DR)** — Elo-style, starts at 1000. Beat stronger players, gain more. Visible ± after every match.
- **Divisions** — Bronze III → Legend I (15 steps). Promotion matches: win 2 of 3 to rank up — instant drama.
- **Seasons (6 weeks)** — soft reset each season; end-of-season rewards are *cosmetic only* (title, arena skin, tap-effect). Last season's peak is framed on your profile forever.
- **Placement story** — first 5 matches of a season are "placements" with big DR swings. Day-one hype, every season.
- **Rank decay: NO.** Decay punishes rest and breeds unhealthy play. Your rank is yours until someone takes it.

### Leaderboards (the witness system)
- **Global Top 100** — names in lights, live from Firebase.
- **Country boards** — being #14 in your country feels 100× more real than #40,000 globally.
- **Friends board** — the one that actually matters: auto-built from everyone you've ever dueled via room code. *"Rahul passed you while you slept"* is the strongest re-open hook that exists — and it's honest.
- **Per-round-type boards** — fastest average Strike, best Liar accuracy. Everyone gets to be elite at *something*.
- **Weekly reset boards** — fresh race every Monday; newcomers can taste the top.

## 3 · Emotional Systems (the "feel" layer)

- **The Rival System** — the game remembers your most-played opponent and your head-to-head record ("Rahul 12 – 9 You"). A rivalry screen, a rematch button, a notification when your rival passes your DR. Personal rivalry > abstract ladder.
- **Clutch Meter** — winning a round while match-point-down is logged as a *Clutch*. Clutch count is a profile stat. Comebacks become identity.
- **Signature Stat** — every player gets a headline number on their card: "avg Strike: 214 ms". Speed becomes something you *are*.
- **Ghost Replays** — after a loss, watch a 5-second overlay of the exact ms gap ("you were 31 ms behind"). Turns tilt into "one more, I can shave 31 ms."
- **Haptic & sound identity** — every round type gets a unique heartbeat-style audio ramp before GO. Players should *feel* which round is coming with eyes closed.
- **Taunt-free emotes** — 6 wholesome emotes (🔥 😱 🫡 🤝 💀 ⚡) between rounds. Expression without toxicity; no chat = no bullying surface.

## 4 · Modes & Social Gravity

- **Party Royale (3–8 players)** — one room code, everyone plays the same round simultaneously, slowest each round is eliminated. Last reflex standing. This is the school-lunch-table mode and the #1 growth feature.
- **Tournament rooms** — a code spawns an auto-bracketed knockout for up to 16. Winner's name engraved in the room's history node.
- **Daily Gauntlet** — one fixed seed for the whole world each day; 10 rounds solo, one attempt. Global percentile at the end ("faster than 91.4% today"). Identical challenge = perfectly fair bragging.
- **2v2 Relay** — teammates alternate rounds; you win *for someone*. Duty is a stronger motivator than greed.
- **Spectator seats** — extra people in a room watch live with big slow-mo reveals of both reaction times. Turns a duel into an event.
- **Challenge links** — share `reflexduel://beat/214ms` — a link that opens straight into beating your time. Every result becomes an invitation.

## 5 · Progression & Collection (all earned, never bought)

- **Arena skins** — Neon Dojo, Deep Space, Monsoon Rooftop — unlocked by *deeds* ("win 5 duels after being 0–3 down"), not by grinding hours.
- **Tap effects** — lightning cracks, ink splashes, shockwaves where you strike.
- **Titles** — "The Untrappable" (50 Trap wins), "Ice Veins" (10 Sudden-Death wins), "Comeback Kid" (25 Clutches). Titles describe *how you play*.
- **Mastery tracks per round type** — Strike Lv. 30 shows next to your name in the pre-round screen. Psychological warfare, earned.

## 6 · Fair Fire — the anti-dark-pattern contract

This game targets kids and teens, so addiction must come from *pride, rivalry and mastery* — never from anxiety, scarcity or spending. Hard commitments:

- **No pay-to-win. Ever.** Cosmetics only, and even those earnable by play.
- **No loot boxes, no gacha, no fake discounts, no countdown-timer shop pressure.**
- **No loss-punishment mechanics** (no losing cosmetics/DR floors protect new players).
- **Streak freeze is free** — daily-streak systems, if added, never punish a missed day harshly.
- **Session nudge** — after ~60 min of continuous play: a friendly full-screen "Legends rest their hands 🖐️" with one-tap resume. Respectful, skippable, honest.
- **Anti-cheat** — server-timestamp validation (reaction < 80 ms auto-flagged as inhuman, < 120 ms reviewed), seed verification, and shadow-pools for confirmed cheaters so they only duel each other.

*A 10/10 game is one parents don't fear and players brag about. Those are the same feature.*

## 7 · Roadmap

**Phase 1 — Sharper Blade (now)**
Sounds + haptics, Sudden Death rule, Friends leaderboard, Rival system, 2 new rounds (Liar, Freeze).

**Phase 2 — The Climb (next)**
Seasonal DR ladder, divisions + promotion matches, Daily Gauntlet, country/global boards, titles.

**Phase 3 — The Arena Fills**
Party Royale, tournaments, spectators, challenge links, arena skins + mastery tracks.

**Phase 4 — The World Watches**
2v2 Relay, replays/highlights sharing, seasonal world championship board, creator room codes.

---

### North-star metrics
- **"One more" rate** — % of matches followed by a rematch within 60 s (target > 45%).
- **Witnessed wins** — % of duels vs. a repeat opponent (rivalries forming, target > 30%).
- **D7 retention via friends board** — players with ≥ 3 friends on the board should retain 2× baseline.
- **Median session ≤ 25 min** — yes, a *ceiling*. Healthy sessions + high return frequency beats binge-and-burnout. That's what makes it a 10/10 to *feel*, not just to play.
