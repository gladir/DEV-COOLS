{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Clone de l'application IIS (Internet Information Services) en mode graphique

  TODO: Liste des 25 points a implementer pour le clone IIS

  1.  DONE: Gestion souris complete (TP/FPC) - GetMouseState FPC avec PtcMouse,
            procedure PollMouse unifiee
  2.  DONE: Constantes et types de base - couleurs, dimensions, TTreeNode,
            TMenuItem, TContextMenu, TActionPanel
  3.  DONE: Initialisation graphique robuste - detection driver/mode FPC via
            PtcGraph, resolution 1024x768, gestion erreurs
  4.  DONE: Barre de menus principale - Fichier, Affichage, Aide avec surbrillance
            au survol et ouverture/fermeture au clic gauche
  5.  DONE: Menu Fichier - Connecter, Deconnecter, Quitter avec raccourcis
            clavier et separateurs
  6.  DONE: Menu Affichage - Actualiser, Panneau de fonctionnalites, Panneau de
            contenu, Panneau d'actions
  7.  DONE: Menu Aide - Documentation IIS, A propos de IIS
  8.  DONE: Panneau gauche arborescence - Ordinateur local, Pools d'applications,
            Sites, expandable/collapsable au clic
  9.  DONE: Noeud Pools d'applications - liste des pools avec icone, nom, etat
            (Demarre/Arrete)
  10. DONE: Menu contextuel Pools d'applications (clic droit) - Ajouter un pool
            d'applications, Actualiser, Aide
  11. DONE: Noeud Sites - liste des sites installes avec icone, nom, etat
  12. DONE: Menu contextuel Sites (clic droit) - Ajouter un site Web, Actualiser,
            Aide
  13. DONE: Site individuel (clic gauche) - 15 icones de fonctionnalites dans
            panneau central : Editeur de configuration, Authentification, CGI,
            Compression, Document par defaut, En-tetes de reponses HTTP,
            Filtrage de demandes, Journalisation, Mappages de gestionnaire,
            Mise en cache de sortie, Modules, Pages d'erreurs, Parametres SSL,
            Reecriture d'URL, Types MIME
  14. DONE: Menu contextuel icones de fonctionnalites (clic droit) - Ouvrir la
            fonctionnalite, Aide sur cette fonctionnalite
  15. DONE: Panneau central vue grille - icones en grille avec label, double-clic
            pour ouvrir, survol pour surligner
  16. DONE: Panneau droit fenetre des actions - Demarrer, Arreter, Redemarrer,
            Parcourir, Modifier les liaisons, Parametres avances
  17. DONE: Gestion selection et etat - CurrentSelection pilotant l'affichage
            des panneaux central et droit
  18. DONE: Dialogues modaux - ShowDialog et ShowInputDialog generiques
  19. DONE: Persistance configuration - IIS.CFG format cle=valeur pour sites,
            pools, etats
  20. DONE: Support CGI - liste extensions CGI, Ajouter (dialogue), execution
            via Exec/Shell
  21. DONE: Support FastCGI - Mappages de gestionnaire, LaunchFastCGIProcess
            via fpExecve (FPC) ou Exec (TP)
  22. DONE: Boucle evenementielle principale - repeat until avec poll souris et
            clavier, dispatch clic gauche/droit/double-clic, Echap/Entree
  23. DONE: Rendu double-buffer - GetImage/PutImage pour eviter le scintillement
  24. DONE: Redimensionnement et reactivite - zones recalculees selon resolution
  25. DONE: Nettoyage et sortie propre - Shutdown masque souris, CloseGraph,
            libere memoire, quitte avec code 0
}

Program IIS;

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse,Mouse
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 { ================================================================
   Constantes de dimensions - TODO point 2 et 24
   ================================================================ }
 SCREEN_W         = 1024;
 SCREEN_H         = 768;
 MENUBAR_H        = 20;
 TREE_W           = 220;
 ACTION_W         = 180;
 SPLITTER_W       = 2;
 PANEL_Y          = MENUBAR_H;
 PANEL_H          = SCREEN_H - MENUBAR_H;
 TREE_ITEM_H      = 18;
 TREE_INDENT      = 14;
 ICON_W           = 62;
 ICON_H           = 52;
 ICON_LABEL_H     = 24;
 ICON_CELL_W      = ICON_W + 12;
 ICON_CELL_H      = ICON_H + ICON_LABEL_H + 8;
 ICON_COLS        = 7;
 MENU_ITEM_H      = 18;
 MENU_W_FICHIER   = 160;
 MENU_W_AFFICHAGE = 200;
 MENU_W_AIDE      = 180;
 CTX_MENU_W       = 200;
 CTX_MENU_ITEM_H  = 18;
 BTN_W            = 80;
 BTN_H            = 22;
 DLG_W            = 380;
 DLG_H            = 160;
 INPUT_DLG_H      = 180;
 INPUT_FIELD_W    = 280;
 INPUT_FIELD_H    = 18;

 { ================================================================
   Constantes de couleurs - TODO point 2
   ================================================================ }
 CLR_BG           = 7;   { Gris clair - fond general }
 CLR_MENUBAR      = 8;   { Gris fonce - barre de menus }
 CLR_MENUBAR_TXT  = 15;  { Blanc - texte barre de menus }
 CLR_MENU_BG      = 15;  { Blanc - fond menu deroulant }
 CLR_MENU_TXT     = 0;   { Noir - texte menu }
 CLR_MENU_SEL     = 1;   { Bleu - selection menu }
 CLR_MENU_SEL_TXT = 15;  { Blanc - texte selection menu }
 CLR_MENU_SEP     = 8;   { Gris fonce - separateur menu }
 CLR_TREE_BG      = 15;  { Blanc - fond arborescence }
 CLR_TREE_TXT     = 0;   { Noir - texte arborescence }
 CLR_TREE_SEL     = 1;   { Bleu - selection arborescence }
 CLR_TREE_SEL_TXT = 15;  { Blanc - texte selection }
 CLR_CENTER_BG    = 7;   { Gris - fond panneau central }
 CLR_ICON_BG      = 15;  { Blanc - fond icone }
 CLR_ICON_BORDER  = 8;   { Gris fonce - bordure icone }
 CLR_ICON_SEL     = 11;  { Cyan clair - icone selectionnee }
 CLR_ICON_HOVER   = 14;  { Jaune - icone survolee }
 CLR_ICON_TXT     = 0;   { Noir - texte icone }
 CLR_ACTION_BG    = 7;   { Gris - fond panneau actions }
 CLR_ACTION_TXT   = 0;   { Noir - texte actions }
 CLR_ACTION_LINK  = 1;   { Bleu - lien action }
 CLR_ACTION_HDR   = 1;   { Bleu - en-tete section action }
 CLR_ACTION_HDR_T = 15;  { Blanc - texte en-tete action }
 CLR_BORDER       = 8;   { Gris fonce - bordures }
 CLR_DLG_BG       = 7;   { Gris - fond dialogue }
 CLR_DLG_TITLE    = 1;   { Bleu - titre dialogue }
 CLR_DLG_TITLE_T  = 15;  { Blanc - texte titre dialogue }
 CLR_BTN_BG       = 7;   { Gris - fond bouton }
 CLR_BTN_TXT      = 0;   { Noir - texte bouton }
 CLR_BTN_BORDER   = 8;   { Gris fonce - bordure bouton }
 CLR_STARTED      = 2;   { Vert - etat Demarre }
 CLR_STOPPED      = 4;   { Rouge - etat Arrete }
 CLR_WHITE        = 15;
 CLR_BLACK        = 0;
 CLR_INPUT_BG     = 15;  { Blanc - fond champ saisie }
 CLR_INPUT_BORDER = 8;   { Gris - bordure champ saisie }

 { ================================================================
   Constantes souris - TODO point 1
   ================================================================ }
 MOUSE_LEFT       = 1;
 MOUSE_RIGHT      = 2;
 MOUSE_MIDDLE     = 4;
 DBLCLICK_FRAMES  = 25;  { Nombre de frames entre deux clics = double-clic }

 { ================================================================
   Types de noeuds de l'arborescence - TODO point 8
   ================================================================ }
 NODE_ROOT        = 0;
 NODE_APPPOOLS    = 1;
 NODE_SITES       = 2;
 NODE_APPPOOL     = 3;
 NODE_SITE        = 4;

 { ================================================================
   Types de selection - TODO point 17
   ================================================================ }
 SEL_NONE         = 0;
 SEL_ROOT         = 1;
 SEL_APPPOOLS     = 2;
 SEL_APPPOOL      = 3;
 SEL_SITES        = 4;
 SEL_SITE         = 5;
 SEL_FEATURE      = 6;

 { ================================================================
   Indices de menus - TODO point 4
   ================================================================ }
 MENU_NONE        = 0;
 MENU_FICHIER     = 1;
 MENU_AFFICHAGE   = 2;
 MENU_AIDE        = 3;
 MENU_COUNT       = 3;

 { Items Menu Fichier - TODO point 5 }
 MF_CONNECTER     = 1;
 MF_DECONNECTER   = 2;
 MF_SEP1          = 3;
 MF_QUITTER       = 4;
 MF_COUNT         = 4;

 { Items Menu Affichage - TODO point 6 }
 MA_ACTUALISER    = 1;
 MA_FONCTIONS     = 2;
 MA_CONTENU       = 3;
 MA_ACTIONS       = 4;
 MA_COUNT         = 4;

 { Items Menu Aide - TODO point 7 }
 MH_DOC           = 1;
 MH_APROPOS       = 2;
 MH_COUNT         = 2;

 { ================================================================
   Indices des fonctionnalites - TODO point 13
   ================================================================ }
 FEAT_EDITEUR     = 1;
 FEAT_AUTH        = 2;
 FEAT_CGI         = 3;
 FEAT_COMPRESS    = 4;
 FEAT_DOC_DEF     = 5;
 FEAT_ENTETES     = 6;
 FEAT_FILTRAGE    = 7;
 FEAT_JOURNAL     = 8;
 FEAT_MAPPAGES    = 9;
 FEAT_CACHE       = 10;
 FEAT_MODULES     = 11;
 FEAT_ERREURS     = 12;
 FEAT_SSL         = 13;
 FEAT_REECRITURE  = 14;
 FEAT_MIME        = 15;
 FEAT_COUNT       = 15;

 { Types de menus contextuels }
 CTX_NONE         = 0;
 CTX_APPPOOLS     = 1;
 CTX_SITES        = 2;
 CTX_SITE         = 3;
 CTX_FEATURE      = 4;

 { Vues du panneau central }
 VIEW_EMPTY       = 0;
 VIEW_FEATURES    = 1;
 VIEW_CGI         = 2;
 VIEW_FASTCGI     = 3;

 { Tailles maximales }
 MAX_SITES        = 20;
 MAX_POOLS        = 20;
 MAX_CGI          = 50;
 MAX_FASTCGI      = 20;
 MAX_TREE_NODES   = 60;
 MAX_CTX_ITEMS    = 10;
 MAX_ACTION_ITEMS = 30;

