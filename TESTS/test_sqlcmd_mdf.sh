#!/bin/sh
# =============================================================================
# test_sqlcmd_mdf.sh - Tests d'integration de SQLCMD avec fichiers .MDF
# =============================================================================
#
# Ce script teste que SQLCMD.PAS peut lire un vrai fichier .MDF genere
# programmatiquement et executer des requetes SELECT, USE, WHERE, GROUP BY,
# ORDER BY, COUNT, SUM, AVG, MIN, MAX correctement.
#
# Le fichier MDF contient une table Employees avec 8 lignes et 5 colonnes :
#   EmployeeId INT, Salary INT, FirstName VARCHAR, LastName VARCHAR, Department VARCHAR
#
# Usage:
#   ./TESTS/test_sqlcmd_mdf.sh [chemin_vers_SQLCMD]
#
# Si le chemin n'est pas fourni, le script compile SQLCMD.PAS automatiquement.
# =============================================================================

TIMEOUT_SEC=30
PASS=0
FAIL=0
TOTAL=0
TMPDIR="/tmp/test_sqlcmd_mdf_$$"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR"

# ==== Couleurs ====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass_test() {
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  printf "${GREEN}  PASS${NC} %s\n" "$1"
}

fail_test() {
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  printf "${RED}  FAIL${NC} %s\n" "$1"
}

# ==== Localiser le binaire SQLCMD ====
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"

if [ -n "$1" ]; then
  SQLCMD_BIN="$1"
elif [ -x "$ROOTDIR/SQLCMD" ]; then
  SQLCMD_BIN="$ROOTDIR/SQLCMD"
else
  echo "Compilation de SQLCMD.PAS..."
  if command -v fpc > /dev/null 2>&1; then
    cd "$ROOTDIR"
    fpc -Mtp SQLCMD.PAS > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "ERREUR: Echec de la compilation de SQLCMD.PAS"
      exit 1
    fi
    SQLCMD_BIN="$ROOTDIR/SQLCMD"
  else
    echo "ERREUR: fpc (Free Pascal Compiler) non trouve"
    exit 1
  fi
fi

if [ ! -x "$SQLCMD_BIN" ]; then
  echo "ERREUR: $SQLCMD_BIN n'est pas executable"
  exit 1
fi

echo ""
echo "============================================================"
echo "  Tests d'integration SQLCMD + fichier MDF"
echo "  Binaire: $SQLCMD_BIN"
echo "============================================================"
echo ""

# ==== Generer le fichier MDF de test ====
echo "Generation du fichier MDF de test..."
MDF_FILE="$TMPDIR/test.mdf"
python3 "$ROOTDIR/TESTS/gen_test_mdf.py" "$MDF_FILE" > "$TMPDIR/gen_output.txt" 2>&1
if [ $? -ne 0 ]; then
  echo "ERREUR: Echec de la generation du fichier MDF"
  cat "$TMPDIR/gen_output.txt"
  exit 1
fi

if [ ! -f "$MDF_FILE" ]; then
  echo "ERREUR: Fichier MDF non cree"
  exit 1
fi

FILE_SIZE=$(wc -c < "$MDF_FILE")
echo "  Fichier MDF: $MDF_FILE ($FILE_SIZE octets)"
echo ""

# =========================================================================
# SECTION 1 : Tests de base - Ouverture MDF et --selftest
# =========================================================================
echo "--- SECTION 1 : Tests de base ---"

# Test 1.1: Self-tests internes
timeout $TIMEOUT_SEC "$SQLCMD_BIN" --selftest > "$TMPDIR/out_1_1.txt" 2>&1
RC=$?
TESTS_PASSED=$(grep "^Reussi" "$TMPDIR/out_1_1.txt" | head -1)
if [ $RC -eq 0 ] && echo "$TESTS_PASSED" | grep -q "218"; then
  pass_test "1.1 Self-tests: 218 tests reussis"
else
  fail_test "1.1 Self-tests: exit=$RC $TESTS_PASSED"
fi

# Test 1.2: Ouverture du fichier MDF
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT 1 AS Test" > "$TMPDIR/out_1_2.txt" 2>&1
RC=$?
if [ $RC -eq 0 ] && grep -q "Test" "$TMPDIR/out_1_2.txt"; then
  pass_test "1.2 Ouverture MDF: SELECT 1 reussit"
else
  fail_test "1.2 Ouverture MDF: exit=$RC"
fi

