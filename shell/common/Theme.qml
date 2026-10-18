pragma Singleton
// Paleta de la shell. Lee el esquema ACTUAL de caelestia (~/.local/state/caelestia/scheme.json)
// y se actualiza en vivo al aplicar un tema. Si no existe, usa Catppuccin Mocha como fallback.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Mapa de roles Material 3 -> hex (sin #) del esquema activo
    property var c: ({})
    property string schemeName: "Salchipapa"
    property string schemeFlavour: "base"

    function col(role: string, fallback: string): string {
        const v = c[role];
        return v ? "#" + v : fallback;
    }

    function fontPx(size: real): int {
        return Math.max(8, Math.round(size * Config.appearanceFontSize / 15));
    }

    function space(units: real): int {
        return Math.max(0, Math.round(units * Config.appearanceSpacingUnit / 4));
    }

    function alpha(value: color, percent: real): color {
        return Qt.rgba(value.r, value.g, value.b, Math.max(0, Math.min(1, percent / 100)));
    }

    function iconPx(size: real): int {
        return Math.max(8, Math.round(size * Config.appearanceIconSize / 18));
    }

    // Paleta de la tabla @define-color que acompaña al tema.
    readonly property var palette: ({
        bg0: "#040e0d", bg1: "#0a1816", bg2: "#0f211f", bg3: "#152a26", bg4: "#1d3631",
        fg: "#f5e2c5", red: "#ff6048", orange: "#ffa478", yellow: "#f5cd5b",
        green: "#7ad9a8", aqua: "#3dd1b0", blue: "#5fc8d4", purple: "#e89aa8",
        grey0: "#3a1a35", grey1: "#5a4d3e", grey2: "#c4b09a"
    })

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const scheme = JSON.parse(text());
                root.c = scheme.colours ?? ({});
                root.schemeName = scheme.name ?? "Custom";
                root.schemeFlavour = scheme.flavour ?? scheme.variant ?? "default";
            } catch (e) {
                root.c = ({});
                root.schemeName = "Salchipapa";
                root.schemeFlavour = "base";
            }
        }
    }

    // --- Superficies ---
    readonly property color base: palette.bg2
    readonly property color mantle: palette.bg1
    readonly property color crust: palette.bg0
    readonly property color surface0: palette.bg3
    readonly property color surface1: palette.bg4
    readonly property color overlay0: palette.grey0
    readonly property color overlay1: palette.grey1
    readonly property color overlay2: palette.grey2
    readonly property color text: palette.fg
    readonly property color subtext: palette.grey2

    // --- Acentos (mapeados a roles M3; el acento principal es "green" = primary) ---
    readonly property color schemePrimary: palette.green
    readonly property color green: Config.appearanceAccent !== "" ? "#" + Config.appearanceAccent : schemePrimary
    readonly property color shadow: col("shadow", "#000000")
    readonly property color red: palette.red
    readonly property color orange: palette.orange
    readonly property color yellow: palette.yellow
    readonly property color aqua: palette.aqua
    readonly property color blue: palette.blue
    readonly property color sapphire: palette.aqua
    readonly property color peach: palette.orange
    readonly property color mauve: palette.purple
    readonly property color purple: palette.purple

    // --- Isla ---
    readonly property color islandBg: palette.bg0
    readonly property color islandBorder: "#1affffff"

    // --- Paneles: superficies neutras para mantener el contraste de la referencia ---
    readonly property color panelBg: "#000000"
    readonly property color panelCard: Qt.lighter(Config.appearanceColorBurst ? col("surfaceContainerLow", "#151513") : "#151513", 1 + Config.appearanceSurfaceLift / 100)
    readonly property color panelCardHi: Qt.lighter(Config.appearanceColorBurst ? col("surfaceContainerHigh", "#22211f") : "#22211f", 1 + Config.appearanceSurfaceLift / 100)
    readonly property color divider: alpha(panelCardHi, Config.appearanceDividerStrength)
    readonly property color secondaryText: alpha(subtext, Config.appearanceSecondaryText)
    readonly property color tertiaryText: alpha(overlay0, Config.appearanceTertiaryText)
    readonly property color hoverFill: alpha(green, Config.appearanceHoverFill)
    readonly property color selectedFill: alpha(green, Config.appearanceSelectedFill)
    readonly property color modalDim: alpha("#000000", Config.appearanceModalDim)
    readonly property int radiusSmall: Config.appearanceSmallRadius
    readonly property int radiusMedium: Config.appearanceMediumRadius
    readonly property int radiusLarge: Config.appearanceLargeRadius
    readonly property string bodyFontFamily: Config.appearanceBodyFont !== "" ? Config.appearanceBodyFont : Qt.application.font.family
    readonly property string displayFontFamily: Config.appearanceDisplayFont !== "" ? Config.appearanceDisplayFont : bodyFontFamily
    readonly property int iconWeight: Math.max(100, Math.min(700, 100 + Config.appearanceIconStroke * 30))

    // --- Curvas de animación (Material 3) ---
    readonly property bool reduceMotion: Config.motionReduce || Config.gameMode
    readonly property var spring: reduceMotion ? [0.2, 0, 0, 1, 1, 1] : [0.38, 1 + (Config.motionBounce / 100 * 0.525), 0.22, 1, 1, 1]
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property int movementDuration: reduceMotion ? 0 : Config.motionMovementDuration
    readonly property int fadeDuration: reduceMotion ? 0 : Config.motionFadeDuration
    readonly property int hoverDuration: reduceMotion ? 0 : Config.motionHoverDuration
}
