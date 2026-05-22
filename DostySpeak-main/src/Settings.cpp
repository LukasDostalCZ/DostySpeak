#include "Settings.h"
#include "AppPaths.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QApplication>
#include <QPalette>
#include <QLocale>
#include <QSaveFile>
#include <QFile>
#include <QProcess>


static bool systemPrefersDarkTheme()
{
#ifdef Q_OS_MAC
    QProcess process;
    process.start("defaults", {"read", "-g", "AppleInterfaceStyle"});
    if (process.waitForFinished(600)) {
        const QString out = QString::fromUtf8(process.readAllStandardOutput()).trimmed().toLower();
        if (out.contains("dark")) return true;
    }
#endif

    if (!qApp) return false;

    const QColor window = qApp->palette().color(QPalette::Window);
    return window.lightness() < 128;
}

static QString defaultAudioPlayer()
{
#ifdef Q_OS_WIN
    return "powershell";
#elif defined(Q_OS_MAC)
    return "afplay";
#else
    return "aplay";
#endif
}

AppSettings SettingsStore::load()
{
    AppSettings s;
    s.darkMode = systemPrefersDarkTheme();

    const QLocale locale = QLocale::system();
    if (locale.language() == QLocale::Czech) {
        s.language = "cs";
    } else {
        s.language = "en";
    }

    s.piperBinary = AppPaths::defaultPiperBinary();
    s.piperModel = AppPaths::defaultPiperModel();
    s.audioPlayer = defaultAudioPlayer();

    QFile file(AppPaths::settingsPath());
    if (!file.open(QIODevice::ReadOnly)) {
        save(s);
        return s;
    }

    const QJsonObject o = QJsonDocument::fromJson(file.readAll()).object();

    s.language = o.value("language").toString(s.language);
    s.engine = o.value("engine").toString(s.engine);

    s.nativeVoice = o.value("nativeVoice").toString(s.nativeVoice);
    s.nativeSpeed = o.value("nativeSpeed").toInt(s.nativeSpeed);
    s.nativePitch = o.value("nativePitch").toInt(s.nativePitch);
    s.nativeAmplitude = o.value("nativeAmplitude").toInt(s.nativeAmplitude);
    s.outputVolume = o.value("outputVolume").toInt(s.outputVolume);

    s.piperBinary = o.value("piperBinary").toString(s.piperBinary);
    s.piperModel = o.value("piperModel").toString(s.piperModel);
    s.audioPlayer = o.value("audioPlayer").toString(s.audioPlayer);
    s.onlineLanguage = o.value("onlineLanguage").toString(s.onlineLanguage);
    s.edgeTtsCommand = o.value("edgeTtsCommand").toString(s.edgeTtsCommand);
    s.activeVoicePreset = o.value("activeVoicePreset").toString(s.activeVoicePreset);
    for (const auto &v : o.value("voicePresetNames").toArray()) s.voicePresetNames << v.toString();
    for (const auto &v : o.value("voicePresetValues").toArray()) s.voicePresetValues << v.toString();

    s.piperLengthScale = o.value("piperLengthScale").toDouble(s.piperLengthScale);
    s.piperNoiseScale = o.value("piperNoiseScale").toDouble(s.piperNoiseScale);
    s.piperNoiseW = o.value("piperNoiseW").toDouble(s.piperNoiseW);
    s.piperQuality = o.value("piperQuality").toString(s.piperQuality);

    s.sortMode = o.value("sortMode").toString(s.sortMode);
    if (o.contains("folders") && o.value("folders").isArray()) {
        s.folders.clear();
        const QJsonArray folderArray = o.value("folders").toArray();
        for (const auto &value : folderArray) {
            const QString folder = value.toString().trimmed();
            if (!folder.isEmpty() && !s.folders.contains(folder)) s.folders << folder;
        }
        if (s.folders.isEmpty()) s.folders << "General";
    }
    s.darkMode = o.value("darkMode").toBool(s.darkMode);
    s.clearAfterSpeak = o.value("clearAfterSpeak").toBool(s.clearAfterSpeak);
    s.firstRunDone = o.value("firstRunDone").toBool(s.firstRunDone);

    return s;
}

void SettingsStore::save(const AppSettings &s)
{
    QJsonObject o;
    o["language"] = s.language;
    o["engine"] = s.engine;

    o["nativeVoice"] = s.nativeVoice;
    o["nativeSpeed"] = s.nativeSpeed;
    o["nativePitch"] = s.nativePitch;
    o["nativeAmplitude"] = s.nativeAmplitude;
    o["outputVolume"] = s.outputVolume;

    o["piperBinary"] = s.piperBinary;
    o["piperModel"] = s.piperModel;
    o["audioPlayer"] = s.audioPlayer;
    o["onlineLanguage"] = s.onlineLanguage;
    o["edgeTtsCommand"] = s.edgeTtsCommand;
    o["activeVoicePreset"] = s.activeVoicePreset;
    QJsonArray voicePresetNames;
    for (const QString &name : s.voicePresetNames) voicePresetNames.append(name);
    o["voicePresetNames"] = voicePresetNames;
    QJsonArray voicePresetValues;
    for (const QString &value : s.voicePresetValues) voicePresetValues.append(value);
    o["voicePresetValues"] = voicePresetValues;

    o["piperLengthScale"] = s.piperLengthScale;
    o["piperNoiseScale"] = s.piperNoiseScale;
    o["piperNoiseW"] = s.piperNoiseW;
    o["piperQuality"] = s.piperQuality;

    o["sortMode"] = s.sortMode;
    QJsonArray folderArray;
    for (const QString &folder : s.folders) folderArray.append(folder);
    o["folders"] = folderArray;
    o["darkMode"] = s.darkMode;
    o["clearAfterSpeak"] = s.clearAfterSpeak;
    o["firstRunDone"] = s.firstRunDone;

    QSaveFile file(AppPaths::settingsPath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
        file.commit();
    }
}
