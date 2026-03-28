#!/bin/sh
# =============================================================================
# test_disres.sh - Tests rigoureux pour DISRES.PAS
# =============================================================================
#
# Ce script teste que DISRES desassemble correctement les fichiers .RES
# (Windows 16 bits et 32 bits) sans planter, et que les fichiers .RC
# generes sont coherents.
#
# Usage:
#   ./TESTS/test_disres.sh [chemin_vers_DISRES]
#
# Si le chemin n'est pas fourni, le script compile DISRES.PAS automatiquement.
# Les fichiers .RES de test sont lus depuis SAMPLES/RES/.
# =============================================================================

TIMEOUT_SEC=30
PASS=0
FAIL=0
TOTAL=0
TMPDIR_TEST="/tmp/test_disres_$$"

cleanup() {
  rm -rf "$TMPDIR_TEST"
}
trap cleanup EXIT

mkdir -p "$TMPDIR_TEST"

# ==== Couleurs ====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass_test() {
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  printf "${GREEN}  [PASS]${NC} %s\n" "$1"
}

fail_test() {
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  printf "${RED}  [FAIL]${NC} %s\n" "$1"
  if [ -n "$2" ]; then
    printf "         Detail: %s\n" "$2"
  fi
}

# ==== Localisation du binaire DISRES ====
DISRES_BIN="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SAMPLES_RES="$REPO_DIR/SAMPLES/RES"

if [ -z "$DISRES_BIN" ]; then
  if [ -f "$REPO_DIR/DISRES.PAS" ]; then
    echo "Compilation de DISRES.PAS..."
    fpc -Mtp "$REPO_DIR/DISRES.PAS" -o"$TMPDIR_TEST/DISRES" 2>&1 | tail -3
    if [ $? -ne 0 ]; then
      echo "ERREUR: Echec de la compilation de DISRES.PAS"
      exit 1
    fi
    DISRES_BIN="$TMPDIR_TEST/DISRES"
  else
    echo "ERREUR: DISRES.PAS introuvable et aucun binaire specifie."
    exit 1
  fi
fi

if [ ! -x "$DISRES_BIN" ]; then
  echo "ERREUR: $DISRES_BIN n'est pas executable."
  exit 1
fi

# ==== Verifier la presence des fichiers de test ====
if [ ! -d "$SAMPLES_RES" ]; then
  echo "ERREUR: Repertoire SAMPLES/RES/ introuvable : $SAMPLES_RES"
  exit 1
fi

echo ""
echo "============================================================"
echo "  Tests rigoureux de DISRES"
echo "  Binaire: $DISRES_BIN"
echo "  Echantillons: $SAMPLES_RES"
echo "============================================================"
echo ""

# ==== Helper : lancer DISRES avec timeout ====
run_disres() {
  local input="$1"
  shift
  timeout "$TIMEOUT_SEC" "$DISRES_BIN" "$input" "$@"
  return $?
}

# =============================================================================
# 1. Tests de base : aide et usage
# =============================================================================
echo "--- 1. Tests d'aide et usage ---"

OUT=$("$DISRES_BIN" -h 2>&1)
if echo "$OUT" | grep -q "DISRES"; then
  pass_test "1.1 Aide -h affiche DISRES"
else
  fail_test "1.1 Aide -h ne contient pas DISRES" "$OUT"
fi

OUT=$("$DISRES_BIN" 2>&1)
STATUS=$?
if echo "$OUT" | grep -q "DISRES"; then
  pass_test "1.2 Sans argument affiche banniere"
else
  fail_test "1.2 Sans argument n'affiche pas la banniere" "$OUT"
fi

OUT=$("$DISRES_BIN" fichier_inexistant.res 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ] || echo "$OUT" | grep -qi "erreur\|error\|introuvable\|not found"; then
  pass_test "1.3 Fichier inexistant provoque une erreur"
else
  fail_test "1.3 Fichier inexistant n'a pas provoque d'erreur" "$OUT"
