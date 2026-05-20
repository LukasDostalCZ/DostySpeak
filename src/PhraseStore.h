#pragma once

#include <QDateTime>
#include <QString>
#include <QVector>

struct Phrase {
    QString id;
    QString text;
    QString folder = "General";
    QDateTime createdAt;
    QDateTime updatedAt;
    int useCount = 0;
};

class PhraseStore {
public:
    static QVector<Phrase> load();
    static void save(const QVector<Phrase> &phrases);

private:
    static QVector<Phrase> defaultPhrases();
};
