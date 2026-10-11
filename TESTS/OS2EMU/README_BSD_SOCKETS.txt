TESTS/EMUOS2 - Verification des 20 NOUVELLES fonctions BSD Sockets d'OS/2
========================================================================

Contexte
--------
Demande explicite de l'utilisateur (2026-10-11, meme journee que
TESTS/OS2EMU) :
  1. Ajouter dans Options > Emulateur > OS/2 une case a cocher "BSD
     Sockets d'OS/2" (cochee par defaut), activant/desactivant le point 2.
  2. Implementer l'API TCP/IP complete (41 entrees TCPIP32.DLL fournies
     par l'utilisateur).
  3. Creer dans TESTS/EMUOS2/ les tests necessaires.

21 des 41 entrees fournies etaient DEJA implementees par le chantier
precedent (voir TESTS/OS2EMU/ et project_devenv_os2_tcpip32.md) : socket,
bind, listen, accept, connect, shutdown, closesocket, send, recv, sendto,
recvfrom, getsockname, getpeername, getsockopt, setsockopt, ioctl,
select, gethostbyname, gethostbyaddr, getservbyname, getservbyport. Ce
dossier (EMUOS2, distinct de OS2EMU - nom demande tel quel) couvre les
20 fonctions RESTANTES, toutes nouvellement ajoutees a Lx_DoDosCall dans
DEVENV.PAS : sendmsg, recvmsg, socketpair, fcntl, gethostname,
sethostname, getdomainname, setdomainname, getprotobyname,
getprotobynumber, inet_addr, inet_ntoa, inet_network, inet_lnaof,
inet_netof, inet_makeaddr, htonl, htons, ntohl, ntohs.

Case a cocher "BSD Sockets d'OS/2" (renommage, pas un ajout en double)
--------------------------------------------------------------------
Un chantier anterieur, le MEME jour, avait deja ajoute une case "Reseau
MPTS (TCPIP32)" qui gate EXACTEMENT le meme branchement TCPIP32/
TCP32DLL/SO32DLL/TCPIPDLL de Lx_DoDosCall. Plutot que d'ajouter une 2e
case redondante avec la meme portee fonctionnelle, elle a ete RENOMMEE
"BSD Sockets d'OS/2" (champ Pascal renomme Os2Mpts -> Os2BsdSockets,
toujours Boolean, toujours cochee par defaut) - continue a gater les 41
fonctions (les 21 deja existantes ET les 20 nouvelles ci-dessous) d'un
seul coup, exactement comme demande ("activant ou desactivant le point
2" - "le point 2" etant l'integralite de l'API).

Memes techniques et disciplines que TESTS/OS2EMU
--------------------------------------------------------------------
Aucun executable OS/2 LX reel, aucun outil de ce depot ne sachant en
produire (voir TESTS/OS2EMU/README_MPTS.txt pour le detail complet de
cette recherche) : BUILDLX2.PAS construit a la main, octet par octet,
les 2 executables ci-dessous (MEME infrastructure generique que
TESTS/OS2EMU/BUILDLX.PAS, recopiee telle quelle pour que ce dossier
reste autonome) ; VERIFYLX2.PAS (meme reimplementation independante de
Emu_LoadLX/Lx_ApplyPageFixups que l'original, legerement generalisee
pour accepter un nombre quelconque de fichiers en argument) confirme
que les 2 fichiers chargent correctement et que tous les fixups
resolvent le bon couple (module, nom de fonction) dans l'ordre
d'emission - "TOUTES LES VERIFICATIONS ONT REUSSI" pour les 2 fichiers,
AUCUN bogue de generation cette fois (contrairement au 1er lot, dont
les 2 bogues de BUILDLX.PAS - en-tete a 168 octets, arrondi de
e32_datapage - sont restes corriges dans l'infrastructure reutilisee
ici des le premier essai).

Sous-ensemble x86-32 identique (MOV/PUSH/CALL uniquement, aucun saut
conditionnel) - voir TESTS/OS2EMU/README_MPTS.txt pour la justification
complete de ce choix.

--------------------------------------------------------------------
Comment executer ces tests dans DEVENV
--------------------------------------------------------------------
Memes commandes Terminal que TESTS/OS2EMU (LXINFO/LXSTEP/LXDUMP, voir
TESTS/OS2EMU/README_MPTS.txt pour leur syntaxe complete) :

  LXSTEP  TESTS\EMUOS2\TCPCONV.EXE C8
  LXSTEP  TESTS\EMUOS2\TCPEXT.EXE C8

(compte d'instructions TOUJOURS en hexadecimal, $C8=200 decimal,
largement suffisant - l'execution s'arrete d'elle-meme au DosExit final
avant d'epuiser ce compte).

TCPCONV.EXE - fonctions de conversion/traduction (16 des 20 nouvelles)
--------------------------------------------------------------------
htonl/htons/ntohl/ntohs, inet_addr/inet_ntoa/inet_network/inet_lnaof/
inet_netof/inet_makeaddr, gethostname/sethostname/getdomainname/
setdomainname (etat SIMULE, voir disclosure ci-dessous), getprotobyname/
getprotobynumber.

Verification du resultat : la ligne "ARRET : DosExit(action=0,
code=16909060)" signale un succes total - 16909060 = $01020304, le
resultat d'un aller-retour PUR ntohl(htonl($01020304)) qui doit
reproduire exactement la valeur de depart, sans aucune dependance
reseau/hote (le signal le plus simple et le plus deterministe de ce
fichier). Un code different indique un probleme dans HTONL ou NTOHL.

3 DosWrite ponctuent l'execution et s'affichent directement dans le
Terminal, chacun une preuve visuelle independante :
  - "127.0.0.1" (9 octets) : aller-retour inet_addr -> inet_ntoa, donc
    marshaling correct d'une chaine fraichement allouee dans le tas
    invite (pointeur hote jamais dereference directement par le
    programme invite).
  - "unit-test-host" (14 octets) : aller-retour sethostname ->
    gethostname, donc l'etat simule (Os2SimHostName) est bien relu par
    un appel SUBSEQUENT du MEME programme.
  - "example.test" (12 octets) : idem pour setdomainname ->
    getdomainname (Os2SimDomainName).

Disclosure (voir aussi les commentaires DEVENV.PAS) : sethostname/
setdomainname ne touchent JAMAIS au vrai systeme d'exploitation hote -
etat purement simule, en memoire, reinitialise a chaque relancement de
l'emulateur. inet_network/inet_lnaof/inet_netof/inet_makeaddr
n'existent PAS dans Winsock (fonctions BSD historiques) - reimplantees
en Pascal pur d'apres l'algorithme de classes d'adresse A/B/C standard
(aucun appel reseau necessaire, arithmetique pure).

TCPEXT.EXE - socketpair/fcntl/sendmsg/recvmsg (les 4 dernieres)
--------------------------------------------------------------------
Cree une VRAIE paire de sockets 127.0.0.1 connectes entre eux
(socketpair emule via boucle locale reelle, AUCUN domaine AF_UNIX natif
sous Winsock - voir disclosure DEVENV.PAS), pose le mode non bloquant
sur l'un des deux (fcntl F_SETFL/O_NONBLOCK) puis le RELIT (fcntl
F_GETFL) pour prouver que l'etat est bien conserve cote emulateur
(Winsock seul ne permet pas de relire cet etat - table dediee
Os2FcntlNbSock/Flag), puis envoie "HI!" via sendmsg (UN SEUL iovec, pas
de vraie dispersion multi-tampons) et le recoit via recvmsg a l'AUTRE
bout de la MEME paire reelle.

