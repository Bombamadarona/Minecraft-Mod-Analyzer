
Write-Host "@@@@@@    @@@@@@      @@@       @@@@@@@@   @@@@@@   @@@@@@@   @@@  @@@     @@@  @@@@@@@  "
Write-Host "@@@@@@@   @@@@@@@      @@@       @@@@@@@@  @@@@@@@@  @@@@@@@@  @@@@ @@@     @@@  @@@@@@@  "
Write-Host "!@@       !@@          @@!       @@!       @@!  @@@  @@!  @@@  @@!@!@@@     @@!    @@!    "
Write-Host "!@!       !@!          !@!       !@!       !@!  @!@  !@!  @!@  !@!!@!@!     !@!    !@!    "
Write-Host "!!@@!!    !!@@!!       @!!       @!!!:!    @!@!@!@!  @!@!!@!   @!@ !!@!     !!@    @!!    "
Write-Host " !!@!!!    !!@!!!      !!!       !!!!!:    !!!@!!!!  !!@!@!    !@!  !!!     !!!    !!!    "
Write-Host "     !:!       !:!     !!:       !!:       !!:  !!!  !!: :!!   !!:  !!!     !!:    !!:    "
Write-Host "    !:!       !:!       :!:      :!:       :!:  !:!  :!:  !:!  :!:  !:!     :!:    :!:    "
Write-Host ":::: ::   :::: ::       :: ::::   :: ::::  ::   :::  ::   :::   ::   ::      ::     ::  "
Write-Host ":: : :    :: : :       : :: : :  : :: ::    :   : :   :   : :  ::    :      :       :"
Write-Host ""
Write-Host "Discord: https://discord.gg/UET6TdxFUk"
Write-Host ""

# Colori e Logs

function Write-Color($Text, [ConsoleColor]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Log-Write($text, $color = 'White') {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $text"
    Write-Color $line $color
    Add-Content -Path $logFile -Value $line
}

function Write-Separator() {
    Log-Write ('-' * 60)
}

function Log-Write-Header($text) {
    Write-Separator
    Log-Write $text 'Cyan'
    Write-Separator
}

# Filtro nomi sospetti

function Is-SuspiciousFile($filePath) {
    $suspiciousKeywords = @(
        "cheat","inject","hack","xray","ghost","wurst","meteor",
        "liquidbounce","impact","future","combat","clicker","op"
    )

    foreach ($keyword in $suspiciousKeywords) {
        if ($filePath -imatch $keyword) { return $true }
    }
    return $false
}

# Analizi .jar 

function Analyze-Mod-Content($modPath) {

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $tmpDir = Join-Path $env:TEMP ("modscan_" + [guid]::NewGuid())
    New-Item -Path $tmpDir -ItemType Directory | Out-Null

    $foundSuspicious = $false
    $details = @()

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($modPath, $tmpDir)

        $classFiles = Get-ChildItem $tmpDir -Recurse -Filter *.class -ErrorAction SilentlyContinue
        if (!$classFiles) {
            return @{ Suspicious=$false; Classes=@() }
        }

        $keywords = @(
            "cheat","hack","xray","inject","aimbot","killaura","bypass","speed",
            "autoarmor","aura","hitbox","ghost","triggerbot","combat","cps",
            "autoclicker","fly","reach","autototem","scaffold","self-destruct"
        )

        foreach ($cf in $classFiles) {

            try {
                $bytes = [System.IO.File]::ReadAllBytes($cf.FullName)
                $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
            } catch { continue }

            $found = @()
            foreach ($k in $keywords) {
                if ($ascii -match $k) { $found += $k }
            }

            if ($found.Count -gt 0) {
                $foundSuspicious = $true
                $rel = $cf.FullName.Substring($tmpDir.Length + 1)

                $details += [PSCustomObject]@{
                    Class    = $rel
                    Keywords = ($found | Sort-Object -Unique)
                }
            }
        }

        return @{
            Suspicious = $foundSuspicious
            Classes    = $details
        }
    }
    catch {
        Log-Write "Errore analizzando $modPath : $($_.Exception.Message)" 'Yellow'
        return $null
    }
    finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Log path

$basePath = $PSScriptRoot
if (!$basePath) { $basePath = (Get-Location).Path }

$logFile = Join-Path $basePath ("Risultati-scan_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Write-Host ""
Write-Host ("-" + ("=" * 58) + "-") -ForegroundColor Cyan
Write-Host "|            MINECRAFT MOD SCANNER - Avvio Analisi         |" -ForegroundColor Cyan
Write-Host ("-" + ("=" * 58) + "-") -ForegroundColor Cyan
Write-Host ""

# Input directory

Log-Write-Header "Analisi manuale cartella mods"

$customModsPath = Read-Host "Inserisci la directory (es: C:\Users\%username%\AppData\Roaming\.minecraft)"

if (!(Test-Path $customModsPath)) {
    Log-Write "La directory non esiste: $customModsPath" 'Red'
    exit
}

Log-Write "Analisi della cartella: $customModsPath" 'Green'

# Scan

$modSegnalate = @{}
$modFiles = Get-ChildItem $customModsPath -Recurse -File -Include *.jar, *.zip -ErrorAction SilentlyContinue

if (!$modFiles) {
    Log-Write "Nessuna mod (.jar o .zip) trovata nella directory." 'Yellow'
}
else {
    foreach ($mod in $modFiles) {

        if ($modSegnalate.ContainsKey($mod.FullName)) { continue }
        $modSegnalate[$mod.FullName] = $true

        $isNameSuspicious = Is-SuspiciousFile $mod.FullName
        $analysis = Analyze-Mod-Content $mod.FullName

        if ($analysis -eq $null) { continue }

        $isContentSuspicious = $analysis.Suspicious

        if ($isNameSuspicious -and $isContentSuspicious) {
            Log-Write ">> MOD SOSPETTA (nome + contenuto): $($mod.FullName)" 'Red'
        }
        elseif ($isNameSuspicious) {
            Log-Write ">> MOD SOSPETTA (nome): $($mod.FullName)" 'Yellow'
        }
        elseif ($isContentSuspicious) {
            Log-Write ">> MOD SOSPETTA (contenuto): $($mod.FullName)" 'Yellow'
        }
        else {
            Log-Write "MOD SAFE: $($mod.FullName)" 'Gray'
        }

        foreach ($cls in $analysis.Classes) {
            Log-Write ("    • {0}  (keywords: {1})" -f $cls.Class, ($cls.Keywords -join ", ")) 'Red'
        }
    }
}

# Fine

Write-Host ""
Write-Host ("-" + ("=" * 58) + "-") -ForegroundColor Cyan
Write-Host "|                       ANALISI COMPLETATA                       |" -ForegroundColor Cyan
Write-Host ("-" + ("=" * 58) + "-") -ForegroundColor Cyan
Write-Host ""

Log-Write "Risultati salvati in: $logFile" 'Green'
