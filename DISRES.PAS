{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Desassembleur de fichiers .RES (ressources Windows 16 bits et 32 bits)
                genere un fichier de sortie .RC (script ressource) et
                extrait les ressources binaires (icones, curseurs, bitmaps)
  @license: MIT
}

(* ============================================================
  DISRES.PAS - Desassembleur de fichiers .RES vers .RC
  Free Pascal (-Mtp)

  Supporte :
    - Format RES 16 bits (Windows 3.x, Borland Pascal 7.x, Turbo Pascal pour Windows)
    - Format RES 32 bits (Windows NT/9x+, MSVC, Delphi, Free Pascal/windres)

  Usage :
    DISRES fichier.res [-o sortie.rc] [-16|-32] [-v] [-h]

  Options :
    -o nom    : specifier le nom du fichier de sortie .RC
    -16       : forcer la lecture en format 16 bits
    -32       : forcer la lecture en format 32 bits
    -v        : mode verbeux (afficher details des ressources)
    -h        : afficher l aide

  Voir DOC/RES_FORMAT.txt pour la description complete du format .RES.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
            DISRES_VERSION ('1.0') et DISRES_DATE ('2026-03-25')
            {$A-} pour desactiver l alignement automatique des records
            TOptions : SrcFile (String), OutFile (String),
              Force16 (Boolean), Force32 (Boolean),
              Verbose (Boolean), ExtractBin (Boolean)
            Constantes de codes de retour : EXIT_OK = 0, EXIT_ERROR = 1,
              EXIT_USAGE = 2
            Constantes de format : FMT_UNKNOWN = 0, FMT_RES16 = 1,
              FMT_RES32 = 2
            Constantes de tailles internes : MAX_RESOURCES = 4096,
              MAX_STRINGS = 4096, MAX_ACCEL = 256,
              MAX_MENU_ITEMS = 512, MAX_DIALOG_CTRL = 256
            Procedure FatalError(Msg: String) : afficher l erreur et
              appeler Halt(EXIT_ERROR)
            Procedure ParseCommandLine(Var Opts: TOptions) :
              analyser ParamStr(1..ParamCount), detecter les options
              -o / -16 / -32 / -v / -h / --help, valider que SrcFile
              est fourni et se termine par .res ou .RES
            Procedure ShowHelp : afficher la syntaxe, les options et
              la version, puis quitter avec EXIT_OK
            Afficher la banniere de version au demarrage

  TODO 02 - FONCTIONS UTILITAIRES [IMPLEMENTE]
            Function HexByte(B: Byte): String
              retourne la representation hexadecimale sur 2 chiffres
            Function HexWord(W: Word): String
              retourne la representation hexadecimale sur 4 chiffres
            Function HexDWord(D: LongInt): String
              retourne la representation hexadecimale sur 8 chiffres
            Function IntToStr(N: LongInt): String
              convertit un entier en chaine decimale
            Function UpCaseStr(Const S: String): String
              convertir une chaine en majuscules
            Function Trim(Const S: String): String
              supprimer les espaces de debut et de fin
            Function FileExists(Const FName: String): Boolean
              verifier l existence d un fichier
            Function ChangeFileExt(Const FName, NewExt: String): String
              remplacer l extension d un nom de fichier
            Function PadLeft(Const S: String; Width: Integer): String
              completer a gauche avec des espaces
            Function WCharToChar(W: Word): Char
              convertir un WCHAR Unicode en Char Latin-1 (best-effort)
            Function UniStrToStr(Const Buf: Array Of Word;
              Len: Integer): String
              convertir un tableau de WCHAR en String Pascal
            Function EscapeRCString(Const S: String): String
              echapper les caracteres speciaux pour le format RC
              (guillemets -> \", backslash -> \\, tabulation -> \t,
              retour chariot -> \n)
            Function FormatID(ID: LongInt; Const Name: String): String
              si Name <> '' : retourner Name entre guillemets
              sinon : retourner IntToStr(ID)

  TODO 03 - LECTURE BINAIRE DU FICHIER .RES [IMPLEMENTE]
            Variables globales : ResFile (File Of Byte),
              ResFileName (String), ResFileSize (LongInt),
              ResFilePos (LongInt)
            Procedure OpenResFile(Const FName: String)
              ouvrir le fichier binaire en lecture ({$I-}/{$I+}),
              gerer l erreur si le fichier n existe pas,
              lire ResFileSize (Seek vers la fin puis revenir),
              reinitialiser ResFilePos := 0
            Procedure CloseResFile
              fermer le fichier ResFile
            Function ReadByte: Byte
              lire un octet depuis ResFile, incrementer ResFilePos,
              lever FatalError si EOF inattendu
            Function ReadWord: Word
              lire 2 octets little-endian (Lo + Hi * 256)
            Function ReadDWord: LongInt
              lire 4 octets little-endian
            Function ReadWChar: Word
              lire un WCHAR (2 octets little-endian = ReadWord)
            Procedure SkipBytes(N: LongInt)
              avancer de N octets sans lire le contenu
              (utiliser Seek pour efficacite si N > 64)
            Function GetResPos: LongInt
              retourner ResFilePos courant
            Procedure SeekResPos(Pos: LongInt)
              se deplacer a la position Pos dans le fichier
            Function ResEOF: Boolean
              retourner True si ResFilePos >= ResFileSize
            Procedure AlignResPos(Align: Byte)
              aligner ResFilePos sur un multiple de Align
              (2 pour format 16 bits, 4 pour format 32 bits)

  TODO 04 - DETECTION DU FORMAT 16 OU 32 BITS [IMPLEMENTE]
            Function DetectResFormat: Integer
              lire les 8 premiers octets sans consommer le flux
              (sauvegarder la position, lire, puis revenir)
              Critere format 32 bits : les 4 premiers DWORD correspondent
              a la ressource nulle (DataSize=0, HeaderSize=32,
              Type=0x0000FFFF, Name=0x0000FFFF)
              Critere format 16 bits : le premier WORD est un identifiant
              de type connu (0x8001..0x800F ou un offset de chaine)
              Si le critere 32 bits est satisfait : retourner FMT_RES32
              Si le critere 16 bits est satisfait : retourner FMT_RES16
              Sinon : retourner FMT_UNKNOWN (format non reconnu)
              Si Opts.Force16 = True : retourner FMT_RES16
              Si Opts.Force32 = True : retourner FMT_RES32
            Procedure CheckResFormat(Var ResFormat: Integer)
              appeler DetectResFormat, afficher le format detecte
              si Verbose, lever FatalError si FMT_UNKNOWN

  TODO 05 - PARSING DE L'EN-TETE RESSOURCE 16 BITS [IMPLEMENTE]
            Type TResHeader16 : record
              TypeId   : Word    (type numerique, bit 15 = 1 si numerique)
              TypeName : String  (chaine Pascal si bit 15 = 0, vide sinon)
              NameId   : Word    (identifiant numerique ou 0)
              NameStr  : String  (chaine Pascal si bit 15 = 0, vide sinon)
              DataSize : LongInt (taille des donnees)
              Attribs  : Word    (attributs memoire)
              Reserved : Word    (reserve = 0)
              NameLen  : Word    (longueur du nom, optionnel)
              DataOfs  : LongInt (position du debut des donnees)
            End
            Function ReadPascalString: String
              lire une chaine Pascal (1 octet longueur + chars)
              alignement sur 2 octets apres la chaine
            Procedure ReadResHeader16(Var Hdr: TResHeader16)
              lire le type (WORD), si bit 15 = 1 : TypeId := W and $7FFF,
              sinon lire une chaine Pascal comme TypeName
              lire l identifiant (WORD), meme logique pour NameId/NameStr
              lire DataSize (DWORD), Attribs (WORD), Reserved (WORD)
              aligner sur 2 octets, enregistrer DataOfs := GetResPos
            Function IsLastResHeader16: Boolean
              retourner True si le WORD courant = $0000 (marqueur de fin)

  TODO 06 - PARSING DE L'EN-TETE RESSOURCE 32 BITS [IMPLEMENTE]
            Type TResHeader32 : record
              DataSize    : LongInt (taille des donnees en octets)
              HeaderSize  : LongInt (taille de l en-tete, variable)
              TypeIsId    : Boolean (True si type numerique)
              TypeId      : Word    (identifiant de type si TypeIsId)
              TypeName    : String  (nom Unicode si Non TypeIsId)
              NameIsId    : Boolean (True si nom numerique)
              NameId      : Word    (identifiant de nom si NameIsId)
              NameStr     : String  (nom Unicode si Non NameIsId)
              DataVersion : LongInt (version des donnees)
              MemFlags    : Word    (attributs memoire)
              LangId      : Word    (identifiant de langue)
              Version     : LongInt (version utilisateur)
              Characteristics : LongInt (caracteristiques utilisateur)
              DataOfs     : LongInt (position des donnees dans le fichier)
            End
            Function ReadUnicodeString: String
              lire une chaine Unicode UTF-16LE terminee par WCHAR $0000
              convertir chaque WCHAR en Char Latin-1 via WCharToChar
              retourner la chaine Pascal resultante
            Procedure ReadIdOrName(Var IsId: Boolean; Var Id: Word;
              Var Name: String)
              lire le premier WORD : si = $FFFF, lire un WORD Id (IsId=True)
              sinon pusher le WORD comme premier char de la chaine Unicode
              et appeler ReadUnicodeString pour le reste (IsId=False)
            Procedure ReadResHeader32(Var Hdr: TResHeader32)
              lire DataSize (DWORD), HeaderSize (DWORD)
              appeler ReadIdOrName pour TypeIsId/TypeId/TypeName
              appeler ReadIdOrName pour NameIsId/NameId/NameStr
              aligner sur 4 octets (padding apres Type+Name)
              lire DataVersion, MemFlags, LangId, Version, Characteristics
              enregistrer DataOfs := GetResPos
            Procedure ReadNullHeader32
              valider et ignorer la ressource nulle de 32 octets

  TODO 07 - TABLE DES TYPES DE RESSOURCES [RT_*] [IMPLEMENTE]
            Constantes des types standards :
              RT_CURSOR = 1, RT_BITMAP = 2, RT_ICON = 3,
              RT_MENU = 4, RT_DIALOG = 5, RT_STRING = 6,
              RT_FONTDIR = 7, RT_FONT = 8, RT_ACCELERATOR = 9,
              RT_RCDATA = 10, RT_MESSAGETABLE = 11,
              RT_GROUP_CURSOR = 12, RT_GROUP_ICON = 14,
              RT_VERSION = 16, RT_DLGINCLUDE = 17,
              RT_PLUGPLAY = 19, RT_VXD = 20,
              RT_ANICURSOR = 21, RT_ANIICON = 22,
              RT_HTML = 23, RT_MANIFEST = 24,
              RT_TOOLBAR = 241
            Function ResourceTypeName(TypeId: Word): String
              retourner le nom symbolique RT_xxx correspondant
              ex. 1 -> 'RT_CURSOR', 3 -> 'RT_ICON'
              retourner 'RT_UNKNOWN_' + IntToStr(TypeId) si inconnu
            Function ResourceTypeKeyword(TypeId: Word): String
              retourner le mot-cle RC correspondant pour la generation
              ex. 3 -> 'ICON', 2 -> 'BITMAP', 4 -> 'MENU',
              5 -> 'DIALOG', 9 -> 'ACCELERATORS',
              10 -> 'RCDATA', 16 -> 'VERSIONINFO'
            Function ResourceFileExt(TypeId: Word): String
              retourner l extension du fichier extrait
              ex. 3 -> '.ico', 1 -> '.cur', 2 -> '.bmp',
              8 -> '.fnt', 24 -> '.xml', autres -> '.bin'

  TODO 08 - DECODAGE DE LANGUAGE ID [IMPLEMENTE]
            Constantes de langues courantes :
              LANG_NEUTRAL         = $0000,
              LANG_ENGLISH_US      = $0409,
              LANG_ENGLISH_UK      = $0809,
              LANG_FRENCH          = $040C,
              LANG_FRENCH_BELGIUM  = $080C,
              LANG_FRENCH_CANADA   = $0C0C,
              LANG_GERMAN          = $0407,
              LANG_ITALIAN         = $0410,
              LANG_SPANISH         = $0C0A,
              LANG_PORTUGUESE_BR   = $0416,
              LANG_PORTUGUESE_PT   = $0816,
              LANG_RUSSIAN         = $0419,
              LANG_JAPANESE        = $0411,
              LANG_CHINESE_SIMPL   = $0804,
              LANG_CHINESE_TRAD    = $0404
            Function LangIdToStr(LangId: Word): String
              retourner la description textuelle de l identifiant de langue
              ex. $0409 -> 'ENGLISH, AMERICAN'
              ex. $040C -> 'FRENCH'
              ex. $0000 -> 'NEUTRAL'
              retourner 'LANG_' + HexWord(LangId) si inconnu
            Function LangIdToRCKeyword(LangId: Word): String
              retourner la directive LANGUAGE du format RC
              ex. $0409 -> 'LANGUAGE LANG_ENGLISH, SUBLANG_ENGLISH_US'
              ex. $040C -> 'LANGUAGE LANG_FRENCH, SUBLANG_FRENCH'
              ex. $0000 -> 'LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL'

  TODO 09 - DECODAGE DES FLAGS MEMOIRE [IMPLEMENTE]
            Constantes de flags memoire 16 bits :
              MF_MOVEABLE    = $0010,
              MF_PURE        = $0020,
              MF_PRELOAD     = $0040,
              MF_DISCARDABLE = $1000,
              MF_FIXED       = $0000
            Constantes de flags memoire 32 bits :
              MF32_MOVEABLE    = $0010,
              MF32_PURE        = $0020,
              MF32_PRELOAD     = $0040,
              MF32_DISCARDABLE = $1000,
              MF32_SHARED      = $0030
            Function MemFlagsToStr(Flags: Word): String
              retourner la liste des flags separes par ' | '
              ex. $0030 -> 'MOVEABLE | PURE'
              ex. $1030 -> 'MOVEABLE | PURE | DISCARDABLE'
              retourner 'FIXED' si Flags = 0
            Function MemFlagsToRCOptions(Flags: Word): String
              retourner les options RC correspondantes pour la directive
              de ressource : 'DISCARDABLE', 'MOVEABLE', 'PRELOAD'
              en les separant par des espaces
              utilise pour annoter la ligne de declaration de ressource

  TODO 10 - TABLE DES RESSOURCES (COLLECTE) [IMPLEMENTE]
            Type TResourceEntry : record
              ResFormat    : Integer   (FMT_RES16 ou FMT_RES32)
              TypeIsId     : Boolean   (True si type numerique)
              TypeId       : Word      (identifiant de type)
              TypeName     : String    (nom de type si Non TypeIsId)
              NameIsId     : Boolean   (True si nom numerique)
              NameId       : Word      (identifiant de nom)
              NameStr      : String    (nom si Non NameIsId)
              DataSize     : LongInt   (taille des donnees)
              DataOfs      : LongInt   (offset dans le fichier)
              MemFlags     : Word      (attributs memoire)
              LangId       : Word      (identifiant de langue, 0 si 16 bits)
            End
            Variables globales :
              Resources    : Array[1..MAX_RESOURCES] Of TResourceEntry
              ResCount     : Integer   (nombre de ressources collectees)
            Procedure CollectResources16
              boucle de lecture des en-tetes 16 bits jusqu a IsLastResHeader16
              ou EOF : lire chaque TResHeader16, remplir TResourceEntry,
              avancer de DataSize octets apres l en-tete
            Procedure CollectResources32
              lire et ignorer la ressource nulle, puis boucle jusqu a EOF :
              lire chaque TResHeader32, remplir TResourceEntry,
              avancer de DataSize octets, aligner sur 4 octets
            Procedure CollectResources(ResFormat: Integer)
              appeler CollectResources16 ou CollectResources32,
              afficher le nombre de ressources collectees si Verbose

  TODO 11 - DECODAGE RT_STRING (TYPE 6) [IMPLEMENTE]
            Type TStringEntry : record
              BlockId  : Word    (identifiant du bloc 1..N)
              Index    : Byte    (indice dans le bloc 0..15)
              StringId : Word    (= (BlockId-1)*16 + Index)
              Text     : String  (texte de la chaine)
            End
            Variables globales :
              StringEntries : Array[1..MAX_STRINGS] Of TStringEntry
              StringCount   : Integer
            Procedure ParseStringTable(Const Res: TResourceEntry)
              positionner le flux a Res.DataOfs (SeekResPos)
              pour i := 0 to 15 : lire WORD LenW (longueur en WCHARs)
              si LenW > 0 : lire LenW WCHARs, convertir en String,
              ajouter dans StringEntries
              StringId := (Res.NameId - 1) * 16 + i
            Procedure ParseAllStringTables
              parcourir Resources[], appeler ParseStringTable
              pour chaque ressource de TypeId = RT_STRING
            Function StringTableRC(Const Entry: TStringEntry): String
              retourner la ligne RC :
              '    ' + IntToStr(Entry.StringId) + ', "' +
              EscapeRCString(Entry.Text) + '"'

  TODO 12 - DECODAGE RT_ACCELERATOR (TYPE 9) [IMPLEMENTE]
            Type TAccelEntry : record
              fVirt  : Word   (drapeaux de l accelerateur)
              Key    : Word   (code de touche)
              Cmd    : Word   (identifiant de commande)
              IsLast : Boolean (True si bit 7 de fVirt est a 1)
            End
            Constantes fVirt :
              FVIRTKEY  = $01, FNOINVERT = $02, FSHIFT = $04,
              FCONTROL  = $08, FALT      = $10, FLAST   = $80
            Function VKeyToStr(Key: Word): String
              retourner le nom de la touche virtuelle :
              VK_BACK=$08->'VK_BACK', VK_TAB=$09->'VK_TAB',
              VK_RETURN=$0D->'VK_RETURN', VK_ESCAPE=$1B->'VK_ESCAPE',
              VK_SPACE=$20->'VK_SPACE', VK_END=$23->'VK_END',
              VK_HOME=$24->'VK_HOME', VK_LEFT=$25->'VK_LEFT',
              VK_UP=$26->'VK_UP', VK_RIGHT=$27->'VK_RIGHT',
              VK_DOWN=$28->'VK_DOWN', VK_DELETE=$2E->'VK_DELETE',
              VK_INSERT=$2D->'VK_INSERT', VK_F1=$70..'VK_F12'=$7B
              Si FVIRTKEY non actif : retourner '"' + Char(Key) + '"'
            Procedure ParseAccelerators(Const Res: TResourceEntry;
              Var Entries: Array Of TAccelEntry; Var Count: Integer)
              positionner le flux a Res.DataOfs, lire par groupes de 8 octets
              (fVirt WORD + key WORD + cmd WORD + padding WORD),
              IsLast := (fVirt and FLAST) <> 0, boucler jusqu a IsLast
            Function AccelEntryToRC(Const E: TAccelEntry): String
              '    ' + VKeyToStr(E.Key) + ', ' + IntToStr(E.Cmd) +
              options (NOINVERT, SHIFT, CONTROL, ALT, VIRTKEY) separes par ', '

  TODO 13 - DECODAGE RT_MENU (TYPE 4) [A FAIRE]
            Type TMenuItem : record
              Flags    : Word    (fItemFlags)
              MenuID   : Word    (identifiant ou 0 si popup)
              Text     : String  (texte Unicode converti)
              IsPopup  : Boolean (True si fItemFlags and $0020 <> 0)
              IsEnd    : Boolean (True si fItemFlags and $0080 <> 0)
              IsSep    : Boolean (True si fItemFlags and $0800 <> 0)
              IsLast   : Boolean (marque de fin du niveau courant)
            End
            Constantes fItemFlags :
              MF_GRAYED = $0001, MF_DISABLED = $0002,
              MF_BITMAP = $0008, MF_CHECKED = $0010,
              MF_POPUP  = $0020, MF_MENUBARBREAK = $0040,
              MF_MENUBREAK = $0080, MF_SEPARATOR = $0800,
              MF_END    = $0080
            Procedure ParseMenuItems(Level: Integer;
              Var Lines: Array Of String; Var LineCount: Integer)
              lire les elements de menu recursivement :
              lire fItemFlags (WORD), si Non IsPopup : lire MenuID (WORD)
              lire le texte Unicode termine par WCHAR $0000
              si IsPopup : ajouter 'POPUP "text"' + BEGIN + recurse + END
              si IsSep : ajouter 'MENUITEM SEPARATOR'
              sinon : ajouter 'MENUITEM "text", id [, options]'
              boucler jusqu a IsEnd pour le niveau courant
            Procedure ParseMenu(Const Res: TResourceEntry)
              positionner le flux, lire wVersion (WORD) et cbHeaderSize (WORD)
              si wVersion = 0 : menu standard, appeler ParseMenuItems(0)
              si wVersion = 1 : menu etendu MENUEX (stub : hex dump)
              stocker les lignes generees pour la phase de generation

  TODO 14 - DECODAGE RT_DIALOG (TYPE 5) [A FAIRE]
            Constantes de classes predefinies (atoms) :
              DC_BUTTON = $0080, DC_EDIT = $0081, DC_STATIC = $0082,
              DC_LISTBOX = $0083, DC_SCROLLBAR = $0084,
              DC_COMBOBOX = $0085
            Constantes de styles DS_* :
              DS_SETFONT = $0040, DS_MODALFRAME = $0080,
              DS_CENTER = $0800, DS_SYSMODAL = $0002
            Function WindowClassAtomToStr(Atom: Word): String
              retourner le nom de classe predefinit :
              $0080->'BUTTON', $0081->'EDIT', $0082->'STATIC',
              $0083->'LISTBOX', $0084->'SCROLLBAR', $0085->'COMBOBOX'
            Procedure ParseDialogStyles(Style: LongInt;
              Var StyleStr: String)
              construire la chaine de styles WS_*/DS_* (combinaisons
              via '|') pour la directive STYLE du .RC
            Procedure ParseDialogTemplate(Const Res: TResourceEntry)
              positionner le flux, lire style (DWORD), exStyle (DWORD),
              cdit (WORD), x (Word), y (Word), cx (Word), cy (Word)
              lire menu (ReadIdOrName), windowClass (ReadIdOrName),
              title (ReadUnicodeString)
              si style and DS_SETFONT : lire pointSize (WORD),
              typeface (ReadUnicodeString)
              pour chaque controle : aligner sur 4 octets,
              lire style, exStyle, x, y, cx, cy, id,
              windowClass (ReadIdOrName), title (ReadIdOrName),
              extraCount (WORD), sauter extraCount octets
              stocker les lignes de dialogue generees

  TODO 15 - DECODAGE RT_VERSION (TYPE 16) [A FAIRE]
            Constantes VS_FIXEDFILEINFO :
              VS_FFI_SIGNATURE = $FEEF04BD
            Constantes VFT_* (dwFileType) :
              VFT_UNKNOWN = 0, VFT_APP = 1, VFT_DLL = 2,
              VFT_DRV = 3, VFT_FONT = 4, VFT_VXD = 5
            Constantes VOS_* (dwFileOS) :
              VOS_UNKNOWN = 0, VOS_NT_WINDOWS32 = $00040004
            Type TVersionInfo : record
              FileVersionMS : LongInt, FileVersionLS : LongInt,
              ProductVersionMS : LongInt, ProductVersionLS : LongInt,
              FileOS : LongInt, FileType : LongInt, FileSubtype : LongInt,
              FileFlags : LongInt, FileFlagsMask : LongInt,
              StringValues : Array[1..64] Of record
                Key : String; Value : String End,
              StringCount : Integer,
              TranslationLang : Word, TranslationCP : Word
            End
            Procedure ParseVSFixedFileInfo(Var Info: TVersionInfo)
              verifier la signature $FEEF04BD, lire les champs
              dwStrucVersion, dwFileVersionMS/LS, dwProductVersionMS/LS,
              dwFileFlagsMask, dwFileFlags, dwFileOS, dwFileType,
              dwFileSubtype, dwFileDateMS/LS
            Procedure ParseVersionStringBlock(Var Info: TVersionInfo)
              lire les blocs StringFileInfo recursivement :
              chaque entree : WORD wLength, WORD wValueLength, WORD wType,
              WCHAR[] szKey, padding DWORD, WCHAR[] value
            Procedure ParseVersionVarBlock(Var Info: TVersionInfo)
              lire le bloc VarFileInfo : WORD Translation, CP
            Procedure ParseVersionInfo(Const Res: TResourceEntry;
              Var Info: TVersionInfo)
              lire l en-tete VS_VERSIONINFO (wLength, wValueLength, wType,
              szKey = "VS_VERSION_INFO"), aligner sur 4 octets,
              appeler ParseVSFixedFileInfo, puis parser les blocs enfants
              StringFileInfo et VarFileInfo

  TODO 16 - DECODAGE RT_ICON / RT_CURSOR (TYPES 3 ET 1) [A FAIRE]
            Type TIconHeader : record
              Reserved : Word  (= 0)
              ResType  : Word  (1 = ICO, 2 = CUR)
              Count    : Word  (nombre d icones/curseurs dans le fichier)
            End
            Type TIconDirEntry : record
              Width    : Byte  (largeur en pixels, 0 = 256)
              Height   : Byte  (hauteur en pixels, 0 = 256)
              ColorCount : Byte (nombre de couleurs, 0 si >= 256)
              Reserved : Byte  (= 0)
              Planes   : Word  (pour ICO : 1; pour CUR : hotspot X)
              BitCount : Word  (bits par pixel; pour CUR : hotspot Y)
              BytesInRes : LongInt (taille des donnees DIB)
              ImageOffset : LongInt (offset dans le fichier .ico/.cur)
            End
            Procedure ReadRawResourceBytes(Const Res: TResourceEntry;
              Var Buf: PByteArray; Var BufSize: LongInt)
              allouer un tampon de Res.DataSize octets, se positionner
              a Res.DataOfs et lire tous les octets
            Procedure ExtractIconFile(Const Res: TResourceEntry;
              Const OutFile: String)
              les ressources RT_ICON individuelles contiennent un DIB brut
              construire un .ico minimal (TIconHeader + TIconDirEntry +
              donnees DIB) et ecrire le fichier
            Procedure ExtractCursorFile(Const Res: TResourceEntry;
              Const OutFile: String)
              similaire a ExtractIconFile pour les curseurs .cur

  TODO 17 - DECODAGE RT_BITMAP (TYPE 2) [A FAIRE]
            Constantes BITMAPINFOHEADER :
              BI_RGB = 0, BI_RLE8 = 1, BI_RLE4 = 2, BI_BITFIELDS = 3
            Type TBitmapFileHeader : record
              bfType      : Word    (= $4D42 = 'BM')
              bfSize      : LongInt (taille totale du fichier .bmp)
              bfReserved1 : Word    (= 0)
              bfReserved2 : Word    (= 0)
              bfOffBits   : LongInt (offset des donnees pixels)
            End
            Type TBitmapInfoHeader : record
              biSize          : LongInt (= 40)
              biWidth         : LongInt
              biHeight        : LongInt (positif = bas-en-haut)
              biPlanes        : Word    (= 1)
              biBitCount      : Word    (bits par pixel)
              biCompression   : LongInt (BI_RGB, BI_RLE8, etc.)
              biSizeImage     : LongInt (taille des donnees pixels)
              biXPelsPerMeter : LongInt
              biYPelsPerMeter : LongInt
              biClrUsed       : LongInt
              biClrImportant  : LongInt
            End
            Procedure ExtractBitmapFile(Const Res: TResourceEntry;
              Const OutFile: String)
              lire les donnees brutes (BITMAPINFOHEADER + palette + pixels)
              prepend un TBitmapFileHeader coherent (bfType='BM',
              bfOffBits = 14 + biSize + biClrUsed*4,
              bfSize = bfOffBits + biSizeImage),
              ecrire le fichier .bmp resultant
            Function BitmapInfoLine(Const Res: TResourceEntry): String
              retourner une chaine descriptive de la bitmap :
              'W=' + largeur + ' H=' + hauteur + ' BPP=' + biBitCount

  TODO 18 - DECODAGE RT_GROUP_ICON / RT_GROUP_CURSOR (TYPES 14 ET 12) [A FAIRE]
            Type TGrpIconDirEntry : record
              Width    : Byte
              Height   : Byte
              ColorCount : Byte
              Reserved : Byte
              Planes   : Word
              BitCount : Word
              BytesInRes : LongInt
              Id       : Word    (identifiant de la ressource RT_ICON/RT_CURSOR associee)
            End
            Procedure ParseGroupIcon(Const Res: TResourceEntry)
              lire TIconHeader (Reserved, ResType, Count),
              pour chaque entree : lire TGrpIconDirEntry (14 octets),
              enregistrer l association GroupIconId -> [Id1, Id2, ...]
              chaque Id correspond a une ressource RT_ICON individuelle
            Procedure BuildGroupIconFile(GroupId: Word;
              Const OutFile: String)
              assembler un fichier .ico complet en concatenant l en-tete
              de groupe et les donnees brutes des ressources RT_ICON
              individuelles dans l ordre de TGrpIconDirEntry,
              calculer les offsets absolus corrects
            Procedure ParseGroupCursor(Const Res: TResourceEntry)
              similaire a ParseGroupIcon pour RT_GROUP_CURSOR -> .cur

  TODO 19 - DECODAGE RT_RCDATA (TYPE 10) [A FAIRE]
            Constantes de formatage :
              RCDATA_BYTES_PER_LINE = 16
            Procedure ParseRCData(Const Res: TResourceEntry;
              Var Lines: Array Of String; Var LineCount: Integer)
              positionner le flux a Res.DataOfs
              pour chaque groupe de RCDATA_BYTES_PER_LINE octets :
              construire une ligne hex 'XXh, XXh, ...' (format MASM/RC)
              enregistrer dans Lines
              gerer le dernier groupe incomplet correctement
            Function RCDataToHexLine(Const Buf: Array Of Byte;
              Count, Offset: Integer): String
              convertir Count octets a partir de Buf[Offset] en une chaine
              de litteraux hexadecimaux separes par des virgules
              format : '0x' + HexByte(b) ou b + 'h' selon convention RC
            Procedure GenerateRCDataBlock(Const Res: TResourceEntry;
              ResId: String; Var OutLines: Array Of String;
              Var OutCount: Integer)
              generer le bloc RC complet :
              ResId + ' RCDATA BEGIN' / lignes hex / 'END'

  TODO 20 - DECODAGE RT_MANIFEST (TYPE 24) [A FAIRE]
            Type TManifestData : record
              Text     : Array[1..256] Of String  (lignes XML)
              LineCount : Integer
            End
            Procedure ParseManifest(Const Res: TResourceEntry;
              Var Data: TManifestData)
              positionner le flux, lire Res.DataSize octets comme UTF-8
              decoder les sequences multi-octets UTF-8 courantes
              (ASCII direct, $C2-$DF -> 2 octets, $E0-$EF -> 3 octets)
              decomposer en lignes (LF ou CR+LF comme separateur)
              stocker dans Data.Text
            Procedure GenerateManifestRef(Const Res: TResourceEntry;
              Const ManifestFile: String;
              Var OutLines: Array Of String; Var OutCount: Integer)
              option 1 : extraire le texte XML dans un fichier .xml
              et generer '1 RT_MANIFEST "fichier.xml"'
              option 2 (si manifest court) : inclure directement comme
              RCDATA avec commentaire '// Manifeste XML embarque'
            Procedure ExtractManifestFile(Const Res: TResourceEntry;
              Const OutFile: String)
              ecrire les octets bruts de la ressource dans un fichier .xml

  TODO 21 - GENERATION DE L'EN-TETE DU FICHIER .RC [A FAIRE]
            Procedure WriteRCHeader(Var OutFile: Text;
              Const SrcFileName: String; ResFormat: Integer)
              ecrire les commentaires d en-tete :
              '// Fichier .RC genere par DISRES version X.X'
              '// Source : ' + SrcFileName
              '// Format : RES ' + (16/32) + ' bits'
              '// Date   : ' + date de generation
              ligne vide
              ecrire '#include <windows.h>' si format 32 bits
              ecrire les includes Borland/Turbo si format 16 bits :
              '#include <wintypes.h>'
              ligne vide
              ecrire la section des identifies de commandes si presentes
              ('// Identifiants de commandes (a personaliser)')
              reperer les IDs de commandes dans les accelerateurs/menus
              et generer des '#define IDM_xxx NNN' correspondants
            Procedure WriteRCLanguageDirective(Var OutFile: Text;
              LangId: Word; ResFormat: Integer)
              si ResFormat = FMT_RES32 et LangId <> 0 :
              ecrire 'LANGUAGE ' + LangIdToRCKeyword(LangId)

  TODO 22 - GENERATION DES DIRECTIVES RC PAR TYPE [A FAIRE]
            Procedure WriteRCResource(Var OutFile: Text;
              Const Res: TResourceEntry)
              orchestrateur : appeler la procedure de generation
              appropriee selon Res.TypeId :
              RT_ICON (3)         -> WriteRCIcon
              RT_CURSOR (1)       -> WriteRCCursor
              RT_BITMAP (2)       -> WriteRCBitmap
              RT_MENU (4)         -> WriteRCMenu
              RT_DIALOG (5)       -> WriteRCDialog
              RT_STRING (6)       -> (gere globalement par WriteRCStringTable)
              RT_ACCELERATOR (9)  -> WriteRCAccelerators
              RT_RCDATA (10)      -> WriteRCRCData
              RT_VERSION (16)     -> WriteRCVersionInfo
              RT_MANIFEST (24)    -> WriteRCManifest
              RT_GROUP_ICON (14)  -> WriteRCGroupIcon
              RT_GROUP_CURSOR (12)-> WriteRCGroupCursor
              autres              -> WriteRCRawData (hexdump generique)
            Procedure GenerateRCFile(ResFormat: Integer)
              ouvrir OutFile en ecriture (Assign + Rewrite),
              appeler WriteRCHeader, puis WriteRCLanguageDirective,
              pour chaque ressource dans Resources[] appeler WriteRCResource,
              grouper toutes les RT_STRING dans un seul appel
              a WriteRCStringTable, fermer OutFile

  TODO 23 - EXTRACTION DES RESSOURCES BINAIRES [A FAIRE]
            Variables globales :
              ExtractDir  : String  (repertoire d extraction, './' par defaut)
              ExtractCount : Integer (nombre de fichiers extraits)
            Procedure BuildExtractPath(Const Res: TResourceEntry;
              Const Ext: String): String
              construire le chemin de sortie :
              ExtractDir + ResourceTypeKeyword(Res.TypeId) + '_' +
              FormatID(Res.NameId, Res.NameStr) + Ext
            Procedure ExtractAllBinaryResources
              pour chaque ressource :
              RT_ICON (3)     -> ExtractIconFile (si pas de groupe)
              RT_CURSOR (1)   -> ExtractCursorFile (si pas de groupe)
              RT_BITMAP (2)   -> ExtractBitmapFile
              RT_GROUP_ICON (14)  -> BuildGroupIconFile
              RT_GROUP_CURSOR (12)-> (groupes curseurs)
              RT_MANIFEST (24)    -> ExtractManifestFile
              RT_HTML (23)        -> ecrire octets bruts dans .html
              autres              -> ecrire octets bruts dans .bin
              incrementer ExtractCount a chaque fichier cree
              afficher le chemin du fichier extrait si Verbose
            Procedure WriteRawBytes(Const Res: TResourceEntry;
              Const OutPath: String)
              ouvrir un fichier binaire en ecriture, lire les octets de
              la ressource un par un et les ecrire, puis fermer

  TODO 24 - GENERATION STRINGTABLE ET ACCELERATORS [A FAIRE]
            Procedure WriteRCStringTable(Var OutFile: Text)
              si StringCount = 0 : ne rien ecrire
              regrouper les StringEntries par BlockId (blocs de 16)
              pour chaque bloc present :
              ecrire 'STRINGTABLE' + options MemFlags
              ecrire 'BEGIN'
              pour chaque chaine du bloc dans l ordre croissant de StringId :
              ecrire StringTableRC(Entry)
              ecrire 'END'
              ligne vide entre les blocs
            Procedure WriteRCAccelerators(Var OutFile: Text;
              Const Res: TResourceEntry)
              ecrire FormatID(Res.NameId, Res.NameStr) + ' ACCELERATORS'
              + MemFlagsToRCOptions(Res.MemFlags)
              ecrire 'BEGIN'
              appeler ParseAccelerators, pour chaque entree :
              ecrire AccelEntryToRC(Entry)
              ecrire 'END' + ligne vide
            Procedure WriteRCVersionInfo(Var OutFile: Text;
              Const Res: TResourceEntry)
              appeler ParseVersionInfo, generer :
              FormatID + ' VERSIONINFO'
              'FILEVERSION ' + version MS + ', ' + version LS
              'PRODUCTVERSION ' + product MS + ', ' + product LS
              'FILEFLAGSMASK ' + HexDWord
              'FILEFLAGS ' + HexDWord
              'FILEOS ' + HexDWord
              'FILETYPE ' + HexDWord
              'FILESUBTYPE ' + HexDWord
              'BEGIN' / blocs BLOCK et VALUE / 'END'

  TODO 25 - VERIFICATION ET RAPPORT FINAL [A FAIRE]
            Function GetFileSize(Const FName: String): LongInt
              ouvrir le fichier, chercher la fin, retourner la taille
            Procedure VerifyRCFile(Const OutFileName: String)
              verifier que OutFileName existe et n est pas vide
              ouvrir le fichier RC en lecture et compter les lignes
              verifier qu il ne contient pas de lignes malformees
              evidentes (BEGIN sans END correspondant par exemple)
              afficher un avertissement si des ressources n ont pas
              pu etre decodees (TypeId inconnu)
            Procedure DisplayFinalReport(Const Opts: TOptions;
              ResFormat: Integer)
              afficher le rapport complet :
              '=== DISRES - Rapport de desassemblage ==='
              'Fichier source  : ' + Opts.SrcFile
              'Format detecte  : RES ' + (16/32) + ' bits'
              'Ressources total: ' + IntToStr(ResCount)
              Pour chaque type RT_* present : compter et afficher
              '  RT_ICON       : N ressource(s)'
              '  RT_BITMAP     : N ressource(s)'
              '  RT_MENU       : N ressource(s)'
              '  RT_DIALOG     : N ressource(s)'
              '  RT_STRING     : N bloc(s), ' + IntToStr(StringCount) + ' chaine(s)'
              '  RT_ACCELERATOR: N table(s)'
              '  RT_VERSION    : N ressource(s)'
              '  RT_RCDATA     : N ressource(s)'
              '  RT_MANIFEST   : N ressource(s)'
              'Fichiers extraits: ' + IntToStr(ExtractCount)
              'Fichier RC genere: ' + Opts.OutFile
              'Taille RC        : ' + IntToStr(GetFileSize(Opts.OutFile)) + ' octets'
              Si Opts.Verbose : afficher le detail de chaque ressource
              (type, nom/ID, langue, taille, flags memoire)

*)

