{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Application de navigateur Web graphique

  TODO: Liste des 25 points a implementer pour le navigateur Web graphique

  1.  DONE: Implementer la barre d'URL avec champ de saisie de texte editable
  2.  DONE: Creer le bouton "Precedent" pour naviguer vers la page precedente dans l'historique
  3.  DONE: Creer le bouton "Suivant" pour naviguer vers la page suivante dans l'historique
  4.  DONE: Creer le bouton "Actualiser" pour recharger la page courante
  5.  DONE: Creer le bouton "Favori" pour ajouter/gerer les marque-pages
  6.  DONE: Implementer la gestion de l'historique de navigation (pile de pages visitees)
  7.  DONE: Implementer le support de la souris pour Turbo Pascal via INT 33h
  8.  TODO: Implementer le support de la souris pour Free Pascal via PtcMouse
  9.  TODO: Creer le parseur HTML supportant toutes les balises HTML (HTML 1.0 a HTML5)
  10. TODO: Implementer le rendu des balises de structure HTML (html, head, body, div, span)
  11. TODO: Implementer le rendu des balises de texte (p, h1-h6, strong, em, pre, code)
  12. TODO: Implementer le rendu des listes (ul, ol, li, dl, dt, dd)
  13. TODO: Implementer le rendu des tableaux (table, tr, td, th, thead, tbody)
  14. TODO: Implementer le rendu des formulaires (form, input, button, select, textarea)
  15. TODO: Implementer la detection et le rendu des liens hypertexte (balise <a href>)
  16. TODO: Implementer la navigation par clic sur les liens URL dans les pages
  17. TODO: Creer l'interpreteur JavaScript pour le support des scripts cote client
  18. TODO: Implementer le DOM (Document Object Model) pour la manipulation JavaScript
  19. TODO: Creer le parseur CSS pour le support des feuilles de style
  20. TODO: Implementer l'application des styles CSS aux elements HTML (cascade et heritage)
  21. TODO: Implementer le decodeur et l'affichage des images BMP
  22. TODO: Implementer le decodeur et l'affichage des images GIF (y compris anime)
  23. TODO: Implementer le decodeur et l'affichage des images JPEG
  24. TODO: Implementer le decodeur et l'affichage des images PNG
  25. TODO: Implementer le parseur et le rendu des fichiers SVG (Scalable Vector Graphics)
}

