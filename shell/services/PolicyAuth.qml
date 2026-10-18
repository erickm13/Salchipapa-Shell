pragma Singleton
// Agente PolicyKit integrado en Salchipapa Shell.
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive
    readonly property bool registered: agent.isRegistered
    property string responseText: ""

    function submit(response: string): void {
        const currentFlow = agent.flow;
        if (!currentFlow || response.length === 0)
            return;

        currentFlow.submit(response);
        responseText = "";
    }

    function cancel(): void {
        agent.flow?.cancelAuthenticationRequest();
        responseText = "";
    }

    onActiveChanged: {
        if (!active)
            responseText = "";
    }

    PolkitAgent {
        id: agent
        path: "/org/salchipapa/Shell/PolicyAuth"
    }
}
