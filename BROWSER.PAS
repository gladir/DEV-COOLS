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
  8.  DONE: Implementer le support de la souris pour Free Pascal via PtcMouse
  9.  DONE: Creer le parseur HTML supportant toutes les balises HTML (HTML 1.0 a HTML5)
  10. DONE: Implementer le rendu des balises de structure HTML (html, head, body, div, span)
  11. DONE: Implementer le rendu des balises de texte (p, h1-h6, strong, em, pre, code)
  12. DONE: Implementer le rendu des listes (ul, ol, li, dl, dt, dd)
  13. DONE: Implementer le rendu des tableaux (table, tr, td, th, thead, tbody)
  14. DONE: Implementer le rendu des formulaires (form, input, button, select, textarea)
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

 { =====================================================
   Constantes pour le parseur HTML (HTML 1.0 a HTML5)
   ===================================================== }

 { Types de noeuds HTML }
 HTML_NODE_ELEMENT = 1;      { Element HTML (balise) }
 HTML_NODE_TEXT = 2;         { Noeud texte }
 HTML_NODE_COMMENT = 3;      { Commentaire HTML }
 HTML_NODE_DOCTYPE = 4;      { Declaration DOCTYPE }
 HTML_NODE_CDATA = 5;        { Section CDATA }

 { Types de balises HTML - Structure }
 TAG_HTML = 1;
 TAG_HEAD = 2;
 TAG_BODY = 3;
 TAG_DIV = 4;
 TAG_SPAN = 5;
 TAG_SECTION = 6;
 TAG_ARTICLE = 7;
 TAG_NAV = 8;
 TAG_ASIDE = 9;
 TAG_HEADER = 10;
 TAG_FOOTER = 11;
 TAG_MAIN = 12;

 { Types de balises HTML - Titres }
 TAG_H1 = 20;
 TAG_H2 = 21;
 TAG_H3 = 22;
 TAG_H4 = 23;
 TAG_H5 = 24;
 TAG_H6 = 25;

 { Types de balises HTML - Texte }
 TAG_P = 30;
 TAG_BR = 31;
 TAG_HR = 32;
 TAG_STRONG = 33;
 TAG_B = 34;
 TAG_EM = 35;
 TAG_I = 36;
 TAG_U = 37;
 TAG_S = 38;
 TAG_STRIKE = 39;
 TAG_DEL = 40;
 TAG_INS = 41;
 TAG_SUB = 42;
 TAG_SUP = 43;
 TAG_SMALL = 44;
 TAG_BIG = 45;
 TAG_MARK = 46;
 TAG_ABBR = 47;
 TAG_CITE = 48;
 TAG_DFN = 49;
 TAG_CODE = 50;
 TAG_PRE = 51;
 TAG_KBD = 52;
 TAG_SAMP = 53;
 TAG_VAR = 54;
 TAG_Q = 55;
 TAG_BLOCKQUOTE = 56;

 { Types de balises HTML - Liens et media }
 TAG_A = 60;
 TAG_IMG = 61;
 TAG_AUDIO = 62;
 TAG_VIDEO = 63;
 TAG_SOURCE = 64;
 TAG_TRACK = 65;
 TAG_EMBED = 66;
 TAG_OBJECT = 67;
 TAG_PARAM = 68;
 TAG_IFRAME = 69;
 TAG_CANVAS = 70;
 TAG_SVG = 71;
 TAG_PICTURE = 72;
 TAG_FIGURE = 73;
 TAG_FIGCAPTION = 74;

 { Types de balises HTML - Listes }
 TAG_UL = 80;
 TAG_OL = 81;
 TAG_LI = 82;
 TAG_DL = 83;
 TAG_DT = 84;
 TAG_DD = 85;
 TAG_MENU = 86;

 { Types de balises HTML - Tableaux }
 TAG_TABLE = 90;
 TAG_TR = 91;
 TAG_TD = 92;
 TAG_TH = 93;
 TAG_THEAD = 94;
 TAG_TBODY = 95;
 TAG_TFOOT = 96;
 TAG_CAPTION = 97;
 TAG_COLGROUP = 98;
 TAG_COL = 99;

 { Types de balises HTML - Formulaires }
 TAG_FORM = 100;
 TAG_INPUT = 101;
 TAG_BUTTON = 102;
 TAG_SELECT = 103;
 TAG_OPTION = 104;
 TAG_OPTGROUP = 105;
 TAG_TEXTAREA = 106;
 TAG_LABEL = 107;
 TAG_FIELDSET = 108;
 TAG_LEGEND = 109;
 TAG_DATALIST = 110;
 TAG_OUTPUT = 111;
 TAG_PROGRESS = 112;
 TAG_METER = 113;

 { Types de balises HTML - Metadonnees }
 TAG_TITLE = 120;
 TAG_META = 121;
 TAG_LINK = 122;
 TAG_STYLE = 123;
 TAG_SCRIPT = 124;
 TAG_NOSCRIPT = 125;
 TAG_BASE = 126;
 TAG_TEMPLATE = 127;
 TAG_SLOT = 128;

 { Types de balises HTML - Semantique }
 TAG_ADDRESS = 130;
 TAG_TIME = 131;
 TAG_DATA = 132;
 TAG_DETAILS = 133;
 TAG_SUMMARY = 134;
 TAG_DIALOG = 135;

 { Types de balises HTML - Ruby (annotations asiatiques) }
 TAG_RUBY = 140;
 TAG_RT = 141;
 TAG_RP = 142;
 TAG_RB = 143;
 TAG_RTC = 144;

 { Types de balises HTML - Autres }
 TAG_WBR = 150;
 TAG_BDI = 151;
 TAG_BDO = 152;
 TAG_MAP = 153;
 TAG_AREA = 154;

 { Balise inconnue }
 TAG_UNKNOWN = 255;

 { Nombre maximum d'attributs par balise }
 MAX_ATTRIBUTES = 32;

 { Nombre maximum d'enfants par noeud }
 MAX_CHILDREN = 256;

 { =====================================================
   Constantes pour le rendu HTML
   ===================================================== }

 { Zone de rendu du contenu HTML }
 RENDER_AREA_X = 5;
 RENDER_AREA_Y = 30;           { Sous la barre d'URL }
 RENDER_AREA_WIDTH = 630;
 RENDER_AREA_HEIGHT = 440;

 { Marges et espacements }
 RENDER_MARGIN_LEFT = 10;
 RENDER_MARGIN_TOP = 5;
 RENDER_LINE_HEIGHT = 16;
 RENDER_PARAGRAPH_SPACING = 8;
 RENDER_DIV_MARGIN = 4;

 { Tailles de ligne pour les titres }
 RENDER_H1_HEIGHT = 32;
 RENDER_H2_HEIGHT = 28;
 RENDER_H3_HEIGHT = 24;
 RENDER_H4_HEIGHT = 20;
 RENDER_H5_HEIGHT = 18;
 RENDER_H6_HEIGHT = 16;

 { Parametres pour les listes }
 RENDER_LIST_INDENT = 20;      { Indentation par niveau de liste }
 RENDER_LIST_SPACING = 2;      { Espacement entre elements de liste }
 RENDER_DT_SPACING = 4;        { Espacement avant terme de definition }
 RENDER_DD_INDENT = 30;        { Indentation pour les definitions }

 { Types de listes }
 LIST_TYPE_NONE = 0;
 LIST_TYPE_UL = 1;             { Liste non ordonnee }
 LIST_TYPE_OL = 2;             { Liste ordonnee }
 LIST_TYPE_DL = 3;             { Liste de definitions }

 { Parametres pour les tableaux }
 TABLE_CELL_PADDING = 4;       { Padding interieur des cellules }
 TABLE_BORDER_WIDTH = 1;       { Epaisseur des bordures }
 TABLE_CELL_MIN_WIDTH = 40;    { Largeur minimale d'une cellule }
 TABLE_CELL_SPACING = 2;       { Espacement entre cellules }
 TABLE_MARGIN = 8;             { Marge autour du tableau }
 TABLE_BORDER_COLOR = 8;       { Couleur des bordures (gris fonce) }
 TABLE_HEADER_BG = 7;          { Couleur de fond des en-tetes (gris clair) }
 MAX_TABLE_COLS = 20;          { Nombre maximum de colonnes }

 { Parametres pour les formulaires }
 FORM_MARGIN = 6;              { Marge autour du formulaire }
 INPUT_WIDTH = 120;            { Largeur par defaut d'un champ input }
 INPUT_HEIGHT = 16;            { Hauteur d'un champ input }
 INPUT_PADDING = 3;            { Padding interieur des inputs }
 INPUT_BORDER_COLOR = 8;       { Couleur de bordure (gris fonce) }
 INPUT_BG_COLOR = 15;          { Couleur de fond (blanc) }
 INPUT_TEXT_COLOR = 0;         { Couleur du texte (noir) }
 BUTTON_PADDING_X = 8;         { Padding horizontal des boutons }
 BUTTON_PADDING_Y = 4;         { Padding vertical des boutons }
 BUTTON_BG_COLOR = 7;          { Couleur de fond des boutons (gris clair) }
 BUTTON_BORDER_COLOR = 8;      { Couleur de bordure des boutons }
 BUTTON_SHADOW_COLOR = 8;      { Couleur de l'ombre }
 CHECKBOX_SIZE = 12;           { Taille des cases a cocher }
 RADIO_SIZE = 12;              { Taille des boutons radio }
 SELECT_WIDTH = 100;           { Largeur par defaut d'un select }
 SELECT_ARROW_WIDTH = 16;      { Largeur de la fleche du select }
 TEXTAREA_WIDTH = 200;         { Largeur par defaut d'un textarea }
 TEXTAREA_HEIGHT = 60;         { Hauteur par defaut d'un textarea }
 TEXTAREA_ROWS_DEFAULT = 4;    { Nombre de lignes par defaut }
 TEXTAREA_COLS_DEFAULT = 20;   { Nombre de colonnes par defaut }

 { Couleurs de rendu }
 RENDER_BG_COLOR = 15;         { Blanc }
 RENDER_TEXT_COLOR = 0;        { Noir }
 RENDER_LINK_COLOR = 1;        { Bleu }

 { Styles de texte (flags combinables) }
 TEXT_STYLE_NORMAL = 0;
 TEXT_STYLE_BOLD = 1;
 TEXT_STYLE_ITALIC = 2;
 TEXT_STYLE_UNDERLINE = 4;
 TEXT_STYLE_STRIKE = 8;
 TEXT_STYLE_CODE = 16;

Type
 { Type pour un attribut HTML }
 HTMLAttribute = Record
  Name: String[64];
  Value: String[255];
 End;

 { Pointeur vers un noeud HTML (declaration forward) }
 HTMLNodePtr = ^HTMLNode;

 { Type pour un noeud HTML }
 HTMLNode = Record
  NodeType: Byte;            { Type de noeud (element, texte, commentaire, etc.) }
  TagType: Byte;             { Type de balise (TAG_P, TAG_DIV, etc.) }
  TagName: String[32];       { Nom de la balise originale }
  Content: String;           { Contenu texte pour les noeuds texte }
  Attributes: Array[1..MAX_ATTRIBUTES] Of HTMLAttribute;
  AttributeCount: Integer;
  Children: Array[1..MAX_CHILDREN] Of HTMLNodePtr;
  ChildCount: Integer;
  Parent: HTMLNodePtr;       { Pointeur vers le noeud parent }
 End;

 { Contexte de rendu HTML }
 RenderContext = Record
  X: Integer;                { Position X courante }
  Y: Integer;                { Position Y courante }
  MaxX: Integer;             { Limite droite de la zone }
  MaxY: Integer;             { Limite basse de la zone }
  LineHeight: Integer;       { Hauteur de ligne courante }
  TextColor: Integer;        { Couleur du texte courante }
  BgColor: Integer;          { Couleur de fond courante }
  InHead: Boolean;           { Dans la section head (ne pas afficher) }
  InBody: Boolean;           { Dans la section body }
  BlockLevel: Integer;       { Niveau d'imbrication des blocs }
  TextStyle: Byte;           { Style de texte (gras, italique, etc.) }
  InPreformatted: Boolean;   { Dans une balise pre (conserver espaces) }
  ListType: Byte;            { Type de liste courante (UL, OL, DL) }
  ListLevel: Integer;        { Niveau d'imbrication des listes }
  ListItemNumber: Integer;   { Numero de l'element courant dans OL }
  InTable: Boolean;          { Dans un tableau }
  InTableHeader: Boolean;    { Dans l'en-tete du tableau (thead/th) }
  TableX: Integer;           { Position X de depart du tableau }
  TableCellX: Integer;       { Position X de la cellule courante }
  TableCellWidth: Integer;   { Largeur de la cellule courante }
  TableColIndex: Integer;    { Index de la colonne courante }
  TableRowY: Integer;        { Position Y de debut de la ligne }
  TableRowHeight: Integer;   { Hauteur de la ligne courante }
  InForm: Boolean;           { Dans un formulaire }
  InSelect: Boolean;         { Dans un element select }
  SelectOptionIndex: Integer;{ Index de l'option courante dans select }
 End;

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

 { Variables pour le parseur HTML }
 HTMLDocument: HTMLNodePtr;   { Racine du document HTML parse }
 HTMLParseError: String;      { Message d'erreur de parsing }

{ =====================================================
  PARSEUR HTML - Fonctions et procedures
  ===================================================== }

{ Fonction pour convertir une chaine en minuscules }
Function HTMLLowerCase(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'A') And (S[I] <= 'Z') Then
   S[I] := Chr(Ord(S[I]) + 32);
 HTMLLowerCase := S;
End;

{ Fonction pour ignorer les espaces blancs }
Function HTMLSkipWhitespace(Const S: String; Pos: Integer): Integer;
Begin
 While (Pos <= Length(S)) And (S[Pos] In [' ', #9, #10, #13]) Do
  Inc(Pos);
 HTMLSkipWhitespace := Pos;
End;

{ Fonction pour verifier si une balise est auto-fermante (void element) }
Function IsVoidElement(Const TagName: String): Boolean;
Var
 LowerName: String;
Begin
 LowerName := HTMLLowerCase(TagName);
 IsVoidElement := (LowerName = 'area') Or (LowerName = 'base') Or
                  (LowerName = 'br') Or (LowerName = 'col') Or
                  (LowerName = 'embed') Or (LowerName = 'hr') Or
                  (LowerName = 'img') Or (LowerName = 'input') Or
                  (LowerName = 'link') Or (LowerName = 'meta') Or
                  (LowerName = 'param') Or (LowerName = 'source') Or
                  (LowerName = 'track') Or (LowerName = 'wbr');
End;

{ Fonction pour obtenir le type de balise a partir du nom }
Function GetTagType(Const TagName: String): Byte;
Var
 LowerName: String;
Begin
 LowerName := HTMLLowerCase(TagName);

 { Balises de structure }
 If LowerName = 'html' Then GetTagType := TAG_HTML
 Else If LowerName = 'head' Then GetTagType := TAG_HEAD
 Else If LowerName = 'body' Then GetTagType := TAG_BODY
 Else If LowerName = 'div' Then GetTagType := TAG_DIV
 Else If LowerName = 'span' Then GetTagType := TAG_SPAN
 Else If LowerName = 'section' Then GetTagType := TAG_SECTION
 Else If LowerName = 'article' Then GetTagType := TAG_ARTICLE
 Else If LowerName = 'nav' Then GetTagType := TAG_NAV
 Else If LowerName = 'aside' Then GetTagType := TAG_ASIDE
 Else If LowerName = 'header' Then GetTagType := TAG_HEADER
 Else If LowerName = 'footer' Then GetTagType := TAG_FOOTER
 Else If LowerName = 'main' Then GetTagType := TAG_MAIN

 { Titres }
 Else If LowerName = 'h1' Then GetTagType := TAG_H1
 Else If LowerName = 'h2' Then GetTagType := TAG_H2
 Else If LowerName = 'h3' Then GetTagType := TAG_H3
 Else If LowerName = 'h4' Then GetTagType := TAG_H4
 Else If LowerName = 'h5' Then GetTagType := TAG_H5
 Else If LowerName = 'h6' Then GetTagType := TAG_H6

 { Balises de texte }
 Else If LowerName = 'p' Then GetTagType := TAG_P
 Else If LowerName = 'br' Then GetTagType := TAG_BR
 Else If LowerName = 'hr' Then GetTagType := TAG_HR
 Else If LowerName = 'strong' Then GetTagType := TAG_STRONG
 Else If LowerName = 'b' Then GetTagType := TAG_B
 Else If LowerName = 'em' Then GetTagType := TAG_EM
 Else If LowerName = 'i' Then GetTagType := TAG_I
 Else If LowerName = 'u' Then GetTagType := TAG_U
 Else If LowerName = 's' Then GetTagType := TAG_S
 Else If LowerName = 'strike' Then GetTagType := TAG_STRIKE
 Else If LowerName = 'del' Then GetTagType := TAG_DEL
 Else If LowerName = 'ins' Then GetTagType := TAG_INS
 Else If LowerName = 'sub' Then GetTagType := TAG_SUB
 Else If LowerName = 'sup' Then GetTagType := TAG_SUP
 Else If LowerName = 'small' Then GetTagType := TAG_SMALL
 Else If LowerName = 'big' Then GetTagType := TAG_BIG
 Else If LowerName = 'mark' Then GetTagType := TAG_MARK
 Else If LowerName = 'abbr' Then GetTagType := TAG_ABBR
 Else If LowerName = 'cite' Then GetTagType := TAG_CITE
 Else If LowerName = 'dfn' Then GetTagType := TAG_DFN
 Else If LowerName = 'code' Then GetTagType := TAG_CODE
 Else If LowerName = 'pre' Then GetTagType := TAG_PRE
 Else If LowerName = 'kbd' Then GetTagType := TAG_KBD
 Else If LowerName = 'samp' Then GetTagType := TAG_SAMP
 Else If LowerName = 'var' Then GetTagType := TAG_VAR
 Else If LowerName = 'q' Then GetTagType := TAG_Q
 Else If LowerName = 'blockquote' Then GetTagType := TAG_BLOCKQUOTE

 { Liens et media }
 Else If LowerName = 'a' Then GetTagType := TAG_A
 Else If LowerName = 'img' Then GetTagType := TAG_IMG
 Else If LowerName = 'audio' Then GetTagType := TAG_AUDIO
 Else If LowerName = 'video' Then GetTagType := TAG_VIDEO
 Else If LowerName = 'source' Then GetTagType := TAG_SOURCE
 Else If LowerName = 'track' Then GetTagType := TAG_TRACK
 Else If LowerName = 'embed' Then GetTagType := TAG_EMBED
 Else If LowerName = 'object' Then GetTagType := TAG_OBJECT
 Else If LowerName = 'param' Then GetTagType := TAG_PARAM
 Else If LowerName = 'iframe' Then GetTagType := TAG_IFRAME
 Else If LowerName = 'canvas' Then GetTagType := TAG_CANVAS
 Else If LowerName = 'svg' Then GetTagType := TAG_SVG
 Else If LowerName = 'picture' Then GetTagType := TAG_PICTURE
 Else If LowerName = 'figure' Then GetTagType := TAG_FIGURE
 Else If LowerName = 'figcaption' Then GetTagType := TAG_FIGCAPTION

 { Listes }
 Else If LowerName = 'ul' Then GetTagType := TAG_UL
 Else If LowerName = 'ol' Then GetTagType := TAG_OL
 Else If LowerName = 'li' Then GetTagType := TAG_LI
 Else If LowerName = 'dl' Then GetTagType := TAG_DL
 Else If LowerName = 'dt' Then GetTagType := TAG_DT
 Else If LowerName = 'dd' Then GetTagType := TAG_DD
 Else If LowerName = 'menu' Then GetTagType := TAG_MENU

 { Tableaux }
 Else If LowerName = 'table' Then GetTagType := TAG_TABLE
 Else If LowerName = 'tr' Then GetTagType := TAG_TR
 Else If LowerName = 'td' Then GetTagType := TAG_TD
 Else If LowerName = 'th' Then GetTagType := TAG_TH
 Else If LowerName = 'thead' Then GetTagType := TAG_THEAD
 Else If LowerName = 'tbody' Then GetTagType := TAG_TBODY
 Else If LowerName = 'tfoot' Then GetTagType := TAG_TFOOT
 Else If LowerName = 'caption' Then GetTagType := TAG_CAPTION
 Else If LowerName = 'colgroup' Then GetTagType := TAG_COLGROUP
 Else If LowerName = 'col' Then GetTagType := TAG_COL

 { Formulaires }
 Else If LowerName = 'form' Then GetTagType := TAG_FORM
 Else If LowerName = 'input' Then GetTagType := TAG_INPUT
 Else If LowerName = 'button' Then GetTagType := TAG_BUTTON
 Else If LowerName = 'select' Then GetTagType := TAG_SELECT
 Else If LowerName = 'option' Then GetTagType := TAG_OPTION
 Else If LowerName = 'optgroup' Then GetTagType := TAG_OPTGROUP
 Else If LowerName = 'textarea' Then GetTagType := TAG_TEXTAREA
 Else If LowerName = 'label' Then GetTagType := TAG_LABEL
 Else If LowerName = 'fieldset' Then GetTagType := TAG_FIELDSET
 Else If LowerName = 'legend' Then GetTagType := TAG_LEGEND
 Else If LowerName = 'datalist' Then GetTagType := TAG_DATALIST
 Else If LowerName = 'output' Then GetTagType := TAG_OUTPUT
 Else If LowerName = 'progress' Then GetTagType := TAG_PROGRESS
 Else If LowerName = 'meter' Then GetTagType := TAG_METER

 { Metadonnees }
 Else If LowerName = 'title' Then GetTagType := TAG_TITLE
 Else If LowerName = 'meta' Then GetTagType := TAG_META
 Else If LowerName = 'link' Then GetTagType := TAG_LINK
 Else If LowerName = 'style' Then GetTagType := TAG_STYLE
 Else If LowerName = 'script' Then GetTagType := TAG_SCRIPT
 Else If LowerName = 'noscript' Then GetTagType := TAG_NOSCRIPT
 Else If LowerName = 'base' Then GetTagType := TAG_BASE
 Else If LowerName = 'template' Then GetTagType := TAG_TEMPLATE
 Else If LowerName = 'slot' Then GetTagType := TAG_SLOT

 { Semantique }
 Else If LowerName = 'address' Then GetTagType := TAG_ADDRESS
 Else If LowerName = 'time' Then GetTagType := TAG_TIME
 Else If LowerName = 'data' Then GetTagType := TAG_DATA
 Else If LowerName = 'details' Then GetTagType := TAG_DETAILS
 Else If LowerName = 'summary' Then GetTagType := TAG_SUMMARY
 Else If LowerName = 'dialog' Then GetTagType := TAG_DIALOG

 { Ruby }
 Else If LowerName = 'ruby' Then GetTagType := TAG_RUBY
 Else If LowerName = 'rt' Then GetTagType := TAG_RT
 Else If LowerName = 'rp' Then GetTagType := TAG_RP
 Else If LowerName = 'rb' Then GetTagType := TAG_RB
 Else If LowerName = 'rtc' Then GetTagType := TAG_RTC

 { Autres }
 Else If LowerName = 'wbr' Then GetTagType := TAG_WBR
 Else If LowerName = 'bdi' Then GetTagType := TAG_BDI
 Else If LowerName = 'bdo' Then GetTagType := TAG_BDO
 Else If LowerName = 'map' Then GetTagType := TAG_MAP
 Else If LowerName = 'area' Then GetTagType := TAG_AREA

 Else GetTagType := TAG_UNKNOWN;
End;

{ Procedure pour creer un nouveau noeud HTML }
Function CreateHTMLNode: HTMLNodePtr;
Var
 Node: HTMLNodePtr;
 I: Integer;
Begin
 New(Node);
 Node^.NodeType := HTML_NODE_ELEMENT;
 Node^.TagType := TAG_UNKNOWN;
 Node^.TagName := '';
 Node^.Content := '';
 Node^.AttributeCount := 0;
 Node^.ChildCount := 0;
 Node^.Parent := Nil;
 For I := 1 To MAX_ATTRIBUTES Do Begin
  Node^.Attributes[I].Name := '';
  Node^.Attributes[I].Value := '';
 End;
 For I := 1 To MAX_CHILDREN Do
  Node^.Children[I] := Nil;
 CreateHTMLNode := Node;
End;

{ Procedure pour liberer un noeud HTML et ses enfants }
Procedure FreeHTMLNode(Node: HTMLNodePtr);
Var
 I: Integer;
Begin
 If Node = Nil Then Exit;
 { Liberer recursivement tous les enfants }
 For I := 1 To Node^.ChildCount Do
  If Node^.Children[I] <> Nil Then
   FreeHTMLNode(Node^.Children[I]);
 Dispose(Node);
End;

{ Fonction pour extraire le nom d'une balise }
Function ExtractTagName(Const S: String; Var Pos: Integer): String;
Var
 StartPos: Integer;
 TagName: String;
Begin
 TagName := '';
 Pos := HTMLSkipWhitespace(S, Pos);
 StartPos := Pos;
 While (Pos <= Length(S)) And
       Not (S[Pos] In [' ', '>', '/', #9, #10, #13, '=']) Do
  Inc(Pos);
 TagName := Copy(S, StartPos, Pos - StartPos);
 ExtractTagName := TagName;
End;

{ Fonction pour extraire la valeur d'un attribut }
Function ExtractAttributeValue(Const S: String; Var Pos: Integer): String;
Var
 Quote: Char;
 StartPos: Integer;
 Value: String;
Begin
 Value := '';
 Pos := HTMLSkipWhitespace(S, Pos);
 If Pos > Length(S) Then Begin
  ExtractAttributeValue := '';
  Exit;
 End;
 { Verifier si la valeur est entre guillemets }
 If S[Pos] In ['"', ''''] Then Begin
  Quote := S[Pos];
  Inc(Pos);
  StartPos := Pos;
  While (Pos <= Length(S)) And (S[Pos] <> Quote) Do
   Inc(Pos);
  Value := Copy(S, StartPos, Pos - StartPos);
  If Pos <= Length(S) Then Inc(Pos); { Passer le guillemet fermant }
 End
 Else Begin
  { Valeur sans guillemets }
  StartPos := Pos;
  While (Pos <= Length(S)) And Not (S[Pos] In [' ', '>', '/', #9, #10, #13]) Do
   Inc(Pos);
  Value := Copy(S, StartPos, Pos - StartPos);
 End;
 ExtractAttributeValue := Value;
End;

{ Procedure pour parser les attributs d'une balise }
Procedure ParseHTMLAttributes(Const S: String; Var Pos: Integer; Node: HTMLNodePtr);
Var
 AttrName, AttrValue: String;
Begin
 While Pos <= Length(S) Do Begin
  Pos := HTMLSkipWhitespace(S, Pos);
  If Pos > Length(S) Then Exit;
  If S[Pos] In ['>', '/'] Then Exit;

  { Extraire le nom de l'attribut }
  AttrName := ExtractTagName(S, Pos);
  If AttrName = '' Then Exit;

  Pos := HTMLSkipWhitespace(S, Pos);
  AttrValue := '';

  { Verifier s'il y a une valeur }
  If (Pos <= Length(S)) And (S[Pos] = '=') Then Begin
   Inc(Pos);
   AttrValue := ExtractAttributeValue(S, Pos);
  End;

  { Ajouter l'attribut au noeud }
  If Node^.AttributeCount < MAX_ATTRIBUTES Then Begin
   Inc(Node^.AttributeCount);
   Node^.Attributes[Node^.AttributeCount].Name := HTMLLowerCase(AttrName);
   Node^.Attributes[Node^.AttributeCount].Value := AttrValue;
  End;
 End;
End;

{ Fonction principale pour parser du HTML }
Function ParseHTML(Const HTMLSource: String): HTMLNodePtr;
Var
 Pos, StartPos, EndTagPos: Integer;
 Root, CurrentNode, NewNode, TextNode: HTMLNodePtr;
 TagName, CloseTagName, TextContent: String;
 IsClosingTag, IsSelfClosing: Boolean;
Begin
 Root := CreateHTMLNode;
 Root^.NodeType := HTML_NODE_ELEMENT;
 Root^.TagName := 'document';
 Root^.TagType := TAG_UNKNOWN;
 CurrentNode := Root;
 Pos := 1;
 HTMLParseError := '';

 While Pos <= Length(HTMLSource) Do Begin
  { Chercher le debut d'une balise }
  StartPos := Pos;
  While (Pos <= Length(HTMLSource)) And (HTMLSource[Pos] <> '<') Do
   Inc(Pos);

  { Traiter le texte avant la balise }
  If Pos > StartPos Then Begin
   TextContent := Copy(HTMLSource, StartPos, Pos - StartPos);
   { Ignorer le texte qui ne contient que des espaces }
   If Trim(TextContent) <> '' Then Begin
    TextNode := CreateHTMLNode;
    TextNode^.NodeType := HTML_NODE_TEXT;
    TextNode^.Content := TextContent;
    TextNode^.Parent := CurrentNode;
    If CurrentNode^.ChildCount < MAX_CHILDREN Then Begin
     Inc(CurrentNode^.ChildCount);
     CurrentNode^.Children[CurrentNode^.ChildCount] := TextNode;
    End;
   End;
  End;

  If Pos > Length(HTMLSource) Then Break;

  { On est sur un '<' }
  Inc(Pos);
  If Pos > Length(HTMLSource) Then Break;

  { Verifier le type de balise }
  If HTMLSource[Pos] = '!' Then Begin
   { Commentaire ou DOCTYPE }
   Inc(Pos);
   If (Pos + 1 <= Length(HTMLSource)) And
      (HTMLSource[Pos] = '-') And (HTMLSource[Pos + 1] = '-') Then Begin
    { Commentaire HTML <!-- ... --> }
    Inc(Pos, 2);
    StartPos := Pos;
    While (Pos + 2 <= Length(HTMLSource)) And
          Not ((HTMLSource[Pos] = '-') And (HTMLSource[Pos + 1] = '-') And
               (HTMLSource[Pos + 2] = '>')) Do
     Inc(Pos);
    NewNode := CreateHTMLNode;
    NewNode^.NodeType := HTML_NODE_COMMENT;
    NewNode^.Content := Copy(HTMLSource, StartPos, Pos - StartPos);
    NewNode^.Parent := CurrentNode;
    If CurrentNode^.ChildCount < MAX_CHILDREN Then Begin
     Inc(CurrentNode^.ChildCount);
     CurrentNode^.Children[CurrentNode^.ChildCount] := NewNode;
    End;
    Inc(Pos, 3);
   End
   Else Begin
    { DOCTYPE ou autre declaration }
    While (Pos <= Length(HTMLSource)) And (HTMLSource[Pos] <> '>') Do
     Inc(Pos);
    Inc(Pos);
   End;
  End
  Else If HTMLSource[Pos] = '/' Then Begin
   { Balise fermante </tag> }
   Inc(Pos);
   CloseTagName := ExtractTagName(HTMLSource, Pos);
   { Trouver le '>' }
   While (Pos <= Length(HTMLSource)) And (HTMLSource[Pos] <> '>') Do
    Inc(Pos);
   Inc(Pos);
   { Remonter au parent si le nom correspond }
   If (CurrentNode <> Root) And
      (HTMLLowerCase(CurrentNode^.TagName) = HTMLLowerCase(CloseTagName)) Then
    CurrentNode := CurrentNode^.Parent;
  End
  Else Begin
   { Balise ouvrante <tag ...> }
   TagName := ExtractTagName(HTMLSource, Pos);
   If TagName <> '' Then Begin
    NewNode := CreateHTMLNode;
    NewNode^.NodeType := HTML_NODE_ELEMENT;
    NewNode^.TagName := TagName;
    NewNode^.TagType := GetTagType(TagName);
    NewNode^.Parent := CurrentNode;

    { Parser les attributs }
    ParseHTMLAttributes(HTMLSource, Pos, NewNode);

    { Verifier si c'est une balise auto-fermante }
    Pos := HTMLSkipWhitespace(HTMLSource, Pos);
    IsSelfClosing := False;
    If (Pos <= Length(HTMLSource)) And (HTMLSource[Pos] = '/') Then Begin
     IsSelfClosing := True;
     Inc(Pos);
    End;

    { Trouver le '>' }
    While (Pos <= Length(HTMLSource)) And (HTMLSource[Pos] <> '>') Do
     Inc(Pos);
    Inc(Pos);

    { Ajouter le noeud comme enfant du noeud courant }
    If CurrentNode^.ChildCount < MAX_CHILDREN Then Begin
     Inc(CurrentNode^.ChildCount);
     CurrentNode^.Children[CurrentNode^.ChildCount] := NewNode;
    End;

    { Si ce n'est pas une balise auto-fermante ou void, descendre dans le noeud }
    If Not IsSelfClosing And Not IsVoidElement(TagName) Then
     CurrentNode := NewNode;
   End;
  End;
 End;

 ParseHTML := Root;
End;

{ Fonction pour obtenir un attribut d'un noeud HTML }
Function GetHTMLAttribute(Node: HTMLNodePtr; Const AttrName: String): String;
Var
 I: Integer;
 LowerName: String;
Begin
 GetHTMLAttribute := '';
 If Node = Nil Then Exit;
 LowerName := HTMLLowerCase(AttrName);
 For I := 1 To Node^.AttributeCount Do
  If Node^.Attributes[I].Name = LowerName Then Begin
   GetHTMLAttribute := Node^.Attributes[I].Value;
   Exit;
  End;
End;

{ Fonction pour trouver un element par son ID }
Function FindElementById(Node: HTMLNodePtr; Const Id: String): HTMLNodePtr;
Var
 I: Integer;
 Found: HTMLNodePtr;
Begin
 FindElementById := Nil;
 If Node = Nil Then Exit;
 If GetHTMLAttribute(Node, 'id') = Id Then Begin
  FindElementById := Node;
  Exit;
 End;
 { Rechercher dans les enfants }
 For I := 1 To Node^.ChildCount Do Begin
  Found := FindElementById(Node^.Children[I], Id);
  If Found <> Nil Then Begin
   FindElementById := Found;
   Exit;
  End;
 End;
End;

{ Fonction pour compter les elements avec un certain tag }
Function CountElementsByTag(Node: HTMLNodePtr; TagType: Byte): Integer;
Var
 I, Count: Integer;
Begin
 Count := 0;
 If Node = Nil Then Begin
  CountElementsByTag := 0;
  Exit;
 End;
 If Node^.TagType = TagType Then Inc(Count);
 For I := 1 To Node^.ChildCount Do
  Count := Count + CountElementsByTag(Node^.Children[I], TagType);
 CountElementsByTag := Count;
End;

{ Fonction Trim pour supprimer les espaces en debut et fin }
Function Trim(Const S: String): String;
Var
 StartPos, EndPos: Integer;
Begin
 StartPos := 1;
 EndPos := Length(S);
 While (StartPos <= EndPos) And (S[StartPos] In [' ', #9, #10, #13]) Do
  Inc(StartPos);
 While (EndPos >= StartPos) And (S[EndPos] In [' ', #9, #10, #13]) Do
  Dec(EndPos);
 If StartPos > EndPos Then
  Trim := ''
 Else
  Trim := Copy(S, StartPos, EndPos - StartPos + 1);
End;

{ Procedure pour initialiser le parseur HTML }
Procedure InitHTMLParser;
Begin
 HTMLDocument := Nil;
 HTMLParseError := '';
End;

{ =====================================================
  FIN PARSEUR HTML
  ===================================================== }

{ =====================================================
  RENDU HTML - Balises de structure (html, head, body, div, span)
  ===================================================== }

Var
 { Variables globales pour le rendu HTML }
 CurrentRenderContext: RenderContext;

{ Procedure pour initialiser le contexte de rendu }
Procedure InitRenderContext(Var Ctx: RenderContext);
Begin
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT;
 Ctx.Y := RENDER_AREA_Y + RENDER_MARGIN_TOP;
 Ctx.MaxX := RENDER_AREA_X + RENDER_AREA_WIDTH - RENDER_MARGIN_LEFT;
 Ctx.MaxY := RENDER_AREA_Y + RENDER_AREA_HEIGHT;
 Ctx.LineHeight := RENDER_LINE_HEIGHT;
 Ctx.TextColor := RENDER_TEXT_COLOR;
 Ctx.BgColor := RENDER_BG_COLOR;
 Ctx.InHead := False;
 Ctx.InBody := False;
 Ctx.BlockLevel := 0;
 Ctx.TextStyle := TEXT_STYLE_NORMAL;
 Ctx.InPreformatted := False;
 Ctx.ListType := LIST_TYPE_NONE;
 Ctx.ListLevel := 0;
 Ctx.ListItemNumber := 0;
 Ctx.InTable := False;
 Ctx.InTableHeader := False;
 Ctx.TableX := 0;
 Ctx.TableCellX := 0;
 Ctx.TableCellWidth := TABLE_CELL_MIN_WIDTH;
 Ctx.TableColIndex := 0;
 Ctx.TableRowY := 0;
 Ctx.TableRowHeight := RENDER_LINE_HEIGHT;
 Ctx.InForm := False;
 Ctx.InSelect := False;
 Ctx.SelectOptionIndex := 0;
End;

{ Procedure pour effacer la zone de rendu }
Procedure ClearRenderArea;
Begin
 SetFillStyle(SolidFill, RENDER_BG_COLOR);
 Bar(RENDER_AREA_X, RENDER_AREA_Y,
     RENDER_AREA_X + RENDER_AREA_WIDTH,
     RENDER_AREA_Y + RENDER_AREA_HEIGHT);
 SetColor(0);
 Rectangle(RENDER_AREA_X, RENDER_AREA_Y,
           RENDER_AREA_X + RENDER_AREA_WIDTH,
           RENDER_AREA_Y + RENDER_AREA_HEIGHT);
End;

{ Procedure pour passer a la ligne suivante }
Procedure RenderNewLine(Var Ctx: RenderContext);
Begin
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
 Ctx.Y := Ctx.Y + Ctx.LineHeight;
End;

{ Procedure pour ajouter un espacement de bloc }
Procedure RenderBlockSpacing(Var Ctx: RenderContext; Spacing: Integer);
Begin
 Ctx.Y := Ctx.Y + Spacing;
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
End;

{ Fonction pour calculer la largeur d'un texte }
Function GetTextWidth(Const Text: String): Integer;
Begin
 GetTextWidth := Length(Text) * 8; { Police par defaut = 8 pixels par caractere }
End;

{ Procedure pour afficher du texte avec retour a la ligne automatique }
Procedure RenderText(Var Ctx: RenderContext; Const Text: String);
Var
 I, StartWord, EndWord, WordWidth: Integer;
 Word: String;
Begin
 If Ctx.InHead Then Exit; { Ne pas afficher le contenu de head }
 If Ctx.Y > Ctx.MaxY Then Exit; { Depasse la zone de rendu }

 SetColor(Ctx.TextColor);
 I := 1;

 While I <= Length(Text) Do Begin
  { Ignorer les espaces en debut de ligne }
  While (I <= Length(Text)) And (Text[I] In [' ', #9, #10, #13]) Do Begin
   If Text[I] In [#10, #13] Then Begin
    { Nouvelle ligne dans le texte source }
    If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
     RenderNewLine(Ctx);
   End
   Else If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then Begin
    { Espace entre les mots }
    Ctx.X := Ctx.X + 8;
   End;
   Inc(I);
  End;

  If I > Length(Text) Then Break;

  { Extraire le mot suivant }
  StartWord := I;
  While (I <= Length(Text)) And Not (Text[I] In [' ', #9, #10, #13]) Do
   Inc(I);
  EndWord := I - 1;
  Word := Copy(Text, StartWord, EndWord - StartWord + 1);
  WordWidth := GetTextWidth(Word);

  { Retour a la ligne si le mot ne tient pas }
  If (Ctx.X + WordWidth > Ctx.MaxX) And
     (Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
   RenderNewLine(Ctx);

  { Afficher le mot si on est dans la zone visible }
  If Ctx.Y <= Ctx.MaxY Then Begin
   OutTextXY(Ctx.X, Ctx.Y, Word);
   Ctx.X := Ctx.X + WordWidth;
  End;
 End;
End;

{ Declaration forward pour la recursion }
Procedure RenderHTMLNode(Node: HTMLNodePtr; Var Ctx: RenderContext); Forward;

{ Procedure pour rendre les enfants d'un noeud }
Procedure RenderChildren(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 I: Integer;
Begin
 For I := 1 To Node^.ChildCount Do
  If Node^.Children[I] <> Nil Then
   RenderHTMLNode(Node^.Children[I], Ctx);
End;

{ Procedure pour rendre la balise HTML (racine du document) }
Procedure RenderTagHTML(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { La balise html est un conteneur, on rend juste ses enfants }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise HEAD (metadonnees, ne pas afficher) }
Procedure RenderTagHead(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInHead: Boolean;
Begin
 OldInHead := Ctx.InHead;
 Ctx.InHead := True;
 { On peut parser le contenu de head pour le titre, mais on n'affiche rien }
 RenderChildren(Node, Ctx);
 Ctx.InHead := OldInHead;
End;

{ Procedure pour rendre la balise BODY (contenu principal) }
Procedure RenderTagBody(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInBody: Boolean;
 BgColorAttr: String;
Begin
 OldInBody := Ctx.InBody;
 Ctx.InBody := True;

 { Verifier l'attribut bgcolor }
 BgColorAttr := GetHTMLAttribute(Node, 'bgcolor');
 { Note: Le support complet des couleurs sera ajoute avec le CSS }

 RenderChildren(Node, Ctx);
 Ctx.InBody := OldInBody;
End;

{ Procedure pour rendre la balise DIV (bloc) }
Procedure RenderTagDiv(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { DIV est un element de bloc - nouvelle ligne avant et apres }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);

 Inc(Ctx.BlockLevel);
 RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
 RenderChildren(Node, Ctx);
 Dec(Ctx.BlockLevel);

 RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
End;

{ Procedure pour rendre la balise SPAN (inline) }
Procedure RenderTagSpan(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { SPAN est un element inline - pas de saut de ligne }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise SECTION (HTML5 bloc semantique) }
Procedure RenderTagSection(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 RenderChildren(Node, Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise ARTICLE (HTML5 bloc semantique) }
Procedure RenderTagArticle(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 RenderChildren(Node, Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise NAV (HTML5 navigation) }
Procedure RenderTagNav(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
 RenderNewLine(Ctx);
End;

{ Procedure pour rendre la balise ASIDE (HTML5 contenu lateral) }
Procedure RenderTagAside(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 Inc(Ctx.BlockLevel);
 RenderChildren(Node, Ctx);
 Dec(Ctx.BlockLevel);
 RenderNewLine(Ctx);
End;

{ Procedure pour rendre la balise HEADER (HTML5 en-tete) }
Procedure RenderTagHeader(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
 RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
End;

{ Procedure pour rendre la balise FOOTER (HTML5 pied de page) }
Procedure RenderTagFooter(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise MAIN (HTML5 contenu principal) }
Procedure RenderTagMain(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
End;

{ =====================================================
  RENDU HTML - Balises de texte (p, h1-h6, strong, em, pre, code)
  ===================================================== }

{ Procedure pour rendre la balise P (paragraphe) }
Procedure RenderTagP(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Nouvelle ligne avant le paragraphe si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);

 RenderChildren(Node, Ctx);

 { Espacement apres le paragraphe }
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure generique pour rendre les titres H1-H6 }
Procedure RenderHeading(Node: HTMLNodePtr; Var Ctx: RenderContext; HeadingHeight: Integer);
Var
 OldLineHeight: Integer;
 OldTextStyle: Byte;
Begin
 { Sauvegarder les valeurs courantes }
 OldLineHeight := Ctx.LineHeight;
 OldTextStyle := Ctx.TextStyle;

 { Nouvelle ligne avant le titre }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);

 { Appliquer la taille du titre }
 Ctx.LineHeight := HeadingHeight;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;

 RenderChildren(Node, Ctx);

 { Restaurer les valeurs }
 Ctx.LineHeight := OldLineHeight;
 Ctx.TextStyle := OldTextStyle;

 { Espacement apres le titre }
 RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise H1 }
Procedure RenderTagH1(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H1_HEIGHT);
End;

{ Procedure pour rendre la balise H2 }
Procedure RenderTagH2(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H2_HEIGHT);
End;

{ Procedure pour rendre la balise H3 }
Procedure RenderTagH3(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H3_HEIGHT);
End;

{ Procedure pour rendre la balise H4 }
Procedure RenderTagH4(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H4_HEIGHT);
End;

{ Procedure pour rendre la balise H5 }
Procedure RenderTagH5(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H5_HEIGHT);
End;

{ Procedure pour rendre la balise H6 }
Procedure RenderTagH6(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderHeading(Node, Ctx, RENDER_H6_HEIGHT);
End;

{ Procedure pour rendre la balise STRONG (texte gras) }
Procedure RenderTagStrong(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise B (texte gras) }
Procedure RenderTagB(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagStrong(Node, Ctx);
End;

{ Procedure pour rendre la balise EM (texte italique) }
Procedure RenderTagEm(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_ITALIC;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise I (texte italique) }
Procedure RenderTagI(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagEm(Node, Ctx);
End;

{ Procedure pour rendre la balise U (texte souligne) }
Procedure RenderTagU(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_UNDERLINE;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise S/STRIKE/DEL (texte barre) }
Procedure RenderTagStrike(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_STRIKE;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise PRE (texte preformate) }
Procedure RenderTagPre(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInPreformatted: Boolean;
 OldTextStyle: Byte;
Begin
 { Nouvelle ligne avant le bloc pre }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);

 OldInPreformatted := Ctx.InPreformatted;
 OldTextStyle := Ctx.TextStyle;

 Ctx.InPreformatted := True;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_CODE;

 RenderChildren(Node, Ctx);

 Ctx.InPreformatted := OldInPreformatted;
 Ctx.TextStyle := OldTextStyle;

 { Espacement apres le bloc pre }
 RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise CODE (code inline) }
Procedure RenderTagCode(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_CODE;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise KBD (entree clavier) }
Procedure RenderTagKbd(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagCode(Node, Ctx);
End;

{ Procedure pour rendre la balise SAMP (exemple de sortie) }
Procedure RenderTagSamp(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagCode(Node, Ctx);
End;

{ Procedure pour rendre la balise VAR (variable) }
Procedure RenderTagVar(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagEm(Node, Ctx);
End;

{ Procedure pour rendre la balise BR (saut de ligne) }
Procedure RenderTagBR(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderNewLine(Ctx);
End;

{ Procedure pour rendre la balise HR (ligne horizontale) }
Procedure RenderTagHR(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Nouvelle ligne avant la ligne horizontale }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, 4);

 { Dessiner la ligne horizontale }
 SetColor(8); { Gris }
 Line(RENDER_AREA_X + RENDER_MARGIN_LEFT,
      Ctx.Y + (Ctx.LineHeight Div 2),
      Ctx.MaxX - RENDER_MARGIN_LEFT,
      Ctx.Y + (Ctx.LineHeight Div 2));
 SetColor(Ctx.TextColor);

 { Espacement apres la ligne }
 RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, 4);
End;

{ Procedure pour rendre la balise BLOCKQUOTE (citation) }
Procedure RenderTagBlockquote(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Nouvelle ligne avant la citation }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);

 { Indenter le contenu }
 Inc(Ctx.BlockLevel, 2);
 RenderChildren(Node, Ctx);
 Dec(Ctx.BlockLevel, 2);

 { Espacement apres la citation }
 RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise Q (citation inline) }
Procedure RenderTagQ(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Ajouter des guillemets }
 RenderText(Ctx, '"');
 RenderChildren(Node, Ctx);
 RenderText(Ctx, '"');
End;

{ Procedure pour rendre la balise SMALL (texte petit) }
Procedure RenderTagSmall(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Note: En mode texte graphique, on ne peut pas vraiment reduire la taille }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise MARK (texte surligne) }
Procedure RenderTagMark(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldBgColor: Integer;
Begin
 OldBgColor := Ctx.BgColor;
 Ctx.BgColor := 14; { Jaune pour le surlignage }
 RenderChildren(Node, Ctx);
 Ctx.BgColor := OldBgColor;
End;

{ Procedure pour rendre la balise ABBR/DFN/CITE (texte semantique) }
Procedure RenderTagSemanticInline(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Ces balises n'ont pas de style visuel specifique par defaut }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise SUB (indice) }
Procedure RenderTagSub(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Note: Le rendu de l'indice necessiterait un ajustement vertical }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise SUP (exposant) }
Procedure RenderTagSup(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Note: Le rendu de l'exposant necessiterait un ajustement vertical }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise INS (texte insere) }
Procedure RenderTagIns(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 RenderTagU(Node, Ctx);
End;

{ =====================================================
  FIN RENDU BALISES DE TEXTE
  ===================================================== }

{ =====================================================
  RENDU HTML - Listes (ul, ol, li, dl, dt, dd)
  ===================================================== }

{ Procedure pour rendre la balise UL (liste non ordonnee) }
Procedure RenderTagUL(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldListType: Byte;
 OldListItemNumber: Integer;
Begin
 { Nouvelle ligne avant la liste si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);

 { Sauvegarder l'etat de la liste parente }
 OldListType := Ctx.ListType;
 OldListItemNumber := Ctx.ListItemNumber;

 { Configurer pour liste non ordonnee }
 Ctx.ListType := LIST_TYPE_UL;
 Ctx.ListItemNumber := 0;
 Inc(Ctx.ListLevel);

 RenderChildren(Node, Ctx);

 { Restaurer l'etat }
 Dec(Ctx.ListLevel);
 Ctx.ListType := OldListType;
 Ctx.ListItemNumber := OldListItemNumber;

 { Espacement apres la liste }
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise OL (liste ordonnee) }
Procedure RenderTagOL(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldListType: Byte;
 OldListItemNumber: Integer;
Begin
 { Nouvelle ligne avant la liste si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);

 { Sauvegarder l'etat de la liste parente }
 OldListType := Ctx.ListType;
 OldListItemNumber := Ctx.ListItemNumber;

 { Configurer pour liste ordonnee }
 Ctx.ListType := LIST_TYPE_OL;
 Ctx.ListItemNumber := 0;
 Inc(Ctx.ListLevel);

 RenderChildren(Node, Ctx);

 { Restaurer l'etat }
 Dec(Ctx.ListLevel);
 Ctx.ListType := OldListType;
 Ctx.ListItemNumber := OldListItemNumber;

 { Espacement apres la liste }
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise LI (element de liste) }
Procedure RenderTagLI(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 BulletText: String;
 IndentX: Integer;
Begin
 { Nouvelle ligne pour l'element }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.ListLevel * RENDER_LIST_INDENT) Then
  RenderNewLine(Ctx);

 { Calculer l'indentation }
 IndentX := RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.ListLevel * RENDER_LIST_INDENT);
 Ctx.X := IndentX;

 { Incrementer le numero d'element pour les listes ordonnees }
 If Ctx.ListType = LIST_TYPE_OL Then
  Inc(Ctx.ListItemNumber);

 { Afficher le marqueur de liste }
 Case Ctx.ListType Of
  LIST_TYPE_UL: Begin
   { Puce pour liste non ordonnee - utiliser differentes puces selon le niveau }
   Case Ctx.ListLevel Of
    1: BulletText := '• ';   { Puce ronde }
    2: BulletText := '○ ';   { Cercle vide }
    3: BulletText := '■ ';   { Carre plein }
    Else BulletText := '- '; { Tiret pour niveaux plus profonds }
   End;
   RenderText(Ctx, BulletText);
  End;
  LIST_TYPE_OL: Begin
   { Numero pour liste ordonnee }
   Str(Ctx.ListItemNumber, BulletText);
   BulletText := BulletText + '. ';
   RenderText(Ctx, BulletText);
  End;
  Else Begin
   { Pas de marqueur si pas dans une liste }
  End;
 End;

 { Rendre le contenu de l'element }
 RenderChildren(Node, Ctx);

 { Espacement apres l'element }
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise DL (liste de definitions) }
Procedure RenderTagDL(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldListType: Byte;
Begin
 { Nouvelle ligne avant la liste si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);

 { Sauvegarder l'etat }
 OldListType := Ctx.ListType;

 { Configurer pour liste de definitions }
 Ctx.ListType := LIST_TYPE_DL;
 Inc(Ctx.ListLevel);

 RenderChildren(Node, Ctx);

 { Restaurer l'etat }
 Dec(Ctx.ListLevel);
 Ctx.ListType := OldListType;

 { Espacement apres la liste }
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise DT (terme de definition) }
Procedure RenderTagDT(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
Begin
 { Nouvelle ligne pour le terme }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, RENDER_DT_SPACING);

 { Position sans indentation supplementaire }
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT + ((Ctx.ListLevel - 1) * RENDER_LIST_INDENT);

 { Rendre le terme en gras }
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;

 RenderChildren(Node, Ctx);

 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise DD (definition) }
Procedure RenderTagDD(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Nouvelle ligne pour la definition }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT Then
  RenderNewLine(Ctx);

 { Indenter la definition }
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT + ((Ctx.ListLevel - 1) * RENDER_LIST_INDENT) + RENDER_DD_INDENT;

 RenderChildren(Node, Ctx);

 { Espacement apres la definition }
 RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ =====================================================
  FIN RENDU LISTES
  ===================================================== }

{ =====================================================
  RENDU HTML - Tableaux (table, tr, td, th, thead, tbody)
  ===================================================== }

{ Fonction utilitaire pour compter les colonnes d'un tableau }
Function CountTableColumns(Node: HTMLNodePtr): Integer;
Var
 I, J, MaxCols, RowCols: Integer;
 ChildNode, CellNode: HTMLNodePtr;
Begin
 MaxCols := 0;

 { Parcourir les enfants pour trouver tr, thead, tbody }
 For I := 1 To Node^.ChildCount Do Begin
  ChildNode := Node^.Children[I];
  If ChildNode <> Nil Then Begin
   If (ChildNode^.TagType = TAG_TR) Then Begin
    { Compter les cellules dans cette ligne }
    RowCols := 0;
    For J := 1 To ChildNode^.ChildCount Do Begin
     CellNode := ChildNode^.Children[J];
     If CellNode <> Nil Then Begin
      If (CellNode^.TagType = TAG_TD) Or (CellNode^.TagType = TAG_TH) Then
       Inc(RowCols);
     End;
    End;
    If RowCols > MaxCols Then MaxCols := RowCols;
   End
   Else If (ChildNode^.TagType = TAG_THEAD) Or (ChildNode^.TagType = TAG_TBODY) Then Begin
    { Parcourir les lignes dans thead/tbody }
    For J := 1 To ChildNode^.ChildCount Do Begin
     If (ChildNode^.Children[J] <> Nil) And (ChildNode^.Children[J]^.TagType = TAG_TR) Then Begin
      RowCols := CountTableColumns(ChildNode);
      If RowCols > MaxCols Then MaxCols := RowCols;
     End;
    End;
   End;
  End;
 End;

 If MaxCols > MAX_TABLE_COLS Then MaxCols := MAX_TABLE_COLS;
 If MaxCols = 0 Then MaxCols := 1;
 CountTableColumns := MaxCols;
End;

{ Procedure pour rendre la balise TABLE }
Procedure RenderTagTable(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInTable: Boolean;
 OldTableX: Integer;
 NumCols, TableWidth: Integer;
Begin
 { Nouvelle ligne avant le tableau si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, TABLE_MARGIN);

 { Sauvegarder l'etat }
 OldInTable := Ctx.InTable;
 OldTableX := Ctx.TableX;

 { Configurer le contexte pour le tableau }
 Ctx.InTable := True;
 Ctx.TableX := Ctx.X;
 Ctx.TableColIndex := 0;
 Ctx.TableRowY := Ctx.Y;
 Ctx.TableRowHeight := RENDER_LINE_HEIGHT;

 { Calculer la largeur des cellules }
 NumCols := CountTableColumns(Node);
 TableWidth := Ctx.MaxX - Ctx.X - TABLE_MARGIN;
 Ctx.TableCellWidth := (TableWidth - (NumCols * TABLE_CELL_SPACING)) Div NumCols;
 If Ctx.TableCellWidth < TABLE_CELL_MIN_WIDTH Then
  Ctx.TableCellWidth := TABLE_CELL_MIN_WIDTH;

 { Dessiner la bordure superieure du tableau }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableX, Ctx.Y, Ctx.TableX + (NumCols * (Ctx.TableCellWidth + TABLE_CELL_SPACING)), Ctx.Y);
 Inc(Ctx.Y, TABLE_BORDER_WIDTH);

 { Rendre les enfants }
 RenderChildren(Node, Ctx);

 { Dessiner la bordure inferieure du tableau }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableX, Ctx.Y, Ctx.TableX + (NumCols * (Ctx.TableCellWidth + TABLE_CELL_SPACING)), Ctx.Y);
 Inc(Ctx.Y, TABLE_BORDER_WIDTH);

 { Restaurer l'etat }
 Ctx.InTable := OldInTable;
 Ctx.TableX := OldTableX;

 { Retour a la position X de depart et espacement apres }
 Ctx.X := RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
 RenderBlockSpacing(Ctx, TABLE_MARGIN);
End;

{ Procedure pour rendre la balise THEAD (en-tete du tableau) }
Procedure RenderTagThead(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInTableHeader: Boolean;
Begin
 OldInTableHeader := Ctx.InTableHeader;
 Ctx.InTableHeader := True;

 RenderChildren(Node, Ctx);

 Ctx.InTableHeader := OldInTableHeader;
End;

{ Procedure pour rendre la balise TBODY (corps du tableau) }
Procedure RenderTagTbody(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { TBODY est principalement semantique, rendre simplement les enfants }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise TR (ligne de tableau) }
Procedure RenderTagTR(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 I: Integer;
 MaxRowHeight: Integer;
 ChildNode: HTMLNodePtr;
Begin
 If Not Ctx.InTable Then Begin
  { Si pas dans un tableau, rendre comme un bloc }
  RenderChildren(Node, Ctx);
  Exit;
 End;

 { Initialiser la ligne }
 Ctx.TableColIndex := 0;
 Ctx.TableCellX := Ctx.TableX;
 Ctx.TableRowY := Ctx.Y;
 Ctx.TableRowHeight := RENDER_LINE_HEIGHT + (2 * TABLE_CELL_PADDING);

 { Dessiner la bordure gauche de la ligne }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableX, Ctx.Y, Ctx.TableX, Ctx.Y + Ctx.TableRowHeight);

 { Rendre les cellules }
 RenderChildren(Node, Ctx);

 { Dessiner la bordure droite de la ligne }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableCellX, Ctx.TableRowY, Ctx.TableCellX, Ctx.TableRowY + Ctx.TableRowHeight);

 { Passer a la ligne suivante }
 Ctx.Y := Ctx.TableRowY + Ctx.TableRowHeight;
 Ctx.X := Ctx.TableX;

 { Dessiner la bordure horizontale sous la ligne }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableX, Ctx.Y, Ctx.TableCellX, Ctx.Y);
 Inc(Ctx.Y, TABLE_BORDER_WIDTH);
End;

{ Procedure pour rendre la balise TD (cellule de donnees) }
Procedure RenderTagTD(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 CellStartX, CellStartY: Integer;
 OldMaxX: Integer;
Begin
 If Not Ctx.InTable Then Begin
  { Si pas dans un tableau, rendre comme un bloc }
  RenderChildren(Node, Ctx);
  Exit;
 End;

 { Position de la cellule }
 CellStartX := Ctx.TableCellX;
 CellStartY := Ctx.TableRowY;

 { Dessiner le fond de la cellule }
 SetFillStyle(SolidFill, RENDER_BG_COLOR);
 Bar(CellStartX + TABLE_BORDER_WIDTH, CellStartY + TABLE_BORDER_WIDTH,
     CellStartX + Ctx.TableCellWidth, CellStartY + Ctx.TableRowHeight - TABLE_BORDER_WIDTH);

 { Configurer le contexte pour le contenu de la cellule }
 Ctx.X := CellStartX + TABLE_CELL_PADDING;
 Ctx.Y := CellStartY + TABLE_CELL_PADDING;
 OldMaxX := Ctx.MaxX;
 Ctx.MaxX := CellStartX + Ctx.TableCellWidth - TABLE_CELL_PADDING;

 { Rendre le contenu }
 RenderChildren(Node, Ctx);

 { Restaurer MaxX }
 Ctx.MaxX := OldMaxX;

 { Passer a la cellule suivante }
 Ctx.TableCellX := CellStartX + Ctx.TableCellWidth + TABLE_CELL_SPACING;
 Inc(Ctx.TableColIndex);

 { Dessiner la bordure droite de la cellule }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableCellX - TABLE_CELL_SPACING, CellStartY, Ctx.TableCellX - TABLE_CELL_SPACING, CellStartY + Ctx.TableRowHeight);

 { Remettre Y a la position de la ligne }
 Ctx.Y := CellStartY;
End;

{ Procedure pour rendre la balise TH (cellule d'en-tete) }
Procedure RenderTagTH(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 CellStartX, CellStartY: Integer;
 OldMaxX: Integer;
 OldTextStyle: Byte;
Begin
 If Not Ctx.InTable Then Begin
  { Si pas dans un tableau, rendre comme un bloc en gras }
  OldTextStyle := Ctx.TextStyle;
  Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;
  RenderChildren(Node, Ctx);
  Ctx.TextStyle := OldTextStyle;
  Exit;
 End;

 { Position de la cellule }
 CellStartX := Ctx.TableCellX;
 CellStartY := Ctx.TableRowY;

 { Dessiner le fond de la cellule d'en-tete (gris clair) }
 SetFillStyle(SolidFill, TABLE_HEADER_BG);
 Bar(CellStartX + TABLE_BORDER_WIDTH, CellStartY + TABLE_BORDER_WIDTH,
     CellStartX + Ctx.TableCellWidth, CellStartY + Ctx.TableRowHeight - TABLE_BORDER_WIDTH);

 { Configurer le contexte pour le contenu de la cellule }
 Ctx.X := CellStartX + TABLE_CELL_PADDING;
 Ctx.Y := CellStartY + TABLE_CELL_PADDING;
 OldMaxX := Ctx.MaxX;
 Ctx.MaxX := CellStartX + Ctx.TableCellWidth - TABLE_CELL_PADDING;

 { Rendre le contenu en gras }
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;
 RenderChildren(Node, Ctx);
 Ctx.TextStyle := OldTextStyle;

 { Restaurer MaxX }
 Ctx.MaxX := OldMaxX;

 { Passer a la cellule suivante }
 Ctx.TableCellX := CellStartX + Ctx.TableCellWidth + TABLE_CELL_SPACING;
 Inc(Ctx.TableColIndex);

 { Dessiner la bordure droite de la cellule }
 SetColor(TABLE_BORDER_COLOR);
 Line(Ctx.TableCellX - TABLE_CELL_SPACING, CellStartY, Ctx.TableCellX - TABLE_CELL_SPACING, CellStartY + Ctx.TableRowHeight);

 { Remettre Y a la position de la ligne }
 Ctx.Y := CellStartY;
End;

{ =====================================================
  FIN RENDU TABLEAUX
  ===================================================== }

{ =====================================================
  RENDU HTML - Formulaires (form, input, button, select, textarea)
  ===================================================== }

{ Fonction utilitaire pour obtenir la valeur d'un attribut }
Function GetNodeAttribute(Node: HTMLNodePtr; AttrName: String): String;
Var
 I: Integer;
 LowerAttr: String;
Begin
 GetNodeAttribute := '';
 If Node = Nil Then Exit;

 LowerAttr := '';
 For I := 1 To Length(AttrName) Do
  LowerAttr := LowerAttr + LoCase(AttrName[I]);

 For I := 1 To Node^.AttrCount Do Begin
  If Node^.Attrs[I].Name = LowerAttr Then Begin
   GetNodeAttribute := Node^.Attrs[I].Value;
   Exit;
  End;
 End;
End;

{ Procedure pour rendre la balise FORM }
Procedure RenderTagForm(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInForm: Boolean;
Begin
 { Nouvelle ligne avant le formulaire si necessaire }
 If Ctx.X > RENDER_AREA_X + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, FORM_MARGIN);

 { Sauvegarder l'etat }
 OldInForm := Ctx.InForm;
 Ctx.InForm := True;

 { Rendre les enfants du formulaire }
 RenderChildren(Node, Ctx);

 { Restaurer l'etat }
 Ctx.InForm := OldInForm;

 { Espacement apres le formulaire }
 RenderBlockSpacing(Ctx, FORM_MARGIN);
End;

{ Procedure pour dessiner un champ de saisie text/password }
Procedure DrawInputField(X, Y, W, H: Integer; Value: String; IsPassword: Boolean);
Var
 DisplayText: String;
 I: Integer;
Begin
 { Fond blanc }
 SetFillStyle(SolidFill, INPUT_BG_COLOR);
 Bar(X, Y, X + W, Y + H);

 { Bordure }
 SetColor(INPUT_BORDER_COLOR);
 Rectangle(X, Y, X + W, Y + H);

 { Texte (masque pour password) }
 If IsPassword Then Begin
  DisplayText := '';
  For I := 1 To Length(Value) Do
   DisplayText := DisplayText + '*';
 End
 Else
  DisplayText := Value;

 SetColor(INPUT_TEXT_COLOR);
 If Length(DisplayText) > 0 Then
  OutTextXY(X + INPUT_PADDING, Y + INPUT_PADDING, DisplayText);
End;

{ Procedure pour dessiner une case a cocher }
Procedure DrawCheckbox(X, Y: Integer; Checked: Boolean);
Begin
 { Fond blanc }
 SetFillStyle(SolidFill, INPUT_BG_COLOR);
 Bar(X, Y, X + CHECKBOX_SIZE, Y + CHECKBOX_SIZE);

 { Bordure }
 SetColor(INPUT_BORDER_COLOR);
 Rectangle(X, Y, X + CHECKBOX_SIZE, Y + CHECKBOX_SIZE);

 { Coche si selectionne }
 If Checked Then Begin
  SetColor(INPUT_TEXT_COLOR);
  Line(X + 2, Y + (CHECKBOX_SIZE Div 2), X + (CHECKBOX_SIZE Div 2), Y + CHECKBOX_SIZE - 3);
  Line(X + (CHECKBOX_SIZE Div 2), Y + CHECKBOX_SIZE - 3, X + CHECKBOX_SIZE - 2, Y + 2);
 End;
End;

{ Procedure pour dessiner un bouton radio }
Procedure DrawRadioButton(X, Y: Integer; Selected: Boolean);
Var
 CenterX, CenterY, Radius: Integer;
Begin
 CenterX := X + (RADIO_SIZE Div 2);
 CenterY := Y + (RADIO_SIZE Div 2);
 Radius := RADIO_SIZE Div 2;

 { Cercle exterieur }
 SetColor(INPUT_BORDER_COLOR);
 Circle(CenterX, CenterY, Radius);

 { Remplir si selectionne }
 If Selected Then Begin
  SetFillStyle(SolidFill, INPUT_TEXT_COLOR);
  FillEllipse(CenterX, CenterY, Radius - 3, Radius - 3);
 End;
End;

{ Procedure pour dessiner un bouton }
Procedure DrawButton(X, Y: Integer; Caption: String);
Var
 W, H: Integer;
Begin
 W := TextWidth(Caption) + (2 * BUTTON_PADDING_X);
 H := TextHeight(Caption) + (2 * BUTTON_PADDING_Y);

 { Ombre }
 SetFillStyle(SolidFill, BUTTON_SHADOW_COLOR);
 Bar(X + 2, Y + 2, X + W + 2, Y + H + 2);

 { Fond du bouton }
 SetFillStyle(SolidFill, BUTTON_BG_COLOR);
 Bar(X, Y, X + W, Y + H);

 { Bordure }
 SetColor(BUTTON_BORDER_COLOR);
 Rectangle(X, Y, X + W, Y + H);

 { Effet 3D (bord haut/gauche clair) }
 SetColor(15);
 Line(X, Y, X + W, Y);
 Line(X, Y, X, Y + H);

 { Effet 3D (bord bas/droite fonce) }
 SetColor(8);
 Line(X, Y + H, X + W, Y + H);
 Line(X + W, Y, X + W, Y + H);

 { Texte du bouton }
 SetColor(INPUT_TEXT_COLOR);
 OutTextXY(X + BUTTON_PADDING_X, Y + BUTTON_PADDING_Y, Caption);
End;

{ Procedure pour rendre la balise INPUT }
Procedure RenderTagInput(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 InputType, InputValue, InputName: String;
 Checked: Boolean;
 W, H: Integer;
Begin
 { Obtenir les attributs }
 InputType := GetNodeAttribute(Node, 'type');
 InputValue := GetNodeAttribute(Node, 'value');
 InputName := GetNodeAttribute(Node, 'name');

 { Type par defaut: text }
 If InputType = '' Then InputType := 'text';

 { Verifier si checked }
 Checked := (GetNodeAttribute(Node, 'checked') <> '');

 { Rendre selon le type }
 If (InputType = 'text') Or (InputType = 'password') Or (InputType = 'email') Or
    (InputType = 'number') Or (InputType = 'search') Or (InputType = 'tel') Or
    (InputType = 'url') Then Begin
  { Champ de saisie }
  DrawInputField(Ctx.X, Ctx.Y, INPUT_WIDTH, INPUT_HEIGHT, InputValue, InputType = 'password');
  Inc(Ctx.X, INPUT_WIDTH + 6);
 End
 Else If InputType = 'checkbox' Then Begin
  { Case a cocher }
  DrawCheckbox(Ctx.X, Ctx.Y, Checked);
  Inc(Ctx.X, CHECKBOX_SIZE + 6);
 End
 Else If InputType = 'radio' Then Begin
  { Bouton radio }
  DrawRadioButton(Ctx.X, Ctx.Y, Checked);
  Inc(Ctx.X, RADIO_SIZE + 6);
 End
 Else If (InputType = 'submit') Or (InputType = 'button') Or (InputType = 'reset') Then Begin
  { Bouton }
  If InputValue = '' Then Begin
   If InputType = 'submit' Then InputValue := 'Envoyer'
   Else If InputType = 'reset' Then InputValue := 'Effacer'
   Else InputValue := 'Bouton';
  End;
  DrawButton(Ctx.X, Ctx.Y, InputValue);
  W := TextWidth(InputValue) + (2 * BUTTON_PADDING_X);
  Inc(Ctx.X, W + 6);
 End
 Else If InputType = 'hidden' Then Begin
  { Input cache - ne rien afficher }
 End
 Else Begin
  { Type inconnu - afficher comme texte }
  DrawInputField(Ctx.X, Ctx.Y, INPUT_WIDTH, INPUT_HEIGHT, InputValue, False);
  Inc(Ctx.X, INPUT_WIDTH + 6);
 End;

 { Gerer le debordement de ligne }
 If Ctx.X > Ctx.MaxX Then Begin
  RenderNewLine(Ctx);
 End;
End;

{ Procedure pour rendre la balise BUTTON }
Procedure RenderTagButton(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 ButtonText: String;
 W: Integer;
Begin
 { Obtenir le texte du bouton }
 ButtonText := GetNodeAttribute(Node, 'value');

 { Si pas de valeur, utiliser le contenu textuel }
 If ButtonText = '' Then Begin
  If (Node^.ChildCount > 0) And (Node^.Children[1] <> Nil) Then Begin
   If Node^.Children[1]^.NodeType = HTML_NODE_TEXT Then
    ButtonText := Node^.Children[1]^.Content;
  End;
 End;

 If ButtonText = '' Then ButtonText := 'Bouton';

 { Dessiner le bouton }
 DrawButton(Ctx.X, Ctx.Y, ButtonText);
 W := TextWidth(ButtonText) + (2 * BUTTON_PADDING_X);
 Inc(Ctx.X, W + 6);

 { Gerer le debordement de ligne }
 If Ctx.X > Ctx.MaxX Then Begin
  RenderNewLine(Ctx);
 End;
End;

{ Procedure pour rendre la balise SELECT }
Procedure RenderTagSelect(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInSelect: Boolean;
 I: Integer;
 FirstOptionText: String;
 ChildNode: HTMLNodePtr;
Begin
 { Trouver le texte de la premiere option }
 FirstOptionText := '';
 For I := 1 To Node^.ChildCount Do Begin
  ChildNode := Node^.Children[I];
  If (ChildNode <> Nil) And (ChildNode^.TagType = TAG_OPTION) Then Begin
   If (ChildNode^.ChildCount > 0) And (ChildNode^.Children[1] <> Nil) Then Begin
    If ChildNode^.Children[1]^.NodeType = HTML_NODE_TEXT Then Begin
     FirstOptionText := ChildNode^.Children[1]^.Content;
     Break;
    End;
   End;
  End;
 End;

 If FirstOptionText = '' Then FirstOptionText := '---';

 { Dessiner le fond de la liste deroulante }
 SetFillStyle(SolidFill, INPUT_BG_COLOR);
 Bar(Ctx.X, Ctx.Y, Ctx.X + SELECT_WIDTH, Ctx.Y + INPUT_HEIGHT);

 { Bordure }
 SetColor(INPUT_BORDER_COLOR);
 Rectangle(Ctx.X, Ctx.Y, Ctx.X + SELECT_WIDTH, Ctx.Y + INPUT_HEIGHT);

 { Zone de la fleche }
 SetFillStyle(SolidFill, BUTTON_BG_COLOR);
 Bar(Ctx.X + SELECT_WIDTH - SELECT_ARROW_WIDTH, Ctx.Y + 1,
     Ctx.X + SELECT_WIDTH - 1, Ctx.Y + INPUT_HEIGHT - 1);

 { Dessiner la fleche vers le bas }
 SetColor(INPUT_TEXT_COLOR);
 Line(Ctx.X + SELECT_WIDTH - SELECT_ARROW_WIDTH + 4, Ctx.Y + 5,
      Ctx.X + SELECT_WIDTH - (SELECT_ARROW_WIDTH Div 2), Ctx.Y + INPUT_HEIGHT - 5);
 Line(Ctx.X + SELECT_WIDTH - (SELECT_ARROW_WIDTH Div 2), Ctx.Y + INPUT_HEIGHT - 5,
      Ctx.X + SELECT_WIDTH - 4, Ctx.Y + 5);

 { Texte de l'option selectionnee }
 SetColor(INPUT_TEXT_COLOR);
 OutTextXY(Ctx.X + INPUT_PADDING, Ctx.Y + INPUT_PADDING, FirstOptionText);

 Inc(Ctx.X, SELECT_WIDTH + 6);

 { Gerer le debordement de ligne }
 If Ctx.X > Ctx.MaxX Then Begin
  RenderNewLine(Ctx);
 End;

 { Note: Les options ne sont pas rendues visiblement (liste fermee par defaut) }
End;

{ Procedure pour rendre la balise OPTION }
Procedure RenderTagOption(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Les options sont gerees par SELECT, ne rien faire ici }
 { Le texte de l'option est lu directement par RenderTagSelect }
End;

{ Procedure pour rendre la balise TEXTAREA }
Procedure RenderTagTextarea(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 Rows, Cols: Integer;
 W, H: Integer;
 TextContent: String;
 RowsStr, ColsStr: String;
 Code: Integer;
Begin
 { Obtenir les dimensions }
 RowsStr := GetNodeAttribute(Node, 'rows');
 ColsStr := GetNodeAttribute(Node, 'cols');

 Rows := TEXTAREA_ROWS_DEFAULT;
 Cols := TEXTAREA_COLS_DEFAULT;

 If RowsStr <> '' Then Begin
  Val(RowsStr, Rows, Code);
  If Code <> 0 Then Rows := TEXTAREA_ROWS_DEFAULT;
 End;

 If ColsStr <> '' Then Begin
  Val(ColsStr, Cols, Code);
  If Code <> 0 Then Cols := TEXTAREA_COLS_DEFAULT;
 End;

 { Calculer les dimensions en pixels }
 W := Cols * 8;  { Approximation: 8 pixels par caractere }
 H := Rows * RENDER_LINE_HEIGHT;

 If W < TEXTAREA_WIDTH Div 2 Then W := TEXTAREA_WIDTH;
 If H < TEXTAREA_HEIGHT Div 2 Then H := TEXTAREA_HEIGHT;

 { Nouvelle ligne si necessaire }
 If Ctx.X + W > Ctx.MaxX Then
  RenderNewLine(Ctx);

 { Fond blanc }
 SetFillStyle(SolidFill, INPUT_BG_COLOR);
 Bar(Ctx.X, Ctx.Y, Ctx.X + W, Ctx.Y + H);

 { Bordure }
 SetColor(INPUT_BORDER_COLOR);
 Rectangle(Ctx.X, Ctx.Y, Ctx.X + W, Ctx.Y + H);

 { Contenu textuel (si present) }
 If (Node^.ChildCount > 0) And (Node^.Children[1] <> Nil) Then Begin
  If Node^.Children[1]^.NodeType = HTML_NODE_TEXT Then Begin
   TextContent := Node^.Children[1]^.Content;
   SetColor(INPUT_TEXT_COLOR);
   OutTextXY(Ctx.X + INPUT_PADDING, Ctx.Y + INPUT_PADDING, TextContent);
  End;
 End;

 Inc(Ctx.X, W + 6);

 { Gerer le debordement de ligne }
 If Ctx.X > Ctx.MaxX Then Begin
  RenderNewLine(Ctx);
 End;
End;

{ Procedure pour rendre la balise LABEL }
Procedure RenderTagLabel(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { Label est rendu comme du texte normal avec ses enfants }
 RenderChildren(Node, Ctx);
End;

{ =====================================================
  FIN RENDU FORMULAIRES
  ===================================================== }
Procedure RenderHTMLNode(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 If Node = Nil Then Exit;
 If Ctx.Y > Ctx.MaxY Then Exit; { Depasse la zone de rendu }

 Case Node^.NodeType Of
  HTML_NODE_TEXT: Begin
   { Noeud texte - afficher le contenu }
   RenderText(Ctx, Node^.Content);
  End;

  HTML_NODE_ELEMENT: Begin
   { Element HTML - traiter selon le type de balise }
   Case Node^.TagType Of
    { Balises de structure }
    TAG_HTML:     RenderTagHTML(Node, Ctx);
    TAG_HEAD:     RenderTagHead(Node, Ctx);
    TAG_BODY:     RenderTagBody(Node, Ctx);
    TAG_DIV:      RenderTagDiv(Node, Ctx);
    TAG_SPAN:     RenderTagSpan(Node, Ctx);
    TAG_SECTION:  RenderTagSection(Node, Ctx);
    TAG_ARTICLE:  RenderTagArticle(Node, Ctx);
    TAG_NAV:      RenderTagNav(Node, Ctx);
    TAG_ASIDE:    RenderTagAside(Node, Ctx);
    TAG_HEADER:   RenderTagHeader(Node, Ctx);
    TAG_FOOTER:   RenderTagFooter(Node, Ctx);
    TAG_MAIN:     RenderTagMain(Node, Ctx);

    { Balises de texte - Titres }
    TAG_H1:       RenderTagH1(Node, Ctx);
    TAG_H2:       RenderTagH2(Node, Ctx);
    TAG_H3:       RenderTagH3(Node, Ctx);
    TAG_H4:       RenderTagH4(Node, Ctx);
    TAG_H5:       RenderTagH5(Node, Ctx);
    TAG_H6:       RenderTagH6(Node, Ctx);

    { Balises de texte - Paragraphe et blocs }
    TAG_P:        RenderTagP(Node, Ctx);
    TAG_BR:       RenderTagBR(Node, Ctx);
    TAG_HR:       RenderTagHR(Node, Ctx);
    TAG_PRE:      RenderTagPre(Node, Ctx);
    TAG_BLOCKQUOTE: RenderTagBlockquote(Node, Ctx);

    { Balises de texte - Style inline }
    TAG_STRONG:   RenderTagStrong(Node, Ctx);
    TAG_B:        RenderTagB(Node, Ctx);
    TAG_EM:       RenderTagEm(Node, Ctx);
    TAG_I:        RenderTagI(Node, Ctx);
    TAG_U:        RenderTagU(Node, Ctx);
    TAG_S:        RenderTagStrike(Node, Ctx);
    TAG_STRIKE:   RenderTagStrike(Node, Ctx);
    TAG_DEL:      RenderTagStrike(Node, Ctx);
    TAG_INS:      RenderTagIns(Node, Ctx);
    TAG_CODE:     RenderTagCode(Node, Ctx);
    TAG_KBD:      RenderTagKbd(Node, Ctx);
    TAG_SAMP:     RenderTagSamp(Node, Ctx);
    TAG_VAR:      RenderTagVar(Node, Ctx);
    TAG_Q:        RenderTagQ(Node, Ctx);
    TAG_SMALL:    RenderTagSmall(Node, Ctx);
    TAG_MARK:     RenderTagMark(Node, Ctx);
    TAG_SUB:      RenderTagSub(Node, Ctx);
    TAG_SUP:      RenderTagSup(Node, Ctx);
    TAG_ABBR:     RenderTagSemanticInline(Node, Ctx);
    TAG_CITE:     RenderTagSemanticInline(Node, Ctx);
    TAG_DFN:      RenderTagSemanticInline(Node, Ctx);

    { Balises de listes }
    TAG_UL:       RenderTagUL(Node, Ctx);
    TAG_OL:       RenderTagOL(Node, Ctx);
    TAG_LI:       RenderTagLI(Node, Ctx);
    TAG_DL:       RenderTagDL(Node, Ctx);
    TAG_DT:       RenderTagDT(Node, Ctx);
    TAG_DD:       RenderTagDD(Node, Ctx);

    { Balises de tableaux }
    TAG_TABLE:    RenderTagTable(Node, Ctx);
    TAG_THEAD:    RenderTagThead(Node, Ctx);
    TAG_TBODY:    RenderTagTbody(Node, Ctx);
    TAG_TR:       RenderTagTR(Node, Ctx);
    TAG_TD:       RenderTagTD(Node, Ctx);
    TAG_TH:       RenderTagTH(Node, Ctx);

    { Balises de formulaires }
    TAG_FORM:     RenderTagForm(Node, Ctx);
    TAG_INPUT:    RenderTagInput(Node, Ctx);
    TAG_BUTTON:   RenderTagButton(Node, Ctx);
    TAG_SELECT:   RenderTagSelect(Node, Ctx);
    TAG_OPTION:   RenderTagOption(Node, Ctx);
    TAG_TEXTAREA: RenderTagTextarea(Node, Ctx);
    TAG_LABEL:    RenderTagLabel(Node, Ctx);

    Else Begin
     { Balise non geree - rendre les enfants par defaut }
     RenderChildren(Node, Ctx);
    End;
   End;
  End;

  HTML_NODE_COMMENT: Begin
   { Commentaire - ne rien afficher }
  End;
 End;
End;

{ Procedure pour rendre un document HTML complet }
Procedure RenderHTMLDocument(Doc: HTMLNodePtr);
Var
 Ctx: RenderContext;
Begin
 If Doc = Nil Then Exit;

 { Initialiser le contexte de rendu }
 InitRenderContext(Ctx);

 { Effacer la zone de rendu }
 ClearRenderArea;

 { Rendre le document }
 RenderHTMLNode(Doc, Ctx);
End;

{ Procedure pour tester le rendu avec du HTML }
Procedure TestHTMLRender(Const HTMLSource: String);
Var
 Doc: HTMLNodePtr;
Begin
 Doc := ParseHTML(HTMLSource);
 If Doc <> Nil Then Begin
  RenderHTMLDocument(Doc);
  FreeHTMLNode(Doc);
 End;
End;

{ =====================================================
  FIN RENDU HTML
  ===================================================== }

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
 { Implementation du support souris pour Free Pascal via PtcMouse }

 Var
  PtcMouseLastX, PtcMouseLastY: Integer;
  PtcMouseLeftClickCount, PtcMouseRightClickCount: Integer;

 Function MouseDriverFound: Boolean;
 Begin
  { PtcMouse est toujours disponible sous Free Pascal avec PtcGraph }
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { PtcMouse gere automatiquement l'affichage du curseur }
  { Pas d'action necessaire }
 End;

 Procedure HideMouse;
 Begin
  { PtcMouse gere automatiquement l'affichage du curseur }
  { Pas d'action necessaire }
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Buttons: Word;
 Begin
  { Utiliser les fonctions de PtcMouse }
  X := GetMouseX;
  Y := GetMouseY;
  Buttons := GetMouseButtons;
  Button := 0;
  { Convertir les boutons PtcMouse au format standard }
  If (Buttons And MouseLeftButton) <> 0 Then
   Button := Button Or MOUSE_LEFT_BUTTON;
  If (Buttons And MouseRightButton) <> 0 Then
   Button := Button Or MOUSE_RIGHT_BUTTON;
  If (Buttons And MouseMiddleButton) <> 0 Then
   Button := Button Or MOUSE_MIDDLE_BUTTON;
 End;

 Procedure SetMouseHorizontalBounds(MinX, MaxX: Integer);
 Begin
  { PtcMouse ne supporte pas les limites personnalisees }
  { Le curseur est limite a la fenetre graphique automatiquement }
 End;

 Procedure SetMouseVerticalBounds(MinY, MaxY: Integer);
 Begin
  { PtcMouse ne supporte pas les limites personnalisees }
  { Le curseur est limite a la fenetre graphique automatiquement }
 End;

 Procedure SetMousePosition(X, Y: Integer);
 Begin
  { PtcMouse ne supporte pas le positionnement direct du curseur }
  { Sauvegarder la position pour reference }
  PtcMouseLastX := X;
  PtcMouseLastY := Y;
 End;

 Function GetMouseLeftClicks: Integer;
 Var
  Buttons: Word;
 Begin
  { Detecter les clics via l'etat des boutons }
  Buttons := GetMouseButtons;
  If (Buttons And MouseLeftButton) <> 0 Then Begin
   Inc(PtcMouseLeftClickCount);
   GetMouseLeftClicks := PtcMouseLeftClickCount;
  End
   Else
  GetMouseLeftClicks := 0;
 End;

 Function GetMouseRightClicks: Integer;
 Var
  Buttons: Word;
 Begin
  { Detecter les clics via l'etat des boutons }
  Buttons := GetMouseButtons;
  If (Buttons And MouseRightButton) <> 0 Then Begin
   Inc(PtcMouseRightClickCount);
   GetMouseRightClicks := PtcMouseRightClickCount;
  End
   Else
  GetMouseRightClicks := 0;
 End;

 Procedure GetMouseMotion(Var DeltaX, DeltaY: Integer);
 Var
  CurrentX, CurrentY: Integer;
 Begin
  { Calculer le deplacement depuis la derniere position }
  CurrentX := GetMouseX;
  CurrentY := GetMouseY;
  DeltaX := CurrentX - PtcMouseLastX;
  DeltaY := CurrentY - PtcMouseLastY;
  PtcMouseLastX := CurrentX;
  PtcMouseLastY := CurrentY;
 End;

 Procedure InitPtcMouseVars;
 Begin
  PtcMouseLastX := 0;
  PtcMouseLastY := 0;
  PtcMouseLeftClickCount := 0;
  PtcMouseRightClickCount := 0;
 End;
{$ENDIF}

{ Procedure pour initialiser la souris }
Procedure InitMouse;
Begin
 {$IFDEF FPC}
 InitPtcMouseVars;
 {$ENDIF}
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
 InitHTMLParser;
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