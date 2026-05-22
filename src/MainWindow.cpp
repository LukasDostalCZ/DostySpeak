#include "MainWindow.h"

#include "AppPaths.h"
#include "AppInfo.h"
#include "I18n.h"
#include "VoiceCatalog.h"

#include <algorithm>

#include <QApplication>
#include <QAbstractItemView>
#include <QCheckBox>
#include <QToolTip>
#include <QCoreApplication>
#include <QTextEdit>
#include <QTabWidget>
#include <QClipboard>
#include <QDateTime>
#include <QDialog>
#include <QDialogButtonBox>
#include <QDir>
#include <QDirIterator>
#include <QTimer>
#include <QDropEvent>
#include <QDragEnterEvent>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QHeaderView>
#include <QInputDialog>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QKeyEvent>
#include <QListWidget>
#include <QMap>
#include <QMessageBox>
#include <QFrame>
#include <QMenuBar>
#include <QMenu>
#include <QNetworkReply>
#include <QPlainTextEdit>
#include <QProcess>
#include <QPixmap>
#include <QPushButton>
#include <QRegularExpression>
#include <QButtonGroup>
#include <QRadioButton>
#include <QScrollArea>
#include <QSpinBox>
#include <QSlider>
#include <QSplitter>
#include <QStandardPaths>
#include <QTextBoundaryFinder>
#include <QTextStream>
#include <QVBoxLayout>
#include <QUuid>

#ifdef Q_OS_WIN
#include <windows.h>
#include <shellapi.h>
#endif

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent),
      settings_(SettingsStore::load()),
      phrases_(PhraseStore::load())
{
    I18n::instance().load(settings_.language);
    speaker_.setSettings(settings_);

    buildUi();
    buildMenus();
    applyTheme();
    refreshFolders();
    refreshPhrases();

    setWindowTitle("Dosty Speak");
    resize(1100, 720);

    if (!settings_.firstRunDone) {
        QTimer::singleShot(250, this, &MainWindow::showFirstRunWizard);
    }
}

QString MainWindow::trKey(const QString &key) const
{
    return I18n::instance().t(key);
}

void MainWindow::buildUi()
{
    auto *central = new QWidget(this);
    auto *root = new QVBoxLayout(central);
    root->setContentsMargins(18, 16, 18, 12);
    root->setSpacing(12);

    auto *title = new QLabel("Dosty Speak", central);
    title->setObjectName("title");
    root->addWidget(title);

    auto *hint = new QLabel(trKey("hint.main"), central);
    hint->setObjectName("hint");
    root->addWidget(hint);

    auto *topRow = new QHBoxLayout();
    input_ = new QLineEdit(central);
    input_->setPlaceholderText(trKey("placeholder.input"));
    input_->setMinimumHeight(44);
    input_->installEventFilter(this);
    topRow->addWidget(input_, 1);

    auto *speakButton = new QPushButton(trKey("button.speak"), central);
    auto *saveButton = new QPushButton(trKey("button.save"), central);
    auto *stopButton = new QPushButton(trKey("button.stop"), central);
    topRow->addWidget(speakButton);
    topRow->addWidget(saveButton);
    topRow->addWidget(stopButton);
    root->addLayout(topRow);

    auto *autocompletePopupRow = new QHBoxLayout();
    autocompletePopupRow->setContentsMargins(0, 0, 0, 0);
    autocompletePopup_ = new QListWidget(central);
    autocompletePopup_->setObjectName("autocompletePopup");
    autocompletePopup_->setFocusPolicy(Qt::NoFocus);
    autocompletePopup_->setSelectionMode(QAbstractItemView::SingleSelection);
    autocompletePopup_->setUniformItemSizes(true);
    autocompletePopup_->setMaximumHeight(150);
    autocompletePopup_->setMinimumWidth(320);
    autocompletePopup_->setMaximumWidth(520);
    autocompletePopup_->hide();
    autocompletePopupRow->addWidget(autocompletePopup_);
    autocompletePopupRow->addStretch(1);
    root->addLayout(autocompletePopupRow);

    autocompletePreview_ = new QLabel(trKey("autocomplete.hint"), central);
    autocompletePreview_->setObjectName("autocompletePreview");
    autocompletePreview_->setWordWrap(true);
    autocompletePreview_->setTextFormat(Qt::RichText);
    root->addWidget(autocompletePreview_);

    auto *quickControls = new QHBoxLayout();
    quickControls->setSpacing(10);

    auto *presetLabel = new QLabel(trKey("voicePreset.label"), central);
    quickControls->addWidget(presetLabel);

    presetCombo_ = new QComboBox(central);
    presetCombo_->setMinimumWidth(190);
    presetCombo_->addItem(trKey("voicePreset.current"), "__current");
    quickControls->addWidget(presetCombo_);

    auto *volumeLabel = new QLabel(trKey("setting.outputVolume"), central);
    quickControls->addWidget(volumeLabel);

    mainVolumeSlider_ = new QSlider(Qt::Horizontal, central);
    mainVolumeSlider_->setRange(0, 100);
    mainVolumeSlider_->setValue(settings_.outputVolume);
    mainVolumeSlider_->setMaximumWidth(190);
    quickControls->addWidget(mainVolumeSlider_);

    auto *speedLabel = new QLabel(trKey("setting.speed"), central);
    quickControls->addWidget(speedLabel);

    mainSpeedSlider_ = new QSlider(Qt::Horizontal, central);
    mainSpeedSlider_->setRange(80, 230);
    mainSpeedSlider_->setValue(settings_.nativeSpeed);
    mainSpeedSlider_->setMaximumWidth(190);
    quickControls->addWidget(mainSpeedSlider_);
    quickControls->addStretch(1);

    root->addLayout(quickControls);

    connect(mainVolumeSlider_, &QSlider::valueChanged, this, [this](int value) {
        settings_.outputVolume = value;
        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
    });
    connect(mainSpeedSlider_, &QSlider::valueChanged, this, [this](int value) {
        settings_.nativeSpeed = value;
        // For Piper, speed affects generated speech length, but not model inference time.
        if (settings_.engine == "piper") {
            settings_.piperLengthScale = qBound(0.55, 150.0 / qMax(1, value), 1.40);
        }
        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
    });

    refreshPresetCombo();
    connect(presetCombo_, QOverload<int>::of(&QComboBox::currentIndexChanged), this, [this] {
        if (!presetCombo_) return;
        const QString data = presetCombo_->currentData().toString();
        if (data == "__current" || data.isEmpty()) return;
        applyVoicePresetJson(data);
    });

    connect(speakButton, &QPushButton::clicked, this, [this] { speakText(input_->text()); });
    connect(saveButton, &QPushButton::clicked, this, [this] { addPhrase(input_->text()); });
    connect(stopButton, &QPushButton::clicked, &speaker_, &Speaker::stop);

    connect(input_, &QLineEdit::textEdited, this, [this] {
        if (!suppressAutocompleteReset_) {
            autocompleteCandidates_.clear();
            autocompleteCandidateIndex_ = -1;
            autocompletePrefix_.clear();
        }
        updateAutocompletePreview();
    });
    connect(input_, &QLineEdit::cursorPositionChanged, this, [this] {
        if (!suppressAutocompleteReset_) {
            autocompleteCandidates_.clear();
            autocompleteCandidateIndex_ = -1;
            autocompletePrefix_.clear();
        }
        updateAutocompletePreview();
    });

    updateAutocompletePreview();

    auto *bar = new QHBoxLayout();
    auto *label = new QLabel(trKey("label.phrases"), central);
    label->setObjectName("sectionTitle");
    bar->addWidget(label);

    search_ = new QLineEdit(central);
    search_->setPlaceholderText(trKey("placeholder.search"));
    search_->installEventFilter(this);
    bar->addWidget(search_, 1);

    sortCombo_ = new QComboBox(central);
    sortCombo_->addItem(trKey("sort.usage"), "usage");
    sortCombo_->addItem(trKey("sort.created"), "created");
    sortCombo_->addItem(trKey("sort.updated"), "updated");
    sortCombo_->addItem(trKey("sort.alpha"), "alpha");

    const int idx = sortCombo_->findData(settings_.sortMode);
    if (idx >= 0) sortCombo_->setCurrentIndex(idx);
    bar->addWidget(sortCombo_);

    root->addLayout(bar);

    auto *splitter = new QSplitter(Qt::Horizontal, central);
    splitter->setChildrenCollapsible(false);

    auto *folderPanel = new QWidget(splitter);
    auto *folderLayout = new QVBoxLayout(folderPanel);
    folderLayout->setContentsMargins(0, 0, 0, 0);
    folderLayout->setSpacing(8);

    auto *folderTitle = new QLabel(trKey("label.folders"), folderPanel);
    folderTitle->setObjectName("sectionTitle");
    folderLayout->addWidget(folderTitle);

    folderList_ = new QListWidget(folderPanel);
    folderList_->setObjectName("folderList");
    folderList_->setMinimumWidth(190);
    folderList_->setMaximumWidth(310);
    folderList_->installEventFilter(this);
    folderList_->setAcceptDrops(true);
    folderList_->viewport()->setAcceptDrops(true);
    folderList_->viewport()->installEventFilter(this);
    folderList_->setDropIndicatorShown(true);
    folderList_->setDragDropMode(QAbstractItemView::DropOnly);
    folderList_->setDefaultDropAction(Qt::MoveAction);
    folderList_->setContextMenuPolicy(Qt::CustomContextMenu);
    folderLayout->addWidget(folderList_, 1);

    auto *newFolderButton = new QPushButton(trKey("button.newFolder"), folderPanel);
    folderLayout->addWidget(newFolderButton);

    auto *phrasePanel = new QWidget(splitter);
    auto *phraseLayout = new QVBoxLayout(phrasePanel);
    phraseLayout->setContentsMargins(0, 0, 0, 0);
    phraseLayout->setSpacing(8);

    auto *phraseTitle = new QLabel(trKey("label.phrases"), phrasePanel);
    phraseTitle->setObjectName("sectionTitle");
    phraseLayout->addWidget(phraseTitle);

    phraseTree_ = new QTreeWidget(phrasePanel);
    phraseTree_->setColumnCount(1);
    phraseTree_->setHeaderHidden(true);
    phraseTree_->header()->setSectionResizeMode(0, QHeaderView::Stretch);
    phraseTree_->setRootIsDecorated(false);
    phraseTree_->setUniformRowHeights(true);
    phraseTree_->installEventFilter(this);
    phraseTree_->setDragEnabled(true);
    phraseTree_->setDragDropMode(QAbstractItemView::DragOnly);
    phraseTree_->setDefaultDropAction(Qt::MoveAction);
    phraseTree_->setSelectionMode(QAbstractItemView::SingleSelection);
    phraseTree_->setContextMenuPolicy(Qt::CustomContextMenu);
    phraseLayout->addWidget(phraseTree_, 1);

    splitter->addWidget(folderPanel);
    splitter->addWidget(phrasePanel);
    splitter->setStretchFactor(0, 0);
    splitter->setStretchFactor(1, 1);
    root->addWidget(splitter, 1);

    auto *bottom = new QHBoxLayout();
    status_ = new QLabel(trKey("status.ready"), central);
    status_->setObjectName("status");
    bottom->addWidget(status_, 1);

    root->addLayout(bottom);

    setCentralWidget(central);

    connect(newFolderButton, &QPushButton::clicked, this, &MainWindow::createFolder);
    connect(search_, &QLineEdit::textChanged, this, &MainWindow::refreshPhrases);
    connect(folderList_, &QListWidget::currentRowChanged, this, &MainWindow::refreshPhrases);
    connect(folderList_, &QListWidget::customContextMenuRequested, this, &MainWindow::showFolderContextMenu);
    connect(phraseTree_, &QTreeWidget::customContextMenuRequested, this, &MainWindow::showPhraseContextMenu);
    connect(phraseTree_, &QTreeWidget::currentItemChanged, this, [this](QTreeWidgetItem*, QTreeWidgetItem*) {
        loadSelectedPhraseIntoInput();
    });

    connect(sortCombo_, QOverload<int>::of(&QComboBox::currentIndexChanged), this, [this] {
        settings_.sortMode = sortCombo_->currentData().toString();
        SettingsStore::save(settings_);
        refreshPhrases();
    });
    connect(phraseTree_, &QTreeWidget::itemDoubleClicked, this, [this] {
        const int index = selectedPhraseIndex();
        if (index >= 0) speakText(phrases_[index].text, index);
    });
    input_->setFocus();
    updateModeStatus("typing");
}

void MainWindow::buildMenus()
{
    auto *file = menuBar()->addMenu(trKey("menu.file"));
    file->addAction(trKey("menu.import"), this, &MainWindow::importPhrases);
    file->addAction(trKey("menu.export"), this, &MainWindow::exportPhrases);
    file->addSeparator();
    file->addAction(trKey("menu.quit"), this, &QWidget::close);

    auto *actions = menuBar()->addMenu(trKey("menu.actions"));
    actions->addAction(trKey("menu.speakText"), this, [this] { speakText(input_->text()); });
    actions->addAction(trKey("menu.saveText"), this, [this] { addPhrase(input_->text()); });
    actions->addAction(trKey("menu.stop"), &speaker_, &Speaker::stop);
    actions->addSeparator();
    actions->addAction(trKey("menu.newFolder"), this, &MainWindow::createFolder);
    actions->addAction(trKey("menu.newPhrase"), this, [this] {
        bool ok = false;
        QString text = QInputDialog::getMultiLineText(this, trKey("dialog.newPhrase"), trKey("label.text"), "", &ok);
        if (ok) addPhrase(text);
    }, QKeySequence("Ctrl+N"));
    actions->addAction(trKey("menu.editPhrase"), this, [this] {
        const int index = selectedPhraseIndex();
        if (index >= 0) editPhrase(index);
    }, QKeySequence(Qt::Key_F2));
    actions->addAction(trKey("menu.duplicatePhrase"), this, &MainWindow::duplicateSelectedPhrase);
    actions->addAction(trKey("menu.moveToFolder"), this, &MainWindow::moveSelectedPhraseToFolder);
    actions->addAction(trKey("menu.deletePhrase"), this, &MainWindow::deleteSelectedPhrase);

    auto *voice = menuBar()->addMenu(trKey("menu.voice"));
    voice->addAction(trKey("menu.selectVoice"), this, &MainWindow::showVoiceDialog);
    voice->addAction(trKey("menu.installEngines"), this, [this] { showSynthInstallDialog(this); });

    auto *view = menuBar()->addMenu(trKey("menu.view"));
    view->addAction(trKey("menu.language"), this, &MainWindow::showLanguageDialog);
    view->addAction(trKey("menu.resetSetup"), this, &MainWindow::resetSettingsAndRestartWizard);
    view->addAction(trKey("menu.toggleDark"), this, [this] {
        settings_.darkMode = !settings_.darkMode;
        SettingsStore::save(settings_);
        applyTheme();
    }, QKeySequence("Ctrl+D"));
    view->addAction(trKey("menu.search"), this, [this] { search_->setFocus(); search_->selectAll(); }, QKeySequence("Ctrl+F"));

    auto *help = menuBar()->addMenu(trKey("menu.help"));
    help->addAction(trKey("menu.shortcuts"), this, &MainWindow::showShortcuts);
    help->addAction(trKey("menu.diagnostics"), this, &MainWindow::showDiagnosticsDialog);
    help->addSeparator();
    help->addAction(trKey("menu.about"), this, &MainWindow::showAboutDialog);
}