fi

echo ""

# =============================================================================
# 2. test01_empty.res - RES32 minimal (null header seulement)
# =============================================================================
echo "--- 2. test01_empty.res (RES32 minimal) ---"

RES="$SAMPLES_RES/test01_empty.res"
OUT_RC="$TMPDIR_TEST/test01.rc"

if [ ! -f "$RES" ]; then
  fail_test "2.0 test01_empty.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "2.1 DISRES termine sans erreur sur RES32 minimal"
  else
    fail_test "2.1 DISRES a echoue sur RES32 minimal (code $STATUS)" "$OUT"
  fi

  if [ -f "$OUT_RC" ]; then
    pass_test "2.2 Fichier .RC genere"
  else
    fail_test "2.2 Fichier .RC non genere"
  fi

  if echo "$OUT" | grep -q "Format detecte.*32 bits"; then
    pass_test "2.3 Format RES32 detecte"
  else
    fail_test "2.3 Format RES32 non detecte" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 0"; then
    pass_test "2.4 Compte ressources = 0 (correct)"
  else
    fail_test "2.4 Compte ressources incorrect" "$OUT"
  fi

  if echo "$OUT" | grep -q "=== DISRES - Rapport de desassemblage ==="; then
    pass_test "2.5 Rapport final affiche"
  else
    fail_test "2.5 Rapport final absent" "$OUT"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END\|AVERTISSEMENT.*vide"; then
    fail_test "2.6 Faux avertissement BEGIN/END ou vide" "$OUT"
  else
    pass_test "2.6 Pas d'avertissement indesirable"
  fi
fi

echo ""

# =============================================================================
# 3. test02_stringtable.res - RES32 avec RT_STRING (Hello/World)
# =============================================================================
echo "--- 3. test02_stringtable.res (RES32 + RT_STRING) ---"

RES="$SAMPLES_RES/test02_stringtable.res"
OUT_RC="$TMPDIR_TEST/test02.rc"

if [ ! -f "$RES" ]; then
  fail_test "3.0 test02_stringtable.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "3.1 DISRES termine sans erreur"
  else
    fail_test "3.1 DISRES a echoue (code $STATUS)" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 1"; then
    pass_test "3.2 Compte ressources = 1 (correct)"
  else
    fail_test "3.2 Compte ressources incorrect" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_STRING.*1 bloc"; then
    pass_test "3.3 RT_STRING : 1 bloc detecte"
  else
    fail_test "3.3 RT_STRING non detecte" "$OUT"
  fi

  if echo "$OUT" | grep -q "2 chaine"; then
    pass_test "3.4 2 chaines detectees (Hello + World)"
  else
    fail_test "3.4 Comptage de chaines incorrect" "$OUT"
  fi

  if [ -f "$OUT_RC" ] && [ -s "$OUT_RC" ]; then
    pass_test "3.5 Fichier .RC non vide genere"
  else
    fail_test "3.5 Fichier .RC vide ou absent"
  fi

  # Note: la generation STRINGTABLE est implementee dans TODO 24.
  # En attendant, le fichier RC contient l'en-tete mais pas le STRINGTABLE.
  if [ -f "$OUT_RC" ] && head -1 "$OUT_RC" | grep -q "^//"; then
    pass_test "3.6 En-tete RC correct (commentaire //)"
  else
    fail_test "3.6 En-tete RC incorrect"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END"; then
    fail_test "3.7 Avertissement BEGIN/END inattendu" "$OUT"
  else
    pass_test "3.7 Pas d'avertissement BEGIN/END"
  fi
fi

echo ""

# =============================================================================
# 4. test03_rcdata.res - RES32 avec RT_RCDATA
# =============================================================================
echo "--- 4. test03_rcdata.res (RES32 + RT_RCDATA) ---"

RES="$SAMPLES_RES/test03_rcdata.res"
OUT_RC="$TMPDIR_TEST/test03.rc"