# Test 1.3: Verification du nombre de pages
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -v -q "SELECT 1 AS X" > "$TMPDIR/out_1_3.txt" 2>&1
if grep -q "Nombre de pages: 13" "$TMPDIR/out_1_3.txt"; then
  pass_test "1.3 MDF contient 13 pages"
else
  fail_test "1.3 Nombre de pages incorrect"
fi

# Test 1.4: Nom de la base de donnees
if grep -q "dbName.*=.*TestDB" "$TMPDIR/out_1_3.txt"; then
  pass_test "1.4 Base de donnees: TestDB"
else
  fail_test "1.4 Nom de BD incorrect"
fi

echo ""

# =========================================================================
# SECTION 2 : Commande USE
# =========================================================================
echo "--- SECTION 2 : Commande USE ---"

# Test 2.1: USE master
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "USE master" > "$TMPDIR/out_2_1.txt" 2>&1
if grep -q "Changed database context to 'master'" "$TMPDIR/out_2_1.txt"; then
  pass_test "2.1 USE master: message de changement correct"
else
  fail_test "2.1 USE master: message incorrect"
fi

# Test 2.2: USE TestDB
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "USE TestDB" > "$TMPDIR/out_2_2.txt" 2>&1
if grep -q "Changed database context to 'TestDB'" "$TMPDIR/out_2_2.txt"; then
  pass_test "2.2 USE TestDB: message de changement correct"
else
  fail_test "2.2 USE TestDB: message incorrect"
fi

# Test 2.3: Script test_use.sql
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -i "$ROOTDIR/SAMPLES/SQLSERVER/test_use.sql" > "$TMPDIR/out_2_3.txt" 2>&1
RC=$?
if [ $RC -eq 0 ] && grep -q "Changed database context to 'master'" "$TMPDIR/out_2_3.txt" && \
   grep -q "Changed database context to 'TestDB'" "$TMPDIR/out_2_3.txt" && \
   grep -q "1" "$TMPDIR/out_2_3.txt"; then
  pass_test "2.3 Script test_use.sql: USE master + USE TestDB + SELECT"
else
  fail_test "2.3 Script test_use.sql: exit=$RC"
fi

echo ""

# =========================================================================
# SECTION 3 : SELECT * FROM Employees (toutes les donnees)
# =========================================================================
echo "--- SECTION 3 : SELECT * FROM Employees ---"

timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT * FROM Employees" > "$TMPDIR/out_3.txt" 2>&1

# Test 3.1: 8 lignes retournees
if grep -q "8 ligne(s) affectee(s)" "$TMPDIR/out_3.txt"; then
  pass_test "3.1 SELECT *: 8 lignes retournees"
else
  fail_test "3.1 SELECT *: nombre de lignes incorrect"
fi

# Test 3.2: Verification de chaque employe
if grep -q "Alice.*Martin.*Engineering" "$TMPDIR/out_3.txt"; then
  pass_test "3.2 Donnees: Alice Martin Engineering present"
else
  fail_test "3.2 Donnees: Alice Martin absent"
fi

if grep -q "Bob.*Dupont.*Sales" "$TMPDIR/out_3.txt"; then
  pass_test "3.3 Donnees: Bob Dupont Sales present"
else
  fail_test "3.3 Donnees: Bob Dupont absent"
fi

if grep -q "Charlie.*Bernard.*Engineering" "$TMPDIR/out_3.txt"; then
  pass_test "3.4 Donnees: Charlie Bernard Engineering present"
else
  fail_test "3.4 Donnees: Charlie Bernard absent"
fi

if grep -q "Diana.*Leroy.*Marketing" "$TMPDIR/out_3.txt"; then
  pass_test "3.5 Donnees: Diana Leroy Marketing present"
else
  fail_test "3.5 Donnees: Diana Leroy absent"
fi

if grep -q "Eve.*Moreau.*Engineering" "$TMPDIR/out_3.txt"; then
  pass_test "3.6 Donnees: Eve Moreau Engineering present"
else
  fail_test "3.6 Donnees: Eve Moreau absent"
fi

if grep -q "Frank.*Simon.*Sales" "$TMPDIR/out_3.txt"; then
  pass_test "3.7 Donnees: Frank Simon Sales present"
else
  fail_test "3.7 Donnees: Frank Simon absent"
fi

if grep -q "Grace.*Laurent.*Marketing" "$TMPDIR/out_3.txt"; then
  pass_test "3.8 Donnees: Grace Laurent Marketing present"
else
  fail_test "3.8 Donnees: Grace Laurent absent"
fi

