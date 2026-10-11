TESTS/OS2EMU - Verification du MPTS (TCPIP32) de l'emulateur OS/2 LX
========================================================================

Contexte
--------
Demande explicite de l'utilisateur (2026-10-11) : apres l'ajout des 20
fonctions BSD Sockets de MPTS (TCPIP32.DLL/TCP32DLL.DLL/SO32DLL.DLL/
TCPIPDLL.DLL, voir project_devenv_os2_tcpip32.md) au dispatcher d'import
LX (Lx_DoDosCall), ecrire des fichiers de test que l'emulateur OS/2 PUISSE
REELLEMENT EXECUTER pour verifier que le MPTS fonctionne - pas seulement
qu'un harnais Winsock autonome, hors de l'emulateur, fonctionne (ce qui
avait deja ete fait, voir os2tcptest.pas cite dans project_devenv_os2_
tcpip32.md, mais sans jamais passer par Emu_LoadLX/Lx_Step/Lx_DoDosCall).

Difference fondamentale avec TESTS/DOSEMU : pas de format plat
-----------------------------------------------------------------
Les tests DOS (NBTEST/PKTTEST/WATTCPTEST, voir README_NETWORK.txt du
meme depot) sont de simples .COM assembles par ASM86.exe. Un executable
OS/2 LX (Linear eXecutable) est un conteneur bien plus complexe : en-tete
de 176 octets, table d'objets, table de pages objet, table de pages de
fixup, table d'enregistrements de fixup, table de noms de modules
importes, table de noms de procedures importees. Une recherche prealable
(agent Explore) a confirme :
  - Aucun executable OS/2 LX reel n'est present dans ce depot (les 2 seuls
    fichiers jamais utilises pour developper cet emulateur, ddnsicon.exe
    et LOGDAEM.EXE, vivent sur la machine de l'utilisateur, hors du depot
    Git - voir les commentaires DEVENV.PAS:6432/6758).
  - Aucun outil de ce depot ne sait PRODUIRE un conteneur LX (contrairement
    a GENIM2.PAS pour le format Hunk Amiga, ou ML.PAS pour PE/COFF Win32).
  - Aucun precedent de "fichier LX minimal" n'existe dans ce code : les
    verifications anterieures (PMWIN Clipboard, DOSCALLS) ont TOUJOURS
    soit charge un vrai fichier externe non commite (LXLOAD/LXSTEP sur
    ddnsicon.exe/LOGDAEM.EXE), soit construit un cadre d'appel SYNTHETIQUE
    bypassant completement Emu_LoadLX/Lx_Step (TermCmd_LXCall/LXPMTest -
    voir DEVENV.PAS:130029+/130100+, commentaire "SANS Emu_LoadLX").

Consequence : TCPSOCK.EXE/TCPNAME.EXE/TCPOPT.EXE ci-dessous sont les
TOUT PREMIERS fichiers de ce depot a exercer, de bout en bout, le vrai
chargeur LX (Emu_LoadLX), le vrai mecanisme de fixup (Lx_ApplyPageFixups),
et le vrai decodeur d'instructions x86-32 (Lx_Step) - construits a la
main, octet par octet, via BUILDLX.PAS (ci-joint, compile avec FPC),
dans le meme esprit que GENIM2/le format .PAK : pas d'assembleur/linker
OS/2 disponible, donc generation directe du conteneur + code machine.

Sous-ensemble x86-32 utilise (volontairement restreint)
---------------------------------------------------------
Uniquement MOV (reg<-imm32, mem<-reg, reg<-mem, octet mem<-imm8), PUSH
(imm32, reg<-mem indirect via "push m32"), et CALL rel32 - le sous-
ensemble le plus simple et le moins ambigu a assembler a la main, sans
AUCUN saut conditionnel ni instruction de comparaison (CMP/Jcc/SETcc) :
les 3 programmes executent une sequence PUREMENT LINEAIRE d'appels MPTS,
et rapportent leurs resultats en les ecrivant dans un bloc de donnees
dedie (D_RESULTS) ainsi que via le code de sortie DosExit (ordinal 234
DOSCALLS) et un DosWrite (ordinal 282) pour TCPSOCK.

