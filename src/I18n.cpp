#include "I18n.h"
#include "AppPaths.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

I18n& I18n::instance()
{
    static I18n inst;
    return inst;
}

void I18n::load(const QString &languageCode)
{
    languageCode_ = languageCode.isEmpty() ? "en" : languageCode;
    strings_.clear();

    // Minimal English fallback so the GUI never shows raw keys when resources
    // are missing or when the app is launched from an unusual directory.
    strings_.insert("hint.piperSpeed", "");
    strings_.insert("hint.main", "Type a sentence and press Enter. Shift+Enter saves it as a phrase.");
    strings_.insert("autocomplete.hint", "Tab completes a word. Press Tab again to cycle more suggestions. Arrows browse saved phrases.");
    strings_.insert("autocomplete.preview", "Tab completes:");
    strings_.insert("autocomplete.alternatives", "More suggestions:");
    strings_.insert("firstRun.piperVoiceRequired", "Piper is selected, but no voice is checked for download.");
    strings_.insert("placeholder.input", "Type what you want to say…");
    strings_.insert("placeholder.search", "Search…");
    strings_.insert("button.speak", "Speak");
    strings_.insert("button.save", "Save");
    strings_.insert("button.stop", "Stop");
    strings_.insert("button.new", "+ New");
    strings_.insert("button.newFolder", "+ Folder");
    strings_.insert("button.speakSelected", "Speak selected");
    strings_.insert("button.edit", "Edit");
    strings_.insert("button.downloadVoice", "Download selected voice");
    strings_.insert("button.cancel", "Cancel");
    strings_.insert("button.installPiper", "Install / repair Piper runtime");
    strings_.insert("menu.installPiper", "Install / repair Piper runtime…");
    strings_.insert("status.installingPiper", "Installing Piper runtime…");
    strings_.insert("status.creatingVenv", "Creating Python virtual environment…");
    strings_.insert("status.upgradingPip", "Upgrading pip…");
    strings_.insert("status.installingPiperPackage", "Installing Piper package…");
    strings_.insert("status.piperInstalled", "Piper runtime installed. You can now download and select a Piper voice.");
    strings_.insert("status.piperInstallFailed", "Piper installation failed.");
    strings_.insert("status.installingEmbeddedPython", "Installing bundled official Python for Dosty Speak…");
    strings_.insert("status.downloadingEmbeddedPython", "Downloading embedded Python…");
    strings_.insert("status.extractingEmbeddedPython", "Extracting embedded Python…");
    strings_.insert("status.downloadingPipBootstrap", "Downloading pip bootstrap…");
    strings_.insert("status.installingPipBootstrap", "Installing pip into embedded Python…");
    strings_.insert("status.installingEmbeddedPython", "Installing bundled official Python for Dosty Speak…");
    strings_.insert("status.downloadingEmbeddedPython", "Downloading official Python runtime…");
    strings_.insert("status.extractingEmbeddedPython", "Extracting official Python runtime…");
    strings_.insert("status.downloadingPipBootstrap", "Downloading pip bootstrap…");
    strings_.insert("status.installingPipBootstrap", "Installing pip into bundled Python…");
    strings_.insert("status.processStartFailed", "Could not start required process.");
    strings_.insert("status.piperExeMissing", "Piper installation finished, but piper.exe was not found.");
    strings_.insert("status.pythonMissing", "Python 3 was not found. Install Python 3 from python.org and enable Add python.exe to PATH, or install/use MSYS2 UCRT64 Python. Then try installing Piper again.");
    strings_.insert("label.folders", "Folders");
    strings_.insert("label.phrases", "Phrases");
    strings_.insert("label.folder", "Folder:");
    strings_.insert("folder.all", "All folders");
    strings_.insert("folder.general", "General");
    strings_.insert("menu.moveToFolder", "Move to folder…");
    strings_.insert("dialog.folder", "Folder");
    strings_.insert("dialog.folderPrompt", "Folder name:");
    strings_.insert("column.folder", "Folder");
    strings_.insert("status.movedToFolder", "Phrase moved to folder.");
    strings_.insert("label.text", "Text:");
    strings_.insert("label.language", "Language:");
    strings_.insert("column.phrase", "Phrase");
    strings_.insert("column.uses", "Uses");
    strings_.insert("column.created", "Created");
    strings_.insert("sort.usage", "Most used");
    strings_.insert("sort.created", "Created");
    strings_.insert("sort.updated", "Recently edited");
    strings_.insert("sort.alpha", "Alphabetical");
    strings_.insert("menu.file", "File");
    strings_.insert("menu.import", "Import phrases…");
    strings_.insert("menu.export", "Export phrases…");
    strings_.insert("menu.quit", "Quit");
    strings_.insert("menu.actions", "Actions");
    strings_.insert("menu.speakText", "Speak text");
    strings_.insert("menu.saveText", "Save text as phrase");
    strings_.insert("menu.stop", "Stop");
    strings_.insert("menu.newPhrase", "New phrase…");
    strings_.insert("menu.newFolder", "New folder…");
    strings_.insert("menu.editPhrase", "Edit phrase…");
    strings_.insert("menu.duplicatePhrase", "Duplicate phrase");
    strings_.insert("menu.deletePhrase", "Delete phrase");

    strings_.insert("menu.renameFolder", "Rename folder…");
    strings_.insert("menu.deleteFolder", "Delete folder");
    strings_.insert("status.typingLockedMode", "Typing mode: Tab completes a word, arrows browse saved phrases, Esc unlocks phrase selection.");
    strings_.insert("status.keyboardUnlocked", "Phrase selection unlocked. Esc or Tab returns to typing.");
    strings_.insert("status.autocompleteApplied", "Word completed from saved phrases.");
    strings_.insert("status.noAutocomplete", "No suitable completion found.");
    strings_.insert("status.typingMode", "Typing mode — Enter speaks the text.");
    strings_.insert("status.phraseMode", "Phrase mode — arrows select a phrase, Enter speaks it, Tab returns to typing.");
    strings_.insert("status.folderRenamed", "Folder renamed.");
    strings_.insert("status.folderDeleted", "Folder deleted. Phrases were moved to General.");
    strings_.insert("status.loadedPhrase", "Phrase loaded into the input field.");
    strings_.insert("dialog.renameFolder", "Rename folder");
    strings_.insert("dialog.deleteFolderQuestion", "Delete this folder? Phrases inside will be moved to General.");
    strings_.insert("dialog.protectedFolder", "This folder cannot be deleted.");
    strings_.insert("menu.voice", "Voice");
    strings_.insert("menu.selectVoice", "Select / download voice…");
    strings_.insert("menu.voiceSettings", "Voice settings…");
    strings_.insert("menu.view", "View");
    strings_.insert("menu.language", "Language");
    strings_.insert("menu.toggleDark", "Toggle dark mode");
    strings_.insert("menu.search", "Search");
    strings_.insert("menu.help", "Help");
    strings_.insert("menu.shortcuts", "Shortcuts");
    strings_.insert("menu.about", "About Dosty Speak");
    strings_.insert("menu.diagnostics", "Diagnostics…");
    strings_.insert("dialog.about", "About Dosty Speak");
    strings_.insert("dialog.firstRun", "Welcome to Dosty Speak");
    strings_.insert("firstRun.intro", "Let’s set up the app for first use.");
    strings_.insert("firstRun.language", "Choose interface language:");
    strings_.insert("firstRun.voice", "Choose initial voice:");
    strings_.insert("firstRun.appearance", "Choose appearance:");
    strings_.insert("appearance.system", "Use current/default appearance");
    strings_.insert("appearance.light", "Light mode");
    strings_.insert("appearance.dark", "Dark mode");
    strings_.insert("menu.resetSetup", "Reset settings and open setup wizard…");
    strings_.insert("dialog.resetSetup", "Reset settings");
    strings_.insert("dialog.resetSetupQuestion", "This will delete Dosty Speak settings and phrases, then open the first-run setup wizard again. Continue?");
    strings_.insert("status.settingsReset", "Settings were reset.");
    strings_.insert("status.dataCleared", "App data cleared.");
    strings_.insert("firstRun.nativeHint", "System/native voice is the safest first choice. Piper can be installed now if you select a Piper voice.");
    strings_.insert("firstRun.finish", "Finish");
    strings_.insert("firstRun.skip", "Skip");
    strings_.insert("firstRun.piperInstallAsk", "You selected a Piper voice. Dosty Speak can install/repair Piper runtime now and then download the selected voice. This can take a while. Continue?");
    strings_.insert("firstRun.piperInstallTitle", "Install Piper now?");
    strings_.insert("status.firstRunDone", "First-run setup finished.");
    strings_.insert("status.languageApplied", "Language changed without restart.");
    strings_.insert("dialog.longTextNote", "");
    strings_.insert("status.downloadingVoiceModel", "Downloading selected voice model…");
    strings_.insert("voice.nativeDefault", "System / native voice");
    strings_.insert("voice.googleCzech", "Online Google voice — Czech");
    strings_.insert("voice.googleEnglish", "Online Google voice — English");
    strings_.insert("voice.espeakCzech", "eSpeak NG — Czech");
    strings_.insert("voice.edgeCzech", "Microsoft Edge online — Czech");
    strings_.insert("voice.edgeEnglish", "Microsoft Edge online — English");
    strings_.insert("voice.piperCzech", "Piper Czech — Jirka");
    strings_.insert("voice.piperEnglish", "Piper English — Amy");
    strings_.insert("dialog.diagnostics", "Diagnostics");
    strings_.insert("button.copy", "Copy");
    strings_.insert("button.close", "Close");
    strings_.insert("about.text", "Dosty Speak\n\nVersion: %1\nAuthor: %2\nLicense: %3\n\nA cross-platform phrase based text-to-speech app.\n\nThis program is open-source software released under the MIT License.");
    strings_.insert("dialog.newPhrase", "New phrase");
    strings_.insert("dialog.newFolder", "New folder");
    strings_.insert("dialog.editPhrase", "Edit phrase");
    strings_.insert("dialog.deleteTitle", "Delete phrase");
    strings_.insert("dialog.deleteQuestion", "Really delete selected phrase?");
    strings_.insert("dialog.voice", "Voice");
    strings_.insert("dialog.settings", "Settings");
    strings_.insert("label.paths", "Paths");
    strings_.insert("engine.native", "System / native voice");
    strings_.insert("engine.piper", "Piper neural voice");
    strings_.insert("setting.dark", "Dark mode:");
    strings_.insert("setting.clearAfter", "Clear input after speaking:");
    strings_.insert("setting.speed", "Native speed:");
    strings_.insert("setting.pitch", "Native pitch:");
    strings_.insert("setting.volume", "Native volume:");
    strings_.insert("setting.piperBinary", "Piper binary:");
    strings_.insert("status.ready", "Ready.");
    strings_.insert("status.emptyText", "Nothing to speak.");
    strings_.insert("status.duplicate", "This phrase already exists.");
    strings_.insert("status.saved", "Phrase saved.");
    strings_.insert("status.folderCreated", "Folder created.");
    strings_.insert("status.dropPhraseHint", "Drag a phrase onto a folder to move it.");
    strings_.insert("status.speaking", "Speaking…");
    strings_.insert("status.nativeTtsFailed", "Could not start the native TTS engine.");
    strings_.insert("status.piperMissing", "Piper is not installed or the binary path is wrong.");
    strings_.insert("status.modelMissing", "Piper model is missing.");
    strings_.insert("status.piperStartFailed", "Could not start Piper.");
    strings_.insert("status.piperTimeout", "Piper timed out.");
    strings_.insert("status.piperError", "Piper failed.");
    strings_.insert("status.playerFailed", "Could not play generated audio.");
    strings_.insert("status.deleteOnlyList", "Phrase deletion works only when the phrase list is focused.");
    strings_.insert("status.voiceSaved", "Voice saved.");
    strings_.insert("status.piperAlreadyInstalled", "Piper runtime already exists, reusing it.");
    strings_.insert("status.voiceAlreadyDownloaded", "Voice model already exists, selecting it.");
    strings_.insert("status.voiceDownloadFailed", "Voice download failed. Check internet connection and try again.");
    strings_.insert("status.voiceConfigured", "Piper voice configured.");
    strings_.insert("status.voiceNotFound", "Selected voice was not found in the voice catalog.");
    strings_.insert("status.downloading", "Downloading voice…");
    strings_.insert("status.downloadDone", "Voice downloaded.");
    strings_.insert("status.settingsSaved", "Settings saved.");
    strings_.insert("status.restartForLanguage", "Please restart the app to fully apply the language change.");
    strings_.insert("status.importDone", "Import finished.");
    strings_.insert("status.exportDone", "Export finished.");
    strings_.insert("help.shortcuts", "Enter — speak input\nShift+Enter — save input as phrase\nEsc — stop\nCtrl+N — new phrase\nF2 — edit selected phrase\nDelete — delete only when phrase list is focused\nCtrl+D — dark mode\nCtrl+F — search\nAlt+1..9 — speak first visible phrases");

    QString path = AppPaths::i18nFile(languageCode_);
    if (path.isEmpty() && languageCode_ != "en") {
        path = AppPaths::i18nFile("en");
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return;

    const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = object.begin(); it != object.end(); ++it) {
        strings_.insert(it.key(), it.value().toString());
    }
}

QString I18n::language() const
{
    return languageCode_;
}

QString I18n::t(const QString &key) const
{
    return strings_.value(key, key);
}
