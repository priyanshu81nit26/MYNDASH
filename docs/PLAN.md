# DISTRICT — Build Plan & Analysis (Flutter, Android + iOS)

## 1. What we're building

A premium dark, glassy **mind-sport app**: practice like Duolingo, compete like chess.com,
win like 8-ball pool. Five pillars: **Daily Problem · Solve (levels 800→2500) · 1v1 ·
Arena (up to 8) · Store (coins → merch)**. Reflex Duel (already built) becomes one 1v1
challenge type.

## 2. Analysis — key decisions before writing code

**a) Native Flutter widgets, not a game engine.**
Every category is a board/grid/text interaction — Flutter excels here. A game engine
(Flame) would add weight without benefit. Reflex Duel rounds also work as widgets (proven).

**b) "3D / wow" layer = Flutter fragment shaders now, Rive drop-ins later.**
- **Now:** a custom GLSL aurora shader (`shaders/aurora.frag`) renders a slow-moving,
  organic nebula behind every screen — GPU-cheap, feels alive, no assets needed.
  Graceful fallback to gradient blobs if shaders fail on a device.
- **Later (Rive):** the plan reserves mount points for `.riv` files — mascot on Home,
  trophy burst on victory, coin rain on store purchase, streak flame on Daily. Rive
  files must be designed in the Rive editor (design tool, not code) — slots are marked
  `// RIVE:` in code so a designer can drop them in without refactoring.

**c) Offline-first, online-second.**
Phase 1 ships fully playable vs **rated bots** (1v1 + Arena) with local persistence.
Phase 2 wires Firebase (already proven in reflex_duel: anonymous auth, rooms,
server-time sync) for real humans. This ordering de-risks everything: UX and content
get perfect first; netcode plugs into stable screens.

**d) Playtime balancing (adaptation of CATEGORIES.md).**
30 questions/level is right for *question* categories (~20–45s each ≈ 12–20 min/level).
For **board** categories (Sudoku, Minesweeper…), 30 boards would be 1–3 hours — so board
categories use **10 boards/level**, keeping every level a 15–25 min session. Curriculum
ratings and ramps stay identical.

**e) Validation & hints are per-category dashboards, not generic.**
Each puzzle gets its own gamified surface: Sudoku shows conflicts the moment you place
a wrong digit (cell flashes, mistake counter ticks), hint fills a correct cell with a
shimmer; Minesweeper hint reveals a safe frontier cell; Sliding hint plays the next
optimal move; MCQ hint burns two wrong options (50:50). 3 free hints/level, then 25 coins.

**f) Economy honesty.** Coin purchases and merch redemption ship as **mock flows**
behind a clean interface (`Wallet.buy()`, `Store.redeem()`), because real money needs a
payment gateway (Razorpay/Play Billing), prize-competition legal compliance, and
fulfilment ops. The UI is final; the backend switches from mock → real without UI change.

## 3. Architecture

```
district/app/
  pubspec.yaml                google_fonts, shared_preferences; shader assets
  shaders/aurora.frag         GLSL nebula background
  lib/
    main.dart                 boot, routes
    theme.dart                pure-black premium theme, rank colors
    core/
      state.dart              AppData: coins, ratings, stars, streak, inventory (JSON via prefs)
      difficulty.dart         rating→params curve, par times, stars, Elo for duels
    engine/
      question.dart           Question model (typed / MCQ)
      generators.dart         8 categories, seeded, mistake-modelled distractors
    puzzles/
      sudoku.dart             generator (unique-solution) + engine
      sudoku_screen.dart      gamified dashboard: validate-on-tap, notes, hints
      minesweeper_screen.dart, sliding_screen.dart, hanoi_screen.dart, memory_screen.dart
    ui/glass.dart             GlassCard, NeonButton, ShaderBackground(+fallback)
    screens/
      home.dart               hub: daily card, duel, arena, solve grid, store
      solve.dart / levels.dart / session.dart   category → level map → 30-Q run
      daily.dart / duel.dart / arena.dart / store.dart
```

## 4. Content matrix (Phase 1)

| Category | Type | Dashboard features |
|---|---|---|
| Mental Math | typed | keypad, speed bar, streak-in-run |
| Quant Aptitude | MCQ | 50:50 hint, trap distractors |
| Number Theory | MCQ | — |
| IQ Patterns | MCQ | sequence display |
| Geometry | MCQ | — |
| Probability | MCQ | fraction options |
| Clock & Calendar | MCQ | — |
| Knights & Knaves | MCQ | statement cards |
| **Sudoku** | board | live conflict validation, notes mode, hint-fill, 3-mistake limit |
| Minesweeper | board | first-tap safe, flags, safe-cell hint |
| Sliding Tile | board | move counter vs par, hint move |
| Tower of Hanoi | board | optimal-move par, illegal-move shake |
| Memory Matrix | board | flash-then-recall, lives |

Remaining CATEGORIES.md entries (Kakuro, KenKen, Nonograms, Logic Grid, Set, Cryptarithms,
River Crossing, Estimation, Syllogisms, Data Interpretation, Word Problems) render as
**locked "SOON" cards** — the grid shows platform breadth from day one.

## 5. Modes

- **Solve:** 18 levels/category (800→2500). Stars ★/★★/★★★ (accuracy + par time).
  ★★ unlocks next. Coins = level/10 × stars. Boss questions Q28–30 (Q8–10 on boards).
- **Daily:** date-seeded, same for everyone, rating ≈ overall+100; streak ×; +100 coins.
- **1v1:** pick category (or Reflex) → 7-question race vs opponent; free or wagered
  (50/100/250); Elo rating updates; live opponent progress bar. Phase 1 bots, Phase 2 humans.
- **Arena:** 8 seats, 10 mixed questions, 15s each, live standings between questions;
  rooms: Free / Bronze 50 / Silver 200 / Gold 500; pot pays 60% / 25% (15% house).
- **Store:** Get-Coins packs (mock) + merch redemption (Nike/Puma shoes, JBL, boAt,
  Bonkers tee, Yonex racket, SG bat, Rubik's cube, Kindle, iPhone, PS5, MacBook) with
  order tracking.

## 6. Phases

1. **Phase 1 (this build):** everything above, offline, bots, mock economy.
2. **Phase 2:** Firebase multiplayer (port reflex_duel netcode), real leaderboards,
   friends, room codes for Arena.
3. **Phase 3:** Rive animation pass, sound design, haptics, remaining 11 categories.
4. **Phase 4:** real payments + KYC + fulfilment partner, seasons, tournaments.

## 7. Success bar for Phase 1

Open app → play a Sudoku level with live validation and hints → win a wagered duel →
place 2nd in an arena → redeem coins for merch (mock) — all in under 10 minutes,
with zero placeholder screens on that path.
