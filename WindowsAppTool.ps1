# ==============================================================================
# Script: WindowsAppTool
# Verze: PowerShell
# Autor: Gemini
# Datum: 2023-10-01
# ==============================================================================

# --- Globalni nastaveni ---
$ErrorActionPreference = "Stop"
$LogFilePath = Join-Path -Path $PSScriptRoot -ChildPath "WindowsAppTool_Log.txt"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Funkce ---

# Funkce pro logovani
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoConsole # Tento parametr zde zustava, ale uz nema vliv na konzolovy vypis z TETO funkce
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        $logDir = Split-Path $LogFilePath -Parent
        if ($logDir -and (-not (Test-Path $logDir)) ) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        # Zapis do souboru zustava
        Add-Content -Path $LogFilePath -Value $logEntry -Encoding UTF8
    } catch {
        # Pokud selze zapis do logu, vypiseme varovani na konzoli, protoze logovani selhalo
        Write-Warning "CHYBA ZAPISU LOGU: Nepodarilo se zapsat do '$LogFilePath': $($_.Exception.Message)"
    }
    
}

# Funkce pro kontrolu admin prav
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { Write-Log "Chyba pri kontrole administratorskych prav: $($_.Exception.Message)" "ERROR"; return $false }
}

# Funkce pro potvrzeni Ano/Ne
function Get-Confirmation ($PromptMessage) {
    $validInput = $false
    while (-not $validInput) {
        $logPrompt = $PromptMessage -replace '`n',' '; Write-Log "Cekam na potvrzeni uzivatele: '$logPrompt (A/N)'" "DEBUG" -NoConsole
        $input = Read-Host "$PromptMessage (A/N)"
        Write-Log "Uzivatel odpovedel: '$input'" "DEBUG" -NoConsole
        if ($input -eq 'A' -or $input -eq 'a') { return $true; $validInput = $true }
        if ($input -eq 'N' -or $input -eq 'n') { return $false; $validInput = $true }
        Write-Log "Neplatna odpoved uzivatele." "WARN"
    }
}

# Funkce pro specificke potvrzeni
function Get-SpecificConfirmation ($PromptMessage, $RequiredString) {
     $logPrompt = $PromptMessage -replace '`n',' '; Write-Log "Cekam na specificke potvrzeni: '$logPrompt (Vyžadováno: '$RequiredString')'" "DEBUG" -NoConsole
    $input = Read-Host "$PromptMessage (Pro potvrzeni napiste '$RequiredString')"
    Write-Log "Uzivatel zadal: '$input'" "DEBUG" -NoConsole
    $isConfirmed = ($input -eq $RequiredString)
    if ($isConfirmed) { Write-Log "Potvrzeni '$RequiredString' bylo uspesne zadano." "INFO" -NoConsole }
    else { Write-Log "Potvrzeni '$RequiredString' NEBYLO zadano spravne." "WARN" }
    return $isConfirmed
}

# Funkce pro spusteni procesu (s omezenym vypisem)
function Start-ProcessWait ($FilePath, $ArgumentList, $ActionDescription) {
    Write-Log "Spoustim proces: '$FilePath' s argumenty '$ArgumentList' pro akci '$ActionDescription'" "INFO" -NoConsole
    try {
        Write-Host "Provadim: $ActionDescription ..." -ForegroundColor Gray
        Write-Log "Provadim akci: $ActionDescription..." "INFO" -NoConsole
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -Verb RunAs -WindowStyle Minimized -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            Write-Log "${ActionDescription}: Proces skoncil s chybovym kodem $($process.ExitCode)." "WARN"
            Write-Warning "${ActionDescription}: Proces skoncil s chybovym kodem $($process.ExitCode)."
            return $false
        } else {
            Write-Log "${ActionDescription}: Proces uspesne dokoncen (Kod 0)." "INFO" -NoConsole
            Write-Host "${ActionDescription}: OK (Kod 0)." -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Log "Nepodarilo se spustit proces pro '$ActionDescription': $($_.Exception.Message)" "ERROR"
        Write-Error "Nepodarilo se spustit proces pro '$ActionDescription': $($_.Exception.Message)"
        return $false
    }
}

