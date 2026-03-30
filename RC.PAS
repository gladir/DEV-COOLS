{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur de fichiers .RC (scripts ressource) en fichiers
                .RES (ressources Windows 16 bits ou 32 bits)
  @license: MIT
}

(* ============================================================
  RC.PAS - Compilateur de ressources Windows (.RC -> .RES)
  Free Pascal (-Mtp)

  Supporte :
    - Generation de format RES 16 bits (Windows 3.x, Borland Pascal 7.x,
      Turbo Pascal pour Windows)
    - Generation de format RES 32 bits (Windows NT/9x+, MSVC, Delphi,
      Free Pascal/windres)

  Usage :
    RC fichier.rc [-o sortie.res] [-16|-32] [-I<chemin>] [-D<sym>] [-v] [-h]

  Options :
    -o nom        : specifier le nom du fichier de sortie .RES
    -16           : generer en format 16 bits
    -32           : generer en format 32 bits (defaut)
    -I<chemin>    : ajouter un chemin de recherche pour les includes
    -D<sym>       : definir un symbole de preprocesseur
    -v            : mode verbeux (afficher details des ressources)
    -h            : afficher l aide

  Voir DOC/RES_FORMAT.txt pour la description complete du format .RES.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
            RC_VERSION ('1.0') et RC_DATE ('2026-03-30')
            {$A-} pour desactiver l alignement automatique des records
            TOptions : SrcFile (String), OutFile (String),
              Output16 (Boolean), Output32 (Boolean),
              Verbose (Boolean), IncludePaths (Array[1..16] Of String),
              IncludeCount (Integer), Defines (Array[1..64] Of String),
              DefineCount (Integer)
            Constantes de codes de retour : EXIT_OK = 0, EXIT_ERROR = 1,
              EXIT_USAGE = 2
            Constantes de format : FMT_RES16 = 1, FMT_RES32 = 2
            Constantes de tailles internes : MAX_RESOURCES = 4096,
              MAX_STRINGS = 4096, MAX_ACCEL = 256,
              MAX_MENU_ITEMS = 512, MAX_DIALOG_CTRL = 256,
              MAX_TOKENS = 8192, MAX_INCLUDES = 64
            Procedure FatalError(Msg: String) : afficher l erreur et
              appeler Halt(EXIT_ERROR)
            Procedure ParseCommandLine(Var Opts: TOptions) :
              analyser ParamStr(1..ParamCount), detecter les options
              -o / -16 / -32 / -I / -D / -v / -h / --help, valider que
              SrcFile est fourni et se termine par .rc ou .RC
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
            Function StrToInt(Const S: String): LongInt
              convertit une chaine decimale ou hexadecimale en entier
              supporter les formats : 123, 0x7B, 7Bh, 0x7B
            Function UpCaseStr(Const S: String): String
              convertir une chaine en majuscules
            Function Trim(Const S: String): String
              supprimer les espaces de debut et de fin
            Function FileExists(Const FName: String): Boolean
              verifier l existence d un fichier
            Function ChangeFileExt(Const FName, NewExt: String): String
              remplacer l extension d un nom de fichier
            Function ExtractFileName(Const FName: String): String
              extraire le nom du fichier sans le chemin
            Function ExtractFilePath(Const FName: String): String
              extraire le chemin du fichier sans le nom
            Function CharToWChar(C: Char): Word
              convertir un Char Latin-1 en WCHAR Unicode
            Function StrToUniStr(Const S: String): Array Of Word
              convertir une String Pascal en tableau de WCHAR

  TODO 03 - LEXER RC (TOKENISATION) [IMPLEMENTE]
            Type TTokenKind : enumeration des types de tokens
              TK_EOF, TK_IDENT, TK_NUMBER, TK_STRING, TK_CHAR,
              TK_COMMA, TK_LPAREN, TK_RPAREN, TK_LBRACE, TK_RBRACE,
              TK_PIPE, TK_PLUS, TK_MINUS, TK_NOT, TK_COLON,
              TK_BEGIN, TK_END, TK_PREPROCESSOR, TK_COMMENT,
              TK_NEWLINE
            Type TToken : record
              Kind   : TTokenKind
              Value  : String     (contenu textuel du token)
              IntVal : LongInt    (valeur numerique si TK_NUMBER)
              Line   : Integer    (numero de ligne pour les erreurs)
              Col    : Integer    (colonne pour les erreurs)
            End
            Variables globales :
              SrcFile    : Text       (fichier source ouvert)
              SrcLine    : Integer    (numero de ligne courant)
              SrcCol     : Integer    (colonne courante)
              SrcChar    : Char       (caractere courant)
              CurrToken  : TToken     (token courant)
              PeekToken  : TToken     (token en avance si peek actif)
              HasPeek    : Boolean    (True si PeekToken est valide)
            Procedure OpenSourceFile(Const FName: String)
              ouvrir le fichier .RC en mode texte ({$I-}/{$I+}),
              initialiser SrcLine := 1, SrcCol := 0, lire le premier char
            Procedure CloseSourceFile
              fermer le fichier SrcFile
            Function ReadChar: Char
              lire le prochain caractere, mettre a jour SrcCol et SrcLine
            Function PeekChar: Char
              retourner le prochain caractere sans l avancer
            Procedure SkipWhitespace
              sauter les espaces, tabulations et retours chariot
            Procedure SkipLineComment
              sauter les commentaires // jusqu a fin de ligne
            Procedure SkipBlockComment
              sauter les commentaires /* ... */
            Function LexNumber: TToken
              lire un nombre decimal ou hexadecimal (0x...)
            Function LexString: TToken
              lire une chaine entre guillemets doubles "..."
              gerer les sequences d echappement \n \t \\ \"
            Function LexIdent: TToken
              lire un identifiant ou mot-cle (lettres, chiffres, _)
            Function NextToken: TToken
              retourner le prochain token, stocker dans CurrToken
            Function PeekTokenFn: TToken
              retourner le prochain token sans avancer

  TODO 04 - PARSER RC (ANALYSE SYNTAXIQUE) [IMPLEMENTE]
            Type TStatementKind : enumeration des types de declarations
              ST_INCLUDE, ST_DEFINE, ST_UNDEF, ST_IFDEF, ST_IFNDEF,
              ST_ELSE, ST_ENDIF, ST_PRAGMA, ST_LANGUAGE,
              ST_STRINGTABLE, ST_ACCELERATORS, ST_MENU, ST_MENUEX,
              ST_DIALOG, ST_DIALOGEX, ST_VERSIONINFO,
              ST_ICON, ST_CURSOR, ST_BITMAP, ST_FONT, ST_RCDATA,
              ST_MESSAGETABLE, ST_MANIFEST, ST_HTML,
              ST_USER_TYPE
            Function ExpectToken(Kind: TTokenKind): TToken
              lire le token suivant et verifier qu il est du bon type,
              sinon lever une erreur de syntaxe
            Function ExpectIdent: String
              lire et retourner la valeur d un identifiant attendu
            Function ExpectNumber: LongInt
              lire et retourner un nombre attendu
            Function ExpectString: String
              lire et retourner une chaine attendue
            Function ParseExpression: LongInt
              parser une expression arithmetique simple :
              nombre | ident | expr + expr | expr | expr | expr - expr
              | NOT expr | (expr)
            Function ParseResourceId: TResourceId
              lire un identifiant de ressource (nombre ou chaine)
            Procedure ParseStatement
              lire et dispatcher vers le bon parseur selon le token courant
            Procedure ParseFile
              boucle principale : appeler ParseStatement jusqu a EOF
            Function IsRCKeyword(Const Ident: String): Boolean
              verifier si l identifiant est un mot-cle RC :
              ACCELERATORS, BEGIN, BITMAP, CURSOR, DIALOG, DIALOGEX,
              END, ICON, LANGUAGE, MENU, MENUEX, POPUP, RCDATA,
              STRINGTABLE, VERSIONINFO, etc.

  TODO 05 - ECRITURE BINAIRE DU FICHIER .RES [IMPLEMENTE]
            Variables globales : ResFile (File Of Byte),
              ResFileName (String), ResFileSize (LongInt),
              ResFilePos (LongInt)
            Procedure CreateResFile(Const FName: String)
              creer le fichier binaire en ecriture ({$I-}/{$I+}),
              gerer l erreur si le fichier ne peut etre cree,
              initialiser ResFilePos := 0
            Procedure CloseResFile
              fermer le fichier ResFile
            Procedure WriteByte(B: Byte)
              ecrire un octet dans ResFile, incrementer ResFilePos
            Procedure WriteWord(W: Word)
              ecrire 2 octets little-endian (Lo puis Hi)
            Procedure WriteDWord(D: LongInt)
              ecrire 4 octets little-endian
            Procedure WriteWChar(W: Word)
              ecrire un WCHAR (2 octets little-endian = WriteWord)
            Procedure WriteBytes(Const Buf: Array Of Byte; Count: LongInt)
              ecrire un tableau d octets
            Procedure WriteString(Const S: String)
              ecrire une chaine Pascal (1 octet longueur + chars)
            Procedure WriteUnicodeString(Const S: String)
              ecrire une chaine Unicode UTF-16LE terminee par $0000
            Procedure PadToAlignment(Align: Byte)
              ecrire des octets $00 jusqu a ce que ResFilePos soit
              multiple de Align (2 pour 16 bits, 4 pour 32 bits)
            Function GetResPos: LongInt
              retourner ResFilePos courant
            Procedure SeekResPos(Pos: LongInt)
              se deplacer a la position Pos dans le fichier

  TODO 06 - GENERATION EN-TETE RES 16/32 BITS [IMPLEMENTE]
            Procedure WriteNullHeader32
              ecrire la ressource nulle de 32 octets au debut du fichier
              32 bits : DataSize=0, HeaderSize=32, Type=$FFFF,
              Name=$FFFF, DataVersion=0, MemFlags=0, LangId=0,
              Version=0, Characteristics=0
            Procedure WriteResHeader16(TypeId, NameId: Word;
              DataSize, Attribs: Word)
              ecrire l en-tete 16 bits : TypeId avec bit $8000,
              NameId avec bit $8000, DataSize (DWORD), Attribs (WORD),
              Reserved (WORD = 0)
            Procedure WriteResHeader16Str(Const TypeName, ResName: String;
              DataSize, Attribs: Word)
              variante avec noms en chaines Pascal
            Procedure WriteResHeader32(TypeIsId: Boolean; TypeId: Word;
              Const TypeName: String; NameIsId: Boolean; NameId: Word;
              Const ResName: String; DataSize: LongInt; MemFlags: Word;
              LangId: Word)
              ecrire l en-tete 32 bits complet : DataSize, HeaderSize,
              Type (FFFF+ID ou Unicode), Name (FFFF+ID ou Unicode),
              alignement, DataVersion, MemFlags, LangId, Version,
              Characteristics
            Function CalculateHeaderSize32(TypeIsId: Boolean;
              Const TypeName: String; NameIsId: Boolean;
              Const ResName: String): LongInt
              calculer la taille de l en-tete 32 bits variable
            Procedure WriteEndMarker16
              ecrire le marqueur de fin 16 bits : WORD $0000

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
            Function ResourceTypeFromKeyword(Const Kw: String): Word
              retourner le type numerique correspondant au mot-cle :
              'CURSOR' -> 1, 'BITMAP' -> 2, 'ICON' -> 3,
              'MENU' -> 4, 'DIALOG' -> 5, 'STRINGTABLE' -> 6,
              'ACCELERATORS' -> 9, 'RCDATA' -> 10, 'MESSAGETABLE' -> 11,
              'VERSIONINFO' -> 16, 'MANIFEST' -> 24, 'HTML' -> 23
              retourner 0 si inconnu (type utilisateur)
            Function ResourceTypeName(TypeId: Word): String
              retourner le nom symbolique RT_xxx correspondant

  TODO 08 - TRAITEMENT DE LANGUAGE ID [IMPLEMENTE]
            Variables globales :
              CurrentLangId : Word (langue courante, defaut = $0000)
            Constantes de langues courantes :
              LANG_NEUTRAL = $0000, LANG_ENGLISH_US = $0409,
              LANG_ENGLISH_UK = $0809, LANG_FRENCH = $040C,
              LANG_FRENCH_CANADA = $0C0C, LANG_GERMAN = $0407,
              LANG_ITALIAN = $0410, LANG_SPANISH = $0C0A,
              LANG_PORTUGUESE_BR = $0416, LANG_RUSSIAN = $0419,
              LANG_JAPANESE = $0411, LANG_CHINESE_SIMPL = $0804
            Function MakeLangId(Primary, Sub: Word): Word
              combiner PRIMARYLANGID et SUBLANGID en un LANGID complet
              formule : (Sub shl 10) or Primary
            Function PrimaryLangIdFromName(Const Name: String): Word
              retourner LANG_xxx depuis le nom :
              'ENGLISH' -> $09, 'FRENCH' -> $0C, 'GERMAN' -> $07, etc.
            Function SubLangIdFromName(Const Name: String): Word
              retourner SUBLANG_xxx depuis le nom :
              'DEFAULT' -> 1, 'NEUTRAL' -> 0, 'ENGLISH_US' -> 1,
              'FRENCH' -> 1, 'FRENCH_CANADIAN' -> 3, etc.
            Procedure ParseLanguageDirective
              lire LANGUAGE LANG_xxx, SUBLANG_xxx et mettre a jour
              CurrentLangId := MakeLangId(primary, sub)

  TODO 09 - TRAITEMENT DES FLAGS MEMOIRE [IMPLEMENTE]
            Variables globales :
              DefaultMemFlags : Word (flags par defaut pour les ressources)
            Constantes de flags memoire :
              MF_MOVEABLE = $0010, MF_PURE = $0020, MF_PRELOAD = $0040,
              MF_DISCARDABLE = $1000, MF_FIXED = $0000
            Function MemFlagFromName(Const Name: String): Word
              retourner le flag correspondant au mot-cle :
              'MOVEABLE' -> $0010, 'PURE' -> $0020, 'PRELOAD' -> $0040,
              'DISCARDABLE' -> $1000, 'FIXED' -> $0000,
              'LOADONCALL' -> $0000, 'SHARED' -> $0030
            Function ParseMemoryOptions: Word
              lire les options de memoire optionnelles apres une declaration
              de ressource : MOVEABLE, DISCARDABLE, PRELOAD, etc.
              retourner la combinaison des flags, ou DefaultMemFlags
              si aucune option specifiee

  TODO 10 - TABLE DES RESSOURCES (COLLECTE) [IMPLEMENTE]
            Type TResourceEntry : record
              TypeIsId   : Boolean   (True si type numerique)
              TypeId     : Word      (identifiant de type)
              TypeName   : String    (nom de type si Non TypeIsId)
              NameIsId   : Boolean   (True si nom numerique)
              NameId     : Word      (identifiant de nom)
              NameStr    : String    (nom si Non NameIsId)
              DataSize   : LongInt   (taille des donnees)
              DataOfs    : LongInt   (offset dans le fichier genere)
              MemFlags   : Word      (attributs memoire)
              LangId     : Word      (identifiant de langue)
            End
            Variables globales :
              Resources    : Array[1..MAX_RESOURCES] Of TResourceEntry
              ResCount     : Integer   (nombre de ressources compilees)
            Function AddResource(TypeIsId: Boolean; TypeId: Word;
              Const TypeName: String; NameIsId: Boolean; NameId: Word;
              Const ResName: String; MemFlags: Word; LangId: Word): Integer
              ajouter une nouvelle ressource a la table, retourner l index
            Procedure SetResourceDataOfs(Index: Integer; Ofs: LongInt)
              mettre a jour l offset des donnees pour une ressource
            Procedure SetResourceDataSize(Index: Integer; Size: LongInt)
              mettre a jour la taille des donnees pour une ressource

  TODO 11 - COMPILATION STRINGTABLE [A FAIRE]
            Type TStringEntry : record
              StringId : Word   (identifiant de la chaine)
              Text     : String (texte de la chaine)
              LangId   : Word   (langue)
            End
            Variables globales :
              StringEntries : Array[1..MAX_STRINGS] Of TStringEntry
              StringCount   : Integer
            Procedure ParseStringTable
              lire le bloc STRINGTABLE ... BEGIN ... END :
              pour chaque ligne : lire ID, virgule, chaine entre ""
              ajouter dans StringEntries avec CurrentLangId
            Procedure WriteStringTable
              grouper les StringEntries par bloc de 16 IDs consecutifs
              (bloc N contient les IDs (N-1)*16 a (N-1)*16+15)
              pour chaque bloc present :
              - ecrire l en-tete de ressource RT_STRING avec ID = N
              - pour chaque slot 0..15 : ecrire WORD longueur (en WCHARs)
                puis les WCHARs (0 si slot vide)
              aligner les donnees sur 4 octets

  TODO 12 - COMPILATION ACCELERATORS [A FAIRE]
            Type TAccelEntry : record
              fVirt  : Word   (drapeaux de l accelerateur)
              Key    : Word   (code de touche ou ASCII)
              Cmd    : Word   (identifiant de commande)
            End
            Constantes fVirt :
              FVIRTKEY = $01, FNOINVERT = $02, FSHIFT = $04,
              FCONTROL = $08, FALT = $10
            Constantes de touches virtuelles :
              VK_BACK = $08, VK_TAB = $09, VK_RETURN = $0D,
              VK_ESCAPE = $1B, VK_SPACE = $20, VK_END = $23,
              VK_HOME = $24, VK_LEFT = $25, VK_UP = $26,
              VK_RIGHT = $27, VK_DOWN = $28, VK_INSERT = $2D,
              VK_DELETE = $2E, VK_F1..$7B = VK_F12
            Function VKeyFromName(Const Name: String): Word
              retourner le code de touche virtuelle depuis le nom
            Procedure ParseAccelerators(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire le bloc ACCELERATORS ... BEGIN ... END :
              pour chaque ligne : lire touche, virgule, commande,
              options (VIRTKEY, SHIFT, CONTROL, ALT, NOINVERT)
              compiler en TAccelEntry
            Procedure WriteAccelerators(Const Entries: Array Of TAccelEntry;
              Count: Integer; NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word; LangId: Word)
              ecrire l en-tete de ressource RT_ACCELERATOR,
              puis pour chaque entree : WORD fVirt, WORD key, WORD cmd,
              WORD padding (bit $80 dans fVirt pour la derniere entree)

  TODO 13 - COMPILATION MENU [A FAIRE]
            Type TMenuItem : record
              Flags    : Word    (fItemFlags)
              MenuID   : Word    (identifiant ou 0 si popup)
              Text     : String  (texte de l element)
              IsPopup  : Boolean (True si sous-menu)
              IsSep    : Boolean (True si separateur)
              Level    : Integer (niveau d imbrication)
            End
            Constantes fItemFlags :
              MF_GRAYED = $0001, MF_DISABLED = $0002,
              MF_CHECKED = $0010, MF_POPUP = $0010,
              MF_MENUBARBREAK = $0020, MF_MENUBREAK = $0040,
              MF_SEPARATOR = $0800, MF_END = $0080
            Variables globales :
              MenuItems : Array[1..MAX_MENU_ITEMS] Of TMenuItem
              MenuItemCount : Integer
            Procedure ParseMenu(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire le bloc MENU ... BEGIN ... END :
              POPUP "text" ... BEGIN ... END pour les sous-menus
              MENUITEM "text", id [, options] pour les elements
              MENUITEM SEPARATOR pour les separateurs
            Procedure WriteMenu(Const Items: Array Of TMenuItem;
              Count: Integer; NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word; LangId: Word)
              ecrire l en-tete RT_MENU (WORD wVersion=0, WORD cbHeader=0),
              puis ecrire les elements recursivement :
              WORD fItemFlags, WORD menuId (si non popup),
              chaine Unicode terminee par $0000

  TODO 14 - COMPILATION DIALOG [A FAIRE]
            Type TDialogTemplate : record
              Style    : LongInt  (styles de fenetre)
              ExStyle  : LongInt  (styles etendus)
              X, Y     : Word     (position)
              CX, CY   : Word     (dimensions)
              Menu     : String   (ressource menu ou vide)
              Class    : String   (classe de fenetre ou vide)
              Title    : String   (titre de la boite)
              Font     : String   (nom de police si DS_SETFONT)
              FontSize : Word     (taille de police si DS_SETFONT)
            End
            Type TDialogControl : record
              Style    : LongInt  (styles du controle)
              ExStyle  : LongInt  (styles etendus)
              X, Y     : Word     (position)
              CX, CY   : Word     (dimensions)
              Id       : Word     (identifiant de controle)
              Class    : String   (classe ou atom predefini)
              Text     : String   (texte ou ressource)
            End
            Constantes de classes predefinies :
              DC_BUTTON = $0080, DC_EDIT = $0081, DC_STATIC = $0082,
              DC_LISTBOX = $0083, DC_SCROLLBAR = $0084, DC_COMBOBOX = $0085
            Constantes DS_* :
              DS_SETFONT = $0040, DS_MODALFRAME = $0080,
              DS_CENTER = $0800, DS_SYSMODAL = $0002
            Procedure ParseDialog(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word; IsEx: Boolean)
              lire le bloc DIALOG/DIALOGEX x,y,cx,cy ... BEGIN ... END :
              STYLE style | style | ...
              EXSTYLE exstyle
              CAPTION "titre"
              FONT pointsize, "nom"
              CLASS "classe"
              MENU ressource
              controles : PUSHBUTTON, DEFPUSHBUTTON, CHECKBOX, RADIOBUTTON,
              GROUPBOX, LTEXT, RTEXT, CTEXT, EDITTEXT, COMBOBOX, LISTBOX,
              SCROLLBAR, ICON, CONTROL
            Procedure WriteDialog(Const Dlg: TDialogTemplate;
              Const Controls: Array Of TDialogControl; CtrlCount: Integer;
              NameIsId: Boolean; NameId: Word; Const NameStr: String;
              MemFlags: Word; LangId: Word)
              ecrire l en-tete RT_DIALOG (DLGTEMPLATE 32 bits) :
              style, exstyle, cdit, x, y, cx, cy,
              menu (IdOrName), class (IdOrName), title (Unicode),
              [pointsize, typeface si DS_SETFONT],
              puis pour chaque controle : aligner sur 4 octets,
              style, exstyle, x, y, cx, cy, id, class (IdOrName),
              title (IdOrName), extraCount=0

  TODO 15 - COMPILATION VERSIONINFO [A FAIRE]
            Type TVersionInfo : record
              FileVersionMS, FileVersionLS : LongInt
              ProductVersionMS, ProductVersionLS : LongInt
              FileFlags, FileFlagsMask : LongInt
              FileOS, FileType, FileSubtype : LongInt
              StringValues : Array[1..64] Of record
                Key   : String
                Value : String
              End
              StringCount : Integer
              TranslationLang : Word
              TranslationCP   : Word
            End
            Constantes VFT_* :
              VFT_UNKNOWN = 0, VFT_APP = 1, VFT_DLL = 2,
              VFT_DRV = 3, VFT_FONT = 4, VFT_VXD = 5
            Constantes VOS_* :
              VOS_UNKNOWN = 0, VOS_NT_WINDOWS32 = $00040004
            Procedure ParseVersionInfo(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire le bloc VERSIONINFO ... BEGIN ... END :
              FILEVERSION a,b,c,d
              PRODUCTVERSION a,b,c,d
              FILEFLAGSMASK hex
              FILEFLAGS hex
              FILEOS hex
              FILETYPE hex
              FILESUBTYPE hex
              blocs BLOCK "StringFileInfo" et "VarFileInfo"
              dans StringFileInfo : BLOCK "codepage" puis VALUE "key", "value"
            Procedure WriteVersionInfo(Const Info: TVersionInfo;
              NameIsId: Boolean; NameId: Word; Const NameStr: String;
              MemFlags: Word; LangId: Word)
              ecrire l en-tete RT_VERSION (VS_VERSIONINFO) :
              WORD wLength, WORD wValueLength=52, WORD wType=0,
              WCHAR[] szKey="VS_VERSION_INFO", alignement,
              VS_FIXEDFILEINFO (52 octets), blocs StringFileInfo et
              VarFileInfo recursivement avec alignement sur 4 octets

  TODO 16 - COMPILATION ICON/CURSOR [A FAIRE]
            Type TIconDirEntry : record
              Width    : Byte   (largeur, 0 = 256)
              Height   : Byte   (hauteur, 0 = 256)
              ColorCount : Byte (nombre de couleurs, 0 si >= 256)
              Reserved : Byte   (= 0)
              Planes   : Word   (1 pour ICO; hotspot X pour CUR)
              BitCount : Word   (bits par pixel; hotspot Y pour CUR)
              BytesInRes : LongInt (taille des donnees DIB)
              ImageOffset : LongInt (offset dans le fichier .ico/.cur)
            End
            Procedure LoadIconFile(Const FileName: String;
              Var Entries: Array Of TIconDirEntry; Var EntryCount: Integer;
              Var Data: Array Of Pointer; Var DataSizes: Array Of LongInt)
              lire un fichier .ico : en-tete (6 octets), repertoire
              (EntryCount * 16 octets), puis les donnees DIB de chaque image
            Procedure LoadCursorFile(Const FileName: String;
              Var Entries: Array Of TIconDirEntry; Var EntryCount: Integer;
              Var Data: Array Of Pointer; Var DataSizes: Array Of LongInt)
              similaire a LoadIconFile pour les fichiers .cur
            Procedure WriteIcon(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const FileName: String;
              MemFlags: Word; LangId: Word)
              charger le fichier .ico, ecrire chaque image comme ressource
              RT_ICON individuelle (IDs generes automatiquement),
              puis ecrire une ressource RT_GROUP_ICON avec le repertoire
            Procedure WriteCursor(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const FileName: String;
              MemFlags: Word; LangId: Word)
              similaire a WriteIcon pour RT_CURSOR / RT_GROUP_CURSOR

  TODO 17 - COMPILATION BITMAP [A FAIRE]
            Type TBitmapFileHeader : record
              bfType      : Word    (doit etre 'BM' = $4D42)
              bfSize      : LongInt (taille totale du fichier)
              bfReserved1 : Word
              bfReserved2 : Word
              bfOffBits   : LongInt (offset des donnees pixels)
            End
            Type TBitmapInfoHeader : record
              biSize          : LongInt (= 40)
              biWidth         : LongInt
              biHeight        : LongInt
              biPlanes        : Word    (= 1)
              biBitCount      : Word    (bits par pixel)
              biCompression   : LongInt
              biSizeImage     : LongInt
              biXPelsPerMeter : LongInt
              biYPelsPerMeter : LongInt
              biClrUsed       : LongInt
              biClrImportant  : LongInt
            End
            Procedure LoadBitmapFile(Const FileName: String;
              Var Header: TBitmapInfoHeader; Var DataPtr: Pointer;
              Var DataSize: LongInt)
              lire un fichier .bmp : verifier bfType='BM',
              lire TBitmapInfoHeader, puis les donnees DIB
              (palette + pixels), retourner sans le TBitmapFileHeader
            Procedure WriteBitmap(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const FileName: String;
              MemFlags: Word; LangId: Word)
              charger le fichier .bmp, ecrire une ressource RT_BITMAP
              contenant TBitmapInfoHeader + palette + pixels (sans
              TBitmapFileHeader)

  TODO 18 - COMPILATION GROUP_ICON/GROUP_CURSOR [A FAIRE]
            Type TGrpIconDirEntry : record
              Width    : Byte
              Height   : Byte
              ColorCount : Byte
              Reserved : Byte
              Planes   : Word
              BitCount : Word
              BytesInRes : LongInt
              Id       : Word    (identifiant de la ressource RT_ICON associee)
            End
            Variables globales :
              NextIconId   : Word (prochain ID pour RT_ICON = 1)
              NextCursorId : Word (prochain ID pour RT_CURSOR = 1)
            Procedure WriteGroupIconHeader(GroupId: Word;
              Const Entries: Array Of TGrpIconDirEntry;
              EntryCount: Integer; MemFlags: Word; LangId: Word)
              ecrire une ressource RT_GROUP_ICON :
              WORD Reserved=0, WORD ResType=1 (ICO), WORD Count,
              puis pour chaque entree : TGrpIconDirEntry (14 octets)
            Procedure WriteGroupCursorHeader(GroupId: Word;
              Const Entries: Array Of TGrpIconDirEntry;
              EntryCount: Integer; MemFlags: Word; LangId: Word)
              similaire avec ResType=2 (CUR) pour RT_GROUP_CURSOR

  TODO 19 - COMPILATION RCDATA [A FAIRE]
            Procedure ParseRCData(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire le bloc RCDATA ... BEGIN ... END :
              donnees litterales : nombres (octets/words), chaines "...",
              ou reference a un fichier externe "fichier.bin"
              si donnees litterales : parser chaque valeur hexadecimale
              ou chaine et stocker dans un tampon
              si fichier externe : lire le contenu binaire du fichier
            Procedure WriteRCData(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const Data: Array Of Byte;
              DataSize: LongInt; MemFlags: Word; LangId: Word)
              ecrire une ressource RT_RCDATA avec les donnees brutes
            Procedure WriteRCDataFromFile(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const FileName: String;
              MemFlags: Word; LangId: Word)
              lire le fichier externe et ecrire comme RT_RCDATA

  TODO 20 - COMPILATION MANIFEST [A FAIRE]
            Procedure ParseManifest(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire la declaration MANIFEST "fichier.xml" ou
              MANIFEST id "fichier.xml" :
              si fichier externe : lire le contenu XML (UTF-8)
              si bloc inline BEGIN ... END : parser les donnees comme texte
            Procedure WriteManifest(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; Const FileName: String;
              MemFlags: Word; LangId: Word)
              lire le fichier .xml externe et ecrire comme RT_MANIFEST
              (les donnees sont stockees telles quelles, UTF-8)
            Function ValidateManifestXML(Const Data: Array Of Char;
              Size: LongInt): Boolean
              validation basique du XML : verifier que le fichier commence
              par <?xml ou <assembly, et contient </assembly>

  TODO 21 - PREPROCESSEUR #INCLUDE / #DEFINE [A FAIRE]
            Variables globales :
              Defines      : Array[1..256] Of record
                Name  : String
                Value : String
              End
              DefineCount  : Integer
              IncludeStack : Array[1..MAX_INCLUDES] Of record
                FileName : String
                FileHandle : Text
                Line     : Integer
                Col      : Integer
              End
              IncludeLevel : Integer
            Procedure AddDefine(Const Name, Value: String)
              ajouter une definition au tableau Defines
            Procedure RemoveDefine(Const Name: String)
              supprimer une definition (#undef)
            Function IsDefined(Const Name: String): Boolean
              verifier si un symbole est defini
            Function ExpandDefines(Const Line: String): String
              remplacer les occurrences des symboles definis par leur valeur
            Procedure ProcessInclude(Const FileName: String)
              empiler le fichier courant sur IncludeStack,
              ouvrir le nouveau fichier, incrementer IncludeLevel,
              parser recursivement puis revenir au fichier parent
            Procedure ProcessDefine
              lire #define NOM [valeur] et appeler AddDefine
            Procedure ProcessUndef
              lire #undef NOM et appeler RemoveDefine
            Procedure ProcessIfdef
              lire #ifdef NOM, si non defini : sauter jusqu a #else/#endif
            Procedure ProcessIfndef
              lire #ifndef NOM, si defini : sauter jusqu a #else/#endif
            Procedure ProcessElse
              inverser l etat conditionnel
            Procedure ProcessEndif
              terminer le bloc conditionnel
            Function FindIncludeFile(Const FileName: String): String
              chercher le fichier dans les chemins IncludePaths

  TODO 22 - RESOLUTION DES CHEMINS DE FICHIERS [A FAIRE]
            Variables globales :
              BasePath : String (repertoire du fichier .RC source)
            Procedure InitBasePath(Const SrcFileName: String)
              extraire le chemin du fichier source pour resoudre
              les chemins relatifs des ressources
            Function ResolveResourcePath(Const FileName: String): String
              resoudre le chemin d un fichier ressource (icone, bitmap, etc.)
              essayer dans l ordre :
              1. chemin absolu si commence par / ou X:\
              2. chemin relatif a BasePath
              3. chemins dans IncludePaths
              4. chemin relatif au repertoire courant
              retourner le premier chemin existant, ou lever une erreur
            Function NormalizePath(Const Path: String): String
              normaliser les separateurs de chemin (/ vs \)
              et resoudre les .. et .
            Function IsAbsolutePath(Const Path: String): Boolean
              determiner si un chemin est absolu

  TODO 23 - VALIDATION ET MESSAGES D'ERREUR [A FAIRE]
            Variables globales :
              ErrorCount   : Integer
              WarningCount : Integer
            Procedure Error(Const Msg: String)
              afficher une erreur avec le numero de ligne et colonne,
              incrementer ErrorCount
            Procedure ErrorFmt(Const Fmt: String; Args: Array Of String)
              erreur formatee avec arguments
            Procedure Warning(Const Msg: String)
              afficher un avertissement, incrementer WarningCount
            Procedure WarningFmt(Const Fmt: String; Args: Array Of String)
              avertissement formate
            Procedure ExpectError(Expected, Found: String)
              'Attendu "expected", trouve "found"'
            Procedure SyntaxError(Const Msg: String)
              erreur de syntaxe fatale, arreter la compilation
            Procedure FileNotFoundError(Const FileName: String)
              erreur fichier non trouve
            Procedure DuplicateResourceError(TypeId, NameId: Word;
              Const NameStr: String)
              erreur ressource deja definie
            Function HasErrors: Boolean
              retourner True si ErrorCount > 0
            Procedure DisplayErrorSummary
              afficher le nombre d erreurs et d avertissements

  TODO 24 - GENERATION FICHIER .RES COMPLET [A FAIRE]
            Procedure CompileRC(Const Opts: TOptions)
              orchestrateur principal :
              1. initialiser les structures (ressources, chaines, defines)
              2. ouvrir le fichier source .RC
              3. creer le fichier de sortie .RES
              4. si format 32 bits : ecrire WriteNullHeader32
              5. parser le fichier source : ParseFile
              6. ecrire les ressources collectees :
                 - pour chaque ressource dans Resources[] :
                   ecrire l en-tete puis les donnees
                 - grouper les STRINGTABLE et les ecrire
              7. si format 16 bits : ecrire WriteEndMarker16
              8. fermer les fichiers
              9. afficher le rapport de compilation
            Procedure WriteAllResources(OutputFormat: Integer)
              parcourir Resources[] et ecrire chaque ressource
              avec l en-tete approprie (16 ou 32 bits)
            Procedure SortResourcesByType
              optionnel : trier les ressources par type pour optimiser
              la structure du fichier .RES

  TODO 25 - VERIFICATION ET RAPPORT FINAL [A FAIRE]
            Function GetFileSize(Const FName: String): LongInt
              ouvrir le fichier, chercher la fin, retourner la taille
            Procedure VerifyResFile(Const OutFileName: String)
              verifier que OutFileName existe et n est pas vide
              ouvrir le fichier .RES en lecture et verifier l en-tete
              (ressource nulle pour 32 bits, en-tete valide pour 16 bits)
              afficher un avertissement si le fichier semble corrompu
            Procedure DisplayFinalReport(Const Opts: TOptions)
              afficher le rapport complet :
              '=== RC - Rapport de compilation ==='
              'Fichier source   : ' + Opts.SrcFile
              'Format genere    : RES ' + (16/32) + ' bits'
              'Ressources total : ' + IntToStr(ResCount)
              Pour chaque type RT_* present : compter et afficher
              '  RT_ICON        : N ressource(s)'
              '  RT_BITMAP      : N ressource(s)'
              '  RT_MENU        : N ressource(s)'
              '  RT_DIALOG      : N ressource(s)'
              '  RT_STRING      : N bloc(s), N chaine(s)'
              '  RT_ACCELERATOR : N table(s)'
              '  RT_VERSION     : N ressource(s)'
              '  RT_RCDATA      : N ressource(s)'
              '  RT_MANIFEST    : N ressource(s)'
              'Erreurs   : ' + IntToStr(ErrorCount)
              'Warnings  : ' + IntToStr(WarningCount)
              'Fichier RES genere: ' + Opts.OutFile
              'Taille RES        : ' + IntToStr(GetFileSize(Opts.OutFile)) + ' octets'
              Si Opts.Verbose : afficher le detail de chaque ressource
              (type, nom/ID, langue, taille, flags memoire)

*)

Program RC;

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
  RC_VERSION = '1.0';
  RC_DATE    = '2026-03-30';

  { Codes de retour }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Formats de fichier .RES }
  FMT_RES16  = 1;   { Windows 3.x / Borland Pascal 16 bits }
  FMT_RES32  = 2;   { Windows NT/9x+ 32 bits               }

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

  { Tailles maximales }
  MAX_RESOURCES   = 4096;
  MAX_STRINGS     = 4096;
  MAX_ACCEL       = 256;
  MAX_MENU_ITEMS  = 512;
  MAX_DIALOG_CTRL = 256;
  MAX_TOKENS      = 8192;
  MAX_INCLUDES    = 64;
  MAX_DEFINES     = 256;
  MAX_INCLUDE_PATHS = 16;

  { Flags memoire }
  MF_MOVEABLE    = $0010;
  MF_PURE        = $0020;
  MF_PRELOAD     = $0040;
  MF_DISCARDABLE = $1000;
  MF_FIXED       = $0000;

  { Langues courantes }
  LANG_NEUTRAL      = $0000;
  LANG_ENGLISH_US   = $0409;
  LANG_ENGLISH_UK   = $0809;
  LANG_FRENCH       = $040C;
  LANG_FRENCH_CANADA = $0C0C;
  LANG_GERMAN       = $0407;
  LANG_ITALIAN      = $0410;
  LANG_SPANISH      = $0C0A;
  LANG_PORTUGUESE_BR = $0416;
  LANG_RUSSIAN      = $0419;
  LANG_JAPANESE     = $0411;
  LANG_CHINESE_SIMPL = $0804;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[255];

  TOptions = Record
    SrcFile      : TString;
    OutFile      : TString;
    Output16     : Boolean;
    Output32     : Boolean;
    Verbose      : Boolean;
    IncludePaths : Array[1..MAX_INCLUDE_PATHS] Of TString;
    IncludeCount : Integer;
    Defines      : Array[1..64] Of TString;
    DefineCount  : Integer;
  End;
  
  { TODO 10 : Table des ressources }
  TResourceEntry = Record
    TypeIsId   : Boolean;   { True si type numerique }
    TypeId     : Word;      { identifiant de type }
    TypeName   : TString;   { nom de type si Non TypeIsId }
    NameIsId   : Boolean;   { True si nom numerique }
    NameId     : Word;      { identifiant de nom }
    NameStr    : TString;   { nom si Non NameIsId }
    DataSize   : LongInt;   { taille des donnees }
    DataOfs    : LongInt;   { offset dans le fichier genere }
    MemFlags   : Word;      { attributs memoire }
    LangId     : Word;      { identifiant de langue }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;
  
  { TODO 08 : Variables pour le traitement des Language IDs }
  CurrentLangId : Word;
  
  { TODO 09 : Variables pour le traitement des flags memoire }
  DefaultMemFlags : Word;
  
  { TODO 10 : Table des ressources }
  Resources : Array[1..MAX_RESOURCES] Of TResourceEntry;
  ResCount  : Integer;

{ ============================================================
  PROCEDURES ET FONCTIONS
  ============================================================ }

{ ----- Procedure FatalError ----- }
Procedure FatalError(Msg : TString);
Begin
  WriteLn('RC: ERREUR FATALE: ', Msg);
  Halt(EXIT_ERROR);
End;

{ ----- Procedure ShowHelp ----- }
Procedure ShowHelp;
Begin
  WriteLn('RC v', RC_VERSION,
          ' - Compilateur de ressources Windows (.RC -> .RES)');
  WriteLn;
  WriteLn('Syntaxe : RC fichier.rc [-o sortie.res] [-16|-32] [-I<chemin>] [-D<sym>] [-v] [-h]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -o nom       : specifier le nom du fichier de sortie .RES');
  WriteLn('                 (defaut : meme nom que le fichier source, extension .RES)');
  WriteLn('  -16          : generer en format RES 16 bits');
  WriteLn('                 (Windows 3.x, Borland Pascal, Turbo Pascal pour Windows)');
  WriteLn('  -32          : generer en format RES 32 bits (defaut)');
  WriteLn('                 (Windows NT/9x+, MSVC, Delphi, Free Pascal/windres)');
  WriteLn('  -I<chemin>   : ajouter un chemin de recherche pour les includes');
  WriteLn('  -D<symbole>  : definir un symbole de preprocesseur');
  WriteLn('  -v           : mode verbeux (afficher details des ressources)');
  WriteLn('  -h, --help   : afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  RC monapp.rc                    Compile monapp.rc -> monapp.res (32 bits)');
  WriteLn('  RC monapp.rc -o sortie.res      Compile vers sortie.res');
  WriteLn('  RC monapp.rc -16                Compile en format 16 bits');
  WriteLn('  RC monapp.rc -Iinclude -DDEBUG  Avec chemin include et symbole DEBUG');
  Halt(EXIT_OK);
End;

{ ----- Function UpCaseStr ----- }
Function UpCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Res : TString;
Begin
  Res := '';
  For I := 1 To Length(S) Do
    Res := Res + UpCase(S[I]);
  UpCaseStr := Res;
End;

{ ----- Function ChangeFileExt ----- }
Function ChangeFileExt(Const FName, NewExt : TString) : TString;
Var
  I   : Integer;
  Res : TString;
Begin
  Res := FName;
  For I := Length(FName) DownTo 1 Do
  Begin
    If FName[I] = '.' Then
    Begin
      Res := Copy(FName, 1, I - 1) + NewExt;
      Break;
    End;
    If (FName[I] = '\') Or (FName[I] = '/') Then
      Break;
  End;
  If Res = FName Then
    Res := FName + NewExt;
  ChangeFileExt := Res;
End;

{ ============================================================
  TODO 02 : FONCTIONS UTILITAIRES
  ============================================================ }

{ ----- Function HexByte ----- }
Function HexByte(B : Byte) : TString;
Const
  HexChars : Array[0..15] Of Char = '0123456789ABCDEF';
Begin
  HexByte := HexChars[B Shr 4] + HexChars[B And $0F];
End;

{ ----- Function HexWord ----- }
Function HexWord(W : Word) : TString;
Begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

{ ----- Function HexDWord ----- }
Function HexDWord(D : LongInt) : TString;
Begin
  HexDWord := HexWord((D Shr 16) And $FFFF) + HexWord(D And $FFFF);
End;

{ ----- Function IntToStr ----- }
Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ ----- Function StrToInt ----- }
Function StrToInt(Const S : TString) : LongInt;
Var
  I, Code : Integer;
  Val     : LongInt;
  Tmp     : TString;
Begin
  Tmp := S;
  { Supprimer les espaces }
  While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do
    Delete(Tmp, 1, 1);
  While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do
    Delete(Tmp, Length(Tmp), 1);

  Val := 0;
  If Length(Tmp) = 0 Then
  Begin
    StrToInt := 0;
    Exit;
  End;

  { Format hexadecimal 0x... ou 0X... }
  If (Length(Tmp) > 2) And (Tmp[1] = '0') And
     ((Tmp[2] = 'x') Or (Tmp[2] = 'X')) Then
  Begin
    Delete(Tmp, 1, 2);
    For I := 1 To Length(Tmp) Do
    Begin
      Val := Val Shl 4;
      Case Tmp[I] Of
        '0'..'9': Val := Val + Ord(Tmp[I]) - Ord('0');
        'A'..'F': Val := Val + Ord(Tmp[I]) - Ord('A') + 10;
        'a'..'f': Val := Val + Ord(Tmp[I]) - Ord('a') + 10;
      End;
    End;
    StrToInt := Val;
    Exit;
  End;

  { Format hexadecimal ...h ou ...H }
  If (Length(Tmp) > 1) And ((Tmp[Length(Tmp)] = 'h') Or (Tmp[Length(Tmp)] = 'H')) Then
  Begin
    Delete(Tmp, Length(Tmp), 1);
    For I := 1 To Length(Tmp) Do
    Begin
      Val := Val Shl 4;
      Case Tmp[I] Of
        '0'..'9': Val := Val + Ord(Tmp[I]) - Ord('0');
        'A'..'F': Val := Val + Ord(Tmp[I]) - Ord('A') + 10;
        'a'..'f': Val := Val + Ord(Tmp[I]) - Ord('a') + 10;
      End;
    End;
    StrToInt := Val;
    Exit;
  End;

  { Format decimal }
  System.Val(S, Val, Code);
  If Code = 0 Then
    StrToInt := Val
  Else
    StrToInt := 0;
End;

{ ----- Function Trim ----- }
Function Trim(Const S : TString) : TString;
Var
  L, R : Integer;
Begin
  L := 1;
  R := Length(S);
  While (L <= R) And (S[L] = ' ') Do
    Inc(L);
  While (R >= L) And (S[R] = ' ') Do
    Dec(R);
  If L > R Then
    Trim := ''
  Else
    Trim := Copy(S, L, R - L + 1);
End;

{ ----- Function FileExists ----- }
Function FileExists(Const FName : TString) : Boolean;
Var
  F : File;
Begin
  {$I-}
  Assign(F, FName);
  Reset(F, 1);
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
  {$I+}
End;

{ ----- Function ExtractFileName ----- }
Function ExtractFileName(Const FName : TString) : TString;
Var
  I : Integer;
Begin
  For I := Length(FName) DownTo 1 Do
  Begin
    If (FName[I] = '\') Or (FName[I] = '/') Then
    Begin
      ExtractFileName := Copy(FName, I + 1, Length(FName) - I);
      Exit;
    End;
  End;
  ExtractFileName := FName;
End;

{ ----- Function ExtractFilePath ----- }
Function ExtractFilePath(Const FName : TString) : TString;
Var
  I : Integer;
Begin
  For I := Length(FName) DownTo 1 Do
  Begin
    If (FName[I] = '\') Or (FName[I] = '/') Then
    Begin
      ExtractFilePath := Copy(FName, 1, I);
      Exit;
    End;
  End;
  ExtractFilePath := '';
End;

{ ----- Function CharToWChar ----- }
Function CharToWChar(C : Char) : Word;
Begin
  { Latin-1 vers Unicode (les 256 premiers caracteres sont identiques) }
  CharToWChar := Ord(C);
End;

{ ----- Type pour tableau de WCHAR ----- }
Type
  TWCharArray = Array[0..255] Of Word;

{ ----- Procedure StrToUniStr ----- }
Procedure StrToUniStr(Const S : TString; Var Arr : TWCharArray; Var Len : Integer);
Var
  I : Integer;
Begin
  Len := Length(S);
  For I := 1 To Len Do
    Arr[I - 1] := CharToWChar(S[I]);
  { Ajouter le terminateur null }
  Arr[Len] := 0;
  Inc(Len); { Len inclut le terminateur null }
End;

{ ============================================================
  TODO 03 : LEXER RC (TOKENISATION)
  ============================================================ }

{ ----- Type TTokenKind ----- }
Type
  TTokenKind = (
    TK_EOF,           { Fin de fichier }
    TK_IDENT,         { Identifiant ou mot-cle }
    TK_NUMBER,        { Nombre decimal ou hexadecimal }
    TK_STRING,        { Chaine entre guillemets "..." }
    TK_CHAR,          { Caractere unique }
    TK_COMMA,         (* , *)
    TK_LPAREN,        (* ( *)
    TK_RPAREN,        (* ) *)
    TK_LBRACE,        (* accolade ouvrante *)
    TK_RBRACE,        (* accolade fermante *)
    TK_PIPE,          (* | *)
    TK_PLUS,          { + }
    TK_MINUS,         { - }
    TK_NOT,           { ~ ou NOT }
    TK_COLON,         { : }
    TK_BEGIN,         { BEGIN }
    TK_END,           { END }
    TK_PREPROCESSOR,  { #directive }
    TK_COMMENT,       { Commentaire }
    TK_NEWLINE        { Nouvelle ligne }
  );

{ ----- Type TToken ----- }
Type
  TToken = Record
    Kind   : TTokenKind;  { Type du token }
    Value  : TString;     { Contenu textuel du token }
    IntVal : LongInt;     { Valeur numerique si TK_NUMBER }
    Line   : Integer;     { Numero de ligne pour les erreurs }
    Col    : Integer;     { Colonne pour les erreurs }
  End;

{ ----- Variables globales du lexer ----- }
Var
  LexFile    : Text;       { Fichier source ouvert }
  LexLine    : Integer;    { Numero de ligne courant }
  LexCol     : Integer;    { Colonne courante }
  LexChar    : Char;       { Caractere courant }
  LexEOF     : Boolean;    { True si fin de fichier atteinte }
  CurrToken  : TToken;     { Token courant }
  PeekToken  : TToken;     { Token en avance si peek actif }
  HasPeek    : Boolean;    { True si PeekToken est valide }

{ ----- Procedure OpenSourceFile ----- }
Procedure OpenSourceFile(Const FName : TString);
Begin
  {$I-}
  Assign(LexFile, FName);
  Reset(LexFile);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier : ' + FName);

  LexLine := 1;
  LexCol := 0;
  LexEOF := False;
  HasPeek := False;

  { Lire le premier caractere }
  If Not Eof(LexFile) Then
  Begin
    Read(LexFile, LexChar);
    LexCol := 1;
  End
  Else
  Begin
    LexChar := #0;
    LexEOF := True;
  End;
End;

{ ----- Procedure CloseSourceFile ----- }
Procedure CloseSourceFile;
Begin
  {$I-}
  Close(LexFile);
  {$I+}
End;

{ ----- Function ReadChar ----- }
Function ReadChar : Char;
Begin
  If LexEOF Then
  Begin
    ReadChar := #0;
    Exit;
  End;

  ReadChar := LexChar;

  { Lire le caractere suivant }
  If Not Eof(LexFile) Then
  Begin
    Read(LexFile, LexChar);
    If LexChar = #10 Then
    Begin
      Inc(LexLine);
      LexCol := 0;
    End
    Else If LexChar <> #13 Then
      Inc(LexCol);
  End
  Else
  Begin
    LexChar := #0;
    LexEOF := True;
  End;
End;

{ ----- Function PeekChar ----- }
Function PeekChar : Char;
Begin
  PeekChar := LexChar;
End;

{ ----- Procedure SkipWhitespace ----- }
Procedure SkipWhitespace;
Var
  C : Char;
Begin
  While Not LexEOF Do
  Begin
    C := PeekChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Then
      ReadChar
    Else
      Exit;
  End;
End;

{ ----- Procedure SkipLineComment ----- }
Procedure SkipLineComment;
Var
  C : Char;
Begin
  { On a deja lu les // }
  While Not LexEOF Do
  Begin
    C := PeekChar;
    If (C = #10) Or (C = #13) Then
      Exit;
    ReadChar;
  End;
End;

{ ----- Procedure SkipBlockComment ----- }
Procedure SkipBlockComment;
Var
  C : Char;
Begin
  { On a deja lu le /* }
  While Not LexEOF Do
  Begin
    C := ReadChar;
    If (C = '*') And (PeekChar = '/') Then
    Begin
      ReadChar; { Consommer le / }
      Exit;
    End;
  End;
End;

{ ----- Function LexNumber ----- }
Function LexNumber : TToken;
Var
  Tok    : TToken;
  S      : TString;
  C      : Char;
  IsHex  : Boolean;
Begin
  Tok.Kind := TK_NUMBER;
  Tok.Line := LexLine;
  Tok.Col := LexCol;
  S := '';
  IsHex := False;

  C := PeekChar;

  { Verifier si c est un nombre hexadecimal 0x... }
  If C = '0' Then
  Begin
    S := S + ReadChar;
    C := PeekChar;
    If (C = 'x') Or (C = 'X') Then
    Begin
      S := S + ReadChar;
      IsHex := True;
      { Lire les chiffres hexadecimaux }
      While Not LexEOF Do
      Begin
        C := PeekChar;
        If ((C >= '0') And (C <= '9')) Or
           ((C >= 'A') And (C <= 'F')) Or
           ((C >= 'a') And (C <= 'f')) Then
          S := S + ReadChar
        Else
          Break;
      End;
    End;
  End;

  { Lire les chiffres decimaux si pas hexadecimal }
  If Not IsHex Then
  Begin
    While Not LexEOF Do
    Begin
      C := PeekChar;
      If (C >= '0') And (C <= '9') Then
        S := S + ReadChar
      Else
        Break;
    End;

    { Verifier le suffixe h ou H pour hexadecimal }
    C := PeekChar;
    If (C = 'h') Or (C = 'H') Then
    Begin
      S := S + ReadChar;
      IsHex := True;
    End;
  End;

  Tok.Value := S;
  Tok.IntVal := StrToInt(S);
  LexNumber := Tok;
End;

{ ----- Function LexString ----- }
Function LexString : TToken;
Var
  Tok   : TToken;
  S     : TString;
  C     : Char;
  Quote : Char;
Begin
  Tok.Kind := TK_STRING;
  Tok.Line := LexLine;
  Tok.Col := LexCol;
  S := '';

  Quote := ReadChar; { Lire le guillemet ouvrant }

  While Not LexEOF Do
  Begin
    C := PeekChar;
    If C = Quote Then
    Begin
      ReadChar; { Consommer le guillemet fermant }
      Break;
    End
    Else If C = '\' Then
    Begin
      { Sequence d echappement }
      ReadChar;
      C := ReadChar;
      Case C Of
        'n' : S := S + #10;
        't' : S := S + #9;
        'r' : S := S + #13;
        '\' : S := S + '\';
        '"' : S := S + '"';
        '''' : S := S + '''';
        '0' : S := S + #0;
      Else
        S := S + C;
      End;
    End
    Else If (C = #10) Or (C = #13) Then
    Begin
      FatalError('Chaine non terminee a la ligne ' + IntToStr(LexLine));
    End
    Else
      S := S + ReadChar;
  End;

  Tok.Value := S;
  Tok.IntVal := 0;
  LexString := Tok;
End;

{ ----- Function LexIdent ----- }
Function LexIdent : TToken;
Var
  Tok : TToken;
  S   : TString;
  C   : Char;
  SUp : TString;
Begin
  Tok.Kind := TK_IDENT;
  Tok.Line := LexLine;
  Tok.Col := LexCol;
  S := '';

  While Not LexEOF Do
  Begin
    C := PeekChar;
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Then
      S := S + ReadChar
    Else
      Break;
  End;

  Tok.Value := S;
  Tok.IntVal := 0;

  { Verifier les mots-cles speciaux }
  SUp := UpCaseStr(S);
  If SUp = 'BEGIN' Then
    Tok.Kind := TK_BEGIN
  Else If SUp = 'END' Then
    Tok.Kind := TK_END
  Else If SUp = 'NOT' Then
    Tok.Kind := TK_NOT;

  LexIdent := Tok;
End;

{ ----- Function NextToken ----- }
Function NextToken : TToken;
Var
  Tok      : TToken;
  C        : Char;
  C2       : Char;
  Continue : Boolean;
Begin
  { Verifier si on a un token en avance }
  If HasPeek Then
  Begin
    CurrToken := PeekToken;
    HasPeek := False;
    NextToken := CurrToken;
    Exit;
  End;

  { Initialiser le token }
  Tok.Kind := TK_EOF;
  Tok.Value := '';
  Tok.IntVal := 0;
  Tok.Line := LexLine;
  Tok.Col := LexCol;

  { Boucle pour sauter les commentaires }
  Continue := True;
  While Continue Do
  Begin
    Continue := False;

    { Sauter les espaces }
    SkipWhitespace;

    If LexEOF Then
    Begin
      CurrToken := Tok;
      NextToken := Tok;
      Exit;
    End;

    Tok.Line := LexLine;
    Tok.Col := LexCol;
    C := PeekChar;

    { Nouvelle ligne }
    If C = #10 Then
    Begin
      Tok.Kind := TK_NEWLINE;
      Tok.Value := ReadChar;
      CurrToken := Tok;
      NextToken := Tok;
      Exit;
    End;

    { Commentaire // ou /* }
    If C = '/' Then
    Begin
      ReadChar;
      C2 := PeekChar;
      If C2 = '/' Then
      Begin
        ReadChar;
        SkipLineComment;
        Continue := True;
      End
      Else If C2 = '*' Then
      Begin
        ReadChar;
        SkipBlockComment;
        Continue := True;
      End
      Else
      Begin
        { C est juste un / (rare en RC) }
        Tok.Kind := TK_IDENT;
        Tok.Value := '/';
        CurrToken := Tok;
        NextToken := Tok;
        Exit;
      End;
    End;
  End;

  { Preprocesseur # }
  C := PeekChar;
  If C = '#' Then
  Begin
    Tok.Kind := TK_PREPROCESSOR;
    Tok.Value := ReadChar;
    { Lire le nom de la directive }
    While Not LexEOF Do
    Begin
      C := PeekChar;
      If ((C >= 'A') And (C <= 'Z')) Or
         ((C >= 'a') And (C <= 'z')) Or
         (C = '_') Then
        Tok.Value := Tok.Value + ReadChar
      Else
        Break;
    End;
    CurrToken := Tok;
    NextToken := Tok;
    Exit;
  End;

  { Nombre }
  If (C >= '0') And (C <= '9') Then
  Begin
    Tok := LexNumber;
    CurrToken := Tok;
    NextToken := Tok;
    Exit;
  End;

  { Chaine }
  If (C = '"') Or (C = '''') Then
  Begin
    Tok := LexString;
    CurrToken := Tok;
    NextToken := Tok;
    Exit;
  End;

  { Identifiant }
  If ((C >= 'A') And (C <= 'Z')) Or
     ((C >= 'a') And (C <= 'z')) Or
     (C = '_') Then
  Begin
    Tok := LexIdent;
    CurrToken := Tok;
    NextToken := Tok;
    Exit;
  End;

  { Ponctuation et operateurs }
  Case C Of
    ',' :
    Begin
      Tok.Kind := TK_COMMA;
      Tok.Value := ReadChar;
    End;
    '(' :
    Begin
      Tok.Kind := TK_LPAREN;
      Tok.Value := ReadChar;
    End;
    ')' :
    Begin
      Tok.Kind := TK_RPAREN;
      Tok.Value := ReadChar;
    End;
    '{' :
    Begin
      Tok.Kind := TK_LBRACE;
      Tok.Value := ReadChar;
    End;
    '}' :
    Begin
      Tok.Kind := TK_RBRACE;
      Tok.Value := ReadChar;
    End;
    '|' :
    Begin
      Tok.Kind := TK_PIPE;
      Tok.Value := ReadChar;
    End;
    '+' :
    Begin
      Tok.Kind := TK_PLUS;
      Tok.Value := ReadChar;
    End;
    '-' :
    Begin
      Tok.Kind := TK_MINUS;
      Tok.Value := ReadChar;
    End;
    '~' :
    Begin
      Tok.Kind := TK_NOT;
      Tok.Value := ReadChar;
    End;
    ':' :
    Begin
      Tok.Kind := TK_COLON;
      Tok.Value := ReadChar;
    End;
  Else
    { Caractere inconnu - le sauter }
    Tok.Kind := TK_CHAR;
    Tok.Value := ReadChar;
  End;

  CurrToken := Tok;
  NextToken := Tok;
End;

{ ----- Function PeekTokenFn ----- }
Function PeekTokenFn : TToken;
Begin
  If Not HasPeek Then
  Begin
    PeekToken := NextToken;
    HasPeek := True;
  End;
  PeekTokenFn := PeekToken;
End;

{ ============================================================
  TODO 04 : PARSER RC (ANALYSE SYNTAXIQUE)
  ============================================================ }

{ ----- Type TStatementKind ----- }
Type
  TStatementKind = (
    ST_INCLUDE,       { #include }
    ST_DEFINE,        { #define }
    ST_UNDEF,         { #undef }
    ST_IFDEF,         { #ifdef }
    ST_IFNDEF,        { #ifndef }
    ST_ELSE,          { #else }
    ST_ENDIF,         { #endif }
    ST_PRAGMA,        { #pragma }
    ST_LANGUAGE,      { LANGUAGE }
    ST_STRINGTABLE,   { STRINGTABLE }
    ST_ACCELERATORS,  { ACCELERATORS }
    ST_MENU,          { MENU }
    ST_MENUEX,        { MENUEX }
    ST_DIALOG,        { DIALOG }
    ST_DIALOGEX,      { DIALOGEX }
    ST_VERSIONINFO,   { VERSIONINFO }
    ST_ICON,          { ICON }
    ST_CURSOR,        { CURSOR }
    ST_BITMAP,        { BITMAP }
    ST_FONT,          { FONT }
    ST_RCDATA,        { RCDATA }
    ST_MESSAGETABLE,  { MESSAGETABLE }
    ST_MANIFEST,      { MANIFEST }
    ST_HTML,          { HTML }
    ST_USER_TYPE      { Type utilisateur }
  );

{ ----- Type TResourceId ----- }
Type
  TResourceId = Record
    IsNumeric : Boolean;   { True si ID numerique, False si chaine }
    NumId     : LongInt;   { ID numerique }
    StrId     : TString;   { ID chaine }
  End;

{ ----- Variables globales du parser ----- }
Var
  ParseError     : Boolean;    { True si une erreur de parsing s est produite }
  ParseErrorMsg  : TString;    { Message d erreur }

{ ----- Procedure SyntaxError ----- }
Procedure SyntaxError(Const Msg : TString);
Begin
  ParseError := True;
  ParseErrorMsg := Msg;
  WriteLn('Erreur de syntaxe ligne ', LexLine, ' col ', LexCol, ': ', Msg);
End;

{ ----- Function ExpectToken ----- }
Function ExpectToken(Kind : TTokenKind) : TToken;
Var
  Tok : TToken;
Begin
  Tok := NextToken;
  If Tok.Kind <> Kind Then
  Begin
    SyntaxError('Token inattendu: ' + Tok.Value);
  End;
  ExpectToken := Tok;
End;

{ ----- Function ExpectIdent ----- }
Function ExpectIdent : TString;
Var
  Tok : TToken;
Begin
  Tok := NextToken;
  If Tok.Kind <> TK_IDENT Then
  Begin
    SyntaxError('Identifiant attendu, trouve: ' + Tok.Value);
    ExpectIdent := '';
  End
  Else
    ExpectIdent := Tok.Value;
End;

{ ----- Function ExpectNumber ----- }
Function ExpectNumber : LongInt;
Var
  Tok : TToken;
Begin
  Tok := NextToken;
  If Tok.Kind <> TK_NUMBER Then
  Begin
    SyntaxError('Nombre attendu, trouve: ' + Tok.Value);
    ExpectNumber := 0;
  End
  Else
    ExpectNumber := Tok.IntVal;
End;

{ ----- Function ExpectString ----- }
Function ExpectString : TString;
Var
  Tok : TToken;
Begin
  Tok := NextToken;
  If Tok.Kind <> TK_STRING Then
  Begin
    SyntaxError('Chaine attendue, trouvee: ' + Tok.Value);
    ExpectString := '';
  End
  Else
    ExpectString := Tok.Value;
End;

{ ----- Forward declaration pour ParseExpression ----- }
Function ParseExpression : LongInt; Forward;

{ ----- Function ParsePrimaryExpr ----- }
Function ParsePrimaryExpr : LongInt;
Var
  Tok : TToken;
  Val : LongInt;
Begin
  Tok := PeekTokenFn;

  If Tok.Kind = TK_NUMBER Then
  Begin
    Tok := NextToken;
    ParsePrimaryExpr := Tok.IntVal;
  End
  Else If Tok.Kind = TK_IDENT Then
  Begin
    Tok := NextToken;
    { Les identifiants sont traites comme 0 pour l instant }
    { Dans une impl complete, on chercherait dans les defines }
    ParsePrimaryExpr := 0;
  End
  Else If Tok.Kind = TK_LPAREN Then
  Begin
    Tok := NextToken; { Consommer ( }
    Val := ParseExpression;
    ExpectToken(TK_RPAREN); { Attendre ) }
    ParsePrimaryExpr := Val;
  End
  Else If Tok.Kind = TK_NOT Then
  Begin
    Tok := NextToken; { Consommer NOT ou ~ }
    Val := ParsePrimaryExpr;
    ParsePrimaryExpr := Not Val;
  End
  Else If Tok.Kind = TK_MINUS Then
  Begin
    Tok := NextToken; { Consommer - }
    Val := ParsePrimaryExpr;
    ParsePrimaryExpr := -Val;
  End
  Else
  Begin
    SyntaxError('Expression attendue, trouvee: ' + Tok.Value);
    ParsePrimaryExpr := 0;
  End;
End;

{ ----- Function ParseExpression ----- }
Function ParseExpression : LongInt;
Var
  Left  : LongInt;
  Right : LongInt;
  Tok   : TToken;
Begin
  Left := ParsePrimaryExpr;

  { Verifier les operateurs binaires }
  Tok := PeekTokenFn;
  While (Tok.Kind = TK_PLUS) Or (Tok.Kind = TK_MINUS) Or (Tok.Kind = TK_PIPE) Do
  Begin
    Tok := NextToken; { Consommer l operateur }
    Right := ParsePrimaryExpr;

    Case Tok.Kind Of
      TK_PLUS  : Left := Left + Right;
      TK_MINUS : Left := Left - Right;
      TK_PIPE  : Left := Left Or Right;
    End;

    Tok := PeekTokenFn;
  End;

  ParseExpression := Left;
End;

{ ----- Function ParseResourceId ----- }
Function ParseResourceId : TResourceId;
Var
  Tok : TToken;
  Res : TResourceId;
Begin
  Tok := PeekTokenFn;

  If Tok.Kind = TK_NUMBER Then
  Begin
    Tok := NextToken;
    Res.IsNumeric := True;
    Res.NumId := Tok.IntVal;
    Res.StrId := '';
  End
  Else If Tok.Kind = TK_STRING Then
  Begin
    Tok := NextToken;
    Res.IsNumeric := False;
    Res.NumId := 0;
    Res.StrId := Tok.Value;
  End
  Else If Tok.Kind = TK_IDENT Then
  Begin
    Tok := NextToken;
    Res.IsNumeric := False;
    Res.NumId := 0;
    Res.StrId := Tok.Value;
  End
  Else
  Begin
    SyntaxError('ID de ressource attendu, trouve: ' + Tok.Value);
    Res.IsNumeric := True;
    Res.NumId := 0;
    Res.StrId := '';
  End;

  ParseResourceId := Res;
End;

{ ----- Function IsRCKeyword ----- }
Function IsRCKeyword(Const Ident : TString) : Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(Ident);
  IsRCKeyword :=
    (U = 'ACCELERATORS') Or
    (U = 'ALT') Or
    (U = 'ASCII') Or
    (U = 'AUTO3STATE') Or
    (U = 'AUTOCHECKBOX') Or
    (U = 'AUTORADIOBUTTON') Or
    (U = 'BEGIN') Or
    (U = 'BITMAP') Or
    (U = 'BLOCK') Or
    (U = 'CAPTION') Or
    (U = 'CHARACTERISTICS') Or
    (U = 'CHECKBOX') Or
    (U = 'CLASS') Or
    (U = 'COMBOBOX') Or
    (U = 'CONTROL') Or
    (U = 'CTEXT') Or
    (U = 'CURSOR') Or
    (U = 'DEFPUSHBUTTON') Or
    (U = 'DIALOG') Or
    (U = 'DIALOGEX') Or
    (U = 'DISCARDABLE') Or
    (U = 'EDITTEXT') Or
    (U = 'END') Or
    (U = 'EXSTYLE') Or
    (U = 'FILEFLAGS') Or
    (U = 'FILEFLAGSMASK') Or
    (U = 'FILEOS') Or
    (U = 'FILESUBTYPE') Or
    (U = 'FILETYPE') Or
    (U = 'FILEVERSION') Or
    (U = 'FIXED') Or
    (U = 'FONT') Or
    (U = 'GRAYED') Or
    (U = 'GROUPBOX') Or
    (U = 'HELP') Or
    (U = 'HTML') Or
    (U = 'ICON') Or
    (U = 'IMPURE') Or
    (U = 'INACTIVE') Or
    (U = 'LANGUAGE') Or
    (U = 'LISTBOX') Or
    (U = 'LOADONCALL') Or
    (U = 'LTEXT') Or
    (U = 'MANIFEST') Or
    (U = 'MENU') Or
    (U = 'MENUBARBREAK') Or
    (U = 'MENUBREAK') Or
    (U = 'MENUEX') Or
    (U = 'MENUITEM') Or
    (U = 'MESSAGETABLE') Or
    (U = 'MOVEABLE') Or
    (U = 'NOINVERT') Or
    (U = 'NOT') Or
    (U = 'POPUP') Or
    (U = 'PRELOAD') Or
    (U = 'PRODUCTVERSION') Or
    (U = 'PURE') Or
    (U = 'PUSHBOX') Or
    (U = 'PUSHBUTTON') Or
    (U = 'RADIOBUTTON') Or
    (U = 'RCDATA') Or
    (U = 'RTEXT') Or
    (U = 'SCROLLBAR') Or
    (U = 'SEPARATOR') Or
    (U = 'SHIFT') Or
    (U = 'STATE3') Or
    (U = 'STRINGTABLE') Or
    (U = 'STYLE') Or
    (U = 'VALUE') Or
    (U = 'VERSION') Or
    (U = 'VERSIONINFO') Or
    (U = 'VIRTKEY');
End;

{ ----- Function GetStatementKind ----- }
Function GetStatementKind(Const Ident : TString) : TStatementKind;
Var
  U : TString;
Begin
  U := UpCaseStr(Ident);
  If U = 'STRINGTABLE' Then
    GetStatementKind := ST_STRINGTABLE
  Else If U = 'ACCELERATORS' Then
    GetStatementKind := ST_ACCELERATORS
  Else If U = 'MENU' Then
    GetStatementKind := ST_MENU
  Else If U = 'MENUEX' Then
    GetStatementKind := ST_MENUEX
  Else If U = 'DIALOG' Then
    GetStatementKind := ST_DIALOG
  Else If U = 'DIALOGEX' Then
    GetStatementKind := ST_DIALOGEX
  Else If U = 'VERSIONINFO' Then
    GetStatementKind := ST_VERSIONINFO
  Else If U = 'ICON' Then
    GetStatementKind := ST_ICON
  Else If U = 'CURSOR' Then
    GetStatementKind := ST_CURSOR
  Else If U = 'BITMAP' Then
    GetStatementKind := ST_BITMAP
  Else If U = 'FONT' Then
    GetStatementKind := ST_FONT
  Else If U = 'RCDATA' Then
    GetStatementKind := ST_RCDATA
  Else If U = 'MESSAGETABLE' Then
    GetStatementKind := ST_MESSAGETABLE
  Else If U = 'MANIFEST' Then
    GetStatementKind := ST_MANIFEST
  Else If U = 'HTML' Then
    GetStatementKind := ST_HTML
  Else If U = 'LANGUAGE' Then
    GetStatementKind := ST_LANGUAGE
  Else
    GetStatementKind := ST_USER_TYPE;
End;

{ ----- Procedure SkipToEndBlock ----- }
Procedure SkipToEndBlock;
Var
  Tok   : TToken;
  Depth : Integer;
Begin
  Depth := 1;
  While (Depth > 0) And (Not ParseError) Do
  Begin
    Tok := NextToken;
    If Tok.Kind = TK_EOF Then
    Begin
      SyntaxError('Fin de fichier inattendue dans un bloc');
      Exit;
    End
    Else If Tok.Kind = TK_BEGIN Then
      Inc(Depth)
    Else If Tok.Kind = TK_END Then
      Dec(Depth);
  End;
End;

{ ----- Procedure ParsePreprocessor ----- }
Procedure ParsePreprocessor(Const Directive : TString);
Var
  D   : TString;
  Tok : TToken;
Begin
  D := UpCaseStr(Directive);

  If D = '#INCLUDE' Then
  Begin
    { Lire le nom de fichier }
    Tok := NextToken;
    If (Tok.Kind = TK_STRING) Or (Tok.Kind = TK_IDENT) Then
    Begin
      { TODO: implementer l inclusion de fichiers }
    End;
  End
  Else If D = '#DEFINE' Then
  Begin
    { Lire l identifiant et eventuellement la valeur }
    Tok := NextToken;
    If Tok.Kind = TK_IDENT Then
    Begin
      { TODO: implementer les defines }
    End;
  End
  Else If D = '#UNDEF' Then
  Begin
    Tok := NextToken;
    { TODO: implementer undef }
  End
  Else If D = '#IFDEF' Then
  Begin
    Tok := NextToken;
    { TODO: implementer ifdef }
  End
  Else If D = '#IFNDEF' Then
  Begin
    Tok := NextToken;
    { TODO: implementer ifndef }
  End
  Else If D = '#ELSE' Then
  Begin
    { TODO: implementer else }
  End
  Else If D = '#ENDIF' Then
  Begin
    { TODO: implementer endif }
  End
  Else If D = '#PRAGMA' Then
  Begin
    { Ignorer le reste de la ligne }
    Tok := NextToken;
  End;
End;

{ ----- Procedure ParseStatement ----- }
Procedure ParseStatement;
Var
  Tok      : TToken;
  ResId    : TResourceId;
  StmtKind : TStatementKind;
  IdUp     : TString;
Begin
  Tok := PeekTokenFn;

  { Fin de fichier }
  If Tok.Kind = TK_EOF Then
    Exit;

  { Nouvelle ligne - ignorer }
  If Tok.Kind = TK_NEWLINE Then
  Begin
    Tok := NextToken;
    Exit;
  End;

  { Directive preprocesseur }
  If Tok.Kind = TK_PREPROCESSOR Then
  Begin
    Tok := NextToken;
    ParsePreprocessor(Tok.Value);
    Exit;
  End;

  { Identifiant - peut etre un ID de ressource ou un mot-cle }
  If (Tok.Kind = TK_IDENT) Or (Tok.Kind = TK_NUMBER) Then
  Begin
    IdUp := UpCaseStr(Tok.Value);

    { Verifier si c est LANGUAGE en premier }
    If IdUp = 'LANGUAGE' Then
    Begin
      Tok := NextToken; { Consommer LANGUAGE }
      { Lire les parametres de language }
      Tok := PeekTokenFn;
      If Tok.Kind = TK_NUMBER Then
        Tok := NextToken;
      Tok := PeekTokenFn;
      If Tok.Kind = TK_COMMA Then
      Begin
        Tok := NextToken;
        Tok := PeekTokenFn;
        If Tok.Kind = TK_NUMBER Then
          Tok := NextToken;
      End;
      Exit;
    End;

    { Verifier si c est STRINGTABLE sans ID }
    If IdUp = 'STRINGTABLE' Then
    Begin
      Tok := NextToken; { Consommer STRINGTABLE }
      { Attendre BEGIN ou { }
      Tok := PeekTokenFn;
      While (Tok.Kind <> TK_BEGIN) And (Tok.Kind <> TK_LBRACE) And (Tok.Kind <> TK_EOF) Do
      Begin
        Tok := NextToken;
        Tok := PeekTokenFn;
      End;
      If (Tok.Kind = TK_BEGIN) Or (Tok.Kind = TK_LBRACE) Then
      Begin
        Tok := NextToken;
        SkipToEndBlock;
      End;
      Exit;
    End;

    { Sinon, c est un ID de ressource suivi d un type }
    ResId := ParseResourceId;

    { Lire le type de ressource }
    Tok := PeekTokenFn;
    If Tok.Kind = TK_IDENT Then
    Begin
      Tok := NextToken;
      StmtKind := GetStatementKind(Tok.Value);

      { Pour les ressources simples (ICON, CURSOR, BITMAP, etc.), }
      { lire le nom de fichier }
      If (StmtKind = ST_ICON) Or (StmtKind = ST_CURSOR) Or
         (StmtKind = ST_BITMAP) Or (StmtKind = ST_FONT) Or
         (StmtKind = ST_MANIFEST) Or (StmtKind = ST_HTML) Then
      Begin
        { Options memoire optionnelles }
        Tok := PeekTokenFn;
        While (Tok.Kind = TK_IDENT) And
              ((UpCaseStr(Tok.Value) = 'DISCARDABLE') Or
               (UpCaseStr(Tok.Value) = 'PRELOAD') Or
               (UpCaseStr(Tok.Value) = 'LOADONCALL') Or
               (UpCaseStr(Tok.Value) = 'MOVEABLE') Or
               (UpCaseStr(Tok.Value) = 'FIXED') Or
               (UpCaseStr(Tok.Value) = 'PURE') Or
               (UpCaseStr(Tok.Value) = 'IMPURE')) Do
        Begin
          Tok := NextToken;
          Tok := PeekTokenFn;
        End;
        { Lire le nom du fichier }
        If Tok.Kind = TK_STRING Then
          Tok := NextToken;
      End
      { Pour DIALOG, DIALOGEX, MENU, MENUEX, ACCELERATORS, RCDATA, VERSIONINFO }
      { lire jusqu au END du bloc }
      Else If (StmtKind = ST_DIALOG) Or (StmtKind = ST_DIALOGEX) Or
              (StmtKind = ST_MENU) Or (StmtKind = ST_MENUEX) Or
              (StmtKind = ST_ACCELERATORS) Or (StmtKind = ST_RCDATA) Or
              (StmtKind = ST_VERSIONINFO) Or (StmtKind = ST_MESSAGETABLE) Then
      Begin
        (* Sauter jusqu a BEGIN puis jusqu a END *)
        Tok := PeekTokenFn;
        While (Tok.Kind <> TK_BEGIN) And (Tok.Kind <> TK_LBRACE) And (Tok.Kind <> TK_EOF) Do
        Begin
          Tok := NextToken;
          Tok := PeekTokenFn;
        End;
        If (Tok.Kind = TK_BEGIN) Or (Tok.Kind = TK_LBRACE) Then
        Begin
          Tok := NextToken;
          SkipToEndBlock;
        End;
      End
      { Type utilisateur ou inconnu }
      Else
      Begin
        { Sauter jusqu a la fin de la ligne ou BEGIN }
        Tok := PeekTokenFn;
        While (Tok.Kind <> TK_NEWLINE) And (Tok.Kind <> TK_BEGIN) And
              (Tok.Kind <> TK_LBRACE) And (Tok.Kind <> TK_EOF) Do
        Begin
          Tok := NextToken;
          Tok := PeekTokenFn;
        End;
        If (Tok.Kind = TK_BEGIN) Or (Tok.Kind = TK_LBRACE) Then
        Begin
          Tok := NextToken;
          SkipToEndBlock;
        End;
      End;
    End;
  End
  Else
  Begin
    { Token inattendu - le sauter }
    Tok := NextToken;
  End;
End;

{ ----- Procedure ParseFile ----- }
Procedure ParseFile;
Var
  Tok : TToken;
Begin
  ParseError := False;
  ParseErrorMsg := '';

  Tok := PeekTokenFn;
  While (Tok.Kind <> TK_EOF) And (Not ParseError) Do
  Begin
    ParseStatement;
    Tok := PeekTokenFn;
  End;
End;

{ ============================================================
  TODO 05 : ECRITURE BINAIRE DU FICHIER .RES
  ============================================================ }

Var
  ResFile     : File Of Byte;   { Fichier binaire de sortie }
  ResFileName : TString;        { Nom du fichier .RES }
  ResFileSize : LongInt;        { Taille totale du fichier }
  ResFilePos  : LongInt;        { Position courante dans le fichier }

{ ----- Procedure CreateResFile ----- }
Procedure CreateResFile(Const FName : TString);
Begin
  ResFileName := FName;
  ResFilePos := 0;
  ResFileSize := 0;

  {$I-}
  Assign(ResFile, FName);
  Rewrite(ResFile);
  {$I+}

  If IOResult <> 0 Then
    FatalError('Impossible de creer le fichier : ' + FName);
End;

{ ----- Procedure CloseResFile ----- }
Procedure CloseResFile;
Begin
  {$I-}
  Close(ResFile);
  {$I+}
  If IOResult <> 0 Then
    { Ignorer les erreurs de fermeture }
    ;
  ResFileSize := ResFilePos;
End;

{ ----- Procedure WriteByte ----- }
Procedure WriteByte(B : Byte);
Begin
  {$I-}
  Write(ResFile, B);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Erreur d''ecriture dans le fichier .RES');
  Inc(ResFilePos);
End;

{ ----- Procedure WriteWord ----- }
Procedure WriteWord(W : Word);
Begin
  { Little-endian : octet de poids faible en premier }
  WriteByte(Lo(W));
  WriteByte(Hi(W));
End;

{ ----- Procedure WriteDWord ----- }
Procedure WriteDWord(D : LongInt);
Begin
  { Little-endian : 4 octets du moins significatif au plus significatif }
  WriteByte(Byte(D And $FF));
  WriteByte(Byte((D Shr 8) And $FF));
  WriteByte(Byte((D Shr 16) And $FF));
  WriteByte(Byte((D Shr 24) And $FF));
End;

{ ----- Procedure WriteWChar ----- }
Procedure WriteWChar(W : Word);
Begin
  { WCHAR = 2 octets little-endian }
  WriteWord(W);
End;

{ ----- Procedure WriteBytes ----- }
Procedure WriteBytes(Const Buf : Array Of Byte; Count : LongInt);
Var
  I : LongInt;
Begin
  For I := 0 To Count - 1 Do
    WriteByte(Buf[I]);
End;

{ ----- Procedure WriteString ----- }
Procedure WriteString(Const S : TString);
Var
  I   : Integer;
  Len : Byte;
Begin
  { Chaine Pascal : 1 octet longueur + caracteres }
  Len := Length(S);
  WriteByte(Len);
  For I := 1 To Len Do
    WriteByte(Ord(S[I]));
End;

{ ----- Procedure WriteUnicodeString ----- }
Procedure WriteUnicodeString(Const S : TString);
Var
  I : Integer;
Begin
  { Chaine Unicode UTF-16LE terminee par $0000 }
  For I := 1 To Length(S) Do
    WriteWChar(CharToWChar(S[I]));
  { Terminateur nul Unicode }
  WriteWChar($0000);
End;

{ ----- Procedure PadToAlignment ----- }
Procedure PadToAlignment(Align : Byte);
Begin
  { Ecrire des octets $00 jusqu a alignement }
  While (ResFilePos Mod Align) <> 0 Do
    WriteByte($00);
End;

{ ----- Function GetResPos ----- }
Function GetResPos : LongInt;
Begin
  GetResPos := ResFilePos;
End;

{ ----- Procedure SeekResPos ----- }
Procedure SeekResPos(Pos : LongInt);
Begin
  {$I-}
  Seek(ResFile, Pos);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Erreur de positionnement dans le fichier .RES');
  ResFilePos := Pos;
End;

{ ============================================================
  TODO 06 : GENERATION EN-TETE RES 16/32 BITS
  ============================================================ }

{ ----- Procedure WriteNullHeader32 ----- }
{ Ecrit la ressource nulle de 32 octets au debut du fichier .RES 32 bits }
Procedure WriteNullHeader32;
Begin
  { DataSize = 0 }
  WriteDWord(0);
  { HeaderSize = 32 }
  WriteDWord(32);
  { Type = $FFFF + 0 (ressource nulle) }
  WriteWord($FFFF);
  WriteWord(0);
  { Name = $FFFF + 0 }
  WriteWord($FFFF);
  WriteWord(0);
  { DataVersion = 0 }
  WriteDWord(0);
  { MemFlags = 0 }
  WriteWord(0);
  { LangId = 0 }
  WriteWord(0);
  { Version = 0 }
  WriteDWord(0);
  { Characteristics = 0 }
  WriteDWord(0);
End;

{ ----- Procedure WriteResHeader16 ----- }
{ Ecrit l'en-tete 16 bits avec IDs numeriques }
Procedure WriteResHeader16(TypeId, NameId : Word; DataSize, Attribs : Word);
Begin
  { TypeId avec bit $8000 indiquant ID numerique }
  WriteWord(TypeId Or $8000);
  { NameId avec bit $8000 indiquant ID numerique }
  WriteWord(NameId Or $8000);
  { DataSize en DWORD }
  WriteDWord(DataSize);
  { Attributs }
  WriteWord(Attribs);
  { Reserved = 0 }
  WriteWord(0);
End;

{ ----- Procedure WriteResHeader16Str ----- }
{ Variante avec noms en chaines Pascal }
Procedure WriteResHeader16Str(Const TypeName, ResName : TString;
                               DataSize, Attribs : Word);
Var
  I : Integer;
Begin
  { TypeName - chaine sans bit $8000, terminee par null }
  For I := 1 To Length(TypeName) Do
    WriteByte(Ord(TypeName[I]));
  WriteByte(0);
  
  { ResName - chaine terminee par null }
  For I := 1 To Length(ResName) Do
    WriteByte(Ord(ResName[I]));
  WriteByte(0);
  
  { DataSize en DWORD }
  WriteDWord(DataSize);
  { Attributs }
  WriteWord(Attribs);
  { Reserved = 0 }
  WriteWord(0);
End;

{ ----- Function CalculateHeaderSize32 ----- }
{ Calcule la taille de l'en-tete 32 bits variable }
Function CalculateHeaderSize32(TypeIsId : Boolean; Const TypeName : TString;
                                NameIsId : Boolean; Const ResName : TString) : LongInt;
Var
  Size : LongInt;
Begin
  { Taille de base : DataSize(4) + HeaderSize(4) = 8 }
  Size := 8;
  
  { Type : FFFF+ID (4 octets) ou Unicode (2 octets par char + 2 null) }
  If TypeIsId Then
    Size := Size + 4
  Else
    Size := Size + (Length(TypeName) + 1) * 2;
  
  { Name : FFFF+ID (4 octets) ou Unicode (2 octets par char + 2 null) }
  If NameIsId Then
    Size := Size + 4
  Else
    Size := Size + (Length(ResName) + 1) * 2;
  
  { Alignement sur DWORD (4 octets) }
  If (Size Mod 4) <> 0 Then
    Size := Size + (4 - (Size Mod 4));
  
  { Reste de l'en-tete : DataVersion(4) + MemFlags(2) + LangId(2) + }
  { Version(4) + Characteristics(4) = 16 }
  Size := Size + 16;
  
  CalculateHeaderSize32 := Size;
End;

{ ----- Procedure WriteResHeader32 ----- }
{ Ecrit l'en-tete 32 bits complet }
Procedure WriteResHeader32(TypeIsId : Boolean; TypeId : Word;
                            Const TypeName : TString;
                            NameIsId : Boolean; NameId : Word;
                            Const ResName : TString;
                            DataSize : LongInt; MemFlags : Word;
                            LangId : Word);
Var
  HeaderSize : LongInt;
  I : Integer;
Begin
  { Calculer la taille de l'en-tete }
  HeaderSize := CalculateHeaderSize32(TypeIsId, TypeName, NameIsId, ResName);
  
  { DataSize }
  WriteDWord(DataSize);
  
  { HeaderSize }
  WriteDWord(HeaderSize);
  
  { Type : FFFF+ID ou chaine Unicode }
  If TypeIsId Then
  Begin
    WriteWord($FFFF);
    WriteWord(TypeId);
  End
  Else
  Begin
    For I := 1 To Length(TypeName) Do
      WriteWChar(CharToWChar(TypeName[I]));
    WriteWChar(0);
  End;
  
  { Name : FFFF+ID ou chaine Unicode }
  If NameIsId Then
  Begin
    WriteWord($FFFF);
    WriteWord(NameId);
  End
  Else
  Begin
    For I := 1 To Length(ResName) Do
      WriteWChar(CharToWChar(ResName[I]));
    WriteWChar(0);
  End;
  
  { Alignement sur DWORD }
  PadToAlignment(4);
  
  { DataVersion = 0 }
  WriteDWord(0);
  
  { MemFlags }
  WriteWord(MemFlags);
  
  { LangId }
  WriteWord(LangId);
  
  { Version = 0 }
  WriteDWord(0);
  
  { Characteristics = 0 }
  WriteDWord(0);
End;

{ ----- Procedure WriteEndMarker16 ----- }
{ Ecrit le marqueur de fin 16 bits }
Procedure WriteEndMarker16;
Begin
  WriteWord($0000);
End;

{ ============================================================
  TODO 07 : TABLE DES TYPES DE RESSOURCES [RT_*]
  (Constantes RT_* definies avec TODO 01)
  ============================================================ }

{ ----- Function ResourceTypeFromKeyword ----- }
{ Retourne le type numerique correspondant au mot-cle RC }
Function ResourceTypeFromKeyword(Const Kw : TString) : Word;
Var
  KwUp : TString;
Begin
  KwUp := UpCaseStr(Kw);
  
  If KwUp = 'CURSOR' Then
    ResourceTypeFromKeyword := RT_CURSOR
  Else If KwUp = 'BITMAP' Then
    ResourceTypeFromKeyword := RT_BITMAP
  Else If KwUp = 'ICON' Then
    ResourceTypeFromKeyword := RT_ICON
  Else If KwUp = 'MENU' Then
    ResourceTypeFromKeyword := RT_MENU
  Else If (KwUp = 'DIALOG') Or (KwUp = 'DIALOGEX') Then
    ResourceTypeFromKeyword := RT_DIALOG
  Else If KwUp = 'STRINGTABLE' Then
    ResourceTypeFromKeyword := RT_STRING
  Else If KwUp = 'FONTDIR' Then
    ResourceTypeFromKeyword := RT_FONTDIR
  Else If KwUp = 'FONT' Then
    ResourceTypeFromKeyword := RT_FONT
  Else If (KwUp = 'ACCELERATORS') Or (KwUp = 'ACCELERATOR') Then
    ResourceTypeFromKeyword := RT_ACCELERATOR
  Else If KwUp = 'RCDATA' Then
    ResourceTypeFromKeyword := RT_RCDATA
  Else If KwUp = 'MESSAGETABLE' Then
    ResourceTypeFromKeyword := RT_MESSAGETABLE
  Else If (KwUp = 'VERSIONINFO') Or (KwUp = 'VERSION') Then
    ResourceTypeFromKeyword := RT_VERSION
  Else If KwUp = 'DLGINCLUDE' Then
    ResourceTypeFromKeyword := RT_DLGINCLUDE
  Else If KwUp = 'PLUGPLAY' Then
    ResourceTypeFromKeyword := RT_PLUGPLAY
  Else If KwUp = 'VXD' Then
    ResourceTypeFromKeyword := RT_VXD
  Else If KwUp = 'ANICURSOR' Then
    ResourceTypeFromKeyword := RT_ANICURSOR
  Else If KwUp = 'ANIICON' Then
    ResourceTypeFromKeyword := RT_ANIICON
  Else If KwUp = 'HTML' Then
    ResourceTypeFromKeyword := RT_HTML
  Else If KwUp = 'MANIFEST' Then
    ResourceTypeFromKeyword := RT_MANIFEST
  Else If KwUp = 'TOOLBAR' Then
    ResourceTypeFromKeyword := RT_TOOLBAR
  Else
    ResourceTypeFromKeyword := 0; { Type utilisateur ou inconnu }
End;

{ ----- Function ResourceTypeName ----- }
{ Retourne le nom symbolique RT_xxx correspondant au type }
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
    ResourceTypeName := 'RT_USER(' + IntToStr(TypeId) + ')';
  End;
End;

{ ============================================================
  TODO 08 : TRAITEMENT DE LANGUAGE ID
  ============================================================ }

{ ----- Function MakeLangId ----- }
{ Combine PRIMARYLANGID et SUBLANGID en un LANGID complet }
{ Formule : (Sub shl 10) or Primary }
Function MakeLangId(Primary, Sub : Word) : Word;
Begin
  MakeLangId := (Sub Shl 10) Or Primary;
End;

{ ----- Function PrimaryLangIdFromName ----- }
{ Retourne le PRIMARYLANGID depuis le nom de la langue }
Function PrimaryLangIdFromName(Const Name : TString) : Word;
Var
  N : TString;
Begin
  N := UpCaseStr(Name);
  
  { Langues principales - PRIMARYLANGID }
  If (N = 'NEUTRAL') Or (N = 'LANG_NEUTRAL') Then
    PrimaryLangIdFromName := $00
  Else If (N = 'ARABIC') Or (N = 'LANG_ARABIC') Then
    PrimaryLangIdFromName := $01
  Else If (N = 'BULGARIAN') Or (N = 'LANG_BULGARIAN') Then
    PrimaryLangIdFromName := $02
  Else If (N = 'CATALAN') Or (N = 'LANG_CATALAN') Then
    PrimaryLangIdFromName := $03
  Else If (N = 'CHINESE') Or (N = 'LANG_CHINESE') Then
    PrimaryLangIdFromName := $04
  Else If (N = 'CZECH') Or (N = 'LANG_CZECH') Then
    PrimaryLangIdFromName := $05
  Else If (N = 'DANISH') Or (N = 'LANG_DANISH') Then
    PrimaryLangIdFromName := $06
  Else If (N = 'GERMAN') Or (N = 'LANG_GERMAN') Then
    PrimaryLangIdFromName := $07
  Else If (N = 'GREEK') Or (N = 'LANG_GREEK') Then
    PrimaryLangIdFromName := $08
  Else If (N = 'ENGLISH') Or (N = 'LANG_ENGLISH') Then
    PrimaryLangIdFromName := $09
  Else If (N = 'SPANISH') Or (N = 'LANG_SPANISH') Then
    PrimaryLangIdFromName := $0A
  Else If (N = 'FINNISH') Or (N = 'LANG_FINNISH') Then
    PrimaryLangIdFromName := $0B
  Else If (N = 'FRENCH') Or (N = 'LANG_FRENCH') Then
    PrimaryLangIdFromName := $0C
  Else If (N = 'HEBREW') Or (N = 'LANG_HEBREW') Then
    PrimaryLangIdFromName := $0D
  Else If (N = 'HUNGARIAN') Or (N = 'LANG_HUNGARIAN') Then
    PrimaryLangIdFromName := $0E
  Else If (N = 'ICELANDIC') Or (N = 'LANG_ICELANDIC') Then
    PrimaryLangIdFromName := $0F
  Else If (N = 'ITALIAN') Or (N = 'LANG_ITALIAN') Then
    PrimaryLangIdFromName := $10
  Else If (N = 'JAPANESE') Or (N = 'LANG_JAPANESE') Then
    PrimaryLangIdFromName := $11
  Else If (N = 'KOREAN') Or (N = 'LANG_KOREAN') Then
    PrimaryLangIdFromName := $12
  Else If (N = 'DUTCH') Or (N = 'LANG_DUTCH') Then
    PrimaryLangIdFromName := $13
  Else If (N = 'NORWEGIAN') Or (N = 'LANG_NORWEGIAN') Then
    PrimaryLangIdFromName := $14
  Else If (N = 'POLISH') Or (N = 'LANG_POLISH') Then
    PrimaryLangIdFromName := $15
  Else If (N = 'PORTUGUESE') Or (N = 'LANG_PORTUGUESE') Then
    PrimaryLangIdFromName := $16
  Else If (N = 'ROMANIAN') Or (N = 'LANG_ROMANIAN') Then
    PrimaryLangIdFromName := $18
  Else If (N = 'RUSSIAN') Or (N = 'LANG_RUSSIAN') Then
    PrimaryLangIdFromName := $19
  Else If (N = 'SERBIAN') Or (N = 'LANG_SERBIAN') Then
    PrimaryLangIdFromName := $1A
  Else If (N = 'SLOVAK') Or (N = 'LANG_SLOVAK') Then
    PrimaryLangIdFromName := $1B
  Else If (N = 'SLOVENIAN') Or (N = 'LANG_SLOVENIAN') Then
    PrimaryLangIdFromName := $24
  Else If (N = 'SWEDISH') Or (N = 'LANG_SWEDISH') Then
    PrimaryLangIdFromName := $1D
  Else If (N = 'THAI') Or (N = 'LANG_THAI') Then
    PrimaryLangIdFromName := $1E
  Else If (N = 'TURKISH') Or (N = 'LANG_TURKISH') Then
    PrimaryLangIdFromName := $1F
  Else If (N = 'UKRAINIAN') Or (N = 'LANG_UKRAINIAN') Then
    PrimaryLangIdFromName := $22
  Else If (N = 'VIETNAMESE') Or (N = 'LANG_VIETNAMESE') Then
    PrimaryLangIdFromName := $2A
  Else
    PrimaryLangIdFromName := $00; { LANG_NEUTRAL par defaut }
End;

{ ----- Function SubLangIdFromName ----- }
{ Retourne le SUBLANGID depuis le nom de la sous-langue }
Function SubLangIdFromName(Const Name : TString) : Word;
Var
  N : TString;
Begin
  N := UpCaseStr(Name);
  
  { Sous-langues - SUBLANGID }
  If (N = 'NEUTRAL') Or (N = 'SUBLANG_NEUTRAL') Then
    SubLangIdFromName := $00
  Else If (N = 'DEFAULT') Or (N = 'SUBLANG_DEFAULT') Then
    SubLangIdFromName := $01
  Else If (N = 'SYS_DEFAULT') Or (N = 'SUBLANG_SYS_DEFAULT') Then
    SubLangIdFromName := $02
  Else If (N = 'CUSTOM_DEFAULT') Or (N = 'SUBLANG_CUSTOM_DEFAULT') Then
    SubLangIdFromName := $03
  { Anglais }
  Else If (N = 'ENGLISH_US') Or (N = 'SUBLANG_ENGLISH_US') Then
    SubLangIdFromName := $01
  Else If (N = 'ENGLISH_UK') Or (N = 'SUBLANG_ENGLISH_UK') Then
    SubLangIdFromName := $02
  Else If (N = 'ENGLISH_AUS') Or (N = 'SUBLANG_ENGLISH_AUS') Then
    SubLangIdFromName := $03
  Else If (N = 'ENGLISH_CAN') Or (N = 'SUBLANG_ENGLISH_CAN') Then
    SubLangIdFromName := $04
  { Francais }
  Else If (N = 'FRENCH') Or (N = 'SUBLANG_FRENCH') Then
    SubLangIdFromName := $01
  Else If (N = 'FRENCH_BELGIAN') Or (N = 'SUBLANG_FRENCH_BELGIAN') Then
    SubLangIdFromName := $02
  Else If (N = 'FRENCH_CANADIAN') Or (N = 'SUBLANG_FRENCH_CANADIAN') Then
    SubLangIdFromName := $03
  Else If (N = 'FRENCH_SWISS') Or (N = 'SUBLANG_FRENCH_SWISS') Then
    SubLangIdFromName := $04
  { Allemand }
  Else If (N = 'GERMAN') Or (N = 'SUBLANG_GERMAN') Then
    SubLangIdFromName := $01
  Else If (N = 'GERMAN_SWISS') Or (N = 'SUBLANG_GERMAN_SWISS') Then
    SubLangIdFromName := $02
  Else If (N = 'GERMAN_AUSTRIAN') Or (N = 'SUBLANG_GERMAN_AUSTRIAN') Then
    SubLangIdFromName := $03
  { Espagnol }
  Else If (N = 'SPANISH') Or (N = 'SUBLANG_SPANISH') Then
    SubLangIdFromName := $01
  Else If (N = 'SPANISH_MEXICAN') Or (N = 'SUBLANG_SPANISH_MEXICAN') Then
    SubLangIdFromName := $02
  Else If (N = 'SPANISH_MODERN') Or (N = 'SUBLANG_SPANISH_MODERN') Then
    SubLangIdFromName := $03
  { Italien }
  Else If (N = 'ITALIAN') Or (N = 'SUBLANG_ITALIAN') Then
    SubLangIdFromName := $01
  Else If (N = 'ITALIAN_SWISS') Or (N = 'SUBLANG_ITALIAN_SWISS') Then
    SubLangIdFromName := $02
  { Portugais }
  Else If (N = 'PORTUGUESE') Or (N = 'SUBLANG_PORTUGUESE') Then
    SubLangIdFromName := $02
  Else If (N = 'PORTUGUESE_BRAZILIAN') Or (N = 'SUBLANG_PORTUGUESE_BRAZILIAN') Then
    SubLangIdFromName := $01
  { Chinois }
  Else If (N = 'CHINESE_TRADITIONAL') Or (N = 'SUBLANG_CHINESE_TRADITIONAL') Then
    SubLangIdFromName := $01
  Else If (N = 'CHINESE_SIMPLIFIED') Or (N = 'SUBLANG_CHINESE_SIMPLIFIED') Then
    SubLangIdFromName := $02
  { Neerlandais }
  Else If (N = 'DUTCH') Or (N = 'SUBLANG_DUTCH') Then
    SubLangIdFromName := $01
  Else If (N = 'DUTCH_BELGIAN') Or (N = 'SUBLANG_DUTCH_BELGIAN') Then
    SubLangIdFromName := $02
  { Autres }
  Else If (N = 'KOREAN') Or (N = 'SUBLANG_KOREAN') Then
    SubLangIdFromName := $01
  Else If (N = 'SERBIAN_LATIN') Or (N = 'SUBLANG_SERBIAN_LATIN') Then
    SubLangIdFromName := $02
  Else If (N = 'SERBIAN_CYRILLIC') Or (N = 'SUBLANG_SERBIAN_CYRILLIC') Then
    SubLangIdFromName := $03
  Else
    SubLangIdFromName := $00; { SUBLANG_NEUTRAL par defaut }
End;

{ ----- Procedure ParseLanguageDirective ----- }
{ Parse la directive LANGUAGE LANG_xxx, SUBLANG_xxx }
{ et met a jour CurrentLangId }
Procedure ParseLanguageDirective;
Var
  PrimaryId : Word;
  SubId     : Word;
  LangName  : TString;
  SubName   : TString;
Begin
  { On suppose que le token LANGUAGE a deja ete lu }
  { Lire le token de langue primaire }
  NextToken;
  
  If CurrToken.Kind <> TK_IDENT Then
    SyntaxError('Identifiant de langue attendu')
  Else
  Begin
    LangName := CurrToken.Value;
    PrimaryId := PrimaryLangIdFromName(LangName);
    
    { Lire la virgule }
    NextToken;
    If CurrToken.Kind = TK_COMMA Then
    Begin
      { Lire le sous-identifiant de langue }
      NextToken;
      
      If CurrToken.Kind <> TK_IDENT Then
        SyntaxError('Identifiant de sous-langue attendu')
      Else
      Begin
        SubName := CurrToken.Value;
        SubId := SubLangIdFromName(SubName);
        
        { Combiner les IDs pour former le LANGID complet }
        CurrentLangId := MakeLangId(PrimaryId, SubId);
      End;
    End
    Else
    Begin
      { Pas de sous-langue specifiee, utiliser SUBLANG_NEUTRAL }
      SubId := $00;
      CurrentLangId := MakeLangId(PrimaryId, SubId);
    End;
  End;
End;

{ ============================================================
  TODO 09 : TRAITEMENT DES FLAGS MEMOIRE
  ============================================================ }

{ ----- Function MemFlagFromName ----- }
{ Retourne le flag memoire correspondant au mot-cle }
Function MemFlagFromName(Const Name : TString) : Word;
Var
  N : TString;
Begin
  N := UpCaseStr(Name);
  
  If N = 'MOVEABLE' Then
    MemFlagFromName := MF_MOVEABLE       { $0010 }
  Else If N = 'MOVABLE' Then
    MemFlagFromName := MF_MOVEABLE       { Orthographe alternative }
  Else If N = 'PURE' Then
    MemFlagFromName := MF_PURE           { $0020 }
  Else If N = 'PRELOAD' Then
    MemFlagFromName := MF_PRELOAD        { $0040 }
  Else If N = 'DISCARDABLE' Then
    MemFlagFromName := MF_DISCARDABLE    { $1000 }
  Else If N = 'FIXED' Then
    MemFlagFromName := MF_FIXED          { $0000 }
  Else If N = 'LOADONCALL' Then
    MemFlagFromName := MF_FIXED          { $0000 - meme que FIXED }
  Else If N = 'SHARED' Then
    MemFlagFromName := MF_MOVEABLE Or MF_PURE  { $0030 }
  Else If N = 'IMPURE' Then
    MemFlagFromName := MF_FIXED          { Oppose de PURE }
  Else If N = 'NONSHARED' Then
    MemFlagFromName := MF_FIXED          { Oppose de SHARED }
  Else
    MemFlagFromName := 0;                { Flag inconnu }
End;

{ ----- Function IsMemoryOption ----- }
{ Verifie si le token courant est une option memoire }
Function IsMemoryOption(Const Name : TString) : Boolean;
Var
  N : TString;
Begin
  N := UpCaseStr(Name);
  IsMemoryOption := (N = 'MOVEABLE') Or (N = 'MOVABLE') Or
                    (N = 'PURE') Or (N = 'PRELOAD') Or
                    (N = 'DISCARDABLE') Or (N = 'FIXED') Or
                    (N = 'LOADONCALL') Or (N = 'SHARED') Or
                    (N = 'IMPURE') Or (N = 'NONSHARED');
End;

{ ----- Function ParseMemoryOptions ----- }
{ Lit les options de memoire optionnelles apres une declaration }
{ de ressource. Retourne la combinaison des flags ou DefaultMemFlags }
{ si aucune option n'est specifiee. }
Function ParseMemoryOptions : Word;
Var
  Flags    : Word;
  HasFlags : Boolean;
  FlagVal  : Word;
Begin
  Flags := 0;
  HasFlags := False;
  
  { Lire les options de memoire tant qu'il y en a }
  While (CurrToken.Kind = TK_IDENT) And IsMemoryOption(CurrToken.Value) Do
  Begin
    FlagVal := MemFlagFromName(CurrToken.Value);
    
    { FIXED et MOVEABLE sont exclusifs mutuellement }
    If (FlagVal = MF_MOVEABLE) Then
      Flags := (Flags And (Not MF_FIXED)) Or MF_MOVEABLE
    Else If (CurrToken.Value = 'FIXED') Or (CurrToken.Value = 'fixed') Then
      Flags := (Flags And (Not MF_MOVEABLE)) Or MF_FIXED
    Else
      Flags := Flags Or FlagVal;
    
    HasFlags := True;
    NextToken;
  End;
  
  { Si aucune option specifiee, utiliser les flags par defaut }
  If Not HasFlags Then
    ParseMemoryOptions := DefaultMemFlags
  Else
    ParseMemoryOptions := Flags;
End;

{ =============================================================
  TODO 10 - TABLE DES RESSOURCES (COLLECTE)
  ============================================================= }

{ ----- Function AddResource ----- }
{ Ajoute une nouvelle ressource a la table et retourne l index }
Function AddResource(ATypeIsId: Boolean; ATypeId: Word;
  Const ATypeName: TString; ANameIsId: Boolean; ANameId: Word;
  Const AResName: TString; AMemFlags: Word; ALangId: Word): Integer;
Begin
  If ResCount >= MAX_RESOURCES Then
  Begin
    FatalError('Nombre maximal de ressources atteint (' + IntToStr(MAX_RESOURCES) + ')');
    AddResource := 0;
    Exit;
  End;
  
  Inc(ResCount);
  
  With Resources[ResCount] Do
  Begin
    TypeIsId := ATypeIsId;
    TypeId   := ATypeId;
    TypeName := ATypeName;
    NameIsId := ANameIsId;
    NameId   := ANameId;
    NameStr  := AResName;
    DataSize := 0;      { Sera mis a jour plus tard }
    DataOfs  := 0;      { Sera mis a jour plus tard }
    MemFlags := AMemFlags;
    LangId   := ALangId;
  End;
  
  AddResource := ResCount;
End;

{ ----- Procedure SetResourceDataOfs ----- }
{ Met a jour l offset des donnees pour une ressource }
Procedure SetResourceDataOfs(Index: Integer; Ofs: LongInt);
Begin
  If (Index >= 1) And (Index <= ResCount) Then
    Resources[Index].DataOfs := Ofs
  Else
    FatalError('Index de ressource invalide: ' + IntToStr(Index));
End;

{ ----- Procedure SetResourceDataSize ----- }
{ Met a jour la taille des donnees pour une ressource }
Procedure SetResourceDataSize(Index: Integer; Size: LongInt);
Begin
  If (Index >= 1) And (Index <= ResCount) Then
    Resources[Index].DataSize := Size
  Else
    FatalError('Index de ressource invalide: ' + IntToStr(Index));
End;

{ ----- Procedure ParseCommandLine ----- }
Procedure ParseCommandLine(Var AOpts : TOptions);
Var
  I      : Integer;
  Arg    : TString;
  ArgUp  : TString;
Begin
  AOpts.SrcFile      := '';
  AOpts.OutFile      := '';
  AOpts.Output16     := False;
  AOpts.Output32     := True;  { Defaut : 32 bits }
  AOpts.Verbose      := False;
  AOpts.IncludeCount := 0;
  AOpts.DefineCount  := 0;

  If ParamCount = 0 Then
    ShowHelp;

  For I := 1 To ParamCount Do
  Begin
    Arg   := ParamStr(I);
    ArgUp := UpCaseStr(Arg);

    If (ArgUp = '-H') Or (ArgUp = '--HELP') Or (ArgUp = '/?') Then
      ShowHelp
    Else If ArgUp = '-V' Then
      AOpts.Verbose := True
    Else If ArgUp = '-16' Then
    Begin
      AOpts.Output16 := True;
      AOpts.Output32 := False;
    End
    Else If ArgUp = '-32' Then
    Begin
      AOpts.Output32 := True;
      AOpts.Output16 := False;
    End
    Else If Copy(ArgUp, 1, 2) = '-O' Then
    Begin
      If Length(Arg) > 2 Then
        AOpts.OutFile := Copy(Arg, 3, Length(Arg) - 2)
      Else If I < ParamCount Then
      Begin
        Inc(I);
        AOpts.OutFile := ParamStr(I);
      End;
    End
    Else If Copy(ArgUp, 1, 2) = '-I' Then
    Begin
      If AOpts.IncludeCount < MAX_INCLUDE_PATHS Then
      Begin
        Inc(AOpts.IncludeCount);
        AOpts.IncludePaths[AOpts.IncludeCount] := Copy(Arg, 3, Length(Arg) - 2);
      End;
    End
    Else If Copy(ArgUp, 1, 2) = '-D' Then
    Begin
      If AOpts.DefineCount < 64 Then
      Begin
        Inc(AOpts.DefineCount);
        AOpts.Defines[AOpts.DefineCount] := Copy(Arg, 3, Length(Arg) - 2);
      End;
    End
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') And (AOpts.SrcFile = '') Then
      AOpts.SrcFile := Arg;
  End;

  { Verifier que le fichier source est fourni }
  If AOpts.SrcFile = '' Then
    FatalError('Aucun fichier source specifie');

  { Verifier l extension }
  ArgUp := UpCaseStr(AOpts.SrcFile);
  If (Copy(ArgUp, Length(ArgUp) - 2, 3) <> '.RC') Then
    FatalError('Le fichier source doit avoir l''extension .RC');

  { Generer le nom de sortie par defaut }
  If AOpts.OutFile = '' Then
    AOpts.OutFile := ChangeFileExt(AOpts.SrcFile, '.RES');
End;

{ ----- Programme principal ----- }
Begin
  { Banniere de version }
  WriteLn('RC v', RC_VERSION, ' (', RC_DATE, ') - ',
          'Compilateur de ressources Windows');
  WriteLn;
  
  { Initialiser le compteur de ressources }
  ResCount := 0;

  { Analyser la ligne de commande }
  ParseCommandLine(Opts);

  { Afficher les parametres en mode verbeux }
  If Opts.Verbose Then
  Begin
    WriteLn('Fichier source : ', Opts.SrcFile);
    WriteLn('Fichier sortie : ', Opts.OutFile);
    If Opts.Output16 Then
      WriteLn('Format         : RES 16 bits')
    Else
      WriteLn('Format         : RES 32 bits');
  End;

  { TODO : Implementation des TODOs 11-25 }
  WriteLn;
  WriteLn('NOTE: TODOs 01-10 [IMPLEMENTE]. TODOs 11-25 sont [A FAIRE].');
  WriteLn('      Ce fichier contient la structure et les specifications');
  WriteLn('      pour un compilateur de ressources .RC vers .RES.');
End.
