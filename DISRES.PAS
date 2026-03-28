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

  TODO 13 - DECODAGE RT_MENU (TYPE 4) [IMPLEMENTE]
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

  TODO 14 - DECODAGE RT_DIALOG (TYPE 5) [IMPLEMENTE]
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

  TODO 15 - DECODAGE RT_VERSION (TYPE 16) [IMPLEMENTE]
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

  TODO 16 - DECODAGE RT_ICON / RT_CURSOR (TYPES 3 ET 1) [IMPLEMENTE]
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

  TODO 17 - DECODAGE RT_BITMAP (TYPE 2) [IMPLEMENTE]
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

  TODO 18 - DECODAGE RT_GROUP_ICON / RT_GROUP_CURSOR (TYPES 14 ET 12) [IMPLEMENTE]
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

  TODO 19 - DECODAGE RT_RCDATA (TYPE 10) [IMPLEMENTE]
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

  TODO 20 - DECODAGE RT_MANIFEST (TYPE 24) [IMPLEMENTE]
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

  TODO 21 - GENERATION DE L'EN-TETE DU FICHIER .RC [IMPLEMENTE]
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

  TODO 22 - GENERATION DES DIRECTIVES RC PAR TYPE [IMPLEMENTE]
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

  TODO 25 - VERIFICATION ET RAPPORT FINAL [IMPLEMENTE]
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

  { Drapeaux fItemFlags pour les elements de menu (RT_MENU) }
  MF_GRAYED       = $0001;  { element grise              }
  MF_DISABLED     = $0002;  { element desactive          }
  MF_BITMAP       = $0008;  { element bitmap             }
  MF_CHECKED      = $0010;  { element coche              }
  MF_POPUP        = $0020;  { element sous-menu popup    }
  MF_MENUBARBREAK = $0040;  { saut de barre de menu      }
  MF_MENUBREAK    = $0080;  { saut de colonne de menu    }
  MF_SEPARATOR    = $0800;  { separateur de menu         }
  MF_END          = $0080;  { dernier element du niveau  }

  { Classes predefinies des controles de dialogue (DC_*) }
  DC_BUTTON    = $0080;  { bouton standard             }
  DC_EDIT      = $0081;  { zone de saisie              }
  DC_STATIC    = $0082;  { texte statique              }
  DC_LISTBOX   = $0083;  { liste deroulante            }
  DC_SCROLLBAR = $0084;  { barre de defilement         }
  DC_COMBOBOX  = $0085;  { liste combinee              }

  { Styles de dialogue DS_* }
  DS_SYSMODAL   = $0002;  { dialogue systeme modal         }
  DS_SETFONT    = $0040;  { utiliser une police specifique }
  DS_MODALFRAME = $0080;  { cadre modal                    }
  DS_CENTER     = $0800;  { centrer dans l ecran           }

  { Constantes VS_VERSIONINFO (RT_VERSION) }
  VS_FFI_SIGNATURE = LongInt($FEEF04BD); { signature VS_FIXEDFILEINFO    }

  { Types de fichiers VFT_* (dwFileType) }
  VFT_UNKNOWN = 0;   { type inconnu            }
  VFT_APP     = 1;   { application             }
  VFT_DLL     = 2;   { bibliotheque de liens   }
  VFT_DRV     = 3;   { pilote de peripherique  }
  VFT_FONT    = 4;   { police de caracteres    }
  VFT_VXD     = 5;   { pilote virtuel          }

  { Systemes d exploitation VOS_* (dwFileOS) }
  VOS_UNKNOWN      = 0;         { OS inconnu        }
  VOS_NT_WINDOWS32 = $00040004; { Windows 32 bits   }

  { Constantes de compression BITMAPINFOHEADER (BI_*) }
  BI_RGB       = 0;  { pas de compression (RVB pur)           }
  BI_RLE8      = 1;  { compression RLE 8 bpp                  }
  BI_RLE4      = 2;  { compression RLE 4 bpp                  }
  BI_BITFIELDS = 3;  { masques de couleur RGB definis          }

  { Limites internes }
  MAX_RESOURCES   = 4096;
  MAX_STRINGS     = 4096;
  MAX_ACCEL       = 256;
  MAX_MENU_ITEMS  = 512;
  MAX_MENU_LINES  = 2048;
  MAX_DIALOG_CTRL = 256;
  MAX_DIALOG_LINES = 1024;
  MAX_VERSION_INFO    = 16;   { ressources RT_VERSION par fichier   }
  MAX_VERSION_STRINGS = 64;   { paires cle-valeur par ressource     }
  MAX_VERSION_LINES   = 512;  { lignes RC generees pour les versions}
  MAX_GRP_ICONS       = 64;   { ressources RT_GROUP_ICON/CURSOR max }
  MAX_GRP_ENTRIES     = 16;   { images max par ressource groupe     }
  RCDATA_BYTES_PER_LINE = 16; { octets par ligne hex RCDATA         }
  MAX_RCDATA_LINES    = 4096; { lignes RC generees pour les RCDATA  }
  MAX_MANIFEST_LINES  = 256;  { lignes XML max par ressource manifest}

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

  { Element de menu decode (RT_MENU) }
  TMenuItem = Record
    Flags   : Word;     { drapeaux fItemFlags                  }
    MenuID  : Word;     { identifiant ou 0 si popup            }
    Text    : TString;  { texte Unicode converti               }
    IsPopup : Boolean;  { True si MF_POPUP dans Flags          }
    IsEnd   : Boolean;  { True si MF_END dans Flags            }
    IsSep   : Boolean;  { True si MF_SEPARATOR dans Flags      }
    IsLast  : Boolean;  { marque de fin du niveau courant      }
  End;

  { Tableau de lignes RC pour la generation (menus) }
  TMenuLineArray = Array[1..MAX_MENU_LINES] Of TString;

  { Controle de dialogue decode (RT_DIALOG) }
  TDialogControl = Record
    Style     : LongInt;   { style du controle                  }
    ExStyle   : LongInt;   { style etendu du controle           }
    X         : Word;      { position X                         }
    Y         : Word;      { position Y                         }
    CX        : Word;      { largeur                            }
    CY        : Word;      { hauteur                            }
    Id        : Word;      { identifiant de commande            }
    ClassIsId : Boolean;   { True si classe est un identifiant  }
    ClassId   : Word;      { identifiant de classe si ClassIsId }
    ClassName : TString;   { nom de classe si Non ClassIsId     }
    TitleIsId : Boolean;   { True si titre est un identifiant   }
    TitleId   : Word;      { identifiant de titre si TitleIsId  }
    TitleStr  : TString;   { texte du titre si Non TitleIsId    }
  End;

  { Tableau de lignes RC pour la generation (dialogues) }
  TDialogLineArray = Array[1..MAX_DIALOG_LINES] Of TString;

  { Tableau de lignes RC pour la generation (RCDATA) }
  TRCDataLineArray = Array[1..MAX_RCDATA_LINES] Of TString;

  { Donnees decodees d une ressource RT_MANIFEST (XML) }
  TManifestData = Record
    Text      : Array[1..MAX_MANIFEST_LINES] Of TString; { lignes XML }
    LineCount : Integer;                                  { nb lignes  }
  End;

  { Entree de valeur de chaine de version (StringFileInfo) }
  TVersionStringEntry = Record
    Key   : TString;   { nom de la cle, ex. "CompanyName"  }
    Value : TString;   { valeur associee                   }
  End;

  { Informations de version decodees (RT_VERSION) }
  TVersionInfo = Record
    FileVersionMS    : LongInt;  { version fichier partie haute         }
    FileVersionLS    : LongInt;  { version fichier partie basse         }
    ProductVersionMS : LongInt;  { version produit partie haute         }
    ProductVersionLS : LongInt;  { version produit partie basse         }
    FileOS           : LongInt;  { systeme d exploitation cible         }
    FileType         : LongInt;  { type de fichier VFT_*                }
    FileSubtype      : LongInt;  { sous-type de fichier                 }
    FileFlags        : LongInt;  { drapeaux de fichier                  }
    FileFlagsMask    : LongInt;  { masque des drapeaux valides          }
    StringTableKey   : TString;  { cle du bloc StringTable ex 040904b0 }
    StringValues     : Array[1..MAX_VERSION_STRINGS] Of TVersionStringEntry;
    StringCount      : Integer;  { nombre de paires cle-valeur          }
    TranslationLang  : Word;     { identifiant de langue                }
    TranslationCP    : Word;     { page de codes                        }
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

  { Tampon d octets generique pour les ressources binaires }
  TByteArray = Array[0..65534] Of Byte;
  PByteArray = ^TByteArray;

  { En-tete d un fichier .ico/.cur (ICONDIR / CURSORDIR) }
  TIconHeader = Record
    Reserved : Word;   { = 0                              }
    ResType  : Word;   { 1 = ICO, 2 = CUR                 }
    Count    : Word;   { nombre d images dans le fichier  }
  End;

  { Entree de repertoire d icone/curseur (ICONDIRENTRY) }
  TIconDirEntry = Record
    Width      : Byte;     { largeur en pixels (0 = 256)      }
    Height     : Byte;     { hauteur en pixels (0 = 256)      }
    ColorCount : Byte;     { nombre de couleurs (0 si >= 256) }
    Reserved   : Byte;     { = 0                              }
    Planes     : Word;     { ICO : 1 ; CUR : hotspot X        }
    BitCount   : Word;     { bits/pixel ; CUR : hotspot Y     }
    BytesInRes : LongInt;  { taille des donnees DIB           }
    ImageOfs   : LongInt;  { offset des donnees dans le .ico  }
  End;

  { En-tete d un fichier .bmp (BITMAPFILEHEADER, 14 octets) }
  TBitmapFileHeader = Record
    bfType      : Word;    { = $4D42 ('BM')                   }
    bfSize      : LongInt; { taille totale du fichier .bmp     }
    bfReserved1 : Word;    { = 0                              }
    bfReserved2 : Word;    { = 0                              }
    bfOffBits   : LongInt; { offset vers les donnees pixels    }
  End;

  { En-tete d information bitmap (BITMAPINFOHEADER, 40 octets) }
  TBitmapInfoHeader = Record
    biSize          : LongInt; { = 40                          }
    biWidth         : LongInt; { largeur en pixels             }
    biHeight        : LongInt; { hauteur (positif = bas-haut)  }
    biPlanes        : Word;    { = 1                           }
    biBitCount      : Word;    { bits par pixel                }
    biCompression   : LongInt; { BI_RGB, BI_RLE8, etc.         }
    biSizeImage     : LongInt; { taille donnees pixels         }
    biXPelsPerMeter : LongInt; { resolution horizontale        }
    biYPelsPerMeter : LongInt; { resolution verticale          }
    biClrUsed       : LongInt; { couleurs utilisees            }
    biClrImportant  : LongInt; { couleurs importantes          }
  End;

  { Entree de repertoire de groupe d icone/curseur (GRPICONDIR) }
  TGrpIconDirEntry = Record
    Width      : Byte;     { largeur en pixels (0 = 256)                  }
    Height     : Byte;     { hauteur en pixels (0 = 256)                  }
    ColorCount : Byte;     { nombre de couleurs (0 si >= 256)             }
    Reserved   : Byte;     { = 0                                          }
    Planes     : Word;     { plans (ICO) ou hotspot X (CUR)               }
    BitCount   : Word;     { bits/pixel (ICO) ou hotspot Y (CUR)          }
    BytesInRes : LongInt;  { taille des donnees de la ressource associee  }
    Id         : Word;     { identifiant de la ressource RT_ICON/CURSOR   }
  End;

  { Structure interne representant un groupe d icones/curseurs }
  TGroupIcon = Record
    GroupId  : Word;                                   { NameId du groupe  }
    IsCursor : Boolean;                                { True = .cur       }
    Count    : Integer;                                { nb d images       }
    Entries  : Array[1..MAX_GRP_ENTRIES] Of TGrpIconDirEntry;
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
  MenuItems     : Array[1..MAX_MENU_ITEMS] Of TMenuItem;
  MenuItemCount : Integer;       { nombre d elements de menu decodes }
  MenuRCLines   : TMenuLineArray;{ lignes RC generees pour les menus }
  MenuRCLineCount : Integer;     { nombre de lignes RC de menu       }
  DialogControls   : Array[1..MAX_DIALOG_CTRL] Of TDialogControl;
  DialogCtrlCount  : Integer;    { nombre de controles decodes       }
  DialogRCLines    : TDialogLineArray; { lignes RC pour les dialogues }
  DialogRCLineCount : Integer;   { nombre de lignes RC de dialogue   }
  VersionInfos      : Array[1..MAX_VERSION_INFO] Of TVersionInfo;
  VersionInfoCount  : Integer;   { nombre de ressources de version   }
  VersionRCLines    : Array[1..MAX_VERSION_LINES] Of TString;
  VersionRCLineCount : Integer;  { nombre de lignes RC de version    }
  GroupIcons        : Array[1..MAX_GRP_ICONS] Of TGroupIcon;
  GroupIconCount    : Integer;   { nombre de groupes d icones decodes  }
  RCDataRCLines     : TRCDataLineArray; { lignes RC generees pour les RCDATA }
  RCDataRCLineCount : Integer;   { nombre de lignes RC RCDATA          }
  ExtractCount      : Integer;   { nombre de fichiers binaires extraits }

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
      { TypeId a deja le bit 15 supprime par ReadResHeader16 ;
        determiner numerique vs chaine selon TypeName vide ou non }
      If H.TypeName = '' Then
      Begin
        E.TypeIsId := True;
        E.TypeId   := H.TypeId;
        E.TypeName := '';
      End
      Else
      Begin
        E.TypeIsId := False;
        E.TypeId   := 0;
        E.TypeName := H.TypeName;
      End;
      { Meme logique pour le nom de ressource }
      If H.NameStr = '' Then
      Begin
        E.NameIsId := True;
        E.NameId   := H.NameId;
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
  TODO 13 - DECODAGE RT_MENU (TYPE 4) [IMPLEMENTE]
  ============================================================ }

