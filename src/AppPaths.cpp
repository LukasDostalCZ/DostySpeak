#include "AppPaths.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

QString AppPaths::dataDir()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty()) {
        dir = QDir::homePath() + "/.local/share/dosty-speak";
    }
    QDir().mkpath(dir);
    return dir;
}

QString AppPaths::voicesDir()
{
    QString dir = dataDir() + "/voices";
    QDir().mkpath(dir);
    return dir;
}

QString AppPaths::settingsPath()
{
    return dataDir() + "/settings.json";
}

QString AppPaths::phrasesPath()
{
    return dataDir() + "/phrases.json";
}

QStringList AppPaths::resourceDirs()
{
    QStringList dirs;

#ifdef RESOURCE_DIR
    dirs << QString::fromUtf8(RESOURCE_DIR);
#endif

    const QString appDir = QCoreApplication::applicationDirPath();

    // Running from the build directory after CMake post-build copy.
    dirs << appDir + "/resources";

    // Running from a local build tree, where executable is usually ./build/dosty-speak.
    dirs << appDir + "/../resources";
    dirs << appDir + "/../../resources";

    // Installed Linux layout.
    dirs << appDir + "/../share/dosty-speak";
    dirs << "/usr/local/share/dosty-speak";
    dirs << "/usr/share/dosty-speak";

#ifdef Q_OS_MAC
    // App bundle layout.
    dirs << appDir + "/../Resources";
    dirs << appDir + "/../Resources/resources";
#endif

#ifdef Q_OS_WIN
    // Windows deployment folder.
    dirs << appDir + "/resources";
#endif

    // Last resort for running from project root.
    dirs << QDir::currentPath() + "/resources";

    QStringList unique;
    for (const QString &dir : dirs) {
        const QString clean = QDir::cleanPath(dir);
        if (!unique.contains(clean)) unique << clean;
    }
    return unique;
}

QString AppPaths::i18nFile(const QString &languageCode)
{
    for (const QString &base : resourceDirs()) {
        const QString path = base + "/i18n/" + languageCode + ".json";
        if (QFileInfo::exists(path)) return path;
    }
    return {};
}

QString AppPaths::voiceCatalogPath()
{
    for (const QString &base : resourceDirs()) {
        const QString path = base + "/voices/catalog.json";
        if (QFileInfo::exists(path)) return path;
    }
    return {};
}

QString AppPaths::resourcePath(const QString &relativePath)
{
    for (const QString &base : resourceDirs()) {
        const QString path = base + "/" + relativePath;
        if (QFileInfo::exists(path)) return path;
    }
    return {};
}

QString AppPaths::defaultPiperBinary()
{
#ifdef Q_OS_WIN
    return dataDir() + "/piper-venv/Scripts/piper.exe";
#elif defined(Q_OS_MAC)
    return dataDir() + "/piper-venv/bin/piper";
#else
    return dataDir() + "/piper-venv/bin/piper";
#endif
}

QString AppPaths::defaultPiperModel()
{
    return voicesDir() + "/cs_CZ-jirka-medium.onnx";
}
