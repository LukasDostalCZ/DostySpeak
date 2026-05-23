#pragma once

#include "Settings.h"

#include <QObject>
#include <QProcess>
#include <QString>

class Speaker : public QObject {
    Q_OBJECT

public:
    explicit Speaker(QObject *parent = nullptr);

    void setSettings(const AppSettings &settings);
    QString speak(const QString &text);
    void stop();

private:
    AppSettings settings_;
    QList<QProcess*> processes_;

    QString speakNative(const QString &text);
    QString speakPiper(const QString &text);
    QString speakGoogleOnline(const QString &text);
    QString speakEspeakNg(const QString &text);
    QString speakEdgeOnline(const QString &text);
    QString playMp3(const QString &path);
    QString playWav(const QString &path);
    QString cachePath(const QString &engine, const QString &key, const QString &extension) const;
};
