TESTS/OS2EMU - Verification de LAN (NETAPI.DLL, API "LAN Server" d'OS/2)
========================================================================

Contexte
--------
Demande explicite de l'utilisateur (2026-10-11, meme journee que
README_MPTS.txt/README_BSD_SOCKETS.txt/README_IBM_TCPIP.txt) :
  1. Ajouter dans Options > Emulateur > OS/2 une 4e case a cocher "LAN"
     (cochee par defaut), activant/desactivant le point 2.
  2. Implementer l'API LAN Server fournie (NETAPI.DLL, 33 fonctions :
     NetServerEnum/GetInfo/SetInfo, NetShareEnum/GetInfo/SetInfo/Add/
     Del, NetSessionEnum/GetInfo/Del, NetWkstaGetInfo/SetInfo,
     NetUseEnum/GetInfo/Add/Del, NetAccessGetInfo/SetInfo,
     NetUserEnum/GetInfo/Add/Del/SetInfo, NetGroupEnum/GetInfo/Add/Del/
     AddUser/DelUser, NetMessageNameAdd/Del/Enum,
     NetMessageBufferSend, NetRemoteTOD).
  3. Creer les tests necessaires dans TESTS/OS2EMU/.

NETAPI.DLL est PARTAGE avec les 4 fonctions NetBios/NetBiosOpen/
NetBiosSubmit/NetBiosEnum deja implantees (chantier anterieur, voir
project_devenv_dosemu.md-style NetBIOS) - meme nom de DLL historiquement
mais concept totalement DIFFERENT (transport reseau bas niveau vs
administration de serveur de fichiers/utilisateurs) : la case "LAN" gate
UNIQUEMENT les 33 nouvelles fonctions, les 4 fonctions NetBios* restent
INCHANGEES et toujours actives (meme discipline que MPTS/BSD Sockets,
voir feedback_dont_merge_distinct_gates.md).

Difference avec TCPIP32/RPC32DLL : heritage Win32 DIRECT, mais un vrai
garde-fou de securite necessaire
--------------------------------------------------------------------
Contrairement a RPC32DLL (aucun equivalent Win32), l'API LAN Manager
d'OS/2 (NETAPI.DLL) est l'ANCETRE DIRECT de l'API LAN Manager de
Windows (netapi32.dll) - memes noms de fonctions, meme famille de
structures "niveau d'information", heritage documente publiquement. Les
11 fonctions LECTURE SEULE les plus utiles sont donc REELLEMENT pontees
vers le VRAI netapi32.dll de la machine hote : un programme OS/2 invite
voit alors les VRAIS partages/utilisateurs/groupes/sessions de LA
MACHINE HOTE ELLE-MEME (conversion UTF-16->ASCII simplifiee - octet bas
de chaque caractere large, les noms non-ASCII seraient tronques/
deformes, cas rare en pratique).

MAIS : 22 des 33 fonctions sont des MUTATEURS (NetUserAdd/Del/SetInfo,
NetGroupAdd/Del/AddUser/DelUser, NetShareAdd/Del/SetInfo,
NetServerSetInfo, NetAccessSetInfo, NetWkstaSetInfo,
NetMessageNameAdd/Del, NetMessageBufferSend) qui, si elles etaient
REELLEMENT appliquees au vrai netapi32.dll, CREERAIENT/SUPPRIMERAIENT/
MODIFIERAIENT de VRAIS comptes utilisateur, groupes ou partages de
fichiers sur la machine hote - un risque de securite bien plus serieux
que renommer l'hote (deja refuse pour sethostname/setdomainname, voir
project_devenv_os2_bsdsockets.md). CES 22 FONCTIONS SONT DONC TOUJOURS
REFUSEES PROPREMENT (ERROR_NOT_SUPPORTED=50), QUELLE QUE SOIT LA CASE
"LAN" - rien dans ce chantier ne touche JAMAIS a un compte utilisateur,
un groupe ou un partage reel de la machine hote. 2 fonctions
supplementaires (NetAccessGetInfo, NetMessageNameEnum) n'ont plus
d'equivalent sur un Windows moderne (securite "niveau partage" LAN
Manager et service Messenger, tous deux retires depuis longtemps) et
sont refusees pour la meme raison honnete.

