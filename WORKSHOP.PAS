{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de Resource Editor Workshop - Editeur de ressources Windows
                (.RES, .RC) avec support import Macintosh et GEM/Atari ST
  @license: MIT
}

(* ============================================================
   WORKSHOP.PAS - Resource Editor Workshop
   Clone de l'editeur de ressources Borland Resource Workshop

   Turbo Pascal 7 / Free Pascal 3.2 (-Mtp)

   Fonctionnalites :
     - Mode graphique VGA 640x480
     - Support souris multiplateforme (INT 33h / PtcMouse)
     - Interface GUI complete avec menus deroulants
     - Edition de fichiers .RC (scripts) et .RES (binaires)
     - Support des ressources : BITMAP, ICON, CURSOR, DIALOG,
       MENU, STRINGTABLE, ACCELERATORS, RCDATA, VERSIONINFO
     - Import des ressources Macintosh et GEM/Atari ST

   Usage :
     WORKSHOP [fichier.rc | fichier.res]

   Voir README.md pour la documentation complete.

   TODO 01 - INITIALISATION DU MODE GRAPHIQUE VGA [IMPLEMENTE]
             Configurer le mode graphique 640x480 compatible
             Turbo Pascal (Graph) et Free Pascal (PtcGraph)
             Detection automatique du compilateur avec $IFDEF FPC
             Procedure InitializeGraphics : detecter le mode VGA,
             appeler InitGraph, verifier GraphResult, configurer
             les couleurs et styles par defaut

   TODO 02 - SUPPORT SOURIS MULTIPLATEFORME [IMPLEMENTE]
             Pour Turbo Pascal : INT 33h avec Registers
               Function MouseDriverFound: Boolean (AX=0)
               Procedure ShowMouse (AX=1)
               Procedure HideMouse (AX=2)
               Procedure GetMouseState(Var X, Y, Button: LongInt) (AX=3)
               Procedure SetMousePos(X, Y: LongInt) (AX=4)
               Procedure SetMouseBounds(X1, Y1, X2, Y2: LongInt) (AX=7,8)
             Pour Free Pascal : utiliser PtcMouse
               GetMouseState via GetMouseEvent/GetLastButtonPress

   TODO 03 - SYSTEME DE FENETRAGE GUI [IMPLEMENTE]
             Types de base :
               TRect = Record X1, Y1, X2, Y2: Integer End
               TWindow = Record Title: String; Bounds: TRect;
                 Visible, Active, Moveable, Resizable: Boolean End
             Procedure DrawWindow(W: TWindow) : dessiner bordure 3D,
               barre de titre, boutons fermer/minimiser/maximiser
             Procedure DrawButton(X, Y, W, H: Integer; Caption: String;
               Pressed: Boolean) : dessiner un bouton avec effet 3D
             Procedure DrawCheckBox(X, Y: Integer; Checked: Boolean;
               Caption: String)
             Procedure DrawRadioButton(X, Y: Integer; Selected: Boolean;
               Caption: String)
             Procedure DrawScrollBar(X, Y, Len: Integer; Vertical: Boolean;
               Pos, Max: Integer)
             Procedure DrawEditBox(X, Y, W: Integer; Text: String;
               Focused: Boolean)
             Procedure DrawListBox(X, Y, W, H: Integer; Items: Array;
               Selected, TopItem: Integer)

   TODO 04 - BARRE DE MENUS PRINCIPALE [IMPLEMENTE]
             Type TMenuItem = Record
               Caption: String; Shortcut: String; Enabled: Boolean;
               Checked: Boolean; SubMenu: ^TMenu
             End
             Type TMenu = Record
               Items: Array[1..20] Of TMenuItem; Count: Integer;
               X, Y, W, H: Integer; Visible: Boolean
             End
             Menus : Fichier, Edition, Format, Vue, Projet, Options,
               Outils, Aide
             Procedure DrawMenuBar : dessiner la barre de menus
             Procedure DrawDropDownMenu(Menu: TMenu) : afficher menu
             Function HandleMenuClick(X, Y: Integer): Integer :
               detecter le menu clique et retourner l'ID de commande
             Constantes de commandes CMD_FILE_NEW, CMD_FILE_OPEN, etc.

   TODO 05 - LECTURE DES FICHIERS .RC [IMPLEMENTE]
             Lexer : tokenisation du script RC
               TTokenKind : TK_IDENT, TK_NUMBER, TK_STRING, TK_COMMA,
                 TK_LPAREN, TK_RPAREN, TK_LBRACE, TK_RBRACE, etc.
               Function NextToken: TToken
               Function PeekToken: TToken
             Parser : analyse syntaxique des directives
               Procedure ParseStatement : dispatcher selon le mot-cle
               Procedure ParseDialog, ParseMenu, ParseStringTable,
                 ParseAccelerators, ParseVersionInfo, ParseBitmap,
                 ParseIcon, ParseCursor, ParseRcData
             Structure en memoire des ressources parsees

   TODO 06 - ECRITURE DES FICHIERS .RC [IMPLEMENTE]
             Procedure WriteRCFile(Const FileName: String)
               generer le script RC a partir des ressources en memoire
             Procedure WriteDialogRC(D: TDialog)
             Procedure WriteMenuRC(M: TMenu)
             Procedure WriteStringTableRC
             Procedure WriteAcceleratorsRC
             Procedure WriteVersionInfoRC
             Formatter le code avec indentation et commentaires

   TODO 07 - LECTURE DES FICHIERS .RES BINAIRES [IMPLEMENTE]
             Detection du format (16 bits vs 32 bits)
             Lecture de l'en-tete de ressource
             Extraction des donnees brutes
             Decodage des types : RT_DIALOG, RT_MENU, RT_STRING,
               RT_ACCELERATOR, RT_VERSION, RT_BITMAP, RT_ICON, etc.
             Stockage en memoire pour edition

   TODO 08 - ECRITURE DES FICHIERS .RES BINAIRES [IMPLEMENTE]
             Procedure WriteRESFile(Const FileName: String; Is32Bit: Boolean)
             Generation de l'en-tete nulle (32 bits)
             Ecriture des ressources avec alignement
             Calcul des tailles et offsets

   TODO 09 - IMPORT DES RESSOURCES MACINTOSH [IMPLEMENTE]
             Lecture du resource fork Macintosh
             Decodage du resource map
             Support des types : ICON, ICN#, icl4, icl8, CURS, PICT,
               MENU, DLOG, DITL, STR, STR#, vers
             Conversion vers format Windows equivalent

   TODO 10 - IMPORT DES FICHIERS GEM .RSC [IMPLEMENTE]
             Lecture du format RSC Atari ST/GEM
             Decodage des structures : OBJECT, TEDINFO, ICONBLK,
               BITBLK, CICON, etc.
             Extraction des images et formulaires
             Conversion vers format Windows

   TODO 11 - EDITEUR DE BITMAP [IMPLEMENTE]
             Interface : zone de dessin, palette de couleurs,
               outils (crayon, ligne, rectangle, ellipse, remplissage,
               selection, gomme), zoom (1x, 2x, 4x, 8x, 16x)
             Procedure DrawBitmapEditor
             Procedure HandleBitmapEditorClick
             Procedure BitmapPutPixel(X, Y: Integer; Color: Byte)
             Procedure BitmapDrawLine(X1, Y1, X2, Y2: Integer)
             Procedure BitmapFloodFill(X, Y: Integer; Color: Byte)
             Support des formats : 1-bit, 4-bit, 8-bit, 24-bit

   TODO 12 - EDITEUR D'ICONES (.ICO) [IMPLEMENTE]
             Support multi-resolution : 16x16, 32x32, 48x48, 64x64, 256x256
             Masque de transparence (AND mask)
             Liste des images dans l'icone
             Ajout/suppression de resolutions
             Import/export BMP individuel

   TODO 13 - EDITEUR DE CURSEURS (.CUR) [IMPLEMENTE]
             Similaire a l'editeur d'icones
             Definition du point chaud (hotspot X, Y)
             Previsualisation du curseur en mouvement
             Support des curseurs animes (ANI)

   TODO 14 - EDITEUR DE BOITES DE DIALOGUE [IMPLEMENTE]
             Editeur visuel WYSIWYG
             Palette de controles : PUSHBUTTON, DEFPUSHBUTTON,
               CHECKBOX, RADIOBUTTON, EDITTEXT, COMBOBOX, LISTBOX,
               SCROLLBAR, STATIC, GROUPBOX, ICON, etc.
             Drag and drop des controles
             Redimensionnement et alignement
             Editeur de proprietes (ID, texte, style, position)
             Grille d'alignement configurable

   TODO 15 - EDITEUR D'ETIQUETTES (STATIC) [IMPLEMENTE]
             Types : LTEXT, RTEXT, CTEXT (alignement)
             ICON (reference a une icone)
             EDITTEXT (champ de saisie)
             Proprietes : texte, police, couleur, bordure

   TODO 16 - EDITEUR DE MENUS [IMPLEMENTE]
             Vue hierarchique arborescente
             POPUP (sous-menu), MENUITEM, SEPARATOR
             Proprietes : texte, ID, raccourci, style (GRAYED, CHECKED)
             Previsualisation du menu

   TODO 17 - EDITEUR DE TABLES DE CHAINES (STRINGTABLE) [IMPLEMENTE]
             Liste des chaines avec ID et texte
             Ajout/modification/suppression
             Recherche par ID ou contenu
             Support multilingue (plusieurs tables par langue)

   TODO 18 - EDITEUR D'ACCELERATEURS [IMPLEMENTE]
             Liste des raccourcis clavier
             Definition : touche, modificateurs (VIRTKEY, ALT, CONTROL,
               SHIFT, NOINVERT), ID de commande
             Validation des conflits

   TODO 19 - EDITEUR RCDATA [IMPLEMENTE]
             Editeur hexadecimal pour donnees brutes
             Vue hex + ASCII cote a cote
             Recherche, remplacement
             Import/export de fichiers binaires

   TODO 20 - EDITEUR VERSIONINFO [IMPLEMENTE]
             Formulaire pour les informations de version :
               FILEVERSION, PRODUCTVERSION, FILEFLAGSMASK, FILEFLAGS,
               FILEOS, FILETYPE, FILESUBTYPE
             Block StringFileInfo : CompanyName, FileDescription,
               FileVersion, InternalName, LegalCopyright, OriginalFilename,
               ProductName, ProductVersion
             Block VarFileInfo : Translation

   TODO 21 - EDITEUR DE LANGUES [IMPLEMENTE]
             Selection de la langue (LANGUAGE primary, sub)
             Liste des langues supportees
             Code page associe
             Application a une ressource ou globalement

   TODO 22 - EXPLORATEUR DE RESSOURCES [IMPLEMENTE]
             Vue arborescente hierarchique
             Icones par type de ressource
             Drag and drop entre projets
             Menu contextuel (ajouter, supprimer, renommer, dupliquer)
             Filtrage par type

   TODO 23 - PRESSE-PAPIERS (COPIER/COLLER) [IMPLEMENTE]
             Copie de ressources entieres
             Copie de pixels dans les editeurs graphiques
             Copie de texte dans les editeurs de texte
             Format interne pour preservation des proprietes

   TODO 24 - PREVISUALISATION [IMPLEMENTE]
             Apercu des dialogues en taille reelle
             Apercu des menus deroulants
             Test interactif des controles
             Zoom et centrage

   TODO 25 - GESTION DE PROJET [IMPLEMENTE]
             Nouveau projet (vide ou depuis template)
             Ouvrir projet existant (.RC ou .RES)
             Sauvegarder / Sauvegarder sous
             Ajouter ressource (tous types)
             Supprimer ressource
             Compiler vers .RES (16 ou 32 bits)
             Verifier la coherence du projet
             Liste des fichiers recents
   ============================================================ *)

Program WORKSHOP;