# Funkce pro instalaci vybranych aplikaci
function Install-BasicApps {
    Clear-Host; Write-Log "Zahajena funkce Install-BasicApps (WinForms verze)." "INFO" -NoConsole
    Write-Host "==============================================" -ForegroundColor Yellow; Write-Host "      Instalace vybranych aplikaci" -ForegroundColor Yellow; Write-Host "==============================================" -ForegroundColor Yellow

    # Seznam dostupnych aplikaci (stejny jako predtim)
    $availableApps = @(
        [PSCustomObject]@{Poc=1;  Nazev="Google Chrome";             ID="Google.Chrome"}
        [PSCustomObject]@{Poc=2;  Nazev="Mozilla Firefox";           ID="Mozilla.Firefox"}
        [PSCustomObject]@{Poc=3;  Nazev="7-Zip";                     ID="7zip.7zip"}
        [PSCustomObject]@{Poc=5;  Nazev="Microsoft PowerToys";       ID="Microsoft.PowerToys"}
        [PSCustomObject]@{Poc=6;  Nazev="Windows Terminal";          ID="Microsoft.WindowsTerminal"}
        [PSCustomObject]@{Poc=7;  Nazev="VLC Media Player";          ID="VideoLAN.VLC"}
        [PSCustomObject]@{Poc=11; Nazev="Visual Studio Code";        ID="Microsoft.VisualStudioCode"}
        [PSCustomObject]@{Poc=12; Nazev="PowerShell 7";              ID="Microsoft.PowerShell"}
        [PSCustomObject]@{Poc=13; Nazev="GPU-Z";                     ID="TechPowerUp.GPU-Z"}
        [PSCustomObject]@{Poc=14; Nazev="CPU-Z";                     ID="CPUID.CPU-Z"}
        [PSCustomObject]@{Poc=15; Nazev="HWiNFO";                    ID="REALiX.HWiNFO"}
        [PSCustomObject]@{Poc=16; Nazev="Steam";                     ID="Valve.Steam"}
        [PSCustomObject]@{Poc=17; Nazev="GOG Galaxy";                ID="GOG.Galaxy"}
        [PSCustomObject]@{Poc=18; Nazev="Epic Games Launcher";       ID="EpicGames.EpicGamesLauncher"}
        [PSCustomObject]@{Poc=19; Nazev="Ubisoft Connect";           ID="Ubisoft.Connect"}
        [PSCustomObject]@{Poc=20; Nazev="Wargaming Game Center";     ID="Wargaming.GameCenter"}
        [PSCustomObject]@{Poc=21; Nazev="Logitech G HUB";            ID="Logitech.GHUB"}
        [PSCustomObject]@{Poc=22; Nazev="Discord";                   ID="Discord.Discord"}
        [PSCustomObject]@{Poc=23; Nazev="FanControl";                ID="Rem0o.FanControl"}
        [PSCustomObject]@{Poc=24; Nazev="MSI Afterburner";           ID="MSI.Afterburner"}
        [PSCustomObject]@{Poc=25; Nazev="RivaTuner Statistics Server"; ID="RivaTuner.RTSS"}
        [PSCustomObject]@{Poc=26; Nazev="HWMonitor";                 ID="CPUID.HWMonitor"}
        [PSCustomObject]@{Poc=27; Nazev="WinRAR";                    ID="RARLab.WinRAR"}
    ) | Sort-Object Poc
    Write-Log "Pripraven seznam aplikaci k vyberu." "DEBUG" -NoConsole

    # --- ZACATEK KODU PRO OKNO S CHECKBOXY ---

    try {
        # Nacteni potrebnych sestaveni pro Windows Forms
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Vytvoreni hlavniho okna (Form)
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Vyberte aplikace k instalaci"
        $form.Size = New-Object System.Drawing.Size(400, 500) # Sirka, Vyska
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog # Pevna velikost okna
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false

        # Vytvoreni panelu pro tlacitka (dole)
        $buttonPanel = New-Object System.Windows.Forms.Panel
        $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
        $buttonPanel.Height = 40

        # Vytvoreni tlacitka OK
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Location = New-Object System.Drawing.Point(220, 5) # Pozice X, Y v panelu
        $okButton.Size = New-Object System.Drawing.Size(75, 30)     # Sirka, Vyska
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK # Co se stane pri kliknuti
        $form.AcceptButton = $okButton # Reaguje na Enter

        # Vytvoreni tlacitka Storno
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Storno"
        $cancelButton.Location = New-Object System.Drawing.Point(300, 5) # Pozice X, Y v panelu
        $cancelButton.Size = New-Object System.Drawing.Size(75, 30)     # Sirka, Vyska
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel # Co se stane pri kliknuti
        $form.CancelButton = $cancelButton # Reaguje na Escape

        # Pridani tlacitek do panelu
        $buttonPanel.Controls.Add($okButton)
        $buttonPanel.Controls.Add($cancelButton)

        # Vytvoreni seznamu s checkboxy (CheckedListBox)
        $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
        $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill # Vyplni zbyvajici misto
        $checkedListBox.CheckOnClick = $true # Staci kliknout na polozku pro zaskrtnuti
        $checkedListBox.FormattingEnabled = $true

        # Naplneni seznamu aplikacemi
        # Pridavame cely objekt aplikace, ale zobrazime jen Nazev
        $checkedListBox.DisplayMember = "Nazev"
        foreach ($app in $availableApps) {
            [void]$checkedListBox.Items.Add($app)
        }

        # Pridani prvku (seznam a panel s tlacitky) do okna
        $form.Controls.Add($checkedListBox)
        $form.Controls.Add($buttonPanel) # Panel pridavame az po seznamu, aby se spravne dockoval

        # Zobrazeni okna a cekani na uzivatele
        Write-Host "Zobrazuji okno pro vyber aplikaci..." -ForegroundColor Cyan
        $result = $form.ShowDialog()

        $selectedApps = $null # Pripravime promennou pro vybrane

        # Zpracovani vysledku
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-Log "Uzivatel potvrdil vyber v okne." "DEBUG" -NoConsole
            # Ziskani zaskrtnutych polozek (vraci cele objekty, ktere jsme vlozili)
            $selectedApps = @($checkedListBox.CheckedItems | ForEach-Object { $_ }) # VŽDY vytvoří pole

            if ($selectedApps -and $selectedApps.Count -gt 0) {
                # OK - mame vybrane aplikace
            } else {
                $selectedApps = $null # Pokud nic nevybral a dal OK
                Write-Log "Uzivatel potvrdil OK, ale nevybral zadne aplikace." "WARN"
            }
        } else {
            # Uzivatel klikl na Storno nebo zavrel okno
            Write-Log "Uzivatel zrusil vyber v okne (Storno nebo zavreni)." "INFO"
            $selectedApps = $null
        }

        # Uvolneni zdroju okna
        $form.Dispose()

    } catch {
        Write-Log "Chyba pri vytvareni nebo zpracovani okna pro vyber aplikaci: $($_.Exception.Message)" "ERROR"
        Write-Error "Došlo k chybě při práci s oknem pro výběr aplikací: $($_.Exception.Message)"
        # V pripade chyby pokracujeme, jako by nic nebylo vybrano
        $selectedApps = $null
    }

    # --- KONEC KODU PRO OKNO S CHECKBOXY ---


    # Zbytek funkce zustava stejny, pracuje s promennou $selectedApps

    if ($null -eq $selectedApps) {
        Write-Log "Nebyly vybrany zadne aplikace nebo byla akce zrusena/selhala." "WARN"
        Write-Host "`nNebyly vybrany zadne aplikace nebo byla akce zrusena. Instalace preskocena." -ForegroundColor Yellow
        return # Ukonci funkci Install-BasicApps
    }

    $selectedNames = $selectedApps | ForEach-Object {$_.Nazev}
    Write-Log "Uzivatel vybral aplikace: $($selectedNames -join ', ')" "INFO" -NoConsole
    Write-Host "`nByly vybrany nasledujici aplikace:" -ForegroundColor Green
    $selectedApps | ForEach-Object { Write-Host "   - $($_.Nazev)" }
    Write-Host ""

    if (-not (Get-Confirmation "Chcete pokracovat v instalaci techto vybranych aplikaci?")) {
        Write-Log "Instalace vybranych aplikaci zrusena uzivatelem po vyberu." "INFO"
        Write-Host "Instalace zrusena."
        return # Ukonci funkci Install-BasicApps
    }

    Write-Log "Zahajeni instalace vybranych aplikaci." "INFO" -NoConsole
    Write-Host "`nSpoustim instalaci vybranych aplikaci (muze to trvat)...`n"
    $installErrors = 0

    foreach ($app in $selectedApps) {
        
        Write-Host # Prazdny radek
        $appName = $app.Nazev; $appId = $app.ID; Write-Log "Pokus o instalaci/aktualizaci '$appName' (ID: $appId)." "INFO" -NoConsole
        Write-Host "----------------------------------------------"; # Pridano pro prehlednost
        $alreadyInstalled_I = $false; try {
            Write-Host "   Overuji, zda je '$appName' jiz nainstalovana..." -ForegroundColor Gray; Write-Log "Overuji existenci '$appName' (ID: $appId) pres 'winget list'." "DEBUG" -NoConsole
            $listOutput_I = Invoke-Expression "winget list --id $appId -e --accept-source-agreements 2>&1"
            if ($LASTEXITCODE -eq 0 -and $listOutput_I -notmatch 'No installed package found matching input criteria.') { $alreadyInstalled_I = $true }
        } catch { Write-Log "Chyba pri overovani existence '$appName': $($_.Exception.Message)" "WARN"; Write-Warning "   Nepodarilo se overit, zda je '$appName' nainstalovana." }
        if ($alreadyInstalled_I) { Write-Log "'$appName' (ID: $appId) jiz nainstalovan (dle winget list), preskakuji." "INFO"; Write-Host "   '$appName' je jiz nainstalovana (via Winget). Preskakuji." -ForegroundColor Cyan
        } else {
            Write-Log "'$appName' (ID: $appId) nenalezen, pokousim se o instalaci/aktualizaci." "INFO" -NoConsole
            $arguments = "install --id $appId -e --accept-package-agreements --accept-source-agreements --disable-interactivity --force"
            if (-not (Start-ProcessWait -FilePath "winget" -ArgumentList $arguments -ActionDescription "Instalace $appName")) {
                $installErrors++; Write-Log "Instalace '$appName' se nezdarila." "WARN" -NoConsole; Read-Host "Stisknete Enter pro pokracovani dalsi aplikaci..."
            }
        } Write-Log "Dokoncen pokus o instalaci/aktualizaci '$appName'." "INFO" -NoConsole; Write-Host "----------------------------------------------" # Pridano pro prehlednost
    }

    Write-Host "`n==============================================" -ForegroundColor Yellow
    if ($installErrors -eq 0) { Write-Log "Instalace vybranych aplikaci dokoncena bez chyb." "INFO"; Write-Host "Instalace/aktualizace vybranych aplikaci dokoncena bez zaznamenanych chyb." -ForegroundColor Green
    } else { Write-Log "Instalace vybranych aplikaci dokoncena s $installErrors chybami." "WARN"; Write-Warning "Instalace dokoncena s $installErrors chybami. Zkontrolujte prosim vypis vyse a log soubor." }
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Log "Ukoncena funkce Install-BasicApps (WinForms verze)." "INFO" -NoConsole
}

