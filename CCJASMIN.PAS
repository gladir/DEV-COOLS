{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @description: Compilateur C pour Jasmin JVM (Java Virtual Machine)
}

Program CCJASMIN;

{$A-}
{$I-}

Uses DOS;

Const
 VERSION = 'Compilateur C pour Jasmin JVM V1.1';  { Version du compilateur C pour JVM }
 YES = 1;                         { Valeur boolÇenne vraie }
 NO = 0;                          { Valeur boolÇenne fausse }

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
 offsize = 2;       { Taille en octets du champ dÇplacement }

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
 sizeof_int = 2;      { Taille du type int (2 octets) }
 sizeof_long = 4;     { Taille du type long (4 octets) }
 sizeof_float = 4;    { Taille du type float (4 octets) }
 sizeof_double = 8;   { Taille du type double (8 octets) }
 sizeof_pointer = 2;  { Taille d'un pointeur (2 octets) }
 sizeof_enum = 2;     { Taille du type enum (2 octets, comme int) }

  { Classes d'entreposage }
 statik = 1;      { Variable statique (durÇe de vie du programme) }
 stkloc = 2;      { Variable locale sur la pile }
 CEXTERNAL = 3;   { Variable externe dÇfinie ailleurs }
 automatic = 4;   { Variable automatique (locale par dÇfaut) }

  { Types d'instructions }
 streturn = 3;    { Instruction de retour de fonction }

  { Types d'assembleurs }
 ASJASMIN = 1;    { Assembleur Jasmin pour JVM }

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

 { Ligne d'entrÇe }
 linesize = 80;            { Taille maximale d'une ligne d'entrÇe }
 linemax = linesize - 1;   { Index maximum valide dans une ligne }

Type
  { TSymTab n'est plus nÇcessaire - utilisation d'une table de symboles basÇe sur la mÇmoire de tas }
 TLine = String[linesize];
  { Structure d'information de type }
 PTypeInfo = ^TTypeInfo;
 TTypeInfo = Record
  base_type: Integer;      { Type de donnÔøΩes de base (cint, cchar,...) }
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

  { Structure d'instruction d'optimisation dans le tas }
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
  offset: Integer;        { Offset du membre dans la structure }
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

 { Gestion des macros/Define - utilisation de la mÇmoire de tas au lieu de tableaux statiques }
 PDefine = ^TDefine;
 TDefine = Record
  name: String;
  value: String;
  in_use: Boolean;
  next: PDefine;        { Pointeur vers le prochain define dans la liste chaånÇe }
 End;

  { Gestion des directives de prÔøΩprocesseur conditionnelles }
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

 { Table de symboles utilisant la mÔøΩmoire de tas au lieu du segment de donnÇes }
 PSymbol = ^TSymbol;
 TSymbol = Record
  name: String;
  ident: Integer;        { it_variable, it_function,... }
  ctype: Integer;        { Type de symbole }
  storage: Integer;      { Classe d'entreposage }
  offset_value: Integer; { DÇplacement ou valeur }
  type_info: TTypeInfo;  { Information de type Çtendue }
  next: PSymbol;         { Symbole suivant dans la chaåne }
 End;

  { Pointeur vers fonction dans la mÇmoire de tas }
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
 TSwitchTable = Array[0..7] of TSwitchStatement; { Maximum 8 switch imbriquÇs }

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
 include_stack: Array[0..9] of TIncludeFile;  { Maximum 10 niveaux d'inclusion }
 include_depth: Integer;
 current_filename: String;

  { Table des fichiers inclus pour Çviter l'inclusion circulaire }
 included_files: Array[0..49] of TIncludedFile; { Maximum 50 fichiers diffÇrents }
 included_count: Integer;

  { Gestion Define/Macro - utilisation du tas (liste chaånÇe) }
 define_list: PDefine;  { Tàte de la liste chaånÇe des defines }
 define_count: Integer; { Nombre de dÇfinitions actuellement en usage }

 { Gestion des directives conditionnelles de prÇprocesseur }
 condition_stack: TConditionStack; { Pile de conditions }
 condition_depth: Integer;         { Profondeur actuelle de la pile }
 skip_code: Boolean;               { Vrai si on doit ignorer le code actuel }

 { Informations de type Çtendues - maintenant entreposÇes directement dans les symboles }
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

 { DÇclarations anticipÇes }
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

{ Fonctions hÇritÇes - plus nÇcessaires avec la table de symboles basÇe sur la mÇmoire de tas }
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

 { Fonctions d'entrÇe/sortie }
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
 If use_stdout Then WriteLn(s)
               Else WriteLn(output, s);
End;

Procedure nl;Begin
 safe_writeln('');
End;

{ Fonction pour convertir les instructions 6809 en instructions Jasmin JVM }
Function convert_to_jasmin(s: String): String;
Var
 result: String;
 i: Integer;
Begin
 result := s;
  { Convertir les instructions 6809 vers Jasmin JVM }
 If Pos('ldd  # ', result) = 1 Then
  result := 'bipush ' + Copy(result, 7, Length(result)) { Charger constante sur pile }
 Else If Pos('ldd  #', result) = 1 Then
  result := 'bipush ' + Copy(result, 6, Length(result)) { Charger constante sur pile (sans espace) }
 Else If Pos('ldd   ', result) = 1 Then
  result := 'iload ' + Copy(result, 7, Length(result)) { Charger variable locale }
 Else If Pos('ldd  ', result) = 1 Then
  result := 'iload ' + Copy(result, 6, Length(result)) { Charger variable locale (format alternatif) }
 Else If Pos('std   ', result) = 1 Then
  result := 'istore ' + Copy(result, 7, Length(result)) { Stocker dans variable locale }
 Else If Pos('std  ', result) = 1 Then
  result := 'istore ' + Copy(result, 6, Length(result)) { Stocker dans variable locale (format alternatif) }
 Else If Pos('pshs d', result) = 1 Then
  result := '; push already done by JVM stack' + Copy(result, 7, Length(result))
 Else If Pos('puls d', result) = 1 Then
  result := '; pop automatic by JVM stack' + Copy(result, 7, Length(result))
 Else If Pos('addd ', result) = 1 Then
  result := 'iadd' + Copy(result, 5, Length(result)) { Addition entiäre }
 Else If Pos('subd ', result) = 1 Then
  result := 'isub' + Copy(result, 5, Length(result)) { Soustraction entiäre }
 Else If Pos('cmpd ', result) = 1 Then
  result := 'if_icmpeq L' + Copy(result, 6, Length(result)) { Comparaison entiäre }
 Else If Pos('tstd', result) = 1 Then
  result := 'ifeq L' + Copy(result, 5, Length(result)) { Test si Çgal Ö zÇro }
 Else If Pos('lbeq ', result) = 1 Then
  result := 'ifeq ' + Copy(result, 6, Length(result)) { Saut si Çgal }
 Else If Pos('lbne ', result) = 1 Then
  result := 'ifne ' + Copy(result, 6, Length(result)) { Saut si non Çgal }
 Else If Pos('lbra ', result) = 1 Then
  result := 'goto ' + Copy(result, 6, Length(result)) { Saut inconditionnel }
 Else If Pos('bgt ', result) = 1 Then
  result := 'ifgt ' + Copy(result, 5, Length(result)) { Saut si supÇrieur }
 Else If Pos('bge ', result) = 1 Then
  result := 'ifge ' + Copy(result, 5, Length(result)) { Saut si supÇrieur ou Çgal }
 Else If Pos('blt ', result) = 1 Then
  result := 'iflt ' + Copy(result, 5, Length(result)) { Saut si infÇrieur }
 Else If Pos('ble ', result) = 1 Then
  result := 'ifle ' + Copy(result, 5, Length(result)) { Saut si infÇrieur ou Çgal }
 Else If Pos('jsr  ', result) = 1 Then
  result := 'invokestatic ' + Copy(result, 6, Length(result)) { Appel de mÇthode statique }
 Else If Pos('rts', result) = 1 Then
  result := 'return' + Copy(result, 4, Length(result)) { Retour de mÇthode }
 Else If Pos('swi', result) = 1 Then
  result := 'invokevirtual java/lang/System/exit(I)V' + Copy(result, 4, Length(result)) { Interruption systäme }
 Else If Pos('leas -', result) = 1 Then
  result := '; stack allocation: -' + Copy(result, 7, Length(result)) { Allocation pile }
 Else If Pos('leas ', result) = 1 Then
  result := '; stack deallocation: ' + Copy(result, 6, Length(result)) { DÇsallocation pile }
 Else If Pos('neg', result) = 1 Then
  result := 'ineg' + Copy(result, 4, Length(result)) { NÇgation entiäre }
 Else If Pos('inc', result) = 1 Then
  result := 'iconst_1' + #13#10#9 + 'iadd' + Copy(result, 4, Length(result)) { IncrÇment }
 Else If Pos('dec', result) = 1 Then
  result := 'iconst_1' + #13#10#9 + 'isub' + Copy(result, 4, Length(result)) { DÇcrÇment }
 Else If Pos('mul', result) = 1 Then
  result := 'imul' + Copy(result, 4, Length(result)) { Multiplication entiäre }
 Else If Pos('imul', result) = 1 Then
  result := result { DÇjÖ en Jasmin }
 Else If Pos('div', result) = 1 Then
  result := 'idiv' + Copy(result, 4, Length(result)) { Division entiäre }
 Else If Pos('idiv', result) = 1 Then
  result := result { DÇjÖ en Jasmin }
 Else If Pos('irem', result) = 1 Then
  result := result { Reste division - dÇjÖ en Jasmin }
 Else If Pos('iadd', result) = 1 Then
  result := result { Addition - dÇjÖ en Jasmin }
 Else If Pos('isub', result) = 1 Then
  result := result { Soustraction - dÇjÖ en Jasmin }
 Else If Pos('and', result) = 1 Then
  result := 'iand' + Copy(result, 4, Length(result)) { ET logique }
 Else If Pos('or', result) = 1 Then
  result := 'ior' + Copy(result, 3, Length(result)) { OU logique }
 Else If Pos('xor', result) = 1 Then
  result := 'ixor' + Copy(result, 4, Length(result)) { XOR logique }
 Else If Pos(',x', result) > 0 Then
  result := Copy(result, 1, Pos(',x', result) - 1) + ' ; indexed access' + Copy(result, Pos(',x', result) + 2, Length(result))
 Else
 Begin
  { Instruction non reconnue - la laisser telle quelle }
 End;
 convert_to_jasmin := result;
End;

Procedure ol(s:String);Begin
 safe_writeln(#9 + convert_to_jasmin(s));
End;

{ GÇnÇrer instruction ldd avec constante immÇdiate }
Procedure ol_ldd_imm(value: Integer);
Var
 temp: String;
Begin
 Str(value, temp);
 ol('bipush ' + temp);
End;

{ GÇnÇrer instruction ldd avec variable }
Procedure ol_ldd_var(varname: String);Begin
 ol('iload ' + varname);
End;

 { GÇnÇrer instruction std avec variable }
Procedure ol_std_var(varname: String);Begin
 ol('istore ' + varname);
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

 { Fonctions de gÇnÇration d'Çtiquettes }
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

 { GÇnÇration de code }
Procedure ot(s: String);Begin
 safe_write(#9 + s + ' '); { TAB puis chaåne de caractäres avec espace }
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

{ ÇInitialiser la table des Çtiquettes goto }
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
    Else errrpt('ÔøΩtiquette dÔøΩjÔøΩ dÔøΩfinie: ' + label_name);
   End;
   Exit;
  End;
  goto_table[index].is_defined := True;
  prelabel(goto_table[index].label_id);
  safe_writeln('; ÔøΩtiquette dÔøΩfinie: ' + label_name);
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
  ot('goto ');
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
     Else errrpt('ÔøΩtiquette non dÔøΩfinie: ' + name);
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
Function begin_switch_statement(expr_type:Integer):Boolean;Begin
 begin_switch_statement := False;
 If switch_depth >= 8 Then Begin
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
   _Germany: errrpt('case-Anweisung auÔøΩerhalb von switch');
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
    Else errrpt('Trop d''Çtiquettes case (max 32)');
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
Function add_switch_default: Integer;Begin
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
  If has_default Then
  Begin
   Case Language of
    _English: errrpt('Multiple default labels in switch');
    {$IFDEF FPC}
    _Germany: errrpt('Mehrere default-Labels in switch');
    {$ENDIF}
    Else errrpt('Plusieurs Çtiquettes default dans switch');
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
   ot('cmpi #');
   outdec(cases[i].value);
   nl;
   ot('lbeq ');
   printlabel(cases[i].label_id);
   nl;
  End;
   { Saut vers default ou fin }
  If has_default Then Begin
   ot('goto ');
   printlabel(default_label);
   nl;
  End
   Else
  Begin
   ot('goto ');
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
Function get_current_switch_end:Integer;Begin
 get_current_switch_end := -1;
 If switch_depth > 0 Then
  get_current_switch_end := switch_table[switch_depth - 1].end_label;
End;

 { Gestion de contexte de boucle pour le support break/continue }
Procedure push_loop_context(loop_type:Integer;break_lbl,continue_lbl:Integer);Begin
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
 If loop_depth > 0 Then Dec(loop_depth);
End;

Function get_current_break_label:Integer;Begin
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
 If loop_depth > 0 Then get_current_continue_label := loop_stack[loop_depth-1].continue_label;
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
{ NOUVELLES FONCTIONS DE TABLE DE SYMBOLES BASêE SUR LE TAS                    }
{ ============================================================================ }

{ Initialiser la table de symboles basÇe sur la mÇmoire de tas }
Procedure init_symbols;Begin
 symbol_list := nil;
 symbol_count := 0;
End;

 { Trouver un symbole dans la table de symboles basÇe sur la mÇmoire de tas }
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

 { Fonction addsym amÇliorÇe utilisant la mÇmoire de tas }
Function addsym_heap(sname: String; typ: Integer; storage: Integer; offset_value: Integer):PSymbol;Begin
 addsym_heap := add_symbol(sname, it_variable, typ, storage, offset_value);
End;

 { Fonction findsym amÇliorÇe utilisant la mÇmoire de tas }
Function findsym_heap(sname: String):PSymbol;Begin
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
 Else can_convert_type := False;
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
   ol('clra   ; extension zÇro char non signÇ');
  End
   Else
  Begin
   ol('i2b    ; extension byte JVM');
  End;
 End
  { GÇrer la conversion int vers char }
  Else
 If (from_type.base_type = cint) and (to_type.base_type = cchar) Then Begin
  ol('i2b    ; conversion int vers byte JVM');
 End
  { GÇrer la conversion int vers long }
 Else If (from_type.base_type = cint) and (to_type.base_type = clong) Then Begin
  If from_type.is_unsigned Then Begin
   ol('clr  -2,s   ; partie haute = 0 pour unsigned');
   ol('clr  -1,s');
  End
  Else
  Begin
   ol('tsta        ; test du signe');
   ol('bpl  +      ; si positif, partie haute = 0');
   ol('ldd  #$FFFF ; si nÇgatif, partie haute = $FFFF');
   ol('std  -2,s   ; stocker partie haute');
   ol('bra  ++');
   ol('+ clr  -2,s  ; partie haute = 0');
   ol('clr  -1,s');
   ol('++');
  End;
 End
  { GÇrer la conversion long vers int }
 Else If (from_type.base_type = clong) and (to_type.base_type = cint) Then Begin
  ol('ldd  -2,s    ; charger partie basse du long');
  ol('leas 2,s     ; ajuster pile (partie haute ignorÇe)');
 End
  { GÇrer la conversion char vers long }
  Else
 If (from_type.base_type = cchar) and (to_type.base_type = clong)Then Begin
  If from_type.is_unsigned Then Begin
   ol('clra        ; extension zÇro char');
   ol('clr  -2,s   ; partie haute = 0');
   ol('clr  -1,s');
  End
   Else
  Begin
   ol('sex         ; extension de signe char vers int');
   ol('tsta        ; test du signe de la partie int');
   ol('bpl  +      ; si positif, partie haute = 0');
   ol('ldd  #$FFFF ; si nÇgatif, partie haute = $FFFF');
   ol('std  -2,s   ; entreposer partie haute');
   ol('bra  ++');
   ol('+ clr  -2,s  ; partie haute = 0');
   ol('clr  -1,s');
   ol('++');
  End;
 End
  { GÇrer la conversion long vers char }
  Else
 If (from_type.base_type = clong) and (to_type.base_type = cchar) Then Begin
  ol('ldd  -2,s    ; charger partie basse du long');
  ol('tfr  b,a     ; ne garder que l''octet faible');
  ol('clrb');
  ol('leas 4,s     ; ajuster pile (libÇrer long)');
 End
 { GÇrer les conversions enum (traitÇ comme int) }
  Else
 If (from_type.base_type = cenum) and (to_type.base_type <> cenum)Then Begin
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
 safe_writeln('; Parsing dÇclaration typedef');
 { Le mot clef typedef a dÇjÖ ÇtÇ consommÇ }

 { Analyser le type de base }
 base_type := parse_type_specifier_with_qualifiers(type_info);
 If base_type = -1 Then
 Begin
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
  { D√©finir les indicateurs d'optimisation en fonction du niveau }
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
    Else
   If (current^.opcode = 'pshs') and (current^.operand = 'd') Then Begin
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
   End
    Else
   Begin
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
   If (next1^.opcode = 'nega') and (next2^.opcode = 'negb') Then Begin
    current^.operand := '#-1';
    current^.comment := current^.comment + ' ; constante pliÇe';
    next1^.can_eliminate := True;
    next2^.can_eliminate := True;
   End;
  End
   { Optimise la multiplication par la puissance de 2 }
   Else
  If (current^.opcode = 'jsr') and (current^.operand = 'mult16') Then Begin
   { Il faudrait plus de contexte pour dÇterminer s'il s'agit d'une multiplication par une constante }
   Case Language of
    _English: current^.comment := current^.comment + ' ; could optimize if power of 2';
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
   current^.comment := current^.comment + ' ; candidat Ö l''optimisation de saut';
  End;
  current := current^.next;
 End;
End;

 { Appliquer toutes les optimisations }
Procedure optimize_code;Begin
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
    If Length(comment) > 0 Then safe_writeln(#9 + opcode + ' ' + operand + ' ; ' + comment)
                           Else safe_writeln(#9 + opcode + ' ' + operand);
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
 If optimize > OPT_NONE Then add_instruction(op, operand, '')
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
   0: add_instruction('iconst_0', '', 'chargement zÇro optimisÇ JVM');
   1: add_instruction('iconst_1', '', 'chargement un optimisÇ JVM');
   -1: add_instruction('iconst_m1', '', 'chargement -1 optimisÇ JVM');
  Else
   Begin
    Str(value, temp);
    add_instruction('bipush', temp, 'charger constante JVM');
   End;
  End;
 End
 Else
 Begin
  ol_ldd_imm(value);
 End;
End;

 { Affectation de variable optimisÇe }
Procedure opt_store_variable(var_name: String; size: Integer);
Begin
 If optimize > OPT_NONE Then
 Begin
  Case size of
   1: add_instruction('istore', var_name, 'stocker byte JVM');
   2: add_instruction('istore', var_name, 'stocker int JVM');
  Else
   add_instruction('istore', var_name, 'stocker par dÇfaut JVM');
  End;
 End
 Else
 Begin
  Case size of
   1: Begin
       ol('istore ' + var_name);
      End;
   2: Begin
       ol('istore ' + var_name);
      End;
  Else
   Begin
    ol('istore ' + var_name);
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
   0: { Ne rien faire - ajouter zÇro };
   1: add_instruction('inc', 'd', '+1 optimisÇ');
   -1: add_instruction('dec', 'd', '-1 optimisÇ');
  Else
   Begin
    Str(value, temp);
    add_instruction('addd', '#' + temp, 'ajouter constante');
   End;
  End;
 End
  Else
 Begin
  If value <> 0 Then Begin
   ot('addd #');
   outdec(value);
   nl;
  End;
 End;
End;

{ Multiplication optimisÇe }
Procedure opt_multiply(value:Integer);Begin
 If optimize > OPT_NONE Then Begin
   { Optimiser la multiplication par des puissances de 2 }
  Case value of
   0: add_instruction('iconst_0', '', 'multiplier par 0 JVM');
   1: { Ne rien faire - multiplier par 1 };
   2: Begin
       add_instruction('iconst_1', '', 'dÇcalage pour *2 JVM');
       add_instruction('ishl', '', 'dÇcalage gauche JVM');
      End;
   4: Begin
       add_instruction('iconst_2', '', 'dÇcalage pour *4 JVM');
       add_instruction('ishl', '', 'dÇcalage gauche JVM');
      End;
   8: Begin
       add_instruction('iconst_3', '', 'dÇcalage pour *8 JVM');
       add_instruction('ishl', '', 'dÇcalage gauche JVM');
      End;
  Else
   add_instruction('imul', '', 'multiplication gÇnÇrale JVM');
  End;
 End
  Else
 ol('imul      ; multiplication JVM');
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
{ FONCTIONS DE SUPPORT POUR LES OPêRATIONS LONG (32 BITS) SUR 6809             }
{ ============================================================================ }

 { GÇnÇrer une routine d'addition long (32 bits) }
Procedure generate_long_add;Begin
 safe_writeln('; Addition long 32 bits - Jasmin JVM');
 safe_writeln('long_add:');
 ol('; Addition long : JVM gäre nativement les longs 64-bit');
 ol('ladd        ; addition long JVM (64-bit)');
 ol('return      ; retour JVM');
End;

 { GÇnÇrer une routine de soustraction long (32 bits) }
Procedure generate_long_sub;Begin
 safe_writeln('; Soustraction long 32 bits - Jasmin JVM');
 safe_writeln('long_sub:');
 ol('; Soustraction long : JVM gäre nativement les longs 64-bit');
 ol('lsub        ; soustraction long JVM (64-bit)');
 ol('return      ; retour JVM');
End;

 { GÇnÇrer une routine de multiplication long (32 bits) }
Procedure generate_long_mul;Begin
 safe_writeln('; Multiplication long 32 bits - Jasmin JVM');
 safe_writeln('long_mul:');
 ol('; Multiplication long : JVM gäre nativement les longs 64-bit');
 ol('lmul        ; multiplication long JVM (64-bit)');
 ol('return      ; retour JVM');
End;

{ GÇnÇrer une routine de division long (32 bits) - version simplifiÇe }
Procedure generate_long_div;Begin
 safe_writeln('; Division long 32 bits - Jasmin JVM');
 safe_writeln('long_div:');
 ol('; Division long : JVM gäre nativement les longs 64-bit');
 ol('ldiv        ; division long JVM (64-bit)');
 ol('return      ; retour JVM');
End;

 { GÇnÇrer les routines de comparaison long }
Procedure generate_long_compare;Begin
 safe_writeln('; Comparaison long 32 bits - Jasmin JVM');
 safe_writeln('long_cmp:');
 ol('; Comparaison long : JVM gäre nativement les longs 64-bit');
 ol('lcmp        ; comparaison long JVM (64-bit)');
 ol('return      ; retour JVM');
End;

 { Charger une constante long sur la pile }
Procedure load_long_constant(value: LongInt);
Var
 temp_str: String;
Begin
 Str(value, temp_str);
 safe_writeln('; Charger constante long: ' + temp_str);
 ol('ldc2_w ' + temp_str + 'L  ; charger constante long JVM');
End;

 { Charger une variable long depuis la mÇmoire }
Procedure load_long_variable(var_name: String);Begin
 safe_writeln('; Charger variable long: ' + var_name);
 ol('lload ' + var_name + '     ; charger variable long JVM');
End;

 { Entreposer un long de la pile vers une variable }
Procedure store_long_variable(var_name: String);Begin
 safe_writeln('; Stocker variable long: ' + var_name);
 ol('lstore ' + var_name + '    ; stocker variable long JVM');
End;

{ ============================================================================ }
{ FONCTIONS DE GESTION DES FONCTIONS                                           }
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
Function add_function(func_name:String;return_type:Integer):Integer;
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
    Else errrpt('Trop de param√®tres pour la fonction ' + name);
   End;
   Exit;
  End;
  With parameters[param_count] do Begin
   name := param_name;
   typ := param_type;
   init_type_info(type_info);
   type_info.base_type := param_type;
   calculate_type_size(type_info);
   offset := param_count * 2; { 2 octets par paramätre sur la pile }
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
   { Prologue standard Jasmin JVM }
  If not is_main Then Begin
   safe_writeln('; Prologue fonction JVM - gestion automatique');
   safe_writeln('; Variables locales allouÇes automatiquement par JVM');
  End
   Else
  Begin
   safe_writeln('; Point d''entrÇe de la fonction principale JVM');
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
   { êpilogue standard Jasmin JVM }
   safe_writeln('; DÇsallocation automatique JVM');
   ol('return    ; retourner Ö l''appelant JVM');
  End
   Else
  Begin
   safe_writeln('; Sortie de fonction principale');
   ol('return    ; fin de programme JVM');
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
  If arg_count <> param_count Then
   safe_writeln('; Attention: Nombre d''arguments ne correspond pas');
   { GÇnÇrer l'instruction d'appel }
  ot('invokestatic ');
  outstr(name);
  ol('()V');
   { Nettoyer la pile - gestion automatique JVM }
  If param_count > 0 Then Begin
   safe_writeln('; Paramätres gÇrÇs automatiquement par JVM');
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
Function find_struct(struct_name:String):PStructDef;
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
Function find_struct_by_id(struct_id:Integer):PStructDef;
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
Function create_struct(struct_name:String;is_union:Boolean):PStructDef;
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
     { Dans une union, tous les membres ont offset 0 }
    offset := 0;
     { La taille de l'union est la taille du plus grand membre }
    If member_size > total_size Then
     total_size := member_size;
   End
    Else
   Begin
    { Dans une structure, les membres sont align√©s s√©quentiellement }
    offset := total_size;
    total_size := total_size + member_size;
   End;
  End;
  Inc(member_count);
  add_struct_member := True;
 End;
End;

 { Trouver un membre dans une structure }
Function find_struct_member(struct_def:PStructDef;member_name:String):Integer;
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
 While current <> nil do
 Begin
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
    If not readinline Then Begin
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
   safe_writeln('; Analyse le membre...');
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
    Else errrpt('Structure/Union non dÇfinie: ' + struct_name);
   End;
   Exit;
  End;
  parse_struct_declaration := struct_def^.struct_id;
 End;
End;

 { DÇclarations anticipÇes pour l'analyse d'expression et les fonctions d'analyse }
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
Function get_type_name_from_id(type_id: Integer):String;begin
  case type_id of
    cvoid: get_type_name_from_id := 'void';
    cchar: get_type_name_from_id := 'char';
    cint: get_type_name_from_id := 'int';
    else get_type_name_from_id := 'int'; { Par d√©faut }
  end;
end;

 { Obtenir le nom d'un symbole depuis son pointeur entreposÇ comme entier }
Function get_symbol_name(symbol_ptr_as_int: Integer): String;
Var
  sym_ptr: PSymbol;
Begin
 If symbol_ptr_as_int = 0 then Begin
  get_symbol_name := 'unknown';
  exit;
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
   { Le qualificateur const est gÇrÇ dans parse_declarator }
   safe_writeln('; qualificateur const dÇtectÇ');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   { Le qualificateur volatile est gÇrÇ dans parse_declarator }
   safe_writeln('; qualificateur volatile dÇtectÇ');
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
  Else If match('enum') Then
  Begin
   base_type := parse_enum_type;
   Break;
  End
  Else
   Break; { Plus de spÇcificateurs de type }
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
  If match('const') Then
  Begin
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
   { Analyser la dÇclaration de structure compläte }
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
   { Analyser la dÇclaration d'union compläte }
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

 { Parser une dÇclaration enum }
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
  If not symname(identifier) Then Break;
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
  Inc(enum_value); { Prochaine valeur par dÇfaut }
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
 If type_info.base_type = 0 Then type_info.base_type := base_type;
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
 If not symname(func_name) Then Begin
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
 If not match('(') Then Begin
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
 If ch = ')' Then gch; { Consommer la parenth√®se fermante }
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
   { Analyser simplifiÇ - ignorer le contenu pour l'instant }
   While (ch <> #0) and (ch <> '}') Do Begin
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
   { Traiter comme fonction non d√©clar√©e retournant int }
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
   ol('; argument poussÇ automatiquement sur pile JVM');
   Inc(arg_count);
  Until not match(',');
   { Attendre parenthäse fermante }
  If not match(')') Then Begin
   Case Language of
    _English: errrpt('Expected ) after function arguments');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete ) nach Funktionsargumenten');
    {$ENDIF}
    Else errrpt(') attendu apr√®s les arguments de fonction');
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
 If find_symbol(var_name) <> nil Then Begin
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
 If type_info.array_size > 0 Then sym_ptr := add_symbol(var_name, it_array, var_type, storage_class, 0)
                             Else sym_ptr := add_symbol(var_name, it_variable, var_type, storage_class, 0);
 If sym_ptr <> nil Then Begin
  { Entreposer les informations de type directement dans le symbole }
  sym_ptr^.type_info := type_info;
  If use_stdout Then WriteLn('; Variable dÇclarÇe: ', var_name, ' (', get_type_name(type_info), ')')
                Else safe_writeln('; Variable dÇclarÇe: ' + var_name);
   { GÇnÇrer l'allocation d'entreposage basÇe sur la classe d'entreposage }
  Case storage_class of
   CEXTERNAL:
   Begin
    { Variable externe - ne pas gÇnÇrer d'allocation, juste rÇfÇrencer }
    safe_writeln('; Variable externe: ' + var_name + ' (dÇfinie ailleurs)');
   End;
   statik:
   Begin
    { Variable statique - gÇnÇrer champ statique dans la classe Jasmin }
    safe_writeln('.field public static ' + var_name + ' I');
    safe_writeln('; Variable statique: ' + var_name);
   End;
    Else
   Begin
    { Variable automatique - allouer slot de variable locale }
    type_size := type_info.size;
    safe_writeln('; Variable locale: ' + var_name + ' (slot local)');
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
  lval.symbol := Integer(sym_ptr); { Entreposer le pointeur comme entier pour compatibilitÇ }
  lval.typ := sym_ptr^.ctype;
  lval.storage := sym_ptr^.storage;
  lval.indirect := 0;
  lval.constant := False;
   { Les informations de type sont entreposÇes directement dans le symbole }
  lval.type_info := sym_ptr^.type_info;
 End
  Else
 Begin
  { Variable non trouvÇe - traiter comme nouvelle variable pour l'instant }
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

Function pop_include_file:Boolean;Begin
 pop_include_file := False;
 If include_depth <= 0 Then Exit;
  { DÇsactiver le marquage du fichier actuel comme n'Çtant plus en cours de traitement }
  { unmark_file_included(current_filename); } { CommentÇ pour le moment }
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
  { Restaure la ligen d'Çtat proprement }
  line := saved_line;
  lptr := saved_lptr;
  eof := saved_eof;
 End;
 safe_writeln('; Returned from include file to: ' + current_filename);
 pop_include_file := True;
End;

 { OpÇrations sur les fichiers }
Function readinline: Boolean;Begin
 readinline := False;
 Repeat
  { VÇrifier si le fichier d'entrÇe est correctement initialisÇ }
  {$I-}
  If not System.Eof(input) Then Begin
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

 { Inclure les fonctions de gestion de fichiers }

 { Initialiser le systäme d'inclusion }
Procedure init_inclusion_system;
Var
 i: Integer;
Begin
 include_depth := 0;
 included_count := 0;
 current_filename := 'main.c'; { Fichier main par dÇfaut }
 For i := 0 to 49 do Begin
  included_files[i].filename := '';
  included_files[i].is_included := False;
 End;
End;

 { VÇrifier si un fichier est dÇjÖ prÇsentement inclus }
Function is_file_included(filename: String): Boolean;
Var
 i: Integer;
Begin
 is_file_included := False;
 For i := 0 to included_count - 1 do Begin
  If included_files[i].filename = filename Then Begin
   is_file_included := included_files[i].is_included;
   Exit;
  End;
 End;
End;

 { Marquer un fichier Ö inclure }
Procedure mark_file_included(filename:String);
Var
 i: Integer;
Begin
  { VÇrifier s'il est dÇjÖ dans la table }
 For i := 0 to included_count - 1 do Begin
  If included_files[i].filename = filename Then Begin
   included_files[i].is_included := True;
   Exit;
  End;
 End;
  { Ajout d'un nouveau entrÇe si l'espace est disponible }
 If included_count < 50 Then Begin
  included_files[included_count].filename := filename;
  included_files[included_count].is_included := True;
  Inc(included_count);
 End;
End;

 { DÇsactivez le marquage d'un fichier lorsque vous quittez son paramätre }
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
  { Saute #include et les espaces blancs }
 start_pos := Pos('#include', include_line);
 If start_pos > 0 Then Begin
  start_pos := start_pos + 8; { Longueur de '#include' }
   { Saute les espaces blancs }
  While (start_pos <= Length(include_line)) and
        ((include_line[start_pos] = ' ') or (include_line[start_pos] = #9)) do
   Inc(start_pos);
  { VÇrifier pour les guillemets et le symbole plus petit }
  If start_pos <= Length(include_line) Then Begin
   If (include_line[start_pos] = '"') or (include_line[start_pos] = '<') Then Begin
    Inc(start_pos); { Saute le guillemet et le symbole plus petit }
    end_pos := start_pos;
     { Recherche le guillemet et le symbole plus grand }
    While (end_pos <= Length(include_line)) and
          (include_line[end_pos] <> '"') and
          (include_line[end_pos] <> '>') do
     Inc(end_pos);
    If end_pos <= Length(include_line) Then filename := Copy(include_line, start_pos, end_pos - start_pos);
   End;
  End;
 End;
 extract_filename := filename;
End;

Function push_include_file(include_filename: String): Boolean;Begin
 push_include_file := False;
  { VÇrifier pour l'inclusion circulaire }
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
  { VÇrifier pour la profondeur maximum d'inclusion }
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
  { Sauvegarde l'Çtat courant du fichier }
 With include_stack[include_depth] do Begin
  filename := current_filename;
  saved_line := line;
  saved_lptr := lptr;
  saved_eof := eof;
 End;
  { Essai d'ouvrir le fichier d'inclusion }
 Assign(input, include_filename);
 {$I-}
 Reset(input);
 If IOResult <> 0 Then Begin
  { Restaurez le fichier prÇcÇdent en le rouvrant }
  If include_depth > 0 Then Begin
   Assign(input, include_stack[include_depth].filename);
   Reset(input);
  End;
  Case Language of
   _English: errrpt('Cannot open include file: ' + include_filename);
   {$IFDEF FPC}
   _Germany: errrpt('Kann Include-Datei nicht îffnen: ' + include_filename);
   {$ENDIF}
   Else errrpt('Impossible d''ouvrir le fichier d''inclusion: ' + include_filename);
  End;
  Exit;
 End;
 {$I+}
  { Indiquez que le fichier est inclus pour Çviter l'inclusion circulaire }
 mark_file_included(include_filename);
  { Mise Ö jour de l'Çtat }
 Inc(include_depth);
 current_filename := include_filename;
 eof := 0;
 lptr := 1; { RÇinitialiser le pointeur de ligne pour le nouveau fichier }
 safe_writeln('; Including file: ' + include_filename);
 push_include_file := True;
End;

Function process_include_directive(include_line: String): Boolean;
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
{ FONCTIONS DE GESTION DE DEFINE/MACRO                                         }
{ ============================================================================ }

 { Initialise la systäme define }
Procedure init_defines;Begin
 define_list := nil;     { Initialiser la liste chaånÇe comme vide }
 define_count := 0;
 { N'Çcrivez pas dans le champ de sortir car il n'est peut-àtre pas encore initialisÇ. }
End;

 { Trouver une constante #define par son nom - renvoi un pointeur }
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

 { Enläve une constante #define }
Function remove_define(def_name:String):Boolean;
Var
 current, prev: PDefine;
Begin
 remove_define := False;
 current := define_list;
 prev := nil;
 While current <> nil do Begin
  If current^.in_use and (current^.name = def_name) Then Begin
   { TrouvÇ - Ö retirer de la liste }
   If prev = nil Then define_list := current^.next  { Premier dans la liste }
                 Else prev^.next := current^.next;  { Ce n'est pas le premier dans la liste }
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
Function add_define(def_name,def_value:String):Boolean;
Var
 new_define: PDefine;
Begin
 add_define := False;
  { VÇrifier si la dÇfinition existe dÇjÖ et autoriser sa redÇfinition avec avertissement }
 If find_define(def_name) <> nil Then Begin
  Case Language of
   _English:Begin
     WriteLn('; Warning: Macro ' + def_name + ' redefined (previous definition ignored)');
     { Remove old definition }
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
 { Initialise un nouveau define }
 With new_define^ do Begin
  name := def_name;
  value := def_value;
  in_use := True;
  next := define_list;  { InsÇrer au dÇbut de la liste }
 End;
  { Mise Ö jour de la tàte de liste }
 define_list := new_define;
 Inc(define_count);
 If use_stdout Then WriteLn('; Defined macro: ', def_name, ' = ', def_value)
               Else safe_writeln('; Defined macro: ' + def_name + ' = ' + def_value);
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

 { Traite la directive #define  }
Function process_define_directive(define_line: String): Boolean;
Var
 line_pos, start_pos, end_pos: Integer;
 def_name, def_value: String;
Begin
 process_define_directive := False;
 def_name := '';
 def_value := '';
  { Saute #define et les espaces blancs }
 line_pos := Pos('#define', define_line);
 If line_pos <= 0 Then Exit;
 line_pos := line_pos + 7; { Longueur de '#define' }
  { Saute les espaces blancs }
 While (line_pos <= Length(define_line))and((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
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
  { Saute l'espace blanc avant la valeur }
 While (line_pos <= Length(define_line)) and ((define_line[line_pos] = ' ') or (define_line[line_pos] = #9)) do
  Inc(line_pos);
  { Extraire la valeur (reste de la ligne) }
 If line_pos <= Length(define_line) Then
  def_value := Copy(define_line, line_pos, Length(define_line) - line_pos + 1)
 Else
  def_value := '1'; { Valeur par dÇfaut pour les macros sans valeur explicite }
  { Supprime les espaces blancs de fin de valeur }
 While (Length(def_value) > 0) and
       ((def_value[Length(def_value)] = ' ') or (def_value[Length(def_value)] = #9)) do
  Delete(def_value, Length(def_value), 1);
 { Ajout le define }
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
  { Plusieurs passes pour gÇrer les expansions imbriquÇes }
 Repeat
  changed := False;
  line_pos := 1;
  While line_pos <= Length(result_line) do Begin
   { VÇrifiez si nous sommes au dÇbut d'un identifiant }
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

    { VÇrifiez si ce jeton est une macro dÇfinie }
    define_ptr := find_define(token);
    If define_ptr <> nil Then Begin
     { Remplacez le jeton par sa valeur }
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

 { Effacer toutes les dÇfinitions de la mÇmoire de tas }
Procedure free_defines;
Var
 current, next: PDefine;
Begin
 current := define_list;
 While current <> nil do Begin
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
  result := 0; { Define non trouv√© = 0 }
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
   Else errrpt('Trop de directives #if imbriquÇes (max 32)');
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
   Else errrpt('Trop de directives #ifndef imbriquÇes (max 32)');
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
  is_true := False; { Une branche prÇcÇdente Çtait vraie }
 End;
 skip_code := should_skip_code;
 If use_stdout Then WriteLn('; #elif ', temp_condition)
               Else safe_writeln('; #elif ' + temp_condition);
 process_elif_directive := True;
End;

 { Traiter la directive #else }
Function process_else_directive: Boolean;Begin
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
    Else errrpt('Plusieurs #else dans le màme bloc #if');
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
               Else safe_writeln('; Contexte de compilation conditionnelle effacÇ');
End;

 { Analyser l'accäs aux tableaux avec indexation }
Procedure parse_array_access(array_name: String; var lval: TLVal);
Var
 index_lval: TLVal;
 array_symbol: PSymbol;
 element_size: Integer;
Begin
 { Trouver le symbole du tableau }
 array_symbol := find_symbol(array_name);
 If array_symbol = nil Then Begin
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
 ol('tfr  d,x    ; adresse dans X');
 Case element_size of
  1: ol('ldb  ,x     ; charger octet');
  2: ol('ldd  ,x     ; charger mot');
  Else ol('ldd  ,x     ; charger mot par dÇfaut');
 End;
  { Configurer lval pour le rÇsultat }
 lval.typ := array_symbol^.type_info.base_type;
 lval.indirect := 1; { Valeur chargÇe indirectement }
 lval.constant := False;
 lval.type_info := array_symbol^.type_info;
 lval.type_info.array_size := 0; { Ce n'est plus un tableau mais un ÇlÇment }
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
    (struct_symbol^.type_info.base_type <> cunion) Then Begin
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
 If not symname(member_name)Then Begin
  Case Language of
   _English: errrpt('Expected member name after .');
   {$IFDEF FPC}
   _Germany: errrpt('Erwarteter Mitgliedsname nach .');
   {$ENDIF}
   Else errrpt('Nom de membre attendu apräs .');
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
   Else errrpt('DÇfinition de structure non trouvÇe');
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
  ot('ldd  #');
  outstr(struct_name);
  nl;
 End
  Else
 Begin
  { Ajouter le dÇplacement du membre }
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
  ol('ldd  ,x     ; charger mot par dÇfaut');
 End;
  { Configurer lval pour le rÇsultat }
 With struct_def^.members[member_index] do Begin
  lval.typ := member_type;
  lval.indirect := 1;
  lval.constant := False;
  lval.type_info := type_info;
 End;
End;

 { Analyseur d'expressions primaire avec prise en charger des appels de fonction }
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
    ol_ldd_imm(num);
   End;
  'A'..'Z', 'a'..'z', '_': Begin
    id := parse_identifier;
     { VÇrifiez s'il s'agit d'un appel de fonction }
    If peek_char = '(' Then Begin
     { C'est une fonction d'appel }
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
     { Ceci est une rÇfÇrence de variable }
     If lookup_variable(id, lval) Then
     Begin
      { VÇrifiez s'il s'agit d'un accäs Ö un tableau }
      If peek_char = '[' Then Begin
       { Indexation de tableaux }
       parse_array_access(id, lval);
      End
       Else
      If peek_char = '.' Then Begin
       { Accäs des membres de la structure }
       parse_struct_member_access(id, lval, False);
      End
       Else
      Begin
       { Accäs simple aux variables }
       ol('ldd   ' + id);
      End;
     End
      Else
     Begin
      { Variable non dÇclarÇe }
      lval.symbol := 0;
      lval.typ := cint;
      lval.constant := False;
      ol('ldd   ' + id);
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

{ Analyseur d'expressions unaires }
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
    ol('nega');
    ol('negb');
    ol('sbca #0');
   End;
  '!': Begin
    next_char;
    safe_writeln('; OpÇrateur ! (NOT logique)');
    unary_expression(lval);
    { Convertir en boolÇen: 0 si non-zÇro, 1 si zÇro }
    true_label := getlabel;
    end_label := getlabel;
    ol('tstd');      { Tester D (le rÇsultat de l'expression) }
    ol('beq  L' + IntToStr(true_label)); { Si zÇro, c''est vrai (!0 = 1) }
    ol('ldd  #0');   { Sinon c'est faux (!non_zÇro = 0) }
    ol('bra  L' + IntToStr(end_label));
    prelabel(true_label);
    ol('ldd  #1');   { RÇsultat vrai }
    prelabel(end_label);
   End;
  '~': Begin
    next_char;
    unary_expression(lval);
    ol('coma');
    ol('comb');
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
 If lval.symbol > 0 Then Begin
  ptr_name := get_symbol_name(lval.symbol);
  safe_writeln('; DÇrÇfÇrencement de: ' + ptr_name);
  ol('ldx  ' + ptr_name);  { Charger l'adresse entreposÇe dans le pointeur }
  ol('ldd  ,x');           { Charger la valeur pointÇe }
 End
  Else
 Begin
  safe_writeln('; DÇrÇfÇrencement indirect');
  ol('ldx  ,s++');         { RÇcupÇrer l'adresse depuis la pile }
  ol('ldd  ,x');           { Charger la valeur pointÇe }
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
  ol('ldx  ' + ptr_name);  { Charger l'adresse entreposÇe dans le pointeur }
  ol('ldd  ,x');           { Charger la valeur pointÇe }
 End
  Else
 Begin
  safe_writeln('; DÇrÇfÇrencement indirect');
  ol('ldx  ,s++');         { RÇcupÇrer l'adresse depuis la pile }
  ol('ldd  ,x');           { Charger la valeur pointÇe }
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
 If sym_ptr = nil Then Begin
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
 ol('pshs x'); { Empiler l'adresse }
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
 If not match('sizeof') Then Begin
  Case Language of
   _English: errrpt('Expected sizeof keyword');
   {$IFDEF FPC}
   _Germany: errrpt('Erwartetes sizeof-SchlÅsselwort');
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
  { Analyser le contenu - peut àtre un type ou une expression }
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
 ol_ldd_imm(size_value);
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

 { Multiplicative expression parser }
Procedure multiplicative_expression(var lval: TLVal);
Var
 op: Char;
Begin
 unary_expression(lval);
 While (peek_char = '*') or (peek_char = '/') or (peek_char = '%') do Begin
  op := next_char;
   { L'opÇrande gauche est dÇjÖ sur la pile JVM }
  unary_expression(lval);
   { L'opÇrande droite est maintenant sur la pile JVM }
  Case op of
   '*': Begin
     ol('imul'); { multiplier deux entiers sur une pile }
    End;
   '/': Begin
     ol('idiv'); { diviser deux entiers sur une pile }
    End;
   '%': Begin
     ol('irem'); { reste de deux entiers sur une pile }
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
  { L'opÇrande gauche est dÇjÖ sur la pile JVM }
  multiplicative_expression(lval);
  { L'opÇrande droite est maintenant sur la pile JVM }
  Case op of
   '+': Begin
     ol('iadd'); { ajouter deux entiers sur la pile }
    End;
   '-': Begin
     ol('isub'); { soustraire deux entiers sur la pile }
    End;
  End;
 End;
End;

{ Analyseur d'expressions relationnelles - gäre >, <, >=, <=, ==, != }
Procedure relational_expression(var lval: TLVal);Begin
 additive_expression(lval);
 While True do Begin
  If match('>') Then Begin
   If match('=') Then Begin
    { >= operator }
    safe_writeln('; OpÇrateur >=');
    ol('pshs d');    { Pousser l'opÇrande gauche }
    additive_expression(lval);
    ol('puls x');    { OpÇrande gauche versX }
    ol('cmpx d');    { Compare X avec D }
    ol('bge *+5');   { Branchement si supÇrieur ou Çgale }
    ol('ldd #0');    { RÇsultat false }
    ol('bra *+3');   { Saute le rÇsultat true }
    ol('ldd #1');    { RÇsultat True }
   End
    Else
   Begin
    { OpÇrateur > }
    safe_writeln('; OpÇrateur >');
    ol('pshs d');    { Empile l'opÇrande gauche }
    additive_expression(lval);
    ol('puls x');    { OpÇrande de gauche vers X }
    ol('cmpx d');    { Compare X avec D }
    ol('bgt *+5');   { Branchement si supÇrieur }
    ol('ldd #0');    { RÇsultat False }
    ol('bra *+3');   { Saute le rÇsultat true }
    ol('ldd #1');    { RÇsultat True }
   End;
  End
   Else
  If match('<') Then Begin
   If match('=') Then Begin
    { OpÇrateur <= }
    safe_writeln('; OpÇrateur <=');
    ol('pshs d');    { Empile l'opÇrande gauche }
    additive_expression(lval);
    ol('puls x');    { OpÇrande de gauche vers X }
    ol('cmpx d');    { Compare X avec D }
    ol('ble *+5');   { Branchement si infÇrieur ou Çgale }
    ol('ldd #0');    { RÇsultat False }
    ol('bra *+3');   { Saute le rÇsultat true }
    ol('ldd #1');    { RÇsultat True }
   End
    Else
   Begin
    { OpÇrateur < }
    safe_writeln('; OpÇrateur <');
    ol('pshs d');    { Empile l'opÇrande de gauche }
    additive_expression(lval);
    ol('puls x');    { OpÇrande de gauche vers X }
    ol('cmpx d');    { Compare X avec D }
    ol('blt *+5');   { Branchement si infÇrieur }
    ol('ldd #0');    { RÇsultat False }
    ol('bra *+3');   { Saute le rÇsultat true }
    ol('ldd #1');    { RÇsultat True }
   End;
  End
   Else
  If match('=') and match('=') Then Begin
   { OpÇrateur == }
   safe_writeln('; OpÇrateur ==');
   ol('pshs d');    { Empile l'opÇrande de gauche }
   additive_expression(lval);
   ol('puls x');    { OpÇrande de gauche vers X }
   ol('cmpx d');    { Compare X avec D }
   ol('beq *+5');   { Branchement si Çgale }
   ol('ldd #0');    { RÇsultat False }
   ol('bra *+3');   { Saute le rÇsultat true }
   ol('ldd #1');    { RÇsultat True }
  End
   Else
  If match('!') and match('=') Then Begin
   { OpÇrateur != }
   safe_writeln('; OpÇrateur !=');
   ol('pshs d');    { Empile l'opÇrande de gauche }
   additive_expression(lval);
   ol('puls x');    { OpÇrande de gauche vers X }
   ol('cmpx d');    { Compare X avec D }
   ol('bne *+5');   { Branchement si pas Çgale }
   ol('ldd #0');    { RÇsultat False }
   ol('bra *+3');   { Saute le rÇsultat true }
   ol('ldd #1');    { RÇsultat True }
  End
   Else
  Break; { Pas plus d'opÇrateurs relationnel }
 End;
End;

{ Analyseur d'expression binaire ET - Gäre le & }
Procedure bitwise_and_expression(var lval: TLVal);Begin
 relational_expression(lval);
 While match('&') do Begin
  { VÇrifier que ce n'est pas && }
  If peek_char = '&' Then Begin
   { Reculer car c'est && qui sera traitÇ par logical_and }
   Dec(lptr);
   Break;
  End;
  safe_writeln('; OpÇrateur & (ET binaire)');
  ol('pshs d');    { Empile l'opÇrande de gauche }
  relational_expression(lval);
  ol('tfr  d,x');  { OpÇrande de droite vers X }
  ol('puls d');    { OpÇrande de gauche vers D }
  ol('tfr  a,u');  { Sauvegarde A dans U }
  ol('tfr  b,a');  { B vers A pour l'octet bas }
  ol('anda 1,x');  { Octet bas AND }
  ol('tfr  a,b');  { RÇsultat de l'octet bas vers B }
  ol('tfr  u,a');  { Restaure l'octet haut de U }
  ol('anda 0,x');  { L'octet haut AND }
 End;
End;

{ Analyseur d'expression binaire XOR - Gäre le ^ }
Procedure bitwise_xor_expression(var lval: TLVal);Begin
 bitwise_and_expression(lval);
 While match('^') do Begin
  safe_writeln('; OpÇrateur ^ (XOR binaire)');
  ol('pshs d');    { Empile l'opÇrande de gauche }
  bitwise_and_expression(lval);
  ol('tfr  d,x');  { OpÇrande de droite vers X }
  ol('puls d');    { OpÇrande de gauche vers D }
  ol('tfr  a,u');  { Sauvegarde A dans U }
  ol('tfr  b,a');  { B vers A pour l'octet bas }
  ol('eora 1,x');  { Octet bas XOR }
  ol('tfr  a,b');  { RÇsultat de l'octet bas vers B }
  ol('tfr  u,a');  { Restaure l'octet haut de U }
  ol('eora 0,x');  { Octets haut XOR }
 End;
End;

 { Analyse l'expression binaire OU - Gäre le | }
Procedure bitwise_or_expression(var lval: TLVal);Begin
 bitwise_xor_expression(lval);
 While match('|') do Begin
  { VÇrifier que ce n'est pas || }
  If peek_char = '|' Then Begin
   { Reculer car c'est || Çtant traitÇ par logical_or }
   Dec(lptr);
   Break;
  End;
  safe_writeln('; OpÇrateur | (OU binaire)');
  ol('pshs d');    { Empile l'opÇrande de gauche }
  bitwise_xor_expression(lval);
  ol('tfr  d,x');  { OpÇrande gauche vers X }
  ol('puls d');    { OpÇrande de gauche vers D }
  ol('tfr  a,u');  { Sauvegarde A dans U }
  ol('tfr  b,a');  { B vers A pour l'octet bas }
  ol('ora  1,x');  { Octets bas OR }
  ol('tfr  a,b');  { RÇsultat de l'octet bas vers B }
  ol('tfr  u,a');  { Restaure l'octet haut de U }
  ol('ora  0,x');  { Octet haut OR }
 End;
End;

 { Analyseur d'expression logique ET - Gäre le && }
Procedure logical_and_expression(var lval: TLVal);
Var
 false_label, end_label: Integer;
Begin
 bitwise_or_expression(lval);
 While match('&') and match('&') do Begin
  safe_writeln('; OpÇrateur && (ET logique)');
   { GÇnÇrer les Çtiquettes }
  false_label := getlabel;
  end_label := getlabel;
   { Tester la premiäre expression }
  ol('tstd');
  ot('lbeq ');
  printlabel(false_label);
  nl;
   { êvaluer la deuxiäme expression }
  bitwise_or_expression(lval);
  ol('tstd');
  ot('lbeq ');
  printlabel(false_label);
  nl;
  { Les deux sont vraies - rÇsultat = 1 }
  ol('ldd #1');
  ot('lbra ');
  printlabel(end_label);
  nl;
   { Au moins une est fausse - rÇsultat = 0 }
  prelabel(false_label);
  ol('ldd #0');
   { Fin }
  prelabel(end_label);
 End;
End;

 { Analyse l'expression logique OU - GÇrer le || }
Procedure logical_or_expression(var lval: TLVal);
Var
 true_label, end_label: Integer;
Begin
 logical_and_expression(lval);
 While match('|') and match('|') do Begin
  safe_writeln('; OpÇrateur || (OU logique)');
   { GÇnÇrer les Çtiquettes }
  true_label := getlabel;
  end_label := getlabel;
   { Tester la premiäre expression }
  ol('tstd');
  ot('lbne ');
  printlabel(true_label);
  nl;
  { êvaluer la deuxiäme expression }
  logical_and_expression(lval);
  ol('tstd');
  ot('lbne ');
  printlabel(true_label);
  nl;
  { Les deux sont fausses - rÇsultat = 0 }
  ol('ldd #0');
  ot('lbra ');
  printlabel(end_label);
  nl;
  { Au moins une est vraie - rÇsultat = 1 }
  prelabel(true_label);
  ol('ldd #1');
  { Fin }
  prelabel(end_label);
 End;
End;

{ Analyseur d'expresion conditionnelle - Gäre le ?: (opÇrateur ternaire) }
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
  ol('tstd');         { Tester le rÇsultat de la condition }
  ot('lbeq ');        { Si faux, aller Ö l'expression fausse }
  printlabel(false_label);
  nl;
   { Analyser l'expression vraie }
  safe_writeln('; Expression vraie du ternaire');
  logical_or_expression(true_lval);
   { Sauter l'expression fausse }
  ot('lbra ');
  printlabel(end_label);
  nl;
   { Attendre ':' }
  If not match(':') Then
  Begin
   Case Language of
    _English: errrpt('Expected : in ternary operator');
    {$IFDEF FPC}
    _Germany: errrpt('Erwartete : im ternÑren Operator');
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
  safe_writeln('; Fin opÇrateur ternaire');
 End;
End;

 { Analyseur d'expresion Main }
Function expression_bool(var lval: TLVal):Boolean;Begin
 conditional_expression(lval);
 expression_bool := True;
End;

 { Enveloppe de procÇdure pour la compatibilitÇ ascendante }
Procedure expression(var lval:TLVal);Begin
 expression_bool(lval);
End;

{ Fonctions d'analyse de dÇclaration de variable - dÇplacer apräs l'expression }
{ êtendre l'analyse de la dÇclaration avec un support de type complet }
Function parse_declaration: Boolean;
Var
 base_type, var_type, storage_class: Integer;
 var_name: String;
 lval: TLVal;
 type_info: TTypeInfo;
 save_lptr: Integer;
Begin
 parse_declaration := False;
  { Analyse le premier spÇcificateur de classe d'entreposage }
 storage_class := parse_storage_class_specifier;
  { VÇrifie si c'est une dÇclaration typedef }
 If storage_class = it_typedef_type Then Begin
  { Gäre la dÇclaration typedef }
  If parse_typedef_declaration Then parse_declaration := True;
  Exit;
 End;
  { Analyse le spÇcificateur de type avec les qualificateurs }
 base_type := parse_type_specifier_with_qualifiers(type_info);
 If base_type = -1 Then Exit; { Pas de type valide trouvÇ }
  { Sauvegarde la position pour vÇrifier si la fonction est une fonction ou une variable }
 save_lptr := lptr;
  { Essayer d'analyser comme un dÇclarateur pour obtenir le nom }
 var_type := parse_declarator(var_name, base_type, type_info);
 If var_type = 0 Then Exit;
  { VÇrifie si c'est une fonction de dÇclaration ou de dÇfinition }
 If match('(') Then Begin
  { C'est une fonction - restaure la position et analyse la fonction }
  lptr := save_lptr;
  If parse_function_declaration(base_type) Then parse_declaration := True;
  Exit;
 End;
  { C'est une dÇclaration de variable - passe la classe d'entreposage }
 declare_variable(var_name, var_type, type_info, storage_class);
 parse_declaration := True;
  { VÇrifie pour l'initialisation }
 If match('=') Then Begin
  safe_writeln('; Initializing variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
  expression(lval);
   { VÇrifie le type pour l'initialisation }
  If type_info.is_const Then Begin
   safe_writeln('; const variable initialized');
  End;
   { GÇnäre le type le code d'initialisation appropriÇ }
  Case type_info.size of
   1: Begin
       ol('stb   ' + var_name); { Entrepose l'octet pour char }
      End;
   2: Begin
       ol('std   ' + var_name); { Entrepose le mot pour int/short/pointeurs }
      End;
  Else
   Begin
    ol('std   ' + var_name); { Par dÇfaut vers word }
   End;
  End;
 End
  Else
 Begin
  { VÇrifie la variable const a besoin d'àtre initialisÇ }
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
  { Gäre les dÇclarations de multiple variable }
 While match(',') do Begin
  var_type := parse_declarator(var_name, base_type, type_info);
  If var_type = 0 Then Exit;
  declare_variable(var_name, var_type, type_info, storage_class);
   { VÇrifier pour l'initialisation }
  If match('=') Then Begin
   safe_writeln('; Initializing variable: ' + var_name + ' (' + get_type_name(type_info) + ')');
   expression(lval);
    { GÇnäre le code d'initialisation }
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
   { VÇrifie si la variable const variable nÇcessite une initialisation }
   If type_info.is_const Then Begin
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
 If not match(';') Then errrpt('Expected semicolon after declaration');
End;

{ DÇclarations anticipÇe pour les instructions d'analyse }
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

{ Analyse la structure de contrìle }
Function parse_if_statement: Boolean;
Var
 lval: TLVal;
 else_label, end_label: Integer;
Begin
 parse_if_statement := False;
 If not match('if') Then Exit;
 parse_if_statement := True;
  { Ouverture de parenthäse attendue }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not match('(') Then Begin
  errrpt('Expected ( after if');
  Exit;
 End;
  { Analyse conditionnelle }
 safe_writeln('; IF condition');
 expression_bool(lval);
  { Fermeture de parenthäse attendue }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not match(')') Then Begin
  errrpt('Expected ) after if condition');
  Exit;
 End;
  { GÇnäre un saut conditionnel }
 else_label := getlabel;
 end_label := getlabel;
 ol('tstd');
 ot('lbeq ');
 printlabel(else_label);
 nl;
  { Analse alors l'instruction (peut àtre une simple instruction ou une instruction composÇ) }
 safe_writeln('; IF then block');
  { VÇrifie si c'est nÇcessaire de lire la prochaine ligne pour l'instruction }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If not parse_statement Then Begin
  errrpt('Expected statement after if condition');
  Exit;
 End;
  { VÇrifie la prÇsence de la clause else - elle peut se trouver sur la ligne suivante }
 blanks;
 If (lptr > Length(line)) and (eof = 0) Then readinline;
 If match('else') Then Begin
  { Saute par dessus le bloc else }
  ot('lbra ');
  printlabel(end_label);
  nl;
  { Bloc else }
  prelabel(else_label);
  safe_writeln('; ELSE block');
   { VÇrifiez si nous devons lire la ligne suivante pour l'instruction else }
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

Function parse_while_statement:Boolean;
Var
 lval: TLVal;
 loop_label, end_label: Integer;
Begin
 parse_while_statement := False;
 If not match('while') Then Exit;
 parse_while_statement := True;
  { GÇnäre les Çtiquettes de boucle }
 loop_label := getlabel;
 end_label := getlabel;
  { Empile le contexte de boucle pour break/continue }
 push_loop_context(1, end_label, loop_label);
  { DÇbut de la boucle }
 prelabel(loop_label);
 safe_writeln('; WHILE loop start');
  { Ouverture de parenthäse attendue }
 If not match('(') Then Begin
  errrpt('Expected ( after while');
  Exit;
 End;
  { Analyse la condition }
 safe_writeln('; WHILE condition');
 expression_bool(lval);
 { Fermeture de parenthäse attendue }
 If not match(')') Then errrpt('Expected ) after while condition');
  { GÇnäre le saut de condition }
 ol('tstd');
 ot('lbeq ');
 printlabel(end_label);
 nl;
  { Analyse le corps de la boucle }
 safe_writeln('; WHILE body');
 parse_statement;
  { Saut en arriäre vers la condition }
 ot('lbra ');
 printlabel(loop_label);
 nl;
  { Fin de l'Çtiquette }
 prelabel(end_label);
 safe_writeln('; End WHILE');
  { DÇpile le contexte de boucle }
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
  { GÇnäre les Çtiquettes de boucle }
 condition_label := getlabel;
 increment_label := getlabel;
 end_label := getlabel;
  { Empile le contexte de boucle pour break/continue }
 push_loop_context(2, end_label, increment_label);
 safe_writeln('; FOR loop start');
  { Ouverture de parenthäse attendue }
 If not match('(') Then Begin
  errrpt('Expected ( after for');
  Exit;
 End;
  { Initialisation d'analyse et d'exÇcution }
 safe_writeln('; FOR initialization');
 blanks;
 If ch <> ';' Then Begin
  parse_assignment_statement;  { Parse and execute initialization }
 End;
 If not match(';') Then Begin
  errrpt('Expected ; after for initialization');
  Exit;
 End;
  { Sauvegarde la position pour l'analyse de condition }
 blanks;
 condition_start := lptr;
  { Passez outre la condition pour en trouver la fin }
 While (ch <> ';') and (ch <> #0) Do gch;
 condition_end := lptr;
 If not match(';') Then Begin
  errrpt('Expected ; after for condition');
  Exit;
 End;
  { Analyse la sauvegarde de position pour l'incrÇmentation }
 blanks;
 increment_start := lptr;
  { Ignorez l'incrÇment pour trouver sa fin }
 While (ch <> ')') and (ch <> #0) Do gch;
 increment_end := lptr;
 If not match(')') Then Begin
  errrpt('Expected ) after for increment');
  Exit;
 End;
  { Passer Ö la vÇrification des conditions }
 ot('lbra ');
 printlabel(condition_label);
 nl;
  { êtiquette d'incrÇmentation - oó continue saute Ö }
 prelabel(increment_label);
 safe_writeln('; FOR increment');
  { RÇanalyser et exÇcuter l'incrÇmentation Ö partir de la position enregistrÇe }
 saved_lptr := lptr;       { Sauvegarde la position courante }
 lptr := increment_start;  { DÇfinit le dÇbut de l'incrÇmentation }
 gch;                      { Actualiser le caractäre courant }
 If increment_end > increment_start Then Begin
  parse_assignment_statement;  { Analyse et exÇcute l'incrÇmentation }
 End;
 lptr := saved_lptr;       { Restaure la position }
 gch;                      { Actualiser le caractäre courant }
 ot('lbra ');
 printlabel(condition_label);
 nl;
  { êtiquette de vÇrification de condition }
 prelabel(condition_label);
 safe_writeln('; FOR condition check');
 { RÇanalyser la condition Ö partir de la position enregistrÇe }
 saved_lptr := lptr;       { Sauvegarde la position courante }
 lptr := condition_start;  { DÇfinir la condition de dÇmarrage }
 gch;                      { Actualiser le caractäre actuel }
 If condition_end > condition_start Then Begin
  expression_bool(lval);   { Analyse la condition }
 End
  Else
 Begin
  { Pas de condition = boucle infinie }
  ot('ldd  #1');
  nl;
 End;
 lptr := saved_lptr;       { Restaure la position }
 gch;                      { Actualiser le caractäre courant }
  { GÇnÇrer un saut conditionnel Ö la fin si faux }
 ol('tstd');
 ot('lbeq ');
 printlabel(end_label);
 nl;
  { Analyse le corps de la boucle }
 safe_writeln('; FOR body');
 parse_statement;
  { Saut vers l'incrÇmentation }
 ot('lbra ');
 printlabel(increment_label);
 nl;
  { Fin d'Çtiquette - oó break faut le saut }
 prelabel(end_label);
 safe_writeln('; End FOR');
  { DÇpile le contexte de boucle }
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
  { GÇnäre les Çtiquttes de boucle }
 loop_label := getlabel;
 condition_label := getlabel;
 end_label := getlabel;
 { Empile le contexte de boucle pour break/continue }
 { push_loop_context(3, end_label, condition_label); }
 { DÇbut de boucle }
 prelabel(loop_label);
 safe_writeln('; DO-WHILE loop start');
  { Analyse le corps de la boucle }
 parse_statement;
  { while attendue }
 If not match('while') Then Begin
  errrpt('Expected while after do body');
  Exit;
 End;
  { Ouverture de parenthäse attendue }
 If not match('(') Then Begin
  errrpt('Expected ( after while');
  Exit;
 End;
  { Analyse la condition }
 prelabel(condition_label);
 safe_writeln('; DO-WHILE condition');
 expression_bool(lval);
  { Fermeture de parenthäse attendue }
 If not match(')') Then errrpt('Expected ) after while condition');
  { Point-virgule attendue }
 If not match(';') Then errrpt('Expected ; after do-while');
  { GÇnäre un saut conditionnel en arriäre }
 ol('tstd');
 ot('lbne ');
 printlabel(loop_label);
 nl;
  { Fin d'Çtiquette }
 prelabel(end_label);
 safe_writeln('; End DO-WHILE');
 { DÇpile le contexte de boucle }
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
  { VÇrifier la valeur de retour }
 If not match(';') Then Begin
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
  { GÇnäre le code de retour }
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
  { Point-virgule attendue }
 If not match(';') Then errrpt('Expected ; after break');
  { RÇcupÇrer l'Çtiquette de pause actuelle Ö partir du contexte de boucle }
 break_label := get_current_break_label;
 If break_label = -1 Then Begin
  errrpt('break statement not within a loop');
  Exit;
 End;
  { Passer Ö la fin de la boucle actuelle }
 ot('lbra ');
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
 { Point-virgule attendue }
 If not match(';') Then errrpt('Expected ; after continue');
 { RÇcupÇrer l'Çtiquette continue actuelle Ö partir du contexte de boucle }
 continue_label := get_current_continue_label;
 If continue_label = -1 Then Begin
  errrpt('continue statement not within a loop');
  Exit;
 End;
  { Saute Ö la condition de la boucle }
 ot('lbra ');
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
   Else errrpt('Nom d''Çtiquette attendu apräs goto');
  End;
  Exit;
 End;
  { Attendre point-virgule }
 If not match(';') Then errrpt('Expected ; after goto statement');
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
   Else errrpt('( attendu apr√®s switch');
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
   Else errrpt(') attendu apr√®s expression switch');
  End;
  Exit;
 End;
  { Commencer le switch }
 If not begin_switch_statement(switch_expr_type) Then Exit;
  { Sauvegarder la valeur de l'expression pour comparaison }
 ol('std  switch_temp ; sauver valeur switch');
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
   Else errrpt(': attendu apr√®s default');
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

 { Analyse l'instruction composÇe }
Function parse_compound_statement:Boolean;Begin
 parse_compound_statement := False;
 If not match('{') Then Exit;
 parse_compound_statement := True;
 safe_writeln('; Compound statement start');
  { Analyse les instructions jusqu'Ö l'accolade fermante }
 Repeat
  { VÇrifier si nous devons lire une nouvelle ligne }
  blanks;
  If (lptr > Length(line)) or (Length(line) = 0) Then Begin
   If not readinline Then Break;
   lptr := 1;
  End;
   { VÇrifie la prÇsence d'une accolade de fermeture }
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
   { Passez Ö la ligne suivante pour Çviter les boucles infinies }
   If not readinline Then Break;
   lptr := 1;
  End;
 Until False;
 safe_writeln('; Compound statement end');
End;

{ Analyse des instructions d'expression }
Function parse_expression_statement: Boolean;
Var
 lval: TLVal;
 save_lptr: Integer;
Begin
 parse_expression_statement := False;
  { VÇrifier si l'instruction est vide (ne contient qu'un point-virgule) }
 If match(';') Then Begin
  parse_expression_statement := True;
  safe_writeln('; Empty statement');
  Exit;
 End;
  { VÇrifiez s'il y a quelque chose qui ressemble Ö une expression }
 save_lptr := lptr;
 If not (is_digit(peek_char) or is_alpha(peek_char) or (peek_char = '(')) Then Exit;
  { Essayez d'analyse l'expression }
 expression_bool(lval);
 parse_expression_statement := True;
  { Point-virgule attendue }
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
 If array_symbol = nil Then Begin
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
  {$IFDEF FPC}
  Case Language of
   _English: errrpt('Variable is not an array: ' + array_name);
   _Germany: errrpt('Variable ist kein Array: ' + array_name);
   Else
   {$ENDIF}
   errrpt('La variable n''est pas un tableau: ' + array_name);
  {$IFDEF FPC}
  End;
  {$ENDIF}
  Exit;
 End;
 safe_writeln('; Assignation Ö ÇlÇment de tableau ' + array_name);
  { Analyser l'expression d'index (le '[' a dÇjÖ ÇtÇ consommÇ) }
 additive_expression(index_lval);
  { Consommer ']' }
 If not match(']')Then Begin
  {$IFDEF FPC}
  Case Language of
   _English: errrpt('Expected ] after array index');
   _Germany: errrpt('Erwartete ] nach Array-Index');
   Else
   {$ENDIF}
    errrpt('] attendu apr√®s l''index du tableau');
  {$IFDEF FPC}
  End;
  {$ENDIF}
  Exit;
 End;
  { Consommer '=' }
 If not match('=') Then Begin
  {$IFDEF FPC}
  Case Language of
   _English: errrpt('Expected = in array assignment');
   _Germany: errrpt('Erwartete = in Array-Zuweisung');
   Else
   {$ENDIF}
   errrpt('= attendu dans l''assignation de tableau');
  {$IFDEF FPC}
  End;
  {$ENDIF}
  Exit;
 End;
  { Sauvegarder l'index sur la pile }
 ol('pshs d      ; sauvegarder index sur pile');
  { Analyser l'expression du cìtÇ droit }
 expression(right_lval);
  { Sauvegarder la valeur Ö assigner }
 ol('pshs d      ; sauvegarder valeur Ö assigner');
  { RÇcupÇrer l'index }
 ol('puls x      ; rÇcupÇrer valeur dans X');
 ol('puls d      ; rÇcupÇrer index dans D');
  { Calculer la taille d'un ÇlÇment }
 element_size := get_type_size(array_symbol^.type_info.base_type);
  { Si la taille d'ÇlÇment n'est pas 1, multiplier l'index }
 If element_size > 1 Then Begin
  safe_writeln('; Multiplier index par taille ÇlÇment');
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
    { Multiplication gÇnÇrale }
    ol('bipush ' + IntToStr(element_size));
    ol('imul     ; multiplication JVM');
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
  1: ol('stb  ,y     ; stocker octet');
  2: ol('std  ,y     ; stocker mot');
 Else
  ol('std  ,y     ; stocker mot par dÇfaut');
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
  { Essayez d'analyser l'identifiant }
 If symname(var_name) Then Begin
  blanks;
   { VÇrifiez s'il s'agit d'un accäs Ö un tableau }
  If match('[') Then Begin
   { Affectation des ÇlÇments du tableau: array[index] = value }
   parse_array_assignment(var_name);
   parse_assignment_statement := True;
  End
   Else
  If match('=') Then Begin
    { Il s'agit d'une simple affectation de variable }
   blanks;
    { Recherche une variable }
   If lookup_variable(var_name, lval) Then Begin
    { VÇrifie si la variable est const }
    If lval.type_info.is_const Then
    Begin
     {$IFDEF FPC}
     Case Language of
      _English: errrpt('Cannot assign to const variable: ' + var_name);
      _Germany: errrpt('Kann const Variable nicht zuweisen: ' + var_name);
      Else
      {$ENDIF}
       errrpt('Impossible d''assigner Ö la variable const: ' + var_name);
     {$IFDEF FPC}
      End;
     {$ENDIF}
     Exit;
    End;
     { Analyser l'expression du cìtÇ droit }
    expression(right_lval);
     { GÇnÇrer le code d'affectation }
    ol('std   ' + var_name);
    safe_writeln('; Assignment to variable: ' + var_name);
    parse_assignment_statement := True;
   End;
  End
   Else
  Begin
   { Il ne s'agit pas d'une affectation, rÇtablir la position }
   lptr := save_lptr;
  End;
 End;
End;

 { Analyseur d'instruction Main }
Function parse_statement:Boolean;Begin
 parse_statement := False;
  { Saute les lignes vides et les commentaires }
 blanks;
 If Length(line) = 0 Then Begin
  parse_statement := True;
  Exit;
 End;
  { Essai diffÇrent types d'instructions }
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
 If use_stdout Then Begin
  WriteLn('; ', VERSION);
  WriteLn('');
  WriteLn('.class public Main');
  WriteLn('.super java/lang/Object');
  WriteLn('');
  WriteLn('.method public <init>()V');
  WriteLn(#9, 'aload_0');
  WriteLn(#9, 'invokespecial java/lang/Object/<init>()V');
  WriteLn(#9, 'return');
  WriteLn('.end method');
  WriteLn('');
  WriteLn('.method public static main([Ljava/lang/String;)V');
  WriteLn(#9, '.limit stack 100');
  WriteLn(#9, '.limit locals 100');
 End
  Else
 Begin
  safe_writeln('; ' + VERSION);
  safe_writeln('');
  safe_writeln('.class public Main');
  safe_writeln('.super java/lang/Object');
  safe_writeln('');
  safe_writeln('.method public <init>()V');
  safe_writeln(#9 + 'aload_0');
  safe_writeln(#9 + 'invokespecial java/lang/Object/<init>()V');
  safe_writeln(#9 + 'return');
  safe_writeln('.end method');
  safe_writeln('');
  safe_writeln('.method public static main([Ljava/lang/String;)V');
  safe_writeln(#9 + '.limit stack 100');
  safe_writeln(#9 + '.limit locals 100');
 End;
End;

Procedure trailer;Begin
  { Appliquez les optimisations si activÇ }
 If optimize > OPT_NONE Then Begin
  optimize_code;
  output_optimized_instructions;
  free_opt_instructions; { LibÇrer la mÇmoire des instructions d'optimisation }
 End;
 If use_stdout Then Begin
  WriteLn(#9, 'return');
  WriteLn('.end method');
 End
 Else
 Begin
  safe_writeln(#9 + 'return');
  safe_writeln('.end method');
 End;
End;

Procedure closeout;Begin
 If not use_stdout Then Close(output);
End;

Procedure errrptsummary;Begin
 WriteLn;
 WriteLn(errcnt, ' error(s) in compilation.');
End;

 { Analyse syntaxique amÇliorÇe avec dÇclarations de variables, structures de contrìle et analyseur d'expression }
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
  If IOResult <> 0 Then Begin
   eof := 1;
   Break;
  End;
  {$I+}
   { Traitement de simple commentaire }
  If match('/*') Then Begin
   While (not match('*/')) and (eof = 0) do readinline;
   Continue;
  End;
   { Traiter les directives du prÇprocesseur AVANT l'expansion macro }
  If match('#') Then Begin
   If match('include') Then Begin
    { Traite la directive #include }
    If not should_skip_code Then Begin
     If process_include_directive(line) Then Begin
       { Succäs de include - RÇinitialise le pointeur de ligne et continue avec le fichier d'inclusion }
      lptr := Length(line) + 1; { Force l'appel Ö readinline pour tout nouveau fichier }
      Continue;
     End
      Else
     Begin
      { Erreur dÇjÖ signalÇe, ignorez cette ligne }
      Continue;
     End;
    End
     Else
    Begin
      { Ignorer l'inclusion dans le bloc conditionnel }
     Continue;
    End;
   End
    Else
   If match('define') Then Begin
    { Traite la directive #define }
    If not should_skip_code Then Begin
     If process_define_directive(line) Then
      Continue  { Continue avec la prochaine ligne }
      Else
     Begin
      { Erreur dÇjÖ signalÇe, ignorez cette ligne }
      Continue;
     End;
    End
    Else
    Begin
     { Ignorer la dÇfinition dans le bloc conditionnel }
     Continue;
    End;
   End
   Else If match('if ') Then
   Begin
    { Traite la directive #if }
    blanks;
    process_if_directive(Copy(line, lptr, 255));
    Continue;
   End
   Else If match('ifdef ') Then
   Begin
    { Traite la directive #ifdef }
    blanks;
    process_ifdef_directive(Copy(line, lptr, 255));
    Continue;
   End
   Else If match('ifndef ') Then
   Begin
    { Traite la directive #ifndef }
    blanks;
    process_ifndef_directive(Copy(line, lptr, 255));
    Continue;
   End
   Else If match('elif ') Then
   Begin
    { Traite la directive #elif }
    blanks;
    process_elif_directive(Copy(line, lptr, 255));
    Continue;
   End
   Else If match('else') Then
   Begin
    { Traite la directive #else }
    process_else_directive;
    Continue;
   End
   Else If match('endif') Then
   Begin
    { Traite la directive #endif }
    process_endif_directive;
    Continue;
   End
   Else
   Begin
    { Autre directives de prÇprocesseur - saute pour le moment }
    safe_writeln('; Skipping preprocessor directive: ' + line);
    Continue;
   End;
  End;
   { VÇrifier si nous devons ignorer du code en raison d'une compilation conditionnelle }
  If should_skip_code Then Begin
   { Saute cette ligne complätement }
   Continue;
  End;
   { Appliquer l'expansion de macro Ö ligne APRES le traitemetn conditionnel }
  expanded_line := expand_macros(line);
  If expanded_line <> line Then
  Begin
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
   { Essayez d'analyser comme une instruction (incluant les dÇclarations et les structures de contrìle) }
  If parse_statement Then Begin
   safe_writeln('; Statement processed');
   Continue;
  End;
   { Solution de repli : Analyser les identifiants et les expressions pour assurer la rÇtrocompatibilitÇ }
  lptr := 1;
  If symname(sname) Then Begin
   safe_writeln('; Identifier: ' + sname);
    { VÇrifier pour l'affectation }
   blanks;
   If match('=') Then Begin
    safe_writeln('; Assignment to ' + sname);
    blanks;
     { Recherchez la variable dans le tableau des symboles }
    If lookup_variable(sname, lval) Then Begin
     { VÇrifiez si la variable est constante et empàcher son affectation }
     If lval.type_info.is_const Then
     Begin
      {$IFDEF FPC}
      Case Language of
       _English: errrpt('Cannot assign to const variable: ' + sname);
       _Germany: errrpt('Kann const Variable nicht zuweisen: ' + sname);
       Else
       {$ENDIF}
       errrpt('Impossible d''assigner Ö la variable const: ' + sname);
       {$IFDEF FPC}
       End;
      {$ENDIF}
     End
     Else
     Begin
      safe_writeln('; Assignment to variable: ' + sname);
       { Utilise l'analyseur d'expression pour le cìtÇ droite }
      expression(right_lval);
       { Entrepose le rÇsultat dans la variable }
      ol('std   ' + sname);
     End;
    End;
   End
   Else
   Begin
    { Charge la variable }
    If lookup_variable(sname, lval) Then
    Begin
     ot('ldd  ');
     outstr(sname);
     nl;
    End;
   End;
   Continue;
  End;
   { Essayez d'analyser comme une expression }
  lptr := 1;
  blanks;
  If (peek_char >= '0') and (peek_char <= '9') Then Begin
   safe_writeln('; Expression detected');
   expression(lval);
   Continue;
  End;
  { DÇtection de fonction simple }
  If Pos('(', line) > 0 Then Begin
   safe_writeln('; Function found: ' + line);
   ol('nop ; placeholder for function');
  End;
   { Afficher le contenu restant sous forme de commentaire }
  If Length(line) > 0 Then Begin
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
  {$IFDEF FPC}
  Case Language of
   _English:Begin
    WriteLn('CCJASMIN - This command allows you to launch the C compiler for ',
            'the Jasmin (JVM).');
    WriteLn;
    WriteLn('usage: CCJASMIN infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options:');
    WriteLn('  -O0    No optimization (default)');
    WriteLn('  -O1    Basic optimizations (peephole, constant folding)');
    WriteLn('  -O2    Advanced optimizations (+ dead code, jumps)');
    WriteLn('  -O3    Aggressive optimizations (all)');
   End;
   _Germany:Begin
    WriteLn('CCJASMIN - Dieser Befehl ermîglicht es, den C-Compiler fÅr ',
            'den Jasmin-Mikroprozessor zu starten.');
    WriteLn;
    WriteLn('Syntax: CCJASMIN infile.c [outfile] [-optionen]');
    WriteLn;
    WriteLn('Optionen:');
    WriteLn('  -O0    Keine Optimierung (Standard)');
    WriteLn('  -O1    Grundlegende Optimierungen (Guckloch, Konstantenfaltung)');
    WriteLn('  -O2    Erweiterte Optimierungen (+ toter Code, SprÅnge)');
    WriteLn('  -O3    Aggressive Optimierungen (alle)');
   End;
   Else
   {$ENDIF}
   Begin
    WriteLn('CCJASMIN - Cette commande permet de lancer le compilateur C pour ',
            'le JASMIN (JVM).');
    WriteLn;
    WriteLn('Syntaxe : CCJASMIN infile.c [outfile] [-options]');
    WriteLn;
    WriteLn('Options :');
    WriteLn('  -O0    Pas d''optimisation (valeur par dÇfaut)');
    WriteLn('  -O1    Optimisations de base (oeilleon, pliage constant)');
    WriteLn('  -O2    Optimisations avancÇes (code mort, sauts)');
    WriteLn('  -O3    Optimisations aggressives (toutes)');
   End;
  {$IFDEF FPC}
  End;
  {$ENDIF}
  Halt(1);
 End;
  { Initialise les variables - symtab n'est plus nÇcessaire }
 { FillChar(symtab, SizeOf(symtab), 0); -- Vieille table de symbole a enlever }
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
 { Initialise le systäme de fichier include }
 include_depth := 0;
 current_filename := '';
 { Initialise le systäme define }
 init_defines;
 { Initialise la table de symbole basÇ sur la mÇmoire de tas }
 init_symbols;
  { Compile le corps de main }
 nxtlab := 0;
 kill;
 WriteLn('CCJASMIN - Compilateur C pour JASMIN V1.01');
 WriteLn;
 optimize := OPT_NONE;
 ctext := NO;
 { Analyse les paramätres de la ligne de commande }
 For i := 1 to ParamCount do Begin
  param := ParamStr(i);
  If param = '-O0' Then optimize := OPT_NONE
  Else If param = '-O1' Then optimize := OPT_BASIC
  Else If param = '-O2' Then optimize := OPT_ADVANCED
  Else If param = '-O3' Then optimize := OPT_AGGRESSIVE;
 End;
  { Ouvre le fichier d'entrÇe avec la vÇrification d'erreur }
 Assign(input, ParamStr(1));
 {$I-}
 Reset(input);
 If IOResult <> 0 Then Begin
  WriteLn('Error: Cannot open input file: ', ParamStr(1));
  Halt(1);
 End;
 {$I+}
 current_filename := ParamStr(1); { DÇfinir le nom de fichier initiale pour le systäme d'inclusion }
 WriteLn('Compile le fichier Source: ', ParamStr(1));
 { Initialise les variables global }
 eof := 0;
 errcnt := 0;
 lptr := 1;
 line := '';
 nextlabel := 0;
 use_stdout := True; { Initialize tìt - peut àtre modifiÇ ulltÇrieurement }
  { Initialiser la table des symboles basÇe sur la mÇmoire de tas }
 init_symbols;
  { Initialiser la tables des defines }
 init_defines;
  { Initialise le systäme d'inclusion }
 init_inclusion_system;
  { Initialise le systäme de conditions }
 init_conditions;
  { Initialise la table de contrìle de flux }
 init_goto_table;
 init_switch_table;
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
   { Message supprimÇ temporairement }
   { WriteLn('Generating asm file: ', param); }
   use_stdout := False;
  End
   Else
  Begin
   { Ne pas assigner de sortie Ö la sortie; utiliser plutìt un drapeau }
   {$IFDEF FPC}
   Case Language of
    _English:WriteLn('Using console screen for output.');
    Else
   {$ENDIF}
    WriteLn('Affichage de la sortie sur la console.');
   {$IFDEF FPC}
   End;
   {$ENDIF}
   use_stdout := True;
  End;
 End
  Else
 Begin
   { Ne pas assigner de sortie Ö la sortie; utiliser plutìt un drapeau }
  {$IFDEF FPC}
  Case Language of
   _English:WriteLn('Using console screen for output.');
   Else
  {$ENDIF}
   WriteLn('Affichage de la sortie sur la console.');
  {$IFDEF FPC}
  End;
  {$ENDIF}
  use_stdout := True;
 End;
  { Initialisation du systäme d'optimisation }
 init_optimization;
 { Initialise la pile de contexte boucle }
 loop_depth := 0;
 { Initialise la table d'information de type }
 type_info_count := 0;
  { Initialisaton du systäme de gestion des fonctions }
 init_functions;
  { Initialisation du systäme de gestion des structures }
 init_structs;
 { Initialisation de la table des Çtiquettes goto }
 init_goto_table;
 asmtype := ASJASMIN;
 header;          { Code d'introduction }
 parse;           { Analyse toutes les entrÇe }
 trailer;         { Code de suivi }
 free_defines;    { Libäre la mÇmoire de define de la mÇmoire de tas }
 free_conditions; { Libäre le systäme de conditions }
 free_symbols;    { Libäre la table de symbole de la mÇmoire de tas }
 free_structs;    { Libäre les dÇfinitions de struct de la mÇmoire de tas }
 closeout;        { Fermer la sortie }
 errrptsummary;   { RÇsumer les erreurs }
END.