Program BROWSER;

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 { Constantes pour la barre d'URL }
 URL_BAR_X = 5;
 URL_BAR_Y = 5;
 URL_BAR_WIDTH = 500;
 URL_BAR_HEIGHT = 20;
 URL_MAX_LENGTH = 255;

 { Constantes pour le bouton Precedent }
 BACK_BTN_X = 515;
 BACK_BTN_Y = 5;
 BACK_BTN_WIDTH = 30;
 BACK_BTN_HEIGHT = 20;

 { Constantes pour le bouton Suivant }
 FORWARD_BTN_X = 550;
 FORWARD_BTN_Y = 5;
 FORWARD_BTN_WIDTH = 30;
 FORWARD_BTN_HEIGHT = 20;

 { Constantes pour le bouton Actualiser }
 REFRESH_BTN_X = 585;
 REFRESH_BTN_Y = 5;
 REFRESH_BTN_WIDTH = 30;
 REFRESH_BTN_HEIGHT = 20;

 { Constantes pour le bouton Favori }
 FAVORITE_BTN_X = 620;
 FAVORITE_BTN_Y = 5;
 FAVORITE_BTN_WIDTH = 30;
 FAVORITE_BTN_HEIGHT = 20;

 { Constantes pour les favoris }
 MAX_FAVORITES = 100;

 { Constantes pour l'historique de navigation }
 MAX_HISTORY = 100;

 { Couleurs de l'interface }
 COLOR_URL_BAR_BG = 15;       { Blanc }
 COLOR_URL_BAR_BORDER = 0;    { Noir }
 COLOR_URL_BAR_TEXT = 0;      { Noir }
 COLOR_URL_BAR_CURSOR = 0;    { Noir }
 COLOR_BTN_BG = 7;            { Gris clair }
 COLOR_BTN_BORDER = 0;        { Noir }
 COLOR_BTN_TEXT = 0;          { Noir }
 COLOR_BTN_DISABLED = 8;      { Gris fonce }

 { Constantes pour les boutons de la souris }
 MOUSE_LEFT_BUTTON = 1;
 MOUSE_RIGHT_BUTTON = 2;
 MOUSE_MIDDLE_BUTTON = 4;

Var
 { Variables globales pour la barre d'URL }
 CurrentURL: String;
 URLCursorPos: Integer;
 URLBarFocused: Boolean;

 { Variables pour le bouton Precedent }
 BackButtonEnabled: Boolean;

 { Variables pour le bouton Suivant }
 ForwardButtonEnabled: Boolean;

 { Variables pour le bouton Actualiser }
 RefreshButtonEnabled: Boolean;

 { Variables pour le bouton Favori et les marque-pages }
 FavoriteButtonEnabled: Boolean;
 Favorites: Array[1..MAX_FAVORITES] Of String;
 FavoriteCount: Integer;

 { Variables pour l'historique de navigation }
 History: Array[1..MAX_HISTORY] Of String;
 HistoryCount: Integer;
 HistoryIndex: Integer;

 { Variables pour le support de la souris }
 MouseAvailable: Boolean;
 MouseX, MouseY: LongInt;
 MouseButton: LongInt;
 LastMouseButton: LongInt;

{ Declarations forward pour l'historique de navigation }
Procedure GoBack; Forward;
Procedure GoForward; Forward;

{ Procedure pour dessiner la barre d'URL }
Procedure DrawURLBar;
Var
 TextX, TextY: Integer;
 DisplayURL: String;
Begin
 { Dessiner le fond de la barre d'URL }
 SetFillStyle(SolidFill, COLOR_URL_BAR_BG);
 Bar(URL_BAR_X, URL_BAR_Y, URL_BAR_X + URL_BAR_WIDTH, URL_BAR_Y + URL_BAR_HEIGHT);

 { Dessiner la bordure de la barre d'URL }
 SetColor(COLOR_URL_BAR_BORDER);
 Rectangle(URL_BAR_X, URL_BAR_Y, URL_BAR_X + URL_BAR_WIDTH, URL_BAR_Y + URL_BAR_HEIGHT);

 { Afficher l'URL courante }
 SetColor(COLOR_URL_BAR_TEXT);
 TextX := URL_BAR_X + 5;
 TextY := URL_BAR_Y + 5;

 { Tronquer l'URL si elle est trop longue pour l'affichage }
 DisplayURL := CurrentURL;
 If Length(DisplayURL) > 60 Then
  DisplayURL := Copy(DisplayURL, 1, 60) + '...';

 OutTextXY(TextX, TextY, DisplayURL);

 { Dessiner le curseur si la barre a le focus }
 If URLBarFocused Then Begin
  SetColor(COLOR_URL_BAR_CURSOR);
  Line(TextX + (URLCursorPos * 8), URL_BAR_Y + 3,
       TextX + (URLCursorPos * 8), URL_BAR_Y + URL_BAR_HEIGHT - 3);
 End;
End;

{ Procedure pour dessiner le bouton Precedent }
Procedure DrawBackButton;
Var
 CenterX, CenterY: Integer;
 ArrowColor: Integer;
Begin
 { Dessiner le fond du bouton }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(BACK_BTN_X, BACK_BTN_Y, BACK_BTN_X + BACK_BTN_WIDTH, BACK_BTN_Y + BACK_BTN_HEIGHT);

 { Dessiner la bordure du bouton }
 SetColor(COLOR_BTN_BORDER);
 Rectangle(BACK_BTN_X, BACK_BTN_Y, BACK_BTN_X + BACK_BTN_WIDTH, BACK_BTN_Y + BACK_BTN_HEIGHT);

 { Dessiner la fleche vers la gauche (symbole <) }
 CenterX := BACK_BTN_X + (BACK_BTN_WIDTH Div 2);
 CenterY := BACK_BTN_Y + (BACK_BTN_HEIGHT Div 2);

 { Couleur de la fleche selon l'etat du bouton }
 If BackButtonEnabled Then
  ArrowColor := COLOR_BTN_TEXT
 Else
  ArrowColor := COLOR_BTN_DISABLED;

 SetColor(ArrowColor);
 { Dessiner une fleche vers la gauche }
 Line(CenterX + 5, CenterY - 5, CenterX - 5, CenterY);
 Line(CenterX - 5, CenterY, CenterX + 5, CenterY + 5);
 Line(CenterX - 5, CenterY, CenterX + 8, CenterY);
End;

{ Fonction pour verifier si un clic est dans le bouton Precedent }
Function IsClickInBackButton(X, Y: Integer): Boolean;
Begin
 IsClickInBackButton := (X >= BACK_BTN_X) And (X <= BACK_BTN_X + BACK_BTN_WIDTH) And
                        (Y >= BACK_BTN_Y) And (Y <= BACK_BTN_Y + BACK_BTN_HEIGHT);
End;

{ Procedure pour gerer le clic sur le bouton Precedent }
Procedure HandleBackButtonClick;
Begin
 If Not BackButtonEnabled Then Exit;
 GoBack;
End;

{ Procedure pour initialiser le bouton Precedent }
Procedure InitBackButton;
Begin
 BackButtonEnabled := False; { Desactive par defaut car pas d'historique }
End;

{ Procedure pour activer/desactiver le bouton Precedent }
Procedure SetBackButtonEnabled(Enabled: Boolean);
Begin
 BackButtonEnabled := Enabled;
 DrawBackButton;
End;

{ Procedure pour dessiner le bouton Suivant }
Procedure DrawForwardButton;
Var
 CenterX, CenterY: Integer;
 ArrowColor: Integer;
Begin
 { Dessiner le fond du bouton }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(FORWARD_BTN_X, FORWARD_BTN_Y, FORWARD_BTN_X + FORWARD_BTN_WIDTH, FORWARD_BTN_Y + FORWARD_BTN_HEIGHT);

 { Dessiner la bordure du bouton }
 SetColor(COLOR_BTN_BORDER);
 Rectangle(FORWARD_BTN_X, FORWARD_BTN_Y, FORWARD_BTN_X + FORWARD_BTN_WIDTH, FORWARD_BTN_Y + FORWARD_BTN_HEIGHT);

 { Dessiner la fleche vers la droite (symbole >) }
 CenterX := FORWARD_BTN_X + (FORWARD_BTN_WIDTH Div 2);
 CenterY := FORWARD_BTN_Y + (FORWARD_BTN_HEIGHT Div 2);

 { Couleur de la fleche selon l'etat du bouton }
 If ForwardButtonEnabled Then
  ArrowColor := COLOR_BTN_TEXT
 Else
  ArrowColor := COLOR_BTN_DISABLED;

 SetColor(ArrowColor);
 { Dessiner une fleche vers la droite }
 Line(CenterX - 5, CenterY - 5, CenterX + 5, CenterY);
 Line(CenterX + 5, CenterY, CenterX - 5, CenterY + 5);
 Line(CenterX + 5, CenterY, CenterX - 8, CenterY);
End;

{ Fonction pour verifier si un clic est dans le bouton Suivant }
Function IsClickInForwardButton(X, Y: Integer): Boolean;
Begin
 IsClickInForwardButton := (X >= FORWARD_BTN_X) And (X <= FORWARD_BTN_X + FORWARD_BTN_WIDTH) And
                           (Y >= FORWARD_BTN_Y) And (Y <= FORWARD_BTN_Y + FORWARD_BTN_HEIGHT);
End;

{ Procedure pour gerer le clic sur le bouton Suivant }
Procedure HandleForwardButtonClick;
Begin
 If Not ForwardButtonEnabled Then Exit;
 GoForward;
End;

{ Procedure pour initialiser le bouton Suivant }
Procedure InitForwardButton;
Begin
 ForwardButtonEnabled := False; { Desactive par defaut car pas d'historique }
End;

{ Procedure pour activer/desactiver le bouton Suivant }
Procedure SetForwardButtonEnabled(Enabled: Boolean);
Begin
 ForwardButtonEnabled := Enabled;
 DrawForwardButton;
End;

{ Procedure pour dessiner le bouton Actualiser }
Procedure DrawRefreshButton;
Var
 CenterX, CenterY: Integer;
 IconColor: Integer;
Begin
 { Dessiner le fond du bouton }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(REFRESH_BTN_X, REFRESH_BTN_Y, REFRESH_BTN_X + REFRESH_BTN_WIDTH, REFRESH_BTN_Y + REFRESH_BTN_HEIGHT);

 { Dessiner la bordure du bouton }
 SetColor(COLOR_BTN_BORDER);
 Rectangle(REFRESH_BTN_X, REFRESH_BTN_Y, REFRESH_BTN_X + REFRESH_BTN_WIDTH, REFRESH_BTN_Y + REFRESH_BTN_HEIGHT);

 { Dessiner le symbole de rafraichissement (fleche circulaire) }
 CenterX := REFRESH_BTN_X + (REFRESH_BTN_WIDTH Div 2);
 CenterY := REFRESH_BTN_Y + (REFRESH_BTN_HEIGHT Div 2);

 { Couleur de l'icone selon l'etat du bouton }
 If RefreshButtonEnabled Then
  IconColor := COLOR_BTN_TEXT
 Else
  IconColor := COLOR_BTN_DISABLED;

 SetColor(IconColor);
 { Dessiner un cercle partiel avec une fleche pour symboliser le rafraichissement }
 Arc(CenterX, CenterY, 45, 315, 6);
 { Dessiner la pointe de la fleche }
 Line(CenterX + 4, CenterY - 6, CenterX + 6, CenterY - 2);
 Line(CenterX + 4, CenterY - 6, CenterX + 8, CenterY - 6);
End;

{ Fonction pour verifier si un clic est dans le bouton Actualiser }
Function IsClickInRefreshButton(X, Y: Integer): Boolean;
Begin
 IsClickInRefreshButton := (X >= REFRESH_BTN_X) And (X <= REFRESH_BTN_X + REFRESH_BTN_WIDTH) And
                           (Y >= REFRESH_BTN_Y) And (Y <= REFRESH_BTN_Y + REFRESH_BTN_HEIGHT);
End;

{ Procedure pour gerer le clic sur le bouton Actualiser }
Procedure HandleRefreshButtonClick;
Begin
 If Not RefreshButtonEnabled Then Exit;
 { Recharger la page courante }
 { La navigation sera implementee quand le chargement de pages sera disponible }
End;

{ Procedure pour initialiser le bouton Actualiser }
Procedure InitRefreshButton;
Begin
 RefreshButtonEnabled := True; { Active par defaut car on peut toujours rafraichir }
End;

{ Procedure pour activer/desactiver le bouton Actualiser }
Procedure SetRefreshButtonEnabled(Enabled: Boolean);
Begin
 RefreshButtonEnabled := Enabled;
 DrawRefreshButton;
End;

{ Fonction pour verifier si l'URL courante est dans les favoris }
Function IsFavorite(URL: String): Boolean;
Var
 I: Integer;
Begin
 IsFavorite := False;
 For I := 1 To FavoriteCount Do Begin
  If Favorites[I] = URL Then Begin
   IsFavorite := True;
   Exit;
  End;
 End;
End;

{ Procedure pour ajouter l'URL courante aux favoris }
Procedure AddFavorite(URL: String);
Begin
 If FavoriteCount < MAX_FAVORITES Then Begin
  If Not IsFavorite(URL) Then Begin
   Inc(FavoriteCount);
   Favorites[FavoriteCount] := URL;
  End;
 End;
End;

{ Procedure pour retirer l'URL courante des favoris }
Procedure RemoveFavorite(URL: String);
Var
 I, J: Integer;
Begin
 For I := 1 To FavoriteCount Do Begin
  If Favorites[I] = URL Then Begin
   { Decaler les elements suivants }
   For J := I To FavoriteCount - 1 Do
    Favorites[J] := Favorites[J + 1];
   Dec(FavoriteCount);
   Exit;
  End;
 End;
End;

{ Procedure pour dessiner le bouton Favori }
Procedure DrawFavoriteButton;
Var
 CenterX, CenterY: Integer;
 IconColor: Integer;
 IsFav: Boolean;
Begin
 { Dessiner le fond du bouton }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(FAVORITE_BTN_X, FAVORITE_BTN_Y, FAVORITE_BTN_X + FAVORITE_BTN_WIDTH, FAVORITE_BTN_Y + FAVORITE_BTN_HEIGHT);

 { Dessiner la bordure du bouton }
 SetColor(COLOR_BTN_BORDER);
 Rectangle(FAVORITE_BTN_X, FAVORITE_BTN_Y, FAVORITE_BTN_X + FAVORITE_BTN_WIDTH, FAVORITE_BTN_Y + FAVORITE_BTN_HEIGHT);

 { Dessiner le symbole etoile pour les favoris }
 CenterX := FAVORITE_BTN_X + (FAVORITE_BTN_WIDTH Div 2);
 CenterY := FAVORITE_BTN_Y + (FAVORITE_BTN_HEIGHT Div 2);

 { Couleur de l'icone selon l'etat du bouton et si l'URL est en favori }
 IsFav := IsFavorite(CurrentURL);
 If FavoriteButtonEnabled Then Begin
  If IsFav Then
   IconColor := 14 { Jaune si favori }
  Else
   IconColor := COLOR_BTN_TEXT;
 End
  Else
  IconColor := COLOR_BTN_DISABLED;

 SetColor(IconColor);
 { Dessiner une etoile a 5 branches }
 { Branche superieure }
 Line(CenterX, CenterY - 7, CenterX - 2, CenterY - 2);
 Line(CenterX, CenterY - 7, CenterX + 2, CenterY - 2);
 { Branche gauche superieure }
 Line(CenterX - 7, CenterY - 2, CenterX - 2, CenterY - 2);
 Line(CenterX - 7, CenterY - 2, CenterX - 3, CenterY + 2);
 { Branche droite superieure }
 Line(CenterX + 7, CenterY - 2, CenterX + 2, CenterY - 2);
 Line(CenterX + 7, CenterY - 2, CenterX + 3, CenterY + 2);
 { Branche gauche inferieure }
 Line(CenterX - 5, CenterY + 6, CenterX - 3, CenterY + 2);
 Line(CenterX - 5, CenterY + 6, CenterX, CenterY + 3);
 { Branche droite inferieure }
 Line(CenterX + 5, CenterY + 6, CenterX + 3, CenterY + 2);
 Line(CenterX + 5, CenterY + 6, CenterX, CenterY + 3);
End;

{ Fonction pour verifier si un clic est dans le bouton Favori }
Function IsClickInFavoriteButton(X, Y: Integer): Boolean;
Begin
 IsClickInFavoriteButton := (X >= FAVORITE_BTN_X) And (X <= FAVORITE_BTN_X + FAVORITE_BTN_WIDTH) And
                            (Y >= FAVORITE_BTN_Y) And (Y <= FAVORITE_BTN_Y + FAVORITE_BTN_HEIGHT);
End;

{ Procedure pour gerer le clic sur le bouton Favori }
Procedure HandleFavoriteButtonClick;
Begin
 If Not FavoriteButtonEnabled Then Exit;
 { Basculer l'etat du favori pour l'URL courante }
 If IsFavorite(CurrentURL) Then
  RemoveFavorite(CurrentURL)
 Else
  AddFavorite(CurrentURL);
 DrawFavoriteButton;
End;

{ Procedure pour initialiser le bouton Favori }
Procedure InitFavoriteButton;
Begin
 FavoriteButtonEnabled := True; { Active par defaut }
 FavoriteCount := 0;
End;

{ Procedure pour activer/desactiver le bouton Favori }
Procedure SetFavoriteButtonEnabled(Enabled: Boolean);
Begin
 FavoriteButtonEnabled := Enabled;
 DrawFavoriteButton;
End;

{ Fonction pour verifier si on peut revenir en arriere dans l'historique }
Function CanGoBack: Boolean;
Begin
 CanGoBack := HistoryIndex > 1;
End;

{ Fonction pour verifier si on peut avancer dans l'historique }
Function CanGoForward: Boolean;
Begin
 CanGoForward := HistoryIndex < HistoryCount;
End;

{ Procedure pour mettre a jour l'etat des boutons de navigation }
Procedure UpdateNavigationButtons;
Begin
 BackButtonEnabled := CanGoBack;
 ForwardButtonEnabled := CanGoForward;
 DrawBackButton;
 DrawForwardButton;
End;

{ Procedure pour naviguer vers une nouvelle URL et l'ajouter a l'historique }
Procedure NavigateTo(URL: String);
Var
 I: Integer;
Begin
 { Si on navigue depuis un point intermediaire de l'historique, }
 { on supprime tout ce qui est apres la position actuelle }
 If HistoryIndex < HistoryCount Then Begin
  HistoryCount := HistoryIndex;
 End;

 { Ajouter la nouvelle URL a l'historique si l'historique n'est pas plein }
 If HistoryCount < MAX_HISTORY Then Begin
  Inc(HistoryCount);
  History[HistoryCount] := URL;
  HistoryIndex := HistoryCount;
 End
  Else
 Begin
  { Si l'historique est plein, decaler tout vers le haut et ajouter a la fin }
  For I := 1 To MAX_HISTORY - 1 Do
   History[I] := History[I + 1];
  History[MAX_HISTORY] := URL;
  HistoryIndex := MAX_HISTORY;
 End;

 { Mettre a jour l'URL courante }
 CurrentURL := URL;
 URLCursorPos := Length(CurrentURL);
 DrawURLBar;
 DrawFavoriteButton;
 UpdateNavigationButtons;
End;

{ Procedure pour aller a la page precedente }
Procedure GoBack;
Begin
 If CanGoBack Then Begin
  Dec(HistoryIndex);
  CurrentURL := History[HistoryIndex];
  URLCursorPos := Length(CurrentURL);
  DrawURLBar;
  DrawFavoriteButton;
  UpdateNavigationButtons;
 End;
End;

{ Procedure pour aller a la page suivante }
Procedure GoForward;
Begin
 If CanGoForward Then Begin
  Inc(HistoryIndex);
  CurrentURL := History[HistoryIndex];
  URLCursorPos := Length(CurrentURL);
  DrawURLBar;
  DrawFavoriteButton;
  UpdateNavigationButtons;
 End;
End;

{ Procedure pour initialiser l'historique }
Procedure InitHistory;
Begin
 HistoryCount := 0;
 HistoryIndex := 0;
End;

{ Fonction pour obtenir le nombre d'elements dans l'historique }
Function GetHistoryCount: Integer;
Begin
 GetHistoryCount := HistoryCount;
End;

{ Fonction pour obtenir la position actuelle dans l'historique }
Function GetHistoryIndex: Integer;
Begin
 GetHistoryIndex := HistoryIndex;
End;

{ Procedure pour verifier si un clic est dans la barre d'URL }
Function IsClickInURLBar(X, Y: Integer): Boolean;
Begin
 IsClickInURLBar := (X >= URL_BAR_X) And (X <= URL_BAR_X + URL_BAR_WIDTH) And
                    (Y >= URL_BAR_Y) And (Y <= URL_BAR_Y + URL_BAR_HEIGHT);
End;

{ Procedure pour gerer la saisie de texte dans la barre d'URL }
Procedure HandleURLInput(Key: Char);
Begin
 If Not URLBarFocused Then Exit;

 Case Ord(Key) Of
  8: Begin { Backspace }
   If (URLCursorPos > 0) And (Length(CurrentURL) > 0) Then Begin
    Delete(CurrentURL, URLCursorPos, 1);
    Dec(URLCursorPos);
   End;
  End;
  13: Begin { Enter - Valider l'URL }
   URLBarFocused := False;
   { Ici on pourrait appeler une procedure de navigation }
  End;
  27: Begin { Escape - Annuler la saisie }
   URLBarFocused := False;
  End;
  Else Begin { Caractere normal }
   If (Key >= #32) And (Key <= #126) Then Begin
    If Length(CurrentURL) < URL_MAX_LENGTH Then Begin
     Inc(URLCursorPos);
     Insert(Key, CurrentURL, URLCursorPos);
    End;
   End;
  End;
 End;
 DrawURLBar;
End;

{ Procedure pour gerer les touches speciales (fleches) dans la barre d'URL }
Procedure HandleURLSpecialKey(ScanCode: Byte);
Begin
 If Not URLBarFocused Then Exit;

 Case ScanCode Of
  75: Begin { Fleche gauche }
   If URLCursorPos > 0 Then Dec(URLCursorPos);
  End;
  77: Begin { Fleche droite }
   If URLCursorPos < Length(CurrentURL) Then Inc(URLCursorPos);
  End;
  71: Begin { Home }
   URLCursorPos := 0;
  End;
  79: Begin { End }
   URLCursorPos := Length(CurrentURL);
  End;
  83: Begin { Delete }
   If URLCursorPos < Length(CurrentURL) Then
    Delete(CurrentURL, URLCursorPos + 1, 1);
  End;
 End;
 DrawURLBar;
End;

{ Procedure pour initialiser la barre d'URL }
Procedure InitURLBar;
Begin
 CurrentURL := 'https://';
 URLCursorPos := Length(CurrentURL);
 URLBarFocused := False;
End;

{ Procedure pour definir une nouvelle URL }
Procedure SetURL(NewURL: String);
Begin
 CurrentURL := NewURL;
 URLCursorPos := Length(CurrentURL);
 DrawURLBar;
End;

{ Fonction pour obtenir l'URL courante }
Function GetURL: String;
Begin
 GetURL := CurrentURL;
End;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

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
  X := Regs.CX;
  Y := Regs.DX;
 End;

 { Procedure pour definir les limites horizontales du curseur souris }
 Procedure SetMouseHorizontalBounds(MinX, MaxX: Integer);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0007;
  Regs.CX := MinX;
  Regs.DX := MaxX;
  Intr($33, Regs);
 End;

 { Procedure pour definir les limites verticales du curseur souris }
 Procedure SetMouseVerticalBounds(MinY, MaxY: Integer);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0008;
  Regs.CX := MinY;
  Regs.DX := MaxY;
  Intr($33, Regs);
 End;

 { Procedure pour positionner le curseur souris }
 Procedure SetMousePosition(X, Y: Integer);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0004;
  Regs.CX := X;
  Regs.DX := Y;
  Intr($33, Regs);
 End;

 { Fonction pour obtenir le nombre de clics du bouton gauche }
 Function GetMouseLeftClicks: Integer;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0005;
  Regs.BX := 0; { Bouton gauche }
  Intr($33, Regs);
  GetMouseLeftClicks := Regs.BX;
 End;

 { Fonction pour obtenir le nombre de clics du bouton droit }
 Function GetMouseRightClicks: Integer;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0005;
  Regs.BX := 1; { Bouton droit }
  Intr($33, Regs);
  GetMouseRightClicks := Regs.BX;
 End;

 { Fonction pour obtenir le deplacement de la souris depuis le dernier appel }
 Procedure GetMouseMotion(Var DeltaX, DeltaY: Integer);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $000B;
  Intr($33, Regs);
  DeltaX := Regs.CX;
  DeltaY := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { Pas d'implémentation pour Free Pascal }
 End;

 Procedure HideMouse;
 Begin
  { Pas d'implémentation pour Free Pascal }
 End;

 Procedure SetMouseHorizontalBounds(MinX, MaxX: Integer);
 Begin
  { Pas d'implementation pour Free Pascal - utilise PtcMouse }
 End;

 Procedure SetMouseVerticalBounds(MinY, MaxY: Integer);
 Begin
  { Pas d'implementation pour Free Pascal - utilise PtcMouse }
 End;

 Procedure SetMousePosition(X, Y: Integer);
 Begin
  { Pas d'implementation pour Free Pascal - utilise PtcMouse }
 End;

 Function GetMouseLeftClicks: Integer;
 Begin
  GetMouseLeftClicks := 0;
 End;

 Function GetMouseRightClicks: Integer;
 Begin
  GetMouseRightClicks := 0;
 End;

 Procedure GetMouseMotion(Var DeltaX, DeltaY: Integer);
 Begin
  DeltaX := 0;
  DeltaY := 0;
 End;
{$ENDIF}

{ Procedure pour initialiser la souris }
Procedure InitMouse;
Begin
 MouseAvailable := MouseDriverFound;
 If MouseAvailable Then Begin
  ShowMouse;
  SetMouseHorizontalBounds(0, GetMaxX);
  SetMouseVerticalBounds(0, GetMaxY);
  SetMousePosition(GetMaxX Div 2, GetMaxY Div 2);
  MouseX := GetMaxX Div 2;
  MouseY := GetMaxY Div 2;
  MouseButton := 0;
  LastMouseButton := 0;
 End;
End;

{ Procedure pour gerer les clics de souris sur l'interface }
Procedure HandleMouseClick(X, Y: Integer);
Begin
 { Verifier si le clic est dans la barre d'URL }
 If IsClickInURLBar(X, Y) Then Begin
  URLBarFocused := True;
  { Calculer la position du curseur dans l'URL }
  URLCursorPos := (X - URL_BAR_X - 5) Div 8;
  If URLCursorPos > Length(CurrentURL) Then
   URLCursorPos := Length(CurrentURL);
  If URLCursorPos < 0 Then
   URLCursorPos := 0;
  DrawURLBar;
 End
  Else
 Begin
  URLBarFocused := False;
  DrawURLBar;
 End;

 { Verifier si le clic est dans le bouton Precedent }
 If IsClickInBackButton(X, Y) Then Begin
  HandleBackButtonClick;
 End;

 { Verifier si le clic est dans le bouton Suivant }
 If IsClickInForwardButton(X, Y) Then Begin
  HandleForwardButtonClick;
 End;

 { Verifier si le clic est dans le bouton Actualiser }
 If IsClickInRefreshButton(X, Y) Then Begin
  HandleRefreshButtonClick;
 End;

 { Verifier si le clic est dans le bouton Favori }
 If IsClickInFavoriteButton(X, Y) Then Begin
  HandleFavoriteButtonClick;
 End;
End;

{ Procedure pour traiter les evenements de la souris }
Procedure ProcessMouseInput;
Begin
 If Not MouseAvailable Then Exit;

 { Obtenir l'etat actuel de la souris }
 GetMouseState(MouseX, MouseY, MouseButton);

 { Detecter un clic (transition de non-presse a presse) }
 If ((MouseButton And MOUSE_LEFT_BUTTON) <> 0) And
    ((LastMouseButton And MOUSE_LEFT_BUTTON) = 0) Then Begin
  HideMouse;
  HandleMouseClick(MouseX, MouseY);
  ShowMouse;
 End;

 { Sauvegarder l'etat du bouton pour la prochaine iteration }
 LastMouseButton := MouseButton;
End;

Var
 Key: Char;

BEGIN
 InitializeGraphics;
 InitURLBar;
 InitHistory;
 InitMouse;
 InitBackButton;
 InitForwardButton;
 InitRefreshButton;
 InitFavoriteButton;
 { Ajouter l'URL initiale a l'historique }
 NavigateTo(CurrentURL);
 DrawURLBar;
 DrawBackButton;
 DrawForwardButton;
 DrawRefreshButton;
 DrawFavoriteButton;
 { Boucle principale pour gerer le clavier et la souris }
 URLBarFocused := True;
 Repeat
  { Traiter les evenements de la souris }
  ProcessMouseInput;
  { Traiter les evenements du clavier }
  If KeyPressed Then Begin
   Key := ReadKey;
   If Key = #0 Then Begin
    { Touche speciale }
    Key := ReadKey;
    HandleURLSpecialKey(Ord(Key));
   End
    Else
   HandleURLInput(Key);
  End;
 Until Key = #27;
 { Cacher la souris avant de fermer }
 If MouseAvailable Then HideMouse;
 CloseGraph;
END.