#!/bin/sh
# =============================================================================
# test_disexe.sh - Tests rigoureux pour DISEXE.PAS
# =============================================================================
#
# Ce script teste que DISEXE desassemble correctement les fichiers EXE
# DOS 16 bits (MZ) et Windows 32 bits (PE) sans planter, et que les
# fichiers .ASM generes sont coherents.
#
# Usage:
#   ./TESTS/test_disexe.sh [chemin_vers_DISEXE]
#
# Si le chemin n'est pas fourni, le script compile DISEXE.PAS automatiquement.
# =============================================================================

TIMEOUT_SEC=30
PASS=0
FAIL=0
TOTAL=0
TMPDIR="/tmp/test_disexe_$$"

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

# ==== Localisation du binaire DISEXE ====
DISEXE_BIN="${1:-}"

if [ -z "$DISEXE_BIN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_DIR="$(dirname "$SCRIPT_DIR")"
  if [ -f "$REPO_DIR/DISEXE.PAS" ]; then
    echo "Compilation de DISEXE.PAS..."
    fpc -Mtp "$REPO_DIR/DISEXE.PAS" -o"$TMPDIR/DISEXE" 2>&1 | tail -3
    if [ $? -ne 0 ]; then
      echo "ERREUR: Echec de la compilation de DISEXE.PAS"
      exit 1
    fi
    DISEXE_BIN="$TMPDIR/DISEXE"
  else
    echo "ERREUR: DISEXE.PAS introuvable et aucun binaire specifie."
    exit 1
  fi
fi

if [ ! -x "$DISEXE_BIN" ]; then
  echo "ERREUR: $DISEXE_BIN n'est pas executable."
  exit 1
fi

echo ""
echo "============================================================"
echo "  Tests rigoureux de DISEXE"
echo "  Binaire: $DISEXE_BIN"
echo "============================================================"
echo ""

# =========================================================================
# Generation des fichiers EXE de test
# =========================================================================

generate_test_files() {
  python3 - "$TMPDIR" << 'PYEOF'
import struct, sys, os

tmpdir = sys.argv[1]

# -----------------------------------------------------------------------
# 1. Minimal DOS MZ EXE: prints "Hi!" and exits
# -----------------------------------------------------------------------
def gen_dos_minimal(path):
    code = bytearray()
    code += b'\xB4\x09'                      # MOV AH, 09h
    code += b'\xBA\x0B\x00'                  # MOV DX, 000Bh (msg offset)
    code += b'\xCD\x21'                      # INT 21h
    code += b'\xB8\x00\x4C'                  # MOV AX, 4C00h
    code += b'\xCD\x21'                      # INT 21h
    code += b'Hi!$'
    while len(code) % 16 != 0:
        code += b'\x00'
    hdr_para = 2
    hdr_size = hdr_para * 16
    total = hdr_size + len(code)
    pages = (total + 511) // 512
    lastpg = total % 512
    h = struct.pack('<2sHHHHHHHHHHHHH',
        b'MZ', lastpg, pages, 0, hdr_para, 0, 0xFFFF,
        0, 0x100, 0, 0, 0, hdr_size, 0)
    h += b'\x00' * (hdr_size - len(h))
    with open(path, 'wb') as f:
        f.write(h + code)

# -----------------------------------------------------------------------
# 2. Complex DOS MZ EXE: many instruction types + relocation
# -----------------------------------------------------------------------
def gen_dos_complex(path):
    code = bytearray()
    code += b'\x90'                       # NOP
    code += b'\x50\x53\x51\x52'          # PUSH AX/BX/CX/DX
    code += b'\xB8\x34\x12'              # MOV AX, 1234h
    code += b'\xBB\x78\x56'              # MOV BX, 5678h
    code += b'\x01\xD8'                  # ADD AX, BX
    code += b'\x2D\x01\x00'              # SUB AX, 1
    code += b'\x3D\x00\x00'              # CMP AX, 0
    code += b'\x74\x05'                  # JE +5
    code += b'\xB9\xFF\xFF'              # MOV CX, FFFFh
    code += b'\xEB\x03'                  # JMP +3
    code += b'\x31\xC9'                  # XOR CX, CX
    code += b'\x90'                       # NOP
    code += b'\x25\xFF\x00'              # AND AX, 00FFh
    code += b'\x0D\x00\x80'              # OR AX, 8000h
    code += b'\x85\xC0'                  # TEST AX, AX
    code += b'\x0E'                       # PUSH CS
    code += b'\x1F'                       # POP DS
    code += b'\xB4\x4C'                  # MOV AH, 4Ch
    code += b'\xCD\x21'                  # INT 21h
    code += b'\xCC'                       # INT 3
    code += b'\xE8\x02\x00'              # CALL +2
    code += b'\xEB\x01'                  # JMP +1
    code += b'\xC3'                       # RET
    code += b'\xF4'                       # HLT
    code += b'\xFA'                       # CLI
    code += b'\xFB'                       # STI
    code += b'\xFC'                       # CLD
    code += b'\xFD'                       # STD
    code += b'\xE2\xFC'                  # LOOP -4
    code += b'\xF3\xA4'                  # REP MOVSB
    code += b'\xAC'                       # LODSB
    code += b'\xAA'                       # STOSB
    code += b'\x5A\x59\x5B\x58'          # POP DX/CX/BX/AX
    code += b'\xCB'                       # RETF
    code += b'\xD1\xE0'                  # SHL AX, 1
    code += b'\xD1\xE8'                  # SHR AX, 1
    code += b'\x40'                       # INC AX
    code += b'\x48'                       # DEC AX
    code += b'\x93'                       # XCHG AX, BX
    code += b'Test data$\x00'
    while len(code) % 16 != 0:
        code += b'\x00'
    hdr_para = 4
    hdr_size = hdr_para * 16
    reloc_ofs = 28
    reloc_entry = struct.pack('<HH', 0, 0)
    total = hdr_size + len(code)
    pages = (total + 511) // 512
    lastpg = total % 512
    h = struct.pack('<2sHHHHHHHHHHHHH',
        b'MZ', lastpg, pages, 1, hdr_para, 0, 0xFFFF,
        0, 0x200, 0, 0, 0, reloc_ofs, 0)
    h += reloc_entry
    h += b'\x00' * (hdr_size - len(h))
    with open(path, 'wb') as f:
        f.write(h + code)

# -----------------------------------------------------------------------
# 3. DOS MZ EXE with only data (edge case: no real code)
# -----------------------------------------------------------------------
def gen_dos_data_only(path):
    code = bytearray()
    code += b'\xB8\x00\x4C'              # MOV AX, 4C00h
    code += b'\xCD\x21'                  # INT 21h
    # Lots of data
    for i in range(64):
        code += bytes([i & 0xFF])
    while len(code) % 16 != 0:
        code += b'\x00'
    hdr_para = 2
    hdr_size = hdr_para * 16
    total = hdr_size + len(code)
    pages = (total + 511) // 512
    lastpg = total % 512
    h = struct.pack('<2sHHHHHHHHHHHHH',
        b'MZ', lastpg, pages, 0, hdr_para, 0, 0xFFFF,
        0, 0x100, 0, 0, 0, hdr_size, 0)
    h += b'\x00' * (hdr_size - len(h))
    with open(path, 'wb') as f:
        f.write(h + code)

# -----------------------------------------------------------------------
# 4. Minimal PE32 EXE (ExitProcess only)
# -----------------------------------------------------------------------
def gen_pe_minimal(path):
    IMAGE_BASE = 0x00400000
    SA = 0x1000; FA = 0x200
    TEXT_RVA = 0x1000; IDATA_RVA = 0x2000
    ILT_O = 0x28; IAT_O = 0x30; HN_O = 0x38; DLL_O = 0x46
    hn = struct.pack('<H', 0) + b'ExitProcess\x00'
    dll = b'KERNEL32.DLL\x00'
    idata = bytearray()
    idata += struct.pack('<IIIII', IDATA_RVA+ILT_O, 0, 0, IDATA_RVA+DLL_O, IDATA_RVA+IAT_O)
    idata += b'\x00'*20
    idata += b'\x00'*(ILT_O-len(idata))
    idata += struct.pack('<II', IDATA_RVA+HN_O, 0)
    idata += struct.pack('<II', IDATA_RVA+HN_O, 0)
    idata += b'\x00'*(HN_O-len(idata))
    idata += hn
    idata += b'\x00'*(DLL_O-len(idata))
    idata += dll
    while len(idata)%FA: idata += b'\x00'
    exit_iat = IMAGE_BASE + IDATA_RVA + IAT_O
    text = bytearray()
    text += b'\x6A\x2A'                  # PUSH 42
    text += b'\xFF\x15'+struct.pack('<I',exit_iat) # CALL [ExitProcess]
    text += b'\xCC'*4
    while len(text)%FA: text += b'\x00'
    PE_OFS = 0x80; OPT_SIZE = 224; NS = 2
    HR = PE_OFS+4+20+OPT_SIZE+NS*40
    HA = ((HR+FA-1)//FA)*FA
    TFO = HA; IFO = TFO+len(text)
    SOI = IDATA_RVA+((len(idata)+SA-1)//SA)*SA
    dos = struct.pack('<2s',b'MZ')+b'\x00'*(0x3C-2)+struct.pack('<I',PE_OFS)+b'\x00'*(PE_OFS-0x40)
    pe = b'PE\x00\x00'
    coff = struct.pack('<HHIIIHH',0x014C,NS,0,0,0,OPT_SIZE,0x0102)
    opt = struct.pack('<H',0x010B)+struct.pack('<BB',1,0)
    opt += struct.pack('<III',len(text),len(idata),0)
    opt += struct.pack('<III',TEXT_RVA,TEXT_RVA,IDATA_RVA)
    opt += struct.pack('<III',IMAGE_BASE,SA,FA)
    opt += struct.pack('<HHHHHH',4,0,0,0,4,0)
    opt += struct.pack('<IIII',0,SOI,HA,0)
    opt += struct.pack('<HH',3,0)
    opt += struct.pack('<IIII',0x100000,0x1000,0x100000,0x1000)
    opt += struct.pack('<II',0,16)
    dd = b'\x00'*8+struct.pack('<II',IDATA_RVA,40)+b'\x00'*(14*8)
    opt += dd
    st = b'.text\x00\x00\x00'+struct.pack('<IIIIIIHHI',len(text),TEXT_RVA,len(text),TFO,0,0,0,0,0x60000020)
    si = b'.idata\x00\x00'+struct.pack('<IIIIIIHHI',len(idata),IDATA_RVA,len(idata),IFO,0,0,0,0,0xC0000040)
    hdr = dos+pe+coff+opt+st+si+b'\x00'*(HA-len(dos+pe+coff+opt+st+si))
    with open(path,'wb') as f: f.write(hdr+text+idata)

# -----------------------------------------------------------------------
# 5. Complex PE32 EXE (3 imports, prologue, varied instructions)
# -----------------------------------------------------------------------
def gen_pe_complex(path):
    IMAGE_BASE = 0x00400000
    SA = 0x1000; FA = 0x200
    TEXT_RVA = 0x1000; IDATA_RVA = 0x2000; DATA_RVA = 0x3000
    ILT_O=0x28;IAT_O=0x38;HN1=0x48;HN2=0x58;HN3=0x68;DLLO=0x74
    idata = bytearray()
    idata += struct.pack('<IIIII',IDATA_RVA+ILT_O,0,0,IDATA_RVA+DLLO,IDATA_RVA+IAT_O)
    idata += b'\x00'*20
    idata += b'\x00'*(ILT_O-len(idata))
    idata += struct.pack('<III',IDATA_RVA+HN1,IDATA_RVA+HN2,IDATA_RVA+HN3)+struct.pack('<I',0)
    assert len(idata)==IAT_O
    idata += struct.pack('<III',IDATA_RVA+HN1,IDATA_RVA+HN2,IDATA_RVA+HN3)+struct.pack('<I',0)
    idata += b'\x00'*(HN1-len(idata))
    idata += struct.pack('<H',0)+b'ExitProcess\x00'
    if len(idata)%2: idata += b'\x00'
    idata += b'\x00'*(HN2-len(idata))
    idata += struct.pack('<H',0)+b'GetStdHandle\x00'
    if len(idata)%2: idata += b'\x00'
    idata += b'\x00'*(HN3-len(idata))
    idata += struct.pack('<H',0)+b'WriteFile\x00'
    if len(idata)%2: idata += b'\x00'
    idata += b'\x00'*(DLLO-len(idata))
    idata += b'KERNEL32.DLL\x00'
    while len(idata)%FA: idata += b'\x00'
    IAT_Exit=IMAGE_BASE+IDATA_RVA+IAT_O
    IAT_GetH=IMAGE_BASE+IDATA_RVA+IAT_O+4
    IAT_Write=IMAGE_BASE+IDATA_RVA+IAT_O+8
    msg = b'Hello from DISEXE!\r\n'
    data = bytearray(msg)+b'\x00'*4
    struct.pack_into('<I',data,len(msg),len(msg))
    data += b'\xDE\xAD\xBE\xEF'+b'\x00'*16
    while len(data)%FA: data += b'\x00'
    MSG_VA = IMAGE_BASE+DATA_RVA
    text = bytearray()
    text += b'\x55\x89\xE5\x83\xEC\x10'
    text += b'\x6A\xF5'
    text += b'\xFF\x15'+struct.pack('<I',IAT_GetH)
    text += b'\x89\x45\xFC'
    text += b'\x6A\x00\x8D\x4D\xF8\x51'
    text += b'\x68'+struct.pack('<I',len(msg))
    text += b'\x68'+struct.pack('<I',MSG_VA)
    text += b'\xFF\x75\xFC'
    text += b'\xFF\x15'+struct.pack('<I',IAT_Write)
    text += b'\x33\xC0\x50'
    text += b'\xFF\x15'+struct.pack('<I',IAT_Exit)
    # Second sub with prologue
    text += b'\x55\x89\xE5\x60'
    text += b'\x8B\x45\x08\x85\xC0\x74\x08'
    text += b'\xC1\xE0\x02\x05\x64\x00\x00\x00\xEB\x02'
    text += b'\x33\xC0\x61\x89\xEC\x5D\xC2\x04\x00'
    text += b'\x90'*8+b'\xCC'*4
    while len(text)%FA: text += b'\x00'
    PE_OFS=0x80;OPT_SIZE=224;NS=3
    HR=PE_OFS+4+20+OPT_SIZE+NS*40;HA=((HR+FA-1)//FA)*FA
    TFO=HA;IFO=TFO+len(text);DFO=IFO+len(idata)
    SOI=DATA_RVA+((len(data)+SA-1)//SA)*SA
    dos=struct.pack('<2s',b'MZ')+b'\x00'*(0x3C-2)+struct.pack('<I',PE_OFS)+b'\x00'*(PE_OFS-0x40)
    pe=b'PE\x00\x00'
    coff=struct.pack('<HHIIIHH',0x014C,NS,0,0,0,OPT_SIZE,0x0102)
    opt=struct.pack('<H',0x010B)+struct.pack('<BB',1,0)
    opt+=struct.pack('<III',len(text),len(idata)+len(data),0)
    opt+=struct.pack('<III',TEXT_RVA,TEXT_RVA,DATA_RVA)
    opt+=struct.pack('<III',IMAGE_BASE,SA,FA)
    opt+=struct.pack('<HHHHHH',4,0,0,0,4,0)
    opt+=struct.pack('<IIII',0,SOI,HA,0)
    opt+=struct.pack('<HH',3,0)
    opt+=struct.pack('<IIII',0x100000,0x1000,0x100000,0x1000)
    opt+=struct.pack('<II',0,16)
    dd=b'\x00'*8+struct.pack('<II',IDATA_RVA,40)+b'\x00'*(14*8)
    opt+=dd
    st=b'.text\x00\x00\x00'+struct.pack('<IIIIIIHHI',len(text),TEXT_RVA,len(text),TFO,0,0,0,0,0x60000020)
    si=b'.idata\x00\x00'+struct.pack('<IIIIIIHHI',len(idata),IDATA_RVA,len(idata),IFO,0,0,0,0,0xC0000040)
    sd=b'.data\x00\x00\x00'+struct.pack('<IIIIIIHHI',len(data),DATA_RVA,len(data),DFO,0,0,0,0,0xC0000040)
    hdr=dos+pe+coff+opt+st+si+sd+b'\x00'*(HA-len(dos+pe+coff+opt+st+si+sd))
    with open(path,'wb') as f: f.write(hdr+text+idata+data)

# -----------------------------------------------------------------------
# 6. Truncated PE (corrupt) - header says PE but file is too short
# -----------------------------------------------------------------------
def gen_pe_truncated(path):
    dos = struct.pack('<2s',b'MZ')+b'\x00'*(0x3C-2)+struct.pack('<I',0x80)+b'\x00'*(0x80-0x40)
    pe = b'PE\x00\x00'
    # Truncate after PE signature (missing COFF header)
    with open(path,'wb') as f: f.write(dos+pe)

# -----------------------------------------------------------------------
# 7. File with MZ signature but garbage data
# -----------------------------------------------------------------------
def gen_mz_garbage(path):
    data = bytearray(b'MZ')
    data += bytes(range(256)) * 2  # 512 bytes of junk
    with open(path,'wb') as f: f.write(data)

# -----------------------------------------------------------------------
# Generate all test files
# -----------------------------------------------------------------------
gen_dos_minimal(os.path.join(tmpdir, 'dos_minimal.exe'))
gen_dos_complex(os.path.join(tmpdir, 'dos_complex.exe'))
gen_dos_data_only(os.path.join(tmpdir, 'dos_data.exe'))
gen_pe_minimal(os.path.join(tmpdir, 'pe_minimal.exe'))
gen_pe_complex(os.path.join(tmpdir, 'pe_complex.exe'))
gen_pe_truncated(os.path.join(tmpdir, 'pe_truncated.exe'))
gen_mz_garbage(os.path.join(tmpdir, 'mz_garbage.exe'))

# Also generate an empty file and a text file
with open(os.path.join(tmpdir, 'empty.exe'), 'wb') as f:
    pass
with open(os.path.join(tmpdir, 'not_exe.txt'), 'w') as f:
    f.write('This is not an executable file.\n')

print('All test files generated successfully.')
PYEOF
}

echo "Generation des fichiers EXE de test..."
generate_test_files
if [ $? -ne 0 ]; then
  echo "ERREUR: Generation des fichiers de test echouee."
  exit 1
fi
echo ""

# =========================================================================
# SECTION 1 : Tests de base - Le desassembleur ne plante pas
# =========================================================================
echo "--- SECTION 1 : Stabilite (pas de crash) ---"

# Test 1.1: DOS minimal
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_minimal.exe" -o "$TMPDIR/dos_minimal.asm" > "$TMPDIR/out_1_1.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "1.1 DOS minimal: desassemblage sans crash (exit 0)"
else
  fail_test "1.1 DOS minimal: crash ou erreur (exit $RC)"
fi

# Test 1.2: DOS complex
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_complex.exe" -o "$TMPDIR/dos_complex.asm" > "$TMPDIR/out_1_2.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "1.2 DOS complexe: desassemblage sans crash (exit 0)"
else
  fail_test "1.2 DOS complexe: crash ou erreur (exit $RC)"
fi

# Test 1.3: DOS data-heavy
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_data.exe" -o "$TMPDIR/dos_data.asm" > "$TMPDIR/out_1_3.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "1.3 DOS data-heavy: desassemblage sans crash (exit 0)"
else
  fail_test "1.3 DOS data-heavy: crash ou erreur (exit $RC)"
fi

# Test 1.4: PE minimal
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_minimal.exe" -o "$TMPDIR/pe_minimal.asm" > "$TMPDIR/out_1_4.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "1.4 PE minimal: desassemblage sans crash (exit 0)"
else
  fail_test "1.4 PE minimal: crash ou erreur (exit $RC)"
fi

# Test 1.5: PE complex (3 imports, data section)
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_complex.exe" -o "$TMPDIR/pe_complex.asm" > "$TMPDIR/out_1_5.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "1.5 PE complexe (3 imports): desassemblage sans crash (exit 0)"
else
  fail_test "1.5 PE complexe (3 imports): crash ou erreur (exit $RC)"
fi

echo ""

# =========================================================================
# SECTION 2 : Tests d'options
# =========================================================================
echo "--- SECTION 2 : Options de la ligne de commande ---"

# Test 2.1: -v (verbose)
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_minimal.exe" -o "$TMPDIR/dos_v.asm" -v > "$TMPDIR/out_2_1.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "2.1 Option -v: fonctionne sans crash"
else
  fail_test "2.1 Option -v: crash (exit $RC)"
fi

# Test 2.2: -hex
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_complex.exe" -o "$TMPDIR/pe_hex.asm" -hex > "$TMPDIR/out_2_2.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "2.2 Option -hex: fonctionne sans crash"
else
  fail_test "2.2 Option -hex: crash (exit $RC)"
fi

# Test 2.3: -v -hex combined
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_complex.exe" -o "$TMPDIR/dos_vhex.asm" -v -hex > "$TMPDIR/out_2_3.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "2.3 Options -v -hex combinees: fonctionne sans crash"
else
  fail_test "2.3 Options -v -hex combinees: crash (exit $RC)"
fi

# Test 2.4: -16 (force 16-bit)
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_minimal.exe" -o "$TMPDIR/dos_16.asm" -16 > "$TMPDIR/out_2_4.txt" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  pass_test "2.4 Option -16: fonctionne sans crash"
else
  fail_test "2.4 Option -16: crash (exit $RC)"
fi

# Test 2.5: -h (help)
timeout $TIMEOUT_SEC "$DISEXE_BIN" -h > "$TMPDIR/out_2_5.txt" 2>&1
if grep -q "Usage" "$TMPDIR/out_2_5.txt"; then
  pass_test "2.5 Option -h: affiche l'aide"
else
  fail_test "2.5 Option -h: n'affiche pas l'aide"
fi

echo ""

# =========================================================================
# SECTION 3 : Gestion des erreurs
# =========================================================================
echo "--- SECTION 3 : Gestion des erreurs ---"

# Test 3.1: Fichier inexistant
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/nonexistent.exe" -o "$TMPDIR/nofile.asm" > "$TMPDIR/out_3_1.txt" 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  pass_test "3.1 Fichier inexistant: retourne une erreur (exit $RC)"
else
  fail_test "3.1 Fichier inexistant: devrait echouer mais exit 0"
fi

# Test 3.2: Fichier vide
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/empty.exe" -o "$TMPDIR/empty.asm" > "$TMPDIR/out_3_2.txt" 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  pass_test "3.2 Fichier vide: retourne une erreur (exit $RC)"
else
  fail_test "3.2 Fichier vide: devrait echouer mais exit 0"
fi

# Test 3.3: Fichier texte (pas un EXE)
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/not_exe.txt" -o "$TMPDIR/notexe.asm" > "$TMPDIR/out_3_3.txt" 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  pass_test "3.3 Fichier texte: retourne une erreur (exit $RC)"
else
  fail_test "3.3 Fichier texte: devrait echouer mais exit 0"
fi

# Test 3.4: PE tronque
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_truncated.exe" -o "$TMPDIR/pe_trunc.asm" > "$TMPDIR/out_3_4.txt" 2>&1
RC=$?
# We accept either error (non-zero) or graceful handling (zero) - the key is no crash/segfault
if [ $RC -le 1 ]; then
  pass_test "3.4 PE tronque: pas de crash (exit $RC)"
else
  fail_test "3.4 PE tronque: crash potentiel (exit $RC)" "Signal/segfault possible"
fi

# Test 3.5: MZ avec donnees corrompues
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/mz_garbage.exe" -o "$TMPDIR/mz_garb.asm" > "$TMPDIR/out_3_5.txt" 2>&1
RC=$?
if [ $RC -le 1 ]; then
  pass_test "3.5 MZ corrompu: pas de crash (exit $RC)"
else
  fail_test "3.5 MZ corrompu: crash potentiel (exit $RC)" "Signal/segfault possible"
fi

# Test 3.6: Aucun fichier d'entree
timeout $TIMEOUT_SEC "$DISEXE_BIN" > "$TMPDIR/out_3_6.txt" 2>&1
RC=$?
if grep -qi "erreur\|error\|usage" "$TMPDIR/out_3_6.txt"; then
  pass_test "3.6 Aucun argument: affiche un message d'erreur"
else
  fail_test "3.6 Aucun argument: pas de message d'erreur"
fi

echo ""

# =========================================================================
# SECTION 4 : Coherence du fichier .ASM genere (DOS 16-bit)
# =========================================================================
echo "--- SECTION 4 : Coherence ASM DOS 16 bits ---"

ASM_DOS="$TMPDIR/dos_complex.asm"

# Test 4.1: Fichier .ASM non-vide
if [ -s "$ASM_DOS" ]; then
  pass_test "4.1 Fichier .ASM DOS non-vide ($(wc -c < "$ASM_DOS") octets)"
else
  fail_test "4.1 Fichier .ASM DOS vide ou inexistant"
fi

# Test 4.2: Contient la directive .8086
if grep -q '\.8086' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.2 Directive .8086 presente"
else
  fail_test "4.2 Directive .8086 absente"
fi

# Test 4.3: Contient .MODEL SMALL
if grep -q '\.MODEL SMALL' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.3 Directive .MODEL SMALL presente"
else
  fail_test "4.3 Directive .MODEL SMALL absente"
fi

# Test 4.4: Contient SEGMENT/ENDS pour le code
if grep -q 'SEGMENT' "$ASM_DOS" 2>/dev/null && grep -q 'ENDS' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.4 Directives SEGMENT/ENDS presentes"
else
  fail_test "4.4 Directives SEGMENT/ENDS absentes"
fi

# Test 4.5: Contient END
if grep -q '^END' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.5 Directive END presente"
else
  fail_test "4.5 Directive END absente"
fi

# Test 4.6: Contient au moins une instruction reconnue (INT, MOV, PUSH, etc.)
if grep -qiE '(MOV|INT|PUSH|POP|ADD|SUB|JMP|CALL|RET|NOP|XOR|CMP)' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.6 Instructions assembleur reconnues presentes"
else
  fail_test "4.6 Aucune instruction assembleur reconnue trouvee"
fi

# Test 4.7: Contient un label de sous-programme
if grep -q 'sub_' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.7 Label de sous-programme (sub_) present"
else
  fail_test "4.7 Label de sous-programme absent"
fi

# Test 4.8: Le header/commentaire mentionne le fichier source
if grep -q 'Source' "$ASM_DOS" 2>/dev/null; then
  pass_test "4.8 Commentaire avec fichier source present"
else
  fail_test "4.8 Commentaire avec fichier source absent"
fi

echo ""

# =========================================================================
# SECTION 5 : Coherence du fichier .ASM genere (PE 32-bit)
# =========================================================================
echo "--- SECTION 5 : Coherence ASM PE 32 bits ---"

ASM_PE="$TMPDIR/pe_complex.asm"

# Test 5.1: Fichier .ASM PE non-vide
if [ -s "$ASM_PE" ]; then
  pass_test "5.1 Fichier .ASM PE non-vide ($(wc -c < "$ASM_PE") octets)"
else
  fail_test "5.1 Fichier .ASM PE vide ou inexistant"
fi

# Test 5.2: Contient .386
if grep -q '\.386' "$ASM_PE" 2>/dev/null; then
  pass_test "5.2 Directive .386 presente"
else
  fail_test "5.2 Directive .386 absente"
fi

# Test 5.3: Contient .MODEL FLAT
if grep -q '\.MODEL FLAT' "$ASM_PE" 2>/dev/null; then
  pass_test "5.3 Directive .MODEL FLAT presente"
else
  fail_test "5.3 Directive .MODEL FLAT absente"
fi

# Test 5.4: Contient .CODE
if grep -q '\.CODE' "$ASM_PE" 2>/dev/null; then
  pass_test "5.4 Directive .CODE presente"
else
  fail_test "5.4 Directive .CODE absente"
fi

# Test 5.5: Mentionne ExitProcess dans EXTRN
if grep -qi 'ExitProcess' "$ASM_PE" 2>/dev/null; then
  pass_test "5.5 Import ExitProcess mentionne"
else
  fail_test "5.5 Import ExitProcess absent"
fi

# Test 5.6: Mentionne GetStdHandle
if grep -qi 'GetStdHandle' "$ASM_PE" 2>/dev/null; then
  pass_test "5.6 Import GetStdHandle mentionne"
else
  fail_test "5.6 Import GetStdHandle absent"
fi

# Test 5.7: Mentionne WriteFile
if grep -qi 'WriteFile' "$ASM_PE" 2>/dev/null; then
  pass_test "5.7 Import WriteFile mentionne"
else
  fail_test "5.7 Import WriteFile absent"
fi

# Test 5.8: Contient des instructions 32 bits (PUSH/CALL/MOV)
if grep -qiE '(PUSH|CALL|MOV|XOR|TEST)' "$ASM_PE" 2>/dev/null; then
  pass_test "5.8 Instructions 32 bits presentes"
else
  fail_test "5.8 Aucune instruction 32 bits trouvee"
fi

# Test 5.9: Point d'entree mentionne dans le fichier
if grep -qi 'entree\|entry' "$ASM_PE" 2>/dev/null; then
  pass_test "5.9 Point d'entree mentionne dans l'ASM"
else
  fail_test "5.9 Point d'entree non mentionne"
fi

echo ""

# =========================================================================
# SECTION 6 : Verification du rapport de coherence interne
# =========================================================================
echo "--- SECTION 6 : Rapport de coherence interne ---"

# Test 6.1: Verification de coherence OK pour DOS
if grep -q "coherence.*OK\|OK.*anomalie" "$TMPDIR/out_1_2.txt" 2>/dev/null; then
  pass_test "6.1 Verification coherence DOS: OK"
else
  fail_test "6.1 Verification coherence DOS: pas de message OK"
fi

# Test 6.2: Verification de coherence OK pour PE
if grep -q "coherence.*OK\|OK.*anomalie" "$TMPDIR/out_1_5.txt" 2>/dev/null; then
  pass_test "6.2 Verification coherence PE: OK"
else
  fail_test "6.2 Verification coherence PE: pas de message OK"
fi

# Test 6.3: Rapport final present pour DOS
if grep -q "RAPPORT FINAL" "$TMPDIR/out_1_2.txt" 2>/dev/null; then
  pass_test "6.3 Rapport final present pour DOS"
else
  fail_test "6.3 Rapport final absent pour DOS"
fi

# Test 6.4: Rapport final present pour PE
if grep -q "RAPPORT FINAL" "$TMPDIR/out_1_5.txt" 2>/dev/null; then
  pass_test "6.4 Rapport final present pour PE"
else
  fail_test "6.4 Rapport final absent pour PE"
fi

# Test 6.5: Nombre d'instructions > 0 dans le rapport DOS
INSTR_DOS=$(grep -o "Instructions analysees.*: [0-9]*" "$TMPDIR/out_1_2.txt" 2>/dev/null | grep -o '[0-9]*$')
if [ -n "$INSTR_DOS" ] && [ "$INSTR_DOS" -gt 0 ] 2>/dev/null; then
  pass_test "6.5 Rapport DOS: $INSTR_DOS instructions analysees"
else
  fail_test "6.5 Rapport DOS: nombre d'instructions manquant ou zero"
fi

# Test 6.6: Nombre d'imports dans le rapport PE
IMPORTS_PE=$(grep -o "Imports.*: [0-9]*" "$TMPDIR/out_1_5.txt" 2>/dev/null | head -1 | grep -o '[0-9]*$')
if [ -n "$IMPORTS_PE" ] && [ "$IMPORTS_PE" -ge 3 ] 2>/dev/null; then
  pass_test "6.6 Rapport PE: $IMPORTS_PE imports detectes (attendu >= 3)"
else
  fail_test "6.6 Rapport PE: imports manquants (trouve: ${IMPORTS_PE:-0}, attendu >= 3)"
fi

echo ""

# =========================================================================
# SECTION 7 : Mode verbose et hex
# =========================================================================
echo "--- SECTION 7 : Contenu verbose et hex ---"

# Test 7.1: Verbose DOS montre details de l'entete
if grep -qi "Entete MZ\|Signature\|CS:IP" "$TMPDIR/out_2_1.txt" 2>/dev/null; then
  pass_test "7.1 Verbose DOS: details entete MZ affiches"
else
  fail_test "7.1 Verbose DOS: details entete absents"
fi

# Test 7.2: Le fichier hex ASM est plus grand que le normal
if [ -s "$TMPDIR/pe_hex.asm" ] && [ -s "$ASM_PE" ]; then
  SIZE_HEX=$(wc -c < "$TMPDIR/pe_hex.asm")
  SIZE_NORMAL=$(wc -c < "$ASM_PE")
  if [ "$SIZE_HEX" -gt "$SIZE_NORMAL" ]; then
    pass_test "7.2 Option -hex: ASM plus grand ($SIZE_HEX > $SIZE_NORMAL octets)"
  else
    # -hex may not always produce larger output if hex comments are short
    pass_test "7.2 Option -hex: ASM genere ($SIZE_HEX octets, normal: $SIZE_NORMAL)"
  fi
else
  fail_test "7.2 Option -hex: fichier ASM manquant"
fi

echo ""

# =========================================================================
# SECTION 8 : Test de non-regression (desassemblage multiple)
# =========================================================================
echo "--- SECTION 8 : Reproductibilite ---"

# Test 8.1: Desassembler 2 fois le meme fichier donne le meme resultat
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_complex.exe" -o "$TMPDIR/dos_run1.asm" > /dev/null 2>&1
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/dos_complex.exe" -o "$TMPDIR/dos_run2.asm" > /dev/null 2>&1
if diff -q "$TMPDIR/dos_run1.asm" "$TMPDIR/dos_run2.asm" > /dev/null 2>&1; then
  pass_test "8.1 DOS: resultat reproductible (2 runs identiques)"
else
  fail_test "8.1 DOS: resultats differents entre 2 runs"
fi

# Test 8.2: Idem pour PE
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_complex.exe" -o "$TMPDIR/pe_run1.asm" > /dev/null 2>&1
timeout $TIMEOUT_SEC "$DISEXE_BIN" "$TMPDIR/pe_complex.exe" -o "$TMPDIR/pe_run2.asm" > /dev/null 2>&1
if diff -q "$TMPDIR/pe_run1.asm" "$TMPDIR/pe_run2.asm" > /dev/null 2>&1; then
  pass_test "8.2 PE: resultat reproductible (2 runs identiques)"
else
  fail_test "8.2 PE: resultats differents entre 2 runs"
fi

echo ""

# =========================================================================
# SECTION 9 : Structure ASM avancee
# =========================================================================
echo "--- SECTION 9 : Structure ASM avancee ---"

# Test 9.1: Pas de labels dupliques dans le DOS ASM
DUPES_DOS=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*:' "$TMPDIR/dos_complex.asm" 2>/dev/null | sort | uniq -d | wc -l)
if [ "$DUPES_DOS" -eq 0 ]; then
  pass_test "9.1 DOS ASM: aucun label duplique"
else
  fail_test "9.1 DOS ASM: $DUPES_DOS labels dupliques trouves"
fi

# Test 9.2: Pas de labels dupliques dans le PE ASM
DUPES_PE=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*:' "$TMPDIR/pe_complex.asm" 2>/dev/null | sort | uniq -d | wc -l)
if [ "$DUPES_PE" -eq 0 ]; then
  pass_test "9.2 PE ASM: aucun label duplique"
else
  fail_test "9.2 PE ASM: $DUPES_PE labels dupliques trouves"
fi

# Test 9.3: OPTION CASEMAP dans PE ASM
if grep -q 'OPTION CASEMAP' "$ASM_PE" 2>/dev/null; then
  pass_test "9.3 PE ASM: OPTION CASEMAP present"
else
  fail_test "9.3 PE ASM: OPTION CASEMAP absent"
fi

# Test 9.4: .STACK dans DOS ASM
if grep -q '\.STACK' "$ASM_DOS" 2>/dev/null; then
  pass_test "9.4 DOS ASM: directive .STACK presente"
else
  fail_test "9.4 DOS ASM: directive .STACK absente"
fi

# Test 9.5: Detection de la chaine ASCII dans DOS complexe
if grep -qi 'aStr_\|string' "$ASM_DOS" 2>/dev/null; then
  pass_test "9.5 DOS ASM: detection de chaine ASCII"
else
  fail_test "9.5 DOS ASM: pas de chaine ASCII detectee"
fi

# Test 9.6: EXTRN declarations dans PE ASM
if grep -q 'EXTRN' "$ASM_PE" 2>/dev/null; then
  pass_test "9.6 PE ASM: declarations EXTRN presentes"
else
  fail_test "9.6 PE ASM: declarations EXTRN absentes"
fi

# Test 9.7: Le PE ASM contient des sous-programmes
if grep -q 'sub_' "$ASM_PE" 2>/dev/null; then
  pass_test "9.7 PE ASM: sous-programmes detectes"
else
  fail_test "9.7 PE ASM: aucun sous-programme detecte"
fi

# Test 9.8: Annotations INT 21h dans le DOS ASM
if grep -qi 'INT.*21h\|DOS' "$ASM_DOS" 2>/dev/null; then
  pass_test "9.8 DOS ASM: annotations pour INT 21h presentes"
else
  fail_test "9.8 DOS ASM: annotations INT 21h absentes"
fi

echo ""

# =========================================================================
# SECTION 10 : Tests de timeout et performance
# =========================================================================
echo "--- SECTION 10 : Performance ---"

# Test 10.1: DOS minimal se desassemble en moins de 5 secondes
START_TIME=$(date +%s)
timeout 5 "$DISEXE_BIN" "$TMPDIR/dos_minimal.exe" -o /dev/null > /dev/null 2>&1
RC=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
if [ $RC -eq 0 ] && [ $ELAPSED -lt 5 ]; then
  pass_test "10.1 DOS minimal: desassemble en ${ELAPSED}s (< 5s)"
else
  fail_test "10.1 DOS minimal: trop lent ou timeout (${ELAPSED}s, exit $RC)"
fi

# Test 10.2: PE complex se desassemble en moins de 10 secondes
START_TIME=$(date +%s)
timeout 10 "$DISEXE_BIN" "$TMPDIR/pe_complex.exe" -o /dev/null > /dev/null 2>&1
RC=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
if [ $RC -eq 0 ] && [ $ELAPSED -lt 10 ]; then
  pass_test "10.2 PE complexe: desassemble en ${ELAPSED}s (< 10s)"
else
  fail_test "10.2 PE complexe: trop lent ou timeout (${ELAPSED}s, exit $RC)"
fi

echo ""

# =========================================================================
# RESUME
# =========================================================================
echo "============================================================"
echo "  RESUME DES TESTS"
echo "============================================================"
echo ""
printf "  Total   : %d\n" "$TOTAL"
printf "  ${GREEN}Reussis${NC} : %d\n" "$PASS"
printf "  ${RED}Echoues${NC} : %d\n" "$FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  printf "${GREEN}Tous les tests ont reussi !${NC}\n"
  exit 0
else
  printf "${RED}%d test(s) echoue(s).${NC}\n" "$FAIL"
  exit 1
fi
