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

  TODO 11 - COMPILATION STRINGTABLE [IMPLEMENTE]
            Type TStringEntry : record
              StringId : Word   (identifiant de la chaine)
              Text     : String (texte de la chaine)
              LangId   : Word   (langue)
            End
            Variables globales :
              StringEntries : Array[1..MAX_STRINGS] Of TStringEntry
              StringCount   : Integer
            Procedure AddStringEntry
              ajoute une entree dans la table des chaines
            Procedure ParseStringTable
              lire le bloc STRINGTABLE ... BEGIN ... END :
              pour chaque ligne : lire ID, virgule, chaine entre ""
              ajouter dans StringEntries avec CurrentLangId
            Function FindStringBlock
              trouve si un bloc de 16 chaines contient au moins une chaine
            Function GetStringFromBlock
              retourne la chaine pour un slot dans un bloc
            Function GetMaxStringBlockId
              retourne le numero de bloc maximal utilise
            Procedure WriteStringTable
              grouper les StringEntries par bloc de 16 IDs consecutifs
              (bloc N contient les IDs (N-1)*16 a (N-1)*16+15)
              pour chaque bloc present :
              - ecrire l en-tete de ressource RT_STRING avec ID = N
              - pour chaque slot 0..15 : ecrire WORD longueur (en WCHARs)
                puis les WCHARs (0 si slot vide)
              aligner les donnees sur 4 octets

  TODO 12 - COMPILATION ACCELERATORS [IMPLEMENTE]
            Type TAccelEntry : record
              fVirt  : Word   (drapeaux de l accelerateur)
              Key    : Word   (code de touche ou ASCII)
              Cmd    : Word   (identifiant de commande)
            End
            Constantes fVirt :
              FVIRTKEY = $01, FNOINVERT = $02, FSHIFT = $04,
              FCONTROL = $08, FALT = $10, FLAST = $80
            Constantes de touches virtuelles :
              VK_BACK = $08, VK_TAB = $09, VK_RETURN = $0D,
              VK_ESCAPE = $1B, VK_SPACE = $20, VK_END = $23,
              VK_HOME = $24, VK_LEFT = $25, VK_UP = $26,
              VK_RIGHT = $27, VK_DOWN = $28, VK_INSERT = $2D,
              VK_DELETE = $2E, VK_F1..$7B = VK_F12
            Variables globales :
              AccelEntries : Array[1..MAX_ACCEL] Of TAccelEntry
              AccelCount   : Integer
            Function VKeyFromName(Const Name: String): Word
              retourne le code de touche virtuelle depuis le nom
            Function IsAccelOption(Const S: String): Boolean
              verifie si le token est une option d accelerateur
            Procedure ParseAccelerators(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word)
              lire le bloc ACCELERATORS ... BEGIN ... END :
              pour chaque ligne : lire touche, virgule, commande,
              options (VIRTKEY, SHIFT, CONTROL, ALT, NOINVERT)
              compiler en TAccelEntry
            Procedure WriteAccelerators(NameIsId: Boolean; NameId: Word;
              Const NameStr: String; MemFlags: Word; LangId: Word)
              ecrire l en-tete de ressource RT_ACCELERATOR,
              puis pour chaque entree : WORD fVirt, WORD key, WORD cmd,
              WORD padding (bit $80 dans fVirt pour la derniere entree)

  TODO 13 - COMPILATION MENU [IMPLEMENTE]
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

  TODO 14 - COMPILATION DIALOG [IMPLEMENTE]
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

  TODO 15 - COMPILATION VERSIONINFO [IMPLEMENTE]
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

  TODO 16 - COMPILATION ICON/CURSOR [IMPLEMENTE]
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

  TODO 17 - COMPILATION BITMAP [IMPLEMENTE]
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

  TODO 18 - COMPILATION GROUP_ICON/GROUP_CURSOR [IMPLEMENTE]
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

  { TODO 12 : Constantes pour accelerateurs }
  { Drapeaux fVirt }
  FVIRTKEY   = $01;   { La touche est une touche virtuelle }
  FNOINVERT  = $02;   { Ne pas inverser l element de menu }
  FSHIFT     = $04;   { Touche SHIFT enfoncee }
  FCONTROL   = $08;   { Touche CONTROL enfoncee }
  FALT       = $10;   { Touche ALT enfoncee }
  FLAST      = $80;   { Dernier accelerateur dans la table }
  
  { Codes de touches virtuelles }
  VK_BACK    = $08;   { Backspace }
  VK_TAB     = $09;   { Tab }
  VK_CLEAR   = $0C;   { Clear }
  VK_RETURN  = $0D;   { Enter }
  VK_SHIFT   = $10;   { Shift }
  VK_CONTROL = $11;   { Ctrl }
  VK_MENU    = $12;   { Alt }
  VK_PAUSE   = $13;   { Pause }
  VK_CAPITAL = $14;   { Caps Lock }
  VK_ESCAPE  = $1B;   { Escape }
  VK_SPACE   = $20;   { Space }
  VK_PRIOR   = $21;   { Page Up }
  VK_NEXT    = $22;   { Page Down }
  VK_END     = $23;   { End }
  VK_HOME    = $24;   { Home }
  VK_LEFT    = $25;   { Left Arrow }
  VK_UP      = $26;   { Up Arrow }
  VK_RIGHT   = $27;   { Right Arrow }
  VK_DOWN    = $28;   { Down Arrow }
  VK_SELECT  = $29;   { Select }
  VK_PRINT   = $2A;   { Print }
  VK_EXECUTE = $2B;   { Execute }
  VK_SNAPSHOT= $2C;   { Print Screen }
  VK_INSERT  = $2D;   { Insert }
  VK_DELETE  = $2E;   { Delete }
  VK_HELP    = $2F;   { Help }
  VK_F1      = $70;   { F1 }
  VK_F2      = $71;   { F2 }
  VK_F3      = $72;   { F3 }
  VK_F4      = $73;   { F4 }
  VK_F5      = $74;   { F5 }
  VK_F6      = $75;   { F6 }
  VK_F7      = $76;   { F7 }
  VK_F8      = $77;   { F8 }
  VK_F9      = $78;   { F9 }
  VK_F10     = $79;   { F10 }
  VK_F11     = $7A;   { F11 }
  VK_F12     = $7B;   { F12 }
  VK_NUMLOCK = $90;   { Num Lock }
  VK_SCROLL  = $91;   { Scroll Lock }
  
  { TODO 13 : Constantes pour menus }
  { Drapeaux fItemFlags }
  MFT_STRING     = $0000;   { Element texte normal }
  MF_GRAYED      = $0001;   { Element grise }
  MF_DISABLED    = $0002;   { Element desactive }
  MF_BITMAP      = $0004;   { Element bitmap }
  MF_CHECKED     = $0008;   { Element coche }
  MF_POPUP       = $0010;   { Sous-menu popup }
  MF_MENUBARBREAK= $0020;   { Nouvelle colonne avec separateur }
  MF_MENUBREAK   = $0040;   { Nouvelle colonne }
  MF_END         = $0080;   { Dernier element au niveau courant }
  MF_OWNERDRAW   = $0100;   { Element dessine par le proprietaire }
  MF_SEPARATOR   = $0800;   { Separateur }
  MF_HELP        = $4000;   { Element d aide }
  
  { TODO 14 : Constantes pour dialogues }
  { Classes predefinies de controles }
  DC_BUTTON    = $0080;     { Boutons }
  DC_EDIT      = $0081;     { Zone de texte editable }
  DC_STATIC    = $0082;     { Texte statique }
  DC_LISTBOX   = $0083;     { Liste }
  DC_SCROLLBAR = $0084;     { Barre de defilement }
  DC_COMBOBOX  = $0085;     { Liste deroulante }
  
  { Styles de dialogue (DS_*) }
  DS_ABSALIGN      = $0001;  { Alignement absolu }
  DS_SYSMODAL      = $0002;  { Modal systeme }
  DS_3DLOOK        = $0004;  { Apparence 3D }
  DS_FIXEDSYS      = $0008;  { Police fixe }
  DS_NOFAILCREATE  = $0010;  { Ne pas echouer la creation }
  DS_LOCALEDIT     = $0020;  { Edition locale }
  DS_SETFONT       = $0040;  { Definir une police }
  DS_MODALFRAME    = $0080;  { Cadre modal }
  DS_NOIDLEMSG     = $0100;  { Pas de message idle }
  DS_SETFOREGROUND = $0200;  { Mettre au premier plan }
  DS_CONTROL       = $0400;  { Controle enfant }
  DS_CENTER        = $0800;  { Centrer sur l ecran }
  DS_CENTERMOUSE   = $1000;  { Centrer sur la souris }
  DS_CONTEXTHELP   = $2000;  { Aide contextuelle }
  DS_SHELLFONT     = $0048;  { Police shell (DS_SETFONT + DS_FIXEDSYS) }
  
  { Styles de fenetre (WS_*) pour dialogues }
  WS_POPUP         = LongInt($80000000);
  WS_CHILD         = $40000000;
  WS_MINIMIZE      = $20000000;
  WS_VISIBLE       = $10000000;
  WS_DISABLED      = $08000000;
  WS_CLIPSIBLINGS  = $04000000;
  WS_CLIPCHILDREN  = $02000000;
  WS_MAXIMIZE      = $01000000;
  WS_CAPTION       = $00C00000;
  WS_BORDER        = $00800000;
  WS_DLGFRAME      = $00400000;
  WS_VSCROLL       = $00200000;
  WS_HSCROLL       = $00100000;
  WS_SYSMENU       = $00080000;
  WS_THICKFRAME    = $00040000;
  WS_GROUP         = $00020000;
  WS_TABSTOP       = $00010000;
  WS_MINIMIZEBOX   = $00020000;
  WS_MAXIMIZEBOX   = $00010000;
  
  { Styles de boutons (BS_*) }
  BS_PUSHBUTTON    = $0000;
  BS_DEFPUSHBUTTON = $0001;
  BS_CHECKBOX      = $0002;
  BS_AUTOCHECKBOX  = $0003;
  BS_RADIOBUTTON   = $0004;
  BS_3STATE        = $0005;
  BS_AUTO3STATE    = $0006;
  BS_GROUPBOX      = $0007;
  BS_AUTORADIOBUTTON = $0009;
  BS_PUSHBOX       = $000A;
  BS_LEFTTEXT      = $0020;
  
  { Styles de texte statique (SS_*) }
  SS_LEFT          = $0000;
  SS_CENTER        = $0001;
  SS_RIGHT         = $0002;
  SS_ICON          = $0003;
  SS_BLACKRECT     = $0004;
  SS_GRAYRECT      = $0005;
  SS_WHITERECT     = $0006;
  SS_BLACKFRAME    = $0007;
  SS_GRAYFRAME     = $0008;
  SS_WHITEFRAME    = $0009;
  SS_SIMPLE        = $000B;
  SS_LEFTNOWORDWRAP= $000C;
  SS_OWNERDRAW     = $000D;
  SS_BITMAP        = $000E;
  SS_CENTERIMAGE   = $0200;
  
  { Styles d editbox (ES_*) }
  ES_LEFT          = $0000;
  ES_CENTER        = $0001;
  ES_RIGHT         = $0002;
  ES_MULTILINE     = $0004;
  ES_UPPERCASE     = $0008;
  ES_LOWERCASE     = $0010;
  ES_PASSWORD      = $0020;
  ES_AUTOVSCROLL   = $0040;
  ES_AUTOHSCROLL   = $0080;
  ES_NOHIDESEL     = $0100;
  ES_READONLY      = $0800;
  ES_WANTRETURN    = $1000;
  
  { Styles de listbox (LBS_*) }
  LBS_NOTIFY       = $0001;
  LBS_SORT         = $0002;
  LBS_NOREDRAW     = $0004;
  LBS_MULTIPLESEL  = $0008;
  LBS_HASSTRINGS   = $0040;
  LBS_USETABSTOPS  = $0080;
  LBS_NOINTEGRALHEIGHT = $0100;
  
  { Styles de combobox (CBS_*) }
  CBS_SIMPLE       = $0001;
  CBS_DROPDOWN     = $0002;
  CBS_DROPDOWNLIST = $0003;
  CBS_OWNERDRAWFIXED = $0010;
  CBS_AUTOHSCROLL  = $0040;
  CBS_SORT         = $0100;
  CBS_HASSTRINGS   = $0200;
  
  { TODO 15 : Constantes pour VERSIONINFO }
  { Types de fichier (VFT_*) }
  VFT_UNKNOWN    = $00000000;   { Type inconnu }
  VFT_APP        = $00000001;   { Application }
  VFT_DLL        = $00000002;   { DLL }
  VFT_DRV        = $00000003;   { Driver }
  VFT_FONT       = $00000004;   { Police }
  VFT_VXD        = $00000005;   { VxD }
  VFT_STATIC_LIB = $00000007;   { Bibliotheque statique }
  
  { Sous-types de fichier (VFT2_*) }
  VFT2_UNKNOWN         = $00000000;
  VFT2_DRV_PRINTER     = $00000001;
  VFT2_DRV_KEYBOARD    = $00000002;
  VFT2_DRV_LANGUAGE    = $00000003;
  VFT2_DRV_DISPLAY     = $00000004;
  VFT2_DRV_MOUSE       = $00000005;
  VFT2_DRV_NETWORK     = $00000006;
  VFT2_DRV_SYSTEM      = $00000007;
  VFT2_DRV_INSTALLABLE = $00000008;
  VFT2_DRV_SOUND       = $00000009;
  VFT2_DRV_COMM        = $0000000A;
  VFT2_FONT_RASTER     = $00000001;
  VFT2_FONT_VECTOR     = $00000002;
  VFT2_FONT_TRUETYPE   = $00000003;
  
  { Systemes d exploitation cibles (VOS_*) }
  VOS_UNKNOWN    = $00000000;   { OS inconnu }
  VOS_DOS        = $00010000;   { DOS }
  VOS_OS216      = $00020000;   { OS/2 16 bits }
  VOS_OS232      = $00030000;   { OS/2 32 bits }
  VOS_NT         = $00040000;   { Windows NT }
  VOS__WINDOWS16 = $00000001;   { Windows 16 bits }
  VOS__PM16      = $00000002;   { Presentation Manager 16 bits }
  VOS__PM32      = $00000003;   { Presentation Manager 32 bits }
  VOS__WINDOWS32 = $00000004;   { Windows 32 bits }
  VOS_DOS_WINDOWS16 = $00010001;
  VOS_DOS_WINDOWS32 = $00010004;
  VOS_OS216_PM16 = $00020002;
  VOS_OS232_PM32 = $00030003;
  VOS_NT_WINDOWS32 = $00040004; { Windows NT 32 bits }
  
  { Drapeaux de fichier (VS_FF_*) }
  VS_FF_DEBUG        = $00000001;   { Fichier debug }
  VS_FF_PRERELEASE   = $00000002;   { Version prerelease }
  VS_FF_PATCHED      = $00000004;   { Fichier patche }
  VS_FF_PRIVATEBUILD = $00000008;   { Build prive }
  VS_FF_INFOINFERRED = $00000010;   { Info inferee }
  VS_FF_SPECIALBUILD = $00000020;   { Build special }
  VS_FFI_FILEFLAGSMASK = $0000003F; { Masque valide }
  
  { Signature VS_FIXEDFILEINFO }
  VS_FFI_SIGNATURE_LO = $04BD;       { Partie basse de la signature }
  VS_FFI_SIGNATURE_HI = $FEEF;       { Partie haute de la signature }
  VS_FFI_STRUCVERSION= $00010000;   { Version de structure }
  
  { Taille maximale pour les valeurs de version }
  MAX_VERSION_STRINGS = 64;
  
  { TODO 16 : Taille maximale pour les entrees icone/curseur }
  MAX_ICON_ENTRIES = 64;

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
  
  { TODO 11 : Table des chaines STRINGTABLE }
  TStringEntry = Record
    StringId : Word;        { identifiant de la chaine }
    Text     : TString;     { texte de la chaine }
    LangId   : Word;        { langue }
  End;
  
  { TODO 12 : Accelerateurs }
  TAccelEntry = Record
    fVirt : Word;           { drapeaux de l accelerateur }
    Key   : Word;           { code de touche ou ASCII }
    Cmd   : Word;           { identifiant de commande }
  End;
  
  { TODO 13 : Menus }
  TMenuItem = Record
    Flags   : Word;         { drapeaux fItemFlags }
    MenuID  : Word;         { identifiant ou 0 si popup }
    Text    : TString;      { texte de l element }
    IsPopup : Boolean;      { True si sous-menu }
    IsSep   : Boolean;      { True si separateur }
    Level   : Integer;      { niveau d imbrication }
  End;
  
  { TODO 14 : Dialogues }
  TDialogTemplate = Record
    Style    : LongInt;     { styles de fenetre }
    ExStyle  : LongInt;     { styles etendus }
    X, Y     : Integer;     { position }
    CX, CY   : Integer;     { dimensions }
    Menu     : TString;     { ressource menu ou vide }
    MenuIsId : Boolean;     { True si menu est un ID }
    MenuId   : Word;        { ID du menu }
    DlgClass : TString;     { classe de fenetre ou vide }
    ClassIsId: Boolean;     { True si classe est un ID }
    ClassId  : Word;        { ID de classe }
    Title    : TString;     { titre de la boite }
    FontName : TString;     { nom de police si DS_SETFONT }
    FontSize : Word;        { taille de police si DS_SETFONT }
    IsEx     : Boolean;     { True si DIALOGEX }
  End;
  
  TDialogControl = Record
    Style    : LongInt;     { styles du controle }
    ExStyle  : LongInt;     { styles etendus }
    X, Y     : Integer;     { position }
    CX, CY   : Integer;     { dimensions }
    Id       : Word;        { identifiant de controle }
    CtrlClass: TString;     { classe ou vide si atom }
    ClassIsId: Boolean;     { True si classe predefinie }
    ClassId  : Word;        { atom de classe predefinie }
    Text     : TString;     { texte ou ressource }
    TextIsId : Boolean;     { True si texte est un ID ressource }
    TextId   : Word;        { ID de ressource si TextIsId }
  End;
  
  { TODO 15 : VERSIONINFO }
  TVersionStringValue = Record
    Key   : TString;        { cle (CompanyName, FileVersion, etc.) }
    Value : TString;        { valeur de la chaine }
  End;
  
  TVersionInfo = Record
    { VS_FIXEDFILEINFO }
    FileVersionMS     : LongInt;  { HIWORD=majeur, LOWORD=mineur }
    FileVersionLS     : LongInt;  { HIWORD=build, LOWORD=revision }
    ProductVersionMS  : LongInt;  { HIWORD=majeur, LOWORD=mineur }
    ProductVersionLS  : LongInt;  { HIWORD=build, LOWORD=revision }
    FileFlagsMask     : LongInt;  { Masque des drapeaux valides }
    FileFlags         : LongInt;  { Drapeaux du fichier }
    FileOS            : LongInt;  { OS cible }
    FileType          : LongInt;  { Type de fichier }
    FileSubtype       : LongInt;  { Sous-type de fichier }
    { StringFileInfo }
    StringValues      : Array[1..MAX_VERSION_STRINGS] Of TVersionStringValue;
    StringCount       : Integer;  { Nombre de paires cle/valeur }
    { VarFileInfo - Translation }
    TranslationLang   : Word;     { Langue (ex: $0409 = anglais US) }
    TranslationCP     : Word;     { Code page (ex: $04B0 = Unicode) }
  End;
  
  { TODO 16 : Structure pour les entrees de repertoire icone/curseur }
  TIconDirEntry = Record
    Width      : Byte;      { largeur, 0 = 256 }
    Height     : Byte;      { hauteur, 0 = 256 }
    ColorCount : Byte;      { nombre de couleurs, 0 si >= 256 }
    Reserved   : Byte;      { = 0 }
    Planes     : Word;      { 1 pour ICO; hotspot X pour CUR }
    BitCount   : Word;      { bits par pixel; hotspot Y pour CUR }
    BytesInRes : LongInt;   { taille des donnees DIB }
    ImageOffset: LongInt;   { offset dans le fichier .ico/.cur }
  End;
  
  { TODO 16 : Structure pour le repertoire de groupe }
  TGrpIconDirEntry = Record
    Width      : Byte;      { largeur, 0 = 256 }
    Height     : Byte;      { hauteur, 0 = 256 }
    ColorCount : Byte;      { nombre de couleurs, 0 si >= 256 }
    Reserved   : Byte;      { = 0 }
    Planes     : Word;      { 1 pour ICO; hotspot X pour CUR }
    BitCount   : Word;      { bits par pixel; hotspot Y pour CUR }
    BytesInRes : LongInt;   { taille des donnees DIB }
    Id         : Word;      { identifiant de la ressource RT_ICON associee }
  End;
  
  { TODO 17 : Structure pour l'en-tete de fichier bitmap }
  TBitmapFileHeader = Record
    bfType      : Word;     { doit etre 'BM' = $4D42 }
    bfSize      : LongInt;  { taille totale du fichier }
    bfReserved1 : Word;     { reserve, = 0 }
    bfReserved2 : Word;     { reserve, = 0 }
    bfOffBits   : LongInt;  { offset des donnees pixels }
  End;
  
  { TODO 17 : Structure pour l'en-tete d'info bitmap }
  TBitmapInfoHeader = Record
    biSize          : LongInt;  { = 40 }
    biWidth         : LongInt;  { largeur en pixels }
    biHeight        : LongInt;  { hauteur en pixels }
    biPlanes        : Word;     { = 1 }
    biBitCount      : Word;     { bits par pixel }
    biCompression   : LongInt;  { type de compression }
    biSizeImage     : LongInt;  { taille des donnees image }
    biXPelsPerMeter : LongInt;  { resolution horizontale }
    biYPelsPerMeter : LongInt;  { resolution verticale }
    biClrUsed       : LongInt;  { nombre de couleurs utilisees }
    biClrImportant  : LongInt;  { nombre de couleurs importantes }
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
  
  { TODO 11 : Table des chaines STRINGTABLE }
  StringEntries : Array[1..MAX_STRINGS] Of TStringEntry;
  StringCount   : Integer;
  
  { TODO 12 : Table des accelerateurs }
  AccelEntries : Array[1..MAX_ACCEL] Of TAccelEntry;
  AccelCount   : Integer;
  
  { TODO 13 : Table des elements de menu }
  MenuItems    : Array[1..MAX_MENU_ITEMS] Of TMenuItem;
  MenuItemCount: Integer;
  
  { TODO 14 : Dialogues }
  DialogTemplate  : TDialogTemplate;
  DialogControls  : Array[1..MAX_DIALOG_CTRL] Of TDialogControl;
  DialogCtrlCount : Integer;
  
  { TODO 15 : VERSIONINFO }
  VersionInfo : TVersionInfo;
  
  { TODO 16 : ICON/CURSOR }
  NextIconId   : Word;     { prochain ID pour RT_ICON }
  NextCursorId : Word;     { prochain ID pour RT_CURSOR }
  IconEntries  : Array[1..MAX_ICON_ENTRIES] Of TIconDirEntry;
  IconCount    : Integer;
  IconData     : Array[1..MAX_ICON_ENTRIES] Of Pointer;
  IconDataSizes: Array[1..MAX_ICON_ENTRIES] Of LongInt;
  
  { TODO 17 : BITMAP }
  BitmapData     : Pointer;   { donnees du bitmap (sans BITMAPFILEHEADER) }
  BitmapDataSize : LongInt;   { taille des donnees du bitmap }

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

{ ----- Procedure WriteBytesFromPtr ----- }
Procedure WriteBytesFromPtr(Ptr : Pointer; Count : LongInt);
Var
  I   : LongInt;
  P   : PByte;
Begin
  P := PByte(Ptr);
  For I := 0 To Count - 1 Do
  Begin
    WriteByte(P^);
    Inc(P);
  End;
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

{ =============================================================
  TODO 11 - COMPILATION STRINGTABLE
  ============================================================= }

{ ----- Procedure AddStringEntry ----- }
{ Ajoute une entree dans la table des chaines }
Procedure AddStringEntry(AStringId: Word; Const AText: TString; ALangId: Word);
Begin
  If StringCount >= MAX_STRINGS Then
  Begin
    FatalError('Nombre maximal de chaines atteint (' + IntToStr(MAX_STRINGS) + ')');
    Exit;
  End;
  
  Inc(StringCount);
  
  With StringEntries[StringCount] Do
  Begin
    StringId := AStringId;
    Text     := AText;
    LangId   := ALangId;
  End;
End;

{ ----- Procedure ParseStringTable ----- }
{ Parse un bloc STRINGTABLE ... BEGIN ... END }
{ Format : STRINGTABLE [options memoire]
           BEGIN
             id, "texte"
             id, "texte"
             ...
           END }
Procedure ParseStringTable;
Var
  StringId : LongInt;
  Text     : TString;
  MemFlags : Word;
Begin
  { Lire les options memoire optionnelles }
  MemFlags := ParseMemoryOptions;
  
  { Attendre BEGIN ou { }
  If (CurrToken.Kind <> TK_BEGIN) And (CurrToken.Kind <> TK_LBRACE) Then
  Begin
    SyntaxError('BEGIN ou accolade ouvrante attendu apres STRINGTABLE');
    Exit;
  End;
  NextToken; (* Consommer BEGIN ou accolade ouvrante *)
  
  (* Lire les entrees jusqu a END ou accolade fermante *)
  While (CurrToken.Kind <> TK_END) And (CurrToken.Kind <> TK_RBRACE) And
        (CurrToken.Kind <> TK_EOF) Do
  Begin
    { Ignorer les commentaires et nouvelles lignes }
    If CurrToken.Kind = TK_NEWLINE Then
    Begin
      NextToken;
      Continue;
    End;
    
    If CurrToken.Kind = TK_COMMENT Then
    Begin
      NextToken;
      Continue;
    End;
    
    { Lire l identifiant de la chaine (nombre) }
    If CurrToken.Kind <> TK_NUMBER Then
    Begin
      SyntaxError('Identifiant numerique attendu dans STRINGTABLE');
      SkipToEndBlock;
      Exit;
    End;
    StringId := CurrToken.IntVal;
    NextToken;
    
    { Optionnel : virgule ou comma }
    If CurrToken.Kind = TK_COMMA Then
      NextToken;
    
    { Lire la chaine entre guillemets }
    If CurrToken.Kind <> TK_STRING Then
    Begin
      SyntaxError('Chaine entre guillemets attendue dans STRINGTABLE');
      SkipToEndBlock;
      Exit;
    End;
    Text := CurrToken.Value;
    NextToken;
    
    { Ajouter l entree dans la table }
    AddStringEntry(Word(StringId), Text, CurrentLangId);
  End;
  
  (* Consommer END ou accolade fermante *)
  If (CurrToken.Kind = TK_END) Or (CurrToken.Kind = TK_RBRACE) Then
    NextToken;
End;

{ ----- Function FindStringBlock ----- }
{ Trouve si un bloc de 16 chaines contient au moins une chaine }
{ BlockId = 1..n, contient les chaines (BlockId-1)*16 a (BlockId-1)*16+15 }
Function FindStringBlock(BlockId: Integer; LangId: Word): Boolean;
Var
  I       : Integer;
  MinId   : Word;
  MaxId   : Word;
Begin
  MinId := Word((BlockId - 1) * 16);
  MaxId := MinId + 15;
  FindStringBlock := False;
  
  For I := 1 To StringCount Do
  Begin
    If (StringEntries[I].LangId = LangId) And
       (StringEntries[I].StringId >= MinId) And
       (StringEntries[I].StringId <= MaxId) Then
    Begin
      FindStringBlock := True;
      Exit;
    End;
  End;
End;

{ ----- Function GetStringFromBlock ----- }
{ Retourne la chaine pour un slot dans un bloc }
{ BlockId = 1..n, Slot = 0..15 }
Function GetStringFromBlock(BlockId: Integer; Slot: Integer; LangId: Word): TString;
Var
  I        : Integer;
  TargetId : Word;
Begin
  TargetId := Word((BlockId - 1) * 16 + Slot);
  GetStringFromBlock := '';
  
  For I := 1 To StringCount Do
  Begin
    If (StringEntries[I].LangId = LangId) And
       (StringEntries[I].StringId = TargetId) Then
    Begin
      GetStringFromBlock := StringEntries[I].Text;
      Exit;
    End;
  End;
End;

{ ----- Function GetMaxStringBlockId ----- }
{ Retourne le numero de bloc maximal utilise }
Function GetMaxStringBlockId(LangId: Word): Integer;
Var
  I       : Integer;
  BlockId : Integer;
  MaxBlock: Integer;
Begin
  MaxBlock := 0;
  
  For I := 1 To StringCount Do
  Begin
    If StringEntries[I].LangId = LangId Then
    Begin
      BlockId := (StringEntries[I].StringId Div 16) + 1;
      If BlockId > MaxBlock Then
        MaxBlock := BlockId;
    End;
  End;
  
  GetMaxStringBlockId := MaxBlock;
End;

{ ----- Procedure WriteStringTable ----- }
{ Ecrit les blocs STRINGTABLE dans le fichier .RES }
{ Format 32 bits : chaque bloc contient 16 chaines }
{ Pour chaque chaine : WORD longueur (en WCHARs), puis WCHARs }
Procedure WriteStringTable;
Var
  BlockId    : Integer;
  MaxBlock   : Integer;
  Slot       : Integer;
  Str        : TString;
  I          : Integer;
  DataStart  : LongInt;
  DataSize   : LongInt;
  LangId     : Word;
  LangList   : Array[1..256] Of Word;
  LangCount  : Integer;
  LangIdx    : Integer;
  Found      : Boolean;
  ResIdx     : Integer;
Begin
  If StringCount = 0 Then
    Exit;
  
  { Collecter la liste des langues utilisees }
  LangCount := 0;
  For I := 1 To StringCount Do
  Begin
    LangId := StringEntries[I].LangId;
    Found := False;
    For LangIdx := 1 To LangCount Do
    Begin
      If LangList[LangIdx] = LangId Then
      Begin
        Found := True;
        Break;
      End;
    End;
    If Not Found Then
    Begin
      Inc(LangCount);
      If LangCount <= 256 Then
        LangList[LangCount] := LangId;
    End;
  End;
  
  { Pour chaque langue, ecrire les blocs de chaines }
  For LangIdx := 1 To LangCount Do
  Begin
    LangId := LangList[LangIdx];
    MaxBlock := GetMaxStringBlockId(LangId);
    
    { Pour chaque bloc qui contient des chaines }
    For BlockId := 1 To MaxBlock Do
    Begin
      If Not FindStringBlock(BlockId, LangId) Then
        Continue;
      
      { Enregistrer la ressource dans la table }
      ResIdx := AddResource(True, RT_STRING, '', True, Word(BlockId), '',
                           DefaultMemFlags, LangId);
      
      { Ecrire l en-tete 32 bits }
      { On va d abord calculer la taille des donnees }
      DataStart := GetResPos;
      
      { Ecrire les 16 slots du bloc }
      For Slot := 0 To 15 Do
      Begin
        Str := GetStringFromBlock(BlockId, Slot, LangId);
        
        { Ecrire la longueur en WCHARs }
        WriteWord(Word(Length(Str)));
        
        { Ecrire les caracteres en Unicode }
        For I := 1 To Length(Str) Do
          WriteWChar(CharToWChar(Str[I]));
      End;
      
      { Calculer la taille des donnees }
      DataSize := GetResPos - DataStart;
      
      { Aligner sur 4 octets }
      PadToAlignment(4);
      
      { Mettre a jour la taille et l offset dans la table des ressources }
      SetResourceDataOfs(ResIdx, DataStart);
      SetResourceDataSize(ResIdx, DataSize);
    End;
  End;
End;

{ =============================================================
  TODO 12 - COMPILATION ACCELERATORS
  ============================================================= }

{ ----- Function VKeyFromName ----- }
{ Retourne le code de touche virtuelle depuis le nom }
Function VKeyFromName(Const Name: TString): Word;
Var
  UpName : TString;
Begin
  UpName := UpCaseStr(Name);
  
  { Touches de fonction }
  If UpName = 'VK_F1' Then VKeyFromName := VK_F1
  Else If UpName = 'VK_F2' Then VKeyFromName := VK_F2
  Else If UpName = 'VK_F3' Then VKeyFromName := VK_F3
  Else If UpName = 'VK_F4' Then VKeyFromName := VK_F4
  Else If UpName = 'VK_F5' Then VKeyFromName := VK_F5
  Else If UpName = 'VK_F6' Then VKeyFromName := VK_F6
  Else If UpName = 'VK_F7' Then VKeyFromName := VK_F7
  Else If UpName = 'VK_F8' Then VKeyFromName := VK_F8
  Else If UpName = 'VK_F9' Then VKeyFromName := VK_F9
  Else If UpName = 'VK_F10' Then VKeyFromName := VK_F10
  Else If UpName = 'VK_F11' Then VKeyFromName := VK_F11
  Else If UpName = 'VK_F12' Then VKeyFromName := VK_F12
  { Touches de navigation }
  Else If UpName = 'VK_LEFT' Then VKeyFromName := VK_LEFT
  Else If UpName = 'VK_RIGHT' Then VKeyFromName := VK_RIGHT
  Else If UpName = 'VK_UP' Then VKeyFromName := VK_UP
  Else If UpName = 'VK_DOWN' Then VKeyFromName := VK_DOWN
  Else If UpName = 'VK_HOME' Then VKeyFromName := VK_HOME
  Else If UpName = 'VK_END' Then VKeyFromName := VK_END
  Else If UpName = 'VK_PRIOR' Then VKeyFromName := VK_PRIOR
  Else If (UpName = 'VK_NEXT') Or (UpName = 'VK_PAGEDOWN') Then VKeyFromName := VK_NEXT
  Else If UpName = 'VK_PAGEUP' Then VKeyFromName := VK_PRIOR
  { Touches speciales }
  Else If UpName = 'VK_BACK' Then VKeyFromName := VK_BACK
  Else If UpName = 'VK_TAB' Then VKeyFromName := VK_TAB
  Else If (UpName = 'VK_RETURN') Or (UpName = 'VK_ENTER') Then VKeyFromName := VK_RETURN
  Else If (UpName = 'VK_ESCAPE') Or (UpName = 'VK_ESC') Then VKeyFromName := VK_ESCAPE
  Else If UpName = 'VK_SPACE' Then VKeyFromName := VK_SPACE
  Else If UpName = 'VK_INSERT' Then VKeyFromName := VK_INSERT
  Else If UpName = 'VK_DELETE' Then VKeyFromName := VK_DELETE
  Else If UpName = 'VK_HELP' Then VKeyFromName := VK_HELP
  Else If UpName = 'VK_PAUSE' Then VKeyFromName := VK_PAUSE
  Else If UpName = 'VK_CAPITAL' Then VKeyFromName := VK_CAPITAL
  Else If UpName = 'VK_CLEAR' Then VKeyFromName := VK_CLEAR
  Else If UpName = 'VK_SELECT' Then VKeyFromName := VK_SELECT
  Else If UpName = 'VK_PRINT' Then VKeyFromName := VK_PRINT
  Else If UpName = 'VK_EXECUTE' Then VKeyFromName := VK_EXECUTE
  Else If UpName = 'VK_SNAPSHOT' Then VKeyFromName := VK_SNAPSHOT
  Else If UpName = 'VK_NUMLOCK' Then VKeyFromName := VK_NUMLOCK
  Else If UpName = 'VK_SCROLL' Then VKeyFromName := VK_SCROLL
  Else If UpName = 'VK_SHIFT' Then VKeyFromName := VK_SHIFT
  Else If UpName = 'VK_CONTROL' Then VKeyFromName := VK_CONTROL
  Else If UpName = 'VK_MENU' Then VKeyFromName := VK_MENU
  { Valeur inconnue }
  Else VKeyFromName := 0;
End;

{ ----- Function IsAccelOption ----- }
{ Verifie si le token est une option d accelerateur }
Function IsAccelOption(Const S: TString): Boolean;
Var
  UpS : TString;
Begin
  UpS := UpCaseStr(S);
  IsAccelOption := (UpS = 'VIRTKEY') Or (UpS = 'ASCII') Or
                   (UpS = 'SHIFT') Or (UpS = 'CONTROL') Or
                   (UpS = 'ALT') Or (UpS = 'NOINVERT');
End;

{ ----- Procedure ParseAccelerators ----- }
{ Parse un bloc ACCELERATORS ... BEGIN ... END }
Procedure ParseAccelerators(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word);
Var
  Key      : Word;
  Cmd      : Word;
  fVirt    : Word;
  KeyStr   : TString;
  IsVirtKey: Boolean;
Begin
  { Reinitialiser le compteur d accelerateurs }
  AccelCount := 0;
  
  { Attendre BEGIN ou accolade ouvrante }
  If (CurrToken.Kind <> TK_BEGIN) And (CurrToken.Kind <> TK_LBRACE) Then
  Begin
    SyntaxError('BEGIN ou accolade ouvrante attendu apres ACCELERATORS');
    Exit;
  End;
  NextToken; (* Consommer BEGIN ou accolade ouvrante *)
  
  (* Lire les entrees jusqu a END ou accolade fermante *)
  While (CurrToken.Kind <> TK_END) And (CurrToken.Kind <> TK_RBRACE) And
        (CurrToken.Kind <> TK_EOF) Do
  Begin
    { Ignorer les commentaires et nouvelles lignes }
    If CurrToken.Kind = TK_NEWLINE Then
    Begin
      NextToken;
      Continue;
    End;
    
    If CurrToken.Kind = TK_COMMENT Then
    Begin
      NextToken;
      Continue;
    End;
    
    { Lire la touche (chaine ASCII ou identifiant VK_xxx) }
    Key := 0;
    fVirt := 0;
    IsVirtKey := False;
    
    If CurrToken.Kind = TK_STRING Then
    Begin
      { Caractere ASCII entre guillemets }
      KeyStr := CurrToken.Value;
      If Length(KeyStr) > 0 Then
        Key := Ord(KeyStr[1]);
      NextToken;
    End
    Else If CurrToken.Kind = TK_NUMBER Then
    Begin
      { Code numerique }
      Key := Word(CurrToken.IntVal);
      NextToken;
    End
    Else If CurrToken.Kind = TK_IDENT Then
    Begin
      { Identifiant de touche virtuelle }
      KeyStr := CurrToken.Value;
      Key := VKeyFromName(KeyStr);
      If Key = 0 Then
      Begin
        { Peut etre une lettre simple comme A, B, etc. }
        If Length(KeyStr) = 1 Then
          Key := Ord(UpCase(KeyStr[1]))
        Else
          SyntaxError('Touche inconnue: ' + KeyStr);
      End
      Else
        IsVirtKey := True;
      NextToken;
    End
    Else
    Begin
      SyntaxError('Touche attendue dans ACCELERATORS');
      SkipToEndBlock;
      Exit;
    End;
    
    { Attendre une virgule }
    If CurrToken.Kind = TK_COMMA Then
      NextToken;
    
    { Lire l identifiant de commande }
    If CurrToken.Kind = TK_NUMBER Then
    Begin
      Cmd := Word(CurrToken.IntVal);
      NextToken;
    End
    Else If CurrToken.Kind = TK_IDENT Then
    Begin
      { Identificateur symbolique - convertir en nombre si possible }
      Cmd := Word(StrToInt(CurrToken.Value));
      NextToken;
    End
    Else
    Begin
      SyntaxError('Identifiant de commande attendu dans ACCELERATORS');
      SkipToEndBlock;
      Exit;
    End;
    
    { Lire les options (virgule puis VIRTKEY, SHIFT, CONTROL, ALT, NOINVERT) }
    While CurrToken.Kind = TK_COMMA Do
    Begin
      NextToken;
      
      If CurrToken.Kind = TK_IDENT Then
      Begin
        KeyStr := UpCaseStr(CurrToken.Value);
        
        If KeyStr = 'VIRTKEY' Then
        Begin
          fVirt := fVirt Or FVIRTKEY;
          IsVirtKey := True;
        End
        Else If KeyStr = 'ASCII' Then
        Begin
          { ASCII = pas VIRTKEY, ne rien faire }
        End
        Else If KeyStr = 'SHIFT' Then
          fVirt := fVirt Or FSHIFT
        Else If KeyStr = 'CONTROL' Then
          fVirt := fVirt Or FCONTROL
        Else If KeyStr = 'ALT' Then
          fVirt := fVirt Or FALT
        Else If KeyStr = 'NOINVERT' Then
          fVirt := fVirt Or FNOINVERT;
        
        NextToken;
      End;
    End;
    
    { Si la touche est virtuelle, ajouter le flag }
    If IsVirtKey Then
      fVirt := fVirt Or FVIRTKEY;
    
    { Ajouter l entree dans la table }
    If AccelCount < MAX_ACCEL Then
    Begin
      Inc(AccelCount);
      AccelEntries[AccelCount].fVirt := fVirt;
      AccelEntries[AccelCount].Key := Key;
      AccelEntries[AccelCount].Cmd := Cmd;
    End;
  End;
  
  (* Consommer END ou accolade fermante *)
  If (CurrToken.Kind = TK_END) Or (CurrToken.Kind = TK_RBRACE) Then
    NextToken;
End;

{ ----- Procedure WriteAccelerators ----- }
{ Ecrit une table d accelerateurs dans le fichier .RES }
Procedure WriteAccelerators(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word; LangId: Word);
Var
  I         : Integer;
  DataStart : LongInt;
  DataSize  : LongInt;
  ResIdx    : Integer;
  fVirt     : Word;
Begin
  If AccelCount = 0 Then
    Exit;
  
  { Enregistrer la ressource dans la table }
  ResIdx := AddResource(True, RT_ACCELERATOR, '', NameIsId, NameId, NameStr,
                       MemFlags, LangId);
  
  { Memoriser la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire chaque entree d accelerateur }
  { Format: WORD fVirt, WORD key, WORD cmd, WORD padding }
  For I := 1 To AccelCount Do
  Begin
    fVirt := AccelEntries[I].fVirt;
    
    { Marquer la derniere entree avec le bit $80 }
    If I = AccelCount Then
      fVirt := fVirt Or FLAST;
    
    WriteWord(fVirt);
    WriteWord(AccelEntries[I].Key);
    WriteWord(AccelEntries[I].Cmd);
    WriteWord(0);  { Padding }
  End;
  
  { Calculer la taille des donnees }
  DataSize := GetResPos - DataStart;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l offset dans la table des ressources }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ =============================================================
  TODO 13 - COMPILATION MENU
  ============================================================= }

