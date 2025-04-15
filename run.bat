@echo off
:: Zjisteni, zda skript bezi s pravy administratora pomoci PowerShellu
powershell -NoProfile -Command "if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 1 }" >nul 2>&1

:: Pokud predchozi prikaz selhal (errorlevel NENI 0), znamena to, ze nejsme admin
if '%errorlevel%' NEQ '0' (
    echo Pozaduji administratorska prava...
    :: Znovu spustime tento .bat soubor, ale s vyzvanim o prava admina
    powershell Start-Process -FilePath "%~f0" -Verb RunAs
    :: Ukoncime puvodni beh bez prav
    exit /b
)

:: --- Pokud jsme zde, mame prava administratora ---
echo.
echo Spoustim PowerShell skript 'WindowsAppTool'...
echo (Pokud se okno zavre, zkontrolujte, zda soubor .ps1 existuje ve stejne slozce)
echo.

:: Spustime PowerShell skript (upravte nazev souboru, pokud je jiny!)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0WindowsAppTool.ps1"
echo.
echo ---------------------------------------------------
echo PowerShell skript byl dokoncen.
echo Stisknete libovolnou klavesu pro zavreni tohoto okna.