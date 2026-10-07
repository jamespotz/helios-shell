import QtQuick
import QtQuick3D

// A small, transparent viewport with shared lighting for every weather object.
View3D {
    id: root
    property bool sunny: false
    property bool cloudy: false
    property bool wet: false
    property bool severe: false
    property bool snow: false
    property bool storm: false
    property bool foggy: false
    property bool motionEnabled: false
    property real drift: 0
    property var cloudLayers: []
    property real fall: 0
    property real flash: 0
    readonly property bool flashingAllowed: root.motionEnabled && root.storm
    readonly property real flashIntensity: root.flashingAllowed ? root.flash : 0
    readonly property bool precipitationAnimating: precipitationMotion.running
    readonly property var cloudObjects: cloudModels
    readonly property var precipitationObjects: precipitationModels
    onFlashingAllowedChanged: if (!root.flashingAllowed) root.flash = 0

    camera: sceneCamera
    environment: SceneEnvironment {
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.Medium
        fog: Fog {
            enabled: root.foggy
            color: "#8c97a5"
            density: 0.35
            depthEnabled: true
            depthNear: 480
            depthFar: 850
        }
    }
    OrthographicCamera {
        id: sceneCamera
        z: 600
        clipNear: 1
        clipFar: 1200
    }
    DirectionalLight {
        eulerRotation: Qt.vector3d(-35, -30, 0)
        color: "#fff1df"
        ambientColor: "#292e36"
        brightness: 1.2 + root.flashIntensity * 0.9
        castsShadow: true
        shadowMapQuality: Light.ShadowMapQualityLow
        shadowFactor: 55
        shadowBias: 0.1
        shadowFilter: 4
    }
    DirectionalLight {
        eulerRotation: Qt.vector3d(15, 120, 0)
        color: "#96b0d5"
        brightness: 0.5
    }
    PrincipledMaterial {
        id: cloudMaterial
        baseColor: root.severe ? "#a7adb6" : root.wet ? "#c9ced5" : "#f4f6f9"
        roughness: 1
        specularAmount: 0.06
        // Lifts the shaded side so lobes read as soft, matte puffs.
        emissiveFactor: Qt.vector3d(0.16, 0.17, 0.19)
    }
    PrincipledMaterial {
        id: rainMaterial
        baseColor: "#88bddb"
        roughness: 0.18
        specularAmount: 0.8
    }
    PrincipledMaterial {
        id: snowMaterial
        baseColor: "#e6edf4"
        roughness: 0.65
    }

    Model {
        objectName: "weatherSun3D"
        readonly property real diameter: root.cloudy ? 112 : 142
        visible: root.sunny
        source: "#Sphere"
        x: root.cloudy ? 18 + diameter / 2 - root.width / 2 : 0
        y: root.height / 2 - (root.cloudy ? 18 : 38) - diameter / 2
        z: -85
        readonly property real size: diameter / 100 * (root.motionEnabled ? 1 + root.drift / 120 : 1)
        scale: Qt.vector3d(size, size, size)
        materials: PrincipledMaterial {
            baseColor: "#f4b332"
            roughness: 0.32
            specularAmount: 0.55
            emissiveFactor: Qt.vector3d(0.18, 0.07, 0.01)
        }
    }
    Repeater3D {
        id: cloudModels
        model: root.cloudLayers
        Node {
            id: cluster
            required property int index
            required property var modelData
            objectName: "weatherCloud3D_" + index
            readonly property real projectedWidth: root.width * modelData.size
            readonly property real projectedHeight: Math.min(projectedWidth * 0.64, root.height * (1 - modelData.y) - 4)
            x: root.width * modelData.x + projectedWidth / 2 - root.width / 2
            y: root.height / 2 - root.height * modelData.y - projectedHeight / 2
                - (root.motionEnabled ? root.drift * modelData.pace : 0)
            z: index * 12
            scale: Qt.vector3d(projectedWidth / 100, projectedHeight / 65, projectedWidth / 100)

            Repeater3D {
                // Round lobes: a dominant dome, a right shoulder, and smaller puffs on top and left.
                model: [
                    {x: -15, y: 5, z: -10, s: 0.32},
                    {x: 10, y: 14, z: -14, s: 0.23},
                    {x: 22, y: 12, z: -16, s: 0.12},
                    {x: -38, y: -10, z: -2, s: 0.23},
                    {x: -27, y: -8, z: 2, s: 0.27},
                    {x: 36, y: -4, z: 0, s: 0.28},
                    {x: 6, y: -4, z: 8, s: 0.45}
                ]
                Model {
                    required property var modelData
                    source: "#Sphere"
                    position: Qt.vector3d(modelData.x, modelData.y, modelData.z)
                    scale: Qt.vector3d(modelData.s, modelData.s, modelData.s)
                    materials: cloudMaterial
                }
            }
        }
    }
    Repeater3D {
        id: precipitationModels
        model: root.wet ? (root.severe ? 18 : 9) : root.snow ? 12 : 0
        Node {
            required property int index
            x: ((index * 37 % 97) / 97 - 0.5) * root.width * 0.84
            y: root.height * 0.05 - ((index / Math.max(1, precipitationModels.count)
                + (root.motionEnabled ? root.fall : 0)) % 1) * root.height * 0.52
            z: 100 + index % 3 * 8
            eulerRotation.z: root.snow ? 0 : -12
            readonly property real size: 0.8 + index % 3 * 0.2
            scale: Qt.vector3d(size, size, size)
            Model {
                source: "#Sphere"
                scale: root.snow ? Qt.vector3d(0.025, 0.025, 0.025) : Qt.vector3d(0.024, 0.05, 0.024)
                castsShadows: false
                receivesShadows: false
                materials: root.snow ? snowMaterial : rainMaterial
            }
            Model {
                visible: !root.snow
                source: "#Cone"
                y: 2.3
                scale: Qt.vector3d(0.024, 0.035, 0.024)
                castsShadows: false
                receivesShadows: false
                materials: rainMaterial
            }
        }
    }
    Node {
        visible: root.flashIntensity > 0
        z: 140
        y: -15
        Repeater3D {
            model: [
                {x: -6, y: 15, angle: -25, length: 26},
                {x: -4, y: -7, angle: 38, length: 25},
                {x: -8, y: -28, angle: -24, length: 24}
            ]
            Model {
                required property var modelData
                source: "#Cylinder"
                x: modelData.x
                y: modelData.y
                eulerRotation.z: modelData.angle
                scale: Qt.vector3d(0.025, modelData.length / 100, 0.025)
                castsShadows: false
                receivesShadows: false
                materials: PrincipledMaterial {
                    baseColor: "#e4efff"
                    emissiveFactor: Qt.vector3d(1, 1, 1)
                }
            }
        }
    }
    NumberAnimation on fall {
        id: precipitationMotion
        objectName: "weatherPrecipitationMotion"
        from: 0
        to: 1
        duration: root.snow ? 3600 : 1200
        loops: Animation.Infinite
        running: root.motionEnabled && precipitationModels.count > 0
    }
    SequentialAnimation on flash {
        running: root.flashingAllowed
        loops: Animation.Infinite
        PauseAnimation { duration: 6000 }
        NumberAnimation { from: 0; to: 1; duration: 25 }
        PauseAnimation { duration: 40 }
        NumberAnimation { to: 0; duration: 180 }
    }
}
