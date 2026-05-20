#include "VoiceCatalog.h"
#include "AppPaths.h"
#include "I18n.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>

QVector<DownloadableVoice> VoiceCatalog::downloadable()
{
    QVector<DownloadableVoice> voices;

    auto addFallbackVoices = [&]() {
        voices.clear();

        voices.push_back({
            "cs_CZ-jirka-medium",
            "cs-CZ",
            I18n::instance().language() == "cs" ? "Čeština — Jirka — medium" : "Czech — Jirka — medium",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/cs/cs_CZ/jirka/medium/cs_CZ-jirka-medium.onnx",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/cs/cs_CZ/jirka/medium/cs_CZ-jirka-medium.onnx.json"
        });

        voices.push_back({
            "en_US-amy-medium",
            "en-US",
            I18n::instance().language() == "cs" ? "Angličtina US — Amy — medium" : "English US — Amy — medium",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json"
        });

        voices.push_back({
            "en_US-ryan-medium",
            "en-US",
            I18n::instance().language() == "cs" ? "Angličtina US — Ryan — medium" : "English US — Ryan — medium",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/medium/en_US-ryan-medium.onnx",
            "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/medium/en_US-ryan-medium.onnx.json"
        });
    };

    QFile file(AppPaths::voiceCatalogPath());
    if (!file.open(QIODevice::ReadOnly)) {
        addFallbackVoices();

    std::sort(voices.begin(), voices.end(), [](const DownloadableVoice &a, const DownloadableVoice &b) {
        const QString ka = a.language.toLower() + "|" + a.name.toLower();
        const QString kb = b.language.toLower() + "|" + b.name.toLower();
        return ka < kb;
    });

        return voices;
    }

    const QJsonArray array = QJsonDocument::fromJson(file.readAll()).array();
    const QString lang = I18n::instance().language();

    for (const auto &value : array) {
        const QJsonObject o = value.toObject();
        DownloadableVoice v;
        v.id = o.value("id").toString();
        v.language = o.value("language").toString();
        const QJsonObject names = o.value("name").toObject();
        v.name = names.value(lang).toString(names.value("en").toString(v.id));
        v.onnxUrl = o.value("onnxUrl").toString();
        v.configUrl = o.value("configUrl").toString();

        if (!v.id.isEmpty() && !v.onnxUrl.isEmpty()) voices.push_back(v);
    }

    if (voices.isEmpty()) addFallbackVoices();

    std::sort(voices.begin(), voices.end(), [](const DownloadableVoice &a, const DownloadableVoice &b) {
        const QString ka = a.language.toLower() + "|" + a.name.toLower();
        const QString kb = b.language.toLower() + "|" + b.name.toLower();
        return ka < kb;
    });

    return voices;
}

QVector<NativeVoice> VoiceCatalog::native()
{
    QVector<NativeVoice> voices;

#ifdef Q_OS_WIN
    voices.push_back({"default", "system", "Windows default voice"});
#elif defined(Q_OS_MAC)
    voices.push_back({"default", "system", "macOS default voice"});
    voices.push_back({"Zuzana", "cs-CZ", "Zuzana"});
    voices.push_back({"Tereza", "cs-CZ", "Tereza"});
    voices.push_back({"Daniel", "en-GB", "Daniel"});
    voices.push_back({"Samantha", "en-US", "Samantha"});
#else
    voices.push_back({"cs", "cs-CZ", "eSpeak Czech default"});
    voices.push_back({"cs+m1", "cs-CZ", "eSpeak Czech male 1"});
    voices.push_back({"cs+m2", "cs-CZ", "eSpeak Czech male 2"});
    voices.push_back({"cs+f1", "cs-CZ", "eSpeak Czech female 1"});
    voices.push_back({"cs+f2", "cs-CZ", "eSpeak Czech female 2"});
    voices.push_back({"en", "en", "eSpeak English"});
    voices.push_back({"sk", "sk-SK", "eSpeak Slovak"});
#endif

    return voices;
}

QString VoiceCatalog::modelPath(const DownloadableVoice &voice)
{
    return AppPaths::voicesDir() + "/" + voice.id + ".onnx";
}

QString VoiceCatalog::configPath(const DownloadableVoice &voice)
{
    return AppPaths::voicesDir() + "/" + voice.id + ".onnx.json";
}

bool VoiceCatalog::isDownloaded(const DownloadableVoice &voice)
{
    return QFileInfo::exists(modelPath(voice)) && QFileInfo::exists(configPath(voice));
}
