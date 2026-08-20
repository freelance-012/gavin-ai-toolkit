@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  Gavin AI Toolkit - Deploy Script (Windows)
::  Usage: deploy.bat <platform> <scope> [PATH]
::  Platform: codebuddy | claude
::  Scope:   user | project
:: ============================================================

set "SKILLS_DIR=%~dp0skills"

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
        set "TARGET_DIR=%USERPROFILE%\.codebuddy\skills"
    ) else if /i "%SCOPE%"=="project" (
        call :check_project_path
        set "TARGET_DIR=%PROJECT_PATH%\.codebuddy\skills"
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
echo [INFO] Skills: %SKILLS_DIR%
echo.

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
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

set "COUNT=0"
for /D %%S in ("%SKILLS_DIR%\*") do (
    if exist "%%S\SKILL.md" (
        set "SKILL_NAME=%%~nxS"
        set "SKILL_TARGET=%TARGET_DIR%\!SKILL_NAME!"
        echo   Deploying: !SKILL_NAME!

        if exist "!SKILL_TARGET!" rmdir /S /Q "!SKILL_TARGET!"

        mklink /J "!SKILL_TARGET!" "%%S"
        if !ERRORLEVEL!==0 (
            echo   [OK] !SKILL_NAME! deployed via junction.
        ) else (
            xcopy /E /I /Y /Q "%%S" "!SKILL_TARGET!"
            if !ERRORLEVEL!==0 (
                echo   [OK] !SKILL_NAME! deployed via copy.
            ) else (
                echo   [ERROR] Failed to deploy !SKILL_NAME!
            )
        )
        set /a COUNT+=1
    )
)

echo.
echo [OK] !COUNT! skills deployed.
goto :eof

:: ============================================================
::  Sub: Deploy to Claude Code (flat .md files)
:: ============================================================
:deploy_claude
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

set "COUNT=0"
for /D %%S in ("%SKILLS_DIR%\*") do (
    if exist "%%S\SKILL.md" (
        set "SKILL_NAME=%%~nxS"
        copy /Y "%%S\SKILL.md" "%TARGET_DIR%\!SKILL_NAME!.md" >nul
        echo [OK] Installed !SKILL_NAME!.md

        if exist "%%S\phases" (
            for %%F in ("%%S\phases\*.md") do (
                set "FN=%%~nF"
                copy /Y "%%F" "%TARGET_DIR%\!SKILL_NAME!-!FN!.md" >nul 2>nul && echo [OK] Installed !SKILL_NAME!-!FN!.md
            )
        )
        set /a COUNT+=1
    )
)

echo.
echo [OK] !COUNT! skills deployed.
goto :eof

endlocal
