#pragma once

#include "PhraseStore.h"
#include "Settings.h"
#include "Speaker.h"

#include <QComboBox>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMainWindow>
#include <QNetworkAccessManager>
#include <QSlider>
#include <QProgressDialog>
#include <QTreeWidget>

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

private:
    AppSettings settings_;
    QVector<Phrase> phrases_;
    Speaker speaker_;
    QNetworkAccessManager network_;

    QLineEdit *input_ = nullptr;
    QLineEdit *search_ = nullptr;
    QListWidget *folderList_ = nullptr;
    QTreeWidget *phraseTree_ = nullptr;
    QComboBox *sortCombo_ = nullptr;
    QLabel *status_ = nullptr;
    QSlider *mainVolumeSlider_ = nullptr;
    QSlider *mainSpeedSlider_ = nullptr;

    void buildUi();
    void buildMenus();
    void applyTheme();

    void refreshFolders();
    void refreshPhrases();
    QString currentFolderFilter() const;
    QVector<int> sortedIndices() const;
    int selectedPhraseIndex() const;

    void speakText(const QString &text, int phraseIndex = -1);
    void addPhrase(const QString &text);
    void editPhrase(int index);
    void deleteSelectedPhrase();
    void duplicateSelectedPhrase();
    void createFolder();
    void moveSelectedPhraseToFolder();
    void moveSelectedPhraseToFolderName(const QString &folder);
    void renameSelectedFolder();
    void deleteSelectedFolder();
    void showFolderContextMenu(const QPoint &pos);
    void showPhraseContextMenu(const QPoint &pos);
    void loadSelectedPhraseIntoInput();
    void updateModeStatus(const QString &mode);
    void selectVisiblePhraseNumber(int number, bool speakImmediately);
    void focusPhraseList();

    void showVoiceDialog();
    void showSettingsDialog();
    void showLanguageDialog();
    void showFirstRunWizard();
    void resetSettingsAndRestartWizard();
    void clearAppDataFiles();
    void rebuildUiAfterLanguageChange();
    bool installPiperRuntimeSilent(QWidget *parentWidget);
    QString findPythonForPiper(QStringList *baseArgs = nullptr) const;
    void downloadVoiceById(const QString &voiceId, QWidget *parentWidget);
    bool configurePiperVoiceById(const QString &voiceId, QWidget *parentWidget, bool installRuntimeIfNeeded);
    void downloadVoice(const QString &voiceId);
    void installPiperRuntime();
    void downloadUrlToFile(const QUrl &url, const QString &target, QProgressDialog *progress, std::function<void(bool)> done);

    void importPhrases();
    void exportPhrases();
    void showShortcuts();
    void showAboutDialog();
    void showDiagnosticsDialog();

    QString trKey(const QString &key) const;

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;
    bool focusNextPrevChild(bool next) override;
};
