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
  5.  TODO: Creer le bouton "Favori" pour ajouter/gerer les marque-pages
  6.  TODO: Implementer la gestion de l'historique de navigation (pile de pages visitees)
  7.  TODO: Implementer le support de la souris pour Turbo Pascal via INT 33h
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

 { Couleurs de l'interface }
 COLOR_URL_BAR_BG = 15;       { Blanc }
 COLOR_URL_BAR_BORDER = 0;    { Noir }
 COLOR_URL_BAR_TEXT = 0;      { Noir }
 COLOR_URL_BAR_CURSOR = 0;    { Noir }
 COLOR_BTN_BG = 7;            { Gris clair }
 COLOR_BTN_BORDER = 0;        { Noir }
 COLOR_BTN_TEXT = 0;          { Noir }
 COLOR_BTN_DISABLED = 8;      { Gris fonce }

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
 { La navigation vers la page precedente sera implementee }
 { quand l'historique sera disponible (TODO 6) }
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
 { La navigation vers la page suivante sera implementee }
 { quand l'historique sera disponible (TODO 6) }
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
{$ENDIF}

Var
 Key: Char;

BEGIN
 InitializeGraphics;
 InitURLBar;
 InitBackButton;
 InitForwardButton;
 InitRefreshButton;
 DrawURLBar;
 DrawBackButton;
 DrawForwardButton;
 DrawRefreshButton;
 { Boucle principale temporaire pour tester la barre d'URL }
 URLBarFocused := True;
 Repeat
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
 CloseGraph;
END.