# 🧠 MYNDASH — the mind arena

*(formerly DISTRICT — rebranded; same Firebase project `district-966f3`.)*

One Flutter app (Android + iOS), two worlds:

1. **MYNDASH** — a premium dark, glassy mind-sport platform: learn, solve, duel, win.
2. **Reflex Duel ⚡** — the original real-time reaction game, embedded as the action
   challenge inside 1v1 (with full Firebase online rooms).

## Install on your phone (one click)

Connect your phone via USB (USB debugging ON) and double-click
**`build_and_install.bat`** in this folder. It fetches packages, builds the
release APK and installs it. First build takes a few minutes.

## First-run experience

Intro pages → **Sign in / Create account** (Google · email + password +
verification mail · phone + SMS OTP · or guest) → claim a **unique username**
(6+ chars, globally unique) → home. Every major section (Solve, Daily, 1v1,
Arena, Contest, Store) shows a short **first-time guide** explaining how to play.
Google & phone OTP activate once Firebase is connected (below) *and* your SHA-1
key is added in Firebase console → Project settings → Your apps → Android
(get it with `cd android && gradlew signingReport`).

## Titles & weekly contests

Contests run **every Saturday & Sunday** (Blitz 30 min / Classic 45 min).
Contest rating starts at 1500: Beginner → 1700 Specialist → 1900 Expert →
2100 Master → 2300 Candidate Master → 2600 Chakra → 2900 **Trishul** 🔱.

## What's inside

- **Home** — coins, streak flame 🔥, hamburger menu (Help / About / Feedback /
  Logout), quick entry to everything including the **Global Top 30 leaderboard**
  and **Friends search**. A **Netflix-style auto-moving hero slider** rotates
  through the trending public arena, the daily challenge, real chess, the
  weekend contest and the store.
- **Daily 5** — 5 progressive questions; each solve unlocks the next. Streak = coins.
- **Solve** — 25 categories × levels **800 → 2500** (chess-style bands, Novice →
  Grandmaster). Question categories run 30-question sessions with boss questions;
  board categories (Sudoku, Minesweeper, KenKen, Kakuro, Nonograms, Sliding,
  Hanoi, Set, River Crossing, Logic Grid, Memory) run 6 escalating boards with
  live validation and hints (3 free per level, then 25 coins).
- **1v1** — 7-question race with wagers (Elo rated) across math/logic feeds
  **plus three battle modes**: **REAL Chess ♟** (full legal chess — castling,
  en passant, promotion, checkmate — on a responsive 2D board vs a
  rating-scaled alpha-beta engine, `lib/engine/chess_engine.dart`),
  **Tactics 🧩** (curated mate-in-one & tactics MCQs) and **Darts 🎯** (timed
  precision — tap a shrinking dartboard, closest to bullseye over 5 throws
  wins). Or **Reflex Duel ⚡** online rooms.
- **Games 🎮** — one hub for **Chess ♟, Darts 🎯 and Rubik's Cube 🧊**, each
  with Practice + Compete (bot / online / friend) using ONE consistent
  invite flow: a 6-letter room code + shareable link you can paste into
  WhatsApp or any messenger.
- **Rubik's Cube 🧊** — exact NxN sticker engine (`lib/engine/cube_core.dart`),
  real 3D rendering with finger-orbit and animated face turns, authentic
  colors. Practice 2×2 & 4×4 with Shuffle/timer/move counter; Compete = race
  a bot or a live player on the same seeded scramble.
- **Online 1v1 🌐** — matchmaking queue pairs you with the **closest rating**
  in your game/category (`/queue`, `/rooms` in RTDB). Live chess move sync,
  live darts throw sync, cube races and 7-question duels with live opponent
  progress. Forfeit/leave handling + claim-win on inactivity.
- **Haptics & sounds** — every button clicks (`lib/core/fx.dart` wired into
  the Glass/Neon widgets); wins, losses, level-ups, darts and chess captures
  each have their own feel. Win/loss celebration dialogs on every 1v1.
- **Profile calendar 🗓** — month view with contest (Sat/Sun) and Live Drop
  markers plus your own reminders / scheduled matches (persisted locally).