# Funkce pro aktualizaci vsech aplikaci
function Update-AllApps {
    Clear-Host; Write-Log "Zahajena funkce Update-AllApps." "INFO" -NoConsole
    Write-Host "==============================================" -ForegroundColor Yellow; Write-Host "     Aktualizace vsech aplikaci" -ForegroundColor Yellow; Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "Spoustim kontrolu a aktualizaci vsech aplikaci pres winget..."; Write-Host "Muze to chvili trvat, budte prosim trpelivi."; Write-Host ""
    $arguments = "upgrade --all --accept-package-agreements --accept-source-agreements --disable-interactivity --verbose"
    Start-ProcessWait -FilePath "winget" -ArgumentList $arguments -ActionDescription "Aktualizace vsech aplikaci"
    Write-Log "Dokoncen pokus o aktualizaci vsech aplikaci." "INFO" -NoConsole; Write-Host "`n==============================================" -ForegroundColor Yellow
    Write-Host "Proces aktualizace dokoncen. Zkontrolujte vystup vyse."; Write-Host "==============================================" -ForegroundColor Yellow; Write-Log "Ukoncena funkce Update-AllApps." "INFO" -NoConsole
}

# Funkce pro aktualizaci Winget
function Update-Winget {
    Clear-Host; Write-Log "Zahajena funkce Update-Winget." "INFO" -NoConsole
    Write-Host "==============================================" -ForegroundColor Yellow; Write-Host "     Aktualizace Winget (Instalator aplikaci)" -ForegroundColor Yellow; Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "Pokousim se aktualizovat samotny nastroj Winget (balik Microsoft.AppInstaller)."
    Write-Host ""
    if (Get-Confirmation "Chcete pokracovat?") {
        $arguments = "upgrade Microsoft.AppInstaller --include-unknown --accept-package-agreements --disable-interactivity"
        Start-ProcessWait -FilePath "winget" -ArgumentList $arguments -ActionDescription "Aktualizace Winget"
        Write-Log "Dokoncen pokus o aktualizaci Winget." "INFO" -NoConsole
    } else { Write-Log "Aktualizace Winget zrusena uzivatelem." "INFO"; Write-Host "Aktualizace Winget zrusena." }
    Write-Host "`n==============================================" -ForegroundColor Yellow; Write-Log "Ukoncena funkce Update-Winget." "INFO" -NoConsole
}