if [ ! -f "$RES" ]; then
  fail_test "4.0 test03_rcdata.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "4.1 DISRES termine sans erreur"
  else
    fail_test "4.1 DISRES a echoue (code $STATUS)" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 1"; then
    pass_test "4.2 Compte ressources = 1 (correct)"
  else
    fail_test "4.2 Compte ressources incorrect" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_RCDATA.*1 ressource"; then
    pass_test "4.3 RT_RCDATA detecte"
  else
    fail_test "4.3 RT_RCDATA non detecte" "$OUT"
  fi

  if [ -f "$OUT_RC" ] && grep -q "RCDATA BEGIN" "$OUT_RC"; then
    pass_test "4.4 Bloc RCDATA BEGIN present dans le RC"
  else
    fail_test "4.4 Bloc RCDATA BEGIN absent du RC"
  fi

  if [ -f "$OUT_RC" ] && grep -q "^END$" "$OUT_RC"; then
    pass_test "4.5 END present dans le RC"
  else
    fail_test "4.5 END absent du RC"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END"; then
    fail_test "4.6 Avertissement BEGIN/END inattendu" "$OUT"
  else
    pass_test "4.6 Pas d'avertissement BEGIN/END"
  fi

  if [ -f "$OUT_RC" ] && grep -q "0x44, 0x49, 0x53" "$OUT_RC"; then
    pass_test "4.7 Donnees hex presentes dans le RC (0x44='D', 0x49='I', 0x53='S')"
  else
    fail_test "4.7 Donnees hex absentes du RC"
  fi
fi

echo ""

# =============================================================================
# 5. test04_mixed.res - RES32 avec RT_STRING x2 + RT_RCDATA
# =============================================================================
echo "--- 5. test04_mixed.res (RES32 mixte) ---"

RES="$SAMPLES_RES/test04_mixed.res"
OUT_RC="$TMPDIR_TEST/test04.rc"

if [ ! -f "$RES" ]; then
  fail_test "5.0 test04_mixed.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "5.1 DISRES termine sans erreur"
  else
    fail_test "5.1 DISRES a echoue (code $STATUS)" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 3"; then
    pass_test "5.2 Compte ressources = 3 (correct)"
  else
    fail_test "5.2 Compte ressources incorrect (attendu 3)" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_STRING.*2 bloc"; then
    pass_test "5.3 RT_STRING : 2 blocs detectes"
  else
    fail_test "5.3 RT_STRING 2 blocs non detectes" "$OUT"
  fi

  if echo "$OUT" | grep -q "5 chaine"; then
    pass_test "5.4 5 chaines detectees"
  else
    fail_test "5.4 Comptage de chaines incorrect (attendu 5)" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_RCDATA.*1 ressource"; then
    pass_test "5.5 RT_RCDATA detecte"
  else
    fail_test "5.5 RT_RCDATA non detecte" "$OUT"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END"; then
    fail_test "5.6 Avertissement BEGIN/END inattendu" "$OUT"
  else
    pass_test "5.6 Pas d'avertissement BEGIN/END"
  fi
fi

echo ""

# =============================================================================
# 6. test05_res16.res - RES16 avec RT_RCDATA + RT_STRING
# =============================================================================
echo "--- 6. test05_res16.res (RES16) ---"

RES="$SAMPLES_RES/test05_res16.res"
OUT_RC="$TMPDIR_TEST/test05.rc"

