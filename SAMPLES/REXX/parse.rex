/* parse.rex - Exemple REXX : PARSE VAR, PARSE ARG, templates, delimiteurs */

/* PARSE VAR - decoupage par mots */
say '=== PARSE VAR par mots ==='
ligne = 'rouge vert bleu jaune'
parse var ligne c1 c2 c3 reste
say 'Couleur 1 :' c1
say 'Couleur 2 :' c2
say 'Couleur 3 :' c3
say 'Reste     :' reste

/* PARSE VAR - avec delimiteur litteral */
say
say '=== PARSE VAR avec delimiteur ==='
csv = 'Paris,Lyon,Marseille'
parse var csv v1 ',' v2 ',' v3
say 'Ville 1 :' v1
say 'Ville 2 :' v2
say 'Ville 3 :' v3

/* PARSE VAR - avec position absolue */
say
say '=== PARSE VAR avec position ==='
enreg = 'NOM     PRENOM  AGE'
parse var enreg champ1 9 champ2 17 champ3
say 'Champ 1 :' champ1
say 'Champ 2 :' champ2
say 'Champ 3 :' champ3

/* PARSE VAR - avec point (placeholder) */
say
say '=== PARSE VAR avec placeholder ==='
info = 'ignorer garder ignorer2 garder2'
parse var info . mot1 . mot2
say 'Mot 1 :' mot1
say 'Mot 2 :' mot2

/* PARSE UPPER VAR - conversion en majuscules */
say
say '=== PARSE UPPER VAR ==='
mixte = 'Hello World Rexx'
parse upper var mixte u1 u2 u3
say 'U1 :' u1
say 'U2 :' u2
say 'U3 :' u3

/* PARSE VERSION */
say
say '=== PARSE VERSION ==='
parse version ver
say 'Version :' ver

/* PARSE SOURCE */
say
say '=== PARSE SOURCE ==='
parse source src
say 'Source :' src

say
say 'Fin du programme parse.rex'