# Funkce pro odinstalaci Bloatware (BEZ Edge)
function Uninstall-Bloatware {
    Clear-Host; Write-Log "Zahajena funkce Uninstall-Bloatware." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Yellow; Write-Host "   Odinstalace predinstalovanych aplikaci Windows" -ForegroundColor Yellow; Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""; Write-Host "  /!\\   V A R O V A N I   /!\\" -ForegroundColor Red; Write-Host "  Tato funkce se pokusi odstranit nektere standardni aplikace Windows." -ForegroundColor Red
    Write-Host "  Odstraneni muze ovlivnit jine funkce systemu a je obtizne vratne!" -ForegroundColor Red; Write-Host "  Microsoft Edge NEBUDE odstranen touto volbou." -ForegroundColor Red; Write-Host ""
    $bloatAppList = @(
        [PSCustomObject]@{ Name = "Microsoft Teams"; Pattern = "*MicrosoftTeams*" } 
        [PSCustomObject]@{ Name = "OneDrive (Appx)"; Pattern = "*OneDrive*" }
        [PSCustomObject]@{ Name = "Ziskat Napovedu"; Pattern = "*GetHelp*" } 
        [PSCustomObject]@{ Name = "Zaciname (Get Started)"; Pattern = "*GetStarted*" }
        [PSCustomObject]@{ Name = "Pocasi"; Pattern = "*BingWeather*" } 
        [PSCustomObject]@{ Name = "Zpravy"; Pattern = "*BingNews*" }
        [PSCustomObject]@{ Name = "Mapy"; Pattern = "*WindowsMaps*" } 
        [PSCustomObject]@{ Name = "Posta a Kalendar"; Pattern = "*windowscommunicationsapps*" }
        [PSCustomObject]@{ Name = "Lide (Kontakty)"; Pattern = "*People*" } 
        [PSCustomObject]@{ Name = "Vas telefon / Propojeni"; Pattern = "*YourPhone*" }
        [PSCustomObject]@{ Name = "Microsoft Solitaire Collection";Pattern = "*MicrosoftSolitaireCollection*" } 
        [PSCustomObject]@{ Name = "Centrum Office (My Office)"; Pattern = "*MicrosoftOfficeHub*" }
        [PSCustomObject]@{ Name = "Centrum Feedback"; Pattern = "*WindowsFeedbackHub*" } 
        [PSCustomObject]@{ Name = "Mixed Reality Portal"; Pattern = "*MixedReality.Portal*" }
        [PSCustomObject]@{ Name = "Skype (verze z Appx)"; Pattern = "*SkypeApp*" } 
        [PSCustomObject]@{ Name = "Rychle poznamky (Sticky Notes)";Pattern = "*MicrosoftStickyNotes*" }
        [PSCustomObject]@{ Name = "Widgety (Web Experience Pack)"; Pattern = "*WebExperienceHost*" }
    )
    Write-Host "Nasledujici skupiny aplikaci se skript pokusi odstranit (dle vzoru):"
    $bloatAppList | ForEach-Object { Write-Host "  - $($_.Name) (Vzor: '$($_.Pattern)')" }
    Write-Host ""
    if (-not (Get-SpecificConfirmation "Pro potvrzeni odinstalace napiste 'ANO'" "ANO")) { Write-Log "Odinstalace bloatware zrusena uzivatelem." "INFO"; Write-Host "Odinstalace zrusena uzivatelem."; return }
    Write-Log "Zahajeni odinstalace bloatware." "INFO" -NoConsole; Write-Host "`nSpoustim odinstalaci standardnich aplikaci pomoci PowerShell..."; Write-Host "Pripadne chyby (aplikace nenalezena, nelze odebrat) budou ignorovany..."
    foreach ($appToRemove in $bloatAppList) {
        $pattern = $appToRemove.Pattern; $appName = $appToRemove.Name; Write-Host "----------------------------------------------"
        Write-Log "Pokus o odinstalaci '$appName' (vzor: '$pattern')." "INFO" -NoConsole; Write-Host "Pokousim se odinstalovat: $appName (vzor: '$pattern')..."
        $packageRemoved = $false; try {
            $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern }
            if ($packages) {
                foreach ($package in $packages) { Write-Log "  Odstranuji: $($package.Name) ($($package.PackageFullName))" "DEBUG" -NoConsole; Write-Host "  Odstranuji: $($package.Name) ($($package.PackageFullName))"; Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 100; $packageRemoved = $true }
                if ($packageRemoved) { Write-Log "  Odstraneni pro '$appName' (vzor '$pattern') dokoncenoo." "INFO" -NoConsole; Write-Host "  Odstraneni pro '$appName' dokoncenoo." -ForegroundColor Green }
            } else { Write-Log "  Nenalezeny zadne nainstalovane balicky pro '$appName' (vzor '$pattern')." "INFO" -NoConsole; Write-Host "  Nenalezeny zadne nainstalovane balicky pro '$appName'." -ForegroundColor Gray }
        } catch { Write-Log "  Doslo k obecne chybe pri zpracovani '$appName': $($_.Exception.Message)" "ERROR"; Write-Warning "  Doslo k obecne chybe pri zpracovani '$appName': $($_.Exception.Message)" }
         Write-Host "----------------------------------------------`n"
    }
    Write-Host "============================================================" -ForegroundColor Yellow; Write-Log "Odinstalace bloatware dokoncena." "INFO"
    Write-Host "Pokus o odinstalaci specifikovanych aplikaci (mimo Edge) dokoncen." -ForegroundColor Green; Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "Pro uplne projeveni zmen muze byt potreba restartovat pocitac."; Write-Log "Ukoncena funkce Uninstall-Bloatware." "INFO" -NoConsole
}

