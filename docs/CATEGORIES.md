# DISTRICT — Category & Level Curriculum

**Platform:** train + duel with mind puzzles. Ratings run **800 → 2500** like chess.
This file is the master design for every category: what it trains, how difficulty
scales *inside* a level (intra) and *across* levels (inter), and where it appears
(Solve / Daily / 1v1 / Arena).

---

## The Level Framework (applies to every category)

| Band | Rating | Identity |
|---|---|---|
| Novice | 800–1000 | Learn the rules by playing |
| Learner | 1000–1300 | Speed + basic technique |
| Skilled | 1300–1600 | Multi-step thinking |
| Expert | 1600–1900 | Technique under time pressure |
| Master | 1900–2200 | Deep search, few hints from format |
| Grandmaster | 2200–2500 | Competition-grade problems |

- **18 levels per category** (800, 900, 1000 … 2500). Each level = **30 questions**.
- **Intra-level ramp:** Q1–10 at base difficulty, Q11–20 at +⅓ step, Q21–27 at +⅔ step,
  **Q28–30 are "boss questions"** at next-level difficulty (this is what makes finishing a level feel earned).
- **Stars:** ★ ≥ 60% correct · ★★ ≥ 80% · ★★★ ≥ 95% *and* inside the par time.
- **Unlock rule:** next level opens at ★★. Coins reward = level ÷ 10 × stars.
- **Resume:** 30-question runs save progress — leave anytime, continue later.
- **Competitive reuse:** 1v1 and Arena pull from the *same generators*, pinned to the
  average rating of the players in the room, so practice literally trains you for matches.

---

## GROUP A — Number Crunch (fast, typed answers; the esport core)

### 1. Mental Math
- **Trains:** raw calculation speed; the "engine" stat of the whole platform.
- **Inter-level:** 800: 2-digit ± → 1200: 2×1-digit ×,÷ → 1600: 3-digit mixed, squares
  → 2000: 4-op chains, %, powers → 2500: Vedic-style tricks required (98×97, 45², 1/16 as %).
- **Intra-level:** operand size and op count grow every 10 questions.
- **Format:** typed number, 20s par. Perfect for 1v1 race + Arena.

### 2. Quantitative Aptitude
- **Trains:** translating words into equations (exam-grade skill: CAT/GMAT/SSC).
- **Topics by band:** percentages, ratios → profit & loss, averages → speed-distance-time,
  work-time → mixtures, partnership → compound interest, relative speed (trains/boats).
- **Inter-level:** single-step (800) → two-step (1400) → three-step with a trap answer (2000+).
- **Format:** MCQ (4 options, distractors generated from *common mistakes*), 45s par.

### 3. Number Theory Puzzles
- **Trains:** structural feel for numbers.
- **Inter-level:** parity/divisibility (800) → GCD/LCM (1200) → remainders & modular
  arithmetic (1600) → last digits of powers, divisor counting (2000) → CRT-flavoured,
  digit-sum chains (2400).
- **Format:** typed or MCQ, 40s par.

### 4. Probability & Combinatorics *(appended — duels love it)*
- **Trains:** counting without listing; risk intuition.
- **Inter-level:** single dice/coin (800) → two events (1200) → nCr counting (1600)
  → conditional probability (2000) → expected value (2400).
- **Format:** MCQ with fraction options.

### 5. Estimation / Fermi *(appended — great Daily material)*
- **Trains:** order-of-magnitude judgement. "How many liters in an olympic pool?"
- **Scoring twist:** closest range wins — brilliant in Arena because everyone can answer
  but only the calibrated win.

## GROUP B — Aptitude & Reasoning (MCQ, exam-adjacent)

### 6. IQ Pattern Problems
- **Inter-level:** next-in-sequence arithmetic (800) → geometric/alternating (1200) →
  interleaved double sequences (1600) → second-difference & polynomial (2000) →
  symbol-matrix patterns (2400).

### 7. Word Problems
- Classic brainteasers: ages, heads-and-legs, coins, handshakes, socks-in-the-dark.
- **Inter-level:** direct setup → inverted unknowns → multi-constraint → adversarial
  wording where the obvious answer is planted wrong.

### 8. Geometry Puzzles
- **Inter-level:** angle chasing in triangles (800) → areas/perimeters (1200) →
  Pythagoras & special triangles (1500) → circles, polygons (1800) → coordinate
  geometry (2100) → composite-figure dissection (2400).

### 9. Syllogisms & Deduction *(appended)*
- "All ravens are birds. Some birds sing…" — valid-conclusion MCQ.
- **Inter-level:** 2 premises → 3 premises → negations → "possibility" traps → Venn-breaking cases.

### 10. Data Interpretation *(appended)*
- Mini table/chart rendered in-app; 3 rapid questions per display.
- **Trains:** reading numbers the way interviews and exams demand.

