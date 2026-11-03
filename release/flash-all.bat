@echo off
rem postmarketOS for Lenovo Tab P11 (TB-J606F): install from fastboot (Windows).
rem Writes userdata (the whole system), boot_b (kernel), erases dtbo_b and makes slot b active.
rem Slot a (Android boot, dtbo, vbmeta) and all other partitions are not touched.
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set FB=fastboot
if exist "%~dp0fastboot.exe" set FB="%~dp0fastboot.exe"

%FB% --version >nul 2>&1 || (echo fastboot not found: put fastboot.exe next to this file or install platform-tools & goto fail)
for %%f in (userdata.img boot.img SHA256SUMS) do if not exist "%%f" (echo %%f is missing - unpack the whole archive & goto fail)

echo == Checking files (sha256)
for /f "tokens=1,2" %%a in (SHA256SUMS) do call :check %%a %%b || goto fail

echo == Waiting for the tablet in fastboot (Vol- + Power)
%FB% devices | findstr /C:"fastboot" >nul || (echo No device in fastboot mode & goto fail)
%FB% getvar product 2>&1 | findstr /C:"product: bengal" >nul || (echo This is not a Lenovo Tab P11 J606F & goto fail)
%FB% getvar unlocked 2>&1 | findstr /C:"unlocked: yes" >nul || (echo Bootloader is locked - unlock it first & goto fail)
%FB% getvar current-slot 2>&1 | findstr /C:"current-slot"

echo.
echo WARNING: userdata will be ERASED completely (all Android data is lost).
echo ВНИМАНИЕ: раздел userdata будет стёрт ПОЛНОСТЬЮ.
set /p answer=Type YES to continue / Введите YES: 
if not "%answer%"=="YES" (echo Cancelled & goto fail)

%FB% flash userdata userdata.img || goto fail
%FB% flash boot_b boot.img || goto fail
%FB% erase dtbo_b || goto fail
%FB% --set-active=b || goto fail
%FB% reboot
echo.
echo Done. On the first boot the tablet reboots once by itself.
echo Готово. При первой загрузке планшет сам перезагрузится один раз.
pause
exit /b 0

:check
rem certutil prints a header and a footer with ":" and the hash alone on the line between them
for /f "tokens=*" %%h in ('certutil -hashfile "%2" SHA256 ^| findstr /v ":"') do (
	set "h=%%h"
	goto cmp
)
:cmp
set "h=%h: =%"
if /i "%h%"=="%1" (echo %2: OK & exit /b 0)
echo %2: checksum mismatch - download the archive again
exit /b 1

:fail
pause
exit /b 1