# Funkce pro odinstalaci Edge
function Uninstall-Edge {
    Clear-Host; Write-Log "Zahajena funkce Uninstall-Edge." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Red; Write-Host "      Odinstalace Microsoft Edge" -ForegroundColor Red; Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""; Write-Host "             /!\\   V A R O V A N I   /!\\" -ForegroundColor Red
    Write-Host "  TATO AKCE SE POKUSI ODINSTALOVAT MICROSOFT EDGE." -ForegroundColor Red; Write-Host "  MUZE DOJIT K NEOCEKAVANYM PROBLEMUM SE STABILITOU SYSTEMU," -ForegroundColor Red
    Write-Host "  AKTUALIZACEMI WINDOWS NEBO JINYMI APLIKACEMI (WebView2)." -ForegroundColor Red; Write-Host "  POKRACUJTE POUZE NA VLASTNI NEBEZPECI!" -ForegroundColor Red; Write-Host ""
    if (-not (Get-SpecificConfirmation "Pro potvrzeni odinstalace Edge napiste presne 'ANO EDGE'" "ANO EDGE")) { Write-Log "Odinstalace Edge zrusena uzivatelem." "INFO"; Write-Host "Odinstalace Edge zrusena uzivatelem."; return }
    Write-Log "Zahajeni pokusu o odinstalaci Edge." "WARN"; Write-Host "`n------------------------------------------------------------"
    Write-Host "POKUS O ODINSTALACI MICROSOFT EDGE..."; Write-Host "Hledam instalacni program Edge (setup.exe)..."; Write-Host "------------------------------------------------------------"
    $edgeAppPath = "C:\Program Files (x86)\Microsoft\Edge\Application"; $edgeSetupPath = $null; $edgeFound = $false
    if (Test-Path $edgeAppPath) {
        Write-Log "Standardni slozka Edge nalezena: '$edgeAppPath'." "DEBUG" -NoConsole; try {
            $latestVersionDir = Get-ChildItem -Path $edgeAppPath -Directory | Where-Object {$_.Name -match '^\d+(\.\d+){3}$'} | Sort-Object {[version]$_.Name} -Descending | Select-Object -First 1
            if ($latestVersionDir) {
                Write-Log "Nalezena slozka s nejvyssi verzi Edge: '$($latestVersionDir.FullName)'." "DEBUG" -NoConsole; $potentialPath = Join-Path -Path $latestVersionDir.FullName -ChildPath "Installer\setup.exe"
                if (Test-Path $potentialPath) { $edgeSetupPath = $potentialPath; $edgeFound = $true; Write-Log "Nalezen Edge setup.exe: '$edgeSetupPath'." "INFO" -NoConsole; Write-Host "  Nalezen Edge setup.exe: '$edgeSetupPath'" -ForegroundColor Green
                } else { Write-Log "Soubor setup.exe nenalezen v '$($latestVersionDir.FullName)\Installer'." "WARN"; Write-Warning "Slozka Installer\setup.exe nenalezena v '$($latestVersionDir.FullName)'." }
            } else { Write-Log "Nenalezena zadna slozka s ocekavanym formatem verze v '$edgeAppPath'." "WARN"; Write-Warning "Nenalezena zadna slozka s ocekavanym formatem verze v '$edgeAppPath'." }
        } catch { Write-Log "Doslo k chybe pri hledani slozky s verzi Edge: $($_.Exception.Message)" "ERROR"; Write-Warning "Doslo k chybe pri hledani slozky s verzi Edge: $($_.Exception.Message)" }
    } else { Write-Log "Standardni slozka Edge '$edgeAppPath' nenalezena." "WARN"; Write-Warning "Standardni slozka Edge '$edgeAppPath' nenalezena." }
    if ($edgeFound) {
        $arguments = "--uninstall --system-level --verbose-logging --force-uninstall"
        if (Start-ProcessWait -FilePath $edgeSetupPath -ArgumentList $arguments -ActionDescription "Odinstalace Edge") { Write-Log "Odinstalator Edge uspesne spusten a dokoncen (Kod 0)." "INFO"; Write-Host "  Odinstalator Edge dobehl. Restartujte pocitac pro dokončení." -ForegroundColor Green
        } else { Write-Log "Odinstalator Edge skoncil s chybou nebo byl prerusen." "WARN"; }
    } else { Write-Log "Edge setup.exe nebyl nalezen, odinstalace se nespusti." "ERROR"; Write-Error "  CHYBA: Nepodarilo se automaticky nalezt soubor 'setup.exe' pro Microsoft Edge."; Write-Error "         Edge NEBYL odinstalovan timto skriptem." }
    Write-Host "------------------------------------------------------------"; Write-Host "`n============================================================" -ForegroundColor Yellow
    Write-Log "Pokus o odinstalaci Edge dokoncen (uspech zavisi na vysledku vyse)." "INFO"; Write-Host "Pokus o odinstalaci Microsoft Edge dokoncen." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow; Write-Log "Ukoncena funkce Uninstall-Edge." "INFO" -NoConsole
}