void MainWindow::applyTheme()
{
    QString style;
    if (settings_.darkMode) {
        style = R"(
            QWidget { background: #171a20; color: #f3f4f6; font-size: 11pt; }
            QMenuBar, QMenu { background: #20242c; color: #f3f4f6; }
            QLineEdit, QTreeWidget, QListWidget, QPlainTextEdit, QSpinBox {
                background: #111318; color: #f3f4f6; border: 1px solid #343b47; border-radius: 8px; padding: 8px;
            }
            QComboBox { background: #111318; color: #f3f4f6; border: 1px solid #343b47; border-radius: 10px; padding: 8px 38px 8px 10px; min-height: 24px; }
            QComboBox::drop-down { subcontrol-origin: border; subcontrol-position: top right; width: 34px; border-left: 1px solid #343b47; border-top-right-radius: 10px; border-bottom-right-radius: 10px; background: #202734; }
            QComboBox::down-arrow { image: url(:/qt-project.org/styles/commonstyle/images/down-16.png); width: 12px; height: 12px; }
            QComboBox::drop-down:hover { background: #2b3444; }
            QPushButton { background: #2b3240; color: #f3f4f6; border: 1px solid #414a5a; border-radius: 8px; padding: 8px 12px; }
            QPushButton:hover { background: #354052; }
            QHeaderView::section { background: #20242c; color: #f3f4f6; padding: 8px; border: none; }
            QTreeWidget::item:selected, QListWidget::item:selected { background: #33415c; }
            QLabel#title { font-size: 22pt; font-weight: 700; }
            QLabel#hint, QLabel#status { color: #b5bdc9; }
            QLabel#sectionTitle { font-size: 14pt; font-weight: 700; }
            QLabel#autocompleteInline { color: #ffffff; background: #374151; border-radius: 8px; padding: 6px 10px; font-weight: 700; }
            QScrollArea { background: transparent; border: 1px solid #2f3643; border-radius: 8px; }
            QScrollArea > QWidget > QWidget { background: transparent; }
            QFrame#voiceChoiceCard { background: transparent; border: none; border-radius: 6px; }
            QFrame#voiceChoiceCard:hover { background: #202734; }
            QRadioButton { color: #f3f4f6; spacing: 8px; min-height: 22px; padding: 0px 2px; }
            QRadioButton::indicator { width: 14px; height: 14px; border-radius: 7px; border: 1px solid #8b95a7; background: #111318; }
            QRadioButton::indicator:hover { border: 1px solid #60a5fa; }
            QRadioButton::indicator:checked { border: 4px solid #0d6efd; background: #ffffff; }
            QListWidget#voiceChoiceList::item { min-height: 30px; padding: 6px 10px; border-radius: 8px; }
            QListWidget#voiceChoiceList::item:selected { background: #33415c; color: #ffffff; }
            QLabel#autocompletePreview { color: #cbd5e1; background: transparent; border: none; padding: 2px 4px; font-weight: 500; }
        )";
    } else {
        style = R"(
            QWidget { background: #eef1f6; color: #111827; font-size: 11pt; }
            QMenuBar, QMenu { background: #ffffff; color: #111827; }
            QLineEdit, QTreeWidget, QListWidget, QPlainTextEdit, QSpinBox {
                background: #ffffff; color: #111827; border: 1px solid #d5dbe7; border-radius: 8px; padding: 8px;
            }
            QComboBox { background: #ffffff; color: #111827; border: 1px solid #d5dbe7; border-radius: 10px; padding: 8px 38px 8px 10px; min-height: 24px; }
            QComboBox::drop-down { subcontrol-origin: border; subcontrol-position: top right; width: 34px; border-left: 1px solid #d5dbe7; border-top-right-radius: 10px; border-bottom-right-radius: 10px; background: #f3f6fb; }
            QComboBox::down-arrow { image: url(:/qt-project.org/styles/commonstyle/images/down-16.png); width: 12px; height: 12px; }
            QComboBox::drop-down:hover { background: #e7edf7; }
            QPushButton { background: #ffffff; color: #111827; border: 1px solid #d5dbe7; border-radius: 8px; padding: 8px 12px; }
            QPushButton:hover { background: #f4f7fb; }
            QHeaderView::section { background: #f8fafc; color: #111827; padding: 8px; border: none; }
            QTreeWidget::item:selected, QListWidget::item:selected { background: #dbe8ff; }
            QLabel#title { font-size: 22pt; font-weight: 700; }
            QLabel#hint, QLabel#status { color: #586174; }
            QLabel#sectionTitle { font-size: 14pt; font-weight: 700; }
            QLabel#autocompleteInline { color: #0f172a; background: #e5e7eb; border-radius: 8px; padding: 6px 10px; font-weight: 700; }
            QScrollArea { background: transparent; border: 1px solid #d5dbe7; border-radius: 8px; }
            QScrollArea > QWidget > QWidget { background: transparent; }
            QFrame#voiceChoiceCard { background: transparent; border: none; border-radius: 6px; }
            QFrame#voiceChoiceCard:hover { background: #e7edf7; }
            QRadioButton { color: #111827; spacing: 8px; min-height: 22px; padding: 0px 2px; }
            QRadioButton::indicator { width: 14px; height: 14px; border-radius: 7px; border: 1px solid #64748b; background: #ffffff; }
            QRadioButton::indicator:hover { border: 1px solid #2563eb; }
            QRadioButton::indicator:checked { border: 4px solid #2563eb; background: #ffffff; }
            QListWidget#voiceChoiceList::item { min-height: 30px; padding: 6px 10px; border-radius: 8px; }
            QListWidget#voiceChoiceList::item:selected { background: #dbe8ff; color: #111827; }
            QLabel#autocompletePreview { color: #475569; background: transparent; border: none; padding: 2px 4px; font-weight: 500; }
        )";
    }
    qApp->setStyleSheet(style);
}

QString MainWindow::currentFolderFilter() const
{
    if (!folderList_ || !folderList_->currentItem()) return {};
    return folderList_->currentItem()->data(Qt::UserRole).toString();
}

void MainWindow::refreshFolders()
{
    if (!folderList_) return;

    const QString previous = currentFolderFilter();

    QStringList folders = settings_.folders;
    if (!folders.contains("General")) folders << "General";

    for (auto &phrase : phrases_) {
        if (phrase.folder.trimmed().isEmpty()) phrase.folder = "General";
        if (!folders.contains(phrase.folder)) folders << phrase.folder;
    }
    folders.removeDuplicates();
    folders.sort(Qt::CaseInsensitive);

    folderList_->blockSignals(true);
    folderList_->clear();

    auto *all = new QListWidgetItem(trKey("folder.all"));
    all->setData(Qt::UserRole, QString());
    folderList_->addItem(all);

    for (const QString &folder : folders) {
        auto *item = new QListWidgetItem(folder);
        item->setData(Qt::UserRole, folder);
        folderList_->addItem(item);
    }

    int row = 0;
    if (!previous.isEmpty()) {
        for (int i = 0; i < folderList_->count(); ++i) {
            if (folderList_->item(i)->data(Qt::UserRole).toString() == previous) {
                row = i;
                break;
            }
        }
    }
    folderList_->setCurrentRow(row);
    folderList_->blockSignals(false);
}

QVector<int> MainWindow::sortedIndices() const
{
    QVector<int> indices;
    const QString needle = search_->text().simplified().toLower();
    const QString folder = currentFolderFilter();

    for (int i = 0; i < phrases_.size(); ++i) {
        const bool folderMatch = folder.isEmpty() || phrases_[i].folder == folder;
        const bool searchMatch = needle.isEmpty() || phrases_[i].text.toLower().contains(needle);
        if (folderMatch && searchMatch) indices.push_back(i);
    }

    std::sort(indices.begin(), indices.end(), [this](int a, int b) {
        const auto &pa = phrases_[a];
        const auto &pb = phrases_[b];

        if (settings_.sortMode == "usage") {
            if (pa.useCount != pb.useCount) return pa.useCount > pb.useCount;
            return pa.createdAt < pb.createdAt;
        }
        if (settings_.sortMode == "created") return pa.createdAt < pb.createdAt;
        if (settings_.sortMode == "updated") return pa.updatedAt > pb.updatedAt;
        if (settings_.sortMode == "alpha") return pa.text.toLower() < pb.text.toLower();
        return a < b;
    });

    return indices;
}

void MainWindow::refreshPhrases()
{
    const int selected = selectedPhraseIndex();
    phraseTree_->clear();

    int visibleNumber = 1;
    for (int index : sortedIndices()) {
        const Phrase &p = phrases_[index];
        QString text = p.text;
        if (visibleNumber <= 9) text = QString::number(visibleNumber) + ". " + text;

        auto *item = new QTreeWidgetItem({text});
        item->setData(0, Qt::UserRole, index);
        phraseTree_->addTopLevelItem(item);

        if (index == selected) phraseTree_->setCurrentItem(item);
        ++visibleNumber;
    }

    if (!phraseTree_->currentItem() && phraseTree_->topLevelItemCount() > 0) {
        phraseTree_->setCurrentItem(phraseTree_->topLevelItem(0));
    }
}

int MainWindow::selectedPhraseIndex() const
{
    auto *item = phraseTree_->currentItem();
    if (!item) return -1;
    return item->data(0, Qt::UserRole).toInt();
}

void MainWindow::focusPhraseList()
{
    phraseTree_->setFocus();
    if (!phraseTree_->currentItem() && phraseTree_->topLevelItemCount() > 0) {
        phraseTree_->setCurrentItem(phraseTree_->topLevelItem(0));
    }
    updateModeStatus("phrase");
}

void MainWindow::loadSelectedPhraseIntoInput()
{
    const int index = selectedPhraseIndex();
    if (index < 0 || index >= phrases_.size()) return;

    input_->setText(phrases_[index].text);
    status_->setText(trKey("status.loadedPhrase"));
}

void MainWindow::updateModeStatus(const QString &mode)
{
    if (mode == "phrase") {
        status_->setText(trKey("status.phraseMode"));
    } else if (mode == "typingLocked") {
        status_->setText(trKey("status.typingLockedMode"));
    } else {
        status_->setText(trKey("status.typingMode"));
    }
}

void MainWindow::showFolderContextMenu(const QPoint &pos)
{
    QListWidgetItem *item = folderList_->itemAt(pos);
    if (!item) return;

    folderList_->setCurrentItem(item);

    QMenu menu(this);
    menu.addAction(trKey("menu.newFolder"), this, &MainWindow::createFolder);

    const QString folder = item->data(Qt::UserRole).toString();
    if (!folder.isEmpty()) {
        menu.addSeparator();
        menu.addAction(trKey("menu.renameFolder"), this, &MainWindow::renameSelectedFolder);
        menu.addAction(trKey("menu.deleteFolder"), this, &MainWindow::deleteSelectedFolder);
    }

    menu.exec(folderList_->viewport()->mapToGlobal(pos));
}

void MainWindow::showPhraseContextMenu(const QPoint &pos)
{
    QTreeWidgetItem *item = phraseTree_->itemAt(pos);
    if (!item) return;

    phraseTree_->setCurrentItem(item);
    loadSelectedPhraseIntoInput();

    QMenu menu(this);
    menu.addAction(trKey("menu.speakText"), this, [this] { speakText(input_->text(), selectedPhraseIndex()); });
    menu.addAction(trKey("menu.editPhrase"), this, [this] {
        const int index = selectedPhraseIndex();
        if (index >= 0) editPhrase(index);
    });
    menu.addAction(trKey("menu.duplicatePhrase"), this, &MainWindow::duplicateSelectedPhrase);
    menu.addAction(trKey("menu.moveToFolder"), this, &MainWindow::moveSelectedPhraseToFolder);
    menu.addSeparator();
    menu.addAction(trKey("menu.deletePhrase"), this, &MainWindow::deleteSelectedPhrase);

    menu.exec(phraseTree_->viewport()->mapToGlobal(pos));
}

void MainWindow::renameSelectedFolder()
{
    if (!folderList_ || !folderList_->currentItem()) return;

    const QString oldName = folderList_->currentItem()->data(Qt::UserRole).toString();
    if (oldName.isEmpty()) return;

    bool ok = false;
    const QString newName = QInputDialog::getText(
        this,
        trKey("dialog.renameFolder"),
        trKey("dialog.folderPrompt"),
        QLineEdit::Normal,
        oldName,
        &ok
    ).trimmed();

    if (!ok || newName.isEmpty() || newName == oldName) return;

    for (auto &phrase : phrases_) {
        if (phrase.folder == oldName) phrase.folder = newName;
    }

    settings_.folders.removeAll(oldName);
    if (!settings_.folders.contains(newName)) settings_.folders << newName;

    SettingsStore::save(settings_);
    PhraseStore::save(phrases_);

    refreshFolders();

    for (int i = 0; i < folderList_->count(); ++i) {
        if (folderList_->item(i)->data(Qt::UserRole).toString() == newName) {
            folderList_->setCurrentRow(i);
            break;
        }
    }

    refreshPhrases();
    status_->setText(trKey("status.folderRenamed"));
}

void MainWindow::deleteSelectedFolder()
{
    if (!folderList_ || !folderList_->currentItem()) return;

    const QString folder = folderList_->currentItem()->data(Qt::UserRole).toString();
    if (folder.isEmpty() || folder == "General") {
        QMessageBox::information(this, trKey("dialog.folder"), trKey("dialog.protectedFolder"));
        return;
    }

    if (QMessageBox::question(this, trKey("dialog.folder"), trKey("dialog.deleteFolderQuestion")) != QMessageBox::Yes) {
        return;
    }

    for (auto &phrase : phrases_) {
        if (phrase.folder == folder) phrase.folder = "General";
    }

    settings_.folders.removeAll(folder);
    if (!settings_.folders.contains("General")) settings_.folders << "General";

    SettingsStore::save(settings_);
    PhraseStore::save(phrases_);

    refreshFolders();
    refreshPhrases();
    status_->setText(trKey("status.folderDeleted"));
}

void MainWindow::speakText(const QString &text, int phraseIndex)
{
    const QString result = speaker_.speak(text);
    if (!result.isEmpty()) {
        status_->setText(trKey(result));
        return;
    }

    if (phraseIndex >= 0 && phraseIndex < phrases_.size()) {
        phrases_[phraseIndex].useCount++;
        phrases_[phraseIndex].updatedAt = QDateTime::currentDateTimeUtc();
        PhraseStore::save(phrases_);
        refreshPhrases();
    }

    status_->setText(trKey("status.speaking"));
    QTimer::singleShot(3500, this, [this] {
        if (!status_) return;
        if (focusWidget() == phraseTree_) updateModeStatus("phrase");
        else updateModeStatus("typing");
    });
    if (settings_.clearAfterSpeak && phraseIndex < 0) input_->clear();
}

void MainWindow::addPhrase(const QString &text)
{
    const QString normalized = text.simplified();
    if (normalized.isEmpty()) {
        status_->setText(trKey("status.emptyText"));
        return;
    }

    for (const auto &p : phrases_) {
        if (p.text == normalized) {
            status_->setText(trKey("status.duplicate"));
            return;
        }
    }

    Phrase p;
    p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.text = normalized;
    p.folder = currentFolderFilter().isEmpty() ? "General" : currentFolderFilter();
    p.createdAt = QDateTime::currentDateTimeUtc();
    p.updatedAt = p.createdAt;
    phrases_.push_back(p);
    PhraseStore::save(phrases_);
    refreshFolders();
    refreshPhrases();
    status_->setText(trKey("status.saved"));
}

void MainWindow::editPhrase(int index)
{
    if (index < 0 || index >= phrases_.size()) return;

    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.editPhrase"));
    auto *layout = new QVBoxLayout(&dialog);
    auto *edit = new QPlainTextEdit(&dialog);
    edit->setPlainText(phrases_[index].text);
    layout->addWidget(edit);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    if (dialog.exec() == QDialog::Accepted) {
        const QString text = edit->toPlainText().simplified();
        if (!text.isEmpty()) {
            phrases_[index].text = text;
            phrases_[index].updatedAt = QDateTime::currentDateTimeUtc();
            PhraseStore::save(phrases_);
            refreshPhrases();
        }
    }
}

void MainWindow::deleteSelectedPhrase()
{
    if (qApp->focusWidget() != phraseTree_) {
        status_->setText(trKey("status.deleteOnlyList"));
        return;
    }

    const int index = selectedPhraseIndex();
    if (index < 0) return;

    if (QMessageBox::question(this, trKey("dialog.deleteTitle"), trKey("dialog.deleteQuestion")) == QMessageBox::Yes) {
        phrases_.removeAt(index);
        PhraseStore::save(phrases_);
        refreshFolders();
        refreshPhrases();
    }
}

void MainWindow::duplicateSelectedPhrase()
{
    const int index = selectedPhraseIndex();
    if (index < 0) return;
    addPhrase(phrases_[index].text + " ");
}

void MainWindow::createFolder()
{
    bool ok = false;
    const QString folder = QInputDialog::getText(
        this,
        trKey("dialog.newFolder"),
        trKey("dialog.folderPrompt"),
        QLineEdit::Normal,
        "",
        &ok
    ).trimmed();

    if (!ok || folder.isEmpty()) return;

    if (!settings_.folders.contains(folder)) {
        settings_.folders << folder;
        SettingsStore::save(settings_);
    }

    refreshFolders();

    for (int i = 0; i < folderList_->count(); ++i) {
        if (folderList_->item(i)->data(Qt::UserRole).toString() == folder) {
            folderList_->setCurrentRow(i);
            break;
        }
    }

    status_->setText(trKey("status.folderCreated"));
}

void MainWindow::moveSelectedPhraseToFolderName(const QString &folder)
{
    const int index = selectedPhraseIndex();
    if (index < 0 || folder.trimmed().isEmpty()) return;

    const QString cleanFolder = folder.trimmed();

    phrases_[index].folder = cleanFolder;
    phrases_[index].updatedAt = QDateTime::currentDateTimeUtc();

    if (!settings_.folders.contains(cleanFolder)) {
        settings_.folders << cleanFolder;
        SettingsStore::save(settings_);
    }

    PhraseStore::save(phrases_);
    refreshFolders();
    refreshPhrases();
    status_->setText(trKey("status.movedToFolder"));
}

void MainWindow::moveSelectedPhraseToFolder()
{
    const int index = selectedPhraseIndex();
    if (index < 0) return;

    bool ok = false;
    const QString current = phrases_[index].folder.isEmpty() ? "General" : phrases_[index].folder;
    const QString folder = QInputDialog::getText(this, trKey("dialog.folder"), trKey("dialog.folderPrompt"), QLineEdit::Normal, current, &ok).trimmed();

    if (!ok || folder.isEmpty()) return;
    moveSelectedPhraseToFolderName(folder);
}

void MainWindow::selectAdjacentVisiblePhrase(int delta)
{
    if (!phraseTree_ || phraseTree_->topLevelItemCount() == 0) return;

    int row = phraseTree_->indexOfTopLevelItem(phraseTree_->currentItem());
    if (row < 0) row = 0;
    row += delta;
    if (row < 0) row = phraseTree_->topLevelItemCount() - 1;
    if (row >= phraseTree_->topLevelItemCount()) row = 0;

    QTreeWidgetItem *item = phraseTree_->topLevelItem(row);
    if (!item) return;

    phraseTree_->setCurrentItem(item);
    phraseTree_->scrollToItem(item);
    loadSelectedPhraseIntoInput();

    // Keep typing focus locked in the input. Arrow keys only browse phrases.
    input_->setFocus();
    input_->setCursorPosition(input_->text().size());
    updateModeStatus("typingLocked");
}

QString MainWindow::currentWordPrefix() const
{
    if (!input_) return {};

    const QString text = input_->text();
    const int cursor = input_->cursorPosition();

    int start = cursor;
    while (start > 0) {
        const QChar ch = text.at(start - 1);
        if (!ch.isLetterOrNumber() && ch != QChar('_')) break;
        --start;
    }

    return text.mid(start, cursor - start);
}

QStringList MainWindow::autocompleteWords(const QString &prefix) const
{
    const QString normalizedPrefix = prefix.trimmed().toLower();
    if (normalizedPrefix.size() < 1) return {};

    QMap<QString, int> score;

    auto addWord = [&](const QString &word, int weight) {
        const QString clean = word.toLower().trimmed();
        if (clean.size() <= normalizedPrefix.size()) return;
        if (!clean.startsWith(normalizedPrefix)) return;
        score[clean] += weight;
    };

    auto addWords = [&](const QString &text, int weight) {
        const QStringList words = text.toLower().split(QRegularExpression("[^\\p{L}\\p{N}_]+"), Qt::SkipEmptyParts);
        for (const QString &word : words) addWord(word, weight);
    };

    // Built-in starter dictionary so autocomplete is useful before the user builds history.
    const QStringList csCommon = {
        "ano", "ne", "nevím", "prosím", "děkuju", "děkuji", "dobře", "jasně", "můžu", "můžete",
        "potřebuju", "potřebuji", "pomoc", "chvilku", "odpověď", "zopakovat", "pomaleji", "rozumím",
        "souhlasím", "nesouhlasím", "bolí", "dělat", "mluvit", "hlas", "syntetizátor"
    };
    const QStringList enCommon = {
        "yes", "no", "please", "thank", "thanks", "hello", "help", "need", "moment", "understand",
        "repeat", "slowly", "agree", "disagree", "speak", "voice", "answer", "question", "doctor"
    };

    for (const QString &word : csCommon) addWord(word, 2);
    for (const QString &word : enCommon) addWord(word, 2);

    for (const Phrase &phrase : phrases_) {
        addWords(phrase.text, qMax(4, phrase.useCount + 4));
    }

    addWords(input_->text(), 3);

    struct Candidate {
        QString word;
        int score;
    };

    QVector<Candidate> candidates;
    for (auto it = score.constBegin(); it != score.constEnd(); ++it) {
        candidates.push_back({it.key(), it.value()});
    }

    std::sort(candidates.begin(), candidates.end(), [](const Candidate &a, const Candidate &b) {
        if (a.score != b.score) return a.score > b.score;
        if (a.word.size() != b.word.size()) return a.word.size() < b.word.size();
        return a.word < b.word;
    });

    QStringList result;
    for (const Candidate &candidate : candidates) {
        if (!result.contains(candidate.word)) result << candidate.word;
        if (result.size() >= 8) break;
    }

    return result;
}

void MainWindow::updateAutocompletePreview()
{
    if (!autocompletePreview_ || !input_) return;

    const QString prefix = currentWordPrefix();
    const QStringList candidates = autocompleteWords(prefix);

    if (prefix.isEmpty() || candidates.isEmpty()) {
        if (autocompleteInline_) autocompleteInline_->setText("");
        autocompletePreview_->setText(trKey("autocomplete.hint"));
        return;
    }

    const QString first = candidates.first();
    if (autocompleteInline_) {
        autocompleteInline_->setText(prefix.toHtmlEscaped() + " → <b>" + first.toHtmlEscaped() + "</b>");
    }

    QStringList preview;
    for (int i = 1; i < candidates.size() && i < 6; ++i) {
        preview << candidates[i].toHtmlEscaped();
    }

    if (preview.isEmpty()) {
        autocompletePreview_->setText(trKey("autocomplete.preview") + " <b>" + first.toHtmlEscaped() + "</b>");
    } else {
        autocompletePreview_->setText(trKey("autocomplete.alternatives") + " " + preview.join("  ·  "));
    }
}

bool MainWindow::autocompleteCurrentWord()
{
    if (!input_) return false;

    const QString text = input_->text();
    const int cursor = input_->cursorPosition();

    int start = cursor;
    while (start > 0) {
        const QChar ch = text.at(start - 1);
        if (!ch.isLetterOrNumber() && ch != QChar('_')) break;
        --start;
    }

    const QString activeWord = text.mid(start, cursor - start).toLower();
    if (activeWord.isEmpty()) {
        autocompletePrefix_.clear();
        autocompleteCandidates_.clear();
        autocompleteCandidateIndex_ = -1;
        updateAutocompletePreview();
        status_->setText(trKey("status.noAutocomplete"));
        return true;
    }

    // Repeated Tab should keep cycling from the original prefix, even after
    // the input text has been programmatically replaced with a completed word.
    if (!autocompletePrefix_.isEmpty() && activeWord.startsWith(autocompletePrefix_)) {
        autocompleteCandidates_ = autocompleteWords(autocompletePrefix_);
        if (autocompleteCandidates_.isEmpty()) {
            updateAutocompletePreview();
            status_->setText(trKey("status.noAutocomplete"));
            return true;
        }

        const int currentIndex = autocompleteCandidates_.indexOf(activeWord);
        if (currentIndex >= 0) autocompleteCandidateIndex_ = (currentIndex + 1) % autocompleteCandidates_.size();
        else autocompleteCandidateIndex_ = (autocompleteCandidateIndex_ + 1) % autocompleteCandidates_.size();
    } else {
        autocompletePrefix_ = activeWord;
        autocompleteCandidates_ = autocompleteWords(autocompletePrefix_);
        autocompleteCandidateIndex_ = 0;
    }

    if (autocompleteCandidates_.isEmpty()) {
        autocompleteCandidateIndex_ = -1;
        updateAutocompletePreview();
        status_->setText(trKey("status.noAutocomplete"));
        return true;
    }

    const QString completion = autocompleteCandidates_.value(qBound(0, autocompleteCandidateIndex_, autocompleteCandidates_.size() - 1));
    if (completion.isEmpty()) {
        updateAutocompletePreview();
        return true;
    }

    QString newText = text;
    newText.replace(start, cursor - start, completion);
    suppressAutocompleteReset_ = true;
    input_->setText(newText);
    input_->setCursorPosition(start + completion.size());
    suppressAutocompleteReset_ = false;

    updateAutocompletePreview();
    status_->setText(trKey("status.autocompleteApplied") + " " + completion);
    return true;
}

void MainWindow::selectVisiblePhraseNumber(int number, bool speakImmediately)
{
    const auto indices = sortedIndices();
    const int position = number - 1;
    if (position < 0 || position >= indices.size()) return;

    const int phraseIndex = indices[position];
    for (int i = 0; i < phraseTree_->topLevelItemCount(); ++i) {
        QTreeWidgetItem *item = phraseTree_->topLevelItem(i);
        if (item && item->data(0, Qt::UserRole).toInt() == phraseIndex) {
            phraseTree_->setCurrentItem(item);
            phraseTree_->setFocus();
            break;
        }
    }

    if (speakImmediately) speakText(phrases_[phraseIndex].text, phraseIndex);
}

void MainWindow::clearAppDataFiles()
{
    QFile::remove(AppPaths::settingsPath());
    QFile::remove(AppPaths::phrasesPath());

    // For testing and a truly clean setup, remove generated/runtime data too.
    QDir(AppPaths::dataDir() + "/python-embed").removeRecursively();
    QDir(AppPaths::dataDir() + "/piper-venv").removeRecursively();
    QDir(AppPaths::voicesDir()).removeRecursively();

    QFile::remove(AppPaths::dataDir() + "/python-embed.zip");
    QFile::remove(AppPaths::dataDir() + "/last.wav");
    QFile::remove(AppPaths::dataDir() + "/native-text-utf8.txt");
    QFile::remove(AppPaths::dataDir() + "/piper-input-utf8.txt");
}

void MainWindow::resetSettingsAndRestartWizard()
{
    if (QMessageBox::question(this, trKey("dialog.resetSetup"), trKey("dialog.resetSetupQuestion")) != QMessageBox::Yes) {
        return;
    }

    clearAppDataFiles();

    settings_ = SettingsStore::load();
    phrases_ = PhraseStore::load();
    I18n::instance().load(settings_.language);
    speaker_.setSettings(settings_);

    settings_.firstRunDone = false;
    SettingsStore::save(settings_);

    rebuildUiAfterLanguageChange();

    status_->setText(trKey("status.settingsReset"));
    QTimer::singleShot(200, this, &MainWindow::showFirstRunWizard);
}

void MainWindow::rebuildUiAfterLanguageChange()
{
    I18n::instance().load(settings_.language);

    QWidget *oldCentral = takeCentralWidget();
    if (oldCentral) oldCentral->deleteLater();

    if (menuBar()) {
        menuBar()->clear();
    }

    buildUi();
    buildMenus();
    applyTheme();
    refreshFolders();
    refreshPhrases();

    status_->setText(trKey("status.languageApplied"));
}

bool MainWindow::installEdgeTtsRuntime(QWidget *parentWidget, bool silent)
{
    QWidget *owner = parentWidget ? parentWidget : this;

    const QMessageBox::StandardButton answer = silent
        ? QMessageBox::Yes
        : QMessageBox::question(
              owner,
              trKey("dialog.voice"),
              trKey("status.installEdgeTtsQuestion"),
              QMessageBox::Yes | QMessageBox::No,
              QMessageBox::Yes
          );

    if (answer != QMessageBox::Yes) return false;

    QProgressDialog progress(trKey("status.installingEdgeTts"), trKey("button.cancel"), 0, 0, owner);
    progress.setMinimumWidth(620);
    progress.setWindowModality(Qt::WindowModal);
    progress.show();
    qApp->processEvents();

    auto runLocal = [&](const QString &program, const QStringList &args, const QString &label, bool showError = true) -> bool {
        progress.setLabelText(label);
        qApp->processEvents();

        QProcess process;
        process.start(program, args);

        if (!process.waitForStarted(20000)) {
            if (showError) {
                QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.processStartFailed") + "\n\n" + program);
            }
            return false;
        }

        while (!process.waitForFinished(250)) {
            qApp->processEvents();
            if (progress.wasCanceled()) {
                process.kill();
                return false;
            }
        }

        if (process.exitCode() != 0) {
            if (showError) {
                const QString out = QString::fromUtf8(process.readAllStandardOutput());
                const QString err = QString::fromUtf8(process.readAllStandardError());
                QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.edgeTtsInstallFailed") + "\n\n" + out + "\n" + err);
            }
            return false;
        }

        return true;
    };

#ifdef Q_OS_WIN
    // Windows LTSC / Windows 11 reliability: do not use the normal Python
    // installer and do not depend on system-wide Python. Use the official
    // embeddable Python ZIP in the app data directory and run edge-tts as
    // `python.exe -m edge_tts`. This is admin-free and self-contained.
    const QString pythonRoot = AppPaths::dataDir() + "/python-edge";
    const QString pythonExe = pythonRoot + "/python.exe";
    const QString zipPath = AppPaths::dataDir() + "/python-edge-embed.zip";
    const QString getPipPath = AppPaths::dataDir() + "/get-pip.py";

    auto psQuote = [](QString value) {
        value = QDir::toNativeSeparators(value);
        value.replace("'", "''");
        return QString("'") + value + "'";
    };

    if (!QFileInfo::exists(pythonExe)) {
        QDir().mkpath(pythonRoot);
        const QString installCommand =
            "$ErrorActionPreference='Stop'; "
            "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "
            "$zip=" + psQuote(zipPath) + "; "
            "$target=" + psQuote(pythonRoot) + "; "
            "$url='https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip'; "
            "if (-not (Test-Path $zip)) { "
            "  try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip } "
            "  catch { $wc = New-Object System.Net.WebClient; $wc.DownloadFile($url, $zip) } "
            "}; "
            "if (Test-Path $target) { Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue }; "
            "New-Item -ItemType Directory -Force -Path $target | Out-Null; "
            "Expand-Archive -LiteralPath $zip -DestinationPath $target -Force; "
            "$pth = Get-ChildItem -LiteralPath $target -Filter 'python*._pth' | Select-Object -First 1; "
            "if ($pth) { (Get-Content -LiteralPath $pth.FullName) -replace '^#import site','import site' | Set-Content -LiteralPath $pth.FullName -Encoding ASCII }; "
            "if (-not (Test-Path (Join-Path $target 'python.exe'))) { throw 'python.exe was not unpacked' }";

        if (!runLocal("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", installCommand}, trKey("status.installingPythonRuntime"))) return false;
    }

    const QString checkEdgeCommand =
        "$ErrorActionPreference='SilentlyContinue'; & " + psQuote(pythonExe) + " -m edge_tts --help *> $null; exit $LASTEXITCODE";
    bool edgeModuleOk = runLocal("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", checkEdgeCommand}, trKey("status.checkingEdgeTts"), false);

    if (!edgeModuleOk) {
        const QString installPipAndEdge =
            "$ErrorActionPreference='Stop'; "
            "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "
            "$py=" + psQuote(pythonExe) + "; "
            "$getpip=" + psQuote(getPipPath) + "; "
            "$url='https://bootstrap.pypa.io/get-pip.py'; "
            "try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $getpip } "
            "catch { $wc = New-Object System.Net.WebClient; $wc.DownloadFile($url, $getpip) }; "
            "& $py $getpip --no-warn-script-location; "
            "& $py -m pip install --upgrade --no-warn-script-location edge-tts";

        if (!runLocal("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", installPipAndEdge}, trKey("status.installingEdgeTtsPackage"))) return false;
    }

    const QString verifyCommand =
        "$ErrorActionPreference='SilentlyContinue'; & " + psQuote(pythonExe) + " -m edge_tts --help *> $null; exit $LASTEXITCODE";
    if (!runLocal("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", verifyCommand}, trKey("status.checkingEdgeTts"), false)) {
        QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.edgeTtsInstallFailed"));
        return false;
    }

    settings_.edgeTtsCommand = pythonExe;
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);

    if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.edgeTtsInstalled"));
    return true;
#else
    const QString venvDir = AppPaths::dataDir() + "/edge-tts-venv";
    const QString venvPython = venvDir + "/bin/python";
    const QString edgeCmd = venvDir + "/bin/edge-tts";

    if (!QFileInfo::exists(edgeCmd)) {
        if (!runLocal("python3", {"-m", "venv", venvDir}, trKey("status.creatingEdgeVenv"))) {
            QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.pythonVenvMissing"));
            return false;
        }
        if (!runLocal(venvPython, {"-m", "pip", "install", "--upgrade", "pip"}, trKey("status.upgradingPip"))) return false;
        if (!runLocal(venvPython, {"-m", "pip", "install", "--upgrade", "edge-tts"}, trKey("status.installingEdgeTtsPackage"))) return false;
    }

    if (!QFileInfo::exists(edgeCmd)) {
        QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.edgeTtsInstallFailed"));
        return false;
    }

    settings_.edgeTtsCommand = edgeCmd;
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);

    if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.edgeTtsInstalled"));
    return true;
#endif
}

bool MainWindow::installEspeakNgRuntime(QWidget *parentWidget, bool silent)
{
    QWidget *owner = parentWidget ? parentWidget : this;

    const QMessageBox::StandardButton answer = silent
        ? QMessageBox::Yes
        : QMessageBox::question(
              owner,
              trKey("dialog.voice"),
              trKey("status.installEspeakQuestion"),
              QMessageBox::Yes | QMessageBox::No,
              QMessageBox::Yes
          );

    if (answer != QMessageBox::Yes) return false;

    QProgressDialog progress(trKey("status.installingEspeakNg"), trKey("button.cancel"), 0, 0, owner);
    progress.setMinimumWidth(620);
    progress.setWindowModality(Qt::WindowModal);
    progress.show();
    qApp->processEvents();

    auto runLocal = [&](const QString &program, const QStringList &args, const QString &label, bool showError = true) -> bool {
        progress.setLabelText(label);
        qApp->processEvents();

        QProcess process;
        process.start(program, args);

        if (!process.waitForStarted(15000)) {
            if (showError) QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.processStartFailed") + "\n\n" + program);
            return false;
        }

        while (!process.waitForFinished(250)) {
            qApp->processEvents();
            if (progress.wasCanceled()) {
                process.kill();
                return false;
            }
        }

        if (process.exitCode() != 0) {
            if (showError) {
                const QString out = QString::fromUtf8(process.readAllStandardOutput());
                const QString err = QString::fromUtf8(process.readAllStandardError());
                QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.espeakInstallFailed") + "\n\n" + out + "\n" + err);
            }
            return false;
        }

        return true;
    };

#ifdef Q_OS_WIN
    // Best effort on Windows. winget is not guaranteed on LTSC, but if it exists
    // this gives users a one-click-ish path. Otherwise show a manual helper.
    if (QFileInfo::exists("C:/Program Files/eSpeak NG/espeak-ng.exe")) {
        if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakAlreadyInstalled"));
        return true;
    }

    const QString command =
        "if (Get-Command winget -ErrorAction SilentlyContinue) { "
        "winget install --id eSpeak-NG.eSpeak-NG -e --accept-package-agreements --accept-source-agreements "
        "} else { exit 10 }";

    if (runLocal("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command}, trKey("status.installingEspeakNg"), false)) {
        if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakInstalled"));
        return true;
    }

    QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakManualWindows"));
    return false;
#elif defined(Q_OS_MAC)
    if (QFileInfo::exists("/opt/homebrew/bin/espeak-ng") || QFileInfo::exists("/usr/local/bin/espeak-ng")) {
        if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakAlreadyInstalled"));
        return true;
    }

    QString brew = "/opt/homebrew/bin/brew";
    if (!QFileInfo::exists(brew)) brew = "/usr/local/bin/brew";

    if (QFileInfo::exists(brew)) {
        if (runLocal(brew, {"install", "espeak-ng"}, trKey("status.installingEspeakNg"), false)) {
            if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakInstalled"));
            return true;
        }
    } else {
        const QString script =
            "tell application \"Terminal\" to do script \"/bin/bash -c '$("
            "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
            ")'; echo; echo Homebrew hotovo. Dosty Speak potom znovu spusti instalaci eSpeak NG.\"";
        runLocal("osascript", {"-e", script}, trKey("status.installingHomebrew"), false);
        QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.homebrewInstallStarted"));
        return false;
    }

    QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.espeakManualMac"));
    return false;
#else
    const QString command =
        "set -e; "
        "if command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y espeak-ng; "
        "elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y espeak-ng; "
        "elif command -v zypper >/dev/null 2>&1; then sudo zypper install -y espeak-ng; "
        "elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed espeak-ng; "
        "else exit 20; fi";

    if (runLocal("bash", {"-lc", command}, trKey("status.installingEspeakNg"), false)) {
        if (!silent) QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.espeakInstalled"));
        return true;
    }

    QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.espeakManualLinux"));
    return false;
#endif
}

bool MainWindow::installVisualCppRuntime(QWidget *parentWidget, bool silent)
{
#ifdef Q_OS_WIN
    QWidget *owner = parentWidget ? parentWidget : this;

    const QString existingSystem32 = "C:/Windows/System32/VCRUNTIME140.dll";
    const QString existingMsvcp = "C:/Windows/System32/MSVCP140.dll";
    if (QFileInfo::exists(existingSystem32) && QFileInfo::exists(existingMsvcp)) {
        if (!silent) {
            QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.vcRuntimeAlreadyInstalled"));
        }
        return true;
    }

    const QMessageBox::StandardButton answer = silent
        ? QMessageBox::Yes
        : QMessageBox::question(
              owner,
              trKey("dialog.voice"),
              trKey("status.installVcRuntimeQuestion"),
              QMessageBox::Yes | QMessageBox::No,
              QMessageBox::Yes
          );

    if (answer != QMessageBox::Yes) return false;

    QProgressDialog progress(trKey("status.downloadingVcRuntime"), trKey("button.cancel"), 0, 0, owner);
    progress.setMinimumWidth(580);
    progress.setWindowModality(Qt::WindowModal);
    progress.show();
    qApp->processEvents();

    auto runLocalPowerShell = [&](const QString &command, const QString &label, bool showError = true) -> bool {
        progress.setLabelText(label);
        qApp->processEvents();

        QProcess process;
        process.start("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command});

        if (!process.waitForStarted(15000)) {
            if (showError) QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.processStartFailed") + "\n\npowershell");
            return false;
        }

        while (!process.waitForFinished(250)) {
            qApp->processEvents();
            if (progress.wasCanceled()) {
                process.kill();
                return false;
            }
        }

        if (process.exitCode() != 0) {
            if (showError) {
                const QString out = QString::fromUtf8(process.readAllStandardOutput());
                const QString err = QString::fromUtf8(process.readAllStandardError());
                QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.vcRuntimeInstallFailed") + "\n\n" + out + "\n" + err);
            }
            return false;
        }

        return true;
    };

    const QString vcRedistPath = AppPaths::dataDir() + "/vc_redist.x64.exe";
    QString escapedVcPath = vcRedistPath;
    escapedVcPath.replace("'", "''");

    const QString downloadCommand =
        "$ErrorActionPreference='Stop'; "
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "
        "$url='https://aka.ms/vs/17/release/vc_redist.x64.exe'; "
        "$out='" + escapedVcPath + "'; "
        "try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out } "
        "catch { "
        "  $wc = New-Object System.Net.WebClient; "
        "  $wc.DownloadFile($url, $out); "
        "}";

    if (!QFileInfo::exists(vcRedistPath)) {
        if (!runLocalPowerShell(downloadCommand, trKey("status.downloadingVcRuntime"))) return false;
    }

    progress.setLabelText(trKey("status.installingVcRuntime"));
    qApp->processEvents();

    QString nativeVcPath = QDir::toNativeSeparators(vcRedistPath);

    // Prefer ShellExecuteEx from the Qt process. It gives a normal UAC prompt
    // and works better on Windows 10 LTSC than nested PowerShell Start-Process -Verb RunAs.
    SHELLEXECUTEINFOW sei;
    ZeroMemory(&sei, sizeof(sei));
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"runas";
    const std::wstring fileW = nativeVcPath.toStdWString();
    const std::wstring paramsW = L"/install /quiet /norestart";
    sei.lpFile = fileW.c_str();
    sei.lpParameters = paramsW.c_str();
    sei.nShow = SW_SHOWNORMAL;

    if (!ShellExecuteExW(&sei)) {
        QMessageBox::warning(owner, trKey("dialog.voice"), trKey("status.vcRuntimeInstallFailed"));
        return false;
    }

    if (sei.hProcess) {
        while (WaitForSingleObject(sei.hProcess, 250) == WAIT_TIMEOUT) {
            qApp->processEvents();
            if (progress.wasCanceled()) {
                CloseHandle(sei.hProcess);
                return false;
            }
        }
        CloseHandle(sei.hProcess);
    }

    if (!silent) {
        QMessageBox::information(owner, trKey("dialog.voice"), trKey("status.vcRuntimeInstalled"));
    }

    return true;
#else
    Q_UNUSED(parentWidget);
    Q_UNUSED(silent);
    return true;
#endif
}

bool MainWindow::installPiperRuntimeSilent(QWidget *parentWidget)
{
    QProgressDialog progress(trKey("status.installingPiper"), trKey("button.cancel"), 0, 0, parentWidget ? parentWidget : this);
    progress.setMinimumWidth(580);
    progress.setWindowModality(Qt::WindowModal);
    progress.show();
    qApp->processEvents();

    auto run = [&](const QString &program, const QStringList &args, const QString &label, bool showError = true) -> bool {
        progress.setLabelText(label);
        qApp->processEvents();

        QProcess process;
        process.start(program, args);

        if (!process.waitForStarted(15000)) {
            if (showError) {
                QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.processStartFailed") + "\n\n" + program);
            }
            return false;
        }

        while (!process.waitForFinished(250)) {
            qApp->processEvents();
            if (progress.wasCanceled()) {
                process.kill();
                return false;
            }
        }

        if (process.exitCode() != 0) {
            if (showError) {
                const QString out = QString::fromUtf8(process.readAllStandardOutput());
                const QString err = QString::fromUtf8(process.readAllStandardError());
                QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.piperInstallFailed") + "\n\n" + out + "\n" + err);
            }
            return false;
        }

        return true;
    };

#ifdef Q_OS_WIN
    // Windows 10 LTSC often does not have winget and can also fail with
    // embeddable Python + pip/piper-tts. Use the official standalone Piper
    // Windows release instead. This avoids requiring system Python entirely.
    const QString piperDir = AppPaths::dataDir() + "/piper-runtime";
    const QString piperExe = piperDir + "/piper/piper.exe";
    const QString zipPath = AppPaths::dataDir() + "/piper-windows-amd64.zip";
    const QString piperZipUrl = "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip";

    if (QFileInfo::exists(piperExe)) {
        settings_.piperBinary = piperExe;
        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
        return true;
    }

    QDir().mkpath(piperDir);

    auto runPowerShell = [&](const QString &command, const QString &label) -> bool {
        return run("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command}, label);
    };

    QString escapedUrl = piperZipUrl;
    escapedUrl.replace("'", "''");
    QString escapedZipPath = zipPath;
    escapedZipPath.replace("'", "''");
    QString escapedPiperDir = piperDir;
    escapedPiperDir.replace("'", "''");

    const QString downloadCommand =
        "$ErrorActionPreference='Stop'; "
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "
        "$url='" + escapedUrl + "'; "
        "$out='" + escapedZipPath + "'; "
        "try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out } "
        "catch { "
        "  $wc = New-Object System.Net.WebClient; "
        "  $wc.DownloadFile($url, $out); "
        "}";

    if (!QFileInfo::exists(zipPath)) {
        if (!runPowerShell(downloadCommand, trKey("status.downloadingPiperRuntime"))) return false;
    }

    const QString extractCommand =
        "$ErrorActionPreference='Stop'; "
        "$zip='" + escapedZipPath + "'; "
        "$dest='" + escapedPiperDir + "'; "
        "if (Test-Path $dest) { Remove-Item -Force -Recurse $dest }; "
        "New-Item -ItemType Directory -Force -Path $dest | Out-Null; "
        "Expand-Archive -Force -Path $zip -DestinationPath $dest";

    if (!runPowerShell(extractCommand, trKey("status.extractingPiperRuntime"))) return false;

    QString foundPiper = piperExe;
    if (!QFileInfo::exists(foundPiper)) {
        const QStringList found = QDir(piperDir).entryList(QStringList() << "piper.exe", QDir::Files, QDir::Name);
        if (!found.isEmpty()) foundPiper = piperDir + "/" + found.first();

        if (!QFileInfo::exists(foundPiper)) {
            QDirIterator it(piperDir, QStringList() << "piper.exe", QDir::Files, QDirIterator::Subdirectories);
            if (it.hasNext()) foundPiper = it.next();
        }
    }

    if (!QFileInfo::exists(foundPiper)) {
        QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.piperExeMissing"));
        return false;
    }

    // Windows 10 LTSC may miss the Microsoft Visual C++ runtime required by
    // the official Piper build. Verify Piper before saving the path. If it
    // cannot start, install the official VC++ Redistributable and retry.
    auto verifyPiperRuntime = [&]() -> bool {
        QProcess verify;
        verify.start(foundPiper, {"--help"});
        if (!verify.waitForStarted(5000)) return false;
        if (!verify.waitForFinished(10000)) {
            verify.kill();
            return false;
        }
        return verify.exitCode() == 0;
    };

    if (!verifyPiperRuntime()) {
        installVisualCppRuntime(parentWidget ? parentWidget : this, true);

        if (!verifyPiperRuntime()) {
            QMessageBox::warning(
                parentWidget ? parentWidget : this,
                trKey("dialog.voice"),
                trKey("status.vcRuntimeRequired")
            );
            return false;
        }
    }

    settings_.piperBinary = foundPiper;
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);
    return true;
#else
    const QString pipPath = AppPaths::dataDir() + "/piper-venv/bin/pip";
    const QString piperPath = AppPaths::dataDir() + "/piper-venv/bin/piper";
    const QString venvDir = AppPaths::dataDir() + "/piper-venv";

    if (!QFileInfo::exists(pipPath)) {
        if (!run("python3", {"-m", "venv", venvDir}, trKey("status.creatingVenv"))) return false;
    }

    if (!run(pipPath, {"install", "--upgrade", "pip"}, trKey("status.upgradingPip"))) return false;
    if (!run(pipPath, {"install", "--upgrade", "piper-tts"}, trKey("status.installingPiperPackage"))) return false;

    settings_.piperBinary = piperPath;
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);
    return true;
#endif
}

bool MainWindow::configurePiperVoiceById(const QString &voiceId, QWidget *parentWidget, bool installRuntimeIfNeeded)
{
    DownloadableVoice selectedVoice;
    bool found = false;

    for (const auto &v : VoiceCatalog::downloadable()) {
        if (v.id == voiceId) {
            selectedVoice = v;
            found = true;
            break;
        }
    }

    if (!found) {
        QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.voiceNotFound"));
        return false;
    }

    if (installRuntimeIfNeeded) {
        if (!QFileInfo::exists(settings_.piperBinary)) {
            if (!installPiperRuntimeSilent(parentWidget ? parentWidget : this)) return false;
        } else {
            status_->setText(trKey("status.piperAlreadyInstalled"));
        }
    }

    settings_.engine = "piper";
    settings_.piperModel = VoiceCatalog::modelPath(selectedVoice);
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);

    if (VoiceCatalog::isDownloaded(selectedVoice)) {
        status_->setText(trKey("status.voiceAlreadyDownloaded"));
        return true;
    }

    downloadVoiceById(voiceId, parentWidget ? parentWidget : this);

    if (!VoiceCatalog::isDownloaded(selectedVoice)) {
        QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.voiceDownloadFailed"));
        return false;
    }

    settings_.engine = "piper";
    settings_.piperModel = VoiceCatalog::modelPath(selectedVoice);
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);
    status_->setText(trKey("status.voiceConfigured"));
    return true;
}

void MainWindow::downloadVoiceById(const QString &voiceId, QWidget *parentWidget)
{
    for (const auto &v : VoiceCatalog::downloadable()) {
        if (v.id == voiceId) {
            settings_.engine = "piper";
            settings_.piperModel = VoiceCatalog::modelPath(v);
            SettingsStore::save(settings_);
            speaker_.setSettings(settings_);

            if (VoiceCatalog::isDownloaded(v)) {
                status_->setText(trKey("status.voiceSaved"));
                return;
            }

            QProgressDialog progress(trKey("status.downloadingVoiceModel"), trKey("button.cancel"), 0, 100, parentWidget ? parentWidget : this);
            progress.setMinimumWidth(560);
            progress.setWindowModality(Qt::WindowModal);
            progress.show();
            qApp->processEvents();

            auto downloadSync = [&](const QUrl &url, const QString &target) -> bool {
                QNetworkReply *reply = network_.get(QNetworkRequest(url));
                QFile file(target + ".part");

                if (!file.open(QIODevice::WriteOnly)) {
                    reply->deleteLater();
                    return false;
                }

                QObject::connect(reply, &QNetworkReply::downloadProgress, &progress, [&](qint64 received, qint64 total) {
                    if (total > 0) progress.setValue(static_cast<int>((received * 100) / total));
                    qApp->processEvents();
                });

                bool finished = false;
                QObject::connect(reply, &QNetworkReply::readyRead, &progress, [&]() {
                    file.write(reply->readAll());
                });
                QObject::connect(reply, &QNetworkReply::finished, &progress, [&]() {
                    file.write(reply->readAll());
                    finished = true;
                });
                QObject::connect(&progress, &QProgressDialog::canceled, reply, &QNetworkReply::abort);

                while (!finished) {
                    qApp->processEvents();
                    if (progress.wasCanceled()) {
                        reply->abort();
                        break;
                    }
                }

                const bool ok = reply->error() == QNetworkReply::NoError && !progress.wasCanceled();
                file.close();

                if (ok) {
                    QFile::remove(target);
                    QFile::rename(target + ".part", target);
                } else {
                    QFile::remove(target + ".part");
                }

                reply->deleteLater();
                return ok;
            };

            progress.setLabelText(trKey("status.downloadingVoiceModel"));
            const bool modelOk = downloadSync(QUrl(v.onnxUrl), VoiceCatalog::modelPath(v));
            if (!modelOk) return;

            progress.setValue(0);
            const bool configOk = downloadSync(QUrl(v.configUrl), VoiceCatalog::configPath(v));
            if (!configOk) return;

            settings_.engine = "piper";
            settings_.piperModel = VoiceCatalog::modelPath(v);
            SettingsStore::save(settings_);
            speaker_.setSettings(settings_);

            status_->setText(trKey("status.voiceSaved"));
            return;
        }
    }
}

void MainWindow::showFirstRunWizard()
{
    // Step 1: language and theme.
    QDialog step1(this);
    step1.setWindowTitle(trKey("dialog.firstRun"));
    step1.resize(620, 320);
    step1.setMinimumSize(580, 300);

    auto *step1Layout = new QVBoxLayout(&step1);
    step1Layout->setSpacing(14);

    auto *logoRow = new QHBoxLayout();
    auto *logo = new QLabel(&step1);
    QPixmap logoPixmap(":/icons/dosty-speak.png");
    if (logoPixmap.isNull()) logoPixmap.load(QCoreApplication::applicationDirPath() + "/resources/icons/dosty-speak.png");
    if (logoPixmap.isNull()) logoPixmap.load(QCoreApplication::applicationDirPath() + "/../Resources/dosty-speak.png");
    logo->setPixmap(logoPixmap.scaled(72, 72, Qt::KeepAspectRatio, Qt::SmoothTransformation));
    logoRow->addStretch(1);
    logoRow->addWidget(logo);
    logoRow->addStretch(1);
    step1Layout->addLayout(logoRow);

    auto *intro = new QLabel(trKey("firstRun.intro"), &step1);
    intro->setWordWrap(true);
    intro->setAlignment(Qt::AlignCenter);
    step1Layout->addWidget(intro);

    auto *form = new QFormLayout();
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *language = new QComboBox(&step1);
    language->setMinimumWidth(220);
    language->setMinimumContentsLength(18);
    language->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    language->addItem("English", "en");
    language->addItem("Čeština", "cs");
    int langIndex = language->findData(settings_.language);
    if (langIndex >= 0) language->setCurrentIndex(langIndex);
    form->addRow(trKey("firstRun.language"), language);

    auto *appearance = new QComboBox(&step1);
    appearance->setMinimumWidth(260);
    appearance->setMinimumContentsLength(24);
    appearance->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    appearance->addItem(trKey("appearance.system"), "system");
    appearance->addItem(trKey("appearance.light"), "light");
    appearance->addItem(trKey("appearance.dark"), "dark");
    appearance->setCurrentIndex(appearance->findData("system"));
    form->addRow(trKey("firstRun.appearance"), appearance);

    step1Layout->addLayout(form);

    auto relabelStep1 = [&]() {
        I18n::instance().load(language->currentData().toString());
        step1.setWindowTitle(trKey("dialog.firstRun"));
        intro->setText(trKey("firstRun.intro"));
        appearance->setItemText(appearance->findData("system"), trKey("appearance.system"));
        appearance->setItemText(appearance->findData("light"), trKey("appearance.light"));
        appearance->setItemText(appearance->findData("dark"), trKey("appearance.dark"));
    };
    connect(language, QOverload<int>::of(&QComboBox::currentIndexChanged), &step1, [&] { relabelStep1(); });

    auto *buttons1 = new QDialogButtonBox(&step1);
    buttons1->addButton(trKey("firstRun.continue"), QDialogButtonBox::AcceptRole);
    buttons1->addButton(trKey("firstRun.skip"), QDialogButtonBox::RejectRole);
    step1Layout->addWidget(buttons1);
    connect(buttons1, &QDialogButtonBox::accepted, &step1, &QDialog::accept);
    connect(buttons1, &QDialogButtonBox::rejected, &step1, &QDialog::reject);

    if (step1.exec() != QDialog::Accepted) {
        settings_.firstRunDone = true;
        SettingsStore::save(settings_);
        return;
    }

    const QString chosenLanguage = language->currentData().toString();
    const bool languageChanged = settings_.language != chosenLanguage;
    settings_.language = chosenLanguage;
    I18n::instance().load(settings_.language);

    const QString appearanceChoice = appearance->currentData().toString();
    if (appearanceChoice == "dark") settings_.darkMode = true;
    else if (appearanceChoice == "light") settings_.darkMode = false;
    else {
        // Reload defaults so the system preference is detected again, especially on macOS.
        AppSettings defaults = SettingsStore::load();
        settings_.darkMode = defaults.darkMode;
    }

    phrases_ = PhraseStore::defaultPhrasesForLanguage(settings_.language);
    PhraseStore::save(phrases_);
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);
    applyTheme();

    // Step 2: install engines and voices.
    QDialog step2(this);
    step2.setWindowTitle(trKey("firstRun.installEngines"));
    step2.resize(980, 620);
    step2.setMinimumSize(900, 560);

    auto *step2Layout = new QVBoxLayout(&step2);
    auto *step2Intro = new QLabel(trKey("firstRun.installIntro"), &step2);
    step2Intro->setWordWrap(true);
    step2Layout->addWidget(step2Intro);

    auto *mainSplit = new QHBoxLayout();
    mainSplit->setSpacing(14);

    auto *engineList = new QListWidget(&step2);
    engineList->setMinimumWidth(330);
    engineList->setMaximumWidth(390);
    engineList->setAlternatingRowColors(true);
    engineList->setSelectionMode(QAbstractItemView::SingleSelection);

    struct EngineRow {
        QString id;
        QString titleKey;
        QString descKey;
        bool installable;
        bool defaultChecked;
    };

    QVector<EngineRow> engines = {
        {"native", "engine.native", "engineInfo.native", false, true},
        {"piper", "engine.piper", "engineInfo.piper", true, false},
        {"google_online", "engine.googleOnline", "engineInfo.google", false, true},
        {"edge_online", "engine.edgeOnline", "engineInfo.edge", true, false},
        {"espeak_ng", "engine.espeakNg", "engineInfo.espeak", true, false}
    };

    for (const auto &row : engines) {
        auto *item = new QListWidgetItem((row.installable ? "＋ " : "✓ ") + trKey(row.titleKey), engineList);
        item->setData(Qt::UserRole, row.id);
        item->setData(Qt::UserRole + 1, row.descKey);
        item->setFlags(item->flags() | Qt::ItemIsUserCheckable | Qt::ItemIsSelectable | Qt::ItemIsEnabled);
        item->setCheckState(row.defaultChecked ? Qt::Checked : Qt::Unchecked);
        engineList->addItem(item);
    }
    engineList->setCurrentRow(0);
    mainSplit->addWidget(engineList);

    auto *right = new QVBoxLayout();

    auto *descriptionBox = new QFrame(&step2);
    descriptionBox->setObjectName("descriptionCard");
    descriptionBox->setMinimumWidth(420);
    auto *descriptionLayout = new QVBoxLayout(descriptionBox);
    auto *descriptionTitle = new QLabel(trKey("firstRun.engineDetails"), descriptionBox);
    descriptionTitle->setObjectName("sectionTitle");
    auto *description = new QLabel(descriptionBox);
    description->setWordWrap(true);
    description->setTextFormat(Qt::RichText);
    descriptionLayout->addWidget(descriptionTitle);
    descriptionLayout->addWidget(description);
    right->addWidget(descriptionBox);

    auto *piperVoiceBox = new QGroupBox(trKey("firstRun.morePiperVoices"), &step2);
    auto *piperVoiceLayout = new QVBoxLayout(piperVoiceBox);
    auto *piperVoiceList = new QListWidget(piperVoiceBox);
    piperVoiceList->setSelectionMode(QAbstractItemView::NoSelection);
    for (const auto &v : VoiceCatalog::downloadable()) {
        auto *item = new QListWidgetItem(v.name);
        item->setData(Qt::UserRole, v.id);
        item->setFlags(item->flags() | Qt::ItemIsUserCheckable);
        item->setCheckState(Qt::Unchecked);
        piperVoiceList->addItem(item);
    }
    piperVoiceLayout->addWidget(piperVoiceList);
    right->addWidget(piperVoiceBox, 1);
    right->addStretch(1);

    mainSplit->addLayout(right, 1);
    step2Layout->addLayout(mainSplit, 1);

    auto updateDescription = [&]() {
        if (!engineList->currentItem()) return;
        const QString id = engineList->currentItem()->data(Qt::UserRole).toString();
        const QString descKey = engineList->currentItem()->data(Qt::UserRole + 1).toString();

        QString badges;
        if (id == "native") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span>";
        else if (id == "piper") badges = "<span style='color:#15803d'>✓ Windows 64-bit</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#b45309'>− Windows 32-bit</span>";
        else if (id == "google_online") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#2563eb'>internet</span>";
        else if (id == "edge_online") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#2563eb'>internet</span> · <span style='color:#7c3aed'>edge-tts</span>";
        else if (id == "espeak_ng") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#b45309'>robotic</span>";

        Q_UNUSED(badges);
        description->setText(trKey(descKey));
        piperVoiceBox->setVisible(id == "piper");
    };

    connect(engineList, &QListWidget::currentItemChanged, &step2, [&] { updateDescription(); });
    updateDescription();

    auto *buttons2 = new QDialogButtonBox(&step2);
    buttons2->addButton(trKey("firstRun.continue"), QDialogButtonBox::AcceptRole);
    buttons2->addButton(trKey("firstRun.skip"), QDialogButtonBox::RejectRole);
    step2Layout->addWidget(buttons2);
    connect(buttons2, &QDialogButtonBox::accepted, &step2, [&] {
        bool piperSelected = false;
        bool piperVoiceSelected = false;

        for (int i = 0; i < engineList->count(); ++i) {
            auto *item = engineList->item(i);
            if (item->data(Qt::UserRole).toString() == "piper" && item->checkState() == Qt::Checked) {
                piperSelected = true;
                break;
            }
        }

        for (int i = 0; i < piperVoiceList->count(); ++i) {
            if (piperVoiceList->item(i)->checkState() == Qt::Checked) {
                piperVoiceSelected = true;
                break;
            }
        }

        if (piperSelected && !piperVoiceSelected) {
            QMessageBox::warning(&step2, trKey("engine.piper"), trKey("firstRun.piperVoiceRequired"));
            engineList->setCurrentRow(1);
            piperVoiceBox->setVisible(true);
            return;
        }

        step2.accept();
    });
    connect(buttons2, &QDialogButtonBox::rejected, &step2, &QDialog::reject);

    if (step2.exec() == QDialog::Accepted) {
        for (int i = 0; i < engineList->count(); ++i) {
            auto *item = engineList->item(i);
            if (item->checkState() != Qt::Checked) continue;
            const QString id = item->data(Qt::UserRole).toString();
            if (id == "piper") installPiperRuntimeSilent(this);
            if (id == "edge_online") installEdgeTtsRuntime(this, true);
            if (id == "espeak_ng") installEspeakNgRuntime(this, true);
        }

        for (int i = 0; i < piperVoiceList->count(); ++i) {
            auto *item = piperVoiceList->item(i);
            if (item->checkState() == Qt::Checked) {
                downloadVoiceById(item->data(Qt::UserRole).toString(), this);
            }
        }
    }

    // Step 3: choose default only from installed/available voices.
    QDialog step3(this);
    step3.setWindowTitle(trKey("firstRun.defaultVoiceTitle"));
    step3.resize(820, 540);
    step3.setMinimumSize(760, 480);

    auto *step3Layout = new QVBoxLayout(&step3);
    auto *voiceHint = new QLabel(trKey("firstRun.defaultVoiceInstalledOnly"), &step3);
    voiceHint->setWordWrap(true);
    step3Layout->addWidget(voiceHint);

    auto *voiceList = new QListWidget(&step3);
    voiceList->setObjectName("voiceChoiceList");
    voiceList->setAlternatingRowColors(false);
    voiceList->setUniformItemSizes(false);
    voiceList->setSelectionMode(QAbstractItemView::SingleSelection);
    step3Layout->addWidget(voiceList, 1);

    auto addVoiceItem = [&](const QString &label, const QString &data) {
        auto *item = new QListWidgetItem(label);
        item->setData(Qt::UserRole, data);
        item->setSizeHint(QSize(0, 34));
        voiceList->addItem(item);
        if (voiceList->currentRow() < 0) voiceList->setCurrentItem(item);
    };

    for (const auto &v : VoiceCatalog::native()) addVoiceItem(trKey("engine.native") + " · " + v.name, "native:" + v.id);
    addVoiceItem(trKey("engine.googleOnline") + " · " + trKey("onlineVoice.cs"), "online:cs");
    addVoiceItem(trKey("engine.googleOnline") + " · " + trKey("onlineVoice.en"), "online:en");

    for (const auto &v : VoiceCatalog::downloadable()) {
        if (VoiceCatalog::isDownloaded(v)) addVoiceItem(trKey("engine.piper") + " · " + v.name, "piper:" + v.id);
    }

    if (!settings_.edgeTtsCommand.trimmed().isEmpty() && QFileInfo::exists(settings_.edgeTtsCommand)) {
        addVoiceItem(trKey("engine.edgeOnline") + " · " + trKey("edgeVoice.csMale"), "edge:cs");
        addVoiceItem(trKey("engine.edgeOnline") + " · " + trKey("edgeVoice.enMale"), "edge:en");
    }

#ifdef Q_OS_MAC
    const bool espeakAvailable = QFileInfo::exists("/opt/homebrew/bin/espeak-ng") || QFileInfo::exists("/usr/local/bin/espeak-ng");
#elif defined(Q_OS_WIN)
    const bool espeakAvailable = QFileInfo::exists("C:/Program Files/eSpeak NG/espeak-ng.exe");
#else
    const bool espeakAvailable = true;
#endif
    if (espeakAvailable) {
        addVoiceItem(trKey("engine.espeakNg") + " · " + trKey("espeakVoice.cs"), "espeak:cs");
        addVoiceItem(trKey("engine.espeakNg") + " · " + trKey("espeakVoice.en"), "espeak:en");
    }

    auto *buttons3 = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &step3);
    step3Layout->addWidget(buttons3);
    connect(buttons3, &QDialogButtonBox::accepted, &step3, &QDialog::accept);
    connect(buttons3, &QDialogButtonBox::rejected, &step3, &QDialog::reject);

    if (step3.exec() == QDialog::Accepted) {
        QString chosenVoice;
        if (auto *item = voiceList->currentItem()) {
            chosenVoice = item->data(Qt::UserRole).toString();
        }

        if (chosenVoice.startsWith("native:")) {
            settings_.engine = "native";
            settings_.nativeVoice = chosenVoice.mid(QString("native:").size());
        } else if (chosenVoice.startsWith("piper:")) {
            settings_.engine = "piper";
            const QString voiceId = chosenVoice.mid(QString("piper:").size());
            for (const auto &v : VoiceCatalog::downloadable()) {
                if (v.id == voiceId) settings_.piperModel = VoiceCatalog::modelPath(v);
            }
        } else if (chosenVoice.startsWith("online:")) {
            settings_.engine = "google_online";
            settings_.onlineLanguage = chosenVoice.mid(QString("online:").size());
        } else if (chosenVoice.startsWith("edge:")) {
            settings_.engine = "edge_online";
            settings_.onlineLanguage = chosenVoice.mid(QString("edge:").size());
        } else if (chosenVoice.startsWith("espeak:")) {
            settings_.engine = "espeak_ng";
            settings_.onlineLanguage = chosenVoice.mid(QString("espeak:").size());
        }
    }

    settings_.firstRunDone = true;
    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);

    if (languageChanged) {
        rebuildUiAfterLanguageChange();
    } else {
        refreshFolders();
        refreshPhrases();
        applyTheme();
        status_->setText(trKey("status.firstRunDone"));
    }
}

void MainWindow::showSynthInstallDialog(QWidget *parentWidget)
{
    QDialog dialog(parentWidget ? parentWidget : this);
    dialog.setWindowTitle(trKey("menu.installEngines"));
    dialog.resize(980, 680);
    dialog.setMinimumSize(900, 620);

    auto *layout = new QVBoxLayout(&dialog);
    auto *intro = new QLabel(trKey("installDialog.intro"), &dialog);
    intro->setWordWrap(true);
    layout->addWidget(intro);

    auto *mainSplit = new QHBoxLayout();
    mainSplit->setSpacing(14);

    auto *engineList = new QListWidget(&dialog);
    engineList->setMinimumWidth(330);
    engineList->setMaximumWidth(390);
    engineList->setAlternatingRowColors(true);
    engineList->setSelectionMode(QAbstractItemView::SingleSelection);

    struct InstallEngineRow {
        QString id;
        QString titleKey;
        QString descKey;
        bool defaultChecked;
    };

    QVector<InstallEngineRow> engines = {
        {"piper", "engine.piper", "engineInfo.piper", false},
        {"edge_online", "engine.edgeOnline", "engineInfo.edge", false},
        {"espeak_ng", "engine.espeakNg", "engineInfo.espeak", false}
    };

#ifdef Q_OS_WIN
    engines.push_back({"vc_runtime", "menu.installVcRuntime", "status.installVcRuntimeQuestion", false});
#endif

    for (const auto &row : engines) {
        auto *item = new QListWidgetItem("＋ " + trKey(row.titleKey));
        item->setData(Qt::UserRole, row.id);
        item->setData(Qt::UserRole + 1, row.descKey);
        item->setFlags(item->flags() | Qt::ItemIsUserCheckable | Qt::ItemIsSelectable | Qt::ItemIsEnabled);
        item->setCheckState(row.defaultChecked ? Qt::Checked : Qt::Unchecked);
        engineList->addItem(item);
    }
    engineList->setCurrentRow(0);
    mainSplit->addWidget(engineList);

    auto *right = new QVBoxLayout();

    auto *descriptionBox = new QFrame(&dialog);
    descriptionBox->setObjectName("descriptionCard");
    auto *descriptionLayout = new QVBoxLayout(descriptionBox);
    auto *descriptionTitle = new QLabel(trKey("firstRun.engineDetails"), descriptionBox);
    descriptionTitle->setObjectName("sectionTitle");
    auto *description = new QLabel(descriptionBox);
    description->setWordWrap(true);
    description->setTextFormat(Qt::RichText);
    descriptionLayout->addWidget(descriptionTitle);
    descriptionLayout->addWidget(description);
    right->addWidget(descriptionBox);

    auto *piperVoiceBox = new QGroupBox(trKey("installDialog.piperVoices"), &dialog);
    auto *piperVoiceLayout = new QVBoxLayout(piperVoiceBox);
    auto *piperVoiceList = new QListWidget(piperVoiceBox);
    piperVoiceList->setSelectionMode(QAbstractItemView::NoSelection);
    for (const auto &v : VoiceCatalog::downloadable()) {
        QString label = v.name;
        if (VoiceCatalog::isDownloaded(v)) label += "  ✓";
        auto *item = new QListWidgetItem(label);
        item->setData(Qt::UserRole, v.id);
        item->setFlags(item->flags() | Qt::ItemIsUserCheckable | Qt::ItemIsEnabled);
        item->setCheckState(Qt::Unchecked);
        piperVoiceList->addItem(item);
    }
    piperVoiceLayout->addWidget(piperVoiceList);
    right->addWidget(piperVoiceBox, 1);

    mainSplit->addLayout(right, 1);
    layout->addLayout(mainSplit, 1);

    auto updateDescription = [&]() {
        if (!engineList->currentItem()) return;
        const QString id = engineList->currentItem()->data(Qt::UserRole).toString();
        const QString descKey = engineList->currentItem()->data(Qt::UserRole + 1).toString();

        QString badges;
        if (id == "piper") badges = "<span style='color:#15803d'>✓ Windows 64-bit</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#b45309'>− Windows 32-bit</span>";
        else if (id == "edge_online") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#2563eb'>internet</span> · <span style='color:#7c3aed'>edge-tts</span>";
        else if (id == "espeak_ng") badges = "<span style='color:#15803d'>✓ Windows</span> · <span style='color:#15803d'>✓ macOS</span> · <span style='color:#15803d'>✓ Linux</span> · <span style='color:#b45309'>robotic</span>";
        else if (id == "vc_runtime") badges = "<span style='color:#15803d'>✓ Windows 64-bit</span> · <span style='color:#b45309'>Piper dependency</span>";

        Q_UNUSED(badges);
        description->setText(trKey(descKey));
        piperVoiceBox->setVisible(id == "piper");
    };

    connect(engineList, &QListWidget::currentItemChanged, &dialog, [&] { updateDescription(); });
    updateDescription();

    auto *buttons = new QDialogButtonBox(&dialog);
    auto *install = buttons->addButton(trKey("button.install"), QDialogButtonBox::AcceptRole);
    auto *close = buttons->addButton(QDialogButtonBox::Close);
    Q_UNUSED(install);
    Q_UNUSED(close);
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, [&] {
        bool piperSelected = false;
        bool piperVoiceSelected = false;

        for (int i = 0; i < engineList->count(); ++i) {
            auto *item = engineList->item(i);
            if (item->data(Qt::UserRole).toString() == "piper" && item->checkState() == Qt::Checked) {
                piperSelected = true;
                break;
            }
        }

        for (int i = 0; i < piperVoiceList->count(); ++i) {
            if (piperVoiceList->item(i)->checkState() == Qt::Checked) {
                piperVoiceSelected = true;
                break;
            }
        }

        if (piperSelected && !piperVoiceSelected) {
            QMessageBox::warning(&dialog, trKey("engine.piper"), trKey("firstRun.piperVoiceRequired"));
            engineList->setCurrentRow(0);
            piperVoiceBox->setVisible(true);
            return;
        }

        for (int i = 0; i < engineList->count(); ++i) {
            auto *item = engineList->item(i);
            if (item->checkState() != Qt::Checked) continue;
            const QString id = item->data(Qt::UserRole).toString();
            if (id == "piper") installPiperRuntimeSilent(&dialog);
            else if (id == "edge_online") installEdgeTtsRuntime(&dialog, false);
            else if (id == "espeak_ng") installEspeakNgRuntime(&dialog, false);
#ifdef Q_OS_WIN
            else if (id == "vc_runtime") installVisualCppRuntime(&dialog, false);
#endif
        }

        for (int i = 0; i < piperVoiceList->count(); ++i) {
            auto *item = piperVoiceList->item(i);
            if (item->checkState() == Qt::Checked) {
                downloadVoiceById(item->data(Qt::UserRole).toString(), &dialog);
            }
        }

        QMessageBox::information(&dialog, trKey("menu.installEngines"), trKey("installDialog.done"));
    });
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    dialog.exec();
}

void MainWindow::showDefaultVoiceWizard(QWidget *parentWidget)
{
    QDialog dialog(parentWidget ? parentWidget : this);
    dialog.setWindowTitle(trKey("firstRun.defaultVoiceTitle"));
    dialog.resize(820, 620);
    dialog.setMinimumSize(760, 520);

    auto *layout = new QVBoxLayout(&dialog);

    auto *intro = new QLabel(trKey("firstRun.defaultVoiceIntro"), &dialog);
    intro->setWordWrap(true);
    layout->addWidget(intro);

    auto *engine = new QComboBox(&dialog);
    engine->addItem(trKey("engine.native"), "native");
    engine->addItem(trKey("engine.piper"), "piper");
    engine->addItem(trKey("engine.googleOnline"), "google_online");
    engine->addItem(trKey("engine.edgeOnline"), "edge_online");
    engine->addItem(trKey("engine.espeakNg"), "espeak_ng");
    engine->setCurrentIndex(engine->findData(settings_.engine));
    layout->addWidget(engine);

    auto *voiceList = new QComboBox(&dialog);
    voiceList->setMinimumContentsLength(58);
    voiceList->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    layout->addWidget(voiceList);

    auto *multiLabel = new QLabel(trKey("firstRun.morePiperVoices"), &dialog);
    multiLabel->setWordWrap(true);
    layout->addWidget(multiLabel);

    auto *piperList = new QListWidget(&dialog);
    piperList->setSelectionMode(QAbstractItemView::MultiSelection);
    for (const auto &v : VoiceCatalog::downloadable()) {
        auto *item = new QListWidgetItem(v.name);
        item->setData(Qt::UserRole, v.id);
        item->setCheckState(Qt::Unchecked);
        piperList->addItem(item);
    }
    layout->addWidget(piperList, 1);

    auto refreshVoiceList = [&]() {
        const QString selectedEngine = engine->currentData().toString();
        voiceList->clear();

        if (selectedEngine == "piper") {
            for (const auto &v : VoiceCatalog::downloadable()) {
                QString label = v.name;
                label += VoiceCatalog::isDownloaded(v) ? " ✓" : " ↓";
                voiceList->addItem(label, "piper:" + v.id);
            }
        } else if (selectedEngine == "google_online") {
            voiceList->addItem(trKey("onlineVoice.cs"), "online:cs");
            voiceList->addItem(trKey("onlineVoice.en"), "online:en");
            voiceList->addItem(trKey("onlineVoice.sk"), "online:sk");
            voiceList->addItem(trKey("onlineVoice.de"), "online:de");
            voiceList->addItem(trKey("onlineVoice.pl"), "online:pl");
            voiceList->addItem(trKey("onlineVoice.fr"), "online:fr");
        } else if (selectedEngine == "edge_online") {
            voiceList->addItem(trKey("edgeVoice.csMale"), "edge:cs");
            voiceList->addItem(trKey("edgeVoice.enMale"), "edge:en");
            voiceList->addItem(trKey("edgeVoice.skMale"), "edge:sk");
            voiceList->addItem(trKey("edgeVoice.deMale"), "edge:de");
            voiceList->addItem(trKey("edgeVoice.plMale"), "edge:pl");
            voiceList->addItem(trKey("edgeVoice.frMale"), "edge:fr");
        } else if (selectedEngine == "espeak_ng") {
            voiceList->addItem(trKey("espeakVoice.cs"), "espeak:cs");
            voiceList->addItem(trKey("espeakVoice.en"), "espeak:en");
            voiceList->addItem(trKey("espeakVoice.sk"), "espeak:sk");
            voiceList->addItem(trKey("espeakVoice.de"), "espeak:de");
            voiceList->addItem(trKey("espeakVoice.pl"), "espeak:pl");
            voiceList->addItem(trKey("espeakVoice.fr"), "espeak:fr");
        } else {
            for (const auto &v : VoiceCatalog::native()) {
                voiceList->addItem(v.name, "native:" + v.id);
            }
        }

        const bool isPiper = selectedEngine == "piper";
        multiLabel->setVisible(isPiper);
        piperList->setVisible(isPiper);
    };

    connect(engine, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [&] { refreshVoiceList(); });
    refreshVoiceList();

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    auto *savePresetButton = buttons->addButton(trKey("voicePreset.saveButton"), QDialogButtonBox::ActionRole);
    layout->addWidget(buttons);
    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);
    connect(savePresetButton, &QPushButton::clicked, &dialog, [this] { saveCurrentVoicePreset(); });

    if (dialog.exec() == QDialog::Accepted) {
        const QString data = voiceList->currentData().toString();

        if (data.startsWith("native:")) {
            settings_.engine = "native";
            settings_.nativeVoice = data.mid(QString("native:").size());
        } else if (data.startsWith("piper:")) {
            settings_.engine = "piper";
            configurePiperVoiceById(data.mid(QString("piper:").size()), &dialog, true);
        } else if (data.startsWith("online:")) {
            settings_.engine = "google_online";
            settings_.onlineLanguage = data.mid(QString("online:").size());
        } else if (data.startsWith("edge:")) {
            settings_.engine = "edge_online";
            settings_.onlineLanguage = data.mid(QString("edge:").size());
            if (settings_.edgeTtsCommand.trimmed().isEmpty() || !QFileInfo::exists(settings_.edgeTtsCommand)) {
                installEdgeTtsRuntime(&dialog, true);
            }
        } else if (data.startsWith("espeak:")) {
            settings_.engine = "espeak_ng";
            settings_.onlineLanguage = data.mid(QString("espeak:").size());
        }

        if (engine->currentData().toString() == "piper") {
            for (int i = 0; i < piperList->count(); ++i) {
                auto *item = piperList->item(i);
                if (item->checkState() == Qt::Checked) {
                    const QString voiceId = item->data(Qt::UserRole).toString();
                    downloadVoiceById(voiceId, &dialog);
                }
            }
        }

        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
    }
}

QString MainWindow::currentVoicePresetJson() const
{
    QJsonObject o;
    o["engine"] = settings_.engine;
    o["nativeVoice"] = settings_.nativeVoice;
    o["nativeSpeed"] = settings_.nativeSpeed;
    o["nativePitch"] = settings_.nativePitch;
    o["nativeAmplitude"] = settings_.nativeAmplitude;
    o["outputVolume"] = settings_.outputVolume;
    o["piperModel"] = settings_.piperModel;
    o["piperQuality"] = settings_.piperQuality;
    o["piperLengthScale"] = settings_.piperLengthScale;
    o["piperNoiseScale"] = settings_.piperNoiseScale;
    o["piperNoiseW"] = settings_.piperNoiseW;
    o["onlineLanguage"] = settings_.onlineLanguage;
    o["edgeTtsCommand"] = settings_.edgeTtsCommand;
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

void MainWindow::applyVoicePresetJson(const QString &json)
{
    const QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
    if (o.isEmpty()) return;

    settings_.engine = o.value("engine").toString(settings_.engine);
    settings_.nativeVoice = o.value("nativeVoice").toString(settings_.nativeVoice);
    settings_.nativeSpeed = o.value("nativeSpeed").toInt(settings_.nativeSpeed);
    settings_.nativePitch = o.value("nativePitch").toInt(settings_.nativePitch);
    settings_.nativeAmplitude = o.value("nativeAmplitude").toInt(settings_.nativeAmplitude);
    settings_.outputVolume = o.value("outputVolume").toInt(settings_.outputVolume);
    settings_.piperModel = o.value("piperModel").toString(settings_.piperModel);
    settings_.piperQuality = o.value("piperQuality").toString(settings_.piperQuality);
    settings_.piperLengthScale = o.value("piperLengthScale").toDouble(settings_.piperLengthScale);
    settings_.piperNoiseScale = o.value("piperNoiseScale").toDouble(settings_.piperNoiseScale);
    settings_.piperNoiseW = o.value("piperNoiseW").toDouble(settings_.piperNoiseW);
    settings_.onlineLanguage = o.value("onlineLanguage").toString(settings_.onlineLanguage);
    settings_.edgeTtsCommand = o.value("edgeTtsCommand").toString(settings_.edgeTtsCommand);

    SettingsStore::save(settings_);
    speaker_.setSettings(settings_);

    if (mainVolumeSlider_) mainVolumeSlider_->setValue(settings_.outputVolume);
    if (mainSpeedSlider_) mainSpeedSlider_->setValue(settings_.nativeSpeed);

    status_->setText(trKey("voicePreset.applied"));
}

void MainWindow::saveCurrentVoicePreset()
{
    bool ok = false;
    const QString name = QInputDialog::getText(
        this,
        trKey("voicePreset.saveTitle"),
        trKey("voicePreset.namePrompt"),
        QLineEdit::Normal,
        settings_.activeVoicePreset.isEmpty() ? trKey("voicePreset.defaultName") : settings_.activeVoicePreset,
        &ok
    ).trimmed();

    if (!ok || name.isEmpty()) return;

    const QString value = currentVoicePresetJson();
    const int existing = settings_.voicePresetNames.indexOf(name);
    if (existing >= 0) {
        settings_.voicePresetValues[existing] = value;
    } else {
        settings_.voicePresetNames << name;
        settings_.voicePresetValues << value;
    }

    settings_.activeVoicePreset = name;
    SettingsStore::save(settings_);
    refreshPresetCombo();
    status_->setText(trKey("voicePreset.saved"));
}

void MainWindow::refreshPresetCombo()
{
    if (!presetCombo_) return;

    presetCombo_->blockSignals(true);
    presetCombo_->clear();
    presetCombo_->addItem(trKey("voicePreset.current"), "__current");

    for (int i = 0; i < settings_.voicePresetNames.size() && i < settings_.voicePresetValues.size(); ++i) {
        presetCombo_->addItem(settings_.voicePresetNames[i], settings_.voicePresetValues[i]);
    }

    if (!settings_.activeVoicePreset.isEmpty()) {
        const int index = presetCombo_->findText(settings_.activeVoicePreset);
        if (index >= 0) presetCombo_->setCurrentIndex(index);
    }

    presetCombo_->blockSignals(false);
}

void MainWindow::showVoiceDialog()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("menu.selectVoice"));
    dialog.resize(820, 620);
    dialog.setMinimumSize(760, 540);
    auto *layout = new QVBoxLayout(&dialog);

    auto *hint = new QLabel(trKey("voiceDialog.hint"), &dialog);
    hint->setWordWrap(true);
    layout->addWidget(hint);

    auto *form = new QFormLayout();
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *engine = new QComboBox(&dialog);
    engine->setMinimumContentsLength(30);
    engine->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    engine->addItem(trKey("engine.native"), "native");
    engine->addItem(trKey("engine.piper"), "piper");
    engine->addItem(trKey("engine.googleOnline"), "google_online");
    engine->addItem(trKey("engine.edgeOnline"), "edge_online");
    engine->addItem(trKey("engine.espeakNg"), "espeak_ng");
    engine->setCurrentIndex(engine->findData(settings_.engine));
    form->addRow(trKey("voiceDialog.engine"), engine);

    auto *voiceList = new QComboBox(&dialog);
    voiceList->setMinimumContentsLength(56);
    voiceList->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    form->addRow(trKey("voiceDialog.voice"), voiceList);

    layout->addLayout(form);

    auto *settingsBox = new QGroupBox(trKey("voiceDialog.engineSettings"), &dialog);
    auto *settingsForm = new QFormLayout(settingsBox);
    settingsForm->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *outputVolume = new QSpinBox(settingsBox);
    outputVolume->setRange(0, 100);
    outputVolume->setSuffix("%");
    outputVolume->setValue(settings_.outputVolume);
    settingsForm->addRow(trKey("setting.outputVolume"), outputVolume);

    auto *speed = new QSpinBox(settingsBox);
    speed->setRange(80, 230);
    speed->setValue(settings_.nativeSpeed);
    settingsForm->addRow(trKey("setting.speed"), speed);

    auto *pitchLabel = new QLabel(trKey("setting.pitch"), settingsBox);
    auto *pitch = new QSpinBox(settingsBox);
    pitch->setRange(0, 99);
    pitch->setValue(settings_.nativePitch);
    settingsForm->addRow(pitchLabel, pitch);

    auto *amplitudeLabel = new QLabel(trKey("setting.nativeAmplitude"), settingsBox);
    auto *amplitude = new QSpinBox(settingsBox);
    amplitude->setRange(50, 200);
    amplitude->setValue(settings_.nativeAmplitude);
    settingsForm->addRow(amplitudeLabel, amplitude);

    auto *piperQualityLabel = new QLabel(trKey("setting.piperQuality"), settingsBox);
    auto *piperQuality = new QComboBox(settingsBox);
    piperQuality->addItem(trKey("quality.fast"), "fast");
    piperQuality->addItem(trKey("quality.balanced"), "balanced");
    piperQuality->addItem(trKey("quality.high"), "high");
    int qualityIndex = piperQuality->findData(settings_.piperQuality);
    if (qualityIndex >= 0) piperQuality->setCurrentIndex(qualityIndex);
    settingsForm->addRow(piperQualityLabel, piperQuality);

    auto *edgeCommandLabel = new QLabel(trKey("setting.edgeTtsCommand"), settingsBox);
    auto *edgeCommand = new QLineEdit(settings_.edgeTtsCommand, settingsBox);
    edgeCommand->setPlaceholderText("edge-tts");
    settingsForm->addRow(edgeCommandLabel, edgeCommand);

    layout->addWidget(settingsBox);

    auto refreshVoiceList = [&]() {
        const QString selectedEngine = engine->currentData().toString();
        const QString oldSelection = voiceList->currentData().toString();

        voiceList->blockSignals(true);
        voiceList->clear();

        if (selectedEngine == "piper") {
            for (const auto &v : VoiceCatalog::downloadable()) {
                QString label = v.name;
                label += VoiceCatalog::isDownloaded(v) ? " ✓" : " ↓";
                voiceList->addItem(label, "piper:" + v.id);
            }
        } else if (selectedEngine == "google_online") {
            voiceList->addItem(trKey("onlineVoice.cs"), "online:cs");
            voiceList->addItem(trKey("onlineVoice.en"), "online:en");
            voiceList->addItem(trKey("onlineVoice.sk"), "online:sk");
            voiceList->addItem(trKey("onlineVoice.de"), "online:de");
            voiceList->addItem(trKey("onlineVoice.pl"), "online:pl");
            voiceList->addItem(trKey("onlineVoice.fr"), "online:fr");
        } else if (selectedEngine == "edge_online") {
            voiceList->addItem(trKey("edgeVoice.csMale"), "edge:cs");
            voiceList->addItem(trKey("edgeVoice.enMale"), "edge:en");
            voiceList->addItem(trKey("edgeVoice.skMale"), "edge:sk");
            voiceList->addItem(trKey("edgeVoice.deMale"), "edge:de");
            voiceList->addItem(trKey("edgeVoice.plMale"), "edge:pl");
            voiceList->addItem(trKey("edgeVoice.frMale"), "edge:fr");
        } else if (selectedEngine == "espeak_ng") {
            voiceList->addItem(trKey("espeakVoice.cs"), "espeak:cs");
            voiceList->addItem(trKey("espeakVoice.en"), "espeak:en");
            voiceList->addItem(trKey("espeakVoice.sk"), "espeak:sk");
            voiceList->addItem(trKey("espeakVoice.de"), "espeak:de");
            voiceList->addItem(trKey("espeakVoice.pl"), "espeak:pl");
            voiceList->addItem(trKey("espeakVoice.fr"), "espeak:fr");
        } else {
            for (const auto &v : VoiceCatalog::native()) {
                voiceList->addItem(v.name, "native:" + v.id);
            }
        }

        int preferred = -1;
        if (selectedEngine == "native") preferred = voiceList->findData("native:" + settings_.nativeVoice);
        else if (selectedEngine == "google_online") preferred = voiceList->findData("online:" + settings_.onlineLanguage);
        else if (selectedEngine == "edge_online") preferred = voiceList->findData("edge:" + settings_.onlineLanguage);
        else if (selectedEngine == "espeak_ng") preferred = voiceList->findData("espeak:" + settings_.onlineLanguage);

        const int oldIndex = voiceList->findData(oldSelection);
        if (oldIndex >= 0) voiceList->setCurrentIndex(oldIndex);
        else if (preferred >= 0) voiceList->setCurrentIndex(preferred);

        voiceList->blockSignals(false);
    };

    auto refreshEngineSettingsVisibility = [&]() {
        const QString selectedEngine = engine->currentData().toString();
        const bool nativeLike = selectedEngine == "native" || selectedEngine == "espeak_ng";
        const bool piper = selectedEngine == "piper";
        const bool edge = selectedEngine == "edge_online";

        pitchLabel->setVisible(nativeLike);
        pitch->setVisible(nativeLike);
        amplitudeLabel->setVisible(nativeLike);
        amplitude->setVisible(nativeLike);
        piperQualityLabel->setVisible(piper);
        piperQuality->setVisible(piper);
        edgeCommandLabel->setVisible(edge);
        edgeCommand->setVisible(edge);
    };

    connect(engine, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [&] {
        refreshVoiceList();
        refreshEngineSettingsVisibility();
    });

    refreshVoiceList();
    refreshEngineSettingsVisibility();

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    auto *savePresetButton = buttons->addButton(trKey("voicePreset.saveButton"), QDialogButtonBox::ActionRole);
    layout->addWidget(buttons);

    auto applyDialogVoiceSelection = [&]() {
        const QString data = voiceList->currentData().toString();
        settings_.engine = engine->currentData().toString();
        settings_.outputVolume = outputVolume->value();
        settings_.nativeSpeed = speed->value();
        settings_.nativePitch = pitch->value();
        settings_.nativeAmplitude = amplitude->value();
        settings_.piperQuality = piperQuality->currentData().toString();
        settings_.edgeTtsCommand = edgeCommand->text();

        if (settings_.engine == "piper") {
            settings_.piperLengthScale = qBound(0.55, 150.0 / qMax(1, settings_.nativeSpeed), 1.40);
        }

        if (data.startsWith("native:")) {
            settings_.engine = "native";
            settings_.nativeVoice = data.mid(QString("native:").size());
        } else if (data.startsWith("piper:")) {
            const QString voiceId = data.mid(QString("piper:").size());
            configurePiperVoiceById(voiceId, &dialog, true);
        } else if (data.startsWith("online:")) {
            settings_.engine = "google_online";
            settings_.onlineLanguage = data.mid(QString("online:").size());
        } else if (data.startsWith("edge:")) {
            settings_.engine = "edge_online";
            settings_.onlineLanguage = data.mid(QString("edge:").size());
            if (settings_.edgeTtsCommand.trimmed().isEmpty() || !QFileInfo::exists(settings_.edgeTtsCommand)) {
                installEdgeTtsRuntime(&dialog, true);
            }
        } else if (data.startsWith("espeak:")) {
            settings_.engine = "espeak_ng";
            settings_.onlineLanguage = data.mid(QString("espeak:").size());
        }

        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
        if (mainVolumeSlider_) mainVolumeSlider_->setValue(settings_.outputVolume);
        if (mainSpeedSlider_) mainSpeedSlider_->setValue(settings_.nativeSpeed);
        refreshPresetCombo();
    };

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);
    connect(savePresetButton, &QPushButton::clicked, &dialog, [this, &applyDialogVoiceSelection] {
        applyDialogVoiceSelection();
        saveCurrentVoicePreset();
    });

    if (dialog.exec() == QDialog::Accepted) {
        applyDialogVoiceSelection();
        status_->setText(trKey("status.voiceSaved"));
    }
}

void MainWindow::installPiperRuntime()
{
    if (installPiperRuntimeSilent(this)) {
        QMessageBox::information(this, trKey("dialog.voice"), trKey("status.piperInstalled"));
    }
}

void MainWindow::downloadVoice(const QString &voiceId)
{
    DownloadableVoice voice;
    bool found = false;
    for (const auto &v : VoiceCatalog::downloadable()) {
        if (v.id == voiceId) {
            voice = v;
            found = true;
            break;
        }
    }
    if (!found) return;

    auto *progress = new QProgressDialog(trKey("status.downloading"), trKey("button.cancel"), 0, 100, this);
    progress->setWindowModality(Qt::WindowModal);
    progress->show();

    downloadUrlToFile(QUrl(voice.onnxUrl), VoiceCatalog::modelPath(voice), progress, [=](bool ok) {
        if (!ok) { progress->deleteLater(); return; }
        downloadUrlToFile(QUrl(voice.configUrl), VoiceCatalog::configPath(voice), progress, [=](bool ok2) {
            progress->deleteLater();
            if (ok2) QMessageBox::information(this, trKey("dialog.voice"), trKey("status.downloadDone"));
        });
    });
}

void MainWindow::downloadUrlToFile(const QUrl &url, const QString &target, QProgressDialog *progress, std::function<void(bool)> done)
{
    QNetworkReply *reply = network_.get(QNetworkRequest(url));
    QFile *file = new QFile(target + ".part", reply);

    if (!file->open(QIODevice::WriteOnly)) {
        reply->deleteLater();
        done(false);
        return;
    }

    connect(reply, &QNetworkReply::readyRead, this, [reply, file] { file->write(reply->readAll()); });
    connect(reply, &QNetworkReply::downloadProgress, this, [progress](qint64 received, qint64 total) {
        if (total > 0) progress->setValue(static_cast<int>((received * 100) / total));
    });
    connect(progress, &QProgressDialog::canceled, reply, &QNetworkReply::abort);
    connect(reply, &QNetworkReply::finished, this, [reply, file, target, done] {
        file->write(reply->readAll());
        file->close();

        const bool ok = reply->error() == QNetworkReply::NoError;
        if (ok) {
            QFile::remove(target);
            QFile::rename(target + ".part", target);
        } else {
            QFile::remove(target + ".part");
        }

        reply->deleteLater();
        done(ok);
    });
}

void MainWindow::showSettingsDialog()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.settings"));
    dialog.resize(760, 520);
    dialog.setMinimumSize(700, 460);

    auto *layout = new QVBoxLayout(&dialog);
    auto *tabs = new QTabWidget(&dialog);
    layout->addWidget(tabs, 1);

    auto *generalPage = new QWidget(tabs);
    auto *generalForm = new QFormLayout(generalPage);
    generalForm->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *appearanceMode = new QComboBox(generalPage);
    appearanceMode->setMinimumContentsLength(28);
    appearanceMode->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    appearanceMode->addItem(trKey("appearance.light"), "light");
    appearanceMode->addItem(trKey("appearance.dark"), "dark");
    appearanceMode->setCurrentIndex(settings_.darkMode ? appearanceMode->findData("dark") : appearanceMode->findData("light"));
    generalForm->addRow(trKey("firstRun.appearance"), appearanceMode);

    auto *clearAfter = new QCheckBox(generalPage);
    clearAfter->setChecked(settings_.clearAfterSpeak);
    generalForm->addRow(trKey("setting.clearAfter"), clearAfter);
    tabs->addTab(generalPage, trKey("dialog.settings"));

    auto *voicePage = new QWidget(tabs);
    auto *voiceForm = new QFormLayout(voicePage);
    voiceForm->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *speed = new QSpinBox(voicePage);
    speed->setRange(80, 230);
    speed->setValue(settings_.nativeSpeed);
    voiceForm->addRow(trKey("setting.speed"), speed);

    auto *pitch = new QSpinBox(voicePage);
    pitch->setRange(0, 99);
    pitch->setValue(settings_.nativePitch);
    voiceForm->addRow(trKey("setting.pitch"), pitch);

    auto *amplitude = new QSpinBox(voicePage);
    amplitude->setRange(50, 200);
    amplitude->setValue(settings_.nativeAmplitude);
    voiceForm->addRow(trKey("setting.nativeAmplitude"), amplitude);

    auto *outputVolume = new QSpinBox(voicePage);
    outputVolume->setRange(0, 100);
    outputVolume->setSuffix("%");
    outputVolume->setValue(settings_.outputVolume);
    voiceForm->addRow(trKey("setting.outputVolume"), outputVolume);

    auto *piperQuality = new QComboBox(voicePage);
    piperQuality->addItem(trKey("quality.fast"), "fast");
    piperQuality->addItem(trKey("quality.balanced"), "balanced");
    piperQuality->addItem(trKey("quality.high"), "high");
    int qualityIndex = piperQuality->findData(settings_.piperQuality);
    if (qualityIndex >= 0) piperQuality->setCurrentIndex(qualityIndex);
    voiceForm->addRow(trKey("setting.piperQuality"), piperQuality);
    tabs->addTab(voicePage, trKey("menu.voice"));

    auto *pathsPage = new QWidget(tabs);
    auto *pathsForm = new QFormLayout(pathsPage);
    pathsForm->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *piperBinary = new QLineEdit(settings_.piperBinary, pathsPage);
    pathsForm->addRow(trKey("setting.piperBinary"), piperBinary);

    auto *edgeCommand = new QLineEdit(settings_.edgeTtsCommand, pathsPage);
    edgeCommand->setPlaceholderText("edge-tts");
    pathsForm->addRow(trKey("setting.edgeTtsCommand"), edgeCommand);
    tabs->addTab(pathsPage, trKey("label.paths"));

    connect(appearanceMode, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [this, appearanceMode] {
        settings_.darkMode = appearanceMode->currentData().toString() == "dark";
        applyTheme();
    });

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    if (dialog.exec() == QDialog::Accepted) {
        settings_.darkMode = appearanceMode->currentData().toString() == "dark";
        settings_.clearAfterSpeak = clearAfter->isChecked();
        settings_.nativeSpeed = speed->value();
        settings_.nativePitch = pitch->value();
        settings_.nativeAmplitude = amplitude->value();
        settings_.outputVolume = outputVolume->value();
        settings_.piperQuality = piperQuality->currentData().toString();
        settings_.piperBinary = piperBinary->text();
        settings_.edgeTtsCommand = edgeCommand->text();

        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
        if (mainVolumeSlider_) mainVolumeSlider_->setValue(settings_.outputVolume);
        if (mainSpeedSlider_) mainSpeedSlider_->setValue(settings_.nativeSpeed);
        applyTheme();
        status_->setText(trKey("status.settingsSaved"));
    }
}

void MainWindow::showLanguageDialog()
{
    QStringList languages = {"en", "cs"};
    bool ok = false;
    QString lang = QInputDialog::getItem(this, trKey("menu.language"), trKey("label.language"), languages, languages.indexOf(settings_.language), false, &ok);
    if (!ok || lang.isEmpty()) return;

    settings_.language = lang;
    SettingsStore::save(settings_);
    QMessageBox::information(this, trKey("menu.language"), trKey("status.restartForLanguage"));
}

void MainWindow::importPhrases()
{
    const QString path = QFileDialog::getOpenFileName(this, trKey("menu.import"), QDir::homePath(), "Text/JSON (*.txt *.json);;All files (*)");
    if (path.isEmpty()) return;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    const QString content = QString::fromUtf8(file.readAll());
    const QStringList lines = content.split(QRegularExpression("[\\r\\n]+"), Qt::SkipEmptyParts);

    for (const QString &line : lines) addPhrase(line);
    status_->setText(trKey("status.importDone"));
}

void MainWindow::exportPhrases()
{
    const QString path = QFileDialog::getSaveFileName(this, trKey("menu.export"), QDir::homePath() + "/dosty-speak-phrases.txt", "Text (*.txt)");
    if (path.isEmpty()) return;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return;

    QTextStream out(&file);
    for (const auto &p : phrases_) out << p.text << "\n";

    status_->setText(trKey("status.exportDone"));
}

void MainWindow::showShortcuts()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("menu.shortcuts"));
    dialog.resize(560, 420);

    auto *layout = new QVBoxLayout(&dialog);

    auto *title = new QLabel(trKey("menu.shortcuts"), &dialog);
    title->setObjectName("sectionTitle");
    layout->addWidget(title);

    auto *text = new QPlainTextEdit(&dialog);
    text->setReadOnly(true);
    QString shortcuts = trKey("help.shortcuts");
    shortcuts.replace("\\n", "\n");
    text->setPlainText(shortcuts);
    layout->addWidget(text, 1);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, &dialog);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);
    layout->addWidget(buttons);

    dialog.exec();
}

void MainWindow::showAboutDialog()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.about"));
    dialog.resize(520, 360);

    auto *layout = new QVBoxLayout(&dialog);
    layout->setSpacing(14);

    auto *top = new QHBoxLayout();

    auto *icon = new QLabel(&dialog);
    QPixmap pixmap(AppPaths::resourcePath("icons/dosty-speak.png"));
    if (!pixmap.isNull()) {
        icon->setPixmap(pixmap.scaled(112, 112, Qt::KeepAspectRatio, Qt::SmoothTransformation));
    }
    icon->setFixedSize(124, 124);
    icon->setAlignment(Qt::AlignCenter);
    top->addWidget(icon);

    auto *textBox = new QVBoxLayout();
    auto *name = new QLabel("Dosty Speak", &dialog);
    name->setObjectName("title");
    textBox->addWidget(name);

    auto *about = new QLabel(trKey("about.text").arg(AppInfo::version(), AppInfo::author(), AppInfo::license()), &dialog);
    about->setWordWrap(true);
    about->setTextInteractionFlags(Qt::TextSelectableByMouse);
    textBox->addWidget(about);
    textBox->addStretch(1);

    top->addLayout(textBox, 1);
    layout->addLayout(top);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, &dialog);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);
    layout->addWidget(buttons);

    dialog.exec();
}

void MainWindow::showDiagnosticsDialog()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.diagnostics"));
    dialog.resize(760, 560);

    auto *layout = new QVBoxLayout(&dialog);

    auto *diagnostics = new QTextEdit(&dialog);
    diagnostics->setReadOnly(true);
    diagnostics->setPlainText(AppInfo::diagnosticsText());
    layout->addWidget(diagnostics, 1);

    auto *buttons = new QDialogButtonBox(&dialog);
    auto *copyButton = buttons->addButton(trKey("button.copy"), QDialogButtonBox::ActionRole);
    auto *closeButton = buttons->addButton(trKey("button.close"), QDialogButtonBox::RejectRole);
    layout->addWidget(buttons);

    connect(copyButton, &QPushButton::clicked, &dialog, [diagnostics] {
        QApplication::clipboard()->setText(diagnostics->toPlainText());
    });
    connect(closeButton, &QPushButton::clicked, &dialog, &QDialog::reject);

    dialog.exec();
}


bool MainWindow::focusNextPrevChild(bool next)
{
    Q_UNUSED(next);

    // Keep keyboard focus in the typing field. Tab is used for word completion.
    if (focusWidget() == input_) {
        autocompleteCurrentWord();
        return true;
    }

    return QMainWindow::focusNextPrevChild(next);
}

bool MainWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::FocusIn) {
        if (obj == input_) updateModeStatus("typingLocked");
        if (obj == phraseTree_) updateModeStatus("phrase");
    }

    const bool isFolderDropTarget = (obj == folderList_ || obj == folderList_->viewport());

    if (isFolderDropTarget && event->type() == QEvent::DragEnter) {
        auto *drag = static_cast<QDragEnterEvent*>(event);
        if (selectedPhraseIndex() >= 0) {
            drag->setDropAction(Qt::MoveAction);
            drag->accept();
        }
        return true;
    }

    if (isFolderDropTarget && event->type() == QEvent::DragMove) {
        auto *drag = static_cast<QDragMoveEvent*>(event);
        if (selectedPhraseIndex() >= 0) {
            drag->setDropAction(Qt::MoveAction);
            drag->accept();
        }
        return true;
    }

    if (isFolderDropTarget && event->type() == QEvent::Drop) {
        auto *drop = static_cast<QDropEvent*>(event);

        QPoint pos = drop->position().toPoint();
        if (obj == folderList_) {
            pos = folderList_->viewport()->mapFrom(folderList_, pos);
        }

        QListWidgetItem *item = folderList_->itemAt(pos);
        if (!item) item = folderList_->currentItem();

        const QString folder = item ? item->data(Qt::UserRole).toString() : QString();
        if (!folder.isEmpty()) {
            moveSelectedPhraseToFolderName(folder);
            drop->setDropAction(Qt::MoveAction);
            drop->accept();
        }
        return true;
    }

    if (event->type() != QEvent::KeyPress) return QMainWindow::eventFilter(obj, event);

    auto *key = static_cast<QKeyEvent*>(event);

    if (obj == input_) {
        if (key->key() == Qt::Key_Return || key->key() == Qt::Key_Enter) {
            if (key->modifiers() & Qt::ShiftModifier) addPhrase(input_->text());
            else speakText(input_->text());
            return true;
        }

        if (key->key() == Qt::Key_Tab) {
            autocompleteCurrentWord();
            return true;
        }

        if (key->key() == Qt::Key_Escape) {
            focusPhraseList();
            status_->setText(trKey("status.keyboardUnlocked"));
            return true;
        }

        if (key->key() == Qt::Key_Down) {
            selectAdjacentVisiblePhrase(1);
            return true;
        }

        if (key->key() == Qt::Key_Up) {
            selectAdjacentVisiblePhrase(-1);
            return true;
        }
    }

    if (obj == phraseTree_) {
        if (key->key() == Qt::Key_Delete) {
            deleteSelectedPhrase();
            return true;
        }

        if (key->key() == Qt::Key_Escape || key->key() == Qt::Key_Tab) {
            input_->setFocus();
            input_->setCursorPosition(input_->text().size());
            updateModeStatus("typingLocked");
            return true;
        }

        if (key->key() == Qt::Key_Return || key->key() == Qt::Key_Enter) {
            const int index = selectedPhraseIndex();
            if (index >= 0) {
                loadSelectedPhraseIntoInput();
                speakText(input_->text(), index);
            }
            return true;
        }

        if (key->key() >= Qt::Key_1 && key->key() <= Qt::Key_9 && key->modifiers() == Qt::NoModifier) {
            selectVisiblePhraseNumber(key->key() - Qt::Key_0, false);
            loadSelectedPhraseIntoInput();
            return true;
        }
    }

    if (obj == folderList_) {
        if (key->key() == Qt::Key_Return || key->key() == Qt::Key_Enter || key->key() == Qt::Key_Tab) {
            focusPhraseList();
            return true;
        }
    }

    if ((key->modifiers() & Qt::AltModifier) && key->key() >= Qt::Key_1 && key->key() <= Qt::Key_9) {
        selectVisiblePhraseNumber(key->key() - Qt::Key_0, true);
        return true;
    }

    return QMainWindow::eventFilter(obj, event);
}
