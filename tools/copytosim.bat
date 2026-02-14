@echo on
setlocal

set "root=D:\MikeDocuments\_GitProjects\ETX_OTX projects\Showall"
set "src=%root%\src"

:: copy to TX16S sim data folder
set "dest=D:\OneDrive\RC\__EdgeTX\2.10\TX16SSimRoot"
xcopy "%src%\" "%dest%\WIDGETS\Showall" /s /i /y

echo transfer complete