Exemples de programmes COS Absolute Binary avec PDT (Program Description
Table) pour l'emulateur Cray-1 integre de DEVENV.PAS (CRAY1_LoadAbs).

Format de fichier (voir DEVENV.PAS, commentaire de tete pres de
CRAY1_LoadAbs) :

  Offset  Taille  Champ
  0       8       Signature 'CRAY-PDT' (variante avec PDT) ou 'CRAY-1'
                  suivi de 2 octets nuls (variante sans PDT)
  8       8       JOBNAME (8 caracteres ASCII, bourrage par des espaces)
                  -- uniquement si signature 'CRAY-PDT'
  16      8       FL (Field Length demandee, mots CRAY 64 bits, seuls les
                  4 derniers octets sont utilises, poids fort en tete)
                  -- uniquement si signature 'CRAY-PDT'
  24      8       PRIORITY (0-63, dernier octet du mot)
                  -- uniquement si signature 'CRAY-PDT'
  ...     8       CodeWords (mots CRAY 64 bits de code)
  ...     8       DataWords (mots CRAY 64 bits de donnees)
  ...     8       EntryAddr (adresse de depart, en "parcels" de 16 bits)
  ...     *2      (CodeWords+DataWords)*4 "parcels" de 16 bits, poids
                  fort en tete, chacun un mot memoire CRAY1_Mem[]

La FL est VERIFIEE au chargement : si CodeWords+DataWords depasse la FL
demandee, le chargement est refuse (meme comportement qu'un vrai COS).

Fichiers de cet dossier :

  hello_pdt.abs  - JOB=HELLO FL=10 PRIORITY=10. Affiche
                   "HELLO FROM CRAY-1 COS" puis s'arrete (EX service 3
                   print string, puis service 2 newline, puis service 7
                   halt).

  count_pdt.abs  - JOB=COUNT FL=4 PRIORITY=5 (FL exactement egale au
                   besoin reel : demontre l'acceptation a la limite).
                   Boucle S1=1..5 (LDIMM/ADDS/SUBS/JSN) affichant un
                   nombre par ligne (EX service 1 print int) puis
                   s'arrete.

Ces fichiers sont des binaires bruts crees a la main (aucun compilateur
de ce depot n'emet encore la variante 'CRAY-PDT') - octets verifies en
reexecutant le meme decodage que CRAY1_LoadAbs/CRAY1_Step/CRAY1_Trap
dans un petit programme Pascal autonome jetable avant integration ici.
