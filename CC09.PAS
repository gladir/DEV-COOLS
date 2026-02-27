{ @author: Sylvain Maltais
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @description: Small-C Compiler for 6809
}

Program CC09;

{$A-}
{$I-}

Const
 VERSION = 'small-c V2.3 (Pascal)';
 YES = 1;
 NO = 0;

 { Symbol table parameters }
 symsiz = 14;
 symtbsz = 8008;
 numglbs = 512;
 MASKGLBS = 511;
 namesize = 9;
 namemax = 8;

 { Symbol table entry format offsets }
 name = 0;
 ident = 9;
 ctype = 10;
 storage = 11;
 offset = 12;
 offsize = 2;

 { Identifier types }
 variable = 1;
 arr = 2;
 pointer = 3;
 func = 4;

 { Data types }
 cchar = 4;
 cint = 8;

 { Storage classes }
 statik = 1;
 stkloc = 2;
 CEXTERNAL = 3;
 automatic = 4;

 { Statement types }
 streturn = 3;

 { Assembler types }
 AS6809 = 1;
 AS9 = 2;

 { Input line }
 linesize = 80;
 linemax = linesize - 1;

Type
 TSymTab = Array[0..symtbsz-1] of Char;
 TLine = String[linesize];

 { Expression value structure }
 TLVal = Record
  symbol: Integer;     { pointer to symbol table entry }
  indirect: Integer;   { 0=direct, 1=indirect }
  typ: Integer;        { data type }
  storage: Integer;    { storage class }
  constant: Boolean;   { true if constant value }
  value: Integer;      { constant value if applicable }
 End;

Var
 { Symbol tables }
 symtab: TSymTab;
 glbptr, locptr: Integer;

 { Input line }
 line: TLine;
 lptr: Integer;

 { Labels and counters }
 nxtlab: Integer;
 nextlabel: Integer; { For expression parser }

 { Flags and options }
 first_func, declared: Boolean;
 stkp: Integer;
 errcnt, eof: Integer;
 optimize, ctext, cmode, lastst: Integer;

 { File handles }
 input, output: Text;
 asmtype: Integer;
 use_stdout: Boolean;

Function startglb: Integer;
Begin
 startglb := 0;
End;

Function endglb: Integer;
Begin
 endglb := startglb + numglbs * symsiz;
End;

Function startloc: Integer;
Begin
 startloc := endglb + symsiz;
End;

Function endloc: Integer;
Begin
 endloc := symtbsz - symsiz;
End;

{ Utility functions }
Function upper(ch: Char): Char;
Begin
 If ch in ['a'..'z'] Then upper := Chr(Ord(ch) - 32)
                     Else upper := ch;
End;

Function an(ch: Char): Boolean;
Begin
 an := ch in ['A'..'Z', 'a'..'z', '_'];
End;

Function numeric(ch: Char): Boolean;
Begin
 numeric := ch in ['0'..'9'];
End;

{ String utilities }
Function streq(s1, s2: String): Boolean;
Begin
 streq := s1 = s2;
End;

{ Input/Output functions }
Function ch: Char;
Begin
 If lptr <= Length(line) Then ch := line[lptr]
                         Else ch := #0;
End;

Function gch: Char;
Begin
 If lptr <= Length(line) Then
 Begin
  gch := line[lptr];
  Inc(lptr);
 End
 Else gch := #0;
End;

Procedure kill;
Begin
 lptr := Length(line) + 1;
End;

Procedure nl;
Begin
 WriteLn(output);
End;