### 11. Clock & Calendar *(appended)*
- Hand angles, overlaps (800–1400); day-of-week for any date, calendar cycles (1600+).

### 12. Binary Logic Puzzles (Knights & Knaves)
- "A says B lies; B says C lies…" — identify truth-tellers.
- **Inter-level:** 2 speakers → 3 speakers → self-reference → mixed "spy" (alternator) → 5-speaker webs.

### 13. Cryptarithms
- SEND+MORE=MONEY style. **Inter-level:** 2-letter sums with 1 unknown (800) →
  3-letter full alphametics (1400) → multiplication cryptarithms (2000+).
- **Format:** solve for one letter (MCQ) at low levels; full assignment grid at high.

## GROUP C — Grid & Constraint Puzzles (interactive boards)

### 14. Sudoku
- **Inter-level:** 4×4 (800–1100) → 6×6 (1200–1500) → 9×9 easy→hard (1600–2200) →
  9×9 minimal-clue + variants (X-sudoku) (2300+).
- **Intra-level:** fewer givens every 10 puzzles. Par time scales.

### 15. Minesweeper
- **Inter-level:** 6×6/5 mines → 8×8/10 → 10×10/18 → 12×12/28 no-flag par (2200+).
- **Skill:** it's deduction, not luck — first click always safe; boards guarantee logic path.

### 16. Nonograms
- **Inter-level:** 5×5 (800) → 8×8 (1300) → 10×10 (1700) → 12×12 multi-block rows (2100+).

### 17. KenKen
- **Inter-level:** 3×3 +/− cages → 4×4 all ops → 5×5 (1800) → 6×6 (2200).

### 18. Kakuro
- **Inter-level:** 4×4 with unique-sum combos (magic blocks) → 6×6 → 8×8 with
  overlapping runs. Teach the 45-rule at Learner band.

### 19. Logic Grid Puzzles
- 3 people × 3 attributes (800) → 4×4 (1400) → 5×5 with negative-only clues (2000+).
- **Format:** tap-to-mark ✔/✘ grid, clues sidebar.

### 20. Set Card Game
- Find the SET among dealt cards. 9 cards (800) → 12 (1300) → 15 + "exactly how many
  sets exist?" meta-questions (1900+). Timed — pure pattern-vision sport.

## GROUP D — Sequential / Planning Puzzles (interactive)

### 21. Tower of Hanoi
- 3 disks (800) → 4 (1100) → 5 (1400) → 6 (1800) → 7 with move-limit = optimal (2200).
- **Stars tied to move efficiency**, not just completion.

### 22. Sliding Tile Puzzle
- 3×3 (800–1400) → 4×4 (1500–2100) → 4×4 under move-par (2200+).

### 23. River Crossing Puzzles
- Wolf-goat-cabbage (800) → missionaries & cannibals (1300) → bridge-and-torch with
  time budget (1700) → jealous-husbands variants (2100+).
- **Format:** tap entities onto the boat; state machine validates.

### 24. Memory Matrix *(appended — gamified recall)*
- Grid flashes 2s, reproduce it. 3×3/4 cells → 5×5/10 cells → sequences shown in order (2000+).

## GROUP E — Action

### 25. Reflex Duel ⚡ (the original game, now one challenge type)
- Strike / Trap / Target / Sequence / Math-Flash rounds, best-of-7.
- Appears as a **1v1 challenge mode and Arena tiebreaker** — when two minds are equal,
  nerves decide.

---

## Where each category appears

| Mode | Pull |
|---|---|
| **Daily Problem** | 1 hand-tuned question/day, rotating category, rating ≈ your overall + 100. Streak = coins. |
| **Solve** | All 25 categories × 18 levels × 30 questions ≈ **13,500 questions** of structured practice. |
| **1v1** | Fast categories (A, B, Set, Memory, Reflex). 7-question race. Free or coin-wagered. |
| **Arena (up to 8)** | 10 mixed questions from groups A+B, 15s each. Entry-fee rooms pay winner 60% / runner-up 25% of the pot (house 15%). |

## Difficulty engineering notes (for implementation)

1. Every generator takes a **rating r (800–2500)** and returns a question whose
   parameters (operand size, steps, grid size, clue count, time par) are functions of r.
2. **Distractors are modelled mistakes** — sign slips, off-by-one, unit confusion —
   so wrong options feel painfully plausible at every level.
3. **Seeded RNG:** Solve levels are seeded by (category, level) so a level is the same
   on retry — mastery is measurable. Duels/Arena use fresh seeds. Daily is date-seeded
   so the whole world gets the same problem.
4. **Par times** shrink ~20% per band; stars require both accuracy and pace.
5. Boss questions (Q28–30) preview the next level — the cliffhanger that sells "one more level".
