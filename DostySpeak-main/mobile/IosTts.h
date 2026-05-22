#pragma once

#include <QString>

namespace IosTts {
    void speak(const QString &text, const QString &language = QStringLiteral("cs-CZ"), float rate = 0.48f, float pitch = 1.0f);
    void stop();
}
