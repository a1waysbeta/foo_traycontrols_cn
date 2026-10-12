@echo off
setlocal

echo ========================================
echo Building Tray Controls for foobar2000 (x86)
echo ========================================

REM Set the project file path
set PROJECT_FILE=foo_traycontrols.vcxproj

REM Check if the project file exists
if not exist "%PROJECT_FILE%" (
    echo Error: Project file "%PROJECT_FILE%" not found.
    echo Make sure you're running this from the correct directory.
    pause
    exit /b 1
)

REM SDK layout check: the project now links the prebuilt shared-Win32.lib
REM shipped with the reupen foobar2000-sdk-modified fork. An old local
REM copy of lib\foobar2000_SDK (full official SDK tree) is NOT compatible.
if exist "lib\foobar2000_SDK" if not exist "lib\foobar2000_SDK\foobar2000\shared\shared-Win32.lib" (
    echo Error: old local SDK copy detected in lib\foobar2000_SDK.
    echo Please delete the lib directory and run this script again
    echo so the remote SDK forks can be fetched.
    pause
    exit /b 1
)

REM Fetch remote SDK sources (requires git)
if not exist "lib\foobar2000_SDK\foobar2000\SDK\foobar2000_SDK.vcxproj" (
    echo Fetching foobar2000 SDK ^(reupen fork^)...
    git clone --depth 1 https://github.com/reupen/foobar2000-sdk-modified lib\foobar2000_SDK\foobar2000
    if %ERRORLEVEL% neq 0 (
        echo Error: git clone of foobar2000-sdk-modified failed.
        pause
        exit /b 1
    )
)
if not exist "lib\foobar2000_SDK\pfc\pfc.vcxproj" (
    echo Fetching pfc ^(reupen fork^)...
    git clone --depth 1 https://github.com/reupen/pfc-modified lib\foobar2000_SDK\pfc
    if %ERRORLEVEL% neq 0 (
        echo Error: git clone of pfc-modified failed.
        pause
        exit /b 1
    )
)

REM Fix platform toolset v140/v145 to v143 (requires PowerShell)
powershell -NoProfile -Command "Get-ChildItem -Path lib -Recurse -Filter *.vcxproj | ForEach-Object { $c = Get-Content $_.FullName -Raw; if ($c -match 'v14[05]') { Write-Host ('Fixing toolset: ' + $_.Name); ($c -replace 'v14[05]', 'v143') | Set-Content $_.FullName -NoNewline } }"

REM Build dependencies
echo.
echo Building pfc (Win32)...
msbuild lib\foobar2000_SDK\pfc\pfc.vcxproj /p:Configuration=Release /p:Platform=Win32 /p:OutDir=x86\pfc\ /v:minimal
if %ERRORLEVEL% neq 0 goto build_failed

echo.
echo Building foobar2000_SDK (Win32)...
msbuild lib\foobar2000_SDK\foobar2000\SDK\foobar2000_SDK.vcxproj /p:Configuration=Release /p:Platform=Win32 /p:OutDir=x86\foobar2000_SDK\ /v:minimal
if %ERRORLEVEL% neq 0 goto build_failed

REM Build the component
echo.
echo Building %PROJECT_FILE% (Win32 Release)...
msbuild "%PROJECT_FILE%" /p:Configuration=Release /p:Platform=Win32 /v:minimal
if %ERRORLEVEL% neq 0 goto build_failed

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.

if exist "Release\foo_traycontrols.dll" (
    echo Output: Release\foo_traycontrols.dll
) else (
    echo Warning: Expected output file not found at Release\foo_traycontrols.dll
)

echo.
pause
exit /b 0

:build_failed
echo.
echo ========================================
echo Build failed with error code %ERRORLEVEL%.
echo ========================================
echo.
echo Common issues:
echo - Make sure Visual Studio 2022 Build Tools (v143) are installed
echo - Make sure git is available in PATH
echo - Check that the remote SDK forks could be fetched
pause
exit /b %ERRORLEVEL%
