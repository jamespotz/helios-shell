# AGENTS.md

Terminology such as **Island**, **Island destination**, and **Launcher** is defined in `CONTEXT.md`. Use those terms consistently instead of introducing ad hoc synonyms.

## Layout

`.config/quickshell/helios/`:

- `components/` — reusable UI such as buttons, fields, and panels
- `services/` — system/business logic and QML singletons such as Audio, Bluetooth, and Calendar
- `modules/` — feature surfaces such as `island/`, `lock/`, `osd/`, and `polkit/`

File names in `modules/island/` say their role, using the `CONTEXT.md` terms:

- `*Destination` — an Island destination (`VolumeDestination.qml`); registered in `services/IslandNavigation.qml`
- `Island*` — the Island's own structure (`IslandIdle`, `IslandPeek`, `IslandDestinationHost`)
- `*Widget` — a widget in the idle or peek state
- `*Card` — an alert card
- no suffix — a part used inside one destination (`WallpaperCarousel`)

The suffix also keeps type names clear of service singletons (`WeatherWidget` beside `Weather`). Theme exporters in `services/` are `ThemeExport<App>`; Settings window pages in `modules/settings/` are `*Settings`.
- `data/` — static data such as emoji and themes

## Project Philosophy

Helios is a **QML desktop shell** inspired by Apple's design principles: clarity, restraint, consistency, direct manipulation, meaningful motion, and attention to detail.

Do **not** clone macOS. Apply those principles while maintaining Helios's own visual identity.

When designing or reviewing motion, gestures, sound, materials, or typography, load the `apple-design` skill; the Motion & Sound rules below are how its principles map onto this codebase.

## Before Making Changes

Before implementing something new:

1. Inspect nearby implementations.
2. Search for existing components, services, design tokens, and interaction patterns that solve the same or a similar problem.
3. Reuse or extend existing patterns when practical.
4. Understand the current source of truth for any state you intend to modify.

Keep it simple. Do not overcomplicate things.

Preserve existing behavior and visual conventions unless the task explicitly requires changing them.

Keep changes scoped to the task. Do not refactor unrelated code unless required for correctness.

## Design Rules

- Prefer clarity over decoration.
- Keep interfaces visually calm and focused.
- Use spacing, typography, and hierarchy before borders or extra containers.
- Use progressive disclosure instead of showing every option at once.
- Use color to communicate meaning rather than decoration.
- Use existing spacing, typography, radius, color, and animation tokens consistently.
- Support light/dark themes, scaling, localization, keyboard navigation, and reduced motion where applicable.
- Avoid unnecessary blur, gradients, shadows, borders, and nested rounded rectangles.
- Do not introduce a new visual pattern when an established pattern already solves the same problem.

## Motion & Sound

Motion explains a state change; sound confirms one. Both are **interruptible**, **calm**, and caused by something the user can see.

- **Geometry** (x, y, size, scale, rotation) uses `components/Spring.qml`, which follows the Motion preset (`Config.uiSpring*`). The Island morph and satellites use their own `Config.islandSpring*` / `Config.satelliteSpring*`. A spring retargets from the current value and velocity, so new input mid-animation stays continuous; a timed `NumberAnimation` restarts from zero velocity.
- Springs are critically damped (damping `1.0`) by default. Overshoot belongs to the user's "bouncy" preset or motion that carries momentum, such as a flick.
- **Color, opacity, and looping animations** stay timed, using `Config.animFast` / `animMedium` / `animSlow` with `Easing.OutCubic`. Use a raw millisecond value only for a deliberate one-off (a lightning flash), with a comment.
- **Reduce motion** (`Config.reducedMotion`): put `enabled: !Config.reducedMotion` on every geometry `Behavior`, and add `&& !Config.reducedMotion` to the `running` of every loop, shake, and flash. Opacity and color fades may stay, since they aid comprehension without moving anything. Keep the state legible without the motion (an error border alongside the shake).
- Loops (`loops: Animation.Infinite`, `FrameAnimation`) run only while their item is visible and their state is live.
- Enter and exit along the same path, anchored to the element that triggered them.
- **Sound** goes through `services/AlertSounds.qml`, the single source of truth: add a kind to `soundFor`, and add interface kinds to `interfaceKinds`. Alert kinds follow `Config.alertSounds`; interface kinds follow `Config.interfaceSounds`. Both are off by default.
- Trigger sound from the same signal that drives the motion, so the two land on the same frame. Throttle anything repeatable (volume keys).
- Shared controls make their own sound, so new uses get it for free: buttons, chips, rows, and menus tap on commit (click, Return, or Space, never on press or hover); `Toggle` plays a higher click turning on and a lower one turning off; sliders tick once per tenth of the range crossed. These are WAVs in `data/sounds/`, listed in `fileFor`. Don't use QtMultimedia (`SoundEffect`): its PipeWire device watcher spins on a dead socket when a Bluetooth sink disappears and hangs the shell.
- Reserve sound for meaningful moments (a commit, an arrival, a failure). Hover, focus, and routine navigation stay silent.
- No haptics: Linux has no standard haptics API.

