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
    QString autocompletePrefix_;
    QStringList autocompleteCandidates_;
    int autocompleteCandidateIndex_ = -1;

    QLineEdit *input_ = nullptr;
    QLineEdit *search_ = nullptr;
    QListWidget *folderList_ = nullptr;
    QTreeWidget *phraseTree_ = nullptr;
    QComboBox *sortCombo_ = nullptr;
    QLabel *status_ = nullptr;
    QLabel *autocompleteInline_ = nullptr;
    QLabel *autocompletePreview_ = nullptr;
    QListWidget *autocompletePopup_ = nullptr;
    QComboBox *presetCombo_ = nullptr;
    bool suppressAutocompleteReset_ = false;
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
    void selectAdjacentVisiblePhrase(int delta);
    bool autocompleteCurrentWord();
    QStringList autocompleteWords(const QString &prefix) const;
    QString currentWordPrefix() const;
    void updateAutocompletePreview();
    void refreshAutocompletePopup(const QStringList &candidates, int activeIndex = 0);
    void hideAutocompletePopup();
    QString currentVoicePresetJson() const;
    void applyVoicePresetJson(const QString &json);
    void saveCurrentVoicePreset();
    void refreshPresetCombo();
    void focusPhraseList();

    void showVoiceDialog();
    void showSettingsDialog();
    void showLanguageDialog();
    void showFirstRunWizard();
    void showSynthInstallDialog(QWidget *parentWidget);
    void showDefaultVoiceWizard(QWidget *parentWidget);
    void resetSettingsAndRestartWizard();
    void clearAppDataFiles();
    void rebuildUiAfterLanguageChange();
    bool installPiperRuntimeSilent(QWidget *parentWidget);
    bool installLinuxPythonVenvPackage(QProgressDialog *progress, QWidget *owner) const;
    QString findPythonForPiper(QStringList *baseArgs = nullptr) const;
    void downloadVoiceById(const QString &voiceId, QWidget *parentWidget);
    bool configurePiperVoiceById(const QString &voiceId, QWidget *parentWidget, bool installRuntimeIfNeeded);
    void downloadVoice(const QString &voiceId);
    void installPiperRuntime();
    bool installVisualCppRuntime(QWidget *parentWidget, bool silent = false);
    bool installEdgeTtsRuntime(QWidget *parentWidget, bool silent = false);
    bool installEspeakNgRuntime(QWidget *parentWidget, bool silent = false);
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
