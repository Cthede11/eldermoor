@echo off
rem Eldermoor: download the newest release from GitHub, only what changed. Close the game first.
rem Your worlds, settings, keybinds and any mods you added yourself are kept.
rem "Update Eldermoor.bat" check   only shows what an update would download.
title Eldermoor updater
cd /d "%~dp0"
if /i "%~1"=="check" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eldermoor-update\update.ps1" -Check
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eldermoor-update\update.ps1"
)
