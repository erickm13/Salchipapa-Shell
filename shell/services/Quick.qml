pragma Singleton
// Estado de los interruptores rápidos: Night light, Game mode y Focus (No molestar).
// Lo comparten el dashboard expandido y el centro de control (ControlContent).
import Quickshell
import Quickshell.Hyprland
import "../common"

Singleton {
    id: root

    property bool nightLight: false
    readonly property bool gameMode: Config.gameMode
    property bool dnd: false // Focus / No molestar

    // ¿Se deben silenciar los peeks de notificación? (Focus o Game mode)
    readonly property bool silenced: dnd || gameMode

    function toggleNightLight(): void {
        nightLight = !nightLight;
        // hyprsunset como daemon (exec_cmd de Hyprland lo lanza desacoplado)
        Hyprland.dispatch("hl.dsp.exec_cmd('" + (nightLight ? "hyprsunset -t 4000" : "pkill hyprsunset") + "')");
    }
    function toggleGameMode(): void {
        Config.gameMode = !Config.gameMode;
    }
    function toggleDnd(): void {
        dnd = !dnd;
    }
}
