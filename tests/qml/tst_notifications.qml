import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import services

ShellRoot {
    id: root

    property bool integrationActionInvoked: false
    readonly property string integrationTargetClass: Quickshell.env("NOTIFICATIONS_TEST_CLASS") || ""
    readonly property string integrationTargetAddress: Quickshell.env("NOTIFICATIONS_TEST_ADDRESS") || ""
    property string activeAddressAtInvocation: ""

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }

    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    function fail(message) {
        throw new Error(message);
    }

    function verify(value, message) {
        if (!value) root.fail(message || "verification failed");
    }

    function compare(actual, expected, message) {
        if (actual !== expected) {
            root.fail((message || "values differ") + `: expected ${expected}, got ${actual}`);
        }
    }

    function normalizedAddress(address) {
        return String(address || "").toLowerCase().replace(/^0x/, "");
    }

    function pass() {
        console.warn("NOTIFICATIONS_TEST_PASS");
        root._terminateDelay.start();
    }

    function reportFailure(error) {
        console.error("NOTIFICATIONS_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    function test_historyEntryDoesNotRetainNotificationObjects() {
        const action = {
            identifier: "default",
            text: "Open",
            invoke: function() {}
        };
        const entry = Notifications._historyEntry({
            summary: "Build complete",
            body: "The application compiled successfully.",
            appName: "Builder",
            appIcon: "builder",
            desktopEntry: "org.example.Builder",
            actions: [action]
        });

        root.compare(entry.summary, "Build complete");
        root.compare(entry.desktopEntry, "org.example.Builder");
        root.verify(entry.time instanceof Date, "history timestamp is not a Date");
        root.compare(entry.action, undefined, "history retained an action object");
        root.compare(entry.actions, undefined, "history retained action objects");
        root.compare(entry.senderPid, undefined, "history retained sender PID");
    }

    function test_actionInvocationDoesNotReadDestroyedNotification() {
        let destroyed = false;
        const action = {
            identifier: "default",
            text: "Open",
            invoke: function() { destroyed = true; }
        };
        const notification = { actions: [action] };

        Object.defineProperty(notification, "desktopEntry", {
            get: function() {
                if (destroyed) throw new Error("notification was destroyed");
                return "";
            }
        });
        Object.defineProperty(notification, "appName", {
            get: function() {
                if (destroyed) throw new Error("notification was destroyed");
                return "";
            }
        });

        root.verify(Notifications.focusApp(notification), "default action was not handled");
        root.verify(destroyed, "default action was not invoked");
    }

    function test_hyprland056FocusRequestUsesWindowAddress() {
        root.compare(
            Notifications._focusRequest("0xAbC123"),
            'hl.dsp.focus({ window = "address:0xAbC123" })'
        );
        root.compare(Notifications._focusRequest(""), "");
    }

    function test_actionSchedulesBoundedFocusRetries() {
        let invoked = false;
        const action = {
            identifier: "default",
            text: "Open",
            invoke: function() { invoked = true; }
        };

        root.verify(Notifications.focusApp({
            actions: [action],
            desktopEntry: "org.example.Missing",
            appName: "Missing"
        }), "action was not handled");
        root.verify(invoked, "action was not invoked before scheduling focus");
        root.compare(Notifications._pendingFocusDesktopEntry, "org.example.Missing");
        root.compare(Notifications._pendingFocusAppName, "Missing");
        root.compare(Notifications._focusAttemptsRemaining, 3);
        root.verify(Notifications._actionFocusTimer.running, "focus retry timer was not started");
        Notifications._actionFocusTimer.stop();
    }

    function runHyprlandIntegrationTest() {
        root.verify(root.integrationTargetAddress, "target Hyprland window was not found");

        const action = {
            identifier: "default",
            text: "Open",
            invoke: function() {
                root.integrationActionInvoked = true;
                root.activeAddressAtInvocation = Hyprland.activeToplevel
                    ? Hyprland.activeToplevel.address
                    : "";
            }
        };

        root.verify(Notifications.focusApp({
            actions: [action],
            desktopEntry: root.integrationTargetClass,
            appName: root.integrationTargetClass
        }), "integration action was not handled");

        root.verify(root.integrationActionInvoked, "integration action was not invoked");
        root.verify(
            root.normalizedAddress(root.activeAddressAtInvocation)
                !== root.normalizedAddress(root.integrationTargetAddress),
            "target was already focused before action invocation"
        );
        focusCheck.start();
    }

    Timer {
        id: toplevelCheck
        property int attempts: 0

        interval: 50
        repeat: true

        onTriggered: {
            attempts++;
            const resolvedAddress = Notifications._windowAddress(
                root.integrationTargetClass,
                root.integrationTargetClass
            );
            if (root.normalizedAddress(resolvedAddress)
                    === root.normalizedAddress(root.integrationTargetAddress)) {
                stop();
                try {
                    root.runHyprlandIntegrationTest();
                } catch (error) {
                    root.reportFailure(error);
                }
            } else if (attempts >= 20) {
                stop();
                root.reportFailure(new Error(
                    `target Hyprland window was not found: expected ${root.integrationTargetAddress}, got ${resolvedAddress}`
                ));
            }
        }
    }

    Timer {
        id: focusCheck
        property int attempts: 0

        interval: 50
        repeat: true

        onTriggered: {
            attempts++;
            const activeAddress = root.normalizedAddress(
                Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
            );
            if (activeAddress !== root.normalizedAddress(root.integrationTargetAddress)
                    && attempts < 20) {
                return;
            }

            stop();
            try {
                root.compare(
                    activeAddress,
                    root.normalizedAddress(root.integrationTargetAddress),
                    "Hyprland did not focus the target after action invocation"
                );
                root.pass();
            } catch (error) {
                root.reportFailure(error);
            }
        }
    }

    Component.onCompleted: {
        try {
            root.test_historyEntryDoesNotRetainNotificationObjects();
            root.test_actionInvocationDoesNotReadDestroyedNotification();
            root.test_hyprland056FocusRequestUsesWindowAddress();
            root.test_actionSchedulesBoundedFocusRetries();
            if (root.integrationTargetClass) {
                root.verify(root.integrationTargetAddress, "expected Hyprland address was not provided");
                Hyprland.refreshToplevels();
                toplevelCheck.start();
                return;
            }
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