{ ----- Function IsMenuOption ----- }
{ Verifie si le token est une option de menu }
Function IsMenuOption(Const S: TString): Boolean;
Var
  UpS : TString;
Begin
  UpS := UpCaseStr(S);
  IsMenuOption := (UpS = 'GRAYED') Or (UpS = 'INACTIVE') Or
                  (UpS = 'CHECKED') Or (UpS = 'MENUBARBREAK') Or
                  (UpS = 'MENUBREAK') Or (UpS = 'HELP') Or
                  (UpS = 'OWNERDRAW');
End;

{ ----- Function MenuFlagFromName ----- }
{ Retourne le flag MF_* depuis le nom }
Function MenuFlagFromName(Const Name: TString): Word;
Var
  UpName : TString;
Begin
  UpName := UpCaseStr(Name);
  
  If (UpName = 'GRAYED') Or (UpName = 'INACTIVE') Then
    MenuFlagFromName := MF_GRAYED
  Else If UpName = 'CHECKED' Then
    MenuFlagFromName := MF_CHECKED
  Else If UpName = 'MENUBARBREAK' Then
    MenuFlagFromName := MF_MENUBARBREAK
  Else If UpName = 'MENUBREAK' Then
    MenuFlagFromName := MF_MENUBREAK
  Else If UpName = 'HELP' Then
    MenuFlagFromName := MF_HELP
  Else If UpName = 'OWNERDRAW' Then
    MenuFlagFromName := MF_OWNERDRAW
  Else
    MenuFlagFromName := 0;