if [ ! -f "$RES" ]; then
  fail_test "6.0 test05_res16.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "6.1 DISRES termine sans erreur"
  else
    fail_test "6.1 DISRES a echoue (code $STATUS)" "$OUT"
  fi

  if echo "$OUT" | grep -q "Format detecte.*16 bits"; then
    pass_test "6.2 Format RES16 detecte"
  else
    fail_test "6.2 Format RES16 non detecte" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 2"; then
    pass_test "6.3 Compte ressources = 2 (correct)"
  else
    fail_test "6.3 Compte ressources incorrect (attendu 2)" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_STRING.*1 bloc"; then
    pass_test "6.4 RT_STRING detecte en RES16"
  else
    fail_test "6.4 RT_STRING non detecte en RES16" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_RCDATA.*1 ressource"; then
    pass_test "6.5 RT_RCDATA detecte en RES16"
  else
    fail_test "6.5 RT_RCDATA non detecte en RES16" "$OUT"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END"; then
    fail_test "6.6 Avertissement BEGIN/END inattendu" "$OUT"
  else
    pass_test "6.6 Pas d'avertissement BEGIN/END"
  fi
fi

echo ""

# =============================================================================
# 7. test06_multistring.res - RES32 avec 3xRT_STRING + RT_RCDATA
# =============================================================================
echo "--- 7. test06_multistring.res (RES32 multi-blocs) ---"

RES="$SAMPLES_RES/test06_multistring.res"
OUT_RC="$TMPDIR_TEST/test06.rc"

if [ ! -f "$RES" ]; then
  fail_test "7.0 test06_multistring.res manquant"
else
  OUT=$(run_disres "$RES" -o "$OUT_RC" 2>&1)
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    pass_test "7.1 DISRES termine sans erreur"
  else
    fail_test "7.1 DISRES a echoue (code $STATUS)" "$OUT"
  fi

  if echo "$OUT" | grep -q "Ressources total: 4"; then
    pass_test "7.2 Compte ressources = 4 (correct)"
  else
    fail_test "7.2 Compte ressources incorrect (attendu 4)" "$OUT"
  fi

  if echo "$OUT" | grep -q "RT_STRING.*3 bloc"; then
    pass_test "7.3 RT_STRING : 3 blocs detectes"
  else
    fail_test "7.3 RT_STRING 3 blocs non detectes" "$OUT"
  fi

  if echo "$OUT" | grep -q "12 chaine"; then
    pass_test "7.4 12 chaines detectees"
  else
    fail_test "7.4 Comptage de chaines incorrect (attendu 12)" "$OUT"
  fi

  if echo "$OUT" | grep -qi "AVERTISSEMENT.*BEGIN.*END"; then
    fail_test "7.5 Avertissement BEGIN/END inattendu" "$OUT"
  else
    pass_test "7.5 Pas d'avertissement BEGIN/END"
  fi
fi

echo ""

# =============================================================================
# 8. Test mode verbeux (-v)
# =============================================================================
echo "--- 8. Mode verbeux ---"

RES="$SAMPLES_RES/test04_mixed.res"
OUT=$(run_disres "$RES" -o "$TMPDIR_TEST/test_v.rc" -v 2>&1)
STATUS=$?

if [ $STATUS -eq 0 ]; then
  pass_test "8.1 DISRES -v termine sans erreur"
else
  fail_test "8.1 DISRES -v a echoue (code $STATUS)" "$OUT"
fi

if echo "$OUT" | grep -q "Detail des ressources"; then
  pass_test "8.2 Mode -v affiche 'Detail des ressources'"
else
  fail_test "8.2 Mode -v n'affiche pas le detail" "$OUT"
fi

if echo "$OUT" | grep -q "type=RT_STRING\|type=RT_RCDATA"; then
  pass_test "8.3 Mode -v affiche les types de ressources"
else
  fail_test "8.3 Mode -v ne montre pas les types" "$OUT"
fi

echo ""

# =============================================================================
# 9. Test force format (-16 et -32)
# =============================================================================
echo "--- 9. Options de force de format ---"

RES="$SAMPLES_RES/test02_stringtable.res"
OUT=$(run_disres "$RES" -o "$TMPDIR_TEST/test_32.rc" -32 2>&1)
if echo "$OUT" | grep -q "Format detecte.*32 bits"; then
  pass_test "9.1 Option -32 force le format RES32"
else
  fail_test "9.1 Option -32 n'a pas force RES32" "$OUT"
fi

