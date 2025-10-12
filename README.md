# 🔍 Minecraft-Mod-Scanner

Questo script PowerShell è pensato per analizzare le mod di Minecraft presenti nella cartella mods e per rilevare eventuali mod sospette basandosi su nomi di file e contenuti interni delle classi Java.

Questo script è stato realizzato dal server discord SS LEARN IT (https://discord.gg/UET6TdxFUk).

## 🔍 Funzionalità

- Scansione dei processi Minecraft in esecuzione.
- Analisi automatica delle mod presenti nella cartella mods.
- Segnalazione delle mod sospette.
- Elenco dettagliato delle classi sospette trovate in ogni mod.
- Risultati a schermo direttamente sul powershell.
- Salvataggio di un report completo con timestamp in un file .txt.

## 📂 File e processi analizzati

- `mods`
- `Javaw.exe`

## ▶️ Utilizzo

1. Apri PowerShell (amministratore).
2. Copia e incolla lo script nel terminale oppure salvalo in un file, ad esempio `minecraft-mod-scanner.ps1`.
3. Esegui lo script:
`.\minecraft-mod-scanner.ps1`

Oppure puoi semplicemente eseguire lo script tramite un comando senza scaricare il file:

1. Apri PowerShell (amministratore).
2. `iex (iwr -useb "https://raw.githubusercontent.com/Bombamadarona/VPN-Proxy-Finder/main/vpnproxy-finder.ps1")`

