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
  21. DONE: Implementer le decodeur et l'affichage des images BMP
  22. DONE: Implementer le decodeur et l'affichage des images GIF (y compris anime)
  23. DONE: Implementer le decodeur et l'affichage des images JPEG
  24. DONE: Implementer le decodeur et l'affichage des images PNG
  25. DONE: Implementer le parseur et le rendu des fichiers SVG (Scalable Vector Graphics)
}

Program BROWSER;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

Uses {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 BROWSER_BUILD_ID = '20260620-STACKFIX-5';

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
 { RENDER_AREA_WIDTH/HEIGHT : valeurs par defaut pour le mode VGA
   640x480 ; recalculees dans InitializeGraphics selon la resolution
   reelle (notamment en mode -maxscreen), voir plus bas. }

 { Barres de defilement de la zone de rendu }
 SCROLLBAR_SIZE = 16;          { Epaisseur des barres / cote des boutons fleche }
 SCROLLBAR_MIN_THUMB = 12;     { Taille minimale de la poignee }
 SCROLL_LINE_STEP = 16;        { Pas de defilement par clic sur une fleche }
 SCROLL_MEASURE_MARGIN = 2000; { Marge d'anticipation pour mesurer le contenu restant }

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

 { Modes de text-align CSS }
 ALIGN_LEFT = 0;
 ALIGN_CENTER = 1;
 ALIGN_RIGHT = 2;

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
 CSS_TOK_LBRACE = 10;        { accolade (debut de bloc) }
 CSS_TOK_RBRACE = 11;        { accolade (fin de bloc) }
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
 HTMLBufferChunkPtr = ^HTMLBufferChunk;
 HTMLBufferChunk = Record
  Data: Array[0..4095] Of Char;
  Used: Word;
  Next: HTMLBufferChunkPtr;
 End;
 HTMLSourceBuffer = Record
  FirstChunk: HTMLBufferChunkPtr;
  LastChunk: HTMLBufferChunkPtr;
  DataLength: LongInt;
 End;

 CSSUnitString = String[8];

 { Attribut HTML stocke dans une liste chainee }
 HTMLAttributePtr = ^HTMLAttribute;
 HTMLAttribute = Record
  Name: String[64];
  Value: String[255];
  Next: HTMLAttributePtr;
 End;

 { Pointeur vers un noeud HTML (declaration forward) }
 HTMLNodePtr = ^HTMLNode;

 { Type pour un noeud HTML }
 HTMLNode = Record
  NodeType: Byte;            { Type de noeud (element, texte, commentaire, etc.) }
  TagType: Byte;             { Type de balise (TAG_P, TAG_DIV, etc.) }
  TagName: String[32];       { Nom de la balise originale }
  Content: String;           { Contenu texte pour les noeuds texte }
  FirstAttribute: HTMLAttributePtr;
  LastAttribute: HTMLAttributePtr;
  AttributeCount: Integer;
  FirstChild: HTMLNodePtr;
  LastChild: HTMLNodePtr;
  PreviousSibling: HTMLNodePtr;
  NextSibling: HTMLNodePtr;
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
  NoWrap: Boolean;           { CSS white-space: nowrap }
  TextAlignMode: Byte;       { CSS text-align : 0=left 1=center 2=right }
 End;

 { Marges/padding/bordure/fond resolus en pixels pour l'element dont
   le rendu est en cours - meme principe de capture immediate que
   CurrentElementWantsBlock (-1 = non specifie par le CSS, le
   gestionnaire de balise garde alors sa propre constante par defaut). }
 TElementBoxInfo = Record
  MarginTopPx: Integer;
  MarginBottomPx: Integer;
  PaddingTopPx: Integer;
  PaddingBottomPx: Integer;
  HasBorder: Boolean;
  BorderWidthPx: Integer;
  BorderColorIdx: Integer;
  HasBgBox: Boolean;
  BgBoxColorIdx: Integer;
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
  { Etendu pour un support CSS plus complet }
  TextAlign: String[16];
  LineHeight: String[16];
  Float: String[16];
  ClearProp: String[16];
  PositionProp: String[16];
  TopProp: String[16];
  RightProp: String[16];
  BottomProp: String[16];
  LeftProp: String[16];
  ListStyle: String[32];
  ListStyleType: String[16];
  VerticalAlign: String[16];
  WhiteSpace: String[16];
  Overflow: String[16];
  MarginTop: String[16];
  MarginRight: String[16];
  MarginBottom: String[16];
  MarginLeft: String[16];
  PaddingTop: String[16];
  PaddingRight: String[16];
  PaddingBottom: String[16];
  PaddingLeft: String[16];
  BorderColor: String[32];
  BorderWidth: String[16];
  BorderStyle: String[16];
 End;

 { =====================================================
   Types pour le parseur CSS
   ===================================================== }

 { Token CSS }
 CSSToken = Record
  TokType: Byte;              { Type du token (CSS_TOK_*) }
  Value: String;              { Valeur textuelle du token }
  NumValue: Real;             { Valeur numerique (si nombre) }
  UnitValue: CSSUnitString;   { Unite (px, em, %, etc.) }
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
 { -maxscreen : forcer l'affichage maximal supporte (voir DEVENV.PAS) }
 MaxScreen: Boolean;

 { Dimensions de la zone de rendu HTML, calculees selon la resolution
   graphique reelle (voir InitializeGraphics). Valeurs par defaut =
   mode VGA 640x480. }
 RENDER_AREA_WIDTH: Integer;
 RENDER_AREA_HEIGHT: Integer;

 { Defilement de la page (voir RenderText/InitRenderContext/RenderHTMLDocument) }
 ScrollX: Integer;             { decalage horizontal courant, >= 0 }
 ScrollY: Integer;             { decalage vertical courant, >= 0 }
 CanScrollUp: Boolean;
 CanScrollDown: Boolean;
 CanScrollLeft: Boolean;
 CanScrollRight: Boolean;
 ContentOverflowX: Integer;    { X maximal atteint pendant le rendu (mots non coupables) }
 RenderOriginX: Integer;       { = RENDER_AREA_X - ScrollX, ancre du contenu }
 RenderOriginY: Integer;       { = RENDER_AREA_Y - ScrollY, ancre du contenu }

 { Resultat CSS "display" du noeud dont le rendu est en cours, lu par
   chaque RenderTagXXX juste avant tout appel recursif (RenderChildren
   peut re-ecrire ce drapeau pour un descendant entre-temps : chaque
   gestionnaire doit le capturer dans une variable locale avant de
   rendre ses enfants). True = comportement de bloc (saut de ligne
   avant/apres), False = le CSS a demande display:inline/inline-block,
   donc le contenu doit continuer sur la meme ligne malgre le
   comportement par defaut de la balise. }
 CurrentElementWantsBlock: Boolean;

 { CSS list-style/list-style-type:none du <li> dont le rendu est en
   cours - meme principe et meme prudence de capture que
   CurrentElementWantsBlock (lu une seule fois, au tout debut de
   RenderTagLI, avant tout appel recursif). }
 CurrentElementListStyleNone: Boolean;

 { Boite CSS (marges/padding/bordure/fond) de l'element dont le rendu
   est en cours - voir TElementBoxInfo. }
 CurrentElementBox: TElementBoxInfo;

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

{ Declaree ici car elle est utilisee par le parseur avant son implementation. }
Function Trim(Const S: String): String; Forward;

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

{ Convertir un code ISO-8859-1/Unicode courant vers le jeu de caracteres
  utilise par la cible. Turbo Pascal DOS utilise normalement la page 850. }
Function HTMLCodePointToChar(CodePoint: LongInt): Char;
Begin
 {$IFDEF FPC}
 If (CodePoint >= 0) And (CodePoint <= 255) Then
  HTMLCodePointToChar := Chr(CodePoint)
 Else
  HTMLCodePointToChar := '?';
 {$ELSE}
 Case CodePoint Of
  160: HTMLCodePointToChar := ' ';
  192: HTMLCodePointToChar := Chr(183); { A grave }
  194: HTMLCodePointToChar := Chr(182); { A circonflexe }
  199: HTMLCodePointToChar := Chr(128); { C cedille }
  200: HTMLCodePointToChar := Chr(212); { E grave }
  201: HTMLCodePointToChar := Chr(144); { E aigu }
  202: HTMLCodePointToChar := Chr(210); { E circonflexe }
  206: HTMLCodePointToChar := Chr(215); { I circonflexe }
  212: HTMLCodePointToChar := Chr(226); { O circonflexe }
  217: HTMLCodePointToChar := Chr(235); { U grave }
  219: HTMLCodePointToChar := Chr(234); { U circonflexe }
  224: HTMLCodePointToChar := Chr(133); { a grave }
  225: HTMLCodePointToChar := Chr(160); { a aigu }
  226: HTMLCodePointToChar := Chr(131); { a circonflexe }
  228: HTMLCodePointToChar := Chr(132); { a trema }
  231: HTMLCodePointToChar := Chr(135); { c cedille }
  232: HTMLCodePointToChar := Chr(138); { e grave }
  233: HTMLCodePointToChar := Chr(130); { e aigu }
  234: HTMLCodePointToChar := Chr(136); { e circonflexe }
  235: HTMLCodePointToChar := Chr(137); { e trema }
  238: HTMLCodePointToChar := Chr(140); { i circonflexe }
  239: HTMLCodePointToChar := Chr(139); { i trema }
  244: HTMLCodePointToChar := Chr(147); { o circonflexe }
  246: HTMLCodePointToChar := Chr(148); { o trema }
  249: HTMLCodePointToChar := Chr(151); { u grave }
  251: HTMLCodePointToChar := Chr(150); { u circonflexe }
  252: HTMLCodePointToChar := Chr(129); { u trema }
  169: HTMLCodePointToChar := Chr(184); { copyright }
  174: HTMLCodePointToChar := Chr(169); { marque deposee }
  176: HTMLCodePointToChar := Chr(248); { degre }
  171: HTMLCodePointToChar := Chr(174); { guillemet gauche }
  187: HTMLCodePointToChar := Chr(175); { guillemet droit }
  Else
   If (CodePoint >= 0) And (CodePoint <= 127) Then
    HTMLCodePointToChar := Chr(CodePoint)
   Else
    HTMLCodePointToChar := '?';
 End;
 {$ENDIF}
End;

Function HTMLNamedEntityCode(Const EntityName: String): LongInt;
Var
 Name: String;
Begin
 If EntityName = 'Agrave' Then Begin HTMLNamedEntityCode := 192; Exit; End;
 If EntityName = 'Acirc' Then Begin HTMLNamedEntityCode := 194; Exit; End;
 If EntityName = 'Ccedil' Then Begin HTMLNamedEntityCode := 199; Exit; End;
 If EntityName = 'Egrave' Then Begin HTMLNamedEntityCode := 200; Exit; End;
 If EntityName = 'Eacute' Then Begin HTMLNamedEntityCode := 201; Exit; End;
 If EntityName = 'Ecirc' Then Begin HTMLNamedEntityCode := 202; Exit; End;
 If EntityName = 'Icirc' Then Begin HTMLNamedEntityCode := 206; Exit; End;
 If EntityName = 'Ocirc' Then Begin HTMLNamedEntityCode := 212; Exit; End;
 If EntityName = 'Ugrave' Then Begin HTMLNamedEntityCode := 217; Exit; End;
 If EntityName = 'Ucirc' Then Begin HTMLNamedEntityCode := 219; Exit; End;
 Name := HTMLLowerCase(EntityName);
 HTMLNamedEntityCode := -1;
 If Name = 'nbsp' Then HTMLNamedEntityCode := 160
 Else If Name = 'amp' Then HTMLNamedEntityCode := 38
 Else If Name = 'lt' Then HTMLNamedEntityCode := 60
 Else If Name = 'gt' Then HTMLNamedEntityCode := 62
 Else If Name = 'quot' Then HTMLNamedEntityCode := 34
 Else If Name = 'apos' Then HTMLNamedEntityCode := 39
 Else If Name = 'agrave' Then HTMLNamedEntityCode := 224
 Else If Name = 'aacute' Then HTMLNamedEntityCode := 225
 Else If Name = 'acirc' Then HTMLNamedEntityCode := 226
 Else If Name = 'auml' Then HTMLNamedEntityCode := 228
 Else If Name = 'ccedil' Then HTMLNamedEntityCode := 231
 Else If Name = 'egrave' Then HTMLNamedEntityCode := 232
 Else If Name = 'eacute' Then HTMLNamedEntityCode := 233
 Else If Name = 'ecirc' Then HTMLNamedEntityCode := 234
 Else If Name = 'euml' Then HTMLNamedEntityCode := 235
 Else If Name = 'icirc' Then HTMLNamedEntityCode := 238
 Else If Name = 'iuml' Then HTMLNamedEntityCode := 239
 Else If Name = 'ocirc' Then HTMLNamedEntityCode := 244
 Else If Name = 'ouml' Then HTMLNamedEntityCode := 246
 Else If Name = 'ugrave' Then HTMLNamedEntityCode := 249
 Else If Name = 'ucirc' Then HTMLNamedEntityCode := 251
 Else If Name = 'uuml' Then HTMLNamedEntityCode := 252
 Else If Name = 'laquo' Then HTMLNamedEntityCode := 171
 Else If Name = 'raquo' Then HTMLNamedEntityCode := 187
 Else If Name = 'copy' Then HTMLNamedEntityCode := 169
 Else If Name = 'reg' Then HTMLNamedEntityCode := 174
 Else If Name = 'deg' Then HTMLNamedEntityCode := 176;
End;

Function HTMLDecodeEntities(Const S: String): String;
Var
 I, SemiPos, J, Digit: Integer;
 EntityName, ResultText: String;
 CodePoint: LongInt;
 IsNumeric, IsHex, ValidNumber: Boolean;
Begin
 ResultText := '';
 I := 1;
 While (I <= Length(S)) And (Length(ResultText) < 255) Do Begin
  If S[I] <> '&' Then Begin
   ResultText := ResultText + S[I];
   Inc(I);
  End
  Else Begin
   SemiPos := I + 1;
   While (SemiPos <= Length(S)) And (SemiPos - I <= 16) And
         (S[SemiPos] <> ';') Do
    Inc(SemiPos);
   If (SemiPos > Length(S)) Or (S[SemiPos] <> ';') Then Begin
    ResultText := ResultText + '&';
    Inc(I);
   End
   Else Begin
    EntityName := Copy(S, I + 1, SemiPos - I - 1);
    IsNumeric := (Length(EntityName) > 1) And (EntityName[1] = '#');
    CodePoint := -1;
    If IsNumeric Then Begin
     IsHex := (Length(EntityName) > 2) And
              (EntityName[2] In ['x', 'X']);
     If IsHex Then J := 3 Else J := 2;
     CodePoint := 0;
     ValidNumber := J <= Length(EntityName);
     While ValidNumber And (J <= Length(EntityName)) Do Begin
      If EntityName[J] In ['0'..'9'] Then
       Digit := Ord(EntityName[J]) - Ord('0')
      Else If IsHex And (EntityName[J] In ['a'..'f']) Then
       Digit := Ord(EntityName[J]) - Ord('a') + 10
      Else If IsHex And (EntityName[J] In ['A'..'F']) Then
       Digit := Ord(EntityName[J]) - Ord('A') + 10
      Else Begin
       Digit := 0;
       ValidNumber := False;
      End;
      If ValidNumber Then Begin
       If IsHex Then CodePoint := CodePoint * 16 + Digit
                Else CodePoint := CodePoint * 10 + Digit;
      End;
      Inc(J);
     End;
     If Not ValidNumber Then CodePoint := -1;
    End
    Else
     CodePoint := HTMLNamedEntityCode(EntityName);

    If CodePoint >= 0 Then Begin
     If CodePoint = 160 Then ResultText := ResultText + ' '
     Else ResultText := ResultText + HTMLCodePointToChar(CodePoint);
    End
    Else
     ResultText := ResultText + Copy(S, I, SemiPos - I + 1);
    I := SemiPos + 1;
   End;
  End;
 End;
 HTMLDecodeEntities := ResultText;
End;

{ Fonction pour ignorer les espaces blancs }
Function HTMLSourceChar(Const S: HTMLSourceBuffer; Pos: LongInt): Char;
Var
 Chunk: HTMLBufferChunkPtr;
 Offset: LongInt;
Begin
 HTMLSourceChar := #0;
 If (S.FirstChunk = Nil) Or (Pos < 1) Or (Pos > S.DataLength) Then Exit;
 Offset := Pos - 1;
 Chunk := S.FirstChunk;
 While (Chunk <> Nil) And (Offset >= Chunk^.Used) Do Begin
  Offset := Offset - Chunk^.Used;
  Chunk := Chunk^.Next;
 End;
 If Chunk <> Nil Then HTMLSourceChar := Chunk^.Data[Offset];
End;

Function HTMLSourceCopy(Const S: HTMLSourceBuffer; StartPos, Count: LongInt): String;
Var
 I, CopyCount: Integer;
 ResultText: String;
Begin
 ResultText := '';
 If (S.FirstChunk = Nil) Or (StartPos < 1) Or (Count <= 0) Then Begin
  HTMLSourceCopy := ResultText;
  Exit;
 End;
 If StartPos + Count - 1 > S.DataLength Then
  Count := S.DataLength - StartPos + 1;
 If Count > 255 Then CopyCount := 255 Else CopyCount := Count;
 For I := 0 To CopyCount - 1 Do
  ResultText := ResultText + HTMLSourceChar(S, StartPos + I);
 HTMLSourceCopy := ResultText;
End;

Function HTMLSkipWhitespace(Const S: HTMLSourceBuffer; Pos: LongInt): LongInt;
Begin
 While (Pos <= S.DataLength) And
       (HTMLSourceChar(S, Pos) In [' ', #9, #10, #13]) Do
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
Begin
 New(Node);
 Node^.NodeType := HTML_NODE_ELEMENT;
 Node^.TagType := TAG_UNKNOWN;
 Node^.TagName := '';
 Node^.Content := '';
 Node^.FirstAttribute := Nil;
 Node^.LastAttribute := Nil;
 Node^.AttributeCount := 0;
 Node^.FirstChild := Nil;
 Node^.LastChild := Nil;
 Node^.PreviousSibling := Nil;
 Node^.NextSibling := Nil;
 Node^.ChildCount := 0;
 Node^.Parent := Nil;
 CreateHTMLNode := Node;
End;

Function HTMLAttributeAt(Node: HTMLNodePtr; Index: Integer): HTMLAttributePtr;
Var
 Attr: HTMLAttributePtr;
 I: Integer;
Begin
 HTMLAttributeAt := Nil;
 If (Node = Nil) Or (Index < 1) Then Exit;
 Attr := Node^.FirstAttribute;
 I := 1;
 While (Attr <> Nil) And (I < Index) Do Begin
  Attr := Attr^.Next;
  Inc(I);
 End;
 HTMLAttributeAt := Attr;
End;

Function HTMLChildAt(Node: HTMLNodePtr; Index: Integer): HTMLNodePtr;
Var
 Child: HTMLNodePtr;
 I: Integer;
Begin
 HTMLChildAt := Nil;
 If (Node = Nil) Or (Index < 1) Then Exit;
 Child := Node^.FirstChild;
 I := 1;
 While (Child <> Nil) And (I < Index) Do Begin
  Child := Child^.NextSibling;
  Inc(I);
 End;
 HTMLChildAt := Child;
End;

Procedure HTMLAddAttribute(Node: HTMLNodePtr; Const Name, Value: String);
Var
 Attr: HTMLAttributePtr;
Begin
 If Node = Nil Then Exit;
 New(Attr);
 Attr^.Name := Name;
 Attr^.Value := Value;
 Attr^.Next := Nil;
 If Node^.LastAttribute = Nil Then
  Node^.FirstAttribute := Attr
 Else
  Node^.LastAttribute^.Next := Attr;
 Node^.LastAttribute := Attr;
 Inc(Node^.AttributeCount);
End;

Procedure HTMLAppendChild(Parent, Child: HTMLNodePtr);
Begin
 If (Parent = Nil) Or (Child = Nil) Then Exit;
 Child^.Parent := Parent;
 Child^.PreviousSibling := Parent^.LastChild;
 Child^.NextSibling := Nil;
 If Parent^.LastChild = Nil Then
  Parent^.FirstChild := Child
 Else
  Parent^.LastChild^.NextSibling := Child;
 Parent^.LastChild := Child;
 Inc(Parent^.ChildCount);
End;

Procedure HTMLFreeAttributes(Node: HTMLNodePtr);
Var
 Attr, NextAttr: HTMLAttributePtr;
Begin
 If Node = Nil Then Exit;
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  NextAttr := Attr^.Next;
  Dispose(Attr);
  Attr := NextAttr;
 End;
 Node^.FirstAttribute := Nil;
 Node^.LastAttribute := Nil;
 Node^.AttributeCount := 0;
End;

{ Procedure pour liberer un noeud HTML et ses enfants }
Procedure FreeHTMLNode(Node: HTMLNodePtr);
Var
 Child, NextChild: HTMLNodePtr;
Begin
 If Node = Nil Then Exit;
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  NextChild := Child^.NextSibling;
  FreeHTMLNode(Child);
  Child := NextChild;
 End;
 HTMLFreeAttributes(Node);
 Dispose(Node);
End;

{ Fonction pour extraire le nom d'une balise }
Function ExtractTagName(Const S: HTMLSourceBuffer; Var Pos: LongInt): String;
Var
 StartPos: LongInt;
 TagName: String;
Begin
 TagName := '';
 Pos := HTMLSkipWhitespace(S, Pos);
 StartPos := Pos;
 While (Pos <= S.DataLength) And
       Not (HTMLSourceChar(S, Pos) In [' ', '>', '/', #9, #10, #13, '=']) Do
  Inc(Pos);
 TagName := HTMLSourceCopy(S, StartPos, Pos - StartPos);
 ExtractTagName := TagName;
End;

{ Fonction pour extraire la valeur d'un attribut }
Function ExtractAttributeValue(Const S: HTMLSourceBuffer; Var Pos: LongInt): String;
Var
 Quote: Char;
 StartPos: LongInt;
 Value: String;
Begin
 Value := '';
 Pos := HTMLSkipWhitespace(S, Pos);
 If Pos > S.DataLength Then Begin
  ExtractAttributeValue := '';
  Exit;
 End;
 { Verifier si la valeur est entre guillemets }
 If HTMLSourceChar(S, Pos) In ['"', ''''] Then Begin
  Quote := HTMLSourceChar(S, Pos);
  Inc(Pos);
  StartPos := Pos;
  While (Pos <= S.DataLength) And (HTMLSourceChar(S, Pos) <> Quote) Do
   Inc(Pos);
  Value := HTMLSourceCopy(S, StartPos, Pos - StartPos);
  If Pos <= S.DataLength Then Inc(Pos); { Passer le guillemet fermant }
 End
 Else Begin
  { Valeur sans guillemets }
  StartPos := Pos;
  While (Pos <= S.DataLength) And
        Not (HTMLSourceChar(S, Pos) In [' ', '>', '/', #9, #10, #13]) Do
   Inc(Pos);
  Value := HTMLSourceCopy(S, StartPos, Pos - StartPos);
 End;
  ExtractAttributeValue := HTMLDecodeEntities(Value);
End;

{ Procedure pour parser les attributs d'une balise }
Procedure ParseHTMLAttributes(Const S: HTMLSourceBuffer; Var Pos: LongInt;
                              Node: HTMLNodePtr);
Var
 AttrName, AttrValue: String;
Begin
 While Pos <= S.DataLength Do Begin
  Pos := HTMLSkipWhitespace(S, Pos);
  If Pos > S.DataLength Then Exit;
  If HTMLSourceChar(S, Pos) In ['>', '/'] Then Exit;

  { Extraire le nom de l'attribut }
  AttrName := ExtractTagName(S, Pos);
  If AttrName = '' Then Exit;

  Pos := HTMLSkipWhitespace(S, Pos);
  AttrValue := '';

  { Verifier s'il y a une valeur }
  If (Pos <= S.DataLength) And (HTMLSourceChar(S, Pos) = '=') Then Begin
   Inc(Pos);
   AttrValue := ExtractAttributeValue(S, Pos);
  End;

  { Ajouter l'attribut au noeud }
  HTMLAddAttribute(Node, HTMLLowerCase(AttrName), AttrValue);
 End;
End;

{ Fonction principale pour parser du HTML }
Function ParseHTML(Const HTMLSource: HTMLSourceBuffer): HTMLNodePtr;
Var
 Pos, StartPos, EndTagPos: LongInt;
 Root, CurrentNode, NewNode, TextNode, SearchNode: HTMLNodePtr;
 TagName, CloseTagName, TextContent: String;
 IsClosingTag, IsSelfClosing: Boolean;
 CurrentDepth: Integer;
Begin
 Root := CreateHTMLNode;
 Root^.NodeType := HTML_NODE_ELEMENT;
 Root^.TagName := 'document';
 Root^.TagType := TAG_UNKNOWN;
 CurrentNode := Root;
 CurrentDepth := 0;
 Pos := 1;
 HTMLParseError := '';

 While Pos <= HTMLSource.DataLength Do Begin
  { Chercher le debut d'une balise }
  StartPos := Pos;
  While (Pos <= HTMLSource.DataLength) And
        (HTMLSourceChar(HTMLSource, Pos) <> '<') Do
   Inc(Pos);

  { Traiter le texte avant la balise }
  If Pos > StartPos Then Begin
   TextContent := HTMLDecodeEntities(
                   HTMLSourceCopy(HTMLSource, StartPos, Pos - StartPos));
   { Ignorer le texte qui ne contient que des espaces }
   If Trim(TextContent) <> '' Then Begin
    TextNode := CreateHTMLNode;
    TextNode^.NodeType := HTML_NODE_TEXT;
    TextNode^.Content := TextContent;
    TextNode^.Parent := CurrentNode;
    HTMLAppendChild(CurrentNode, TextNode);
   End;
  End;

  If Pos > HTMLSource.DataLength Then Break;

  { On est sur un '<' }
  Inc(Pos);
  If Pos > HTMLSource.DataLength Then Break;

  { Verifier le type de balise }
  If HTMLSourceChar(HTMLSource, Pos) = '!' Then Begin
   { Commentaire ou DOCTYPE }
   Inc(Pos);
   If (Pos + 1 <= HTMLSource.DataLength) And
      (HTMLSourceChar(HTMLSource, Pos) = '-') And
      (HTMLSourceChar(HTMLSource, Pos + 1) = '-') Then Begin
    { Commentaire HTML <!-- ... --> }
    Inc(Pos, 2);
    StartPos := Pos;
    While (Pos + 2 <= HTMLSource.DataLength) And
          Not ((HTMLSourceChar(HTMLSource, Pos) = '-') And
               (HTMLSourceChar(HTMLSource, Pos + 1) = '-') And
               (HTMLSourceChar(HTMLSource, Pos + 2) = '>')) Do
     Inc(Pos);
    NewNode := CreateHTMLNode;
    NewNode^.NodeType := HTML_NODE_COMMENT;
    NewNode^.Content := HTMLSourceCopy(HTMLSource, StartPos, Pos - StartPos);
    NewNode^.Parent := CurrentNode;
    HTMLAppendChild(CurrentNode, NewNode);
    Inc(Pos, 3);
   End
   Else Begin
    { DOCTYPE ou autre declaration }
    While (Pos <= HTMLSource.DataLength) And
          (HTMLSourceChar(HTMLSource, Pos) <> '>') Do
     Inc(Pos);
    Inc(Pos);
   End;
  End
  Else If HTMLSourceChar(HTMLSource, Pos) = '/' Then Begin
   { Balise fermante </tag> }
   Inc(Pos);
   CloseTagName := ExtractTagName(HTMLSource, Pos);
   { Trouver le '>' }
   While (Pos <= HTMLSource.DataLength) And
         (HTMLSourceChar(HTMLSource, Pos) <> '>') Do
    Inc(Pos);
   Inc(Pos);
   { HTML reel est souvent imparfait: chercher l'ancetre correspondant au
     lieu de laisser chaque balise mal fermee augmenter la profondeur. }
   SearchNode := CurrentNode;
   While (SearchNode <> Root) And
         (HTMLLowerCase(SearchNode^.TagName) <> HTMLLowerCase(CloseTagName)) Do
    SearchNode := SearchNode^.Parent;
   If SearchNode <> Root Then Begin
    While CurrentNode <> SearchNode Do Begin
     CurrentNode := CurrentNode^.Parent;
     If CurrentDepth > 0 Then Dec(CurrentDepth);
    End;
    CurrentNode := SearchNode^.Parent;
    If CurrentDepth > 0 Then Dec(CurrentDepth);
   End;
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
    If (Pos <= HTMLSource.DataLength) And
       (HTMLSourceChar(HTMLSource, Pos) = '/') Then Begin
     IsSelfClosing := True;
     Inc(Pos);
    End;

    { Trouver le '>' }
    While (Pos <= HTMLSource.DataLength) And
          (HTMLSourceChar(HTMLSource, Pos) <> '>') Do
     Inc(Pos);
    Inc(Pos);

    { Ajouter le noeud comme enfant du noeud courant }
    HTMLAppendChild(CurrentNode, NewNode);

    { Si ce n'est pas une balise auto-fermante ou void, descendre dans le noeud }
    If Not IsSelfClosing And Not IsVoidElement(TagName) And
       (CurrentDepth < 32) Then Begin
     CurrentNode := NewNode;
     Inc(CurrentDepth);
    End;
   End;
  End;
 End;

 ParseHTML := Root;
End;

{ Fonction pour obtenir un attribut d'un noeud HTML }
Function GetHTMLAttribute(Node: HTMLNodePtr; Const AttrName: String): String;
Var
 Attr: HTMLAttributePtr;
 LowerName: String;
Begin
 GetHTMLAttribute := '';
 If Node = Nil Then Exit;
 LowerName := HTMLLowerCase(AttrName);
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  If Attr^.Name = LowerName Then Begin
   GetHTMLAttribute := Attr^.Value;
   Exit;
  End;
  Attr := Attr^.Next;
 End;
End;

{ Fonction pour trouver un element par son ID }
Function FindElementById(Node: HTMLNodePtr; Const Id: String): HTMLNodePtr;
Var
 Found: HTMLNodePtr;
 Child: HTMLNodePtr;
Begin
 FindElementById := Nil;
 If Node = Nil Then Exit;
 If GetHTMLAttribute(Node, 'id') = Id Then Begin
  FindElementById := Node;
  Exit;
 End;
 { Rechercher dans les enfants }
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  Found := FindElementById(Child, Id);
  If Found <> Nil Then Begin
   FindElementById := Found;
   Exit;
  End;
  Child := Child^.NextSibling;
 End;
End;

{ Fonction pour compter les elements avec un certain tag }
Function CountElementsByTag(Node: HTMLNodePtr; TagType: Byte): Integer;
Var
 Count: Integer;
 Child: HTMLNodePtr;
Begin
 Count := 0;
 If Node = Nil Then Begin
  CountElementsByTag := 0;
  Exit;
 End;
 If Node^.TagType = TagType Then Inc(Count);
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  Count := Count + CountElementsByTag(Child, TagType);
  Child := Child^.NextSibling;
 End;
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
    { Autre expression (ex: appel de fonction isole) - revenir en
      arriere et evaluer via le moteur d'expressions, qui avance Pos
      lui-meme. Rappeler JSEvaluate sur le meme texte rebouclerait
      indefiniment dans cette meme branche sans jamais progresser. }
    Pos := StartPos;
    JSEvaluate := JSEvalExpression(Script, Pos);
    Pos := JSSkipComments(Script, Pos);
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
 Attr: HTMLAttributePtr;
 LowerAttr, LowerName: String;
Begin
 DOMGetAttribute := '';
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  LowerName := HTMLLowerCase(Attr^.Name);
  If LowerName = LowerAttr Then Begin
   DOMGetAttribute := Attr^.Value;
   Exit;
  End;
  Attr := Attr^.Next;
 End;
End;

{ Definir un attribut sur un noeud HTML }
Procedure DOMSetAttribute(Node: HTMLNodePtr; AttrName, AttrValue: String);
Var
 Attr: HTMLAttributePtr;
 LowerAttr, LowerName: String;
Begin
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  LowerName := HTMLLowerCase(Attr^.Name);
  If LowerName = LowerAttr Then Begin
   Attr^.Value := AttrValue;
   Exit;
  End;
  Attr := Attr^.Next;
 End;
 HTMLAddAttribute(Node, HTMLLowerCase(AttrName), AttrValue);
End;

{ Supprimer un attribut d'un noeud HTML }
Procedure DOMRemoveAttribute(Node: HTMLNodePtr; AttrName: String);
Var
 Attr, PreviousAttr: HTMLAttributePtr;
 LowerAttr, LowerName: String;
Begin
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);

 PreviousAttr := Nil;
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  LowerName := HTMLLowerCase(Attr^.Name);
  If LowerName = LowerAttr Then Begin
   If PreviousAttr = Nil Then Node^.FirstAttribute := Attr^.Next
   Else PreviousAttr^.Next := Attr^.Next;
   If Node^.LastAttribute = Attr Then Node^.LastAttribute := PreviousAttr;
   Dispose(Attr);
   Dec(Node^.AttributeCount);
   Exit;
  End;
  PreviousAttr := Attr;
  Attr := Attr^.Next;
 End;
End;

{ Verifier si un noeud a un attribut }
Function DOMHasAttribute(Node: HTMLNodePtr; AttrName: String): Boolean;
Var
 Attr: HTMLAttributePtr;
 LowerAttr, LowerName: String;
Begin
 DOMHasAttribute := False;
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  LowerName := HTMLLowerCase(Attr^.Name);
  If LowerName = LowerAttr Then Begin
   DOMHasAttribute := True;
   Exit;
  End;
  Attr := Attr^.Next;
 End;
End;

{ Fonction recursive pour chercher un element par ID }
Function DOMGetElementByIdRecursive(Node: HTMLNodePtr; Id: String): HTMLNodePtr;
Var
 NodeId: String;
 Result, Child: HTMLNodePtr;
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
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  Result := DOMGetElementByIdRecursive(Child, Id);
  If Result <> Nil Then Begin
   DOMGetElementByIdRecursive := Result;
   Exit;
  End;
  Child := Child^.NextSibling;
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
 LowerTag, LowerNodeTag: String;
 Current: HTMLNodePtr;
Begin
 If Node = Nil Then Exit;

 LowerTag := HTMLLowerCase(TagName);
 Current := Node;
 While Current <> Nil Do Begin
  If Current^.NodeType = HTML_NODE_ELEMENT Then Begin
   LowerNodeTag := HTMLLowerCase(Current^.TagName);
   If (LowerTag = '*') Or (LowerNodeTag = LowerTag) Then Begin
    If List.Length < MAX_DOM_QUERY_RESULTS Then Begin
     Inc(List.Length);
     List.Nodes[List.Length] := Current;
    End;
   End;
  End;

  If Current^.FirstChild <> Nil Then
   Current := Current^.FirstChild
  Else Begin
   While (Current <> Nil) And (Current <> Node) And
         (Current^.NextSibling = Nil) Do
    Current := Current^.Parent;
   If Current = Node Then Current := Nil
   Else If Current <> Nil Then Current := Current^.NextSibling;
  End;
 End;
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
 Current: HTMLNodePtr;
Begin
 If Node = Nil Then Exit;
 Current := Node;
 While Current <> Nil Do Begin
  If DOMHasClass(Current, ClassName) Then Begin
   If List.Length < MAX_DOM_QUERY_RESULTS Then Begin
    Inc(List.Length);
    List.Nodes[List.Length] := Current;
   End;
  End;

  If Current^.FirstChild <> Nil Then
   Current := Current^.FirstChild
  Else Begin
   While (Current <> Nil) And (Current <> Node) And
         (Current^.NextSibling = Nil) Do
    Current := Current^.Parent;
   If Current = Node Then Current := Nil
   Else If Current <> Nil Then Current := Current^.NextSibling;
  End;
 End;
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
Function DOMGetTextContent(Node: HTMLNodePtr): AnsiString;
Var
 Result: AnsiString;
 Child: HTMLNodePtr;
Begin
 Result := '';
 If Node = Nil Then Begin
  DOMGetTextContent := Result;
  Exit;
 End;

 If Node^.NodeType = HTML_NODE_TEXT Then
  Result := Node^.Content
 Else Begin
  Child := Node^.FirstChild;
  While Child <> Nil Do Begin
   Result := Result + DOMGetTextContent(Child);
   Child := Child^.NextSibling;
  End;
 End;

 DOMGetTextContent := Result;
End;

{ Definir le texte d'un noeud (innerText/textContent) }
Procedure DOMSetTextContent(Node: HTMLNodePtr; Text: String);
Var
 Child, NextChild, TextNode: HTMLNodePtr;
Begin
 If Node = Nil Then Exit;

 { Supprimer tous les enfants existants }
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  NextChild := Child^.NextSibling;
  FreeHTMLNode(Child);
  Child := NextChild;
 End;
 Node^.FirstChild := Nil;
 Node^.LastChild := Nil;
 Node^.ChildCount := 0;

 { Creer un nouveau noeud texte comme seul enfant }
 If Length(Text) > 0 Then Begin
  TextNode := CreateHTMLNode;
  TextNode^.NodeType := HTML_NODE_TEXT;
  TextNode^.TagType := 0;
  TextNode^.Content := Text;
  HTMLAppendChild(Node, TextNode);
 End;
End;

{ Creer un nouvel element HTML (document.createElement) }
Function DOMCreateElement(TagName: String): HTMLNodePtr;
Var
 NewNode: HTMLNodePtr;
Begin
 NewNode := CreateHTMLNode;
 NewNode^.NodeType := HTML_NODE_ELEMENT;
 NewNode^.TagType := GetTagType(TagName);
 NewNode^.TagName := TagName;
 NewNode^.Content := '';
 DOMCreateElement := NewNode;
End;

{ Creer un noeud texte (document.createTextNode) }
Function DOMCreateTextNode(Text: String): HTMLNodePtr;
Var
 NewNode: HTMLNodePtr;
Begin
 NewNode := CreateHTMLNode;
 NewNode^.NodeType := HTML_NODE_TEXT;
 NewNode^.TagType := 0;
 NewNode^.TagName := '';
 NewNode^.Content := Text;
 DOMCreateTextNode := NewNode;
End;

{ Ajouter un enfant a un element (appendChild) }
Function DOMAppendChild(Parent, Child: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMAppendChild := Nil;
 If (Parent = Nil) Or (Child = Nil) Then Exit;

 HTMLAppendChild(Parent, Child);
 DOMAppendChild := Child;
End;

{ Inserer un enfant avant un autre (insertBefore) }
Function DOMInsertBefore(Parent, NewChild, RefChild: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMInsertBefore := Nil;
 If (Parent = Nil) Or (NewChild = Nil) Then Exit;

 If RefChild = Nil Then Begin
  { Inserer a la fin si pas de reference }
  DOMInsertBefore := DOMAppendChild(Parent, NewChild);
  Exit;
 End;

 If RefChild^.Parent <> Parent Then Exit;
 NewChild^.Parent := Parent;
 NewChild^.PreviousSibling := RefChild^.PreviousSibling;
 NewChild^.NextSibling := RefChild;
 If RefChild^.PreviousSibling <> Nil Then
  RefChild^.PreviousSibling^.NextSibling := NewChild
 Else
  Parent^.FirstChild := NewChild;
 RefChild^.PreviousSibling := NewChild;
 Inc(Parent^.ChildCount);
 DOMInsertBefore := NewChild;
End;

{ Supprimer un enfant (removeChild) }
Function DOMRemoveChild(Parent, Child: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMRemoveChild := Nil;
 If (Parent = Nil) Or (Child = Nil) Then Exit;

 If Child^.Parent <> Parent Then Exit;
 If Child^.PreviousSibling <> Nil Then
  Child^.PreviousSibling^.NextSibling := Child^.NextSibling
 Else Parent^.FirstChild := Child^.NextSibling;
 If Child^.NextSibling <> Nil Then
  Child^.NextSibling^.PreviousSibling := Child^.PreviousSibling
 Else Parent^.LastChild := Child^.PreviousSibling;
 Dec(Parent^.ChildCount);
 Child^.Parent := Nil;
 Child^.PreviousSibling := Nil;
 Child^.NextSibling := Nil;
 DOMRemoveChild := Child;
End;

{ Remplacer un enfant (replaceChild) }
Function DOMReplaceChild(Parent, NewChild, OldChild: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMReplaceChild := Nil;
 If (Parent = Nil) Or (NewChild = Nil) Or (OldChild = Nil) Then Exit;

 If OldChild^.Parent <> Parent Then Exit;
 NewChild^.Parent := Parent;
 NewChild^.PreviousSibling := OldChild^.PreviousSibling;
 NewChild^.NextSibling := OldChild^.NextSibling;
 If NewChild^.PreviousSibling <> Nil Then
  NewChild^.PreviousSibling^.NextSibling := NewChild
 Else Parent^.FirstChild := NewChild;
 If NewChild^.NextSibling <> Nil Then
  NewChild^.NextSibling^.PreviousSibling := NewChild
 Else Parent^.LastChild := NewChild;
 OldChild^.Parent := Nil;
 OldChild^.PreviousSibling := Nil;
 OldChild^.NextSibling := Nil;
 DOMReplaceChild := OldChild;
End;

{ Cloner un noeud (cloneNode) }
Function DOMCloneNode(Node: HTMLNodePtr; Deep: Boolean): HTMLNodePtr;
Var
 Clone, ChildClone, Child: HTMLNodePtr;
 Attr: HTMLAttributePtr;
Begin
 DOMCloneNode := Nil;
 If Node = Nil Then Exit;

 Clone := CreateHTMLNode;
 Clone^.NodeType := Node^.NodeType;
 Clone^.TagType := Node^.TagType;
 Clone^.TagName := Node^.TagName;
 Clone^.Content := Node^.Content;
 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  HTMLAddAttribute(Clone, Attr^.Name, Attr^.Value);
  Attr := Attr^.Next;
 End;

 { Cloner les enfants si demande }
 If Deep Then Begin
  Child := Node^.FirstChild;
  While Child <> Nil Do Begin
   ChildClone := DOMCloneNode(Child, True);
   If ChildClone <> Nil Then Begin
    HTMLAppendChild(Clone, ChildClone);
   End;
   Child := Child^.NextSibling;
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
  DOMGetFirstChild := Node^.FirstChild;
End;

{ Obtenir le dernier enfant (lastChild) }
Function DOMGetLastChild(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 If (Node = Nil) Or (Node^.ChildCount = 0) Then
  DOMGetLastChild := Nil
 Else
  DOMGetLastChild := Node^.LastChild;
End;

{ Obtenir le frere precedent (previousSibling) }
Function DOMGetPreviousSibling(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMGetPreviousSibling := Nil;
 If Node = Nil Then Exit;

 DOMGetPreviousSibling := Node^.PreviousSibling;
End;

{ Obtenir le frere suivant (nextSibling) }
Function DOMGetNextSibling(Node: HTMLNodePtr): HTMLNodePtr;
Begin
 DOMGetNextSibling := Nil;
 If Node = Nil Then Exit;

 DOMGetNextSibling := Node^.NextSibling;
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
{ NOTE IMPORTANTE : Pos est ici un LongInt (32 bits), pas Integer. La
  directive de compatibilite Turbo Pascal de ce fichier fait qu'Integer
  reste fidele a l'original et n'est que 16 bits (-32768..32767) !
  Une feuille de style reelle depasse presque toujours cette limite
  (49948 octets ici) : un compteur de position en Integer y deborde
  silencieusement vers une valeur negative au-dela de l'octet 32767,
  ce qui finit par indexer la chaine avec une position invalide et
  declenche EAccessViolation. C'est la veritable cause des
  plantages/blocages observes sur ce parseur (le filet de securite
  GuardPos plus bas en attenuait le symptome sans corriger la cause). }
Function CSSSkipWhitespace(Const S: AnsiString; Pos: LongInt): LongInt;
Begin
 While (Pos <= Length(S)) And (S[Pos] In [' ', #9, #10, #13]) Do
  Inc(Pos);
 CSSSkipWhitespace := Pos;
End;

{ Ignorer les commentaires CSS /* */ }
Function CSSSkipComment(Const S: AnsiString; Pos: LongInt): LongInt;
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
Function CSSSkipWhitespaceAndComments(Const S: AnsiString; Pos: LongInt): LongInt;
Var
 OldPos: LongInt;
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
Function CSSReadIdent(Const S: AnsiString; Var Pos: LongInt): String;
Var
 Start: LongInt;
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
Function CSSReadString(Const S: AnsiString; Var Pos: LongInt): String;
Var
 Quote: Char;
 Start: LongInt;
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
Procedure CSSReadNumber(Const S: AnsiString; Var Pos: LongInt; Var NumVal: Real;
                        Var UnitStr: CSSUnitString);
Var
 Start: LongInt;
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
Function CSSReadToken(Const S: AnsiString; Var Pos: LongInt): CSSToken;
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
Function CSSParseSimpleSelector(Const S: AnsiString; Var Pos: LongInt): CSSSelectorPart;
Var
 Part: CSSSelectorPart;
 Token: CSSToken;
 StartPos: LongInt;
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
Function CSSParseSelector(Const S: AnsiString; Var Pos: LongInt): CSSSelector;
Var
 Sel: CSSSelector;
 Part: CSSSelectorPart;
 Combinator: Byte;
 HasWhitespace: Boolean;
 StartPos: LongInt;
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
Procedure CSSParseDeclarations(Const S: AnsiString; Var Pos: LongInt; Var Rule: CSSRule);
Var
 PropName, PropValue: String;
 Token: CSSToken;
 Important: Boolean;
 StartValue: LongInt;
Begin
 { Chercher l'accolade ouvrante }
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

{ Parser une regle CSS directement dans sa destination. }
Procedure CSSParseRule(Const S: AnsiString; Var Pos: LongInt; Var Rule: CSSRule);
Var
 Sel: CSSSelector;
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

End;

{ Parser une feuille de style CSS complete }
Procedure CSSParseStylesheet(Const CSS: AnsiString);
Var
 Pos: LongInt;
 RuleIndex: Integer;
 GuardPos: LongInt;
 BraceLevel: Integer;
Begin
 Pos := 1;

 While (Pos >= 1) And (Pos <= Length(CSS)) Do Begin
  { Filet de securite : ce parseur ecrit a la main ne reconnait pas
    toute la syntaxe CSS3 (ex: selecteurs non standards). Si un appel
    plus bas ne fait aucun progres (ou corrompt Pos), on force
    l'avancement d'au moins un caractere plutot que de boucler/planter
    indefiniment sur une feuille de style reelle complexe. }
  GuardPos := Pos;

  Pos := CSSSkipWhitespaceAndComments(CSS, Pos);
  If Pos > Length(CSS) Then Break;

  { Ignorer les at-rules pour l'instant (sauf @charset) }
  If CSS[Pos] = '@' Then Begin
   Inc(Pos);
   While (Pos <= Length(CSS)) And (CSS[Pos] <> ';') And (CSS[Pos] <> '{') Do
    Inc(Pos);
   If (Pos <= Length(CSS)) And (CSS[Pos] = '{') Then Begin
    { At-rule avec bloc, par exemple @media : sauter le bloc en
      comptant les accolades imbriquees, sinon la 1ere regle a
      l'interieur du bloc referme prematurement le @media et derobe
      le reste du fichier au lieu de la feuille de style globale. }
    Inc(Pos);
    BraceLevel := 1;
    While (Pos <= Length(CSS)) And (BraceLevel > 0) Do Begin
     If CSS[Pos] = '{' Then Inc(BraceLevel)
     Else If CSS[Pos] = '}' Then Dec(BraceLevel);
     Inc(Pos);
    End;
   End
   Else If Pos <= Length(CSS) Then Inc(Pos);
   GuardPos := -1; { progres garanti par les boucles ci-dessus }
  End
  Else Begin
   { Parser directement dans la feuille globale pour eviter une CSSRule
     locale de plusieurs dizaines de Ko sur la pile. }
   If CSSGlobalStylesheet.RuleCount < MAX_CSS_RULES Then Begin
    RuleIndex := CSSGlobalStylesheet.RuleCount + 1;
    CSSParseRule(CSS, Pos, CSSGlobalStylesheet.Rules[RuleIndex]);
    If CSSGlobalStylesheet.Rules[RuleIndex].SelectorCount > 0 Then
     CSSGlobalStylesheet.RuleCount := RuleIndex;
   End
   Else Begin
    While (Pos <= Length(CSS)) And (CSS[Pos] <> '}') Do Inc(Pos);
    If Pos <= Length(CSS) Then Inc(Pos);
   End;
  End;

  { Garde anti-blocage : si rien n'a fait progresser Pos (ou si Pos est
    devenu invalide), on force un caractere d'avance. }
  If (GuardPos >= 0) And ((Pos <= GuardPos) Or (Pos < 1)) Then
   Pos := GuardPos + 1;
 End;
End;

{ Affecter une propriete CSS resolue au champ correspondant du style.
  Partagee par le style inline et les deux passes de cascade (normale
  puis !important) pour eviter de dupliquer ce grand Case et faciliter
  l'ajout futur de nouvelles proprietes en un seul endroit. }
Procedure CSSAssignProperty(PropId: Byte; Const Value: String; Var Style: DOMStyle);
Begin
 Case PropId Of
  CSS_PROP_COLOR: Style.Color := Value;
  CSS_PROP_BACKGROUND_COLOR: Style.BackgroundColor := Value;
  CSS_PROP_BACKGROUND: Style.BackgroundColor := Value;
  CSS_PROP_FONT_SIZE: Style.FontSize := Value;
  CSS_PROP_FONT_WEIGHT: Style.FontWeight := Value;
  CSS_PROP_FONT_STYLE: Style.FontStyle := Value;
  CSS_PROP_TEXT_DECORATION: Style.TextDecoration := Value;
  CSS_PROP_TEXT_ALIGN: Style.TextAlign := Value;
  CSS_PROP_DISPLAY: Style.Display := Value;
  CSS_PROP_VISIBILITY: Style.Visibility := Value;
  CSS_PROP_WIDTH: Style.Width := Value;
  CSS_PROP_HEIGHT: Style.Height := Value;
  CSS_PROP_MARGIN: Style.Margin := Value;
  CSS_PROP_MARGIN_TOP: Style.MarginTop := Value;
  CSS_PROP_MARGIN_RIGHT: Style.MarginRight := Value;
  CSS_PROP_MARGIN_BOTTOM: Style.MarginBottom := Value;
  CSS_PROP_MARGIN_LEFT: Style.MarginLeft := Value;
  CSS_PROP_PADDING: Style.Padding := Value;
  CSS_PROP_PADDING_TOP: Style.PaddingTop := Value;
  CSS_PROP_PADDING_RIGHT: Style.PaddingRight := Value;
  CSS_PROP_PADDING_BOTTOM: Style.PaddingBottom := Value;
  CSS_PROP_PADDING_LEFT: Style.PaddingLeft := Value;
  CSS_PROP_BORDER: Style.Border := Value;
  CSS_PROP_BORDER_COLOR: Style.BorderColor := Value;
  CSS_PROP_BORDER_WIDTH: Style.BorderWidth := Value;
  CSS_PROP_BORDER_STYLE: Style.BorderStyle := Value;
  CSS_PROP_POSITION: Style.PositionProp := Value;
  CSS_PROP_TOP: Style.TopProp := Value;
  CSS_PROP_RIGHT: Style.RightProp := Value;
  CSS_PROP_LEFT: Style.LeftProp := Value;
  CSS_PROP_BOTTOM: Style.BottomProp := Value;
  CSS_PROP_FLOAT: Style.Float := Value;
  CSS_PROP_CLEAR: Style.ClearProp := Value;
  CSS_PROP_LINE_HEIGHT: Style.LineHeight := Value;
  CSS_PROP_OVERFLOW: Style.Overflow := Value;
  CSS_PROP_LIST_STYLE: Style.ListStyle := Value;
  CSS_PROP_LIST_STYLE_TYPE: Style.ListStyleType := Value;
  CSS_PROP_VERTICAL_ALIGN: Style.VerticalAlign := Value;
  CSS_PROP_WHITE_SPACE: Style.WhiteSpace := Value;
 End;
End;

{ Parser un attribut style inline }
Procedure CSSParseInlineStyle(Const StyleAttr: String; Var Style: DOMStyle);
Var
 Pos: LongInt;
 PropName, PropValue: String;
 StartValue: LongInt;
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

  { Appliquer la propriete au style - meme table que les feuilles de
    style (CSSGetPropertyId/CSSAssignProperty), pour que le style
    inline reconnaisse exactement les memes proprietes. }
  CSSAssignProperty(CSSGetPropertyId(PropName), PropValue, Style);

  If (Pos <= Length(StyleAttr)) And (StyleAttr[Pos] = ';') Then Inc(Pos);
 End;
End;

{ Verifier si un selecteur correspond a un element }
Function CSSMatchSelector(Const Sel: CSSSelector; Element: HTMLNodePtr): Boolean;
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

  { Passer au noeud suivant selon le combinateur : Sel.Parts[I] (et
    non Parts[I-1]) contient le combinateur qui relie la partie I a
    la partie I-1, puisque c'est la valeur enregistree par
    CSSParseSelector juste avant d'ajouter la partie I. Avec le
    mauvais index, un selecteur compose comme "li.Foo" (Combinator =
    CSS_COMB_NONE) etait traite comme un descendant ("li .Foo"),
    remontant vers le parent au lieu de re-tester le meme element -
    ce qui faisait silencieusement echouer la quasi-totalite des
    selecteurs composes (balise+classe, balise+id, etc.). }
  If I > 1 Then Begin
   Case Sel.Parts[I].Combinator Of
    CSS_COMB_NONE: { Selecteur compose : rester sur le meme element } ;
    CSS_COMB_DESCENDANT: Node := Node^.Parent;
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
 I, J, K: Integer;
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
  For J := 1 To CSSGlobalStylesheet.Rules[I].SelectorCount Do Begin
   If CSSMatchSelector(CSSGlobalStylesheet.Rules[I].Selectors[J], Element) Then Begin
    { Appliquer les proprietes }
    For K := 1 To CSSGlobalStylesheet.Rules[I].PropertyCount Do Begin
     Case CSSGlobalStylesheet.Rules[I].Properties[K].PropId Of
      CSS_PROP_COLOR: Style.Color := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_BACKGROUND_COLOR: Style.BackgroundColor := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_FONT_SIZE: Style.FontSize := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_FONT_WEIGHT: Style.FontWeight := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_FONT_STYLE: Style.FontStyle := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_TEXT_DECORATION: Style.TextDecoration := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_DISPLAY: Style.Display := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_VISIBILITY: Style.Visibility := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_WIDTH: Style.Width := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_HEIGHT: Style.Height := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_MARGIN: Style.Margin := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_PADDING: Style.Padding := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
      CSS_PROP_BORDER: Style.Border := CSSGlobalStylesheet.Rules[I].Properties[K].Value;
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
{ Table RGB de la palette EGA/VGA 16 couleurs standard (index = couleur
  BGI 0..15), utilisee pour trouver la couleur la plus proche d'une
  couleur CSS hexadecimale ou rgb(). }
Const
 EGAPaletteR: Array[0..15] Of Byte = (0,0,0,0,170,170,170,170,85,85,85,85,255,255,255,255);
 EGAPaletteG: Array[0..15] Of Byte = (0,0,170,170,0,0,85,170,85,85,255,255,85,85,255,255);
 EGAPaletteB: Array[0..15] Of Byte = (0,170,0,170,0,170,0,170,85,255,85,255,85,255,85,255);

{ Trouver l'index EGA/VGA (0..15) le plus proche d'une couleur RGB 24
  bits, par distance euclidienne au carre (pas besoin de racine pour
  comparer). }
Function CSSRGBToIndex(R, G, B: Byte): Integer;
Var
 I, DR, DG, DB: Integer;
 Dist, BestDist: LongInt;
 BestIdx: Integer;
Begin
 BestIdx := 0;
 BestDist := MaxLongInt;
 For I := 0 To 15 Do Begin
  DR := R - EGAPaletteR[I];
  DG := G - EGAPaletteG[I];
  DB := B - EGAPaletteB[I];
  Dist := LongInt(DR) * DR + LongInt(DG) * DG + LongInt(DB) * DB;
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestIdx := I;
  End;
 End;
 CSSRGBToIndex := BestIdx;
End;

{ Convertir un chiffre hexadecimal en valeur 0..15, -1 si invalide }
Function CSSHexDigit(C: Char): Integer;
Begin
 If C In ['0'..'9'] Then CSSHexDigit := Ord(C) - Ord('0')
 Else If C In ['A'..'F'] Then CSSHexDigit := Ord(C) - Ord('A') + 10
 Else If C In ['a'..'f'] Then CSSHexDigit := Ord(C) - Ord('a') + 10
 Else CSSHexDigit := -1;
End;

{ Parser une couleur hexadecimale CSS (#RGB ou #RRGGBB) ; retourne -1
  si la chaine n'est pas un hexadecimal valide. }
Function CSSParseHexColor(Const ColorStr: String): Integer;
Var
 H: String;
 R, G, B: Integer;
 D1, D2, D3, D4, D5, D6: Integer;
Begin
 CSSParseHexColor := -1;
 If (Length(ColorStr) = 0) Or (ColorStr[1] <> '#') Then Exit;
 H := Copy(ColorStr, 2, Length(ColorStr) - 1);

 If Length(H) = 3 Then Begin
  D1 := CSSHexDigit(H[1]); D2 := CSSHexDigit(H[2]); D3 := CSSHexDigit(H[3]);
  If (D1 < 0) Or (D2 < 0) Or (D3 < 0) Then Exit;
  R := D1 * 16 + D1; G := D2 * 16 + D2; B := D3 * 16 + D3;
 End Else If Length(H) = 6 Then Begin
  D1 := CSSHexDigit(H[1]); D2 := CSSHexDigit(H[2]);
  D3 := CSSHexDigit(H[3]); D4 := CSSHexDigit(H[4]);
  D5 := CSSHexDigit(H[5]); D6 := CSSHexDigit(H[6]);
  If (D1 < 0) Or (D2 < 0) Or (D3 < 0) Or (D4 < 0) Or (D5 < 0) Or (D6 < 0) Then Exit;
  R := D1 * 16 + D2; G := D3 * 16 + D4; B := D5 * 16 + D6;
 End Else
  Exit;

 CSSParseHexColor := CSSRGBToIndex(R, G, B);
End;

{ Parser une couleur CSS rgb(r,g,b) ou rgba(r,g,b,a) ; retourne -1 si
  la chaine n'a pas ce format. }
Function CSSParseRGBFunc(Const ColorStr: String): Integer;
Var
 LowerColor, NumStr: String;
 P, I: Integer;
 Vals: Array[1..3] Of Integer;
 ValCount, Code: Integer;
Begin
 CSSParseRGBFunc := -1;
 LowerColor := HTMLLowerCase(ColorStr);
 P := System.Pos('(', LowerColor);
 If ((System.Pos('rgb', LowerColor) <> 1) And (System.Pos('rgba', LowerColor) <> 1)) Or
    (P = 0) Then Exit;

 ValCount := 0;
 I := P + 1;
 While (I <= Length(LowerColor)) And (ValCount < 3) Do Begin
  While (I <= Length(LowerColor)) And (LowerColor[I] In [' ', ',']) Do Inc(I);
  NumStr := '';
  While (I <= Length(LowerColor)) And (LowerColor[I] In ['0'..'9']) Do Begin
   NumStr := NumStr + LowerColor[I];
   Inc(I);
  End;
  If Length(NumStr) = 0 Then Break;
  Inc(ValCount);
  Val(NumStr, Vals[ValCount], Code);
  If Code <> 0 Then Exit;
  While (I <= Length(LowerColor)) And (LowerColor[I] <> ',') And (LowerColor[I] <> ')') Do Inc(I);
  If (I <= Length(LowerColor)) And (LowerColor[I] = ',') Then Inc(I);
 End;
 If ValCount < 3 Then Exit;

 CSSParseRGBFunc := CSSRGBToIndex(Vals[1], Vals[2], Vals[3]);
End;

Function CSSColorToIndex(Const ColorStr: String): Integer;
Var
 LowerColor: String;
 HexResult: Integer;
Begin
 { Couleurs hexadecimales (#RGB / #RRGGBB) - format le plus courant en
   CSS reel, totalement absent ici auparavant : toute couleur definie
   en hexadecimal etait silencieusement ignoree. }
 If (Length(ColorStr) > 0) And (ColorStr[1] = '#') Then Begin
  HexResult := CSSParseHexColor(ColorStr);
  CSSColorToIndex := HexResult;
  Exit;
 End;

 { Fonctions rgb()/rgba() }
 If (System.Pos('rgb', HTMLLowerCase(ColorStr)) = 1) Then Begin
  CSSColorToIndex := CSSParseRGBFunc(ColorStr);
  Exit;
 End;

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
{ Resoudre le chemin d'une feuille de style externe (href de <link>)
  par rapport a l'URL/fichier courant - meme principe que
  BMPBuildImagePath pour les images (cf. plus loin dans ce fichier). }
Function CSSBuildStylesheetPath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  CSSBuildStylesheetPath := Src;
  Exit;
 End;

 BasePath := CurrentURL;
 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 CSSBuildStylesheetPath := BasePath + Src;
End;

{ Charger un fichier texte entier (feuille de style externe) dans une
  AnsiString, sans la limite de 255 caracteres des String courtes
  (directive H moins de ce fichier) : indispensable car une feuille
  de style reelle depasse presque toujours 255 octets. }
Function LoadTextFileAsString(Const FileName: String): AnsiString;
Var
 F: File;
 Buf: Array[1..4096] Of Char;
 BytesRead: Word;
 Total: AnsiString;
Begin
 Total := '';
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  LoadTextFileAsString := '';
  Exit;
 End;
 Repeat
  BlockRead(F, Buf, SizeOf(Buf), BytesRead);
  If BytesRead > 0 Then Begin
   SetLength(Total, Length(Total) + BytesRead);
   Move(Buf, Total[Length(Total) - BytesRead + 1], BytesRead);
  End;
 Until BytesRead < SizeOf(Buf);
 Close(F);
 LoadTextFileAsString := Total;
End;

Procedure CSSExtractFromDocument;
Var
 List: DOMNodeList;
 I: Integer;
 StyleContent: AnsiString;
 RelAttr, HrefAttr, CSSPath: String;
 ExternalCSS: AnsiString;
Begin
 { Feuilles de style en ligne : <style>...</style> }
 List := DOMGetElementsByTagName('style');
 For I := 1 To List.Length Do Begin
  StyleContent := DOMGetTextContent(List.Nodes[I]);
  If Length(StyleContent) > 0 Then
   CSSParseStylesheet(StyleContent);
 End;

 { Feuilles de style externes : <link rel="stylesheet" href="..."> }
 List := DOMGetElementsByTagName('link');
 For I := 1 To List.Length Do Begin
  RelAttr := HTMLLowerCase(GetHTMLAttribute(List.Nodes[I], 'rel'));
  If RelAttr = 'stylesheet' Then Begin
   HrefAttr := GetHTMLAttribute(List.Nodes[I], 'href');
   If Length(HrefAttr) > 0 Then Begin
    CSSPath := CSSBuildStylesheetPath(HrefAttr);
    ExternalCSS := LoadTextFileAsString(CSSPath);
    If Length(ExternalCSS) > 0 Then
     CSSParseStylesheet(ExternalCSS);
   End;
  End;
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
  RuleIndex: Integer;
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

{ Resoudre la cascade CSS pour un element.
  L'heritage est transporte par RenderContext pendant le parcours du DOM;
  remonter recursivement tous les parents ici doublait la profondeur de pile. }

Procedure CSSResolveCascade(Element: HTMLNodePtr; Var Style: DOMStyle);
Var
 I, J, RuleIndex: Integer;
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
 Style.TextAlign := '';
 Style.LineHeight := '';
 Style.Float := '';
 Style.ClearProp := '';
 Style.PositionProp := '';
 Style.TopProp := '';
 Style.RightProp := '';
 Style.BottomProp := '';
 Style.LeftProp := '';
 Style.ListStyle := '';
 Style.ListStyleType := '';
 Style.VerticalAlign := '';
 Style.WhiteSpace := '';
 Style.Overflow := '';
 Style.MarginTop := '';
 Style.MarginRight := '';
 Style.MarginBottom := '';
 Style.MarginLeft := '';
 Style.PaddingTop := '';
 Style.PaddingRight := '';
 Style.PaddingBottom := '';
 Style.PaddingLeft := '';
 Style.BorderColor := '';
 Style.BorderWidth := '';
 Style.BorderStyle := '';

 If Element = Nil Then Exit;

 { Collecter les regles correspondantes }
 MatchedCount := 0;
 For I := 1 To CSSGlobalStylesheet.RuleCount Do Begin
  For J := 1 To CSSGlobalStylesheet.Rules[I].SelectorCount Do Begin
   If CSSMatchSelector(CSSGlobalStylesheet.Rules[I].Selectors[J], Element) Then Begin
    If MatchedCount < 128 Then Begin
     Inc(MatchedCount);
     MatchedRules[MatchedCount].RuleIndex := I;
     MatchedRules[MatchedCount].SelectorIndex := J;
     MatchedRules[MatchedCount].Specificity :=
      CSSGlobalStylesheet.Rules[I].Selectors[J].Specificity;
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
  RuleIndex := MatchedRules[I].RuleIndex;
  For J := 1 To CSSGlobalStylesheet.Rules[RuleIndex].PropertyCount Do Begin
   If Not CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].Important Then
    CSSAssignProperty(CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].PropId,
     CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].Value, Style);
  End;
 End;

 { Ensuite les regles !important }
 For I := 1 To MatchedCount Do Begin
  RuleIndex := MatchedRules[I].RuleIndex;
  For J := 1 To CSSGlobalStylesheet.Rules[RuleIndex].PropertyCount Do Begin
   If CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].Important Then
    CSSAssignProperty(CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].PropId,
     CSSGlobalStylesheet.Rules[RuleIndex].Properties[J].Value, Style);
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

 { Appliquer text-decoration (underline et/ou line-through, separes
   par un espace en CSS, ex: "underline line-through") }
 If Length(Style.TextDecoration) > 0 Then Begin
  If HTMLLowerCase(Style.TextDecoration) = 'none' Then Begin
   Ctx.TextStyle := Ctx.TextStyle And (Not TEXT_STYLE_UNDERLINE) And (Not TEXT_STYLE_STRIKE);
  End Else Begin
   If System.Pos('underline', HTMLLowerCase(Style.TextDecoration)) > 0 Then
    Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_UNDERLINE;
   If System.Pos('line-through', HTMLLowerCase(Style.TextDecoration)) > 0 Then
    Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_STRIKE;
  End;
 End;

 { Appliquer visibility }
 If HTMLLowerCase(Style.Visibility) = 'hidden' Then Begin
  { Element cache mais prend de l'espace - simuler en ne pas dessiner }
  { Note: necessiterait un flag InVisible dans le contexte }
 End;

 { Appliquer text-align }
 If Length(Style.TextAlign) > 0 Then Begin
  If HTMLLowerCase(Style.TextAlign) = 'center' Then
   Ctx.TextAlignMode := ALIGN_CENTER
  Else If HTMLLowerCase(Style.TextAlign) = 'right' Then
   Ctx.TextAlignMode := ALIGN_RIGHT
  Else
   Ctx.TextAlignMode := ALIGN_LEFT;
 End;

 { Appliquer white-space: nowrap (empeche le retour a la ligne
   automatique - utilise par ex. par les icones d'en-tete sprites) }
 If Length(Style.WhiteSpace) > 0 Then
  Ctx.NoWrap := HTMLLowerCase(Style.WhiteSpace) = 'nowrap';
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

{ Calculer la boite CSS (marges/padding/bordure/fond) d'un element a
  partir de son style resolu. -1 dans MarginTopPx/.../PaddingBottomPx
  signifie "non specifie", le gestionnaire de balise garde alors sa
  propre constante d'espacement par defaut. Le raccourci (Margin,
  Padding, Border) est utilise si le cote specifique n'est pas defini ;
  CSSParseDimension gere correctement le cas d'un raccourci a plusieurs
  valeurs (ex: "4px 8px") en ne lisant que le premier nombre. }
Function ComputeElementBoxInfo(Const Style: DOMStyle): TElementBoxInfo;
Var
 Info: TElementBoxInfo;
 BorderTokens, Tok: String;
 P: Integer;
 TryColor: Integer;
Begin
 Info.MarginTopPx := -1;
 Info.MarginBottomPx := -1;
 Info.PaddingTopPx := -1;
 Info.PaddingBottomPx := -1;
 Info.HasBorder := False;
 Info.BorderWidthPx := 0;
 Info.BorderColorIdx := 0;
 Info.HasBgBox := False;
 Info.BgBoxColorIdx := 0;

 If Length(Style.MarginTop) > 0 Then
  Info.MarginTopPx := CSSParseDimension(Style.MarginTop, 0)
 Else If Length(Style.Margin) > 0 Then
  Info.MarginTopPx := CSSParseDimension(Style.Margin, 0);

 If Length(Style.MarginBottom) > 0 Then
  Info.MarginBottomPx := CSSParseDimension(Style.MarginBottom, 0)
 Else If Length(Style.Margin) > 0 Then
  Info.MarginBottomPx := CSSParseDimension(Style.Margin, 0);

 If Length(Style.PaddingTop) > 0 Then
  Info.PaddingTopPx := CSSParseDimension(Style.PaddingTop, 0)
 Else If Length(Style.Padding) > 0 Then
  Info.PaddingTopPx := CSSParseDimension(Style.Padding, 0);

 If Length(Style.PaddingBottom) > 0 Then
  Info.PaddingBottomPx := CSSParseDimension(Style.PaddingBottom, 0)
 Else If Length(Style.Padding) > 0 Then
  Info.PaddingBottomPx := CSSParseDimension(Style.Padding, 0);

 { Bordure : largeur et couleur, depuis les sous-proprietes ou le
   raccourci "border: 1px solid #003366" }
 If Length(Style.BorderWidth) > 0 Then
  Info.BorderWidthPx := CSSParseDimension(Style.BorderWidth, 0)
 Else If Length(Style.Border) > 0 Then
  Info.BorderWidthPx := CSSParseDimension(Style.Border, 0);

 If Length(Style.BorderColor) > 0 Then Begin
  TryColor := CSSColorToIndex(Style.BorderColor);
  If TryColor >= 0 Then Info.BorderColorIdx := TryColor;
 End Else If Length(Style.Border) > 0 Then Begin
  { Chercher un jeton ressemblant a une couleur dans le raccourci }
  BorderTokens := Style.Border + ' ';
  P := System.Pos(' ', BorderTokens);
  While P > 0 Do Begin
   Tok := Copy(BorderTokens, 1, P - 1);
   BorderTokens := Copy(BorderTokens, P + 1, Length(BorderTokens) - P);
   If Length(Tok) > 0 Then Begin
    TryColor := CSSColorToIndex(Tok);
    If TryColor >= 0 Then Info.BorderColorIdx := TryColor;
   End;
   P := System.Pos(' ', BorderTokens);
  End;
 End;

 Info.HasBorder := Info.BorderWidthPx > 0;
 If Length(Style.BorderStyle) > 0 Then
  Info.HasBorder := Info.HasBorder And (HTMLLowerCase(Style.BorderStyle) <> 'none');

 { Fond plein de la boite (pas seulement derriere les mots, voir
   RenderStyledWord) : seulement si la balise est un bloc avec une
   couleur de fond explicite. }
 If Length(Style.BackgroundColor) > 0 Then Begin
  TryColor := CSSColorToIndex(Style.BackgroundColor);
  If TryColor >= 0 Then Begin
   Info.HasBgBox := True;
   Info.BgBoxColorIdx := TryColor;
  End;
 End;

 ComputeElementBoxInfo := Info;
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
 { RenderOriginX/Y = ancre de positionnement du contenu, decalee selon
   le defilement courant. Ctx.MaxX/MaxY restent bases sur la VRAIE
   position fixe de la zone de rendu (independants du defilement) :
   Ctx.MaxX est la limite de retour a la ligne (elle ne doit pas
   bouger avec ScrollX, sinon le texte se reformaterait a chaque clic
   sur la barre horizontale) ; Ctx.MaxY est etendu d'une marge de
   mesure pour pouvoir detecter, en une seule passe, s'il reste du
   contenu sous la zone visible (voir RenderHTMLDocument). }
 RenderOriginX := RENDER_AREA_X - ScrollX;
 RenderOriginY := RENDER_AREA_Y - ScrollY;
 Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT;
 Ctx.Y := RenderOriginY + RENDER_MARGIN_TOP;
 Ctx.MaxX := RENDER_AREA_X + (RENDER_AREA_WIDTH - SCROLLBAR_SIZE) - RENDER_MARGIN_LEFT;
 Ctx.MaxY := RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE) + SCROLL_MEASURE_MARGIN;
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
 Ctx.NoWrap := False;
 Ctx.TextAlignMode := ALIGN_LEFT;
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
 Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
 Ctx.Y := Ctx.Y + Ctx.LineHeight;
End;

{ Procedure pour ajouter un espacement de bloc }
Procedure RenderBlockSpacing(Var Ctx: RenderContext; Spacing: Integer);
Begin
 Ctx.Y := Ctx.Y + Spacing;
 Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
End;

{ Fonction pour calculer la largeur d'un texte }
Function GetTextWidth(Const Text: String): Integer;
Begin
 GetTextWidth := Length(Text) * 8; { Police par defaut = 8 pixels par caractere }
End;

{ Decaler Ctx.X selon text-align (centre/droite) avant de rendre le
  contenu d'un element de bloc. Approximation : on mesure la largeur
  du texte de TOUT le sous-arbre (DOMGetTextContent) et on suppose
  qu'il tient sur une seule ligne, ce qui est exact pour les titres et
  la plupart des paragraphes courts ; un paragraphe long se reformate
  sur plusieurs lignes a partir de ce meme decalage initial (un
  centrage parfait ligne par ligne demanderait de bufferiser chaque
  ligne avant de la dessiner, hors de portee raisonnable ici). }
Procedure ApplyTextAlignOffset(Var Ctx: RenderContext; Node: HTMLNodePtr);
Var
 ContentWidth, AvailWidth, LineStart: Integer;
Begin
 If Ctx.TextAlignMode = ALIGN_LEFT Then Exit;
 LineStart := Ctx.X;
 ContentWidth := GetTextWidth(DOMGetTextContent(Node));
 AvailWidth := Ctx.MaxX - LineStart;
 If ContentWidth >= AvailWidth Then Exit; { ne tient pas sur une ligne : laisser le wrap normal }
 If Ctx.TextAlignMode = ALIGN_CENTER Then
  Ctx.X := LineStart + ((AvailWidth - ContentWidth) Div 2)
 Else If Ctx.TextAlignMode = ALIGN_RIGHT Then
  Ctx.X := LineStart + (AvailWidth - ContentWidth);
 If Ctx.X < LineStart Then Ctx.X := LineStart;
End;

{ Procedure pour afficher du texte avec retour a la ligne automatique }
{ Dessiner un seul mot avec les styles actifs (gras/souligne/barre/
  fond) : Ctx.TextStyle et Ctx.BgColor sont mis a jour partout dans le
  moteur de rendu (balises B/STRONG/I/EM/U/S/MARK/CSS font-weight/
  text-decoration/etc.) mais n'etaient jusqu'ici jamais consultes au
  moment de dessiner - le texte sortait toujours "normal". }
Procedure RenderStyledWord(Var Ctx: RenderContext; Const Word: String; WordWidth: Integer);
Var
 UnderlineY, StrikeY: Integer;
Begin
 { Fond du mot, si different du fond de page par defaut }
 If Ctx.BgColor <> RENDER_BG_COLOR Then Begin
  SetFillStyle(SolidFill, Ctx.BgColor);
  Bar(Ctx.X, Ctx.Y, Ctx.X + WordWidth, Ctx.Y + Ctx.LineHeight - 2);
 End;

 SetColor(Ctx.TextColor);
 OutTextXY(Ctx.X, Ctx.Y, Word);
 { Gras simule par un second trace decale de 1 pixel : la police
   bitmap par defaut n'a pas de variante grasse. }
 If (Ctx.TextStyle And TEXT_STYLE_BOLD) <> 0 Then
  OutTextXY(Ctx.X + 1, Ctx.Y, Word);

 If (Ctx.TextStyle And TEXT_STYLE_UNDERLINE) <> 0 Then Begin
  UnderlineY := Ctx.Y + 9;
  Line(Ctx.X, UnderlineY, Ctx.X + WordWidth, UnderlineY);
 End;

 If (Ctx.TextStyle And TEXT_STYLE_STRIKE) <> 0 Then Begin
  StrikeY := Ctx.Y + 4;
  Line(Ctx.X, StrikeY, Ctx.X + WordWidth, StrikeY);
 End;
End;

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
    If (Not Ctx.NoWrap) And
       (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
     RenderNewLine(Ctx);
   End
   Else If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then Begin
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

  { Retour a la ligne si le mot ne tient pas (sauf white-space:nowrap,
    qui demande explicitement de ne jamais retourner a la ligne -
    utilise par ex. par les icones d'en-tete en sprite) }
  If (Not Ctx.NoWrap) And (Ctx.X + WordWidth > Ctx.MaxX) And
     (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
   RenderNewLine(Ctx);

  { Afficher le mot uniquement s'il est dans la bande visible (entre
    la barre d'URL et la barre de defilement horizontale) ; on avance
    quand meme Ctx.X pour garder une mise en page coherente et pour
    detecter un eventuel debordement (mot plus large que la zone). }
  If (Ctx.Y >= RENDER_AREA_Y) And
     (Ctx.Y <= RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE)) Then
   RenderStyledWord(Ctx, Word, WordWidth);
  Ctx.X := Ctx.X + WordWidth;
  If Ctx.X > ContentOverflowX Then ContentOverflowX := Ctx.X;
 End;
End;

{ Declaration forward pour la recursion }
Procedure RenderHTMLNode(Node: HTMLNodePtr; Var Ctx: RenderContext); Forward;

{ Procedure pour rendre les enfants d'un noeud }
Procedure RenderChildren(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 Child: HTMLNodePtr;
Begin
 Child := Node^.FirstChild;
 While Child <> Nil Do Begin
  RenderHTMLNode(Child, Ctx);
  Child := Child^.NextSibling;
 End;
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
Var
 WantsBlock: Boolean;
 Box: TElementBoxInfo;
 MarginTopPx, MarginBottomPx, PaddingTopPx, PaddingBottomPx: Integer;
 BoxStartX, BoxStartY, BoxEndY: Integer;
Begin
 WantsBlock := CurrentElementWantsBlock;
 Box := CurrentElementBox;
 If Box.MarginTopPx >= 0 Then MarginTopPx := Box.MarginTopPx Else MarginTopPx := RENDER_DIV_MARGIN;
 If Box.MarginBottomPx >= 0 Then MarginBottomPx := Box.MarginBottomPx Else MarginBottomPx := RENDER_DIV_MARGIN;
 If Box.PaddingTopPx >= 0 Then PaddingTopPx := Box.PaddingTopPx Else PaddingTopPx := 0;
 If Box.PaddingBottomPx >= 0 Then PaddingBottomPx := Box.PaddingBottomPx Else PaddingBottomPx := 0;

 { DIV est un element de bloc par defaut - nouvelle ligne avant et
   apres - sauf si le CSS demande display:inline/inline-block. }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  Inc(Ctx.BlockLevel);
  RenderBlockSpacing(Ctx, MarginTopPx);
  BoxStartX := RenderOriginX + RENDER_MARGIN_LEFT;
  BoxStartY := Ctx.Y;
  If PaddingTopPx > 0 Then Ctx.Y := Ctx.Y + PaddingTopPx;
  ApplyTextAlignOffset(Ctx, Node);
 End;

 RenderChildren(Node, Ctx);

 If WantsBlock Then Begin
  If PaddingBottomPx > 0 Then Ctx.Y := Ctx.Y + PaddingBottomPx;
  BoxEndY := Ctx.Y;
  { Bordure dessinee apres le contenu (simple contour, ne recouvre
    donc pas le texte deja trace - un fond plein devrait etre dessine
    AVANT le contenu, ce qui demanderait de connaitre la hauteur de la
    boite a l'avance ; non implemente pour cette raison). }
  If Box.HasBorder Then Begin
   SetColor(Box.BorderColorIdx);
   Rectangle(BoxStartX, BoxStartY, Ctx.MaxX, BoxEndY);
   SetColor(Ctx.TextColor);
  End;
  Dec(Ctx.BlockLevel);
  RenderBlockSpacing(Ctx, MarginBottomPx);
 End;
End;

{ Procedure pour rendre la balise SPAN (inline) }
Procedure RenderTagSpan(Node: HTMLNodePtr; Var Ctx: RenderContext);
Begin
 { SPAN est un element inline - pas de saut de ligne }
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise SECTION (HTML5 bloc semantique) }
Procedure RenderTagSection(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 End;
 RenderChildren(Node, Ctx);
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise ARTICLE (HTML5 bloc semantique) }
Procedure RenderTagArticle(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 End;
 RenderChildren(Node, Ctx);
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
End;

{ Procedure pour rendre la balise NAV (HTML5 navigation) }
Procedure RenderTagNav(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock And (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
 If WantsBlock Then
  RenderNewLine(Ctx);
End;

{ Procedure pour rendre la balise ASIDE (HTML5 contenu lateral) }
Procedure RenderTagAside(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  Inc(Ctx.BlockLevel);
 End;
 RenderChildren(Node, Ctx);
 If WantsBlock Then Begin
  Dec(Ctx.BlockLevel);
  RenderNewLine(Ctx);
 End;
End;

{ Procedure pour rendre la balise HEADER (HTML5 en-tete) }
Procedure RenderTagHeader(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock And (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
End;

{ Procedure pour rendre la balise FOOTER (HTML5 pied de page) }
Procedure RenderTagFooter(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock Then Begin
  RenderBlockSpacing(Ctx, RENDER_DIV_MARGIN);
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
 End;
 RenderChildren(Node, Ctx);
End;

{ Procedure pour rendre la balise MAIN (HTML5 contenu principal) }
Procedure RenderTagMain(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 If WantsBlock And (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
  RenderNewLine(Ctx);
 RenderChildren(Node, Ctx);
End;

{ =====================================================
  RENDU HTML - Balises de texte (p, h1-h6, strong, em, pre, code)
  ===================================================== }

{ Procedure pour rendre la balise P (paragraphe) }
Procedure RenderTagP(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
 Box: TElementBoxInfo;
 MarginTopPx, MarginBottomPx: Integer;
 BoxStartX, BoxStartY: Integer;
Begin
 WantsBlock := CurrentElementWantsBlock;
 Box := CurrentElementBox;
 If Box.MarginTopPx >= 0 Then MarginTopPx := Box.MarginTopPx Else MarginTopPx := RENDER_PARAGRAPH_SPACING;
 If Box.MarginBottomPx >= 0 Then MarginBottomPx := Box.MarginBottomPx Else MarginBottomPx := RENDER_PARAGRAPH_SPACING;

 { Nouvelle ligne avant le paragraphe si necessaire, sauf si le CSS
   demande display:inline/inline-block. }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, MarginTopPx);
  BoxStartX := RenderOriginX + RENDER_MARGIN_LEFT;
  BoxStartY := Ctx.Y;
  ApplyTextAlignOffset(Ctx, Node);
 End;

 RenderChildren(Node, Ctx);

 If WantsBlock Then Begin
  If Box.HasBorder Then Begin
   SetColor(Box.BorderColorIdx);
   Rectangle(BoxStartX, BoxStartY, Ctx.MaxX, Ctx.Y);
   SetColor(Ctx.TextColor);
  End;
  RenderBlockSpacing(Ctx, MarginBottomPx);
 End;
End;

{ Procedure generique pour rendre les titres H1-H6 }
Procedure RenderHeading(Node: HTMLNodePtr; Var Ctx: RenderContext; HeadingHeight: Integer);
Var
 OldLineHeight: Integer;
 OldTextStyle: Byte;
 WantsBlock: Boolean;
 Box: TElementBoxInfo;
 MarginTopPx, MarginBottomPx: Integer;
Begin
 WantsBlock := CurrentElementWantsBlock;
 Box := CurrentElementBox;
 If Box.MarginTopPx >= 0 Then MarginTopPx := Box.MarginTopPx Else MarginTopPx := RENDER_PARAGRAPH_SPACING;
 If Box.MarginBottomPx >= 0 Then MarginBottomPx := Box.MarginBottomPx Else MarginBottomPx := RENDER_PARAGRAPH_SPACING;

 { Sauvegarder les valeurs courantes }
 OldLineHeight := Ctx.LineHeight;
 OldTextStyle := Ctx.TextStyle;

 { Nouvelle ligne avant le titre, sauf si le CSS demande
   display:inline/inline-block. }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, MarginTopPx);
 End;

 { Appliquer la taille du titre }
 Ctx.LineHeight := HeadingHeight;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;

 If WantsBlock Then ApplyTextAlignOffset(Ctx, Node);

 RenderChildren(Node, Ctx);

 { Restaurer les valeurs }
 Ctx.LineHeight := OldLineHeight;
 Ctx.TextStyle := OldTextStyle;

 { Espacement apres le titre }
 If WantsBlock Then Begin
  RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, MarginBottomPx);
 End;
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
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant le bloc pre }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 End;

 OldInPreformatted := Ctx.InPreformatted;
 OldTextStyle := Ctx.TextStyle;

 Ctx.InPreformatted := True;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_CODE;

 RenderChildren(Node, Ctx);

 Ctx.InPreformatted := OldInPreformatted;
 Ctx.TextStyle := OldTextStyle;

 { Espacement apres le bloc pre }
 If WantsBlock Then Begin
  RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 End;
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
 If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
  RenderNewLine(Ctx);
 RenderBlockSpacing(Ctx, 4);

 { Dessiner la ligne horizontale }
 SetColor(8); { Gris }
 Line(RenderOriginX + RENDER_MARGIN_LEFT,
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
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant la citation }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
  Inc(Ctx.BlockLevel, 2);
 End;

 { Indenter le contenu }
 RenderChildren(Node, Ctx);

 { Espacement apres la citation }
 If WantsBlock Then Begin
  Dec(Ctx.BlockLevel, 2);
  RenderBlockSpacing(Ctx, RENDER_PARAGRAPH_SPACING);
 End;
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
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant la liste si necessaire }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
 End;

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
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise OL (liste ordonnee) }
Procedure RenderTagOL(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldListType: Byte;
 OldListItemNumber: Integer;
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant la liste si necessaire }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
 End;

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
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise LI (element de liste) }
Procedure RenderTagLI(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 BulletText: String;
 IndentX: Integer;
 WantsBlock: Boolean;
 NoBullet: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 NoBullet := CurrentElementListStyleNone;
 { Nouvelle ligne pour l'element, sauf si le CSS demande
   display:inline/inline-block (ex: menu horizontal en <li>). }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.ListLevel * RENDER_LIST_INDENT) Then
   RenderNewLine(Ctx);

  { Calculer l'indentation }
  IndentX := RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.ListLevel * RENDER_LIST_INDENT);
  Ctx.X := IndentX;
 End
 Else If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.ListLevel * RENDER_LIST_INDENT) Then
  { En ligne : un espace de separation avant l'element suivant }
  Ctx.X := Ctx.X + 8;

 { Incrementer le numero d'element pour les listes ordonnees }
 If Ctx.ListType = LIST_TYPE_OL Then
  Inc(Ctx.ListItemNumber);

 { Afficher le marqueur de liste, sauf si list-style/list-style-type
   vaut none (menus horizontaux <ul><li> par exemple). }
 If Not NoBullet Then Begin
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
 End;

 { Rendre le contenu de l'element }
 RenderChildren(Node, Ctx);

 { Espacement apres l'element }
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise DL (liste de definitions) }
Procedure RenderTagDL(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldListType: Byte;
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant la liste si necessaire }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
 End;

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
 If WantsBlock Then
  RenderBlockSpacing(Ctx, RENDER_LIST_SPACING);
End;

{ Procedure pour rendre la balise DT (terme de definition) }
Procedure RenderTagDT(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldTextStyle: Byte;
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne pour le terme }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, RENDER_DT_SPACING);

  { Position sans indentation supplementaire }
  Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT + ((Ctx.ListLevel - 1) * RENDER_LIST_INDENT);
 End;

 { Rendre le terme en gras }
 OldTextStyle := Ctx.TextStyle;
 Ctx.TextStyle := Ctx.TextStyle Or TEXT_STYLE_BOLD;

 RenderChildren(Node, Ctx);

 Ctx.TextStyle := OldTextStyle;
End;

{ Procedure pour rendre la balise DD (definition) }
Procedure RenderTagDD(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne pour la definition }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT Then
   RenderNewLine(Ctx);

  { Indenter la definition }
  Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT + ((Ctx.ListLevel - 1) * RENDER_LIST_INDENT) + RENDER_DD_INDENT;
 End;

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
 MaxCols, RowCols: Integer;
 ChildNode, CellNode, RowNode: HTMLNodePtr;
Begin
 MaxCols := 0;

 { Parcourir les enfants pour trouver tr, thead, tbody }
 ChildNode := Node^.FirstChild;
 While ChildNode <> Nil Do Begin
  If ChildNode <> Nil Then Begin
   If (ChildNode^.TagType = TAG_TR) Then Begin
    { Compter les cellules dans cette ligne }
    RowCols := 0;
    CellNode := ChildNode^.FirstChild;
    While CellNode <> Nil Do Begin
     If CellNode <> Nil Then Begin
      If (CellNode^.TagType = TAG_TD) Or (CellNode^.TagType = TAG_TH) Then
       Inc(RowCols);
     End;
     CellNode := CellNode^.NextSibling;
    End;
    If RowCols > MaxCols Then MaxCols := RowCols;
   End
   Else If (ChildNode^.TagType = TAG_THEAD) Or (ChildNode^.TagType = TAG_TBODY) Then Begin
    { Parcourir les lignes dans thead/tbody }
    RowNode := ChildNode^.FirstChild;
    While RowNode <> Nil Do Begin
     If RowNode^.TagType = TAG_TR Then Begin
      RowCols := CountTableColumns(ChildNode);
      If RowCols > MaxCols Then MaxCols := RowCols;
     End;
     RowNode := RowNode^.NextSibling;
    End;
   End;
  End;
  ChildNode := ChildNode^.NextSibling;
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
 If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
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
 Ctx.X := RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10);
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
 Attr: HTMLAttributePtr;
 LowerAttr: String;
Begin
 GetNodeAttribute := '';
 If Node = Nil Then Exit;

 LowerAttr := HTMLLowerCase(AttrName);

 Attr := Node^.FirstAttribute;
 While Attr <> Nil Do Begin
  If HTMLLowerCase(Attr^.Name) = LowerAttr Then Begin
   GetNodeAttribute := Attr^.Value;
   Exit;
  End;
  Attr := Attr^.Next;
 End;
End;

{ Procedure pour rendre la balise FORM }
Procedure RenderTagForm(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 OldInForm: Boolean;
 WantsBlock: Boolean;
Begin
 WantsBlock := CurrentElementWantsBlock;
 { Nouvelle ligne avant le formulaire si necessaire }
 If WantsBlock Then Begin
  If Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10) Then
   RenderNewLine(Ctx);
  RenderBlockSpacing(Ctx, FORM_MARGIN);
 End;

 { Sauvegarder l'etat }
 OldInForm := Ctx.InForm;
 Ctx.InForm := True;

 { Rendre les enfants du formulaire }
 RenderChildren(Node, Ctx);

 { Restaurer l'etat }
 Ctx.InForm := OldInForm;

 { Espacement apres le formulaire }
 If WantsBlock Then
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
  If Node^.FirstChild <> Nil Then Begin
   If Node^.FirstChild^.NodeType = HTML_NODE_TEXT Then
    ButtonText := Node^.FirstChild^.Content;
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
 FirstOptionText: String;
 ChildNode: HTMLNodePtr;
Begin
 { Trouver le texte de la premiere option }
 FirstOptionText := '';
 ChildNode := Node^.FirstChild;
 While ChildNode <> Nil Do Begin
  If (ChildNode <> Nil) And (ChildNode^.TagType = TAG_OPTION) Then Begin
   If ChildNode^.FirstChild <> Nil Then Begin
    If ChildNode^.FirstChild^.NodeType = HTML_NODE_TEXT Then Begin
     FirstOptionText := ChildNode^.FirstChild^.Content;
     Break;
    End;
   End;
  End;
  ChildNode := ChildNode^.NextSibling;
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
 If Node^.FirstChild <> Nil Then Begin
  If Node^.FirstChild^.NodeType = HTML_NODE_TEXT Then Begin
   TextContent := Node^.FirstChild^.Content;
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
  StartX := RenderOriginX + RENDER_MARGIN_LEFT;
 End;

 { Calculer la largeur du texte du lien pour la zone cliquable }
 LinkText := '';
 ChildNode := Node^.FirstChild;
 While ChildNode <> Nil Do Begin
  If (ChildNode <> Nil) And (ChildNode^.NodeType = HTML_NODE_TEXT) Then Begin
   LinkText := LinkText + ChildNode^.Content;
  End;
  ChildNode := ChildNode^.NextSibling;
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
 Result: String;
 Child: HTMLNodePtr;
Begin
 Result := '';
 If Node = Nil Then Begin
  GetNodeTextContent := Result;
  Exit;
 End;

 If Node^.NodeType = HTML_NODE_TEXT Then
  Result := Node^.Content
 Else If Node^.NodeType = HTML_NODE_ELEMENT Then Begin
  Child := Node^.FirstChild;
  While Child <> Nil Do Begin
   Result := Result + GetNodeTextContent(Child);
   Child := Child^.NextSibling;
  End;
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

{ =====================================================
  DECODEUR ET AFFICHAGE D'IMAGES BMP
  ===================================================== }

Const
 { Signature BMP }
 BMP_SIGNATURE = $4D42; { 'BM' en little-endian }

 { Types de compression BMP }
 BMP_COMPRESS_NONE = 0;    { Pas de compression }
 BMP_COMPRESS_RLE8 = 1;    { RLE 8-bit }
 BMP_COMPRESS_RLE4 = 2;    { RLE 4-bit }
 BMP_COMPRESS_BITFIELDS = 3; { Champs de bits }

 { Taille maximale d'image supportee }
 BMP_MAX_WIDTH = 800;
 BMP_MAX_HEIGHT = 600;

Type
 { En-tete de fichier BMP (14 octets) }
 BMPFileHeader = Record
  Signature: Word;       { 'BM' = 0x4D42 }
  FileSize: LongInt;     { Taille totale du fichier }
  Reserved1: Word;       { Reserve (0) }
  Reserved2: Word;       { Reserve (0) }
  DataOffset: LongInt;   { Offset vers les donnees image }
 End;

 { En-tete d'information BMP (BITMAPINFOHEADER - 40 octets) }
 BMPInfoHeader = Record
  HeaderSize: LongInt;   { Taille de cet en-tete (40) }
  Width: LongInt;        { Largeur en pixels }
  Height: LongInt;       { Hauteur en pixels (negatif = top-down) }
  Planes: Word;          { Nombre de plans (1) }
  BitsPerPixel: Word;    { Bits par pixel (1, 4, 8, 16, 24, 32) }
  Compression: LongInt;  { Type de compression }
  ImageSize: LongInt;    { Taille des donnees image }
  XPixelsPerMeter: LongInt; { Resolution horizontale }
  YPixelsPerMeter: LongInt; { Resolution verticale }
  ColorsUsed: LongInt;   { Nombre de couleurs utilisees }
  ColorsImportant: LongInt; { Nombre de couleurs importantes }
 End;

 { Entree de palette BMP (4 octets) }
 BMPPaletteEntry = Record
  Blue: Byte;
  Green: Byte;
  Red: Byte;
  Reserved: Byte;
 End;

 { Palette de couleurs BMP }
 BMPPalette = Array[0..255] Of BMPPaletteEntry;

 { Structure d'image BMP en memoire }
 BMPImage = Record
  Width: Integer;
  Height: Integer;
  BitsPerPixel: Integer;
  TopDown: Boolean;      { True si les lignes sont stockees de haut en bas }
  Palette: BMPPalette;
  PaletteSize: Integer;
  Data: Pointer;         { Pointeur vers les donnees de pixels }
  DataSize: LongInt;
  Valid: Boolean;
 End;

 BMPImagePtr = ^BMPImage;

Var
 { Cache d'images chargees }
 BMPImageCache: Array[1..32] Of Record
  URL: String[255];
  Image: BMPImage;
  Used: Boolean;
 End;
 BMPImageCacheCount: Integer;

{ Initialiser le cache d'images }
Procedure BMPInitCache;
Var
 I: Integer;
Begin
 For I := 1 To 32 Do Begin
  BMPImageCache[I].URL := '';
  BMPImageCache[I].Used := False;
  BMPImageCache[I].Image.Valid := False;
  BMPImageCache[I].Image.Data := Nil;
 End;
 BMPImageCacheCount := 0;
End;

{ Convertir une couleur RGB en index de palette VGA/EGA }
Function BMPRGBToVGAColor(R, G, B: Byte): Byte;
Var
 BestColor, BestDist, Dist: LongInt;
 I: Integer;
 { Palette EGA/VGA standard }
Const
 VGAPalette: Array[0..15, 0..2] Of Byte = (
  (0, 0, 0),       { 0: Noir }
  (0, 0, 170),     { 1: Bleu }
  (0, 170, 0),     { 2: Vert }
  (0, 170, 170),   { 3: Cyan }
  (170, 0, 0),     { 4: Rouge }
  (170, 0, 170),   { 5: Magenta }
  (170, 85, 0),    { 6: Marron }
  (170, 170, 170), { 7: Gris clair }
  (85, 85, 85),    { 8: Gris fonce }
  (85, 85, 255),   { 9: Bleu clair }
  (85, 255, 85),   { 10: Vert clair }
  (85, 255, 255),  { 11: Cyan clair }
  (255, 85, 85),   { 12: Rouge clair }
  (255, 85, 255),  { 13: Magenta clair }
  (255, 255, 85),  { 14: Jaune }
  (255, 255, 255)  { 15: Blanc }
 );
Begin
 BestColor := 0;
 BestDist := 256 * 256 * 3; { Distance maximale possible }

 For I := 0 To 15 Do Begin
  { Distance euclidienne au carre }
  Dist := (Integer(R) - Integer(VGAPalette[I, 0])) *
          (Integer(R) - Integer(VGAPalette[I, 0])) +
          (Integer(G) - Integer(VGAPalette[I, 1])) *
          (Integer(G) - Integer(VGAPalette[I, 1])) +
          (Integer(B) - Integer(VGAPalette[I, 2])) *
          (Integer(B) - Integer(VGAPalette[I, 2]));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestColor := I;
  End;
 End;

 BMPRGBToVGAColor := BestColor;
End;

{ Liberer la memoire d'une image BMP }
Procedure BMPFreeImage(Var Img: BMPImage);
Begin
 If Img.Data <> Nil Then Begin
  FreeMem(Img.Data, Img.DataSize);
  Img.Data := Nil;
 End;
 Img.Valid := False;
 Img.DataSize := 0;
End;

{ Charger une image BMP depuis un fichier }
Function BMPLoadFromFile(Const FileName: String; Var Img: BMPImage): Boolean;
Var
 F: File;
 FileHdr: BMPFileHeader;
 InfoHdr: BMPInfoHeader;
 BytesRead: Word;
 I: Integer;
 RowSize: LongInt;
 Padding: Integer;
Begin
 BMPLoadFromFile := False;
 Img.Valid := False;
 Img.Data := Nil;

 { Ouvrir le fichier }
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tete de fichier }
 BlockRead(F, FileHdr, SizeOf(BMPFileHeader), BytesRead);
 If BytesRead <> SizeOf(BMPFileHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier la signature BMP }
 If FileHdr.Signature <> BMP_SIGNATURE Then Begin
  Close(F);
  Exit;
 End;

 { Lire l'en-tete d'information }
 BlockRead(F, InfoHdr, SizeOf(BMPInfoHeader), BytesRead);
 If BytesRead <> SizeOf(BMPInfoHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier les dimensions }
 If (Abs(InfoHdr.Width) > BMP_MAX_WIDTH) Or
    (Abs(InfoHdr.Height) > BMP_MAX_HEIGHT) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier la compression (seule BI_RGB est supportee) }
 If InfoHdr.Compression <> BMP_COMPRESS_NONE Then Begin
  Close(F);
  Exit;
 End;

 { Remplir la structure }
 Img.Width := InfoHdr.Width;
 If InfoHdr.Height < 0 Then Begin
  Img.Height := -InfoHdr.Height;
  Img.TopDown := True;
 End
 Else Begin
  Img.Height := InfoHdr.Height;
  Img.TopDown := False;
 End;
 Img.BitsPerPixel := InfoHdr.BitsPerPixel;

 { Lire la palette si necessaire }
 Img.PaletteSize := 0;
 If Img.BitsPerPixel <= 8 Then Begin
  If InfoHdr.ColorsUsed > 0 Then
   Img.PaletteSize := InfoHdr.ColorsUsed
  Else
   Img.PaletteSize := 1 Shl Img.BitsPerPixel;

  If Img.PaletteSize > 256 Then Img.PaletteSize := 256;

  For I := 0 To Img.PaletteSize - 1 Do Begin
   BlockRead(F, Img.Palette[I], SizeOf(BMPPaletteEntry), BytesRead);
   If BytesRead <> SizeOf(BMPPaletteEntry) Then Begin
    Close(F);
    Exit;
   End;
  End;
 End;

 { Calculer la taille des donnees }
 { Chaque ligne est alignee sur 4 octets }
 RowSize := ((LongInt(Img.Width) * LongInt(Img.BitsPerPixel) + 31) Div 32) * 4;
 Img.DataSize := RowSize * LongInt(Img.Height);

 { Allouer la memoire pour les donnees }
 If Img.DataSize > 65520 Then Begin
  { Trop grand pour une allocation simple }
  Close(F);
  Exit;
 End;

 GetMem(Img.Data, Img.DataSize);
 If Img.Data = Nil Then Begin
  Close(F);
  Exit;
 End;

 { Se positionner au debut des donnees }
 Seek(F, FileHdr.DataOffset);
 If IOResult <> 0 Then Begin
  BMPFreeImage(Img);
  Close(F);
  Exit;
 End;

 { Lire les donnees de l'image }
 BlockRead(F, Img.Data^, Img.DataSize, BytesRead);
 If LongInt(BytesRead) <> Img.DataSize Then Begin
  BMPFreeImage(Img);
  Close(F);
  Exit;
 End;

 Close(F);
 Img.Valid := True;
 BMPLoadFromFile := True;
End;

{ Obtenir la couleur d'un pixel dans l'image BMP }
Function BMPGetPixel(Const Img: BMPImage; X, Y: Integer): Byte;
Var
 RowSize: LongInt;
 ByteOffset: LongInt;
 BitOffset: Integer;
 PixelData: Byte;
 R, G, B: Byte;
 RowPtr: ^Byte;
 ActualY: Integer;
Begin
 BMPGetPixel := 0;
 If Not Img.Valid Then Exit;
 If (X < 0) Or (X >= Img.Width) Or (Y < 0) Or (Y >= Img.Height) Then Exit;

 { Les BMP stockent les lignes du bas vers le haut (sauf TopDown) }
 If Img.TopDown Then
  ActualY := Y
 Else
  ActualY := Img.Height - 1 - Y;

 { Calculer la taille d'une ligne (alignee sur 4 octets) }
 RowSize := ((LongInt(Img.Width) * LongInt(Img.BitsPerPixel) + 31) Div 32) * 4;

 Case Img.BitsPerPixel Of
  1: Begin
   ByteOffset := RowSize * LongInt(ActualY) + (X Div 8);
   BitOffset := 7 - (X Mod 8);
   RowPtr := Img.Data;
   Inc(RowPtr, ByteOffset);
   PixelData := (RowPtr^ Shr BitOffset) And 1;
   { Convertir via la palette }
   BMPGetPixel := BMPRGBToVGAColor(
    Img.Palette[PixelData].Red,
    Img.Palette[PixelData].Green,
    Img.Palette[PixelData].Blue);
  End;

  4: Begin
   ByteOffset := RowSize * LongInt(ActualY) + (X Div 2);
   RowPtr := Img.Data;
   Inc(RowPtr, ByteOffset);
   If (X Mod 2) = 0 Then
    PixelData := (RowPtr^ Shr 4) And $0F
   Else
    PixelData := RowPtr^ And $0F;
   { Convertir via la palette }
   BMPGetPixel := BMPRGBToVGAColor(
    Img.Palette[PixelData].Red,
    Img.Palette[PixelData].Green,
    Img.Palette[PixelData].Blue);
  End;

  8: Begin
   ByteOffset := RowSize * LongInt(ActualY) + LongInt(X);
   RowPtr := Img.Data;
   Inc(RowPtr, ByteOffset);
   PixelData := RowPtr^;
   { Convertir via la palette }
   BMPGetPixel := BMPRGBToVGAColor(
    Img.Palette[PixelData].Red,
    Img.Palette[PixelData].Green,
    Img.Palette[PixelData].Blue);
  End;

  24: Begin
   ByteOffset := RowSize * LongInt(ActualY) + LongInt(X) * 3;
   RowPtr := Img.Data;
   Inc(RowPtr, ByteOffset);
   B := RowPtr^;
   Inc(RowPtr);
   G := RowPtr^;
   Inc(RowPtr);
   R := RowPtr^;
   BMPGetPixel := BMPRGBToVGAColor(R, G, B);
  End;

  32: Begin
   ByteOffset := RowSize * LongInt(ActualY) + LongInt(X) * 4;
   RowPtr := Img.Data;
   Inc(RowPtr, ByteOffset);
   B := RowPtr^;
   Inc(RowPtr);
   G := RowPtr^;
   Inc(RowPtr);
   R := RowPtr^;
   { Ignorer l'alpha (4eme octet) }
   BMPGetPixel := BMPRGBToVGAColor(R, G, B);
  End;
 End;
End;

{ Dessiner une image BMP a l'ecran }
Procedure BMPDrawImage(Const Img: BMPImage; DestX, DestY: Integer;
                        MaxWidth, MaxHeight: Integer);
Var
 X, Y: Integer;
 DrawWidth, DrawHeight: Integer;
 PixelColor: Byte;
Begin
 If Not Img.Valid Then Exit;

 { Calculer les dimensions a dessiner }
 DrawWidth := Img.Width;
 DrawHeight := Img.Height;

 { Limiter aux dimensions maximales }
 If DrawWidth > MaxWidth Then DrawWidth := MaxWidth;
 If DrawHeight > MaxHeight Then DrawHeight := MaxHeight;

 { Dessiner pixel par pixel }
 For Y := 0 To DrawHeight - 1 Do Begin
  For X := 0 To DrawWidth - 1 Do Begin
   PixelColor := BMPGetPixel(Img, X, Y);
   PutPixel(DestX + X, DestY + Y, PixelColor);
  End;
 End;
End;

{ Dessiner une image BMP avec mise a l'echelle }
Procedure BMPDrawImageScaled(Const Img: BMPImage; DestX, DestY: Integer;
                              DestWidth, DestHeight: Integer);
Var
 X, Y: Integer;
 SrcX, SrcY: Integer;
 PixelColor: Byte;
Begin
 If Not Img.Valid Then Exit;
 If (DestWidth <= 0) Or (DestHeight <= 0) Then Exit;

 { Dessiner avec mise a l'echelle }
 For Y := 0 To DestHeight - 1 Do Begin
  SrcY := (Y * Img.Height) Div DestHeight;
  For X := 0 To DestWidth - 1 Do Begin
   SrcX := (X * Img.Width) Div DestWidth;
   PixelColor := BMPGetPixel(Img, SrcX, SrcY);
   PutPixel(DestX + X, DestY + Y, PixelColor);
  End;
 End;
End;

{ Chercher une image dans le cache }
Function BMPFindInCache(Const URL: String): Integer;
Var
 I: Integer;
Begin
 BMPFindInCache := 0;
 For I := 1 To 32 Do Begin
  If BMPImageCache[I].Used And (BMPImageCache[I].URL = URL) Then Begin
   BMPFindInCache := I;
   Exit;
  End;
 End;
End;

{ Ajouter une image au cache }
Function BMPAddToCache(Const URL: String; Const Img: BMPImage): Integer;
Var
 I: Integer;
 Slot: Integer;
Begin
 BMPAddToCache := 0;

 { Chercher un slot libre }
 Slot := 0;
 For I := 1 To 32 Do Begin
  If Not BMPImageCache[I].Used Then Begin
   Slot := I;
   Break;
  End;
 End;

 { Si pas de slot libre, utiliser le premier }
 If Slot = 0 Then Begin
  { Liberer la premiere image }
  If BMPImageCache[1].Image.Valid Then
   BMPFreeImage(BMPImageCache[1].Image);
  Slot := 1;
 End;

 BMPImageCache[Slot].URL := URL;
 BMPImageCache[Slot].Image := Img;
 BMPImageCache[Slot].Used := True;
 BMPAddToCache := Slot;
End;

{ Construire le chemin complet d'une image }
Function BMPBuildImagePath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 { Si c'est un chemin absolu, le retourner tel quel }
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  BMPBuildImagePath := Src;
  Exit;
 End;

 { Sinon construire le chemin relatif a l'URL courante }
 BasePath := CurrentURL;

 { Retirer le nom de fichier de l'URL courante }
 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 BMPBuildImagePath := BasePath + Src;
End;

{ Procedure pour rendre la balise IMG }
{$IFDEF FPC}
Procedure RenderTagImg(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 Alt: String;
Begin
 { Les types GIF/JPEG/PNG/SVG sont declares plus loin dans ce programme.
   En mode FPC, afficher le texte alternatif en attendant que les decodeurs
   soient regroupes dans une unite declaree avant le moteur de rendu. }
 If Node = Nil Then Exit;
 If Ctx.InHead Then Exit;
 Alt := GetNodeAttribute(Node, 'alt');
 If Alt = '' Then Alt := '[image]';
 RenderText(Ctx, Alt);
End;
{$ELSE}
Procedure RenderTagImg(Node: HTMLNodePtr; Var Ctx: RenderContext);
Var
 Src, Alt, WidthAttr, HeightAttr: String;
 ImgPath, ImgExt: String;
 BMPImg: BMPImage;
 GIFImg: GIFImage;
 JPEGImg: JPEGImage;
 PNGImg: PNGImage;
 SVGImg: SVGImage;
 CacheIdx: Integer;
 ImgWidth, ImgHeight: Integer;
 DrawWidth, DrawHeight: Integer;
 AltWidth: Integer;
 Code: Integer;
 IsBMP, IsGIF, IsJPEG, IsPNG, IsSVG: Boolean;
Begin
 If Node = Nil Then Exit;
 If Ctx.InHead Then Exit; { Pas d'affichage dans head }

 { Obtenir les attributs }
 Src := GetNodeAttribute(Node, 'src');
 Alt := GetNodeAttribute(Node, 'alt');
 WidthAttr := GetNodeAttribute(Node, 'width');
 HeightAttr := GetNodeAttribute(Node, 'height');

 { Si pas de source, afficher le texte alternatif }
 If Length(Src) = 0 Then Begin
  If Length(Alt) > 0 Then
   RenderText(Ctx, '[' + Alt + ']');
  Exit;
 End;

 { Construire le chemin complet de l'image }
 ImgPath := BMPBuildImagePath(Src);

 { Determiner le type d'image }
 IsBMP := False;
 IsGIF := False;
 IsJPEG := False;
 IsPNG := False;
 IsSVG := False;
 If Length(ImgPath) >= 4 Then Begin
  ImgExt := HTMLLowerCase(Copy(ImgPath, Length(ImgPath) - 3, 4));
  If ImgExt = '.bmp' Then IsBMP := True
  Else If ImgExt = '.gif' Then IsGIF := True
  Else If ImgExt = '.jpg' Then IsJPEG := True
  Else If ImgExt = 'jpeg' Then IsJPEG := True
  Else If ImgExt = '.png' Then IsPNG := True
  Else If ImgExt = '.svg' Then IsSVG := True;
 End;
 { Verifier aussi .jpeg (5 caracteres) }
 If (Not IsJPEG) And (Length(ImgPath) >= 5) Then Begin
  ImgExt := HTMLLowerCase(Copy(ImgPath, Length(ImgPath) - 4, 5));
  If ImgExt = '.jpeg' Then IsJPEG := True;
 End;

 { Si format non supporte, afficher le texte alternatif }
 If Not IsBMP And Not IsGIF And Not IsJPEG And Not IsPNG And Not IsSVG Then Begin
  If Length(Alt) > 0 Then
   RenderText(Ctx, '[' + Alt + ']')
  Else
   RenderText(Ctx, '[IMG]');
  Exit;
 End;

 { Traitement des images BMP }
 If IsBMP Then Begin
  CacheIdx := BMPFindInCache(ImgPath);
  If CacheIdx > 0 Then Begin
   BMPImg := BMPImageCache[CacheIdx].Image;
  End
  Else Begin
   If Not BMPLoadFromFile(ImgPath, BMPImg) Then Begin
    If Length(Alt) > 0 Then
     RenderText(Ctx, '[' + Alt + ']')
    Else
     RenderText(Ctx, '[IMG: ' + Src + ']');
    Exit;
   End;
   BMPAddToCache(ImgPath, BMPImg);
  End;

  ImgWidth := BMPImg.Width;
  ImgHeight := BMPImg.Height;

  If Length(WidthAttr) > 0 Then Begin
   Val(WidthAttr, DrawWidth, Code);
   If Code <> 0 Then DrawWidth := ImgWidth;
  End
  Else
   DrawWidth := ImgWidth;

  If Length(HeightAttr) > 0 Then Begin
   Val(HeightAttr, DrawHeight, Code);
   If Code <> 0 Then DrawHeight := ImgHeight;
  End
  Else
   DrawHeight := ImgHeight;

  If Ctx.X + DrawWidth > Ctx.MaxX Then RenderNewLine(Ctx);

  If DrawWidth > Ctx.MaxX - Ctx.X Then DrawWidth := Ctx.MaxX - Ctx.X;
  If DrawHeight > Ctx.MaxY - Ctx.Y Then DrawHeight := Ctx.MaxY - Ctx.Y;

  If (DrawWidth = ImgWidth) And (DrawHeight = ImgHeight) Then
   BMPDrawImage(BMPImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight)
  Else
   BMPDrawImageScaled(BMPImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight);

  Ctx.X := Ctx.X + DrawWidth;
  If DrawHeight > Ctx.LineHeight Then Ctx.LineHeight := DrawHeight;
 End

 { Traitement des images GIF }
 Else If IsGIF Then Begin
  CacheIdx := GIFFindInCache(ImgPath);
  If CacheIdx > 0 Then Begin
   GIFImg := GIFImageCache[CacheIdx].Image;
  End
  Else Begin
   If Not GIFLoadFromFile(ImgPath, GIFImg) Then Begin
    If Length(Alt) > 0 Then
     RenderText(Ctx, '[' + Alt + ']')
    Else
     RenderText(Ctx, '[IMG: ' + Src + ']');
    Exit;
   End;
   GIFAddToCache(ImgPath, GIFImg);
  End;

  ImgWidth := GIFImg.Width;
  ImgHeight := GIFImg.Height;

  If Length(WidthAttr) > 0 Then Begin
   Val(WidthAttr, DrawWidth, Code);
   If Code <> 0 Then DrawWidth := ImgWidth;
  End
  Else
   DrawWidth := ImgWidth;

  If Length(HeightAttr) > 0 Then Begin
   Val(HeightAttr, DrawHeight, Code);
   If Code <> 0 Then DrawHeight := ImgHeight;
  End
  Else
   DrawHeight := ImgHeight;

  If Ctx.X + DrawWidth > Ctx.MaxX Then RenderNewLine(Ctx);

  If DrawWidth > Ctx.MaxX - Ctx.X Then DrawWidth := Ctx.MaxX - Ctx.X;
  If DrawHeight > Ctx.MaxY - Ctx.Y Then DrawHeight := Ctx.MaxY - Ctx.Y;

  If (DrawWidth = ImgWidth) And (DrawHeight = ImgHeight) Then
   GIFDrawImage(GIFImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight)
  Else
   GIFDrawImageScaled(GIFImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight);

  Ctx.X := Ctx.X + DrawWidth;
  If DrawHeight > Ctx.LineHeight Then Ctx.LineHeight := DrawHeight;
 End

 { Traitement des images JPEG }
 Else If IsJPEG Then Begin
  CacheIdx := JPEGFindInCache(ImgPath);
  If CacheIdx > 0 Then Begin
   JPEGImg := JPEGImageCache[CacheIdx].Image;
  End
  Else Begin
   If Not JPEGLoadFromFile(ImgPath, JPEGImg) Then Begin
    If Length(Alt) > 0 Then
     RenderText(Ctx, '[' + Alt + ']')
    Else
     RenderText(Ctx, '[IMG: ' + Src + ']');
    Exit;
   End;
   JPEGAddToCache(ImgPath, JPEGImg);
  End;

  ImgWidth := JPEGImg.Width;
  ImgHeight := JPEGImg.Height;

  If Length(WidthAttr) > 0 Then Begin
   Val(WidthAttr, DrawWidth, Code);
   If Code <> 0 Then DrawWidth := ImgWidth;
  End
  Else
   DrawWidth := ImgWidth;

  If Length(HeightAttr) > 0 Then Begin
   Val(HeightAttr, DrawHeight, Code);
   If Code <> 0 Then DrawHeight := ImgHeight;
  End
  Else
   DrawHeight := ImgHeight;

  If Ctx.X + DrawWidth > Ctx.MaxX Then RenderNewLine(Ctx);

  If DrawWidth > Ctx.MaxX - Ctx.X Then DrawWidth := Ctx.MaxX - Ctx.X;
  If DrawHeight > Ctx.MaxY - Ctx.Y Then DrawHeight := Ctx.MaxY - Ctx.Y;

  If (DrawWidth = ImgWidth) And (DrawHeight = ImgHeight) Then
   JPEGDrawImage(JPEGImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight)
  Else
   JPEGDrawImageScaled(JPEGImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight);

  Ctx.X := Ctx.X + DrawWidth;
  If DrawHeight > Ctx.LineHeight Then Ctx.LineHeight := DrawHeight;
 End

 { Traitement des images PNG }
 Else If IsPNG Then Begin
  CacheIdx := PNGFindInCache(ImgPath);
  If CacheIdx > 0 Then Begin
   PNGImg := PNGImageCache[CacheIdx].Image;
  End
  Else Begin
   If Not PNGLoadFromFile(ImgPath, PNGImg) Then Begin
    If Length(Alt) > 0 Then
     RenderText(Ctx, '[' + Alt + ']')
    Else
     RenderText(Ctx, '[IMG: ' + Src + ']');
    Exit;
   End;
   PNGAddToCache(ImgPath, PNGImg);
  End;

  ImgWidth := PNGImg.Width;
  ImgHeight := PNGImg.Height;

  If Length(WidthAttr) > 0 Then Begin
   Val(WidthAttr, DrawWidth, Code);
   If Code <> 0 Then DrawWidth := ImgWidth;
  End
  Else
   DrawWidth := ImgWidth;

  If Length(HeightAttr) > 0 Then Begin
   Val(HeightAttr, DrawHeight, Code);
   If Code <> 0 Then DrawHeight := ImgHeight;
  End
  Else
   DrawHeight := ImgHeight;

  If Ctx.X + DrawWidth > Ctx.MaxX Then RenderNewLine(Ctx);

  If DrawWidth > Ctx.MaxX - Ctx.X Then DrawWidth := Ctx.MaxX - Ctx.X;
  If DrawHeight > Ctx.MaxY - Ctx.Y Then DrawHeight := Ctx.MaxY - Ctx.Y;

  If (DrawWidth = ImgWidth) And (DrawHeight = ImgHeight) Then
   PNGDrawImage(PNGImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight)
  Else
   PNGDrawImageScaled(PNGImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight);

  Ctx.X := Ctx.X + DrawWidth;
  If DrawHeight > Ctx.LineHeight Then Ctx.LineHeight := DrawHeight;
 End

 { Traitement des images SVG }
 Else If IsSVG Then Begin
  CacheIdx := SVGFindInCache(ImgPath);
  If CacheIdx > 0 Then Begin
   SVGImg := SVGImageCache[CacheIdx].Image;
  End
  Else Begin
   If Not SVGLoadFromFile(ImgPath, SVGImg) Then Begin
    If Length(Alt) > 0 Then
     RenderText(Ctx, '[' + Alt + ']')
    Else
     RenderText(Ctx, '[IMG: ' + Src + ']');
    Exit;
   End;
   SVGAddToCache(ImgPath, SVGImg);
  End;

  ImgWidth := SVGImg.Width;
  ImgHeight := SVGImg.Height;

  If Length(WidthAttr) > 0 Then Begin
   Val(WidthAttr, DrawWidth, Code);
   If Code <> 0 Then DrawWidth := ImgWidth;
  End
  Else
   DrawWidth := ImgWidth;

  If Length(HeightAttr) > 0 Then Begin
   Val(HeightAttr, DrawHeight, Code);
   If Code <> 0 Then DrawHeight := ImgHeight;
  End
  Else
   DrawHeight := ImgHeight;

  If Ctx.X + DrawWidth > Ctx.MaxX Then RenderNewLine(Ctx);

  If DrawWidth > Ctx.MaxX - Ctx.X Then DrawWidth := Ctx.MaxX - Ctx.X;
  If DrawHeight > Ctx.MaxY - Ctx.Y Then DrawHeight := Ctx.MaxY - Ctx.Y;

  SVGDrawImageScaled(SVGImg, Ctx.X, Ctx.Y, DrawWidth, DrawHeight);

  Ctx.X := Ctx.X + DrawWidth;
  If DrawHeight > Ctx.LineHeight Then Ctx.LineHeight := DrawHeight;
 End;
End;
{$ENDIF}

{ =====================================================
  FIN DECODEUR IMAGES BMP
  ===================================================== }

{ =====================================================
  DECODEUR ET AFFICHAGE D'IMAGES GIF (y compris anime)
  ===================================================== }

Const
 { Signature GIF }
 GIF_SIGNATURE_87A = 'GIF87a';
 GIF_SIGNATURE_89A = 'GIF89a';

 { Types d'extensions GIF }
 GIF_EXT_GRAPHIC_CONTROL = $F9;
 GIF_EXT_COMMENT = $FE;
 GIF_EXT_PLAINTEXT = $01;
 GIF_EXT_APPLICATION = $FF;

 { Separateurs GIF }
 GIF_IMAGE_SEPARATOR = $2C;
 GIF_EXTENSION_INTRODUCER = $21;
 GIF_TRAILER = $3B;

 { Taille maximale d'image GIF supportee }
 GIF_MAX_WIDTH = 800;
 GIF_MAX_HEIGHT = 600;
 GIF_MAX_FRAMES = 100;

 { LZW Constants }
 LZW_MAX_CODES = 4096;
 LZW_CLEAR_CODE_OFFSET = 0;
 LZW_EOI_CODE_OFFSET = 1;

Type
 { En-tete de fichier GIF (6 octets) }
 GIFHeader = Record
  Signature: Array[1..6] Of Char; { 'GIF87a' ou 'GIF89a' }
 End;

 { Descripteur d'ecran logique GIF (7 octets) }
 GIFLogicalScreenDesc = Record
  Width: Word;           { Largeur de l'ecran logique }
  Height: Word;          { Hauteur de l'ecran logique }
  PackedFields: Byte;    { Champs compresses }
  BgColorIndex: Byte;    { Index de couleur de fond }
  PixelAspectRatio: Byte; { Ratio d'aspect }
 End;

 { Entree de palette GIF (3 octets) }
 GIFPaletteEntry = Record
  Red: Byte;
  Green: Byte;
  Blue: Byte;
 End;

 { Palette de couleurs GIF }
 GIFPalette = Array[0..255] Of GIFPaletteEntry;
 GIFPalettePtr = ^GIFPalette;

 { Extension de controle graphique GIF }
 GIFGraphicControlExt = Record
  DisposalMethod: Byte;  { Methode de disposition (0-7) }
  UserInputFlag: Boolean; { Attend une entree utilisateur }
  TransparentFlag: Boolean; { Transparence activee }
  DelayTime: Word;       { Delai en 1/100 secondes }
  TransparentIndex: Byte; { Index de couleur transparente }
 End;

 { Descripteur d'image GIF }
 GIFImageDescriptor = Record
  Left: Word;            { Position X de l'image }
  Top: Word;             { Position Y de l'image }
  Width: Word;           { Largeur de l'image }
  Height: Word;          { Hauteur de l'image }
  PackedFields: Byte;    { Champs compresses }
 End;

 { Frame d'animation GIF }
 GIFFrame = Record
  Left: Integer;
  Top: Integer;
  Width: Integer;
  Height: Integer;
  Data: Pointer;         { Pointeur vers les pixels de la frame }
  DataSize: LongInt;
  DelayTime: Word;       { Delai avant la prochaine frame (1/100 sec) }
  DisposalMethod: Byte;  { Comment disposer de cette frame }
  TransparentFlag: Boolean;
  TransparentIndex: Byte;
  HasLocalPalette: Boolean;
  LocalPalette: GIFPalette;
  LocalPaletteSize: Integer;
  Valid: Boolean;
 End;

 GIFFramePtr = ^GIFFrame;

 { Structure d'image GIF complete en memoire }
 GIFImage = Record
  Width: Integer;        { Largeur de l'ecran logique }
  Height: Integer;       { Hauteur de l'ecran logique }
  GlobalPalette: GIFPalette;
  GlobalPaletteSize: Integer;
  HasGlobalPalette: Boolean;
  BgColorIndex: Byte;
  FrameCount: Integer;   { Nombre de frames }
  Frames: Array[1..GIF_MAX_FRAMES] Of GIFFrame;
  CurrentFrame: Integer; { Frame actuelle pour l'animation }
  LastFrameTime: LongInt; { Temps de la derniere frame }
  IsAnimated: Boolean;   { True si GIF anime }
  LoopCount: Integer;    { Nombre de boucles (0 = infini) }
  Valid: Boolean;
 End;

 GIFImagePtr = ^GIFImage;

 { Table LZW pour le decodage }
 LZWEntry = Record
  Prefix: Integer;       { Code prefixe (-1 si racine) }
  Suffix: Byte;          { Octet suffixe }
  Length: Integer;       { Longueur de la chaine }
 End;

 LZWTable = Array[0..LZW_MAX_CODES - 1] Of LZWEntry;
 LZWTablePtr = ^LZWTable;

Var
 { Cache d'images GIF chargees }
 GIFImageCache: Array[1..16] Of Record
  URL: String[255];
  Image: GIFImage;
  Used: Boolean;
 End;
 GIFImageCacheCount: Integer;

 { Buffer de lecture LZW }
 LZWBitBuffer: LongInt;
 LZWBitsInBuffer: Integer;
 LZWDataBuffer: Array[0..255] Of Byte;
 LZWDataPos: Integer;
 LZWDataLen: Integer;
 LZWFileHandle: File;

{ Initialiser le cache d'images GIF }
Procedure GIFInitCache;
Var
 I, J: Integer;
Begin
 For I := 1 To 16 Do Begin
  GIFImageCache[I].URL := '';
  GIFImageCache[I].Used := False;
  GIFImageCache[I].Image.Valid := False;
  GIFImageCache[I].Image.FrameCount := 0;
  For J := 1 To GIF_MAX_FRAMES Do Begin
   GIFImageCache[I].Image.Frames[J].Data := Nil;
   GIFImageCache[I].Image.Frames[J].Valid := False;
  End;
 End;
 GIFImageCacheCount := 0;
End;

{ Convertir une couleur RGB en index de palette VGA }
Function GIFRGBToVGAColor(R, G, B: Byte): Byte;
Var
 BestColor, BestDist, Dist: LongInt;
 I: Integer;
Const
 VGAPalette: Array[0..15, 0..2] Of Byte = (
  (0, 0, 0),       { 0: Noir }
  (0, 0, 170),     { 1: Bleu }
  (0, 170, 0),     { 2: Vert }
  (0, 170, 170),   { 3: Cyan }
  (170, 0, 0),     { 4: Rouge }
  (170, 0, 170),   { 5: Magenta }
  (170, 85, 0),    { 6: Marron }
  (170, 170, 170), { 7: Gris clair }
  (85, 85, 85),    { 8: Gris fonce }
  (85, 85, 255),   { 9: Bleu clair }
  (85, 255, 85),   { 10: Vert clair }
  (85, 255, 255),  { 11: Cyan clair }
  (255, 85, 85),   { 12: Rouge clair }
  (255, 85, 255),  { 13: Magenta clair }
  (255, 255, 85),  { 14: Jaune }
  (255, 255, 255)  { 15: Blanc }
 );
Begin
 BestColor := 0;
 BestDist := 256 * 256 * 3;

 For I := 0 To 15 Do Begin
  Dist := (Integer(R) - Integer(VGAPalette[I, 0])) *
          (Integer(R) - Integer(VGAPalette[I, 0])) +
          (Integer(G) - Integer(VGAPalette[I, 1])) *
          (Integer(G) - Integer(VGAPalette[I, 1])) +
          (Integer(B) - Integer(VGAPalette[I, 2])) *
          (Integer(B) - Integer(VGAPalette[I, 2]));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestColor := I;
  End;
 End;

 GIFRGBToVGAColor := BestColor;
End;

{ Liberer la memoire d'une frame GIF }
Procedure GIFFreeFrame(Var Frame: GIFFrame);
Begin
 If Frame.Data <> Nil Then Begin
  FreeMem(Frame.Data, Frame.DataSize);
  Frame.Data := Nil;
 End;
 Frame.Valid := False;
 Frame.DataSize := 0;
End;

{ Liberer la memoire d'une image GIF complete }
Procedure GIFFreeImage(Var Img: GIFImage);
Var
 I: Integer;
Begin
 For I := 1 To Img.FrameCount Do
  GIFFreeFrame(Img.Frames[I]);
 Img.FrameCount := 0;
 Img.Valid := False;
End;

{ Lire un bloc de sous-donnees GIF }
Function GIFReadSubBlock(Var F: File; Var Buffer; MaxSize: Integer): Integer;
Var
 BlockSize: Byte;
 BytesRead: Word;
Begin
 GIFReadSubBlock := 0;
 BlockRead(F, BlockSize, 1, BytesRead);
 If (BytesRead <> 1) Or (BlockSize = 0) Then Exit;

 If BlockSize > MaxSize Then BlockSize := MaxSize;
 BlockRead(F, Buffer, BlockSize, BytesRead);
 GIFReadSubBlock := BytesRead;
End;

{ Sauter les sous-blocs restants }
Procedure GIFSkipSubBlocks(Var F: File);
Var
 BlockSize: Byte;
 BytesRead: Word;
 TempBuffer: Array[0..255] Of Byte;
Begin
 Repeat
  BlockRead(F, BlockSize, 1, BytesRead);
  If (BytesRead <> 1) Or (BlockSize = 0) Then Exit;
  BlockRead(F, TempBuffer, BlockSize, BytesRead);
 Until (BlockSize = 0) Or (BytesRead = 0);
End;

{ Initialiser le buffer de lecture LZW }
Procedure LZWInitBuffer(Var F: File);
Begin
 LZWBitBuffer := 0;
 LZWBitsInBuffer := 0;
 LZWDataPos := 0;
 LZWDataLen := 0;
 LZWFileHandle := F;
End;

{ Lire le prochain sous-bloc de donnees }
Function LZWReadNextBlock: Boolean;
Var
 BlockSize: Byte;
 BytesRead: Word;
Begin
 LZWReadNextBlock := False;
 BlockRead(LZWFileHandle, BlockSize, 1, BytesRead);
 If (BytesRead <> 1) Or (BlockSize = 0) Then Exit;

 BlockRead(LZWFileHandle, LZWDataBuffer, BlockSize, BytesRead);
 If BytesRead <> BlockSize Then Exit;

 LZWDataPos := 0;
 LZWDataLen := BlockSize;
 LZWReadNextBlock := True;
End;

{ Lire N bits du flux LZW }
Function LZWReadBits(NumBits: Integer): Integer;
Var
 Result: Integer;
 NextByte: Byte;
Begin
 LZWReadBits := -1;

 { S'assurer qu'on a assez de bits }
 While LZWBitsInBuffer < NumBits Do Begin
  { Besoin de plus de donnees }
  If LZWDataPos >= LZWDataLen Then Begin
   If Not LZWReadNextBlock Then Exit;
  End;

  NextByte := LZWDataBuffer[LZWDataPos];
  Inc(LZWDataPos);

  LZWBitBuffer := LZWBitBuffer Or (LongInt(NextByte) Shl LZWBitsInBuffer);
  Inc(LZWBitsInBuffer, 8);
 End;

 { Extraire les bits requis }
 Result := LZWBitBuffer And ((1 Shl NumBits) - 1);
 LZWBitBuffer := LZWBitBuffer Shr NumBits;
 Dec(LZWBitsInBuffer, NumBits);

 LZWReadBits := Result;
End;

{ Decoder les donnees d'image LZW }
Function GIFDecodeLZW(Var F: File; MinCodeSize: Byte;
                       OutputBuffer: Pointer; MaxOutput: LongInt): LongInt;
Var
 Table: LZWTablePtr;
 ClearCode, EOICode: Integer;
 CodeSize, NextCode: Integer;
 OldCode, Code, TempCode: Integer;
 Stack: Array[0..LZW_MAX_CODES - 1] Of Byte;
 StackPtr: Integer;
 FirstChar: Byte;
 OutputPos: LongInt;
 OutPtr: ^Byte;
 I: Integer;
Begin
 GIFDecodeLZW := 0;

 { Allouer la table LZW }
 GetMem(Table, SizeOf(LZWTable));
 If Table = Nil Then Exit;

 { Initialiser les codes speciaux }
 ClearCode := 1 Shl MinCodeSize;
 EOICode := ClearCode + 1;

 { Initialiser le buffer de lecture }
 LZWInitBuffer(F);

 { Initialiser les variables }
 CodeSize := MinCodeSize + 1;
 NextCode := EOICode + 1;
 OldCode := -1;
 FirstChar := 0;
 OutputPos := 0;
 OutPtr := OutputBuffer;

 { Initialiser la table avec les codes de base }
 For I := 0 To ClearCode - 1 Do Begin
  Table^[I].Prefix := -1;
  Table^[I].Suffix := I;
  Table^[I].Length := 1;
 End;

 { Decoder le flux }
 While OutputPos < MaxOutput Do Begin
  Code := LZWReadBits(CodeSize);
  If Code < 0 Then Break; { Erreur de lecture }

  If Code = EOICode Then Break; { Fin de l'image }

  If Code = ClearCode Then Begin
   { Reinitialiser la table }
   CodeSize := MinCodeSize + 1;
   NextCode := EOICode + 1;
   OldCode := -1;
   Continue;
  End;

  If OldCode = -1 Then Begin
   { Premier code apres clear }
   If Code < ClearCode Then Begin
    OutPtr^ := Code;
    Inc(OutPtr);
    Inc(OutputPos);
    FirstChar := Code;
    OldCode := Code;
   End;
   Continue;
  End;

  { Decoder la chaine }
  TempCode := Code;
  StackPtr := 0;

  If Code >= NextCode Then Begin
   { Cas special: code pas encore dans la table }
   Stack[StackPtr] := FirstChar;
   Inc(StackPtr);
   TempCode := OldCode;
  End;

  { Suivre la chaine de prefixes }
  While TempCode >= ClearCode Do Begin
   If TempCode >= NextCode Then Break; { Code invalide }
   Stack[StackPtr] := Table^[TempCode].Suffix;
   Inc(StackPtr);
   TempCode := Table^[TempCode].Prefix;
   If StackPtr >= LZW_MAX_CODES Then Break; { Debordement }
  End;

  { Ajouter le dernier caractere }
  If TempCode >= 0 Then Begin
   Stack[StackPtr] := TempCode;
   Inc(StackPtr);
   FirstChar := TempCode;
  End;

  { Ecrire la pile dans l'ordre inverse }
  While (StackPtr > 0) And (OutputPos < MaxOutput) Do Begin
   Dec(StackPtr);
   OutPtr^ := Stack[StackPtr];
   Inc(OutPtr);
   Inc(OutputPos);
  End;

  { Ajouter une nouvelle entree a la table }
  If NextCode < LZW_MAX_CODES Then Begin
   Table^[NextCode].Prefix := OldCode;
   Table^[NextCode].Suffix := FirstChar;
   Table^[NextCode].Length := Table^[OldCode].Length + 1;
   Inc(NextCode);

   { Augmenter la taille du code si necessaire }
   If (NextCode >= (1 Shl CodeSize)) And (CodeSize < 12) Then
    Inc(CodeSize);
  End;

  OldCode := Code;
 End;

 { Liberer la table }
 FreeMem(Table, SizeOf(LZWTable));

 GIFDecodeLZW := OutputPos;
End;

{ Charger une image GIF depuis un fichier }
Function GIFLoadFromFile(Const FileName: String; Var Img: GIFImage): Boolean;
Var
 F: File;
 Header: GIFHeader;
 ScreenDesc: GIFLogicalScreenDesc;
 ImageDesc: GIFImageDescriptor;
 BytesRead: Word;
 I: Integer;
 GlobalPaletteSize: Integer;
 Introducer, Label_: Byte;
 GCE: GIFGraphicControlExt;
 HasGCE: Boolean;
 BlockSize: Byte;
 GCEData: Array[0..5] Of Byte;
 MinCodeSize: Byte;
 FrameWidth, FrameHeight: Integer;
 FrameDataSize: LongInt;
 LocalPaletteSize: Integer;
 DecodedSize: LongInt;
 AppId: Array[1..11] Of Char;
 LoopData: Array[0..2] Of Byte;
Begin
 GIFLoadFromFile := False;
 Img.Valid := False;
 Img.FrameCount := 0;
 Img.CurrentFrame := 1;
 Img.IsAnimated := False;
 Img.LoopCount := 0;
 Img.HasGlobalPalette := False;

 { Initialiser le GCE }
 HasGCE := False;
 GCE.DisposalMethod := 0;
 GCE.UserInputFlag := False;
 GCE.TransparentFlag := False;
 GCE.DelayTime := 0;
 GCE.TransparentIndex := 0;

 { Ouvrir le fichier }
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire l'en-tete GIF }
 BlockRead(F, Header, SizeOf(GIFHeader), BytesRead);
 If BytesRead <> SizeOf(GIFHeader) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier la signature GIF }
 If (Header.Signature <> GIF_SIGNATURE_87A) And
    (Header.Signature <> GIF_SIGNATURE_89A) Then Begin
  Close(F);
  Exit;
 End;

 { Lire le descripteur d'ecran logique }
 BlockRead(F, ScreenDesc, SizeOf(GIFLogicalScreenDesc), BytesRead);
 If BytesRead <> SizeOf(GIFLogicalScreenDesc) Then Begin
  Close(F);
  Exit;
 End;

 { Verifier les dimensions }
 If (ScreenDesc.Width > GIF_MAX_WIDTH) Or
    (ScreenDesc.Height > GIF_MAX_HEIGHT) Then Begin
  Close(F);
  Exit;
 End;

 Img.Width := ScreenDesc.Width;
 Img.Height := ScreenDesc.Height;
 Img.BgColorIndex := ScreenDesc.BgColorIndex;

 { Lire la palette globale si presente }
 If (ScreenDesc.PackedFields And $80) <> 0 Then Begin
  GlobalPaletteSize := 1 Shl ((ScreenDesc.PackedFields And $07) + 1);
  Img.GlobalPaletteSize := GlobalPaletteSize;
  Img.HasGlobalPalette := True;

  For I := 0 To GlobalPaletteSize - 1 Do Begin
   BlockRead(F, Img.GlobalPalette[I], SizeOf(GIFPaletteEntry), BytesRead);
   If BytesRead <> SizeOf(GIFPaletteEntry) Then Begin
    Close(F);
    Exit;
   End;
  End;
 End;

 { Parcourir les blocs GIF }
 While True Do Begin
  BlockRead(F, Introducer, 1, BytesRead);
  If BytesRead <> 1 Then Break;

  Case Introducer Of
   GIF_TRAILER: Break; { Fin du fichier GIF }

   GIF_EXTENSION_INTRODUCER: Begin
    { Lire le type d'extension }
    BlockRead(F, Label_, 1, BytesRead);
    If BytesRead <> 1 Then Break;

    Case Label_ Of
     GIF_EXT_GRAPHIC_CONTROL: Begin
      { Extension de controle graphique }
      BlockRead(F, BlockSize, 1, BytesRead);
      If (BytesRead = 1) And (BlockSize >= 4) Then Begin
       BlockRead(F, GCEData, BlockSize, BytesRead);
       If BytesRead = BlockSize Then Begin
        GCE.DisposalMethod := (GCEData[0] Shr 2) And $07;
        GCE.UserInputFlag := (GCEData[0] And $02) <> 0;
        GCE.TransparentFlag := (GCEData[0] And $01) <> 0;
        GCE.DelayTime := GCEData[1] Or (Word(GCEData[2]) Shl 8);
        GCE.TransparentIndex := GCEData[3];
        HasGCE := True;
       End;
      End;
      { Lire le terminateur }
      BlockRead(F, BlockSize, 1, BytesRead);
     End;

     GIF_EXT_APPLICATION: Begin
      { Extension d'application (NETSCAPE pour les boucles) }
      BlockRead(F, BlockSize, 1, BytesRead);
      If (BytesRead = 1) And (BlockSize = 11) Then Begin
       BlockRead(F, AppId, 11, BytesRead);
       If (BytesRead = 11) And (Copy(AppId, 1, 8) = 'NETSCAPE') Then Begin
        { Lire le sous-bloc de boucle }
        BlockRead(F, BlockSize, 1, BytesRead);
        If (BytesRead = 1) And (BlockSize = 3) Then Begin
         BlockRead(F, LoopData, 3, BytesRead);
         If BytesRead = 3 Then
          Img.LoopCount := LoopData[1] Or (Word(LoopData[2]) Shl 8);
        End;
       End;
      End;
      GIFSkipSubBlocks(F);
     End;

     Else Begin
      { Sauter les autres extensions }
      GIFSkipSubBlocks(F);
     End;
    End;
   End;

   GIF_IMAGE_SEPARATOR: Begin
    { Nouvelle frame d'image }
    If Img.FrameCount >= GIF_MAX_FRAMES Then Break;

    { Lire le descripteur d'image }
    BlockRead(F, ImageDesc, SizeOf(GIFImageDescriptor), BytesRead);
    If BytesRead <> SizeOf(GIFImageDescriptor) Then Break;

    Inc(Img.FrameCount);

    With Img.Frames[Img.FrameCount] Do Begin
     Left := ImageDesc.Left;
     Top := ImageDesc.Top;
     Width := ImageDesc.Width;
     Height := ImageDesc.Height;
     Valid := False;
     Data := Nil;
     HasLocalPalette := False;
     LocalPaletteSize := 0;

     { Appliquer les parametres GCE si disponibles }
     If HasGCE Then Begin
      DelayTime := GCE.DelayTime;
      DisposalMethod := GCE.DisposalMethod;
      TransparentFlag := GCE.TransparentFlag;
      TransparentIndex := GCE.TransparentIndex;
      HasGCE := False; { Consommer le GCE }
     End
     Else Begin
      DelayTime := 0;
      DisposalMethod := 0;
      TransparentFlag := False;
      TransparentIndex := 0;
     End;

     { Lire la palette locale si presente }
     If (ImageDesc.PackedFields And $80) <> 0 Then Begin
      LocalPaletteSize := 1 Shl ((ImageDesc.PackedFields And $07) + 1);
      HasLocalPalette := True;
      Img.Frames[Img.FrameCount].LocalPaletteSize := LocalPaletteSize;

      For I := 0 To LocalPaletteSize - 1 Do Begin
       BlockRead(F, LocalPalette[I], SizeOf(GIFPaletteEntry), BytesRead);
       If BytesRead <> SizeOf(GIFPaletteEntry) Then Begin
        Close(F);
        Exit;
       End;
      End;
     End;

     { Lire le code LZW minimum }
     BlockRead(F, MinCodeSize, 1, BytesRead);
     If BytesRead <> 1 Then Begin
      Close(F);
      Exit;
     End;

     { Allouer la memoire pour les pixels }
     FrameWidth := ImageDesc.Width;
     FrameHeight := ImageDesc.Height;
     FrameDataSize := LongInt(FrameWidth) * LongInt(FrameHeight);

     If FrameDataSize > 65520 Then Begin
      { Trop grand, sauter cette frame }
      GIFSkipSubBlocks(F);
      Dec(Img.FrameCount);
      Continue;
     End;

     GetMem(Data, FrameDataSize);
     If Data = Nil Then Begin
      GIFSkipSubBlocks(F);
      Dec(Img.FrameCount);
      Continue;
     End;
     DataSize := FrameDataSize;

     { Decoder les donnees LZW }
     DecodedSize := GIFDecodeLZW(F, MinCodeSize, Data, FrameDataSize);

     If DecodedSize > 0 Then
      Valid := True
     Else Begin
      FreeMem(Data, FrameDataSize);
      Data := Nil;
      Dec(Img.FrameCount);
     End;
    End;
   End;
  End;
 End;

 Close(F);

 { Verifier si on a charge au moins une frame }
 If Img.FrameCount > 0 Then Begin
  Img.Valid := True;
  Img.IsAnimated := (Img.FrameCount > 1);
  Img.CurrentFrame := 1;
  Img.LastFrameTime := 0;
  GIFLoadFromFile := True;
 End;
End;

{ Obtenir la couleur d'un pixel dans une frame GIF }
Function GIFGetPixel(Const Img: GIFImage; FrameIdx: Integer;
                      X, Y: Integer; Var IsTransparent: Boolean): Byte;
Var
 Offset: LongInt;
 PixelIndex: Byte;
 Palette: ^GIFPalette;
 DataPtr: ^Byte;
Begin
 GIFGetPixel := 0;
 IsTransparent := False;

 If Not Img.Valid Then Exit;
 If (FrameIdx < 1) Or (FrameIdx > Img.FrameCount) Then Exit;
 If Not Img.Frames[FrameIdx].Valid Then Exit;

 With Img.Frames[FrameIdx] Do Begin
  If (X < 0) Or (X >= Width) Or (Y < 0) Or (Y >= Height) Then Exit;

  Offset := LongInt(Y) * LongInt(Width) + LongInt(X);
  DataPtr := Data;
  Inc(DataPtr, Offset);
  PixelIndex := DataPtr^;

  { Verifier la transparence }
  If TransparentFlag And (PixelIndex = TransparentIndex) Then Begin
   IsTransparent := True;
   Exit;
  End;

  { Choisir la palette appropriee }
  If HasLocalPalette Then
   Palette := @LocalPalette
  Else If Img.HasGlobalPalette Then
   Palette := @Img.GlobalPalette
  Else Begin
   GIFGetPixel := PixelIndex And $0F; { Utiliser l'index directement }
   Exit;
  End;

  { Convertir en couleur VGA }
  GIFGetPixel := GIFRGBToVGAColor(
   Palette^[PixelIndex].Red,
   Palette^[PixelIndex].Green,
   Palette^[PixelIndex].Blue);
 End;
End;

{ Dessiner une frame GIF a l'ecran }
Procedure GIFDrawFrame(Const Img: GIFImage; FrameIdx: Integer;
                        DestX, DestY: Integer; MaxWidth, MaxHeight: Integer);
Var
 X, Y: Integer;
 DrawWidth, DrawHeight: Integer;
 PixelColor: Byte;
 IsTransparent: Boolean;
 FrameX, FrameY: Integer;
Begin
 If Not Img.Valid Then Exit;
 If (FrameIdx < 1) Or (FrameIdx > Img.FrameCount) Then Exit;
 If Not Img.Frames[FrameIdx].Valid Then Exit;

 With Img.Frames[FrameIdx] Do Begin
  { Calculer les dimensions a dessiner }
  DrawWidth := Width;
  DrawHeight := Height;

  If DrawWidth > MaxWidth Then DrawWidth := MaxWidth;
  If DrawHeight > MaxHeight Then DrawHeight := MaxHeight;

  { Dessiner pixel par pixel }
  For Y := 0 To DrawHeight - 1 Do Begin
   For X := 0 To DrawWidth - 1 Do Begin
    PixelColor := GIFGetPixel(Img, FrameIdx, X, Y, IsTransparent);
    If Not IsTransparent Then Begin
     FrameX := DestX + Left + X;
     FrameY := DestY + Top + Y;
     PutPixel(FrameX, FrameY, PixelColor);
    End;
   End;
  End;
 End;
End;

{ Dessiner une image GIF (premiere frame ou frame courante) }
Procedure GIFDrawImage(Const Img: GIFImage; DestX, DestY: Integer;
                        MaxWidth, MaxHeight: Integer);
Begin
 If Img.Valid And (Img.FrameCount > 0) Then
  GIFDrawFrame(Img, Img.CurrentFrame, DestX, DestY, MaxWidth, MaxHeight);
End;

{ Dessiner une image GIF avec mise a l'echelle }
Procedure GIFDrawImageScaled(Const Img: GIFImage; DestX, DestY: Integer;
                              DestWidth, DestHeight: Integer);
Var
 X, Y: Integer;
 SrcX, SrcY: Integer;
 PixelColor: Byte;
 IsTransparent: Boolean;
 FrameIdx: Integer;
Begin
 If Not Img.Valid Then Exit;
 If (DestWidth <= 0) Or (DestHeight <= 0) Then Exit;
 If Img.FrameCount < 1 Then Exit;

 FrameIdx := Img.CurrentFrame;
 If Not Img.Frames[FrameIdx].Valid Then Exit;

 { Dessiner avec mise a l'echelle }
 For Y := 0 To DestHeight - 1 Do Begin
  SrcY := (Y * Img.Frames[FrameIdx].Height) Div DestHeight;
  For X := 0 To DestWidth - 1 Do Begin
   SrcX := (X * Img.Frames[FrameIdx].Width) Div DestWidth;
   PixelColor := GIFGetPixel(Img, FrameIdx, SrcX, SrcY, IsTransparent);
   If Not IsTransparent Then
    PutPixel(DestX + X, DestY + Y, PixelColor);
  End;
 End;
End;

{ Avancer a la prochaine frame d'animation }
Function GIFNextFrame(Var Img: GIFImage): Boolean;
Begin
 GIFNextFrame := False;
 If Not Img.Valid Then Exit;
 If Not Img.IsAnimated Then Exit;

 Inc(Img.CurrentFrame);
 If Img.CurrentFrame > Img.FrameCount Then
  Img.CurrentFrame := 1;

 GIFNextFrame := True;
End;

{ Verifier si l'animation doit avancer (basee sur le temps) }
Function GIFShouldAdvance(Const Img: GIFImage; CurrentTime: LongInt): Boolean;
Var
 DelayMs: LongInt;
Begin
 GIFShouldAdvance := False;
 If Not Img.Valid Then Exit;
 If Not Img.IsAnimated Then Exit;

 { Calculer le delai en millisecondes }
 DelayMs := LongInt(Img.Frames[Img.CurrentFrame].DelayTime) * 10;
 If DelayMs < 20 Then DelayMs := 100; { Delai minimum }

 { Verifier si assez de temps s'est ecoule }
 If CurrentTime - Img.LastFrameTime >= DelayMs Then
  GIFShouldAdvance := True;
End;

{ Mettre a jour le temps de la derniere frame }
Procedure GIFUpdateFrameTime(Var Img: GIFImage; CurrentTime: LongInt);
Begin
 Img.LastFrameTime := CurrentTime;
End;

{ Chercher une image GIF dans le cache }
Function GIFFindInCache(Const URL: String): Integer;
Var
 I: Integer;
Begin
 GIFFindInCache := 0;
 For I := 1 To 16 Do Begin
  If GIFImageCache[I].Used And (GIFImageCache[I].URL = URL) Then Begin
   GIFFindInCache := I;
   Exit;
  End;
 End;
End;

{ Ajouter une image GIF au cache }
Function GIFAddToCache(Const URL: String; Const Img: GIFImage): Integer;
Var
 I: Integer;
 Slot: Integer;
Begin
 GIFAddToCache := 0;

 { Chercher un slot libre }
 Slot := 0;
 For I := 1 To 16 Do Begin
  If Not GIFImageCache[I].Used Then Begin
   Slot := I;
   Break;
  End;
 End;

 { Si pas de slot libre, utiliser le premier }
 If Slot = 0 Then Begin
  If GIFImageCache[1].Image.Valid Then
   GIFFreeImage(GIFImageCache[1].Image);
  Slot := 1;
 End;

 GIFImageCache[Slot].URL := URL;
 GIFImageCache[Slot].Image := Img;
 GIFImageCache[Slot].Used := True;
 GIFAddToCache := Slot;
End;

{ Construire le chemin complet d'une image GIF }
Function GIFBuildImagePath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 { Si c'est un chemin absolu, le retourner tel quel }
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  GIFBuildImagePath := Src;
  Exit;
 End;

 { Sinon construire le chemin relatif a l'URL courante }
 BasePath := CurrentURL;

 { Retirer le nom de fichier de l'URL courante }
 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 GIFBuildImagePath := BasePath + Src;
End;

{ =====================================================
  FIN DECODEUR IMAGES GIF
  ===================================================== }

{ =====================================================
  DECODEUR ET AFFICHAGE D'IMAGES JPEG
  ===================================================== }

Const
 { Marqueurs JPEG }
 JPEG_SOI  = $FFD8;  { Start Of Image }
 JPEG_EOI  = $FFD9;  { End Of Image }
 JPEG_APP0 = $FFE0;  { Application Marker JFIF }
 JPEG_APP1 = $FFE1;  { Application Marker EXIF }
 JPEG_DQT  = $FFDB;  { Define Quantization Table }
 JPEG_DHT  = $FFC4;  { Define Huffman Table }
 JPEG_SOF0 = $FFC0;  { Start Of Frame (Baseline DCT) }
 JPEG_SOF2 = $FFC2;  { Start Of Frame (Progressive DCT) }
 JPEG_SOS  = $FFDA;  { Start Of Scan }
 JPEG_DRI  = $FFDD;  { Define Restart Interval }
 JPEG_RST0 = $FFD0;  { Restart Marker 0 }
 JPEG_RST7 = $FFD7;  { Restart Marker 7 }
 JPEG_COM  = $FFFE;  { Comment }

 { Taille maximale d'image JPEG supportee }
 JPEG_MAX_WIDTH = 800;
 JPEG_MAX_HEIGHT = 600;

 { Constantes DCT }
 JPEG_BLOCK_SIZE = 8;  { Taille d'un bloc DCT }
 JPEG_BLOCK_SIZE2 = 64; { 8x8 pixels par bloc }

Type
 { Table de quantification JPEG }
 JPEGQuantTable = Array[0..63] Of Word;
 JPEGQuantTablePtr = ^JPEGQuantTable;

 { Table Huffman JPEG }
 JPEGHuffmanTable = Record
  Bits: Array[0..15] Of Byte;    { Nombre de codes par longueur }
  Values: Array[0..255] Of Byte; { Valeurs des symboles }
  MinCode: Array[0..15] Of Integer; { Code minimum par longueur }
  MaxCode: Array[0..15] Of Integer; { Code maximum par longueur }
  ValPtr: Array[0..15] Of Integer;  { Index dans Values }
  NumCodes: Integer;
  Valid: Boolean;
 End;
 JPEGHuffmanTablePtr = ^JPEGHuffmanTable;

 { Composante d'image JPEG }
 JPEGComponent = Record
  Id: Byte;              { Identifiant de composante }
  HSampling: Byte;       { Facteur d'echantillonnage horizontal }
  VSampling: Byte;       { Facteur d'echantillonnage vertical }
  QuantTableId: Byte;    { Table de quantification utilisee }
  DCTableId: Byte;       { Table Huffman DC }
  ACTableId: Byte;       { Table Huffman AC }
  DCPred: Integer;       { Predicteur DC precedent }
 End;

 { Bloc de donnees 8x8 }
 JPEGBlock = Array[0..63] Of Integer;
 JPEGBlockPtr = ^JPEGBlock;

 { Structure d'image JPEG en memoire }
 JPEGImage = Record
  Width: Integer;
  Height: Integer;
  NumComponents: Integer;
  Components: Array[1..4] Of JPEGComponent;
  QuantTables: Array[0..3] Of JPEGQuantTable;
  QuantTableValid: Array[0..3] Of Boolean;
  DCHuffTables: Array[0..3] Of JPEGHuffmanTable;
  ACHuffTables: Array[0..3] Of JPEGHuffmanTable;
  MaxHSampling: Byte;
  MaxVSampling: Byte;
  RestartInterval: Word;
  Data: Pointer;         { Pointeur vers les donnees RGB }
  DataSize: LongInt;
  Valid: Boolean;
 End;

 JPEGImagePtr = ^JPEGImage;

Var
 { Cache d'images JPEG chargees }
 JPEGImageCache: Array[1..16] Of Record
  URL: String[255];
  Image: JPEGImage;
  Used: Boolean;
 End;
 JPEGImageCacheCount: Integer;

 { Buffer de lecture de bits pour Huffman }
 JPEGBitBuffer: LongInt;
 JPEGBitsInBuffer: Integer;
 JPEGFileHandle: File;
 JPEGFilePos: LongInt;
 JPEGDataBuffer: Array[0..4095] Of Byte;
 JPEGDataPos: Integer;
 JPEGDataLen: Integer;

{ Ordre zigzag pour parcourir les coefficients DCT }
Const
 JPEGZigZag: Array[0..63] Of Byte = (
   0,  1,  8, 16,  9,  2,  3, 10,
  17, 24, 32, 25, 18, 11,  4,  5,
  12, 19, 26, 33, 40, 48, 41, 34,
  27, 20, 13,  6,  7, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36,
  29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46,
  53, 60, 61, 54, 47, 55, 62, 63
 );

{ Initialiser le cache d'images JPEG }
Procedure JPEGInitCache;
Var
 I: Integer;
Begin
 For I := 1 To 16 Do Begin
  JPEGImageCache[I].URL := '';
  JPEGImageCache[I].Used := False;
  JPEGImageCache[I].Image.Valid := False;
  JPEGImageCache[I].Image.Data := Nil;
 End;
 JPEGImageCacheCount := 0;
End;

{ Convertir une couleur RGB en index de palette VGA }
Function JPEGRGBToVGAColor(R, G, B: Byte): Byte;
Var
 BestColor, BestDist, Dist: LongInt;
 I: Integer;
Const
 VGAPalette: Array[0..15, 0..2] Of Byte = (
  (0, 0, 0),       { 0: Noir }
  (0, 0, 170),     { 1: Bleu }
  (0, 170, 0),     { 2: Vert }
  (0, 170, 170),   { 3: Cyan }
  (170, 0, 0),     { 4: Rouge }
  (170, 0, 170),   { 5: Magenta }
  (170, 85, 0),    { 6: Marron }
  (170, 170, 170), { 7: Gris clair }
  (85, 85, 85),    { 8: Gris fonce }
  (85, 85, 255),   { 9: Bleu clair }
  (85, 255, 85),   { 10: Vert clair }
  (85, 255, 255),  { 11: Cyan clair }
  (255, 85, 85),   { 12: Rouge clair }
  (255, 85, 255),  { 13: Magenta clair }
  (255, 255, 85),  { 14: Jaune }
  (255, 255, 255)  { 15: Blanc }
 );
Begin
 BestColor := 0;
 BestDist := 256 * 256 * 3;

 For I := 0 To 15 Do Begin
  Dist := (Integer(R) - Integer(VGAPalette[I, 0])) *
          (Integer(R) - Integer(VGAPalette[I, 0])) +
          (Integer(G) - Integer(VGAPalette[I, 1])) *
          (Integer(G) - Integer(VGAPalette[I, 1])) +
          (Integer(B) - Integer(VGAPalette[I, 2])) *
          (Integer(B) - Integer(VGAPalette[I, 2]));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestColor := I;
  End;
 End;

 JPEGRGBToVGAColor := BestColor;
End;

{ Liberer la memoire d'une image JPEG }
Procedure JPEGFreeImage(Var Img: JPEGImage);
Begin
 If Img.Data <> Nil Then Begin
  FreeMem(Img.Data, Img.DataSize);
  Img.Data := Nil;
 End;
 Img.Valid := False;
 Img.DataSize := 0;
End;

{ Initialiser le buffer de lecture de bits }
Procedure JPEGInitBitBuffer(Var F: File);
Begin
 JPEGBitBuffer := 0;
 JPEGBitsInBuffer := 0;
 JPEGFileHandle := F;
 JPEGDataPos := 0;
 JPEGDataLen := 0;
End;

{ Lire un octet du fichier JPEG (gere les marqueurs $FF00) }
Function JPEGReadByte: Integer;
Var
 BytesRead: Word;
 B: Byte;
 SkipMarker: Boolean;
Begin
 JPEGReadByte := -1;

 { Boucle plutot que recursion : un flux corrompu/atypique peut
   enchainer plusieurs marqueurs RST consecutifs, ce qu'un appel
   recursif a soi-meme finirait par faire deborder la pile. }
 Repeat
  SkipMarker := False;

  { Remplir le buffer si necessaire }
  If JPEGDataPos >= JPEGDataLen Then Begin
   BlockRead(JPEGFileHandle, JPEGDataBuffer, SizeOf(JPEGDataBuffer), BytesRead);
   If BytesRead = 0 Then Exit;
   JPEGDataPos := 0;
   JPEGDataLen := BytesRead;
  End;

  B := JPEGDataBuffer[JPEGDataPos];
  Inc(JPEGDataPos);

  { Gerer le byte stuffing: $FF00 devient $FF }
  If B = $FF Then Begin
   If JPEGDataPos >= JPEGDataLen Then Begin
    BlockRead(JPEGFileHandle, JPEGDataBuffer, SizeOf(JPEGDataBuffer), BytesRead);
    If BytesRead = 0 Then Exit;
    JPEGDataPos := 0;
    JPEGDataLen := BytesRead;
   End;

   If JPEGDataBuffer[JPEGDataPos] = $00 Then Begin
    Inc(JPEGDataPos); { Sauter le $00 de stuffing }
   End
   Else If (JPEGDataBuffer[JPEGDataPos] >= $D0) And
           (JPEGDataBuffer[JPEGDataPos] <= $D7) Then Begin
    { Marqueur RST - le sauter, puis lire l'octet suivant }
    Inc(JPEGDataPos);
    JPEGBitBuffer := 0;
    JPEGBitsInBuffer := 0;
    SkipMarker := True;
   End;
  End;
 Until Not SkipMarker;

 JPEGReadByte := B;
End;

{ Lire N bits du flux }
Function JPEGReadBits(NumBits: Integer): Integer;
Var
 B: Integer;
Begin
 JPEGReadBits := -1;

 While JPEGBitsInBuffer < NumBits Do Begin
  B := JPEGReadByte;
  If B < 0 Then Exit;
  JPEGBitBuffer := (JPEGBitBuffer Shl 8) Or B;
  Inc(JPEGBitsInBuffer, 8);
 End;

 Dec(JPEGBitsInBuffer, NumBits);
 JPEGReadBits := (JPEGBitBuffer Shr JPEGBitsInBuffer) And ((1 Shl NumBits) - 1);
End;

{ Decoder un symbole Huffman }
Function JPEGDecodeHuffman(Var Table: JPEGHuffmanTable): Integer;
Var
 Code, BitLen: Integer;
 Index: Integer;
Begin
 JPEGDecodeHuffman := -1;
 If Not Table.Valid Then Exit;

 Code := 0;
 For BitLen := 1 To 16 Do Begin
  Code := (Code Shl 1) Or JPEGReadBits(1);
  If Code < 0 Then Exit;

  If (Code >= Table.MinCode[BitLen - 1]) And
     (Code <= Table.MaxCode[BitLen - 1]) Then Begin
   Index := Table.ValPtr[BitLen - 1] + Code - Table.MinCode[BitLen - 1];
   If Index < Table.NumCodes Then
    JPEGDecodeHuffman := Table.Values[Index];
   Exit;
  End;
 End;
End;

{ Etendre la valeur decodee selon la categorie }
Function JPEGExtendValue(Value, Category: Integer): Integer;
Var
 Threshold: Integer;
Begin
 If Category = 0 Then Begin
  JPEGExtendValue := 0;
  Exit;
 End;

 Threshold := 1 Shl (Category - 1);
 If Value < Threshold Then
  JPEGExtendValue := Value - (2 * Threshold - 1)
 Else
  JPEGExtendValue := Value;
End;

{ Construire les codes Huffman a partir des bits }
Procedure JPEGBuildHuffmanCodes(Var Table: JPEGHuffmanTable);
Var
 Code, I, J: Integer;
 Count: Integer;
Begin
 Code := 0;
 Count := 0;

 For I := 0 To 15 Do Begin
  Table.MinCode[I] := Code;
  Table.ValPtr[I] := Count;

  For J := 0 To Table.Bits[I] - 1 Do Begin
   Inc(Code);
   Inc(Count);
  End;

  Table.MaxCode[I] := Code - 1;
  Code := Code Shl 1;
 End;

 Table.NumCodes := Count;
 Table.Valid := True;
End;

{ Coefficients IDCT precalcules (cosinus) }
Const
 JPEGIDCTScale: Array[0..7, 0..7] Of Integer = (
  (362, 362, 362, 362, 362, 362, 362, 362),
  (502, 425, 284, 100, -100, -284, -425, -502),
  (473, 195, -195, -473, -473, -195, 195, 473),
  (425, -100, -502, -284, 284, 502, 100, -425),
  (362, -362, -362, 362, 362, -362, -362, 362),
  (284, -502, 100, 425, -425, -100, 502, -284),
  (195, -473, 473, -195, -195, 473, -473, 195),
  (100, -284, 425, -502, 502, -425, 284, -100)
 );

{ Effectuer l'IDCT sur un bloc 8x8 }
Procedure JPEGInverseIDCT(Var Block: JPEGBlock);
Var
 Temp: Array[0..63] Of LongInt;
 I, J, K: Integer;
 Sum: LongInt;
Begin
 { IDCT sur les colonnes }
 For I := 0 To 7 Do Begin
  For J := 0 To 7 Do Begin
   Sum := 0;
   For K := 0 To 7 Do Begin
    Sum := Sum + LongInt(Block[K * 8 + I]) * LongInt(JPEGIDCTScale[K, J]);
   End;
   Temp[J * 8 + I] := Sum Div 256;
  End;
 End;

 { IDCT sur les lignes }
 For I := 0 To 7 Do Begin
  For J := 0 To 7 Do Begin
   Sum := 0;
   For K := 0 To 7 Do Begin
    Sum := Sum + Temp[I * 8 + K] * LongInt(JPEGIDCTScale[K, J]);
   End;
   Block[I * 8 + J] := Sum Div 256 + 128;

   { Clamping a 0-255 }
   If Block[I * 8 + J] < 0 Then Block[I * 8 + J] := 0;
   If Block[I * 8 + J] > 255 Then Block[I * 8 + J] := 255;
  End;
 End;
End;

{ Decoder un bloc 8x8 }
Function JPEGDecodeBlock(Var Block: JPEGBlock;
                          Var DCTable, ACTable: JPEGHuffmanTable;
                          Var QuantTable: JPEGQuantTable;
                          Var DCPred: Integer): Boolean;
Var
 I, Symbol, Category, Bits, Value: Integer;
 Run, Size: Integer;
 ZZIndex: Integer;
Begin
 JPEGDecodeBlock := False;

 { Initialiser le bloc a zero }
 For I := 0 To 63 Do Block[I] := 0;

 { Decoder le coefficient DC }
 Category := JPEGDecodeHuffman(DCTable);
 If Category < 0 Then Exit;

 If Category > 0 Then Begin
  Bits := JPEGReadBits(Category);
  If Bits < 0 Then Exit;
  Value := JPEGExtendValue(Bits, Category);
 End
 Else
  Value := 0;

 DCPred := DCPred + Value;
 Block[0] := DCPred * Integer(QuantTable[0]);

 { Decoder les coefficients AC }
 ZZIndex := 1;
 While ZZIndex < 64 Do Begin
  Symbol := JPEGDecodeHuffman(ACTable);
  If Symbol < 0 Then Exit;

  If Symbol = 0 Then Begin
   { EOB - End Of Block }
   Break;
  End;

  Run := (Symbol Shr 4) And $0F;   { Nombre de zeros }
  Size := Symbol And $0F;          { Taille de la valeur }

  If Symbol = $F0 Then Begin
   { ZRL - 16 zeros }
   Inc(ZZIndex, 16);
   Continue;
  End;

  Inc(ZZIndex, Run);
  If ZZIndex >= 64 Then Break;

  If Size > 0 Then Begin
   Bits := JPEGReadBits(Size);
   If Bits < 0 Then Exit;
   Value := JPEGExtendValue(Bits, Size);
   Block[JPEGZigZag[ZZIndex]] := Value * Integer(QuantTable[JPEGZigZag[ZZIndex]]);
  End;

  Inc(ZZIndex);
 End;

 { Appliquer l'IDCT }
 JPEGInverseIDCT(Block);

 JPEGDecodeBlock := True;
End;

{ Convertir YCbCr vers RGB }
Procedure JPEGYCbCrToRGB(Y, Cb, Cr: Integer; Var R, G, B: Byte);
Var
 Rv, Gv, Bv: Integer;
Begin
 { Formule standard ITU-R BT.601 }
 Rv := Y + ((Cr - 128) * 359) Div 256;
 Gv := Y - ((Cb - 128) * 88 + (Cr - 128) * 183) Div 256;
 Bv := Y + ((Cb - 128) * 454) Div 256;

 { Clamping a 0-255 }
 If Rv < 0 Then Rv := 0 Else If Rv > 255 Then Rv := 255;
 If Gv < 0 Then Gv := 0 Else If Gv > 255 Then Gv := 255;
 If Bv < 0 Then Bv := 0 Else If Bv > 255 Then Bv := 255;

 R := Rv;
 G := Gv;
 B := Bv;
End;

{ Lire un mot (16 bits big-endian) }
Function JPEGReadWord(Var F: File): Word;
Var
 B1, B2: Byte;
 BytesRead: Word;
Begin
 BlockRead(F, B1, 1, BytesRead);
 BlockRead(F, B2, 1, BytesRead);
 JPEGReadWord := (Word(B1) Shl 8) Or B2;
End;

{ Sauter N octets }
Procedure JPEGSkipBytes(Var F: File; Count: Word);
Var
 I: Integer;
 B: Byte;
 BytesRead: Word;
Begin
 For I := 1 To Count Do
  BlockRead(F, B, 1, BytesRead);
End;

{ Lire la table de quantification }
Function JPEGReadQuantTable(Var F: File; Var Img: JPEGImage; Length: Word): Boolean;
Var
 Precision, TableId: Byte;
 I: Integer;
 B: Byte;
 W: Word;
 BytesRead: Word;
 Remaining: Integer;
Begin
 JPEGReadQuantTable := False;
 Remaining := Length - 2;

 While Remaining > 0 Do Begin
  BlockRead(F, B, 1, BytesRead);
  Dec(Remaining);

  Precision := (B Shr 4) And $0F;
  TableId := B And $0F;

  If TableId > 3 Then Exit;

  If Precision = 0 Then Begin
   { Table 8 bits }
   For I := 0 To 63 Do Begin
    BlockRead(F, B, 1, BytesRead);
    Dec(Remaining);
    Img.QuantTables[TableId][JPEGZigZag[I]] := B;
   End;
  End
  Else Begin
   { Table 16 bits }
   For I := 0 To 63 Do Begin
    W := JPEGReadWord(F);
    Dec(Remaining, 2);
    Img.QuantTables[TableId][JPEGZigZag[I]] := W;
   End;
  End;

  Img.QuantTableValid[TableId] := True;
 End;

 JPEGReadQuantTable := True;
End;

{ Lire la table Huffman }
Function JPEGReadHuffmanTable(Var F: File; Var Img: JPEGImage; Length: Word): Boolean;
Var
 TableClass, TableId: Byte;
 B: Byte;
 BytesRead: Word;
 Remaining: Integer;
 I, Count: Integer;
 Table: ^JPEGHuffmanTable;
Begin
 JPEGReadHuffmanTable := False;
 Remaining := Length - 2;

 While Remaining > 0 Do Begin
  BlockRead(F, B, 1, BytesRead);
  Dec(Remaining);

  TableClass := (B Shr 4) And $0F; { 0 = DC, 1 = AC }
  TableId := B And $0F;

  If TableId > 3 Then Exit;

  If TableClass = 0 Then
   Table := @Img.DCHuffTables[TableId]
  Else
   Table := @Img.ACHuffTables[TableId];

  { Lire le nombre de codes par longueur }
  Count := 0;
  For I := 0 To 15 Do Begin
   BlockRead(F, Table^.Bits[I], 1, BytesRead);
   Dec(Remaining);
   Inc(Count, Table^.Bits[I]);
  End;

  { Lire les valeurs }
  For I := 0 To Count - 1 Do Begin
   BlockRead(F, Table^.Values[I], 1, BytesRead);
   Dec(Remaining);
  End;

  { Construire les codes }
  JPEGBuildHuffmanCodes(Table^);
 End;

 JPEGReadHuffmanTable := True;
End;

{ Lire le SOF (Start Of Frame) }
Function JPEGReadSOF(Var F: File; Var Img: JPEGImage; Length: Word): Boolean;
Var
 Precision: Byte;
 BytesRead: Word;
 I: Integer;
 B: Byte;
Begin
 JPEGReadSOF := False;

 BlockRead(F, Precision, 1, BytesRead);
 Img.Height := JPEGReadWord(F);
 Img.Width := JPEGReadWord(F);
 BlockRead(F, B, 1, BytesRead);
 Img.NumComponents := B;

 If (Img.Width > JPEG_MAX_WIDTH) Or (Img.Height > JPEG_MAX_HEIGHT) Then Exit;
 If (Img.NumComponents < 1) Or (Img.NumComponents > 4) Then Exit;

 Img.MaxHSampling := 1;
 Img.MaxVSampling := 1;

 For I := 1 To Img.NumComponents Do Begin
  BlockRead(F, Img.Components[I].Id, 1, BytesRead);
  BlockRead(F, B, 1, BytesRead);
  Img.Components[I].HSampling := (B Shr 4) And $0F;
  Img.Components[I].VSampling := B And $0F;
  BlockRead(F, Img.Components[I].QuantTableId, 1, BytesRead);
  Img.Components[I].DCPred := 0;

  If Img.Components[I].HSampling > Img.MaxHSampling Then
   Img.MaxHSampling := Img.Components[I].HSampling;
  If Img.Components[I].VSampling > Img.MaxVSampling Then
   Img.MaxVSampling := Img.Components[I].VSampling;
 End;

 JPEGReadSOF := True;
End;

{ Lire le SOS (Start Of Scan) }
Function JPEGReadSOS(Var F: File; Var Img: JPEGImage): Boolean;
Var
 NumComponents: Byte;
 BytesRead: Word;
 I: Integer;
 CompId, TableIds: Byte;
 Ss, Se, AhAl: Byte;
Begin
 JPEGReadSOS := False;

 BlockRead(F, NumComponents, 1, BytesRead);
 If NumComponents <> Img.NumComponents Then Exit;

 For I := 1 To NumComponents Do Begin
  BlockRead(F, CompId, 1, BytesRead);
  BlockRead(F, TableIds, 1, BytesRead);
  Img.Components[I].DCTableId := (TableIds Shr 4) And $0F;
  Img.Components[I].ACTableId := TableIds And $0F;
 End;

 { Lire les parametres de scan (ignores pour baseline) }
 BlockRead(F, Ss, 1, BytesRead);
 BlockRead(F, Se, 1, BytesRead);
 BlockRead(F, AhAl, 1, BytesRead);

 JPEGReadSOS := True;
End;

{ Charger une image JPEG depuis un fichier }
Function JPEGLoadFromFile(Const FileName: String; Var Img: JPEGImage): Boolean;
Var
 F: File;
 Marker, Length: Word;
 BytesRead: Word;
 I, J, X, Y: Integer;
 MCUWidth, MCUHeight: Integer;
 BlocksPerMCU: Integer;
 YBlocks, CbBlocks, CrBlocks: Array[0..3] Of JPEGBlock;
 R, G, B: Byte;
 PixelOffset: LongInt;
 DataPtr: ^Byte;
 Yv, Cbv, Crv: Integer;
 BlockX, BlockY: Integer;
 PixelX, PixelY: Integer;
Begin
 JPEGLoadFromFile := False;
 Img.Valid := False;
 Img.Data := Nil;

 For I := 0 To 3 Do Begin
  Img.QuantTableValid[I] := False;
  Img.DCHuffTables[I].Valid := False;
  Img.ACHuffTables[I].Valid := False;
 End;

 { Ouvrir le fichier }
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Verifier la signature SOI }
 Marker := JPEGReadWord(F);
 If Marker <> JPEG_SOI Then Begin
  Close(F);
  Exit;
 End;

 { Parcourir les segments }
 While True Do Begin
  Marker := JPEGReadWord(F);
  If (Marker And $FF00) <> $FF00 Then Break;

  Case Marker Of
   JPEG_EOI: Break;

   JPEG_DQT: Begin
    Length := JPEGReadWord(F);
    If Not JPEGReadQuantTable(F, Img, Length) Then Begin
     Close(F);
     Exit;
    End;
   End;

   JPEG_DHT: Begin
    Length := JPEGReadWord(F);
    If Not JPEGReadHuffmanTable(F, Img, Length) Then Begin
     Close(F);
     Exit;
    End;
   End;

   JPEG_SOF0: Begin { Baseline DCT }
    Length := JPEGReadWord(F);
    If Not JPEGReadSOF(F, Img, Length) Then Begin
     Close(F);
     Exit;
    End;
   End;

   JPEG_SOS: Begin
    Length := JPEGReadWord(F);
    If Not JPEGReadSOS(F, Img) Then Begin
     Close(F);
     Exit;
    End;

    { Allouer la memoire pour les pixels RGB }
    Img.DataSize := LongInt(Img.Width) * LongInt(Img.Height) * 3;
    If Img.DataSize > 65520 Then Begin
     { Trop grand pour le mode reel }
     Close(F);
     Exit;
    End;

    GetMem(Img.Data, Img.DataSize);
    If Img.Data = Nil Then Begin
     Close(F);
     Exit;
    End;

    { Initialiser le buffer de bits }
    JPEGInitBitBuffer(F);

    { Reinitialiser les predicteurs DC }
    For I := 1 To Img.NumComponents Do
     Img.Components[I].DCPred := 0;

    { Taille d'un MCU en pixels }
    MCUWidth := Img.MaxHSampling * 8;
    MCUHeight := Img.MaxVSampling * 8;

    { Decoder les MCUs }
    Y := 0;
    While Y < Img.Height Do Begin
     X := 0;
     While X < Img.Width Do Begin
      { Decoder les blocs Y (luminance) }
      For I := 0 To Img.Components[1].VSampling * Img.Components[1].HSampling - 1 Do Begin
       If Not JPEGDecodeBlock(YBlocks[I],
         Img.DCHuffTables[Img.Components[1].DCTableId],
         Img.ACHuffTables[Img.Components[1].ACTableId],
         Img.QuantTables[Img.Components[1].QuantTableId],
         Img.Components[1].DCPred) Then Begin
        FreeMem(Img.Data, Img.DataSize);
        Img.Data := Nil;
        Close(F);
        Exit;
       End;
      End;

      { Decoder les blocs Cb et Cr si image couleur }
      If Img.NumComponents >= 3 Then Begin
       If Not JPEGDecodeBlock(CbBlocks[0],
         Img.DCHuffTables[Img.Components[2].DCTableId],
         Img.ACHuffTables[Img.Components[2].ACTableId],
         Img.QuantTables[Img.Components[2].QuantTableId],
         Img.Components[2].DCPred) Then Begin
        FreeMem(Img.Data, Img.DataSize);
        Img.Data := Nil;
        Close(F);
        Exit;
       End;

       If Not JPEGDecodeBlock(CrBlocks[0],
         Img.DCHuffTables[Img.Components[3].DCTableId],
         Img.ACHuffTables[Img.Components[3].ACTableId],
         Img.QuantTables[Img.Components[3].QuantTableId],
         Img.Components[3].DCPred) Then Begin
        FreeMem(Img.Data, Img.DataSize);
        Img.Data := Nil;
        Close(F);
        Exit;
       End;
      End;

      { Convertir et stocker les pixels }
      For BlockY := 0 To MCUHeight - 1 Do Begin
       For BlockX := 0 To MCUWidth - 1 Do Begin
        PixelX := X + BlockX;
        PixelY := Y + BlockY;

        If (PixelX < Img.Width) And (PixelY < Img.Height) Then Begin
         { Obtenir la valeur Y du bloc approprie }
         I := (BlockY Div 8) * Img.Components[1].HSampling + (BlockX Div 8);
         If I > Img.Components[1].VSampling * Img.Components[1].HSampling - 1 Then
          I := 0;
         Yv := YBlocks[I][(BlockY Mod 8) * 8 + (BlockX Mod 8)];

         If Img.NumComponents >= 3 Then Begin
          { Calculer la position dans les blocs Cb/Cr (sous-echantillonnes) }
          J := (BlockY * Img.Components[2].VSampling Div Img.MaxVSampling) * 8 +
               (BlockX * Img.Components[2].HSampling Div Img.MaxHSampling);
          If J > 63 Then J := 63;
          Cbv := CbBlocks[0][J];
          Crv := CrBlocks[0][J];

          JPEGYCbCrToRGB(Yv, Cbv, Crv, R, G, B);
         End
         Else Begin
          { Image en niveaux de gris }
          R := Yv;
          G := Yv;
          B := Yv;
         End;

         { Stocker le pixel }
         PixelOffset := (LongInt(PixelY) * LongInt(Img.Width) + LongInt(PixelX)) * 3;
         DataPtr := Img.Data;
         Inc(DataPtr, PixelOffset);
         DataPtr^ := R;
         Inc(DataPtr);
         DataPtr^ := G;
         Inc(DataPtr);
         DataPtr^ := B;
        End;
       End;
      End;

      Inc(X, MCUWidth);
     End;
     Inc(Y, MCUHeight);
    End;

    Break; { Fin du decodage }
   End;

   JPEG_DRI: Begin
    Length := JPEGReadWord(F);
    Img.RestartInterval := JPEGReadWord(F);
   End;

   Else Begin
    { Sauter les segments inconnus }
    Length := JPEGReadWord(F);
    If Length > 2 Then
     JPEGSkipBytes(F, Length - 2);
   End;
  End;
 End;

 Close(F);

 If Img.Data <> Nil Then Begin
  Img.Valid := True;
  JPEGLoadFromFile := True;
 End;
End;

{ Obtenir la couleur d'un pixel dans une image JPEG }
Function JPEGGetPixel(Const Img: JPEGImage; X, Y: Integer): Byte;
Var
 Offset: LongInt;
 DataPtr: ^Byte;
 R, G, B: Byte;
Begin
 JPEGGetPixel := 0;
 If Not Img.Valid Then Exit;
 If (X < 0) Or (X >= Img.Width) Or (Y < 0) Or (Y >= Img.Height) Then Exit;

 Offset := (LongInt(Y) * LongInt(Img.Width) + LongInt(X)) * 3;
 DataPtr := Img.Data;
 Inc(DataPtr, Offset);
 R := DataPtr^;
 Inc(DataPtr);
 G := DataPtr^;
 Inc(DataPtr);
 B := DataPtr^;

 JPEGGetPixel := JPEGRGBToVGAColor(R, G, B);
End;

{ Dessiner une image JPEG a l'ecran }
Procedure JPEGDrawImage(Const Img: JPEGImage; DestX, DestY: Integer;
                         MaxWidth, MaxHeight: Integer);
Var
 X, Y: Integer;
 DrawWidth, DrawHeight: Integer;
 PixelColor: Byte;
Begin
 If Not Img.Valid Then Exit;

 DrawWidth := Img.Width;
 DrawHeight := Img.Height;

 If DrawWidth > MaxWidth Then DrawWidth := MaxWidth;
 If DrawHeight > MaxHeight Then DrawHeight := MaxHeight;

 For Y := 0 To DrawHeight - 1 Do Begin
  For X := 0 To DrawWidth - 1 Do Begin
   PixelColor := JPEGGetPixel(Img, X, Y);
   PutPixel(DestX + X, DestY + Y, PixelColor);
  End;
 End;
End;

{ Dessiner une image JPEG avec mise a l'echelle }
Procedure JPEGDrawImageScaled(Const Img: JPEGImage; DestX, DestY: Integer;
                               DestWidth, DestHeight: Integer);
Var
 X, Y: Integer;
 SrcX, SrcY: Integer;
 PixelColor: Byte;
Begin
 If Not Img.Valid Then Exit;
 If (DestWidth <= 0) Or (DestHeight <= 0) Then Exit;

 For Y := 0 To DestHeight - 1 Do Begin
  SrcY := (Y * Img.Height) Div DestHeight;
  For X := 0 To DestWidth - 1 Do Begin
   SrcX := (X * Img.Width) Div DestWidth;
   PixelColor := JPEGGetPixel(Img, SrcX, SrcY);
   PutPixel(DestX + X, DestY + Y, PixelColor);
  End;
 End;
End;

{ Chercher une image JPEG dans le cache }
Function JPEGFindInCache(Const URL: String): Integer;
Var
 I: Integer;
Begin
 JPEGFindInCache := 0;
 For I := 1 To 16 Do Begin
  If JPEGImageCache[I].Used And (JPEGImageCache[I].URL = URL) Then Begin
   JPEGFindInCache := I;
   Exit;
  End;
 End;
End;

{ Ajouter une image JPEG au cache }
Function JPEGAddToCache(Const URL: String; Const Img: JPEGImage): Integer;
Var
 I: Integer;
 Slot: Integer;
Begin
 JPEGAddToCache := 0;

 Slot := 0;
 For I := 1 To 16 Do Begin
  If Not JPEGImageCache[I].Used Then Begin
   Slot := I;
   Break;
  End;
 End;

 If Slot = 0 Then Begin
  If JPEGImageCache[1].Image.Valid Then
   JPEGFreeImage(JPEGImageCache[1].Image);
  Slot := 1;
 End;

 JPEGImageCache[Slot].URL := URL;
 JPEGImageCache[Slot].Image := Img;
 JPEGImageCache[Slot].Used := True;
 JPEGAddToCache := Slot;
End;

{ Construire le chemin complet d'une image JPEG }
Function JPEGBuildImagePath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  JPEGBuildImagePath := Src;
  Exit;
 End;

 BasePath := CurrentURL;

 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 JPEGBuildImagePath := BasePath + Src;
End;

{ =====================================================
  FIN DECODEUR IMAGES JPEG
  ===================================================== }

{ =====================================================
  DECODEUR ET AFFICHAGE D'IMAGES PNG
  ===================================================== }

Const
 { Signature PNG (8 octets) }
 PNG_SIGNATURE: Array[0..7] Of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

 { Types de chunks PNG }
 PNG_CHUNK_IHDR = 'IHDR';  { Image Header }
 PNG_CHUNK_PLTE = 'PLTE';  { Palette }
 PNG_CHUNK_IDAT = 'IDAT';  { Image Data }
 PNG_CHUNK_IEND = 'IEND';  { Image End }
 PNG_CHUNK_tRNS = 'tRNS';  { Transparency }

 { Types de couleur PNG }
 PNG_COLOR_GRAYSCALE = 0;
 PNG_COLOR_RGB = 2;
 PNG_COLOR_PALETTE = 3;
 PNG_COLOR_GRAYSCALE_ALPHA = 4;
 PNG_COLOR_RGBA = 6;

 { Types de filtres PNG }
 PNG_FILTER_NONE = 0;
 PNG_FILTER_SUB = 1;
 PNG_FILTER_UP = 2;
 PNG_FILTER_AVERAGE = 3;
 PNG_FILTER_PAETH = 4;

 { Taille maximale d'image PNG supportee }
 PNG_MAX_WIDTH = 800;
 PNG_MAX_HEIGHT = 600;

 { Constantes pour DEFLATE }
 DEFLATE_MAX_BITS = 15;
 DEFLATE_MAX_LIT_CODES = 286;
 DEFLATE_MAX_DIST_CODES = 30;
 DEFLATE_MAX_CODE_LENGTH = 19;

Type
 { En-tete IHDR PNG }
 PNGHeader = Record
  Width: LongInt;
  Height: LongInt;
  BitDepth: Byte;
  ColorType: Byte;
  Compression: Byte;
  Filter: Byte;
  Interlace: Byte;
 End;

 { Entree de palette PNG }
 PNGPaletteEntry = Record
  R, G, B: Byte;
 End;

 { Table Huffman pour DEFLATE }
 DeflateHuffTable = Record
  Counts: Array[0..DEFLATE_MAX_BITS] Of Word;
  Symbols: Array[0..DEFLATE_MAX_LIT_CODES - 1] Of Word;
  NumSymbols: Integer;
  Valid: Boolean;
 End;

 { Structure d'image PNG en memoire }
 PNGImage = Record
  Width: Integer;
  Height: Integer;
  BitDepth: Byte;
  ColorType: Byte;
  HasAlpha: Boolean;
  Palette: Array[0..255] Of PNGPaletteEntry;
  PaletteSize: Integer;
  TransparentIndex: Integer;  { Pour images palette avec transparence }
  TransparentR, TransparentG, TransparentB: Word;  { Pour RGB transparent }
  HasTransparent: Boolean;
  Data: Pointer;         { Pointeur vers les donnees RGB }
  AlphaData: Pointer;    { Pointeur vers les donnees alpha }
  DataSize: LongInt;
  Valid: Boolean;
 End;

 PNGImagePtr = ^PNGImage;

Var
 { Cache d'images PNG chargees }
 PNGImageCache: Array[1..16] Of Record
  URL: String[255];
  Image: PNGImage;
  Used: Boolean;
 End;
 PNGImageCacheCount: Integer;

 { Buffer pour decompression DEFLATE }
 DeflateInBuffer: Array[0..65535] Of Byte;
 DeflateInPos: LongInt;
 DeflateInLen: LongInt;
 DeflateBitBuffer: LongInt;
 DeflateBitsInBuffer: Integer;

 { Buffer de sortie pour donnees decompressees }
 DeflateOutBuffer: Array[0..65535] Of Byte;
 DeflateOutPos: LongInt;
 DeflateOutLen: LongInt;

{ Initialiser le cache d'images PNG }
Procedure PNGInitCache;
Var
 I: Integer;
Begin
 For I := 1 To 16 Do Begin
  PNGImageCache[I].URL := '';
  PNGImageCache[I].Used := False;
  PNGImageCache[I].Image.Valid := False;
  PNGImageCache[I].Image.Data := Nil;
  PNGImageCache[I].Image.AlphaData := Nil;
 End;
 PNGImageCacheCount := 0;
End;

{ Convertir une couleur RGB en index de palette VGA }
Function PNGRGBToVGAColor(R, G, B: Byte): Byte;
Var
 BestColor, BestDist, Dist: LongInt;
 I: Integer;
Const
 VGAPalette: Array[0..15, 0..2] Of Byte = (
  (0, 0, 0),       { 0: Noir }
  (0, 0, 170),     { 1: Bleu }
  (0, 170, 0),     { 2: Vert }
  (0, 170, 170),   { 3: Cyan }
  (170, 0, 0),     { 4: Rouge }
  (170, 0, 170),   { 5: Magenta }
  (170, 85, 0),    { 6: Marron }
  (170, 170, 170), { 7: Gris clair }
  (85, 85, 85),    { 8: Gris fonce }
  (85, 85, 255),   { 9: Bleu clair }
  (85, 255, 85),   { 10: Vert clair }
  (85, 255, 255),  { 11: Cyan clair }
  (255, 85, 85),   { 12: Rouge clair }
  (255, 85, 255),  { 13: Magenta clair }
  (255, 255, 85),  { 14: Jaune }
  (255, 255, 255)  { 15: Blanc }
 );
Begin
 BestColor := 0;
 BestDist := 256 * 256 * 3;

 For I := 0 To 15 Do Begin
  Dist := (Integer(R) - Integer(VGAPalette[I, 0])) *
          (Integer(R) - Integer(VGAPalette[I, 0])) +
          (Integer(G) - Integer(VGAPalette[I, 1])) *
          (Integer(G) - Integer(VGAPalette[I, 1])) +
          (Integer(B) - Integer(VGAPalette[I, 2])) *
          (Integer(B) - Integer(VGAPalette[I, 2]));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestColor := I;
  End;
 End;

 PNGRGBToVGAColor := BestColor;
End;

{ Liberer la memoire d'une image PNG }
Procedure PNGFreeImage(Var Img: PNGImage);
Begin
 If Img.Data <> Nil Then Begin
  FreeMem(Img.Data, Img.DataSize);
  Img.Data := Nil;
 End;
 If Img.AlphaData <> Nil Then Begin
  FreeMem(Img.AlphaData, LongInt(Img.Width) * LongInt(Img.Height));
  Img.AlphaData := Nil;
 End;
 Img.Valid := False;
 Img.DataSize := 0;
End;

{ Lire un mot 32 bits big-endian }
Function PNGReadDWord(Var F: File): LongInt;
Var
 B: Array[0..3] Of Byte;
 BytesRead: Word;
Begin
 BlockRead(F, B, 4, BytesRead);
 PNGReadDWord := (LongInt(B[0]) Shl 24) Or (LongInt(B[1]) Shl 16) Or
                 (LongInt(B[2]) Shl 8) Or LongInt(B[3]);
End;

{ Lire un mot 16 bits big-endian }
Function PNGReadWord(Var F: File): Word;
Var
 B1, B2: Byte;
 BytesRead: Word;
Begin
 BlockRead(F, B1, 1, BytesRead);
 BlockRead(F, B2, 1, BytesRead);
 PNGReadWord := (Word(B1) Shl 8) Or B2;
End;

{ Initialiser le buffer de bits pour DEFLATE }
Procedure DeflateInitBitBuffer;
Begin
 DeflateBitBuffer := 0;
 DeflateBitsInBuffer := 0;
 DeflateInPos := 0;
End;

{ Lire N bits du flux DEFLATE }
Function DeflateReadBits(NumBits: Integer): Integer;
Var
 Result: Integer;
Begin
 DeflateReadBits := -1;

 While DeflateBitsInBuffer < NumBits Do Begin
  If DeflateInPos >= DeflateInLen Then Exit;
  DeflateBitBuffer := DeflateBitBuffer Or
   (LongInt(DeflateInBuffer[DeflateInPos]) Shl DeflateBitsInBuffer);
  Inc(DeflateInPos);
  Inc(DeflateBitsInBuffer, 8);
 End;

 Result := DeflateBitBuffer And ((1 Shl NumBits) - 1);
 DeflateBitBuffer := DeflateBitBuffer Shr NumBits;
 Dec(DeflateBitsInBuffer, NumBits);
 DeflateReadBits := Result;
End;

{ Tables de longueurs pour DEFLATE }
Const
 DeflateLengthBase: Array[257..285] Of Word = (
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
 );
 DeflateLengthExtra: Array[257..285] Of Byte = (
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
  3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
 );
 DeflateDistBase: Array[0..29] Of Word = (
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
  257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
  8193, 12289, 16385, 24577
 );
 DeflateDistExtra: Array[0..29] Of Byte = (
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
  7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
 );
 DeflateCodeLengthOrder: Array[0..18] Of Byte = (
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
 );

{ Construire une table Huffman }
Procedure DeflateBuildHuffTable(Var Table: DeflateHuffTable;
                                 Var Lengths: Array Of Byte;
                                 NumCodes: Integer);
Var
 I, Code, Len: Integer;
 NextCode: Array[0..DEFLATE_MAX_BITS] Of Integer;
Begin
 Table.Valid := False;
 Table.NumSymbols := NumCodes;

 { Compter les codes par longueur }
 For I := 0 To DEFLATE_MAX_BITS Do Table.Counts[I] := 0;
 For I := 0 To NumCodes - 1 Do
  If Lengths[I] > 0 Then
   Inc(Table.Counts[Lengths[I]]);

 { Calculer les premiers codes par longueur }
 Code := 0;
 For I := 1 To DEFLATE_MAX_BITS Do Begin
  Code := (Code + Table.Counts[I - 1]) Shl 1;
  NextCode[I] := Code;
 End;

 { Assigner les symboles }
 For I := 0 To NumCodes - 1 Do Begin
  Len := Lengths[I];
  If Len > 0 Then Begin
   Table.Symbols[NextCode[Len]] := I;
   Inc(NextCode[Len]);
  End;
 End;

 Table.Valid := True;
End;

{ Decoder un symbole Huffman }
Function DeflateDecodeSymbol(Var Table: DeflateHuffTable): Integer;
Var
 Code, Len, First, Index, Count: Integer;
Begin
 DeflateDecodeSymbol := -1;
 If Not Table.Valid Then Exit;

 Code := 0;
 First := 0;
 Index := 0;

 For Len := 1 To DEFLATE_MAX_BITS Do Begin
  Code := (Code Shl 1) Or DeflateReadBits(1);
  If Code < 0 Then Exit;

  Count := Table.Counts[Len];
  If Code - First < Count Then Begin
   DeflateDecodeSymbol := Table.Symbols[Index + Code - First];
   Exit;
  End;
  First := (First + Count) Shl 1;
  Inc(Index, Count);
 End;
End;

{ Decompresser un bloc DEFLATE }
Function DeflateDecompressBlock(Var OutData: Array Of Byte;
                                 Var OutLen: LongInt;
                                 MaxOut: LongInt): Boolean;
Var
 BFinal, BType: Integer;
 Len, NLen: Word;
 I: Integer;
 LitLenLengths: Array[0..DEFLATE_MAX_LIT_CODES - 1] Of Byte;
 DistLengths: Array[0..DEFLATE_MAX_DIST_CODES - 1] Of Byte;
 CodeLengths: Array[0..18] Of Byte;
 LitLenTable, DistTable, CodeTable: DeflateHuffTable;
 HLit, HDist, HCLen: Integer;
 Symbol, Length, Distance: Integer;
 Extra: Integer;
 CopyPos: LongInt;
Begin
 DeflateDecompressBlock := False;
 OutLen := 0;

 DeflateInitBitBuffer;

 Repeat
  BFinal := DeflateReadBits(1);
  If BFinal < 0 Then Exit;

  BType := DeflateReadBits(2);
  If BType < 0 Then Exit;

  Case BType Of
   0: Begin { Bloc non compresse }
    { Aligner sur octet }
    DeflateBitBuffer := 0;
    DeflateBitsInBuffer := 0;

    If DeflateInPos + 4 > DeflateInLen Then Exit;
    Len := DeflateInBuffer[DeflateInPos] Or
           (Word(DeflateInBuffer[DeflateInPos + 1]) Shl 8);
    NLen := DeflateInBuffer[DeflateInPos + 2] Or
            (Word(DeflateInBuffer[DeflateInPos + 3]) Shl 8);
    Inc(DeflateInPos, 4);

    If Len <> (NLen Xor $FFFF) Then Exit;

    If DeflateInPos + Len > DeflateInLen Then Exit;
    If OutLen + Len > MaxOut Then Exit;

    For I := 0 To Len - 1 Do Begin
     OutData[OutLen] := DeflateInBuffer[DeflateInPos];
     Inc(OutLen);
     Inc(DeflateInPos);
    End;
   End;

   1: Begin { Bloc avec codes Huffman fixes }
    { Construire les tables Huffman fixes }
    For I := 0 To 143 Do LitLenLengths[I] := 8;
    For I := 144 To 255 Do LitLenLengths[I] := 9;
    For I := 256 To 279 Do LitLenLengths[I] := 7;
    For I := 280 To 287 Do LitLenLengths[I] := 8;
    DeflateBuildHuffTable(LitLenTable, LitLenLengths, 288);

    For I := 0 To 31 Do DistLengths[I] := 5;
    DeflateBuildHuffTable(DistTable, DistLengths, 32);

    { Decoder les symboles }
    Repeat
     Symbol := DeflateDecodeSymbol(LitLenTable);
     If Symbol < 0 Then Exit;

     If Symbol < 256 Then Begin
      { Litteral }
      If OutLen >= MaxOut Then Exit;
      OutData[OutLen] := Symbol;
      Inc(OutLen);
     End
     Else If Symbol = 256 Then Begin
      { Fin du bloc }
      Break;
     End
     Else Begin
      { Longueur + distance }
      Length := DeflateLengthBase[Symbol];
      If DeflateLengthExtra[Symbol] > 0 Then Begin
       Extra := DeflateReadBits(DeflateLengthExtra[Symbol]);
       If Extra < 0 Then Exit;
       Inc(Length, Extra);
      End;

      Symbol := DeflateDecodeSymbol(DistTable);
      If Symbol < 0 Then Exit;

      Distance := DeflateDistBase[Symbol];
      If DeflateDistExtra[Symbol] > 0 Then Begin
       Extra := DeflateReadBits(DeflateDistExtra[Symbol]);
       If Extra < 0 Then Exit;
       Inc(Distance, Extra);
      End;

      { Copier les octets }
      CopyPos := OutLen - Distance;
      If CopyPos < 0 Then Exit;

      For I := 0 To Length - 1 Do Begin
       If OutLen >= MaxOut Then Exit;
       OutData[OutLen] := OutData[CopyPos];
       Inc(OutLen);
       Inc(CopyPos);
      End;
     End;
    Until False;
   End;

   2: Begin { Bloc avec codes Huffman dynamiques }
    HLit := DeflateReadBits(5) + 257;
    HDist := DeflateReadBits(5) + 1;
    HCLen := DeflateReadBits(4) + 4;

    If (HLit < 0) Or (HDist < 0) Or (HCLen < 0) Then Exit;

    { Lire les longueurs de codes }
    For I := 0 To 18 Do CodeLengths[I] := 0;
    For I := 0 To HCLen - 1 Do Begin
     CodeLengths[DeflateCodeLengthOrder[I]] := DeflateReadBits(3);
    End;

    DeflateBuildHuffTable(CodeTable, CodeLengths, 19);

    { Decoder les longueurs literal/length }
    I := 0;
    While I < HLit + HDist Do Begin
     Symbol := DeflateDecodeSymbol(CodeTable);
     If Symbol < 0 Then Exit;

     If Symbol < 16 Then Begin
      If I < HLit Then LitLenLengths[I] := Symbol
      Else DistLengths[I - HLit] := Symbol;
      Inc(I);
     End
     Else If Symbol = 16 Then Begin
      Extra := DeflateReadBits(2) + 3;
      If Extra < 0 Then Exit;
      While Extra > 0 Do Begin
       If I < HLit Then
        LitLenLengths[I] := LitLenLengths[I - 1]
       Else
        DistLengths[I - HLit] := DistLengths[I - HLit - 1];
       Inc(I);
       Dec(Extra);
      End;
     End
     Else If Symbol = 17 Then Begin
      Extra := DeflateReadBits(3) + 3;
      If Extra < 0 Then Exit;
      While Extra > 0 Do Begin
       If I < HLit Then LitLenLengths[I] := 0
       Else DistLengths[I - HLit] := 0;
       Inc(I);
       Dec(Extra);
      End;
     End
     Else Begin { Symbol = 18 }
      Extra := DeflateReadBits(7) + 11;
      If Extra < 0 Then Exit;
      While Extra > 0 Do Begin
       If I < HLit Then LitLenLengths[I] := 0
       Else DistLengths[I - HLit] := 0;
       Inc(I);
       Dec(Extra);
      End;
     End;
    End;

    DeflateBuildHuffTable(LitLenTable, LitLenLengths, HLit);
    DeflateBuildHuffTable(DistTable, DistLengths, HDist);

    { Decoder les symboles }
    Repeat
     Symbol := DeflateDecodeSymbol(LitLenTable);
     If Symbol < 0 Then Exit;

     If Symbol < 256 Then Begin
      If OutLen >= MaxOut Then Exit;
      OutData[OutLen] := Symbol;
      Inc(OutLen);
     End
     Else If Symbol = 256 Then Begin
      Break;
     End
     Else Begin
      Length := DeflateLengthBase[Symbol];
      If DeflateLengthExtra[Symbol] > 0 Then Begin
       Extra := DeflateReadBits(DeflateLengthExtra[Symbol]);
       If Extra < 0 Then Exit;
       Inc(Length, Extra);
      End;

      Symbol := DeflateDecodeSymbol(DistTable);
      If Symbol < 0 Then Exit;

      Distance := DeflateDistBase[Symbol];
      If DeflateDistExtra[Symbol] > 0 Then Begin
       Extra := DeflateReadBits(DeflateDistExtra[Symbol]);
       If Extra < 0 Then Exit;
       Inc(Distance, Extra);
      End;

      CopyPos := OutLen - Distance;
      If CopyPos < 0 Then Exit;

      For I := 0 To Length - 1 Do Begin
       If OutLen >= MaxOut Then Exit;
       OutData[OutLen] := OutData[CopyPos];
       Inc(OutLen);
       Inc(CopyPos);
      End;
     End;
    Until False;
   End;

   Else Exit; { Type invalide }
  End;

 Until BFinal = 1;

 DeflateDecompressBlock := True;
End;

{ Predicteur Paeth pour filtres PNG }
Function PNGPaethPredictor(A, B, C: Integer): Integer;
Var
 P, PA, PB, PC: Integer;
Begin
 P := A + B - C;
 PA := Abs(P - A);
 PB := Abs(P - B);
 PC := Abs(P - C);

 If (PA <= PB) And (PA <= PC) Then
  PNGPaethPredictor := A
 Else If PB <= PC Then
  PNGPaethPredictor := B
 Else
  PNGPaethPredictor := C;
End;

{ Appliquer les filtres PNG }
Function PNGUnfilterRow(FilterType: Byte;
                         Var CurrRow, PrevRow: Array Of Byte;
                         RowLen, BytesPerPixel: Integer): Boolean;
Var
 I: Integer;
 A, B, C, Raw: Integer;
Begin
 PNGUnfilterRow := False;

 Case FilterType Of
  PNG_FILTER_NONE: Begin
   { Rien a faire }
  End;

  PNG_FILTER_SUB: Begin
   For I := BytesPerPixel To RowLen - 1 Do Begin
    CurrRow[I] := (CurrRow[I] + CurrRow[I - BytesPerPixel]) And $FF;
   End;
  End;

  PNG_FILTER_UP: Begin
   For I := 0 To RowLen - 1 Do Begin
    CurrRow[I] := (CurrRow[I] + PrevRow[I]) And $FF;
   End;
  End;

  PNG_FILTER_AVERAGE: Begin
   For I := 0 To RowLen - 1 Do Begin
    If I < BytesPerPixel Then
     A := 0
    Else
     A := CurrRow[I - BytesPerPixel];
    B := PrevRow[I];
    CurrRow[I] := (CurrRow[I] + (A + B) Div 2) And $FF;
   End;
  End;

  PNG_FILTER_PAETH: Begin
   For I := 0 To RowLen - 1 Do Begin
    If I < BytesPerPixel Then Begin
     A := 0;
     C := 0;
    End
    Else Begin
     A := CurrRow[I - BytesPerPixel];
     C := PrevRow[I - BytesPerPixel];
    End;
    B := PrevRow[I];
    CurrRow[I] := (CurrRow[I] + PNGPaethPredictor(A, B, C)) And $FF;
   End;
  End;

  Else Exit; { Filtre inconnu }
 End;

 PNGUnfilterRow := True;
End;

{ Charger une image PNG depuis un fichier }
Function PNGLoadFromFile(Const FileName: String; Var Img: PNGImage): Boolean;
Var
 F: File;
 Signature: Array[0..7] Of Byte;
 ChunkLen: LongInt;
 ChunkType: Array[0..3] Of Char;
 ChunkCRC: LongInt;
 BytesRead: Word;
 I, X, Y: Integer;
 Header: PNGHeader;
 CompDataLen: LongInt;
 CompData: Array[0..65535] Of Byte;
 CompDataPos: LongInt;
 DecompData: Array[0..65535] Of Byte;
 DecompLen: LongInt;
 BytesPerPixel, RowBytes: Integer;
 CurrRow, PrevRow: Array[0..4095] Of Byte;
 FilterType: Byte;
 DataPos: LongInt;
 PixelOffset: LongInt;
 DataPtr: ^Byte;
 AlphaPtr: ^Byte;
 R, G, B, A: Byte;
 GrayVal: Byte;
 PalIdx: Byte;
Begin
 PNGLoadFromFile := False;
 Img.Valid := False;
 Img.Data := Nil;
 Img.AlphaData := Nil;
 Img.HasTransparent := False;
 Img.TransparentIndex := -1;

 { Ouvrir le fichier }
 {$I-}
 Assign(F, FileName);
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Verifier la signature PNG }
 BlockRead(F, Signature, 8, BytesRead);
 If BytesRead <> 8 Then Begin
  Close(F);
  Exit;
 End;

 For I := 0 To 7 Do Begin
  If Signature[I] <> PNG_SIGNATURE[I] Then Begin
   Close(F);
   Exit;
  End;
 End;

 CompDataLen := 0;
 CompDataPos := 0;
 Img.PaletteSize := 0;

 { Parcourir les chunks }
 While True Do Begin
  ChunkLen := PNGReadDWord(F);
  BlockRead(F, ChunkType, 4, BytesRead);
  If BytesRead <> 4 Then Break;

  If ChunkType = PNG_CHUNK_IHDR Then Begin
   { En-tete de l'image }
   Header.Width := PNGReadDWord(F);
   Header.Height := PNGReadDWord(F);
   BlockRead(F, Header.BitDepth, 1, BytesRead);
   BlockRead(F, Header.ColorType, 1, BytesRead);
   BlockRead(F, Header.Compression, 1, BytesRead);
   BlockRead(F, Header.Filter, 1, BytesRead);
   BlockRead(F, Header.Interlace, 1, BytesRead);

   If (Header.Width > PNG_MAX_WIDTH) Or (Header.Height > PNG_MAX_HEIGHT) Then Begin
    Close(F);
    Exit;
   End;

   Img.Width := Header.Width;
   Img.Height := Header.Height;
   Img.BitDepth := Header.BitDepth;
   Img.ColorType := Header.ColorType;
   Img.HasAlpha := (Header.ColorType = PNG_COLOR_GRAYSCALE_ALPHA) Or
                   (Header.ColorType = PNG_COLOR_RGBA);

   { Lire le CRC }
   ChunkCRC := PNGReadDWord(F);
  End

  Else If ChunkType = PNG_CHUNK_PLTE Then Begin
   { Palette }
   Img.PaletteSize := ChunkLen Div 3;
   For I := 0 To Img.PaletteSize - 1 Do Begin
    BlockRead(F, Img.Palette[I].R, 1, BytesRead);
    BlockRead(F, Img.Palette[I].G, 1, BytesRead);
    BlockRead(F, Img.Palette[I].B, 1, BytesRead);
   End;
   ChunkCRC := PNGReadDWord(F);
  End

  Else If ChunkType = PNG_CHUNK_tRNS Then Begin
   { Transparence }
   Img.HasTransparent := True;
   If Img.ColorType = PNG_COLOR_PALETTE Then Begin
    { Index transparent pour palette }
    For I := 0 To ChunkLen - 1 Do Begin
     BlockRead(F, A, 1, BytesRead);
     If A = 0 Then Img.TransparentIndex := I;
    End;
   End
   Else If Img.ColorType = PNG_COLOR_GRAYSCALE Then Begin
    Img.TransparentG := PNGReadWord(F);
   End
   Else If Img.ColorType = PNG_COLOR_RGB Then Begin
    Img.TransparentR := PNGReadWord(F);
    Img.TransparentG := PNGReadWord(F);
    Img.TransparentB := PNGReadWord(F);
   End;
   ChunkCRC := PNGReadDWord(F);
  End

  Else If ChunkType = PNG_CHUNK_IDAT Then Begin
   { Donnees compressees - accumuler }
   If CompDataPos + ChunkLen <= 65536 Then Begin
    BlockRead(F, CompData[CompDataPos], ChunkLen, BytesRead);
    Inc(CompDataPos, ChunkLen);
   End
   Else Begin
    { Trop de donnees - sauter }
    For I := 1 To ChunkLen Do Begin
     BlockRead(F, A, 1, BytesRead);
    End;
   End;
   ChunkCRC := PNGReadDWord(F);
  End

  Else If ChunkType = PNG_CHUNK_IEND Then Begin
   { Fin de l'image }
   ChunkCRC := PNGReadDWord(F);
   Break;
  End

  Else Begin
   { Chunk inconnu - sauter }
   For I := 1 To ChunkLen Do Begin
    BlockRead(F, A, 1, BytesRead);
   End;
   ChunkCRC := PNGReadDWord(F);
  End;
 End;

 Close(F);

 { Decompresser les donnees (sauter l'en-tete zlib de 2 octets) }
 If CompDataPos < 3 Then Exit;

 Move(CompData[2], DeflateInBuffer, CompDataPos - 2);
 DeflateInLen := CompDataPos - 2;

 If Not DeflateDecompressBlock(DecompData, DecompLen, 65536) Then Exit;

 { Calculer les octets par pixel }
 Case Img.ColorType Of
  PNG_COLOR_GRAYSCALE: BytesPerPixel := 1;
  PNG_COLOR_RGB: BytesPerPixel := 3;
  PNG_COLOR_PALETTE: BytesPerPixel := 1;
  PNG_COLOR_GRAYSCALE_ALPHA: BytesPerPixel := 2;
  PNG_COLOR_RGBA: BytesPerPixel := 4;
  Else Exit;
 End;

 RowBytes := Img.Width * BytesPerPixel;

 { Allouer la memoire pour les pixels RGB }
 Img.DataSize := LongInt(Img.Width) * LongInt(Img.Height) * 3;
 If Img.DataSize > 65520 Then Exit;

 GetMem(Img.Data, Img.DataSize);
 If Img.Data = Nil Then Exit;

 { Allouer la memoire pour l'alpha si necessaire }
 If Img.HasAlpha Then Begin
  GetMem(Img.AlphaData, LongInt(Img.Width) * LongInt(Img.Height));
  If Img.AlphaData = Nil Then Begin
   FreeMem(Img.Data, Img.DataSize);
   Img.Data := Nil;
   Exit;
  End;
 End;

 { Initialiser la ligne precedente a zero }
 For I := 0 To RowBytes - 1 Do PrevRow[I] := 0;

 { Decoder les lignes }
 DataPos := 0;
 For Y := 0 To Img.Height - 1 Do Begin
  { Lire le type de filtre }
  If DataPos >= DecompLen Then Break;
  FilterType := DecompData[DataPos];
  Inc(DataPos);

  { Lire les donnees de la ligne }
  For I := 0 To RowBytes - 1 Do Begin
   If DataPos >= DecompLen Then
    CurrRow[I] := 0
   Else Begin
    CurrRow[I] := DecompData[DataPos];
    Inc(DataPos);
   End;
  End;

  { Appliquer le filtre inverse }
  If Not PNGUnfilterRow(FilterType, CurrRow, PrevRow, RowBytes, BytesPerPixel) Then Begin
   PNGFreeImage(Img);
   Exit;
  End;

  { Convertir les pixels en RGB }
  For X := 0 To Img.Width - 1 Do Begin
   PixelOffset := (LongInt(Y) * LongInt(Img.Width) + LongInt(X)) * 3;
   DataPtr := Img.Data;
   Inc(DataPtr, PixelOffset);

   Case Img.ColorType Of
    PNG_COLOR_GRAYSCALE: Begin
     GrayVal := CurrRow[X];
     DataPtr^ := GrayVal; Inc(DataPtr);
     DataPtr^ := GrayVal; Inc(DataPtr);
     DataPtr^ := GrayVal;
    End;

    PNG_COLOR_RGB: Begin
     DataPtr^ := CurrRow[X * 3]; Inc(DataPtr);
     DataPtr^ := CurrRow[X * 3 + 1]; Inc(DataPtr);
     DataPtr^ := CurrRow[X * 3 + 2];
    End;

    PNG_COLOR_PALETTE: Begin
     PalIdx := CurrRow[X];
     If PalIdx < Img.PaletteSize Then Begin
      DataPtr^ := Img.Palette[PalIdx].R; Inc(DataPtr);
      DataPtr^ := Img.Palette[PalIdx].G; Inc(DataPtr);
      DataPtr^ := Img.Palette[PalIdx].B;
     End
     Else Begin
      DataPtr^ := 0; Inc(DataPtr);
      DataPtr^ := 0; Inc(DataPtr);
      DataPtr^ := 0;
     End;
    End;

    PNG_COLOR_GRAYSCALE_ALPHA: Begin
     GrayVal := CurrRow[X * 2];
     A := CurrRow[X * 2 + 1];
     DataPtr^ := GrayVal; Inc(DataPtr);
     DataPtr^ := GrayVal; Inc(DataPtr);
     DataPtr^ := GrayVal;
     If Img.AlphaData <> Nil Then Begin
      AlphaPtr := Img.AlphaData;
      Inc(AlphaPtr, LongInt(Y) * LongInt(Img.Width) + LongInt(X));
      AlphaPtr^ := A;
     End;
    End;

    PNG_COLOR_RGBA: Begin
     DataPtr^ := CurrRow[X * 4]; Inc(DataPtr);
     DataPtr^ := CurrRow[X * 4 + 1]; Inc(DataPtr);
     DataPtr^ := CurrRow[X * 4 + 2];
     If Img.AlphaData <> Nil Then Begin
      AlphaPtr := Img.AlphaData;
      Inc(AlphaPtr, LongInt(Y) * LongInt(Img.Width) + LongInt(X));
      AlphaPtr^ := CurrRow[X * 4 + 3];
     End;
    End;
   End;
  End;

  { Sauvegarder la ligne courante comme precedente }
  Move(CurrRow, PrevRow, RowBytes);
 End;

 Img.Valid := True;
 PNGLoadFromFile := True;
End;

{ Obtenir la couleur d'un pixel dans une image PNG }
Function PNGGetPixel(Const Img: PNGImage; X, Y: Integer): Byte;
Var
 Offset: LongInt;
 DataPtr: ^Byte;
 R, G, B: Byte;
Begin
 PNGGetPixel := 0;
 If Not Img.Valid Then Exit;
 If (X < 0) Or (X >= Img.Width) Or (Y < 0) Or (Y >= Img.Height) Then Exit;

 Offset := (LongInt(Y) * LongInt(Img.Width) + LongInt(X)) * 3;
 DataPtr := Img.Data;
 Inc(DataPtr, Offset);
 R := DataPtr^;
 Inc(DataPtr);
 G := DataPtr^;
 Inc(DataPtr);
 B := DataPtr^;

 PNGGetPixel := PNGRGBToVGAColor(R, G, B);
End;

{ Obtenir l'alpha d'un pixel dans une image PNG }
Function PNGGetAlpha(Const Img: PNGImage; X, Y: Integer): Byte;
Var
 Offset: LongInt;
 AlphaPtr: ^Byte;
Begin
 PNGGetAlpha := 255;  { Opaque par defaut }
 If Not Img.Valid Then Exit;
 If Not Img.HasAlpha Then Exit;
 If Img.AlphaData = Nil Then Exit;
 If (X < 0) Or (X >= Img.Width) Or (Y < 0) Or (Y >= Img.Height) Then Exit;

 Offset := LongInt(Y) * LongInt(Img.Width) + LongInt(X);
 AlphaPtr := Img.AlphaData;
 Inc(AlphaPtr, Offset);
 PNGGetAlpha := AlphaPtr^;
End;

{ Dessiner une image PNG a l'ecran }
Procedure PNGDrawImage(Const Img: PNGImage; DestX, DestY: Integer;
                        MaxWidth, MaxHeight: Integer);
Var
 X, Y: Integer;
 DrawWidth, DrawHeight: Integer;
 PixelColor: Byte;
 Alpha: Byte;
Begin
 If Not Img.Valid Then Exit;

 DrawWidth := Img.Width;
 DrawHeight := Img.Height;

 If DrawWidth > MaxWidth Then DrawWidth := MaxWidth;
 If DrawHeight > MaxHeight Then DrawHeight := MaxHeight;

 For Y := 0 To DrawHeight - 1 Do Begin
  For X := 0 To DrawWidth - 1 Do Begin
   If Img.HasAlpha Then Begin
    Alpha := PNGGetAlpha(Img, X, Y);
    If Alpha > 128 Then Begin
     PixelColor := PNGGetPixel(Img, X, Y);
     PutPixel(DestX + X, DestY + Y, PixelColor);
    End;
   End
   Else Begin
    PixelColor := PNGGetPixel(Img, X, Y);
    PutPixel(DestX + X, DestY + Y, PixelColor);
   End;
  End;
 End;
End;

{ Dessiner une image PNG avec mise a l'echelle }
Procedure PNGDrawImageScaled(Const Img: PNGImage; DestX, DestY: Integer;
                              DestWidth, DestHeight: Integer);
Var
 X, Y: Integer;
 SrcX, SrcY: Integer;
 PixelColor: Byte;
 Alpha: Byte;
Begin
 If Not Img.Valid Then Exit;
 If (DestWidth <= 0) Or (DestHeight <= 0) Then Exit;

 For Y := 0 To DestHeight - 1 Do Begin
  SrcY := (Y * Img.Height) Div DestHeight;
  For X := 0 To DestWidth - 1 Do Begin
   SrcX := (X * Img.Width) Div DestWidth;
   If Img.HasAlpha Then Begin
    Alpha := PNGGetAlpha(Img, SrcX, SrcY);
    If Alpha > 128 Then Begin
     PixelColor := PNGGetPixel(Img, SrcX, SrcY);
     PutPixel(DestX + X, DestY + Y, PixelColor);
    End;
   End
   Else Begin
    PixelColor := PNGGetPixel(Img, SrcX, SrcY);
    PutPixel(DestX + X, DestY + Y, PixelColor);
   End;
  End;
 End;
End;

{ Chercher une image PNG dans le cache }
Function PNGFindInCache(Const URL: String): Integer;
Var
 I: Integer;
Begin
 PNGFindInCache := 0;
 For I := 1 To 16 Do Begin
  If PNGImageCache[I].Used And (PNGImageCache[I].URL = URL) Then Begin
   PNGFindInCache := I;
   Exit;
  End;
 End;
End;

{ Ajouter une image PNG au cache }
Function PNGAddToCache(Const URL: String; Const Img: PNGImage): Integer;
Var
 I: Integer;
 Slot: Integer;
Begin
 PNGAddToCache := 0;

 Slot := 0;
 For I := 1 To 16 Do Begin
  If Not PNGImageCache[I].Used Then Begin
   Slot := I;
   Break;
  End;
 End;

 If Slot = 0 Then Begin
  If PNGImageCache[1].Image.Valid Then
   PNGFreeImage(PNGImageCache[1].Image);
  Slot := 1;
 End;

 PNGImageCache[Slot].URL := URL;
 PNGImageCache[Slot].Image := Img;
 PNGImageCache[Slot].Used := True;
 PNGAddToCache := Slot;
End;

{ Construire le chemin complet d'une image PNG }
Function PNGBuildImagePath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  PNGBuildImagePath := Src;
  Exit;
 End;

 BasePath := CurrentURL;

 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 PNGBuildImagePath := BasePath + Src;
End;

{ =====================================================
  FIN DECODEUR IMAGES PNG
  ===================================================== }

{ =====================================================
  PARSEUR ET RENDU DE FICHIERS SVG (Scalable Vector Graphics)
  ===================================================== }

Const
 { Types d'elements SVG }
 SVG_ELEM_NONE = 0;
 SVG_ELEM_SVG = 1;
 SVG_ELEM_G = 2;
 SVG_ELEM_RECT = 3;
 SVG_ELEM_CIRCLE = 4;
 SVG_ELEM_ELLIPSE = 5;
 SVG_ELEM_LINE = 6;
 SVG_ELEM_POLYLINE = 7;
 SVG_ELEM_POLYGON = 8;
 SVG_ELEM_PATH = 9;
 SVG_ELEM_TEXT = 10;

 { Commandes de chemin SVG }
 SVG_CMD_MOVETO = 'M';
 SVG_CMD_LINETO = 'L';
 SVG_CMD_HLINETO = 'H';
 SVG_CMD_VLINETO = 'V';
 SVG_CMD_CURVETO = 'C';
 SVG_CMD_SMOOTHCURVE = 'S';
 SVG_CMD_QUADRATIC = 'Q';
 SVG_CMD_SMOOTHQUAD = 'T';
 SVG_CMD_ARC = 'A';
 SVG_CMD_CLOSEPATH = 'Z';

 { Taille maximale SVG }
 SVG_MAX_WIDTH = 800;
 SVG_MAX_HEIGHT = 600;
 SVG_MAX_POINTS = 1024;
 SVG_MAX_ELEMENTS = 256;

Type
 { Point 2D flottant }
 SVGPoint = Record
  X, Y: Real;
 End;

 { Matrice de transformation 2D }
 SVGTransform = Record
  A, B, C, D, E, F: Real;  { a b c d e f - matrice 3x3 }
 End;

 { Style SVG }
 SVGStyle = Record
  Fill: LongInt;        { Couleur de remplissage (-1 = none) }
  Stroke: LongInt;      { Couleur de contour (-1 = none) }
  StrokeWidth: Real;    { Largeur du contour }
  Opacity: Real;        { Opacite 0.0 - 1.0 }
  FillOpacity: Real;
  StrokeOpacity: Real;
 End;

 { Element SVG de base }
 SVGElementPtr = ^SVGElement;
 SVGElement = Record
  ElemType: Integer;
  Style: SVGStyle;
  Transform: SVGTransform;
  { Proprietes specifiques selon le type }
  X, Y: Real;           { Position }
  Width, Height: Real;  { Dimensions }
  RX, RY: Real;         { Rayons (pour rect arrondi, ellipse) }
  X1, Y1, X2, Y2: Real; { Points (pour line) }
  Points: Array[0..SVG_MAX_POINTS - 1] Of SVGPoint;
  PointCount: Integer;
  PathData: String;     { Donnees du chemin }
  TextContent: String;  { Contenu texte }
  Children: Array[0..31] Of SVGElementPtr;
  ChildCount: Integer;
  Parent: SVGElementPtr;
 End;

 { Image SVG complete }
 SVGImage = Record
  Width: Integer;
  Height: Integer;
  ViewBoxX, ViewBoxY: Real;
  ViewBoxW, ViewBoxH: Real;
  HasViewBox: Boolean;
  Root: SVGElementPtr;
  Elements: Array[0..SVG_MAX_ELEMENTS - 1] Of SVGElement;
  ElementCount: Integer;
  Valid: Boolean;
 End;

 SVGImagePtr = ^SVGImage;

Var
 { Cache d'images SVG }
 SVGImageCache: Array[1..16] Of Record
  URL: String[255];
  Image: SVGImage;
  Used: Boolean;
 End;
 SVGImageCacheCount: Integer;

{ Initialiser le cache SVG }
Procedure SVGInitCache;
Var
 I: Integer;
Begin
 For I := 1 To 16 Do Begin
  SVGImageCache[I].URL := '';
  SVGImageCache[I].Used := False;
  SVGImageCache[I].Image.Valid := False;
  SVGImageCache[I].Image.Root := Nil;
 End;
 SVGImageCacheCount := 0;
End;

{ Initialiser une transformation identite }
Procedure SVGInitTransform(Var T: SVGTransform);
Begin
 T.A := 1.0; T.B := 0.0;
 T.C := 0.0; T.D := 1.0;
 T.E := 0.0; T.F := 0.0;
End;

{ Initialiser un style par defaut }
Procedure SVGInitStyle(Var S: SVGStyle);
Begin
 S.Fill := 0;           { Noir }
 S.Stroke := -1;        { Pas de contour }
 S.StrokeWidth := 1.0;
 S.Opacity := 1.0;
 S.FillOpacity := 1.0;
 S.StrokeOpacity := 1.0;
End;

{ Convertir une couleur SVG en couleur VGA }
Function SVGColorToVGA(Color: LongInt): Byte;
Var
 R, G, B: Byte;
 BestColor, BestDist, Dist: LongInt;
 I: Integer;
Const
 VGAPalette: Array[0..15, 0..2] Of Byte = (
  (0, 0, 0),       { 0: Noir }
  (0, 0, 170),     { 1: Bleu }
  (0, 170, 0),     { 2: Vert }
  (0, 170, 170),   { 3: Cyan }
  (170, 0, 0),     { 4: Rouge }
  (170, 0, 170),   { 5: Magenta }
  (170, 85, 0),    { 6: Marron }
  (170, 170, 170), { 7: Gris clair }
  (85, 85, 85),    { 8: Gris fonce }
  (85, 85, 255),   { 9: Bleu clair }
  (85, 255, 85),   { 10: Vert clair }
  (85, 255, 255),  { 11: Cyan clair }
  (255, 85, 85),   { 12: Rouge clair }
  (255, 85, 255),  { 13: Magenta clair }
  (255, 255, 85),  { 14: Jaune }
  (255, 255, 255)  { 15: Blanc }
 );
Begin
 If Color < 0 Then Begin
  SVGColorToVGA := 255; { Transparent }
  Exit;
 End;

 R := (Color Shr 16) And $FF;
 G := (Color Shr 8) And $FF;
 B := Color And $FF;

 BestColor := 0;
 BestDist := 256 * 256 * 3;

 For I := 0 To 15 Do Begin
  Dist := (Integer(R) - Integer(VGAPalette[I, 0])) *
          (Integer(R) - Integer(VGAPalette[I, 0])) +
          (Integer(G) - Integer(VGAPalette[I, 1])) *
          (Integer(G) - Integer(VGAPalette[I, 1])) +
          (Integer(B) - Integer(VGAPalette[I, 2])) *
          (Integer(B) - Integer(VGAPalette[I, 2]));
  If Dist < BestDist Then Begin
   BestDist := Dist;
   BestColor := I;
  End;
 End;

 SVGColorToVGA := BestColor;
End;

{ Parser une couleur SVG (hex, rgb, nommee) }
Function SVGParseColor(Const S: String): LongInt;
Var
 Temp: String;
 R, G, B: Integer;
 Code: Integer;
 I, J: Integer;
Begin
 SVGParseColor := 0;  { Noir par defaut }

 If Length(S) = 0 Then Exit;

 Temp := HTMLLowerCase(S);

 { Couleur "none" = transparent }
 If Temp = 'none' Then Begin
  SVGParseColor := -1;
  Exit;
 End;

 { Format hexadecimal #RRGGBB ou #RGB }
 If S[1] = '#' Then Begin
  If Length(S) = 7 Then Begin
   Val('$' + Copy(S, 2, 2), R, Code);
   Val('$' + Copy(S, 4, 2), G, Code);
   Val('$' + Copy(S, 6, 2), B, Code);
   SVGParseColor := (LongInt(R) Shl 16) Or (LongInt(G) Shl 8) Or LongInt(B);
  End
  Else If Length(S) = 4 Then Begin
   Val('$' + S[2] + S[2], R, Code);
   Val('$' + S[3] + S[3], G, Code);
   Val('$' + S[4] + S[4], B, Code);
   SVGParseColor := (LongInt(R) Shl 16) Or (LongInt(G) Shl 8) Or LongInt(B);
  End;
  Exit;
 End;

 { Format rgb(r,g,b) }
 If Copy(Temp, 1, 4) = 'rgb(' Then Begin
  Temp := Copy(S, 5, Length(S) - 5);
  I := Pos(',', Temp);
  If I > 0 Then Begin
   Val(Copy(Temp, 1, I - 1), R, Code);
   Delete(Temp, 1, I);
   I := Pos(',', Temp);
   If I > 0 Then Begin
    Val(Copy(Temp, 1, I - 1), G, Code);
    Delete(Temp, 1, I);
    Val(Temp, B, Code);
    SVGParseColor := (LongInt(R) Shl 16) Or (LongInt(G) Shl 8) Or LongInt(B);
   End;
  End;
  Exit;
 End;

 { Couleurs nommees }
 If Temp = 'black' Then SVGParseColor := $000000
 Else If Temp = 'white' Then SVGParseColor := $FFFFFF
 Else If Temp = 'red' Then SVGParseColor := $FF0000
 Else If Temp = 'green' Then SVGParseColor := $008000
 Else If Temp = 'blue' Then SVGParseColor := $0000FF
 Else If Temp = 'yellow' Then SVGParseColor := $FFFF00
 Else If Temp = 'cyan' Then SVGParseColor := $00FFFF
 Else If Temp = 'magenta' Then SVGParseColor := $FF00FF
 Else If Temp = 'orange' Then SVGParseColor := $FFA500
 Else If Temp = 'purple' Then SVGParseColor := $800080
 Else If Temp = 'gray' Then SVGParseColor := $808080
 Else If Temp = 'grey' Then SVGParseColor := $808080
 Else If Temp = 'silver' Then SVGParseColor := $C0C0C0
 Else If Temp = 'navy' Then SVGParseColor := $000080
 Else If Temp = 'teal' Then SVGParseColor := $008080
 Else If Temp = 'olive' Then SVGParseColor := $808000
 Else If Temp = 'maroon' Then SVGParseColor := $800000
 Else If Temp = 'lime' Then SVGParseColor := $00FF00
 Else If Temp = 'aqua' Then SVGParseColor := $00FFFF
 Else If Temp = 'fuchsia' Then SVGParseColor := $FF00FF
 Else If Temp = 'pink' Then SVGParseColor := $FFC0CB
 Else If Temp = 'brown' Then SVGParseColor := $A52A2A
 Else If Temp = 'coral' Then SVGParseColor := $FF7F50
 Else If Temp = 'gold' Then SVGParseColor := $FFD700
 Else If Temp = 'lightgray' Then SVGParseColor := $D3D3D3
 Else If Temp = 'darkgray' Then SVGParseColor := $A9A9A9;
End;

{ Parser un nombre reel }
Function SVGParseNumber(Const S: String; Var Pos: Integer): Real;
Var
 Start: Integer;
 NumStr: String;
 Code: Integer;
 Value: Real;
Begin
 SVGParseNumber := 0.0;

 { Sauter les espaces et separateurs }
 While (Pos <= Length(S)) And (S[Pos] In [' ', ',', #9, #10, #13]) Do
  Inc(Pos);

 If Pos > Length(S) Then Exit;

 Start := Pos;

 { Signe optionnel }
 If (Pos <= Length(S)) And (S[Pos] In ['+', '-']) Then Inc(Pos);

 { Partie entiere }
 While (Pos <= Length(S)) And (S[Pos] In ['0'..'9']) Do Inc(Pos);

 { Partie decimale }
 If (Pos <= Length(S)) And (S[Pos] = '.') Then Begin
  Inc(Pos);
  While (Pos <= Length(S)) And (S[Pos] In ['0'..'9']) Do Inc(Pos);
 End;

 { Exposant }
 If (Pos <= Length(S)) And (S[Pos] In ['e', 'E']) Then Begin
  Inc(Pos);
  If (Pos <= Length(S)) And (S[Pos] In ['+', '-']) Then Inc(Pos);
  While (Pos <= Length(S)) And (S[Pos] In ['0'..'9']) Do Inc(Pos);
 End;

 NumStr := Copy(S, Start, Pos - Start);
 Val(NumStr, Value, Code);
 If Code = 0 Then SVGParseNumber := Value;
End;

{ Sauter les espaces }
Procedure SVGSkipWhitespace(Const S: String; Var Pos: Integer);
Begin
 While (Pos <= Length(S)) And (S[Pos] In [' ', ',', #9, #10, #13]) Do
  Inc(Pos);
End;

{ Appliquer une transformation a un point }
Procedure SVGTransformPoint(Const T: SVGTransform; Var P: SVGPoint);
Var
 NewX, NewY: Real;
Begin
 NewX := T.A * P.X + T.C * P.Y + T.E;
 NewY := T.B * P.X + T.D * P.Y + T.F;
 P.X := NewX;
 P.Y := NewY;
End;

{ Multiplier deux transformations }
Procedure SVGMultiplyTransform(Const T1, T2: SVGTransform; Var Result: SVGTransform);
Begin
 Result.A := T1.A * T2.A + T1.C * T2.B;
 Result.B := T1.B * T2.A + T1.D * T2.B;
 Result.C := T1.A * T2.C + T1.C * T2.D;
 Result.D := T1.B * T2.C + T1.D * T2.D;
 Result.E := T1.A * T2.E + T1.C * T2.F + T1.E;
 Result.F := T1.B * T2.E + T1.D * T2.F + T1.F;
End;

{ Dessiner une ligne avec transformation }
Procedure SVGDrawLine(X1, Y1, X2, Y2: Integer; Color: Byte;
                       OffsetX, OffsetY: Integer);
Var
 DX, DY, Steps, I: Integer;
 XInc, YInc: Real;
 X, Y: Real;
Begin
 If Color = 255 Then Exit; { Transparent }

 DX := X2 - X1;
 DY := Y2 - Y1;

 If Abs(DX) > Abs(DY) Then Steps := Abs(DX)
 Else Steps := Abs(DY);

 If Steps = 0 Then Begin
  PutPixel(OffsetX + X1, OffsetY + Y1, Color);
  Exit;
 End;

 XInc := DX / Steps;
 YInc := DY / Steps;
 X := X1;
 Y := Y1;

 For I := 0 To Steps Do Begin
  PutPixel(OffsetX + Round(X), OffsetY + Round(Y), Color);
  X := X + XInc;
  Y := Y + YInc;
 End;
End;

{ Dessiner un rectangle }
Procedure SVGDrawRect(X, Y, W, H: Integer; FillColor, StrokeColor: Byte;
                       OffsetX, OffsetY: Integer);
Var
 I, J: Integer;
Begin
 { Remplissage }
 If FillColor <> 255 Then Begin
  For J := Y To Y + H - 1 Do
   For I := X To X + W - 1 Do
    PutPixel(OffsetX + I, OffsetY + J, FillColor);
 End;

 { Contour }
 If StrokeColor <> 255 Then Begin
  { Haut et bas }
  For I := X To X + W - 1 Do Begin
   PutPixel(OffsetX + I, OffsetY + Y, StrokeColor);
   PutPixel(OffsetX + I, OffsetY + Y + H - 1, StrokeColor);
  End;
  { Gauche et droite }
  For J := Y To Y + H - 1 Do Begin
   PutPixel(OffsetX + X, OffsetY + J, StrokeColor);
   PutPixel(OffsetX + X + W - 1, OffsetY + J, StrokeColor);
  End;
 End;
End;

{ Dessiner un cercle (algorithme de Bresenham) }
Procedure SVGDrawCircle(CX, CY, R: Integer; FillColor, StrokeColor: Byte;
                         OffsetX, OffsetY: Integer);
Var
 X, Y, D: Integer;
 I: Integer;
Begin
 If R <= 0 Then Exit;

 { Remplissage par lignes horizontales }
 If FillColor <> 255 Then Begin
  For Y := -R To R Do Begin
   X := Round(Sqrt(R * R - Y * Y));
   For I := CX - X To CX + X Do
    PutPixel(OffsetX + I, OffsetY + CY + Y, FillColor);
  End;
 End;

 { Contour avec algorithme de Bresenham }
 If StrokeColor <> 255 Then Begin
  X := 0;
  Y := R;
  D := 3 - 2 * R;

  While X <= Y Do Begin
   PutPixel(OffsetX + CX + X, OffsetY + CY + Y, StrokeColor);
   PutPixel(OffsetX + CX - X, OffsetY + CY + Y, StrokeColor);
   PutPixel(OffsetX + CX + X, OffsetY + CY - Y, StrokeColor);
   PutPixel(OffsetX + CX - X, OffsetY + CY - Y, StrokeColor);
   PutPixel(OffsetX + CX + Y, OffsetY + CY + X, StrokeColor);
   PutPixel(OffsetX + CX - Y, OffsetY + CY + X, StrokeColor);
   PutPixel(OffsetX + CX + Y, OffsetY + CY - X, StrokeColor);
   PutPixel(OffsetX + CX - Y, OffsetY + CY - X, StrokeColor);

   If D < 0 Then
    D := D + 4 * X + 6
   Else Begin
    D := D + 4 * (X - Y) + 10;
    Dec(Y);
   End;
   Inc(X);
  End;
 End;
End;

{ Dessiner une ellipse }
Procedure SVGDrawEllipse(CX, CY, RX, RY: Integer; FillColor, StrokeColor: Byte;
                          OffsetX, OffsetY: Integer);
Var
 X, Y: Integer;
 XLen: Integer;
Begin
 If (RX <= 0) Or (RY <= 0) Then Exit;

 { Remplissage par lignes horizontales }
 If FillColor <> 255 Then Begin
  For Y := -RY To RY Do Begin
   XLen := Round(RX * Sqrt(1 - (Y * Y) / (RY * RY)));
   For X := CX - XLen To CX + XLen Do
    PutPixel(OffsetX + X, OffsetY + CY + Y, FillColor);
  End;
 End;

 { Contour approximatif }
 If StrokeColor <> 255 Then Begin
  For Y := -RY To RY Do Begin
   XLen := Round(RX * Sqrt(1 - (Y * Y) / (RY * RY)));
   PutPixel(OffsetX + CX - XLen, OffsetY + CY + Y, StrokeColor);
   PutPixel(OffsetX + CX + XLen, OffsetY + CY + Y, StrokeColor);
  End;
 End;
End;

{ Dessiner un polygone rempli (scanline) }
Procedure SVGDrawPolygon(Const Points: Array Of SVGPoint; Count: Integer;
                          FillColor, StrokeColor: Byte;
                          OffsetX, OffsetY: Integer);
Var
 MinY, MaxY, Y: Integer;
 I, J: Integer;
 X1, Y1, X2, Y2: Integer;
 Intersections: Array[0..255] Of Integer;
 IntCount: Integer;
 Temp: Integer;
Begin
 If Count < 3 Then Exit;

 { Trouver les bornes Y }
 MinY := Round(Points[0].Y);
 MaxY := MinY;
 For I := 1 To Count - 1 Do Begin
  If Round(Points[I].Y) < MinY Then MinY := Round(Points[I].Y);
  If Round(Points[I].Y) > MaxY Then MaxY := Round(Points[I].Y);
 End;

 { Remplissage par scanline }
 If FillColor <> 255 Then Begin
  For Y := MinY To MaxY Do Begin
   IntCount := 0;
   J := Count - 1;
   For I := 0 To Count - 1 Do Begin
    Y1 := Round(Points[J].Y);
    Y2 := Round(Points[I].Y);
    If ((Y1 <= Y) And (Y2 > Y)) Or ((Y2 <= Y) And (Y1 > Y)) Then Begin
     X1 := Round(Points[J].X);
     X2 := Round(Points[I].X);
     If IntCount < 256 Then Begin
      Intersections[IntCount] := X1 + ((Y - Y1) * (X2 - X1)) Div (Y2 - Y1);
      Inc(IntCount);
     End;
    End;
    J := I;
   End;

   { Trier les intersections }
   For I := 0 To IntCount - 2 Do
    For J := I + 1 To IntCount - 1 Do
     If Intersections[I] > Intersections[J] Then Begin
      Temp := Intersections[I];
      Intersections[I] := Intersections[J];
      Intersections[J] := Temp;
     End;

   { Remplir entre les paires d'intersections }
   I := 0;
   While I < IntCount - 1 Do Begin
    For J := Intersections[I] To Intersections[I + 1] Do
     PutPixel(OffsetX + J, OffsetY + Y, FillColor);
    Inc(I, 2);
   End;
  End;
 End;

 { Contour }
 If StrokeColor <> 255 Then Begin
  For I := 0 To Count - 1 Do Begin
   J := (I + 1) Mod Count;
   SVGDrawLine(Round(Points[I].X), Round(Points[I].Y),
               Round(Points[J].X), Round(Points[J].Y),
               StrokeColor, OffsetX, OffsetY);
  End;
 End;
End;

{ Parser les donnees d'un chemin SVG }
Procedure SVGParsePath(Const D: String; Var Points: Array Of SVGPoint;
                        Var PointCount: Integer);
Var
 Pos: Integer;
 Cmd: Char;
 IsRelative: Boolean;
 CurX, CurY: Real;
 StartX, StartY: Real;
 X, Y, X1, Y1, X2, Y2: Real;
 LastCmd: Char;
Begin
 PointCount := 0;
 Pos := 1;
 CurX := 0; CurY := 0;
 StartX := 0; StartY := 0;
 LastCmd := ' ';

 While Pos <= Length(D) Do Begin
  SVGSkipWhitespace(D, Pos);
  If Pos > Length(D) Then Break;

  { Lire la commande }
  If D[Pos] In ['M', 'm', 'L', 'l', 'H', 'h', 'V', 'v', 'C', 'c',
                'S', 's', 'Q', 'q', 'T', 't', 'A', 'a', 'Z', 'z'] Then Begin
   Cmd := D[Pos];
   Inc(Pos);
  End
  Else
   Cmd := LastCmd;

  IsRelative := Cmd In ['m', 'l', 'h', 'v', 'c', 's', 'q', 't', 'a', 'z'];
  Cmd := UpCase(Cmd);

  Case Cmd Of
   'M': Begin { MoveTo }
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     CurX := CurX + X;
     CurY := CurY + Y;
    End
    Else Begin
     CurX := X;
     CurY := Y;
    End;
    StartX := CurX;
    StartY := CurY;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := 'L'; { Suivants implicites = LineTo }
   End;

   'L': Begin { LineTo }
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     CurX := CurX + X;
     CurY := CurY + Y;
    End
    Else Begin
     CurX := X;
     CurY := Y;
    End;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'H': Begin { Horizontal LineTo }
    X := SVGParseNumber(D, Pos);
    If IsRelative Then CurX := CurX + X
    Else CurX := X;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'V': Begin { Vertical LineTo }
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then CurY := CurY + Y
    Else CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'C': Begin { Cubic Bezier - approximer par segments }
    X1 := SVGParseNumber(D, Pos);
    Y1 := SVGParseNumber(D, Pos);
    X2 := SVGParseNumber(D, Pos);
    Y2 := SVGParseNumber(D, Pos);
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     X1 := CurX + X1; Y1 := CurY + Y1;
     X2 := CurX + X2; Y2 := CurY + Y2;
     X := CurX + X; Y := CurY + Y;
    End;
    { Approximation lineaire du point final }
    CurX := X;
    CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'S': Begin { Smooth Cubic Bezier }
    X2 := SVGParseNumber(D, Pos);
    Y2 := SVGParseNumber(D, Pos);
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     X2 := CurX + X2; Y2 := CurY + Y2;
     X := CurX + X; Y := CurY + Y;
    End;
    CurX := X;
    CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'Q': Begin { Quadratic Bezier }
    X1 := SVGParseNumber(D, Pos);
    Y1 := SVGParseNumber(D, Pos);
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     X1 := CurX + X1; Y1 := CurY + Y1;
     X := CurX + X; Y := CurY + Y;
    End;
    CurX := X;
    CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'T': Begin { Smooth Quadratic Bezier }
    X := SVGParseNumber(D, Pos);
    Y := SVGParseNumber(D, Pos);
    If IsRelative Then Begin
     X := CurX + X; Y := CurY + Y;
    End;
    CurX := X;
    CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'A': Begin { Arc - approximer par ligne directe }
    { Sauter rx, ry, x-axis-rotation, large-arc-flag, sweep-flag }
    X1 := SVGParseNumber(D, Pos); { rx }
    Y1 := SVGParseNumber(D, Pos); { ry }
    X2 := SVGParseNumber(D, Pos); { x-axis-rotation }
    X := SVGParseNumber(D, Pos);  { large-arc-flag }
    Y := SVGParseNumber(D, Pos);  { sweep-flag }
    X := SVGParseNumber(D, Pos);  { x }
    Y := SVGParseNumber(D, Pos);  { y }
    If IsRelative Then Begin
     X := CurX + X; Y := CurY + Y;
    End;
    CurX := X;
    CurY := Y;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   'Z': Begin { ClosePath }
    CurX := StartX;
    CurY := StartY;
    If PointCount < SVG_MAX_POINTS Then Begin
     Points[PointCount].X := CurX;
     Points[PointCount].Y := CurY;
     Inc(PointCount);
    End;
    LastCmd := Cmd;
   End;

   Else Inc(Pos); { Caractere inconnu }
  End;
 End;
End;

{ Extraire un attribut d'un element XML }
Function SVGGetAttribute(Const Element, AttrName: String): String;
Var
 Pos, StartPos, EndPos: Integer;
 AttrLower: String;
 C: Char;
Begin
 SVGGetAttribute := '';
 AttrLower := HTMLLowerCase(AttrName) + '=';
 Pos := 1;

 While Pos <= Length(Element) Do Begin
  If HTMLLowerCase(Copy(Element, Pos, Length(AttrLower))) = AttrLower Then Begin
   Inc(Pos, Length(AttrLower));
   If Pos > Length(Element) Then Exit;
   C := Element[Pos];
   If C In ['"', ''''] Then Begin
    Inc(Pos);
    StartPos := Pos;
    While (Pos <= Length(Element)) And (Element[Pos] <> C) Do Inc(Pos);
    SVGGetAttribute := Copy(Element, StartPos, Pos - StartPos);
    Exit;
   End;
  End
  Else
   Inc(Pos);
 End;
End;

{ Charger une image SVG depuis un fichier }
Function SVGLoadFromFile(Const FileName: String; Var Img: SVGImage): Boolean;
Var
 F: Text;
 Line, Content, Element, TagName: String;
 Pos, TagStart, TagEnd: Integer;
 InTag: Boolean;
 CurElem: SVGElementPtr;
 Temp: String;
 Code: Integer;
 I: Integer;
Begin
 SVGLoadFromFile := False;
 Img.Valid := False;
 Img.ElementCount := 0;
 Img.Root := Nil;
 Img.Width := 100;
 Img.Height := 100;
 Img.HasViewBox := False;

 { Ouvrir le fichier }
 {$I-}
 Assign(F, FileName);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;

 { Lire tout le contenu }
 Content := '';
 While Not EOF(F) Do Begin
  ReadLn(F, Line);
  Content := Content + Line + ' ';
 End;
 Close(F);

 { Parser les elements SVG }
 Pos := 1;
 While Pos <= Length(Content) Do Begin
  { Chercher le debut d'un tag }
  TagStart := Pos;
  While (TagStart <= Length(Content)) And (Content[TagStart] <> '<') Do
   Inc(TagStart);
  If TagStart > Length(Content) Then Break;

  { Chercher la fin du tag }
  TagEnd := TagStart + 1;
  While (TagEnd <= Length(Content)) And (Content[TagEnd] <> '>') Do
   Inc(TagEnd);
  If TagEnd > Length(Content) Then Break;

  Element := Copy(Content, TagStart + 1, TagEnd - TagStart - 1);
  Pos := TagEnd + 1;

  { Ignorer les commentaires et declarations }
  If (Length(Element) > 0) And ((Element[1] = '!') Or (Element[1] = '?')) Then
   Continue;

  { Ignorer les tags de fermeture }
  If (Length(Element) > 0) And (Element[1] = '/') Then Continue;

  { Extraire le nom du tag }
  TagName := '';
  I := 1;
  While (I <= Length(Element)) And Not (Element[I] In [' ', '/', '>']) Do Begin
   TagName := TagName + Element[I];
   Inc(I);
  End;
  TagName := HTMLLowerCase(TagName);

  { Traiter les elements }
  If TagName = 'svg' Then Begin
   { Element racine SVG }
   Temp := SVGGetAttribute(Element, 'width');
   If Length(Temp) > 0 Then Begin
    Val(Temp, Img.Width, Code);
    If Code <> 0 Then Img.Width := 100;
   End;
   Temp := SVGGetAttribute(Element, 'height');
   If Length(Temp) > 0 Then Begin
    Val(Temp, Img.Height, Code);
    If Code <> 0 Then Img.Height := 100;
   End;
   Temp := SVGGetAttribute(Element, 'viewBox');
   If Length(Temp) > 0 Then Begin
    Img.HasViewBox := True;
    I := 1;
    Img.ViewBoxX := SVGParseNumber(Temp, I);
    Img.ViewBoxY := SVGParseNumber(Temp, I);
    Img.ViewBoxW := SVGParseNumber(Temp, I);
    Img.ViewBoxH := SVGParseNumber(Temp, I);
   End;
  End

  Else If (TagName = 'rect') And (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   CurElem^.ElemType := SVG_ELEM_RECT;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'x');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.X := SVGParseNumber(Temp, I); End
   Else CurElem^.X := 0;

   Temp := SVGGetAttribute(Element, 'y');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Y := SVGParseNumber(Temp, I); End
   Else CurElem^.Y := 0;

   Temp := SVGGetAttribute(Element, 'width');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Width := SVGParseNumber(Temp, I); End
   Else CurElem^.Width := 0;

   Temp := SVGGetAttribute(Element, 'height');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Height := SVGParseNumber(Temp, I); End
   Else CurElem^.Height := 0;

   Temp := SVGGetAttribute(Element, 'rx');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.RX := SVGParseNumber(Temp, I); End
   Else CurElem^.RX := 0;

   Temp := SVGGetAttribute(Element, 'ry');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.RY := SVGParseNumber(Temp, I); End
   Else CurElem^.RY := 0;

   Temp := SVGGetAttribute(Element, 'fill');
   If Length(Temp) > 0 Then CurElem^.Style.Fill := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke-width');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Style.StrokeWidth := SVGParseNumber(Temp, I); End;

   Inc(Img.ElementCount);
  End

  Else If (TagName = 'circle') And (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   CurElem^.ElemType := SVG_ELEM_CIRCLE;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'cx');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.X := SVGParseNumber(Temp, I); End
   Else CurElem^.X := 0;

   Temp := SVGGetAttribute(Element, 'cy');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Y := SVGParseNumber(Temp, I); End
   Else CurElem^.Y := 0;

   Temp := SVGGetAttribute(Element, 'r');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.RX := SVGParseNumber(Temp, I); End
   Else CurElem^.RX := 0;
   CurElem^.RY := CurElem^.RX;

   Temp := SVGGetAttribute(Element, 'fill');
   If Length(Temp) > 0 Then CurElem^.Style.Fill := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke-width');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Style.StrokeWidth := SVGParseNumber(Temp, I); End;

   Inc(Img.ElementCount);
  End

  Else If (TagName = 'ellipse') And (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   CurElem^.ElemType := SVG_ELEM_ELLIPSE;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'cx');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.X := SVGParseNumber(Temp, I); End
   Else CurElem^.X := 0;

   Temp := SVGGetAttribute(Element, 'cy');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Y := SVGParseNumber(Temp, I); End
   Else CurElem^.Y := 0;

   Temp := SVGGetAttribute(Element, 'rx');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.RX := SVGParseNumber(Temp, I); End
   Else CurElem^.RX := 0;

   Temp := SVGGetAttribute(Element, 'ry');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.RY := SVGParseNumber(Temp, I); End
   Else CurElem^.RY := 0;

   Temp := SVGGetAttribute(Element, 'fill');
   If Length(Temp) > 0 Then CurElem^.Style.Fill := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp);

   Inc(Img.ElementCount);
  End

  Else If (TagName = 'line') And (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   CurElem^.ElemType := SVG_ELEM_LINE;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'x1');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.X1 := SVGParseNumber(Temp, I); End
   Else CurElem^.X1 := 0;

   Temp := SVGGetAttribute(Element, 'y1');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Y1 := SVGParseNumber(Temp, I); End
   Else CurElem^.Y1 := 0;

   Temp := SVGGetAttribute(Element, 'x2');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.X2 := SVGParseNumber(Temp, I); End
   Else CurElem^.X2 := 0;

   Temp := SVGGetAttribute(Element, 'y2');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Y2 := SVGParseNumber(Temp, I); End
   Else CurElem^.Y2 := 0;

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp)
   Else CurElem^.Style.Stroke := 0; { Noir par defaut }

   Temp := SVGGetAttribute(Element, 'stroke-width');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Style.StrokeWidth := SVGParseNumber(Temp, I); End;

   Inc(Img.ElementCount);
  End

  Else If ((TagName = 'polygon') Or (TagName = 'polyline')) And
          (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   If TagName = 'polygon' Then CurElem^.ElemType := SVG_ELEM_POLYGON
   Else CurElem^.ElemType := SVG_ELEM_POLYLINE;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'points');
   If Length(Temp) > 0 Then Begin
    CurElem^.PointCount := 0;
    I := 1;
    While I <= Length(Temp) Do Begin
     SVGSkipWhitespace(Temp, I);
     If I > Length(Temp) Then Break;
     If CurElem^.PointCount < SVG_MAX_POINTS Then Begin
      CurElem^.Points[CurElem^.PointCount].X := SVGParseNumber(Temp, I);
      CurElem^.Points[CurElem^.PointCount].Y := SVGParseNumber(Temp, I);
      Inc(CurElem^.PointCount);
     End
     Else Break;
    End;
   End;

   Temp := SVGGetAttribute(Element, 'fill');
   If Length(Temp) > 0 Then CurElem^.Style.Fill := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp);

   Inc(Img.ElementCount);
  End

  Else If (TagName = 'path') And (Img.ElementCount < SVG_MAX_ELEMENTS) Then Begin
   CurElem := @Img.Elements[Img.ElementCount];
   CurElem^.ElemType := SVG_ELEM_PATH;
   SVGInitStyle(CurElem^.Style);
   SVGInitTransform(CurElem^.Transform);

   Temp := SVGGetAttribute(Element, 'd');
   If Length(Temp) > 0 Then
    SVGParsePath(Temp, CurElem^.Points, CurElem^.PointCount);

   Temp := SVGGetAttribute(Element, 'fill');
   If Length(Temp) > 0 Then CurElem^.Style.Fill := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke');
   If Length(Temp) > 0 Then CurElem^.Style.Stroke := SVGParseColor(Temp);

   Temp := SVGGetAttribute(Element, 'stroke-width');
   If Length(Temp) > 0 Then Begin I := 1; CurElem^.Style.StrokeWidth := SVGParseNumber(Temp, I); End;

   Inc(Img.ElementCount);
  End;
 End;

 Img.Valid := True;
 SVGLoadFromFile := True;
End;

{ Dessiner une image SVG }
Procedure SVGDrawImage(Const Img: SVGImage; DestX, DestY: Integer;
                        MaxWidth, MaxHeight: Integer);
Var
 I: Integer;
 Elem: SVGElementPtr;
 FillColor, StrokeColor: Byte;
 ScaleX, ScaleY: Real;
 X, Y, W, H, RX, RY: Integer;
 X1, Y1, X2, Y2: Integer;
Begin
 If Not Img.Valid Then Exit;

 { Calculer l'echelle }
 ScaleX := 1.0;
 ScaleY := 1.0;
 If Img.HasViewBox And (Img.ViewBoxW > 0) And (Img.ViewBoxH > 0) Then Begin
  ScaleX := MaxWidth / Img.ViewBoxW;
  ScaleY := MaxHeight / Img.ViewBoxH;
 End
 Else If (Img.Width > 0) And (Img.Height > 0) Then Begin
  ScaleX := MaxWidth / Img.Width;
  ScaleY := MaxHeight / Img.Height;
 End;

 { Dessiner chaque element }
 For I := 0 To Img.ElementCount - 1 Do Begin
  Elem := @Img.Elements[I];
  FillColor := SVGColorToVGA(Elem^.Style.Fill);
  StrokeColor := SVGColorToVGA(Elem^.Style.Stroke);

  Case Elem^.ElemType Of
   SVG_ELEM_RECT: Begin
    X := Round(Elem^.X * ScaleX);
    Y := Round(Elem^.Y * ScaleY);
    W := Round(Elem^.Width * ScaleX);
    H := Round(Elem^.Height * ScaleY);
    SVGDrawRect(X, Y, W, H, FillColor, StrokeColor, DestX, DestY);
   End;

   SVG_ELEM_CIRCLE: Begin
    X := Round(Elem^.X * ScaleX);
    Y := Round(Elem^.Y * ScaleY);
    RX := Round(Elem^.RX * ScaleX);
    SVGDrawCircle(X, Y, RX, FillColor, StrokeColor, DestX, DestY);
   End;

   SVG_ELEM_ELLIPSE: Begin
    X := Round(Elem^.X * ScaleX);
    Y := Round(Elem^.Y * ScaleY);
    RX := Round(Elem^.RX * ScaleX);
    RY := Round(Elem^.RY * ScaleY);
    SVGDrawEllipse(X, Y, RX, RY, FillColor, StrokeColor, DestX, DestY);
   End;

   SVG_ELEM_LINE: Begin
    X1 := Round(Elem^.X1 * ScaleX);
    Y1 := Round(Elem^.Y1 * ScaleY);
    X2 := Round(Elem^.X2 * ScaleX);
    Y2 := Round(Elem^.Y2 * ScaleY);
    SVGDrawLine(X1, Y1, X2, Y2, StrokeColor, DestX, DestY);
   End;

   SVG_ELEM_POLYGON, SVG_ELEM_PATH: Begin
    If Elem^.PointCount > 2 Then Begin
     { Appliquer l'echelle aux points }
     For X := 0 To Elem^.PointCount - 1 Do Begin
      Elem^.Points[X].X := Elem^.Points[X].X * ScaleX;
      Elem^.Points[X].Y := Elem^.Points[X].Y * ScaleY;
     End;
     SVGDrawPolygon(Elem^.Points, Elem^.PointCount,
                    FillColor, StrokeColor, DestX, DestY);
    End;
   End;

   SVG_ELEM_POLYLINE: Begin
    If Elem^.PointCount > 1 Then Begin
     For X := 0 To Elem^.PointCount - 2 Do Begin
      X1 := Round(Elem^.Points[X].X * ScaleX);
      Y1 := Round(Elem^.Points[X].Y * ScaleY);
      X2 := Round(Elem^.Points[X + 1].X * ScaleX);
      Y2 := Round(Elem^.Points[X + 1].Y * ScaleY);
      SVGDrawLine(X1, Y1, X2, Y2, StrokeColor, DestX, DestY);
     End;
    End;
   End;
  End;
 End;
End;

{ Dessiner une image SVG avec mise a l'echelle }
Procedure SVGDrawImageScaled(Const Img: SVGImage; DestX, DestY: Integer;
                              DestWidth, DestHeight: Integer);
Begin
 SVGDrawImage(Img, DestX, DestY, DestWidth, DestHeight);
End;

{ Chercher une image SVG dans le cache }
Function SVGFindInCache(Const URL: String): Integer;
Var
 I: Integer;
Begin
 SVGFindInCache := 0;
 For I := 1 To 16 Do Begin
  If SVGImageCache[I].Used And (SVGImageCache[I].URL = URL) Then Begin
   SVGFindInCache := I;
   Exit;
  End;
 End;
End;

{ Ajouter une image SVG au cache }
Function SVGAddToCache(Const URL: String; Const Img: SVGImage): Integer;
Var
 I: Integer;
 Slot: Integer;
Begin
 SVGAddToCache := 0;

 Slot := 0;
 For I := 1 To 16 Do Begin
  If Not SVGImageCache[I].Used Then Begin
   Slot := I;
   Break;
  End;
 End;

 If Slot = 0 Then Slot := 1; { Remplacer le premier }

 SVGImageCache[Slot].URL := URL;
 SVGImageCache[Slot].Image := Img;
 SVGImageCache[Slot].Used := True;
 SVGAddToCache := Slot;
End;

{ Construire le chemin complet d'une image SVG }
Function SVGBuildImagePath(Const Src: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 If (Length(Src) > 0) And ((Src[1] = '/') Or (Src[1] = '\') Or
     ((Length(Src) > 2) And (Src[2] = ':'))) Then Begin
  SVGBuildImagePath := Src;
  Exit;
 End;

 BasePath := CurrentURL;

 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 SVGBuildImagePath := BasePath + Src;
End;

{ =====================================================
  FIN PARSEUR ET RENDU SVG
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
 OldNoWrap: Boolean;
 OldTextAlignMode: Byte;
Begin
 If Node = Nil Then Exit;
 If Ctx.Y > Ctx.MaxY Then Exit; { Depasse la zone de rendu }

 { Sauvegarder le contexte actuel pour restauration apres le rendu }
 OldTextColor := Ctx.TextColor;
 OldBgColor := Ctx.BgColor;
 OldTextStyle := Ctx.TextStyle;
 OldNoWrap := Ctx.NoWrap;
 OldTextAlignMode := Ctx.TextAlignMode;

 { Par defaut (CSS desactive ou noeud texte) : comportement de bloc
   selon la balise seule, comme avant l'introduction du CSS. }
 NodeStyle.Display := '';
 CurrentElementWantsBlock := CSSIsBlockElement(NodeStyle, Node^.TagType);
 CurrentElementListStyleNone := False;
 CurrentElementBox.MarginTopPx := -1;
 CurrentElementBox.MarginBottomPx := -1;
 CurrentElementBox.PaddingTopPx := -1;
 CurrentElementBox.PaddingBottomPx := -1;
 CurrentElementBox.HasBorder := False;
 CurrentElementBox.HasBgBox := False;

 { Appliquer les styles CSS si active et si c'est un element }
 If CSSAutoApply And CSSEnabled And (Node^.NodeType = HTML_NODE_ELEMENT) Then Begin
  CSSResolveCascade(Node, NodeStyle);

  { Verifier si l'element doit etre cache }
  If CSSIsElementHidden(NodeStyle) Then Exit;

  { Appliquer les styles au contexte }
  CSSApplyStylesToContext(NodeStyle, Ctx);

  { display: en/in/inline-block calcule par cascade, en tenant compte
    du comportement par defaut de la balise si la propriete n'est pas
    explicitement fixee (voir CSSIsBlockElement). }
  CurrentElementWantsBlock := CSSIsBlockElement(NodeStyle, Node^.TagType);

  { list-style/list-style-type: none - puce supprimee (utilise par ex.
    pour les menus horizontaux construits avec <ul><li>). }
  CurrentElementListStyleNone :=
   (HTMLLowerCase(NodeStyle.ListStyleType) = 'none') Or
   (System.Pos('none', HTMLLowerCase(NodeStyle.ListStyle)) > 0);

  { Marges/padding/bordure/fond resolus en pixels pour cet element. }
  CurrentElementBox := ComputeElementBoxInfo(NodeStyle);
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

    { Images }
    TAG_IMG:      RenderTagImg(Node, Ctx);

    { NOSCRIPT - afficher le contenu si JavaScript est desactive }
    TAG_NOSCRIPT: Begin
     If Not JSEnabled Then RenderChildren(Node, Ctx);
    End;

    Else Begin
     { Balise non geree (ex: figure, figcaption, address, details,
       summary) - rendre les enfants, avec saut de ligne si la balise
       ou le CSS la considere comme un element de bloc. }
     If CurrentElementWantsBlock And
        (Ctx.X > RenderOriginX + RENDER_MARGIN_LEFT + (Ctx.BlockLevel * 10)) Then
      RenderNewLine(Ctx);
     RenderChildren(Node, Ctx);
     If CurrentElementWantsBlock Then
      RenderNewLine(Ctx);
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
  Ctx.NoWrap := OldNoWrap;
  Ctx.TextAlignMode := OldTextAlignMode;
 End;
End;

{ Declarations forward pour les barres de defilement (definies plus
  bas, avec les autres elements de l'interface comme les boutons). }
Procedure DrawVScrollBar; Forward;
Procedure DrawHScrollBar; Forward;

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
 ContentOverflowX := RENDER_AREA_X;
 RenderHTMLNode(Doc, Ctx);

 { Determiner s'il reste du contenu a reveler par defilement : Ctx.Y
   depasse le bas visible si la marge de mesure (SCROLL_MEASURE_MARGIN)
   a rencontre du contenu au-dela de la zone visible. }
 CanScrollDown := Ctx.Y > (RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE));
 CanScrollUp := ScrollY > 0;
 CanScrollRight := ContentOverflowX > (RENDER_AREA_X + (RENDER_AREA_WIDTH - SCROLLBAR_SIZE));
 CanScrollLeft := ScrollX > 0;

 DrawVScrollBar;
 DrawHScrollBar;
End;

{ Procedure pour tester le rendu avec du HTML }
Procedure TestHTMLRender(Const HTMLSource: HTMLSourceBuffer);
Var
 Doc: HTMLNodePtr;
Begin
 Doc := ParseHTML(HTMLSource);
 If Doc <> Nil Then Begin
  { Conserver l'arbre du document (au lieu de le liberer immediatement)
    pour pouvoir le re-rendre sans reparser a chaque defilement, et
    pour que DOMGetElementById/... (acces DOM depuis JS) trouvent un
    document valide. L'ancien arbre est libere ici, juste avant d etre
    remplace. }
  If HTMLDocument <> Nil Then FreeHTMLNode(HTMLDocument);
  HTMLDocument := Doc;
  ScrollX := 0;
  ScrollY := 0;
  RenderHTMLDocument(HTMLDocument);
 End;
End;

{ Procedure pour re-rendre la page courante apres un changement de
  defilement, sans reparser le HTML. }
Procedure RescrollPage;
Begin
 If HTMLDocument = Nil Then Exit;
 RenderHTMLDocument(HTMLDocument);
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

{ =====================================================
  BARRES DE DEFILEMENT DE LA ZONE DE RENDU
  ===================================================== }

{ --- Geometrie de la barre verticale --- }
Function VScrollX1: Integer;
Begin VScrollX1 := RENDER_AREA_X + RENDER_AREA_WIDTH - SCROLLBAR_SIZE; End;
Function VScrollX2: Integer;
Begin VScrollX2 := RENDER_AREA_X + RENDER_AREA_WIDTH; End;
Function VScrollTrackY1: Integer;
Begin VScrollTrackY1 := RENDER_AREA_Y + SCROLLBAR_SIZE; End;
Function VScrollTrackY2: Integer;
Begin VScrollTrackY2 := RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE) - SCROLLBAR_SIZE; End;

{ --- Geometrie de la barre horizontale --- }
Function HScrollY1: Integer;
Begin HScrollY1 := RENDER_AREA_Y + RENDER_AREA_HEIGHT - SCROLLBAR_SIZE; End;
Function HScrollY2: Integer;
Begin HScrollY2 := RENDER_AREA_Y + RENDER_AREA_HEIGHT; End;
Function HScrollTrackX1: Integer;
Begin HScrollTrackX1 := RENDER_AREA_X + SCROLLBAR_SIZE; End;
Function HScrollTrackX2: Integer;
Begin HScrollTrackX2 := RENDER_AREA_X + (RENDER_AREA_WIDTH - SCROLLBAR_SIZE) - SCROLLBAR_SIZE; End;

{ Procedure pour dessiner la barre de defilement verticale (fleches
  haut/bas et poignee proportionnelle a l'avancement). }
Procedure DrawVScrollBar;
Var
 TrackH, ThumbH, ThumbY, Range, ArrowColor: Integer;
 CenterX, CenterY: Integer;
Begin
 { Fond de la barre }
 SetFillStyle(SolidFill, COLOR_URL_BAR_BG);
 Bar(VScrollX1, RENDER_AREA_Y, VScrollX2, RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE));
 SetColor(COLOR_BTN_BORDER);
 Rectangle(VScrollX1, RENDER_AREA_Y, VScrollX2, RENDER_AREA_Y + (RENDER_AREA_HEIGHT - SCROLLBAR_SIZE));

 { Bouton fleche du haut }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(VScrollX1, RENDER_AREA_Y, VScrollX2, RENDER_AREA_Y + SCROLLBAR_SIZE);
 Rectangle(VScrollX1, RENDER_AREA_Y, VScrollX2, RENDER_AREA_Y + SCROLLBAR_SIZE);
 CenterX := (VScrollX1 + VScrollX2) Div 2;
 CenterY := RENDER_AREA_Y + (SCROLLBAR_SIZE Div 2);
 If CanScrollUp Then ArrowColor := COLOR_BTN_TEXT Else ArrowColor := COLOR_BTN_DISABLED;
 SetColor(ArrowColor);
 Line(CenterX, CenterY - 4, CenterX - 4, CenterY + 3);
 Line(CenterX, CenterY - 4, CenterX + 4, CenterY + 3);

 { Bouton fleche du bas }
 CenterY := VScrollTrackY2 + (SCROLLBAR_SIZE Div 2);
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(VScrollX1, VScrollTrackY2, VScrollX2, VScrollTrackY2 + SCROLLBAR_SIZE);
 SetColor(COLOR_BTN_BORDER);
 Rectangle(VScrollX1, VScrollTrackY2, VScrollX2, VScrollTrackY2 + SCROLLBAR_SIZE);
 If CanScrollDown Then ArrowColor := COLOR_BTN_TEXT Else ArrowColor := COLOR_BTN_DISABLED;
 SetColor(ArrowColor);
 Line(CenterX, CenterY + 4, CenterX - 4, CenterY - 3);
 Line(CenterX, CenterY + 4, CenterX + 4, CenterY - 3);

 { Poignee : taille et position proportionnelles a ScrollY et a ce
   qui reste mesurable (CanScrollDown). Approximation raisonnable :
   on ne connait pas la hauteur totale exacte du document (le rendu
   s'arrete d'explorer au-dela d'une marge de mesure pour rester
   rapide), seulement s'il reste du contenu sous le pli. }
 TrackH := VScrollTrackY2 - VScrollTrackY1;
 If TrackH < SCROLLBAR_MIN_THUMB Then Exit;
 If CanScrollUp Or CanScrollDown Then Begin
  Range := ScrollY;
  If CanScrollDown Then Inc(Range, TrackH) { encore de la place plus bas } ;
  If Range <= 0 Then Range := 1;
  ThumbH := (TrackH * TrackH) Div Range;
  If ThumbH > TrackH Then ThumbH := TrackH;
  If ThumbH < SCROLLBAR_MIN_THUMB Then ThumbH := SCROLLBAR_MIN_THUMB;
  ThumbY := VScrollTrackY1 + ((TrackH - ThumbH) * ScrollY) Div Range;
  If ThumbY + ThumbH > VScrollTrackY2 Then ThumbY := VScrollTrackY2 - ThumbH;
 End Else Begin
  ThumbH := TrackH;
  ThumbY := VScrollTrackY1;
 End;
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(VScrollX1 + 2, ThumbY, VScrollX2 - 2, ThumbY + ThumbH);
 SetColor(COLOR_BTN_BORDER);
 Rectangle(VScrollX1 + 2, ThumbY, VScrollX2 - 2, ThumbY + ThumbH);
End;

{ Procedure pour dessiner la barre de defilement horizontale }
Procedure DrawHScrollBar;
Var
 TrackW, ThumbW, ThumbX, Range, ArrowColor: Integer;
 CenterX, CenterY: Integer;
Begin
 SetFillStyle(SolidFill, COLOR_URL_BAR_BG);
 Bar(RENDER_AREA_X, HScrollY1, RENDER_AREA_X + (RENDER_AREA_WIDTH - SCROLLBAR_SIZE), HScrollY2);
 SetColor(COLOR_BTN_BORDER);
 Rectangle(RENDER_AREA_X, HScrollY1, RENDER_AREA_X + (RENDER_AREA_WIDTH - SCROLLBAR_SIZE), HScrollY2);

 { Bouton fleche gauche }
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(RENDER_AREA_X, HScrollY1, RENDER_AREA_X + SCROLLBAR_SIZE, HScrollY2);
 Rectangle(RENDER_AREA_X, HScrollY1, RENDER_AREA_X + SCROLLBAR_SIZE, HScrollY2);
 CenterX := RENDER_AREA_X + (SCROLLBAR_SIZE Div 2);
 CenterY := (HScrollY1 + HScrollY2) Div 2;
 If CanScrollLeft Then ArrowColor := COLOR_BTN_TEXT Else ArrowColor := COLOR_BTN_DISABLED;
 SetColor(ArrowColor);
 Line(CenterX - 4, CenterY, CenterX + 3, CenterY - 4);
 Line(CenterX - 4, CenterY, CenterX + 3, CenterY + 4);

 { Bouton fleche droite }
 CenterX := HScrollTrackX2 + (SCROLLBAR_SIZE Div 2);
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(HScrollTrackX2, HScrollY1, HScrollTrackX2 + SCROLLBAR_SIZE, HScrollY2);
 SetColor(COLOR_BTN_BORDER);
 Rectangle(HScrollTrackX2, HScrollY1, HScrollTrackX2 + SCROLLBAR_SIZE, HScrollY2);
 If CanScrollRight Then ArrowColor := COLOR_BTN_TEXT Else ArrowColor := COLOR_BTN_DISABLED;
 SetColor(ArrowColor);
 Line(CenterX + 4, CenterY, CenterX - 3, CenterY - 4);
 Line(CenterX + 4, CenterY, CenterX - 3, CenterY + 4);

 { Poignee horizontale }
 TrackW := HScrollTrackX2 - HScrollTrackX1;
 If TrackW < SCROLLBAR_MIN_THUMB Then Exit;
 If CanScrollLeft Or CanScrollRight Then Begin
  Range := ScrollX;
  If CanScrollRight Then Inc(Range, TrackW);
  If Range <= 0 Then Range := 1;
  ThumbW := (TrackW * TrackW) Div Range;
  If ThumbW > TrackW Then ThumbW := TrackW;
  If ThumbW < SCROLLBAR_MIN_THUMB Then ThumbW := SCROLLBAR_MIN_THUMB;
  ThumbX := HScrollTrackX1 + ((TrackW - ThumbW) * ScrollX) Div Range;
  If ThumbX + ThumbW > HScrollTrackX2 Then ThumbX := HScrollTrackX2 - ThumbW;
 End Else Begin
  ThumbW := TrackW;
  ThumbX := HScrollTrackX1;
 End;
 SetFillStyle(SolidFill, COLOR_BTN_BG);
 Bar(ThumbX, HScrollY1 + 2, ThumbX + ThumbW, HScrollY2 - 2);
 SetColor(COLOR_BTN_BORDER);
 Rectangle(ThumbX, HScrollY1 + 2, ThumbX + ThumbW, HScrollY2 - 2);
End;

{ --- Detection de clic sur les elements des barres de defilement --- }
Function IsClickInVScrollUp(X, Y: Integer): Boolean;
Begin
 IsClickInVScrollUp := (X >= VScrollX1) And (X <= VScrollX2) And
                       (Y >= RENDER_AREA_Y) And (Y <= RENDER_AREA_Y + SCROLLBAR_SIZE);
End;

Function IsClickInVScrollDown(X, Y: Integer): Boolean;
Begin
 IsClickInVScrollDown := (X >= VScrollX1) And (X <= VScrollX2) And
                         (Y >= VScrollTrackY2) And (Y <= VScrollTrackY2 + SCROLLBAR_SIZE);
End;

Function IsClickInVScrollTrack(X, Y: Integer): Boolean;
Begin
 IsClickInVScrollTrack := (X >= VScrollX1) And (X <= VScrollX2) And
                          (Y > RENDER_AREA_Y + SCROLLBAR_SIZE) And (Y < VScrollTrackY2);
End;

Function IsClickInHScrollLeft(X, Y: Integer): Boolean;
Begin
 IsClickInHScrollLeft := (Y >= HScrollY1) And (Y <= HScrollY2) And
                         (X >= RENDER_AREA_X) And (X <= RENDER_AREA_X + SCROLLBAR_SIZE);
End;

Function IsClickInHScrollRight(X, Y: Integer): Boolean;
Begin
 IsClickInHScrollRight := (Y >= HScrollY1) And (Y <= HScrollY2) And
                          (X >= HScrollTrackX2) And (X <= HScrollTrackX2 + SCROLLBAR_SIZE);
End;

Function IsClickInHScrollTrack(X, Y: Integer): Boolean;
Begin
 IsClickInHScrollTrack := (Y >= HScrollY1) And (Y <= HScrollY2) And
                          (X > RENDER_AREA_X + SCROLLBAR_SIZE) And (X < HScrollTrackX2);
End;

{ --- Defilement effectif : ajuste ScrollX/ScrollY puis re-rend la
  page courante (sans reparser le HTML). --- }
Procedure ScrollPageBy(DX, DY: Integer);
Begin
 If (DY < 0) And (ScrollY > 0) Then Begin
  ScrollY := ScrollY + DY;
  If ScrollY < 0 Then ScrollY := 0;
 End Else If (DY > 0) And CanScrollDown Then
  ScrollY := ScrollY + DY;

 If (DX < 0) And (ScrollX > 0) Then Begin
  ScrollX := ScrollX + DX;
  If ScrollX < 0 Then ScrollX := 0;
 End Else If (DX > 0) And CanScrollRight Then
  ScrollX := ScrollX + DX;

 RescrollPage;
End;

{ Procedure pour gerer un clic dans la barre verticale }
Procedure HandleVScrollClick(X, Y: Integer);
Var
 PageStep: Integer;
Begin
 PageStep := RENDER_AREA_HEIGHT - SCROLLBAR_SIZE;
 If IsClickInVScrollUp(X, Y) Then
  ScrollPageBy(0, -SCROLL_LINE_STEP)
 Else If IsClickInVScrollDown(X, Y) Then
  ScrollPageBy(0, SCROLL_LINE_STEP)
 Else If IsClickInVScrollTrack(X, Y) Then Begin
  If Y < VScrollTrackY1 + ((VScrollTrackY2 - VScrollTrackY1) Div 2) Then
   ScrollPageBy(0, -PageStep)
  Else
   ScrollPageBy(0, PageStep);
 End;
End;

{ Procedure pour gerer un clic dans la barre horizontale }
Procedure HandleHScrollClick(X, Y: Integer);
Var
 PageStep: Integer;
Begin
 PageStep := RENDER_AREA_WIDTH - SCROLLBAR_SIZE;
 If IsClickInHScrollLeft(X, Y) Then
  ScrollPageBy(-SCROLL_LINE_STEP, 0)
 Else If IsClickInHScrollRight(X, Y) Then
  ScrollPageBy(SCROLL_LINE_STEP, 0)
 Else If IsClickInHScrollTrack(X, Y) Then Begin
  If X < HScrollTrackX1 + ((HScrollTrackX2 - HScrollTrackX1) Div 2) Then
   ScrollPageBy(-PageStep, 0)
  Else
   ScrollPageBy(PageStep, 0);
 End;
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

Procedure InitHTMLSource(Var HTML: HTMLSourceBuffer);
Begin
 HTML.FirstChunk := Nil;
 HTML.LastChunk := Nil;
 HTML.DataLength := 0;
End;

Procedure FreeHTMLSource(Var HTML: HTMLSourceBuffer);
Var
 Chunk, NextChunk: HTMLBufferChunkPtr;
Begin
 Chunk := HTML.FirstChunk;
 While Chunk <> Nil Do Begin
  NextChunk := Chunk^.Next;
  Dispose(Chunk);
  Chunk := NextChunk;
 End;
 HTML.FirstChunk := Nil;
 HTML.LastChunk := Nil;
 HTML.DataLength := 0;
End;

Function SetHTMLSourceFromString(Const S: String;
                                 Var HTML: HTMLSourceBuffer): Boolean;
Var
 I, CopyCount: Integer;
 Chunk: HTMLBufferChunkPtr;
Begin
 FreeHTMLSource(HTML);
 SetHTMLSourceFromString := False;
 If Length(S) = 0 Then Exit;
 I := 1;
 While I <= Length(S) Do Begin
  New(Chunk);
  Chunk^.Used := 0;
  Chunk^.Next := Nil;
  CopyCount := Length(S) - I + 1;
  If CopyCount > 4096 Then CopyCount := 4096;
  While Chunk^.Used < CopyCount Do Begin
   Chunk^.Data[Chunk^.Used] := S[I + Chunk^.Used];
   Inc(Chunk^.Used);
  End;
  If HTML.LastChunk = Nil Then HTML.FirstChunk := Chunk
  Else HTML.LastChunk^.Next := Chunk;
  HTML.LastChunk := Chunk;
  Inc(HTML.DataLength, CopyCount);
  Inc(I, CopyCount);
 End;
 SetHTMLSourceFromString := True;
End;

{ Lecture binaire par blocs chaines, sans segment contigu de 64 Ko. }
Function LoadHTMLFile(Const FileName: String; Var HTML: HTMLSourceBuffer): Boolean;
Var
 F: File;
 BytesRead: Word;
 Chunk: HTMLBufferChunkPtr;
Begin
 FreeHTMLSource(HTML);
 LoadHTMLFile := False;
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult <> 0 Then Exit;

 Repeat
  New(Chunk);
  Chunk^.Used := 0;
  Chunk^.Next := Nil;
  BlockRead(F, Chunk^.Data, 4096, BytesRead);
  If BytesRead > 0 Then Begin
   Chunk^.Used := BytesRead;
   If HTML.LastChunk = Nil Then HTML.FirstChunk := Chunk
   Else HTML.LastChunk^.Next := Chunk;
   HTML.LastChunk := Chunk;
   Inc(HTML.DataLength, BytesRead);
  End
  Else
   Dispose(Chunk);
 Until BytesRead < 4096;
 Close(F);
 LoadHTMLFile := HTML.DataLength > 0;
End;

Function IsRemoteURL(Const URL: String): Boolean;
Var
 LowerURL: String;
Begin
 LowerURL := HTMLLowerCase(URL);
 IsRemoteURL := (Copy(LowerURL, 1, 7) = 'http://') Or
                (Copy(LowerURL, 1, 8) = 'https://');
End;

{ Charger et afficher la cible courante. }
Procedure DisplayCurrentTarget;
Var
 HTML: HTMLSourceBuffer;
 FileName: String;
 MessageText: String;
Begin
 InitHTMLSource(HTML);
 If IsRemoteURL(CurrentURL) Then Begin
  MessageText := '<html><body><h2>Adresse URL</h2><p>' + CurrentURL +
                 '</p><p>Le telechargement HTTP/HTTPS n''est pas encore implemente.</p></body></html>';
  If SetHTMLSourceFromString(MessageText, HTML) Then
   TestHTMLRender(HTML);
  FreeHTMLSource(HTML);
  Exit;
 End;

 FileName := CurrentURL;
 If Copy(HTMLLowerCase(FileName), 1, 7) = 'file://' Then
  Delete(FileName, 1, 7);

 If LoadHTMLFile(FileName, HTML) Then
  TestHTMLRender(HTML)
 Else Begin
  MessageText := '<html><body><h2>Erreur</h2><p>Impossible d''ouvrir le fichier : ' +
                 FileName + '</p></body></html>';
  If SetHTMLSourceFromString(MessageText, HTML) Then
   TestHTMLRender(HTML);
 End;
 FreeHTMLSource(HTML);
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
 DisplayCurrentTarget;
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
  DisplayCurrentTarget;
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
  DisplayCurrentTarget;
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
 If Not URLBarFocused Then Begin
  { La barre d'URL n'a pas le focus : les touches de navigation
    defilent la page plutot que de deplacer un curseur de texte. }
  Case ScanCode Of
   72: ScrollPageBy(0, -SCROLL_LINE_STEP);                      { Fleche haut }
   80: ScrollPageBy(0, SCROLL_LINE_STEP);                       { Fleche bas }
   75: ScrollPageBy(-SCROLL_LINE_STEP, 0);                      { Fleche gauche }
   77: ScrollPageBy(SCROLL_LINE_STEP, 0);                       { Fleche droite }
   73: ScrollPageBy(0, -(RENDER_AREA_HEIGHT - SCROLLBAR_SIZE)); { Page haut }
   81: ScrollPageBy(0, RENDER_AREA_HEIGHT - SCROLLBAR_SIZE);    { Page bas }
  End;
  Exit;
 End;

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

{ --- Choisir le pilote/mode graphique selon -maxscreen : voir
  DEVENV.PAS/SelectScreenDriverMode pour le detail. Detect choisirait
  le pilote couleur le plus profond (15/16 bits), ou les indices de
  palette EGA/VGA 1..15 sont alors interpretes comme des valeurs RGB
  brutes au lieu de couleurs Noir/Bleu/Vert/.../Jaune/Blanc. On force
  donc le pilote 256 couleurs (palette VGA standard) a sa plus haute
  resolution, ce qui conserve la palette correcte. }
Procedure SelectScreenDriverMode(WantMaxScreen: Boolean;
 Var Driver, Mode: Integer);
Var
 LoMode, HiMode: SmallInt;
Begin
 {$IFDEF FPC}
  If(WantMaxScreen)Then Begin
   Driver := D8bit;
   GetModeRange(Driver, LoMode, HiMode);
   If HiMode >= LoMode Then
    Mode := HiMode
   Else Begin
    Driver := Detect;
    Mode := 0;
   End;
  End
   Else
  Begin
   Driver := VGA;
   Mode := VGAHi;
  End;
 {$ELSE}
  Driver := Detect;
  Mode := VGAHi;
 {$ENDIF}
End;

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 SelectScreenDriverMode(MaxScreen, Driver, Mode);
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
  { Zone de rendu = espace reellement disponible apres la barre d'URL,
    et non plus une taille figee pour 640x480 : sans cela, le mode
    -maxscreen ouvrait un grand ecran mais ne dessinait le contenu
    HTML que dans son coin superieur gauche. }
  RENDER_AREA_WIDTH := GetMaxX - RENDER_AREA_X - 5;
  RENDER_AREA_HEIGHT := GetMaxY - RENDER_AREA_Y - 5;
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
  MouseDriverFound := PtcMouse.InitMouse;
 End;

 Procedure ShowMouse;
 Begin
  PtcMouse.ShowMouse;
 End;

 Procedure HideMouse;
 Begin
  PtcMouse.HideMouse;
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Begin
  PtcMouse.GetMouseState(X, Y, Button);
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
  PtcMouse.SetMousePos(X, Y);
  PtcMouseLastX := X;
  PtcMouseLastY := Y;
 End;

 Function GetMouseLeftClicks: Integer;
 Var
  X, Y, Buttons: LongInt;
 Begin
  { Detecter les clics via l'etat des boutons }
  PtcMouse.GetMouseState(X, Y, Buttons);
  If (Buttons And PtcMouse.LButton) <> 0 Then Begin
   Inc(PtcMouseLeftClickCount);
   GetMouseLeftClicks := PtcMouseLeftClickCount;
  End
   Else
  GetMouseLeftClicks := 0;
 End;

 Function GetMouseRightClicks: Integer;
 Var
  X, Y, Buttons: LongInt;
 Begin
  { Detecter les clics via l'etat des boutons }
  PtcMouse.GetMouseState(X, Y, Buttons);
  If (Buttons And PtcMouse.RButton) <> 0 Then Begin
   Inc(PtcMouseRightClickCount);
   GetMouseRightClicks := PtcMouseRightClickCount;
  End
   Else
  GetMouseRightClicks := 0;
 End;

 Procedure GetMouseMotion(Var DeltaX, DeltaY: Integer);
 Var
  CurrentX, CurrentY, Buttons: LongInt;
 Begin
  { Calculer le deplacement depuis la derniere position }
  PtcMouse.GetMouseState(CurrentX, CurrentY, Buttons);
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
{ Resoudre un href relatif (ex: "A86/reference.htm") par rapport au
  repertoire de la page courante - meme principe que BMPBuildImagePath
  pour les images et CSSBuildStylesheetPath pour les feuilles de
  style, qui souffraient du meme probleme avant d'etre corriges : sans
  cette resolution, un lien relatif est cherche par rapport au
  repertoire de travail du PROCESSUS (celui ou BROWSER.exe a ete
  lance), pas par rapport a la page actuellement affichee. }
Function ResolveLinkHref(Const Href: String): String;
Var
 BasePath: String;
 I: Integer;
Begin
 { Chemin deja absolu (autre lecteur, ou commence par / ou \) : le
   retourner tel quel. }
 If (Length(Href) > 0) And ((Href[1] = '/') Or (Href[1] = '\') Or
     ((Length(Href) > 2) And (Href[2] = ':'))) Then Begin
  ResolveLinkHref := Href;
  Exit;
 End;

 BasePath := CurrentURL;
 For I := Length(BasePath) DownTo 1 Do Begin
  If BasePath[I] In ['/', '\'] Then Begin
   BasePath := Copy(BasePath, 1, I);
   Break;
  End;
 End;

 ResolveLinkHref := BasePath + Href;
End;

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
  { URL relative - combiner avec le repertoire de la page courante
    (ex: "A86/reference.htm" depuis une page situee dans CODER/ doit
    pointer vers CODER/A86/reference.htm, pas vers le repertoire de
    travail du processus). }
  NavigateTo(ResolveLinkHref(TargetURL));
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

 { Verifier si le clic est dans l'une des barres de defilement }
 HandleVScrollClick(X, Y);
 HandleHScrollClick(X, Y);

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

Procedure WriteConsoleLine(Const S: String);
Begin
 {$IFDEF FPC}
 WriteLn(StdErr, S);
 {$ELSE}
 WriteLn(S);
 {$ENDIF}
End;

Procedure PrintUsage;
Begin
 WriteConsoleLine('BROWSER 1.00 - Navigateur Web graphique');
 WriteConsoleLine('Build: ' + BROWSER_BUILD_ID);
 WriteConsoleLine('');
 WriteConsoleLine('Usage:');
 WriteConsoleLine('  BROWSER [URL|FICHIER]');
 WriteConsoleLine('  BROWSER URL <adresse>');
 WriteConsoleLine('  BROWSER FILE <fichier.html>');
 WriteConsoleLine('');
 WriteConsoleLine('Options:');
 WriteConsoleLine('  /?, /H, -h, --help       Afficher cette aide');
 WriteConsoleLine('  /URL, -u, --url URL      Ouvrir une adresse HTTP ou HTTPS');
 WriteConsoleLine('  /FILE, -f, --file FILE   Ouvrir un fichier HTML local');
 WriteConsoleLine('  /TEST FILE               Charger, rendre, confirmer puis quitter');
 WriteConsoleLine('  -maxscreen               Ouvrir le navigateur en plein ecran');
 WriteConsoleLine('');
 WriteConsoleLine('Exemples:');
 WriteConsoleLine('  BROWSER https://www.example.com/');
 WriteConsoleLine('  BROWSER FILE index.html');
End;

Function IsHelpParameter(Const S: String): Boolean;
Var
 P: String;
Begin
 P := HTMLLowerCase(S);
 IsHelpParameter := (P = '/?') Or (P = '/h') Or
                    (P = '-h') Or (P = '--help');
End;

Function IsURLParameter(Const S: String): Boolean;
Var
 P: String;
Begin
 P := HTMLLowerCase(S);
 IsURLParameter := (P = 'url') Or (P = '/url') Or
                   (P = '-u') Or (P = '--url');
End;

Function IsFileParameter(Const S: String): Boolean;
Var
 P: String;
Begin
 P := HTMLLowerCase(S);
 IsFileParameter := (P = 'file') Or (P = '/file') Or
                    (P = '-f') Or (P = '--file');
End;

Procedure ParseCommandLine(Var InitialTarget: String; Var TestMode: Boolean);
Var
 FirstParam, LowerParam: String;
 Args: Array[1..20] Of String;
 ArgCount, I: Integer;
Begin
 InitialTarget := 'https://';
 TestMode := False;
 MaxScreen := False;

 { Extraire -maxscreen de la ligne de commande, ou qu'il apparaisse,
   et conserver les autres arguments dans leur ordre d'origine (meme
   principe que DEVENV.PAS). }
 ArgCount := 0;
 For I := 1 To System.ParamCount Do Begin
  If HTMLLowerCase(ParamStr(I)) = '-maxscreen' Then
   MaxScreen := True
  Else If ArgCount < 20 Then Begin
   Inc(ArgCount);
   Args[ArgCount] := ParamStr(I);
  End;
 End;

 If ArgCount = 0 Then Exit;

 FirstParam := Args[1];
 LowerParam := HTMLLowerCase(FirstParam);
 If IsHelpParameter(FirstParam) Then Begin
  PrintUsage;
  Halt;
 End;

 If (LowerParam = 'test') Or (LowerParam = '/test') Or
    (LowerParam = '--test') Then Begin
  If ArgCount < 2 Then Begin
   WriteConsoleLine('Erreur: un nom de fichier est requis pour /TEST.');
   Halt(1);
  End;
  InitialTarget := Args[2];
  TestMode := True;
  Exit;
 End;

 If IsURLParameter(FirstParam) Or IsFileParameter(FirstParam) Then Begin
  If ArgCount < 2 Then Begin
   WriteConsoleLine('Erreur: une URL ou un nom de fichier est requis.');
   WriteConsoleLine('Utilisez BROWSER /? pour afficher l''aide.');
   Halt(1);
  End;
  InitialTarget := Args[2];
  Exit;
 End;

 { Un premier argument sans option est directement une URL ou un fichier. }
 InitialTarget := FirstParam;
End;

Var
 Key: Char;
 InitialTarget: String;
 TestMode: Boolean;

BEGIN
 ParseCommandLine(InitialTarget, TestMode);
 InitializeGraphics;
 InitURLBar;
 SetURL(InitialTarget);
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
 If TestMode Then Begin
  { Re-naviguer vers la meme page pour exercer un second appel a
    CSSParseStylesheet alors que la table de regles est deja pleine
    (cas reel d'un clic sur un lien apres le chargement d'une 1ere
    page) : c'est ce second appel qui a revele le debordement 16 bits
    de Pos corrige ci-dessus. }
  NavigateTo(CurrentURL);
  { Valider aussi les operations executees uniquement par le mode normal. }
  ProcessMouseInput;
  { Exercer le defilement (bas/droite puis haut/gauche) pour detecter
    toute exception dans RescrollPage/DrawVScrollBar/DrawHScrollBar. }
  ScrollPageBy(0, SCROLL_LINE_STEP);
  ScrollPageBy(SCROLL_LINE_STEP, 0);
  ScrollPageBy(0, -SCROLL_LINE_STEP);
  ScrollPageBy(-SCROLL_LINE_STEP, 0);
  WriteConsoleLine('Build ' + BROWSER_BUILD_ID +
                   ': chargement, rendu et interface termines sans exception.');
  If MouseAvailable Then HideMouse;
  CloseGraph;
  Halt;
 End;
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
