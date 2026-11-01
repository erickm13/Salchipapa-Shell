pragma ComponentBehavior: Bound
// Ajustes > Shortcuts: qué apps salen como pestaña en el glosario de atajos (Super + /).
// Guarda las ocultas en Config.opt.keybindHiddenTabs (así las apps nuevas salen visibles).
import QtQuick
import "../common"

Item {
    id: root

    implicitHeight: content.implicitHeight

    function setShown(id: string, shown: bool): void {
        let hidden = Config.keybindHidden.filter(x => x !== id);
        if (!shown)
            hidden.push(id);
        // Siempre al menos una pestaña
        if (hidden.length >= Config.keybindApps.length)
            return;
        Config.opt.keybindHiddenTabs = hidden.join(",");
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(4)

        SettingGroup {
            title: "Shortcuts glossary (Super + /)"
            width: parent.width

            Repeater {
                model: Config.keybindApps
                delegate: SettingToggleRow {
                    required property var modelData
                    label: modelData.label
                    sublabel: modelData.sub
                    checked: !Config.keybindHidden.includes(modelData.id)
                    onToggled: root.setShown(modelData.id, !checked)
                }
            }
        }

        Text {
            width: parent.width
            text: "Each app is a tab in the glossary: Tab / Shift+Tab switch between them. At least one stays visible."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }
}
