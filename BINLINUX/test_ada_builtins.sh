#!/bin/bash
# test_ada_builtins.sh : suite de tests Wine pour les fonctions built-in Ada.
#
# Compile chaque sample T30..T35 avec ADACW32 puis execute l.exe sous Wine
# et verifie que la sortie contient le marqueur final "=== FIN ===". Affiche
# un tableau PASS/FAIL et un code de sortie non-zero en cas d.echec.

set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
ADACW32="${ROOT}/BINLINUX/ADACW32"
SAMPLES="${ROOT}/SAMPLES/ADA"

if [ ! -x "${ADACW32}" ]; then
    echo "ERREUR: ${ADACW32} introuvable. Compiler d.abord : fpc -Mtp ADACW32.PAS"
    exit 2
fi

if ! command -v wine >/dev/null 2>&1; then
    echo "ERREUR: wine n.est pas installe"
    exit 2
fi

# Liste des tests de fonctions built-in (T30..T35).
TESTS=(
    T30_LATIN1
    T31_HANDLING
    T32_NUMERICS
    T33_STRINGS
    T34_TEXTIO
    T35_ALLMODS
    T36_ASMINLINE
)

PASS=0
FAIL=0
FAILED_TESTS=""

echo "=== Tests Ada built-in sous Wine ==="
for t in "${TESTS[@]}"; do
    SRC="${SAMPLES}/${t}.ADB"
    EXE="${SAMPLES}/${t}.exe"

    if [ ! -f "${SRC}" ]; then
        printf "  [SKIP] %-16s (source absent)\n" "${t}"
        continue
    fi

    # Compilation
    if ! "${ADACW32}" "${SRC}" 2>/dev/null | tail -3 | grep -q "Erreurs    : 0"; then
        printf "  [FAIL] %-16s (compilation)\n" "${t}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS="${FAILED_TESTS} ${t}(compile)"
        continue
    fi

    if [ ! -f "${EXE}" ]; then
        printf "  [FAIL] %-16s (exe non produit)\n" "${t}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS="${FAILED_TESTS} ${t}(exe)"
        continue
    fi

    # Execution Wine : verifier le marqueur final
    OUTPUT=$(WINEDEBUG=-all wine "${EXE}" 2>/dev/null)
    if echo "${OUTPUT}" | grep -q "=== FIN ==="; then
        LINES=$(echo "${OUTPUT}" | wc -l)
        printf "  [PASS] %-16s (%3d lignes)\n" "${t}" "${LINES}"
        PASS=$((PASS + 1))
    else
        printf "  [FAIL] %-16s (marqueur FIN absent)\n" "${t}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS="${FAILED_TESTS} ${t}(run)"
    fi
done

echo "---"
echo "Resultat : ${PASS} PASS, ${FAIL} FAIL"
if [ "${FAIL}" -gt 0 ]; then
    echo "Echecs :${FAILED_TESTS}"
    exit 1
fi
exit 0