End;

{ ----- Procedure AddMenuItem ----- }
{ Ajoute un element de menu a la table }
Procedure AddMenuItem(Flags: Word; MenuID: Word; Const Text: TString;
                      IsPopup, IsSep: Boolean; Level: Integer);
Begin
  If MenuItemCount < MAX_MENU_ITEMS Then
  Begin
    Inc(MenuItemCount);
    MenuItems[MenuItemCount].Flags := Flags;
    MenuItems[MenuItemCount].MenuID := MenuID;
    MenuItems[MenuItemCount].Text := Text;
    MenuItems[MenuItemCount].IsPopup := IsPopup;
    MenuItems[MenuItemCount].IsSep := IsSep;
    MenuItems[MenuItemCount].Level := Level;
  End;
End;

{ ----- Procedure ParseMenuBlock ----- }
{ Parse un bloc de menu recursivement (entre BEGIN et END) }
Procedure ParseMenuBlock(Level: Integer); Forward;

Procedure ParseMenuBlock(Level: Integer);
Var
  ItemText  : TString;
  ItemId    : Word;
  ItemFlags : Word;
  KeyWord   : TString;
Begin
  (* Consommer BEGIN ou accolade ouvrante *)
  If (CurrToken.Kind = TK_BEGIN) Or (CurrToken.Kind = TK_LBRACE) Then
    NextToken;
  
  (* Lire les elements jusqu a END ou accolade fermante *)
  While (CurrToken.Kind <> TK_END) And (CurrToken.Kind <> TK_RBRACE) And
        (CurrToken.Kind <> TK_EOF) Do
  Begin
    { Ignorer les nouvelles lignes et commentaires }
    If CurrToken.Kind = TK_NEWLINE Then
    Begin
      NextToken;
      Continue;
    End;
    
    If CurrToken.Kind = TK_COMMENT Then
    Begin
      NextToken;
      Continue;
    End;
    
    If CurrToken.Kind = TK_IDENT Then
    Begin
      KeyWord := UpCaseStr(CurrToken.Value);
      
      If KeyWord = 'POPUP' Then
      Begin
        { POPUP "text" ... BEGIN ... END }
        NextToken;
        
        { Lire le texte du popup }
        ItemText := '';
        If CurrToken.Kind = TK_STRING Then
        Begin
          ItemText := CurrToken.Value;
          NextToken;
        End;
        
        { Lire les options }
        ItemFlags := MF_POPUP;
        While CurrToken.Kind = TK_COMMA Do
        Begin
          NextToken;
          If CurrToken.Kind = TK_IDENT Then
          Begin
            ItemFlags := ItemFlags Or MenuFlagFromName(CurrToken.Value);
            NextToken;
          End;
        End;
        
        { Ajouter l element popup }
        AddMenuItem(ItemFlags, 0, ItemText, True, False, Level);
        
        { Parser le sous-menu }
        If (CurrToken.Kind = TK_BEGIN) Or (CurrToken.Kind = TK_LBRACE) Then
          ParseMenuBlock(Level + 1);
      End
      Else If KeyWord = 'MENUITEM' Then
      Begin
        { MENUITEM "text", id [, options] ou MENUITEM SEPARATOR }
        NextToken;
        
        { Verifier si c est un separateur }
        If (CurrToken.Kind = TK_IDENT) And 
           (UpCaseStr(CurrToken.Value) = 'SEPARATOR') Then
        Begin
          NextToken;
          AddMenuItem(MF_SEPARATOR, 0, '', False, True, Level);
        End
        Else
        Begin
          { MENUITEM "text", id [, options] }
          ItemText := '';
          If CurrToken.Kind = TK_STRING Then
          Begin
            ItemText := CurrToken.Value;
            NextToken;
          End;
          
          { Virgule et identifiant }
          ItemId := 0;
          If CurrToken.Kind = TK_COMMA Then
          Begin
            NextToken;
            If CurrToken.Kind = TK_NUMBER Then
            Begin
              ItemId := Word(CurrToken.IntVal);
              NextToken;
            End
            Else If CurrToken.Kind = TK_IDENT Then
            Begin
              ItemId := Word(StrToInt(CurrToken.Value));
              NextToken;
            End;
          End;
          
          { Options supplementaires }
          ItemFlags := 0;
          While CurrToken.Kind = TK_COMMA Do
          Begin
            NextToken;
            If CurrToken.Kind = TK_IDENT Then
            Begin
              ItemFlags := ItemFlags Or MenuFlagFromName(CurrToken.Value);
              NextToken;
            End;
          End;
          
          AddMenuItem(ItemFlags, ItemId, ItemText, False, False, Level);
        End;
      End
      Else
      Begin
        { Mot-cle inconnu, ignorer }
        NextToken;
      End;
    End
    Else
    Begin
      NextToken;
    End;
  End;
  
  { Marquer le dernier element du niveau avec MF_END }
  If MenuItemCount > 0 Then
  Begin
    { Trouver le dernier element au niveau courant }
    If MenuItems[MenuItemCount].Level = Level Then
      MenuItems[MenuItemCount].Flags := MenuItems[MenuItemCount].Flags Or MF_END;
  End;
  
  (* Consommer END ou accolade fermante *)
  If (CurrToken.Kind = TK_END) Or (CurrToken.Kind = TK_RBRACE) Then
    NextToken;
End;

{ ----- Procedure ParseMenu ----- }
{ Parse un bloc MENU ... BEGIN ... END }
Procedure ParseMenu(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word);
Begin
  { Reinitialiser le compteur d elements de menu }
  MenuItemCount := 0;
  
  { Attendre BEGIN ou accolade ouvrante }
  If (CurrToken.Kind <> TK_BEGIN) And (CurrToken.Kind <> TK_LBRACE) Then
  Begin
    SyntaxError('BEGIN ou accolade ouvrante attendu apres MENU');
    Exit;
  End;
  
  { Parser le bloc de menu }
  ParseMenuBlock(0);
End;

{ ----- Procedure WriteMenu ----- }
{ Ecrit une ressource menu dans le fichier .RES }
Procedure WriteMenu(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word; LangId: Word);
Var
  I         : Integer;
  DataStart : LongInt;
  DataSize  : LongInt;
  ResIdx    : Integer;
  ItemFlags : Word;
  S         : TString;
  J         : Integer;
