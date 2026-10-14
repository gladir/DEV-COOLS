TESTS/CORAIL_TPC - Verification de TPC.PAS avec les sources du projet CORAIL
============================================================================

Principe
--------
Les 525 fichiers .PAS du projet CORAIL (https://github.com/gladir/corail) ont
ete ecrits pour Turbo Pascal 7.0 et le depot fournit dans BIN16/ les
executables produits par le compilateur Borland. Chaque source est compile
avec TPC (clone de TPC.EXE, fichier TPC.PAS de ce depot), puis l'executable
obtenu et l'executable Borland sont lances tous les deux sous DOSBox avec les
memes arguments; la sortie standard (OUT.TXT), le texte de l'ecran (capture
par SCRDUMP.PAS) et les fichiers produits sont compares.

Quatre modes d'execution:
  help    : NOM.EXE /?            (ecran d'aide)
  noarg   : NOM.EXE               (aucun argument)
  nofile  : NOM.EXE NOFILE.TXT    (fichier inexistant)
  sample  : NOM.EXE <arguments>   (arguments de sample_args.txt, deduits de la
            ligne "Syntaxe" de chaque programme, avec les fichiers d'exemple
            du repertoire samples/)

Classes de resultat de compare.py:
  IDENTIQUE    sortie, ecran et fichiers produits identiques
  STDOUT_DIFF  sortie standard differente (ecran identique)
  ECRAN_DIFF   ecran different (sortie identique)
  FICHIER_DIFF seuls les fichiers produits different
  DIFF         sortie et ecran differents
  ERREUR_EXEC  erreur d'execution cote TPC seulement
  TIMEOUT_2    les deux programmes depassent le delai (programmes interactifs)
  TIMEOUT_REF / TIMEOUT_OUR  un seul des deux depasse le delai
Les lignes "Runtime error NNN at XXXX:XXXX." (Borland) et "Erreur
d'execution NNN a XXXX:XXXX." (TPC) sont considerees equivalentes si le
numero est le meme (l'adresse depend forcement du compilateur).

Utilisation
-----------
  git clone https://github.com/gladir/corail /tmp/corail
  CORAIL=/tmp/corail WORK=/tmp/corail-tests ./TESTS/CORAIL_TPC/run_all.sh
Options: run_all.sh [binaire TPC] ["help noarg nofile sample"]; JOBS=n pour le
nombre de DOSBox en parallele (4 par defaut), TIMEOUT_SEC (25 s par execution).
Resultats dans $WORK: results.txt (compilation), compare_<mode>.txt, et un
repertoire runs_<mode>/{ref,our}_NOM par execution.

Fichiers
--------
  run_all.sh       compilation + execution des quatre modes + comparaison
  run_one.sh       une execution (NOM, ref|our, mode) sous DOSBox
  compare.py       classement des resultats d'un mode
  SCRDUMP.PAS      capture de l'ecran texte (compile avec TPC, tourne sous DOS)
  sample_args.txt  arguments du mode sample (NOM puis arguments)
  samples/         fichiers d'exemple SAMPLE.* (SAMPLE.EXE est une copie de
                   ISBN.EXE produite au moment du test)

Les resultats obtenus sont consignes dans DOC/CORAIL_TPC_TESTS.txt.
