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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [A FAIRE]
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

  TODO 02 - FONCTIONS UTILITAIRES [A FAIRE]
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

  TODO 03 - LEXER RC (TOKENISATION) [A FAIRE]
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

  TODO 04 - PARSER RC (ANALYSE SYNTAXIQUE) [A FAIRE]
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

  TODO 05 - ECRITURE BINAIRE DU FICHIER .RES [A FAIRE]
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

  TODO 06 - GENERATION EN-TETE RES 16/32 BITS [A FAIRE]
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

  TODO 07 - TABLE DES TYPES DE RESSOURCES [RT_*] [A FAIRE]
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

  TODO 08 - TRAITEMENT DE LANGUAGE ID [A FAIRE]
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

  TODO 09 - TRAITEMENT DES FLAGS MEMOIRE [A FAIRE]
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

  TODO 10 - TABLE DES RESSOURCES (COLLECTE) [A FAIRE]
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

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;

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
    Else If (Arg[1] <> '-') And (AOpts.SrcFile = '') Then
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

  { TODO : Implementation des TODOs 01-25 }
  WriteLn;
  WriteLn('NOTE: Les TODOs 01-25 sont [A FAIRE].');
  WriteLn('      Ce fichier contient la structure et les specifications');
  WriteLn('      pour un compilateur de ressources .RC vers .RES.');
End.
