#include "AppInfo.h"
#include "AppPaths.h"

#include <QCoreApplication>
#include <QLibraryInfo>
#include <QSysInfo>
#include <QFile>
#include <QtGlobal>

#ifndef APP_NAME
#define APP_NAME "Dosty Speak"
#endif

#ifndef APP_ID
#define APP_ID "dosty-speak"
#endif

#ifndef APP_VERSION
#define APP_VERSION "dev"
#endif

#ifndef APP_AUTHOR
#define APP_AUTHOR "Lukáš Dostál"
#endif

#ifndef APP_LICENSE
#define APP_LICENSE "MIT"
#endif

static const char *APP_COPYRIGHT_TEXT = "Copyright (c) 2026 Lukáš Dostál";

QString AppInfo::name() { return QString::fromUtf8(APP_NAME); }
QString AppInfo::id() { return QString::fromUtf8(APP_ID); }
QString AppInfo::version() { return QString::fromUtf8(APP_VERSION); }
QString AppInfo::author() { return QString::fromUtf8(APP_AUTHOR); }
QString AppInfo::license() { return QString::fromUtf8(APP_LICENSE); }
QString AppInfo::copyright() { return QString::fromUtf8(APP_COPYRIGHT_TEXT); }

QString AppInfo::buildType()
{
#ifdef NDEBUG
    return "Release";
#else
    return "Debug";
#endif
}

QString AppInfo::compilerInfo()
{
#if defined(__clang__)
    return QString("Clang %1.%2.%3").arg(__clang_major__).arg(__clang_minor__).arg(__clang_patchlevel__);
#elif defined(__GNUC__)
    return QString("GCC %1.%2.%3").arg(__GNUC__).arg(__GNUC_MINOR__).arg(__GNUC_PATCHLEVEL__);
#elif defined(_MSC_VER)
    return QString("MSVC %1").arg(_MSC_VER);
#else
    return "Unknown compiler";
#endif
}

QString AppInfo::qtBuildVersion()
{
    return QString::fromUtf8(QT_VERSION_STR);
}

QString AppInfo::qtRuntimeVersion()
{
    return QString::fromUtf8(qVersion());
}

QString AppInfo::buildDateTime()
{
    return QString("%1 %2").arg(QString::fromUtf8(__DATE__), QString::fromUtf8(__TIME__));
}

QString AppInfo::systemInfo()
{
    return QString("%1 / %2 / %3")
        .arg(QSysInfo::prettyProductName(),
             QSysInfo::currentCpuArchitecture(),
             QSysInfo::kernelType() + " " + QSysInfo::kernelVersion());
}

QString AppInfo::diagnosticsText()
{
    QString text;
    text += "Dosty Speak diagnostics\n";
    text += "=======================\n\n";

    text += "Application\n";
    text += "-----------\n";
    text += "Name: " + name() + "\n";
    text += "ID: " + id() + "\n";
    text += "Version: " + version() + "\n";
    text += "Author: " + author() + "\n";
    text += "License: " + license() + "\n";
    text += copyright() + "\n\n";

    text += "Build\n";
    text += "-----\n";
    text += "Build type: " + buildType() + "\n";
    text += "Build date: " + buildDateTime() + "\n";
    text += "Compiler: " + compilerInfo() + "\n";
    text += "Qt build version: " + qtBuildVersion() + "\n";
    text += "Qt runtime version: " + qtRuntimeVersion() + "\n\n";

    text += "System\n";
    text += "------\n";
    text += "System: " + systemInfo() + "\n";
    text += "Product: " + QSysInfo::productType() + " " + QSysInfo::productVersion() + "\n";
    text += "CPU architecture: " + QSysInfo::currentCpuArchitecture() + "\n";
    text += "Word size: " + QString::number(QSysInfo::WordSize) + "-bit\n\n";

    text += "Paths\n";
    text += "-----\n";
    text += "Executable: " + QCoreApplication::applicationFilePath() + "\n";
    text += "App data: " + AppPaths::dataDir() + "\n";
    text += "Voices: " + AppPaths::voicesDir() + "\n";
    text += "Settings: " + AppPaths::settingsPath() + "\n";
    text += "Phrases: " + AppPaths::phrasesPath() + "\n";
    text += "Voice catalog: " + AppPaths::voiceCatalogPath() + "\n\n";

    text += "Resource search dirs\n";
    text += "--------------------\n";
    for (const QString &dir : AppPaths::resourceDirs()) {
        text += dir + "\n";
    }

    return text;
}
