@echo off

:: Go to directory containing batch file
FOR /f %%i in ("%0") DO SET curpath=%%~dpi
CD /d %curpath%

:: Flags to determine which parts will be executed
SET doDev=0
SET doSelendroid=0
SET doAndroid=0
SET doVerbose=0
SET doForce=0

:: Read in command line switches
FOR %%A IN (%*) DO IF "%%A" == "--dev" SET doDev=1
FOR %%A IN (%*) DO IF "%%A" == "--android" SET doAndroid=1
FOR %%A IN (%*) DO IF "%%A" == "--selendroid" SET doSelendroid=1
FOR %%A IN (%*) DO IF "%%A" == "--verbose" SET doVerbose=1
FOR %%A IN (%*) DO IF "%%A" == "--force" SET doForce=1

:: If nothing is flagged do only android
IF %doDev% == 0 IF %doSelendroid% == 0 IF %doAndroid% == 0 SET doAndroid=1

:: Install Package and Dependencies
ECHO.
ECHO =====Installing dependencies with npm=====
ECHO.
CALL :runCmd "npm install ."

:: Install Dev Dependencies
if %doDev% == 1 (
  ECHO.
  ECHO =====Installing development dependencies with npm=====
  ECHO.
  CALL :runCmd "npm install . --dev"
  ECHO.
)

:: Reset Android
if %doAndroid% == 1 (
  ECHO.
  ECHO =====Resetting Android=====
  ECHO.
  CALL :runCmd "node_modules\.bin\grunt configAndroidBootstrap"
  CALL :runCmd "node_modules\.bin\grunt buildAndroidBootstrap"
  CALL :runCmd "node_modules\.bin\grunt setConfigVer:android"
  ECHO.
  ECHO =====Reset Android Complete=====
  
  ECHO.
  ECHO =====Resetting Unlock.apk=====
  ECHO.
  CALL :runCmd "RD /S /Q build\unlock_apk"
  CALL :runCmd "MKDIR build\unlock_apk"
  ECHO Building Unlock.apk
  CALL :runCmd "git submodule update --init submodules\unlock_apk"
  CALL :runCmd "PUSHD submodules\unlock_apk"
  CALL :runCmd "ant clean"
  CALL :runCmd "ant debug"
  CALL :runCmd "POPD"
  CALL :runCmd "COPY submodules\unlock_apk\bin\unlock_apk-debug.apk build\unlock_apk\unlock_apk-debug.apk"
  ECHO.
  ECHO =====Reset Unlock.apk Complete=====

  :: Reset Android Dev
  IF %doDev% == 1 (
    ECHO.
    ECHO =====Resetting API Demos=====
    ECHO.
    ECHO Cloning/updating Android test app: ApiDemos
    CALL :runCmd "git submodule update --init submodules\ApiDemos"
    CALL :runCmd "RD /S /Q sample-code\apps\ApiDemos | VER > NUL"
    CALL :runCmd "MKDIR sample-code\apps\ApiDemos"
    CALL :runCmd "XCOPY submodules\ApiDemos sample-code\apps\ApiDemos /E /Q"
    CALL :runCmd "node_modules\.bin\grunt configAndroidApp:ApiDemos"
    CALL :runCmd "node_modules\.bin\grunt buildAndroidApp:ApiDemos"
    ECHO.
    ECHO =====Reset API Demos Complete=====
  )
)

:: Reset Selendroid
IF %doSelendroid% == 1 (
  ECHO.
  ECHO =====Resetting Selendroid=====
  ECHO.
  ECHO Clearing out any old modified server apks
  CALL :runCmd "RD -/S /Q %windir%\Temp\selendroid*.apk | VER > NUL"
  ECHO Cloning/updating selendroid
  CALL :runCmd "RD -/S /Q submodules\selendroid\selendroid-server\target | VER > NUL"
  CALL :runCmd "git submodule update --init submodules\selendroid"
  CALL :runCmd "RD /S /Q selendroid  | VER > NUL"
  ECHO Building selendroid server and supporting libraries
  CALL :runCmd "node_modules\.bin\grunt buildSelendroidServer"
  ECHO Setting Selendroid config to Appium's version
  CALL :runCmd "node_modules\.bin\grunt setConfigVer:selendroid"
  ECHO.
  ECHO =====Reset Selendroid Complete=====
)
ECHO.
GOTO :EOF

:: Function to run commands
:runCmd - function to run a command
  IF %doVerbose% == 1 ECHO %~1
  CALL %~1
  IF %ERRORLEVEL% NEQ 0 IF %doForce% == 0 (
    CD /D %curpath%
    ECHO.
    ECHO Stopping because there was an error
    CALL :halt 1
  )
GOTO :EOF

:: Sets the errorlevel and stops the batch immediately
:halt
CALL :__SetErrorLevel %1
CALL :__ErrorExit 2> NUL
GOTO :EOF

:__ErrorExit
REM Creates a syntax error, stops immediately
() 
GOTO :EOF

:__SetErrorLevel
EXIT /B %TIME:~-2%
GOTO :EOF