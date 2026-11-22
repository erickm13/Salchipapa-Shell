pragma ComponentBehavior: Bound
// Panel de ajustes de la shell. Ventana propia (modal, centrada): sidebar de categorías +
// buscador + contenido. Fase 1: "Bar & Island" funcional (escribe en Config, persistente);
// el resto de categorías son marcadores por ahora.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
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
    // Ese es el tamaño al abrir; al redimensionar la ventana el panel la llena (la escala no cambia:
    // hay más sitio para el contenido, no letras más grandes).
    readonly property real uiScale: Math.min(1.3, (openScreen.width - 96) / 1080, (openScreen.height - 144) / 620)
    implicitWidth: Math.round(1080 * uiScale)
    implicitHeight: Math.round(620 * uiScale)
    minimumSize: Qt.size(Math.round(820 * uiScale), Math.round(460 * uiScale))

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
            name: "Wi-Fi",
            icon: "wifi",
            desc: "Turn Wi-Fi on or off and connect to networks."
        },
        {
            name: "Bluetooth",
            icon: "bluetooth",
            desc: "Turn Bluetooth on or off, pair and connect devices."
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
        },
        {
            name: "Shortcuts",
            icon: "keyboard",
            desc: "Which apps appear in the shortcuts glossary (Super + /)."
        }
    ]

    // Subsecciones desplegables (bloques con muchos ajustes finos): plegadas al abrir
    property bool openShape: false
    property bool openSurfaces: false
    property bool openShadow: false
    property bool openIslandSize: false

    // Barra lateral: un color por sección para su icono, y dónde empieza cada grupo de secciones
    readonly property var categoryTints: [Theme.purple, Theme.blue, Theme.aqua, Theme.green, Theme.blue, Theme.red, Theme.orange, Theme.overlay1,
        Theme.yellow, Theme.blue, Theme.purple, Theme.aqua, Theme.overlay1, Theme.orange, Theme.red]
    readonly property var groupStarts: [3, 5, 8, 12]

    // La ventana se destruye al cerrar: la categoría abierta se guarda en Overlay
    property int category: Overlay.settingsCategory
    onCategoryChanged: {
        Overlay.settingsCategory = category;
        regroupTimer.restart();
    }
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

    // Fondo de la terminal (foot): color de salchipapa-colors.ini y opacidad de foot.ini. Lo usa la
    // franja translúcida de la barra lateral. Si no hay foot, el fondo del tema al 80 %.
    property color terminalBg: Theme.crust
    property real terminalAlpha: 0.8
    FileView {
        path: Quickshell.env("HOME") + "/.config/foot/salchipapa-colors.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^background\s*=\s*([0-9a-fA-F]{6})\s*$/m);
            if (m)
                win.terminalBg = "#" + m[1];
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/foot/foot.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^alpha\s*=\s*([0-9.]+)\s*$/m);
            if (m)
                win.terminalAlpha = Math.max(0.2, Math.min(1, parseFloat(m[1])));
        }
    }

    // Agrupa visualmente las filas de ajustes seguidas (las tarjetas con `radius` hijas directas de
    // la columna): redondea solo la primera por arriba y la última por abajo
    function regroup(): void {
        const rows = [];
        for (const c of controlsCol.children)
            if (c.visible && c.height > 0)
                rows.push(c);
        const isRow = c => c && typeof c.radius === "number" && c.topLeftRadius !== undefined;
        const r = Theme.radiusMedium;
        for (let i = 0; i < rows.length; i++) {
            const c = rows[i];
            if (!isRow(c))
                continue;
            const up = isRow(rows[i - 1]), down = isRow(rows[i + 1]);
            c.topLeftRadius = c.topRightRadius = up ? 0 : r;
            c.bottomLeftRadius = c.bottomRightRadius = down ? 0 : r;
        }
    }
    Timer {
        id: regroupTimer
        interval: 0
        onTriggered: win.regroup()
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
        else {
            Overlay.settingsRevealAll = true; // puede estar en una subsección plegada
            focusTimer.start(); // tras recolocar la columna, para que el ajuste quede a la vista
        }
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
        // Fila de pastillas: su título y el nombre de cada ajuste que agrupa
        if (item.chips !== undefined) {
            if (typeof item.label === "string" && item.label !== "")
                out.push(item.label.trim());
            for (const c of item.chips)
                out.push(c.label);
            return;
        }
        if (item.options !== undefined) {
            if (typeof item.label === "string" && item.label !== "")
                out.push(item.label.trim());
            return;
        }
        const l = item.label;
        if (typeof l === "string" && l.trim() !== "")
            out.push(l.trim());
        else if (typeof item.text === "string" && item.color !== undefined && item.echoMode === undefined && !String(item.font?.family).startsWith("Material")
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
        Overlay.settingsRevealAll = true; // también lo que está en subsecciones plegadas
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
        Overlay.settingsRevealAll = false;
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
        // Llena la ventana (en unidades de diseño, antes de escalar)
        width: win.width > 0 ? win.width / win.uiScale : 1080
        height: win.height > 0 ? win.height / win.uiScale : 620
        scale: win.uiScale
        transformOrigin: Item.TopLeft
        // Dividido por la escala: las esquinas quedan del mismo radio que las de la pantalla
        radius: (Config.appearanceScreenCorners ? Config.appearanceScreenCornerRadius : 0) / win.uiScale
        // Translúcida: Hyprland desenfoca lo que hay detrás de la ventana, y eso se ve en la franja
        // de la barra lateral. El contenido lleva su propio fondo opaco (contentBg).
        // Mismo color y opacidad que el fondo de la terminal (ver win.terminalBg), para que el
        // desenfoque se vea igual en las dos
        color: Qt.rgba(win.terminalBg.r, win.terminalBg.g, win.terminalBg.b, win.terminalAlpha)
        border.width: 0
        border.color: Theme.divider

        // Fondo opaco del contenido: de la barra lateral al borde derecho de la ventana
        Rectangle {
            id: contentBg
            x: sidebar.x + sidebar.width + 8
            width: parent.width - x
            height: parent.height
            // Del tono de las tarjetas pero más oscuro: se distinguen sin el contraste duro del negro
            color: Qt.darker(Theme.panelCard, 1.7)
            topRightRadius: parent.radius
            bottomRightRadius: parent.radius
        }

        focus: Overlay.settings
        // Al abrir, el foco en el buscador: ↑/↓ cambian de sección desde el primer momento
        // (con `focus: true` solo, al crearse la ventana a veces no lo recibía nadie)
        Component.onCompleted: {
            Overlay.settingsRevealAll = false;
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
            // Panel propio, algo más claro que el contenido y separado del borde de la ventana
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 8
            width: 228
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.06)

            Rectangle {
                id: search
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 12
                height: 30
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.07)

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
                        text: "Search"
                        color: Theme.secondaryText
                        font: parent.font
                        visible: parent.text.length === 0
                    }
                    Keys.onEscapePressed: Overlay.settings = false
                }
            }

            // Quién eres: foto (~/.face) y usuario
            Item {
                id: profileRow
                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: 44
                // El recorte redondo se dibuja al triple de tamaño y se reduce: a su tamaño real
                // (38 px, y la ventana va ampliada) la foto salía borrosa
                Item {
                    id: profilePhoto
                    width: 38
                    height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    ClippingRectangle {
                        width: parent.width * 3
                        height: parent.height * 3
                        radius: width / 2
                        scale: 1 / 3
                        transformOrigin: Item.TopLeft
                        color: Theme.panelCardHi
                        FacePhoto {
                            anchors.fill: parent
                        }
                    }
                }
                Column {
                    anchors.left: profilePhoto.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: Quickshell.env("USER") || "user"
                        color: "#ffffff"
                        elide: Text.ElideRight
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(14)
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: "Salchipapa Shell"
                        color: Theme.secondaryText
                        elide: Text.ElideRight
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(11)
                    }
                }
            }

            ListView {
                anchors.top: profileRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 10
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                clip: true
                spacing: 1
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: win.query.trim() === "" ? win.category : win.sel
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                // Un ajuste se muestra con el icono de su sección y el nombre de la sección a la derecha
                // Las secciones van en grupos: un hueco antes de la primera de cada uno (no al buscar)
                delegate: Item {
                    id: navSlot
                    required property int index
                    required property var modelData
                    readonly property real gap: win.query.trim() === "" && win.groupStarts.includes(modelData.cat) ? 8 : 0
                    width: ListView.view.width
                    height: navItem.height + gap
                  NavItem {
                    id: navItem
                    readonly property int index: navSlot.index
                    readonly property var modelData: navSlot.modelData
                    y: navSlot.gap
                    width: parent.width
                    tint: win.categoryTints[modelData.cat] ?? Theme.overlay1
                    iconName: win.categories[modelData.cat].icon
                    label: modelData.setting || win.categories[modelData.cat].name
                    hint: modelData.setting ? win.categories[modelData.cat].name : ""
                    active: win.query.trim() === "" ? win.category === modelData.cat : win.sel === index
                    // Con el ratón, elegir una sección solo la muestra: el foco se queda en el
                    // buscador (si pasara al primer control, saldría marcado sin haberlo tocado).
                    // Entrar a los controles con el teclado sigue siendo Enter.
                    onClicked: {
                        win.sel = index;
                        if (modelData.setting === "") {
                            win.category = modelData.cat;
                            searchInput.forceActiveFocus();
                        } else {
                            win.openResult(modelData);
                        }
                    }
                  }
                }
            }
        }

        // ---------- Contenido ----------
        Item {
            id: content
            // Ocupa lo que deja la barra lateral, hasta un ancho cómodo de leer: en una ventana muy
            // grande se centra en vez de estirar las filas de lado a lado
            readonly property real room: parent.width - sidebar.width - 36
            width: Math.min(room, 1100)
            x: sidebar.x + sidebar.width + 18 + (room - width) / 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 18
            anchors.bottomMargin: 18

            readonly property var cat: win.categories[win.category]

            Row {
                id: navArrows
                // Barra de herramientas: flechas de sección a la izquierda del título
                z: 1
                anchors.left: headerCard.left
                anchors.verticalCenter: headerCard.verticalCenter
                spacing: 4
                // Sección anterior / siguiente
                NavArrow {
                    glyph: "arrow_back"
                    onClicked: win.stepCategory(-1)
                }
                NavArrow {
                    glyph: "arrow_forward"
                    onClicked: win.stepCategory(1)
                }
            }

            // Cabecera sin tarjeta: (flechas) + nombre de la sección y, debajo, su descripción
            Item {
                id: headerCard
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 74 // las flechas
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        id: hTitle
                        width: parent.width
                        font.family: Theme.displayFontFamily
                        text: content.cat ? content.cat.name : ""
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(17)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        font.family: Theme.bodyFontFamily
                        text: content.cat ? content.cat.desc : ""
                        color: Theme.secondaryText
                        font.pixelSize: Theme.fontPx(11)
                        elide: Text.ElideRight
                    }
                }
            }

            // Barra de desplazamiento: solo si hay más contenido del que cabe
            Rectangle {
                z: 2
                visible: controlsFlick.contentHeight > controlsFlick.height + 1
                anchors.right: parent.right
                anchors.rightMargin: -11
                y: controlsFlick.y + controlsFlick.visibleArea.yPosition * controlsFlick.height
                width: 4
                height: Math.max(24, controlsFlick.visibleArea.heightRatio * controlsFlick.height)
                radius: 2
                color: Theme.secondaryText
                opacity: controlsFlick.moving ? 0.9 : 0.4
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            // Controles (scroll)
            Flickable {
                id: controlsFlick
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
                    // Las filas seguidas forman una sola tarjeta: 1 px entre ellas (deja ver el
                    // fondo como línea divisoria) y esquinas redondeadas solo en los extremos
                    spacing: 1
                    onHeightChanged: regroupTimer.restart()
                    Component.onCompleted: regroupTimer.restart()

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
                    SectionTitle {
                        visible: win.category === 1
                        text: "Indicators"
                    }
                    SettingChipsRow {
                        visible: win.category === 1
                        card: true
                        label: "Show in the island"
                        hint: "What appears next to the clock while the island is at rest."
                        chips: [
                            { label: "Battery percentage", key: "clockShowBatteryPercent" },
                            { label: "Now playing", key: "clockShowNowPlaying" },
                            { label: "Unread notifications", key: "clockShowUnreadNotifs" },
                            { label: "Bluetooth", key: "clockShowBluetooth" },
                            { label: "Downloads", key: "clockShowDownloads" }
                        ]
                    }
                    SectionTitle {
                        visible: win.category === 1
                        text: "Mascot"
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Mascot"
                        checked: Config.mascotEnabled
                        onToggled: Config.opt.mascotEnabled = !Config.mascotEnabled
                    }
                    // Qué mascota: la salchipapa de serie o cualquier hoja de sprites (PNG) que haya en
                    // ~/.config/salchipapa-shell/mascots. Rejilla con el primer fotograma de cada una
                    // (pueden ser cientos, y así el nombre del archivo da igual).
                    Rectangle {
                        id: mascotPicker
                        visible: win.category === 1 && Config.mascotEnabled
                        width: parent.width
                        height: mascotGrid.y + mascotGrid.height + 12
                        radius: Theme.radiusMedium
                        color: Theme.panelCard
                        readonly property var options: {
                            const list = [
                                { value: "random", label: "Random", icon: "" },
                                { value: "", label: "Salchipapa", icon: Qt.resolvedUrl("../assets/mascot/salchipapa.png") }
                            ];
                            for (let i = 0; i < mascotFiles.count; i++) {
                                const base = mascotFiles.get(i, "fileName").replace(/\.png$/i, "");
                                const path = mascotFiles.get(i, "filePath");
                                list.push({
                                    value: path,
                                    label: base.length <= 3 ? base.toUpperCase() : base.charAt(0).toUpperCase() + base.slice(1),
                                    icon: "file://" + path
                                });
                            }
                            return list;
                        }
                        FolderListModel {
                            id: mascotFiles
                            folder: "file://" + Quickshell.env("HOME") + "/.config/salchipapa-shell/mascots"
                            nameFilters: ["*.png"]
                            showDirs: false
                        }
                        Text {
                            x: 16
                            y: 14
                            text: "Mascot character"
                            color: "#ffffff"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(14)
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            y: 15
                            text: (mascotPicker.options.find(o => o.value === Config.mascotSprite)?.label ?? "Custom") + " · " + mascotPicker.options.length
                            color: Theme.secondaryText
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(12)
                        }
                        GridView {
                            id: mascotGrid
                            x: 12
                            y: 44
                            width: parent.width - 24
                            height: Math.min(Math.ceil(count / Math.max(1, Math.floor(width / cellWidth))), 4) * cellHeight
                            cellWidth: 46
                            cellHeight: 46
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: mascotPicker.options
                            delegate: Item {
                                id: mascotCell
                                required property var modelData
                                // Hoja con varias animaciones (.json junto al PNG): la miniatura es su
                                // primer fotograma, no la hoja entera
                                property var meta: null
                                FileView {
                                    path: mascotCell.modelData.value.toLowerCase().endsWith(".png") ? mascotCell.modelData.value.slice(0, -4) + ".json" : ""
                                    printErrors: false
                                    onLoaded: {
                                        try {
                                            mascotCell.meta = JSON.parse(text());
                                        } catch (e) {
                                            mascotCell.meta = null;
                                        }
                                    }
                                }
                                readonly property bool on: Config.mascotSprite === modelData.value
                                width: mascotGrid.cellWidth
                                height: mascotGrid.cellHeight
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 10
                                    color: mascotCellMouse.containsMouse || mascotCell.on ? Theme.panelCardHi : "transparent"
                                    border.width: mascotCell.on ? 2 : 0
                                    border.color: Theme.green
                                    // "Random": va cambiando de mascota cada pocos minutos
                                    Text {
                                        visible: mascotCell.modelData.value === "random"
                                        anchors.centerIn: parent
                                        text: "shuffle"
                                        color: mascotCell.on ? Theme.green : Theme.text
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: Theme.fontPx(24)
                                    }
                                    // Primer fotograma: la hoja se escala a la altura y se recorta por la izquierda
                                    Image {
                                        visible: mascotCell.modelData.value !== "random"
                                        anchors.centerIn: parent
                                        width: 32
                                        height: 32
                                        source: mascotCell.modelData.icon
                                        sourceClipRect: mascotCell.meta ? Qt.rect(0, 0, mascotCell.meta.frameWidth, mascotCell.meta.frameHeight) : undefined
                                        fillMode: mascotCell.meta ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                        horizontalAlignment: mascotCell.meta ? Image.AlignHCenter : Image.AlignLeft
                                        clip: true
                                        smooth: false
                                        asynchronous: true
                                    }
                                    MouseArea {
                                        id: mascotCellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.opt.mascotSprite = mascotCell.modelData.value
                                    }
                                }
                            }
                        }
                    }
                    SubsectionRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Size & spacing"
                        hint: "Island height, width, gaps and padding"
                        open: win.openIslandSize || Overlay.settingsRevealAll
                        onToggled: win.openIslandSize = !win.openIslandSize
                    }
                    PxSlider {
                        visible: win.category === 1 && (win.openIslandSize || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Bar height"
                        from: 20
                        to: 60
                        value: Config.barHeight
                        onMoved: v => Config.opt.barHeight = v
                    }
                    PxSlider {
                        visible: win.category === 1 && (win.openIslandSize || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Collapsed width"
                        from: 60
                        to: 420
                        value: Config.collapsedWidth
                        onMoved: v => Config.opt.collapsedWidth = v
                    }
                    PxSlider {
                        visible: win.category === 1 && (win.openIslandSize || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Expanded height"
                        from: 120
                        to: 260
                        value: Config.expandedHeight
                        onMoved: v => Config.opt.expandedHeight = v
                    }
                    PxSlider {
                        visible: win.category === 1 && (win.openIslandSize || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Edge gap"
                        from: 0
                        to: 40
                        value: Config.topMargin
                        onMoved: v => Config.opt.gapFromEdge = v
                    }
                    PxSlider {
                        visible: win.category === 1 && (win.openIslandSize || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Inner padding"
                        from: 4
                        to: 30
                        value: Config.innerPadding
                        onMoved: v => Config.opt.innerPadding = v
                    }

                    // ---- Media ----
                    SectionTitle {
                        visible: win.category === 6
                        text: "Layout"
                    }
                    PxSlider {
                        visible: win.category === 6
                        width: parent.width
                        label: "Title width"
                        from: 60
                        to: 240
                        value: Config.mediaTitleWidth
                        onMoved: v => Config.opt.mediaTitleWidth = v
                    }
                    PxSlider {
                        visible: win.category === 6
                        width: parent.width
                        label: "Album art size"
                        from: 40
                        to: 160
                        value: Config.mediaAlbumArtSize
                        onMoved: v => Config.opt.mediaAlbumArtSize = v
                    }
                    SectionTitle {
                        visible: win.category === 6
                        text: "What to show"
                    }
                    SettingChipsRow {
                        visible: win.category === 6
                        card: true
                        label: "Show in the media card"
                        chips: [
                            { label: "Album", key: "mediaShowAlbum" },
                            { label: "Artist", key: "mediaShowArtist" },
                            { label: "Playback buttons", key: "mediaShowControls" },
                            { label: "Lyrics", key: "mediaShowLyrics" }
                        ]
                    }
                    ToggleRow {
                        visible: win.category === 6
                        width: parent.width
                        label: "Scroll to change track"
                        checked: Config.mediaScrollToChangeTrack
                        onToggled: Config.opt.mediaScrollToChangeTrack = !Config.mediaScrollToChangeTrack
                    }

                    // ---- Clock & Date ----
                    SectionTitle {
                        visible: win.category === 9
                        text: "Bar clock"
                    }
                    SettingChipsRow {
                        visible: win.category === 9
                        card: true
                        label: "Clock in the island"
                        hint: "What the island shows at rest, around the time."
                        chips: [
                            { label: "24-hour time", key: "clock24Hour" },
                            { label: "Seconds", key: "clockShowSeconds" },
                            { label: "Workspace dots", key: "clockShowWorkspaceDots" },
                            { label: "Battery & Wi-Fi", key: "clockShowBatteryWifi" }
                        ]
                    }
                    SectionTitle {
                        visible: win.category === 9
                        text: "Expanded island"
                    }
                    SettingChipsRow {
                        visible: win.category === 9
                        card: true
                        label: "When you hover the island"
                        hint: "What the expanded island adds."
                        chips: [
                            { label: "Workspaces", key: "clockExpandedWorkspaces" },
                            { label: "Status", key: "clockExpandedStatus" },
                            { label: "Media card", key: "clockExpandedMedia" }
                        ]
                    }
                    SectionTitle {
                        visible: win.category === 9
                        text: "Calendar"
                    }
                    ChoiceRow {
                        visible: win.category === 9
                        width: parent.width
                        label: "Week starts on"
                        options: [
                            { value: "0", label: "Sun" }, { value: "1", label: "Mon" }, { value: "2", label: "Tue" },
                            { value: "3", label: "Wed" }, { value: "4", label: "Thu" }, { value: "5", label: "Fri" },
                            { value: "6", label: "Sat" }
                        ]
                        current: "" + Config.clockWeekStart
                        onPicked: value => Config.opt.clockWeekStart = parseInt(value)
                    }
                    PxSlider {
                        visible: win.category === 9
                        width: parent.width
                        label: "Day cell height"
                        from: 20
                        to: 48
                        value: Config.clockCalendarDayHeight
                        onMoved: v => Config.opt.clockCalendarDayHeight = v
                    }
                    ToggleRow {
                        visible: win.category === 9
                        width: parent.width
                        label: "Show neighbouring months"
                        checked: Config.clockShowNeighbouringMonths
                        onToggled: Config.opt.clockShowNeighbouringMonths = !Config.clockShowNeighbouringMonths
                    }

                    // ---- Motion ----
                    SectionTitle {
                        visible: win.category === 11
                        text: "Animation"
                    }
                    ToggleRow {
                        visible: win.category === 11
                        width: parent.width
                        label: "Reduce motion"
                        checked: Config.opt.motionReduce
                        onToggled: Config.opt.motionReduce = !Config.opt.motionReduce
                    }
                    PxSlider {
                        visible: win.category === 11
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
                        visible: win.category === 11
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
                        visible: win.category === 11
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
                        visible: win.category === 11
                        width: parent.width
                        label: "Bounce"
                        from: 0
                        to: 100
                        value: Config.opt.motionBounce
                        unit: "%"
                        onMoved: v => Config.opt.motionBounce = v
                    }

                    LauncherSettings {
                        visible: win.category === 10
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    NotificationsSettings {
                        visible: win.category === 5
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    ControlCenterSettings {
                        visible: win.category === 7
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    LockScreenSettings {
                        visible: win.category === 8
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    DisplaySettings {
                        visible: win.category === 2
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    // Wi-Fi y Bluetooth: las mismas páginas que abre la isla, sin la flecha de volver
                    WifiContent {
                        visible: win.category === 3
                        width: parent.width
                        height: visible ? 520 : 0
                        inIsland: false
                        k: 1
                        active: visible && !Overlay.settingsRevealAll
                    }
                    BluetoothContent {
                        visible: win.category === 4
                        width: parent.width
                        height: visible ? 520 : 0
                        inIsland: false
                        k: 1
                        active: visible && !Overlay.settingsRevealAll
                    }
                    BootThemesSettings {
                        visible: win.category === 13
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    KeybindsSettings {
                        visible: win.category === 14
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    SystemSettings {
                        visible: win.category === 12
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

                    SubsectionRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Shape & spacing"
                        hint: "Spacing, corner radius and icon size"
                        open: win.openShape || Overlay.settingsRevealAll
                        onToggled: win.openShape = !win.openShape
                    }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Spacing"; from: 2; to: 8; value: Config.appearanceSpacingUnit; unit: "%"; divisor: 0.04; onMoved: v => Config.opt.appearanceSpacingUnit = v }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Small radius"; from: 0; to: 24; value: Config.appearanceSmallRadius; onMoved: v => Config.opt.appearanceSmallRadius = v }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Medium radius"; from: 0; to: 32; value: Config.appearanceMediumRadius; onMoved: v => Config.opt.appearanceMediumRadius = v }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Large radius"; from: 0; to: 40; value: Config.appearanceLargeRadius; onMoved: v => Config.opt.appearanceLargeRadius = v }
                    ToggleRow {
                        visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll)
                        width: parent.width
                        label: "Screen corners"
                        checked: Config.appearanceScreenCorners
                        onToggled: Config.opt.appearanceScreenCorners = !Config.appearanceScreenCorners
                    }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll) && Config.appearanceScreenCorners; width: parent.width; label: "Screen corner radius"; from: 0; to: 32; value: Config.appearanceScreenCornerRadius; onMoved: v => Config.opt.appearanceScreenCornerRadius = v }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Icon size"; from: 12; to: 32; value: Config.appearanceIconSize; unit: "%"; divisor: 0.18; onMoved: v => Config.opt.appearanceIconSize = v }
                    PxSlider { visible: win.category === 0 && (win.openShape || Overlay.settingsRevealAll); width: parent.width; label: "Icon stroke"; from: 1; to: 20; value: Config.appearanceIconStroke; unit: ""; onMoved: v => Config.opt.appearanceIconStroke = v }

                    SubsectionRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Surfaces & text contrast"
                        hint: "How strong cards, dividers, hover and secondary text look"
                        open: win.openSurfaces || Overlay.settingsRevealAll
                        onToggled: win.openSurfaces = !win.openSurfaces
                    }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Surface lift"; from: 0; to: 20; value: Config.appearanceSurfaceLift; unit: "%"; onMoved: v => Config.opt.appearanceSurfaceLift = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Divider strength"; from: 0; to: 100; value: Config.appearanceDividerStrength; unit: "%"; onMoved: v => Config.opt.appearanceDividerStrength = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Secondary text"; from: 0; to: 100; value: Config.appearanceSecondaryText; unit: "%"; onMoved: v => Config.opt.appearanceSecondaryText = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Tertiary text"; from: 0; to: 100; value: Config.appearanceTertiaryText; unit: "%"; onMoved: v => Config.opt.appearanceTertiaryText = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Hover fill"; from: 0; to: 30; value: Config.appearanceHoverFill; unit: "%"; onMoved: v => Config.opt.appearanceHoverFill = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Selected fill"; from: 0; to: 30; value: Config.appearanceSelectedFill; unit: "%"; onMoved: v => Config.opt.appearanceSelectedFill = v }
                    PxSlider { visible: win.category === 0 && (win.openSurfaces || Overlay.settingsRevealAll); width: parent.width; label: "Modal dim"; from: 0; to: 90; value: Config.appearanceModalDim; unit: "%"; onMoved: v => Config.opt.appearanceModalDim = v }

                    SubsectionRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Window shadow"
                        hint: "Opacity, blur, offset and spread"
                        open: win.openShadow || Overlay.settingsRevealAll
                        onToggled: win.openShadow = !win.openShadow
                    }
                    PxSlider { visible: win.category === 0 && (win.openShadow || Overlay.settingsRevealAll); width: parent.width; label: "Opacity"; from: 0; to: 100; value: Config.appearanceShadowOpacity; unit: "%"; onMoved: v => { Config.opt.appearanceShadowOpacity = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0 && (win.openShadow || Overlay.settingsRevealAll); width: parent.width; label: "Blur"; from: 0; to: 100; value: Config.appearanceShadowBlur; unit: "%"; onMoved: v => { Config.opt.appearanceShadowBlur = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0 && (win.openShadow || Overlay.settingsRevealAll); width: parent.width; label: "Vertical offset"; from: 0; to: 30; value: Config.appearanceShadowOffset; onMoved: v => { Config.opt.appearanceShadowOffset = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 0 && (win.openShadow || Overlay.settingsRevealAll); width: parent.width; label: "Spread"; from: 0; to: 450; value: Config.appearanceShadowSpread; onMoved: v => { Config.opt.appearanceShadowSpread = v; WindowShadowSync.scheduleSync(); } }
                    SectionTitle {
                        visible: win.category === 0
                        text: "Wallpaper"
                    }
                    PxSlider { visible: win.category === 0; width: parent.width; label: "Wallpaper transition"; from: 500; to: 3000; value: Config.appearanceWallpaperCrossfade; unit: "s"; divisor: 1000; decimals: 2; snap: 50; onMoved: v => Config.opt.appearanceWallpaperCrossfade = v }

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
        property color tint: Theme.overlay1
        signal clicked

        height: 32
        radius: 9
        color: active ? Theme.green : (navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        // Icono en un círculo neutro (más oscuro sobre la fila elegida)
        Rectangle {
            id: ic
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: nav.active ? Qt.rgba(0, 0, 0, 0.16) : Theme.panelCardHi
            Text {
                anchors.centerIn: parent
                text: nav.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(15)
                font.weight: Theme.iconWeight
                color: nav.active ? Theme.crust : Theme.secondaryText
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
            color: nav.active ? Theme.crust : Theme.text
            font.pixelSize: Theme.fontPx(13)
            font.bold: nav.active
            elide: Text.ElideRight
        }
        Text {
            id: hintText
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: nav.hint !== "" ? Math.min(implicitWidth, 80) : 0
            text: nav.hint
            color: nav.active ? Theme.crust : Theme.tertiaryText
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

    // Cabecera de una subsección desplegable: título, resumen y flecha; al pulsarla aparecen debajo
    // sus ajustes (las filas que la siguen, con `win.open…` en su `visible`)
    component SubsectionRow: Rectangle {
        id: sub
        property string label: ""
        property string hint: ""
        property bool open: false
        signal toggled

        height: 58
        radius: Theme.radiusMedium
        color: subMouse.containsMouse ? Qt.tint(Theme.panelCard, Theme.hoverFill) : Theme.panelCard
        border.width: activeFocus ? 2 : 0
        border.color: Theme.green

        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(sub)
        Keys.onUpPressed: KeyNav.move(sub, false)
        Keys.onDownPressed: KeyNav.move(sub, true)
        Keys.onSpacePressed: sub.toggled()
        Keys.onReturnPressed: sub.toggled()
        Keys.onEnterPressed: sub.toggled()

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: chevron.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: sub.label
                color: "#ffffff"
                elide: Text.ElideRight
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(14)
            }
            Text {
                width: parent.width
                visible: sub.hint !== ""
                text: sub.hint
                color: Theme.secondaryText
                elide: Text.ElideRight
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
            }
        }
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            color: Theme.secondaryText
            font.family: "Material Symbols Rounded"
            font.pixelSize: Theme.iconPx(20)
            rotation: sub.open ? 90 : 0
            Behavior on rotation {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
        MouseArea {
            id: subMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sub.toggled()
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
        // Valor con − / + para ajustarlo de `snap` en `snap`
        SliderStepper {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 7
            anchors.rightMargin: 10
            readonly property real shown: Number((ps.value / ps.divisor).toFixed(ps.decimals))
            text: ps.unit === "" ? ("" + shown) : ps.unit === "%" ? (shown + "%") : (shown + " " + ps.unit)
            onStep: dir => ps.nudge(dir, true)
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: pl.bottom
            anchors.topMargin: 12
            height: 6
            radius: 3
            color: Theme.panelCardHi

            Rectangle {
                id: fillr
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: 3
                width: parent.width * (ps.value - ps.from) / Math.max(1, ps.to - ps.from)
                color: Theme.green
            }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#ffffff"
                border.width: 3
                border.color: Theme.green
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
