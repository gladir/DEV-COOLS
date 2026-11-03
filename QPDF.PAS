{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @description: Clone de QPDF : optimise la structure interne d'un fichier PDF
                (renumerotation, suppression des objets inutiles, flux d'objets,
                flux xref) et compresse ses flux sans perte (Flate), donc sans
                reduire la resolution des images.
}

Program QPDF(Input,Output);

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
{$ELSE}
 {$M 65520,0,655360}
{$ENDIF}
{$R-}
{$S-}
{$I-}

Const
 ProgVersion='1.0';

 { Tampons extensibles par blocs de 16 Ko (contourne la limite de 64 Ko) }
 ChunkShift=14;
 ChunkSize=16384;
 ChunkMask=16383;
 MaxChunks=8192;

 { Table des objets par pages }
 ObjPageShift=9;
 ObjPageSize=512;
 ObjPageMask=511;
 MaxObjPages=4096;
 MaxObjNum=2097151;

 FlReach=1;   { objet atteignable depuis le trailer }
 FlStream=2;  { objet de type flux }
 FlFree=4;    { objet explicitement libere dans la table xref }

 MaxFilt=8;
 CacheN=4;
 PerStm=100;  { nombre maximal d'objets par flux d'objets }
 InflateLimit=100000000;
 OutBufSize=32768;

 TrailerSkip='/Prev/XRefStm/Size/Encrypt/Length/Filter/DecodeParms/DP/W/Index/Type/';

