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
 GeosXlate:Array[0..127]of Byte=(
  $8E,$8F,$80,$90,$A5,$99,$9A,$A0,$85,$83,$84,$20,$86,$87,$82,$8A,
  $88,$89,$A1,$8D,$8C,$8B,$A4,$A2,$95,$93,$94,$20,$A3,$97,$96,$81,
  $20,$F8,$9B,$9C,$15,$F9,$14,$E1,$20,$20,$20,$20,$20,$20,$92,$20,
  $EC,$F1,$F3,$F2,$9D,$E6,$EB,$E4,$20,$20,$F4,$A6,$A7,$EA,$91,$ED,
  $A8,$AD,$AA,$FB,$9F,$F7,$20,$AE,$AF,$20,$20,$20,$20,$20,$20,$20,
  $20,$20,$20,$20,$20,$F6,$04,$98,$20,$20,$20,$20,$20,$20,$20,$20,
  $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,
  $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20);
 GeosXlapp:Array[0..127]of Byte=(
  $8E,$8F,$80,$90,$A5,$99,$9A,$A0,$85,$83,$84,$61,$86,$87,$82,$8A,
  $88,$89,$A1,$8D,$8C,$8B,$A4,$A2,$95,$93,$94,$6F,$A3,$97,$96,$81,
  $2B,$F8,$9B,$9C,$15,$F9,$14,$E1,$52,$43,$7E,$27,$22,$D8,$92,$30,
  $EC,$F1,$F3,$F2,$9D,$E6,$EB,$E4,$E3,$E3,$F4,$A6,$A7,$EA,$91,$ED,
  $A8,$AD,$AA,$FB,$9F,$F7,$1E,$AE,$AF,$5F,$20,$41,$41,$4F,$99,$94,
  $2D,$C4,$22,$22,$60,$27,$F6,$04,$98,$59,$2F,$E8,$3C,$3E,$79,$59,
  $2B,$FA,$2C,$22,$70,$41,$45,$41,$45,$45,$49,$49,$49,$49,$4F,$4F,
  $20,$4F,$55,$55,$55,$2C,$5E,$7E,$2D,$60,$F8,$F8,$2C,$22,$2C,$27);

Type
 TCodeMap = Array[0..8191] of Byte;
 PEntry = ^TEntry;
 TEntry = Record Next:PEntry; Seg,Ofs:Word; IsCode:Boolean; Name:String[63]; End;
 PLibrary = ^TLibrary;
 TLibrary = Record Next:PLibrary; Ordinal:Word; Name:String[8]; End;
 PFixup = ^TFixup;
 TFixup = Record Next:PFixup; FType,Ofs:Word; Handled:Boolean; End;
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
 HadError, FatalError : Boolean;
 CodeMap, DataMap, LabelMap, InstMap, FreeMap, ChunkMap:TCodeMap;
 DisBase, DisSize : LongInt; DisSeg:Word;
 FirstEntry:PEntry; FirstLibrary:PLibrary; FirstFixup:PFixup;
 FirstSymbol:PSymbol; FirstJumpTable:PJumpTable; SelfLibrary:String[8];
 EntryVersion:LongInt; DisSilent:Boolean;

Function IfThenString(Test:Boolean;Const A,B:String):String; Forward;
Procedure Fail(Const S:String); Forward;
Function WordAt(Posn:LongInt):Word; Forward;
Function ValidRange(Posn,Count:LongInt):Boolean; Forward;
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

Function UpperString(Const S:String):String;
Var R:String;I:Integer;
Begin R:=S;For I:=1 to Length(R)do R[I]:=UpCase(R[I]);UpperString:=R;End;

Procedure ErrorWrite(Const S:String);
{$IFDEF FPC}
Begin Write(StdErr,S);End;
{$ELSE}
Var R:Registers;
Begin
 If S=''Then Exit;R.AH:=$40;R.BX:=2;R.CX:=Length(S);R.DS:=Seg(S[1]);R.DX:=Ofs(S[1]);MsDos(R);
End;
{$ENDIF}