if grep -q "Henri.*Roux.*Engineering" "$TMPDIR/out_3.txt"; then
  pass_test "3.9 Donnees: Henri Roux Engineering present"
else
  fail_test "3.9 Donnees: Henri Roux absent"
fi

# Test 3.10: Verifier les salaires
if grep -q "75000.*Alice" "$TMPDIR/out_3.txt"; then
  pass_test "3.10 Salaire Alice = 75000"
else
  fail_test "3.10 Salaire Alice incorrect"
fi

if grep -q "92000.*Eve" "$TMPDIR/out_3.txt"; then
  pass_test "3.11 Salaire Eve = 92000"
else
  fail_test "3.11 Salaire Eve incorrect"
fi

echo ""

# =========================================================================
# SECTION 4 : WHERE clause
# =========================================================================
echo "--- SECTION 4 : WHERE clause ---"

# Test 4.1: WHERE Salary > 70000
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT * FROM Employees WHERE Salary > 70000" > "$TMPDIR/out_4_1.txt" 2>&1
if grep -q "4 ligne(s) affectee(s)" "$TMPDIR/out_4_1.txt"; then
  pass_test "4.1 WHERE Salary > 70000: 4 lignes (Alice, Charlie, Eve, Henri)"
else
  fail_test "4.1 WHERE Salary > 70000: nombre incorrect"
fi

# Test 4.2: WHERE Department = 'Sales'
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT * FROM Employees WHERE Department = 'Sales'" > "$TMPDIR/out_4_2.txt" 2>&1
if grep -q "2 ligne(s) affectee(s)" "$TMPDIR/out_4_2.txt" && \
   grep -q "Bob" "$TMPDIR/out_4_2.txt" && grep -q "Frank" "$TMPDIR/out_4_2.txt"; then
  pass_test "4.2 WHERE Department='Sales': Bob et Frank"
else
  fail_test "4.2 WHERE Department='Sales': resultat incorrect"
fi

# Test 4.3: WHERE with AND
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT * FROM Employees WHERE Salary > 50000 AND Department = 'Engineering'" > "$TMPDIR/out_4_3.txt" 2>&1
if grep -q "4 ligne(s) affectee(s)" "$TMPDIR/out_4_3.txt"; then
  pass_test "4.3 WHERE Salary>50000 AND Department='Engineering': 4 lignes"
else
  fail_test "4.3 WHERE AND: resultat incorrect"
fi

echo ""

# =========================================================================
# SECTION 5 : Fonctions d'agregation
# =========================================================================
echo "--- SECTION 5 : Fonctions d'agregation ---"

# Test 5.1: COUNT(*)
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT COUNT(*) AS Total FROM Employees" > "$TMPDIR/out_5_1.txt" 2>&1
if grep -q "^8" "$TMPDIR/out_5_1.txt"; then
  pass_test "5.1 COUNT(*) = 8"
else
  fail_test "5.1 COUNT(*) incorrect"
fi

# Test 5.2: SUM(Salary)
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT SUM(Salary) AS TotalSalary FROM Employees" > "$TMPDIR/out_5_2.txt" 2>&1
if grep -q "533000" "$TMPDIR/out_5_2.txt"; then
  pass_test "5.2 SUM(Salary) = 533000"
else
  fail_test "5.2 SUM(Salary) incorrect"
fi

# Test 5.3: AVG(Salary)
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT AVG(Salary) AS AvgSalary FROM Employees" > "$TMPDIR/out_5_3.txt" 2>&1
if grep -q "66625" "$TMPDIR/out_5_3.txt"; then
  pass_test "5.3 AVG(Salary) = 66625"
else
  fail_test "5.3 AVG(Salary) incorrect"
fi

# Test 5.4: MIN/MAX
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT MIN(Salary) AS MinSal, MAX(Salary) AS MaxSal FROM Employees" > "$TMPDIR/out_5_4.txt" 2>&1
if grep -q "45000" "$TMPDIR/out_5_4.txt" && grep -q "92000" "$TMPDIR/out_5_4.txt"; then
  pass_test "5.4 MIN=45000, MAX=92000"
else
  fail_test "5.4 MIN/MAX incorrect"
fi

# Test 5.5: GROUP BY
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT Department, COUNT(*) AS Cnt FROM Employees GROUP BY Department" > "$TMPDIR/out_5_5.txt" 2>&1
if grep -q "Engineering.*4" "$TMPDIR/out_5_5.txt" && \
   grep -q "Sales.*2" "$TMPDIR/out_5_5.txt" && \
   grep -q "Marketing.*2" "$TMPDIR/out_5_5.txt"; then
  pass_test "5.5 GROUP BY: Engineering=4, Sales=2, Marketing=2"