Type
 PChunk=^TChunk;
 TChunk=Array[0..ChunkSize-1]of Byte;
 PChunkDir=^TChunkDir;
 TChunkDir=Array[0..MaxChunks-1]of PChunk;
 TBuf=Record
  Dir:PChunkDir;
  Len:Longint;
  NChunks:Longint;
 End;
 PBuf=^TBuf;
 PBytes=^TBytes;
 TBytes=Array[0..32767]of Byte;

 TObjRec=Record
  Kind:Byte;      { 0=inconnu/libre, 1=dans le fichier, 2=dans un flux d'objets }
  Flags:Byte;
  Gen:Word;
  Off:Longint;    { decalage dans le fichier ou numero du flux d'objets }
  Idx:Longint;    { index dans le flux d'objets }
  RefStart:Longint;
  RefCnt:Longint;
  NewNum:Longint;
 End;
 PObjRec=^TObjRec;
 TObjPage=Array[0..ObjPageSize-1]of TObjRec;
 PObjPage=^TObjPage;
 TObjDir=Array[0..MaxObjPages-1]of PObjPage;
 PObjDir=^TObjDir;

 TStmCache=Record
  Num:Longint;
  Data:TBuf;
  Hdr:TBuf;
  Count:Longint;
  First:Longint;
 End;

Var
 { Divers }
 Warnings:Longint;
 Verbose:Boolean;

 { Sortie }
 OutOpen:Boolean;
 OutF:File;
 OutName:String;
 OBytes:PBytes;
 OutFill:Longint;
 OutPos:Longint;

 { Source }
 SF:File;
 SFSize:Longint;
 SCache:PBytes;
 SCacheStart:Longint;
 SCacheLen:Longint;
 SBuf:PBuf;          { NIL = lecture dans le fichier source }
 Bias:Longint;       { decalage de l'en-tete %PDF- }
 VerMajor,VerMinor:Integer;

 { Objets }
 ObjDir:PObjDir;
 NullRec:TObjRec;
 HighObj:Longint;
 Refs:TBuf;
 TrailerPos:Longint;
 SynthRoot:Longint;
 SrcXrefStm:Boolean;
 Reconstructed:Boolean;
 OverrideFree:Boolean;
 SC:Array[0..CacheN-1]of TStmCache;
 SCNext:Integer;

 { Parcours }
 WMode:Integer;      { 0=sauter, 1=collecter les references, 2=emettre }
 EmBuf:PBuf;
 TopSkip:String;
 ExtraKind:Integer;

 { Filtres du flux courant }
 NF:Integer;
 FOk:Boolean;
 FName:Array[1..MaxFilt]of String[40];
 FParm:Array[1..MaxFilt]of Longint;
 FPred,FColors,FBpc,FCols,FEarly:Array[1..MaxFilt]of Longint;

 { Tampons de travail }
 XRaw,XDec,RawX,DecA,DecB,PredTmp:TBuf;

Procedure ErrLn(Const S:String);Begin
 {$IFDEF FPC}WriteLn(StdErr,S);{$ELSE}WriteLn(S);{$ENDIF}
End;

Procedure CloseOutput;Begin
 If OutOpen Then Begin
  Close(OutF);If IOResult<>0 Then;
  Erase(OutF);If IOResult<>0 Then;
  OutOpen:=False;
 End;
End;

Procedure Fatal(Const S:String);Begin
 ErrLn('QPDF : erreur : '+S);
 CloseOutput;
 Halt(2);
End;

Procedure Warn(Const S:String);Begin
 Inc(Warnings);
 ErrLn('QPDF : avertissement : '+S);
End;

Function IStr(N:Longint):String;
Var S:String;
Begin
 Str(N,S);IStr:=S;
End;

Function PadZero(N:Longint;W:Integer):String;
Var S:String;
Begin
 S:=IStr(N);
 While Length(S)<W Do S:='0'+S;
 PadZero:=S;
End;

{ ------------------------------------------------------------------ }
{ Tampons extensibles                                                 }
{ ------------------------------------------------------------------ }

Procedure BufInit(Var B:TBuf);Begin
 B.Dir:=NIL;B.Len:=0;B.NChunks:=0;
End;

Procedure BufFree(Var B:TBuf);
Var I:Longint;
Begin
 If B.Dir<>NIL Then Begin
  For I:=0 to B.NChunks-1 do FreeMem(B.Dir^[I],SizeOf(TChunk));
  FreeMem(B.Dir,SizeOf(TChunkDir));
 End;
 B.Dir:=NIL;B.Len:=0;B.NChunks:=0;
End;

Procedure BufClear(Var B:TBuf);Begin
 B.Len:=0;
End;

Procedure BufEnsure(Var B:TBuf;N:Longint);
Var Need:Longint;P:PChunk;
Begin
 If N<=0 Then Exit;
 Need:=(N+ChunkMask)shr ChunkShift;
 If Need<=B.NChunks Then Exit;
 If Need>MaxChunks Then Fatal('Flux de donnees trop volumineux.');
 If B.Dir=NIL Then Begin
  GetMem(B.Dir,SizeOf(TChunkDir));
  FillChar(B.Dir^,SizeOf(TChunkDir),0);
 End;
 While B.NChunks<Need Do Begin
  {$IFNDEF FPC}
  If MaxAvail<Longint(SizeOf(TChunk))+2048 Then Fatal('Memoire insuffisante.');
  {$ENDIF}
  GetMem(P,SizeOf(TChunk));
  B.Dir^[B.NChunks]:=P;
  Inc(B.NChunks);
 End;
End;

Procedure BufPut(Var B:TBuf;V:Byte);
Var C:Longint;
Begin
 C:=B.Len shr ChunkShift;
 If C>=B.NChunks Then BufEnsure(B,B.Len+1);
 B.Dir^[C]^[B.Len and ChunkMask]:=V;
 Inc(B.Len);
End;

Function BufGet(Var B:TBuf;I:Longint):Byte;Begin
 BufGet:=B.Dir^[I shr ChunkShift]^[I and ChunkMask];
End;

Procedure BufSet(Var B:TBuf;I:Longint;V:Byte);Begin
 B.Dir^[I shr ChunkShift]^[I and ChunkMask]:=V;
End;

Procedure BufPutStr(Var B:TBuf;Const S:String);
Var I:Integer;
Begin
 For I:=1 to Length(S)do BufPut(B,Ord(S[I]));
End;

Procedure BufPutL(Var B:TBuf;V:Longint);Begin
 BufPut(B,V and 255);
 BufPut(B,(V shr 8)and 255);
 BufPut(B,(V shr 16)and 255);
 BufPut(B,(V shr 24)and 255);
End;

Function BufGetL(Var B:TBuf;I:Longint):Longint;Begin
 BufGetL:=Longint(BufGet(B,I))or(Longint(BufGet(B,I+1))shl 8)or
          (Longint(BufGet(B,I+2))shl 16)or(Longint(BufGet(B,I+3))shl 24);
End;

Procedure BufAppend(Var D:TBuf;Var S:TBuf;From,Cnt:Longint);
Var I:Longint;
Begin
 If Cnt<=0 Then Exit;
 BufEnsure(D,D.Len+Cnt);
 For I:=From to From+Cnt-1 do BufPut(D,BufGet(S,I));
End;

Procedure BufReadFile(Var F:File;Cnt:Longint;Var B:TBuf);
Var N,C,Off:Longint;Got:Word;
Begin
 If Cnt<=0 Then Exit;
 BufEnsure(B,B.Len+Cnt);
 While Cnt>0 Do Begin
  C:=B.Len shr ChunkShift;
  Off:=B.Len and ChunkMask;
  N:=ChunkSize-Off;
  If N>Cnt Then N:=Cnt;
  BlockRead(F,B.Dir^[C]^[Off],Word(N),Got);
  If IOResult<>0 Then Got:=0;
  If Got=0 Then Cnt:=0
   Else
  Begin
   Inc(B.Len,Got);
   Dec(Cnt,Got);
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Ecriture du fichier de sortie                                       }
{ ------------------------------------------------------------------ }

Procedure OutFlush;
Var Got:Word;
Begin
 If OutFill>0 Then Begin
  BlockWrite(OutF,OBytes^,Word(OutFill),Got);
  If(IOResult<>0)or(Got<>OutFill)Then Fatal('Erreur d''ecriture sur le fichier de sortie.');
  OutFill:=0;
 End;
End;

Procedure OutBytes(Var Data;N:Longint);
Var P:PBytes;K,Done:Longint;
Begin
 P:=@Data;Done:=0;
 While Done<N Do Begin
  K:=OutBufSize-OutFill;
  If K>N-Done Then K:=N-Done;
  Move(P^[Done],OBytes^[OutFill],Word(K));
  Inc(OutFill,K);
  Inc(Done,K);
  If OutFill>=OutBufSize Then OutFlush;
 End;
 Inc(OutPos,N);
End;

Procedure OutStr(S:String);Begin
 If Length(S)>0 Then OutBytes(S[1],Length(S));
End;

Procedure OutBuffer(Var B:TBuf;From,Cnt:Longint);
Var C,Off,K:Longint;
Begin
 While Cnt>0 Do Begin
  C:=From shr ChunkShift;
  Off:=From and ChunkMask;
  K:=ChunkSize-Off;
  If K>Cnt Then K:=Cnt;
  OutBytes(B.Dir^[C]^[Off],K);
  Inc(From,K);
  Dec(Cnt,K);
 End;
End;

{ ------------------------------------------------------------------ }
{ Table des objets                                                    }
{ ------------------------------------------------------------------ }

Function GetRec(N:Longint):PObjRec;
Var Pg:Longint;
Begin
 If(N<0)or(N>MaxObjNum)Then Fatal('Numero d''objet invalide : '+IStr(N));
 Pg:=N shr ObjPageShift;
 If ObjDir^[Pg]=NIL Then Begin
  GetMem(ObjDir^[Pg],SizeOf(TObjPage));
  FillChar(ObjDir^[Pg]^,SizeOf(TObjPage),0);
 End;
 GetRec:=@ObjDir^[Pg]^[N and ObjPageMask];
 If N>HighObj Then HighObj:=N;
End;

Function PeekRec(N:Longint):PObjRec;
Var Pg:Longint;
Begin
 PeekRec:=@NullRec;
 If(N<0)or(N>MaxObjNum)Then Exit;
 Pg:=N shr ObjPageShift;
 If ObjDir^[Pg]<>NIL Then PeekRec:=@ObjDir^[Pg]^[N and ObjPageMask];
End;

Procedure ResetObjects;
Var I:Longint;
Begin
 For I:=0 to MaxObjPages-1 do If ObjDir^[I]<>NIL Then Begin
  FreeMem(ObjDir^[I],SizeOf(TObjPage));
  ObjDir^[I]:=NIL;
 End;
 HighObj:=0;
 TrailerPos:=-1;
 SynthRoot:=0;
 For I:=0 to CacheN-1 do SC[I].Num:=-1;
End;

{ ------------------------------------------------------------------ }
{ Lecture de la source                                                }
{ ------------------------------------------------------------------ }

Procedure LoadCache(P:Longint);
Var Got:Word;St:Longint;
Begin
 St:=(P shr 13)shl 13;
 Seek(SF,St);
 BlockRead(SF,SCache^,8192,Got);
 If IOResult<>0 Then Got:=0;
 SCacheStart:=St;
 SCacheLen:=Got;
End;

Function SB(P:Longint):Integer;Begin
 If SBuf<>NIL Then Begin
  If(P<0)or(P>=SBuf^.Len)Then SB:=-1 Else SB:=BufGet(SBuf^,P);
 End
  Else
 Begin
  If(P<0)or(P>=SFSize)Then Begin SB:=-1;Exit;End;
  If(P<SCacheStart)or(P>=SCacheStart+SCacheLen)Then LoadCache(P);
  If P-SCacheStart>=SCacheLen Then SB:=-1 Else SB:=SCache^[P-SCacheStart];
 End;
End;

Function IsWS(C:Integer):Boolean;Begin
 IsWS:=(C=32)or(C=10)or(C=13)or(C=9)or(C=0)or(C=12);
End;

Function IsDelim(C:Integer):Boolean;Begin
 IsDelim:=(C=40)or(C=41)or(C=60)or(C=62)or(C=91)or(C=93)or(C=123)or(C=125)or(C=47)or(C=37);
End;

Function IsReg(C:Integer):Boolean;Begin
 IsReg:=(C>=0)and Not IsWS(C)and Not IsDelim(C);
End;

Procedure SkipWS(Var P:Longint);
Var C:Integer;Done:Boolean;
Begin
 Done:=False;
 Repeat
  C:=SB(P);
  If IsWS(C)Then Inc(P)
   Else
  If C=37 Then Begin
   Repeat
    Inc(P);C:=SB(P);
   Until(C=-1)or(C=10)or(C=13);
  End
   Else
  Done:=True;
 Until Done;
End;

Function ReadInt(Var P:Longint;Var V:Longint):Boolean;
Var Q:Longint;C:Integer;Neg,Any:Boolean;
Begin
 Q:=P;SkipWS(Q);Neg:=False;V:=0;Any:=False;
 C:=SB(Q);
 If(C=43)or(C=45)Then Begin
  Neg:=(C=45);Inc(Q);C:=SB(Q);
 End;
 While(C>=48)and(C<=57)Do Begin
  If V>214748363 Then V:=2147483647 Else V:=V*10+(C-48);
  Any:=True;Inc(Q);C:=SB(Q);
 End;
 If Any Then Begin
  If Neg Then V:=-V;
  P:=Q;
 End;
 ReadInt:=Any;
End;

Function MatchStr(P:Longint;Const K:String):Boolean;
Var I:Integer;
Begin
 MatchStr:=False;
 For I:=1 to Length(K)do If SB(P+I-1)<>Ord(K[I])Then Exit;
 MatchStr:=True;
End;

Function MatchKW(P:Longint;Const K:String):Boolean;Begin
 MatchKW:=False;
 If Not MatchStr(P,K)Then Exit;
 MatchKW:=Not IsReg(SB(P+Length(K)));
End;

Function ReadNameStr(Var P:Longint):String;
Var S:String;C:Integer;
Begin
 S:='';Inc(P);
 C:=SB(P);
 While IsReg(C)Do Begin
  If Length(S)<200 Then S:=S+Chr(C);
  Inc(P);C:=SB(P);
 End;
 ReadNameStr:=S;
End;

{ Reference "n g R" a la position P ? }
Function IsRefAt(P:Longint;Var N1:Longint;Var After:Longint):Boolean;
Var Q,G:Longint;C:Integer;
Begin
 IsRefAt:=False;
 Q:=P;
 If Not ReadInt(Q,N1)Then Exit;
 If IsReg(SB(Q))Then Exit;
 SkipWS(Q);
 C:=SB(Q);
 If Not((C>=48)and(C<=57))Then Exit;
 If Not ReadInt(Q,G)Then Exit;
 If IsReg(SB(Q))Then Exit;
 SkipWS(Q);
 If SB(Q)<>82 Then Exit;
 If IsReg(SB(Q+1))Then Exit;
 After:=Q+1;
 IsRefAt:=True;
End;

{ ------------------------------------------------------------------ }
{ Parcours d'une valeur PDF (sauter / collecter / emettre)            }
{ ------------------------------------------------------------------ }

Procedure EmitExtra;Forward;

Procedure PutC(C:Byte);Begin
 If WMode=2 Then BufPut(EmBuf^,C);
End;

Procedure PutS(Const S:String);
Var I:Integer;
Begin
 If WMode=2 Then For I:=1 to Length(S)do BufPut(EmBuf^,Ord(S[I]));
End;

Function MapRef(N:Longint):Longint;
Var R:PObjRec;
Begin
 MapRef:=0;
 R:=PeekRec(N);
 If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)Then MapRef:=R^.NewNum;
End;

Procedure AddRef(N:Longint);
Var R:PObjRec;
Begin
 If(N>0)and(N<=MaxObjNum)Then Begin
  R:=PeekRec(N);
  If R^.Kind<>0 Then BufPutL(Refs,N)
   Else
  If(R^.Flags and FlFree)=0 Then BufPutL(Refs,-N);
 End;
End;

Function HexDigit(C:Integer):Boolean;Begin
 HexDigit:=((C>=48)and(C<=57))or((C>=65)and(C<=70))or((C>=97)and(C<=102));
End;

Function ValidNumber(P,Q:Longint):Boolean;
Var C:Integer;Dot,Dig:Boolean;I:Longint;
Begin
 Dot:=False;Dig:=False;ValidNumber:=False;
 For I:=P to Q-1 do Begin
  C:=SB(I);
  If(C>=48)and(C<=57)Then Dig:=True
   Else
  If(C=46)and Not Dot Then Dot:=True
   Else
  If((C=43)or(C=45))and(I=P)Then
   Else
  Exit;
 End;
 ValidNumber:=Dig;
End;

Function ValidKeyword(P,Q:Longint):Boolean;Begin
 ValidKeyword:=((Q-P=4)and(MatchStr(P,'true')or MatchStr(P,'null')))or((Q-P=5)and MatchStr(P,'false'));
End;

Procedure WalkValue(Var P:Longint;Depth:Integer);
Var C,D:Integer;Q,Q2,N1:Longint;Key:String;Done,DigitsOnly:Boolean;SaveMode:Integer;Lv,M:Longint;
Begin
 SkipWS(P);
 C:=SB(P);
 If C=-1 Then Begin PutS('null');Exit;End;
 If Depth>60 Then Begin Inc(P);Exit;End;
 Case C of
  47:Begin
   PutC(47);Inc(P);D:=SB(P);
   While IsReg(D)Do Begin
    PutC(Byte(D));Inc(P);D:=SB(P);
   End;
  End;
  40:Begin
   Lv:=0;Done:=False;
   Repeat
    D:=SB(P);
    If D=-1 Then Done:=True
     Else
    Begin
     PutC(Byte(D));Inc(P);
     If D=92 Then Begin
      D:=SB(P);
      If D<>-1 Then Begin PutC(Byte(D));Inc(P);End;
     End
      Else
     If D=40 Then Inc(Lv)
      Else
     If D=41 Then Begin
      Dec(Lv);
      If Lv=0 Then Done:=True;
     End;
    End;
   Until Done;
   While Lv>0 Do Begin PutC(41);Dec(Lv);End;
  End;
  60:If SB(P+1)=60 Then Begin
   Inc(P,2);
   PutS('<<');
   Done:=False;
   Repeat
    SkipWS(P);
    D:=SB(P);
    If(D=-1)or((D=62)and(SB(P+1)=62))Then Done:=True
     Else
    If D<>47 Then Begin
     SaveMode:=WMode;WMode:=0;
     WalkValue(P,Depth+1);
     WMode:=SaveMode;
    End
     Else
    Begin
     Key:=ReadNameStr(P);
     SkipWS(P);
     If(Depth=0)and(TopSkip<>'')and(Pos('/'+Key+'/',TopSkip)>0)Then Begin
      SaveMode:=WMode;WMode:=0;
      WalkValue(P,Depth+1);
      WMode:=SaveMode;
     End
      Else
     Begin
      PutC(32);PutC(47);PutS(Key);PutC(32);
      If(SB(P)=62)and(SB(P+1)=62)Then PutS('null')
                                 Else WalkValue(P,Depth+1);
     End;
    End;
   Until Done;
   If(SB(P)=62)and(SB(P+1)=62)Then Inc(P,2);
   If(Depth=0)and(ExtraKind<>0)Then EmitExtra;
   PutS(' >>');
  End
   Else
  Begin
   PutC(60);Inc(P);Done:=False;
   Repeat
    D:=SB(P);
    If D=-1 Then Done:=True
     Else
    Begin
     Inc(P);
     If D=62 Then Begin PutC(62);Done:=True;End
      Else
     If HexDigit(D)Then PutC(Byte(D));
    End;
   Until Done;
   If D=-1 Then PutC(62);
  End;
  91:Begin
   Inc(P);PutC(91);Done:=False;
   Repeat
    SkipWS(P);D:=SB(P);
    If D=-1 Then Done:=True
     Else
    If D=93 Then Begin Inc(P);Done:=True;End
     Else
    Begin
     PutC(32);
     WalkValue(P,Depth+1);
    End;
   Until Done;
   PutS(' ]');
  End;
  41,93,62,123,125:Inc(P);
  Else Begin
   Q:=P;D:=SB(Q);DigitsOnly:=True;
   While IsReg(D)Do Begin
    If Not((D>=48)and(D<=57))Then DigitsOnly:=False;
    Inc(Q);D:=SB(Q);
   End;
   If Q=P Then Begin Inc(P);Exit;End;
   If DigitsOnly and(Q-P<=10)and IsRefAt(P,N1,Q2)Then Begin
    P:=Q2;
    If WMode=1 Then AddRef(N1)
     Else
    If WMode=2 Then Begin
     M:=MapRef(N1);
     If M>0 Then PutS(IStr(M)+' 0 R')
            Else PutS('null');
    End;
   End
    Else
   Begin
    If WMode=2 Then Begin
     If ValidNumber(P,Q)or ValidKeyword(P,Q)Then Begin
      While P<Q Do Begin
       PutC(Byte(SB(P)));Inc(P);
      End;
     End
      Else
     Begin
      PutS('null');
      P:=Q;
     End;
    End
     Else
    P:=Q;
   End;
  End;
 End;
End;

Procedure SkipValueAt(Var P:Longint);
Var Save:Integer;
Begin
 Save:=WMode;WMode:=0;
 WalkValue(P,1);
 WMode:=Save;
End;

{ P pointe sur '<<' : retourne la position de la valeur de la cle ou -1 }
Function DictFind(P:Longint;Const Key:String):Longint;
Var D:Integer;K:String;Done:Boolean;
Begin
 DictFind:=-1;
 SkipWS(P);
 If(SB(P)<>60)or(SB(P+1)<>60)Then Exit;
 Inc(P,2);Done:=False;
 Repeat
  SkipWS(P);D:=SB(P);
  If(D=-1)or((D=62)and(SB(P+1)=62))Then Done:=True
   Else
  If D<>47 Then SkipValueAt(P)
   Else
  Begin
   K:=ReadNameStr(P);
   SkipWS(P);
   If K=Key Then Begin
    DictFind:=P;
    Exit;
   End;
   If(SB(P)=62)and(SB(P+1)=62)Then Done:=True
                              Else SkipValueAt(P);
  End;
 Until Done;
End;

Function ReadDirectInt(P:Longint;Var V:Longint):Boolean;
Var N1,A:Longint;
Begin
 ReadDirectInt:=False;
 If P<0 Then Exit;
 If IsRefAt(P,N1,A)Then Exit;
 If Not ReadInt(P,V)Then Exit;
 ReadDirectInt:=True;
End;

{ Nom d'un type : retourne le nom (sans /) de la valeur a la position P }
Function ReadNameAt(P:Longint):String;Begin
 ReadNameAt:='';
 If P<0 Then Exit;
 SkipWS(P);
 If SB(P)=47 Then ReadNameAt:=ReadNameStr(P);
End;

{ ------------------------------------------------------------------ }
{ Tables communes Deflate / Inflate                                   }
{ ------------------------------------------------------------------ }

Const
 LBase:Array[0..28]of Word=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258);
 LExt:Array[0..28]of Byte=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase:Array[0..29]of Word=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577);
 DExt:Array[0..29]of Byte=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 CLOrder:Array[0..18]of Byte=(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);
 BitMask:Array[0..16]of Longint=(0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535);

{ ------------------------------------------------------------------ }
{ Inflate (zlib / deflate)                                            }
{ ------------------------------------------------------------------ }

Type
 THuff=Record
  Count:Array[0..15]of Word;
  Symbol:Array[0..287]of Word;
 End;
 TLen320=Array[0..319]of Byte;

Var
 IIn,IOut:PBuf;
 IPos,IEnd,IBits,IBase:Longint;
 ICnt:Integer;
 IErr:Boolean;
 LitH,DistH:THuff;

Function IGetBits(N:Integer):Longint;Begin
 While ICnt<N Do Begin
  If IPos>=IEnd Then Begin
   IErr:=True;IGetBits:=0;Exit;
  End;
  IBits:=IBits or(Longint(BufGet(IIn^,IPos))shl ICnt);
  Inc(IPos);Inc(ICnt,8);
 End;
 IGetBits:=IBits and BitMask[N];
 IBits:=IBits shr N;
 Dec(ICnt,N);
End;

Function HBuild(Var H:THuff;Var Lens:TLen320;Off,N:Integer):Longint;
Var Left:Longint;L,S:Integer;Offs:Array[0..15]of Integer;
Begin
 For L:=0 to 15 do H.Count[L]:=0;
 For S:=0 to N-1 do Inc(H.Count[Lens[Off+S]]);
 HBuild:=0;
 If H.Count[0]=N Then Exit;
 Left:=1;
 For L:=1 to 15 do Begin
  Left:=Left shl 1;
  Left:=Left-H.Count[L];
  If Left<0 Then Begin HBuild:=Left;Exit;End;
 End;
 Offs[1]:=0;
 For L:=1 to 14 do Offs[L+1]:=Offs[L]+H.Count[L];
 For S:=0 to N-1 do If Lens[Off+S]<>0 Then Begin
  H.Symbol[Offs[Lens[Off+S]]]:=S;
  Inc(Offs[Lens[Off+S]]);
 End;
 HBuild:=Left;
End;

Function DecodeSym(Var H:THuff):Integer;
Var Code,First,Index,Cnt:Longint;L:Integer;
Begin
 While(ICnt<15)and(IPos<IEnd)Do Begin
  IBits:=IBits or(Longint(BufGet(IIn^,IPos))shl ICnt);
  Inc(IPos);Inc(ICnt,8);
 End;
 Code:=0;First:=0;Index:=0;
 For L:=1 to 15 do Begin
  If ICnt=0 Then Begin IErr:=True;DecodeSym:=-1;Exit;End;
  Code:=Code or(IBits and 1);
  IBits:=IBits shr 1;
  Dec(ICnt);
  Cnt:=H.Count[L];
  If Code-Cnt<First Then Begin
   DecodeSym:=H.Symbol[Index+(Code-First)];
   Exit;
  End;
  Index:=Index+Cnt;
  First:=(First+Cnt)shl 1;
  Code:=Code shl 1;
 End;
 IErr:=True;
 DecodeSym:=-1;
End;

Procedure IFixedTables;
Var Lens:TLen320;I:Integer;
Begin
 For I:=0 to 143 do Lens[I]:=8;
 For I:=144 to 255 do Lens[I]:=9;
 For I:=256 to 279 do Lens[I]:=7;
 For I:=280 to 287 do Lens[I]:=8;
 HBuild(LitH,Lens,0,288);
 For I:=0 to 29 do Lens[I]:=5;
 HBuild(DistH,Lens,0,30);
End;

Function IDynTables:Boolean;
Var NLen,NDist,NCode,I,Sym,Rep:Integer;Lens:TLen320;PrevL:Byte;CLH:THuff;Lv:Longint;
Begin
 IDynTables:=False;
 NLen:=IGetBits(5)+257;
 NDist:=IGetBits(5)+1;
 NCode:=IGetBits(4)+4;
 If IErr or(NLen>286)or(NDist>30)Then Exit;
 For I:=0 to 18 do Lens[I]:=0;
 For I:=0 to NCode-1 do Lens[CLOrder[I]]:=IGetBits(3);
 If IErr Then Exit;
 If HBuild(CLH,Lens,0,19)<>0 Then Exit;
 I:=0;PrevL:=0;
 While I<NLen+NDist Do Begin
  Sym:=DecodeSym(CLH);
  If IErr or(Sym<0)Then Exit;
  If Sym<16 Then Begin
   Lens[I]:=Sym;PrevL:=Sym;Inc(I);
  End
   Else
  Begin
   Rep:=0;
   If Sym=16 Then Begin
    If I=0 Then Exit;
    Rep:=3+IGetBits(2);
   End
    Else
   If Sym=17 Then Begin PrevL:=0;Rep:=3+IGetBits(3);End
    Else
   Begin PrevL:=0;Rep:=11+IGetBits(7);End;
   If IErr or(I+Rep>NLen+NDist)Then Exit;
   While Rep>0 Do Begin
    Lens[I]:=PrevL;Inc(I);Dec(Rep);
   End;
  End;
 End;
 If Lens[256]=0 Then Exit;
 Lv:=HBuild(LitH,Lens,0,NLen);
 If Lv<0 Then Exit;
 Lv:=HBuild(DistH,Lens,NLen,NDist);
 If Lv<0 Then Exit;
 IDynTables:=True;
End;

Function InflateBuf(Var Src:TBuf;From:Longint;Var Dst:TBuf;Zlib:Boolean):Boolean;
Var Last:Boolean;T,Sym,DS:Integer;Len,Dist,K,NLn,I:Longint;Done:Boolean;
Begin
 InflateBuf:=False;
 IIn:=@Src;IOut:=@Dst;IPos:=From;IEnd:=Src.Len;IBits:=0;ICnt:=0;IErr:=False;
 IBase:=Dst.Len;
 If Zlib Then Begin
  If IEnd-IPos<2 Then Exit;
  If(BufGet(Src,IPos)and 15)<>8 Then Exit;
  If((Longint(BufGet(Src,IPos))*256+BufGet(Src,IPos+1))mod 31)<>0 Then Exit;
  If(BufGet(Src,IPos+1)and 32)<>0 Then Exit;
  Inc(IPos,2);
 End;
 Repeat
  Last:=IGetBits(1)=1;
  T:=IGetBits(2);
  If IErr Then Exit;
  If T=0 Then Begin
   IPos:=IPos-(ICnt div 8);ICnt:=0;IBits:=0;
   If IPos+4>IEnd Then Exit;
   Len:=BufGet(Src,IPos)or(Longint(BufGet(Src,IPos+1))shl 8);
   NLn:=BufGet(Src,IPos+2)or(Longint(BufGet(Src,IPos+3))shl 8);
   Inc(IPos,4);
   If Len<>((Not NLn)and 65535)Then Exit;
   If IPos+Len>IEnd Then Exit;
   For K:=0 to Len-1 do BufPut(Dst,BufGet(Src,IPos+K));
   Inc(IPos,Len);
  End
   Else
  If(T=1)or(T=2)Then Begin
   If T=1 Then IFixedTables
          Else If Not IDynTables Then Exit;
   Done:=False;
   Repeat
    Sym:=DecodeSym(LitH);
    If IErr or(Sym<0)Then Exit;
    If Sym<256 Then BufPut(Dst,Sym)
     Else
    If Sym=256 Then Done:=True
     Else
    Begin
     Dec(Sym,257);
     If Sym>=29 Then Exit;
     Len:=LBase[Sym]+IGetBits(LExt[Sym]);
     DS:=DecodeSym(DistH);
     If IErr or(DS<0)or(DS>=30)Then Exit;
     Dist:=DBase[DS]+IGetBits(DExt[DS]);
     If IErr Then Exit;
     If Dist>Dst.Len-IBase Then Exit;
     For I:=1 to Len do BufPut(Dst,BufGet(Dst,Dst.Len-Dist));
    End;
    If Dst.Len-IBase>InflateLimit Then Exit;
   Until Done;
  End
   Else
  Exit;
 Until Last;
 InflateBuf:=True;
End;

{ ------------------------------------------------------------------ }
{ Deflate (LZ77 + Huffman dynamique, format zlib)                     }
{ ------------------------------------------------------------------ }

Const
 MaxDist=32767;
 WMaskD=32767;
 HashSize=8192;
 HashMask=8191;
 LitBufSize=16384;

Type
 THead=Array[0..HashSize-1]of Longint;
 PHead=^THead;
 TPrev16=Array[0..16383]of Word;
 PPrev16=^TPrev16;
 TSymD=Array[0..LitBufSize-1]of Word;
 PSymD=^TSymD;
 TSymL=Array[0..LitBufSize-1]of Byte;
 PSymL=^TSymL;
 TFreq=Array[0..287]of Longint;
 TLens=Array[0..287]of Byte;
 TCodes=Array[0..287]of Word;

Var
 DInit:Boolean;
 DForceStore:Boolean;
 DHead:PHead;
 DPrevA,DPrevB:PPrev16;
 DSymD:PSymD;
 DSymL:PSymL;
 DSrc,DDst:PBuf;
 DN:Longint;
 DBB:Longint;
 DBC:Integer;
 DSym,DCover,DBlkStart,DExtra:Longint;
 DLitF,DDistF:TFreq;
 LCodeTab:Array[0..255]of Byte;
 DTab1,DTab2:Array[0..255]of Byte;
 FixLens,FixDLens:TLens;
 FixCodes,FixDCodes:TCodes;
 CfgGood,CfgLazy,CfgNice,CfgChain:Longint;

Function RevBits(Code:Longint;Len:Integer):Longint;
Var R:Longint;I:Integer;
Begin
 R:=0;
 For I:=1 to Len do Begin
  R:=(R shl 1)or(Code and 1);
  Code:=Code shr 1;
 End;
 RevBits:=R;
End;

Procedure HuffLens(Var Freq:TFreq;N,Limit:Integer;Var Lens:TLens);
Var
 W:Array[0..575]of Longint;
 Par,Dep:Array[0..575]of Integer;
 Sym:Array[0..287]of Integer;
 F:TFreq;
 M,I,J,Q1,Q2,NN,A,B,MaxD,Tmp:Integer;
Begin
 For I:=0 to N-1 do Begin Lens[I]:=0;F[I]:=Freq[I];End;
 M:=0;
 For I:=0 to N-1 do If F[I]>0 Then Begin Sym[M]:=I;Inc(M);End;
 If M=0 Then Exit;
 If M=1 Then Begin Lens[Sym[0]]:=1;Exit;End;
 For I:=1 to M-1 do Begin
  Tmp:=Sym[I];J:=I-1;
  While(J>=0)and(F[Sym[J]]>F[Tmp])Do Begin
   Sym[J+1]:=Sym[J];Dec(J);
  End;
  Sym[J+1]:=Tmp;
 End;
 Repeat
  For I:=0 to M-1 do W[I]:=F[Sym[I]];
  Q1:=0;Q2:=M;NN:=M;
  For I:=1 to M-1 do Begin
   If(Q1<M)and((Q2>=NN)or(W[Q1]<=W[Q2]))Then Begin A:=Q1;Inc(Q1);End
                                         Else Begin A:=Q2;Inc(Q2);End;
   If(Q1<M)and((Q2>=NN)or(W[Q1]<=W[Q2]))Then Begin B:=Q1;Inc(Q1);End
                                         Else Begin B:=Q2;Inc(Q2);End;
   W[NN]:=W[A]+W[B];
   Par[A]:=NN;Par[B]:=NN;
   Inc(NN);
  End;
  Dep[NN-1]:=0;
  For I:=NN-2 downto 0 do Dep[I]:=Dep[Par[I]]+1;
  MaxD:=0;
  For I:=0 to M-1 do If Dep[I]>MaxD Then MaxD:=Dep[I];
  If MaxD>Limit Then For I:=0 to M-1 do F[Sym[I]]:=(F[Sym[I]]+1)shr 1;
 Until MaxD<=Limit;
 For I:=0 to M-1 do Lens[Sym[I]]:=Dep[I];
End;

Procedure MakeCodes(Var Lens:TLens;N:Integer;Var Codes:TCodes);
Var BlCount,NextC:Array[0..15]of Longint;I,B:Integer;Code:Longint;
Begin
 For I:=0 to 15 do BlCount[I]:=0;
 For I:=0 to N-1 do Inc(BlCount[Lens[I]]);
 BlCount[0]:=0;
 Code:=0;
 For B:=1 to 15 do Begin
  Code:=(Code+BlCount[B-1])shl 1;
  NextC[B]:=Code;
 End;
 For I:=0 to N-1 do If Lens[I]<>0 Then Begin
  Codes[I]:=RevBits(NextC[Lens[I]],Lens[I]);
  Inc(NextC[Lens[I]]);
 End;
End;

Procedure Ensure2(Var Freq:TFreq;N:Integer);
Var I,C:Integer;
Begin
 C:=0;
 For I:=0 to N-1 do If Freq[I]>0 Then Inc(C);
 If C<2 Then Begin
  If Freq[0]=0 Then Begin Freq[0]:=1;Inc(C);End;
  If(C<2)and(Freq[1]=0)Then Freq[1]:=1;
 End;
End;

Function PrevGet(I:Longint):Longint;Begin
 If I<16384 Then PrevGet:=DPrevA^[I] Else PrevGet:=DPrevB^[I-16384];
End;

Procedure PrevSet(I,V:Longint);Begin
 If I<16384 Then DPrevA^[I]:=V Else DPrevB^[I-16384]:=V;
End;

Procedure DefInit;
Var C,L,D:Longint;
Begin
 If DInit Then Exit;
 DInit:=True;
 GetMem(DHead,SizeOf(THead));
 GetMem(DPrevA,SizeOf(TPrev16));
 GetMem(DPrevB,SizeOf(TPrev16));
 GetMem(DSymD,SizeOf(TSymD));
 GetMem(DSymL,SizeOf(TSymL));
 For C:=0 to 28 do
  For L:=LBase[C] to LBase[C]+(Longint(1)shl LExt[C])-1 do
   If(L>=3)and(L<=258)Then LCodeTab[L-3]:=C;
 For C:=0 to 29 do
  For D:=DBase[C] to DBase[C]+(Longint(1)shl DExt[C])-1 do
   If D<=256 Then DTab1[D-1]:=C
             Else DTab2[(D-1)shr 7]:=C;
 For C:=0 to 143 do FixLens[C]:=8;
 For C:=144 to 255 do FixLens[C]:=9;
 For C:=256 to 279 do FixLens[C]:=7;
 For C:=280 to 287 do FixLens[C]:=8;
 MakeCodes(FixLens,288,FixCodes);
 For C:=0 to 29 do Begin
  FixDLens[C]:=5;
  FixDCodes[C]:=RevBits(C,5);
 End;
End;

Function DistCode(D:Longint):Integer;Begin
 If D<=256 Then DistCode:=DTab1[D-1]
           Else DistCode:=DTab2[(D-1)shr 7];
End;

Procedure PutBits(V:Longint;N:Integer);Begin
 DBB:=DBB or(V shl DBC);
 Inc(DBC,N);
 While DBC>=8 Do Begin
  BufPut(DDst^,DBB and 255);
  DBB:=DBB shr 8;
  Dec(DBC,8);
 End;
End;

Procedure AlignByte;Begin
 If DBC>0 Then PutBits(0,8-DBC);
End;

Procedure SendSyms(Var Ll:TLens;Var Lc:TCodes;Var Dl:TLens;Var Dc:TCodes);
Var I,D,LC2,DC2:Longint;Lt:Integer;
Begin
 For I:=0 to DSym-1 do Begin
  D:=DSymD^[I];
  Lt:=DSymL^[I];
  If D=0 Then PutBits(Lc[Lt],Ll[Lt])
   Else
  Begin
   LC2:=LCodeTab[Lt];
   PutBits(Lc[257+LC2],Ll[257+LC2]);
   If LExt[LC2]>0 Then PutBits(Lt+3-LBase[LC2],LExt[LC2]);
   DC2:=DistCode(D);
   PutBits(Dc[DC2],Dl[DC2]);
   If DExt[DC2]>0 Then PutBits(D-DBase[DC2],DExt[DC2]);
  End;
 End;
 PutBits(Lc[256],Ll[256]);
End;

Procedure FlushBlock(Final:Boolean);
Var
 LL,DL,CLL:TLens;
 LC,DC,CLC:TCodes;
 CLF:TFreq;
 Seq:Array[0..319]of Byte;
 CLSym,CLExt:Array[0..319]of Byte;
 NLit,NDist,NCL,Total,I,Run,R,NSym:Integer;
 DynBits,FixBits,StoBits,Len,Pieces,Ps,Left,Piece,NP,KK:Longint;
 V:Byte;
Begin
 DLitF[256]:=1;
 Ensure2(DLitF,286);
 Ensure2(DDistF,30);
 HuffLens(DLitF,286,15,LL);
 HuffLens(DDistF,30,15,DL);
 NLit:=286;
 While(NLit>257)and(LL[NLit-1]=0)Do Dec(NLit);
 NDist:=30;
 While(NDist>1)and(DL[NDist-1]=0)Do Dec(NDist);
 Total:=NLit+NDist;
 For I:=0 to NLit-1 do Seq[I]:=LL[I];
 For I:=0 to NDist-1 do Seq[NLit+I]:=DL[I];
 NSym:=0;I:=0;
 While I<Total Do Begin
  V:=Seq[I];Run:=1;
  While(I+Run<Total)and(Seq[I+Run]=V)Do Inc(Run);
  I:=I+Run;
  If V=0 Then Begin
   While Run>0 Do Begin
    If Run>=11 Then Begin
     R:=Run;If R>138 Then R:=138;
     CLSym[NSym]:=18;CLExt[NSym]:=R-11;Inc(NSym);Dec(Run,R);
    End
     Else
    If Run>=3 Then Begin
     CLSym[NSym]:=17;CLExt[NSym]:=Run-3;Inc(NSym);Run:=0;
    End
     Else
    Begin
     CLSym[NSym]:=0;CLExt[NSym]:=0;Inc(NSym);Dec(Run);
    End;
   End;
  End
   Else
  Begin
   CLSym[NSym]:=V;CLExt[NSym]:=0;Inc(NSym);Dec(Run);
   While Run>=3 Do Begin
    R:=Run;If R>6 Then R:=6;
    CLSym[NSym]:=16;CLExt[NSym]:=R-3;Inc(NSym);Dec(Run,R);
   End;
   While Run>0 Do Begin
    CLSym[NSym]:=V;CLExt[NSym]:=0;Inc(NSym);Dec(Run);
   End;
  End;
 End;
 For I:=0 to 18 do CLF[I]:=0;
 For I:=0 to NSym-1 do Inc(CLF[CLSym[I]]);
 HuffLens(CLF,19,7,CLL);
 MakeCodes(CLL,19,CLC);
 NCL:=19;
 While(NCL>4)and(CLL[CLOrder[NCL-1]]=0)Do Dec(NCL);
 { Estimation des couts }
 DynBits:=3+14+3*NCL;
 For I:=0 to NSym-1 do Begin
  DynBits:=DynBits+CLL[CLSym[I]];
  Case CLSym[I]of
   16:Inc(DynBits,2);
   17:Inc(DynBits,3);
   18:Inc(DynBits,7);
  End;
 End;
 FixBits:=3+DExtra;
 DynBits:=DynBits+DExtra;
 For I:=0 to 285 do Begin
  DynBits:=DynBits+DLitF[I]*LL[I];
  FixBits:=FixBits+DLitF[I]*FixLens[I];
 End;
 For I:=0 to 29 do Begin
  DynBits:=DynBits+DDistF[I]*DL[I];
  FixBits:=FixBits+DDistF[I]*5;
 End;
 Len:=DCover-DBlkStart;
 Pieces:=(Len+65534)div 65535;
 If Pieces<1 Then Pieces:=1;
 StoBits:=Pieces*(3+7+32)+Len*8;
 If DForceStore or((StoBits<=FixBits)and(StoBits<=DynBits))Then Begin
  Ps:=DBlkStart;Left:=Len;
  Repeat
   Piece:=Left;
   If Piece>65535 Then Piece:=65535;
   Left:=Left-Piece;
   PutBits(Ord(Final and(Left=0)),1);
   PutBits(0,2);
   AlignByte;
   PutBits(Piece and 255,8);
   PutBits((Piece shr 8)and 255,8);
   NP:=(Not Piece)and 65535;
   PutBits(NP and 255,8);
   PutBits((NP shr 8)and 255,8);
   For KK:=0 to Piece-1 do BufPut(DDst^,BufGet(DSrc^,Ps+KK));
   Inc(Ps,Piece);
  Until Left<=0;
 End
  Else
 If FixBits<=DynBits Then Begin
  PutBits(Ord(Final),1);
  PutBits(1,2);
  SendSyms(FixLens,FixCodes,FixDLens,FixDCodes);
 End
  Else
 Begin
  MakeCodes(LL,286,LC);
  MakeCodes(DL,30,DC);
  PutBits(Ord(Final),1);
  PutBits(2,2);
  PutBits(NLit-257,5);
  PutBits(NDist-1,5);
  PutBits(NCL-4,4);
  For I:=0 to NCL-1 do PutBits(CLL[CLOrder[I]],3);
  For I:=0 to NSym-1 do Begin
   PutBits(CLC[CLSym[I]],CLL[CLSym[I]]);
   Case CLSym[I]of
    16:PutBits(CLExt[I],2);
    17:PutBits(CLExt[I],3);
    18:PutBits(CLExt[I],7);
   End;
  End;
  SendSyms(LL,LC,DL,DC);
 End;
 FillChar(DLitF,SizeOf(DLitF),0);
 FillChar(DDistF,SizeOf(DDistF),0);
 DSym:=0;DExtra:=0;DBlkStart:=DCover;
End;

Procedure TallyLit(C:Byte);Begin
 DSymD^[DSym]:=0;
 DSymL^[DSym]:=C;
 Inc(DLitF[C]);
 Inc(DSym);Inc(DCover);
 If DSym>=LitBufSize-1 Then FlushBlock(False);
End;

Procedure TallyMatch(Len,Dist:Longint);
Var LC2,DC2:Integer;
Begin
 DSymD^[DSym]:=Dist;
 DSymL^[DSym]:=Len-3;
 LC2:=LCodeTab[Len-3];
 Inc(DLitF[257+LC2]);
 DC2:=DistCode(Dist);
 Inc(DDistF[DC2]);
 DExtra:=DExtra+LExt[LC2]+DExt[DC2];
 Inc(DSym);Inc(DCover,Len);
 If DSym>=LitBufSize-1 Then FlushBlock(False);
End;

Function DHash(Ps:Longint):Longint;
Var V:Longint;
Begin
 V:=(Longint(BufGet(DSrc^,Ps))shl 16)or(Longint(BufGet(DSrc^,Ps+1))shl 8)or BufGet(DSrc^,Ps+2);
 DHash:=(V xor(V shr 9)xor(V shr 17))and HashMask;
End;

Function DInsert(Ps:Longint):Longint;
Var H,C:Longint;
Begin
 H:=DHash(Ps);
 C:=DHead^[H]-1;
 If(C>=0)and(Ps-C<=MaxDist)Then PrevSet(Ps and WMaskD,Ps-C)
 Else Begin
  PrevSet(Ps and WMaskD,0);
  C:=-1;
 End;
 DHead^[H]:=Ps+1;
 DInsert:=C;
End;

Function LongestMatch(Ps,Cand,PrevLen:Longint;Var MDist:Longint):Longint;
Var Best,Chain,Lim,MaxLen,Nice,L,PD:Longint;Done:Boolean;
Begin
 Best:=PrevLen;
 Chain:=CfgChain;
 If PrevLen>=CfgGood Then Chain:=Chain shr 2;
 If Chain<1 Then Chain:=1;
 Lim:=Ps-MaxDist;
 MaxLen:=DN-Ps;
 If MaxLen>258 Then MaxLen:=258;
 Nice:=CfgNice;
 If Nice>MaxLen Then Nice:=MaxLen;
 Done:=False;
 Repeat
  If Best>=MaxLen Then Done:=True
   Else
  Begin
   If(BufGet(DSrc^,Cand+Best)=BufGet(DSrc^,Ps+Best))and(BufGet(DSrc^,Cand)=BufGet(DSrc^,Ps))Then Begin
    L:=1;
    While(L<MaxLen)and(BufGet(DSrc^,Cand+L)=BufGet(DSrc^,Ps+L))Do Inc(L);
    If L>Best Then Begin
     Best:=L;
     MDist:=Ps-Cand;
     If L>=Nice Then Done:=True;
    End;
   End;
   If Not Done Then Begin
    PD:=PrevGet(Cand and WMaskD);
    If PD=0 Then Done:=True
     Else
    Begin
     Cand:=Cand-PD;
     If Cand<Lim Then Done:=True;
     Dec(Chain);
     If Chain<=0 Then Done:=True;
    End;
   End;
  End;
 Until Done;
 LongestMatch:=Best;
End;

Procedure SetLevel(Level:Integer);Begin
 Case Level of
  1:Begin CfgGood:=4;CfgLazy:=4;CfgNice:=8;CfgChain:=4;End;
  2:Begin CfgGood:=4;CfgLazy:=5;CfgNice:=16;CfgChain:=8;End;
  3:Begin CfgGood:=4;CfgLazy:=6;CfgNice:=32;CfgChain:=32;End;
  4:Begin CfgGood:=4;CfgLazy:=4;CfgNice:=16;CfgChain:=16;End;
  5:Begin CfgGood:=8;CfgLazy:=16;CfgNice:=32;CfgChain:=32;End;
  6:Begin CfgGood:=8;CfgLazy:=16;CfgNice:=128;CfgChain:=128;End;
  7:Begin CfgGood:=8;CfgLazy:=32;CfgNice:=128;CfgChain:=256;End;
  8:Begin CfgGood:=32;CfgLazy:=128;CfgNice:=258;CfgChain:=1024;End;
  Else Begin CfgGood:=32;CfgLazy:=258;CfgNice:=258;CfgChain:=4096;End;
 End;
End;

Procedure DeflateBuf(Var Src,Dst:TBuf;Level:Integer);
Var
 Ps,N,HeadC,PrevLen,PrevDist,CurLen,CurDist,P2,MD,S1,S2,I,K:Longint;
 Avail:Boolean;Flg:Byte;
Begin
 DefInit;
 SetLevel(Level);
 DSrc:=@Src;DDst:=@Dst;DN:=Src.Len;N:=DN;
 DBB:=0;DBC:=0;DSym:=0;DCover:=0;DBlkStart:=0;DExtra:=0;
 FillChar(DLitF,SizeOf(DLitF),0);
 FillChar(DDistF,SizeOf(DDistF),0);
 Case Level of
  0,1:Flg:=$01;
  2,3,4,5:Flg:=$5E;
  6:Flg:=$9C;
  Else Flg:=$DA;
 End;
 BufPut(Dst,$78);BufPut(Dst,Flg);
 DForceStore:=(Level<=0);
 If Level<=0 Then Begin
  DCover:=N;
  FlushBlock(True);
 End
  Else
 Begin
  FillChar(DHead^,SizeOf(THead),0);
  Ps:=0;Avail:=False;CurLen:=2;CurDist:=0;
  While Ps<N Do Begin
   HeadC:=-1;
   If Ps+2<N Then HeadC:=DInsert(Ps);
   PrevLen:=CurLen;PrevDist:=CurDist;CurLen:=2;
   If(HeadC>=0)and(PrevLen<CfgLazy)Then Begin
    MD:=CurDist;
    CurLen:=LongestMatch(Ps,HeadC,PrevLen,MD);
    CurDist:=MD;
    If(CurLen=3)and(CurDist>4096)Then CurLen:=2;
   End;
   If(PrevLen>=3)and(CurLen<=PrevLen)Then Begin
    TallyMatch(PrevLen,PrevDist);
    P2:=Ps+1;
    While P2<=Ps+PrevLen-2 Do Begin
     If P2+2<N Then DInsert(P2);
     Inc(P2);
    End;
    Ps:=Ps+PrevLen-1;
    Avail:=False;CurLen:=2;
   End
    Else
   If Avail Then Begin
    TallyLit(BufGet(Src,Ps-1));
    Inc(Ps);
   End
    Else
   Begin
    Avail:=True;
    Inc(Ps);
   End;
  End;
  If Avail Then TallyLit(BufGet(Src,N-1));
  FlushBlock(True);
 End;
 AlignByte;
 { Adler-32 }
 S1:=1;S2:=0;I:=0;
 While I<N Do Begin
  K:=I+1024;
  If K>N Then K:=N;
  While I<K Do Begin
   S1:=S1+BufGet(Src,I);
   S2:=S2+S1;
   Inc(I);
  End;
  S1:=S1 mod 65521;
  S2:=S2 mod 65521;
 End;
 BufPut(Dst,(S2 shr 8)and 255);BufPut(Dst,S2 and 255);
 BufPut(Dst,(S1 shr 8)and 255);BufPut(Dst,S1 and 255);
End;

{ ------------------------------------------------------------------ }
{ Autres filtres : ASCIIHex, ASCII85, RunLength, LZW                  }
{ ------------------------------------------------------------------ }

Function HexVal(C:Integer):Integer;Begin
 If(C>=48)and(C<=57)Then HexVal:=C-48
 Else If(C>=65)and(C<=70)Then HexVal:=C-55
 Else If(C>=97)and(C<=102)Then HexVal:=C-87
 Else HexVal:=-1;
End;

Function DecodeAHx(Var Src,Dst:TBuf):Boolean;
Var I,H,Cur:Longint;V:Integer;Done:Boolean;
Begin
 H:=-1;I:=0;Done:=False;
 While(I<Src.Len)and Not Done Do Begin
  V:=BufGet(Src,I);Inc(I);
  If V=62 Then Done:=True
   Else
  If Not IsWS(V)Then Begin
   Cur:=HexVal(V);
   If Cur<0 Then Begin DecodeAHx:=False;Exit;End;
   If H<0 Then H:=Cur
    Else
   Begin
    BufPut(Dst,H*16+Cur);H:=-1;
   End;
  End;
 End;
 If H>=0 Then BufPut(Dst,H*16);
 DecodeAHx:=True;
End;

{ Ecrit les octets d'un groupe ASCII85 (N chiffres, N>=2) sans depasser 32 bits }
Type
 TA85=Array[0..4]of Longint;

Procedure A85Group(Var Dst:TBuf;Var T:TA85;N:Integer);
Var X,XH,XL,LP,LPH,LPL,HI:Longint;K:Integer;
Begin
 For K:=N to 4 do T[K]:=84;
 X:=((T[0]*85+T[1])*85+T[2])*85+T[3];
 XH:=X shr 16;XL:=X and 65535;
 LP:=XL*85+T[4];
 LPH:=LP shr 16;LPL:=LP and 65535;
 HI:=(XH*85+LPH)and 65535;
 BufPut(Dst,(HI shr 8)and 255);
 If N>2 Then BufPut(Dst,HI and 255);
 If N>3 Then BufPut(Dst,(LPL shr 8)and 255);
 If N>4 Then BufPut(Dst,LPL and 255);
End;

Function DecodeA85(Var Src,Dst:TBuf):Boolean;
Var I,N:Longint;V:Integer;Done:Boolean;T:TA85;
Begin
 DecodeA85:=False;
 I:=0;N:=0;Done:=False;
 If(Src.Len>=2)and(BufGet(Src,0)=60)and(BufGet(Src,1)=126)Then I:=2;
 While(I<Src.Len)and Not Done Do Begin
  V:=BufGet(Src,I);Inc(I);
  If IsWS(V)Then
   Else
  If V=126 Then Done:=True
   Else
  If(V=122)and(N=0)Then Begin
   BufPut(Dst,0);BufPut(Dst,0);BufPut(Dst,0);BufPut(Dst,0);
  End
   Else
  If(V>=33)and(V<=117)Then Begin
   T[N]:=V-33;Inc(N);
   If N=5 Then Begin
    A85Group(Dst,T,5);
    N:=0;
   End;
  End
   Else
  Exit;
 End;
 If N>1 Then A85Group(Dst,T,N);
 DecodeA85:=True;
End;

Function DecodeRL(Var Src,Dst:TBuf):Boolean;
Var I,L,K:Longint;B:Byte;
Begin
 DecodeRL:=False;
 I:=0;
 While I<Src.Len Do Begin
  L:=BufGet(Src,I);Inc(I);
  If L=128 Then Begin DecodeRL:=True;Exit;End;
  If L<128 Then Begin
   For K:=0 to L do Begin
    If I>=Src.Len Then Exit;
    BufPut(Dst,BufGet(Src,I));Inc(I);
   End;
  End
   Else
  Begin
   If I>=Src.Len Then Exit;
   B:=BufGet(Src,I);Inc(I);
   For K:=1 to 257-L do BufPut(Dst,B);
  End;
  If Dst.Len>InflateLimit Then Exit;
 End;
 DecodeRL:=True;
End;

Type
 TLzwPre=Array[0..4095]of Word;
 TLzwSuf=Array[0..4095]of Byte;
 TLzwStk=Array[0..4096]of Byte;
 PLzwPre=^TLzwPre;
 PLzwSuf=^TLzwSuf;
 PLzwStk=^TLzwStk;

Function DecodeLZW(Var Src,Dst:TBuf;Early:Longint):Boolean;
Var
 Pre:PLzwPre;Suf:PLzwSuf;Stk:PLzwStk;
 BitBuf,BitCnt,Width,NextC,Code,Prev,SP,Cur,I,FirstCh:Longint;
 Ps:Longint;Ok,Done:Boolean;
Begin
 DecodeLZW:=False;
 GetMem(Pre,SizeOf(TLzwPre));GetMem(Suf,SizeOf(TLzwSuf));GetMem(Stk,SizeOf(TLzwStk));
 BitBuf:=0;BitCnt:=0;Ps:=0;Width:=9;NextC:=258;Prev:=-1;FirstCh:=0;
 Ok:=True;Done:=False;
 While Ok and Not Done Do Begin
  While(BitCnt<Width)and(Ps<Src.Len)Do Begin
   BitBuf:=(BitBuf shl 8)or BufGet(Src,Ps);Inc(Ps);Inc(BitCnt,8);
  End;
  If BitCnt<Width Then Done:=True
   Else
  Begin
   Code:=(BitBuf shr(BitCnt-Width))and BitMask[Width];
   Dec(BitCnt,Width);
   BitBuf:=BitBuf and BitMask[BitCnt];
   If Code=256 Then Begin
    NextC:=258;Width:=9;Prev:=-1;
   End
    Else
   If Code=257 Then Done:=True
    Else
   If Prev<0 Then Begin
    If Code>255 Then Ok:=False
     Else
    Begin
     BufPut(Dst,Code);Prev:=Code;FirstCh:=Code;
    End;
   End
    Else
   Begin
    If Code>NextC Then Ok:=False
     Else
    Begin
     If Code=NextC Then Cur:=Prev Else Cur:=Code;
     SP:=0;
     While Cur>=258 Do Begin
      Stk^[SP]:=Suf^[Cur];Inc(SP);
      Cur:=Pre^[Cur];
     End;
     Stk^[SP]:=Cur;Inc(SP);
     FirstCh:=Cur;
     For I:=SP-1 downto 0 do BufPut(Dst,Stk^[I]);
     If Code=NextC Then BufPut(Dst,FirstCh);
     If NextC<4096 Then Begin
      Pre^[NextC]:=Prev;Suf^[NextC]:=FirstCh;Inc(NextC);
     End;
     Prev:=Code;
     If Dst.Len>InflateLimit Then Ok:=False;
    End;
   End;
   If NextC+Early>=2048 Then Width:=12
    Else If NextC+Early>=1024 Then Width:=11
    Else If NextC+Early>=512 Then Width:=10
    Else Width:=9;
  End;
 End;
 FreeMem(Pre,SizeOf(TLzwPre));FreeMem(Suf,SizeOf(TLzwSuf));FreeMem(Stk,SizeOf(TLzwStk));
 DecodeLZW:=Ok;
End;

{ ------------------------------------------------------------------ }
{ Predicteurs PNG / TIFF                                              }
{ ------------------------------------------------------------------ }

Function Unpredict(Var Src,Dst:TBuf;Pred,Colors,Bpc,Cols:Longint):Boolean;
Var RowBytes,Bpp,Ps,N,I,RowStart,DB:Longint;Ft,X,A,B,C,V,PA,PB,PC,Pp:Longint;
Begin
 Unpredict:=False;
 If(Colors<1)or(Bpc<1)or(Cols<1)or(Colors>64)or(Bpc>16)Then Exit;
 If Cols>10000000 Then Exit;
 RowBytes:=(Colors*Bpc*Cols+7)div 8;
 Bpp:=(Colors*Bpc+7)div 8;
 If RowBytes<1 Then Exit;
 DB:=Dst.Len;
 If Pred=2 Then Begin
  If Bpc<>8 Then Exit;
  Ps:=0;
  While Ps<Src.Len Do Begin
   N:=RowBytes;
   If N>Src.Len-Ps Then N:=Src.Len-Ps;
   RowStart:=Dst.Len;
   For I:=0 to N-1 do Begin
    V:=BufGet(Src,Ps+I);
    If I>=Colors Then V:=(V+BufGet(Dst,RowStart+I-Colors))and 255;
    BufPut(Dst,V);
   End;
   Inc(Ps,N);
  End;
  Unpredict:=True;Exit;
 End;
 If(Pred<10)or(Pred>15)Then Exit;
 Ps:=0;
 While Ps<Src.Len Do Begin
  Ft:=BufGet(Src,Ps);Inc(Ps);
  If Ft>4 Then Exit;
  N:=RowBytes;
  If N>Src.Len-Ps Then N:=Src.Len-Ps;
  RowStart:=Dst.Len;
  For I:=0 to N-1 do Begin
   X:=BufGet(Src,Ps+I);
   If I>=Bpp Then A:=BufGet(Dst,RowStart+I-Bpp) Else A:=0;
   If RowStart-RowBytes>=DB Then Begin
    B:=BufGet(Dst,RowStart-RowBytes+I);
    If I>=Bpp Then C:=BufGet(Dst,RowStart-RowBytes+I-Bpp) Else C:=0;
   End
    Else
   Begin B:=0;C:=0;End;
   Case Ft of
    0:V:=X;
    1:V:=X+A;
    2:V:=X+B;
    3:V:=X+((A+B)shr 1);
    Else Begin
     Pp:=A+B-C;
     PA:=Pp-A;If PA<0 Then PA:=-PA;
     PB:=Pp-B;If PB<0 Then PB:=-PB;
     PC:=Pp-C;If PC<0 Then PC:=-PC;
     If(PA<=PB)and(PA<=PC)Then V:=X+A
      Else If PB<=PC Then V:=X+B
      Else V:=X+C;
    End;
   End;
   BufPut(Dst,V and 255);
  End;
  Inc(Ps,N);
 End;
 Unpredict:=True;
End;

{ ------------------------------------------------------------------ }
{ Analyse et decodage des filtres d'un flux                           }
{ ------------------------------------------------------------------ }

Function NormFilter(Const S:String):String;Begin
 If S='Fl' Then NormFilter:='FlateDecode'
 Else If S='AHx' Then NormFilter:='ASCIIHexDecode'
 Else If S='A85' Then NormFilter:='ASCII85Decode'
 Else If S='LZW' Then NormFilter:='LZWDecode'
 Else If S='RL' Then NormFilter:='RunLengthDecode'
 Else NormFilter:=S;
End;

Procedure ParseParm(I:Integer;P:Longint);
Var V,X:Longint;
Begin
 FParm[I]:=P;
 X:=DictFind(P,'Predictor');
 If X>=0 Then Begin If ReadDirectInt(X,V)Then FPred[I]:=V Else FOk:=False;End;
 X:=DictFind(P,'Colors');
 If X>=0 Then Begin If ReadDirectInt(X,V)Then FColors[I]:=V Else FOk:=False;End;
 X:=DictFind(P,'BitsPerComponent');
 If X>=0 Then Begin If ReadDirectInt(X,V)Then FBpc[I]:=V Else FOk:=False;End;
 X:=DictFind(P,'Columns');
 If X>=0 Then Begin If ReadDirectInt(X,V)Then FCols[I]:=V Else FOk:=False;End;
 X:=DictFind(P,'EarlyChange');
 If X>=0 Then Begin If ReadDirectInt(X,V)Then FEarly[I]:=V Else FOk:=False;End;
End;

Procedure AnalyzeFilters(DictPos:Longint);
Var V,V2,P:Longint;C:Integer;I:Integer;Done:Boolean;S:String;
Begin
 FOk:=True;NF:=0;
 SBuf:=NIL;
 V:=DictFind(DictPos,'Filter');
 If V>=0 Then Begin
  SkipWS(V);
  C:=SB(V);
  If C=47 Then Begin
   S:=ReadNameStr(V);
   NF:=1;FName[1]:=NormFilter(S);
   If Length(S)>40 Then FOk:=False;
  End
   Else
  If C=91 Then Begin
   P:=V+1;Done:=False;
   Repeat
    SkipWS(P);C:=SB(P);
    If C=93 Then Done:=True
     Else
    If C=47 Then Begin
     S:=ReadNameStr(P);
     If(NF>=MaxFilt)or(Length(S)>40)Then Begin FOk:=False;Done:=True;End
      Else
     Begin Inc(NF);FName[NF]:=NormFilter(S);End;
    End
     Else
    Begin FOk:=False;Done:=True;End;
   Until Done;
  End
   Else
  If Not MatchKW(V,'null')Then FOk:=False;
 End;
 For I:=1 to MaxFilt do Begin
  FParm[I]:=-1;FPred[I]:=1;FColors[I]:=1;FBpc[I]:=8;FCols[I]:=1;FEarly[I]:=1;
 End;
 If NF=0 Then Exit;
 V2:=DictFind(DictPos,'DecodeParms');
 If V2<0 Then V2:=DictFind(DictPos,'DP');
 If V2>=0 Then Begin
  SkipWS(V2);C:=SB(V2);
  If C=60 Then Begin
   If NF=1 Then ParseParm(1,V2) Else FOk:=False;
  End
   Else
  If C=91 Then Begin
   P:=V2+1;
   For I:=1 to NF do Begin
    SkipWS(P);C:=SB(P);
    If C=60 Then Begin
     ParseParm(I,P);
     SkipValueAt(P);
    End
     Else
    If MatchKW(P,'null')Then Inc(P,4)
     Else
    If C=93 Then
     Else
    Begin FOk:=False;SkipValueAt(P);End;
   End;
  End
   Else
  If Not MatchKW(V2,'null')Then FOk:=False;
 End;
End;

Function DecodeOne(I:Integer;Var Src,Dst:TBuf;PredToo:Boolean):Boolean;
Var Ok:Boolean;
Begin
 BufClear(Dst);
 Ok:=False;
 If FName[I]='FlateDecode' Then Ok:=InflateBuf(Src,0,Dst,True)
 Else If FName[I]='LZWDecode' Then Ok:=DecodeLZW(Src,Dst,FEarly[I])
 Else If FName[I]='ASCII85Decode' Then Ok:=DecodeA85(Src,Dst)
 Else If FName[I]='ASCIIHexDecode' Then Ok:=DecodeAHx(Src,Dst)
 Else If FName[I]='RunLengthDecode' Then Ok:=DecodeRL(Src,Dst);
 If Ok and PredToo and(FPred[I]>1)and((FName[I]='FlateDecode')or(FName[I]='LZWDecode'))Then Begin
  BufClear(PredTmp);
  BufAppend(PredTmp,Dst,0,Dst.Len);
  BufClear(Dst);
  Ok:=Unpredict(PredTmp,Dst,FPred[I],FColors[I],FBpc[I],FCols[I]);
 End;
 DecodeOne:=Ok;
End;

{ Peut-on decoder le filtre I ? (PredToo : autoriser les predicteurs) }
Function CanDecode(I:Integer;PredToo:Boolean):Boolean;
Var N:String;
Begin
 CanDecode:=False;
 N:=FName[I];
 If Not((N='FlateDecode')or(N='LZWDecode')or(N='ASCII85Decode')or(N='ASCIIHexDecode')or(N='RunLengthDecode'))Then Exit;
 If FPred[I]>1 Then Begin
  If Not PredToo Then Exit;
  If FPred[I]=2 Then Begin If FBpc[I]<>8 Then Exit;End
   Else
  If(FPred[I]<10)or(FPred[I]>15)Then Exit;
 End;
 CanDecode:=True;
End;

{ Decode completement le flux (xref, flux d'objets) }
Function DecodeStreamFull(DictPos:Longint;Var Raw,Dst:TBuf):Boolean;
Var I:Integer;Src,Tgt:PBuf;Ok:Boolean;Flip:Boolean;
Begin
 DecodeStreamFull:=False;
 BufClear(Dst);
 AnalyzeFilters(DictPos);
 If Not FOk Then Exit;
 If NF=0 Then Begin
  BufAppend(Dst,Raw,0,Raw.Len);
  DecodeStreamFull:=True;Exit;
 End;
 Src:=@Raw;Flip:=False;
 For I:=1 to NF do Begin
  If Not CanDecode(I,True)Then Exit;
  If I=NF Then Tgt:=@Dst
   Else
  Begin
   If Flip Then Tgt:=@DecB Else Tgt:=@DecA;
   Flip:=Not Flip;
  End;
  Ok:=DecodeOne(I,Src^,Tgt^,True);
  If Not Ok Then Exit;
  Src:=Tgt;
 End;
 DecodeStreamFull:=True;
End;

{ ------------------------------------------------------------------ }
{ Lecture des donnees brutes d'un flux                                }
{ ------------------------------------------------------------------ }

Function OpenObject(N:Longint;Var P:Longint):Boolean;Forward;

Function ResolveInt(N:Longint;Var V:Longint):Boolean;
Var P:Longint;Save:PBuf;
Begin
 ResolveInt:=False;
 Save:=SBuf;
 If OpenObject(N,P)Then ResolveInt:=ReadDirectInt(P,V);
 SBuf:=Save;
End;

{ Determine le debut et la fin des donnees d'un flux (dictionnaire en DictPos) }
Function StreamExtent(DictPos:Longint;Var DS,DE:Longint):Boolean;
Var P,L,LenPos,N1,A,Q,Fnd,K:Longint;C:Integer;Save:PBuf;Valid:Boolean;
Begin
 StreamExtent:=False;
 SBuf:=NIL;
 P:=DictPos;SkipValueAt(P);SkipWS(P);
 If Not MatchKW(P,'stream')Then Exit;
 Inc(P,6);
 C:=SB(P);
 If C=13 Then Begin
  Inc(P);
  If SB(P)=10 Then Inc(P);
 End
  Else
 If C=10 Then Inc(P);
 DS:=P;
 L:=-1;
 LenPos:=DictFind(DictPos,'Length');
 If LenPos>=0 Then Begin
  If IsRefAt(LenPos,N1,A)Then Begin
   Save:=SBuf;
   If Not ResolveInt(N1,L)Then L:=-1;
   SBuf:=Save;
  End
   Else
  If Not ReadInt(LenPos,L)Then L:=-1;
 End;
 SBuf:=NIL;
 Valid:=False;
 If(L>=0)and(DS+L<=SFSize)Then Begin
  Q:=DS+L;SkipWS(Q);
  If MatchKW(Q,'endstream')or MatchKW(Q,'endobj')Then Valid:=True;
 End;
 If Valid Then DE:=DS+L
  Else
 Begin
  Fnd:=-1;Q:=DS;
  While Q<SFSize Do Begin
   If SB(Q)=101 Then Begin
    If MatchStr(Q,'endstream')Then Begin Fnd:=Q;Q:=SFSize;End;
   End;
   Inc(Q);
  End;
  If Fnd<0 Then Begin
   Q:=DS;
   While Q<SFSize Do Begin
    If SB(Q)=101 Then Begin
     If MatchStr(Q,'endobj')Then Begin Fnd:=Q;Q:=SFSize;End;
    End;
    Inc(Q);
   End;
  End;
  If Fnd<0 Then Fnd:=SFSize;
  DE:=Fnd;
  If(DE>DS)and(SB(DE-1)=10)Then Dec(DE);
  If(DE>DS)and(SB(DE-1)=13)Then Dec(DE);
 End;
 K:=DE-DS;
 If K<0 Then DE:=DS;
 StreamExtent:=True;
End;

Function GetRaw(DictPos:Longint;Var Raw:TBuf):Boolean;
Var DS,DE:Longint;
Begin
 GetRaw:=False;
 BufClear(Raw);
 If Not StreamExtent(DictPos,DS,DE)Then Exit;
 Seek(SF,DS);
 BufReadFile(SF,DE-DS,Raw);
 GetRaw:=True;
End;

{ ------------------------------------------------------------------ }
{ Acces aux objets (fichier ou flux d'objets)                         }
{ ------------------------------------------------------------------ }

Function LocateFileObj(N:Longint;Var P:Longint):Boolean;
Var R:PObjRec;Q,A,B:Longint;
Begin
 LocateFileObj:=False;
 R:=PeekRec(N);
 If(R^.Kind<>1)or(R^.Off<0)or(R^.Off>=SFSize)Then Exit;
 SBuf:=NIL;
 Q:=R^.Off;
 If Not ReadInt(Q,A)Then Exit;
 If A<>N Then Exit;
 If Not ReadInt(Q,B)Then Exit;
 SkipWS(Q);
 If Not MatchKW(Q,'obj')Then Exit;
 Inc(Q,3);SkipWS(Q);
 P:=Q;
 LocateFileObj:=True;
End;

Function LoadObjStm(StmNum:Longint):Integer;
Var I,Slot:Integer;P,V,N,First,K,A,B,Q:Longint;Save:PBuf;
Begin
 LoadObjStm:=-1;
 For I:=0 to CacheN-1 do If SC[I].Num=StmNum Then Begin
  LoadObjStm:=I;Exit;
 End;
 Save:=SBuf;
 If Not LocateFileObj(StmNum,P)Then Begin SBuf:=Save;Exit;End;
 N:=0;First:=0;
 V:=DictFind(P,'N');
 If Not ReadDirectInt(V,N)Then Begin SBuf:=Save;Exit;End;
 V:=DictFind(P,'First');
 If Not ReadDirectInt(V,First)Then Begin SBuf:=Save;Exit;End;
 Slot:=SCNext;SCNext:=(SCNext+1)mod CacheN;
 SC[Slot].Num:=-1;
 BufClear(SC[Slot].Data);BufClear(SC[Slot].Hdr);
 If Not GetRaw(P,RawX)Then Begin SBuf:=Save;Exit;End;
 If Not DecodeStreamFull(P,RawX,SC[Slot].Data)Then Begin SBuf:=Save;Exit;End;
 SBuf:=@SC[Slot].Data;
 Q:=0;K:=0;
 While K<N Do Begin
  If(Not ReadInt(Q,A))or(Not ReadInt(Q,B))Then K:=N
   Else
  Begin
   BufPutL(SC[Slot].Hdr,A);
   BufPutL(SC[Slot].Hdr,B);
   Inc(K);
  End;
 End;
 SBuf:=Save;
 SC[Slot].Count:=SC[Slot].Hdr.Len div 8;
 SC[Slot].First:=First;
 SC[Slot].Num:=StmNum;
 LoadObjStm:=Slot;
End;

Function OpenObject(N:Longint;Var P:Longint):Boolean;
Var R:PObjRec;S:Integer;K,Off,I:Longint;
Begin
 OpenObject:=False;
 R:=PeekRec(N);
 Case R^.Kind of
  1:OpenObject:=LocateFileObj(N,P);
  2:Begin
   S:=LoadObjStm(R^.Off);
   If S<0 Then Exit;
   K:=R^.Idx;
   If(K<0)or(K>=SC[S].Count)or(BufGetL(SC[S].Hdr,K*8)<>N)Then Begin
    K:=-1;
    For I:=0 to SC[S].Count-1 do
     If(K<0)and(BufGetL(SC[S].Hdr,I*8)=N)Then K:=I;
    If K<0 Then Exit;
   End;
   Off:=BufGetL(SC[S].Hdr,K*8+4);
   SBuf:=@SC[S].Data;
   P:=SC[S].First+Off;
   If P>=SC[S].Data.Len Then Exit;
   OpenObject:=True;
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Lecture de la table xref                                            }
{ ------------------------------------------------------------------ }

Function ReadField(Var B:TBuf;Ps,W:Longint):Longint;
Var I,V:Longint;
Begin
 V:=0;
 For I:=0 to W-1 do Begin
  If V>8388607 Then V:=2147483647 Else V:=V*256+BufGet(B,Ps+I);
 End;
 ReadField:=V;
End;

Procedure SetEntry(Num,Typ,F2,F3:Longint);
Var R:PObjRec;
Begin
 If(Num<1)or(Num>MaxObjNum)Then Exit;
 R:=GetRec(Num);
 If R^.Kind<>0 Then Exit;
 If Typ=0 Then Begin
  R^.Flags:=R^.Flags or FlFree;
  Exit;
 End;
 If((R^.Flags and FlFree)<>0)and Not OverrideFree Then Exit;
 If Typ=1 Then Begin
  If F2<=0 Then Exit;
  R^.Kind:=1;R^.Off:=F2+Bias;R^.Gen:=F3;
 End
  Else
 If Typ=2 Then Begin
  R^.Kind:=2;R^.Off:=F2;R^.Idx:=F3;
 End;
End;

Function ReadXrefStream(P:Longint;Var Prev:Longint):Boolean;
Var DP,V,W0,W1,W2,Size,Q,A,B,K,Ps,RowLen,Start,Cnt,T,F2,F3,Q2:Longint;
Begin
 ReadXrefStream:=False;
 Prev:=-1;
 SBuf:=NIL;
 Q:=P;
 If Not ReadInt(Q,A)Then Exit;
 If Not ReadInt(Q,B)Then Exit;
 SkipWS(Q);
 If Not MatchKW(Q,'obj')Then Exit;
 Inc(Q,3);SkipWS(Q);
 DP:=Q;
 If(SB(DP)<>60)or(SB(DP+1)<>60)Then Exit;
 V:=DictFind(DP,'W');
 If V<0 Then Exit;
 SkipWS(V);
 If SB(V)<>91 Then Exit;
 Inc(V);
 If Not ReadInt(V,W0)Then Exit;
 If Not ReadInt(V,W1)Then Exit;
 If Not ReadInt(V,W2)Then Exit;
 If(W0<0)or(W1<0)or(W2<0)or(W0>4)or(W1>4)or(W2>4)Then Exit;
 RowLen:=W0+W1+W2;
 If RowLen=0 Then Exit;
 V:=DictFind(DP,'Size');
 If Not ReadDirectInt(V,Size)Then Exit;
 V:=DictFind(DP,'Prev');
 If(V>=0)and ReadDirectInt(V,A)Then Prev:=A+Bias;
 If(TrailerPos<0)and(DictFind(DP,'Root')>=0)Then TrailerPos:=DP;
 If Not GetRaw(DP,XRaw)Then Exit;
 If Not DecodeStreamFull(DP,XRaw,XDec)Then Exit;
 Ps:=0;
 V:=DictFind(DP,'Index');
 If V>=0 Then Begin
  SkipWS(V);
  If SB(V)=91 Then Q2:=V+1 Else Q2:=-1;
 End
  Else
 Q2:=-1;
 If Q2<0 Then Begin
  Start:=0;Cnt:=Size;
 End;
 Repeat
  If Q2>=0 Then Begin
   SkipWS(Q2);
   If SB(Q2)=93 Then Begin Start:=0;Cnt:=0;Q2:=-2;End
    Else
   If(Not ReadInt(Q2,Start))or(Not ReadInt(Q2,Cnt))Then Begin Start:=0;Cnt:=0;Q2:=-2;End;
  End;
  K:=0;
  While(K<Cnt)and(Ps+RowLen<=XDec.Len)Do Begin
   If W0>0 Then T:=ReadField(XDec,Ps,W0) Else T:=1;
   F2:=ReadField(XDec,Ps+W0,W1);
   F3:=ReadField(XDec,Ps+W0+W1,W2);
   Inc(Ps,RowLen);
   SetEntry(Start+K,T,F2,F3);
   Inc(K);
  End;
  If Q2=-1 Then Q2:=-2;
 Until Q2=-2;
 ReadXrefStream:=True;
End;

Function ReadXrefTable(P:Longint;Var Prev:Longint;Var XStm:Longint):Boolean;
Var Start,Cnt,I,Off,Gen,Num,V,TP:Longint;C:Integer;Done:Boolean;Shift:Longint;
Begin
 ReadXrefTable:=False;
 Prev:=-1;XStm:=-1;
 SBuf:=NIL;
 Done:=False;
 Repeat
  SkipWS(P);
  If MatchKW(P,'trailer')Then Done:=True
   Else
  Begin
   If Not ReadInt(P,Start)Then Exit;
   If Not ReadInt(P,Cnt)Then Exit;
   If(Cnt<0)or(Start<0)Then Exit;
   Shift:=0;
   I:=0;
   While I<Cnt Do Begin
    If Not ReadInt(P,Off)Then Exit;
    If Not ReadInt(P,Gen)Then Exit;
    SkipWS(P);
    C:=SB(P);
    If(C<>110)and(C<>102)Then Exit;
    Inc(P);
    If(I=0)and(C=102)and(Start=1)and(Off=0)and(Gen=65535)Then Shift:=-1;
    Num:=Start+I+Shift;
    If(C=110)and(Off>0)Then SetEntry(Num,1,Off,Gen)
     Else
    If C=102 Then SetEntry(Num,0,0,0);
    Inc(I);
   End;
  End;
 Until Done;
 Inc(P,7);
 SkipWS(P);
 If(SB(P)<>60)or(SB(P+1)<>60)Then Exit;
 TP:=P;
 If(TrailerPos<0)and(DictFind(TP,'Root')>=0)Then TrailerPos:=TP;
 V:=DictFind(TP,'Prev');
 If(V>=0)and ReadDirectInt(V,Off)Then Prev:=Off+Bias;
 V:=DictFind(TP,'XRefStm');
 If(V>=0)and ReadDirectInt(V,Off)Then XStm:=Off+Bias;
 ReadXrefTable:=True;
End;

Function ReadXrefChain(Start:Longint):Boolean;
Var P,Q,Prev,XS,Dummy:Longint;Ok,First:Boolean;NV,I:Integer;Seen:Boolean;
    Visited:Array[0..63]of Longint;
Begin
 ReadXrefChain:=False;
 FillChar(Visited,SizeOf(Visited),0);
 P:=Start;NV:=0;First:=True;
 While P>=0 Do Begin
  Seen:=(NV>=64);
  For I:=0 to NV-1 do If Visited[I]=P Then Seen:=True;
  If Seen Then P:=-1
   Else
  Begin
   Visited[NV]:=P;Inc(NV);
   Q:=P;SkipWS(Q);
   If MatchKW(Q,'xref')Then Begin
    Ok:=ReadXrefTable(Q+4,Prev,XS);
    If First Then SrcXrefStm:=False;
    If Ok and(XS>0)Then Begin
     OverrideFree:=True;
     Ok:=ReadXrefStream(XS,Dummy) or Ok;
     OverrideFree:=False;
    End;
   End
    Else
   Begin
    Ok:=ReadXrefStream(Q,Prev);
    If First Then SrcXrefStm:=True;
   End;
   If Not Ok Then Begin
    If First Then Exit;
    P:=-1;
   End
    Else
   Begin
    ReadXrefChain:=True;
    First:=False;
    P:=Prev;
   End;
  End;
 End;
End;

Function FindStartXref:Longint;
Var P,Lo,V,Q:Longint;
Begin
 FindStartXref:=-1;
 Lo:=SFSize-2048;
 If Lo<0 Then Lo:=0;
 P:=SFSize-9;
 While P>=Lo Do Begin
  If SB(P)=115 Then Begin
   If MatchKW(P,'startxref')Then Begin
    Q:=P+9;
    If ReadInt(Q,V)Then Begin FindStartXref:=V+Bias;Exit;End;
   End;
  End;
  Dec(P);
 End;
End;

{ ------------------------------------------------------------------ }
{ Reconstruction de la table xref                                     }
{ ------------------------------------------------------------------ }

Procedure Reconstruct;
Var P,Q,Q2,N,G,DP,DS,DE,V,K,Nn:Longint;C:Integer;R,R2:PObjRec;T:String;S:Integer;
Begin
 Warn('structure xref invalide ou incomplete : reconstruction de la table des objets.');
 Reconstructed:=True;
 ResetObjects;
 SBuf:=NIL;
 SrcXrefStm:=False;
 P:=0;
 While P<SFSize Do Begin
  C:=SB(P);
  If(C>=48)and(C<=57)and((P=0)or Not IsReg(SB(P-1)))Then Begin
   Q:=P;
   If ReadInt(Q,N)and ReadInt(Q,G)Then Begin
    SkipWS(Q);
    If MatchKW(Q,'obj')and(N>=1)and(N<=MaxObjNum)Then Begin
     R:=GetRec(N);
     R^.Kind:=1;R^.Off:=P;R^.Gen:=G;R^.Flags:=0;R^.Idx:=0;
     Inc(Q,3);SkipWS(Q);
     P:=Q;
     If(SB(Q)=60)and(SB(Q+1)=60)Then Begin
      DP:=Q;
      Q2:=Q;SkipValueAt(Q2);SkipWS(Q2);
      If MatchKW(Q2,'stream')Then Begin
       If StreamExtent(DP,DS,DE)Then P:=DE;
       T:=ReadNameAt(DictFind(DP,'Type'));
       If T='ObjStm' Then Begin
        S:=LoadObjStm(N);
        If S>=0 Then
         For K:=0 to SC[S].Count-1 do Begin
          Nn:=BufGetL(SC[S].Hdr,K*8);
          If(Nn>=1)and(Nn<=MaxObjNum)Then Begin
           R2:=GetRec(Nn);
           R2^.Kind:=2;R2^.Off:=N;R2^.Idx:=K;R2^.Flags:=0;
          End;
         End;
        SBuf:=NIL;
       End
        Else
       If T='XRef' Then Begin
        If DictFind(DP,'Root')>=0 Then Begin TrailerPos:=DP;SrcXrefStm:=True;End;
       End;
      End;
     End;
    End
     Else
    Inc(P);
   End
    Else
   Inc(P);
  End
   Else
  If(C=116)and MatchKW(P,'trailer')Then Begin
   Q:=P+7;SkipWS(Q);
   If(SB(Q)=60)and(SB(Q+1)=60)Then Begin
    If DictFind(Q,'Root')>=0 Then Begin TrailerPos:=Q;SrcXrefStm:=False;End;
    P:=Q;
   End
    Else
   Inc(P);
  End
   Else
  Inc(P);
 End;
 If TrailerPos<0 Then Begin
  { recherche d'un catalogue }
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If R^.Kind<>0 Then Begin
    If OpenObject(N,P)Then Begin
     V:=DictFind(P,'Type');
     If ReadNameAt(V)='Catalog' Then SynthRoot:=N;
    End;
    SBuf:=NIL;
   End;
  End;
  If SynthRoot=0 Then Fatal('impossible de trouver la racine (Root) du document.');
 End;
End;

{ ------------------------------------------------------------------ }
{ Options                                                             }
{ ------------------------------------------------------------------ }

Var
 InName:String;
 CompressOn,DecodeOn,RecompFlate:Boolean;
 ObjMode:Integer;          { 0=disable 1=preserve 2=generate }
 Level:Integer;
 CheckOnly,ShowNPages:Boolean;
 MinVerMaj,MinVerMin,ForceMaj,ForceMin:Integer;
 KeepUnref,WarnExit0:Boolean;

 { Etat de l'ecriture }
 UseObjStm,UseXrefStm:Boolean;
 NObj:Longint;             { nombre d'objets conserves }
 NextStm:Longint;
 XE:TBuf;                  { entrees xref : 12 octets par objet }
 OSBody,OSHdr,OSNums,OSAll,WRaw,W1,W2,W3,TB,OB:TBuf;
 OSCnt:Longint;
 { donnees du flux courant }
 StrChanged,OutFlate:Boolean;
 OutFirst:Integer;
 SLen:Longint;
 XSize,XW2,XW3,XLen:Longint;
 XFlate:Boolean;

{ ------------------------------------------------------------------ }
{ Premiere passe : collecte des references de chaque objet            }
{ ------------------------------------------------------------------ }

Function PassA:Boolean;
Var N,P,Q,Start:Longint;R:PObjRec;IsStm:Boolean;
Begin
 PassA:=True;
 BufClear(Refs);
 ExtraKind:=0;
 { trailer }
 R:=GetRec(0);
 R^.RefStart:=0;
 If TrailerPos>=0 Then Begin
  SBuf:=NIL;
  WMode:=1;TopSkip:=TrailerSkip;
  Q:=TrailerPos;
  WalkValue(Q,0);
  TopSkip:='';WMode:=0;
 End
  Else
 If SynthRoot>0 Then BufPutL(Refs,SynthRoot);
 R:=GetRec(0);
 R^.RefCnt:=Refs.Len div 4;
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If R^.Kind<>0 Then Begin
   If Not OpenObject(N,P)Then Begin
    SBuf:=NIL;
    If Not Reconstructed Then Begin PassA:=False;Exit;End;
    R^.Kind:=0;
    Warn('objet '+IStr(N)+' illisible, ignore.');
   End
    Else
   Begin
    Start:=Refs.Len div 4;
    IsStm:=False;
    If(SB(P)=60)and(SB(P+1)=60)Then Begin
     WMode:=0;Q:=P;
     WalkValue(Q,1);
     SkipWS(Q);
     If(R^.Kind=1)and MatchKW(Q,'stream')Then IsStm:=True;
    End;
    If IsStm Then R^.Flags:=R^.Flags or FlStream
             Else R^.Flags:=R^.Flags and Not FlStream;
    WMode:=1;Q:=P;
    If IsStm Then TopSkip:='/Length/';
    WalkValue(Q,0);
    TopSkip:='';WMode:=0;
    SBuf:=NIL;
    R^.RefStart:=Start;
    R^.RefCnt:=Refs.Len div 4-Start;
   End;
  End;
 End;
 SBuf:=NIL;
End;

Function ComputeReach:Boolean;
Var Q:TBuf;Head,I,N,T:Longint;R,R0:PObjRec;Missing:Longint;
Begin
 BufInit(Q);
 Missing:=0;
 R0:=GetRec(0);
 For I:=0 to R0^.RefCnt-1 do Begin
  N:=BufGetL(Refs,(R0^.RefStart+I)*4);
  If N<0 Then Inc(Missing)
   Else
  Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)=0)Then Begin
    R^.Flags:=R^.Flags or FlReach;
    BufPutL(Q,N);
   End;
  End;
 End;
 If KeepUnref Then
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)=0)Then Begin
    R^.Flags:=R^.Flags or FlReach;
    BufPutL(Q,N);
   End;
  End;
 Head:=0;
 While Head*4<Q.Len Do Begin
  N:=BufGetL(Q,Head*4);Inc(Head);
  R:=PeekRec(N);
  For I:=0 to R^.RefCnt-1 do Begin
   T:=BufGetL(Refs,(R^.RefStart+I)*4);
   If T<0 Then Inc(Missing)
    Else
   Begin
    R0:=PeekRec(T);
    If(R0^.Kind<>0)and((R0^.Flags and FlReach)=0)Then Begin
     R0^.Flags:=R0^.Flags or FlReach;
     BufPutL(Q,T);
    End;
   End;
  End;
 End;
 BufFree(Q);
 NObj:=0;
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)Then Begin
   Inc(NObj);
   R^.NewNum:=NObj;
  End;
 End;
 ComputeReach:=(Missing=0)or Reconstructed;
End;

{ ------------------------------------------------------------------ }
{ Ecriture                                                            }
{ ------------------------------------------------------------------ }

Procedure XSet(Num,Typ,F2,F3:Longint);Begin
 BufSet(XE,Num*12,Typ);
 BufSet(XE,Num*12+1,0);
 BufSet(XE,Num*12+2,0);
 BufSet(XE,Num*12+3,0);
 BufSet(XE,Num*12+4,F2 and 255);BufSet(XE,Num*12+5,(F2 shr 8)and 255);
 BufSet(XE,Num*12+6,(F2 shr 16)and 255);BufSet(XE,Num*12+7,(F2 shr 24)and 255);
 BufSet(XE,Num*12+8,F3 and 255);BufSet(XE,Num*12+9,(F3 shr 8)and 255);
 BufSet(XE,Num*12+10,(F3 shr 16)and 255);BufSet(XE,Num*12+11,(F3 shr 24)and 255);
End;

Procedure EmitStreamExtra;
Var I:Integer;Total:Integer;AnyParm:Boolean;Q:Longint;
Begin
 If StrChanged Then Begin
  Total:=0;
  If OutFlate Then Inc(Total);
  If OutFirst<=NF Then Inc(Total,NF-OutFirst+1);
  If Total>0 Then Begin
   PutS(' /Filter ');
   If Total=1 Then Begin
    If OutFlate Then PutS('/FlateDecode') Else PutS('/'+FName[OutFirst]);
   End
    Else
   Begin
    PutS('[');
    If OutFlate Then PutS(' /FlateDecode');
    For I:=OutFirst to NF do PutS(' /'+FName[I]);
    PutS(' ]');
   End;
   AnyParm:=False;
   For I:=OutFirst to NF do If FParm[I]>=0 Then AnyParm:=True;
   If AnyParm Then Begin
    PutS(' /DecodeParms ');
    If(Total=1)and Not OutFlate Then Begin
     Q:=FParm[OutFirst];
     WalkValue(Q,1);
    End
     Else
    Begin
     PutS('[');
     If OutFlate Then PutS(' null');
     For I:=OutFirst to NF do Begin
      PutC(32);
      If FParm[I]>=0 Then Begin
       Q:=FParm[I];
       WalkValue(Q,1);
      End
       Else
      PutS('null');
     End;
     PutS(' ]');
    End;
   End;
  End;
 End;
 PutS(' /Length '+IStr(SLen));
End;

Procedure EmitXrefExtra;Begin
 PutS(' /Type /XRef /Size '+IStr(XSize)+' /W [ 1 '+IStr(XW2)+' '+IStr(XW3)+' ]');
 If XFlate Then PutS(' /Filter /FlateDecode /DecodeParms << /Columns '+IStr(1+XW2+XW3)+' /Predictor 12 >>');
 PutS(' /Length '+IStr(XLen));
End;

Procedure EmitExtra;Begin
 Case ExtraKind of
  1:EmitStreamExtra;
  2:EmitXrefExtra;
  3:PutS(' /Size '+IStr(XSize));
 End;
End;

{ Ecrit dans TB le dictionnaire du trailer (Kind : 2=flux xref, 3=trailer classique) }
Procedure EmitTrailer(Kind:Integer);
Var Q:Longint;
Begin
 BufClear(TB);
 EmBuf:=@TB;SBuf:=NIL;
 WMode:=2;ExtraKind:=Kind;TopSkip:=TrailerSkip;
 If TrailerPos>=0 Then Begin
  Q:=TrailerPos;
  WalkValue(Q,0);
 End
  Else
 Begin
  PutS('<<');
  If SynthRoot>0 Then PutS(' /Root '+IStr(MapRef(SynthRoot))+' 0 R');
  EmitExtra;
  PutS(' >>');
 End;
 WMode:=0;ExtraKind:=0;TopSkip:='';
End;

Procedure FlushObjStm;
Var StmN,First,I:Longint;Data:PBuf;Fl:Boolean;
Begin
 If OSCnt=0 Then Exit;
 StmN:=NextStm;Inc(NextStm);
 BufPutStr(OSHdr,#10);
 First:=OSHdr.Len;
 BufClear(OSAll);
 BufAppend(OSAll,OSHdr,0,OSHdr.Len);
 BufAppend(OSAll,OSBody,0,OSBody.Len);
 Data:=@OSAll;Fl:=False;
 If CompressOn Then Begin
  BufClear(W3);
  DeflateBuf(OSAll,W3,Level);
  If W3.Len<OSAll.Len Then Begin Data:=@W3;Fl:=True;End;
 End;
 XSet(StmN,1,OutPos,0);
 OutStr(IStr(StmN)+' 0 obj'#10'<< /Type /ObjStm /N '+IStr(OSCnt)+' /First '+IStr(First));
 If Fl Then OutStr(' /Filter /FlateDecode');
 OutStr(' /Length '+IStr(Data^.Len)+' >>'#10'stream'#10);
 OutBuffer(Data^,0,Data^.Len);
 OutStr(#10'endstream'#10'endobj'#10);
 For I:=0 to OSCnt-1 do XSet(BufGetL(OSNums,I*4),2,StmN,I);
 BufClear(OSBody);BufClear(OSHdr);BufClear(OSNums);
 OSCnt:=0;
End;

Procedure AddToObjStm(N:Longint;R:PObjRec);
Var P,Off:Longint;Opened:Boolean;
Begin
 EmBuf:=@OSBody;
 Off:=OSBody.Len;
 Opened:=OpenObject(N,P);
 WMode:=2;ExtraKind:=0;TopSkip:='';
 If Opened Then WalkValue(P,0)
           Else PutS('null');
 WMode:=0;SBuf:=NIL;
 BufPut(OSBody,10);
 BufPutStr(OSHdr,IStr(R^.NewNum)+' '+IStr(Off)+' ');
 BufPutL(OSNums,R^.NewNum);
 Inc(OSCnt);
 If OSCnt>=PerStm Then FlushObjStm;
End;

{ Decide du traitement des donnees du flux }
Procedure ChooseStreamData(Var Raw:TBuf;Var Data:PBuf);
Var K,KMax,I:Integer;Src,Tgt:PBuf;Flip,Ok,AllFlate:Boolean;
Begin
 Data:=@Raw;
 StrChanged:=False;OutFlate:=False;OutFirst:=1;
 { recompression directe d'un flux Flate simple }
 If CompressOn and RecompFlate and FOk and(NF=1)and(FName[1]='FlateDecode')Then Begin
  BufClear(W1);BufClear(W2);
  If InflateBuf(Raw,0,W1,True)Then Begin
   DeflateBuf(W1,W2,Level);
   If W2.Len<Raw.Len Then Data:=@W2;
  End;
  Exit;
 End;
 K:=0;Src:=@Raw;
 If DecodeOn and FOk and(NF>0)Then Begin
  KMax:=0;
  While(KMax<NF)and CanDecode(KMax+1,Not CompressOn)Do Inc(KMax);
  If CompressOn Then Begin
   AllFlate:=True;
   For I:=1 to KMax do If FName[I]<>'FlateDecode' Then AllFlate:=False;
   If AllFlate Then KMax:=0;
  End;
  Flip:=False;Ok:=True;
  While Ok and(K<KMax)Do Begin
   If Flip Then Tgt:=@W2 Else Tgt:=@W1;
   Flip:=Not Flip;
   Ok:=DecodeOne(K+1,Src^,Tgt^,Not CompressOn);
   If Ok Then Begin Src:=Tgt;Inc(K);End;
  End;
  If Not Ok Then Begin
   Warn('flux illisible (decodage impossible), conserve tel quel.');
   Data:=@Raw;Exit;
  End;
 End;
 If CompressOn Then Begin
  If FOk and(K=NF)Then Begin
   BufClear(W3);
   DeflateBuf(Src^,W3,Level);
   If W3.Len<Raw.Len Then Begin
    Data:=@W3;StrChanged:=True;OutFlate:=True;OutFirst:=NF+1;
   End;
  End
   Else
  If(K>0)and(Src^.Len<=Raw.Len)Then Begin
   Data:=Src;StrChanged:=True;OutFirst:=K+1;
  End;
 End
  Else
 If K>0 Then Begin
  Data:=Src;StrChanged:=True;OutFirst:=K+1;
 End;
End;

Procedure WriteStreamObject(R:PObjRec;Var P:Longint);
Var Data:PBuf;Q:Longint;
Begin
 { P : debut du dictionnaire }
 If Not GetRaw(P,WRaw)Then Begin
  Warn('flux invalide dans l''objet '+IStr(R^.NewNum)+'.');
  BufClear(WRaw);
 End;
 AnalyzeFilters(P);
 ChooseStreamData(WRaw,Data);
 SLen:=Data^.Len;
 BufClear(OB);
 EmBuf:=@OB;SBuf:=NIL;
 WMode:=2;ExtraKind:=1;
 If StrChanged Then TopSkip:='/Length/Filter/DecodeParms/DP/'
               Else TopSkip:='/Length/';
 Q:=P;
 WalkValue(Q,0);
 WMode:=0;ExtraKind:=0;TopSkip:='';
 OutBuffer(OB,0,OB.Len);
 OutStr(#10'stream'#10);
 OutBuffer(Data^,0,Data^.Len);
 OutStr(#10'endstream'#10);
End;

Procedure WriteNormalObject(N:Longint;R:PObjRec);
Var P,Q:Longint;
Begin
 XSet(R^.NewNum,1,OutPos,0);
 OutStr(IStr(R^.NewNum)+' 0 obj'#10);
 If OpenObject(N,P)Then Begin
  If(R^.Flags and FlStream)<>0 Then WriteStreamObject(R,P)
   Else
  Begin
   BufClear(OB);
   EmBuf:=@OB;
   WMode:=2;ExtraKind:=0;TopSkip:='';
   Q:=P;
   WalkValue(Q,0);
   WMode:=0;
   OutBuffer(OB,0,OB.Len);
   SBuf:=NIL;
  End;
 End
  Else
 OutStr('null');
 OutStr(#10'endobj'#10);
End;

Function BytesFor(V:Longint):Longint;Begin
 If V<256 Then BytesFor:=1
 Else If V<65536 Then BytesFor:=2
 Else If V<16777216 Then BytesFor:=3
 Else BytesFor:=4;
End;

Procedure PutBE(Var B:TBuf;V,W:Longint);
Var I:Longint;
Begin
 For I:=W-1 downto 0 do BufPut(B,(V shr(I*8))and 255);
End;

Procedure WriteXref;
Var I,N,Typ,F2,F3,MaxF2,MaxF3,XrefNum,XrefPos,RowLen,Row0:Longint;XPlain,XOut:PBuf;B:Byte;
Begin
 If Not UseXrefStm Then Begin
  XSize:=NextStm;
  XrefPos:=OutPos;
  OutStr('xref'#10'0 '+IStr(XSize)+#10);
  OutStr('0000000000 65535 f '#10);
  For N:=1 to XSize-1 do Begin
   F2:=BufGetL(XE,N*12+4);
   OutStr(PadZero(F2,10)+' 00000 n '#10);
  End;
  EmitTrailer(3);
  OutStr('trailer'#10);
  OutBuffer(TB,0,TB.Len);
  OutStr(#10'startxref'#10+IStr(XrefPos)+#10'%%EOF'#10);
  Exit;
 End;
 XrefNum:=NextStm;
 XSize:=XrefNum+1;
 XrefPos:=OutPos;
 XSet(XrefNum,1,XrefPos,0);
 MaxF2:=XrefPos;MaxF3:=0;
 For N:=1 to XSize-1 do Begin
  F2:=BufGetL(XE,N*12+4);F3:=BufGetL(XE,N*12+8);
  If F2>MaxF2 Then MaxF2:=F2;
  If F3>MaxF3 Then MaxF3:=F3;
 End;
 XW2:=BytesFor(MaxF2);XW3:=BytesFor(MaxF3);
 RowLen:=1+XW2+XW3;
 BufClear(W1);
 For N:=0 to XSize-1 do Begin
  If N=0 Then Begin Typ:=0;F2:=0;F3:=0;End
   Else
  Begin
   Typ:=BufGet(XE,N*12);F2:=BufGetL(XE,N*12+4);F3:=BufGetL(XE,N*12+8);
  End;
  BufPut(W1,Typ);PutBE(W1,F2,XW2);PutBE(W1,F3,XW3);
 End;
 XPlain:=@W1;XFlate:=False;
 If CompressOn Then Begin
  { predicteur PNG "Up" }
  BufClear(W2);
  For N:=0 to XSize-1 do Begin
   BufPut(W2,2);
   For I:=0 to RowLen-1 do Begin
    B:=BufGet(W1,N*RowLen+I);
    If N>0 Then B:=(B-BufGet(W1,(N-1)*RowLen+I))and 255;
    BufPut(W2,B);
   End;
  End;
  BufClear(W3);
  DeflateBuf(W2,W3,Level);
  XPlain:=@W3;XFlate:=True;
 End;
 XOut:=XPlain;
 XLen:=XOut^.Len;
 OutStr(IStr(XrefNum)+' 0 obj'#10);
 EmitTrailer(2);
 OutBuffer(TB,0,TB.Len);
 OutStr(#10'stream'#10);
 OutBuffer(XOut^,0,XOut^.Len);
 OutStr(#10'endstream'#10'endobj'#10);
 OutStr('startxref'#10+IStr(XrefPos)+#10'%%EOF'#10);
End;

Procedure WriteOutput;
Var N,I,NComp,NStm:Longint;R:PObjRec;Maj,Min:Integer;
Begin
 { version }
 Maj:=VerMajor;Min:=VerMinor;
 If UseXrefStm Then
  If(Maj<1)or((Maj=1)and(Min<5))Then Begin Maj:=1;Min:=5;End;
 If(MinVerMaj>Maj)or((MinVerMaj=Maj)and(MinVerMin>Min))Then Begin Maj:=MinVerMaj;Min:=MinVerMin;End;
 If ForceMaj>0 Then Begin Maj:=ForceMaj;Min:=ForceMin;End;
 Assign(OutF,OutName);
 Rewrite(OutF,1);
 If IOResult<>0 Then Fatal('impossible de creer le fichier de sortie : '+OutName);
 OutOpen:=True;
 GetMem(OBytes,SizeOf(TBytes));
 OutFill:=0;OutPos:=0;
 OutStr('%PDF-'+IStr(Maj)+'.'+IStr(Min)+#10);
 OutStr('%'#191#247#162#254#10);
 { dimension de la table xref }
 NComp:=0;
 If UseObjStm Then
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and FlStream)=0)Then Inc(NComp);
  End;
 NStm:=(NComp+PerStm-1)div PerStm;
 BufClear(XE);
 BufEnsure(XE,(NObj+NStm+2)*12);
 For I:=0 to(NObj+NStm+2)*12-1 do BufPut(XE,0);
 NextStm:=NObj+1;
 OSCnt:=0;
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)Then Begin
   If UseObjStm and((R^.Flags and FlStream)=0)Then AddToObjStm(N,R)
                                               Else WriteNormalObject(N,R);
  End;
 End;
 FlushObjStm;
 WriteXref;
 OutFlush;
 Close(OutF);
 If IOResult<>0 Then Fatal('erreur a la fermeture du fichier de sortie.');
 OutOpen:=False;
End;

{ ------------------------------------------------------------------ }
{ Verification (--check) et nombre de pages                           }
{ ------------------------------------------------------------------ }

Procedure CheckStreams;
Var N:Longint;R:PObjRec;P:Longint;I:Integer;Src,Tgt:PBuf;Flip,Ok:Boolean;
Begin
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and FlStream)<>0)Then Begin
   If OpenObject(N,P)Then Begin
    If GetRaw(P,WRaw)Then Begin
     AnalyzeFilters(P);
     If FOk Then Begin
      Src:=@WRaw;Flip:=False;Ok:=True;
      I:=1;
      While Ok and(I<=NF)and CanDecode(I,True)Do Begin
       If Flip Then Tgt:=@W2 Else Tgt:=@W1;
       Flip:=Not Flip;
       Ok:=DecodeOne(I,Src^,Tgt^,True);
       Src:=Tgt;Inc(I);
      End;
      If Not Ok Then Warn('objet '+IStr(N)+' : erreur de decodage du flux.');
     End;
    End
     Else
    Warn('objet '+IStr(N)+' : flux invalide.');
   End;
  End;
 End;
 SBuf:=NIL;
End;

Function CountPages:Longint;
Var V,P,N1,A,C:Longint;
Begin
 CountPages:=-1;
 If TrailerPos>=0 Then V:=DictFind(TrailerPos,'Root') Else V:=-1;
 If V<0 Then Begin
  If SynthRoot>0 Then N1:=SynthRoot Else Exit;
 End
  Else
 If Not IsRefAt(V,N1,A)Then Exit;
 SBuf:=NIL;
 If Not OpenObject(N1,P)Then Exit;
 V:=DictFind(P,'Pages');
 If(V<0)or Not IsRefAt(V,N1,A)Then Begin SBuf:=NIL;Exit;End;
 SBuf:=NIL;
 If Not OpenObject(N1,P)Then Exit;
 V:=DictFind(P,'Count');
 If ReadDirectInt(V,C)Then CountPages:=C;
 SBuf:=NIL;
End;

{ ------------------------------------------------------------------ }
{ Programme principal                                                 }
{ ------------------------------------------------------------------ }

Procedure ShowHelp;Begin
 WriteLn('QPDF : Cette commande permet d''optimiser la structure interne d''un fichier PDF');
 WriteLn('       et de compresser ses flux de donnees sans perte (la resolution des');
 WriteLn('       images n''est jamais reduite).');
 WriteLn;
 WriteLn('Syntaxe : QPDF [options] entree.pdf sortie.pdf');
 WriteLn;
 WriteLn(' --stream-data=compress|preserve|uncompress');
 WriteLn('                          Traitement des flux (defaut : compress)');
 WriteLn(' --compress-streams=y|n   Compresse les flux (Flate)');
 WriteLn(' --decode-level=none|generalized|specialized|all');
 WriteLn('                          Filtres decodes avant recompression (defaut : generalized)');
 WriteLn(' --recompress-flate       Recompresse aussi les flux deja en Flate');
 WriteLn(' --compression-level=0..9 Niveau de compression Flate (defaut : 9)');
 WriteLn(' --object-streams=disable|preserve|generate');
 WriteLn('                          Gestion des flux d''objets (defaut : preserve)');
 WriteLn(' --preserve-unreferenced  Conserve les objets non references');
 WriteLn(' --min-version=x.y        Version minimale du PDF produit');
 WriteLn(' --force-version=x.y      Force la version du PDF produit');
 WriteLn(' --check                  Verifie la structure et les flux (aucune sortie)');
 WriteLn(' --show-npages            Affiche le nombre de pages');
 WriteLn(' --warning-exit-0         Code de retour 0 meme en cas d''avertissements');
 WriteLn(' --verbose                Affiche un resume des tailles');
 WriteLn(' --version                Affiche la version');
 WriteLn(' --help                   Affiche cette aide');
 WriteLn;
 WriteLn('Exemple :');
 WriteLn('  QPDF --stream-data=compress --object-streams=generate original.pdf compact.pdf');
 WriteLn;
 WriteLn('Limites : les fichiers chiffres, --linearize et --qdf ne sont pas supportes.');
End;

Procedure BadOpt(Const S:String);Begin
 ErrLn('QPDF : option non supportee ou invalide : '+S);
 ErrLn('Essayez QPDF --help pour obtenir de l''aide.');
 Halt(2);
End;

Function ParseVer(Const S:String;Var Maj,Min:Integer):Boolean;
Var P:Integer;
Begin
 ParseVer:=False;
 P:=Pos('.',S);
 If(P<2)or(P>=Length(S))Then Exit;
 If(Length(S)-P>2)or(P>3)Then Exit;
 Maj:=Ord(S[1])-48;
 Min:=Ord(S[P+1])-48;
 If(Maj<0)or(Maj>9)or(Min<0)or(Min>9)Then Exit;
 ParseVer:=True;
End;

Procedure ParseArgs;
Var I,P,NPos:Integer;S,Opt,OptVal:String;EndOpts:Boolean;V:Longint;Code:Integer;
Begin
 InName:='';OutName:='';NPos:=0;EndOpts:=False;
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  If(Not EndOpts)and(S='--')Then EndOpts:=True
   Else
  If(Not EndOpts)and((S='/?')or(S='-h')or(S='--help'))Then Begin
   ShowHelp;Halt(0);
  End
   Else
  If(Not EndOpts)and(Copy(S,1,2)='--')Then Begin
   P:=Pos('=',S);
   If P>0 Then Begin Opt:=Copy(S,3,P-3);OptVal:=Copy(S,P+1,255);End
          Else Begin Opt:=Copy(S,3,255);OptVal:='';End;
   If Opt='version' Then Begin
    WriteLn('QPDF version ',ProgVersion,' (clone Pascal de qpdf)');
    Halt(0);
   End
    Else
   If Opt='stream-data' Then Begin
    If OptVal='compress' Then Begin CompressOn:=True;DecodeOn:=True;End
     Else If OptVal='preserve' Then Begin CompressOn:=False;DecodeOn:=False;End
     Else If OptVal='uncompress' Then Begin CompressOn:=False;DecodeOn:=True;End
     Else BadOpt(S);
   End
    Else
   If Opt='compress-streams' Then Begin
    If OptVal='y' Then CompressOn:=True
     Else If OptVal='n' Then CompressOn:=False
     Else BadOpt(S);
   End
    Else
   If Opt='decode-level' Then Begin
    If OptVal='none' Then DecodeOn:=False
     Else If(OptVal='generalized')or(OptVal='specialized')or(OptVal='all')Then DecodeOn:=True
     Else BadOpt(S);
   End
    Else
   If Opt='recompress-flate' Then RecompFlate:=True
    Else
   If Opt='compression-level' Then Begin
    Val(OptVal,V,Code);
    If(Code<>0)or(V<0)or(V>9)Then BadOpt(S);
    Level:=V;
   End
    Else
   If Opt='object-streams' Then Begin
    If OptVal='disable' Then ObjMode:=0
     Else If OptVal='preserve' Then ObjMode:=1
     Else If OptVal='generate' Then ObjMode:=2
     Else BadOpt(S);
   End
    Else
   If Opt='preserve-unreferenced' Then KeepUnref:=True
    Else
   If Opt='min-version' Then Begin
    If Not ParseVer(OptVal,MinVerMaj,MinVerMin)Then BadOpt(S);
   End
    Else
   If Opt='force-version' Then Begin
    If Not ParseVer(OptVal,ForceMaj,ForceMin)Then BadOpt(S);
   End
    Else
   If Opt='check' Then CheckOnly:=True
    Else
   If Opt='show-npages' Then ShowNPages:=True
    Else
   If Opt='warning-exit-0' Then WarnExit0:=True
    Else
   If(Opt='verbose')or(Opt='no-original-object-ids')or(Opt='deterministic-id')or(Opt='static-id')Then Begin
    If Opt='verbose' Then Verbose:=True;
   End
    Else
   BadOpt(S);
  End
   Else
  Begin
   Inc(NPos);
   If NPos=1 Then InName:=S
    Else
   If NPos=2 Then OutName:=S
    Else
   BadOpt(S);
  End;
 End;
End;

Procedure Init;
Var I:Integer;
Begin
 Warnings:=0;Verbose:=False;WarnExit0:=False;
 OutOpen:=False;OutFill:=0;OutPos:=0;OBytes:=NIL;
 SBuf:=NIL;SCacheStart:=0;SCacheLen:=0;Bias:=0;
 VerMajor:=1;VerMinor:=4;
 GetMem(ObjDir,SizeOf(TObjDir));
 FillChar(ObjDir^,SizeOf(TObjDir),0);
 GetMem(SCache,SizeOf(TBytes));
 FillChar(NullRec,SizeOf(NullRec),0);
 HighObj:=0;TrailerPos:=-1;SynthRoot:=0;SrcXrefStm:=False;Reconstructed:=False;
 SCNext:=0;OverrideFree:=False;
 For I:=0 to CacheN-1 do Begin
  SC[I].Num:=-1;SC[I].Count:=0;SC[I].First:=0;
  BufInit(SC[I].Data);BufInit(SC[I].Hdr);
 End;
 BufInit(Refs);BufInit(XRaw);BufInit(XDec);BufInit(RawX);BufInit(DecA);BufInit(DecB);
 BufInit(PredTmp);BufInit(XE);BufInit(OSBody);BufInit(OSHdr);BufInit(OSNums);BufInit(OSAll);
 BufInit(WRaw);BufInit(W1);BufInit(W2);BufInit(W3);BufInit(TB);BufInit(OB);
 WMode:=0;TopSkip:='';ExtraKind:=0;EmBuf:=NIL;
 DInit:=False;DForceStore:=False;
 CompressOn:=True;DecodeOn:=True;RecompFlate:=False;ObjMode:=1;Level:=9;
 CheckOnly:=False;ShowNPages:=False;KeepUnref:=False;
 MinVerMaj:=0;MinVerMin:=0;ForceMaj:=0;ForceMin:=0;
 StrChanged:=False;OutFlate:=False;OutFirst:=1;SLen:=0;
End;

Procedure OpenSource;
Var P:Longint;Found:Boolean;
Begin
 Assign(SF,InName);
 FileMode:=0;
 Reset(SF,1);
 If IOResult<>0 Then Fatal('impossible d''ouvrir '+InName+' : fichier introuvable ou illisible.');
 FileMode:=2;
 SFSize:=FileSize(SF);
 If SFSize<16 Then Fatal(InName+' : ce n''est pas un fichier PDF.');
 SBuf:=NIL;
 Found:=False;P:=0;
 While(P<1024)and(P<SFSize-8)and Not Found Do Begin
  If(SB(P)=37)and MatchStr(P,'%PDF-')Then Found:=True
                                      Else Inc(P);
 End;
 If Found Then Begin
  Bias:=P;
  VerMajor:=SB(P+5)-48;
  If SB(P+6)=46 Then VerMinor:=SB(P+7)-48;
  If(VerMajor<0)or(VerMajor>9)Then VerMajor:=1;
  If(VerMinor<0)or(VerMinor>9)Then VerMinor:=4;
 End
  Else
 Warn('en-tete %PDF- introuvable.');
End;

Procedure CheckEncrypt;Begin
 If(TrailerPos>=0)and(DictFind(TrailerPos,'Encrypt')>=0)Then
  Fatal(InName+' : fichier chiffre (Encrypt) : non supporte par cette version.');
End;

Var
 Sx,N,SizeIn,SizeOut,NPages:Longint;
 Ok,SrcHasStm:Boolean;
 R:PObjRec;
 F2:File;

BEGIN
 Init;
 If ParamCount=0 Then Begin
  ShowHelp;
  Halt(0);
 End;
 ParseArgs;
 If InName='' Then Begin
  ErrLn('QPDF : aucun fichier d''entree. Essayez QPDF --help.');
  Halt(2);
 End;
 If(Not CheckOnly)and(Not ShowNPages)and(OutName='')Then Begin
  ErrLn('QPDF : aucun fichier de sortie. Essayez QPDF --help.');
  Halt(2);
 End;
 If(OutName<>'')and(OutName=InName)Then Begin
  ErrLn('QPDF : le fichier de sortie doit etre different du fichier d''entree.');
  Halt(2);
 End;
 OpenSource;
 { structure du document }
 Ok:=False;
 Sx:=FindStartXref;
 If Sx>=0 Then Ok:=ReadXrefChain(Sx);
 If Ok and(TrailerPos<0)Then Ok:=False;
 If Not Ok Then Reconstruct;
 CheckEncrypt;
 If Not(PassA and ComputeReach)Then Begin
  Reconstruct;
  CheckEncrypt;
  If Not(PassA and ComputeReach)Then Fatal('structure du document irrecuperable.');
 End;
 If NObj=0 Then Fatal('aucun objet atteignable depuis la racine du document.');
 If ShowNPages Then Begin
  NPages:=CountPages;
  If NPages<0 Then Fatal('impossible de determiner le nombre de pages.');
  WriteLn(NPages);
 End
  Else
 If CheckOnly Then Begin
  CheckStreams;
  If Warnings=0 Then WriteLn('Aucune erreur de syntaxe ou d''encodage de flux n''a ete trouvee.')
  Else WriteLn('Des problemes ont ete trouves (',Warnings,' avertissement(s)).');
 End
  Else
 Begin
  SrcHasStm:=False;
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind=2)and((R^.Flags and FlReach)<>0)Then SrcHasStm:=True;
  End;
  Case ObjMode of
   0:Begin UseObjStm:=False;UseXrefStm:=False;End;
   1:Begin UseObjStm:=SrcHasStm;UseXrefStm:=SrcHasStm or SrcXrefStm;End;
   Else Begin UseObjStm:=True;UseXrefStm:=True;End;
  End;
  WriteOutput;
  If Verbose Then Begin
   SizeIn:=SFSize;
   Assign(F2,OutName);FileMode:=0;Reset(F2,1);
   If IOResult=0 Then Begin
    SizeOut:=FileSize(F2);Close(F2);
    WriteLn('Taille d''origine : ',SizeIn,' octets');
    WriteLn('Taille finale    : ',SizeOut,' octets');
    If SizeIn>=100 Then WriteLn('Gain             : ',(SizeIn-SizeOut)div(SizeIn div 100),' %');
    WriteLn('Objets conserves : ',NObj);
   End;
   FileMode:=2;
  End;
 End;
 Close(SF);
 If(Warnings>0)and Not WarnExit0 Then Halt(3);
END.
