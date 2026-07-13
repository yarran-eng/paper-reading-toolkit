@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0parse-pdf-precise.ps1" %*