{ ---- Lire les elements de menu recursivement --------------- }
Procedure ParseMenuItems(Level : Integer;
                         Var Lines : TMenuLineArray;
                         Var LineCount : Integer);
Var
  fFlags  : Word;
  Mid     : Word;
  Txt     : TString;
  IsPopup : Boolean;
  IsEnd2  : Boolean;
  IsSep   : Boolean;
  Indent  : TString;
  Opts2   : TString;
  J       : Integer;
  E       : TMenuItem;
Begin
  Repeat
    fFlags  := ReadWord;
    IsPopup := (fFlags And MF_POPUP) <> 0;
    IsEnd2  := (fFlags And MF_END) <> 0;
    IsSep   := (fFlags And MF_SEPARATOR) <> 0;
    Mid := 0;
    If Not IsPopup Then
      Mid := ReadWord;
    Txt := ReadUnicodeString;
    { Stocker dans le tableau global MenuItems }
    If MenuItemCount < MAX_MENU_ITEMS Then
    Begin
      Inc(MenuItemCount);
      E.Flags   := fFlags;
      E.MenuID  := Mid;
      E.Text    := Txt;
      E.IsPopup := IsPopup;
      E.IsEnd   := IsEnd2;
      E.IsSep   := IsSep;
      E.IsLast  := IsEnd2;
      MenuItems[MenuItemCount] := E;
    End;
    { Construire le prefixe d indentation }
    Indent := '';
    For J := 1 To (Level + 1) Do
      Indent := Indent + '    ';
    { Generer les lignes RC correspondantes }
    If IsPopup Then
    Begin
      If LineCount < MAX_MENU_LINES Then
      Begin
        Inc(LineCount);
        Lines[LineCount] := Indent + 'POPUP "' + Txt + '"';
      End;
      If LineCount < MAX_MENU_LINES Then
      Begin
        Inc(LineCount);
        Lines[LineCount] := Indent + 'BEGIN';
      End;
      ParseMenuItems(Level + 1, Lines, LineCount);
      If LineCount < MAX_MENU_LINES Then
      Begin
        Inc(LineCount);
        Lines[LineCount] := Indent + 'END';
      End;
    End
    Else If IsSep Then
    Begin
      If LineCount < MAX_MENU_LINES Then
      Begin
        Inc(LineCount);
        Lines[LineCount] := Indent + 'MENUITEM SEPARATOR';
      End;
    End
    Else
    Begin
      Opts2 := '';
      If (fFlags And MF_GRAYED) <> 0 Then
        Opts2 := Opts2 + ', GRAYED';
      If (fFlags And MF_CHECKED) <> 0 Then
        Opts2 := Opts2 + ', CHECKED';
      If (fFlags And MF_DISABLED) <> 0 Then
        Opts2 := Opts2 + ', INACTIVE';
      If (fFlags And MF_MENUBARBREAK) <> 0 Then
        Opts2 := Opts2 + ', MENUBARBREAK';
      If LineCount < MAX_MENU_LINES Then
      Begin
        Inc(LineCount);
        Lines[LineCount] := Indent + 'MENUITEM "' + Txt + '", ' +
                            IntToStr(Mid) + Opts2;
      End;
    End;
  Until IsEnd2;
End;

{ ---- Decoder une ressource MENU ----------------------------- }
Procedure ParseMenu(Const Res : TResourceEntry);
Var
  wVersion     : Word;
  cbHeaderSize : Word;
  ResName      : TString;
  StartLine    : Integer;
  I            : Integer;
Begin
  SeekResPos(Res.DataOfs);
  wVersion     := ReadWord;
  cbHeaderSize := ReadWord;
  { Se positionner apres l en-tete (cbHeaderSize inclut les 4 octets lus) }
  SeekResPos(Res.DataOfs + cbHeaderSize);
  { Determiner le nom de la ressource }
  If Res.NameIsId Then
    ResName := IntToStr(Res.NameId)
  Else
    ResName := Res.NameStr;
  StartLine := MenuRCLineCount;
  { Ajouter l en-tete et le bloc RC }
  If MenuRCLineCount < MAX_MENU_LINES Then
  Begin
    Inc(MenuRCLineCount);
    MenuRCLines[MenuRCLineCount] := ResName + ' MENU';
  End;
  If MenuRCLineCount < MAX_MENU_LINES Then
  Begin
    Inc(MenuRCLineCount);
    MenuRCLines[MenuRCLineCount] := 'BEGIN';
  End;
  If wVersion = 0 Then
  Begin
    { Menu standard }
    ParseMenuItems(0, MenuRCLines, MenuRCLineCount);
  End
  Else
  Begin
    { Menu etendu MENUEX : non supporte, stub }
    If MenuRCLineCount < MAX_MENU_LINES Then
    Begin
      Inc(MenuRCLineCount);
      MenuRCLines[MenuRCLineCount] := '    { MENUEX - format etendu non supporte }';
    End;
  End;
  If MenuRCLineCount < MAX_MENU_LINES Then
  Begin
    Inc(MenuRCLineCount);
    MenuRCLines[MenuRCLineCount] := 'END';
  End;
  { Afficher si mode verbeux }
  If Opts.Verbose Then
    For I := StartLine + 1 To MenuRCLineCount Do
      WriteLn(MenuRCLines[I]);
End;

{ ---- Decoder toutes les ressources MENU -------------------- }
Procedure ParseAllMenus;
Var
  I         : Integer;
  MenuCount : Integer;
Begin
  MenuItemCount   := 0;
  MenuRCLineCount := 0;
  MenuCount       := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_MENU) Then
    Begin
      ParseMenu(Resources[I]);
      Inc(MenuCount);
    End;
  End;
  If Opts.Verbose Then
    WriteLn(MenuCount, ' menu(s) decode(s), ',
            MenuItemCount, ' element(s) de menu au total.');
End;

{ ============================================================
  TODO 14 - DECODAGE RT_DIALOG (TYPE 5) [IMPLEMENTE]
  ============================================================ }

{ ---- Nom de classe predefinit a partir d un atome --------- }
Function WindowClassAtomToStr(Atom : Word) : TString;
Begin
  Case Atom Of
    DC_BUTTON    : WindowClassAtomToStr := 'BUTTON';
    DC_EDIT      : WindowClassAtomToStr := 'EDIT';
    DC_STATIC    : WindowClassAtomToStr := 'STATIC';
    DC_LISTBOX   : WindowClassAtomToStr := 'LISTBOX';
    DC_SCROLLBAR : WindowClassAtomToStr := 'SCROLLBAR';
    DC_COMBOBOX  : WindowClassAtomToStr := 'COMBOBOX';
  Else
    WindowClassAtomToStr := '#' + IntToStr(Atom);
  End;
End;

{ ---- Construire la chaine de styles WS_*/DS_* ------------- }
Procedure ParseDialogStyles(Style : LongInt; Var StyleStr : TString);
  Procedure AddStyle(Const S : TString);
  Begin
    If StyleStr = '' Then
      StyleStr := S
    Else
      StyleStr := StyleStr + ' | ' + S;
  End;
Begin
  StyleStr := '';
  { Styles DS_* (petites valeurs) }
  If (Style And DS_SYSMODAL)   <> 0 Then AddStyle('DS_SYSMODAL');
  If (Style And DS_SETFONT)    <> 0 Then AddStyle('DS_SETFONT');
  If (Style And DS_MODALFRAME) <> 0 Then AddStyle('DS_MODALFRAME');
  If (Style And DS_CENTER)     <> 0 Then AddStyle('DS_CENTER');
  { Styles WS_* (grandes valeurs, comparaisons avec masques) }
  If (Style And $80000000) <> 0 Then AddStyle('WS_POPUP');
  If (Style And $40000000) <> 0 Then AddStyle('WS_CHILD');
  If (Style And $20000000) <> 0 Then AddStyle('WS_CLIPSIBLINGS');
  If (Style And $10000000) <> 0 Then AddStyle('WS_VISIBLE');
  If (Style And $08000000) <> 0 Then AddStyle('WS_DISABLED');
  If (Style And $00200000) <> 0 Then AddStyle('WS_VSCROLL');
  If (Style And $00100000) <> 0 Then AddStyle('WS_HSCROLL');
  If (Style And $00080000) <> 0 Then AddStyle('WS_SYSMENU');
  If (Style And $00040000) <> 0 Then AddStyle('WS_THICKFRAME');
  If (Style And $00020000) <> 0 Then AddStyle('WS_MINIMIZEBOX');
  If (Style And $00010000) <> 0 Then AddStyle('WS_MAXIMIZEBOX');
  { WS_CAPTION = WS_BORDER | WS_DLGFRAME = $00C00000 }
  If (Style And $00C00000) = $00C00000 Then
    AddStyle('WS_CAPTION')
  Else
  Begin
    If (Style And $00800000) <> 0 Then AddStyle('WS_BORDER');
    If (Style And $00400000) <> 0 Then AddStyle('WS_DLGFRAME');
  End;
  If StyleStr = '' Then
    StyleStr := '0';
End;

{ ---- Decoder un modele de boite de dialogue ---------------- }
Procedure ParseDialogTemplate(Const Res : TResourceEntry);
Var
  Style        : LongInt;
  ExStyle      : LongInt;
  CDit         : Word;
  DX, DY, DCX, DCY : Word;
  MenuIsId     : Boolean;
  MenuId       : Word;
  MenuName     : TString;
  WClassIsId   : Boolean;
  WClassId     : Word;
  WClassName   : TString;
  Title        : TString;
  PointSize    : Word;
  Typeface     : TString;
  StyleStr     : TString;
  ResName      : TString;
  I            : Integer;
  StartLine    : Integer;
  Ctrl         : TDialogControl;
  CStyle       : LongInt;
  CExStyle     : LongInt;
  CX2, CY2, CCX, CCY, CId : Word;
  ExtraCount   : Word;
  CtrlClassIsId : Boolean;
  CtrlClassId   : Word;
  CtrlClassName : TString;
  CtrlTitleIsId : Boolean;
  CtrlTitleId   : Word;
  CtrlTitleStr  : TString;
  CtrlClassNameRC : TString;
  CtrlTitleRC     : TString;
