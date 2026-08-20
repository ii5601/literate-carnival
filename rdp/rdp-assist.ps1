[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$ConfigPath = "$PSScriptRoot\config.json"
$ReadmePath = "$env:USERPROFILE\Desktop\readme.txt"

# Инициализируем переменные автонастройки
$AutoDarkTheme = $null
$AutoWallpaper = $null
$AutoApps = $null
$SilentMode = $false

# Проверяем и читаем конфиг предустановки
if (Test-Path $ConfigPath) {
    try {
        $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        if ($Config) {
            $AutoDarkTheme = $Config.DarkTheme
            $AutoWallpaper = $Config.CustomWallpaper
            $AutoApps = $Config.InstallApps
            $SilentMode = $true
            Write-Host "[Предустановка] Найден файл конфигурации. Включаем автоматический режим." -ForegroundColor Magent
        }
    } catch {
        Write-Host "[Предустановка] Ошибка чтения config.json, переходим в интерактивный режим." -ForegroundColor Yellow
    }
}

# Создание readme.txt
$ReadmeContent = @"
==================================================
Добро пожаловать в рабочую среду RDP!
==================================================
Этот скрипт настроил ваш профиль автоматически или запросит параметры.
"@
if (-not (Test-Path $ReadmePath)) {
    New-Item -Path $ReadmePath -ItemType File -Value $ReadmeContent -Force | Out-Null
}

Clear-Host
Write-Host (Get-Content -Path $ReadmePath -Raw) -ForegroundColor Cyan
Write-Host "`n--------------------------------------------------`n"

# Функция для вопросов (используется, только если нет авто-конфига)
function Get-YnAnswer ($Question, $DefaultValue) {
    if ($SilentMode -and ($DefaultValue -ne $null)) { return $DefaultValue }
    while ($true) {
        $ans = Read-Host "$Question (Д/Н)"
        if ($ans -match '^[ДдYy]') { return $true }
        if ($ans -match '^[НнNn]') { return $false }
        Write-Host "Пожалуйста, введите Д (Да) или Н (Нет)." -ForegroundColor Yellow
    }
}

# 1. Темная тема
if (Get-YnAnswer "Хотите включить темную тему Windows?" $AutoDarkTheme) {
    Write-Host "Включаю темную тему..." -ForegroundColor Green
    $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty -Path $RegistryPath -Name "AppsUseLightTheme" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $RegistryPath -Name "SystemUsesLightTheme" -Value 0 -ErrorAction SilentlyContinue
}

# 2. Кастомные обои
if (Get-YnAnswer "Хотите установить кастомные обои?" $AutoWallpaper) {
    $WallpaperPath = "C:\Windows\Web\Wallpaper\Windows\img0.jpg" 
    if (Test-Path $WallpaperPath) {
        Write-Host "Устанавливаю обои..." -ForegroundColor Green
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $WallpaperPath
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "2"
        
        $UpdateCode = @"
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        Add-Type -TypeDefinition $UpdateCode -ErrorAction SilentlyContinue
        [Wallpaper]::SystemParametersInfo(20, 0, $WallpaperPath, 3) | Out-Null
    } else {
        Write-Host "Файл обоев по пути $WallpaperPath не найден!" -ForegroundColor Red
    }
}

# 3. Приложения
$Selection = $AutoApps
if (-not $SilentMode) {
    if (Get-YnAnswer "Хотите выбрать и установить дополнительные приложения?" $false) {
        Write-Host "`nДоступные приложения для установки:`n1. Google Chrome`n2. Notepad++`n3. 7-Zip"
        $Selection = Read-Host "Введите номера приложений через запятую (например: 1,3)"
    }
}

if ($Selection) {
    if ($Selection -like "*1*") { 
        Write-Host "Установка Google Chrome..." -ForegroundColor Green
        Start-Process winget -ArgumentList "install --id Google.Chrome --silent --accept-source-agreements --accept-package-agreements" -Wait 
    }
    if ($Selection -like "*2*") { 
        Write-Host "Установка Notepad++..." -ForegroundColor Green
        Start-Process winget -ArgumentList "install --id Notepad++.Notepad++ --silent --accept-source-agreements --accept-package-agreements" -Wait 
    }
    if ($Selection -like "*3*") { 
        Write-Host "Установка 7-Zip..." -ForegroundColor Green
        Start-Process winget -ArgumentList "install --id 7zip.7zip --silent --accept-source-agreements --accept-package-agreements" -Wait 
    }
}

# Язык системы
Write-Host "`nНастройка русского языка как основного..." -ForegroundColor Green
Set-Culture ru-RU
Set-UiCulture ru-RU
Set-WinUserLanguageList -LanguageList (New-WinUserLanguageList -Language "ru-RU") -Force

Write-Host "`nНастройка завершена!" -ForegroundColor Cyan
if (-not $SilentMode) {
    Write-Host "Нажмите любую клавишу для выхода."
    [void][System.Console]::ReadKey()
} else {
    Start-Sleep -Seconds 3 # Даем 3 секунды посмотреть логи в тихом режиме перед закрытием
}
