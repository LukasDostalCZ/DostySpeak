#include "MobileBridge.h"

#include <QDebug>
#include <QProcess>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>

#if defined(Q_OS_ANDROID)
#include <QCoreApplication>
#include <QJniObject>
#endif

#if defined(Q_OS_IOS)
#include "IosTts.h"
#endif

MobileBridge::MobileBridge(QObject *parent) : QObject(parent) {}

#if defined(Q_OS_ANDROID)
void MobileBridge::ensureAndroidTts()
{
    if (androidTtsReady_) return;

    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        qWarning() << "Android activity/context is not available";
        return;
    }

    QJniObject::callStaticMethod<void>(
        "cz/dosty/speak/DostyTts",
        "init",
        "(Landroid/content/Context;)V",
        activity.object<jobject>()
    );

    androidTtsReady_ = true;
}
#endif

void MobileBridge::speak(const QString &text)
{
    if (text.trimmed().isEmpty()) return;

#if defined(Q_OS_ANDROID)
    ensureAndroidTts();

    QJniObject jText = QJniObject::fromString(text);
    QJniObject::callStaticMethod<void>(
        "cz/dosty/speak/DostyTts",
        "speak",
        "(Ljava/lang/String;)V",
        jText.object<jstring>()
    );
#elif defined(Q_OS_IOS)
    IosTts::speak(text, languageTag_, static_cast<float>(0.35 + (rate_ * 0.18)), static_cast<float>(pitch_));
#elif defined(Q_OS_MACOS)
    if (speechProcess_) {
        speechProcess_->kill();
        speechProcess_->deleteLater();
        speechProcess_ = nullptr;
    }

    speechProcess_ = new QProcess(this);

    QString voice;
    if (languageTag_.startsWith(QStringLiteral("cs"), Qt::CaseInsensitive)) {
        voice = QStringLiteral("Zuzana");
    } else if (languageTag_.startsWith(QStringLiteral("de"), Qt::CaseInsensitive)) {
        voice = QStringLiteral("Anna");
    } else {
        voice = QStringLiteral("Samantha");
    }

    int wordsPerMinute = qBound(90, static_cast<int>(175 * rate_), 320);

    QStringList args;
    args << QStringLiteral("-v") << voice
         << QStringLiteral("-r") << QString::number(wordsPerMinute)
         << text;

    connect(speechProcess_, &QProcess::finished, speechProcess_, &QObject::deleteLater);
    connect(speechProcess_, &QProcess::finished, this, [this] {
        speechProcess_ = nullptr;
    });

    speechProcess_->start(QStringLiteral("/usr/bin/say"), args);
#else
    qInfo() << "Mobile preview speak:" << text;
#endif
}

void MobileBridge::speakWithSettings(const QString &text, const QString &languageTag, double rate)
{
    setLanguage(languageTag);
    setRate(rate);
    speak(text);
}

void MobileBridge::stop()
{
#if defined(Q_OS_ANDROID)
    ensureAndroidTts();
    QJniObject::callStaticMethod<void>("cz/dosty/speak/DostyTts", "stop", "()V");
#elif defined(Q_OS_IOS)
    IosTts::stop();
#elif defined(Q_OS_MACOS)
    if (speechProcess_) {
        speechProcess_->kill();
        speechProcess_->deleteLater();
        speechProcess_ = nullptr;
    }
#else
    qInfo() << "Stop speech";
#endif
}

QString MobileBridge::dataFilePath(const QString &fileName) const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.dosty-speak-mobile");

    QDir dir(base);
    if (!dir.exists())
        dir.mkpath(QStringLiteral("."));

    return dir.filePath(fileName);
}

QStringList MobileBridge::readPhraseFile(const QString &fileName) const
{
    QFile file(dataFilePath(fileName));
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return {};

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray())
        return {};

    QStringList result;
    const QJsonArray array = doc.array();
    for (const QJsonValue &value : array) {
        const QString text = value.toString().trimmed();
        if (!text.isEmpty())
            result << text;
    }
    return result;
}

void MobileBridge::writePhraseFile(const QString &fileName, const QStringList &items) const
{
    QJsonArray array;
    for (const QString &item : items) {
        const QString text = item.trimmed();
        if (!text.isEmpty())
            array.append(text);
    }

    QFile file(dataFilePath(fileName));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Could not write mobile phrase file:" << file.fileName();
        return;
    }

    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
}

QStringList MobileBridge::variantListToStringList(const QVariantList &items)
{
    QStringList result;
    for (const QVariant &item : items) {
        const QString text = item.toString().trimmed();
        if (!text.isEmpty() && !result.contains(text))
            result << text;
    }
    return result;
}

QStringList MobileBridge::loadSavedPhrases() const
{
    return readPhraseFile(QStringLiteral("saved-phrases.json"));
}

QStringList MobileBridge::loadQuickPhrases() const
{
    return readPhraseFile(QStringLiteral("quick-phrases.json"));
}

void MobileBridge::saveSavedPhraseList(const QVariantList &items)
{
    writePhraseFile(QStringLiteral("saved-phrases.json"), variantListToStringList(items));
}

void MobileBridge::saveQuickPhraseList(const QVariantList &items)
{
    writePhraseFile(QStringLiteral("quick-phrases.json"), variantListToStringList(items));
}

void MobileBridge::savePhrase(const QString &text)
{
    QString clean = text.trimmed();
    if (clean.isEmpty())
        return;

    QStringList phrases = loadSavedPhrases();
    phrases.removeAll(clean);
    phrases.prepend(clean);
    writePhraseFile(QStringLiteral("saved-phrases.json"), phrases);
}

void MobileBridge::setLanguage(const QString &languageTag)
{
    languageTag_ = languageTag.isEmpty() ? QStringLiteral("cs-CZ") : languageTag;

#if defined(Q_OS_ANDROID)
    ensureAndroidTts();
    QJniObject jLanguage = QJniObject::fromString(languageTag_);
    QJniObject::callStaticMethod<void>(
        "cz/dosty/speak/DostyTts",
        "setLanguage",
        "(Ljava/lang/String;)V",
        jLanguage.object<jstring>()
    );
#endif
}

void MobileBridge::setRate(double value)
{
    rate_ = value;

#if defined(Q_OS_ANDROID)
    ensureAndroidTts();
    QJniObject::callStaticMethod<void>(
        "cz/dosty/speak/DostyTts",
        "setRate",
        "(F)V",
        static_cast<jfloat>(rate_)
    );
#endif
}

void MobileBridge::setPitch(double value)
{
    pitch_ = value;

#if defined(Q_OS_ANDROID)
    ensureAndroidTts();
    QJniObject::callStaticMethod<void>(
        "cz/dosty/speak/DostyTts",
        "setPitch",
        "(F)V",
        static_cast<jfloat>(pitch_)
    );
#endif
}