# Funkce pro zobrazeni typu licence Windows
function Show-WindowsLicenseType {
    Clear-Host; Write-Log "Zahajena funkce Show-WindowsLicenseType." "INFO" -NoConsole
    Write-Host "==============================================" -ForegroundColor Yellow; Write-Host "       Typ licence Windows" -ForegroundColor Yellow; Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "Zjistuji informace o licenci...`n"; Write-Log "Zjistovani informaci o licenci pres WMI..." "INFO" -NoConsole
    $licenseType = "Neznamy"; $licenseDescription = "N/A"; $oemKeyExists = $false
    try {
        $windowsAppID = "55c92734-d682-4d71-983e-d6ec3f16059f"; Write-Log "Hledam licenci pro AppID: $windowsAppID" "DEBUG" -NoConsole
        $licenseInfo = Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $_.ApplicationID -eq $windowsAppID -and $_.LicenseStatus -eq 1 } | Select-Object -First 1
        if ($licenseInfo) {
            $licenseDescription = $licenseInfo.Description; Write-Log "Nalezen popis licence: '$licenseDescription'" "INFO"
            Write-Host "Popis licence systemu: $($licenseDescription)"
            if ($licenseDescription -match 'OEM') { $licenseType = "OEM"; Write-Log "Typ licence identifikovan jako OEM z popisu." "INFO" -NoConsole }
            elseif ($licenseDescription -match 'Retail') { $licenseType = "Retail"; Write-Log "Typ licence identifikovan jako Retail z popisu." "INFO" -NoConsole }
            elseif ($licenseDescription -match 'VOLUME') { $licenseType = "Volume (MAK/KMS)"; Write-Log "Typ licence identifikovan jako Volume z popisu." "INFO" -NoConsole }
            else { Write-Log "Typ licence nelze spolehlive urcit z popisu '$licenseDescription'." "WARN" }
        } else { Write-Log "Nepodarilo se nalezt aktivni licenci Windows pres SoftwareLicensingProduct." "WARN"; Write-Warning "Nepodarilo se nalezt informace o aktivni licenci Windows." }
        Write-Log "Kontroluji pritomnost OA3xOriginalProductKey..." "DEBUG" -NoConsole
        $serviceInfo = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue
        if ($serviceInfo -and $serviceInfo.OA3xOriginalProductKey) {
            $oemKeyExists = $true; Write-Log "Nalezen OA3xOriginalProductKey (silna indikace OEM)." "INFO" -NoConsole
            Write-Host "V systemu byl detekovan produktovy klic z BIOS/UEFI (typicke pro OEM)." -ForegroundColor Gray
            if ($licenseType -eq "Neznamy") { $licenseType = "Pravdepodobne OEM (nalezen klic v BIOS/UEFI)"; Write-Log "Typ licence upresnen na OEM diky OA3x klici." "INFO" -NoConsole }
        } else { Write-Log "OA3xOriginalProductKey nenalezen." "DEBUG" -NoConsole }
    } catch { Write-Log "Chyba pri zjistovani licence: $($_.Exception.Message)" "ERROR"; Write-Error "Pri zjistovani typu licence doslo k chybe: $($_.Exception.Message)" }
    Write-Host "`n----------------------------------------------"; Write-Host "Zjisteny typ licence: $($licenseType)" -ForegroundColor Green
    Write-Log "Vysledny zjisteny typ licence: $licenseType" "INFO"; Write-Host "----------------------------------------------"
    Write-Host "(Presnost zavisi na informacich dostupnych v systemu)." -ForegroundColor Gray; Write-Log "Ukoncena funkce Show-WindowsLicenseType." "INFO" -NoConsole
}

