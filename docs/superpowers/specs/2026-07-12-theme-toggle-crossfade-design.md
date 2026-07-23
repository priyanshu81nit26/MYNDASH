# Theme Toggle — Smooth Cross-Fade + Home Icon (Round 1)

Date: 2026-07-12
Status: Approved

## Problem

Toggling Arcade (light) ↔ Night (dark) only visibly transitions the bottom
`NavigationBar`. The rest of the screen snaps or appears not to change.

**Root cause:** `NavigationBar` reads `Theme.of(context)` (an InheritedWidget)
so it repaints on theme change even when declared `const`. Every other surface
reads colors from static getters in `DC` (`theme_district.dart`) that return one
of two flat `Color`s by a boolean. Those getters are evaluated during a screen's
`build`; the home tabs are instantiated `const`, so an ancestor rebuild never
reaches them and their colors never re-evaluate mid-transition.

## Scope

The theme switch is being removed from the drawer, so the **only** toggle entry
point becomes the home header. Therefore the cross-fade only has to look smooth
on the home surface — pushed screens (Solve, Games, boards) are always entered
*after* a toggle and build with the final theme already.

## Design

### 1. Animated theme value (`theme_district.dart`)
- Add `ThemeCtl.t` — a `ValueNotifier<double>` (0.0 = Arcade, 1.0 = Night),
  animated. `mode` (int) stays the persisted source of truth; `isDark`/`isLight`
  still derive from `mode` for the many boolean call sites.
- Change the primary `DC` color getters (`bg`, `bg2`, `text`, `dim`, `fg`,
  `cyan`, `violet`, `magenta`, `lime`, `amber`, `danger`, `electric`) from
  `_d ? a : b` to `Color.lerp(lightColor, darkColor, ThemeCtl.t.value)!`.
  Rating-band helpers (`band`, `contestColor`) keep their boolean picks — they
  choose among many colors by rating, not a light/dark pair; a one-frame flip in
  a small chip is negligible.

### 2. Drive the animation at the app root (`main.dart`)
- `DistrictApp` becomes `StatefulWidget` with `SingleTickerProviderStateMixin`.
- Own an `AnimationController` (320 ms) + `CurvedAnimation(easeInOutCubic)`,
  initialized to the persisted `mode`.
- Listen to `ThemeCtl.mode`; on change, `animateTo(mode)`. The curve's listener
  writes `ThemeCtl.t.value = curve.value` each frame.
- Wrap the `MaterialApp` build in `AnimatedBuilder(animation: curve)` and build
  `home:` fresh (non-`const`) each frame so the home shell re-reads `DC` colors.

### 3. Cross-fade the backdrop (`ui/glass.dart` — `ShaderBackground`)
- Replace `isDark ? _NightBackdrop() : _ArcadeBackdrop()` with a `Stack` that
  paints `_ArcadeBackdrop` at `opacity 1-t` and `_NightBackdrop` at `opacity t`,
  omitting whichever is fully transparent at rest (no double-paint when idle, so
  zero cost on pushed screens).

### 4. Home shell rebuilds per frame (`screens/district_home.dart`)
- Remove `const` from the tab instantiations in the `switch` so a root rebuild
  cascades into `_HomeTab` (its `State` persists — tab index & scroll intact).
- Add a sun/moon toggle button to the top-right of the home header, left of the
  menu icon: `Icon(ThemeCtl.isDark ? Icons.light_mode_rounded :
  Icons.dark_mode_rounded)` → `ThemeCtl.toggle()`. (Moon shown in light mode =
  "switch to Night".)
- Remove the theme `ListTile` + its divider from `_MyndDrawer`.

## Files touched
`theme_district.dart`, `main.dart`, `ui/glass.dart`, `screens/district_home.dart`.
No new dependencies — `AnimationController` covers it.

## Out of scope (later rounds)
Onboarding centering/fluid text, board & question UI restyle, menu redesign,
emoji cleanup.
