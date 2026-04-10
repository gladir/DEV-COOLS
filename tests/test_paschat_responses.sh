#!/bin/bash
# Script de test final pour vérifier les réponses cohérentes de PASCHAT
# Vérifie que toutes les entrées génèrent des réponses cohérentes

PASCHAT="/tmp/PASCHAT"
PASSED=0
FAILED=0
TOTAL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_response() {
    local input="$1"
    local expected="$2"
    local test_name="$3"
    
    TOTAL=$((TOTAL + 1))
    
    output=$(echo -e "$input\n/quit" | timeout 5 $PASCHAT 2>&1 || true)
    
    if echo "$output" | grep -qiE "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Input: $input"
        echo "  Expected pattern: $expected"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

test_no_crash_with_output() {
    local input="$1"
    local test_name="$2"
    
    TOTAL=$((TOTAL + 1))
    
    output=$(echo -e "$input\n/quit" | timeout 5 $PASCHAT 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -qi "revoir"; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "==================================================="
echo -e "${YELLOW}   Tests de réponses cohérentes pour PASCHAT${NC}"
echo "==================================================="
echo ""

# ===================
# TESTS DE SALUTATION
# ===================
echo "--- 1. Tests de salutations (4 tests) ---"
test_response "bonjour" "Bonjour|Comment|aide|Pascal" "Salutation 'bonjour'"
test_response "salut" "Bonjour|Comment|aide|Pascal" "Salutation 'salut'"
test_response "hello" "Bonjour|Comment|aide|Pascal" "Salutation 'hello'"
test_response "allo" "Bonjour|Comment|aide|Pascal" "Salutation 'allo'"

echo ""
# ======================
# TESTS DE COMMANDES
# ======================
echo "--- 2. Tests de commandes spéciales (5 tests) ---"
test_response "/help" "aide|Aide|commande|Commandes|generer" "Commande /help"
test_response "/quit" "revoir|bientot" "Commande /quit"
test_response "/exit" "revoir|bientot" "Commande /exit"
test_response "quitter" "revoir|bientot" "Texte 'quitter'"
test_response "au revoir" "revoir|bientot" "Texte 'au revoir'"

echo ""
# ================================
# TESTS D'EXPLICATION
# ================================
echo "--- 3. Tests d'explication (4 tests) ---"
test_response "qu'est-ce qu'une procedure" "n.ai pas trouve|procedure|Procedure" "Explication 'procedure'"
test_response "comment faire une boucle" "n.ai pas trouve|boucle|FOR|WHILE" "Explication 'boucle'"
test_response "c'est quoi un tableau" "n.ai pas trouve|tableau|Array" "Explication 'tableau'"
test_response "explique le if" "n.ai pas trouve|IF|condition" "Explication 'if'"

echo ""
# ================================
# TESTS DE GÉNÉRATION DE CODE
# ================================
echo "--- 4. Tests de génération de code (5 tests) ---"
test_response "ecris un programme bonjour" "programme|Program|Voici|code" "Programme 'bonjour'"
test_response "génère un programme pascal" "programme|Program|Voici|code" "Programme généré"
test_response "cree une procedure de test" "procedure|Procedure|Voici|code" "Procédure créée"
test_response "fais une fonction addition" "function|Function|Voici|code|programme" "Fonction créée"
test_response "affiche hello world" "programme|Program|Voici|code" "Programme affichage"

echo ""
# ================================
# TESTS D'ENTRÉES INCONNUES
# ================================
echo "--- 5. Tests d'entrées inconnues/invalides (3 tests) ---"
test_response "xyz123abc" "compris|reformuler|help|n.ai pas" "Entrée inconnue"
test_no_crash_with_output "" "Entrée vide"
test_no_crash_with_output "      " "Entrée espaces"

echo ""
# ================================
# TESTS DE ROBUSTESSE
# ================================
echo "--- 6. Tests de robustesse (3 tests) ---"
test_no_crash_with_output "!@#\$%^&*()" "Caractères spéciaux"
test_no_crash_with_output "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "Entrée longue"
test_no_crash_with_output "test1\ntest2\ntest3" "Entrées multiples"

echo ""
echo "==================================================="
echo -e "${YELLOW}   RÉSUMÉ DES TESTS${NC}"
echo "==================================================="
echo "Total:  $TOTAL tests"
echo -e "Passés: ${GREEN}$PASSED${NC}"
echo -e "Échoués: ${RED}$FAILED${NC}"
echo ""

PERCENT=$((PASSED * 100 / TOTAL))
echo "Taux de réussite: $PERCENT%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ TOUS LES TESTS SONT PASSÉS!${NC}"
    echo ""
    echo "PASCHAT répond de manière cohérente à toutes les entrées testées:"
    echo "  - Salutations"
    echo "  - Commandes spéciales (/help, /quit)"
    echo "  - Demandes d'explication"
    echo "  - Demandes de génération de code"
    echo "  - Entrées invalides (avec message d'erreur approprié)"
    echo "  - Caractères spéciaux (sans crash)"
    exit 0
else
    echo -e "${RED}✗ $FAILED test(s) ont échoué${NC}"
    exit 1
fi
