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

# Funkce pro pruvodce nastavenim (sekvencni spusteni vybranych funkci - Navrat do menu)
function Start-WizardMode {
    Clear-Host
    Write-Log "Zahajena funkce Start-WizardMode (Pruvodce nastavenim - navrat do menu)." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "              Pruvodce nastavenim WindowsAppTool" -ForegroundColor Green # Bez diakritiky
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host
    Write-Host "Tento pruvodce vas provede nasledujicimi kroky v doporucenem poradi:" # Bez diakritiky
    Write-Host "  1. Instalace zakladnich aplikaci" # Bez diakritiky
    Write-Host "  2. Odinstalace aplikaci Windows" # Bez diakritiky
    Write-Host "  3. Odinstalace Microsoft Edge - Volitelne v ramci kroku" # Bez diakritiky
    Write-Host "  4. Otevreni stranek pro stazeni ovladacu GPU" # Bez diakritiky
    Write-Host
    if (-not (Get-Confirmation "Chcete spustit pruvodce nastavenim?")) { # Bez diakritiky
        Write-Log "Pruvodce nastavenim zrusen uzivatelem." "INFO"
        Write-Host "Pruvodce nastavenim zrusen." -ForegroundColor Yellow # Bez diakritiky
        return # Vratime se do hlavniho menu
    }

    Write-Log "Pruvodce - Krok 1: Instalace zakladnich aplikaci" "INFO"
    Write-Host "`n--- Pruvodce: Krok 1/4 - Instalace zakladnich aplikaci ---`n" -ForegroundColor Green # Bez diakritiky
    Install-BasicApps # Volame funkci (drive #1, nyni #2 v menu)
    Read-Host "`nPruvodce: Krok 1 dokoncen. Stisknete Enter pro pokracovani k odinstalaci aplikaci Windows..." # Bez diakritiky

    Write-Log "Pruvodce - Krok 2: Odinstalace aplikaci Windows" "INFO"
    Write-Host "`n--- Pruvodce: Krok 2/4 - Odinstalace aplikaci Windows ---`n" -ForegroundColor Green # Bez diakritiky
    Uninstall-Bloatware # Volame funkci (drive #4, nyni #5 v menu)
    Read-Host "`nPruvodce: Krok 2 dokoncen. Stisknete Enter pro pokracovani k odinstalaci Microsoft Edge..." # Bez diakritiky

    Write-Log "Pruvodce - Krok 3: Odinstalace Microsoft Edge" "INFO"
    Write-Host "`n--- Pruvodce: Krok 3/4 - Odinstalace Microsoft Edge ---`n" -ForegroundColor Green # Bez diakritiky
    Uninstall-Edge # Volame funkci (drive #5, nyni #6 v menu)
    Read-Host "`nPruvodce: Krok 3 dokoncen (nebo preskocen). Stisknete Enter pro pokracovani k ovladacum GPU..." # Bez diakritiky

    Write-Log "Pruvodce - Krok 4: Otevreni stranek pro ovladace GPU" "INFO"
    Write-Host "`n--- Pruvodce: Krok 4/4 - Otevreni stranek pro stazeni ovladacu GPU ---`n" -ForegroundColor Green # Bez diakritiky
    Show-DriverDownloadPages # Volame funkci (nyni #9 v menu)

    # Konec pruvodce - Nyni uz nic dalsiho nedelame, rizeni se vrati do hlavni smycky
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "            Pruvodce nastavenim byl dokoncen." -ForegroundColor Green # Bez diakritiky
    Write-Host "============================================================" -ForegroundColor Green
    Write-Log "Pruvodce nastavenim dokoncen." "INFO"
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
        [PSCustomObject]@{Poc=25; Nazev="RivaTuner";                 ID="RivaTuner.RTSS"}
        [PSCustomObject]@{Poc=26; Nazev="HWMonitor";                 ID="CPUID.HWMonitor"}
        [PSCustomObject]@{Poc=27; Nazev="WinRAR";                    ID="RARLab.WinRAR"}
        [PSCustomObject]@{Poc=28; Nazev="PrusaSlicer";               ID="Prusa3D.PrusaSlicer"}
        [PSCustomObject]@{Poc=29; Nazev="Bambu Studio";              ID="Bambulab.Bambustudio"}
        [PSCustomObject]@{Poc=30; Nazev="Arduino IDE";               ID="ArduinoSA.IDE.stable"}
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

# Funkce pro odinstalaci VYBRANYCH aplikaci Windows (Bloatware & More - S VYBEREM, Aktualizovany Seznam, Bez diakritiky)
# Funkce pro odinstalaci VYBRANYCH aplikaci Windows (Bloatware & More - S VYBEREM, Aktualizovany Seznam, Bez diakritiky, Tlacitka Vse/Nic)
function Uninstall-Bloatware {
    Clear-Host; Write-Log "Zahajena funkce Uninstall-Bloatware (v5 - tlacitka Vse/Nic)." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "   Odinstalace vybranych aplikaci Windows (Vyber ze seznamu)" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " /!\\ V A R O V A N I /!\\" -ForegroundColor Red -BackgroundColor Black
    Write-Host " TATO FUNKCE UMOZNUJE ODINSTALOVAT SIROKOU SKALU APLIKACI," -ForegroundColor Red
    Write-Host " VCETNE STANDARDNICH SOUCASTI WINDOWS A POTENCIALNE DULEZITYCH KOMPONENT." -ForegroundColor Red
    Write-Host " PECLIVE ZVAZTE KAZDOU POLOZKU, NEZ JI ZASKRTNETE K ODSTRANENI!" -ForegroundColor Red
    Write-Host " Odstraneni muze ovlivnit jine funkce systemu a je obtizne vratne!" -ForegroundColor Red
    Write-Host " Microsoft Edge NEBUDE odstranen touto volbou." -ForegroundColor Red
    Write-Host ""

    # Aktualizovany seznam aplikaci podle vaseho zadani, bez diakritiky
    $availableBloatware = @(
        [PSCustomObject]@{ Nazev = "3D Builder"; Pattern = "Microsoft.3DBuilder" }
        [PSCustomObject]@{ Nazev = "ACG Media Player"; Pattern = "ACGMediaPlayer" }
        [PSCustomObject]@{ Nazev = "Actipro Software LLC"; Pattern = "ActiproSoftwareLLC" } # Nejspis komponenta jine appky
        [PSCustomObject]@{ Nazev = "Adobe Photoshop Express"; Pattern = "AdobeSystemsIncorporated.AdobePhotoshopExpress" }
        [PSCustomObject]@{ Nazev = "Amazon (Aplikace)"; Pattern = "Amazon.com.Amazon" }
        [PSCustomObject]@{ Nazev = "Amazon Prime Video"; Pattern = "AmazonVideo.PrimeVideo" }
        [PSCustomObject]@{ Nazev = "Asphalt 8: Airborne"; Pattern = "Asphalt8Airborne" }
        [PSCustomObject]@{ Nazev = "Autodesk SketchBook"; Pattern = "AutodeskSketchBook" }
        [PSCustomObject]@{ Nazev = "Bubble Witch 3 Saga"; Pattern = "king.com.BubbleWitch3Saga" }
        [PSCustomObject]@{ Nazev = "Budik a hodiny"; Pattern = "Microsoft.WindowsAlarms" } # Soucast systemu
        [PSCustomObject]@{ Nazev = "Caesars Slots Free Casino"; Pattern = "CaesarsSlotsFreeCasino" }
        [PSCustomObject]@{ Nazev = "Candy Crush Saga"; Pattern = "king.com.CandyCrushSaga" }
        [PSCustomObject]@{ Nazev = "Candy Crush Soda Saga"; Pattern = "king.com.CandyCrushSodaSaga" }
        [PSCustomObject]@{ Nazev = "Centrum Office"; Pattern = "Microsoft.MicrosoftOfficeHub" }
        [PSCustomObject]@{ Nazev = "Cestovani"; Pattern = "Microsoft.BingTravel" }
        [PSCustomObject]@{ Nazev = "Clipchamp editor videa"; Pattern = "Clipchamp.Clipchamp" }
        [PSCustomObject]@{ Nazev = "Cooking Fever"; Pattern = "COOKINGFEVER" }
        [PSCustomObject]@{ Nazev = "CyberLink Media Suite Essentials"; Pattern = "CyberLinkMediaSuiteEssentials" }
        [PSCustomObject]@{ Nazev = "Dev Home"; Pattern = "Microsoft.Windows.DevHome" } # Pro vyvojare
        [PSCustomObject]@{ Nazev = "Disney (Obecna?)"; Pattern = "Disney" } # Muze byt prilis obecne
        [PSCustomObject]@{ Nazev = "Disney Magic Kingdoms"; Pattern = "DisneyMagicKingdoms" }
        [PSCustomObject]@{ Nazev = "Drawboard PDF"; Pattern = "DrawboardPDF" }
        [PSCustomObject]@{ Nazev = "Duolingo - Ucte se jazyky"; Pattern = "Duolingo-LearnLanguagesforFree" }
        [PSCustomObject]@{ Nazev = "Eclipse Manager"; Pattern = "EclipseManager" }
        [PSCustomObject]@{ Nazev = "Facebook"; Pattern = "Facebook" }
        [PSCustomObject]@{ Nazev = "FarmVille 2: Country Escape"; Pattern = "FarmVille2CountryEscape" }
        [PSCustomObject]@{ Nazev = "Feedback Hub"; Pattern = "Microsoft.WindowsFeedbackHub" }
        [PSCustomObject]@{ Nazev = "Filmy a TV porady"; Pattern = "Microsoft.ZuneVideo" }
        [PSCustomObject]@{ Nazev = "Finance"; Pattern = "Microsoft.BingFinance" }
        [PSCustomObject]@{ Nazev = "Fitbit"; Pattern = "fitbit" }
        [PSCustomObject]@{ Nazev = "Flipboard"; Pattern = "Flipboard" }
        [PSCustomObject]@{ Nazev = "Fotoaparat"; Pattern = "Microsoft.WindowsCamera" } # !! Pokud pouzivate kameru !!
        [PSCustomObject]@{ Nazev = "Hidden City"; Pattern = "HiddenCity" }
        [PSCustomObject]@{ Nazev = "Hudba Groove"; Pattern = "Microsoft.ZuneMusic" }
        [PSCustomObject]@{ Nazev = "Hulu Plus"; Pattern = "HULULLC.HULUPLUS" }
        [PSCustomObject]@{ Nazev = "iHeartRadio"; Pattern = "iHeartRadio" }
        [PSCustomObject]@{ Nazev = "Instagram"; Pattern = "Instagram" }
        [PSCustomObject]@{ Nazev = "Jidlo a piti"; Pattern = "Microsoft.BingFoodAndDrink" }
        [PSCustomObject]@{ Nazev = "Lide (Kontakty)"; Pattern = "Microsoft.People" } # !! Propojeno s Postou !!
        [PSCustomObject]@{ Nazev = "LinkedIn"; Pattern = "LinkedInforWindows" }
        [PSCustomObject]@{ Nazev = "Live Wallpaper (Sidia)"; Pattern = "Sidia.LiveWallpaper" }
        [PSCustomObject]@{ Nazev = "Mapy Windows"; Pattern = "Microsoft.WindowsMaps" }
        [PSCustomObject]@{ Nazev = "March of Empires"; Pattern = "MarchofEmpires" }
        [PSCustomObject]@{ Nazev = "Microsoft Family Safety"; Pattern = "MicrosoftCorporationII.MicrosoftFamily" }
        [PSCustomObject]@{ Nazev = "Microsoft Journal"; Pattern = "Microsoft.MicrosoftJournal" }
        [PSCustomObject]@{ Nazev = "Microsoft Power BI"; Pattern = "Microsoft.MicrosoftPowerBIForWindows" } # Nastroj pro analyzu dat
        [PSCustomObject]@{ Nazev = "Microsoft Solitaire Collection"; Pattern = "Microsoft.MicrosoftSolitaireCollection" }
        [PSCustomObject]@{ Nazev = "Microsoft Sway"; Pattern = "Microsoft.Office.Sway" }
        [PSCustomObject]@{ Nazev = "Microsoft Teams"; Pattern = "MicrosoftTeams" } # Muze byt vice zaznamu
        [PSCustomObject]@{ Nazev = "Microsoft To Do"; Pattern = "Microsoft.Todos" } # Muze byt uzitecne
        [PSCustomObject]@{ Nazev = "Microsoft Whiteboard"; Pattern = "Microsoft.Whiteboard" }
        [PSCustomObject]@{ Nazev = "Mixed Reality Portal"; Pattern = "Microsoft.MixedReality.Portal" }
        [PSCustomObject]@{ Nazev = "Mobilni tarify"; Pattern = "Microsoft.OneConnect" }
        [PSCustomObject]@{ Nazev = "MS Teams"; Pattern = "MSTeams" } # Muze byt vice zaznamu
        [PSCustomObject]@{ Nazev = "Netflix"; Pattern = "Netflix" }
        [PSCustomObject]@{ Nazev = "Neznama MS aplikace (549981C3F5F10)"; Pattern = "Microsoft.549981C3F5F10" } # !! Nejasne !!
        [PSCustomObject]@{ Nazev = "NYT Crossword"; Pattern = "NYTCrossword" }
        [PSCustomObject]@{ Nazev = "OneCalendar"; Pattern = "OneCalendar" }
        [PSCustomObject]@{ Nazev = "OneDrive"; Pattern = "Microsoft.OneDrive" } # !! Synchronizace souboru - VELMI OPATRNE !!
        [PSCustomObject]@{ Nazev = "OneNote"; Pattern = "Microsoft.Office.OneNote" } # !! Pozor, pokud pouzivate !!
        [PSCustomObject]@{ Nazev = "Outlook (Novy)"; Pattern = "Microsoft.OutlookForWindows" } # !! Pozor, pokud pouzivate !!
        [PSCustomObject]@{ Nazev = "Pandora"; Pattern = "PandoraMediaInc" }
        [PSCustomObject]@{ Nazev = "Phototastic Collage"; Pattern = "PhototasticCollage" }
        [PSCustomObject]@{ Nazev = "PicsArt Photo Studio"; Pattern = "PicsArt-PhotoStudio" }
        [PSCustomObject]@{ Nazev = "Plex"; Pattern = "Plex" }
        [PSCustomObject]@{ Nazev = "Pocasi"; Pattern = "Microsoft.BingWeather" }
        [PSCustomObject]@{ Nazev = "Polarr Photo Editor (Academic)"; Pattern = "PolarrPhotoEditorAcademicEdition" }
        [PSCustomObject]@{ Nazev = "Posta a Kalendar"; Pattern = "Microsoft.windowscommunicationsapps" } # !! Pokud pouzivate !!
        [PSCustomObject]@{ Nazev = "Power Automate Desktop"; Pattern = "Microsoft.PowerAutomateDesktop" } # Automatizacni nastroj
        [PSCustomObject]@{ Nazev = "Print 3D"; Pattern = "Microsoft.Print3D" }
        [PSCustomObject]@{ Nazev = "Prohlizec 3D objektu"; Pattern = "Microsoft.Microsoft3DViewer" }
        [PSCustomObject]@{ Nazev = "Propojeni s telefonem"; Pattern = "Microsoft.YourPhone" } # !! Propojeni s mobilem !!
        [PSCustomObject]@{ Nazev = "Propojeni zarizeni"; Pattern = "MicrosoftWindows.CrossDevice" } # Souvisi s propojenim
        [PSCustomObject]@{ Nazev = "Prekladac"; Pattern = "Microsoft.BingTranslator" }
        [PSCustomObject]@{ Nazev = "Royal Revolt"; Pattern = "Royal Revolt" } # Mezera muze byt problem
        [PSCustomObject]@{ Nazev = "Rychle poznamky"; Pattern = "Microsoft.MicrosoftStickyNotes" } # Muze byt uzitecne
        [PSCustomObject]@{ Nazev = "Rychly pomocnik"; Pattern = "MicrosoftCorporationII.QuickAssist" } # Nastroj pro vzdalenou pomoc
        [PSCustomObject]@{ Nazev = "Shazam"; Pattern = "Shazam" }
        [PSCustomObject]@{ Nazev = "Skype"; Pattern = "Microsoft.SkypeApp" }
        [PSCustomObject]@{ Nazev = "Sling TV"; Pattern = "SlingTV" }
        [PSCustomObject]@{ Nazev = "Sport"; Pattern = "Microsoft.BingSports" }
        [PSCustomObject]@{ Nazev = "Spotify"; Pattern = "Spotify" }
        [PSCustomObject]@{ Nazev = "Test rychlosti site"; Pattern = "Microsoft.NetworkSpeedTest" }
        [PSCustomObject]@{ Nazev = "TikTok"; Pattern = "TikTok" }
        [PSCustomObject]@{ Nazev = "TuneIn Radio"; Pattern = "TuneInRadio" }
        [PSCustomObject]@{ Nazev = "Twitter / X"; Pattern = "Twitter" }
        [PSCustomObject]@{ Nazev = "Viber"; Pattern = "Viber" }
        [PSCustomObject]@{ Nazev = "Vzdalena plocha"; Pattern = "Microsoft.RemoteDesktop" } # !! Pokud pouzivate !!
        [PSCustomObject]@{ Nazev = "Vyhledavani (Bing)"; Pattern = "Microsoft.BingSearch" }
        [PSCustomObject]@{ Nazev = "WinZip Universal"; Pattern = "WinZipUniversal" }
        [PSCustomObject]@{ Nazev = "Wunderlist"; Pattern = "Wunderlist" } # Ukoncena sluzba
        [PSCustomObject]@{ Nazev = "XING"; Pattern = "XING" }
        [PSCustomObject]@{ Nazev = "Xbox"; Pattern = "Microsoft.XboxApp" } # Potreba pro nektere hry/sluzby Xbox
        [PSCustomObject]@{ Nazev = "Zaznam zvuku"; Pattern = "Microsoft.WindowsSoundRecorder" } # Jednoduchy zaznamnik
        [PSCustomObject]@{ Nazev = "Zdravi a fitness"; Pattern = "Microsoft.BingHealthAndFitness" }
        [PSCustomObject]@{ Nazev = "Ziskat napovedu"; Pattern = "Microsoft.GetHelp" }
        [PSCustomObject]@{ Nazev = "Zpravy (Bing)"; Pattern = "Microsoft.BingNews" } # Muze byt vice (Bing/MS News)
        [PSCustomObject]@{ Nazev = "Zpravy (MS Messaging)"; Pattern = "Microsoft.Messaging" } # Odlisne od News
        [PSCustomObject]@{ Nazev = "Zpravy (MS News)"; Pattern = "Microsoft.News" } # Muze byt vice (Bing/MS News)

    ) | Sort-Object Nazev # Setridime podle nazvu pro lepsi prehlednost

    Write-Log "Pripraven rozsireny seznam aplikaci k vyberu pro odinstalaci (aktualizovany, bez diakritiky)." "DEBUG" -NoConsole

    # --- OKNO S CHECKBOXY PRO VYBER K ODINSTALACI ---
    $selectedAppsToUninstall = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Vyberte aplikace Windows k ODINSTALACI (VELMI OPATRNE!)"
        $form.Size = New-Object System.Drawing.Size(550, 600)
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $form.MaximizeBox = $true
        $form.MinimizeBox = $true

        $labelWarning = New-Object System.Windows.Forms.Label
        $labelWarning.Text = "VAROVANI: Odinstalace nekterych polozek muze poskodit system! Peclive vyberte." # Bez diakritiky
        $labelWarning.Dock = [System.Windows.Forms.DockStyle]::Top
        $labelWarning.ForeColor = [System.Drawing.Color]::Red
        $labelWarning.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $labelWarning.AutoSize = $true

        # --- Panel a Tlacitka (vcetne Vybrat vse / Zrusit vse) ---
        $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
        $buttonPanel.Height = 40
        $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft # Zarovna prvky doprava

        # Tlacitko OK
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "Odinstalovat vybrane" # Bez diakritiky
        $okButton.Size = New-Object System.Drawing.Size(150, 30)
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $okButton.Margin = New-Object System.Windows.Forms.Padding(3)

        # Tlacitko Storno
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Storno"
        $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $cancelButton.Margin = New-Object System.Windows.Forms.Padding(3)

        # *** NOVE TLACITKO: Vybrat vse ***
        $selectAllButton = New-Object System.Windows.Forms.Button
        $selectAllButton.Text = "Vybrat vse" # Bez diakritiky
        $selectAllButton.Size = New-Object System.Drawing.Size(100, 30)
        $selectAllButton.Margin = New-Object System.Windows.Forms.Padding(10, 3, 3, 3) # Vetsi levy margin pro odstup
        # Akce pro tlacitko Vybrat vse
        $selectAllButton.add_Click({
            for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                $checkedListBox.SetItemChecked($i, $true)
            }
        })

        # *** NOVE TLACITKO: Zrusit vse ***
        $deselectAllButton = New-Object System.Windows.Forms.Button
        $deselectAllButton.Text = "Zrusit vse" # Bez diakritiky
        $deselectAllButton.Size = New-Object System.Drawing.Size(100, 30)
        $deselectAllButton.Margin = New-Object System.Windows.Forms.Padding(3)
         # Akce pro tlacitko Zrusit vse
        $deselectAllButton.add_Click({
            for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
                $checkedListBox.SetItemChecked($i, $false)
            }
        })

        # Pridame tlacitka do FlowLayoutPanelu (Poradi pridani ovlivnuje poradi zobrazeni u RightToLeft!)
        $buttonPanel.Controls.Add($cancelButton)       # Uplne vpravo
        $buttonPanel.Controls.Add($okButton)           # Nalevo od Storno
        $buttonPanel.Controls.Add($deselectAllButton)  # Nalevo od OK
        $buttonPanel.Controls.Add($selectAllButton)    # Uplne vlevo

        # Nastavime Accept/Cancel pro funkcnost Enter/Escape
        $form.AcceptButton = $okButton
        $form.CancelButton = $cancelButton
        # --- Konec casti pro tlacitka ---

        # Seznam s checkboxy
        $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
        $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $checkedListBox.CheckOnClick = $true
        $checkedListBox.FormattingEnabled = $true

        # Naplneni seznamu
        $checkedListBox.DisplayMember = "Nazev" # Zobrazujeme Nazev bez diakritiky
        foreach ($app in $availableBloatware) {
            [void]$checkedListBox.Items.Add($app)
        }

        # Pridani prvku do okna
        $form.Controls.Add($checkedListBox)
        $form.Controls.Add($buttonPanel)
        $form.Controls.Add($labelWarning)

        Write-Host "Zobrazuji okno pro vyber aplikaci k ODINSTALACI..." -ForegroundColor Cyan # Bez diakritiky
        Write-Host "Pamatujte na VAROVANI!" -ForegroundColor Red # Bez diakritiky
        $result = $form.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedAppsToUninstall = @($checkedListBox.CheckedItems | ForEach-Object { $_ })
            if ($selectedAppsToUninstall -and $selectedAppsToUninstall.Count -gt 0) {
                 Write-Log "Uzivatel potvrdil vyber aplikaci k odinstalaci." "INFO" -NoConsole
            } else {
                $selectedAppsToUninstall = $null
                Write-Log "Uzivatel potvrdil OK, ale nevybral zadne aplikace." "WARN"
            }
        } else {
            $selectedAppsToUninstall = $null
            Write-Log "Uzivatel zrusil vyber aplikaci k odinstalaci (Storno nebo zavreni)." "INFO"
        }
        $form.Dispose()

    } catch {
        Write-Log "Chyba pri vytvareni/zpracovani okna pro vyber bloatware: $($_.Exception.Message)" "ERROR"
        Write-Error "Doslo k chybe pri praci s oknem pro vyber aplikaci: $($_.Exception.Message)" # Bez diakritiky
        $selectedAppsToUninstall = $null
    }

    # --- KONEC OKNA S CHECKBOXY ---

    # Zbytek funkce pro odinstalaci zustava stejny
    if ($null -eq $selectedAppsToUninstall) {
        Write-Log "Nebyly vybrany zadne aplikace k odinstalaci nebo byla akce zrusena." "WARN"
        Write-Host "`nNebyly vybrany zadne aplikace k odinstalaci. Akce zrusena." -ForegroundColor Yellow # Bez diakritiky
        return
    }

    Write-Host "`nBudou ODINSTALOVANY tyto aplikace:" -ForegroundColor Red # Bez diakritiky
    $selectedAppsToUninstall | ForEach-Object { Write-Host "  - $($_.Nazev) (Pattern: '$($_.Pattern)')" } # Nazev uz je bez diakritiky
    Write-Host ""

    if (-not (Get-Confirmation "OPRAVDU chcete pokracovat v ODINSTALACI techto vybranych aplikaci?")) {
        Write-Log "Odinstalace vybranych aplikaci Windows zrusena uzivatelem." "INFO"
        Write-Host "Odinstalace zrusena." -ForegroundColor Yellow # Bez diakritiky
        return
    }

    Write-Log "Zahajeni odinstalace vybranych aplikaci Windows." "INFO" -NoConsole
    Write-Host "`nSpoustim odinstalaci vybranych aplikaci pomoci PowerShell..." # Bez diakritiky
    Write-Host "Pripadne chyby (aplikace nenalezena, nelze odebrat) budou ignorovany..." # Bez diakritiky
    $uninstallErrors = 0

    foreach ($appToRemove in $selectedAppsToUninstall) {
        $pattern = $appToRemove.Pattern
        $appName = $appToRemove.Nazev
        Write-Host "----------------------------------------------"
        Write-Log "Pokus o odinstalaci '$appName' (vzor: '$pattern')." "INFO" -NoConsole
        Write-Host "Pokousim se odinstalovat: $appName (vzor: '$pattern')..." # Bez diakritiky
        $packageRemovedCount = 0
        try {
             $packages = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
             if (-not $packages) {
                 $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$pattern*" -or $_.PackageFullName -like "*$pattern*" -or $_.PackageFamilyName -like "*$pattern*" }
             }

            if ($packages) {
                foreach ($package in $packages) {
                    Write-Log "  Odstranuji: $($package.Name) ($($package.PackageFullName))" "DEBUG" -NoConsole
                    Write-Host "  Odstranuji: $($package.Name) ($($package.PackageFullName))" # Bez diakritiky
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                    if ($LASTEXITCODE -ne 0) {
                        Write-Log "  Chyba pri odstranovani $($package.PackageFullName) (Kod $LASTEXITCODE)" "WARN" # Bez diakritiky
                    } else {
                        $packageRemovedCount++
                    }
                    Start-Sleep -Milliseconds 100
                }
                if ($packageRemovedCount -gt 0) {
                    Write-Log "  Uspesne odstraneno $packageRemovedCount balicku pro '$appName' (vzor '$pattern')." "INFO" -NoConsole # Bez diakritiky
                    Write-Host "  Uspesne odstraneno $packageRemovedCount balicku pro '$appName'." -ForegroundColor Green # Bez diakritiky
                } else {
                    Write-Log "  Nepodarilo se odstranit zadny nalezany balicek pro '$appName' (vzor '$pattern')." "WARN" -NoConsole # Bez diakritiky
                    Write-Warning "  Nepodarilo se odstranit zadny nalezany balicek pro '$appName'." # Bez diakritiky
                    $uninstallErrors++
                }
            } else {
                Write-Log "  Nenalezeny zadne nainstalovane balicky pro '$appName' (vzor '$pattern')." "INFO" -NoConsole # Bez diakritiky
                Write-Host "  Nenalezeny zadne nainstalovane balicky pro '$appName'." -ForegroundColor Gray # Bez diakritiky
            }
        } catch {
            Write-Log "  Doslo k obecne chybe pri zpracovani '$appName': $($_.Exception.Message)" "ERROR" # Bez diakritiky
            Write-Warning "  Doslo k obecne chybe pri zpracovani '$appName': $($_.Exception.Message)" # Bez diakritiky
            $uninstallErrors++
        }
         Write-Host "----------------------------------------------`n"
    }

    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Log "Odinstalace vybranych aplikaci Windows dokoncena." "INFO"
    if ($uninstallErrors -eq 0) {
         Write-Host "Pokus o odinstalaci vybranych aplikaci dokoncen." -ForegroundColor Green # Bez diakritiky
         Write-Host "(Pripadne neuspesne odstraneni jednotlivych balicku viz log)." -ForegroundColor Gray # Bez diakritiky
    } else {
        Write-Warning "Pokus o odinstalaci vybranych aplikaci dokoncen s $uninstallErrors chybami behem zpracovani (viz log)." # Bez diakritiky
    }
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "Pro uplne projeveni zmen muze byt potreba restartovat pocitac." # Bez diakritiky
    Write-Log "Ukoncena funkce Uninstall-Bloatware (v5 - tlacitka Vse/Nic)." "INFO" -NoConsole
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