Begin
  If MenuItemCount = 0 Then
    Exit;
  
  { Enregistrer la ressource dans la table }
  ResIdx := AddResource(True, RT_MENU, '', NameIsId, NameId, NameStr,
                       MemFlags, LangId);
  
  { Memoriser la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire l en-tete de menu (WORD wVersion=0, WORD cbHeaderSize=0) }
  WriteWord(0);  { wVersion }
  WriteWord(0);  { cbHeaderSize }
  
  { Ecrire chaque element de menu }
  For I := 1 To MenuItemCount Do
  Begin
    ItemFlags := MenuItems[I].Flags;
    
    { Ajuster les flags pour le format binaire }
    If MenuItems[I].IsSep Then
      ItemFlags := ItemFlags Or MF_SEPARATOR;
    If MenuItems[I].IsPopup Then
      ItemFlags := ItemFlags Or MF_POPUP;
    
    { Ecrire les flags }
    WriteWord(ItemFlags);
    
    { Ecrire l ID seulement si ce n est pas un popup }
    If Not MenuItems[I].IsPopup Then
      WriteWord(MenuItems[I].MenuID);
    
    { Ecrire le texte en Unicode termine par $0000 }
    S := MenuItems[I].Text;
    For J := 1 To Length(S) Do
      WriteWChar(CharToWChar(S[J]));
    WriteWChar(0);  { Terminateur Unicode }
  End;
  
  { Calculer la taille des donnees }
  DataSize := GetResPos - DataStart;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l offset dans la table des ressources }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ============================================================
  TODO 14 - COMPILATION DIALOG
  ============================================================ }

{ ----- Function IsDialogOption ----- }
{ Verifie si le token actuel est une option de style de dialogue }
Function IsDialogOption(Const S: TString): Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  IsDialogOption := (U = 'STYLE') Or (U = 'EXSTYLE') Or (U = 'CAPTION') Or
                   (U = 'FONT') Or (U = 'CLASS') Or (U = 'MENU') Or
                   (U = 'CHARACTERISTICS') Or (U = 'VERSION') Or
                   (U = 'LANGUAGE');
End;

{ ----- Function DialogStyleFromName ----- }
{ Convertit un nom de style en valeur }
Function DialogStyleFromName(Const S: TString): LongInt;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  DialogStyleFromName := 0;
  { Styles de fenetre WS_* }
  If U = 'WS_POPUP'         Then DialogStyleFromName := WS_POPUP
  Else If U = 'WS_CHILD'         Then DialogStyleFromName := WS_CHILD
  Else If U = 'WS_MINIMIZE'      Then DialogStyleFromName := WS_MINIMIZE
  Else If U = 'WS_VISIBLE'       Then DialogStyleFromName := WS_VISIBLE
  Else If U = 'WS_DISABLED'      Then DialogStyleFromName := WS_DISABLED
  Else If U = 'WS_CLIPSIBLINGS'  Then DialogStyleFromName := WS_CLIPSIBLINGS
  Else If U = 'WS_CLIPCHILDREN'  Then DialogStyleFromName := WS_CLIPCHILDREN
  Else If U = 'WS_MAXIMIZE'      Then DialogStyleFromName := WS_MAXIMIZE
  Else If U = 'WS_CAPTION'       Then DialogStyleFromName := WS_CAPTION
  Else If U = 'WS_BORDER'        Then DialogStyleFromName := WS_BORDER
  Else If U = 'WS_DLGFRAME'      Then DialogStyleFromName := WS_DLGFRAME
  Else If U = 'WS_VSCROLL'       Then DialogStyleFromName := WS_VSCROLL
  Else If U = 'WS_HSCROLL'       Then DialogStyleFromName := WS_HSCROLL
  Else If U = 'WS_SYSMENU'       Then DialogStyleFromName := WS_SYSMENU
  Else If U = 'WS_THICKFRAME'    Then DialogStyleFromName := WS_THICKFRAME
  Else If U = 'WS_GROUP'         Then DialogStyleFromName := WS_GROUP
  Else If U = 'WS_TABSTOP'       Then DialogStyleFromName := WS_TABSTOP
  Else If U = 'WS_MINIMIZEBOX'   Then DialogStyleFromName := WS_MINIMIZEBOX
  Else If U = 'WS_MAXIMIZEBOX'   Then DialogStyleFromName := WS_MAXIMIZEBOX
  { Styles de dialogue DS_* }
  Else If U = 'DS_ABSALIGN'      Then DialogStyleFromName := DS_ABSALIGN
  Else If U = 'DS_SYSMODAL'      Then DialogStyleFromName := DS_SYSMODAL
  Else If U = 'DS_3DLOOK'        Then DialogStyleFromName := DS_3DLOOK
  Else If U = 'DS_FIXEDSYS'      Then DialogStyleFromName := DS_FIXEDSYS
  Else If U = 'DS_NOFAILCREATE'  Then DialogStyleFromName := DS_NOFAILCREATE
  Else If U = 'DS_LOCALEDIT'     Then DialogStyleFromName := DS_LOCALEDIT
  Else If U = 'DS_SETFONT'       Then DialogStyleFromName := DS_SETFONT
  Else If U = 'DS_MODALFRAME'    Then DialogStyleFromName := DS_MODALFRAME
  Else If U = 'DS_NOIDLEMSG'     Then DialogStyleFromName := DS_NOIDLEMSG
  Else If U = 'DS_SETFOREGROUND' Then DialogStyleFromName := DS_SETFOREGROUND
  Else If U = 'DS_CONTROL'       Then DialogStyleFromName := DS_CONTROL
  Else If U = 'DS_CENTER'        Then DialogStyleFromName := DS_CENTER
  Else If U = 'DS_CENTERMOUSE'   Then DialogStyleFromName := DS_CENTERMOUSE
  Else If U = 'DS_CONTEXTHELP'   Then DialogStyleFromName := DS_CONTEXTHELP
  Else If U = 'DS_SHELLFONT'     Then DialogStyleFromName := DS_SHELLFONT;
End;

{ ----- Function ControlStyleFromName ----- }
{ Convertit un nom de style de controle en valeur }
Function ControlStyleFromName(Const S: TString): LongInt;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  ControlStyleFromName := 0;
  { Styles de boutons BS_* }
  If U = 'BS_PUSHBUTTON'       Then ControlStyleFromName := BS_PUSHBUTTON
  Else If U = 'BS_DEFPUSHBUTTON'   Then ControlStyleFromName := BS_DEFPUSHBUTTON
  Else If U = 'BS_CHECKBOX'        Then ControlStyleFromName := BS_CHECKBOX
  Else If U = 'BS_AUTOCHECKBOX'    Then ControlStyleFromName := BS_AUTOCHECKBOX
  Else If U = 'BS_RADIOBUTTON'     Then ControlStyleFromName := BS_RADIOBUTTON
  Else If U = 'BS_3STATE'          Then ControlStyleFromName := BS_3STATE
  Else If U = 'BS_AUTO3STATE'      Then ControlStyleFromName := BS_AUTO3STATE
  Else If U = 'BS_GROUPBOX'        Then ControlStyleFromName := BS_GROUPBOX
  Else If U = 'BS_AUTORADIOBUTTON' Then ControlStyleFromName := BS_AUTORADIOBUTTON
  Else If U = 'BS_LEFTTEXT'        Then ControlStyleFromName := BS_LEFTTEXT
  { Styles de texte statique SS_* }
  Else If U = 'SS_LEFT'            Then ControlStyleFromName := SS_LEFT
  Else If U = 'SS_CENTER'          Then ControlStyleFromName := SS_CENTER
  Else If U = 'SS_RIGHT'           Then ControlStyleFromName := SS_RIGHT
  Else If U = 'SS_ICON'            Then ControlStyleFromName := SS_ICON
  Else If U = 'SS_BLACKRECT'       Then ControlStyleFromName := SS_BLACKRECT
  Else If U = 'SS_GRAYRECT'        Then ControlStyleFromName := SS_GRAYRECT
  Else If U = 'SS_WHITERECT'       Then ControlStyleFromName := SS_WHITERECT
  Else If U = 'SS_BLACKFRAME'      Then ControlStyleFromName := SS_BLACKFRAME
  Else If U = 'SS_GRAYFRAME'       Then ControlStyleFromName := SS_GRAYFRAME
  Else If U = 'SS_WHITEFRAME'      Then ControlStyleFromName := SS_WHITEFRAME
  Else If U = 'SS_SIMPLE'          Then ControlStyleFromName := SS_SIMPLE
  Else If U = 'SS_BITMAP'          Then ControlStyleFromName := SS_BITMAP
  Else If U = 'SS_CENTERIMAGE'     Then ControlStyleFromName := SS_CENTERIMAGE
  { Styles d editbox ES_* }
  Else If U = 'ES_LEFT'            Then ControlStyleFromName := ES_LEFT
  Else If U = 'ES_CENTER'          Then ControlStyleFromName := ES_CENTER
  Else If U = 'ES_RIGHT'           Then ControlStyleFromName := ES_RIGHT
  Else If U = 'ES_MULTILINE'       Then ControlStyleFromName := ES_MULTILINE
  Else If U = 'ES_UPPERCASE'       Then ControlStyleFromName := ES_UPPERCASE
  Else If U = 'ES_LOWERCASE'       Then ControlStyleFromName := ES_LOWERCASE
  Else If U = 'ES_PASSWORD'        Then ControlStyleFromName := ES_PASSWORD
  Else If U = 'ES_AUTOVSCROLL'     Then ControlStyleFromName := ES_AUTOVSCROLL
  Else If U = 'ES_AUTOHSCROLL'     Then ControlStyleFromName := ES_AUTOHSCROLL
  Else If U = 'ES_NOHIDESEL'       Then ControlStyleFromName := ES_NOHIDESEL
  Else If U = 'ES_READONLY'        Then ControlStyleFromName := ES_READONLY
  Else If U = 'ES_WANTRETURN'      Then ControlStyleFromName := ES_WANTRETURN
  { Styles de listbox LBS_* }
  Else If U = 'LBS_NOTIFY'         Then ControlStyleFromName := LBS_NOTIFY
  Else If U = 'LBS_SORT'           Then ControlStyleFromName := LBS_SORT
  Else If U = 'LBS_NOREDRAW'       Then ControlStyleFromName := LBS_NOREDRAW
  Else If U = 'LBS_MULTIPLESEL'    Then ControlStyleFromName := LBS_MULTIPLESEL
  Else If U = 'LBS_HASSTRINGS'     Then ControlStyleFromName := LBS_HASSTRINGS
  Else If U = 'LBS_USETABSTOPS'    Then ControlStyleFromName := LBS_USETABSTOPS
  { Styles de combobox CBS_* }
  Else If U = 'CBS_SIMPLE'         Then ControlStyleFromName := CBS_SIMPLE
  Else If U = 'CBS_DROPDOWN'       Then ControlStyleFromName := CBS_DROPDOWN
  Else If U = 'CBS_DROPDOWNLIST'   Then ControlStyleFromName := CBS_DROPDOWNLIST
  Else If U = 'CBS_AUTOHSCROLL'    Then ControlStyleFromName := CBS_AUTOHSCROLL
  Else If U = 'CBS_SORT'           Then ControlStyleFromName := CBS_SORT
  Else If U = 'CBS_HASSTRINGS'     Then ControlStyleFromName := CBS_HASSTRINGS
  { Styles generiques WS_* pour controles }
  Else If U = 'WS_CHILD'           Then ControlStyleFromName := WS_CHILD
  Else If U = 'WS_VISIBLE'         Then ControlStyleFromName := WS_VISIBLE
  Else If U = 'WS_DISABLED'        Then ControlStyleFromName := WS_DISABLED
  Else If U = 'WS_GROUP'           Then ControlStyleFromName := WS_GROUP
  Else If U = 'WS_TABSTOP'         Then ControlStyleFromName := WS_TABSTOP
  Else If U = 'WS_BORDER'          Then ControlStyleFromName := WS_BORDER
  Else If U = 'WS_VSCROLL'         Then ControlStyleFromName := WS_VSCROLL
  Else If U = 'WS_HSCROLL'         Then ControlStyleFromName := WS_HSCROLL;
End;

{ ----- Function IsControlKeyword ----- }
{ Verifie si le token est un mot-cle de controle de dialogue }
Function IsControlKeyword(Const S: TString): Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  IsControlKeyword := (U = 'PUSHBUTTON') Or (U = 'DEFPUSHBUTTON') Or
                     (U = 'CHECKBOX') Or (U = 'AUTOCHECKBOX') Or
                     (U = 'RADIOBUTTON') Or (U = 'AUTORADIOBUTTON') Or
                     (U = 'GROUPBOX') Or (U = 'LTEXT') Or
                     (U = 'RTEXT') Or (U = 'CTEXT') Or
                     (U = 'EDITTEXT') Or (U = 'COMBOBOX') Or
                     (U = 'LISTBOX') Or (U = 'SCROLLBAR') Or
                     (U = 'ICON') Or (U = 'CONTROL') Or
                     (U = 'STATE3') Or (U = 'AUTO3STATE');
End;

{ ----- Procedure InitDialogTemplate ----- }
{ Initialise le template de dialogue }
Procedure InitDialogTemplate;
Begin
  DialogTemplate.Style    := 0;
  DialogTemplate.ExStyle  := 0;
  DialogTemplate.X        := 0;
  DialogTemplate.Y        := 0;
  DialogTemplate.CX       := 0;
  DialogTemplate.CY       := 0;
  DialogTemplate.Menu     := '';
  DialogTemplate.MenuIsId := False;
  DialogTemplate.MenuId   := 0;
  DialogTemplate.DlgClass := '';
  DialogTemplate.ClassIsId:= False;
  DialogTemplate.ClassId  := 0;
  DialogTemplate.Title    := '';
  DialogTemplate.FontName := '';
  DialogTemplate.FontSize := 8;
  DialogTemplate.IsEx     := False;
  DialogCtrlCount := 0;
End;

{ ----- Procedure AddDialogControl ----- }
{ Ajoute un controle a la liste }
Procedure AddDialogControl(Style, ExStyle: LongInt; X, Y, CX, CY: Integer;
  Id: Word; Const CtrlClass: TString; ClassIsId: Boolean; ClassId: Word;
  Const Text: TString; TextIsId: Boolean; TextId: Word);
Begin
  If DialogCtrlCount < MAX_DIALOG_CTRL Then
  Begin
    Inc(DialogCtrlCount);
    DialogControls[DialogCtrlCount].Style     := Style;
    DialogControls[DialogCtrlCount].ExStyle   := ExStyle;
    DialogControls[DialogCtrlCount].X         := X;
    DialogControls[DialogCtrlCount].Y         := Y;
    DialogControls[DialogCtrlCount].CX        := CX;
    DialogControls[DialogCtrlCount].CY        := CY;
    DialogControls[DialogCtrlCount].Id        := Id;
    DialogControls[DialogCtrlCount].CtrlClass := CtrlClass;
    DialogControls[DialogCtrlCount].ClassIsId := ClassIsId;
    DialogControls[DialogCtrlCount].ClassId   := ClassId;
    DialogControls[DialogCtrlCount].Text      := Text;
    DialogControls[DialogCtrlCount].TextIsId  := TextIsId;
    DialogControls[DialogCtrlCount].TextId    := TextId;
  End;
End;

{ ----- Procedure ParseDialogControl ----- }
{ Parse un controle de dialogue }
Procedure ParseDialogControl;
Var
  CtrlType    : TString;
  CtrlText    : TString;
  CtrlId      : Word;
  CtrlX       : Integer;
  CtrlY       : Integer;
  CtrlCX      : Integer;
  CtrlCY      : Integer;
  CtrlStyle   : LongInt;
  CtrlExStyle : LongInt;
  CtrlClass   : TString;
  ClassIsId   : Boolean;
  ClassId     : Word;
  TextIsId    : Boolean;
  TextId      : Word;
  U           : TString;
