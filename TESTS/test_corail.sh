#!/bin/sh
# =============================================================================
# test_corail.sh - Test TPCW32 avec les fichiers .PAS du projet gladir/corail
# =============================================================================
#
# Usage:
#   ./TESTS/test_corail.sh [chemin_vers_TPCW32] [chemin_vers_corail]
#
# Exemples:
#   ./TESTS/test_corail.sh /tmp/TPCW32 /tmp/corail-master
#   ./TESTS/test_corail.sh ./TPCW32 ../corail
#
# Si les arguments ne sont pas fournis, le script tente de compiler TPCW32
# et de telecharger le depot corail automatiquement.
#
# Le timeout par fichier est de 5 secondes (modifiable via TIMEOUT_SEC).
# =============================================================================

TIMEOUT_SEC=5

TPCW32_BIN="${1:-}"
CORAIL_DIR="${2:-}"

# Si TPCW32 n'est pas fourni, le compiler
if [ -z "$TPCW32_BIN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_DIR="$(dirname "$SCRIPT_DIR")"
  if [ -f "$REPO_DIR/TPCW32.PAS" ]; then
    echo "Compilation de TPCW32.PAS..."
    fpc -Mtp "$REPO_DIR/TPCW32.PAS" -o/tmp/TPCW32 2>&1 | tail -3
    if [ $? -ne 0 ]; then
      echo "ERREUR: Echec de la compilation de TPCW32.PAS"
      exit 1
    fi
    TPCW32_BIN="/tmp/TPCW32"
  else
    echo "ERREUR: TPCW32.PAS introuvable et aucun binaire specifie."
    echo "Usage: $0 [chemin_vers_TPCW32] [chemin_vers_corail]"
    exit 1
  fi
fi

# Si le repertoire corail n'est pas fourni, le telecharger
if [ -z "$CORAIL_DIR" ]; then
  if [ ! -d "/tmp/corail-master" ]; then
    echo "Telechargement du depot gladir/corail..."
    curl -sL -o /tmp/corail.zip "https://github.com/gladir/corail/archive/refs/heads/master.zip"
    if [ ! -s /tmp/corail.zip ] || file /tmp/corail.zip | grep -q "text"; then
      echo "ERREUR: Echec du telechargement de corail."
      exit 1
    fi
    cd /tmp && unzip -q corail.zip
  fi
  CORAIL_DIR="/tmp/corail-master"
fi

# Verifier les chemins
if [ ! -x "$TPCW32_BIN" ]; then
  echo "ERREUR: $TPCW32_BIN n'existe pas ou n'est pas executable."
  exit 1
fi

PAS_COUNT=$(ls "$CORAIL_DIR"/*.PAS 2>/dev/null | wc -l)
if [ "$PAS_COUNT" -eq 0 ]; then
  echo "ERREUR: Aucun fichier .PAS trouve dans $CORAIL_DIR"
  exit 1
fi

echo "============================================================"
echo "  Test TPCW32 avec les fichiers .PAS du projet corail"
echo "============================================================"
echo "  TPCW32:    $TPCW32_BIN"
echo "  Corail:    $CORAIL_DIR"
echo "  Fichiers:  $PAS_COUNT .PAS"
echo "  Timeout:   ${TIMEOUT_SEC}s par fichier"
echo "============================================================"
echo ""

PASS=0
FAIL=0
TIMEOUT_COUNT=0
TOTAL=0
FAIL_LIST=""
TIMEOUT_LIST=""

for f in "$CORAIL_DIR"/*.PAS; do
  TOTAL=$((TOTAL + 1))
  base=$(basename "$f")
  timeout "$TIMEOUT_SEC" "$TPCW32_BIN" "$f" -asm > /dev/null 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    PASS=$((PASS + 1))
  elif [ $rc -eq 124 ]; then
    TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1))
    TIMEOUT_LIST="$TIMEOUT_LIST  $base
"
  else
    FAIL=$((FAIL + 1))
    FAIL_LIST="$FAIL_LIST  $base (rc=$rc)
"
  fi
  if [ $((TOTAL % 50)) -eq 0 ]; then
    echo "  Progression: $TOTAL/$PAS_COUNT fichiers traites..."
  fi
done

echo ""
echo "============================================================"
echo "  RESULTATS"
echo "============================================================"
echo "  Total:       $TOTAL"
echo "  Succes:      $PASS"
echo "  Echecs:      $FAIL"
echo "  Timeouts:    $TIMEOUT_COUNT"
echo "  Taux:        $(( PASS * 100 / TOTAL ))%"
echo "============================================================"

if [ -n "$FAIL_LIST" ]; then
  echo ""
  echo "Fichiers en echec:"
  echo "$FAIL_LIST"
fi

if [ -n "$TIMEOUT_LIST" ]; then
  echo ""
  echo "Fichiers en timeout (>${TIMEOUT_SEC}s):"
  echo "$TIMEOUT_LIST"
fi

# Code de retour: 0 si au moins 70% passent
THRESHOLD=$(( TOTAL * 70 / 100 ))
if [ $PASS -ge $THRESHOLD ]; then
  echo ""
  echo "OK: $PASS/$TOTAL fichiers passent (seuil: 70%)"
  exit 0
else
  echo ""
  echo "ECHEC: Seulement $PASS/$TOTAL fichiers passent (seuil: 70%)"
  exit 1
fi
