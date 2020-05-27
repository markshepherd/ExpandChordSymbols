import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.4

MuseScore {
    version: "1.0"
    description: "test"
    menuPath: "Plugins.Command Tester…"
    pluginType: "dock"
    dockArea: "left"
    id: window
    width:  600;
    height: 300;

    TextEdit {
        id: textInput
        wrapMode: Text.WordWrap
        text: "xxxxx"
        font.pointSize:15
        anchors.left: window.left
        anchors.right: window.right
        anchors.top: window.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 10
    }

    Button {
        id : buttonExpand
        text: "Do Command"
        anchors.top: textInput.bottom
        anchors.left: window.left
        anchors.leftMargin: 10
        anchors.topMargin: 10
        onClicked: {
            console.log("cmd", textInput.text);
            cmd(textInput.text);
        }
    }

    Button {
        id : buttonCancel
        text: "Done"
        anchors.bottom: window.bottom
        anchors.right: buttonExpand.left
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        onClicked: {
            Qt.quit();
        }
    }

    onRun: {
        var x = curScore.selection.elements[0];
        while (x) {
            console.log(x.name);
            x = x.parent;
        }
    }
}
