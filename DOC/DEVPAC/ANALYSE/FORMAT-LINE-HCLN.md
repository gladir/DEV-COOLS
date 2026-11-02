# Informations de ligne dans l'executable Atari (OPT LINE / OPT HCLN) - format retenu par l'assembleur (asm)

Le manuel Devpac 3 (p.118-119) ne specifie pas le format Atari : « OPT LINE = section de debug LINE (8 octets par ligne
generant du code), OPT HCLN = lignes compressees (~2 octets par ligne) ». Format retenu : LINE = style Lattice (paires
numero de ligne / adresse sur 32 bits = 8 octets par ligne), HCLN = format compact propre a ce projet.

## Emplacement dans le fichier .PRG
Fichier GEMDOS normal : en-tete 28 octets ($601A, TEXT, DATA, BSS, SYMBOLES, 0, flags, 0), TEXT, DATA, table des symboles
DRI (SS octets), table de relocation. La section de lignes est ajoutee APRES la fin de la table de relocation (les chargeurs
GEMDOS ignorent tout ce qui suit le 0 terminal). Pour la trouver : fin = 28+TEXT+DATA+SS ; si le long en `fin` vaut 0,
la table est vide et occupe 4 octets ; sinon c'est un long (premier offset) suivi d'octets, jusqu'a l'octet 0 inclus.
Juste apres : eventuellement la section 'LINE' et/ou la section 'HCLN' (les deux si les deux options sont actives), l'une
derriere l'autre. Toutes les valeurs sont en gros-boutiste (big endian).

Chaque section : 4 octets de magie ASCII ('LINE' ou 'HCLN'), puis un long = longueur en octets de la charge utile, puis la
charge utile. Pour sauter une section inconnue : lire magie + longueur.

## Adresses
Toutes les adresses de ces tables sont des DEPLACEMENTS par rapport au debut du segment TEXT du programme
(adresse = deplacement + base de chargement du TEXT ; le DATA suit le TEXT a TEXT arrondi au pair, comme dans les symboles).
Seules les lignes qui generent du code ou des donnees en TEXT ou DATA sont presentes (pas BSS, pas OFFSET, pas ORG).
Le numero de ligne est celui de la ligne source du fichier d'origine (1 = premiere ligne) ; une ligne issue d'une macro ou
d'un REPT recoit le numero de la ligne qui l'a appelee (macro) ou de la ligne du corps (REPT), dans le fichier courant.

## Section 'LINE' (charge utile)
Repetee pour chaque fichier source (le fichier principal puis les INCLUDE rencontres, dans l'ordre de premiere apparition) :
  long  n          longueur du nom en longs (nom = octets ASCII termines par des 0, complete a un multiple de 4)
  n*4 octets       nom du fichier (tel qu'ecrit dans la ligne de commande / le INCLUDE resolu ; sans normalisation)
  long  count      nombre de paires
  count * { long ligne ; long deplacement }   triees par deplacement croissant (une meme ligne peut apparaitre plusieurs fois)
La charge utile se termine apres le dernier fichier (longueur donnee par l'en-tete de section).

## Section 'HCLN' (charge utile), flux d'enregistrements
  octet 0x00                     fin
  octet 0x01, octet L, L octets  debut d'un fichier (nom ASCII, sans zero final) ; remet l'adresse et la ligne courantes a 0
  octet 0x02, mot N              N entrees (N <= 65535) pour le fichier courant, triees par deplacement croissant
Chaque entree (deux champs, 2 octets dans le cas courant) :
  A : octet = delta de deplacement par rapport a l'entree precedente du fichier (premiere entree : par rapport a 0)
      0..250 = delta direct ; 251 = delta sur un mot (2 octets suivants) ; 252 = delta sur un long (4 octets suivants)
  B : octet signe = delta de numero de ligne par rapport a l'entree precedente (premiere : par rapport a 0)
      -127..127 = delta direct ; 0x80 = delta sur un long signe (4 octets suivants)
  (ordre des octets de l'entree : A [extension de A] B [extension de B])
Une entree peut se repeter pour un meme deplacement avec lignes differentes (delta A = 0).
