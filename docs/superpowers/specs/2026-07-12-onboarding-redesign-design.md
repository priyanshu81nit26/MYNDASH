# Onboarding Redesign (Round 2)

Date: 2026-07-12
Status: Approved

## Problem
Onboarding reads "AI-generated": emoji everywhere, quiz questions pinned to the
top of the screen with gradient "fluid" titles, chip answers. Wanted: cleaner
iOS feel, no emojis in questions, one centered question per screen.

## Two surfaces
1. **Intro slides** (`OnboardingFlow._pages`) — floating 3D glass tile with an
   emoji + gradient title, already centered.
2. **About You** (`AboutYouScreen`) — age + 6 questions, pinned near top, emoji
   titles/options, chip answers.

## Design

### Intro slides
- Change `_pages` records from `(emoji, title, body)` to `(IconData, title, body)`.
  Icons: psychology, extension, sports_esports, bolt, groups, emoji_events,
  auto_awesome.
- `Hero3D` takes `IconData icon` instead of `String emoji`; renders an `Icon`
  (white, size ≈ tile·0.4) inside the same floating/tilting glass tile.
- Strip the remaining emojis from slide body copy (e.g. "Arcade ☀️ or Night 🌙"
  → "Arcade or Night"). Keep the gradient brand title — it's the hero, not a
  question.

### About You
- New shared `_centeredQuestion(title, subtitle?, options)` layout: vertically
  centered `Column` (min size) in a `SingleChildScrollView`, plain bold centered
  title (no ShaderMask), optional dim subtitle.
- New shared `_optionRow(label, selected, onTap)`: full-width rounded row, label
  left, check-circle right, accent border/fill when selected. Replaces the chip
  `Wrap` for both age and questions.
- Age page and every question page route through those two helpers.
- Remove all emojis from `_ages`, `_questions` titles, and options.

## Files touched
`screens/onboarding.dart` only.

## Out of scope (later rounds)
Board/question UI in Solve & Games (round 3), menu redesign + broader emoji
cleanup (round 4). `FirstTimeGuide` in-app coach cards keep their emojis for now.
