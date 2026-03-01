{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur COBOL pour 8086/8088 - Sortie MASM/TASM
}

Program COBOL86;

{$A-}
{$I-}

Uses DOS;

{ ============================================================================ }
{ CONSTANTES GENERALES                                                         }
{ ============================================================================ }

Const
 VERSION = 'COBOL86 V1.0';

 { Colonnes COBOL format fixe }
 COL_SEQ_START    = 1;   { Colonnes 1-6  : numero de sequence (ignore) }
 COL_SEQ_END      = 6;
 COL_INDICATOR    = 7;   { Colonne 7     : indicateur (* / - espace) }
 COL_AREA_A_START = 8;   { Colonnes 8-11 : zone A (en-tetes, noms niv 01/77) }
 COL_AREA_B_START = 12;  { Colonnes 12-72: zone B (instructions, clauses) }
 COL_SOURCE_END   = 72;  { Colonne 72    : fin de la zone source }
 COL_ID_START     = 73;  { Colonnes 73-80: zone identification (ignoree) }

 { Types de tokens COBOL }
 TOK_UNKNOWN   = 0;
 TOK_WORD      = 1;   { Mot : identifiant ou mot reserve }
 TOK_NUMBER    = 2;   { Litteral numerique (entier ou decimal) }
 TOK_STRING    = 3;   { Litteral chaine entre apostrophes ou guillemets }
 TOK_PERIOD    = 4;   { . (terminateur de phrase COBOL) }
 TOK_COMMA     = 5;   { , }
 TOK_SEMICOLON = 6;   { ; }
 TOK_LPAREN    = 7;   { ( }
 TOK_RPAREN    = 8;   { ) }
 TOK_PLUS      = 9;   { + }
 TOK_MINUS     = 10;  { - }
 TOK_MULTIPLY  = 11;  { * }
 TOK_DIVIDE    = 12;  { / }
 TOK_POWER     = 13;  { ** }
 TOK_EQUAL     = 14;  { = }
 TOK_LESS      = 15;  { < }
 TOK_GREATER   = 16;  { > }
 TOK_LESSEQ    = 17;  { <= }
 TOK_GREATEREQ = 18;  { >= }
 TOK_NOTEQUAL  = 19;  { <> ou NOT = }
 TOK_COLON     = 20;  { : (reference de sous-chaine) }
 TOK_EOF       = 21;  { Fin de fichier }

 { Indicateurs de colonne 7 }
 IND_NORMAL    = ' '; { Ligne normale }
 IND_COMMENT   = '*'; { Ligne de commentaire }
 IND_PAGE      = '/'; { Saut de page (traite comme commentaire) }
 IND_CONTINUE  = '-'; { Ligne de continuation }
 IND_DEBUG     = 'D'; { Ligne de debug (traite comme commentaire) }

 MAX_TOKEN_LEN  = 255;
 MAX_LINE_LEN   = 255;
 MAX_ERRORS     = 999;

{ ============================================================================ }
{ VARIABLES GLOBALES DU TOKENISEUR                                             }
{ ============================================================================ }

