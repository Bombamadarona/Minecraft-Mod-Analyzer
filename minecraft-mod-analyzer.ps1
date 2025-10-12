Write-Output "@@@@@@    @@@@@@      @@@       @@@@@@@@   @@@@@@   @@@@@@@   @@@  @@@     @@@  @@@@@@@  "
Write-Output "@@@@@@@   @@@@@@@      @@@       @@@@@@@@  @@@@@@@@  @@@@@@@@  @@@@ @@@     @@@  @@@@@@@  "
Write-Output "!@@       !@@          @@!       @@!       @@!  @@@  @@!  @@@  @@!@!@@@     @@!    @@!    "
Write-Output "!@!       !@!          !@!       !@!       !@!  @!@  !@!  @!@  !@!!@!@!     !@!    !@!    "
Write-Output "!!@@!!    !!@@!!       @!!       @!!!:!    @!@!@!@!  @!@!!@!   @!@ !!@!     !!@    @!!    "
Write-Output " !!@!!!    !!@!!!      !!!       !!!!!:    !!!@!!!!  !!@!@!    !@!  !!!     !!!    !!!    "
Write-Output "     !:!       !:!     !!:       !!:       !!:  !!!  !!: :!!   !!:  !!!     !!:    !!:    "
Write-Output "    !:!       !:!       :!:      :!:       :!:  !:!  :!:  !:!  :!:  !:!     :!:    :!:    "
Write-Output ":::: ::   :::: ::       :: ::::   :: ::::  ::   :::  ::   :::   ::   ::      ::     ::  "
Write-Output ":: : :    :: : :       : :: : :  : :: ::    :   : :   :   : :  ::    :      :       :"
Write-Output ""
Write-Output "https://discord.gg/UET6TdxFUk"
Write-Output ""

function Write-Color([string]$Text, [ConsoleColor]$Color = 'White') {
    $currentColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Text
    $Host.UI.RawUI.ForegroundColor = $currentColor
}

function Log-Write($text, [ConsoleColor]$color = 'White') {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $text"
    Write-Color $line $color
    Add-Content -Path $logFile -Value $line
}

function Write-Separator() {
    $sep = ('-' * 60)
    Log-Write $sep
}

function Is-SuspiciousFile($filePath) {
    $suspiciousKeywords = @(
        "cheat", "inject", "hack", "xray", "ghost", "wurst", "meteor", "liquidbounce", "impact", "future"
    )
    foreach ($keyword in $suspiciousKeywords) {
        if ($filePath -imatch $keyword) {
            return $true
        }
    }
    return $false
}

function Analyze-Mod-Content($modPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmpDir = Join-Path $env:TEMP ("modscan_" + [guid]::NewGuid())
    New-Item -Path $tmpDir -ItemType Directory | Out-Null

    $hasSuspicious = $false
    $classesDetails = @()

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($modPath, $tmpDir)
        $classFiles = Get-ChildItem $tmpDir -Recurse -Filter *.class -ErrorAction SilentlyContinue
        if (-not $classFiles) {
            return @{
                Suspicious = $false
                Obfuscated = $false
                Classes = $classesDetails
            }
        }

        $suspiciousVars = @("cheat", "hack", "xray", "inject", "aimbot", "killaura", "bypass", "ghost", "triggerbot", "reach", "autototem", "scaffold", "self-destruct")

        foreach ($classFile in $classFiles) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($classFile.FullName)
                $raw = -join ($bytes | ForEach-Object {[char]$_})
            } catch {
                continue
            }

            $matches = Select-String -InputObject $raw -Pattern '[\w]{4,}' -AllMatches | ForEach-Object { $_.Matches.Value }

            $foundKeywords = @()
            foreach ($word in $suspiciousVars) {
                if ($matches -match $word) {
                    $foundKeywords += $word
                }
            }

            if ($foundKeywords.Count -gt 0) {
                $hasSuspicious = $true
                $relPath = $classFile.FullName.Substring($tmpDir.Length + 1)
                $classesDetails += [PSCustomObject]@{
                    Class = $relPath
                    Keywords = ($foundKeywords | Sort-Object -Unique)
                }
            }
        }

        return @{
            Suspicious = $hasSuspicious
            Obfuscated = $false
            Classes = $classesDetails
        }
    } catch {
        Log-Write "Impossibile analizzare il contenuto di ${modPath}: $($_.Exception.Message)" 'Yellow'
        return $null
    } finally {
        try { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}

if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne '') {
    $basePath = $PSScriptRoot
} else {
    $basePath = (Get-Location).Path
}

$logFile = Join-Path -Path $basePath -ChildPath ("Risultati-scan_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Write-Host ""
Write-Host "-" + ("=" * 58) + "-" -ForegroundColor Cyan
Write-Host "|              MINECRAFT MOD SCANNER - Avvio Analisi             |" -ForegroundColor Cyan
Write-Host "-" + ("=" * 58) + "-" -ForegroundColor Cyan
Write-Host ""

function Log-Write-Header($text) {
    Write-Separator
    Log-Write $text 'Cyan'
    Write-Separator
}

Log-Write-Header "Analisi manuale cartella mods"

$customModsPath = Read-Host "Inserisci il percorso completo della cartella mods da analizzare (es. C:\Users\utente\Desktop\mods)"

if (-not (Test-Path $customModsPath)) {
    Log-Write "La directory specificata non esiste: $customModsPath" 'Red'
    exit
}

Log-Write "Analisi della cartella: $customModsPath" 'Green'

$modSegnalate = @{}

$modFiles = Get-ChildItem $customModsPath -Recurse -File -Include *.jar,*.zip -ErrorAction SilentlyContinue

if ($modFiles.Count -eq 0) {
    Log-Write "Nessuna mod (.jar o .zip) trovata nella directory." 'Yellow'
} else {
    foreach ($mod in $modFiles) {
        if (-not $modSegnalate.ContainsKey($mod.FullName)) {
            $modSegnalate[$mod.FullName] = $true

            $isNameSuspicious = Is-SuspiciousFile $mod.FullName
            $analysis = Analyze-Mod-Content $mod.FullName
            if ($analysis -eq $null) {
                continue
            }

            $isContentSuspicious = $analysis.Suspicious
            $classesSuspette = $analysis.Classes

            if ($isNameSuspicious -and $isContentSuspicious) {
                Log-Write ">> MOD SOSPETTA (nome + contenuto): $($mod.FullName)" 'Red'
            } elseif ($isNameSuspicious) {
                Log-Write ">> MOD SOSPETTA (nome): $($mod.FullName)" 'Yellow'
            } elseif ($isContentSuspicious) {
                Log-Write ">> MOD SOSPETTA (contenuto): $($mod.FullName)" 'Yellow'
            } else {
                Log-Write "MOD SAFE: $($mod.FullName)" 'Gray'
            }

            if ($isContentSuspicious -and $classesSuspette.Count -gt 0) {
                Log-Write ">>> Classi sospette trovate nella mod:" 'Red'
                foreach ($detail in $classesSuspette) {
                    Log-Write ("     • {0} (trovato: {1})" -f $detail.Class, ($detail.Keywords -join ", ")) 'Red'
                }
            }
        }
    }
}

Write-Host ""
Write-Host "-" + ("=" * 58) + "-" -ForegroundColor Cyan
Write-Host "|                       ANALISI COMPLETATA                       |" -ForegroundColor Cyan
Write-Host "-" + ("=" * 58) + "-" -ForegroundColor Cyan
Write-Host ""

Log-Write "Risultati salvati in: $logFile" 'Green'
