# AGENTS.md

## Project Philosophy

This is a **QML desktop shell** inspired by Apple's design principles: clarity, restraint, consistency, direct manipulation, meaningful motion, and attention to detail.

Do **not** clone macOS. Apply the principles while maintaining the shell's own visual identity.

## Design Rules

- Prefer clarity over decoration.
- Keep interfaces visually calm and focused.
- Use spacing, typography, and hierarchy before borders or extra containers.
- Use progressive disclosure instead of showing every option at once.
- Color should communicate meaning, not decorate.
- Motion should explain transitions and state changes.
- Keep animations fast, subtle, and interruptible.
- Use consistent spacing, typography, radii, colors, and animation tokens.
- Support light/dark themes, scaling, localization, keyboard navigation, and reduced motion.
- Avoid unnecessary blur, gradients, shadows, borders, and nested rounded rectangles.

## QML Guidelines

- Prefer declarative bindings over imperative state synchronization.
- Keep a single source of truth for state.
- Build reusable components instead of duplicating UI.
- Keep components focused on one responsibility.
- Separate system/business logic from presentation where practical.
- Use semantic APIs and theme values rather than hardcoded styling.

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

Every interactive component should consider:

- default
- hover
- pressed
- focused
- disabled
- selected/active

Interactions should provide immediate feedback and behave predictably with both pointer and keyboard.

## Performance

The shell must remain smooth under real workloads.

Avoid:

- unnecessary bindings
- constantly running animations
- excessive blur
- expensive layout recalculation
- unnecessary object creation
- heavy JavaScript in frame-sensitive paths

## Before Adding UI

Reuse existing:

1. components
2. design tokens
3. interaction patterns
4. animation conventions

Do not introduce a new visual pattern when the shell already has one for the same problem.

## Final Rule

When choosing between solutions, prefer the one that is:

**clearer, simpler, quieter, more consistent, more accessible, and easier to maintain.**
