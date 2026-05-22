#include "Speaker.h"
#include "AppPaths.h"

#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTemporaryFile>
#include <QTextStream>
#include <QDir>
#include <QTimer>
#include <QUrlQuery>
#include <QEventLoop>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkAccessManager>

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
    if (settings_.engine == "google_online") return speakGoogleOnline(normalized);
    if (settings_.engine == "espeak_ng") return speakEspeakNg(normalized);
    if (settings_.engine == "edge_online") return speakEdgeOnline(normalized);
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

QString Speaker::speakEspeakNg(const QString &text)
{
    auto *process = new QProcess(this);

#ifdef Q_OS_WIN
#ifdef Q_OS_WIN
    hideProcessWindow(process);
#endif
    QString program = "espeak-ng.exe";
    if (QFileInfo::exists("C:/Program Files/eSpeak NG/espeak-ng.exe")) {
        program = "C:/Program Files/eSpeak NG/espeak-ng.exe";
    }
#elif defined(Q_OS_MAC)
    QString program = "espeak-ng";
    if (QFileInfo::exists("/opt/homebrew/bin/espeak-ng")) program = "/opt/homebrew/bin/espeak-ng";
    else if (QFileInfo::exists("/usr/local/bin/espeak-ng")) program = "/usr/local/bin/espeak-ng";
#else
    QString program = "espeak-ng";
#endif

    QString voice = settings_.onlineLanguage;
    if (voice.isEmpty()) voice = settings_.language == "cs" ? "cs" : "en";

    QStringList args;
    args << "-v" << voice;
    args << "-s" << QString::number(settings_.nativeSpeed);
#ifndef Q_OS_WIN
    args << "-a" << QString::number(settings_.nativeAmplitude);
#endif
    args << text;

    process->start(program, args);
    if (!process->waitForStarted(2000)) {
        process->deleteLater();
        return "status.espeakMissing";
    }

    processes_.push_back(process);
    return {};
}

QString Speaker::speakEdgeOnline(const QString &text)
{
    const QString mp3Path = AppPaths::dataDir() + "/edge-tts-last.mp3";

    QString command = settings_.edgeTtsCommand.trimmed();
    if (command.isEmpty()) command = "edge-tts";

    QString voice;
    const QString lang = settings_.onlineLanguage.isEmpty() ? "cs" : settings_.onlineLanguage;
    if (lang == "cs") voice = "cs-CZ-AntoninNeural";
    else if (lang == "en") voice = "en-US-GuyNeural";
    else if (lang == "sk") voice = "sk-SK-LukasNeural";
    else if (lang == "de") voice = "de-DE-ConradNeural";
    else if (lang == "pl") voice = "pl-PL-MarekNeural";
    else if (lang == "fr") voice = "fr-FR-HenriNeural";
    else voice = "cs-CZ-AntoninNeural";

    const QString textPath = AppPaths::dataDir() + "/edge-tts-input-utf8.txt";
    QFile textFile(textPath);
    if (!textFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) return "status.edgeTtsError";
    textFile.write("\xEF\xBB\xBF");
    textFile.write(text.toUtf8());
    textFile.close();

    QStringList args;
    const QString commandFile = QFileInfo(command).fileName().toLower();
    const bool runAsPythonModule = commandFile == "python.exe" || commandFile == "python" || commandFile == "python3";
    if (runAsPythonModule) {
        args << "-m" << "edge_tts";
    }
    args << "--voice" << voice;
    args << "--file" << textPath;
    args << "--write-media" << mp3Path;

    QProcess edge;
#ifdef Q_OS_WIN
    hideProcessWindow(&edge);
#endif
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONUTF8", "1");
    env.insert("PYTHONIOENCODING", "utf-8");
    edge.setProcessEnvironment(env);

    edge.start(command, args);
    if (!edge.waitForStarted(3000)) return "status.edgeTtsMissing";

    if (!edge.waitForFinished(60000)) {
        edge.kill();
        return "status.edgeTtsTimeout";
    }

    if (edge.exitCode() != 0 || !QFileInfo::exists(mp3Path) || QFileInfo(mp3Path).size() == 0) {
        QFile errFile(AppPaths::dataDir() + "/edge-tts-last-error.txt");
        if (errFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            errFile.write("Command: " + command.toUtf8() + "\n");
            errFile.write("Voice: " + voice.toUtf8() + "\n\nSTDOUT:\n");
            errFile.write(edge.readAllStandardOutput());
            errFile.write("\nSTDERR:\n");
            errFile.write(edge.readAllStandardError());
            errFile.close();
        }
        return "status.edgeTtsError";
    }

    return playMp3(mp3Path);
}

