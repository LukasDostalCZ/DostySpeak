import QtQuick

Window {
    id: root
    width: 430
    height: 820
    visible: true
    title: "Dosty Speak Mobile"
    color: bg

    property string selectedLanguage: "cs-CZ"
    property real speechRate: 1.0
    property bool darkMode: true
    property int currentTab: 0
    property bool editMode: false
    property string editorMode: "saved"
    property int editorIndex: -1
    property string editorTitle: "Upravit hlášku"

    // Android/iOS draw the app under the system status/navigation bars.
    // Keep the touch UI away from the clock, camera cutout and gesture bar.
    property int safeTop: Qt.platform.os === "android" ? 34 : (Qt.platform.os === "ios" ? 46 : 0)
    property int safeBottom: Qt.platform.os === "android" ? 18 : (Qt.platform.os === "ios" ? 28 : 0)

    property color bg: darkMode ? "#07111f" : "#f6f7fb"
    property color panel: darkMode ? "#101827" : "#ffffff"
    property color card: darkMode ? "#14263a" : "#ffffff"
    property color cardSoft: darkMode ? "#1e2b3d" : "#eef2f7"
    property color textColor: darkMode ? "#f8fafc" : "#111827"
    property color muted: darkMode ? "#a8b3c7" : "#667085"
    property color border: darkMode ? "#243b55" : "#cbd5e1"
    property color accent: "#0d6efd"
    property color accent2: "#22d3ee"

    ListModel { id: quickModel }
    ListModel { id: savedModel }

    function speakText(value) {
        if (!value || value.trim().length === 0)
            return
        input.text = value.trim()
        input.cursorPosition = input.text.length
        if (typeof bridge !== "undefined")
            bridge.speakWithSettings(input.text, selectedLanguage, speechRate)
        else
            console.log("Dosty Speak Mobile:", input.text)
    }

    function stopSpeech() {
        if (typeof bridge !== "undefined")
            bridge.stop()
    }

    function modelToArray(model) {
        var out = []
        for (var i = 0; i < model.count; i++)
            out.push(model.get(i).text)
        return out
    }

    function persistSaved() {
        if (typeof bridge !== "undefined")
            bridge.saveSavedPhraseList(modelToArray(savedModel))
    }

    function persistQuick() {
        if (typeof bridge !== "undefined")
            bridge.saveQuickPhraseList(modelToArray(quickModel))
    }

    function fillModel(model, values) {
        model.clear()
        for (var i = 0; i < values.length; i++) {
            var v = ("" + values[i]).trim()
            if (v.length > 0)
                model.append({ "text": v })
        }
    }

    function loadData() {
        var quickDefaults = ["Ano.", "Ne.", "Prosím.", "Děkuji.", "Pomoc.", "Zopakovat."]
        var savedDefaults = [
            "Dobrý den, omlouvám se, momentálně nemůžu mluvit. Budu používat hlasový syntetizátor.",
            "Můžete to prosím zopakovat pomaleji?",
            "Děkuji, rozumím.",
            "Potřebuji pomoc.",
            "Na schůzce budu odpovídat přes hlasový syntetizátor.",
            "Prosím chvilku, napíšu odpověď."
        ]

        var quick = quickDefaults
        var saved = savedDefaults
        if (typeof bridge !== "undefined") {
            quick = bridge.loadQuickPhrases()
            saved = bridge.loadSavedPhrases()
            if (!quick || quick.length === 0) quick = quickDefaults
            if (!saved || saved.length === 0) saved = savedDefaults
        }
        fillModel(quickModel, quick)
        fillModel(savedModel, saved)
    }

    function saveCurrentInput() {
        var value = input.text.trim()
        if (value.length === 0)
            return
        savedModel.insert(0, { "text": value })
        persistSaved()
    }

    function openEditor(mode, index, text) {
        editorMode = mode
        editorIndex = index
        editorTitle = mode === "quick" ? "Rychlá hláška" : "Uložená hláška"
        editorInput.text = text || ""
        editMode = true
        editorInput.forceActiveFocus()
    }

    function commitEditor() {
        var value = editorInput.text.trim()
        if (value.length === 0)
            return
        var model = editorMode === "quick" ? quickModel : savedModel
        if (editorIndex >= 0 && editorIndex < model.count)
            model.setProperty(editorIndex, "text", value)
        else
            model.insert(0, { "text": value })
        if (editorMode === "quick") persistQuick(); else persistSaved()
        editMode = false
    }

    function deleteEditorItem() {
        var model = editorMode === "quick" ? quickModel : savedModel
        if (editorIndex >= 0 && editorIndex < model.count) {
            model.remove(editorIndex)
            if (editorMode === "quick") persistQuick(); else persistSaved()
        }
        editMode = false
    }

    Component.onCompleted: loadData()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64 + safeTop
        color: panel

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: safeTop + (64 - height) / 2
            text: "Dosty Speak"
            color: textColor
            font.pixelSize: 24
            font.bold: true
        }

        Rectangle {
            visible: currentTab === 0
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: safeTop + (64 - height) / 2
            width: 112
            height: 38
            radius: 19
            color: accent
            Text { anchors.centerIn: parent; text: "+ Uložit"; color: "white"; font.pixelSize: 16; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: saveCurrentInput() }
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top
        contentWidth: width
        contentHeight: contentColumn.height + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: flick.width
            spacing: 14
            padding: 18

            Text {
                width: parent.width - 36
                text: currentTab === 0 ? "Hlášky" : currentTab === 1 ? "Hlas" : currentTab === 2 ? "Rychlé hlášky" : "Nastavení"
                color: textColor
                font.pixelSize: 30
                font.bold: true
            }

            Rectangle {
                visible: currentTab === 0
                width: parent.width - 36
                height: 150
                radius: 22
                color: darkMode ? "#06111f" : "#ffffff"
                border.color: input.activeFocus ? accent2 : border
                border.width: input.activeFocus ? 2 : 1

                TextEdit {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 16
                    text: ""
                    color: textColor
                    font.pixelSize: 22
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    verticalAlignment: TextEdit.AlignTop
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: speakText(text)
                }

                Text {
                    visible: input.text.length === 0 && !input.activeFocus
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 16
                    anchors.topMargin: 16
                    text: "Napiš větu..."
                    color: muted
                    font.pixelSize: 22
                }
            }

            Flow {
                visible: currentTab === 0
                width: parent.width - 36
                spacing: 8

                Repeater {
                    model: quickModel
                    delegate: Rectangle {
                        width: Math.max(92, quickLabel.implicitWidth + 30)
                        height: 50
                        radius: 17
                        color: cardSoft
                        border.color: border
                        Text { id: quickLabel; anchors.centerIn: parent; text: model.text; color: textColor; font.pixelSize: 17 }
                        MouseArea { anchors.fill: parent; onClicked: speakText(model.text) }
                    }
                }
            }

            Row {
                visible: currentTab === 0
                width: parent.width - 36
                spacing: 10

                Rectangle {
                    width: (parent.width - 20) / 3
                    height: 62
                    radius: 18
                    color: accent
                    Text { anchors.centerIn: parent; text: "Přečíst"; color: "white"; font.pixelSize: 18; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: speakText(input.text) }
                }
                Rectangle {
                    width: (parent.width - 20) / 3
                    height: 62
                    radius: 18
                    color: cardSoft
                    border.color: border
                    Text { anchors.centerIn: parent; text: "Uložit"; color: textColor; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; onClicked: saveCurrentInput() }
                }
                Rectangle {
                    width: (parent.width - 20) / 3
                    height: 62
                    radius: 18
                    color: cardSoft
                    border.color: border
                    Text { anchors.centerIn: parent; text: "Stop"; color: textColor; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; onClicked: stopSpeech() }
                }
            }

            Text {
                visible: currentTab === 0
                width: parent.width - 36
                text: "Uložené hlášky"
                color: textColor
                font.pixelSize: 24
                font.bold: true
            }

            Repeater {
                visible: currentTab === 0
                model: savedModel
                delegate: Rectangle {
                    visible: currentTab === 0
                    width: contentColumn.width - 36
                    height: Math.max(92, phrase.implicitHeight + 48)
                    radius: 22
                    color: card
                    border.color: border

                    Text {
                        id: phrase
                        anchors.left: parent.left
                        anchors.right: editButton.left
                        anchors.top: parent.top
                        anchors.margins: 16
                        text: model.text
                        color: textColor
                        font.pixelSize: 18
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
                        anchors.bottomMargin: 10
                        text: "Klepni pro přečtení"
                        color: muted
                        font.pixelSize: 12
                    }
                    Rectangle {
                        id: editButton
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 62
                        height: 38
                        radius: 14
                        color: cardSoft
                        border.color: border
                        Text { anchors.centerIn: parent; text: "Upravit"; color: textColor; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: openEditor("saved", index, model.text) }
                    }
                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: editButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        onClicked: speakText(model.text)
                    }
                }
            }

            Column {
                visible: currentTab === 1
                width: parent.width - 36
                spacing: 14

                Text { width: parent.width; text: "Jazyk"; color: textColor; font.pixelSize: 18; font.bold: true }
                Row {
                    spacing: 10
                    Rectangle { width: 140; height: 54; radius: 16; color: selectedLanguage === "cs-CZ" ? accent : cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Čeština"; color: selectedLanguage === "cs-CZ" ? "white" : textColor; font.pixelSize: 17 } MouseArea { anchors.fill: parent; onClicked: selectedLanguage = "cs-CZ" } }
                    Rectangle { width: 140; height: 54; radius: 16; color: selectedLanguage === "en-US" ? accent : cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "English"; color: selectedLanguage === "en-US" ? "white" : textColor; font.pixelSize: 17 } MouseArea { anchors.fill: parent; onClicked: selectedLanguage = "en-US" } }
                }
                Text { text: "Rychlost: " + speechRate.toFixed(1) + "×"; color: textColor; font.pixelSize: 18 }
                Row {
                    spacing: 10
                    Rectangle { width: 100; height: 54; radius: 16; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Pomaleji"; color: textColor; font.pixelSize: 15 } MouseArea { anchors.fill: parent; onClicked: speechRate = Math.max(0.6, speechRate - 0.1) } }
                    Rectangle { width: 100; height: 54; radius: 16; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Rychleji"; color: textColor; font.pixelSize: 15 } MouseArea { anchors.fill: parent; onClicked: speechRate = Math.min(1.6, speechRate + 0.1) } }
                }
                Rectangle { width: parent.width; height: 60; radius: 18; color: accent; Text { anchors.centerIn: parent; text: "Otestovat hlas"; color: "white"; font.pixelSize: 18; font.bold: true } MouseArea { anchors.fill: parent; onClicked: speakText("Toto je test hlasu.") } }
            }

            Column {
                visible: currentTab === 2
                width: parent.width - 36
                spacing: 12

                Text {
                    width: parent.width
                    text: "Rychlé hlášky se ukazují jako tlačítka nahoře. Klepnutí je rovnou přečte. Tady je můžeš upravit."
                    color: muted
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 18
                    color: accent
                    Text { anchors.centerIn: parent; text: "+ Přidat rychlou hlášku"; color: "white"; font.pixelSize: 17; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: openEditor("quick", -1, "") }
                }

                Repeater {
                    model: quickModel
                    delegate: Rectangle {
                        width: parent.width
                        height: 70
                        radius: 20
                        color: card
                        border.color: border

                        Text {
                            anchors.left: parent.left
                            anchors.right: editQuick.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: model.text
                            color: textColor
                            font.pixelSize: 18
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            id: editQuick
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 66
                            height: 40
                            radius: 14
                            color: cardSoft
                            border.color: border
                            Text { anchors.centerIn: parent; text: "Upravit"; color: textColor; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: openEditor("quick", index, model.text) }
                        }
                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: editQuick.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            onClicked: speakText(model.text)
                        }
                    }
                }
            }

            Column {
                visible: currentTab === 3
                width: parent.width - 36
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 18
                    color: card
                    border.color: border
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; text: "Tmavý režim"; color: textColor; font.pixelSize: 18 }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 30
                        radius: 15
                        color: darkMode ? accent : "#cbd5e1"
                        Rectangle { width: 24; height: 24; radius: 12; anchors.verticalCenter: parent.verticalCenter; x: darkMode ? parent.width - width - 3 : 3; color: "white" }
                    }
                    MouseArea { anchors.fill: parent; onClicked: darkMode = !darkMode }
                }

                Text {
                    width: parent.width
                    text: "Toto je dotyková mobilní verze. Uložené a rychlé hlášky se ukládají přímo v aplikaci."
                    color: muted
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 76 + safeBottom
        color: panel
        border.color: border

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8 + safeBottom
            spacing: 8
            Repeater {
                model: [
                    { label: "Hlášky", tab: 0 },
                    { label: "Hlas", tab: 1 },
                    { label: "Rychlé", tab: 2 },
                    { label: "Nastavení", tab: 3 }
                ]
                delegate: Rectangle {
                    width: (footer.width - 48) / 4
                    height: 60
                    radius: 16
                    color: currentTab === modelData.tab ? accent : cardSoft
                    border.color: currentTab === modelData.tab ? accent2 : border
                    Text { anchors.centerIn: parent; text: modelData.label; color: currentTab === modelData.tab ? "white" : textColor; font.pixelSize: 14; font.bold: currentTab === modelData.tab }
                    MouseArea { anchors.fill: parent; onClicked: currentTab = modelData.tab }
                }
            }
        }
    }

    Rectangle {
        visible: editMode
        anchors.fill: parent
        color: "#99000000"
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            anchors.bottomMargin: 14 + safeBottom
            height: 310
            radius: 26
            color: panel
            border.color: border

            Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: 18; anchors.topMargin: 16; text: editorTitle; color: textColor; font.pixelSize: 24; font.bold: true }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 58
                anchors.margins: 18
                height: 120
                radius: 18
                color: darkMode ? "#06111f" : "#ffffff"
                border.color: editorInput.activeFocus ? accent2 : border
                border.width: 2

                TextEdit {
                    id: editorInput
                    anchors.fill: parent
                    anchors.margins: 14
                    color: textColor
                    font.pixelSize: 20
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 8

                Rectangle { width: (parent.width - 16) / 3; height: 56; radius: 17; color: accent; Text { anchors.centerIn: parent; text: "Uložit"; color: "white"; font.pixelSize: 17; font.bold: true } MouseArea { anchors.fill: parent; onClicked: commitEditor() } }
                Rectangle { width: (parent.width - 16) / 3; height: 56; radius: 17; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Smazat"; color: textColor; font.pixelSize: 17 } MouseArea { anchors.fill: parent; onClicked: deleteEditorItem() } }
                Rectangle { width: (parent.width - 16) / 3; height: 56; radius: 17; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Zrušit"; color: textColor; font.pixelSize: 17 } MouseArea { anchors.fill: parent; onClicked: editMode = false } }
            }
        }
    }
}
