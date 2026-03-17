# test_keywords.awk - Test de reconnaissance des mots-cles,
#   fonctions builtin et variables builtin AWK (TODO 03)
# Compile avec : AWKCW32 test_keywords.awk -d

# Mots-cles AWK (21) : BEGIN END BEGINFILE if else while for do in
#   break continue function return delete exit getline next nextfile
#   print printf sprintf

BEGIN {
    # Variables builtin (16) : FS RS OFS ORS NR NF FNR
    #   FILENAME ARGC ARGV ENVIRON RSTART RLENGTH SUBSEP OFMT CONVFMT
    FS = ":"
    OFS = " | "
    ORS = "\n"
    RS = "\n"
    OFMT = "%.6g"
    CONVFMT = "%.6g"
    SUBSEP = "\034"

    # Fonctions builtin (24) : length substr index split
    #   sub gsub match sprintf tolower toupper
    #   sin cos atan2 exp log sqrt int rand srand
    #   system close fflush mktime strftime
    x = length("hello")
    y = substr("abcdef", 2, 3)
    z = index("hello world", "world")
    n = split("a:b:c", arr, ":")
    s = sprintf("%d + %d = %d", 1, 2, 3)
    lo = tolower("HELLO")
    up = toupper("world")
    a = sin(3.14)
    b = cos(0)
    c = atan2(1, 1)
    d = exp(1)
    e = log(2.718)
    f = sqrt(144)
    g = int(3.7)
    srand(42)
    r = rand()

    # Keywords dans contexte
    print "NR=" NR " NF=" NF " FNR=" FNR
    printf "ARGC=%d\n", ARGC
    print "FILENAME=" FILENAME
    print "RSTART=" RSTART " RLENGTH=" RLENGTH
    if (NR == 0) {
        print "debut"
    } else {
        print "suite"
    }
    for (i = 1; i <= 3; i++) {
        if (i == 2) continue
        print i
    }
    exit 0
}

# Pattern-action avec variables builtin
/test/ {
    print NR, NF, $0
    delete arr
}

function max(a, b) {
    if (a > b) return a
    else return b
}

END {
    print "fin"
}
