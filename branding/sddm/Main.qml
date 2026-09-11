import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#0b0b0e"
    property bool busy: false
    function login() {
        if (user.text.length && !busy) {
            busy = true;
            message.text = "";
            sddm.login(user.text, password.text, session.currentIndex);
        }
    }
    Image { anchors.fill: parent; source: config.background; fillMode: Image.PreserveAspectCrop; opacity: 0.24 }
    Rectangle {
        anchors.centerIn: parent
        width: 400; height: form.implicitHeight + 72
        radius: 24; color: "#ed171519"; border.color: "#3b2a32"
        ColumnLayout {
            id: form
            anchors.centerIn: parent; width: 304; spacing: 18
            Image { source: "/usr/share/icons/deadrose/scalable/apps/dead-rose.svg"; Layout.alignment: Qt.AlignHCenter; sourceSize: Qt.size(72,72) }
            Label { text: "DEAD ROSE"; color: "#f5f2f4"; font.pixelSize: 24; font.letterSpacing: 5; Layout.alignment: Qt.AlignHCenter }
            TextField {
                id: user; Layout.fillWidth: true; placeholderText: "Username"
                text: userModel.lastUser; color: "#f5f2f4"; focus: !text.length
                Accessible.name: "Username"; onAccepted: password.forceActiveFocus()
                background: Rectangle { color: "#252027"; radius: 8; border.color: user.activeFocus ? "#8a2d45" : "#44343e" }
            }
            TextField {
                id: password; Layout.fillWidth: true; placeholderText: "Password"; echoMode: TextInput.Password
                color: "#f5f2f4"; focus: user.text.length > 0
                Accessible.name: "Password"; onAccepted: root.login()
                background: Rectangle { color: "#252027"; radius: 8; border.color: password.activeFocus ? "#8a2d45" : "#44343e" }
            }
            ComboBox {
                id: session; Layout.fillWidth: true; model: sessionModel; textRole: "name"
                currentIndex: sessionModel.lastIndex; Accessible.name: "Desktop session"
                palette.button: "#252027"; palette.buttonText: "#f5f2f4"; palette.base: "#252027"; palette.text: "#f5f2f4"
            }
            ComboBox {
                Layout.fillWidth: true; model: keyboard.layouts; textRole: "longName"
                currentIndex: keyboard.currentLayout; onActivated: keyboard.currentLayout = currentIndex
                visible: keyboard.layouts.length > 1; Accessible.name: "Keyboard layout"
                palette.button: "#252027"; palette.buttonText: "#f5f2f4"; palette.base: "#252027"; palette.text: "#f5f2f4"
            }
            Label { text: "Caps Lock is on"; color: "#cfa3ad"; visible: keyboard.capsLock }
            Label { id: message; Layout.fillWidth: true; wrapMode: Text.Wrap; color: "#e294a6"; visible: text.length > 0 }
            Button {
                text: root.busy ? "Signing in…" : "Sign in"; Layout.fillWidth: true; enabled: !root.busy
                palette.button: "#8a2d45"; palette.buttonText: "#ffffff"; onClicked: root.login()
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Button { text: "Restart"; enabled: sddm.canReboot; onClicked: sddm.reboot() }
                Button { text: "Shut down"; enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
            }
        }
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; message.text = "Sign-in failed. Check your username and password."; password.text = ""; password.forceActiveFocus(); }
    }
}
