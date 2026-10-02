TESTS/DOSEMU - Verification du "Type de processeur" de l'emulateur DOS
========================================================================

Contexte
--------
Options > Emulateur > DOS: Materiel expose desormais une liste
deroulante "Type de processeur" (DosCpuType) a 10 valeurs :
8086, 8088, 80186, NEC V20, NEC V30, 80188, 80286, 80386, 80486,
Pentium. Ce reglage pilote de vraies differences de comportement du
coeur CPU emule (voir Emu_ApplyCpuType dans DEVENV.PAS) :

- EmuCpu286Plus (deja existant) : masquage du compte CL des decalages/
  rotations a 5 bits (80186+) vs compte brut sur 8 bits (pre-186) ;
  comportement DAA/DAS AF.
- Bits reserves 12-15 de FLAGS (POPF/IRET) : forces a 1 (pre-286),
  forces a 0 (80286 reel mode), bit 15 seul force a 1 avec bits 12-14
  pilotables (80386+) - voir Emu_ApplyFlagsReservedBits.
- PUSH SP : pousse la valeur DEJA DECREMENTEE (pre-286) ou la valeur
  AVANT decrementation (80286+).
- MUL/IMUL : NEC V20/V30 calculent reellement SF/ZF/PF a partir du
  produit, contrairement au vrai Intel 8086/8088 qui les laisse
  inchanges (EmuCpuIsNEC).
- CPUID : disponible seulement si "CPUID detecte" est coche ET le
  type de processeur est 80486 ou Pentium ; famille rapportee (EAX=1)
  = 4 pour 80486, 5 pour Pentium.

CPUDETECT.A86 / CPUDETECT.COM
------------------------------
Programme DOS unique qui applique ces techniques en cascade et se
termine via INT 21h/AH=4Ch avec AL = code detecte. DEVENV affiche ce
code dans le panneau de sortie ("Programme termine (code N)") des
qu'on lance le programme (F5/Ctrl+F5) depuis l'IDE.

Pour reassembler apres modification du source :
  ASM86.exe TESTS\DOSEMU\CPUDETECT.A86 TESTS\DOSEMU\CPUDETECT /B
  (renommer ensuite CPUDETECT.BIN en CPUDETECT.COM - un binaire /B
  est deja au format .COM, aucune conversion de structure requise)

Table de correspondance attendue
---------------------------------
Regler "Type de processeur" dans Options > Emulateur : DOS >
Materiel, puis executer CPUDETECT.COM et verifier le code retour :

  Type de processeur choisi   | Code attendu | Signification du code
  -----------------------------|--------------|------------------------
  8086                         | 0            | 8086/8088 (Intel reel)
  8088                         | 0            | 8086/8088 (Intel reel)
  80186                        | 2            | 80186/80188
  NEC V20                      | 1            | NEC V20/V30
  NEC V30                      | 1            | NEC V20/V30
  80188                        | 2            | 80186/80188
  80286                        | 3            | 80286
  80386                        | 4            | 80386
  80486                        | 5            | 80486 (necessite aussi
                                |              | la case "CPUID detecte")
  Pentium                      | 6            | Pentium ou plus (idem)

Limite honnete (volontairement non resolue)
---------------------------------------------
Ce programme NE PEUT PAS distinguer :
  - 8086 de 8088 (memes instructions, seule la largeur du bus de
    donnees externe differe - invisible pour tout programme)
  - NEC V20 de NEC V30 (meme famille d'extensions NEC, seule la
    largeur de bus differe entre eux, comme 8086/8088)
  - 80186 de 80188 (idem, meme jeu d'instructions/comportement)

La technique materielle reelle pour ces paires (taille de la file
d'attente de prefetch, mesuree par du code auto-modifiant chronometre
- voir le tableau fourni par l'utilisateur) exige un modele de bus/
cycles reel. DEVENV emule au niveau INSTRUCTION (resultats et fanions
par opcode), pas au niveau cycle/bus - cette distinction restera donc
toujours hors de portee de ce banc d'essai, par construction, quel
que soit l'effort investi cote logiciel. Documente ici plutot que
simule a tort.

Verification effectuee pendant ce chantier
---------------------------------------------
- DEVENV.PAS compile sans erreur avec le nouveau DosCpuType et toute
  la logique d'emulation associee (fpc -Mtp DEVENV.PAS).
- CPUDETECT.A86 assemble sans erreur avec ASM86.exe (/B /C) ; le
  listing commente (.H86) a ete relu instruction par instruction et
  correspond exactement a l'intention (deplacements de saut courts
  tous corrects, encodage MUL BL/SHL AX,CL/CMP BX,imm16 verifies).
- Un bogue REEL preexistant d'ASM86.PAS a ete trouve et corrige
  pendant ce travail : la sortie binaire (/B) ecrivait les octets
  IMMEDIATEMENT lors de leur rencontre, AVANT que les corrections a
  posteriori (Modify_Byte - utilisees par les decalages/rotations
  avec CL, MUL/DIV selon la taille d'operande, et SURTOUT la
  resolution de tout saut/appel vers une etiquette pas encore vue)
  ne soient appliquees. Le fichier .H86 (texte) etait toujours juste,
  mais le .BIN restait fige sur l'octet PROVISOIRE - verifie octet
  par octet sur un cas reel (SHL AX,CL produisait D0 E0 au lieu de
  D3 E0 dans le binaire). Voir le commentaire de BinArray dans
  ASM86.PAS pour le detail complet du correctif.
- CE QUI N'A PU ETRE VERIFIE DANS CET ENVIRONNEMENT : l'execution
  reelle de CPUDETECT.COM a l'interieur de DEVENV pour chacun des 10
  reglages (DEVENV est une IDE plein ecran interactive sans mode de
  commande automatise de type "executer et rapporter le code de
  sortie", contrairement a BROWSER.exe qui dispose d'un mode /TEST).
  A faire manuellement : charger CPUDETECT.COM dans DEVENV, regler
  "Type de processeur", executer (F5), lire le code de sortie dans le
  panneau de sortie, repeter pour les 10 reglages et comparer a la
  table ci-dessus.