{$A-}

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse,Dos
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 { Version }
 WORKSHOP_VERSION = '1.0';
 WORKSHOP_DATE = '2026-04-20';

 { Constantes graphiques }
 SCREEN_WIDTH = 640;
 SCREEN_HEIGHT = 480;
 MENU_BAR_HEIGHT = 20;
 STATUS_BAR_HEIGHT = 20;
 TOOLBAR_HEIGHT = 32;

 { Couleurs de l'interface }
 { Note: SetBkColor(7) remape l'index 0 vers gris, donc ne jamais }
 { utiliser la couleur 0 pour dessiner. Utiliser 8 comme noir. }
 COLOR_BACKGROUND = 7;
 COLOR_MENUBAR = 7;
 COLOR_MENUTEXT = 8;
 COLOR_HIGHLIGHT = 1;
 COLOR_HIGHLIGHTTEXT = 15;
 COLOR_WINDOW = 15;
 COLOR_WINDOWTEXT = 8;
 COLOR_BORDER3D_LIGHT = 15;
 COLOR_BORDER3D_DARK = 8;
 COLOR_TITLEBAR = 1;
 COLOR_TITLETEXT = 15;
 COLOR_BUTTON = 7;
 COLOR_BUTTONTEXT = 8;
 COLOR_DISABLED = 8;
 COLOR_SCROLLBAR = 7;
 COLOR_GRAYTEXT = 8;

 { Constantes de menus }
 MAX_MENUS = 8;
 MAX_MENU_ITEMS = 20;

 { Commandes de menu - Fichier }
 CMD_NONE = 0;
 CMD_FILE_NEW = 100;
 CMD_FILE_OPEN = 101;
 CMD_FILE_SAVE = 102;
 CMD_FILE_SAVEAS = 103;
 CMD_FILE_IMPORT_MAC = 104;
 CMD_FILE_IMPORT_GEM = 105;
 CMD_FILE_EXPORT = 106;
 CMD_FILE_EXIT = 107;
 { Commandes de menu - Edition }
 CMD_EDIT_UNDO = 200;
 CMD_EDIT_CUT = 201;
 CMD_EDIT_COPY = 202;
 CMD_EDIT_PASTE = 203;
 CMD_EDIT_DELETE = 204;
 CMD_EDIT_SELECTALL = 205;
 { Commandes de menu - Format }
 CMD_FORMAT_FONT = 300;
 CMD_FORMAT_ALIGN = 301;
 CMD_FORMAT_SIZE = 302;
 CMD_FORMAT_COLORS = 303;
 { Commandes de menu - Vue }
 CMD_VIEW_EXPLORER = 400;
 CMD_VIEW_PROPERTIES = 401;
 CMD_VIEW_ZOOMIN = 402;
 CMD_VIEW_ZOOMOUT = 403;
 CMD_VIEW_GRID = 404;
 { Commandes de menu - Projet }
 CMD_PROJECT_ADDRES = 500;
 CMD_PROJECT_DELRES = 501;
 CMD_PROJECT_COMPILE = 502;
 CMD_PROJECT_VERIFY = 503;
 { Commandes de menu - Options }
 CMD_OPTIONS_PREFS = 600;
 CMD_OPTIONS_COMPILER = 601;
 CMD_OPTIONS_COLORS = 602;
 { Commandes de menu - Outils }
 CMD_TOOLS_HEXEDIT = 700;
 CMD_TOOLS_COMPARE = 701;
 CMD_TOOLS_VALIDATE = 702;
 { Commandes de menu - Aide }
 CMD_HELP_INDEX = 800;
 CMD_HELP_SEARCH = 801;
 CMD_HELP_ABOUT = 802;

 { Types de ressources Windows }
 RT_CURSOR = 1;
 RT_BITMAP = 2;
 RT_ICON = 3;
 RT_MENU = 4;
 RT_DIALOG = 5;
 RT_STRING = 6;
 RT_FONTDIR = 7;
 RT_FONT = 8;
 RT_ACCELERATOR = 9;
 RT_RCDATA = 10;
 RT_MESSAGETABLE = 11;
 RT_GROUP_CURSOR = 12;
 RT_GROUP_ICON = 14;
 RT_VERSION = 16;
 RT_DLGINCLUDE = 17;
 RT_PLUGPLAY = 19;
 RT_VXD = 20;
 RT_ANICURSOR = 21;
 RT_ANIICON = 22;
 RT_HTML = 23;
 RT_MANIFEST = 24;

 { Types d'objets GEM/AES (Atari ST) }
 G_BOX      = 20;  { Boite rectangle }
 G_TEXT     = 21;  { Texte }
 G_BOXTEXT  = 22;  { Texte dans une boite }
 G_IMAGE    = 23;  { Image bitmap }
 G_PROGDEF  = 24;  { Objet defini par programme }
 G_IBOX     = 25;  { Boite invisible }
 G_BUTTON   = 26;  { Bouton }
 G_BOXCHAR  = 27;  { Caractere dans une boite }
 G_STRING   = 28;  { Chaine de caracteres }
 G_FTEXT    = 29;  { Texte editable formatte }
 G_FBOXTEXT = 30;  { Texte editable dans boite }
 G_ICON     = 31;  { Icone }
 G_TITLE    = 32;  { Titre de menu }
 G_CICON    = 33;  { Icone couleur }

 { Flags d'objets GEM }
 GEM_SELECTABLE = $0001;
 GEM_DEFAULT    = $0002;
 GEM_EXIT       = $0004;
 GEM_EDITABLE   = $0008;
 GEM_RBUTTON    = $0010;
 GEM_LASTOB     = $0020;
 GEM_TOUCHEXIT  = $0040;
 GEM_HIDETREE   = $0080;
 GEM_INDIRECT   = $0100;
 GEM_FL3DIND    = $0200;
 GEM_FL3DACT    = $0400;
 GEM_SUBMENU    = $0800;

 { Constantes pour import GEM RSC }
 GEM_DIALOG_ID_BASE = 1000;  { Base pour IDs de dialogues importes }
 GEM_ICON_ID_BASE   = 2000;  { Base pour IDs d'icones importees }
 GEM_BITMAP_ID_BASE = 3000;  { Base pour IDs de bitmaps importes }
 TREE_INDEX_SIZE    = 4;     { Taille d'une entree dans l'index d'arbres }
 MAX_RSC_STRING_LEN = 255;   { Longueur max des chaines RSC }

 { Limites }
 MAX_RESOURCES = 1024;
 MAX_STRINGS = 4096;
 MAX_CONTROLS = 256;
 MAX_MENU_ITEMS_RES = 512;
 MAX_ACCEL = 256;
 MAX_BITMAP_SIZE = 65535;
 MAX_WINDOWS = 16;
 MAX_UNDO = 64;

 { Outils de dessin }
 TOOL_SELECT = 0;
 TOOL_PENCIL = 1;
 TOOL_LINE = 2;
 TOOL_RECT = 3;
 TOOL_FILLRECT = 4;
 TOOL_ELLIPSE = 5;
 TOOL_FILLELLIPSE = 6;
 TOOL_FILL = 7;
 TOOL_ERASER = 8;
 TOOL_PICKER = 9;
 TOOL_TEXT = 10;

Type
 { Types de base }
 TRect = Record
  X1, Y1, X2, Y2: Integer;
 End;

 TPoint = Record
  X, Y: Integer;
 End;

 { Element de menu }
 TMenuItem = Record
  Caption: String[40];
  Shortcut: String[15];
  CommandId: Integer;
  Enabled: Boolean;
  Checked: Boolean;
  IsSeparator: Boolean;
 End;

 { Menu deroulant }
 TDropMenu = Record
  Items: Array[1..MAX_MENU_ITEMS] Of TMenuItem;
  Count: Integer;
  X, Y, W, H: Integer;
  Visible: Boolean;
  SelectedItem: Integer;
 End;

 { Barre de menus }
 TMenuBar = Record
  Titles: Array[1..MAX_MENUS] Of String[20];
  Menus: Array[1..MAX_MENUS] Of TDropMenu;
  Count: Integer;
  ActiveMenu: Integer;
  MenuOpen: Boolean;
 End;

 { Fenetre }
 TWindow = Record
  Title: String[60];
  Bounds: TRect;
  ClientArea: TRect;
  Visible: Boolean;
  Active: Boolean;
  Moveable: Boolean;
  Resizable: Boolean;
  HasCloseBtn: Boolean;
  HasMinBtn: Boolean;
  HasMaxBtn: Boolean;
  Minimized: Boolean;
  Maximized: Boolean;
  WindowType: Integer;
  ResourceIndex: Integer;
 End;

 { Identifiant de ressource }
 TResourceId = Record
  IsNumeric: Boolean;
  NumId: Word;
  StrId: String[63];
 End;

 { Entree de ressource }
 TResourceEntry = Record
  ResType: Word;
  TypeName: String[31];
  ResId: TResourceId;
  LangId: Word;
  MemFlags: Word;
  DataSize: LongInt;
  DataOffset: LongInt;
  Modified: Boolean;
 End;

 { Donnees de dialogue }
 TDialogControl = Record
  CtrlType: Word;
  CtrlId: Word;
  X, Y, W, H: Integer;
  Text: String[127];
  Style: LongInt;
  ExStyle: LongInt;
  ClassName: String[31];
 End;

 TDialogData = Record
  Style: LongInt;
  ExStyle: LongInt;
  X, Y, W, H: Integer;
  Caption: String[127];
  FontName: String[31];
  FontSize: Integer;
  FontWeight: Integer;
  FontItalic: Boolean;
  Controls: Array[1..MAX_CONTROLS] Of TDialogControl;
  ControlCount: Integer;
 End;

 { Donnees de menu }
 TMenuItemData = Record
  ItemType: Byte;
  ItemId: Word;
  Text: String[63];
  Flags: Word;
  Level: Integer;
 End;

 TMenuData = Record
  Items: Array[1..MAX_MENU_ITEMS_RES] Of TMenuItemData;
  ItemCount: Integer;
 End;

 { Donnees de table de chaines }
 TStringEntry = Record
  StringId: Word;
  Text: String[255];
  LangId: Word;
 End;

 { Donnees d'accelerateur }
 TAccelEntry = Record
  fVirt: Word;
  Key: Word;
  Cmd: Word;
 End;

 { Donnees de version }
 TVersionInfo = Record
  FileVersionMS: LongInt;
  FileVersionLS: LongInt;
  ProductVersionMS: LongInt;
  ProductVersionLS: LongInt;
  FileFlagsMask: LongInt;
  FileFlags: LongInt;
  FileOS: LongInt;
  FileType: LongInt;
  FileSubtype: LongInt;
  CompanyName: String[127];
  FileDescription: String[127];
  FileVersion: String[31];
  InternalName: String[63];
  LegalCopyright: String[127];
  OriginalFilename: String[63];
  ProductName: String[127];
  ProductVersion: String[31];
  Comments: String[255];
  LegalTrademarks: String[127];
  PrivateBuild: String[63];
  SpecialBuild: String[63];
 End;

 { Donnees de bitmap }
 TBitmapData = Record
  Width: Integer;
  Height: Integer;
  BitsPerPixel: Integer;
  Palette: Array[0..255] Of Record R, G, B: Byte End;
  PaletteCount: Integer;
  DataSize: LongInt;
 End;

 { Donnees d'icone }
 TIconImage = Record
  Width: Integer;
  Height: Integer;
  BitsPerPixel: Integer;
  DataSize: Integer;
  MaskSize: Integer;
 End;

 TIconData = Record
  Images: Array[1..8] Of TIconImage;
  ImageCount: Integer;
 End;

 { Donnees de curseur }
 TCursorData = Record
  Width: Integer;
  Height: Integer;
  HotspotX: Integer;
  HotspotY: Integer;
  BitsPerPixel: Integer;
  DataSize: Integer;
  MaskSize: Integer;
 End;

 { Structures pour import GEM RSC (Atari ST) }
 { En-tete du fichier RSC - 36 octets }
 TRSCHeader = Record
  vrsn: Word;        { Version du fichier RSC }
  object_: Word;     { Offset vers tableau OBJECT }
  tedinfo: Word;     { Offset vers tableau TEDINFO }
  iconblk: Word;     { Offset vers tableau ICONBLK }
  bitblk: Word;      { Offset vers tableau BITBLK }
  frstr: Word;       { Offset vers free strings }
  string_: Word;     { Offset vers premier string }
  imdata: Word;      { Offset vers donnees image }
  frimg: Word;       { Offset vers free images }
  trindex: Word;     { Offset vers tree index }
  nobs: Word;        { Nombre d'objects }
  ntree: Word;       { Nombre d'arbres }
  nted: Word;        { Nombre de TEDINFO }
  nib: Word;         { Nombre d'ICONBLK }
  nbb: Word;         { Nombre de BITBLK }
  nstring: Word;     { Nombre de strings }
  nimages: Word;     { Nombre d'images }
  rssize: Word;      { Taille totale du fichier RSC }
 End;

 { Structure OBJECT GEM - 24 octets }
 TGEMObject = Record
  ob_next: SmallInt;  { Index du prochain objet }
  ob_head: SmallInt;  { Index du premier enfant }
  ob_tail: SmallInt;  { Index du dernier enfant }
  ob_type: Word;      { Type d'objet }
  ob_flags: Word;     { Flags }
  ob_state: Word;     { Etat de l'objet }
  ob_spec: LongInt;   { Pointeur vers donnees specifiques }
  ob_x: SmallInt;     { Position X }
  ob_y: SmallInt;     { Position Y }
  ob_width: SmallInt; { Largeur }
  ob_height: SmallInt;{ Hauteur }
 End;

 { Structure TEDINFO GEM - 28 octets }
 TGEMTedInfo = Record
  te_ptext: LongInt;    { Pointeur vers texte editable }
  te_ptmplt: LongInt;   { Pointeur vers template }
  te_pvalid: LongInt;   { Pointeur vers validation string }
  te_font: SmallInt;    { Font ID }
  te_fontid: SmallInt;  { Font ID reserve }
  te_just: SmallInt;    { Justification (0=left, 1=right, 2=center) }
  te_color: SmallInt;   { Couleur }
  te_fontsize: SmallInt;{ Taille de fonte }
  te_thickness: SmallInt;{ Epaisseur de la bordure }
  te_txtlen: SmallInt;  { Longueur max du texte }
  te_tmplen: SmallInt;  { Longueur du template }
 End;

 { Structure ICONBLK GEM - 34 octets }
 TGEMIconBlk = Record
  ib_pmask: LongInt;  { Pointeur vers masque }
  ib_pdata: LongInt;  { Pointeur vers donnees image }
  ib_ptext: LongInt;  { Pointeur vers texte de l'icone }
  ib_char: SmallInt;  { Caractere dans l'icone }
  ib_xchar: SmallInt; { Position X du caractere }
  ib_ychar: SmallInt; { Position Y du caractere }
  ib_xicon: SmallInt; { Position X de l'icone }
  ib_yicon: SmallInt; { Position Y de l'icone }
  ib_wicon: SmallInt; { Largeur de l'icone }
  ib_hicon: SmallInt; { Hauteur de l'icone }
  ib_xtext: SmallInt; { Position X du texte }
  ib_ytext: SmallInt; { Position Y du texte }
  ib_wtext: SmallInt; { Largeur du texte }
  ib_htext: SmallInt; { Hauteur du texte }
 End;

 { Structure BITBLK GEM - 14 octets }
 TGEMBitBlk = Record
  bi_pdata: LongInt;  { Pointeur vers donnees bitmap }
  bi_wb: SmallInt;    { Largeur en octets }
  bi_hl: SmallInt;    { Hauteur en lignes }
  bi_x: SmallInt;     { Position X }
  bi_y: SmallInt;     { Position Y }
  bi_color: SmallInt; { Couleur }
 End;

 { Donnees RSC en memoire }
 TRSCData = Record
  Header: TRSCHeader;
  Objects: Array[1..256] Of TGEMObject;
  ObjectCount: Integer;
  TedInfos: Array[1..64] Of TGEMTedInfo;
  TedInfoCount: Integer;
  IconBlks: Array[1..32] Of TGEMIconBlk;
  IconBlkCount: Integer;
  BitBlks: Array[1..32] Of TGEMBitBlk;
  BitBlkCount: Integer;
  TreeCount: Integer;
 End;

 { Presse-papiers interne }
 TClipboard = Record
  HasData: Boolean;
  DataType: Integer;
  ResourceType: Word;
  DataSize: LongInt;
  Width, Height: Integer;
  Text: String[255];
 End;

 { Etat de l'application }
 { Etat de l'arbre de ressources dans l'explorateur }
 TTreeNodeState = Record
  Expanded: Boolean;           { Noeud est-il deplie }
  HasChildren: Boolean;        { Noeud a-t-il des enfants }
  Level: Integer;              { Niveau d'indentation (0=racine, 1=type, 2=ressource) }
  ResType: Word;               { Type de ressource pour les noeuds de niveau 1 }
  ResIndex: Integer;           { Index de la ressource pour niveau 2 (-1 si noeud type) }
  Y: Integer;                  { Position Y a l'ecran pour detection clics }
 End;

 TAppState = Record
  ProjectFile: String[127];
  ProjectModified: Boolean;
  Is32BitFormat: Boolean;
  CurrentLangId: Word;
  CurrentTool: Integer;
  CurrentColor: Integer;
  ZoomLevel: Integer;
  ShowGrid: Boolean;
  GridSize: Integer;
  ShowExplorer: Boolean;
  ShowProperties: Boolean;
  { Arbre de ressources }
  TreeNodes: Array[1..256] Of TTreeNodeState;
  TreeNodeCount: Integer;
  TreeSelectedNode: Integer;   { Noeud selectionne dans l'arbre }
  TreeScrollPos: Integer;      { Position de defilement vertical }
  { Etats d'expansion par type de ressource }
  TreeExpanded: Array[1..16] Of Boolean; { Expansion par RT_xxx }
 End;

 { Etat de l'editeur de dialogues WYSIWYG }
 TDialogEditorState = Record
  DialogIndex: Integer;       { Index du dialogue en cours d'edition }
  SelectedControl: Integer;   { Index du controle selectionne (-1 = aucun, 0 = dialogue) }
  DragMode: Integer;          { 0=aucun, 1=deplacement, 2=redim }
  DragStartX, DragStartY: Integer;
  DragOffsetX, DragOffsetY: Integer;
  ResizeHandle: Integer;      { 0-7 pour les 8 poignees de redim }
  PaletteSelection: Integer;  { Type de controle dans la palette }
  ShowHandles: Boolean;       { Afficher les poignees de selection }
 End;

 { Types de controles pour la palette WYSIWYG }
Const
 CTRL_PUSHBUTTON   = 0;
 CTRL_DEFPUSHBUTTON= 1;
 CTRL_CHECKBOX     = 2;
 CTRL_RADIOBUTTON  = 3;
 CTRL_EDITTEXT     = 4;
 CTRL_COMBOBOX     = 5;
 CTRL_LISTBOX      = 6;
 CTRL_SCROLLBAR    = 7;
 CTRL_STATIC       = 8;
 CTRL_GROUPBOX     = 9;
 CTRL_ICON         = 10;

Type
 { Type pour le buffer de fichier RSC alloue sur le tas }
 TRSCFileBuffer = Array[0..65535] Of Byte;
 PRSCFileBuffer = ^TRSCFileBuffer;

Var
 { Mode graphique }
 GrDriver, GrMode: Integer;

 { Souris }
 MouseX, MouseY: LongInt;
 MouseButton: LongInt;
 MouseVisible: Boolean;
 LastMouseX, LastMouseY: LongInt;
 LastMouseBtn: LongInt;

 { Interface utilisateur }
 MainMenuBar: TMenuBar;
 Windows: Array[1..MAX_WINDOWS] Of TWindow;
 WindowCount: Integer;
 ActiveWindowIndex: Integer;

 { Ressources du projet }
 Resources: Array[1..MAX_RESOURCES] Of TResourceEntry;
 ResourceCount: Integer;

 { Donnees des ressources }
 Dialogs: Array[1..64] Of TDialogData;
 DialogCount: Integer;
 ResMenus: Array[1..64] Of TMenuData;
 MenuDataCount: Integer;
 StringEntries: Array[1..MAX_STRINGS] Of TStringEntry;
 StringCount: Integer;
 Accels: Array[1..MAX_ACCEL] Of TAccelEntry;
 AccelCount: Integer;
 VersionInfos: Array[1..16] Of TVersionInfo;
 VersionCount: Integer;
 Bitmaps: Array[1..32] Of TBitmapData;
 BitmapCount: Integer;
 Icons: Array[1..32] Of TIconData;
 IconCount: Integer;
 Cursors: Array[1..16] Of TCursorData;
 CursorCount: Integer;

 { Donnees GEM RSC importees }
 RSCData: TRSCData;
 RSCFileBuffer: PRSCFileBuffer; { Alloue sur le tas avec GetMem/FreeMem }

 { Presse-papiers }
 Clipboard: TClipboard;

 { Etat de l'application }
 AppState: TAppState;

 { Etat de l'editeur WYSIWYG de dialogues }
 DlgEdState: TDialogEditorState;

 { Boucle principale }
 Running: Boolean;
 NeedRedraw: Boolean;

{ ============================================================
  TODO 01 - INITIALISATION DU MODE GRAPHIQUE VGA
  ============================================================ }

Procedure InitializeGraphics;
Var
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  GrDriver := VGA;
  GrMode := VGAHi;
 {$ELSE}
  GrDriver := Detect;
  GrMode := VGAHi;
 {$ENDIF}
 InitGraph(GrDriver, GrMode, '');
 ErrCode := GraphResult;
 If ErrCode = grOk Then Begin
  SetColor(White);
  SetBkColor(COLOR_BACKGROUND);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetFillStyle(SolidFill, COLOR_BACKGROUND);
  Bar(0, 0, GetMaxX, GetMaxY);
 End
 Else Begin
  WriteLn('Erreur graphique : ', GraphErrorMsg(ErrCode));
  Halt(1);
 End;
End;

Procedure CloseGraphics;
Begin
 CloseGraph;
End;

{ ============================================================
  TODO 02 - SUPPORT SOURIS MULTIPLATEFORME
  ============================================================ }

{$IFNDEF FPC}
Function MouseDriverFound: Boolean;
Var
 Regs: Registers;
Begin
 Regs.AX := 0;
 Intr($33, Regs);
 MouseDriverFound := Regs.AX = $FFFF;
End;

Procedure ShowMouse;
Var
 Regs: Registers;
Begin
 If Not MouseVisible Then Begin
  Regs.AX := $0001;
  Intr($33, Regs);
  MouseVisible := True;
 End;
End;

Procedure HideMouse;
Var
 Regs: Registers;
Begin
 If MouseVisible Then Begin
  Regs.AX := $0002;
  Intr($33, Regs);
  MouseVisible := False;
 End;
End;

Procedure GetMouseState(Var X, Y, Button: LongInt);
Var
 Regs: Registers;
Begin
 Regs.AX := $0003;
 Intr($33, Regs);
 Button := Regs.BX;
 X := Regs.CX;
 Y := Regs.DX;
End;

Procedure SetMousePos(X, Y: LongInt);
Var
 Regs: Registers;
Begin
 Regs.AX := $0004;
 Regs.CX := Word(X);
 Regs.DX := Word(Y);
 Intr($33, Regs);
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: LongInt);
Var
 Regs: Registers;
Begin
 Regs.AX := $0007;
 Regs.CX := Word(X1);
 Regs.DX := Word(X2);
 Intr($33, Regs);
 Regs.AX := $0008;
 Regs.CX := Word(Y1);
 Regs.DX := Word(Y2);
 Intr($33, Regs);
End;

{$ELSE}
Function MouseDriverFound: Boolean;
Begin
 MouseDriverFound := True;
End;

Procedure ShowMouse;
Begin
 MouseVisible := True;
End;

Procedure HideMouse;
Begin
 MouseVisible := False;
End;

Procedure GetMouseStateFPC(Var X, Y, Button: LongInt);
Var
 MX, MY: LongInt;
 MB: LongInt;
Begin
 MB := 0;
 MX := 0;
 MY := 0;
 PtcMouse.GetMouseState(MX, MY, MB);
 X := MX;
 Y := MY;
 Button := MB;
End;

Procedure SetMousePos(X, Y: LongInt);
Begin
 { PtcMouse ne supporte pas cette fonction }
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: LongInt);
Begin
 { PtcMouse ne supporte pas cette fonction }
End;
{$ENDIF}

Procedure InitMouse;
Begin
 MouseVisible := False;
 MouseX := 320;
 MouseY := 240;
 MouseButton := 0;
 LastMouseX := 0;
 LastMouseY := 0;
 LastMouseBtn := 0;
 If MouseDriverFound Then Begin
  {$IFNDEF FPC}
  SetMouseBounds(0, 0, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1);
  SetMousePos(320, 240);
  {$ENDIF}
  ShowMouse;
 End;
End;

Procedure UpdateMouse;
Begin
 LastMouseX := MouseX;
 LastMouseY := MouseY;
 LastMouseBtn := MouseButton;
 {$IFDEF FPC}
 GetMouseStateFPC(MouseX, MouseY, MouseButton);
 {$ELSE}
 GetMouseState(MouseX, MouseY, MouseButton);
 {$ENDIF}
End;

Function MouseClicked: Boolean;
Begin
 MouseClicked := (MouseButton And 1 = 1) And (LastMouseBtn And 1 = 0);
End;

Function MouseRightClicked: Boolean;
Begin
 MouseRightClicked := (MouseButton And 2 = 2) And (LastMouseBtn And 2 = 0);
End;

Function MouseInRect(R: TRect): Boolean;
Begin
 MouseInRect := (MouseX >= R.X1) And (MouseX <= R.X2) And
                (MouseY >= R.Y1) And (MouseY <= R.Y2);
End;

{ ============================================================
  TODO 03 - SYSTEME DE FENETRAGE GUI
  ============================================================ }

Procedure Draw3DRect(X1, Y1, X2, Y2: Integer; Raised: Boolean);
Begin
 If Raised Then Begin
  SetColor(COLOR_BORDER3D_LIGHT);
  Line(X1, Y1, X2, Y1);
  Line(X1, Y1, X1, Y2);
  SetColor(COLOR_BORDER3D_DARK);
  Line(X2, Y1, X2, Y2);
  Line(X1, Y2, X2, Y2);
 End
 Else Begin
  SetColor(COLOR_BORDER3D_DARK);
  Line(X1, Y1, X2, Y1);
  Line(X1, Y1, X1, Y2);
  SetColor(COLOR_BORDER3D_LIGHT);
  Line(X2, Y1, X2, Y2);
  Line(X1, Y2, X2, Y2);
 End;
End;

Procedure DrawButton(X, Y, W, H: Integer; Caption: String; Pressed, Enabled: Boolean);
Var
 TextW, TextH: Integer;
 CX, CY: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(X, Y, X + W - 1, Y + H - 1);
 Draw3DRect(X, Y, X + W - 1, Y + H - 1, Not Pressed);
 If Enabled Then
  SetColor(COLOR_BUTTONTEXT)
 Else
  SetColor(COLOR_DISABLED);
 TextW := TextWidth(Caption);
 TextH := TextHeight(Caption);
 CX := X + (W - TextW) Div 2;
 CY := Y + (H - TextH) Div 2;
 If Pressed Then Begin
  Inc(CX);
  Inc(CY);
 End;
 OutTextXY(CX, CY, Caption);
End;

Procedure DrawCheckBox(X, Y: Integer; Checked: Boolean; Caption: String; Enabled: Boolean);
Const
 BoxSize = 12;
Begin
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + BoxSize - 1, Y + BoxSize - 1);
 Draw3DRect(X, Y, X + BoxSize - 1, Y + BoxSize - 1, False);
 If Checked Then Begin
  SetColor(COLOR_WINDOWTEXT);
  Line(X + 2, Y + 6, X + 4, Y + 9);
  Line(X + 4, Y + 9, X + 9, Y + 2);
 End;
 If Enabled Then
  SetColor(COLOR_WINDOWTEXT)
 Else
  SetColor(COLOR_DISABLED);
 OutTextXY(X + BoxSize + 4, Y + (BoxSize - TextHeight('X')) Div 2, Caption);
End;

Procedure DrawRadioButton(X, Y: Integer; Selected: Boolean; Caption: String; Enabled: Boolean);
Const
 Radius = 6;
Begin
 SetColor(COLOR_BORDER3D_DARK);
 Circle(X + Radius, Y + Radius, Radius);
 SetFillStyle(SolidFill, COLOR_WINDOW);
 FloodFill(X + Radius, Y + Radius, COLOR_BORDER3D_DARK);
 If Selected Then Begin
  SetFillStyle(SolidFill, COLOR_WINDOWTEXT);
  FillEllipse(X + Radius, Y + Radius, 3, 3);
 End;
 If Enabled Then
  SetColor(COLOR_WINDOWTEXT)
 Else
  SetColor(COLOR_DISABLED);
 OutTextXY(X + Radius * 2 + 4, Y + Radius - TextHeight('X') Div 2, Caption);
End;

Procedure DrawEditBox(X, Y, W: Integer; Text: String; Focused: Boolean);
Const
 Height = 20;
Begin
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + W - 1, Y + Height - 1);
 Draw3DRect(X, Y, X + W - 1, Y + Height - 1, False);
 SetColor(COLOR_WINDOWTEXT);
 If Length(Text) > 0 Then
  OutTextXY(X + 3, Y + (Height - TextHeight('X')) Div 2, Text);
 If Focused Then Begin
  SetColor(COLOR_WINDOWTEXT);
  Line(X + 3 + TextWidth(Text), Y + 3, X + 3 + TextWidth(Text), Y + Height - 4);
 End;
End;

Procedure DrawScrollBarV(X, Y, H: Integer; Pos, Max: Integer);
Const
 Width = 16;
 ArrowH = 16;
Var
 TrackH, ThumbY, ThumbH: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_SCROLLBAR);
 Bar(X, Y, X + Width - 1, Y + H - 1);
 DrawButton(X, Y, Width, ArrowH, '^', False, True);
 DrawButton(X, Y + H - ArrowH, Width, ArrowH, 'v', False, True);
 TrackH := H - 2 * ArrowH;
 Draw3DRect(X, Y + ArrowH, X + Width - 1, Y + H - ArrowH - 1, False);
 If Max > 0 Then Begin
  ThumbH := TrackH Div 4;
  If ThumbH < 10 Then ThumbH := 10;
  ThumbY := Y + ArrowH + (Pos * (TrackH - ThumbH)) Div Max;
  DrawButton(X + 1, ThumbY, Width - 2, ThumbH, '', False, True);
 End;
End;

Procedure DrawWindow(Var W: TWindow);
Var
 BtnX: Integer;
Begin
 If Not W.Visible Then Exit;
 HideMouse;
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(W.Bounds.X1, W.Bounds.Y1, W.Bounds.X2, W.Bounds.Y2);
 SetColor(COLOR_BORDER3D_DARK);
 Rectangle(W.Bounds.X1, W.Bounds.Y1, W.Bounds.X2, W.Bounds.Y2);
 Draw3DRect(W.Bounds.X1 + 1, W.Bounds.Y1 + 1, W.Bounds.X2 - 1, W.Bounds.Y2 - 1, True);
 If W.Active Then
  SetFillStyle(SolidFill, COLOR_TITLEBAR)
 Else
  SetFillStyle(SolidFill, COLOR_DISABLED);
 Bar(W.Bounds.X1 + 3, W.Bounds.Y1 + 3, W.Bounds.X2 - 3, W.Bounds.Y1 + 20);
 SetColor(COLOR_TITLETEXT);
 OutTextXY(W.Bounds.X1 + 6, W.Bounds.Y1 + 6, W.Title);
 BtnX := W.Bounds.X2 - 18;
 If W.HasCloseBtn Then Begin
  DrawButton(BtnX, W.Bounds.Y1 + 4, 14, 14, 'X', False, True);
  Dec(BtnX, 16);
 End;
 If W.HasMaxBtn Then Begin
  DrawButton(BtnX, W.Bounds.Y1 + 4, 14, 14, '[]', False, True);
  Dec(BtnX, 16);
 End;
 If W.HasMinBtn Then Begin
  DrawButton(BtnX, W.Bounds.Y1 + 4, 14, 14, '_', False, True);
 End;
 W.ClientArea.X1 := W.Bounds.X1 + 4;
 W.ClientArea.Y1 := W.Bounds.Y1 + 22;
 W.ClientArea.X2 := W.Bounds.X2 - 4;
 W.ClientArea.Y2 := W.Bounds.Y2 - 4;
 ShowMouse;
End;

Procedure DrawAllWindows;
Var
 I: Integer;
Begin
 For I := 1 To WindowCount Do
  DrawWindow(Windows[I]);
End;

Function CreateWindow(ATitle: String; X, Y, W, H: Integer; WndType: Integer): Integer;
Var
 I: Integer;
Begin
 If WindowCount < MAX_WINDOWS Then Begin
  Inc(WindowCount);
  With Windows[WindowCount] Do Begin
   Title := ATitle;
   Bounds.X1 := X;
   Bounds.Y1 := Y;
   Bounds.X2 := X + W - 1;
   Bounds.Y2 := Y + H - 1;
   Visible := True;
   Active := True;
   Moveable := True;
   Resizable := True;
   HasCloseBtn := True;
   HasMinBtn := True;
   HasMaxBtn := True;
   Minimized := False;
   Maximized := False;
   WindowType := WndType;
   ResourceIndex := 0;
  End;
  For I := 1 To WindowCount - 1 Do
   Windows[I].Active := False;
  ActiveWindowIndex := WindowCount;
  CreateWindow := WindowCount;
 End
 Else
  CreateWindow := 0;
End;

Procedure CloseWindow(Index: Integer);
Var
 I: Integer;
Begin
 If (Index >= 1) And (Index <= WindowCount) Then Begin
  For I := Index To WindowCount - 1 Do
   Windows[I] := Windows[I + 1];
  Dec(WindowCount);
  If WindowCount > 0 Then Begin
   ActiveWindowIndex := WindowCount;
   Windows[WindowCount].Active := True;
  End
  Else
   ActiveWindowIndex := 0;
  NeedRedraw := True;
 End;
End;

Procedure ActivateWindow(Index: Integer);
Var
 I: Integer;
Begin
 If (Index >= 1) And (Index <= WindowCount) Then Begin
  For I := 1 To WindowCount Do
   Windows[I].Active := (I = Index);
  ActiveWindowIndex := Index;
  NeedRedraw := True;
 End;
End;

{ ============================================================
  TODO 04 - BARRE DE MENUS PRINCIPALE
  ============================================================ }

Procedure InitMenuBar;
Begin
 With MainMenuBar Do Begin
  Count := 8;
  ActiveMenu := 0;
  MenuOpen := False;

  Titles[1] := 'Fichier';
  With Menus[1] Do Begin
   Count := 8;
   Items[1].Caption := 'Nouveau'; Items[1].Shortcut := 'Ctrl+N'; Items[1].CommandId := CMD_FILE_NEW; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Ouvrir...'; Items[2].Shortcut := 'Ctrl+O'; Items[2].CommandId := CMD_FILE_OPEN; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := 'Sauvegarder'; Items[3].Shortcut := 'Ctrl+S'; Items[3].CommandId := CMD_FILE_SAVE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := False;
   Items[4].Caption := 'Sauvegarder sous...'; Items[4].Shortcut := ''; Items[4].CommandId := CMD_FILE_SAVEAS; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Items[5].Caption := '-'; Items[5].Shortcut := ''; Items[5].CommandId := CMD_NONE; Items[5].Enabled := True; Items[5].Checked := False; Items[5].IsSeparator := True;
   Items[6].Caption := 'Importer Mac...'; Items[6].Shortcut := ''; Items[6].CommandId := CMD_FILE_IMPORT_MAC; Items[6].Enabled := True; Items[6].Checked := False; Items[6].IsSeparator := False;
   Items[7].Caption := 'Importer GEM...'; Items[7].Shortcut := ''; Items[7].CommandId := CMD_FILE_IMPORT_GEM; Items[7].Enabled := True; Items[7].Checked := False; Items[7].IsSeparator := False;
   Items[8].Caption := 'Quitter'; Items[8].Shortcut := 'Alt+F4'; Items[8].CommandId := CMD_FILE_EXIT; Items[8].Enabled := True; Items[8].Checked := False; Items[8].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[2] := 'Edition';
  With Menus[2] Do Begin
   Count := 6;
   Items[1].Caption := 'Annuler'; Items[1].Shortcut := 'Ctrl+Z'; Items[1].CommandId := CMD_EDIT_UNDO; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := '-'; Items[2].Shortcut := ''; Items[2].CommandId := CMD_NONE; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := True;
   Items[3].Caption := 'Couper'; Items[3].Shortcut := 'Ctrl+X'; Items[3].CommandId := CMD_EDIT_CUT; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := False;
   Items[4].Caption := 'Copier'; Items[4].Shortcut := 'Ctrl+C'; Items[4].CommandId := CMD_EDIT_COPY; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Items[5].Caption := 'Coller'; Items[5].Shortcut := 'Ctrl+V'; Items[5].CommandId := CMD_EDIT_PASTE; Items[5].Enabled := True; Items[5].Checked := False; Items[5].IsSeparator := False;
   Items[6].Caption := 'Supprimer'; Items[6].Shortcut := 'Suppr'; Items[6].CommandId := CMD_EDIT_DELETE; Items[6].Enabled := True; Items[6].Checked := False; Items[6].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[3] := 'Format';
  With Menus[3] Do Begin
   Count := 4;
   Items[1].Caption := 'Police...'; Items[1].Shortcut := ''; Items[1].CommandId := CMD_FORMAT_FONT; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Alignement'; Items[2].Shortcut := ''; Items[2].CommandId := CMD_FORMAT_ALIGN; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := 'Taille...'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_FORMAT_SIZE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := False;
   Items[4].Caption := 'Couleurs...'; Items[4].Shortcut := ''; Items[4].CommandId := CMD_FORMAT_COLORS; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[4] := 'Vue';
  With Menus[4] Do Begin
   Count := 5;
   Items[1].Caption := 'Explorateur'; Items[1].Shortcut := 'F3'; Items[1].CommandId := CMD_VIEW_EXPLORER; Items[1].Enabled := True; Items[1].Checked := True; Items[1].IsSeparator := False;
   Items[2].Caption := 'Proprietes'; Items[2].Shortcut := 'F4'; Items[2].CommandId := CMD_VIEW_PROPERTIES; Items[2].Enabled := True; Items[2].Checked := True; Items[2].IsSeparator := False;
   Items[3].Caption := '-'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_NONE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := True;
   Items[4].Caption := 'Zoom avant'; Items[4].Shortcut := 'Ctrl++'; Items[4].CommandId := CMD_VIEW_ZOOMIN; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Items[5].Caption := 'Zoom arriere'; Items[5].Shortcut := 'Ctrl+-'; Items[5].CommandId := CMD_VIEW_ZOOMOUT; Items[5].Enabled := True; Items[5].Checked := False; Items[5].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[5] := 'Projet';
  With Menus[5] Do Begin
   Count := 5;
   Items[1].Caption := 'Ajouter ressource...'; Items[1].Shortcut := 'Ins'; Items[1].CommandId := CMD_PROJECT_ADDRES; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Supprimer ressource'; Items[2].Shortcut := 'Suppr'; Items[2].CommandId := CMD_PROJECT_DELRES; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := '-'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_NONE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := True;
   Items[4].Caption := 'Compiler'; Items[4].Shortcut := 'F9'; Items[4].CommandId := CMD_PROJECT_COMPILE; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Items[5].Caption := 'Verifier'; Items[5].Shortcut := ''; Items[5].CommandId := CMD_PROJECT_VERIFY; Items[5].Enabled := True; Items[5].Checked := False; Items[5].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[6] := 'Options';
  With Menus[6] Do Begin
   Count := 3;
   Items[1].Caption := 'Preferences...'; Items[1].Shortcut := ''; Items[1].CommandId := CMD_OPTIONS_PREFS; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Compilateur...'; Items[2].Shortcut := ''; Items[2].CommandId := CMD_OPTIONS_COMPILER; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := 'Couleurs IDE...'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_OPTIONS_COLORS; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[7] := 'Outils';
  With Menus[7] Do Begin
   Count := 3;
   Items[1].Caption := 'Editeur hexadecimal'; Items[1].Shortcut := ''; Items[1].CommandId := CMD_TOOLS_HEXEDIT; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Comparer ressources'; Items[2].Shortcut := ''; Items[2].CommandId := CMD_TOOLS_COMPARE; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := 'Valider'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_TOOLS_VALIDATE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;

  Titles[8] := 'Aide';
  With Menus[8] Do Begin
   Count := 4;
   Items[1].Caption := 'Index'; Items[1].Shortcut := 'F1'; Items[1].CommandId := CMD_HELP_INDEX; Items[1].Enabled := True; Items[1].Checked := False; Items[1].IsSeparator := False;
   Items[2].Caption := 'Recherche...'; Items[2].Shortcut := ''; Items[2].CommandId := CMD_HELP_SEARCH; Items[2].Enabled := True; Items[2].Checked := False; Items[2].IsSeparator := False;
   Items[3].Caption := '-'; Items[3].Shortcut := ''; Items[3].CommandId := CMD_NONE; Items[3].Enabled := True; Items[3].Checked := False; Items[3].IsSeparator := True;
   Items[4].Caption := 'A propos...'; Items[4].Shortcut := ''; Items[4].CommandId := CMD_HELP_ABOUT; Items[4].Enabled := True; Items[4].Checked := False; Items[4].IsSeparator := False;
   Visible := False;
   SelectedItem := 0;
  End;
 End;
End;

Procedure DrawMenuBar;
Var
 I, X: Integer;
Begin
 HideMouse;
 SetFillStyle(SolidFill, COLOR_MENUBAR);
 Bar(0, 0, SCREEN_WIDTH - 1, MENU_BAR_HEIGHT - 1);
 Draw3DRect(0, 0, SCREEN_WIDTH - 1, MENU_BAR_HEIGHT - 1, True);
 X := 8;
 For I := 1 To MainMenuBar.Count Do Begin
  If MainMenuBar.ActiveMenu = I Then Begin
   SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
   Bar(X - 4, 2, X + TextWidth(MainMenuBar.Titles[I]) + 4, MENU_BAR_HEIGHT - 3);
   SetColor(COLOR_HIGHLIGHTTEXT);
  End
  Else Begin
   SetColor(COLOR_MENUTEXT);
  End;
  OutTextXY(X, 5, MainMenuBar.Titles[I]);
  MainMenuBar.Menus[I].X := X - 4;
  X := X + TextWidth(MainMenuBar.Titles[I]) + 16;
 End;
 ShowMouse;
End;

Procedure DrawDropDownMenu(MenuIndex: Integer);
Var
 I, Y, MaxW, ItemH: Integer;
Begin
 If (MenuIndex < 1) Or (MenuIndex > MainMenuBar.Count) Then Exit;
 If Not MainMenuBar.Menus[MenuIndex].Visible Then Exit;
 HideMouse;
 MaxW := 100;
 For I := 1 To MainMenuBar.Menus[MenuIndex].Count Do Begin
  If TextWidth(MainMenuBar.Menus[MenuIndex].Items[I].Caption + '  ' + MainMenuBar.Menus[MenuIndex].Items[I].Shortcut) + 20 > MaxW Then
   MaxW := TextWidth(MainMenuBar.Menus[MenuIndex].Items[I].Caption + '  ' + MainMenuBar.Menus[MenuIndex].Items[I].Shortcut) + 20;
 End;
 ItemH := 18;
 MainMenuBar.Menus[MenuIndex].W := MaxW;
 MainMenuBar.Menus[MenuIndex].H := MainMenuBar.Menus[MenuIndex].Count * ItemH + 4;
 MainMenuBar.Menus[MenuIndex].Y := MENU_BAR_HEIGHT;
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(MainMenuBar.Menus[MenuIndex].X, MainMenuBar.Menus[MenuIndex].Y, MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W, MainMenuBar.Menus[MenuIndex].Y + MainMenuBar.Menus[MenuIndex].H);
 SetColor(COLOR_BORDER3D_DARK);
 Rectangle(MainMenuBar.Menus[MenuIndex].X, MainMenuBar.Menus[MenuIndex].Y, MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W, MainMenuBar.Menus[MenuIndex].Y + MainMenuBar.Menus[MenuIndex].H);
 Draw3DRect(MainMenuBar.Menus[MenuIndex].X + 1, MainMenuBar.Menus[MenuIndex].Y + 1, MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W - 1, MainMenuBar.Menus[MenuIndex].Y + MainMenuBar.Menus[MenuIndex].H - 1, True);
 Y := MainMenuBar.Menus[MenuIndex].Y + 2;
 For I := 1 To MainMenuBar.Menus[MenuIndex].Count Do Begin
  If MainMenuBar.Menus[MenuIndex].Items[I].IsSeparator Then Begin
   SetColor(COLOR_BORDER3D_DARK);
   Line(MainMenuBar.Menus[MenuIndex].X + 2, Y + ItemH Div 2, MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W - 2, Y + ItemH Div 2);
  End
  Else Begin
   If MainMenuBar.Menus[MenuIndex].SelectedItem = I Then Begin
    SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
    Bar(MainMenuBar.Menus[MenuIndex].X + 2, Y, MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W - 2, Y + ItemH - 1);
    SetColor(COLOR_HIGHLIGHTTEXT);
   End
   Else If MainMenuBar.Menus[MenuIndex].Items[I].Enabled Then
    SetColor(COLOR_MENUTEXT)
   Else
    SetColor(COLOR_DISABLED);
   OutTextXY(MainMenuBar.Menus[MenuIndex].X + 6, Y + 2, MainMenuBar.Menus[MenuIndex].Items[I].Caption);
   If MainMenuBar.Menus[MenuIndex].Items[I].Shortcut <> '' Then
    OutTextXY(MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W - TextWidth(MainMenuBar.Menus[MenuIndex].Items[I].Shortcut) - 6, Y + 2, MainMenuBar.Menus[MenuIndex].Items[I].Shortcut);
   If MainMenuBar.Menus[MenuIndex].Items[I].Checked Then Begin
    SetColor(COLOR_MENUTEXT);
    OutTextXY(MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W - 16, Y + 2, '*');
   End;
  End;
  Inc(Y, ItemH);
 End;
 ShowMouse;
End;

Function GetMenuAtPos(X, Y: Integer): Integer;
Var
 I, MX: Integer;
Begin
 GetMenuAtPos := 0;
 If Y > MENU_BAR_HEIGHT Then Exit;
 MX := 8;
 For I := 1 To MainMenuBar.Count Do Begin
  If (X >= MX - 4) And (X < MX + TextWidth(MainMenuBar.Titles[I]) + 8) Then Begin
   GetMenuAtPos := I;
   Exit;
  End;
  MX := MX + TextWidth(MainMenuBar.Titles[I]) + 16;
 End;
End;

Function GetMenuItemAtPos(MenuIndex: Integer; X, Y: Integer): Integer;
Var
 ItemH, I, ItemY: Integer;
Begin
 GetMenuItemAtPos := 0;
 If (MenuIndex < 1) Or (MenuIndex > MainMenuBar.Count) Then Exit;
 If Not MainMenuBar.Menus[MenuIndex].Visible Then Exit;
 If (X < MainMenuBar.Menus[MenuIndex].X) Or (X > MainMenuBar.Menus[MenuIndex].X + MainMenuBar.Menus[MenuIndex].W) Or (Y < MainMenuBar.Menus[MenuIndex].Y) Or (Y > MainMenuBar.Menus[MenuIndex].Y + MainMenuBar.Menus[MenuIndex].H) Then Exit;
 ItemH := 18;
 ItemY := MainMenuBar.Menus[MenuIndex].Y + 2;
 For I := 1 To MainMenuBar.Menus[MenuIndex].Count Do Begin
  If (Y >= ItemY) And (Y < ItemY + ItemH) Then Begin
   If Not MainMenuBar.Menus[MenuIndex].Items[I].IsSeparator Then
    GetMenuItemAtPos := I;
   Exit;
  End;
  Inc(ItemY, ItemH);
 End;
End;

Procedure CloseAllMenus;
Var
 I: Integer;
Begin
 For I := 1 To MainMenuBar.Count Do Begin
  MainMenuBar.Menus[I].Visible := False;
  MainMenuBar.Menus[I].SelectedItem := 0;
 End;
 MainMenuBar.ActiveMenu := 0;
 MainMenuBar.MenuOpen := False;
 NeedRedraw := True;
End;

Function HandleMenuClick(X, Y: Integer): Integer;
Var
 MenuIdx, ItemIdx: Integer;
Begin
 HandleMenuClick := CMD_NONE;
 MenuIdx := GetMenuAtPos(X, Y);
 If MenuIdx > 0 Then Begin
  If MainMenuBar.MenuOpen And (MainMenuBar.ActiveMenu = MenuIdx) Then Begin
   CloseAllMenus;
  End
  Else Begin
   CloseAllMenus;
   MainMenuBar.ActiveMenu := MenuIdx;
   MainMenuBar.Menus[MenuIdx].Visible := True;
   MainMenuBar.MenuOpen := True;
   NeedRedraw := True;
  End;
 End
 Else If MainMenuBar.MenuOpen Then Begin
  ItemIdx := GetMenuItemAtPos(MainMenuBar.ActiveMenu, X, Y);
  If ItemIdx > 0 Then Begin
   If MainMenuBar.Menus[MainMenuBar.ActiveMenu].Items[ItemIdx].Enabled Then Begin
    HandleMenuClick := MainMenuBar.Menus[MainMenuBar.ActiveMenu].Items[ItemIdx].CommandId;
    CloseAllMenus;
   End;
  End
  Else Begin
   CloseAllMenus;
  End;
 End;
End;

Procedure UpdateMenuHighlight(X, Y: Integer);
Var
 MenuIdx, ItemIdx, OldItem: Integer;
Begin
 If Not MainMenuBar.MenuOpen Then Exit;
 MenuIdx := GetMenuAtPos(X, Y);
 If (MenuIdx > 0) And (MenuIdx <> MainMenuBar.ActiveMenu) Then Begin
  MainMenuBar.Menus[MainMenuBar.ActiveMenu].Visible := False;
  MainMenuBar.Menus[MainMenuBar.ActiveMenu].SelectedItem := 0;
  MainMenuBar.ActiveMenu := MenuIdx;
  MainMenuBar.Menus[MenuIdx].Visible := True;
  NeedRedraw := True;
 End
 Else Begin
  OldItem := MainMenuBar.Menus[MainMenuBar.ActiveMenu].SelectedItem;
  ItemIdx := GetMenuItemAtPos(MainMenuBar.ActiveMenu, X, Y);
  If ItemIdx <> OldItem Then Begin
   MainMenuBar.Menus[MainMenuBar.ActiveMenu].SelectedItem := ItemIdx;
   NeedRedraw := True;
  End;
 End;
End;

{ ============================================================
  TODO 05-10 - FONCTIONS UTILITAIRES POUR FICHIERS
  ============================================================ }

Function UpCaseStr(Const S: String): String;
Var
 I: Integer;
 R: String;
Begin
 R := S;
 For I := 1 To Length(R) Do
  If (R[I] >= 'a') And (R[I] <= 'z') Then
   R[I] := Chr(Ord(R[I]) - 32);
 UpCaseStr := R;
End;

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function FileExists(Const FName: String): Boolean;
Var
 F: File;
Begin
 {$I-}
 Assign(F, FName);
 Reset(F, 1);
 {$I+}
 If IOResult = 0 Then Begin
  Close(F);
  FileExists := True;
 End
 Else
  FileExists := False;
End;

Function ChangeFileExt(Const FName, NewExt: String): String;
Var
 I: Integer;
 BaseName: String;
Begin
 BaseName := FName;
 For I := Length(FName) DownTo 1 Do Begin
  If FName[I] = '.' Then Begin
   BaseName := Copy(FName, 1, I - 1);
   Break;
  End;
  If (FName[I] = '\') Or (FName[I] = '/') Then Break;
 End;
 ChangeFileExt := BaseName + NewExt;
End;

{ Lecture fichiers RES }
Var
 ResFile: File;
 ResFileSize: LongInt;
 ResFilePos: LongInt;

Procedure OpenResFile(Const FName: String);
Begin
 {$I-}
 Assign(ResFile, FName);
 Reset(ResFile, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  CloseGraphics;
  WriteLn('Erreur: Impossible d''ouvrir ', FName);
  Halt(1);
 End;
 Seek(ResFile, FileSize(ResFile));
 ResFileSize := FilePos(ResFile);
 Seek(ResFile, 0);
 ResFilePos := 0;
End;

Procedure CloseResFile;
Begin
 Close(ResFile);
End;

Function ReadResByte: Byte;
Var
 B: Byte;
Begin
 BlockRead(ResFile, B, 1);
 Inc(ResFilePos);
 ReadResByte := B;
End;

Function ReadResWord: Word;
Var
 B1, B2: Byte;
Begin
 B1 := ReadResByte;
 B2 := ReadResByte;
 ReadResWord := B1 + Word(B2) * 256;
End;

Function ReadResDWord: LongInt;
Var
 W1, W2: Word;
Begin
 W1 := ReadResWord;
 W2 := ReadResWord;
 ReadResDWord := LongInt(W1) Or (LongInt(W2) Shl 16);
End;

Function DetectResFormat: Integer;
Var
 D1, D2, D3, D4: LongInt;
 SavePos: LongInt;
Begin
 SavePos := ResFilePos;
 D1 := ReadResDWord;
 D2 := ReadResDWord;
 D3 := ReadResDWord;
 D4 := ReadResDWord;
 Seek(ResFile, SavePos);
 ResFilePos := SavePos;
 If (D1 = 0) And (D2 = 32) Then
  DetectResFormat := 2
 Else
  DetectResFormat := 1;
End;

{ Lecture d'une chaine UTF-16LE terminee par null et conversion en ANSI.
  Note: Supporte uniquement les caracteres du Basic Multilingual Plane dans
  la plage U+0000 a U+00FF (Latin-1). Les caracteres hors de cette plage
  sont silencieusement ignores. }
Function ReadResUnicodeString: String;
Var
 S: String;
 W: Word;
Begin
 S := '';
 Repeat
  W := ReadResWord;
  If (W <> 0) And (W < 256) And (Length(S) < 255) Then
   S := S + Chr(W);
 Until W = 0;
 ReadResUnicodeString := S;
End;

{ Lecture d'une chaine UTF-16LE avec longueur prefixee (format STRINGTABLE).
  Memes limitations que ReadResUnicodeString concernant les caracteres. }
Function ReadResCountedString: String;
Var
 S: String;
 Len: Word;
 I: Integer;
 W: Word;
Begin
 S := '';
 Len := ReadResWord;
 For I := 1 To Len Do Begin
  W := ReadResWord;
  If (W < 256) And (Length(S) < 255) Then
   S := S + Chr(W);
 End;
 ReadResCountedString := S;
End;

{ Alignement sur DWORD lors de la lecture }
Procedure AlignResDWord;
Var
 Padding: Integer;
Begin
 Padding := (4 - (ResFilePos Mod 4)) Mod 4;
 If Padding > 0 Then Begin
  Seek(ResFile, ResFilePos + Padding);
  ResFilePos := ResFilePos + Padding;
 End;
End;

{ Lecture d'un dialogue depuis le fichier RES 32-bit }
Procedure ReadResDialog(DataSize: LongInt; ResId: Word);
Var
 StartPos: LongInt;
 DlgIdx, I: Integer;
 ControlCount: Word;
 W: Word;
Begin
 If DialogCount >= 64 Then Exit;

 StartPos := ResFilePos;
 Inc(DialogCount);
 DlgIdx := DialogCount;

 { Initialiser le dialogue }
 FillChar(Dialogs[DlgIdx], SizeOf(TDialogData), 0);

 { DLGTEMPLATE }
 Dialogs[DlgIdx].Style := ReadResDWord;
 Dialogs[DlgIdx].ExStyle := ReadResDWord;
 ControlCount := ReadResWord;
 Dialogs[DlgIdx].X := ReadResWord;
 Dialogs[DlgIdx].Y := ReadResWord;
 Dialogs[DlgIdx].W := ReadResWord;
 Dialogs[DlgIdx].H := ReadResWord;

 { Menu (ignorer) }
 W := ReadResWord;
 If W = $FFFF Then
  ReadResWord  { ID numerique }
 Else If W <> 0 Then Begin
  { Chaine Unicode - deja lu le premier caractere }
  While ReadResWord <> 0 Do;
 End;

 { Classe de fenetre (ignorer) }
 W := ReadResWord;
 If W = $FFFF Then
  ReadResWord
 Else If W <> 0 Then Begin
  While ReadResWord <> 0 Do;
 End;

 { Titre du dialogue }
 Dialogs[DlgIdx].Caption := ReadResUnicodeString;

 { Police (si DS_SETFONT = $40) }
 If (Dialogs[DlgIdx].Style And $40) <> 0 Then Begin
  Dialogs[DlgIdx].FontSize := ReadResWord;
  Dialogs[DlgIdx].FontName := ReadResUnicodeString;
 End;

 { Lire les controles }
 Dialogs[DlgIdx].ControlCount := 0;
 For I := 1 To ControlCount Do Begin
  If Dialogs[DlgIdx].ControlCount >= MAX_CONTROLS Then Break;

  { Alignement DWORD }
  AlignResDWord;

  Inc(Dialogs[DlgIdx].ControlCount);

  { DLGITEMTEMPLATE }
  Dialogs[DlgIdx].Controls[I].Style := ReadResDWord;
  Dialogs[DlgIdx].Controls[I].ExStyle := ReadResDWord;
  Dialogs[DlgIdx].Controls[I].X := ReadResWord;
  Dialogs[DlgIdx].Controls[I].Y := ReadResWord;
  Dialogs[DlgIdx].Controls[I].W := ReadResWord;
  Dialogs[DlgIdx].Controls[I].H := ReadResWord;
  Dialogs[DlgIdx].Controls[I].CtrlId := ReadResWord;

  { Classe du controle }
  W := ReadResWord;
  If W = $FFFF Then Begin
   Dialogs[DlgIdx].Controls[I].CtrlType := ReadResWord - $80;
  End Else Begin
   Dialogs[DlgIdx].Controls[I].CtrlType := 0;
   If W <> 0 Then
    While ReadResWord <> 0 Do;
  End;

  { Texte du controle }
  Dialogs[DlgIdx].Controls[I].Text := ReadResUnicodeString;

  { Extra bytes }
  W := ReadResWord;
  If W > 0 Then Begin
   Seek(ResFile, ResFilePos + W);
   ResFilePos := ResFilePos + W;
  End;
 End;

 { Ajouter a la liste des ressources }
 If ResourceCount < MAX_RESOURCES Then Begin
  Inc(ResourceCount);
  Resources[ResourceCount].ResType := RT_DIALOG;
  Resources[ResourceCount].ResId.IsNumeric := True;
  Resources[ResourceCount].ResId.NumId := ResId;
  Resources[ResourceCount].ResId.StrId := '';
  Resources[ResourceCount].DataSize := DataSize;
  Resources[ResourceCount].DataOffset := StartPos;
  Resources[ResourceCount].LangId := $0409;
 End;
End;

{ Lecture d'un menu depuis le fichier RES 32-bit }
Procedure ReadResMenu(DataSize: LongInt; ResId: Word);
Var
 StartPos: LongInt;
 MenuIdx: Integer;
 Flags, ItemId: Word;
 Level: Integer;
Begin
 If MenuDataCount >= 64 Then Exit;

 StartPos := ResFilePos;
 Inc(MenuDataCount);
 MenuIdx := MenuDataCount;

 { Initialiser le menu }
 FillChar(ResMenus[MenuIdx], SizeOf(TMenuData), 0);

 { MENUHEADER }
 ReadResWord; { Version }
 ReadResWord; { Offset }

 { Lire les items }
 Level := 0;
 While (ResFilePos < StartPos + DataSize) And (ResMenus[MenuIdx].ItemCount < MAX_MENU_ITEMS_RES) Do Begin
  Flags := ReadResWord;

  If (Flags And $10) = 0 Then { Pas un POPUP }
   ItemId := ReadResWord
  Else
   ItemId := 0;

  Inc(ResMenus[MenuIdx].ItemCount);
  ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].Flags := Flags;
  ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].ItemId := ItemId;
  ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].Text := ReadResUnicodeString;
  ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].Level := Level;

  If (Flags And $10) <> 0 Then { POPUP }
   Inc(Level);
  If (Flags And $80) <> 0 Then { MF_END }
   Dec(Level);
  If Level < 0 Then Level := 0;
 End;

 { Ajouter a la liste des ressources }
 If ResourceCount < MAX_RESOURCES Then Begin
  Inc(ResourceCount);
  Resources[ResourceCount].ResType := RT_MENU;
  Resources[ResourceCount].ResId.IsNumeric := True;
  Resources[ResourceCount].ResId.NumId := ResId;
  Resources[ResourceCount].ResId.StrId := '';
  Resources[ResourceCount].DataSize := DataSize;
  Resources[ResourceCount].DataOffset := StartPos;
  Resources[ResourceCount].LangId := $0409;
 End;
End;

{ Lecture d'une table de chaines depuis le fichier RES 32-bit }
Procedure ReadResStringTable(DataSize: LongInt; BundleId: Word);
Var
 StartPos: LongInt;
 I: Integer;
 BaseId: Word;
 S: String;
Begin
 StartPos := ResFilePos;
 BaseId := (BundleId - 1) * 16;

 { Lire les 16 chaines du bundle }
 For I := 0 To 15 Do Begin
  If ResFilePos >= StartPos + DataSize Then Break;
  S := ReadResCountedString;
  If Length(S) > 0 Then Begin
   If StringCount < MAX_STRINGS Then Begin
    Inc(StringCount);
    StringEntries[StringCount].StringId := BaseId + I;
    StringEntries[StringCount].Text := S;
    StringEntries[StringCount].LangId := $0409;
   End;
  End;
 End;
End;

{ Chargement complet d'un fichier RES 32-bit }
Procedure LoadResFile(Const FileName: String);
Var
 Format: Integer;
 DataSize, HeaderSize: LongInt;
 ResType, ResId: Word;
 MemFlags, LangId: Word;
 W: Word;
 EndPos: LongInt;
Begin
 If Not FileExists(FileName) Then Exit;

 { Reinitialiser les donnees }
 ResourceCount := 0;
 DialogCount := 0;
 MenuDataCount := 0;
 StringCount := 0;

 OpenResFile(FileName);
 Format := DetectResFormat;
 AppState.Is32BitFormat := (Format = 2);

 If Format = 2 Then Begin
  { Sauter l'en-tete null }
  ReadResDWord; { DataSize = 0 }
  ReadResDWord; { HeaderSize = 32 }
  ReadResDWord; { Type }
  ReadResDWord; { Name }
  ReadResDWord; { DataVersion }
  ReadResWord;  { MemoryFlags }
  ReadResWord;  { LanguageId }
  ReadResDWord; { Version }
  ReadResDWord; { Characteristics }

  { Lire les ressources }
  While ResFilePos < ResFileSize Do Begin
   DataSize := ReadResDWord;
   HeaderSize := ReadResDWord;

   If (DataSize = 0) And (HeaderSize = 0) Then Break;

   { Type de ressource }
   W := ReadResWord;
   If W = $FFFF Then
    ResType := ReadResWord
   Else Begin
    ResType := 0;
    If W <> 0 Then
     While ReadResWord <> 0 Do;
   End;

   { ID de ressource }
   W := ReadResWord;
   If W = $FFFF Then
    ResId := ReadResWord
   Else Begin
    ResId := 0;
    If W <> 0 Then
     While ReadResWord <> 0 Do;
   End;

   { Alignement DWORD }
   AlignResDWord;

   { Lire le reste de l'en-tete }
   ReadResDWord;        { DataVersion }
   MemFlags := ReadResWord;  { MemoryFlags }
   LangId := ReadResWord;    { LanguageId }
   ReadResDWord;        { Version }
   ReadResDWord;        { Characteristics }

   EndPos := ResFilePos + DataSize;

   { Parser selon le type }
   Case ResType Of
    RT_DIALOG: ReadResDialog(DataSize, ResId);
    RT_MENU: ReadResMenu(DataSize, ResId);
    RT_STRING: ReadResStringTable(DataSize, ResId);
   Else
    { Sauter les donnees non supportees }
    Seek(ResFile, EndPos);
    ResFilePos := EndPos;
   End;

   { S'assurer qu'on est a la bonne position }
   If ResFilePos < EndPos Then Begin
    Seek(ResFile, EndPos);
    ResFilePos := EndPos;
   End;

   { Alignement DWORD entre ressources }
   AlignResDWord;
  End;
 End;

 CloseResFile;
End;

{ Ecriture fichiers RES }
Var
 OutResFile: File;

Procedure CreateOutResFile(Const FName: String);
Begin
 {$I-}
 Assign(OutResFile, FName);
 Rewrite(OutResFile, 1);
 {$I+}
End;

Procedure CloseOutResFile;
Begin
 Close(OutResFile);
End;

Procedure WriteResByte(B: Byte);
Begin
 BlockWrite(OutResFile, B, 1);
End;

Procedure WriteResWord(W: Word);
Begin
 WriteResByte(Lo(W));
 WriteResByte(Hi(W));
End;

Procedure WriteResDWord(D: LongInt);
Begin
 WriteResWord(Word(D And $FFFF));
 WriteResWord(Word((D Shr 16) And $FFFF));
End;

Procedure WriteNullHeader32;
Begin
 WriteResDWord(0);
 WriteResDWord(32);
 WriteResWord($FFFF);
 WriteResWord(0);
 WriteResWord($FFFF);
 WriteResWord(0);
 WriteResDWord(0);
 WriteResWord(0);
 WriteResWord(0);
 WriteResDWord(0);
 WriteResDWord(0);
End;

{ Ecriture d'une chaine ANSI vers UTF-16LE terminee par null.
  Note: Convertit caracteres ANSI (0-255) en UTF-16LE. Ne supporte pas
  les caracteres multi-octets ou l'encodage UTF-8 complet. }
Procedure WriteResString(Const S: String);
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  WriteResWord(Ord(S[I]));
 WriteResWord(0); { Terminateur null }
End;

{ Ecriture de l'en-tete d'une ressource 32-bit }
Procedure WriteResHeader32(DataSize: LongInt; ResType, ResId: Word; MemFlags: Word);
Var
 HeaderSize: LongInt;
Begin
 { En-tete de ressource 32-bit }
 HeaderSize := 32;
 WriteResDWord(DataSize);   { Taille des donnees }
 WriteResDWord(HeaderSize); { Taille de l'en-tete }
 WriteResWord($FFFF);       { Type = nombre }
 WriteResWord(ResType);     { Type de ressource }
 WriteResWord($FFFF);       { ID = nombre }
 WriteResWord(ResId);       { ID de ressource }
 WriteResDWord(0);          { Version des donnees }
 WriteResWord(MemFlags);    { Flags memoire }
 WriteResWord($0409);       { Language ID (US English) }
 WriteResDWord(0);          { Version }
 WriteResDWord(0);          { Caracteristiques }
End;

{ Calcul de la taille d'un dialogue en format binaire }
Function CalcDialogSize(DlgIdx: Integer): LongInt;
Var
 Size: LongInt;
 I: Integer;
Begin
 { DLGTEMPLATE de base: Style(4) + ExStyle(4) + ControlCount(2) +
   X(2) + Y(2) + CX(2) + CY(2) = 18 octets }
 Size := 18;
 { Menu, Class, Title - tous vides pour simplifier }
 Size := Size + 2 + 2 + (Length(Dialogs[DlgIdx].Caption) + 1) * 2;
 { Font si DS_SETFONT }
 If (Dialogs[DlgIdx].Style And $40) <> 0 Then Begin
  Size := Size + 2; { Font size }
  Size := Size + (Length(Dialogs[DlgIdx].FontName) + 1) * 2;
 End;
 { Controles }
 For I := 1 To Dialogs[DlgIdx].ControlCount Do Begin
  Size := Size + 18; { DLGITEMTEMPLATE }
  { Class, Title, Extra }
  Size := Size + 2 + (Length(Dialogs[DlgIdx].Controls[I].Text) + 1) * 2 + 2;
  { Aligner sur DWORD }
  If (Size Mod 4) <> 0 Then
   Size := Size + (4 - (Size Mod 4));
 End;
 CalcDialogSize := Size;
End;

{ Ecriture d'un dialogue au format ressource binaire 32-bit }
Procedure WriteResDialog(DlgIdx: Integer);
Var
 I, J: Integer;
 DataSize: LongInt;
 Padding: Integer;
Begin
 If (DlgIdx < 1) Or (DlgIdx > DialogCount) Then Exit;

 DataSize := CalcDialogSize(DlgIdx);
 WriteResHeader32(DataSize, RT_DIALOG, DlgIdx, $1030);

 { DLGTEMPLATE }
 WriteResDWord(Dialogs[DlgIdx].Style);   { Style }
 WriteResDWord(Dialogs[DlgIdx].ExStyle); { ExStyle }
 WriteResWord(Dialogs[DlgIdx].ControlCount); { Nombre de controles }
 WriteResWord(Dialogs[DlgIdx].X);        { X }
 WriteResWord(Dialogs[DlgIdx].Y);        { Y }
 WriteResWord(Dialogs[DlgIdx].W);        { CX }
 WriteResWord(Dialogs[DlgIdx].H);        { CY }
 WriteResWord(0);  { Menu - pas de menu }
 WriteResWord(0);  { Class - classe standard }
 WriteResString(Dialogs[DlgIdx].Caption); { Title }

 { Font (si DS_SETFONT est dans le style) }
 If (Dialogs[DlgIdx].Style And $40) <> 0 Then Begin
  WriteResWord(Dialogs[DlgIdx].FontSize);
  WriteResString(Dialogs[DlgIdx].FontName);
 End;

 { Controles }
 For I := 1 To Dialogs[DlgIdx].ControlCount Do Begin
  { Alignement sur DWORD avant chaque controle }
  { Calculer le padding necessaire une seule fois }
  Padding := (4 - (FilePos(OutResFile) Mod 4)) Mod 4;
  For J := 1 To Padding Do
   WriteResByte(0);

  WriteResDWord(Dialogs[DlgIdx].Controls[I].Style);   { Style }
  WriteResDWord(Dialogs[DlgIdx].Controls[I].ExStyle); { ExStyle }
  WriteResWord(Dialogs[DlgIdx].Controls[I].X);        { X }
  WriteResWord(Dialogs[DlgIdx].Controls[I].Y);        { Y }
  WriteResWord(Dialogs[DlgIdx].Controls[I].W);        { CX }
  WriteResWord(Dialogs[DlgIdx].Controls[I].H);        { CY }
  WriteResWord(Dialogs[DlgIdx].Controls[I].CtrlId);   { ID }

  { Class - utiliser type de controle comme classe predefinies }
  WriteResWord($FFFF);
  WriteResWord($0080 + Dialogs[DlgIdx].Controls[I].CtrlType); { Classe standard }

  { Title }
  WriteResString(Dialogs[DlgIdx].Controls[I].Text);

  { Extra bytes }
  WriteResWord(0);
 End;
End;

{ Ecriture d'un menu au format ressource binaire 32-bit }
Procedure WriteResMenu(MenuIdx: Integer);
Var
 I: Integer;
 DataSize: LongInt;
 Flags: Word;
Begin
 If (MenuIdx < 1) Or (MenuIdx > MenuDataCount) Then Exit;

 { Calculer taille }
 DataSize := 4; { Version + Offset }
 For I := 1 To ResMenus[MenuIdx].ItemCount Do Begin
  DataSize := DataSize + 2; { Flags }
  If ResMenus[MenuIdx].Items[I].ItemType <> 1 Then { Pas un POPUP }
   DataSize := DataSize + 2; { ID }
  DataSize := DataSize + (Length(ResMenus[MenuIdx].Items[I].Text) + 1) * 2;
 End;

 WriteResHeader32(DataSize, RT_MENU, MenuIdx, $1030);

 { MENUHEADER }
 WriteResWord(0); { Version }
 WriteResWord(0); { Offset vers premier item }

 { Items }
 For I := 1 To ResMenus[MenuIdx].ItemCount Do Begin
  Flags := ResMenus[MenuIdx].Items[I].Flags;
  { Dernier item du niveau }
  If I = ResMenus[MenuIdx].ItemCount Then
   Flags := Flags Or $80; { MF_END }

  WriteResWord(Flags);

  { ID seulement si pas un POPUP }
  If (Flags And $10) = 0 Then
   WriteResWord(ResMenus[MenuIdx].Items[I].ItemId);

  WriteResString(ResMenus[MenuIdx].Items[I].Text);
 End;
End;

{ Ecriture d'une table de chaines au format ressource binaire 32-bit }
Procedure WriteResStringTable;
Var
 I, J, BundleId: Integer;
 StringsInBundle: Array[0..15] Of String[255];
 DataSize: LongInt;
 HasStrings: Boolean;
Begin
 If StringCount = 0 Then Exit;

 { Parcourir par bundles de 16 chaines }
 For BundleId := 0 To 255 Do Begin
  { Initialiser bundle }
  For J := 0 To 15 Do
   StringsInBundle[J] := '';

  { Collecter les chaines pour ce bundle }
  HasStrings := False;
  For I := 1 To StringCount Do Begin
   If (StringEntries[I].StringId Div 16) = BundleId Then Begin
    StringsInBundle[StringEntries[I].StringId Mod 16] := StringEntries[I].Text;
    HasStrings := True;
   End;
  End;

  If HasStrings Then Begin
   { Calculer taille }
   DataSize := 0;
   For J := 0 To 15 Do
    DataSize := DataSize + 2 + Length(StringsInBundle[J]) * 2;

   WriteResHeader32(DataSize, RT_STRING, BundleId + 1, $1030);

   { Ecrire les 16 chaines du bundle }
   For J := 0 To 15 Do Begin
    WriteResWord(Length(StringsInBundle[J]));
    For I := 1 To Length(StringsInBundle[J]) Do
     WriteResWord(Ord(StringsInBundle[J][I]));
   End;
  End;
 End;
End;

{ Sauvegarde du fichier .RES complet }
Procedure SaveResFile(Const FileName: String; Is32Bit: Boolean);
Var
 I: Integer;
Begin
 CreateOutResFile(FileName);

 If Is32Bit Then Begin
  { Ecrire l'en-tete null requis par le format 32-bit }
  WriteNullHeader32;

  { Ecrire tous les dialogues }
  For I := 1 To DialogCount Do
   WriteResDialog(I);

  { Ecrire tous les menus }
  For I := 1 To MenuDataCount Do
   WriteResMenu(I);

  { Ecrire la table de chaines }
  WriteResStringTable;
 End;

 CloseOutResFile;
 AppState.ProjectModified := False;
End;

{ ============================================================
  LECTURE FICHIERS RC (Resource Script)
  ============================================================ }

Var
 RCFile: Text;
 RCLine: String;
 RCLineNum: Integer;
 RCTokenIndex: Integer;
 RCTokens: Array[1..64] Of String[127];
 RCTokenCount: Integer;

{ Lecture d'une ligne et tokenisation }
Function ReadRCLine: Boolean;
Var
 I: Integer;
Begin
 ReadRCLine := False;
 If Eof(RCFile) Then Exit;
 ReadLn(RCFile, RCLine);
 Inc(RCLineNum);

 { Enlever les commentaires // }
 I := Pos('//', RCLine);
 If I > 0 Then
  RCLine := Copy(RCLine, 1, I - 1);

 { Tokeniser la ligne }
 RCTokenCount := 0;
 I := 1;
 While I <= Length(RCLine) Do Begin
  { Sauter les espaces }
  While (I <= Length(RCLine)) And (RCLine[I] In [' ', #9, ',']) Do
   Inc(I);
  If I > Length(RCLine) Then Break;

  If RCTokenCount >= 64 Then Break;
  Inc(RCTokenCount);
  RCTokens[RCTokenCount] := '';

  { Chaine entre guillemets }
  If RCLine[I] = '"' Then Begin
   Inc(I);
   While (I <= Length(RCLine)) And (RCLine[I] <> '"') Do Begin
    RCTokens[RCTokenCount] := RCTokens[RCTokenCount] + RCLine[I];
    Inc(I);
   End;
   If I <= Length(RCLine) Then Inc(I);
  End
  { Token normal }
  Else Begin
   While (I <= Length(RCLine)) And Not (RCLine[I] In [' ', #9, ',']) Do Begin
    RCTokens[RCTokenCount] := RCTokens[RCTokenCount] + RCLine[I];
    Inc(I);
   End;
  End;
 End;

 RCTokenIndex := 1;
 ReadRCLine := RCTokenCount > 0;
End;

Function GetRCToken: String;
Begin
 If RCTokenIndex <= RCTokenCount Then Begin
  GetRCToken := RCTokens[RCTokenIndex];
  Inc(RCTokenIndex);
 End
 Else
  GetRCToken := '';
End;

Function PeekRCToken: String;
Begin
 If RCTokenIndex <= RCTokenCount Then
  PeekRCToken := RCTokens[RCTokenIndex]
 Else
  PeekRCToken := '';
End;

Function RCTokenToInt(Const S: String): LongInt;
Var
 Code: Integer;
 L: LongInt;
Begin
 Val(S, L, Code);
 If Code = 0 Then
  RCTokenToInt := L
 Else
  RCTokenToInt := 0;
End;

Function RCTokenToWord(Const S: String): Word;
Begin
 RCTokenToWord := Word(RCTokenToInt(S));
End;

{ Parser un style de dialogue/controle }
Function ParseRCStyle(Const S: String): LongInt;
Var
 Style: LongInt;
Begin
 Style := 0;
 If Pos('WS_VISIBLE', S) > 0 Then Style := Style Or $10000000;
 If Pos('WS_CHILD', S) > 0 Then Style := Style Or $40000000;
 If Pos('WS_POPUP', S) > 0 Then Style := Style Or $80000000;
 If Pos('WS_CAPTION', S) > 0 Then Style := Style Or $00C00000;
 If Pos('WS_SYSMENU', S) > 0 Then Style := Style Or $00080000;
 If Pos('WS_THICKFRAME', S) > 0 Then Style := Style Or $00040000;
 If Pos('WS_MINIMIZEBOX', S) > 0 Then Style := Style Or $00020000;
 If Pos('WS_MAXIMIZEBOX', S) > 0 Then Style := Style Or $00010000;
 If Pos('DS_MODALFRAME', S) > 0 Then Style := Style Or $80;
 If Pos('DS_SETFONT', S) > 0 Then Style := Style Or $40;
 If Pos('DS_CENTER', S) > 0 Then Style := Style Or $0800;
 If Pos('BS_PUSHBUTTON', S) > 0 Then Style := Style Or $0000;
 If Pos('BS_DEFPUSHBUTTON', S) > 0 Then Style := Style Or $0001;
 If Pos('BS_CHECKBOX', S) > 0 Then Style := Style Or $0002;
 If Pos('BS_AUTOCHECKBOX', S) > 0 Then Style := Style Or $0003;
 If Pos('BS_RADIOBUTTON', S) > 0 Then Style := Style Or $0004;
 If Pos('BS_AUTORADIOBUTTON', S) > 0 Then Style := Style Or $0009;
 If Pos('BS_GROUPBOX', S) > 0 Then Style := Style Or $0007;
 If Pos('ES_LEFT', S) > 0 Then Style := Style Or $0000;
 If Pos('ES_CENTER', S) > 0 Then Style := Style Or $0001;
 If Pos('ES_RIGHT', S) > 0 Then Style := Style Or $0002;
 If Pos('ES_MULTILINE', S) > 0 Then Style := Style Or $0004;
 If Pos('ES_AUTOHSCROLL', S) > 0 Then Style := Style Or $0080;
 If Pos('ES_AUTOVSCROLL', S) > 0 Then Style := Style Or $0040;
 If Pos('SS_LEFT', S) > 0 Then Style := Style Or $0000;
 If Pos('SS_CENTER', S) > 0 Then Style := Style Or $0001;
 If Pos('SS_RIGHT', S) > 0 Then Style := Style Or $0002;
 If Pos('CBS_DROPDOWN', S) > 0 Then Style := Style Or $0002;
 If Pos('CBS_DROPDOWNLIST', S) > 0 Then Style := Style Or $0003;
 If Pos('LBS_STANDARD', S) > 0 Then Style := Style Or $00A00003;
 ParseRCStyle := Style;
End;

{ Parser un dialogue }
Procedure ParseRCDialog(ResId: Word);
Var
 DlgIdx, I: Integer;
 Token, StyleStr: String;
 X, Y, W, H: Integer;
 CtrlType: Word;
Begin
 If DialogCount >= 64 Then Exit;
 Inc(DialogCount);
 DlgIdx := DialogCount;
 FillChar(Dialogs[DlgIdx], SizeOf(TDialogData), 0);

 { ID x, y, width, height }
 X := RCTokenToWord(GetRCToken);
 Y := RCTokenToWord(GetRCToken);
 W := RCTokenToWord(GetRCToken);
 H := RCTokenToWord(GetRCToken);
 Dialogs[DlgIdx].X := X;
 Dialogs[DlgIdx].Y := Y;
 Dialogs[DlgIdx].W := W;
 Dialogs[DlgIdx].H := H;

 { Lire les lignes suivantes jusqu'a BEGIN }
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'BEGIN' Then Begin
   GetRCToken;
   Break;
  End;
  If Token = 'STYLE' Then Begin
   GetRCToken;
   StyleStr := '';
   While RCTokenIndex <= RCTokenCount Do
    StyleStr := StyleStr + ' ' + GetRCToken;
   Dialogs[DlgIdx].Style := ParseRCStyle(StyleStr);
  End
  Else If Token = 'CAPTION' Then Begin
   GetRCToken;
   Dialogs[DlgIdx].Caption := GetRCToken;
  End
  Else If Token = 'FONT' Then Begin
   GetRCToken;
   Dialogs[DlgIdx].FontSize := RCTokenToWord(GetRCToken);
   Dialogs[DlgIdx].FontName := GetRCToken;
   Dialogs[DlgIdx].Style := Dialogs[DlgIdx].Style Or $40; { DS_SETFONT }
  End;
 End;

 { Lire les controles jusqu'a END }
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'END' Then Break;
  If Dialogs[DlgIdx].ControlCount >= MAX_CONTROLS Then Continue;

  If Token = 'LTEXT' Then Begin
   CtrlType := 1; { STATIC }
   GetRCToken;
  End
  Else If Token = 'CTEXT' Then Begin
   CtrlType := 1;
   GetRCToken;
  End
  Else If Token = 'RTEXT' Then Begin
   CtrlType := 1;
   GetRCToken;
  End
  Else If Token = 'PUSHBUTTON' Then Begin
   CtrlType := 0; { BUTTON }
   GetRCToken;
  End
  Else If Token = 'DEFPUSHBUTTON' Then Begin
   CtrlType := 0;
   GetRCToken;
  End
  Else If Token = 'CHECKBOX' Then Begin
   CtrlType := 0;
   GetRCToken;
  End
  Else If Token = 'RADIOBUTTON' Then Begin
   CtrlType := 0;
   GetRCToken;
  End
  Else If Token = 'GROUPBOX' Then Begin
   CtrlType := 0;
   GetRCToken;
  End
  Else If Token = 'EDITTEXT' Then Begin
   CtrlType := 2; { EDIT }
   GetRCToken;
  End
  Else If Token = 'COMBOBOX' Then Begin
   CtrlType := 3; { COMBOBOX }
   GetRCToken;
  End
  Else If Token = 'LISTBOX' Then Begin
   CtrlType := 4; { LISTBOX }
   GetRCToken;
  End
  Else If Token = 'CONTROL' Then Begin
   CtrlType := 0;
   GetRCToken;
  End
  Else
   Continue;

  Inc(Dialogs[DlgIdx].ControlCount);
  I := Dialogs[DlgIdx].ControlCount;
  Dialogs[DlgIdx].Controls[I].CtrlType := CtrlType;

  { Text, ID, x, y, width, height }
  If Token <> 'EDITTEXT' Then
   Dialogs[DlgIdx].Controls[I].Text := GetRCToken;
  Dialogs[DlgIdx].Controls[I].CtrlId := RCTokenToWord(GetRCToken);
  Dialogs[DlgIdx].Controls[I].X := RCTokenToWord(GetRCToken);
  Dialogs[DlgIdx].Controls[I].Y := RCTokenToWord(GetRCToken);
  Dialogs[DlgIdx].Controls[I].W := RCTokenToWord(GetRCToken);
  Dialogs[DlgIdx].Controls[I].H := RCTokenToWord(GetRCToken);

  { Style optionnel }
  StyleStr := '';
  While RCTokenIndex <= RCTokenCount Do
   StyleStr := StyleStr + ' ' + GetRCToken;
  If StyleStr <> '' Then
   Dialogs[DlgIdx].Controls[I].Style := ParseRCStyle(StyleStr);
 End;

 { Ajouter a la liste des ressources }
 If ResourceCount < MAX_RESOURCES Then Begin
  Inc(ResourceCount);
  Resources[ResourceCount].ResType := RT_DIALOG;
  Resources[ResourceCount].ResId.IsNumeric := True;
  Resources[ResourceCount].ResId.NumId := ResId;
  Resources[ResourceCount].ResId.StrId := '';
  Resources[ResourceCount].LangId := $0409;
 End;
End;

{ Parser un menu }
Procedure ParseRCMenu(ResId: Word);
Var
 MenuIdx, I: Integer;
 Token: String;
 Level: Integer;
Begin
 If MenuDataCount >= 64 Then Exit;
 Inc(MenuDataCount);
 MenuIdx := MenuDataCount;
 FillChar(ResMenus[MenuIdx], SizeOf(TMenuData), 0);

 { Chercher BEGIN }
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'BEGIN' Then Begin
   GetRCToken;
   Break;
  End;
 End;

 { Lire les items }
 Level := 0;
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'END' Then Begin
   If Level > 0 Then
    Dec(Level)
   Else
    Break;
   GetRCToken;
   { Marquer le dernier item comme MF_END }
   If ResMenus[MenuIdx].ItemCount > 0 Then
    ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].Flags :=
     ResMenus[MenuIdx].Items[ResMenus[MenuIdx].ItemCount].Flags Or $80;
   Continue;
  End;

  If ResMenus[MenuIdx].ItemCount >= MAX_MENU_ITEMS_RES Then Continue;

  If Token = 'POPUP' Then Begin
   GetRCToken;
   Inc(ResMenus[MenuIdx].ItemCount);
   I := ResMenus[MenuIdx].ItemCount;
   ResMenus[MenuIdx].Items[I].ItemType := 1;
   ResMenus[MenuIdx].Items[I].Text := GetRCToken;
   ResMenus[MenuIdx].Items[I].Flags := $10; { MF_POPUP }
   ResMenus[MenuIdx].Items[I].Level := Level;
   { Chercher BEGIN du sous-menu }
   While ReadRCLine Do Begin
    If UpCaseStr(PeekRCToken) = 'BEGIN' Then Begin
     GetRCToken;
     Inc(Level);
     Break;
    End;
   End;
  End
  Else If Token = 'MENUITEM' Then Begin
   GetRCToken;
   Token := GetRCToken;
   If UpCaseStr(Token) = 'SEPARATOR' Then Begin
    Inc(ResMenus[MenuIdx].ItemCount);
    I := ResMenus[MenuIdx].ItemCount;
    ResMenus[MenuIdx].Items[I].ItemType := 2; { Separateur }
    ResMenus[MenuIdx].Items[I].Text := '';
    ResMenus[MenuIdx].Items[I].ItemId := 0;
    ResMenus[MenuIdx].Items[I].Flags := $800; { MF_SEPARATOR }
    ResMenus[MenuIdx].Items[I].Level := Level;
   End
   Else Begin
    Inc(ResMenus[MenuIdx].ItemCount);
    I := ResMenus[MenuIdx].ItemCount;
    ResMenus[MenuIdx].Items[I].ItemType := 0;
    ResMenus[MenuIdx].Items[I].Text := Token;
    ResMenus[MenuIdx].Items[I].ItemId := RCTokenToWord(GetRCToken);
    ResMenus[MenuIdx].Items[I].Flags := 0;
    ResMenus[MenuIdx].Items[I].Level := Level;
   End;
  End;
 End;

 { Ajouter a la liste des ressources }
 If ResourceCount < MAX_RESOURCES Then Begin
  Inc(ResourceCount);
  Resources[ResourceCount].ResType := RT_MENU;
  Resources[ResourceCount].ResId.IsNumeric := True;
  Resources[ResourceCount].ResId.NumId := ResId;
  Resources[ResourceCount].ResId.StrId := '';
  Resources[ResourceCount].LangId := $0409;
 End;
End;

{ Parser une table de chaines }
Procedure ParseRCStringTable;
Var
 Token: String;
 StringId: Word;
Begin
 { Chercher BEGIN }
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'BEGIN' Then Begin
   GetRCToken;
   Break;
  End;
 End;

 { Lire les chaines }
 While ReadRCLine Do Begin
  Token := UpCaseStr(PeekRCToken);
  If Token = 'END' Then Break;

  If StringCount >= MAX_STRINGS Then Continue;

  StringId := RCTokenToWord(GetRCToken);
  If StringId > 0 Then Begin
   Inc(StringCount);
   StringEntries[StringCount].StringId := StringId;
   StringEntries[StringCount].Text := GetRCToken;
   StringEntries[StringCount].LangId := $0409;
  End;
 End;
End;

{ Lecture complete d'un fichier RC }
Procedure ReadRCFile(Const FileName: String);
Var
 Token, ResIdStr: String;
 ResId: Word;
 ValCode: Integer;
Begin
 { Reinitialiser les donnees }
 ResourceCount := 0;
 DialogCount := 0;
 MenuDataCount := 0;
 StringCount := 0;

 {$I-}
 Assign(RCFile, FileName);
 Reset(RCFile);
 {$I+}
 If IOResult <> 0 Then Exit;

 RCLineNum := 0;

 While Not Eof(RCFile) Do Begin
  If Not ReadRCLine Then Continue;

  Token := UpCaseStr(PeekRCToken);

  { Ignorer les directives preprocesseur }
  If (Length(Token) > 0) And (Token[1] = '#') Then Continue;

  { STRINGTABLE }
  If Token = 'STRINGTABLE' Then Begin
   GetRCToken; { Consommer STRINGTABLE }
   ParseRCStringTable;
   Continue;
  End;

  { Format: ID DIALOG/DIALOGEX/MENU/MENUEX }
  { Le premier token est l'ID de ressource }
  ResIdStr := GetRCToken;
  Val(ResIdStr, ResId, ValCode);
  If ValCode <> 0 Then ResId := 100; { Default si pas un nombre }

  Token := UpCaseStr(GetRCToken);
  If (Token = 'DIALOG') Or (Token = 'DIALOGEX') Then
   ParseRCDialog(ResId)
  Else If (Token = 'MENU') Or (Token = 'MENUEX') Then
   ParseRCMenu(ResId);
 End;

 Close(RCFile);
End;

{ Ecriture fichiers RC }
Procedure WriteRCFile(Const FileName: String);
Var
 F: Text;
Begin
 {$I-}
 Assign(F, FileName);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, '// Resource Script genere par WORKSHOP');
 WriteLn(F, '// Date: ', WORKSHOP_DATE);
 WriteLn(F);
 Close(F);
End;

{ Import Macintosh }
Function SwapLong(L: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte Absolute L;
 TempByte: Byte;
Begin
 TempByte := B[0]; B[0] := B[3]; B[3] := TempByte;
 TempByte := B[1]; B[1] := B[2]; B[2] := TempByte;
 SwapLong := L;
End;

Procedure ImportMacResource(Const FileName: String);
Begin
 If Not FileExists(FileName) Then Exit;
 AppState.ProjectModified := True;
End;

{ ============================================================
  TODO 10 - IMPORT DES FICHIERS GEM .RSC
  ============================================================ }

{ Fonction pour echanger les octets d'un word (big endian -> little endian) }
Function SwapWord(W: Word): Word;
Var
 B: Array[0..1] Of Byte Absolute W;
 TempByte: Byte;
Begin
 TempByte := B[0]; B[0] := B[1]; B[1] := TempByte;
 SwapWord := W;
End;

{ Lecture de l'en-tete du fichier RSC }
Function ReadRSCHeader(Var F: File; Var Header: TRSCHeader): Boolean;
Var
 BytesRead: Integer;
Begin
 ReadRSCHeader := False;
 {$I-}
 BlockRead(F, Header, SizeOf(TRSCHeader), BytesRead);
 {$I+}
 If (IOResult <> 0) Or (BytesRead <> SizeOf(TRSCHeader)) Then Exit;
 { Conversion big endian -> little endian (Atari ST est 68000 = big endian) }
 Header.vrsn := SwapWord(Header.vrsn);
 Header.object_ := SwapWord(Header.object_);
 Header.tedinfo := SwapWord(Header.tedinfo);
 Header.iconblk := SwapWord(Header.iconblk);
 Header.bitblk := SwapWord(Header.bitblk);
 Header.frstr := SwapWord(Header.frstr);
 Header.string_ := SwapWord(Header.string_);
 Header.imdata := SwapWord(Header.imdata);
 Header.frimg := SwapWord(Header.frimg);
 Header.trindex := SwapWord(Header.trindex);
 Header.nobs := SwapWord(Header.nobs);
 Header.ntree := SwapWord(Header.ntree);
 Header.nted := SwapWord(Header.nted);
 Header.nib := SwapWord(Header.nib);
 Header.nbb := SwapWord(Header.nbb);
 Header.nstring := SwapWord(Header.nstring);
 Header.nimages := SwapWord(Header.nimages);
 Header.rssize := SwapWord(Header.rssize);
 ReadRSCHeader := True;
End;

{ Lecture d'un objet GEM depuis le fichier }
Procedure ReadGEMObject(Var Obj: TGEMObject; Offset: Word);
Begin
 Move(RSCFileBuffer^[Offset], Obj, SizeOf(TGEMObject));
 { Conversion big endian -> little endian }
 Obj.ob_next := SmallInt(SwapWord(Word(Obj.ob_next)));
 Obj.ob_head := SmallInt(SwapWord(Word(Obj.ob_head)));
 Obj.ob_tail := SmallInt(SwapWord(Word(Obj.ob_tail)));
 Obj.ob_type := SwapWord(Obj.ob_type);
 Obj.ob_flags := SwapWord(Obj.ob_flags);
 Obj.ob_state := SwapWord(Obj.ob_state);
 Obj.ob_spec := SwapLong(Obj.ob_spec);
 Obj.ob_x := SmallInt(SwapWord(Word(Obj.ob_x)));
 Obj.ob_y := SmallInt(SwapWord(Word(Obj.ob_y)));
 Obj.ob_width := SmallInt(SwapWord(Word(Obj.ob_width)));
 Obj.ob_height := SmallInt(SwapWord(Word(Obj.ob_height)));
End;

{ Lecture d'un TEDINFO depuis le fichier }
Procedure ReadGEMTedInfo(Var Ted: TGEMTedInfo; Offset: Word);
Begin
 Move(RSCFileBuffer^[Offset], Ted, SizeOf(TGEMTedInfo));
 { Conversion big endian -> little endian }
 Ted.te_ptext := SwapLong(Ted.te_ptext);
 Ted.te_ptmplt := SwapLong(Ted.te_ptmplt);
 Ted.te_pvalid := SwapLong(Ted.te_pvalid);
 Ted.te_font := SmallInt(SwapWord(Word(Ted.te_font)));
 Ted.te_fontid := SmallInt(SwapWord(Word(Ted.te_fontid)));
 Ted.te_just := SmallInt(SwapWord(Word(Ted.te_just)));
 Ted.te_color := SmallInt(SwapWord(Word(Ted.te_color)));
 Ted.te_fontsize := SmallInt(SwapWord(Word(Ted.te_fontsize)));
 Ted.te_thickness := SmallInt(SwapWord(Word(Ted.te_thickness)));
 Ted.te_txtlen := SmallInt(SwapWord(Word(Ted.te_txtlen)));
 Ted.te_tmplen := SmallInt(SwapWord(Word(Ted.te_tmplen)));
End;

{ Lecture d'un ICONBLK depuis le fichier }
Procedure ReadGEMIconBlk(Var Icon: TGEMIconBlk; Offset: Word);
Begin
 Move(RSCFileBuffer^[Offset], Icon, SizeOf(TGEMIconBlk));
 { Conversion big endian -> little endian }
 Icon.ib_pmask := SwapLong(Icon.ib_pmask);
 Icon.ib_pdata := SwapLong(Icon.ib_pdata);
 Icon.ib_ptext := SwapLong(Icon.ib_ptext);
 Icon.ib_char := SmallInt(SwapWord(Word(Icon.ib_char)));
 Icon.ib_xchar := SmallInt(SwapWord(Word(Icon.ib_xchar)));
 Icon.ib_ychar := SmallInt(SwapWord(Word(Icon.ib_ychar)));
 Icon.ib_xicon := SmallInt(SwapWord(Word(Icon.ib_xicon)));
 Icon.ib_yicon := SmallInt(SwapWord(Word(Icon.ib_yicon)));
 Icon.ib_wicon := SmallInt(SwapWord(Word(Icon.ib_wicon)));
 Icon.ib_hicon := SmallInt(SwapWord(Word(Icon.ib_hicon)));
 Icon.ib_xtext := SmallInt(SwapWord(Word(Icon.ib_xtext)));
 Icon.ib_ytext := SmallInt(SwapWord(Word(Icon.ib_ytext)));
 Icon.ib_wtext := SmallInt(SwapWord(Word(Icon.ib_wtext)));
 Icon.ib_htext := SmallInt(SwapWord(Word(Icon.ib_htext)));
End;

{ Lecture d'un BITBLK depuis le fichier }
Procedure ReadGEMBitBlk(Var Bit: TGEMBitBlk; Offset: Word);
Begin
 Move(RSCFileBuffer^[Offset], Bit, SizeOf(TGEMBitBlk));
 { Conversion big endian -> little endian }
 Bit.bi_pdata := SwapLong(Bit.bi_pdata);
 Bit.bi_wb := SmallInt(SwapWord(Word(Bit.bi_wb)));
 Bit.bi_hl := SmallInt(SwapWord(Word(Bit.bi_hl)));
 Bit.bi_x := SmallInt(SwapWord(Word(Bit.bi_x)));
 Bit.bi_y := SmallInt(SwapWord(Word(Bit.bi_y)));
 Bit.bi_color := SmallInt(SwapWord(Word(Bit.bi_color)));
End;

{ Lecture d'une chaine depuis le buffer RSC (null-terminated) }
Function ReadRSCString(Offset: Word): String;
Var
 S: String;
 I: Integer;
 BufIdx: Word;
Begin
 S := '';
 I := 0;
 BufIdx := Offset;
 While (I < MAX_RSC_STRING_LEN) And (BufIdx < SizeOf(TRSCFileBuffer)) And (RSCFileBuffer^[BufIdx] <> 0) Do Begin
  S := S + Chr(RSCFileBuffer^[BufIdx]);
  Inc(I);
  Inc(BufIdx);
 End;
 ReadRSCString := S;
End;

{ Conversion d'un objet GEM vers un controle Windows }
Procedure ConvertGEMObjectToControl(Const Obj: TGEMObject; Var Ctrl: TDialogControl; ObjIndex: Integer);
Var
 ObjectType: Word;
 Ted: TGEMTedInfo;
Begin
 ObjectType := Obj.ob_type And $00FF; { Type de base sans extended type }
 Ctrl.X := Obj.ob_x;
 Ctrl.Y := Obj.ob_y;
 Ctrl.W := Obj.ob_width;
 Ctrl.H := Obj.ob_height;
 Ctrl.CtrlId := ObjIndex;
 Ctrl.Style := 0;
 Ctrl.ExStyle := 0;
 Ctrl.Text := '';
 Ctrl.ClassName := '';

 Case ObjectType Of
  G_BOX, G_IBOX: Begin
   Ctrl.CtrlType := 0; { STATIC / Group Box }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000007; { WS_CHILD | WS_VISIBLE | SS_BLACKFRAME }
  End;
  G_TEXT, G_FTEXT: Begin
   Ctrl.CtrlType := 1; { STATIC text }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000000; { WS_CHILD | WS_VISIBLE }
   { Lecture du texte depuis TEDINFO si present }
   If (Obj.ob_spec > 0) And (Obj.ob_spec < SizeOf(TRSCFileBuffer)) Then Begin
    ReadGEMTedInfo(Ted, Word(Obj.ob_spec));
    If (Ted.te_ptext > 0) And (Ted.te_ptext < SizeOf(TRSCFileBuffer)) Then
     Ctrl.Text := ReadRSCString(Word(Ted.te_ptext));
   End;
  End;
  G_BOXTEXT, G_FBOXTEXT: Begin
   Ctrl.CtrlType := 1; { STATIC text dans boite }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000007; { WS_CHILD | WS_VISIBLE | SS_BLACKFRAME }
   If (Obj.ob_spec > 0) And (Obj.ob_spec < SizeOf(TRSCFileBuffer)) Then Begin
    ReadGEMTedInfo(Ted, Word(Obj.ob_spec));
    If (Ted.te_ptext > 0) And (Ted.te_ptext < SizeOf(TRSCFileBuffer)) Then
     Ctrl.Text := ReadRSCString(Word(Ted.te_ptext));
   End;
  End;
  G_BUTTON: Begin
   If (Obj.ob_flags And GEM_RBUTTON) <> 0 Then Begin
    Ctrl.CtrlType := 3; { Radio button }
    Ctrl.ClassName := 'BUTTON';
    Ctrl.Style := $50000009; { WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON }
   End Else If (Obj.ob_flags And GEM_EXIT) <> 0 Then Begin
    Ctrl.CtrlType := 2; { Push button }
    Ctrl.ClassName := 'BUTTON';
    Ctrl.Style := $50010000; { WS_CHILD | WS_VISIBLE | WS_TABSTOP }
    If (Obj.ob_flags And GEM_DEFAULT) <> 0 Then
     Ctrl.Style := Ctrl.Style Or $0001; { BS_DEFPUSHBUTTON }
   End Else Begin
    Ctrl.CtrlType := 2; { Standard button }
    Ctrl.ClassName := 'BUTTON';
    Ctrl.Style := $50010000;
   End;
   If (Obj.ob_spec > 0) And (Obj.ob_spec < SizeOf(TRSCFileBuffer)) Then
    Ctrl.Text := ReadRSCString(Word(Obj.ob_spec));
  End;
  G_STRING, G_TITLE: Begin
   Ctrl.CtrlType := 1; { STATIC string }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000000;
   If (Obj.ob_spec > 0) And (Obj.ob_spec < SizeOf(TRSCFileBuffer)) Then
    Ctrl.Text := ReadRSCString(Word(Obj.ob_spec));
  End;
  G_IMAGE: Begin
   Ctrl.CtrlType := 4; { Image/Bitmap }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000003; { WS_CHILD | WS_VISIBLE | SS_BITMAP }
  End;
  G_ICON, G_CICON: Begin
   Ctrl.CtrlType := 5; { Icon }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000003; { WS_CHILD | WS_VISIBLE | SS_ICON }
  End;
  G_BOXCHAR: Begin
   Ctrl.CtrlType := 1; { STATIC char }
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000001; { WS_CHILD | WS_VISIBLE | SS_CENTER }
   Ctrl.Text := Chr((Obj.ob_spec Shr 24) And $FF);
  End;
 Else Begin
   Ctrl.CtrlType := 0;
   Ctrl.ClassName := 'STATIC';
   Ctrl.Style := $50000000;
  End;
 End;
End;

{ Conversion d'un formulaire GEM vers un dialogue Windows }
Procedure ConvertGEMTreeToDialog(TreeIndex: Integer);
Var
 ObjIndex, CtrlCount: Integer;
 TreeOffset: Word;
 Obj: TGEMObject;
 RootObj: TGEMObject;
Begin
 If DialogCount >= 64 Then Exit;
 If TreeIndex >= RSCData.Header.ntree Then Exit;

 { Lecture de l'offset de l'arbre depuis la table d'index }
 Move(RSCFileBuffer^[RSCData.Header.trindex + TreeIndex * TREE_INDEX_SIZE], TreeOffset, 2);
 TreeOffset := SwapWord(TreeOffset);

 { Lecture de l'objet racine }
 ReadGEMObject(RootObj, RSCData.Header.object_ + TreeOffset);

 Inc(DialogCount);
 With Dialogs[DialogCount] Do Begin
  Caption := 'GEM Form ' + IntToStr(TreeIndex);
  X := 10;
  Y := 10;
  W := RootObj.ob_width;
  H := RootObj.ob_height;
  Style := LongInt($90C80000); { WS_POPUP | WS_VISIBLE | WS_CAPTION | WS_SYSMENU }
  ExStyle := 0;
  FontName := 'MS Sans Serif';
  FontSize := 8;
  FontWeight := 400;
  FontItalic := False;
  ControlCount := 0;

  { Parcourir tous les objets de l'arbre }
  ObjIndex := 0;
  CtrlCount := 0;
  While (ObjIndex < RSCData.Header.nobs) And (CtrlCount < MAX_CONTROLS) Do Begin
   ReadGEMObject(Obj, RSCData.Header.object_ + (TreeOffset + ObjIndex * SizeOf(TGEMObject)));

   { Convertir l'objet sauf la racine }
   If ObjIndex > 0 Then Begin
    Inc(CtrlCount);
    ConvertGEMObjectToControl(Obj, Controls[CtrlCount], ObjIndex);
   End;

   { Verifier si c'est le dernier objet }
   If (Obj.ob_flags And GEM_LASTOB) <> 0 Then Break;
   Inc(ObjIndex);
  End;

  ControlCount := CtrlCount;
 End;

 { Ajouter une entree de ressource }
 If ResourceCount < MAX_RESOURCES Then Begin
  Inc(ResourceCount);
  With Resources[ResourceCount] Do Begin
   ResType := RT_DIALOG;
   TypeName := 'DIALOG';
   ResId.IsNumeric := True;
   ResId.NumId := GEM_DIALOG_ID_BASE + TreeIndex;
   ResId.StrId := '';
   LangId := $0409; { English US }
   MemFlags := $1010;
   DataSize := 0;
   DataOffset := 0;
   Modified := True;
  End;
 End;
End;

{ Extraction des icones GEM vers format Windows }
Procedure ExtractGEMIcons;
Var
 I: Integer;
 Icon: TGEMIconBlk;
Begin
 For I := 0 To RSCData.Header.nib - 1 Do Begin
  If IconCount >= 32 Then Break;
  ReadGEMIconBlk(Icon, RSCData.Header.iconblk + I * SizeOf(TGEMIconBlk));

  Inc(IconCount);
  With Icons[IconCount] Do Begin
   ImageCount := 1;
   Images[1].Width := Icon.ib_wicon;
   Images[1].Height := Icon.ib_hicon;
   Images[1].BitsPerPixel := 1; { Icones GEM monochromes }
   Images[1].DataSize := (Icon.ib_wicon Div 8) * Icon.ib_hicon;
   Images[1].MaskSize := Images[1].DataSize;
  End;

  { Ajouter une ressource ICON }
  If ResourceCount < MAX_RESOURCES Then Begin
   Inc(ResourceCount);
   With Resources[ResourceCount] Do Begin
    ResType := RT_ICON;
    TypeName := 'ICON';
    ResId.IsNumeric := True;
    ResId.NumId := GEM_ICON_ID_BASE + I;
    ResId.StrId := '';
    LangId := $0409;
    MemFlags := $1010;
    DataSize := Icons[IconCount].Images[1].DataSize;
    DataOffset := Icon.ib_pdata;
    Modified := True;
   End;
  End;
 End;
End;

{ Extraction des images bitmap GEM vers format Windows }
Procedure ExtractGEMBitmaps;
Var
 I: Integer;
 Bit: TGEMBitBlk;
Begin
 For I := 0 To RSCData.Header.nbb - 1 Do Begin
  If BitmapCount >= 32 Then Break;
  ReadGEMBitBlk(Bit, RSCData.Header.bitblk + I * SizeOf(TGEMBitBlk));

  Inc(BitmapCount);
  With Bitmaps[BitmapCount] Do Begin
   Width := Bit.bi_wb * 8; { bi_wb est en octets }
   Height := Bit.bi_hl;
   BitsPerPixel := 1; { Images GEM monochromes }
   PaletteCount := 2;
   Palette[0].R := 255; Palette[0].G := 255; Palette[0].B := 255;
   Palette[1].R := 0; Palette[1].G := 0; Palette[1].B := 0;
   DataSize := Bit.bi_wb * Bit.bi_hl;
  End;

  { Ajouter une ressource BITMAP }
  If ResourceCount < MAX_RESOURCES Then Begin
   Inc(ResourceCount);
   With Resources[ResourceCount] Do Begin
    ResType := RT_BITMAP;
    TypeName := 'BITMAP';
    ResId.IsNumeric := True;
    ResId.NumId := GEM_BITMAP_ID_BASE + I;
    ResId.StrId := '';
    LangId := $0409;
    MemFlags := $1010;
    DataSize := Bitmaps[BitmapCount].DataSize;
    DataOffset := Bit.bi_pdata;
    Modified := True;
   End;
  End;
 End;
End;

{ Procedure principale d'import GEM RSC }
Procedure ImportGEMResource(Const FileName: String);
Var
 F: File;
 BytesRead: Integer;
 I: Integer;
 ActualFileName: String;
Begin
 { Si pas de nom fourni, utiliser une boite de dialogue (non implementee) }
 ActualFileName := FileName;
 If ActualFileName = '' Then Exit;

 { Verifier l'existence du fichier }
 If Not FileExists(ActualFileName) Then Exit;

 { Ouvrir le fichier en mode binaire }
 Assign(F, ActualFileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tete RSC }
 If Not ReadRSCHeader(F, RSCData.Header) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier la taille du fichier }
 If RSCData.Header.rssize > SizeOf(TRSCFileBuffer) Then Begin
  Close(F);
  Exit;
 End;

 { Relire tout le fichier dans le buffer }
 Seek(F, 0);
 BlockRead(F, RSCFileBuffer^, RSCData.Header.rssize, BytesRead);
 Close(F);

 If BytesRead < RSCData.Header.rssize Then Exit;

 { Initialiser les compteurs }
 RSCData.ObjectCount := RSCData.Header.nobs;
 RSCData.TedInfoCount := RSCData.Header.nted;
 RSCData.IconBlkCount := RSCData.Header.nib;
 RSCData.BitBlkCount := RSCData.Header.nbb;
 RSCData.TreeCount := RSCData.Header.ntree;

 { Lire les objets GEM }
 For I := 0 To RSCData.Header.nobs - 1 Do Begin
  If I >= 256 Then Break;
  ReadGEMObject(RSCData.Objects[I + 1], RSCData.Header.object_ + I * SizeOf(TGEMObject));
 End;

 { Lire les TEDINFO }
 For I := 0 To RSCData.Header.nted - 1 Do Begin
  If I >= 64 Then Break;
  ReadGEMTedInfo(RSCData.TedInfos[I + 1], RSCData.Header.tedinfo + I * SizeOf(TGEMTedInfo));
 End;

 { Lire les ICONBLK }
 For I := 0 To RSCData.Header.nib - 1 Do Begin
  If I >= 32 Then Break;
  ReadGEMIconBlk(RSCData.IconBlks[I + 1], RSCData.Header.iconblk + I * SizeOf(TGEMIconBlk));
 End;

 { Lire les BITBLK }
 For I := 0 To RSCData.Header.nbb - 1 Do Begin
  If I >= 32 Then Break;
  ReadGEMBitBlk(RSCData.BitBlks[I + 1], RSCData.Header.bitblk + I * SizeOf(TGEMBitBlk));
 End;

 { Convertir les arbres GEM vers des dialogues Windows }
 For I := 0 To RSCData.Header.ntree - 1 Do Begin
  ConvertGEMTreeToDialog(I);
 End;

 { Extraire les icones }
 ExtractGEMIcons;

 { Extraire les bitmaps }
 ExtractGEMBitmaps;

 { Marquer le projet comme modifie }
 AppState.ProjectModified := True;
End;

{ ============================================================
  TODO 11-21 - EDITEURS
  ============================================================ }

Procedure DrawBitmapEditor(WndIndex: Integer);
Var
 I: Integer;
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 1 Then Exit;
 For I := 0 To 15 Do Begin
  SetFillStyle(SolidFill, I);
  Bar(Windows[WndIndex].ClientArea.X2 - 20, Windows[WndIndex].ClientArea.Y1 + I * 12, Windows[WndIndex].ClientArea.X2 - 4, Windows[WndIndex].ClientArea.Y1 + I * 12 + 10);
 End;
 DrawButton(Windows[WndIndex].ClientArea.X1, Windows[WndIndex].ClientArea.Y1, 24, 24, 'P', AppState.CurrentTool = TOOL_PENCIL, True);
 DrawButton(Windows[WndIndex].ClientArea.X1 + 26, Windows[WndIndex].ClientArea.Y1, 24, 24, 'L', AppState.CurrentTool = TOOL_LINE, True);
 DrawButton(Windows[WndIndex].ClientArea.X1 + 52, Windows[WndIndex].ClientArea.Y1, 24, 24, 'R', AppState.CurrentTool = TOOL_RECT, True);
 DrawButton(Windows[WndIndex].ClientArea.X1 + 78, Windows[WndIndex].ClientArea.Y1, 24, 24, 'F', AppState.CurrentTool = TOOL_FILL, True);
End;

{ ============================================================
  TODO 14 - EDITEUR DE BOITES DE DIALOGUE WYSIWYG
  ============================================================ }

{ Dessiner un controle Windows dans l'editeur WYSIWYG }
Procedure DrawWYSIWYGControl(BaseX, BaseY: Integer; Const Ctrl: TDialogControl; Selected: Boolean);
Var
 CX, CY, CW, CH: Integer;
 CtrlText: String;
Begin
 { Calculer position absolue du controle }
 CX := BaseX + Ctrl.X;
 CY := BaseY + Ctrl.Y;
 CW := Ctrl.W;
 CH := Ctrl.H;
 CtrlText := Ctrl.Text;

 Case Ctrl.CtrlType Of
  CTRL_PUSHBUTTON, CTRL_DEFPUSHBUTTON: Begin
   { Bouton standard }
   SetFillStyle(SolidFill, COLOR_BUTTON);
   Bar(CX, CY, CX + CW - 1, CY + CH - 1);
   Draw3DRect(CX, CY, CX + CW - 1, CY + CH - 1, False);
   SetColor(COLOR_BUTTONTEXT);
   OutTextXY(CX + (CW - TextWidth(CtrlText)) Div 2, CY + (CH - 8) Div 2, CtrlText);
   If Ctrl.CtrlType = CTRL_DEFPUSHBUTTON Then Begin
    SetColor(0);
    Rectangle(CX - 1, CY - 1, CX + CW, CY + CH);
   End;
  End;
  CTRL_CHECKBOX: Begin
   { Case a cocher }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY + 2, CX + 12, CY + 14);
   Draw3DRect(CX, CY + 2, CX + 12, CY + 14, True);
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX + 16, CY + 3, CtrlText);
  End;
  CTRL_RADIOBUTTON: Begin
   { Bouton radio }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   SetColor(COLOR_BORDER3D_DARK);
   Circle(CX + 6, CY + 8, 6);
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX + 16, CY + 3, CtrlText);
  End;
  CTRL_EDITTEXT: Begin
   { Zone de saisie }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY, CX + CW - 1, CY + CH - 1);
   Draw3DRect(CX, CY, CX + CW - 1, CY + CH - 1, True);
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX + 2, CY + 2, CtrlText);
  End;
  CTRL_COMBOBOX: Begin
   { Liste deroulante }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY, CX + CW - 17, CY + CH - 1);
   Draw3DRect(CX, CY, CX + CW - 1, CY + CH - 1, True);
   SetFillStyle(SolidFill, COLOR_BUTTON);
   Bar(CX + CW - 16, CY + 1, CX + CW - 2, CY + CH - 2);
   Draw3DRect(CX + CW - 16, CY + 1, CX + CW - 2, CY + CH - 2, False);
   SetColor(COLOR_BUTTONTEXT);
   OutTextXY(CX + CW - 12, CY + 4, 'v');
  End;
  CTRL_LISTBOX: Begin
   { Liste }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY, CX + CW - 1, CY + CH - 1);
   Draw3DRect(CX, CY, CX + CW - 1, CY + CH - 1, True);
  End;
  CTRL_SCROLLBAR: Begin
   { Barre de defilement }
   SetFillStyle(SolidFill, COLOR_SCROLLBAR);
   Bar(CX, CY, CX + CW - 1, CY + CH - 1);
   Draw3DRect(CX, CY, CX + CW - 1, CY + CH - 1, True);
   If CW > CH Then Begin
    { Horizontal }
    DrawButton(CX, CY, 16, CH, '<', False, True);
    DrawButton(CX + CW - 16, CY, 16, CH, '>', False, True);
   End Else Begin
    { Vertical }
    DrawButton(CX, CY, CW, 16, '^', False, True);
    DrawButton(CX, CY + CH - 16, CW, 16, 'v', False, True);
   End;
  End;
  CTRL_STATIC: Begin
   { Etiquette texte }
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX, CY + 2, CtrlText);
  End;
  CTRL_GROUPBOX: Begin
   { Groupe }
   SetColor(COLOR_BORDER3D_DARK);
   Rectangle(CX, CY + 6, CX + CW - 1, CY + CH - 1);
   SetFillStyle(SolidFill, COLOR_BUTTON);
   Bar(CX + 8, CY, CX + 8 + TextWidth(CtrlText), CY + 12);
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX + 8, CY, CtrlText);
  End;
  CTRL_ICON: Begin
   { Icone }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY, CX + 31, CY + 31);
   SetColor(COLOR_BORDER3D_DARK);
   Rectangle(CX, CY, CX + 31, CY + 31);
   SetColor(COLOR_WINDOWTEXT);
   OutTextXY(CX + 8, CY + 12, 'ICO');
  End;
 Else Begin
   { Controle inconnu }
   SetFillStyle(SolidFill, COLOR_WINDOW);
   Bar(CX, CY, CX + CW - 1, CY + CH - 1);
   SetColor(COLOR_BORDER3D_DARK);
   Rectangle(CX, CY, CX + CW - 1, CY + CH - 1);
  End;
 End;

 { Dessiner les poignees de selection }
 If Selected Then Begin
  SetColor(0);
  SetLineStyle(DashedLn, 0, NormWidth);
  Rectangle(CX - 1, CY - 1, CX + CW, CY + CH);
  SetLineStyle(SolidLn, 0, NormWidth);
  { Poignees aux 8 positions }
  SetFillStyle(SolidFill, 0);
  Bar(CX - 3, CY - 3, CX + 2, CY + 2); { Top-left }
  Bar(CX + CW Div 2 - 2, CY - 3, CX + CW Div 2 + 3, CY + 2); { Top-center }
  Bar(CX + CW - 2, CY - 3, CX + CW + 3, CY + 2); { Top-right }
  Bar(CX - 3, CY + CH Div 2 - 2, CX + 2, CY + CH Div 2 + 3); { Mid-left }
  Bar(CX + CW - 2, CY + CH Div 2 - 2, CX + CW + 3, CY + CH Div 2 + 3); { Mid-right }
  Bar(CX - 3, CY + CH - 2, CX + 2, CY + CH + 3); { Bottom-left }
  Bar(CX + CW Div 2 - 2, CY + CH - 2, CX + CW Div 2 + 3, CY + CH + 3); { Bottom-center }
  Bar(CX + CW - 2, CY + CH - 2, CX + CW + 3, CY + CH + 3); { Bottom-right }
 End;
End;

{ Dessiner la palette de controles WYSIWYG }
Procedure DrawWYSIWYGPalette(X, Y: Integer; SelectedTool: Integer);
Const
 PaletteLabels: Array[0..10] Of String[8] = (
  'Button', 'DefBtn', 'Check', 'Radio', 'Edit',
  'Combo', 'List', 'Scroll', 'Static', 'Group', 'Icon'
 );
Var
 I, BtnX, BtnY: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(X, Y, X + 64, Y + 250);
 Draw3DRect(X, Y, X + 64, Y + 250, False);

 For I := 0 To 10 Do Begin
  BtnX := X + 2;
  BtnY := Y + 2 + I * 22;
  DrawButton(BtnX, BtnY, 60, 20, PaletteLabels[I], I = SelectedTool, True);
 End;
End;

{ Dessiner la grille d'alignement }
Procedure DrawAlignmentGrid(X1, Y1, X2, Y2, GridSize: Integer);
Var
 GX, GY: Integer;
Begin
 SetColor(COLOR_DISABLED);
 SetLineStyle(DottedLn, 0, NormWidth);
 GX := X1;
 While GX <= X2 Do Begin
  Line(GX, Y1, GX, Y2);
  Inc(GX, GridSize);
 End;
 GY := Y1;
 While GY <= Y2 Do Begin
  Line(X1, GY, X2, GY);
  Inc(GY, GridSize);
 End;
 SetLineStyle(SolidLn, 0, NormWidth);
End;

{ Editeur de dialogue WYSIWYG complet }
Procedure DrawDialogEditor(WndIndex: Integer);
Var
 I, DlgIdx: Integer;
 DesignX, DesignY, DesignW, DesignH: Integer;
 PaletteX, PaletteY: Integer;
 PropX, PropY: Integer;
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 2 Then Exit;

 DlgIdx := Windows[WndIndex].ResourceIndex;
 If (DlgIdx < 1) Or (DlgIdx > DialogCount) Then DlgIdx := 1;

 { Calculer les zones }
 PaletteX := Windows[WndIndex].ClientArea.X1;
 PaletteY := Windows[WndIndex].ClientArea.Y1;
 DesignX := Windows[WndIndex].ClientArea.X1 + 70;
 DesignY := Windows[WndIndex].ClientArea.Y1;
 DesignW := Windows[WndIndex].ClientArea.X2 - Windows[WndIndex].ClientArea.X1 - 200;
 DesignH := Windows[WndIndex].ClientArea.Y2 - Windows[WndIndex].ClientArea.Y1;
 PropX := Windows[WndIndex].ClientArea.X2 - 125;
 PropY := Windows[WndIndex].ClientArea.Y1;

 { Dessiner la palette de controles }
 DrawWYSIWYGPalette(PaletteX, PaletteY, DlgEdState.PaletteSelection);

 { Zone de design du dialogue }
 SetFillStyle(SolidFill, COLOR_BACKGROUND);
 Bar(DesignX, DesignY, DesignX + DesignW, DesignY + DesignH);

 { Dessiner la grille si activee }
 If AppState.ShowGrid Then
  DrawAlignmentGrid(DesignX, DesignY, DesignX + DesignW, DesignY + DesignH, AppState.GridSize);

 { Dessiner le cadre du dialogue lui-meme }
 If DialogCount > 0 Then Begin
  SetFillStyle(SolidFill, COLOR_BUTTON);
  Bar(DesignX + 10, DesignY + 10, DesignX + 10 + Dialogs[DlgIdx].W, DesignY + 10 + Dialogs[DlgIdx].H);
  { Barre de titre du dialogue }
  SetFillStyle(SolidFill, COLOR_TITLEBAR);
  Bar(DesignX + 10, DesignY + 10, DesignX + 10 + Dialogs[DlgIdx].W, DesignY + 28);
  SetColor(COLOR_TITLETEXT);
  OutTextXY(DesignX + 14, DesignY + 14, Dialogs[DlgIdx].Caption);
  { Bordure }
  Draw3DRect(DesignX + 10, DesignY + 10, DesignX + 10 + Dialogs[DlgIdx].W, DesignY + 10 + Dialogs[DlgIdx].H, False);

  { Dessiner tous les controles du dialogue }
  For I := 1 To Dialogs[DlgIdx].ControlCount Do Begin
   DrawWYSIWYGControl(DesignX + 10, DesignY + 30,
                      Dialogs[DlgIdx].Controls[I],
                      I = DlgEdState.SelectedControl);
  End;

  { Selection du dialogue lui-meme }
  If DlgEdState.SelectedControl = 0 Then Begin
   SetColor(0);
   SetLineStyle(DashedLn, 0, NormWidth);
   Rectangle(DesignX + 9, DesignY + 9, DesignX + 11 + Dialogs[DlgIdx].W, DesignY + 11 + Dialogs[DlgIdx].H);
   SetLineStyle(SolidLn, 0, NormWidth);
  End;
 End Else Begin
  SetColor(COLOR_DISABLED);
  OutTextXY(DesignX + 20, DesignY + 20, 'Aucun dialogue. Creez-en un nouveau.');
 End;

 { Zone des proprietes }
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(PropX, PropY, PropX + 120, PropY + 200);
 Draw3DRect(PropX, PropY, PropX + 120, PropY + 200, True);
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(PropX + 4, PropY + 4, 'Proprietes');
 Line(PropX, PropY + 18, PropX + 120, PropY + 18);

 If DialogCount > 0 Then Begin
  If DlgEdState.SelectedControl = 0 Then Begin
   { Proprietes du dialogue }
   OutTextXY(PropX + 4, PropY + 24, 'Dialogue:');
   OutTextXY(PropX + 4, PropY + 40, 'X: ' + IntToStr(Dialogs[DlgIdx].X));
   OutTextXY(PropX + 4, PropY + 56, 'Y: ' + IntToStr(Dialogs[DlgIdx].Y));
   OutTextXY(PropX + 4, PropY + 72, 'W: ' + IntToStr(Dialogs[DlgIdx].W));
   OutTextXY(PropX + 4, PropY + 88, 'H: ' + IntToStr(Dialogs[DlgIdx].H));
  End Else If (DlgEdState.SelectedControl >= 1) And
              (DlgEdState.SelectedControl <= Dialogs[DlgIdx].ControlCount) Then Begin
   { Proprietes du controle selectionne }
   With Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl] Do Begin
    OutTextXY(PropX + 4, PropY + 24, 'Controle #' + IntToStr(DlgEdState.SelectedControl));
    OutTextXY(PropX + 4, PropY + 40, 'ID: ' + IntToStr(CtrlId));
    OutTextXY(PropX + 4, PropY + 56, 'X: ' + IntToStr(X));
    OutTextXY(PropX + 4, PropY + 72, 'Y: ' + IntToStr(Y));
    OutTextXY(PropX + 4, PropY + 88, 'W: ' + IntToStr(W));
    OutTextXY(PropX + 4, PropY + 104, 'H: ' + IntToStr(H));
    OutTextXY(PropX + 4, PropY + 120, 'Text: ' + Copy(Text, 1, 10));
   End;
  End;
 End;
End;

{ Gestion des clics dans l'editeur WYSIWYG }
Function HandleDialogEditorClick(WndIndex: Integer; MX, MY: Integer; MBtn: Integer): Boolean;
Var
 I, DlgIdx: Integer;
 DesignX, DesignY: Integer;
 PaletteX, PaletteY: Integer;
 CtrlX, CtrlY, CtrlW, CtrlH: Integer;
 ClickedControl: Integer;
Begin
 HandleDialogEditorClick := False;
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 2 Then Exit;

 DlgIdx := Windows[WndIndex].ResourceIndex;
 If (DlgIdx < 1) Or (DlgIdx > DialogCount) Then Exit;

 PaletteX := Windows[WndIndex].ClientArea.X1;
 PaletteY := Windows[WndIndex].ClientArea.Y1;
 DesignX := Windows[WndIndex].ClientArea.X1 + 70;
 DesignY := Windows[WndIndex].ClientArea.Y1;

 { Verifier clic sur palette }
 If (MX >= PaletteX) And (MX <= PaletteX + 64) And
    (MY >= PaletteY) And (MY <= PaletteY + 250) Then Begin
  I := (MY - PaletteY - 2) Div 22;
  If (I >= 0) And (I <= 10) Then Begin
   DlgEdState.PaletteSelection := I;
   HandleDialogEditorClick := True;
   Exit;
  End;
 End;

 { Verifier clic sur zone de design }
 If (MX >= DesignX + 10) And (MX <= DesignX + 10 + Dialogs[DlgIdx].W) And
    (MY >= DesignY + 10) And (MY <= DesignY + 10 + Dialogs[DlgIdx].H) Then Begin

  ClickedControl := -1;

  { Verifier si clic sur un controle existant }
  For I := Dialogs[DlgIdx].ControlCount DownTo 1 Do Begin
   CtrlX := DesignX + 10 + Dialogs[DlgIdx].Controls[I].X;
   CtrlY := DesignY + 30 + Dialogs[DlgIdx].Controls[I].Y;
   CtrlW := Dialogs[DlgIdx].Controls[I].W;
   CtrlH := Dialogs[DlgIdx].Controls[I].H;
   If (MX >= CtrlX) And (MX <= CtrlX + CtrlW) And
      (MY >= CtrlY) And (MY <= CtrlY + CtrlH) Then Begin
    ClickedControl := I;
    Break;
   End;
  End;

  If ClickedControl > 0 Then Begin
   { Selectionner le controle clique }
   DlgEdState.SelectedControl := ClickedControl;
   DlgEdState.DragMode := 1; { Mode deplacement }
   DlgEdState.DragStartX := MX;
   DlgEdState.DragStartY := MY;
   DlgEdState.DragOffsetX := MX - (DesignX + 10 + Dialogs[DlgIdx].Controls[ClickedControl].X);
   DlgEdState.DragOffsetY := MY - (DesignY + 30 + Dialogs[DlgIdx].Controls[ClickedControl].Y);
  End Else Begin
   { Clic sur le dialogue vide - ajouter nouveau controle si outil selectionne }
   If DlgEdState.PaletteSelection >= 0 Then Begin
    If Dialogs[DlgIdx].ControlCount < MAX_CONTROLS Then Begin
     Inc(Dialogs[DlgIdx].ControlCount);
     With Dialogs[DlgIdx].Controls[Dialogs[DlgIdx].ControlCount] Do Begin
      CtrlType := DlgEdState.PaletteSelection;
      CtrlId := 100 + Dialogs[DlgIdx].ControlCount;
      X := MX - DesignX - 10;
      Y := MY - DesignY - 30;
      { Taille par defaut selon le type }
      Case CtrlType Of
       CTRL_PUSHBUTTON, CTRL_DEFPUSHBUTTON: Begin W := 75; H := 23; Text := 'Button'; End;
       CTRL_CHECKBOX: Begin W := 80; H := 16; Text := 'CheckBox'; End;
       CTRL_RADIOBUTTON: Begin W := 80; H := 16; Text := 'Radio'; End;
       CTRL_EDITTEXT: Begin W := 100; H := 20; Text := ''; End;
       CTRL_COMBOBOX: Begin W := 100; H := 200; Text := ''; End;
       CTRL_LISTBOX: Begin W := 100; H := 80; Text := ''; End;
       CTRL_SCROLLBAR: Begin W := 16; H := 100; Text := ''; End;
       CTRL_STATIC: Begin W := 60; H := 16; Text := 'Label'; End;
       CTRL_GROUPBOX: Begin W := 120; H := 80; Text := 'Group'; End;
       CTRL_ICON: Begin W := 32; H := 32; Text := ''; End;
      Else Begin W := 50; H := 20; Text := ''; End;
      End;
      Style := 0;
      ExStyle := 0;
      ClassName := '';
     End;
     DlgEdState.SelectedControl := Dialogs[DlgIdx].ControlCount;
     AppState.ProjectModified := True;
    End;
   End Else Begin
    { Deselectionner - clic sur fond dialogue }
    DlgEdState.SelectedControl := 0;
   End;
  End;
  HandleDialogEditorClick := True;
 End;
End;

{ Gestion du drag pour deplacement/redimensionnement }
Procedure HandleDialogEditorDrag(WndIndex: Integer; MX, MY: Integer);
Var
 DlgIdx: Integer;
 DesignX, DesignY: Integer;
 NewX, NewY: Integer;
Begin
 If DlgEdState.DragMode = 0 Then Exit;
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;

 DlgIdx := Windows[WndIndex].ResourceIndex;
 If (DlgIdx < 1) Or (DlgIdx > DialogCount) Then Exit;
 If (DlgEdState.SelectedControl < 1) Or
    (DlgEdState.SelectedControl > Dialogs[DlgIdx].ControlCount) Then Exit;

 DesignX := Windows[WndIndex].ClientArea.X1 + 70;
 DesignY := Windows[WndIndex].ClientArea.Y1;

 If DlgEdState.DragMode = 1 Then Begin
  { Mode deplacement }
  NewX := MX - DlgEdState.DragOffsetX - DesignX - 10;
  NewY := MY - DlgEdState.DragOffsetY - DesignY - 30;

  { Aligner sur grille si active }
  If AppState.ShowGrid Then Begin
   NewX := (NewX Div AppState.GridSize) * AppState.GridSize;
   NewY := (NewY Div AppState.GridSize) * AppState.GridSize;
  End;

  { Limiter dans les bornes du dialogue }
  If NewX < 0 Then NewX := 0;
  If NewY < 0 Then NewY := 0;
  If NewX + Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].W > Dialogs[DlgIdx].W Then
   NewX := Dialogs[DlgIdx].W - Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].W;
  If NewY + Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].H > Dialogs[DlgIdx].H - 20 Then
   NewY := Dialogs[DlgIdx].H - 20 - Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].H;

  Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].X := NewX;
  Dialogs[DlgIdx].Controls[DlgEdState.SelectedControl].Y := NewY;
  AppState.ProjectModified := True;
 End;
End;

{ Fin du drag }
Procedure HandleDialogEditorRelease;
Begin
 DlgEdState.DragMode := 0;
End;

Procedure DrawMenuEditor(WndIndex: Integer);
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 3 Then Exit;
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 4, 'Structure du menu:');
End;

Procedure DrawStringTableEditor(WndIndex: Integer);
Var
 I, Y: Integer;
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 4 Then Exit;
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(Windows[WndIndex].ClientArea.X1, Windows[WndIndex].ClientArea.Y1, Windows[WndIndex].ClientArea.X2, Windows[WndIndex].ClientArea.Y1 + 18);
 SetColor(COLOR_BUTTONTEXT);
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 4, 'ID');
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 60, Windows[WndIndex].ClientArea.Y1 + 4, 'Texte');
 Y := Windows[WndIndex].ClientArea.Y1 + 20;
 For I := 1 To StringCount Do Begin
  If Y > Windows[WndIndex].ClientArea.Y2 - 16 Then Break;
  SetColor(COLOR_WINDOWTEXT);
  OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Y, IntToStr(StringEntries[I].StringId));
  OutTextXY(Windows[WndIndex].ClientArea.X1 + 60, Y, StringEntries[I].Text);
  Inc(Y, 16);
 End;
End;

Procedure DrawAccelEditor(WndIndex: Integer);
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 5 Then Exit;
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 4, 'Raccourcis clavier:');
End;

Procedure DrawRCDataEditor(WndIndex: Integer);
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 6 Then Exit;
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 4, 'Editeur hexadecimal:');
End;

Procedure DrawVersionEditor(WndIndex: Integer);
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 7 Then Exit;
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 4, 'Informations de version:');
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 24, 'FileVersion:');
 OutTextXY(Windows[WndIndex].ClientArea.X1 + 4, Windows[WndIndex].ClientArea.Y1 + 44, 'ProductVersion:');
End;

{ ============================================================
  TODO 22 - EXPLORATEUR DE RESSOURCES
  ============================================================ }

Const
 EXPLORER_WIDTH = 180;

{ Obtenir le nom d'un type de ressource }
Function GetResourceTypeName(ResType: Word): String;
Begin
 Case ResType Of
  RT_CURSOR: GetResourceTypeName := 'Curseurs';
  RT_BITMAP: GetResourceTypeName := 'Bitmaps';
  RT_ICON: GetResourceTypeName := 'Icones';
  RT_MENU: GetResourceTypeName := 'Menus';
  RT_DIALOG: GetResourceTypeName := 'Dialogues';
  RT_STRING: GetResourceTypeName := 'Chaines';
  RT_ACCELERATOR: GetResourceTypeName := 'Accelerateurs';
  RT_RCDATA: GetResourceTypeName := 'RCDATA';
  RT_VERSION: GetResourceTypeName := 'Version';
  Else GetResourceTypeName := 'Autre';
 End;
End;

{ Obtenir l'ID d'un type de ressource pour le tableau TreeExpanded }
Function GetTreeExpandedIndex(ResType: Word): Integer;
Begin
 If (ResType >= 1) And (ResType <= 16) Then
  GetTreeExpandedIndex := ResType
 Else
  GetTreeExpandedIndex := 16;
End;

{ Compter les ressources d'un type donne }
Function CountResourcesOfType(ResType: Word): Integer;
Var
 I, Cnt: Integer;
Begin
 Cnt := 0;
 For I := 1 To ResourceCount Do
  If Resources[I].ResType = ResType Then Inc(Cnt);
 CountResourcesOfType := Cnt;
End;

{ Obtenir l'index global d'une ressource par type et rang }
Function GetResourceByTypeAndRank(ResType: Word; Rank: Integer): Integer;
Var
 I, Cnt: Integer;
Begin
 Cnt := 0;
 GetResourceByTypeAndRank := 0;
 For I := 1 To ResourceCount Do Begin
  If Resources[I].ResType = ResType Then Begin
   Inc(Cnt);
   If Cnt = Rank Then Begin
    GetResourceByTypeAndRank := I;
    Exit;
   End;
  End;
 End;
End;

{ Construire l'arbre des ressources }
Procedure BuildResourceTree;
Var
 I, J, NodeIdx, TypeIdx: Integer;
 TypesFound: Array[1..16] Of Word;
 TypeCount: Integer;
 Found: Boolean;
Begin
 { Reinitialiser l'arbre }
 AppState.TreeNodeCount := 0;
 NodeIdx := 0;

 { Collecter tous les types de ressources presents }
 TypeCount := 0;
 For I := 1 To ResourceCount Do Begin
  Found := False;
  For J := 1 To TypeCount Do Begin
   If TypesFound[J] = Resources[I].ResType Then Begin
    Found := True;
    Break;
   End;
  End;
  If Not Found And (TypeCount < 16) Then Begin
   Inc(TypeCount);
   TypesFound[TypeCount] := Resources[I].ResType;
  End;
 End;

 { Creer les noeuds pour chaque type }
 For TypeIdx := 1 To TypeCount Do Begin
  If NodeIdx >= 256 Then Break;
  Inc(NodeIdx);
  With AppState.TreeNodes[NodeIdx] Do Begin
   Expanded := AppState.TreeExpanded[GetTreeExpandedIndex(TypesFound[TypeIdx])];
   HasChildren := True;
   Level := 1;
   ResType := TypesFound[TypeIdx];
   ResIndex := -1;
   Y := 0;
  End;

  { Si le noeud est deplie, ajouter les ressources enfants }
  If AppState.TreeExpanded[GetTreeExpandedIndex(TypesFound[TypeIdx])] Then Begin
   For I := 1 To ResourceCount Do Begin
    If Resources[I].ResType = TypesFound[TypeIdx] Then Begin
     If NodeIdx >= 256 Then Break;
     Inc(NodeIdx);
     With AppState.TreeNodes[NodeIdx] Do Begin
      Expanded := False;
      HasChildren := False;
      Level := 2;
      ResType := TypesFound[TypeIdx];
      ResIndex := I;
      Y := 0;
     End;
    End;
   End;
  End;
 End;

 AppState.TreeNodeCount := NodeIdx;
End;

{ Dessiner l'icone +/- pour les noeuds avec enfants }
Procedure DrawTreeExpandIcon(X, Y: Integer; Expanded: Boolean);
Begin
 SetColor(COLOR_BUTTONTEXT);
 Rectangle(X, Y, X + 8, Y + 8);
 Line(X + 2, Y + 4, X + 6, Y + 4);  { Trait horizontal }
 If Not Expanded Then
  Line(X + 4, Y + 2, X + 4, Y + 6);  { Trait vertical pour le + }
End;

{ Ouvrir l'editeur pour une ressource selectionnee }
Procedure OpenResourceEditor(ResIndex: Integer);
Var
 I: Integer;
 WinType: Integer;
 Title: String;
Begin
 If (ResIndex < 1) Or (ResIndex > ResourceCount) Then Exit;

 { Determiner le type de fenetre a ouvrir }
 Case Resources[ResIndex].ResType Of
  RT_BITMAP, RT_ICON, RT_CURSOR: WinType := 1;  { Editeur bitmap }
  RT_DIALOG: WinType := 2;                       { Editeur dialogue }
  RT_MENU: WinType := 3;                         { Editeur menu }
  RT_STRING: WinType := 4;                       { Editeur chaines }
  RT_ACCELERATOR: WinType := 5;                  { Editeur accelerateurs }
  RT_RCDATA: WinType := 6;                       { Editeur RCDATA }
  RT_VERSION: WinType := 7;                      { Editeur version }
  Else Exit;
 End;

 { Creer le titre de la fenetre }
 If Resources[ResIndex].ResId.IsNumeric Then
  Title := GetResourceTypeName(Resources[ResIndex].ResType) + ' #' + IntToStr(Resources[ResIndex].ResId.NumId)
 Else
  Title := GetResourceTypeName(Resources[ResIndex].ResType) + ' ' + Resources[ResIndex].ResId.StrId;

 { Verifier si une fenetre pour cette ressource existe deja }
 For I := 1 To WindowCount Do Begin
  If Windows[I].Title = Title Then Begin
   ActivateWindow(I);
   Exit;
  End;
 End;

 { Creer une nouvelle fenetre }
 If WindowCount < MAX_WINDOWS Then Begin
  Inc(WindowCount);
  With Windows[WindowCount] Do Begin
   If AppState.ShowExplorer Then Begin
    Bounds.X1 := EXPLORER_WIDTH + 5;
    Bounds.X2 := SCREEN_WIDTH - 10;
   End Else Begin
    Bounds.X1 := 10;
    Bounds.X2 := SCREEN_WIDTH - 10;
   End;
   Bounds.Y1 := MENU_BAR_HEIGHT + TOOLBAR_HEIGHT + 5;
   Bounds.Y2 := SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 10;
   Windows[WindowCount].Title := Title;
   Visible := True;
   Active := True;
   Moveable := True;
   Resizable := True;
   WindowType := WinType;
   ResourceIndex := ResIndex;
  End;
  ActivateWindow(WindowCount);
  { Pour les dialogues, initialiser l'editeur avec l'index de ressource }
  If WinType = 2 Then Begin
   { Trouver le dialogue correspondant - utiliser l'ordre des ressources }
   DlgEdState.DialogIndex := 1;  { Par defaut, premier dialogue }
   DlgEdState.SelectedControl := -1;
  End;
 End;

 NeedRedraw := True;
End;

Procedure DrawResourceExplorer;
Var
 X, Y, I: Integer;
 TreeY: Integer;
 ExpandIcon: String;
 ItemText: String;
 IndentX: Integer;
 MaxY: Integer;
Begin
 If Not AppState.ShowExplorer Then Exit;

 { Reconstruire l'arbre }
 BuildResourceTree;

 X := 0;
 Y := MENU_BAR_HEIGHT + TOOLBAR_HEIGHT;
 MaxY := SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 16;

 HideMouse;

 { Fond du panneau }
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + EXPLORER_WIDTH - 1, SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 1);
 Draw3DRect(X, Y, X + EXPLORER_WIDTH - 1, SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 1, False);

 { En-tete }
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(X + 1, Y + 1, X + EXPLORER_WIDTH - 2, Y + 18);
 SetColor(COLOR_BUTTONTEXT);
 OutTextXY(X + 4, Y + 4, 'Ressources');

 TreeY := Y + 22;

 { Dessiner les noeuds de l'arbre }
 For I := 1 To AppState.TreeNodeCount Do Begin
  If TreeY > MaxY Then Break;

  { Calculer l'indentation }
  IndentX := X + 4 + (AppState.TreeNodes[I].Level - 1) * 16;

  { Sauvegarder la position Y pour la detection des clics }
  AppState.TreeNodes[I].Y := TreeY;

  { Dessiner la selection si c'est le noeud selectionne }
  If I = AppState.TreeSelectedNode Then Begin
   SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
   Bar(X + 2, TreeY, X + EXPLORER_WIDTH - 3, TreeY + 14);
   SetColor(COLOR_HIGHLIGHTTEXT);
  End Else Begin
   SetColor(COLOR_WINDOWTEXT);
  End;

  { Dessiner l'icone +/- pour les noeuds avec enfants }
  If AppState.TreeNodes[I].HasChildren Then Begin
   DrawTreeExpandIcon(IndentX, TreeY + 2, AppState.TreeNodes[I].Expanded);
   IndentX := IndentX + 12;
  End;

  { Preparer le texte a afficher }
  If AppState.TreeNodes[I].Level = 1 Then Begin
   { Noeud de type }
   ItemText := GetResourceTypeName(AppState.TreeNodes[I].ResType);
   ItemText := ItemText + ' (' + IntToStr(CountResourcesOfType(AppState.TreeNodes[I].ResType)) + ')';
  End Else Begin
   { Noeud de ressource individuelle }
   If (AppState.TreeNodes[I].ResIndex >= 1) And
      (AppState.TreeNodes[I].ResIndex <= ResourceCount) Then Begin
    If Resources[AppState.TreeNodes[I].ResIndex].ResId.IsNumeric Then
     ItemText := '#' + IntToStr(Resources[AppState.TreeNodes[I].ResIndex].ResId.NumId)
    Else
     ItemText := Resources[AppState.TreeNodes[I].ResIndex].ResId.StrId;
   End Else
    ItemText := '???';
  End;

  { Afficher le texte }
  OutTextXY(IndentX, TreeY + 2, ItemText);

  Inc(TreeY, 16);
 End;

 { Message si aucune ressource }
 If ResourceCount = 0 Then Begin
  SetColor(COLOR_GRAYTEXT);
  OutTextXY(X + 8, Y + 30, '(Aucune ressource)');
 End;

 ShowMouse;
End;

{ Gestion des clics dans l'explorateur de ressources }
Function HandleResourceExplorerClick(ClickX, ClickY: Integer): Boolean;
Var
 I: Integer;
 ExpIdx: Integer;
Begin
 HandleResourceExplorerClick := False;

 If Not AppState.ShowExplorer Then Exit;
 If ClickX > EXPLORER_WIDTH Then Exit;
 If ClickY < MENU_BAR_HEIGHT + TOOLBAR_HEIGHT + 20 Then Exit;

 { Parcourir les noeuds pour trouver celui qui a ete clique }
 For I := 1 To AppState.TreeNodeCount Do Begin
  If (ClickY >= AppState.TreeNodes[I].Y) And
     (ClickY < AppState.TreeNodes[I].Y + 16) Then Begin
   { Noeud trouve }
   If AppState.TreeNodes[I].HasChildren Then Begin
    { C'est un noeud de type - basculer l'expansion }
    ExpIdx := GetTreeExpandedIndex(AppState.TreeNodes[I].ResType);
    AppState.TreeExpanded[ExpIdx] := Not AppState.TreeExpanded[ExpIdx];
    AppState.TreeSelectedNode := I;
    HandleResourceExplorerClick := True;
    NeedRedraw := True;
   End Else Begin
    { C'est un noeud de ressource - le selectionner et ouvrir l'editeur }
    AppState.TreeSelectedNode := I;
    If AppState.TreeNodes[I].ResIndex > 0 Then
     OpenResourceEditor(AppState.TreeNodes[I].ResIndex);
    HandleResourceExplorerClick := True;
    NeedRedraw := True;
   End;
   Exit;
  End;
 End;
End;

{ ============================================================
  TODO 23 - PRESSE-PAPIERS
  ============================================================ }

Procedure CopyResource(Index: Integer);
Begin
 If (Index < 1) Or (Index > ResourceCount) Then Exit;
 Clipboard.HasData := True;
 Clipboard.DataType := 1;
 Clipboard.ResourceType := Resources[Index].ResType;
End;

Procedure PasteResource;
Begin
 If Not Clipboard.HasData Then Exit;
 If Clipboard.DataType <> 1 Then Exit;
 AppState.ProjectModified := True;
End;

Procedure CutResource(Index: Integer);
Begin
 CopyResource(Index);
 AppState.ProjectModified := True;
End;

{ ============================================================
  TODO 24 - PREVISUALISATION
  ============================================================ }

Procedure PreviewDialog(Index: Integer);
Var
 X, Y: Integer;
Begin
 If (Index < 1) Or (Index > DialogCount) Then Exit;
 X := (SCREEN_WIDTH - Dialogs[Index].W) Div 2;
 Y := (SCREEN_HEIGHT - Dialogs[Index].H) Div 2;
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + Dialogs[Index].W, Y + Dialogs[Index].H);
 Draw3DRect(X, Y, X + Dialogs[Index].W, Y + Dialogs[Index].H, True);
 SetFillStyle(SolidFill, COLOR_TITLEBAR);
 Bar(X + 2, Y + 2, X + Dialogs[Index].W - 2, Y + 18);
 SetColor(COLOR_TITLETEXT);
 OutTextXY(X + 4, Y + 4, Dialogs[Index].Caption);
End;

{ ============================================================
  TODO 25 - GESTION DE PROJET
  ============================================================ }

Procedure NewProject;
Begin
 ResourceCount := 0;
 DialogCount := 0;
 MenuDataCount := 0;
 StringCount := 0;
 AccelCount := 0;
 VersionCount := 0;
 BitmapCount := 0;
 IconCount := 0;
 CursorCount := 0;
 AppState.ProjectFile := '';
 AppState.ProjectModified := False;
 AppState.Is32BitFormat := True;
 NeedRedraw := True;
End;

Procedure OpenProject(Const FileName: String);
Var
 Ext: String;
 I: Integer;
Begin
 Ext := '';
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   Ext := UpCaseStr(Copy(FileName, I, Length(FileName) - I + 1));
   Break;
  End;
 End;
 NewProject;
 If Ext = '.RES' Then
  LoadResFile(FileName)
 Else If Ext = '.RC' Then
  ReadRCFile(FileName);
 AppState.ProjectFile := FileName;
 AppState.ProjectModified := False;
 NeedRedraw := True;
End;

Function GetFileExt(Const FName: String): String;
Var
 I: Integer;
Begin
 GetFileExt := '';
 For I := Length(FName) DownTo 1 Do Begin
  If FName[I] = '.' Then Begin
   GetFileExt := UpCaseStr(Copy(FName, I, Length(FName) - I + 1));
   Exit;
  End;
  If (FName[I] = '\') Or (FName[I] = '/') Then Exit;
 End;
End;

Procedure SaveProject;
Var
 Ext: String;
Begin
 If AppState.ProjectFile = '' Then Exit;
 Ext := GetFileExt(AppState.ProjectFile);
 If Ext = '.RC' Then
  WriteRCFile(AppState.ProjectFile)
 Else
  SaveResFile(AppState.ProjectFile, AppState.Is32BitFormat);
 AppState.ProjectModified := False;
End;

Procedure AddResource(ResType: Word);
Begin
 If ResourceCount >= MAX_RESOURCES Then Exit;
 Inc(ResourceCount);
 Resources[ResourceCount].ResType := ResType;
 Resources[ResourceCount].ResId.IsNumeric := True;
 Resources[ResourceCount].ResId.NumId := ResourceCount;
 Resources[ResourceCount].LangId := AppState.CurrentLangId;
 Resources[ResourceCount].MemFlags := $1030;
 Resources[ResourceCount].DataSize := 0;
 Resources[ResourceCount].Modified := True;
 AppState.ProjectModified := True;
 NeedRedraw := True;
End;

Procedure DeleteResource(Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 1) Or (Index > ResourceCount) Then Exit;
 For I := Index To ResourceCount - 1 Do
  Resources[I] := Resources[I + 1];
 Dec(ResourceCount);
 AppState.ProjectModified := True;
 NeedRedraw := True;
End;

Procedure CompileProject;
Var
 OutFile: String;
Begin
 If AppState.ProjectFile = '' Then Exit;
 OutFile := ChangeFileExt(AppState.ProjectFile, '.RES');
 SaveResFile(OutFile, AppState.Is32BitFormat);
End;

{ ============================================================
  BARRE D'OUTILS
  ============================================================ }

Procedure DrawToolbar;
Var
 X, Y: Integer;
Begin
 Y := MENU_BAR_HEIGHT;
 HideMouse;
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(0, Y, SCREEN_WIDTH - 1, Y + TOOLBAR_HEIGHT - 1);
 Draw3DRect(0, Y, SCREEN_WIDTH - 1, Y + TOOLBAR_HEIGHT - 1, True);
 X := 4;
 DrawButton(X, Y + 4, 24, 24, 'N', False, True);
 X := X + 28;
 DrawButton(X, Y + 4, 24, 24, 'O', False, True);
 X := X + 28;
 DrawButton(X, Y + 4, 24, 24, 'S', False, True);
 X := X + 36;
 DrawButton(X, Y + 4, 24, 24, 'X', False, True);
 X := X + 28;
 DrawButton(X, Y + 4, 24, 24, 'C', False, True);
 X := X + 28;
 DrawButton(X, Y + 4, 24, 24, 'V', False, True);
 X := X + 36;
 DrawButton(X, Y + 4, 24, 24, 'Z', False, True);
 X := X + 36;
 DrawButton(X, Y + 4, 24, 24, '+', False, True);
 X := X + 28;
 DrawButton(X, Y + 4, 24, 24, '-', False, True);
 ShowMouse;
End;

{ ============================================================
  BARRE D'ETAT
  ============================================================ }

Procedure DrawStatusBar;
Var
 Y: Integer;
 Status: String;
Begin
 Y := SCREEN_HEIGHT - STATUS_BAR_HEIGHT;
 HideMouse;
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(0, Y, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1);
 Draw3DRect(0, Y, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1, False);
 SetColor(COLOR_BUTTONTEXT);
 If AppState.ProjectFile <> '' Then
  Status := AppState.ProjectFile
 Else
  Status := 'Nouveau projet';
 If AppState.ProjectModified Then
  Status := Status + ' *';
 OutTextXY(4, Y + 4, Status);
 OutTextXY(SCREEN_WIDTH - 100, Y + 4, 'X:' + IntToStr(MouseX) + ' Y:' + IntToStr(MouseY));
 ShowMouse;
End;

{ ============================================================
  DIALOGUES MODAUX
  ============================================================ }

{ Boite de dialogue Ouvrir fichier }
Function ShowOpenFileDialog: String;
Const
 MAX_FILES = 50;
 LIST_HEIGHT = 8;
Var
 X, Y, W, H: Integer;
 EditText: String;
 CursorPos: Integer;
 Files: Array[1..MAX_FILES] Of String;
 FileCount: Integer;
 TopIndex: Integer;
 SelectedIndex: Integer;
 I, J: Integer;
 DirInfo: SearchRec;
 Done: Boolean;
 Result: Boolean;
 Ch: Char;
 ListY, ListH: Integer;
 BtnOkX, BtnCancelX, BtnY: Integer;
 EditX, EditY, EditW: Integer;
 ClickedItem: Integer;
 ExtFilter: String;

 Procedure ScanFiles;
 Var
  Sr: SearchRec;
  I, J: Integer;
  TmpStr: String;
 Begin
  FileCount := 0;
  { Chercher les fichiers .RC }
  FindFirst('*.RC', Archive, Sr);
  While DosError = 0 Do Begin
   If FileCount < MAX_FILES Then Begin
    Inc(FileCount);
    Files[FileCount] := Sr.Name;
   End;
   FindNext(Sr);
  End;
  { Chercher les fichiers .RES }
  FindFirst('*.RES', Archive, Sr);
  While DosError = 0 Do Begin
   If FileCount < MAX_FILES Then Begin
    Inc(FileCount);
    Files[FileCount] := Sr.Name;
   End;
   FindNext(Sr);
  End;
  { Trier les fichiers par ordre alphabetique }
  For I := 1 To FileCount - 1 Do
   For J := I + 1 To FileCount Do
    If Files[I] > Files[J] Then Begin
     TmpStr := Files[I];
     Files[I] := Files[J];
     Files[J] := TmpStr;
    End;
 End;

 Procedure DrawDialog;
 Var
  DisplayY, FileIdx, I: Integer;
 Begin
  HideMouse;
  { Fond de la boite de dialogue }
  SetFillStyle(SolidFill, COLOR_WINDOW);
  Bar(X, Y, X + W, Y + H);
  Draw3DRect(X, Y, X + W, Y + H, True);
  { Barre de titre }
  SetFillStyle(SolidFill, COLOR_TITLEBAR);
  Bar(X + 2, Y + 2, X + W - 2, Y + 18);
  SetColor(COLOR_TITLETEXT);
  OutTextXY(X + 4, Y + 4, 'Ouvrir un fichier');
  { Label "Nom du fichier:" }
  SetColor(COLOR_WINDOWTEXT);
  OutTextXY(X + 10, EditY - 16, 'Nom du fichier:');
  { Champ d'edition }
  SetFillStyle(SolidFill, White);
  Bar(EditX, EditY, EditX + EditW, EditY + 18);
  Draw3DRect(EditX, EditY, EditX + EditW, EditY + 18, False);
  SetColor(Black);
  OutTextXY(EditX + 4, EditY + 4, EditText);
  { Curseur }
  If CursorPos <= Length(EditText) Then
   Line(EditX + 4 + CursorPos * 8, EditY + 2, EditX + 4 + CursorPos * 8, EditY + 16);
  { Label "Fichiers:" }
  SetColor(COLOR_WINDOWTEXT);
  OutTextXY(X + 10, ListY - 16, 'Fichiers (.RC, .RES):');
  { Liste des fichiers }
  SetFillStyle(SolidFill, White);
  Bar(X + 10, ListY, X + W - 90, ListY + ListH);
  Draw3DRect(X + 10, ListY, X + W - 90, ListY + ListH, False);
  SetColor(Black);
  DisplayY := ListY + 2;
  For I := TopIndex To TopIndex + LIST_HEIGHT - 1 Do Begin
   If I <= FileCount Then Begin
    FileIdx := I;
    If FileIdx = SelectedIndex Then Begin
     SetFillStyle(SolidFill, COLOR_HIGHLIGHT);
     Bar(X + 11, DisplayY, X + W - 91, DisplayY + 14);
     SetColor(COLOR_HIGHLIGHTTEXT);
    End Else Begin
     SetColor(Black);
    End;
    OutTextXY(X + 14, DisplayY + 2, Files[FileIdx]);
    Inc(DisplayY, 14);
   End;
  End;
  { Barre de defilement }
  SetFillStyle(SolidFill, COLOR_SCROLLBAR);
  Bar(X + W - 86, ListY, X + W - 70, ListY + ListH);
  Draw3DRect(X + W - 86, ListY, X + W - 70, ListY + ListH, False);
  { Bouton haut }
  DrawButton(X + W - 85, ListY + 1, 14, 14, '^', False, True);
  { Bouton bas }
  DrawButton(X + W - 85, ListY + ListH - 15, 14, 14, 'v', False, True);
  { Boutons Ouvrir et Annuler }
  DrawButton(BtnOkX, BtnY, 70, 24, 'Ouvrir', False, True);
  DrawButton(BtnCancelX, BtnY, 70, 24, 'Annuler', False, True);
  { Message si aucun fichier }
  If FileCount = 0 Then Begin
   SetColor(COLOR_GRAYTEXT);
   OutTextXY(X + 14, ListY + 20, '(Aucun fichier)');
  End;
  ShowMouse;
 End;

Begin
 ShowOpenFileDialog := '';
 W := 400;
 H := 300;
 X := (SCREEN_WIDTH - W) Div 2;
 Y := (SCREEN_HEIGHT - H) Div 2;
 EditX := X + 10;
 EditY := Y + 36;
 EditW := W - 100;
 ListY := Y + 80;
 ListH := LIST_HEIGHT * 14 + 4;
 BtnOkX := X + W - 160;
 BtnCancelX := X + W - 80;
 BtnY := Y + H - 35;
 EditText := '';
 CursorPos := 0;
 TopIndex := 1;
 SelectedIndex := 0;
 Done := False;
 Result := False;
 ScanFiles;
 DrawDialog;

 While Not Done Do Begin
  UpdateMouse;

  { Gestion des touches clavier }
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch = #0 Then Begin
    Ch := ReadKey;
    Case Ch Of
     #72: Begin { Fleche haut }
      If SelectedIndex > 1 Then Begin
       Dec(SelectedIndex);
       If SelectedIndex < TopIndex Then TopIndex := SelectedIndex;
       EditText := Files[SelectedIndex];
       CursorPos := Length(EditText);
       DrawDialog;
      End;
     End;
     #80: Begin { Fleche bas }
      If SelectedIndex < FileCount Then Begin
       Inc(SelectedIndex);
       If SelectedIndex > TopIndex + LIST_HEIGHT - 1 Then TopIndex := SelectedIndex - LIST_HEIGHT + 1;
       EditText := Files[SelectedIndex];
       CursorPos := Length(EditText);
       DrawDialog;
      End;
     End;
     #75: Begin { Fleche gauche }
      If CursorPos > 0 Then Begin
       Dec(CursorPos);
       DrawDialog;
      End;
     End;
     #77: Begin { Fleche droite }
      If CursorPos < Length(EditText) Then Begin
       Inc(CursorPos);
       DrawDialog;
      End;
     End;
    End;
   End Else Begin
    Case Ch Of
     #13: Begin { Entree }
      If EditText <> '' Then Begin
       Result := True;
       Done := True;
      End;
     End;
     #27: Begin { Echap }
      Done := True;
     End;
     #8: Begin { Backspace }
      If (Length(EditText) > 0) And (CursorPos > 0) Then Begin
       Delete(EditText, CursorPos, 1);
       Dec(CursorPos);
       DrawDialog;
      End;
     End;
     Else Begin
      If (Length(EditText) < 127) And (Ch >= ' ') Then Begin
       Insert(Ch, EditText, CursorPos + 1);
       Inc(CursorPos);
       DrawDialog;
      End;
     End;
    End;
   End;
  End;

  { Gestion des clics souris }
  If MouseClicked Then Begin
   { Clic sur un fichier de la liste }
   If (MouseX >= X + 10) And (MouseX <= X + W - 90) And
      (MouseY >= ListY) And (MouseY <= ListY + ListH) Then Begin
    ClickedItem := TopIndex + (MouseY - ListY) Div 14;
    If (ClickedItem >= 1) And (ClickedItem <= FileCount) Then Begin
     SelectedIndex := ClickedItem;
     EditText := Files[SelectedIndex];
     CursorPos := Length(EditText);
     DrawDialog;
    End;
   End
   { Clic sur le champ d'edition }
   Else If (MouseX >= EditX) And (MouseX <= EditX + EditW) And
           (MouseY >= EditY) And (MouseY <= EditY + 18) Then Begin
    CursorPos := (MouseX - EditX - 4) Div 8;
    If CursorPos < 0 Then CursorPos := 0;
    If CursorPos > Length(EditText) Then CursorPos := Length(EditText);
    DrawDialog;
   End
   { Clic sur bouton Ouvrir }
   Else If (MouseX >= BtnOkX) And (MouseX <= BtnOkX + 70) And
           (MouseY >= BtnY) And (MouseY <= BtnY + 24) Then Begin
    If EditText <> '' Then Begin
     Result := True;
     Done := True;
    End;
   End
   { Clic sur bouton Annuler }
   Else If (MouseX >= BtnCancelX) And (MouseX <= BtnCancelX + 70) And
           (MouseY >= BtnY) And (MouseY <= BtnY + 24) Then Begin
    Done := True;
   End
   { Clic sur bouton defilement haut }
   Else If (MouseX >= X + W - 85) And (MouseX <= X + W - 71) And
           (MouseY >= ListY + 1) And (MouseY <= ListY + 15) Then Begin
    If TopIndex > 1 Then Begin
     Dec(TopIndex);
     DrawDialog;
    End;
   End
   { Clic sur bouton defilement bas }
   Else If (MouseX >= X + W - 85) And (MouseX <= X + W - 71) And
           (MouseY >= ListY + ListH - 15) And (MouseY <= ListY + ListH - 1) Then Begin
    If TopIndex + LIST_HEIGHT - 1 < FileCount Then Begin
     Inc(TopIndex);
     DrawDialog;
    End;
   End;
  End;

  Delay(10);
 End;

 If Result Then
  ShowOpenFileDialog := EditText
 Else
  ShowOpenFileDialog := '';
 NeedRedraw := True;
End;

Procedure ShowAboutDialog;
Var
 X, Y, W, H: Integer;
Begin
 W := 300;
 H := 150;
 X := (SCREEN_WIDTH - W) Div 2;
 Y := (SCREEN_HEIGHT - H) Div 2;
 HideMouse;
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + W, Y + H);
 Draw3DRect(X, Y, X + W, Y + H, True);
 SetFillStyle(SolidFill, COLOR_TITLEBAR);
 Bar(X + 2, Y + 2, X + W - 2, Y + 18);
 SetColor(COLOR_TITLETEXT);
 OutTextXY(X + 4, Y + 4, 'A propos');
 SetColor(COLOR_WINDOWTEXT);
 OutTextXY(X + 20, Y + 30, 'Resource Editor Workshop');
 OutTextXY(X + 20, Y + 50, 'Version ' + WORKSHOP_VERSION);
 OutTextXY(X + 20, Y + 70, 'Date: ' + WORKSHOP_DATE);
 OutTextXY(X + 20, Y + 90, 'Clone de Borland Resource Workshop');
 DrawButton(X + (W - 60) Div 2, Y + H - 30, 60, 22, 'OK', False, True);
 ShowMouse;
 Repeat
  UpdateMouse;
 Until MouseClicked;
 NeedRedraw := True;
End;

{ ============================================================
  TRAITEMENT DES COMMANDES
  ============================================================ }

Procedure ProcessCommand(Cmd: Integer);
Var
 OpenFileName: String;
Begin
 Case Cmd Of
  CMD_FILE_NEW: NewProject;
  CMD_FILE_OPEN: Begin
   OpenFileName := ShowOpenFileDialog;
   If OpenFileName <> '' Then
    OpenProject(OpenFileName);
  End;
  CMD_FILE_SAVE: SaveProject;
  CMD_FILE_IMPORT_MAC: ImportMacResource('');
  CMD_FILE_IMPORT_GEM: ImportGEMResource('');
  CMD_FILE_EXIT: Running := False;
  CMD_EDIT_CUT: CutResource(1);
  CMD_EDIT_COPY: CopyResource(1);
  CMD_EDIT_PASTE: PasteResource;
  CMD_EDIT_DELETE: DeleteResource(1);
  CMD_VIEW_EXPLORER: Begin
   AppState.ShowExplorer := Not AppState.ShowExplorer;
   MainMenuBar.Menus[4].Items[1].Checked := AppState.ShowExplorer;
   NeedRedraw := True;
  End;
  CMD_VIEW_PROPERTIES: Begin
   AppState.ShowProperties := Not AppState.ShowProperties;
   MainMenuBar.Menus[4].Items[2].Checked := AppState.ShowProperties;
   NeedRedraw := True;
  End;
  CMD_VIEW_ZOOMIN: Begin
   If AppState.ZoomLevel < 16 Then AppState.ZoomLevel := AppState.ZoomLevel * 2;
   NeedRedraw := True;
  End;
  CMD_VIEW_ZOOMOUT: Begin
   If AppState.ZoomLevel > 1 Then AppState.ZoomLevel := AppState.ZoomLevel Div 2;
   NeedRedraw := True;
  End;
  CMD_VIEW_GRID: Begin
   AppState.ShowGrid := Not AppState.ShowGrid;
   NeedRedraw := True;
  End;
  CMD_PROJECT_ADDRES: AddResource(RT_DIALOG);
  CMD_PROJECT_DELRES: DeleteResource(ResourceCount);
  CMD_PROJECT_COMPILE: CompileProject;
  CMD_HELP_ABOUT: ShowAboutDialog;
 End;
End;

{ ============================================================
  GESTION DES EVENEMENTS
  ============================================================ }

Procedure HandleKeyPress;
Var
 Ch: Char;
Begin
 If KeyPressed Then Begin
  Ch := ReadKey;
  If Ch = #0 Then Begin
   Ch := ReadKey;
   Case Ch Of
    #59: ProcessCommand(CMD_HELP_INDEX);
    #60: ProcessCommand(CMD_FILE_SAVE);
    #61: ProcessCommand(CMD_VIEW_EXPLORER);
    #67: ProcessCommand(CMD_PROJECT_COMPILE);
    #68: Running := False;
    #107: Running := False; { Alt+F4 }
   End;
  End
  Else Begin
   Case Ch Of
    #27: CloseAllMenus;
   End;
  End;
 End;
End;

Procedure HandleMouseClick;
Var
 Cmd: Integer;
 I: Integer;
 R: TRect;
 ClickedOnExplorer: Boolean;
Begin
 If MouseClicked Then Begin
  If (MouseY < MENU_BAR_HEIGHT) Or MainMenuBar.MenuOpen Then Begin
   Cmd := HandleMenuClick(MouseX, MouseY);
   If Cmd <> CMD_NONE Then ProcessCommand(Cmd);
  End
  Else If MouseY < MENU_BAR_HEIGHT + TOOLBAR_HEIGHT Then Begin
   { Toolbar clicks }
  End
  Else If MouseY < SCREEN_HEIGHT - STATUS_BAR_HEIGHT Then Begin
   { Verifier d'abord si le clic est dans l'explorateur de ressources }
   ClickedOnExplorer := False;
   If AppState.ShowExplorer And (MouseX < EXPLORER_WIDTH) Then Begin
    ClickedOnExplorer := HandleResourceExplorerClick(MouseX, MouseY);
   End;

   { Si pas dans l'explorateur, verifier les fenetres }
   If Not ClickedOnExplorer Then Begin
    For I := WindowCount DownTo 1 Do Begin
     R := Windows[I].Bounds;
     If MouseInRect(R) Then Begin
      ActivateWindow(I);
      If (MouseX >= R.X2 - 18) And (MouseX <= R.X2 - 4) And
         (MouseY >= R.Y1 + 4) And (MouseY <= R.Y1 + 18) Then Begin
       CloseWindow(I);
      End Else If Windows[I].WindowType = 2 Then Begin
       { Editeur de dialogue WYSIWYG }
       If HandleDialogEditorClick(I, MouseX, MouseY, MouseButton) Then
        NeedRedraw := True;
      End;
      Break;
     End;
    End;
   End;
  End;
 End
 Else If MainMenuBar.MenuOpen Then Begin
  UpdateMenuHighlight(MouseX, MouseY);
 End
 Else Begin
  { Gestion du drag dans l'editeur de dialogues }
  If (MouseButton And 1 = 1) And (DlgEdState.DragMode > 0) Then Begin
   For I := 1 To WindowCount Do Begin
    If Windows[I].WindowType = 2 Then Begin
     HandleDialogEditorDrag(I, MouseX, MouseY);
     NeedRedraw := True;
     Break;
    End;
   End;
  End Else If (MouseButton And 1 = 0) And (DlgEdState.DragMode > 0) Then Begin
   HandleDialogEditorRelease;
  End;
 End;
End;

{ ============================================================
  BOUCLE PRINCIPALE
  ============================================================ }

Procedure DrawScreen;
Var
 I: Integer;
Begin
 HideMouse;
 SetFillStyle(SolidFill, COLOR_BACKGROUND);
 Bar(0, MENU_BAR_HEIGHT + TOOLBAR_HEIGHT, SCREEN_WIDTH - 1, SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 1);
 DrawMenuBar;
 DrawToolbar;
 DrawStatusBar;
 DrawResourceExplorer;
 For I := 1 To WindowCount Do Begin
  DrawWindow(Windows[I]);
  Case Windows[I].WindowType Of
   1: DrawBitmapEditor(I);
   2: DrawDialogEditor(I);
   3: DrawMenuEditor(I);
   4: DrawStringTableEditor(I);
   5: DrawAccelEditor(I);
   6: DrawRCDataEditor(I);
   7: DrawVersionEditor(I);
  End;
 End;
 If MainMenuBar.MenuOpen Then
  DrawDropDownMenu(MainMenuBar.ActiveMenu);
 ShowMouse;
End;

Procedure Initialize;
Var
 I: Integer;
Begin
 { Allouer le buffer RSC sur le tas }
 GetMem(RSCFileBuffer, SizeOf(TRSCFileBuffer));
 Running := True;
 NeedRedraw := True;
 WindowCount := 0;
 ActiveWindowIndex := 0;
 ResourceCount := 0;
 DialogCount := 0;
 MenuDataCount := 0;
 StringCount := 0;
 AccelCount := 0;
 VersionCount := 0;
 BitmapCount := 0;
 IconCount := 0;
 CursorCount := 0;
 Clipboard.HasData := False;
 AppState.ProjectFile := '';
 AppState.ProjectModified := False;
 AppState.Is32BitFormat := True;
 AppState.CurrentLangId := $0409;
 AppState.CurrentTool := TOOL_PENCIL;
 AppState.CurrentColor := 0;
 AppState.ZoomLevel := 4;
 AppState.ShowGrid := True;
 AppState.GridSize := 8;
 AppState.ShowExplorer := True;
 AppState.ShowProperties := True;
 { Initialiser l'arbre de ressources }
 AppState.TreeNodeCount := 0;
 AppState.TreeSelectedNode := 0;
 AppState.TreeScrollPos := 0;
 For I := 1 To 16 Do
  AppState.TreeExpanded[I] := True;  { Tous les noeuds deplies par defaut }
 { Initialiser l'editeur WYSIWYG de dialogues }
 DlgEdState.DialogIndex := 0;
 DlgEdState.SelectedControl := -1;
 DlgEdState.DragMode := 0;
 DlgEdState.PaletteSelection := CTRL_PUSHBUTTON;
 DlgEdState.ShowHandles := True;
 InitializeGraphics;
 InitMouse;
 InitMenuBar;
End;

Procedure Cleanup;
Begin
 HideMouse;
 CloseGraphics;
 { Liberer le buffer RSC du tas }
 If RSCFileBuffer <> Nil Then
  FreeMem(RSCFileBuffer, SizeOf(TRSCFileBuffer));
End;

Procedure MainLoop;
Begin
 While Running Do Begin
  UpdateMouse;
  HandleKeyPress;
  HandleMouseClick;
  If NeedRedraw Then Begin
   DrawScreen;
   NeedRedraw := False;
  End;
  Delay(10);
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 Initialize;
 If ParamCount > 0 Then
  OpenProject(ParamStr(1));
 MainLoop;
 Cleanup;
END.
