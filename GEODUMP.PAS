{ @author: Sylvain Maltais (support@gladir.com), d'apres GeoDump 0.5 de Marcus Groeber
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal / Free Pascal 3.2)
  @abstract: Clone Turbo Pascal / Free Pascal de GEODUMP 0.5.
  @license: MIT
}

Program GEODUMP;

Uses Dos;

{$A-}
{$I-}

Const
 GEOS1_ID = $53CF45C7;
 GEOS2_ID = $53C145C7;
 BSWF_ID  = $46575342;
 VM_ID    = $ADEB;
 GEOS1_HEADER_SIZE = 192;
 GEOS2_HEADER_SIZE = 256;
 APP1_HEADER_POS = $C0;
 APP2_HEADER_POS = 248;
 APP1_HEADER_SIZE = 96;
 APP2_HEADER_SIZE = 88;
 VM_DIR_HEADER_SIZE = 32;
 VM_DIR_RECORD_SIZE = 12;

Type
 TCodeMap = Array[0..8191] of Byte;
 PEntry = ^TEntry;
 TEntry = Record Next:PEntry; Seg,Ofs:Word; IsCode:Boolean; Name:String[63]; End;
 PLibrary = ^TLibrary;
 TLibrary = Record Next:PLibrary; Ordinal:Word; Name:String[8]; End;
 PFixup = ^TFixup;
 TFixup = Record Next:PFixup; FType,Ofs:Word; End;
 PSymbol = ^TSymbol;
 TSymbol = Record Next:PSymbol; Lib:String[8]; Ordinal:Word; Name:String[63]; End;
 PJumpTable = ^TJumpTable;
 TJumpTable = Record Next:PJumpTable; Seg,Ofs,Len:Word; Kind:Byte; End;
 TSegment = Record
  Len, FixLen, Flags : Word;
  Pos : LongInt;
 End;

Var
 F : File;
 FileName, DisplayName : String;
 FileLen, GeosBase : LongInt;
 GeosVersion : Integer;
 DoDump, DoList, OnePass : Boolean;
 OneResource : Integer;
 HadError : Boolean;
 CodeMap, DataMap, LabelMap, InstMap : TCodeMap;
 DisBase, DisSize : LongInt; DisSeg:Word;
 FirstEntry:PEntry; FirstLibrary:PLibrary; FirstFixup:PFixup;
 FirstSymbol:PSymbol; FirstJumpTable:PJumpTable; SelfLibrary:String[8];

Function IfThenString(Test:Boolean;Const A,B:String):String; Forward;
Procedure Fail(Const S:String); Forward;
Function WordAt(Posn:LongInt):Word; Forward;
Procedure AddEntry(Seg,Ofs:Word;IsCode:Boolean;Const Name:String); Forward;

Function HexDigit(N: Byte): Char;
Begin If N < 10 Then HexDigit := Chr(Ord('0') + N) Else HexDigit := Chr(Ord('A') + N - 10); End;

Function HexN(V: LongWord; Digits: Integer): String;
Var S: String; I: Integer;
Begin
 S := ''; For I := 1 to Digits do Begin S := HexDigit(Byte(V and 15)) + S; V := V shr 4; End;
 HexN := S;
End;

Function DecStr(V: LongInt): String;
Var S: String;
Begin Str(V, S); DecStr := S; End;
Function IfThenLong(Test:Boolean;A,B:LongInt):LongInt;
Begin If Test Then IfThenLong:=A Else IfThenLong:=B;End;

