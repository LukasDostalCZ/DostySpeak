#pragma once

#include <QHash>
#include <QString>

class I18n {
public:
    static I18n& instance();

    void load(const QString &languageCode);
    QString language() const;
    QString t(const QString &key) const;

private:
    QString languageCode_ = "en";
    QHash<QString, QString> strings_;
};
