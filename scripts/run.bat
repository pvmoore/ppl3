@echo off
cls
chcp 65001

if "%1"=="" (
    set NAME=projects\test
) else (
    set NAME=projects\%1
)

rem cd ..


del /Q %NAME%\.target\*.exe

if not exist "ppl3.exe" goto COMPILE
del ppl3.exe

:COMPILE
dub build --parallel --build=debug --config=test --arch=x86_64 --compiler=dmd


if not exist "ppl3.exe" goto FAIL
ppl3.exe %NAME%


if not exist "%NAME%\.target\test.exe" goto FAIL
call getfilesize.bat %NAME%\.target\test.exe
echo.
echo Running %NAME%\.target\test.exe (%filesize% bytes)
echo.
%NAME%\.target\test.exe
IF %ERRORLEVEL% NEQ 0 (
  echo.
  echo.
  echo Exit code was %ERRORLEVEL%
)
goto END


:FAIL
echo.
echo Compile or config error


:END