Procedure ol(s: String);
Begin
 WriteLn(output, #9, s);
End;

Procedure outstr(s: String);
Begin
 Write(output, s);
End;

Procedure outdec(n: Integer);
Begin
 Write(output, n);
End;

{ Label generation functions }
Function getlabel: Integer;
Begin
 Inc(nextlabel);
 getlabel := nextlabel;
End;

Procedure printlabel(labelnum: Integer);
Begin
 outstr('L');
 outdec(labelnum);
End;

Procedure prelabel(lab: Integer);
Begin
 WriteLn(output, 'L', lab, ':');
End;

{ Code generation }
Procedure ot(s: String);
Begin
 Write(output, #9, s); { TAB then string }
End;

{ Expression parsing utility functions }
Function is_alpha(ch: Char): Boolean;
Begin
 is_alpha := ((ch >= 'A') and (ch <= 'Z')) or ((ch >= 'a') and (ch <= 'z')) or (ch = '_');
End;

Function is_digit(ch: Char): Boolean;
Begin
 is_digit := (ch >= '0') and (ch <= '9');
End;

Function is_alnum(ch: Char): Boolean;
Begin
 is_alnum := is_alpha(ch) or is_digit(ch);
End;

Procedure skip_whitespace;
Begin
 While (lptr <= Length(line)) and ((line[lptr] = ' ') or (line[lptr] = #9)) do
  Inc(lptr);
End;

Function peek_char: Char;
Begin
 skip_whitespace;
 If lptr <= Length(line) Then
  peek_char := line[lptr]
 Else
  peek_char := #0;
End;

Function next_char: Char;
Begin
 skip_whitespace;
 If lptr <= Length(line) Then
 Begin
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
 While (lptr <= Length(line)) and is_digit(line[lptr]) do
 Begin
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
 While (lptr <= Length(line)) and is_alnum(line[lptr]) do
 Begin
  result := result + line[lptr];
  Inc(lptr);
 End;
 parse_identifier := result;
End;

{ Error reporting }
Procedure errrpt(msg: String);
Begin
 Inc(errcnt);
 WriteLn('Error: ', msg, ' at line ', lptr);
End;

{ Missing outbyte procedure }
Procedure outbyte(b: Byte);
Begin
 Write(output, Chr(b));
End;

{ Lexical analysis }
Function blanks: Boolean;
Var
 found: Boolean;
Begin
 found := False;
 While (lptr <= Length(line)) and (line[lptr] in [' ', #9]) do
 Begin
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
 For i := 1 to Length(s) do
 Begin
  If (lptr + i - 1 > Length(line)) or (line[lptr + i - 1] <> s[i]) Then
  Begin
   matched := False;
   Break;
  End;
 End;
 If matched Then lptr := lptr + Length(s);
 match := matched;
End;

Function amatch(s: String; len: Integer): Boolean;
Begin
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

{ Number parsing }
Function number(Var value: Integer): Boolean;
Var
 n: Integer;
Begin
 blanks;
 n := 0;
 number := False;
 If (lptr <= Length(line)) and numeric(line[lptr]) Then
 Begin
  number := True;
  While (lptr <= Length(line)) and numeric(line[lptr]) do
  Begin
   n := n * 10 + (Ord(line[lptr]) - Ord('0'));
   Inc(lptr);
  End;
  value := n;
 End;
End;

{ Symbol table management }
Function hash(sname: String): Integer;
Var
 h, i: Integer;
Begin
 h := 0;
 For i := 1 to Length(sname) do
  h := (h shl 1) + Ord(sname[i]);
 hash := h;
End;

{ Symbol table operations }
Function addsym(sname: String; typ: Integer; storage: Integer; offset: Integer): Integer;
Var
 ptr: Integer;
Begin
 ptr := glbptr;
 If ptr + symsiz > endglb Then
 Begin
  errrpt('Symbol table overflow');
  addsym := 0;
  Exit;
 End;
 
 { Store symbol name }
 Move(sname[1], symtab[ptr + name], Length(sname));
 symtab[ptr + name + Length(sname)] := #0;
 
 { Store attributes }
 symtab[ptr + ident] := Chr(variable);
 symtab[ptr + ctype] := Chr(typ);
 symtab[ptr + storage] := Chr(storage);
 
 { Store offset }
 Move(offset, symtab[ptr + offset], offsize);
 
 glbptr := glbptr + symsiz;
 addsym := ptr;
End;

Function findsym(sname: String): Integer;
Var
 ptr: Integer;
 stored_name: String;
Begin
 ptr := startglb;
 While ptr < glbptr do
 Begin
  { Extract stored name }
  stored_name := '';
  While (symtab[ptr + name + Length(stored_name)] <> #0) and 
        (Length(stored_name) < namemax) do
  Begin
   stored_name := stored_name + symtab[ptr + name + Length(stored_name)];
  End;
  
  If stored_name = sname Then
  Begin
   findsym := ptr;
   Exit;
  End;
  
  ptr := ptr + symsiz;
 End;
 
 findsym := 0;
End;

{ Variable declaration parsing }
Function parse_type_specifier: Integer;
Begin
 parse_type_specifier := cint; { Default to int }
 
 If match('int') Then
  parse_type_specifier := cint
 Else If match('char') Then
  parse_type_specifier := cchar
 Else If match('void') Then
  parse_type_specifier := 0;
End;

Function parse_declarator(var var_name: String; base_type: Integer): Integer;
Var
 result_type: Integer;
 array_size: Integer;
Begin
 result_type := base_type;
 
 { Handle pointer declarations }
 While match('*') do
 Begin
  result_type := pointer;
 End;
 
 { Parse variable name }
 If not symname(var_name) Then
 Begin
  errrpt('Expected variable name');
  parse_declarator := 0;
  Exit;
 End;
 
 { Handle array declarations }
 If match('[') Then
 Begin
  If number(array_size) Then
   WriteLn(output, '; Array size: ', array_size)
  Else
   array_size := 1;
   
  If not match(']') Then
   errrpt('Expected closing bracket');
   
  result_type := arr;
 End;
 
 parse_declarator := result_type;
End;

Procedure declare_variable(var_name: String; var_type: Integer);
Var
 sym_ptr: Integer;
Begin
 { Check if already declared }
 If findsym(var_name) <> 0 Then
 Begin
  errrpt('Variable ' + var_name + ' already declared');
  Exit;
 End;
 
 { Add to symbol table }
 sym_ptr := addsym(var_name, var_type, automatic, 0);
 If sym_ptr <> 0 Then
 Begin
  WriteLn(output, '; Declared variable: ', var_name, ' (type: ', var_type, ')');
  
  { Generate storage allocation }
  outstr(var_name);
  Case var_type of
   cchar: WriteLn(output, ': rmb 1');
   cint: WriteLn(output, ': rmb 2');
   pointer: WriteLn(output, ': rmb 2');
   arr: WriteLn(output, ': rmb 2 ; array pointer');
  Else
   WriteLn(output, ': rmb 2');
  End;
 End;
End;

{ File operations }
Function readinline: Boolean;
Begin
 If not System.Eof(input) Then
 Begin
  ReadLn(input, line);
  lptr := 1;
  readinline := True;
 End
 Else
 Begin
  eof := 1;
  readinline := False;
 End;
End;

{ Forward declarations for expression parsing }
Procedure expression(var lval: TLVal); forward;

{ Primary expression parser }
Procedure primary_expression(var lval: TLVal);
Var
 id: String;
 num: Integer;
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
    lval.symbol := 0; { TODO: lookup in symbol table }
    lval.typ := cint;
    lval.constant := False;
    ot('ldd  ');
    outstr(id);
    nl;
   End;

  '(': Begin
    next_char; { consume '(' }
    expression(lval);
    If peek_char = ')' Then
     next_char { consume ')' }
    Else
     errrpt('Missing )');
   End;

  Else
   errrpt('Invalid primary expression');
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
Procedure expression(var lval: TLVal);
Begin
 additive_expression(lval);
End;

{ Variable declaration parsing functions - moved after expression }
Function parse_declaration: Boolean;
Var
 base_type, var_type: Integer;
 var_name: String;
 lval: TLVal;
Begin
 parse_declaration := False;
 
 { Parse type specifier }
 base_type := parse_type_specifier;
 If base_type = 0 Then Exit; { No valid type found }
 
 { Parse variable declarator(s) }
 Repeat
  var_type := parse_declarator(var_name, base_type);
  If var_type = 0 Then Exit;
  
  declare_variable(var_name, var_type);
  parse_declaration := True;
  
  { Check for initialization }
  If match('=') Then
  Begin
   WriteLn(output, '; Initializing variable: ', var_name);
   expression(lval);
   
   { Generate initialization code }
   ot('std  ');
   outstr(var_name);
   nl;
  End;
  
  { Check for multiple declarations separated by comma }
  If match(',') Then Continue
  Else Break;
 Until False;
 
 { Expect semicolon }
 If not match(';') Then
  errrpt('Expected semicolon after declaration');
End;

{ Enhanced identifier lookup with symbol table }
Function lookup_variable(var_name: String; var lval: TLVal): Boolean;
Var
 sym_ptr: Integer;
Begin
 lookup_variable := False;
 FillChar(lval, SizeOf(lval), 0);
 
 sym_ptr := findsym(var_name);
 If sym_ptr <> 0 Then
 Begin
  lookup_variable := True;
  lval.symbol := sym_ptr;
  lval.typ := Ord(symtab[sym_ptr + ctype]);
  lval.storage := Ord(symtab[sym_ptr + storage]);
  lval.indirect := 0;
  lval.constant := False;
 End
 Else
 Begin
  { Variable not found - treat as new variable for now }
  WriteLn(output, '; Warning: Undeclared variable ', var_name);
  lval.symbol := 0;
  lval.typ := cint;
  lval.constant := False;
  lookup_variable := True;
 End;
End;

Procedure ask;
Begin
 nxtlab := 0;
 kill;
 WriteLn(' Small-6809 C compiler for DOS systems V2.02 (Pascal)');
 WriteLn(' Converted to Pascal from original CC09');
 WriteLn;
 optimize := NO;
 ctext := NO;

 If ParamCount < 1 Then
 Begin
  WriteLn('usage: cc09 infile.c [outfile] [-options]');
  Halt(1);
 End;

 Assign(input, ParamStr(1));
 Reset(input);
 WriteLn('Compiling Source file: ', ParamStr(1));

 If ParamCount >= 2 Then
 Begin
  Assign(output, ParamStr(2));
  Rewrite(output);
  WriteLn('Generating asm file: ', ParamStr(2));
  use_stdout := False;
 End
 Else
 Begin
  output := Output;
  WriteLn('Using console screen for output.');
  use_stdout := True;
 End;

 asmtype := AS6809;
End;

Procedure header;
Begin
 WriteLn(output, '; ', VERSION);
End;

Procedure trailer;
Begin
 If asmtype = AS6809 Then WriteLn(output, ';    .end')
                     Else WriteLn(output, '  END');
End;

Procedure closeout;
Begin
 If not use_stdout Then Close(output);
End;

Procedure errrptsummary;
Begin
 WriteLn;
 WriteLn(errcnt, ' error(s) in compilation.');
End;

{ Enhanced parsing with variable declarations and expression parser }
Procedure parse;
Var
 lval: TLVal;
 sname: String;
 save_lptr: Integer;
Begin
 While eof = 0 do
 Begin
  If not readinline Then Break;

  { Simple comment processing }
  If match('/*') Then
  Begin
   While (not match('*/')) and (eof = 0) do
    readinline;
   Continue;
  End;

  { Skip preprocessor directives }
  If match('#') Then Continue;

  { Skip empty lines }
  blanks;
  If Length(line) = 0 Then Continue;

  WriteLn(output, '; Processing: ', line);

  { Reset position for parsing }
  lptr := 1;
  FillChar(lval, SizeOf(lval), 0);

  { Try to parse as variable declaration first }
  save_lptr := lptr;
  If parse_declaration Then
  Begin
   WriteLn(output, '; Declaration processed');
   Continue;
  End;
  
  { Reset position if declaration failed }
  lptr := save_lptr;

  { Parse identifiers and expressions }
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
     { Use expression parser for right side }
     expression(lval);

     { Store result in variable }
     ot('std  ');
     outstr(sname);
     nl;
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

{ Main program }
BEGIN
 { Initialize variables }
 FillChar(symtab, SizeOf(symtab), 0);
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

 { Compiler main body }
 ask;      { Get user options }
 header;   { Intro code }
 parse;    { Process ALL input }
 trailer;  { Follow-up code }
 closeout; { Close the output }
 errrptsummary; { Summarize errors }
END.
