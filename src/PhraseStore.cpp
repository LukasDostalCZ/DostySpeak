#include "PhraseStore.h"
#include "AppPaths.h"
#include "Settings.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QUuid>

QVector<Phrase> PhraseStore::defaultPhrases()
{
    QVector<Phrase> phrases;
    const AppSettings settings = SettingsStore::load();

    struct TemplatePhrase {
        QString folder;
        QString text;
    };

    QVector<TemplatePhrase> templates;

    if (settings.language == "cs") {
        templates = {
            {"Základní", "Dobrý den, omlouvám se, momentálně nemůžu mluvit. Budu používat hlasový syntetizátor."},
            {"Základní", "Můžete to prosím zopakovat pomaleji?"},
            {"Základní", "Děkuju, rozumím."},
            {"Základní", "Prosím chvilku, napíšu odpověď."},
            {"Základní", "Omlouvám se, teď nemůžu odpovědět hlasem."},
            {"Práce", "Na schůzce budu odpovídat přes hlasový syntetizátor."},
            {"Práce", "Souhlasím, můžeme pokračovat."},
            {"Práce", "Potřebuji se k tomu vrátit za chvíli."},
            {"Doktor", "Potřeboval bych se prosím objednat na ORL, už delší dobu mám výrazný chrapot až ztrátu hlasu."},
            {"Doktor", "Bolí mě hrtan a hlas se zhoršuje hlavně během dne."},
            {"Doktor", "Můžete mi prosím říct, co mám dělat dál?"}
        };
    } else {
        templates = {
            {"General", "Hello, I am currently unable to speak. I will use this text-to-speech app."},
            {"General", "Could you please repeat that more slowly?"},
            {"General", "Thank you, I understand."},
            {"General", "Please give me a moment to type the answer."},
            {"General", "Sorry, I cannot answer by voice right now."},
            {"Work", "I will use a text-to-speech app during this meeting."},
            {"Work", "I agree, we can continue."},
            {"Work", "I need to come back to this in a moment."},
            {"Doctor", "I need to schedule an ENT appointment because I have had severe hoarseness and voice loss for a while."},
            {"Doctor", "My larynx hurts and my voice gets worse during the day."},
            {"Doctor", "Could you please tell me what I should do next?"}
        };
    }

    const QDateTime now = QDateTime::currentDateTimeUtc();
    for (int i = 0; i < templates.size(); ++i) {
        Phrase p;
        p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        p.folder = templates[i].folder;
        p.text = templates[i].text;
        p.createdAt = now.addSecs(i);
        p.updatedAt = p.createdAt;
        phrases.push_back(p);
    }
    return phrases;
}

QVector<Phrase> PhraseStore::load()
{
    QFile file(AppPaths::phrasesPath());
    if (!file.open(QIODevice::ReadOnly)) {
        auto phrases = defaultPhrases();
        save(phrases);
        return phrases;
    }

    QVector<Phrase> phrases;
    const QJsonArray array = QJsonDocument::fromJson(file.readAll()).array();

    for (const auto &value : array) {
        if (value.isString()) {
            Phrase p;
            p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            p.text = value.toString().trimmed();
            p.folder = "General";
            p.createdAt = QDateTime::currentDateTimeUtc();
            p.updatedAt = p.createdAt;
            if (!p.text.isEmpty()) phrases.push_back(p);
            continue;
        }

        const QJsonObject o = value.toObject();
        Phrase p;
        p.id = o.value("id").toString(QUuid::createUuid().toString(QUuid::WithoutBraces));
        p.text = o.value("text").toString().trimmed();
        p.folder = o.value("folder").toString("General").trimmed();
        if (p.folder.isEmpty()) p.folder = "General";
        p.createdAt = QDateTime::fromString(o.value("createdAt").toString(), Qt::ISODate);
        p.updatedAt = QDateTime::fromString(o.value("updatedAt").toString(), Qt::ISODate);
        p.useCount = o.value("useCount").toInt(0);

        if (!p.createdAt.isValid()) p.createdAt = QDateTime::currentDateTimeUtc();
        if (!p.updatedAt.isValid()) p.updatedAt = p.createdAt;
        if (!p.text.isEmpty()) phrases.push_back(p);
    }

    if (phrases.isEmpty()) phrases = defaultPhrases();
    save(phrases);
    return phrases;
}

void PhraseStore::save(const QVector<Phrase> &phrases)
{
    QJsonArray array;
    for (const auto &p : phrases) {
        QJsonObject o;
        o["id"] = p.id;
        o["text"] = p.text;
        o["folder"] = p.folder;
        o["createdAt"] = p.createdAt.toUTC().toString(Qt::ISODate);
        o["updatedAt"] = p.updatedAt.toUTC().toString(Qt::ISODate);
        o["useCount"] = p.useCount;
        array.push_back(o);
    }

    QSaveFile file(AppPaths::phrasesPath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
        file.commit();
    }
}
