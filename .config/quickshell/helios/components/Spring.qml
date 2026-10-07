import QtQuick
import "../services"

// Shell-wide motion spring for geometry (x, y, size, scale, rotation).
// Uses the Motion preset's UI spring (Config.uiSpring*), stiffer than the
// Island's morph. Color, opacity and looping animations stay timed. Gate the
// enclosing Behavior with `enabled: !Config.reducedMotion`.
SpringAnimation {
    spring: Config.uiSpringStiffness
    damping: Config.uiSpringDamping
    // Fine enough that small scale changes (0.96 → 1) settle, not snap.
    epsilon: 0.002
}
