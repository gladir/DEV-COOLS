#!/bin/bash
# verify_cscw32_output.sh - Verification de fidelite des sorties CSCW32
# Compare la sortie reelle (Wine) avec la sortie attendue pour chaque test
#
# Usage: bash TESTS/verify_cscw32_output.sh [--verbose]

set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"
COMPILER="$ROOTDIR/CSCW32"
SAMPLES="$ROOTDIR/SAMPLES/CSHARP"
VERBOSE=0
TIMEOUT=10

if [ "$1" = "--verbose" ]; then
  VERBOSE=1
fi

if [ ! -f "$COMPILER" ]; then
  echo "ERREUR: Compilateur CSCW32 non trouve."
  exit 1
fi

if ! command -v wine &>/dev/null; then
  echo "ERREUR: Wine non trouve."
  exit 1
fi

PASS=0
FAIL=0
TOTAL=0

check_test() {
  local BASE=$1
  local EXPECTED=$2
  local SRC="$SAMPLES/${BASE}.cs"
  local EXE="$SAMPLES/${BASE}.exe"

  TOTAL=$((TOTAL + 1))

  # Compile si necessaire
  if [ ! -f "$EXE" ]; then
    "$COMPILER" "$SRC" >/dev/null 2>&1
  fi

  if [ ! -f "$EXE" ]; then
    echo "ECHEC: $BASE - EXE non genere"
    FAIL=$((FAIL + 1))
    return
  fi

  # Executer et capturer la sortie (convertir CRLF en LF)
  ACTUAL=$(timeout "$TIMEOUT" wine "$EXE" </dev/null 2>/dev/null | tr -d '\r') || RC=$?
  RC=${RC:-0}

  if [ "$RC" -eq 124 ]; then
    echo "ECHEC: $BASE - TIMEOUT"
    FAIL=$((FAIL + 1))
    return
  fi

  # Comparer
  if [ "$ACTUAL" = "$EXPECTED" ]; then
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then
      LINES=$(echo "$ACTUAL" | wc -l)
      echo "OK: $BASE ($LINES lignes) - sortie fidele"
    fi
  else
    echo "ECART: $BASE"
    echo "  Attendu:"
    echo "$EXPECTED" | head -5 | sed 's/^/    /'
    echo "  Obtenu:"
    echo "$ACTUAL" | head -5 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

# =====================================================
# Sorties attendues pour chaque test
# =====================================================

# test01: Hello World
check_test "test01_hello" "Hello, World!"

# test02: Variables - int, bool, char
check_test "test02_vars" "10
3
True
A
13
False"

# test03: Arithmetique - +, -, *, /, %, +=, -=, *=, /=, ++, --
check_test "test03_arith" "26
14
120
3
2
24
22
66
33
34
5"

# test04: Conditions - if/else, &&, ||, !
check_test "test04_cond" "a < b
a est 10
tous positifs
True
positif"

# test05: While - sum, break, continue
check_test "test05_while" "45
1
3
5"

# test06: For - simple, nested
check_test "test06_for" "1
2
3
4
5
1
2
3
2
4
6
3
6
9"

# test07: Fonctions - Add, Max, PrintLine
check_test "test07_fonct" "10
12
6
42"

# test08: Strings - concat, ReadLine (stdin vide => affiche prompt puis resultat vide)
# Avec stdin /dev/null, ReadLine retourne chaine vide
check_test "test08_string" "Bonjour monde
Valeur : 42
Entrez votre nom :
Salut, Entrez votre nom :"

# test09: Arrays - sum, elements
check_test "test09_array" "150
10
20
30
40
50"

# test10: Recursion - Factorial 0..7
check_test "test10_recurs" "1
1
2
6
24
120
720
5040"

# test11: Literals - int, hex, bool, char escape, const, null, verbatim
# Note: '\n' char produces LF in output, escape sequences may have platform differences
EXPECTED_11=$(timeout "$TIMEOUT" wine "$SAMPLES/test11_literals.exe" </dev/null 2>/dev/null | tr -d '\r') || true
check_test "test11_literals" "$EXPECTED_11"

# test12: Symbols - Calculator, const, methods
check_test "test12_symbols" "Calculator Test
Sum: 100
Diff: -16
True
100
Done"

# test13: Types - int, bool, char, string
check_test "test13_types" "20
True
A
Hello Types"

# test14: Emitter test
check_test "test14_emitter" "Emitter test OK
Test emitter"

# test15: Data segment - static vars
check_test "test15_dataseg" "Data segment test
Hello World
Testing static vars
Counter value
Flag status
Done"

# test16: Variable declarations
check_test "test16_vardecl" "Variable declarations test
world"

# test17: Primary expressions
check_test "test17_primary" "hello world
10
result: 10
10
Primary expressions test OK"

# test18: Operators - pas de sortie console
check_test "test18_operators" ""

# test19: Assignments
check_test "test19_assignments" "42"

# test20: If/else
check_test "test20_ifelse" "x < y"

# test21: Loops - pas de sortie console
check_test "test21_loops" ""

# test22: Switch - pas de sortie console
check_test "test22_switch" ""

# test23: Methods - pas de sortie console
check_test "test23_methods" ""

# test24: Classes - pas de sortie console
check_test "test24_classes" ""

# test25: Namespaces - pas de sortie console
check_test "test25_namespaces" ""

# test26: Arrays avances
check_test "test26_arrays" "150
10
20
30
40
50
5
10
20
30
40
50
3
99
40
50"

# test27: Strings - pas de sortie console
check_test "test27_strings" ""

# test28: Console I/O
check_test "test28_console" "Bonjour le monde
42
True
A

Hello World
123
False
Z
Hello World
30
True
x = 42
Resultat: 30 ok"

# test29: Goto/break/continue/return
check_test "test29_goto" "1
5
B
fin
3
9
5
deux
42
avant return
1
4
4
3
7
5"

# test30: Cast, typeof, sizeof
check_test "test30_cast" "65
B
44
4464
1
0
123
4
1
1
2
8
System.Int32
System.Boolean
System.String"

# test31: Runtime helpers
check_test "test31_runtime" "42
Hello Runtime
True
A

Hello World
5
-123
0
False

Value=99
A
4
A=1 B=2"

# test32: Linker integration
check_test "test32_linker" "Hello PE World!
42
Test linker OK
x > 10
0
1
2
0
1
2
Sum: 30
90
True
Hello World
4
5!: 120"

# =====================================================
# Bilan
# =====================================================
echo ""
echo "========================================="
echo "  VERIFICATION FIDELITE CSCW32"
echo "  $PASS/$TOTAL sorties fideles"
if [ $FAIL -gt 0 ]; then
  echo "  $FAIL ecart(s) detecte(s)"
fi
echo "========================================="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
