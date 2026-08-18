@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  Gavin AI Toolkit - Deploy Script (Windows)
::  Supports: CodeBuddy, Claude Code
::
::  Usage:
::    deploy.bat <platform> <scope> [PATH]
::
::  Platform: codebuddy | claude
::  Scope:   user | project
:: ============================================================

set "SOURCE_DIR=%~dp0skills\slam-code-reader"

:: --- Parse arguments safely (handles spaces and unicode paths) ---
set "PLATFORM=%~1"
set "SCOPE=%~2"
set "PROJECT_PATH=%~3"

:: --- Help ---
if "%PLATFORM%"=="" (
    echo ===========================================
    echo   Gavin AI Toolkit - Deploy Tool (Windows)
    echo ===========================================
    echo.
    echo   Usage:
    echo     deploy.bat ^<platform^> ^<scope^> [project_path]
    echo.
    echo   Platform:
    echo     codebuddy   Deploy to CodeBuddy skills directory
    echo     claude      Deploy to Claude Code commands directory
    echo.
    echo   Scope:
    echo     user        User-level (global, all projects)
    echo     project     Project-level (requires path)
    echo.
    echo   Examples:
    echo     deploy.bat codebuddy user
    echo     deploy.bat codebuddy project D:\my-project
    echo     deploy.bat claude user
    echo     deploy.bat claude project D:\my-project
    echo ===========================================
    exit /b 0
)

:: --- Validate Platform ---
if /i not "%PLATFORM%"=="codebuddy" if /i not "%PLATFORM%"=="claude" (
    echo [ERROR] Unknown platform '%PLATFORM%'
    echo        Use 'codebuddy' or 'claude'
    exit /b 1
)

:: --- Determine Target Directory ---
if /i "%PLATFORM%"=="codebuddy" (
    if /i "%SCOPE%"=="user" (
        set "TARGET_DIR=%USERPROFILE%\.workbuddy\skills\slam-code-reader"
        echo [INFO] Platform: CodeBuddy  Scope: User-level (global)
        echo        Target: %TARGET_DIR%

    ) else if /i "%SCOPE%"=="project" (
        if "%PROJECT_PATH%"=="" (
            echo [ERROR] Project path required for project-level deployment.
            echo        Usage: deploy.bat codebuddy project D:\my-project
            exit /b 1
        )
        if not exist "%PROJECT_PATH%" (
            echo [ERROR] Project path does not exist: %PROJECT_PATH%
            exit /b 1
        )
        set "TARGET_DIR=%PROJECT_PATH%\.workbuddy\skills\slam-code-reader"
        echo [INFO] Platform: CodeBuddy  Scope: Project-level
        echo        Target: %TARGET_DIR%

    ) else (
        echo [ERROR] Unknown scope '%SCOPE%'
        echo        Use 'user' or 'project'
        exit /b 1
    )

) else if /i "%PLATFORM%"=="claude" (
    if /i "%SCOPE%"=="user" (
        set "TARGET_DIR=%USERPROFILE%\.claude\commands"
        echo [INFO] Platform: Claude Code  Scope: User-level (global)
        echo        Target: %TARGET_DIR%

    ) else if /i "%SCOPE%"=="project" (
        if "%PROJECT_PATH%"=="" (
            echo [ERROR] Project path required for project-level deployment.
            echo        Usage: deploy.bat claude project D:\my-project
            exit /b 1
        )
        if not exist "%PROJECT_PATH%" (
            echo [ERROR] Project path does not exist: %PROJECT_PATH%
            exit /b 1
        )
        set "TARGET_DIR=%PROJECT_PATH%\.claude\commands"
        echo [INFO] Platform: Claude Code  Scope: Project-level
        echo        Target: %TARGET_DIR%

    ) else (
        echo [ERROR] Unknown scope '%SCOPE%'
        echo        Use 'user' or 'project'
        exit /b 1
    )
)

echo.
echo [INFO] Source: %SOURCE_DIR%
echo.

:: --- Check Source ---
if not exist "%SOURCE_DIR%\SKILL.md" (
    echo [ERROR] Source SKILL.md not found
    echo        Expected: %SOURCE_DIR%\SKILL.md
    exit /b 1
)

:: --- Deploy Based on Platform ---
if /i "%PLATFORM%"=="codebuddy" (
    call :deploy_codebuddy
) else if /i "%PLATFORM%"=="claude" (
    call :deploy_claude
)

echo.
echo ===========================================
goto :eof

:: ============================================================
::  Subroutine: Deploy to CodeBuddy (Junction or Copy)
:: ============================================================
:deploy_codebuddy

:: Remove old deployment
if exist "%TARGET_DIR%" (
    echo [WARN] Target exists, removing old version...
    rmdir /S /Q "%TARGET_DIR%"
)

:: Create parent directory
set "PARENT_DIR=%TARGET_DIR%\.."
if not exist "%PARENT_DIR%" mkdir "%PARENT_DIR"

:: Try Junction first (preferred on Windows)
echo [LINK] Creating Junction link...
mklink /J "%TARGET_DIR%" "%SOURCE_DIR%"

if %ERRORLEVEL%==0 (
    echo.
    echo [OK] Deployed successfully! (Junction link mode)
    echo.
    echo      Source and target stay in sync.
    echo      Edit source files to update all deployments.
    echo.
    echo      Next step: In CodeBuddy, type "analyze D:/your-slam-project"
) else (
    echo.
    echo [WARN] Junction failed, trying copy mode...
    xcopy /E /I /Y /Q "%SOURCE_DIR%" "%TARGET_DIR%"

    if %ERRORLEVEL%==0 (
        echo [OK] Deployed successfully! (Copy mode)
        echo.
        echo      Note: Re-run this script after editing source files.
        echo      Next step: In CodeBuddy, type "analyze D:/your-slam-project"
    ) else (
        echo [ERROR] Deployment failed
        exit /b 1
    )
)

goto :eof

:: ============================================================
::  Subroutine: Deploy to Claude Code (flat .md files)
:: ============================================================
:deploy_claude

:: Create target directory
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Install main command
copy /Y "%SOURCE_DIR%\SKILL.md" "%TARGET_DIR%\slam-code-reader.md" >nul
echo [OK] Installed: slam-code-reader.md (main command)

:: Install phase sub-commands
for %%F in ("%SOURCE_DIR%\phases\*.md") do (
    set "PHASE_FILE=%%~F"
    set "PHASE_NAME=%%~nF"
    copy /Y "!PHASE_FILE!" "%TARGET_DIR%\slam-!PHASE_NAME!.md" >nul 2>nul && (
        echo [OK] Installed: slam-!PHASE_NAME!.md
    )
)

echo.
echo      Usage in Claude Code:
echo      /slam-code-reader          Run full analysis
echo      /slam-phase0-collect       Collect papers/docs only
echo      /slam-phase1-topology      Scan code topology only
echo      /slam-phase4-deep-dive     Deep dive into a module
echo      ... (etc)

goto :eof

endlocal