Begin
  CtrlType := UpCaseStr(CurrToken.Value);
  NextToken;  { Consommer le mot-cle }
  
  CtrlText    := '';
  CtrlId      := 0;
  CtrlX       := 0;
  CtrlY       := 0;
  CtrlCX      := 0;
  CtrlCY      := 0;
  CtrlStyle   := WS_CHILD Or WS_VISIBLE;
  CtrlExStyle := 0;
  CtrlClass   := '';
  ClassIsId   := False;
  ClassId     := 0;
  TextIsId    := False;
  TextId      := 0;
  
  { Determiner la classe et les styles par defaut selon le type }
  If CtrlType = 'PUSHBUTTON' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_PUSHBUTTON Or WS_TABSTOP;
  End
  Else If CtrlType = 'DEFPUSHBUTTON' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_DEFPUSHBUTTON Or WS_TABSTOP;
  End
  Else If CtrlType = 'CHECKBOX' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_CHECKBOX Or WS_TABSTOP;
  End
  Else If CtrlType = 'AUTOCHECKBOX' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_AUTOCHECKBOX Or WS_TABSTOP;
  End
  Else If CtrlType = 'RADIOBUTTON' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_RADIOBUTTON Or WS_TABSTOP;
  End
  Else If CtrlType = 'AUTORADIOBUTTON' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_AUTORADIOBUTTON Or WS_TABSTOP;
  End
  Else If CtrlType = 'GROUPBOX' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_GROUPBOX;
  End
  Else If CtrlType = 'LTEXT' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_STATIC;
    CtrlStyle := CtrlStyle Or SS_LEFT;
  End
  Else If CtrlType = 'RTEXT' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_STATIC;
    CtrlStyle := CtrlStyle Or SS_RIGHT;
  End
  Else If CtrlType = 'CTEXT' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_STATIC;
    CtrlStyle := CtrlStyle Or SS_CENTER;
  End
  Else If CtrlType = 'ICON' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_STATIC;
    CtrlStyle := CtrlStyle Or SS_ICON;
  End
  Else If CtrlType = 'EDITTEXT' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_EDIT;
    CtrlStyle := CtrlStyle Or ES_LEFT Or WS_BORDER Or WS_TABSTOP;
  End
  Else If CtrlType = 'COMBOBOX' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_COMBOBOX;
    CtrlStyle := CtrlStyle Or CBS_DROPDOWN Or WS_TABSTOP;
  End
  Else If CtrlType = 'LISTBOX' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_LISTBOX;
    CtrlStyle := CtrlStyle Or LBS_NOTIFY Or WS_BORDER Or WS_TABSTOP;
  End
  Else If CtrlType = 'SCROLLBAR' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_SCROLLBAR;
  End
  Else If CtrlType = 'STATE3' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_3STATE Or WS_TABSTOP;
  End
  Else If CtrlType = 'AUTO3STATE' Then
  Begin
    ClassIsId := True;
    ClassId   := DC_BUTTON;
    CtrlStyle := CtrlStyle Or BS_AUTO3STATE Or WS_TABSTOP;
  End
  Else If CtrlType = 'CONTROL' Then
  Begin
    { Format generique CONTROL text, id, class, style, x, y, cx, cy }
    ClassIsId := False;
  End;
  
  { Lire le texte du controle (sauf pour certains types) }
  If (CtrlType <> 'EDITTEXT') And (CtrlType <> 'COMBOBOX') And 
     (CtrlType <> 'LISTBOX') And (CtrlType <> 'SCROLLBAR') Then
  Begin
    If CurrToken.Kind = TK_STRING Then
    Begin
      CtrlText := CurrToken.Value;
      NextToken;
    End
    Else If CurrToken.Kind = TK_NUMBER Then
    Begin
      { Texte est un ID de ressource (ex: pour ICON) }
      TextIsId := True;
      TextId   := StrToInt(CurrToken.Value);
      NextToken;
    End;
    
    { Attendre la virgule }
    If CurrToken.Kind = TK_COMMA Then
      NextToken;
  End;
  
  { Lire l identifiant du controle }
  If CurrToken.Kind = TK_NUMBER Then
    CtrlId := StrToInt(CurrToken.Value)
  Else If CurrToken.Kind = TK_IDENT Then
    CtrlId := ParseExpression;  { Peut etre une constante }
  NextToken;
  
  { Pour CONTROL, lire la classe apres l ID }
  If CtrlType = 'CONTROL' Then
  Begin
    If CurrToken.Kind = TK_COMMA Then
      NextToken;
    If CurrToken.Kind = TK_STRING Then
    Begin
      CtrlClass := CurrToken.Value;
      U := UpCaseStr(CtrlClass);
      { Verifier si c est une classe predefinie }
      If U = 'BUTTON' Then
      Begin
        ClassIsId := True;
        ClassId := DC_BUTTON;
      End
      Else If U = 'EDIT' Then
      Begin
        ClassIsId := True;
        ClassId := DC_EDIT;
      End
      Else If U = 'STATIC' Then
      Begin
        ClassIsId := True;
        ClassId := DC_STATIC;
      End
      Else If U = 'LISTBOX' Then
      Begin
        ClassIsId := True;
        ClassId := DC_LISTBOX;
      End
      Else If U = 'SCROLLBAR' Then
      Begin
        ClassIsId := True;
        ClassId := DC_SCROLLBAR;
      End
      Else If U = 'COMBOBOX' Then
      Begin
        ClassIsId := True;
        ClassId := DC_COMBOBOX;
      End;
      NextToken;
    End;
    
    { Lire le style pour CONTROL }
    If CurrToken.Kind = TK_COMMA Then
      NextToken;
    If CurrToken.Kind = TK_NUMBER Then
    Begin
      CtrlStyle := StrToInt(CurrToken.Value);
      NextToken;
    End
    Else If CurrToken.Kind = TK_IDENT Then
    Begin
      CtrlStyle := WS_CHILD Or WS_VISIBLE;
      While (CurrToken.Kind = TK_IDENT) Or (CurrToken.Kind = TK_PIPE) Do
      Begin
        If CurrToken.Kind = TK_IDENT Then
        Begin
          CtrlStyle := CtrlStyle Or ControlStyleFromName(CurrToken.Value);
          CtrlStyle := CtrlStyle Or DialogStyleFromName(CurrToken.Value);
        End;
        NextToken;
      End;
    End;
  End;
  
  { Lire les coordonnees : x, y, cx, cy }
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    CtrlX := StrToInt(CurrToken.Value);
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    CtrlY := StrToInt(CurrToken.Value);
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    CtrlCX := StrToInt(CurrToken.Value);
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    CtrlCY := StrToInt(CurrToken.Value);
    NextToken;
  End;
  
  { Lire les styles optionnels supplementaires }
  While CurrToken.Kind = TK_COMMA Do
  Begin
    NextToken;
    If CurrToken.Kind = TK_NUMBER Then
    Begin
      CtrlStyle := CtrlStyle Or StrToInt(CurrToken.Value);
      NextToken;
    End
    Else If CurrToken.Kind = TK_IDENT Then
    Begin
      CtrlStyle := CtrlStyle Or ControlStyleFromName(CurrToken.Value);
      CtrlStyle := CtrlStyle Or DialogStyleFromName(CurrToken.Value);
      NextToken;
    End;
    
    While CurrToken.Kind = TK_PIPE Do
    Begin
      NextToken;
      If CurrToken.Kind = TK_IDENT Then
      Begin
        CtrlStyle := CtrlStyle Or ControlStyleFromName(CurrToken.Value);
        CtrlStyle := CtrlStyle Or DialogStyleFromName(CurrToken.Value);
        NextToken;
      End
      Else If CurrToken.Kind = TK_NUMBER Then
      Begin
        CtrlStyle := CtrlStyle Or StrToInt(CurrToken.Value);
        NextToken;
      End;
    End;
  End;
  
  { Ajouter le controle }
  AddDialogControl(CtrlStyle, CtrlExStyle, CtrlX, CtrlY, CtrlCX, CtrlCY,
    CtrlId, CtrlClass, ClassIsId, ClassId, CtrlText, TextIsId, TextId);
End;

{ ----- Procedure ParseDialog ----- }
{ Parse un bloc DIALOG ... BEGIN ... END }
Procedure ParseDialog(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word; IsEx: Boolean);
Var
  DlgX, DlgY, DlgCX, DlgCY : Integer;
  U : TString;
Begin
  { Initialiser le template }
  InitDialogTemplate;
  DialogTemplate.IsEx := IsEx;
  
  { Styles par defaut pour un dialogue }
  DialogTemplate.Style := WS_POPUP Or WS_BORDER Or WS_SYSMENU Or DS_MODALFRAME;
  
  { Lire les coordonnees x, y, cx, cy }
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    DlgX := StrToInt(CurrToken.Value);
    DialogTemplate.X := DlgX;
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    DlgY := StrToInt(CurrToken.Value);
    DialogTemplate.Y := DlgY;
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    DlgCX := StrToInt(CurrToken.Value);
    DialogTemplate.CX := DlgCX;
    NextToken;
  End;
  
  If CurrToken.Kind = TK_COMMA Then
    NextToken;
  If CurrToken.Kind = TK_NUMBER Then
  Begin
    DlgCY := StrToInt(CurrToken.Value);
    DialogTemplate.CY := DlgCY;
    NextToken;
  End;
  
  { Lire les options du dialogue avant BEGIN }
  While (CurrToken.Kind <> TK_BEGIN) And (CurrToken.Kind <> TK_LBRACE) And
        (CurrToken.Kind <> TK_EOF) Do
  Begin
    If CurrToken.Kind = TK_IDENT Then
    Begin
      U := UpCaseStr(CurrToken.Value);
      
      If U = 'STYLE' Then
      Begin
        NextToken;
        DialogTemplate.Style := 0;
        While (CurrToken.Kind = TK_NUMBER) Or (CurrToken.Kind = TK_IDENT) Or
              (CurrToken.Kind = TK_PIPE) Or (CurrToken.Kind = TK_NOT) Do
        Begin
          If CurrToken.Kind = TK_NUMBER Then
            DialogTemplate.Style := DialogTemplate.Style Or StrToInt(CurrToken.Value)
          Else If CurrToken.Kind = TK_IDENT Then
            DialogTemplate.Style := DialogTemplate.Style Or DialogStyleFromName(CurrToken.Value)
          Else If CurrToken.Kind = TK_NOT Then
          Begin
            NextToken;
            If CurrToken.Kind = TK_IDENT Then
              DialogTemplate.Style := DialogTemplate.Style And Not DialogStyleFromName(CurrToken.Value);
          End;
          NextToken;
        End;
      End
      Else If U = 'EXSTYLE' Then
      Begin
        NextToken;
        DialogTemplate.ExStyle := 0;
        While (CurrToken.Kind = TK_NUMBER) Or (CurrToken.Kind = TK_IDENT) Or
              (CurrToken.Kind = TK_PIPE) Do
        Begin
          If CurrToken.Kind = TK_NUMBER Then
            DialogTemplate.ExStyle := DialogTemplate.ExStyle Or StrToInt(CurrToken.Value)
          Else If CurrToken.Kind = TK_IDENT Then
            DialogTemplate.ExStyle := DialogTemplate.ExStyle Or DialogStyleFromName(CurrToken.Value);
          NextToken;
        End;
      End
      Else If U = 'CAPTION' Then
      Begin
        NextToken;
        If CurrToken.Kind = TK_STRING Then
        Begin
          DialogTemplate.Title := CurrToken.Value;
          DialogTemplate.Style := DialogTemplate.Style Or WS_CAPTION;
          NextToken;
        End;
      End
      Else If U = 'FONT' Then
      Begin
        NextToken;
        { Lire la taille de police }
        If CurrToken.Kind = TK_NUMBER Then
        Begin
          DialogTemplate.FontSize := StrToInt(CurrToken.Value);
          NextToken;
        End;
        If CurrToken.Kind = TK_COMMA Then
          NextToken;
        { Lire le nom de la police }
        If CurrToken.Kind = TK_STRING Then
        Begin
          DialogTemplate.FontName := CurrToken.Value;
          DialogTemplate.Style := DialogTemplate.Style Or DS_SETFONT;
          NextToken;
        End;
      End
      Else If U = 'CLASS' Then
      Begin
        NextToken;
        If CurrToken.Kind = TK_STRING Then
        Begin
          DialogTemplate.DlgClass := CurrToken.Value;
          NextToken;
        End
        Else If CurrToken.Kind = TK_NUMBER Then
        Begin
          DialogTemplate.ClassIsId := True;
          DialogTemplate.ClassId := StrToInt(CurrToken.Value);
          NextToken;
        End;
      End
      Else If U = 'MENU' Then
      Begin
        NextToken;
        If CurrToken.Kind = TK_STRING Then
        Begin
          DialogTemplate.Menu := CurrToken.Value;
          NextToken;
        End
        Else If CurrToken.Kind = TK_NUMBER Then
        Begin
          DialogTemplate.MenuIsId := True;
          DialogTemplate.MenuId := StrToInt(CurrToken.Value);
          NextToken;
        End
        Else If CurrToken.Kind = TK_IDENT Then
        Begin
          DialogTemplate.Menu := CurrToken.Value;
          NextToken;
        End;
      End
      Else If U = 'LANGUAGE' Then
      Begin
        NextToken;
        ParseLanguageDirective;
      End
      Else
      Begin
        { Ignorer les options inconnues }
        NextToken;
      End;
    End
    Else
    Begin
      NextToken;
    End;
  End;
  
  { Verifier BEGIN ou accolade }
  If (CurrToken.Kind <> TK_BEGIN) And (CurrToken.Kind <> TK_LBRACE) Then
  Begin
    SyntaxError('BEGIN ou { attendu apres les options du dialogue');
    Exit;
  End;
  NextToken;  { Consommer BEGIN }
  
  { Lire les controles }
  While (CurrToken.Kind <> TK_END) And (CurrToken.Kind <> TK_RBRACE) And
        (CurrToken.Kind <> TK_EOF) Do
  Begin
    If CurrToken.Kind = TK_IDENT Then
    Begin
      If IsControlKeyword(CurrToken.Value) Then
        ParseDialogControl
      Else
        NextToken;  { Ignorer les mots-cles inconnus }
    End
    Else
    Begin
      NextToken;
    End;
  End;
  
  { Consommer END }
  If (CurrToken.Kind = TK_END) Or (CurrToken.Kind = TK_RBRACE) Then
    NextToken;
End;

{ ----- Procedure WriteDialog ----- }
{ Ecrit une ressource dialogue dans le fichier .RES }
Procedure WriteDialog(NameIsId: Boolean; NameId: Word;
  Const NameStr: TString; MemFlags: Word; LangId: Word);
Var
  I         : Integer;
  J         : Integer;
  DataStart : LongInt;
  DataSize  : LongInt;
  ResIdx    : Integer;
  S         : TString;
Begin
  { Enregistrer la ressource dans la table }
  ResIdx := AddResource(True, RT_DIALOG, '', NameIsId, NameId, NameStr,
                       MemFlags, LangId);
  
  { Memoriser la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire l en-tete DLGTEMPLATE }
  { DWORD style }
  WriteDWord(DialogTemplate.Style);
  { DWORD dwExtendedStyle }
  WriteDWord(DialogTemplate.ExStyle);
  { WORD cdit (nombre de controles) }
  WriteWord(DialogCtrlCount);
  { short x }
  WriteWord(DialogTemplate.X);
  { short y }
  WriteWord(DialogTemplate.Y);
  { short cx }
  WriteWord(DialogTemplate.CX);
  { short cy }
  WriteWord(DialogTemplate.CY);
  
  { Menu (sz_Or_Ord) }
  If DialogTemplate.MenuIsId Then
  Begin
    WriteWord($FFFF);
    WriteWord(DialogTemplate.MenuId);
  End
  Else If DialogTemplate.Menu <> '' Then
  Begin
    S := DialogTemplate.Menu;
    For J := 1 To Length(S) Do
      WriteWChar(CharToWChar(S[J]));
    WriteWChar(0);
  End
  Else
    WriteWord(0);  { Pas de menu }
  
  { Classe de fenetre (sz_Or_Ord) }
  If DialogTemplate.ClassIsId Then
  Begin
    WriteWord($FFFF);
    WriteWord(DialogTemplate.ClassId);
  End
  Else If DialogTemplate.DlgClass <> '' Then
  Begin
    S := DialogTemplate.DlgClass;
    For J := 1 To Length(S) Do
      WriteWChar(CharToWChar(S[J]));
    WriteWChar(0);
  End
  Else
    WriteWord(0);  { Classe par defaut }
  
  { Titre (Unicode) }
  S := DialogTemplate.Title;
  For J := 1 To Length(S) Do
    WriteWChar(CharToWChar(S[J]));
  WriteWChar(0);
  
  { Police si DS_SETFONT }
  If (DialogTemplate.Style And DS_SETFONT) <> 0 Then
  Begin
    WriteWord(DialogTemplate.FontSize);
    S := DialogTemplate.FontName;
    For J := 1 To Length(S) Do
      WriteWChar(CharToWChar(S[J]));
    WriteWChar(0);
  End;
  
  { Ecrire chaque controle }
  For I := 1 To DialogCtrlCount Do
  Begin
    { Aligner sur DWORD }
    PadToAlignment(4);
    
    { DLGITEMTEMPLATE }
    { DWORD style }
    WriteDWord(DialogControls[I].Style);
    { DWORD dwExtendedStyle }
    WriteDWord(DialogControls[I].ExStyle);
    { short x }
    WriteWord(DialogControls[I].X);
    { short y }
    WriteWord(DialogControls[I].Y);
    { short cx }
    WriteWord(DialogControls[I].CX);
    { short cy }
    WriteWord(DialogControls[I].CY);
    { WORD id }
    WriteWord(DialogControls[I].Id);
    
    { Classe du controle (sz_Or_Ord) }
    If DialogControls[I].ClassIsId Then
    Begin
      WriteWord($FFFF);
      WriteWord(DialogControls[I].ClassId);
    End
    Else If DialogControls[I].CtrlClass <> '' Then
    Begin
      S := DialogControls[I].CtrlClass;
      For J := 1 To Length(S) Do
        WriteWChar(CharToWChar(S[J]));
      WriteWChar(0);
    End
    Else
    Begin
      WriteWord($FFFF);
      WriteWord(DC_STATIC);  { Par defaut }
    End;
    
    { Texte du controle (sz_Or_Ord) }
    If DialogControls[I].TextIsId Then
    Begin
      WriteWord($FFFF);
      WriteWord(DialogControls[I].TextId);
    End
    Else
    Begin
      S := DialogControls[I].Text;
      For J := 1 To Length(S) Do
        WriteWChar(CharToWChar(S[J]));
      WriteWChar(0);
    End;
    
    { WORD extraCount (toujours 0) }
    WriteWord(0);
  End;
  
  { Calculer la taille des donnees }
  DataSize := GetResPos - DataStart;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l offset dans la table des ressources }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ============================================================
  TODO 15 - COMPILATION VERSIONINFO
  ============================================================ }