Procedure ErrorWriteLn(Const S:String);
Begin ErrorWrite(S+#13#10);End;
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
  If (P^.Name='') and (Name<>'') Then Begin P^.Name:=Name;Inc(EntryVersion);End;
  If IsCode and not P^.IsCode Then Begin P^.IsCode:=True;Inc(EntryVersion);End;Exit;End;P:=P^.Next;End;
 New(P);If P=Nil Then Begin Fail('memoire insuffisante pour les symboles');Exit;End;
 P^.Seg:=Seg;P^.Ofs:=Ofs;P^.IsCode:=IsCode;P^.Name:=Name;P^.Next:=FirstEntry;FirstEntry:=P;Inc(EntryVersion);
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
 P^.FType:=WordAt(Posn+LongInt(I)*4);P^.Ofs:=WordAt(Posn+LongInt(I)*4+2);P^.Handled:=False;P^.Next:=FirstFixup;FirstFixup:=P;End;End;

Function LibraryName(N:Word):String;
Var P:PLibrary;
Begin P:=FirstLibrary;While P<>Nil do Begin If P^.Ordinal=N Then Begin LibraryName:=P^.Name;Exit;End;P:=P^.Next;End;LibraryName:='LIB'+DecStr(N);End;

Function FindFixup(Ofs:Word):PFixup;
Var P:PFixup;
Begin P:=FirstFixup;While(P<>Nil)and(P^.Ofs<>Ofs)do P:=P^.Next;FindFixup:=P;End;

Function FixupSymbol(Ofs:Word;Size:Integer):String;
Var P,Q:PFixup;T,V,S,O:Word;R,LibName:String;
Begin R:='';P:=FindFixup(Ofs);If P=Nil Then Begin FixupSymbol:='';Exit;End;T:=P^.FType;V:=WordAt(DisBase+Ofs);LibName:=LibraryName(T shr 8);
 If Size=2 Then Case T and $00FF of
  $11:R:='offset '+LibrarySymbol(LibName,V);
  $12:R:='segment '+LibrarySymbol(LibName,V);
  $13:R:='handle '+LibName;
  $22:If V=1 Then R:='dgroup' Else R:='SEG'+DecStr(V);
  $23:If V=0 Then R:='handle 0'Else R:='handle SEG'+DecStr(V);
 End Else If Size=4 Then Case T and $00FF of
  $00:R:=LibrarySymbol('geos',V);
  $11:Begin Q:=FindFixup(Ofs+2);If(Q<>Nil)and((Q^.FType and $00FF)=$12)Then Begin R:=LibrarySymbol(LibName,V);Q^.Handled:=True;End;End;
  $14:R:=LibrarySymbol(LibName,V);
  $24:Begin S:=V;O:=WordAt(DisBase+Ofs+2);R:=LabelName(S,O,'H');AddEntry(S,O,True,'');End;
 End;
 If R<>''Then P^.Handled:=True;FixupSymbol:=R;
End;

Function ImmediateOperand(Pos:Word;Size:Integer;Value:LongInt):String;
Var S:String;
Begin S:=FixupSymbol(Pos,Size);If S<>''Then ImmediateOperand:=S Else ImmediateOperand:='0'+HexN(LongWord(Value),Size*2)+'h';End;

Procedure Fail(Const S: String);
Begin WriteLn('GeoDump: ', S); HadError := True; End;

Procedure Fatal(Const S:String);
Begin If not FatalError Then WriteLn('GeoDump: erreur fatale: ',S);HadError:=True;FatalError:=True;End;

Function CheckedAdd(A,B:LongInt;Var R:LongInt):Boolean;
Begin CheckedAdd:=False;R:=0;If(A<0)or(B<0)or(A>MaxLongInt-B)Then Exit;R:=A+B;CheckedAdd:=True;End;

Function CheckedMul(A,B:LongInt;Var R:LongInt):Boolean;
Begin CheckedMul:=False;R:=0;If(A<0)or(B<0)Then Exit;If(A<>0)and(B>MaxLongInt div A)Then Exit;R:=A*B;CheckedMul:=True;End;

Function CheckedTable(Base,Count,ItemSize:LongInt;Var Last:LongInt):Boolean;
Var N:LongInt;
Begin CheckedTable:=CheckedMul(Count,ItemSize,N)and CheckedAdd(Base,N,Last)and ValidRange(Base,N);End;

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
 B := 0; If FatalError Then Begin ByteAt:=0;Exit;End;
 If not ValidRange(Posn, 1) Then Begin Fatal('fin de fichier inattendue'); ByteAt := 0; Exit; End;
 Seek(F, Posn); BlockRead(F, B, 1, N); If (IOResult <> 0) or (N <> 1) Then Fail('erreur de lecture'); ByteAt := B;
End;

Function WordAt(Posn: LongInt): Word;
Begin WordAt := Word(ByteAt(Posn)) or (Word(ByteAt(Posn + 1)) shl 8); End;

Function LongAt(Posn: LongInt): LongInt;
Begin LongAt := LongInt(LongWord(WordAt(Posn)) or (LongWord(WordAt(Posn + 2)) shl 16)); End;

Function BytesNonZero(Posn:LongInt;Count:Integer):Boolean;
Var I:Integer;
Begin BytesNonZero:=False;If not ValidRange(Posn,Count)Then Exit;For I:=0 to Count-1 do If ByteAt(Posn+I)<>0 Then Begin BytesNonZero:=True;Exit;End;End;

Procedure DisplayUnknown(Const Name:String;Posn:LongInt;Count:Integer);
Var I:Integer;
Begin If not BytesNonZero(Posn,Count)Then Exit;Write('             ',Name,': ');For I:=0 to Count-1 do Begin If I<>0 Then Write(' ');Write(HexN(ByteAt(Posn+I),2));End;WriteLn;End;

Function FileAttributes(V:Word):String;
Var S:String;Rest:Word;
 Procedure Add(Const N:String);Begin If S<>''Then S:=S+', ';S:=S+N;End;
Begin S:='';Rest:=V;If(V and $8000)<>0 Then Begin Add('MODELE');Rest:=Rest and not $8000;End;
 If(V and $4000)<>0 Then Begin Add('PUBLIC_MULTIPLE');Rest:=Rest and not $4000;End;
 If(V and $2000)<>0 Then Begin Add('PUBLIC_UNIQUE');Rest:=Rest and not $2000;End;
 If(V and $0800)<>0 Then Begin Add('CACHE');Rest:=Rest and not $0800;End;
 If Rest<>0 Then Add('INCONNU='+HexN(Rest,4));If S=''Then S:='0';FileAttributes:=S;End;

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

Function GeosChar(B:Byte;Approx:Boolean):Char;
Begin If B<128 Then GeosChar:=Chr(B)Else If Approx Then GeosChar:=Chr(GeosXlapp[B-128])Else GeosChar:=Chr(GeosXlate[B-128]);End;

Function GeosString(Const Source:String;Approx:Boolean):String;
Var S:String;I:Integer;
Begin S:=Source;For I:=1 to Length(S)do S[I]:=GeosChar(Ord(S[I]),Approx);GeosString:=S;End;

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
 If Success Then Begin FileName := N; DisplayName := UpperString(BaseName(N)); FileLen := FileSize(F); End;
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
 Else If (Op>=$B8) and (Op<=$BF) Then Begin If OpSize=4 Then Imm:=LongAt(DisBase+P) Else Imm:=WordAt(DisBase+P);Text:='mov '+RegName(Op-$B8,OpSize)+','+ImmediateOperand(P,OpSize,Imm);Inc(P,OpSize);End
 Else If (Op<=$3D) and ((Op and 7)<=5) Then Begin Mn:=Alu[(Op shr 3) and 7];Size:=Op and 1;If Size=0 Then Size:=1 Else Size:=OpSize;
  If (Op and 7)<4 Then Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);B:=RegName(RegV,Size);
   If (Op and 2)<>0 Then Text:=Mn+' '+B+','+A Else Text:=Mn+' '+A+','+B;
  End Else Begin If Size=1 Then Begin Imm:=ByteAt(DisBase+P);Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;
   Text:=Mn+' '+RegName(0,Size)+','+ImmediateOperand(P-Size,Size,Imm);End;
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
  $68:Begin If OpSize=4 Then Imm:=LongAt(DisBase+P)Else Imm:=WordAt(DisBase+P);Text:='push '+ImmediateOperand(P,OpSize,Imm);Inc(P,OpSize);End;$6A:Begin Text:='push '+DecStr(SignedByte(ByteAt(DisBase+P)));Inc(P);End;
  $69,$6B:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);
   If Op=$6B Then Begin Imm:=SignedByte(ByteAt(DisBase+P));B:=DecStr(Imm);Inc(P);End Else Begin If OpSize=4 Then Imm:=LongAt(DisBase+P)Else Imm:=WordAt(DisBase+P);B:=ImmediateOperand(P,OpSize,Imm);Inc(P,OpSize);End;Text:='imul '+RegName(RegV,OpSize)+','+A+','+B;End;
  $80,$81,$82,$83:Begin M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;If Op in [$80,$82] Then Size:=1 Else Size:=OpSize;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
   If Op in [$80,$82,$83] Then Begin Imm:=SignedByte(ByteAt(DisBase+P));Inc(P);End Else If Size=4 Then Begin Imm:=LongAt(DisBase+P);Inc(P,4);End Else Begin Imm:=WordAt(DisBase+P);Inc(P,2);End;
   If Op in[$81]Then B:=ImmediateOperand(P-Size,Size,Imm)Else B:=DecStr(Imm);Text:=Alu[Grp]+' '+A+','+B;End;
  $86,$87:Begin If Op=$86 Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);Text:='xchg '+A+','+RegName(RegV,Size);End;
  $8C,$8E:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,2,Used,Addr32);Inc(P,Used);If Op=$8C Then Text:='mov '+A+',s'+DecStr(RegV) Else Text:='mov s'+DecStr(RegV)+','+A;End;
  $8D:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Text:='lea '+RegName(RegV,OpSize)+','+A;End;
  $8F:Begin A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);Text:='pop '+A;End;
  $9A:Begin Sym:=FixupSymbol(P,4);Imm:=WordAt(DisBase+P);If Sym<>'' Then Text:='call far '+Sym Else Text:='call far '+HexN(WordAt(DisBase+P+2),4)+':'+HexN(Imm,4);Inc(P,4);End;
  $A0,$A1,$A2,$A3:Begin If (Op and 1)=0 Then Size:=1 Else Size:=OpSize;If Addr32 Then Begin Imm:=LongAt(DisBase+P);Used:=4;End Else Begin Imm:=WordAt(DisBase+P);Used:=2;End;Sym:=ImmediateOperand(P,Used,Imm);Inc(P,Used);If (Op and 2)=0 Then Text:='mov '+RegName(0,Size)+',['+Sym+']' Else Text:='mov ['+Sym+'],'+RegName(0,Size);End;
  $A4:Text:='movsb';$A5:Text:='movsw';$A6:Text:='cmpsb';$A7:Text:='cmpsw';$AA:Text:='stosb';$AB:Text:='stosw';$AC:Text:='lodsb';$AD:Text:='lodsw';$AE:Text:='scasb';$AF:Text:='scasw';
  $A8:Begin Text:='test al,0'+HexN(ByteAt(DisBase+P),2)+'h';Inc(P);End;
  $A9:Begin If OpSize=4 Then Imm:=LongAt(DisBase+P)Else Imm:=WordAt(DisBase+P);Text:='test '+RegName(0,OpSize)+','+ImmediateOperand(P,OpSize,Imm);Inc(P,OpSize);End;
  $C0,$C1,$D0,$D1,$D2,$D3:Begin If Op in [$C0,$D0,$D2] Then Size:=1 Else Size:=OpSize;M:=ByteAt(DisBase+P);Grp:=(M shr 3) and 7;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);
   If Op in [$D0,$D1] Then B:='1' Else If Op in [$D2,$D3] Then B:='cl' Else Begin B:=DecStr(ByteAt(DisBase+P));Inc(P);End;Text:=Shift[Grp]+' '+A+','+B;End;
  $C4,$C5:Begin M:=ByteAt(DisBase+P);RegV:=(M shr 3) and 7;A:=DecodeRM(P,OpSize,Used,Addr32);Inc(P,Used);If Op=$C4 Then Mn:='les' Else Mn:='lds';Text:=Mn+' '+RegName(RegV,OpSize)+','+A;End;
  $C2:Begin Text:='ret '+DecStr(WordAt(DisBase+P));Inc(P,2);Stops:=True;End;$CA:Begin Text:='retf '+DecStr(WordAt(DisBase+P));Inc(P,2);Stops:=True;End;
  $C8:Begin Text:='enter '+DecStr(WordAt(DisBase+P))+','+DecStr(ByteAt(DisBase+P+2));Inc(P,3);End;$C9:Text:='leave';
  $C6,$C7:Begin If Op=$C6 Then Size:=1 Else Size:=OpSize;A:=DecodeRM(P,Size,Used,Addr32);Inc(P,Used);If Size=1 Then Imm:=ByteAt(DisBase+P)Else If Size=4 Then Imm:=LongAt(DisBase+P)Else Imm:=WordAt(DisBase+P);Text:='mov '+A+','+ImmediateOperand(P,Size,Imm);Inc(P,Size);End;
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

Function JumpDirective(Ofs:Word;Var Text:String;Var Size:Integer):Boolean;
Var J:PJumpTable;Rel,Half,Pair:Word;Seg,Dest:Word;IsSegment:Boolean;
Begin JumpDirective:=False;J:=FirstJumpTable;While J<>Nil do Begin If(J^.Seg=DisSeg)and(Ofs>=J^.Ofs)and(Ofs<J^.Ofs+J^.Len)Then Begin
  Rel:=Ofs-J^.Ofs;
  If(J^.Kind=2)and((Rel mod 2)=0)Then Begin Dest:=WordAt(DisBase+Ofs);Text:='dw offset '+LabelName(DisSeg,Dest,'H');Size:=2;JumpDirective:=True;Exit;End;
  If(J^.Kind=4)and((Rel mod 4)=0)and(Rel+3<J^.Len)Then Begin Dest:=WordAt(DisBase+Ofs);Seg:=WordAt(DisBase+Ofs+2);Text:='dw offset '+LabelName(Seg,Dest,'H')+',segment '+LabelName(Seg,Dest,'H');Size:=4;JumpDirective:=True;Exit;End;
  If J^.Kind in[16,17]Then Begin Half:=J^.Len div 2;If(Rel mod 2)=0 Then Begin
   If Rel<Half Then Pair:=Rel Else Pair:=Rel-Half;IsSegment:=((J^.Kind=16)and(Rel<Half))or((J^.Kind=17)and(Rel>=Half));
   If J^.Kind=16 Then Begin Seg:=WordAt(DisBase+J^.Ofs+Pair);Dest:=WordAt(DisBase+J^.Ofs+Half+Pair);End
   Else Begin Dest:=WordAt(DisBase+J^.Ofs+Pair);Seg:=WordAt(DisBase+J^.Ofs+Half+Pair);End;
   If IsSegment Then Text:='dw segment '+LabelName(Seg,Dest,'H')Else Text:='dw offset '+LabelName(Seg,Dest,'H');Size:=2;JumpDirective:=True;Exit;
  End;End;
 End;J:=J^.Next;End;
