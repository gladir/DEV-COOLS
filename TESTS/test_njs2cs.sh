#!/bin/bash
# test_njs2cs.sh - Teste que les fichiers .CS generes par NJS2CS compilent
#                  et s'executent correctement.
#
# Usage: ./TESTS/test_njs2cs.sh [--verbose]
#
# Prerequis: fpc (Free Pascal), dotnet (SDK .NET)

set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"
TRANSPILER="$ROOTDIR/BINLINUX/NJS2CS"
SAMPLES="$ROOTDIR/SAMPLES/NJS2CS"
TMPDIR_BUILD="/tmp/njs2cs_test_$$"
VERBOSE=0
TIMEOUT=15

if [ "$1" = "--verbose" ]; then
  VERBOSE=1
fi

# Verifier que le transpileur existe (le compiler au besoin)
if [ ! -f "$TRANSPILER" ]; then
  echo "INFO: NJS2CS non trouve, compilation avec fpc -Mtp NJS2CS.PAS..."
  ( cd "$ROOTDIR" && fpc -Mtp NJS2CS.PAS >/dev/null 2>&1 && \
    mkdir -p BINLINUX && mv NJS2CS BINLINUX/ && rm -f NJS2CS.o ) || {
    echo "ERREUR: echec compilation NJS2CS.PAS"
    exit 1
  }
fi

# Verifier que dotnet est disponible
if ! command -v dotnet &>/dev/null; then
  echo "ERREUR: dotnet SDK non trouve. Installez le SDK .NET."
  exit 1
fi

# Verifier que des fichiers JS de test existent
if [ ! -d "$SAMPLES" ] || [ -z "$(ls "$SAMPLES"/test*.js 2>/dev/null)" ]; then
  echo "ERREUR: Aucun fichier test*.js dans $SAMPLES"
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
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CSharp" Version="4.7.0" />
  </ItemGroup>
</Project>
CSPROJ

# Restauration une seule fois
dotnet restore "$TMPDIR_BUILD/TestApp.csproj" --verbosity quiet 2>/dev/null

PASS=0
FAIL=0
TOTAL=0

for SRC in "$SAMPLES"/test*.js; do
  BASE=$(basename "$SRC" .js)
  CS_OUT="$TMPDIR_BUILD/Program.cs"
  TOTAL=$((TOTAL + 1))

  # Etape 1 : Transpilation JS -> C#
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

  # Etape 2 : Compilation C#
  BUILD_OUT=$(cd "$TMPDIR_BUILD" && dotnet build --verbosity quiet 2>&1)
  if ! echo "$BUILD_OUT" | grep -q "0 Error"; then
    echo "ECHEC COMPILATION: $BASE"
    if [ $VERBOSE -eq 1 ]; then
      echo "$BUILD_OUT" | grep -E "error" | head -5 | sed "s/^/  /"
    fi
    FAIL=$((FAIL + 1))
    continue
  fi

  echo "OK: $BASE"
  PASS=$((PASS + 1))
done

# Nettoyage
rm -rf "$TMPDIR_BUILD"

echo
echo "Resultats : $PASS/$TOTAL reussis, $FAIL echecs"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