2 bogues REELS trouves et corriges dans BUILDLX.PAS pendant l'ecriture
--------------------------------------------------------------------
1. **En-tete LX ecrit a 168 octets au lieu des 176 requis** : 2 champs
   manquants dans la sequence d'emission (e32_dircnt entre e32_dirtab et
   e32_fpagetab ; e32_instdemand entre e32_instpreload et e32_heapsize) -
   detecte IMMEDIATEMENT par une assertion de taille (`If Hdr.Len<>176`),
   avant meme d'ecrire un seul fichier. Corrige en ajoutant les 2 champs
   manquants, re-verifie par la meme assertion.
2. **Page de code classee a tort "BSS" (jamais chargee en memoire)** :
   l'arrondi de l'offset de la zone de donnees de page (e32_datapage) a
   un multiple de 512 octets (granularite imposee par e32_pageshift=9)
   etait applique a la valeur RELATIVE a l'en-tete (DataPageOfs) plutot
   qu'a la valeur ABSOLUE (DataPageOfs+HdrOfs) - des que HdrOfs(=$40)
   n'est lui-meme pas un multiple de 512 (ce qui est systematiquement le
   cas ici), l'addition finale (e32_datapage := DataPageOfs+HdrOfs) sort
   du multiple de 512 vise, et le calcul SectorOffset=e32_datapage/512
   (division entiere) perd silencieusement les 64 derniers octets -
   Emu_LoadLX comparant alors FileOfs(=SectorOffset*512) < e32_datapage,
   traitait la page de CODE ENTIERE comme "zero-fill" (le programme
   n'etait alors JAMAIS vraiment charge, bien que le fichier semble
   valide a l'inspection de l'en-tete seul). Trouve par VERIFYLX.PAS
   (ci-joint) - EXACTEMENT la meme discipline "un harnais de verification
   independant attrape des bogues invisibles a la simple relecture de
   code" appliquee a chaque chantier de cette session (DISPAK/HFS/ASM86).
   Corrige en arrondissant la valeur ABSOLUE.

Verification effectuee pendant ce chantier
---------------------------------------------
- VERIFYLX.PAS (ci-joint, compile avec FPC) reimplemente, ligne par
  ligne, la MEME logique que Lx_ReadHeader/Emu_LoadLX/Lx_ApplyPageFixups
  lues directement dans DEVENV.PAS (pas une transcription de memoire) et
  confirme, pour les 3 fichiers :
   * Signature MZ/e_crlc=0/e_lfanew, puis signature LX, en-tete 176
     octets integralement relu et coherent (objcnt/startobj/stackobj/
     pageshift dans les bornes attendues).
   * Chaque page objet (CODE et DONNEES) resout vers un FileOfs reel
     SUPERIEUR OU EGAL a e32_datapage (donc chargee comme donnees
     reelles, PAS comme BSS).
   * Chaque enregistrement de fixup (14 pour TCPSOCK, 4 pour TCPNAME, 18
     pour TCPOPT) pointe exactement sur l'octet $E8 (CALL rel32) emis par
     BUILDLX.PAS - preuve directe qu'aucun fixup ne cible un octet voisin
     par erreur de calcul de decalage.
   * Chaque fixup resout le COUPLE (module importe, nom de procedure)
     EXACT attendu, dans l'ORDRE d'emission du code (ex. TCPOPT : SOCKET,
     BIND, LISTEN, GETSOCKNAME, SOCKET, CONNECT, ACCEPT, GETPEERNAME,
     SHUTDOWN, IOCTL, SETSOCKOPT, GETSOCKOPT, GETHOSTBYADDR, SELECT,
     CLOSESOCKET x3, DosExit) - confirme que le mecanisme de resolution
     d'emplacement de trappe (Lx_ResolveImportSlot, reimplemente a
     l'identique dans VERIFYLX.PAS) attribuerait les MEMES emplacements
     que le vrai DEVENV.PAS.
  Sortie complete : "=== TOUTES LES VERIFICATIONS ONT REUSSI ===" pour
  les 3 fichiers (aucun echec residuel apres les 2 correctifs ci-dessus).
- L'ordre d'empilement des arguments (droite-a-gauche, dernier argument
  pousse EN PREMIER) a ete verifie MANUELLEMENT pour chacun des 18 appels
  MPTS distincts, champ par champ, contre les lectures `Lx_ReadDWord(ESP+
  4/+8/+12/...)` et les valeurs NArgsPopped lues directement dans
  Lx_DoDosCall (DEVENV.PAS:128456-128890) - PAS supposees de memoire.
