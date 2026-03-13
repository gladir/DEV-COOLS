/* hello.rex - Exemple REXX : SAY, variables, concatenation, chaines */

/* Affichage simple */
say 'Bonjour, monde!'
say "Hello, World!"

/* Variables et affichage */
nom = 'REXX'
version = '86'
say 'Compilateur :' nom || version

/* Concatenation explicite (||) et implicite (espace) */
prenom = 'Jean'
famille = 'Dupont'
say 'Nom complet :' prenom famille
say 'Identifiant :' prenom || '.' || famille

/* Chaines avec guillemets */
msg = "C'est un test"
say msg

/* Variable numerique affichee comme chaine */
annee = 2025
say 'Annee :' annee

/* Ligne vide */
say

/* Concatenation multiple */
a = 'un'
b = 'deux'
c = 'trois'
say a b c
say a || '-' || b || '-' || c

say 'Fin du programme hello.rex'
