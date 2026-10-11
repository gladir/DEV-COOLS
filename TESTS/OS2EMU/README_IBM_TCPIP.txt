TESTS/OS2EMU - Verification d'IBM TCP/IP (client ONC/Sun RPC, RPC32DLL.DLL)
========================================================================

Contexte
--------
Demande explicite de l'utilisateur (2026-10-11, meme journee que
README_MPTS.txt et README_BSD_SOCKETS.txt) :
  1. Ajouter dans Options > Emulateur > OS/2 une 3e case a cocher "IBM
     TCP/IP" (cochee par defaut), activant/desactivant le point 2.
  2. Implementer l'API RPC fournie : callrpc, clnt_create, clnt_call,
     clnt_destroy, clnt_control, clnt_freeres, clnt_geterr, clnt_perrno,
     clnt_perror, clnt_sperrno, clnt_sperror (11 fonctions, DLL
     RPC32DLL.DLL).
  3. Creer les tests necessaires dans TESTS/OS2EMU/.

Difference fondamentale avec TCPIP32/MPTS : PAS du Winsock
--------------------------------------------------------------------
RPC32DLL.DLL implante le VRAI protocole ONC/Sun RPC (RFC 1831 pour les
messages CALL/REPLY, RFC 1833 pour le "portmapper"/RPCBIND) par-dessus
un simple socket - AUCUNE equivalence native dans ws2_32.dll,
contrairement a TCPIP32 qui map presque terme a terme sur de vraies
fonctions Winsock. Ce protocole a donc ete REIMPLANTE EN PASCAL PUR,
directement sur les sockets Winsock deja lies (Mdbc_socket/connect/
send/recv) : en-tete RPC CALL/REPLY (40/24 octets, gros-boutiste),
resolution de port via le portmapper (programme RPC 100000, UDP port
111 fixe par convention), et un vrai aller-retour reseau.

Case a cocher "IBM TCP/IP" - 3e case INDEPENDANTE
--------------------------------------------------------------------
Contrairement a "BSD Sockets d'OS/2" (qui est un SOUS-ensemble de
"MPTS"), "IBM TCP/IP" gate un module Winsock totalement DIFFERENT
(RPC32DLL, sans aucun rapport avec TCPIP32/TCP32DLL/SO32DLL/TCPIPDLL) -
voir le commentaire de tete du branchement RPC32DLL dans Lx_DoDosCall.
Decochee, les 11 fonctions tombent dans le meme "Appel systeme non
supporte" qu'un module reellement inconnu, independamment de l'etat de
MPTS/BSD Sockets.

Portee assumee et disclosee (meme discipline que ioctl/fcntl/sendmsg/
recvmsg des chantiers precedents)
--------------------------------------------------------------------
La serialisation XDR des arguments/resultats REELS d'une procedure RPC
applicative necessiterait de RAPPELER les fonctions de filtrage XDR
(inproc/outproc) fournies par le programme invite lui-meme - un vrai
mecanisme de rappel reentrant dans le code invite, hors de portee de ce
dispatcheur. Seules les procedures SANS ARGUMENT NI RESULTAT (xdr_void
des 2 cotes - le cas de TOUTE procedure 0/NULL, le "ping" RPC standard
utilise pour tester la joignabilite d'un service) sont donc reellement
et correctement serialisees. Pour toute autre procedure, l'appel
atteint quand meme REELLEMENT le serveur (en-tete RPC correct, numero
de procedure demande) mais sans les arguments reels - le serveur
repondra alors normalement PROC_UNAVAIL/GARBAGE_ARGS, jamais un succes
invente.

sethostname/setdomainname-style "faux succes" EXPLICITEMENT EVITE ici
aussi : clnt_create/callrpc interrogent un VRAI portmapper reseau ;
contre un hote qui n'en a aucun (cas tres probable sur Windows, qui
n'expose pas de portmapper par defaut, contrairement a beaucoup de
systemes Unix/Linux qui font tourner rpcbind), le resultat honnete est
RPC_TIMEDOUT(5) - JAMAIS un succes fabrique.

