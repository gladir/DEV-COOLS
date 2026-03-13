/* test_strings.rexx - Test des fonctions integrees de chaines (TODO 15) */

/* LENGTH */
say LENGTH("hello")
say LENGTH("")
say LENGTH("REXX")

/* SUBSTR */
say SUBSTR("hello world", 7)
say SUBSTR("hello world", 1, 5)
say SUBSTR("abcdef", 3, 2)

/* LEFT */
say LEFT("hello", 3)
say LEFT("hi", 5)

/* RIGHT */
say RIGHT("hello", 3)
say RIGHT("hi", 5)

/* COPIES */
say COPIES("ab", 3)
say COPIES("*", 5)

/* REVERSE */
say REVERSE("hello")
say REVERSE("abcde")

/* POS */
say POS("ll", "hello")
say POS("xyz", "hello")
say POS("o", "hello world", 5)

/* LASTPOS */
say LASTPOS("l", "hello world")

/* CENTER */
say CENTER("hi", 6)
say CENTER("hello", 3)

/* STRIP */
say STRIP("  hello  ")

/* SPACE */
say SPACE("  hello   world  ")
say SPACE("a  b  c", 1)

/* OVERLAY */
say OVERLAY("XX", "abcdef", 3)

/* INSERT */
say INSERT("XX", "abcdef", 3)

/* DELSTR */
say DELSTR("abcdef", 3, 2)
say DELSTR("abcdef", 3)