QString Speaker::speakGoogleOnline(const QString &text)
{
    const QString mp3Path = AppPaths::dataDir() + "/google-tts-last.mp3";

    // Unofficial online Google Translate TTS endpoint.
    // This is useful as an optional extra voice, but it requires internet
    // and may change or stop working. Piper/native remain the reliable engines.
    QString ttsText = text;
    if (ttsText.size() > 190) {
        // Google Translate TTS endpoints are not reliable with long texts.
        // Keep the app responsive and avoid failed requests.
        ttsText = ttsText.left(190);
    }

    QUrl url("https://translate.google.com/translate_tts");
    QUrlQuery query;
    query.addQueryItem("ie", "UTF-8");
    query.addQueryItem("client", "tw-ob");
    query.addQueryItem("tl", settings_.onlineLanguage.isEmpty() ? "cs" : settings_.onlineLanguage);
    query.addQueryItem("q", ttsText);
    url.setQuery(query);

    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "Mozilla/5.0");

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    timeout.setInterval(15000);

    QNetworkReply *reply = manager.get(request);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start();
    loop.exec();

    if (!timeout.isActive()) {
        reply->abort();
        reply->deleteLater();
        return "status.onlineTtsTimeout";
    }

    timeout.stop();

    if (reply->error() != QNetworkReply::NoError) {
        QFile errFile(AppPaths::dataDir() + "/online-tts-last-error.txt");
        if (errFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            errFile.write(reply->errorString().toUtf8());
            errFile.close();
        }
        reply->deleteLater();
        return "status.onlineTtsError";
    }

    const QByteArray mp3 = reply->readAll();
    reply->deleteLater();

    if (mp3.isEmpty()) return "status.onlineTtsError";

    QFile out(mp3Path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return "status.onlineTtsError";
    out.write(mp3);
    out.close();

    return playMp3(mp3Path);
}

QString Speaker::speakPiper(const QString &text)
{
    if (!QFileInfo::exists(settings_.piperBinary)) return "status.piperMissing";
    if (!QFileInfo::exists(settings_.piperModel)) return "status.modelMissing";

#ifdef Q_OS_WIN
    // Avoid launching piper.exe when the Microsoft VC++ runtime is missing.
    // Otherwise Windows shows a system DLL error dialog before we can handle it.
    if (!QFileInfo::exists("C:/Windows/System32/VCRUNTIME140.dll") ||
        !QFileInfo::exists("C:/Windows/System32/MSVCP140.dll")) {
        return "status.vcRuntimeMissing";
    }
#endif

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

QString Speaker::playMp3(const QString &path)
{
#ifdef Q_OS_WIN
    auto *process = new QProcess(this);
#ifdef Q_OS_WIN
    hideProcessWindow(process);
#endif
    QString escaped = path;
    escaped.replace("'", "''");

    // Windows 10/11 can be missing or delaying the legacy WMP COM player.
    // Wait until playback really starts; if it never starts, fall back to the
    // .NET/WPF MediaPlayer. This makes Google/Edge online voices much more
    // reliable on Windows LTSC and fresh Windows 11 installs.
    const QString command =
        "$ErrorActionPreference='Stop'; "
        "$p='" + escaped + "'; "
        "$vol=" + QString::number(qBound(0, settings_.outputVolume, 100) / 100.0, 'f', 2) + "; "
        "$played=$false; "
        "try { "
        "  $wmp = New-Object -ComObject WMPlayer.OCX; "
        "  $wmp.URL = $p; "
        "  $wmp.settings.volume = [int]($vol * 100); "
        "  $wmp.controls.play(); "
        "  for ($i=0; $i -lt 60; $i++) { "
        "    Start-Sleep -Milliseconds 100; "
        "    if ($wmp.playState -eq 3) { $played=$true; break } "
        "    if ($wmp.playState -eq 1 -or $wmp.playState -eq 8) { break } "
        "  } "
        "  if ($played) { while ($wmp.playState -ne 1 -and $wmp.playState -ne 8 -and $wmp.playState -ne 10) { Start-Sleep -Milliseconds 100 } } "
        "} catch { } "
        "if (-not $played) { "
        "  Add-Type -AssemblyName PresentationCore; "
        "  $m = New-Object System.Windows.Media.MediaPlayer; "
        "  $m.Open([Uri]$p); $m.Volume = $vol; $m.Play(); "
        "  Start-Sleep -Milliseconds 350; "
        "  $limit = 0; "
        "  while ($limit -lt 1200) { "
        "    Start-Sleep -Milliseconds 100; $limit++; "
        "    if ($m.NaturalDuration.HasTimeSpan -and $m.Position -ge $m.NaturalDuration.TimeSpan) { break } "
        "  } "
        "  $m.Stop(); $m.Close(); "
        "}";

    process->start("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command});
#elif defined(Q_OS_MAC)
    auto *process = new QProcess(this);
    const double volume = qBound(0, settings_.outputVolume, 100) / 100.0;
    process->start("afplay", {"-v", QString::number(volume, 'f', 2), path});
#else
    auto *process = new QProcess(this);

    if (QFileInfo::exists("/usr/bin/ffplay") || QFileInfo::exists("/bin/ffplay")) {
        process->start("ffplay", {"-nodisp", "-autoexit", "-loglevel", "quiet", path});
    } else if (QFileInfo::exists("/usr/bin/mpg123") || QFileInfo::exists("/bin/mpg123")) {
        process->start("mpg123", {"-q", path});
    } else {
        process->deleteLater();
        return "status.mp3PlayerMissing";
    }
#endif

    if (!process->waitForStarted(3000)) {
        process->deleteLater();
        return "status.playerFailed";
    }

    processes_.push_back(process);
    return {};
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
