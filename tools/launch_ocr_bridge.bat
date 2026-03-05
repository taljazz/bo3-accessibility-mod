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
echo.
call "C:\ProgramData\miniforge3\condabin\conda.bat" activate bo3
python "%~dp0menu_ocr_bridge.py" -v
pause