Function NextToken(Const S:String;Var P:Integer):String;
Var B:Integer;T:String;
Begin While (P<=Length(S))and(S[P] in [' ',#9])do Inc(P);B:=P;While(P<=Length(S))and not(S[P]in[' ',#9,#13,#10,';'])do Inc(P);
 T:=Copy(S,B,P-B);NextToken:=T;End;

Function NumberValue(Const S:String;HexDefault:Boolean;Var Ok:Boolean):Word;
Var I,D:Integer;V:LongInt;C:Char;
Begin V:=0;Ok:=S<>'';For I:=1 to Length(S) do Begin C:=UpCase(S[I]);If C in ['0'..'9']Then D:=Ord(C)-48 Else If HexDefault and(C in['A'..'F'])Then D:=Ord(C)-55 Else Begin Ok:=False;D:=0;End;
 If HexDefault Then V:=V*16+D Else V:=V*10+D;If V>65535 Then Ok:=False;End;NumberValue:=Word(V);End;

Function SupportPath(Const N:String):String;
Var P:String;
Begin P:=GetEnv('GEODUMP');If P=''Then P:='.';If not(P[Length(P)]in['\','/'])Then P:=P+'\';SupportPath:=P+N;End;

Procedure LoadSymbols(Const LibName:String);
Var T:Text;Line,A,B,C:String;P,IO:Integer;Ord:Word;Ok:Boolean;S:PSymbol;
Begin Assign(T,SupportPath(LibName+'.sls'));Reset(T);IO:=IOResult;If IO<>0 Then Exit;
 While not Eof(T)do Begin ReadLn(T,Line);If IOResult<>0 Then Break;P:=1;A:=NextToken(Line,P);B:=NextToken(Line,P);C:=NextToken(Line,P);
  If(A<>'')and(A[1]<>';')and(B<>'')and(C<>'')Then Begin Ord:=NumberValue(B,False,Ok);If Ok Then Begin New(S);If S=Nil Then Begin Fail('memoire insuffisante pour les symboles SLS');Break;End;
   S^.Lib:=A;S^.Ordinal:=Ord;S^.Name:=C;S^.Next:=FirstSymbol;FirstSymbol:=S;End;End;End;Close(T);IO:=IOResult;
End;

Function LibrarySymbol(Const LibName:String;Ord:Word):String;
Var S:PSymbol;
Begin S:=FirstSymbol;While S<>Nil do Begin If(S^.Lib=LibName)and(S^.Ordinal=Ord)Then Begin LibrarySymbol:=S^.Name;Exit;End;S:=S^.Next;End;LibrarySymbol:=LibName+'_'+DecStr(Ord);End;

Procedure LoadDisInfo(Const LibName:String);
Var T:Text;Line,A,B,C,D:String;P,IO:Integer;Seg,Ofs,L:Word;Ok1,Ok2,Ok3:Boolean;E:PJumpTable;K:Char;
Begin Assign(T,SupportPath(LibName+'.dis'));Reset(T);IO:=IOResult;If IO<>0 Then Exit;
 While not Eof(T)do Begin ReadLn(T,Line);If IOResult<>0 Then Break;P:=1;A:=NextToken(Line,P);If A=''Then Continue;K:=UpCase(A[1]);B:=NextToken(Line,P);C:=NextToken(Line,P);D:=NextToken(Line,P);
  Seg:=NumberValue(B,False,Ok1);Ofs:=NumberValue(C,True,Ok2);If(K in['C','D'])and Ok1 and Ok2 Then AddEntry(Seg,Ofs,K='C',D)
  Else If(K='J')and Ok1 and Ok2 Then Begin L:=NumberValue(D,True,Ok3);A:=NextToken(Line,P);If Ok3 and(A<>'')Then Begin New(E);If E<>Nil Then Begin E^.Seg:=Seg;E^.Ofs:=Ofs;E^.Len:=L;K:=UpCase(A[1]);If K='2'Then E^.Kind:=2 Else If K='4'Then E^.Kind:=4 Else If K='S'Then E^.Kind:=16 Else E^.Kind:=17;E^.Next:=FirstJumpTable;FirstJumpTable:=E;End;End;End;
 End;Close(T);IO:=IOResult;
End;

Procedure AddEntry(Seg,Ofs:Word;IsCode:Boolean;Const Name:String);
Var P:PEntry;
Begin
 P:=FirstEntry;While P<>Nil do Begin If (P^.Seg=Seg) and (P^.Ofs=Ofs) Then Begin
  If (P^.Name='') and (Name<>'') Then P^.Name:=Name;If IsCode Then P^.IsCode:=True;Exit;End;P:=P^.Next;End;
 New(P);If P=Nil Then Begin Fail('memoire insuffisante pour les symboles');Exit;End;
 P^.Seg:=Seg;P^.Ofs:=Ofs;P^.IsCode:=IsCode;P^.Name:=Name;P^.Next:=FirstEntry;FirstEntry:=P;
End;

Function LabelName(Seg,Ofs:Word;Kind:Char):String;
Var P:PEntry;
Begin P:=FirstEntry;While P<>Nil do Begin If (P^.Seg=Seg)and(P^.Ofs=Ofs)and(P^.Name<>'') Then Begin LabelName:=P^.Name;Exit;End;P:=P^.Next;End;
 LabelName:=Kind+DecStr(Seg)+'_'+HexN(Ofs,4);
End;

Procedure ClearFixups;
Var P,Q:PFixup;
Begin P:=FirstFixup;While P<>Nil do Begin Q:=P^.Next;Dispose(P);P:=Q;End;FirstFixup:=Nil;End;

Procedure LoadFixups(Posn:LongInt;Count:Word);
Var I:Word;P:PFixup;
Begin ClearFixups;If Count=0 Then Exit;For I:=0 to Count-1 do Begin New(P);If P=Nil Then Begin Fail('memoire insuffisante pour les relogements');Exit;End;
 P^.FType:=WordAt(Posn+LongInt(I)*4);P^.Ofs:=WordAt(Posn+LongInt(I)*4+2);P^.Next:=FirstFixup;FirstFixup:=P;End;End;

Function LibraryName(N:Word):String;
Var P:PLibrary;
Begin P:=FirstLibrary;While P<>Nil do Begin If P^.Ordinal=N Then Begin LibraryName:=P^.Name;Exit;End;P:=P^.Next;End;LibraryName:='LIB'+DecStr(N);End;

Function FixupSymbol(Ofs:Word):String;
Var P:PFixup;T,V,S,O:Word;
Begin FixupSymbol:='';P:=FirstFixup;While (P<>Nil)and(P^.Ofs<>Ofs)do P:=P^.Next;If P=Nil Then Exit;T:=P^.FType;V:=WordAt(DisBase+Ofs);
 Case T and $00FF of
  $00:FixupSymbol:='geos_'+DecStr(V);
  $11,$14:FixupSymbol:=LibrarySymbol(LibraryName(T shr 8),V);
  $12:FixupSymbol:='segment '+LibrarySymbol(LibraryName(T shr 8),V);
  $13:FixupSymbol:='handle '+LibraryName(T shr 8);
  $22:If V=1 Then FixupSymbol:='dgroup' Else FixupSymbol:='SEG'+DecStr(V);
  $23:FixupSymbol:='handle SEG'+DecStr(V);
  $24:Begin S:=V;O:=WordAt(DisBase+Ofs+2);FixupSymbol:=LabelName(S,O,'H');AddEntry(S,O,True,'');End;
 End;
End;

Procedure Fail(Const S: String);
Begin WriteLn('GeoDump: ', S); HadError := True; End;

Function ValidRange(Posn, Count: LongInt): Boolean;
Begin ValidRange := (Posn >= 0) and (Count >= 0) and (Posn <= FileLen) and (Count <= FileLen - Posn); End;

Procedure Go(Posn: LongInt);
Begin
 If not ValidRange(Posn, 0) Then Begin Fail('position de fichier invalide 0x' + HexN(LongWord(Posn), 8)); Exit; End;
 Seek(F, Posn); If IOResult <> 0 Then Fail('erreur de positionnement');
End;

Function ByteAt(Posn: LongInt): Byte;
Var B: Byte; N: Word;
Begin
 B := 0; If not ValidRange(Posn, 1) Then Begin Fail('fin de fichier inattendue'); ByteAt := 0; Exit; End;
 Seek(F, Posn); BlockRead(F, B, 1, N); If (IOResult <> 0) or (N <> 1) Then Fail('erreur de lecture'); ByteAt := B;
End;

Function WordAt(Posn: LongInt): Word;
Begin WordAt := Word(ByteAt(Posn)) or (Word(ByteAt(Posn + 1)) shl 8); End;

Function LongAt(Posn: LongInt): LongInt;
Begin LongAt := LongInt(LongWord(WordAt(Posn)) or (LongWord(WordAt(Posn + 2)) shl 16)); End;

Function FixedString(Posn: LongInt; Count: Integer; StopAtNull: Boolean): String;
Var S: String; I: Integer; C: Byte;
Begin
 S := ''; For I := 0 to Count - 1 do Begin C := ByteAt(Posn + I);
  If StopAtNull and (C = 0) Then Break;
  If Length(S) < 255 Then S := S + Chr(C);
 End;
 While (Length(S) > 0) and (S[Length(S)] in [#0, ' ']) do Delete(S, Length(S), 1);
 FixedString := S;
End;

Function BaseName(Const S: String): String;
Var I, StartPos, DotPos: Integer;
Begin
 StartPos := 1; DotPos := 0;
 For I := 1 to Length(S) do If S[I] in ['\','/',':'] Then Begin StartPos := I + 1; DotPos := 0; End Else If S[I] = '.' Then DotPos := I;
 If DotPos = 0 Then DotPos := Length(S) + 1; BaseName := Copy(S, StartPos, DotPos - StartPos);
End;

Function HasExtension(Const S: String): Boolean;
Var I: Integer;
Begin
 HasExtension := False; For I := Length(S) DownTo 1 do Begin
  If S[I] = '.' Then Begin HasExtension := True; Exit; End;
  If S[I] in ['\','/',':'] Then Exit;
 End;
End;

Function OpenInput(Const Requested: String): Boolean;
Var N: String; Success: Boolean;
Begin
 N := Requested; Assign(F, N); Reset(F, 1);
 If (IOResult <> 0) and not HasExtension(N) Then Begin N := N + '.GEO'; Assign(F, N); Reset(F, 1); End;
 Success := IOResult = 0; OpenInput := Success;
 If Success Then Begin FileName := N; DisplayName := BaseName(N); FileLen := FileSize(F); End;
End;

Function TokenAt(P: LongInt): String;
Var S: String; N: Word;
Begin
 S := FixedString(P, 4, True); N := WordAt(P + 4);
 If S = '' Then TokenAt := '-' Else TokenAt := S + ',' + DecStr(N);
End;

Function ReleaseAt(P: LongInt): String;
Begin ReleaseAt := DecStr(WordAt(P)) + '.' + DecStr(WordAt(P+2)) + '  ' + DecStr(WordAt(P+4)) + '-' + DecStr(WordAt(P+6)); End;

Function ProtocolAt(P: LongInt): String;
Var R: String;
Begin R := DecStr(WordAt(P+2)); While Length(R) < 3 do R := '0' + R; ProtocolAt := DecStr(WordAt(P)) + '.' + R; End;

Function Printable(B: Byte): Char;
Begin If (B >= 32) and (B <= 122) Then Printable := Chr(B) Else Printable := '.'; End;

Procedure DumpBytes(Posn, Count: LongInt; StartOffset: Word; Handle: LongInt);
Var I, J, N: LongInt; A: String; B: Byte;
Begin
 If not ValidRange(Posn, Count) Then Begin Fail('le bloc depasse la fin du fichier'); Exit; End;
 I := 0; While I < Count do Begin N := Count - I; If N > 16 Then N := 16;
  If Handle >= 0 Then A := '[' + HexN(Handle,4) + '] ' + HexN(StartOffset + I,4) + ':'
  Else If Handle = -2 Then A := '* Donnees: ' + HexN(StartOffset + I,4) + ':' Else A := HexN(StartOffset + I,4) + ':';
  Write(A); While Length(A) < 14 do Begin Write(' '); A := A + ' '; End; Write(' ');
  For J := 0 to 15 do If J < N Then Write(HexN(ByteAt(Posn+I+J),2),' ') Else Write('   ');
  For J := 0 to N - 1 do Begin B := ByteAt(Posn+I+J); Write(Printable(B)); End; WriteLn;
  Handle := -1; Inc(I, N);
 End;
End;

Function MapTest(Const M:TCodeMap; P:Word):Boolean;
Begin MapTest := (M[P shr 3] and (1 shl (P and 7)))<>0; End;
Procedure MapSet(Var M:TCodeMap; P:Word);
Begin M[P shr 3] := M[P shr 3] or (1 shl (P and 7)); End;
Procedure MapClear(Var M:TCodeMap;P:Word);
Begin M[P shr 3]:=M[P shr 3] and not(1 shl(P and 7));End;

Function SignedByte(B:Byte):Integer;
Begin If B<128 Then SignedByte:=B Else SignedByte:=Integer(B)-256; End;
Function SignedWord(W:Word):LongInt;
Begin If W<$8000 Then SignedWord:=W Else SignedWord:=LongInt(W)-65536; End;

Function RegName(N,Size:Integer):String;
Const R8:Array[0..7] of String[2]=('al','cl','dl','bl','ah','ch','dh','bh');
      R16:Array[0..7] of String[2]=('ax','cx','dx','bx','sp','bp','si','di');
      R32:Array[0..7] of String[3]=('eax','ecx','edx','ebx','esp','ebp','esi','edi');
Begin If Size=1 Then RegName:=R8[N and 7] Else If Size=4 Then RegName:=R32[N and 7] Else RegName:=R16[N and 7]; End;

Function DecodeRM(Ofs:Word; Size:Integer; Var Used:Integer; Addr32:Boolean):String;
Const EA16:Array[0..7] of String[7]=('[bx+si','[bx+di','[bp+si','[bp+di','[si','[di','[bp','[bx');
Var M,ModV,RM,Sib,Scale,Idx,Base:Byte; D:LongInt; S:String;
Begin
 M:=ByteAt(DisBase+Ofs); Used:=1; ModV:=M shr 6; RM:=M and 7;
 If ModV=3 Then Begin DecodeRM:=RegName(RM,Size);Exit;End;
 If Addr32 Then Begin
  If RM=4 Then Begin Sib:=ByteAt(DisBase+Ofs+Used);Inc(Used);Scale:=Sib shr 6;Idx:=(Sib shr 3)and 7;Base:=Sib and 7;S:='[';
   If not((ModV=0)and(Base=5)) Then S:=S+RegName(Base,4);
   If Idx<>4 Then Begin If Length(S)>1 Then S:=S+'+';S:=S+RegName(Idx,4);If Scale<>0 Then S:=S+'*'+DecStr(1 shl Scale);End;
   If (ModV=0)and(Base=5) Then Begin D:=LongAt(DisBase+Ofs+Used);Inc(Used,4);If Length(S)>1 Then S:=S+'+';S:=S+HexN(LongWord(D),8);End;
  End Else S:='['+RegName(RM,4);
  If (ModV=0) and (RM=5) Then Begin D:=LongAt(DisBase+Ofs+Used);Inc(Used,4);S:='['+HexN(LongWord(D),8);End
  Else If ModV=1 Then Begin D:=SignedByte(ByteAt(DisBase+Ofs+Used));Inc(Used);If D>=0 Then S:=S+'+';S:=S+DecStr(D);End
  Else If ModV=2 Then Begin D:=LongAt(DisBase+Ofs+Used);Inc(Used,4);S:=S+'+'+HexN(LongWord(D),8);End;
 End Else Begin S:=EA16[RM];
  If (ModV=0) and (RM=6) Then Begin D:=WordAt(DisBase+Ofs+Used);Inc(Used,2);S:='['+HexN(D,4);End
  Else If ModV=1 Then Begin D:=SignedByte(ByteAt(DisBase+Ofs+Used));Inc(Used);If D>=0 Then S:=S+'+';S:=S+DecStr(D);End
  Else If ModV=2 Then Begin D:=SignedWord(WordAt(DisBase+Ofs+Used));Inc(Used,2);If D>=0 Then S:=S+'+';S:=S+DecStr(D);End;
 End; DecodeRM:=S+']';
End;

Function DecodeInstruction(Ofs:Word; Var Text:String; Var Target:LongInt; Var Stops:Boolean):Integer;
Const Jcc:Array[0..15] of String[3]=('jo','jno','jb','jnb','je','jne','jbe','ja','js','jns','jp','jnp','jl','jge','jle','jg');
      Alu:Array[0..7] of String[3]=('add','or','adc','sbb','and','sub','xor','cmp');
      Shift:Array[0..7] of String[3]=('rol','ror','rcl','rcr','shl','shr','sal','sar');
Var P,Used,Size,OpSize:Integer; Op,Op2,M,RegV,Grp:Byte; Addr32,Prefix:Boolean; Imm:LongInt; A,B,Mn,Sym,PrefixText:String;
Begin
 P:=Ofs;Target:=-1;Stops:=False;Addr32:=False;OpSize:=2;Prefix:=True;PrefixText:='';
 While Prefix do Begin Op:=ByteAt(DisBase+P);Prefix:=False;
  Case Op of $66:Begin OpSize:=4;Prefix:=True;Inc(P);End;$67:Begin Addr32:=True;Prefix:=True;Inc(P);End;
   $26:Begin PrefixText:='es:';Prefix:=True;Inc(P);End;$2E:Begin PrefixText:='cs:';Prefix:=True;Inc(P);End;
   $36:Begin PrefixText:='ss:';Prefix:=True;Inc(P);End;$3E:Begin PrefixText:='ds:';Prefix:=True;Inc(P);End;
   $64:Begin PrefixText:='fs:';Prefix:=True;Inc(P);End;$65:Begin PrefixText:='gs:';Prefix:=True;Inc(P);End;
   $F0:Begin PrefixText:='lock ';Prefix:=True;Inc(P);End;$F2:Begin PrefixText:='repne ';Prefix:=True;Inc(P);End;$F3:Begin PrefixText:='rep ';Prefix:=True;Inc(P);End;End;
 End; Op:=ByteAt(DisBase+P);Inc(P);Text:='';
 If (Op>=$40) and (Op<=$47) Then Text:='inc '+RegName(Op-$40,OpSize)
 Else If (Op>=$48) and (Op<=$4F) Then Text:='dec '+RegName(Op-$48,OpSize)
 Else If (Op>=$50) and (Op<=$57) Then Text:='push '+RegName(Op-$50,OpSize)
 Else If (Op>=$58) and (Op<=$5F) Then Text:='pop '+RegName(Op-$58,OpSize)
 Else If (Op>=$70) and (Op<=$7F) Then Begin Target:=P+SignedByte(ByteAt(DisBase+P));Inc(P);Text:=Jcc[Op and 15]+' '+LabelName(DisSeg,Target,'L');End
 Else If (Op>=$B0) and (Op<=$B7) Then Begin Text:='mov '+RegName(Op-$B0,1)+',0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End
 Else If (Op>=$B8) and (Op<=$BF) Then Begin If OpSize=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;Text:='mov '+RegName(Op-$B8,OpSize)+',0'+HexN(LongWord(Imm),OpSize*2)+'h';End
 Else If (Op<=$3D) and ((Op and 7)<=5) Then Begin Mn:=Alu[(Op shr 3) and 7];Size:=Op and 1;If Size=0 Then Size:=1 Else Size:=OpSize;
  If (Op and 7)<4 Then Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);B:=RegName(RegV,Size);
   If (Op and 2)<>0 Then Text:=Mn+' '+B+','+A Else Text:=Mn+' '+A+','+B;
  End Else Begin If Size=1 Then Begin Imm:=ByteAt(DisBase+P);Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;
   Text:=Mn+' '+RegName(0,Size)+',0'+HexN(LongWord(Imm),Size*2)+'h';End;
 End
 Else Case Op of
  $06:Text:='push es';$07:Text:='pop es';$0E:Text:='push cs';$16:Text:='push ss';$17:Text:='pop ss';$1E:Text:='push ds';$1F:Text:='pop ds';
  $27:Text:='daa';$2F:Text:='das';$37:Text:='aaa';$3F:Text:='aas';
  $60:Text:='pusha';$61:Text:='popa';$62:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Text:='bound '+RegName(RegV,OpSize)+','+A;End;
  $63:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,2,Used,Addr32);Inc(P,Used);Text:='arpl '+A+','+RegName(RegV,2);End;
  $6C:Text:='insb';$6D:Text:='insw';$6E:Text:='outsb';$6F:Text:='outsw';
  $90:Text:='nop';$C3:Begin Text:='ret';Stops:=True;End;$CB:Begin Text:='retf';Stops:=True;End;
  $91,$92,$93,$94,$95,$96,$97:Text:='xchg '+RegName(0,OpSize)+','+RegName(Op-$90,OpSize);
  $98:If OpSize=4 Then Text:='cwde' Else Text:='cbw';$99:If OpSize=4 Then Text:='cdq' Else Text:='cwd';
  $9B:Text:='wait';$9C:Text:='pushf';$9D:Text:='popf';$9E:Text:='sahf';$9F:Text:='lahf';
  $CC:Text:='int 3';$CD:Begin Text:='int 0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End;$CF:Begin Text:='iret';Stops:=True;End;
  $E8:Begin If OpSize=4 Then Begin Target:=P+4+LongAt(DisBase+P);Inc(P,4);End Else Begin Target:=P+2+SignedWord(WordAt(DisBase+P));Inc(P,2);End;Text:='call '+LabelName(DisSeg,Target,'L');End;
  $E9:Begin If OpSize=4 Then Begin Target:=P+4+LongAt(DisBase+P);Inc(P,4);End Else Begin Target:=P+2+SignedWord(WordAt(DisBase+P));Inc(P,2);End;Text:='jmp '+LabelName(DisSeg,Target,'L');Stops:=True;End;
  $EB:Begin Target:=P+1+SignedByte(ByteAt(DisBase+P));Inc(P);Text:='jmp short '+LabelName(DisSeg,Target,'L');Stops:=True;End;
  $68:Begin Text:='push 0'+HexN(WordAt(DisBase+P),4)+'h';Inc(P,2);End;$6A:Begin Text:='push '+DecStr(SignedByte(ByteAt(DisBase+P)));Inc(P);End;
  $69,$6B:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);
   If Op=$6B Then Begin Imm:=SignedByte(ByteAt(DisBase+P));Inc(P);End Else If OpSize=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;Text:='imul '+RegName(RegV,OpSize)+','+A+','+DecStr(Imm);End;
  $80,$81,$82,$83:Begin M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;If Op in [$80,$82] Then Size:=1 Else Size:=OpSize;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
   If Op in [$80,$82,$83] Then Begin Imm:=SignedByte(ByteAt(DisBase+P));Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;
   Text:=Alu[Grp]+' '+A+','+DecStr(Imm);End;
  $86,$87:Begin If Op=$86 Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);Text:='xchg '+A+','+RegName(RegV,Size);End;
  $8C,$8E:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,2,Used,Addr32);Inc(P,Used);If Op=$8C Then Text:='mov '+A+',s'+DecStr(RegV) Else Text:='mov s'+DecStr(RegV)+','+A;End;
  $8D:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Text:='lea '+RegName(RegV,OpSize)+','+A;End;
  $8F:Begin A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Text:='pop '+A;End;
  $9A:Begin Sym:=FixupSymbol(P);Imm:=WordAt(DisBase+P);If Sym<>'' Then Text:='call far '+Sym Else Text:='call far '+HexN(WordAt(DisBase+P+2),4)+':'+HexN(Imm,4);Inc(P,4);End;
  $A0,$A1,$A2,$A3:Begin If (Op and 1)=0 Then Size:=1 Else Size:=OpSize;If Addr32 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;If (Op and 2)=0 Then Text:='mov '+RegName(0,Size)+',['+HexN(Imm,IfThenLong(Addr32,8,4))+']' Else Text:='mov ['+HexN(Imm,IfThenLong(Addr32,8,4))+'],'+RegName(0,Size);End;
  $A4:Text:='movsb';$A5:Text:='movsw';$A6:Text:='cmpsb';$A7:Text:='cmpsw';$AA:Text:='stosb';$AB:Text:='stosw';$AC:Text:='lodsb';$AD:Text:='lodsw';$AE:Text:='scasb';$AF:Text:='scasw';
  $A8:Begin Text:='test al,0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End;
  $A9:Begin If OpSize=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;Text:='test '+RegName(0,OpSize)+',0'+HexN(Imm,OpSize*2)+'h';End;
  $C0,$C1,$D0,$D1,$D2,$D3:Begin If Op in [$C0,$D0,$D2] Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
   If Op in [$D0,$D1] Then B:='1' Else If Op in [$D2,$D3] Then B:='cl' Else Begin B:=DecStr(ByteAt(DisBase+P));Inc(P);End;Text:=Shift[Grp]+' '+A+','+B;End;
  $C4,$C5:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);If Op=$C4 Then Mn:='les' Else Mn:='lds';Text:=Mn+' '+RegName(RegV,OpSize)+','+A;End;
  $C2:Begin Text:='ret '+DecStr(WordAt(DisBase+P));Inc(P,2);Stops:=True;End;$CA:Begin Text:='retf '+DecStr(WordAt(DisBase+P));Inc(P,2);Stops:=True;End;
  $C8:Begin Text:='enter '+DecStr(WordAt(DisBase+P))+','+DecStr(ByteAt(DisBase+P+2));Inc(P,3);End;$C9:Text:='leave';
  $C6,$C7:Begin If Op=$C6 Then Size:=1 Else Size:=OpSize;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);If Size=1 Then Begin Imm:=ByteAt(DisBase+P);Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;Text:='mov '+A+',0'+HexN(Imm,Size*2)+'h';End;
  $E0,$E1,$E2,$E3:Begin Target:=P+1+SignedByte(ByteAt(DisBase+P));Inc(P);Case Op of$E0:Mn:='loopne';$E1:Mn:='loope';$E2:Mn:='loop';Else Mn:='jcxz';End;Text:=Mn+' '+LabelName(DisSeg,Target,'L');End;
  $EA:Begin Text:='jmp far '+HexN(WordAt(DisBase+P+2),4)+':'+HexN(WordAt(DisBase+P),4);Inc(P,4);Stops:=True;End;
  $D4:Begin Text:='aam '+DecStr(ByteAt(DisBase+P));Inc(P);End;$D5:Begin Text:='aad '+DecStr(ByteAt(DisBase+P));Inc(P);End;$D7:Text:='xlat';
  $D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF:Begin A:=DecodeRM(P,2,Used,Addr32);Inc(P,Used);Text:='esc '+DecStr(Op-$D8)+','+A;End;
  $E4:Begin Text:='in al,0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End;$E5:Begin Text:='in '+RegName(0,OpSize)+',0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End;
  $E6:Begin Text:='out 0'+HexN(ByteAt(DisBase+P),2)+'h,al';Inc(P);End;$E7:Begin Text:='out 0'+HexN(ByteAt(DisBase+P),2)+'h,'+RegName(0,OpSize);Inc(P);End;
  $EC:Text:='in al,dx';$ED:Text:='in '+RegName(0,OpSize)+',dx';$EE:Text:='out dx,al';$EF:Text:='out dx,'+RegName(0,OpSize);
  $F5:Text:='cmc';$F6,$F7:Begin If Op=$F6 Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
   Case Grp of 0,1:Begin If Size=1 Then Begin Imm:=ByteAt(DisBase+P);Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;Text:='test '+A+',0'+HexN(Imm,Size*2)+'h';End;
    2:Text:='not '+A;3:Text:='neg '+A;4:Text:='mul '+A;5:Text:='imul '+A;6:Text:='div '+A;7:Text:='idiv '+A;End;End;
  $FE,$FF:Begin If Op=$FE Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);Case Grp of 0:Mn:='inc';1:Mn:='dec';2:Mn:='call';3:Mn:='call far';4:Begin Mn:='jmp';Stops:=True;End;5:Begin Mn:='jmp far';Stops:=True;End;6:Mn:='push';Else Mn:='???';End;Text:=Mn+' '+A;End;
  $0F:Begin Op2:=ByteAt(DisBase+P);Inc(P);If (Op2>=$80) and (Op2<=$8F) Then Begin If OpSize=4 Then Begin Target:=P+4+LongAt(DisBase+P);Inc(P,4);End Else Begin Target:=P+2+SignedWord(WordAt(DisBase+P));Inc(P,2);End;Text:=Jcc[Op2 and 15]+' '+LabelName(DisSeg,Target,'L');End
   Else If (Op2>=$90) and (Op2<=$9F) Then Begin A:=DecodeRM(P,1,Used,Addr32);Inc(P,Used);Text:='set'+Copy(Jcc[Op2 and 15],2,3)+' '+A;End
   Else If (Op2>=$C8)and(Op2<=$CF) Then Text:='bswap '+RegName(Op2-$C8,4)
   Else If Op2 in [$B6,$B7,$BE,$BF] Then Begin If (Op2 and 1)=0 Then Size:=1 Else Size:=2;M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);If (Op2 and 8)=0 Then Mn:='movzx' Else Mn:='movsx';Text:=Mn+' '+RegName(RegV,OpSize)+','+A;End
   Else If Op2 in [$A0,$A1,$A8,$A9] Then Begin If Op2 in [$A0,$A8] Then Mn:='push ' Else Mn:='pop ';If Op2<$A8 Then Mn:=Mn+'fs' Else Mn:=Mn+'gs';Text:=Mn;End
   Else If Op2 in [$A3,$AB,$B3,$BB] Then Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Case Op2 of $A3:Mn:='bt';$AB:Mn:='bts';$B3:Mn:='btr';Else Mn:='btc';End;Text:=Mn+' '+A+','+RegName(RegV,OpSize);End
   Else If Op2 in [$A4,$A5,$AC,$AD] Then Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);If Op2<$AC Then Mn:='shld' Else Mn:='shrd';If (Op2 and 1)=0 Then Begin B:=DecStr(ByteAt(DisBase+P));Inc(P);End Else B:='cl';Text:=Mn+' '+A+','+RegName(RegV,OpSize)+','+B;End
   Else If Op2 in [$AF,$B0,$B1,$BC,$BD,$C0,$C1] Then Begin If Op2 in [$B0,$C0] Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
    Case Op2 of $AF:Mn:='imul';$B0,$B1:Mn:='cmpxchg';$BC:Mn:='bsf';$BD:Mn:='bsr';Else Mn:='xadd';End;Text:=Mn+' '+RegName(RegV,Size)+','+A;End
   Else If Op2 in [$B2,$B4,$B5] Then Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);If Op2=$B2 Then Mn:='lss' Else If Op2=$B4 Then Mn:='lfs' Else Mn:='lgs';Text:=Mn+' '+RegName(RegV,OpSize)+','+A;End
   Else If Op2=$BA Then Begin M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Case Grp of 4:Mn:='bt';5:Mn:='bts';6:Mn:='btr';Else Mn:='btc';End;Text:=Mn+' '+A+','+DecStr(ByteAt(DisBase+P));Inc(P);End
   Else Text:='db 00Fh,0'+HexN(Op2,2)+'h';End;
  $88,$89,$8A,$8B,$01,$03,$29,$2B,$31,$33,$39,$3B,$84,$85:
   Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;If Op in [$88,$8A,$84] Then Size:=1 Else Size:=OpSize;
    A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);B:=RegName(RegV,Size);
    Case Op of $88,$89:Text:='mov '+A+','+B;$8A,$8B:Text:='mov '+B+','+A;$01,$03:Text:='add ';$29,$2B:Text:='sub ';$31,$33:Text:='xor ';$39,$3B:Text:='cmp ';Else Text:='test ';End;
    If Text[Length(Text)]=' ' Then If Op in [$03,$2B,$33,$3B] Then Text:=Text+B+','+A Else Text:=Text+A+','+B;
   End;
  $F8:Text:='clc';$F9:Text:='stc';$FA:Text:='cli';$FB:Text:='sti';$FC:Text:='cld';$FD:Text:='std';$F4:Begin Text:='hlt';Stops:=True;End;
 Else Text:='db 0'+HexN(Op,2)+'h'; End;
 If P>DisSize Then Begin Text:='db 0'+HexN(ByteAt(DisBase+Ofs),2)+'h';P:=Ofs+1;Target:=-1;Stops:=False;End;
 If (PrefixText<>'')and(Text<>'') Then Text:=PrefixText+Text;DecodeInstruction:=P-Ofs;