Begin
  SeekResPos(Res.DataOfs);
  Style   := ReadDWord;
  ExStyle := ReadDWord;
  CDit    := ReadWord;
  DX      := ReadWord;
  DY      := ReadWord;
  DCX     := ReadWord;
  DCY     := ReadWord;
  { Lire le menu (sz_Or_Ord) }
  ReadIdOrName(MenuIsId, MenuId, MenuName);
  { Lire la classe de fenetre (sz_Or_Ord) }
  ReadIdOrName(WClassIsId, WClassId, WClassName);
  { Lire le titre }
  Title := ReadUnicodeString;
  { Lire la police si DS_SETFONT }
  PointSize := 0;
  Typeface  := '';
  If (Style And DS_SETFONT) <> 0 Then
  Begin
    PointSize := ReadWord;
    Typeface  := ReadUnicodeString;
  End;
  { Determiner le nom de la ressource }
  If Res.NameIsId Then
    ResName := IntToStr(Res.NameId)
  Else
    ResName := Res.NameStr;
  StartLine := DialogRCLineCount;
  { Generer l en-tete du dialogue }
  If DialogRCLineCount < MAX_DIALOG_LINES Then
  Begin
    Inc(DialogRCLineCount);
    DialogRCLines[DialogRCLineCount] := ResName + ' DIALOG ' +
      IntToStr(DX) + ', ' + IntToStr(DY) + ', ' +
      IntToStr(DCX) + ', ' + IntToStr(DCY);
  End;
  ParseDialogStyles(Style, StyleStr);
  If DialogRCLineCount < MAX_DIALOG_LINES Then
  Begin
    Inc(DialogRCLineCount);
    DialogRCLines[DialogRCLineCount] := 'STYLE ' + StyleStr;
  End;
  If Title <> '' Then
  Begin
    If DialogRCLineCount < MAX_DIALOG_LINES Then
    Begin
      Inc(DialogRCLineCount);
      DialogRCLines[DialogRCLineCount] := 'CAPTION "' +
        EscapeRCString(Title) + '"';
    End;
  End;
  If (Style And DS_SETFONT) <> 0 Then
  Begin
    If DialogRCLineCount < MAX_DIALOG_LINES Then
    Begin
      Inc(DialogRCLineCount);
      DialogRCLines[DialogRCLineCount] := 'FONT ' +
        IntToStr(PointSize) + ', "' + EscapeRCString(Typeface) + '"';
    End;
  End;
  If DialogRCLineCount < MAX_DIALOG_LINES Then
  Begin
    Inc(DialogRCLineCount);
    DialogRCLines[DialogRCLineCount] := 'BEGIN';
  End;
  { Decoder chaque controle }
  For I := 1 To CDit Do
  Begin
    { Aligner sur 4 octets }
    AlignResPos(4);
    CStyle   := ReadDWord;
    CExStyle := ReadDWord;
    CX2 := ReadWord;
    CY2 := ReadWord;
    CCX := ReadWord;
    CCY := ReadWord;
    CId := ReadWord;
    ReadIdOrName(CtrlClassIsId, CtrlClassId, CtrlClassName);
    ReadIdOrName(CtrlTitleIsId, CtrlTitleId, CtrlTitleStr);
    ExtraCount := ReadWord;
    If ExtraCount > 0 Then
      SkipBytes(ExtraCount);
    { Stocker dans le tableau global DialogControls }
    If DialogCtrlCount < MAX_DIALOG_CTRL Then
    Begin
      Inc(DialogCtrlCount);
      Ctrl.Style     := CStyle;
      Ctrl.ExStyle   := CExStyle;
      Ctrl.X         := CX2;
      Ctrl.Y         := CY2;
      Ctrl.CX        := CCX;
      Ctrl.CY        := CCY;
      Ctrl.Id        := CId;
      Ctrl.ClassIsId := CtrlClassIsId;
      Ctrl.ClassId   := CtrlClassId;
      Ctrl.ClassName := CtrlClassName;
      Ctrl.TitleIsId := CtrlTitleIsId;
      Ctrl.TitleId   := CtrlTitleId;
      Ctrl.TitleStr  := CtrlTitleStr;
      DialogControls[DialogCtrlCount] := Ctrl;
    End;
    { Determiner le nom de classe pour le RC }
    If CtrlClassIsId Then
      CtrlClassNameRC := '"' + WindowClassAtomToStr(CtrlClassId) + '"'
    Else
      CtrlClassNameRC := '"' + CtrlClassName + '"';
    { Determiner le titre pour le RC }
    If CtrlTitleIsId Then
      CtrlTitleRC := IntToStr(CtrlTitleId)
    Else
      CtrlTitleRC := '"' + EscapeRCString(CtrlTitleStr) + '"';
    { Generer la ligne CONTROL }
    If DialogRCLineCount < MAX_DIALOG_LINES Then
    Begin
      Inc(DialogRCLineCount);
      DialogRCLines[DialogRCLineCount] :=
        '    CONTROL ' + CtrlTitleRC + ', ' + IntToStr(CId) + ', ' +
        CtrlClassNameRC + ', ' + IntToStr(CStyle) + ', ' +
        IntToStr(CX2) + ', ' + IntToStr(CY2) + ', ' +
        IntToStr(CCX) + ', ' + IntToStr(CCY);
    End;
  End;
  If DialogRCLineCount < MAX_DIALOG_LINES Then
  Begin
    Inc(DialogRCLineCount);
    DialogRCLines[DialogRCLineCount] := 'END';
  End;
  { Afficher si mode verbeux }
  If Opts.Verbose Then
    For I := StartLine + 1 To DialogRCLineCount Do
      WriteLn(DialogRCLines[I]);
End;

{ ---- Decoder tous les dialogues ---------------------------- }
Procedure ParseAllDialogs;
Var
  I         : Integer;
  DlgCount  : Integer;
Begin
  DialogCtrlCount   := 0;
  DialogRCLineCount := 0;
  DlgCount          := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_DIALOG) Then
    Begin
      ParseDialogTemplate(Resources[I]);
      Inc(DlgCount);
    End;
  End;
  If Opts.Verbose Then
    WriteLn(DlgCount, ' dialogue(s) decode(s), ',
            DialogCtrlCount, ' controle(s) au total.');
End;

{ ============================================================
  TODO 15 - DECODAGE RT_VERSION (TYPE 16) [IMPLEMENTE]
  ============================================================ }

{ ---- Formater un LongInt en hexadecimal style RC ---------- }
Function HexLong(D : LongInt) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := HexDWord(D);
  I := 1;
  While (I < Length(S)) And (S[I] = '0') Do
    Inc(I);
  HexLong := '0x' + Copy(S, I, Length(S) - I + 1) + 'L';
End;

{ ---- Lire le bloc VS_FIXEDFILEINFO ------------------------ }
Procedure ParseVSFixedFileInfo(Var Info : TVersionInfo);
Var
  Sig : LongInt;
Begin
  Sig := ReadDWord;
  If Sig <> VS_FFI_SIGNATURE Then
    Exit;
  ReadDWord;                          { dwStrucVersion }
  Info.FileVersionMS    := ReadDWord;
  Info.FileVersionLS    := ReadDWord;
  Info.ProductVersionMS := ReadDWord;
  Info.ProductVersionLS := ReadDWord;
  Info.FileFlagsMask    := ReadDWord;
  Info.FileFlags        := ReadDWord;
  Info.FileOS           := ReadDWord;
  Info.FileType         := ReadDWord;
  Info.FileSubtype      := ReadDWord;
  ReadDWord;                          { dwFileDateMS }
  ReadDWord;                          { dwFileDateLS }
End;

{ ---- Lire les blocs StringFileInfo recursivement ---------- }
Procedure ParseVersionStringBlock(Var Info : TVersionInfo);
Var
  BlockStart : LongInt;
  BlockLen   : Word;
  TableStart : LongInt;
  TableLen   : Word;
  EntryStart : LongInt;
  EntryLen   : Word;
  SKey       : TString;
  SVal       : TString;
  W          : Word;
Begin
  BlockStart := ResFilePos;
  BlockLen   := ReadWord;
  ReadWord;                     { wValueLength = 0 }
  ReadWord;                     { wType = 1 }
  ReadUnicodeString;            { szKey = "StringFileInfo" }
  AlignResPos(4);
  If BlockLen = 0 Then Exit;
  { Parser chaque StringTable }
  While ResFilePos < BlockStart + BlockLen Do
  Begin
    TableStart := ResFilePos;
    TableLen   := ReadWord;
    If TableLen = 0 Then Break;
    ReadWord;                   { wValueLength = 0 }
    ReadWord;                   { wType = 1 }
    Info.StringTableKey := ReadUnicodeString;  { ex. "040904b0" }
    AlignResPos(4);
    { Parser chaque entree de chaine }
    While ResFilePos < TableStart + TableLen Do
    Begin
      EntryStart := ResFilePos;
      EntryLen   := ReadWord;
      If EntryLen = 0 Then Break;
      ReadWord;                 { wValueLength }
      ReadWord;                 { wType = 1 }
      SKey := ReadUnicodeString;
      AlignResPos(4);
      { Lire la valeur jusqu au nul ou fin d entree }
      SVal := '';
      While ResFilePos < EntryStart + EntryLen Do
      Begin
        W := ReadWChar;
        If W = 0 Then Break;
        SVal := SVal + WCharToChar(W);
      End;
      { Stocker la paire cle-valeur }
      If (SKey <> '') And (Info.StringCount < MAX_VERSION_STRINGS) Then
      Begin
        Inc(Info.StringCount);
        Info.StringValues[Info.StringCount].Key   := SKey;
        Info.StringValues[Info.StringCount].Value := SVal;
      End;
      SeekResPos(EntryStart + EntryLen);
    End;
    SeekResPos(TableStart + TableLen);
  End;
  SeekResPos(BlockStart + BlockLen);
End;

{ ---- Lire le bloc VarFileInfo ----------------------------- }
Procedure ParseVersionVarBlock(Var Info : TVersionInfo);
Var
  BlockStart : LongInt;
  BlockLen   : Word;
  VarStart   : LongInt;
  VarLen     : Word;
Begin
  BlockStart := ResFilePos;
  BlockLen   := ReadWord;
  ReadWord;                     { wValueLength = 0 }
  ReadWord;                     { wType = 1 }
  ReadUnicodeString;            { szKey = "VarFileInfo" }
  AlignResPos(4);
  If BlockLen = 0 Then Exit;
  If ResFilePos < BlockStart + BlockLen Then
  Begin
    VarStart := ResFilePos;
    VarLen   := ReadWord;
    If VarLen > 0 Then
    Begin
      ReadWord;                 { wValueLength }
      ReadWord;                 { wType = 0 }
      ReadUnicodeString;        { szKey = "Translation" }
      AlignResPos(4);
      If ResFilePos < VarStart + VarLen Then
      Begin
        Info.TranslationLang := ReadWord;
        Info.TranslationCP   := ReadWord;
      End;
    End;
  End;
  SeekResPos(BlockStart + BlockLen);
End;

{ ---- Generer les lignes RC pour une ressource de version -- }
Procedure VersionInfoToRC(Const Info    : TVersionInfo;
                          Const ResName : TString);
  Procedure AddLine(Const S : TString);
  Begin
    If VersionRCLineCount < MAX_VERSION_LINES Then
    Begin
      Inc(VersionRCLineCount);
      VersionRCLines[VersionRCLineCount] := S;
    End;
  End;
  Function VerStr(MS, LS : LongInt) : TString;
  Begin
    VerStr := IntToStr(Word(MS Shr 16)) + ', ' +
              IntToStr(Word(MS And $FFFF)) + ', ' +
              IntToStr(Word(LS Shr 16)) + ', ' +
              IntToStr(Word(LS And $FFFF));
  End;
Var
  I        : Integer;
  BlkKey   : TString;
Begin
  AddLine(ResName + ' VERSIONINFO');
  AddLine('FILEVERSION '    + VerStr(Info.FileVersionMS,    Info.FileVersionLS));
  AddLine('PRODUCTVERSION ' + VerStr(Info.ProductVersionMS, Info.ProductVersionLS));
  AddLine('FILEFLAGSMASK '  + HexLong(Info.FileFlagsMask));
  AddLine('FILEFLAGS '      + HexLong(Info.FileFlags));
  AddLine('FILEOS '         + HexLong(Info.FileOS));
  AddLine('FILETYPE '       + HexLong(Info.FileType));
  AddLine('FILESUBTYPE '    + HexLong(Info.FileSubtype));
  AddLine('BEGIN');
  If Info.StringCount > 0 Then
  Begin
    AddLine('    BLOCK "StringFileInfo"');
    AddLine('    BEGIN');
    If Info.StringTableKey <> '' Then
      BlkKey := Info.StringTableKey
    Else
      BlkKey := HexWord(Info.TranslationLang) + HexWord(Info.TranslationCP);
    AddLine('        BLOCK "' + BlkKey + '"');
    AddLine('        BEGIN');
    For I := 1 To Info.StringCount Do
      AddLine('            VALUE "' + Info.StringValues[I].Key + '", "' +
              EscapeRCString(Info.StringValues[I].Value) + '"');
    AddLine('        END');
    AddLine('    END');
  End;
  If (Info.TranslationLang <> 0) Or (Info.TranslationCP <> 0) Then
  Begin
    AddLine('    BLOCK "VarFileInfo"');
    AddLine('    BEGIN');
    AddLine('        VALUE "Translation", 0x' +
            HexWord(Info.TranslationLang) + ', 0x' +
            HexWord(Info.TranslationCP));
    AddLine('    END');
  End;
  AddLine('END');
End;

{ ---- Decoder une ressource RT_VERSION --------------------- }
Procedure ParseVersionInfo(Const Res     : TResourceEntry;
                           Var   Info    : TVersionInfo);
Var
  ResStart : LongInt;
  ResLen   : Word;
  ValLen   : Word;
  SavePos  : LongInt;
  BlockLen : Word;
  BlockKey : TString;
Begin
  { Initialiser la structure }
  Info.FileVersionMS    := 0;
  Info.FileVersionLS    := 0;
  Info.ProductVersionMS := 0;
  Info.ProductVersionLS := 0;
  Info.FileOS           := VOS_UNKNOWN;
  Info.FileType         := VFT_UNKNOWN;
  Info.FileSubtype      := 0;
  Info.FileFlags        := 0;
  Info.FileFlagsMask    := 0;
  Info.StringTableKey   := '';
  Info.StringCount      := 0;
  Info.TranslationLang  := 0;
  Info.TranslationCP    := 0;
  SeekResPos(Res.DataOfs);
  ResStart := ResFilePos;
  ResLen   := ReadWord;        { wLength total }
  ValLen   := ReadWord;        { wValueLength = 52 si VS_FIXEDFILEINFO }
  ReadWord;                    { wType = 0 }
  ReadUnicodeString;           { szKey = "VS_VERSION_INFO" }
  AlignResPos(4);
  { Lire VS_FIXEDFILEINFO si present }
  If ValLen > 0 Then
    ParseVSFixedFileInfo(Info);
  AlignResPos(4);
  { Parser les blocs enfants StringFileInfo et VarFileInfo }
  While ResFilePos < ResStart + ResLen Do
  Begin
    SavePos  := ResFilePos;
    BlockLen := ReadWord;
    If BlockLen = 0 Then Break;
    ReadWord;                  { wValueLength }
    ReadWord;                  { wType }
    BlockKey := ReadUnicodeString;
    SeekResPos(SavePos);
    If UpCaseStr(BlockKey) = 'STRINGFILEINFO' Then
      ParseVersionStringBlock(Info)
    Else If UpCaseStr(BlockKey) = 'VARFILEINFO' Then
      ParseVersionVarBlock(Info)
    Else
      Break;
  End;
End;

{ ---- Decoder toutes les ressources RT_VERSION ------------- }
Procedure ParseAllVersionInfos;
Var
  I        : Integer;
  VerCount : Integer;
  Info     : TVersionInfo;
  ResName  : TString;
