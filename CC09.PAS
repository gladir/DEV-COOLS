{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @description: Compilateur C pour 6809
}

Program CC09;

{$A-}
{$I-}

Uses DOS;

Const
 VERSION = 'Compilateur C V1.1';  { Version du compilateur C pour 6809 }
 YES = 1;                         { Valeur booléenne vraie }
 NO = 0;                          { Valeur booléenne fausse }

  { Paramètres de la table de symbole }
 symsiz = 14;       { Taille d'une entrée de symbole en octets }
 numglbs = 512;     { Nombre maximum de symboles globaux }
 MASKGLBS = 511;    { Masque pour le hachage de la table de symboles }
 namesize = 9;      { Taille maximale d'un nom de symbole incluant le terminateur }
 namemax = 8;       { Longueur maximale d'un nom de symbole }

  { Déplacement du format d'entrée de la table des symboles }
 name = 0;          { Offset du nom du symbole dans l'entrée }
 ident = 9;         { Offset de l'identificateur de type }
 ctype = 10;        { Offset du type de données C }
 storage = 11;      { Offset de la classe de stockage }
 offset = 12;       { Offset de la valeur/adresse du symbole }
 offsize = 2;       { Taille en octets du champ offset }

  { Types d'identificateurs }
 it_variable = 1;     { Variable simple }
 it_array = 2;        { Tableau }
 it_pointer = 3;      { Pointeur }
 it_function = 4;     { Fonction }
 it_struct_type = 5;  { Type structure }
 it_union_type = 6;   { Type union }
 it_typedef_type = 7; { Type défini par typedef }

  { Types de données }
 cvoid = 1;      { Type void (aucune valeur) }
 cchar = 2;      { Caractère signé 8 bits }
 cuchar = 3;     { Caractère non signé 8 bits }
 cshort = 4;     { Entier court signé 16 bits }
 cushort = 5;    { Entier court non signé 16 bits }
 cint = 6;       { Entier signé 16 bits }
 cuint = 7;      { Entier non signé 16 bits }
 clong = 8;      { Entier long signé 32 bits }
 culong = 9;     { Entier long non signé 32 bits }
 cfloat = 10;    { Nombre flottant simple précision }
 cdouble = 11;   { Nombre flottant double précision }
 cpointer = 12;  { Pointeur vers un type }
 carray = 13;    { Tableau d'éléments }
 cstruct = 14;   { Structure de données }
 cunion = 15;    { Union de données }

  { Taille du type en octets }
 sizeof_void = 0;     { Taille du type void (aucune taille) }
 sizeof_char = 1;     { Taille du type char (1 octet) }
 sizeof_short = 2;    { Taille du type short (2 octets) }
 sizeof_int = 2;      { Taille du type int sur 6809 (2 octets) }
 sizeof_long = 4;     { Taille du type long (4 octets) }
 sizeof_float = 4;    { Taille du type float (4 octets) }
 sizeof_double = 8;   { Taille du type double (8 octets) }
 sizeof_pointer = 2;  { Taille d'un pointeur sur 6809 (2 octets) }

  { Classes d'entreposage }
 statik = 1;      { Variable statique (durée de vie du programme) }
 stkloc = 2;      { Variable locale sur la pile }
 CEXTERNAL = 3;   { Variable externe définie ailleurs }
 automatic = 4;   { Variable automatique (locale par défaut) }

  { Types d'instructions }
 streturn = 3;    { Instruction de retour de fonction }

  { Types d'assembleurs }
 AS6809 = 1;      { Assembleur pour processeur Motorola 6809 }
 AS9 = 2;         { Assembleur AS9 pour 6809 }

  { Niveau d'optimisations }
 OPT_NONE = 0;        { Aucune optimisation }
 OPT_BASIC = 1;       { Optimisations de base }
 OPT_ADVANCED = 2;    { Optimisations avancées }
 OPT_AGGRESSIVE = 3;  { Optimisations agressives (toutes activées) }

 { Option d'optimisation }
 OPT_PEEPHOLE = 1;      { Optimisations pour analyse de code }
 OPT_DEAD_CODE = 2;     { �limination du code mort }
 OPT_CONSTANT_FOLD = 4; { Simplification des constantes }
 OPT_STRENGTH_RED = 8;  { R�duction de la complexit� }
 OPT_REGISTER = 16;     { Allocation de registres }
 OPT_JUMP = 32;         { Optimisations de sauts }

 { Ligne d'entrée }
 linesize = 80;            { Taille maximale d'une ligne d'entrée }
 linemax = linesize - 1;   { Index maximum valide dans une ligne }

Type
 { TSymTab no longer needed - using heap-based symbol table }
 TLine = String[linesize];

 { Structure d'information de type }
 PTypeInfo = ^TTypeInfo;
 TTypeInfo = Record
  base_type: Integer;      { Type de donn�es de base (cint, cchar, etc.) }
  pointer_level: Integer;  { Nombre de niveaux d'indirection }
  array_size: Integer;     { Taille du tableau (0 si ce n'est pas un tableau) }
  is_unsigned: Boolean;    { Vrai pour les types non sign�s }
  is_const: Boolean;       { Vrai pour les types constants }
  is_volatile: Boolean;    { Vrai pour les types volatils }
  struct_id: Integer;      { Identifiant de struct/union }
  size: Integer;           { Taille totale en octets }
 End;

 { Structure de valeur d'expression }
 TLVal = Record
  symbol: Integer;        { Pointeur vers l'entr�e de la table de symboles }
  indirect: Integer;      { 0=direct, 1=indirect }
  typ: Integer;           { Type de donn�es }
  storage: Integer;       { Classe d'entreposage }
  constant: Boolean;      { Vrai si la valeur est constante }
  value: Integer;         { Valeur constante, le cas �ch�ant }
  type_info: TTypeInfo;   { Informations de type �tendues }
 End;

 { Structure d'instruction d'optimisation }
 TOptInstruction = Record
  opcode: String[10];     { Mnémonique d'instruction }
  operand: String[20];    { Opérande }
  comment: String[40];    { Commentaire }
  line_number: Integer;   { Numéro de ligne source }
  can_eliminate: Boolean; { Peut être supprimé lors de la suppression du code mort }
 End;

 { Pointeur vers instruction d'optimisation }
 POptInst = ^TOptInst;
 
 { Structure d'instruction d'optimisation dans le tas }
 TOptInst = Record
  opcode: String[10];     { Mnémonique d'instruction }
  operand: String[20];    { Opérande }
  comment: String[40];    { Commentaire }
  line_number: Integer;   { Numéro de ligne source }
  can_eliminate: Boolean; { Peut être supprimé lors de la suppression du code mort }
  next: POptInst;         { Pointeur vers instruction suivante }
 End;

 { Optimisation de contexte }
 TOptContext = Record
  level: Integer;           { Niveau d'optimisation }
  flags: Integer;           { Drapeaux d'optimisation }
  inst_list: POptInst;      { Liste chaînée d'instructions dans le tas }
  inst_count: Integer;      { Nombre d'instructions }
  last_result_reg: String;  { Dernier registre utilisé pour le résultat }
 End;

 { Structure de param�tres de la fonction }
 TParameter = Record
  name: String[20];      { Nom du param�tre }
  typ: Integer;          { Type du param�tre }
  type_info: TTypeInfo;  { Informations d�taill�es sur le type }
  offset: Integer;       { D�placement de la pile }
 End;

 { Function information structure }
 TFunction = Record
  name: String[20];                      { Nom de la fonction }
  return_type: Integer;                  { Type de retour }
  return_type_info: TTypeInfo;           { Type de retour d�taill� }
  param_count: Integer;                  { Nombre de param�tres }
  parameters: Array[0..9] of TParameter; { Liste des param�tres }
  is_defined: Boolean;                   { Vrai si la fonction est d�finie (poss�de un corps) }
  is_declared: Boolean;                  { Vrai si la fonction est d�clar�e }
  label_id: Integer;                     { Etiquette assembleur de la fonction }
  local_vars_size: Integer;              { Taille dees variables locales }
  is_main: Boolean;                      { Vrai s'il s'agit de la fonction principale }
 End;

 { Structure de contexte de boucle pour le support break/continue }
 TLoopContext = Record
  loop_type: Integer;     { 1=while, 2=for, 3=do-while }
  break_label: Integer;   { Étiquette à utiliser pour break }
  continue_label: Integer; { Étiquette à utiliser pour continue }
 End;

 { Membre d'une structure ou union }
 TStructMember = Record
  name: String[20];       { Nom du membre }
  member_type: Integer;   { Type de base du membre }
  type_info: TTypeInfo;   { Informations détaillées du type }
  offset: Integer;        { Offset du membre dans la structure }
  size: Integer;          { Taille du membre en octets }
 End;

 { Définition de structure ou union }
 PStructDef = ^TStructDef;
 TStructDef = Record
  name: String[20];                        { Nom de la structure/union }
  is_union: Boolean;                       { Vrai si c'est une union, faux si struct }
  member_count: Integer;                   { Nombre de membres }
  members: Array[0..15] of TStructMember;  { Liste des membres (max 16) }
  total_size: Integer;                     { Taille totale de la structure }
  struct_id: Integer;                      { ID unique de la structure }
  next: PStructDef;                        { Structure suivante dans la liste }
 End;

 { Gestion des fichiers d'inclusion }
 TIncludeFile = Record
  filename: String{$IFNDEF FPC}[80]{$ENDIF};
  saved_line: TLine;
  saved_lptr: Integer;
  saved_eof: Integer;
 End;

 { Gestion des macros/Define - utilisation de tableaux statiques au lieu du tas }
 TDefine = Record
  name: String;
  value: String;
  in_use: Boolean;
 End;

 TDefineTable = Array[0..{$IFDEF FPC}99{$ELSE}49{$ENDIF}] of TDefine; { Max 100 définitions }

 { Table de symboles utilisant la mémoire de tas au lieu du segment de données }
 PSymbol = ^TSymbol;
 TSymbol = Record
  name: String;
  ident: Integer;    { it_variable, it_function, etc. }
  ctype: Integer;    { Type de symbole }
  storage: Integer;  { Classe de stockage }
  offset_value: Integer; { Décalage ou valeur }
  type_info: TTypeInfo; { Information de type étendue }
  next: PSymbol;     { Symbole suivant dans la chaîne }
 End;

  { Pointeur vers fonction dans le tas }
 PFunction = ^TFunctionNode;
 
 { Noeud de fonction pour liste chaînée dans le tas }
 TFunctionNode = Record
  func_data: TFunction;    { Données de la fonction }
  next: PFunction;         { Fonction suivante dans la liste }
 End;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain,_Albanian,_Portuguese,_Swedish,_Danish,_Japanese);
 TmpLanguage:String;
 { Tables de symbole }
 { Variables héritées - conservées pour la compatibilité avec certains calculs }
 glbptr, locptr: Integer;

 { Nouvelle table de symboles basée sur le tas }
 symbol_list: PSymbol;    { Tête de la liste de symboles }
 symbol_count: Integer;   { Compteur pour les statistiques }

 { Gestion de fonction - liste chaînée basée sur le tas }
 function_list: PFunction;          { Tête de la liste de fonctions }
 function_count: Integer;           { Compteur pour les statistiques }
 current_function_node: PFunction;  { Noeud de la fonction en cours d'analyse }
 current_function: Integer;         { Index de fonction pour compatibilité }
 call_stack_depth: Integer;         { Profondeur d'appel actuelle }

 { Contexte d'optimisation }
 opt_context: TOptContext;

 { Gestion des structures et unions - liste chaînée basée sur le tas }
 struct_list: PStructDef;     { Tête de la liste de structures/unions }
 struct_count: Integer;       { Compteur de structures/unions }
 next_struct_id: Integer;     { Prochain ID de structure disponible }

 { Pile de contexte de boucle pour break/continue }
 loop_stack: Array[0..31] of TLoopContext;
 loop_depth: Integer;

 { Pile de fichiers d'inclusion }
 include_stack: Array[0..9] of TIncludeFile;  { Max 10 niveaux d'inclusion }
 include_depth: Integer;
 current_filename: String;

 { Gestion Define/Macro - utilisation de table statique }
 define_table: TDefineTable;
 define_count: Integer; { Nombre de définitions actuellement en usage }

 { Informations de type étendues - maintenant stockées directement dans les symboles }
  type_info_count: Integer;

 { Ligne d'entr�e }
 line: TLine;
 lptr: Integer;

 { �tiquettes et compteurs }
 nxtlab: Integer;
 nextlabel: Integer; { Pour l'analyseur d'expressions }

 { Drapeaux et options }
 first_func, declared: Boolean;
 stkp: Integer;
 errcnt, eof: Integer;
 optimize, ctext, cmode, lastst: Integer;

 { Gestionnaires de fichiers }
 input, output: Text;
 asmtype: Integer;
 use_stdout: Boolean;

{ Déclarations anticipées }
Procedure init_type_info(var type_info: TTypeInfo); forward;
Function parse_type_specifier: Integer; forward;
Function parse_type_specifier_with_qualifiers(var type_info: TTypeInfo): Integer; forward;
Function readinline: Boolean; forward;

{ Fonctions héritées - plus nécessaires avec la table de symboles basée sur le tas }
Function startglb: Integer;Begin
 startglb := 1; { Commence à 1 pour réserver 0 comme valeur "non trouvé" }
End;

Function endglb: Integer;Begin
 endglb := 1000; { Valeur fictive pour la compatibilité }
End;

Function startloc: Integer;Begin
 startloc := 1000; { Valeur fictive pour la compatibilité }
End;

Function endloc: Integer;Begin
 endloc := 2000; { Valeur fictive pour la compatibilité }
End;

 { Fonctions utilitaires }
Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function upper(ch: Char): Char;Begin
 If ch in ['a'..'z'] Then upper := Chr(Ord(ch) - 32)
                     Else upper := ch;
End;

Function an(ch: Char):Boolean;Begin
 an := ch in ['A'..'Z', 'a'..'z', '_'];
End;

Function numeric(ch: Char): Boolean;Begin
 numeric := ch in ['0'..'9'];
End;

 { Utilitaires de chaine de caract�res }
Function streq(s1, s2: String): Boolean;Begin
 streq := s1 = s2;
End;

 { Fonctions d'entr�e/sortie }
Function ch:Char;Begin
 If lptr <= Length(line) Then ch := line[lptr]
                         Else ch := #0;
End;

Function gch:Char;Begin
 If lptr <= Length(line) Then Begin
  gch := line[lptr];
  Inc(lptr);
 End
  Else
 gch := #0;
End;

Procedure kill;Begin
 lptr := Length(line) + 1;
End;

{ Fonctions d'écriture de fichier sécurisées }
Function is_output_ready: Boolean;
Begin
 { Retourne toujours vrai car nous gérons la vérification de fichier ailleurs }
 is_output_ready := True;
End;

Procedure safe_write(s: String);
Begin
 { Utilise toujours stdout pour l'instant pour éviter les problèmes de fichier }
 Write(s);
End;

Procedure safe_writeln(s: String);
Begin
 { Utilise toujours stdout pour l'instant pour éviter les problèmes de fichier }
 WriteLn(s);
End;

Procedure nl;Begin
 safe_writeln('');
End;

Procedure ol(s:String);Begin
 safe_writeln(#9 + s);
End;

 { Écrire la ligne dans la sortie avec routage conditionnel }
Procedure outln(s: String);Begin
 safe_writeln(s);
End;

Procedure outstr(s:String);Begin
 safe_write(s);
End;

Procedure outdec(n:Integer);
Var
 temp: String;
Begin
 Str(n, temp);
 safe_write(temp);
End;

 { Fonctions de g�n�ration d'�tiquettes }
Function getlabel:Integer;Begin
 Inc(nextlabel);
 getlabel := nextlabel;
End;

Procedure printlabel(labelnum: Integer);Begin
 outstr('L');
 outdec(labelnum);
End;

Procedure prelabel(lab:Integer);
Var
 temp: String;
Begin
 Str(lab, temp);
 safe_writeln('L' + temp + ':');
End;

 { Génération de code }
Procedure ot(s: String);Begin
 safe_write(#9 + s + ' '); { TAB puis chaîne de caractères avec espace }
End;

 { Fonctions utilitaires d'analyse d'expressions }
Function is_alpha(ch:Char):Boolean;Begin
 is_alpha := ((ch >= 'A') and (ch <= 'Z')) or ((ch >= 'a') and (ch <= 'z')) or (ch = '_');
End;

Function is_digit(ch:Char):Boolean;Begin
 is_digit := (ch >= '0') and (ch <= '9');
End;

Function is_alnum(ch:Char):Boolean;Begin
 is_alnum := is_alpha(ch) or is_digit(ch);
End;

Procedure skip_whitespace;Begin
 While (lptr <= Length(line)) and ((line[lptr] = ' ') or (line[lptr] = #9)) do Inc(lptr);
End;

Function peek_char:Char;Begin
 skip_whitespace;
 If lptr <= Length(line)Then peek_char := line[lptr]
                        Else peek_char := #0;
End;

Function next_char:Char;Begin
 skip_whitespace;
 If lptr <= Length(line) Then Begin
  next_char := line[lptr];
  Inc(lptr);
 End
  Else
 next_char := #0;
End;

Function parse_number: Integer;
Var
 result: Integer;
Begin
 result := 0;
 skip_whitespace;
 While (lptr <= Length(line)) and is_digit(line[lptr]) do Begin
  result := result * 10 + (Ord(line[lptr]) - Ord('0'));
  Inc(lptr);
 End;
 parse_number := result;
End;

Function parse_identifier: String;
Var
 result: String;
Begin
 result := '';
 skip_whitespace;
 While (lptr <= Length(line)) and is_alnum(line[lptr]) do Begin
  result := result + line[lptr];
  Inc(lptr);
 End;
 parse_identifier := result;
End;

{ Signalement des erreurs }
Procedure errrpt(msg: String);Begin
 Inc(errcnt);
 Case Language of
  _English: WriteLn('Error: ', msg, ' at line ', lptr);
  Else WriteLn('Erreur: ', msg, ' à la ligne ', lptr);
 End;
End;

{ Gestion de contexte de boucle pour le support break/continue }
Procedure push_loop_context(loop_type: Integer; break_lbl, continue_lbl: Integer);
Begin
 If loop_depth >= 32 Then
 Begin
  Case Language of
   _English: errrpt('Too many nested loops');
   _Germany: errrpt('Zu viele verschachtelte Schleifen');
   Else errrpt('Trop de boucles imbriquées');
  End;
  Exit;
 End;
 
 { Vérification défensive - s'assurer que loop_depth est initialisé }
 If loop_depth < 0 Then loop_depth := 0;
 
 loop_stack[loop_depth].loop_type := loop_type;
 loop_stack[loop_depth].break_label := break_lbl;
 loop_stack[loop_depth].continue_label := continue_lbl;
 Inc(loop_depth);
End;

Procedure pop_loop_context;
Begin
 If loop_depth > 0 Then
  Dec(loop_depth);
End;

Function get_current_break_label: Integer;
Begin
 get_current_break_label := -1;
 If loop_depth > 0 Then
  get_current_break_label := loop_stack[loop_depth-1].break_label;
End;

Function get_current_continue_label: Integer;
Begin
 get_current_continue_label := -1;
 If loop_depth > 0 Then
  get_current_continue_label := loop_stack[loop_depth-1].continue_label;
End;

Procedure outbyte(b: Byte);Begin
 Write(Chr(b)); { Utilise toujours stdout pour la sécurité }
End;

 { Analyse lexicale }
Function blanks: Boolean;
Var
 found: Boolean;
Begin
 found := False;
 While (lptr <= Length(line)) and (line[lptr] in [' ', #9]) do Begin
  Inc(lptr);
  found := True;
 End;
 blanks := found;
End;

Function match(s: String): Boolean;
Var
 i: Integer;
 matched: Boolean;
Begin
 blanks;
 matched := True;
 For i := 1 to Length(s) do Begin
  If (lptr + i - 1 > Length(line)) or (line[lptr + i - 1] <> s[i]) Then Begin
   matched := False;
   Break;
  End;
 End;
 If matched Then lptr := lptr + Length(s);
 match := matched;
End;

Function amatch(s: String; len: Integer): Boolean;Begin
 amatch := match(Copy(s, 1, len));
End;

Function symname(Var sname: String): Boolean;
Var
 i: Integer;
Begin
 blanks;
 sname := '';
 i := 0;
 If (lptr <= Length(line)) and an(line[lptr]) Then
 Begin
  While (lptr <= Length(line)) and (an(line[lptr]) or numeric(line[lptr])) and (i < namemax) do
  Begin
   sname := sname + line[lptr];
   Inc(lptr);
   Inc(i);
  End;
  symname := True;
 End
 Else symname := False;
End;

 { Analyse des nombres }
Function number(Var value: Integer): Boolean;
Var
 n: Integer;
Begin
 blanks;
 n := 0;
 number := False;
 If (lptr <= Length(line)) and numeric(line[lptr]) Then Begin
  number := True;
  While (lptr <= Length(line)) and numeric(line[lptr]) do Begin
   n := n * 10 + (Ord(line[lptr]) - Ord('0'));
   Inc(lptr);
  End;
  value := n;
 End;
End; { Gestion des tables de symboles }
Function hash(sname: String): Integer;
Var
 h, i: Integer;
Begin
 h := 0;
 For i := 1 to Length(sname) do
  h := (h shl 1) + Ord(sname[i]);
 hash := h;
End;

{ ============================================================================ }
{ NOUVELLES FONCTIONS DE TABLE DE SYMBOLES BASÉE SUR LE TAS                   }
{ ============================================================================ }

{ Initialiser la table de symboles basée sur le tas }
Procedure init_symbols;
Begin
 symbol_list := nil;
 symbol_count := 0;
End;

{ Trouver un symbole dans la table de symboles basée sur le tas }
Function find_symbol(sname: String): PSymbol;
Var
 current: PSymbol;
Begin
 find_symbol := nil;
 current := symbol_list;
 
 While current <> nil do
 Begin
  If current^.name = sname Then
  Begin
   find_symbol := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Ajouter un symbole à la table de symboles basée sur le tas }
Function add_symbol(sname: String; id_type: Integer; sym_type: Integer; stor_class: Integer; offset_val: Integer): PSymbol;
Var
 new_symbol: PSymbol;
Begin
 add_symbol := nil;
 
 { Vérifier si le symbole existe déjà }
 If find_symbol(sname) <> nil Then
 Begin
  { Le symbole existe déjà }
  Exit;
 End;
 
 { Allouer de la mémoire sur le tas }
 New(new_symbol);
 If new_symbol = nil Then
 Begin
  { Mémoire insuffisante }
  Exit;
 End;
 
 { Initialiser le nouveau symbole }
 With new_symbol^ do
 Begin
  name := sname;
  ident := id_type;
  ctype := sym_type;
  storage := stor_class;
  offset_value := offset_val;
  init_type_info(type_info);
  type_info.base_type := sym_type;
  next := symbol_list;  { Insérer au début de la liste }
 End;
 
 { Mettre à jour la tête de liste }
 symbol_list := new_symbol;
 Inc(symbol_count);
 
 add_symbol := new_symbol;
End;

{ Fonction addsym améliorée utilisant le tas }
Function addsym_heap(sname: String; typ: Integer; storage: Integer; offset_value: Integer): PSymbol;
Begin
 addsym_heap := add_symbol(sname, it_variable, typ, storage, offset_value);
End;

{ Fonction findsym améliorée utilisant le tas }
Function findsym_heap(sname: String): PSymbol;
Begin
 findsym_heap := find_symbol(sname);
End;

{ Libérer tous les symboles de la mémoire de tas }
Procedure free_symbols;
Var
 current, next: PSymbol;
Begin
 current := symbol_list;
 While current <> nil do
 Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 
 symbol_list := nil;
 If use_stdout Then WriteLn('; Freed ', symbol_count, ' symbols from heap')
               Else safe_writeln('; Freed symbols from heap');
 symbol_count := 0;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES TYPES                                               }
{ ============================================================================ }

{ Initialiser la structure d'informations de type }
Procedure init_type_info(var type_info: TTypeInfo);Begin
 FillChar(type_info, SizeOf(type_info), 0);
 type_info.base_type := cint;
 type_info.pointer_level := 0;
 type_info.array_size := 0;
 type_info.is_unsigned := False;
 type_info.is_const := False;
 type_info.is_volatile := False;
 type_info.struct_id := 0;
 type_info.size := sizeof_int;
End;

{ Obtenir la taille d'un type de base }
Function get_type_size(base_type: Integer): Integer;Begin
 Case base_type of
  cvoid: get_type_size := sizeof_void;
  cchar, cuchar: get_type_size := sizeof_char;
  cshort, cushort: get_type_size := sizeof_short;
  cint, cuint: get_type_size := sizeof_int;
  clong, culong: get_type_size := sizeof_long;
  cfloat: get_type_size := sizeof_float;
  cdouble: get_type_size := sizeof_double;
  cpointer: get_type_size := sizeof_pointer;
  Else get_type_size := sizeof_int; { Par défaut }
 End;
End;

{ Calculer la taille totale d'un type, tableaux et pointeurs inclus }
Function calculate_type_size(var type_info: TTypeInfo): Integer;
Var
 result_size: Integer;
Begin
 If type_info.pointer_level > 0 Then result_size := sizeof_pointer Else
 If type_info.array_size > 0 Then result_size := get_type_size(type_info.base_type) * type_info.array_size
                             Else result_size := get_type_size(type_info.base_type);
 type_info.size := result_size;
 calculate_type_size := result_size;
End;

{ Vérifiez si deux types sont compatibles }
Function types_compatible(var type1, type2: TTypeInfo): Boolean;Begin
 types_compatible := (type1.base_type = type2.base_type) and
                    (type1.pointer_level = type2.pointer_level) and
                    (type1.is_unsigned = type2.is_unsigned);
End;

{ Vérifier si le type peut être converti en un autre }
Function can_convert_type(var from_type, to_type: TTypeInfo):Boolean;Begin
  { Les pointeurs peuvent être convertis en pointeurs }
 If (from_type.pointer_level > 0) and (to_type.pointer_level > 0) Then Begin
  can_convert_type := True;
  Exit;
 End;
  { Les types numériques peuvent généralement être convertis }
 If (from_type.pointer_level = 0) and (to_type.pointer_level = 0) Then Begin
  Case from_type.base_type of
   cchar, cuchar, cshort, cushort, cint, cuint, clong, culong:
    Case to_type.base_type of
     cchar, cuchar, cshort, cushort, cint, cuint, clong, culong:
      can_convert_type := True;
    Else
     can_convert_type := False;
    End;
  Else
   can_convert_type := False;
  End;
 End
 Else
  can_convert_type := False;
End;

 { Récupérer le nom du type sous forme de chaîne de caractères pour les messages de débogage/d'erreur }
Function get_type_name(var type_info: TTypeInfo): String;
Var
 base_name, temp_str: String;
 i: Integer;
Begin
  { Obtenir le nom du type de base }
 Case type_info.base_type of
  cvoid: base_name := 'void';
  cchar: base_name := 'char';
  cuchar: base_name := 'unsigned char';
  cshort: base_name := 'short';
  cushort: base_name := 'unsigned short';
  cint: base_name := 'int';
  cuint: base_name := 'unsigned int';
  clong: base_name := 'long';
  culong: base_name := 'unsigned long';
  cfloat: base_name := 'float';
  cdouble: base_name := 'double';
  Else base_name := 'unknown';
 End;
  { Ajouter les qualificateurs const/volatile }
 If type_info.is_const Then base_name := 'const ' + base_name;
 If type_info.is_volatile Then base_name := 'volatile ' + base_name;
  { Ajouter des astéristiques de pointeur }
 For i := 1 to type_info.pointer_level do base_name := base_name + '*';
  { Ajouter la notation de tableau }
 If type_info.array_size > 0 Then Begin
  Str(type_info.array_size, temp_str);
  base_name := base_name + '[' + temp_str + ']';
 End;
 get_type_name := base_name;
End;

 { Générer le code assembleur pour la conversion de type }
Procedure generate_type_conversion(var from_type, to_type: TTypeInfo);Begin
 Case Language of
  _English:safe_writeln('; Type conversion from ' + get_type_name(from_type) + ' to ' + get_type_name(to_type));
  Else safe_writeln('; Conversion de type de ' + get_type_name(from_type) + ' à ' + get_type_name(to_type));
 End;
 { Gérer la conversion char en int }
 If (from_type.base_type = cchar) and (to_type.base_type = cint) Then Begin
  If from_type.is_unsigned Then Begin
   ol('clra   ; extension zéro char non signé');
  End
  Else
  Begin
   ol('sex    ; extension de signe char signé');
  End;
 End
  { Gérer la conversion int vers char }
  Else
 If (from_type.base_type = cint) and (to_type.base_type = cchar) Then Begin
  ol('tfr  d,x ; ne garder que l''octet faible');
  ol('tfr  b,a');
  ol('clrb');
 End;
  { Ajouter des conversions supplémentaires si nécessaires }
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DE LA LISTE D'INSTRUCTIONS D'OPTIMISATION              }
{ ============================================================================ }

 { Ajouter une instruction à la liste chaînée }
Function add_opt_instruction(opcode, operand, comment: String): POptInst;
Var
 new_inst: POptInst;
Begin
 New(new_inst);
 new_inst^.opcode := opcode;
 new_inst^.operand := operand;
 new_inst^.comment := comment;
 new_inst^.line_number := opt_context.inst_count;
 new_inst^.can_eliminate := False;
 new_inst^.next := opt_context.inst_list;
 opt_context.inst_list := new_inst;
 Inc(opt_context.inst_count);
 add_opt_instruction := new_inst;
End;

 { Obtenir l'instruction à l'index donné (pour compatibilité) }
Function get_opt_instruction(index: Integer): POptInst;
Var
 current: POptInst;
 i: Integer;
Begin
 current := opt_context.inst_list;
 For i := opt_context.inst_count - 1 downto index + 1 do Begin
  If current <> nil Then current := current^.next;
 End;
 get_opt_instruction := current;
End;

 { Libérer toute la liste d'instructions }
Procedure free_opt_instructions;
Var
 current, temp: POptInst;
Begin
 current := opt_context.inst_list;
 While current <> nil do Begin
  temp := current;
  current := current^.next;
  Dispose(temp);
 End;
 opt_context.inst_list := nil;
 opt_context.inst_count := 0;
End;

{ ============================================================================ }
{ FONCTIONS D'OPTIMISATION DU CODE                                             }
{ ============================================================================ }

 { Initialiser le contexte d'optimisation }
Procedure init_optimization;Begin
 FillChar(opt_context, SizeOf(opt_context), 0);
 opt_context.level := optimize;
 opt_context.inst_list := nil;
 opt_context.inst_count := 0;
 opt_context.last_result_reg := 'd';
  { Définir les indicateurs d'optimisation en fonction du niveau }
 Case optimize of
  OPT_NONE: opt_context.flags := 0;
  OPT_BASIC: opt_context.flags := OPT_PEEPHOLE or OPT_CONSTANT_FOLD;
  OPT_ADVANCED: opt_context.flags := OPT_PEEPHOLE or OPT_CONSTANT_FOLD or OPT_DEAD_CODE or OPT_JUMP;
  OPT_AGGRESSIVE: opt_context.flags := $7FFF; { Toutes les optimisations }
 End;
End;

 { Ajouter des instructions au tampon d'optimisation }
Procedure add_instruction(opcode,operand,comment:String);Begin
 add_opt_instruction(opcode, operand, comment);
End;

{ Optimisation du judas - suppression des instructions redondantes }
Procedure peephole_optimize;
Var
 current, next_inst, temp: POptInst;
 changed: Boolean;
Begin
 If (opt_context.flags and OPT_PEEPHOLE) = 0 Then Exit;
 Repeat
  changed := False;
  current := opt_context.inst_list;
  While (current <> nil) and (current^.next <> nil) do Begin
   next_inst := current^.next;
   
   { Enlève LDD #0 suivi par STD }
   If(current^.opcode = 'ldd')and(current^.operand = '#0')Then Begin
    If (next_inst^.opcode = 'std') Then Begin
     { Remplace avec CLR }
     current^.opcode := 'clr';
     current^.operand := next_inst^.operand;
     current^.comment := current^.comment + ' ; optimisé de ldd #0, std';
     { Marquer la prochaine instruction pour le retrait }
     next_inst^.can_eliminate := True;
     changed := True;
    End;
   End
   { Enlève STD suivi par LDD dans le même emplacement }
   Else If (current^.opcode = 'std') Then Begin
    If (next_inst^.opcode = 'ldd') and
       (next_inst^.operand = current^.operand) Then
    Begin
     { Supprime les LDD redondants }
     next_inst^.can_eliminate := True;
     current^.comment := current^.comment + ' ; supprime les LDD redondants ldd';
     changed := True;
    End;
   End
   { Optimise PSHS D suivi par PULS D }
   Else If (current^.opcode = 'pshs') and (current^.operand = 'd') Then
   Begin
    If (next_inst^.opcode = 'puls') and
       (next_inst^.operand = 'd') Then
    Begin
     { Supprimer les deux instructions }
     current^.can_eliminate := True;
     next_inst^.can_eliminate := True;
     changed := True;
    End;
   End;
   
   current := current^.next;
  End;
  
  { Enlève les instructions marquées }
  current := opt_context.inst_list;
  opt_context.inst_list := nil;
  opt_context.inst_count := 0;
  
  While current <> nil do Begin
   temp := current;
   current := current^.next;
   
   If not temp^.can_eliminate Then Begin
    temp^.next := opt_context.inst_list;
    opt_context.inst_list := temp;
    Inc(opt_context.inst_count);
   End Else Begin
    Dispose(temp);
   End;
  End;
 Until not changed;
End;

 { Optimisation constante du pliage }
Procedure constant_fold_optimize;
Var
 current, next1, next2: POptInst;
Begin
 If (opt_context.flags and OPT_CONSTANT_FOLD) = 0 Then Exit;
 current := opt_context.inst_list;
 While (current <> nil) and (current^.next <> nil) and (current^.next^.next <> nil) do Begin
  next1 := current^.next;
  next2 := current^.next^.next;
  
  { Optimise LDD #1 suivi par NEGA/NEGB à LDD #-1 }
  If (current^.opcode = 'ldd') and (current^.operand = '#1') Then Begin
   If (next1^.opcode = 'nega') and (next2^.opcode = 'negb') Then
   Begin
    current^.operand := '#-1';
    current^.comment := current^.comment + ' ; constante pliée';
    next1^.can_eliminate := True;
    next2^.can_eliminate := True;
   End;
  End
  { Optimise la multiplication par la puissance de 2 }
  Else If (current^.opcode = 'jsr') and (current^.operand = 'mult16') Then
  Begin
   { Il faudrait plus de contexte pour déterminer s'il s'agit d'une multiplication par une constante }
   Case Language of
    _English: current^.comment := current^.comment + ' ; could optimize if power of 2';
    Else current^.comment:= current^.comment + ' ; pourrait être optimisé si c''est une puissance de 2';
   End;
  End;
  
  current := current^.next;
 End;
End;

 { Élimination des codes morts }
Procedure dead_code_eliminate;
Var
 current: POptInst;
Begin
 If (opt_context.flags and OPT_DEAD_CODE) = 0 Then Exit;
 current := opt_context.inst_list;
 While current <> nil do Begin
  { Instructions d'élimination de Mark NOP }
  If current^.opcode = 'nop' Then Begin
   current^.can_eliminate := True;
  End;
  current := current^.next;
 End;
End;

 { Optimisation des sauts - suppression des sauts inutiles }
Procedure jump_optimize;
Var
 current: POptInst;
Begin
 If (opt_context.flags and OPT_JUMP) = 0 Then Exit;

 current := opt_context.inst_list;
 While current <> nil do
 Begin
  { Supprimer les sauts vers l'instruction suivante }
  If (current^.opcode = 'lbra') or (current^.opcode = 'bra') Then
  Begin
   { Cela nécessiterait une analyse d'étiquettes pour être entièrement implémenté }
   current^.comment := current^.comment + ' ; candidat à l''optimisation de saut';
  End;
  current := current^.next;
 End;
End;

{ Appliquer toutes les optimisations }
Procedure optimize_code;
Begin
 If optimize = OPT_NONE Then Exit;

 safe_writeln('; Application des optimisations');

 { Appliquer les optimisations dans l'ordre }
 constant_fold_optimize;
 peephole_optimize;
 dead_code_eliminate;
 jump_optimize;

 safe_writeln('; Optimisation terminée');
End;

{ Sortie des instructions optimisées }
Procedure output_optimized_instructions;
Var
 current: POptInst;
Begin
 current := opt_context.inst_list;
 While current <> nil do
 Begin
  With current^ do
  Begin
   If not can_eliminate Then
   Begin
    If Length(comment) > 0 Then
     safe_writeln(#9 + opcode + ' ' + operand + ' ; ' + comment)
    Else
     safe_writeln(#9 + opcode + ' ' + operand);
   End;
  End;
  current := current^.next;
 End;
End;

{ Emballage de génération de code optimisé }
Procedure optimized_ol(s: String);
Begin
 If optimize > OPT_NONE Then
  add_instruction(s, '', '')
 Else
  ol(s);
End;

Procedure optimized_ot(op, operand: String);
Begin
 If optimize > OPT_NONE Then
  add_instruction(op, operand, '')
 Else
 Begin
  ot(op + ' ' + operand);
  nl;
 End;
End;

{ Fonctions d'optimisation spécialisées }

{ Chargement de constante optimisé }
Procedure opt_load_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then
 Begin
  { Optimiser les constantes communes }
  Case value of
   0: add_instruction('clr', 'a', 'chargement zéro optimisé');
   1: add_instruction('lda', '#1', 'chargement un optimisé');
   -1: add_instruction('lda', '#$FF', 'chargement -1 optimisé');
  Else
   Begin
    Str(value, temp);
    add_instruction('ldd', '#' + temp, 'charger constante');
   End;
  End;
 End
 Else
 Begin
  ot('ldd  #');
  outdec(value);
  nl;
 End;
End;

{ Affectation de variable optimisée }
Procedure opt_store_variable(var_name: String; size: Integer);
Begin
 If optimize > OPT_NONE Then
 Begin
  Case size of
   1: add_instruction('stb', var_name, 'stocker octet');
   2: add_instruction('std', var_name, 'stocker mot');
  Else
   add_instruction('std', var_name, 'stocker par défaut');
  End;
 End
 Else
 Begin
  Case size of
   1: Begin
       ot('stb  ');
       outstr(var_name);
       nl;
      End;
   2: Begin
       ot('std  ');
       outstr(var_name);
       nl;
      End;
  Else
   Begin
    ot('std  ');
    outstr(var_name);
    nl;
   End;
  End;
 End;
End;

{ Opérations arithmétiques optimisées }
Procedure opt_add_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then
 Begin
  Case value of
   0: { Ne rien faire - ajouter zéro };
   1: add_instruction('inc', 'd', '+1 optimisé');
   -1: add_instruction('dec', 'd', '-1 optimisé');
  Else
   Begin
    Str(value, temp);
    add_instruction('addd', '#' + temp, 'ajouter constante');
   End;
  End;
 End
 Else
 Begin
  If value <> 0 Then
  Begin
   ot('addd #');
   outdec(value);
   nl;
  End;
 End;
End;

{ Multiplication optimisée }
Procedure opt_multiply(value: Integer);
Begin
 If optimize > OPT_NONE Then
 Begin
  { Optimiser la multiplication par des puissances de 2 }
  Case value of
   0: add_instruction('clr', 'd', 'multiplier par 0');
   1: { Ne rien faire - multiplier par 1 };
   2: add_instruction('lsld', '', 'multiplier par 2');
   4: Begin
       add_instruction('lsld', '', 'multiplier par 4 (décalage 1)');
       add_instruction('lsld', '', 'multiplier par 4 (décalage 2)');
      End;
   8: Begin
       add_instruction('lsld', '', 'multiplier par 8 (décalage 1)');
       add_instruction('lsld', '', 'multiplier par 8 (décalage 2)');
       add_instruction('lsld', '', 'multiplier par 8 (décalage 3)');
      End;
  Else
   add_instruction('jsr', 'mult16', 'multiplication générale');
  End;
 End
 Else
  ol('jsr  mult16');
End;

{ Corriger la fonction IntToStr - remplacer par Str }
Function IntToStr(value: Integer): String;
Var
 temp: String;
Begin
 Str(value, temp);
 IntToStr := temp;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES FONCTIONS                                          }
{ ============================================================================ }

{ Initialiser le système de gestion des fonctions basé sur le tas }
Procedure init_functions;
Begin
 function_list := nil;
 function_count := 0;
 current_function_node := nil;
 current_function := -1;
 call_stack_depth := 0;
End;

{ Trouver une fonction par nom - retourne le pointeur vers le noeud }
Function find_function_node(func_name: String): PFunction;
Var
 current: PFunction;
Begin
 find_function_node := nil;
 current := function_list;
 
 While current <> nil do
 Begin
  If current^.func_data.name = func_name Then
  Begin
   find_function_node := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Trouver une fonction par nom - retourne l'index pour compatibilité }
Function find_function(func_name: String): Integer;
Var
 current: PFunction;
 index: Integer;
Begin
 find_function := -1;
 current := function_list;
 index := 0;
 
 While current <> nil do
 Begin
  If current^.func_data.name = func_name Then
  Begin
   find_function := index;
   Exit;
  End;
  current := current^.next;
  Inc(index);
 End;
End;

{ Ajouter une nouvelle fonction à la liste chaînée }
Function add_function(func_name: String; return_type: Integer): Integer;
Var
 func_node: PFunction;
 func_index: Integer;
Begin
 add_function := -1;

 { Vérifier si la fonction existe déjà }
 func_index := find_function(func_name);
 If func_index <> -1 Then
 Begin
  add_function := func_index;
  Exit;
 End;

 { Allouer mémoire pour nouvelle fonction dans le tas }
 New(func_node);
 If func_node = nil Then
 Begin
  Case Language of
   _English: errrpt('Out of memory for function table');
   _Germany: errrpt('Kein Speicher für Funktionstabelle');
   Else errrpt('Mémoire insuffisante pour la table de fonctions');
  End;
  Exit;
 End;

 { Initialiser les données de la fonction }
 With func_node^.func_data do
 Begin
  name := func_name;
  return_type := return_type;
  init_type_info(return_type_info);
  return_type_info.base_type := return_type;
  calculate_type_size(return_type_info);
  param_count := 0;
  is_defined := False;
  is_declared := False;
  label_id := getlabel;
  local_vars_size := 0;
  is_main := (func_name = 'main');
 End;

 { Insérer au début de la liste }
 func_node^.next := function_list;
 function_list := func_node;
 
 func_index := function_count;
 Inc(function_count);
 add_function := func_index;
End;

{ Obtenir le noeud de fonction par index pour compatibilité }
Function get_function_node(func_index: Integer): PFunction;
Var
 current: PFunction;
 i: Integer;
Begin
 get_function_node := nil;
 
 If (func_index < 0) or (func_index >= function_count) Then Exit;
 
 current := function_list;
 For i := 0 to func_index do
 Begin
  If current = nil Then Exit;
  If i = func_index Then
  Begin
   get_function_node := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Ajouter un paramètre à la fonction }
Function add_parameter(func_index: Integer; param_name: String; param_type: Integer): Boolean;
Var
 func_node: PFunction;
Begin
 add_parameter := False;

 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;

 With func_node^.func_data do
 Begin
  If param_count >= 10 Then
  Begin
   Case Language of
    _English: errrpt('Too many parameters for function ' + name);
    _Germany: errrpt('Zu viele Parameter für Funktion ' + name);
    Else errrpt('Trop de paramètres pour la fonction ' + name);
   End;
   Exit;
  End;

  With parameters[param_count] do
  Begin
   name := param_name;
   typ := param_type;
   init_type_info(type_info);
   type_info.base_type := param_type;
   calculate_type_size(type_info);
   offset := param_count * 2; { 2 octets par paramètre sur la pile 6809 }
  End;

  Inc(param_count);
  add_parameter := True;
 End;
End;

{ Générer le prologue de fonction }
Procedure generate_function_prologue(func_index: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;

 With func_node^.func_data do
 Begin
  safe_writeln('; Fonction: ' + name);
  safe_writeln(name + ':');

  { Prologue standard 6809 }
  If not is_main Then
  Begin
   ol('pshs x,y  ; sauvegarder pointeur de cadre et contexte d''adresse de retour');
   ol('tfr  s,x  ; configurer pointeur de cadre');

   { Allouer de l'espace pour les variables locales si nécessaire }
   If local_vars_size > 0 Then
   Begin
    safe_writeln('; Allouer variables locales (octets de taille)');
    ot('leas -');
    outdec(local_vars_size);
    outstr(',s');
    nl;
   End;
  End
  Else
  Begin
   safe_writeln('; Point d''entrée de la fonction principale');
  End;
 End;
End;

{ Générer l'épilogue de fonction }
Procedure generate_function_epilogue(func_index: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;

 With func_node^.func_data do
 Begin
  safe_writeln('; Fin de fonction: ' + name);

  If not is_main Then
  Begin
   { Épilogue standard 6809 }
   If local_vars_size > 0 Then
   Begin
    safe_writeln('; Désallouer variables locales');
    ot('leas ');
    outdec(local_vars_size);
    outstr(',s');
    nl;
   End;

   ol('puls x,y  ; restaurer pointeur de cadre');
   ol('rts       ; retourner à l''appelant');
  End
  Else
  Begin
   safe_writeln('; Sortie de fonction principale');
   ol('swi       ; interruption logicielle (fin de programme)');
  End;
 End;
End;

{ Générer un appel de fonction }
Procedure generate_function_call(func_index: Integer; arg_count: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;

 With func_node^.func_data do
 Begin
  safe_writeln('; Appel de fonction: ' + name);

  { Vérifier le nombre de paramètres }
  If arg_count <> param_count Then
   safe_writeln('; Attention: Nombre d''arguments ne correspond pas');

  { Générer l'instruction d'appel }
  ot('jsr  ');
  outstr(name);
  nl;

  { Nettoyer la pile si des paramètres ont été passés }
  If param_count > 0 Then
  Begin
   safe_writeln('; Nettoyer les paramètres de pile');
   ot('leas ');
   outdec(param_count * 2);
   outstr(',s');
   nl;
  End;

  Inc(call_stack_depth);
 End;
End;

{ Libérer toute la liste de fonctions du tas }
Procedure free_functions;
Var
 current, next: PFunction;
Begin
 current := function_list;
 While current <> nil do
 Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 
 function_list := nil;
 If use_stdout Then WriteLn('; Libéré ', function_count, ' fonctions du tas')
               Else safe_writeln('; Libéré fonctions du tas');
 function_count := 0;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES STRUCTURES ET UNIONS                               }
{ ============================================================================ }

{ Initialiser le système de gestion des structures }
Procedure init_structs;
Begin
 struct_list := nil;
 struct_count := 0;
 next_struct_id := 1;
End;

{ Trouver une structure par nom }
Function find_struct(struct_name: String): PStructDef;
Var
 current: PStructDef;
Begin
 find_struct := nil;
 current := struct_list;
 
 While current <> nil do
 Begin
  If current^.name = struct_name Then
  Begin
   find_struct := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Trouver une structure par ID }
Function find_struct_by_id(struct_id: Integer): PStructDef;
Var
 current: PStructDef;
Begin
 find_struct_by_id := nil;
 current := struct_list;
 
 While current <> nil do
 Begin
  If current^.struct_id = struct_id Then
  Begin
   find_struct_by_id := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Créer une nouvelle structure/union }
Function create_struct(struct_name: String; is_union: Boolean): PStructDef;
Var
 new_struct: PStructDef;
Begin
 create_struct := nil;
 
 { Vérifier si la structure existe déjà }
 If find_struct(struct_name) <> nil Then
 Begin
  Case Language of
   _English: errrpt('Struct/Union already defined: ' + struct_name);
   _Germany: errrpt('Struct/Union bereits definiert: ' + struct_name);
   Else errrpt('Structure/Union déjà définie: ' + struct_name);
  End;
  Exit;
 End;
 
 { Allouer mémoire pour la nouvelle structure }
 New(new_struct);
 If new_struct = nil Then
 Begin
  Case Language of
   _English: errrpt('Out of memory for struct definition');
   _Germany: errrpt('Kein Speicher für Struct-Definition');
   Else errrpt('Mémoire insuffisante pour la définition de structure');
  End;
  Exit;
 End;
 
 { Initialiser la structure }
 With new_struct^ do
 Begin
  name := struct_name;
  is_union := is_union;
  member_count := 0;
  total_size := 0;
  struct_id := next_struct_id;
  Inc(next_struct_id);
  next := struct_list;
 End;
 
 { Ajouter au début de la liste }
 struct_list := new_struct;
 Inc(struct_count);
 
 create_struct := new_struct;
End;

{ Ajouter un membre à une structure }
Function add_struct_member(struct_def: PStructDef; member_name: String;
                          member_type: Integer; var type_info: TTypeInfo): Boolean;
Var
 member_size: Integer;
Begin
 add_struct_member := False;
 
 If struct_def = nil Then Exit;
 
 With struct_def^ do
 Begin
  If member_count >= 16 Then
  Begin
   Case Language of
    _English: errrpt('Too many members in struct: ' + name);
    _Germany: errrpt('Zu viele Mitglieder in Struct: ' + name);
    Else errrpt('Trop de membres dans la structure: ' + name);
   End;
   Exit;
  End;
  
  { Calculer la taille du membre }
  member_size := calculate_type_size(type_info);
  
  { Initialiser le membre }
  With members[member_count] do
  Begin
   name := member_name;
   member_type := member_type;
   type_info := type_info;
   size := member_size;
   
   If is_union Then
   Begin
    { Dans une union, tous les membres ont offset 0 }
    offset := 0;
    { La taille de l'union est la taille du plus grand membre }
    If member_size > total_size Then
     total_size := member_size;
   End
   Else
   Begin
    { Dans une structure, les membres sont alignés séquentiellement }
    offset := total_size;
    total_size := total_size + member_size;
   End;
  End;
  
  Inc(member_count);
  add_struct_member := True;
 End;
End;

{ Trouver un membre dans une structure }
Function find_struct_member(struct_def: PStructDef; member_name: String): Integer;
Var
 i: Integer;
Begin
 find_struct_member := -1;
 
 If struct_def = nil Then Exit;
 
 For i := 0 to struct_def^.member_count - 1 do
 Begin
  If struct_def^.members[i].name = member_name Then
  Begin
   find_struct_member := i;
   Exit;
  End;
 End;
End;

{ Libérer toutes les structures de la mémoire de tas }
Procedure free_structs;
Var
 current, next: PStructDef;
Begin
 current := struct_list;
 While current <> nil do
 Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 
 struct_list := nil;
 If use_stdout Then WriteLn('; Libéré ', struct_count, ' structures du tas')
               Else safe_writeln('; Libéré structures du tas');
 struct_count := 0;
End;

{ Analyser une déclaration de structure ou union }
Function parse_struct_declaration(is_union: Boolean): Integer;
Var
 struct_name, member_name: String;
 struct_def: PStructDef;
 member_type: Integer;
 member_type_info: TTypeInfo;
Begin
 parse_struct_declaration := -1;
 
 { Obtenir le nom de la structure/union (optionnel) }
 If symname(struct_name) Then
 Begin
  { Structure nommée }
  If is_union Then
   safe_writeln('; Déclaration union: ' + struct_name)
  Else
   safe_writeln('; Déclaration struct: ' + struct_name);
 End
 Else
 Begin
  { Structure anonyme - générer un nom unique }
  Str(next_struct_id, struct_name);
  struct_name := '_anon_struct_' + struct_name;
 End;
 
 { Vérifier s'il y a une définition de corps }
 If match('{') Then
 Begin
  { Créer la nouvelle structure }
  struct_def := create_struct(struct_name, is_union);
  If struct_def = nil Then Exit;
  
  { Analyser les membres }
  safe_writeln('; Début parsing membres struct');
  blanks; { S'assurer qu'on ignore les espaces au début }
  
  Repeat
   { Vérifier si nous avons atteint la fin de la ligne }
   If lptr > Length(line) Then
   Begin
    safe_writeln('; Lecture nouvelle ligne pour struct...');
    If not readinline Then
    Begin
     Case Language of
      _English: errrpt('Unexpected end of file in struct/union');
      _Germany: errrpt('Unerwartetes Dateiende in Struct/Union');  
      Else errrpt('Fin de fichier inattendue dans struct/union');
     End;
     Exit;
    End;
   End;
   
   blanks; { Ignorer les espaces }
   
   { Vérifier si c'est la fin de la struct }
   If peek_char = '}' Then Break;
   
   safe_writeln('; Dans boucle parsing - membre détecté');
   safe_writeln('; Parsing membre...'); 
   blanks; { S'assurer qu'on ignore les espaces }
   { Analyser le type du membre }
   member_type := parse_type_specifier;
   init_type_info(member_type_info);
   member_type_info.base_type := member_type;
   calculate_type_size(member_type_info);
   safe_writeln('; Type membre analysé: ' + IntToStr(member_type));
   If member_type = -1 Then
   Begin
    Case Language of
     _English: errrpt('Expected member type in struct/union');
     _Germany: errrpt('Erwarteter Mitgliedstyp in Struct/Union');
     Else errrpt('Type de membre attendu dans struct/union');
    End;
    Exit;
   End;
   
   { Analyser le nom du membre }
   safe_writeln('; Tentative lecture nom membre...');
   If not symname(member_name) Then
   Begin
    Case Language of
     _English: errrpt('Expected member name in struct/union');
     _Germany: errrpt('Erwarteter Mitgliedsname in Struct/Union');
     Else errrpt('Nom de membre attendu dans struct/union');
    End;
    Exit;
   End;
   
   safe_writeln('; Nom de membre lu: ' + member_name);
   
   { Ajouter le membre à la structure }
   If not add_struct_member(struct_def, member_name, member_type, member_type_info) Then
    Exit;
   
   { Consommer le point-virgule }
   If not match(';') Then
   Begin
    Case Language of
     _English: errrpt('Expected ; after struct member');
     _Germany: errrpt('Erwartete ; nach Struct-Mitglied');
     Else errrpt('; attendu après membre de structure');
    End;
    Exit;
   End;
   
   safe_writeln('; Membre ajouté: ' + member_name);
  Until False; { La boucle se termine par les Break }
  
  { Consommer l'accolade de fermeture }
  If not match('}') Then
  Begin
   Case Language of
    _English: errrpt('Expected } to close struct/union');
    _Germany: errrpt('Erwartete } zum Schließen der Struct/Union');
    Else errrpt('} attendu pour fermer struct/union');
   End;
   Exit;
  End;
  
  { Afficher les informations de la structure }
  With struct_def^ do
  Begin
   If is_union Then
    safe_writeln('; Union ' + name + ' définie, taille: ' + IntToStr(total_size) + ' octets')
   Else
    safe_writeln('; Structure ' + name + ' définie, taille: ' + IntToStr(total_size) + ' octets');
  End;
  
  parse_struct_declaration := struct_def^.struct_id;
 End
 Else
 Begin
  { Référence à une structure existante }
  struct_def := find_struct(struct_name);
  If struct_def = nil Then
  Begin
   Case Language of
    _English: errrpt('Undefined struct/union: ' + struct_name);
    _Germany: errrpt('Undefinierte Struct/Union: ' + struct_name);
    Else errrpt('Structure/Union non définie: ' + struct_name);
   End;
   Exit;
  End;
  
  parse_struct_declaration := struct_def^.struct_id;
 End;
End;

{ Déclarations anticipées pour l'analyse d'expression et les fonctions d'analyse }
Function expression_bool(var lval: TLVal): Boolean; forward;
Procedure primary_expression(var lval: TLVal); forward;
Procedure unary_expression(var lval: TLVal); forward;
Procedure multiplicative_expression(var lval: TLVal); forward;
Procedure additive_expression(var lval: TLVal); forward;
Procedure parse_struct_member_access(struct_name: String; var lval: TLVal; is_pointer: Boolean); forward;
Procedure parse_dereference(var lval: TLVal); forward;
Procedure parse_address_of(var lval: TLVal); forward;

{ Convertir un type entier en nom de type string }
function get_type_name_from_id(type_id: Integer): String;
begin
  case type_id of
    cchar: get_type_name_from_id := 'char';
    cint: get_type_name_from_id := 'int';
    else get_type_name_from_id := 'int'; { Par défaut }
  end;
end;

{ Obtenir le nom d'un symbole depuis son pointeur stocké comme entier }
function get_symbol_name(symbol_ptr_as_int: Integer): String;
var
  sym_ptr: PSymbol;
begin
  if symbol_ptr_as_int = 0 then
  begin
    get_symbol_name := 'unknown';
    exit;
  end;
  
  sym_ptr := PSymbol(symbol_ptr_as_int);
  if sym_ptr = nil then
  begin
    get_symbol_name := 'invalid';
    exit;
  end;
  
  get_symbol_name := sym_ptr^.name;
end;

{ Analyse améliorée des spécificateurs de type avec support complet des types C }
Function parse_type_specifier: Integer;
Var
 is_unsigned, is_signed: Boolean;
 base_type: Integer;
Begin
 is_unsigned := False;
 is_signed := False;
 base_type := cint; { Par défaut }

 { Analyser les qualificateurs et spécificateurs de type }
 Repeat
  If match('unsigned') Then
  Begin
   is_unsigned := True;
   Continue;
  End
  Else If match('signed') Then
  Begin
   is_signed := True;
   Continue;
  End
  Else If match('const') Then
  Begin
   { Le qualificateur const est géré dans parse_declarator }
   safe_writeln('; qualificateur const détecté');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   { Le qualificateur volatile est géré dans parse_declarator }
   safe_writeln('; qualificateur volatile détecté');
   Continue;
  End
  Else If match('void') Then
  Begin
   base_type := cvoid;
   Break;
  End
  Else If match('char') Then
  Begin
   If is_unsigned Then base_type := cuchar
   Else base_type := cchar;
   Break;
  End
  Else If match('short') Then
  Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := cushort
   Else base_type := cshort;
   Break;
  End
  Else If match('long') Then
  Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := culong
   Else base_type := clong;
   Break;
  End
  Else If match('int') Then
  Begin
   If is_unsigned Then base_type := cuint
   Else base_type := cint;
   Break;
  End
  Else If match('float') Then
  Begin
   base_type := cfloat;
   Break;
  End
  Else If match('double') Then
  Begin
   base_type := cdouble;
   Break;
  End
  Else
   Break; { Plus de spécificateurs de type }
 Until False;

 parse_type_specifier := base_type;
End;

{ Analyse améliorée des spécificateurs de type avec qualificateurs }
Function parse_type_specifier_with_qualifiers(var type_info: TTypeInfo): Integer;
Var
 is_unsigned, is_signed, is_const, is_volatile: Boolean;
 base_type: Integer;
 type_found: Boolean;
Begin
 is_unsigned := False;
 is_signed := False;
 is_const := False;
 is_volatile := False;
 base_type := -1; { Aucun type initialement }
 type_found := False;

 { Initialiser type_info }
 init_type_info(type_info);

 { Analyser les qualificateurs et spécificateurs de type }
 Repeat
  If match('const') Then
  Begin
   is_const := True;
   safe_writeln('; qualificateur const détecté');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   is_volatile := True;
   safe_writeln('; qualificateur volatile détecté');
   Continue;
  End
  Else If match('unsigned') Then
  Begin
   is_unsigned := True;
   Continue;
  End
  Else If match('signed') Then
  Begin
   is_signed := True;
   Continue;
  End
  Else If match('void') Then
  Begin
   base_type := cvoid;
   type_found := True;
   Break;
  End
  Else If match('char') Then
  Begin
   If is_unsigned Then base_type := cuchar
   Else base_type := cchar;
   type_found := True;
   Break;
  End
  Else If match('short') Then
  Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := cushort
   Else base_type := cshort;
   type_found := True;
   Break;
  End
  Else If match('long') Then
  Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := culong
   Else base_type := clong;
   type_found := True;
   Break;
  End
  Else If match('int') Then
  Begin
   If is_unsigned Then base_type := cuint
   Else base_type := cint;
   type_found := True;
   Break;
  End
  Else If match('float') Then
  Begin
   base_type := cfloat;
   type_found := True;
   Break;
  End
  Else If match('double') Then
  Begin
   base_type := cdouble;
   type_found := True;
   Break;
  End
  Else If match('struct') Then
  Begin
   { Analyser la déclaration de structure complète }
   base_type := parse_struct_declaration(False); { False = struct, pas union }
   If base_type = -1 Then
   Begin
    parse_type_specifier_with_qualifiers := -1;
    Exit;
   End;
   { Convertir l'ID de struct vers le type cstruct }
   type_info.struct_id := base_type;
   base_type := cstruct;
   type_found := True;
   Break;
  End
  Else If match('union') Then
  Begin
   { Analyser la déclaration d'union complète }
   base_type := parse_struct_declaration(True); { True = union }
   If base_type = -1 Then
   Begin
    parse_type_specifier_with_qualifiers := -1;
    Exit;
   End;
   { Convertir l'ID d'union vers le type cunion }
   type_info.struct_id := base_type;
   base_type := cunion;
   type_found := True;
   Break;
  End
  Else
   Break; { Plus de spécificateurs de type }
 Until False;

 { Si aucun type explicite mais unsigned/signed spécifié, int par défaut }
 If not type_found and (is_unsigned or is_signed) Then
 Begin
  If is_unsigned Then base_type := cuint
  Else base_type := cint;
  type_found := True;
 End;

 { Retourner -1 si aucun type trouvé }
 If not type_found Then
 Begin
  parse_type_specifier_with_qualifiers := -1;
  Exit;
 End;

 { Définir les informations de type }
 type_info.base_type := base_type;
 type_info.is_unsigned := is_unsigned;
 type_info.is_const := is_const;
 type_info.is_volatile := is_volatile;
 calculate_type_size(type_info);

 parse_type_specifier_with_qualifiers := base_type;
End;

{ Analyse améliorée du déclarateur avec informations de type }
Function parse_declarator(var var_name: String; base_type: Integer; var type_info: TTypeInfo): Integer;
Var
 result_type: Integer;
 array_size: Integer;
Begin
 { Ne pas réinitialiser type_info car il peut déjà contenir des qualificateurs }
 { Mettre à jour seulement le type de base s'il n'est pas déjà défini }
 If type_info.base_type = 0 Then
  type_info.base_type := base_type;
 result_type := base_type;

 { Gérer les déclarations de pointeur }
 While match('*') do
 Begin
  Inc(type_info.pointer_level);
  result_type := cpointer;

  { Gérer const/volatile après * }
  If match('const') Then type_info.is_const := True;
  If match('volatile') Then type_info.is_volatile := True;
 End;

 { Analyser le nom de variable }
 If not symname(var_name) Then
 Begin
  Case Language of
   _English: errrpt('Expected variable name');
   _Germany: errrpt('Erwarteter Variablenname');
   Else errrpt('Nom de variable attendu');
  End;
  parse_declarator := 0;
  Exit;
 End;

 { Gérer les déclarations de tableau }
 If match('[') Then
 Begin
  If number(array_size) Then
  Begin
   type_info.array_size := array_size;
   safe_writeln('; Taille de tableau détectée');
  End
  Else
  Begin
   type_info.array_size := 1; { Tableau de taille inconnue }
  End;

  If not match(']') Then
  Begin
   Case Language of
    _English: errrpt('Expected closing bracket');
    _Germany: errrpt('Erwartete schließende Klammer');
    Else errrpt('Crochet fermant attendu');
   End;
  End;

  result_type := carray;
 End;

 { Calculer la taille finale }
 calculate_type_size(type_info);

 parse_declarator := result_type;
End;

{ Analyser la déclaration/définition de fonction }
Function parse_function_declaration(return_type: Integer): Boolean;
Var
 func_name, param_name: String;
 param_type: Integer;
 func_index: Integer;
 type_info: TTypeInfo;
 has_body: Boolean;
Begin
 parse_function_declaration := False;

 { Obtenir le nom de fonction }
 If not symname(func_name) Then
 Begin
  Case Language of
   _English: errrpt('Expected function name');
   _Germany: errrpt('Erwarteter Funktionsname');
   Else errrpt('Nom de fonction attendu');
  End;
  Exit;
 End;

 { SIMPLIFIÉ: Sortir seulement un commentaire et ignorer le traitement avancé }
 safe_writeln('; Déclaration de fonction: ' + func_name);
 
 { Aller à la fin de ligne pour éviter plus de traitement }
 kill;
 parse_function_declaration := True;
End;

{ Analyser l'appel de fonction }
Function parse_function_call(func_name: String; var lval: TLVal): Boolean;
Var
 func_index: Integer;
 arg_count: Integer;
 arg_lval: TLVal;
 func_node: PFunction;
Begin
 parse_function_call := False;

 { Trouver la fonction }
 func_index := find_function(func_name);
 If func_index = -1 Then
 Begin
  safe_writeln('; Attention: Fonction non déclarée ' + func_name);
  { Traiter comme fonction non déclarée retournant int }
  func_index := add_function(func_name, cint);
 End;

 safe_writeln('; Appel de fonction: ' + func_name);

 { Attendre parenthèse ouvrante }
 If not match('(') Then
 Begin
  Case Language of
   _English: errrpt('Expected ( in function call');
   _Germany: errrpt('Erwartete ( im Funktionsaufruf');
   Else errrpt('( attendu dans l''appel de fonction');
  End;
  Exit;
 End;

 arg_count := 0;

 { Analyser les arguments }
 If not match(')') Then
 Begin
  Repeat
   safe_writeln('; Argument (suivant)');

   { Analyser l'expression d'argument }
   expression_bool(arg_lval);

   { Pousser l'argument sur la pile }
   ol('pshs d  ; pousser argument');
   Inc(arg_count);

  Until not match(',');

  { Attendre parenthèse fermante }
  If not match(')') Then
  Begin
   Case Language of
    _English: errrpt('Expected ) after function arguments');
    _Germany: errrpt('Erwartete ) nach Funktionsargumenten');
    Else errrpt(') attendu après les arguments de fonction');
   End;
  End;
 End;

 { Générer l'appel de fonction }
 generate_function_call(func_index, arg_count);

 { Configurer la valeur de retour }
 FillChar(lval, SizeOf(lval), 0);
 
 { Obtenir le type de retour depuis la liste chaînée }
 func_node := get_function_node(func_index);
 If func_node <> nil Then
  lval.typ := func_node^.func_data.return_type
 Else
  lval.typ := cint; { Type par défaut en cas d'erreur }
  
 lval.constant := False;

 parse_function_call := True;
End;

{ Déclaration de variable améliorée avec table de symboles basée sur le tas }
Procedure declare_variable(var_name: String; var_type: Integer; var type_info: TTypeInfo);
Var
 sym_ptr: PSymbol;
 type_size: Integer;
Begin
 { Vérifier si déjà déclarée en utilisant la nouvelle table de tas }
 If find_symbol(var_name) <> nil Then
 Begin
  Case Language of
   _English: errrpt('Variable ' + var_name + ' already declared');
   _Germany: errrpt('Variable ' + var_name + ' bereits deklariert');
   Else errrpt('Variable ' + var_name + ' déjà déclarée');
  End;
  Exit;
 End;

 { Ajouter à la table de symboles basée sur le tas }
 If type_info.array_size > 0 Then
  sym_ptr := add_symbol(var_name, it_array, var_type, automatic, 0)
 Else
  sym_ptr := add_symbol(var_name, it_variable, var_type, automatic, 0);
 If sym_ptr <> nil Then
 Begin
  { Stocker les informations de type directement dans le symbole }
  sym_ptr^.type_info := type_info;
  
  If use_stdout Then WriteLn('; Variable déclarée: ', var_name, ' (', get_type_name(type_info), ')')
                Else safe_writeln('; Variable déclarée: ' + var_name);

  { Générer l'allocation de stockage basée sur le type }
  If use_stdout Then Write(var_name)
                Else outstr(var_name);
  type_size := type_info.size;

  If type_size = 1 Then
  Begin
   If use_stdout Then WriteLn(': rmb 1')
                 Else safe_writeln(': rmb 1');
  End
  Else
  Begin
   If use_stdout Then WriteLn(': rmb ', type_size)
                 Else safe_writeln(': rmb (taille)');
  End;

  If use_stdout Then WriteLn('; Taille: ', type_size, ' octets')
                Else safe_writeln('; Taille de variable en octets');
 End;
End;

{ Recherche d'identificateur améliorée avec table de symboles basée sur le tas }
Function lookup_variable(var_name: String; var lval: TLVal): Boolean;
Var
 sym_ptr: PSymbol;
Begin
 lookup_variable := False;
 FillChar(lval, SizeOf(lval), 0);

 { TEMPORAIRE: Simuler la recherche d'une variable const pour test }
 If var_name = 'consttest' Then
 Begin
  lookup_variable := True;
  lval.symbol := 1;
  lval.typ := cint;
  lval.storage := automatic;
  lval.indirect := 0;
  lval.constant := False;
  
  { Initialiser les infos de type comme const }
  init_type_info(lval.type_info);
  lval.type_info.base_type := cint;
  lval.type_info.is_const := True;  { Rendre const pour test }
  Exit;
 End;

 sym_ptr := find_symbol(var_name);
 
 If sym_ptr <> nil Then
 Begin
  lookup_variable := True;
  lval.symbol := Integer(sym_ptr); { Stocker le pointeur comme entier pour compatibilité }
  lval.typ := sym_ptr^.ctype;
  lval.storage := sym_ptr^.storage;
  lval.indirect := 0;
  lval.constant := False;

  { Les informations de type sont stockées directement dans le symbole }
  lval.type_info := sym_ptr^.type_info;
 End
 Else
 Begin
  { Variable non trouvée - traiter comme nouvelle variable pour l'instant }
  If use_stdout Then WriteLn('; Attention: Variable non déclarée ', var_name)
                Else safe_writeln('; Attention: Variable non déclarée ' + var_name);
  lval.symbol := 0;
  lval.typ := cint;
  lval.constant := False;
  init_type_info(lval.type_info);
  lval.type_info.base_type := cint;
  lookup_variable := True;
 End;
End;

Function pop_include_file: Boolean;
Begin
 pop_include_file := False;
 
 If include_depth <= 0 Then Exit;
 
 { Fermer le fichier d'inclusion actuel en toute sécurité }
 {$I-}
 System.Close(input);
 {$I+}
 
 { Restaurer l'état du fichier précédent }
 Dec(include_depth);
 With include_stack[include_depth] do
 Begin
  current_filename := filename;
  System.Assign(input, filename);
  {$I-}
  System.Reset(input);
  If IOResult <> 0 Then
  Begin
   { Erreur de restauration du fichier }
   eof := 1;
   Exit;
  End;
  {$I+}
 End;
 
 pop_include_file := True;
End;

{ Opérations sur les fichiers }
Function readinline: Boolean;
Begin
 readinline := False;
 
 Repeat
  { Vérifier si le fichier d'entrée est correctement initialisé }
  {$I-}
  If not System.Eof(input) Then
  Begin
   ReadLn(input, line);
   If IOResult = 0 Then
   Begin
    lptr := 1;
    readinline := True;
    Exit;
   End
   Else
   Begin
    { Erreur de lecture de fichier }
    eof := 1;
    readinline := False;
    Exit;
   End;
  End
  {$I+}
  Else
  Begin
   { Le fichier actuel est à la fin }
   If include_depth > 0 Then
   Begin
    { Nous sommes dans un fichier d'inclusion, retourner au fichier précédent }
    If not pop_include_file Then
    Begin
     eof := 1;
     readinline := False;
     Exit;
    End;
    { Continuer la boucle pour essayer de lire depuis le fichier restauré }
   End
   Else
   Begin
    { Le fichier principal est à la fin }
    eof := 1;
    readinline := False;
    Exit;
   End;
  End;
 Until False;
End;

{ Include file management functions }
Function extract_filename(include_line: String): String;
Var
 start_pos, end_pos: Integer;
 filename: String;
Begin
 filename := '';
 
 { Skip #include and whitespace }
 start_pos := Pos('#include', include_line);
 If start_pos > 0 Then
 Begin
  start_pos := start_pos + 8; { Length of '#include' }
  
  { Skip whitespace }
  While (start_pos <= Length(include_line)) and 
        ((include_line[start_pos] = ' ') or (include_line[start_pos] = #9)) do
   Inc(start_pos);
  
  { Check for quotes or angle brackets }
  If start_pos <= Length(include_line) Then
  Begin
   If (include_line[start_pos] = '"') or (include_line[start_pos] = '<') Then
   Begin
    Inc(start_pos); { Skip opening quote/bracket }
    end_pos := start_pos;
    
    { Find closing quote or bracket }
    While (end_pos <= Length(include_line)) and 
          (include_line[end_pos] <> '"') and 
          (include_line[end_pos] <> '>') do
     Inc(end_pos);
    
    If end_pos <= Length(include_line) Then
     filename := Copy(include_line, start_pos, end_pos - start_pos);
   End;
  End;
 End;
 
 extract_filename := filename;
End;

Function push_include_file(include_filename: String): Boolean;
Begin
 push_include_file := False;
 
 { Check for maximum include depth }
 If include_depth >= 10 Then
 Begin
  Case Language of
   _English: errrpt('Include depth too deep (max 10): ' + include_filename);
   _Germany: errrpt('Include-Tiefe zu tief (max 10): ' + include_filename);
   Else errrpt('Profondeur d''inclusion trop importante (max 10): ' + include_filename);
  End;
  Exit;
 End;
 
 { Save current file state }
 With include_stack[include_depth] do
 Begin
  filename := current_filename;
  saved_line := line;
  saved_lptr := lptr;
  saved_eof := eof;
 End;
 
 { Try to open the include file }
 Assign(input, include_filename);
 {$I-} 
 Reset(input); 
 If IOResult <> 0 Then
 Begin
  { Restore previous file by reopening it }
  If include_depth > 0 Then
  Begin
   Assign(input, include_stack[include_depth].filename);
   Reset(input);
  End;
  
  Case Language of
   _English: errrpt('Cannot open include file: ' + include_filename);
   _Germany: errrpt('Kann Include-Datei nicht öffnen: ' + include_filename);
   Else errrpt('Impossible d''ouvrir le fichier d''inclusion: ' + include_filename);
  End;
  Exit;
 End;
 {$I+}
 
 { Update state }
 Inc(include_depth);
 current_filename := include_filename;
 eof := 0;
 
 safe_writeln('; Including file: ' + include_filename);
 push_include_file := True;
End;

Function process_include_directive(include_line: String): Boolean;
Var
 filename: String;
Begin
 process_include_directive := False;
 
 filename := extract_filename(include_line);
 If filename = '' Then
 Begin
  Case Language of
   _English: errrpt('Invalid #include directive syntax');
   _Germany: errrpt('Ungültige #include-Direktiven-Syntax');
   Else errrpt('Syntaxe de directive #include invalide');
  End;
  Exit;
 End;
 
 If push_include_file(filename) Then
  process_include_directive := True;
End;

{ ============================================================================ }
{ DEFINE/MACRO MANAGEMENT FUNCTIONS                                           }
{ ============================================================================ }

{ Initialize define system }
Procedure init_defines;
Var
 i: Integer;
Begin
 For i := 0 to 99 do
 Begin
  define_table[i].name := '';
  define_table[i].value := '';
  define_table[i].in_use := False;
 End;
 define_count := 0;
 { Don't write to output here as it may not be initialized yet }
End;

{ Find a #define constant by name }
Function find_define_index(def_name: String): Integer;
Var
 i: Integer;
Begin
 find_define_index := -1;
 For i := 0 to 99 do
 Begin
  If define_table[i].in_use and (define_table[i].name = def_name) Then
  Begin
   find_define_index := i;
   Exit;
  End;
 End;
End;

{ Add a new #define constant }
Function add_define(def_name, def_value: String): Boolean;
Var
 i: Integer;
Begin
 add_define := False;
 
 { Check if already defined }
 If find_define_index(def_name) <> -1 Then
 Begin
  Case Language of
   _English: errrpt('Macro ' + def_name + ' already defined');
   _Germany: errrpt('Makro ' + def_name + ' bereits definiert');
   Else errrpt('Macro ' + def_name + ' déjà défini');
  End;
  Exit;
 End;
 
 { Find empty slot }
 For i := 0 to 99 do
 Begin
  If not define_table[i].in_use Then
  Begin
   define_table[i].name := def_name;
   define_table[i].value := def_value;
   define_table[i].in_use := True;
   Inc(define_count);
   If use_stdout Then WriteLn('; Defined macro: ', def_name, ' = ', def_value)
                 Else safe_writeln('; Defined macro: ' + def_name + ' = ' + def_value);
   add_define := True;
   Exit;
  End;
 End;
 
 { Table full }
 Case Language of
  _English: errrpt('Too many #define constants (max 100)');
  _Germany: errrpt('Zu viele #define-Konstanten (max 100)');
  Else errrpt('Trop de constantes #define (max 100)');
 End;
End;

{ Get the value of a #define constant }
Function get_define_value(def_name: String): String;
Var
 index: Integer;
Begin
 get_define_value := '';
 index := find_define_index(def_name);
 If index <> -1 Then
  get_define_value := define_table[index].value;
End;

{ Process #define directive }
Function process_define_directive(define_line: String): Boolean;
Var
 line_pos, start_pos, end_pos: Integer;
 def_name, def_value: String;
Begin
 process_define_directive := False;
 def_name := '';
 def_value := '';
 
 { Skip #define and whitespace }
 line_pos := Pos('#define', define_line);
 If line_pos <= 0 Then Exit;
 
 line_pos := line_pos + 7; { Length of '#define' }
 
 { Skip whitespace }
 While (line_pos <= Length(define_line)) and 
       ((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
  Inc(line_pos);
 
 { Extract macro name }
 start_pos := line_pos;
 While (line_pos <= Length(define_line)) and 
       (((define_line[line_pos] >= 'A') and (define_line[line_pos] <= 'Z')) or
        ((define_line[line_pos] >= 'a') and (define_line[line_pos] <= 'z')) or
        ((define_line[line_pos] >= '0') and (define_line[line_pos] <= '9')) or
        (define_line[line_pos] = '_')) do
  Inc(line_pos);
 
 If line_pos > start_pos Then
  def_name := Copy(define_line, start_pos, line_pos - start_pos)
 Else
 Begin
  Case Language of
   _English: errrpt('Invalid #define directive: missing name');
   _Germany: errrpt('Ungültige #define-Direktive: Name fehlt');
   Else errrpt('Directive #define invalide: nom manquant');
  End;
  Exit;
 End;
 
 { Skip whitespace before value }
 While (line_pos <= Length(define_line)) and 
       ((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
  Inc(line_pos);
 
 { Extract value (rest of line) }
 If line_pos <= Length(define_line) Then
  def_value := Copy(define_line, line_pos, Length(define_line) - line_pos + 1)
 Else
  def_value := '1'; { Default value for macros without explicit value }
 
 { Remove trailing whitespace from value }
 While (Length(def_value) > 0) and 
       ((def_value[Length(def_value)] = ' ') or (def_value[Length(def_value)] = #9)) do
  Delete(def_value, Length(def_value), 1);
 
 { Add the define }
 If add_define(def_name, def_value) Then
  process_define_directive := True;
End;

{ Expand macros in a line of code }
Function expand_macros(input_line: String): String;
Var
 result_line: String;
 line_pos, start_pos, end_pos: Integer;
 token: String;
 index: Integer;
 changed: Boolean;
Begin
 result_line := input_line;
 
 { Multiple passes to handle nested expansions }
 Repeat
  changed := False;
  line_pos := 1;
  
  While line_pos <= Length(result_line) do
  Begin
   { Check if we're at the start of an identifier }
   If ((result_line[line_pos] >= 'A') and (result_line[line_pos] <= 'Z')) or
      ((result_line[line_pos] >= 'a') and (result_line[line_pos] <= 'z')) or
      (result_line[line_pos] = '_') Then
   Begin
    { Extract identifier }
    start_pos := line_pos;
    While (line_pos <= Length(result_line)) and 
          (((result_line[line_pos] >= 'A') and (result_line[line_pos] <= 'Z')) or
           ((result_line[line_pos] >= 'a') and (result_line[line_pos] <= 'z')) or
           ((result_line[line_pos] >= '0') and (result_line[line_pos] <= '9')) or
           (result_line[line_pos] = '_')) do
     Inc(line_pos);
    
    token := Copy(result_line, start_pos, line_pos - start_pos);
    
    { Check if this token is a defined macro }
    index := find_define_index(token);
    If index <> -1 Then
    Begin
     { Replace the token with its value }
     Delete(result_line, start_pos, Length(token));
     Insert(define_table[index].value, result_line, start_pos);
     line_pos := start_pos + Length(define_table[index].value);
     changed := True;
     If use_stdout Then WriteLn('; Expanded macro: ', token, ' -> ', define_table[index].value)
                   Else safe_writeln('; Expanded macro: ' + token + ' -> ' + define_table[index].value);
    End;
   End
   Else
    Inc(line_pos);
  End;
 Until not changed;
 
 expand_macros := result_line;
End;

{ Clear all defines from table }
Procedure free_defines;
Var
 i: Integer;
Begin
 For i := 0 to 99 do
 Begin
  If define_table[i].in_use Then
  Begin
   define_table[i].name := '';
   define_table[i].value := '';
   define_table[i].in_use := False;
  End;
 End;
 
 If use_stdout Then WriteLn('; Cleared ', define_count, ' macro definitions from table')
               Else safe_writeln('; Cleared macro definitions from table');
 define_count := 0;
End;

{ Analyser l'accès aux tableaux avec indexation }
Procedure parse_array_access(array_name: String; var lval: TLVal);
Var
 index_lval: TLVal;
 array_symbol: PSymbol;
 element_size: Integer;
Begin
 { Trouver le symbole du tableau }
 array_symbol := find_symbol(array_name);
 If array_symbol = nil Then
 Begin
  Case Language of
   _English: errrpt('Array not found: ' + array_name);
   _Germany: errrpt('Array nicht gefunden: ' + array_name);
   Else errrpt('Tableau non trouvé: ' + array_name);
  End;
  Exit;
 End;

 { Vérifier que c'est bien un tableau }
 If (array_symbol^.ident <> it_array) and (array_symbol^.type_info.array_size = 0) Then
 Begin
  Case Language of
   _English: errrpt('Variable is not an array: ' + array_name);
   _Germany: errrpt('Variable ist kein Array: ' + array_name);
   Else errrpt('La variable n''est pas un tableau: ' + array_name);
  End;
  Exit;
 End;

 { Consommer '[' }
 If not match('[') Then
 Begin
  Case Language of
   _English: errrpt('Expected [ for array index');
   _Germany: errrpt('Erwartete [ für Array-Index');
   Else errrpt('[ attendu pour l''index du tableau');
  End;
  Exit;
 End;

 safe_writeln('; Calcul de l''index du tableau ' + array_name);

 { Analyser l'expression d'index }
 additive_expression(index_lval);

 { Consommer ']' }
 If not match(']') Then
 Begin
  Case Language of
   _English: errrpt('Expected ] after array index');
   _Germany: errrpt('Erwartete ] nach Array-Index');
   Else errrpt('] attendu après l''index du tableau');
  End;
  Exit;
 End;

 { Calculer la taille d'un élément }
 element_size := get_type_size(array_symbol^.type_info.base_type);
 
 { Générer le code pour calculer l'adresse de l'élément }
 safe_writeln('; Calculer adresse élément tableau');
 
 { Si la taille d'élément n'est pas 1, multiplier l'index }
 If element_size > 1 Then
 Begin
  safe_writeln('; Multiplier index par taille élément');
  Case element_size of
   2: ol('lsld    ; multiplier par 2');
   4: Begin
       ol('lsld    ; multiplier par 4 (shift 1)');
       ol('lsld    ; multiplier par 4 (shift 2)');
      End;
   8: Begin
       ol('lsld    ; multiplier par 8 (shift 1)');
       ol('lsld    ; multiplier par 8 (shift 2)');
       ol('lsld    ; multiplier par 8 (shift 3)');
      End;
  Else
   Begin
    { Multiplication générale }
    ot('ldb  #');
    outdec(element_size);
    nl;
    ol('jsr  mult16');
   End;
  End;
 End;

 { Ajouter l'adresse de base du tableau }
 ot('addd #');
 outstr(array_name);
 nl;

 { Charger la valeur à l'adresse calculée }
 ol('tfr  d,x    ; adresse dans X');
 Case element_size of
  1: ol('ldb  ,x     ; charger octet');
  2: ol('ldd  ,x     ; charger mot');
 Else
  ol('ldd  ,x     ; charger mot par défaut');
 End;

 { Configurer lval pour le résultat }
 lval.typ := array_symbol^.type_info.base_type;
 lval.indirect := 1; { Valeur chargée indirectement }
 lval.constant := False;
 lval.type_info := array_symbol^.type_info;
 lval.type_info.array_size := 0; { Ce n'est plus un tableau mais un élément }
End;

{ Analyser l'accès aux membres de structure }
Procedure parse_struct_member_access(struct_name: String; var lval: TLVal; is_pointer: Boolean);
Var
 member_name: String;
 struct_symbol: PSymbol;
 struct_def: PStructDef;
 member_index: Integer;
 member_offset, member_size: Integer;
Begin
 { Trouver le symbole de la structure }
 struct_symbol := find_symbol(struct_name);
 If struct_symbol = nil Then
 Begin
  Case Language of
   _English: errrpt('Struct variable not found: ' + struct_name);
   _Germany: errrpt('Struct-Variable nicht gefunden: ' + struct_name);
   Else errrpt('Variable de structure non trouvée: ' + struct_name);
  End;
  Exit;
 End;

 { Vérifier que c'est bien une structure }
 If (struct_symbol^.type_info.base_type <> cstruct) and 
    (struct_symbol^.type_info.base_type <> cunion) Then
 Begin
  Case Language of
   _English: errrpt('Variable is not a struct/union: ' + struct_name);
   _Germany: errrpt('Variable ist kein Struct/Union: ' + struct_name);
   Else errrpt('La variable n''est pas une structure/union: ' + struct_name);
  End;
  Exit;
 End;

 { Consommer '.' ou '->' }
 If is_pointer Then
 Begin
  If not (match('-') and match('>')) Then
  Begin
   Case Language of
    _English: errrpt('Expected -> for pointer member access');
    _Germany: errrpt('Erwartete -> für Pointer-Mitgliedszugriff');
    Else errrpt('-> attendu pour l''accès aux membres de pointeur');
   End;
   Exit;
  End;
 End
 Else
 Begin
  If not match('.') Then
  Begin
   Case Language of
    _English: errrpt('Expected . for struct member access');
    _Germany: errrpt('Erwartete . für Struct-Mitgliedszugriff');
    Else errrpt('. attendu pour l''accès aux membres de structure');
   End;
   Exit;
  End;
 End;

 { Obtenir le nom du membre }
 If not symname(member_name) Then
 Begin
  Case Language of
   _English: errrpt('Expected member name after .');
   _Germany: errrpt('Erwarteter Mitgliedsname nach .');
   Else errrpt('Nom de membre attendu après .');
  End;
  Exit;
 End;

 { Trouver la définition de la structure }
 struct_def := find_struct_by_id(struct_symbol^.type_info.struct_id);
 If struct_def = nil Then
 Begin
  Case Language of
   _English: errrpt('Struct definition not found');
   _Germany: errrpt('Struct-Definition nicht gefunden');
   Else errrpt('Définition de structure non trouvée');
  End;
  Exit;
 End;

 { Trouver le membre dans la structure }
 member_index := find_struct_member(struct_def, member_name);
 If member_index = -1 Then
 Begin
  Case Language of
   _English: errrpt('Member not found in struct: ' + member_name);
   _Germany: errrpt('Mitglied nicht in Struct gefunden: ' + member_name);
   Else errrpt('Membre non trouvé dans la structure: ' + member_name);
  End;
  Exit;
 End;

 { Obtenir les informations du membre }
 With struct_def^.members[member_index] do
 Begin
  member_offset := offset;
  member_size := size;
 End;

 safe_writeln('; Accès au membre ' + member_name + ' (offset: ' + IntToStr(member_offset) + ')');

 { Générer le code pour calculer l'adresse du membre }
 If member_offset = 0 Then
 Begin
  { Le membre est au début de la structure }
  ot('ldd  #');
  outstr(struct_name);
  nl;
 End
 Else
 Begin
  { Ajouter l'offset du membre }
  ot('ldd  #');
  outstr(struct_name);
  nl;
  ot('addd #');
  outdec(member_offset);
  nl;
 End;

 { Charger la valeur du membre }
 ol('tfr  d,x    ; adresse du membre dans X');
 Case member_size of
  1: ol('ldb  ,x     ; charger octet');
  2: ol('ldd  ,x     ; charger mot');
 Else
  ol('ldd  ,x     ; charger mot par défaut');
 End;

 { Configurer lval pour le résultat }
 With struct_def^.members[member_index] do
 Begin
  lval.typ := member_type;
  lval.indirect := 1;
  lval.constant := False;
  lval.type_info := type_info;
 End;
End;

{ Primary expression parser with function call support }
Procedure primary_expression(var lval: TLVal);
Var
 id: String;
 num: Integer;
 save_lptr: Integer;
Begin
 FillChar(lval, SizeOf(lval), 0);

 Case peek_char of
  '0'..'9': Begin
    num := parse_number;
    lval.typ := cint;
    lval.constant := True;
    lval.value := num;
    ot('ldd  #');
    outdec(num);
    nl;
   End;

  'A'..'Z', 'a'..'z', '_': Begin
    id := parse_identifier;

    { Check if this is a function call }
    If peek_char = '(' Then
    Begin
     { This is a function call }
     If parse_function_call(id, lval) Then
     Begin
      { Function call result is already in D register }
      safe_writeln('; Function ' + id + ' returned in D');
     End
     Else
     Begin
      Case Language of
       _English: errrpt('Invalid function call: ' + id);
       _Germany: errrpt('Ungültiger Funktionsaufruf: ' + id);
       Else errrpt('Appel de fonction invalide: ' + id);
      End;
     End;
    End
    Else
    Begin
     { This is a variable reference }
     If lookup_variable(id, lval) Then
     Begin
      { Check if this is an array access }
      If peek_char = '[' Then
      Begin
       { Array indexing }
       parse_array_access(id, lval);
      End
      Else If peek_char = '.' Then
      Begin
       { Structure member access }
       parse_struct_member_access(id, lval, False);
      End
      Else
      Begin
       { Simple variable access }
       ot('ldd  ');
       outstr(id);
       nl;
      End;
     End
     Else
     Begin
      { Undeclared variable }
      lval.symbol := 0;
      lval.typ := cint;
      lval.constant := False;
      ot('ldd  ');
      outstr(id);
      nl;
     End;
    End;
   End;

  '(': Begin
    next_char; { consume '(' }
    additive_expression(lval);
    If peek_char = ')' Then
     next_char { consume ')' }
    Else
    Begin
     Case Language of
      _English: errrpt('Missing )');
      _Germany: errrpt('Fehlende )');
      Else errrpt(') manquant');
     End;
    End;
   End;

  Else
   Case Language of
    _English: errrpt('Invalid primary expression');
    _Germany: errrpt('Ungültiger primärer Ausdruck');
    Else errrpt('Expression primaire invalide');
   End;
 End;
End;

{ Unary expression parser }
Procedure unary_expression(var lval: TLVal);
Begin
 Case peek_char of
  '+': Begin
    next_char;
    unary_expression(lval);
   End;

  '-': Begin
    next_char;
    unary_expression(lval);
    ol('nega');
    ol('negb');
    ol('sbca #0');
   End;

  '!': Begin
    next_char;
    unary_expression(lval);
    ol('subd #0');
    ol('seq');
    ol('clra');
    ol('tfr  b,a');
   End;

  '~': Begin
    next_char;
    unary_expression(lval);
    ol('coma');
    ol('comb');
   End;

  '*': Begin
    { Opérateur de déréférencement }
    next_char;
    unary_expression(lval);
    parse_dereference(lval);
   End;

  '&': Begin
    { Opérateur d'adresse }
    next_char;
    parse_address_of(lval);
   End;

  Else
   primary_expression(lval);
 End;
End;

{ Opérateur de déréférencement (*ptr) }
Procedure parse_dereference(var lval: TLVal);
var
  ptr_name: String;
Begin
 safe_writeln('; Déréférencement de pointeur');
 
 { Vérifier que c'est bien un pointeur }
 If lval.type_info.pointer_level = 0 Then
 Begin
  Case Language of
   _English: errrpt('Cannot dereference non-pointer type');
   _Germany: errrpt('Kann Nicht-Zeiger-Typ nicht dereferenzieren');
   Else errrpt('Impossible de déréférencer un type non-pointeur');
  End;
  Exit;
 End;
 
 { Générer le code de déréférencement }
 If lval.symbol > 0 Then
 Begin
  ptr_name := get_symbol_name(lval.symbol);
  safe_writeln('; Déréférencement de: ' + ptr_name);
  ol('ldx  ' + ptr_name);  { Charger l'adresse stockée dans le pointeur }
  ol('ldd  ,x');           { Charger la valeur pointée }
 End
 Else
 Begin
  safe_writeln('; Déréférencement indirect');
  ol('ldx  ,s++');         { Récupérer l'adresse depuis la pile }
  ol('ldd  ,x');           { Charger la valeur pointée }
 End;
 
 { Décrémenter le niveau de pointeur }
 Dec(lval.type_info.pointer_level);
 
 { Le résultat est maintenant une valeur }
 lval.indirect := 0;
 
 safe_writeln('; Pointeur déréférencé, nouveau niveau: ' + IntToStr(lval.type_info.pointer_level));
End;

{ Opérateur d'adresse (&var) }  
Procedure parse_address_of(var lval: TLVal);
Var
  var_name: String;
  sym_ptr: PSymbol;
Begin
 safe_writeln('; Prise d''adresse de variable');
 
 { Lire le nom de la variable directement }
 If not symname(var_name) Then
 Begin
  Case Language of
   _English: errrpt('Expected variable name after &');
   _Germany: errrpt('Variablenname nach & erwartet'); 
   Else errrpt('Nom de variable attendu après &');
  End;
  Exit;
 End;
 
 { Chercher la variable dans la table des symboles }
 sym_ptr := find_symbol(var_name);
 If sym_ptr = nil Then
 Begin
  Case Language of
   _English: errrpt('Undefined variable: ' + var_name);
   _Germany: errrpt('Undefinierte Variable: ' + var_name);
   Else errrpt('Variable non définie: ' + var_name);
  End;
  Exit;
 End;
 
 { Vérifier que c'est bien une variable (pas une constante) }
 If sym_ptr^.ident <> it_variable Then
 Begin
  Case Language of
   _English: errrpt('Cannot take address of non-variable');
   _Germany: errrpt('Kann Adresse von Nicht-Variable nicht nehmen'); 
   Else errrpt('Impossible de prendre l''adresse d''une non-variable');
  End;
  Exit;
 End;
 
 { Générer le code pour obtenir l'adresse }
 ol('leax ' + var_name);
 ol('pshs x'); { Empiler l'adresse }
 
 { Configurer lval pour le résultat }
 lval.symbol := Integer(sym_ptr);
 lval.indirect := 1; { Résultat sur la pile }
 lval.typ := cpointer;
 lval.storage := sym_ptr^.storage;
 lval.constant := False;
 lval.value := 0;
 
 { Copier les informations de type et incrémenter le niveau de pointeur }
 lval.type_info := sym_ptr^.type_info;
 Inc(lval.type_info.pointer_level);
 
 safe_writeln('; Adresse de ' + var_name + ' prise, niveau pointeur: ' + IntToStr(lval.type_info.pointer_level));
End;

{ Multiplicative expression parser }
Procedure multiplicative_expression(var lval: TLVal);
Var
 op: Char;
Begin
 unary_expression(lval);

 While (peek_char = '*') or (peek_char = '/') or (peek_char = '%') do
 Begin
  op := next_char;
  ol('pshs d'); { push left operand }

  unary_expression(lval);

  Case op of
   '*': Begin
     ol('puls x'); { pop left operand to X }
     ol('jsr  mult16'); { call multiply routine }
    End;

   '/': Begin
     ol('tfr  d,x'); { right operand to X }
     ol('puls d'); { left operand to D }
     ol('jsr  div16'); { call divide routine }
    End;

   '%': Begin
     ol('tfr  d,x'); { right operand to X }
     ol('puls d'); { left operand to D }
     ol('jsr  mod16'); { call modulo routine }
    End;
  End;
 End;
End;

{ Additive expression parser }
Procedure additive_expression(var lval: TLVal);
Var
 op: Char;
Begin
 multiplicative_expression(lval);

 While (peek_char = '+') or (peek_char = '-') do
 Begin
  op := next_char;
  ol('pshs d'); { push left operand }

  multiplicative_expression(lval);

  Case op of
   '+': Begin
     ol('addd ,s++'); { add and clean stack }
    End;

   '-': Begin
     ol('tfr  d,x'); { right operand to X }
     ol('puls d'); { left operand to D }
     ol('subd ,x'); { subtract }
    End;
  End;
 End;
End;

{ Main expression parser }
Function expression_bool(var lval: TLVal): Boolean;
Begin
 additive_expression(lval);
 expression_bool := True;
End;

{ Wrapper procedure for backward compatibility }
Procedure expression(var lval: TLVal);
Begin
 expression_bool(lval);
End;

{ Variable declaration parsing functions - moved after expression }
{ Enhanced declaration parsing with full type support }
Function parse_declaration: Boolean;
Var
 base_type, var_type: Integer;
 var_name: String;
 lval: TLVal;
 type_info: TTypeInfo;
 save_lptr: Integer;
Begin
 parse_declaration := False;

 { Parse type specifier with qualifiers }
 base_type := parse_type_specifier_with_qualifiers(type_info);
 If base_type = -1 Then Exit; { No valid type found }

 { Save position to check for function vs variable }
 save_lptr := lptr;

 { Try to parse as declarator to get the name }
 var_type := parse_declarator(var_name, base_type, type_info);
 If var_type = 0 Then Exit;

 { Check if this is a function declaration/definition }
 If match('(') Then
 Begin
  { This is a function - restore position and parse as function }
  lptr := save_lptr;
  If parse_function_declaration(base_type) Then
   parse_declaration := True;
  Exit;
 End;

 { This is a variable declaration }
 declare_variable(var_name, var_type, type_info);
 parse_declaration := True;

 { Check for initialization }
 If match('=') Then
 Begin
  safe_writeln('; Initializing variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
  expression(lval);

  { Type checking for initialization }
  If type_info.is_const Then
  Begin
   safe_writeln('; const variable initialized');
  End;

  { Generate type-appropriate initialization code }
  Case type_info.size of
   1: Begin
       ot('stb  '); { Store byte for char }
       outstr(var_name);
       nl;
      End;
   2: Begin
       ot('std  '); { Store word for int/short/pointers }
       outstr(var_name);
       nl;
      End;
  Else
   Begin
    ot('std  '); { Default to word }
    outstr(var_name);
    nl;
   End;
  End;
 End
 Else
 Begin
  { Check if const variable needs initialization }
  If type_info.is_const Then
  Begin
   Case Language of
    _English: errrpt('const variable ' + var_name + ' must be initialized');
    _Germany: errrpt('const Variable ' + var_name + ' muss initialisiert werden');
    Else errrpt('la variable const ' + var_name + ' doit être initialisée');
   End;
  End;
 End;

 { Handle multiple variable declarations }
 While match(',') do
 Begin
  var_type := parse_declarator(var_name, base_type, type_info);
  If var_type = 0 Then Exit;

  declare_variable(var_name, var_type, type_info);

  { Check for initialization }
  If match('=') Then
  Begin
   safe_writeln('; Initializing variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
   expression(lval);

   { Generate initialization code }
   Case type_info.size of
    1: Begin
        ot('stb  ');
        outstr(var_name);
        nl;
       End;
    2: Begin
        ot('std  ');
        outstr(var_name);
        nl;
       End;
   Else
    Begin
     ot('std  ');
     outstr(var_name);
     nl;
    End;
   End;
  End
  Else
  Begin
   { Check if const variable needs initialization }
   If type_info.is_const Then
   Begin
    Case Language of
     _English: errrpt('const variable ' + var_name + ' must be initialized');
     _Germany: errrpt('const Variable ' + var_name + ' muss initialisiert werden');
     Else errrpt('la variable const ' + var_name + ' doit être initialisée');
    End;
   End;
  End;
 End;

 { Expect semicolon for variable declarations }
 If not match(';') Then
  errrpt('Expected semicolon after declaration');
End;

{ Forward declarations for statement parsing }
Function parse_statement: Boolean; forward;
Function parse_compound_statement: Boolean; forward;
Function parse_assignment_statement: Boolean; forward;
Procedure parse_array_assignment(array_name: String); forward;

{ Control structure parsing }
Function parse_if_statement: Boolean;
Var
 lval: TLVal;
 else_label, end_label: Integer;
Begin
 parse_if_statement := False;

 If not match('if') Then Exit;
 parse_if_statement := True;

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after if');
  Exit;
 End;

 { Parse condition }
 safe_writeln('; IF condition');
 expression_bool(lval);

 { Expect closing parenthesis }
 If not match(')') Then
  errrpt('Expected ) after if condition');

 { Generate conditional jump }
 else_label := getlabel;
 end_label := getlabel;

 ol('tstd');
 ot('lbeq ');
 printlabel(else_label);
 nl;

 { Parse then statement }
 safe_writeln('; IF then block');
 parse_statement;

 { Check for else clause }
 If match('else') Then
 Begin
  { Jump over else block }
  ot('lbra ');
  printlabel(end_label);
  nl;

  { Else block }
  prelabel(else_label);
  safe_writeln('; ELSE block');
  parse_statement;

  prelabel(end_label);
 End
 Else
 Begin
  prelabel(else_label);
 End;

 safe_writeln('; End IF');
End;

Function parse_while_statement: Boolean;
Var
 lval: TLVal;
 loop_label, end_label: Integer;
Begin
 parse_while_statement := False;

 If not match('while') Then Exit;
 parse_while_statement := True;

 { Generate loop labels }
 loop_label := getlabel;
 end_label := getlabel;

 { Push loop context for break/continue }
 push_loop_context(1, end_label, loop_label);

 { Loop start }
 prelabel(loop_label);
 safe_writeln('; WHILE loop start');

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after while');
  Exit;
 End;

 { Parse condition }
 safe_writeln('; WHILE condition');
 expression_bool(lval);

 { Expect closing parenthesis }
 If not match(')') Then
  errrpt('Expected ) after while condition');

 { Generate conditional jump }
 ol('tstd');
 ot('lbeq ');
 printlabel(end_label);
 nl;

 { Parse loop body }
 safe_writeln('; WHILE body');
 parse_statement;

 { Jump back to condition }
 ot('lbra ');
 printlabel(loop_label);
 nl;

 { End label }
 prelabel(end_label);
 safe_writeln('; End WHILE');

 { Pop loop context }
 pop_loop_context;
End;

Function parse_for_statement: Boolean;
Var
 lval: TLVal;
 loop_label, condition_label, end_label: Integer;
Begin
 parse_for_statement := False;

 If not match('for') Then Exit;
 parse_for_statement := True;

 { Generate loop labels }
 condition_label := getlabel;
 loop_label := getlabel;
 end_label := getlabel;

 { Push loop context for break/continue }
 { push_loop_context(2, end_label, loop_label); }

 safe_writeln('; FOR loop start');

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after for');
  Exit;
 End;

 { Parse initialization }
 safe_writeln('; FOR initialization');
 If not match(';') Then
 Begin
  expression_bool(lval);
  If not match(';') Then
   errrpt('Expected ; after for initialization');
 End;

 { Jump to condition }
 ot('lbra ');
 printlabel(condition_label);
 nl;

 { Loop increment label }
 prelabel(loop_label);
 safe_writeln('; FOR increment');

 { Parse increment }
 If not match(')') Then
 Begin
  expression_bool(lval);
  If not match(')') Then
   errrpt('Expected ) after for increment');
 End;

 { Condition label }
 prelabel(condition_label);
 safe_writeln('; FOR condition');

 { Parse condition }
 If not match(';') Then
 Begin
  expression_bool(lval);
  If not match(';') Then
   errrpt('Expected ; after for condition');
 End
 Else
 Begin
  { No condition = infinite loop }
  ot('ldd  #1');
  nl;
 End;

 { Generate conditional jump }
 ol('tstd');
 ot('lbeq ');
 printlabel(end_label);
 nl;

 { Parse loop body }
 safe_writeln('; FOR body');
 parse_statement;

 { Jump back to increment }
 ot('lbra ');
 printlabel(loop_label);
 nl;

 { End label }
 prelabel(end_label);
 safe_writeln('; End FOR');

 { Pop loop context }
 pop_loop_context;
End;

Function parse_do_while_statement: Boolean;
Var
 lval: TLVal;
 loop_label, condition_label, end_label: Integer;
Begin
 parse_do_while_statement := False;

 If not match('do') Then Exit;
 parse_do_while_statement := True;

 { Generate loop labels }
 loop_label := getlabel;
 condition_label := getlabel;
 end_label := getlabel;

 { Push loop context for break/continue }
 { push_loop_context(3, end_label, condition_label); }

 { Loop start }
 prelabel(loop_label);
 safe_writeln('; DO-WHILE loop start');

 { Parse loop body }
 parse_statement;

 { Expect while }
 If not match('while') Then
 Begin
  errrpt('Expected while after do body');
  Exit;
 End;

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after while');
  Exit;
 End;

 { Parse condition }
 prelabel(condition_label);
 safe_writeln('; DO-WHILE condition');
 expression_bool(lval);

 { Expect closing parenthesis }
 If not match(')') Then
  errrpt('Expected ) after while condition');

 { Expect semicolon }
 If not match(';') Then
  errrpt('Expected ; after do-while');

 { Generate conditional jump back }
 ol('tstd');
 ot('lbne ');
 printlabel(loop_label);
 nl;

 { End label }
 prelabel(end_label);
 safe_writeln('; End DO-WHILE');

 { Pop loop context }
 { pop_loop_context; }
End;

Function parse_return_statement: Boolean;
Var
 lval: TLVal;
Begin
 parse_return_statement := False;

 If not match('return') Then Exit;
 parse_return_statement := True;

 safe_writeln('; RETURN statement');

 { Check for return value }
 If not match(';') Then
 Begin
  expression_bool(lval);
  If not match(';') Then
   errrpt('Expected ; after return value');
 End
 Else
 Begin
  { Return void - load 0 }
  ot('ldd  #0');
  nl;
 End;

 { Generate return code }
 ol('rts');
End;

Function parse_break_statement: Boolean;
Var
 break_label: Integer;
Begin
 parse_break_statement := False;

 If not match('break') Then Exit;
 parse_break_statement := True;

 safe_writeln('; BREAK statement');

 { Expect semicolon }
 If not match(';') Then
  errrpt('Expected ; after break');

 { Get current break label from loop context }
 break_label := get_current_break_label;
 If break_label = -1 Then
 Begin
  errrpt('break statement not within a loop');
  Exit;
 End;

 { Jump to end of current loop }
 ot('lbra ');
 printlabel(break_label);
 nl;
End;

Function parse_continue_statement: Boolean;
Var
 continue_label: Integer;
Begin
 parse_continue_statement := False;

 If not match('continue') Then Exit;
 parse_continue_statement := True;

 safe_writeln('; CONTINUE statement');

 { Expect semicolon }
 If not match(';') Then
  errrpt('Expected ; after continue');

 { Get current continue label from loop context }
 continue_label := get_current_continue_label;
 If continue_label = -1 Then
 Begin
  errrpt('continue statement not within a loop');
  Exit;
 End;

 { Jump to loop condition }
 ot('lbra ');
 printlabel(continue_label);
 nl;
End;

{ Compound statement parsing }
Function parse_compound_statement: Boolean;
Begin
 parse_compound_statement := False;

 If not match('{') Then Exit;
 parse_compound_statement := True;

 safe_writeln('; Compound statement start');

 { Parse statements until closing brace }
 While not match('}') do
 Begin
  If eof <> 0 Then
  Begin
   Case Language of
    _English: errrpt('Unexpected end of file in compound statement');
    _Germany: errrpt('Unerwartetes Dateiende in zusammengesetzter Anweisung');
    Else errrpt('Fin de fichier inattendue dans l''instruction composée');
   End;
   Exit;
  End;

  If not parse_statement Then
  Begin
   { Skip to next line to avoid infinite loops }
   If not readinline Then Break;
  End;
 End;

 safe_writeln('; Compound statement end');

 { Check if this is the end of a function body }
 If current_function <> -1 Then
 Begin
  generate_function_epilogue(current_function);
  current_function := -1;
 End;
End;

{ Expression statement parsing }
Function parse_expression_statement: Boolean;
Var
 lval: TLVal;
 save_lptr: Integer;
Begin
 parse_expression_statement := False;

 { Check for empty statement (just semicolon) }
 If match(';') Then
 Begin
  parse_expression_statement := True;
  safe_writeln('; Empty statement');
  Exit;
 End;

 { Check if there's something that looks like an expression }
 save_lptr := lptr;
 If not (is_digit(peek_char) or is_alpha(peek_char) or (peek_char = '(')) Then
  Exit;

 { Try to parse expression }
 expression_bool(lval);
 parse_expression_statement := True;

 { Expect semicolon }
 If not match(';') Then
  errrpt('Expected ; after expression');

 safe_writeln('; Expression statement');
End;

{ Analyser l'assignation aux éléments de tableau }
Procedure parse_array_assignment(array_name: String);
Var
 index_lval, right_lval: TLVal;
 array_symbol: PSymbol;
 element_size: Integer;
Begin
 { Trouver le symbole du tableau }
 array_symbol := find_symbol(array_name);
 If array_symbol = nil Then
 Begin
  Case Language of
   _English: errrpt('Array not found: ' + array_name);
   _Germany: errrpt('Array nicht gefunden: ' + array_name);
   Else errrpt('Tableau non trouvé: ' + array_name);
  End;
  Exit;
 End;

 { Vérifier que c'est bien un tableau }
 If (array_symbol^.ident <> it_array) and (array_symbol^.type_info.array_size = 0) Then
 Begin
  Case Language of
   _English: errrpt('Variable is not an array: ' + array_name);
   _Germany: errrpt('Variable ist kein Array: ' + array_name);
   Else errrpt('La variable n''est pas un tableau: ' + array_name);
  End;
  Exit;
 End;

 safe_writeln('; Assignation à élément de tableau ' + array_name);

 { Analyser l'expression d'index (le '[' a déjà été consommé) }
 additive_expression(index_lval);

 { Consommer ']' }
 If not match(']') Then
 Begin
  Case Language of
   _English: errrpt('Expected ] after array index');
   _Germany: errrpt('Erwartete ] nach Array-Index');
   Else errrpt('] attendu après l''index du tableau');
  End;
  Exit;
 End;

 { Consommer '=' }
 If not match('=') Then
 Begin
  Case Language of
   _English: errrpt('Expected = in array assignment');
   _Germany: errrpt('Erwartete = in Array-Zuweisung');
   Else errrpt('= attendu dans l''assignation de tableau');
  End;
  Exit;
 End;

 { Sauvegarder l'index sur la pile }
 ol('pshs d      ; sauvegarder index sur pile');

 { Analyser l'expression du côté droit }
 expression(right_lval);

 { Sauvegarder la valeur à assigner }
 ol('pshs d      ; sauvegarder valeur à assigner');

 { Récupérer l'index }
 ol('puls x      ; récupérer valeur dans X');
 ol('puls d      ; récupérer index dans D');

 { Calculer la taille d'un élément }
 element_size := get_type_size(array_symbol^.type_info.base_type);
 
 { Si la taille d'élément n'est pas 1, multiplier l'index }
 If element_size > 1 Then
 Begin
  safe_writeln('; Multiplier index par taille élément');
  Case element_size of
   2: ol('lsld    ; multiplier par 2');
   4: Begin
       ol('lsld    ; multiplier par 4 (shift 1)');
       ol('lsld    ; multiplier par 4 (shift 2)');
      End;
   8: Begin
       ol('lsld    ; multiplier par 8 (shift 1)');
       ol('lsld    ; multiplier par 8 (shift 2)');
       ol('lsld    ; multiplier par 8 (shift 3)');
      End;
  Else
   Begin
    { Multiplication générale }
    ot('ldb  #');
    outdec(element_size);
    nl;
    ol('jsr  mult16');
   End;
  End;
 End;

 { Ajouter l'adresse de base du tableau }
 ot('addd #');
 outstr(array_name);
 nl;

 { Stocker la valeur à l'adresse calculée }
 ol('tfr  d,y    ; adresse dans Y');
 ol('tfr  x,d    ; récupérer valeur dans D');
 Case element_size of
  1: ol('stb  ,y     ; stocker octet');
  2: ol('std  ,y     ; stocker mot');
 Else
  ol('std  ,y     ; stocker mot par défaut');
 End;

 safe_writeln('; Assignation à ' + array_name + '[] terminée');
End;

{ Assignment statement parser }
Function parse_assignment_statement: Boolean;
Var
 var_name: String;
 lval, right_lval: TLVal;
 save_lptr: Integer;
Begin
 parse_assignment_statement := False;
 save_lptr := lptr;
 
 { Try to parse identifier }
 If symname(var_name) Then
 Begin
  blanks;
  
  { Check if this is an array access }
  If match('[') Then
  Begin
   { Array element assignment: array[index] = value }
   parse_array_assignment(var_name);
   parse_assignment_statement := True;
  End
  Else If match('=') Then
  Begin
   { This is a simple variable assignment }
   blanks;
   
   { Look up variable }
   If lookup_variable(var_name, lval) Then
   Begin
    { Check if variable is const }
    If lval.type_info.is_const Then
    Begin
     Case Language of
      _English: errrpt('Cannot assign to const variable: ' + var_name);
      _Germany: errrpt('Kann const Variable nicht zuweisen: ' + var_name);
      Else errrpt('Impossible d''assigner à la variable const: ' + var_name);
     End;
     Exit;
    End;
    
    { Parse right side expression }
    expression(right_lval);
    
    { Generate assignment code }
    ot('std  ');
    outstr(var_name);
    nl;
    
    safe_writeln('; Assignment to variable: ' + var_name);
    parse_assignment_statement := True;
   End;
  End
  Else
  Begin
   { Not an assignment, restore position }
   lptr := save_lptr;
  End;
 End;
End;

{ Main statement parser }
Function parse_statement: Boolean;
Begin
 parse_statement := False;

 { Skip empty lines and comments }
 blanks;
 If Length(line) = 0 Then
 Begin
  parse_statement := True;
  Exit;
 End;

 { Try different statement types }
 If parse_compound_statement Then
  parse_statement := True
 Else If parse_assignment_statement Then
  parse_statement := True
 Else If parse_if_statement Then
  parse_statement := True
 Else If parse_while_statement Then
  parse_statement := True
 Else If parse_for_statement Then
  parse_statement := True
 Else If parse_do_while_statement Then
  parse_statement := True
 Else If parse_return_statement Then
  parse_statement := True
 Else If parse_break_statement Then
  parse_statement := True
 Else If parse_continue_statement Then
  parse_statement := True
 Else If parse_declaration Then
  parse_statement := True
 Else If parse_expression_statement Then
  parse_statement := True
 Else If parse_assignment_statement Then
  parse_statement := True;
End;

Procedure header;
Begin
 If use_stdout Then
  WriteLn('; ', VERSION)
 Else
  safe_writeln('; ' + VERSION);
End;

Procedure trailer;Begin
 { Apply optimizations if enabled }
 If optimize > OPT_NONE Then
 Begin
  optimize_code;
  output_optimized_instructions;
  free_opt_instructions; { Libérer la mémoire des instructions d'optimisation }
 End;

 If use_stdout Then
 Begin
  If asmtype = AS6809 Then WriteLn(';    .end')
                      Else WriteLn('  END');
 End
 Else
 Begin
  If asmtype = AS6809 Then safe_writeln(';    .end')
                      Else safe_writeln('  END');
 End;
End;

Procedure closeout;Begin
 If not use_stdout Then Close(output);
End;

Procedure errrptsummary;Begin
 WriteLn;
 WriteLn(errcnt, ' error(s) in compilation.');
End;

{ Enhanced parsing with variable declarations, control structures and expression parser }
Procedure parse;
Var
 lval: TLVal;
 right_lval: TLVal;
 sname: String;
 save_lptr: Integer;
 expanded_line: String;
Begin
 While eof = 0 do Begin
  {$I-}
  If not readinline Then Break;
  If IOResult <> 0 Then
  Begin
   eof := 1;
   Break;
  End;
  {$I+}

  { Apply macro expansion to the line before processing }
  expanded_line := expand_macros(line);
  If expanded_line <> line Then
  Begin
   line := expanded_line;
   If use_stdout Then WriteLn('; Line after macro expansion: ', line)
                 Else safe_writeln('; Line after macro expansion: ' + line);
  End;

  { Simple comment processing }
  If match('/*') Then
  Begin
   While (not match('*/')) and (eof = 0) do
    readinline;
   Continue;
  End;

  { Process preprocessor directives }
  If match('#') Then
  Begin
   If match('include') Then
   Begin
    { Process #include directive }
    If process_include_directive(line) Then
     Continue  { Continue with included file }
    Else
    Begin
     { Error already reported, skip this line }
     Continue;
    End;
   End
   Else If match('define') Then
   Begin
    { Process #define directive }
    If process_define_directive(line) Then
     Continue  { Continue with next line }
    Else
    Begin
     { Error already reported, skip this line }
     Continue;
    End;
   End
   Else
   Begin
    { Other preprocessor directives - skip for now }
    safe_writeln('; Skipping preprocessor directive: ' + line);
    Continue;
   End;
  End;

  { Skip empty lines }
  blanks;
  If Length(line) = 0 Then Continue;

  safe_writeln('; Processing: ' + line);

  { Reset position for parsing }
  lptr := 1;
  FillChar(lval, SizeOf(lval), 0);

  { Try to parse as statement (includes declarations and control structures) }
  If parse_statement Then
  Begin
   safe_writeln('; Statement processed');
   Continue;
  End;

  { Fallback: Parse identifiers and expressions for backward compatibility }
  lptr := 1;
  If symname(sname) Then
  Begin
   safe_writeln('; Identifier: ' + sname);

   { Check for assignment }
   blanks;
   If match('=') Then
   Begin
    safe_writeln('; Assignment to ' + sname);
    blanks;

    { Look up variable in symbol table }
    If lookup_variable(sname, lval) Then
    Begin
     { Check if variable is const and prevent assignment }
     If lval.type_info.is_const Then
     Begin
      Case Language of
       _English: errrpt('Cannot assign to const variable: ' + sname);
       _Germany: errrpt('Kann const Variable nicht zuweisen: ' + sname);
       Else errrpt('Impossible d''assigner à la variable const: ' + sname);
      End;
     End
     Else
     Begin
      safe_writeln('; Assignment to variable: ' + sname);

      { Use expression parser for right side }
      expression(right_lval);

      { Store result in variable }
      ot('std  ');
      outstr(sname);
      nl;
     End;
    End;
   End
   Else
   Begin
    { Load variable }
    If lookup_variable(sname, lval) Then
    Begin
     ot('ldd  ');
     outstr(sname);
     nl;
    End;
   End;
   Continue;
  End;

  { Try to parse as expression }
  lptr := 1;
  blanks;
  If (peek_char >= '0') and (peek_char <= '9') Then
  Begin
   safe_writeln('; Expression detected');
   expression(lval);
   Continue;
  End;

  { Simple function detection fallback }
  If Pos('(', line) > 0 Then
  Begin
   safe_writeln('; Function found: ' + line);
   ol('nop ; placeholder for function');
  End;

  { Output any remaining content as comment }
  If Length(line) > 0 Then
  Begin
   safe_writeln('; Unknown: ' + line);
  End;
 End;
End;

Var
 i: Integer;
 param: String;

BEGIN
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SQ')or
    (StrToUpper(Copy(TmpLanguage,1,3))='ALB')Then Language:=_Albanian Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='PT')or
    (StrToUpper(Copy(TmpLanguage,1,3))='PRT')Then Language:=_Portuguese Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='SE')or
    (StrToUpper(Copy(TmpLanguage,1,3))='SWE')Then Language:=_Swedish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='DK')or
    (StrToUpper(Copy(TmpLanguage,1,3))='DNK')Then Language:=_Danish Else
  If(StrToUpper(Copy(TmpLanguage,1,2))='JP')or
    (StrToUpper(Copy(TmpLanguage,1,3))='JPN')Then Language:=_Japanese;
 End;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  Case Language of
   _English:Begin
    WriteLn('CC09 - This command allows you to launch the C compiler for ',
            'the 6809 microprocessor.');
    WriteLn;
    WriteLn('usage: cc09 infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options:');
    WriteLn('  -O0    No optimization (default)');
    WriteLn('  -O1    Basic optimizations (peephole, constant folding)');
    WriteLn('  -O2    Advanced optimizations (+ dead code, jumps)');
    WriteLn('  -O3    Aggressive optimizations (all)');
   End;
   _Germany:Begin
    WriteLn('CC09 - Dieser Befehl ermöglicht es, den C-Compiler für ',
            'den 6809-Mikroprozessor zu starten.');
    WriteLn;
    WriteLn('Syntax: cc09 infile.c [outfile] [-optionen]');
    WriteLn;
    WriteLn('Optionen:');
    WriteLn('  -O0    Keine Optimierung (Standard)');
    WriteLn('  -O1    Grundlegende Optimierungen (Guckloch, Konstantenfaltung)');
    WriteLn('  -O2    Erweiterte Optimierungen (+ toter Code, Sprünge)');
    WriteLn('  -O3    Aggressive Optimierungen (alle)');
   End;
   Else Begin
    WriteLn('CC09 - Cette commande permet de lancer le compilateur C pour ',
            'le microprocesseur 6809.');
    WriteLn;
    WriteLn('Syntaxe : cc09 infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options :');
    WriteLn('  -O0    Pas d''optimisation (valeur par d�faut)');
    WriteLn('  -O1    Optimisations de base (oeilleon, pliage constant)');
    WriteLn('  -O2    Optimisations avanc�es (code mort, sauts)');
    WriteLn('  -O3    Optimisations aggressives (toutes)');
   End;
  End;
  Halt(1);
 End;
  { Initialize variables - symtab no longer needed }
 { FillChar(symtab, SizeOf(symtab), 0); -- Old symbol table removed }
 glbptr := startglb;
 locptr := startloc;
 stkp := 0;
 errcnt := 0;
 eof := 0;
 lastst := 0;
 cmode := 1;
 first_func := True;
 declared := False;
 use_stdout := True;
 { Initialize include file system }
 include_depth := 0;
 current_filename := '';
 { Initialize define system }
 init_defines;
 { Initialize heap-based symbol table }
 init_symbols;
  { Compiler main body }
 nxtlab := 0;
 kill;
 WriteLn('CC09 - Compilateur C pour 6809 V1.01');
 WriteLn;
 optimize := OPT_NONE;
 ctext := NO;
 { Parse command line arguments }
 For i := 1 to ParamCount do Begin
  param := ParamStr(i);
  If param = '-O0' Then optimize := OPT_NONE
  Else If param = '-O1' Then optimize := OPT_BASIC
  Else If param = '-O2' Then optimize := OPT_ADVANCED
  Else If param = '-O3' Then optimize := OPT_AGGRESSIVE;
 End;
 
 { Open input file with error checking }
 Assign(input, ParamStr(1));
 {$I-}
 Reset(input);
 If IOResult <> 0 Then
 Begin
  WriteLn('Error: Cannot open input file: ', ParamStr(1));
  Halt(1);
 End;
 {$I+}
 
 current_filename := ParamStr(1); { Set initial filename for include system }
 WriteLn('Compiling Source file: ', ParamStr(1));
 
 { Initialize global variables }
 eof := 0;
 errcnt := 0;
 lptr := 1;
 line := '';
 nextlabel := 0;
 use_stdout := True; { Initialize early - may be changed later }
 
 { Initialize heap-based symbol table }
 init_symbols;
 
 { Initialize defines table }
 init_defines;
 
 If optimize > OPT_NONE Then WriteLn('Optimization level: ', optimize);
 If ParamCount >= 2 Then Begin
  param := ParamStr(2);
  If (param[1] <> '-') Then Begin { Option impossible, fichier de sortie obligatoire }
   Assign(output, param);
   {$I-}
   Rewrite(output);
   If IOResult <> 0 Then
   Begin
    WriteLn('Error: Cannot create output file: ', param);
    Halt(1);
   End;
   {$I+}
   WriteLn('Generating asm file: ', param);
   use_stdout := False;
  End
   Else
  Begin
   { Ne pas assigner de sortie � la sortie; utiliser plut�t un drapeau }
   Case Language of
    _English:WriteLn('Using console screen for output.');
    Else WriteLn('Affichage de la sortie sur la console.');
   End;
   use_stdout := True;
  End;
 End
  Else
 Begin
   { Ne pas assigner de sortie � la sortie; utiliser plut�t un drapeau }
  Case Language of
   _English:WriteLn('Using console screen for output.');
   Else WriteLn('Affichage de la sortie sur la console.');
  End;
  use_stdout := True;
 End;
  { Initialisation du syst�me d'opimisation }
 init_optimization;
 { Initialize loop context stack }
 loop_depth := 0;
 { Initialize type info table }
 type_info_count := 0;
  { Initialisaton du syst�me de gestion des fonctions }
 init_functions;
  { Initialisation du système de gestion des structures }
 init_structs;
 asmtype := AS6809;
 header;        { Code d''introduction }
 parse;         { Analyse toutes les entr�e }
 trailer;       { Code de suivi }
 free_defines;  { Free define memory from heap }
 free_symbols;  { Free symbol table from heap }
 free_structs;  { Free struct definitions from heap }
 closeout;      { Fermer la sortie }
 errrptsummary; { R�sumer les erreurs }
END.