# Funkce pro zobrazeni oficialnich stranek ke stazeni ovladacu GPU (Cista verze bez Choco/Chipset)
function Show-DriverDownloadPages {
    Clear-Host; Write-Log "Zahajena funkce Show-DriverDownloadPages." "INFO" -NoConsole
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "         Otevreni stranek pro stazeni ovladacu GPU" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tato funkce detekuje vyrobce vasich grafickych karet (Nvidia/AMD/Intel)" # Bez diakritiky
    Write-Host "a pokusi se otevrit oficialni stranky pro stazeni ovladacu ve vasem prohlizeci." # Bez diakritiky
    Write-Host "Samotny skript zadne ovladace neinstaluje." # Bez diakritiky
    Write-Host ""

    # 1. Detekce GPU (pouzivame globalni promennou $sysInfoGPU)
    Write-Host "Detekuji graficke karty..." -ForegroundColor Gray # Bez diakritiky
    Write-Log "Detekuji GPU z: $($sysInfoGPU -join '; ')" "INFO" -NoConsole

    $hasNvidia = $sysInfoGPU | Where-Object { $_ -like '*NVIDIA*' -or $_ -like '*GeForce*' }
    $hasAmdGpu = $sysInfoGPU | Where-Object { $_ -like '*AMD*' -or $_ -like '*Radeon*' }
    $hasIntelGpu = $sysInfoGPU | Where-Object { $_ -like '*Intel*' -and ($_ -like '*HD Graphics*' -or $_ -like '*UHD Graphics*' -or $_ -like '*Iris*' -or $_ -like '*Arc*') }
    # $hasIntelGpu = $sysInfoGPU | Where-Object { $_ -like '*Intel*' } # Pripadne jednodussi detekce Intelu

    $pageOpened = $false # Praporek, zda jsme otevřeli aspon jednu stranku

    # Definice URL adres
    $nvidiaUrl = "https://www.nvidia.com/en-us/drivers/"
    $amdUrl = "https://www.amd.com/en/support/download/drivers.html"
    $intelUrl = "https://www.intel.com/content/www/us/en/download-center/home.html"

    # 2. Otevreni stranek podle detekce
    if ($hasNvidia) {
        Write-Host "- Nalezena graficka karta NVIDIA." -ForegroundColor Green # Bez diakritiky
        Write-Host "  Oteviram stranku Nvidia pro stazeni ovladacu..." -ForegroundColor Cyan # Bez diakritiky
        Write-Log "Detekovana NVIDIA GPU. Oteviram $nvidiaUrl" "INFO" -NoConsole
        try {
            Start-Process $nvidiaUrl
            $pageOpened = $true
            Start-Sleep -Seconds 1 # Mala pauza mezi otviranim
        } catch {
            Write-Log "Chyba pri otevirani stranky NVIDIA: $($_.Exception.Message)" "ERROR"
            Write-Warning "Nepodarilo se otevrit stranku NVIDIA: $($_.Exception.Message)"
        }
    }

    if ($hasAmdGpu) {
        Write-Host "- Nalezena graficka karta AMD." -ForegroundColor Green # Bez diakritiky
        Write-Host "  Oteviram stranku AMD pro stazeni ovladacu..." -ForegroundColor Cyan # Bez diakritiky
        Write-Log "Detekovana AMD GPU. Oteviram $amdUrl" "INFO" -NoConsole
        try {
            Start-Process $amdUrl
            $pageOpened = $true
            Start-Sleep -Seconds 1 # Mala pauza mezi otviranim
        } catch {
            Write-Log "Chyba pri otevirani stranky AMD: $($_.Exception.Message)" "ERROR"
            Write-Warning "Nepodarilo se otevrit stranku AMD: $($_.Exception.Message)"
        }
    }

    if ($hasIntelGpu) {
        Write-Host "- Nalezena graficka karta Intel." -ForegroundColor Green
        Write-Host "  Oteviram stranku Intel pro stazeni ovladacu..." -ForegroundColor Cyan
        Write-Log "Detekovana Intel GPU. Oteviram $intelUrl" "INFO" -NoConsole
        try {
            Start-Process $intelUrl
            $pageOpened = $true
            Start-Sleep -Seconds 2 # Mala pauza mezi otviranim
        } catch {
            Write-Log "Chyba pri otevirani stranky Intel: $($_.Exception.Message)" "ERROR"
            Write-Warning "Nepodarilo se otevrit stranku Intel: $($_.Exception.Message)"
        }
    }

    # 3. Zprava pokud nic nebylo nalezeno/otevreno
    if (-not $pageOpened) {
        Write-Host "`nNepodarilo se detekovat grafickou kartu Nvidia, AMD nebo Intel," -ForegroundColor Yellow # Bez diakritiky
        Write-Host "nebo nastala chyba pri otevirani stranek." -ForegroundColor Yellow # Bez diakritiky
        Write-Log "Nebyly detekovany podporovane GPU nebo nastala chyba pri otevirani URL." "WARN"
    } else {
         Write-Host "`nStranky vyrobcu byly otevreny ve vasem vychozim webovem prohlizeci." -ForegroundColor Green # Bez diakritiky
    }

    Write-Log "Ukoncena funkce Show-DriverDownloadPages." "INFO" -NoConsole
}

