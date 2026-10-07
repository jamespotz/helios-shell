import QtQuick
import "../services"

// Shell-wide motion spring for geometry (x, y, size, scale, rotation).
// Follows the Island's spring so the Motion preset sets the whole shell's
// feel. Color, opacity and looping animations stay timed. Gate the
// enclosing Behavior with `enabled: !Config.reducedMotion`.
SpringAnimation {
    spring: Config.islandSpringStiffness
    damping: Config.islandSpringDamping
    // Fine enough that small scale changes (0.96 → 1) settle, not snap.
    epsilon: 0.002
}
