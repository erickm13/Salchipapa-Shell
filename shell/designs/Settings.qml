pragma ComponentBehavior: Bound
// Panel de ajustes de la shell. Ventana propia (modal, centrada): sidebar de categorías +
// buscador + contenido. Fase 1: "Bar & Island" funcional (escribe en Config, persistente);
// el resto de categorías son marcadores por ahora.
import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../common"
import "../services"

FloatingWindow {
    id: win

    // La ventana se crea al abrir el panel (LazyLoader en shell.qml) en el monitor enfocado en ese
    // momento (Overlay.settingsMonitor): la escala sale de ese monitor y no cambia mientras está abierta.
    readonly property ShellScreen openScreen: Quickshell.screens.find(s => s.name === Overlay.settingsMonitor) ?? Quickshell.screens[0]

    visible: true
    color: "transparent"
    title: "Salchipapa Settings"
    screen: openScreen
    // Todo el panel se diseña a 1080×620 y se amplía con `scale` (el texto sigue nítido): para
    // agrandarlo o achicarlo entero basta con cambiar el 1.3. Si la pantalla no da, se reduce.
    readonly property real uiScale: Math.min(1.3, (openScreen.width - 96) / 1080, (openScreen.height - 144) / 620)
    implicitWidth: Math.round(1080 * uiScale)
    implicitHeight: Math.round(620 * uiScale)

    // Ordenadas por uso: las que más se tocan primero. Las páginas se eligen por índice
    // (win.category === N), así que al reordenar hay que renumerar esas condiciones.
    readonly property var categories: [
        {
            name: "Appearance",
            icon: "palette",
            desc: "Colors, theme and wallpaper."
        },
        {
            name: "Bar & Island",
            icon: "crop_16_9",
            desc: "Island shape and size, notch and Game Mode bar."
        },
        {
            name: "Display",
            icon: "monitor",
            desc: "Monitor position, resolution, refresh rate and orientation."
        },
        {
            name: "Notifications",
            icon: "notifications",
            desc: "Notifications and Do Not Disturb."
        },
        {
            name: "Media",
            icon: "music_note",
            desc: "Media player and controls."
        },
        {
            name: "Control Center",
            icon: "tune",
            desc: "Quick toggles and control center layout."
        },
        {
            name: "Lock Screen",
            icon: "lock",
            desc: "Lock screen clock, background and content."
        },
        {
            name: "Clock & Date",
            icon: "schedule",
            desc: "Clock, time format and calendar."
        },
        {
            name: "Launcher",
            icon: "search",
            desc: "Size of the app launcher (Super + Space)."
        },
        {
            name: "Motion",
            icon: "animation",
            desc: "Animations and transitions."
        },
        {
            name: "System",
            icon: "settings",
            desc: "Touchpad, blur, processes and shell info."
        },
        {
            name: "Login & Boot",
            icon: "login",
            desc: "Login (SDDM) and boot (GRUB) themes."
        }
    ]

    // La ventana se destruye al cerrar: la categoría abierta se guarda en Overlay
    property int category: Overlay.settingsCategory
    onCategoryChanged: Overlay.settingsCategory = category
    property string query: ""
    property string currentScheme: "Dynamic"

    // Si los colores actuales salen del fondo, volver a generarlos al cambiar estilo o intensidad
    function regenerateWallpaperColors(): void {
        if (win.currentScheme.toLowerCase() === "dynamic" && Wallpaper.animated === "" && Wallpaper.current !== "")
            regenProc.exec([Quickshell.shellDir + "/../scripts/wallpaper.sh", "--colors-only", Wallpaper.current]);
    }
    Process { id: regenProc }

    readonly property var accentColors: [Theme.green, Theme.red, Theme.orange, Theme.yellow, Theme.aqua, Theme.blue, Theme.purple]
    // Fuentes de interfaz recomendadas primero (si están instaladas); luego el resto, sin las de
    // iconos/símbolos ni las variantes de escritura de Noto, que no sirven como texto de la shell.
    readonly property var suggestedFonts: ["Google Sans Flex", "Inter", "Inter Display", "Geist", "Rubik"]
    readonly property var installedFonts: {
        const all = Qt.fontFamilies();
        const picks = suggestedFonts.filter(f => all.includes(f));
        const skip = /Symbols|Icons|Awesome|Webdings|Standard Symbols|Music|Noto (Sans|Serif|Kufi|Naskh|Nastaliq|Rashi|Fangsong|Traditional|Znamenny) \S/;
        const rest = all.filter(f => !picks.includes(f) && !skip.test(f)).sort();
        return ["System default"].concat(picks, rest);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/scheme"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: win.currentScheme = text().trim() || "Dynamic"
        onLoadFailed: win.currentScheme = "Dynamic"
    }

    function openThemeSelector(): void {
        Overlay.settings = false;
        Overlay.mode = "themes";
    }

    function openWallpaperSelector(): void {
        Overlay.settings = false;
        Overlay.mode = "wallpaper";
    }

    // ---- Buscador: secciones y ajustes ----
    // Sin texto, la barra lateral lista las secciones. Con texto, las secciones cuyo nombre
    // coincide y después los ajustes que coinciden ({ cat, setting }); elegir un ajuste abre su
    // sección y pone el foco en él.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const sections = categories.map((c, i) => ({ cat: i, setting: "" }));
        if (q === "")
            return sections;
        const out = sections.filter(r => categories[r.cat].name.toLowerCase().includes(q));
        for (const e of Overlay.settingsIndex)
            if (e.label.toLowerCase().includes(q))
                out.push({ cat: e.cat, setting: e.label });
        return out.slice(0, 40);
    }
    property int sel: 0 // resultado marcado mientras se busca
    onQueryChanged: sel = 0

    // ↑/↓ en el buscador: sin texto cambia de sección; con texto recorre los resultados
    // (y muestra la sección del resultado marcado)
    function stepResult(delta: int): void {
        if (query.trim() === "") {
            stepCategory(delta);
            return;
        }
        if (results.length === 0)
            return;
        sel = (sel + delta + results.length) % results.length;
        category = results[sel].cat;
    }

    // Sección anterior/siguiente entre todas (Ctrl+↑/↓ y ↑/↓ sin búsqueda)
    function stepCategory(delta: int): void {
        category = (category + delta + categories.length) % categories.length;
    }

    function openResult(r: var): void {
        if (!r)
            return;
        category = r.cat;
        if (r.setting === "")
            KeyNav.move(searchInput, true);
        else
            focusTimer.start(); // tras recolocar la columna, para que el ajuste quede a la vista
    }
    property string pendingSetting: results[sel]?.setting ?? ""
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: win.focusSetting(win.pendingSetting)
    }

    // Etiquetas de los controles visibles bajo `item`: la propiedad `label` de las filas y los
    // títulos en blanco o negrita de las filas hechas a mano (no los campos de texto ni iconos).
    function collectLabels(item: Item, out: var): void {
        // Los botones (señal clicked) no son ajustes, y de una fila con opciones solo cuenta su título
        if (typeof item.clicked === "function")
            return;
        if (item.options !== undefined) {
            if (typeof item.label === "string" && item.label !== "")
                out.push(item.label.trim());
            return;
        }
        const l = item.label;
        if (typeof l === "string" && l.trim() !== "")
            out.push(l.trim());
        else if (typeof item.text === "string" && item.echoMode === undefined && !String(item.font?.family).startsWith("Material")
                 && (Qt.colorEqual(item.color, "#ffffff") || item.font?.bold)) {
            const t = item.text.trim();
            if (t.length >= 3 && t.length <= 40)
                out.push(t);
        }
        for (const c of item.children)
            collectLabels(c, out);
    }

    // Recorre las secciones una vez por sesión de la shell (mostrar algunas páginas consulta
    // procesos o monitores, así que no se repite en cada apertura)
    function buildIndex(): void {
        const saved = category;
        const out = [];
        for (let i = 0; i < categories.length; i++) {
            category = i;
            const labels = [];
            for (const child of controlsCol.children)
                if (child.visible)
                    collectLabels(child, labels);
            for (const label of new Set(labels))
                out.push({ cat: i, label: label });
        }
        category = saved;
        Overlay.settingsIndex = out;
    }

    function findLabel(item: Item, label: string): Item {
        if (!item.visible)
            return null;
        if (item.label === label || (item.text === label && item.echoMode === undefined))
            return item;
        for (const c of item.children) {
            const hit = findLabel(c, label);
            if (hit)
                return hit;
        }
        return null;
    }

    function firstFocusable(item: Item): Item {
        for (const c of item.children) {
            if (!c.visible || !c.enabled)
                continue;
            if (c.activeFocusOnTab)
                return c;
            const hit = firstFocusable(c);
            if (hit)
                return hit;
        }
        return null;
    }

    // Foco en el control del ajuste: la propia fila si es enfocable o, si es un título, el
    // control enfocable más cercano de su fila (sube como mucho tres niveles)
    function focusSetting(label: string): void {
        const hit = findLabel(controlsCol, label);
        if (!hit) {
            KeyNav.move(searchInput, true);
            return;
        }
        let p = hit;
        for (let up = 0; p && p !== controlsCol && up < 4; up++, p = p.parent) {
            const target = p.activeFocusOnTab ? p : firstFocusable(p);
            if (target) {
                target.forceActiveFocus();
                return;
            }
        }
        KeyNav.ensureVisible(hit);
    }

    // ===== Card =====
    Rectangle {
        id: cardBg
        width: 1080
        height: 620
        scale: win.uiScale
        transformOrigin: Item.TopLeft
        // Dividido por la escala: las esquinas quedan del mismo radio que las de la pantalla
        radius: (Config.appearanceScreenCorners ? Config.appearanceScreenCornerRadius : 0) / win.uiScale
        color: Theme.panelBg
        border.width: 0
        border.color: Theme.divider

        focus: Overlay.settings
        // Al abrir, el foco en el buscador: ↑/↓ cambian de sección desde el primer momento
        // (con `focus: true` solo, al crearse la ventana a veces no lo recibía nadie)
        Component.onCompleted: {
            if (Overlay.settingsIndex.length === 0)
                win.buildIndex();
            Qt.callLater(() => searchInput.forceActiveFocus());
        }

        // Cambiar de sección desde cualquier parte, también con el foco en un control
        Shortcut {
            sequences: ["Ctrl+Down", "Ctrl+Tab", "Ctrl+PgDown"]
            onActivated: {
                win.stepCategory(1);
                searchInput.forceActiveFocus();
            }
        }
        Shortcut {
            sequences: ["Ctrl+Up", "Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
            onActivated: {
                win.stepCategory(-1);
                searchInput.forceActiveFocus();
            }
        }

        // Esc desde un control vuelve a la barra lateral; desde ahí cierra
        Keys.onEscapePressed: {
            if (searchInput.activeFocus)
                Overlay.settings = false;
            else
                searchInput.forceActiveFocus();
        }

        MouseArea {
            anchors.fill: parent // traga clics (no cierra)
        }

        // ---------- Sidebar ----------
        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 18
            anchors.bottomMargin: 18
            width: 220
            radius: parent.radius
            color: Theme.panelBg
            // Cuadra el borde derecho (tapa las esquinas redondeadas de ese lado)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 20
                color: Theme.panelBg
            }

            Rectangle {
                id: search
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 0
                height: 34
                radius: Theme.radiusSmall
                color: Theme.panelCard

                Text {
                    id: sIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.overlay1
                }
                TextInput {
                    font.family: Theme.bodyFontFamily
                    id: searchInput
                    anchors.left: sIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(13)
                    clip: true
                    focus: Overlay.settings
                    onTextChanged: win.query = text
                    Keys.onUpPressed: win.stepResult(-1)
                    Keys.onDownPressed: win.stepResult(1)
                    // Enter: con búsqueda abre el resultado marcado; sin ella, entra a los controles
                    function enterContent(): void {
                        if (win.query.trim() !== "")
                            win.openResult(win.results[win.sel]);
                        else
                            KeyNav.move(searchInput, true);
                    }
                    Keys.onReturnPressed: enterContent()
                    Keys.onEnterPressed: enterContent()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search Settings"
                        color: Theme.text
                        font: parent.font
                        visible: parent.text.length === 0
                    }
                    Keys.onEscapePressed: Overlay.settings = false
                }
            }

            ListView {
                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                clip: true
                spacing: 2
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: win.query.trim() === "" ? win.category : win.sel
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                // Un ajuste se muestra con el icono de su sección y el nombre de la sección a la derecha
                delegate: NavItem {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    iconName: win.categories[modelData.cat].icon
                    label: modelData.setting || win.categories[modelData.cat].name
                    hint: modelData.setting ? win.categories[modelData.cat].name : ""
                    active: win.query.trim() === "" ? win.category === modelData.cat : win.sel === index
                    onClicked: {
                        win.sel = index;
                        win.openResult(modelData);
                    }
                }
            }
        }

        // ---------- Contenido ----------
        Item {
            id: content
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18

            readonly property var cat: win.categories[win.category]

            Row {
                id: navArrows
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: 6
                NavArrow {
                    glyph: "arrow_back"
                }
                NavArrow {
                    glyph: "arrow_forward"
                }
            }

            // Header
            Rectangle {
                id: headerCard
                anchors.top: navArrows.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 10
                height: 118
                radius: 16
                color: Theme.panelCard

                Rectangle {
                    id: hIcon
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 14
                    width: 50
                    height: 50
                    radius: 14
                    color: Theme.panelCardHi
                    Text {
                        anchors.centerIn: parent
                        text: content.cat ? content.cat.icon : ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Theme.iconPx(26)
                        font.weight: Theme.iconWeight
                        color: Theme.green
                    }
                }
                Text {
                    font.family: Theme.displayFontFamily
                    id: hTitle
                    anchors.top: hIcon.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 6
                    text: content.cat ? content.cat.name : ""
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: true
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    anchors.top: hTitle.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 2
                    width: parent.width - 48
                    horizontalAlignment: Text.AlignHCenter
                    text: content.cat ? content.cat.desc : ""
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx(11)
                    wrapMode: Text.Wrap
                }
            }

            // Controles (scroll)
            Flickable {
                anchors.top: headerCard.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 14
                contentHeight: controlsCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: controlsCol
                    width: parent.width
                    spacing: Theme.space(3)

                    // ---- Bar & Island ----
                    SectionTitle {
                        visible: win.category === 1
                        text: "Island"
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Notch mode"
                        checked: Config.notchMode
                        onToggled: Config.opt.notchMode = !Config.opt.notchMode
                    }
                    // Dónde va la isla: excluyentes, así que una sola fila de opciones (por dentro
                    // siguen siendo islandAllScreens + islandFollowFocus)
                    ChoiceRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Island on"
                        options: [
                            { value: "all", label: "All monitors" },
                            { value: "primary", label: "Primary monitor" },
                            { value: "focus", label: "Focused monitor" }
                        ]
                        current: Config.islandAllScreens ? "all" : (Config.islandFollowFocus ? "focus" : "primary")
                        onPicked: value => {
                            Config.opt.islandAllScreens = value === "all";
                            Config.opt.islandFollowFocus = value === "focus";
                        }
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Close panels on outside click"
                        checked: Config.islandCloseOnClickOutside
                        onToggled: Config.opt.islandCloseOnClickOutside = !Config.islandCloseOnClickOutside
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Battery percentage"
                        checked: Config.clockShowBatteryPercent
                        onToggled: Config.opt.clockShowBatteryPercent = !Config.clockShowBatteryPercent
                    }
                    SectionTitle {
                        visible: win.category === 1
                        text: "Size"
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Bar height"
                        from: 20
                        to: 60
                        value: Config.barHeight
                        onMoved: v => Config.opt.barHeight = v
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Collapsed width"
                        from: 60
                        to: 420
                        value: Config.collapsedWidth
                        onMoved: v => Config.opt.collapsedWidth = v
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Expanded height"
                        from: 120
                        to: 260
                        value: Config.expandedHeight
                        onMoved: v => Config.opt.expandedHeight = v
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Edge gap"
                        from: 0
                        to: 40
                        value: Config.topMargin
                        onMoved: v => Config.opt.gapFromEdge = v
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Inner padding"
                        from: 4
                        to: 30
                        value: Config.innerPadding
                        onMoved: v => Config.opt.innerPadding = v
                    }

                    // ---- Media ----
                    SectionTitle {
                        visible: win.category === 4
                        text: "Layout"
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Title width"
                        from: 60
                        to: 240
                        value: Config.mediaTitleWidth
                        onMoved: v => Config.opt.mediaTitleWidth = v
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Album art size"
                        from: 40
                        to: 160
                        value: Config.mediaAlbumArtSize
                        onMoved: v => Config.opt.mediaAlbumArtSize = v
                    }
                    SectionTitle {
                        visible: win.category === 4
                        text: "What to show"
                    }
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Album line"
                        checked: Config.mediaShowAlbum
                        onToggled: Config.opt.mediaShowAlbum = !Config.mediaShowAlbum
                    }
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Artist line"
                        checked: Config.mediaShowArtist
                        onToggled: Config.opt.mediaShowArtist = !Config.mediaShowArtist
                    }
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Transport buttons"
                        checked: Config.mediaShowControls
                        onToggled: Config.opt.mediaShowControls = !Config.mediaShowControls
                    }
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Lyrics"
                        checked: Config.mediaShowLyrics
                        onToggled: Config.opt.mediaShowLyrics = !Config.mediaShowLyrics
                    }
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Scroll to change track"
                        checked: Config.mediaScrollToChangeTrack
                        onToggled: Config.opt.mediaScrollToChangeTrack = !Config.mediaScrollToChangeTrack
                    }

                    // ---- Clock & Date ----
                    SectionTitle {
                        visible: win.category === 7
                        text: "Bar clock"
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "24-hour time"
                        checked: Config.clock24Hour
                        onToggled: Config.opt.clock24Hour = !Config.clock24Hour
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Show seconds"
                        checked: Config.clockShowSeconds
                        onToggled: Config.opt.clockShowSeconds = !Config.clockShowSeconds
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Workspace dots"
                        checked: Config.clockShowWorkspaceDots
                        onToggled: Config.opt.clockShowWorkspaceDots = !Config.clockShowWorkspaceDots
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Battery & Wi-Fi"
                        checked: Config.clockShowBatteryWifi
                        onToggled: Config.opt.clockShowBatteryWifi = !Config.clockShowBatteryWifi
                    }
                    SectionTitle {
                        visible: win.category === 7
                        text: "Expanded island"
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Workspaces on the left"
                        checked: Config.clockExpandedWorkspaces
                        onToggled: Config.opt.clockExpandedWorkspaces = !Config.clockExpandedWorkspaces
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Status on the right"
                        checked: Config.clockExpandedStatus
                        onToggled: Config.opt.clockExpandedStatus = !Config.clockExpandedStatus
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Media card"
                        checked: Config.clockExpandedMedia
                        onToggled: Config.opt.clockExpandedMedia = !Config.clockExpandedMedia
                    }
                    SectionTitle {
                        visible: win.category === 7
                        text: "Calendar"
                    }
                    PxSlider {
                        visible: win.category === 7
                        width: parent.width
                        label: "Week starts on"
                        from: 0
                        to: 6
                        unit: ""
                        value: Config.clockWeekStart
                        onMoved: v => Config.opt.clockWeekStart = v
                    }
                    PxSlider {
                        visible: win.category === 7
                        width: parent.width
                        label: "Day cell height"
                        from: 20
                        to: 48
                        value: Config.clockCalendarDayHeight
                        onMoved: v => Config.opt.clockCalendarDayHeight = v
                    }
                    ToggleRow {
                        visible: win.category === 7
                        width: parent.width
                        label: "Show neighbouring months"
                        checked: Config.clockShowNeighbouringMonths
                        onToggled: Config.opt.clockShowNeighbouringMonths = !Config.clockShowNeighbouringMonths
                    }

                    // ---- Motion ----
                    SectionTitle {
                        visible: win.category === 9
                        text: "Animation"
                    }
                    ToggleRow {
                        visible: win.category === 9
                        width: parent.width
                        label: "Reduce motion"
                        checked: Config.opt.motionReduce
                        onToggled: Config.opt.motionReduce = !Config.opt.motionReduce
                    }
                    PxSlider {
                        visible: win.category === 9
                        width: parent.width
                        label: "Movement"
                        from: 0
                        to: 1000
                        value: Config.opt.motionMovementDuration
                        unit: "s"
                        divisor: 1000
                        decimals: 2
                        snap: 10
                        onMoved: v => Config.opt.motionMovementDuration = v
                    }
                    PxSlider {
                        visible: win.category === 9
                        width: parent.width
                        label: "Fades"
                        from: 0
                        to: 1000
                        value: Config.opt.motionFadeDuration
                        unit: "s"
                        divisor: 1000
                        decimals: 2
                        snap: 10
                        onMoved: v => Config.opt.motionFadeDuration = v
                    }
                    PxSlider {
                        visible: win.category === 9
                        width: parent.width
                        label: "Hover response"
                        from: 0
                        to: 1000
                        value: Config.opt.motionHoverDuration
                        unit: "s"
                        divisor: 1000
                        decimals: 2
                        snap: 10
                        onMoved: v => Config.opt.motionHoverDuration = v
                    }
                    PxSlider {
                        visible: win.category === 9
                        width: parent.width
                        label: "Bounce"
                        from: 0
                        to: 100
                        value: Config.opt.motionBounce
                        unit: "%"
                        onMoved: v => Config.opt.motionBounce = v
                    }

                    LauncherSettings {
                        visible: win.category === 8
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    NotificationsSettings {
                        visible: win.category === 3
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    ControlCenterSettings {
                        visible: win.category === 5
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    LockScreenSettings {
                        visible: win.category === 6
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    DisplaySettings {
                        visible: win.category === 2
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    BootThemesSettings {
                        visible: win.category === 11
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    SystemSettings {
                        visible: win.category === 10
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }

                    // ---- Appearance ----
                    SectionTitle {
                        visible: win.category === 0
                        text: "Theme & wallpaper"
                    }
                    Rectangle {
                        visible: win.category === 0
                        width: parent.width
                        height: 68
                        radius: 12
                        color: Theme.panelCard

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 34
                            color: "transparent"
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Theme"
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    text: win.currentScheme
                                    color: Theme.secondaryText
                                    font.pixelSize: Theme.fontPx(11)
                                }
                                Text {
                                    text: "arrow_forward"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Theme.tertiaryText
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openThemeSelector()
                            }
                            KeyButton {
                                radius: Theme.radiusSmall
                                onActivated: win.openThemeSelector()
                            }
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 34
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                    color: Theme.divider
                        }
                        Item {
                            anchors.top: parent.top
                            anchors.topMargin: 35
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 33
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Wallpaper"
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    text: Wallpaper.current.length > 0 ? Wallpaper.current.split("/").pop().replace(/\.[^.]+$/, "") : "Choose…"
                                    color: Theme.secondaryText
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideLeft
                                }
                                Text {
                                    text: "arrow_forward"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Theme.tertiaryText
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openWallpaperSelector()
                            }
                            KeyButton {
                                radius: Theme.radiusSmall
                                onActivated: win.openWallpaperSelector()
                            }
                        }
                    }
                    SectionTitle {
                        visible: win.category === 0
                        text: "Accent"
                    }
                    Rectangle {
                        visible: win.category === 0
                        width: parent.width
                        height: 44
                        radius: 12
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Accent colour"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: win.accentColors
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    width: 15
                                    height: 15
                                    radius: 8
                                    color: modelData
                                    border.width: (Config.appearanceAccent === String(modelData).replace("#", "") || (Config.appearanceAccent === "" && index === 0)) ? 2 : 0
                                    border.color: "#ffffff"

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.opt.appearanceAccent = index === 0 ? "" : String(modelData).replace("#", "")
                                    }
                                    KeyButton {
                                        radius: 8
                                        onActivated: Config.opt.appearanceAccent = index === 0 ? "" : String(modelData).replace("#", "")
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: win.category === 0
                        width: parent.width
                        height: 42
                        radius: 12
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Custom"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 150
                            height: 30
                            radius: 8
                        color: Theme.divider
                            TextInput {
                                font.family: Theme.bodyFontFamily
                                id: accentInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                                text: Config.appearanceAccent !== "" ? "#" + Config.appearanceAccent : ""
                                clip: true
                                validator: RegularExpressionValidator { regularExpression: /^#?[0-9a-fA-F]{6}$/ }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "#rrggbb"
                                    color: Theme.tertiaryText
                                    font: parent.font
                                    visible: accentInput.text.length === 0
                                }
                                onEditingFinished: {
                                    if (text.length === 0)
                                        Config.opt.appearanceAccent = "";
                                    else if (acceptableInput)
                                        Config.opt.appearanceAccent = text.replace("#", "").toLowerCase();
                                }
                            }
                        }
                        Connections {
                            target: Config
                            function onAppearanceAccentChanged(): void {
                                accentInput.text = Config.appearanceAccent !== "" ? "#" + Config.appearanceAccent : "";
                            }
                        }
                    }
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Color burst"
                        checked: Config.appearanceColorBurst
                        onToggled: Config.opt.appearanceColorBurst = !Config.appearanceColorBurst
                    }
                    ChoiceRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Color style"
                        options: [
                            { value: "scheme-tonal-spot", label: "Soft" },
                            { value: "scheme-expressive", label: "Expressive" },
                            { value: "scheme-fidelity", label: "Faithful" },
                            { value: "scheme-vibrant", label: "Vibrant" },
                            { value: "scheme-rainbow", label: "Rainbow" },
                            { value: "scheme-fruit-salad", label: "Fruit salad" }
                        ]
                        current: Config.appearanceMatugenType
                        onPicked: value => {
                            Config.opt.appearanceMatugenType = value;
                            win.regenerateWallpaperColors();
                        }
                    }
                    ChoiceRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Color intensity"
                        options: [
                            { value: "0", label: "Pastel" },
                            { value: "1", label: "Medium" },
                            { value: "2", label: "Vivid" }
                        ]
                        current: String(Config.appearanceMatugenIntensity)
                        onPicked: value => {
                            Config.opt.appearanceMatugenIntensity = parseInt(value);
                            win.regenerateWallpaperColors();
                        }
                    }
                    Text {
                        visible: win.category === 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Used when colours come from the wallpaper (Super+W with Colours on). Soft is the Material default; Expressive gives distinct hues. Intensity makes the accent colours deeper; backgrounds and text stay readable."
                        color: Theme.tertiaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                    }
                    SectionTitle {
                        visible: win.category === 0
                        text: "Type"
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Font size"
                        from: 10
                        to: 24
                        value: Config.appearanceFontSize
                        // 15 px = 100 % (Theme.fontPx escala todo el texto desde ahí)
                        unit: "%"
                        divisor: 0.15
                        onMoved: v => Config.opt.appearanceFontSize = v
                    }
                    Rectangle {
                        id: fontPicker
                        visible: win.category === 0
                        width: parent.width
                        height: fontList.visible ? 174 : 42
                        radius: 12
                        color: Theme.panelCard

                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: fontField.verticalCenter
                            text: "Body font"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            id: fontField
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            anchors.rightMargin: 8
                            width: 170
                            height: 30
                            radius: 8
                            color: Theme.panelCardHi
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: fontArrow.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.appearanceBodyFont || "System default"
                                color: Theme.text
                                font.pixelSize: Theme.fontPx(11)
                                elide: Text.ElideRight
                            }
                            Text {
                                id: fontArrow
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: fontList.visible ? "expand_less" : "expand_more"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: Theme.secondaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: fontList.visible = !fontList.visible
                            }
                            KeyButton {
                                id: fontFieldKey
                                radius: 8
                                onActivated: fontList.visible = !fontList.visible
                            }
                        }
                        ListView {
                            id: fontList
                            visible: false
                            anchors.top: fontField.bottom
                            anchors.left: fontField.left
                            anchors.right: fontField.right
                            anchors.topMargin: 4
                            height: 126
                            clip: true
                            model: win.installedFonts
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width
                                height: 30
                                radius: 6
                                color: fontRowMouse.containsMouse ? Theme.panelCardHi : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.text
                                    font.family: modelData === "System default" ? Theme.bodyFontFamily : modelData
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: fontRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.opt.appearanceBodyFont = modelData === "System default" ? "" : modelData;
                                        fontList.visible = false;
                                    }
                                }
                                KeyButton {
                                    radius: 6
                                    onActivated: {
                                        Config.opt.appearanceBodyFont = modelData === "System default" ? "" : modelData;
                                        fontList.visible = false;
                                        fontFieldKey.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: displayFontPicker
                        visible: win.category === 0
                        width: parent.width
                        height: displayFontList.visible ? 174 : 42
                        radius: Theme.radiusMedium
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: displayFontField.verticalCenter
                            text: "Display font"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            id: displayFontField
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            anchors.rightMargin: 8
                            width: 170
                            height: 30
                            radius: Theme.radiusSmall
                            color: Theme.panelCardHi
                            Text {
                                font.family: Theme.displayFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: displayFontArrow.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.appearanceDisplayFont || "System default"
                                color: Theme.text
                                font.pixelSize: Theme.fontPx(11)
                                elide: Text.ElideRight
                            }
                            Text {
                                id: displayFontArrow
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: displayFontList.visible ? "expand_less" : "expand_more"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: Theme.secondaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: displayFontList.visible = !displayFontList.visible
                            }
                            KeyButton {
                                id: displayFontFieldKey
                                radius: Theme.radiusSmall
                                onActivated: displayFontList.visible = !displayFontList.visible
                            }
                        }
                        ListView {
                            id: displayFontList
                            visible: false
                            anchors.top: displayFontField.bottom
                            anchors.left: displayFontField.left
                            anchors.right: displayFontField.right
                            anchors.topMargin: 4
                            height: 126
                            clip: true
                            model: win.installedFonts
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width
                                height: 30
                                radius: 6
                                color: displayFontRow.containsMouse ? Theme.panelCardHi : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.text
                                    font.family: modelData === "System default" ? Theme.displayFontFamily : modelData
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: displayFontRow
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.opt.appearanceDisplayFont = modelData === "System default" ? "" : modelData;
                                        displayFontList.visible = false;
                                    }
                                }
                                KeyButton {
                                    radius: 6
                                    onActivated: {
                                        Config.opt.appearanceDisplayFont = modelData === "System default" ? "" : modelData;
                                        displayFontList.visible = false;
                                        displayFontFieldKey.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    SectionTitle {
                        visible: win.category === 0
                        text: "Shape & depth"
                    }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Spacing"; from: 2; to: 8; value: Config.appearanceSpacingUnit; unit: "%"; divisor: 0.04; onMoved: v => Config.opt.appearanceSpacingUnit = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Small radius"; from: 0; to: 24; value: Config.appearanceSmallRadius; onMoved: v => Config.opt.appearanceSmallRadius = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Medium radius"; from: 0; to: 32; value: Config.appearanceMediumRadius; onMoved: v => Config.opt.appearanceMediumRadius = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Large radius"; from: 0; to: 40; value: Config.appearanceLargeRadius; onMoved: v => Config.opt.appearanceLargeRadius = v }
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Screen corners"
                        checked: Config.appearanceScreenCorners
                        onToggled: Config.opt.appearanceScreenCorners = !Config.appearanceScreenCorners
                    }
                    PxSlider { visible: win.category === 0 && Config.appearanceScreenCorners; width: parent.width; label: "Screen corner radius"; from: 0; to: 32; value: Config.appearanceScreenCornerRadius; onMoved: v => Config.opt.appearanceScreenCornerRadius = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Icon size"; from: 12; to: 32; value: Config.appearanceIconSize; unit: "%"; divisor: 0.18; onMoved: v => Config.opt.appearanceIconSize = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Icon stroke"; from: 1; to: 20; value: Config.appearanceIconStroke; unit: ""; onMoved: v => Config.opt.appearanceIconStroke = v }

                    SectionTitle {
                        visible: win.category === 0
                        text: "Surfaces & ink"
                    }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Surface lift"; from: 0; to: 20; value: Config.appearanceSurfaceLift; unit: "%"; onMoved: v => Config.opt.appearanceSurfaceLift = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Divider strength"; from: 0; to: 100; value: Config.appearanceDividerStrength; unit: "%"; onMoved: v => Config.opt.appearanceDividerStrength = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Secondary text"; from: 0; to: 100; value: Config.appearanceSecondaryText; unit: "%"; onMoved: v => Config.opt.appearanceSecondaryText = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Tertiary text"; from: 0; to: 100; value: Config.appearanceTertiaryText; unit: "%"; onMoved: v => Config.opt.appearanceTertiaryText = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Hover fill"; from: 0; to: 30; value: Config.appearanceHoverFill; unit: "%"; onMoved: v => Config.opt.appearanceHoverFill = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Selected fill"; from: 0; to: 30; value: Config.appearanceSelectedFill; unit: "%"; onMoved: v => Config.opt.appearanceSelectedFill = v }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Modal dim"; from: 0; to: 90; value: Config.appearanceModalDim; unit: "%"; onMoved: v => Config.opt.appearanceModalDim = v }

                    SectionTitle {
                        visible: win.category === 0
                        text: "Shadow"
                    }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Opacity"; from: 0; to: 100; value: Config.appearanceShadowOpacity; unit: "%"; onMoved: v => { Config.opt.appearanceShadowOpacity = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Blur"; from: 0; to: 100; value: Config.appearanceShadowBlur; unit: "%"; onMoved: v => { Config.opt.appearanceShadowBlur = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Vertical offset"; from: 0; to: 30; value: Config.appearanceShadowOffset; onMoved: v => { Config.opt.appearanceShadowOffset = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Spread"; from: 0; to: 450; value: Config.appearanceShadowSpread; onMoved: v => { Config.opt.appearanceShadowSpread = v; WindowShadowSync.scheduleSync(); } }
                    SectionTitle {
                        visible: win.category === 0
                        text: "Wallpaper"
                    }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Wallpaper crossfade"; from: 0; to: 1000; value: Config.appearanceWallpaperCrossfade; unit: "s"; divisor: 1000; decimals: 2; snap: 50; onMoved: v => Config.opt.appearanceWallpaperCrossfade = v }

                    // ---- Otras categorías (placeholder) ----
                    Item {
                        visible: false
                        width: parent.width
                        height: 90
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.centerIn: parent
                            text: "Coming soon"
                            color: Theme.tertiaryText
                            font.pixelSize: Theme.fontPx(13)
                        }
                    }
                }
            }
        }
    }

    // ===================== Sub-componentes =====================

    component NavItem: Rectangle {
        id: nav
        property string iconName: ""
        property string label: ""
        property string hint: ""
        property bool active: false
        signal clicked

        height: 40
        radius: Theme.radiusMedium
        color: active ? Theme.panelCard : (navMouse.containsMouse ? Qt.tint(Theme.panelCard, Theme.hoverFill) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        Rectangle {
            id: ic
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 13
            color: nav.active ? Theme.green : Theme.panelCardHi
            Text {
                anchors.centerIn: parent
                text: nav.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(15)
                font.weight: Theme.iconWeight
                color: nav.active ? Theme.islandBg : Theme.secondaryText
            }
        }
        Text {
            font.family: Theme.bodyFontFamily
            anchors.left: ic.right
            anchors.leftMargin: 10
            anchors.right: hintText.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.active ? "#ffffff" : Theme.text
            font.pixelSize: Theme.fontPx(nav.hint !== "" ? 13 : 15)
            font.bold: nav.active
            elide: Text.ElideRight
        }
        Text {
            id: hintText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: nav.hint !== "" ? Math.min(implicitWidth, 80) : 0
            text: nav.hint
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            elide: Text.ElideRight
        }
        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    component NavArrow: Rectangle {
        id: arrow
        property string glyph: ""
        signal clicked
        width: 28
        height: 28
        radius: Theme.radiusSmall
        color: aMouse.containsMouse ? Qt.tint(Theme.panelCardHi, Theme.hoverFill) : Theme.panelCard
        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: Theme.iconPx(16)
            font.weight: Theme.iconWeight
            color: Theme.secondaryText
        }
        MouseArea {
            id: aMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }

    // Fila con opciones en píldoras (una elegida)
    component ChoiceRow: Rectangle {
        id: cr
        property string label: ""
        property var options: [] // [{value, label}]
        property string current: ""
        signal picked(string value)
        // Etiqueta a la izquierda y opciones a la derecha en la misma línea (como los
        // interruptores); si no caben, las opciones bajan a una segunda línea
        readonly property real chipsWidth: measureRow.implicitWidth
        readonly property bool inline: crLabel.implicitWidth + 24 + chipsWidth + 30 <= width
        height: inline ? 48 : chips.y + chips.height + 12
        radius: Theme.radiusMedium
        color: Theme.panelCard
        border.width: activeFocus ? 2 : 0
        border.color: Theme.green

        // ←/→: opción anterior/siguiente
        function step(dir: int): void {
            const i = options.findIndex(o => o.value === current);
            const next = options[Math.max(0, Math.min(options.length - 1, i + dir))];
            if (next && next.value !== current)
                picked(next.value);
        }
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(cr)
        Keys.onUpPressed: KeyNav.move(cr, false)
        Keys.onDownPressed: KeyNav.move(cr, true)
        Keys.onLeftPressed: cr.step(-1)
        Keys.onRightPressed: cr.step(1)
        // Ancho natural de las opciones (en negrita, el caso más ancho), sin dibujarlas
        Row {
            id: measureRow
            visible: false
            spacing: 6
            Repeater {
                model: cr.options
                delegate: Text {
                    required property var modelData
                    width: implicitWidth + 24
                    text: modelData.label
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                }
            }
        }
        Text {
            id: crLabel
            x: 16
            y: cr.inline ? (cr.height - height) / 2 : 12
            text: cr.label
            color: "#ffffff"
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
        Flow {
            id: chips
            x: cr.inline ? cr.width - 14 - width : 16
            y: cr.inline ? (cr.height - 28) / 2 : crLabel.y + crLabel.height + 10
            width: cr.inline ? cr.chipsWidth : cr.width - 32
            spacing: 6
            Repeater {
                model: cr.options
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: cr.current === modelData.value
                    // Ancho de la versión en negrita: no baila al cambiar de opción y cuadra con measureRow
                    width: boldText.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: on ? Theme.green : (chipMouse.containsMouse ? Theme.panelCardHi : Qt.rgba(1, 1, 1, 0.04))
                    Text {
                        id: boldText
                        visible: false
                        text: chip.modelData.label
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.bold: true
                    }
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.on ? Theme.crust : Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.bold: chip.on
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!chip.on) cr.picked(chip.modelData.value)
                    }
                }
            }
        }
    }

    component ToggleRow: Rectangle {
        id: tr
        property string label: ""
        property bool checked: false
        signal toggled

        height: 48
        radius: Theme.radiusMedium
        color: Theme.panelCard
        border.width: activeFocus ? 2 : 0
        border.color: Theme.green

        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(tr)
        Keys.onUpPressed: KeyNav.move(tr, false)
        Keys.onDownPressed: KeyNav.move(tr, true)
        Keys.onSpacePressed: tr.toggled()
        Keys.onReturnPressed: tr.toggled()
        Keys.onEnterPressed: tr.toggled()

        Text {
            font.family: Theme.bodyFontFamily
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(14)
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: 12
            color: tr.checked ? Theme.green : Theme.panelCardHi
            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x {
                    NumberAnimation {
                        duration: Theme.movementDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tr.toggled()
            }
        }
    }

    component PxSlider: Rectangle {
        id: ps
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        property string unit: "px"
        // Como en SettingSliderRow: se muestra valor / divisor; snap redondea a múltiplos
        property real divisor: 1
        property int decimals: 0
        property int snap: 1
        signal moved(int v)

        height: 58
        radius: Theme.radiusMedium
        color: Theme.panelCard
        border.width: activeFocus ? 2 : 0
        border.color: Theme.green

        // ←/→ en pasos de 1/20 del rango; con Shift, de `snap` en `snap`
        readonly property int step: Math.max(snap, Math.round((to - from) / 20 / snap) * snap)
        function nudge(dir: int, fine: bool): void {
            moved(Math.max(from, Math.min(to, value + dir * (fine ? snap : step))));
        }
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(ps)
        Keys.onUpPressed: KeyNav.move(ps, false)
        Keys.onDownPressed: KeyNav.move(ps, true)
        Keys.onLeftPressed: event => ps.nudge(-1, event.modifiers & Qt.ShiftModifier)
        Keys.onRightPressed: event => ps.nudge(1, event.modifiers & Qt.ShiftModifier)

        Text {
            font.family: Theme.bodyFontFamily
            id: pl
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 14
            text: ps.label
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(14)
        }
        Text {
            font.family: Theme.bodyFontFamily
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 14
            readonly property real shown: Number((ps.value / ps.divisor).toFixed(ps.decimals))
            text: ps.unit === "" ? ("" + shown) : ps.unit === "%" ? (shown + "%") : (shown + " " + ps.unit)
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(13)
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: pl.bottom
            anchors.topMargin: 12
            height: 4
            radius: 2
            color: Theme.panelCardHi

            Rectangle {
                id: fillr
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: 2
                width: parent.width * (ps.value - ps.from) / Math.max(1, ps.to - ps.from)
                color: Theme.green
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fillr.width - width / 2))
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -18
                anchors.bottomMargin: -18
                cursorShape: Qt.PointingHandCursor
                function setX(mx) {
                    const r = Math.max(0, Math.min(1, mx / track.width));
                    const v = Math.round((ps.from + r * (ps.to - ps.from)) / ps.snap) * ps.snap;
                    ps.moved(Math.max(ps.from, Math.min(ps.to, v)));
                }
                onPressed: mouse => setX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setX(mouse.x);
                }
            }
        }
    }
}
