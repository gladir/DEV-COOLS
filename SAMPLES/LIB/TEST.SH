#!/bin/bash
# TEST.SH - Script de test pour la commande LIB
# Ce script teste toutes les fonctionnalites de la commande LIB

# Chemin vers les binaires
BINDIR="../../BINLINUX"
LIB="$BINDIR/LIB"

# Couleurs pour la sortie
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction pour afficher le resultat d'un test
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $2"
        ((TESTS_FAILED++))
    fi
}

echo "========================================"
echo "  Tests de la commande LIB"
echo "========================================"
echo ""

# Test 1: Verifier que LIB existe
echo -e "${YELLOW}Test 1: Verification du binaire LIB${NC}"
if [ -x "$LIB" ]; then
    test_result 0 "Le binaire LIB existe et est executable"
else
    test_result 1 "Le binaire LIB n'existe pas ou n'est pas executable"
    echo "Arret des tests."
    exit 1
fi

# Test 2: Afficher l'aide
echo -e "${YELLOW}Test 2: Affichage de l'aide${NC}"
$LIB /? > /dev/null 2>&1
test_result $? "Affichage de l'aide (/?) fonctionne"

# Test 3: Verifier que les fichiers OBJ existent
echo -e "${YELLOW}Test 3: Verification des fichiers OBJ${NC}"
if [ -f "MATH.OBJ" ] && [ -f "STRING.OBJ" ] && [ -f "IO.OBJ" ]; then
    test_result 0 "Tous les fichiers OBJ existent"
else
    test_result 1 "Certains fichiers OBJ sont manquants - compilez d'abord avec MASM"
    echo "Utilisez: ../../BINLINUX/MASM MATH.ASM && ../../BINLINUX/MASM STRING.ASM && ../../BINLINUX/MASM IO.ASM"
fi

# Test 4: Creer une bibliotheque
echo -e "${YELLOW}Test 4: Creation d'une bibliotheque${NC}"
rm -f TEST.LIB 2>/dev/null
$LIB /NOLOGO /OUT:TEST.LIB MATH.OBJ STRING.OBJ IO.OBJ > /dev/null 2>&1
if [ -f "TEST.LIB" ]; then
    test_result 0 "Creation de TEST.LIB"
else
    test_result 1 "Echec de la creation de TEST.LIB"
fi

# Test 5: Lister le contenu
echo -e "${YELLOW}Test 5: Listage du contenu${NC}"
OUTPUT=$($LIB /NOLOGO /LIST TEST.LIB 2>&1)
if echo "$OUTPUT" | grep -q "MATH.ASM"; then
    test_result 0 "Module MATH.ASM trouve dans la bibliotheque"
else
    test_result 1 "Module MATH.ASM non trouve"
fi

if echo "$OUTPUT" | grep -q "STRING.ASM"; then
    test_result 0 "Module STRING.ASM trouve dans la bibliotheque"
else
    test_result 1 "Module STRING.ASM non trouve"
fi

if echo "$OUTPUT" | grep -q "IO.ASM"; then
    test_result 0 "Module IO.ASM trouve dans la bibliotheque"
else
    test_result 1 "Module IO.ASM non trouve"
fi

if echo "$OUTPUT" | grep -q "Total: 3 module"; then
    test_result 0 "Nombre de modules correct (3)"
else
    test_result 1 "Nombre de modules incorrect"
fi

# Test 6: Afficher les symboles
echo -e "${YELLOW}Test 6: Affichage des symboles${NC}"
OUTPUT=$($LIB /NOLOGO /SYMBOLS TEST.LIB 2>&1)
SYMBOLS_FOUND=0

for SYM in ADD16 SUB16 MUL16 STRLEN STRCPY PUTCHAR GETCHAR NEWLINE; do
    if echo "$OUTPUT" | grep -q "$SYM"; then
        ((SYMBOLS_FOUND++))
    fi
done

if [ $SYMBOLS_FOUND -eq 8 ]; then
    test_result 0 "Tous les 8 symboles ont ete trouves"
else
    test_result 1 "Seulement $SYMBOLS_FOUND/8 symboles trouves"
fi

# Test 7: Mode verbeux
echo -e "${YELLOW}Test 7: Mode verbeux${NC}"
OUTPUT=$($LIB /VERBOSE /OUT:VERBOSE.LIB MATH.OBJ 2>&1)
if echo "$OUTPUT" | grep -q "Module:"; then
    test_result 0 "Mode verbeux fonctionne"
else
    test_result 1 "Mode verbeux ne fonctionne pas"
fi
rm -f VERBOSE.LIB 2>/dev/null

# Test 8: Fichier reponse (liste de fichiers OBJ)
echo -e "${YELLOW}Test 8: Fichier reponse${NC}"
echo "MATH.OBJ" > test.rsp
echo "STRING.OBJ" >> test.rsp

$LIB /NOLOGO /OUT:RESPONSE.LIB @test.rsp > /dev/null 2>&1
if [ -f "RESPONSE.LIB" ]; then
    test_result 0 "Fichier reponse fonctionne"
else
    test_result 1 "Fichier reponse ne fonctionne pas"
fi
rm -f test.rsp RESPONSE.LIB 2>/dev/null

# Nettoyage
echo ""
echo -e "${YELLOW}Nettoyage...${NC}"
rm -f TEST.LIB 2>/dev/null

# Resume
echo ""
echo "========================================"
echo "  Resume des tests"
echo "========================================"
echo -e "Tests reussis: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests echoues: ${RED}$TESTS_FAILED${NC}"
TOTAL=$((TESTS_PASSED + TESTS_FAILED))
echo "Total: $TOTAL tests"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}Tous les tests ont reussi!${NC}"
    exit 0
else
    echo -e "${RED}Certains tests ont echoue.${NC}"
    exit 1
fi

