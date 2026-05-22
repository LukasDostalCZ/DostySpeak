#pragma once

#include <QString>

class AppInfo {
public:
    static QString name();
    static QString id();
    static QString version();
    static QString author();
    static QString license();
    static QString copyright();

    static QString buildType();
    static QString compilerInfo();
    static QString qtBuildVersion();
    static QString qtRuntimeVersion();
    static QString buildDateTime();
    static QString systemInfo();
    static QString diagnosticsText();
};
