#include "MobileBridge.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QList>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    MobileBridge bridge;
    engine.rootContext()->setContextProperty(QStringLiteral("bridge"), &bridge);
#if defined(QT_DESKTOP_PREVIEW)
    engine.addImportPath(QStringLiteral("/opt/homebrew/opt/qt/qml"));
    engine.addImportPath(QStringLiteral("/usr/local/opt/qt/qml"));
#endif
QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
    );

    const QList<QUrl> candidates = {
        QUrl(QStringLiteral("qrc:/mobile/qml/main.qml")),
        QUrl::fromLocalFile(QCoreApplication::applicationDirPath() + QStringLiteral("/../Resources/mobile/qml/main.qml")),
        QUrl::fromLocalFile(QCoreApplication::applicationDirPath() + QStringLiteral("/mobile/qml/main.qml")),
        QUrl::fromLocalFile(QDir::currentPath() + QStringLiteral("/mobile/qml/main.qml"))
    };

    for (const QUrl &candidate : candidates) {
        engine.load(candidate);
        if (!engine.rootObjects().isEmpty()) {
            break;
        }
    }

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Could not load mobile/qml/main.qml from qrc, app resources or working directory.";
        return -1;
    }

    return app.exec();
}
