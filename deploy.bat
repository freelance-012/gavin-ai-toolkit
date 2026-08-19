@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  Gavin AI Toolkit - Deploy Script (Windows)
::  Usage: deploy.bat <platform> <scope> [PATH]
::  Platform: codebuddy | claude
::  Scope:   user | project
:: ============================================================

set "SOURCE_DIR=%~dp0skills\slam-code-reader"

set "PLATFORM=%~1"
set "SCOPE=%~2"
set "PROJECT_PATH=%~3"

:: --- Help ---
if "%PLATFORM%"=="" (
    echo ===========================================
    echo   Gavin AI Toolkit - Deploy Tool
    echo ===========================================
    echo.
    echo   Usage: deploy.bat ^<platform^> ^<scope^> [path]
    echo.
    echo   Platform: codebuddy ^| claude
    echo   Scope:   user ^| project
    echo.
    echo   Examples:
    echo     deploy.bat codebuddy user
    echo     deploy.bat codebuddy project D:\my-project
    echo     deploy.bat claude project D:\my-project
    echo ===========================================
    exit /b 0
)

:: --- Validate Platform ---
if /i not "%PLATFORM%"=="codebuddy" if /i not "%PLATFORM%"=="claude" (
    echo [ERROR] Unknown platform '%PLATFORM%'
    exit /b 1
)

:: --- Determine Target ---
if /i "%PLATFORM%"=="codebuddy" (
    if /i "%SCOPE%"=="user" (
        set "TARGET_DIR=%USERPROFILE%\.codebuddy\skills\slam-code-reader"
    ) else if /i "%SCOPE%"=="project" (
        call :check_project_path
        set "TARGET_DIR=%PROJECT_PATH%\.codebuddy\skills\slam-code-reader"
    ) else (
        echo [ERROR] Unknown scope '%SCOPE%'
        exit /b 1
    )
) else if /i "%PLATFORM%"=="claude" (
    if /i "%SCOPE%"=="user" (
        set "TARGET_DIR=%USERPROFILE%\.claude\commands"
    ) else if /i "%SCOPE%"=="project" (
        call :check_project_path
        set "TARGET_DIR=%PROJECT_PATH%\.claude\commands"
    ) else (
        echo [ERROR] Unknown scope '%SCOPE%'
        exit /b 1
    )
)

echo [INFO] Platform: %PLATFORM%
echo [INFO] Scope: %SCOPE%
echo [INFO] Target: %TARGET_DIR%
echo [INFO] Source: %SOURCE_DIR%
echo.

:: --- Check Source ---
if not exist "%SOURCE_DIR%\SKILL.md" (
    echo [ERROR] SKILL.md not found at %SOURCE_DIR%
    exit /b 1
)

:: --- Deploy ---
if /i "%PLATFORM%"=="codebuddy" (
    call :deploy_codebuddy
) else (
    call :deploy_claude
)

echo.
echo [OK] Done.
goto :eof

:: ============================================================
::  Sub: Check project path exists
:: ============================================================
:check_project_path
if "%PROJECT_PATH%"=="" (
    echo [ERROR] Project path required for project-level deployment
    exit /b 1
)
if not exist "%PROJECT_PATH%" (
    echo [ERROR] Project path does not exist: %PROJECT_PATH%
    exit /b 1
)
goto :eof

:: ============================================================
::  Sub: Deploy to CodeBuddy (Junction or Copy)
:: ============================================================
:deploy_codebuddy
if exist "%TARGET_DIR%" (
    echo [WARN] Removing old deployment...
    rmdir /S /Q "%TARGET_DIR%"
)
set "PARENT=%TARGET_DIR%\.."
if not exist "%PARENT%" mkdir "%PARENT"

echo [LINK] Creating junction...
mklink /J "%TARGET_DIR%" "%SOURCE_DIR%"
if !ERRORLEVEL!==0 (
    echo [OK] Deployed via junction link.
) else (
    echo [WARN] Junction failed, copying...
    xcopy /E /I /Y /Q "%SOURCE_DIR%" "%TARGET_DIR%"
    if !ERRORLEVEL!==0 (
        echo [OK] Deployed via copy.
    ) else (
        echo [ERROR] Deployment failed
        exit /b 1
    )
)
goto :eof

:: ============================================================
::  Sub: Deploy to Claude Code (flat .md files)
:: ============================================================
:deploy_claude
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
copy /Y "%SOURCE_DIR%\SKILL.md" "%TARGET_DIR%\slam-code-reader.md" >nul
echo [OK] Installed slam-code-reader.md
for %%F in ("%SOURCE_DIR%\phases\*.md") do (
    set "FN=%%~nF"
    copy /Y "%%F" "%TARGET_DIR%\slam-!FN!.md" >nul 2>nul && echo [OK] Installed slam-!FN!.md
)
goto :eof

endlocal
