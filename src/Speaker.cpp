#include "Speaker.h"
#include "AppPaths.h"

#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTemporaryFile>
#include <QTextStream>
#include <QDir>

#ifdef Q_OS_WIN
#include <windows.h>
#endif


#ifdef Q_OS_WIN
static void hideProcessWindow(QProcess *process)
{
    process->setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *args) {
        args->flags |= CREATE_NO_WINDOW;
        args->startupInfo->dwFlags |= STARTF_USESHOWWINDOW;
        args->startupInfo->wShowWindow = SW_HIDE;
    });
}
#endif

Speaker::Speaker(QObject *parent) : QObject(parent), settings_(SettingsStore::load())
{
}

void Speaker::setSettings(const AppSettings &settings)
{
    settings_ = settings;
}

void Speaker::stop()
{
    for (QProcess *p : processes_) {
        if (p && p->state() != QProcess::NotRunning) {
            p->terminate();
            if (!p->waitForFinished(500)) p->kill();
        }
        if (p) p->deleteLater();
    }
    processes_.clear();

#ifndef Q_OS_WIN
    QProcess::execute("pkill", {"-f", "espeak-ng"});
#endif
}

QString Speaker::speak(const QString &text)
{
    const QString normalized = text.simplified();
    if (normalized.isEmpty()) return "status.emptyText";

    stop();

    if (settings_.engine == "piper") return speakPiper(normalized);
    return speakNative(normalized);
}

QString Speaker::speakNative(const QString &text)
{
#ifdef Q_OS_WIN
    // Windows command-line encoding can corrupt Czech diacritics if the text is
    // embedded directly in a PowerShell command. Store the phrase as UTF-8 with
    // BOM, then run PowerShell via -EncodedCommand (UTF-16LE), so both the script
    // and the spoken text are passed without codepage loss.
    const QString textPath = AppPaths::dataDir() + "/native-text-utf8.txt";
    QFile file(textPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return "status.nativeTtsFailed";
    }

    QByteArray utf8WithBom;
    utf8WithBom.append(char(0xEF));
    utf8WithBom.append(char(0xBB));
    utf8WithBom.append(char(0xBF));
    utf8WithBom.append(text.toUtf8());
    file.write(utf8WithBom);
    file.close();

    auto *process = new QProcess(this);

    QString escapedPath = textPath;
    escapedPath.replace("'", "''");

    const QString command =
        "$OutputEncoding = [System.Text.Encoding]::UTF8; "
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        "Add-Type -AssemblyName System.Speech; "
        "$text = [System.IO.File]::ReadAllText('" + escapedPath + "', [System.Text.Encoding]::UTF8); "
        "$text = $text.TrimStart([char]0xFEFF); "
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        "$s.Speak($text);";

    const QByteArray encodedCommand =
        QByteArray(reinterpret_cast<const char*>(command.utf16()), command.size() * 2).toBase64();

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONUTF8", "1");
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);

    process->start("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", QString::fromLatin1(encodedCommand)});
    if (!process->waitForStarted(2000)) {
        process->deleteLater();
        return "status.nativeTtsFailed";
    }
    processes_.push_back(process);
    return {};
#elif defined(Q_OS_MAC)
    auto *process = new QProcess(this);
    QStringList args;
    if (!settings_.nativeVoice.isEmpty() && settings_.nativeVoice != "default") {
        args << "-v" << settings_.nativeVoice;
    }
    args << text;

    process->start("say", args);
    if (!process->waitForStarted(2000)) {
        process->deleteLater();
        return "status.nativeTtsFailed";
    }
    processes_.push_back(process);
    return {};
#else
    auto *process = new QProcess(this);
    const QStringList args = {
        "-v", settings_.nativeVoice,
        "-s", QString::number(settings_.nativeSpeed),
        "-p", QString::number(settings_.nativePitch),
        "-a", QString::number(settings_.nativeAmplitude),
        text
    };

    process->start("espeak-ng", args);
    if (!process->waitForStarted(2000)) {
        process->deleteLater();
        return "status.nativeTtsFailed";
    }
    processes_.push_back(process);
    return {};
#endif
}