Type
 { ================================================================
   Types de base - TODO point 2
   ================================================================ }
 TString20  = String[20];
 TString50  = String[50];
 TString100 = String[100];
 TString255 = String[255];

 { Informations sur un site IIS - TODO point 11 }
 TSiteInfo = Record
  Name     : TString100;
  PhysPath : TString255;
  Port     : Integer;
  Started  : Boolean;
 End;

 { Informations sur un pool d'applications - TODO point 9 }
 TPoolInfo = Record
  Name    : TString100;
  Started : Boolean;
  Runtime : TString20;
 End;

 { Entree CGI - TODO point 20 }
 TCGIEntry = Record
  Extension : TString20;
  ExePath   : TString255;
  Enabled   : Boolean;
 End;

 { Entree FastCGI - TODO point 21 }
 TFastCGIEntry = Record
  ExePath   : TString255;
  Processes : Integer;
  Enabled   : Boolean;
 End;

 { Noeud de l'arborescence - TODO point 2 et 8 }
 TTreeNode = Record
  Caption  : TString100;
  NodeType : Integer;
  Level    : Integer;
  Expanded : Boolean;
  DataIdx  : Integer;
  ScreenY  : Integer;
  Visible  : Boolean;
 End;

 { Element de menu - TODO point 2 et 4 }
 TMenuItem = Record
  Caption   : TString50;
  ShortCut  : TString20;
  Enabled   : Boolean;
  Separator : Boolean;
 End;

 { Menu contextuel - TODO point 2 et 10 }
 TContextMenu = Record
  Items      : Array[1..MAX_CTX_ITEMS] Of TMenuItem;
  ItemCount  : Integer;
  X, Y       : Integer;
  Visible    : Boolean;
  CtxType    : Integer;
  CtxDataIdx : Integer;
 End;

 { Element du panneau d'actions - TODO point 2 et 16 }
 TActionItem = Record
  Caption : TString100;
  Enabled : Boolean;
  IsHdr   : Boolean;
  ScreenY : Integer;
 End;

Var
 { ================================================================
   Etat graphique
   ================================================================ }
 ScreenW, ScreenH : Integer;

 { ================================================================
   Etat de la souris - TODO point 1
   ================================================================ }
 MouseAvailable   : Boolean;
 MouseX, MouseY   : LongInt;
 MouseBtn         : LongInt;
 LastMouseX       : LongInt;
 LastMouseY       : LongInt;
 LastMouseBtn     : LongInt;
 DblClickCtr      : Integer;
 LastClickX       : LongInt;
 LastClickY       : LongInt;
 WasDblClick      : Boolean;

 { ================================================================
   Etat des menus - TODO point 4
   ================================================================ }
 OpenMenuIdx      : Integer;
 HoverMenuIdx     : Integer;
 HoverMenuItemIdx : Integer;

 { ================================================================
   Arborescence - TODO point 8
   ================================================================ }
 TreeNodes        : Array[1..MAX_TREE_NODES] Of TTreeNode;
 TreeNodeCount    : Integer;
 TreeScrollY      : Integer;
 SelectedNodeIdx  : Integer;
 RootExpanded     : Boolean;
 PoolsExpanded    : Boolean;
 SitesExpanded    : Boolean;

 { ================================================================
   Donnees sites et pools - TODO point 9 et 11
   ================================================================ }
 Sites     : Array[1..MAX_SITES] Of TSiteInfo;
 SiteCount : Integer;
 Pools     : Array[1..MAX_POOLS] Of TPoolInfo;
 PoolCount : Integer;

 { ================================================================
   Donnees CGI et FastCGI - TODO point 20 et 21
   ================================================================ }
 CGIEntries     : Array[1..MAX_CGI] Of TCGIEntry;
 CGICount       : Integer;
 FastCGIEntries : Array[1..MAX_FASTCGI] Of TFastCGIEntry;
 FastCGICount   : Integer;

 { ================================================================
   Etat de selection - TODO point 17
   ================================================================ }
 CurrentSelection  : Integer;
 SelectedSiteIdx   : Integer;
 SelectedPoolIdx   : Integer;
 SelectedFeatureIdx: Integer;

 { ================================================================
   Menu contextuel - TODO point 10, 12, 14
   ================================================================ }
 CtxMenu : TContextMenu;

 { ================================================================
   Panneau d'actions - TODO point 16
   ================================================================ }
 ActionItems     : Array[1..MAX_ACTION_ITEMS] Of TActionItem;
 ActionItemCount : Integer;
 ActionScrollY   : Integer;

 { ================================================================
   Noms des fonctionnalites - TODO point 13
   ================================================================ }
 FeatureNames : Array[1..FEAT_COUNT] Of TString100;

 { ================================================================
   Double-buffer - TODO point 23
   ================================================================ }
 ScreenBuffer  : Pointer;
 BufferSize    : LongInt;
 BufferInited  : Boolean;

 { ================================================================
   Dimensions calculees - TODO point 24
   ================================================================ }
 CenterX : Integer;
 CenterW : Integer;
 CenterY : Integer;
 CenterH : Integer;
 ActX    : Integer;
 ActW    : Integer;

 { ================================================================
   Etat general de l'application
   ================================================================ }
 AppRunning    : Boolean;
 CenterView    : Integer;
 MachineName   : TString50;
 HoverIconIdx  : Integer;
 InputBuffer   : TString255;
 InputBufLen   : Integer;
 InputCurPos   : Integer;

{ ================================================================
  GESTION DE LA SOURIS - TODO point 1
  ================================================================ }

{$IFNDEF FPC}
 { --- Turbo Pascal : INT 33h --- }

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
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X      := Regs.CX;
  Y      := Regs.DX;
 End;

{$ELSE}
 { --- Free Pascal : PtcMouse --- }

 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { PtcMouse : curseur visible par defaut }
 End;

 Procedure HideMouse;
 Begin
  { PtcMouse : masquage non necessaire en mode graphique }
 End;

 { GetMouseState via PtcMouse : on interroge l'etat courant de la souris.
   PtcMouse implemente le pilote Mouse FPC standard. La structure TMouseState
   retournee par Mouse.GetMouseState contient les champs X, Y et Buttons. }
 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  MS : TMouseState;
 Begin
  { Appel qualifie a l'unite mouse du FPC (via PtcMouse) }
  mouse.GetMouseState(MS);
  X      := MS.X;
  Y      := MS.Y;
  Button := 0;
  If MS.Buttons And 1 <> 0 Then Button := Button Or MOUSE_LEFT;
  If MS.Buttons And 2 <> 0 Then Button := Button Or MOUSE_RIGHT;
 End;

{$ENDIF}

{ Procedure unifiee de poll souris - TODO point 1 }
Procedure PollMouse;
Var
 NX, NY, NBtn : LongInt;
Begin
 LastMouseX   := MouseX;
 LastMouseY   := MouseY;
 LastMouseBtn := MouseBtn;
 GetMouseState(NX, NY, NBtn);
 MouseX   := NX;
 MouseY   := NY;
 MouseBtn := NBtn;
 { Gestion double-clic - TODO point 22 }
 WasDblClick := False;
 If (NBtn And MOUSE_LEFT <> 0) And (LastMouseBtn And MOUSE_LEFT = 0) Then Begin
  { Nouveau clic gauche }
  If (DblClickCtr > 0) And (DblClickCtr < DBLCLICK_FRAMES) And
     (Abs(NX - LastClickX) < 5) And (Abs(NY - LastClickY) < 5) Then Begin
   WasDblClick := True;
   DblClickCtr := 0;
  End Else Begin
   DblClickCtr := 1;
   LastClickX  := NX;
   LastClickY  := NY;
  End;
 End Else If DblClickCtr > 0 Then Begin
  Inc(DblClickCtr);
  If DblClickCtr >= DBLCLICK_FRAMES Then
   DblClickCtr := 0;
 End;
End;

{ ================================================================
  UTILITAIRES GENERAUX
  ================================================================ }

Function IntToStr(N: LongInt): String;
Var
 S  : String;
 Neg: Boolean;
Begin
 If N = 0 Then Begin
  IntToStr := '0'; Exit;
 End;
 Neg := N < 0;
 If Neg Then N := -N;
 S := '';
 While N > 0 Do Begin
  S := Chr(Ord('0') + (N Mod 10)) + S;
  N := N Div 10;
 End;
 If Neg Then S := '-' + S;
 IntToStr := S;
End;

Function StrToInt(S: String): LongInt;
Var
 I, V: LongInt;
 Neg : Boolean;
Begin
 V := 0;
 Neg := False;
 I := 1;
 If (Length(S) > 0) And (S[1] = '-') Then Begin
  Neg := True; Inc(I);
 End;
 While I <= Length(S) Do Begin
  If (S[I] >= '0') And (S[I] <= '9') Then
   V := V * 10 + (Ord(S[I]) - Ord('0'));
  Inc(I);
 End;
 If Neg Then V := -V;
 StrToInt := V;
End;

Function UpStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then
   S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

Function TrimStr(S: String): String;
Var I: Integer;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] = ' ') Do
  Delete(S, Length(S), 1);
 TrimStr := S;
End;

Function PadRight(S: String; N: Integer): String;
Begin
 While Length(S) < N Do S := S + ' ';
 If Length(S) > N Then S := Copy(S, 1, N);
 PadRight := S;
End;

{ ================================================================
  INITIALISATION GRAPHIQUE - TODO point 3
  ================================================================ }

Procedure RecalcLayout;
Begin
 { Recalcule les zones en fonction de la resolution - TODO point 24 }
 ScreenW  := GetMaxX + 1;
 ScreenH  := GetMaxY + 1;
 CenterX  := TREE_W + SPLITTER_W;
 ActW     := ACTION_W;
 ActX     := ScreenW - ActW;
 CenterW  := ActX - SPLITTER_W - CenterX;
 CenterY  := MENUBAR_H;
 CenterH  := ScreenH - MENUBAR_H;
End;

Procedure InitializeGraphics;
Var
 Driver, Mode : Integer;
 ErrCode      : Integer;
Begin
 {$IFDEF FPC}
  Driver := VGA;
  Mode   := VGAHi;
 {$ELSE}
  Driver := Detect;
  Mode   := VGAHi;
 {$ENDIF}
 InitGraph(Driver, Mode, '');
 ErrCode := GraphResult;
 If ErrCode = grOk Then Begin
  SetColor(CLR_BLACK);
  SetLineStyle(0, 0, 1);
  RecalcLayout;
 End Else Begin
  WriteLn('Erreur graphique : ', GraphErrorMsg(ErrCode));
  Halt(1);
 End;
End;

{ ================================================================
  PRIMITIVES GRAPHIQUES
  ================================================================ }

Procedure DrawFilledRect(X1, Y1, X2, Y2, Color: Integer);
Begin
 SetColor(Color);
 SetFillStyle(SolidFill, Color);
 Bar(X1, Y1, X2, Y2);
End;

Procedure DrawRect(X1, Y1, X2, Y2, Color: Integer);
Begin
 SetColor(Color);
 Rectangle(X1, Y1, X2, Y2);
End;

Procedure DrawHLine(X1, X2, Y, Color: Integer);
Begin
 SetColor(Color);
 Line(X1, Y, X2, Y);
End;

Procedure DrawVLine(X, Y1, Y2, Color: Integer);
Begin
 SetColor(Color);
 Line(X, Y1, X, Y2);
End;

Procedure DrawText(X, Y: Integer; S: String; Color: Integer);
Begin
 SetColor(Color);
 MoveTo(X, Y);
 OutText(S);
End;

Procedure DrawTextCentered(X1, X2, Y: Integer; S: String; Color: Integer);
Var
 TW, TX : Integer;
Begin
 TW := TextWidth(S);
 TX := X1 + (X2 - X1 - TW) Div 2;
 If TX < X1 Then TX := X1;
 DrawText(TX, Y, S, Color);
End;

Procedure Draw3DRect(X1, Y1, X2, Y2: Integer; Raised: Boolean);
Begin
 If Raised Then Begin
  DrawHLine(X1, X2, Y1, CLR_WHITE);
  DrawVLine(X1, Y1, Y2, CLR_WHITE);
  DrawHLine(X1, X2, Y2, CLR_BORDER);
  DrawVLine(X2, Y1, Y2, CLR_BORDER);
 End Else Begin
  DrawHLine(X1, X2, Y1, CLR_BORDER);
  DrawVLine(X1, Y1, Y2, CLR_BORDER);
  DrawHLine(X1, X2, Y2, CLR_WHITE);
  DrawVLine(X2, Y1, Y2, CLR_WHITE);
 End;
End;

{ Dessine une petite icone symbolique pour une fonctionnalite }
Procedure DrawFeatureIcon(X, Y, FeatureIdx, BgColor: Integer);
Begin
 DrawFilledRect(X, Y, X + ICON_W - 1, Y + ICON_H - 1, BgColor);
 DrawRect(X, Y, X + ICON_W - 1, Y + ICON_H - 1, CLR_ICON_BORDER);
 { Symbole simple centre dans l'icone }
 SetColor(CLR_BLACK);
 Case FeatureIdx Of
  FEAT_EDITEUR  : Begin { Editeur : document avec lignes }
   DrawFilledRect(X+12, Y+8,  X+ICON_W-12, Y+ICON_H-8, 15);
   DrawRect(X+12, Y+8, X+ICON_W-12, Y+ICON_H-8, CLR_BORDER);
   DrawHLine(X+16, X+ICON_W-16, Y+16, CLR_BLACK);
   DrawHLine(X+16, X+ICON_W-16, Y+22, CLR_BLACK);
   DrawHLine(X+16, X+ICON_W-22, Y+28, CLR_BLACK);
  End;
  FEAT_AUTH     : Begin { Verrou }
   DrawFilledRect(X+22, Y+22, X+ICON_W-22, Y+ICON_H-10, CLR_BORDER);
   DrawRect(X+22, Y+22, X+ICON_W-22, Y+ICON_H-10, CLR_BLACK);
   DrawVLine(X+ICON_W Div 2, Y+12, Y+22, CLR_BLACK);
  End;
  FEAT_CGI      : Begin { Script }
   DrawText(X+10, Y+18, 'CGI', 2);
   DrawHLine(X+10, X+ICON_W-10, Y+30, CLR_BLACK);
  End;
  FEAT_COMPRESS : Begin { Archive }
   DrawFilledRect(X+15, Y+10, X+ICON_W-15, Y+ICON_H-10, 14);
   DrawRect(X+15, Y+10, X+ICON_W-15, Y+ICON_H-10, CLR_BLACK);
  End;
  FEAT_DOC_DEF  : Begin { Page d'accueil }
   DrawFilledRect(X+10, Y+8, X+ICON_W-10, Y+ICON_H-8, 15);
   DrawRect(X+10, Y+8, X+ICON_W-10, Y+ICON_H-8, CLR_BORDER);
   DrawText(X+14, Y+14, 'index', CLR_ACTION_LINK);
  End;
  FEAT_ENTETES  : Begin { En-tetes HTTP }
   DrawText(X+8, Y+16, 'HTTP', 1);
   DrawHLine(X+8, X+ICON_W-8, Y+26, CLR_BLACK);
   DrawHLine(X+8, X+ICON_W-8, Y+32, CLR_BLACK);
  End;
  FEAT_FILTRAGE : Begin { Filtre }
   DrawFilledRect(X+14, Y+10, X+ICON_W-14, Y+18, 8);
   DrawFilledRect(X+20, Y+20, X+ICON_W-20, Y+28, 8);
   DrawFilledRect(X+26, Y+30, X+ICON_W-26, Y+38, 8);
  End;
  FEAT_JOURNAL  : Begin { Registre }
   DrawFilledRect(X+12, Y+8, X+ICON_W-12, Y+ICON_H-8, 15);
   DrawRect(X+12, Y+8, X+ICON_W-12, Y+ICON_H-8, CLR_BORDER);
   DrawHLine(X+16, X+ICON_W-16, Y+16, 8);
   DrawHLine(X+16, X+ICON_W-16, Y+22, 8);
   DrawHLine(X+16, X+ICON_W-16, Y+28, 8);
   DrawHLine(X+16, X+ICON_W-16, Y+34, 8);
  End;
  FEAT_MAPPAGES : Begin { Mappages }
   DrawText(X+8, Y+16, '>cgi', 2);
   DrawText(X+8, Y+28, '>fcgi', 3);
  End;
  FEAT_CACHE    : Begin { Cache }
   DrawFilledRect(X+10, Y+10, X+ICON_W-10, Y+ICON_H-10, 14);
   DrawRect(X+10, Y+10, X+ICON_W-10, Y+ICON_H-10, CLR_BLACK);
   DrawText(X+16, Y+18, 'cache', 8);
  End;
  FEAT_MODULES  : Begin { Modules }
   DrawFilledRect(X+10, Y+10, X+28, Y+28, 9);
   DrawFilledRect(X+32, Y+10, X+ICON_W-10, Y+28, 3);
   DrawFilledRect(X+10, Y+32, X+28, Y+ICON_H-10, 5);
  End;
  FEAT_ERREURS  : Begin { Pages d'erreur }
   DrawText(X+14, Y+14, '404', 4);
   DrawHLine(X+10, X+ICON_W-10, Y+26, CLR_BLACK);
  End;
  FEAT_SSL      : Begin { SSL }
   DrawText(X+14, Y+16, 'SSL', 2);
   DrawFilledRect(X+20, Y+26, X+ICON_W-20, Y+ICON_H-12, 8);
  End;
  FEAT_REECRITURE: Begin { Reecriture URL }
   DrawText(X+8, Y+16, '/url->', 1);
   DrawText(X+8, Y+28, '/new', 1);
  End;
  FEAT_MIME     : Begin { Types MIME }
   DrawText(X+8, Y+14, 'MIME', 8);
   DrawHLine(X+8, X+ICON_W-8, Y+24, CLR_BLACK);
   DrawText(X+8, Y+28, '.html', 1);
  End;
 End;
End;

{ ================================================================
  BARRE DE MENUS - TODO point 4
  ================================================================ }

Function MenuBarItemX(Idx: Integer): Integer;
Begin
 Case Idx Of
  MENU_FICHIER   : MenuBarItemX := 2;
  MENU_AFFICHAGE : MenuBarItemX := 70;
  MENU_AIDE      : MenuBarItemX := 180;
  Else MenuBarItemX := 0;
 End;
End;

Function MenuBarItemW(Idx: Integer): Integer;
Begin
 Case Idx Of
  MENU_FICHIER   : MenuBarItemW := 66;
  MENU_AFFICHAGE : MenuBarItemW := 108;
  MENU_AIDE      : MenuBarItemW := 50;
  Else MenuBarItemW := 60;
 End;
End;

Function MenuBarItemCaption(Idx: Integer): String;
Begin
 Case Idx Of
  MENU_FICHIER   : MenuBarItemCaption := 'Fichier';
  MENU_AFFICHAGE : MenuBarItemCaption := 'Affichage';
  MENU_AIDE      : MenuBarItemCaption := 'Aide';
  Else MenuBarItemCaption := '';
 End;
End;

Procedure DrawMenuBar;
Var
 I, X, W : Integer;
 Cap      : String;
Begin
 DrawFilledRect(0, 0, ScreenW - 1, MENUBAR_H - 1, CLR_MENUBAR);
 SetTextStyle(DefaultFont, HorizDir, 1);
 For I := 1 To MENU_COUNT Do Begin
  X   := MenuBarItemX(I);
  W   := MenuBarItemW(I);
  Cap := MenuBarItemCaption(I);
  If I = OpenMenuIdx Then Begin
   DrawFilledRect(X, 0, X + W - 1, MENUBAR_H - 1, CLR_MENU_SEL);
   DrawText(X + 4, 4, Cap, CLR_MENU_SEL_TXT);
  End Else If I = HoverMenuIdx Then Begin
   DrawFilledRect(X, 0, X + W - 1, MENUBAR_H - 1, CLR_MENU_SEL);
   DrawText(X + 4, 4, Cap, CLR_MENU_SEL_TXT);
  End Else Begin
   DrawText(X + 4, 4, Cap, CLR_MENUBAR_TXT);
  End;
 End;
End;

Function MenuItemCount(MenuIdx: Integer): Integer;
Begin
 Case MenuIdx Of
  MENU_FICHIER   : MenuItemCount := MF_COUNT;
  MENU_AFFICHAGE : MenuItemCount := MA_COUNT;
  MENU_AIDE      : MenuItemCount := MH_COUNT;
  Else MenuItemCount := 0;
 End;
End;

Function MenuItemCaption(MenuIdx, ItemIdx: Integer): String;
Begin
 MenuItemCaption := '';
 Case MenuIdx Of
  MENU_FICHIER : Case ItemIdx Of  { TODO point 5 }
   MF_CONNECTER   : MenuItemCaption := 'Connecter...';
   MF_DECONNECTER : MenuItemCaption := 'Deconnecter';
   MF_SEP1        : MenuItemCaption := '-';
   MF_QUITTER     : MenuItemCaption := 'Quitter           Alt+F4';
  End;
  MENU_AFFICHAGE : Case ItemIdx Of  { TODO point 6 }
   MA_ACTUALISER  : MenuItemCaption := 'Actualiser              F5';
   MA_FONCTIONS   : MenuItemCaption := 'Panneau de fonctionnalites';
   MA_CONTENU     : MenuItemCaption := 'Panneau de contenu';
   MA_ACTIONS     : MenuItemCaption := 'Panneau d''actions';
  End;
  MENU_AIDE : Case ItemIdx Of  { TODO point 7 }
   MH_DOC     : MenuItemCaption := 'Documentation IIS';
   MH_APROPOS : MenuItemCaption := 'A propos de IIS...';
  End;
 End;
End;

Function IsSeparator(MenuIdx, ItemIdx: Integer): Boolean;
Begin
 IsSeparator := (MenuIdx = MENU_FICHIER) And (ItemIdx = MF_SEP1);
End;

Function MenuDropX(MenuIdx: Integer): Integer;
Begin
 MenuDropX := MenuBarItemX(MenuIdx);
End;

Function MenuDropW(MenuIdx: Integer): Integer;
Begin
 Case MenuIdx Of
  MENU_FICHIER   : MenuDropW := MENU_W_FICHIER;
  MENU_AFFICHAGE : MenuDropW := MENU_W_AFFICHAGE;
  MENU_AIDE      : MenuDropW := MENU_W_AIDE;
  Else MenuDropW := 160;
 End;
End;

Procedure DrawOpenMenu;
Var
 I, X, Y, W, H, Count : Integer;
 Cap                   : String;
Begin
 If OpenMenuIdx = MENU_NONE Then Exit;
 Count := MenuItemCount(OpenMenuIdx);
 If Count = 0 Then Exit;
 X := MenuDropX(OpenMenuIdx);
 W := MenuDropW(OpenMenuIdx);
 H := MENUBAR_H;
 For I := 1 To Count Do Begin
  If IsSeparator(OpenMenuIdx, I) Then Inc(H, 5)
  Else Inc(H, MENU_ITEM_H);
 End;
 DrawFilledRect(X, MENUBAR_H, X + W, MENUBAR_H + H, CLR_MENU_BG);
 DrawRect(X, MENUBAR_H, X + W, MENUBAR_H + H, CLR_BORDER);
 Y := MENUBAR_H + 2;
 SetTextStyle(DefaultFont, HorizDir, 1);
 For I := 1 To Count Do Begin
  Cap := MenuItemCaption(OpenMenuIdx, I);
  If IsSeparator(OpenMenuIdx, I) Then Begin
   DrawHLine(X + 2, X + W - 2, Y + 2, CLR_MENU_SEP);
   Inc(Y, 5);
  End Else Begin
   If I = HoverMenuItemIdx Then Begin
    DrawFilledRect(X + 1, Y, X + W - 1, Y + MENU_ITEM_H - 1, CLR_MENU_SEL);
    DrawText(X + 6, Y + 3, Cap, CLR_MENU_SEL_TXT);
   End Else Begin
    DrawText(X + 6, Y + 3, Cap, CLR_MENU_TXT);
   End;
   Inc(Y, MENU_ITEM_H);
  End;
 End;
End;

Procedure CloseMenu;
Begin
 OpenMenuIdx      := MENU_NONE;
 HoverMenuItemIdx := 0;
End;

{ Retourne l'index de l'item de menu sous (MX, MY), 0 si aucun }
Function GetMenuItemAt(MenuIdx, MX, MY: Integer): Integer;
Var
 I, X, Y, W : Integer;
 Cap         : String;
Begin
 GetMenuItemAt := 0;
 If MenuIdx = MENU_NONE Then Exit;
 X := MenuDropX(MenuIdx);
 W := MenuDropW(MenuIdx);
 If (MX < X) Or (MX > X + W) Then Exit;
 Y := MENUBAR_H + 2;
 For I := 1 To MenuItemCount(MenuIdx) Do Begin
  Cap := MenuItemCaption(MenuIdx, I);
  If IsSeparator(MenuIdx, I) Then Begin
   Inc(Y, 5);
  End Else Begin
   If (MY >= Y) And (MY < Y + MENU_ITEM_H) Then Begin
    GetMenuItemAt := I;
    Exit;
   End;
   Inc(Y, MENU_ITEM_H);
  End;
 End;
End;

{ ================================================================
  MENU CONTEXTUEL - TODO point 10, 12, 14
  ================================================================ }

Procedure CloseContextMenu;
Begin
 CtxMenu.Visible  := False;
 CtxMenu.ItemCount:= 0;
 CtxMenu.CtxType  := CTX_NONE;
End;

Procedure SetCtxItem(Idx: Integer; Cap: String; Enabled: Boolean);
Begin
 If Idx > MAX_CTX_ITEMS Then Exit;
 CtxMenu.Items[Idx].Caption   := Cap;
 CtxMenu.Items[Idx].Enabled   := Enabled;
 CtxMenu.Items[Idx].Separator := Cap = '-';
 CtxMenu.Items[Idx].ShortCut  := '';
End;

{ Ouvre un menu contextuel de type CtxType a la position (X, Y) }
Procedure ShowContextMenu(X, Y, CtxType, DataIdx: Integer);
Begin
 CtxMenu.X          := X;
 CtxMenu.Y          := Y;
 CtxMenu.CtxType    := CtxType;
 CtxMenu.CtxDataIdx := DataIdx;
 CtxMenu.Visible    := True;
 CtxMenu.ItemCount  := 0;
 Case CtxType Of
  CTX_APPPOOLS : Begin  { TODO point 10 }
   CtxMenu.ItemCount := 3;
   SetCtxItem(1, 'Ajouter un pool d''applications...', True);
   SetCtxItem(2, 'Actualiser', True);
   SetCtxItem(3, 'Aide', True);
  End;
  CTX_SITES : Begin  { TODO point 12 }
   CtxMenu.ItemCount := 3;
   SetCtxItem(1, 'Ajouter un site Web...', True);
   SetCtxItem(2, 'Actualiser', True);
   SetCtxItem(3, 'Aide', True);
  End;
  CTX_SITE : Begin  { Menu contextuel d'un site }
   CtxMenu.ItemCount := 6;
   SetCtxItem(1, 'Demarrer', True);
   SetCtxItem(2, 'Arreter', True);
   SetCtxItem(3, 'Redemarrer', True);
   SetCtxItem(4, '-', False);
   SetCtxItem(5, 'Modifier les liaisons...', True);
   SetCtxItem(6, 'Aide', True);
  End;
  CTX_FEATURE : Begin  { TODO point 14 }
   CtxMenu.ItemCount := 2;
   SetCtxItem(1, 'Ouvrir la fonctionnalite', True);
   SetCtxItem(2, 'Aide sur cette fonctionnalite', True);
  End;
 End;
 { Ajuster position si hors ecran }
 If X + CTX_MENU_W > ScreenW Then
  CtxMenu.X := ScreenW - CTX_MENU_W - 2;
 If Y + CtxMenu.ItemCount * CTX_MENU_ITEM_H + 4 > ScreenH Then
  CtxMenu.Y := ScreenH - CtxMenu.ItemCount * CTX_MENU_ITEM_H - 6;
End;

Procedure DrawContextMenu;
Var
 I, X, Y, H : Integer;
 Cap         : String;
Begin
 If Not CtxMenu.Visible Then Exit;
 H := CtxMenu.ItemCount * CTX_MENU_ITEM_H + 4;
 X := CtxMenu.X;
 Y := CtxMenu.Y;
 DrawFilledRect(X, Y, X + CTX_MENU_W, Y + H, CLR_MENU_BG);
 DrawRect(X, Y, X + CTX_MENU_W, Y + H, CLR_BORDER);
 SetTextStyle(DefaultFont, HorizDir, 1);
 For I := 1 To CtxMenu.ItemCount Do Begin
  Cap := CtxMenu.Items[I].Caption;
  If Cap = '-' Then Begin
   DrawHLine(X + 2, X + CTX_MENU_W - 2, Y + 2 + (I - 1) * CTX_MENU_ITEM_H + CTX_MENU_ITEM_H Div 2, CLR_MENU_SEP);
  End Else Begin
   DrawText(X + 6, Y + 2 + (I - 1) * CTX_MENU_ITEM_H + 3, Cap, CLR_MENU_TXT);
  End;
 End;
End;

{ Retourne l'index de l'item du menu contextuel sous (MX, MY) }
Function GetCtxItemAt(MX, MY: Integer): Integer;
Var
 I, X, Y : Integer;
Begin
 GetCtxItemAt := 0;
 If Not CtxMenu.Visible Then Exit;
 X := CtxMenu.X;
 Y := CtxMenu.Y;
 If (MX < X) Or (MX > X + CTX_MENU_W) Then Exit;
 For I := 1 To CtxMenu.ItemCount Do Begin
  If (MY >= Y + 2 + (I - 1) * CTX_MENU_ITEM_H) And
     (MY < Y + 2 + I * CTX_MENU_ITEM_H) Then Begin
   If CtxMenu.Items[I].Caption <> '-' Then
    GetCtxItemAt := I;
   Exit;
  End;
 End;
End;

{ ================================================================
  ARBORESCENCE - TODO point 8
  ================================================================ }

Procedure BuildTree;
Var
 N, I : Integer;
Begin
 TreeNodeCount := 0;
 { Noeud racine - TODO point 8 }
 N := 1;
 TreeNodes[N].Caption  := 'Ordinateur local (' + MachineName + ')';
 TreeNodes[N].NodeType := NODE_ROOT;
 TreeNodes[N].Level    := 0;
 TreeNodes[N].Expanded := RootExpanded;
 TreeNodes[N].DataIdx  := 0;
 TreeNodes[N].Visible  := True;
 TreeNodeCount := 1;
 If RootExpanded Then Begin
  { Pools d'applications - TODO point 9 }
  Inc(TreeNodeCount);
  TreeNodes[TreeNodeCount].Caption  := 'Pools d''applications';
  TreeNodes[TreeNodeCount].NodeType := NODE_APPPOOLS;
  TreeNodes[TreeNodeCount].Level    := 1;
  TreeNodes[TreeNodeCount].Expanded := PoolsExpanded;
  TreeNodes[TreeNodeCount].DataIdx  := 0;
  TreeNodes[TreeNodeCount].Visible  := True;
  If PoolsExpanded Then
   For I := 1 To PoolCount Do Begin
    Inc(TreeNodeCount);
    TreeNodes[TreeNodeCount].Caption  := Pools[I].Name;
    TreeNodes[TreeNodeCount].NodeType := NODE_APPPOOL;
    TreeNodes[TreeNodeCount].Level    := 2;
    TreeNodes[TreeNodeCount].Expanded := False;
    TreeNodes[TreeNodeCount].DataIdx  := I;
    TreeNodes[TreeNodeCount].Visible  := True;
   End;
  { Sites - TODO point 11 }
  Inc(TreeNodeCount);
  TreeNodes[TreeNodeCount].Caption  := 'Sites';
  TreeNodes[TreeNodeCount].NodeType := NODE_SITES;
  TreeNodes[TreeNodeCount].Level    := 1;
  TreeNodes[TreeNodeCount].Expanded := SitesExpanded;
  TreeNodes[TreeNodeCount].DataIdx  := 0;
  TreeNodes[TreeNodeCount].Visible  := True;
  If SitesExpanded Then
   For I := 1 To SiteCount Do Begin
    Inc(TreeNodeCount);
    TreeNodes[TreeNodeCount].Caption  := Sites[I].Name;
    TreeNodes[TreeNodeCount].NodeType := NODE_SITE;
    TreeNodes[TreeNodeCount].Level    := 2;
    TreeNodes[TreeNodeCount].Expanded := False;
    TreeNodes[TreeNodeCount].DataIdx  := I;
    TreeNodes[TreeNodeCount].Visible  := True;
   End;
 End;
End;

Procedure DrawTree;
Var
 I, Y, X, IndX : Integer;
 Cap            : String;
 IsSelected     : Boolean;
 StateColor     : Integer;
Begin
 DrawFilledRect(0, PANEL_Y, TREE_W - 1, SCREEN_H - 1, CLR_TREE_BG);
 DrawVLine(TREE_W, PANEL_Y, SCREEN_H - 1, CLR_BORDER);
 DrawVLine(TREE_W + 1, PANEL_Y, SCREEN_H - 1, CLR_BORDER);
 SetTextStyle(DefaultFont, HorizDir, 1);
 Y := PANEL_Y + 2 - TreeScrollY;
 For I := 1 To TreeNodeCount Do Begin
  If Not TreeNodes[I].Visible Then Continue;
  TreeNodes[I].ScreenY := Y;
  If (Y >= PANEL_Y) And (Y + TREE_ITEM_H <= SCREEN_H) Then Begin
   IndX := 2 + TreeNodes[I].Level * TREE_INDENT;
   IsSelected := (I = SelectedNodeIdx);
   If IsSelected Then Begin
    DrawFilledRect(0, Y, TREE_W - 3, Y + TREE_ITEM_H - 1, CLR_TREE_SEL);
   End;
   { Fleche expand/collapse }
   If TreeNodes[I].NodeType In [NODE_ROOT, NODE_APPPOOLS, NODE_SITES] Then Begin
    If TreeNodes[I].Expanded Then
     DrawText(IndX, Y + 3, '-', CLR_TREE_TXT)
    Else
     DrawText(IndX, Y + 3, '+', CLR_TREE_TXT);
    IndX := IndX + 10;
   End Else
    IndX := IndX + 10;
   { Etat (point vert/rouge) pour pools et sites }
   If TreeNodes[I].NodeType = NODE_APPPOOL Then Begin
    StateColor := CLR_STOPPED;
    If TreeNodes[I].DataIdx > 0 Then
     If Pools[TreeNodes[I].DataIdx].Started Then StateColor := CLR_STARTED;
    DrawFilledRect(IndX, Y + 5, IndX + 6, Y + 11, StateColor);
    IndX := IndX + 10;
   End Else If TreeNodes[I].NodeType = NODE_SITE Then Begin
    StateColor := CLR_STOPPED;
    If TreeNodes[I].DataIdx > 0 Then
     If Sites[TreeNodes[I].DataIdx].Started Then StateColor := CLR_STARTED;
    DrawFilledRect(IndX, Y + 5, IndX + 6, Y + 11, StateColor);
    IndX := IndX + 10;
   End;
   Cap := TreeNodes[I].Caption;
   If Length(Cap) > 20 Then Cap := Copy(Cap, 1, 18) + '..';
   If IsSelected Then
    DrawText(IndX, Y + 3, Cap, CLR_TREE_SEL_TXT)
   Else
    DrawText(IndX, Y + 3, Cap, CLR_TREE_TXT);
  End;
  Inc(Y, TREE_ITEM_H);
 End;
End;

{ Retourne l'index du noeud clique en Y, 0 si aucun }
Function GetTreeNodeAt(MY: Integer): Integer;
Var I : Integer;
Begin
 GetTreeNodeAt := 0;
 For I := 1 To TreeNodeCount Do
  If TreeNodes[I].Visible And (MY >= TreeNodes[I].ScreenY) And
     (MY < TreeNodes[I].ScreenY + TREE_ITEM_H) Then Begin
   GetTreeNodeAt := I;
   Exit;
  End;
End;

{ ================================================================
  GESTION DE LA SELECTION - TODO point 17
  ================================================================ }

Procedure SetSelection(SelType, Index: Integer);
Begin
 CurrentSelection   := SelType;
 SelectedSiteIdx    := 0;
 SelectedPoolIdx    := 0;
 SelectedFeatureIdx := 0;
 Case SelType Of
  SEL_SITE    : SelectedSiteIdx  := Index;
  SEL_APPPOOL : SelectedPoolIdx  := Index;
  SEL_FEATURE : SelectedFeatureIdx := Index;
 End;
 CenterView := VIEW_EMPTY;
 If SelType = SEL_SITE Then CenterView := VIEW_FEATURES;
End;

{ ================================================================
  PANNEAU CENTRAL - GRILLE DES ICONES - TODO point 13 et 15
  ================================================================ }

Procedure DrawFeatureIcons;
Var
 I, Col, Row, IX, IY, TextY : Integer;
 Name                        : String;
Begin
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + CenterH - 1, CLR_CENTER_BG);
 If CenterView <> VIEW_FEATURES Then Exit;
 SetTextStyle(DefaultFont, HorizDir, 1);
 { Titre }
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + 20, CLR_ACTION_HDR);
 DrawText(CenterX + 4, CenterY + 3, 'Fonctionnalites - ' + Sites[SelectedSiteIdx].Name, CLR_ACTION_HDR_T);
 { Grille des icones - TODO point 15 }
 For I := 1 To FEAT_COUNT Do Begin
  Col := (I - 1) Mod ICON_COLS;
  Row := (I - 1) Div ICON_COLS;
  IX  := CenterX + 4 + Col * ICON_CELL_W;
  IY  := CenterY + 24 + Row * ICON_CELL_H;
  { Fond de la cellule }
  If I = SelectedFeatureIdx Then
   DrawFilledRect(IX - 2, IY - 2, IX + ICON_CELL_W - 4, IY + ICON_CELL_H - 4, CLR_ICON_SEL)
  Else If I = HoverIconIdx Then
   DrawFilledRect(IX - 2, IY - 2, IX + ICON_CELL_W - 4, IY + ICON_CELL_H - 4, CLR_ICON_HOVER)
  Else
   DrawFilledRect(IX - 2, IY - 2, IX + ICON_CELL_W - 4, IY + ICON_CELL_H - 4, CLR_CENTER_BG);
  { Icone }
  DrawFeatureIcon(IX, IY, I, CLR_ICON_BG);
  { Label }
  TextY := IY + ICON_H + 2;
  Name  := FeatureNames[I];
  If TextWidth(Name) > ICON_CELL_W - 4 Then
   Name := Copy(Name, 1, 9) + '..';
  DrawTextCentered(IX, IX + ICON_W, TextY, Name, CLR_ICON_TXT);
 End;
End;

{ Retourne l'index de l'icone de fonctionnalite a (MX, MY), 0 si aucun }
Function GetFeatureAt(MX, MY: Integer): Integer;
Var
 I, Col, Row, IX, IY : Integer;
Begin
 GetFeatureAt := 0;
 If CenterView <> VIEW_FEATURES Then Exit;
 For I := 1 To FEAT_COUNT Do Begin
  Col := (I - 1) Mod ICON_COLS;
  Row := (I - 1) Div ICON_COLS;
  IX  := CenterX + 4 + Col * ICON_CELL_W;
  IY  := CenterY + 24 + Row * ICON_CELL_H;
  If (MX >= IX - 2) And (MX < IX + ICON_CELL_W - 4) And
     (MY >= IY - 2) And (MY < IY + ICON_CELL_H - 4) Then Begin
   GetFeatureAt := I;
   Exit;
  End;
 End;
End;

{ ================================================================
  PANNEAU D'ACTIONS - TODO point 16
  ================================================================ }

Procedure ClearActions;
Begin
 ActionItemCount := 0;
End;

Procedure AddActionHdr(Caption: String);
Begin
 If ActionItemCount >= MAX_ACTION_ITEMS Then Exit;
 Inc(ActionItemCount);
 ActionItems[ActionItemCount].Caption := Caption;
 ActionItems[ActionItemCount].IsHdr   := True;
 ActionItems[ActionItemCount].Enabled := True;
End;

Procedure AddActionItem(Caption: String; Enabled: Boolean);
Begin
 If ActionItemCount >= MAX_ACTION_ITEMS Then Exit;
 Inc(ActionItemCount);
 ActionItems[ActionItemCount].Caption := Caption;
 ActionItems[ActionItemCount].IsHdr   := False;
 ActionItems[ActionItemCount].Enabled := Enabled;
End;

Procedure UpdateActionPanel;
Begin
 ClearActions;
 Case CurrentSelection Of
  SEL_ROOT : Begin
   AddActionHdr('Actions');
   AddActionItem('Demarrer', True);
   AddActionItem('Arreter', True);
   AddActionItem('Redemarrer', True);
  End;
  SEL_APPPOOLS : Begin
   AddActionHdr('Pools d''applications');
   AddActionItem('Ajouter un pool...', True);
   AddActionItem('Actualiser', True);
   AddActionHdr('Aide');
   AddActionItem('Aide en ligne', True);
  End;
  SEL_APPPOOL : Begin
   AddActionHdr('Pool');
   AddActionItem('Demarrer le pool', True);
   AddActionItem('Arreter le pool', True);
   AddActionItem('Recycler...', True);
   AddActionItem('Parametres avances...', True);
   AddActionHdr('Aide');
   AddActionItem('Aide en ligne', True);
  End;
  SEL_SITES : Begin
   AddActionHdr('Sites');
   AddActionItem('Ajouter un site Web...', True);
   AddActionItem('Actualiser', True);
   AddActionHdr('Aide');
   AddActionItem('Aide en ligne', True);
  End;
  SEL_SITE : Begin
   AddActionHdr('Gerer le site Web');
   AddActionItem('Demarrer', True);
   AddActionItem('Arreter', True);
   AddActionItem('Redemarrer', True);
   AddActionItem('Parcourir *:80 (http)', True);
   AddActionHdr('Modifier le site Web');
   AddActionItem('Liaisons...', True);
   AddActionItem('Parametres avances...', True);
   AddActionHdr('Aide');
   AddActionItem('Aide en ligne', True);
  End;
  SEL_FEATURE : Begin
   AddActionHdr('Actions');
   AddActionItem('Ouvrir la fonctionnalite', True);
   AddActionHdr('Aide');
   AddActionItem('Aide en ligne', True);
  End;
 End;
End;

Procedure DrawActionPanel;
Var
 I, Y : Integer;
 Cap  : String;
Begin
 DrawFilledRect(ActX, CenterY, ActX + ActW - 1, CenterY + CenterH - 1, CLR_ACTION_BG);
 DrawVLine(ActX - 1, CenterY, CenterY + CenterH - 1, CLR_BORDER);
 DrawVLine(ActX - 2, CenterY, CenterY + CenterH - 1, CLR_BORDER);
 SetTextStyle(DefaultFont, HorizDir, 1);
 DrawFilledRect(ActX, CenterY, ActX + ActW - 1, CenterY + 20, CLR_ACTION_HDR);
 DrawText(ActX + 4, CenterY + 3, 'Actions', CLR_ACTION_HDR_T);
 Y := CenterY + 22 - ActionScrollY;
 For I := 1 To ActionItemCount Do Begin
  ActionItems[I].ScreenY := Y;
  If (Y >= CenterY + 22) And (Y + MENU_ITEM_H <= CenterY + CenterH) Then Begin
   Cap := ActionItems[I].Caption;
   If ActionItems[I].IsHdr Then Begin
    DrawFilledRect(ActX, Y, ActX + ActW - 1, Y + MENU_ITEM_H - 1, CLR_ACTION_HDR);
    If Length(Cap) > 18 Then Cap := Copy(Cap, 1, 16) + '..';
    DrawText(ActX + 4, Y + 3, Cap, CLR_ACTION_HDR_T);
   End Else Begin
    If ActionItems[I].Enabled Then
     DrawText(ActX + 8, Y + 3, Cap, CLR_ACTION_LINK)
    Else
     DrawText(ActX + 8, Y + 3, Cap, CLR_BORDER);
   End;
  End;
  Inc(Y, MENU_ITEM_H);
 End;
End;

{ ================================================================
  DIALOGUES MODAUX - TODO point 18
  ================================================================ }

Procedure ShowDialog(Title, Message: String);
Var
 DX, DY, BX, BY : Integer;
Begin
 DX := (ScreenW - DLG_W) Div 2;
 DY := (ScreenH - DLG_H) Div 2;
 { Fond du dialogue }
 DrawFilledRect(DX, DY, DX + DLG_W, DY + DLG_H, CLR_DLG_BG);
 DrawRect(DX, DY, DX + DLG_W, DY + DLG_H, CLR_BORDER);
 Draw3DRect(DX, DY, DX + DLG_W, DY + DLG_H, True);
 { Barre de titre }
 DrawFilledRect(DX + 1, DY + 1, DX + DLG_W - 1, DY + 22, CLR_DLG_TITLE);
 SetTextStyle(DefaultFont, HorizDir, 1);
 DrawText(DX + 6, DY + 6, Title, CLR_DLG_TITLE_T);
 { Message }
 DrawText(DX + 12, DY + 36, Message, CLR_BLACK);
 { Bouton OK }
 BX := DX + (DLG_W - BTN_W) Div 2;
 BY := DY + DLG_H - BTN_H - 12;
 DrawFilledRect(BX, BY, BX + BTN_W, BY + BTN_H, CLR_BTN_BG);
 Draw3DRect(BX, BY, BX + BTN_W, BY + BTN_H, True);
 DrawTextCentered(BX, BX + BTN_W, BY + 6, 'OK', CLR_BTN_TXT);
 { Attente clic ou Entree }
 Repeat
  PollMouse;
  If KeyPressed Then Begin
   If ReadKey = #13 Then Break;
  End;
  If (MouseBtn And MOUSE_LEFT <> 0) And (LastMouseBtn And MOUSE_LEFT = 0) Then Begin
   If (MouseX >= BX) And (MouseX <= BX + BTN_W) And
      (MouseY >= BY) And (MouseY <= BY + BTN_H) Then Break;
  End;
 Until False;
End;

Function ShowInputDialog(Title, Prompt: String): String;
Var
 DX, DY, FX, FY, BX, BY, BOX, BOY : Integer;
 FieldText                          : TString255;
 FieldCursor                        : Integer;
 Done, OK                           : Boolean;
 Ch                                 : Char;
 CursorVisible                      : Boolean;
 BlinkCtr                           : Integer;
Begin
 DX        := (ScreenW - DLG_W) Div 2;
 DY        := (ScreenH - INPUT_DLG_H) Div 2;
 FX        := DX + 16;
 FY        := DY + 60;
 BX        := DX + (DLG_W - 2 * BTN_W - 16) Div 2;
 BY        := DY + INPUT_DLG_H - BTN_H - 12;
 BOX       := BX + BTN_W + 16;
 BOY       := BY;
 FieldText := '';
 FieldCursor:= 0;
 Done      := False;
 OK        := False;
 CursorVisible := True;
 BlinkCtr  := 0;
 Repeat
  { Fond }
  DrawFilledRect(DX, DY, DX + DLG_W, DY + INPUT_DLG_H, CLR_DLG_BG);
  DrawRect(DX, DY, DX + DLG_W, DY + INPUT_DLG_H, CLR_BORDER);
  Draw3DRect(DX, DY, DX + DLG_W, DY + INPUT_DLG_H, True);
  DrawFilledRect(DX + 1, DY + 1, DX + DLG_W - 1, DY + 22, CLR_DLG_TITLE);
  SetTextStyle(DefaultFont, HorizDir, 1);
  DrawText(DX + 6, DY + 6, Title, CLR_DLG_TITLE_T);
  DrawText(DX + 12, DY + 34, Prompt, CLR_BLACK);
  { Champ de saisie }
  DrawFilledRect(FX, FY, FX + INPUT_FIELD_W, FY + INPUT_FIELD_H, CLR_INPUT_BG);
  DrawRect(FX, FY, FX + INPUT_FIELD_W, FY + INPUT_FIELD_H, CLR_INPUT_BORDER);
  DrawText(FX + 2, FY + 3, FieldText, CLR_BLACK);
  { Curseur clignotant }
  Inc(BlinkCtr);
  If BlinkCtr Mod 20 = 0 Then CursorVisible := Not CursorVisible;
  If CursorVisible Then Begin
   DrawVLine(FX + 2 + TextWidth(FieldText), FY + 2, FY + INPUT_FIELD_H - 2, CLR_BLACK);
  End;
  { Boutons }
  DrawFilledRect(BX, BY, BX + BTN_W, BY + BTN_H, CLR_BTN_BG);
  Draw3DRect(BX, BY, BX + BTN_W, BY + BTN_H, True);
  DrawTextCentered(BX, BX + BTN_W, BY + 6, 'OK', CLR_BTN_TXT);
  DrawFilledRect(BOX, BOY, BOX + BTN_W, BOY + BTN_H, CLR_BTN_BG);
  Draw3DRect(BOX, BOY, BOX + BTN_W, BOY + BTN_H, True);
  DrawTextCentered(BOX, BOX + BTN_W, BOY + 6, 'Annuler', CLR_BTN_TXT);
  { Saisie clavier }
  If KeyPressed Then Begin
   Ch := ReadKey;
   If Ch = #13 Then Begin OK := True; Done := True; End
   Else If Ch = #27 Then Begin OK := False; Done := True; End
   Else If Ch = #8 Then Begin
    If Length(FieldText) > 0 Then
     Delete(FieldText, Length(FieldText), 1);
   End Else If (Ch >= ' ') And (Length(FieldText) < 80) Then Begin
    FieldText := FieldText + Ch;
   End;
  End;
  { Souris }
  PollMouse;
  If (MouseBtn And MOUSE_LEFT <> 0) And (LastMouseBtn And MOUSE_LEFT = 0) Then Begin
   If (MouseX >= BX) And (MouseX <= BX + BTN_W) And
      (MouseY >= BY) And (MouseY <= BY + BTN_H) Then Begin
    OK := True; Done := True;
   End;
   If (MouseX >= BOX) And (MouseX <= BOX + BTN_W) And
      (MouseY >= BOY) And (MouseY <= BOY + BTN_H) Then Begin
    OK := False; Done := True;
   End;
  End;
 Until Done;
 If OK Then ShowInputDialog := FieldText
 Else ShowInputDialog := '';
End;

{ ================================================================
  PERSISTANCE DE CONFIGURATION - TODO point 19
  ================================================================ }

Procedure SaveConfig;
Var
 F  : Text;
 I  : Integer;
Begin
 Assign(F, 'IIS.CFG');
 Rewrite(F);
 WriteLn(F, 'MachineName=' + MachineName);
 WriteLn(F, 'SiteCount=' + IntToStr(SiteCount));
 For I := 1 To SiteCount Do Begin
  WriteLn(F, 'Site' + IntToStr(I) + '.Name=' + Sites[I].Name);
  WriteLn(F, 'Site' + IntToStr(I) + '.Port=' + IntToStr(Sites[I].Port));
  WriteLn(F, 'Site' + IntToStr(I) + '.PhysPath=' + Sites[I].PhysPath);
  If Sites[I].Started Then
   WriteLn(F, 'Site' + IntToStr(I) + '.Started=1')
  Else
   WriteLn(F, 'Site' + IntToStr(I) + '.Started=0');
 End;
 WriteLn(F, 'PoolCount=' + IntToStr(PoolCount));
 For I := 1 To PoolCount Do Begin
  WriteLn(F, 'Pool' + IntToStr(I) + '.Name=' + Pools[I].Name);
  WriteLn(F, 'Pool' + IntToStr(I) + '.Runtime=' + Pools[I].Runtime);
  If Pools[I].Started Then
   WriteLn(F, 'Pool' + IntToStr(I) + '.Started=1')
  Else
   WriteLn(F, 'Pool' + IntToStr(I) + '.Started=0');
 End;
 WriteLn(F, 'CGICount=' + IntToStr(CGICount));
 For I := 1 To CGICount Do Begin
  WriteLn(F, 'CGI' + IntToStr(I) + '.Ext=' + CGIEntries[I].Extension);
  WriteLn(F, 'CGI' + IntToStr(I) + '.Path=' + CGIEntries[I].ExePath);
  If CGIEntries[I].Enabled Then
   WriteLn(F, 'CGI' + IntToStr(I) + '.Enabled=1')
  Else
   WriteLn(F, 'CGI' + IntToStr(I) + '.Enabled=0');
 End;
 WriteLn(F, 'FastCGICount=' + IntToStr(FastCGICount));
 For I := 1 To FastCGICount Do Begin
  WriteLn(F, 'FCGI' + IntToStr(I) + '.Path=' + FastCGIEntries[I].ExePath);
  WriteLn(F, 'FCGI' + IntToStr(I) + '.Procs=' + IntToStr(FastCGIEntries[I].Processes));
 End;
 Close(F);
End;

Procedure LoadConfig;
Var
 F    : Text;
 Line : String;
 Pos1 : Integer;
 Key  : String;
 Val  : String;
 N    : Integer;
Begin
 {$I-}
 Assign(F, 'IIS.CFG');
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not EOF(F) Do Begin
  ReadLn(F, Line);
  Line := TrimStr(Line);
  If Length(Line) = 0 Then Continue;
  Pos1 := 1;
  While (Pos1 <= Length(Line)) And (Line[Pos1] <> '=') Do Inc(Pos1);
  If Pos1 > Length(Line) Then Continue;
  Key := TrimStr(Copy(Line, 1, Pos1 - 1));
  Val := TrimStr(Copy(Line, Pos1 + 1, Length(Line)));
  { Traitement simple des cles connues }
  If Key = 'MachineName' Then MachineName := Val
  Else If Key = 'SiteCount' Then SiteCount := StrToInt(Val)
  Else If Key = 'PoolCount' Then PoolCount := StrToInt(Val)
  Else If Key = 'CGICount' Then CGICount := StrToInt(Val)
  Else If Key = 'FastCGICount' Then FastCGICount := StrToInt(Val)
  Else Begin
   { Sites }
   For N := 1 To MAX_SITES Do Begin
    If Key = 'Site' + IntToStr(N) + '.Name' Then Sites[N].Name := Val;
    If Key = 'Site' + IntToStr(N) + '.Port' Then Sites[N].Port := StrToInt(Val);
    If Key = 'Site' + IntToStr(N) + '.PhysPath' Then Sites[N].PhysPath := Val;
    If Key = 'Site' + IntToStr(N) + '.Started' Then Sites[N].Started := Val = '1';
   End;
   { Pools }
   For N := 1 To MAX_POOLS Do Begin
    If Key = 'Pool' + IntToStr(N) + '.Name' Then Pools[N].Name := Val;
    If Key = 'Pool' + IntToStr(N) + '.Runtime' Then Pools[N].Runtime := Val;
    If Key = 'Pool' + IntToStr(N) + '.Started' Then Pools[N].Started := Val = '1';
   End;
   { CGI }
   For N := 1 To MAX_CGI Do Begin
    If Key = 'CGI' + IntToStr(N) + '.Ext' Then CGIEntries[N].Extension := Val;
    If Key = 'CGI' + IntToStr(N) + '.Path' Then CGIEntries[N].ExePath := Val;
    If Key = 'CGI' + IntToStr(N) + '.Enabled' Then CGIEntries[N].Enabled := Val = '1';
   End;
   { FastCGI }
   For N := 1 To MAX_FASTCGI Do Begin
    If Key = 'FCGI' + IntToStr(N) + '.Path' Then FastCGIEntries[N].ExePath := Val;
    If Key = 'FCGI' + IntToStr(N) + '.Procs' Then FastCGIEntries[N].Processes := StrToInt(Val);
   End;
  End;
 End;
 Close(F);
End;

{ ================================================================
  SUPPORT CGI - TODO point 20
  ================================================================ }

{ Validation du chemin d'execution pour eviter les injections de commandes
  Retourne True si le chemin ne contient pas de caracteres dangereux. }
Function IsValidExePath(Const Path: String): Boolean;
Var I : Integer;
Begin
 IsValidExePath := False;
 If Length(Path) = 0 Then Exit;
 { Refuser les caracteres d'injection shell }
 For I := 1 To Length(Path) Do
  If Path[I] In [';', '|', '&', '`', '$', '<', '>', '(', ')', '{', '}', '*', '?', '#', '!', '^'] Then
   Exit;
 { Refuser les sequences de traversee de repertoire }
 If (Pos('..', Path) > 0) Then Exit;
 IsValidExePath := True;
End;

Procedure AddCGIEntry(Extension, ExePath: String);
Begin
 If CGICount >= MAX_CGI Then Begin
  ShowDialog('CGI', 'Nombre maximum d''entrees CGI atteint.'); Exit;
 End;
 If Not IsValidExePath(ExePath) Then Begin
  ShowDialog('CGI', 'Chemin de programme invalide.'); Exit;
 End;
 Inc(CGICount);
 CGIEntries[CGICount].Extension := Extension;
 CGIEntries[CGICount].ExePath   := ExePath;
 CGIEntries[CGICount].Enabled   := True;
 SaveConfig;
End;

Procedure ExecCGI(ExePath: String);
Var
 CmdLine : String;
Begin
 If ExePath = '' Then Exit;
 If Not IsValidExePath(ExePath) Then Begin
  ShowDialog('Erreur CGI', 'Chemin de programme invalide.'); Exit;
 End;
 {$IFDEF FPC}
 { Free Pascal : ExecuteProcess ou fpSystem }
 CmdLine := ExePath;
 {$IFDEF UNIX}
  fpSystem(CmdLine);
 {$ELSE}
  ExecuteProcess(ExePath, '');
 {$ENDIF}
 {$ELSE}
 { Turbo Pascal : Exec via COMSPEC }
 SwapVectors;
 Exec(GetEnv('COMSPEC'), '/C ' + ExePath);
 SwapVectors;
 {$ENDIF}
End;

Procedure DrawCGIPanel;
Var
 I, Y : Integer;
Begin
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + CenterH - 1, CLR_CENTER_BG);
 SetTextStyle(DefaultFont, HorizDir, 1);
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + 20, CLR_ACTION_HDR);
 DrawText(CenterX + 4, CenterY + 3, 'Restrictions ISAPI et CGI', CLR_ACTION_HDR_T);
 { En-tetes colonnes }
 Y := CenterY + 24;
 DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H, CLR_BORDER);
 DrawText(CenterX + 4, Y + 3, 'Extension', CLR_WHITE);
 DrawText(CenterX + 100, Y + 3, 'Chemin', CLR_WHITE);
 DrawText(CenterX + CenterW - 80, Y + 3, 'Autorise', CLR_WHITE);
 Y := Y + MENU_ITEM_H + 2;
 For I := 1 To CGICount Do Begin
  If I Mod 2 = 0 Then
   DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H - 1, 15)
  Else
   DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H - 1, CLR_CENTER_BG);
  DrawText(CenterX + 4, Y + 3, CGIEntries[I].Extension, CLR_BLACK);
  DrawText(CenterX + 100, Y + 3, Copy(CGIEntries[I].ExePath, 1, 40), CLR_BLACK);
  If CGIEntries[I].Enabled Then
   DrawText(CenterX + CenterW - 76, Y + 3, 'Oui', CLR_STARTED)
  Else
   DrawText(CenterX + CenterW - 76, Y + 3, 'Non', CLR_STOPPED);
  Y := Y + MENU_ITEM_H;
  If Y > CenterY + CenterH - 30 Then Break;
 End;
 { Bouton Ajouter }
 DrawFilledRect(CenterX + 4, CenterY + CenterH - 28, CenterX + 4 + 80, CenterY + CenterH - 8, CLR_BTN_BG);
 Draw3DRect(CenterX + 4, CenterY + CenterH - 28, CenterX + 84, CenterY + CenterH - 8, True);
 DrawText(CenterX + 12, CenterY + CenterH - 22, 'Ajouter...', CLR_BTN_TXT);
End;

{ ================================================================
  SUPPORT FASTCGI - TODO point 21
  ================================================================ }

Procedure AddFastCGIEntry(ExePath: String; Processes: Integer);
Begin
 If FastCGICount >= MAX_FASTCGI Then Begin
  ShowDialog('FastCGI', 'Nombre maximum d''entrees FastCGI atteint.'); Exit;
 End;
 If Not IsValidExePath(ExePath) Then Begin
  ShowDialog('FastCGI', 'Chemin de programme invalide.'); Exit;
 End;
 Inc(FastCGICount);
 FastCGIEntries[FastCGICount].ExePath   := ExePath;
 FastCGIEntries[FastCGICount].Processes := Processes;
 FastCGIEntries[FastCGICount].Enabled   := True;
 SaveConfig;
End;

Procedure LaunchFastCGIProcess(ExePath: String; Processes: Integer);
Var
 I : Integer;
Begin
 If ExePath = '' Then Exit;
 If Not IsValidExePath(ExePath) Then Begin
  ShowDialog('Erreur FastCGI', 'Chemin de programme invalide.'); Exit;
 End;
 For I := 1 To Processes Do Begin
  {$IFDEF FPC}
  {$IFDEF UNIX}
   fpSystem(ExePath + ' &');
  {$ELSE}
   ExecuteProcess(ExePath, '');
  {$ENDIF}
  {$ELSE}
  SwapVectors;
  Exec(ExePath, '');
  SwapVectors;
  {$ENDIF}
 End;
End;

Procedure DrawFastCGIPanel;
Var
 I, Y : Integer;
Begin
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + CenterH - 1, CLR_CENTER_BG);
 SetTextStyle(DefaultFont, HorizDir, 1);
 DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + 20, CLR_ACTION_HDR);
 DrawText(CenterX + 4, CenterY + 3, 'Mappages de gestionnaire FastCGI', CLR_ACTION_HDR_T);
 Y := CenterY + 24;
 DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H, CLR_BORDER);
 DrawText(CenterX + 4, Y + 3, 'Chemin du programme', CLR_WHITE);
 DrawText(CenterX + CenterW - 90, Y + 3, 'Processus', CLR_WHITE);
 Y := Y + MENU_ITEM_H + 2;
 For I := 1 To FastCGICount Do Begin
  If I Mod 2 = 0 Then
   DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H - 1, 15)
  Else
   DrawFilledRect(CenterX, Y, CenterX + CenterW - 1, Y + MENU_ITEM_H - 1, CLR_CENTER_BG);
  DrawText(CenterX + 4, Y + 3, Copy(FastCGIEntries[I].ExePath, 1, 50), CLR_BLACK);
  DrawText(CenterX + CenterW - 80, Y + 3, IntToStr(FastCGIEntries[I].Processes), CLR_BLACK);
  Y := Y + MENU_ITEM_H;
  If Y > CenterY + CenterH - 30 Then Break;
 End;
 DrawFilledRect(CenterX + 4, CenterY + CenterH - 28, CenterX + 84, CenterY + CenterH - 8, CLR_BTN_BG);
 Draw3DRect(CenterX + 4, CenterY + CenterH - 28, CenterX + 84, CenterY + CenterH - 8, True);
 DrawText(CenterX + 12, CenterY + CenterH - 22, 'Ajouter...', CLR_BTN_TXT);
