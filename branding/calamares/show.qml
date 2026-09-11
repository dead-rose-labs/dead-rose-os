import QtQuick
import calamares.slideshow
Presentation {
    Slide {
        Rectangle {
            anchors.fill: parent; color: "#111014"
            Column {
                anchors.centerIn: parent; spacing: 24
                Image { anchors.horizontalCenter: parent.horizontalCenter; source: "logo.svg"; width: 100; height: 100 }
                Text { text: "DEAD ROSE OS"; color: "#f5f2f4"; font.pixelSize: 28; font.letterSpacing: 4 }
                Text { text: "A quiet place to build.\n\nArch Linux · KDE Plasma"; color: "#aaa0a7"; font.pixelSize: 18 }
            }
        }
    }
}
