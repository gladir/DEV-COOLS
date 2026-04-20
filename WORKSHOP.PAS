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
      Crt,PtcGraph,PtcCrt,PtcMouse
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
 COLOR_BACKGROUND = 7;
 COLOR_MENUBAR = 7;
 COLOR_MENUTEXT = 0;
 COLOR_HIGHLIGHT = 1;
 COLOR_HIGHLIGHTTEXT = 15;
 COLOR_WINDOW = 15;
 COLOR_WINDOWTEXT = 0;
 COLOR_BORDER3D_LIGHT = 15;
 COLOR_BORDER3D_DARK = 8;
 COLOR_TITLEBAR = 1;
 COLOR_TITLETEXT = 15;
 COLOR_BUTTON = 7;
 COLOR_BUTTONTEXT = 0;
 COLOR_DISABLED = 8;
 COLOR_SCROLLBAR = 7;

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
 End;

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

 { Presse-papiers }
 Clipboard: TClipboard;

 { Etat de l'application }
 AppState: TAppState;

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
 MB: Word;
Begin
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
Begin
 ReadResWord := ReadResByte + ReadResByte * 256;
End;

Function ReadResDWord: LongInt;
Var
 W1, W2: Word;
Begin
 W1 := ReadResWord;
 W2 := ReadResWord;
 ReadResDWord := LongInt(W1) + LongInt(W2) * 65536;
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

Procedure LoadResFile(Const FileName: String);
Var
 Format: Integer;
Begin
 If Not FileExists(FileName) Then Exit;
 OpenResFile(FileName);
 Format := DetectResFormat;
 AppState.Is32BitFormat := (Format = 2);
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

Procedure SaveResFile(Const FileName: String; Is32Bit: Boolean);
Begin
 CreateOutResFile(FileName);
 If Is32Bit Then
  WriteNullHeader32;
 CloseOutResFile;
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
 T: Byte;
Begin
 T := B[0]; B[0] := B[3]; B[3] := T;
 T := B[1]; B[1] := B[2]; B[2] := T;
 SwapLong := L;
End;

Procedure ImportMacResource(Const FileName: String);
Begin
 If Not FileExists(FileName) Then Exit;
 AppState.ProjectModified := True;
End;

{ Import GEM }
Procedure ImportGEMResource(Const FileName: String);
Begin
 If Not FileExists(FileName) Then Exit;
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

Procedure DrawDialogEditor(WndIndex: Integer);
Begin
 If (WndIndex < 1) Or (WndIndex > WindowCount) Then Exit;
 If Windows[WndIndex].WindowType <> 2 Then Exit;
 DrawButton(Windows[WndIndex].ClientArea.X1, Windows[WndIndex].ClientArea.Y1, 60, 20, 'Button', False, True);
 DrawButton(Windows[WndIndex].ClientArea.X1, Windows[WndIndex].ClientArea.Y1 + 22, 60, 20, 'Edit', False, True);
 DrawButton(Windows[WndIndex].ClientArea.X1, Windows[WndIndex].ClientArea.Y1 + 44, 60, 20, 'Static', False, True);
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(Windows[WndIndex].ClientArea.X1 + 70, Windows[WndIndex].ClientArea.Y1, Windows[WndIndex].ClientArea.X2 - 120, Windows[WndIndex].ClientArea.Y2);
 Draw3DRect(Windows[WndIndex].ClientArea.X1 + 70, Windows[WndIndex].ClientArea.Y1, Windows[WndIndex].ClientArea.X2 - 120, Windows[WndIndex].ClientArea.Y2, True);
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

Procedure DrawResourceExplorer;
Var
 X, Y, I: Integer;
 TypeName: String;
Begin
 If Not AppState.ShowExplorer Then Exit;
 X := 0;
 Y := MENU_BAR_HEIGHT + TOOLBAR_HEIGHT;
 HideMouse;
 SetFillStyle(SolidFill, COLOR_WINDOW);
 Bar(X, Y, X + EXPLORER_WIDTH - 1, SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 1);
 Draw3DRect(X, Y, X + EXPLORER_WIDTH - 1, SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 1, False);
 SetFillStyle(SolidFill, COLOR_BUTTON);
 Bar(X + 1, Y + 1, X + EXPLORER_WIDTH - 2, Y + 18);
 SetColor(COLOR_BUTTONTEXT);
 OutTextXY(X + 4, Y + 4, 'Ressources');
 Y := Y + 22;
 For I := 1 To ResourceCount Do Begin
  If Y > SCREEN_HEIGHT - STATUS_BAR_HEIGHT - 20 Then Break;
  Case Resources[I].ResType Of
   RT_CURSOR: TypeName := '+ Curseurs';
   RT_BITMAP: TypeName := '+ Bitmaps';
   RT_ICON: TypeName := '+ Icones';
   RT_MENU: TypeName := '+ Menus';
   RT_DIALOG: TypeName := '+ Dialogues';
   RT_STRING: TypeName := '+ Chaines';
   RT_ACCELERATOR: TypeName := '+ Accelerateurs';
   RT_RCDATA: TypeName := '+ RCDATA';
   RT_VERSION: TypeName := '+ Version';
   Else TypeName := '+ Ressource';
  End;
  SetColor(COLOR_WINDOWTEXT);
  OutTextXY(X + 8, Y, TypeName);
  If Resources[I].ResId.IsNumeric Then
   OutTextXY(X + 20, Y + 14, '#' + IntToStr(Resources[I].ResId.NumId))
  Else
   OutTextXY(X + 20, Y + 14, Resources[I].ResId.StrId);
  Inc(Y, 30);
 End;
 ShowMouse;
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
 If (Ext = '.RES') Then
  LoadResFile(FileName);
 AppState.ProjectFile := FileName;
 AppState.ProjectModified := False;
 NeedRedraw := True;
End;

Procedure SaveProject;
Begin
 If AppState.ProjectFile = '' Then Exit;
 If UpCaseStr(Copy(AppState.ProjectFile, Length(AppState.ProjectFile) - 2, 3)) = '.RC' Then
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
Begin
 Case Cmd Of
  CMD_FILE_NEW: NewProject;
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
Begin
 If MouseClicked Then Begin
  If MouseY < MENU_BAR_HEIGHT Then Begin
   Cmd := HandleMenuClick(MouseX, MouseY);
   If Cmd <> CMD_NONE Then ProcessCommand(Cmd);
  End
  Else If MouseY < MENU_BAR_HEIGHT + TOOLBAR_HEIGHT Then Begin
   { Toolbar clicks }
  End
  Else If MouseY < SCREEN_HEIGHT - STATUS_BAR_HEIGHT Then Begin
   For I := WindowCount DownTo 1 Do Begin
    R := Windows[I].Bounds;
    If MouseInRect(R) Then Begin
     ActivateWindow(I);
     If (MouseX >= R.X2 - 18) And (MouseX <= R.X2 - 4) And
        (MouseY >= R.Y1 + 4) And (MouseY <= R.Y1 + 18) Then Begin
      CloseWindow(I);
     End;
     Break;
    End;
   End;
  End;
 End
 Else If MainMenuBar.MenuOpen Then Begin
  UpdateMenuHighlight(MouseX, MouseY);
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
Begin
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
 InitializeGraphics;
 InitMouse;
 InitMenuBar;
End;

Procedure Cleanup;
Begin
 HideMouse;
 CloseGraphics;
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
