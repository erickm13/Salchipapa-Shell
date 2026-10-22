pragma Singleton
// Teclas pulsadas en la isla, como Show Me The Key (para grabaciones o enseñar atajos).
// showmethekey-cli lee el teclado con libinput y saca una línea JSON por tecla; necesita root, así
// que va con pkexec (la contraseña la pide el agente polkit de la isla). Al ser de root no se le
// puede mandar una señal: se para escribiéndole "stop". Solo lee mientras está activo y no guarda
// nada. La distribución es "us" (input.lua): los símbolos se sacan de esa.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool active: false
    // Lo que se ve: [{ kind: "text" | "combo", text, count }], lo más nuevo al final
    property var chips: []
    signal pressed

    function toggle(): void {
        if (active)
            stop();
        else
            start();
    }
    function start(): void {
        active = true;
        proc.running = true;
    }
    function stop(): void {
        active = false;
        if (proc.running)
            proc.write("stop\n");
        clear();
    }
    function clear(): void {
        chips = [];
        held = {};
    }
    // Al ocultarse la isla, la siguiente tecla empieza de cero (los modificadores siguen pulsados)
    function clearChips(): void {
        chips = [];
    }

    readonly property var modNames: ({
        KEY_LEFTMETA: "Super", KEY_RIGHTMETA: "Super",
        KEY_LEFTCTRL: "Ctrl", KEY_RIGHTCTRL: "Ctrl",
        KEY_LEFTALT: "Alt", KEY_RIGHTALT: "AltGr",
        KEY_LEFTSHIFT: "Shift", KEY_RIGHTSHIFT: "Shift"
    })
    readonly property var modOrder: ["Super", "Ctrl", "Alt", "AltGr", "Shift"]
    // Símbolos de la distribución us: [normal, con Shift]. El espacio no: va en su propia pastilla,
    // como ⌫ o Enter
    readonly property var symbols: ({
        KEY_1: ["1", "!"], KEY_2: ["2", "@"], KEY_3: ["3", "#"], KEY_4: ["4", "$"], KEY_5: ["5", "%"],
        KEY_6: ["6", "^"], KEY_7: ["7", "&"], KEY_8: ["8", "*"], KEY_9: ["9", "("], KEY_0: ["0", ")"],
        KEY_MINUS: ["-", "_"], KEY_EQUAL: ["=", "+"], KEY_LEFTBRACE: ["[", "{"], KEY_RIGHTBRACE: ["]", "}"],
        KEY_SEMICOLON: [";", ":"], KEY_APOSTROPHE: ["'", "\""], KEY_GRAVE: ["`", "~"], KEY_BACKSLASH: ["\\", "|"],
        KEY_COMMA: [",", "<"], KEY_DOT: [".", ">"], KEY_SLASH: ["/", "?"]
    })
    readonly property var specials: ({
        KEY_ENTER: "Enter ⏎", KEY_KPENTER: "Enter ⏎", KEY_BACKSPACE: "⌫", KEY_TAB: "Tab ⇥", KEY_ESC: "Esc",
        KEY_SPACE: "Space", KEY_DELETE: "Del", KEY_INSERT: "Ins", KEY_HOME: "Home", KEY_END: "End",
        KEY_PAGEUP: "PgUp", KEY_PAGEDOWN: "PgDn", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
        KEY_CAPSLOCK: "Caps", KEY_SYSRQ: "PrtSc", KEY_PRINT: "PrtSc", KEY_MUTE: "Mute",
        KEY_VOLUMEUP: "Vol +", KEY_VOLUMEDOWN: "Vol −", KEY_BRIGHTNESSUP: "Bright +", KEY_BRIGHTNESSDOWN: "Bright −",
        KEY_PLAYPAUSE: "Play/Pause", KEY_NEXTSONG: "Next", KEY_PREVIOUSSONG: "Prev"
    })

    property var held: ({}) // modificadores pulsados ahora
    property bool modAlone: false // se pulsó un modificador y aún ninguna otra tecla

    function heldMods(): var {
        return modOrder.filter(m => held[m]);
    }

    // Texto de una tecla suelta (sin modificadores): letra/símbolo, o null si no es imprimible
    function printable(key: string, shift: bool): var {
        const m = key.match(/^KEY_([A-Z])$/);
        if (m)
            return shift ? m[1] : m[1].toLowerCase();
        return symbols[key] ? symbols[key][shift ? 1 : 0] : null;
    }
    function label(key: string): string {
        if (specials[key])
            return specials[key];
        const m = key.match(/^KEY_([A-Z0-9])$/);
        if (m)
            return m[1];
        if (symbols[key])
            return symbols[key][0];
        const name = key.replace(/^KEY_/, "");
        return name.charAt(0) + name.slice(1).toLowerCase();
    }

    function push(kind: string, text: string): void {
        const list = chips.slice();
        const last = list[list.length - 1];
        if (kind === "text" && last?.kind === "text") {
            // Las letras seguidas forman una palabra (se recorta por el principio)
            list[list.length - 1] = { kind: "text", text: (last.text + text).slice(-24), count: 1 };
        } else if (kind === "combo" && last?.kind === "combo" && last.text === text) {
            list[list.length - 1] = { kind: "combo", text: text, count: last.count + 1 };
        } else {
            list.push({ kind: kind, text: text, count: 1 });
        }
        chips = list.slice(-5);
        pressed();
    }

    function handle(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.event_name !== "KEYBOARD_KEY")
            return;
        const key = ev.key_name;
        const down = ev.state_name === "PRESSED";
        const mod = modNames[key];
        if (mod) {
            const h = Object.assign({}, held);
            if (down) {
                if (heldMods().length === 0)
                    modAlone = true;
                h[mod] = true;
            } else {
                // Un modificador solo (p. ej. Super para abrir algo) también se muestra
                if (modAlone)
                    push("combo", heldMods().join(" + "));
                delete h[mod];
                modAlone = false;
            }
            held = h;
            return;
        }
        if (!down)
            return;
        modAlone = false;
        const mods = heldMods();
        const shiftOnly = mods.length === 1 && mods[0] === "Shift";
        const ch = mods.length === 0 || shiftOnly ? printable(key, shiftOnly) : null;
        if (ch !== null)
            push("text", ch);
        else
            push("combo", mods.concat([label(key)]).join(" + "));
    }

    Process {
        id: proc
        command: ["pkexec", "/usr/bin/showmethekey-cli"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        // Contraseña cancelada, error o parada: deja de estar activo
        onExited: {
            root.active = false;
            root.clear();
        }
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "keys"
        description: "Mostrar/ocultar las teclas pulsadas en la isla"
        onPressed: root.toggle()
    }
}
