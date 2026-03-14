* database.prg - Exemple Clipper : USE, APPEND, REPLACE, DELETE, SKIP, SEEK
* Compilation : CLIPPER86 database.prg

* --- Ouvrir un fichier DBF ---
USE clients ALIAS CLI

* --- Navigation de base ---
GO TOP
? "RECNO apres GO TOP :", RECNO()
? "EOF() :", EOF()
? "BOF() :", BOF()

GO BOTTOM
? "RECNO apres GO BOTTOM :", RECNO()
? "RECCOUNT() :", RECCOUNT()

* --- Deplacements avec SKIP ---
GO TOP
SKIP
? "Apres SKIP   : RECNO =", RECNO()
SKIP 3
? "Apres SKIP 3 : RECNO =", RECNO()
SKIP -1
? "Apres SKIP -1: RECNO =", RECNO()

* --- Acces direct ---
GO 5
? "GO 5 : RECNO =", RECNO()

* --- Informations sur la structure ---
? "FCOUNT() :", FCOUNT()
? "ALIAS()  :", ALIAS()
? "USED()   :", USED()

* --- Ajout et modification ---
APPEND BLANK
REPLACE nom WITH "Martin", prenom WITH "Pierre"
? "Nouvel enregistrement ajoute"

* --- Suppression et rappel ---
DELETE
? "DELETED() apres DELETE :", DELETED()
RECALL
? "DELETED() apres RECALL :", DELETED()

* --- Zones de travail multiples ---
SELECT 2
USE produits ALIAS PRD SHARED
? "Zone 2 : ALIAS =", ALIAS()

SELECT 1
? "Zone 1 : ALIAS =", ALIAS()

* --- Fermeture ---
CLOSE
SELECT 2
CLOSE ALL

* --- PACK et ZAP ---
USE temp
PACK
ZAP
CLOSE

* --- USE sans argument (fermer) ---
USE clients
USE

? "Fin de database.prg"
RETURN
