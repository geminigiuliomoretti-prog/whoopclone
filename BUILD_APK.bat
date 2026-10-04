@echo off
echo ===================================================
echo COMPILAZIONE AUTOMATICA APK WHOOP 5.0 CLONE
echo ===================================================

set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=C:\flutter\bin;%PATH%

cd /d "c:\Users\costa\Downloads\Clone-whoop\whoop_clone"

echo.
echo Avvio della build APK veloci in corso...
call C:\flutter\bin\flutter.bat build apk --debug

echo.
echo ===================================================
echo COMPILAZIONE COMPLETATA!
echo L'APK si trova in:
echo whoop_clone\build\app\outputs\flutter-apk\app-debug.apk
echo ===================================================
pause
