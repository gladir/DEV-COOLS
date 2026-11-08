#!/bin/bash
# Tests du mode multi-segments de TPC (code de plus de 64 Ko, voir DOC/TPC_OPTIMISATIONS.txt).
#
# TPC_SEGSIZE=n force le mode multi-segments sur de petits programmes (segments d'environ n octets) ;
# chaque programme est compile normalement puis avec plusieurs tailles de segment, execute sous DOSBox
# et les sorties doivent etre identiques (hors adresse de l'erreur d'execution, qui change de segment).
#
# usage : run_tests.sh [chemin_de_tpc]      (defaut : ../../tpc, construit par
#         fpc -Mtp -O1 -otpc TPC.PAS a la racine du depot)
# Sans DOSBox, seule la compilation (et le nombre de segments obtenu) est verifiee.
# Option : MSDOS0=/chemin/MSDOS-0 pour verifier aussi FDISK, FORMAT et LINK (/? et un lien reel).
HERE=$(cd "$(dirname "$0")" && pwd)
TPC=$(readlink -f "${1:-$HERE/../../tpc}")
[ -x "$TPC" ] || { echo "TPC introuvable : $TPC"; exit 2; }
W=$(mktemp -d /tmp/multiseg.XXXXXX)
fail=0
ok()  { echo "OK    $*"; }
ko()  { echo "ECHEC $*"; fail=$((fail+1)); }

run_dos() {   # run_dos DIR PROG [args] -> DIR/OUT.TXT (vide si DOSBox absent)
  local d=$1 p=$2; shift 2
  command -v dosbox >/dev/null || return 1
  ( cd "$d" && rm -f OUT.TXT &&
    printf '[sdl]\nfullscreen=false\n[cpu]\ncycles=max\n[autoexec]\nmount c %s\nc:\n%s %s > OUT.TXT\nexit\n' "$PWD" "$p" "$*" > conf.txt &&
    SDL_VIDEODRIVER=dummy timeout 90 dosbox -conf conf.txt -noconsole >/dev/null 2>&1 )
  [ -f "$d/OUT.TXT" ]
}

segments() {  # nombre de segments d'une compilation (TPC_PASSES=1)
  grep -a -o 'segments=[0-9]*' "$1" | tail -1 | cut -d= -f2
}

# compare le programme P (+ options TPC) en mono-segment et en multi-segments
compare() {
  local prog=$1 opts=$2 argsets=$3; shift 3
  local d="$W/$prog"; mkdir -p "$d/n"; cp "$HERE"/*.PAS "$d/n/"
  ( cd "$d/n" && "$TPC" $opts $prog.PAS > build.log 2>&1 ) && cp "$d/n/$prog.EXE" "$d/n/REF.EXE" || { ko "$prog : compilation normale"; return; }
  for sz in "$@"; do
    mkdir -p "$d/$sz"; cp "$HERE"/*.PAS "$d/$sz/"
    ( cd "$d/$sz" && TPC_SEGSIZE=$sz TPC_PASSES=1 "$TPC" $opts $prog.PAS > build.log 2>&1 )
    [ -f "$d/$sz/$prog.EXE" ] || { ko "$prog TPC_SEGSIZE=$sz : compilation ($(tail -1 "$d/$sz/build.log"))"; continue; }
    n=$(segments "$d/$sz/build.log")
    [ "${n:-1}" -gt 1 ] || ko "$prog TPC_SEGSIZE=$sz : un seul segment obtenu"
    cp "$d/$sz/$prog.EXE" "$d/$sz/CUR.EXE"
    for a in $argsets; do
      [ "$a" = "-" ] && a=""
      run_dos "$d/n" REF.EXE $a && cp "$d/n/OUT.TXT" "$d/n/ref.out" || { ok "$prog TPC_SEGSIZE=$sz ($n segments) : compile seulement (pas de DOSBox)"; continue 2; }
      run_dos "$d/$sz" CUR.EXE $a; 
      # l'adresse de l'erreur d'execution depend du segment : on la neutralise
      if diff <(tr -d '\r' < "$d/n/ref.out" | sed 's/ a [0-9A-F]*:[0-9A-F]*\./ a X./') \
              <(tr -d '\r' < "$d/$sz/OUT.TXT" | sed 's/ a [0-9A-F]*:[0-9A-F]*\./ a X./') > "$d/$sz/diff.txt"; then
        ok "$prog TPC_SEGSIZE=$sz ($n segments) args='$a' : sorties identiques ($(wc -c < "$d/n/ref.out") octets)"
      else ko "$prog TPC_SEGSIZE=$sz args='$a' : sorties differentes (voir $d/$sz/diff.txt)"; fi
    done
  done
}

# arguments : "-" = aucun ; 3 = Halt(3) ; 4 = RunError(150) ; 5 = division par zero
compare MULTISEG1 "" "- 3 4 5" 7000 8500 12000
compare MULTISEG2 "-B" "-" 6500
# MULTISEG3 (Crt) ecrit directement dans la memoire video : compilation seulement
compare MULTISEG3 "" "" 7000 8000

# programmes reels de plus de 64 Ko de code (sans l'option TPC_SEGSIZE : mode active automatiquement)
if [ -n "$MSDOS0" ] && [ -d "$MSDOS0" ]; then
  for p in FDISK FORMAT LINK; do
    d="$W/$p"; mkdir -p "$d"; cp "$MSDOS0/$p.PAS" "$d/"
    ( cd "$d" && TPC_PASSES=1 "$TPC" $p.PAS > build.log 2>&1 )
    if [ -f "$d/$p.EXE" ]; then ok "$p : compile ($(segments "$d/build.log") segments, $(wc -c < "$d/$p.EXE") octets)"; else ko "$p : $(tail -1 "$d/build.log")"; continue; fi
    # FDISK ecrit via Crt (memoire video) : pas de redirection possible, seul /? de FORMAT et LINK est controle
    [ $p = FDISK ] && continue
    if run_dos "$d" $p.EXE '/?'; then
      [ "$(wc -c < "$d/OUT.TXT")" -gt 200 ] && ok "$p /? : aide affichee" || ko "$p /? : sortie trop courte"
    fi
  done
fi

rm -rf "$W"
[ $fail -eq 0 ] && echo "Tous les tests multi-segments passent." || echo "$fail test(s) en echec."
exit $fail