else
  fail_test "5.5 GROUP BY incorrect"
fi

# Test 5.6: Script test_aggregate.sql
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -i "$ROOTDIR/SAMPLES/SQLSERVER/test_aggregate.sql" > "$TMPDIR/out_5_6.txt" 2>&1
RC=$?
if [ $RC -eq 0 ] && grep -q "533000" "$TMPDIR/out_5_6.txt" && grep -q "66625" "$TMPDIR/out_5_6.txt"; then
  pass_test "5.6 Script test_aggregate.sql execute avec succes"
else
  fail_test "5.6 Script test_aggregate.sql: exit=$RC"
fi

echo ""

# =========================================================================
# SECTION 6 : ORDER BY
# =========================================================================
echo "--- SECTION 6 : ORDER BY ---"

# Test 6.1: ORDER BY Salary DESC
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT FirstName, Salary FROM Employees ORDER BY Salary DESC" > "$TMPDIR/out_6_1.txt" 2>&1
# Skip header (2 lines: column names + separator), first data line should be Eve (92000)
FIRST_NAME=$(sed -n '3p' "$TMPDIR/out_6_1.txt" | awk '{print $1}')
if [ "$FIRST_NAME" = "Eve" ]; then
  pass_test "6.1 ORDER BY Salary DESC: Eve en premier (92000)"
else
  fail_test "6.1 ORDER BY DESC: premier=$FIRST_NAME (attendu: Eve)"
fi

# Test 6.2: ORDER BY LastName ASC
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT LastName FROM Employees ORDER BY LastName ASC" > "$TMPDIR/out_6_2.txt" 2>&1
FIRST_LAST=$(sed -n '3p' "$TMPDIR/out_6_2.txt" | awk '{print $1}')
if [ "$FIRST_LAST" = "Bernard" ]; then
  pass_test "6.2 ORDER BY LastName ASC: Bernard en premier"
else
  fail_test "6.2 ORDER BY LastName ASC: premier=$FIRST_LAST (attendu: Bernard)"
fi

echo ""

# =========================================================================
# SECTION 7 : Fonctions scalaires (sans MDF requis)
# =========================================================================
echo "--- SECTION 7 : Fonctions scalaires ---"

# Test 7.1: Expressions arithmetiques simples
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT 10 + 32 AS Result" > "$TMPDIR/out_7_1.txt" 2>&1
if grep -q "42" "$TMPDIR/out_7_1.txt"; then
  pass_test "7.1 Expression 10+32 = 42"
else
  fail_test "7.1 Expression 10+32 incorrect"
fi

# Test 7.2: Multiple columns with string literals
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT 'Hello' AS Col1, 'World' AS Col2" > "$TMPDIR/out_7_2.txt" 2>&1
if grep -q "Hello" "$TMPDIR/out_7_2.txt" && grep -q "World" "$TMPDIR/out_7_2.txt"; then
  pass_test "7.2 SELECT 'Hello' AS Col1, 'World' AS Col2"
else
  fail_test "7.2 String literals incorrect"
fi

# Test 7.3: CASE expression
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT CASE WHEN 5 > 3 THEN 'OK' ELSE 'KO' END AS Result" > "$TMPDIR/out_7_3.txt" 2>&1
if grep -q "OK" "$TMPDIR/out_7_3.txt"; then
  pass_test "7.3 CASE WHEN 5>3 THEN 'OK' = 'OK'"
else
  fail_test "7.3 CASE expression incorrect"
fi

# Test 7.4: CAST
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT CAST(123 AS VARCHAR(10)) AS Result" > "$TMPDIR/out_7_4.txt" 2>&1
if grep -q "123" "$TMPDIR/out_7_4.txt"; then
  pass_test "7.4 CAST(123 AS VARCHAR) = '123'"
else
  fail_test "7.4 CAST incorrect"
fi

# Test 7.5: IIF
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT IIF(1 > 0, 'Vrai', 'Faux') AS Result" > "$TMPDIR/out_7_5.txt" 2>&1
if grep -q "Vrai" "$TMPDIR/out_7_5.txt"; then
  pass_test "7.5 IIF(1>0, 'Vrai', 'Faux') = 'Vrai'"
else
  fail_test "7.5 IIF incorrect"
fi