- La convention stdcall de retour (Lx_DoDosCall lit RetAddr=[ESP] PUIS
  ESP+=4+NArgsPopped*4 PUIS EIP:=RetAddr, voir DEVENV.PAS:128901-128903)
  a ete relue directement pour confirmer qu'aucun nettoyage de pile cote
  appelant n'est necessaire (l'emulateur depile lui-meme, cote "appele",
  exactement N arguments par fonction - code en dur par fonction, PAS lu
  depuis un quelconque champ du fichier).

CE QUI N'A PU ETRE VERIFIE DANS CET ENVIRONNEMENT
---------------------------------------------------
L'execution reelle, EN DIRECT dans l'IDE DEVENV (LXSTEP, voir plus bas),
n'a pas pu etre lancee depuis cet environnement (meme limite documentee
dans TESTS/DOSEMU/README_NETWORK.txt - IDE plein ecran sans mode de
commande automatise). La verification ci-dessus couvre tout ce qui est
VERIFIABLE SANS executer l'emulateur lui-meme : l'integralite du format
conteneur (en-tete/objets/pages/fixups/imports) et la correction de
CHAQUE instruction x86 emise (opcode/ModRM/ordre des arguments/valeurs
immediates), relues et recoupees champ par champ contre le code source
reel de Emu_LoadLX/Lx_ApplyPageFixups/Lx_DoDosCall - mais PAS le
comportement du decodeur Lx_Step lui-meme sur ces octets precis (bien
qu'il s'agisse du sous-ensemble d'opcodes x86 le plus simple et le plus
communement rencontre, deja exerce par les executables reels compiles
ddnsicon.exe/LOGDAEM.EXE). A faire manuellement : charger chaque .EXE
via les commandes ci-dessous et lire le resultat affiche.

