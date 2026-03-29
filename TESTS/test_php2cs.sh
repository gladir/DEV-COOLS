#!/bin/bash
# test_php2cs.sh - Teste que les fichiers .CS generes par PHP2CS compilent
#
# Usage: ./TESTS/test_php2cs.sh [--verbose]
#
# Prerequis: fpc (Free Pascal), dotnet (SDK .NET)

set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"
TRANSPILER="$ROOTDIR/PHP2CS"
SAMPLES="$ROOTDIR/SAMPLES/PHP2CS"
TMPDIR_BUILD="/tmp/php2cs_test_$$"
VERBOSE=0
TIMEOUT=15

if [ "$1" = "--verbose" ]; then
  VERBOSE=1
fi

# Verifier que le transpileur existe
if [ ! -f "$TRANSPILER" ]; then
  echo "ERREUR: PHP2CS non trouve. Compilez avec: fpc -Mtp PHP2CS.PAS"
  exit 1
fi

# Verifier que dotnet est disponible
if ! command -v dotnet &>/dev/null; then
  echo "ERREUR: dotnet SDK non trouve. Installez le SDK .NET."
  exit 1
fi

# Verifier que des fichiers PHP de test existent
if [ ! -d "$SAMPLES" ] || [ -z "$(ls "$SAMPLES"/test*.php 2>/dev/null)" ]; then
  echo "ERREUR: Aucun fichier test*.php dans $SAMPLES"
  exit 1
fi

# Creer le repertoire de build temporaire avec un projet console minimal
mkdir -p "$TMPDIR_BUILD"
cat > "$TMPDIR_BUILD/TestApp.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
CSPROJ

# Effectuer une restauration une seule fois
dotnet restore "$TMPDIR_BUILD/TestApp.csproj" --verbosity quiet 2>/dev/null

PASS=0
FAIL=0
TOTAL=0

for SRC in "$SAMPLES"/test*.php; do
  BASE=$(basename "$SRC" .php)
  CS_OUT="$TMPDIR_BUILD/${BASE}.cs"
  TOTAL=$((TOTAL + 1))

  # Etape 1 : Transpilation PHP -> C#
  TRANS_OUT=$(timeout "$TIMEOUT" "$TRANSPILER" "$SRC" "$CS_OUT" 2>&1) || RC=$?
  RC=${RC:-0}

  if [ "$RC" -eq 124 ]; then
    echo "ECHEC TRANSPILATION: $BASE - TIMEOUT (>${TIMEOUT}s)"
    FAIL=$((FAIL + 1))
    continue
  fi

  if [ ! -f "$CS_OUT" ]; then
    echo "ECHEC TRANSPILATION: $BASE - fichier .cs non genere"
    if [ $VERBOSE -eq 1 ]; then echo "  $TRANS_OUT"; fi
    FAIL=$((FAIL + 1))
    continue
  fi

  # Etape 2 : Compilation C# avec dotnet
  # Copier le fichier genere comme Program.cs du projet temporaire
  cp "$CS_OUT" "$TMPDIR_BUILD/Program.cs"

  BUILD_OUT=$(dotnet build "$TMPDIR_BUILD/TestApp.csproj" \
    --verbosity quiet --no-restore 2>&1) || BUILD_RC=$?
  BUILD_RC=${BUILD_RC:-0}

  if [ "$BUILD_RC" -ne 0 ]; then
    echo "ECHEC COMPILATION: $BASE"
    if [ $VERBOSE -eq 1 ]; then
      echo "$BUILD_OUT" | grep -E "(error|erreur)" | head -10
    fi
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then
      echo "OK: $BASE"
    fi
  fi
done

# Nettoyage
rm -rf "$TMPDIR_BUILD"

echo ""
echo "========================================="
echo "  RESULTATS PHP2CS: $PASS/$TOTAL passes"
if [ $FAIL -gt 0 ]; then
  echo "  $FAIL echec(s)"
fi
echo "========================================="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
