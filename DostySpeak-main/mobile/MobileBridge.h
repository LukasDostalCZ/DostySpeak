#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QVariantList>

class MobileBridge : public QObject {
    Q_OBJECT

public:
    explicit MobileBridge(QObject *parent = nullptr);

    Q_INVOKABLE void speak(const QString &text);
    Q_INVOKABLE void speakWithSettings(const QString &text, const QString &languageTag, double rate);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void savePhrase(const QString &text);
    Q_INVOKABLE QStringList loadSavedPhrases() const;
    Q_INVOKABLE QStringList loadQuickPhrases() const;
    Q_INVOKABLE void saveSavedPhraseList(const QVariantList &items);
    Q_INVOKABLE void saveQuickPhraseList(const QVariantList &items);

    Q_INVOKABLE void setLanguage(const QString &languageTag);
    Q_INVOKABLE void setRate(double value);
    Q_INVOKABLE void setPitch(double value);

private:
    QProcess *speechProcess_ = nullptr;
    QString languageTag_ = QStringLiteral("cs-CZ");
    double rate_ = 1.0;
    double pitch_ = 1.0;

    QString dataFilePath(const QString &fileName) const;
    QStringList readPhraseFile(const QString &fileName) const;
    void writePhraseFile(const QString &fileName, const QStringList &items) const;
    static QStringList variantListToStringList(const QVariantList &items);

#if defined(Q_OS_ANDROID)
    void ensureAndroidTts();
    bool androidTtsReady_ = false;
#endif
};
