# multifile.awk - FILENAME, FNR, ARGC, ARGV, getline
# Compile avec : AWK86.EXE multifile.awk multifile.asm
# Usage : multifile fichier1.txt fichier2.txt

BEGIN {
    print "Nombre d arguments : " ARGC
}

{
    print FILENAME ":" FNR " -> " $0
}

END {
    print "Total : " NR " enregistrements"
}
