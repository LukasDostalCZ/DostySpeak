#pragma once

#include <QString>
#include <QStringList>

struct AppSettings {
    QString language = "en";

    QString engine = "native";          // native | piper | google_online | espeak_ng | edge_online
    QString nativeVoice = "cs";
    int nativeSpeed = 130;
    int nativePitch = 35;
    int nativeAmplitude = 150;
    int outputVolume = 100;          // 0..100, playback volume

    QString piperBinary;
    QString piperModel;
    QString audioPlayer;
    QString onlineLanguage = "cs";       // cs | en | sk | de ...
    QString edgeTtsCommand;              // edge-tts command path, empty = auto

    QString activeVoicePreset;
    QStringList voicePresetNames;
    QStringList voicePresetValues;       // compact JSON strings matching voicePresetNames

    double piperLengthScale = 0.85;
    double piperNoiseScale = 0.35;
    double piperNoiseW = 0.5;
    QString piperQuality = "balanced"; // fast | balanced | high

    QString sortMode = "usage";         // usage | created | updated | alpha
    QStringList folders = {"General"};
    bool darkMode = false;
    bool clearAfterSpeak = false;
    bool firstRunDone = false;
};

class SettingsStore {
public:
    static AppSettings load();
    static void save(const AppSettings &settings);
};
