# MYNDASH — the mind arena

**Puzzles as a sport.** Duel real minds, climb the ranks, win rewards. One
Flutter codebase — Android + Web (myndash.online), iOS-ready.

*(Formerly "Reflex Duel" / "DISTRICT" — same Firebase project `district-966f3`,
rebranded and rebuilt into a full competitive mind-sport platform.)*

---

## What it is

MYNDASH turns everyday brain training into something you can compete at —
head to head, with a real person on the other side, a live rating, and a
rank to defend. Solo practice, daily challenges, 1v1 duels, timed arenas,
weekend contests, squads, and a weekly Wrapped recap of how your mind
actually performed.

**Live:** https://myndash.online

---

## The flow — start to dashboard

```
Onboarding intro carousel (7 pages)
   ↓
Create account / Sign in  —  Google · Email + password (verified) · Phone (SMS OTP)
   ↓
Claim a unique username (6–20 chars, live availability check)
   ↓
About You  —  age + 6 quick questions (new accounts only)
   under 12 → routed into MYNDASH KIDS instead of the adult app
   ↓
Rocket-launch reveal animation
   ↓
Home dashboard
```

Returning users skip straight past onboarding/About You into the reveal.

---

## Features

### Learn
- **Daily 5** — five progressively unlocking questions plus independent daily
  games; one transparent XP/coin pool; every clear archives into the
  **Daily Vault** for permanent rating-tagged practice.
- **Solve** — 25 categories across levels **800 → 2500** (chess-style bands,
  Novice → Grandmaster): question categories (30-question sessions with a
  boss question) and board categories (Sudoku, Minesweeper, KenKen, Kakuro,
  Nonograms, Sliding, Hanoi, Set, River Crossing, Logic Grid, Memory) with
  live validation and hints.
- **AI Coach** — an offline, evidence-grounded personal trainer, **free for
  every player**.

### Compete
- **1v1** — question-feed duels with wagers (Elo-rated), plus dedicated
  battle modes: **Chess** (full legal rules — castling, en passant,
  promotion, checkmate — vs a rating-scaled engine), **Darts** (swipe-throw
  physics, 5 darts, closest to bullseye), and the original **Reflex Duel**
  reaction-time rooms.
- **Games hub** — Chess, Darts, Rubik's Cube (real NxN sticker engine, 3D
  finger-orbit rendering) and 5 shared **Mind Games** (Sudoku, Hanoi, Number
  Puzzle, Arrow Puzzle, Word Finder/Crossword) — each with Practice/Journey
  and Compete (bot / online / friend), one consistent invite flow: a
  6-letter room code + shareable link.
- **Online matchmaking** — pairs you with the closest rating in your
  game/category; live opponent progress, forfeit/leave handling, claim-win
  on inactivity.
- **Showdown reveal** — a "you vs opponent" pregame beat before every match.

### Arenas & Contests
- **Arenas** — host or join timed, rating-bracketed events: official
  MYNDASH tiers (Bronze/Silver/Gold) and player-hosted arenas, public or
  private (6-letter join code), with enforced entry fees, participant caps
  and prize pools. **My Arenas** splits into Upcoming / Ongoing / History.
- **Weekend contests** — official Saturday/Sunday papers, the same seeded
  questions worldwide, with a live leaderboard per event.
- **Live Drop** — twice a day, a 10-minute window opens with the same 15
  seeded questions for everyone on Earth; scores post to a global board.

### Social
- **Profile** — activity heatmap (12 weeks), match history with W/L/D and
  rating deltas, Mind DNA (a living 6-trait radar computed from real play),
  and an edit-profile sheet (name, bio, username, avatar — cross-platform
  base64 photo, contact fields).
- **Public profiles** — view any player's name, username, bio, rating and
  recent matches; follow/unfollow, follower/following/requests pages.
- **Friends search** — debounced autocomplete over the global username
  index.
- **Leaderboards** — Global, Corporate, College, and Friends views, your own
  rank pinned at the top.
- **Squads** — up to 10-player clans (public join or private code), plus
  **Squad Mania**, the monthly inter-squad tournament (base league → top 16
  → top 8 → semis → final).
