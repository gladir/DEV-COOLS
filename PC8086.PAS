{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Pascal pour 8086
}

Program PC8086;

{$A-}

Uses DOS;

{ ============================================================================ }
{ CONSTANTES ET TYPES                                                          }
{ ============================================================================ }

Const
 MAX_SYMBOL_NAME = 32;
 MAX_STRING_LENGTH = 255;
 MAX_SYMBOLS = 1000;
 MAX_LABEL_COUNT = 100;
 MAX_INCLUDE_DEPTH = 10;

 { Types de symboles Pascal }
 SYM_UNKNOWN = 0;
 SYM_PROGRAM = 1;
 SYM_USES = 2;
 SYM_VAR = 3;
 SYM_CONST = 4;
 SYM_TYPE = 5;
 SYM_PROCEDURE = 6;
 SYM_FUNCTION = 7;
 SYM_BEGIN = 8;
 SYM_END = 9;
 SYM_IF = 10;
 SYM_THEN = 11;
 SYM_ELSE = 12;
 SYM_WHILE = 13;
 SYM_DO = 14;
 SYM_FOR = 15;
 SYM_TO = 16;
 SYM_DOWNTO = 17;
 SYM_REPEAT = 18;
 SYM_UNTIL = 19;
 SYM_CASE = 20;
 SYM_OF = 21;
 SYM_WRITE = 22;
 SYM_WRITELN = 23;
 SYM_READ = 24;
 SYM_READLN = 25;
 SYM_INTERRUPT = 26;
 SYM_RECORD = 27;
 SYM_ARRAY = 28;
 SYM_OTHERWISE = 29;

 { Opérateurs de comparaison }
 SYM_EQUAL = 30;      { = }
 SYM_NOTEQUAL = 31;   { <> }
 SYM_LESS = 32;       { < }
 SYM_GREATER = 33;    { > }
 SYM_LESSEQ = 34;     { <= }
 SYM_GREATEREQ = 35;  { >= }

 { Opérateurs arithmétiques }
 SYM_PLUS = 36;       { + }
 SYM_MINUS = 37;      { - }
 SYM_MULTIPLY = 38;   { * }
 SYM_DIVIDE = 39;     { / }

 { Opérateurs logiques }
 SYM_AND = 40;        { AND }
 SYM_OR = 41;         { OR }
 SYM_XOR = 42;        { XOR }

 { Caractères spéciaux }
 SYM_DOT = 43;        { . }

 { Types de données Pascal }
 TYPE_INTEGER = 1;
 TYPE_BYTE = 2;
 TYPE_WORD = 3;
 TYPE_STRING = 4;
 TYPE_CHAR = 5;
 TYPE_BOOLEAN = 6;
 TYPE_REAL = 7;
 TYPE_RECORD = 8;
 TYPE_ARRAY = 9;
 TYPE_POINTER = 10;

 { Classes de stockage }
 STORAGE_GLOBAL = 1;
 STORAGE_LOCAL = 2;
 STORAGE_PARAMETER = 3;
 STORAGE_FUNCTION_RESULT = 4;

Type
 { Structure pour les symboles }
 TSymbol = Record
  name: String[MAX_SYMBOL_NAME];
  symbol_type: Integer;
  data_type: Integer;
  storage_class: Integer;
  offset: Integer;
  value: Integer;
  defined: Boolean;
  return_type: Integer;      { Type de retour pour les fonctions }
  is_function: Boolean;      { Indicateur fonction vs procédure }
  record_size: Integer;      { Taille totale du record }
  field_count: Integer;      { Nombre de champs dans le record }
 End;
 
 { Pointeur vers un symbole }
 PSymbol = ^TSymbol;

 { Structure pour les étiquettes }
 TLabel = Record
  name: String[MAX_SYMBOL_NAME];
  label_id: Integer;
  defined: Boolean;
  address: Integer;
 End;
 
 { Pointeur vers une étiquette }
 PLabel = ^TLabel;

Var
 { Variables globales }
 input_file: Text;
 output_file: Text;
 current_line: String;
 line_pos: Integer;
 current_char: Char;
 line_number: Integer;

 { Table des symboles }
 symbol_table: Array[1..MAX_SYMBOLS] of PSymbol;
 symbol_count: Integer;

 { Table des étiquettes }
 label_table: Array[1..MAX_LABEL_COUNT] of PLabel;
 label_count: Integer;
 next_label_id: Integer;

 { État du compilateur }
 current_token: String;
 current_symbol: Integer;
 current_value: Integer;
 error_count: Integer;

 { Variables de génération de code }
 code_segment: Boolean;
 data_segment: Boolean;
 stack_offset: Integer;

 { Noms des fichiers }
 source_filename: String;
 output_filename: String;

 { Variables pour les fonctions }
 current_function_name: String;
 current_function_type: Integer;
 in_function: Boolean;

{ ============================================================================ }
{ FONCTIONS UTILITAIRES                                                        }
{ ============================================================================ }