--------------------------------------------------------------------
Comment executer ces tests dans DEVENV
--------------------------------------------------------------------
Depuis le Terminal de l'IDE (commandes LXINFO/LXLOAD/LXSTEP/LXDUMP,
disponibles dans le meme bloc de commandes que COCO3/ARM64/PEINFO -
voir DEVENV.PAS:165307+) :

  LXINFO  TESTS\OS2EMU\TCPSOCK.EXE
    -> affiche l'en-tete/objets/imports decodes (verification statique,
       aucune execution).

  LXSTEP  TESTS\OS2EMU\TCPSOCK.EXE C8
    -> charge ET EXECUTE jusqu'a $C8 (=200 decimal - le compte est
       TOUJOURS interprete en hexadecimal par cette commande, meme
       convention qu'ELFBP) instructions, largement suffisant pour
       atteindre le DosExit final (l'execution s'arrete d'elle-meme des
       que LX_Halted devient vrai, avant d'epuiser le compte). Affiche
       en texte le registre EAX/EBX/ECX/EDX, ESP/EBP/ESI/EDI, et surtout
       la ligne "ARRET : DosExit(action=0, code=N)" - c'est CETTE ligne
       qui porte le resultat du test, PAS les registres (qui refletent
       simplement l'etat laisse par le DERNIER appel execute, souvent
       CLOSESOCKET, sans rapport avec le succes du test).

  LXDUMP  TESTS\OS2EMU\TCPSOCK.EXE 10000
    -> charge (SANS EXECUTER - LXDUMP ne fait AUCUN Lx_Step, uniquement
       Emu_LoadLX) et affiche 16 octets a l'adresse donnee. Utile pour
       confirmer qu'un fixup a bien ete applique AVANT toute execution :
       par exemple, a l'adresse $10010 (le disp32 du tout premier CALL
       de TCPSOCK.EXE, juste apres l'octet E8 a $1000F), les 4 octets
       doivent former un deplacement relatif NON NUL qui, une fois ajoute
       a $10014 (l'adresse suivant immediatement ce disp32), tombe dans
       la plage $1E00000-$1FFFFFF (LX_TRAP_BASE) - PAS une adresse brute
       de fichier ni des zeros.

TCPSOCK.EXE - cycle socket/bind/listen/connect/accept/send/recv
--------------------------------------------------------------------
9 fonctions MPTS en boucle locale (127.0.0.1, port ephemere choisi par
l'hote et relu via getsockname) : SOCKET, BIND, LISTEN, GETSOCKNAME,
SOCKET (client), CONNECT, ACCEPT, SEND, RECV, puis CLOSESOCKET x3.

Verification du resultat : la ligne "ARRET : DosExit(action=0, code=3)"
signale un succes total (recv() a recu exactement les 3 octets envoyes).
Un code different de 3 (0, negatif, ou une autre petite valeur) indique
un echec a un endroit de la chaine - inspecter les lignes LXSTEP
precedentes (historique EIP/ESP) pour localiser l'appel fautif.
Un deuxieme signal, INDEPENDANT du code de sortie : juste avant la ligne
d'arret, DosWrite(1, ...) ecrit directement "HI!" dans le panneau du
Terminal si recv() a reellement recu les octets envoyes par send() via
le vrai aller-retour TCPIP32->Winsock (PAS une boucle locale simulee -
send()/recv() passent par 2 vrais appels socket() Winsock distincts,
cote emulateur, relies uniquement par le vrai noyau reseau de l'hote).

TCPNAME.EXE - resolution de noms reelle
--------------------------------------------------------------------
3 fonctions MPTS : GETHOSTBYNAME("one.one.one.one" - adresse publique
Cloudflare stable, 1.0.0.1 ou 1.1.1.1 selon l'ordre de resolution DNS de
la machine hote), GETSERVBYNAME("http","tcp"), GETSERVBYPORT(80,"tcp").
Necessite un acces Internet/DNS reel depuis la machine qui execute DEVENV.

Verification du resultat : le code de sortie final est l'adresse IP
resolue, relue en entier comme 4 octets bruts [a,b,c,d] interpretes en
LongInt little-endian (a + b*256 + c*65536 + d*16777216). Pour 1.0.0.1
ou 1.1.1.1, l'octet de poids FORT (le DERNIER octet reseau de l'IP) vaut
TOUJOURS 1 dans les 2 cas : "ARRET : DosExit(action=0, code=16777217)"
(=$01000001, pour 1.0.0.1) ou "code=16843009" (=$01010101, pour 1.1.1.1)
signalent tous deux un succes - diviser le code par 16777216 doit donner
exactement 1. Un code de 0 signale un echec de resolution DNS (verifier
l'acces reseau reel de la machine hote).

TCPOPT.EXE - introspection et options de socket
--------------------------------------------------------------------
Complete la couverture a 20/20 fonctions MPTS (avec TCPSOCK+TCPNAME) :
reprend la sequence SOCKET/BIND/LISTEN/GETSOCKNAME/SOCKET/CONNECT/ACCEPT
de TCPSOCK (pour disposer de sockets valides et connectes), puis exerce
GETPEERNAME, SHUTDOWN, IOCTL (FIONBIO), SETSOCKOPT+GETSOCKOPT
(SO_REUSEADDR), GETHOSTBYADDR(127.0.0.1), SELECT, puis CLOSESOCKET x3.
Seuls les ALIAS de nom (SOCLOSE=meme gestionnaire que CLOSESOCKET,
TCP32DLL/SO32DLL/TCPIPDLL=meme gestionnaire que TCPIP32) ne sont pas
redondes ici - deja couverts par construction (meme code Pascal cote
emulateur, voir Lx_DoDosCall).

Verification du resultat : la ligne "ARRET : DosExit(action=0, code=1)"
signale un succes total de l'aller-retour SETSOCKOPT->GETSOCKOPT (la
valeur SO_REUSEADDR=1 ecrite est bien celle relue en retour - le signal
le plus deterministe de ce test, contrairement a SELECT dont le resultat
0 ou 1 depend legitimement de l'etat reel, non force, du socket au
moment de l'appel). Un code different de 1 indique un echec quelque part
dans la chaine setsockopt/getsockopt.

Fichiers de ce dossier
--------------------------------------------------------------------
TCPSOCK.EXE / TCPNAME.EXE / TCPOPT.EXE : les executables LX de test.
BUILDLX.PAS : le generateur (FPC, {$MODE OBJFPC}) - reconstruit les 3
  .EXE depuis zero (`fpc BUILDLX.PAS && BUILDLX .`), documente integra-
  lement le format conteneur LX construit a la main (commentaires de
  tete de chaque section).
VERIFYLX.PAS : le harnais de verification independant (FPC) - reimple-
  mente Emu_LoadLX/Lx_ApplyPageFixups et confirme la coherence de
  n'importe quel fichier LX genere (`fpc VERIFYLX.PAS && VERIFYLX
  TCPSOCK.EXE TCPNAME.EXE TCPOPT.EXE`).