- **Community hub** — verify your college or company (email OTP via a
  Firebase Cloud Function) to join its leaderboard; one org at a time,
  exclusive between college and company.

### MYNDASH Wrapped
A Spotify-style weekly recap — a swipeable deck of story cards (solves,
streak, best day, win rate, favourite mode) built from real play data — plus
a **Journey** timeline of tenure ranks (Beginner from day one → Practitioner
→ Challenger → Hustler), each with its own art. Shareable to Instagram/
WhatsApp.

### MYNDASH KIDS
A dedicated under-12 zone routed to automatically from the About You age
question: age-fit topics, a full games arcade in practice mode, Kid Arcade
(endless high-score games), Chocolate Hour (a new problem every hour, 24/
day), Fun Games (Block Builder, Memory Match, Almanac, Cross Math) — same
profile and coins, no online duels/arenas/store until 12+.

### Store & economy
Dual currency: **coins** 🪙 (earned by playing, spendable) and **XP** ⚡
(earned by playing, never spent — a lifetime score). Redeeming an item
priced X coins also requires earned XP ≥ 5X, so purchases alone can never
unlock rewards. **The Store is currently an upcoming preview — there is no
live payment integration**; coins are earned entirely through gameplay.

---

## Tech stack

- **Flutter** (Android, Web live at myndash.online, iOS-ready) — single
  codebase, Material 3, light "Arcade" / dark "Night" themes with animated
  cross-fade.
- **Firebase**: Authentication (Google, Email/Password, Phone), Realtime
  Database (region `asia-southeast1`) for usernames/profiles/social/events/
  matchmaking, Cloud Functions (Node.js) for org-verification email OTP,
  Hosting for the web build.
- **No payment SDK** — deliberately removed; see `docs/payments-v1-retired.md`.
- Custom chess engine (`lib/engine/chess_engine.dart`), NxN Rubik's Cube
  engine (`lib/engine/cube_core.dart`), and a shared rating/progression
  system (`lib/engine/rating_catalog.dart`, `lib/engine/game_progression.dart`)
  spanning every category and game.

## Security

A recent adversarial security pass covering web + Android, RTDB rules, the
in-repo Cloud Function, and hosting headers lives in `SECURITY_AUDIT.md`
(supersedes nothing in the earlier `SECURITY_THREATS.md`). Known open items
and the current model are documented there — read it before treating any
surface as trusted.

## Project layout

```
lib/
  main.dart                    boots the app, routes onboarding → home
  theme_district.dart          design system (DC palette, ThemeCtl)
  core/state.dart              coins, XP, levels, streak, activity, match history
  engine/                      chess/cube engines, rating catalog, generators
  ui/                          shared widgets (glass, buttons, heatmap, avatar)
  services/account_service.dart auth, usernames, social, competitions
  screens/onboarding.dart      intro → sign-in → username → about-you
  screens/welcome_screen.dart  the rocket-launch reveal
  screens/district_home.dart   root shell + navigation
  screens/wrap_screen.dart     MYNDASH Wrapped + Journey
  screens/arena_redesign.dart  arenas (host/join/My Arenas)
  screens/contest_screen.dart  weekend contests
  screens/(game screens)       one file per game (chess, darts, cube, sudoku…)
  screens/kid_*.dart           the under-12 zone
```

Design docs: `docs/CATEGORIES.md` (the full 800–2500 curriculum) ·
`docs/PLAN.md` (architecture & phases) · `VISION.md` (product mission) ·
`ideass.md` (roadmap/monetization ideas).

## Build it

```bash
flutter pub get
flutter run                      # works fully offline (practice, solve, vs AI)
flutter build apk --release      # Android
flutter build web --release      # Web
```

## Optional: connect your own Firebase project

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then in the Firebase console:
1. Authentication → Sign-in method → enable **Google**, **Email/Password**, **Phone**
2. Realtime Database → create it, then paste `database.rules.json` into Rules
3. (Optional) Cloud Functions → deploy `functions/` for org-verification email

Without Firebase configured, the app still runs — solo practice, Solve,
Daily 5, and duels vs AI all work offline; only sign-in, cloud sync, search,
and leaderboards need the network.
