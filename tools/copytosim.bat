@echo on
setlocal

set "root=D:\MikeDocuments\_GitProjects\ETX_OTX projects\Showall"
set "src=%root%\src"

:: copy to 800x400 sim data folder
set "dest=D:\OneDrive\RC\__EdgeTX\2.12\SDCard\c800x480"
xcopy "%src%\" "%dest%\WIDGETS\Showall" /s /i /y

:: copy to TX16S sim data folder
set "dest=D:\OneDrive\RC\__EdgeTX\2.10\TX16SSimRoot"
xcopy "%src%\" "%dest%\WIDGETS\Showall" /s /i /y

echo transfer complete