Begin
  VersionInfoCount   := 0;
  VersionRCLineCount := 0;
  VerCount           := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_VERSION) Then
    Begin
      ParseVersionInfo(Resources[I], Info);
      If Resources[I].NameIsId Then
        ResName := IntToStr(Resources[I].NameId)
      Else
        ResName := Resources[I].NameStr;
      VersionInfoToRC(Info, ResName);
      If VersionInfoCount < MAX_VERSION_INFO Then
      Begin
        Inc(VersionInfoCount);
        VersionInfos[VersionInfoCount] := Info;
      End;
      Inc(VerCount);
    End;
  End;
  If Opts.Verbose Then
    WriteLn(VerCount, ' ressource(s) de version decodee(s), ',
            VersionRCLineCount, ' ligne(s) RC generee(s).');
End;

{ ============================================================
  TODO 16 - DECODAGE RT_ICON / RT_CURSOR (TYPES 3 ET 1) [IMPLEMENTE]
  ============================================================ }

{ ---- Lire les octets bruts d une ressource dans un tampon -- }
Procedure ReadRawResourceBytes(Const Res     : TResourceEntry;
                               Var   Buf     : PByteArray;
                               Var   BufSize : LongInt);
Var
  I : LongInt;
Begin
  BufSize := Res.DataSize;
  If BufSize <= 0 Then
  Begin
    Buf := Nil;
    Exit;
  End;
  GetMem(Buf, BufSize);
  SeekResPos(Res.DataOfs);
  For I := 0 To BufSize - 1 Do
    Buf^[I] := ReadByte;
End;

{ ---- Extraire une icone RT_ICON vers un fichier .ico ------- }
Procedure ExtractIconFile(Const Res     : TResourceEntry;
                          Const OutFile : TString);
Var
  F           : File Of Byte;
  biWidth     : LongInt;
  biHeight    : LongInt;
  biBitCount  : Word;
  biClrUsed   : LongInt;
  AWidth      : Byte;
  AHeight     : Byte;
  AColorCount : Byte;
  I           : LongInt;
  B           : Byte;
  Lo_         : Byte;
  Hi_         : Byte;
  Procedure WriteW(V : Word);
  Begin
    Lo_ := V And $FF;
    Hi_ := (V Shr 8) And $FF;
    Write(F, Lo_);
    Write(F, Hi_);
  End;
  Procedure WriteL(V : LongInt);
  Begin
    WriteW(Word(V And $FFFF));
    WriteW(Word((V Shr 16) And $FFFF));
  End;