## QML Guidelines

- Prefer declarative bindings over imperative state synchronization.
- Maintain a single source of truth for state.
- Keep components focused on a clear responsibility.
- Separate system/business logic from presentation where practical.
- Build reusable components when they reduce meaningful duplication.
- Do not introduce abstractions that make simple code harder to understand.
- Prefer semantic APIs and theme values over hardcoded styling.
- Avoid duplicating state merely to mirror another property's value.
- Avoid unnecessary JavaScript when a QML binding or declarative construct expresses the behavior clearly.

Prefer:

```qml
color: Theme.textPrimary
spacing: Theme.spacingMedium
```

instead of:

```qml
color: "#ffffff"
spacing: 13
```

## Interaction

Interactive components should support all states relevant to their behavior, including:

- default
- hover
- pressed
- focused
- disabled
- selected/active

Provide immediate feedback for user actions.

Pointer and keyboard interaction should be predictable and consistent with similar components elsewhere in the shell.

Do not make important functionality available only through hover.

## Performance

The shell must remain smooth under real workloads.

Avoid:

- expensive or redundant bindings, especially in frequently updated paths
- constantly running animations
- excessive blur
- unnecessary layout recalculation
- unnecessary object creation
- heavy JavaScript in frame-sensitive paths
- polling when an event, signal, or binding can provide the same information

Prefer work that occurs in response to actual state changes rather than continuously.

## Git & Repository Safety

- Never commit code unless explicitly asked to do so.
- Never push code unless explicitly asked to do so.
- Never create or open a pull request unless explicitly asked to do so.
- Do not assume that permission to modify files also grants permission to commit, push, or create a pull request.
- Leave repository history and remote branches unchanged unless the user explicitly requests otherwise.

## Commands

```sh
./.config/hypr/helios-reload.sh          # run/relaunch (kills existing instances, preloads jemalloc)
./tests/run-<name>-test.sh               # run a single test; see tests/ for the full list
./link.sh                                # symlink new/changed files into $TARGET (default $HOME)
```

Don't launch `quickshell -c helios` directly: it skips jemalloc (RSS grows past 1GB) and leaves duplicate instances running.

Quickshell hot-reloads in place when a file under `helios/` is saved. This works because `link.sh` links `~/.config/quickshell/helios` as one directory. Saves that rename a temp file over the original sometimes miss the reload. If the UI looks stale, check `quickshell -c helios log` for `Reloading configuration...` or press `Super+Shift+R`. A hot reload re-creates singletons, so in-memory state is reset.

## Validation

After making a change:

1. Run the narrowest relevant automated test when one exists.
2. Reload or relaunch Quickshell when the change affects runtime QML.
3. Verify the affected interaction or UI state directly.
4. Check for QML/runtime errors introduced by the change.
5. Relaunch only via `./.config/hypr/helios-reload.sh`.

Do not claim a change works solely because the code looks correct.

## New or Changed Files

Run `./link.sh` when new or changed files need to be symlinked into `$TARGET`.

Before creating a new component, confirm that an existing component cannot reasonably be reused or extended.

## Final Rule

When choosing between otherwise valid solutions, prefer the one that is:

**clearer, simpler, quieter, more consistent, more accessible, more performant, and easier to maintain.**

When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision.
