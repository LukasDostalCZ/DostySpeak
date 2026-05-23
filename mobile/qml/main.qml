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
    property bool saveFlash: false
    property string saveToastText: ""
    property real saveToastOpacity: 0
    property string savedSortMode: "newest"
    property string editorTitle: "Upravit hlášku"

    // Android/iOS draw the app under the system status/navigation bars.
    // Keep the touch UI away from the clock, camera cutout and gesture bar.
    property int safeTop: Qt.platform.os === "android" ? 34 : (Qt.platform.os === "ios" ? 46 : 0)
    property int safeBottom: Qt.platform.os === "android" ? 18 : (Qt.platform.os === "ios" ? 28 : 0)
    property real keyboardInset: Qt.inputMethod.visible ? Math.max(0, Qt.inputMethod.keyboardRectangle.height) : 0

    property color bg: darkMode ? "#0b1220" : "#f6f7fb"
    property color panel: darkMode ? "#0f172a" : "#ffffff"
    property color card: darkMode ? "#111c2e" : "#ffffff"
    property color cardSoft: darkMode ? "#172235" : "#eef2f7"
    property color field: darkMode ? "#08111f" : "#ffffff"
    property color textColor: darkMode ? "#e5e7eb" : "#111827"
    property color muted: darkMode ? "#94a3b8" : "#667085"
    property color border: darkMode ? "#263447" : "#d5dbe5"
    property color accent: "#2563eb"
    property color accentPressed: "#1d4ed8"
    property color accent2: "#38bdf8"

    ListModel { id: quickModel }
    ListModel { id: savedModel }

    Timer {
        id: saveFlashTimer
        interval: 260
        repeat: false
        onTriggered: saveFlash = false
    }

    Timer {
        id: saveToastTimer
        interval: 900
        repeat: false
        onTriggered: saveToastOpacity = 0
    }

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

    function showSaveFeedback(message) {
        saveFlash = true
        saveFlashTimer.restart()
        saveToastText = message || "Uloženo"
        saveToastOpacity = 1
        saveToastTimer.restart()
    }

    function sortSavedModel() {
        var values = modelToArray(savedModel)
        if (savedSortMode === "az") {
            values.sort(function(a, b) { return a.localeCompare(b) })
        } else if (savedSortMode === "short") {
            values.sort(function(a, b) { return a.length - b.length })
        } else if (savedSortMode === "long") {
            values.sort(function(a, b) { return b.length - a.length })
        }
        fillModel(savedModel, values)
        persistSaved()
    }

    function removeSavedAt(index) {
        if (index >= 0 && index < savedModel.count) {
            savedModel.remove(index)
            persistSaved()
            showSaveFeedback("Smazáno")
        }
    }

    function removeQuickAt(index) {
        if (index >= 0 && index < quickModel.count) {
            quickModel.remove(index)
            persistQuick()
            showSaveFeedback("Smazáno")
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
        if (savedSortMode !== "newest")
            sortSavedModel()
        persistSaved()
        showSaveFeedback("Hláška uložena")
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
        if (editorMode === "saved" && savedSortMode !== "newest")
            sortSavedModel()
        showSaveFeedback("Uloženo")
        editMode = false
    }

    function deleteEditorItem() {
        var model = editorMode === "quick" ? quickModel : savedModel
        if (editorIndex >= 0 && editorIndex < model.count) {
            model.remove(editorIndex)
            if (editorMode === "quick") persistQuick(); else persistSaved()
            showSaveFeedback("Smazáno")
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
        height: 58 + safeTop
        color: panel

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: safeTop + (58 - height) / 2
            text: "Dosty Speak"
            color: textColor
            font.pixelSize: 22
            font.bold: true
        }

        Rectangle {
            id: headerSaveButton
            visible: currentTab === 0
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: safeTop + (58 - height) / 2
            width: 104
            height: 36
            radius: 12
            color: headerSaveMouse.pressed || saveFlash ? accentPressed : accent
            scale: saveFlash ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 130 } }
            Text { anchors.centerIn: parent; text: "+ Uložit"; color: "white"; font.pixelSize: 15; font.bold: true }
            MouseArea { id: headerSaveMouse; anchors.fill: parent; onClicked: saveCurrentInput() }
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
            spacing: 12
            padding: 16

            Text {
                width: parent.width - 32
                text: currentTab === 0 ? "Hlášky" : currentTab === 1 ? "Hlas" : currentTab === 2 ? "Rychlé hlášky" : "Nastavení"
                color: textColor
                font.pixelSize: 24
                font.bold: true
            }

            Rectangle {
                visible: currentTab === 0
                width: parent.width - 32
                height: 132
                radius: 14
                color: field
                border.color: input.activeFocus ? accent2 : border
                border.width: 1

                TextEdit {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 14
                    text: ""
                    color: textColor
                    font.pixelSize: 20
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
                    anchors.leftMargin: 14
                    anchors.topMargin: 14
                    text: "Napiš větu..."
                    color: muted
                    font.pixelSize: 20
                }
            }

            Flow {
                visible: currentTab === 0
                width: parent.width - 32
                spacing: 7

                Repeater {
                    model: quickModel
                    delegate: Rectangle {
                        width: Math.max(84, quickLabel.implicitWidth + 24)
                        height: 42
                        radius: 10
                        color: cardSoft
                        border.color: border
                        Text { id: quickLabel; anchors.centerIn: parent; text: model.text; color: textColor; font.pixelSize: 15 }
                        MouseArea { anchors.fill: parent; onClicked: speakText(model.text) }
                    }
                }
            }

            Row {
                visible: currentTab === 0
                width: parent.width - 32
                spacing: 8

                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 52
                    radius: 12
                    color: accent
                    Text { anchors.centerIn: parent; text: "Přečíst"; color: "white"; font.pixelSize: 16; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: speakText(input.text) }
                }
                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 52
                    radius: 12
                    color: saveFlash ? (darkMode ? "#111827" : "#d6deea") : cardSoft
                    border.color: border
                    scale: saveFlash ? 0.97 : 1.0
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 130 } }
                    Text { anchors.centerIn: parent; text: "Uložit"; color: textColor; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: saveCurrentInput() }
                }
                Rectangle {
                    width: (parent.width - 16) / 3
                    height: 52
                    radius: 12
                    color: cardSoft
                    border.color: border
                    Text { anchors.centerIn: parent; text: "Stop"; color: textColor; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: stopSpeech() }
                }
            }

            Text {
                visible: currentTab === 0
                width: parent.width - 32
                text: "Uložené hlášky"
                color: textColor
                font.pixelSize: 21
                font.bold: true
            }

            Repeater {
                visible: currentTab === 0
                model: savedModel
                delegate: Item {
                    visible: currentTab === 0
                    width: contentColumn.width - 32
                    height: Math.max(82, phrase.implicitHeight + 42)

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "#dc2626"
                        opacity: Math.min(1, Math.abs(savedCard.x) / 130)
                        Text { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: "Smazat"; color: "white"; font.pixelSize: 16; font.bold: true }
                    }

                    Rectangle {
                        id: savedCard
                        width: parent.width
                        height: parent.height
                        radius: 14
                        color: card
                        border.color: border
                        x: 0
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Text {
                        id: phrase
                        anchors.left: parent.left
                        anchors.right: editButton.left
                        anchors.top: parent.top
                        anchors.margins: 16
                        text: model.text
                        color: textColor
                        font.pixelSize: 17
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
                        anchors.bottomMargin: 10
                        text: "Klepni pro přečtení"
                        color: muted
                        font.pixelSize: 11
                    }
                    Rectangle {
                        id: editButton
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        width: 60
                        height: 34
                        radius: 10
                        color: cardSoft
                        border.color: border
                        Text { anchors.centerIn: parent; text: "Upravit"; color: textColor; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; onClicked: openEditor("saved", index, model.text) }
                    }
                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: editButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        drag.target: savedCard
                        drag.axis: Drag.XAxis
                        drag.minimumX: -150
                        drag.maximumX: 0
                        onClicked: speakText(model.text)
                        onReleased: {
                            if (savedCard.x < -105) {
                                removeSavedAt(index)
                            } else {
                                savedCard.x = 0
                            }
                        }
                    }
                    }
                }
            }

            Column {
                visible: currentTab === 1
                width: parent.width - 32
                spacing: 14

                Text { width: parent.width; text: "Jazyk"; color: textColor; font.pixelSize: 17; font.bold: true }
                Row {
                    spacing: 10
                    Rectangle { width: 132; height: 48; radius: 12; color: selectedLanguage === "cs-CZ" ? accent : cardSoft; border.color: selectedLanguage === "cs-CZ" ? accent : border; Text { anchors.centerIn: parent; text: "Čeština"; color: selectedLanguage === "cs-CZ" ? "white" : textColor; font.pixelSize: 15 } MouseArea { anchors.fill: parent; onClicked: selectedLanguage = "cs-CZ" } }
                    Rectangle { width: 132; height: 48; radius: 12; color: selectedLanguage === "en-US" ? accent : cardSoft; border.color: selectedLanguage === "en-US" ? accent : border; Text { anchors.centerIn: parent; text: "English"; color: selectedLanguage === "en-US" ? "white" : textColor; font.pixelSize: 15 } MouseArea { anchors.fill: parent; onClicked: selectedLanguage = "en-US" } }
                }
                Text { text: "Rychlost: " + speechRate.toFixed(1) + "×"; color: textColor; font.pixelSize: 17 }
                Row {
                    spacing: 10
                    Rectangle { width: 96; height: 48; radius: 12; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Pomaleji"; color: textColor; font.pixelSize: 14 } MouseArea { anchors.fill: parent; onClicked: speechRate = Math.max(0.6, speechRate - 0.1) } }
                    Rectangle { width: 96; height: 48; radius: 12; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Rychleji"; color: textColor; font.pixelSize: 14 } MouseArea { anchors.fill: parent; onClicked: speechRate = Math.min(1.6, speechRate + 0.1) } }
                }
                Rectangle { width: parent.width; height: 52; radius: 12; color: accent; Text { anchors.centerIn: parent; text: "Otestovat hlas"; color: "white"; font.pixelSize: 16; font.bold: true } MouseArea { anchors.fill: parent; onClicked: speakText("Toto je test hlasu.") } }
            }

            Column {
                visible: currentTab === 2
                width: parent.width - 32
                spacing: 12

                Text {
                    width: parent.width
                    text: "Rychlé hlášky se ukazují jako tlačítka nahoře. Klepnutí je rovnou přečte. Tady je můžeš upravit."
                    color: muted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: 12
                    color: accent
                    Text { anchors.centerIn: parent; text: "+ Přidat rychlou hlášku"; color: "white"; font.pixelSize: 15; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: openEditor("quick", -1, "") }
                }

                Repeater {
                    model: quickModel
                    delegate: Item {
                        width: parent.width
                        height: 62

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "#dc2626"
                            opacity: Math.min(1, Math.abs(quickCard.x) / 130)
                            Text { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: "Smazat"; color: "white"; font.pixelSize: 16; font.bold: true }
                        }

                        Rectangle {
                            id: quickCard
                            width: parent.width
                            height: parent.height
                            radius: 14
                            color: card
                            border.color: border
                            x: 0
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.left: parent.left
                            anchors.right: editQuick.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            text: model.text
                            color: textColor
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            id: editQuick
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            height: 34
                            radius: 10
                            color: cardSoft
                            border.color: border
                            Text { anchors.centerIn: parent; text: "Upravit"; color: textColor; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: openEditor("quick", index, model.text) }
                        }
                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: editQuick.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            drag.target: quickCard
                            drag.axis: Drag.XAxis
                            drag.minimumX: -150
                            drag.maximumX: 0
                            onClicked: speakText(model.text)
                            onReleased: {
                                if (quickCard.x < -105) {
                                    removeQuickAt(index)
                                } else {
                                    quickCard.x = 0
                                }
                            }
                        }
                        }
                    }
                }
            }

            Column {
                visible: currentTab === 3
                width: parent.width - 32
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: 12
                    color: card
                    border.color: border
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; text: "Tmavý režim"; color: textColor; font.pixelSize: 16 }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        height: 28
                        radius: 14
                        color: darkMode ? accent : "#cbd5e1"
                        Rectangle { width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter; x: darkMode ? parent.width - width - 3 : 3; color: "white" }
                    }
                    MouseArea { anchors.fill: parent; onClicked: darkMode = !darkMode }
                }

                Text { width: parent.width; text: "Řazení uložených hlášek"; color: textColor; font.pixelSize: 17; font.bold: true }
                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Nejnovější", value: "newest" },
                            { label: "A-Z", value: "az" },
                            { label: "Krátké", value: "short" },
                            { label: "Dlouhé", value: "long" }
                        ]
                        delegate: Rectangle {
                            width: Math.max(84, sortLabel.implicitWidth + 24)
                            height: 42
                            radius: 10
                            color: savedSortMode === modelData.value ? accent : cardSoft
                            border.color: savedSortMode === modelData.value ? accent2 : border
                            Text { id: sortLabel; anchors.centerIn: parent; text: modelData.label; color: savedSortMode === modelData.value ? "white" : textColor; font.pixelSize: 14; font.bold: savedSortMode === modelData.value }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    savedSortMode = modelData.value
                                    sortSavedModel()
                                    showSaveFeedback("Seřazeno")
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Toto je dotyková mobilní verze. Uložené a rychlé hlášky se ukládají přímo v aplikaci."
                    color: muted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Rectangle {
        id: saveToast
        visible: saveToastOpacity > 0
        z: 80
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: footer.top
        anchors.bottomMargin: 14
        width: Math.min(parent.width - 48, saveToastLabel.implicitWidth + 44)
        height: 44
        radius: 12
        color: darkMode ? "#f8fafc" : "#101827"
        opacity: saveToastOpacity
        scale: saveToastOpacity > 0 ? 1.0 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180 } }
        Text {
            id: saveToastLabel
            anchors.centerIn: parent
            text: saveToastText
            color: darkMode ? "#101827" : "#f8fafc"
            font.pixelSize: 14
            font.bold: true
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 60 + safeBottom
        color: panel
        border.color: border

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
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
                    width: (footer.width - 52) / 4
                    height: 46
                    radius: 12
                    color: currentTab === modelData.tab ? accent : cardSoft
                    border.color: currentTab === modelData.tab ? accent2 : border
                    Text { anchors.centerIn: parent; text: modelData.label; color: currentTab === modelData.tab ? "white" : textColor; font.pixelSize: 13; font.bold: currentTab === modelData.tab }
                    MouseArea { anchors.fill: parent; onClicked: currentTab = modelData.tab }
                }
            }
        }
    }

    Rectangle {
        visible: editMode
        anchors.fill: parent
        color: "#cc020617"
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 14
            anchors.bottomMargin: 14 + (Qt.inputMethod.visible ? keyboardInset : safeBottom)
            height: Qt.inputMethod.visible ? Math.min(258, Math.max(220, root.height - keyboardInset - safeTop - 34)) : 292
            radius: 16
            color: panel
            border.color: border
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Text { anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: 18; anchors.topMargin: 16; text: editorTitle; color: textColor; font.pixelSize: 21; font.bold: true }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 58
                anchors.margins: 18
                height: Qt.inputMethod.visible ? 96 : 112
                radius: 12
                color: field
                border.color: editorInput.activeFocus ? accent2 : border
                border.width: 1

                TextEdit {
                    id: editorInput
                    anchors.fill: parent
                    anchors.margins: 14
                    color: textColor
                    font.pixelSize: 18
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

                Rectangle { width: (parent.width - 16) / 3; height: 46; radius: 10; color: editorSaveMouse.pressed || saveFlash ? accentPressed : accent; Behavior on color { ColorAnimation { duration: 140 } } Text { anchors.centerIn: parent; text: "Uložit"; color: "white"; font.pixelSize: 14; font.bold: true } MouseArea { id: editorSaveMouse; anchors.fill: parent; onClicked: commitEditor() } }
                Rectangle { width: (parent.width - 16) / 3; height: 46; radius: 10; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Smazat"; color: textColor; font.pixelSize: 14 } MouseArea { anchors.fill: parent; onClicked: deleteEditorItem() } }
                Rectangle { width: (parent.width - 16) / 3; height: 46; radius: 10; color: cardSoft; border.color: border; Text { anchors.centerIn: parent; text: "Zrušit"; color: textColor; font.pixelSize: 14 } MouseArea { anchors.fill: parent; onClicked: editMode = false } }
            }
        }
    }
}