# Funkce pro upravu vybranych nastaveni Windows (Vzhled, Chovani - s vyberem A/N pro kazdou sekci)
function NastavitVzhledAChovani {
    Clear-Host; Write-Log "Zahajena funkce NastavitVzhledAChovani (v2.1 - oprava chyby TaskbarDa)." "INFO" -NoConsole # Bez diakritiky
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "         Uprava vybranych nastaveni Vzhledu a Chovani" -ForegroundColor Cyan # Bez diakritiky
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host
    Write-Host "Tato funkce vam umozni upravit nasledujici nastaveni:" # Bez diakritiky
    Write-Host "  - UAC (Rizeni uzivatelskych uctu) - Nastaveni na nejnizsi uroven." # Bez diakritiky
    Write-Host "    /!\\ VAROVANI: Toto snizuje zabezpeceni systemu! /!\\" -ForegroundColor Red # Bez diakritiky
    Write-Host "  - Barevne rezimy - Rezim Windows na TMAVY, Rezim Aplikaci na SVETLY." # Bez diakritiky
    Write-Host "  - Hlavni panel - Skryti tlacitek Vyhledavani, Zobrazeni ukolu a Widgety." # Bez diakritiky
    Write-Host
    Write-Host "Pred kazdou skupinou zmen budete dotazani na potvrzeni (A/N)." # Bez diakritiky
    Write-Host "Pro projeveni vsech provedenych zmen muze byt VYŽADOVÁN RESTART pocitace!" -ForegroundColor Yellow # Bez diakritiky
    Write-Host

    $restartNeeded = $false
    $changeMade = $false

    # --- Sekce UAC ---
    Write-Host "`n--- Nastaveni UAC ---" -ForegroundColor Cyan
    if (Get-Confirmation "Chcete nastavit UAC na nejnizsi uroven (Nikdy neupozornovat)? (NEDOPORUCUJE SE!)") { # Bez diakritiky
        Write-Log "Uzivatel potvrdil zmenu nastaveni UAC." "WARN"
        $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        $uacValueName = 'ConsentPromptBehaviorAdmin'
        try {
            Write-Host "- Nastavuji UAC (ConsentPromptBehaviorAdmin = 0)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $uacPath -Name $uacValueName -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Host "  OK (UAC nastaveno, vyzaduje restart)" -ForegroundColor Green # Bez diakritiky
            Write-Log "REG: UAC [$uacPath - $uacValueName] nastaveno na 0 (Never Notify)." "WARN"
            $restartNeeded = $true
            $changeMade = $true
        } catch {
            Write-Log "REG Chyba: Nepodarilo se nastavit UAC [$uacPath - $uacValueName] na 0: $($_.Exception.Message)" "ERROR"
            Write-Error "Chyba pri nastavovani UAC: $($_.Exception.Message)" # Bez diakritiky
        }
    } else {
        Write-Log "Nastaveni UAC preskoceno uzivatelem." "INFO"
        Write-Host "- Nastaveni UAC preskoceno." -ForegroundColor Yellow # Bez diakritiky
    }
    Start-Sleep -Milliseconds 500

    # --- Sekce Barevne rezimy ---
    Write-Host "`n--- Nastaveni Barevnych rezimu ---" -ForegroundColor Cyan # Bez diakritiky
    if (Get-Confirmation "Chcete nastavit Rezim Windows na TMAVY a Rezim Aplikaci na SVETLY?") { # Bez diakritiky
        Write-Log "Uzivatel potvrdil zmenu barevnych rezimu." "INFO"
        $themePath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        $colorChangeOk = $true
        try {
            Write-Host "- Nastavuji Rezim aplikaci na Svetly (AppsUseLightTheme = 1)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $themePath -Name 'AppsUseLightTheme' -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Log "REG: Vzhled [$themePath - AppsUseLightTheme] nastaveno na 1 (Svetly)." "INFO"
        } catch {
            Write-Log "REG Chyba: Nepodarilo se nastavit AppsUseLightTheme=1: $($_.Exception.Message)" "ERROR"
            Write-Error "Chyba pri nastavovani rezimu aplikaci: $($_.Exception.Message)" # Bez diakritiky
            $colorChangeOk = $false
        }
        Start-Sleep -Milliseconds 200
        try {
            Write-Host "- Nastavuji Rezim Windows na Tmavy (SystemUsesLightTheme = 0)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $themePath -Name 'SystemUsesLightTheme' -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "REG: Vzhled [$themePath - SystemUsesLightTheme] nastaveno na 0 (Tmavy)." "INFO"
        } catch {
            Write-Log "REG Chyba: Nepodarilo se nastavit SystemUsesLightTheme=0: $($_.Exception.Message)" "ERROR"
            Write-Error "Chyba pri nastavovani rezimu Windows: $($_.Exception.Message)" # Bez diakritiky
            $colorChangeOk = $false
        }

        if ($colorChangeOk) {
             Write-Host "  OK (Barevne rezimy nastaveny)" -ForegroundColor Green # Bez diakritiky
             $restartNeeded = $true
             $changeMade = $true
        }

    } else {
        Write-Log "Nastaveni barevnych rezimu preskoceno uzivatelem." "INFO"
        Write-Host "- Nastaveni barevnych rezimu preskoceno." -ForegroundColor Yellow # Bez diakritiky
    }
    Start-Sleep -Milliseconds 500

    # --- Sekce Hlavni panel ---
    Write-Host "`n--- Nastaveni Hlavniho panelu ---" -ForegroundColor Cyan # Bez diakritiky
    if (Get-Confirmation "Chcete skryt tlacitka Vyhledavani, Zobrazeni ukolu a Widgety?") { # Bez diakritiky
        Write-Log "Uzivatel potvrdil zmenu nastaveni hlavniho panelu." "INFO"
        $searchPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        $explorerAdvancedPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        $taskbarChangeOk = $true
        try {
            Write-Host "- Skryvam Vyhledavani (SearchboxTaskbarMode = 0)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $searchPath -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "REG: Taskbar [$searchPath - SearchboxTaskbarMode] nastaveno na 0 (Skryto)." "INFO"
        } catch { Write-Log "REG Chyba: Nepodarilo se nastavit SearchboxTaskbarMode=0: $($_.Exception.Message)" "ERROR"; Write-Error "Chyba pri skryvani Vyhledavani: $($_.Exception.Message)"; $taskbarChangeOk = $false } # Bez diakritiky
        Start-Sleep -Milliseconds 200
        try {
            Write-Host "- Skryvam Zobrazeni ukolu (TaskbarMn = 0)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $explorerAdvancedPath -Name 'TaskbarMn' -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Log "REG: Taskbar [$explorerAdvancedPath - TaskbarMn] nastaveno na 0 (Skryto)." "INFO"
        } catch { Write-Log "REG Chyba: Nepodarilo se nastavit TaskbarMn=0: $($_.Exception.Message)" "ERROR"; Write-Error "Chyba pri skryvani Zobrazeni ukolu: $($_.Exception.Message)"; $taskbarChangeOk = $false } # Bez diakritiky
        Start-Sleep -Milliseconds 200

        # *** ZDE JE ZMENA - ErrorAction SilentlyContinue a upraveny catch blok ***
        try {
            Write-Host "- Skryvam Widgety (TaskbarDa = 0)..." -ForegroundColor Gray # Bez diakritiky
            Set-ItemProperty -Path $explorerAdvancedPath -Name 'TaskbarDa' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue # <- ZMENA ZDE
            # Kontrola, zda prikaz vyvolal chybu, i kdyz jsme ji potlacili
            if ($?) { # $? obsahuje stav uspesnosti posledniho prikazu
                 Write-Log "REG: Taskbar [$explorerAdvancedPath - TaskbarDa] nastaveno na 0 (Skryto)." "INFO"
            } else {
                 # Pokud $? je $false, prikaz selhal i pres SilentlyContinue
                 Write-Log "REG Chyba: Nepodarilo se nastavit TaskbarDa=0 (pravdepodobne opravneni nebo GPO)." "ERROR" # Bez diakritiky
                 Write-Warning "  Nepodarilo se skryt Widgety - operace byla systemem blokovana." # Bez diakritiky
                 $taskbarChangeOk = $false
            }
        } catch {
            # Tento catch by se uz nemel provest kvuli SilentlyContinue, ale pro jistotu
            Write-Log "REG Chyba (catch blok): Nepodarilo se nastavit TaskbarDa=0: $($_.Exception.Message)" "ERROR"
            Write-Warning "  Nepodarilo se skryt Widgety: $($_.Exception.Message)" # Bez diakritiky
            $taskbarChangeOk = $false
        }
        # *** KONEC ZMENY ***

        if ($taskbarChangeOk) {
             Write-Host "  OK (Nastaveni hlavniho panelu provedeno, krome pripadnych chyb vyse)" -ForegroundColor Green # Bez diakritiky
             $restartNeeded = $true
             $changeMade = $true
        }

    } else {
        Write-Log "Nastaveni hlavniho panelu preskoceno uzivatelem." "INFO"
        Write-Host "- Nastaveni hlavniho panelu preskoceno." -ForegroundColor Yellow # Bez diakritiky
    }

    # --- Zaverecne Upozorneni ---
    Write-Host "`n------------------------------------------------------------"
    if ($changeMade) {
        Write-Host "Pozadovane upravy byly provedeny (nebo byl zaznamenan pokus)." -ForegroundColor Green # Bez diakritiky
        if ($restartNeeded) {
            Write-Host "Pro plne projeveni provedenych zmen je NUTNY RESTART pocitace!" -ForegroundColor Yellow -BackgroundColor Black # Bez diakritiky
            Write-Log "Funkce NastavitVzhledAChovani dokoncena. Byl upozornen na nutnost restartu." "INFO"
        } else {
             Write-Host "Provedene zmeny nevyzaduji restart." -ForegroundColor Green # Bez diakritiky
             Write-Log "Funkce NastavitVzhledAChovani dokoncena. Nebyly provedeny zmeny vyzadujici restart." "INFO"
        }
    } else {
        Write-Host "Nebyly provedeny zadne zmeny nastaveni." -ForegroundColor Yellow # Bez diakritiky
    }
    Write-Host "------------------------------------------------------------"
    # Zde uz nevolame Invoke-RestartAndRelaunchCheck, protoze tato verze kodu ji nema
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
    Write-Host " GPU: $($sysInfoGPU -join ', ')" -ForegroundColor White
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # --- Menu ---
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   WindowsAppTool (PowerShell verze)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Vyberte pozadovanou akci:" # Bez diakritiky
    Write-Host "  1. Pruvodce nastavenim" # Bez diakritiky
    Write-Host "  ---------------------------------"
    Write-Host "  2. Instalovat vybrane aplikace" # Drive 1 Bez diakritiky
    Write-Host "  3. Aktualizovat vsechny aplikace" # Drive 2 Bez diakritiky
    Write-Host "  4. Aktualizovat Winget (Instalator aplikaci)" # Drive 3 Bez diakritiky
    Write-Host "  5. Odinstalovat aplikace Windows (Vyber)" # Drive 4 Bez diakritiky
    Write-Host "  6. Odinstalovat Microsoft Edge" # Drive 5 Bez diakritiky
    Write-Host "  7. Zobrazit typ licence Windows" # Drive 6 Bez diakritiky
    Write-Host "  8. Odinstalovat specifickou aplikaci (Vyber)" # Drive 7 Bez diakritiky
    Write-Host "  9. Otevrit stranky pro stazeni ovladacu GPU" # Drive 9 - zustava Bez diakritiky
    Write-Host "  10. Upravit vzhled a chovani Windows" # << NOVA POLOZKA Bez diakritiky
    Write-Host "  11. Konec" # << Drive 10 (puvodne 8) Bez diakritiky
    Write-Host ""
    $choice = Read-Host "Zadejte cislo volby (1-11)" # << ZMENA ROZSAHU Bez diakritiky
    Write-Log "Uzivatel zvolil v menu moznost: $choice" "INFO"

    try {
        switch ($choice) {
            "1" { Start-WizardMode }
            "2" { Install-BasicApps }
            "3" { Update-AllApps }
            "4" { Update-Winget }
            "5" { Uninstall-Bloatware }
            "6" { Uninstall-Edge }
            "7" { Show-WindowsLicenseType }
            "8" { Uninstall-SelectedApps }
            "9" { Show-DriverDownloadPages }
            "10" { NastavitVzhledAChovani }   # << NOVY CASE
            "11" {                           # << ZMENA CISLA
                Write-Log "Uzivatel zvolil konec skriptu. Ukoncuji." "INFO"
                Write-Host "Skript ukoncen." # Bez diakritiky
                exit 0
            }
            default {
                Write-Log "Neplatna volba menu: '$choice'." "WARN"
                Write-Warning "Neplatna volba '$choice'. Zkuste to znovu." # Bez diakritiky
                Start-Sleep -Seconds 2
            }
        }# end switch

        # Pockame na uzivatele pred zobrazenim menu znovu (pokud jsme neukoncili pres exit)
         Read-Host "`nAkce dokoncena. Stisknete Enter pro navrat do hlavniho menu..." # Bez diakritiky

    } catch {
         $logMsg = "`n! NEOCEKAVANA CHYBA SKRIPTU: $($_.Exception.Message) | Cil: $($_.TargetObject) | Radek: $($_.InvocationInfo.ScriptLineNumber)" # Bez diakritiky
         Write-Log $logMsg "ERROR"
         Write-Error $logMsg
         Read-Host "Stisknete Enter pro navrat do hlavniho menu..." # Bez diakritiky
    }

} while (-not $exitLoop)
# --- Konec skriptu ---
Write-Log "================ Ukonceni logovani skriptu ================" "INFO"