Program DISRES;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$A-}
{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  DISRES_VERSION = '1.0';
  DISRES_DATE    = '2026-03-25';

  { Codes de retour }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Formats de fichier .RES }
  FMT_UNKNOWN = 0;
  FMT_RES16   = 1;   { Windows 3.x / Borland Pascal 16 bits }
  FMT_RES32   = 2;   { Windows NT/9x+ 32 bits               }

  { Types de ressources standards (RT_*) }
  RT_CURSOR       = 1;
  RT_BITMAP       = 2;
  RT_ICON         = 3;
  RT_MENU         = 4;
  RT_DIALOG       = 5;
  RT_STRING       = 6;
  RT_FONTDIR      = 7;
  RT_FONT         = 8;
  RT_ACCELERATOR  = 9;
  RT_RCDATA       = 10;
  RT_MESSAGETABLE = 11;
  RT_GROUP_CURSOR = 12;
  RT_GROUP_ICON   = 14;
  RT_VERSION      = 16;
  RT_DLGINCLUDE   = 17;
  RT_PLUGPLAY     = 19;
  RT_VXD          = 20;
  RT_ANICURSOR    = 21;
  RT_ANIICON      = 22;
  RT_HTML         = 23;
  RT_MANIFEST     = 24;
  RT_TOOLBAR      = 241;

  { Identifiants de langue (LANG_*) }
  LANG_NEUTRAL         = $0000;
  LANG_ENGLISH_US      = $0409;
  LANG_ENGLISH_UK      = $0809;
  LANG_FRENCH          = $040C;
  LANG_FRENCH_BELGIUM  = $080C;
  LANG_FRENCH_CANADA   = $0C0C;
  LANG_GERMAN          = $0407;
  LANG_ITALIAN         = $0410;
  LANG_SPANISH         = $0C0A;
  LANG_PORTUGUESE_BR   = $0416;
  LANG_PORTUGUESE_PT   = $0816;
  LANG_RUSSIAN         = $0419;
  LANG_JAPANESE        = $0411;
  LANG_CHINESE_SIMPL   = $0804;
  LANG_CHINESE_TRAD    = $0404;

  { Flags memoire 16 bits (format Windows 3.x) }
  MF_FIXED       = $0000;
  MF_MOVEABLE    = $0010;
  MF_PURE        = $0020;
  MF_PRELOAD     = $0040;
  MF_DISCARDABLE = $1000;

  { Flags memoire 32 bits (format Win32) }
  MF32_MOVEABLE    = $0010;
  MF32_PURE        = $0020;
  MF32_PRELOAD     = $0040;
  MF32_DISCARDABLE = $1000;
  MF32_SHARED      = $0030;

  { Drapeaux fVirt pour les accelerateurs (RT_ACCELERATOR) }
  FVIRTKEY  = $01;   { touche virtuelle                    }
  FNOINVERT = $02;   { ne pas inverser la barre de menu    }
  FSHIFT    = $04;   { modificateur SHIFT                  }
  FCONTROL  = $08;   { modificateur CONTROL                }
  FALT      = $10;   { modificateur ALT                    }
  FLAST     = $80;   { dernier accelerateur du tableau     }

  { Limites internes }
  MAX_RESOURCES   = 4096;
  MAX_STRINGS     = 4096;
  MAX_ACCEL       = 256;
  MAX_MENU_ITEMS  = 512;
  MAX_DIALOG_CTRL = 256;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String;

  { En-tete d'une ressource 16 bits (format Windows 3.x) }
  TResHeader16 = Record
    TypeId   : Word;      { identifiant numerique de type (bit 15 = 1) }
    TypeName : TString;   { chaine Pascal si bit 15 = 0, vide sinon    }
    NameId   : Word;      { identifiant numerique du nom (bit 15 = 1)  }
    NameStr  : TString;   { chaine Pascal si bit 15 = 0, vide sinon    }
    DataSize : LongInt;   { taille des donnees en octets               }
    Attribs  : Word;      { attributs memoire                          }
    Reserved : Word;      { reserve = 0                                }
    NameLen  : Word;      { longueur du nom (optionnel)                }
    DataOfs  : LongInt;   { position du debut des donnees              }
  End;

  { En-tete d'une ressource 32 bits (format Win32) }
  TResHeader32 = Record
    DataSize        : LongInt;  { taille des donnees en octets              }
    HeaderSize      : LongInt;  { taille de l en-tete (variable)            }
    TypeIsId        : Boolean;  { True si type numerique                    }
    TypeId          : Word;     { identifiant de type si TypeIsId           }
    TypeName        : TString;  { nom Unicode Latin-1 si Non TypeIsId       }
    NameIsId        : Boolean;  { True si nom numerique                     }
    NameId          : Word;     { identifiant de nom si NameIsId            }
    NameStr         : TString;  { nom Unicode Latin-1 si Non NameIsId       }
    DataVersion     : LongInt;  { version des donnees                       }
    MemFlags        : Word;     { attributs memoire                         }
    LangId          : Word;     { identifiant de langue                     }
    Version         : LongInt;  { version utilisateur                       }
    Characteristics : LongInt;  { caracteristiques utilisateur              }
    DataOfs         : LongInt;  { position des donnees dans le fichier      }
  End;

  { Entree dans la table des accelerateurs decodes (RT_ACCELERATOR) }
  TAccelEntry = Record
    fVirt  : Word;    { drapeaux de l accelerateur            }
    Key    : Word;    { code de touche                        }
    Cmd    : Word;    { identifiant de commande               }
    IsLast : Boolean; { True si bit FLAST de fVirt est a 1   }
  End;

  { Entree dans la table des chaines decodes (RT_STRING) }
  TStringEntry = Record
    BlockId  : Word;    { identifiant du bloc 1..N      }
    Index    : Byte;    { indice dans le bloc 0..15     }
    StringId : Word;    { = (BlockId-1)*16 + Index      }
    Text     : TString; { texte de la chaine            }
  End;

  { Entree dans la table des ressources collectees }
  TResourceEntry = Record
    ResFormat  : Integer;   { FMT_RES16 ou FMT_RES32              }
    TypeIsId   : Boolean;   { True si type numerique              }
    TypeId     : Word;      { identifiant de type si TypeIsId     }
    TypeName   : TString;   { nom de type si Non TypeIsId         }
    NameIsId   : Boolean;   { True si nom numerique               }
    NameId     : Word;      { identifiant de nom si NameIsId      }
    NameStr    : TString;   { nom si Non NameIsId                 }
    DataSize   : LongInt;   { taille des donnees en octets        }
    DataOfs    : LongInt;   { offset des donnees dans le fichier  }
    MemFlags   : Word;      { attributs memoire                   }
    LangId     : Word;      { identifiant de langue (0 si 16 bits)}
  End;

  { Options de la ligne de commande }
  TOptions = Record
    SrcFile    : TString;   { fichier .RES source               }
    OutFile    : TString;   { fichier .RC de sortie             }
    Force16    : Boolean;   { -16 : forcer format 16 bits       }
    Force32    : Boolean;   { -32 : forcer format 32 bits       }
    Verbose    : Boolean;   { -v  : mode verbeux                }
    ExtractBin : Boolean;   { -x  : extraire ressources binaires}
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts         : TOptions;
  ResFile      : File Of Byte;   { fichier .RES ouvert en lecture  }
  ResFileName  : TString;        { nom du fichier courant          }
  ResFileSize  : LongInt;        { taille totale en octets         }
  ResFilePos   : LongInt;        { position courante (0-base)      }
  ResFormat    : Integer;        { FMT_RES16 ou FMT_RES32          }
  Resources    : Array[1..MAX_RESOURCES] Of TResourceEntry;
  ResCount     : Integer;        { nombre de ressources collectees  }
  StringEntries : Array[1..MAX_STRINGS] Of TStringEntry;
  StringCount   : Integer;       { nombre de chaines decodees       }
  AccelEntries  : Array[1..MAX_ACCEL] Of TAccelEntry;
  AccelCount    : Integer;       { nombre d accelerateurs decodes   }

{ ============================================================
  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('DISRES: ERREUR - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;
Begin
  WriteLn('DISRES v', DISRES_VERSION,
          ' - Desassembleur de fichiers .RES (ressources Windows) vers .RC');
  WriteLn;
  WriteLn('Syntaxe : DISRES fichier.res [-o sortie.rc] [-16|-32] [-x] [-v] [-h]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -o nom    : specifier le nom du fichier de sortie .RC');
  WriteLn('              (defaut : meme nom que le fichier source, extension .RC)');
  WriteLn('  -16       : forcer la lecture en format RES 16 bits');
  WriteLn('              (Windows 3.x, Borland Pascal, Turbo Pascal pour Windows)');
  WriteLn('  -32       : forcer la lecture en format RES 32 bits');
  WriteLn('              (Windows NT/9x+, MSVC, Delphi, Free Pascal/windres)');
  WriteLn('  -x        : extraire les ressources binaires (icones, curseurs, bitmaps)');
  WriteLn('              dans le repertoire courant');
  WriteLn('  -v        : mode verbeux (afficher les details des ressources)');
  WriteLn('  -h        : afficher cette aide');
  WriteLn('  --help    : afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  DISRES appli.res');
  WriteLn('  DISRES appli.res -o ressources.rc -v');
  WriteLn('  DISRES appli.res -32 -x -o appli.rc');
  WriteLn;
  Halt(EXIT_OK);
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName(Var AOpts : TOptions);
Var
  Base : TString;
  I    : Integer;
Begin
  Base := AOpts.SrcFile;
  For I := Length(Base) DownTo 1 Do
  Begin
    If (Base[I] = '.') Or (Base[I] = ':') Or
       (Base[I] = '\') Or (Base[I] = '/') Then
    Begin
      If Base[I] = '.' Then
        Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  AOpts.OutFile := Base + '.RC';
End;

{ ---- Analyse de la ligne de commande ---------------------- }
Procedure ParseCommandLine(Var AOpts : TOptions);
Var
  I    : Integer;
  Arg  : TString;
  SLen : Integer;
  Ext  : TString;
Begin
  { Initialisation des options }
  AOpts.SrcFile    := '';
  AOpts.OutFile    := '';
  AOpts.Force16    := False;
  AOpts.Force32    := False;
  AOpts.Verbose    := False;
  AOpts.ExtractBin := False;

  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '-?') Or (Arg = '--help') Then
      ShowHelp
    Else If Arg = '-v' Then
      AOpts.Verbose := True
    Else If Arg = '-16' Then
    Begin
      AOpts.Force16 := True;
      AOpts.Force32 := False;
    End
    Else If Arg = '-32' Then
    Begin
      AOpts.Force32 := True;
      AOpts.Force16 := False;
    End
    Else If Arg = '-x' Then
      AOpts.ExtractBin := True
    Else If (Arg = '-o') And (I < ParamCount) Then
    Begin
      Inc(I);
      AOpts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('DISRES: option inconnue : ', Arg);
      WriteLn('Utilisez DISRES -h pour l''aide.');
      Halt(EXIT_USAGE);
    End
    Else If AOpts.SrcFile = '' Then
      AOpts.SrcFile := Arg
    Else
    Begin
      WriteLn('DISRES: argument inattendu : ', Arg);
      WriteLn('Utilisez DISRES -h pour l''aide.');
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;

  { Verifier que le fichier source est fourni }
  If AOpts.SrcFile = '' Then
  Begin
    WriteLn('DISRES: aucun fichier source specifie.');
    WriteLn('Utilisez DISRES -h pour l''aide.');
    Halt(EXIT_USAGE);
  End;

  { Verifier l'extension .res / .RES }
  SLen := Length(AOpts.SrcFile);
  If SLen >= 4 Then
    Ext := Copy(AOpts.SrcFile, SLen - 3, 4)
  Else
    Ext := AOpts.SrcFile;
  { Convertir en majuscules pour comparaison }
  If (Length(Ext) = 4) And (Ext[1] = '.') Then
  Begin
    If (Ext[2] In ['R', 'r']) And (Ext[3] In ['E', 'e']) And
       (Ext[4] In ['S', 's']) Then
      { extension valide }
    Else
    Begin
      WriteLn('DISRES: le fichier source doit avoir l''extension .RES : ',
              AOpts.SrcFile);
      Halt(EXIT_USAGE);
    End;
  End
  Else
  Begin
    WriteLn('DISRES: le fichier source doit avoir l''extension .RES : ',
            AOpts.SrcFile);
    Halt(EXIT_USAGE);
  End;

  { Construire le nom de sortie par defaut si non specifie }
  If AOpts.OutFile = '' Then
    BuildOutName(AOpts);
End;

{ ============================================================
  TODO 02 - FONCTIONS UTILITAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- Representation hexadecimale 2 chiffres --------------- }
Function HexByte(B : Byte) : TString;
Const
  HexDigits : Array[0..15] Of Char = '0123456789ABCDEF';
Begin
  HexByte := HexDigits[B Shr 4] + HexDigits[B And $0F];
End;

{ ---- Representation hexadecimale 4 chiffres --------------- }
Function HexWord(W : Word) : TString;
Begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

{ ---- Representation hexadecimale 8 chiffres --------------- }
Function HexDWord(D : LongInt) : TString;
Begin
  HexDWord := HexWord(Word(D Shr 16)) + HexWord(Word(D And $FFFF));
End;

{ ---- Conversion entier -> chaine decimale ----------------- }
Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ ---- Conversion chaine en majuscules ---------------------- }
Function UpCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    Tmp[I] := UpCase(Tmp[I]);
  UpCaseStr := Tmp;
End;

{ ---- Supprimer espaces de debut et de fin ----------------- }
Function Trim(Const S : TString) : TString;
Var
  L, R : Integer;
Begin
  L := 1;
  While (L <= Length(S)) And (S[L] = ' ') Do Inc(L);
  R := Length(S);
  While (R >= L) And (S[R] = ' ') Do Dec(R);
  If L > R Then
    Trim := ''
  Else
    Trim := Copy(S, L, R - L + 1);
End;

{ ---- Verifier l existence d un fichier -------------------- }
Function FileExists(Const FName : TString) : Boolean;
Var
  F : File;
Begin
  Assign(F, FName);
  {$I-}
  Reset(F, 1);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

{ ---- Remplacer l extension d un fichier ------------------- }
Function ChangeFileExt(Const FName, NewExt : TString) : TString;
Var
  I    : Integer;
  Base : TString;
Begin
  Base := FName;
  For I := Length(FName) DownTo 1 Do
  Begin
    If FName[I] = '.' Then
    Begin
      Base := Copy(FName, 1, I - 1);
      Break;
    End;
    If (FName[I] = '\') Or (FName[I] = '/') Then Break;
  End;
  ChangeFileExt := Base + NewExt;
End;

{ ---- Completer a gauche avec des espaces ------------------ }
Function PadLeft(Const S : TString; Width : Integer) : TString;
Var
  R : TString;
Begin
  R := S;
  While Length(R) < Width Do
    R := ' ' + R;
  PadLeft := R;
End;

{ ---- Convertir WCHAR Unicode en Char Latin-1 -------------- }
Function WCharToChar(W : Word) : Char;
Begin
  { Caracteres ASCII directs }
  If W < 128 Then
    WCharToChar := Chr(W)
  { Plage Latin-1 supplement (U+0080..U+00FF) }
  Else If W <= $00FF Then
    WCharToChar := Chr(W And $FF)
  { Caracteres hors Latin-1 : remplacer par '?' }
  Else
    WCharToChar := '?';
End;

{ ---- Convertir tableau de WCHAR en String Pascal ---------- }
Function UniStrToStr(Const Buf : Array Of Word; Len : Integer) : TString;
Var
  I : Integer;
  S : TString;
Begin
  S := '';
  For I := 0 To Len - 1 Do
  Begin
    If Buf[I] = 0 Then Break;
    If Length(S) < 255 Then
      S := S + WCharToChar(Buf[I]);
  End;
  UniStrToStr := S;
End;

{ ---- Echapper les caracteres speciaux pour le format RC --- }
Function EscapeRCString(Const S : TString) : TString;
Var
  I   : Integer;
  Res : TString;
Begin
  Res := '';
  For I := 1 To Length(S) Do
  Begin
    Case S[I] Of
      '"'  : Res := Res + '\"';
      '\'  : Res := Res + '\\';
      #9   : Res := Res + '\t';
      #13  : Res := Res + '\n';
      #10  : { ignorer LF apres CR } ;
    Else
      Res := Res + S[I];
    End;
  End;
  EscapeRCString := Res;
End;

{ ---- Formatter un identifiant ressource (nom ou ID) ------- }
Function FormatID(ID : LongInt; Const Name : TString) : TString;
Begin
  If Name <> '' Then
    FormatID := '"' + Name + '"'
  Else
    FormatID := IntToStr(ID);
End;

{ ============================================================
  TODO 03 - LECTURE BINAIRE DU FICHIER .RES [IMPLEMENTE]
  ============================================================ }

{ ---- Ouvrir le fichier RES en lecture --------------------- }
Procedure OpenResFile(Const FName : TString);
Begin
  ResFileName := FName;
  Assign(ResFile, FName);
  {$I-}
  Reset(ResFile);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier : ' + FName);
  { Lire la taille via FileSize }
  ResFileSize := FileSize(ResFile);
  ResFilePos  := 0;
End;

{ ---- Fermer le fichier RES -------------------------------- }
Procedure CloseResFile;
Begin
  Close(ResFile);
End;

{ ---- Lire un octet ---------------------------------------- }
Function ReadByte : Byte;
Var
  B : Byte;
Begin
  If ResFilePos >= ResFileSize Then
    FatalError('EOF inattendu dans ' + ResFileName);
  Read(ResFile, B);
  Inc(ResFilePos);
  ReadByte := B;
End;

{ ---- Lire un Word little-endian (2 octets) ---------------- }
Function ReadWord : Word;
Var
  Lo_, Hi_ : Byte;
Begin
  Lo_ := ReadByte;
  Hi_ := ReadByte;
  ReadWord := Word(Lo_) + Word(Hi_) * 256;
End;

{ ---- Lire un DWord little-endian (4 octets) --------------- }
Function ReadDWord : LongInt;
Var
  W0, W1 : Word;
Begin
  W0 := ReadWord;
  W1 := ReadWord;
  ReadDWord := LongInt(W0) Or (LongInt(W1) Shl 16);
End;

{ ---- Lire un WCHAR (2 octets little-endian) --------------- }
Function ReadWChar : Word;
Begin
  ReadWChar := ReadWord;
End;

{ ---- Avancer de N octets sans lire le contenu ------------- }
Procedure SkipBytes(N : LongInt);
Var
  I : LongInt;
  B : Byte;
Begin
  If N <= 0 Then Exit;
  If N > 64 Then
  Begin
    { Seek direct pour efficacite }
    Seek(ResFile, ResFilePos + N);
    ResFilePos := ResFilePos + N;
  End
  Else
  Begin
    For I := 1 To N Do
    Begin
      Read(ResFile, B);
      Inc(ResFilePos);
    End;
  End;
End;

{ ---- Retourner la position courante ----------------------- }
Function GetResPos : LongInt;
Begin
  GetResPos := ResFilePos;
End;

{ ---- Se deplacer a la position Pos ------------------------ }
Procedure SeekResPos(Pos : LongInt);
Begin
  Seek(ResFile, Pos);
  ResFilePos := Pos;
End;

{ ---- Tester la fin de fichier ----------------------------- }
Function ResEOF : Boolean;
Begin
  ResEOF := ResFilePos >= ResFileSize;
End;

{ ---- Aligner la position sur un multiple de Align --------- }
Procedure AlignResPos(Align : Byte);
Var
  Remainder : LongInt;
Begin
  If Align <= 1 Then Exit;
  Remainder := ResFilePos Mod LongInt(Align);
  If Remainder <> 0 Then
    SkipBytes(LongInt(Align) - Remainder);
End;

{ ============================================================
  TODO 04 - DETECTION DU FORMAT 16 OU 32 BITS [IMPLEMENTE]
  ============================================================ }

{ ---- Detecter automatiquement le format du fichier .RES --- }
Function DetectResFormat : Integer;
Var
  SavePos : LongInt;
  DW0     : LongInt;   { 4 premiers octets : DataSize (32 bits) ou TypeId (16 bits) }
  DW1     : LongInt;   { 4 octets suivants : HeaderSize (32 bits)                   }
  W0      : Word;      { premier WORD pour critere 16 bits                          }
Begin
  { Respecter les options de force en priorite }
  If Opts.Force16 Then Begin DetectResFormat := FMT_RES16; Exit; End;
  If Opts.Force32 Then Begin DetectResFormat := FMT_RES32; Exit; End;

  { Fichier trop petit pour etre valide }
  If ResFileSize < 8 Then Begin DetectResFormat := FMT_UNKNOWN; Exit; End;

  { Sauvegarder la position et lire les 8 premiers octets }
  SavePos := GetResPos;
  DW0 := ReadDWord;
  DW1 := ReadDWord;
  SeekResPos(SavePos);

  { Critere format 32 bits :
    premier enregistrement = ressource nulle => DataSize=0, HeaderSize=32 }
  If (DW0 = 0) And (DW1 = 32) Then
  Begin
    DetectResFormat := FMT_RES32;
    Exit;
  End;

  { Critere format 16 bits :
    premier WORD = type numerique $8001..$800F
    ou type connu non numerique 1..16 (RT_CURSOR..RT_ANIICON) }
  W0 := Word(DW0 And $0000FFFF);
  If ((W0 >= $8001) And (W0 <= $800F)) Or
     ((W0 >= 1)     And (W0 <= 16))    Then
  Begin
    DetectResFormat := FMT_RES16;
    Exit;
  End;

  DetectResFormat := FMT_UNKNOWN;
End;

{ ---- Verifier le format et lever une erreur si inconnu ---- }
Procedure CheckResFormat(Var AResFormat : Integer);
Begin
  AResFormat := DetectResFormat;
  If Opts.Verbose Then
  Begin
    Case AResFormat Of
      FMT_RES16 : WriteLn('Format detecte    : RES 16 bits (Windows 3.x)');
      FMT_RES32 : WriteLn('Format detecte    : RES 32 bits (Windows NT/9x+)');
    Else
      WriteLn('Format detecte    : inconnu');
    End;
  End;
  If AResFormat = FMT_UNKNOWN Then
    FatalError('Format de fichier non reconnu : ' + ResFileName);
End;

{ ============================================================
  TODO 05 - PARSING DE L'EN-TETE RESSOURCE 16 BITS [IMPLEMENTE]
  ============================================================ }

{ ---- Lire une chaine Pascal (longueur 1 octet + chars) ---- }
Function ReadPascalString : TString;
Var
  Len : Byte;
  I   : Integer;
  S   : TString;
Begin
  Len := ReadByte;
  S   := '';
  For I := 1 To Len Do
    S := S + Chr(ReadByte);
  { Aligner sur 2 octets : total lu = 1 (longueur) + Len (chars) }
  If ((Len + 1) Mod 2) <> 0 Then
    SkipBytes(1);
  ReadPascalString := S;
End;

{ ---- Lire l'en-tete d'une ressource 16 bits --------------- }
Procedure ReadResHeader16(Var Hdr : TResHeader16);
Var
  W : Word;
Begin
  { Type : WORD avec bit 15 = numerique ou chaine Pascal }
  W := ReadWord;
  If (W And $8000) <> 0 Then
  Begin
    Hdr.TypeId   := W And $7FFF;
    Hdr.TypeName := '';
  End
  Else
  Begin
    Hdr.TypeId   := 0;
    SeekResPos(ResFilePos - 2);
    Hdr.TypeName := ReadPascalString;
  End;

  { Nom : meme logique }
  W := ReadWord;
  If (W And $8000) <> 0 Then
  Begin
    Hdr.NameId  := W And $7FFF;
    Hdr.NameStr := '';
  End
  Else
  Begin
    Hdr.NameId  := 0;
    SeekResPos(ResFilePos - 2);
    Hdr.NameStr := ReadPascalString;
  End;
  Hdr.NameLen := Length(Hdr.NameStr);

  { Champs numeriques }
  Hdr.DataSize := ReadDWord;
  Hdr.Attribs  := ReadWord;
  Hdr.Reserved := ReadWord;

  { Alignement sur 2 octets avant les donnees }
  AlignResPos(2);
  Hdr.DataOfs := GetResPos;
End;

{ ---- Tester si la ressource courante est le marqueur de fin }
Function IsLastResHeader16 : Boolean;
Var
  W       : Word;
  SavePos : LongInt;
Begin
  SavePos          := GetResPos;
  W                := ReadWord;
  SeekResPos(SavePos);
  IsLastResHeader16 := (W = $0000);
End;

{ ============================================================
  TODO 06 - PARSING DE L'EN-TETE RESSOURCE 32 BITS [IMPLEMENTE]
  ============================================================ }

{ ---- Lire une chaine Unicode UTF-16LE (terminee par $0000) - }
Function ReadUnicodeString : TString;
Var
  W : Word;
  S : TString;
Begin
  S := '';
  W := ReadWChar;
  While W <> 0 Do
  Begin
    S := S + WCharToChar(W);
    W := ReadWChar;
  End;
  ReadUnicodeString := S;
End;

{ ---- Lire un identifiant numerique ou un nom Unicode ------- }
Procedure ReadIdOrName(Var IsId : Boolean; Var Id : Word;
                       Var Name : TString);
Var
  W : Word;
Begin
  W := ReadWord;
  If W = $FFFF Then
  Begin
    IsId := True;
    Id   := ReadWord;
    Name := '';
  End
  Else
  Begin
    IsId := False;
    Id   := 0;
    { Le WORD lu est le premier WCHAR de la chaine Unicode }
    Name := WCharToChar(W) + ReadUnicodeString;
  End;
End;

{ ---- Lire l'en-tete d'une ressource 32 bits --------------- }
Procedure ReadResHeader32(Var Hdr : TResHeader32);
Begin
  Hdr.DataSize   := ReadDWord;
  Hdr.HeaderSize := ReadDWord;

  { Type : $FFFF + WORD numerique ou chaine Unicode }
  ReadIdOrName(Hdr.TypeIsId, Hdr.TypeId, Hdr.TypeName);

  { Nom : meme logique }
  ReadIdOrName(Hdr.NameIsId, Hdr.NameId, Hdr.NameStr);

  { Aligner sur 4 octets apres Type + Nom }
  AlignResPos(4);

  { Champs fixes suivant le padding }
  Hdr.DataVersion     := ReadDWord;
  Hdr.MemFlags        := ReadWord;
  Hdr.LangId          := ReadWord;
  Hdr.Version         := ReadDWord;
  Hdr.Characteristics := ReadDWord;

  Hdr.DataOfs := GetResPos;
End;

{ ---- Valider et sauter la ressource nulle de 32 octets ---- }
Procedure ReadNullHeader32;
Var
  Hdr : TResHeader32;
Begin
  ReadResHeader32(Hdr);
  If (Hdr.DataSize <> 0) Or (Hdr.HeaderSize <> 32) Then
    FatalError('En-tete null 32 bits invalide dans ' + ResFileName);
End;

{ ============================================================
  TODO 07 - TABLE DES TYPES DE RESSOURCES (RT_*) [IMPLEMENTE]
  ============================================================ }

{ ---- Nom symbolique RT_xxx d'un type de ressource --------- }
Function ResourceTypeName(TypeId : Word) : TString;
Begin
  Case TypeId Of
    RT_CURSOR       : ResourceTypeName := 'RT_CURSOR';
    RT_BITMAP       : ResourceTypeName := 'RT_BITMAP';
    RT_ICON         : ResourceTypeName := 'RT_ICON';
    RT_MENU         : ResourceTypeName := 'RT_MENU';
    RT_DIALOG       : ResourceTypeName := 'RT_DIALOG';
    RT_STRING       : ResourceTypeName := 'RT_STRING';
    RT_FONTDIR      : ResourceTypeName := 'RT_FONTDIR';
    RT_FONT         : ResourceTypeName := 'RT_FONT';
    RT_ACCELERATOR  : ResourceTypeName := 'RT_ACCELERATOR';
    RT_RCDATA       : ResourceTypeName := 'RT_RCDATA';
    RT_MESSAGETABLE : ResourceTypeName := 'RT_MESSAGETABLE';
    RT_GROUP_CURSOR : ResourceTypeName := 'RT_GROUP_CURSOR';
    RT_GROUP_ICON   : ResourceTypeName := 'RT_GROUP_ICON';
    RT_VERSION      : ResourceTypeName := 'RT_VERSION';
    RT_DLGINCLUDE   : ResourceTypeName := 'RT_DLGINCLUDE';
    RT_PLUGPLAY     : ResourceTypeName := 'RT_PLUGPLAY';
    RT_VXD          : ResourceTypeName := 'RT_VXD';
    RT_ANICURSOR    : ResourceTypeName := 'RT_ANICURSOR';
    RT_ANIICON      : ResourceTypeName := 'RT_ANIICON';
    RT_HTML         : ResourceTypeName := 'RT_HTML';
    RT_MANIFEST     : ResourceTypeName := 'RT_MANIFEST';
    RT_TOOLBAR      : ResourceTypeName := 'RT_TOOLBAR';
  Else
    ResourceTypeName := 'RT_UNKNOWN_' + IntToStr(TypeId);
  End;
End;

{ ---- Mot-cle RC pour la generation du script -------------- }
Function ResourceTypeKeyword(TypeId : Word) : TString;
Begin
  Case TypeId Of
    RT_CURSOR       : ResourceTypeKeyword := 'CURSOR';
    RT_BITMAP       : ResourceTypeKeyword := 'BITMAP';
    RT_ICON         : ResourceTypeKeyword := 'ICON';
    RT_MENU         : ResourceTypeKeyword := 'MENU';
    RT_DIALOG       : ResourceTypeKeyword := 'DIALOG';
    RT_STRING       : ResourceTypeKeyword := 'STRINGTABLE';
    RT_FONTDIR      : ResourceTypeKeyword := 'FONTDIR';
    RT_FONT         : ResourceTypeKeyword := 'FONT';
    RT_ACCELERATOR  : ResourceTypeKeyword := 'ACCELERATORS';
    RT_RCDATA       : ResourceTypeKeyword := 'RCDATA';
    RT_MESSAGETABLE : ResourceTypeKeyword := 'MESSAGETABLE';
    RT_GROUP_CURSOR : ResourceTypeKeyword := 'GROUP_CURSOR';
    RT_GROUP_ICON   : ResourceTypeKeyword := 'GROUP_ICON';
    RT_VERSION      : ResourceTypeKeyword := 'VERSIONINFO';
    RT_DLGINCLUDE   : ResourceTypeKeyword := 'DLGINCLUDE';
    RT_PLUGPLAY     : ResourceTypeKeyword := 'PLUGPLAY';
    RT_VXD          : ResourceTypeKeyword := 'VXD';
    RT_ANICURSOR    : ResourceTypeKeyword := 'ANICURSOR';
    RT_ANIICON      : ResourceTypeKeyword := 'ANIICON';
    RT_HTML         : ResourceTypeKeyword := 'HTML';
    RT_MANIFEST     : ResourceTypeKeyword := 'MANIFEST';
    RT_TOOLBAR      : ResourceTypeKeyword := 'TOOLBAR';
  Else
    ResourceTypeKeyword := 'RCDATA';
  End;
End;

{ ---- Extension du fichier extrait pour ce type ------------ }
Function ResourceFileExt(TypeId : Word) : TString;
Begin
  Case TypeId Of
    RT_CURSOR,
    RT_ANICURSOR    : ResourceFileExt := '.cur';
    RT_BITMAP       : ResourceFileExt := '.bmp';
    RT_ICON,
    RT_ANIICON      : ResourceFileExt := '.ico';
    RT_FONT         : ResourceFileExt := '.fnt';
    RT_HTML         : ResourceFileExt := '.html';
    RT_MANIFEST     : ResourceFileExt := '.xml';
  Else
    ResourceFileExt := '.bin';
  End;
End;

{ ============================================================
  TODO 08 - DECODAGE DE LANGUAGE ID [IMPLEMENTE]
  ============================================================ }

{ ---- Description textuelle d'un identifiant de langue ----- }
Function LangIdToStr(LangId : Word) : TString;
Begin
  Case LangId Of
    LANG_NEUTRAL        : LangIdToStr := 'NEUTRAL';
    LANG_ENGLISH_US     : LangIdToStr := 'ENGLISH, AMERICAN';
    LANG_ENGLISH_UK     : LangIdToStr := 'ENGLISH, BRITISH';
    LANG_FRENCH         : LangIdToStr := 'FRENCH';
    LANG_FRENCH_BELGIUM : LangIdToStr := 'FRENCH, BELGIAN';
    LANG_FRENCH_CANADA  : LangIdToStr := 'FRENCH, CANADIAN';
    LANG_GERMAN         : LangIdToStr := 'GERMAN';
    LANG_ITALIAN        : LangIdToStr := 'ITALIAN';
    LANG_SPANISH        : LangIdToStr := 'SPANISH';
    LANG_PORTUGUESE_BR  : LangIdToStr := 'PORTUGUESE, BRAZILIAN';
    LANG_PORTUGUESE_PT  : LangIdToStr := 'PORTUGUESE';
    LANG_RUSSIAN        : LangIdToStr := 'RUSSIAN';
    LANG_JAPANESE       : LangIdToStr := 'JAPANESE';
    LANG_CHINESE_SIMPL  : LangIdToStr := 'CHINESE, SIMPLIFIED';
    LANG_CHINESE_TRAD   : LangIdToStr := 'CHINESE, TRADITIONAL';
  Else
    LangIdToStr := 'LANG_' + HexWord(LangId);
  End;
End;

{ ---- Directive LANGUAGE pour un script .RC ----------------- }
Function LangIdToRCKeyword(LangId : Word) : TString;
Begin
  Case LangId Of
    LANG_NEUTRAL        : LangIdToRCKeyword :=
                            'LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL';
    LANG_ENGLISH_US     : LangIdToRCKeyword :=
                            'LANGUAGE LANG_ENGLISH, SUBLANG_ENGLISH_US';
    LANG_ENGLISH_UK     : LangIdToRCKeyword :=
                            'LANGUAGE LANG_ENGLISH, SUBLANG_ENGLISH_UK';
    LANG_FRENCH         : LangIdToRCKeyword :=
                            'LANGUAGE LANG_FRENCH, SUBLANG_FRENCH';
    LANG_FRENCH_BELGIUM : LangIdToRCKeyword :=
                            'LANGUAGE LANG_FRENCH, SUBLANG_FRENCH_BELGIAN';
    LANG_FRENCH_CANADA  : LangIdToRCKeyword :=
                            'LANGUAGE LANG_FRENCH, SUBLANG_FRENCH_CANADIAN';
    LANG_GERMAN         : LangIdToRCKeyword :=
                            'LANGUAGE LANG_GERMAN, SUBLANG_GERMAN';
    LANG_ITALIAN        : LangIdToRCKeyword :=
                            'LANGUAGE LANG_ITALIAN, SUBLANG_ITALIAN';
    LANG_SPANISH        : LangIdToRCKeyword :=
                            'LANGUAGE LANG_SPANISH, SUBLANG_SPANISH';
    LANG_PORTUGUESE_BR  : LangIdToRCKeyword :=
                            'LANGUAGE LANG_PORTUGUESE, SUBLANG_PORTUGUESE_BRAZILIAN';
    LANG_PORTUGUESE_PT  : LangIdToRCKeyword :=
                            'LANGUAGE LANG_PORTUGUESE, SUBLANG_PORTUGUESE';
    LANG_RUSSIAN        : LangIdToRCKeyword :=
                            'LANGUAGE LANG_RUSSIAN, SUBLANG_DEFAULT';
    LANG_JAPANESE       : LangIdToRCKeyword :=
                            'LANGUAGE LANG_JAPANESE, SUBLANG_DEFAULT';
    LANG_CHINESE_SIMPL  : LangIdToRCKeyword :=
                            'LANGUAGE LANG_CHINESE, SUBLANG_CHINESE_SIMPLIFIED';
    LANG_CHINESE_TRAD   : LangIdToRCKeyword :=
                            'LANGUAGE LANG_CHINESE, SUBLANG_CHINESE_TRADITIONAL';
  Else
    LangIdToRCKeyword := 'LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL';
  End;
End;

{ ============================================================
  TODO 09 - DECODAGE DES FLAGS MEMOIRE [IMPLEMENTE]
  ============================================================ }

{ ---- Description textuelle des flags memoire --------------- }
Function MemFlagsToStr(Flags : Word) : TString;
Var
  S : TString;
Begin
  If Flags = MF_FIXED Then
  Begin
    MemFlagsToStr := 'FIXED';
    Exit;
  End;
  S := '';
  If (Flags And MF_MOVEABLE) <> 0 Then
  Begin
    If S <> '' Then S := S + ' | ';
    S := S + 'MOVEABLE';
  End;
  If (Flags And MF_PURE) <> 0 Then
  Begin
    If S <> '' Then S := S + ' | ';
    S := S + 'PURE';
  End;
  If (Flags And MF_PRELOAD) <> 0 Then
  Begin
    If S <> '' Then S := S + ' | ';
    S := S + 'PRELOAD';
  End;
  If (Flags And MF_DISCARDABLE) <> 0 Then
  Begin
    If S <> '' Then S := S + ' | ';
    S := S + 'DISCARDABLE';
  End;
  If S = '' Then S := 'FIXED';
  MemFlagsToStr := S;
End;

{ ---- Options RC correspondant aux flags memoire ------------ }
Function MemFlagsToRCOptions(Flags : Word) : TString;
Var
  S : TString;
Begin
  S := '';
  If (Flags And MF_DISCARDABLE) <> 0 Then
  Begin
    If S <> '' Then S := S + ' ';
    S := S + 'DISCARDABLE';
  End;
  If (Flags And MF_MOVEABLE) <> 0 Then
  Begin
    If S <> '' Then S := S + ' ';
    S := S + 'MOVEABLE';
  End;
  If (Flags And MF_PRELOAD) <> 0 Then
  Begin
    If S <> '' Then S := S + ' ';
    S := S + 'PRELOAD';
  End;
  MemFlagsToRCOptions := S;
End;

{ ============================================================
  TODO 10 - TABLE DES RESSOURCES (COLLECTE) [IMPLEMENTE]
  ============================================================ }

{ ---- Collecte des ressources 16 bits ---------------------- }
Procedure CollectResources16;
Var
  H   : TResHeader16;
  E   : TResourceEntry;
Begin
  SeekResPos(0);
  While (Not IsLastResHeader16) And (Not ResEOF) Do
  Begin
    ReadResHeader16(H);
    If ResCount < MAX_RESOURCES Then
    Begin
      Inc(ResCount);
      E.ResFormat := FMT_RES16;
      If (H.TypeId And $8000) <> 0 Then
      Begin
        E.TypeIsId := True;
        E.TypeId   := H.TypeId And $7FFF;
        E.TypeName := '';
      End
      Else
      Begin
        E.TypeIsId := False;
        E.TypeId   := 0;
        E.TypeName := H.TypeName;
      End;
      If (H.NameId And $8000) <> 0 Then
      Begin
        E.NameIsId := True;
        E.NameId   := H.NameId And $7FFF;
        E.NameStr  := '';
      End
      Else
      Begin
        E.NameIsId := False;
        E.NameId   := 0;
        E.NameStr  := H.NameStr;
      End;
      E.DataSize := H.DataSize;
      E.DataOfs  := H.DataOfs;
      E.MemFlags := H.Attribs;
      E.LangId   := 0;
      Resources[ResCount] := E;
    End;
    SkipBytes(H.DataSize);
    AlignResPos(2);
  End;
End;

{ ---- Collecte des ressources 32 bits ---------------------- }
Procedure CollectResources32;
Var
  H    : TResHeader32;
  E    : TResourceEntry;
Begin
  SeekResPos(0);
  { Lire et ignorer la ressource nulle (en-tete de version) }
  ReadNullHeader32;
  While Not ResEOF Do
  Begin
    ReadResHeader32(H);
    If ResCount < MAX_RESOURCES Then
    Begin
      Inc(ResCount);
      E.ResFormat := FMT_RES32;
      E.TypeIsId  := H.TypeIsId;
      E.TypeId    := H.TypeId;
      E.TypeName  := H.TypeName;
      E.NameIsId  := H.NameIsId;
      E.NameId    := H.NameId;
      E.NameStr   := H.NameStr;
      E.DataSize  := H.DataSize;
      E.DataOfs   := H.DataOfs;
      E.MemFlags  := H.MemFlags;
      E.LangId    := H.LangId;
      Resources[ResCount] := E;
    End;
    SkipBytes(H.DataSize);
    AlignResPos(4);
  End;
End;

{ ---- Orchestrateur de collecte ---------------------------- }
Procedure CollectResources(AResFormat : Integer);
Begin
  ResCount := 0;
  If AResFormat = FMT_RES16 Then
    CollectResources16
  Else
    CollectResources32;
  If Opts.Verbose Then
    WriteLn(ResCount, ' ressource(s) collectee(s).');
End;

{ ============================================================
  TODO 11 - DECODAGE RT_STRING (TYPE 6) [IMPLEMENTE]
  ============================================================ }

{ ---- Decoder une ressource STRINGTABLE 16 entrees ---------- }
Procedure ParseStringTable(Const Res : TResourceEntry);
Var
  I      : Integer;
  LenW   : Word;
  J      : Integer;
  W      : Word;
  S      : TString;
  E      : TStringEntry;
Begin
  SeekResPos(Res.DataOfs);
  For I := 0 To 15 Do
  Begin
    LenW := ReadWord;
    If LenW > 0 Then
    Begin
      S := '';
      For J := 1 To LenW Do
      Begin
        W := ReadWChar;
        S := S + WCharToChar(W);
      End;
      If StringCount < MAX_STRINGS Then
      Begin
        Inc(StringCount);
        E.BlockId  := Res.NameId;
        E.Index    := I;
        E.StringId := (Res.NameId - 1) * 16 + I;
        E.Text     := S;
        StringEntries[StringCount] := E;
      End;
    End;
  End;
End;

{ ---- Decoder toutes les ressources STRINGTABLE ------------- }
Procedure ParseAllStringTables;
Var
  I : Integer;
Begin
  StringCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_STRING) Then
      ParseStringTable(Resources[I]);
  End;
  If Opts.Verbose Then
    WriteLn(StringCount, ' chaine(s) decodee(s).');
End;

{ ---- Generer la ligne RC pour une entree de chaine --------- }
Function StringTableRC(Const Entry : TStringEntry) : TString;
Begin
  StringTableRC := '    ' + IntToStr(Entry.StringId) +
                   ', "' + EscapeRCString(Entry.Text) + '"';
End;

{ ============================================================
  TODO 12 - DECODAGE RT_ACCELERATOR (TYPE 9) [IMPLEMENTE]
  ============================================================ }

{ ---- Nom de la touche virtuelle ----------------------------- }
Function VKeyToStr(Key : Word; AVirt : Word) : TString;
Var
  S : TString;
Begin
  If (AVirt And FVIRTKEY) <> 0 Then
  Begin
    Case Key Of
      $08 : S := 'VK_BACK';
      $09 : S := 'VK_TAB';
      $0D : S := 'VK_RETURN';
      $1B : S := 'VK_ESCAPE';
      $20 : S := 'VK_SPACE';
      $23 : S := 'VK_END';
      $24 : S := 'VK_HOME';
      $25 : S := 'VK_LEFT';
      $26 : S := 'VK_UP';
      $27 : S := 'VK_RIGHT';
      $28 : S := 'VK_DOWN';
      $2D : S := 'VK_INSERT';
      $2E : S := 'VK_DELETE';
      $70 : S := 'VK_F1';
      $71 : S := 'VK_F2';
      $72 : S := 'VK_F3';
      $73 : S := 'VK_F4';
      $74 : S := 'VK_F5';
      $75 : S := 'VK_F6';
      $76 : S := 'VK_F7';
      $77 : S := 'VK_F8';
      $78 : S := 'VK_F9';
      $79 : S := 'VK_F10';
      $7A : S := 'VK_F11';
      $7B : S := 'VK_F12';
    Else
      S := IntToStr(Key);
    End;
  End
  Else
    S := '"' + Chr(Key And $FF) + '"';
  VKeyToStr := S;
End;

{ ---- Decoder une ressource ACCELERATORS --------------------- }
Procedure ParseAccelerators(Const Res : TResourceEntry);
Var
  fV     : Word;
  K      : Word;
  Cmd    : Word;
  Pad    : Word;
  E      : TAccelEntry;
Begin
  SeekResPos(Res.DataOfs);
  Repeat
    fV  := ReadWord;
    K   := ReadWord;
    Cmd := ReadWord;
    Pad := ReadWord;   { padding / reserved }
    If AccelCount < MAX_ACCEL Then
    Begin
      Inc(AccelCount);
      E.fVirt  := fV;
      E.Key    := K;
      E.Cmd    := Cmd;
      E.IsLast := (fV And FLAST) <> 0;
      AccelEntries[AccelCount] := E;
    End;
  Until (fV And FLAST) <> 0;
End;

{ ---- Decoder toutes les ressources ACCELERATORS ------------- }
Procedure ParseAllAccelerators;
Var
  I : Integer;
Begin
  AccelCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_ACCELERATOR) Then
      ParseAccelerators(Resources[I]);
  End;
  If Opts.Verbose Then
    WriteLn(AccelCount, ' accelerateur(s) decode(s).');
End;

{ ---- Generer la ligne RC pour un accelerateur --------------- }
Function AccelEntryToRC(Const E : TAccelEntry) : TString;
Var
  S    : TString;
  Opts2 : TString;
Begin
  S := '    ' + VKeyToStr(E.Key, E.fVirt) + ', ' + IntToStr(E.Cmd);
  Opts2 := '';
  If (E.fVirt And FNOINVERT) <> 0 Then
    Opts2 := Opts2 + ', NOINVERT';
  If (E.fVirt And FSHIFT) <> 0 Then
    Opts2 := Opts2 + ', SHIFT';
  If (E.fVirt And FCONTROL) <> 0 Then
    Opts2 := Opts2 + ', CONTROL';
  If (E.fVirt And FALT) <> 0 Then
    Opts2 := Opts2 + ', ALT';
  If (E.fVirt And FVIRTKEY) <> 0 Then
    Opts2 := Opts2 + ', VIRTKEY';
  AccelEntryToRC := S + Opts2;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  { Banniere de version }
  WriteLn('DISRES v', DISRES_VERSION, ' (', DISRES_DATE, ') - ',
          'Desassembleur de fichiers .RES vers .RC');
  WriteLn;

  { Analyser la ligne de commande }
  ParseCommandLine(Opts);

  { Afficher la configuration si mode verbeux }
  If Opts.Verbose Then
  Begin
    WriteLn('Fichier source  : ', Opts.SrcFile);
    WriteLn('Fichier sortie  : ', Opts.OutFile);
    If Opts.Force16 Then
      WriteLn('Format force    : RES 16 bits')
    Else If Opts.Force32 Then
      WriteLn('Format force    : RES 32 bits')
    Else
      WriteLn('Format          : detection automatique');
    If Opts.ExtractBin Then
      WriteLn('Extraction bin. : activee');
    WriteLn;
  End;

  { Ouvrir le fichier source }
  OpenResFile(Opts.SrcFile);

  If Opts.Verbose Then
    WriteLn('Taille du fichier : ', ResFileSize, ' octets');

  { Detecter le format 16 ou 32 bits }
  CheckResFormat(ResFormat);

  { Collecter toutes les ressources }
  CollectResources(ResFormat);

  { Decoder les tables de chaines (RT_STRING) }
  ParseAllStringTables;

  { Decoder les accelerateurs (RT_ACCELERATOR) }
  ParseAllAccelerators;

  { TODO 13 a TODO 25 : a implementer }
  WriteLn('(TODO 13 a TODO 25 : implementation en cours)');

  { Fermer le fichier source }
  CloseResFile;
End.
