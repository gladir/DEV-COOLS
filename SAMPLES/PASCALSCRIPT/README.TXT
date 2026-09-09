EXEMPLES PASCALSCRIPT CONSOLE
=============================

Ces scripts utilisent la syntaxe PascalScript classique et l'objet WScript
fourni par un hote ActiveScript compatible.

Exemple de lancement avec un hote CSCRIPT prenant PascalScript en charge :

  CSCRIPT //E:PascalScript //Nologo SAMPLES\PASCALSCRIPT\01_hello.psc

Les fichiers sont numerotes par difficulte approximative :

  01  Affichage console et objet WScript
  02  Variables et mathematiques
  03  Chaines de caracteres
  04  Conditions et Case
  05  Boucles
  06  Tableaux statiques et dynamiques
  07  Procedures et parametres
  08  Fonctions et recursion
  09  Enumerations et enregistrements
  10  Arguments de ligne de commande
  11  Variants et conversions
  12  Exceptions
  13  Sortie anticipee avec Exit
  14  Acces base de donnees (Database/DatabaseConnection/RecordSet)
  15  Acces direct a un fichier dBASE .DBF (Database.Connect('File=...'))
  16  Acces direct a un fichier CSV .CSV (Database.Connect('File=...'))

PascalScript est un langage Pascal embarque : selon l'hote utilise, certaines
extensions comme les tableaux dynamiques, Variant ou try/except peuvent varier.

Les exemples 14/15/16 utilisent Write/WriteLn (pas WScript.Echo) et les objets
Database/DatabaseConnection/RecordSet - extensions specifiques a l'hote
PSCRIPT de ce depot (DEVENV.PAS), pas une norme PascalScript generale.
14 relie ces objets au vrai moteur SQL Server local (SQLCMD.EXE/master.mdf) ;
15 et 16 utilisent la forme 'File=xxx.DBF/.CSV;...' de Database.Connect, qui
ouvre directement le fichier indique via le meme lecteur que la Grille de
donnees de l'IDE (WK_GRID) - aucun SQLCMD.EXE dans ce cas, et le texte de
Query n'est pas analyse (une connexion File=... pointe deja sur un seul
fichier, donc Query renvoie toujours toutes ses colonnes/lignes). Pour un
fichier .CSV, la premiere ligne n'est JAMAIS devinee comme un en-tete (meme
comportement honnete que la Grille elle-meme) - les colonnes s'appellent
'Champ1'/'Champ2'/... et la premiere ligne LUE est la ligne d'en-tete du
fichier, pas une donnee reelle (voir 16_database_csv.psc pour le detail).
