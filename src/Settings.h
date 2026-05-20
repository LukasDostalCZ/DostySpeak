#pragma once

#include <QString>
#include <QStringList>

struct AppSettings {
    QString language = "en";

    QString engine = "native";          // native | piper
    QString nativeVoice = "cs";
    int nativeSpeed = 130;
    int nativePitch = 35;
    int nativeAmplitude = 150;
    int outputVolume = 100;          // 0..100, playback volume

    QString piperBinary;
    QString piperModel;
    QString audioPlayer;

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