End;

Procedure ListBytes(Posn, Count: LongInt; StartOffset,Segment: Word;DefaultCode:Boolean);
Var Pass,Len,I,J,N,Scan:Integer; Target:LongInt; Changed,Stops:Boolean; T:String;E:PEntry;JT:PJumpTable;TSeg,TOfs:Word;
Begin
 If not ValidRange(Posn, Count) Then Begin Fail('la ressource depasse la fin du fichier'); Exit; End;
 DisBase:=Posn;DisSize:=Count;DisSeg:=Segment;FillChar(CodeMap,SizeOf(CodeMap),0);FillChar(DataMap,SizeOf(DataMap),0);FillChar(LabelMap,SizeOf(LabelMap),0);FillChar(InstMap,SizeOf(InstMap),0);
 If DefaultCode Then MapSet(LabelMap,StartOffset);
 E:=FirstEntry;While E<>Nil do Begin If(E^.Seg=Segment)and(E^.Ofs>=StartOffset)and(E^.Ofs<StartOffset+Count)Then Begin MapSet(LabelMap,E^.Ofs);If E^.IsCode Then MapClear(DataMap,E^.Ofs)Else MapSet(DataMap,E^.Ofs);End;E:=E^.Next;End;
 JT:=FirstJumpTable;While JT<>Nil do Begin If(JT^.Seg=Segment)and(JT^.Ofs<Count)Then Begin
  For J:=0 to JT^.Len-1 do If JT^.Ofs+J<Count Then MapSet(DataMap,JT^.Ofs+J);
  If JT^.Kind=2 Then Begin J:=0;While J+1<JT^.Len do Begin TOfs:=WordAt(Posn+JT^.Ofs+J);If TOfs<Count Then Begin AddEntry(Segment,TOfs,True,'');MapSet(LabelMap,TOfs);MapClear(DataMap,TOfs);End;Inc(J,2);End;End
  Else If JT^.Kind=4 Then Begin J:=0;While J+3<JT^.Len do Begin TSeg:=WordAt(Posn+JT^.Ofs+J);TOfs:=WordAt(Posn+JT^.Ofs+J+2);AddEntry(TSeg,TOfs,True,'');If(TSeg=Segment)and(TOfs<Count)Then Begin MapSet(LabelMap,TOfs);MapClear(DataMap,TOfs);End;Inc(J,4);End;End;
 End;JT:=JT^.Next;End;
 Pass:=0;Repeat Inc(Pass);Changed:=False;I:=0;
  While I<Count do Begin If MapTest(LabelMap,StartOffset+I) Then Begin Scan:=I;
   While (Scan<Count) and not MapTest(InstMap,StartOffset+Scan) and not MapTest(DataMap,StartOffset+Scan) do Begin
    Len:=DecodeInstruction(StartOffset+Scan,T,Target,Stops);If Len<1 Then Len:=1;MapSet(InstMap,StartOffset+Scan);
    For J:=0 to Len-1 do If Scan+J<Count Then MapSet(CodeMap,StartOffset+Scan+J);
    If (Target>=StartOffset) and (Target<StartOffset+Count) and not MapTest(LabelMap,Target) Then Begin MapSet(LabelMap,Target);MapClear(DataMap,Target);AddEntry(Segment,Target,True,'');Changed:=True;End;
    Inc(Scan,Len);If Stops Then Break;
   End;
  End;Inc(I);End;
 Until (not Changed) or OnePass or (Pass>=10);
 WriteLn('; Passes de desassemblage necessaires: ',Pass);I:=0;
 While I<Count do Begin If MapTest(LabelMap,StartOffset+I) Then If MapTest(DataMap,StartOffset+I)Then WriteLn(LabelName(Segment,StartOffset+I,'D'),':')Else WriteLn(LabelName(Segment,StartOffset+I,'L'),':');
  If MapTest(CodeMap,StartOffset+I) Then Begin Len:=DecodeInstruction(StartOffset+I,T,Target,Stops);WriteLn(#9,T);Inc(I,Len);End
  Else Begin N:=1;While (I+N<Count) and (N<8) and not MapTest(CodeMap,StartOffset+I+N) and not MapTest(LabelMap,StartOffset+I+N) do Inc(N);
   Write(#9,'db',#9);For J:=0 to N-1 do Begin If J<>0 Then Write(',');Write('0',HexN(ByteAt(Posn+I+J),2),'h');End;WriteLn;Inc(I,N);End;
 End;
End;

Function SegmentFlags(V: Word): String;
Var S: String;
 Procedure Add(Const N: String);
 Begin If S <> '' Then S := S + ','; S := S + N; End;
Begin
 S := '';
 If (V and $8000) <> 0 Then Add('INITIALISE_A_ZERO'); If (V and $4000) <> 0 Then Add('VERROUILLE');
 If (V and $2000) <> 0 Then Add('SANS_ERREUR'); If (V and $1000) <> 0 Then Add('INTERFACE');
 If (V and $0800) <> 0 Then Add('LECTURE_SEULE'); If (V and $0400) <> 0 Then Add('RESSOURCE_OBJET');
 If (V and $0200) <> 0 Then Add('CODE'); If (V and $0100) <> 0 Then Add('CONFORME');
 If (V and $0080) <> 0 Then Add('FIXE'); If (V and $0040) <> 0 Then Add('PARTAGEABLE');
 If (V and $0020) <> 0 Then Add('JETABLE'); If (V and $0010) <> 0 Then Add('PERMUTABLE');
 If (V and $0008) <> 0 Then Add('LMEM'); If (V and $0004) <> 0 Then Add('DEBOGAGE');
 If (V and $0002) <> 0 Then Add('JETE'); If (V and $0001) <> 0 Then Add('PERMUTE');
 If S = '' Then S := '0'; SegmentFlags := S;
End;

Procedure DisplayHeap(Posn, Size: LongInt);
Var HList, Entries, FreeSize, Flags, LType, I, Ofs, BlockSize, NextOfs: Word;
Begin
 If not ValidRange(Posn, 16) Then Begin Fail('en-tete LMem tronque'); Exit; End;
 HList := WordAt(Posn+2); Flags := WordAt(Posn+4); LType := WordAt(Posn+6);
 Entries := WordAt(Posn+10); Ofs := WordAt(Posn+12); FreeSize := WordAt(Posn+14);
 WriteLn; WriteLn(' * LMem: Taille: ',WordAt(Posn+8):5,' octets   Liste des handles: @ 0x',HexN(HList,4),'   Entrees: ',Entries);
 WriteLn('        Libre: ',FreeSize:5,' octets'); WriteLn('     Attributs: ',HexN(Flags,4)); WriteLn('         Type: ',HexN(LType,4));
 If (Entries > 0) and (HList < Size) and ValidRange(Posn+HList, LongInt(Entries)*2) Then
  For I := 0 to Entries - 1 do Begin
   BlockSize := WordAt(Posn+HList+LongInt(I)*2);
   If (BlockSize <> 0) and (BlockSize <> $FFFF) and (BlockSize > HList) and (BlockSize < Size) Then Begin
    If BlockSize >= 2 Then Begin
     NextOfs := WordAt(Posn+BlockSize-2); If NextOfs > 2 Then DumpBytes(Posn+BlockSize, NextOfs-2, BlockSize, HList+I*2);
    End;
   End;
  End;
 I := 0; While (Ofs <> 0) and (I < 4096) do Begin
  If (Ofs < 2) or (Ofs >= Size) Then Begin Fail('liste libre LMem invalide'); Break; End;
  BlockSize := WordAt(Posn+Ofs-2); NextOfs := WordAt(Posn+Ofs);
  WriteLn('         ',HexN(Ofs,4),': *** libre: ',BlockSize:5,' octets'); Ofs := NextOfs; Inc(I);
 End;
End;

Procedure DisplayFixup(SegPos: LongInt; FixPos: LongInt; FixCount: Word);
Var I, T, O: Word; Kind, Target: String;
Begin
 If FixCount = 0 Then Exit;
 For I := 0 to FixCount - 1 do Begin
  T := WordAt(FixPos + LongInt(I)*4); O := WordAt(FixPos + LongInt(I)*4 + 2);
  Case T and $000F of
   0: Kind := 'pointeur distant vers routine'; 1: Kind := 'deplacement vers routine'; 2: Kind := 'segment de routine';
   3: Kind := 'segment'; 4: Kind := 'pointeur distant'; Else Kind := 'inconnu';
  End;
  Case T and $0030 of $00: Target := 'noyau'; $10: Target := 'bibliotheque'; $20: Target := 'programme'; Else Target := 'inconnu'; End;
  WriteLn('  Relogements: @ 0x',HexN(O,4),'  ',Kind,' (',Target,', type=',HexN(T,4),')');
 End;
End;

Procedure DisplaySegment(Index, NumSeg: Word; TablePos: LongInt);
Var S: TSegment; FixPos, DataPos, Rounded: LongInt; FixCount: Word; Prefix, SegName: String;
Begin
 S.Len := WordAt(TablePos + LongInt(Index)*2);
 S.Pos := LongAt(TablePos + LongInt(NumSeg)*2 + LongInt(Index)*4);
 S.FixLen := WordAt(TablePos + LongInt(NumSeg)*6 + LongInt(Index)*2);
 S.Flags := WordAt(TablePos + LongInt(NumSeg)*8 + LongInt(Index)*2);
 If (Index = 0) and (S.Len = 0) Then Exit;
 If Index = 1 Then SegName := 'idata' Else SegName := 'SEG' + DecStr(Index);
 If DoList Then Begin
  If (S.Flags and 8) <> 0 Then WriteLn(SegName,#9,'SEGMENT lmem 0',HexN(WordAt(GeosBase+S.Pos+6),4),'h,0',HexN(WordAt(GeosBase+S.Pos+4),4),'h')
  Else WriteLn(SegName,#9,'SEGMENT'); Prefix := ';';
 End Else Begin WriteLn('Ressource ',Index,':'); Prefix := ' '; End;
 DataPos := GeosBase + S.Pos; Rounded := (LongInt(S.Len) + 15) and LongInt($FFFFFFF0); FixPos := DataPos + Rounded;
 FixCount := S.FixLen div 4;
 WriteLn(Prefix,' Position fichier: @ 0x0',HexN(LongWord(DataPos),8),' Taille: 0x0',HexN(S.Len,4),'     Relogements: ',FixCount);
 WriteLn(Prefix,' ',SegmentFlags(S.Flags));
 If DoDump Then Begin
  If ValidRange(FixPos,S.FixLen) Then LoadFixups(FixPos,FixCount) Else ClearFixups;
  If (S.Flags and 8) <> 0 Then DisplayHeap(DataPos, S.Len)
  Else Begin WriteLn; If DoList Then ListBytes(DataPos,S.Len,0,Index,(S.Flags and $0200)<>0) Else DumpBytes(DataPos, S.Len, 0, -2); End;
  If S.FixLen = 0 Then Begin End
  Else If ValidRange(FixPos, S.FixLen) Then DisplayFixup(DataPos, FixPos, FixCount)
  Else Fail('table de relogements tronquee dans la ressource ' + DecStr(Index));
 End;
 If DoList Then WriteLn(SegName,#9,'ENDS'); WriteLn;
End;

Procedure DisplayApplication;
Var P, D, LibPos, ExpPos, SegTable: LongInt; Attr, AppType, NumLib, NumExp, NumSeg, StackSize, I: Word;
    N, E, T,SelfName: String; LP:PLibrary;
Begin
 If GeosVersion = 1 Then P := APP1_HEADER_POS Else P := APP2_HEADER_POS; D := 0;
 If not ValidRange(P, APP1_HEADER_SIZE) Then Begin Fail('en-tete d''application tronque'); Exit; End;
 Attr := WordAt(P+34+D); AppType := WordAt(P+36+D); StackSize := WordAt(P+22+D);
 NumExp := WordAt(P+82+D); NumLib := WordAt(P+84+D); NumSeg := WordAt(P+88+D);
 N := FixedString(P+52+D,8,False); E := FixedString(P+60+D,4,False);SelfName:=N;SelfLibrary:=N;
 If DoList Then Begin LoadSymbols(SelfLibrary);LoadDisInfo(SelfLibrary);End;
 WriteLn; WriteLn('    Nom permanent: ',N,E);
 Case AppType of 1:T:='[Application]'; 2:T:='[Bibliotheque]'; 3:T:='[Pilote]'; Else T:='???'; End;
 WriteLn('            Type: ',HexN(AppType,2),' ',T); WriteLn('       Attributs: ',HexN(Attr,4));
 WriteLn(' Protocole noyau: ',ProtocolAt(P+12+D)); WriteLn('            CRC?: 0x0',HexN(WordAt(P+50+D),4));
 WriteLn(' Pile/non-init.: ',StackSize,' octets');
 LibPos := P+APP1_HEADER_SIZE;
 If NumLib > 0 Then For I := 0 to NumLib-1 do Begin
 N := FixedString(LibPos+LongInt(I)*14,8,False); AppType := WordAt(LibPos+LongInt(I)*14+8);
  New(LP);If LP<>Nil Then Begin LP^.Ordinal:=I;LP^.Name:=N;LP^.Next:=FirstLibrary;FirstLibrary:=LP;End Else Fail('memoire insuffisante pour les bibliotheques');
  If DoList Then LoadSymbols(N);
  If AppType=$2000 Then T:='Pilote' Else If AppType=$4000 Then T:='Bibliotheque' Else T:='???';
  WriteLn('  Bibliotheques: ',I:2,': ',N,' ',T,' (protocole ',ProtocolAt(LibPos+LongInt(I)*14+10),')');
 End;
 If (Attr and $8000)<>0 Then Begin WriteLn('Classe processus: Ress:0x',HexN(WordAt(P+26+D),4),' Dep:0x',HexN(WordAt(P+24+D),4));
  WriteLn('Objet application: Ress:0x',HexN(WordAt(P+30+D),4),' Fragment:0x',HexN(WordAt(P+28+D),4)); End;
 If (Attr and $4000)<>0 Then WriteLn('  Initialisation: Ress:0x',HexN(WordAt(P+78+D),4),' Dep:0x',HexN(WordAt(P+76+D),4));
 If (Attr and $2000)<>0 Then WriteLn('  Table du pilote: Ress:0x',HexN(WordAt(P+74+D),4),' Dep:0x',HexN(WordAt(P+72+D),4));
 ExpPos := LibPos + LongInt(NumLib)*14;
 If NumExp>0 Then For I:=0 to NumExp-1 do AddEntry(WordAt(ExpPos+LongInt(I)*4+2),WordAt(ExpPos+LongInt(I)*4),True,LibrarySymbol(SelfName,I));
 If (Attr and $8000)<>0 Then AddEntry(WordAt(P+26+D),WordAt(P+24+D),False,'ProcessClass');
 If (Attr and $4000)<>0 Then AddEntry(WordAt(P+78+D),WordAt(P+76+D),True,'LibraryEntry');
 If (Attr and $2000)<>0 Then AddEntry(WordAt(P+74+D),WordAt(P+72+D),False,'DriverTable');
 If DoDump and (NumExp > 0) Then For I := 0 to NumExp-1 do Begin If (I mod 4)=0 Then Write('    Exportations: ');
  Write(I:5,'=',HexN(WordAt(ExpPos+LongInt(I)*4+2),4),':',HexN(WordAt(ExpPos+LongInt(I)*4),4),' ');
  If ((I mod 4)=3) or (I=NumExp-1) Then WriteLn; End
 Else If NumExp<>0 Then WriteLn('    Exportations: ',NumExp,' emplacements');
 SegTable := ExpPos + LongInt(NumExp)*4; WriteLn;
 If DoList Then Begin WriteLn('%',#10,#10,'include stdapp.def',#10);
  If OnePass Then WriteLn('; Mode une passe demande (/1)'); WriteLn;
 End;
 If NumSeg > 0 Then For I := 0 to NumSeg-1 do If (OneResource<0) or (I=OneResource) Then DisplaySegment(I,NumSeg,SegTable);
End;

Procedure DisplayVMFile;
Var P, DirPos, RecPos, BlockPos: LongInt; DirSize, Count, I, Hdl, Flags, ID, BlockSize: Word;
    TotalUsed, TotalFree: LongInt;
Begin
 If GeosVersion=1 Then P:=$C0 Else P:=GeosBase-8;
 If GeosVersion=1 Then Inc(P,8);
 If WordAt(P)<>VM_ID Then Begin WriteLn('Fichier VM invalide.'); Exit; End;
 DirSize:=WordAt(P+2); DirPos:=LongAt(P+4)+GeosBase;
 WriteLn; WriteLn(' Repertoire VM: @ 0x',HexN(LongWord(DirPos),6),'   Longueur: ',DirSize,' octets');
 If not ValidRange(DirPos,VM_DIR_HEADER_SIZE) Then Begin Fail('repertoire VM tronque'); Exit; End;
 WriteLn; WriteLn('  Blocs libres: ',WordAt(DirPos+10),'                         Handles libres: ',WordAt(DirPos+12));
 WriteLn('  Blocs utilises: ',WordAt(DirPos+14),'                     Blocs attaches: ',WordAt(DirPos+16));
 WriteLn('   Taille totale: ',LongAt(DirPos+24),' octets'); WriteLn('       Attributs: ',HexN(WordAt(DirPos+28),4));
 WriteLn; WriteLn(' Handle bloc carte: [',HexN(WordAt(DirPos+20),4),']  Handle bloc DBMap: [',HexN(WordAt(DirPos+30),4),']');
 WriteLn('1er bloc libre: [',HexN(WordAt(DirPos+2),4),']  dernier bloc libre: [',HexN(WordAt(DirPos+4),4),']  1er handle libre: [',HexN(WordAt(DirPos+6),4),']'); WriteLn;
 If DirSize<VM_DIR_HEADER_SIZE Then Begin Fail('taille du repertoire VM invalide'); Exit; End;
 Count:=(DirSize-VM_DIR_HEADER_SIZE) div VM_DIR_RECORD_SIZE; TotalUsed:=0; TotalFree:=0;
 If Count > 0 Then For I:=0 to Count-1 do Begin RecPos:=DirPos+VM_DIR_HEADER_SIZE+LongInt(I)*VM_DIR_RECORD_SIZE;
  Hdl:=VM_DIR_HEADER_SIZE+I*VM_DIR_RECORD_SIZE; Flags:=WordAt(RecPos+2); ID:=WordAt(RecPos+4);
  BlockSize:=WordAt(RecPos+6); BlockPos:=LongAt(RecPos+8)+GeosBase; Write('[',HexN(Hdl,4),']: ');
  If BlockSize<>0 Then Begin Inc(TotalUsed,BlockSize); WriteLn('     @ 0x',HexN(LongWord(BlockPos),6),' ',BlockSize:5,' octets  Handle mem.: ',HexN(WordAt(RecPos),4),'  ID utilisateur: ',HexN(ID,4));
   If Flags<>$00FF Then WriteLn('         Attributs: ',HexN(Flags,4));
   If DoDump Then Begin If I=0 Then WriteLn('        (repertoire des handles)') Else If (Flags and $0100)<>0 Then DisplayHeap(BlockPos,BlockSize) Else DumpBytes(BlockPos,BlockSize,0,-2); WriteLn; End;
  End Else If BlockPos<>GeosBase Then Begin Inc(TotalFree,WordAt(RecPos+4)); WriteLn('libre @ 0x',HexN(LongWord(BlockPos),6),' ',WordAt(RecPos+4):5,' octets   Precedent: [',HexN(WordAt(RecPos+2),4),']  Suivant: [',HexN(WordAt(RecPos),4),']'); End
  Else WriteLn('**** (inutilise)');
 End;
 WriteLn; WriteLn('Total des blocs: ',TotalUsed+TotalFree,' octets (',TotalUsed,' utilises, ',TotalFree,' libres)');
End;

Procedure DisplayFont;
Var FontID,Raster,PointStart,PointEnd,OutlineStart,OutlineEnd:Word; Family:Byte; P:LongInt;
Begin
 WriteLn('  Nom de police: ',FixedString(13,20,True)); FontID:=WordAt(8); Raster:=WordAt(10); Family:=ByteAt(12);
 WriteLn(' ID de la police: ',HexN(FontID,4)); WriteLn('          Famille: ',HexN(Family,2),' - Moteur de rendu: ',HexN(Raster,4));
 PointStart:=WordAt(33); PointEnd:=WordAt(35); OutlineStart:=WordAt(37); OutlineEnd:=WordAt(39);
 If OutlineStart<>0 Then Begin WriteLn; WriteLn('*** Donnees vectorielles ***'); P:=LongInt(OutlineStart)+6;
  While P<LongInt(OutlineEnd)+6 do Begin Write('        Style: ',HexN(ByteAt(P),2),' - Graisse: ',HexN(ByteAt(P+1),2));
   WriteLn(' - Taille totale: ',LongAt(P+6)+LongAt(P+14)+LongAt(P+22),' octets'); If DoDump Then DumpBytes(LongAt(P+2),LongAt(P+6),0,-1); Inc(P,26); End;
 End;
 If PointStart<>0 Then Begin WriteLn; WriteLn('*** Donnees matricielles (taille en points) ***'); P:=LongInt(PointStart)+6;
  While P<LongInt(PointEnd)+6 do Begin WriteLn('   Bloc de donnees: @ ',HexN(LongWord(LongAt(P+6)),8),' - Taille: ',WordAt(P+4):5,' octets - Style: ',HexN(ByteAt(P),2),' - Taille points: ',HexN(ByteAt(P+1),2),HexN(ByteAt(P+2),2),'.',HexN(ByteAt(P+3),2));
   If DoList Then DumpBytes(LongAt(P+6),WordAt(P+4),0,-1); Inc(P,10); End;
 End; WriteLn;
End;

Procedure DisplayGeosFile;
Var Magic:LongInt; ClassID,Flags,DateV,TimeV:Word; Name,Info,Copyright:String;
Begin
 Magic:=LongAt(0); If Magic=BSWF_ID Then Begin DisplayFont; Exit; End;
 If Magic=GEOS1_ID Then Begin GeosVersion:=1; GeosBase:=0; ClassID:=WordAt(4); Flags:=WordAt(6);
  Name:=FixedString(32,36,True); Info:=FixedString(68,100,True); Copyright:=FixedString(168,24,True);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(20)); WriteLn('Type fichier GEOS: ',IfThenString(ClassID=0,'Executable (1.x)','Fichier VM (1.x)'),' Application: ',TokenAt(26));
  WriteLn('         Version: ',ReleaseAt(8),'    Protocole: ',ProtocolAt(16)); WriteLn('       Attributs: ',HexN(Flags,4));
 End Else If Magic=GEOS2_ID Then Begin GeosVersion:=2; GeosBase:=GEOS2_HEADER_SIZE; Name:=FixedString(4,36,True); ClassID:=WordAt(40); Flags:=WordAt(42);
  Info:=FixedString(68,100,True); Copyright:=FixedString(168,24,True); DateV:=WordAt(200); TimeV:=WordAt(202);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(56));
  Case ClassID of 1:Name:='Executable (2.x)';2:Name:='Fichier VM (2.x)';3:Name:='Fichier niveau octet';4:Name:='Fichier d''information de repertoire';5:Name:='Lien';Else Name:='???';End;
  WriteLn('Type fichier GEOS: ',Name,' Application: ',TokenAt(62)); WriteLn('         Version: ',ReleaseAt(44),'    Protocole: ',ProtocolAt(52));
  WriteLn('            Cree: ',(DateV shr 5) and 15:2,'/',DateV and 31:2,'/',1980+(DateV shr 9):4,'  ',TimeV shr 11:2,':',(TimeV shr 5) and 63:2,'.',(TimeV and 31)*2:2);
  WriteLn('       Attributs: ',HexN(Flags,4));
 End Else Begin WriteLn('Ce fichier n''est pas un fichier PC/GEOS.'); Exit; End;
 If Info<>'' Then WriteLn('Informations util.: ',Info); If Copyright<>'' Then WriteLn(' Droits d''auteur: ',Copyright);
 If ((GeosVersion=1) and (ClassID=0)) or ((GeosVersion=2) and (ClassID=1)) Then DisplayApplication
 Else If ((GeosVersion=1) and (ClassID=1)) or ((GeosVersion=2) and (ClassID=2)) Then DisplayVMFile;
End;

Function IfThenString(Test:Boolean;Const A,B:String):String;
Begin If Test Then IfThenString:=A Else IfThenString:=B; End;
Procedure Usage;
Begin
  WriteLn('GEODUMP - Cette commande permet d''analyser des formats de fichiers PC/GEOS.');
 WriteLn;
 WriteLn('Syntaxe : GEODUMP [/D|/L] [/Rnn] [/1] fichier');
 WriteLn(#9,'  /D      Affiche le contenu des blocs et des ressources');
 WriteLn(#9,'  /L      Produit un listing des ressources ou polices (inclut /D)');
 WriteLn(#9,'  /Rnn    Limite l''affichage a la ressource nn (decimal)');
 WriteLn(#9,'  /1      Produit le listing des la premiere passe');
End;

Procedure ParseCommand;
Var I, Code:Integer; S,N:String;
Begin
 DoDump:=False;DoList:=False;OnePass:=False;OneResource:=-1;FileName:=''; I:=1;
 While I<=ParamCount do Begin S:=ParamStr(I);
  If (Length(S)>=2) and (S[1] in ['/','-']) Then Begin
   Case UpCase(S[2]) of 'D':DoDump:=True; 'L':Begin DoList:=True;DoDump:=True;End; '1':OnePass:=True;
    '?':Begin Usage; Halt(0); End;
    'R':Begin N:=Copy(S,3,Length(S));Val(N,OneResource,Code);If (Code<>0) or (N='') Then Begin Fail('numero de ressource invalide');OneResource:=-1;End;End;
   Else Fail('option inconnue '+S); End;
  End Else If FileName='' Then FileName:=S Else Fail('trop de noms de fichiers'); Inc(I);
 End;
End;

Begin
 HadError:=False; ParseCommand; If FileName='' Then Begin Usage; Halt(1); End;
 If HadError Then Halt(1); If not OpenInput(FileName) Then Begin WriteLn('Fichier introuvable.'); Halt(1); End;
 If DoList Then WriteLn('comment %'); WriteLn; WriteLn(#9#9#9'    Contenu de ',DisplayName); WriteLn;
 DisplayGeosFile; Close(F); If HadError Then Halt(1);
End.
