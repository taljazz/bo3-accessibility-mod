@echo off
title BO3 Accessibility - Combined TTS Bridge (Gameplay + Menu OCR)
echo =============================================
echo   BO3 Accessibility - Combined TTS Bridge
echo =============================================
echo.
echo This bridge reads BOTH:
echo   - In-game announcements (zombie alerts, prompts, rounds)
echo   - Menu text via screen OCR (main menu, lobby, settings)
echo.
echo Make sure NVDA is running before continuing.
echo BO3 should be in Borderless Windowed mode for best OCR results.
echo Shift+F9 toggles menu OCR on/off.
echo.
echo Select launch mode:
echo   1) Normal
echo   2) Verbose (show debug output)
echo   3) No OCR (gameplay TTS only)
echo.
choice /C 123 /N /M "Enter choice (1-3): "
if errorlevel 3 set "FLAGS=--no-ocr" & goto launch
if errorlevel 2 set "FLAGS=-v" & goto launch
set "FLAGS="

:launch
echo.
call "C:\ProgramData\miniforge3\condabin\conda.bat" activate bo3
python "%~dp0menu_ocr_bridge.py" %FLAGS%
pause
