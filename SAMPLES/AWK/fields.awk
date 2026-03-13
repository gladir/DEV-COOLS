# fields.awk - Champs $1 $2 $NF, NR, NF, FS
# Compile avec : AWK86.EXE fields.awk fields.asm
# Usage : fields < data.txt

BEGIN {
    FS = ":"
}

{
    print "Ligne " NR " a " NF " champs"
    print "  Premier : " $1
    print "  Dernier : " $NF
}

END {
    print "Total : " NR " lignes"
}
