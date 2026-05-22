# Dosty Speak - Windows release build GUI
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-gui.ps1
#
# Lets you choose supported Windows release artifacts.

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ProjectDir = (Resolve-Path ".").Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Dosty Speak - Windows Release Builder"
$form.Size = New-Object System.Drawing.Size(500, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Dosty Speak release build"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 14)
$title.Size = New-Object System.Drawing.Size(450, 28)
$form.Controls.Add($title)

$archGroup = New-Object System.Windows.Forms.GroupBox
$archGroup.Text = "Architecture"
$archGroup.Location = New-Object System.Drawing.Point(16, 52)
$archGroup.Size = New-Object System.Drawing.Size(220, 126)
$form.Controls.Add($archGroup)

$archAmd64 = New-Object System.Windows.Forms.CheckBox
$archAmd64.Text = "amd64 / x86_64 (recommended)"
$archAmd64.Checked = $true
$archAmd64.Location = New-Object System.Drawing.Point(14, 26)
$archAmd64.Size = New-Object System.Drawing.Size(200, 24)
$archGroup.Controls.Add($archAmd64)

$archX86 = New-Object System.Windows.Forms.CheckBox
$archX86.Text = "x86 / 32-bit legacy Win32"
$archX86.Location = New-Object System.Drawing.Point(14, 54)
$archX86.Size = New-Object System.Drawing.Size(200, 24)
$archGroup.Controls.Add($archX86)

$archArm64 = New-Object System.Windows.Forms.CheckBox
$archArm64.Text = "arm64 (Windows ARM only)"
$archArm64.Location = New-Object System.Drawing.Point(14, 82)
$archArm64.Size = New-Object System.Drawing.Size(200, 24)
$archGroup.Controls.Add($archArm64)

$outGroup = New-Object System.Windows.Forms.GroupBox
$outGroup.Text = "Artifacts"
$outGroup.Location = New-Object System.Drawing.Point(256, 52)
$outGroup.Size = New-Object System.Drawing.Size(210, 126)
$form.Controls.Add($outGroup)

$outInstaller = New-Object System.Windows.Forms.CheckBox
$outInstaller.Text = "Installer EXE"
$outInstaller.Checked = $true
$outInstaller.Location = New-Object System.Drawing.Point(14, 30)
$outInstaller.Size = New-Object System.Drawing.Size(170, 24)
$outGroup.Controls.Add($outInstaller)

$outPortable = New-Object System.Windows.Forms.CheckBox
$outPortable.Text = "Portable ZIP"
$outPortable.Checked = $true
$outPortable.Location = New-Object System.Drawing.Point(14, 64)
$outPortable.Size = New-Object System.Drawing.Size(170, 24)
$outGroup.Controls.Add($outPortable)

$note = New-Object System.Windows.Forms.Label
$note.Text = "amd64 builds the main Qt app. x86 builds the lightweight legacy Win32 app. arm64 requires Windows ARM64."
$note.Location = New-Object System.Drawing.Point(16, 190)
$note.Size = New-Object System.Drawing.Size(450, 42)
$form.Controls.Add($note)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(16, 234)
$logBox.Size = New-Object System.Drawing.Size(450, 42)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.Text = "Ready."
$form.Controls.Add($logBox)

$ok = New-Object System.Windows.Forms.Button
$ok.Text = "Build"
$ok.Location = New-Object System.Drawing.Point(290, 288)
$ok.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($ok)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = "Cancel"
$cancel.Location = New-Object System.Drawing.Point(386, 288)
$cancel.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($cancel)

$cancel.Add_Click({ $form.Close() })

$ok.Add_Click({
    if (-not ($archAmd64.Checked -or $archX86.Checked -or $archArm64.Checked)) {
        [System.Windows.Forms.MessageBox]::Show("Choose at least one architecture.", "Dosty Speak")
        return
    }

    if (-not ($outInstaller.Checked -or $outPortable.Checked)) {
        [System.Windows.Forms.MessageBox]::Show("Choose installer, portable ZIP, or both.", "Dosty Speak")
        return
    }

    if ($archArm64.Checked -and $outInstaller.Checked) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "arm64 installer is not production-ready here. x86 uses Qt 5 and can build installer/portable. Continue?",
            "Dosty Speak",
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::OK) { return }
    }

    $form.Enabled = $false
    $logBox.Text = "Building... PowerShell window will show detailed output."
    $form.Refresh()

    try {
        if ($archAmd64.Checked) {
            $args = @("-Arch", "amd64")
            if ($outInstaller.Checked) { $args += "-Installer" }
            if ($outPortable.Checked) { $args += "-Portable" }
            powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") @args
        }

        if ($archX86.Checked) {
            powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") -Arch x86 -Portable
        }

        if ($archArm64.Checked) {
            powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") -Arch arm64 -Portable
        }

        [System.Windows.Forms.MessageBox]::Show("Build finished. Check the dist folder.", "Dosty Speak")
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Build failed")
        $form.Enabled = $true
    }
})

[void]$form.ShowDialog()