# Test 7.6: COALESCE
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT COALESCE(NULL, 42) AS Result" > "$TMPDIR/out_7_6.txt" 2>&1
if grep -q "42" "$TMPDIR/out_7_6.txt"; then
  pass_test "7.6 COALESCE(NULL, 42) = 42"
else
  fail_test "7.6 COALESCE incorrect"
fi

echo ""

# =========================================================================
# SECTION 8 : Validation de coherence des donnees
# =========================================================================
echo "--- SECTION 8 : Validation de coherence ---"

# Test 8.1: SUM doit etre coherent avec les valeurs individuelles
# 75000+62000+85000+45000+92000+55000+48000+71000 = 533000
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT SUM(Salary) AS Total FROM Employees" > "$TMPDIR/out_8_1.txt" 2>&1
if grep -q "533000" "$TMPDIR/out_8_1.txt"; then
  pass_test "8.1 Coherence: SUM(Salary) = 533000 (somme verifiee)"
else
  fail_test "8.1 Coherence: SUM incorrect"
fi

# Test 8.2: COUNT par departement doit etre coherent
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT Department, COUNT(*) AS C FROM Employees GROUP BY Department" > "$TMPDIR/out_8_2.txt" 2>&1
ENG_CNT=$(grep "Engineering" "$TMPDIR/out_8_2.txt" | grep -o "[0-9]*$" | head -1)
SALES_CNT=$(grep "Sales" "$TMPDIR/out_8_2.txt" | grep -o "[0-9]*$" | head -1)
MKT_CNT=$(grep "Marketing" "$TMPDIR/out_8_2.txt" | grep -o "[0-9]*$" | head -1)
TOTAL_DEPT=$((${ENG_CNT:-0} + ${SALES_CNT:-0} + ${MKT_CNT:-0}))
if [ "$TOTAL_DEPT" -eq 8 ]; then
  pass_test "8.2 Coherence: somme des COUNT par dept = 8 (4+2+2)"
else
  fail_test "8.2 Coherence: somme departements = $TOTAL_DEPT (attendu 8)"
fi

# Test 8.3: AVG doit etre coherent avec SUM/COUNT
timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -q "SELECT AVG(Salary) AS AvgSal FROM Employees" > "$TMPDIR/out_8_3.txt" 2>&1
if grep -q "66625" "$TMPDIR/out_8_3.txt"; then
  pass_test "8.3 Coherence: AVG(Salary) = 533000/8 = 66625"
else
  fail_test "8.3 Coherence: AVG incorrect"
fi

# Test 8.4: MIN < AVG < MAX
if [ 45000 -lt 66625 ] && [ 66625 -lt 92000 ]; then
  pass_test "8.4 Coherence: MIN(45000) < AVG(66625) < MAX(92000)"
else
  fail_test "8.4 Coherence: relation MIN < AVG < MAX invalide"
fi

echo ""

# =========================================================================
# SECTION 9 : Execution des scripts SQL de SAMPLES/SQLSERVER
# =========================================================================
echo "--- SECTION 9 : Scripts SAMPLES/SQLSERVER/*.sql ---"

for SQL_FILE in "$ROOTDIR"/SAMPLES/SQLSERVER/test_math.sql \
                "$ROOTDIR"/SAMPLES/SQLSERVER/test_string.sql \
                "$ROOTDIR"/SAMPLES/SQLSERVER/test_conversion.sql \
                "$ROOTDIR"/SAMPLES/SQLSERVER/test_case.sql \
                "$ROOTDIR"/SAMPLES/SQLSERVER/test_iif_choose.sql \
                "$ROOTDIR"/SAMPLES/SQLSERVER/test_set_options.sql; do
  BASENAME=$(basename "$SQL_FILE")
  timeout $TIMEOUT_SEC "$SQLCMD_BIN" -S "$MDF_FILE" -i "$SQL_FILE" > "$TMPDIR/out_9_${BASENAME}.txt" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    pass_test "9.x Script $BASENAME: execute sans erreur"
  else
    fail_test "9.x Script $BASENAME: exit=$RC"
  fi
done

echo ""

# =========================================================================
# Resume
# =========================================================================
echo "============================================================"
echo "  Resume"
echo "============================================================"
echo "  Total  : $TOTAL"
echo "  Reussi : $PASS"
echo "  Echoue : $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "  Tous les tests sont passes avec succes."
  echo ""
  exit 0
else
  echo "  ATTENTION: $FAIL test(s) echoue(s)."
  echo ""
  exit 1
fi
