* test_index.prg - Test des operations d index et recherche (TODO 20)
* Compilateur Clipper86 - generation assembleur 8086

* --- INDEX ON expr TO fichier ---
USE clients
INDEX ON nom TO clients_nom
INDEX ON age TO clients_age

* --- SET INDEX TO fichier ---
SET INDEX TO clients_nom, clients_age

* --- SET ORDER TO n ---
SET ORDER TO 1
SET ORDER TO 2
SET ORDER TO 0

* --- SEEK ---
SEEK 5
? FOUND()
SEEK "Dupont"
? FOUND()

* --- LOCATE FOR condition ---
GO TOP
LOCATE FOR age > 30
? FOUND()
? RECNO()

* --- CONTINUE ---
CONTINUE
? FOUND()
? RECNO()

* --- REINDEX ---
REINDEX

* --- SET FILTER / SET RELATION ---
SET FILTER TO age > 18
SET FILTER TO

SET RELATION TO codeClient INTO commandes

* --- SET SOFTSEEK / SET EXACT / SET DELETED ---
SET SOFTSEEK ON
SET SOFTSEEK OFF
SET EXACT ON
SET EXACT OFF
SET DELETED ON
SET DELETED OFF

* --- DBEVAL ---
GO TOP
DBEVAL({|| ? RECNO()})

* --- Fonctions index ---
? ORDNAME()
? ORDCOUNT()
? FOUND()

CLOSE

RETURN
