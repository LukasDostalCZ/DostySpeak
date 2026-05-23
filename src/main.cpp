#include <QApplication>
#include <QCoreApplication>
#include <QStyleFactory>
#include "MainWindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

#ifdef Q_OS_WIN
    const QString windowsStyle = QStyleFactory::keys().contains("windowsvista", Qt::CaseInsensitive)
        ? "windowsvista"
        : "windows";
    QApplication::setStyle(QStyleFactory::create(windowsStyle));
#endif

    QCoreApplication::setOrganizationName("Dosty");
    QCoreApplication::setApplicationName("DostySpeak");
    QCoreApplication::setApplicationVersion(APP_VERSION);

    MainWindow window;
    window.show();

    return app.exec();
}
