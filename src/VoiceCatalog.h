#pragma once

#include <QString>
#include <QVector>

struct DownloadableVoice {
    QString id;
    QString language;
    QString name;
    QString onnxUrl;
    QString configUrl;
};

struct NativeVoice {
    QString id;
    QString language;
    QString name;
};

class VoiceCatalog {
public:
    static QVector<DownloadableVoice> downloadable();
    static QVector<NativeVoice> native();
    static bool isDownloaded(const DownloadableVoice &voice);
    static QString modelPath(const DownloadableVoice &voice);
    static QString configPath(const DownloadableVoice &voice);
};
