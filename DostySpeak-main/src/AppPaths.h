#pragma once

#include <QString>
#include <QStringList>

class AppPaths {
public:
    static QString dataDir();
    static QString voicesDir();
    static QString settingsPath();
    static QString phrasesPath();

    static QStringList resourceDirs();
    static QString i18nFile(const QString &languageCode);
    static QString voiceCatalogPath();
    static QString resourcePath(const QString &relativePath);

    static QString defaultPiperBinary();
    static QString defaultPiperModel();
};