Var
 { Fichiers }
 input_file     : Text;
 output_file    : Text;
 source_filename: String;
 output_filename: String;

 { Etat du lecteur de lignes }
 raw_line       : String;   { Ligne brute lue depuis le fichier }
 source_line    : String;   { Zone source effective (cols 8-72) }
 indicator_char : Char;     { Caractere indicateur (col 7) }
 line_number    : Integer;  { Numero de ligne courante }
 line_pos       : Integer;  { Position courante dans source_line (1-base) }
 current_char   : Char;     { Caractere courant }
 in_continuation: Boolean;  { Vrai si on est en continuation de chaine }
 cont_quote     : Char;     { Caractere de quote de la chaine en continuation }

 { Etat du tokeniseur }
 current_token  : String;   { Valeur textuelle du token courant }
 current_symbol : Integer;  { Type du token courant (TOK_xxx) }
 current_value  : LongInt;  { Valeur numerique si TOK_NUMBER }
 token_column   : Integer;  { Colonne de debut du token dans la ligne source }
 error_count    : Integer;  { Nombre d'erreurs rencontrees }
 eof_reached    : Boolean;  { Vrai quand le fichier est entierement lu }

{ ============================================================================ }
{ UTILITAIRES                                                                  }
{ ============================================================================ }

{ Convertir une chaine en majuscules }
Function UpperStr(s: String): String;
Var
 i: Integer;
 r: String;
Begin
 r := s;
 For i := 1 to Length(s) do
  If (s[i] >= 'a') and (s[i] <= 'z') Then
   r[i] := Chr(Ord(s[i]) - 32);
 UpperStr := r;
End;

{ Afficher une erreur avec le numero de ligne }
Procedure Error(msg: String);
Begin
 WriteLn('ERREUR ligne ', line_number, ' col ', token_column + 7,
         ': ', msg);
 Inc(error_count);
 If error_count >= MAX_ERRORS Then
 Begin
  WriteLn('Trop d''erreurs - compilation arretee.');
  Close(input_file);
  Halt(1);
 End;
End;

{ Afficher un avertissement }
Procedure Warning(msg: String);
Begin
 WriteLn('ATTENTION ligne ', line_number, ' col ', token_column + 7,
         ': ', msg);
End;

{ ============================================================================ }
{ LECTURE DES LIGNES COBOL (FORMAT FIXE)                                      }
{ ============================================================================ }

{
  Format fixe COBOL traditionnel :
    Cols  1- 6 : zone numerotation (ignoree)
    Col   7    : zone indicateur
                   ' ' = ligne normale
                   '*' = commentaire entier
                   '/' = saut de page (commentaire)
                   '-' = continuation de la ligne precedente
                   'D' = ligne de debug (commentaire ici)
    Cols  8-11 : zone A (en-tetes de divisions/sections, niveaux 01/77/88)
    Cols 12-72 : zone B (corps des instructions et clauses)
    Cols 73-80 : zone identification du programme (ignoree)

  source_line contient toujours le contenu des colonnes 8 a 72 (donc
  jusqu'a 65 caracteres) ; line_pos et current_char pointent dedans.
}

{ Lire la prochaine ligne physique depuis le fichier }
Function ReadPhysicalLine: Boolean;
Begin
 If Eof(input_file) Then
 Begin
  ReadPhysicalLine := False;
  Exit;
 End;
 ReadLn(input_file, raw_line);
 Inc(line_number);
 ReadPhysicalLine := True;
End;

{ Extraire la zone source (cols 8-72) et l'indicateur (col 7) }
Procedure ExtractSourceZone;
Var
 len: Integer;
Begin
 len := Length(raw_line);

 { Indicateur col 7 }
 If len >= COL_INDICATOR Then
  indicator_char := raw_line[COL_INDICATOR]
 Else
  indicator_char := IND_NORMAL;

 { Zone source : cols 8 a 72 (ou fin de ligne si plus courte) }
 If len >= COL_AREA_A_START Then
 Begin
  If len > COL_SOURCE_END Then len := COL_SOURCE_END;
  source_line := Copy(raw_line, COL_AREA_A_START,
                       len - COL_AREA_A_START + 1);
  { Supprimer les espaces de fin }
  While (Length(source_line) > 0) and
        (source_line[Length(source_line)] = ' ') do
   Delete(source_line, Length(source_line), 1);
 End
 Else
  source_line := '';
End;

{ Avancer d'un caractere dans source_line (declaration anticipee) }
Procedure NextChar; Forward;

Procedure LoadNextLine;
Label retry;
Begin
retry:
 If not ReadPhysicalLine Then
 Begin
  eof_reached    := True;
  source_line    := '';
  line_pos       := 1;
  current_char   := #0;
  indicator_char := IND_NORMAL;
  Exit;
 End;

 ExtractSourceZone;

 { Ignorer les lignes de commentaire }
 If (indicator_char = IND_COMMENT) or
    (indicator_char = IND_PAGE)    or
    (indicator_char = IND_DEBUG)   Then
  Goto retry;

 { Ligne de continuation : signaler l'etat }
 If indicator_char = IND_CONTINUE Then
  in_continuation := True
 Else
  in_continuation := False;

 line_pos := 1;

 If Length(source_line) > 0 Then
  current_char := source_line[1]
 Else
  current_char := ' ';
End;

{ Avancer d'un caractere dans source_line }
Procedure NextChar;
Begin
 Inc(line_pos);
 If line_pos > Length(source_line) Then
 Begin
  If eof_reached Then
  Begin
   current_char := #0;
   Exit;
  End;
  LoadNextLine;
 End
 Else
  current_char := source_line[line_pos];
End;

{ Retourner le caractere SUIVANT sans avancer (regarder en avant) }
Function PeekChar: Char;
Begin
 If line_pos + 1 <= Length(source_line) Then
  PeekChar := source_line[line_pos + 1]
 Else
  PeekChar := ' ';
End;

{ ============================================================================ }
{ ANALYSEUR LEXICAL (TOKENISEUR COBOL)                                         }
{ ============================================================================ }

{ Ignorer les espaces et tabulations dans la zone source courante }
Procedure SkipSpaces;
Begin
 While (current_char = ' ') or (current_char = #9) do
 Begin
  If line_pos >= Length(source_line) Then
  Begin
   If eof_reached Then
   Begin
    current_char := #0;
    Exit;
   End;
   LoadNextLine;
  End
  Else
   NextChar;
 End;
End;

{
  Lire un mot COBOL (identifiant ou mot reserve).
  Un mot COBOL est compose de lettres, chiffres et traits d'union.
  Il ne peut pas commencer ni finir par un trait d'union.
  Longueur max : 30 caracteres (norme), on accepte jusqu'a MAX_TOKEN_LEN.
}
Procedure ReadWord;
Begin
 current_token := '';
 token_column  := line_pos;
 While ((current_char >= 'A') and (current_char <= 'Z')) or
       ((current_char >= 'a') and (current_char <= 'z')) or
       ((current_char >= '0') and (current_char <= '9')) or
       (current_char = '-') do
 Begin
  { Un tiret suivi d'un espace ou fin de ligne = operateur, pas partie du mot }
  If (current_char = '-') Then
  Begin
   If (PeekChar = ' ') or (PeekChar = #0) or
      (line_pos >= Length(source_line)) Then
    Break;
  End;
  current_token := current_token + current_char;
  NextChar;
 End;

 { Supprimer un eventuel tiret de fin (interdit par la norme) }
 While (Length(current_token) > 0) and
       (current_token[Length(current_token)] = '-') do
  Delete(current_token, Length(current_token), 1);

 current_token  := UpperStr(current_token);
 current_symbol := TOK_WORD;
End;

{
  Lire un litteral numerique COBOL.
  Forme : chiffres [. chiffres]
}
Procedure ReadNumber;
Var
 temp : String;
 code : Integer;
Begin
 temp     := '';
 token_column := line_pos;

 While ((current_char >= '0') and (current_char <= '9')) do
 Begin
  temp := temp + current_char;
  NextChar;
 End;

 { Partie decimale }
 If (current_char = '.') and (PeekChar >= '0') and (PeekChar <= '9') Then
 Begin
  temp := temp + '.';
  NextChar;
  While ((current_char >= '0') and (current_char <= '9')) do
  Begin
   temp := temp + current_char;
   NextChar;
  End;
 End;

 current_token  := temp;
 current_symbol := TOK_NUMBER;
 Val(temp, current_value, code);
 If code <> 0 Then current_value := 0;
End;

{
  Lire un litteral chaine COBOL.
  Delimiteur : apostrophe (') ou guillemet (").
  Doublement du delimiteur = caracterel litteral dans la chaine.
  Continuation possible sur la ligne suivante (indicateur '-').
}
Procedure ReadString;
Var
 quote_char: Char;
 done      : Boolean;
Begin
 quote_char     := current_char;
 current_token  := '';
 current_symbol := TOK_STRING;
 token_column   := line_pos;
 NextChar; { Sauter le delimiteur ouvrant }

 done := False;
 While not done do
 Begin
  If current_char = #0 Then
  Begin
   Error('Fin de fichier dans un litteral chaine non ferme');
   done := True;
  End
  Else If (current_char = quote_char) Then
  Begin
   NextChar;
   If current_char = quote_char Then
   Begin
    current_token := current_token + quote_char;
    NextChar;
   End
   Else
    done := True;
  End
  Else If line_pos > Length(source_line) Then
  Begin
   If eof_reached Then
   Begin
    Error('Chaine non fermee avant fin de fichier');
    done := True;
   End
   Else
   Begin
    LoadNextLine;
    If indicator_char = IND_CONTINUE Then
    Begin
     While (current_char = ' ') or (current_char = #9) do
      NextChar;
     If current_char = quote_char Then
      NextChar
     Else
      done := True;
    End
    Else
    Begin
     Warning('Chaine non fermee sur la ligne - fermeture implicite');
     done := True;
    End;
   End;
  End
  Else
  Begin
   current_token := current_token + current_char;
   NextChar;
  End;
 End;
End;

{
  Obtenir le prochain token COBOL.
  Gere : mots, nombres, chaines, operateurs, et le point terminateur.
}
Procedure NextToken;
Begin
 SkipSpaces;

 If (current_char = #0) or eof_reached Then
 Begin
  current_token  := '';
  current_symbol := TOK_EOF;
  Exit;
 End;

 token_column := line_pos;

 { Mot (identifiant ou mot reserve) }
 If ((current_char >= 'A') and (current_char <= 'Z')) or
    ((current_char >= 'a') and (current_char <= 'z')) Then
 Begin
  ReadWord;
  Exit;
 End;

 { Nombre }
 If (current_char >= '0') and (current_char <= '9') Then
 Begin
  ReadNumber;
  Exit;
 End;

 { Litteral chaine }
 If (current_char = '''') or (current_char = '"') Then
 Begin
  ReadString;
  Exit;
 End;

 { Caracteres speciaux }
 Case current_char of
  '.':
   Begin
    If (PeekChar >= '0') and (PeekChar <= '9') Then
    Begin
     { Nombre commencant par un point decimal }
     current_token  := '0';
     current_symbol := TOK_NUMBER;
     current_value  := 0;
     NextChar;
     While (current_char >= '0') and (current_char <= '9') do
     Begin
      current_token := current_token + current_char;
      NextChar;
     End;
    End
    Else
    Begin
     current_token  := '.';
     current_symbol := TOK_PERIOD;
     NextChar;
    End;
   End;
  ',':
   Begin
    current_token := ','; current_symbol := TOK_COMMA; NextChar;
   End;
  ';':
   Begin
    current_token := ';'; current_symbol := TOK_SEMICOLON; NextChar;
   End;
  '(':
   Begin
    current_token := '('; current_symbol := TOK_LPAREN; NextChar;
   End;
  ')':
   Begin
    current_token := ')'; current_symbol := TOK_RPAREN; NextChar;
   End;
  '+':
   Begin
    current_token := '+'; current_symbol := TOK_PLUS; NextChar;
   End;
  '-':
   Begin
    current_token := '-'; current_symbol := TOK_MINUS; NextChar;
   End;
  '*':
   Begin
    NextChar;
    If current_char = '*' Then
    Begin
     current_token := '**'; current_symbol := TOK_POWER; NextChar;
    End
    Else
    Begin
     current_token := '*'; current_symbol := TOK_MULTIPLY;
    End;
   End;
  '/':
   Begin
    current_token := '/'; current_symbol := TOK_DIVIDE; NextChar;
   End;
  '=':
   Begin
    current_token := '='; current_symbol := TOK_EQUAL; NextChar;
   End;
  '<':
   Begin
    NextChar;
    If current_char = '=' Then
    Begin
     current_token := '<='; current_symbol := TOK_LESSEQ; NextChar;
    End
    Else If current_char = '>' Then
    Begin
     current_token := '<>'; current_symbol := TOK_NOTEQUAL; NextChar;
    End
    Else
    Begin
     current_token := '<'; current_symbol := TOK_LESS;
    End;
   End;
  '>':
   Begin
    NextChar;
    If current_char = '=' Then
    Begin
     current_token := '>='; current_symbol := TOK_GREATEREQ; NextChar;
    End
    Else
    Begin
     current_token := '>'; current_symbol := TOK_GREATER;
    End;
   End;
  ':':
   Begin
    current_token := ':'; current_symbol := TOK_COLON; NextChar;
   End;
 Else
  Error('Caractere inattendu: ''' + current_char + '''');
  current_token  := current_char;
  current_symbol := TOK_UNKNOWN;
  NextChar;
 End;
End;

{ ============================================================================ }
{ INITIALISATION DU TOKENISEUR                                                 }
{ ============================================================================ }

Procedure InitTokenizer;
Begin
 line_number     := 0;
 line_pos        := 1;
 current_char    := ' ';
 raw_line        := '';
 source_line     := '';
 indicator_char  := IND_NORMAL;
 in_continuation := False;
 cont_quote      := '''';
 current_token   := '';
 current_symbol  := TOK_UNKNOWN;
 current_value   := 0;
 token_column    := 0;
 error_count     := 0;
 eof_reached     := False;

 LoadNextLine;
 NextToken;
End;

{ ============================================================================ }
{ API PUBLIQUE DU TOKENISEUR                                                   }
{ ============================================================================ }

{ Vrai si le token courant est le mot COBOL w }
Function TokenIs(w: String): Boolean;
Begin
 TokenIs := (current_symbol = TOK_WORD) and (current_token = UpperStr(w));
End;

{ Consommer le token courant }
Procedure Consume;
Begin
 NextToken;
End;

{ Consommer un mot reserve, erreur si different }
Procedure Expect(w: String);
Begin
 If not TokenIs(w) Then
  Error('Attendu ''' + UpperStr(w) + ''', trouve ''' + current_token + '''')
 Else
  NextToken;
End;

{ Consommer un type de token specifique }
Procedure ExpectSym(sym: Integer; desc: String);
Begin
 If current_symbol <> sym Then
  Error('Attendu ' + desc + ', trouve ''' + current_token + '''')
 Else
  NextToken;
End;

{ Sauter jusqu'au prochain point terminateur (inclus) }
Procedure SkipToPeriod;
Begin
 While (current_symbol <> TOK_PERIOD) and (current_symbol <> TOK_EOF) do
  NextToken;
 If current_symbol = TOK_PERIOD Then NextToken;
End;

{ Sauter jusqu'au prochain mot w (inclus) }
Procedure SkipToWord(w: String);
Begin
 While not TokenIs(w) and (current_symbol <> TOK_EOF) do
  NextToken;
 If TokenIs(w) Then NextToken;
End;

{ ============================================================================ }
{ DEBOGAGE : DECHARGE DES TOKENS (mode /T)                                     }
{ ============================================================================ }

Function TokenTypeName(sym: Integer): String;
Begin
 Case sym of
  TOK_UNKNOWN   : TokenTypeName := 'UNKNOWN';
  TOK_WORD      : TokenTypeName := 'MOT';
  TOK_NUMBER    : TokenTypeName := 'NOMBRE';
  TOK_STRING    : TokenTypeName := 'CHAINE';
  TOK_PERIOD    : TokenTypeName := 'POINT';
  TOK_COMMA     : TokenTypeName := 'VIRGULE';
  TOK_SEMICOLON : TokenTypeName := 'POINTVIRGULE';
  TOK_LPAREN    : TokenTypeName := 'PARGAUCHE';
  TOK_RPAREN    : TokenTypeName := 'PARDROITE';
  TOK_PLUS      : TokenTypeName := 'PLUS';
  TOK_MINUS     : TokenTypeName := 'MOINS';
  TOK_MULTIPLY  : TokenTypeName := 'MULTIPLIER';
  TOK_DIVIDE    : TokenTypeName := 'DIVISER';
  TOK_POWER     : TokenTypeName := 'PUISSANCE';
  TOK_EQUAL     : TokenTypeName := 'EGAL';
  TOK_LESS      : TokenTypeName := 'INFERIEUR';
  TOK_GREATER   : TokenTypeName := 'SUPERIEUR';
  TOK_LESSEQ    : TokenTypeName := 'INFERIEUR_EG';
  TOK_GREATEREQ : TokenTypeName := 'SUPERIEUR_EG';
  TOK_NOTEQUAL  : TokenTypeName := 'DIFFERENT';
  TOK_COLON     : TokenTypeName := 'DEUXPOINTS';
  TOK_EOF       : TokenTypeName := 'FIN_FICHIER';
 Else
  TokenTypeName := '???';
 End;
End;

Procedure DumpTokens;
Begin
 WriteLn('=== DECHARGE DES TOKENS COBOL ===');
 WriteLn('Format: [ligne:col] TYPE  "valeur"');
 WriteLn;
 While current_symbol <> TOK_EOF do
 Begin
  WriteLn('[', line_number:4, ':', (token_column + COL_INDICATOR):2, '] ',
          TokenTypeName(current_symbol), #9,
          '"', current_token, '"');
  NextToken;
 End;
 WriteLn;
 WriteLn('=== FIN DECHARGE ===');
End;

{ ============================================================================ }
{ PROGRAMME PRINCIPAL                                                          }
{ ============================================================================ }

Procedure ShowHelp;
Begin
 WriteLn(VERSION, ' - Compilateur COBOL pour 8086/8088');
 WriteLn;
 WriteLn('Syntaxe: COBOL86 [options] <fichier.cbl> [fichier.asm]');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /T   Decharge des tokens (debug tokeniseur)');
 WriteLn('  /?   Afficher cette aide');
 WriteLn;
 WriteLn('Exemples:');
 WriteLn('  COBOL86 HELLO.CBL');
 WriteLn('  COBOL86 HELLO.CBL HELLO.ASM');
 WriteLn('  COBOL86 /T HELLO.CBL');
End;

Var
 i            : Integer;
 opt_dump_tok : Boolean;
 arg          : String;

Begin
 opt_dump_tok    := False;
 source_filename := '';
 output_filename := '';

 For i := 1 to ParamCount do
 Begin
  arg := ParamStr(i);
  If (arg = '/?') or (arg = '-h') or (arg = '--help') Then
  Begin
   ShowHelp;
   Halt(0);
  End
  Else If (UpperStr(arg) = '/T') or (UpperStr(arg) = '-T') Then
   opt_dump_tok := True
  Else If source_filename = '' Then
   source_filename := arg
  Else If output_filename = '' Then
   output_filename := arg;
 End;

 If source_filename = '' Then
 Begin
  ShowHelp;
  Halt(1);
 End;

 { Nom de sortie par defaut : meme nom, extension .ASM }
 If output_filename = '' Then
 Begin
  output_filename := source_filename;
  i := Length(output_filename);
  While (i > 0) and (output_filename[i] <> '.') and
        (output_filename[i] <> '\') and (output_filename[i] <> '/') do
   Dec(i);
  If (i > 0) and (output_filename[i] = '.') Then
   output_filename := Copy(output_filename, 1, i - 1) + '.ASM'
  Else
   output_filename := output_filename + '.ASM';
 End;

 { Ouvrir le fichier source }
 Assign(input_file, source_filename);
 Reset(input_file);
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible d''ouvrir le fichier: ', source_filename);
  Halt(1);
 End;

 WriteLn(VERSION, ' - Compilation de: ', source_filename);

 InitTokenizer;

 If opt_dump_tok Then
 Begin
  DumpTokens;
  Close(input_file);
  WriteLn('Termine. Erreurs: ', error_count);
  Halt(0);
 End;

 { TODO: Appel au parseur principal (prochaines etapes) }
 WriteLn('INFO: Parseur non encore implemente.');

 Close(input_file);
 WriteLn('Termine. Erreurs: ', error_count);
 If error_count > 0 Then Halt(1);
END.