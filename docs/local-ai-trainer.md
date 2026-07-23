# Local AI Trainer

MYNDASH's trainer runs entirely on-device. It does not call an LLM, require an API
key, or upload training telemetry.

## How it works

1. `AppData` keeps a bounded 480-event timeline containing only game/domain,
   result, duration, par time and timestamp. Typed answers and personal text are
   not stored in this timeline.
2. `LocalCoachEngine` combines that timeline with existing answer aggregates,
   mistakes, progression, stars, activity and match history.
3. Natural-language questions are tokenized, lightly normalized and expanded
   with game aliases.
4. A BM25 sparse retriever ranks a curated strategy corpus covering math,
   problem solving, board games, memory, language, reaction and competitive
   modes.
5. A deterministic response composer combines the retrieved method with the
   player's evidence. It never invents a score when a game has not been
   measured.

## Coaching signals

- Accuracy and average answer time
- Fast-wrong answers (impulse)
- Slow-right answers (method understood, recall not yet automatic)
- Level progression and stars
- Practice quality and completion time
- Match form and activity consistency
- Six skill groups: Calculation, Logic, Spatial, Memory, Language and
  Competition

## Storage and performance

The timeline is capped at 480 compact events. Charts use static,
`RepaintBoundary`-isolated custom painters, so the telemetry screen has no
continuous animation or chart-package dependency.