QString Speaker::speakPiper(const QString &text)
{
    if (!QFileInfo::exists(settings_.piperBinary)) return "status.piperMissing";
    if (!QFileInfo::exists(settings_.piperModel)) return "status.modelMissing";

    const QString wavPath = AppPaths::dataDir() + "/last.wav";

    const QString inputPath = AppPaths::dataDir() + "/piper-input-utf8.txt";
    QFile inputFile(inputPath);
    if (!inputFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return "status.piperError";
    }

    // Piper expects UTF-8 text. Using a file as stdin is more reliable on
    // Windows than writing through a pipe, especially when the Piper executable
    // is a Python entry point affected by console code pages.
    inputFile.write(text.toUtf8());
    inputFile.write("\n");
    inputFile.close();

    QProcess piper;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONUTF8", "1");
    env.insert("PYTHONIOENCODING", "utf-8");
    env.insert("LC_ALL", "C.UTF-8");
    env.insert("LANG", "C.UTF-8");
    piper.setProcessEnvironment(env);
    piper.setStandardInputFile(inputPath);

    double qualityLengthScale = settings_.piperLengthScale;
    double qualityNoiseScale = settings_.piperNoiseScale;
    double qualityNoiseW = settings_.piperNoiseW;

    if (settings_.piperQuality == "fast") {
        // Faster perceived output: speak slightly quicker and use conservative noise.
        qualityLengthScale = 0.72;
        qualityNoiseScale = 0.20;
        qualityNoiseW = 0.35;
    } else if (settings_.piperQuality == "high") {
        // Better sounding, a little slower/clearer.
        qualityLengthScale = 0.95;
        qualityNoiseScale = 0.45;
        qualityNoiseW = 0.65;
    }

    const QStringList args = {
        "--model", settings_.piperModel,
        "--length-scale", QString::number(qualityLengthScale),
        "--noise-scale", QString::number(qualityNoiseScale),
        "--noise-w", QString::number(qualityNoiseW),
        "--output_file", wavPath
    };

    piper.start(settings_.piperBinary, args);
    if (!piper.waitForStarted(3000)) return "status.piperStartFailed";

    if (!piper.waitForFinished(60000)) {
        piper.kill();
        return "status.piperTimeout";
    }

    if (piper.exitCode() != 0) {
        QFile errFile(AppPaths::dataDir() + "/piper-last-error.txt");
        if (errFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            errFile.write("STDOUT:\n");
            errFile.write(piper.readAllStandardOutput());
            errFile.write("\nSTDERR:\n");
            errFile.write(piper.readAllStandardError());
            errFile.close();
        }
        return "status.piperError";
    }

    if (!QFileInfo::exists(wavPath) || QFileInfo(wavPath).size() == 0) {
        QFile errFile(AppPaths::dataDir() + "/piper-last-error.txt");
        if (errFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            errFile.write("Piper finished, but output WAV is missing or empty.\n");
            errFile.write("Model: " + settings_.piperModel.toUtf8() + "\n");
            errFile.write("Binary: " + settings_.piperBinary.toUtf8() + "\n");
            errFile.close();
        }
        return "status.piperError";
    }

    return playWav(wavPath);
}

QString Speaker::playWav(const QString &path)
{
#ifdef Q_OS_WIN
    auto *process = new QProcess(this);
#ifdef Q_OS_WIN
    hideProcessWindow(process);
#endif
    QString escaped = path;
    escaped.replace("'", "''");

    // Reliability first: System.Media.SoundPlayer is synchronous and works on
    // old Windows installations without WPF/MediaPlayer timing issues.
    //
    // Windows per-file volume for WAV playback is not reliably available through
    // SoundPlayer, so outputVolume is currently applied on macOS/Linux and kept
    // in settings for the planned legacy/audio-backend work. On Windows the
    // system mixer volume is used.
    const QString command =
        "$ErrorActionPreference='Stop'; "
        "$p='" + escaped + "'; "
        "$player = New-Object System.Media.SoundPlayer $p; "
        "$player.Load(); "
        "$player.PlaySync();";

    process->start("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command});
#elif defined(Q_OS_MAC)
    auto *process = new QProcess(this);
    const double volume = qBound(0, settings_.outputVolume, 100) / 100.0;
    process->start("afplay", {"-v", QString::number(volume, 'f', 2), path});
#else
    auto *process = new QProcess(this);
    QString player = settings_.audioPlayer.isEmpty() ? "aplay" : settings_.audioPlayer;
    if (player.contains("paplay")) {
        process->start(player, {"--volume", QString::number(qBound(0, settings_.outputVolume, 100) * 655), path});
    } else {
        // aplay has no reliable per-process volume flag; system mixer volume is used.
        process->start(player, {path});
    }
#endif

    if (!process->waitForStarted(2000)) {
        process->deleteLater();
        return "status.playerFailed";
    }

    processes_.push_back(process);
    return {};
}
