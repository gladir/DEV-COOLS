/* strings.rex - Exemple REXX : SUBSTR, LENGTH, POS, COPIES, REVERSE, etc. */

say '=== LENGTH ==='
say 'LENGTH("Bonjour") =' length('Bonjour')
say 'LENGTH("") =' length('')
say 'LENGTH("REXX 86") =' length('REXX 86')

say
say '=== SUBSTR ==='
phrase = 'Hello World'
say 'SUBSTR("Hello World", 7) =' substr(phrase, 7)
say 'SUBSTR("Hello World", 1, 5) =' substr(phrase, 1, 5)

say
say '=== LEFT / RIGHT ==='
mot = 'Bonjour'
say 'LEFT("Bonjour", 3) =' left(mot, 3)
say 'RIGHT("Bonjour", 4) =' right(mot, 4)

say
say '=== COPIES ==='
say 'COPIES("*", 10) =' copies('*', 10)
say 'COPIES("ab", 4) =' copies('ab', 4)

say
say '=== REVERSE ==='
say 'REVERSE("Hello") =' reverse('Hello')
say 'REVERSE("12345") =' reverse('12345')

say
say '=== POS / LASTPOS ==='
texte = 'abracadabra'
say 'POS("bra", "abracadabra") =' pos('bra', texte)
say 'LASTPOS("a", "abracadabra") =' lastpos('a', texte)

say
say '=== CENTER ==='
say 'CENTER("OK", 10) =' center('OK', 10)

say
say '=== STRIP ==='
say 'STRIP("  espaces  ") =' strip('  espaces  ')

say
say '=== SPACE ==='
say 'SPACE("un  deux  trois") =' space('un  deux  trois')

say
say '=== OVERLAY ==='
say 'OVERLAY("XX", "abcdef", 3) =' overlay('XX', 'abcdef', 3)

say
say '=== INSERT ==='
say 'INSERT("XX", "abcdef", 3) =' insert('XX', 'abcdef', 3)

say
say '=== DELSTR ==='
say 'DELSTR("abcdef", 3, 2) =' delstr('abcdef', 3, 2)

say
say 'Fin du programme strings.rex'