# Funkce pro odinstalaci VYBRANYCH aplikaci (pomoci Out-GridView)
function Uninstall-SelectedApps {
    Clear-Host; Write-Log "Zahajena funkce Uninstall-SelectedApps." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "   Odinstalace specifickych aplikaci (Vyber ze seznamu)" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "Nacitam seznam nainstalovanych aplikaci pomoci 'winget list'..."
    Write-Host "(To muze chvili trvat...)"
    Write-Log "Spoustim 'winget list' pro ziskani seznamu aplikaci." "INFO" -NoConsole

    $installedApps = @()
    try {
        # Presmerujeme i chybovy vystup, abychom ho pripadne videli v $listOutput
        $listOutput = winget list --accept-source-agreements 2>&1
        Write-Log "Vystup z 'winget list' zachycen, pocet radku: $($listOutput.Count)." "DEBUG" -NoConsole

        # Pokud winget list skoncil s chybou, $LASTEXITCODE nebude 0
        if ($LASTEXITCODE -ne 0) {
             Write-Warning "Prikaz 'winget list' skoncil s chybou (kod $LASTEXITCODE)."
             Write-Warning "Vystup: $($listOutput -join [Environment]::NewLine)"
             Write-Log "Prikaz 'winget list' selhal s kodem $LASTEXITCODE." "ERROR"
             # Presto zkusime parsovat, co vratil, pokud neco vratil
        }

        $regex = '^(.*?)\s{2,}(\S+)\s{2,}(\S+).*$'
        # Preskocime hlavicku (Name, ---) a pripadne varovani/chyby na zacatku
        # Hledame prvni radek, ktery zacina nejakym znakem (ne mezerou) a za nim jsou 2+ mezery
        $startIndex = 0
        for ($i = 0; $i -lt $listOutput.Count; $i++) {
            if ($listOutput[$i] -match '^\S+.*\s{2,}') {
                $startIndex = $i
                break
            }
        }
        # Pokud jsme nenasli potencialni zacatek dat, preskocime standardni 2 radky
        if ($startIndex -eq 0 -and $listOutput.Count -gt 1) { $startIndex = 2 }

        Write-Log "Zacinam parsovat vystup 'winget list' od radku $startIndex." "DEBUG" -NoConsole
        $dataLines = $listOutput | Select-Object -Skip $startIndex

        foreach ($line in $dataLines) {
            if ($line -match $regex) {
                $appName = $Matches[1].Trim(); $appId = $Matches[2].Trim(); $appVersion = $Matches[3].Trim()
                if (-not [string]::IsNullOrWhiteSpace($appName) -and -not [string]::IsNullOrWhiteSpace($appId)) {
                    $installedApps += [PSCustomObject]@{ Nazev = $appName; ID = $appId; Verze = $appVersion }
                } else { Write-Log "Preskocen radek kvuli chybejicimu nazvu nebo ID: '$line'" "WARN" -NoConsole }
            } else { if (-not [string]::IsNullOrWhiteSpace($line) -and $line -notmatch '^-+$') { Write-Log "Radek vystupu 'winget list' neodpovida ocekavanemu formatu: '$line'" "WARN" -NoConsole } }
        }
        Write-Log "Zpracovani vystupu 'winget list' dokonceno. Nalezeno $($installedApps.Count) aplikaci pro vyber." "INFO"
        if ($installedApps.Count -eq 0) {
             Write-Warning "Nepodarilo se nacist nebo zpracovat seznam nainstalovanych aplikaci z winget list."; Write-Warning "Bud nejsou zadne aplikace spravovane pres winget, nebo se zmenil format vystupu 'winget list'."; Write-Log "Nepodarilo se ziskat aplikace ze seznamu winget." "ERROR"; return
        }
        Write-Host "`nNalezeno $($installedApps.Count) aplikaci."
        Write-Host "V nasledujicim okne vyberte aplikace k ODINSTALACI." -ForegroundColor Cyan; Write-Host "(Pro vyber vice polozek drzte klavesu Ctrl nebo Shift pri klikani)." -ForegroundColor Cyan
        Write-Host "Po vyberu kliknete na tlacitko 'OK'." -ForegroundColor Cyan; Start-Sleep -Seconds 1
        $selectedAppsToUninstall = $installedApps | Sort-Object Nazev | Out-GridView -Title "Vyberte aplikace k ODINSTALACI (Ctrl+Klik pro vice polozek)" -PassThru
        if ($null -eq $selectedAppsToUninstall) { Write-Log "Uzivatel nevybral zadne aplikace k odinstalaci nebo zavrel okno." "WARN"; Write-Host "`nNebyly vybrany zadne aplikace k odinstalaci. Akce zrusena." -ForegroundColor Yellow; return }
        $selectedNames = $selectedAppsToUninstall | ForEach-Object {$_.Nazev}; Write-Log "Uzivatel vybral k odinstalaci: $($selectedNames -join ', ')" "INFO" -NoConsole
        Write-Host "`nBudou odinstalovany nasledujici aplikace:" -ForegroundColor Red; $selectedAppsToUninstall | ForEach-Object { Write-Host "  - $($_.Nazev) (ID: $($_.ID))" }; Write-Host ""
        if (-not (Get-Confirmation "OPRAVDU chcete pokracovat v ODINSTALACI techto aplikaci?")) { Write-Log "Odinstalace vybranych aplikaci zrusena uzivatelem." "INFO"; Write-Host "Odinstalace zrusena."; return }
        Write-Log "Zahajeni odinstalace vybranych aplikaci." "INFO" -NoConsole; Write-Host "`nSpoustim odinstalaci vybranych aplikaci..."
        $uninstallErrors = 0
        foreach ($app in $selectedAppsToUninstall) {
            Write-Host # Prazdny radek
            $appName = $app.Nazev; $appId = $app.ID; Write-Log "Pokus o odinstalaci '$appName' (ID: $appId)." "INFO" -NoConsole
            $arguments = "uninstall --id `"$appId`" --accept-source-agreements --disable-interactivity --silent"
            if (-not (Start-ProcessWait -FilePath "winget" -ArgumentList $arguments -ActionDescription "Odinstalace $appName")) {
                $uninstallErrors++; Write-Log "Odinstalace '$appName' se nezdarila." "WARN" -NoConsole
            } Write-Log "Dokoncen pokus o odinstalaci '$appName'." "INFO" -NoConsole
        }
        Write-Host "`n============================================================" -ForegroundColor Yellow
        if ($uninstallErrors -eq 0) { Write-Log "Odinstalace vybranych aplikaci dokoncena bez zaznamenanych chyb." "INFO"; Write-Host "Odinstalace vybranych aplikaci dokoncena bez zaznamenanych chyb." -ForegroundColor Green
        } else { Write-Log "Odinstalace dokoncena s $uninstallErrors chybami." "WARN"; Write-Warning "Odinstalace dokoncena s $uninstallErrors chybami. Zkontrolujte prosim vypis vyse a log soubor." }
        Write-Host "============================================================" -ForegroundColor Yellow
    } catch { Write-Log "Chyba ve funkci Uninstall-SelectedApps: $($_.Exception.Message)" "ERROR"; Write-Error "Pri odinstalaci specifickych aplikaci doslo k chybe: $($_.Exception.Message)" }
     Write-Log "Ukoncena funkce Uninstall-SelectedApps." "INFO" -NoConsole
}

# --- Hlavni cast skriptu ---

Write-Log "================ Zahajeni logovani skriptu ================" "INFO"
Write-Log "Spoustim script: WindowsAppTool" "INFO" -NoConsole

# 1. Kontrola Admin prav
Write-Log "Kontrola administratorskych prav..." "DEBUG" -NoConsole
if (-not (Test-IsAdmin)) {
    Write-Log "Skript nema administratorska prava. Ukoncuji." "ERROR"
    Write-Warning "Tento skript vyzaduje prava administratora. Spustte jej znovu jako spravce."
    Read-Host "Stisknete Enter pro ukonceni..."
    exit 1
}
Write-Log "Kontrola admin prav uspesna." "INFO"
Start-Sleep -Seconds 1

# 2. Kontrola Winget
Write-Host "`n=============================================="
Write-Log "Kontrola dostupnosti nastroje Winget..." "INFO" -NoConsole
Write-Host "  Kontrola nastroje Winget..."
Write-Host "=============================================="
$wingetExe = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $wingetExe) {
    Write-Log "Prikaz 'winget' nebyl nalezen. Skript ukoncen." "ERROR"
    Write-Error "Prikaz 'winget' nebyl nalezen. Ujistete se, ze mate nainstalovany 'Instalacni program aplikaci' (App Installer) z Microsoft Store a je aktualni."
    Read-Host "Stisknete Enter pro ukonceni..."
    exit 1
}
try {
    Write-Log "Winget nalezen: $($wingetExe.Source)" "INFO" -NoConsole
    $wingetVersionOutput = Invoke-Expression "winget --version --disable-interactivity"
    Write-Log "Nalezena verze Winget: $($wingetVersionOutput -join '; ')" "INFO" -NoConsole
    Write-Host "Winget nalezen a funkcni (Verze: $($wingetVersionOutput))." -ForegroundColor Green
} catch {
    Write-Log "Neocekavana chyba pri zjistovani verze winget: $($_.Exception.Message)" "ERROR"
    Write-Warning "`nDoslo k chybe pri zjistovani verze winget: $($_.Exception.Message)"
    Write-Warning "Presto se pokusime pokracovat."
    Read-Host "Stisknete Enter pro pokracovani..."
}