{ ----- Forward declarations pour TODO 15 ----- }
Procedure WriteVersionInfo(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; MemFlags : Word; LangId : Word); Forward;

{ ----- Function IsVersionOption ----- }
{ Verifie si le token est une option VERSIONINFO }
Function IsVersionOption(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  IsVersionOption := (U = 'FILEVERSION') Or
                     (U = 'PRODUCTVERSION') Or
                     (U = 'FILEFLAGSMASK') Or
                     (U = 'FILEFLAGS') Or
                     (U = 'FILEOS') Or
                     (U = 'FILETYPE') Or
                     (U = 'FILESUBTYPE');
End;

{ ----- Function VersionFlagFromName ----- }
{ Retourne la valeur d une constante VERSIONINFO }
Function VersionFlagFromName(Const S : TString) : LongInt;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  { Types de fichier VFT_* }
  If U = 'VFT_UNKNOWN'    Then VersionFlagFromName := VFT_UNKNOWN
  Else If U = 'VFT_APP'   Then VersionFlagFromName := VFT_APP
  Else If U = 'VFT_DLL'   Then VersionFlagFromName := VFT_DLL
  Else If U = 'VFT_DRV'   Then VersionFlagFromName := VFT_DRV
  Else If U = 'VFT_FONT'  Then VersionFlagFromName := VFT_FONT
  Else If U = 'VFT_VXD'   Then VersionFlagFromName := VFT_VXD
  Else If U = 'VFT_STATIC_LIB' Then VersionFlagFromName := VFT_STATIC_LIB
  { Sous-types VFT2_* }
  Else If U = 'VFT2_UNKNOWN' Then VersionFlagFromName := VFT2_UNKNOWN
  Else If U = 'VFT2_DRV_PRINTER' Then VersionFlagFromName := VFT2_DRV_PRINTER
  Else If U = 'VFT2_DRV_KEYBOARD' Then VersionFlagFromName := VFT2_DRV_KEYBOARD
  Else If U = 'VFT2_DRV_LANGUAGE' Then VersionFlagFromName := VFT2_DRV_LANGUAGE
  Else If U = 'VFT2_DRV_DISPLAY' Then VersionFlagFromName := VFT2_DRV_DISPLAY
  Else If U = 'VFT2_DRV_MOUSE' Then VersionFlagFromName := VFT2_DRV_MOUSE
  Else If U = 'VFT2_DRV_NETWORK' Then VersionFlagFromName := VFT2_DRV_NETWORK
  Else If U = 'VFT2_DRV_SYSTEM' Then VersionFlagFromName := VFT2_DRV_SYSTEM
  Else If U = 'VFT2_DRV_INSTALLABLE' Then VersionFlagFromName := VFT2_DRV_INSTALLABLE
  Else If U = 'VFT2_DRV_SOUND' Then VersionFlagFromName := VFT2_DRV_SOUND
  Else If U = 'VFT2_DRV_COMM' Then VersionFlagFromName := VFT2_DRV_COMM
  Else If U = 'VFT2_FONT_RASTER' Then VersionFlagFromName := VFT2_FONT_RASTER
  Else If U = 'VFT2_FONT_VECTOR' Then VersionFlagFromName := VFT2_FONT_VECTOR
  Else If U = 'VFT2_FONT_TRUETYPE' Then VersionFlagFromName := VFT2_FONT_TRUETYPE
  { OS cibles VOS_* }
  Else If U = 'VOS_UNKNOWN' Then VersionFlagFromName := VOS_UNKNOWN
  Else If U = 'VOS_DOS'   Then VersionFlagFromName := VOS_DOS
  Else If U = 'VOS_OS216' Then VersionFlagFromName := VOS_OS216
  Else If U = 'VOS_OS232' Then VersionFlagFromName := VOS_OS232
  Else If U = 'VOS_NT'    Then VersionFlagFromName := VOS_NT
  Else If U = 'VOS__WINDOWS16' Then VersionFlagFromName := VOS__WINDOWS16
  Else If U = 'VOS__PM16' Then VersionFlagFromName := VOS__PM16
  Else If U = 'VOS__PM32' Then VersionFlagFromName := VOS__PM32
  Else If U = 'VOS__WINDOWS32' Then VersionFlagFromName := VOS__WINDOWS32
  Else If U = 'VOS_DOS_WINDOWS16' Then VersionFlagFromName := VOS_DOS_WINDOWS16
  Else If U = 'VOS_DOS_WINDOWS32' Then VersionFlagFromName := VOS_DOS_WINDOWS32
  Else If U = 'VOS_OS216_PM16' Then VersionFlagFromName := VOS_OS216_PM16
  Else If U = 'VOS_OS232_PM32' Then VersionFlagFromName := VOS_OS232_PM32
  Else If U = 'VOS_NT_WINDOWS32' Then VersionFlagFromName := VOS_NT_WINDOWS32
  { Drapeaux VS_FF_* }
  Else If U = 'VS_FF_DEBUG' Then VersionFlagFromName := VS_FF_DEBUG
  Else If U = 'VS_FF_PRERELEASE' Then VersionFlagFromName := VS_FF_PRERELEASE
  Else If U = 'VS_FF_PATCHED' Then VersionFlagFromName := VS_FF_PATCHED
  Else If U = 'VS_FF_PRIVATEBUILD' Then VersionFlagFromName := VS_FF_PRIVATEBUILD
  Else If U = 'VS_FF_INFOINFERRED' Then VersionFlagFromName := VS_FF_INFOINFERRED
  Else If U = 'VS_FF_SPECIALBUILD' Then VersionFlagFromName := VS_FF_SPECIALBUILD
  Else If U = 'VS_FFI_FILEFLAGSMASK' Then VersionFlagFromName := VS_FFI_FILEFLAGSMASK
  Else VersionFlagFromName := 0;
End;

{ ----- Procedure InitVersionInfo ----- }
{ Initialise la structure VersionInfo avec des valeurs par defaut }
Procedure InitVersionInfo;
Begin
  VersionInfo.FileVersionMS := 0;
  VersionInfo.FileVersionLS := 0;
  VersionInfo.ProductVersionMS := 0;
  VersionInfo.ProductVersionLS := 0;
  VersionInfo.FileFlagsMask := VS_FFI_FILEFLAGSMASK;
  VersionInfo.FileFlags := 0;
  VersionInfo.FileOS := VOS_NT_WINDOWS32;
  VersionInfo.FileType := VFT_APP;
  VersionInfo.FileSubtype := VFT2_UNKNOWN;
  VersionInfo.StringCount := 0;
  VersionInfo.TranslationLang := $0409;  { Anglais US par defaut }
  VersionInfo.TranslationCP := $04B0;    { Unicode }
End;

{ ----- Procedure AddVersionString ----- }
{ Ajoute une paire cle/valeur a VersionInfo }
Procedure AddVersionString(Const Key, Value : TString);
Begin
  If VersionInfo.StringCount < MAX_VERSION_STRINGS Then
  Begin
    Inc(VersionInfo.StringCount);
    VersionInfo.StringValues[VersionInfo.StringCount].Key := Key;
    VersionInfo.StringValues[VersionInfo.StringCount].Value := Value;
  End;
End;

{ ----- Function ParseVersionExpression ----- }
{ Parse une expression pour VERSIONINFO (nombre, constante, ou combinaison) }
Function ParseVersionExpression : LongInt;
Var
  Result : LongInt;
  Val    : LongInt;
  Tok    : TToken;
  Done   : Boolean;
Begin
  Result := 0;
  Done := False;
  
  While Not Done Do
  Begin
    Tok := CurrToken;
    If Tok.Kind = TK_NUMBER Then
    Begin
      Result := Result Or Tok.IntVal;
      NextToken;
    End
    Else If Tok.Kind = TK_IDENT Then
    Begin
      Val := VersionFlagFromName(Tok.Value);
      Result := Result Or Val;
      NextToken;
    End
    Else
      Done := True;
    
    { Verifier si on continue avec | }
    If (CurrToken.Kind = TK_PIPE) Then
      NextToken
    Else
      Done := True;
  End;
  
  ParseVersionExpression := Result;
End;

{ ----- Procedure ParseVersionInfoBlock ----- }
{ Parse le contenu d un bloc VERSIONINFO }
Procedure ParseVersionInfoBlock;
Var
  Tok    : TToken;
  InBlock : Boolean;
  Key    : TString;
  Value  : TString;
  BlockName : TString;
  CodePage  : TString;
Begin
  InBlock := True;
  
  While InBlock Do
  Begin
    Tok := CurrToken;
    
    If Tok.Kind = TK_EOF Then
      InBlock := False
    Else If (Tok.Kind = TK_IDENT) And (UpCaseStr(Tok.Value) = 'END') Then
    Begin
      NextToken;
      InBlock := False;
    End
    Else If (Tok.Kind = TK_IDENT) And (UpCaseStr(Tok.Value) = 'BLOCK') Then
    Begin
      NextToken;  { Passer BLOCK }
      
      { Lire le nom du bloc entre guillemets }
      If CurrToken.Kind = TK_STRING Then
      Begin
        BlockName := UpCaseStr(CurrToken.Value);
        NextToken;
        
        { Chercher BEGIN }
        While (CurrToken.Kind <> TK_EOF) And
              Not ((CurrToken.Kind = TK_IDENT) And 
                   ((UpCaseStr(CurrToken.Value) = 'BEGIN') Or
                    (CurrToken.Value = '{'))) Do
          NextToken;
        
        If CurrToken.Kind <> TK_EOF Then
          NextToken;  { Passer BEGIN ou { }
        
        If BlockName = 'STRINGFILEINFO' Then
        Begin
          { Parser StringFileInfo - contient un bloc avec code page }
          While (CurrToken.Kind <> TK_EOF) And
                Not ((CurrToken.Kind = TK_IDENT) And 
                     (UpCaseStr(CurrToken.Value) = 'END')) Do
          Begin
            If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'BLOCK') Then
            Begin
              NextToken;
              If CurrToken.Kind = TK_STRING Then
              Begin
                CodePage := CurrToken.Value;  { Ex: "040904B0" }
                { Extraire langue et code page }
                If Length(CodePage) >= 8 Then
                Begin
                  VersionInfo.TranslationLang := StrToInt('$' + Copy(CodePage, 1, 4));
                  VersionInfo.TranslationCP := StrToInt('$' + Copy(CodePage, 5, 4));
                End;
                NextToken;
              End;
              
              { Chercher BEGIN du bloc code page }
              While (CurrToken.Kind <> TK_EOF) And
                    Not ((CurrToken.Kind = TK_IDENT) And 
                         ((UpCaseStr(CurrToken.Value) = 'BEGIN') Or
                          (CurrToken.Value = '{'))) Do
                NextToken;
              
              If CurrToken.Kind <> TK_EOF Then
                NextToken;
              
              { Parser les VALUE }
              While (CurrToken.Kind <> TK_EOF) And
                    Not ((CurrToken.Kind = TK_IDENT) And 
                         (UpCaseStr(CurrToken.Value) = 'END')) Do
              Begin
                If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'VALUE') Then
                Begin
                  NextToken;
                  If CurrToken.Kind = TK_STRING Then
                  Begin
                    Key := CurrToken.Value;
                    NextToken;
                    If CurrToken.Kind = TK_COMMA Then
                      NextToken;
                    If CurrToken.Kind = TK_STRING Then
                    Begin
                      Value := CurrToken.Value;
                      AddVersionString(Key, Value);
                      NextToken;
                    End;
                  End;
                End
                Else
                  NextToken;
              End;
              
              If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'END') Then
                NextToken;  { Fin du bloc code page }
            End
            Else
              NextToken;
          End;
          
          If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'END') Then
            NextToken;  { Fin StringFileInfo }
        End
        Else If BlockName = 'VARFILEINFO' Then
        Begin
          { Parser VarFileInfo - contient VALUE "Translation", lang, cp }
          While (CurrToken.Kind <> TK_EOF) And
                Not ((CurrToken.Kind = TK_IDENT) And 
                     (UpCaseStr(CurrToken.Value) = 'END')) Do
          Begin
            If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'VALUE') Then
            Begin
              NextToken;
              If (CurrToken.Kind = TK_STRING) And (UpCaseStr(CurrToken.Value) = 'TRANSLATION') Then
              Begin
                NextToken;
                If CurrToken.Kind = TK_COMMA Then
                  NextToken;
                If CurrToken.Kind = TK_NUMBER Then
                Begin
                  VersionInfo.TranslationLang := CurrToken.IntVal;
                  NextToken;
                  If CurrToken.Kind = TK_COMMA Then
                    NextToken;
                  If CurrToken.Kind = TK_NUMBER Then
                  Begin
                    VersionInfo.TranslationCP := CurrToken.IntVal;
                    NextToken;
                  End;
                End;
              End
              Else
                NextToken;
            End
            Else
              NextToken;
          End;
          
          If (CurrToken.Kind = TK_IDENT) And (UpCaseStr(CurrToken.Value) = 'END') Then
            NextToken;  { Fin VarFileInfo }
        End
        Else
        Begin
          { Bloc inconnu - sauter jusqu'au END correspondant }
          While (CurrToken.Kind <> TK_EOF) And
                Not ((CurrToken.Kind = TK_IDENT) And 
                     (UpCaseStr(CurrToken.Value) = 'END')) Do
            NextToken;
          If CurrToken.Kind <> TK_EOF Then
            NextToken;
        End;
      End;
    End
    Else
      NextToken;  { Passer les tokens inconnus }
  End;
End;

{ ----- Procedure ParseVersionInfo ----- }
{ Parse le bloc VERSIONINFO complet }
Procedure ParseVersionInfo(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; MemFlags : Word);
Var
  Tok   : TToken;
  TokUp : TString;
  V1, V2, V3, V4 : LongInt;
Begin
  { Initialiser la structure }
  InitVersionInfo;
  
  { Parser les options avant BEGIN }
  While (CurrToken.Kind <> TK_EOF) And
        Not ((CurrToken.Kind = TK_IDENT) And 
             ((UpCaseStr(CurrToken.Value) = 'BEGIN') Or
              (CurrToken.Value = '{'))) Do
  Begin
    Tok := CurrToken;
    If Tok.Kind = TK_IDENT Then
    Begin
      TokUp := UpCaseStr(Tok.Value);
      
      If TokUp = 'FILEVERSION' Then
      Begin
        NextToken;
        V1 := 0; V2 := 0; V3 := 0; V4 := 0;
        If CurrToken.Kind = TK_NUMBER Then
        Begin
          V1 := CurrToken.IntVal;
          NextToken;
          If CurrToken.Kind = TK_COMMA Then NextToken;
          If CurrToken.Kind = TK_NUMBER Then
          Begin
            V2 := CurrToken.IntVal;
            NextToken;
            If CurrToken.Kind = TK_COMMA Then NextToken;
            If CurrToken.Kind = TK_NUMBER Then
            Begin
              V3 := CurrToken.IntVal;
              NextToken;
              If CurrToken.Kind = TK_COMMA Then NextToken;
              If CurrToken.Kind = TK_NUMBER Then
              Begin
                V4 := CurrToken.IntVal;
                NextToken;
              End;
            End;
          End;
        End;
        VersionInfo.FileVersionMS := (V1 Shl 16) Or V2;
        VersionInfo.FileVersionLS := (V3 Shl 16) Or V4;
      End
      Else If TokUp = 'PRODUCTVERSION' Then
      Begin
        NextToken;
        V1 := 0; V2 := 0; V3 := 0; V4 := 0;
        If CurrToken.Kind = TK_NUMBER Then
        Begin
          V1 := CurrToken.IntVal;
          NextToken;
          If CurrToken.Kind = TK_COMMA Then NextToken;
          If CurrToken.Kind = TK_NUMBER Then
          Begin
            V2 := CurrToken.IntVal;
            NextToken;
            If CurrToken.Kind = TK_COMMA Then NextToken;
            If CurrToken.Kind = TK_NUMBER Then
            Begin
              V3 := CurrToken.IntVal;
              NextToken;
              If CurrToken.Kind = TK_COMMA Then NextToken;
              If CurrToken.Kind = TK_NUMBER Then
              Begin
                V4 := CurrToken.IntVal;
                NextToken;
              End;
            End;
          End;
        End;
        VersionInfo.ProductVersionMS := (V1 Shl 16) Or V2;
        VersionInfo.ProductVersionLS := (V3 Shl 16) Or V4;
      End
      Else If TokUp = 'FILEFLAGSMASK' Then
      Begin
        NextToken;
        VersionInfo.FileFlagsMask := ParseVersionExpression;
      End
      Else If TokUp = 'FILEFLAGS' Then
      Begin
        NextToken;
        VersionInfo.FileFlags := ParseVersionExpression;
      End
      Else If TokUp = 'FILEOS' Then
      Begin
        NextToken;
        VersionInfo.FileOS := ParseVersionExpression;
      End
      Else If TokUp = 'FILETYPE' Then
      Begin
        NextToken;
        VersionInfo.FileType := ParseVersionExpression;
      End
      Else If TokUp = 'FILESUBTYPE' Then
      Begin
        NextToken;
        VersionInfo.FileSubtype := ParseVersionExpression;
      End
      Else
        NextToken;
    End
    Else
      NextToken;
  End;
  
  { Passer BEGIN ou { }
  If (CurrToken.Kind = TK_IDENT) Or (CurrToken.Value = '{') Then
    NextToken;
  
  { Parser le contenu du bloc }
  ParseVersionInfoBlock;
  
  { Ecrire la ressource }
  WriteVersionInfo(NameIsId, NameId, NameStr, MemFlags, CurrentLangId);
End;

{ ----- Procedure WriteVersionInfoString ----- }
{ Ecrit un bloc String (cle, valeur) aligne }
Procedure WriteVersionInfoString(Const Key, Value : TString);
Var
  BlockStart, BlockLen : LongInt;
  ValLen : Integer;
  I : Integer;
Begin
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  { Memoriser la position de debut }
  BlockStart := GetResPos;
  
  { Calculer la longueur de la valeur }
  ValLen := Length(Value) + 1;  { +1 pour le null terminator }
  
  { WORD wLength - sera mis a jour }
  WriteWord(0);
  { WORD wValueLength - taille de la valeur en WORDs }
  WriteWord(ValLen);
  { WORD wType = 1 (texte) }
  WriteWord(1);
  
  { szKey - nom de la cle en Unicode }
  For I := 1 To Length(Key) Do
    WriteWChar(CharToWChar(Key[I]));
  WriteWChar(0);  { Null terminator }
  
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  { Value - valeur en Unicode }
  For I := 1 To Length(Value) Do
    WriteWChar(CharToWChar(Value[I]));
  WriteWChar(0);  { Null terminator }
  
  { Calculer et mettre a jour la taille du bloc }
  BlockLen := GetResPos - BlockStart;
  SeekResPos(BlockStart);
  WriteWord(BlockLen);
  SeekResPos(BlockStart + BlockLen);
End;

{ ----- Procedure WriteVersionInfo ----- }
{ Ecrit une ressource VERSIONINFO complete }
Procedure WriteVersionInfo(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; MemFlags : Word; LangId : Word);
Var
  ResIdx      : Integer;
  DataStart   : LongInt;
  DataSize    : LongInt;
  VerInfoStart: LongInt;
  VerInfoLen  : LongInt;
  SFIStart    : LongInt;
  SFILen      : LongInt;
  STStart     : LongInt;
  STLen       : LongInt;
  VFIStart    : LongInt;
  VFILen      : LongInt;
  TransStart  : LongInt;
  TransLen    : LongInt;
  I           : Integer;
  S           : TString;
  LangCP      : TString;
Begin
  { Ajouter a la table des ressources }
  ResIdx := AddResource(True, RT_VERSION, '',
                        NameIsId, NameId, NameStr, MemFlags, LangId);
  
  { Ecrire l en-tete de ressource 32 bits }
  WriteResHeader32(True, RT_VERSION, '',
                   NameIsId, NameId, NameStr, 0, MemFlags, LangId);
  
  { Memoriser la position de debut des donnees }
  DataStart := GetResPos;
  
  { ===== VS_VERSIONINFO ===== }
  VerInfoStart := GetResPos;
  
  { WORD wLength - sera mis a jour a la fin }
  WriteWord(0);
  { WORD wValueLength = 52 (taille de VS_FIXEDFILEINFO) }
  WriteWord(52);
  { WORD wType = 0 (binaire) }
  WriteWord(0);
  
  { szKey = "VS_VERSION_INFO" en Unicode }
  S := 'VS_VERSION_INFO';
  For I := 1 To Length(S) Do
    WriteWChar(CharToWChar(S[I]));
  WriteWChar(0);  { Null terminator }
  
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  { ===== VS_FIXEDFILEINFO (52 octets) ===== }
  { DWORD dwSignature - ecrit en deux WORDs pour eviter overflow }
  WriteWord(VS_FFI_SIGNATURE_LO);
  WriteWord(VS_FFI_SIGNATURE_HI);
  { DWORD dwStrucVersion }
  WriteDWord(VS_FFI_STRUCVERSION);
  { DWORD dwFileVersionMS }
  WriteDWord(VersionInfo.FileVersionMS);
  { DWORD dwFileVersionLS }
  WriteDWord(VersionInfo.FileVersionLS);
  { DWORD dwProductVersionMS }
  WriteDWord(VersionInfo.ProductVersionMS);
  { DWORD dwProductVersionLS }
  WriteDWord(VersionInfo.ProductVersionLS);
  { DWORD dwFileFlagsMask }
  WriteDWord(VersionInfo.FileFlagsMask);
  { DWORD dwFileFlags }
  WriteDWord(VersionInfo.FileFlags);
  { DWORD dwFileOS }
  WriteDWord(VersionInfo.FileOS);
  { DWORD dwFileType }
  WriteDWord(VersionInfo.FileType);
  { DWORD dwFileSubtype }
  WriteDWord(VersionInfo.FileSubtype);
  { DWORD dwFileDateMS }
  WriteDWord(0);
  { DWORD dwFileDateLS }
  WriteDWord(0);
  
  { ===== StringFileInfo ===== }
  If VersionInfo.StringCount > 0 Then
  Begin
    { Aligner sur DWORD }
    PadToAlignment(4);
    
    SFIStart := GetResPos;
    
    { WORD wLength - sera mis a jour }
    WriteWord(0);
    { WORD wValueLength = 0 }
    WriteWord(0);
    { WORD wType = 1 (texte) }
    WriteWord(1);
    
    { szKey = "StringFileInfo" en Unicode }
    S := 'StringFileInfo';
    For I := 1 To Length(S) Do
      WriteWChar(CharToWChar(S[I]));
    WriteWChar(0);
    
    { Aligner sur DWORD }
    PadToAlignment(4);
    
    { ===== StringTable ===== }
    STStart := GetResPos;
    
    { WORD wLength - sera mis a jour }
    WriteWord(0);
    { WORD wValueLength = 0 }
    WriteWord(0);
    { WORD wType = 1 (texte) }
    WriteWord(1);
    
    { szKey = "hhhhHHHH" (langue + codepage) en Unicode }
    LangCP := HexWord(VersionInfo.TranslationLang) + 
              HexWord(VersionInfo.TranslationCP);
    For I := 1 To Length(LangCP) Do
      WriteWChar(CharToWChar(LangCP[I]));
    WriteWChar(0);
    
    { Aligner sur DWORD }
    PadToAlignment(4);
    
    { Ecrire chaque paire String (cle, valeur) }
    For I := 1 To VersionInfo.StringCount Do
      WriteVersionInfoString(VersionInfo.StringValues[I].Key,
                             VersionInfo.StringValues[I].Value);
    
    { Mettre a jour la taille de StringTable }
    STLen := GetResPos - STStart;
    SeekResPos(STStart);
    WriteWord(STLen);
    SeekResPos(STStart + STLen);
    
    { Mettre a jour la taille de StringFileInfo }
    SFILen := GetResPos - SFIStart;
    SeekResPos(SFIStart);
    WriteWord(SFILen);
    SeekResPos(SFIStart + SFILen);
  End;
  
  { ===== VarFileInfo ===== }
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  VFIStart := GetResPos;
  
  { WORD wLength - sera mis a jour }
  WriteWord(0);
  { WORD wValueLength = 0 }
  WriteWord(0);
  { WORD wType = 1 (texte) }
  WriteWord(1);
  
  { szKey = "VarFileInfo" en Unicode }
  S := 'VarFileInfo';
  For I := 1 To Length(S) Do
    WriteWChar(CharToWChar(S[I]));
  WriteWChar(0);
  
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  { ===== Var (Translation) ===== }
  TransStart := GetResPos;
  
  { WORD wLength - sera mis a jour }
  WriteWord(0);
  { WORD wValueLength = 4 (taille de Translation) }
  WriteWord(4);
  { WORD wType = 0 (binaire) }
  WriteWord(0);
  
  { szKey = "Translation" en Unicode }
  S := 'Translation';
  For I := 1 To Length(S) Do
    WriteWChar(CharToWChar(S[I]));
  WriteWChar(0);
  
  { Aligner sur DWORD }
  PadToAlignment(4);
  
  { Value = WORD langID, WORD codepage }
  WriteWord(VersionInfo.TranslationLang);
  WriteWord(VersionInfo.TranslationCP);
  
  { Mettre a jour la taille de Var (Translation) }
  TransLen := GetResPos - TransStart;
  SeekResPos(TransStart);
  WriteWord(TransLen);
  SeekResPos(TransStart + TransLen);
  
  { Mettre a jour la taille de VarFileInfo }
  VFILen := GetResPos - VFIStart;
  SeekResPos(VFIStart);
  WriteWord(VFILen);
  SeekResPos(VFIStart + VFILen);
  
  { Mettre a jour la taille totale de VS_VERSIONINFO }
  VerInfoLen := GetResPos - VerInfoStart;
  SeekResPos(VerInfoStart);
  WriteWord(VerInfoLen);
  SeekResPos(VerInfoStart + VerInfoLen);
  
  { Calculer la taille des donnees }
  DataSize := GetResPos - DataStart;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l offset dans la table des ressources }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ============================================================
  TODO 16 - COMPILATION ICON/CURSOR
  ============================================================ }

