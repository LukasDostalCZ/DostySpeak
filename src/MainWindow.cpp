#include "MainWindow.h"

#include "AppPaths.h"
#include "AppInfo.h"
#include "I18n.h"
#include "VoiceCatalog.h"

#include <QApplication>
#include <QAbstractItemView>
#include <QCheckBox>
#include <QToolTip>
#include <QCoreApplication>
#include <QTextEdit>
#include <QClipboard>
#include <QDateTime>
#include <QDialog>
#include <QDialogButtonBox>
#include <QDir>
#include <QTimer>
#include <QDropEvent>
#include <QDragEnterEvent>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QKeyEvent>
#include <QListWidget>
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
#include <QSpinBox>
#include <QSlider>
#include <QSplitter>
#include <QTextStream>
#include <QVBoxLayout>
#include <QUuid>

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

    auto *quickControls = new QHBoxLayout();
    quickControls->setSpacing(10);

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

    connect(speakButton, &QPushButton::clicked, this, [this] { speakText(input_->text()); });
    connect(saveButton, &QPushButton::clicked, this, [this] { addPhrase(input_->text()); });
    connect(stopButton, &QPushButton::clicked, &speaker_, &Speaker::stop);

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
    voice->addAction(trKey("menu.installPiper"), this, &MainWindow::installPiperRuntime);
    voice->addAction(trKey("menu.voiceSettings"), this, &MainWindow::showSettingsDialog);

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
            QLineEdit, QTreeWidget, QListWidget, QPlainTextEdit, QSpinBox, QComboBox {
                background: #111318; color: #f3f4f6; border: 1px solid #343b47; border-radius: 8px; padding: 8px;
            }
            QPushButton { background: #2b3240; color: #f3f4f6; border: 1px solid #414a5a; border-radius: 8px; padding: 8px 12px; }
            QPushButton:hover { background: #354052; }
            QHeaderView::section { background: #20242c; color: #f3f4f6; padding: 8px; border: none; }
            QTreeWidget::item:selected, QListWidget::item:selected { background: #33415c; }
            QLabel#title { font-size: 22pt; font-weight: 700; }
            QLabel#hint, QLabel#status { color: #b5bdc9; }
            QLabel#sectionTitle { font-size: 14pt; font-weight: 700; }
        )";
    } else {
        style = R"(
            QWidget { background: #eef1f6; color: #111827; font-size: 11pt; }
            QMenuBar, QMenu { background: #ffffff; color: #111827; }
            QLineEdit, QTreeWidget, QListWidget, QPlainTextEdit, QSpinBox, QComboBox {
                background: #ffffff; color: #111827; border: 1px solid #d5dbe7; border-radius: 8px; padding: 8px;
            }
            QPushButton { background: #ffffff; color: #111827; border: 1px solid #d5dbe7; border-radius: 8px; padding: 8px 12px; }
            QPushButton:hover { background: #f4f7fb; }
            QHeaderView::section { background: #f8fafc; color: #111827; padding: 8px; border: none; }
            QTreeWidget::item:selected, QListWidget::item:selected { background: #dbe8ff; }
            QLabel#title { font-size: 22pt; font-weight: 700; }
            QLabel#hint, QLabel#status { color: #586174; }
            QLabel#sectionTitle { font-size: 14pt; font-weight: 700; }
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
    // On Windows we avoid relying on system Python. Dosty Speak installs its
    // own bundled official Python into app data and installs piper-tts there.
    const QString pythonDir = AppPaths::dataDir() + "/python-embed";
    const QString pythonExe = pythonDir + "/python.exe";
    const QString scriptsDir = pythonDir + "/Scripts";
    const QString embeddedPiper = scriptsDir + "/piper.exe";

    if (QFileInfo::exists(embeddedPiper)) {
        settings_.piperBinary = embeddedPiper;
        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
        return true;
    }

    QDir().mkpath(pythonDir);
    QDir().mkpath(scriptsDir);

    const QString zipPath = AppPaths::dataDir() + "/python-embed.zip";
    const QString getPipPath = pythonDir + "/get-pip.py";
    const QString pythonZipUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip";
    const QString getPipUrl = "https://bootstrap.pypa.io/get-pip.py";

    auto runPowerShell = [&](const QString &command, const QString &label) -> bool {
        return run("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command}, label);
    };

    if (!QFileInfo::exists(pythonExe)) {
        if (!runPowerShell("Invoke-WebRequest -Uri '" + pythonZipUrl + "' -OutFile '" + zipPath + "'", trKey("status.downloadingEmbeddedPython"))) return false;
        if (!runPowerShell("Expand-Archive -Force -Path '" + zipPath + "' -DestinationPath '" + pythonDir + "'", trKey("status.extractingEmbeddedPython"))) return false;

        // Enable site-packages in Python embeddable distribution.
        QString pthPath = pythonDir + "/python311._pth";
        if (!QFileInfo::exists(pthPath)) {
            // Future-proof fallback: find whatever pythonXY._pth exists.
            const QStringList pthFiles = QDir(pythonDir).entryList(QStringList() << "python*._pth", QDir::Files);
            if (!pthFiles.isEmpty()) pthPath = pythonDir + "/" + pthFiles.first();
        }

        QFile pthFile(pthPath);
        if (pthFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString pth = QString::fromUtf8(pthFile.readAll());
            pthFile.close();

            pth.replace("#import site", "import site");
            if (!pth.contains("import site")) pth += "\nimport site\n";

            if (pthFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                pthFile.write(pth.toUtf8());
                pthFile.close();
            }
        }
    }

    if (!QFileInfo::exists(getPipPath)) {
        if (!runPowerShell("Invoke-WebRequest -Uri '" + getPipUrl + "' -OutFile '" + getPipPath + "'", trKey("status.downloadingPipBootstrap"))) return false;
    }

    // Bootstrap pip and install Piper into the bundled official Python.
    if (!run(pythonExe, {getPipPath}, trKey("status.installingPipBootstrap"))) return false;
    if (!run(pythonExe, {"-m", "pip", "install", "--upgrade", "pip"}, trKey("status.upgradingPip"))) return false;
    if (!run(pythonExe, {"-m", "pip", "install", "--upgrade", "piper-tts"}, trKey("status.installingPiperPackage"))) return false;

    if (!QFileInfo::exists(embeddedPiper)) {
        QMessageBox::warning(parentWidget ? parentWidget : this, trKey("dialog.voice"), trKey("status.piperExeMissing"));
        return false;
    }

    settings_.piperBinary = embeddedPiper;
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
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.firstRun"));
    dialog.resize(760, 500);
    dialog.setMinimumSize(720, 460);

    auto *layout = new QVBoxLayout(&dialog);
    layout->setSpacing(14);

    auto *intro = new QLabel(trKey("firstRun.intro"), &dialog);
    intro->setWordWrap(true);
    layout->addWidget(intro);

    auto *form = new QFormLayout();
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *language = new QComboBox(&dialog);
    language->setMinimumContentsLength(24);
    language->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    language->addItem("English", "en");
    language->addItem("Čeština", "cs");
    int langIndex = language->findData(settings_.language);
    if (langIndex >= 0) language->setCurrentIndex(langIndex);
    form->addRow(trKey("firstRun.language"), language);

    auto *voice = new QComboBox(&dialog);
    voice->setMinimumContentsLength(46);
    voice->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    voice->addItem(trKey("voice.nativeDefault"), "native");
    voice->addItem(trKey("voice.piperCzech"), "piper:cs_CZ-jirka-medium");
    voice->addItem(trKey("voice.piperEnglish"), "piper:en_US-amy-medium");
    form->addRow(trKey("firstRun.voice"), voice);

    auto *appearance = new QComboBox(&dialog);
    appearance->setMinimumContentsLength(32);
    appearance->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    appearance->addItem(trKey("appearance.system"), "system");
    appearance->addItem(trKey("appearance.light"), "light");
    appearance->addItem(trKey("appearance.dark"), "dark");
    appearance->setCurrentIndex(settings_.darkMode ? appearance->findData("dark") : appearance->findData("system"));
    form->addRow(trKey("firstRun.appearance"), appearance);

    connect(appearance, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [this, appearance] {
        const QString value = appearance->currentData().toString();
        if (value == "dark") {
            settings_.darkMode = true;
            applyTheme();
        } else if (value == "light") {
            settings_.darkMode = false;
            applyTheme();
        } else {
            // System/default means keep the automatically detected value.
            applyTheme();
        }
    });

    layout->addLayout(form);

    auto *hint = new QLabel(trKey("firstRun.nativeHint"), &dialog);
    hint->setWordWrap(true);
    layout->addWidget(hint);

    auto *buttons = new QDialogButtonBox(&dialog);
    auto *finish = buttons->addButton(trKey("firstRun.finish"), QDialogButtonBox::AcceptRole);
    auto *skip = buttons->addButton(trKey("firstRun.skip"), QDialogButtonBox::RejectRole);
    layout->addWidget(buttons);

    connect(finish, &QPushButton::clicked, &dialog, &QDialog::accept);
    connect(skip, &QPushButton::clicked, &dialog, &QDialog::reject);

    if (dialog.exec() == QDialog::Accepted) {
        const QString chosenLanguage = language->currentData().toString();
        const QString voiceChoice = voice->currentData().toString();
        const QString appearanceChoice = appearance->currentData().toString();

        const bool languageChanged = settings_.language != chosenLanguage;
        settings_.language = chosenLanguage;
        if (appearanceChoice == "dark") settings_.darkMode = true;
        if (appearanceChoice == "light") settings_.darkMode = false;
        settings_.firstRunDone = true;

        if (voiceChoice == "native") {
            settings_.engine = "native";
            SettingsStore::save(settings_);
            speaker_.setSettings(settings_);
        } else if (voiceChoice.startsWith("piper:")) {
            const QString voiceId = voiceChoice.mid(QString("piper:").size());

            if (QMessageBox::question(
                    this,
                    trKey("firstRun.piperInstallTitle"),
                    trKey("firstRun.piperInstallAsk")
                ) == QMessageBox::Yes) {
                SettingsStore::save(settings_);
                configurePiperVoiceById(voiceId, this, true);
            } else {
                configurePiperVoiceById(voiceId, this, false);
            }
        } else {
            SettingsStore::save(settings_);
            speaker_.setSettings(settings_);
        }

        if (languageChanged) {
            rebuildUiAfterLanguageChange();
        } else {
            applyTheme();
            status_->setText(trKey("status.firstRunDone"));
        }
    } else {
        settings_.firstRunDone = true;
        SettingsStore::save(settings_);
    }
}

void MainWindow::showVoiceDialog()
{
    QDialog dialog(this);
    dialog.setWindowTitle(trKey("dialog.voice"));
    dialog.resize(760, 460);
    dialog.setMinimumSize(720, 400);
    auto *layout = new QVBoxLayout(&dialog);

    auto *engine = new QComboBox(&dialog);
    engine->setMinimumContentsLength(30);
    engine->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    engine->addItem(trKey("engine.native"), "native");
    engine->addItem(trKey("engine.piper"), "piper");
    engine->setCurrentIndex(engine->findData(settings_.engine));
    layout->addWidget(engine);

    auto *voiceList = new QComboBox(&dialog);
    voiceList->setMinimumContentsLength(56);
    voiceList->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    layout->addWidget(voiceList);

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

            if (!settings_.piperModel.isEmpty()) {
                const QString modelFile = QFileInfo(settings_.piperModel).completeBaseName();
                for (int i = 0; i < voiceList->count(); ++i) {
                    if (voiceList->itemData(i).toString().contains(modelFile)) {
                        voiceList->setCurrentIndex(i);
                        break;
                    }
                }
            }
        } else {
            for (const auto &v : VoiceCatalog::native()) {
                voiceList->addItem(v.name, "native:" + v.id);
            }

            const int currentNative = voiceList->findData("native:" + settings_.nativeVoice);
            if (currentNative >= 0) voiceList->setCurrentIndex(currentNative);
        }

        const int oldIndex = voiceList->findData(oldSelection);
        if (oldIndex >= 0) voiceList->setCurrentIndex(oldIndex);

        voiceList->blockSignals(false);
    };

    refreshVoiceList();

    auto *download = new QPushButton(trKey("button.downloadVoice"), &dialog);
    layout->addWidget(download);

    auto *installPiper = new QPushButton(trKey("button.installPiper"), &dialog);
    layout->addWidget(installPiper);

    connect(engine, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [&] {
        refreshVoiceList();
        const bool isPiper = engine->currentData().toString() == "piper";
        download->setEnabled(isPiper);
        installPiper->setEnabled(isPiper);
    });

    const bool isInitialPiper = engine->currentData().toString() == "piper";
    download->setEnabled(isInitialPiper);
    installPiper->setEnabled(isInitialPiper);

    connect(download, &QPushButton::clicked, &dialog, [&] {
        const QString data = voiceList->currentData().toString();
        if (data.startsWith("piper:")) {
            engine->setCurrentIndex(engine->findData("piper"));
            configurePiperVoiceById(data.mid(QString("piper:").size()), &dialog, true);
            refreshVoiceList();
        }
    });
    connect(installPiper, &QPushButton::clicked, &dialog, [&] { installPiperRuntime(); });

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    if (dialog.exec() == QDialog::Accepted) {
        const QString data = voiceList->currentData().toString();
        settings_.engine = engine->currentData().toString();

        if (data.startsWith("native:")) {
            settings_.engine = "native";
            settings_.nativeVoice = data.mid(QString("native:").size());
        } else if (data.startsWith("piper:")) {
            const QString voiceId = data.mid(QString("piper:").size());
            configurePiperVoiceById(voiceId, &dialog, true);
        }

        SettingsStore::save(settings_);
        speaker_.setSettings(settings_);
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
    dialog.resize(720, 420);
    dialog.setMinimumSize(680, 360);
    auto *form = new QFormLayout(&dialog);
    form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);

    auto *appearanceMode = new QComboBox(&dialog);
    appearanceMode->setMinimumContentsLength(28);
    appearanceMode->setSizeAdjustPolicy(QComboBox::AdjustToContents);
    appearanceMode->addItem(trKey("appearance.light"), "light");
    appearanceMode->addItem(trKey("appearance.dark"), "dark");
    appearanceMode->setCurrentIndex(settings_.darkMode ? appearanceMode->findData("dark") : appearanceMode->findData("light"));
    form->addRow(trKey("firstRun.appearance"), appearanceMode);

    connect(appearanceMode, QOverload<int>::of(&QComboBox::currentIndexChanged), &dialog, [this, appearanceMode] {
        settings_.darkMode = appearanceMode->currentData().toString() == "dark";
        applyTheme();
    });

    auto *clearAfter = new QCheckBox(&dialog);
    clearAfter->setChecked(settings_.clearAfterSpeak);
    form->addRow(trKey("setting.clearAfter"), clearAfter);

    auto *speed = new QSpinBox(&dialog);
    speed->setRange(80, 230);
    speed->setValue(settings_.nativeSpeed);
    form->addRow(trKey("setting.speed"), speed);

    auto *pitch = new QSpinBox(&dialog);
    pitch->setRange(0, 99);
    pitch->setValue(settings_.nativePitch);
    form->addRow(trKey("setting.pitch"), pitch);

    auto *amplitude = new QSpinBox(&dialog);
    amplitude->setRange(50, 200);
    amplitude->setValue(settings_.nativeAmplitude);
    form->addRow(trKey("setting.nativeAmplitude"), amplitude);

    auto *outputVolume = new QSpinBox(&dialog);
    outputVolume->setRange(0, 100);
    outputVolume->setSuffix("%");
    outputVolume->setValue(settings_.outputVolume);
    form->addRow(trKey("setting.outputVolume"), outputVolume);

    auto *piperQuality = new QComboBox(&dialog);
    piperQuality->addItem(trKey("quality.fast"), "fast");
    piperQuality->addItem(trKey("quality.balanced"), "balanced");
    piperQuality->addItem(trKey("quality.high"), "high");
    int qualityIndex = piperQuality->findData(settings_.piperQuality);
    if (qualityIndex >= 0) piperQuality->setCurrentIndex(qualityIndex);
    form->addRow(trKey("setting.piperQuality"), piperQuality);

    auto *piperBinary = new QLineEdit(settings_.piperBinary, &dialog);
    form->addRow(trKey("setting.piperBinary"), piperBinary);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, &dialog);
    form->addRow(buttons);

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
    text->setPlainText(trKey("help.shortcuts"));
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
    QWidget *fw = focusWidget();

    if (fw == input_) {
        focusPhraseList();
        return true;
    }

    if (fw == phraseTree_) {
        input_->setFocus();
        input_->selectAll();
        updateModeStatus("typing");
        return true;
    }

    return QMainWindow::focusNextPrevChild(next);
}

bool MainWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::FocusIn) {
        if (obj == input_) updateModeStatus("typing");
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
            focusPhraseList();
            return true;
        }
    }

    if (obj == phraseTree_) {
        if (key->key() == Qt::Key_Delete) {
            deleteSelectedPhrase();
            return true;
        }

        if (key->key() == Qt::Key_Tab) {
            input_->setFocus();
            input_->selectAll();
            updateModeStatus("typing");
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