- **MYNDASH KIDS 🚀** — onboarding now asks age (+ a cheeky "what do you think
  your IQ is?"); under-12s get a dedicated kids home: age-fit topics
  (counting → times tables → fractions…), 10 levels × 30 questions each,
  all games in practice mode, same profile & coins — **no online duels,
  arenas or store** until 12+.
- **Chess Journey ♟** — 30 levels of real chess. Level N simulates
  **900 + N×100 Elo** (L1 = 1000 … L30 = 3900); each level is **5 games** and
  every game the bot gains **+20 Elo**. Win all 5 to unlock the next level;
  completed levels stay replayable as practice.
- **Live Drop ⚡** — twice a day (13:00 & 21:00 local) a 10-minute window opens:
  everyone worldwide gets the **same 15 seeded questions**; scores post to a
  global drop board (`/drops/{window}`), coins + XP paid by score.
- **Squads 👥** — 3–10 player clans with name, tag and a 6-letter join code.
  Squad Power = combined earned XP of all members (`/squads`, `/squad_codes`).
- **College 🎓 & Corporate 🏢** — type your campus/company name: if it exists
  on MYNDASH you join its board (ranked by contest rating); if not, it's appended
  to the database and you're member #1 (`/orgs/college`, `/orgs/company`).
- **Mind DNA 🧬** — a living 6-trait radar (Speed, Logic, Memory, Calculation,
  Nerve, Consistency) computed from real play, with a shareable archetype.
- **MYNDASH PRO / ULTRA 💎** — membership screen (demo activation; no billing yet).
  Sells speed, style, insight & access — never wins. See `ideass.md`.
- **Arena** — 8 seats, 10 questions, entry-fee rooms; pot pays 🥇 60% / 🥈 25%.
- **Arenas / Events 2.0** — a live **public-arena slider** on top, then the
  **MYNDASH official tier events**: 🥉 Bronze Blitz (75 🪙) · 🥈 Silver Series
  (120 🪙) · 🥇 Gold Gauntlet (300 🪙). Anyone can **host an esports arena**,
  **public or private** — private arenas get a 6-letter join code. Tier rules
  are enforced: minimum entry fee (75/120/300), participation limits
  (min 2 → max 8/16/32) and prize caps (1500/4000/12000 🪙). The **public
  arena browser** has filters (tier/price, game category, arena size) and
  pagination. See `ideass.md` for the monetization & SaaS roadmap.
- **Profile** — GitHub-style **activity heatmap** (last 12 weeks of solves),
  **Games** history (last 15 matches with W/L/D, rating delta) and a
  **last-5 form strip**, plus social counts and the Title Road.
- **Friends** — dedicated search page with debounced (300 ms) autocomplete over
  the global username index; tap a player to open their **public profile**
  (contest rating + title, duel Elo, XP, recent matches) and follow/unfollow.
- **Leaderboard** — top 30 players platform-wide by contest rating, with your
  own rank row pinned at the bottom. Offline-safe with a retry state.
- **Store** — coin packs (demo checkout) and a real-brand prize wall
  (Nike, Samsung, JBL, Sony, PlayStation, iPhone…), governed by the dual-currency
  economy below.
- **Aurora shader background** — custom GLSL fragment shader (`shaders/aurora.frag`)
  with graceful fallback.

## 💰 The economy (dual currency — play-to-redeem)

Two currencies with different rules:

| | Coins 🪙 | XP ⚡ |
|---|---|---|
| Earned by playing | ✅ | ✅ |
| Purchasable | ✅ (coin packs) | ❌ **never** |
| Spent on redemption | ✅ | ❌ (kept — it's a lifetime score) |

**Redemption rule:** an item priced **X coins** also requires **earned XP ≥ 5X**.
Since XP can only come from solving, dueling and contests, redemptions can
never be reached by purchase alone — buying coins speeds you up, but only
play unlocks prizes. Every store item shows two progress bars (coins + XP)
so players always see how close they are. Orders are demo-fulfilled; real
payments/fulfilment are Phase 4 (see `docs/PLAN.md`).

XP sources: level stars (10/★), daily solves (15), contest questions (20 each),
Reflex practice (10–30).

## Build it

```bash
cd reflex_duel
flutter create . --platforms=android,ios --org com.district
flutter pub get
flutter run                      # MYNDASH works fully offline
flutter build apk --release      # Android
flutter build ios --release      # iOS (requires a Mac)
```

## Optional: turn on the online layer (Firebase)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=district-966f3
```

Then in the [Firebase console](https://console.firebase.google.com/u/0/project/district-966f3):
1. Authentication → Sign-in method → **Anonymous** → Enable
2. Realtime Database → Create database
3. Realtime Database → Rules → paste `database.rules.json` → Publish

The Realtime Database lives in **asia-southeast1**; its URL is pinned in
`lib/firebase_options.dart` (`DefaultFirebaseOptions.databaseUrl`) and every
service accesses it via `FirebaseDatabase.instanceFor` with 6-second timeouts
and graceful offline fallbacks. Cloud data model:

```
/usernames/{username} = uid          unique-handle index (prefix-searchable)
/profiles/{uid}                      public stats: username, name, elo,
                                     contestRating, xp, recent matches
/social/{uid}/following|followers    social graph
/events, /rooms                      events + Reflex Duel rooms
```

Without Firebase, MYNDASH still runs 100% (practice, solve, duels/arena vs rated
AI); only human rooms, search and the leaderboard need the cloud.

## Project layout

```
lib/
  main.dart                    boots MYNDASH (+ optional Firebase)
  theme_district.dart          pure-black premium theme, rating bands
  core/state.dart              coins, XP, levels, streak, activity heatmap,
                               match history, guide flags, Elo
  engine/question.dart         category registry, difficulty math
  engine/generators.dart       10 question categories, rating-scaled
  engine/chess_puzzles.dart    curated chess tactics MCQs (1v1 mode)
  puzzles/                     11 interactive board dashboards
  ui/glass.dart                glass kit + aurora shader background
  ui/extras.dart               heatmap, form strip, confetti, guides, share
  screens/district_home.dart   nav shell + home + hamburger drawer
  screens/solve_flow.dart      level maps, 30-Q sessions, board runs
  screens/compete.dart         1v1 duels (incl. chess), arena
  screens/darts_duel.dart      darts precision 1v1
  screens/friends_search.dart  player search + public profiles
  screens/leaderboard_screen.dart  global top 30
  screens/store_screen.dart    coin packs + dual-currency prize wall
  screens/(reflex files)       the original Reflex Duel game
```

Design docs: `docs/CATEGORIES.md` (full 800–2500 curriculum) · `docs/PLAN.md` (architecture & phases).

## Rebuild after changes

Double-click **`build_and_install.bat`** with your phone connected.