{ Afficher un message d'erreur }
Procedure Error(msg: String);
Begin
 WriteLn('ERREUR ligne ', line_number, ': ', msg);
 Inc(error_count);
End;

{ Afficher un avertissement }
Procedure Warning(msg: String);
Begin
 WriteLn('ATTENTION ligne ', line_number, ': ', msg);
End;

{ Convertir une chaîne en majuscules }
Function UpperCase(s: String): String;
Var
 i: Integer;
 result: String;
Begin
 result := s;
 For i := 1 to Length(s) do
  If (s[i] >= 'a') and (s[i] <= 'z') Then
   result[i] := Chr(Ord(s[i]) - 32);
 UpperCase := result;
End;

{ ============================================================================ }
{ GESTION DES FICHIERS ET LECTURE                                             }
{ ============================================================================ }

{ Lire le caractère suivant }
Procedure NextChar;
Begin
 If line_pos > Length(current_line) Then
 Begin
  If not Eof(input_file) Then
  Begin
   ReadLn(input_file, current_line);
   Inc(line_number);
   line_pos := 1;
   If Length(current_line) = 0 Then
   Begin
    current_char := ' '; { Traiter ligne vide comme espace }
    Exit;
   End;
  End
  Else
  Begin
   current_char := #0;
   Exit;
  End;
 End;

 If line_pos <= Length(current_line) Then
 Begin
  current_char := current_line[line_pos];
  Inc(line_pos);
 End
 Else
 Begin
  current_char := ' '; { Fin de ligne = espace }
  Inc(line_pos); { Pour déclencher la lecture de la ligne suivante }
 End;
End;

{ Ignorer les espaces et commentaires }
Procedure SkipWhitespace;
Begin
 While (current_char = ' ') or (current_char = #9) or (current_char = #13) or (current_char = #10) do
  NextChar;

 { Gérer les commentaires Pascal délimités par accolades }
 If current_char = '{' Then
 Begin
  NextChar;
  While (current_char <> '}') and (current_char <> #0) do
   NextChar;
  If current_char = '}' Then
   NextChar;
  SkipWhitespace; { Récursion pour ignorer les espaces après commentaire }
 End;

 { Gérer les commentaires Pascal (* *) }
 If (current_char = '(') and (line_pos <= Length(current_line)) and (current_line[line_pos] = '*') Then
 Begin
  NextChar; NextChar; { Ignorer (* }
  While not ((current_char = '*') and (line_pos <= Length(current_line))
         and (current_line[line_pos] = ')')) and (current_char <> #0) do
   NextChar;
  If current_char = '*' Then
  Begin
   NextChar; NextChar; { Ignorer *) }
  End;
  SkipWhitespace; { Récursion }
 End;
End;

{ ============================================================================ }
{ ANALYSEUR LEXICAL                                                           }
{ ============================================================================ }

{ Lire un identificateur ou mot-clé }
Procedure ReadIdentifier;
Begin
 current_token := '';
 While ((current_char >= 'A') and (current_char <= 'Z')) or
       ((current_char >= 'a') and (current_char <= 'z')) or
       ((current_char >= '0') and (current_char <= '9')) or
       (current_char = '_') do
 Begin
  current_token := current_token + current_char;
  NextChar;
 End;

 { Identifier le type de symbole }
 current_token := UpperCase(current_token);

 If current_token = 'PROGRAM' Then current_symbol := SYM_PROGRAM
 Else If current_token = 'USES' Then current_symbol := SYM_USES
 Else If current_token = 'VAR' Then current_symbol := SYM_VAR
 Else If current_token = 'CONST' Then current_symbol := SYM_CONST
 Else If current_token = 'TYPE' Then current_symbol := SYM_TYPE
 Else If current_token = 'PROCEDURE' Then current_symbol := SYM_PROCEDURE
 Else If current_token = 'FUNCTION' Then current_symbol := SYM_FUNCTION
 Else If current_token = 'BEGIN' Then current_symbol := SYM_BEGIN
 Else If current_token = 'END' Then current_symbol := SYM_END
 Else If current_token = 'IF' Then current_symbol := SYM_IF
 Else If current_token = 'THEN' Then current_symbol := SYM_THEN
 Else If current_token = 'ELSE' Then current_symbol := SYM_ELSE
 Else If current_token = 'WHILE' Then current_symbol := SYM_WHILE
 Else If current_token = 'DO' Then current_symbol := SYM_DO
 Else If current_token = 'FOR' Then current_symbol := SYM_FOR
 Else If current_token = 'TO' Then current_symbol := SYM_TO
 Else If current_token = 'DOWNTO' Then current_symbol := SYM_DOWNTO
 Else If current_token = 'REPEAT' Then current_symbol := SYM_REPEAT
 Else If current_token = 'UNTIL' Then current_symbol := SYM_UNTIL
 Else If current_token = 'CASE' Then current_symbol := SYM_CASE
 Else If current_token = 'OF' Then current_symbol := SYM_OF
 Else If current_token = 'WRITE' Then current_symbol := SYM_WRITE
 Else If current_token = 'WRITELN' Then current_symbol := SYM_WRITELN
 Else If current_token = 'READ' Then current_symbol := SYM_READ
 Else If current_token = 'READLN' Then current_symbol := SYM_READLN
 Else If current_token = 'RECORD' Then current_symbol := SYM_RECORD
 Else If current_token = 'ARRAY' Then current_symbol := SYM_ARRAY
 Else If current_token = 'OTHERWISE' Then current_symbol := SYM_OTHERWISE
 Else If current_token = 'AND' Then current_symbol := SYM_AND
 Else If current_token = 'OR' Then current_symbol := SYM_OR
 Else If current_token = 'XOR' Then current_symbol := SYM_XOR
 Else current_symbol := SYM_UNKNOWN;
End;

{ Lire un nombre }
Procedure ReadNumber;
Var
 temp: String;
 code: Integer;
Begin
 temp := '';
 While (current_char >= '0') and (current_char <= '9') do
 Begin
  temp := temp + current_char;
  NextChar;
 End;

 Val(temp, current_value, code);
 If code <> 0 Then
 Begin
  Error('Nombre invalide: ' + temp);
  current_value := 0;
 End;

 current_token := temp;
 current_symbol := SYM_UNKNOWN;
End;

{ Obtenir le prochain token }
Procedure NextToken;
Begin
 SkipWhitespace;

 If current_char = #0 Then
 Begin
  current_token := '';
  current_symbol := SYM_UNKNOWN;
  Exit;
 End;

 { Chaîne de caractères }
 If current_char = '''' Then
 Begin
  current_token := '';
  current_symbol := SYM_UNKNOWN;
  NextChar; { Ignorer le premier guillemet }

  While (current_char <> '''') and (current_char <> #0) do
  Begin
   { Gérer les caractères d'échappement }
   If current_char = '''' Then
   Begin
    NextChar;
    If current_char = '''' Then
    Begin
     { Double guillemet = guillemet littéral }
     current_token := current_token + '''';
     NextChar;
    End
    Else
    Begin
     { Fin de chaîne }
     Break;
    End;
   End
   Else
   Begin
    current_token := current_token + current_char;
    NextChar;
   End;
  End;

  If current_char = '''' Then
   NextChar { Ignorer le guillemet final }
  Else
   Error('Chaîne non terminée');
 End
 { Opérateur d'affectation := }
 Else If current_char = ':' Then
 Begin
  NextChar;
  If current_char = '=' Then
  Begin
   current_token := ':=';
   current_symbol := SYM_UNKNOWN;
   NextChar;
  End
  Else
  Begin
   current_token := ':';
   current_symbol := SYM_UNKNOWN;
  End;
 End
 { Opérateurs de comparaison }
 Else If current_char = '<' Then
 Begin
  NextChar;
  If current_char = '=' Then
  Begin
   current_token := '<=';
   current_symbol := SYM_LESSEQ;
   NextChar;
  End
  Else If current_char = '>' Then
  Begin
   current_token := '<>';
   current_symbol := SYM_NOTEQUAL;
   NextChar;
  End
  Else
  Begin
   current_token := '<';
   current_symbol := SYM_LESS;
  End;
 End
 Else If current_char = '>' Then
 Begin
  NextChar;
  If current_char = '=' Then
  Begin
   current_token := '>=';
   current_symbol := SYM_GREATEREQ;
   NextChar;
  End
  Else
  Begin
   current_token := '>';
   current_symbol := SYM_GREATER;
  End;
 End
 Else If current_char = '=' Then
 Begin
  current_token := '=';
  current_symbol := SYM_EQUAL;
  NextChar;
 End
 { Opérateurs arithmétiques }
 Else If current_char = '+' Then
 Begin
  current_token := '+';
  current_symbol := SYM_PLUS;
  NextChar;
 End
 Else If current_char = '-' Then
 Begin
  current_token := '-';
  current_symbol := SYM_MINUS;
  NextChar;
 End
 Else If current_char = '*' Then
 Begin
  current_token := '*';
  current_symbol := SYM_MULTIPLY;
  NextChar;
 End
 Else If current_char = '/' Then
 Begin
  current_token := '/';
  current_symbol := SYM_DIVIDE;
  NextChar;
 End
 { Identifier ou mot-clé }
 Else If ((current_char >= 'A') and (current_char <= 'Z')) or
    ((current_char >= 'a') and (current_char <= 'z')) or
    (current_char = '_') Then
  ReadIdentifier
 { Nombre }
 Else If (current_char >= '0') and (current_char <= '9') Then
  ReadNumber
 { Caractères spéciaux }
 Else If current_char = '.' Then
 Begin
  current_token := '.';
  current_symbol := SYM_DOT;
  NextChar;
 End
 Else
 Begin
  current_token := current_char;
  current_symbol := SYM_UNKNOWN;
  NextChar;
 End;
End;

{ ============================================================================ }
{ GESTION DE LA TABLE DES SYMBOLES                                            }
{ ============================================================================ }

{ Rechercher un symbole dans la table }
Function FindSymbol(name: String): Integer;
Var
 i: Integer;
Begin
 name := UpperCase(name);
 For i := 1 to symbol_count do
  If (symbol_table[i] <> nil) and (symbol_table[i]^.name = name) Then
  Begin
   FindSymbol := i;
   Exit;
  End;
 FindSymbol := 0;
End;

{ Ajouter un symbole à la table }
Function AddSymbol(name: String; sym_type, data_type, storage: Integer): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddSymbol := 0;
  Exit;
 End;

 upper_name := UpperCase(name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;  { Utiliser la version en majuscules }
  symbol_type := sym_type;
  data_type := data_type;
  storage_class := storage;
  offset := 0;
  value := 0;
  defined := False;
  return_type := TYPE_INTEGER;  { Par défaut }
  is_function := False;
  record_size := 0;
  field_count := 0;
 End;

 AddSymbol := symbol_count;
End;

{ Ajouter une fonction à la table des symboles }
Function AddFunction(name: String; return_type: Integer): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddFunction := 0;
  Exit;
 End;

 upper_name := UpperCase(name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_FUNCTION;
  data_type := return_type;
  storage_class := STORAGE_GLOBAL;
  offset := 0;
  value := 0;
  defined := True;
  return_type := return_type;
  is_function := True;
  record_size := 0;
  field_count := 0;
 End;

 AddFunction := symbol_count;
End;

{ Ajouter une procédure à la table des symboles }
Function AddProcedure(name: String): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddProcedure := 0;
  Exit;
 End;

 upper_name := UpperCase(name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_PROCEDURE;
  data_type := TYPE_INTEGER; { Pas utilisé pour les procédures }
  storage_class := STORAGE_GLOBAL;
  offset := 0;
  value := 0;
  defined := True;
  return_type := TYPE_INTEGER; { Pas utilisé }
  is_function := False; { Procédure, pas fonction }
  record_size := 0;
  field_count := 0;
 End;

 AddProcedure := symbol_count;
End;

{ Ajouter une procédure d'interruption à la table des symboles }
Function AddInterrupt(name: String): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddInterrupt := 0;
  Exit;
 End;

 upper_name := UpperCase(name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_INTERRUPT;
  data_type := TYPE_INTEGER; { Pas utilisé pour les interruptions }
  storage_class := STORAGE_GLOBAL;
  offset := 0;
  value := 0;
  defined := True;
  return_type := TYPE_INTEGER; { Pas utilisé }
  is_function := False; { Procédure d'interruption, pas fonction }
  record_size := 0;
  field_count := 0;
 End;

 AddInterrupt := symbol_count;
End;

{ Ajouter un type RECORD à la table des symboles }
Function AddRecord(name: String; size: Integer): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddRecord := 0;
  Exit;
 End;

 upper_name := UpperCase(name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_TYPE;
  data_type := TYPE_RECORD;
  storage_class := STORAGE_GLOBAL;
  offset := 0;
  value := 0;
  defined := True;
  return_type := TYPE_INTEGER; { Pas utilisé }
  is_function := False;
  record_size := size;
  field_count := 0;
 End;

 AddRecord := symbol_count;
End;

{ Ajouter un champ de RECORD à la table des symboles }
Function AddRecordField(field_name: String; field_type: Integer; record_index: Integer; field_offset: Integer): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddRecordField := 0;
  Exit;
 End;

 upper_name := UpperCase(field_name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_VAR; { Les champs sont traités comme des variables }
  data_type := field_type;
  storage_class := STORAGE_PARAMETER; { Utilisé pour indiquer que c'est un champ }
  offset := field_offset;
  value := record_index; { Index du record parent }
  defined := True;
  return_type := TYPE_INTEGER;
  is_function := False;
  record_size := 0;
  field_count := 0;
 End;

 { Incrémenter le nombre de champs du record parent }
 If (record_index > 0) and (record_index <= symbol_count) Then
  Inc(symbol_table[record_index]^.field_count);

 AddRecordField := symbol_count;
End;

{ Ajouter un type alias à la table des symboles }
Function AddTypeAlias(type_name: String; base_type: Integer): Integer;
Var
 upper_name: String;
Begin
 If symbol_count >= MAX_SYMBOLS Then
 Begin
  Error('Table des symboles pleine');
  AddTypeAlias := 0;
  Exit;
 End;

 upper_name := UpperCase(type_name);
 Inc(symbol_count);
 New(symbol_table[symbol_count]);
 With symbol_table[symbol_count]^ do
 Begin
  name := upper_name;
  symbol_type := SYM_TYPE;
  data_type := base_type;
  storage_class := STORAGE_GLOBAL;
  offset := 0;
  value := 0;
  defined := True;
  return_type := TYPE_INTEGER;
  is_function := False;
  record_size := 0;
  field_count := 0;
 End;

 AddTypeAlias := symbol_count;
End;

{ ============================================================================ }
{ GÉNÉRATION DE CODE ASSEMBLEUR 8086                                          }
{ ============================================================================ }

{ Écrire une ligne dans le fichier de sortie }
Procedure EmitLine(line: String);
Begin
 WriteLn(output_file, line);
End;

{ Générer une instruction assembleur }
Procedure Emit(instruction: String);
Begin
 EmitLine('    ' + instruction);
End;

{ Générer une étiquette }
Procedure EmitLabel(label_name: String);
Begin
 EmitLine(label_name + ':');
End;

{ Générer un commentaire }
Procedure EmitComment(comment: String);
Begin
 EmitLine('; ' + comment);
End;

{ Générer l'en-tête du programme }
Procedure GenerateHeader;
Var
 year, month, day, dayofweek: Word;
 hour, minute, second, sec100: Word;
 date_str, time_str, temp: String;
Begin
 EmitComment('Compilé par PC8086 - Compilateur Pascal vers 8086');
 
 { Obtenir la date système }
 GetDate(year, month, day, dayofweek);
 
 { Construire la chaîne de date manuellement }
 Str(year, temp);
 date_str := temp + '-';
 
 If month < 10 Then date_str := date_str + '0';
 Str(month, temp);
 date_str := date_str + temp + '-';
 
 If day < 10 Then date_str := date_str + '0';
 Str(day, temp);
 date_str := date_str + temp;
 
 { Obtenir l'heure système }
 GetTime(hour, minute, second, sec100);
 
 { Construire la chaîne d'heure }
 time_str := '';
 If hour < 10 Then time_str := time_str + '0';
 Str(hour, temp);
 time_str := time_str + temp + ':';
 
 If minute < 10 Then time_str := time_str + '0';
 Str(minute, temp);
 time_str := time_str + temp + ':';
 
 If second < 10 Then time_str := time_str + '0';
 Str(second, temp);
 time_str := time_str + temp;
 
 EmitComment('Date: ' + date_str + ' ' + time_str);
 EmitLine('');
 EmitLine('.MODEL SMALL');
 EmitLine('.STACK 100h');
 EmitLine('');
 EmitLine('.DATA');
 
 { Définir les chaînes constantes pour les booléens }
 EmitLine('TRUE_STR  DB ''TRUE$''');
 EmitLine('FALSE_STR DB ''FALSE$''');
 EmitLine('');
 
 data_segment := True;
End;

{ Générer la déclaration d'une variable }
Procedure GenerateVariableDeclaration(var_name: String; var_type: Integer);
Var
 type_index: Integer;
 record_size: Integer;
Begin
 If not data_segment Then
 Begin
  EmitLine('.DATA');
  data_segment := True;
 End;

 Case var_type of
  TYPE_INTEGER, TYPE_WORD: EmitLine(var_name + ' DW ?');
  TYPE_BYTE, TYPE_CHAR: EmitLine(var_name + ' DB ?');
  TYPE_STRING: 
   Begin
    { Une chaîne Pascal a un octet de longueur suivi des caractères }
    EmitLine(var_name + ' DB 256 DUP(?)')
   End;
  TYPE_BOOLEAN: EmitLine(var_name + ' DB ?');
  TYPE_RECORD: 
   Begin
    { Chercher la taille du record dans la table des symboles }
    type_index := FindSymbol(var_name); { Ceci ne fonctionnera pas, il faudrait passer le type }
    { Pour l'instant, utiliser une taille par défaut }
    EmitLine(var_name + ' DB 64 DUP(?) ; Record (taille estimée)');
   End;
  TYPE_ARRAY:
   Begin
    { Pour l'instant, utiliser une taille par défaut pour les arrays }
    EmitLine(var_name + ' DW 100 DUP(?) ; Array (taille estimée)');
   End;
  TYPE_POINTER:
   Begin
    { Les pointeurs sont des mots de 16 bits en 8086 }
    EmitLine(var_name + ' DW ? ; Pointeur');
   End;
 Else
  EmitLine(var_name + ' DW ?'); { Par défaut }
 End;
End;

{ Commencer la section de code }
Procedure BeginCodeSection;
Begin
 If data_segment Then
 Begin
  EmitLine('');
  data_segment := False;
 End;

 If not code_segment Then
 Begin
  EmitLine('.CODE');
  EmitLine('MAIN PROC');
  EmitLine('    mov ax, @data');
  EmitLine('    mov ds, ax');
  EmitLine('');
  code_segment := True;
 End;
End;

{ Terminer le programme }
Procedure GenerateFooter;
Begin
 If code_segment Then
 Begin
  EmitLine('');
  EmitLine('    mov ax, 4C00h');
  EmitLine('    int 21h');
  EmitLine('MAIN ENDP');
  EmitLine('END MAIN');
 End;
End;

{ Convertir un entier en chaîne }
Function IntToStr(value: Integer): String;
Var
 result: String;
 negative: Boolean;
 digit: Integer;
Begin
 If value = 0 Then
 Begin
  IntToStr := '0';
  Exit;
 End;

 result := '';
 negative := value < 0;
 If negative Then
  value := -value;

 While value > 0 do
 Begin
  digit := value mod 10;
  result := Chr(48 + digit) + result;
  value := value div 10;
 End;

 If negative Then
  result := '-' + result;

 IntToStr := result;
End;

{ Générer une nouvelle étiquette }
Function NewLabel: String;
Begin
 Inc(next_label_id);
 NewLabel := 'L' + IntToStr(next_label_id);
End;

{ ============================================================================ }
{ ANALYSEUR SYNTAXIQUE PASCAL                                                 }
{ ============================================================================ }

{ Déclarations anticipées }
Procedure ParseStatement; forward;
Procedure ParseExpression; forward;
Procedure ParseBlock; forward;
Procedure ParseFor; forward;
Procedure ParseCase; forward;

{ Vérifier si le token actuel correspond }
Function Accept(expected_symbol: Integer): Boolean;
Begin
 Accept := (current_symbol = expected_symbol);
End;

{ Consommer un token attendu }
Procedure Expect(expected_symbol: Integer; error_msg: String);
Begin
 If current_symbol = expected_symbol Then
  NextToken
 Else
  Error(error_msg + ', trouvé: ' + current_token);
End;

{ Parser une expression simple }
Procedure ParseExpression;
Var
 sym_index: Integer;
 temp_token: String;
 left_operand: String;
 left_type: Integer; { Type du premier opérande }
 comparison_op: Integer;
 is_string_literal: Boolean;
 string_label: String;
Begin
 left_type := TYPE_INTEGER; { Type par défaut }
 is_string_literal := False;
 
 { Parser le premier opérande }
 If current_symbol = SYM_UNKNOWN Then
 Begin
  temp_token := current_token;
  
  { Vérifier si c'est une chaîne littérale }
  If (Length(temp_token) > 1) or 
     ((Length(temp_token) = 1) and not ((temp_token[1] >= '0') and (temp_token[1] <= '9')) and
      not ((temp_token[1] >= 'A') and (temp_token[1] <= 'Z')) and 
      not ((temp_token[1] >= 'a') and (temp_token[1] <= 'z'))) Then
  Begin
   { C'est probablement une chaîne littérale }
   is_string_literal := True;
   left_type := TYPE_STRING;
   
   { Créer une étiquette pour la chaîne }
   string_label := 'STR' + IntToStr(next_label_id);
   Inc(next_label_id);
   
   { Générer la chaîne dans le segment de données }
   If not data_segment Then
   Begin
    EmitLine('.DATA');
    data_segment := True;
   End;
   
   EmitLine(string_label + ' DB ' + IntToStr(Length(temp_token)) + ', ''' + temp_token + '''');
   
   { Retour au segment de code }
   If not code_segment Then
    BeginCodeSection;
    
   { Charger l'adresse de la chaîne }
   Emit('mov si, OFFSET ' + string_label);
   left_operand := 'si';
   NextToken;
  End
  { Vérifier si c'est un caractère littéral (longueur 1, lettre) }
  Else If (Length(temp_token) = 1) and 
     (((temp_token[1] >= 'A') and (temp_token[1] <= 'Z')) or
      ((temp_token[1] >= 'a') and (temp_token[1] <= 'z'))) Then
  Begin
   { Caractère littéral - traiter comme valeur ASCII }
   Emit('mov al, ' + IntToStr(Ord(temp_token[1])));
   left_operand := 'al';
   left_type := TYPE_CHAR;
   NextToken;
  End
  { C'est peut-être un nombre }
  Else If (temp_token <> '') and (temp_token[1] >= '0') and (temp_token[1] <= '9') Then
  Begin
   { Nombre littéral }
   Emit('mov ax, ' + temp_token);
   left_operand := 'ax';
   left_type := TYPE_INTEGER;
   NextToken;
  End
  Else If temp_token <> '' Then
  Begin
   { Identificateur - chercher dans la table des symboles }
   sym_index := FindSymbol(temp_token);
   If sym_index > 0 Then
   Begin
    left_type := symbol_table[sym_index]^.data_type;
    
    { Vérifier si c'est un appel de fonction }
    If symbol_table[sym_index]^.is_function Then
    Begin
     { Appel de fonction }
     EmitComment('Appel fonction: ' + temp_token);
     NextToken; { Consommer le nom de la fonction }
     
     { Gérer les paramètres (pour l'instant, on ignore) }
     If current_token = '(' Then
     Begin
      NextToken;
      While (current_token <> ')') and (current_char <> #0) do
       NextToken;
      If current_token = ')' Then
       NextToken;
     End;
     
     { Générer l'appel }
     Emit('call ' + symbol_table[sym_index]^.name);
     
     { Le résultat est dans AX ou AL selon le type de retour }
     Case symbol_table[sym_index]^.return_type of
      TYPE_INTEGER, TYPE_WORD: left_operand := 'ax';
      TYPE_BYTE, TYPE_CHAR: left_operand := 'al';
      TYPE_STRING: left_operand := 'si';
     Else
      left_operand := 'ax';
     End;
     left_type := symbol_table[sym_index]^.return_type;
    End
    { Vérifier si c'est un appel de procédure }
    Else If symbol_table[sym_index]^.symbol_type = SYM_PROCEDURE Then
    Begin
     { Appel de procédure }
     EmitComment('Appel procédure: ' + temp_token);
     NextToken; { Consommer le nom de la procédure }
     
     { Gérer les paramètres (pour l'instant, on ignore) }
     If current_token = '(' Then
     Begin
      NextToken;
      While (current_token <> ')') and (current_char <> #0) do
       NextToken;
      If current_token = ')' Then
       NextToken;
     End;
     
     { Générer l'appel - les procédures ne retournent pas de valeur }
     Emit('call ' + symbol_table[sym_index]^.name);
     left_operand := 'ax'; { Valeur par défaut }
     left_type := TYPE_INTEGER;
    End
    { Vérifier si c'est un appel d'interruption }
    Else If symbol_table[sym_index]^.symbol_type = SYM_INTERRUPT Then
    Begin
     { Appel d'interruption }
     EmitComment('Appel interruption: ' + temp_token);
     NextToken; { Consommer le nom de l'interruption }
     
     { Gérer les paramètres (pour l'instant, on ignore) }
     If current_token = '(' Then
     Begin
      NextToken;
      While (current_token <> ')') and (current_char <> #0) do
       NextToken;
      If current_token = ')' Then
       NextToken;
     End;
     
     { Générer l'appel - les interruptions ne retournent pas de valeur }
     Emit('call ' + symbol_table[sym_index]^.name);
     left_operand := 'ax'; { Valeur par défaut }
     left_type := TYPE_INTEGER;
    End
    Else
    Begin
     { Variable normale }
     Case symbol_table[sym_index]^.data_type of
      TYPE_INTEGER, TYPE_WORD: 
       Begin
        Emit('mov ax, ' + symbol_table[sym_index]^.name);
        left_operand := 'ax';
       End;
      TYPE_BYTE, TYPE_CHAR: 
       Begin
        Emit('mov al, ' + symbol_table[sym_index]^.name);
        left_operand := 'al';
       End;
      TYPE_STRING:
       Begin
        Emit('mov si, OFFSET ' + symbol_table[sym_index]^.name);
        left_operand := 'si';
       End;
     Else
      Begin
       Emit('mov ax, ' + symbol_table[sym_index]^.name);
       left_operand := 'ax';
      End;
     End;
     NextToken;
    End;
   End
   Else
   Begin
    Error('Variable non déclarée: ' + temp_token);
    left_operand := 'ax';
    left_type := TYPE_INTEGER;
    NextToken;
   End;
  End
  Else
  Begin
   NextToken; { Token vide, continuer }
   left_operand := 'ax';
   left_type := TYPE_INTEGER;
  End;
 End
 Else
 Begin
  NextToken; { Symbole reconnu, continuer }
  left_operand := 'ax';
  left_type := TYPE_INTEGER;
 End;
 
 { Vérifier s'il y a une opération arithmétique ou logique avant la comparaison }
 If (current_symbol = SYM_PLUS) or (current_symbol = SYM_MINUS) or
    (current_symbol = SYM_MULTIPLY) or (current_symbol = SYM_DIVIDE) or
    (current_symbol = SYM_AND) or (current_symbol = SYM_OR) or (current_symbol = SYM_XOR) Then
 Begin
  comparison_op := current_symbol;
  NextToken; { Consommer l'opérateur }
  
  { Parser le deuxième opérande }
  If current_symbol = SYM_UNKNOWN Then
  Begin
   temp_token := current_token;
   
   { Nombre littéral }
   If (temp_token <> '') and (temp_token[1] >= '0') and (temp_token[1] <= '9') Then
   Begin
    { Générer l'opération }
    Case comparison_op of
     SYM_PLUS: 
      Begin
       { Vérifier si c'est une concaténation de chaînes }
       If left_type = TYPE_STRING Then
       Begin
        { Concaténation de chaînes - pour l'instant on génère un appel de fonction }
        EmitComment('Concaténation de chaînes');
        Emit('call CONCAT_STR');
       End
       Else If left_operand = 'ax' Then
        Emit('add ax, ' + temp_token)
       Else
        Emit('add al, ' + temp_token);
      End;
     SYM_MINUS:
      Begin
       If left_operand = 'ax' Then
        Emit('sub ax, ' + temp_token)
       Else
        Emit('sub al, ' + temp_token);
      End;
     SYM_MULTIPLY:
      Begin
       If left_operand = 'ax' Then
       Begin
        Emit('mov bx, ' + temp_token);
        Emit('mul bx');
       End
       Else
       Begin
        Emit('mov bl, ' + temp_token);
        Emit('mul bl');
       End;
      End;
     SYM_DIVIDE:
      Begin
       If left_operand = 'ax' Then
       Begin
        Emit('mov bx, ' + temp_token);
        Emit('div bx');
       End
       Else
       Begin
        Emit('mov bl, ' + temp_token);
        Emit('div bl');
       End;
      End;
     SYM_AND:
      Begin
       If left_operand = 'ax' Then
        Emit('and ax, ' + temp_token)
       Else
        Emit('and al, ' + temp_token);
      End;
     SYM_OR:
      Begin
       If left_operand = 'ax' Then
        Emit('or ax, ' + temp_token)
       Else
        Emit('or al, ' + temp_token);
      End;
     SYM_XOR:
      Begin
       If left_operand = 'ax' Then
        Emit('xor ax, ' + temp_token)
       Else
        Emit('xor al, ' + temp_token);
      End;
    End;
    NextToken;
   End
   Else If temp_token <> '' Then
   Begin
    { Variable - chercher dans la table des symboles }
    sym_index := FindSymbol(temp_token);
    If sym_index > 0 Then
    Begin
     Case comparison_op of
      SYM_PLUS:
       Begin
        { Vérifier si c'est une concaténation de chaînes }
        If (left_type = TYPE_STRING) and (symbol_table[sym_index]^.data_type = TYPE_STRING) Then
        Begin
         EmitComment('Concaténation de chaînes');
         Emit('mov di, OFFSET ' + symbol_table[sym_index]^.name);
         Emit('call CONCAT_STR'); { Appel de fonction de concaténation }
        End
        Else If left_operand = 'ax' Then
         Emit('add ax, ' + symbol_table[sym_index]^.name)
        Else
         Emit('add al, ' + symbol_table[sym_index]^.name);
       End;
      SYM_MINUS:
       Begin
        If left_operand = 'ax' Then
         Emit('sub ax, ' + symbol_table[sym_index]^.name)
        Else
         Emit('sub al, ' + symbol_table[sym_index]^.name);
       End;
      SYM_MULTIPLY:
       Begin
        If left_operand = 'ax' Then
        Begin
         Emit('mov bx, ' + symbol_table[sym_index]^.name);
         Emit('mul bx');
        End
        Else
        Begin
         Emit('mov bl, ' + symbol_table[sym_index]^.name);
         Emit('mul bl');
        End;
       End;
      SYM_DIVIDE:
       Begin
        If left_operand = 'ax' Then
        Begin
         Emit('mov bx, ' + symbol_table[sym_index]^.name);
         Emit('div bx');
        End
        Else
        Begin
         Emit('mov bl, ' + symbol_table[sym_index]^.name);
         Emit('div bl');
        End;
       End;
      SYM_AND:
       Begin
        If left_operand = 'ax' Then
         Emit('and ax, ' + symbol_table[sym_index]^.name)
        Else
         Emit('and al, ' + symbol_table[sym_index]^.name);
       End;
      SYM_OR:
       Begin
        If left_operand = 'ax' Then
         Emit('or ax, ' + symbol_table[sym_index]^.name)
        Else
         Emit('or al, ' + symbol_table[sym_index]^.name);
       End;
      SYM_XOR:
       Begin
        If left_operand = 'ax' Then
         Emit('xor ax, ' + symbol_table[sym_index]^.name)
        Else
         Emit('xor al, ' + symbol_table[sym_index]^.name);
       End;
     End;
    End
    Else
     Error('Variable non déclarée: ' + temp_token);
    NextToken;
   End;
   
   left_operand := 'ax'; { Le résultat est toujours dans AX }
  End;
 End;
 
 { Vérifier s'il y a un opérateur de comparaison }
 comparison_op := current_symbol;
 If (comparison_op = SYM_EQUAL) or (comparison_op = SYM_NOTEQUAL) or 
    (comparison_op = SYM_LESS) or (comparison_op = SYM_GREATER) or
    (comparison_op = SYM_LESSEQ) or (comparison_op = SYM_GREATEREQ) Then
 Begin
  NextToken; { Consommer l'opérateur }
  
  { Parser le deuxième opérande }
  If current_symbol = SYM_UNKNOWN Then
  Begin
   temp_token := current_token;
   
   { Nombre littéral }
   If (temp_token <> '') and (temp_token[1] >= '0') and (temp_token[1] <= '9') Then
   Begin
    If left_operand = 'ax' Then
     Emit('cmp ax, ' + temp_token)
    Else
     Emit('cmp al, ' + temp_token);
    NextToken;
   End
   Else If temp_token <> '' Then
   Begin
    { Variable }
    sym_index := FindSymbol(temp_token);
    If sym_index > 0 Then
    Begin
     Case symbol_table[sym_index]^.data_type of
      TYPE_INTEGER, TYPE_WORD:
       Begin
        If left_operand = 'ax' Then
         Emit('cmp ax, ' + symbol_table[sym_index]^.name)
        Else
        Begin
         Emit('mov bx, ' + symbol_table[sym_index]^.name);
         Emit('cmp al, bl');
        End;
       End;
      TYPE_BYTE, TYPE_CHAR:
       Begin
        If left_operand = 'al' Then
         Emit('cmp al, ' + symbol_table[sym_index]^.name)
        Else
        Begin
         Emit('mov bl, ' + symbol_table[sym_index]^.name);
         Emit('cmp ax, bx');
        End;
       End;
     Else
      Begin
       If left_operand = 'ax' Then
        Emit('cmp ax, ' + symbol_table[sym_index]^.name)
       Else
        Emit('cmp al, ' + symbol_table[sym_index]^.name);
      End;
     End;
    End
    Else
     Error('Variable non déclarée: ' + temp_token);
    NextToken;
   End;
   
   { Générer le code conditionnel selon l'opérateur }
   Case comparison_op of
    SYM_EQUAL: 
     Begin
      Emit('mov ax, 1');
      Emit('je COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
    SYM_NOTEQUAL:
     Begin
      Emit('mov ax, 1');
      Emit('jne COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
    SYM_LESS:
     Begin
      Emit('mov ax, 1');
      Emit('jl COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
    SYM_GREATER:
     Begin
      Emit('mov ax, 1');
      Emit('jg COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
    SYM_LESSEQ:
     Begin
      Emit('mov ax, 1');
      Emit('jle COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
    SYM_GREATEREQ:
     Begin
      Emit('mov ax, 1');
      Emit('jge COMP_TRUE_' + IntToStr(next_label_id));
      Emit('mov ax, 0');
      EmitLabel('COMP_TRUE_' + IntToStr(next_label_id));
      Inc(next_label_id);
     End;
   End;
  End;
 End;
End;

{ Parser une instruction d'affectation }
Procedure ParseAssignment(var_name: String);
Var
 sym_index: Integer;
 string_temp: String;
 is_string_assignment: Boolean;
Begin
 sym_index := FindSymbol(var_name);
 If sym_index = 0 Then
 Begin
  Error('Variable non déclarée: ' + var_name);
  NextToken; { Consommer le token pour éviter la boucle infinie }
  Exit;
 End;

 { Attendre := }
 NextToken; { Consommer l'identificateur de variable }
 If current_token = ':=' Then
 Begin
  NextToken; { Consommer := }
  
  { Vérifier si c'est une affectation de chaîne littérale }
  is_string_assignment := False;
  If (symbol_table[sym_index]^.data_type = TYPE_STRING) Then
  Begin
   { Pour une variable string, vérifier si on a une chaîne littérale en cours }
   string_temp := current_token;
   { Considérer que c'est une chaîne littérale si ce n'est pas un nombre }
   If (Length(string_temp) > 0) and 
      not ((string_temp[1] >= '0') and (string_temp[1] <= '9')) Then
   Begin
    is_string_assignment := True;
   End;
  End;
  
  If is_string_assignment Then
  Begin
   { Affectation de chaîne littérale }
   EmitComment('Affectation chaîne: ' + var_name + ' := ''' + string_temp + '''');
   
   { Stocker la longueur d'abord (format Pascal) }
   Emit('mov al, ' + IntToStr(Length(string_temp)));
   Emit('mov ' + symbol_table[sym_index]^.name + ', al');
   
   { Copier les caractères si la chaîne n'est pas vide }
   If Length(string_temp) > 0 Then
   Begin
    { Générer la chaîne constante dans le segment de données }
    If not data_segment Then
    Begin
     EmitLine('.DATA');
     data_segment := True;
    End;
    
    EmitLine('STR_CONST' + IntToStr(next_label_id) + ' DB ''' + string_temp + '''');
    
    { Retour au segment de code }
    If not code_segment Then
     BeginCodeSection;
    
    { Copier les caractères }
    Emit('mov si, OFFSET STR_CONST' + IntToStr(next_label_id));
    Emit('mov di, OFFSET ' + symbol_table[sym_index]^.name + '+1');
    Emit('mov cx, ' + IntToStr(Length(string_temp)));
    Emit('rep movsb');
    
    Inc(next_label_id);
   End;
   
   NextToken; { Consommer la chaîne }
  End
  Else
  Begin
   ParseExpression;

   { Vérifier si c'est une affectation au résultat d'une fonction }
   If symbol_table[sym_index]^.is_function and (symbol_table[sym_index]^.name = current_function_name) Then
   Begin
    { Affectation au résultat de la fonction }
    EmitComment('Affectation résultat fonction: ' + var_name);
    Case symbol_table[sym_index]^.return_type of
     TYPE_INTEGER, TYPE_WORD: 
      Begin
       Emit('mov [bp-2], ax');  { Stocker le résultat dans l'espace local }
      End;
     TYPE_BYTE, TYPE_CHAR: 
      Begin
       Emit('mov [bp-2], al');
      End;
     TYPE_STRING:
      Begin
       { Pour les chaînes, copier depuis SI vers l'espace local }
       Emit('mov di, [bp-2]');
       Emit('call COPY_STR');
      End;
    Else
     Begin
      Emit('mov [bp-2], ax');
     End;
    End;
   End
   Else
   Begin
    { Générer le code d'affectation normal }
    Case symbol_table[sym_index]^.data_type of
     TYPE_INTEGER, TYPE_WORD: Emit('mov ' + symbol_table[sym_index]^.name + ', ax');
     TYPE_BYTE, TYPE_CHAR: Emit('mov ' + symbol_table[sym_index]^.name + ', al');
     TYPE_STRING: 
      Begin
       EmitComment('Copie de chaîne');
       Emit('mov di, OFFSET ' + symbol_table[sym_index]^.name);
       Emit('call COPY_STR'); { SI -> DI }
      End;
    Else
     Emit('mov ' + symbol_table[sym_index]^.name + ', ax');
    End;
   End;
  End;
 End
 Else
 Begin
  Error('Attendu := pour l''affectation, trouvé: ' + current_token);
  NextToken; { Consommer le token erroné pour éviter la boucle infinie }
 End;
End;

{ Parser une instruction WRITE (sans saut de ligne) }
Procedure ParseWrite;
Var
 i, sym_index: Integer;
 is_string: Boolean;
 var_name: String;
Begin
 NextToken; { Consommer WRITE }

 If current_token = '(' Then
 Begin
  NextToken;

  { Traitement des paramètres multiples séparés par des virgules }
  Repeat
   is_string := False;
   
   { Vérifier si c'est une chaîne littérale (entre guillemets) }
   If (current_symbol = SYM_UNKNOWN) and (Length(current_token) > 0) and 
      (Pos('''', current_line) > 0) Then
   Begin
    { Chaîne littérale }
    is_string := True;
    EmitComment('Affichage chaîne (Write): ' + current_token);
    
    { Optimisation: utiliser l'interruption DOS 09h pour les chaînes }
    If Length(current_token) > 0 Then
    Begin
     { Générer une étiquette de données pour la chaîne }
     If not data_segment Then
     Begin
      EmitLine('.DATA');
      data_segment := True;
     End;
     
     EmitLine('STR' + IntToStr(next_label_id) + ' DB ''' + current_token + '$''');
     
     { Retour au segment de code }
     If not code_segment Then
      BeginCodeSection;
      
     { Afficher la chaîne avec DOS function 09h }
     Emit('mov dx, OFFSET STR' + IntToStr(next_label_id));
     Emit('mov ah, 09h');
     Emit('int 21h');
     Inc(next_label_id);
    End;
    
    NextToken;
   End
   Else If (current_symbol = SYM_UNKNOWN) and (current_token <> '') Then
   Begin
    { Vérifier si c'est un nombre ou une variable }
    If (current_token[1] >= '0') and (current_token[1] <= '9') Then
    Begin
     { Nombre littéral }
     EmitComment('Affichage nombre (Write): ' + current_token);
     Emit('mov ax, ' + current_token);
     Emit('call PRINT_NUM');
    End
    Else
    Begin
     { Variable - vérifier dans la table des symboles }
     var_name := current_token;
     sym_index := FindSymbol(var_name);
     If sym_index > 0 Then
     Begin
      EmitComment('Affichage variable (Write): ' + var_name);
      Case symbol_table[sym_index]^.data_type of
       TYPE_INTEGER, TYPE_WORD:
        Begin
         Emit('mov ax, ' + symbol_table[sym_index]^.name);
         Emit('call PRINT_NUM');
        End;
       TYPE_BYTE:
        Begin
         Emit('mov al, ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 0');
         Emit('call PRINT_NUM');
        End;
       TYPE_CHAR:
        Begin
         Emit('mov dl, ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 02h');
         Emit('int 21h');
        End;
       TYPE_STRING:
        Begin
         EmitComment('Affichage variable chaîne (Write): ' + var_name);
         Emit('mov si, OFFSET ' + symbol_table[sym_index]^.name);
         Emit('call PRINT_STR');
        End;
       TYPE_BOOLEAN:
        Begin
         Emit('mov al, ' + symbol_table[sym_index]^.name);
         Emit('cmp al, 0');
         Emit('je FALSE_' + IntToStr(next_label_id));
         Emit('mov dx, OFFSET TRUE_STR');
         Emit('jmp BOOL_END_' + IntToStr(next_label_id));
         EmitLabel('FALSE_' + IntToStr(next_label_id));
         Emit('mov dx, OFFSET FALSE_STR');
         EmitLabel('BOOL_END_' + IntToStr(next_label_id));
         Emit('mov ah, 09h');
         Emit('int 21h');
         Inc(next_label_id);
        End;
      Else
       Begin
        Emit('mov ax, ' + symbol_table[sym_index]^.name);
        Emit('call PRINT_NUM');
       End;
      End;
     End
     Else
     Begin
      Error('Variable non déclarée: ' + var_name);
     End;
    End;
    
    NextToken;
   End;
   
   { Vérifier s'il y a d'autres paramètres }
   If current_token = ',' Then
   Begin
    NextToken;
    Continue; { Traiter le paramètre suivant }
   End
   Else
    Break; { Fin des paramètres }
    
  Until False;

  If current_token = ')' Then
   NextToken
  Else
   Error('Attendu ) après les paramètres de Write');
 End;
 
 { Pas de saut de ligne pour WRITE (contrairement à WRITELN) }
End;

{ Parser une instruction WRITELN }
Procedure ParseWriteln;
Var
 i, sym_index: Integer;
 is_string: Boolean;
 var_name: String;
Begin
 NextToken; { Consommer WRITELN }

 If current_token = '(' Then
 Begin
  NextToken;

  { Traitement des paramètres multiples séparés par des virgules }
  Repeat
   is_string := False;
   
   { Vérifier si c'est une chaîne littérale - détection améliorée }
   If (current_symbol = SYM_UNKNOWN) and (Length(current_token) > 0) and 
      (Length(current_line) > 0) and (line_pos > 1) and 
      (current_line[line_pos-Length(current_token)-1] = '''') Then
   Begin
    { Chaîne littérale }
    is_string := True;
    EmitComment('Affichage chaîne: ' + current_token);
    
    { Optimisation: utiliser l'interruption DOS 09h pour les chaînes }
    If Length(current_token) > 0 Then
    Begin
     { Générer une étiquette de données pour la chaîne }
     If not data_segment Then
     Begin
      EmitLine('.DATA');
      data_segment := True;
     End;
     
     EmitLine('STR' + IntToStr(next_label_id) + ' DB ''' + current_token + '$''');
     
     { Retour au segment de code }
     If not code_segment Then
      BeginCodeSection;
      
     { Afficher la chaîne avec DOS function 09h }
     Emit('mov dx, OFFSET STR' + IntToStr(next_label_id));
     Emit('mov ah, 09h');
     Emit('int 21h');
     Inc(next_label_id);
    End;
    
    NextToken;
   End
   Else If (current_symbol = SYM_UNKNOWN) and (current_token <> '') Then
   Begin
    { Vérifier si c'est un nombre ou une variable }
    If (current_token[1] >= '0') and (current_token[1] <= '9') Then
    Begin
     { Nombre littéral }
     EmitComment('Affichage nombre: ' + current_token);
     Emit('mov ax, ' + current_token);
     Emit('call PRINT_NUM');
    End
    Else
    Begin
     { Variable - vérifier dans la table des symboles }
     var_name := current_token;
     sym_index := FindSymbol(var_name);
     If sym_index > 0 Then
     Begin
      EmitComment('Affichage variable: ' + var_name);
      Case symbol_table[sym_index]^.data_type of
       TYPE_INTEGER, TYPE_WORD:
        Begin
         Emit('mov ax, ' + symbol_table[sym_index]^.name);
         Emit('call PRINT_NUM');
        End;
       TYPE_BYTE:
        Begin
         Emit('mov al, ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 0');
         Emit('call PRINT_NUM');
        End;
       TYPE_CHAR:
        Begin
         Emit('mov dl, ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 02h');
         Emit('int 21h');
        End;
       TYPE_STRING:
        Begin
         EmitComment('Affichage variable chaîne: ' + var_name);
         Emit('mov si, OFFSET ' + symbol_table[sym_index]^.name);
         Emit('call PRINT_STR');
        End;
       TYPE_BOOLEAN:
        Begin
         Emit('mov al, ' + symbol_table[sym_index]^.name);
         Emit('cmp al, 0');
         Emit('je FALSE_' + IntToStr(next_label_id));
         Emit('mov dx, OFFSET TRUE_STR');
         Emit('jmp BOOL_END_' + IntToStr(next_label_id));
         EmitLabel('FALSE_' + IntToStr(next_label_id));
         Emit('mov dx, OFFSET FALSE_STR');
         EmitLabel('BOOL_END_' + IntToStr(next_label_id));
         Emit('mov ah, 09h');
         Emit('int 21h');
         Inc(next_label_id);
        End;
      Else
       Begin
        Emit('mov ax, ' + symbol_table[sym_index]^.name);
        Emit('call PRINT_NUM');
       End;
      End;
     End
     Else
     Begin
      { Traiter comme chaîne littérale si non trouvé }
      EmitComment('Affichage chaîne: ' + current_token);
      If not data_segment Then
      Begin
       EmitLine('.DATA');
       data_segment := True;
      End;
      
      EmitLine('STR' + IntToStr(next_label_id) + ' DB ''' + current_token + '$''');
      
      If not code_segment Then
       BeginCodeSection;
       
      Emit('mov dx, OFFSET STR' + IntToStr(next_label_id));
      Emit('mov ah, 09h');
      Emit('int 21h');
      Inc(next_label_id);
     End;
    End;
    
    NextToken;
   End;
   
   { Vérifier s'il y a d'autres paramètres }
   If current_token = ',' Then
   Begin
    NextToken;
    Continue; { Traiter le paramètre suivant }
   End
   Else
    Break; { Fin des paramètres }
    
  Until False;

  If current_token = ')' Then
   NextToken
  Else
   Error('Attendu ) après les paramètres de WriteLn');
 End;

 { Générer saut de ligne pour WRITELN }
 Emit('mov dl, 13');
 Emit('mov ah, 02h');
 Emit('int 21h');
 Emit('mov dl, 10');
 Emit('mov ah, 02h');
 Emit('int 21h');
End;

{ Parser une instruction IF }
Procedure ParseIf;
Var
 else_label, end_label: String;
Begin
 NextToken; { Consommer IF }

 ParseExpression;

 Expect(SYM_THEN, 'Attendu THEN après IF');

 { Générer le code de test }
 else_label := NewLabel;
 end_label := NewLabel;

 Emit('cmp ax, 0');
 Emit('je ' + else_label);

 ParseStatement;

 If Accept(SYM_ELSE) Then
 Begin
  NextToken;
  Emit('jmp ' + end_label);
  EmitLabel(else_label);
  ParseStatement;
  EmitLabel(end_label);
 End
 Else
  EmitLabel(else_label);
End;

{ Parser une instruction REPEAT }
Procedure ParseRepeat;
Var
 start_label: String;
Begin
 NextToken; { Consommer REPEAT }

 start_label := NewLabel;
 EmitLabel(start_label);

 { Parser le corps de la boucle }
 While not Accept(SYM_UNTIL) and (current_char <> #0) do
 Begin
  ParseStatement;
  
  { Gérer les point-virgules optionnels }
  If current_token = ';' Then
   NextToken;
 End;

 { Traiter UNTIL }
 If Accept(SYM_UNTIL) Then
 Begin
  NextToken; { Consommer UNTIL }
  ParseExpression;
  
  { Générer le code de test - condition inversée par rapport à WHILE }
  Emit('cmp ax, 0');
  Emit('je ' + start_label); { Sauter au début si condition FAUSSE }
 End
 Else
  Error('Attendu UNTIL après REPEAT');
End;

{ Parser une instruction WHILE }
Procedure ParseWhile;
Var
 start_label, end_label: String;
Begin
 NextToken; { Consommer WHILE }

 start_label := NewLabel;
 end_label := NewLabel;

 EmitLabel(start_label);
 ParseExpression;

 Expect(SYM_DO, 'Attendu DO après WHILE');

 Emit('cmp ax, 0');
 Emit('je ' + end_label);

 ParseStatement;

 Emit('jmp ' + start_label);
 EmitLabel(end_label);
End;

{ Parser une boucle FOR }
Procedure ParseFor;
Var
 start_label, end_label, increment_label: String;
 var_name: String;
 is_downto: Boolean;
 sym_idx: Integer;
Begin
 NextToken; { Consommer FOR }
 
 { Lire la variable de contrôle }
 If current_symbol = SYM_UNKNOWN Then
 Begin
  var_name := current_token;
  sym_idx := FindSymbol(var_name);
  If sym_idx <= 0 Then
   Error('Variable de contrôle non déclarée: ' + var_name);
  NextToken;
 End
 Else
  Error('Attendu nom de variable après FOR');
  
 { Attendre := }
 If current_token = ':=' Then
  NextToken
 Else
  Error('Attendu := après nom de variable');
  
 { Analyser l'expression de départ }
 ParseExpression;
 Emit('mov [' + var_name + '], ax'); { Stocker valeur initiale }
 
 { Vérifier TO ou DOWNTO }
 If current_symbol = SYM_TO Then
 Begin
  is_downto := False;
  NextToken;
 End
 Else If current_symbol = SYM_DOWNTO Then
 Begin
  is_downto := True;
  NextToken;
 End
 Else
  Error('Attendu TO ou DOWNTO dans boucle FOR');
  
 { Analyser l'expression de fin }
 ParseExpression;
 Emit('mov bx, ax'); { Stocker valeur finale dans BX }
 
 { Attendre DO }
 Expect(SYM_DO, 'Attendu DO après expression finale');
 
 { Générer les étiquettes }
 start_label := NewLabel;
 increment_label := NewLabel;
 end_label := NewLabel;
 
 { Début de la boucle }
 EmitLabel(start_label);
 
 { Comparer la variable de contrôle avec la valeur finale }
 Emit('mov ax, [' + var_name + ']');
 Emit('cmp ax, bx');
 
 If is_downto Then
  Emit('jl ' + end_label) { Si var < limite_finale, sortir }
 Else  
  Emit('jg ' + end_label); { Si var > limite_finale, sortir }
 
 { Exécuter le corps de la boucle }
 ParseStatement;
 
 { Incrémenter ou décrémenter la variable de contrôle }
 EmitLabel(increment_label);
 Emit('mov ax, [' + var_name + ']');
 If is_downto Then
  Emit('dec ax')
 Else
  Emit('inc ax');
 Emit('mov [' + var_name + '], ax');
 
 { Retourner au début }
 Emit('jmp ' + start_label);
 EmitLabel(end_label);
End;

{ Parser une instruction CASE }
Procedure ParseCase;
Var
 end_label, else_label, case_label: String;
 case_value: Integer;
Begin
 NextToken; { Consommer CASE }
 
 { Analyser l'expression de sélection }
 ParseExpression;
 Emit('mov bx, ax'); { Stocker la valeur du case dans BX }
 
 { Attendre OF }
 Expect(SYM_OF, 'Attendu OF après expression CASE');
 
 { Générer les étiquettes }
 end_label := NewLabel;
 else_label := NewLabel;
 
 { Parser chaque cas }
 While (current_symbol <> SYM_END) and (current_symbol <> SYM_ELSE) and 
       (current_symbol <> SYM_OTHERWISE) and (current_char <> #0) do
 Begin
  { Lire la valeur du cas - c'est un nombre }
  If current_symbol = SYM_UNKNOWN Then
  Begin
   { Vérifier si c'est un nombre }
   If (current_token <> '') and (current_token[1] >= '0') and (current_token[1] <= '9') Then
   Begin
    case_value := current_value;
    NextToken;
    
    { Attendre : }
    If current_token = ':' Then
     NextToken
    Else
     Error('Attendu : après valeur de cas');
    
    { Générer l'étiquette pour ce cas }
    case_label := NewLabel;
    
    { Tester la valeur }
    Emit('cmp bx, ' + IntToStr(case_value));
    Emit('je ' + case_label);
    
    { Parser l'instruction }
    EmitLabel(case_label);
    ParseStatement;
    
    { Saut vers la fin après exécution du cas }
    Emit('jmp ' + end_label);
    
    { Point-virgule optionnel }
    If current_token = ';' Then
     NextToken;
   End
   Else
    NextToken; { Ignorer token non-numérique }
  End
  Else
   NextToken; { Ignorer autres symboles }
 End;
 
 { Si aucun cas n'a matché, aller au ELSE }
 Emit('jmp ' + else_label);
 
 { Gérer ELSE ou OTHERWISE }
 If Accept(SYM_ELSE) or Accept(SYM_OTHERWISE) Then
 Begin
  NextToken; { Consommer ELSE/OTHERWISE }
  EmitLabel(else_label);
  ParseStatement;
  
  { Point-virgule optionnel après ELSE }
  If current_token = ';' Then
   NextToken;
 End
 Else
 Begin
  { Pas d'ELSE - juste une étiquette vide }
  EmitLabel(else_label);
 End;
 
 { Attendre END }
 Expect(SYM_END, 'Attendu END pour fermer CASE');
 
 { Étiquette de fin }
 EmitLabel(end_label);
End;

{ Parser une instruction }
Procedure ParseStatement;
Var
 sym_idx: Integer;
Begin
 Case current_symbol of
  SYM_BEGIN:
   Begin
    NextToken; { Consommer BEGIN }

    While not Accept(SYM_END) and (current_char <> #0) do
    Begin
     If current_symbol <> SYM_UNKNOWN Then
      ParseStatement
     Else If current_token <> '' Then
     Begin
      { C'est peut-être une affectation ou une instruction inconnue }
      sym_idx := FindSymbol(current_token);
      If (sym_idx > 0) and (symbol_table[sym_idx]^.symbol_type = SYM_PROCEDURE) Then
      Begin
       { Appel de procédure }
       EmitComment('Appel procédure: ' + current_token);
       NextToken; { Consommer le nom de la procédure }
       
       { Gérer les paramètres (pour l'instant, on ignore) }
       If current_token = '(' Then
       Begin
        NextToken;
        While (current_token <> ')') and (current_char <> #0) do
         NextToken;
        If current_token = ')' Then
         NextToken;
       End;
       
       { Générer l'appel }
       Emit('call ' + symbol_table[sym_idx]^.name);
      End
      Else If (sym_idx > 0) and (symbol_table[sym_idx]^.symbol_type = SYM_INTERRUPT) Then
      Begin
       { Appel d'interruption }
       EmitComment('Appel interruption: ' + current_token);
       NextToken; { Consommer le nom de l'interruption }
       
       { Gérer les paramètres (pour l'instant, on ignore) }
       If current_token = '(' Then
       Begin
        NextToken;
        While (current_token <> ')') and (current_char <> #0) do
         NextToken;
        If current_token = ')' Then
         NextToken;
       End;
       
       { Générer l'appel }
       Emit('call ' + symbol_table[sym_idx]^.name);
      End
      Else If sym_idx > 0 Then
      Begin
       ParseAssignment(current_token); { ParseAssignment gérera NextToken }
      End
      Else If current_symbol = SYM_WRITELN Then
       ParseWriteln
      Else If current_symbol = SYM_WRITE Then
       ParseWrite
      Else
      Begin
       NextToken; { Ignorer et continuer }
      End;
     End
     Else
      NextToken;

     { Gérer les point-virgules optionnels }
     If current_token = ';' Then
      NextToken;
    End;

    If Accept(SYM_END) Then
     NextToken { Consommer END }
    Else
     Error('Attendu END');
   End;

  SYM_IF:
   ParseIf;

  SYM_WHILE:
   ParseWhile;

  SYM_FOR:
   ParseFor;

  SYM_CASE:
   ParseCase;

  SYM_REPEAT:
   ParseRepeat;

  SYM_WRITE:
   ParseWrite;

  SYM_WRITELN:
   ParseWriteln;

  SYM_UNKNOWN:
   Begin
    If current_token <> '' Then
    Begin
     { Vérifier d'abord si c'est un appel de procédure }
     sym_idx := FindSymbol(current_token);
     If (sym_idx > 0) and (symbol_table[sym_idx]^.symbol_type = SYM_PROCEDURE) Then
     Begin
      { Appel de procédure }
      EmitComment('Appel procédure: ' + current_token);
      NextToken; { Consommer le nom de la procédure }
      
      { Gérer les paramètres (pour l'instant, on ignore) }
      If current_token = '(' Then
      Begin
       NextToken;
       While (current_token <> ')') and (current_char <> #0) do
        NextToken;
       If current_token = ')' Then
        NextToken;
      End;
      
      { Générer l'appel }
      Emit('call ' + symbol_table[sym_idx]^.name);
     End
     Else If (sym_idx > 0) and (symbol_table[sym_idx]^.symbol_type = SYM_INTERRUPT) Then
     Begin
      { Appel d'interruption }
      EmitComment('Appel interruption: ' + current_token);
      NextToken; { Consommer le nom de l'interruption }
      
      { Gérer les paramètres (pour l'instant, on ignore) }
      If current_token = '(' Then
      Begin
       NextToken;
       While (current_token <> ')') and (current_char <> #0) do
        NextToken;
       If current_token = ')' Then
        NextToken;
      End;
      
      { Générer l'appel }
      Emit('call ' + symbol_table[sym_idx]^.name);
     End
     { Peut-être une affectation }
     Else If sym_idx > 0 Then
     Begin
      ParseAssignment(current_token); { ParseAssignment gérera NextToken }
     End
     Else
      NextToken; { Ignorer token inconnu }
    End
    Else
     NextToken;
   End;

  Else
   NextToken; { Ignorer les autres tokens }
 End;
End;

{ Parser les déclarations de variables }
Procedure ParseVarDeclarations;
Var
 var_names: Array[1..50] of String;
 var_count: Integer;
 var_type: Integer;
 type_name: String;
 i, sym_index: Integer;
Begin
 NextToken; { Consommer VAR }

 While (current_symbol = SYM_UNKNOWN) and (current_token <> '') do
 Begin
  { Lire les noms de variables }
  var_count := 0;
  Repeat
   If current_symbol = SYM_UNKNOWN Then
   Begin
    Inc(var_count);
    var_names[var_count] := current_token;
    NextToken;
   End
   Else
   Begin
    Error('Attendu nom de variable');
    Break;
   End;

   If current_token = ',' Then
    NextToken
   Else
    Break;
  Until False;

  { Attendre le deux-points }
  If current_token = ':' Then
   NextToken
  Else
   Error('Attendu : après nom de variable');

  { Lire le type }
  If current_symbol = SYM_UNKNOWN Then
  Begin
   type_name := UpperCase(current_token);
   If type_name = 'INTEGER' Then var_type := TYPE_INTEGER
   Else If type_name = 'BYTE' Then var_type := TYPE_BYTE
   Else If type_name = 'WORD' Then var_type := TYPE_WORD
   Else If type_name = 'STRING' Then var_type := TYPE_STRING
   Else If type_name = 'CHAR' Then var_type := TYPE_CHAR
   Else If type_name = 'BOOLEAN' Then var_type := TYPE_BOOLEAN
   Else
   Begin
    { Vérifier si c'est un type défini par l'utilisateur }
    sym_index := FindSymbol(type_name);
    If (sym_index > 0) and (symbol_table[sym_index]^.symbol_type = SYM_TYPE) Then
    Begin
     { C'est un type défini par l'utilisateur }
     var_type := symbol_table[sym_index]^.data_type;
    End
    Else
    Begin
     Error('Type inconnu: ' + type_name);
     var_type := TYPE_INTEGER;
    End;
   End;
   NextToken;
  End
  Else
  Begin
   Error('Attendu type de variable');
   var_type := TYPE_INTEGER;
  End;

  { Ajouter les variables à la table des symboles }
  For i := 1 to var_count do
  Begin
   sym_index := AddSymbol(var_names[i], SYM_VAR, var_type, STORAGE_GLOBAL);
   If sym_index > 0 Then
    GenerateVariableDeclaration(var_names[i], var_type);
  End;

  { Attendre le point-virgule }
  If current_token = ';' Then
   NextToken
  Else
   Error('Attendu ; après déclaration de variable');
 End;
End;

{ Parser les déclarations de types }
Procedure ParseTypeDeclarations;
Var
 type_name: String;
 record_index: Integer;
 field_names: Array[1..50] of String;
 field_types: Array[1..50] of Integer;
 field_count: Integer;
 field_type: Integer;
 type_name_field: String;
 i: Integer;
 current_offset: Integer;
 sym_index: Integer;  { Variable manquante ajoutée }
Begin
 NextToken; { Consommer TYPE }

 While (current_symbol = SYM_UNKNOWN) and (current_token <> '') do
 Begin
  { Lire le nom du type }
  If current_symbol = SYM_UNKNOWN Then
  Begin
   type_name := current_token;
   NextToken;
  End
  Else
  Begin
   Error('Attendu nom de type');
   Break;
  End;

  { Attendre le signe = }
  If current_token = '=' Then
   NextToken
  Else
   Error('Attendu = après nom de type');

  { Vérifier si c'est un RECORD }
  If Accept(SYM_RECORD) Then
  Begin
   NextToken; { Consommer RECORD }
   
   { Créer le type record dans la table des symboles }
   record_index := AddRecord(type_name, 0); { Taille calculée plus tard }
   current_offset := 0;

   { Lire les champs du record }
   While not Accept(SYM_END) and (current_char <> #0) do
   Begin
    { Lire les noms de champs }
    field_count := 0;
    Repeat
     If current_symbol = SYM_UNKNOWN Then
     Begin
      Inc(field_count);
      field_names[field_count] := current_token;
      NextToken;
     End
     Else
     Begin
      Error('Attendu nom de champ');
      Break;
     End;

     If current_token = ',' Then
      NextToken
     Else
      Break;
    Until False;

    { Attendre le deux-points }
    If current_token = ':' Then
     NextToken
    Else
     Error('Attendu : après nom de champ');

    { Lire le type du champ }
    If current_symbol = SYM_UNKNOWN Then
    Begin
     type_name_field := UpperCase(current_token);
     If type_name_field = 'INTEGER' Then field_type := TYPE_INTEGER
     Else If type_name_field = 'BYTE' Then field_type := TYPE_BYTE
     Else If type_name_field = 'WORD' Then field_type := TYPE_WORD
     Else If type_name_field = 'STRING' Then field_type := TYPE_STRING
     Else If type_name_field = 'CHAR' Then field_type := TYPE_CHAR
     Else If type_name_field = 'BOOLEAN' Then field_type := TYPE_BOOLEAN
     Else
     Begin
      Error('Type de champ inconnu: ' + type_name_field);
      field_type := TYPE_INTEGER;
     End;
     NextToken;
    End
    Else
    Begin
     Error('Attendu type de champ');
     field_type := TYPE_INTEGER;
    End;

    { Ajouter les champs à la table des symboles }
    For i := 1 to field_count do
    Begin
     AddRecordField(field_names[i], field_type, record_index, current_offset);
     
     { Calculer l'offset suivant }
     Case field_type of
      TYPE_INTEGER, TYPE_WORD: Inc(current_offset, 2);
      TYPE_BYTE, TYPE_CHAR, TYPE_BOOLEAN: Inc(current_offset, 1);
      TYPE_STRING: Inc(current_offset, 256);
     Else
      Inc(current_offset, 2);
     End;
    End;

    { Attendre le point-virgule }
    If current_token = ';' Then
     NextToken
    Else If not Accept(SYM_END) Then
     Error('Attendu ; après déclaration de champ');
   End;

   { Consommer END }
   If Accept(SYM_END) Then
    NextToken
   Else
    Error('Attendu END après déclaration de RECORD');

   { Mettre à jour la taille du record }
   If record_index > 0 Then
    symbol_table[record_index]^.record_size := current_offset;
  End
  { Vérifier si c'est un type ARRAY }
  Else If Accept(SYM_ARRAY) Then
  Begin
   NextToken; { Consommer ARRAY }
   
   { Pour l'instant, on traite les arrays comme des types simples }
   { TODO: Implémenter le parsing complet des arrays }
   While (current_token <> ';') and (current_char <> #0) do
    NextToken;
    
   { Créer un type array basique }
   AddSymbol(type_name, SYM_TYPE, TYPE_ARRAY, STORAGE_GLOBAL);
  End
  Else
  Begin
   { Type alias - référence à un autre type }
   If current_symbol = SYM_UNKNOWN Then
   Begin
    type_name_field := UpperCase(current_token);
    If type_name_field = 'INTEGER' Then
     AddTypeAlias(type_name, TYPE_INTEGER)
    Else If type_name_field = 'BYTE' Then
     AddTypeAlias(type_name, TYPE_BYTE)
    Else If type_name_field = 'WORD' Then
     AddTypeAlias(type_name, TYPE_WORD)
    Else If type_name_field = 'STRING' Then
     AddTypeAlias(type_name, TYPE_STRING)
    Else If type_name_field = 'CHAR' Then
     AddTypeAlias(type_name, TYPE_CHAR)
    Else If type_name_field = 'BOOLEAN' Then
     AddTypeAlias(type_name, TYPE_BOOLEAN)
    Else
    Begin
     { Vérifier si c'est une référence à un type défini }
     sym_index := FindSymbol(type_name_field);
     If sym_index > 0 Then
      AddTypeAlias(type_name, symbol_table[sym_index]^.data_type)
     Else
     Begin
      Error('Type de référence inconnu: ' + type_name_field);
      AddTypeAlias(type_name, TYPE_INTEGER);
     End;
    End;
    NextToken;
   End
   Else
   Begin
    { Types simples non supportés pour l'instant }
    Error('Type non supporté');
    While (current_token <> ';') and (current_char <> #0) do
     NextToken;
   End;
  End;

  { Attendre le point-virgule final }
  If current_token = ';' Then
   NextToken
  Else
   Error('Attendu ; après déclaration de type');
 End;
End;

{ Parser une déclaration de fonction }
Procedure ParseFunctionDeclaration;
Var
 func_name: String;
 return_type: Integer;
 type_name: String;
 sym_index: Integer;
 begin_count: Integer;
Begin
 NextToken; { Consommer FUNCTION }

 { Lire le nom de la fonction }
 If current_symbol = SYM_UNKNOWN Then
 Begin
  func_name := current_token;
  NextToken;
 End
 Else
 Begin
  Error('Attendu nom de fonction');
  Exit;
 End;

 { Ignorer les paramètres pour l'instant }
 If current_token = '(' Then
 Begin
  NextToken;
  While (current_token <> ')') and (current_char <> #0) do
   NextToken;
  If current_token = ')' Then
   NextToken;
 End;

 { Attendre le deux-points pour le type de retour }
 If current_token = ':' Then
  NextToken
 Else
  Error('Attendu : après nom de fonction');

 { Lire le type de retour }
 If current_symbol = SYM_UNKNOWN Then
 Begin
  type_name := UpperCase(current_token);
  If type_name = 'INTEGER' Then return_type := TYPE_INTEGER
  Else If type_name = 'BYTE' Then return_type := TYPE_BYTE  
  Else If type_name = 'WORD' Then return_type := TYPE_WORD
  Else If type_name = 'STRING' Then return_type := TYPE_STRING
  Else If type_name = 'CHAR' Then return_type := TYPE_CHAR
  Else If type_name = 'BOOLEAN' Then return_type := TYPE_BOOLEAN
  Else
  Begin
   Error('Type de retour inconnu: ' + type_name);
   return_type := TYPE_INTEGER;
  End;
  NextToken;
 End
 Else
 Begin
  Error('Attendu type de retour');
  return_type := TYPE_INTEGER;
 End;

 { Attendre le point-virgule }
 If current_token = ';' Then
  NextToken
 Else
  Error('Attendu ; après déclaration de fonction');

 { Ajouter la fonction à la table des symboles }
 sym_index := AddFunction(func_name, return_type);
 
 { Configurer l'état pour la fonction }
 current_function_name := UpperCase(func_name);
 current_function_type := return_type;
 in_function := True;

 { Ignorer toute déclaration VAR locale }
 While Accept(SYM_VAR) do
 Begin
  NextToken; { Consommer VAR }
  { Ignorer jusqu'au prochain BEGIN }
  While (current_symbol <> SYM_BEGIN) and (current_char <> #0) do
   NextToken;
 End;

 { Parser le corps de la fonction - pour l'instant on l'ignore mais on compte les BEGIN/END }
 If Accept(SYM_BEGIN) Then
 Begin
  NextToken; { Consommer BEGIN }
  
  begin_count := 1;
  While (begin_count > 0) and (current_char <> #0) do
  Begin
   If Accept(SYM_BEGIN) Then
    Inc(begin_count)
   Else If Accept(SYM_END) Then
    Dec(begin_count);
   
   NextToken;
  End;
 End;

 { Attendre le point-virgule final }
 If current_token = ';' Then
  NextToken;

 { Réinitialiser l'état }
 current_function_name := '';
 in_function := False;
End;

{ Parser une déclaration de procédure }
Procedure ParseProcedureDeclaration;
Var
 proc_name: String;
 sym_index: Integer;
 begin_count: Integer;
 is_interrupt: Boolean;
Begin
 NextToken; { Consommer PROCEDURE }
 is_interrupt := False;

 { Lire le nom de la procédure }
 If current_symbol = SYM_UNKNOWN Then
 Begin
  proc_name := current_token;
  NextToken;
 End
 Else
 Begin
  Error('Attendu nom de procédure');
  Exit;
 End;

 { Ignorer les paramètres pour l'instant }
 If current_token = '(' Then
 Begin
  NextToken;
  While (current_token <> ')') and (current_char <> #0) do
   NextToken;
  If current_token = ')' Then
   NextToken;
 End;

 { Vérifier si c'est une procédure d'interruption }
 If UpperCase(current_token) = 'INTERRUPT' Then
 Begin
  is_interrupt := True;
  NextToken; { Consommer INTERRUPT }
 End;

 { Attendre le point-virgule }
 If current_token = ';' Then
  NextToken
 Else
  Error('Attendu ; après déclaration de procédure');

 { Ajouter la procédure à la table des symboles }
 If is_interrupt Then
  sym_index := AddInterrupt(proc_name)
 Else
  sym_index := AddProcedure(proc_name);
 
 { Configurer l'état pour la procédure }
 current_function_name := UpperCase(proc_name);
 current_function_type := TYPE_INTEGER; { Pas utilisé }
 in_function := True; { Utilise le même flag pour les procédures }

 { Ignorer toute déclaration VAR locale }
 While Accept(SYM_VAR) do
 Begin
  NextToken; { Consommer VAR }
  { Ignorer jusqu'au prochain BEGIN }
  While (current_symbol <> SYM_BEGIN) and (current_char <> #0) do
   NextToken;
 End;

 { Parser le corps de la procédure - pour l'instant on l'ignore mais on compte les BEGIN/END }
 If Accept(SYM_BEGIN) Then
 Begin
  NextToken; { Consommer BEGIN }
  
  begin_count := 1;
  While (begin_count > 0) and (current_char <> #0) do
  Begin
   If Accept(SYM_BEGIN) Then
    Inc(begin_count)
   Else If Accept(SYM_END) Then
    Dec(begin_count);
   
   NextToken;
  End;
 End;

 { Attendre le point-virgule final }
 If current_token = ';' Then
  NextToken;

 { Réinitialiser l'état }
 current_function_name := '';
 in_function := False;
End;

{ Parser un bloc Pascal }
Procedure ParseBlock;
Begin
 { Gérer les déclarations TYPE }
 If Accept(SYM_TYPE) Then
  ParseTypeDeclarations;

 { Gérer les déclarations VAR }
 If Accept(SYM_VAR) Then
  ParseVarDeclarations;

 { Gérer les déclarations FUNCTION }
 While Accept(SYM_FUNCTION) do
  ParseFunctionDeclaration;

 { Gérer les déclarations PROCEDURE (y compris INTERRUPT) }
 While Accept(SYM_PROCEDURE) do
  ParseProcedureDeclaration;

 { Gérer le BEGIN principal }
 If Accept(SYM_BEGIN) Then
 Begin
  BeginCodeSection;
  ParseStatement;
 End
 Else
  Error('Attendu BEGIN');
End;

{ Parser un programme Pascal }
Procedure ParseProgram;
Var
 program_name: String;
Begin
 { En-tête PROGRAM }
 If Accept(SYM_PROGRAM) Then
 Begin
  NextToken; { Consommer PROGRAM }
  
  If current_symbol = SYM_UNKNOWN Then
  Begin
   program_name := current_token;
   EmitComment('Programme: ' + program_name);
   NextToken; { Consommer le nom }
   
   { Gérer les paramètres optionnels du programme }
   If current_token = '(' Then
   Begin
    NextToken; { Consommer ( }
    EmitComment('Paramètres du programme:');
    
    { Ignorer les paramètres pour l'instant }
    While (current_token <> ')') and (current_char <> #0) do
    Begin
     If current_symbol = SYM_UNKNOWN Then
      EmitComment('  - ' + current_token);
     NextToken;
     
     { Gérer les virgules }
     If current_token = ',' Then
      NextToken;
    End;
    
    If current_token = ')' Then
     NextToken
    Else
     Error('Attendu ) après paramètres du programme');
   End;
   
   If current_token = ';' Then
    NextToken
   Else
    Error('Attendu ; après nom de programme');
  End
  Else
   Error('Attendu nom de programme');
 End
 Else
 Begin
  { Programme sans en-tête PROGRAM - accepté mais avec avertissement }
  Warning('Programme sans en-tête PROGRAM - assumé programme principal');
  EmitComment('Programme: (sans nom)');
 End;

 { Gérer les déclarations USES optionnelles }
 While Accept(SYM_USES) do
 Begin
  NextToken; { Consommer USES }
  EmitComment('Unités utilisées:');
  
  Repeat
   If current_symbol = SYM_UNKNOWN Then
   Begin
    EmitComment('  - Unité: ' + current_token);
    NextToken;
   End
   Else
   Begin
    Error('Attendu nom d''unité après USES');
    Break;
   End;
   
   { Gérer les virgules }
   If current_token = ',' Then
   Begin
    NextToken;
    Continue;
   End
   Else
    Break;
  Until False;
  
  If current_token = ';' Then
   NextToken
  Else
   Error('Attendu ; après déclaration USES');
 End;

 GenerateHeader;

 { Parser le bloc principal }
 ParseBlock;

 { Attendre le point final }
 If current_symbol = SYM_DOT Then
  NextToken
 Else
  Error('Attendu . à la fin du programme');

 GenerateFooter;
End;

{ ============================================================================ }
{ PROCÉDURES D'INITIALISATION ET PRINCIPALE                                   }
{ ============================================================================ }

{ Initialiser le compilateur }
Procedure InitCompiler;
Var
 i: Integer;
Begin
 { Initialiser les tables de symboles et d'étiquettes }
 For i := 1 to MAX_SYMBOLS do
  symbol_table[i] := nil;
 For i := 1 to MAX_LABEL_COUNT do
  label_table[i] := nil;
  label_table[i] := nil;
  
 symbol_count := 0;
 label_count := 0;
 next_label_id := 0;
 error_count := 0;
 line_number := 1;
 line_pos := 1;
 current_char := ' ';
 code_segment := False;
 data_segment := False;
 stack_offset := 0;
 current_function_name := '';
 current_function_type := TYPE_INTEGER;
 in_function := False;
End;

{ Libérer la mémoire allouée }
Procedure CleanupCompiler;
Var
 i: Integer;
Begin
 { Libérer les symboles }
 For i := 1 to symbol_count do
  If symbol_table[i] <> nil Then
   Dispose(symbol_table[i]);
   
 { Libérer les étiquettes }
 For i := 1 to label_count do
  If label_table[i] <> nil Then
   Dispose(label_table[i]);
End;

{ Générer les procédures d'aide (comme PRINT_NUM) }
Procedure GenerateHelpProcedures;
Begin
 EmitLine('');
 EmitComment('Procédures d''aide pour l''affichage');
 
 { Procédure pour afficher un nombre entier }
 EmitLine('PRINT_NUM PROC');
 EmitComment('Affiche le nombre dans AX en décimal');
 EmitLine('    push ax');
 EmitLine('    push bx');
 EmitLine('    push cx'); 
 EmitLine('    push dx');
 EmitLine('');
 EmitComment('Traiter le signe négatif');
 EmitLine('    cmp ax, 0');
 EmitLine('    jge PRINT_POSITIVE');
 EmitLine('    mov dl, ''-''');
 EmitLine('    mov ah, 02h');
 EmitLine('    int 21h');
 EmitLine('    neg ax');
 EmitLine('');
 EmitLine('PRINT_POSITIVE:');
 EmitComment('Conversion en décimal et affichage');
 EmitLine('    mov cx, 0    ; Compteur de chiffres');
 EmitLine('    mov bx, 10   ; Diviseur');
 EmitLine('');
 EmitLine('PUSH_DIGITS:');
 EmitLine('    mov dx, 0');
 EmitLine('    div bx       ; AX = AX / 10, DX = reste');
 EmitLine('    add dl, 48   ; Convertir en ASCII');
 EmitLine('    push dx      ; Empiler le chiffre');
 EmitLine('    inc cx       ; Incrémenter compteur');
 EmitLine('    cmp ax, 0');
 EmitLine('    jne PUSH_DIGITS');
 EmitLine('');
 EmitLine('POP_DIGITS:');
 EmitLine('    pop dx       ; Dépiler et afficher');
 EmitLine('    mov ah, 02h');
 EmitLine('    int 21h');
 EmitLine('    loop POP_DIGITS');
 EmitLine('');
 EmitLine('    pop dx');
 EmitLine('    pop cx');
 EmitLine('    pop bx');
 EmitLine('    pop ax');
 EmitLine('    ret');
 EmitLine('PRINT_NUM ENDP');
 
 EmitLine('');
 EmitComment('Procédures d''aide pour les chaînes');
 
 { Procédure de copie de chaînes }
 EmitLine('COPY_STR PROC');
 EmitComment('Copie une chaîne de SI vers DI (format Pascal: longueur + caractères)');
 EmitLine('    push ax');
 EmitLine('    push cx');
 EmitLine('    push si');
 EmitLine('    push di');
 EmitLine('');
 EmitComment('Copier la longueur');
 EmitLine('    lodsb        ; Charger longueur depuis [SI]');
 EmitLine('    stosb        ; Stocker longueur vers [DI]');
 EmitLine('    mov cl, al   ; Nombre de caractères à copier');
 EmitLine('    mov ch, 0');
 EmitLine('');
 EmitComment('Copier les caractères');
 EmitLine('    rep movsb    ; Copier CX caractères');
 EmitLine('');
 EmitLine('    pop di');
 EmitLine('    pop si');
 EmitLine('    pop cx');
 EmitLine('    pop ax');
 EmitLine('    ret');
 EmitLine('COPY_STR ENDP');
 
 { Procédure de concaténation de chaînes }
 EmitLine('');
 EmitLine('CONCAT_STR PROC');
 EmitComment('Concatène deux chaînes: SI (source1) + DI (source2) -> SI (résultat)');
 EmitLine('    push ax');
 EmitLine('    push bx');
 EmitLine('    push cx');
 EmitLine('    push dx');
 EmitLine('    push di');
 EmitLine('');
 EmitComment('Calculer la longueur totale');
 EmitLine('    mov al, [si]     ; Longueur chaîne 1');
 EmitLine('    mov bl, [di]     ; Longueur chaîne 2');
 EmitLine('    add al, bl       ; Longueur totale');
 EmitLine('    cmp al, 255      ; Vérifier dépassement');
 EmitLine('    jbe CONCAT_OK');
 EmitLine('    mov al, 255      ; Limiter à 255');
 EmitLine('');
 EmitLine('CONCAT_OK:');
 EmitComment('Stocker nouvelle longueur');
 EmitLine('    mov [si], al');
 EmitLine('');
 EmitComment('Positionner pour copie de la deuxième chaîne');
 EmitLine('    mov cl, [si]     ; Longueur chaîne 1 originale');
 EmitLine('    mov ch, 0');
 EmitLine('    mov dx, si');
 EmitLine('    inc dx           ; Pointer après longueur');
 EmitLine('    add dx, cx       ; Pointer après chaîne 1');
 EmitLine('');
 EmitComment('Copier la deuxième chaîne');
 EmitLine('    mov cl, [di]     ; Longueur chaîne 2');
 EmitLine('    inc di           ; Pointer après longueur');
 EmitLine('    mov si, di       ; Source = chaîne 2');
 EmitLine('    mov di, dx       ; Destination = fin de chaîne 1');
 EmitLine('    rep movsb        ; Copier');
 EmitLine('');
 EmitLine('    pop di');
 EmitLine('    pop dx');
 EmitLine('    pop cx');
 EmitLine('    pop bx');
 EmitLine('    pop ax');
 EmitLine('    ret');
 EmitLine('CONCAT_STR ENDP');
 
 { Procédure de comparaison de chaînes }
 EmitLine('');
 EmitLine('COMPARE_STR PROC');
 EmitComment('Compare deux chaînes SI et DI, résultat dans AX (0=égal, 1=différent)');
 EmitLine('    push bx');
 EmitLine('    push cx');
 EmitLine('    push dx');
 EmitLine('    push si');
 EmitLine('    push di');
 EmitLine('');
 EmitComment('Comparer les longueurs');
 EmitLine('    mov al, [si]');
 EmitLine('    mov bl, [di]');
 EmitLine('    cmp al, bl');
 EmitLine('    jne COMP_DIFF    ; Longueurs différentes');
 EmitLine('');
 EmitComment('Comparer les caractères');
 EmitLine('    mov cl, al       ; Nombre de caractères');
 EmitLine('    mov ch, 0');
 EmitLine('    inc si           ; Pointer après longueur');
 EmitLine('    inc di');
 EmitLine('    repe cmpsb       ; Comparer caractères');
 EmitLine('    je COMP_EQUAL');
 EmitLine('');
 EmitLine('COMP_DIFF:');
 EmitLine('    mov ax, 1        ; Différent');
 EmitLine('    jmp COMP_END');
 EmitLine('');
 EmitLine('COMP_EQUAL:');
 EmitLine('    mov ax, 0        ; Égal');
 EmitLine('');
 EmitLine('COMP_END:');
 EmitLine('    pop di');
 EmitLine('    pop si');
 EmitLine('    pop dx');
 EmitLine('    pop cx');
 EmitLine('    pop bx');
 EmitLine('    ret');
 EmitLine('COMPARE_STR ENDP');
 
 { Procédure d'affichage de chaînes }
 EmitLine('');
 EmitLine('PRINT_STR PROC');
 EmitComment('Affiche une chaîne Pascal pointée par SI');
 EmitLine('    push ax');
 EmitLine('    push cx');
 EmitLine('    push dx');
 EmitLine('    push si');
 EmitLine('');
 EmitComment('Lire la longueur');
 EmitLine('    lodsb            ; AL = longueur');
 EmitLine('    mov cl, al');
 EmitLine('    mov ch, 0');
 EmitLine('    jcxz PRINT_STR_END');
 EmitLine('');
 EmitLine('PRINT_CHAR_LOOP:');
 EmitLine('    lodsb            ; Charger caractère');
 EmitLine('    mov dl, al       ; Caractère à afficher');
 EmitLine('    mov ah, 02h      ; Fonction DOS affichage caractère');
 EmitLine('    int 21h');
 EmitLine('    loop PRINT_CHAR_LOOP');
 EmitLine('');
 EmitLine('PRINT_STR_END:');
 EmitLine('    pop si');
 EmitLine('    pop dx');
 EmitLine('    pop cx');
 EmitLine('    pop ax');
 EmitLine('    ret');
 EmitLine('PRINT_STR ENDP');
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('PC8086 - Cette commande permet de lancer une compilateur Pascal g�n�rant du code pour le ',
          'microprocesseur 8086 ou 8088.');
  WriteLn;
  WriteLn('Syntaxe: PC8086 <fichier.pas> [fichier.asm]');
  WriteLn('');
  WriteLn('  <fichier.pas>  : Fichier source Pascal');
  WriteLn('  [fichier.asm]  : Fichier assembleur de sortie (optionnel)');
  Halt;
 End;
 WriteLn('PC8086 - Compilateur Pascal vers Assembleur 8086 v1.0');
 WriteLn('======================================================');
 WriteLn('');
 source_filename := ParamStr(1);

 If ParamCount >= 2 Then
  output_filename := ParamStr(2)
 Else
 Begin
  output_filename := source_filename;
  { Changer l'extension .pas en .asm }
  If Pos('.', output_filename) > 0 Then
   output_filename := Copy(output_filename, 1, Pos('.', output_filename) - 1) + '.asm'
  Else
   output_filename := output_filename + '.asm';
 End;

 WriteLn('Fichier source: ', source_filename);
 WriteLn('Fichier sortie: ', output_filename);
 WriteLn('');

 { Ouvrir les fichiers }
 Assign(input_file, source_filename);
 {$I-}
 Reset(input_file);
 {$I+}
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible d''ouvrir le fichier source: ', source_filename);
  Exit;
 End;

 Assign(output_file, output_filename);
 {$I-}
 Rewrite(output_file);
 {$I+}
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible de créer le fichier de sortie: ', output_filename);
  Close(input_file);
  Exit;
 End;

 { Initialiser le compilateur }
 InitCompiler;

 { Lire la première ligne }
 If not Eof(input_file) Then
 Begin
  ReadLn(input_file, current_line);
  line_pos := 1;
 End;

 { Lire le premier caractère }
 NextChar;
 NextToken;

 { Commencer la compilation }
 ParseProgram;

 { Générer les procédures d'aide }
 GenerateHelpProcedures;

 { Fermer les fichiers }
 Close(input_file);
 Close(output_file);
 
 { Libérer la mémoire }
 CleanupCompiler;

 WriteLn('Compilation terminée.');
 WriteLn('Erreurs: ', error_count);

 If error_count = 0 Then
  WriteLn('Assemblage recommandé: MASM ', output_filename)
 Else
  WriteLn('Veuillez corriger les erreurs avant l''assemblage.');
END.