--------------------------------------------------------------------
RPCTEST.EXE - les 11 fonctions contre le portmapper de 127.0.0.1
--------------------------------------------------------------------
Exerce callrpc, clnt_create, clnt_control (3x : CLGET_SERVER_ADDR,
CLSET_TIMEOUT, CLGET_TIMEOUT), clnt_call, clnt_geterr, clnt_perrno,
clnt_sperrno, clnt_sperror, clnt_freeres, clnt_destroy - TOUTES contre
le PORTMAPPER lui-meme (programme RPC 100000, le service RPC le plus
basique qui soit, procedure 0/PMAPPROC_NULL) de 127.0.0.1 : AUCUNE
dependance envers un service RPC applicatif tiers, juste le
portmapper/rpcbind local.

Executer : `LXSTEP TESTS\OS2EMU\RPCTEST.EXE C8` (voir README_MPTS.txt
pour la syntaxe complete des commandes LXINFO/LXSTEP/LXDUMP).

Verification du resultat :
  - "ARRET : DosExit(action=0, code=0)" = SUCCES TOTAL : un portmapper
    a reellement repondu sur 127.0.0.1:111 (rpcbind actif sur la
    machine hote).
  - "ARRET : DosExit(action=0, code=5)" = RPC_TIMEDOUT : AUCUN
    portmapper n'ecoute sur 127.0.0.1:111 - le cas ATTENDU et HONNETE
    sur la plupart des machines Windows (qui n'exposent pas de
    portmapper par defaut), PAS un bogue. La ligne juste avant,
    produite par clnt_perrno, affiche directement "RPC: Timed out"
    dans le Terminal - 2e confirmation independante du meme resultat.
  - Round-trips internes verifiables (dans D_RESULTS, inspectables via
    un futur outil de dump post-execution si besoin) : R4 (resultat de
    CLGET_TIMEOUT) doit valoir exactement 1 (TRUE) ET D_TOBUF doit
    valoir exactement (3,0) apres l'appel - preuve que CLSET_TIMEOUT
    puis CLGET_TIMEOUT font un aller-retour correct sur l'etat du
    client. R6 (relu via clnt_geterr) doit valoir EXACTEMENT R5 (le
    code de clnt_call) - preuve que clnt_geterr reflete bien le dernier
    appel. R9 (clnt_freeres) doit TOUJOURS valoir 1 (TRUE).

CE QUI N'A PU ETRE VERIFIE DANS CET ENVIRONNEMENT
--------------------------------------------------------------------
Memes limites que README_MPTS.txt/README_BSD_SOCKETS.txt : l'execution
reelle EN DIRECT dans l'IDE DEVENV (LXSTEP) n'a pas pu etre lancee
depuis cet environnement. La verification effectuee couvre
l'integralite du format conteneur LX (en-tete/objets/pages/fixups/
imports, via VERIFYLX.PAS - "TOUTES LES VERIFICATIONS ONT REUSSI" pour
RPCTEST.EXE) et la correction de chaque instruction x86 emise (relue et
recoupee champ par champ contre le code source reel de Lx_DoDosCall/
Os2Rpc_*), mais pas le comportement du decodeur Lx_Step lui-meme sur
ces octets precis, ni le resultat REEL du dialogue reseau avec un
portmapper (qui depend entierement de la presence ou non d'un service
RPC sur la machine qui executera le test - voir disclosure ci-dessus).

Fichiers de ce dossier (RPC32DLL)
--------------------------------------------------------------------
RPCTEST.EXE : l'executable LX de test.
BUILDLX.PAS : etendu (4e procedure BuildRpcTest) avec la meme
  infrastructure generique que les 3 premiers fichiers (voir
  README_MPTS.txt).
VERIFYLX.PAS : corrige (2026-10-11, bogue REEL trouve en testant
  RPCTEST.EXE a 1 seul argument - voir le commentaire de tete de
  VerifyFile) + generalise a N fichiers en argument (meme correctif
  deja applique independamment a VERIFYLX2.PAS lors du chantier
  precedent).