Begin
  If Res.DataSize < 40 Then Exit;
  { Lire les champs cles du BITMAPINFOHEADER }
  SeekResPos(Res.DataOfs);
  ReadDWord;                        { biSize            }
  biWidth    := ReadDWord;          { biWidth           }
  biHeight   := ReadDWord;          { biHeight (double) }
  ReadWord;                         { biPlanes          }
  biBitCount := ReadWord;           { biBitCount        }
  ReadDWord;                        { biCompression     }
  ReadDWord;                        { biSizeImage       }
  ReadDWord;                        { biXPelsPerMeter   }
  ReadDWord;                        { biYPelsPerMeter   }
  biClrUsed  := ReadDWord;          { biClrUsed         }
  { La hauteur DIB est doublee (masques XOR et AND) }
  biHeight := biHeight Div 2;
  { Convertir en valeurs TIconDirEntry }
  If biWidth  >= 256 Then AWidth  := 0 Else AWidth  := Byte(biWidth);
  If biHeight >= 256 Then AHeight := 0 Else AHeight := Byte(biHeight);
  { Calculer le nombre de couleurs }
  If biBitCount >= 16 Then
    AColorCount := 0
  Else If biClrUsed > 0 Then
  Begin
    If biClrUsed >= 256 Then AColorCount := 0
    Else AColorCount := Byte(biClrUsed);
  End
  Else If biBitCount > 0 Then
  Begin
    If (LongInt(1) Shl biBitCount) >= 256 Then AColorCount := 0
    Else AColorCount := Byte(LongInt(1) Shl biBitCount);
  End
  Else
    AColorCount := 0;
  { Creer le fichier .ico }
  Assign(F, OutFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  { Ecrire TIconHeader (6 octets) }
  WriteW(0);                        { Reserved = 0     }
  WriteW(1);                        { ResType  = 1 ICO }
  WriteW(1);                        { Count    = 1     }
  { Ecrire TIconDirEntry (16 octets) }
  { ImageOfs = 6 (TIconHeader) + 16 (TIconDirEntry) = 22 }
  Write(F, AWidth);
  Write(F, AHeight);
  Write(F, AColorCount);
  B := 0; Write(F, B);              { Reserved = 0     }
  WriteW(1);                        { Planes   = 1     }
  WriteW(biBitCount);
  WriteL(Res.DataSize);             { BytesInRes       }
  WriteL(22);                       { ImageOfs = 22    }
  { Ecrire les donnees DIB brutes }
  SeekResPos(Res.DataOfs);
  For I := 1 To Res.DataSize Do
  Begin
    B := ReadByte;
    Write(F, B);
  End;
  Close(F);
End;

{ ---- Extraire un curseur RT_CURSOR vers un fichier .cur ---- }
Procedure ExtractCursorFile(Const Res     : TResourceEntry;
                             Const OutFile : TString);
Var
  F           : File Of Byte;
  HotX        : Word;
  HotY        : Word;
  biWidth     : LongInt;
  biHeight    : LongInt;
  biBitCount  : Word;
  biClrUsed   : LongInt;
  AWidth      : Byte;
  AHeight     : Byte;
  AColorCount : Byte;
  DibSize     : LongInt;
  I           : LongInt;
  B           : Byte;
  Lo_         : Byte;
  Hi_         : Byte;
  Procedure WriteW(V : Word);
  Begin
    Lo_ := V And $FF;
    Hi_ := (V Shr 8) And $FF;
    Write(F, Lo_);
    Write(F, Hi_);
  End;
  Procedure WriteL(V : LongInt);
  Begin
    WriteW(Word(V And $FFFF));
    WriteW(Word((V Shr 16) And $FFFF));
  End;
Begin
  { 4 octets hotspot + 40 octets BITMAPINFOHEADER minimum }
  If Res.DataSize < 44 Then Exit;
  { Lire le hotspot puis les champs BITMAPINFOHEADER }
  SeekResPos(Res.DataOfs);
  HotX := ReadWord;                 { hotspot X         }
  HotY := ReadWord;                 { hotspot Y         }
  ReadDWord;                        { biSize            }
  biWidth    := ReadDWord;          { biWidth           }
  biHeight   := ReadDWord;          { biHeight (double) }
  ReadWord;                         { biPlanes          }
  biBitCount := ReadWord;           { biBitCount        }
  ReadDWord;                        { biCompression     }
  ReadDWord;                        { biSizeImage       }
  ReadDWord;                        { biXPelsPerMeter   }
  ReadDWord;                        { biYPelsPerMeter   }
  biClrUsed  := ReadDWord;          { biClrUsed         }
  biHeight := biHeight Div 2;
  If biWidth  >= 256 Then AWidth  := 0 Else AWidth  := Byte(biWidth);
  If biHeight >= 256 Then AHeight := 0 Else AHeight := Byte(biHeight);
  If biBitCount >= 16 Then
    AColorCount := 0
  Else If biClrUsed > 0 Then
  Begin
    If biClrUsed >= 256 Then AColorCount := 0
    Else AColorCount := Byte(biClrUsed);
  End
  Else If biBitCount > 0 Then
  Begin
    If (LongInt(1) Shl biBitCount) >= 256 Then AColorCount := 0
    Else AColorCount := Byte(LongInt(1) Shl biBitCount);
  End
  Else
    AColorCount := 0;
  { Les donnees DIB ne comprennent pas les 4 octets de hotspot }
  DibSize := Res.DataSize - 4;
  Assign(F, OutFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  { Ecrire TIconHeader (6 octets) }
  WriteW(0);                        { Reserved = 0     }
  WriteW(2);                        { ResType  = 2 CUR }
  WriteW(1);                        { Count    = 1     }
  { Ecrire TIconDirEntry (16 octets) }
  { Pour .cur : Planes = HotX, BitCount = HotY }
  Write(F, AWidth);
  Write(F, AHeight);
  Write(F, AColorCount);
  B := 0; Write(F, B);              { Reserved = 0     }
  WriteW(HotX);                     { Planes   = HotX  }
  WriteW(HotY);                     { BitCount = HotY  }
  WriteL(DibSize);                  { BytesInRes       }
  WriteL(22);                       { ImageOfs = 22    }
  { Ecrire les donnees DIB brutes (sans les 4 octets de hotspot) }
  SeekResPos(Res.DataOfs + 4);
  For I := 1 To DibSize Do
  Begin
    B := ReadByte;
    Write(F, B);
  End;
  Close(F);
End;

{ ---- Decoder / extraire toutes les icones RT_ICON ---------- }
Procedure ParseAllIcons;
Var
  I         : Integer;
  IconCount : Integer;
  OutName   : TString;
Begin
  IconCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_ICON) Then
    Begin
      Inc(IconCount);
      If Opts.ExtractBin Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'ICON_' + IntToStr(Resources[I].NameId) + '.ico'
        Else
          OutName := 'ICON_' + Resources[I].NameStr + '.ico';
        ExtractIconFile(Resources[I], OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
          WriteLn('  Icone extraite : ', OutName,
                  ' (', Resources[I].DataSize, ' octets)');
      End;
    End;
  End;
  If Opts.Verbose And (IconCount > 0) Then
    WriteLn(IconCount, ' ressource(s) RT_ICON trouvee(s).');
End;

{ ---- Decoder / extraire tous les curseurs RT_CURSOR -------- }
Procedure ParseAllCursors;
Var
  I           : Integer;
  CursorCount : Integer;
  OutName     : TString;
Begin
  CursorCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_CURSOR) Then
    Begin
      Inc(CursorCount);
      If Opts.ExtractBin Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'CURSOR_' + IntToStr(Resources[I].NameId) + '.cur'
        Else
          OutName := 'CURSOR_' + Resources[I].NameStr + '.cur';
        ExtractCursorFile(Resources[I], OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
          WriteLn('  Curseur extrait: ', OutName,
                  ' (', Resources[I].DataSize, ' octets)');
      End;
    End;
  End;
  If Opts.Verbose And (CursorCount > 0) Then
    WriteLn(CursorCount, ' ressource(s) RT_CURSOR trouvee(s).');
End;

{ ============================================================
  TODO 17 - DECODAGE RT_BITMAP (TYPE 2) [IMPLEMENTE]
  ============================================================ }

{ ---- Extraire une bitmap RT_BITMAP vers un fichier .bmp ---- }
Procedure ExtractBitmapFile(Const Res     : TResourceEntry;
                             Const OutFile : TString);
Var
  F              : File Of Byte;
  biSize         : LongInt;
  biBitCount     : Word;
  biSizeImage    : LongInt;
  biClrUsed      : LongInt;
  bfOffBits      : LongInt;
  bfSize         : LongInt;
  NumColors      : LongInt;
  I              : LongInt;
  B              : Byte;
  Lo_            : Byte;
  Hi_            : Byte;
  Procedure WriteW(V : Word);
  Begin
    Lo_ := V And $FF;
    Hi_ := (V Shr 8) And $FF;
    Write(F, Lo_);
    Write(F, Hi_);
  End;
  Procedure WriteL(V : LongInt);
  Begin
    WriteW(Word(V And $FFFF));
    WriteW(Word((V Shr 16) And $FFFF));
  End;
Begin
  If Res.DataSize < 40 Then Exit;
  { Lire les champs cles du BITMAPINFOHEADER }
  SeekResPos(Res.DataOfs);
  biSize        := ReadDWord;   { biSize (= 40 en general)  }
  ReadDWord;                    { biWidth                   }
  ReadDWord;                    { biHeight                  }
  ReadWord;                     { biPlanes                  }
  biBitCount    := ReadWord;    { biBitCount                }
  ReadDWord;                    { biCompression             }
  biSizeImage   := ReadDWord;   { biSizeImage               }
  ReadDWord;                    { biXPelsPerMeter           }
  ReadDWord;                    { biYPelsPerMeter           }
  biClrUsed     := ReadDWord;   { biClrUsed                 }
  { Calculer le nombre de couleurs dans la palette }
  If biClrUsed > 0 Then
    NumColors := biClrUsed
  Else If biBitCount <= 8 Then
    NumColors := LongInt(1) Shl biBitCount
  Else
    NumColors := 0;
  { Calculer les offsets du BITMAPFILEHEADER }
  { 14 = sizeof(BITMAPFILEHEADER) : bfType(2)+bfSize(4)+bfRes1(2)+bfRes2(2)+bfOffBits(4) }
  bfOffBits := 14 + biSize + NumColors * 4;
  { Si biSizeImage = 0 (BI_RGB non compresse), utiliser la taille des donnees restantes }
  If biSizeImage = 0 Then
  Begin
    biSizeImage := Res.DataSize - biSize - NumColors * 4;
    If biSizeImage < 0 Then biSizeImage := 0;
  End;
  bfSize := bfOffBits + biSizeImage;
  { Creer le fichier .bmp }
  Assign(F, OutFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  { Ecrire le BITMAPFILEHEADER (14 octets) }
  WriteW($4D42);                { bfType = 'BM'            }
  WriteL(bfSize);               { bfSize                   }
  WriteW(0);                    { bfReserved1 = 0          }
  WriteW(0);                    { bfReserved2 = 0          }
  WriteL(bfOffBits);            { bfOffBits                }
  { Ecrire les donnees brutes (BITMAPINFOHEADER + palette + pixels) }
  SeekResPos(Res.DataOfs);
  For I := 1 To Res.DataSize Do
  Begin
    B := ReadByte;
    Write(F, B);
  End;
  Close(F);
End;

{ ---- Retourner une description de la bitmap -------------- }
Function BitmapInfoLine(Const Res : TResourceEntry) : TString;
Var
  biWidth    : LongInt;
  biHeight   : LongInt;
  biBitCount : Word;
Begin
  BitmapInfoLine := '';
  If Res.DataSize < 40 Then Exit;
  SeekResPos(Res.DataOfs);
  ReadDWord;                        { biSize   }
  biWidth    := ReadDWord;          { biWidth  }
  biHeight   := ReadDWord;          { biHeight }
  ReadWord;                         { biPlanes }
  biBitCount := ReadWord;           { biBitCount }
  BitmapInfoLine := 'W=' + IntToStr(biWidth) +
                    ' H=' + IntToStr(biHeight) +
                    ' BPP=' + IntToStr(biBitCount);
End;

{ ---- Decoder / extraire toutes les bitmaps RT_BITMAP ----- }
Procedure ParseAllBitmaps;
Var
  I           : Integer;
  BitmapCount : Integer;
  OutName     : TString;
  InfoStr     : TString;
Begin
  BitmapCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_BITMAP) Then
    Begin
      Inc(BitmapCount);
      If Opts.ExtractBin Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'BITMAP_' + IntToStr(Resources[I].NameId) + '.bmp'
        Else
          OutName := 'BITMAP_' + Resources[I].NameStr + '.bmp';
        ExtractBitmapFile(Resources[I], OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
        Begin
          InfoStr := BitmapInfoLine(Resources[I]);
          WriteLn('  Bitmap extraite: ', OutName,
                  ' (', Resources[I].DataSize, ' octets) ', InfoStr);
        End;
      End Else If Opts.Verbose Then
      Begin
        InfoStr := BitmapInfoLine(Resources[I]);
        If Resources[I].NameIsId Then
          WriteLn('  RT_BITMAP #', Resources[I].NameId, ' : ', InfoStr)
        Else
          WriteLn('  RT_BITMAP "', Resources[I].NameStr, '" : ', InfoStr);
      End;
    End;
  End;
  If Opts.Verbose And (BitmapCount > 0) Then
    WriteLn(BitmapCount, ' ressource(s) RT_BITMAP trouvee(s).');
End;


{ ============================================================
  TODO 18 - DECODAGE RT_GROUP_ICON / RT_GROUP_CURSOR (TYPES 14 ET 12) [IMPLEMENTE]
  ============================================================ }

{ ---- Trouver la ressource RT_ICON/RT_CURSOR par son NameId -- }
Function FindIconById(TypeId : Word; IconId : Word) : Integer;
Var
  J : Integer;
Begin
  FindIconById := 0;
  For J := 1 To ResCount Do
    If Resources[J].TypeIsId And (Resources[J].TypeId = TypeId) Then
      If Resources[J].NameIsId And (Resources[J].NameId = IconId) Then
      Begin
        FindIconById := J;
        Exit;
      End;
End;

{ ---- Analyser un groupe d icones RT_GROUP_ICON --------------- }
Procedure ParseGroupIcon(Const Res : TResourceEntry);
Var
  Reserved : Word;
  ResType  : Word;
  Count    : Word;
  I        : Integer;
  GrpIdx   : Integer;
  E        : TGrpIconDirEntry;
Begin
  If Res.DataSize < 6 Then Exit;
  SeekResPos(Res.DataOfs);
  Reserved := ReadWord;   { doit etre 0  }
  ResType  := ReadWord;   { 1 = icone    }
  Count    := ReadWord;   { nb d images  }
  If Count = 0 Then Exit;
  If GroupIconCount >= MAX_GRP_ICONS Then Exit;
  Inc(GroupIconCount);
  GrpIdx := GroupIconCount;
  GroupIcons[GrpIdx].IsCursor := False;
  If Res.NameIsId Then
    GroupIcons[GrpIdx].GroupId := Res.NameId
  Else
    GroupIcons[GrpIdx].GroupId := 0;
  If Count > MAX_GRP_ENTRIES Then
    GroupIcons[GrpIdx].Count := MAX_GRP_ENTRIES
  Else
    GroupIcons[GrpIdx].Count := Count;
  For I := 1 To GroupIcons[GrpIdx].Count Do
  Begin
    E.Width      := ReadByte;
    E.Height     := ReadByte;
    E.ColorCount := ReadByte;
    E.Reserved   := ReadByte;
    E.Planes     := ReadWord;
    E.BitCount   := ReadWord;
    E.BytesInRes := ReadDWord;
    E.Id         := ReadWord;
    GroupIcons[GrpIdx].Entries[I] := E;
  End;
  { Lire et ignorer les entrees supplementaires si Count > MAX_GRP_ENTRIES }
  For I := MAX_GRP_ENTRIES + 1 To Count Do
  Begin
    ReadByte; ReadByte; ReadByte; ReadByte;   { Width/Height/ColorCount/Reserved }
    ReadWord; ReadWord;                        { Planes/BitCount }
    ReadDWord;                                 { BytesInRes }
    ReadWord;                                  { Id }
  End;
End;

{ ---- Assembler un fichier .ico pour un groupe d icones ------- }
Procedure BuildGroupIconFile(GrpIdx : Integer; Const OutFile : TString);
Var
  F       : File Of Byte;
  N       : Integer;
  I       : Integer;
  ResIdx  : Integer;
  Offset  : LongInt;
  J       : LongInt;
  B       : Byte;
  Lo_     : Byte;
  Hi_     : Byte;
  E       : TGrpIconDirEntry;
  Procedure WriteW(V : Word);
  Begin
    Lo_ := V And $FF;
    Hi_ := (V Shr 8) And $FF;
    Write(F, Lo_);
    Write(F, Hi_);
  End;
  Procedure WriteL(V : LongInt);
  Begin
    WriteW(Word(V And $FFFF));
    WriteW(Word((V Shr 16) And $FFFF));
  End;
Begin
  N := GroupIcons[GrpIdx].Count;
  If N = 0 Then Exit;
  Assign(F, OutFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  { Ecrire l en-tete ICONDIR (6 octets) }
  WriteW(0);                  { Reserved = 0     }
  WriteW(1);                  { Type     = 1 ICO }
  WriteW(N);                  { Count            }
  { Calculer l offset du debut des donnees :
    6 (ICONDIR) + N * 16 (ICONDIRENTRY) }
  Offset := 6 + LongInt(N) * 16;
  { Ecrire N entrees ICONDIRENTRY (16 octets chacune) }
  For I := 1 To N Do
  Begin
    E := GroupIcons[GrpIdx].Entries[I];
    Write(F, E.Width);
    Write(F, E.Height);
    Write(F, E.ColorCount);
    B := 0; Write(F, B);      { Reserved = 0 }
    WriteW(E.Planes);
    WriteW(E.BitCount);
    WriteL(E.BytesInRes);
    WriteL(Offset);
    Offset := Offset + E.BytesInRes;
  End;
  { Ecrire les donnees DIB brutes de chaque RT_ICON }
  For I := 1 To N Do
  Begin
    E := GroupIcons[GrpIdx].Entries[I];
    ResIdx := FindIconById(RT_ICON, E.Id);
    If ResIdx > 0 Then
    Begin
      SeekResPos(Resources[ResIdx].DataOfs);
      For J := 1 To Resources[ResIdx].DataSize Do
      Begin
        B := ReadByte;
        Write(F, B);
      End;
    End Else
    Begin
      { Ressource manquante : ecrire des zeros }
      B := 0;
      For J := 1 To E.BytesInRes Do
        Write(F, B);
    End;
  End;
  Close(F);
End;

{ ---- Analyser un groupe de curseurs RT_GROUP_CURSOR ---------- }
Procedure ParseGroupCursor(Const Res : TResourceEntry);
Var
  Reserved : Word;
  ResType  : Word;
  Count    : Word;
  I        : Integer;
  GrpIdx   : Integer;
  E        : TGrpIconDirEntry;
Begin
  If Res.DataSize < 6 Then Exit;
  SeekResPos(Res.DataOfs);
  Reserved := ReadWord;   { doit etre 0  }
  ResType  := ReadWord;   { 2 = curseur  }
  Count    := ReadWord;   { nb d images  }
  If Count = 0 Then Exit;
  If GroupIconCount >= MAX_GRP_ICONS Then Exit;
  Inc(GroupIconCount);
  GrpIdx := GroupIconCount;
  GroupIcons[GrpIdx].IsCursor := True;
  If Res.NameIsId Then
    GroupIcons[GrpIdx].GroupId := Res.NameId
  Else
    GroupIcons[GrpIdx].GroupId := 0;
  If Count > MAX_GRP_ENTRIES Then
    GroupIcons[GrpIdx].Count := MAX_GRP_ENTRIES
  Else
    GroupIcons[GrpIdx].Count := Count;
  For I := 1 To GroupIcons[GrpIdx].Count Do
  Begin
    E.Width      := ReadByte;
    E.Height     := ReadByte;
    E.ColorCount := ReadByte;
    E.Reserved   := ReadByte;
    E.Planes     := ReadWord;
    E.BitCount   := ReadWord;
    E.BytesInRes := ReadDWord;
    E.Id         := ReadWord;
    GroupIcons[GrpIdx].Entries[I] := E;
  End;
  For I := MAX_GRP_ENTRIES + 1 To Count Do
  Begin
    ReadByte; ReadByte; ReadByte; ReadByte;
    ReadWord; ReadWord;
    ReadDWord;
    ReadWord;
  End;
End;

{ ---- Assembler un fichier .cur pour un groupe de curseurs ---- }
Procedure BuildGroupCursorFile(GrpIdx : Integer; Const OutFile : TString);
Var
  F       : File Of Byte;
  N       : Integer;
  I       : Integer;
  ResIdx  : Integer;
  Offset  : LongInt;
  J       : LongInt;
  B       : Byte;
  Lo_     : Byte;
  Hi_     : Byte;
  E       : TGrpIconDirEntry;
  DibSize : LongInt;
  Procedure WriteW(V : Word);
  Begin
    Lo_ := V And $FF;
    Hi_ := (V Shr 8) And $FF;
    Write(F, Lo_);
    Write(F, Hi_);
  End;
  Procedure WriteL(V : LongInt);
  Begin
    WriteW(Word(V And $FFFF));
    WriteW(Word((V Shr 16) And $FFFF));
  End;
Begin
  N := GroupIcons[GrpIdx].Count;
  If N = 0 Then Exit;
  Assign(F, OutFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  { Ecrire l en-tete CURSORDIR (6 octets) }
  WriteW(0);                  { Reserved = 0     }
  WriteW(2);                  { Type     = 2 CUR }
  WriteW(N);                  { Count            }
  Offset := 6 + LongInt(N) * 16;
  { Ecrire N entrees ICONDIRENTRY pour .cur (16 octets chacune) }
  For I := 1 To N Do
  Begin
    E := GroupIcons[GrpIdx].Entries[I];
    Write(F, E.Width);
    Write(F, E.Height);
    Write(F, E.ColorCount);
    B := 0; Write(F, B);
    WriteW(E.Planes);   { Planes  = hotspot X pour .cur }
    WriteW(E.BitCount); { BitCount = hotspot Y pour .cur }
    { Les donnees RT_CURSOR contiennent 4 octets hotspot + DIB
      la taille dans le .cur est sans le hotspot }
    DibSize := E.BytesInRes - 4;
    If DibSize < 0 Then DibSize := E.BytesInRes;
    WriteL(DibSize);
    WriteL(Offset);
    Offset := Offset + DibSize;
  End;
  { Ecrire les donnees DIB brutes de chaque RT_CURSOR (sans le hotspot) }
  For I := 1 To N Do
  Begin
    E := GroupIcons[GrpIdx].Entries[I];
    ResIdx := FindIconById(RT_CURSOR, E.Id);
    If ResIdx > 0 Then
    Begin
      DibSize := Resources[ResIdx].DataSize - 4;
      If DibSize < 0 Then DibSize := 0;
      SeekResPos(Resources[ResIdx].DataOfs + 4);  { sauter le hotspot }
      For J := 1 To DibSize Do
      Begin
        B := ReadByte;
        Write(F, B);
      End;
    End Else
    Begin
      DibSize := E.BytesInRes - 4;
      If DibSize < 0 Then DibSize := 0;
      B := 0;
      For J := 1 To DibSize Do
        Write(F, B);
    End;
  End;
  Close(F);
End;

{ ---- Decoder / extraire tous les groupes d icones ------------ }
Procedure ParseAllGroupIcons;
Var
  I          : Integer;
  GrpCount   : Integer;
  OutName    : TString;
  GrpIdx     : Integer;
Begin
  GrpCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_GROUP_ICON) Then
    Begin
      Inc(GrpCount);
      GrpIdx := GroupIconCount + 1;
      ParseGroupIcon(Resources[I]);
      If Opts.ExtractBin And (GrpIdx <= GroupIconCount) Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'GROUP_ICON_' + IntToStr(Resources[I].NameId) + '.ico'
        Else
          OutName := 'GROUP_ICON_' + Resources[I].NameStr + '.ico';
        BuildGroupIconFile(GrpIdx, OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
          WriteLn('  Groupe icone extrait: ', OutName,
                  ' (', GroupIcons[GrpIdx].Count, ' image(s))');
      End Else If Opts.Verbose Then
      Begin
        If Resources[I].NameIsId Then
          WriteLn('  RT_GROUP_ICON #', Resources[I].NameId, ' : ',
                  GroupIcons[GrpIdx].Count, ' image(s)')
        Else
          WriteLn('  RT_GROUP_ICON "', Resources[I].NameStr, '" : ',
                  GroupIcons[GrpIdx].Count, ' image(s)');
      End;
    End;
  End;
  If Opts.Verbose And (GrpCount > 0) Then
    WriteLn(GrpCount, ' ressource(s) RT_GROUP_ICON trouvee(s).');
End;

{ ---- Decoder / extraire tous les groupes de curseurs --------- }
Procedure ParseAllGroupCursors;
Var
  I          : Integer;
  GrpCount   : Integer;
  OutName    : TString;
  GrpIdx     : Integer;
Begin
  GrpCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_GROUP_CURSOR) Then
    Begin
      Inc(GrpCount);
      GrpIdx := GroupIconCount + 1;
      ParseGroupCursor(Resources[I]);
      If Opts.ExtractBin And (GrpIdx <= GroupIconCount) Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'GROUP_CURSOR_' + IntToStr(Resources[I].NameId) + '.cur'
        Else
          OutName := 'GROUP_CURSOR_' + Resources[I].NameStr + '.cur';
        BuildGroupCursorFile(GrpIdx, OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
          WriteLn('  Groupe curseur extrait: ', OutName,
                  ' (', GroupIcons[GrpIdx].Count, ' image(s))');
      End Else If Opts.Verbose Then
      Begin
        If Resources[I].NameIsId Then
          WriteLn('  RT_GROUP_CURSOR #', Resources[I].NameId, ' : ',
                  GroupIcons[GrpIdx].Count, ' image(s)')
        Else
          WriteLn('  RT_GROUP_CURSOR "', Resources[I].NameStr, '" : ',
                  GroupIcons[GrpIdx].Count, ' image(s)');
      End;
    End;
  End;
  If Opts.Verbose And (GrpCount > 0) Then
    WriteLn(GrpCount, ' ressource(s) RT_GROUP_CURSOR trouvee(s).');
End;


{ ============================================================
  TODO 19 - DECODAGE RT_RCDATA (TYPE 10) [IMPLEMENTE]
  ============================================================ }

{ ---- Convertir N octets en ligne hex style RC --------------- }
Function RCDataToHexLine(Buf      : PByteArray;
                          StartOfs : LongInt;
                          Count    : Integer) : TString;
Var
  I : Integer;
  S : TString;
Begin
  S := '';
  For I := 0 To Count - 1 Do
  Begin
    If I > 0 Then S := S + ', ';
    S := S + '0x' + HexByte(Buf^[StartOfs + LongInt(I)]);
  End;
  RCDataToHexLine := S;
End;

{ ---- Analyser les octets d une ressource RT_RCDATA ---------- }
{ Ecrit les lignes hex directement dans RCDataRCLines          }
Procedure ParseRCData(Const Res : TResourceEntry);
Var
  Buf       : PByteArray;
  BufSize   : LongInt;
  Offset    : LongInt;
  BytesLeft : LongInt;
  Count     : Integer;
Begin
  ReadRawResourceBytes(Res, Buf, BufSize);
  If Buf = Nil Then Exit;
  Offset := 0;
  While (Offset < BufSize) And (RCDataRCLineCount < MAX_RCDATA_LINES) Do
  Begin
    BytesLeft := BufSize - Offset;
    If BytesLeft > RCDATA_BYTES_PER_LINE Then
      Count := RCDATA_BYTES_PER_LINE
    Else
      Count := Integer(BytesLeft);
    Inc(RCDataRCLineCount);
    RCDataRCLines[RCDataRCLineCount] :=
      '    ' + RCDataToHexLine(Buf, Offset, Count);
    Offset := Offset + LongInt(Count);
  End;
  FreeMem(Buf, BufSize);
End;

{ ---- Generer le bloc RC complet pour une ressource RCDATA --- }
{ ResId RCDATA BEGIN / lignes hex / END                        }
Procedure GenerateRCDataBlock(Const Res   : TResourceEntry;
                               Const ResId : TString);
Begin
  If RCDataRCLineCount >= MAX_RCDATA_LINES Then Exit;
  Inc(RCDataRCLineCount);
  RCDataRCLines[RCDataRCLineCount] := ResId + ' RCDATA BEGIN';
  ParseRCData(Res);
  If RCDataRCLineCount < MAX_RCDATA_LINES Then
  Begin
    Inc(RCDataRCLineCount);
    RCDataRCLines[RCDataRCLineCount] := 'END';
  End;
End;

{ ---- Decoder / afficher toutes les ressources RT_RCDATA ----- }
Procedure ParseAllRCData;
Var
  I           : Integer;
  RCDataCount : Integer;
  ResId       : TString;
  StartLine   : Integer;
  J           : Integer;
Begin
  RCDataRCLineCount := 0;
  RCDataCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_RCDATA) Then
    Begin
      Inc(RCDataCount);
      If Resources[I].NameIsId Then
        ResId := IntToStr(Resources[I].NameId)
      Else
        ResId := Resources[I].NameStr;
      StartLine := RCDataRCLineCount;
      GenerateRCDataBlock(Resources[I], ResId);
      If Opts.Verbose Then
      Begin
        If Resources[I].NameIsId Then
          WriteLn('  RT_RCDATA #', Resources[I].NameId,
                  ' : ', Resources[I].DataSize, ' octet(s)')
        Else
          WriteLn('  RT_RCDATA "', Resources[I].NameStr,
                  '" : ', Resources[I].DataSize, ' octet(s)');
        For J := StartLine + 1 To RCDataRCLineCount Do
          WriteLn(RCDataRCLines[J]);
      End;
    End;
  End;
  If Opts.Verbose And (RCDataCount > 0) Then
    WriteLn(RCDataCount, ' ressource(s) RT_RCDATA trouvee(s).');
End;


{ ============================================================
  TODO 20 - DECODAGE RT_MANIFEST (TYPE 24) [IMPLEMENTE]
  ============================================================ }

{ ---- Analyser le contenu XML UTF-8 d un manifest ----------- }
{ Lit les octets bruts, decode les sequences UTF-8 courantes   }
{ et decompose en lignes (LF ou CR+LF)                         }
Procedure ParseManifest(Const Res  : TResourceEntry;
                        Var   Data : TManifestData);
Var
  Buf     : PByteArray;
  BufSize : LongInt;
  I       : LongInt;
  B       : Byte;
  B2      : Byte;
  Ch      : Char;
  CurLine : TString;
Begin
  Data.LineCount := 0;
  CurLine := '';
  ReadRawResourceBytes(Res, Buf, BufSize);
  If Buf = Nil Then Exit;
  I := 0;
  While I < BufSize Do
  Begin
    B := Buf^[I];
    Inc(I);
    If B < $80 Then
    Begin
      { ASCII direct (U+0000..U+007F) }
      Ch := Chr(B);
    End
    Else If (B >= $C2) And (B <= $DF) And (I < BufSize) Then
    Begin
      { Sequence UTF-8 sur 2 octets : U+0080..U+07FF }
      B2 := Buf^[I];
      Inc(I);
      { Convertir en Latin-1 si dans la plage U+00C0..U+00FF }
      If (B = $C3) And (B2 >= $80) And (B2 <= $BF) Then
        Ch := Chr($40 Or (B2 And $3F))
      Else If (B = $C2) And (B2 >= $80) And (B2 <= $BF) Then
        Ch := Chr(B2 And $3F)
      Else
        Ch := '?';
    End
    Else If (B >= $E0) And (B <= $EF) And (I + 2 <= BufSize) Then
    Begin
      { Sequence UTF-8 sur 3 octets : U+0800..U+FFFF -> hors Latin-1 }
      Inc(I, 2);  { sauter les 2 octets de continuation }
      Ch := '?';
    End
    Else If (B >= $F0) And (B <= $F7) And (I + 3 <= BufSize) Then
    Begin
      { Sequence UTF-8 sur 4 octets : U+10000+ -> hors Latin-1 }
      Inc(I, 3);  { sauter les 3 octets de continuation }
      Ch := '?';
    End
    Else
      Ch := '?';
    { Gerer les fins de ligne (LF ou CR+LF) }
    If Ch = #10 Then
    Begin
      If Data.LineCount < MAX_MANIFEST_LINES Then
      Begin
        Inc(Data.LineCount);
        Data.Text[Data.LineCount] := CurLine;
      End;
      CurLine := '';
    End
    Else If Ch = #13 Then
    Begin
      { CR ignore : sera suivi d un LF pour CR+LF }
    End
    Else
      CurLine := CurLine + Ch;
  End;
  { Enregistrer la derniere ligne si non vide }
  If (Length(CurLine) > 0) And (Data.LineCount < MAX_MANIFEST_LINES) Then
  Begin
    Inc(Data.LineCount);
    Data.Text[Data.LineCount] := CurLine;
  End;
  FreeMem(Buf, BufSize);
End;

{ ---- Extraire un manifest RT_MANIFEST vers un fichier .xml -- }
{ Ecrit les octets bruts de la ressource dans un fichier .xml   }
Procedure ExtractManifestFile(Const Res     : TResourceEntry;
                              Const OutFile : TString);
Var
  F       : File Of Byte;
  Buf     : PByteArray;
  BufSize : LongInt;
  I       : LongInt;
  B       : Byte;
Begin
  ReadRawResourceBytes(Res, Buf, BufSize);
  If Buf = Nil Then Exit;
  Assign(F, OutFile);
  Rewrite(F);
  For I := 0 To BufSize - 1 Do
  Begin
    B := Buf^[I];
    Write(F, B);
  End;
  Close(F);
  FreeMem(Buf, BufSize);
End;

{ ---- Decoder / afficher toutes les ressources RT_MANIFEST --- }
Procedure ParseAllManifests;
Var
  I             : Integer;
  ManifestCount : Integer;
  Data          : TManifestData;
  OutName       : TString;
  J             : Integer;
Begin
  ManifestCount := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_MANIFEST) Then
    Begin
      Inc(ManifestCount);
      ParseManifest(Resources[I], Data);
      If Opts.ExtractBin Then
      Begin
        If Resources[I].NameIsId Then
          OutName := 'MANIFEST_' + IntToStr(Resources[I].NameId) + '.xml'
        Else
          OutName := 'MANIFEST_' + Resources[I].NameStr + '.xml';
        ExtractManifestFile(Resources[I], OutName);
        Inc(ExtractCount);
        If Opts.Verbose Then
        Begin
          WriteLn('  Manifest extrait: ', OutName,
                  ' (', Resources[I].DataSize, ' octet(s), ',
                  Data.LineCount, ' ligne(s) XML)');
          For J := 1 To Data.LineCount Do
            WriteLn(Data.Text[J]);
        End;
      End
      Else If Opts.Verbose Then
      Begin
        If Resources[I].NameIsId Then
          WriteLn('  RT_MANIFEST #', Resources[I].NameId,
                  ' : ', Resources[I].DataSize, ' octet(s), ',
                  Data.LineCount, ' ligne(s) XML')
        Else
          WriteLn('  RT_MANIFEST "', Resources[I].NameStr,
                  '" : ', Resources[I].DataSize, ' octet(s), ',
                  Data.LineCount, ' ligne(s) XML');
        For J := 1 To Data.LineCount Do
          WriteLn(Data.Text[J]);
      End;
    End;
  End;
  If Opts.Verbose And (ManifestCount > 0) Then
    WriteLn(ManifestCount, ' ressource(s) RT_MANIFEST trouvee(s).');
End;


{ ============================================================
  TODO 21 - GENERATION DE L'EN-TETE DU FICHIER .RC [IMPLEMENTE]
  ============================================================ }

{ ---- Formatter un entier Word en 2 chiffres avec zero ----- }
Function IntTo2Digits(N : Word) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  If Length(S) < 2 Then S := '0' + S;
  IntTo2Digits := S;
End;

{ ---- Obtenir la date courante au format AAAA-MM-JJ --------- }
Function CurrentDateStr : TString;
Var
  Year, Month, Day, DayOfWeek : Word;
Begin
  GetDate(Year, Month, Day, DayOfWeek);
  CurrentDateStr := IntToStr(Year) + '-' +
                    IntTo2Digits(Month) + '-' +
                    IntTo2Digits(Day);
End;

{ ---- Ecrire l en-tete commentaire + includes du fichier .RC - }
{ Genere les commentaires de version, source, format et date,   }
{ l include appropriate selon le format, puis les #define IDM_  }
{ pour chaque identifiant de commande unique des accelerateurs  }
{ et des elements de menu non-popup.                            }
Procedure WriteRCHeader(Var OutFile    : Text;
                        Const SrcFileName : TString;
                        AResFormat    : Integer);
Var
  CmdIds     : Array[1..256] Of Word;
  CmdIdCount : Integer;
  I, J       : Integer;
  Cmd        : Word;
  AlreadyIn  : Boolean;
Begin
  { Commentaires d en-tete }
  WriteLn(OutFile, '// Fichier .RC genere par DISRES version ',
          DISRES_VERSION);
  WriteLn(OutFile, '// Source : ', SrcFileName);
  If AResFormat = FMT_RES16 Then
    WriteLn(OutFile, '// Format : RES 16 bits')
  Else
    WriteLn(OutFile, '// Format : RES 32 bits');
  WriteLn(OutFile, '// Date   : ', CurrentDateStr);
  WriteLn(OutFile);
  { Include selon le format 16 ou 32 bits }
  If AResFormat = FMT_RES16 Then
    WriteLn(OutFile, '#include <wintypes.h>')
  Else
    WriteLn(OutFile, '#include <windows.h>');
  WriteLn(OutFile);
  { Collecter les IDs de commandes uniques : accelerateurs }
  CmdIdCount := 0;
  For I := 1 To AccelCount Do
  Begin
    Cmd := AccelEntries[I].Cmd;
    If Cmd > 0 Then
    Begin
      AlreadyIn := False;
      For J := 1 To CmdIdCount Do
        If CmdIds[J] = Cmd Then
        Begin
          AlreadyIn := True;
          Break;
        End;
      If (Not AlreadyIn) And (CmdIdCount < 256) Then
      Begin
        Inc(CmdIdCount);
        CmdIds[CmdIdCount] := Cmd;
      End;
    End;
  End;
  { Ajouter les IDs de commandes des elements de menu non-popup }
  For I := 1 To MenuItemCount Do
  Begin
    Cmd := MenuItems[I].MenuID;
    If (Cmd > 0) And (Not MenuItems[I].IsPopup) Then
    Begin
      AlreadyIn := False;
      For J := 1 To CmdIdCount Do
        If CmdIds[J] = Cmd Then
        Begin
          AlreadyIn := True;
          Break;
        End;
      If (Not AlreadyIn) And (CmdIdCount < 256) Then
      Begin
        Inc(CmdIdCount);
        CmdIds[CmdIdCount] := Cmd;
      End;
    End;
  End;
  { Generer les #define IDM_xxx si des identifiants ont ete trouves }
  If CmdIdCount > 0 Then
  Begin
    WriteLn(OutFile, '// Identifiants de commandes (a personaliser)');
    For I := 1 To CmdIdCount Do
      WriteLn(OutFile, '#define IDM_', CmdIds[I], ' ', CmdIds[I]);
    WriteLn(OutFile);
  End;
End;

{ ---- Ecrire la directive de langue pour un script .RC ------- }
{ Si le format est 32 bits et LangId non nul, ecrit la ligne    }
{ LANGUAGE LANG_xxx, SUBLANG_xxx correspondante.                }
Procedure WriteRCLanguageDirective(Var OutFile  : Text;
                                   LangId      : Word;
                                   AResFormat  : Integer);
Begin
  If (AResFormat = FMT_RES32) And (LangId <> 0) Then
  Begin
    WriteLn(OutFile, LangIdToRCKeyword(LangId));
    WriteLn(OutFile);
  End;
End;

{ ---- Determiner la langue principale du fichier .RES -------- }
{ Retourne le premier LangId non nul rencontre dans Resources,  }
{ ou 0 si toutes les ressources ont LangId = 0 (format 16 bits) }
Function GetPrimaryLangId : Word;
Var
  I : Integer;
Begin
  GetPrimaryLangId := 0;
  For I := 1 To ResCount Do
    If Resources[I].LangId <> 0 Then
    Begin
      GetPrimaryLangId := Resources[I].LangId;
      Exit;
    End;
End;

{ ============================================================
  TODO 22 - GENERATION DES DIRECTIVES RC PAR TYPE [IMPLEMENTE]
  ============================================================ }

{ ---- Forward declaration de WriteRCStringTable (TODO 24) --- }
Procedure WriteRCStringTable(Var OutFile : Text); Forward;

{ ---- Forward declaration de WriteRCAccelerators (TODO 24) -- }
Procedure WriteRCAccelerators(Var OutFile : Text;
                               Const Res  : TResourceEntry); Forward;

{ ---- Forward declaration de WriteRCVersionInfo (TODO 24) --- }
Procedure WriteRCVersionInfo(Var OutFile : Text;
                              Const Res  : TResourceEntry); Forward;

{ ---- Ecrire la directive RC pour une ressource RT_ICON ----- }
{ Les RT_ICON individuels sont des sous-ressources des groupes }
{ RT_GROUP_ICON et ne sont pas references directement dans .RC }
Procedure WriteRCIcon(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
Begin
  ResName := FormatID(Res.NameId, Res.NameStr);
  WriteLn(OutFile, '// RT_ICON ', ResName,
          ' (', Res.DataSize, ' octets, sous-ressource de RT_GROUP_ICON)');
  WriteLn(OutFile);
End;

{ ---- Ecrire la directive RC pour une ressource RT_CURSOR --- }
{ Les RT_CURSOR individuels sont des sous-ressources des       }
{ groupes RT_GROUP_CURSOR.                                     }
Procedure WriteRCCursor(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
Begin
  ResName := FormatID(Res.NameId, Res.NameStr);
  WriteLn(OutFile, '// RT_CURSOR ', ResName,
          ' (', Res.DataSize, ' octets, sous-ressource de RT_GROUP_CURSOR)');
  WriteLn(OutFile);
End;

{ ---- Ecrire la directive RC pour une ressource RT_BITMAP --- }
{ Genere : ID BITMAP [options] "BITMAP_N.bmp"                 }
Procedure WriteRCBitmap(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName  : TString;
  FileName : TString;
  Opts_s   : TString;
Begin
  ResName  := FormatID(Res.NameId, Res.NameStr);
  FileName := 'BITMAP_' + FormatID(Res.NameId, Res.NameStr) + '.bmp';
  Opts_s   := MemFlagsToRCOptions(Res.MemFlags);
  If Opts_s <> '' Then
    WriteLn(OutFile, ResName, ' BITMAP ', Opts_s, ' "', FileName, '"')
  Else
    WriteLn(OutFile, ResName, ' BITMAP "', FileName, '"');
  WriteLn(OutFile);
End;

{ ---- Ecrire la directive RC pour une ressource RT_MENU ----- }
{ Cherche le bloc correspondant dans MenuRCLines et l ecrit.   }
Procedure WriteRCMenu(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
  Tag     : TString;
  I       : Integer;
  Depth   : Integer;
  Found   : Boolean;
Begin
  If Res.NameIsId Then
    ResName := IntToStr(Res.NameId)
  Else
    ResName := Res.NameStr;
  Tag   := ResName + ' MENU';
  Found := False;
  I     := 1;
  While I <= MenuRCLineCount Do
  Begin
    If MenuRCLines[I] = Tag Then
    Begin
      Found := True;
      WriteLn(OutFile, MenuRCLines[I]);
      Inc(I);
      Depth := 0;
      While I <= MenuRCLineCount Do
      Begin
        WriteLn(OutFile, MenuRCLines[I]);
        If MenuRCLines[I] = 'BEGIN' Then
          Inc(Depth)
        Else If MenuRCLines[I] = 'END' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then Break;
        End;
        Inc(I);
      End;
      WriteLn(OutFile);
      Exit;
    End;
    Inc(I);
  End;
  If Not Found Then
  Begin
    WriteLn(OutFile, '// MENU ', ResName, ' (non decode)');
    WriteLn(OutFile);
  End;
End;

{ ---- Ecrire la directive RC pour une ressource RT_DIALOG --- }
{ Cherche le bloc correspondant dans DialogRCLines et l ecrit. }
Procedure WriteRCDialog(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
  Prefix  : TString;
  I       : Integer;
  Depth   : Integer;
  Found   : Boolean;
Begin
  If Res.NameIsId Then
    ResName := IntToStr(Res.NameId)
  Else
    ResName := Res.NameStr;
  Prefix := ResName + ' DIALOG ';
  Found  := False;
  I      := 1;
  While I <= DialogRCLineCount Do
  Begin
    If Copy(DialogRCLines[I], 1, Length(Prefix)) = Prefix Then
    Begin
      Found := True;
      WriteLn(OutFile, DialogRCLines[I]);
      Inc(I);
      Depth := 0;
      While I <= DialogRCLineCount Do
      Begin
        WriteLn(OutFile, DialogRCLines[I]);
        If DialogRCLines[I] = 'BEGIN' Then
          Inc(Depth)
        Else If DialogRCLines[I] = 'END' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then Break;
        End;
        Inc(I);
      End;
      WriteLn(OutFile);
      Exit;
    End;
    Inc(I);
  End;
  If Not Found Then
  Begin
    WriteLn(OutFile, '// DIALOG ', ResName, ' (non decode)');
    WriteLn(OutFile);
  End;
End;

{ ---- Ecrire la directive RC pour une ressource RT_RCDATA --- }
{ Cherche le bloc correspondant dans RCDataRCLines et l ecrit. }
Procedure WriteRCRCData(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
  Tag     : TString;
  I       : Integer;
  Found   : Boolean;
Begin
  ResName := FormatID(Res.NameId, Res.NameStr);
  Tag     := ResName + ' RCDATA BEGIN';
  Found   := False;
  I       := 1;
  While I <= RCDataRCLineCount Do
  Begin
    If RCDataRCLines[I] = Tag Then
    Begin
      Found := True;
      WriteLn(OutFile, RCDataRCLines[I]);
      Inc(I);
      While I <= RCDataRCLineCount Do
      Begin
        WriteLn(OutFile, RCDataRCLines[I]);
        If RCDataRCLines[I] = 'END' Then Break;
        Inc(I);
      End;
      WriteLn(OutFile);
      Exit;
    End;
    Inc(I);
  End;
  If Not Found Then
  Begin
    WriteLn(OutFile, '// RCDATA ', ResName, ' (non decode)');
    WriteLn(OutFile);
  End;
End;

{ ---- Ecrire la directive RC pour une ressource RT_MANIFEST - }
{ Genere : ID RT_MANIFEST "MANIFEST_N.xml"                    }
Procedure WriteRCManifest(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName  : TString;
  FileName : TString;
Begin
  ResName  := FormatID(Res.NameId, Res.NameStr);
  FileName := 'MANIFEST_' + FormatID(Res.NameId, Res.NameStr) + '.xml';
  WriteLn(OutFile, ResName, ' RT_MANIFEST "', FileName, '"');
  WriteLn(OutFile);
End;

{ ---- Ecrire la directive RC pour un groupe d icones -------- }
{ Genere : ID ICON "ICON_N.ico"                               }
Procedure WriteRCGroupIcon(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName  : TString;
  FileName : TString;
Begin
  ResName  := FormatID(Res.NameId, Res.NameStr);
  FileName := 'ICON_' + FormatID(Res.NameId, Res.NameStr) + '.ico';
  WriteLn(OutFile, ResName, ' ICON "', FileName, '"');
  WriteLn(OutFile);
End;

{ ---- Ecrire la directive RC pour un groupe de curseurs ----- }
{ Genere : ID CURSOR "CURSOR_N.cur"                           }
Procedure WriteRCGroupCursor(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName  : TString;
  FileName : TString;
Begin
  ResName  := FormatID(Res.NameId, Res.NameStr);
  FileName := 'CURSOR_' + FormatID(Res.NameId, Res.NameStr) + '.cur';
  WriteLn(OutFile, ResName, ' CURSOR "', FileName, '"');
  WriteLn(OutFile);
End;

{ ---- Ecrire un hexdump generique pour les types inconnus --- }
{ Genere un bloc RCDATA avec les octets en hexadecimal.        }
Procedure WriteRCRawData(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName  : TString;
  TypeName : TString;
  Buf      : PByteArray;
  BufSize  : LongInt;
  I        : LongInt;
  LineStr  : TString;
  ColIdx   : Integer;
Begin
  If Res.TypeIsId Then
    ResName := FormatID(Res.NameId, Res.NameStr) +
               '_TYPE' + IntToStr(Res.TypeId)
  Else
    ResName := Res.TypeName + '_' + FormatID(Res.NameId, Res.NameStr);
  TypeName := ResourceTypeKeyword(Res.TypeId);
  If TypeName = '' Then TypeName := 'RCDATA';
  WriteLn(OutFile, '// Type brut : ', ResourceTypeName(Res.TypeId),
          ' #', Res.NameId, ' (', Res.DataSize, ' octets)');
  WriteLn(OutFile, ResName, ' RCDATA BEGIN');
  ReadRawResourceBytes(Res, Buf, BufSize);
  If Buf <> Nil Then
  Begin
    LineStr := '    ';
    ColIdx  := 0;
    For I := 0 To BufSize - 1 Do
    Begin
      If ColIdx > 0 Then LineStr := LineStr + ', ';
      LineStr := LineStr + '0x' + HexByte(Buf^[I]);
      Inc(ColIdx);
      If ColIdx >= RCDATA_BYTES_PER_LINE Then
      Begin
        WriteLn(OutFile, LineStr);
        LineStr := '    ';
        ColIdx  := 0;
      End;
    End;
    If ColIdx > 0 Then WriteLn(OutFile, LineStr);
    FreeMem(Buf, BufSize);
  End;
  WriteLn(OutFile, 'END');
  WriteLn(OutFile);
End;

{ ---- Orchestrateur : generer la directive RC pour une res. - }
{ Dispatche vers la procedure appropriee selon le TypeId.      }
Procedure WriteRCResource(Var OutFile : Text; Const Res : TResourceEntry);
Begin
  If Not Res.TypeIsId Then
  Begin
    WriteRCRawData(OutFile, Res);
    Exit;
  End;
  Case Res.TypeId Of
    RT_CURSOR       : WriteRCCursor(OutFile, Res);
    RT_BITMAP       : WriteRCBitmap(OutFile, Res);
    RT_ICON         : WriteRCIcon(OutFile, Res);
    RT_MENU         : WriteRCMenu(OutFile, Res);
    RT_DIALOG       : WriteRCDialog(OutFile, Res);
    RT_STRING       : { gere globalement par WriteRCStringTable } ;
    RT_ACCELERATOR  : WriteRCAccelerators(OutFile, Res);
    RT_RCDATA       : WriteRCRCData(OutFile, Res);
    RT_VERSION      : WriteRCVersionInfo(OutFile, Res);
    RT_MANIFEST     : WriteRCManifest(OutFile, Res);
    RT_GROUP_ICON   : WriteRCGroupIcon(OutFile, Res);
    RT_GROUP_CURSOR : WriteRCGroupCursor(OutFile, Res);
  Else
    WriteRCRawData(OutFile, Res);
  End;
End;

{ ---- Stubs pour TODO 24 (implementation dans TODO 24) ------ }
Procedure WriteRCStringTable(Var OutFile : Text);
Begin
  { TODO 24 : implementer la generation de STRINGTABLE }
End;

Procedure WriteRCAccelerators(Var OutFile : Text; Const Res : TResourceEntry);
Begin
  { TODO 24 : implementer la generation de ACCELERATORS }
End;

Procedure WriteRCVersionInfo(Var OutFile : Text; Const Res : TResourceEntry);
Var
  ResName : TString;
  Prefix  : TString;
  I       : Integer;
  Depth   : Integer;
  Found   : Boolean;
Begin
  If Res.NameIsId Then
    ResName := IntToStr(Res.NameId)
  Else
    ResName := Res.NameStr;
  Prefix := ResName + ' VERSIONINFO';
  Found  := False;
  I      := 1;
  While I <= VersionRCLineCount Do
  Begin
    If Copy(VersionRCLines[I], 1, Length(Prefix)) = Prefix Then
    Begin
      Found := True;
      WriteLn(OutFile, VersionRCLines[I]);
      Inc(I);
      Depth := 0;
      While I <= VersionRCLineCount Do
      Begin
        WriteLn(OutFile, VersionRCLines[I]);
        If VersionRCLines[I] = 'BEGIN' Then
          Inc(Depth)
        Else If VersionRCLines[I] = 'END' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then Break;
        End;
        Inc(I);
      End;
      WriteLn(OutFile);
      Exit;
    End;
    Inc(I);
  End;
  If Not Found Then
  Begin
    WriteLn(OutFile, '// VERSIONINFO ', ResName, ' (non decode)');
    WriteLn(OutFile);
  End;
End;

{ ---- Generer le fichier .RC complet ------------------------ }
{ Ouvre Opts.OutFile en ecriture, ecrit l en-tete, la          }
{ directive de langue, puis toutes les directives de           }
{ ressources via WriteRCResource. Les RT_STRING sont groupees  }
{ en un appel a WriteRCStringTable a la fin.                   }
Procedure GenerateRCFile(AResFormat : Integer);
Var
  OutFile    : Text;
  I          : Integer;
  HasStrings : Boolean;
Begin
  Assign(OutFile, Opts.OutFile);
  {$I-}
  Rewrite(OutFile);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('DISRES: impossible de creer le fichier : ', Opts.OutFile);
    Exit;
  End;
  WriteRCHeader(OutFile, Opts.SrcFile, AResFormat);
  WriteRCLanguageDirective(OutFile, GetPrimaryLangId, AResFormat);
  { Ecrire les directives de ressources (sauf RT_STRING) }
  HasStrings := False;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId And (Resources[I].TypeId = RT_STRING) Then
      HasStrings := True
    Else
      WriteRCResource(OutFile, Resources[I]);
  End;
  { Regrouper toutes les RT_STRING dans un seul bloc STRINGTABLE }
  If HasStrings Then
    WriteRCStringTable(OutFile);
  Close(OutFile);
  If Opts.Verbose Then
    WriteLn('Fichier RC genere : ', Opts.OutFile);
End;

{ ============================================================
  TODO 25 - VERIFICATION ET RAPPORT FINAL [IMPLEMENTE]
  ============================================================ }

{ ---- Retourner la taille d un fichier en octets ------------ }
Function GetFileSize(Const FName : TString) : LongInt;
Var
  F : File Of Byte;
Begin
  Assign(F, FName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    GetFileSize := -1;
    Exit;
  End;
  GetFileSize := FileSize(F);
  Close(F);
End;

{ ---- Tester si une ligne RC contient un BEGIN valide ------- }
{ Retourne True si Line = 'BEGIN' ou se termine par ' BEGIN'   }
{ (format "ResName RCDATA BEGIN")                              }
Function LineHasBegin(Const S : TString) : Boolean;
Var
  L : Integer;
Begin
  L := Length(S);
  If S = 'BEGIN' Then
    LineHasBegin := True
  Else If (L >= 6) And (Copy(S, L - 4, 5) = 'BEGIN') And (S[L - 5] = ' ') Then
    LineHasBegin := True
  Else
    LineHasBegin := False;
End;

{ ---- Verifier le fichier RC genere ------------------------- }
Procedure VerifyRCFile(Const OutFileName : TString);
Var
  F          : Text;
  Line       : TString;
  LineCount  : Integer;
  BeginCount : Integer;
  EndCount   : Integer;
  HasUnknown : Boolean;
  I          : Integer;
  FSz        : LongInt;
Begin
  FSz := GetFileSize(OutFileName);
  If FSz < 0 Then
  Begin
    WriteLn('DISRES: AVERTISSEMENT - le fichier RC n''existe pas : ', OutFileName);
    Exit;
  End;
  If FSz = 0 Then
  Begin
    WriteLn('DISRES: AVERTISSEMENT - le fichier RC est vide : ', OutFileName);
    Exit;
  End;
  Assign(F, OutFileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('DISRES: AVERTISSEMENT - impossible d''ouvrir le fichier RC : ', OutFileName);
    Exit;
  End;
  LineCount  := 0;
  BeginCount := 0;
  EndCount   := 0;
  While Not EOF(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineCount);
    If LineHasBegin(Line) Then
      Inc(BeginCount)
    Else If Line = 'END' Then
      Inc(EndCount);
  End;
  Close(F);
  If BeginCount <> EndCount Then
    WriteLn('DISRES: AVERTISSEMENT - desequilibre BEGIN/END dans le fichier RC (',
            BeginCount, ' BEGIN, ', EndCount, ' END)');
  HasUnknown := False;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId Then
    Begin
      If (Resources[I].TypeId > RT_MANIFEST) And
         (Resources[I].TypeId <> RT_TOOLBAR) Then
      Begin
        HasUnknown := True;
        Break;
      End;
    End;
  End;
  If HasUnknown Then
    WriteLn('DISRES: AVERTISSEMENT - certaines ressources de type inconnu ',
            'n''ont pas pu etre decodees.');
End;

{ ---- Afficher le rapport final de desassemblage ------------ }
Procedure DisplayFinalReport(Const AOpts : TOptions; AResFormat : Integer);
Var
  I           : Integer;
  CountIcon   : Integer;
  CountBitmap : Integer;
  CountMenu   : Integer;
  CountDialog : Integer;
  CountAccel  : Integer;
  CountVersion : Integer;
  CountRCData : Integer;
  CountManifest : Integer;
  CountCursor : Integer;
  CountGrpIcon : Integer;
  CountGrpCursor : Integer;
  CountStringBlocks : Integer;
  FileSz      : LongInt;
Begin
  WriteLn('=== DISRES - Rapport de desassemblage ===');
  WriteLn('Fichier source  : ', AOpts.SrcFile);
  If AResFormat = FMT_RES16 Then
    WriteLn('Format detecte  : RES 16 bits')
  Else If AResFormat = FMT_RES32 Then
    WriteLn('Format detecte  : RES 32 bits')
  Else
    WriteLn('Format detecte  : inconnu');
  WriteLn('Ressources total: ', IntToStr(ResCount));
  CountIcon      := 0;
  CountBitmap    := 0;
  CountMenu      := 0;
  CountDialog    := 0;
  CountAccel     := 0;
  CountVersion   := 0;
  CountRCData    := 0;
  CountManifest  := 0;
  CountCursor    := 0;
  CountGrpIcon   := 0;
  CountGrpCursor := 0;
  CountStringBlocks := 0;
  For I := 1 To ResCount Do
  Begin
    If Resources[I].TypeIsId Then
      Case Resources[I].TypeId Of
        RT_ICON         : Inc(CountIcon);
        RT_BITMAP       : Inc(CountBitmap);
        RT_MENU         : Inc(CountMenu);
        RT_DIALOG       : Inc(CountDialog);
        RT_STRING       : Inc(CountStringBlocks);
        RT_ACCELERATOR  : Inc(CountAccel);
        RT_VERSION      : Inc(CountVersion);
        RT_RCDATA       : Inc(CountRCData);
        RT_MANIFEST     : Inc(CountManifest);
        RT_CURSOR       : Inc(CountCursor);
        RT_GROUP_ICON   : Inc(CountGrpIcon);
        RT_GROUP_CURSOR : Inc(CountGrpCursor);
      End;
  End;
  If CountCursor > 0 Then
    WriteLn('  RT_CURSOR     : ', IntToStr(CountCursor), ' ressource(s)');
  If CountIcon > 0 Then
    WriteLn('  RT_ICON       : ', IntToStr(CountIcon), ' ressource(s)');
  If CountBitmap > 0 Then
    WriteLn('  RT_BITMAP     : ', IntToStr(CountBitmap), ' ressource(s)');
  If CountMenu > 0 Then
    WriteLn('  RT_MENU       : ', IntToStr(CountMenu), ' ressource(s)');
  If CountDialog > 0 Then
    WriteLn('  RT_DIALOG     : ', IntToStr(CountDialog), ' ressource(s)');
  If CountStringBlocks > 0 Then
    WriteLn('  RT_STRING     : ', IntToStr(CountStringBlocks), ' bloc(s), ',
            IntToStr(StringCount), ' chaine(s)');
  If CountAccel > 0 Then
    WriteLn('  RT_ACCELERATOR: ', IntToStr(CountAccel), ' table(s)');
  If CountVersion > 0 Then
    WriteLn('  RT_VERSION    : ', IntToStr(CountVersion), ' ressource(s)');
  If CountRCData > 0 Then
    WriteLn('  RT_RCDATA     : ', IntToStr(CountRCData), ' ressource(s)');
  If CountManifest > 0 Then
    WriteLn('  RT_MANIFEST   : ', IntToStr(CountManifest), ' ressource(s)');
  If CountGrpIcon > 0 Then
    WriteLn('  RT_GROUP_ICON : ', IntToStr(CountGrpIcon), ' ressource(s)');
  If CountGrpCursor > 0 Then
    WriteLn('  RT_GROUP_CURSOR: ', IntToStr(CountGrpCursor), ' ressource(s)');
  WriteLn('Fichiers extraits: ', IntToStr(ExtractCount));
  WriteLn('Fichier RC genere: ', AOpts.OutFile);
  FileSz := GetFileSize(AOpts.OutFile);
  If FileSz >= 0 Then
    WriteLn('Taille RC        : ', IntToStr(FileSz), ' octets')
  Else
    WriteLn('Taille RC        : (fichier absent)');
  If AOpts.Verbose Then
  Begin
    WriteLn;
    WriteLn('Detail des ressources :');
    For I := 1 To ResCount Do
    Begin
      If Resources[I].TypeIsId Then
        Write('  [', IntToStr(I), '] type=', ResourceTypeName(Resources[I].TypeId))
      Else
        Write('  [', IntToStr(I), '] type="', Resources[I].TypeName, '"');
      If Resources[I].NameIsId Then
        Write(' id=', IntToStr(Resources[I].NameId))
      Else
        Write(' nom="', Resources[I].NameStr, '"');
      Write(' lang=', HexWord(Resources[I].LangId));
      Write(' taille=', IntToStr(Resources[I].DataSize), ' octets');
      WriteLn(' flags=', HexWord(Resources[I].MemFlags));
    End;
  End;
End;


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
  ExtractCount := 0;
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

  { Decoder les menus (RT_MENU) }
  ParseAllMenus;

  { Decoder les dialogues (RT_DIALOG) }
  ParseAllDialogs;

  { Decoder les informations de version (RT_VERSION) }
  ParseAllVersionInfos;

  { Decoder les icones (RT_ICON) }
  ParseAllIcons;

  { Decoder les curseurs (RT_CURSOR) }
  ParseAllCursors;

  { Decoder les bitmaps (RT_BITMAP) }
  ParseAllBitmaps;

  { Decoder les groupes d icones (RT_GROUP_ICON) et curseurs (RT_GROUP_CURSOR) }
  GroupIconCount := 0;
  ParseAllGroupIcons;
  ParseAllGroupCursors;

  { Decoder les donnees binaires generiques (RT_RCDATA) }
  ParseAllRCData;

  { Decoder les manifests d application (RT_MANIFEST) }
  ParseAllManifests;

  { Generer le fichier .RC complet (TODO 21 + TODO 22) }
  GenerateRCFile(ResFormat);

  { Verifier le fichier RC genere (TODO 25) }
  VerifyRCFile(Opts.OutFile);

  { Afficher le rapport final (TODO 25) }
  DisplayFinalReport(Opts, ResFormat);

  { Fermer le fichier source }
  CloseResFile;
End.
