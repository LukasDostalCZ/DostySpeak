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
    QString playWav(const QString &path);
};