End;

Function FixupDirective(Ofs:Word;Var Text:String;Var Size:Integer):Boolean;
Var P,Q:PFixup;S:String;
Begin FixupDirective:=False;P:=FindFixup(Ofs);If P=Nil Then Exit;Size:=2;
 If(P^.FType and $00FF)in[$00,$14,$24]Then Size:=4
 Else If(P^.FType and $00FF)=$11 Then Begin Q:=FindFixup(Ofs+2);If(Q<>Nil)and((Q^.FType and $00FF)=$12)Then Size:=4;End;
 S:=FixupSymbol(Ofs,Size);If S=''Then Exit;If Size=4 Then Text:='dd '+S Else Text:='dw '+S;FixupDirective:=True;
End;

Procedure ListBytes(Posn, Count: LongInt; StartOffset,Segment: Word;DefaultCode:Boolean);
Var Pass,Len,I,J,N,Scan,Half:Integer; Target:LongInt; Changed,Stops:Boolean; T:String;E:PEntry;JT:PJumpTable;TSeg,TOfs:Word;
Begin
 If not ValidRange(Posn, Count) Then Begin Fail('la ressource depasse la fin du fichier'); Exit; End;
 DisBase:=Posn-StartOffset;DisSize:=LongInt(StartOffset)+Count;DisSeg:=Segment;FillChar(CodeMap,SizeOf(CodeMap),0);FillChar(DataMap,SizeOf(DataMap),0);FillChar(LabelMap,SizeOf(LabelMap),0);FillChar(InstMap,SizeOf(InstMap),0);
 If DefaultCode Then MapSet(LabelMap,StartOffset);
 E:=FirstEntry;While E<>Nil do Begin If(E^.Seg=Segment)and(E^.Ofs>=StartOffset)and(E^.Ofs<StartOffset+Count)Then Begin MapSet(LabelMap,E^.Ofs);If E^.IsCode Then MapClear(DataMap,E^.Ofs)Else MapSet(DataMap,E^.Ofs);End;E:=E^.Next;End;
 JT:=FirstJumpTable;While JT<>Nil do Begin If(JT^.Seg=Segment)and(JT^.Ofs>=StartOffset)and(JT^.Ofs<LongInt(StartOffset)+Count)Then Begin
  If LongInt(JT^.Ofs)+JT^.Len>LongInt(StartOffset)+Count Then Begin Fail('table de sauts .DIS hors de la zone analysee '+DecStr(Segment));JT^.Len:=LongInt(StartOffset)+Count-JT^.Ofs;End;
  If(JT^.Kind in[16,17])and(((JT^.Len mod 4)<>0)or(JT^.Len=0))Then Begin Fail('longueur invalide pour une table de sauts .DIS scindee');JT^.Len:=0;End;
  For J:=0 to JT^.Len-1 do If JT^.Ofs+J<Count Then MapSet(DataMap,JT^.Ofs+J);
  If JT^.Kind=2 Then Begin J:=0;While J+1<JT^.Len do Begin TOfs:=WordAt(DisBase+JT^.Ofs+J);If(TOfs>=StartOffset)and(TOfs<LongInt(StartOffset)+Count)Then Begin AddEntry(Segment,TOfs,True,'');MapSet(LabelMap,TOfs);MapClear(DataMap,TOfs);End;Inc(J,2);End;End
  Else If JT^.Kind=4 Then Begin J:=0;While J+3<JT^.Len do Begin TOfs:=WordAt(DisBase+JT^.Ofs+J);TSeg:=WordAt(DisBase+JT^.Ofs+J+2);AddEntry(TSeg,TOfs,True,'');If(TSeg=Segment)and(TOfs>=StartOffset)and(TOfs<LongInt(StartOffset)+Count)Then Begin MapSet(LabelMap,TOfs);MapClear(DataMap,TOfs);End;Inc(J,4);End;End;
  If JT^.Kind in [16,17] Then Begin Half:=JT^.Len div 2;J:=0;While J+1<Half do Begin
   If JT^.Kind=16 Then Begin TSeg:=WordAt(DisBase+JT^.Ofs+J);TOfs:=WordAt(DisBase+JT^.Ofs+Half+J);End
   Else Begin TOfs:=WordAt(DisBase+JT^.Ofs+J);TSeg:=WordAt(DisBase+JT^.Ofs+Half+J);End;
   AddEntry(TSeg,TOfs,True,'');If(TSeg=Segment)and(TOfs>=StartOffset)and(TOfs<LongInt(StartOffset)+Count)Then Begin MapSet(LabelMap,TOfs);MapClear(DataMap,TOfs);End;Inc(J,2);
  End;End;
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
 Until (not Changed) or (Pass>=10);
 If DisSilent Then Exit;
 WriteLn('; Passes de desassemblage necessaires: ',Pass);I:=0;
 While I<Count do Begin If MapTest(LabelMap,StartOffset+I) Then If MapTest(DataMap,StartOffset+I)Then WriteLn(LabelName(Segment,StartOffset+I,'D'),':')Else WriteLn(LabelName(Segment,StartOffset+I,'L'),':');
  If MapTest(CodeMap,StartOffset+I) Then Begin Len:=DecodeInstruction(StartOffset+I,T,Target,Stops);WriteLn(#9,T);Inc(I,Len);End
  Else If FixupDirective(StartOffset+I,T,N)Then Begin WriteLn(#9,T);Inc(I,N);End
  Else If JumpDirective(StartOffset+I,T,N)Then Begin WriteLn(#9,T);Inc(I,N);End
  Else Begin N:=1;While (I+N<Count) and (N<8) and not MapTest(CodeMap,StartOffset+I+N) and not MapTest(LabelMap,StartOffset+I+N) and(FindFixup(StartOffset+I+N)=Nil)do Inc(N);
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

Procedure DisplayHeap(Posn,Size:LongInt;Const SegName:String;SegIndex:Word;ObjectResource:Boolean);
Var HList,Entries,FreeSize,Flags,LType,I,Ofs,FreeOfs,BlockSize,NextOfs,HandleOfs:Word;DataOfs:Word;
 K:LongInt;DataLen,ActualEnd,FreeTotal:LongInt;IsObject,Overlap:Boolean;CommentPrefix:String;
 FP:PFixup;
Begin
 If(Size<16)or not ValidRange(Posn,Size)Then Begin Fail('en-tete LMem tronque');Exit;End;
 HList:=WordAt(Posn+2);Flags:=WordAt(Posn+4);LType:=WordAt(Posn+6);Entries:=WordAt(Posn+10);FreeOfs:=WordAt(Posn+12);FreeSize:=WordAt(Posn+14);
 If DoList Then CommentPrefix:=';'Else CommentPrefix:=' ';
 WriteLn;WriteLn(CommentPrefix,' * LMem: Taille: ',WordAt(Posn+8):5,' octets   Liste des handles: @ 0x',HexN(HList,4),'   Entrees: ',Entries);
 WriteLn(CommentPrefix,'        Libre: ',FreeSize:5,' octets');WriteLn(CommentPrefix,'     Attributs: ',HexN(Flags,4));WriteLn(CommentPrefix,'         Type: ',HexN(LType,4));
 IsObject:=LType=2;If ObjectResource and not IsObject Then WriteLn(CommentPrefix,' * Avertissement: ressource objet sans type LMem OBJ_BLOCK');
 If DoList Then Begin FP:=FindFixup(0);If FP<>Nil Then FP^.Handled:=True;End;
 DataOfs:=16;If IsObject Then Begin If Size<26 Then Begin Fail('en-tete GEOSObjLMemBlockHeader tronque');Exit;End;
  WriteLn(CommentPrefix,' * Bloc objet: inUseCount: ',WordAt(Posn+16));WriteLn(CommentPrefix,'          interactibleCount: ',WordAt(Posn+18));
  WriteLn(CommentPrefix,'                     output: ',HexN(LongWord(LongAt(Posn+20)),8));WriteLn(CommentPrefix,'               resourceSize: ',WordAt(Posn+24));DataOfs:=26;
 End;
 If(HList<DataOfs)or(HList>Size)Then Begin Fail('position de liste de handles LMem incoherente');Exit;End;
 DataLen:=HList-DataOfs;If IsObject and(DataLen=2)Then DataLen:=0;
 If DataLen>0 Then Begin WriteLn;If DoList and(SegIndex<>$FFFF)Then Begin WriteLn(#9,'assume cs:',SegName);ListBytes(Posn+DataOfs,DataLen,DataOfs,SegIndex,False);End Else DumpBytes(Posn+DataOfs,DataLen,DataOfs,-2);End;
 If LongInt(HList)+LongInt(Entries)*2>Size Then Begin Fail('table des handles LMem tronquee');Entries:=(Size-HList)div 2;End;
 FillChar(ChunkMap,SizeOf(ChunkMap),0);
 If Entries>0 Then For I:=0 to Entries-1 do Begin HandleOfs:=HList+I*2;Ofs:=WordAt(Posn+HandleOfs);
  If(Ofs<>0)and(Ofs<>$FFFF)Then Begin If(Ofs<=HList)or(Ofs>=Size)or(Ofs<2)Then Begin Fail('handle LMem invalide @ '+HexN(HandleOfs,4));Continue;End;
   If MapTest(ChunkMap,Ofs)Then Begin Fail('handles LMem dupliques ou chunks chevauchants @ '+HexN(Ofs,4));Continue;End;
   BlockSize:=WordAt(Posn+Ofs-2);If BlockSize<2 Then Begin Fail('taille de chunk LMem invalide @ '+HexN(Ofs,4));Continue;End;
   ActualEnd:=LongInt(Ofs)-2+((LongInt(BlockSize)+3)and LongInt($FFFFFFFC));If ActualEnd>Size Then Begin Fail('chunk LMem hors du bloc @ '+HexN(Ofs,4));Continue;End;
   Overlap:=False;For K:=Ofs-2 to ActualEnd-1 do If MapTest(ChunkMap,K)Then Overlap:=True;
   If Overlap Then Begin Fail('chevauchement de chunks LMem @ '+HexN(Ofs,4));Continue;End;For K:=Ofs-2 to ActualEnd-1 do MapSet(ChunkMap,K);
   If DoList Then Begin WriteLn;WriteLn('_',SegName,'_',HexN(HandleOfs,4),' chunk byte');If BlockSize>2 Then
    If SegIndex<>$FFFF Then ListBytes(Posn+Ofs,BlockSize-2,Ofs,SegIndex,False)Else DumpBytes(Posn+Ofs,BlockSize-2,Ofs,HandleOfs);
    WriteLn('_',SegName,'_',HexN(HandleOfs,4),' endc');End
   Else If BlockSize>2 Then DumpBytes(Posn+Ofs,BlockSize-2,Ofs,HandleOfs);
  End;
 End;
 FillChar(FreeMap,SizeOf(FreeMap),0);FreeTotal:=0;Ofs:=FreeOfs;
 While Ofs<>0 do Begin If(Ofs<2)or(Ofs+2>Size)Then Begin Fail('pointeur de bloc libre LMem invalide @ '+HexN(Ofs,4));Break;End;
  If Ofs<LongInt(HList)+LongInt(Entries)*2 Then Begin Fail('bloc libre LMem dans la table des handles @ '+HexN(Ofs,4));Break;End;
  If MapTest(FreeMap,Ofs)Then Begin Fail('cycle detecte dans la liste libre LMem @ '+HexN(Ofs,4));Break;End;MapSet(FreeMap,Ofs);
  BlockSize:=WordAt(Posn+Ofs-2);NextOfs:=WordAt(Posn+Ofs);If BlockSize<4 Then Begin Fail('taille de bloc libre LMem invalide @ '+HexN(Ofs,4));Break;End;
  ActualEnd:=LongInt(Ofs)-2+((LongInt(BlockSize)+3)and LongInt($FFFFFFFC));If ActualEnd>Size Then Begin Fail('bloc libre LMem hors limites @ '+HexN(Ofs,4));Break;End;
  Overlap:=False;For K:=Ofs-2 to ActualEnd-1 do If MapTest(ChunkMap,K)or MapTest(FreeMap,K)Then If K<>Ofs Then Overlap:=True;
  If Overlap Then Begin Fail('chevauchement dans la liste libre LMem @ '+HexN(Ofs,4));Break;End;For K:=Ofs-2 to ActualEnd-1 do MapSet(FreeMap,K);
  Inc(FreeTotal,BlockSize);WriteLn(CommentPrefix,'        ',HexN(Ofs,4),': *** libre: ',BlockSize:5,' octets');
  If(NextOfs<>0)and((NextOfs<2)or(NextOfs>=Size))Then Begin Fail('chainage libre LMem corrompu vers '+HexN(NextOfs,4));Break;End;Ofs:=NextOfs;
 End;
 If FreeTotal<>FreeSize Then WriteLn(CommentPrefix,' * Avertissement: total libre calcule ',FreeTotal,' octets, en-tete ',FreeSize,' octets');
End;

Procedure AnalyzeHeap(Posn,Size:LongInt;SegIndex:Word);
Var HList,Entries,I,Ofs,BlockSize,HandleOfs,DataOfs:Word;DataLen:LongInt;
Begin
 If(Size<16)or not ValidRange(Posn,Size)Then Exit;
 HList:=WordAt(Posn+2);Entries:=WordAt(Posn+10);DataOfs:=16;
 If WordAt(Posn+6)=2 Then DataOfs:=26;
 If(HList<DataOfs)or(HList>Size)Then Exit;
 DataLen:=HList-DataOfs;If(WordAt(Posn+6)=2)and(DataLen=2)Then DataLen:=0;
 If DataLen>0 Then ListBytes(Posn+DataOfs,DataLen,DataOfs,SegIndex,False);
 If LongInt(HList)+LongInt(Entries)*2>Size Then Entries:=(Size-HList)div 2;
 If Entries>0 Then For I:=0 to Entries-1 do Begin HandleOfs:=HList+I*2;Ofs:=WordAt(Posn+HandleOfs);
  If(Ofs>HList)and(Ofs<Size)and(Ofs>=2)Then Begin BlockSize:=WordAt(Posn+Ofs-2);
   If(BlockSize>=2)and(LongInt(Ofs)+BlockSize-2<=Size)Then ListBytes(Posn+Ofs,BlockSize-2,Ofs,SegIndex,False);
  End;
 End;
End;

Procedure DisplayFixup(SegPos: LongInt; FixPos: LongInt; FixCount: Word);
Var I, T, O: Word; Kind, Target: String;P:PFixup;
Begin
 If FixCount = 0 Then Exit;
 For I := 0 to FixCount - 1 do Begin
  T := WordAt(FixPos + LongInt(I)*4); O := WordAt(FixPos + LongInt(I)*4 + 2);
  Case T and $000F of
   0: Kind := 'pointeur distant vers routine'; 1: Kind := 'deplacement vers routine'; 2: Kind := 'segment de routine';
   3: Kind := 'segment'; 4: Kind := 'pointeur distant'; Else Kind := 'inconnu';
  End;
  Case T and $0030 of $00: Target := 'noyau'; $10: Target := 'bibliotheque'; $20: Target := 'programme'; Else Target := 'inconnu'; End;
  P:=FindFixup(O);If(P<>Nil)and P^.Handled Then
   WriteLn('  Relogement integre: @ 0x',HexN(O,4),'  ',Kind,' (',Target,', type=',HexN(T,4),')')
  Else WriteLn('  Relogement non integre: @ 0x',HexN(O,4),'  ',Kind,' (',Target,', type=',HexN(T,4),')');
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
  If (S.Flags and 8) <> 0 Then DisplayHeap(DataPos,S.Len,SegName,Index,(S.Flags and $0400)<>0)
  Else Begin WriteLn; If DoList Then ListBytes(DataPos,S.Len,0,Index,(S.Flags and $0200)<>0) Else DumpBytes(DataPos, S.Len, 0, -2); End;
  If S.FixLen = 0 Then Begin End
  Else If ValidRange(FixPos, S.FixLen) Then DisplayFixup(DataPos, FixPos, FixCount)
  Else Fail('table de relogements tronquee dans la ressource ' + DecStr(Index));
 End;
 If DoList Then WriteLn(SegName,#9,'ENDS'); WriteLn;
End;

Procedure AnalyzeSegment(Index,NumSeg:Word;TablePos:LongInt);
Var S:TSegment;DataPos,FixPos,Rounded:LongInt;FixCount:Word;
Begin
 S.Len:=WordAt(TablePos+LongInt(Index)*2);S.Pos:=LongAt(TablePos+LongInt(NumSeg)*2+LongInt(Index)*4);
 S.FixLen:=WordAt(TablePos+LongInt(NumSeg)*6+LongInt(Index)*2);S.Flags:=WordAt(TablePos+LongInt(NumSeg)*8+LongInt(Index)*2);
 If(Index=0)and(S.Len=0)Then Exit;
 DataPos:=GeosBase+S.Pos;Rounded:=(LongInt(S.Len)+15)and LongInt($FFFFFFF0);FixPos:=DataPos+Rounded;FixCount:=S.FixLen div 4;
 If ValidRange(FixPos,S.FixLen)Then LoadFixups(FixPos,FixCount)Else ClearFixups;
 If(S.Flags and 8)<>0 Then AnalyzeHeap(DataPos,S.Len,Index)
 Else ListBytes(DataPos,S.Len,0,Index,(S.Flags and $0200)<>0);
End;

Procedure DisplayApplication;
Var P, D, LibPos, ExpPos, SegTable: LongInt; Attr, AppType, NumLib, NumExp, NumSeg, StackSize, I: Word;
    N, E, T,SelfName: String; LP,FoundLib:PLibrary;Pass:Integer;OldVersion:LongInt;
    TableEnd,ExportBytes,SegmentBytes,SP,RoundLen:LongInt;SLen,SFix:Word;
Begin
 If GeosVersion = 1 Then P := APP1_HEADER_POS Else P := APP2_HEADER_POS; D := 0;
 If not ValidRange(P, APP1_HEADER_SIZE) Then Begin Fail('en-tete d''application tronque'); Exit; End;
 Attr := WordAt(P+34+D); AppType := WordAt(P+36+D); StackSize := WordAt(P+22+D);
 NumExp := WordAt(P+82+D); NumLib := WordAt(P+84+D); NumSeg := WordAt(P+88+D);
 If FatalError Then Exit;
 N:=FixedString(P+52+D,8,False);E:=FixedString(P+60+D,4,False);SelfName:=N;SelfLibrary:=N;
 If DoList Then Begin LoadSymbols(SelfLibrary);LoadDisInfo(SelfLibrary);End;
 WriteLn; WriteLn('Nom permanent: ':14,N,E);
 Case AppType of 1:T:='[Application]'; 2:T:='[Bibliotheque]'; 3:T:='[Pilote]';
  5:T:='[Application GEOS 2.x]';Else T:='???'; End;
 WriteLn('Type: ':14,HexN(AppType,2),' ',T); WriteLn('Attributs: ':14,HexN(Attr,4));
 WriteLn('Protocole noyau: ':14,ProtocolAt(P+12+D)); WriteLn('CRC?: ':14,'0x0',HexN(WordAt(P+50+D),4));
 WriteLn('Pile/non-init.: ':14,StackSize,' octets');
 DisplayUnknown('_x1',P,8);DisplayUnknown('_x21',P+32+D,2);DisplayUnknown('_x3',P+70+D,2);
 DisplayUnknown('_x33',P+80+D,2);DisplayUnknown('_x4',P+86+D,2);DisplayUnknown('_x5',P+90+D,6);
 LibPos := P+APP1_HEADER_SIZE;
 If not CheckedTable(LibPos,NumLib,14,ExpPos)Then Begin Fatal('table des bibliotheques invalide ou tronquee');Exit;End;
 If NumLib > 0 Then For I := 0 to NumLib-1 do Begin
 N:=FixedString(LibPos+LongInt(I)*14,8,False);AppType:=WordAt(LibPos+LongInt(I)*14+8);
  New(LP);If LP<>Nil Then Begin LP^.Ordinal:=I;LP^.Name:=N;LP^.Next:=FirstLibrary;FirstLibrary:=LP;End Else Fail('memoire insuffisante pour les bibliotheques');
  If DoList Then LoadSymbols(N);
  If AppType=$2000 Then T:='Pilote' Else If AppType=$4000 Then T:='Bibliotheque' Else T:='???';
  If I=0 Then Write('Bibliotheques:':14)Else Write('':14);
  WriteLn('  ',I:2,': ',N,' ',T,' (protocole ',ProtocolAt(LibPos+LongInt(I)*14+10),')');
 End;
 If (Attr and $8000)<>0 Then Begin WriteLn('Classe processus: Ress:0x',HexN(WordAt(P+26+D),4),' Dep:0x',HexN(WordAt(P+24+D),4));
  WriteLn('Objet application: Ress:0x',HexN(WordAt(P+30+D),4),' Fragment:0x',HexN(WordAt(P+28+D),4)); End;
 If (Attr and $4000)<>0 Then WriteLn('  Initialisation: Ress:0x',HexN(WordAt(P+78+D),4),' Dep:0x',HexN(WordAt(P+76+D),4));
 If (Attr and $2000)<>0 Then WriteLn('  Table du pilote: Ress:0x',HexN(WordAt(P+74+D),4),' Dep:0x',HexN(WordAt(P+72+D),4));
 If not CheckedMul(NumExp,4,ExportBytes)or not CheckedAdd(ExpPos,ExportBytes,SegTable)or not ValidRange(ExpPos,ExportBytes)Then Begin Fatal('table des exportations invalide ou tronquee');Exit;End;
 If NumExp>0 Then For I:=0 to NumExp-1 do AddEntry(WordAt(ExpPos+LongInt(I)*4+2),WordAt(ExpPos+LongInt(I)*4),True,LibrarySymbol(SelfName,I));
 If (Attr and $8000)<>0 Then AddEntry(WordAt(P+26+D),WordAt(P+24+D),False,'ProcessClass');
 If (Attr and $4000)<>0 Then AddEntry(WordAt(P+78+D),WordAt(P+76+D),True,'LibraryEntry');
 If (Attr and $2000)<>0 Then AddEntry(WordAt(P+74+D),WordAt(P+72+D),False,'DriverTable');
 If DoDump and (NumExp > 0) Then For I := 0 to NumExp-1 do Begin If (I mod 4)=0 Then Write('    Exportations: ');
  Write(I:5,'=',HexN(WordAt(ExpPos+LongInt(I)*4+2),4),':',HexN(WordAt(ExpPos+LongInt(I)*4),4),' ');
  If ((I mod 4)=3) or (I=NumExp-1) Then WriteLn; End
 Else If NumExp<>0 Then WriteLn('    Exportations: ',NumExp,' emplacements');
 If not CheckedMul(NumSeg,10,SegmentBytes)or not ValidRange(SegTable,SegmentBytes)Then Begin Fatal('table des segments invalide ou tronquee');Exit;End;
 If NumSeg>0 Then For I:=0 to NumSeg-1 do Begin
  SLen:=WordAt(SegTable+LongInt(I)*2);SP:=LongAt(SegTable+LongInt(NumSeg)*2+LongInt(I)*4);
  SFix:=WordAt(SegTable+LongInt(NumSeg)*6+LongInt(I)*2);
  If(SFix mod 4)<>0 Then Begin Fatal('taille de relogement invalide dans la ressource '+DecStr(I));Exit;End;
  If not CheckedAdd(GeosBase,SP,TableEnd)or not ValidRange(TableEnd,SLen)Then Begin Fatal('donnees hors fichier dans la ressource '+DecStr(I));Exit;End;
  RoundLen:=(LongInt(SLen)+15)and LongInt($FFFFFFF0);
  If not CheckedAdd(TableEnd,RoundLen,SP)or not ValidRange(SP,SFix)Then Begin Fatal('relogements hors fichier dans la ressource '+DecStr(I));Exit;End;
 End;WriteLn;
 If DoList Then Begin WriteLn('%',#10,#10,'include stdapp.def',#10);
  For I:=0 to NumLib-1 do Begin FoundLib:=FirstLibrary;While(FoundLib<>Nil)and(FoundLib^.Ordinal<>I)do FoundLib:=FoundLib^.Next;
   If(FoundLib<>Nil)and(UpperString(FoundLib^.Name)<>'GEOS')and(UpperString(FoundLib^.Name)<>'UI')Then WriteLn('UseLib ',FoundLib^.Name,'.def');
  End;
  If OnePass Then WriteLn('; /1: listing produit des la premiere passe globale'); WriteLn;
 End;
 If DoList and not OnePass Then Begin Pass:=0;DisSilent:=True;Repeat Inc(Pass);OldVersion:=EntryVersion;
  ErrorWrite('Passe '+DecStr(Pass)+'...');
  If NumSeg>0 Then For I:=0 to NumSeg-1 do If(OneResource<0)or(I=OneResource)Then Begin ErrorWrite(' '+DecStr(I));AnalyzeSegment(I,NumSeg,SegTable);End;
  ErrorWriteLn('');
 Until(EntryVersion=OldVersion)or(Pass>=10);DisSilent:=False;WriteLn('; Passes de desassemblage necessaires: ',Pass);WriteLn;End;
 If NumSeg > 0 Then For I := 0 to NumSeg-1 do If (OneResource<0) or (I=OneResource) Then DisplaySegment(I,NumSeg,SegTable);
End;

Function VMBlockFlags(V,ChangeHandle:Word):String;
Var S:String;
 Procedure Add(Const N:String);Begin If S<>''Then S:=S+', ';S:=S+N;End;
Begin S:='';If(V and $0001)=0 Then Add('PAS_ENREGISTRE');If(V and $0004)=0 Then Add('MODIFICATIONS_DANS_['+HexN(ChangeHandle,4)+']');
 If(V and $0100)<>0 Then Add('TAS_LMEM');If(V and $0200)<>0 Then Add('MODIFICATIONS_NON_SAUVEGARDEES');
 If S=''Then S:='NORMAL';VMBlockFlags:=S;End;

Function VMDirectoryFlags(V:Word):String;
Var S:String;I:Integer;M:Word;
Begin S:='';M:=1;For I:=0 to 15 do Begin If(V and M)<>0 Then Begin If S<>''Then S:=S+', ';S:=S+'BIT_'+HexN(M,4);End;M:=M shl 1;End;
 If S=''Then S:='0';VMDirectoryFlags:=S;End;

Procedure DisplayDbHdr(Posn:LongInt;Size:Word);
Begin If(Size<16)or not ValidRange(Posn,16)Then Begin Fail('bloc DBMap tronque');Exit;End;
 WriteLn('      Handle VM: [',HexN(WordAt(Posn),4),']  Handle memoire: [',HexN(WordAt(Posn+2),4),']');
 WriteLn('      Carte primaire: groupe [',HexN(WordAt(Posn+4),4),'] / item <',HexN(WordAt(Posn+6),4),'>  reserve: ',HexN(WordAt(Posn+8),4));
End;

Function IsFreeDbItem(Posn:LongInt;Size,First,Wanted:Word):Boolean;
Var Cur,Next,Guard:Word;
Begin IsFreeDbItem:=False;Cur:=First;Guard:=0;While(Cur<>0)and(Guard<4096)do Begin If Cur=Wanted Then Begin IsFreeDbItem:=True;Exit;End;
 If(Cur+2>Size)or not ValidRange(Posn+Cur,2)Then Exit;Next:=WordAt(Posn+Cur);If Next=Cur Then Exit;Cur:=Next;Inc(Guard);End;
End;

Procedure DisplayIdx(Posn:LongInt;Size:Word);
Var Flags,MaxItems,FirstFree,BlockTop,I,BlockOfs,LocalHdl,VMHdl,Num,Unknown,MinBlock,MaxBlock:Word;
Begin If(Size<14)or not ValidRange(Posn,Size)Then Begin Fail('index de groupe DB tronque');Exit;End;
 Flags:=WordAt(Posn+4);MaxItems:=WordAt(Posn+6);FirstFree:=WordAt(Posn+8);BlockTop:=WordAt(Posn+10);
 WriteLn('      Handle VM: [',HexN(WordAt(Posn),4),']  Handle memoire: [',HexN(WordAt(Posn+2),4),']  Flags: ',HexN(Flags,4));
 WriteLn('      Limite items: ',HexN(MaxItems,4),'  premier libre: ',HexN(FirstFree,4),'  debut blocs: ',HexN(BlockTop,4),'  taille index: ',WordAt(Posn+12));
 If MaxItems=0 Then Begin WriteLn('        (index vide)');Exit;End;
 If(MaxItems>Size)or(MaxItems<14)Then Begin Fail('limite de liste d''items DB invalide');MaxItems:=Size;End;
 MinBlock:=$FFFF;MaxBlock:=0;I:=14;
 While I+4<=MaxItems do Begin If IsFreeDbItem(Posn,Size,FirstFree,I)Then WriteLn('       <',HexN(I,4),'>: item libre')Else Begin
  BlockOfs:=WordAt(Posn+I);LocalHdl:=WordAt(Posn+I+2);
  If(BlockOfs+6<=Size)Then Begin VMHdl:=WordAt(Posn+BlockOfs+2);WriteLn('       <',HexN(I,4),'>: bloc VM [',HexN(VMHdl,4),'], handle local [',HexN(LocalHdl,4),']');If BlockOfs<MinBlock Then MinBlock:=BlockOfs;If BlockOfs>MaxBlock Then MaxBlock:=BlockOfs;End
  Else WriteLn('       <',HexN(I,4),'>: reference de bloc invalide @ ',HexN(BlockOfs,4));
 End;Inc(I,4);End;
 If MinBlock<>$FFFF Then Begin I:=MinBlock;While(I<=MaxBlock)and(I+6<=Size)do Begin Unknown:=WordAt(Posn+I);VMHdl:=WordAt(Posn+I+2);Num:=WordAt(Posn+I+4);
  WriteLn('      Bloc ',HexN(I,4),': bloc VM [',HexN(VMHdl,4),'], ',Num,' item(s), reserve: ',HexN(Unknown,4));If I>$FFF9 Then Break;Inc(I,6);End;End;
End;

Function VMChangesOwner(DirPos:LongInt;Count,Target:Word):Word;
Var I,Fg,ID,H:Word;R:LongInt;
Begin VMChangesOwner:=$FFFF;If Count=0 Then Exit;For I:=0 to Count-1 do Begin R:=DirPos+VM_DIR_HEADER_SIZE+LongInt(I)*VM_DIR_RECORD_SIZE;
 If WordAt(R+6)<>0 Then Begin Fg:=WordAt(R+2);ID:=WordAt(R+4);H:=VM_DIR_HEADER_SIZE+I*VM_DIR_RECORD_SIZE;
  If((Fg and $0004)=0)and(ID=Target)Then Begin VMChangesOwner:=H;Exit;End;End;End;
End;

Function ValidateVMChain(DirPos:LongInt;Count,Start:Word;Const ChainName:String):Boolean;
Var H,Index,Steps:Word;RecPos:LongInt;
Begin
 ValidateVMChain:=False;FillChar(FreeMap,SizeOf(FreeMap),0);H:=Start;Steps:=0;
 While H<>0 do Begin
  If(H<VM_DIR_HEADER_SIZE)or(((H-VM_DIR_HEADER_SIZE)mod VM_DIR_RECORD_SIZE)<>0)Then Begin Fatal('handle invalide dans '+ChainName+' VM: '+HexN(H,4));Exit;End;
  Index:=(H-VM_DIR_HEADER_SIZE)div VM_DIR_RECORD_SIZE;
  If Index>=Count Then Begin Fatal('handle hors table dans '+ChainName+' VM: '+HexN(H,4));Exit;End;
  If MapTest(FreeMap,Index)Then Begin Fatal('cycle detecte dans '+ChainName+' VM au handle '+HexN(H,4));Exit;End;
  MapSet(FreeMap,Index);Inc(Steps);If Steps>Count Then Begin Fatal('chainage VM trop long');Exit;End;
  RecPos:=DirPos+VM_DIR_HEADER_SIZE+LongInt(Index)*VM_DIR_RECORD_SIZE;H:=WordAt(RecPos);
  If FatalError Then Exit;
 End;ValidateVMChain:=True;
End;

Procedure DisplayVMFile;
Var P,DirPos,RecPos,BlockPos:LongInt;DirSize,TableSize,Count,I,Hdl,Flags,ID,BlockSize,MapHdl,DbMapHdl:Word;
    ChangeOwner:Word;TotalUsed,TotalFree:LongInt;Role:String;
Begin
 If GeosVersion=1 Then P:=$C8 Else P:=GeosBase;
 If WordAt(P)<>VM_ID Then Begin Fatal('fichier VM invalide'); Exit; End;
 DirSize:=WordAt(P+2); DirPos:=LongAt(P+4)+GeosBase;
 WriteLn; WriteLn(' Repertoire VM: @ 0x',HexN(LongWord(DirPos),6),'   Longueur: ',DirSize,' octets');
 If not ValidRange(DirPos,VM_DIR_HEADER_SIZE) Then Begin Fail('repertoire VM tronque'); Exit; End;
 WriteLn; WriteLn('  Blocs libres: ',WordAt(DirPos+10),'                         Handles libres: ',WordAt(DirPos+12));
 WriteLn('  Blocs utilises: ',WordAt(DirPos+14),'                     Blocs attaches: ',WordAt(DirPos+16));
 WriteLn('   Taille totale: ',LongAt(DirPos+24),' octets');WriteLn('       Attributs: ',HexN(WordAt(DirPos+28),4),' [',VMDirectoryFlags(WordAt(DirPos+28)),']');
 DisplayUnknown('_x2',DirPos+18,2);DisplayUnknown('_x2b',DirPos+22,2);
 MapHdl:=WordAt(DirPos+20);DbMapHdl:=WordAt(DirPos+30);
 WriteLn; WriteLn(' Handle bloc MAP: [',HexN(MapHdl,4),']  Handle bloc DBMap: [',HexN(DbMapHdl,4),']');
 WriteLn('1er bloc libre: [',HexN(WordAt(DirPos+2),4),']  dernier bloc libre: [',HexN(WordAt(DirPos+4),4),']  1er handle libre: [',HexN(WordAt(DirPos+6),4),']'); WriteLn;
 If DirSize<VM_DIR_HEADER_SIZE Then Begin Fail('taille du repertoire VM invalide'); Exit; End;
 TableSize:=WordAt(DirPos+8);If TableSize<VM_DIR_HEADER_SIZE Then Begin Fail('taille interne du repertoire VM invalide');Exit;End;
 If TableSize>DirSize Then Begin Fail('repertoire VM interne plus grand que le bloc annonce');TableSize:=DirSize;End;
 If not ValidRange(DirPos,TableSize)Then Begin Fail('table des handles VM tronquee');Exit;End;
 Count:=(TableSize-VM_DIR_HEADER_SIZE) div VM_DIR_RECORD_SIZE; TotalUsed:=0; TotalFree:=0;
 If not ValidateVMChain(DirPos,Count,WordAt(DirPos+2),'la liste des blocs libres')Then Exit;
 If not ValidateVMChain(DirPos,Count,WordAt(DirPos+6),'la liste des handles libres')Then Exit;
 If Count > 0 Then For I:=0 to Count-1 do Begin RecPos:=DirPos+VM_DIR_HEADER_SIZE+LongInt(I)*VM_DIR_RECORD_SIZE;
  Hdl:=VM_DIR_HEADER_SIZE+I*VM_DIR_RECORD_SIZE; Flags:=WordAt(RecPos+2); ID:=WordAt(RecPos+4);
  BlockSize:=WordAt(RecPos+6); BlockPos:=LongAt(RecPos+8)+GeosBase; Write('[',HexN(Hdl,4),']: ');
  If BlockSize<>0 Then Begin Inc(TotalUsed,BlockSize);Role:='';If I=0 Then Role:='REPERTOIRE_HANDLES'Else If Hdl=MapHdl Then Role:='MAP'Else If Hdl=DbMapHdl Then Role:='DBMAP'Else If ID=$FF01 Then Role:='INDEX_GROUPE_DB';
   ChangeOwner:=VMChangesOwner(DirPos,Count,Hdl);If ChangeOwner<>$FFFF Then Begin If Role<>''Then Role:=Role+', ';Role:=Role+'MODIFICATIONS_DU_BLOC_'+HexN(ChangeOwner,4);End;
   Write('     @ 0x',HexN(LongWord(BlockPos),6),' ',BlockSize:5,' octets  Handle mem.: ',HexN(WordAt(RecPos),4),'  ID utilisateur: ',HexN(ID,4));If Role<>''Then Write('  [',Role,']');WriteLn;
   If Flags<>$00FF Then WriteLn('         Attributs VM: ',HexN(Flags,4),' [',VMBlockFlags(Flags,ID),']');
   If(Flags and $0004)=0 Then WriteLn('         Modifications les plus recentes dans le bloc [',HexN(ID,4),']');
   If(Flags and $0200)<>0 Then WriteLn('         Ce bloc contient des modifications non sauvegardees.');
   If DoDump Then Begin If I=0 Then WriteLn('        (repertoire des handles)')
    Else If (Flags and $0100)<>0 Then DisplayHeap(BlockPos,BlockSize,'VM'+HexN(Hdl,4),$FFFF,False)
    Else If Hdl=DbMapHdl Then DisplayDbHdr(BlockPos,BlockSize)
    Else If ID=$FF01 Then DisplayIdx(BlockPos,BlockSize)
    Else DumpBytes(BlockPos,BlockSize,0,-2);WriteLn;End;
  End Else If BlockPos<>GeosBase Then Begin Inc(TotalFree,WordAt(RecPos+4)); WriteLn('libre @ 0x',HexN(LongWord(BlockPos),6),' ',WordAt(RecPos+4):5,' octets   Precedent: [',HexN(WordAt(RecPos+2),4),']  Suivant: [',HexN(WordAt(RecPos),4),']'); End
  Else WriteLn('**** (inutilise)');
 End;
 WriteLn; WriteLn('Total des blocs: ',TotalUsed+TotalFree,' octets (',TotalUsed,' utilises, ',TotalFree,' libres)');
End;

Function SignedWordAt(P:LongInt):Integer;
Var W:Word;
Begin W:=WordAt(P);If W<$8000 Then SignedWordAt:=W Else SignedWordAt:=LongInt(W)-65536;End;

Function CharFlags(Fg:Byte):String;
Var S:String;
 Procedure Add(Const N:String);Begin If S<>''Then S:=S+',';S:=S+N;End;
Begin S:='';If(Fg and $40)<>0 Then Add('LSB_NEGATIF');If(Fg and $20)<>0 Then Add('AU_DESSUS_ASCENDANTE');
 If(Fg and $10)<>0 Then Add('SOUS_DESCENDANTE');If(Fg and $08)<>0 Then Add('SANS_DONNEES');
 If(Fg and $04)<>0 Then Add('PREMIER_CRENE');If(Fg and $02)<>0 Then Add('SECOND_CRENE');If(Fg and $01)<>0 Then Add('INVISIBLE');
 If S=''Then S:='0';CharFlags:=S;End;

Procedure DisplayNimbusChar(Posn,Size:LongInt);
Var P,Last:LongInt;N,I:Integer;Op:Byte;X1,Y1,X2,Y2,X3,Y3:Integer;
Begin If not ValidRange(Posn,Size)or(Size<9)Then Begin Fail('glyphe Nimbus tronque');Exit;End;P:=Posn;Last:=Posn+Size;
 WriteLn('  Boite englobante: (',SignedWordAt(P),',',SignedWordAt(P+2),')-(',SignedWordAt(P+4),',',SignedWordAt(P+6),')');Inc(P,8);
 If P>=Last Then Exit;N:=ByteAt(P);Inc(P);If N<>0 Then WriteLn('  Hints horizontaux:');
 For I:=1 to N do Begin If P+6>Last Then Begin Fail('hints horizontaux Nimbus tronques');Exit;End;WriteLn('    x1=',SignedWordAt(P),', x2=',SignedWordAt(P+2),', largeur=',SignedWordAt(P+4));Inc(P,6);End;
 If P>=Last Then Exit;N:=ByteAt(P);Inc(P);If N<>0 Then WriteLn('  Hints verticaux:');
 For I:=1 to N do Begin If P+6>Last Then Begin Fail('hints verticaux Nimbus tronques');Exit;End;WriteLn('    y1=',SignedWordAt(P),', y2=',SignedWordAt(P+2),', hauteur=',SignedWordAt(P+4));Inc(P,6);End;
 WriteLn('  Trace du caractere:');Op:=255;
 While(P<Last)and not(Op in[3,5])do Begin Op:=ByteAt(P);Inc(P);Case Op of
  0,1:Begin If P+4>Last Then Begin Fail('commande MOVE/LINE tronquee');Exit;End;X1:=SignedWordAt(P);Y1:=SignedWordAt(P+2);Inc(P,4);If Op=0 Then WriteLn('    MOVE (',X1,',',Y1,')')Else WriteLn('    LINE (',X1,',',Y1,')');End;
  2:Begin If P+12>Last Then Begin Fail('commande BEZIER tronquee');Exit;End;X1:=SignedWordAt(P);Y1:=SignedWordAt(P+2);X2:=SignedWordAt(P+4);Y2:=SignedWordAt(P+6);X3:=SignedWordAt(P+8);Y3:=SignedWordAt(P+10);Inc(P,12);WriteLn('    BEZIER (',X1,',',Y1,'),(',X2,',',Y2,'),(',X3,',',Y3,')');End;
  3:WriteLn('    DONE');4:WriteLn('    ILLEGAL');
  5:Begin If P+6>Last Then Begin Fail('commande ACCENT tronquee');Exit;End;X1:=ByteAt(P);X2:=SignedWordAt(P+1);Y2:=SignedWordAt(P+3);X3:=ByteAt(P+5);Inc(P,6);WriteLn('    ACCENT ',X1,',(',X2,',',Y2,'),',X3);End;
  6,7:Begin If P+2>Last Then Begin Fail('commande de ligne Nimbus tronquee');Exit;End;X1:=SignedWordAt(P);Inc(P,2);If Op=6 Then WriteLn('    VERT_LINE ',X1)Else WriteLn('    HORZ_LINE ',X1);End;
  8:Begin If P+2>Last Then Begin Fail('commande REL_LINE tronquee');Exit;End;Y1:=SignedByte(ByteAt(P));X1:=SignedByte(ByteAt(P+1));Inc(P,2);WriteLn('    REL_LINE (',X1,',',Y1,')');End;
  9:Begin If P+6>Last Then Begin Fail('commande REL_CURVE tronquee');Exit;End;X1:=SignedByte(ByteAt(P));Y1:=SignedByte(ByteAt(P+1));X2:=SignedByte(ByteAt(P+2));Y2:=SignedByte(ByteAt(P+3));X3:=SignedByte(ByteAt(P+4));Y3:=SignedByte(ByteAt(P+5));Inc(P,6);WriteLn('    REL_CURVE (',X1,',',Y1,'),(',X2,',',Y2,'),(',X3,',',Y3,')');End;
 Else Begin WriteLn('    COMMANDE_INCONNUE ',Op);Exit;End;End;End;WriteLn;
End;

Procedure DisplayFont;
Const NFH_SIZE=43;
Var FontID,Raster,PointStart,PointEnd,OutlineStart,OutlineEnd,FirstChar,LastChar,NumChars:Word;Family,Fg:Byte;
 P,HeaderPos,HeaderSize,FirstPos,FirstSize,SecondPos,SecondSize,Pos2,KernPos,TotalSize,Missing:LongInt;
 Widths,Offsets:Array[0..255]of Word;Flags:Array[0..255]of Byte;I,Ch,Ch2,NKern,GlyphLen:Integer;C1,C2:Byte;
Begin
 WriteLn('  Nom de police: ',GeosString(FixedString(13,20,True),True));FontID:=WordAt(8);Raster:=WordAt(10);Family:=ByteAt(12);
 WriteLn(' ID de la police: ',HexN(FontID,4));WriteLn('          Famille: ',HexN(Family,2),' - Moteur de rendu: ',HexN(Raster,4));
 PointStart:=WordAt(33);PointEnd:=WordAt(35);OutlineStart:=WordAt(37);OutlineEnd:=WordAt(39);TotalSize:=0;
 If OutlineStart<>0 Then Begin WriteLn;WriteLn('*** Donnees vectorielles ***');P:=LongInt(OutlineStart)+6;
  If(OutlineEnd<OutlineStart)or not ValidRange(P,LongInt(OutlineEnd)-OutlineStart)or(((LongInt(OutlineEnd)-OutlineStart)mod 26)<>0)Then Begin Fatal('table des polices vectorielles BSWF invalide');Exit;End;
  While P<LongInt(OutlineEnd)+6 do Begin If not ValidRange(P,26)Then Begin Fail('entree de police vectorielle tronquee');Break;End;
   Fg:=ByteAt(P);HeaderPos:=LongAt(P+2);HeaderSize:=LongAt(P+6);FirstPos:=LongAt(P+10);FirstSize:=LongAt(P+14);SecondPos:=LongAt(P+18);SecondSize:=LongAt(P+22);
   If(HeaderSize<0)or(FirstSize<0)or(SecondSize<0)or not ValidRange(HeaderPos,HeaderSize)or not ValidRange(FirstPos,FirstSize)or not ValidRange(SecondPos,SecondSize)Then Begin Fatal('bloc de donnees Nimbus hors fichier');Exit;End;
   If HeaderSize>MaxLongInt-FirstSize Then Begin Fatal('taille Nimbus debordante');Exit;End;Pos2:=HeaderSize+FirstSize;
   If Pos2>MaxLongInt-SecondSize Then Begin Fatal('taille Nimbus debordante');Exit;End;Pos2:=Pos2+SecondSize;
   If TotalSize>MaxLongInt-Pos2 Then Begin Fatal('taille totale BSWF debordante');Exit;End;
   WriteLn('        Style: ',HexN(Fg,2),' - Graisse: ',HexN(ByteAt(P+1),2),' - Taille totale: ',Pos2,' octets');Inc(TotalSize,Pos2);
   If DoDump Then Begin If not ValidRange(HeaderPos,HeaderSize)or(HeaderSize<NFH_SIZE)Then Fail('en-tete Nimbus invalide')Else Begin
    WriteLn('  En-tete Nimbus:');WriteLn('    Hauteur H: ',WordAt(HeaderPos),'  Hauteur X: ',WordAt(HeaderPos+2),'  Ascendante: ',WordAt(HeaderPos+4),'  Descendante: ',WordAt(HeaderPos+6));
    WriteLn('    Largeur moyenne: ',WordAt(HeaderPos+8),'  maximale: ',WordAt(HeaderPos+10),'  hauteur: ',WordAt(HeaderPos+12));
    WriteLn('    Accent: ',WordAt(HeaderPos+14),'  ascension: ',WordAt(HeaderPos+16),'  descente: ',WordAt(HeaderPos+18),'  ajustement base: ',WordAt(HeaderPos+20));
    FirstChar:=ByteAt(HeaderPos+22);LastChar:=ByteAt(HeaderPos+23);NumChars:=WordAt(HeaderPos+31);
    If LastChar<FirstChar Then Begin Fatal('intervalle de caracteres Nimbus inverse');Exit;End;
    WriteLn('    Caracteres: ',FirstChar,'..',LastChar,'  defaut: ',ByteAt(HeaderPos+24),'  nombre: ',NumChars);
    WriteLn('    Souligne: position=',WordAt(HeaderPos+25),' epaisseur=',WordAt(HeaderPos+27),'  barre=',WordAt(HeaderPos+29));
    WriteLn('    Marges: LSB=',SignedWordAt(HeaderPos+33),' TSB=',SignedWordAt(HeaderPos+35),' BSB=',SignedWordAt(HeaderPos+37),' RSB=',SignedWordAt(HeaderPos+39),' continuite=',SignedWordAt(HeaderPos+41));
    FillChar(Widths,SizeOf(Widths),0);FillChar(Flags,SizeOf(Flags),0);FillChar(Offsets,SizeOf(Offsets),0);
    If NumChars>256-FirstChar Then Begin Fail('nombre de caracteres Nimbus invalide');NumChars:=256-FirstChar;End;
    If HeaderSize<NFH_SIZE+LongInt(NumChars)*3 Then Begin Fail('taille de table des largeurs Nimbus invalide');NumChars:=0;End;
    For I:=0 to NumChars-1 do Begin Pos2:=HeaderPos+NFH_SIZE+LongInt(I)*3;If not ValidRange(Pos2,3)Then Begin Fail('table des largeurs Nimbus tronquee');Break;End;Widths[FirstChar+I]:=WordAt(Pos2);Flags[FirstChar+I]:=ByteAt(Pos2+2);End;
    KernPos:=HeaderPos+NFH_SIZE+LongInt(NumChars)*3;NKern:=(HeaderSize-NFH_SIZE-LongInt(NumChars)*3)div 4;
    If not ValidRange(KernPos,LongInt(NKern)*4)Then Begin Fail('table de crenage Nimbus tronquee');NKern:=0;End;
    If NKern>0 Then Begin WriteLn('  Crenage: ',NKern,' paire(s)');For I:=0 to NKern-1 do Begin C1:=ByteAt(KernPos+LongInt(I)*2);C2:=ByteAt(KernPos+LongInt(I)*2+1);WriteLn('    ',C2,' (''',GeosChar(C2,False),''') / ',C1,' (''',GeosChar(C1,False),'''): ',SignedWordAt(KernPos+LongInt(NKern)*2+LongInt(I)*2));End;End;
    If LastChar<$80 Then Ch2:=LastChar Else Ch2:=$7F;
    If(FirstChar<$80)and(FirstSize<LongInt(Ch2-FirstChar+1)*2)Then Begin Fatal('table basse des offsets Nimbus tronquee');Exit;End;
    If(LastChar>$7F)and(SecondSize<LongInt(LastChar-$7F)*2)Then Begin Fatal('table haute des offsets Nimbus tronquee');Exit;End;
    If FirstChar<$80 Then For Ch:=FirstChar to Ch2 do Offsets[Ch]:=WordAt(FirstPos+LongInt(Ch-FirstChar)*2);
    If LastChar>$7F Then For Ch:=$80 to LastChar do Offsets[Ch]:=WordAt(SecondPos+LongInt(Ch-$80)*2);
    For Ch:=FirstChar to LastChar do If Offsets[Ch]<>0 Then Begin GlyphLen:=0;
     If((Ch<$80)and(Offsets[Ch]>FirstSize))or((Ch>=$80)and(Offsets[Ch]>SecondSize))Then Begin Fatal('offset de glyphe Nimbus hors bloc');Exit;End;
     For Ch2:=Ch+1 to LastChar do If Offsets[Ch2]<>0 Then Begin If(Ch<$80)and(Ch2>=$80)Then GlyphLen:=FirstSize-Offsets[Ch]Else If(Ch<$80)=(Ch2<$80)Then GlyphLen:=Offsets[Ch2]-Offsets[Ch];Break;End;
     If GlyphLen=0 Then If Ch<$80 Then GlyphLen:=FirstSize-Offsets[Ch]Else GlyphLen:=SecondSize-Offsets[Ch];
     If GlyphLen<0 Then Begin Fail('offsets de glyphes Nimbus non ordonnes');GlyphLen:=0;End;
     WriteLn('  Caractere: ',Ch,' (''',GeosChar(Ch,False),''') - Largeur: ',Widths[Ch],' - Attributs: ',HexN(Flags[Ch],2),' [',CharFlags(Flags[Ch]),'] - Offset: ',HexN(Offsets[Ch],4),' - Taille: ',GlyphLen);
     If(Raster=$1000)and DoList and(GlyphLen>0)Then If Ch<$80 Then DisplayNimbusChar(FirstPos+Offsets[Ch],GlyphLen)Else DisplayNimbusChar(SecondPos+Offsets[Ch],GlyphLen);
    End;
   End;End;Inc(P,26);
  End;
 End;
 If PointStart<>0 Then Begin WriteLn;WriteLn('*** Donnees matricielles (taille en points) ***');P:=LongInt(PointStart)+6;
  If(PointEnd<PointStart)or not ValidRange(P,LongInt(PointEnd)-PointStart)or(((LongInt(PointEnd)-PointStart)mod 10)<>0)Then Begin Fatal('table des polices matricielles BSWF invalide');Exit;End;
  While P<LongInt(PointEnd)+6 do Begin If not ValidRange(P,10)Then Begin Fail('entree de police matricielle tronquee');Break;End;
   If not ValidRange(LongAt(P+6),WordAt(P+4))Then Begin Fatal('bloc matriciel BSWF hors fichier');Exit;End;
   WriteLn('   Bloc de donnees: @ ',HexN(LongWord(LongAt(P+6)),8),' - Taille: ',WordAt(P+4):5,' octets - Style: ',HexN(ByteAt(P),2),' - Taille points: ',HexN(ByteAt(P+1),2),HexN(ByteAt(P+2),2),'.',HexN(ByteAt(P+3),2));
   If DoList Then DumpBytes(LongAt(P+6),WordAt(P+4),0,-1);Inc(TotalSize,WordAt(P+4));Inc(P,10);End;
 End;Missing:=FileLen-TotalSize-(LongInt(PointEnd)-PointStart)-(LongInt(OutlineEnd)-OutlineStart)-41;WriteLn;WriteLn(' Taille manquante: ',Missing,' octets');WriteLn;
End;

Procedure DisplayGeosFile;
Var Magic:LongInt;ClassID,Flags,DateV,TimeV:Word;Name,Info,Copyright,Password:String;
Begin
 Magic:=LongAt(0);If FatalError Then Exit; If Magic=BSWF_ID Then Begin DisplayFont; Exit; End;
 If Magic=GEOS1_ID Then Begin GeosVersion:=1; GeosBase:=0; ClassID:=WordAt(4); Flags:=WordAt(6);
  Name:=GeosString(FixedString(32,36,True),True);Info:=GeosString(FixedString(68,100,True),True);Copyright:=GeosString(FixedString(168,24,True),True);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(20)); WriteLn('Type fichier GEOS: ',IfThenString(ClassID=0,'Executable (1.x)','Fichier VM (1.x)'),' Application: ',TokenAt(26));
  WriteLn('         Version: ',ReleaseAt(8),'    Protocole: ',ProtocolAt(16));WriteLn('       Attributs: ',HexN(Flags,4),' [',FileAttributes(Flags),']');
 End Else If Magic=GEOS2_ID Then Begin GeosVersion:=2;GeosBase:=GEOS2_HEADER_SIZE;Name:=GeosString(FixedString(4,36,True),True);ClassID:=WordAt(40);Flags:=WordAt(42);
  Info:=GeosString(FixedString(68,100,True),True);Copyright:=GeosString(FixedString(168,24,True),True);DateV:=WordAt(200);TimeV:=WordAt(202);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(56));
  Case ClassID of 1:Name:='Executable (2.x)';2:Name:='Fichier VM (2.x)';3:Name:='Fichier niveau octet';4:Name:='Fichier d''information de repertoire';5:Name:='Lien';Else Name:='???';End;
  WriteLn('Type fichier GEOS: ',Name,' Application: ',TokenAt(62)); WriteLn('         Version: ',ReleaseAt(44),'    Protocole: ',ProtocolAt(52));
  WriteLn('            Cree: ',(DateV shr 5) and 15:2,'/',DateV and 31:2,'/',1980+(DateV shr 9):4,'  ',TimeV shr 11:2,':',(TimeV shr 5) and 63:2,'.',(TimeV and 31)*2:2);
  WriteLn('       Attributs: ',HexN(Flags,4),' [',FileAttributes(Flags),']');
  If BytesNonZero(204,8)Then Begin Password:=GeosString(FixedString(204,8,True),True);WriteLn('     Mot de passe: ',Password);DisplayUnknown('mot_de_passe_hex',204,8);End;
  DisplayUnknown('_x',192,8);DisplayUnknown('_x2',212,44);
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
 HadError:=False;FatalError:=False; ParseCommand; If FileName='' Then Begin Usage; Halt(1); End;
 If HadError Then Halt(1); If not OpenInput(FileName) Then Begin WriteLn('Fichier introuvable.'); Halt(1); End;
 If DoList Then WriteLn('comment %'); WriteLn; WriteLn(#9#9#9'    Contenu de ',DisplayName); WriteLn;
 DisplayGeosFile; Close(F); If HadError Then Halt(1);
End.
