@echo off
setlocal
cd /d "%~dp0"
title HomeForge Clean
color 0E

echo Cleaning HomeForge build output...
if exist publish rmdir /s /q publish
for /d /r %%D in (bin,obj) do (
    if exist "%%D" rmdir /s /q "%%D"
)
echo Done.
pause