# --- Ziskani systemovych informaci (jednou na zacatku) ---
Write-Host "`nNacitam zakladni informace o systemu..."
Write-Log "Nacitam zakladni systemove informace..." "INFO" -NoConsole
$sysInfoCPU = "N/A"; $sysInfoRAM = "N/A"; $sysInfoGPU = @("N/A"); $sysInfoOS = "N/A"
try {
    $sysInfoCPU = (Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Name -First 1).Trim()
    $ramBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    $sysInfoRAM = "$([math]::Round($ramBytes / 1GB, 1)) GB"
    $gpuInfo = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -ExpandProperty Name)
    if ($gpuInfo) { $sysInfoGPU = $gpuInfo | ForEach-Object { $_.Trim() } } # Zajisti, ze je to pole, i kdyz je jen jedna GPU
    else { $sysInfoGPU = @("N/A") }
    $osInfo = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version
    $osVersionInfo = Get-ComputerInfo | Select-Object WindowsVersion
    $sysInfoOS = "$($osInfo.Caption) $($osVersionInfo.WindowsVersion) (Ver: $($osInfo.Version))"
    Write-Log "SysInfo: CPU=$sysInfoCPU | RAM=$sysInfoRAM | GPU=$($sysInfoGPU -join '; ') | OS=$sysInfoOS" "INFO" -NoConsole
} catch {
    Write-Log "Chyba pri zjistovani systemovych informaci: $($_.Exception.Message)" "ERROR"
    Write-Warning "Nepodarilo se nacist nektere systemove informace."
}
Write-Host "Hotovo."
Start-Sleep -Seconds 1


# 3. Hlavni menu (smycka)
$exitLoop = $false
do {
    Clear-Host
    # --- Zobrazeni System Info ---
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray
    Write-Host " OS : $sysInfoOS" -ForegroundColor White
    Write-Host " CPU: $sysInfoCPU" -ForegroundColor White
    Write-Host " RAM: $sysInfoRAM" -ForegroundColor White
    Write-Host " GPU: $($sysInfoGPU -join ', ')" -ForegroundColor White # Vypise grafiky oddelene carkou
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # --- Menu ---
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   WindowsAppTool (PowerShell verze)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Vyberte pozadovanou akci:"
    Write-Host "  1. Instalovat vybrane aplikace"
    Write-Host "  2. Aktualizovat vsechny aplikace"
    Write-Host "  3. Aktualizovat Winget (Instalator aplikaci)"
    Write-Host "  4. Odinstalovat aplikace Windows"
    Write-Host "  5. Odinstalovat Microsoft Edge"
    Write-Host "  6. Zobrazit typ licence Windows"
    Write-Host "  7. Odinstalovat specifickou aplikaci (Vyber)"
    Write-Host "  8. Konec"
    Write-Host ""
    $choice = Read-Host "Zadejte cislo volby (1-8)"
    Write-Log "Uzivatel zvolil v menu moznost: $choice" "INFO"

    try {
        switch ($choice) {
            "1" { Install-BasicApps }
            "2" { Update-AllApps }
            "3" { Update-Winget }
            "4" { Uninstall-Bloatware }
            "5" { Uninstall-Edge }
            "6" { Show-WindowsLicenseType }
            "7" { Uninstall-SelectedApps }
            "8" {
                Write-Log "Uzivatel zvolil konec skriptu. Ukoncuji." "INFO"
                Write-Host "Skript ukoncen."
                exit 0 # Ukonci script a zavre okno
            }
            default {
                Write-Log "Neplatna volba menu: '$choice'." "WARN"
                Write-Warning "Neplatna volba '$choice'. Zkuste to znovu."
                Start-Sleep -Seconds 2
            }
        }# end switch

        # Pockame na uzivatele pred zobrazenim menu znovu (pokud jsme neukoncili pres exit)
         Read-Host "`nAkce dokoncena. Stisknete Enter pro navrat do hlavniho menu..."

    } catch {
         $logMsg = "`n! NEOČEKAVANA CHYBA SKRIPTU: $($_.Exception.Message) | Cil: $($_.TargetObject) | Radek: $($_.InvocationInfo.ScriptLineNumber)"
         Write-Log $logMsg "ERROR"
         Write-Error $logMsg
         Read-Host "Stisknete Enter pro navrat do hlavniho menu..."
    }

} while (-not $exitLoop) # Smycka by technicky mela bezet porad, dokud se neukonci pres exit

# --- Konec skriptu ---
Write-Log "================ Ukonceni logovani skriptu ================" "INFO"