Convention d'appel NON verifiee
--------------------------------------------------------------------
Aucune source primaire (en-tete OS/2 NETAPI.H reel) n'est disponible
pour verifier l'ordre exact des parametres des fonctions 16/32 bits
OS/2 historiques - une convention raisonnable et AUTO-COHERENTE a donc
ete choisie (voir le commentaire de tete du branchement NETAPI dans
Lx_DoDosCall) : Enum(pszServer,pBuffer,cbBuffer,pcEntriesRead,
pcTotalEntries) 5 arguments ; GetInfo-par-nom(pszServer,pszNom,
pBuffer,cbBuffer,pcBytesNeeded) 5 arguments ; GetInfo-singulier
(pszServer,pBuffer,cbBuffer,pcBytesNeeded) 4 arguments - pszServer
TOUJOURS ignore (les fonctions reelles rapportent toujours les
donnees de LA machine hote elle-meme). LANTEST.EXE respecte cette
meme convention des deux cotes.

--------------------------------------------------------------------
LANTEST.EXE - les 11 fonctions reelles + 2 mutateurs refuses
--------------------------------------------------------------------
Exerce NetWkstaGetInfo, NetServerGetInfo, NetShareEnum, NetShareGetInfo
("IPC$", partage administratif quasi universel sous Windows),
NetUserEnum, NetUserGetInfo (reutilise directement le pointeur du 1er
utilisateur enumere - pas besoin de connaitre un nom de compte a la
construction), NetGroupEnum, NetGroupGetInfo (idem, 1er groupe
enumere), NetSessionEnum, NetUseEnum, NetRemoteTOD, PUIS NetShareDel
("IPC$") et NetUserAdd - ces 2 derniers etant les mutateurs REFUSES.

Executer : `LXSTEP TESTS\OS2EMU\LANTEST.EXE C8` (voir
README_MPTS.txt pour la syntaxe complete).

Verification du resultat : "ARRET : DosExit(action=0, code=50)" signale
un succes total - 50 = ERROR_NOT_SUPPORTED, le resultat de NetUserAdd
(le DERNIER appel avant DosExit). Ce code est **garanti identique sur
n'importe quelle machine**, contrairement aux 11 appels reels qui le
precedent (dont le resultat depend legitimement de l'etat de la
machine hote - nombre reel de partages/utilisateurs/groupes/sessions,
eventuel ERROR_ACCESS_DENIED(5) sur NetSessionEnum sans privilege
eleve) : c'est delibere, NetUserAdd est le signal le PLUS simple et le
PLUS deterministe de ce fichier, et surtout celui qui compte le plus -
il prouve que le garde-fou de securite fonctionne reellement, partout,
tout le temps. Un code different de 50 serait un signal d'alarme
serieux (le garde-fou aurait ete contourne). Tous les 16 resultats
intermediaires (R0-R15) restent stockes dans le bloc de donnees
D_RESULTS pour inspection future.

CE QUI N'A PU ETRE VERIFIE DANS CET ENVIRONNEMENT
--------------------------------------------------------------------
Memes limites que les README precedents de ce dossier : l'execution
reelle EN DIRECT dans l'IDE DEVENV (LXSTEP) n'a pas pu etre lancee
depuis cet environnement. La verification effectuee couvre
l'integralite du format conteneur LX (en-tete/objets/pages/fixups/
imports, via VERIFYLX.PAS - "TOUTES LES VERIFICATIONS ONT REUSSI" pour
LANTEST.EXE) et la correction de chaque instruction x86 emise, mais pas
le comportement du decodeur Lx_Step lui-meme sur ces octets precis, ni
le resultat REEL des 11 appels en lecture seule (qui depend entierement
de l'etat de la machine qui executera le test - disclosure ci-dessus).

Fichiers de ce dossier (LAN)
--------------------------------------------------------------------
LANTEST.EXE : l'executable LX de test.
BUILDLX.PAS : etendu (5e procedure BuildLanTest) avec la meme
  infrastructure generique que les 4 fichiers precedents.
