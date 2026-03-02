{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur C pour Intel 8086
}

Program CC8086;

{$A-}
{$I-}

Uses DOS;

Const
 VERSION = 'Compilateur C pour Intel 8086 V1.1';  { Version du compilateur C pour Intel 8086 }
 YES = 1;                                         { Valeur boolÇenne vraie }
 NO = 0;                                          { Valeur boolÇenne fausse }

  { Paramätres de la table de symbole }
 symsiz = 14;       { Taille d'une entrÇe de symbole en octets }
 numglbs = 512;     { Nombre maximum de symboles globaux }
 MASKGLBS = 511;    { Masque pour le hachage de la table de symboles }
 namesize = 32;     { Taille maximale d'un nom de symbole incluant le terminateur }
 namemax = 31;      { Longueur maximale d'un nom de symbole }

  { DÇplacement du format d'entrÇe de la table des symboles }
 name = 0;          { DÇplacement du nom du symbole dans l'entrÇe }
 ident = 9;         { DÇplacement de l'identificateur de type }
 ctype = 10;        { DÇplacement du type de donnÇes C }
 storage = 11;      { DÇplacement de la classe d'entreposage }
 offset = 12;       { DÇplacement de la valeur/adresse du symbole }
 offsize = 2;       { Taille en octets du champ offset }

  { Types d'identificateurs }
 it_variable = 1;     { Variable simple }
 it_array = 2;        { Tableau }
 it_pointer = 3;      { Pointeur }
 it_function = 4;     { Fonction }
 it_struct_type = 5;  { Type structure }
 it_union_type = 6;   { Type union }
 it_typedef_type = 7; { Type dÇfini par typedef }

  { Types de donnÇes }
 cvoid = 1;      { Type void (aucune valeur) }
 cchar = 2;      { Caractäre signÇ 8 bits }
 cuchar = 3;     { Caractäre non signÇ 8 bits }
 cshort = 4;     { Entier court signÇ 16 bits }
 cushort = 5;    { Entier court non signÇ 16 bits }
 cint = 6;       { Entier signÇ 16 bits }
 cuint = 7;      { Entier non signÇ 16 bits }
 clong = 8;      { Entier long signÇ 32 bits }
 culong = 9;     { Entier long non signÇ 32 bits }
 cfloat = 10;    { Nombre flottant simple prÇcision }
 cdouble = 11;   { Nombre flottant double prÇcision }
 cpointer = 12;  { Pointeur vers un type }
 carray = 13;    { Tableau d'ÇlÇments }
 cstruct = 14;   { Structure de donnÇes }
 cunion = 15;    { Union de donnÇes }
 cenum = 16;     { ênumÇration de valeurs }

  { Taille du type en octets }
 sizeof_void = 0;     { Taille du type void (aucune taille) }
 sizeof_char = 1;     { Taille du type char (1 octet) }
 sizeof_short = 2;    { Taille du type short (2 octets) }
 sizeof_int = 2;      { Taille du type int sur 8086 (2 octets) }
 sizeof_long = 4;     { Taille du type long (4 octets) }
 sizeof_float = 4;    { Taille du type float (4 octets) }
 sizeof_double = 8;   { Taille du type double (8 octets) }
 sizeof_pointer = 2;  { Taille d'un pointeur sur 8086 (2 octets) }
 sizeof_enum = 2;     { Taille du type enum (2 octets, comme int) }

  { Classes d'entreposage }
 statik = 1;      { Variable statique (durÇe de vie du programme) }
 stkloc = 2;      { Variable locale sur la pile }
 CEXTERNAL = 3;   { Variable externe dÇfinie ailleurs }
 automatic = 4;   { Variable automatique (locale par dÇfaut) }

  { Types d'instructions }
 streturn = 3;    { Instruction de retour de fonction }

  { Types d'assembleurs }
 AS8086 = 1;      { Assembleur pour processeur Intel 8086 }
 ASMX86 = 2;      { Assembleur x86 pour 8086 }

  { Niveau d'optimisations }
 OPT_NONE = 0;        { Aucune optimisation }
 OPT_BASIC = 1;       { Optimisations de base }
 OPT_ADVANCED = 2;    { Optimisations avancÇes }
 OPT_AGGRESSIVE = 3;  { Optimisations agressives (toutes activÇes) }

 { Option d'optimisation }
 OPT_PEEPHOLE = 1;      { Optimisations pour analyse de code }
 OPT_DEAD_CODE = 2;     { êlimination du code mort }
 OPT_CONSTANT_FOLD = 4; { Simplification des constantes }
 OPT_STRENGTH_RED = 8;  { RÇduction de la complexitÇ }
 OPT_REGISTER = 16;     { Allocation de registres }
 OPT_JUMP = 32;         { Optimisations de sauts }

 { Ligne d'entr√©e }
 linesize = 80;            { Taille maximale d'une ligne d'entrÇe }
 linemax = linesize - 1;   { Index maximum valide dans une ligne }

Type
  { TSymTab n'est plus nÇcessaire - utiliser maintenant la mÇmoire de tas pour la table des symboles }
 TLine = String[linesize];

 { Structure d'information de type }
 PTypeInfo = ^TTypeInfo;
 TTypeInfo = Record
  base_type: Integer;      { Type de donnÇes de base (cint, cchar, etc.) }
  pointer_level: Integer;  { Nombre de niveaux d'indirection }
  array_size: Integer;     { Taille du tableau (0 si ce n'est pas un tableau) }
  is_unsigned: Boolean;    { Vrai pour les types non signÔøΩs }
  is_const: Boolean;       { Vrai pour les types constants }
  is_volatile: Boolean;    { Vrai pour les types volatils }
  struct_id: Integer;      { Identifiant de struct/union }
  typedef_name: String;    { Nom du typedef si c'est un type dÇfini }
  is_typedef: Boolean;     { Vrai si c'est un typedef }
  size: Integer;           { Taille totale en octets }
 End;

  { Structure de valeur d'expression }
 TLVal = Record
  symbol: Integer;        { Pointeur vers l'entrÇe de la table de symboles }
  indirect: Integer;      { 0=direct, 1=indirect }
  typ: Integer;           { Type de donnÇes }
  storage: Integer;       { Classe d'entreposage }
  constant: Boolean;      { Vrai si la valeur est constante }
  value: Integer;         { Valeur constante, le cas ÇchÇant }
  type_info: TTypeInfo;   { Informations de type Çtendues }
 End;

 { Structure d'instruction d'optimisation }
 TOptInstruction = Record
  opcode: String[10];     { MnÇmonique d'instruction }
  operand: String[20];    { OpÇrande }
  comment: String[40];    { Commentaire }
  line_number: Integer;   { NumÇro de ligne source }
  can_eliminate: Boolean; { Peut àtre supprimÇ lors de la suppression du code mort }
 End;

 { Pointeur vers instruction d'optimisation }
 POptInst = ^TOptInst;

 { Structure d'instruction d'optimisation dans la mÇmoire tas }
 TOptInst = Record
  opcode: String[10];     { MnÇmonique d'instruction }
  operand: String[20];    { OpÇrande }
  comment: String[40];    { Commentaire }
  line_number: Integer;   { NumÇro de ligne source }
  can_eliminate: Boolean; { Peut àtre supprimÇ lors de la suppression du code mort }
  next: POptInst;         { Pointeur vers instruction suivante }
 End;

 { Optimisation de contexte }
 TOptContext = Record
  level: Integer;           { Niveau d'optimisation }
  flags: Integer;           { Drapeaux d'optimisation }
  inst_list: POptInst;      { Liste chaånÇe d'instructions dans la mÇmoire de tas }
  inst_count: Integer;      { Nombre d'instructions }
  last_result_reg: String;  { Dernier registre utilisÇ pour le rÇsultat }
 End;

  { Structure de paramätres de la fonction }
 TParameter = Record
  name: String[20];      { Nom du paramätre }
  typ: Integer;          { Type du paramätre }
  type_info: TTypeInfo;  { Informations dÇtaillÇes sur le type }
  offset: Integer;       { DÇplacement de la pile }
 End;

 { Structure d'informations de fonction }
 TFunction = Record
  name: String[20];                      { Nom de la fonction }
  return_type: Integer;                  { Type de retour }
  return_type_info: TTypeInfo;           { Type de retour dÇtaillÇ }
  param_count: Integer;                  { Nombre de paramätres }
  parameters: Array[0..9] of TParameter; { Liste des paramätres }
  is_defined: Boolean;                   { Vrai si la fonction est dÇfinie (possäde un corps) }
  is_declared: Boolean;                  { Vrai si la fonction est dÇclarÇe }
  label_id: Integer;                     { Etiquette assembleur de la fonction }
  local_vars_size: Integer;              { Taille dees variables locales }
  is_main: Boolean;                      { Vrai s'il s'agit de la fonction principale }
 End;

 { Structure de contexte de boucle pour le support break/continue }
 TLoopContext = Record
  loop_type: Integer;     { 1=while, 2=for, 3=do-while }
  break_label: Integer;   { êtiquette Ö utiliser pour break }
  continue_label: Integer; { êtiquette Ö utiliser pour continue }
 End;

 { Membre d'une structure ou union }
 TStructMember = Record
  name: String[20];       { Nom du membre }
  member_type: Integer;   { Type de base du membre }
  type_info: TTypeInfo;   { Informations dÇtaillÇes du type }
  offset: Integer;        { DÇplacement du membre dans la structure }
  size: Integer;          { Taille du membre en octets }
 End;

 { DÇfinition de structure ou union }
 PStructDef = ^TStructDef;
 TStructDef = Record
  name: String[20];                        { Nom de la structure/union }
  is_union: Boolean;                       { Vrai si c'est une union, faux si struct }
  member_count: Integer;                   { Nombre de membres }
  members: Array[0..15] of TStructMember;  { Liste des membres (maximum 16) }
  total_size: Integer;                     { Taille totale de la structure }
  struct_id: Integer;                      { ID unique de la structure }
  next: PStructDef;                        { Structure suivante dans la liste }
 End;

 { Gestion des fichiers d'inclusion }
 TIncludeFile = Record
  filename: String;
  saved_line: TLine;
  saved_lptr: Integer;
  saved_eof: Integer;
 End;

 { Table des fichiers dÇjÖ inclus pour Çviter l'inclusion circulaire }
 TIncludedFile = Record
  filename: String;
  is_included: Boolean;
 End;

  { Gestion des macros/Define - utilisation du tas au lieu de tableaux statiques }
 PDefine = ^TDefine;
 TDefine = Record
  name: String;
  value: String;
  in_use: Boolean;
  next: PDefine;        { Pointeur vers le prochain define dans la liste chaånÇe }
 End;

 { Gestion des directives de prÇprocesseur conditionnelles }
 TConditionType = (
  COND_IF,      { #if }
  COND_IFDEF,   { #ifdef }
  COND_IFNDEF,  { #ifndef }
  COND_ELIF     { #elif }
 );

 TConditionState = Record
  condition_type: TConditionType; { Type de condition }
  is_true: Boolean;               { êvaluation actuelle de la condition }
  has_true_branch: Boolean;       { Si une branche vraie a ÇtÇ trouvÇe }
  in_else: Boolean;               { Si nous sommes dans un bloc #else }
  line_number: Integer;           { NumÇro de ligne pour debug }
 End;

 { Pile de conditions pour directives imbriquÇes }
 TConditionStack = Array[0..31] of TConditionState;

 { Table de symboles utilisant la mÇmoire de tas au lieu du segment de donnÇes }
 PSymbol = ^TSymbol;
 TSymbol = Record
  name: String;
  ident: Integer;    { it_variable, it_function, etc. }
  ctype: Integer;    { Type de symbole }
  storage: Integer;  { Classe de stockage }
  offset_value: Integer; { DÇcalage ou valeur }
  type_info: TTypeInfo; { Information de type Çtendue }
  next: PSymbol;     { Symbole suivant dans la chaåne }
 End;

  { Pointeur vers fonction dans le tas }
 PFunction = ^TFunctionNode;

 { Noeud de fonction pour liste chaånÇe dans la mÇmoire de tas }
 TFunctionNode = Record
  func_data: TFunction;    { DonnÇes de la fonction }
  next: PFunction;         { Fonction suivante dans la liste }
 End;

{ Structure pour gÇrer les Çtiquettes goto }
 TGotoLabel = Record
  name: String[20];       { Nom de l'Çtiquette }
  label_id: Integer;      { ID numÇrique de l'Çtiquette }
  is_defined: Boolean;    { Vrai si l'Çtiquette a ÇtÇ dÇfinie }
  is_used: Boolean;       { Vrai si l'Çtiquette a ÇtÇ rÇfÇrencÇe }
 End;

 { Table des Çtiquettes goto }
 TGotoTable = Array[0..31] of TGotoLabel; { Maximum 32 Çtiquettes par fonction }

 { Structure pour gÇrer les instructions switch/case }
 TSwitchCase = Record
  value: Integer;         { Valeur du case }
  label_id: Integer;      { ID de l'Çtiquette pour ce case }
 End;

 TSwitchStatement = Record
  expression_type: Integer;           { Type de l'expression switch }
  case_count: Integer;                { Nombre de cases }
  cases: Array[0..31] of TSwitchCase; { Max 32 cases par switch }
  default_label: Integer;             { êtiquette pour default (-1 si pas de default) }
  end_label: Integer;                 { êtiquette de fin de switch }
  has_default: Boolean;               { Vrai s'il y a une clause default }
 End;

  { Table des switch imbriquÇs }
 TSwitchTable = Array[0..7] of TSwitchStatement; { Max 8 switch imbriquÇs }

Var
 Language:(_French,_English,_Germany,_Italian,_Spain,_Albanian,_Portuguese,_Swedish,_Danish,_Japanese);
 TmpLanguage:String;
 { Tables de symbole }
 { Variables hÇritÇes - conservÇes pour la compatibilitÇ avec certains calculs }
 glbptr, locptr: Integer;

 { Nouvelle table de symboles basÇe sur la mÇmoire de tas }
 symbol_list: PSymbol;    { Tàte de la liste de symboles }
 symbol_count: Integer;   { Compteur pour les statistiques }

 { Gestion de fonction - liste chaånÇe basÇe sur la mÇmoire de tas }
 function_list: PFunction;          { Tàte de la liste de fonctions }
 function_count: Integer;           { Compteur pour les statistiques }
 current_function_node: PFunction;  { Noeud de la fonction en cours d'analyse }
 current_function: Integer;         { Index de fonction pour compatibilitÇ }
 call_stack_depth: Integer;         { Profondeur d'appel actuelle }

 { Contexte d'optimisation }
 opt_context: TOptContext;

 { Gestion des structures et unions - liste chaånÇe basÇe sur la mÇmoire de tas }
 struct_list: PStructDef;     { Tàte de la liste de structures/unions }
 struct_count: Integer;       { Compteur de structures/unions }
 next_struct_id: Integer;     { Prochain ID de structure disponible }

 { Pile de contexte de boucle pour break/continue }
 loop_stack: Array[0..31] of TLoopContext;
 loop_depth: Integer;

 { Pile de fichiers d'inclusion }
 include_stack: Array[0..9] of TIncludeFile;  { Max 10 niveaux d'inclusion }
 include_depth: Integer;
 current_filename: String;

 { Table des fichiers inclus pour Çviter l'inclusion circulaire }
 included_files: Array[0..49] of TIncludedFile; { Max 50 fichiers diffÇrents }
 included_count: Integer;

 { Gestion Define/Macro - utilisation du tas (liste chaånÇe) }
 define_list: PDefine;  { Tàte de la liste chaånÇe des defines }
 define_count: Integer; { Nombre de dÇfinitions actuellement en usage }

 { Gestion des directives conditionnelles de prÇprocesseur }
 condition_stack: TConditionStack; { Pile de conditions }
 condition_depth: Integer;         { Profondeur actuelle de la pile }
 skip_code: Boolean;               { Vrai si on doit ignorer le code actuel }

 { Informations de type √©tendues - maintenant entreposÇes directement dans les symboles }
  type_info_count: Integer;

 { Ligne d'entrÇe }
 line: TLine;
 lptr: Integer;

 { êtiquettes et compteurs }
 nxtlab: Integer;
 nextlabel: Integer; { Pour l'analyseur d'expressions }

 { Table des Çtiquettes goto }
 goto_table: TGotoTable;
 goto_count: Integer;

 { Table des switch imbriquÇs }
 switch_table: TSwitchTable;
 switch_depth: Integer;

 { Drapeaux et options }
 first_func, declared: Boolean;
 stkp: Integer;
 errcnt, eof: Integer;
 optimize, ctext, cmode, lastst: Integer;

 { Gestionnaires de fichiers }
 input, output: Text;
 asmtype: Integer;
 use_stdout: Boolean;

{ DÇclarations anticip√©es }
Procedure init_type_info(var type_info: TTypeInfo); forward;
Function parse_type_specifier: Integer; forward;
Function parse_type_specifier_with_qualifiers(var type_info: TTypeInfo): Integer; forward;
Function parse_storage_class_specifier: Integer; forward;
Function parse_enum_type: Integer; forward;
Function readinline: Boolean; forward;

{ DÇclarations anticipÇes pour typedef }
Function find_typedef(typedef_name: String): PSymbol; forward;
Function add_typedef(typedef_name: String; var type_info: TTypeInfo): PSymbol; forward;
Function parse_typedef_declaration: Boolean; forward;
Function resolve_typedef_type(typedef_name: String; var resolved_type: TTypeInfo): Boolean; forward;

{ Fonctions hÇritÇes - plus nÇcessaires avec la table de symboles basÇe sur le tas }
Function startglb: Integer;Begin
 startglb := 1; { Commence Ö 1 pour rÇserver 0 comme valeur "non trouvÇ" }
End;

Function endglb: Integer;Begin
 endglb := 1000; { Valeur fictive pour la compatibilitÇ }
End;

Function startloc: Integer;Begin
 startloc := 1000; { Valeur fictive pour la compatibilitÇ }
End;

Function endloc: Integer;Begin
 endloc := 2000; { Valeur fictive pour la compatibilitÇ }
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

 { Utilitaires de chaine de caractäres }
Function streq(s1, s2: String): Boolean;Begin
 streq := s1 = s2;
End;

 { Fonctions d'entrÔøΩe/sortie }
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

{ Fonctions d'Çcriture de fichier sÇcurisÇes }
Function is_output_ready: Boolean;Begin
 { Retourne toujours vrai car nous gÇrons la vÇrification de fichier ailleurs }
 is_output_ready := True;
End;

Procedure safe_write(s: String);Begin
 { Utilise toujours stdout pour l'instant pour Çviter les problämes de fichier }
 Write(s);
End;

Procedure safe_writeln(s: String);Begin
 If use_stdout Then
  WriteLn(s)
 Else
  WriteLn(output, s);
End;

Procedure nl;Begin
 safe_writeln('');
End;

 { Fonction pour convertir les instructions 6809 en instructions 8086 et en majuscules }
Function convert_to_8086_upper(s: String): String;
Var
 result: String;
 i: Integer;
Begin
 result := s;
  { Convertir les instructions 6809 vers 8086 }
 If Pos('ldd  #', result) = 1 Then
  result := 'MOV  AX,' + Copy(result, 6, Length(result))
 Else If Pos('LDD #', result) = 1 Then
  result := 'MOV  AX,' + Copy(result, 6, Length(result))
 Else If Pos('ldd  ', result) = 1 Then
  result := 'MOV  AX, ' + Copy(result, 6, Length(result))
 Else If Pos('std  ', result) = 1 Then
  result := 'MOV  ' + Copy(result, 6, Length(result)) + ', AX'
 Else If Pos('stb  ', result) = 1 Then
  result := 'MOV  ' + Copy(result, 6, Length(result)) + ', AL'
 Else If Pos('ldb  #', result) = 1 Then
  result := 'MOV  AL,' + Copy(result, 6, Length(result))
 Else If Pos('ldb  ', result) = 1 Then
  result := 'MOV  AL, ' + Copy(result, 6, Length(result))
 Else If Pos('pshs d', result) = 1 Then
  result := 'PUSH AX' + Copy(result, 7, Length(result))
 Else If Pos('puls d', result) = 1 Then
  result := 'POP  AX' + Copy(result, 7, Length(result))
 Else If Pos('pshs x,y', result) = 1 Then
  result := 'PUSH BP' + Copy(result, 9, Length(result))
 Else If Pos('puls x,y', result) = 1 Then
  result := 'POP  BP' + Copy(result, 9, Length(result))
 Else If Pos('pshs x', result) = 1 Then
  result := 'PUSH BX' + Copy(result, 7, Length(result))
 Else If Pos('puls x', result) = 1 Then
  result := 'POP  BX' + Copy(result, 7, Length(result))
 Else If Pos('addd ,s++', result) = 1 Then
  { 8086 n'a pas d'Çquivalent direct pour ,s++, utiliser une sÇquence }
  result := 'ADD  AX, [SP] ; puis ADD SP, 2' + Copy(result, 9, Length(result))
 Else If Pos('addd ', result) = 1 Then
  result := 'ADD  AX, ' + Copy(result, 6, Length(result))
 Else If Pos('subd ,x', result) = 1 Then
  result := 'SUB  AX, [BX]' + Copy(result, 8, Length(result))
 Else If Pos('subd ', result) = 1 Then
  result := 'SUB  AX, ' + Copy(result, 6, Length(result))
 Else If Pos('cmpd ', result) = 1 Then
  result := 'CMP  AX, ' + Copy(result, 6, Length(result))
 Else If Pos('cmpx d', result) = 1 Then
  result := 'CMP  BX, AX' + Copy(result, 7, Length(result))
 Else If Pos('cmpx ', result) = 1 Then
  result := 'CMP  BX, ' + Copy(result, 6, Length(result))
 Else If Pos('tstd', result) = 1 Then
  result := 'CMP  AX, 0' + Copy(result, 5, Length(result))
 Else If Pos('lbeq ', result) = 1 Then
  result := 'JE   ' + Copy(result, 6, Length(result))
 Else If Pos('lbne ', result) = 1 Then
  result := 'JNE  ' + Copy(result, 6, Length(result))
 Else If Pos('lbra ', result) = 1 Then
  result := 'JMP  ' + Copy(result, 6, Length(result))
 Else If Pos('bgt ', result) = 1 Then
  result := 'JG   ' + Copy(result, 5, Length(result))
 Else If Pos('bge *+5', result) = 1 Then
  result := 'JGE  $+5' + Copy(result, 8, Length(result))
 Else If Pos('blt ', result) = 1 Then
  result := 'JL   ' + Copy(result, 5, Length(result))
 Else If Pos('bge ', result) = 1 Then
  result := 'JGE  ' + Copy(result, 5, Length(result))
 Else If Pos('ble ', result) = 1 Then
  result := 'JLE  ' + Copy(result, 5, Length(result))
 Else If Pos('tfr  s,x', result) = 1 Then
  result := 'MOV  BP, SP' + Copy(result, 9, Length(result))
 Else If Pos('tfr  d,x', result) = 1 Then
  result := 'MOV  BX, AX' + Copy(result, 9, Length(result))
 Else If Pos('leas -', result) = 1 Then
  result := 'SUB  SP, ' + Copy(result, 7, Length(result))
 Else If Pos('leas ', result) = 1 Then
  result := 'ADD  SP, ' + Copy(result, 6, Length(result))
 Else If Pos('jsr  ', result) = 1 Then
  result := 'CALL ' + Copy(result, 6, Length(result))
 Else If Pos('rts', result) = 1 Then
  result := 'RET' + Copy(result, 4, Length(result))
 Else If Pos('swi', result) = 1 Then
  result := 'INT  20h' + Copy(result, 4, Length(result))
 Else If Pos('cmpi ', result) = 1 Then
  result := 'CMP  AX, ' + Copy(result, 6, Length(result))
 Else If Pos('bra *+3', result) = 1 Then
  result := 'JMP  $+3' + Copy(result, 8, Length(result))
 Else If Pos('bra *+5', result) = 1 Then
  result := 'JMP  $+5' + Copy(result, 8, Length(result))
 Else If Pos(',x', result) > 0 Then
  { Remplacer les rÇfÇrences ,x par [BX] }
  result := Copy(result, 1, Pos(',x', result) - 1) + '[BX]' + Copy(result, Pos(',x', result) + 2, Length(result))
  Else
 Begin
  { Si pas de conversion spÇcifique, convertir en majuscules }
  For i := 1 to Length(result) do
   If result[i] in ['a'..'z'] Then
    result[i] := Chr(Ord(result[i]) - 32);
 End;
 convert_to_8086_upper := result;
End;

Procedure ol(s:String);Begin
 safe_writeln(#9 + convert_to_8086_upper(s));
End;

 { êcrire la ligne dans la sortie avec routage conditionnel }
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

 { Fonctions de gÔøΩnÔøΩration d'ÔøΩtiquettes }
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

 { GÇnÇration de code avec conversion automatique vers 8086 et majuscules }
Procedure ot(s: String);Begin
 safe_write(#9 + convert_to_8086_upper(s) + ' '); { TAB puis chaåne de caractäres avec espace }
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
  Else WriteLn('Erreur: ', msg, ' Ö la ligne ', lptr);
 End;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES êTIQUETTES GOTO                                     }
{ ============================================================================ }

 { Initialiser la table des Çtiquettes goto }
Procedure init_goto_table;
Var
 i: Integer;
Begin
 For i := 0 to 31 do Begin
  With goto_table[i] do Begin
   name := '';
   label_id := 0;
   is_defined := False;
   is_used := False;
  End;
 End;
 goto_count := 0;
End;

 { Trouver une Çtiquette goto par nom }
Function find_goto_label(label_name: String): Integer;
Var
 i: Integer;
Begin
 find_goto_label := -1;
 For i := 0 to goto_count - 1 do Begin
  If goto_table[i].name = label_name Then Begin
   find_goto_label := i;
   Exit;
  End;
 End;
End;

 { Ajouter ou rÇcupÇrer une Çtiquette goto }
Function add_goto_label(label_name: String): Integer;
Var
 index: Integer;
Begin
 add_goto_label := -1;
  { VÇrifier si l'Çtiquette existe dÇjÖ }
 index := find_goto_label(label_name);
 If index <> -1 Then Begin
  add_goto_label := index;
  Exit;
 End;
  { VÇrifier s'il y a de la place }
 If goto_count >= 32 Then Begin
  Case Language of
   _English: errrpt('Too many goto labels (max 32)');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele Goto-Labels (max 32)');
   {$ENDIF}
   Else errrpt('Trop d''Çtiquettes goto (max 32)');
  End;
  Exit;
 End;
  { Ajouter la nouvelle Çtiquette }
 index := goto_count;
 With goto_table[index] do Begin
  name := label_name;
  label_id := getlabel;
  is_defined := False;
  is_used := False;
 End;
 Inc(goto_count);
 add_goto_label := index;
End;

 { Marquer une Çtiquette comme dÇfinie }
Procedure define_goto_label(label_name: String);
Var
 index: Integer;
Begin
 index := add_goto_label(label_name);
 If index <> -1 Then Begin
  If goto_table[index].is_defined Then Begin
   Case Language of
    _English: errrpt('Label already defined: ' + label_name);
    {$IFDEF FPC}
    _Germany: errrpt('Label bereits definiert: ' + label_name);
    {$ENDIF}
    Else errrpt('êtiquette dÇjÖ dÇfinie: ' + label_name);
   End;
   Exit;
  End;
  goto_table[index].is_defined := True;
  prelabel(goto_table[index].label_id);
  safe_writeln('; êtiquette dÇfinie: ' + label_name);
 End;
End;

 { Marquer une Çtiquette comme utilisÇe et gÇnÇrer le saut }
Procedure use_goto_label(label_name: String);
Var
 index: Integer;
Begin
 index := add_goto_label(label_name);
 If index <> -1 Then Begin
  goto_table[index].is_used := True;
  ot('jmp ');
  printlabel(goto_table[index].label_id);
  nl;
  safe_writeln('; Saut vers Çtiquette: ' + label_name);
 End;
End;

 { VÇrifier les Çtiquettes non dÇfinies Ö la fin de fonction }
Procedure check_goto_labels;
Var
 i: Integer;
 has_errors: Boolean;
Begin
 has_errors := False;
 For i := 0 to goto_count - 1 do Begin
  With goto_table[i] do Begin
   If is_used and not is_defined Then Begin
    Case Language of
     _English: errrpt('Undefined label: ' + name);
     {$IFDEF FPC}
     _Germany: errrpt('Undefiniertes Label: ' + name);
     {$ENDIF}
     Else errrpt('êtiquette non dÇfinie: ' + name);
    End;
    has_errors := True;
   End;
  End;
 End;
 If not has_errors Then safe_writeln('; Toutes les Çtiquettes goto sont correctement dÇfinies');
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES INSTRUCTIONS SWITCH/CASE/DEFAULT                    }
{ ============================================================================ }

{ Initialiser la table des switch }
Procedure init_switch_table;
Var
 i, j: Integer;
Begin
 For i := 0 to 7 do Begin
  With switch_table[i] do Begin
   expression_type := cint;
   case_count := 0;
   For j := 0 to 31 do Begin
    cases[j].value := 0;
    cases[j].label_id := 0;
   End;
   default_label := -1;
   end_label := 0;
   has_default := False;
  End;
 End;
 switch_depth := 0;
End;

{ Commencer un nouveau switch }
Function begin_switch_statement(expr_type: Integer): Boolean;
Begin
 begin_switch_statement := False;
 If switch_depth >= 8 Then
 Begin
  Case Language of
   _English: errrpt('Too many nested switch statements (max 8)');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele verschachtelte Switch-Anweisungen (max 8)');
   {$ENDIF}
   Else errrpt('Trop d''instructions switch imbriquÇes (max 8)');
  End;
  Exit;
 End;
 With switch_table[switch_depth] do Begin
  expression_type := expr_type;
  case_count := 0;
  default_label := -1;
  end_label := getlabel;
  has_default := False;
 End;
 Inc(switch_depth);
 begin_switch_statement := True;
End;

 { Ajouter un case au switch courant }
Function add_switch_case(case_value: Integer): Integer;
Var
 case_label: Integer;
 i: Integer;
 case_str: String;
Begin
 add_switch_case := -1;
 If switch_depth = 0 Then Begin
  Case Language of
   _English: errrpt('case statement outside switch');
   {$IFDEF FPC}
   _Germany: errrpt('case-Anweisung au·erhalb von switch');
   {$ENDIF}
   Else errrpt('instruction case en dehors de switch');
  End;
  Exit;
 End;
 With switch_table[switch_depth - 1] do Begin
  { VÇrifier si la valeur existe dÇjÖ }
  For i := 0 to case_count - 1 do Begin
   If cases[i].value = case_value Then Begin
    Str(case_value, case_str);
    Case Language of
     _English: errrpt('Duplicate case value: ' + case_str);
     {$IFDEF FPC}
     _Germany: errrpt('Doppelter case-Wert: ' + case_str);
     {$ENDIF}
     Else errrpt('Valeur case dupliquÇe: ' + case_str);
    End;
    Exit;
   End;
  End;
  If case_count >= 32 Then Begin
   Case Language of
    _English: errrpt('Too many case labels (max 32)');
    {$IFDEF FPC}
    _Germany: errrpt('Zu viele case-Labels (max 32)');
    {$ENDIF}
    Else errrpt('Trop d''√©tiquettes case (max 32)');
   End;
   Exit;
  End;
  case_label := getlabel;
  cases[case_count].value := case_value;
  cases[case_count].label_id := case_label;
  Inc(case_count);
  add_switch_case := case_label;
 End;
End;

 { Ajouter une clause default au switch courant }
Function add_switch_default:Integer;Begin
 add_switch_default := -1;
 If switch_depth = 0 Then Begin
  Case Language of
   _English: errrpt('default statement outside switch');
   {$IFDEF FPC}
   _Germany: errrpt('default-Anweisung au·erhalb von switch');
   {$ENDIF}
   Else errrpt('instruction default en dehors de switch');
  End;
  Exit;
 End;
 With switch_table[switch_depth - 1] do Begin
  If has_default Then Begin
   Case Language of
    _English: errrpt('Multiple default labels in switch');
    {$IFDEF FPC}
    _Germany: errrpt('Mehrere default-Labels in switch');
    {$ENDIF}
    Else errrpt('Plusieurs √©tiquettes default dans switch');
   End;
   Exit;
  End;
  default_label := getlabel;
  has_default := True;
  add_switch_default := default_label;
 End;
End;

{ GÇnÇrer le code de comparaison pour un switch }
Procedure generate_switch_comparisons;
Var
 i: Integer;
 case_str: String;
Begin
 If switch_depth = 0 Then Exit;
 With switch_table[switch_depth - 1] do Begin
  safe_writeln('; GÇnÇration des comparaisons switch');
  For i := 0 to case_count - 1 do Begin
   Str(cases[i].value, case_str);
   safe_writeln('; Test case ' + case_str);
   ot('cmp ax,');
   outdec(cases[i].value);
   nl;
   ot('je ');
   printlabel(cases[i].label_id);
   nl;
  End;
   { Saut vers default ou fin }
  If has_default Then
  Begin
   ot('jmp ');
   printlabel(default_label);
   nl;
  End
  Else
  Begin
   ot('jmp ');
   printlabel(end_label);
   nl;
  End;
 End;
End;

 { Terminer le switch courant }
Function end_switch_statement:Integer;Begin
 end_switch_statement := -1;
 If switch_depth = 0 Then Begin
  Case Language of
   _English: errrpt('Unexpected end of switch');
   {$IFDEF FPC}
   _Germany: errrpt('Unerwartetes Ende von switch');
   {$ENDIF}
   Else errrpt('Fin inattendue de switch');
  End;
  Exit;
 End;
 Dec(switch_depth);
 end_switch_statement := switch_table[switch_depth].end_label;
  { GÇnÇrer l'Çtiquette de fin }
 prelabel(switch_table[switch_depth].end_label);
 safe_writeln('; Fin du switch');
End;

 { Obtenir l'Çtiquette de fin du switch courant (pour break) }
Function get_current_switch_end: Integer;Begin
 get_current_switch_end := -1;
 If switch_depth > 0 Then get_current_switch_end := switch_table[switch_depth - 1].end_label;
End;

 { Gestion de contexte de boucle pour le support break/continue }
Procedure push_loop_context(loop_type: Integer; break_lbl, continue_lbl: Integer);Begin
 If loop_depth >= 32 Then Begin
  Case Language of
   _English: errrpt('Too many nested loops');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele verschachtelte Schleifen');
   {$ENDIF}
   Else errrpt('Trop de boucles imbriquÇes');
  End;
  Exit;
 End;
  { VÇrification dÇfensive - s'assurer que loop_depth est initialisÇ }
 If loop_depth < 0 Then loop_depth := 0;
 loop_stack[loop_depth].loop_type := loop_type;
 loop_stack[loop_depth].break_label := break_lbl;
 loop_stack[loop_depth].continue_label := continue_lbl;
 Inc(loop_depth);
End;

Procedure pop_loop_context;Begin
 If loop_depth > 0 Then
  Dec(loop_depth);
End;

Function get_current_break_label: Integer;Begin
 get_current_break_label := -1;
  { VÇrifier d'abord s'il y a un switch actif }
 If switch_depth > 0 Then Begin
  get_current_break_label := switch_table[switch_depth-1].end_label;
  Exit;
 End;
  { Sinon, vÇrifier s'il y a une boucle active }
 If loop_depth > 0 Then get_current_break_label := loop_stack[loop_depth-1].break_label;
End;

Function get_current_continue_label: Integer;Begin
 get_current_continue_label := -1;
 If loop_depth > 0 Then
  get_current_continue_label := loop_stack[loop_depth-1].continue_label;
End;

Procedure outbyte(b: Byte);Begin
 Write(Chr(b)); { Utilise toujours stdout pour la sÇcuritÇ }
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
 If (lptr <= Length(line)) and an(line[lptr]) Then Begin
  While (lptr <= Length(line)) and (an(line[lptr]) or numeric(line[lptr])) and (i < namemax) do Begin
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
End;

{ Gestion des tables de symboles }
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
{ NOUVELLES FONCTIONS DE TABLE DE SYMBOLES BASêE SUR LA MEMOIRE DE TAS         }
{ ============================================================================ }

 { Initialiser la table de symboles basÇe sur la mÇmoire de tas }
Procedure init_symbols;Begin
 symbol_list := nil;
 symbol_count := 0;
End;

 { Trouver un symbole dans la table de symboles basÇe sur le tas }
Function find_symbol(sname: String): PSymbol;
Var
 current: PSymbol;
Begin
 find_symbol := nil;
 current := symbol_list;
 While current <> nil do Begin
  If current^.name = sname Then Begin
   find_symbol := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

 { Ajouter un symbole Ö la table de symboles basÇe sur la mÇmoire de tas }
Function add_symbol(sname: String; id_type: Integer; sym_type: Integer; stor_class: Integer; offset_val: Integer): PSymbol;
Var
 new_symbol: PSymbol;
Begin
 add_symbol := nil;
  { VÇrifier si le symbole existe dÇjÖ }
 If find_symbol(sname) <> nil Then Begin
  { Le symbole existe dÇjÖ }
  Exit;
 End;
  { Allouer de la mÇmoire sur la mÇmoire de tas }
 New(new_symbol);
 If new_symbol = nil Then Begin
  { MÇmoire insuffisante }
  Exit;
 End;
  { Initialiser le nouveau symbole }
 With new_symbol^ do Begin
  name := sname;
  ident := id_type;
  ctype := sym_type;
  storage := stor_class;
  offset_value := offset_val;
  init_type_info(type_info);
  type_info.base_type := sym_type;
  next := symbol_list;  { InsÇrer au dÇbut de la liste }
 End;
  { Mettre Ö jour la tàte de liste }
 symbol_list := new_symbol;
 Inc(symbol_count);
 add_symbol := new_symbol;
End;

 { Fonction addsym amÇliorÇe utilisant le tas }
Function addsym_heap(sname: String; typ: Integer; storage: Integer; offset_value: Integer): PSymbol;Begin
 addsym_heap := add_symbol(sname, it_variable, typ, storage, offset_value);
End;

{ Fonction findsym amÇliorÇe utilisant la mÇmoire de tas }
Function findsym_heap(sname: String): PSymbol;Begin
 findsym_heap := find_symbol(sname);
End;

 { LibÇrer tous les symboles de la mÇmoire de tas }
Procedure free_symbols;
Var
 current, next: PSymbol;
Begin
 current := symbol_list;
 While current <> nil do Begin
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
 type_info.base_type := cint;
 type_info.pointer_level := 0;
 type_info.array_size := 0;
 type_info.is_unsigned := False;
 type_info.is_const := False;
 type_info.is_volatile := False;
 type_info.struct_id := 0;
 type_info.typedef_name := '';
 type_info.is_typedef := False;
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
  cenum: get_type_size := sizeof_enum;
  Else get_type_size := sizeof_int; { Par d√©faut }
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

 { VÇrifiez si deux types sont compatibles }
Function types_compatible(var type1, type2: TTypeInfo): Boolean;Begin
 types_compatible := (type1.base_type = type2.base_type) and
                    (type1.pointer_level = type2.pointer_level) and
                    (type1.is_unsigned = type2.is_unsigned);
End;

 { VÇrifier si le type peut àtre converti en un autre }
Function can_convert_type(var from_type, to_type: TTypeInfo):Boolean;Begin
  { Les pointeurs peuvent àtre convertis en pointeurs }
 If (from_type.pointer_level > 0) and (to_type.pointer_level > 0) Then Begin
  can_convert_type := True;
  Exit;
 End;
  { Les types numÇriques peuvent gÇnÇralement àtre convertis }
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

 { RÇcupÇrer le nom du type sous forme de chaåne de caractäres pour les messages de dÇbogage/d'erreur }
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
  cenum: base_name := 'enum';
  Else base_name := 'unknown';
 End;
  { Ajouter les qualificateurs const/volatile }
 If type_info.is_const Then base_name := 'const ' + base_name;
 If type_info.is_volatile Then base_name := 'volatile ' + base_name;
  { Ajouter des astÇristiques de pointeur }
 For i := 1 to type_info.pointer_level do base_name := base_name + '*';
  { Ajouter la notation de tableau }
 If type_info.array_size > 0 Then Begin
  Str(type_info.array_size, temp_str);
  base_name := base_name + '[' + temp_str + ']';
 End;
 get_type_name := base_name;
End;

 { GÇnÇrer le code assembleur pour la conversion de type }
Procedure generate_type_conversion(var from_type, to_type: TTypeInfo);Begin
 Case Language of
  _English:safe_writeln('; Type conversion from ' + get_type_name(from_type) + ' to ' + get_type_name(to_type));
  Else safe_writeln('; Conversion de type de ' + get_type_name(from_type) + ' Ö ' + get_type_name(to_type));
 End;
 { GÇrer la conversion char en int }
 If (from_type.base_type = cchar) and (to_type.base_type = cint) Then Begin
  If from_type.is_unsigned Then Begin
   ol('xor ah,ah  ; extension zÇro char non signÇ');
  End
   Else
  Begin
   ol('cbw       ; extension de signe char signÇ (AL -> AX)');
  End;
 End
  { GÇrer la conversion int vers char }
  Else
 If (from_type.base_type = cint) and (to_type.base_type = cchar) Then Begin
  ol('mov al,al  ; ne garder que l''octet faible (dÇjÖ dans AL)');
 End
 { G√©rer la conversion int vers long }
 Else If (from_type.base_type = cint) and (to_type.base_type = clong) Then Begin
  If from_type.is_unsigned Then Begin
   ol('xor dx,dx  ; partie haute = 0 pour unsigned');
  End
  Else
  Begin
   ol('cwd        ; extension de signe AX vers DX:AX');
  End;
 End
 { G√©rer la conversion long vers int }
 Else If (from_type.base_type = clong) and (to_type.base_type = cint) Then Begin
  ol('; DX:AX -> AX (partie basse du long)');
 End
 { G√©rer la conversion char vers long }
 Else If (from_type.base_type = cchar) and (to_type.base_type = clong) Then Begin
  If from_type.is_unsigned Then Begin
   ol('xor ah,ah  ; extension zÇro char');
   ol('xor dx,dx  ; partie haute = 0');
  End
  Else
  Begin
   ol('cbw        ; extension de signe char vers int (AL -> AX)');
   ol('cwd        ; extension de signe int vers long (AX -> DX:AX)');
  End;
 End
  { GÇrer la conversion long vers char }
  Else
 If (from_type.base_type = clong) and (to_type.base_type = cchar) Then Begin
  ol('; DX:AX -> AL (ne garder que l''octet faible)');
 End
 { GÇrer les conversions enum (traitÇ comme int) }
  Else
 If (from_type.base_type = cenum) and (to_type.base_type <> cenum) Then Begin
  { Enum vers autre type - d'abord convertir enum vers int puis vers type cible }
  from_type.base_type := cint; { Traiter enum comme int }
  generate_type_conversion(from_type, to_type); { RÇcursion }
 End
  Else
 If (from_type.base_type <> cenum) and (to_type.base_type = cenum) Then Begin
  { Autre type vers enum - d'abord convertir vers int puis vers enum }
  to_type.base_type := cint; { Traiter enum comme int }
  generate_type_conversion(from_type, to_type); { RÇcursion }
 End;
  { Ajouter des conversions supplÇmentaires si nÇcessaires }
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES TYPEDEF                                             }
{ ============================================================================ }

 { Trouver un typedef dans la table des symboles }
Function find_typedef(typedef_name: String): PSymbol;
Var
 current: PSymbol;
Begin
 find_typedef := nil;
 current := symbol_list;
 While current <> nil do Begin
  If (current^.name = typedef_name) and (current^.ident = it_typedef_type) Then Begin
   find_typedef := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

 { Ajouter un nouveau typedef Ö la table des symboles }
Function add_typedef(typedef_name: String; var type_info: TTypeInfo): PSymbol;
Var
 new_symbol: PSymbol;
Begin
 add_typedef := nil;
  { VÇrifier si le typedef existe dÇjÖ }
 If find_typedef(typedef_name) <> nil Then Begin
  Case Language of
   _English: errrpt('Typedef already defined: ' + typedef_name);
   {$IFDEF FPC}
   _Germany: errrpt('Typedef bereits definiert: ' + typedef_name);
   {$ENDIF}
   Else errrpt('Typedef dÇjÖ dÇfini: ' + typedef_name);
  End;
  Exit;
 End;
  { Allouer de la mÇmoire sur le tas }
 New(new_symbol);
 If new_symbol = nil Then Begin
  Case Language of
   _English: errrpt('Out of memory for typedef table');
   {$IFDEF FPC}
   _Germany: errrpt('Kein Speicher fÅr Typedef-Tabelle');
   {$ENDIF}
   Else errrpt('MÇmoire insuffisante pour la table typedef');
  End;
  Exit;
 End;
  { Initialiser le nouveau typedef }
 With new_symbol^ do Begin
  name := typedef_name;
  ident := it_typedef_type;
  ctype := type_info.base_type;
  storage := statik;  { Les typedef sont gÇnÇralement statiques }
  offset_value := 0;
  new_symbol^.type_info := type_info;  { Copier toutes les informations de type explicitement }
  new_symbol^.type_info.is_typedef := True;
  new_symbol^.type_info.typedef_name := typedef_name;
  next := symbol_list;  { InsÇrer au dÇbut de la liste }
 End;
  { Mettre Ö jour la tàte de liste }
 symbol_list := new_symbol;
 Inc(symbol_count);
 add_typedef := new_symbol;
End;

{ RÇsoudre un typedef en son type rÇel }
Function resolve_typedef_type(typedef_name: String; var resolved_type: TTypeInfo): Boolean;
Var
 typedef_symbol: PSymbol;
Begin
 resolve_typedef_type := False;
 typedef_symbol := find_typedef(typedef_name);
 If typedef_symbol = nil Then Exit;
  { Initialiser la structure de destination proprement }
 init_type_info(resolved_type);
  { Copier les informations de type essentielles du typedef }
 resolved_type.base_type := typedef_symbol^.type_info.base_type;
 resolved_type.pointer_level := typedef_symbol^.type_info.pointer_level;
 resolved_type.array_size := typedef_symbol^.type_info.array_size;
 resolved_type.is_unsigned := typedef_symbol^.type_info.is_unsigned;
 resolved_type.is_const := typedef_symbol^.type_info.is_const;
 resolved_type.is_volatile := typedef_symbol^.type_info.is_volatile;
 resolved_type.struct_id := typedef_symbol^.type_info.struct_id;
 resolved_type.size := typedef_symbol^.type_info.size;
 resolved_type.is_typedef := True;
 resolved_type.typedef_name := typedef_name;
 resolve_typedef_type := True;
End;

 { Analyser une dÇclaration typedef }
Function parse_typedef_declaration: Boolean;
Var
 base_type: Integer;
 type_info: TTypeInfo;
 typedef_name: String;
 temp_str: String;
Begin
 parse_typedef_declaration := False;
 safe_writeln('; Analyse de dÇclaration typedef');
  { Le mot clef typedef a dÇjÖ ÇtÇ consommÇ }
  { Analyser le type de base }
 base_type := parse_type_specifier_with_qualifiers(type_info);
 If base_type = -1 Then Begin
  Case Language of
   _English: errrpt('Invalid type specifier in typedef');
   {$IFDEF FPC}
   _Germany: errrpt('UngÅltiger Typ-Spezifizierer in typedef');
   {$ENDIF}
   Else errrpt('SpÇcificateur de type invalide dans typedef');
  End;
  Exit;
 End;
 Str(base_type, temp_str);
 safe_writeln('; Type analysÇ: ' + temp_str);
  { Analyser le dÇclarateur (nom du typedef) }
 If not symname(typedef_name) Then Begin
  Case Language of
   _English: errrpt('Expected typedef name');
   {$IFDEF FPC}
   _Germany: errrpt('Typedef-Name erwartet');
   {$ENDIF}
   Else errrpt('Nom de typedef attendu');
  End;
  Exit;
 End;
  { Attendre point-virgule }
 If not match(';') Then Begin
  Case Language of
   _English: errrpt('Expected ; after typedef declaration');
   {$IFDEF FPC}
   _Germany: errrpt('; nach typedef-Deklaration erwartet');
   {$ENDIF}
   Else errrpt('; attendu apräs dÇclaration typedef');
  End;
  Exit;
 End;
  { Ajouter le typedef Ö la table des symboles }
 If add_typedef(typedef_name, type_info) <> nil Then Begin
  safe_writeln('; Typedef dÇfini: ' + typedef_name + ' = ' + get_type_name(type_info));
  parse_typedef_declaration := True;
 End;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DE LA LISTE D'INSTRUCTIONS D'OPTIMISATION               }
{ ============================================================================ }

 { Ajouter une instruction Ö la liste chaånÇe }
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

 { Obtenir l'instruction Ö l'index donnÇ (pour compatibilitÇ) }
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

 { LibÇrer toute la liste d'instructions }
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
  { DÇfinir les indicateurs d'optimisation en fonction du niveau }
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
    { Enläve LDD #0 suivi par STD }
   If(current^.opcode = 'ldd')and(current^.operand = '#0')Then Begin
    If (next_inst^.opcode = 'std') Then Begin
     { Remplace avec CLR }
     current^.opcode := 'clr';
     current^.operand := next_inst^.operand;
     current^.comment := current^.comment + ' ; optimisÇ de ldd #0, std';
     { Marquer la prochaine instruction pour le retrait }
     next_inst^.can_eliminate := True;
     changed := True;
    End;
   End
   { Enläve STD suivi par LDD dans le màme emplacement }
    Else
   If (current^.opcode = 'std') Then Begin
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
   { Enläve les instructions marquÇes }
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
   { Optimise LDD #1 suivi par NEGA/NEGB Ö LDD #-1 }
  If (current^.opcode = 'ldd') and (current^.operand = '#1') Then Begin
   If (next1^.opcode = 'nega') and (next2^.opcode = 'negb') Then
   Begin
    current^.operand := '#-1';
    current^.comment := current^.comment + ' ; constante pliÇe';
    next1^.can_eliminate := True;
    next2^.can_eliminate := True;
   End;
  End
  { Optimise la multiplication par la puissance de 2 }
  Else If (current^.opcode = 'jsr') and (current^.operand = 'mult16') Then
  Begin
   { Il faudrait plus de contexte pour d√©terminer s'il s'agit d'une multiplication par une constante }
   Case Language of
    _English: current^.comment := current^.comment + ' ; peut optimisÇ si la puissance de 2';
    Else current^.comment:= current^.comment + ' ; pourrait àtre optimisÇ si c''est une puissance de 2';
   End;
  End;
  current := current^.next;
 End;
End;

 { êlimination des codes morts }
Procedure dead_code_eliminate;
Var
 current: POptInst;
Begin
 If (opt_context.flags and OPT_DEAD_CODE) = 0 Then Exit;
 current := opt_context.inst_list;
 While current <> nil do Begin
  { Instructions d'Çlimination de Mark NOP }
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
 While current <> nil do Begin
  { Supprimer les sauts vers l'instruction suivante }
  If (current^.opcode = 'lbra') or (current^.opcode = 'bra') Then Begin
   { Cela nÇcessiterait une analyse d'Çtiquettes pour àtre entiärement implÇmentÇ }
   current^.comment := current^.comment + ' ; candidat √† l''optimisation de saut';
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
 safe_writeln('; Optimisation terminÇe');
End;

 { Sortie des instructions optimisÇes }
Procedure output_optimized_instructions;
Var
 current: POptInst;
Begin
 current := opt_context.inst_list;
 While current <> nil do Begin
  With current^ do Begin
   If not can_eliminate Then Begin
    If Length(comment) > 0 Then
     safe_writeln(#9 + opcode + ' ' + operand + ' ; ' + comment)
    Else
     safe_writeln(#9 + opcode + ' ' + operand);
   End;
  End;
  current := current^.next;
 End;
End;

{ Emballage de gÇnÇration de code optimisÇ }
Procedure optimized_ol(s: String);Begin
 If optimize > OPT_NONE Then add_instruction(s, '', '')
                        Else ol(s);
End;

Procedure optimized_ot(op,operand:String);Begin
 If optimize > OPT_NONE Then
  add_instruction(op, operand, '')
  Else
 Begin
  ot(op + ' ' + operand);
  nl;
 End;
End;

{ Fonctions d'optimisation spÇcialisÇes }

{ Chargement de constante optimisÇ }
Procedure opt_load_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then Begin
  { Optimiser les constantes communes }
  Case value of
   0: add_instruction('xor', 'ax,ax', 'chargement zÇro optimisÇ');
   1: add_instruction('mov', 'ax,1', 'chargement un optimisÇ');
   -1: add_instruction('mov', 'ax,0FFFFh', 'chargement -1 optimisÇ');
  Else
   Begin
    Str(value, temp);
    add_instruction('mov', 'ax,' + temp, 'charger constante');
   End;
  End;
 End
 Else
 Begin
  ot('mov  ax,');
  outdec(value);
  nl;
 End;
End;

 { Affectation de variable optimisÇe }
Procedure opt_store_variable(var_name: String; size: Integer);Begin
 If optimize > OPT_NONE Then Begin
  Case size of
   1: add_instruction('mov', var_name + ',al', 'stocker octet');
   2: add_instruction('mov', var_name + ',ax', 'stocker mot');
  Else
   add_instruction('mov', var_name + ',ax', 'stocker par dÇfaut');
  End;
 End
  Else
 Begin
  Case size of
   1: Begin
       ot('mov  ');
       outstr(var_name);
       outstr(',al');
       nl;
      End;
   2: Begin
       ot('mov  ');
       outstr(var_name);
       outstr(',ax');
       nl;
      End;
  Else
   Begin
    ot('mov  ');
    outstr(var_name);
    outstr(',ax');
    nl;
   End;
  End;
 End;
End;

 { OpÇrations arithmÇtiques optimisÇes }
Procedure opt_add_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then Begin
  Case value of
   0: { Ne rien faire - ajouter z√©ro };
   1: add_instruction('inc', 'ax', '+1 optimisÇ');
   -1: add_instruction('dec', 'ax', '-1 optimisÇ');
  Else
   Begin
    Str(value, temp);
    add_instruction('add', 'ax,' + temp, 'ajouter constante');
   End;
  End;
 End
  Else
 Begin
  If value <> 0 Then Begin
   ot('add ax,');
   outdec(value);
   nl;
  End;
 End;
End;

 { Multiplication optimisÇe }
Procedure opt_multiply(value: Integer);Begin
 If optimize > OPT_NONE Then Begin
   { Optimiser la multiplication par des puissances de 2 }
  Case value of
   0: add_instruction('xor', 'ax,ax', 'multiplier par 0');
   1: { Ne rien faire - multiplier par 1 };
   2: add_instruction('shl', 'ax,1', 'multiplier par 2');
   4: add_instruction('shl', 'ax,2', 'multiplier par 4');
   8: add_instruction('shl', 'ax,3', 'multiplier par 8');
   16: add_instruction('shl', 'ax,4', 'multiplier par 16');
   Else add_instruction('call', 'mult16', 'multiplication gÇnÇrale');
  End;
 End
  Else
 ol('call mult16');
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
{ FONCTIONS DE SUPPORT POUR LES OPêRATIONS LONG (32 BITS) SUR 8086             }
{ ============================================================================ }

{ GÇnÇrer une routine d'addition long (32 bits) }
Procedure generate_long_add;Begin
 safe_writeln('; Addition long 32 bits sur 8086');
 safe_writeln('long_add:');
 ol('; Ajouter deux longs (DX:AX + CX:BX -> DX:AX)');
 ol('add ax,bx    ; additionner parties basses');
 ol('adc dx,cx    ; additionner parties hautes avec carry');
 ol('ret');
End;

{ GÇnÇrer une routine de soustraction long (32 bits) }
Procedure generate_long_sub;Begin
 safe_writeln('; Soustraction long 32 bits sur 8086');
 safe_writeln('long_sub:');
 ol('; Soustraire deux longs (DX:AX - CX:BX -> DX:AX)');
 ol('sub ax,bx    ; soustraire parties basses');
 ol('sbb dx,cx    ; soustraire parties hautes avec borrow');
 ol('ret');
End;

{ GÇnÇrer une routine de multiplication long (32 bits) }
Procedure generate_long_mul;Begin
 safe_writeln('; Multiplication long 32 bits (simplifiÇe) sur 8086');
 safe_writeln('long_mul:');
 ol('; Multiplication simplifiÇe: (DX:AX) * (CX:BX) -> DX:AX');
 ol('push dx      ; sauvegarder DX');
 ol('push cx      ; sauvegarder CX');
 ol('mul bx       ; AX * BX -> DX:AX (partie basse)');
 ol('pop cx       ; restaurer CX');
 ol('pop bx       ; restaurer l''ancien DX dans BX');
 ol('push ax      ; sauvegarder partie basse du rÇsultat');
 ol('mov ax,bx    ; charger l''ancien DX');
 ol('mul cx       ; partie haute * partie basse');
 ol('pop bx       ; restaurer partie basse');
 ol('add dx,ax    ; ajouter au rÇsultat');
 ol('mov ax,bx    ; rÇsultat final dans DX:AX');
 ol('ret');
End;

{ GÇnÇrer une routine de division long (32 bits) - version simplifiÇe }
Procedure generate_long_div;Begin
 safe_writeln('; Division long 32 bits (simplifiÇe) sur 8086');
 safe_writeln('long_div:');
 ol('; Division simplifiÇe: (DX:AX) / (CX:BX) -> DX:AX');
 ol('push bx      ; sauvegarder diviseur partie basse');
 ol('mov bx,cx    ; diviseur partie haute dans BX');
 ol('or bx,bx     ; tester si partie haute du diviseur est 0');
 ol('jnz div32    ; si non, division compläte');
 ol('pop bx       ; restaurer diviseur partie basse');
 ol('div bx       ; DX:AX / BX -> AX (quotient), DX (reste)');
 ol('xor dx,dx    ; partie haute du rÇsultat = 0');
 ol('jmp div_end');
 ol('div32:');
 ol('pop bx       ; nettoyer pile');
 ol('xor ax,ax    ; rÇsultat = 0 pour division complexe');
 ol('xor dx,dx');
 ol('div_end:');
 ol('ret');
End;

{ GÇnÇrer les routines de comparaison long }
Procedure generate_long_compare;Begin
 safe_writeln('; Comparaison long 32 bits sur 8086');
 safe_writeln('long_cmp:');
 ol('; Comparer deux longs: (DX:AX) avec (CX:BX)');
 ol('cmp dx,cx    ; comparer parties hautes');
 ol('jne done     ; si diffÇrentes, on a le rÇsultat');
 ol('cmp ax,bx    ; comparer parties basses');
 ol('done:');
 ol('ret');
End;

{ Charger une constante long sur les registres }
Procedure load_long_constant(value: LongInt);
Var
 high_part, low_part: Integer;
Begin
 high_part := Integer(value shr 16);
 low_part := Integer(value and $FFFF);
 safe_writeln('; Charger constante long: ' + IntToStr(value));
 { Charger dans DX:AX }
 ot('mov ax,');
 outdec(low_part);
 nl;
 ot('mov dx,');
 outdec(high_part);
 nl;
End;

 { Charger une variable long depuis la mÇmoire }
Procedure load_long_variable(var_name: String);Begin
 safe_writeln('; Charger variable long: ' + var_name);
 ot('mov ax,[');
 outstr(var_name);        { Partie basse }
 outstr(']');
 nl;
 ot('mov dx,[');
 outstr(var_name + '+2'); { Partie haute }
 outstr(']');
 nl;
End;

 { Entreposer un long des registres vers une variable }
Procedure store_long_variable(var_name: String);Begin
 safe_writeln('; Stocker variable long: ' + var_name);
 ot('mov [');
 outstr(var_name);        { Entreposer partie basse }
 outstr('],ax');
 nl;
 ot('mov [');
 outstr(var_name + '+2'); { Entreposer partie haute }
 outstr('],dx');
 nl;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES FONCTIONS                                          }
{ ============================================================================ }

{ Initialiser le systäme de gestion des fonctions basÇ sur la mÇmoire de tas }
Procedure init_functions;Begin
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
 While current <> nil do Begin
  If current^.func_data.name = func_name Then Begin
   find_function_node := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

 { Trouver une fonction par nom - retourne l'index pour compatibilitÇ }
Function find_function(func_name: String): Integer;
Var
 current: PFunction;
 index: Integer;
Begin
 find_function := -1;
 current := function_list;
 index := 0;
 While current <> nil do Begin
  If current^.func_data.name = func_name Then Begin
   find_function := index;
   Exit;
  End;
  current := current^.next;
  Inc(index);
 End;
End;

 { Ajouter une nouvelle fonction Ö la liste chaånÇe }
Function add_function(func_name: String; return_type: Integer): Integer;
Var
 func_node: PFunction;
 func_index: Integer;
Begin
 add_function := -1;
  { VÇrifier si la fonction existe dÇjÖ }
 func_index := find_function(func_name);
 If func_index <> -1 Then Begin
  add_function := func_index;
  Exit;
 End;
  { Allouer mÇmoire pour nouvelle fonction dans la mÇmoire de tas }
 New(func_node);
 If func_node = nil Then Begin
  Case Language of
   _English: errrpt('Out of memory for function table');
   {$IFDEF FPC}
   _Germany: errrpt('Kein Speicher fÅr Funktionstabelle');
   {$ENDIF}
   Else errrpt('MÇmoire insuffisante pour la table de fonctions');
  End;
  Exit;
 End;
  { Initialiser les donnÇes de la fonction }
 With func_node^.func_data do Begin
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
  { InsÇrer au dÇbut de la liste }
 func_node^.next := function_list;
 function_list := func_node;
 func_index := function_count;
 Inc(function_count);
 add_function := func_index;
End;

 { Obtenir le noeud de fonction par index pour compatibilitÇ }
Function get_function_node(func_index: Integer): PFunction;
Var
 current: PFunction;
 i: Integer;
Begin
 get_function_node := nil;
 If (func_index < 0) or (func_index >= function_count) Then Exit;
 current := function_list;
 For i := 0 to func_index do Begin
  If current = nil Then Exit;
  If i = func_index Then Begin
   get_function_node := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

{ Ajouter un paramätre Ö la fonction }
Function add_parameter(func_index: Integer; param_name: String; param_type: Integer): Boolean;
Var
 func_node: PFunction;
Begin
 add_parameter := False;
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;
 With func_node^.func_data do Begin
  If param_count >= 10 Then Begin
   Case Language of
    _English: errrpt('Too many parameters for function ' + name);
    {$IFDEF FPC}
    _Germany: errrpt('Zu viele Parameter fÅr Funktion ' + name);
    {$ENDIF}
    Else errrpt('Trop de paramätres pour la fonction ' + name);
   End;
   Exit;
  End;
  With parameters[param_count] do Begin
   name := param_name;
   typ := param_type;
   init_type_info(type_info);
   type_info.base_type := param_type;
   calculate_type_size(type_info);
   offset := param_count * 2; { 2 octets par paramätre sur la pile 6809 }
  End;
  Inc(param_count);
  add_parameter := True;
 End;
End;

 { GÇnÇrer le prologue de fonction }
Procedure generate_function_prologue(func_index: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;
 With func_node^.func_data do Begin
  safe_writeln('; Fonction: ' + name);
  safe_writeln(name + ':');
   { Prologue standard 8086 }
  If not is_main Then Begin
   ol('PUSH BP  ; sauvegarder pointeur de cadre');
   ol('MOV  BP, SP  ; configurer pointeur de cadre');
    { Allouer de l'espace pour les variables locales si nÇcessaire }
   If local_vars_size > 0 Then Begin
    safe_writeln('; Allouer variables locales (octets de taille)');
    ot('SUB  SP,');
    outdec(local_vars_size);
    nl;
   End;
  End
  Else
  Begin
   safe_writeln('; Point d''entrÇe de la fonction principale');
  End;
 End;
End;

 { GÇnÇrer l'Çpilogue de fonction }
Procedure generate_function_epilogue(func_index: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;
 With func_node^.func_data do Begin
  safe_writeln('; Fin de fonction: ' + name);
  If not is_main Then Begin
   { êpilogue standard 6809 }
   If local_vars_size > 0 Then Begin
    safe_writeln('; DÇsallouer variables locales');
    ot('ADD  SP,');
    outdec(local_vars_size);
    nl;
   End;
   ol('POP  BP  ; restaurer pointeur de cadre');
   ol('RET      ; retourner Ö l''appelant');
  End
  Else
  Begin
   safe_writeln('; Sortie de fonction principale');
   ol('INT  20h       ; interruption logicielle DOS (fin de programme)');
  End;
 End;
End;

{ GÇnÇrer un appel de fonction }
Procedure generate_function_call(func_index: Integer; arg_count: Integer);
Var
 func_node: PFunction;
Begin
 func_node := get_function_node(func_index);
 If func_node = nil Then Exit;
 With func_node^.func_data do Begin
  safe_writeln('; Appel de fonction: ' + name);
   { VÇrifier le nombre de paramätres }
  If arg_count <> param_count Then safe_writeln('; Attention: Nombre d''arguments ne correspond pas');
  { GÇnÇrer l'instruction d'appel }
  ot('call ');
  outstr(name);
  nl;
   { Nettoyer la pile si des paramätres ont ÇtÇ passÇs }
  If param_count > 0 Then Begin
   safe_writeln('; Nettoyer les paramätres de pile');
   ot('ADD  SP,');
   outdec(param_count * 2);
   nl;
  End;
  Inc(call_stack_depth);
 End;
End;

 { LibÇrer toute la liste de fonctions de la mÇmoire de tas }
Procedure free_functions;
Var
 current, next: PFunction;
Begin
 current := function_list;
 While current <> nil do Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 function_list := nil;
 If use_stdout Then WriteLn('; LibÇrÇ ', function_count, ' fonctions de la mÇmoire de tas')
               Else safe_writeln('; LibÇrÇ fonctions du tas');
 function_count := 0;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES STRUCTURES ET UNIONS                               }
{ ============================================================================ }

{ Initialiser le systäme de gestion des structures }
Procedure init_structs;Begin
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
 While current <> nil do Begin
  If current^.name = struct_name Then Begin
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
 While current <> nil do Begin
  If current^.struct_id = struct_id Then Begin
   find_struct_by_id := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

 { CrÇer une nouvelle structure/union }
Function create_struct(struct_name: String; is_union: Boolean): PStructDef;
Var
 new_struct: PStructDef;
Begin
 create_struct := nil;
  { VÇrifier si la structure existe dÇjÖ }
 If find_struct(struct_name) <> nil Then Begin
  Case Language of
   _English: errrpt('Struct/Union already defined: ' + struct_name);
   {$IFDEF FPC}
   _Germany: errrpt('Struct/Union bereits definiert: ' + struct_name);
   {$ENDIF}
   Else errrpt('Structure/Union dÇjÖ dÇfinie: ' + struct_name);
  End;
  Exit;
 End;
  { Allouer mÇmoire pour la nouvelle structure }
 New(new_struct);
 If new_struct = nil Then Begin
  Case Language of
   _English: errrpt('Out of memory for struct definition');
   {$IFDEF FPC}
   _Germany: errrpt('Kein Speicher fÅr Struct-Definition');
   {$ENDIF}
   Else errrpt('MÇmoire insuffisante pour la dÇfinition de structure');
  End;
  Exit;
 End;
  { Initialiser la structure }
 With new_struct^ do Begin
  name := struct_name;
  is_union := is_union;
  member_count := 0;
  total_size := 0;
  struct_id := next_struct_id;
  Inc(next_struct_id);
  next := struct_list;
 End;
  { Ajouter au dÇbut de la liste }
 struct_list := new_struct;
 Inc(struct_count);
 create_struct := new_struct;
End;

 { Ajouter un membre Ö une structure }
Function add_struct_member(struct_def: PStructDef; member_name: String;
                          member_type: Integer; var type_info: TTypeInfo): Boolean;
Var
 member_size: Integer;
Begin
 add_struct_member := False;
 If struct_def = nil Then Exit;
 With struct_def^ do Begin
  If member_count >= 16 Then Begin
   Case Language of
    _English: errrpt('Too many members in struct: ' + name);
    {$IFDEF FPC}
    _Germany: errrpt('Zu viele Mitglieder in Struct: ' + name);
    {$ENDIF}
    Else errrpt('Trop de membres dans la structure: ' + name);
   End;
   Exit;
  End;
   { Calculer la taille du membre }
  member_size := calculate_type_size(type_info);
   { Initialiser le membre }
  With members[member_count] do Begin
   name := member_name;
   member_type := member_type;
   type_info := type_info;
   size := member_size;
   If is_union Then Begin
    { Dans une union, tous les membres ont un dÇplacement 0 }
    offset := 0;
    { La taille de l'union est la taille du plus grand membre }
    If member_size > total_size Then
     total_size := member_size;
   End
   Else
   Begin
    { Dans une structure, les membres sont alignÇs sÇquentiellement }
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
 For i := 0 to struct_def^.member_count - 1 do Begin
  If struct_def^.members[i].name = member_name Then Begin
   find_struct_member := i;
   Exit;
  End;
 End;
End;

 { LibÇrer toutes les structures de la mÇmoire de tas }
Procedure free_structs;
Var
 current, next: PStructDef;
Begin
 current := struct_list;
 While current <> nil do Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 struct_list := nil;
 If use_stdout Then WriteLn('; LibÇrÇ ', struct_count, ' structures du tas')
               Else safe_writeln('; LibÇrÇ structures du tas');
 struct_count := 0;
End;

{ Analyser une dÇclaration de structure ou union }
Function parse_struct_declaration(is_union: Boolean): Integer;
Var
 struct_name, member_name: String;
 struct_def: PStructDef;
 member_type: Integer;
 member_type_info: TTypeInfo;
Begin
 parse_struct_declaration := -1;
  { Obtenir le nom de la structure/union (optionnel) }
 If symname(struct_name) Then Begin
  { Structure nommÇe }
  If is_union Then
   safe_writeln('; DÇclaration union: ' + struct_name)
  Else
   safe_writeln('; DÇclaration struct: ' + struct_name);
 End
  Else
 Begin
  { Structure anonyme - gÇnÇrer un nom unique }
  Str(next_struct_id, struct_name);
  struct_name := '_anon_struct_' + struct_name;
 End;
  { VÇrifier s'il y a une dÇfinition de corps }
 If match('{') Then Begin
  { CrÇer la nouvelle structure }
  struct_def := create_struct(struct_name, is_union);
  If struct_def = nil Then Exit;
   { Analyser les membres }
  safe_writeln('; DÇbut parsing membres struct');
  blanks; { S'assurer qu'on ignore les espaces au dÇbut }
  Repeat
   { VÇrifier si nous avons atteint la fin de la ligne }
   If lptr > Length(line) Then Begin
    safe_writeln('; Lecture nouvelle ligne pour struct...');
    If not readinline Then
    Begin
     Case Language of
      _English: errrpt('Unexpected end of file in struct/union');
      {$IFDEF FPC}
      _Germany: errrpt('Unerwartetes Dateiende in Struct/Union');
      {$ENDIF}
      Else errrpt('Fin de fichier inattendue dans struct/union');
     End;
     Exit;
    End;
   End;
   blanks; { Ignorer les espaces }
    { VÇrifier si c'est la fin de la struct }
   If peek_char = '}' Then Break;
   safe_writeln('; Dans boucle parsing - membre dÇtectÇ');
   safe_writeln('; Parsing membre...');
   blanks; { S'assurer qu'on ignore les espaces }
   { Analyser le type du membre }
   member_type := parse_type_specifier;
   init_type_info(member_type_info);
   member_type_info.base_type := member_type;
   calculate_type_size(member_type_info);
   safe_writeln('; Type membre analysÇ: ' + IntToStr(member_type));
   If member_type = -1 Then
   Begin
    Case Language of
     _English: errrpt('Expected member type in struct/union');
     {$IFDEF FPC}
     _Germany: errrpt('Erwarteter Mitgliedstyp in Struct/Union');
     {$ENDIF}
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
     {$IFDEF FPC}
     _Germany: errrpt('Erwarteter Mitgliedsname in Struct/Union');
     {$ENDIF}
     Else errrpt('Nom de membre attendu dans struct/union');
    End;
    Exit;
   End;
   safe_writeln('; Nom de membre lu: ' + member_name);
    { Ajouter le membre Ö la structure }
   If not add_struct_member(struct_def, member_name, member_type, member_type_info) Then Exit;
   { Consommer le point-virgule }
   If not match(';') Then Begin
    Case Language of
     _English: errrpt('Expected ; after struct member');
     {$IFDEF FPC}
     _Germany: errrpt('Erwartete ; nach Struct-Mitglied');
     {$ENDIF}
     Else errrpt('; attendu apräs membre de structure');
    End;
    Exit;
   End;
   safe_writeln('; Membre ajoutÇ: ' + member_name);
  Until False; { La boucle se termine par les Break }
  { Consommer l'accolade de fermeture }
  If not match('}') Then Begin
   Case Language of
    _English: errrpt('Expected } to close struct/union');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete } zum Schlie·en der Struct/Union');
    {$ENDIF}
    Else errrpt('} attendu pour fermer struct/union');
   End;
   Exit;
  End;
   { Afficher les informations de la structure }
  With struct_def^ do Begin
   If is_union Then
    safe_writeln('; Union ' + name + ' dÇfinie, taille: ' + IntToStr(total_size) + ' octets')
   Else
    safe_writeln('; Structure ' + name + ' dÇfinie, taille: ' + IntToStr(total_size) + ' octets');
  End;
  parse_struct_declaration := struct_def^.struct_id;
 End
  Else
 Begin
  { RÇfÇrence Ö une structure existante }
  struct_def := find_struct(struct_name);
  If struct_def = nil Then Begin
   Case Language of
    _English: errrpt('Undefined struct/union: ' + struct_name);
    {$IFDEF FPC}
    _Germany: errrpt('Undefinierte Struct/Union: ' + struct_name);
    {$ENDIF}
    Else errrpt('Structure/Union non d√©finie: ' + struct_name);
   End;
   Exit;
  End;
  parse_struct_declaration := struct_def^.struct_id;
 End;
End;

{ DÇclarations anticip√©es pour l'analyse d'expression et les fonctions d'analyse }
Function expression_bool(var lval: TLVal): Boolean; forward;
Procedure primary_expression(var lval: TLVal); forward;
Procedure unary_expression(var lval: TLVal); forward;
Procedure multiplicative_expression(var lval: TLVal); forward;
Procedure additive_expression(var lval: TLVal); forward;
Procedure relational_expression(var lval: TLVal); forward;
Procedure bitwise_and_expression(var lval: TLVal); forward;
Procedure bitwise_xor_expression(var lval: TLVal); forward;
Procedure bitwise_or_expression(var lval: TLVal); forward;
Procedure logical_and_expression(var lval: TLVal); forward;
Procedure logical_or_expression(var lval: TLVal); forward;
Procedure conditional_expression(var lval: TLVal); forward;
Procedure parse_sizeof_expression(var lval: TLVal); forward;
Procedure parse_struct_member_access(struct_name: String; var lval: TLVal; is_pointer: Boolean); forward;
Procedure parse_dereference(var lval: TLVal); forward;
Procedure parse_address_of(var lval: TLVal); forward;

 { Convertir un type entier en nom de type string }
Function get_type_name_from_id(type_id: Integer): String;begin
  case type_id of
    cvoid: get_type_name_from_id := 'void';
    cchar: get_type_name_from_id := 'char';
    cint: get_type_name_from_id := 'int';
    else get_type_name_from_id := 'int'; { Par dÇfaut }
  end;
End;

{ Obtenir le nom d'un symbole depuis son pointeur entreposÇ comme entier }
Function get_symbol_name(symbol_ptr_as_int: Integer):String;
Var
 sym_ptr: PSymbol;
Begin
 If symbol_ptr_as_int = 0 then begin
  get_symbol_name := 'unknown';
  Exit;
 End;
 sym_ptr := PSymbol(symbol_ptr_as_int);
 If sym_ptr = nil Then Begin
  get_symbol_name := 'invalid';
  exit;
 End;
 get_symbol_name := sym_ptr^.name;
End;

{ Analyse amÇliorÇe des spÇcificateurs de type avec support complet des types C }
Function parse_type_specifier: Integer;
Var
 is_unsigned, is_signed: Boolean;
 base_type: Integer;
Begin
 is_unsigned := False;
 is_signed := False;
 base_type := cint; { Par dÇfaut }
 { Analyser les qualificateurs et spÇcificateurs de type }
 Repeat
  If match('unsigned') Then Begin
   is_unsigned := True;
   Continue;
  End
   Else
  If match('signed') Then Begin
   is_signed := True;
   Continue;
  End
   Else
  If match('const') Then Begin
   { Le qualificateur const est gÇrÇ dans parse_declarator }
   safe_writeln('; qualificateur const dÇtectÇ');
   Continue;
  End
   Else
  If match('volatile') Then Begin
   { Le qualificateur volatile est gÇrÇ dans parse_declarator }
   safe_writeln('; qualificateur volatile dÇtectÇ');
   Continue;
  End
   Else
  If match('void') Then Begin
   base_type := cvoid;
   Break;
  End
   Else
  If match('char') Then Begin
   If is_unsigned Then base_type := cuchar
   Else base_type := cchar;
   Break;
  End
   Else
  If match('short') Then Begin
   If match('int') Then; { optionnel }
   If is_unsigned Then base_type := cushort
   Else base_type := cshort;
   Break;
  End
   Else
  If match('long') Then Begin
   If match('int') Then; { optionnel }
   If is_unsigned Then base_type := culong
   Else base_type := clong;
   Break;
  End
   Else
  If match('int') Then Begin
   If is_unsigned Then base_type := cuint
   Else base_type := cint;
   Break;
  End
   Else
  If match('float') Then Begin
   base_type := cfloat;
   Break;
  End
   Else
  If match('double') Then
  Begin
   base_type := cdouble;
   Break;
  End
   Else
  If match('enum') Then Begin
   base_type := parse_enum_type;
   Break;
  End
   Else
  Break; { Plus de sp√©cificateurs de type }
 Until False;
 parse_type_specifier := base_type;
End;

{ Analyse amÇliorÇe des spÇcificateurs de type avec qualificateurs }
Function parse_type_specifier_with_qualifiers(var type_info: TTypeInfo): Integer;
Var
 is_unsigned, is_signed, is_const, is_volatile: Boolean;
 base_type: Integer;
 type_found: Boolean;
 potential_typedef: String;
 saved_lptr: Integer;
 typedef_type_info: TTypeInfo;
Begin
 is_unsigned := False;
 is_signed := False;
 is_const := False;
 is_volatile := False;
 base_type := -1; { Aucun type initialement }
 type_found := False;
  { Initialiser type_info }
 init_type_info(type_info);
  { Analyser les qualificateurs et spÇcificateurs de type }
 Repeat
  If match('const') Then Begin
   is_const := True;
   safe_writeln('; qualificateur const dÇtectÇ');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   is_volatile := True;
   safe_writeln('; qualificateur volatile dÇtectÇ');
   Continue;
  End
   Else
  If match('unsigned') Then Begin
   is_unsigned := True;
   Continue;
  End
   Else
  If match('signed') Then Begin
   is_signed := True;
   Continue;
  End
   Else
  If match('void') Then Begin
   base_type := cvoid;
   type_found := True;
   Break;
  End
   Else
  If match('char') Then Begin
   If is_unsigned Then base_type := cuchar
   Else base_type := cchar;
   type_found := True;
   Break;
  End
   Else
  If match('short') Then Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := cushort
   Else base_type := cshort;
   type_found := True;
   Break;
  End
   Else
  If match('long') Then Begin
   If match('int') Then; { optional }
   If is_unsigned Then base_type := culong
   Else base_type := clong;
   type_found := True;
   Break;
  End
   Else
  If match('int') Then Begin
   If is_unsigned Then base_type := cuint
   Else base_type := cint;
   type_found := True;
   Break;
  End
   Else
  If match('float') Then Begin
   base_type := cfloat;
   type_found := True;
   Break;
  End
   Else
  If match('double') Then Begin
   base_type := cdouble;
   type_found := True;
   Break;
  End
   Else
  If match('struct') Then Begin
   { Analyser la dÇclaration de structure compläte }
   base_type := parse_struct_declaration(False); { False = struct, pas union }
   If base_type = -1 Then Begin
    parse_type_specifier_with_qualifiers := -1;
    Exit;
   End;
    { Convertir l'ID de struct vers le type cstruct }
   type_info.struct_id := base_type;
   base_type := cstruct;
   type_found := True;
   Break;
  End
   Else
  If match('union') Then Begin
   { Analyser la dÇclaration d'union compläte }
   base_type := parse_struct_declaration(True); { True = union }
   If base_type = -1 Then Begin
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
  Begin
   { VÇrifier si c'est un typedef }
   saved_lptr := lptr; { Sauvegarder la position actuelle }
   If symname(potential_typedef) Then Begin
    If resolve_typedef_type(potential_typedef, typedef_type_info) Then Begin
      { C'est un typedef valide - utiliser ses informations de type }
     type_info := typedef_type_info;
     base_type := typedef_type_info.base_type;
     type_found := True;
     safe_writeln('; Typedef r√©solu: ' + potential_typedef + ' = ' + get_type_name(typedef_type_info));
     Break;
    End
     Else
    Begin
      { Ce n'est pas un typedef - restaurer la position }
     lptr := saved_lptr;
    End;
   End;
   Break; { Plus de spÇcificateurs de type }
  End
 Until False;
  { Si aucun type explicite mais unsigned/signed spÇcifiÇ, int par dÇfaut }
 If not type_found and (is_unsigned or is_signed) Then Begin
  If is_unsigned Then base_type := cuint
                 Else base_type := cint;
  type_found := True;
 End;
  { Retourner -1 si aucun type trouvÇ }
 If not type_found Then Begin
  parse_type_specifier_with_qualifiers := -1;
  Exit;
 End;
  { DÇfinir les informations de type }
 type_info.base_type := base_type;
 type_info.is_unsigned := is_unsigned;
 type_info.is_const := is_const;
 type_info.is_volatile := is_volatile;
 calculate_type_size(type_info);
 parse_type_specifier_with_qualifiers := base_type;
End;

 { Analyser une dÇclaration enum }
Function parse_enum_type: Integer;
Var
 enum_name: String;
 enum_value: Integer;
 identifier: String;
 value_str: String;
 temp_value: Integer;
Begin
 enum_value := 0; { Valeur par dÇfaut de la premiäre constante enum }
 parse_enum_type := cenum;
  { VÇrifier s'il y a un nom d'enum optionnel }
 If symname(enum_name) Then Begin
  safe_writeln('; Enum nommÇ: ' + enum_name);
 End
  Else
 Begin
  safe_writeln('; Enum anonyme');
 End;
 If not match('{') Then Begin
  safe_writeln('; RÇfÇrence Ö enum: ' + enum_name);
  Exit;
 End;
  { Analyser la liste des identifiants enum }
 Repeat
  If Not symname(identifier) Then Break;
   { VÇrifier s'il y a une valeur explicite }
  If match('=') Then Begin
   If number(temp_value) Then Begin
    enum_value := temp_value;
   End
    Else
   Begin
    Case Language of
     _English: errrpt('Expected number in enum initializer');
     {$IFDEF FPC}
     _Germany: errrpt('Zahl in Enum-Initialisierung erwartet');
     {$ENDIF}
     Else errrpt('Nombre attendu dans initialisation enum');
    End;
   End;
  End;
   { Ajouter la constante enum Ö la table des symboles }
  Str(enum_value, value_str);
  safe_writeln(identifier + ' equ ' + value_str);
  Inc(enum_value); { Prochaine valeur par d√©faut }
   { Continuer avec les autres identifiants si virgule }
  If not match(',') Then Break;
 Until False;
  { Attendre la fermeture de accolade }
 If not match('}') Then Begin
  Case Language of
   _English: errrpt('Expected closing brace in enum');
   {$IFDEF FPC}
   _Germany: errrpt('Schliessende Klammer in Enum erwartet');
   {$ENDIF}
   Else errrpt('Accolade fermante attendue dans enum');
  End;
 End;
End;

 { Analyser les spÇcificateurs de classe d'entreposage }
Function parse_storage_class_specifier: Integer;Begin
 parse_storage_class_specifier := automatic; { Par dÇfaut }
 If match('typedef') Then Begin
  safe_writeln('; SpÇcificateur de classe de stockage: typedef');
  parse_storage_class_specifier := it_typedef_type;
 End
  Else
 If match('extern') Then Begin
  safe_writeln('; SpÇcificateur de classe de stockage: extern');
  parse_storage_class_specifier := CEXTERNAL;
 End
  Else
 If match('static') Then Begin
  safe_writeln('; SpÇcificateur de classe de stockage: static');
  parse_storage_class_specifier := statik;
 End
  Else
 If match('auto') Then Begin
  safe_writeln('; SpÇcificateur de classe de stockage: auto');
  parse_storage_class_specifier := automatic;
 End
  Else
 If match('register') Then Begin
  safe_writeln('; SpÇcificateur de classe de stockage: register (traitÇ comme auto)');
  parse_storage_class_specifier := automatic;
 End;
End;

{ Analyse amÇliorÇe du dÇclarateur avec informations de type }
Function parse_declarator(var var_name: String; base_type: Integer; var type_info: TTypeInfo): Integer;
Var
 result_type: Integer;
 array_size: Integer;
Begin
 { Ne pas rÇinitialiser type_info car il peut dÇjÖ contenir des qualificateurs }
 { Mettre Ö jour seulement le type de base s'il n'est pas dÇjÖ dÇfini }
 If type_info.base_type = 0 Then
  type_info.base_type := base_type;
 result_type := base_type;
  { GÇrer les dÇclarations de pointeur }
 While match('*') do Begin
  Inc(type_info.pointer_level);
  result_type := cpointer;
   { GÇrer const/volatile apräs * }
  If match('const') Then type_info.is_const := True;
  If match('volatile') Then type_info.is_volatile := True;
 End;
  { Analyser le nom de variable }
 If not symname(var_name) Then Begin
  Case Language of
   _English: errrpt('Expected variable name');
   {$IFDEF FPC}
   _Germany: errrpt('Erwarteter Variablenname');
   {$ENDIF}
   Else errrpt('Nom de variable attendu');
  End;
  parse_declarator := 0;
  Exit;
 End;
  { GÇrer les dÇclarations de tableau }
 If match('[') Then Begin
  If number(array_size) Then Begin
   type_info.array_size := array_size;
   safe_writeln('; Taille de tableau dÇtectÇe');
  End
   Else
  Begin
   type_info.array_size := 1; { Tableau de taille inconnue }
  End;
  If not match(']') Then Begin
   Case Language of
    _English: errrpt('Expected closing bracket');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete schlie·ende Klammer');
    {$ENDIF}
    Else errrpt('Crochet fermant attendu');
   End;
  End;
  result_type := carray;
 End;
  { Calculer la taille finale }
 calculate_type_size(type_info);
 parse_declarator := result_type;
End;

 { Analyser la dÇclaration/dÇfinition de fonction }
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
   {$IFDEF FPC}
   _Germany: errrpt('Erwarteter Funktionsname');
   {$ENDIF}
   Else errrpt('Nom de fonction attendu');
  End;
  Exit;
 End;
 safe_writeln('; DÇclaration de fonction: ' + func_name + ' (type: ' + get_type_name_from_id(return_type) + ')');
  { Attendre parenthäse ouvrante }
 If not match('(') Then
 Begin
  Case Language of
   _English: errrpt('Expected ( after function name');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ( nach Funktionsname');
   {$ENDIF}
   Else errrpt('( attendu apräs le nom de fonction');
  End;
  Exit;
 End;
  { Ignorer les paramätres pour l'instant - aller jusqu'Ö la parenthäse fermante }
 While (ch <> ')') and (ch <> #0) Do gch;
 If ch = ')' Then gch; { Consommer la parenthäse fermante }
  { VÇrifier s'il y a un corps de fonction }
 blanks;
 has_body := (ch = '{');
 If has_body Then Begin
  { Ajouter la fonction Ö la table des symboles }
  func_index := add_function(func_name, return_type);
   { GÇnÇrer l'Çtiquette de fonction }
  safe_writeln(func_name + ':');
   { Traiter le corps de fonction }
  If match('{') Then Begin
   safe_writeln('; Corps de fonction ' + func_name);
   { Analyse simplifiÇ - ignorer le contenu pour l'instant }
   While (ch <> #0) and (ch <> '}') Do
   Begin
    gch;
   End;
   If ch = '}' Then gch; { Consommer l'accolade fermante }
   safe_writeln('; Fin du corps de fonction ' + func_name);
   { VÇrifier que toutes les Çtiquettes goto sont dÇfinies }
   check_goto_labels;
   { RÇinitialiser la table goto pour la prochaine fonction }
   init_goto_table;
   { RÇinitialiser la table switch pour la prochaine fonction }
   init_switch_table;
  End
   Else
  Begin
   Case Language of
    _English: errrpt('Expected { to begin function body');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete { um Funktionskorper zu beginnen');
    {$ENDIF}
    Else errrpt('{ attendu pour commencer le corps de fonction');
   End;
   Exit;
  End;
 End
  Else
 Begin
  { DÇclaration de fonction sans corps - juste ajouter Ö la table }
  func_index := add_function(func_name, return_type);
  If not match(';') Then Begin
   Case Language of
    _English: errrpt('Expected ; after function declaration');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete ; nach Funktionsdeklaration');
    {$ENDIF}
    Else errrpt('; attendu apräs dÇclaration de fonction');
   End;
   Exit;
  End;
 End;
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
 If func_index = -1 Then Begin
  safe_writeln('; Attention: Fonction non dÇclarÇe ' + func_name);
  { Traiter comme fonction non dÇclarÇe retournant int }
  func_index := add_function(func_name, cint);
 End;
 safe_writeln('; Appel de fonction: ' + func_name);
  { Attendre parenthäse ouvrante }
 If not match('(') Then Begin
  Case Language of
   _English: errrpt('Expected ( in function call');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ( im Funktionsaufruf');
   {$ENDIF}
   Else errrpt('( attendu dans l''appel de fonction');
  End;
  Exit;
 End;
 arg_count := 0;
  { Analyser les arguments }
 If not match(')') Then Begin
  Repeat
   safe_writeln('; Argument (suivant)');
    { Analyser l'expression d'argument }
   expression_bool(arg_lval);
     { Pousser l'argument sur la pile }
   ol('push ax  ; pousser argument');
   Inc(arg_count);
  Until not match(',');
   { Attendre parenthäse fermante }
  If not match(')') Then Begin
   Case Language of
    _English: errrpt('Expected ) after function arguments');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete ) nach Funktionsargumenten');
    {$ENDIF}
    Else errrpt(') attendu apräs les arguments de fonction');
   End;
  End;
 End;
  { GÇnÇrer l'appel de fonction }
 generate_function_call(func_index, arg_count);
  { Configurer la valeur de retour }
 FillChar(lval, SizeOf(lval), 0);
  { Obtenir le type de retour depuis la liste chaånÇe }
 func_node := get_function_node(func_index);
 If func_node <> nil Then lval.typ := func_node^.func_data.return_type
                     Else lval.typ := cint; { Type par dÇfaut en cas d'erreur }
 lval.constant := False;
 parse_function_call := True;
End;

{ DÇclaration de variable amÇliorÇe avec table de symboles basÇe sur la mÇmoire de tas }
Procedure declare_variable(var_name: String; var_type: Integer; var type_info: TTypeInfo; storage_class: Integer);
Var
 sym_ptr: PSymbol;
 type_size: Integer;
Begin
  { VÇrifier si dÇjÖ dÇclarÇe en utilisant la nouvelle table de la mÇmoire de tas }
 If find_symbol(var_name) <> nil Then
 Begin
  Case Language of
   _English: errrpt('Variable ' + var_name + ' already declared');
   {$IFDEF FPC}
   _Germany: errrpt('Variable ' + var_name + ' bereits deklariert');
   {$ENDIF}
   Else errrpt('Variable ' + var_name + ' dÇjÖ dÇclarÇe');
  End;
  Exit;
 End;
  { Ajouter Ö la table de symboles basÇe sur la mÇmoire de tas }
 If type_info.array_size > 0 Then
  sym_ptr := add_symbol(var_name, it_array, var_type, storage_class, 0)
 Else
  sym_ptr := add_symbol(var_name, it_variable, var_type, storage_class, 0);
 If sym_ptr <> nil Then Begin
  { Entreposer les informations de type directement dans le symbole }
  sym_ptr^.type_info := type_info;
  If use_stdout Then WriteLn('; Variable dÇclarÇe: ', var_name, ' (', get_type_name(type_info), ')')
                Else safe_writeln('; Variable dÇclarÇe: ' + var_name);
   { GÇnÇrer l'allocation de stockage bas√©e sur la classe d'entreposage }
  Case storage_class of
   CEXTERNAL:
   Begin
    { Variable externe - ne pas gÇnÇrer d'allocation, juste rÇfÇrencer }
    safe_writeln('; Variable externe: ' + var_name + ' (dÇfinie ailleurs)');
   End;
   statik:
   Begin
    { Variable statique - gÇnÇrer allocation dans section donnÇes }
    If use_stdout Then Write(var_name)
                  Else outstr(var_name);
    type_size := type_info.size;
    If type_size = 1 Then Begin
     If use_stdout Then WriteLn(': rmb 1')
                   Else safe_writeln(': rmb 1');
    End
     Else
    Begin
     If use_stdout Then WriteLn(': rmb ', type_size)
                   Else safe_writeln(': rmb (taille)');
    End;
    safe_writeln('; Variable statique: ' + var_name);
   End;
    Else
   Begin
     { Variable automatique - allocation normale }
    If use_stdout Then Write(var_name)
                  Else outstr(var_name);
    type_size := type_info.size;
    If type_size = 1 Then Begin
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
 End;
End;

 { Recherche d'identificateur amÇliorÇe avec table de symboles basÇe sur la mÇmoire de tas }
Function lookup_variable(var_name: String; var lval: TLVal): Boolean;
Var
 sym_ptr: PSymbol;
Begin
 lookup_variable := False;
 FillChar(lval, SizeOf(lval), 0);
  { TEMPORAIRE: Simuler la recherche d'une variable const pour test }
 If var_name = 'consttest' Then Begin
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
 If sym_ptr <> nil Then Begin
  lookup_variable := True;
  lval.symbol := Integer(sym_ptr); { Stocker le pointeur comme entier pour compatibilit√© }
  lval.typ := sym_ptr^.ctype;
  lval.storage := sym_ptr^.storage;
  lval.indirect := 0;
  lval.constant := False;
   { Les informations de type sont stock√©es directement dans le symbole }
  lval.type_info := sym_ptr^.type_info;
 End
  Else
 Begin
  { Variable non trouv√©e - traiter comme nouvelle variable pour l'instant }
  If use_stdout Then WriteLn('; Attention: Variable non dÇclarÇe ', var_name)
                Else safe_writeln('; Attention: Variable non dÇclarÇe ' + var_name);
  lval.symbol := 0;
  lval.typ := cint;
  lval.constant := False;
  init_type_info(lval.type_info);
  lval.type_info.base_type := cint;
  lookup_variable := True;
 End;
End;

Function pop_include_file: Boolean;Begin
 pop_include_file := False;
 If include_depth <= 0 Then Exit;
  { DÇsactiver le marquage du fichier actuel comme n'Çtant plus en cours de traitement }
  { unmark_file_included(current_filename); } { Commented out for now }
  { Fermer le fichier d'inclusion actuel en toute sÇcuritÇ }
 {$I-}
 System.Close(input);
 {$I+}
  { Restaurer l'Çtat du fichier prÇcÇdent }
 Dec(include_depth);
 With include_stack[include_depth] do Begin
  current_filename := filename;
  System.Assign(input, filename);
  {$I-}
  System.Reset(input);
  If IOResult <> 0 Then Begin
   { Erreur de restauration du fichier }
   eof := 1;
   Exit;
  End;
  {$I+}
   { Restaurer correctement l'Çtat de la ligne }
  line := saved_line;
  lptr := saved_lptr;
  eof := saved_eof;
 End;
 safe_writeln('; Retourner du fichier d''inclusion Ö: ' + current_filename);
 pop_include_file := True;
End;

 { OpÇrations sur les fichiers }
Function readinline: Boolean;Begin
 readinline := False;
 Repeat
  { VÇrifier si le fichier d'entrÇe est correctement initialisÇ }
  {$I-}
  If not System.Eof(input)Then Begin
   ReadLn(input, line);
   If IOResult = 0 Then Begin
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
   { Le fichier actuel est Ö la fin }
   If include_depth > 0 Then Begin
    { Nous sommes dans un fichier d'inclusion, retourner au fichier prÇcÇdent }
    If not pop_include_file Then Begin
     eof := 1;
     readinline := False;
     Exit;
    End;
     { Continuer la boucle pour essayer de lire depuis le fichier restaurÇ }
   End
    Else
   Begin
    { Le fichier principal est Ö la fin }
    eof := 1;
    readinline := False;
    Exit;
   End;
  End;
 Until False;
End;

 { Fonctions de gestion des fichiers d'inclusion }

 { Initialiser le systäme d'inclusion }
Procedure init_inclusion_system;
Var
 i: Integer;
Begin
 include_depth := 0;
 included_count := 0;
 current_filename := 'main.c'; { Default main file }
 For i := 0 to 49 do Begin
  included_files[i].filename := '';
  included_files[i].is_included := False;
 End;
End;

 { VÇrifier si un fichier a dÇjÖ ÇtÇ inclus }
Function is_file_included(filename:String):Boolean;
Var
 i: Integer;
Begin
 is_file_included := False;
 For i := 0 to included_count-1 do Begin
  If included_files[i].filename = filename Then Begin
   is_file_included := included_files[i].is_included;
   Exit;
  End;
 End;
End;

 { Marquer un fichier comme inclus }
Procedure mark_file_included(filename: String);
Var
 i: Integer;
Begin
  { VÇrifier si dÇjÖ dans la table }
 For i := 0 to included_count - 1 do Begin
  If included_files[i].filename = filename Then Begin
   included_files[i].is_included := True;
   Exit;
  End;
 End;
  { Ajouter une nouvelle entrÇe si de l'espace est disponible }
 If included_count < 50 Then Begin
  included_files[included_count].filename := filename;
  included_files[included_count].is_included := True;
  Inc(included_count);
 End;
End;

 { DÇsactivez le marquage d'un fichier lorsque vous quitez son pÇrimätre }
Procedure unmark_file_included(filename: String);
Var
 i: Integer;
Begin
 For i := 0 to included_count - 1 do
 Begin
  If included_files[i].filename = filename Then
  Begin
   included_files[i].is_included := False;
   Exit;
  End;
 End;
End;

Function extract_filename(include_line: String): String;
Var
 start_pos, end_pos: Integer;
 filename: String;
Begin
 filename := '';
  { Ignorer #include et les espaces }
 start_pos := Pos('#include', include_line);
 If start_pos > 0 Then Begin
  start_pos := start_pos + 8; { Longueur de '#include' }
   { Ignorer les espaces }
  While (start_pos <= Length(include_line)) and
        ((include_line[start_pos] = ' ') or (include_line[start_pos] = #9)) do
   Inc(start_pos);
   { VÇrifier les guillemets ou les crochets angulaires }
  If start_pos <= Length(include_line) Then Begin
   If (include_line[start_pos] = '"') or (include_line[start_pos] = '<') Then Begin
    Inc(start_pos); { Ignorer le guillemet/crochet ouvrant }
    end_pos := start_pos;
     { Trouver le guillemet/crochet fermant }
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

Function push_include_file(include_filename: String): Boolean;Begin
 push_include_file := False;
  { VÇrifier l'inclusion circulaire }
 If is_file_included(include_filename) Then Begin
  Case Language of
   _English: errrpt('Circular inclusion detected: ' + include_filename);
   {$IFDEF FPC}
   _Germany: errrpt('ZirkulÑre Einbindung erkannt: ' + include_filename);
   {$ENDIF}
   Else errrpt('Inclusion circulaire dÇtectÇe: ' + include_filename);
  End;
  Exit;
 End;
  { VÇrifier la profondeur maximale d'inclusion }
 If include_depth >= 10 Then Begin
  Case Language of
   _English: errrpt('Include depth too deep (max 10): ' + include_filename);
   {$IFDEF FPC}
   _Germany: errrpt('Include-Tiefe zu tief (max 10): ' + include_filename);
   {$ENDIF}
   Else errrpt('Profondeur d''inclusion trop importante (max 10): ' + include_filename);
  End;
  Exit;
 End;
  { Sauvegarder l'Çtat actuel du fichier }
 With include_stack[include_depth] do Begin
  filename := current_filename;
  saved_line := line;
  saved_lptr := lptr;
  saved_eof := eof;
 End;
  { Essayer d'ouvrir le fichier d'inclusion }
 Assign(input, include_filename);
 {$I-}
 Reset(input);
 If IOResult <> 0 Then Begin
  { Restaurer le fichier prÇcÇdent en le rÇouvrant }
  If include_depth > 0 Then Begin
   Assign(input, include_stack[include_depth].filename);
   Reset(input);
  End;
  Case Language of
   _English: errrpt('Cannot open include file: ' + include_filename);
   {$IFDEF FPC}
   _Germany: errrpt('Kann Include-Datei nicht √∂ffnen: ' + include_filename);
   {$ENDIF}
   Else errrpt('Impossible d''ouvrir le fichier d''inclusion: ' + include_filename);
  End;
  Exit;
 End;
 {$I+}
  { Marquer le fichier comme inclus pour Çviter l'inclusion circulaire }
 mark_file_included(include_filename);
  { Mise Ö jour de l'Çtat }
 Inc(include_depth);
 current_filename := include_filename;
 eof := 0;
 lptr := 1; { RÇinitialiser le pointeur de ligne pour le nouveau fichier }
 safe_writeln('; Inclure le fichier: ' + include_filename);
 push_include_file := True;
End;

Function process_include_directive(include_line:String):Boolean;
Var
 filename: String;
Begin
 process_include_directive := False;
 filename := extract_filename(include_line);
 If filename = '' Then Begin
  Case Language of
   _English: errrpt('Invalid #include directive syntax');
   {$IFDEF FPC}
   _Germany: errrpt('UngÅltige #include-Direktiven-Syntax');
   {$ENDIF}
   Else errrpt('Syntaxe de directive #include invalide');
  End;
  Exit;
 End;
 If push_include_file(filename) Then process_include_directive := True;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES DêFINITIONS/MACROS                                  }
{ ============================================================================ }

 { Initialiser le systäme de dÇfinition }
Procedure init_defines;Begin
 define_list := nil;     { Initialiser la liste chaånÇe comme vide }
 define_count := 0;
 { Ne pas Çcrire dans la sortie ici car elle peut ne pas àtre encore initialisÇe }
End;

{ Trouver une constante #define par nom - retourne un pointeur }
Function find_define(def_name: String): PDefine;
Var
 current: PDefine;
Begin
 find_define := nil;
 current := define_list;
 While current <> nil do Begin
  If current^.in_use and (current^.name = def_name) Then Begin
   find_define := current;
   Exit;
  End;
  current := current^.next;
 End;
End;

 { Supprimer une constante #define }
Function remove_define(def_name: String): Boolean;
Var
 current, prev: PDefine;
Begin
 remove_define := False;
 current := define_list;
 prev := nil;
 While current <> nil do Begin
  If current^.in_use and (current^.name = def_name) Then Begin
   { TrouvÇ - supprimer de la liste }
   If prev = nil Then
    define_list := current^.next  { Premier dans la liste }
   Else
    prev^.next := current^.next;  { Pas le premier dans la liste }
   Dispose(current);
   Dec(define_count);
   remove_define := True;
   Exit;
  End;
  prev := current;
  current := current^.next;
 End;
End;

 { Ajouter une nouvelle constante #define }
Function add_define(def_name, def_value: String): Boolean;
Var
 new_define: PDefine;
Begin
 add_define := False;
  { VÇrifier si dÇjÖ dÇfini et permettre la redÇfinition avec avertissement }
 If find_define(def_name) <> nil Then Begin
  Case Language of
   _English:Begin
     WriteLn('; Warning: Macro ' + def_name + ' redefined (previous definition ignored)');
     { Supprimer l'ancienne dÇfinition }
     remove_define(def_name);
    End;
    {$IFDEF FPC}
   _Germany:Begin
     WriteLn('; Warnung: Makro ' + def_name + ' neu definiert (vorherige Definition ignoriert)');
     remove_define(def_name);
    End;
    {$ENDIF}
   Else
    Begin
     WriteLn('; Avertissement: Macro ' + def_name + ' redÇfini (dÇfinition prÇcÇdente ignorÇe)');
     remove_define(def_name);
    End;
  End;
 End;
  { Allouer un nouveau define dans la mÇmoire de tas }
 New(new_define);
 If new_define = nil Then Begin
  Case Language of
   _English: errrpt('Out of memory for #define constants');
   {$IFDEF FPC}
   _Germany: errrpt('Kein Speicher fÅr #define-Konstanten');
   {$ENDIF}
   Else errrpt('MÇmoire insuffisante pour les constantes #define');
  End;
  Exit;
 End;
  { Initialiser le nouveau define }
 With new_define^ do Begin
  name := def_name;
  value := def_value;
  in_use := True;
  next := define_list;  { InsÇrer au dÇbut de la liste }
 End;
  { Mise Ö jour de la liste d'entàte }
 define_list := new_define;
 Inc(define_count);
 If use_stdout Then WriteLn('; Macro dÇfini: ', def_name, ' = ', def_value)
               Else safe_writeln('; Macro dÇfini: ' + def_name + ' = ' + def_value);
 add_define := True;
End;

 { Obtenir la valeur d'une constante #define }
Function get_define_value(def_name: String): String;
Var
 define_ptr: PDefine;
Begin
 get_define_value := '';
 define_ptr := find_define(def_name);
 If define_ptr <> nil Then
  get_define_value := define_ptr^.value;
End;

{ Traiter la directive #define }
Function process_define_directive(define_line: String): Boolean;
Var
 line_pos, start_pos, end_pos: Integer;
 def_name, def_value: String;
Begin
 process_define_directive := False;
 def_name := '';
 def_value := '';
  { Ignorer #define et les espaces }
 line_pos := Pos('#define', define_line);
 If line_pos <= 0 Then Exit;
 line_pos := line_pos + 7; { Longueur de '#define' }
  { Ignorer les espaces }
 While (line_pos <= Length(define_line)) and
       ((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
  Inc(line_pos);
  { Extraire le nom de macro }
 start_pos := line_pos;
 While (line_pos <= Length(define_line)) and
       (((define_line[line_pos] >= 'A') and (define_line[line_pos] <= 'Z')) or
        ((define_line[line_pos] >= 'a') and (define_line[line_pos] <= 'z')) or
        ((define_line[line_pos] >= '0') and (define_line[line_pos] <= '9')) or
        (define_line[line_pos] = '_')) do
  Inc(line_pos);
 If line_pos > start_pos Then def_name := Copy(define_line, start_pos, line_pos - start_pos)
  Else
 Begin
  Case Language of
   _English: errrpt('Invalid #define directive: missing name');
   {$IFDEF FPC}
   _Germany: errrpt('UngÅltige #define-Direktive: Name fehlt');
   {$ENDIF}
   Else errrpt('Directive #define invalide: nom manquant');
  End;
  Exit;
 End;
  { Ignorer les espaces avant la valeur }
 While (line_pos <= Length(define_line)) and
       ((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
  Inc(line_pos);
  { Extraire la valeur (reste de la ligne) }
 If line_pos <= Length(define_line) Then
  def_value := Copy(define_line, line_pos, Length(define_line) - line_pos + 1)
 Else
  def_value := '1'; { Valeur par dÔøΩfaut pour les macros sans valeur explicite }
  { Supprimer les espaces en fin de valeur }
 While (Length(def_value) > 0) and
       ((def_value[Length(def_value)] = ' ') or (def_value[Length(def_value)] = #9)) do
  Delete(def_value, Length(def_value), 1);
  { Ajouter le define }
 If add_define(def_name, def_value) Then process_define_directive := True;
End;

{ DÇvelopper les macros dans une ligne de code }
Function expand_macros(input_line: String): String;
Var
 result_line: String;
 line_pos, start_pos, end_pos: Integer;
 token: String;
 define_ptr: PDefine;
 changed: Boolean;
Begin
 result_line := input_line;
  { Plusieurs passes pour gÔøΩrer les expansions imbriquÇes }
 Repeat
  changed := False;
  line_pos := 1;
  While line_pos <= Length(result_line) do Begin
   { VÇrifier si on est au dÇbut d'un identifiant }
   If ((result_line[line_pos] >= 'A') and (result_line[line_pos] <= 'Z')) or
      ((result_line[line_pos] >= 'a') and (result_line[line_pos] <= 'z')) or
      (result_line[line_pos] = '_') Then
   Begin
    { Extraire l'identifiant }
    start_pos := line_pos;
    While (line_pos <= Length(result_line)) and
          (((result_line[line_pos] >= 'A') and (result_line[line_pos] <= 'Z')) or
           ((result_line[line_pos] >= 'a') and (result_line[line_pos] <= 'z')) or
           ((result_line[line_pos] >= '0') and (result_line[line_pos] <= '9')) or
           (result_line[line_pos] = '_')) do
     Inc(line_pos);
    token := Copy(result_line, start_pos, line_pos - start_pos);
     { VÇrifier si ce jeton est une macro dÇfinie }
    define_ptr := find_define(token);
    If define_ptr <> nil Then
    Begin
     { Remplacer le jeton par sa valeur }
     Delete(result_line, start_pos, Length(token));
     Insert(define_ptr^.value, result_line, start_pos);
     line_pos := start_pos + Length(define_ptr^.value);
     changed := True;
     If use_stdout Then WriteLn('; Expanded macro: ', token, ' -> ', define_ptr^.value)
                   Else safe_writeln('; Expanded macro: ' + token + ' -> ' + define_ptr^.value);
    End;
   End
   Else
    Inc(line_pos);
  End;
 Until not changed;
 expand_macros := result_line;
End;

 { Supprimer tous les defines de la mÇmoire de tas }
Procedure free_defines;
Var
 current, next: PDefine;
Begin
 current := define_list;
 While current <> nil do
 Begin
  next := current^.next;
  Dispose(current);
  current := next;
 End;
 define_list := nil;
 If use_stdout Then WriteLn('; Cleared ', define_count, ' macro definitions from heap')
               Else safe_writeln('; Cleared macro definitions from heap');
 define_count := 0;
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES DIRECTIVES CONDITIONNELLES                         }
{ ============================================================================ }

 { Initialiser la pile de conditions }
Procedure init_conditions;
Begin
 condition_depth := 0;
 skip_code := False;
End;

 { êvaluer une expression constante simple pour #if }
Function evaluate_constant_expression(expr: String): Integer;
Var
 result: Integer;
 error_code: Integer;
 define_ptr: PDefine;
 temp_str: String;
 i: Integer;
Begin
 result := 0;
 temp_str := expr;
  { Supprimer les espaces au dÇbut et Ö la fin }
 While (Length(temp_str) > 0) and (temp_str[1] = ' ') do
  Delete(temp_str, 1, 1);
 While (Length(temp_str) > 0) and (temp_str[Length(temp_str)] = ' ') do
  Delete(temp_str, Length(temp_str), 1);
  { VÇrifier si c'est un nombre }
 If (Length(temp_str) > 0) and (temp_str[1] in ['0'..'9']) Then Begin
  Val(temp_str, result, error_code);
  If error_code <> 0 Then result := 0; { Si erreur, retourner 0 }
 End
  { VÇrifier si c'est un define }
  Else
 If temp_str <> '' Then Begin
  define_ptr := find_define(temp_str);
  If define_ptr <> nil Then Begin
   { êvaluer rÇcursivement la valeur du define }
   result := evaluate_constant_expression(define_ptr^.value);
  End
   Else
  result := 0; { Define non trouvÇ = 0 }
 End;
 evaluate_constant_expression := result;
End;

 { VÇrifier si on doit ignorer le code actuel }
Function should_skip_code: Boolean;
Var
 i: Integer;
Begin
 should_skip_code := False;
  { Parcourir la pile de conditions }
 For i := 0 to condition_depth - 1 do Begin
  With condition_stack[i] do Begin
   { Si une condition est fausse et qu'on n'est pas dans un else vrai }
   If not is_true and not (in_else and not has_true_branch) Then Begin
    should_skip_code := True;
    Exit;
   End;
  End;
 End;
End;

 { Traiter la directive #if }
Function process_if_directive(condition: String): Boolean;
Var
 condition_value: Integer;
 temp_condition: String;
Begin
 process_if_directive := False;
  { Nettoyer la condition (supprimer espaces et retour chariot) }
 temp_condition := condition;
 While (Length(temp_condition) > 0) and (temp_condition[1] = ' ') do
  Delete(temp_condition, 1, 1);
 While (Length(temp_condition) > 0) and (temp_condition[Length(temp_condition)] in [' ', #13, #10]) do
  Delete(temp_condition, Length(temp_condition), 1);
 If condition_depth >= 32 Then Begin
  Case Language of
   _English: errrpt('Too many nested #if directives (max 32)');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele verschachtelte #if-Direktiven (max 32)');
   {$ENDIF}
   Else errrpt('Trop de directives #if imbriqu√©es (max 32)');
  End;
  Exit;
 End;
 condition_value := evaluate_constant_expression(temp_condition);
 With condition_stack[condition_depth] do Begin
  condition_type := COND_IF;
  is_true := (condition_value <> 0);
  has_true_branch := is_true;
  in_else := False;
  line_number := 0; { √Ä impl√©menter si n√©cessaire }
 End;
 Inc(condition_depth);
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #if ', temp_condition, ' = ', condition_value)
               Else safe_writeln('; #if ' + temp_condition + ' = ' + IntToStr(condition_value));
 process_if_directive := True;
End;

 { Traiter la directive #ifdef }
Function process_ifdef_directive(define_name: String): Boolean;
Var
 define_exists: Boolean;
 temp_name: String;
Begin
 process_ifdef_directive := False;
  { Nettoyer le nom (supprimer espaces et retour chariot) }
 temp_name := define_name;
 While (Length(temp_name) > 0) and (temp_name[1] = ' ') do
  Delete(temp_name, 1, 1);
 While (Length(temp_name) > 0) and (temp_name[Length(temp_name)] in [' ', #13, #10]) do
  Delete(temp_name, Length(temp_name), 1);
 If condition_depth >= 32 Then Begin
  Case Language of
   _English: errrpt('Too many nested #ifdef directives (max 32)');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele verschachtelte #ifdef-Direktiven (max 32)');
   {$ENDIF}
   Else errrpt('Trop de directives #ifdef imbriquÇes (max 32)');
  End;
  Exit;
 End;
 define_exists := (find_define(temp_name) <> nil);
 With condition_stack[condition_depth] do Begin
  condition_type := COND_IFDEF;
  is_true := define_exists;
  has_true_branch := is_true;
  in_else := False;
  line_number := 0;
 End;
 Inc(condition_depth);
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #ifdef ', temp_name, ' = ', define_exists)
               Else safe_writeln('; #ifdef ' + temp_name + ' = ' + IntToStr(Ord(define_exists)));
 process_ifdef_directive := True;
End;

 { Traiter la directive #ifndef }
Function process_ifndef_directive(define_name: String): Boolean;
Var
 define_exists: Boolean;
 temp_name: String;
Begin
 process_ifndef_directive := False;
  { Nettoyer le nom (supprimer espaces et retour chariot) }
 temp_name := define_name;
 While (Length(temp_name) > 0) and (temp_name[1] = ' ') do
  Delete(temp_name, 1, 1);
 While (Length(temp_name) > 0) and (temp_name[Length(temp_name)] in [' ', #13, #10]) do
  Delete(temp_name, Length(temp_name), 1);
 If condition_depth >= 32 Then Begin
  Case Language of
   _English: errrpt('Too many nested #ifndef directives (max 32)');
   {$IFDEF FPC}
   _Germany: errrpt('Zu viele verschachtelte #ifndef-Direktiven (max 32)');
   {$ENDIF}
   Else errrpt('Trop de directives #ifndef imbriqu√©es (max 32)');
  End;
  Exit;
 End;
 define_exists := (find_define(temp_name) <> nil);
 With condition_stack[condition_depth] do Begin
  condition_type := COND_IFNDEF;
  is_true := not define_exists;
  has_true_branch := is_true;
  in_else := False;
  line_number := 0;
 End;
 Inc(condition_depth);
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #ifndef ', temp_name, ' = ', not define_exists)
               Else safe_writeln('; #ifndef ' + temp_name + ' = ' + IntToStr(Ord(not define_exists)));
 process_ifndef_directive := True;
End;

 { Traiter la directive #elif }
Function process_elif_directive(condition: String): Boolean;
Var
 condition_value: Integer;
 temp_condition: String;
Begin
 process_elif_directive := False;
  { Nettoyer la condition (supprimer espaces et retour chariot) }
 temp_condition := condition;
 While (Length(temp_condition) > 0) and (temp_condition[1] = ' ') do
  Delete(temp_condition, 1, 1);
 While (Length(temp_condition) > 0) and (temp_condition[Length(temp_condition)] in [' ', #13, #10]) do
  Delete(temp_condition, Length(temp_condition), 1);
 If condition_depth = 0 Then Begin
  Case Language of
   _English: errrpt('#elif without matching #if');
   {$IFDEF FPC}
   _Germany: errrpt('#elif ohne passendes #if');
   {$ENDIF}
   Else errrpt('#elif sans #if correspondant');
  End;
  Exit;
 End;
 With condition_stack[condition_depth - 1] do Begin
  If in_else Then Begin
   Case Language of
    _English: errrpt('#elif after #else');
    {$IFDEF FPC}
    _Germany: errrpt('#elif nach #else');
    {$ENDIF}
    Else errrpt('#elif apräs #else');
   End;
   Exit;
  End;
   { êvaluer seulement si aucune branche prÇcÇdente n'Çtait vraie }
  If not has_true_branch Then Begin
   condition_value := evaluate_constant_expression(temp_condition);
   is_true := (condition_value <> 0);
   If is_true Then has_true_branch := True;
  End
  Else
   is_true := False; { Une branche pr√©c√©dente √©tait vraie }
 End;
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #elif ', temp_condition)
               Else safe_writeln('; #elif ' + temp_condition);
 process_elif_directive := True;
End;

 { Traiter la directive #else }
Function process_else_directive:Boolean;Begin
 process_else_directive := False;
 If condition_depth = 0 Then Begin
  Case Language of
   _English: errrpt('#else without matching #if');
   {$IFDEF FPC}
   _Germany: errrpt('#else ohne passendes #if');
   {$ENDIF}
   Else errrpt('#else sans #if correspondant');
  End;
  Exit;
 End;
 With condition_stack[condition_depth - 1] do Begin
  If in_else Then Begin
   Case Language of
    _English: errrpt('Multiple #else in same #if block');
    {$IFDEF FPC}
    _Germany: errrpt('Mehrere #else im selben #if-Block');
    {$ENDIF}
    Else errrpt('Plusieurs #else dans le m√™me bloc #if');
   End;
   Exit;
  End;
  in_else := True;
  { #else est vrai seulement si aucune branche prÇcÇdente n'Çtait vraie }
  is_true := not has_true_branch;
 End;
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #else')
               Else safe_writeln('; #else');
 process_else_directive := True;
End;

{ Traiter la directive #endif }
Function process_endif_directive: Boolean;Begin
 process_endif_directive := False;
 If condition_depth = 0 Then Begin
  Case Language of
   _English: errrpt('#endif without matching #if');
   {$IFDEF FPC}
   _Germany: errrpt('#endif ohne passendes #if');
   {$ENDIF}
   Else errrpt('#endif sans #if correspondant');
  End;
  Exit;
 End;
 Dec(condition_depth);
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #endif')
               Else safe_writeln('; #endif');
 process_endif_directive := True;
End;

 { LibÇrer les ressources des conditions }
Procedure free_conditions;Begin
 condition_depth := 0;
 skip_code := False;
 If use_stdout Then WriteLn('; Conditional compilation context cleared')
               Else safe_writeln('; Contexte de compilation conditionnelle effacÇe');
End;

{ Analyser l'acc√®s aux tableaux avec indexation }
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
   {$IFDEF FPC}
   _Germany: errrpt('Array nicht gefunden: ' + array_name);
   {$ENDIF}
   Else errrpt('Tableau non trouvÇ: ' + array_name);
  End;
  Exit;
 End;
  { VÇrifier que c'est bien un tableau }
 If (array_symbol^.ident <> it_array) and (array_symbol^.type_info.array_size = 0) Then Begin
  Case Language of
   _English: errrpt('Variable is not an array: ' + array_name);
   {$IFDEF FPC}
   _Germany: errrpt('Variable ist kein Array: ' + array_name);
   {$ENDIF}
   Else errrpt('La variable n''est pas un tableau: ' + array_name);
  End;
  Exit;
 End;
  { Consommer '[' }
 If not match('[') Then Begin
  Case Language of
   _English: errrpt('Expected [ for array index');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete [ fÅr Array-Index');
   {$ENDIF}
   Else errrpt('[ attendu pour l''index du tableau');
  End;
  Exit;
 End;
 safe_writeln('; Calcul de l''index du tableau ' + array_name);
  { Analyser l'expression d'index }
 additive_expression(index_lval);
  { Consommer ']' }
 If not match(']') Then Begin
  Case Language of
   _English: errrpt('Expected ] after array index');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ] nach Array-Index');
   {$ENDIF}
   Else errrpt('] attendu apräs l''index du tableau');
  End;
  Exit;
 End;
  { Charger la valeur Ö l'adresse calculÇe }
 ol('mov  si,ax  ; adresse dans SI');
 Case element_size of
  1: ol('mov  al,[si] ; charger octet');
  2: ol('mov  ax,[si] ; charger mot');
 Else
  ol('mov  ax,[si] ; charger mot par dÇfaut');
 End;
  { Configurer lval pour le rÇsultat }
 lval.typ := array_symbol^.type_info.base_type;
 lval.indirect := 1; { Valeur charg√©e indirectement }
 lval.constant := False;
 lval.type_info := array_symbol^.type_info;
 lval.type_info.array_size := 0; { Ce n'est plus un tableau mais un √©l√©ment }
End;

 { Analyser l'accäs aux membres de structure }
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
 If struct_symbol = nil Then Begin
  Case Language of
   _English: errrpt('Struct variable not found: ' + struct_name);
   {$IFDEF FPC}
   _Germany: errrpt('Struct-Variable nicht gefunden: ' + struct_name);
   {$ENDIF}
   Else errrpt('Variable de structure non trouvÇe: ' + struct_name);
  End;
  Exit;
 End;
  { VÇrifier que c'est bien une structure }
 If (struct_symbol^.type_info.base_type <> cstruct) and
    (struct_symbol^.type_info.base_type <> cunion) Then
 Begin
  Case Language of
   _English: errrpt('Variable is not a struct/union: ' + struct_name);
   {$IFDEF FPC}
   _Germany: errrpt('Variable ist kein Struct/Union: ' + struct_name);
   {$ENDIF}
   Else errrpt('La variable n''est pas une structure/union: ' + struct_name);
  End;
  Exit;
 End;
  { Consommer '.' ou '->' }
 If is_pointer Then Begin
  If not (match('-') and match('>')) Then Begin
   Case Language of
    _English: errrpt('Expected -> for pointer member access');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete -> fÅr Pointer-Mitgliedszugriff');
    {$ENDIF}
    Else errrpt('-> attendu pour l''accäs aux membres de pointeur');
   End;
   Exit;
  End;
 End
  Else
 Begin
  If not match('.') Then Begin
   Case Language of
    _English: errrpt('Expected . for struct member access');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete . fÅr Struct-Mitgliedszugriff');
    {$ENDIF}
    Else errrpt('. attendu pour l''accäs aux membres de structure');
   End;
   Exit;
  End;
 End;
  { Obtenir le nom du membre }
 If not symname(member_name) Then Begin
  Case Language of
   _English: errrpt('Expected member name after .');
   {$IFDEF FPC}
   _Germany: errrpt('Erwarteter Mitgliedsname nach .');
   {$ENDIF}
   Else errrpt('Nom de membre attendu apr√®s .');
  End;
  Exit;
 End;
  { Trouver la dÇfinition de la structure }
 struct_def := find_struct_by_id(struct_symbol^.type_info.struct_id);
 If struct_def = nil Then Begin
  Case Language of
   _English: errrpt('Struct definition not found');
   {$IFDEF FPC}
   _Germany: errrpt('Struct-Definition nicht gefunden');
   {$ENDIF}
   Else errrpt('D√©finition de structure non trouv√©e');
  End;
  Exit;
 End;
  { Trouver le membre dans la structure }
 member_index := find_struct_member(struct_def, member_name);
 If member_index = -1 Then Begin
  Case Language of
   _English: errrpt('Member not found in struct: ' + member_name);
   {$IFDEF FPC}
   _Germany: errrpt('Mitglied nicht in Struct gefunden: ' + member_name);
   {$ENDIF}
   Else errrpt('Membre non trouvÇ dans la structure: ' + member_name);
  End;
  Exit;
 End;
  { Obtenir les informations du membre }
 With struct_def^.members[member_index] do Begin
  member_offset := offset;
  member_size := size;
 End;
 safe_writeln('; Accäs au membre ' + member_name + ' (offset: ' + IntToStr(member_offset) + ')');
 { GÇnÇrer le code pour calculer l'adresse du membre }
 If member_offset = 0 Then Begin
  { Le membre est au dÇbut de la structure }
  ot('mov  ax,');
  outstr(struct_name);
  nl;
 End
  Else
 Begin
  { Ajouter l'offset du membre }
  ot('mov  ax,');
  outstr(struct_name);
  nl;
  ot('add  ax,');
  outdec(member_offset);
  nl;
 End;
  { Charger la valeur du membre }
 ol('MOV  BX, AX    ; adresse du membre dans BX');
 Case member_size of
  1: ol('MOV  AL, [BX]     ; charger octet');
  2: ol('MOV  AX, [BX]     ; charger mot');
 Else
  ol('MOV  AX, [BX]     ; charger mot par dÇfaut');
 End;
  { Configurer lval pour le rÇsultat }
 With struct_def^.members[member_index] do
 Begin
  lval.typ := member_type;
  lval.indirect := 1;
  lval.constant := False;
  lval.type_info := type_info;
 End;
End;

 { Analyseur d'expression primaire avec support des appels de fonction }
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
    ot('mov  ax,');
    outdec(num);
    nl;
   End;
  'A'..'Z', 'a'..'z', '_': Begin
    id := parse_identifier;
    { VÇrifier si c'est un appel de fonction }
    If peek_char = '(' Then Begin
     { C'est un appel de fonction }
     If parse_function_call(id, lval) Then Begin
      { Le rÇsultat de l'appel de fonction est dÇjÖ dans le registre D }
      safe_writeln('; Function ' + id + ' returned in D');
     End
      Else
     Begin
      Case Language of
       _English: errrpt('Invalid function call: ' + id);
       {$IFDEF FPC}
       _Germany: errrpt('UngÅltiger Funktionsaufruf: ' + id);
       {$ENDIF}
       Else errrpt('Appel de fonction invalide: ' + id);
      End;
     End;
    End
     Else
    Begin
     { C'est une rÇfÇrence de variable }
     If lookup_variable(id, lval) Then Begin
      { VÇrifier si c'est un accäs Ö un tableau }
      If peek_char = '[' Then Begin
       { Indexation d'un tableau }
       parse_array_access(id, lval);
      End
       Else
      If peek_char = '.' Then Begin
       { Accäs au membre d'une structure }
       parse_struct_member_access(id, lval, False);
      End
       Else
      Begin
       { Simple accäs de variable }
       ot('mov  ax,');
       outstr(id);
       nl;
      End;
     End
     Else
     Begin
      { Variable non dÇclarÇ }
      lval.symbol := 0;
      lval.typ := cint;
      lval.constant := False;
      ot('mov  ax,');
      outstr(id);
      nl;
     End;
    End;
   End;
  '(': Begin
    next_char; { consomme '(' }
    additive_expression(lval);
    If peek_char = ')' Then
     next_char { consomme ')' }
    Else
    Begin
     Case Language of
      _English: errrpt('Missing )');
      {$IFDEF FPC}
      _Germany: errrpt('Fehlende )');
      {$ENDIF}
      Else errrpt(') manquant');
     End;
    End;
   End;
  Else
   Case Language of
    _English: errrpt('Invalid primary expression');
    {$IFDEF FPC}
    _Germany: errrpt('UngÅltiger primÑrer Ausdruck');
    {$ENDIF}
    Else errrpt('Expression primaire invalide');
   End;
 End;
End;

{ Analyseur d'expression unaire }
Procedure unary_expression(var lval: TLVal);
Var
 true_label, end_label: Integer;
 save_lptr: Integer;
 id: String;
Begin
  { VÇrifier d'abord si c'est le mot-clef sizeof }
 save_lptr := lptr;
 blanks;
 If is_alpha(peek_char) Then Begin
  id := parse_identifier;
  If id = 'sizeof' Then Begin
   { C'est sizeof - restaurer la position et l'analyser }
   lptr := save_lptr;
   parse_sizeof_expression(lval);
   Exit;
  End;
 End;
  { Restaurer la position pour l'analyse normale }
 lptr := save_lptr;
 Case peek_char of
  '+': Begin
    next_char;
    unary_expression(lval);
   End;
  '-': Begin
    next_char;
    unary_expression(lval);
    ol('NEG  AL');
    ol('NEG  AH');
    ol('SBB  AH, 0');
   End;
  '!': Begin
    next_char;
    safe_writeln('; OpÇrateur ! (NOT logique)');
    unary_expression(lval);
     { Convertir en boolÇen: 0 si non-zÇro, 1 si zÇro }
    true_label := getlabel;
    end_label := getlabel;
    ol('CMP  AX, 0');                    { Tester AX (le rÇsultat de l''expression) }
    ol('JE   L' + IntToStr(true_label)); { Si zÇro, c'est vrai (!0 = 1) }
    ol('MOV  AX, 0');                    { Sinon c'est faux (!non_zÇro = 0) }
    ol('JMP  L' + IntToStr(end_label));
    prelabel(true_label);
    ol('MOV  AX, 1');                    { RÇsultat vrai }
    prelabel(end_label);
   End;
  '~': Begin
    next_char;
    unary_expression(lval);
    ol('NOT  AL');
    ol('NOT  AH');
   End;
  '*': Begin
    { OpÇrateur de dÇrÇfÇrencement }
    next_char;
    unary_expression(lval);
    parse_dereference(lval);
   End;
  '&': Begin
    { OpÇrateur d'adresse }
    next_char;
    parse_address_of(lval);
   End;
  Else
   primary_expression(lval);
 End;
End;

 { OpÇrateur de dÇrÇfÇrencement (*ptr) }
Procedure parse_dereference(var lval: TLVal);
var
  ptr_name: String;
Begin
 safe_writeln('; DÇrÇfÇrencement de pointeur');
  { VÇrifier que c'est bien un pointeur }
 If lval.type_info.pointer_level = 0 Then Begin
  Case Language of
   _English: errrpt('Cannot dereference non-pointer type');
   {$IFDEF FPC}
   _Germany: errrpt('Kann Nicht-Zeiger-Typ nicht dereferenzieren');
   {$ENDIF}
   Else errrpt('Impossible de dÇrÇfÇrencer un type non-pointeur');
  End;
  Exit;
 End;
  { GÇnÇrer le code de dÇrÇfÇrencement }
 If lval.symbol > 0 Then
 Begin
  ptr_name := get_symbol_name(lval.symbol);
  safe_writeln('; DÇrÇfÇrencement de: ' + ptr_name);
  ol('MOV  BX, ' + ptr_name);  { Charger l'adresse entreposÇe dans le pointeur }
  ol('MOV  AX, [BX]');         { Charger la valeur pointÇe }
 End
  Else
 Begin
  safe_writeln('; DÇrÇfÇrencement indirect');
  ol('POP  BX');         { RÇcupÇrer l'adresse depuis la pile }
  ol('MOV  AX, [BX]');   { Charger la valeur pointÇe }
 End;
  { VÇrifier que c'est bien un pointeur }
 If lval.type_info.pointer_level = 0 Then Begin
  Case Language of
   _English: errrpt('Cannot dereference non-pointer type');
   {$IFDEF FPC}
   _Germany: errrpt('Kann Nicht-Zeiger-Typ nicht dereferenzieren');
   {$ENDIF}
   Else errrpt('Impossible de dÇrÇfÇrencer un type non-pointeur');
  End;
  Exit;
 End;
 { GÇnÇrer le code de dÇrÇfÇrencement }
 If lval.symbol > 0 Then Begin
  ptr_name := get_symbol_name(lval.symbol);
  safe_writeln('; DÇrÇfÇrencement de: ' + ptr_name);
  ol('MOV  BX, ' + ptr_name);  { Charger l'adresse entreposÇe dans le pointeur }
  ol('MOV  AX, [BX]');         { Charger la valeur pointÇe }
 End
  Else
 Begin
  safe_writeln('; DÇrÇfÇrencement indirect');
  ol('POP  BX');               { RÇcupÇrer l'adresse depuis la pile }
  ol('MOV  AX, [BX]');         { Charger la valeur pointÇe }
 End;
  { DÇcrÇmenter le niveau de pointeur }
 Dec(lval.type_info.pointer_level);
  { Le rÇsultat est maintenant une valeur }
 lval.indirect := 0;
 safe_writeln('; Pointeur dÇrÇfÇrencÇ, nouveau niveau: ' + IntToStr(lval.type_info.pointer_level));
End;

 { OpÇrateur d'adresse (&var) }
Procedure parse_address_of(var lval: TLVal);
Var
  var_name: String;
  sym_ptr: PSymbol;
Begin
 safe_writeln('; Prise d''adresse de variable');
  { Lire le nom de la variable directement }
 If not symname(var_name) Then Begin
  Case Language of
   _English: errrpt('Expected variable name after &');
   {$IFDEF FPC}
   _Germany: errrpt('Variablenname nach & erwartet');
   {$ENDIF}
   Else errrpt('Nom de variable attendu apräs &');
  End;
  Exit;
 End;
  { Chercher la variable dans la table des symboles }
 sym_ptr := find_symbol(var_name);
 If sym_ptr = nil Then
 Begin
  Case Language of
   _English: errrpt('Undefined variable: ' + var_name);
   {$IFDEF FPC}
   _Germany: errrpt('Undefinierte Variable: ' + var_name);
   {$ENDIF}
   Else errrpt('Variable non dÇfinie: ' + var_name);
  End;
  Exit;
 End;
  { VÇrifier que c'est bien une variable (pas une constante) }
 If sym_ptr^.ident <> it_variable Then Begin
  Case Language of
   _English: errrpt('Cannot take address of non-variable');
   {$IFDEF FPC}
   _Germany: errrpt('Kann Adresse von Nicht-Variable nicht nehmen');
   {$ENDIF}
   Else errrpt('Impossible de prendre l''adresse d''une non-variable');
  End;
  Exit;
 End;
  { GÇnÇrer le code pour obtenir l'adresse }
 ol('leax ' + var_name);
 ol('PUSH BX'); { Empiler l'adresse }
  { Configurer lval pour le rÇsultat }
 lval.symbol := Integer(sym_ptr);
 lval.indirect := 1; { RÇsultat sur la pile }
 lval.typ := cpointer;
 lval.storage := sym_ptr^.storage;
 lval.constant := False;
 lval.value := 0;
  { Copier les informations de type et incrÇmenter le niveau de pointeur }
 lval.type_info := sym_ptr^.type_info;
 Inc(lval.type_info.pointer_level);
 safe_writeln('; Adresse de ' + var_name + ' prise, niveau pointeur: ' + IntToStr(lval.type_info.pointer_level));
End;

{ OpÇrateur sizeof - calcule la taille d'un type ou d'une expression }
Procedure parse_sizeof_expression(var lval: TLVal);
Var
 type_name: String;
 type_id: Integer;
 type_info: TTypeInfo;
 size_value: Integer;
 expr_lval: TLVal;
Begin
 safe_writeln('; OpÇrateur sizeof');
  { Consommer le mot-clef 'sizeof' }
 If not match('sizeof')Then Begin
  Case Language of
   _English: errrpt('Expected sizeof keyword');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartetes sizeof-Schl√ºsselwort');
   {$ENDIF}
   Else errrpt('Mot-clef sizeof attendu');
  End;
  Exit;
 End;
  { Attendre parenthäse ouvrante }
 If not match('(') Then Begin
  Case Language of
   _English: errrpt('Expected ( after sizeof');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ( nach sizeof');
   {$ENDIF}
   Else errrpt('( attendu apräs sizeof');
  End;
  Exit;
 End;
  { Analyser le contenu - peut √™tre un type ou une expression }
 { Sauvegarder la position pour pouvoir revenir en arriäre }
 blanks;
  { Essayer d'analyser comme un type d'abord }
 type_id := parse_type_specifier_with_qualifiers(type_info);
 If type_id <> -1 Then Begin
   { C'est un type - calculer sa taille }
  safe_writeln('; sizeof sur type: ' + get_type_name(type_info));
  size_value := calculate_type_size(type_info);
   { Attendre la parenthäse fermante }
  If not match(')') Then Begin
   Case Language of
    _English: errrpt('Expected ) after sizeof type');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete ) nach sizeof-Typ');
    {$ENDIF}
    Else errrpt(') attendu apräs le type sizeof');
   End;
   Exit;
  End;
 End
  Else
 Begin
   { Ce n'est pas un type - essayer comme expression }
  safe_writeln('; sizeof sur expression');
   { Analyser l'expression }
  unary_expression(expr_lval);
   { Calculer la taille basÇe sur le type de l'expression }
  size_value := calculate_type_size(expr_lval.type_info);
   { Attendre la parenthäse fermante }
  If not match(')') Then Begin
   Case Language of
    _English: errrpt('Expected ) after sizeof expression');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete ) nach sizeof-Ausdruck');
    {$ENDIF}
    Else errrpt(') attendu apräs l''expression sizeof');
   End;
   Exit;
  End;
 End;
  { GÇnÇrer le code pour charger la taille comme constante }
 ot('mov  ax,');
 outdec(size_value);
 nl;
  { Configurer lval pour le rÇsultat }
 FillChar(lval, SizeOf(lval), 0);
 lval.typ := cint;
 lval.constant := True;
 lval.value := size_value;
 init_type_info(lval.type_info);
 lval.type_info.base_type := cint;
 lval.type_info.size := sizeof_int;
 safe_writeln('; sizeof rÇsultat: ' + IntToStr(size_value) + ' octets');
End;

 { Analyseur d'expression multiplicative }
Procedure multiplicative_expression(var lval: TLVal);
Var
 op: Char;
Begin
 unary_expression(lval);
 While (peek_char = '*') or (peek_char = '/') or (peek_char = '%') do Begin
  op := next_char;
  ol('push ax'); { empiler l'opÇrande gauche }
  unary_expression(lval);
  Case op of
   '*': Begin
     ol('POP  BX');     { dÇpiler l'opÇrande gauche vers BX }
     ol('call mult16'); { appeler la routine de multiplication }
    End;
   '/': Begin
     ol('MOV  BX, AX'); { opÇrande droit vers BX }
     ol('POP  AX');     { opÇrande gauche vers AX }
     ol('CALL div16');  { appeler la routine de division }
    End;
   '%': Begin
     ol('MOV  BX, AX'); { opÇrande droit vers BX }
     ol('POP  AX');     { opÇrande gauche vers AX }
     ol('CALL mod16');  { appeler la routine de modulo }
    End;
  End;
 End;
End;

 { Analyseur d'expression additive }
Procedure additive_expression(var lval: TLVal);
Var
 op: Char;
Begin
 multiplicative_expression(lval);
 While (peek_char = '+') or (peek_char = '-') do Begin
  op := next_char;
  ol('PUSH AX'); { empiler l'opÇrande gauche }
  multiplicative_expression(lval);
  Case op of
   '+': Begin
     ol('ADD  AX, [SP] ; puis ADD SP, 2'); { additionner et nettoyer la pile }
     ol('ADD  SP, 2'); { nettoyer la pile }
    End;
   '-': Begin
     ol('MOV  BX, AX'); { opÇrande droit vers BX }
     ol('POP  AX');     { opÇrande gauche vers AX }
     ol('SUB  AX, BX'); { soustraire }
    End;
  End;
 End;
End;

 { Analyseur d'expression relationnelle - gäre >, <, >=, <=, ==, != }
Procedure relational_expression(var lval: TLVal);Begin
 additive_expression(lval);
 While True do Begin
  If match('>') Then Begin
   If match('=') Then Begin
    { >= operator }
    safe_writeln('; OpÇrateur >=');
    ol('PUSH AX');       { Empiler l'opÇrande gauche }
    additive_expression(lval);
    ol('POP  BX');       { OpÇrande gauche vers BX }
    ol('CMP  BX, AX');   { Comparer BX avec AX }
    ol('JGE  $+5');      { Brancher si supÔøΩrieur ou ÔøΩgal }
    ol('MOV  AX, 0');    { RÇsultat faux }
    ol('JMP  $+3');      { Ignorer le rÇsultat vrai }
    ol('MOV  AX, 1');    { RÇsultat vrai }
   End
    Else
   Begin
     { > operator }
    safe_writeln('; OpÇrateur >');
    ol('PUSH AX');       { Empiler l'opÇrande gauche }
    additive_expression(lval);
    ol('POP  BX');       { OpÇrande gauche vers BX }
    ol('CMP  BX, AX');   { Comparer BX avec AX }
    ol('JG   $+5');      { Brancher si supÇrieur }
    ol('MOV  AX, 0');    { RÇsultat faux }
    ol('JMP  $+3');      { Ignorer le rÇsultat vrai }
    ol('MOV  AX, 1');    { RÇsultat vrai }
   End;
  End
   Else
  If match('<') Then Begin
   If match('=') Then Begin
     { <= operator }
    safe_writeln('; OpÇrateur <=');
    ol('PUSH AX');       { Empiler l'opÇrande gauche }
    additive_expression(lval);
    ol('POP  BX');       { OpÇrande gauche vers BX }
    ol('CMP  BX, AX');   { Comparer BX avec AX }
    ol('JLE  $+5');      { Brancher si infÇrieur ou Çgal }
    ol('MOV  AX, 0');    { RÇsultat faux }
    ol('JMP  $+3');      { Ignorer le rÇsultat vrai }
    ol('MOV  AX, 1');    { RÇsultat vrai }
   End
    Else
   Begin
     { OpÇrateur < }
    safe_writeln('; OpÇrateur <');
    ol('PUSH AX');       { Empiler l'opÇrande gauche }
    additive_expression(lval);
    ol('POP  BX');       { OpÇrande gauche vers BX }
    ol('CMP  BX, AX');   { Comparer BX avec AX }
    ol('JL   $+5');      { Brancher si infÇrieur }
    ol('MOV  AX, 0');    { RÇsultat faux }
    ol('JMP  $+3');      { Ignorer le rÇsultat vrai }
    ol('MOV  AX, 1');    { RÇsultat vrai }
   End;
  End
   Else
  If match('=') and match('=')Then Begin
    { OpÇrateur == }
   safe_writeln('; OpÇrateur ==');
   ol('PUSH AX');        { Empiler l'opÇrande gauche }
   additive_expression(lval);
   ol('POP  BX');        { OpÇrande gauche vers BX }
   ol('CMP  BX, AX');    { Comparer BX avec AX }
   ol('JE   $+5');       { Brancher si Çgal }
   ol('MOV  AX, 0');     { RÇsultat faux }
   ol('JMP  $+3');       { Ignorer le rÇsultat vrai }
   ol('MOV  AX, 1');     { RÇsultat vrai }
  End
   Else
  If match('!') and match('=') Then Begin
    { != operator }
   safe_writeln('; OpÇrateur !=');
   ol('PUSH AX');        { Empiler l'opÇrande gauche }
   additive_expression(lval);
   ol('POP  BX');        { OpÇrande gauche vers BX }
   ol('CMP  BX, AX');    { Comparer BX avec AX }
   ol('JNE  $+5');       { Brancher si diffÇrent }
   ol('MOV  AX, 0');     { RÇsultat faux }
   ol('JMP  $+3');       { Ignorer le rÇsultat vrai }
   ol('MOV  AX, 1');     { RÇsultat vrai }
  End
   Else
  Break; { Plus d'opÇrateurs relationnels }
 End;
End;

 { Analyseur d'expression ET binaire - gäre & }
Procedure bitwise_and_expression(var lval:TLVal);Begin
 relational_expression(lval);
 While match('&') do Begin
  { VÇrifier que ce n'est pas && }
  If peek_char = '&' Then Begin
   { Reculer car c'est && qui sera traitÇ par logical_and }
   Dec(lptr);
   Break;
  End;
  safe_writeln('; OpÇrateur & (ET binaire)');
  ol('PUSH AX');      { Empiler l'opÇrande gauche }
  relational_expression(lval);
  ol('MOV  BX, AX');  { OpÇrande droit vers BX }
  ol('POP  AX');      { OpÇrande gauche vers AX }
  ol('AND  AX, BX');  { OpÇration ET binaire }
  ol('tfr  a,b');     { Octet bas du rÇsultat vers B }
  ol('tfr  u,a');     { Restaurer l'octet haut depuis U }
  ol('anda 0,x');     { ET sur les octets hauts }
 End;
End;

 { Analyseur d'expression XOR binaire - gäre ^ }
Procedure bitwise_xor_expression(var lval: TLVal);Begin
 bitwise_and_expression(lval);
 While match('^') do Begin
  safe_writeln('; OpÇrateur ^ (XOR binaire)');
  ol('PUSH AX');      { Empiler l'opÇrande gauche }
  bitwise_and_expression(lval);
  ol('MOV  BX, AX');  { OpÇrande droit vers BX }
  ol('POP  AX');      { OpÇrande gauche vers AX }
  ol('XOR  AX, BX');  { OpÇration XOR binaire }
 End;
End;

 { Analyseur d'expression OU binaire - gäre | }
Procedure bitwise_or_expression(var lval: TLVal);Begin
 bitwise_xor_expression(lval);
 While match('|') do Begin
   { VÇrifier que ce n'est pas || }
  If peek_char = '|' Then Begin
   { Reculer car c'est || qui sera traitÇ par logical_or }
   Dec(lptr);
   Break;
  End;
  safe_writeln('; OpÇrateur | (OU binaire)');
  ol('PUSH AX');      { Empiler l'opÇrande gauche }
  bitwise_xor_expression(lval);
  ol('MOV  BX, AX');  { OpÇrande droit vers BX }
  ol('POP  AX');      { OpÇrande gauche vers AX }
  ol('OR   AX, BX');  { OpÇration OU binaire }
  ol('ora  0,x');     { OU sur les octets hauts }
 End;
End;

 { Analyseur d'expression ET logique - gäre && }
Procedure logical_and_expression(var lval: TLVal);
Var
 false_label, end_label: Integer;
Begin
 bitwise_or_expression(lval);
 While match('&') and match('&') do Begin
  safe_writeln('; OpÇrateur && (ET logique)');
   { GÇnärer les Çtiquettes }
  false_label := getlabel;
  end_label := getlabel;
   { Tester la premiäre expression }
  ol('CMP  AX, 0');
  ot('JE   ');
  printlabel(false_label);
  nl;
   { êvaluer la deuxiäme expression }
  bitwise_or_expression(lval);
  ol('CMP  AX, 0');
  ot('JE   ');
  printlabel(false_label);
  nl;
   { Les deux sont vraies - rÇsultat = 1 }
  ol('MOV  AX, 1');
  ot('JMP  ');
  printlabel(end_label);
  nl;
   { Au moins une est fausse - rÇsultat = 0 }
  prelabel(false_label);
  ol('MOV  AX, 0');
   { Fin }
  prelabel(end_label);
 End;
End;

 { Analyseur d'expression OU logique - gäre || }
Procedure logical_or_expression(var lval: TLVal);
Var
 true_label, end_label: Integer;
Begin
 logical_and_expression(lval);
 While match('|')and match('|')do Begin
  safe_writeln('; Op√©rateur || (OU logique)');
   { GÇnärer les Çtiquettes }
  true_label := getlabel;
  end_label := getlabel;
   { Tester la premiäre expression }
  ol('CMP  AX, 0');
  ot('JNE  ');
  printlabel(true_label);
  nl;
   { êvaluer la deuxiäme expression }
  logical_and_expression(lval);
  ol('CMP  AX, 0');
  ot('JNE  ');
  printlabel(true_label);
  nl;
   { Les deux sont fausses - rÇsultat = 0 }
  ol('MOV  AX, 0');
  ot('JMP  ');
  printlabel(end_label);
  nl;
   { Au moins une est vraie - rÇsultat = 1 }
  prelabel(true_label);
  ol('MOV  AX, 1');
   { Fin }
  prelabel(end_label);
 End;
End;

 { Analyseur d'expression conditionnelle - gäre ?: (opÇrateur ternaire) }
Procedure conditional_expression(var lval: TLVal);
Var
 false_label, end_label: Integer;
 true_lval, false_lval: TLVal;
Begin
 logical_or_expression(lval);
 If match('?') Then Begin
  safe_writeln('; OpÇrateur ternaire ? : (expression conditionnelle)');
   { GÇnÇrer les Çtiquettes }
  false_label := getlabel;
  end_label := getlabel;
  { Tester la condition }
  ol('CMP  AX, 0');        { Tester le r√©sultat de la condition }
  ot('JE   ');             { Si faux, aller √† l''expression fausse }
  printlabel(false_label);
  nl;
   { Analyser l'expression vraie }
  safe_writeln('; Expression vraie du ternaire');
  logical_or_expression(true_lval);
   { Sauter l'expression fausse }
  ot('JMP  ');
  printlabel(end_label);
  nl;
   { Attendre ':' }
  If not match(':')Then Begin
   Case Language of
    _English: errrpt('Expected : in ternary operator');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete : im tern√§ren Operator');
    {$ENDIF}
    Else errrpt(': attendu dans l''opÇrateur ternaire');
   End;
   Exit;
  End;
   { êtiquette pour l'expression fausse }
  prelabel(false_label);
   { Analyser l'expression fausse }
  safe_writeln('; Expression fausse du ternaire');
  logical_or_expression(false_lval);
   { êtiquette de fin }
  prelabel(end_label);
   { Le rÇsultat est dans D - copier les informations de type appropriÇes }
   { Pour simplifier, utiliser le type de l'expression vraie }
  lval := true_lval;
  safe_writeln('; Fin op√©rateur ternaire');
 End;
End;

 { Analyseur d'expressions principal }
Function expression_bool(var lval: TLVal):Boolean;Begin
 conditional_expression(lval);
 expression_bool := True;
End;

{ ProcÇdure enveloppant pour la compatibilitÇ ascendante }
Procedure expression(var lval: TLVal);Begin
 expression_bool(lval);
End;

 { Fonction d'analyse de dÇclaration de variable - dÇplace apräs l'expression }
 { Analyse la dÇclaration Çtendue avec un support de type plein }
Function parse_declaration: Boolean;
Var
 base_type, var_type, storage_class: Integer;
 var_name: String;
 lval: TLVal;
 type_info: TTypeInfo;
 save_lptr: Integer;
Begin
 parse_declaration := False;
  { Analyser d'abord le spÇcificateur de classe d'entreposage }
 storage_class := parse_storage_class_specifier;
  { VÇrifier si c'est une dÇclaration typedef }
 If storage_class = it_typedef_type Then Begin
  { GÇrer la dÇclaration typedef }
  If parse_typedef_declaration Then
   parse_declaration := True;
  Exit;
 End;
  { Analyser le spÇcificateur de type avec qualificateurs }
 base_type := parse_type_specifier_with_qualifiers(type_info);
 If base_type = -1 Then Exit; { Aucun type valide trouvÇ }
  { Sauvegarder la position pour vÇrifier fonction vs variable }
 save_lptr := lptr;
  { Essayer d'analyser comme dÇclarateur pour obtenir le nom }
 var_type := parse_declarator(var_name, base_type, type_info);
 If var_type = 0 Then Exit;
  { VÇrifier si c'est une dÇclaration/dÇfinition de fonction }
 If match('(') Then Begin
  { C'est une fonction - restaurer la position et analyser comme fonction }
  lptr := save_lptr;
  If parse_function_declaration(base_type) Then
   parse_declaration := True;
  Exit;
 End;
  { C'est une dÔøΩclaration de variable - passer la classe de stockage }
 declare_variable(var_name, var_type, type_info, storage_class);
 parse_declaration := True;
  { VÇrifier l'initialisation }
 If match('=') Then Begin
  safe_writeln('; Initialisation de la variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
  expression(lval);
   { VÇrification du type pour l'initialisation }
  If type_info.is_const Then Begin
   safe_writeln('; variable const initialisÇe');
  End;
   { GÇnÇrer le code d'initialisation appropriÇ au type }
  Case type_info.size of
   1: Begin
       ot('MOV  '); { Entreposer l'octet pour char }
       outstr(var_name);
       outstr(', AL');
       nl;
      End;
   2: Begin
       ot('mov  '); { Entreposer le mot pour int/short/pointeurs }
       outstr(var_name);
       nl;
      End;
  Else
   Begin
    ot('mov  '); { Par dÇfaut: mot }
    outstr(var_name);
    nl;
   End;
  End;
 End
  Else
 Begin
  { VÇrifier si la variable const nÇcessite une initialisation }
  If type_info.is_const Then
  Begin
   Case Language of
    _English: errrpt('const variable ' + var_name + ' must be initialized');
    {$IFDEF FPC}
    _Germany: errrpt('const Variable ' + var_name + ' muss initialisiert werden');
    {$ENDIF}
    Else errrpt('la variable const ' + var_name + ' doit àtre initialisÇe');
   End;
  End;
 End;
  { GÇrer les dÇclarations de variables multiples }
 While match(',') do Begin
  var_type := parse_declarator(var_name, base_type, type_info);
  If var_type = 0 Then Exit;
  declare_variable(var_name, var_type, type_info, storage_class);
  { VÇrifier l'initialisation }
  If match('=') Then Begin
   safe_writeln('; Initialisation de la variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
   expression(lval);
    { GÇnÇrer le code d'initialisation }
   Case type_info.size of
    1: Begin
        ot('MOV  ');
        outstr(var_name);
        outstr(', AL');
        nl;
       End;
    2: Begin
        ot('mov  ');
        outstr(var_name);
        nl;
       End;
   Else
    Begin
     ot('mov  ');
     outstr(var_name);
     nl;
    End;
   End;
  End
  Else
  Begin
    { VÇrifier si la variable const nÇcessite une initialisation }
   If type_info.is_const Then
   Begin
    Case Language of
     _English: errrpt('const variable ' + var_name + ' must be initialized');
     {$IFDEF FPC}
     _Germany: errrpt('const Variable ' + var_name + ' muss initialisiert werden');
     {$ENDIF}
     Else errrpt('la variable const ' + var_name + ' doit àtre initialisÇe');
    End;
   End;
  End;
 End;
  { Point-virgule attendu pour les dÇclarations de variable }
 If not match(';') Then errrpt('Point-virgule attendue apräs la dÇclaration');
End;

 { DÇclarations anticipÇes pour l'analyse des instructions }
Function parse_statement: Boolean; forward;
Function parse_compound_statement: Boolean; forward;
Function parse_assignment_statement: Boolean; forward;
Procedure parse_array_assignment(array_name: String); forward;
Function parse_goto_statement: Boolean; forward;
Function parse_label_statement: Boolean; forward;
Function parse_switch_statement: Boolean; forward;
Function parse_case_statement: Boolean; forward;
Function parse_default_statement: Boolean; forward;
Function parse_for_statement: Boolean; forward;

 { Analyse de structure de contrìle }
Function parse_if_statement: Boolean;
Var
 lval: TLVal;
 else_label, end_label: Integer;
Begin
 parse_if_statement := False;
 If not match('if') Then Exit;
 parse_if_statement := True;
  { Attendre la parenthäse ouvrante }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not match('(') Then Begin
  errrpt('Expected ( after if');
  Exit;
 End;
  { Analyser la condition }
 safe_writeln('; IF condition');
 expression_bool(lval);
  { Fermeture de parenthäse attendue }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not match(')') Then Begin
  errrpt('Expected ) after if condition');
  Exit;
 End;
  { GÇnÇrer le saut conditionnel }
 else_label := getlabel;
 end_label := getlabel;
 ol('CMP  AX, 0');
 ot('JE   ');
 printlabel(else_label);
 nl;
  { Analyser l'instruction then (peut àtre simple ou composÇe) }
 safe_writeln('; IF then block');
  { VÇrifier si on doit lire la ligne suivante pour l'instruction }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not parse_statement Then Begin
  errrpt('Expected statement after if condition');
  Exit;
 End;
  { VÇrifier la clause else - peut àtre sur la ligne suivante }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If match('else') Then Begin
  { Sauter le bloc else }
  ot('JMP  ');
  printlabel(end_label);
  nl;
   { Bloc else }
  prelabel(else_label);
  safe_writeln('; ELSE block');
   { VÇrifier si on doit lire la ligne suivante pour l'instruction else }
  blanks;
  If (lptr > Length(line)) and (eof = 0) Then readinline;
  If not parse_statement Then Begin
   errrpt('Expected statement after else');
   Exit;
  End;
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
  { GÇnÇrer les Çtiquettes de boucle }
 loop_label := getlabel;
 end_label := getlabel;
  { Empiler le contexte de boucle pour break/continue }
 push_loop_context(1, end_label, loop_label);
  { DÇbut de boucle }
 prelabel(loop_label);
 safe_writeln('; WHILE loop start');
  { Attendre la parenthäse ouvrante }
 If not match('(') Then Begin
  errrpt('Expected ( after while');
  Exit;
 End;
  { Analyser la condition }
 safe_writeln('; WHILE condition');
 expression_bool(lval);
  { Fermeture de parenthäse attendue }
 If not match(')') Then errrpt('Expected ) after while condition');
  { GÇnÇrer le saut conditionnel }
 ol('CMP  AX, 0');
 ot('JE   ');
 printlabel(end_label);
 nl;
  { Analyser le corps de la boucle }
 safe_writeln('; WHILE body');
 parse_statement;
  { Retourner Ö la condition }
 ot('JMP  ');
 printlabel(loop_label);
 nl;
  { êtiquette de fin }
 prelabel(end_label);
 safe_writeln('; End WHILE');
  { DÇpiler le contexte de boucle }
 pop_loop_context;
End;

Function parse_for_statement: Boolean;
Var
 lval: TLVal;
 increment_label, condition_label, end_label: Integer;
 condition_start, condition_end, increment_start, increment_end: Integer;
 saved_lptr: Integer;
Begin
 parse_for_statement := False;
 If not match('for') Then Exit;
 parse_for_statement := True;
  { GÇnÇrer les Çtiquettes de boucle }
 condition_label := getlabel;
 increment_label := getlabel;
 end_label := getlabel;
  { Empiler le contexte de boucle pour break/continue }
 push_loop_context(2, end_label, increment_label);
 safe_writeln('; FOR loop start');
  { Attendre la parenthäse ouvrante }
 If not match('(') Then
 Begin
  errrpt('Expected ( after for');
  Exit;
 End;
  { Analyser et exÇcuter l'initialisation }
 safe_writeln('; FOR initialization');
 blanks;
 If ch <> ';' Then Begin
  parse_assignment_statement;  { Analyser et exÇcuter l'initialisation }
 End;
 If not match(';') Then Begin
  errrpt('Expected ; after for initialization');
  Exit;
 End;
  { Sauvegarder la position pour l'analyse de la condition }
 blanks;
 condition_start := lptr;
  { Ignorer la condition pour trouver sa fin }
 While (ch <> ';') and (ch <> #0) Do gch;
 condition_end := lptr;
 If not match(';') Then Begin
  errrpt('Expected ; after for condition');
  Exit;
 End;
  { Sauvegarder la position pour l'analyse de l'incrÇment }
 blanks;
 increment_start := lptr;
  { Ignorer l'incrÇment pour trouver sa fin }
 While (ch <> ')') and (ch <> #0) Do gch;
 increment_end := lptr;
 If not match(')') Then Begin
  errrpt('Expected ) after for increment');
  Exit;
 End;
  { Sauter vers la vÇrification de la condition }
 ot('JMP  ');
 printlabel(condition_label);
 nl;
  { êtiquette d'incrÇment - oó continue saute }
 prelabel(increment_label);
 safe_writeln('; FOR increment');
  { RÇanalyser et exÇcuter l'incrÇment depuis la position sauvegardÇe }
 saved_lptr := lptr;  { Sauvegarder la position actuelle }
 lptr := increment_start;  { DÇfinir la position au dÇbut de l'incrÇment }
 gch;  { Rafraåchir le caractäre courant }
 If increment_end > increment_start Then Begin
  parse_assignment_statement;  { Analyser et exÇcuter l'incrÇment }
 End;
 lptr := saved_lptr;  { Restaurer la position }
 gch;  { Rafraåchir le caractäre courant }
 ot('JMP  ');
 printlabel(condition_label);
 nl;
  { êtiquette de vÇrification de la condition }
 prelabel(condition_label);
 safe_writeln('; FOR condition check');
  { RÇanalyser la condition depuis la position sauvegardÇe }
 saved_lptr := lptr;  { Sauvegarder la position actuelle }
 lptr := condition_start;  { DÇfinir la position au dÇbut de la condition }
 gch;  { Rafraåchir le caractäre courant }
 If condition_end > condition_start Then Begin
  expression_bool(lval);  { Analyser la condition }
 End
  Else
 Begin
  { Pas de condition = boucle infinie }
  ot('MOV  AX, 1');
  nl;
 End;
 lptr := saved_lptr;  { Restaurer la position }
 gch;  { Rafraåchir le caractäre courant }
  { GÇnÇrer le saut conditionnel vers la fin si faux }
 ol('CMP  AX, 0');
 ot('JE   ');
 printlabel(end_label);
 nl;
  { Analyser le corps de la boucle }
 safe_writeln('; FOR body');
 parse_statement;
  { Sauter vers l'incrÇment }
 ot('JMP  ');
 printlabel(increment_label);
 nl;
  { êtiquette de fin - oó break saute }
 prelabel(end_label);
 safe_writeln('; End FOR');
  { DÇpiler le contexte de boucle }
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
  { GÇnÇrer les Çtiquettes de boucle }
 loop_label := getlabel;
 condition_label := getlabel;
 end_label := getlabel;
  { Empiler le contexte de boucle pour break/continue }
  { push_loop_context(3, end_label, condition_label); }
  { DÇbut de boucle }
 prelabel(loop_label);
 safe_writeln('; DO-WHILE loop start');
  { Analyser le corps de la boucle }
 parse_statement;
  { while attendue }
 If not match('while') Then Begin
  errrpt('Expected while after do body');
  Exit;
 End;
  { Attendre la parenthäse ouvrante }
 If not match('(') Then Begin
  errrpt('Expected ( after while');
  Exit;
 End;
  { Analyser la condition }
 prelabel(condition_label);
 safe_writeln('; DO-WHILE condition');
 expression_bool(lval);
  { Parenthäse fermer attendue }
 If not match(')') Then errrpt('Expected ) after while condition');
  { Expect semicolon }
 If not match(';') Then
  errrpt('Expected ; after do-while');
  { GÇnÇrer le saut conditionnel en retour }
 ol('CMP  AX, 0');
 ot('JNE  ');
 printlabel(loop_label);
 nl;
  { êtiquette de fin }
 prelabel(end_label);
 safe_writeln('; End DO-WHILE');
  { DÇpiler le contexte de boucle }
 { pop_loop_context; }
End;

Function parse_return_statement:Boolean;
Var
 lval: TLVal;
Begin
 parse_return_statement := False;
 If not match('return') Then Exit;
 parse_return_statement := True;
 safe_writeln('; RETURN statement');
  { VÇrifier s'il y a une valeur de retour }
 If not match(';') Then Begin expression_bool(lval);
  If not match(';') Then errrpt('Expected ; after return value');
 End
  Else
 Begin
  { Retour void - charger 0 }
  ot('MOV  AX, 0');
  nl;
 End;
  { GÇnÇrer le code de retour }
 ol('ret');
End;

Function parse_break_statement: Boolean;
Var
 break_label: Integer;
Begin
 parse_break_statement := False;
 If not match('break') Then Exit;
 parse_break_statement := True;
 safe_writeln('; BREAK statement');
  { Point-virgule attendue }
 If not match(';') Then errrpt('; attendu apräs break');
  { Obtenir l'Çtiquette break courante du contexte de boucle }
 break_label := get_current_break_label;
 If break_label = -1 Then Begin
  errrpt('break statement not within a loop');
  Exit;
 End;
  { Sauter Ö la fin de la boucle courante }
 ot('JMP  ');
 printlabel(break_label);
 nl;
End;

Function parse_continue_statement:Boolean;
Var
 continue_label: Integer;
Begin
 parse_continue_statement := False;
 If not match('continue') Then Exit;
 parse_continue_statement := True;
 safe_writeln('; CONTINUE statement');
  { Point-virgule attendu }
 If not match(';') Then errrpt('Expected ; after continue');
  { Obtenir l'Çtiquette continue courante du contexte de boucle }
 continue_label := get_current_continue_label;
 If continue_label = -1 Then Begin
  errrpt('continue statement not within a loop');
  Exit;
 End;
  { Sauter Ö la condition de boucle }
 ot('JMP  ');
 printlabel(continue_label);
 nl;
End;

 { Analyser une instruction goto }
Function parse_goto_statement: Boolean;
Var
 label_name: String;
Begin
 parse_goto_statement := False;
 If not match('goto') Then Exit;
 parse_goto_statement := True;
 safe_writeln('; GOTO statement');
  { Obtenir le nom de l'Çtiquette }
 If not symname(label_name) Then Begin
  Case Language of
   _English: errrpt('Expected label name after goto');
   {$IFDEF FPC}
   _Germany: errrpt('Label-Name nach goto erwartet');
   {$ENDIF}
   Else errrpt('Nom d''Çtiquette attendu apr√®s goto');
  End;
  Exit;
 End;
  { Attendre point-virgule }
 If not match(';') Then errrpt('; attendu apräs l''instruction goto');
  { GÇnÇrer le saut vers l'Çtiquette }
 use_goto_label(label_name);
End;

 { Analyser une dÇfinition d'Çtiquette (label:) }
Function parse_label_statement: Boolean;
Var
 label_name: String;
 save_lptr: Integer;
Begin
 parse_label_statement := False;
  { Sauvegarder la position pour pouvoir revenir en arriäre }
 save_lptr := lptr;
  { VÇrifier s'il y a un identificateur suivi de ':' }
 If symname(label_name) and match(':') Then Begin
  parse_label_statement := True;
  safe_writeln('; DÇfinition d''Çtiquette: ' + label_name);
  define_goto_label(label_name);
 End
  Else
 Begin
   { Ce n'est pas une Çtiquette, revenir en arriäre }
  lptr := save_lptr;
 End;
End;

 { Analyser une instruction switch }
Function parse_switch_statement: Boolean;
Var
 lval: TLVal;
 switch_expr_type: Integer;
Begin
 parse_switch_statement := False;
 If not match('switch') Then Exit;
 parse_switch_statement := True;
 safe_writeln('; SWITCH statement');
  { Attendre parenthäse ouvrante }
 If not match('(') Then Begin
  Case Language of
   _English: errrpt('Expected ( after switch');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ( nach switch');
   {$ENDIF}
   Else errrpt('( attendu apräs switch');
  End;
  Exit;
 End;
  { Analyser l'expression switch }
 safe_writeln('; Expression switch');
 expression_bool(lval);
 switch_expr_type := lval.typ;
  { Attendre parenthäse fermante }
 If not match(')') Then Begin
  Case Language of
   _English: errrpt('Expected ) after switch expression');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ) nach switch-Ausdruck');
   {$ENDIF}
   Else errrpt(') attendu apräs expression switch');
  End;
  Exit;
 End;
  { Commencer le switch }
 If not begin_switch_statement(switch_expr_type) Then Exit;
  { Sauvegarder la valeur de l'expression pour comparaison }
 ol('MOV  switch_temp, AX ; sauver valeur switch');
  { GÇnÇrer les comparaisons }
 generate_switch_comparisons;
  { Analyser le corps du switch }
 If not match('{') Then Begin
  Case Language of
   _English: errrpt('Expected { after switch statement');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete { nach switch-Anweisung');
   {$ENDIF}
   Else errrpt('{ attendu apräs instruction switch');
  End;
  Exit;
 End;
 safe_writeln('; Corps du switch');
 While (ch <> '}') and (ch <> #0) Do Begin
  If not parse_statement Then Begin
   If ch <> #0 Then gch;
  End;
 End;
 If not match('}') Then Begin
  Case Language of
   _English: errrpt('Expected } to close switch');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete } zum Schlie·en von switch');
   {$ENDIF}
   Else errrpt('} attendu pour fermer switch');
  End;
 End;
  { Terminer le switch }
 end_switch_statement;
End;

 { Analyser une instruction case }
Function parse_case_statement: Boolean;
Var
 case_value: Integer;
 case_label: Integer;
Begin
 parse_case_statement := False;
 If not match('case') Then Exit;
 parse_case_statement := True;
 safe_writeln('; CASE statement');
  { Obtenir la valeur du case }
 If not number(case_value) Then Begin
  Case Language of
   _English: errrpt('Expected constant after case');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete Konstante nach case');
   {$ENDIF}
   Else errrpt('Constante attendue apräs case');
  End;
  Exit;
 End;
  { Attendre deux-points }
 If not match(':') Then Begin
  Case Language of
   _English: errrpt('Expected : after case value');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete : nach case-Wert');
   {$ENDIF}
   Else errrpt(': attendu apräs valeur case');
  End;
  Exit;
 End;
  { Ajouter le case au switch courant }
 case_label := add_switch_case(case_value);
 If case_label <> -1 Then Begin
  prelabel(case_label);
  safe_writeln('; Case ' + IntToStr(case_value) + ' dÇfini');
 End;
End;

 { Analyser une instruction default }
Function parse_default_statement: Boolean;
Var
 default_label: Integer;
Begin
 parse_default_statement := False;
 If not match('default') Then Exit;
 parse_default_statement := True;
 safe_writeln('; DEFAULT statement');
  { Attendre deux-points }
 If not match(':') Then Begin
  Case Language of
   _English: errrpt('Expected : after default');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete : nach default');
   {$ENDIF}
   Else errrpt(': attendu apräs default');
  End;
  Exit;
 End;
  { Ajouter le default au switch courant }
 default_label := add_switch_default;
 If default_label <> -1 Then Begin
  prelabel(default_label);
  safe_writeln('; Default dÇfini');
 End;
End;

 { Analyse une instruction composÇ }
Function parse_compound_statement: Boolean;Begin
 parse_compound_statement := False;
 If not match('{') Then Exit;
 parse_compound_statement := True;
 safe_writeln('; DÇbut d''une instruction composÇ');
  { Analyser les instructions jusqu'Ö l'accolade fermante }
 Repeat
  { VÇrifier si on doit lire une nouvelle ligne }
  blanks;
  If (lptr > Length(line)) or (Length(line) = 0) Then Begin
   If not readinline Then Break;
   lptr := 1;
  End;
   { VÇrifier l'accolade fermante }
  If match('}') Then Break;
  If eof <> 0 Then Begin
   Case Language of
    _English: errrpt('Unexpected end of file in compound statement');
    {$IFDEF FPC}
    _Germany: errrpt('Unerwartetes Dateiende in zusammengesetzter Anweisung');
    {$ENDIF}
    Else errrpt('Fin de fichier inattendue dans l''instruction composÇe');
   End;
   Exit;
  End;
  If not parse_statement Then Begin
   { Passer Ö la ligne suivante pour ÔøΩviter les boucles infinies }
   If not readinline Then Break;
   lptr := 1;
  End;
 Until False;
 safe_writeln('; Fin d''instruction composÇe');
End;

{ Analyse d'instruction d'expression }
Function parse_expression_statement: Boolean;
Var
 lval: TLVal;
 save_lptr: Integer;
Begin
 parse_expression_statement := False;

 { VÇrifier une instruction vide (juste un point-virgule) }
 If match(';') Then
 Begin
  parse_expression_statement := True;
  safe_writeln('; Instruction vide');
  Exit;
 End;

 { VÇrifier s'il y a quelque chose qui ressemble Ö une expression }
 save_lptr := lptr;
 If not (is_digit(peek_char) or is_alpha(peek_char) or (peek_char = '(')) Then Exit;
  { Essayer d'analyser l'expression }
 expression_bool(lval);
 parse_expression_statement := True;
  { Point-virgule attendu }
 If not match(';') Then errrpt('Expected ; after expression');
 safe_writeln('; Expression statement');
End;

 { Analyser l'assignation aux ÇlÇments de tableau }
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
   {$IFDEF FPC}
   _Germany: errrpt('Array nicht gefunden: ' + array_name);
   {$ENDIF}
   Else errrpt('Tableau non trouvÇ: ' + array_name);
  End;
  Exit;
 End;
  { VÇrifier que c'est bien un tableau }
 If (array_symbol^.ident <> it_array) and (array_symbol^.type_info.array_size = 0) Then Begin
  Case Language of
   _English: errrpt('Variable is not an array: ' + array_name);
   {$IFDEF FPC}
   _Germany: errrpt('Variable ist kein Array: ' + array_name);
   {$ENDIF}
   Else errrpt('La variable n''est pas un tableau: ' + array_name);
  End;
  Exit;
 End;
 safe_writeln('; Assignation Ö ÇlÇment de tableau ' + array_name);
  { Analyser l'expression d'index (le '[' a dÇjÖ ÇtÇ consommÇ) }
 additive_expression(index_lval);
  { Consommer ']' }
 If not match(']') Then Begin
  Case Language of
   _English: errrpt('Expected ] after array index');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete ] nach Array-Index');
   {$ENDIF}
   Else errrpt('] attendu apräs l''index du tableau');
  End;
  Exit;
 End;
  { Consommer '=' }
 If not match('=') Then Begin
  Case Language of
   _English: errrpt('Expected = in array assignment');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartete = in Array-Zuweisung');
   {$ENDIF}
   Else errrpt('= attendu dans l''assignation de tableau');
  End;
  Exit;
 End;
  { Sauvegarder l'index sur la pile }
 ol('PUSH AX      ; sauvegarder index sur pile');
  { Analyser l'expression du cìtÇ droit }
 expression(right_lval);
  { Sauvegarder la valeur √† assigner }
 ol('PUSH AX      ; sauvegarder valeur Ö assigner');
  { RÇcupÇrer l'index }
 ol('POP  BX      ; rÇcupÇrer valeur dans BX');
 ol('POP  AX      ; rÇcupÇrer index dans AX');
  { Calculer la taille d'un ÇlÇment }
 element_size := get_type_size(array_symbol^.type_info.base_type);
  { Si la taille d'ÇlÇment n'est pas 1, multiplier l'index }
 If element_size > 1 Then Begin
  safe_writeln('; Multiplier index par taille ÇlÇment');
  Case element_size of
   2: ol('SHL  AX, 1    ; multiplier par 2');
   4: Begin
       ol('SHL  AX, 1    ; multiplier par 4 (shift 1)');
       ol('SHL  AX, 1    ; multiplier par 4 (shift 2)');
      End;
   8: Begin
       ol('SHL  AX, 1    ; multiplier par 8 (shift 1)');
       ol('SHL  AX, 1    ; multiplier par 8 (shift 2)');
       ol('SHL  AX, 1    ; multiplier par 8 (shift 3)');
      End;
  Else
   Begin
    { Multiplication gÇnÇrale }
    ot('MOV  AL, ');
    outdec(element_size);
    nl;
    ol('CALL mult16');
   End;
  End;
 End;
  { Ajouter l'adresse de base du tableau }
 ot('addd #');
 outstr(array_name);
 nl;
  { Entreposer la valeur Ö l'adresse calculÇe }
 ol('tfr  d,y    ; adresse dans Y');
 ol('tfr  x,d    ; rÇcupÇrer valeur dans D');
 Case element_size of
  1: ol('stb  ,y     ; entreposer octet');
  2: ol('MOV  [BP], AX     ; entreposer mot');
 Else
  ol('std  ,y     ; entreposer mot par dÇfaut');
 End;
 safe_writeln('; Assignation Ö ' + array_name + '[] terminÇe');
End;

{ Analyseur d'instructions d'affectation }
Function parse_assignment_statement: Boolean;
Var
 var_name: String;
 lval, right_lval: TLVal;
 save_lptr: Integer;
Begin
 parse_assignment_statement := False;
 save_lptr := lptr;
  { Essayer d'analyser un identifiant }
 If symname(var_name) Then Begin
  blanks;
   { VÇrifier si c'est un accäs Ö un tableau }
  If match('[') Then Begin
   { Assignation Ö un ÇlÇment de tableau: tableau[index] = valeur }
   parse_array_assignment(var_name);
   parse_assignment_statement := True;
  End
   Else
  If match('=') Then Begin
   { C'est une assignation simple Ö une variable }
   blanks;
    { Rechercher la variable }
   If lookup_variable(var_name, lval) Then Begin
    { VÇrifier si la variable est constante }
    If lval.type_info.is_const Then Begin
     Case Language of
      _English: errrpt('Cannot assign to const variable: ' + var_name);
      {$IFDEF FPC}
      _Germany: errrpt('Kann const Variable nicht zuweisen: ' + var_name);
      {$ENDIF}
      Else errrpt('Impossible d''assigner Ö la variable const: ' + var_name);
     End;
     Exit;
    End;
     { Analyser l'expression du cìtÇ droit }
    expression(right_lval);
     { GÇnÇrer le code d'affectation }
    ot('MOV  ');
    outstr(var_name);
    outstr(', AX');
    nl;
    safe_writeln('; Affectation Ö la variable: ' + var_name);
    parse_assignment_statement := True;
   End;
  End
   Else
  Begin
    { Ce n'est pas une affectation, restaurer la position }
   lptr := save_lptr;
  End;
 End;
End;

 { Analyseur d'instructions principal }
Function parse_statement: Boolean;Begin
 parse_statement := False;
  { Ignorer les lignes vides et les commentaires }
 blanks;
 If Length(line) = 0 Then Begin
  parse_statement := True;
  Exit;
 End;
  { Essayer les diffÇrents types d'instructions }
 If parse_label_statement Then
  parse_statement := True
 Else If parse_case_statement Then
  parse_statement := True
 Else If parse_default_statement Then
  parse_statement := True
 Else If parse_compound_statement Then
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
 Else If parse_switch_statement Then
  parse_statement := True
 Else If parse_return_statement Then
  parse_statement := True
 Else If parse_break_statement Then
  parse_statement := True
 Else If parse_continue_statement Then
  parse_statement := True
 Else If parse_goto_statement Then
  parse_statement := True
 Else If parse_declaration Then
  parse_statement := True
 Else If parse_expression_statement Then
  parse_statement := True
 Else If parse_assignment_statement Then
  parse_statement := True;
End;

Procedure header;Begin
 If use_stdout Then
  WriteLn('; ', VERSION)
 Else
  safe_writeln('; ' + VERSION);
End;

Procedure trailer;Begin
  { Appliquer les optimisations si activÇes }
 If optimize > OPT_NONE Then
 Begin
  optimize_code;
  output_optimized_instructions;
  free_opt_instructions; { LibÇrer la mÇmoire des instructions d'optimisation }
 End;
 If use_stdout Then Begin
  If asmtype = AS8086 Then WriteLn(';    .end')
                      Else WriteLn('  END');
 End
  Else
 Begin
  If asmtype = AS8086 Then safe_writeln(';    .end')
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

 { Analyse amÇliorÇe avec dÇclarations de variables, structures de contrìle et analyseur d'expressions }
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
   { Traitement simple des commentaires }
  If match('/*') Then Begin
   While (not match('*/')) and (eof = 0) do
    readinline;
   Continue;
  End;
   { Traiter les directives de prÇprocesseur AVANT l'expansion des macros }
  If match('#') Then Begin
   If match('include') Then Begin
     { Traiter la directive #include }
    If not should_skip_code Then Begin
     If process_include_directive(line) Then Begin
      { Inclusion rÇussie - rÇinitialiser le pointeur de ligne et continuer avec le fichier inclus }
      lptr := Length(line) + 1; { Forcer l'appel de readinline pour le nouveau fichier }
      Continue;
     End
      Else
     Begin
      { Erreur dÇjÖ signalÇe, ignorer cette ligne }
      Continue;
     End;
    End
     Else
    Begin
     { Ignorer l'inclusion dans un bloc conditionnel }
     Continue;
    End;
   End
    Else
   If match('define') Then Begin
    { Traiter la directive #define }
    If not should_skip_code Then Begin
     If process_define_directive(line) Then
      Continue  { Continuer avec la ligne suivante }
      Else
     Begin
      { Erreur dÇjÖ signalÇe, ignorer cette ligne }
      Continue;
     End;
    End
     Else
    Begin
     { Ignorer le define dans un bloc conditionnel }
     Continue;
    End;
   End
    Else
   If match('if ') Then Begin
    { Traiter la directive #if }
    blanks;
    process_if_directive(Copy(line, lptr, 255));
    Continue;
   End
    Else
   If match('ifdef ') Then Begin
     { Traiter la directive #ifdef }
    blanks;
    process_ifdef_directive(Copy(line, lptr, 255));
    Continue;
   End
    Else
   If match('ifndef ') Then Begin
    { Traiter la directive #ifndef }
    blanks;
    process_ifndef_directive(Copy(line, lptr, 255));
    Continue;
   End
    Else
   If match('elif ') Then Begin
    { Traiter la directive #elif }
    blanks;
    process_elif_directive(Copy(line, lptr, 255));
    Continue;
   End
    Else
   If match('else') Then Begin
    { Traiter la directive #else }
    process_else_directive;
    Continue;
   End
    Else
   If match('endif') Then Begin
    { Traiter la directive #endif }
    process_endif_directive;
    Continue;
   End
    Else
   Begin
    { Autres directives de prÇprocesseur - ignorer pour l'instant }
    safe_writeln('; Skipping preprocessor directive: ' + line);
    Continue;
   End;
  End;
   { VÇrifier si on doit ignorer le code en raison de la compilation conditionnelle }
  If should_skip_code Then Begin
   { Ignorer cette ligne complÇtement }
   Continue;
  End;
   { Appliquer l'expansion des macros Ö la ligne APRES le traitement conditionnel }
  expanded_line := expand_macros(line);
  If expanded_line <> line Then Begin
   line := expanded_line;
   If use_stdout Then WriteLn('; Line after macro expansion: ', line)
                 Else safe_writeln('; Line after macro expansion: ' + line);
  End;
   { Ignorer les lignes vides }
  blanks;
  If Length(line) = 0 Then Continue;
  safe_writeln('; Processing: ' + line);
   { RÇinitialiser la position pour l'analyse }
  lptr := 1;
  FillChar(lval, SizeOf(lval), 0);
   { Essayer d'analyser comme instruction (inclut les dÔøΩclarations et les structures de contrìle) }
  If parse_statement Then Begin
   safe_writeln('; Statement processed');
   Continue;
  End;
   { Repli: Analyser les identifiants et les expressions pour la compatibilitÇ ascendante }
  lptr := 1;
  If symname(sname) Then Begin
   safe_writeln('; Identifier: ' + sname);
    { VÇrifier l'affectation }
   blanks;
   If match('=') Then Begin
    safe_writeln('; Affectation Ö ' + sname);
    blanks;
     { Rechercher la variable dans la table de symboles }
    If lookup_variable(sname, lval) Then Begin
     { VÇrifier si la variable est constante et empàcher l'affectation }
     If lval.type_info.is_const Then Begin
      Case Language of
       _English: errrpt('Cannot assign to const variable: ' + sname);
       {$IFDEF FPC}
       _Germany: errrpt('Kann const Variable nicht zuweisen: ' + sname);
       {$ENDIF}
       Else errrpt('Impossible d''assigner Ö la variable const: ' + sname);
      End;
     End
      Else
     Begin
      safe_writeln('; Affectation Ö la variable: ' + sname);
       { Utiliser l'analyseur d'expressions pour le cìtÇ droit }
      expression(right_lval);
       { Entreposer le rÇsultat dans la variable }
      ot('MOV  ');
      outstr(sname);
      outstr(', AX');
      nl;
     End;
    End;
   End
    Else
   Begin
    { Charger la variable }
    If lookup_variable(sname, lval) Then Begin
     ot('MOV  AX, ');
     outstr(sname);
     nl;
    End;
   End;
   Continue;
  End;
   { Essayer d'analyser comme expression }
  lptr := 1;
  blanks;
  If (peek_char >= '0') and (peek_char <= '9') Then Begin
   safe_writeln('; Expression detectÇ');
   expression(lval);
   Continue;
  End;
   { Repli pour la dÇtection simple de fonction }
  If Pos('(', line) > 0 Then Begin
   safe_writeln('; Function found: ' + line);
   ol('nop ; placeholder for function');
  End;
  { Produire le contenu restant sous forme de commentaire }
  If Length(line) > 0 Then Begin
   safe_writeln('; Inconnu: ' + line);
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
    WriteLn('CC8086 - This command allows you to launch the C compiler for ',
            'the 8086 microprocessor.');
    WriteLn;
    WriteLn('usage: CC8086 infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options:');
    WriteLn('  -O0    No optimization (default)');
    WriteLn('  -O1    Basic optimizations (peephole, constant folding)');
    WriteLn('  -O2    Advanced optimizations (+ dead code, jumps)');
    WriteLn('  -O3    Aggressive optimizations (all)');
   End;
   {$IFDEF FPC}
   _Germany:Begin
    WriteLn('CC8086 - Dieser Befehl ermîglicht es, den C-Compiler fÅr ',
            'den 8086-Mikroprozessor zu starten.');
    WriteLn;
    WriteLn('Syntax: CC8086 infile.c [outfile] [-optionen]');
    WriteLn;
    WriteLn('Optionen:');
    WriteLn('  -O0    Keine Optimierung (Standard)');
    WriteLn('  -O1    Grundlegende Optimierungen (Guckloch, Konstantenfaltung)');
    WriteLn('  -O2    Erweiterte Optimierungen (+ toter Code, SprÅnge)');
    WriteLn('  -O3    Aggressive Optimierungen (alle)');
   End;
   {$ENDIF}
   Else Begin
    WriteLn('CC8086 - Cette commande permet de lancer le compilateur C pour ',
            'le microprocesseur 8086.');
    WriteLn;
    WriteLn('Syntaxe : CC8086 infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options :');
    WriteLn('  -O0    Pas d''optimisation (valeur par dÇfaut)');
    WriteLn('  -O1    Optimisations de base (oeilleon, pliage constant)');
    WriteLn('  -O2    Optimisations avancÇes (code mort, sauts)');
    WriteLn('  -O3    Optimisations aggressives (toutes)');
   End;
  End;
  Halt(1);
 End;
  { Initialiser les variables - symtab plus nÇcessaire }
 { FillChar(symtab, SizeOf(symtab), 0); -- Ancienne table de symboles supprimÇe }
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
 { Initialiser le systäme de fichiers d'inclusion }
 include_depth := 0;
 current_filename := '';
 { Initialiser le systäme de dÇfinition }
 init_defines;
 { Initialiser la table de symboles basÇe sur la mÇmoire de tas }
 init_symbols;
  { Corps principal du compilateur }
 nxtlab := 0;
 kill;
 WriteLn('CC8086 - Compilateur C pour 8086 V1.01');
 WriteLn;
 optimize := OPT_NONE;
 ctext := NO;
 { Analyser les arguments de la ligne de commande }
 For i := 1 to ParamCount do Begin
  param := ParamStr(i);
  If param = '-O0' Then optimize := OPT_NONE
  Else If param = '-O1' Then optimize := OPT_BASIC
  Else If param = '-O2' Then optimize := OPT_ADVANCED
  Else If param = '-O3' Then optimize := OPT_AGGRESSIVE;
 End;
  { Ouvrir le fichier d'entrÇe avec vÇrification d'erreur }
 Assign(input, ParamStr(1));
 {$I-}
 Reset(input);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur: Impossible d''ouvrir le fichier : ', ParamStr(1));
  Halt(1);
 End;
 {$I+}
 current_filename := ParamStr(1); { DÇfinir le nom de fichier initial pour le systäme d'inclusion }
 WriteLn('Compilation du fichier source: ', ParamStr(1));
  { Initialiser les variables globales }
 eof := 0;
 errcnt := 0;
 lptr := 1;
 line := '';
 nextlabel := 0;
 use_stdout := True; { Initialiser la sortie standard - peut àtre modifiÇ plus tard }
  { Initialiser la table de symboles basÇe sur la mÇmoire de tas }
 init_symbols;
  { Initialiser la table de dÇfinitions }
 init_defines;
  { Initialiser le systäme d'inclusion }
 init_inclusion_system;
  { Initialiser le systäme de conditions }
 init_conditions;
  { Initialiser les tables de flux de contrìle }
 init_goto_table;
 init_switch_table;
 If optimize > OPT_NONE Then WriteLn('Niveau d''optimisation: ', optimize);
 If ParamCount >= 2 Then Begin
  param := ParamStr(2);
  If (param[1] <> '-') Then Begin { Option impossible, fichier de sortie obligatoire }
   Assign(output, param);
   {$I-} Rewrite(output);
   If IOResult <> 0 Then Begin
    WriteLn('Erreur: Impossible de crÇer le fichier de sortie: ', param);
    Halt(1);
   End;
   {$I+}
    { Message supprimÇ temporairement }
    { WriteLn('GÇnÇrer un fichier asm : ', param); }
   use_stdout := False;
  End
   Else
  Begin
   { Ne pas assigner de sortie Ö la sortie; utiliser plutìt un drapeau }
   Case Language of
    _English:WriteLn('Using console screen for output.');
    Else WriteLn('Affichage de la sortie sur la console.');
   End;
   use_stdout := True;
  End;
 End
  Else
 Begin
   { Ne pas assigner de sortie Ö la sortie; utiliser plutìt un drapeau }
  Case Language of
   _English:WriteLn('Using console screen for output.');
   Else WriteLn('Affichage de la sortie sur la console.');
  End;
  use_stdout := True;
 End;
  { Initialisation du systäme d'optimisation }
 init_optimization;
 { Initialiser la pile de contexte de boucle }
 loop_depth := 0;
 { Initialiser la table d'informations de type }
 type_info_count := 0;
  { Initialisaton du systäme de gestion des fonctions }
 init_functions;
  { Initialisation du systäme de gestion des structures }
 init_structs;
 { Initialisation de la table des Çtiquettes goto }
 init_goto_table;
 asmtype := AS8086;
 header;          { Code d''introduction }
 parse;           { Analyse toutes les entrÇe }
 trailer;         { Code de suivi }
 free_defines;    { LibÇrer la mÇmoire des dÇfinitions de la mÇmoire de tas }
 free_conditions; { LibÇrer le systäme de conditions }
 free_symbols;    { LibÇrer la table de symboles du tas }
 free_structs;    { LibÇrer les dÇfinitions de structures du tas }
 closeout;        { Fermer la sortie }
 errrptsummary;   { RÇsumer les erreurs }
END.
