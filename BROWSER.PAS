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
  15. DONE: Implementer la detection et le rendu des liens hypertexte (balise <a href>)
  16. DONE: Implementer la navigation par clic sur les liens URL dans les pages
  17. DONE: Creer l'interpreteur JavaScript pour le support des scripts cote client
  18. DONE: Implementer le DOM (Document Object Model) pour la manipulation JavaScript
  19. DONE: Creer le parseur CSS pour le support des feuilles de style
  20. DONE: Implementer l'application des styles CSS aux elements HTML (cascade et heritage)
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
 RENDER_LINK_VISITED_COLOR = 5;{ Violet/Magenta }
 RENDER_LINK_ACTIVE_COLOR = 4; { Rouge }

 { Parametres pour les liens }
 MAX_LINKS = 100;              { Nombre maximum de liens sur une page }

 { Styles de texte (flags combinables) }
 TEXT_STYLE_NORMAL = 0;
 TEXT_STYLE_BOLD = 1;
 TEXT_STYLE_ITALIC = 2;
 TEXT_STYLE_UNDERLINE = 4;
 TEXT_STYLE_STRIKE = 8;
 TEXT_STYLE_CODE = 16;

 { =====================================================
   Constantes pour l'interpreteur JavaScript
   ===================================================== }

 { Types de tokens JavaScript }
 JS_TOK_EOF = 0;
 JS_TOK_NUMBER = 1;
 JS_TOK_STRING = 2;
 JS_TOK_IDENTIFIER = 3;
 JS_TOK_KEYWORD = 4;
 JS_TOK_OPERATOR = 5;
 JS_TOK_PUNCTUATOR = 6;
 JS_TOK_BOOLEAN = 7;
 JS_TOK_NULL = 8;
 JS_TOK_UNDEFINED = 9;

 { Types de valeurs JavaScript }
 JS_VAL_UNDEFINED = 0;
 JS_VAL_NULL = 1;
 JS_VAL_BOOLEAN = 2;
 JS_VAL_NUMBER = 3;
 JS_VAL_STRING = 4;
 JS_VAL_OBJECT = 5;
 JS_VAL_FUNCTION = 6;
 JS_VAL_ARRAY = 7;

 { Types d'operations JavaScript }
 JS_OP_ADD = 1;
 JS_OP_SUB = 2;
 JS_OP_MUL = 3;
 JS_OP_DIV = 4;
 JS_OP_MOD = 5;
 JS_OP_EQ = 6;
 JS_OP_NEQ = 7;
 JS_OP_LT = 8;
 JS_OP_GT = 9;
 JS_OP_LTE = 10;
 JS_OP_GTE = 11;
 JS_OP_AND = 12;
 JS_OP_OR = 13;
 JS_OP_NOT = 14;
 JS_OP_ASSIGN = 15;
 JS_OP_STRICT_EQ = 16;
 JS_OP_STRICT_NEQ = 17;

 { Mots-cles JavaScript }
 JS_KW_VAR = 1;
 JS_KW_LET = 2;
 JS_KW_CONST = 3;
 JS_KW_FUNCTION = 4;
 JS_KW_IF = 5;
 JS_KW_ELSE = 6;
 JS_KW_FOR = 7;
 JS_KW_WHILE = 8;
 JS_KW_DO = 9;
 JS_KW_RETURN = 10;
 JS_KW_BREAK = 11;
 JS_KW_CONTINUE = 12;
 JS_KW_TRUE = 13;
 JS_KW_FALSE = 14;
 JS_KW_NULL = 15;
 JS_KW_UNDEFINED = 16;
 JS_KW_NEW = 17;
 JS_KW_THIS = 18;
 JS_KW_TYPEOF = 19;

 { Limites de l'interpreteur JavaScript }
 MAX_JS_VARS = 256;              { Nombre maximum de variables }
 MAX_JS_STACK = 64;              { Taille maximale de la pile }
 MAX_JS_SCRIPT_SIZE = 32000;     { Taille maximale d'un script }
 MAX_JS_STRING_LEN = 1024;       { Longueur maximale d'une chaine }
 MAX_JS_FUNCTIONS = 64;          { Nombre maximum de fonctions }

 { =====================================================
   Constantes pour le DOM (Document Object Model)
   ===================================================== }

 { Types de noeuds DOM }
 DOM_NODE_ELEMENT = 1;           { Element HTML }
 DOM_NODE_TEXT = 3;              { Noeud texte }
 DOM_NODE_COMMENT = 8;           { Commentaire }
 DOM_NODE_DOCUMENT = 9;          { Document }
 DOM_NODE_DOCUMENT_FRAGMENT = 11;{ Fragment de document }

 { Limites du DOM }
 MAX_DOM_QUERY_RESULTS = 100;    { Nombre maximum de resultats de requete }
 MAX_DOM_EVENT_LISTENERS = 32;   { Nombre maximum de gestionnaires d'evenements }

 { Types d'evenements DOM }
 DOM_EVENT_CLICK = 1;
 DOM_EVENT_DBLCLICK = 2;
 DOM_EVENT_MOUSEDOWN = 3;
 DOM_EVENT_MOUSEUP = 4;
 DOM_EVENT_MOUSEOVER = 5;
 DOM_EVENT_MOUSEOUT = 6;
 DOM_EVENT_KEYDOWN = 7;
 DOM_EVENT_KEYUP = 8;
 DOM_EVENT_KEYPRESS = 9;
 DOM_EVENT_LOAD = 10;
 DOM_EVENT_UNLOAD = 11;
 DOM_EVENT_SUBMIT = 12;
 DOM_EVENT_CHANGE = 13;
 DOM_EVENT_FOCUS = 14;
 DOM_EVENT_BLUR = 15;

 { =====================================================
   Constantes pour le parseur CSS
   ===================================================== }

 { Types de tokens CSS }
 CSS_TOK_EOF = 0;
 CSS_TOK_IDENT = 1;          { Identifiant (nom de propriete, nom de classe, etc.) }
 CSS_TOK_STRING = 2;         { Chaine entre guillemets }
 CSS_TOK_NUMBER = 3;         { Nombre (entier ou decimal) }
 CSS_TOK_PERCENTAGE = 4;     { Pourcentage (10%) }
 CSS_TOK_DIMENSION = 5;      { Dimension avec unite (10px, 2em, etc.) }
 CSS_TOK_HASH = 6;           { #id ou #couleur }
 CSS_TOK_DOT = 7;            { . (selecteur de classe) }
 CSS_TOK_COLON = 8;          { : (pseudo-classe ou propriete:valeur) }
 CSS_TOK_SEMICOLON = 9;      { ; (fin de declaration) }
 CSS_TOK_LBRACE = 10;        { { (debut de bloc) }
 CSS_TOK_RBRACE = 11;        { } (fin de bloc) }
 CSS_TOK_LPAREN = 12;        { ( (debut de fonction) }
 CSS_TOK_RPAREN = 13;        { ) (fin de fonction) }
 CSS_TOK_COMMA = 14;         { , (separateur) }
 CSS_TOK_WHITESPACE = 15;    { Espace blanc }
 CSS_TOK_COMMENT = 16;       { Commentaire /* */ }
 CSS_TOK_GT = 17;            { > (selecteur enfant direct) }
 CSS_TOK_PLUS = 18;          { + (selecteur frere adjacent) }
 CSS_TOK_TILDE = 19;         { ~ (selecteur frere general) }
 CSS_TOK_STAR = 20;          { * (selecteur universel) }
 CSS_TOK_LBRACKET = 21;      { [ (selecteur d'attribut) }
 CSS_TOK_RBRACKET = 22;      { ] (fin selecteur d'attribut) }
 CSS_TOK_AT = 23;            { @ (at-rule comme @media, @import) }
 CSS_TOK_IMPORTANT = 24;     { !important }
 CSS_TOK_URL = 25;           { url(...) }
 CSS_TOK_FUNCTION = 26;      { nom-fonction( }

 { Types de selecteurs CSS }
 CSS_SEL_TAG = 1;            { Selecteur de balise (div, p, etc.) }
 CSS_SEL_CLASS = 2;          { Selecteur de classe (.classname) }
 CSS_SEL_ID = 3;             { Selecteur d'ID (#idname) }
 CSS_SEL_UNIVERSAL = 4;      { Selecteur universel (*) }
 CSS_SEL_ATTRIBUTE = 5;      { Selecteur d'attribut ([attr], [attr=val]) }
 CSS_SEL_PSEUDO_CLASS = 6;   { Pseudo-classe (:hover, :first-child) }
 CSS_SEL_PSEUDO_ELEMENT = 7; { Pseudo-element (::before, ::after) }

 { Combinateurs CSS }
 CSS_COMB_NONE = 0;          { Pas de combinateur (premier selecteur) }
 CSS_COMB_DESCENDANT = 1;    { Espace (descendant) }
 CSS_COMB_CHILD = 2;         { > (enfant direct) }
 CSS_COMB_ADJACENT = 3;      { + (frere adjacent) }
 CSS_COMB_SIBLING = 4;       { ~ (frere general) }

 { Limites du parseur CSS }
 MAX_CSS_RULES = 256;        { Nombre maximum de regles CSS }
 MAX_CSS_SELECTORS = 16;     { Selecteurs maximum par regle }
 MAX_CSS_PROPERTIES = 64;    { Proprietes maximum par regle }
 MAX_CSS_SELECTOR_PARTS = 8; { Parties maximum par selecteur compose }

 { Indices des proprietes CSS supportees }
 CSS_PROP_COLOR = 1;
 CSS_PROP_BACKGROUND_COLOR = 2;
 CSS_PROP_BACKGROUND = 3;
 CSS_PROP_FONT_SIZE = 4;
 CSS_PROP_FONT_WEIGHT = 5;
 CSS_PROP_FONT_STYLE = 6;
 CSS_PROP_FONT_FAMILY = 7;
 CSS_PROP_TEXT_DECORATION = 8;
 CSS_PROP_TEXT_ALIGN = 9;
 CSS_PROP_DISPLAY = 10;
 CSS_PROP_VISIBILITY = 11;
 CSS_PROP_WIDTH = 12;
 CSS_PROP_HEIGHT = 13;
 CSS_PROP_MARGIN = 14;
 CSS_PROP_MARGIN_TOP = 15;
 CSS_PROP_MARGIN_RIGHT = 16;
 CSS_PROP_MARGIN_BOTTOM = 17;
 CSS_PROP_MARGIN_LEFT = 18;
 CSS_PROP_PADDING = 19;
 CSS_PROP_PADDING_TOP = 20;
 CSS_PROP_PADDING_RIGHT = 21;
 CSS_PROP_PADDING_BOTTOM = 22;
 CSS_PROP_PADDING_LEFT = 23;
 CSS_PROP_BORDER = 24;
 CSS_PROP_BORDER_COLOR = 25;
 CSS_PROP_BORDER_WIDTH = 26;
 CSS_PROP_BORDER_STYLE = 27;
 CSS_PROP_POSITION = 28;
 CSS_PROP_TOP = 29;
 CSS_PROP_RIGHT = 30;
 CSS_PROP_LEFT = 31;
 CSS_PROP_BOTTOM = 32;
 CSS_PROP_FLOAT = 33;
 CSS_PROP_CLEAR = 34;
 CSS_PROP_LINE_HEIGHT = 35;
 CSS_PROP_OVERFLOW = 36;
 CSS_PROP_CURSOR = 37;
 CSS_PROP_LIST_STYLE = 38;
 CSS_PROP_LIST_STYLE_TYPE = 39;
 CSS_PROP_VERTICAL_ALIGN = 40;
 CSS_PROP_WHITE_SPACE = 41;
 CSS_PROP_UNKNOWN = 255;

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

 { Structure pour stocker les zones de liens cliquables }
 LinkArea = Record
  X1, Y1, X2, Y2: Integer;   { Rectangle de la zone cliquable }
  Href: String[255];         { URL du lien }
  Title: String[128];        { Titre du lien (attribut title) }
  Active: Boolean;           { Zone active ou non }
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
  InLink: Boolean;           { Dans un lien hypertexte }
  CurrentLinkHref: String[255]; { URL du lien en cours de rendu }
 End;

 { =====================================================
   Types pour l'interpreteur JavaScript
   ===================================================== }

 { Valeur JavaScript }
 JSValue = Record
  ValType: Byte;              { Type de la valeur (JS_VAL_*) }
  BoolVal: Boolean;           { Valeur booleenne }
  NumVal: Real;               { Valeur numerique }
  StrVal: String;             { Valeur chaine }
 End;

 { Token JavaScript }
 JSToken = Record
  TokType: Byte;              { Type du token (JS_TOK_*) }
  TokValue: String;           { Valeur textuelle du token }
  NumValue: Real;             { Valeur numerique (si nombre) }
  KeywordType: Byte;          { Type de mot-cle (si JS_TOK_KEYWORD) }
  Line: Integer;              { Numero de ligne }
  Column: Integer;            { Numero de colonne }
 End;

 { Variable JavaScript }
 JSVariable = Record
  Name: String[64];           { Nom de la variable }
  Value: JSValue;             { Valeur de la variable }
  IsConst: Boolean;           { Variable constante (const) }
 End;

 { Fonction JavaScript utilisateur }
 JSFunctionDef = Record
  Name: String[64];           { Nom de la fonction }
  Body: String;               { Corps de la fonction (code source) }
  ParamCount: Integer;        { Nombre de parametres }
  ParamNames: Array[1..10] Of String[32]; { Noms des parametres }
 End;

 { Contexte d'execution JavaScript }
 JSContext = Record
  Variables: Array[1..MAX_JS_VARS] Of JSVariable;
  VarCount: Integer;
  Functions: Array[1..MAX_JS_FUNCTIONS] Of JSFunctionDef;
  FuncCount: Integer;
  Stack: Array[1..MAX_JS_STACK] Of JSValue;
  StackTop: Integer;
  ErrorMsg: String;           { Message d'erreur }
  HasError: Boolean;          { Indicateur d'erreur }
  DocumentOutput: String;     { Sortie de document.write }
 End;

 { =====================================================
   Types pour le DOM (Document Object Model)
   ===================================================== }

 { Pointeur vers un element DOM (meme que HTMLNode pour l'instant) }
 DOMElementPtr = HTMLNodePtr;

 { Liste de noeuds DOM (resultat de requetes comme getElementsByTagName) }
 DOMNodeList = Record
  Nodes: Array[1..MAX_DOM_QUERY_RESULTS] Of HTMLNodePtr;
  Length: Integer;
 End;

 { Gestionnaire d'evenement DOM }
 DOMEventListener = Record
  EventType: Byte;            { Type d'evenement (DOM_EVENT_*) }
  Handler: String;            { Code JavaScript du gestionnaire }
  Element: HTMLNodePtr;       { Element cible }
  Active: Boolean;            { Gestionnaire actif }
 End;

 { Evenement DOM }
 DOMEvent = Record
  EventType: Byte;            { Type d'evenement }
  Target: HTMLNodePtr;        { Element cible }
  CurrentTarget: HTMLNodePtr; { Element courant }
  Bubbles: Boolean;           { L'evenement propage-t-il? }
  Cancelable: Boolean;        { L'evenement peut-il etre annule? }
  DefaultPrevented: Boolean;  { L'action par defaut a-t-elle ete annulee? }
  StopPropagation: Boolean;   { La propagation doit-elle s'arreter? }
 End;

 { Style CSS d'un element DOM }
 DOMStyle = Record
  Color: String[32];
  BackgroundColor: String[32];
  FontSize: String[16];
  FontWeight: String[16];
  FontStyle: String[16];
  TextDecoration: String[32];
  Display: String[16];
  Visibility: String[16];
  Width: String[16];
  Height: String[16];
  Margin: String[32];
  Padding: String[32];
  Border: String[32];
 End;

 { =====================================================
   Types pour le parseur CSS
   ===================================================== }

 { Token CSS }
 CSSToken = Record
  TokType: Byte;              { Type du token (CSS_TOK_*) }
  Value: String;              { Valeur textuelle du token }
  NumValue: Real;             { Valeur numerique (si nombre) }
  UnitValue: String[8];       { Unite (px, em, %, etc.) }
  Line: Integer;              { Numero de ligne }
  Column: Integer;            { Numero de colonne }
 End;

 { Partie d'un selecteur CSS compose }
 CSSSelectorPart = Record
  PartType: Byte;             { Type (CSS_SEL_*) }
  Value: String[64];          { Valeur (nom de balise, classe, id) }
  Combinator: Byte;           { Combinateur precedent (CSS_COMB_*) }
  AttrName: String[32];       { Nom d'attribut (pour selecteur d'attribut) }
  AttrValue: String[64];      { Valeur d'attribut }
  AttrOp: Byte;               { Operateur d'attribut (=, ~=, |=, etc.) }
 End;

 { Selecteur CSS complet (peut etre compose de plusieurs parties) }
 CSSSelector = Record
  Parts: Array[1..MAX_CSS_SELECTOR_PARTS] Of CSSSelectorPart;
  PartCount: Integer;
  Specificity: LongInt;       { Specificite (pour cascade) }
 End;

 { Propriete CSS }
 CSSProperty = Record
  PropId: Byte;               { ID de la propriete (CSS_PROP_*) }
  PropName: String[32];       { Nom de la propriete }
  Value: String;              { Valeur de la propriete }
  Important: Boolean;         { Flag !important }
 End;

 { Regle CSS (selecteurs + declarations) }
 CSSRule = Record
  Selectors: Array[1..MAX_CSS_SELECTORS] Of CSSSelector;
  SelectorCount: Integer;
  Properties: Array[1..MAX_CSS_PROPERTIES] Of CSSProperty;
  PropertyCount: Integer;
 End;

 { Feuille de style CSS }
 CSSStylesheet = Record
  Rules: Array[1..MAX_CSS_RULES] Of CSSRule;
  RuleCount: Integer;
 End;

 { Pointeur vers une feuille de style }
 CSSStylesheetPtr = ^CSSStylesheet;

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

 { Variables pour les zones de liens cliquables }
 LinkAreas: Array[1..MAX_LINKS] Of LinkArea;
 LinkCount: Integer;

 { Variables pour l'interpreteur JavaScript }
 JSCtx: JSContext;            { Contexte d'execution JavaScript }
 JSEnabled: Boolean;          { JavaScript active ou non }
 JSLastAlert: String;         { Dernier message d'alerte }

 { Variables pour le DOM }
 DOMEventListeners: Array[1..MAX_DOM_EVENT_LISTENERS] Of DOMEventListener;
 DOMEventListenerCount: Integer;

 { Variables pour le parseur CSS }
 CSSGlobalStylesheet: CSSStylesheet;  { Feuille de style globale }
 CSSParseError: String;               { Message d'erreur de parsing }
 CSSEnabled: Boolean;                 { CSS active ou non }

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
  INTERPRETEUR JAVASCRIPT
  ===================================================== }

{ Initialiser le contexte JavaScript }
Procedure InitJSContext;
Var
 I: Integer;
Begin
 JSCtx.VarCount := 0;
 JSCtx.FuncCount := 0;
 JSCtx.StackTop := 0;
 JSCtx.ErrorMsg := '';
 JSCtx.HasError := False;
 JSCtx.DocumentOutput := '';
 JSEnabled := True;
 JSLastAlert := '';

 For I := 1 To MAX_JS_VARS Do Begin
  JSCtx.Variables[I].Name := '';
  JSCtx.Variables[I].Value.ValType := JS_VAL_UNDEFINED;
 End;

 For I := 1 To MAX_JS_FUNCTIONS Do Begin
  JSCtx.Functions[I].Name := '';
  JSCtx.Functions[I].Body := '';
  JSCtx.Functions[I].ParamCount := 0;
 End;
End;

{ Creer une valeur JavaScript undefined }
Function JSUndefined: JSValue;
Var
 V: JSValue;
Begin
 V.ValType := JS_VAL_UNDEFINED;
 V.BoolVal := False;
 V.NumVal := 0;
 V.StrVal := '';
 JSUndefined := V;
End;

{ Creer une valeur JavaScript null }
Function JSNull: JSValue;
Var
 V: JSValue;
Begin
 V.ValType := JS_VAL_NULL;
 V.BoolVal := False;
 V.NumVal := 0;
 V.StrVal := '';
 JSNull := V;
End;

{ Creer une valeur JavaScript booleenne }
Function JSBool(B: Boolean): JSValue;
Var
 V: JSValue;
Begin
 V.ValType := JS_VAL_BOOLEAN;
 V.BoolVal := B;
 V.NumVal := 0;
 V.StrVal := '';
 JSBool := V;
End;

{ Creer une valeur JavaScript numerique }
Function JSNumber(N: Real): JSValue;
Var
 V: JSValue;
Begin
 V.ValType := JS_VAL_NUMBER;
 V.BoolVal := False;
 V.NumVal := N;
 V.StrVal := '';
 JSNumber := V;
End;

{ Creer une valeur JavaScript chaine }
Function JSString(S: String): JSValue;
Var
 V: JSValue;
Begin
 V.ValType := JS_VAL_STRING;
 V.BoolVal := False;
 V.NumVal := 0;
 V.StrVal := S;
 JSString := V;
End;

{ Convertir une valeur JavaScript en chaine }
Function JSValueToString(V: JSValue): String;
Var
 S: String;
Begin
 Case V.ValType Of
  JS_VAL_UNDEFINED: JSValueToString := 'undefined';
  JS_VAL_NULL: JSValueToString := 'null';
  JS_VAL_BOOLEAN: If V.BoolVal Then JSValueToString := 'true' Else JSValueToString := 'false';
  JS_VAL_NUMBER: Begin
   Str(V.NumVal:0:6, S);
   { Supprimer les zeros inutiles }
   While (Length(S) > 1) And (S[Length(S)] = '0') And (Pos('.', S) > 0) Do
    Delete(S, Length(S), 1);
   If S[Length(S)] = '.' Then Delete(S, Length(S), 1);
   JSValueToString := S;
  End;
  JS_VAL_STRING: JSValueToString := V.StrVal;
  JS_VAL_OBJECT: JSValueToString := '[object Object]';
  JS_VAL_FUNCTION: JSValueToString := '[function]';
  JS_VAL_ARRAY: JSValueToString := '[array]';
  Else JSValueToString := '';
 End;
End;

{ Convertir une valeur JavaScript en nombre }
Function JSValueToNumber(V: JSValue): Real;
Var
 Code: Integer;
 N: Real;
Begin
 Case V.ValType Of
  JS_VAL_UNDEFINED: JSValueToNumber := 0;
  JS_VAL_NULL: JSValueToNumber := 0;
  JS_VAL_BOOLEAN: If V.BoolVal Then JSValueToNumber := 1 Else JSValueToNumber := 0;
  JS_VAL_NUMBER: JSValueToNumber := V.NumVal;
  JS_VAL_STRING: Begin
   Val(V.StrVal, N, Code);
   If Code = 0 Then JSValueToNumber := N Else JSValueToNumber := 0;
  End;
  Else JSValueToNumber := 0;
 End;
End;

{ Convertir une valeur JavaScript en booleen }
Function JSValueToBool(V: JSValue): Boolean;
Begin
 Case V.ValType Of
  JS_VAL_UNDEFINED: JSValueToBool := False;
  JS_VAL_NULL: JSValueToBool := False;
  JS_VAL_BOOLEAN: JSValueToBool := V.BoolVal;
  JS_VAL_NUMBER: JSValueToBool := V.NumVal <> 0;
  JS_VAL_STRING: JSValueToBool := Length(V.StrVal) > 0;
  Else JSValueToBool := True;
 End;
End;

{ Verifier si un caractere est un chiffre }
Function JSIsDigit(C: Char): Boolean;
Begin
 JSIsDigit := (C >= '0') And (C <= '9');
End;

{ Verifier si un caractere est une lettre }
Function JSIsAlpha(C: Char): Boolean;
Begin
 JSIsAlpha := ((C >= 'a') And (C <= 'z')) Or ((C >= 'A') And (C <= 'Z')) Or (C = '_') Or (C = '$');
End;

{ Verifier si un caractere est alphanumerique }
Function JSIsAlphaNum(C: Char): Boolean;
Begin
 JSIsAlphaNum := JSIsAlpha(C) Or JSIsDigit(C);
End;

{ Verifier si un caractere est un espace blanc }
Function JSIsWhitespace(C: Char): Boolean;
Begin
 JSIsWhitespace := (C = ' ') Or (C = #9) Or (C = #10) Or (C = #13);
End;

{ Obtenir le type de mot-cle JavaScript }
Function JSGetKeywordType(S: String): Byte;
Begin
 If S = 'var' Then JSGetKeywordType := JS_KW_VAR
 Else If S = 'let' Then JSGetKeywordType := JS_KW_LET
 Else If S = 'const' Then JSGetKeywordType := JS_KW_CONST
 Else If S = 'function' Then JSGetKeywordType := JS_KW_FUNCTION
 Else If S = 'if' Then JSGetKeywordType := JS_KW_IF
 Else If S = 'else' Then JSGetKeywordType := JS_KW_ELSE
 Else If S = 'for' Then JSGetKeywordType := JS_KW_FOR
 Else If S = 'while' Then JSGetKeywordType := JS_KW_WHILE
 Else If S = 'do' Then JSGetKeywordType := JS_KW_DO
 Else If S = 'return' Then JSGetKeywordType := JS_KW_RETURN
 Else If S = 'break' Then JSGetKeywordType := JS_KW_BREAK
 Else If S = 'continue' Then JSGetKeywordType := JS_KW_CONTINUE
 Else If S = 'true' Then JSGetKeywordType := JS_KW_TRUE
 Else If S = 'false' Then JSGetKeywordType := JS_KW_FALSE
 Else If S = 'null' Then JSGetKeywordType := JS_KW_NULL
 Else If S = 'undefined' Then JSGetKeywordType := JS_KW_UNDEFINED
 Else If S = 'new' Then JSGetKeywordType := JS_KW_NEW
 Else If S = 'this' Then JSGetKeywordType := JS_KW_THIS
 Else If S = 'typeof' Then JSGetKeywordType := JS_KW_TYPEOF
 Else JSGetKeywordType := 0;
End;

{ Verifier si une chaine est un mot-cle JavaScript }
Function JSIsKeyword(S: String): Boolean;
Begin
 JSIsKeyword := JSGetKeywordType(S) <> 0;
End;

{ Chercher une variable par nom }
Function JSFindVariable(Name: String): Integer;
Var
 I: Integer;
Begin
 JSFindVariable := 0;
 For I := 1 To JSCtx.VarCount Do Begin
  If JSCtx.Variables[I].Name = Name Then Begin
   JSFindVariable := I;
   Exit;
  End;
 End;
End;

{ Definir ou mettre a jour une variable }
Procedure JSSetVariable(Name: String; Value: JSValue; IsConst: Boolean);
Var
 Idx: Integer;
Begin
 Idx := JSFindVariable(Name);
 If Idx > 0 Then Begin
  { Variable existante }
  If JSCtx.Variables[Idx].IsConst Then Begin
   JSCtx.HasError := True;
   JSCtx.ErrorMsg := 'TypeError: Assignment to constant variable: ' + Name;
  End Else
   JSCtx.Variables[Idx].Value := Value;
 End Else Begin
  { Nouvelle variable }
  If JSCtx.VarCount < MAX_JS_VARS Then Begin
   Inc(JSCtx.VarCount);
   JSCtx.Variables[JSCtx.VarCount].Name := Name;
   JSCtx.Variables[JSCtx.VarCount].Value := Value;
   JSCtx.Variables[JSCtx.VarCount].IsConst := IsConst;
  End Else Begin
   JSCtx.HasError := True;
   JSCtx.ErrorMsg := 'Error: Maximum number of variables exceeded';
  End;
 End;
End;

{ Obtenir la valeur d'une variable }
Function JSGetVariable(Name: String): JSValue;
Var
 Idx: Integer;
Begin
 Idx := JSFindVariable(Name);
 If Idx > 0 Then
  JSGetVariable := JSCtx.Variables[Idx].Value
 Else
  JSGetVariable := JSUndefined;
End;

{ Chercher une fonction par nom }
Function JSFindFunction(Name: String): Integer;
Var
 I: Integer;
Begin
 JSFindFunction := 0;
 For I := 1 To JSCtx.FuncCount Do Begin
  If JSCtx.Functions[I].Name = Name Then Begin
   JSFindFunction := I;
   Exit;
  End;
 End;
End;

{ Declaration forward pour l'evaluateur }
Function JSEvaluate(Const Script: String): JSValue; Forward;

{ Appeler une fonction utilisateur }
Function JSCallUserFunction(FuncIdx: Integer; Args: Array Of JSValue; ArgCount: Integer): JSValue;
Var
 I: Integer;
 OldVarCount: Integer;
Begin
 JSCallUserFunction := JSUndefined;
 If (FuncIdx < 1) Or (FuncIdx > JSCtx.FuncCount) Then Exit;

 { Sauvegarder l'etat des variables }
 OldVarCount := JSCtx.VarCount;

 { Definir les parametres comme variables locales }
 For I := 1 To JSCtx.Functions[FuncIdx].ParamCount Do Begin
  If I <= ArgCount Then
   JSSetVariable(JSCtx.Functions[FuncIdx].ParamNames[I], Args[I-1], False)
  Else
   JSSetVariable(JSCtx.Functions[FuncIdx].ParamNames[I], JSUndefined, False);
 End;

 { Executer le corps de la fonction }
 JSCallUserFunction := JSEvaluate(JSCtx.Functions[FuncIdx].Body);

 { Restaurer l'etat des variables (cleanup des variables locales) }
 JSCtx.VarCount := OldVarCount;
End;

{ Fonction native: alert() }
Procedure JSNativeAlert(Msg: String);
Begin
 JSLastAlert := Msg;
 { Dans une vraie implementation, on afficherait une boite de dialogue }
 { Pour l'instant, on stocke juste le message }
End;

{ Fonction native: console.log() }
Procedure JSNativeConsoleLog(Msg: String);
Begin
 { Dans une vraie implementation, on ecrirait dans une console }
 { Pour l'instant, on ne fait rien de visible }
End;

{ Fonction native: document.write() }
Procedure JSNativeDocumentWrite(Content: String);
Begin
 JSCtx.DocumentOutput := JSCtx.DocumentOutput + Content;
End;

{ Ignorer les espaces blancs dans le script }
Function JSSkipWhitespace(Const Script: String; Pos: Integer): Integer;
Begin
 While (Pos <= Length(Script)) And JSIsWhitespace(Script[Pos]) Do
  Inc(Pos);
 JSSkipWhitespace := Pos;
End;

{ Ignorer les commentaires JavaScript }
Function JSSkipComments(Const Script: String; Pos: Integer): Integer;
Begin
 Pos := JSSkipWhitespace(Script, Pos);
 { Commentaire sur une ligne // }
 If (Pos <= Length(Script) - 1) And (Script[Pos] = '/') And (Script[Pos + 1] = '/') Then Begin
  Inc(Pos, 2);
  While (Pos <= Length(Script)) And (Script[Pos] <> #10) And (Script[Pos] <> #13) Do
   Inc(Pos);
  Pos := JSSkipWhitespace(Script, Pos);
 End;
 { Commentaire multi-lignes /* */ }
 If (Pos <= Length(Script) - 1) And (Script[Pos] = '/') And (Script[Pos + 1] = '*') Then Begin
  Inc(Pos, 2);
  While (Pos <= Length(Script) - 1) And Not ((Script[Pos] = '*') And (Script[Pos + 1] = '/')) Do
   Inc(Pos);
  If Pos <= Length(Script) - 1 Then Inc(Pos, 2);
  Pos := JSSkipWhitespace(Script, Pos);
 End;
 JSSkipComments := Pos;
End;

{ Obtenir le prochain token du script }
Function JSGetNextToken(Const Script: String; Var Pos: Integer): JSToken;
Var
 Token: JSToken;
 StartPos: Integer;
 QuoteChar: Char;
 NumStr: String;
 Code: Integer;
Begin
 Token.TokType := JS_TOK_EOF;
 Token.TokValue := '';
 Token.NumValue := 0;
 Token.KeywordType := 0;
 Token.Line := 1;
 Token.Column := Pos;

 Pos := JSSkipComments(Script, Pos);

 If Pos > Length(Script) Then Begin
  JSGetNextToken := Token;
  Exit;
 End;

 { Nombre }
 If JSIsDigit(Script[Pos]) Or
    ((Script[Pos] = '.') And (Pos < Length(Script)) And JSIsDigit(Script[Pos + 1])) Then Begin
  Token.TokType := JS_TOK_NUMBER;
  StartPos := Pos;
  While (Pos <= Length(Script)) And (JSIsDigit(Script[Pos]) Or (Script[Pos] = '.')) Do
   Inc(Pos);
  Token.TokValue := Copy(Script, StartPos, Pos - StartPos);
  Val(Token.TokValue, Token.NumValue, Code);
  JSGetNextToken := Token;
  Exit;
 End;

 { Chaine de caracteres }
 If (Script[Pos] = '''') Or (Script[Pos] = '"') Or (Script[Pos] = '`') Then Begin
  Token.TokType := JS_TOK_STRING;
  QuoteChar := Script[Pos];
  Inc(Pos);
  StartPos := Pos;
  While (Pos <= Length(Script)) And (Script[Pos] <> QuoteChar) Do Begin
   If (Script[Pos] = '\') And (Pos < Length(Script)) Then Inc(Pos);
   Inc(Pos);
  End;
  Token.TokValue := Copy(Script, StartPos, Pos - StartPos);
  If Pos <= Length(Script) Then Inc(Pos);
  JSGetNextToken := Token;
  Exit;
 End;

 { Identifiant ou mot-cle }
 If JSIsAlpha(Script[Pos]) Then Begin
  StartPos := Pos;
  While (Pos <= Length(Script)) And JSIsAlphaNum(Script[Pos]) Do
   Inc(Pos);
  Token.TokValue := Copy(Script, StartPos, Pos - StartPos);
  Token.KeywordType := JSGetKeywordType(Token.TokValue);
  If Token.KeywordType <> 0 Then Begin
   Token.TokType := JS_TOK_KEYWORD;
   If Token.KeywordType = JS_KW_TRUE Then Begin
    Token.TokType := JS_TOK_BOOLEAN;
    Token.NumValue := 1;
   End Else If Token.KeywordType = JS_KW_FALSE Then Begin
    Token.TokType := JS_TOK_BOOLEAN;
    Token.NumValue := 0;
   End Else If Token.KeywordType = JS_KW_NULL Then
    Token.TokType := JS_TOK_NULL
   Else If Token.KeywordType = JS_KW_UNDEFINED Then
    Token.TokType := JS_TOK_UNDEFINED;
  End Else
   Token.TokType := JS_TOK_IDENTIFIER;
  JSGetNextToken := Token;
  Exit;
 End;

 { Operateurs multi-caracteres }
 If (Pos <= Length(Script) - 2) Then Begin
  If (Script[Pos] = '=') And (Script[Pos+1] = '=') And (Script[Pos+2] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '===';
   Inc(Pos, 3);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '!') And (Script[Pos+1] = '=') And (Script[Pos+2] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '!==';
   Inc(Pos, 3);
   JSGetNextToken := Token;
   Exit;
  End;
 End;

 If (Pos <= Length(Script) - 1) Then Begin
  If (Script[Pos] = '=') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '==';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '!') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '!=';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '<') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '<=';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '>') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '>=';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '&') And (Script[Pos+1] = '&') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '&&';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '|') And (Script[Pos+1] = '|') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '||';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '+') And (Script[Pos+1] = '+') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '++';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '-') And (Script[Pos+1] = '-') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '--';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '+') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '+=';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
  If (Script[Pos] = '-') And (Script[Pos+1] = '=') Then Begin
   Token.TokType := JS_TOK_OPERATOR;
   Token.TokValue := '-=';
   Inc(Pos, 2);
   JSGetNextToken := Token;
   Exit;
  End;
 End;

 { Operateurs et ponctuateurs simples }
 If Script[Pos] In ['+', '-', '*', '/', '%', '=', '<', '>', '!'] Then Begin
  Token.TokType := JS_TOK_OPERATOR;
  Token.TokValue := Script[Pos];
  Inc(Pos);
  JSGetNextToken := Token;
  Exit;
 End;

 If Script[Pos] In ['(', ')', '{', '}', '[', ']', ';', ',', '.', ':'] Then Begin
  Token.TokType := JS_TOK_PUNCTUATOR;
  Token.TokValue := Script[Pos];
  Inc(Pos);
  JSGetNextToken := Token;
  Exit;
 End;

 { Caractere inconnu - avancer }
 Inc(Pos);
 JSGetNextToken := Token;
End;

{ Evaluer une expression primaire (nombre, chaine, variable, parentheses) }
Function JSEvalPrimary(Const Script: String; Var Pos: Integer): JSValue;
Var
 Token: JSToken;
 VarName: String;
 FuncIdx: Integer;
 Args: Array[0..9] Of JSValue;
 ArgCount: Integer;
 SubExpr: String;
 ParenLevel: Integer;
 StartPos: Integer;
Begin
 JSEvalPrimary := JSUndefined;
 If JSCtx.HasError Then Exit;

 Token := JSGetNextToken(Script, Pos);

 Case Token.TokType Of
  JS_TOK_NUMBER: JSEvalPrimary := JSNumber(Token.NumValue);
  JS_TOK_STRING: JSEvalPrimary := JSString(Token.TokValue);
  JS_TOK_BOOLEAN: JSEvalPrimary := JSBool(Token.NumValue <> 0);
  JS_TOK_NULL: JSEvalPrimary := JSNull;
  JS_TOK_UNDEFINED: JSEvalPrimary := JSUndefined;

  JS_TOK_IDENTIFIER: Begin
   VarName := Token.TokValue;
   Pos := JSSkipComments(Script, Pos);

   { Verifier si c'est un appel de fonction }
   If (Pos <= Length(Script)) And (Script[Pos] = '(') Then Begin
    Inc(Pos);
    ArgCount := 0;

    { Collecter les arguments }
    Pos := JSSkipComments(Script, Pos);
    While (Pos <= Length(Script)) And (Script[Pos] <> ')') Do Begin
     If ArgCount < 10 Then Begin
      { Trouver l'argument jusqu'a la virgule ou la parenthese fermante }
      StartPos := Pos;
      ParenLevel := 0;
      While (Pos <= Length(Script)) Do Begin
       If Script[Pos] = '(' Then Inc(ParenLevel)
       Else If Script[Pos] = ')' Then Begin
        If ParenLevel = 0 Then Break;
        Dec(ParenLevel);
       End
       Else If (Script[Pos] = ',') And (ParenLevel = 0) Then Break;
       Inc(Pos);
      End;
      SubExpr := Copy(Script, StartPos, Pos - StartPos);
      Args[ArgCount] := JSEvaluate(SubExpr);
      Inc(ArgCount);
     End;
     If (Pos <= Length(Script)) And (Script[Pos] = ',') Then Inc(Pos);
     Pos := JSSkipComments(Script, Pos);
    End;
    If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);

    { Traiter les fonctions natives }
    If VarName = 'alert' Then Begin
     If ArgCount > 0 Then JSNativeAlert(JSValueToString(Args[0]));
     JSEvalPrimary := JSUndefined;
    End
    Else If VarName = 'parseInt' Then Begin
     If ArgCount > 0 Then JSEvalPrimary := JSNumber(Trunc(JSValueToNumber(Args[0])))
     Else JSEvalPrimary := JSNumber(0);
    End
    Else If VarName = 'parseFloat' Then Begin
     If ArgCount > 0 Then JSEvalPrimary := JSNumber(JSValueToNumber(Args[0]))
     Else JSEvalPrimary := JSNumber(0);
    End
    Else If VarName = 'String' Then Begin
     If ArgCount > 0 Then JSEvalPrimary := JSString(JSValueToString(Args[0]))
     Else JSEvalPrimary := JSString('');
    End
    Else If VarName = 'Number' Then Begin
     If ArgCount > 0 Then JSEvalPrimary := JSNumber(JSValueToNumber(Args[0]))
     Else JSEvalPrimary := JSNumber(0);
    End
    Else If VarName = 'Boolean' Then Begin
     If ArgCount > 0 Then JSEvalPrimary := JSBool(JSValueToBool(Args[0]))
     Else JSEvalPrimary := JSBool(False);
    End
    Else Begin
     { Fonction utilisateur }
     FuncIdx := JSFindFunction(VarName);
     If FuncIdx > 0 Then
      JSEvalPrimary := JSCallUserFunction(FuncIdx, Args, ArgCount)
     Else Begin
      JSCtx.HasError := True;
      JSCtx.ErrorMsg := 'ReferenceError: ' + VarName + ' is not defined';
     End;
    End;
   End

   { Verifier si c'est console.log ou document.write }
   Else If (Pos <= Length(Script)) And (Script[Pos] = '.') Then Begin
    Inc(Pos);
    Token := JSGetNextToken(Script, Pos);
    If (VarName = 'console') And (Token.TokValue = 'log') Then Begin
     { console.log() }
     Pos := JSSkipComments(Script, Pos);
     If (Pos <= Length(Script)) And (Script[Pos] = '(') Then Begin
      Inc(Pos);
      StartPos := Pos;
      ParenLevel := 1;
      While (Pos <= Length(Script)) And (ParenLevel > 0) Do Begin
       If Script[Pos] = '(' Then Inc(ParenLevel)
       Else If Script[Pos] = ')' Then Dec(ParenLevel);
       If ParenLevel > 0 Then Inc(Pos);
      End;
      SubExpr := Copy(Script, StartPos, Pos - StartPos);
      JSNativeConsoleLog(JSValueToString(JSEvaluate(SubExpr)));
      If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);
     End;
     JSEvalPrimary := JSUndefined;
    End
    Else If (VarName = 'document') And (Token.TokValue = 'write') Then Begin
     { document.write() }
     Pos := JSSkipComments(Script, Pos);
     If (Pos <= Length(Script)) And (Script[Pos] = '(') Then Begin
      Inc(Pos);
      StartPos := Pos;
      ParenLevel := 1;
      While (Pos <= Length(Script)) And (ParenLevel > 0) Do Begin
       If Script[Pos] = '(' Then Inc(ParenLevel)
       Else If Script[Pos] = ')' Then Dec(ParenLevel);
       If ParenLevel > 0 Then Inc(Pos);
      End;
      SubExpr := Copy(Script, StartPos, Pos - StartPos);
      JSNativeDocumentWrite(JSValueToString(JSEvaluate(SubExpr)));
      If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);
     End;
     JSEvalPrimary := JSUndefined;
    End
    Else Begin
     { Acces a une propriete d'objet - non supporte pour l'instant }
     JSEvalPrimary := JSUndefined;
    End;
   End
   Else Begin
    { Variable simple }
    JSEvalPrimary := JSGetVariable(VarName);
   End;
  End;

  JS_TOK_PUNCTUATOR: Begin
   If Token.TokValue = '(' Then Begin
    { Expression entre parentheses }
    StartPos := Pos;
    ParenLevel := 1;
    While (Pos <= Length(Script)) And (ParenLevel > 0) Do Begin
     If Script[Pos] = '(' Then Inc(ParenLevel)
     Else If Script[Pos] = ')' Then Dec(ParenLevel);
     If ParenLevel > 0 Then Inc(Pos);
    End;
    SubExpr := Copy(Script, StartPos, Pos - StartPos);
    JSEvalPrimary := JSEvaluate(SubExpr);
    If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);
   End;
  End;

  JS_TOK_OPERATOR: Begin
   { Operateur unaire - ou ! }
   If Token.TokValue = '-' Then
    JSEvalPrimary := JSNumber(-JSValueToNumber(JSEvalPrimary(Script, Pos)))
   Else If Token.TokValue = '!' Then
    JSEvalPrimary := JSBool(Not JSValueToBool(JSEvalPrimary(Script, Pos)))
   Else If Token.TokValue = '+' Then
    JSEvalPrimary := JSNumber(JSValueToNumber(JSEvalPrimary(Script, Pos)));
  End;
 End;
End;

{ Evaluer une expression multiplicative (* / %) }
Function JSEvalMultiplicative(Const Script: String; Var Pos: Integer): JSValue;
Var
 Left, Right: JSValue;
 Op: String;
 SavePos: Integer;
 Token: JSToken;
Begin
 Left := JSEvalPrimary(Script, Pos);
 If JSCtx.HasError Then Begin
  JSEvalMultiplicative := Left;
  Exit;
 End;

 While True Do Begin
  SavePos := Pos;
  Pos := JSSkipComments(Script, Pos);
  If Pos > Length(Script) Then Break;

  Token := JSGetNextToken(Script, Pos);
  Op := Token.TokValue;

  If (Op <> '*') And (Op <> '/') And (Op <> '%') Then Begin
   Pos := SavePos;
   Break;
  End;

  Right := JSEvalPrimary(Script, Pos);
  If JSCtx.HasError Then Break;

  If Op = '*' Then
   Left := JSNumber(JSValueToNumber(Left) * JSValueToNumber(Right))
  Else If Op = '/' Then Begin
   If JSValueToNumber(Right) = 0 Then Begin
    JSCtx.HasError := True;
    JSCtx.ErrorMsg := 'Error: Division by zero';
    Break;
   End;
   Left := JSNumber(JSValueToNumber(Left) / JSValueToNumber(Right));
  End
  Else If Op = '%' Then Begin
   If Trunc(JSValueToNumber(Right)) = 0 Then Begin
    JSCtx.HasError := True;
    JSCtx.ErrorMsg := 'Error: Division by zero';
    Break;
   End;
   Left := JSNumber(Trunc(JSValueToNumber(Left)) Mod Trunc(JSValueToNumber(Right)));
  End;
 End;

 JSEvalMultiplicative := Left;
End;

{ Evaluer une expression additive (+ -) }
Function JSEvalAdditive(Const Script: String; Var Pos: Integer): JSValue;
Var
 Left, Right: JSValue;
 Op: String;
 SavePos: Integer;
 Token: JSToken;
Begin
 Left := JSEvalMultiplicative(Script, Pos);
 If JSCtx.HasError Then Begin
  JSEvalAdditive := Left;
  Exit;
 End;

 While True Do Begin
  SavePos := Pos;
  Pos := JSSkipComments(Script, Pos);
  If Pos > Length(Script) Then Break;

  Token := JSGetNextToken(Script, Pos);
  Op := Token.TokValue;

  If (Op <> '+') And (Op <> '-') Then Begin
   Pos := SavePos;
   Break;
  End;

  Right := JSEvalMultiplicative(Script, Pos);
  If JSCtx.HasError Then Break;

  If Op = '+' Then Begin
   { Concatenation si l'un des operandes est une chaine }
   If (Left.ValType = JS_VAL_STRING) Or (Right.ValType = JS_VAL_STRING) Then
    Left := JSString(JSValueToString(Left) + JSValueToString(Right))
   Else
    Left := JSNumber(JSValueToNumber(Left) + JSValueToNumber(Right));
  End
  Else If Op = '-' Then
   Left := JSNumber(JSValueToNumber(Left) - JSValueToNumber(Right));
 End;

 JSEvalAdditive := Left;
End;

{ Evaluer une expression de comparaison (< > <= >= == != === !==) }
Function JSEvalComparison(Const Script: String; Var Pos: Integer): JSValue;
Var
 Left, Right: JSValue;
 Op: String;
 SavePos: Integer;
 Token: JSToken;
Begin
 Left := JSEvalAdditive(Script, Pos);
 If JSCtx.HasError Then Begin
  JSEvalComparison := Left;
  Exit;
 End;

 SavePos := Pos;
 Pos := JSSkipComments(Script, Pos);
 If Pos > Length(Script) Then Begin
  JSEvalComparison := Left;
  Exit;
 End;

 Token := JSGetNextToken(Script, Pos);
 Op := Token.TokValue;

 If (Op <> '<') And (Op <> '>') And (Op <> '<=') And (Op <> '>=') And
    (Op <> '==') And (Op <> '!=') And (Op <> '===') And (Op <> '!==') Then Begin
  Pos := SavePos;
  JSEvalComparison := Left;
  Exit;
 End;

 Right := JSEvalAdditive(Script, Pos);
 If JSCtx.HasError Then Begin
  JSEvalComparison := Left;
  Exit;
 End;

 If Op = '<' Then
  JSEvalComparison := JSBool(JSValueToNumber(Left) < JSValueToNumber(Right))
 Else If Op = '>' Then
  JSEvalComparison := JSBool(JSValueToNumber(Left) > JSValueToNumber(Right))
 Else If Op = '<=' Then
  JSEvalComparison := JSBool(JSValueToNumber(Left) <= JSValueToNumber(Right))
 Else If Op = '>=' Then
  JSEvalComparison := JSBool(JSValueToNumber(Left) >= JSValueToNumber(Right))
 Else If Op = '==' Then
  JSEvalComparison := JSBool(JSValueToString(Left) = JSValueToString(Right))
 Else If Op = '!=' Then
  JSEvalComparison := JSBool(JSValueToString(Left) <> JSValueToString(Right))
 Else If Op = '===' Then
  JSEvalComparison := JSBool((Left.ValType = Right.ValType) And
                             (JSValueToString(Left) = JSValueToString(Right)))
 Else If Op = '!==' Then
  JSEvalComparison := JSBool((Left.ValType <> Right.ValType) Or
                             (JSValueToString(Left) <> JSValueToString(Right)))
 Else
  JSEvalComparison := Left;
End;

{ Evaluer une expression logique (&& ||) }
Function JSEvalLogical(Const Script: String; Var Pos: Integer): JSValue;
Var
 Left, Right: JSValue;
 Op: String;
 SavePos: Integer;
 Token: JSToken;
Begin
 Left := JSEvalComparison(Script, Pos);
 If JSCtx.HasError Then Begin
  JSEvalLogical := Left;
  Exit;
 End;

 While True Do Begin
  SavePos := Pos;
  Pos := JSSkipComments(Script, Pos);
  If Pos > Length(Script) Then Break;

  Token := JSGetNextToken(Script, Pos);
  Op := Token.TokValue;

  If (Op <> '&&') And (Op <> '||') Then Begin
   Pos := SavePos;
   Break;
  End;

  { Short-circuit evaluation }
  If Op = '&&' Then Begin
   If Not JSValueToBool(Left) Then Begin
    JSEvalLogical := Left;
    Exit;
   End;
  End Else If Op = '||' Then Begin
   If JSValueToBool(Left) Then Begin
    JSEvalLogical := Left;
    Exit;
   End;
  End;

  Right := JSEvalComparison(Script, Pos);
  If JSCtx.HasError Then Break;

  Left := Right;
 End;

 JSEvalLogical := Left;
End;

{ Evaluer une expression complete }
Function JSEvalExpression(Const Script: String; Var Pos: Integer): JSValue;
Begin
 JSEvalExpression := JSEvalLogical(Script, Pos);
End;

{ Evaluer un script JavaScript }
Function JSEvaluate(Const Script: String): JSValue;
Var
 Pos: Integer;
 Token: JSToken;
 VarName: String;
 Value: JSValue;
 IsConst: Boolean;
 FuncName: String;
 FuncBody: String;
 BraceLevel: Integer;
 StartPos: Integer;
 ParamStr: String;
 I, J: Integer;
 CondExpr: String;
 ThenBlock: String;
 ElseBlock: String;
 CondValue: JSValue;
Begin
 JSEvaluate := JSUndefined;
 If Length(Script) = 0 Then Exit;
 If JSCtx.HasError Then Exit;

 Pos := 1;

 While Pos <= Length(Script) Do Begin
  Pos := JSSkipComments(Script, Pos);
  If Pos > Length(Script) Then Break;

  { Sauvegarder la position pour analyse }
  StartPos := Pos;
  Token := JSGetNextToken(Script, Pos);

  If Token.TokType = JS_TOK_EOF Then Break;

  { Declaration de variable (var, let, const) }
  If (Token.TokType = JS_TOK_KEYWORD) And
     ((Token.KeywordType = JS_KW_VAR) Or
      (Token.KeywordType = JS_KW_LET) Or
      (Token.KeywordType = JS_KW_CONST)) Then Begin
   IsConst := Token.KeywordType = JS_KW_CONST;

   Token := JSGetNextToken(Script, Pos);
   If Token.TokType <> JS_TOK_IDENTIFIER Then Begin
    JSCtx.HasError := True;
    JSCtx.ErrorMsg := 'SyntaxError: Expected identifier';
    Exit;
   End;
   VarName := Token.TokValue;

   Pos := JSSkipComments(Script, Pos);
   If (Pos <= Length(Script)) And (Script[Pos] = '=') Then Begin
    Inc(Pos);
    { Trouver la fin de l'expression (jusqu'au ; ou fin) }
    StartPos := Pos;
    While (Pos <= Length(Script)) And (Script[Pos] <> ';') Do
     Inc(Pos);
    Value := JSEvaluate(Copy(Script, StartPos, Pos - StartPos));
   End Else
    Value := JSUndefined;

   JSSetVariable(VarName, Value, IsConst);
   If (Pos <= Length(Script)) And (Script[Pos] = ';') Then Inc(Pos);
  End

  { Declaration de fonction }
  Else If (Token.TokType = JS_TOK_KEYWORD) And (Token.KeywordType = JS_KW_FUNCTION) Then Begin
   Token := JSGetNextToken(Script, Pos);
   If Token.TokType <> JS_TOK_IDENTIFIER Then Begin
    JSCtx.HasError := True;
    JSCtx.ErrorMsg := 'SyntaxError: Expected function name';
    Exit;
   End;
   FuncName := Token.TokValue;

   { Parametres }
   Pos := JSSkipComments(Script, Pos);
   If (Pos <= Length(Script)) And (Script[Pos] = '(') Then Begin
    Inc(Pos);
    StartPos := Pos;
    While (Pos <= Length(Script)) And (Script[Pos] <> ')') Do
     Inc(Pos);
    ParamStr := Copy(Script, StartPos, Pos - StartPos);
    If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);
   End Else
    ParamStr := '';

   { Corps de la fonction }
   Pos := JSSkipComments(Script, Pos);
   If (Pos <= Length(Script)) And (Script[Pos] = '{') Then Begin
    Inc(Pos);
    StartPos := Pos;
    BraceLevel := 1;
    While (Pos <= Length(Script)) And (BraceLevel > 0) Do Begin
     If Script[Pos] = '{' Then Inc(BraceLevel)
     Else If Script[Pos] = '}' Then Dec(BraceLevel);
     If BraceLevel > 0 Then Inc(Pos);
    End;
    FuncBody := Copy(Script, StartPos, Pos - StartPos);
    If (Pos <= Length(Script)) And (Script[Pos] = '}') Then Inc(Pos);
   End Else
    FuncBody := '';

   { Enregistrer la fonction }
   If JSCtx.FuncCount < MAX_JS_FUNCTIONS Then Begin
    Inc(JSCtx.FuncCount);
    JSCtx.Functions[JSCtx.FuncCount].Name := FuncName;
    JSCtx.Functions[JSCtx.FuncCount].Body := FuncBody;
    JSCtx.Functions[JSCtx.FuncCount].ParamCount := 0;

    { Parser les parametres }
    I := 1;
    J := 0;
    While I <= Length(ParamStr) Do Begin
     While (I <= Length(ParamStr)) And (ParamStr[I] In [' ', ',']) Do Inc(I);
     StartPos := I;
     While (I <= Length(ParamStr)) And Not (ParamStr[I] In [' ', ',']) Do Inc(I);
     If I > StartPos Then Begin
      Inc(J);
      If J <= 10 Then
       JSCtx.Functions[JSCtx.FuncCount].ParamNames[J] := Copy(ParamStr, StartPos, I - StartPos);
     End;
    End;
    JSCtx.Functions[JSCtx.FuncCount].ParamCount := J;
   End;
  End

  { Instruction if }
  Else If (Token.TokType = JS_TOK_KEYWORD) And (Token.KeywordType = JS_KW_IF) Then Begin
   { Condition }
   Pos := JSSkipComments(Script, Pos);
   If (Pos <= Length(Script)) And (Script[Pos] = '(') Then Begin
    Inc(Pos);
    StartPos := Pos;
    BraceLevel := 1;
    While (Pos <= Length(Script)) And (BraceLevel > 0) Do Begin
     If Script[Pos] = '(' Then Inc(BraceLevel)
     Else If Script[Pos] = ')' Then Dec(BraceLevel);
     If BraceLevel > 0 Then Inc(Pos);
    End;
    CondExpr := Copy(Script, StartPos, Pos - StartPos);
    If (Pos <= Length(Script)) And (Script[Pos] = ')') Then Inc(Pos);
   End Else
    CondExpr := '';

   { Bloc then }
   Pos := JSSkipComments(Script, Pos);
   If (Pos <= Length(Script)) And (Script[Pos] = '{') Then Begin
    Inc(Pos);
    StartPos := Pos;
    BraceLevel := 1;
    While (Pos <= Length(Script)) And (BraceLevel > 0) Do Begin
     If Script[Pos] = '{' Then Inc(BraceLevel)
     Else If Script[Pos] = '}' Then Dec(BraceLevel);
     If BraceLevel > 0 Then Inc(Pos);
    End;
    ThenBlock := Copy(Script, StartPos, Pos - StartPos);
    If (Pos <= Length(Script)) And (Script[Pos] = '}') Then Inc(Pos);
   End Else
    ThenBlock := '';

   { Bloc else optionnel }
   ElseBlock := '';
   Pos := JSSkipComments(Script, Pos);
   StartPos := Pos;
   Token := JSGetNextToken(Script, Pos);
   If (Token.TokType = JS_TOK_KEYWORD) And (Token.KeywordType = JS_KW_ELSE) Then Begin
    Pos := JSSkipComments(Script, Pos);
    If (Pos <= Length(Script)) And (Script[Pos] = '{') Then Begin
     Inc(Pos);
     StartPos := Pos;
     BraceLevel := 1;
     While (Pos <= Length(Script)) And (BraceLevel > 0) Do Begin
      If Script[Pos] = '{' Then Inc(BraceLevel)
      Else If Script[Pos] = '}' Then Dec(BraceLevel);
      If BraceLevel > 0 Then Inc(Pos);
     End;
     ElseBlock := Copy(Script, StartPos, Pos - StartPos);
     If (Pos <= Length(Script)) And (Script[Pos] = '}') Then Inc(Pos);
    End;
   End Else
    Pos := StartPos;

   { Evaluer la condition et executer le bloc approprie }
   CondValue := JSEvaluate(CondExpr);
   If JSValueToBool(CondValue) Then
    JSEvaluate := JSEvaluate(ThenBlock)
   Else If Length(ElseBlock) > 0 Then
    JSEvaluate := JSEvaluate(ElseBlock);
  End

  { Instruction return }
  Else If (Token.TokType = JS_TOK_KEYWORD) And (Token.KeywordType = JS_KW_RETURN) Then Begin
   StartPos := Pos;
   While (Pos <= Length(Script)) And (Script[Pos] <> ';') Do
    Inc(Pos);
   JSEvaluate := JSEvaluate(Copy(Script, StartPos, Pos - StartPos));
   If (Pos <= Length(Script)) And (Script[Pos] = ';') Then Inc(Pos);
   Exit;
  End

  { Expression simple (affectation ou appel de fonction) }
  Else If Token.TokType = JS_TOK_IDENTIFIER Then Begin
   VarName := Token.TokValue;
   Pos := JSSkipComments(Script, Pos);

   { Affectation }
   If (Pos <= Length(Script)) And (Script[Pos] = '=') And
      ((Pos >= Length(Script)) Or (Script[Pos+1] <> '=')) Then Begin
    Inc(Pos);
    StartPos := Pos;
    While (Pos <= Length(Script)) And (Script[Pos] <> ';') Do
     Inc(Pos);
    Value := JSEvaluate(Copy(Script, StartPos, Pos - StartPos));
    JSSetVariable(VarName, Value, False);
    If (Pos <= Length(Script)) And (Script[Pos] = ';') Then Inc(Pos);
   End Else Begin
    { Autre expression - revenir en arriere et evaluer }
    Pos := StartPos;
    StartPos := Pos;
    While (Pos <= Length(Script)) And (Script[Pos] <> ';') Do
     Inc(Pos);
    JSEvaluate := JSEvaluate(Copy(Script, StartPos, Pos - StartPos));
    If (Pos <= Length(Script)) And (Script[Pos] = ';') Then Inc(Pos);
   End;
  End

  { Point-virgule seul }
  Else If (Token.TokType = JS_TOK_PUNCTUATOR) And (Token.TokValue = ';') Then Begin
   { Instruction vide, continuer }
  End

  { Autre expression }
  Else Begin
   Pos := StartPos;
   StartPos := Pos;
   While (Pos <= Length(Script)) And (Script[Pos] <> ';') Do
    Inc(Pos);
   If Pos > StartPos Then
    JSEvaluate := JSEvalExpression(Copy(Script, StartPos, Pos - StartPos), StartPos);
   If (Pos <= Length(Script)) And (Script[Pos] = ';') Then Inc(Pos);
  End;

  If JSCtx.HasError Then Exit;
 End;
End;

{ Executer un script JavaScript }
Procedure JSExecuteScript(Const Script: String);
Begin
 If Not JSEnabled Then Exit;
 If Length(Script) = 0 Then Exit;

 JSCtx.HasError := False;
 JSCtx.ErrorMsg := '';
 JSEvaluate(Script);
End;

{ Obtenir la sortie de document.write }
Function JSGetDocumentOutput: String;
Begin
 JSGetDocumentOutput := JSCtx.DocumentOutput;
End;

{ Effacer la sortie de document.write }
Procedure JSClearDocumentOutput;
Begin
 JSCtx.DocumentOutput := '';
End;

{ =====================================================
  FIN INTERPRETEUR JAVASCRIPT
  ===================================================== }

{ =====================================================
  DOM (Document Object Model) - Fonctions et procedures
  ===================================================== }

{ Initialiser le DOM }
Procedure InitDOM;
Var
 I: Integer;
Begin
 DOMEventListenerCount := 0;
 For I := 1 To MAX_DOM_EVENT_LISTENERS Do Begin
  DOMEventListeners[I].Active := False;
  DOMEventListeners[I].EventType := 0;
  DOMEventListeners[I].Handler := '';
  DOMEventListeners[I].Element := Nil;
 End;
End;

{ Obtenir un attribut d'un noeud HTML }
Function DOMGetAttribute(Node: HTMLNodePtr; AttrName: String): String;
Var
 I: Integer;
 LowerAttr, LowerName: String;
Begin
 DOMGetAttribute := '';
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 For I := 1 To Node^.AttributeCount Do Begin
  LowerName := HTMLLowerCase(Node^.Attributes[I].Name);
  If LowerName = LowerAttr Then Begin
   DOMGetAttribute := Node^.Attributes[I].Value;
   Exit;
  End;
 End;
End;

{ Definir un attribut sur un noeud HTML }
Procedure DOMSetAttribute(Node: HTMLNodePtr; AttrName, AttrValue: String);
Var
 I: Integer;
 LowerAttr, LowerName: String;
 Found: Boolean;
Begin
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 Found := False;

 { Chercher si l'attribut existe deja }
 For I := 1 To Node^.AttributeCount Do Begin
  LowerName := HTMLLowerCase(Node^.Attributes[I].Name);
  If LowerName = LowerAttr Then Begin
   Node^.Attributes[I].Value := AttrValue;
   Found := True;
   Break;
  End;
 End;

 { Ajouter un nouvel attribut si non trouve }
 If Not Found And (Node^.AttributeCount < MAX_ATTRIBUTES) Then Begin
  Inc(Node^.AttributeCount);
  Node^.Attributes[Node^.AttributeCount].Name := AttrName;
  Node^.Attributes[Node^.AttributeCount].Value := AttrValue;
 End;
End;

{ Supprimer un attribut d'un noeud HTML }
Procedure DOMRemoveAttribute(Node: HTMLNodePtr; AttrName: String);
Var
 I, J: Integer;
 LowerAttr, LowerName: String;
Begin
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);

 For I := 1 To Node^.AttributeCount Do Begin
  LowerName := HTMLLowerCase(Node^.Attributes[I].Name);
  If LowerName = LowerAttr Then Begin
   { Decaler tous les attributs suivants }
   For J := I To Node^.AttributeCount - 1 Do
    Node^.Attributes[J] := Node^.Attributes[J + 1];
   Dec(Node^.AttributeCount);
   Exit;
  End;
 End;
End;

{ Verifier si un noeud a un attribut }
Function DOMHasAttribute(Node: HTMLNodePtr; AttrName: String): Boolean;
Var
 I: Integer;
 LowerAttr, LowerName: String;
Begin
 DOMHasAttribute := False;
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 For I := 1 To Node^.AttributeCount Do Begin
  LowerName := HTMLLowerCase(Node^.Attributes[I].Name);
  If LowerName = LowerAttr Then Begin
   DOMHasAttribute := True;
   Exit;
  End;
 End;
End;

{ Fonction recursive pour chercher un element par ID }
Function DOMGetElementByIdRecursive(Node: HTMLNodePtr; Id: String): HTMLNodePtr;
Var
 I: Integer;
 NodeId: String;
 Result: HTMLNodePtr;
Begin
 DOMGetElementByIdRecursive := Nil;
 If Node = Nil Then Exit;

 { Verifier l'ID de ce noeud }
 NodeId := DOMGetAttribute(Node, 'id');
 If NodeId = Id Then Begin
  DOMGetElementByIdRecursive := Node;
  Exit;
 End;

 { Parcourir les enfants }
 For I := 1 To Node^.ChildCount Do Begin
  Result := DOMGetElementByIdRecursive(Node^.Children[I], Id);
  If Result <> Nil Then Begin
   DOMGetElementByIdRecursive := Result;
   Exit;
  End;
 End;
End;

{ Obtenir un element par son ID (document.getElementById) }
Function DOMGetElementById(Id: String): HTMLNodePtr;
Begin
 DOMGetElementById := DOMGetElementByIdRecursive(HTMLDocument, Id);
End;

{ Procedure recursive pour chercher des elements par nom de balise }
Procedure DOMGetElementsByTagNameRecursive(Node: HTMLNodePtr; TagName: String; Var List: DOMNodeList);
Var
 I: Integer;
 LowerTag, LowerNodeTag: String;
Begin
 If Node = Nil Then Exit;

 LowerTag := HTMLLowerCase(TagName);

 { Verifier le nom de balise de ce noeud }
 If Node^.NodeType = HTML_NODE_ELEMENT Then Begin
  LowerNodeTag := HTMLLowerCase(Node^.TagName);
  If (LowerTag = '*') Or (LowerNodeTag = LowerTag) Then Begin
   If List.Length < MAX_DOM_QUERY_RESULTS Then Begin
    Inc(List.Length);
    List.Nodes[List.Length] := Node;
   End;
  End;
 End;

 { Parcourir les enfants }
 For I := 1 To Node^.ChildCount Do
  DOMGetElementsByTagNameRecursive(Node^.Children[I], TagName, List);
End;

{ Obtenir des elements par nom de balise (document.getElementsByTagName) }
Function DOMGetElementsByTagName(TagName: String): DOMNodeList;
Var
 List: DOMNodeList;
Begin
 List.Length := 0;
 DOMGetElementsByTagNameRecursive(HTMLDocument, TagName, List);
 DOMGetElementsByTagName := List;
End;

{ Verifier si un noeud a une classe specifique }
Function DOMHasClass(Node: HTMLNodePtr; ClassName: String): Boolean;
Var
 ClassAttr: String;
 I, StartPos: Integer;
 CurrentClass: String;
Begin
 DOMHasClass := False;
 If Node = Nil Then Exit;

 ClassAttr := DOMGetAttribute(Node, 'class');
 If ClassAttr = '' Then Exit;

 { Parser les classes (separees par des espaces) }
 StartPos := 1;
 For I := 1 To Length(ClassAttr) + 1 Do Begin
  If (I > Length(ClassAttr)) Or (ClassAttr[I] = ' ') Then Begin
   If I > StartPos Then Begin
    CurrentClass := Copy(ClassAttr, StartPos, I - StartPos);
    If CurrentClass = ClassName Then Begin
     DOMHasClass := True;
     Exit;
    End;
   End;
   StartPos := I + 1;
  End;
 End;
End;

{ Procedure recursive pour chercher des elements par classe }
Procedure DOMGetElementsByClassNameRecursive(Node: HTMLNodePtr; ClassName: String; Var List: DOMNodeList);
Var
 I: Integer;
Begin
 If Node = Nil Then Exit;

 { Verifier la classe de ce noeud }
 If DOMHasClass(Node, ClassName) Then Begin
  If List.Length < MAX_DOM_QUERY_RESULTS Then Begin
   Inc(List.Length);
   List.Nodes[List.Length] := Node;
  End;
 End;

 { Parcourir les enfants }
 For I := 1 To Node^.ChildCount Do
  DOMGetElementsByClassNameRecursive(Node^.Children[I], ClassName, List);
End;

{ Obtenir des elements par classe (document.getElementsByClassName) }
Function DOMGetElementsByClassName(ClassName: String): DOMNodeList;
Var
 List: DOMNodeList;
Begin
 List.Length := 0;
 DOMGetElementsByClassNameRecursive(HTMLDocument, ClassName, List);
 DOMGetElementsByClassName := List;
End;

{ Obtenir le texte d'un noeud (innerText/textContent) }
Function DOMGetTextContent(Node: HTMLNodePtr): String;
Var
 I: Integer;
 Result: String;
Begin
 Result := '';
 If Node = Nil Then Begin
  DOMGetTextContent := Result;
  Exit;
 End;

 If Node^.NodeType = HTML_NODE_TEXT Then
  Result := Node^.Content
 Else Begin
  For I := 1 To Node^.ChildCount Do
   Result := Result + DOMGetTextContent(Node^.Children[I]);
 End;

 DOMGetTextContent := Result;
End;

{ Definir le texte d'un noeud (innerText/textContent) }
Procedure DOMSetTextContent(Node: HTMLNodePtr; Text: String);
Begin
 If Node = Nil Then Exit;

 { Supprimer tous les enfants existants }
 Node^.ChildCount := 0;

 { Creer un nouveau noeud texte comme seul enfant }
 If Length(Text) > 0 Then Begin
  New(Node^.Children[1]);
  Node^.Children[1]^.NodeType := HTML_NODE_TEXT;
  Node^.Children[1]^.TagType := 0;
  Node^.Children[1]^.TagName := '';
  Node^.Children[1]^.Content := Text;
  Node^.Children[1]^.AttributeCount := 0;
  Node^.Children[1]^.ChildCount := 0;
  Node^.Children[1]^.Parent := Node;
  Node^.ChildCount := 1;
 End;
End;

{ Creer un nouvel element HTML (document.createElement) }
Function DOMCreateElement(TagName: String): HTMLNodePtr;
Var
 NewNode: HTMLNodePtr;
Begin
 New(NewNode);
 NewNode^.NodeType := HTML_NODE_ELEMENT;
 NewNode^.TagType := GetTagType(TagName);
 NewNode^.TagName := TagName;
 NewNode^.Content := '';
 NewNode^.AttributeCount := 0;
 NewNode^.ChildCount := 0;
 NewNode^.Parent := Nil;
 DOMCreateElement := NewNode;
End;

{ Creer un noeud texte (document.createTextNode) }
Function DOMCreateTextNode(Text: String): HTMLNodePtr;
Var
 NewNode: HTMLNodePtr;
Begin
 New(NewNode);
 NewNode^.NodeType := HTML_NODE_TEXT;
 NewNode^.TagType := 0;
 NewNode^.TagName := '';
 NewNode^.Content := Text;
 NewNode^.AttributeCount := 0;
 NewNode^.ChildCount := 0;
 NewNode^.Parent := Nil;
 DOMCreateTextNode := NewNode;
End;

{ Ajouter un enfant a un element (appendChild) }
Function DOMAppendChild(Parent, Child: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMAppendChild := Nil;
 If (Parent = Nil) Or (Child = Nil) Then Exit;

 If Parent^.ChildCount < MAX_CHILDREN Then Begin
  Inc(Parent^.ChildCount);
  Parent^.Children[Parent^.ChildCount] := Child;
  Child^.Parent := Parent;
  DOMAppendChild := Child;
 End;
End;

{ Inserer un enfant avant un autre (insertBefore) }
Function DOMInsertBefore(Parent, NewChild, RefChild: HTMLNodePtr): HTMLNodePtr;
Var
 I, J, RefIndex: Integer;
Begin
 DOMInsertBefore := Nil;
 If (Parent = Nil) Or (NewChild = Nil) Then Exit;

 If RefChild = Nil Then Begin
  { Inserer a la fin si pas de reference }
  DOMInsertBefore := DOMAppendChild(Parent, NewChild);
  Exit;
 End;

 { Trouver l'index de l'enfant de reference }
 RefIndex := 0;
 For I := 1 To Parent^.ChildCount Do Begin
  If Parent^.Children[I] = RefChild Then Begin
   RefIndex := I;
   Break;
  End;
 End;

 If RefIndex = 0 Then Exit; { Enfant de reference non trouve }

 If Parent^.ChildCount >= MAX_CHILDREN Then Exit;

 { Decaler les enfants suivants }
 Inc(Parent^.ChildCount);
 For J := Parent^.ChildCount DownTo RefIndex + 1 Do
  Parent^.Children[J] := Parent^.Children[J - 1];

 { Inserer le nouvel enfant }
 Parent^.Children[RefIndex] := NewChild;
 NewChild^.Parent := Parent;
 DOMInsertBefore := NewChild;
End;

{ Supprimer un enfant (removeChild) }
Function DOMRemoveChild(Parent, Child: HTMLNodePtr): HTMLNodePtr;
Var
 I, J, ChildIndex: Integer;
Begin
 DOMRemoveChild := Nil;
 If (Parent = Nil) Or (Child = Nil) Then Exit;

 { Trouver l'index de l'enfant }
 ChildIndex := 0;
 For I := 1 To Parent^.ChildCount Do Begin
  If Parent^.Children[I] = Child Then Begin
   ChildIndex := I;
   Break;
  End;
 End;

 If ChildIndex = 0 Then Exit; { Enfant non trouve }

 { Decaler les enfants suivants }
 For J := ChildIndex To Parent^.ChildCount - 1 Do
  Parent^.Children[J] := Parent^.Children[J + 1];
 Dec(Parent^.ChildCount);

 Child^.Parent := Nil;
 DOMRemoveChild := Child;
End;

{ Remplacer un enfant (replaceChild) }
Function DOMReplaceChild(Parent, NewChild, OldChild: HTMLNodePtr): HTMLNodePtr;
Var
 I: Integer;
Begin
 DOMReplaceChild := Nil;
 If (Parent = Nil) Or (NewChild = Nil) Or (OldChild = Nil) Then Exit;

 For I := 1 To Parent^.ChildCount Do Begin
  If Parent^.Children[I] = OldChild Then Begin
   Parent^.Children[I] := NewChild;
   NewChild^.Parent := Parent;
   OldChild^.Parent := Nil;
   DOMReplaceChild := OldChild;
   Exit;
  End;
 End;
End;

{ Cloner un noeud (cloneNode) }
Function DOMCloneNode(Node: HTMLNodePtr; Deep: Boolean): HTMLNodePtr;
Var
 Clone, ChildClone: HTMLNodePtr;
 I: Integer;
Begin
 DOMCloneNode := Nil;
 If Node = Nil Then Exit;

 New(Clone);
 Clone^.NodeType := Node^.NodeType;
 Clone^.TagType := Node^.TagType;
 Clone^.TagName := Node^.TagName;
 Clone^.Content := Node^.Content;
 Clone^.AttributeCount := Node^.AttributeCount;
 Clone^.ChildCount := 0;
 Clone^.Parent := Nil;

 { Copier les attributs }
 For I := 1 To Node^.AttributeCount Do
  Clone^.Attributes[I] := Node^.Attributes[I];

 { Cloner les enfants si demande }
 If Deep Then Begin
  For I := 1 To Node^.ChildCount Do Begin
   ChildClone := DOMCloneNode(Node^.Children[I], True);
   If ChildClone <> Nil Then Begin
    Inc(Clone^.ChildCount);
    Clone^.Children[Clone^.ChildCount] := ChildClone;
    ChildClone^.Parent := Clone;
   End;
  End;
 End;

 DOMCloneNode := Clone;
End;

{ Obtenir le parent d'un noeud (parentNode/parentElement) }
Function DOMGetParentNode(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 If Node = Nil Then
  DOMGetParentNode := Nil
 Else
  DOMGetParentNode := Node^.Parent;
End;

{ Obtenir le premier enfant (firstChild) }
Function DOMGetFirstChild(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 If (Node = Nil) Or (Node^.ChildCount = 0) Then
  DOMGetFirstChild := Nil
 Else
  DOMGetFirstChild := Node^.Children[1];
End;

{ Obtenir le dernier enfant (lastChild) }
Function DOMGetLastChild(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 If (Node = Nil) Or (Node^.ChildCount = 0) Then
  DOMGetLastChild := Nil
 Else
  DOMGetLastChild := Node^.Children[Node^.ChildCount];
End;

{ Obtenir le frere precedent (previousSibling) }
Function DOMGetPreviousSibling(Node: HTMLNodePtr): HTMLNodePtr;
Var
 Parent: HTMLNodePtr;
 I: Integer;
Begin
 DOMGetPreviousSibling := Nil;
 If Node = Nil Then Exit;

 Parent := Node^.Parent;
 If Parent = Nil Then Exit;

 For I := 2 To Parent^.ChildCount Do Begin
  If Parent^.Children[I] = Node Then Begin
   DOMGetPreviousSibling := Parent^.Children[I - 1];
   Exit;
  End;
 End;
End;

{ Obtenir le frere suivant (nextSibling) }
Function DOMGetNextSibling(Node: HTMLNodePtr): HTMLNodePtr;
Var
 Parent: HTMLNodePtr;
 I: Integer;
Begin
 DOMGetNextSibling := Nil;
 If Node = Nil Then Exit;

 Parent := Node^.Parent;
 If Parent = Nil Then Exit;

 For I := 1 To Parent^.ChildCount - 1 Do Begin
  If Parent^.Children[I] = Node Then Begin
   DOMGetNextSibling := Parent^.Children[I + 1];
   Exit;
  End;
 End;
End;

{ Obtenir le nombre d'enfants (childNodes.length) }
Function DOMGetChildCount(Node: HTMLNodePtr): Integer;
Begin
 If Node = Nil Then
  DOMGetChildCount := 0
 Else
  DOMGetChildCount := Node^.ChildCount;
End;

{ Verifier si un noeud a des enfants (hasChildNodes) }
Function DOMHasChildNodes(Node: HTMLNodePtr): Boolean;
Begin
 If Node = Nil Then
  DOMHasChildNodes := False
 Else
  DOMHasChildNodes := Node^.ChildCount > 0;
End;

{ Ajouter un gestionnaire d'evenement (addEventListener) }
Procedure DOMAddEventListener(Element: HTMLNodePtr; EventType: Byte; Handler: String);
Var
 I: Integer;
Begin
 If Element = Nil Then Exit;
 If DOMEventListenerCount >= MAX_DOM_EVENT_LISTENERS Then Exit;

 { Verifier si ce gestionnaire existe deja }
 For I := 1 To DOMEventListenerCount Do Begin
  If DOMEventListeners[I].Active And
     (DOMEventListeners[I].Element = Element) And
     (DOMEventListeners[I].EventType = EventType) And
     (DOMEventListeners[I].Handler = Handler) Then Exit;
 End;

 { Ajouter le gestionnaire }
 Inc(DOMEventListenerCount);
 DOMEventListeners[DOMEventListenerCount].EventType := EventType;
 DOMEventListeners[DOMEventListenerCount].Handler := Handler;
 DOMEventListeners[DOMEventListenerCount].Element := Element;
 DOMEventListeners[DOMEventListenerCount].Active := True;
End;

{ Supprimer un gestionnaire d'evenement (removeEventListener) }
Procedure DOMRemoveEventListener(Element: HTMLNodePtr; EventType: Byte; Handler: String);
Var
 I: Integer;
Begin
 For I := 1 To DOMEventListenerCount Do Begin
  If DOMEventListeners[I].Active And
     (DOMEventListeners[I].Element = Element) And
     (DOMEventListeners[I].EventType = EventType) And
     (DOMEventListeners[I].Handler = Handler) Then Begin
   DOMEventListeners[I].Active := False;
   Exit;
  End;
 End;
End;

{ Declencher un evenement sur un element (dispatchEvent) }
Procedure DOMDispatchEvent(Element: HTMLNodePtr; EventType: Byte);
Var
 I: Integer;
Begin
 If Element = Nil Then Exit;

 For I := 1 To DOMEventListenerCount Do Begin
  If DOMEventListeners[I].Active And
     (DOMEventListeners[I].Element = Element) And
     (DOMEventListeners[I].EventType = EventType) Then Begin
   { Executer le gestionnaire JavaScript }
   JSExecuteScript(DOMEventListeners[I].Handler);
  End;
 End;
End;

{ Obtenir le body du document (document.body) }
Function DOMGetBody: HTMLNodePtr;
Var
 List: DOMNodeList;
Begin
 List := DOMGetElementsByTagName('body');
 If List.Length > 0 Then
  DOMGetBody := List.Nodes[1]
 Else
  DOMGetBody := Nil;
End;

{ Obtenir le head du document (document.head) }
Function DOMGetHead: HTMLNodePtr;
Var
 List: DOMNodeList;
Begin
 List := DOMGetElementsByTagName('head');
 If List.Length > 0 Then
  DOMGetHead := List.Nodes[1]
 Else
  DOMGetHead := Nil;
End;

{ Obtenir le titre du document (document.title) }
Function DOMGetTitle: String;
Var
 List: DOMNodeList;
Begin
 List := DOMGetElementsByTagName('title');
 If List.Length > 0 Then
  DOMGetTitle := DOMGetTextContent(List.Nodes[1])
 Else
  DOMGetTitle := '';
End;

{ Definir le titre du document (document.title) }
Procedure DOMSetTitle(Title: String);
Var
 List: DOMNodeList;
Begin
 List := DOMGetElementsByTagName('title');
 If List.Length > 0 Then
  DOMSetTextContent(List.Nodes[1], Title);
End;

{ Convertir un type d'evenement en nom }
Function DOMEventTypeToName(EventType: Byte): String;
Begin
 Case EventType Of
  DOM_EVENT_CLICK:     DOMEventTypeToName := 'click';
  DOM_EVENT_DBLCLICK:  DOMEventTypeToName := 'dblclick';
  DOM_EVENT_MOUSEDOWN: DOMEventTypeToName := 'mousedown';
  DOM_EVENT_MOUSEUP:   DOMEventTypeToName := 'mouseup';
  DOM_EVENT_MOUSEOVER: DOMEventTypeToName := 'mouseover';
  DOM_EVENT_MOUSEOUT:  DOMEventTypeToName := 'mouseout';
  DOM_EVENT_KEYDOWN:   DOMEventTypeToName := 'keydown';
  DOM_EVENT_KEYUP:     DOMEventTypeToName := 'keyup';
  DOM_EVENT_KEYPRESS:  DOMEventTypeToName := 'keypress';
  DOM_EVENT_LOAD:      DOMEventTypeToName := 'load';
  DOM_EVENT_UNLOAD:    DOMEventTypeToName := 'unload';
  DOM_EVENT_SUBMIT:    DOMEventTypeToName := 'submit';
  DOM_EVENT_CHANGE:    DOMEventTypeToName := 'change';
  DOM_EVENT_FOCUS:     DOMEventTypeToName := 'focus';
  DOM_EVENT_BLUR:      DOMEventTypeToName := 'blur';
  Else                 DOMEventTypeToName := '';
 End;
End;

{ Convertir un nom d'evenement en type }
Function DOMNameToEventType(Name: String): Byte;
Var
 LowerName: String;
Begin
 LowerName := HTMLLowerCase(Name);
 If LowerName = 'click' Then DOMNameToEventType := DOM_EVENT_CLICK
 Else If LowerName = 'dblclick' Then DOMNameToEventType := DOM_EVENT_DBLCLICK
 Else If LowerName = 'mousedown' Then DOMNameToEventType := DOM_EVENT_MOUSEDOWN
 Else If LowerName = 'mouseup' Then DOMNameToEventType := DOM_EVENT_MOUSEUP
 Else If LowerName = 'mouseover' Then DOMNameToEventType := DOM_EVENT_MOUSEOVER
 Else If LowerName = 'mouseout' Then DOMNameToEventType := DOM_EVENT_MOUSEOUT
 Else If LowerName = 'keydown' Then DOMNameToEventType := DOM_EVENT_KEYDOWN
 Else If LowerName = 'keyup' Then DOMNameToEventType := DOM_EVENT_KEYUP
 Else If LowerName = 'keypress' Then DOMNameToEventType := DOM_EVENT_KEYPRESS
 Else If LowerName = 'load' Then DOMNameToEventType := DOM_EVENT_LOAD
 Else If LowerName = 'unload' Then DOMNameToEventType := DOM_EVENT_UNLOAD
 Else If LowerName = 'submit' Then DOMNameToEventType := DOM_EVENT_SUBMIT
 Else If LowerName = 'change' Then DOMNameToEventType := DOM_EVENT_CHANGE
 Else If LowerName = 'focus' Then DOMNameToEventType := DOM_EVENT_FOCUS
 Else If LowerName = 'blur' Then DOMNameToEventType := DOM_EVENT_BLUR
 Else DOMNameToEventType := 0;
End;

{ Executer un selecteur CSS simple (querySelector - supporte #id, .class, tag) }
Function DOMQuerySelector(Selector: String): HTMLNodePtr;
Var
 List: DOMNodeList;
Begin
 DOMQuerySelector := Nil;
 If Length(Selector) = 0 Then Exit;

 If Selector[1] = '#' Then Begin
  { Selecteur ID }
  DOMQuerySelector := DOMGetElementById(Copy(Selector, 2, Length(Selector) - 1));
 End
 Else If Selector[1] = '.' Then Begin
  { Selecteur de classe }
  List := DOMGetElementsByClassName(Copy(Selector, 2, Length(Selector) - 1));
  If List.Length > 0 Then DOMQuerySelector := List.Nodes[1];
 End
 Else Begin
  { Selecteur de balise }
  List := DOMGetElementsByTagName(Selector);
  If List.Length > 0 Then DOMQuerySelector := List.Nodes[1];
 End;
End;

{ Executer un selecteur CSS simple (querySelectorAll) }
Function DOMQuerySelectorAll(Selector: String): DOMNodeList;
Var
 List: DOMNodeList;
 Element: HTMLNodePtr;
Begin
 List.Length := 0;

 If Length(Selector) = 0 Then Begin
  DOMQuerySelectorAll := List;
  Exit;
 End;

 If Selector[1] = '#' Then Begin
  { Selecteur ID - retourne un seul element }
  Element := DOMGetElementById(Copy(Selector, 2, Length(Selector) - 1));
  If Element <> Nil Then Begin
   List.Length := 1;
   List.Nodes[1] := Element;
  End;
 End
 Else If Selector[1] = '.' Then Begin
  { Selecteur de classe }
  List := DOMGetElementsByClassName(Copy(Selector, 2, Length(Selector) - 1));
 End
 Else Begin
  { Selecteur de balise }
  List := DOMGetElementsByTagName(Selector);
 End;

 DOMQuerySelectorAll := List;
End;

{ =====================================================
  FIN DOM (Document Object Model)
  ===================================================== }

{ =====================================================
  PARSEUR CSS - Fonctions et procedures
  ===================================================== }

{ Initialiser le parseur CSS }
Procedure InitCSS;
Var
 I, J: Integer;
Begin
 CSSEnabled := True;
 CSSParseError := '';
 CSSGlobalStylesheet.RuleCount := 0;

 For I := 1 To MAX_CSS_RULES Do Begin
  CSSGlobalStylesheet.Rules[I].SelectorCount := 0;
  CSSGlobalStylesheet.Rules[I].PropertyCount := 0;
  For J := 1 To MAX_CSS_SELECTORS Do
   CSSGlobalStylesheet.Rules[I].Selectors[J].PartCount := 0;
 End;
End;

{ Ignorer les espaces blancs dans le CSS }
Function CSSSkipWhitespace(Const S: String; Pos: Integer): Integer;
Begin
 While (Pos <= Length(S)) And (S[Pos] In [' ', #9, #10, #13]) Do
  Inc(Pos);
 CSSSkipWhitespace := Pos;
End;

{ Ignorer les commentaires CSS /* */ }
Function CSSSkipComment(Const S: String; Pos: Integer): Integer;
Begin
 If (Pos < Length(S)) And (S[Pos] = '/') And (S[Pos + 1] = '*') Then Begin
  Inc(Pos, 2);
  While (Pos < Length(S)) Do Begin
   If (S[Pos] = '*') And (S[Pos + 1] = '/') Then Begin
    Inc(Pos, 2);
    Break;
   End;
   Inc(Pos);
  End;
 End;
 CSSSkipComment := Pos;
End;

{ Ignorer espaces et commentaires }
Function CSSSkipWhitespaceAndComments(Const S: String; Pos: Integer): Integer;
Var
 OldPos: Integer;
Begin
 Repeat
  OldPos := Pos;
  Pos := CSSSkipWhitespace(S, Pos);
  Pos := CSSSkipComment(S, Pos);
 Until Pos = OldPos;
 CSSSkipWhitespaceAndComments := Pos;
End;

{ Verifier si un caractere est valide pour un identifiant CSS }
Function CSSIsIdentChar(C: Char; IsFirst: Boolean): Boolean;
Begin
 If IsFirst Then
  CSSIsIdentChar := (C In ['A'..'Z', 'a'..'z', '_', '-']) Or (Ord(C) >= 128)
 Else
  CSSIsIdentChar := (C In ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) Or (Ord(C) >= 128);
End;

{ Lire un identifiant CSS }
Function CSSReadIdent(Const S: String; Var Pos: Integer): String;
Var
 Start: Integer;
Begin
 CSSReadIdent := '';
 If Pos > Length(S) Then Exit;
 If Not CSSIsIdentChar(S[Pos], True) Then Exit;

 Start := Pos;
 Inc(Pos);
 While (Pos <= Length(S)) And CSSIsIdentChar(S[Pos], False) Do
  Inc(Pos);

 CSSReadIdent := Copy(S, Start, Pos - Start);
End;

{ Lire une chaine entre guillemets }
Function CSSReadString(Const S: String; Var Pos: Integer): String;
Var
 Quote: Char;
 Start: Integer;
Begin
 CSSReadString := '';
 If Pos > Length(S) Then Exit;
 If Not (S[Pos] In ['"', '''']) Then Exit;

 Quote := S[Pos];
 Inc(Pos);
 Start := Pos;

 While (Pos <= Length(S)) And (S[Pos] <> Quote) Do Begin
  { Gerer les echappements }
  If (S[Pos] = '\') And (Pos < Length(S)) Then Inc(Pos);
  Inc(Pos);
 End;

 CSSReadString := Copy(S, Start, Pos - Start);
 If (Pos <= Length(S)) And (S[Pos] = Quote) Then Inc(Pos);
End;

{ Lire un nombre CSS (avec unite optionnelle) }
Procedure CSSReadNumber(Const S: String; Var Pos: Integer; Var NumVal: Real; Var UnitStr: String);
Var
 Start: Integer;
 NumStr: String;
 Negative: Boolean;
Begin
 NumVal := 0;
 UnitStr := '';
 Negative := False;

 { Signe optionnel }
 If (Pos <= Length(S)) And (S[Pos] = '-') Then Begin
  Negative := True;
  Inc(Pos);
 End
 Else If (Pos <= Length(S)) And (S[Pos] = '+') Then
  Inc(Pos);

 { Partie entiere }
 Start := Pos;
 While (Pos <= Length(S)) And (S[Pos] In ['0'..'9']) Do
  Inc(Pos);

 { Partie decimale }
 If (Pos <= Length(S)) And (S[Pos] = '.') Then Begin
  Inc(Pos);
  While (Pos <= Length(S)) And (S[Pos] In ['0'..'9']) Do
   Inc(Pos);
 End;

 NumStr := Copy(S, Start, Pos - Start);
 If Length(NumStr) > 0 Then Begin
  Val(NumStr, NumVal, Start);
  If Negative Then NumVal := -NumVal;
 End;

 { Unite }
 Start := Pos;
 While (Pos <= Length(S)) And (S[Pos] In ['A'..'Z', 'a'..'z', '%']) Do
  Inc(Pos);
 UnitStr := Copy(S, Start, Pos - Start);
End;

{ Lire un token CSS }
Function CSSReadToken(Const S: String; Var Pos: Integer): CSSToken;
Var
 Token: CSSToken;
 C: Char;
Begin
 Token.TokType := CSS_TOK_EOF;
 Token.Value := '';
 Token.NumValue := 0;
 Token.UnitValue := '';
 Token.Line := 1;
 Token.Column := Pos;

 Pos := CSSSkipWhitespaceAndComments(S, Pos);

 If Pos > Length(S) Then Begin
  CSSReadToken := Token;
  Exit;
 End;

 C := S[Pos];

 Case C Of
  '{': Begin
   Token.TokType := CSS_TOK_LBRACE;
   Token.Value := '{';
   Inc(Pos);
  End;
  '}': Begin
   Token.TokType := CSS_TOK_RBRACE;
   Token.Value := '}';
   Inc(Pos);
  End;
  '(': Begin
   Token.TokType := CSS_TOK_LPAREN;
   Token.Value := '(';
   Inc(Pos);
  End;
  ')': Begin
   Token.TokType := CSS_TOK_RPAREN;
   Token.Value := ')';
   Inc(Pos);
  End;
  '[': Begin
   Token.TokType := CSS_TOK_LBRACKET;
   Token.Value := '[';
   Inc(Pos);
  End;
  ']': Begin
   Token.TokType := CSS_TOK_RBRACKET;
   Token.Value := ']';
   Inc(Pos);
  End;
  ':': Begin
   Token.TokType := CSS_TOK_COLON;
   Token.Value := ':';
   Inc(Pos);
  End;
  ';': Begin
   Token.TokType := CSS_TOK_SEMICOLON;
   Token.Value := ';';
   Inc(Pos);
  End;
  ',': Begin
   Token.TokType := CSS_TOK_COMMA;
   Token.Value := ',';
   Inc(Pos);
  End;
  '>': Begin
   Token.TokType := CSS_TOK_GT;
   Token.Value := '>';
   Inc(Pos);
  End;
  '+': Begin
   Token.TokType := CSS_TOK_PLUS;
   Token.Value := '+';
   Inc(Pos);
  End;
  '~': Begin
   Token.TokType := CSS_TOK_TILDE;
   Token.Value := '~';
   Inc(Pos);
  End;
  '*': Begin
   Token.TokType := CSS_TOK_STAR;
   Token.Value := '*';
   Inc(Pos);
  End;
  '@': Begin
   Token.TokType := CSS_TOK_AT;
   Token.Value := '@';
   Inc(Pos);
  End;
  '.': Begin
   Token.TokType := CSS_TOK_DOT;
   Token.Value := '.';
   Inc(Pos);
  End;
  '#': Begin
   Token.TokType := CSS_TOK_HASH;
   Inc(Pos);
   Token.Value := '#' + CSSReadIdent(S, Pos);
  End;
  '"', '''': Begin
   Token.TokType := CSS_TOK_STRING;
   Token.Value := CSSReadString(S, Pos);
  End;
  '0'..'9', '-': Begin
   If (C = '-') And (Pos < Length(S)) And Not (S[Pos + 1] In ['0'..'9', '.']) Then Begin
    { C'est un identifiant commencant par - }
    Token.TokType := CSS_TOK_IDENT;
    Token.Value := CSSReadIdent(S, Pos);
   End
   Else Begin
    CSSReadNumber(S, Pos, Token.NumValue, Token.UnitValue);
    If Token.UnitValue = '%' Then
     Token.TokType := CSS_TOK_PERCENTAGE
    Else If Length(Token.UnitValue) > 0 Then
     Token.TokType := CSS_TOK_DIMENSION
    Else
     Token.TokType := CSS_TOK_NUMBER;
    Str(Token.NumValue:0:2, Token.Value);
   End;
  End;
  Else Begin
   If CSSIsIdentChar(C, True) Then Begin
    Token.TokType := CSS_TOK_IDENT;
    Token.Value := CSSReadIdent(S, Pos);
   End
   Else Begin
    { Caractere inconnu, avancer }
    Inc(Pos);
   End;
  End;
 End;

 CSSReadToken := Token;
End;

{ Obtenir l'ID d'une propriete CSS a partir de son nom }
Function CSSGetPropertyId(Const Name: String): Byte;
Var
 LowerName: String;
Begin
 LowerName := HTMLLowerCase(Name);

 If LowerName = 'color' Then CSSGetPropertyId := CSS_PROP_COLOR
 Else If LowerName = 'background-color' Then CSSGetPropertyId := CSS_PROP_BACKGROUND_COLOR
 Else If LowerName = 'background' Then CSSGetPropertyId := CSS_PROP_BACKGROUND
 Else If LowerName = 'font-size' Then CSSGetPropertyId := CSS_PROP_FONT_SIZE
 Else If LowerName = 'font-weight' Then CSSGetPropertyId := CSS_PROP_FONT_WEIGHT
 Else If LowerName = 'font-style' Then CSSGetPropertyId := CSS_PROP_FONT_STYLE
 Else If LowerName = 'font-family' Then CSSGetPropertyId := CSS_PROP_FONT_FAMILY
 Else If LowerName = 'text-decoration' Then CSSGetPropertyId := CSS_PROP_TEXT_DECORATION
 Else If LowerName = 'text-align' Then CSSGetPropertyId := CSS_PROP_TEXT_ALIGN
 Else If LowerName = 'display' Then CSSGetPropertyId := CSS_PROP_DISPLAY
 Else If LowerName = 'visibility' Then CSSGetPropertyId := CSS_PROP_VISIBILITY
 Else If LowerName = 'width' Then CSSGetPropertyId := CSS_PROP_WIDTH
 Else If LowerName = 'height' Then CSSGetPropertyId := CSS_PROP_HEIGHT
 Else If LowerName = 'margin' Then CSSGetPropertyId := CSS_PROP_MARGIN
 Else If LowerName = 'margin-top' Then CSSGetPropertyId := CSS_PROP_MARGIN_TOP
 Else If LowerName = 'margin-right' Then CSSGetPropertyId := CSS_PROP_MARGIN_RIGHT
 Else If LowerName = 'margin-bottom' Then CSSGetPropertyId := CSS_PROP_MARGIN_BOTTOM
 Else If LowerName = 'margin-left' Then CSSGetPropertyId := CSS_PROP_MARGIN_LEFT
 Else If LowerName = 'padding' Then CSSGetPropertyId := CSS_PROP_PADDING
 Else If LowerName = 'padding-top' Then CSSGetPropertyId := CSS_PROP_PADDING_TOP
 Else If LowerName = 'padding-right' Then CSSGetPropertyId := CSS_PROP_PADDING_RIGHT
 Else If LowerName = 'padding-bottom' Then CSSGetPropertyId := CSS_PROP_PADDING_BOTTOM
 Else If LowerName = 'padding-left' Then CSSGetPropertyId := CSS_PROP_PADDING_LEFT
 Else If LowerName = 'border' Then CSSGetPropertyId := CSS_PROP_BORDER
 Else If LowerName = 'border-color' Then CSSGetPropertyId := CSS_PROP_BORDER_COLOR
 Else If LowerName = 'border-width' Then CSSGetPropertyId := CSS_PROP_BORDER_WIDTH
 Else If LowerName = 'border-style' Then CSSGetPropertyId := CSS_PROP_BORDER_STYLE
 Else If LowerName = 'position' Then CSSGetPropertyId := CSS_PROP_POSITION
 Else If LowerName = 'top' Then CSSGetPropertyId := CSS_PROP_TOP
 Else If LowerName = 'right' Then CSSGetPropertyId := CSS_PROP_RIGHT
 Else If LowerName = 'left' Then CSSGetPropertyId := CSS_PROP_LEFT
 Else If LowerName = 'bottom' Then CSSGetPropertyId := CSS_PROP_BOTTOM
 Else If LowerName = 'float' Then CSSGetPropertyId := CSS_PROP_FLOAT
 Else If LowerName = 'clear' Then CSSGetPropertyId := CSS_PROP_CLEAR
 Else If LowerName = 'line-height' Then CSSGetPropertyId := CSS_PROP_LINE_HEIGHT
 Else If LowerName = 'overflow' Then CSSGetPropertyId := CSS_PROP_OVERFLOW
 Else If LowerName = 'cursor' Then CSSGetPropertyId := CSS_PROP_CURSOR
 Else If LowerName = 'list-style' Then CSSGetPropertyId := CSS_PROP_LIST_STYLE
 Else If LowerName = 'list-style-type' Then CSSGetPropertyId := CSS_PROP_LIST_STYLE_TYPE
 Else If LowerName = 'vertical-align' Then CSSGetPropertyId := CSS_PROP_VERTICAL_ALIGN
 Else If LowerName = 'white-space' Then CSSGetPropertyId := CSS_PROP_WHITE_SPACE
 Else CSSGetPropertyId := CSS_PROP_UNKNOWN;
End;

{ Parser une partie de selecteur simple }
Function CSSParseSimpleSelector(Const S: String; Var Pos: Integer): CSSSelectorPart;
Var
 Part: CSSSelectorPart;
 Token: CSSToken;
 StartPos: Integer;
Begin
 Part.PartType := CSS_SEL_TAG;
 Part.Value := '';
 Part.Combinator := CSS_COMB_NONE;
 Part.AttrName := '';
 Part.AttrValue := '';
 Part.AttrOp := 0;

 Pos := CSSSkipWhitespaceAndComments(S, Pos);
 If Pos > Length(S) Then Begin
  CSSParseSimpleSelector := Part;
  Exit;
 End;

 StartPos := Pos;
 Token := CSSReadToken(S, Pos);

 Case Token.TokType Of
  CSS_TOK_HASH: Begin
   Part.PartType := CSS_SEL_ID;
   Part.Value := Copy(Token.Value, 2, Length(Token.Value) - 1);
  End;
  CSS_TOK_DOT: Begin
   Part.PartType := CSS_SEL_CLASS;
   Part.Value := CSSReadIdent(S, Pos);
  End;
  CSS_TOK_STAR: Begin
   Part.PartType := CSS_SEL_UNIVERSAL;
   Part.Value := '*';
  End;
  CSS_TOK_IDENT: Begin
   Part.PartType := CSS_SEL_TAG;
   Part.Value := HTMLLowerCase(Token.Value);
  End;
  CSS_TOK_COLON: Begin
   { Pseudo-classe ou pseudo-element }
   If (Pos <= Length(S)) And (S[Pos] = ':') Then Begin
    Inc(Pos);
    Part.PartType := CSS_SEL_PSEUDO_ELEMENT;
   End
   Else
    Part.PartType := CSS_SEL_PSEUDO_CLASS;
   Part.Value := CSSReadIdent(S, Pos);
  End;
  CSS_TOK_LBRACKET: Begin
   { Selecteur d'attribut }
   Part.PartType := CSS_SEL_ATTRIBUTE;
   Part.AttrName := CSSReadIdent(S, Pos);
   Pos := CSSSkipWhitespaceAndComments(S, Pos);

   { Verifier operateur }
   If (Pos <= Length(S)) And (S[Pos] In ['=', '~', '|', '^', '$', '*']) Then Begin
    If S[Pos] = '=' Then Part.AttrOp := 1
    Else If (S[Pos] = '~') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then Begin
     Part.AttrOp := 2; Inc(Pos);
    End
    Else If (S[Pos] = '|') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then Begin
     Part.AttrOp := 3; Inc(Pos);
    End
    Else If (S[Pos] = '^') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then Begin
     Part.AttrOp := 4; Inc(Pos);
    End
    Else If (S[Pos] = '$') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then Begin
     Part.AttrOp := 5; Inc(Pos);
    End
    Else If (S[Pos] = '*') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then Begin
     Part.AttrOp := 6; Inc(Pos);
    End;
    Inc(Pos);
    Pos := CSSSkipWhitespaceAndComments(S, Pos);
    Token := CSSReadToken(S, Pos);
    If Token.TokType = CSS_TOK_STRING Then
     Part.AttrValue := Token.Value
    Else If Token.TokType = CSS_TOK_IDENT Then
     Part.AttrValue := Token.Value;
   End;

   { Chercher ] }
   While (Pos <= Length(S)) And (S[Pos] <> ']') Do Inc(Pos);
   If Pos <= Length(S) Then Inc(Pos);
  End;
  Else Begin
   { Pas de selecteur valide, restaurer position }
   Pos := StartPos;
  End;
 End;

 CSSParseSimpleSelector := Part;
End;

{ Parser un selecteur CSS complet }
Function CSSParseSelector(Const S: String; Var Pos: Integer): CSSSelector;
Var
 Sel: CSSSelector;
 Part: CSSSelectorPart;
 Combinator: Byte;
 HasWhitespace: Boolean;
 StartPos: Integer;
Begin
 Sel.PartCount := 0;
 Sel.Specificity := 0;

 While Pos <= Length(S) Do Begin
  StartPos := Pos;

  { Detecter espaces (combinateur descendant) }
  HasWhitespace := False;
  While (Pos <= Length(S)) And (S[Pos] In [' ', #9, #10, #13]) Do Begin
   HasWhitespace := True;
   Inc(Pos);
  End;

  { Ignorer commentaires }
  Pos := CSSSkipComment(S, Pos);

  { Verifier fin de selecteur }
  If (Pos > Length(S)) Or (S[Pos] In ['{', ',']) Then Break;

  { Detecter combinateurs explicites }
  Combinator := CSS_COMB_NONE;
  If Sel.PartCount > 0 Then Begin
   If S[Pos] = '>' Then Begin
    Combinator := CSS_COMB_CHILD;
    Inc(Pos);
    Pos := CSSSkipWhitespaceAndComments(S, Pos);
   End
   Else If S[Pos] = '+' Then Begin
    Combinator := CSS_COMB_ADJACENT;
    Inc(Pos);
    Pos := CSSSkipWhitespaceAndComments(S, Pos);
   End
   Else If S[Pos] = '~' Then Begin
    Combinator := CSS_COMB_SIBLING;
    Inc(Pos);
    Pos := CSSSkipWhitespaceAndComments(S, Pos);
   End
   Else If HasWhitespace Then
    Combinator := CSS_COMB_DESCENDANT;
  End;

  { Parser partie du selecteur }
  Part := CSSParseSimpleSelector(S, Pos);
  If Length(Part.Value) = 0 Then Break;

  Part.Combinator := Combinator;

  If Sel.PartCount < MAX_CSS_SELECTOR_PARTS Then Begin
   Inc(Sel.PartCount);
   Sel.Parts[Sel.PartCount] := Part;

   { Calculer specificite }
   Case Part.PartType Of
    CSS_SEL_ID: Inc(Sel.Specificity, 10000);
    CSS_SEL_CLASS, CSS_SEL_ATTRIBUTE, CSS_SEL_PSEUDO_CLASS: Inc(Sel.Specificity, 100);
    CSS_SEL_TAG, CSS_SEL_PSEUDO_ELEMENT: Inc(Sel.Specificity, 1);
   End;
  End;
 End;

 CSSParseSelector := Sel;
End;

{ Parser les declarations CSS (proprietes) }
Procedure CSSParseDeclarations(Const S: String; Var Pos: Integer; Var Rule: CSSRule);
Var
 PropName, PropValue: String;
 Token: CSSToken;
 Important: Boolean;
 StartValue: Integer;
Begin
 { Chercher { }
 While (Pos <= Length(S)) And (S[Pos] <> '{') Do Inc(Pos);
 If Pos <= Length(S) Then Inc(Pos);

 While Pos <= Length(S) Do Begin
  Pos := CSSSkipWhitespaceAndComments(S, Pos);
  If (Pos > Length(S)) Or (S[Pos] = '}') Then Break;

  { Lire nom de propriete }
  PropName := CSSReadIdent(S, Pos);
  If Length(PropName) = 0 Then Begin
   Inc(Pos);
   Continue;
  End;

  { Chercher : }
  Pos := CSSSkipWhitespaceAndComments(S, Pos);
  If (Pos <= Length(S)) And (S[Pos] = ':') Then Inc(Pos);

  { Lire valeur }
  Pos := CSSSkipWhitespaceAndComments(S, Pos);
  StartValue := Pos;
  PropValue := '';
  Important := False;

  While (Pos <= Length(S)) And Not (S[Pos] In [';', '}']) Do Begin
   Inc(Pos);
  End;

  PropValue := Trim(Copy(S, StartValue, Pos - StartValue));

  { Verifier !important }
  If System.Pos('!important', HTMLLowerCase(PropValue)) > 0 Then Begin
   Important := True;
   PropValue := Trim(Copy(PropValue, 1, System.Pos('!important', HTMLLowerCase(PropValue)) - 1));
  End;

  { Ajouter propriete }
  If (Length(PropName) > 0) And (Rule.PropertyCount < MAX_CSS_PROPERTIES) Then Begin
   Inc(Rule.PropertyCount);
   Rule.Properties[Rule.PropertyCount].PropId := CSSGetPropertyId(PropName);
   Rule.Properties[Rule.PropertyCount].PropName := PropName;
   Rule.Properties[Rule.PropertyCount].Value := PropValue;
   Rule.Properties[Rule.PropertyCount].Important := Important;
  End;

  If (Pos <= Length(S)) And (S[Pos] = ';') Then Inc(Pos);
 End;

 If (Pos <= Length(S)) And (S[Pos] = '}') Then Inc(Pos);
End;

{ Parser une regle CSS complete }
Function CSSParseRule(Const S: String; Var Pos: Integer): CSSRule;
Var
 Rule: CSSRule;
 Sel: CSSSelector;
 Token: CSSToken;
Begin
 Rule.SelectorCount := 0;
 Rule.PropertyCount := 0;

 { Parser les selecteurs (separes par des virgules) }
 While Pos <= Length(S) Do Begin
  Pos := CSSSkipWhitespaceAndComments(S, Pos);
  If (Pos > Length(S)) Or (S[Pos] = '{') Then Break;

  Sel := CSSParseSelector(S, Pos);
  If Sel.PartCount > 0 Then Begin
   If Rule.SelectorCount < MAX_CSS_SELECTORS Then Begin
    Inc(Rule.SelectorCount);
    Rule.Selectors[Rule.SelectorCount] := Sel;
   End;
  End;

  Pos := CSSSkipWhitespaceAndComments(S, Pos);
  If (Pos <= Length(S)) And (S[Pos] = ',') Then Begin
   Inc(Pos);
   Continue;
  End;

  Break;
 End;

 { Parser les declarations }
 If Rule.SelectorCount > 0 Then
  CSSParseDeclarations(S, Pos, Rule);

 CSSParseRule := Rule;
End;

{ Parser une feuille de style CSS complete }
Procedure CSSParseStylesheet(Const CSS: String);
Var
 Pos: Integer;
 Rule: CSSRule;
 Token: CSSToken;
Begin
 Pos := 1;

 While Pos <= Length(CSS) Do Begin
  Pos := CSSSkipWhitespaceAndComments(CSS, Pos);
  If Pos > Length(CSS) Then Break;

  { Ignorer les at-rules pour l'instant (sauf @charset) }
  If CSS[Pos] = '@' Then Begin
   Inc(Pos);
   While (Pos <= Length(CSS)) And (CSS[Pos] <> ';') And (CSS[Pos] <> '{') Do
    Inc(Pos);
   If (Pos <= Length(CSS)) And (CSS[Pos] = '{') Then Begin
    { At-rule avec bloc - sauter le bloc }
    Inc(Pos);
    While (Pos <= Length(CSS)) And (CSS[Pos] <> '}') Do Inc(Pos);
   End;
   If Pos <= Length(CSS) Then Inc(Pos);
   Continue;
  End;

  { Parser une regle normale }
  Rule := CSSParseRule(CSS, Pos);
  If Rule.SelectorCount > 0 Then Begin
   If CSSGlobalStylesheet.RuleCount < MAX_CSS_RULES Then Begin
    Inc(CSSGlobalStylesheet.RuleCount);
    CSSGlobalStylesheet.Rules[CSSGlobalStylesheet.RuleCount] := Rule;
   End;
  End;
 End;
End;

{ Parser un attribut style inline }
Procedure CSSParseInlineStyle(Const StyleAttr: String; Var Style: DOMStyle);
Var
 Pos: Integer;
 PropName, PropValue: String;
 StartValue: Integer;
Begin
 Pos := 1;

 While Pos <= Length(StyleAttr) Do Begin
  Pos := CSSSkipWhitespaceAndComments(StyleAttr, Pos);
  If Pos > Length(StyleAttr) Then Break;

  { Lire nom de propriete }
  PropName := HTMLLowerCase(CSSReadIdent(StyleAttr, Pos));
  If Length(PropName) = 0 Then Begin
   Inc(Pos);
   Continue;
  End;

  { Chercher : }
  Pos := CSSSkipWhitespaceAndComments(StyleAttr, Pos);
  If (Pos <= Length(StyleAttr)) And (StyleAttr[Pos] = ':') Then Inc(Pos);

  { Lire valeur }
  Pos := CSSSkipWhitespaceAndComments(StyleAttr, Pos);
  StartValue := Pos;
  While (Pos <= Length(StyleAttr)) And Not (StyleAttr[Pos] In [';']) Do
   Inc(Pos);
  PropValue := Trim(Copy(StyleAttr, StartValue, Pos - StartValue));

  { Appliquer la propriete au style }
  If PropName = 'color' Then Style.Color := PropValue
  Else If PropName = 'background-color' Then Style.BackgroundColor := PropValue
  Else If PropName = 'font-size' Then Style.FontSize := PropValue
  Else If PropName = 'font-weight' Then Style.FontWeight := PropValue
  Else If PropName = 'font-style' Then Style.FontStyle := PropValue
  Else If PropName = 'text-decoration' Then Style.TextDecoration := PropValue
  Else If PropName = 'display' Then Style.Display := PropValue
  Else If PropName = 'visibility' Then Style.Visibility := PropValue
  Else If PropName = 'width' Then Style.Width := PropValue
  Else If PropName = 'height' Then Style.Height := PropValue
  Else If PropName = 'margin' Then Style.Margin := PropValue
  Else If PropName = 'padding' Then Style.Padding := PropValue
  Else If PropName = 'border' Then Style.Border := PropValue;

  If (Pos <= Length(StyleAttr)) And (StyleAttr[Pos] = ';') Then Inc(Pos);
 End;
End;

{ Verifier si un selecteur correspond a un element }
Function CSSMatchSelector(Sel: CSSSelector; Element: HTMLNodePtr): Boolean;
Var
 I: Integer;
 Part: CSSSelectorPart;
 Node: HTMLNodePtr;
 ClassName, NodeClass: String;
 Match: Boolean;
Begin
 CSSMatchSelector := False;
 If Element = Nil Then Exit;
 If Sel.PartCount = 0 Then Exit;

 Node := Element;

 { Parcourir les parties du selecteur de droite a gauche }
 For I := Sel.PartCount DownTo 1 Do Begin
  If Node = Nil Then Exit;
  Part := Sel.Parts[I];

  { Verifier la correspondance }
  Repeat
   Match := False;
   Case Part.PartType Of
    CSS_SEL_TAG: Begin
     Match := HTMLLowerCase(Node^.TagName) = Part.Value;
    End;
    CSS_SEL_CLASS: Begin
     NodeClass := DOMGetAttribute(Node, 'class');
     Match := DOMHasClass(Node, Part.Value);
    End;
    CSS_SEL_ID: Begin
     Match := DOMGetAttribute(Node, 'id') = Part.Value;
    End;
    CSS_SEL_UNIVERSAL: Begin
     Match := True;
    End;
    CSS_SEL_ATTRIBUTE: Begin
     Match := DOMHasAttribute(Node, Part.AttrName);
     If Match And (Part.AttrOp > 0) Then
      Match := DOMGetAttribute(Node, Part.AttrName) = Part.AttrValue;
    End;
   End;

   If Not Match Then Begin
    Case Part.Combinator Of
     CSS_COMB_DESCENDANT: Begin
      { Remonter dans l'arbre }
      Node := Node^.Parent;
      If Node = Nil Then Exit;
     End;
     Else Exit;
    End;
   End;
  Until Match;

  { Passer au noeud suivant selon le combinateur }
  If I > 1 Then Begin
   Case Sel.Parts[I - 1].Combinator Of
    CSS_COMB_NONE, CSS_COMB_DESCENDANT: Node := Node^.Parent;
    CSS_COMB_CHILD: Node := Node^.Parent;
    CSS_COMB_ADJACENT: Node := DOMGetPreviousSibling(Node);
    CSS_COMB_SIBLING: Node := DOMGetPreviousSibling(Node);
   End;
  End;
 End;

 CSSMatchSelector := True;
End;

{ Obtenir les styles CSS appliques a un element }
Procedure CSSGetComputedStyle(Element: HTMLNodePtr; Var Style: DOMStyle);
Var
 I, J: Integer;
 Rule: CSSRule;
 InlineStyle: String;
Begin
 { Initialiser avec valeurs par defaut }
 Style.Color := '';
 Style.BackgroundColor := '';
 Style.FontSize := '';
 Style.FontWeight := '';
 Style.FontStyle := '';
 Style.TextDecoration := '';
 Style.Display := '';
 Style.Visibility := '';
 Style.Width := '';
 Style.Height := '';
 Style.Margin := '';
 Style.Padding := '';
 Style.Border := '';

 If Element = Nil Then Exit;

 { Appliquer les regles de la feuille de style }
 For I := 1 To CSSGlobalStylesheet.RuleCount Do Begin
  Rule := CSSGlobalStylesheet.Rules[I];
  For J := 1 To Rule.SelectorCount Do Begin
   If CSSMatchSelector(Rule.Selectors[J], Element) Then Begin
    { Appliquer les proprietes }
    For J := 1 To Rule.PropertyCount Do Begin
     Case Rule.Properties[J].PropId Of
      CSS_PROP_COLOR: Style.Color := Rule.Properties[J].Value;
      CSS_PROP_BACKGROUND_COLOR: Style.BackgroundColor := Rule.Properties[J].Value;
      CSS_PROP_FONT_SIZE: Style.FontSize := Rule.Properties[J].Value;
      CSS_PROP_FONT_WEIGHT: Style.FontWeight := Rule.Properties[J].Value;
      CSS_PROP_FONT_STYLE: Style.FontStyle := Rule.Properties[J].Value;
      CSS_PROP_TEXT_DECORATION: Style.TextDecoration := Rule.Properties[J].Value;
      CSS_PROP_DISPLAY: Style.Display := Rule.Properties[J].Value;
      CSS_PROP_VISIBILITY: Style.Visibility := Rule.Properties[J].Value;
      CSS_PROP_WIDTH: Style.Width := Rule.Properties[J].Value;
      CSS_PROP_HEIGHT: Style.Height := Rule.Properties[J].Value;
      CSS_PROP_MARGIN: Style.Margin := Rule.Properties[J].Value;
      CSS_PROP_PADDING: Style.Padding := Rule.Properties[J].Value;
      CSS_PROP_BORDER: Style.Border := Rule.Properties[J].Value;
     End;
    End;
    Break;
   End;
  End;
 End;

 { Appliquer le style inline (priorite maximale) }
 InlineStyle := DOMGetAttribute(Element, 'style');
 If Length(InlineStyle) > 0 Then
  CSSParseInlineStyle(InlineStyle, Style);
End;

{ Convertir une couleur CSS en index de couleur EGA/VGA }
Function CSSColorToIndex(Const ColorStr: String): Integer;
Var
 LowerColor: String;
Begin
 LowerColor := HTMLLowerCase(ColorStr);

 { Couleurs nommees }
 If LowerColor = 'black' Then CSSColorToIndex := 0
 Else If LowerColor = 'blue' Then CSSColorToIndex := 1
 Else If LowerColor = 'green' Then CSSColorToIndex := 2
 Else If LowerColor = 'cyan' Then CSSColorToIndex := 3
 Else If LowerColor = 'red' Then CSSColorToIndex := 4
 Else If LowerColor = 'magenta' Then CSSColorToIndex := 5
 Else If LowerColor = 'brown' Then CSSColorToIndex := 6
 Else If LowerColor = 'lightgray' Then CSSColorToIndex := 7
 Else If LowerColor = 'darkgray' Then CSSColorToIndex := 8
 Else If LowerColor = 'lightblue' Then CSSColorToIndex := 9
 Else If LowerColor = 'lightgreen' Then CSSColorToIndex := 10
 Else If LowerColor = 'lightcyan' Then CSSColorToIndex := 11
 Else If LowerColor = 'lightred' Then CSSColorToIndex := 12
 Else If LowerColor = 'lightmagenta' Then CSSColorToIndex := 13
 Else If LowerColor = 'yellow' Then CSSColorToIndex := 14
 Else If LowerColor = 'white' Then CSSColorToIndex := 15
 { Couleurs HTML standard }
 Else If LowerColor = 'navy' Then CSSColorToIndex := 1
 Else If LowerColor = 'teal' Then CSSColorToIndex := 3
 Else If LowerColor = 'maroon' Then CSSColorToIndex := 4
 Else If LowerColor = 'purple' Then CSSColorToIndex := 5
 Else If LowerColor = 'olive' Then CSSColorToIndex := 6
 Else If LowerColor = 'silver' Then CSSColorToIndex := 7
 Else If LowerColor = 'gray' Then CSSColorToIndex := 8
 Else If LowerColor = 'lime' Then CSSColorToIndex := 10
 Else If LowerColor = 'aqua' Then CSSColorToIndex := 11
 Else If LowerColor = 'fuchsia' Then CSSColorToIndex := 13
 Else If LowerColor = 'orange' Then CSSColorToIndex := 6
 Else CSSColorToIndex := -1;
End;

{ Extraire le CSS des balises <style> du document }
Procedure CSSExtractFromDocument;
Var
 List: DOMNodeList;
 I: Integer;
 StyleContent: String;
Begin
 List := DOMGetElementsByTagName('style');
 For I := 1 To List.Length Do Begin
  StyleContent := DOMGetTextContent(List.Nodes[I]);
  If Length(StyleContent) > 0 Then
   CSSParseStylesheet(StyleContent);
 End;
End;

{ =====================================================
  APPLICATION DES STYLES CSS - Cascade et Heritage
  ===================================================== }

{ Proprietes CSS heritables (du parent vers l'enfant) }
Function CSSIsInheritableProperty(PropId: Byte): Boolean;
Begin
 Case PropId Of
  CSS_PROP_COLOR,
  CSS_PROP_FONT_SIZE,
  CSS_PROP_FONT_WEIGHT,
  CSS_PROP_FONT_STYLE,
  CSS_PROP_FONT_FAMILY,
  CSS_PROP_TEXT_DECORATION,
  CSS_PROP_TEXT_ALIGN,
  CSS_PROP_LINE_HEIGHT,
  CSS_PROP_LIST_STYLE,
  CSS_PROP_LIST_STYLE_TYPE,
  CSS_PROP_VISIBILITY,
  CSS_PROP_WHITE_SPACE,
  CSS_PROP_CURSOR:
   CSSIsInheritableProperty := True;
  Else
   CSSIsInheritableProperty := False;
 End;
End;

{ Structure pour stocker les regles correspondantes triees par specificite }
Type
 CSSMatchedRule = Record
  Rule: CSSRule;
  SelectorIndex: Integer;
  Specificity: LongInt;
  SourceOrder: Integer;
 End;

{ Comparer deux regles pour le tri par cascade }
Function CSSCompareRules(Const A, B: CSSMatchedRule): Integer;
Begin
 { !important a la priorite maximale (gere separement) }
 { Sinon: specificite > ordre de source }
 If A.Specificity > B.Specificity Then
  CSSCompareRules := 1
 Else If A.Specificity < B.Specificity Then
  CSSCompareRules := -1
 Else If A.SourceOrder > B.SourceOrder Then
  CSSCompareRules := 1
 Else If A.SourceOrder < B.SourceOrder Then
  CSSCompareRules := -1
 Else
  CSSCompareRules := 0;
End;

{ Heriter les proprietes CSS du parent }
Procedure CSSInheritStyle(Var ChildStyle: DOMStyle; Const ParentStyle: DOMStyle);
Begin
 { Color herite si non defini }
 If (Length(ChildStyle.Color) = 0) And (Length(ParentStyle.Color) > 0) Then
  ChildStyle.Color := ParentStyle.Color;

 { Font-size herite si non defini }
 If (Length(ChildStyle.FontSize) = 0) And (Length(ParentStyle.FontSize) > 0) Then
  ChildStyle.FontSize := ParentStyle.FontSize;

 { Font-weight herite si non defini }
 If (Length(ChildStyle.FontWeight) = 0) And (Length(ParentStyle.FontWeight) > 0) Then
  ChildStyle.FontWeight := ParentStyle.FontWeight;

 { Font-style herite si non defini }
 If (Length(ChildStyle.FontStyle) = 0) And (Length(ParentStyle.FontStyle) > 0) Then
  ChildStyle.FontStyle := ParentStyle.FontStyle;

 { Text-decoration herite si non defini }
 If (Length(ChildStyle.TextDecoration) = 0) And (Length(ParentStyle.TextDecoration) > 0) Then
  ChildStyle.TextDecoration := ParentStyle.TextDecoration;

 { Visibility herite si non defini }
 If (Length(ChildStyle.Visibility) = 0) And (Length(ParentStyle.Visibility) > 0) Then
  ChildStyle.Visibility := ParentStyle.Visibility;
End;

{ Resoudre la cascade CSS pour un element avec heritage }
Procedure CSSResolveCascade(Element: HTMLNodePtr; Var Style: DOMStyle);
Var
 ParentStyle: DOMStyle;
 I, J, K: Integer;
 Rule: CSSRule;
 MatchedRules: Array[1..128] Of CSSMatchedRule;
 MatchedCount: Integer;
 Temp: CSSMatchedRule;
 InlineStyle: String;
Begin
 { Initialiser avec valeurs par defaut }
 Style.Color := '';
 Style.BackgroundColor := '';
 Style.FontSize := '';
 Style.FontWeight := '';
 Style.FontStyle := '';
 Style.TextDecoration := '';
 Style.Display := '';
 Style.Visibility := '';
 Style.Width := '';
 Style.Height := '';
 Style.Margin := '';
 Style.Padding := '';
 Style.Border := '';

 If Element = Nil Then Exit;

 { Obtenir le style herite du parent }
 If Element^.Parent <> Nil Then Begin
  CSSResolveCascade(Element^.Parent, ParentStyle);
  CSSInheritStyle(Style, ParentStyle);
 End;

 { Collecter les regles correspondantes }
 MatchedCount := 0;
 For I := 1 To CSSGlobalStylesheet.RuleCount Do Begin
  Rule := CSSGlobalStylesheet.Rules[I];
  For J := 1 To Rule.SelectorCount Do Begin
   If CSSMatchSelector(Rule.Selectors[J], Element) Then Begin
    If MatchedCount < 128 Then Begin
     Inc(MatchedCount);
     MatchedRules[MatchedCount].Rule := Rule;
     MatchedRules[MatchedCount].SelectorIndex := J;
     MatchedRules[MatchedCount].Specificity := Rule.Selectors[J].Specificity;
     MatchedRules[MatchedCount].SourceOrder := I;
    End;
    Break;
   End;
  End;
 End;

 { Trier par specificite et ordre de source (tri a bulles simple) }
 For I := 1 To MatchedCount - 1 Do
  For J := I + 1 To MatchedCount Do
   If CSSCompareRules(MatchedRules[I], MatchedRules[J]) > 0 Then Begin
    Temp := MatchedRules[I];
    MatchedRules[I] := MatchedRules[J];
    MatchedRules[J] := Temp;
   End;

 { Appliquer les regles dans l'ordre de cascade }
 { D'abord les regles normales }
 For I := 1 To MatchedCount Do Begin
  Rule := MatchedRules[I].Rule;
  For J := 1 To Rule.PropertyCount Do Begin
   If Not Rule.Properties[J].Important Then Begin
    Case Rule.Properties[J].PropId Of
     CSS_PROP_COLOR: Style.Color := Rule.Properties[J].Value;
     CSS_PROP_BACKGROUND_COLOR: Style.BackgroundColor := Rule.Properties[J].Value;
     CSS_PROP_FONT_SIZE: Style.FontSize := Rule.Properties[J].Value;
     CSS_PROP_FONT_WEIGHT: Style.FontWeight := Rule.Properties[J].Value;
     CSS_PROP_FONT_STYLE: Style.FontStyle := Rule.Properties[J].Value;
     CSS_PROP_TEXT_DECORATION: Style.TextDecoration := Rule.Properties[J].Value;
     CSS_PROP_DISPLAY: Style.Display := Rule.Properties[J].Value;
     CSS_PROP_VISIBILITY: Style.Visibility := Rule.Properties[J].Value;
     CSS_PROP_WIDTH: Style.Width := Rule.Properties[J].Value;
     CSS_PROP_HEIGHT: Style.Height := Rule.Properties[J].Value;
     CSS_PROP_MARGIN: Style.Margin := Rule.Properties[J].Value;
     CSS_PROP_PADDING: Style.Padding := Rule.Properties[J].Value;
     CSS_PROP_BORDER: Style.Border := Rule.Properties[J].Value;
    End;
   End;
  End;
 End;

 { Ensuite les regles !important }
 For I := 1 To MatchedCount Do Begin
  Rule := MatchedRules[I].Rule;
  For J := 1 To Rule.PropertyCount Do Begin
   If Rule.Properties[J].Important Then Begin
    Case Rule.Properties[J].PropId Of
     CSS_PROP_COLOR: Style.Color := Rule.Properties[J].Value;
     CSS_PROP_BACKGROUND_COLOR: Style.BackgroundColor := Rule.Properties[J].Value;
     CSS_PROP_FONT_SIZE: Style.FontSize := Rule.Properties[J].Value;
     CSS_PROP_FONT_WEIGHT: Style.FontWeight := Rule.Properties[J].Value;
     CSS_PROP_FONT_STYLE: Style.FontStyle := Rule.Properties[J].Value;
     CSS_PROP_TEXT_DECORATION: Style.TextDecoration := Rule.Properties[J].Value;
     CSS_PROP_DISPLAY: Style.Display := Rule.Properties[J].Value;
     CSS_PROP_VISIBILITY: Style.Visibility := Rule.Properties[J].Value;
     CSS_PROP_WIDTH: Style.Width := Rule.Properties[J].Value;
     CSS_PROP_HEIGHT: Style.Height := Rule.Properties[J].Value;
     CSS_PROP_MARGIN: Style.Margin := Rule.Properties[J].Value;
     CSS_PROP_PADDING: Style.Padding := Rule.Properties[J].Value;
     CSS_PROP_BORDER: Style.Border := Rule.Properties[J].Value;
    End;
   End;
  End;
 End;

 { Appliquer le style inline (priorite maximale sauf !important) }
 InlineStyle := DOMGetAttribute(Element, 'style');
 If Length(InlineStyle) > 0 Then
  CSSParseInlineStyle(InlineStyle, Style);
End;

{ Appliquer les styles CSS au contexte de rendu }
Procedure CSSApplyStylesToContext(Const Style: DOMStyle; Var Ctx: RenderContext);
Var
 ColorIndex: Integer;
 FontWeightLower, FontStyleLower: String;
Begin
 { Appliquer la couleur du texte }
 If Length(Style.Color) > 0 Then Begin
  ColorIndex := CSSColorToIndex(Style.Color);
  If ColorIndex >= 0 Then
   Ctx.TextColor := ColorIndex;
 End;

 { Appliquer la couleur de fond }
 If Length(Style.BackgroundColor) > 0 Then Begin
  ColorIndex := CSSColorToIndex(Style.BackgroundColor);
  If ColorIndex >= 0 Then
   Ctx.BgColor := ColorIndex;
 End;

 { Appliquer le font-weight }
 If Length(Style.FontWeight) > 0 Then Begin
  FontWeightLower := HTMLLowerCase(Style.FontWeight);
  If (FontWeightLower = 'bold') Or (FontWeightLower = '700') Or
     (FontWeightLower = '800') Or (FontWeightLower = '900') Then
   Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD
  Else If (FontWeightLower = 'normal') Or (FontWeightLower = '400') Then
   Ctx.TextStyle := Ctx.TextStyle And (Not TEXT_STYLE_BOLD);
 End;

 { Appliquer le font-style }
 If Length(Style.FontStyle) > 0 Then Begin
  FontStyleLower := HTMLLowerCase(Style.FontStyle);
  If FontStyleLower = 'italic' Then
   Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_ITALIC
  Else If FontStyleLower = 'normal' Then
   Ctx.TextStyle := Ctx.TextStyle And (Not TEXT_STYLE_ITALIC);
 End;

 { Appliquer text-decoration }
 If Length(Style.TextDecoration) > 0 Then Begin
  If System.Pos('underline', HTMLLowerCase(Style.TextDecoration)) > 0 Then
   Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_UNDERLINE
  Else If HTMLLowerCase(Style.TextDecoration) = 'none' Then
   Ctx.TextStyle := Ctx.TextStyle And (Not TEXT_STYLE_UNDERLINE);
 End;

 { Appliquer visibility }
 If HTMLLowerCase(Style.Visibility) = 'hidden' Then Begin
  { Element cache mais prend de l'espace - simuler en ne pas dessiner }
  { Note: necessiterait un flag InVisible dans le contexte }
 End;
End;

{ Verifier si un element doit etre cache (display: none) }
Function CSSIsElementHidden(Const Style: DOMStyle): Boolean;
Var
 DisplayLower: String;
Begin
 CSSIsElementHidden := False;
 If Length(Style.Display) > 0 Then Begin
  DisplayLower := HTMLLowerCase(Style.Display);
  If DisplayLower = 'none' Then
   CSSIsElementHidden := True;
 End;
 If Length(Style.Visibility) > 0 Then Begin
  If HTMLLowerCase(Style.Visibility) = 'hidden' Then
   CSSIsElementHidden := True;
 End;
End;

{ Verifier si un element est un element de bloc }
Function CSSIsBlockElement(Const Style: DOMStyle; TagType: Byte): Boolean;
Var
 DisplayLower: String;
Begin
 { Verifier d'abord le style CSS }
 If Length(Style.Display) > 0 Then Begin
  DisplayLower := HTMLLowerCase(Style.Display);
  If DisplayLower = 'block' Then Begin
   CSSIsBlockElement := True;
   Exit;
  End
  Else If DisplayLower = 'inline' Then Begin
   CSSIsBlockElement := False;
   Exit;
  End
  Else If DisplayLower = 'inline-block' Then Begin
   CSSIsBlockElement := False;
   Exit;
  End;
 End;

 { Sinon utiliser le comportement par defaut de la balise }
 Case TagType Of
  TAG_DIV, TAG_P, TAG_H1, TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6,
  TAG_SECTION, TAG_ARTICLE, TAG_NAV, TAG_ASIDE, TAG_HEADER, TAG_FOOTER,
  TAG_MAIN, TAG_UL, TAG_OL, TAG_LI, TAG_DL, TAG_DT, TAG_DD,
  TAG_TABLE, TAG_TR, TAG_FORM, TAG_PRE, TAG_BLOCKQUOTE, TAG_HR,
  TAG_FIGCAPTION, TAG_FIGURE, TAG_ADDRESS, TAG_DETAILS, TAG_SUMMARY:
   CSSIsBlockElement := True;
  Else
   CSSIsBlockElement := False;
 End;
End;

{ Parser une valeur de dimension CSS (px, em, %, etc.) et retourner en pixels }
Function CSSParseDimension(Const Value: String; DefaultPx: Integer): Integer;
Var
 NumStr: String;
 NumVal: Real;
 UnitStr: String;
 I, Code: Integer;
Begin
 CSSParseDimension := DefaultPx;
 If Length(Value) = 0 Then Exit;

 { Extraire la partie numerique }
 NumStr := '';
 I := 1;
 While (I <= Length(Value)) And (Value[I] In ['0'..'9', '.', '-']) Do Begin
  NumStr := NumStr + Value[I];
  Inc(I);
 End;

 If Length(NumStr) = 0 Then Exit;
 Val(NumStr, NumVal, Code);
 If Code <> 0 Then Exit;

 { Extraire l'unite }
 UnitStr := HTMLLowerCase(Copy(Value, I, Length(Value) - I + 1));

 { Convertir selon l'unite }
 If (UnitStr = 'px') Or (Length(UnitStr) = 0) Then
  CSSParseDimension := Round(NumVal)
 Else If UnitStr = 'em' Then
  CSSParseDimension := Round(NumVal * 16) { 1em = 16px par defaut }
 Else If UnitStr = 'rem' Then
  CSSParseDimension := Round(NumVal * 16)
 Else If UnitStr = '%' Then
  CSSParseDimension := Round((NumVal / 100) * DefaultPx)
 Else If UnitStr = 'pt' Then
  CSSParseDimension := Round(NumVal * 1.33) { 1pt = 1.33px }
 Else
  CSSParseDimension := Round(NumVal);
End;

{ =====================================================
  FIN APPLICATION DES STYLES CSS
  ===================================================== }

{ =====================================================
  FIN PARSEUR CSS
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
 Ctx.InLink := False;
 Ctx.CurrentLinkHref := '';
End;

{ Procedure pour reinitialiser les zones de liens }
Procedure ClearLinkAreas;
Var
 I: Integer;
Begin
 For I := 1 To MAX_LINKS Do Begin
  LinkAreas[I].Active := False;
  LinkAreas[I].Href := '';
  LinkAreas[I].Title := '';
 End;
 LinkCount := 0;
End;

{ Procedure pour ajouter une zone de lien cliquable }
Procedure AddLinkArea(X1, Y1, X2, Y2: Integer; Href, Title: String);
Begin
 If LinkCount < MAX_LINKS Then Begin
  Inc(LinkCount);
  LinkAreas[LinkCount].X1 := X1;
  LinkAreas[LinkCount].Y1 := Y1;
  LinkAreas[LinkCount].X2 := X2;
  LinkAreas[LinkCount].Y2 := Y2;
  LinkAreas[LinkCount].Href := Href;
  LinkAreas[LinkCount].Title := Title;
  LinkAreas[LinkCount].Active := True;
 End;
End;

{ Fonction pour trouver un lien a une position donnee }
Function FindLinkAtPosition(X, Y: Integer): Integer;
Var
 I: Integer;
Begin
 FindLinkAtPosition := 0;
 For I := 1 To LinkCount Do Begin
  If LinkAreas[I].Active Then Begin
   If (X >= LinkAreas[I].X1) And (X <= LinkAreas[I].X2) And
      (Y >= LinkAreas[I].Y1) And (Y <= LinkAreas[I].Y2) Then Begin
    FindLinkAtPosition := I;
    Exit;
   End;
  End;
 End;
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

{ =====================================================
  RENDU HTML - Liens hypertexte (balise <a href>)
  ===================================================== }

{ Procedure pour rendre la balise A (lien hypertexte) }
Procedure RenderTagA(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 Href, Title: String;
 OldTextColor: Integer;
 OldTextStyle: Byte;
 OldInLink: Boolean;
 StartX, StartY: Integer;
 EndX, EndY: Integer;
 I: Integer;
 ChildNode: HTMLNodePtr;
 LinkText: String;
 TextW: Integer;
Begin
 { Obtenir les attributs href et title }
 Href := GetNodeAttribute(Node, 'href');
 Title := GetNodeAttribute(Node, 'title');

 { Si pas de href, rendre comme du texte normal }
 If Href = '' Then Begin
  RenderChildren(Node, Ctx);
  Exit;
 End;

 { Sauvegarder l'etat courant }
 OldTextColor := Ctx.TextColor;
 OldTextStyle := Ctx.TextStyle;
 OldInLink := Ctx.InLink;

 { Configurer le style de lien }
 Ctx.TextColor := RENDER_LINK_COLOR;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_UNDERLINE;
 Ctx.InLink := True;
 Ctx.CurrentLinkHref := Href;

 { Memoriser la position de debut }
 StartX := Ctx.X;
 StartY := Ctx.Y;

 { Appliquer la couleur du lien }
 SetColor(RENDER_LINK_COLOR);

 { Rendre le contenu du lien }
 RenderChildren(Node, Ctx);

 { Calculer la position de fin }
 EndX := Ctx.X;
 EndY := Ctx.Y;

 { Si le lien a occupe plusieurs lignes, ajuster la zone }
 If EndY > StartY Then Begin
  { Zone multiligne - on enregistre seulement la derniere ligne }
  { Pour une implementation plus complete, il faudrait plusieurs zones }
  StartX := RENDER_AREA_X + RENDER_MARGIN_LEFT;
 End;

 { Calculer la largeur du texte du lien pour la zone cliquable }
 LinkText := '';
 For I := 1 To Node^.ChildCount Do Begin
  ChildNode := Node^.Children[I];
  If (ChildNode <> Nil) And (ChildNode^.NodeType = HTML_NODE_TEXT) Then Begin
   LinkText := LinkText + ChildNode^.Content;
  End;
 End;

 { Si on a trouve du texte, ajouter la zone de lien }
 If LinkText <> '' Then Begin
  TextW := TextWidth(LinkText);
  If EndY = StartY Then Begin
   { Lien sur une seule ligne }
   AddLinkArea(StartX, StartY, StartX + TextW, StartY + Ctx.LineHeight, Href, Title);
  End
  Else Begin
   { Lien multiligne - enregistrer la zone de la derniere ligne }
   AddLinkArea(StartX, EndY, EndX, EndY + Ctx.LineHeight, Href, Title);
  End;
 End
 Else Begin
  { Utiliser la position courante comme estimation }
  If EndX > StartX Then
   AddLinkArea(StartX, StartY, EndX, StartY + Ctx.LineHeight, Href, Title);
 End;

 { Dessiner le soulignement si pas deja fait par RenderText }
 { Le soulignement est gere par TEXT_STYLE_UNDERLINE dans RenderText }

 { Restaurer l'etat }
 Ctx.TextColor := OldTextColor;
 Ctx.TextStyle := OldTextStyle;
 Ctx.InLink := OldInLink;
 Ctx.CurrentLinkHref := '';

 { Restaurer la couleur }
 SetColor(OldTextColor);
End;

{ =====================================================
  FIN RENDU LIENS HYPERTEXTE
  ===================================================== }

{ =====================================================
  RENDU HTML - Scripts (balise <script>)
  ===================================================== }

{ Fonction pour extraire le contenu textuel d'un noeud }
Function GetNodeTextContent(Node: HTMLNodePtr): String;
Var
 I: Integer;
 Result: String;
Begin
 Result := '';
 If Node = Nil Then Begin
  GetNodeTextContent := Result;
  Exit;
 End;

 If Node^.NodeType = HTML_NODE_TEXT Then
  Result := Node^.Content
 Else If Node^.NodeType = HTML_NODE_ELEMENT Then Begin
  For I := 1 To Node^.ChildCount Do
   Result := Result + GetNodeTextContent(Node^.Children[I]);
 End;
 GetNodeTextContent := Result;
End;

{ Procedure pour rendre la balise SCRIPT (execution JavaScript) }
Procedure RenderTagScript(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 ScriptType, ScriptSrc: String;
 ScriptContent: String;
Begin
 { Verifier le type de script }
 ScriptType := GetNodeAttribute(Node, 'type');
 ScriptSrc := GetNodeAttribute(Node, 'src');

 { Ne supporter que JavaScript (par defaut ou explicitement) }
 If (ScriptType <> '') And (ScriptType <> 'text/javascript') And
    (ScriptType <> 'application/javascript') And
    (ScriptType <> 'module') Then Begin
  { Type de script non supporte, ignorer }
  Exit;
 End;

 { Les scripts externes (src=) ne sont pas supportes pour l'instant }
 If ScriptSrc <> '' Then Begin
  { TODO: Charger et executer le script externe }
  Exit;
 End;

 { Extraire le contenu du script }
 ScriptContent := GetNodeTextContent(Node);

 { Executer le script JavaScript }
 If Length(ScriptContent) > 0 Then Begin
  JSExecuteScript(ScriptContent);
 End;

 { Le script ne produit pas de rendu visuel direct }
 { La sortie de document.write() est traitee separement }
End;

{ =====================================================
  FIN RENDU SCRIPTS
  ===================================================== }

{ Variable globale pour activer/desactiver l'application CSS automatique }
Var
 CSSAutoApply: Boolean;

Procedure RenderHTMLNode(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 NodeStyle: DOMStyle;
 OldTextColor: Integer;
 OldBgColor: Integer;
 OldTextStyle: Byte;
Begin
 If Node = Nil Then Exit;
 If Ctx.Y > Ctx.MaxY Then Exit; { Depasse la zone de rendu }

 { Sauvegarder le contexte actuel pour restauration apres le rendu }
 OldTextColor := Ctx.TextColor;
 OldBgColor := Ctx.BgColor;
 OldTextStyle := Ctx.TextStyle;

 { Appliquer les styles CSS si active et si c'est un element }
 If CSSAutoApply And CSSEnabled And (Node^.NodeType = HTML_NODE_ELEMENT) Then Begin
  CSSResolveCascade(Node, NodeStyle);

  { Verifier si l'element doit etre cache }
  If CSSIsElementHidden(NodeStyle) Then Exit;

  { Appliquer les styles au contexte }
  CSSApplyStylesToContext(NodeStyle, Ctx);
 End;

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

    { Liens hypertexte }
    TAG_A:        RenderTagA(Node, Ctx);

    { Scripts JavaScript }
    TAG_SCRIPT:   RenderTagScript(Node, Ctx);

    { NOSCRIPT - afficher le contenu si JavaScript est desactive }
    TAG_NOSCRIPT: Begin
     If Not JSEnabled Then RenderChildren(Node, Ctx);
    End;

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

 { Restaurer le contexte apres le rendu de cet element }
 If CSSAutoApply And CSSEnabled And (Node^.NodeType = HTML_NODE_ELEMENT) Then Begin
  Ctx.TextColor := OldTextColor;
  Ctx.BgColor := OldBgColor;
  Ctx.TextStyle := OldTextStyle;
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

 { Activer l'application automatique des styles CSS }
 CSSAutoApply := True;

 { Extraire et parser les styles CSS des balises <style> }
 If CSSEnabled Then
  CSSExtractFromDocument;

 { Reinitialiser les zones de liens }
 ClearLinkAreas;

 { Effacer la zone de rendu }
 ClearRenderArea;

 { Rendre le document avec application des styles CSS }
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

{ Fonction pour verifier si une position est dans la zone de rendu }
Function IsInRenderArea(X, Y: Integer): Boolean;
Begin
 IsInRenderArea := (X >= RENDER_AREA_X) And
                   (X <= RENDER_AREA_X + RENDER_AREA_WIDTH) And
                   (Y >= RENDER_AREA_Y) And
                   (Y <= RENDER_AREA_Y + RENDER_AREA_HEIGHT);
End;

{ Procedure pour gerer le clic sur un lien hypertexte }
Procedure HandleLinkClick(LinkIndex: Integer);
Var
 TargetURL: String;
Begin
 If (LinkIndex < 1) Or (LinkIndex > LinkCount) Then Exit;
 If Not LinkAreas[LinkIndex].Active Then Exit;

 { Recuperer l'URL du lien }
 TargetURL := LinkAreas[LinkIndex].Href;

 { Verifier si l'URL est vide }
 If TargetURL = '' Then Exit;

 { Traiter les differents types d'URL }
 If (Copy(TargetURL, 1, 7) = 'http://') Or
    (Copy(TargetURL, 1, 8) = 'https://') Then Begin
  { URL absolue - naviguer directement }
  NavigateTo(TargetURL);
 End
 Else If Copy(TargetURL, 1, 1) = '/' Then Begin
  { URL relative a la racine du site }
  { Extraire le protocole et le domaine de l'URL courante }
  { Pour l'instant, on utilise l'URL telle quelle }
  NavigateTo(TargetURL);
 End
 Else If Copy(TargetURL, 1, 1) = '#' Then Begin
  { Ancre dans la meme page - ne pas naviguer pour l'instant }
  { TODO: Implementer le saut vers l'ancre }
 End
 Else If (Copy(TargetURL, 1, 7) = 'mailto:') Then Begin
  { Lien email - ne pas naviguer }
  { Afficher une notification? }
 End
 Else If (Copy(TargetURL, 1, 4) = 'tel:') Then Begin
  { Lien telephone - ne pas naviguer }
 End
 Else Begin
  { URL relative - combiner avec le chemin courant }
  { Pour l'instant, on utilise l'URL telle quelle }
  NavigateTo(TargetURL);
 End;
End;

{ Procedure pour gerer les clics de souris sur l'interface }
Procedure HandleMouseClick(X, Y: Integer);
Var
 LinkIdx: Integer;
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

 { Verifier si le clic est sur un lien hypertexte dans la zone de rendu }
 If IsInRenderArea(X, Y) Then Begin
  LinkIdx := FindLinkAtPosition(X, Y);
  If LinkIdx > 0 Then Begin
   HandleLinkClick(LinkIdx);
  End;
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
 InitJSContext;  { Initialiser l'interpreteur JavaScript }
 InitDOM;        { Initialiser le DOM }
 InitCSS;        { Initialiser le parseur CSS }
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