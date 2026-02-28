{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Pascal pour 8086
}

Program PC8086;

{$A-}

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
 SYM_VAR = 2;
 SYM_CONST = 3;
 SYM_TYPE = 4;
 SYM_PROCEDURE = 5;
 SYM_FUNCTION = 6;
 SYM_BEGIN = 7;
 SYM_END = 8;
 SYM_IF = 9;
 SYM_THEN = 10;
 SYM_ELSE = 11;
 SYM_WHILE = 12;
 SYM_DO = 13;
 SYM_FOR = 14;
 SYM_TO = 15;
 SYM_REPEAT = 16;
 SYM_UNTIL = 17;
 SYM_CASE = 18;
 SYM_OF = 19;
 SYM_WRITE = 20;
 SYM_WRITELN = 21;
 SYM_READ = 22;
 SYM_READLN = 23;

 { Types de données Pascal }
 TYPE_INTEGER = 1;
 TYPE_BYTE = 2;
 TYPE_WORD = 3;
 TYPE_STRING = 4;
 TYPE_CHAR = 5;
 TYPE_BOOLEAN = 6;
 TYPE_REAL = 7;

 { Classes de stockage }
 STORAGE_GLOBAL = 1;
 STORAGE_LOCAL = 2;
 STORAGE_PARAMETER = 3;

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
 Else If current_token = 'REPEAT' Then current_symbol := SYM_REPEAT
 Else If current_token = 'UNTIL' Then current_symbol := SYM_UNTIL
 Else If current_token = 'CASE' Then current_symbol := SYM_CASE
 Else If current_token = 'OF' Then current_symbol := SYM_OF
 Else If current_token = 'WRITE' Then current_symbol := SYM_WRITE
 Else If current_token = 'WRITELN' Then current_symbol := SYM_WRITELN
 Else If current_token = 'READ' Then current_symbol := SYM_READ
 Else If current_token = 'READLN' Then current_symbol := SYM_READLN
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
   current_token := current_token + current_char;
   NextChar;
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
 { Identifier ou mot-clé }
 Else If ((current_char >= 'A') and (current_char <= 'Z')) or
    ((current_char >= 'a') and (current_char <= 'z')) or
    (current_char = '_') Then
  ReadIdentifier
 { Nombre }
 Else If (current_char >= '0') and (current_char <= '9') Then
  ReadNumber
 { Caractères spéciaux }
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
 End;

 AddSymbol := symbol_count;
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
Begin
 EmitComment('Compilé par PC8086 - Compilateur Pascal vers 8086');
 EmitComment('Date: 2026-02-28');
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
Begin
 If not data_segment Then
 Begin
  EmitLine('.DATA');
  data_segment := True;
 End;

 Case var_type of
  TYPE_INTEGER, TYPE_WORD: EmitLine(var_name + ' DW ?');
  TYPE_BYTE, TYPE_CHAR: EmitLine(var_name + ' DB ?');
  TYPE_STRING: EmitLine(var_name + ' DB 256 DUP(?)');
  TYPE_BOOLEAN: EmitLine(var_name + ' DB ?');
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
Begin
 If current_symbol = SYM_UNKNOWN Then
 Begin
  temp_token := current_token;
  
  { Vérifier si c'est un caractère littéral (longueur 1, lettre) }
  If (Length(temp_token) = 1) and 
     (((temp_token[1] >= 'A') and (temp_token[1] <= 'Z')) or
      ((temp_token[1] >= 'a') and (temp_token[1] <= 'z'))) Then
  Begin
   { Caractère littéral - traiter comme valeur ASCII }
   Emit('mov al, ' + IntToStr(Ord(temp_token[1])));
   NextToken;
  End
  { C'est peut-être un nombre }
  Else If (temp_token <> '') and (temp_token[1] >= '0') and (temp_token[1] <= '9') Then
  Begin
   { Nombre littéral }
   Emit('mov ax, ' + temp_token);
   NextToken;
  End
  Else If temp_token <> '' Then
  Begin
   { Identificateur - chercher dans la table des symboles }
   sym_index := FindSymbol(temp_token);
   If sym_index > 0 Then
   Begin
    Case symbol_table[sym_index]^.data_type of
     TYPE_INTEGER, TYPE_WORD: Emit('mov ax, ' + symbol_table[sym_index]^.name);
     TYPE_BYTE, TYPE_CHAR: Emit('mov al, ' + symbol_table[sym_index]^.name);
    Else
     Emit('mov ax, ' + symbol_table[sym_index]^.name);
    End;
   End
   Else
   Begin
    Error('Variable non déclarée: ' + temp_token);
   End;
   NextToken;
  End
  Else
  Begin
   NextToken; { Token vide, continuer }
  End;
 End
 Else
 Begin
  NextToken; { Symbole reconnu, continuer }
 End;
End;

{ Parser une instruction d'affectation }
Procedure ParseAssignment(var_name: String);
Var
 sym_index: Integer;
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
  ParseExpression;

  { Générer le code d'affectation }
  Case symbol_table[sym_index]^.data_type of
   TYPE_INTEGER, TYPE_WORD: Emit('mov ' + symbol_table[sym_index]^.name + ', ax');
   TYPE_BYTE, TYPE_CHAR: Emit('mov ' + symbol_table[sym_index]^.name + ', al');
  Else
   Emit('mov ' + symbol_table[sym_index]^.name + ', ax');
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
         Emit('mov dx, OFFSET ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 09h');
         Emit('int 21h');
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
         Emit('mov dx, OFFSET ' + symbol_table[sym_index]^.name);
         Emit('mov ah, 09h');
         Emit('int 21h');
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

{ Parser une instruction }
Procedure ParseStatement;
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
      If FindSymbol(current_token) > 0 Then
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

  SYM_WRITE:
   ParseWrite;

  SYM_WRITELN:
   ParseWriteln;

  SYM_UNKNOWN:
   Begin
    If current_token <> '' Then
    Begin
     { Peut-être une affectation }
     If FindSymbol(current_token) > 0 Then
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
    Error('Type inconnu: ' + type_name);
    var_type := TYPE_INTEGER;
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

{ Parser un bloc Pascal }
Procedure ParseBlock;
Begin
 { Gérer les déclarations VAR }
 If Accept(SYM_VAR) Then
  ParseVarDeclarations;

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
Begin
 { En-tête PROGRAM }
 If Accept(SYM_PROGRAM) Then
 Begin
  NextToken;
  If current_symbol = SYM_UNKNOWN Then
  Begin
   EmitComment('Programme: ' + current_token);
   NextToken;
   If current_token = ';' Then
    NextToken
   Else
    Error('Attendu ; après nom de programme');
  End
  Else
   Error('Attendu nom de programme');
 End
 Else
  Error('Attendu PROGRAM au début');

 GenerateHeader;

 { Parser le bloc principal }
 ParseBlock;

 { Attendre le point final }
 If current_token = '.' Then
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
