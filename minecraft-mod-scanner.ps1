
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

        $suspiciousVars = @("cheat", "hack", "xray", "inject", "aimbot", "killaura", "bypass", "ghost", "triggerbot")

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
$logFile = Join-Path -Path $basePath -ChildPath ("scan_results_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Write-Host ""
Write-Host "╔" + ("═" * 58) + "╗" -ForegroundColor Cyan
Write-Host "║                 MINECRAFT MOD SCANNER - Avvio Analisi          ║" -ForegroundColor Cyan
Write-Host "╚" + ("═" * 58) + "╝" -ForegroundColor Cyan
Write-Host ""

function Log-Write-Header($text) {
    Write-Separator
    Log-Write $text 'Cyan'
    Write-Separator
}

Log-Write-Header "Controllo processi Minecraft (javaw.exe)..."

$mcProcs = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $mcProcs) {
    Log-Write "Minecraft non risulta in esecuzione (javaw.exe non trovato)." 'Yellow'
} else {
    foreach ($proc in $mcProcs) {
        Log-Write "Analisi del processo Minecraft (PID: $($proc.Id))" 'Green'
        try {
            $modules = $proc.Modules
        } catch {
            Write-Warning "Impossibile accedere ai moduli DLL del processo. Avvia PowerShell come amministratore."
            continue
        }
        $dllSegnalate = @{}
        foreach ($mod in $modules) {
            $filePath = $mod.FileName
            if (Is-SuspiciousFile $filePath -and -not $dllSegnalate.ContainsKey($filePath)) {
                Log-Write ">> FILE SOSPETTO TROVATO: $filePath" 'Red'
                $dllSegnalate[$filePath] = $true
            }
        }
    }
}

Log-Write-Header "Analisi cartelle mods..."

$possibleMcRoots = @(
    "$env:APPDATA\.minecraft",
    "$env:USERPROFILE\AppData\Roaming\.minecraft"
) | Select-Object -Unique

$modSegnalate = @{}
$loaderSegnalati = @{}

foreach ($mcRoot in $possibleMcRoots) {
    if (Test-Path "$mcRoot\mods") {
        Log-Write "Trovata cartella mods: $mcRoot\mods" 'Green'
        $modFiles = Get-ChildItem "$mcRoot\mods" -Recurse -File -Include *.jar,*.zip -ErrorAction SilentlyContinue
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
                    Log-Write "Mod OK: $($mod.FullName)" 'Gray'
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

    if (Test-Path "$mcRoot\versions") {
        $versions = Get-ChildItem "$mcRoot\versions" -Directory -ErrorAction SilentlyContinue
        foreach ($ver in $versions) {
            $verName = $ver.Name
            if ($verName -imatch "forge|fabric|quilt|lunar|badlion" -and -not $loaderSegnalati.ContainsKey($verName)) {
                Log-Write "Trovato mod loader: $verName" 'Cyan'
                $loaderSegnalati[$verName] = $true
            }
        }
    }
}

Write-Host ""
Write-Host "╔" + ("═" * 58) + "╗" -ForegroundColor Cyan
Write-Host "║                         ANALISI COMPLETATA                   ║" -ForegroundColor Cyan
Write-Host "╚" + ("═" * 58) + "╝" -ForegroundColor Cyan
Write-Host ""
Log-Write "Risultati salvati in: $logFile" 'Green'
