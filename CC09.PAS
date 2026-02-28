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
 VERSION = 'Compilateur C V1.1';
 YES = 1;
 NO = 0;

  { Param�tres de la table de symbole }
 symsiz = 14;
 symtbsz = {$IFDEF FPC}8008{$ELSE}250{$ENDIF};
 numglbs = 512;
 MASKGLBS = 511;
 namesize = 9;
 namemax = 8;

  { D�placement du format d'entr�e de la table des symboles }
 name = 0;
 ident = 9;
 ctype = 10;
 storage = 11;
 offset = 12;
 offsize = 2;

  { Types d'identificateurs }
 it_variable = 1;
 it_array = 2;
 it_pointer = 3;
 it_function = 4;
 it_struct_type = 5;
 it_union_type = 6;
 it_typedef_type = 7;

  { Types de donn�es }
 cvoid = 1;
 cchar = 2;
 cuchar = 3;
 cshort = 4;
 cushort = 5;
 cint = 6;
 cuint = 7;
 clong = 8;
 culong = 9;
 cfloat = 10;
 cdouble = 11;
 cpointer = 12;
 carray = 13;
 cstruct = 14;
 cunion = 15;

  { Taille du type en octets }
 sizeof_void = 0;
 sizeof_char = 1;
 sizeof_short = 2;
 sizeof_int = 2;
 sizeof_long = 4;
 sizeof_float = 4;
 sizeof_double = 8;
 sizeof_pointer = 2;

  { Classes d'entreposage }
 statik = 1;
 stkloc = 2;
 CEXTERNAL = 3;
 automatic = 4;

  { Types d'instructions }
 streturn = 3;

  { Types d''assembleurs }
 AS6809 = 1;
 AS9 = 2;

  { Niveau d''opimisations }
 OPT_NONE = 0;
 OPT_BASIC = 1;
 OPT_ADVANCED = 2;
 OPT_AGGRESSIVE = 3;

 { Option d'optimisation }
 OPT_PEEPHOLE = 1;      { Optimisations pour analyse de code }
 OPT_DEAD_CODE = 2;     { �limination du code mort }
 OPT_CONSTANT_FOLD = 4; { Simplification des constantes }
 OPT_STRENGTH_RED = 8;  { R�duction de la complexit� }
 OPT_REGISTER = 16;     { Allocation de registres }
 OPT_JUMP = 32;         { Optimisations de sauts }

 { Ligne d''entr�e }
 linesize = 80;
 linemax = linesize - 1;

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
  opcode: String[10];     { Mn�monique d'instruction }
  operand: String[20];    { Op�rande }
  comment: String[40];    { Commentaire }
  line_number: Integer;   { Num�ro de ligne source }
  can_eliminate: Boolean; { Peut �tre supprim� lors de la suppression du code mort }
 End;

 { Optimisation de contexte }
 TOptContext = Record
  level: Integer;                                                              { Niveau d'optimisation }
  flags: Integer;                                                              { Drapeaux d'optimisation }
  instructions: Array[0..{$IFDEF FPC}999{$ELSE}79{$ENDIF}] of TOptInstruction; { Tampon d'instruction }
  inst_count: Integer;                                                         { Nombre d'instructions }
  last_result_reg: String; { Dernier registre utilis� pour le r�sultat }
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

 { Loop context structure for break/continue support }
 TLoopContext = Record
  loop_type: Integer;     { 1=while, 2=for, 3=do-while }
  break_label: Integer;   { Label to jump for break }
  continue_label: Integer; { Label to jump for continue }
 End;

 { Include file management }
 TIncludeFile = Record
  filename: String{$IFNDEF FPC}[80]{$ENDIF};
  saved_line: TLine;
  saved_lptr: Integer;
  saved_eof: Integer;
 End;

 { Macro/Define management - using static arrays instead of heap }
 TDefine = Record
  name: String;
  value: String;
  in_use: Boolean;
 End;

 TDefineTable = Array[0..{$IFDEF FPC}99{$ELSE}49{$ENDIF}] of TDefine; { Max 100 defines }

 { Symbol table using heap memory instead of data segment }
 PSymbol = ^TSymbol;
 TSymbol = Record
  name: String{$IFNDEF FPC}[80]{$ENDIF};
  ident: Integer;    { it_variable, it_function, etc. }
  ctype: Integer;    { Type of symbol }
  storage: Integer;  { Storage class }
  offset_value: Integer; { Offset or value }
  type_info: TTypeInfo; { Extended type information }
  next: PSymbol;     { Next symbol in chain }
 End;

  { Table de fonction }
 TFunctionTable = Array[0..{$IFDEF FPC}99{$ELSE}50{$ENDIF}] of TFunction;

Var
 Language:(_French,_English,_Germany,_Italian,_Spain,_Albanian,_Portuguese,_Swedish,_Danish,_Japanese);
 TmpLanguage:String;
 { Tables de symbole }
 { Legacy variables - kept for compatibility with some calculations }
 glbptr, locptr: Integer;

 { New heap-based symbol table }
 symbol_list: PSymbol;    { Head of symbol list }
 symbol_count: Integer;   { Counter for statistics }

 { Gestion de fonction }
 function_table: TFunctionTable;
 function_count: Integer;
 current_function: Integer;  { Index of currently parsing function }
 call_stack_depth: Integer; { Current call depth }

 { Contexte d'optimisation }
 opt_context: TOptContext;

 { Loop context stack for break/continue }
 loop_stack: Array[0..31] of TLoopContext;
 loop_depth: Integer;

 { Include file stack }
 include_stack: Array[0..9] of TIncludeFile;  { Max 10 levels of inclusion }
 include_depth: Integer;
 current_filename: String;

 { Define/Macro management - using static table }
 define_table: TDefineTable;
 define_count: Integer; { Number of defines currently in use }

 { Extended type information - now stored directly in symbols }
 { type_info_table: Array[1..SYMTBSZ] of TTypeInfo;  -- No longer needed }
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

{ Forward declarations }
Procedure init_type_info(var type_info: TTypeInfo); forward;

{ Legacy functions - no longer needed with heap-based symbol table }
Function startglb: Integer;Begin
 startglb := 1; { Start at 1 to reserve 0 as "not found" value }
End;

Function endglb: Integer;Begin
 endglb := 1000; { Dummy value for compatibility }
End;

Function startloc: Integer;Begin
 startloc := 1000; { Dummy value for compatibility }
End;

Function endloc: Integer;Begin
 endloc := 2000; { Dummy value for compatibility }
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

{ Safe file writing functions }
Function is_output_ready: Boolean;
Begin
 If use_stdout Then
  is_output_ready := True
 Else
 Begin
  {$I-}
  Write(output, ''); { Test write }
  is_output_ready := (IOResult = 0);
  {$I+}
 End;
End;

Procedure safe_write(s: String);
Begin
 If is_output_ready Then
 Begin
  If use_stdout Then Write(s)
                Else Write(output, s);
 End;
End;

Procedure safe_writeln(s: String);
Begin
 If is_output_ready Then
 Begin
  If use_stdout Then WriteLn(s)
                Else WriteLn(output, s);
 End;
End;

Procedure nl;Begin
 safe_writeln('');
End;

Procedure ol(s:String);Begin
 safe_writeln(#9 + s);
End;

 { �crire la ligne dans la sortie avec routage conditionnel }
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

 { Code generation }
Procedure ot(s: String);Begin
 safe_write(#9 + s + ' '); { TAB alors chaine de caractères avec espace }
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

{ Loop context management for break/continue support }
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
 
 { Defensive check - ensure loop_depth is initialized }
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
 If use_stdout Then Write(Chr(b))
               Else Write(output, Chr(b));
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
{ NEW HEAP-BASED SYMBOL TABLE FUNCTIONS                                       }
{ ============================================================================ }

{ Initialize the heap-based symbol table }
Procedure init_symbols;
Begin
 symbol_list := nil;
 symbol_count := 0;
End;

{ Find a symbol in the heap-based symbol table }
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

{ Add a symbol to the heap-based symbol table }
Function add_symbol(sname: String; id_type: Integer; sym_type: Integer; stor_class: Integer; offset_val: Integer): PSymbol;
Var
 new_symbol: PSymbol;
Begin
 add_symbol := nil;
 
 { Check if symbol already exists }
 If find_symbol(sname) <> nil Then
 Begin
  { Symbol already exists }
  Exit;
 End;
 
 { Allocate memory on heap }
 New(new_symbol);
 If new_symbol = nil Then
 Begin
  { Out of memory }
  Exit;
 End;
 
 { Initialize the new symbol }
 With new_symbol^ do
 Begin
  name := sname;
  ident := id_type;
  ctype := sym_type;
  storage := stor_class;
  offset_value := offset_val;
  init_type_info(type_info);
  type_info.base_type := sym_type;
  next := symbol_list;  { Insert at beginning of list }
 End;
 
 { Update list head }
 symbol_list := new_symbol;
 Inc(symbol_count);
 
 add_symbol := new_symbol;
End;

{ Enhanced addsym function using heap }
Function addsym_heap(sname: String; typ: Integer; storage: Integer; offset_value: Integer): PSymbol;
Begin
 addsym_heap := add_symbol(sname, it_variable, typ, storage, offset_value);
End;

{ Enhanced findsym function using heap }
Function findsym_heap(sname: String): PSymbol;
Begin
 findsym_heap := find_symbol(sname);
End;

{ Free all symbols from heap memory }
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
               Else WriteLn(output, '; Freed ', symbol_count, ' symbols from heap');
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
  Else get_type_size := sizeof_int; { Par d�faut }
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

{ V�rifiez si deux types sont compatibles }
Function types_compatible(var type1, type2: TTypeInfo): Boolean;Begin
 types_compatible := (type1.base_type = type2.base_type) and
                    (type1.pointer_level = type2.pointer_level) and
                    (type1.is_unsigned = type2.is_unsigned);
End;

{ V�rifier si le type peut �tre converti en un autre }
Function can_convert_type(var from_type, to_type: TTypeInfo):Boolean;Begin
  { Les pointeurs peuvent �tre convertis en pointeurs }
 If (from_type.pointer_level > 0) and (to_type.pointer_level > 0) Then Begin
  can_convert_type := True;
  Exit;
 End;
  { Les types num�riques peuvent g�n�ralement �tre convertis }
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

 { R�cup�rer le nom du type sous forme de chaine de caract�res pour les messages de d�bogage/d'erreur }
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
  { Ajouter des ast�ristiques de pointeur }
 For i := 1 to type_info.pointer_level do base_name := base_name + '*';
  { Ajouter la notation de tableau }
 If type_info.array_size > 0 Then Begin
  Str(type_info.array_size, temp_str);
  base_name := base_name + '[' + temp_str + ']';
 End;
 get_type_name := base_name;
End;

 { G�n�rer le code assembleur pour la conversion de type }
Procedure generate_type_conversion(var from_type, to_type: TTypeInfo);Begin
 Case Language of
  _English:WriteLn(output, '; Type conversion from ', get_type_name(from_type),' to ', get_type_name(to_type));
  Else WriteLn(output, '; Conversion de type de ', get_type_name(from_type),' � ', get_type_name(to_type));
 End;
 { G�rer la conversion char en int }
 If (from_type.base_type = cchar) and (to_type.base_type = cint) Then Begin
  If from_type.is_unsigned Then Begin
   ol('clra   ; zero extend unsigned char');
  End
  Else
  Begin
   ol('sex    ; sign extend signed char');
  End;
 End
  { G�rer la conversion int vers char }
  Else
 If (from_type.base_type = cint) and (to_type.base_type = cchar) Then Begin
  ol('tfr  d,x ; keep only low byte');
  ol('tfr  b,a');
  ol('clrb');
 End;
  { Ajoutez des conversions suppl�mentaires si n�cessaires }
End;

{ ============================================================================ }
{ FONCTIONS D'OPTIMISATION DU CODE                                             }
{ ============================================================================ }

 { Initialiser le contexte d'optimisation }
Procedure init_optimization;Begin
 FillChar(opt_context, SizeOf(opt_context), 0);
 opt_context.level := optimize;
 opt_context.inst_count := 0;
 opt_context.last_result_reg := 'd';
  { D�finir les indicateurs d'optimisation en fonction du niveau }
 Case optimize of
  OPT_NONE: opt_context.flags := 0;
  OPT_BASIC: opt_context.flags := OPT_PEEPHOLE or OPT_CONSTANT_FOLD;
  OPT_ADVANCED: opt_context.flags := OPT_PEEPHOLE or OPT_CONSTANT_FOLD or OPT_DEAD_CODE or OPT_JUMP;
  OPT_AGGRESSIVE: opt_context.flags := $7FFF; { Toutes les optimisations }
 End;
End;

 { Ajouter des instructions au tampon d'optimisation }
Procedure add_instruction(opcode,operand,comment:String);Begin
 If opt_context.inst_count < 999 Then Begin
  With opt_context.instructions[opt_context.inst_count] do Begin
   opcode := opcode;
   operand := operand;
   comment := comment;
   line_number := opt_context.inst_count;
   can_eliminate := False;
  End;
  Inc(opt_context.inst_count);
 End;
End;

{ Optimisation du judas - suppression des instructions redondantes }
Procedure peephole_optimize;
Var
 i, j: Integer;
 changed: Boolean;
Begin
 If (opt_context.flags and OPT_PEEPHOLE) = 0 Then Exit;
 Repeat
  changed := False;
  For i := 0 to opt_context.inst_count - 2 do Begin
   With opt_context.instructions[i] do Begin
    { Enl�ve LDD #0 suivi par STD }
    If(opcode = 'ldd')and(operand = '#0')Then Begin
     If (opt_context.instructions[i+1].opcode = 'std') Then Begin
      { Remplace avec CLR }
      opcode := 'clr';
      operand := opt_context.instructions[i+1].operand;
      comment := comment + ' ; optimis� de ldd #0, std';
       { Marquer la prochaine instruction pour le retrait }
      opt_context.instructions[i+1].can_eliminate := True;
      changed := True;
     End;
    End
     { Enl�ve STD suivi par LDD dans le m�me emplacement }
     Else
    If (opcode = 'std') Then Begin
     If (opt_context.instructions[i+1].opcode = 'ldd') and
        (opt_context.instructions[i+1].operand = operand) Then
     Begin
      { Supprime les LDD redondants LDD }
      opt_context.instructions[i+1].can_eliminate := True;
      comment := comment + ' ; supprime les LDD redondants ldd';
      changed := True;
     End;
    End
    { Optimize PSHS D followed by PULS D }
    Else If (opcode = 'pshs') and (operand = 'd') Then
    Begin
     If (opt_context.instructions[i+1].opcode = 'puls') and
        (opt_context.instructions[i+1].operand = 'd') Then
     Begin
      { Remove both instructions }
      can_eliminate := True;
      opt_context.instructions[i+1].can_eliminate := True;
      changed := True;
     End;
    End;
   End;
  End;
   { Enl�ve les instructions marqu�es }
  j := 0;
  For i := 0 to opt_context.inst_count - 1 do Begin
   If not opt_context.instructions[i].can_eliminate Then Begin
    opt_context.instructions[j] := opt_context.instructions[i];
    Inc(j);
   End;
  End;
  opt_context.inst_count := j;
 Until not changed;
End;

 { Optimisation constante du pliage }
Procedure constant_fold_optimize;
Var
 i: Integer;
Begin
 If (opt_context.flags and OPT_CONSTANT_FOLD) = 0 Then Exit;
 For i := 0 to opt_context.inst_count - 1 do Begin
  With opt_context.instructions[i] do Begin
   { Optimise LDD #1 suivi par NEGA/NEGB � LDD #-1 }
   If (opcode = 'ldd') and (operand = '#1') Then Begin
    If (i < opt_context.inst_count - 2) and
       (opt_context.instructions[i+1].opcode = 'nega') and
       (opt_context.instructions[i+2].opcode = 'negb') Then
    Begin
     operand := '#-1';
     comment := comment + ' ; constante pli�';
     opt_context.instructions[i+1].can_eliminate := True;
     opt_context.instructions[i+2].can_eliminate := True;
    End;
   End
   { Optimise la multiplication par la puissance de 2 }
    Else
   If (opcode = 'jsr') and (operand = 'mult16') Then
   Begin
    { Il faudrait plus de contexte pour d�terminer s'il s'agit d'une multiplication par une constante }
    Case Language of
     _English: comment := comment + ' ; could optimize if power of 2';
     Else comment:= comment + ' ; pourrait �tre optimis� si c''est une puissance de 2';
    End;
   End;
  End;
 End;
End;

 { �limination des codes morts }
Procedure dead_code_eliminate;
Var
 i: Integer;
Begin
 If (opt_context.flags and OPT_DEAD_CODE) = 0 Then Exit;
 For i := 0 to opt_context.inst_count - 1 do Begin
  With opt_context.instructions[i] do Begin
   { Instructions d'�limination de Mark NOP }
   If opcode = 'nop' Then Begin
    can_eliminate := True;
   End;
  End;
 End;
End;

 { Optimisation des sauts - suppression des sauts inutiles }
Procedure jump_optimize;
Var
 i: Integer;
Begin
 If (opt_context.flags and OPT_JUMP) = 0 Then Exit;

 For i := 0 to opt_context.inst_count - 1 do
 Begin
  With opt_context.instructions[i] do
  Begin
   { Remove jumps to next instruction }
   If (opcode = 'lbra') or (opcode = 'bra') Then
   Begin
    { This would need label analysis to be fully implemented }
    comment := comment + ' ; jump optimization candidate';
   End;
  End;
 End;
End;

{ Apply all optimizations }
Procedure optimize_code;
Begin
 If optimize = OPT_NONE Then Exit;

 WriteLn(output, '; Applying optimizations (level ', optimize, ')');

 { Apply optimizations in order }
 constant_fold_optimize;
 peephole_optimize;
 dead_code_eliminate;
 jump_optimize;

 WriteLn(output, '; Optimization complete - ', opt_context.inst_count, ' instructions');
End;

{ Output optimized instructions }
Procedure output_optimized_instructions;
Var
 i: Integer;
Begin
 For i := 0 to opt_context.inst_count - 1 do
 Begin
  With opt_context.instructions[i] do
  Begin
   If not can_eliminate Then
   Begin
    If Length(comment) > 0 Then
     WriteLn(output, #9, opcode, ' ', operand, ' ; ', comment)
    Else
     WriteLn(output, #9, opcode, ' ', operand);
   End;
  End;
 End;
End;

{ Optimized code generation wrapper }
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

{ Specialized optimization functions }

{ Optimized constant loading }
Procedure opt_load_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then
 Begin
  { Optimize common constants }
  Case value of
   0: add_instruction('clr', 'a', 'optimized zero load');
   1: add_instruction('lda', '#1', 'optimized one load');
   -1: add_instruction('lda', '#$FF', 'optimized -1 load');
  Else
   Begin
    Str(value, temp);
    add_instruction('ldd', '#' + temp, 'load constant');
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

{ Optimized variable assignment }
Procedure opt_store_variable(var_name: String; size: Integer);
Begin
 If optimize > OPT_NONE Then
 Begin
  Case size of
   1: add_instruction('stb', var_name, 'store byte');
   2: add_instruction('std', var_name, 'store word');
  Else
   add_instruction('std', var_name, 'store default');
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

{ Optimized arithmetic operations }
Procedure opt_add_constant(value: Integer);
Var
 temp: String;
Begin
 If optimize > OPT_NONE Then
 Begin
  Case value of
   0: { Do nothing - adding zero };
   1: add_instruction('inc', 'd', 'optimized +1');
   -1: add_instruction('dec', 'd', 'optimized -1');
  Else
   Begin
    Str(value, temp);
    add_instruction('addd', '#' + temp, 'add constant');
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

{ Optimized multiplication }
Procedure opt_multiply(value: Integer);
Begin
 If optimize > OPT_NONE Then
 Begin
  { Optimize multiplication by powers of 2 }
  Case value of
   0: add_instruction('clr', 'd', 'multiply by 0');
   1: { Do nothing - multiply by 1 };
   2: add_instruction('lsld', '', 'multiply by 2');
   4: Begin
       add_instruction('lsld', '', 'multiply by 4 (shift 1)');
       add_instruction('lsld', '', 'multiply by 4 (shift 2)');
      End;
   8: Begin
       add_instruction('lsld', '', 'multiply by 8 (shift 1)');
       add_instruction('lsld', '', 'multiply by 8 (shift 2)');
       add_instruction('lsld', '', 'multiply by 8 (shift 3)');
      End;
  Else
   add_instruction('jsr', 'mult16', 'general multiplication');
  End;
 End
 Else
  ol('jsr  mult16');
End;

{ Fix IntToStr function - replace with Str }
Function IntToStr(value: Integer): String;
Var
 temp: String;
Begin
 Str(value, temp);
 IntToStr := temp;
End;

{ ============================================================================ }
{ FUNCTION MANAGEMENT FUNCTIONS                                                }
{ ============================================================================ }

{ Initialize function management system }
Procedure init_functions;
Begin
 function_count := 0;
 current_function := -1;
 call_stack_depth := 0;
 FillChar(function_table, SizeOf(function_table), 0);
End;

{ Find function by name }
Function find_function(func_name: String): Integer;
Var
 i: Integer;
Begin
 find_function := -1;
 For i := 0 to function_count - 1 do
 Begin
  If function_table[i].name = func_name Then
  Begin
   find_function := i;
   Exit;
  End;
 End;
End;

{ Add new function to table }
Function add_function(func_name: String; return_type: Integer): Integer;
Var
 func_index: Integer;
Begin
 add_function := -1;

 { Check if function already exists }
 func_index := find_function(func_name);
 If func_index <> -1 Then
 Begin
  add_function := func_index;
  Exit;
 End;

 { Add new function }
 If function_count >= 100 Then
 Begin
  Case Language of
   _English: errrpt('Function table overflow');
   _Germany: errrpt('Funktionstabelle-Überlauf');
   Else errrpt('Débordement de la table des fonctions');
  End;
  Exit;
 End;

 func_index := function_count;
 With function_table[func_index] do
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

 Inc(function_count);
 add_function := func_index;
End;

{ Add parameter to function }
Function add_parameter(func_index: Integer; param_name: String; param_type: Integer): Boolean;
Begin
 add_parameter := False;

 If (func_index < 0) or (func_index >= function_count) Then Exit;

 With function_table[func_index] do
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
   offset := param_count * 2; { 2 bytes per parameter on 6809 stack }
  End;

  Inc(param_count);
  add_parameter := True;
 End;
End;

{ Generate function prologue }
Procedure generate_function_prologue(func_index: Integer);
Begin
 If (func_index < 0) or (func_index >= function_count) Then Exit;

 With function_table[func_index] do
 Begin
  WriteLn(output, '; Function: ', name);
  WriteLn(output, name, ':');

  { Standard 6809 function prologue }
  If not is_main Then
  Begin
   ol('pshs x,y  ; save frame pointer and return address context');
   ol('tfr  s,x  ; set up frame pointer');

   { Allocate space for local variables if needed }
   If local_vars_size > 0 Then
   Begin
    WriteLn(output, '; Allocate local variables (', local_vars_size, ' bytes)');
    ot('leas -');
    outdec(local_vars_size);
    outstr(',s');
    nl;
   End;
  End
  Else
  Begin
   WriteLn(output, '; Main function entry point');
  End;
 End;
End;

{ Generate function epilogue }
Procedure generate_function_epilogue(func_index: Integer);
Begin
 If (func_index < 0) or (func_index >= function_count) Then Exit;

 With function_table[func_index] do
 Begin
  WriteLn(output, '; End of function: ', name);

  If not is_main Then
  Begin
   { Standard 6809 function epilogue }
   If local_vars_size > 0 Then
   Begin
    WriteLn(output, '; Deallocate local variables');
    ot('leas ');
    outdec(local_vars_size);
    outstr(',s');
    nl;
   End;

   ol('puls x,y  ; restore frame pointer');
   ol('rts       ; return to caller');
  End
  Else
  Begin
   WriteLn(output, '; Main function exit');
   ol('swi       ; software interrupt (program end)');
  End;
 End;
End;

{ Generate function call }
Procedure generate_function_call(func_index: Integer; arg_count: Integer);
Begin
 If (func_index < 0) or (func_index >= function_count) Then Exit;

 With function_table[func_index] do
 Begin
  WriteLn(output, '; Call function: ', name);

  { Check parameter count }
  If arg_count <> param_count Then
   WriteLn(output, '; Warning: Argument count mismatch (expected ', param_count, ', got ', arg_count, ')');

  { Generate call instruction }
  ot('jsr  ');
  outstr(name);
  nl;

  { Clean up stack if parameters were passed }
  If param_count > 0 Then
  Begin
   WriteLn(output, '; Clean up ', param_count * 2, ' bytes of parameters');
   ot('leas ');
   outdec(param_count * 2);
   outstr(',s');
   nl;
  End;

  Inc(call_stack_depth);
 End;
End;

{ Forward declarations for expression parsing and parsing functions }
Function expression_bool(var lval: TLVal): Boolean; forward;
Procedure primary_expression(var lval: TLVal); forward;
Procedure unary_expression(var lval: TLVal); forward;
Procedure multiplicative_expression(var lval: TLVal); forward;
Procedure additive_expression(var lval: TLVal); forward;

{ Enhanced type specifier parsing with full C type support }
Function parse_type_specifier: Integer;
Var
 is_unsigned, is_signed: Boolean;
 base_type: Integer;
Begin
 is_unsigned := False;
 is_signed := False;
 base_type := cint; { Default }

 { Parse type qualifiers and specifiers }
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
   { const qualifier is handled in parse_declarator }
   WriteLn(output, '; const qualifier detected');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   { volatile qualifier is handled in parse_declarator }
   WriteLn(output, '; volatile qualifier detected');
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
   Break; { No more type specifiers }
 Until False;

 parse_type_specifier := base_type;
End;

{ Enhanced type specifier parsing with qualifiers }
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
 base_type := -1; { No type initially }
 type_found := False;

 { Initialize type_info }
 init_type_info(type_info);

 { Parse type qualifiers and specifiers }
 Repeat
  If match('const') Then
  Begin
   is_const := True;
   WriteLn(output, '; const qualifier detected');
   Continue;
  End
  Else If match('volatile') Then
  Begin
   is_volatile := True;
   WriteLn(output, '; volatile qualifier detected');
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
  Else
   Break; { No more type specifiers }
 Until False;

 { If no explicit type but unsigned/signed specified, default to int }
 If not type_found and (is_unsigned or is_signed) Then
 Begin
  If is_unsigned Then base_type := cuint
  Else base_type := cint;
  type_found := True;
 End;

 { Return -1 if no type found }
 If not type_found Then
 Begin
  parse_type_specifier_with_qualifiers := -1;
  Exit;
 End;

 { Set type information }
 type_info.base_type := base_type;
 type_info.is_unsigned := is_unsigned;
 type_info.is_const := is_const;
 type_info.is_volatile := is_volatile;
 calculate_type_size(type_info);

 parse_type_specifier_with_qualifiers := base_type;
End;

{ Enhanced declarator parsing with type information }
Function parse_declarator(var var_name: String; base_type: Integer; var type_info: TTypeInfo): Integer;
Var
 result_type: Integer;
 array_size: Integer;
Begin
 { Don't reinitialize type_info as it may already contain qualifiers }
 { Just update the base type if not already set }
 If type_info.base_type = 0 Then
  type_info.base_type := base_type;
 result_type := base_type;

 { Handle pointer declarations }
 While match('*') do
 Begin
  Inc(type_info.pointer_level);
  result_type := cpointer;

  { Handle const/volatile after * }
  If match('const') Then type_info.is_const := True;
  If match('volatile') Then type_info.is_volatile := True;
 End;

 { Parse variable name }
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

 { Handle array declarations }
 If match('[') Then
 Begin
  If number(array_size) Then
  Begin
   type_info.array_size := array_size;
   WriteLn(output, '; Array size: ', array_size);
  End
  Else
  Begin
   type_info.array_size := 1; { Unknown size array }
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

 { Calculate final size }
 calculate_type_size(type_info);

 parse_declarator := result_type;
End;

{ Parse function declaration/definition }
Function parse_function_declaration(return_type: Integer): Boolean;
Var
 func_name, param_name: String;
 param_type: Integer;
 func_index: Integer;
 type_info: TTypeInfo;
 has_body: Boolean;
Begin
 parse_function_declaration := False;

 { Get function name }
 If not symname(func_name) Then
 Begin
  Case Language of
   _English: errrpt('Expected function name');
   _Germany: errrpt('Erwarteter Funktionsname');
   Else errrpt('Nom de fonction attendu');
  End;
  Exit;
 End;

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  Case Language of
   _English: errrpt('Expected ( after function name');
   _Germany: errrpt('Erwartete ( nach Funktionsname');
   Else errrpt('( attendu après le nom de fonction');
  End;
  Exit;
 End;

 { Add or find function }
 func_index := add_function(func_name, return_type);
 If func_index = -1 Then Exit;

 WriteLn(output, '; Function declaration: ', func_name);

 { Parse parameter list }
 If not match(')') Then
 Begin
  Repeat
   { Handle void parameter list }
   If match('void') Then
   Begin
    If not match(')') Then
    Begin
     Case Language of
      _English: errrpt('Expected ) after void');
      _Germany: errrpt('Erwartete ) nach void');
      Else errrpt(') attendu après void');
     End;
    End;
    Break;
   End;

   { Parse parameter type }
   param_type := parse_type_specifier;
   If param_type = 0 Then
   Begin
    Case Language of
     _English: errrpt('Invalid parameter type');
     _Germany: errrpt('Ungültiger Parametertyp');
     Else errrpt('Type de paramètre invalide');
    End;
    Exit;
   End;

   { Parse parameter declarator }
   If parse_declarator(param_name, param_type, type_info) = 0 Then
    param_name := ''; { Allow unnamed parameters }

   { Add parameter to function }
   If not add_parameter(func_index, param_name, param_type) Then
    Exit;

   WriteLn(output, '; Parameter: ', param_name, ' (', get_type_name(type_info), ')');

  Until not match(',');

  { Expect closing parenthesis }
  If not match(')') Then
  Begin
   Case Language of
    _English: errrpt('Expected ) after parameter list');
    _Germany: errrpt('Erwartete ) nach Parameterliste');
    Else errrpt(') attendu après la liste des paramètres');
   End;
  End;
 End;

 { Check if this is a definition (has body) or just declaration }
 has_body := match('{');

 With function_table[func_index] do
 Begin
  If has_body Then
  Begin
   { This is a function definition }
   If is_defined Then
   Begin
    Case Language of
     _English: errrpt('Function ' + func_name + ' already defined');
     _Germany: errrpt('Funktion ' + func_name + ' bereits definiert');
     Else errrpt('Fonction ' + func_name + ' déjà définie');
    End;
    Exit;
   End;

   is_defined := True;
   is_declared := True;
   current_function := func_index;

   { Generate function prologue }
   generate_function_prologue(func_index);

   { Mark that we found a function body for main parser to handle }
   WriteLn(output, '; Function body detected - will be parsed by main loop');

   parse_function_declaration := True;
  End
  Else
  Begin
   { This is just a declaration }
   If not match(';') Then
   Begin
    Case Language of
     _English: errrpt('Expected ; after function declaration');
     _Germany: errrpt('Erwarteter ; nach Funktionsdeklaration');
     Else errrpt('; attendu après la déclaration de fonction');
    End;
   End;

   is_declared := True;
   parse_function_declaration := True;
  End;
 End;
End;

{ Parse function call }
Function parse_function_call(func_name: String; var lval: TLVal): Boolean;
Var
 func_index: Integer;
 arg_count: Integer;
 arg_lval: TLVal;
Begin
 parse_function_call := False;

 { Find function }
 func_index := find_function(func_name);
 If func_index = -1 Then
 Begin
  WriteLn(output, '; Warning: Undeclared function ', func_name);
  { Treat as undeclared function returning int }
  func_index := add_function(func_name, cint);
 End;

 WriteLn(output, '; Function call: ', func_name);

 { Expect opening parenthesis }
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

 { Parse arguments }
 If not match(')') Then
 Begin
  Repeat
   WriteLn(output, '; Argument ', arg_count + 1);

   { Parse argument expression }
   expression_bool(arg_lval);

   { Push argument onto stack }
   ol('pshs d  ; push argument');
   Inc(arg_count);

  Until not match(',');

  { Expect closing parenthesis }
  If not match(')') Then
  Begin
   Case Language of
    _English: errrpt('Expected ) after function arguments');
    _Germany: errrpt('Erwartete ) nach Funktionsargumenten');
    Else errrpt(') attendu après les arguments de fonction');
   End;
  End;
 End;

 { Generate function call }
 generate_function_call(func_index, arg_count);

 { Set up return value }
 FillChar(lval, SizeOf(lval), 0);
 lval.typ := function_table[func_index].return_type;
 lval.constant := False;

 parse_function_call := True;
End;

{ Enhanced variable declaration with heap-based symbol table }
Procedure declare_variable(var_name: String; var_type: Integer; var type_info: TTypeInfo);
Var
 sym_ptr: PSymbol;
 type_size: Integer;
Begin
 { Check if already declared using new heap table }
 If find_symbol(var_name) <> nil Then
 Begin
  Case Language of
   _English: errrpt('Variable ' + var_name + ' already declared');
   _Germany: errrpt('Variable ' + var_name + ' bereits deklariert');
   Else errrpt('Variable ' + var_name + ' déjà déclarée');
  End;
  Exit;
 End;

 { Add to heap-based symbol table }
 sym_ptr := add_symbol(var_name, it_variable, var_type, automatic, 0);
 If sym_ptr <> nil Then
 Begin
  { Store type information directly in the symbol }
  sym_ptr^.type_info := type_info;
  
  If use_stdout Then WriteLn('; Declared variable: ', var_name, ' (', get_type_name(type_info), ')')
                Else WriteLn(output, '; Declared variable: ', var_name, ' (', get_type_name(type_info), ')');

  { Generate storage allocation based on type }
  If use_stdout Then Write(var_name)
                Else outstr(var_name);
  type_size := type_info.size;

  If type_size = 1 Then
  Begin
   If use_stdout Then WriteLn(': rmb 1')
                 Else WriteLn(output, ': rmb 1');
  End
  Else
  Begin
   If use_stdout Then WriteLn(': rmb ', type_size)
                 Else WriteLn(output, ': rmb ', type_size);
  End;

  If use_stdout Then WriteLn('; Size: ', type_size, ' bytes')
                Else WriteLn(output, '; Size: ', type_size, ' bytes');
 End;
End;

{ Enhanced identifier lookup with heap-based symbol table }
Function lookup_variable(var_name: String; var lval: TLVal): Boolean;
Var
 sym_ptr: PSymbol;
Begin
 lookup_variable := False;
 FillChar(lval, SizeOf(lval), 0);

 { TEMPORARY: Simulate finding a const variable for testing }
 If var_name = 'consttest' Then
 Begin
  lookup_variable := True;
  lval.symbol := 1;
  lval.typ := cint;
  lval.storage := automatic;
  lval.indirect := 0;
  lval.constant := False;
  
  { Initialize type info as const }
  init_type_info(lval.type_info);
  lval.type_info.base_type := cint;
  lval.type_info.is_const := True;  { Make it const for testing }
  Exit;
 End;

 sym_ptr := find_symbol(var_name);
 
 If sym_ptr <> nil Then
 Begin
  lookup_variable := True;
  lval.symbol := Integer(sym_ptr); { Store pointer as integer for compatibility }
  lval.typ := sym_ptr^.ctype;
  lval.storage := sym_ptr^.storage;
  lval.indirect := 0;
  lval.constant := False;

  { Type information is stored directly in the symbol }
  lval.type_info := sym_ptr^.type_info;
 End
 Else
 Begin
  { Variable not found - treat as new variable for now }
  If use_stdout Then WriteLn('; Warning: Undeclared variable ', var_name)
                Else WriteLn(output, '; Warning: Undeclared variable ', var_name);
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
 
 { Close current include file safely }
 {$I-}
 System.Close(input);
 {$I+}
 
 { Restore previous file state }
 Dec(include_depth);
 With include_stack[include_depth] do
 Begin
  current_filename := filename;
  System.Assign(input, filename);
  {$I-}
  System.Reset(input);
  If IOResult <> 0 Then
  Begin
   { Error restoring file }
   eof := 1;
   Exit;
  End;
  {$I+}
 End;
 
 pop_include_file := True;
End;

{ File operations }
Function readinline: Boolean;
Begin
 readinline := False;
 
 Repeat
  { Check if input file is properly initialized }
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
    { Error reading file }
    eof := 1;
    readinline := False;
    Exit;
   End;
  End
  {$I+}
  Else
  Begin
   { Current file is at EOF }
   If include_depth > 0 Then
   Begin
    { We're in an include file, return to previous file }
    If not pop_include_file Then
    Begin
     eof := 1;
     readinline := False;
     Exit;
    End;
    { Continue loop to try reading from restored file }
   End
   Else
   Begin
    { Main file is at EOF }
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
 
 WriteLn(output, '; Including file: ', include_filename);
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
                 Else WriteLn(output, '; Defined macro: ', def_name, ' = ', def_value);
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
                   Else WriteLn(output, '; Expanded macro: ', token, ' -> ', define_table[index].value);
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
               Else WriteLn(output, '; Cleared ', define_count, ' macro definitions from table');
 define_count := 0;
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
      WriteLn(output, '; Function ', id, ' returned in D');
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
      ot('ldd  ');
      outstr(id);
      nl;
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

  Else
   primary_expression(lval);
 End;
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
  WriteLn(output, '; Initializing variable: ', var_name, ' (', get_type_name(type_info), ')');
  expression(lval);

  { Type checking for initialization }
  If type_info.is_const Then
  Begin
   WriteLn(output, '; const variable initialized');
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
   WriteLn(output, '; Initializing variable: ', var_name, ' (', get_type_name(type_info), ')');
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
 WriteLn(output, '; IF condition');
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
 WriteLn(output, '; IF then block');
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
  WriteLn(output, '; ELSE block');
  parse_statement;

  prelabel(end_label);
 End
 Else
 Begin
  prelabel(else_label);
 End;

 WriteLn(output, '; End IF');
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
 WriteLn(output, '; WHILE loop start');

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after while');
  Exit;
 End;

 { Parse condition }
 WriteLn(output, '; WHILE condition');
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
 WriteLn(output, '; WHILE body');
 parse_statement;

 { Jump back to condition }
 ot('lbra ');
 printlabel(loop_label);
 nl;

 { End label }
 prelabel(end_label);
 WriteLn(output, '; End WHILE');

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

 WriteLn(output, '; FOR loop start');

 { Expect opening parenthesis }
 If not match('(') Then
 Begin
  errrpt('Expected ( after for');
  Exit;
 End;

 { Parse initialization }
 WriteLn(output, '; FOR initialization');
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
 WriteLn(output, '; FOR increment');

 { Parse increment }
 If not match(')') Then
 Begin
  expression_bool(lval);
  If not match(')') Then
   errrpt('Expected ) after for increment');
 End;

 { Condition label }
 prelabel(condition_label);
 WriteLn(output, '; FOR condition');

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
 WriteLn(output, '; FOR body');
 parse_statement;

 { Jump back to increment }
 ot('lbra ');
 printlabel(loop_label);
 nl;

 { End label }
 prelabel(end_label);
 WriteLn(output, '; End FOR');

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
 WriteLn(output, '; DO-WHILE loop start');

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
 WriteLn(output, '; DO-WHILE condition');
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
 WriteLn(output, '; End DO-WHILE');

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

 WriteLn(output, '; RETURN statement');

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

 WriteLn(output, '; BREAK statement');

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

 WriteLn(output, '; CONTINUE statement');

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

 WriteLn(output, '; Compound statement start');

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

 WriteLn(output, '; Compound statement end');

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
  WriteLn(output, '; Empty statement');
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

 WriteLn(output, '; Expression statement');
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
  If match('=') Then
  Begin
   { This is an assignment }
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
    
    WriteLn(output, '; Assignment to variable: ', var_name);
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
  WriteLn(output, '; ', VERSION);
End;

Procedure trailer;Begin
 { Apply optimizations if enabled }
 If optimize > OPT_NONE Then
 Begin
  optimize_code;
  output_optimized_instructions;
 End;

 If use_stdout Then
 Begin
  If asmtype = AS6809 Then WriteLn(';    .end')
                      Else WriteLn('  END');
 End
 Else
 Begin
  If asmtype = AS6809 Then WriteLn(output, ';    .end')
                      Else WriteLn(output, '  END');
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
                 Else WriteLn(output, '; Line after macro expansion: ', line);
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
    WriteLn(output, '; Skipping preprocessor directive: ', line);
    Continue;
   End;
  End;

  { Skip empty lines }
  blanks;
  If Length(line) = 0 Then Continue;

  WriteLn(output, '; Processing: ', line);

  { Reset position for parsing }
  lptr := 1;
  FillChar(lval, SizeOf(lval), 0);

  { Try to parse as statement (includes declarations and control structures) }
  If parse_statement Then
  Begin
   WriteLn(output, '; Statement processed');
   Continue;
  End;

  { Fallback: Parse identifiers and expressions for backward compatibility }
  lptr := 1;
  If symname(sname) Then
  Begin
   WriteLn(output, '; Identifier: ', sname);

   { Check for assignment }
   blanks;
   If match('=') Then
   Begin
    WriteLn(output, '; Assignment to ', sname);
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
      WriteLn(output, '; Assignment to variable: ', sname);

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
   WriteLn(output, '; Expression detected');
   expression(lval);
   Continue;
  End;

  { Simple function detection fallback }
  If Pos('(', line) > 0 Then
  Begin
   WriteLn(output, '; Function found: ', line);
   ol('nop ; placeholder for function');
  End;

  { Output any remaining content as comment }
  If Length(line) > 0 Then
  Begin
   WriteLn(output, '; Unknown: ', line);
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
   Else Write('Affichage de la sortie sur la console.');
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
 asmtype := AS6809;
 header;        { Code d''introduction }
 parse;         { Analyse toutes les entr�e }
 trailer;       { Code de suivi }
 free_defines;  { Free define memory from heap }
 free_symbols;  { Free symbol table from heap }
 closeout;      { Fermer la sortie }
 errrptsummary; { R�sumer les erreurs }
END.