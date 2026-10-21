#!/bin/bash
# chkpe.sh [AL68CW32] : verifie les ecrivains PE et COFF sur
# work/exec.a68, un programme sans runtime dont les WHILE ne se terminent
# que si les resultats sont corrects (procedures, operateurs, structures,
# unions, REAL).
#   - .EXE par defaut seul, -obj seul, -asm en plus ;
#   - objdump -p / -h / -t / -r (si objdump est present) ;
#   - RUNNER=chargeur (TESTS/AL60CW32/runpe.c compile) : l'.EXE et le .OBJ
#     lie avec lld-link doivent se terminer avec le code 0 (un resultat
#     faux donnerait une boucle sans fin, arretee par timeout).
here=$(cd "$(dirname "$0")" && pwd)
comp=${1:-$here/../../BINLINUX/AL68CW32}
tmp=$(mktemp -d)
cp "$here/work/exec.a68" "$tmp/exec.a68"
cd "$tmp" || exit 1
bad=0
ko() { echo "ECHEC: $1"; bad=1; }
"$comp" exec.a68 >log 2>&1 || ko "compilation .exe"
[ -f exec.exe ] && [ ! -e exec.obj ] && [ ! -e exec.asm ] || ko ".exe seul par defaut"
rm -f exec.exe
"$comp" -obj exec.a68 >log 2>&1 || ko "compilation -obj"
[ -f exec.obj ] && [ ! -e exec.exe ] || ko "-obj ne produit que le .obj"
"$comp" -asm exec.a68 >log 2>&1
[ -f exec.exe ] && [ -f exec.asm ] || ko "-asm produit .exe et .asm"
if command -v objdump >/dev/null 2>&1; then
  objdump -p exec.exe | grep -q "Magic.*010b" || ko "en-tete PE"
  objdump -p exec.exe | grep -q "DLL Name: kernel32.dll" || ko "import kernel32"
  objdump -h exec.obj | grep -q "\.text" || ko "section .text du .obj"
  objdump -t exec.obj | grep -q "_A68P_Main" || ko "symbole d'entree du .obj"
fi
if [ -n "$RUNNER" ]; then
  timeout 5 "$RUNNER" exec.exe >/dev/null 2>&1
  [ $? -eq 0 ] && echo "  .exe execute: ok" || ko ".exe execute"
  if command -v lld-link >/dev/null 2>&1 && command -v llvm-dlltool >/dev/null 2>&1 \
     && command -v llvm-mc >/dev/null 2>&1; then
    { echo "LIBRARY kernel32.dll"; echo "EXPORTS"
      for f in GetStdHandle@4 WriteFile@20 ReadFile@20 ExitProcess@4 \
               GetProcessHeap@0 HeapAlloc@12 HeapFree@12; do echo $f; done; } >k32.def
    { echo ".intel_syntax noprefix"; echo ".text"
      for F in GetStdHandle:4 WriteFile:20 ReadFile:20 ExitProcess:4 \
               GetProcessHeap:0 HeapAlloc:12 HeapFree:12; do
        echo ".globl ${F%%:*}"; echo "${F%%:*}: jmp _${F%%:*}@${F##*:}"
      done; } >alias.s
    llvm-dlltool -m i386 -d k32.def -l k32.lib && \
      llvm-mc -triple=i686-pc-windows-msvc -filetype=obj alias.s -o alias.obj
    "$comp" -obj exec.a68 >log 2>&1
    lld-link /nologo /safeseh:no /subsystem:console /entry:A68P_Main \
      /base:0x400000 /fixed exec.obj alias.obj k32.lib /out:lie.exe >lk.log 2>&1 \
      || ko "lld-link"
    timeout 5 "$RUNNER" lie.exe >/dev/null 2>&1
    [ $? -eq 0 ] && echo "  .obj lie execute: ok" || ko ".obj lie execute"
  else
    echo "  lld-link absent: edition de liens ignoree"
  fi
else
  echo "  RUNNER non defini: executions ignorees"
fi
cd / && rm -rf "$tmp"
[ $bad -eq 0 ] && echo "chkpe: ok"
exit $bad