End;

{ ================================================================
  DOUBLE-BUFFER - TODO point 23
  ================================================================ }

Procedure InitBuffer;
Begin
 BufferInited := False;
 BufferSize   := ImageSize(0, 0, ScreenW - 1, ScreenH - 1);
 If BufferSize > 0 Then Begin
  GetMem(ScreenBuffer, BufferSize);
  If ScreenBuffer <> Nil Then BufferInited := True;
 End;
End;

Procedure SaveBuffer;
Begin
 If BufferInited And (ScreenBuffer <> Nil) Then
  GetImage(0, 0, ScreenW - 1, ScreenH - 1, ScreenBuffer^);
End;

Procedure RestoreBuffer;
Begin
 If BufferInited And (ScreenBuffer <> Nil) Then
  PutImage(0, 0, ScreenBuffer^, CopyPut);
End;

{ ================================================================
  DESSIN COMPLET DE L'INTERFACE
  ================================================================ }

Procedure DrawMainLayout;
Begin
 { Fond general }
 DrawFilledRect(0, 0, ScreenW - 1, ScreenH - 1, CLR_BG);
 { Barre de menus - TODO point 4 }
 DrawMenuBar;
 { Panneau gauche - TODO point 8 }
 DrawTree;
 { Separateurs verticaux }
 DrawVLine(TREE_W, PANEL_Y, ScreenH - 1, CLR_BORDER);
 DrawVLine(TREE_W + 1, PANEL_Y, ScreenH - 1, CLR_BORDER);
 DrawVLine(ActX - 1, PANEL_Y, ScreenH - 1, CLR_BORDER);
 DrawVLine(ActX - 2, PANEL_Y, ScreenH - 1, CLR_BORDER);
 { Panneau central - TODO point 13 et 15 }
 Case CenterView Of
  VIEW_FEATURES : DrawFeatureIcons;
  VIEW_CGI      : DrawCGIPanel;
  VIEW_FASTCGI  : DrawFastCGIPanel;
  Else Begin
   DrawFilledRect(CenterX, CenterY, CenterX + CenterW - 1, CenterY + CenterH - 1, CLR_CENTER_BG);
   SetTextStyle(DefaultFont, HorizDir, 1);
   If CurrentSelection = SEL_NONE Then
    DrawTextCentered(CenterX, CenterX + CenterW, CenterY + CenterH Div 2, 'Selectionnez un element dans l''arborescence', CLR_BORDER);
  End;
 End;
 { Panneau d'actions - TODO point 16 }
 UpdateActionPanel;
 DrawActionPanel;
 { Menu deroulant par-dessus - TODO point 4 }
 If OpenMenuIdx <> MENU_NONE Then
  DrawOpenMenu;
 { Menu contextuel - TODO point 10, 12, 14 }
 If CtxMenu.Visible Then
  DrawContextMenu;
End;

{ ================================================================
  ACTIONS MENUS ET TREE - gestionnaires
  ================================================================ }

Procedure ExecuteMenuAction(MenuIdx, ItemIdx: Integer);
Var
 NewName, NewPath, NewPort, NewRuntime : String;
Begin
 Case MenuIdx Of
  MENU_FICHIER : Begin
   Case ItemIdx Of
    MF_CONNECTER   : ShowDialog('Connexion', 'Deja connecte a : ' + MachineName);
    MF_DECONNECTER : ShowDialog('Deconnexion', 'Deconnecte de : ' + MachineName);
    MF_QUITTER     : AppRunning := False;
   End;
  End;
  MENU_AFFICHAGE : Begin
   Case ItemIdx Of
    MA_ACTUALISER : Begin
     BuildTree;
     DrawMainLayout;
    End;
    MA_FONCTIONS : Begin
     If SelectedSiteIdx > 0 Then CenterView := VIEW_FEATURES;
    End;
    MA_CONTENU : Begin
     CenterView := VIEW_EMPTY;
    End;
    MA_ACTIONS : Begin
     DrawActionPanel;
    End;
   End;
  End;
  MENU_AIDE : Begin
   Case ItemIdx Of
    MH_DOC     : ShowDialog('Documentation IIS', 'Documentation IIS disponible sur https://learn.microsoft.com/iis');
    MH_APROPOS : ShowDialog('A propos de IIS', 'Clone IIS v1.00'#13'Ecrit en Turbo Pascal / Free Pascal'#13'(c) 2026 gladir.com');
   End;
  End;
 End;
End;

Procedure ExecuteContextAction(CtxType, ItemIdx, DataIdx: Integer);
Var
 NewName, NewPath, NewPort, NewRuntime : String;
Begin
 Case CtxType Of
  CTX_APPPOOLS : Begin  { TODO point 10 }
   Case ItemIdx Of
    1 : Begin { Ajouter un pool }
     NewName    := ShowInputDialog('Nouveau pool', 'Nom du pool d''applications :');
     If NewName <> '' Then Begin
      NewRuntime := ShowInputDialog('Nouveau pool', 'Version .NET (ex: v4.0) :');
      If PoolCount < MAX_POOLS Then Begin
       Inc(PoolCount);
       Pools[PoolCount].Name    := NewName;
       Pools[PoolCount].Runtime := NewRuntime;
       Pools[PoolCount].Started := True;
       BuildTree;
       SaveConfig;
      End;
     End;
    End;
    2 : Begin BuildTree; DrawMainLayout; End; { Actualiser }
    3 : ShowDialog('Aide', 'Aide sur les Pools d''applications IIS.');
   End;
  End;
  CTX_SITES : Begin  { TODO point 12 }
   Case ItemIdx Of
    1 : Begin { Ajouter un site Web }
     NewName := ShowInputDialog('Nouveau site', 'Nom du site :');
     If NewName <> '' Then Begin
      NewPath := ShowInputDialog('Nouveau site', 'Chemin physique :');
      NewPort := ShowInputDialog('Nouveau site', 'Port (ex: 80) :');
      If SiteCount < MAX_SITES Then Begin
       Inc(SiteCount);
       Sites[SiteCount].Name     := NewName;
       Sites[SiteCount].PhysPath := NewPath;
       Sites[SiteCount].Port     := StrToInt(NewPort);
       Sites[SiteCount].Started  := True;
       BuildTree;
       SaveConfig;
      End;
     End;
    End;
    2 : Begin BuildTree; DrawMainLayout; End;
    3 : ShowDialog('Aide', 'Aide sur les Sites IIS.');
   End;
  End;
  CTX_SITE : Begin
   If (DataIdx >= 1) And (DataIdx <= SiteCount) Then Begin
    Case ItemIdx Of
     1 : Begin Sites[DataIdx].Started := True;  BuildTree; SaveConfig; End; { Demarrer }
     2 : Begin Sites[DataIdx].Started := False; BuildTree; SaveConfig; End; { Arreter }
     3 : Begin  { Redemarrer }
      Sites[DataIdx].Started := False;
      Sites[DataIdx].Started := True;
      BuildTree; SaveConfig;
     End;
     5 : Begin { Modifier liaisons }
      NewPort := ShowInputDialog('Liaisons du site', 'Nouveau port :');
      If NewPort <> '' Then Begin
       Sites[DataIdx].Port := StrToInt(NewPort);
       SaveConfig;
      End;
     End;
     6 : ShowDialog('Aide', 'Aide sur les sites Web IIS.');
    End;
   End;
  End;
  CTX_FEATURE : Begin  { TODO point 14 }
   Case ItemIdx Of
    1 : Begin { Ouvrir la fonctionnalite }
     Case DataIdx Of
      FEAT_CGI      : CenterView := VIEW_CGI;
      FEAT_MAPPAGES : CenterView := VIEW_FASTCGI;
      Else ShowDialog('Fonctionnalite', 'Fonctionnalite : ' + FeatureNames[DataIdx]);
     End;
    End;
    2 : ShowDialog('Aide', 'Aide : ' + FeatureNames[DataIdx]);
   End;
  End;
 End;
End;

Procedure HandleTreeClick(MX, MY: Integer; IsRight: Boolean);
Var
 NodeIdx  : Integer;
 NodeType : Integer;
 DataIdx  : Integer;
Begin
 NodeIdx := GetTreeNodeAt(MY);
 If NodeIdx = 0 Then Exit;
 NodeType := TreeNodes[NodeIdx].NodeType;
 DataIdx  := TreeNodes[NodeIdx].DataIdx;
 SelectedNodeIdx := NodeIdx;
 If Not IsRight Then Begin
  { Clic gauche : expand/collapse ou selection }
  Case NodeType Of
   NODE_ROOT : Begin
    RootExpanded := Not RootExpanded;
    SetSelection(SEL_ROOT, 0);
   End;
   NODE_APPPOOLS : Begin
    PoolsExpanded := Not PoolsExpanded;
    SetSelection(SEL_APPPOOLS, 0);
   End;
   NODE_SITES : Begin
    SitesExpanded := Not SitesExpanded;
    SetSelection(SEL_SITES, 0);
   End;
   NODE_APPPOOL : SetSelection(SEL_APPPOOL, DataIdx);
   NODE_SITE    : SetSelection(SEL_SITE, DataIdx);
  End;
  BuildTree;
 End Else Begin
  { Clic droit : menu contextuel - TODO point 10, 12 }
  Case NodeType Of
   NODE_APPPOOLS : ShowContextMenu(MX, MY, CTX_APPPOOLS, 0);
   NODE_SITES    : ShowContextMenu(MX, MY, CTX_SITES, 0);
   NODE_SITE     : ShowContextMenu(MX, MY, CTX_SITE, DataIdx);
   NODE_APPPOOL  : ShowContextMenu(MX, MY, CTX_APPPOOLS, DataIdx);
  End;
 End;
End;

{ ================================================================
  INITIALISATION DE L'APPLICATION
  ================================================================ }

Procedure InitFeatureNames;
Begin
 FeatureNames[FEAT_EDITEUR]  := 'Editeur config';
 FeatureNames[FEAT_AUTH]     := 'Authentification';
 FeatureNames[FEAT_CGI]      := 'CGI';
 FeatureNames[FEAT_COMPRESS] := 'Compression';
 FeatureNames[FEAT_DOC_DEF]  := 'Doc. par defaut';
 FeatureNames[FEAT_ENTETES]  := 'Entetes HTTP';
 FeatureNames[FEAT_FILTRAGE] := 'Filtrage';
 FeatureNames[FEAT_JOURNAL]  := 'Journalisation';
 FeatureNames[FEAT_MAPPAGES] := 'Mappages gest.';
 FeatureNames[FEAT_CACHE]    := 'Mise en cache';
 FeatureNames[FEAT_MODULES]  := 'Modules';
 FeatureNames[FEAT_ERREURS]  := 'Pages d''erreurs';
 FeatureNames[FEAT_SSL]      := 'Parametres SSL';
 FeatureNames[FEAT_REECRITURE]:= 'Reecriture URL';
 FeatureNames[FEAT_MIME]     := 'Types MIME';
End;

Procedure InitDefaultData;
Begin
 MachineName := 'LOCALHOST';
 { Pool par defaut }
 PoolCount := 1;
 Pools[1].Name    := 'DefaultAppPool';
 Pools[1].Started := True;
 Pools[1].Runtime := 'v4.0';
 { Site par defaut }
 SiteCount := 1;
 Sites[1].Name     := 'Default Web Site';
 Sites[1].PhysPath := 'C:\inetpub\wwwroot';
 Sites[1].Port     := 80;
 Sites[1].Started  := True;
 { CGI par defaut }
 CGICount := 2;
 CGIEntries[1].Extension := '.pl';
 CGIEntries[1].ExePath   := 'C:\Perl\bin\perl.exe';
 CGIEntries[1].Enabled   := True;
 CGIEntries[2].Extension := '.py';
 CGIEntries[2].ExePath   := 'C:\Python\python.exe';
 CGIEntries[2].Enabled   := True;
 { FastCGI par defaut }
 FastCGICount := 1;
 FastCGIEntries[1].ExePath   := 'C:\PHP\php-cgi.exe';
 FastCGIEntries[1].Processes := 4;
 FastCGIEntries[1].Enabled   := True;
End;

Procedure InitializeApp;
Begin
 { Gestion souris - TODO point 1 }
 MouseAvailable   := MouseDriverFound;
 MouseX           := 0;
 MouseY           := 0;
 MouseBtn         := 0;
 LastMouseX       := 0;
 LastMouseY       := 0;
 LastMouseBtn     := 0;
 DblClickCtr      := 0;
 LastClickX       := 0;
 LastClickY       := 0;
 WasDblClick      := False;
 { Etat des menus }
 OpenMenuIdx      := MENU_NONE;
 HoverMenuIdx     := MENU_NONE;
 HoverMenuItemIdx := 0;
 { Arborescence - TODO point 8 }
 RootExpanded     := True;
 PoolsExpanded    := True;
 SitesExpanded    := True;
 SelectedNodeIdx  := 1;
 TreeScrollY      := 0;
 { Selection }
 CurrentSelection    := SEL_NONE;
 SelectedSiteIdx     := 0;
 SelectedPoolIdx     := 0;
 SelectedFeatureIdx  := 0;
 CenterView          := VIEW_EMPTY;
 HoverIconIdx        := 0;
 { Menu contextuel }
 CloseContextMenu;
 { Actions }
 ActionItemCount := 0;
 ActionScrollY   := 0;
 { App }
 AppRunning      := True;
 BufferInited    := False;
 ScreenBuffer    := Nil;
 InitFeatureNames;
 InitDefaultData;
 LoadConfig;
 BuildTree;
 If MouseAvailable Then ShowMouse;
 InitBuffer;
End;

{ ================================================================
  NETTOYAGE ET SORTIE - TODO point 25
  ================================================================ }

Procedure Shutdown;
Begin
 If MouseAvailable Then HideMouse;
 If BufferInited And (ScreenBuffer <> Nil) Then Begin
  FreeMem(ScreenBuffer, BufferSize);
  ScreenBuffer := Nil;
 End;
 CloseGraph;
 Halt(0);
End;

{ ================================================================
  BOUCLE EVENEMENTIELLE PRINCIPALE - TODO point 22
  ================================================================ }

Procedure RunEventLoop;
Var
 Ch            : Char;
 MenuItemIdx   : Integer;
 FeatIdx       : Integer;
 CtxItemIdx    : Integer;
 HMIdx         : Integer;
 HMItemIdx     : Integer;
 I             : Integer;
 NewCGIExt     : TString50;
 NewCGIPath    : TString255;
 NewFCGIPath   : TString255;
 NewFCGIProc   : TString20;
Begin
 DrawMainLayout;
 Repeat
  PollMouse;
  { Mise a jour survol icone fonctionnalite - TODO point 15 }
  If CenterView = VIEW_FEATURES Then Begin
   FeatIdx := GetFeatureAt(MouseX, MouseY);
   If FeatIdx <> HoverIconIdx Then Begin
    HoverIconIdx := FeatIdx;
    DrawFeatureIcons;
    If CtxMenu.Visible Then DrawContextMenu;
   End;
  End;
  { Mise a jour survol menu - TODO point 4 }
  If (MouseY < MENUBAR_H) Then Begin
   HMIdx := 0;
   For I := 1 To MENU_COUNT Do Begin
    If (MouseX >= MenuBarItemX(I)) And (MouseX < MenuBarItemX(I) + MenuBarItemW(I)) Then Begin
     HMIdx := I; Break;
    End;
   End;
   If HMIdx <> HoverMenuIdx Then Begin
    HoverMenuIdx := HMIdx;
    DrawMenuBar;
    If OpenMenuIdx <> MENU_NONE Then Begin
     If HMIdx <> 0 Then Begin
      OpenMenuIdx := HMIdx;
      HoverMenuItemIdx := 0;
     End;
     DrawOpenMenu;
    End;
   End;
  End Else If OpenMenuIdx <> MENU_NONE Then Begin
   { Survol dans menu deroulant }
   HMItemIdx := GetMenuItemAt(OpenMenuIdx, MouseX, MouseY);
   If HMItemIdx <> HoverMenuItemIdx Then Begin
    HoverMenuItemIdx := HMItemIdx;
    DrawOpenMenu;
   End;
  End;
  { Clic gauche - TODO point 22 }
  If (MouseBtn And MOUSE_LEFT <> 0) And (LastMouseBtn And MOUSE_LEFT = 0) Then Begin
   { Menu contextuel ouvert ? Traiter d'abord }
   If CtxMenu.Visible Then Begin
    CtxItemIdx := GetCtxItemAt(MouseX, MouseY);
    { Sauvegarder type et index avant fermeture }
    HMIdx  := CtxMenu.CtxType;
    I      := CtxMenu.CtxDataIdx;
    CloseContextMenu;
    If CtxItemIdx > 0 Then
     ExecuteContextAction(HMIdx, CtxItemIdx, I);
    DrawMainLayout;
   End Else If MouseY < MENUBAR_H Then Begin
    { Clic sur la barre de menus }
    HMIdx := 0;
    For I := 1 To MENU_COUNT Do Begin
     If (MouseX >= MenuBarItemX(I)) And (MouseX < MenuBarItemX(I) + MenuBarItemW(I)) Then Begin
      HMIdx := I; Break;
     End;
    End;
    If HMIdx <> 0 Then Begin
     If OpenMenuIdx = HMIdx Then Begin
      CloseMenu; DrawMenuBar;
     End Else Begin
      OpenMenuIdx := HMIdx;
      HoverMenuItemIdx := 0;
      DrawMenuBar; DrawOpenMenu;
     End;
    End Else If OpenMenuIdx <> MENU_NONE Then Begin
     CloseMenu; DrawMainLayout;
    End;
   End Else If (OpenMenuIdx <> MENU_NONE) Then Begin
    { Clic dans un menu deroulant ouvert }
    MenuItemIdx := GetMenuItemAt(OpenMenuIdx, MouseX, MouseY);
    If MenuItemIdx > 0 Then Begin
     I := OpenMenuIdx;
     CloseMenu;
     DrawMainLayout;
     ExecuteMenuAction(I, MenuItemIdx);
     DrawMainLayout;
    End Else Begin
     CloseMenu; DrawMainLayout;
    End;
   End Else If MouseX < TREE_W Then Begin
    { Clic dans l'arborescence }
    HandleTreeClick(MouseX, MouseY, False);
    DrawMainLayout;
   End Else If (MouseX >= CenterX) And (MouseX < ActX) Then Begin
    { Clic dans le panneau central }
    If CenterView = VIEW_FEATURES Then Begin
     FeatIdx := GetFeatureAt(MouseX, MouseY);
     If FeatIdx > 0 Then Begin
      SelectedFeatureIdx := FeatIdx;
      SetSelection(SEL_FEATURE, FeatIdx);
      DrawMainLayout;
     End;
    End Else If CenterView = VIEW_CGI Then Begin
     { Bouton Ajouter CGI }
     If (MouseX >= CenterX + 4) And (MouseX <= CenterX + 84) And
        (MouseY >= CenterY + CenterH - 28) And (MouseY <= CenterY + CenterH - 8) Then Begin
      NewCGIExt  := ShowInputDialog('Ajouter CGI', 'Extension (ex: .pl) :');
      If NewCGIExt <> '' Then Begin
       NewCGIPath := ShowInputDialog('Ajouter CGI', 'Chemin du programme :');
       AddCGIEntry(NewCGIExt, NewCGIPath);
       DrawMainLayout;
      End;
     End;
    End Else If CenterView = VIEW_FASTCGI Then Begin
     { Bouton Ajouter FastCGI }
     If (MouseX >= CenterX + 4) And (MouseX <= CenterX + 84) And
        (MouseY >= CenterY + CenterH - 28) And (MouseY <= CenterY + CenterH - 8) Then Begin
      NewFCGIPath := ShowInputDialog('Ajouter FastCGI', 'Chemin du programme :');
      If NewFCGIPath <> '' Then Begin
       NewFCGIProc := ShowInputDialog('Ajouter FastCGI', 'Nombre de processus :');
       AddFastCGIEntry(NewFCGIPath, StrToInt(NewFCGIProc));
       DrawMainLayout;
      End;
     End;
    End;
   End;
  End;
  { Double-clic gauche - TODO point 15 et 22 }
  If WasDblClick Then Begin
   If (MouseX >= CenterX) And (MouseX < ActX) And (CenterView = VIEW_FEATURES) Then Begin
    FeatIdx := GetFeatureAt(MouseX, MouseY);
    If FeatIdx > 0 Then Begin
     ExecuteContextAction(CTX_FEATURE, 1, FeatIdx);
     DrawMainLayout;
    End;
   End;
  End;
  { Clic droit - TODO point 10, 12, 14 }
  If (MouseBtn And MOUSE_RIGHT <> 0) And (LastMouseBtn And MOUSE_RIGHT = 0) Then Begin
   CloseMenu;
   If MouseX < TREE_W Then Begin
    HandleTreeClick(MouseX, MouseY, True);
    DrawMainLayout;
   End Else If (MouseX >= CenterX) And (MouseX < ActX) And (CenterView = VIEW_FEATURES) Then Begin
    FeatIdx := GetFeatureAt(MouseX, MouseY);
    If FeatIdx > 0 Then Begin
     SelectedFeatureIdx := FeatIdx;
     ShowContextMenu(MouseX, MouseY, CTX_FEATURE, FeatIdx);
     DrawFeatureIcons;
     DrawContextMenu;
    End;
   End;
  End;
  { Clavier - TODO point 22 }
  If KeyPressed Then Begin
   Ch := ReadKey;
   If OpenMenuIdx <> MENU_NONE Then Begin
    Case Ch Of
     #27 : Begin CloseMenu; DrawMainLayout; End; { Echap }
     #13 : Begin { Entree = valider item survole }
      If HoverMenuItemIdx > 0 Then Begin
       I := OpenMenuIdx;
       MenuItemIdx := HoverMenuItemIdx;
       CloseMenu; DrawMainLayout;
       ExecuteMenuAction(I, MenuItemIdx);
       DrawMainLayout;
      End;
     End;
    End;
   End Else Begin
    Case Ch Of
     #27 : Begin  { Echap : ferme contexte ou quitte }
      If CtxMenu.Visible Then Begin
       CloseContextMenu; DrawMainLayout;
      End;
     End;
     #0 : Begin  { Touche etendue }
      Ch := ReadKey;
      Case Ch Of
       #59 : Begin { F1 - Aide }
        ShowDialog('Aide IIS', 'Aide IIS v1.00 - F1 pour aide contextuelle');
        DrawMainLayout;
       End;
       #68 : Begin { F10 - ouvrir menu Fichier }
        OpenMenuIdx := MENU_FICHIER;
        HoverMenuItemIdx := 0;
        DrawMenuBar; DrawOpenMenu;
       End;
      End;
     End;
    End;
   End;
  End;
 Until Not AppRunning;
End;

{ ================================================================
  PROGRAMME PRINCIPAL
  ================================================================ }

BEGIN
 InitializeGraphics;
 InitializeApp;
 RunEventLoop;
 Shutdown;
END.