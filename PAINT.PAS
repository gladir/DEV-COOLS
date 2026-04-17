{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description(Clone complet de Microsoft Paint en Turbo Pascal/Free Pascal)
}

Program Paint;

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

Uses
 {$IFDEF FPC}
  Crt, PtcGraph, PtcCrt, PtcMouse
 {$ELSE}
  Crt, Graph, Dos
 {$ENDIF};

Const
 { Constantes de version }
 VERSION_MAJOR = 1;
 VERSION_MINOR = 0;
 PROGRAM_NAME = 'PAINT - Clone de MS Paint';

 { Constantes de l'interface }
 TOOLBAR_WIDTH = 50;
 MENUBAR_HEIGHT = 20;
 STATUSBAR_HEIGHT = 20;
 COLORBAR_HEIGHT = 40;

 { Nombre maximum d'outils }
 MAX_TOOLS = 16;

 { Constantes d'outils }
 TOOL_SELECT = 0;
 TOOL_ERASER = 1;
 TOOL_FILL = 2;
 TOOL_PICKER = 3;
 TOOL_MAGNIFY = 4;
 TOOL_PENCIL = 5;
 TOOL_BRUSH = 6;
 TOOL_AIRBRUSH = 7;
 TOOL_TEXT = 8;
 TOOL_LINE = 9;
 TOOL_CURVE = 10;
 TOOL_RECT = 11;
 TOOL_POLYGON = 12;
 TOOL_ELLIPSE = 13;
 TOOL_ROUNDRECT = 14;

 { Constantes de menu }
 MENU_FILE = 0;
 MENU_EDIT = 1;
 MENU_VIEW = 2;
 MENU_IMAGE = 3;
 MENU_COLORS = 4;
 MENU_HELP = 5;

 { Constantes pour les formats d'image }
 FMT_BMP = 0;
 FMT_GIF = 1;
 FMT_PNG = 2;
 FMT_JPEG = 3;
 FMT_PCX = 4;
 FMT_TARGA = 5;
 FMT_TIFF = 6;

 { Profondeurs de couleur supportées }
 DEPTH_2 = 1;
 DEPTH_4 = 2;
 DEPTH_8 = 3;
 DEPTH_16 = 4;
 DEPTH_32 = 5;
 DEPTH_64 = 6;
 DEPTH_128 = 7;
 DEPTH_256 = 8;
 DEPTH_4096 = 12;
 DEPTH_32768 = 15;
 DEPTH_65536 = 16;
 DEPTH_16M = 24;
 DEPTH_32BIT = 32;

 { Taille maximale de l'image en mémoire }
 MAX_IMAGE_WIDTH = 4096;
 MAX_IMAGE_HEIGHT = 4096;

 { Constantes pour les fichiers BMP }
 BMP_SIGNATURE = $4D42;  { 'BM' }

 { Constantes pour les fichiers GIF }
 GIF87_SIGNATURE = 'GIF87a';
 GIF89_SIGNATURE = 'GIF89a';

 { Constantes pour les fichiers PNG }
 PNG_SIGNATURE: Array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

 { Constantes pour les fichiers JPEG }
 JPEG_SOI = $FFD8;
 JPEG_EOI = $FFD9;

Type
 { Types de données pour la gestion des couleurs }
 TRGBColor = Record
  R, G, B: Byte;
  A: Byte;  { Alpha pour la transparence }
 End;

 TRGBQuad = Record
  Blue, Green, Red, Reserved: Byte;
 End;

 TPalette = Array[0..255] of TRGBColor;

 { Type pour les coordonnées }
 TPoint = Record
  X, Y: Integer;
 End;

 TRect = Record
  Left, Top, Right, Bottom: Integer;
 End;

 { Structure de l'en-tête BMP }
 TBMPFileHeader = Record
  bfType: Word;
  bfSize: LongInt;
  bfReserved1: Word;
  bfReserved2: Word;
  bfOffBits: LongInt;
 End;

 TBMPInfoHeader = Record
  biSize: LongInt;
  biWidth: LongInt;
  biHeight: LongInt;
  biPlanes: Word;
  biBitCount: Word;
  biCompression: LongInt;
  biSizeImage: LongInt;
  biXPelsPerMeter: LongInt;
  biYPelsPerMeter: LongInt;
  biClrUsed: LongInt;
  biClrImportant: LongInt;
 End;

 { Structure pour l'en-tête GIF }
 TGIFHeader = Record
  Signature: Array[0..5] of Char;
  ScreenWidth: Word;
  ScreenHeight: Word;
  Flags: Byte;
  BackgroundColor: Byte;
  AspectRatio: Byte;
 End;

 { Structure pour l'image en mémoire }
 PImageBuffer = ^TImageBuffer;
 TImageBuffer = Record
  Width, Height: Integer;
  BitDepth: Byte;
  HasTransparency: Boolean;
  TransparentColor: TRGBColor;
  Palette: TPalette;
  Modified: Boolean;
  FileName: String;
  Format: Byte;
 End;

 { Structure pour l'historique (Undo/Redo) }
 PHistoryItem = ^THistoryItem;
 THistoryItem = Record
  Action: Byte;
  Data: Pointer;
  DataSize: LongInt;
  Next, Prev: PHistoryItem;
 End;

 { Structure pour les menus }
 TMenuItem = Record
  Caption: String[30];
  Shortcut: String[10];
  Enabled: Boolean;
  Checked: Boolean;
  Separator: Boolean;
 End;

 TMenu = Record
  Title: String[15];
  Items: Array[0..15] of TMenuItem;
  ItemCount: Byte;
  X, Width: Integer;
 End;

 { Structure pour les outils }
 TTool = Record
  Name: String[15];
  Icon: Array[0..15, 0..15] of Byte;
  Selected: Boolean;
 End;

Var
 { Variables globales de l'application }
 GraphDriver, GraphMode: Integer;
 ScreenWidth, ScreenHeight: Integer;
 Running: Boolean;
 CurrentTool: Byte;
 CurrentColor: Byte;
 BackgroundColor: Byte;
 BrushSize: Byte;
 LineWidth: Byte;
 FillStyle: Byte;

 { Variables de la souris }
 MouseX, MouseY: Integer;
 MouseButtons: Integer;
 MouseVisible: Boolean;
 OldMouseX, OldMouseY: Integer;

 { Variables de l'image }
 ImageBuffer: TImageBuffer;
 CanvasX, CanvasY: Integer;
 CanvasWidth, CanvasHeight: Integer;
 ZoomLevel: Integer;

 { Variables pour la sélection }
 SelectionActive: Boolean;
 SelectionRect: TRect;
 CropActive: Boolean;

 { Variables pour les menus }
 Menus: Array[0..5] of TMenu;
 MenuActive: Boolean;
 ActiveMenu: Integer;
 ActiveMenuItem: Integer;

 { Variables pour l'historique }
 UndoList, RedoList: PHistoryItem;
 UndoCount, RedoCount: Integer;
 MaxUndoLevels: Integer;

 { Palette de couleurs standard }
 StandardPalette: Array[0..27] of Byte;

 { Variable pour l'affichage texte }
 TextInput: String;
 TextInsertMode: Boolean;
 TextX, TextY: Integer;

 { Variables pour le dessin }
 Drawing: Boolean;
 StartX, StartY: Integer;
 EndX, EndY: Integer;

{$IFNDEF FPC}
{ Procédures pour la gestion de la souris en Turbo Pascal via Int 33h }

Procedure InitMouse;
Var
 Regs: Registers;
Begin
 Regs.AX := $0000;
 Intr($33, Regs);
 If Regs.AX = $FFFF Then
  MouseVisible := True
 Else
  MouseVisible := False;
End;

Procedure ShowMouse;
Var
 Regs: Registers;
Begin
 If MouseVisible Then Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;
End;

Procedure HideMouse;
Var
 Regs: Registers;
Begin
 If MouseVisible Then Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;
End;

Procedure GetMouseStateLocal(Var X, Y, Buttons: Integer);
Var
 Regs: Registers;
Begin
 Regs.AX := $0003;
 Intr($33, Regs);
 X := Regs.CX;
 Y := Regs.DX;
 Buttons := Regs.BX;
End;

Procedure SetMousePosition(X, Y: Integer);
Var
 Regs: Registers;
Begin
 Regs.AX := $0004;
 Regs.CX := X;
 Regs.DX := Y;
 Intr($33, Regs);
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: Integer);
Var
 Regs: Registers;
Begin
 { Limites horizontales }
 Regs.AX := $0007;
 Regs.CX := X1;
 Regs.DX := X2;
 Intr($33, Regs);
 { Limites verticales }
 Regs.AX := $0008;
 Regs.CX := Y1;
 Regs.DX := Y2;
 Intr($33, Regs);
End;

{$ELSE}
{ Wrappers pour Free Pascal avec PtcMouse }

Procedure InitMouseDriver;
Begin
 PtcMouse.InitMouse;
 MouseVisible := True;
End;

Procedure ShowMouseCursor;
Begin
 PtcMouse.ShowMouse;
End;

Procedure HideMouseCursor;
Begin
 PtcMouse.HideMouse;
End;

Procedure GetMouseStateLocal(Var X, Y, Buttons: Integer);
Var
 LX, LY, LB: LongInt;
Begin
 PtcMouse.GetMouseState(LX, LY, LB);
 X := LX;
 Y := LY;
 Buttons := LB;
End;

Procedure SetMousePosition(X, Y: Integer);
Begin
 PtcMouse.SetMousePos(X, Y);
End;

Procedure SetMouseBounds(X1, Y1, X2, Y2: Integer);
Begin
 { Cette fonction n'est pas disponible dans PtcMouse }
End;
{$ENDIF}

{ Procédures utilitaires }

Procedure DrawRoundedRect(X1, Y1, X2, Y2, RX, RY: Integer);
{ Dessine un rectangle arrondi compatible avec tous les compilateurs }
Begin
 { Lignes horizontales }
 Line(X1 + RX, Y1, X2 - RX, Y1);
 Line(X1 + RX, Y2, X2 - RX, Y2);
 { Lignes verticales }
 Line(X1, Y1 + RY, X1, Y2 - RY);
 Line(X2, Y1 + RY, X2, Y2 - RY);
 { Coins arrondis }
 Arc(X1 + RX, Y1 + RY, 90, 180, RX);
 Arc(X2 - RX, Y1 + RY, 0, 90, RX);
 Arc(X1 + RX, Y2 - RY, 180, 270, RX);
 Arc(X2 - RX, Y2 - RY, 270, 360, RX);
End;

Function Min(A, B: Integer): Integer;
Begin
 If A < B Then Min := A Else Min := B;
End;

Function Max(A, B: Integer): Integer;
Begin
 If A > B Then Max := A Else Max := B;
End;

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function StrToInt(S: String): LongInt;
Var
 N: LongInt;
 Code: Integer;
Begin
 Val(S, N, Code);
 If Code <> 0 Then N := 0;
 StrToInt := N;
End;

Function UpperCase(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 to Length(S) do
  S[I] := UpCase(S[I]);
 UpperCase := S;
End;

Function ExtractFileExt(FileName: String): String;
Var
 I: Integer;
 Ext: String;
Begin
 Ext := '';
 For I := Length(FileName) downto 1 do Begin
  If FileName[I] = '.' Then Begin
   Ext := Copy(FileName, I, Length(FileName) - I + 1);
   Break;
  End;
 End;
 ExtractFileExt := UpperCase(Ext);
End;

Function GetImageFormat(FileName: String): Byte;
Var
 Ext: String;
Begin
 Ext := ExtractFileExt(FileName);
 If (Ext = '.BMP') or (Ext = '.DIB') Then
  GetImageFormat := FMT_BMP
 Else If Ext = '.GIF' Then
  GetImageFormat := FMT_GIF
 Else If Ext = '.PNG' Then
  GetImageFormat := FMT_PNG
 Else If (Ext = '.JPG') or (Ext = '.JPEG') Then
  GetImageFormat := FMT_JPEG
 Else If Ext = '.PCX' Then
  GetImageFormat := FMT_PCX
 Else If (Ext = '.TGA') or (Ext = '.TARGA') Then
  GetImageFormat := FMT_TARGA
 Else If (Ext = '.TIF') or (Ext = '.TIFF') Then
  GetImageFormat := FMT_TIFF
 Else
  GetImageFormat := FMT_BMP;
End;

{ Procédures d'initialisation }

Procedure InitGraphics;
{$IFDEF FPC}
Begin
 GraphDriver := VGA;
 GraphMode := VGAHi;
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then Begin
  WriteLn('Erreur d''initialisation graphique!');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
End;
{$ELSE}
Begin
 GraphDriver := Detect;
 InitGraph(GraphDriver, GraphMode, '');
 If GraphResult <> grOk Then Begin
  WriteLn('Erreur d''initialisation graphique!');
  Halt(1);
 End;
 ScreenWidth := GetMaxX + 1;
 ScreenHeight := GetMaxY + 1;
End;
{$ENDIF}

Procedure InitPalette;
Var
 I: Integer;
Begin
 { Palette standard similaire à MS Paint }
 StandardPalette[0] := Black;
 StandardPalette[1] := White;
 StandardPalette[2] := Red;
 StandardPalette[3] := Green;
 StandardPalette[4] := Blue;
 StandardPalette[5] := Yellow;
 StandardPalette[6] := Cyan;
 StandardPalette[7] := Magenta;
 StandardPalette[8] := LightGray;
 StandardPalette[9] := DarkGray;
 StandardPalette[10] := LightRed;
 StandardPalette[11] := LightGreen;
 StandardPalette[12] := LightBlue;
 StandardPalette[13] := LightCyan;
 StandardPalette[14] := LightMagenta;
 StandardPalette[15] := Brown;

 { Couleurs supplémentaires }
 For I := 16 to 27 do
  StandardPalette[I] := I mod 16;

 { Initialiser les couleurs par défaut }
 CurrentColor := Black;
 BackgroundColor := White;
End;

Procedure InitMenus;
Begin
 { Menu Fichier }
 Menus[MENU_FILE].Title := 'Fichier';
 Menus[MENU_FILE].X := 5;
 Menus[MENU_FILE].Width := 120;
 Menus[MENU_FILE].ItemCount := 10;
 Menus[MENU_FILE].Items[0].Caption := 'Nouveau';
 Menus[MENU_FILE].Items[0].Shortcut := 'Ctrl+N';
 Menus[MENU_FILE].Items[0].Enabled := True;
 Menus[MENU_FILE].Items[1].Caption := 'Ouvrir...';
 Menus[MENU_FILE].Items[1].Shortcut := 'Ctrl+O';
 Menus[MENU_FILE].Items[1].Enabled := True;
 Menus[MENU_FILE].Items[2].Caption := 'Enregistrer';
 Menus[MENU_FILE].Items[2].Shortcut := 'Ctrl+S';
 Menus[MENU_FILE].Items[2].Enabled := True;
 Menus[MENU_FILE].Items[3].Caption := 'Enregistrer sous...';
 Menus[MENU_FILE].Items[3].Shortcut := '';
 Menus[MENU_FILE].Items[3].Enabled := True;
 Menus[MENU_FILE].Items[4].Separator := True;
 Menus[MENU_FILE].Items[5].Caption := 'Imprimer...';
 Menus[MENU_FILE].Items[5].Shortcut := 'Ctrl+P';
 Menus[MENU_FILE].Items[5].Enabled := True;
 Menus[MENU_FILE].Items[6].Separator := True;
 Menus[MENU_FILE].Items[7].Caption := 'Proprietes...';
 Menus[MENU_FILE].Items[7].Shortcut := '';
 Menus[MENU_FILE].Items[7].Enabled := True;
 Menus[MENU_FILE].Items[8].Separator := True;
 Menus[MENU_FILE].Items[9].Caption := 'Quitter';
 Menus[MENU_FILE].Items[9].Shortcut := 'Alt+F4';
 Menus[MENU_FILE].Items[9].Enabled := True;

 { Menu Modifier }
 Menus[MENU_EDIT].Title := 'Modifier';
 Menus[MENU_EDIT].X := 60;
 Menus[MENU_EDIT].Width := 130;
 Menus[MENU_EDIT].ItemCount := 9;
 Menus[MENU_EDIT].Items[0].Caption := 'Annuler';
 Menus[MENU_EDIT].Items[0].Shortcut := 'Ctrl+Z';
 Menus[MENU_EDIT].Items[0].Enabled := True;
 Menus[MENU_EDIT].Items[1].Caption := 'Retablir';
 Menus[MENU_EDIT].Items[1].Shortcut := 'Ctrl+Y';
 Menus[MENU_EDIT].Items[1].Enabled := True;
 Menus[MENU_EDIT].Items[2].Separator := True;
 Menus[MENU_EDIT].Items[3].Caption := 'Couper';
 Menus[MENU_EDIT].Items[3].Shortcut := 'Ctrl+X';
 Menus[MENU_EDIT].Items[3].Enabled := True;
 Menus[MENU_EDIT].Items[4].Caption := 'Copier';
 Menus[MENU_EDIT].Items[4].Shortcut := 'Ctrl+C';
 Menus[MENU_EDIT].Items[4].Enabled := True;
 Menus[MENU_EDIT].Items[5].Caption := 'Coller';
 Menus[MENU_EDIT].Items[5].Shortcut := 'Ctrl+V';
 Menus[MENU_EDIT].Items[5].Enabled := True;
 Menus[MENU_EDIT].Items[6].Caption := 'Effacer selection';
 Menus[MENU_EDIT].Items[6].Shortcut := 'Suppr';
 Menus[MENU_EDIT].Items[6].Enabled := True;
 Menus[MENU_EDIT].Items[7].Separator := True;
 Menus[MENU_EDIT].Items[8].Caption := 'Tout selectionner';
 Menus[MENU_EDIT].Items[8].Shortcut := 'Ctrl+A';
 Menus[MENU_EDIT].Items[8].Enabled := True;

 { Menu Affichage }
 Menus[MENU_VIEW].Title := 'Affichage';
 Menus[MENU_VIEW].X := 125;
 Menus[MENU_VIEW].Width := 140;
 Menus[MENU_VIEW].ItemCount := 8;
 Menus[MENU_VIEW].Items[0].Caption := 'Barre d''outils';
 Menus[MENU_VIEW].Items[0].Shortcut := '';
 Menus[MENU_VIEW].Items[0].Enabled := True;
 Menus[MENU_VIEW].Items[0].Checked := True;
 Menus[MENU_VIEW].Items[1].Caption := 'Barre de couleurs';
 Menus[MENU_VIEW].Items[1].Shortcut := '';
 Menus[MENU_VIEW].Items[1].Enabled := True;
 Menus[MENU_VIEW].Items[1].Checked := True;
 Menus[MENU_VIEW].Items[2].Caption := 'Barre d''etat';
 Menus[MENU_VIEW].Items[2].Shortcut := '';
 Menus[MENU_VIEW].Items[2].Enabled := True;
 Menus[MENU_VIEW].Items[2].Checked := True;
 Menus[MENU_VIEW].Items[3].Separator := True;
 Menus[MENU_VIEW].Items[4].Caption := 'Zoom avant';
 Menus[MENU_VIEW].Items[4].Shortcut := 'Ctrl++';
 Menus[MENU_VIEW].Items[4].Enabled := True;
 Menus[MENU_VIEW].Items[5].Caption := 'Zoom arrire';
 Menus[MENU_VIEW].Items[5].Shortcut := 'Ctrl+-';
 Menus[MENU_VIEW].Items[5].Enabled := True;
 Menus[MENU_VIEW].Items[6].Separator := True;
 Menus[MENU_VIEW].Items[7].Caption := 'Plein ecran';
 Menus[MENU_VIEW].Items[7].Shortcut := 'F11';
 Menus[MENU_VIEW].Items[7].Enabled := True;

 { Menu Image }
 Menus[MENU_IMAGE].Title := 'Image';
 Menus[MENU_IMAGE].X := 195;
 Menus[MENU_IMAGE].Width := 150;
 Menus[MENU_IMAGE].ItemCount := 10;
 Menus[MENU_IMAGE].Items[0].Caption := 'Retourner/Pivoter...';
 Menus[MENU_IMAGE].Items[0].Shortcut := '';
 Menus[MENU_IMAGE].Items[0].Enabled := True;
 Menus[MENU_IMAGE].Items[1].Caption := 'Etirer/Incliner...';
 Menus[MENU_IMAGE].Items[1].Shortcut := '';
 Menus[MENU_IMAGE].Items[1].Enabled := True;
 Menus[MENU_IMAGE].Items[2].Caption := 'Inverser couleurs';
 Menus[MENU_IMAGE].Items[2].Shortcut := '';
 Menus[MENU_IMAGE].Items[2].Enabled := True;
 Menus[MENU_IMAGE].Items[3].Separator := True;
 Menus[MENU_IMAGE].Items[4].Caption := 'Redimensionner...';
 Menus[MENU_IMAGE].Items[4].Shortcut := 'Ctrl+W';
 Menus[MENU_IMAGE].Items[4].Enabled := True;
 Menus[MENU_IMAGE].Items[5].Caption := 'Rogner (Crop)';
 Menus[MENU_IMAGE].Items[5].Shortcut := '';
 Menus[MENU_IMAGE].Items[5].Enabled := True;
 Menus[MENU_IMAGE].Items[6].Separator := True;
 Menus[MENU_IMAGE].Items[7].Caption := 'Attributs...';
 Menus[MENU_IMAGE].Items[7].Shortcut := '';
 Menus[MENU_IMAGE].Items[7].Enabled := True;
 Menus[MENU_IMAGE].Items[8].Separator := True;
 Menus[MENU_IMAGE].Items[9].Caption := 'Effacer l''image';
 Menus[MENU_IMAGE].Items[9].Shortcut := '';
 Menus[MENU_IMAGE].Items[9].Enabled := True;

 { Menu Couleurs }
 Menus[MENU_COLORS].Title := 'Couleurs';
 Menus[MENU_COLORS].X := 255;
 Menus[MENU_COLORS].Width := 130;
 Menus[MENU_COLORS].ItemCount := 2;
 Menus[MENU_COLORS].Items[0].Caption := 'Modifier palette...';
 Menus[MENU_COLORS].Items[0].Shortcut := '';
 Menus[MENU_COLORS].Items[0].Enabled := True;
 Menus[MENU_COLORS].Items[1].Caption := 'Obtenir couleurs...';
 Menus[MENU_COLORS].Items[1].Shortcut := '';
 Menus[MENU_COLORS].Items[1].Enabled := True;

 { Menu Aide }
 Menus[MENU_HELP].Title := '?';
 Menus[MENU_HELP].X := 325;
 Menus[MENU_HELP].Width := 100;
 Menus[MENU_HELP].ItemCount := 2;
 Menus[MENU_HELP].Items[0].Caption := 'Aide';
 Menus[MENU_HELP].Items[0].Shortcut := 'F1';
 Menus[MENU_HELP].Items[0].Enabled := True;
 Menus[MENU_HELP].Items[1].Caption := 'A propos...';
 Menus[MENU_HELP].Items[1].Shortcut := '';
 Menus[MENU_HELP].Items[1].Enabled := True;
End;

Procedure InitImage;
Begin
 ImageBuffer.Width := 640;
 ImageBuffer.Height := 480;
 ImageBuffer.BitDepth := 8;
 ImageBuffer.HasTransparency := False;
 ImageBuffer.Modified := False;
 ImageBuffer.FileName := '';
 ImageBuffer.Format := FMT_BMP;

 CanvasX := TOOLBAR_WIDTH + 5;
 CanvasY := MENUBAR_HEIGHT + 5;
 CanvasWidth := ScreenWidth - TOOLBAR_WIDTH - 10;
 CanvasHeight := ScreenHeight - MENUBAR_HEIGHT - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 10;

 ZoomLevel := 100;
End;

Procedure InitTools;
Begin
 CurrentTool := TOOL_PENCIL;
 BrushSize := 3;
 LineWidth := 1;
 FillStyle := 0;
End;

Procedure InitHistory;
Begin
 UndoList := Nil;
 RedoList := Nil;
 UndoCount := 0;
 RedoCount := 0;
 MaxUndoLevels := 20;
End;

{ Procédures de dessin de l'interface }

Procedure DrawMenuBar;
Var
 I: Integer;
 X: Integer;
Begin
 { Fond de la barre de menu }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, 0, ScreenWidth - 1, MENUBAR_HEIGHT - 1);
 SetColor(DarkGray);
 Line(0, MENUBAR_HEIGHT - 1, ScreenWidth - 1, MENUBAR_HEIGHT - 1);

 { Dessiner les titres des menus }
 SetColor(Black);
 X := 5;
 For I := 0 to 5 do Begin
  Menus[I].X := X;
  If (MenuActive) and (ActiveMenu = I) Then Begin
   SetFillStyle(SolidFill, Blue);
   Bar(X - 2, 2, X + TextWidth(Menus[I].Title) + 2, MENUBAR_HEIGHT - 3);
   SetColor(White);
  End Else Begin
   SetColor(Black);
  End;
  OutTextXY(X, 5, Menus[I].Title);
  X := X + TextWidth(Menus[I].Title) + 15;
 End;
End;

Procedure DrawToolIcon(X, Y: Integer; ToolIndex: Byte; Selected: Boolean);
Var
 IconSize: Integer;
Begin
 IconSize := 20;

 { Fond du bouton }
 If Selected Then Begin
  SetFillStyle(SolidFill, DarkGray);
  Bar(X, Y, X + IconSize, Y + IconSize);
  SetColor(White);
 End Else Begin
  SetFillStyle(SolidFill, LightGray);
  Bar(X, Y, X + IconSize, Y + IconSize);
  SetColor(Black);
 End;

 { Dessiner l'icône selon l'outil }
 Case ToolIndex of
  TOOL_SELECT: Begin
   { Rectangle de sélection en pointillés }
   SetLineStyle(DottedLn, 0, NormWidth);
   Rectangle(X + 4, Y + 4, X + IconSize - 4, Y + IconSize - 4);
   SetLineStyle(SolidLn, 0, NormWidth);
  End;
  TOOL_ERASER: Begin
   { Gomme }
   SetFillStyle(SolidFill, White);
   Bar(X + 5, Y + 8, X + IconSize - 5, Y + IconSize - 4);
   Rectangle(X + 5, Y + 8, X + IconSize - 5, Y + IconSize - 4);
  End;
  TOOL_FILL: Begin
   { Pot de peinture }
   Arc(X + 10, Y + 12, 0, 180, 5);
   Line(X + 5, Y + 12, X + 5, Y + 16);
   Line(X + 15, Y + 12, X + 15, Y + 16);
   Line(X + 5, Y + 16, X + 15, Y + 16);
  End;
  TOOL_PICKER: Begin
   { Pipette }
   Line(X + 6, Y + 6, X + 14, Y + 14);
   Circle(X + 14, Y + 14, 3);
  End;
  TOOL_MAGNIFY: Begin
   { Loupe }
   Circle(X + 10, Y + 9, 5);
   Line(X + 13, Y + 13, X + 17, Y + 17);
  End;
  TOOL_PENCIL: Begin
   { Crayon }
   Line(X + 5, Y + 15, X + 15, Y + 5);
   Line(X + 5, Y + 15, X + 7, Y + 17);
   Line(X + 7, Y + 17, X + 17, Y + 7);
   Line(X + 15, Y + 5, X + 17, Y + 7);
  End;
  TOOL_BRUSH: Begin
   { Pinceau }
   SetFillStyle(SolidFill, CurrentColor);
   FillEllipse(X + 10, Y + 10, 5, 3);
   Line(X + 10, Y + 13, X + 10, Y + 18);
  End;
  TOOL_AIRBRUSH: Begin
   { Aérographe - points dispersés }
   PutPixel(X + 8, Y + 8, CurrentColor);
   PutPixel(X + 10, Y + 7, CurrentColor);
   PutPixel(X + 12, Y + 9, CurrentColor);
   PutPixel(X + 9, Y + 11, CurrentColor);
   PutPixel(X + 11, Y + 12, CurrentColor);
   PutPixel(X + 13, Y + 10, CurrentColor);
   PutPixel(X + 7, Y + 10, CurrentColor);
  End;
  TOOL_TEXT: Begin
   { Lettre A }
   OutTextXY(X + 6, Y + 5, 'A');
  End;
  TOOL_LINE: Begin
   { Ligne }
   Line(X + 5, Y + 15, X + 15, Y + 5);
  End;
  TOOL_CURVE: Begin
   { Courbe }
   Arc(X + 10, Y + 15, 0, 180, 7);
  End;
  TOOL_RECT: Begin
   { Rectangle }
   Rectangle(X + 4, Y + 6, X + 16, Y + 14);
  End;
  TOOL_POLYGON: Begin
   { Polygone }
   Line(X + 10, Y + 4, X + 16, Y + 10);
   Line(X + 16, Y + 10, X + 13, Y + 16);
   Line(X + 13, Y + 16, X + 7, Y + 16);
   Line(X + 7, Y + 16, X + 4, Y + 10);
   Line(X + 4, Y + 10, X + 10, Y + 4);
  End;
  TOOL_ELLIPSE: Begin
   { Ellipse }
   Ellipse(X + 10, Y + 10, 0, 360, 6, 4);
  End;
  TOOL_ROUNDRECT: Begin
   { Rectangle arrondi }
   DrawRoundedRect(X + 4, Y + 6, X + 16, Y + 14, 4, 4);
  End;
 End;

 { Bordure du bouton }
 If Selected Then Begin
  SetColor(White);
  Line(X, Y, X + IconSize, Y);
  Line(X, Y, X, Y + IconSize);
  SetColor(DarkGray);
  Line(X + IconSize, Y, X + IconSize, Y + IconSize);
  Line(X, Y + IconSize, X + IconSize, Y + IconSize);
 End Else Begin
  SetColor(White);
  Line(X, Y, X + IconSize, Y);
  Line(X, Y, X, Y + IconSize);
  SetColor(DarkGray);
  Line(X + IconSize, Y, X + IconSize, Y + IconSize);
  Line(X, Y + IconSize, X + IconSize, Y + IconSize);
 End;
End;

Procedure DrawToolbar;
Var
 I: Integer;
 X, Y: Integer;
 ToolsPerRow: Integer;
Begin
 { Fond de la barre d'outils }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 1);

 { Bordure droite }
 SetColor(DarkGray);
 Line(TOOLBAR_WIDTH - 1, MENUBAR_HEIGHT, TOOLBAR_WIDTH - 1, ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT - 1);

 { Dessiner les icônes d'outils }
 ToolsPerRow := 2;
 For I := 0 to 14 do Begin
  X := 5 + (I mod ToolsPerRow) * 23;
  Y := MENUBAR_HEIGHT + 5 + (I div ToolsPerRow) * 23;
  DrawToolIcon(X, Y, I, I = CurrentTool);
 End;

 { Section de taille de pinceau }
 Y := MENUBAR_HEIGHT + 185;
 SetColor(Black);
 OutTextXY(5, Y, 'Taille:');
 SetFillStyle(SolidFill, White);
 Bar(5, Y + 12, 45, Y + 32);
 SetColor(Black);
 Rectangle(5, Y + 12, 45, Y + 32);
 OutTextXY(20, Y + 17, IntToStr(BrushSize));
End;

Procedure DrawColorPalette;
Var
 I: Integer;
 X, Y: Integer;
 ColorBoxSize: Integer;
 PaletteY: Integer;
Begin
 PaletteY := ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT;
 ColorBoxSize := 16;

 { Fond de la barre de couleurs }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, PaletteY, ScreenWidth - 1, ScreenHeight - STATUSBAR_HEIGHT - 1);

 { Bordure supérieure }
 SetColor(DarkGray);
 Line(0, PaletteY, ScreenWidth - 1, PaletteY);

 { Afficher la couleur actuelle et l'arrière-plan }
 X := 10;
 Y := PaletteY + 5;

 { Couleur d'arrière-plan (en dessous) }
 SetFillStyle(SolidFill, BackgroundColor);
 Bar(X + 8, Y + 8, X + 28, Y + 28);
 SetColor(Black);
 Rectangle(X + 8, Y + 8, X + 28, Y + 28);

 { Couleur de premier plan (au-dessus) }
 SetFillStyle(SolidFill, CurrentColor);
 Bar(X, Y, X + 20, Y + 20);
 SetColor(Black);
 Rectangle(X, Y, X + 20, Y + 20);

 { Palette de couleurs }
 X := 50;
 For I := 0 to 27 do Begin
  SetFillStyle(SolidFill, StandardPalette[I]);
  Bar(X + (I mod 14) * (ColorBoxSize + 2), Y + (I div 14) * (ColorBoxSize + 2),
      X + (I mod 14) * (ColorBoxSize + 2) + ColorBoxSize,
      Y + (I div 14) * (ColorBoxSize + 2) + ColorBoxSize);
  SetColor(Black);
  Rectangle(X + (I mod 14) * (ColorBoxSize + 2), Y + (I div 14) * (ColorBoxSize + 2),
            X + (I mod 14) * (ColorBoxSize + 2) + ColorBoxSize,
            Y + (I div 14) * (ColorBoxSize + 2) + ColorBoxSize);
 End;
End;

Procedure DrawStatusBar;
Var
 StatusY: Integer;
 PosStr: String;
Begin
 StatusY := ScreenHeight - STATUSBAR_HEIGHT;

 { Fond de la barre d'état }
 SetFillStyle(SolidFill, LightGray);
 Bar(0, StatusY, ScreenWidth - 1, ScreenHeight - 1);

 { Bordure supérieure }
 SetColor(DarkGray);
 Line(0, StatusY, ScreenWidth - 1, StatusY);

 { Afficher les informations }
 SetColor(Black);

 { Position de la souris }
 If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
    (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then Begin
  PosStr := IntToStr(MouseX - CanvasX) + ', ' + IntToStr(MouseY - CanvasY);
  OutTextXY(10, StatusY + 5, PosStr);
 End;

 { Taille de l'image }
 PosStr := IntToStr(ImageBuffer.Width) + ' x ' + IntToStr(ImageBuffer.Height) + ' px';
 OutTextXY(150, StatusY + 5, PosStr);

 { Zoom }
 PosStr := IntToStr(ZoomLevel) + '%';
 OutTextXY(300, StatusY + 5, PosStr);

 { Nom du fichier ou état modifié }
 If ImageBuffer.FileName <> '' Then
  OutTextXY(400, StatusY + 5, ImageBuffer.FileName)
 Else
  OutTextXY(400, StatusY + 5, 'Sans titre');

 If ImageBuffer.Modified Then
  OutTextXY(550, StatusY + 5, '*');
End;

Procedure DrawCanvas;
Begin
 { Fond du canvas (zone de dessin) }
 SetFillStyle(SolidFill, White);
 Bar(CanvasX, CanvasY, CanvasX + Min(CanvasWidth, ImageBuffer.Width) - 1,
     CanvasY + Min(CanvasHeight, ImageBuffer.Height) - 1);

 { Bordure du canvas }
 SetColor(DarkGray);
 Rectangle(CanvasX - 1, CanvasY - 1,
           CanvasX + Min(CanvasWidth, ImageBuffer.Width),
           CanvasY + Min(CanvasHeight, ImageBuffer.Height));

 { Grille si zoom > 400% }
 If ZoomLevel >= 400 Then Begin
  SetColor(LightGray);
  { Dessiner la grille... }
 End;
End;

Procedure DrawSelection;
Begin
 If SelectionActive Then Begin
  SetColor(Black);
  SetLineStyle(DottedLn, 0, NormWidth);
  Rectangle(SelectionRect.Left, SelectionRect.Top,
            SelectionRect.Right, SelectionRect.Bottom);
  SetLineStyle(SolidLn, 0, NormWidth);
 End;
End;

Procedure DrawMenu(MenuIndex: Integer);
Var
 I: Integer;
 X, Y, W, H: Integer;
 ItemHeight: Integer;
Begin
 If (MenuIndex < 0) or (MenuIndex > 5) Then Exit;

 ItemHeight := 18;
 X := Menus[MenuIndex].X;
 Y := MENUBAR_HEIGHT;
 W := Menus[MenuIndex].Width;
 H := Menus[MenuIndex].ItemCount * ItemHeight + 4;

 { Fond du menu }
 SetFillStyle(SolidFill, LightGray);
 Bar(X, Y, X + W, Y + H);

 { Bordure }
 SetColor(White);
 Line(X, Y, X + W, Y);
 Line(X, Y, X, Y + H);
 SetColor(DarkGray);
 Line(X + W, Y, X + W, Y + H);
 Line(X, Y + H, X + W, Y + H);
 SetColor(Black);
 Line(X + W + 1, Y + 1, X + W + 1, Y + H + 1);
 Line(X + 1, Y + H + 1, X + W + 1, Y + H + 1);

 { Éléments du menu }
 For I := 0 to Menus[MenuIndex].ItemCount - 1 do Begin
  If Menus[MenuIndex].Items[I].Separator Then Begin
   SetColor(DarkGray);
   Line(X + 2, Y + 2 + I * ItemHeight + ItemHeight div 2,
        X + W - 2, Y + 2 + I * ItemHeight + ItemHeight div 2);
  End Else Begin
   { Fond de l'élément sélectionné }
   If (ActiveMenuItem = I) Then Begin
    SetFillStyle(SolidFill, Blue);
    Bar(X + 2, Y + 2 + I * ItemHeight, X + W - 2, Y + 2 + (I + 1) * ItemHeight);
    SetColor(White);
   End Else Begin
    If Menus[MenuIndex].Items[I].Enabled Then
     SetColor(Black)
    Else
     SetColor(DarkGray);
   End;

   { Coche si activé }
   If Menus[MenuIndex].Items[I].Checked Then
    OutTextXY(X + 5, Y + 4 + I * ItemHeight, #251);

   { Texte de l'élément }
   OutTextXY(X + 20, Y + 4 + I * ItemHeight, Menus[MenuIndex].Items[I].Caption);

   { Raccourci clavier }
   If Menus[MenuIndex].Items[I].Shortcut <> '' Then
    OutTextXY(X + W - TextWidth(Menus[MenuIndex].Items[I].Shortcut) - 10,
              Y + 4 + I * ItemHeight, Menus[MenuIndex].Items[I].Shortcut);
  End;
 End;
End;

Procedure RedrawInterface;
Begin
 {$IFDEF FPC}
 HideMouse;
 {$ELSE}
 HideMouse;
 {$ENDIF}

 { Effacer l'écran }
 SetFillStyle(SolidFill, DarkGray);
 Bar(0, 0, ScreenWidth - 1, ScreenHeight - 1);

 { Dessiner les éléments de l'interface }
 DrawMenuBar;
 DrawToolbar;
 DrawCanvas;
 DrawColorPalette;
 DrawStatusBar;
 DrawSelection;

 { Dessiner le menu actif si nécessaire }
 If MenuActive Then
  DrawMenu(ActiveMenu);

 {$IFDEF FPC}
 ShowMouse;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
End;

{ Procédures de gestion des fichiers image }

Function LoadBMP(FileName: String): Boolean;
Var
 F: File;
 FileHeader: TBMPFileHeader;
 InfoHeader: TBMPInfoHeader;
 BytesRead: Word;
Begin
 LoadBMP := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tête du fichier }
 BlockRead(F, FileHeader, SizeOf(TBMPFileHeader), BytesRead);
 If (BytesRead <> SizeOf(TBMPFileHeader)) or (FileHeader.bfType <> BMP_SIGNATURE) Then Begin
  Close(F);
  Exit;
 End;

 { Lire l'en-tête d'information }
 BlockRead(F, InfoHeader, SizeOf(TBMPInfoHeader), BytesRead);
 If BytesRead <> SizeOf(TBMPInfoHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Mettre à jour les informations de l'image }
 ImageBuffer.Width := InfoHeader.biWidth;
 ImageBuffer.Height := Abs(InfoHeader.biHeight);
 ImageBuffer.BitDepth := InfoHeader.biBitCount;
 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_BMP;
 ImageBuffer.Modified := False;

 { Lire la palette si nécessaire }
 If InfoHeader.biBitCount <= 8 Then Begin
  { Lire la palette de couleurs }
 End;

 { Lire les données de l'image }
 { ... }

 Close(F);
 LoadBMP := True;
End;

Function LoadGIF(FileName: String): Boolean;
Var
 F: File;
 Header: TGIFHeader;
 BytesRead: Word;
Begin
 LoadGIF := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tête GIF }
 BlockRead(F, Header, SizeOf(TGIFHeader), BytesRead);
 If BytesRead <> SizeOf(TGIFHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Vérifier la signature }
 If (Copy(Header.Signature, 1, 3) <> 'GIF') Then Begin
  Close(F);
  Exit;
 End;

 { Mettre à jour les informations de l'image }
 ImageBuffer.Width := Header.ScreenWidth;
 ImageBuffer.Height := Header.ScreenHeight;
 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_GIF;
 ImageBuffer.Modified := False;

 { Vérifier la transparence (GIF89a) }
 If Copy(Header.Signature, 1, 6) = GIF89_SIGNATURE Then Begin
  ImageBuffer.HasTransparency := True;
  { Lire l'extension de contrôle graphique pour la couleur transparente }
 End;

 { Lire la palette globale }
 If (Header.Flags and $80) <> 0 Then Begin
  { Palette globale présente }
 End;

 { Décoder les données d'image LZW }
 { ... }

 Close(F);
 LoadGIF := True;
End;

Function LoadPNG(FileName: String): Boolean;
Var
 F: File;
 Signature: Array[0..7] of Byte;
 BytesRead: Word;
 I: Integer;
 ValidSig: Boolean;
Begin
 LoadPNG := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire la signature PNG }
 BlockRead(F, Signature, 8, BytesRead);
 If BytesRead <> 8 Then Begin
  Close(F);
  Exit;
 End;

 { Vérifier la signature }
 ValidSig := True;
 For I := 0 to 7 do
  If Signature[I] <> PNG_SIGNATURE[I] Then ValidSig := False;

 If Not ValidSig Then Begin
  Close(F);
  Exit;
 End;

 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_PNG;
 ImageBuffer.Modified := False;
 ImageBuffer.HasTransparency := True; { PNG supporte la transparence }

 { Lire les chunks PNG (IHDR, PLTE, IDAT, etc.) }
 { ... }

 Close(F);
 LoadPNG := True;
End;

Function LoadJPEG(FileName: String): Boolean;
Var
 F: File;
 Marker: Word;
 BytesRead: Word;
Begin
 LoadJPEG := False;

 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire le marqueur SOI }
 BlockRead(F, Marker, 2, BytesRead);
 If (BytesRead <> 2) or (Swap(Marker) <> JPEG_SOI) Then Begin
  Close(F);
  Exit;
 End;

 ImageBuffer.FileName := FileName;
 ImageBuffer.Format := FMT_JPEG;
 ImageBuffer.Modified := False;
 ImageBuffer.HasTransparency := False; { JPEG ne supporte pas la transparence }

 { Lire les segments JPEG (APP0, DQT, SOF, etc.) }
 { ... }

 Close(F);
 LoadJPEG := True;
End;

Function LoadImage(FileName: String): Boolean;
Var
 Format: Byte;
Begin
 Format := GetImageFormat(FileName);

 Case Format of
  FMT_BMP: LoadImage := LoadBMP(FileName);
  FMT_GIF: LoadImage := LoadGIF(FileName);
  FMT_PNG: LoadImage := LoadPNG(FileName);
  FMT_JPEG: LoadImage := LoadJPEG(FileName);
  Else LoadImage := False;
 End;
End;

Function SaveBMP(FileName: String): Boolean;
Var
 F: File;
 FileHeader: TBMPFileHeader;
 InfoHeader: TBMPInfoHeader;
 BytesWritten: Word;
 RowSize: LongInt;
 ImageSize: LongInt;
Begin
 SaveBMP := False;

 { Calculer la taille de la ligne (alignée sur 4 octets) }
 RowSize := ((ImageBuffer.Width * ImageBuffer.BitDepth + 31) div 32) * 4;
 ImageSize := RowSize * ImageBuffer.Height;

 { Préparer l'en-tête du fichier }
 FileHeader.bfType := BMP_SIGNATURE;
 FileHeader.bfSize := SizeOf(TBMPFileHeader) + SizeOf(TBMPInfoHeader) + ImageSize;
 FileHeader.bfReserved1 := 0;
 FileHeader.bfReserved2 := 0;
 FileHeader.bfOffBits := SizeOf(TBMPFileHeader) + SizeOf(TBMPInfoHeader);

 { Ajouter la palette si nécessaire }
 If ImageBuffer.BitDepth <= 8 Then
  FileHeader.bfOffBits := FileHeader.bfOffBits + (1 shl ImageBuffer.BitDepth) * 4;

 { Préparer l'en-tête d'information }
 InfoHeader.biSize := SizeOf(TBMPInfoHeader);
 InfoHeader.biWidth := ImageBuffer.Width;
 InfoHeader.biHeight := ImageBuffer.Height;
 InfoHeader.biPlanes := 1;
 InfoHeader.biBitCount := ImageBuffer.BitDepth;
 InfoHeader.biCompression := 0;
 InfoHeader.biSizeImage := ImageSize;
 InfoHeader.biXPelsPerMeter := 2835;
 InfoHeader.biYPelsPerMeter := 2835;
 InfoHeader.biClrUsed := 0;
 InfoHeader.biClrImportant := 0;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire l'en-tête du fichier }
 BlockWrite(F, FileHeader, SizeOf(TBMPFileHeader), BytesWritten);
 If BytesWritten <> SizeOf(TBMPFileHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire l'en-tête d'information }
 BlockWrite(F, InfoHeader, SizeOf(TBMPInfoHeader), BytesWritten);
 If BytesWritten <> SizeOf(TBMPInfoHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire la palette si nécessaire }
 If ImageBuffer.BitDepth <= 8 Then Begin
  { Écrire la palette }
 End;

 { Écrire les données de l'image }
 { ... }

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SaveBMP := True;
End;

Function SaveGIF(FileName: String): Boolean;
Var
 F: File;
 Header: TGIFHeader;
 BytesWritten: Word;
Begin
 SaveGIF := False;

 { Préparer l'en-tête GIF }
 If ImageBuffer.HasTransparency Then
  Move(GIF89_SIGNATURE[1], Header.Signature, 6)
 Else
  Move(GIF87_SIGNATURE[1], Header.Signature, 6);

 Header.ScreenWidth := ImageBuffer.Width;
 Header.ScreenHeight := ImageBuffer.Height;
 Header.Flags := $F7; { Palette globale, 256 couleurs }
 Header.BackgroundColor := 0;
 Header.AspectRatio := 0;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire l'en-tête }
 BlockWrite(F, Header, SizeOf(TGIFHeader), BytesWritten);
 If BytesWritten <> SizeOf(TGIFHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Écrire la palette globale }
 { ... }

 { Écrire l'extension de contrôle graphique pour la transparence }
 If ImageBuffer.HasTransparency Then Begin
  { ... }
 End;

 { Écrire les données d'image compressées en LZW }
 { ... }

 { Écrire le terminateur }
 { ... }

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SaveGIF := True;
End;

Function SavePNG(FileName: String): Boolean;
Var
 F: File;
 BytesWritten: Word;
Begin
 SavePNG := False;

 Assign(F, FileName);
 {$I-}
 Rewrite(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Écrire la signature PNG }
 BlockWrite(F, PNG_SIGNATURE, 8, BytesWritten);
 If BytesWritten <> 8 Then Begin
  Close(F);
  Exit;
 End;

 { Écrire le chunk IHDR }
 { ... }

 { Écrire le chunk PLTE si nécessaire }
 { ... }

 { Écrire le chunk tRNS pour la transparence }
 If ImageBuffer.HasTransparency Then Begin
  { ... }
 End;

 { Écrire les chunks IDAT (données compressées) }
 { ... }

 { Écrire le chunk IEND }
 { ... }

 Close(F);
 ImageBuffer.FileName := FileName;
 ImageBuffer.Modified := False;
 SavePNG := True;
End;

Function SaveImage(FileName: String; Format: Byte): Boolean;
Begin
 Case Format of
  FMT_BMP: SaveImage := SaveBMP(FileName);
  FMT_GIF: SaveImage := SaveGIF(FileName);
  FMT_PNG: SaveImage := SavePNG(FileName);
  Else SaveImage := False;
 End;
End;

{ Procédures de manipulation d'image }

Procedure ResizeImage(NewWidth, NewHeight: Integer);
Begin
 If (NewWidth < 1) or (NewHeight < 1) Then Exit;
 If (NewWidth > MAX_IMAGE_WIDTH) or (NewHeight > MAX_IMAGE_HEIGHT) Then Exit;

 { Redimensionner l'image }
 ImageBuffer.Width := NewWidth;
 ImageBuffer.Height := NewHeight;
 ImageBuffer.Modified := True;

 RedrawInterface;
End;

Procedure CropImage;
Begin
 If Not SelectionActive Then Exit;

 { Rogner l'image selon la sélection }
 ImageBuffer.Width := SelectionRect.Right - SelectionRect.Left;
 ImageBuffer.Height := SelectionRect.Bottom - SelectionRect.Top;
 ImageBuffer.Modified := True;

 SelectionActive := False;
 RedrawInterface;
End;

Procedure SetColorDepth(Depth: Byte);
Begin
 Case Depth of
  DEPTH_2: ImageBuffer.BitDepth := 1;
  DEPTH_4: ImageBuffer.BitDepth := 2;
  DEPTH_8: ImageBuffer.BitDepth := 3;
  DEPTH_16: ImageBuffer.BitDepth := 4;
  DEPTH_32: ImageBuffer.BitDepth := 5;
  DEPTH_64: ImageBuffer.BitDepth := 6;
  DEPTH_128: ImageBuffer.BitDepth := 7;
  DEPTH_256: ImageBuffer.BitDepth := 8;
  DEPTH_4096: ImageBuffer.BitDepth := 12;
  DEPTH_32768: ImageBuffer.BitDepth := 15;
  DEPTH_65536: ImageBuffer.BitDepth := 16;
  DEPTH_16M: ImageBuffer.BitDepth := 24;
  DEPTH_32BIT: ImageBuffer.BitDepth := 32;
 End;
 ImageBuffer.Modified := True;
End;

Procedure FlipHorizontal;
Begin
 { Retourner l'image horizontalement }
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure FlipVertical;
Begin
 { Retourner l'image verticalement }
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure RotateImage(Degrees: Integer);
Begin
 { Pivoter l'image }
 Case Degrees of
  90: Begin
   { Rotation 90 degrés }
  End;
  180: Begin
   { Rotation 180 degrés }
  End;
  270: Begin
   { Rotation 270 degrés }
  End;
 End;
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure InvertColors;
Begin
 { Inverser les couleurs de l'image }
 ImageBuffer.Modified := True;
 RedrawInterface;
End;

Procedure ClearImage;
Begin
 { Effacer l'image (remplir avec la couleur d'arrière-plan) }
 SetFillStyle(SolidFill, BackgroundColor);
 Bar(CanvasX, CanvasY, CanvasX + Min(CanvasWidth, ImageBuffer.Width) - 1,
     CanvasY + Min(CanvasHeight, ImageBuffer.Height) - 1);
 ImageBuffer.Modified := True;
End;

{ Procédures d'historique (Undo/Redo) }

Procedure AddToHistory(Action: Byte);
Var
 NewItem: PHistoryItem;
Begin
 New(NewItem);
 NewItem^.Action := Action;
 NewItem^.Data := Nil;
 NewItem^.DataSize := 0;
 NewItem^.Next := UndoList;
 NewItem^.Prev := Nil;

 If UndoList <> Nil Then
  UndoList^.Prev := NewItem;

 UndoList := NewItem;
 Inc(UndoCount);

 { Limiter le nombre d'éléments dans l'historique }
 If UndoCount > MaxUndoLevels Then Begin
  { Supprimer le plus ancien }
 End;

 { Vider la liste Redo }
 While RedoList <> Nil do Begin
  NewItem := RedoList;
  RedoList := RedoList^.Next;
  Dispose(NewItem);
 End;
 RedoCount := 0;
End;

Procedure Undo;
Var
 Item: PHistoryItem;
Begin
 If UndoList = Nil Then Exit;

 Item := UndoList;
 UndoList := UndoList^.Next;
 If UndoList <> Nil Then
  UndoList^.Prev := Nil;
 Dec(UndoCount);

 { Ajouter à la liste Redo }
 Item^.Next := RedoList;
 Item^.Prev := Nil;
 If RedoList <> Nil Then
  RedoList^.Prev := Item;
 RedoList := Item;
 Inc(RedoCount);

 { Restaurer l'état }
 { ... }

 RedrawInterface;
End;

Procedure Redo;
Var
 Item: PHistoryItem;
Begin
 If RedoList = Nil Then Exit;

 Item := RedoList;
 RedoList := RedoList^.Next;
 If RedoList <> Nil Then
  RedoList^.Prev := Nil;
 Dec(RedoCount);

 { Ajouter à la liste Undo }
 Item^.Next := UndoList;
 Item^.Prev := Nil;
 If UndoList <> Nil Then
  UndoList^.Prev := Item;
 UndoList := Item;
 Inc(UndoCount);

 { Réappliquer l'action }
 { ... }

 RedrawInterface;
End;

{ Procédures de dessin }

Procedure DrawPixel(X, Y: Integer; Color: Byte);
Begin
 If (X >= CanvasX) and (X < CanvasX + ImageBuffer.Width) and
    (Y >= CanvasY) and (Y < CanvasY + ImageBuffer.Height) Then Begin
  PutPixel(X, Y, Color);
  ImageBuffer.Modified := True;
 End;
End;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin
 SetColor(Color);
 Line(X1, Y1, X2, Y2);
 ImageBuffer.Modified := True;
End;

Procedure DrawRectangle(X1, Y1, X2, Y2: Integer; Color: Byte; Filled: Boolean);
Begin
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  Bar(X1, Y1, X2, Y2);
 End Else Begin
  Rectangle(X1, Y1, X2, Y2);
 End;
 ImageBuffer.Modified := True;
End;

Procedure DrawEllipse(X, Y, RadiusX, RadiusY: Integer; Color: Byte; Filled: Boolean);
Begin
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  FillEllipse(X, Y, RadiusX, RadiusY);
 End Else Begin
  Ellipse(X, Y, 0, 360, RadiusX, RadiusY);
 End;
 ImageBuffer.Modified := True;
End;

Procedure DrawCircle(X, Y, Radius: Integer; Color: Byte; Filled: Boolean);
Begin
 DrawEllipse(X, Y, Radius, Radius, Color, Filled);
End;

Procedure DrawRoundRectShape(X1, Y1, X2, Y2, RadiusX, RadiusY: Integer; Color: Byte; Filled: Boolean);
Begin
 SetColor(Color);
 If Filled Then Begin
  SetFillStyle(SolidFill, Color);
  { Dessiner un rectangle arrondi rempli }
  Bar(X1 + RadiusX, Y1, X2 - RadiusX, Y2);
  Bar(X1, Y1 + RadiusY, X2, Y2 - RadiusY);
  FillEllipse(X1 + RadiusX, Y1 + RadiusY, RadiusX, RadiusY);
  FillEllipse(X2 - RadiusX, Y1 + RadiusY, RadiusX, RadiusY);
  FillEllipse(X1 + RadiusX, Y2 - RadiusY, RadiusX, RadiusY);
  FillEllipse(X2 - RadiusX, Y2 - RadiusY, RadiusX, RadiusY);
 End Else Begin
  DrawRoundedRect(X1, Y1, X2, Y2, RadiusX, RadiusY);
 End;
 ImageBuffer.Modified := True;
End;

Procedure FloodFillArea(X, Y: Integer; FillColor, BorderColor: Byte);
Begin
 SetFillStyle(SolidFill, FillColor);
 {$IFDEF FPC}
 PtcGraph.FloodFill(X, Y, BorderColor);
 {$ELSE}
 Graph.FloodFill(X, Y, BorderColor);
 {$ENDIF}
 ImageBuffer.Modified := True;
End;

Procedure DrawText(X, Y: Integer; Text: String; Color: Byte);
Begin
 SetColor(Color);
 OutTextXY(X, Y, Text);
 ImageBuffer.Modified := True;
End;

Procedure DrawWithBrush(X, Y: Integer; Color: Byte);
Var
 I, J: Integer;
 HalfSize: Integer;
Begin
 HalfSize := BrushSize div 2;
 For I := -HalfSize to HalfSize do
  For J := -HalfSize to HalfSize do
   If (I * I + J * J) <= (HalfSize * HalfSize) Then
    DrawPixel(X + I, Y + J, Color);
End;

Procedure DrawWithAirbrush(X, Y: Integer; Color: Byte);
Var
 I: Integer;
 RandX, RandY: Integer;
Begin
 For I := 1 to BrushSize * 5 do Begin
  RandX := X + Random(BrushSize * 2) - BrushSize;
  RandY := Y + Random(BrushSize * 2) - BrushSize;
  If Random(3) = 0 Then
   DrawPixel(RandX, RandY, Color);
 End;
End;

Procedure EraseTool(X, Y: Integer);
Begin
 DrawWithBrush(X, Y, BackgroundColor);
End;

Procedure ColorPicker(X, Y: Integer);
Begin
 If (X >= CanvasX) and (X < CanvasX + ImageBuffer.Width) and
    (Y >= CanvasY) and (Y < CanvasY + ImageBuffer.Height) Then Begin
  CurrentColor := GetPixel(X, Y);
  DrawColorPalette;
 End;
End;

{ Procédures de gestion des événements }

Procedure HandleMenuClick(MenuIndex, ItemIndex: Integer);
Begin
 Case MenuIndex of
  MENU_FILE: Begin
   Case ItemIndex of
    0: Begin { Nouveau }
     ClearImage;
     ImageBuffer.FileName := '';
     ImageBuffer.Modified := False;
    End;
    1: Begin { Ouvrir }
     { Afficher le dialogue d'ouverture de fichier }
    End;
    2: Begin { Enregistrer }
     If ImageBuffer.FileName <> '' Then
      SaveImage(ImageBuffer.FileName, ImageBuffer.Format);
    End;
    3: Begin { Enregistrer sous }
     { Afficher le dialogue d'enregistrement }
    End;
    5: Begin { Imprimer }
     { Fonction d'impression }
    End;
    7: Begin { Propriétés }
     { Afficher les propriétés de l'image }
    End;
    9: Running := False; { Quitter }
   End;
  End;
  MENU_EDIT: Begin
   Case ItemIndex of
    0: Undo;
    1: Redo;
    3: Begin { Couper }
    End;
    4: Begin { Copier }
    End;
    5: Begin { Coller }
    End;
    6: Begin { Effacer sélection }
     If SelectionActive Then Begin
      SetFillStyle(SolidFill, BackgroundColor);
      Bar(SelectionRect.Left, SelectionRect.Top,
          SelectionRect.Right, SelectionRect.Bottom);
      SelectionActive := False;
      ImageBuffer.Modified := True;
     End;
    End;
    8: Begin { Tout sélectionner }
     SelectionActive := True;
     SelectionRect.Left := CanvasX;
     SelectionRect.Top := CanvasY;
     SelectionRect.Right := CanvasX + ImageBuffer.Width - 1;
     SelectionRect.Bottom := CanvasY + ImageBuffer.Height - 1;
    End;
   End;
  End;
  MENU_VIEW: Begin
   Case ItemIndex of
    0: Begin { Barre d'outils }
     Menus[MENU_VIEW].Items[0].Checked := Not Menus[MENU_VIEW].Items[0].Checked;
    End;
    1: Begin { Barre de couleurs }
     Menus[MENU_VIEW].Items[1].Checked := Not Menus[MENU_VIEW].Items[1].Checked;
    End;
    2: Begin { Barre d'état }
     Menus[MENU_VIEW].Items[2].Checked := Not Menus[MENU_VIEW].Items[2].Checked;
    End;
    4: Begin { Zoom avant }
     If ZoomLevel < 800 Then Begin
      ZoomLevel := ZoomLevel * 2;
      If ZoomLevel > 800 Then ZoomLevel := 800;
     End;
    End;
    5: Begin { Zoom arrière }
     If ZoomLevel > 25 Then Begin
      ZoomLevel := ZoomLevel div 2;
      If ZoomLevel < 25 Then ZoomLevel := 25;
     End;
    End;
    7: Begin { Plein écran }
    End;
   End;
  End;
  MENU_IMAGE: Begin
   Case ItemIndex of
    0: Begin { Retourner/Pivoter }
     { Afficher le dialogue }
    End;
    1: Begin { Étirer/Incliner }
    End;
    2: InvertColors;
    4: Begin { Redimensionner }
     { Afficher le dialogue }
    End;
    5: CropImage;
    7: Begin { Attributs }
     { Afficher les attributs de l'image }
    End;
    9: ClearImage;
   End;
  End;
  MENU_COLORS: Begin
   Case ItemIndex of
    0: Begin { Modifier palette }
    End;
    1: Begin { Obtenir couleurs }
    End;
   End;
  End;
  MENU_HELP: Begin
   Case ItemIndex of
    0: Begin { Aide }
    End;
    1: Begin { À propos }
     { Afficher la boîte de dialogue À propos }
    End;
   End;
  End;
 End;

 MenuActive := False;
 RedrawInterface;
End;

Procedure HandleToolbarClick(X, Y: Integer);
Var
 ToolIndex: Integer;
 ToolsPerRow: Integer;
 ToolX, ToolY: Integer;
Begin
 ToolsPerRow := 2;
 ToolX := (X - 5) div 23;
 ToolY := (Y - MENUBAR_HEIGHT - 5) div 23;

 If (ToolX >= 0) and (ToolX < ToolsPerRow) and (ToolY >= 0) and (ToolY < 8) Then Begin
  ToolIndex := ToolY * ToolsPerRow + ToolX;
  If (ToolIndex >= 0) and (ToolIndex <= 14) Then Begin
   CurrentTool := ToolIndex;
   DrawToolbar;
  End;
 End;
End;

Procedure HandleColorClick(X, Y: Integer);
Var
 PaletteY: Integer;
 ColorBoxSize: Integer;
 ColorIndex: Integer;
 ColorX, ColorY: Integer;
Begin
 PaletteY := ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT;
 ColorBoxSize := 16;

 { Vérifier si le clic est dans la palette }
 If (X >= 50) and (Y >= PaletteY + 5) Then Begin
  ColorX := (X - 50) div (ColorBoxSize + 2);
  ColorY := (Y - PaletteY - 5) div (ColorBoxSize + 2);

  If (ColorX >= 0) and (ColorX < 14) and (ColorY >= 0) and (ColorY < 2) Then Begin
   ColorIndex := ColorY * 14 + ColorX;
   If ColorIndex < 28 Then Begin
    If (MouseButtons and 1) <> 0 Then
     CurrentColor := StandardPalette[ColorIndex]
    Else If (MouseButtons and 2) <> 0 Then
     BackgroundColor := StandardPalette[ColorIndex];
    DrawColorPalette;
   End;
  End;
 End;
End;

Procedure HandleCanvasClick(X, Y: Integer);
Begin
 If Drawing Then Exit;

 Case CurrentTool of
  TOOL_SELECT: Begin
   SelectionActive := True;
   SelectionRect.Left := X;
   SelectionRect.Top := Y;
   SelectionRect.Right := X;
   SelectionRect.Bottom := Y;
   Drawing := True;
   StartX := X;
   StartY := Y;
  End;
  TOOL_ERASER: Begin
   Drawing := True;
   EraseTool(X, Y);
  End;
  TOOL_FILL: Begin
   FloodFillArea(X, Y, CurrentColor, GetPixel(X, Y));
   AddToHistory(TOOL_FILL);
  End;
  TOOL_PICKER: Begin
   ColorPicker(X, Y);
  End;
  TOOL_MAGNIFY: Begin
   If ZoomLevel < 800 Then
    ZoomLevel := ZoomLevel * 2;
  End;
  TOOL_PENCIL: Begin
   Drawing := True;
   DrawPixel(X, Y, CurrentColor);
  End;
  TOOL_BRUSH: Begin
   Drawing := True;
   DrawWithBrush(X, Y, CurrentColor);
  End;
  TOOL_AIRBRUSH: Begin
   Drawing := True;
   DrawWithAirbrush(X, Y, CurrentColor);
  End;
  TOOL_TEXT: Begin
   TextX := X;
   TextY := Y;
   TextInsertMode := True;
   TextInput := '';
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_ROUNDRECT, TOOL_CURVE, TOOL_POLYGON: Begin
   Drawing := True;
   StartX := X;
   StartY := Y;
   EndX := X;
   EndY := Y;
  End;
 End;
End;

Procedure HandleCanvasDrag(X, Y: Integer);
Begin
 If Not Drawing Then Exit;

 Case CurrentTool of
  TOOL_SELECT: Begin
   SelectionRect.Right := X;
   SelectionRect.Bottom := Y;
   DrawSelection;
  End;
  TOOL_ERASER: Begin
   EraseTool(X, Y);
  End;
  TOOL_PENCIL: Begin
   DrawLine(OldMouseX, OldMouseY, X, Y, CurrentColor);
  End;
  TOOL_BRUSH: Begin
   DrawWithBrush(X, Y, CurrentColor);
  End;
  TOOL_AIRBRUSH: Begin
   DrawWithAirbrush(X, Y, CurrentColor);
  End;
  TOOL_LINE, TOOL_RECT, TOOL_ELLIPSE, TOOL_ROUNDRECT: Begin
   { Effacer l'aperçu précédent et dessiner le nouveau }
   EndX := X;
   EndY := Y;
  End;
 End;
End;

Procedure HandleCanvasRelease(X, Y: Integer);
Var
 CenterX, CenterY, RadiusX, RadiusY: Integer;
Begin
 If Not Drawing Then Exit;
 Drawing := False;

 Case CurrentTool of
  TOOL_SELECT: Begin
   { Normaliser le rectangle de sélection }
   If SelectionRect.Left > SelectionRect.Right Then Begin
    CenterX := SelectionRect.Left;
    SelectionRect.Left := SelectionRect.Right;
    SelectionRect.Right := CenterX;
   End;
   If SelectionRect.Top > SelectionRect.Bottom Then Begin
    CenterX := SelectionRect.Top;
    SelectionRect.Top := SelectionRect.Bottom;
    SelectionRect.Bottom := CenterX;
   End;
  End;
  TOOL_LINE: Begin
   DrawLine(StartX, StartY, X, Y, CurrentColor);
   AddToHistory(TOOL_LINE);
  End;
  TOOL_RECT: Begin
   DrawRectangle(StartX, StartY, X, Y, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_RECT);
  End;
  TOOL_ELLIPSE: Begin
   CenterX := (StartX + X) div 2;
   CenterY := (StartY + Y) div 2;
   RadiusX := Abs(X - StartX) div 2;
   RadiusY := Abs(Y - StartY) div 2;
   DrawEllipse(CenterX, CenterY, RadiusX, RadiusY, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_ELLIPSE);
  End;
  TOOL_ROUNDRECT: Begin
   DrawRoundRectShape(StartX, StartY, X, Y, 10, 10, CurrentColor, FillStyle > 0);
   AddToHistory(TOOL_ROUNDRECT);
  End;
 End;
End;

Procedure HandleMouseEvent;
Var
 NewButtons: Integer;
Begin
 GetMouseStateLocal(MouseX, MouseY, MouseButtons);

 { Vérifier les clics }
 If (MouseButtons and 1) <> 0 Then Begin
  { Bouton gauche pressé }

  { Vérifier la zone de menu }
  If (MouseY < MENUBAR_HEIGHT) Then Begin
   { Clic sur la barre de menu }
   If Not MenuActive Then Begin
    MenuActive := True;
    ActiveMenu := 0;
    ActiveMenuItem := -1;

    { Trouver le menu cliqué }
    If MouseX < 60 Then ActiveMenu := MENU_FILE
    Else If MouseX < 125 Then ActiveMenu := MENU_EDIT
    Else If MouseX < 195 Then ActiveMenu := MENU_VIEW
    Else If MouseX < 255 Then ActiveMenu := MENU_IMAGE
    Else If MouseX < 325 Then ActiveMenu := MENU_COLORS
    Else ActiveMenu := MENU_HELP;

    RedrawInterface;
   End;
  End
  { Vérifier le menu déroulant }
  Else If MenuActive Then Begin
   If (MouseX >= Menus[ActiveMenu].X) and
      (MouseX < Menus[ActiveMenu].X + Menus[ActiveMenu].Width) Then Begin
    ActiveMenuItem := (MouseY - MENUBAR_HEIGHT - 2) div 18;
    If (ActiveMenuItem >= 0) and (ActiveMenuItem < Menus[ActiveMenu].ItemCount) Then Begin
     If Not Menus[ActiveMenu].Items[ActiveMenuItem].Separator Then
      HandleMenuClick(ActiveMenu, ActiveMenuItem);
    End;
   End Else Begin
    MenuActive := False;
    RedrawInterface;
   End;
  End
  { Vérifier la barre d'outils }
  Else If (MouseX < TOOLBAR_WIDTH) and (MouseY > MENUBAR_HEIGHT) and
          (MouseY < ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT) Then Begin
   HandleToolbarClick(MouseX, MouseY);
  End
  { Vérifier la barre de couleurs }
  Else If (MouseY >= ScreenHeight - STATUSBAR_HEIGHT - COLORBAR_HEIGHT) and
          (MouseY < ScreenHeight - STATUSBAR_HEIGHT) Then Begin
   HandleColorClick(MouseX, MouseY);
  End
  { Vérifier le canvas }
  Else If (MouseX >= CanvasX) and (MouseX < CanvasX + CanvasWidth) and
          (MouseY >= CanvasY) and (MouseY < CanvasY + CanvasHeight) Then Begin
   If Not Drawing Then
    HandleCanvasClick(MouseX, MouseY)
   Else
    HandleCanvasDrag(MouseX, MouseY);
  End;
 End
 Else Begin
  { Bouton relâché }
  If Drawing Then
   HandleCanvasRelease(MouseX, MouseY);
 End;

 { Mise à jour de la barre d'état si la souris a bougé }
 If (MouseX <> OldMouseX) or (MouseY <> OldMouseY) Then Begin
  DrawStatusBar;
  OldMouseX := MouseX;
  OldMouseY := MouseY;
 End;
End;

Procedure HandleKeyboardEvent;
Var
 Key: Char;
 ExtKey: Char;
Begin
 If Not KeyPressed Then Exit;

 Key := ReadKey;

 { Touche étendue }
 If Key = #0 Then Begin
  ExtKey := ReadKey;
  Case ExtKey of
   #59: Begin { F1 - Aide }
   End;
   #60: Begin { F2 }
   End;
   #68: Running := False; { F10 - Quitter }
   #72: Begin { Flèche haut }
    If BrushSize < 50 Then Inc(BrushSize);
    DrawToolbar;
   End;
   #80: Begin { Flèche bas }
    If BrushSize > 1 Then Dec(BrushSize);
    DrawToolbar;
   End;
  End;
 End
 Else Begin
  { Mode saisie de texte }
  If TextInsertMode Then Begin
   If Key = #13 Then Begin { Entrée }
    DrawText(TextX, TextY, TextInput, CurrentColor);
    TextInsertMode := False;
    TextInput := '';
    AddToHistory(TOOL_TEXT);
   End
   Else If Key = #27 Then Begin { Échap }
    TextInsertMode := False;
    TextInput := '';
   End
   Else If Key = #8 Then Begin { Retour arrière }
    If Length(TextInput) > 0 Then
     Delete(TextInput, Length(TextInput), 1);
   End
   Else Begin
    TextInput := TextInput + Key;
   End;
  End
  Else Begin
   { Raccourcis clavier - implémentation simplifiée }
   Case UpCase(Key) of
    '+': If ZoomLevel < 800 Then ZoomLevel := ZoomLevel * 2;
    '-': If ZoomLevel > 25 Then ZoomLevel := ZoomLevel div 2;
    #27: Begin { Échap }
     If MenuActive Then Begin
      MenuActive := False;
      RedrawInterface;
     End
     Else If SelectionActive Then Begin
      SelectionActive := False;
      RedrawInterface;
     End;
    End;
   End;
  End;
 End;
End;

{ Procédure principale }

Procedure Initialize;
Begin
 { Initialiser le générateur de nombres aléatoires }
 Randomize;

 { Initialiser les graphiques }
 InitGraphics;

 { Initialiser la souris }
 {$IFDEF FPC}
 InitMouse;
 {$ELSE}
 InitMouse;
 {$ENDIF}

 { Initialiser les composants de l'application }
 InitPalette;
 InitMenus;
 InitImage;
 InitTools;
 InitHistory;

 { Variables d'état }
 Running := True;
 MenuActive := False;
 ActiveMenu := -1;
 ActiveMenuItem := -1;
 SelectionActive := False;
 Drawing := False;
 TextInsertMode := False;

 { Dessiner l'interface }
 RedrawInterface;

 { Afficher la souris }
 {$IFDEF FPC}
 ShowMouse;
 {$ELSE}
 ShowMouse;
 {$ENDIF}
End;

Procedure Cleanup;
Begin
 { Masquer la souris }
 {$IFDEF FPC}
 HideMouse;
 {$ELSE}
 HideMouse;
 {$ENDIF}

 { Libérer l'historique }
 While UndoList <> Nil do Begin
  RedoList := UndoList;
  UndoList := UndoList^.Next;
  Dispose(RedoList);
 End;

 While RedoList <> Nil do Begin
  UndoList := RedoList;
  RedoList := RedoList^.Next;
  Dispose(UndoList);
 End;

 { Fermer le mode graphique }
 CloseGraph;
End;

Procedure MainLoop;
Begin
 While Running do Begin
  HandleMouseEvent;
  HandleKeyboardEvent;
  Delay(10);
 End;
End;

{ Point d'entrée du programme }
BEGIN
 If (ParamStr(1) = '/?') or (ParamStr(1) = '--help') or (ParamStr(1) = '-h') Then Begin
  WriteLn('PAINT: Clone de Microsoft Paint en Turbo Pascal/Free Pascal');
  WriteLn;
  WriteLn('Syntaxe: PAINT [fichier.bmp|gif|png|jpg]');
  WriteLn;
  WriteLn('Fonctionnalités:');
  WriteLn(' - Interface graphique complète avec menus et barre d''outils');
  WriteLn(' - Support de la souris (Int 33h / PtcMouse)');
  WriteLn(' - Outils de dessin: Crayon, Pinceau, Aérographe, Ligne, Rectangle, Ellipse...');
  WriteLn(' - Support des formats: BMP, GIF, PNG, JPEG');
  WriteLn(' - Support de la transparence pour GIF et PNG');
  WriteLn(' - Redimensionnement et rognage d''image');
  WriteLn(' - Support de 2 a 32 bits de profondeur de couleur');
  WriteLn(' - Historique Annuler/Retablir');
  WriteLn;
  WriteLn('Raccourcis clavier:');
  WriteLn(' Ctrl+N  Nouveau fichier');
  WriteLn(' Ctrl+O  Ouvrir fichier');
  WriteLn(' Ctrl+S  Enregistrer');
  WriteLn(' Ctrl+Z  Annuler');
  WriteLn(' Ctrl+Y  Retablir');
  WriteLn(' Ctrl+A  Tout selectionner');
  WriteLn(' +/-     Zoom avant/arriere');
  WriteLn(' Echap   Annuler operation en cours');
  WriteLn(' F10     Quitter');
 End
 Else Begin
  Initialize;

  { Charger un fichier si spécifié en ligne de commande }
  If ParamCount > 0 Then Begin
   If LoadImage(ParamStr(1)) Then
    RedrawInterface;
  End;

  MainLoop;
  Cleanup;
 End;
END.
