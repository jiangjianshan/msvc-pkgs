@echo off
cls
setlocal enabledelayedexpansion
set OLDPATH=%PATH%
set TERM=
set PATH=C:\cygwin64\bin;%PATH%
bash %~dp0msvc-pkgs.sh %*
set PATH=%OLDPATH%
