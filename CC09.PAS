{ @author: Conversion from CC09 C Compiler to Pascal
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @original: Small-C Compiler for 6809 by Dieter H. Flunkert
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

Var
 { Symbol tables }
 symtab: TSymTab;
 glbptr, locptr: Integer;
 
 { Input line }
 line: TLine;
 lptr: Integer;

 { Labels and counters }
 nxtlab: Integer;
 
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

Procedure outstr(s: String);
Begin
 Write(output, s);
End;

Procedure outdec(n: Integer);
Begin
 Write(output, n);
End;

{ Error reporting }
Procedure errrpt(msg: String);
Begin
 Inc(errcnt);
 WriteLn('Error: ', msg, ' at line ', lptr);
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

{ Label management }
Function getlabel: Integer;
Begin
 Inc(nxtlab);
 getlabel := nxtlab;
End;

{ Code generation }
Procedure ot(s: String);
Begin
 Write(output, #9, s);
End;

Procedure ol(s: String);
Begin
 WriteLn(output, #9, s);
End;

Procedure prelabel(lab: Integer);
Begin
 WriteLn(output, 'L', lab, ':');
End;

Procedure printlabel(lab: Integer);
Begin
 Write(output, 'L', lab);
End;

{ File operations }
Function readinline: Boolean;
Begin
 ReadLn(input, line);
 lptr := 1;
 readinline := True;
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

{ Minimal parsing - just for basic structure }
Procedure parse;
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
  
  { Simple function detection }
  If Pos('(', line) > 0 Then
  Begin
   WriteLn(output, '; Function found: ', line);
   ol('nop ; placeholder for function');
  End;
  
  blanks;
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
