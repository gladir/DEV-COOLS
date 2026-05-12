@echo off
REM ============================================================
REM RUN-TESTS.CMD - Suite de tests pour le compilateur HC.PAS
REM ============================================================
setlocal enableextensions
set HC=%~dp0..\..\HC.EXE
set PASS=0
set FAIL=0

echo ============================================================
echo Tests HC.PAS - Compilateur WinHelp clone
echo ============================================================

REM ---- TEST 1 : projet simple ----
echo.
echo [TEST 1] SIMPLE - compilation basique
pushd "%~dp0SIMPLE"
"%HC%" /V /T SIMPLE.HPJ
if errorlevel 1 ( echo   ECHEC ^(code %errorlevel%^) & set /a FAIL+=1 ) else ( echo   OK & set /a PASS+=1 )
if exist SIMPLE.HLP ( echo   SIMPLE.HLP genere ) else ( echo   ERREUR: SIMPLE.HLP absent & set /a FAIL+=1 )
popd

REM ---- TEST 2 : projet multi-fichiers ----
echo.
echo [TEST 2] MULTI - projet multi-RTF avec ALIAS et CONFIG
pushd "%~dp0MULTI"
"%HC%" /L /M MULTI.HPJ
if errorlevel 2 ( echo   ECHEC ^(code %errorlevel%^) & set /a FAIL+=1 ) else ( echo   OK & set /a PASS+=1 )
if exist MULTI.HLP ( echo   MULTI.HLP genere ) else ( echo   ERREUR: MULTI.HLP absent & set /a FAIL+=1 )
if exist MULTI.LOG ( echo   MULTI.LOG genere ) else ( echo   ERREUR: MULTI.LOG absent & set /a FAIL+=1 )
popd

REM ---- TEST 3 : mode silencieux ----
echo.
echo [TEST 3] QUIET - mode silencieux /Q
pushd "%~dp0QUIET"
"%HC%" /Q QUIET.HPJ > QUIET.OUT
if errorlevel 1 ( echo   ECHEC ^(code %errorlevel%^) & set /a FAIL+=1 ) else ( echo   OK & set /a PASS+=1 )
for %%F in (QUIET.OUT) do if %%~zF GTR 0 ( echo   ERREUR: sortie non vide en /Q & set /a FAIL+=1 ) else ( echo   Sortie vide confirmee )
if exist QUIET.HLP ( echo   QUIET.HLP genere ) else ( echo   ERREUR: QUIET.HLP absent & set /a FAIL+=1 )
popd

REM ---- TEST 4 : detection d'erreurs (RTF manquant) ----
echo.
echo [TEST 4] BADREF - detection RTF manquant
pushd "%~dp0BADREF"
"%HC%" BADREF.HPJ
if errorlevel 1 ( echo   OK - erreur correctement detectee & set /a PASS+=1 ) else ( echo   ECHEC: aucune erreur signalee & set /a FAIL+=1 )
popd

REM ---- TEST 5 : /E arret immediat ----
echo.
echo [TEST 5] BADREF /E - arret a la premiere erreur
pushd "%~dp0BADREF"
"%HC%" /E BADREF.HPJ
if errorlevel 2 ( echo   OK - arret /E declenche & set /a PASS+=1 ) else ( echo   ECHEC: /E non respecte & set /a FAIL+=1 )
popd

REM ---- TEST 6 : aide sans argument ----
echo.
echo [TEST 6] Aide sans argument
"%HC%" > "%~dp0_HELP.OUT"
findstr /C:"Usage" "%~dp0_HELP.OUT" >nul
if errorlevel 1 ( echo   ECHEC: aide non affichee & set /a FAIL+=1 ) else ( echo   OK & set /a PASS+=1 )
del "%~dp0_HELP.OUT" 2>nul

REM ---- TEST 7 : option inconnue ----
echo.
echo [TEST 7] Option inconnue rejetee
"%HC%" /Z SIMPLE.HPJ
if errorlevel 2 ( echo   OK - option rejetee & set /a PASS+=1 ) else ( echo   ECHEC: option /Z acceptee & set /a FAIL+=1 )

REM ---- TEST 8 : /N pas de compression ----
echo.
echo [TEST 8] /N option (pas de compression)
pushd "%~dp0SIMPLE"
"%HC%" /N /Q SIMPLE.HPJ
if errorlevel 1 ( echo   ECHEC & set /a FAIL+=1 ) else ( echo   OK & set /a PASS+=1 )
popd

echo.
echo ============================================================
echo Resultat : %PASS% reussi(s) / %FAIL% echec(s)
echo ============================================================
endlocal & exit /b %FAIL%
