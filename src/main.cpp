#include <QApplication>
#include <QCoreApplication>
#include "MainWindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QCoreApplication::setOrganizationName("Dosty");
    QCoreApplication::setApplicationName("DostySpeak");
    QCoreApplication::setApplicationVersion(APP_VERSION);

    MainWindow window;
    window.show();

    return app.exec();
}
