echo off

rem Update Missions with a new version of Moose.lua
rem Provide as the only parameter the path to the .miz files, which can be embedded in directories.

echo Path to Mission Files: %1

For /R %1 %%M IN (*.miz) do ( 
  echo "Mission: %%M"
  mkdir Temp
  cd Temp
  mkdir l10n
  mkdir l10n\DEFAULT
  copy "..\Moose Mission Setup\Moose.lua" l10n\DEFAULT
  copy "%%~pM%%~nM.lua" l10n\DEFAULT\*.*
  7z -bb0 u "%%M" "l10n\DEFAULT\*.lua"
  cd ..
  rmdir /S /Q Temp
)
