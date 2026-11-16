@echo off
rem Eldermoor: pick a performance preset for this PC (Potato, Low, Balanced, High). Close the game first.
rem Usage from a prompt: "Eldermoor Performance Presets.bat" [potato|low|balanced|high|auto]
title Eldermoor performance presets
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eldermoor-presets\apply.ps1" %*