RES="$SAMPLES_RES/test05_res16.res"
OUT=$(run_disres "$RES" -o "$TMPDIR_TEST/test_16.rc" -16 2>&1)
if echo "$OUT" | grep -q "Format detecte.*16 bits"; then
  pass_test "9.2 Option -16 force le format RES16"
else
  fail_test "9.2 Option -16 n'a pas force RES16" "$OUT"
fi

echo ""

# =============================================================================
# 10. Coherence du fichier RC genere
# =============================================================================
echo "--- 10. Coherence du fichier RC genere ---"

# test02 : stringtable
RC="$TMPDIR_TEST/test02.rc"
if [ -f "$RC" ]; then
  if head -1 "$RC" | grep -q "^//"; then
    pass_test "10.1 test02.rc commence par un commentaire //"
  else
    fail_test "10.1 test02.rc ne commence pas par un commentaire"
  fi

  if grep -q "#include" "$RC"; then
    pass_test "10.2 test02.rc contient #include"
  else
    fail_test "10.2 test02.rc ne contient pas #include"
  fi

  if grep -q "LANGUAGE" "$RC"; then
    pass_test "10.3 test02.rc contient directive LANGUAGE"
  else
    fail_test "10.3 test02.rc ne contient pas directive LANGUAGE"
  fi

  # La generation STRINGTABLE est prevue dans TODO 24.
  # Pour l'instant, on verifie que le fichier RC contient bien
  # la source et la date en commentaire.
  if grep -q "Source" "$RC" && grep -q "Date" "$RC"; then
    pass_test "10.4 test02.rc contient commentaires Source et Date"
  else
    fail_test "10.4 test02.rc ne contient pas les commentaires attendus"
  fi
else
  fail_test "10.1-4 test02.rc non genere, tests de coherence impossibles"
fi

# test03 : rcdata - BEGIN/END equilibres
RC="$TMPDIR_TEST/test03.rc"
if [ -f "$RC" ]; then
  N_BEGIN=$(grep -c "BEGIN" "$RC" 2>/dev/null || echo 0)
  N_END=$(grep -c "^END$" "$RC" 2>/dev/null || echo 0)
  if [ "$N_BEGIN" -eq "$N_END" ] && [ "$N_BEGIN" -gt 0 ]; then
    pass_test "10.5 test03.rc : BEGIN/END equilibres ($N_BEGIN paires)"
  else
    fail_test "10.5 test03.rc : BEGIN/END desequilibres (BEGIN=$N_BEGIN END=$N_END)"
  fi
else
  fail_test "10.5 test03.rc non genere"
fi

echo ""

# =============================================================================
# 11. Test avec -o (nom de sortie explicite)
# =============================================================================
echo "--- 11. Option -o (sortie explicite) ---"

RES="$SAMPLES_RES/test02_stringtable.res"
CUSTOM_OUT="$TMPDIR_TEST/custom_output.rc"
OUT=$(run_disres "$RES" -o "$CUSTOM_OUT" 2>&1)

if [ -f "$CUSTOM_OUT" ]; then
  pass_test "11.1 Option -o cree le fichier a l'emplacement specifie"
else
  fail_test "11.1 Option -o n'a pas cree le fichier" "$OUT"
fi

if echo "$OUT" | grep -q "Fichier RC genere.*custom_output.rc"; then
  pass_test "11.2 Rapport mentionne le nom de sortie correct"
else
  fail_test "11.2 Rapport ne mentionne pas le nom de sortie" "$OUT"
fi

echo ""

# =============================================================================
# Bilan final
# =============================================================================
echo "============================================================"
if [ $FAIL -eq 0 ]; then
  printf "${GREEN}  Bilan: %d/%d tests passes - SUCCES${NC}\n" "$PASS" "$TOTAL"
else
  printf "${RED}  Bilan: %d/%d tests passes, %d echec(s)${NC}\n" "$PASS" "$TOTAL" "$FAIL"
fi
echo "============================================================"
echo ""

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
