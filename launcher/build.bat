@echo off
:: Builds the BO3 Accessibility launcher+bridge (C#, .NET).
:: This compiled app is the launcher AND the TTS/menu bridge in one.
setlocal
echo Building Bo3Access (Release)...
dotnet build "%~dp0Bo3Access\Bo3Access.csproj" -c Release -nologo
if errorlevel 1 (
    echo.
    echo BUILD FAILED.
    pause
    exit /b 1
)
echo.
echo Build complete. Run the launcher with:
echo   "%~dp0Bo3Access\bin\Release\net10.0-windows10.0.19041.0\Bo3Access.exe"
echo.
echo It starts the speech bridge automatically and shows the map picker.
echo Make sure NVDA is running first.
pause
