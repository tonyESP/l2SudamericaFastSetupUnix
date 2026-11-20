@echo off
setlocal enabledelayedexpansion
title Lineage 2 Sudamerica - Optimizador Windows

echo ==============================================================================
echo       LINEAGE 2 SUDAMERICA - OPTIMIZADOR REMASTER / ASEDIO (WINDOWS)
echo ==============================================================================
echo.
echo Este script aplica las configuraciones calibradas de Option.ini y DXVK.
echo.

set /p CLIENT_DIR="Introduce la ruta a la carpeta del juego (ej: C:\L2Sudamerica) o presiona Enter para usar la carpeta actual: "
if "%CLIENT_DIR%"=="" set CLIENT_DIR=%CD%

if not exist "%CLIENT_DIR%\system\L2.exe" (
    if not exist "%CLIENT_DIR%\system\l2.exe" (
        echo [ERROR] No se encontro system\L2.exe en: %CLIENT_DIR%
        echo Verifica la ruta y vuelve a ejecutar este script.
        pause
        exit /b 1
    )
)

echo.
echo Selecciona el perfil a aplicar:
echo   1. Perfil Diario Remaster (Vision ampliada Pawn=6.0, StaticMesh=8.0, Agua alta, Maxima calidad)
echo   2. Perfil Asedios / Mass PvP (Ultra-FPS, sombras desactivadas, ModelDetail=1, 0 bajones)
echo.
set /p PROFILE_CHOICE="Opcion (1 o 2): "

if not exist "%CLIENT_DIR%\system\Option.ini.bak" (
    if exist "%CLIENT_DIR%\system\Option.ini" (
        copy /y "%CLIENT_DIR%\system\Option.ini" "%CLIENT_DIR%\system\Option.ini.bak" >nul
        echo [INFO] Respaldo creado en: %CLIENT_DIR%\system\Option.ini.bak
    )
)

if "%PROFILE_CHOICE%"=="2" (
    copy /y "%~dp0config\Option.siege.ini.template" "%CLIENT_DIR%\system\Option.ini" >nul
    copy /y "%~dp0config\dxvk.siege.conf.template" "%CLIENT_DIR%\system\dxvk.conf" >nul
    echo [OK] Perfil Asedios Ultra-FPS inyectado en system\Option.ini y system\dxvk.conf
) else (
    copy /y "%~dp0config\Option.optimized.ini.template" "%CLIENT_DIR%\system\Option.ini" >nul
    copy /y "%~dp0config\dxvk.conf.template" "%CLIENT_DIR%\system\dxvk.conf" >nul
    echo [OK] Perfil Remaster Extreme inyectado en system\Option.ini y system\dxvk.conf
)

echo.
echo ==============================================================================
echo Optimizacion completada con exito. Ya puedes abrir Lineage 2 normalmente.
echo ==============================================================================
pause