{ ----- Procedure InitIconCursor ----- }
Procedure InitIconCursor;
Begin
  NextIconId   := 1;
  NextCursorId := 1;
  IconCount    := 0;
End;

{ ----- Procedure ClearIconData ----- }
Procedure ClearIconData;
Var
  I : Integer;
Begin
  For I := 1 To IconCount Do
  Begin
    If IconData[I] <> Nil Then
    Begin
      FreeMem(IconData[I], IconDataSizes[I]);
      IconData[I] := Nil;
    End;
  End;
  IconCount := 0;
End;

{ ----- Function LoadIconFile ----- }
Function LoadIconFile(Const FileName : TString) : Boolean;
Var
  F         : File;
  Reserved  : Word;
  ResType   : Word;
  ImageCount: Word;
  I         : Integer;
  Entry     : TIconDirEntry;
  Buffer    : Pointer;
Begin
  LoadIconFile := False;
  ClearIconData;
  
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('RC: Erreur: Impossible d''ouvrir le fichier ', FileName);
    Exit;
  End;
  
  { Lire l'en-tete du fichier ICO/CUR (6 octets) }
  { WORD Reserved = 0, WORD Type = 1 (ICO) ou 2 (CUR), WORD Count }
  BlockRead(F, Reserved, 2);
  BlockRead(F, ResType, 2);
  BlockRead(F, ImageCount, 2);
  
  If (Reserved <> 0) Or ((ResType <> 1) And (ResType <> 2)) Then
  Begin
    WriteLn('RC: Erreur: Format de fichier icone/curseur invalide');
    Close(F);
    Exit;
  End;
  
  If ImageCount > MAX_ICON_ENTRIES Then
    ImageCount := MAX_ICON_ENTRIES;
  
  IconCount := ImageCount;
  
  { Lire le repertoire des images (16 octets par entree) }
  For I := 1 To IconCount Do
  Begin
    BlockRead(F, Entry.Width, 1);
    BlockRead(F, Entry.Height, 1);
    BlockRead(F, Entry.ColorCount, 1);
    BlockRead(F, Entry.Reserved, 1);
    BlockRead(F, Entry.Planes, 2);
    BlockRead(F, Entry.BitCount, 2);
    BlockRead(F, Entry.BytesInRes, 4);
    BlockRead(F, Entry.ImageOffset, 4);
    IconEntries[I] := Entry;
    IconData[I] := Nil;
    IconDataSizes[I] := Entry.BytesInRes;
  End;
  
  { Lire les donnees de chaque image }
  For I := 1 To IconCount Do
  Begin
    If IconDataSizes[I] > 0 Then
    Begin
      GetMem(Buffer, IconDataSizes[I]);
      Seek(F, IconEntries[I].ImageOffset);
      BlockRead(F, Buffer^, IconDataSizes[I]);
      IconData[I] := Buffer;
    End;
  End;
  
  Close(F);
  LoadIconFile := True;
End;

{ ----- Function LoadCursorFile ----- }
Function LoadCursorFile(Const FileName : TString) : Boolean;
Begin
  { Les fichiers .CUR ont le meme format que .ICO }
  { La seule difference est ResType = 2 et Planes/BitCount = hotspot X/Y }
  LoadCursorFile := LoadIconFile(FileName);
End;

{ ----- Procedure WriteIconResource ----- }
Procedure WriteIconResource(IconId : Word; DataPtr : Pointer;
  DataSize : LongInt; MemFlags : Word; LangId : Word);
Var
  ResIdx    : Integer;
  DataStart : LongInt;
Begin
  { Ajouter a la table des ressources }
  ResIdx := AddResource(True, RT_ICON, '', True, IconId, '', MemFlags, LangId);
  
  { Ecrire l'en-tete }
  If Opts.Output32 Then
    WriteResHeader32(True, RT_ICON, '', True, IconId, '', DataSize, MemFlags, LangId)
  Else
    WriteResHeader16(RT_ICON, IconId, DataSize, MemFlags);
  
  { Enregistrer la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire les donnees de l'icone (donnees DIB) }
  WriteBytesFromPtr(DataPtr, DataSize);
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l'offset }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ----- Procedure WriteCursorResource ----- }
Procedure WriteCursorResource(CursorId : Word; DataPtr : Pointer;
  DataSize : LongInt; HotspotX, HotspotY : Word; MemFlags : Word; LangId : Word);
Var
  ResIdx      : Integer;
  DataStart   : LongInt;
  TotalSize   : LongInt;
Begin
  { Pour les curseurs, on doit ajouter un en-tete de 4 octets (hotspot) }
  TotalSize := DataSize + 4;
  
  { Ajouter a la table des ressources }
  ResIdx := AddResource(True, RT_CURSOR, '', True, CursorId, '', MemFlags, LangId);
  
  { Ecrire l'en-tete }
  If Opts.Output32 Then
    WriteResHeader32(True, RT_CURSOR, '', True, CursorId, '', TotalSize, MemFlags, LangId)
  Else
    WriteResHeader16(RT_CURSOR, CursorId, TotalSize, MemFlags);
  
  { Enregistrer la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire le hotspot (2 WORDs) }
  WriteWord(HotspotX);
  WriteWord(HotspotY);
  
  { Ecrire les donnees du curseur (donnees DIB) }
  WriteBytesFromPtr(DataPtr, DataSize);
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l'offset }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, TotalSize);
End;

{ ----- Procedure WriteGroupIconHeader ----- }
Procedure WriteGroupIconHeader(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; Const GrpEntries : Array Of TGrpIconDirEntry;
  GrpCount : Integer; MemFlags : Word; LangId : Word);
Var
  ResIdx    : Integer;
  DataStart : LongInt;
  DataSize  : LongInt;
  I         : Integer;
Begin
  { Calculer la taille des donnees :
    6 octets pour l'en-tete + 14 octets par entree }
  DataSize := 6 + (GrpCount * 14);
  
  { Ajouter a la table des ressources }
  ResIdx := AddResource(True, RT_GROUP_ICON, '', NameIsId, NameId, NameStr, 
                        MemFlags, LangId);
  
  { Ecrire l'en-tete }
  If Opts.Output32 Then
    WriteResHeader32(True, RT_GROUP_ICON, '', NameIsId, NameId, NameStr, 
                     DataSize, MemFlags, LangId)
  Else
    WriteResHeader16(RT_GROUP_ICON, NameId, DataSize, MemFlags);
  
  { Enregistrer la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire l'en-tete du groupe (GRPICONDIR) }
  { WORD Reserved = 0 }
  WriteWord(0);
  { WORD ResType = 1 (ICON) }
  WriteWord(1);
  { WORD Count }
  WriteWord(GrpCount);
  
  { Ecrire chaque entree (GRPICONDIRENTRY) }
  For I := 0 To GrpCount - 1 Do
  Begin
    WriteByte(GrpEntries[I].Width);
    WriteByte(GrpEntries[I].Height);
    WriteByte(GrpEntries[I].ColorCount);
    WriteByte(GrpEntries[I].Reserved);
    WriteWord(GrpEntries[I].Planes);
    WriteWord(GrpEntries[I].BitCount);
    WriteDWord(GrpEntries[I].BytesInRes);
    WriteWord(GrpEntries[I].Id);
  End;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l'offset }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ----- Procedure WriteGroupCursorHeader ----- }
Procedure WriteGroupCursorHeader(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; Const GrpEntries : Array Of TGrpIconDirEntry;
  GrpCount : Integer; MemFlags : Word; LangId : Word);
Var
  ResIdx    : Integer;
  DataStart : LongInt;
  DataSize  : LongInt;
  I         : Integer;
Begin
  { Calculer la taille des donnees :
    6 octets pour l'en-tete + 14 octets par entree }
  DataSize := 6 + (GrpCount * 14);
  
  { Ajouter a la table des ressources }
  ResIdx := AddResource(True, RT_GROUP_CURSOR, '', NameIsId, NameId, NameStr, 
                        MemFlags, LangId);
  
  { Ecrire l'en-tete }
  If Opts.Output32 Then
    WriteResHeader32(True, RT_GROUP_CURSOR, '', NameIsId, NameId, NameStr, 
                     DataSize, MemFlags, LangId)
  Else
    WriteResHeader16(RT_GROUP_CURSOR, NameId, DataSize, MemFlags);
  
  { Enregistrer la position de debut des donnees }
  DataStart := GetResPos;
  
  { Ecrire l'en-tete du groupe (GRPCURSORDIR) }
  { WORD Reserved = 0 }
  WriteWord(0);
  { WORD ResType = 2 (CURSOR) }
  WriteWord(2);
  { WORD Count }
  WriteWord(GrpCount);
  
  { Ecrire chaque entree (GRPCURSORDIRENTRY) }
  For I := 0 To GrpCount - 1 Do
  Begin
    { Pour les curseurs, Width et Height sont des WORDs }
    WriteWord(GrpEntries[I].Width);
    WriteWord(GrpEntries[I].Height);
    WriteWord(GrpEntries[I].Planes);
    WriteWord(GrpEntries[I].BitCount);
    WriteDWord(GrpEntries[I].BytesInRes + 4); { +4 pour le hotspot }
    WriteWord(GrpEntries[I].Id);
  End;
  
  { Aligner sur 4 octets }
  PadToAlignment(4);
  
  { Mettre a jour la taille et l'offset }
  SetResourceDataOfs(ResIdx, DataStart);
  SetResourceDataSize(ResIdx, DataSize);
End;

{ ----- Procedure WriteIcon ----- }
Procedure WriteIcon(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; Const FileName : TString;
  MemFlags : Word; LangId : Word);
Var
  I          : Integer;
  GrpEntries : Array[0..MAX_ICON_ENTRIES-1] Of TGrpIconDirEntry;
  IconIds    : Array[1..MAX_ICON_ENTRIES] Of Word;
Begin
  { Charger le fichier icone }
  If Not LoadIconFile(FileName) Then
  Begin
    FatalError('Impossible de charger le fichier icone: ' + FileName);
    Exit;
  End;
  
  If IconCount = 0 Then
  Begin
    FatalError('Fichier icone vide ou invalide: ' + FileName);
    Exit;
  End;
  
  { Ecrire chaque image comme ressource RT_ICON individuelle }
  For I := 1 To IconCount Do
  Begin
    IconIds[I] := NextIconId;
    WriteIconResource(NextIconId, IconData[I], IconDataSizes[I], MemFlags, LangId);
    Inc(NextIconId);
  End;
  
  { Creer les entrees pour le groupe }
  For I := 1 To IconCount Do
  Begin
    GrpEntries[I-1].Width      := IconEntries[I].Width;
    GrpEntries[I-1].Height     := IconEntries[I].Height;
    GrpEntries[I-1].ColorCount := IconEntries[I].ColorCount;
    GrpEntries[I-1].Reserved   := 0;
    GrpEntries[I-1].Planes     := IconEntries[I].Planes;
    GrpEntries[I-1].BitCount   := IconEntries[I].BitCount;
    GrpEntries[I-1].BytesInRes := IconEntries[I].BytesInRes;
    GrpEntries[I-1].Id         := IconIds[I];
  End;
  
  { Ecrire la ressource RT_GROUP_ICON }
  WriteGroupIconHeader(NameIsId, NameId, NameStr, GrpEntries, IconCount, 
                       MemFlags, LangId);
  
  { Liberer les donnees }
  ClearIconData;
  
  If Opts.Verbose Then
    WriteLn('  ICON ', FileName, ' -> ', IconCount, ' image(s)');
End;

{ ----- Procedure WriteCursor ----- }
Procedure WriteCursor(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; Const FileName : TString;
  MemFlags : Word; LangId : Word);
Var
  I          : Integer;
  GrpEntries : Array[0..MAX_ICON_ENTRIES-1] Of TGrpIconDirEntry;
  CursorIds  : Array[1..MAX_ICON_ENTRIES] Of Word;
  HotspotX   : Word;
  HotspotY   : Word;
Begin
  { Charger le fichier curseur }
  If Not LoadCursorFile(FileName) Then
  Begin
    FatalError('Impossible de charger le fichier curseur: ' + FileName);
    Exit;
  End;
  
  If IconCount = 0 Then
  Begin
    FatalError('Fichier curseur vide ou invalide: ' + FileName);
    Exit;
  End;
  
  { Ecrire chaque image comme ressource RT_CURSOR individuelle }
  For I := 1 To IconCount Do
  Begin
    CursorIds[I] := NextCursorId;
    { Pour les curseurs, Planes contient hotspot X et BitCount contient hotspot Y }
    HotspotX := IconEntries[I].Planes;
    HotspotY := IconEntries[I].BitCount;
    WriteCursorResource(NextCursorId, IconData[I], IconDataSizes[I], 
                        HotspotX, HotspotY, MemFlags, LangId);
    Inc(NextCursorId);
  End;
  
  { Creer les entrees pour le groupe }
  For I := 1 To IconCount Do
  Begin
    GrpEntries[I-1].Width      := IconEntries[I].Width;
    GrpEntries[I-1].Height     := IconEntries[I].Height;
    GrpEntries[I-1].ColorCount := IconEntries[I].ColorCount;
    GrpEntries[I-1].Reserved   := 0;
    { Pour les curseurs dans le groupe, Planes et BitCount sont les vraies valeurs }
    GrpEntries[I-1].Planes     := 1;  { Toujours 1 pour les curseurs }
    GrpEntries[I-1].BitCount   := 1;  { Bits par pixel, typiquement 1 pour curseurs }
    GrpEntries[I-1].BytesInRes := IconEntries[I].BytesInRes;
    GrpEntries[I-1].Id         := CursorIds[I];
  End;
  
  { Ecrire la ressource RT_GROUP_CURSOR }
  WriteGroupCursorHeader(NameIsId, NameId, NameStr, GrpEntries, IconCount, 
                         MemFlags, LangId);
  
  { Liberer les donnees }
  ClearIconData;
  
  If Opts.Verbose Then
    WriteLn('  CURSOR ', FileName, ' -> ', IconCount, ' image(s)');
End;

{ ----- Procedure ParseIcon ----- }
Procedure ParseIcon(NameIsId : Boolean; NameId : Word; Const NameStr : TString);
Var
  MemFlags : Word;
  FileName : TString;
Begin
  { Lire les options memoire }
  MemFlags := ParseMemoryOptions;
  
  { Lire le nom du fichier }
  FileName := ExpectString;
  
  { Ecrire la ressource }
  WriteIcon(NameIsId, NameId, NameStr, FileName, MemFlags, CurrentLangId);
End;

{ ----- Procedure ParseCursor ----- }
Procedure ParseCursor(NameIsId : Boolean; NameId : Word; Const NameStr : TString);
Var
  MemFlags : Word;
  FileName : TString;
Begin
  { Lire les options memoire }
  MemFlags := ParseMemoryOptions;
  
  { Lire le nom du fichier }
  FileName := ExpectString;
  
  { Ecrire la ressource }
  WriteCursor(NameIsId, NameId, NameStr, FileName, MemFlags, CurrentLangId);
End;

{ ============================================================
  TODO 17 : COMPILATION BITMAP
  ============================================================ }

{ ----- Procedure InitBitmap ----- }
{ Initialise les variables globales pour le traitement des bitmaps }
Procedure InitBitmap;
Begin
  BitmapData := Nil;
  BitmapDataSize := 0;
End;

{ ----- Procedure ClearBitmapData ----- }
{ Libere la memoire du bitmap }
Procedure ClearBitmapData;
Begin
  If BitmapData <> Nil Then
  Begin
    FreeMem(BitmapData, BitmapDataSize);
    BitmapData := Nil;
    BitmapDataSize := 0;
  End;
End;

{ ----- Procedure LoadBitmapFile ----- }
{ Charge un fichier .bmp et extrait les donnees DIB (sans BITMAPFILEHEADER) }
Procedure LoadBitmapFile(Const AFileName : TString;
  Var AHeader : TBitmapInfoHeader; Var ADataPtr : Pointer;
  Var ADataSize : LongInt);
Var
  F          : File;
  FileHdr    : TBitmapFileHeader;
  BytesRead  : LongInt;
Begin
  { Initialiser les sorties }
  ADataPtr := Nil;
  ADataSize := 0;
  FillChar(AHeader, SizeOf(AHeader), 0);
  
  { Ouvrir le fichier }
  {$I-}
  Assign(F, AFileName);
  Reset(F, 1);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier bitmap : ' + AFileName);
  
  { Lire l'en-tete du fichier bitmap }
  {$I-}
  BlockRead(F, FileHdr, SizeOf(FileHdr), BytesRead);
  {$I+}
  If (IOResult <> 0) Or (BytesRead <> SizeOf(FileHdr)) Then
  Begin
    Close(F);
    FatalError('Erreur de lecture de l''en-tete du fichier bitmap : ' + AFileName);
  End;
  
  { Verifier la signature 'BM' }
  If FileHdr.bfType <> $4D42 Then
  Begin
    Close(F);
    FatalError('Fichier bitmap invalide (signature incorrecte) : ' + AFileName);
  End;
  
  { Lire l'en-tete d'info bitmap }
  {$I-}
  BlockRead(F, AHeader, SizeOf(AHeader), BytesRead);
  {$I+}
  If (IOResult <> 0) Or (BytesRead <> SizeOf(AHeader)) Then
  Begin
    Close(F);
    FatalError('Erreur de lecture de l''en-tete info bitmap : ' + AFileName);
  End;
  
  { Verifier la taille de l'en-tete }
  If AHeader.biSize < 40 Then
  Begin
    Close(F);
    FatalError('En-tete bitmap non supporte (taille < 40) : ' + AFileName);
  End;
  
  { Calculer la taille des donnees (tout apres BITMAPFILEHEADER) }
  ADataSize := FileHdr.bfSize - SizeOf(FileHdr);
  
  { Allouer la memoire }
  GetMem(ADataPtr, ADataSize);
  If ADataPtr = Nil Then
  Begin
    Close(F);
    FatalError('Memoire insuffisante pour le bitmap : ' + AFileName);
  End;
  
  { Revenir au debut des donnees DIB (apres BITMAPFILEHEADER) }
  {$I-}
  Seek(F, SizeOf(FileHdr));
  {$I+}
  If IOResult <> 0 Then
  Begin
    FreeMem(ADataPtr, ADataSize);
    ADataPtr := Nil;
    ADataSize := 0;
    Close(F);
    FatalError('Erreur de positionnement dans le fichier bitmap : ' + AFileName);
  End;
  
  { Lire les donnees DIB (BITMAPINFOHEADER + palette + pixels) }
  {$I-}
  BlockRead(F, ADataPtr^, ADataSize, BytesRead);
  {$I+}
  If (IOResult <> 0) Or (BytesRead <> ADataSize) Then
  Begin
    FreeMem(ADataPtr, ADataSize);
    ADataPtr := Nil;
    ADataSize := 0;
    Close(F);
    FatalError('Erreur de lecture des donnees bitmap : ' + AFileName);
  End;
  
  { Fermer le fichier }
  Close(F);
End;

{ ----- Procedure WriteBitmapResource ----- }
{ Ecrit les donnees brutes d'un bitmap dans le fichier ressource }
Procedure WriteBitmapResource(ADataPtr : Pointer; ADataSize : LongInt);
Var
  I : LongInt;
  P : PByte;
Begin
  P := PByte(ADataPtr);
  For I := 0 To ADataSize - 1 Do
  Begin
    WriteByte(P^);
    Inc(P);
  End;
End;

{ ----- Procedure WriteBitmap ----- }
{ Ecrit une ressource RT_BITMAP complete }
Procedure WriteBitmap(NameIsId : Boolean; NameId : Word;
  Const NameStr : TString; Const AFileName : TString;
  MemFlags : Word; LangId : Word);
Var
  Header   : TBitmapInfoHeader;
  DataPtr  : Pointer;
  DataSize : LongInt;
  ResIdx   : Integer;
  DataPos  : LongInt;
Begin
  { Charger le fichier bitmap }
  LoadBitmapFile(AFileName, Header, DataPtr, DataSize);
  
  { Ajouter la ressource a la table }
  ResIdx := AddResource(True, RT_BITMAP, '', NameIsId, NameId, NameStr, 
                        MemFlags, LangId);
  
  { Ecrire l'en-tete de ressource }
  If Opts.Output32 Then
  Begin
    WriteResHeader32(True, RT_BITMAP, '', NameIsId, NameId, NameStr,
                     DataSize, MemFlags, LangId);
  End
  Else
  Begin
    If NameIsId Then
      WriteResHeader16(RT_BITMAP, NameId, DataSize, MemFlags)
    Else
      WriteResHeader16Str('BITMAP', NameStr, DataSize, MemFlags);
  End;
  
  { Enregistrer la position des donnees }
  DataPos := GetResPos;
  SetResourceDataOfs(ResIdx, DataPos);
  
  { Ecrire les donnees du bitmap }
  WriteBitmapResource(DataPtr, DataSize);
  
  { Aligner sur 4 octets pour 32 bits }
  If Opts.Output32 Then
    PadToAlignment(4);
  
  { Enregistrer la taille des donnees }
  SetResourceDataSize(ResIdx, DataSize);
  
  { Liberer la memoire }
  FreeMem(DataPtr, DataSize);
  
  { Afficher en mode verbeux }
  If Opts.Verbose Then
  Begin
    Write('  BITMAP ');
    If NameIsId Then
      Write('#', NameId)
    Else
      Write('"', NameStr, '"');
    WriteLn(' <- ', AFileName, ' (', DataSize, ' octets, ',
            Header.biWidth, 'x', Header.biHeight, ' ', Header.biBitCount, 'bpp)');
  End;
End;

{ ----- Procedure ParseBitmap ----- }
{ Parse une declaration BITMAP et ecrit la ressource }
Procedure ParseBitmap(NameIsId : Boolean; NameId : Word; Const NameStr : TString);
Var
  MemFlags : Word;
  FileName : TString;
Begin
  { Lire les options memoire }
  MemFlags := ParseMemoryOptions;
  
  { Lire le nom du fichier }
  FileName := ExpectString;
  
  { Ecrire la ressource }
  WriteBitmap(NameIsId, NameId, NameStr, FileName, MemFlags, CurrentLangId);
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
  
  { Initialiser les compteurs }
  ResCount := 0;
  StringCount := 0;
  AccelCount := 0;
  MenuItemCount := 0;
  DialogCtrlCount := 0;
  InitVersionInfo;
  InitIconCursor;
  InitBitmap;

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

  { TODO : Implementation des TODOs 18-25 }
  WriteLn;
  WriteLn('NOTE: TODOs 01-18 [IMPLEMENTE]. TODOs 19-25 sont [A FAIRE].');
  WriteLn('      Ce fichier contient la structure et les specifications');
  WriteLn('      pour un compilateur de ressources .RC vers .RES.');
End.