Verification du resultat : "ARRET : DosExit(action=0, code=3)" signale
un succes total (recvmsg a recu exactement les 3 octets envoyes par
sendmsg, a travers un vrai socket). Un DosWrite affiche directement
"HI!" dans le Terminal juste avant - 2e preuve, visuelle et
independante, du bon fonctionnement de la chaine complete
socketpair->fcntl->sendmsg->recvmsg.

CE QUI N'A PU ETRE VERIFIE DANS CET ENVIRONNEMENT
--------------------------------------------------------------------
Memes limites que TESTS/OS2EMU/README_MPTS.txt : l'execution reelle EN
DIRECT dans l'IDE DEVENV (LXSTEP) n'a pas pu etre lancee depuis cet
environnement (IDE plein ecran sans mode de commande automatise). La
verification ci-dessus couvre l'integralite du format conteneur LX
(en-tete/objets/pages/fixups/imports, via VERIFYLX2.PAS) et la
correction de chaque instruction x86 emise (relue et recoupee champ par
champ contre le code source reel de Lx_DoDosCall), mais pas le
comportement du decodeur Lx_Step lui-meme sur ces octets precis. A
faire manuellement : charger chaque .EXE via LXSTEP et lire le resultat
affiche.

Fichiers de ce dossier
--------------------------------------------------------------------
TCPCONV.EXE / TCPEXT.EXE : les executables LX de test.
BUILDLX2.PAS : le generateur (FPC, {$MODE OBJFPC}) - reconstruit les 2
  .EXE depuis zero (`fpc BUILDLX2.PAS && BUILDLX2 .`).
VERIFYLX2.PAS : le harnais de verification independant (FPC) - accepte
  un nombre quelconque de chemins en argument (`fpc VERIFYLX2.PAS &&
  VERIFYLX2 TCPCONV.EXE TCPEXT.EXE`).
