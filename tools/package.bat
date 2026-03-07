@echo off
setlocal

:: Set up variables
set "root=D:\MikeDocuments\_GitProjects\ETX_OTX projects\Showall"
set "tempdir=%root%\Tools\temp"
set "zipname=ShowItAll_0921.zip"
set "zipoutput=%root%\package\%zipname%"

:: Clean up any previous temp folder
if exist "%tempdir%" rd /s /q "%tempdir%"

:: Copy selected files into temp directory
xcopy "%root%\src\*.lua" "%tempdir%\"
xcopy "%root%\docs\*.pdf" "%tempdir%\"

:: Compress the folder using PowerShell
powershell -command "Compress-Archive -Path '%tempdir%\*' -DestinationPath '%zipoutput%' -Force"

:: Delete the temporary folder after compression
:: rd /s /q "%tempdir%"

echo Zip archive complete
pause
