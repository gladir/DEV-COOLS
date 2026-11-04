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
 FlPageLeaf=8;  { feuille de l'arbre des pages }
 FlSeen=16;     { deja visite (arbre des pages) }
 MaxDocs=16;

 MaxFilt=8;
 CacheN=4;
 PerStm=100;  { nombre maximal d'objets par flux d'objets }
 InflateLimit=100000000;
 OutBufSize=32768;

 TrailerSkip='/Prev/XRefStm/Size/Encrypt/Length/Filter/DecodeParms/'+
  'DP/W/Index/Type/';

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
  Kind:Byte;      { 0=inconnu/libre, 1=dans le fichier, 2=dans un flux d'objets
    }
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

Type
 TCacheArr=Array[0..CacheN-1]of TStmCache;

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
 SC:TCacheArr;
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
  If(IOResult<>0)or(Got<>OutFill)Then Fatal('Erreur d''ecriture sur le fichier'+
    ' de sortie.');
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
 IsDelim:=(C=40)or(C=41)or(C=60)or(C=62)or(C=91)or(C=93)or(C=123)or(C=125)
   or(C=47)or(C=37);
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
 ValidKeyword:=((Q-P=4)and(MatchStr(P,'true')or
   MatchStr(P,'null')))or((Q-P=5)and MatchStr(P,'false'));
End;

Procedure WalkValue(Var P:Longint;Depth:Integer);
Var
  C,D:Integer;Q,Q2,N1:Longint;Key:String;Done,DigitsOnly:Boolean;
    SaveMode:Integer;Lv,M:Longint;
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
 LBase:Array[0..28]of
   Word=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,
     163,195,227,258);
 LExt:Array[0..28]of
   Byte=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0);
 DBase:Array[0..29]of
   Word=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,
     2049,3073,4097,6145,8193,12289,16385,24577);
 DExt:Array[0..29]of
   Byte=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13);
 CLOrder:Array[0..18]of Byte=(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);
 BitMask:Array[0..16]of
   Longint=(0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535);

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
Var
  NLen,NDist,NCode,I,Sym,Rep:Integer;Lens:TLen320;PrevL:Byte;CLH:THuff;
    Lv:Longint;
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

Function InflateBuf(Var Src:TBuf;From:Longint;Var
  Dst:TBuf;Zlib:Boolean):Boolean;
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
 V:=(Longint(BufGet(DSrc^,Ps))shl 16)or(Longint(BufGet(DSrc^,Ps+1))shl 8)or
   BufGet(DSrc^,Ps+2);
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
   If(BufGet(DSrc^,Cand+Best)=BufGet(DSrc^,Ps+Best))and(BufGet(DSrc^,Cand)
     =BufGet(DSrc^,Ps))Then
     Begin
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

{ Ecrit les octets d'un groupe ASCII85 (N chiffres, N>=2) sans depasser 32 bits
  }
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
 GetMem(Pre,SizeOf(TLzwPre));GetMem(Suf,SizeOf(TLzwSuf));GetMem(Stk,
   SizeOf(TLzwStk));
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
 FreeMem(Pre,SizeOf(TLzwPre));FreeMem(Suf,SizeOf(TLzwSuf));FreeMem(Stk,
   SizeOf(TLzwStk));
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
 If Ok and PredToo
   and(FPred[I]>1)and((FName[I]='FlateDecode')or(FName[I]='LZWDecode'))Then
     Begin
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
 If Not((N='FlateDecode')or(N='LZWDecode')or(N='ASCII85Decode')
   or(N='ASCIIHexDecode')or(N='RunLengthDecode'))Then
   Exit;
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
   If(Not ReadInt(Q2,Start))or(Not ReadInt(Q2,Cnt))Then Begin
     Start:=0;Cnt:=0;Q2:=-2;End;
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
Var
  P,Q,Q2,N,G,DP,DS,DE,V,K,Nn:Longint;C:Integer;R,R2:PObjRec;T:String;S:Integer;
Begin
 Warn('structure xref invalide ou incomplete : reconstruction de la table des'+
   ' objets.');
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
        If DictFind(DP,'Root')>=0 Then Begin
          TrailerPos:=DP;SrcXrefStm:=True;End;
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
  If SynthRoot=0 Then Fatal('impossible de trouver la racine (Root) du'+
    ' document.');
 End;
End;

{ ------------------------------------------------------------------ }
{ Recompression JPEG (DCTDecode) dans le domaine des coefficients DCT  }
{ Seuls les JPEG de base (SOF0/SOF1, 8 bits, un seul balayage) sont    }
{ traites. Les tables de Huffman sont optimisees (sans perte) ; avec   }
{ --jpeg-requant les pas de quantification sont en plus agrandis.      }
{ ------------------------------------------------------------------ }

Type
 TCoef=Array[0..63]of Longint;

Var
 JpegOn:Boolean;
 JpegPct:Longint;          { 100 = sans perte, > 100 = pas de quantif. agrandis }
 JIn,JOut:PBuf;
 JPos,JEnd,JBB,JBC:Longint;
 JBad,JTally:Boolean;
 JQ,JQN:Array[0..3,0..63]of Longint;
 JQDef:Array[0..3]of Boolean;
 JHB:Array[0..7,1..16]of Byte;
 JHV:Array[0..7,0..255]of Byte;
 JHDef:Array[0..7]of Boolean;
 JHMax,JHMin,JHPtr:Array[0..7,0..16]of Longint;
 JNC:Longint;
 JCid,JCH,JCV,JCTq,JCTd,JCTa:Array[1..4]of Longint;
 JImgW,JImgH,JRst,JHMaxF,JVMaxF:Longint;
 JApp,JSof:TBuf;
 JFreq:Array[0..3,0..256]of Longint;
 JEBits:Array[0..3,1..16]of Byte;
 JEVal:Array[0..3,0..255]of Byte;
 JECode,JESize:Array[0..3,0..255]of Longint;
 JENum:Array[0..3]of Longint;
 JOB,JOC:Longint;
 JPred:Array[1..4]of Longint;
 JTotal,JDone:Longint;     { images JPEG a traiter / traitees (progression) }

{ Progression : (n/total) - pct % ; ecrite sur la sortie d'erreur }
Procedure JProgress;
Var Pct:Longint;
Begin
 If JTotal<=0 Then Exit;
 Pct:=(JDone*100)div JTotal;
 {$IFDEF FPC}
 Write(StdErr,#13'Images JPEG : (',JDone,'/',JTotal,') - ',Pct,'%   ');
 {$ELSE}
 Write(#13'Images JPEG : (',JDone,'/',JTotal,') - ',Pct,'%   ');
 {$ENDIF}
End;

Function JByte(P:Longint):Longint;Begin
 If(P<0)or(P>=JEnd)Then JByte:=0 Else JByte:=BufGet(JIn^,P);
End;

Function JWord(P:Longint):Longint;Begin
 JWord:=JByte(P)*256+JByte(P+1);
End;

{ Lecture des bits de donnees entropiques }
Function JGetBits(N:Longint):Longint;
Var B:Longint;
Begin
 While JBC<N Do Begin
  If JPos>=JEnd Then Begin JBad:=True;B:=0;End
   Else
  Begin
   B:=BufGet(JIn^,JPos);
   If B=255 Then Begin
    If JByte(JPos+1)=0 Then Inc(JPos,2)
     Else B:=0;                { marqueur : on fournit des zeros }
   End
    Else
   Inc(JPos);
  End;
  JBB:=((JBB shl 8)or B)and $FFFFFF;
  Inc(JBC,8);
 End;
 JGetBits:=(JBB shr(JBC-N))and((Longint(1)shl N)-1);
 Dec(JBC,N);
End;

Function JDecodeSym(T:Longint):Longint;
Var L:Longint;Code:Longint;Found:Boolean;
Begin
 Code:=0;Found:=False;JDecodeSym:=0;L:=1;
 While(L<=16)and Not Found Do Begin
  Code:=(Code shl 1)or JGetBits(1);
  If(JHMax[T,L]>=0)and(Code<=JHMax[T,L])and(Code>=JHMin[T,L])Then Begin
   JDecodeSym:=JHV[T,JHPtr[T,L]+Code-JHMin[T,L]];
   Found:=True;
  End;
  Inc(L);
 End;
 If Not Found Then JBad:=True;
End;

Procedure JBuildDec(T:Longint);
Var L:Longint;Code,K:Longint;
Begin
 Code:=0;K:=0;
 For L:=1 to 16 Do Begin
  JHPtr[T,L]:=K;JHMin[T,L]:=Code;
  Inc(Code,JHB[T,L]);Inc(K,JHB[T,L]);
  If JHB[T,L]>0 Then JHMax[T,L]:=Code-1 Else JHMax[T,L]:=-1;
  Code:=Code shl 1;
 End;
End;

{ Analyse des marqueurs jusqu'au debut du balayage }
Function JParse(Var Src:TBuf):Boolean;
Var P,L,Mk,End0,I,K,T,Tq,Tc,Th,N,Sum,Id,Hv:Longint;
    Got,Done,Bad:Boolean;
Begin
 JParse:=False;
 JIn:=@Src;JEnd:=Src.Len;
 BufClear(JApp);BufClear(JSof);
 For I:=0 to 3 Do JQDef[I]:=False;
 For I:=0 to 7 Do JHDef[I]:=False;
 JNC:=0;JRst:=0;Got:=False;Done:=False;Bad:=False;
 If(JByte(0)<>255)or(JByte(1)<>$D8)Then Exit;
 P:=2;
 While(P+4<=JEnd)and Not Done and Not Bad Do Begin
  Mk:=JByte(P+1);
  L:=JWord(P+2);
  If JByte(P)<>255 Then Bad:=True
   Else
  If Mk=255 Then Inc(P)
   Else
  If(L<2)or(P+2+L>JEnd)Then Bad:=True
   Else
  Begin
   End0:=P+2+L;
   If(Mk=$C0)or(Mk=$C1)Then Begin
    If Got or(JByte(P+4)<>8)Then Bad:=True
     Else
    Begin
     JImgH:=JWord(P+5);JImgW:=JWord(P+7);
     JNC:=JByte(P+9);
     If(JImgH<1)or(JImgW<1)or(JNC<1)or(JNC>4)or(L<>8+3*JNC)Then Bad:=True
      Else
     Begin
      JHMaxF:=1;JVMaxF:=1;
      For I:=1 to JNC Do Begin
       Id:=JByte(P+10+(I-1)*3);Hv:=JByte(P+11+(I-1)*3);
       JCid[I]:=Id;JCH[I]:=Hv shr 4;JCV[I]:=Hv and 15;
       JCTq[I]:=JByte(P+12+(I-1)*3);
       If(JCH[I]<1)or(JCH[I]>4)or(JCV[I]<1)or(JCV[I]>4)or(JCTq[I]>3)Then
         Bad:=True;
       If JCH[I]>JHMaxF Then JHMaxF:=JCH[I];
       If JCV[I]>JVMaxF Then JVMaxF:=JCV[I];
      End;
      BufAppend(JSof,Src,P,End0-P);
      Got:=True;
     End;
    End;
   End
    Else
   If(Mk=$C2)or(Mk=$C3)or((Mk>=$C5)and(Mk<=$CF)and(Mk<>$C8)and(Mk<>$CC))Then
     Bad:=True
    Else
   If Mk=$DB Then Begin
    I:=P+4;
    While(I<End0)and Not Bad Do Begin
     Tq:=JByte(I)and 15;
     If((JByte(I)shr 4)<>0)or(Tq>3)or(I+65>End0)Then Bad:=True
      Else
     Begin
      For K:=0 to 63 Do JQ[Tq,K]:=JByte(I+1+K);
      JQDef[Tq]:=True;
      Inc(I,65);
     End;
    End;
   End
    Else
   If Mk=$C4 Then Begin
    I:=P+4;
    While(I<End0)and Not Bad Do Begin
     Tc:=JByte(I)shr 4;Th:=JByte(I)and 15;
     If(Tc>1)or(Th>3)Then Bad:=True
      Else
     Begin
      T:=Tc*4+Th;Sum:=0;
      For K:=1 to 16 Do Begin JHB[T,K]:=JByte(I+K);Inc(Sum,JHB[T,K]);End;
      If(Sum>256)or(I+17+Sum>End0)Then Bad:=True
       Else
      Begin
       For K:=0 to Sum-1 Do JHV[T,K]:=JByte(I+17+K);
       JHDef[T]:=True;JBuildDec(T);
       Inc(I,17+Sum);
      End;
     End;
    End;
   End
    Else
   If Mk=$DD Then JRst:=JWord(P+4)
    Else
   If(Mk>=$E0)and(Mk<=$EF)Then BufAppend(JApp,Src,P,End0-P)
    Else
   If Mk=$DA Then Begin
    If Not Got Then Bad:=True
     Else
    Begin
     N:=JByte(P+4);
     If(N<>JNC)or(L<>6+2*N)Then Bad:=True
      Else
     Begin
      For I:=1 to N Do Begin
       Id:=JByte(P+5+(I-1)*2);
       If Id<>JCid[I]Then Bad:=True;
       JCTd[I]:=JByte(P+6+(I-1)*2)shr 4;
       JCTa[I]:=JByte(P+6+(I-1)*2)and 15;
       If(JCTd[I]>3)or(JCTa[I]>3)Then Bad:=True
        Else
       If Not(JHDef[JCTd[I]]and JHDef[4+JCTa[I]]and JQDef[JCTq[I]])Then
         Bad:=True;
      End;
      If(JByte(P+5+2*N)<>0)or(JByte(P+6+2*N)<>63)or(JByte(P+7+2*N)<>0)Then
        Bad:=True;
      If Not Bad Then Begin JPos:=End0;Done:=True;End;
     End;
    End;
   End
    Else
   If Mk=$D9 Then Bad:=True;
   P:=End0;
  End;
 End;
 JParse:=Done and Not Bad;
End;

Function JNBits(V:Longint):Longint;
Var N:Longint;
Begin
 N:=0;
 While V>0 Do Begin Inc(N);V:=V shr 1;End;
 JNBits:=N;
End;

Procedure JPutBits(V:Longint;N:Longint);
Var B:Longint;
Begin
 If N=0 Then Exit;
 JOB:=((JOB shl N)or(V and((Longint(1)shl N)-1)))and $FFFFFFF;
 Inc(JOC,N);
 While JOC>=8 Do Begin
  B:=(JOB shr(JOC-8))and 255;
  BufPut(JOut^,B);
  If B=255 Then BufPut(JOut^,0);
  Dec(JOC,8);
 End;
 JOB:=JOB and((Longint(1)shl JOC)-1);
End;

Procedure JSym(T,S:Longint);Begin
 If JTally Then Inc(JFreq[T,S])
  Else JPutBits(JECode[T,S],JESize[T,S]);
End;

{ Code (ou compte) un bloc deja quantifie (ordre zigzag) }
Procedure JCodeBlock(C:Longint;Var Co:TCoef);
Var K,S,Run:Longint;D,V,Ts:Longint;
Begin
 If C=1 Then Ts:=0 Else Ts:=1;
 D:=Co[0]-JPred[C];JPred[C]:=Co[0];
 If D<0 Then V:=-D Else V:=D;
 S:=JNBits(V);
 JSym(Ts*2,S);
 If S>0 Then Begin
  If D<0 Then Dec(D);
  If Not JTally Then JPutBits(D,S);
 End;
 Run:=0;
 For K:=1 to 63 Do Begin
  If Co[K]=0 Then Inc(Run)
   Else
  Begin
   While Run>15 Do Begin JSym(Ts*2+1,$F0);Dec(Run,16);End;
   V:=Co[K];If V<0 Then V:=-V;
   S:=JNBits(V);
   JSym(Ts*2+1,Run*16+S);
   If Not JTally Then Begin
    V:=Co[K];If V<0 Then Dec(V);
    JPutBits(V,S);
   End;
   Run:=0;
  End;
 End;
 If Run>0 Then JSym(Ts*2+1,0);
End;

{ Un balayage complet : decodage des MCU, requantification, code/compte }
Function JScan:Boolean;
Var McuX,McuY,Mx,My,Rc,C,H,V,K,S,R,Tries,Val,Q,QO,Sum:Longint;
    Co:TCoef;
    DecPred:Array[1..4]of Longint;
    Ok:Boolean;
Begin
 JScan:=False;
 JBB:=0;JBC:=0;JBad:=False;Ok:=True;
 For C:=1 to 4 Do Begin DecPred[C]:=0;JPred[C]:=0;End;
 McuX:=(JImgW+8*JHMaxF-1)div(8*JHMaxF);
 McuY:=(JImgH+8*JVMaxF-1)div(8*JVMaxF);
 Rc:=0;
 My:=0;
 While Ok and(My<McuY)Do Begin
  Mx:=0;
  While Ok and(Mx<McuX)Do Begin
   If(JRst>0)and(Rc=JRst)Then Begin
    JBB:=0;JBC:=0;Tries:=0;
    While(Tries<16)and Not((JByte(JPos)=255)and(JByte(JPos+1)>=$D0)
      and(JByte(JPos+1)<=$D7))Do Begin Inc(JPos);Inc(Tries);End;
    If Tries>=16 Then Ok:=False Else Inc(JPos,2);
    Rc:=0;
    For C:=1 to 4 Do Begin DecPred[C]:=0;JPred[C]:=0;End;
   End;
   Inc(Rc);
   C:=1;
   While Ok and(C<=JNC)Do Begin
    V:=0;
    While Ok and(V<JCV[C])Do Begin
     H:=0;
     While Ok and(H<JCH[C])Do Begin
      S:=JDecodeSym(JCTd[C]);
      If(S>11)or JBad Then Ok:=False
       Else
      Begin
       Val:=0;
       If S>0 Then Begin
        Val:=JGetBits(S);
        If Val<(Longint(1)shl(S-1))Then Val:=Val-(Longint(1)shl S)+1;
       End;
       Inc(DecPred[C],Val);
       For K:=0 to 63 Do Co[K]:=0;
       Co[0]:=DecPred[C];
       K:=1;
       While Ok and(K<=63)Do Begin
        R:=JDecodeSym(4+JCTa[C]);
        If JBad Then Ok:=False
         Else
        Begin
         S:=R and 15;R:=R shr 4;
         If S=0 Then Begin
          If R=15 Then Inc(K,16) Else K:=64;
         End
          Else
         Begin
          Inc(K,R);
          If K>63 Then Ok:=False
           Else
          Begin
           Val:=JGetBits(S);
           If Val<(Longint(1)shl(S-1))Then Val:=Val-(Longint(1)shl S)+1;
           Co[K]:=Val;Inc(K);
          End;
         End;
        End;
       End;
       If JBad Then Ok:=False;
       If Ok Then Begin
        If JpegPct>100 Then
         For K:=0 to 63 Do If Co[K]<>0 Then Begin
          QO:=JQ[JCTq[C],K];Q:=JQN[JCTq[C],K];
          If Q<>QO Then Begin
           If Co[K]<0 Then Begin
            Sum:=((-Co[K])*QO+Q div 2)div Q;Co[K]:=-Sum;
           End
            Else
           Co[K]:=(Co[K]*QO+Q div 2)div Q;
          End;
         End;
        JCodeBlock(C,Co);
       End;
      End;
      Inc(H);
     End;
     Inc(V);
    End;
    Inc(C);
   End;
   Inc(Mx);
  End;
  Inc(My);
 End;
 JScan:=Ok and Not JBad;
End;

{ Construit la table de Huffman optimale (limite 16 bits) de l'ensemble T }
Procedure JGenTable(T:Longint);
Var Fr:Array[0..256]of Longint;
    CS,Oth:Array[0..256]of Longint;
    Bits:Array[0..40]of Longint;
    I,J,C1,C2,Len:Longint;V,P:Longint;
Begin
 For I:=0 to 255 Do Fr[I]:=JFreq[T,I];
 Fr[256]:=1;
 For I:=0 to 256 Do Begin CS[I]:=0;Oth[I]:=-1;End;
 For I:=0 to 40 Do Bits[I]:=0;
 Repeat
  C1:=-1;V:=1000000000;
  For I:=0 to 256 Do If(Fr[I]<>0)and(Fr[I]<=V)Then Begin V:=Fr[I];C1:=I;End;
  C2:=-1;V:=1000000000;
  For I:=0 to 256 Do
   If(Fr[I]<>0)and(Fr[I]<=V)and(I<>C1)Then Begin V:=Fr[I];C2:=I;End;
  If C2>=0 Then Begin
   Inc(Fr[C1],Fr[C2]);Fr[C2]:=0;
   Inc(CS[C1]);
   While Oth[C1]>=0 Do Begin C1:=Oth[C1];Inc(CS[C1]);End;
   Oth[C1]:=C2;
   Inc(CS[C2]);
   While Oth[C2]>=0 Do Begin C2:=Oth[C2];Inc(CS[C2]);End;
  End;
 Until C2<0;
 For I:=0 to 256 Do If CS[I]>0 Then Inc(Bits[CS[I]]);
 For I:=40 downto 17 Do
  While Bits[I]>0 Do Begin
   J:=I-2;
   While Bits[J]=0 Do Dec(J);
   Dec(Bits[I],2);Inc(Bits[I-1]);Inc(Bits[J+1],2);Dec(Bits[J]);
  End;
 I:=16;
 While(I>0)and(Bits[I]=0)Do Dec(I);
 If I>0 Then Dec(Bits[I]);
 JENum[T]:=0;
 For I:=1 to 16 Do Begin JEBits[T,I]:=Bits[I];Inc(JENum[T],Bits[I]);End;
 P:=0;
 For Len:=1 to 40 Do
  For J:=0 to 255 Do If CS[J]=Len Then Begin
   JEVal[T,P]:=J;Inc(P);
  End;
 V:=0;P:=0;
 For Len:=1 to 16 Do Begin
  For I:=1 to JEBits[T,Len] Do Begin
   JECode[T,JEVal[T,P]]:=V;JESize[T,JEVal[T,P]]:=Len;
   Inc(V);Inc(P);
  End;
  V:=V shl 1;
 End;
End;

Procedure JPutByte(V:Longint);Begin BufPut(JOut^,V and 255);End;

Procedure JPutWord(V:Longint);Begin
 BufPut(JOut^,(V shr 8)and 255);BufPut(JOut^,V and 255);
End;

{ Recode le JPEG Src dans Dst ; False si non supporte ou corrompu }
Function JpegTranscode(Var Src,Dst:TBuf):Boolean;
Var I,K,T,Tq,ScanStart:Longint;Seen:Array[0..3]of Boolean;Fin:Boolean;
Begin
 JpegTranscode:=False;
 If Not JParse(Src)Then Exit;
 For Tq:=0 to 3 Do
  If JQDef[Tq]Then
   For K:=0 to 63 Do Begin
    JQN[Tq,K]:=(JQ[Tq,K]*JpegPct+50)div 100;
    If JQN[Tq,K]>255 Then JQN[Tq,K]:=255;
    If JQN[Tq,K]<JQ[Tq,K]Then JQN[Tq,K]:=JQ[Tq,K];
    If JQN[Tq,K]<1 Then JQN[Tq,K]:=1;
   End;
 For T:=0 to 3 Do For K:=0 to 256 Do JFreq[T,K]:=0;
 { passe 1 : statistiques }
 JTally:=True;
 ScanStart:=JPos;
 If Not JScan Then Exit;
 For T:=0 to 3 Do JGenTable(T);
 { passe 2 : ecriture }
 JPos:=ScanStart;JTally:=False;
 BufClear(Dst);
 JOut:=@Dst;JOB:=0;JOC:=0;
 JPutByte(255);JPutByte($D8);
 BufAppend(Dst,JApp,0,JApp.Len);
 For Tq:=0 to 3 Do Seen[Tq]:=False;
 For I:=1 to JNC Do Begin
  Tq:=JCTq[I];
  If Not Seen[Tq]Then Begin
   Seen[Tq]:=True;
   JPutByte(255);JPutByte($DB);JPutWord(67);JPutByte(Tq);
   For K:=0 to 63 Do JPutByte(JQN[Tq,K]);
  End;
 End;
 BufAppend(Dst,JSof,0,JSof.Len);
 For T:=0 to 3 Do If JENum[T]>0 Then Begin
  JPutByte(255);JPutByte($C4);JPutWord(19+JENum[T]);
  JPutByte((T and 1)*16+(T shr 1));
  For K:=1 to 16 Do JPutByte(JEBits[T,K]);
  For K:=0 to JENum[T]-1 Do JPutByte(JEVal[T,K]);
 End;
 JPutByte(255);JPutByte($DA);JPutWord(6+2*JNC);JPutByte(JNC);
 For I:=1 to JNC Do Begin
  JPutByte(JCid[I]);
  If I=1 Then JPutByte(0) Else JPutByte($11);
 End;
 JPutByte(0);JPutByte(63);JPutByte(0);
 Fin:=JScan;
 If Fin Then Begin
  If JOC>0 Then JPutBits((Longint(1)shl(8-JOC))-1,8-JOC);
  JPutByte(255);JPutByte($D9);
 End;
 JpegTranscode:=Fin;
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
 NewRoot:Longint;          { numero du catalogue en mode manipulation de pages }
 ForceNoTrailer:Boolean;

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
 BufSet(XE,Num*12+10,(F3 shr 16)and 255);BufSet(XE,Num*12+11,(F3 shr 24)and
   255);
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

Procedure EmitRootExtra;Begin
 If NewRoot>0 Then PutS(' /Root '+IStr(NewRoot)+' 0 R');
End;

Procedure EmitXrefExtra;Begin
 EmitRootExtra;
 PutS(' /Type /XRef /Size '+IStr(XSize)+' /W [ 1 '+IStr(XW2)+' '+IStr(XW3)+''+
   ' ]');
 If XFlate Then PutS(' /Filter /FlateDecode /DecodeParms << /Columns'+
   ' '+IStr(1+XW2+XW3)+' /Predictor 12 >>');
 PutS(' /Length '+IStr(XLen));
End;

Procedure EmitPageExtra;Forward;
Procedure EmitResExtra;Forward;
Procedure EmitXObjExtra;Forward;
Procedure EmitCatExtra;Forward;

Procedure EmitExtra;Begin
 Case ExtraKind of
  1:EmitStreamExtra;
  2:EmitXrefExtra;
  3:Begin EmitRootExtra;PutS(' /Size '+IStr(XSize));End;
  4:EmitPageExtra;
  5:EmitResExtra;
  6:EmitXObjExtra;
  7:EmitCatExtra;
 End;
End;

{ Ecrit dans TB le dictionnaire du trailer (Kind : 2=flux xref, 3=trailer
  classique) }
Procedure EmitTrailer(Kind:Integer);
Var Q:Longint;
Begin
 BufClear(TB);
 EmBuf:=@TB;SBuf:=NIL;
 WMode:=2;ExtraKind:=Kind;TopSkip:=TrailerSkip;
 If NewRoot>0 Then TopSkip:=TopSkip+'Root/';
 If(TrailerPos>=0)and Not ForceNoTrailer Then Begin
  Q:=TrailerPos;
  WalkValue(Q,0);
 End
  Else
 Begin
  PutS('<<');
  If(NewRoot=0)and(SynthRoot>0)Then PutS(' /Root '+IStr(MapRef(SynthRoot))+' 0'+
    ' R');
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
 OutStr(IStr(StmN)+' 0 obj'#10'<< /Type /ObjStm /N '+IStr(OSCnt)+' /First'+
   ' '+IStr(First));
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

{ Ajoute le contenu de OB (objet synthetique) au flux d'objets courant }
Procedure AddOBToObjStm(Num:Longint);
Var Off:Longint;
Begin
 Off:=OSBody.Len;
 BufAppend(OSBody,OB,0,OB.Len);
 BufPut(OSBody,10);
 BufPutStr(OSHdr,IStr(Num)+' '+IStr(Off)+' ');
 BufPutL(OSNums,Num);
 Inc(OSCnt);
 If OSCnt>=PerStm Then FlushObjStm;
End;

{ Decide du traitement des donnees du flux }
Procedure ChooseStreamData(Var Raw:TBuf;Var Data:PBuf);
Var K,KMax,I:Integer;Src,Tgt:PBuf;Flip,Ok,AllFlate:Boolean;
Begin
 Data:=@Raw;
 StrChanged:=False;OutFlate:=False;OutFirst:=1;
 { recompression JPEG (coefficients DCT) d'un flux DCTDecode simple }
 If JpegOn and FOk and(NF=1)and(FName[1]='DCTDecode')Then Begin
  If JpegTranscode(Raw,W1)Then Begin
   If W1.Len<Raw.Len Then Data:=@W1;
  End;
  Inc(JDone);JProgress;
  Exit;
 End;
 { recompression directe d'un flux Flate simple }
 If CompressOn and RecompFlate and FOk and(NF=1)and(FName[1]='FlateDecode')Then
   Begin
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
Var
  I,N,Typ,F2,F3,MaxF2,MaxF3,XrefNum,XrefPos,RowLen,Row0:Longint;XPlain,
    XOut:PBuf;B:Byte;
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

Procedure BeginOutput(Const
  FName:String;TotalObj,NComp:Longint;VMaj,VMin:Integer);
Var I,NStm:Longint;Maj,Min:Integer;
Begin
 Maj:=VMaj;Min:=VMin;
 If UseXrefStm Then
  If(Maj<1)or((Maj=1)and(Min<5))Then Begin Maj:=1;Min:=5;End;
 If(MinVerMaj>Maj)or((MinVerMaj=Maj)and(MinVerMin>Min))Then Begin
   Maj:=MinVerMaj;Min:=MinVerMin;End;
 If ForceMaj>0 Then Begin Maj:=ForceMaj;Min:=ForceMin;End;
 Assign(OutF,FName);
 Rewrite(OutF,1);
 If IOResult<>0 Then Fatal('impossible de creer le fichier de sortie : '+FName);
 OutOpen:=True;
 If OBytes=NIL Then GetMem(OBytes,SizeOf(TBytes));
 OutFill:=0;OutPos:=0;
 OutStr('%PDF-'+IStr(Maj)+'.'+IStr(Min)+#10);
 OutStr('%'#191#247#162#254#10);
 NObj:=TotalObj;
 If UseObjStm Then NStm:=(NComp+PerStm-1)div PerStm
              Else NStm:=0;
 BufClear(XE);
 BufEnsure(XE,(NObj+NStm+2)*12);
 For I:=0 to(NObj+NStm+2)*12-1 do BufPut(XE,0);
 NextStm:=NObj+1;
 OSCnt:=0;
 BufClear(OSBody);BufClear(OSHdr);BufClear(OSNums);
End;

Procedure EndOutput;Begin
 FlushObjStm;
 WriteXref;
 OutFlush;
 Close(OutF);
 If IOResult<>0 Then Fatal('erreur a la fermeture du fichier de sortie.');
 OutOpen:=False;
End;

Procedure WriteOutput;
Var N,NComp,P:Longint;R:PObjRec;
Begin
 NComp:=0;
 JTotal:=0;JDone:=0;
 If JpegOn Then
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and
     FlStream)<>0)Then
     If OpenObject(N,P)Then Begin
      AnalyzeFilters(P);
      If FOk and(NF=1)and(FName[1]='DCTDecode')Then Inc(JTotal);
     End;
  End;
 JProgress;
 If UseObjStm Then
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and
     FlStream)=0)Then Inc(NComp);
  End;
 BeginOutput(OutName,NObj,NComp,VerMajor,VerMinor);
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)Then Begin
   If UseObjStm and((R^.Flags and FlStream)=0)Then AddToObjStm(N,R)
                                               Else WriteNormalObject(N,R);
  End;
 End;
 If JTotal>0 Then ErrLn('');
 EndOutput;
End;

{ ------------------------------------------------------------------ }
{ Verification (--check) et nombre de pages                           }
{ ------------------------------------------------------------------ }

Procedure CheckStreams;
Var N:Longint;R:PObjRec;P:Longint;I:Integer;Src,Tgt:PBuf;Flip,Ok:Boolean;
Begin
 For N:=1 to HighObj do Begin
  R:=PeekRec(N);
  If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and
    FlStream)<>0)Then Begin
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
{ Chargement d'un document                                            }
{ ------------------------------------------------------------------ }

Const
 MaxOvr=4;
 InhKey:Array[0..3]of String[10]=('Resources','MediaBox','CropBox','Rotate');
 CatBlack='/Pages/Outlines/Names/Dests/StructTreeRoot/AcroForm/'+
  'PageLabels/OpenAction/Threads/SpiderInfo/Perms/Legal/AA/';

Type
 TInh=Array[0..3]of Longint;
 TDocRec=Record
  Name:String;
  Bias:Longint;
  VMaj,VMin:Integer;
  ODir:PObjDir;
  High:Longint;
  RefsB:TBuf;
  TPos,SRoot,RootObj:Longint;
  SXs,Recon:Boolean;
  Cache:TCacheArr;
  CNext:Integer;
  Pages:TBuf;      { 5 Longint par page : objet, heritage x4 }
  NPg:Longint;
 End;
 TOcc=Record
  Doc,PIdx,RotMode,RotVal,NL:Longint;
  LKind,LDoc,LPIdx:Array[0..MaxOvr-1]of Longint;
 End;
 TRunOcc=Record
  PageNum,NL:Longint;
  LStr,LForm,LFIdx:Array[0..MaxOvr-1]of Longint;
 End;
 TSyn=Record
  Kind,A,B,C:Longint;
 End;
 TFormRec=Record
  Doc,PIdx,NewNum,Pad:Longint;
 End;

Var
 Docs:Array[0..MaxDocs-1]of TDocRec;
 NDocs,CurDoc:Integer;
 SFOpen:Boolean;
 CurName:String;
 HasPrimary:Boolean;

 { Options de manipulation de pages }
 EmptyDoc,RemoveLabels,SplitOn,CollateOn:Boolean;
 SplitN,CollateN:Longint;
 NPgSpec,NRot,NOvr:Integer;
 PgFile,PgRng:Array[1..MaxDocs]of String;
 RotAbs:Array[1..8]of Boolean;
 RotAng:Array[1..8]of Longint;
 RotRng:Array[1..8]of String;
 OvrKind:Array[1..MaxOvr]of Integer;
 OvrFile,OvrFrom,OvrRep,OvrTo:Array[1..MaxOvr]of String;

 { Plan }
 OccAll,SynT,RunOcc,RunForms,CQ,SynData,SynComp:TBuf;
 SpecL:Array[1..MaxDocs]of TBuf;
 CatSkip:String;
 QNum,QQNum,RunA:Longint;

 { Page courante }
 PgObj,PgParent,PgRotMode,PgRotVal,PgNL,PgQ,PgQQ,ResPos:Longint;
 PgInh:TInh;
 PgLKind,PgLStr,PgLForm,PgLFIdx:Array[0..MaxOvr-1]of Longint;

Procedure CloseSource;Begin
 If SFOpen Then Begin
  Close(SF);If IOResult<>0 Then;
  SFOpen:=False;
 End;
End;

Procedure OpenSourceFile(Const Nm:String);Begin
 CloseSource;
 Assign(SF,Nm);
 FileMode:=0;
 Reset(SF,1);
 If IOResult<>0 Then Fatal('impossible d''ouvrir '+Nm+' : fichier introuvable'+
   ' ou illisible.');
 FileMode:=2;
 SFOpen:=True;
 SFSize:=FileSize(SF);
 SCacheStart:=0;SCacheLen:=0;
 SBuf:=NIL;
 CurName:=Nm;
End;

Procedure OpenSource(Const Nm:String);
Var P:Longint;Found:Boolean;
Begin
 OpenSourceFile(Nm);
 If SFSize<16 Then Fatal(Nm+' : ce n''est pas un fichier PDF.');
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
  Fatal(CurName+' : fichier chiffre (Encrypt) : non supporte par cette'+
    ' version.');
End;

Procedure LoadStructure(Const Nm:String);
Var Sx:Longint;Ok:Boolean;
Begin
 OpenSource(Nm);
 Ok:=False;
 Sx:=FindStartXref;
 If Sx>=0 Then Ok:=ReadXrefChain(Sx);
 If Ok and(TrailerPos<0)Then Ok:=False;
 If Not Ok Then Reconstruct;
 CheckEncrypt;
 If Not(PassA and ComputeReach)Then Begin
  Reconstruct;
  CheckEncrypt;
  If Not(PassA and ComputeReach)Then Fatal(Nm+' : structure du document'+
    ' irrecuperable.');
 End;
 If NObj=0 Then Fatal(Nm+' : aucun objet atteignable depuis la racine du'+
   ' document.');
End;

{ ------------------------------------------------------------------ }
{ Documents multiples : sauvegarde / restauration de l'etat           }
{ ------------------------------------------------------------------ }

Procedure SaveDoc(I:Integer);Begin
 Docs[I].Bias:=Bias;
 Docs[I].VMaj:=VerMajor;Docs[I].VMin:=VerMinor;
 Docs[I].ODir:=ObjDir;Docs[I].High:=HighObj;
 Docs[I].RefsB:=Refs;
 Docs[I].TPos:=TrailerPos;Docs[I].SRoot:=SynthRoot;
 Docs[I].SXs:=SrcXrefStm;Docs[I].Recon:=Reconstructed;
 Docs[I].Cache:=SC;Docs[I].CNext:=SCNext;
End;

Procedure LoadDoc(I:Integer);Begin
 OpenSourceFile(Docs[I].Name);
 Bias:=Docs[I].Bias;
 VerMajor:=Docs[I].VMaj;VerMinor:=Docs[I].VMin;
 ObjDir:=Docs[I].ODir;HighObj:=Docs[I].High;
 Refs:=Docs[I].RefsB;
 TrailerPos:=Docs[I].TPos;SynthRoot:=Docs[I].SRoot;
 SrcXrefStm:=Docs[I].SXs;Reconstructed:=Docs[I].Recon;
 SC:=Docs[I].Cache;SCNext:=Docs[I].CNext;
End;

Procedure SelectDoc(I:Integer);Begin
 If I<>CurDoc Then Begin
  If CurDoc>=0 Then SaveDoc(CurDoc);
  LoadDoc(I);
  CurDoc:=I;
 End;
 SBuf:=NIL;
End;

Procedure ResetFlags;
Var N:Longint;R:PObjRec;
Begin
 For N:=0 to HighObj do Begin
  R:=PeekRec(N);
  If R<>@NullRec Then Begin
   R^.Flags:=R^.Flags and(FlStream or FlFree or FlPageLeaf);
   R^.NewNum:=0;
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Enregistrements dans des tampons                                    }
{ ------------------------------------------------------------------ }

Procedure RecPut(Var B:TBuf;Idx:Longint;Var R;Size:Longint);
Var P:PBytes;I:Longint;
Begin
 P:=@R;
 For I:=0 to Size-1 do BufSet(B,Idx*Size+I,P^[I]);
End;

Procedure RecGet(Var B:TBuf;Idx:Longint;Var R;Size:Longint);
Var P:PBytes;I:Longint;
Begin
 P:=@R;
 For I:=0 to Size-1 do P^[I]:=BufGet(B,Idx*Size+I);
End;

Procedure RecAdd(Var B:TBuf;Var R;Size:Longint);
Var P:PBytes;I:Longint;
Begin
 P:=@R;
 For I:=0 to Size-1 do BufPut(B,P^[I]);
End;

{ ------------------------------------------------------------------ }
{ Arbre des pages                                                     }
{ ------------------------------------------------------------------ }

Procedure PushNode(Var S:TBuf;N:Longint;Var E:TInh);
Var K:Integer;
Begin
 BufPutL(S,N);
 For K:=0 to 3 do BufPutL(S,E[K]);
End;

Procedure AddPageEntry(D:Integer;N:Longint;Var E:TInh);
Var K:Integer;
Begin
 BufPutL(Docs[D].Pages,N);
 For K:=0 to 3 do BufPutL(Docs[D].Pages,E[K]);
 Inc(Docs[D].NPg);
End;

Procedure CollectPages(D:Integer);
Var
 Stk,Kids:TBuf;
 N,Root,PgRoot,V,P,Q,N1,A,KidsPos:Longint;
 I:Longint;K:Integer;
 E:TInh;
 R:PObjRec;Done:Boolean;
Begin
 BufInit(Stk);BufInit(Kids);
 BufClear(Docs[D].Pages);Docs[D].NPg:=0;
 Root:=0;
 If TrailerPos>=0 Then Begin
  V:=DictFind(TrailerPos,'Root');
  If(V>=0)and IsRefAt(V,N1,A)Then Root:=N1;
 End
  Else
 Root:=SynthRoot;
 Docs[D].RootObj:=Root;
 PgRoot:=0;
 If(Root>0)and OpenObject(Root,P)Then Begin
  V:=DictFind(P,'Pages');
  If(V>=0)and IsRefAt(V,N1,A)Then PgRoot:=N1;
 End;
 SBuf:=NIL;
 If PgRoot>0 Then Begin
  For K:=0 to 3 do E[K]:=-1;
  PushNode(Stk,PgRoot,E);
  While Stk.Len>0 Do Begin
   N:=BufGetL(Stk,Stk.Len-20);
   For K:=0 to 3 do E[K]:=BufGetL(Stk,Stk.Len-16+K*4);
   Dec(Stk.Len,20);
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlSeen)=0)Then Begin
    R^.Flags:=R^.Flags or FlSeen;
    If OpenObject(N,P)and(SB(P)=60)Then Begin
     KidsPos:=DictFind(P,'Kids');
     If KidsPos>=0 Then Begin
      For K:=0 to 3 do If DictFind(P,InhKey[K])>=0 Then E[K]:=N;
      BufClear(Kids);
      Q:=KidsPos;SkipWS(Q);
      If SB(Q)=91 Then Begin
       Inc(Q);Done:=False;
       Repeat
        SkipWS(Q);
        If(SB(Q)=93)or(SB(Q)=-1)Then Done:=True
         Else
        If IsRefAt(Q,N1,A)Then Begin BufPutL(Kids,N1);Q:=A;End
                          Else SkipValueAt(Q);
       Until Done;
      End;
      I:=Kids.Len div 4-1;
      While I>=0 Do Begin
       PushNode(Stk,BufGetL(Kids,I*4),E);
       Dec(I);
      End;
     End
      Else
     Begin
      For K:=0 to 3 do If DictFind(P,InhKey[K])>=0 Then E[K]:=0;
      AddPageEntry(D,N,E);
      R^.Flags:=R^.Flags or FlPageLeaf;
     End;
    End;
    SBuf:=NIL;
   End;
  End;
 End;
 If Docs[D].NPg=0 Then Begin
  { arbre illisible : recherche des objets /Type /Page }
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and OpenObject(N,P)Then Begin
    If(SB(P)=60)and(ReadNameAt(DictFind(P,'Type'))='Page')Then Begin
     For K:=0 to 3 do If DictFind(P,InhKey[K])>=0 Then E[K]:=0 Else E[K]:=-1;
     AddPageEntry(D,N,E);
     R^.Flags:=R^.Flags or FlPageLeaf;
    End;
   End;
   SBuf:=NIL;
  End;
 End;
 BufFree(Stk);BufFree(Kids);
 For N:=0 to HighObj do Begin
  R:=PeekRec(N);
  If R<>@NullRec Then R^.Flags:=R^.Flags and Not FlSeen;
 End;
End;

Function AddDoc(Const Nm:String):Integer;
Var I:Integer;
Begin
 For I:=0 to NDocs-1 do If Docs[I].Name=Nm Then Begin
  AddDoc:=I;Exit;
 End;
 If NDocs>=MaxDocs Then Fatal('trop de fichiers PDF differents (maximum'+
   ' '+IStr(MaxDocs)+').');
 If CurDoc>=0 Then SaveDoc(CurDoc);
 I:=NDocs;Inc(NDocs);
 Docs[I].Name:=Nm;
 BufInit(Docs[I].Pages);
 Docs[I].NPg:=0;
 { etat vierge }
 GetMem(ObjDir,SizeOf(TObjDir));
 FillChar(ObjDir^,SizeOf(TObjDir),0);
 HighObj:=0;
 BufInit(Refs);
 TrailerPos:=-1;SynthRoot:=0;SrcXrefStm:=False;Reconstructed:=False;
 SCNext:=0;Bias:=0;VerMajor:=1;VerMinor:=4;
 FillChar(SC,SizeOf(SC),0);
 CurDoc:=I;
 LoadStructure(Nm);
 CollectPages(I);
 AddDoc:=I;
End;

{ ------------------------------------------------------------------ }
{ Intervalles de pages                                                }
{ ------------------------------------------------------------------ }

Function StrNum(Const S:String):Longint;
Var I:Integer;V:Longint;
Begin
 StrNum:=-1;
 If(S='')or(Length(S)>9)Then Exit;
 V:=0;
 For I:=1 to Length(S)do Begin
  If(S[I]<'0')or(S[I]>'9')Then Exit;
  V:=V*10+(Ord(S[I])-48);
 End;
 StrNum:=V;
End;

Function RangeNum(Const T:String;Count:Longint;Var V:Longint):Boolean;
Var N:Longint;
Begin
 RangeNum:=False;
 If T='' Then Exit;
 If T='z' Then Begin V:=Count;RangeNum:=True;Exit;End;
 If T[1]='r' Then Begin
  N:=StrNum(Copy(T,2,255));
  If N<1 Then Exit;
  V:=Count-N+1;
  RangeNum:=True;
  Exit;
 End;
 N:=StrNum(T);
 If N<0 Then Exit;
 V:=N;
 RangeNum:=True;
End;

{ Analyse un intervalle ("1,3,5-7,z,r2-r1,1-10:odd"). Fill : remplit L et
  verifie les bornes (erreur fatale) ; sinon verifie seulement la syntaxe. }
Function ParseRange(Const S:String;Count:Longint;Var
  L:TBuf;Fill:Boolean):Boolean;
Var Ps,Q,A,B,Step,V,Idx:Longint;T,Sfx:String;Mode,P:Integer;Take:Boolean;
Begin
 ParseRange:=False;
 If Fill Then BufClear(L);
 Ps:=1;
 While Ps<=Length(S)+1 Do Begin
  Q:=Ps;
  While(Q<=Length(S))and(S[Q]<>',')Do Inc(Q);
  T:=Copy(S,Ps,Q-Ps);
  Ps:=Q+1;
  If T<>'' Then Begin
   Mode:=0;
   P:=Pos(':',T);
   If P>0 Then Begin
    Sfx:=Copy(T,P+1,255);T:=Copy(T,1,P-1);
    If Sfx='odd' Then Mode:=1
     Else If Sfx='even' Then Mode:=2
     Else Exit;
   End;
   P:=Pos('-',T);
   If P>0 Then Begin
    If Not(RangeNum(Copy(T,1,P-1),Count,A)and
      RangeNum(Copy(T,P+1,255),Count,B))Then Exit;
   End
    Else
   Begin
    If Not RangeNum(T,Count,A)Then Exit;
    B:=A;
   End;
   If Fill Then Begin
    If(A<1)or(A>Count)or(B<1)or(B>Count)Then
     Fatal('intervalle de pages "'+S+'" hors limites (le document a'+
       ' '+IStr(Count)+' page(s)).');
    If A<=B Then Step:=1 Else Step:=-1;
    V:=A;Idx:=0;
    Repeat
     Inc(Idx);
     Take:=(Mode=0)or((Mode=1)and Odd(Idx))or((Mode=2)and Not Odd(Idx));
     If Take Then BufPutL(L,V);
     If V=B Then V:=B+Step Else V:=V+Step;
    Until V=B+Step;
   End;
  End;
 End;
 ParseRange:=True;
End;

{ ------------------------------------------------------------------ }
{ Lecture de nombres reels et de rectangles                           }
{ ------------------------------------------------------------------ }

Function ReadReal(Var P:Longint;Var V:Real):Boolean;
Var C:Integer;Neg,Any:Boolean;Frac:Real;Q:Longint;
Begin
 Q:=P;SkipWS(Q);V:=0;Neg:=False;Any:=False;
 C:=SB(Q);
 If(C=43)or(C=45)Then Begin Neg:=(C=45);Inc(Q);C:=SB(Q);End;
 While(C>=48)and(C<=57)Do Begin
  V:=V*10+(C-48);Any:=True;Inc(Q);C:=SB(Q);
 End;
 If C=46 Then Begin
  Inc(Q);C:=SB(Q);Frac:=0.1;
  While(C>=48)and(C<=57)Do Begin
   V:=V+Frac*(C-48);Frac:=Frac/10;Any:=True;Inc(Q);C:=SB(Q);
  End;
 End;
 If Any Then Begin
  If Neg Then V:=-V;
  P:=Q;
 End;
 ReadReal:=Any;
End;

Function RealStr(V:Real):String;
Var S:String;
Begin
 Str(V:0:4,S);
 If Pos('.',S)>0 Then Begin
  While S[Length(S)]='0' Do Delete(S,Length(S),1);
  If S[Length(S)]='.' Then Delete(S,Length(S),1);
 End;
 If(S='-0')or(S='')Then S:='0';
 RealStr:=S;
End;

{ Entree de la page PIdx du document D }
Procedure PageEntry(D:Integer;PIdx:Longint;Var Obj:Longint;Var Inh:TInh);
Var K:Integer;
Begin
 Obj:=BufGetL(Docs[D].Pages,PIdx*20);
 For K:=0 to 3 do Inh[K]:=BufGetL(Docs[D].Pages,PIdx*20+4+K*4);
End;

{ Le document D doit etre le document courant. Rectangle effectif (MediaBox...)
  }
Procedure ReadBox(Obj:Longint;Var Inh:TInh;Key:Integer;Var X0,Y0,X1,Y1:Real);
Var H,P,V,Q:Longint;T:Real;Ok:Boolean;
Begin
 X0:=0;Y0:=0;X1:=612;Y1:=792;
 If Inh[Key]=0 Then H:=Obj
  Else If Inh[Key]>0 Then H:=Inh[Key]
  Else Exit;
 SBuf:=NIL;
 If Not OpenObject(H,P)Then Exit;
 V:=DictFind(P,InhKey[Key]);
 If V<0 Then Begin SBuf:=NIL;Exit;End;
 SkipWS(V);
 If SB(V)<>91 Then Begin SBuf:=NIL;Exit;End;
 Inc(V);
 Ok:=ReadReal(V,X0) and ReadReal(V,Y0) and ReadReal(V,X1) and ReadReal(V,Y1);
 If Not Ok Then Begin X0:=0;Y0:=0;X1:=612;Y1:=792;End;
 If X0>X1 Then Begin T:=X0;X0:=X1;X1:=T;End;
 If Y0>Y1 Then Begin T:=Y0;Y0:=Y1;Y1:=T;End;
 SBuf:=NIL;
End;

{ ------------------------------------------------------------------ }
{ Emission d'une page                                                 }
{ ------------------------------------------------------------------ }

Procedure EmitInherited(Obj:Longint;Const Key:String);
Var Save:PBuf;P,V:Longint;
Begin
 Save:=SBuf;
 If OpenObject(Obj,P)Then Begin
  V:=DictFind(P,Key);
  If V>=0 Then Begin
   PutS(' /'+Key+' ');
   WalkValue(V,1);
  End;
 End;
 SBuf:=Save;
End;

Function EffRotate:Longint;
Var Save:PBuf;P,V,R:Longint;H:Longint;
Begin
 EffRotate:=0;
 If PgInh[3]=0 Then H:=PgObj
  Else If PgInh[3]>0 Then H:=PgInh[3]
  Else Exit;
 Save:=SBuf;
 If OpenObject(H,P)Then Begin
  V:=DictFind(P,'Rotate');
  If(V>=0)and ReadDirectInt(V,R)Then EffRotate:=R;
 End;
 SBuf:=Save;
End;

Procedure EmitFormEntries;
Var I,J:Integer;Dup:Boolean;
Begin
 For I:=0 to PgNL-1 do Begin
  Dup:=False;
  For J:=0 to I-1 do If PgLFIdx[J]=PgLFIdx[I]Then Dup:=True;
  If Not Dup Then PutS(' /QFm'+IStr(PgLFIdx[I])+' '+IStr(PgLForm[I])+' 0 R');
 End;
End;

Procedure EmitXObjExtra;Begin
 EmitFormEntries;
End;

Procedure EmitResExtra;
Var XV,N1,A,XP:Longint;Save:PBuf;Done:Boolean;
Begin
 XV:=DictFind(ResPos,'XObject');
 PutS(' /XObject ');
 Done:=False;
 If XV>=0 Then Begin
  Save:=SBuf;
  If IsRefAt(XV,N1,A)Then Begin
   If OpenObject(N1,XP)and(SB(XP)=60)Then Begin
    TopSkip:='';ExtraKind:=6;
    WalkValue(XP,0);
    Done:=True;
   End;
  End
   Else
  If SB(XV)=60 Then Begin
   TopSkip:='';ExtraKind:=6;
   WalkValue(XV,0);
   Done:=True;
  End;
  SBuf:=Save;
 End;
 If Not Done Then Begin
  PutS('<<');EmitFormEntries;PutS(' >>');
 End;
End;

Procedure EmitMergedResources;
Var H,P,V,RP,N1,A:Longint;Save:PBuf;
Begin
 Save:=SBuf;
 PutS(' /Resources ');
 RP:=-1;
 If PgInh[0]=0 Then H:=PgObj
  Else If PgInh[0]>0 Then H:=PgInh[0]
  Else H:=0;
 If(H>0)and OpenObject(H,P)Then Begin
  V:=DictFind(P,'Resources');
  If V>=0 Then Begin
   If IsRefAt(V,N1,A)Then Begin
    If OpenObject(N1,P)Then RP:=P;
   End
    Else
   RP:=V;
  End;
 End;
 If(RP>=0)and(SB(RP)=60)Then Begin
  ResPos:=RP;
  TopSkip:='/XObject/';ExtraKind:=5;
  WalkValue(RP,0);
  ExtraKind:=0;TopSkip:='';
 End
  Else
 Begin
  PutS('<< /XObject <<');EmitFormEntries;PutS(' >> >>');
 End;
 SBuf:=Save;
End;

Procedure EmitContentsElems(V:Longint);
Var Q,N1,A,Pt:Longint;C:Integer;Save:PBuf;Done:Boolean;
Begin
 SkipWS(V);
 C:=SB(V);
 If C=91 Then Begin
  Q:=V+1;Done:=False;
  Repeat
   SkipWS(Q);C:=SB(Q);
   If(C=-1)or(C=93)Then Done:=True
    Else
   Begin
    PutC(32);
    WalkValue(Q,1);
   End;
  Until Done;
 End
  Else
 If IsRefAt(V,N1,A)Then Begin
  Save:=SBuf;
  If OpenObject(N1,Pt)and(SB(Pt)=91)Then Begin
   Q:=Pt+1;Done:=False;
   Repeat
    SkipWS(Q);C:=SB(Q);
    If(C=-1)or(C=93)Then Done:=True
     Else
    Begin
     PutC(32);
     WalkValue(Q,1);
    End;
   Until Done;
  End
   Else
  Begin
   SBuf:=Save;
   PutC(32);
   WalkValue(V,1);
  End;
  SBuf:=Save;
 End;
End;

Procedure EmitLayers;
Var I:Integer;Save:PBuf;P,V:Longint;
Begin
 Save:=SBuf;
 PutS(' /Contents [');
 For I:=0 to PgNL-1 do If PgLKind[I]=0 Then PutS(' '+IStr(PgLStr[I])+' 0 R');
 PutS(' '+IStr(PgQ)+' 0 R');
 If OpenObject(PgObj,P)Then Begin
  V:=DictFind(P,'Contents');
  If V>=0 Then EmitContentsElems(V);
 End;
 SBuf:=Save;
 PutS(' '+IStr(PgQQ)+' 0 R');
 For I:=0 to PgNL-1 do If PgLKind[I]=1 Then PutS(' '+IStr(PgLStr[I])+' 0 R');
 PutS(' ]');
 EmitMergedResources;
End;

Procedure EmitPageExtra;
Var SaveEK:Integer;SaveTS:String;Save:PBuf;K:Integer;NewR:Longint;
Begin
 Save:=SBuf;SaveEK:=ExtraKind;SaveTS:=TopSkip;
 ExtraKind:=0;TopSkip:='';
 PutS(' /Parent '+IStr(PgParent)+' 0 R');
 For K:=0 to 3 do
  If(PgInh[K]>0)and Not((K=0)and(PgNL>0))and Not((K=3)and(PgRotMode<>0))Then
   EmitInherited(PgInh[K],InhKey[K]);
 If PgRotMode<>0 Then Begin
  If PgRotMode=1 Then NewR:=PgRotVal
                 Else NewR:=EffRotate+PgRotVal;
  NewR:=((NewR mod 360)+360)mod 360;
  PutS(' /Rotate '+IStr(NewR));
 End;
 If PgNL>0 Then EmitLayers;
 SBuf:=Save;ExtraKind:=SaveEK;TopSkip:=SaveTS;
End;

{ Parcourt la page courante (Mode 1 = collecte des references, 2 = emission) }
Procedure WalkPage(Mode:Integer);
Var P:Longint;
Begin
 If Not OpenObject(PgObj,P)Then Begin
  WMode:=Mode;
  PutS('<< /Type /Page /Parent '+IStr(PgParent)+' 0 R >>');
  WMode:=0;SBuf:=NIL;
  Exit;
 End;
 TopSkip:='/Parent/';
 If PgNL>0 Then Begin
  TopSkip:=TopSkip+'Contents/';
  If PgInh[0]=0 Then TopSkip:=TopSkip+'Resources/';
 End;
 If PgRotMode<>0 Then TopSkip:=TopSkip+'Rotate/';
 ExtraKind:=4;WMode:=Mode;
 WalkValue(P,0);
 WMode:=0;ExtraKind:=0;TopSkip:='';
 SBuf:=NIL;
End;

Procedure EmitCatExtra;Begin
 PutS(' /Pages 2 0 R');
End;

{ ------------------------------------------------------------------ }
{ Objets synthetiques                                                 }
{ ------------------------------------------------------------------ }

Function SynAdd(Kind,A,B,C:Longint):Longint;
Var S:TSyn;
Begin
 S.Kind:=Kind;S.A:=A;S.B:=B;S.C:=C;
 RecAdd(SynT,S,SizeOf(S));
 SynAdd:=SynT.Len div SizeOf(TSyn);
End;

Procedure PutSynObject(Num:Longint;IsStream:Boolean;Var Data:TBuf);Begin
 If UseObjStm and Not IsStream Then Begin
  AddOBToObjStm(Num);
  Exit;
 End;
 XSet(Num,1,OutPos,0);
 OutStr(IStr(Num)+' 0 obj'#10);
 OutBuffer(OB,0,OB.Len);
 If IsStream Then Begin
  OutStr(#10'stream'#10);
  OutBuffer(Data,0,Data.Len);
  OutStr(#10'endstream');
 End;
 OutStr(#10'endobj'#10);
End;

Procedure SetupPage(Var O:TOcc;Var RO:TRunOcc);
Var Obj:Longint;K:Integer;
Begin
 PageEntry(O.Doc,O.PIdx,Obj,PgInh);
 PgObj:=Obj;
 PgParent:=2;
 PgRotMode:=O.RotMode;PgRotVal:=O.RotVal;
 PgNL:=O.NL;
 PgQ:=QNum;PgQQ:=QQNum;
 For K:=0 to MaxOvr-1 do Begin
  PgLKind[K]:=O.LKind[K];
  PgLStr[K]:=RO.LStr[K];PgLForm[K]:=RO.LForm[K];PgLFIdx[K]:=RO.LFIdx[K];
 End;
End;

Procedure CollectContentRefs(V:Longint;Var L:TBuf);
Var Q,N1,A,Pt:Longint;C:Integer;Save:PBuf;Done:Boolean;
Begin
 SkipWS(V);
 C:=SB(V);
 If C=91 Then Begin
  Q:=V+1;Done:=False;
  Repeat
   SkipWS(Q);C:=SB(Q);
   If(C=-1)or(C=93)Then Done:=True
    Else
   If IsRefAt(Q,N1,A)Then Begin BufPutL(L,N1);Q:=A;End
                     Else SkipValueAt(Q);
  Until Done;
 End
  Else
 If IsRefAt(V,N1,A)Then Begin
  Save:=SBuf;
  If OpenObject(N1,Pt)and(SB(Pt)=91)Then Begin
   Q:=Pt+1;Done:=False;
   Repeat
    SkipWS(Q);C:=SB(Q);
    If(C=-1)or(C=93)Then Done:=True
     Else
    If IsRefAt(Q,N1,A)Then Begin BufPutL(L,N1);Q:=A;End
                      Else SkipValueAt(Q);
   Until Done;
  End
   Else
  BufPutL(L,N1);
  SBuf:=Save;
 End;
End;

Procedure EmitEffective(Obj:Longint;Var Inh:TInh;Key:Integer;Const Dflt:String);
Var H,P,V:Longint;
Begin
 If Inh[Key]=0 Then H:=Obj
  Else If Inh[Key]>0 Then H:=Inh[Key]
  Else H:=0;
 V:=-1;
 If(H>0)and OpenObject(H,P)Then V:=DictFind(P,InhKey[Key]);
 If V>=0 Then WalkValue(V,1)
         Else PutS(Dflt);
 SBuf:=NIL;
End;

Procedure EmitForm(Idx:Longint);
Var
  F:TFormRec;Obj:Longint;Inh:TInh;P,V,I:Longint;L:TBuf;Ps:Longint;Fl:Boolean;
    Data:PBuf;
Begin
 RecGet(RunForms,Idx,F,SizeOf(F));
 SelectDoc(F.Doc);
 PageEntry(F.Doc,F.PIdx,Obj,Inh);
 BufInit(L);
 BufClear(SynData);
 If OpenObject(Obj,P)Then Begin
  V:=DictFind(P,'Contents');
  If V>=0 Then CollectContentRefs(V,L);
 End;
 SBuf:=NIL;
 For I:=0 to L.Len div 4-1 do Begin
  If OpenObject(BufGetL(L,I*4),Ps)and GetRaw(Ps,WRaw)and
    DecodeStreamFull(Ps,WRaw,XDec)Then Begin
   BufAppend(SynData,XDec,0,XDec.Len);
   BufPut(SynData,10);
  End
   Else
  Warn('contenu de la page de superposition illisible, ignore.');
  SBuf:=NIL;
 End;
 BufFree(L);
 Data:=@SynData;Fl:=False;
 If CompressOn Then Begin
  BufClear(SynComp);
  DeflateBuf(SynData,SynComp,Level);
  If SynComp.Len<SynData.Len Then Begin Data:=@SynComp;Fl:=True;End;
 End;
 BufClear(OB);
 EmBuf:=@OB;WMode:=2;
 PutS('<< /Type /XObject /Subtype /Form /BBox ');
 EmitEffective(Obj,Inh,1,'[ 0 0 612 792 ]');
 PutS(' /Resources ');
 EmitEffective(Obj,Inh,0,'<< >>');
 If Fl Then PutS(' /Filter /FlateDecode');
 PutS(' /Length '+IStr(Data^.Len)+' >>');
 WMode:=0;
 PutSynObject(F.NewNum,True,Data^);
End;

Procedure EmitLayerStream(OccIdx,L:Longint);
Var O:TOcc;RO:TRunOcc;F:TFormRec;Obj:Longint;Inh:TInh;K:Integer;Rot:Longint;
    Sx0,Sy0,Sx1,Sy1,Dx0,Dy0,Dx1,Dy1,Sw,Sh,Dw,Dh,Vw,Vh,S,S2,Vx,Vy:Real;
    Ma,Mb,Mc,Md,Me,Mf:Real;
Begin
 RecGet(OccAll,OccIdx,O,SizeOf(O));
 RecGet(RunOcc,OccIdx-RunA,RO,SizeOf(RO));
 RecGet(RunForms,RO.LFIdx[L],F,SizeOf(F));
 SelectDoc(F.Doc);
 PageEntry(F.Doc,F.PIdx,Obj,Inh);
 ReadBox(Obj,Inh,1,Sx0,Sy0,Sx1,Sy1);
 SelectDoc(O.Doc);
 PageEntry(O.Doc,O.PIdx,Obj,Inh);
 ReadBox(Obj,Inh,1,Dx0,Dy0,Dx1,Dy1);
 { rotation effective de la page de destination }
 PgObj:=Obj;
 For K:=0 to 3 do PgInh[K]:=Inh[K];
 Rot:=EffRotate;
 If O.RotMode=1 Then Rot:=O.RotVal
  Else If O.RotMode=2 Then Rot:=Rot+O.RotVal;
 Rot:=((Rot mod 360)+360)mod 360;
 Sw:=Sx1-Sx0;Sh:=Sy1-Sy0;Dw:=Dx1-Dx0;Dh:=Dy1-Dy0;
 If(Rot=90)or(Rot=270)Then Begin Vw:=Dh;Vh:=Dw;End
                      Else Begin Vw:=Dw;Vh:=Dh;End;
 S:=1;
 If(Sw>0)and(Sh>0)Then Begin
  S:=Vw/Sw;S2:=Vh/Sh;
  If S2<S Then S:=S2;
  If S>1 Then S:=1;
 End;
 Vx:=(Vw-S*Sw)/2-S*Sx0;
 Vy:=(Vh-S*Sh)/2-S*Sy0;
 Case Rot of
  90:Begin Ma:=0;Mb:=S;Mc:=-S;Md:=0;Me:=Dw-Vy;Mf:=Vx;End;
  180:Begin Ma:=-S;Mb:=0;Mc:=0;Md:=-S;Me:=Dw-Vx;Mf:=Dh-Vy;End;
  270:Begin Ma:=0;Mb:=-S;Mc:=S;Md:=0;Me:=Vy;Mf:=Dh-Vx;End;
  Else Begin Ma:=S;Mb:=0;Mc:=0;Md:=S;Me:=Vx;Mf:=Vy;End;
 End;
 Me:=Me+Dx0;Mf:=Mf+Dy0;
 BufClear(SynData);
 BufPutStr(SynData,'q '+RealStr(Ma)+' '+RealStr(Mb)+' '+RealStr(Mc)+''+
   ' '+RealStr(Md)+' '+RealStr(Me)+' '+RealStr(Mf)+
                   ' cm /QFm'+IStr(RO.LFIdx[L])+' Do Q'#10);
 BufClear(OB);
 EmBuf:=@OB;WMode:=2;
 PutS('<< /Length '+IStr(SynData.Len)+' >>');
 WMode:=0;
 PutSynObject(RO.LStr[L],True,SynData);
End;

Procedure EmitSyn(K:Longint);
Var S:TSyn;O:TOcc;RO:TRunOcc;I,Cnt,P,Root:Longint;
Begin
 RecGet(SynT,K-1,S,SizeOf(S));
 BufClear(OB);
 EmBuf:=@OB;
 Case S.Kind of
  1:Begin
   WMode:=2;
   Root:=0;
   If HasPrimary Then Begin
    SelectDoc(0);
    Root:=Docs[0].RootObj;
   End;
   If(Root>0)and OpenObject(Root,P)and(SB(P)=60)Then Begin
    TopSkip:=CatSkip;ExtraKind:=7;
    WalkValue(P,0);
    TopSkip:='';ExtraKind:=0;
    SBuf:=NIL;
   End
    Else
   PutS('<< /Type /Catalog /Pages 2 0 R >>');
   WMode:=0;
   PutSynObject(K,False,SynData);
  End;
  2:Begin
   WMode:=2;
   PutS('<< /Type /Pages /Kids [');
   Cnt:=RunOcc.Len div SizeOf(TRunOcc);
   For I:=0 to Cnt-1 do Begin
    RecGet(RunOcc,I,RO,SizeOf(RO));
    PutS(' '+IStr(RO.PageNum)+' 0 R');
   End;
   PutS(' ] /Count '+IStr(Cnt)+' >>');
   WMode:=0;
   PutSynObject(K,False,SynData);
  End;
  3,4:Begin
   BufClear(SynData);
   If S.Kind=3 Then BufPutStr(SynData,'q'#10) Else BufPutStr(SynData,'Q'#10);
   WMode:=2;
   PutS('<< /Length 2 >>');
   WMode:=0;
   PutSynObject(K,True,SynData);
  End;
  5:EmitForm(S.A);
  6:EmitLayerStream(S.A,S.B);
  7:Begin
   RecGet(OccAll,S.A,O,SizeOf(O));
   RecGet(RunOcc,S.B,RO,SizeOf(RO));
   SelectDoc(O.Doc);
   SetupPage(O,RO);
   EmBuf:=@OB;
   WalkPage(2);
   PutSynObject(K,False,SynData);
  End;
 End;
 WMode:=0;
End;

{ ------------------------------------------------------------------ }
{ Fermeture transitive et numerotation                                }
{ ------------------------------------------------------------------ }

Procedure ConsumeSeeds(Mark:Longint);
Var I,T:Longint;R:PObjRec;
Begin
 I:=Mark;
 While I<Refs.Len Do Begin
  T:=BufGetL(Refs,I);
  If T>0 Then Begin
   R:=PeekRec(T);
   If(R^.Kind<>0)and((R^.Flags and(FlReach or FlPageLeaf))=0)Then Begin
    R^.Flags:=R^.Flags or FlReach;
    BufPutL(CQ,T);
   End;
  End;
  Inc(I,4);
 End;
 Refs.Len:=Mark;
End;

Procedure ClosureDoc(D:Integer;A,B:Longint);
Var
  I,Mark,Head,N,T,J,Root,P:Longint;O:TOcc;RO:TRunOcc;R,R0:PObjRec;F:TFormRec;
    Obj:Longint;Inh:TInh;
Begin
 SelectDoc(D);
 ResetFlags;
 BufClear(CQ);
 { catalogue et trailer du document principal }
 If HasPrimary and(D=0)Then Begin
  Mark:=Refs.Len;
  Root:=Docs[0].RootObj;
  If(Root>0)and OpenObject(Root,P)and(SB(P)=60)Then Begin
   TopSkip:=CatSkip;ExtraKind:=7;WMode:=1;
   WalkValue(P,0);
   WMode:=0;ExtraKind:=0;TopSkip:='';
  End;
  SBuf:=NIL;
  If TrailerPos>=0 Then Begin
   TopSkip:=TrailerSkip+'Root/';WMode:=1;
   P:=TrailerPos;
   WalkValue(P,0);
   WMode:=0;TopSkip:='';
  End;
  ConsumeSeeds(Mark);
 End;
 { pages selectionnees }
 For I:=A to B do Begin
  RecGet(OccAll,I,O,SizeOf(O));
  If O.Doc=D Then Begin
   RecGet(RunOcc,I-A,RO,SizeOf(RO));
   PageEntry(D,O.PIdx,Obj,Inh);
   R:=PeekRec(Obj);
   If(R^.Flags and FlReach)=0 Then Begin
    R^.Flags:=R^.Flags or FlReach;
    R^.NewNum:=RO.PageNum;
    Mark:=Refs.Len;
    PgObj:=Obj;PgParent:=2;PgRotMode:=0;PgRotVal:=0;PgNL:=0;
    For J:=0 to 3 do PgInh[J]:=Inh[J];
    WalkPage(1);
    ConsumeSeeds(Mark);
   End;
  End;
 End;
 { formulaires de superposition }
 For I:=0 to RunForms.Len div SizeOf(TFormRec)-1 do Begin
  RecGet(RunForms,I,F,SizeOf(F));
  If F.Doc=D Then Begin
   Mark:=Refs.Len;
   PageEntry(D,F.PIdx,Obj,Inh);
   WMode:=1;
   EmitEffective(Obj,Inh,0,'<< >>');
   WMode:=0;
   ConsumeSeeds(Mark);
  End;
 End;
 { fermeture }
 Head:=0;
 While Head*4<CQ.Len Do Begin
  N:=BufGetL(CQ,Head*4);Inc(Head);
  R:=PeekRec(N);
  For J:=0 to R^.RefCnt-1 do Begin
   T:=BufGetL(Refs,(R^.RefStart+J)*4);
   If T>0 Then Begin
    R0:=PeekRec(T);
    If(R0^.Kind<>0)and((R0^.Flags and(FlReach or FlPageLeaf))=0)Then Begin
     R0^.Flags:=R0^.Flags or FlReach;
     BufPutL(CQ,T);
    End;
   End;
  End;
 End;
End;

{ Produit un fichier avec les pages A..B de la sequence }
Procedure ProduceOutput(A,B:Longint;Const FName:String);
Var
 I,L,D,N,Cnt,NextNum,NComp,TotalObj,SynCount,K:Longint;
 O:TOcc;RO:TRunOcc;F:TFormRec;SY:TSyn;R:PObjRec;Found:Boolean;
 AnyLayer:Boolean;Maj,Min:Integer;
Begin
 RunA:=A;
 BufClear(SynT);BufClear(RunOcc);BufClear(RunForms);
 Cnt:=B-A+1;
 AnyLayer:=False;
 For I:=A to B do Begin
  RecGet(OccAll,I,O,SizeOf(O));
  If O.NL>0 Then AnyLayer:=True;
 End;
 SynAdd(1,0,0,0);
 SynAdd(2,A,Cnt,0);
 QNum:=0;QQNum:=0;
 If AnyLayer Then Begin
  QNum:=SynAdd(3,0,0,0);
  QQNum:=SynAdd(4,0,0,0);
 End;
 For I:=A to B do Begin
  RecGet(OccAll,I,O,SizeOf(O));
  FillChar(RO,SizeOf(RO),0);
  RO.NL:=O.NL;
  For L:=0 to O.NL-1 do Begin
   Found:=False;
   For K:=0 to RunForms.Len div SizeOf(TFormRec)-1 do Begin
    RecGet(RunForms,K,F,SizeOf(F));
    If(F.Doc=O.LDoc[L])and(F.PIdx=O.LPIdx[L])Then Begin
     Found:=True;RO.LForm[L]:=F.NewNum;RO.LFIdx[L]:=K;
    End;
   End;
   If Not Found Then Begin
    F.Doc:=O.LDoc[L];F.PIdx:=O.LPIdx[L];F.Pad:=0;
    K:=RunForms.Len div SizeOf(TFormRec);
    F.NewNum:=SynAdd(5,K,0,0);
    RecAdd(RunForms,F,SizeOf(F));
    RO.LForm[L]:=F.NewNum;RO.LFIdx[L]:=K;
   End;
   RO.LStr[L]:=SynAdd(6,I,L,0);
  End;
  RO.PageNum:=SynAdd(7,I,I-A,0);
  RecAdd(RunOcc,RO,SizeOf(RO));
 End;
 SynCount:=SynT.Len div SizeOf(TSyn);
 For D:=0 to NDocs-1 do ClosureDoc(D,A,B);
 NextNum:=SynCount+1;
 NComp:=0;
 For K:=1 to SynCount do Begin
  RecGet(SynT,K-1,SY,SizeOf(SY));
  If(SY.Kind=1)or(SY.Kind=2)or(SY.Kind=7)Then Inc(NComp);
 End;
 Maj:=0;Min:=0;
 For D:=0 to NDocs-1 do Begin
  SelectDoc(D);
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and
     FlPageLeaf)=0)Then Begin
    R^.NewNum:=NextNum;Inc(NextNum);
    If(R^.Flags and FlStream)=0 Then Inc(NComp);
   End;
  End;
  If(VerMajor>Maj)or((VerMajor=Maj)and(VerMinor>Min))Then Begin
    Maj:=VerMajor;Min:=VerMinor;End;
 End;
 TotalObj:=NextNum-1;
 If CurDoc>=0 Then SaveDoc(CurDoc);
 Case ObjMode of
  0:Begin UseObjStm:=False;UseXrefStm:=False;End;
  1:Begin
   UseObjStm:=HasPrimary and Docs[0].SXs;
   UseXrefStm:=UseObjStm;
  End;
  Else Begin UseObjStm:=True;UseXrefStm:=True;End;
 End;
 NewRoot:=1;
 ForceNoTrailer:=Not HasPrimary;
 BeginOutput(FName,TotalObj,NComp,Maj,Min);
 For K:=1 to SynCount do EmitSyn(K);
 For D:=0 to NDocs-1 do Begin
  SelectDoc(D);
  For N:=1 to HighObj do Begin
   R:=PeekRec(N);
   If(R^.Kind<>0)and((R^.Flags and FlReach)<>0)and((R^.Flags and
     FlPageLeaf)=0)Then Begin
    If UseObjStm and((R^.Flags and FlStream)=0)Then AddToObjStm(N,R)
                                                Else WriteNormalObject(N,R);
   End;
  End;
 End;
 If HasPrimary Then SelectDoc(0);
 EndOutput;
 NewRoot:=0;ForceNoTrailer:=False;
 If Verbose Then WriteLn('Ecrit : ',FName,' (',Cnt,' page(s), ',TotalObj,''+
   ' objets)');
End;

{ ------------------------------------------------------------------ }
{ Plan : sequence de pages, rotations, superpositions                 }
{ ------------------------------------------------------------------ }

Function PagesOf(D:Integer):Longint;Begin
 PagesOf:=Docs[D].NPg;
End;

Procedure BuildPlan;
Var
 S,I,J,K,D,Total,Done,Left:Longint;
 DocOf:Array[1..MaxDocs]of Integer;
 Pos_:Array[1..MaxDocs]of Longint;
 NSp:Integer;
 O:TOcc;
 L,FL,RL,TL:TBuf;
 Src,Dest,Ang:Longint;
 Any:Boolean;
Begin
 NSp:=NPgSpec;
 If NSp=0 Then Begin
  If EmptyDoc Then Fatal('--empty necessite --pages pour choisir les pages.');
  NSp:=1;PgFile[1]:='.';PgRng[1]:='1-z';
 End;
 For S:=1 to NSp do Begin
  If PgFile[S]='.' Then Begin
   If EmptyDoc Then Fatal('"." designe le fichier d''entree, mais --empty est'+
     ' utilise.');
   DocOf[S]:=0;
  End
   Else
  DocOf[S]:=AddDoc(PgFile[S]);
 End;
 For S:=1 to NSp do Begin
  BufInit(SpecL[S]);
  If Docs[DocOf[S]].NPg=0 Then Fatal(Docs[DocOf[S]].Name+' : aucune page'+
    ' trouvee.');
  ParseRange(PgRng[S],Docs[DocOf[S]].NPg,SpecL[S],True);
  Pos_[S]:=0;
 End;
 BufClear(OccAll);
 FillChar(O,SizeOf(O),0);
 If CollateOn Then Begin
  Repeat
   Any:=False;
   For S:=1 to NSp do Begin
    K:=0;
    While(K<CollateN)and(Pos_[S]*4<SpecL[S].Len)Do Begin
     O.Doc:=DocOf[S];O.PIdx:=BufGetL(SpecL[S],Pos_[S]*4)-1;
     RecAdd(OccAll,O,SizeOf(O));
     Inc(Pos_[S]);Inc(K);Any:=True;
    End;
   End;
  Until Not Any;
 End
  Else
 For S:=1 to NSp do
  For I:=0 to SpecL[S].Len div 4-1 do Begin
   O.Doc:=DocOf[S];O.PIdx:=BufGetL(SpecL[S],I*4)-1;
   RecAdd(OccAll,O,SizeOf(O));
  End;
 Total:=OccAll.Len div SizeOf(TOcc);
 If Total=0 Then Fatal('aucune page selectionnee.');
 { rotations }
 BufInit(L);
 For S:=1 to NRot do Begin
  ParseRange(RotRng[S],Total,L,True);
  For I:=0 to L.Len div 4-1 do Begin
   J:=BufGetL(L,I*4)-1;
   RecGet(OccAll,J,O,SizeOf(O));
   If RotAbs[S]Then Begin O.RotMode:=1;O.RotVal:=RotAng[S];End
    Else
   Begin
    If O.RotMode=0 Then O.RotMode:=2;
    O.RotVal:=O.RotVal+RotAng[S];
   End;
   RecPut(OccAll,J,O,SizeOf(O));
  End;
 End;
 { superpositions }
 BufInit(FL);BufInit(RL);BufInit(TL);
 For S:=1 to NOvr do Begin
  D:=AddDoc(OvrFile[S]);
  ParseRange(OvrFrom[S],Docs[D].NPg,FL,True);
  ParseRange(OvrRep[S],Docs[D].NPg,RL,True);
  ParseRange(OvrTo[S],Total,TL,True);
  Left:=FL.Len div 4;
  For I:=0 to TL.Len div 4-1 do Begin
   Dest:=BufGetL(TL,I*4)-1;
   Src:=0;
   If I<Left Then Src:=BufGetL(FL,I*4)
    Else If RL.Len>0 Then Src:=BufGetL(RL,((I-Left)mod(RL.Len div 4))*4);
   If Src>0 Then Begin
    RecGet(OccAll,Dest,O,SizeOf(O));
    If O.NL<MaxOvr Then Begin
     O.LKind[O.NL]:=OvrKind[S];O.LDoc[O.NL]:=D;O.LPIdx[O.NL]:=Src-1;
     Inc(O.NL);
     RecPut(OccAll,Dest,O,SizeOf(O));
    End
     Else
    Warn('trop de superpositions sur la page '+IStr(Dest+1)+'.');
   End;
  End;
 End;
 BufFree(L);BufFree(FL);BufFree(RL);BufFree(TL);
End;

Function SplitName(Const Base:String;FirstP,LastP,Total,N:Longint):String;
Var W:Integer;Num,R:String;P,I,Dot:Integer;
Begin
 W:=Length(IStr(Total));
 Num:=PadZero(FirstP,W);
 If N>1 Then Num:=Num+'-'+PadZero(LastP,W);
 P:=Pos('%d',Base);
 If P>0 Then Begin
  SplitName:=Copy(Base,1,P-1)+Num+Copy(Base,P+2,255);
  Exit;
 End;
 Dot:=0;
 For I:=1 to Length(Base)do Begin
  If Base[I]='.' Then Dot:=I;
  If(Base[I]='/')or(Base[I]='\')Then Dot:=0;
 End;
 If Dot>0 Then R:=Copy(Base,1,Dot-1)+'-'+Num+Copy(Base,Dot,255)
          Else R:=Base+'-'+Num;
 SplitName:=R;
End;

Procedure RunPageOps;
Var Total,A,B:Longint;
Begin
 BufInit(OccAll);BufInit(SynT);BufInit(RunOcc);BufInit(RunForms);
 BufInit(CQ);BufInit(SynData);BufInit(SynComp);
 NewRoot:=0;ForceNoTrailer:=False;
 If Not EmptyDoc Then AddDoc(InName);
 HasPrimary:=Not EmptyDoc;
 { champs du catalogue }
 If(NPgSpec=0)and(Not CollateOn)Then Begin
  CatSkip:='/Pages/';
  If RemoveLabels Then CatSkip:=CatSkip+'/PageLabels/';
 End
  Else
 CatSkip:=CatBlack;
 If RemoveLabels and(Pos('/PageLabels/',CatSkip)=0)Then
   CatSkip:=CatSkip+'/PageLabels/';
 BuildPlan;
 Total:=OccAll.Len div SizeOf(TOcc);
 If ShowNPages Then Begin
  WriteLn(Total);
  Exit;
 End;
 If SplitOn Then Begin
  A:=0;
  While A<Total Do Begin
   B:=A+SplitN-1;
   If B>=Total Then B:=Total-1;
   ProduceOutput(A,B,SplitName(OutName,A+1,B+1,Total,B-A+1));
   A:=B+1;
  End;
 End
  Else
 ProduceOutput(0,Total-1,OutName);
End;

{ ------------------------------------------------------------------ }
{ Programme principal                                                 }
{ ------------------------------------------------------------------ }

Procedure ShowHelp;Begin
 WriteLn('QPDF : Cette commande permet d''optimiser la structure interne d''un'+
   ' fichier PDF,');
 WriteLn('       de compresser ses flux de donnees sans perte (la resolution'+
   ' des');
 WriteLn('       images n''est jamais reduite) et de manipuler ses pages.');
 WriteLn;
 WriteLn('Syntaxe : QPDF [options] entree.pdf sortie.pdf');
 WriteLn('          QPDF --empty [options] sortie.pdf');
 WriteLn;
 WriteLn(' --stream-data=compress|preserve|uncompress');
 WriteLn('                          Traitement des flux (defaut : compress)');
 WriteLn(' --compress-streams=y|n   Compresse les flux (Flate)');
 WriteLn(' --decode-level=none|generalized|specialized|all');
 WriteLn('                          Filtres decodes avant recompression'+
   ' (defaut : generalized).');
 WriteLn('                          Les filtres specialises (DCT, JPX, CCITT,'+
   ' JBIG2) ne sont jamais');
 WriteLn('                          decodes : ils sont conserves tels quels.');
 WriteLn(' --recompress-flate       Recompresse aussi les flux deja en Flate');
 WriteLn(' --compression-level=0..9 Niveau de compression Flate (defaut : 9)');
 WriteLn(' --optimize-jpeg          Recode les images JPEG (DCTDecode) avec des'+
   ' tables de');
 WriteLn('                          Huffman optimales (sans perte, ~4 %)');
 WriteLn(' --jpeg-requant=pct       Comme --optimize-jpeg, mais agrandit en plus'+
   ' les pas de');
 WriteLn('                          quantification de pct % (ex. 150 : image'+
   ' ~15 % plus');
 WriteLn('                          petite, avec perte ; 100 = sans perte)');
 WriteLn(' --object-streams=disable|preserve|generate');
 WriteLn('                          Gestion des flux d''objets (defaut :'+
   ' preserve)');
 WriteLn(' --preserve-unreferenced  Conserve les objets non references');
 WriteLn(' --min-version=x.y        Version minimale du PDF produit');
 WriteLn(' --force-version=x.y      Force la version du PDF produit');
 WriteLn(' --check                  Verifie la structure et les flux (aucune'+
   ' sortie)');
 WriteLn(' --show-npages            Affiche le nombre de pages');
 WriteLn(' --warning-exit-0         Code de retour 0 meme en cas'+
   ' d''avertissements');
 WriteLn(' --verbose                Affiche un resume des tailles');
 WriteLn(' --version                Affiche la version');
 WriteLn(' --help                   Affiche cette aide');
 WriteLn;
 WriteLn('Manipulation de pages :');
 WriteLn(' --empty                  Part d''un document vide (pas de fichier'+
   ' d''entree)');
 WriteLn(' --pages fichier [pages] [fichier [pages]...] --');
 WriteLn('                          Selectionne des pages ("." = fichier'+
   ' d''entree).');
 WriteLn('                          Pages :'+
   ' 1,3,5-7,z,r2-r1,1-10:odd,1-10:even');
 WriteLn(' --collate[=n]            Entrelace les pages des differents'+
   ' fichiers (n a la fois)');
 WriteLn(' --split-pages[=n]        Un fichier de sortie par groupe de n'+
   ' pages');
 WriteLn(' --rotate=[+|-]angle[:pages]  Rotation (0, 90, 180, 270) ; +/- ='+
   ' relative');
 WriteLn(' --overlay fichier [--from=p] [--repeat=p] [--to=p] --');
 WriteLn('                          Superpose les pages d''un autre PDF');
 WriteLn(' --underlay fichier [--from=p] [--repeat=p] [--to=p] --');
 WriteLn('                          Place les pages d''un autre PDF derriere');
 WriteLn(' --remove-page-labels     Supprime les etiquettes de numerotation'+
   ' des pages');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn('  QPDF --stream-data=compress --object-streams=generate original.pdf'+
   ' compact.pdf');
 WriteLn('  QPDF a.pdf --pages . 1-3 b.pdf z-1 -- sortie.pdf');
 WriteLn('  QPDF --empty --pages a.pdf b.pdf -- fusion.pdf');
 WriteLn;
 WriteLn('Limites : les fichiers chiffres, --linearize et --qdf ne sont pas'+
   ' supportes.');
 WriteLn('Avec la manipulation de pages, signets, formulaires et destinations'+
   ' nommees');
 WriteLn('ne sont conserves que si toutes les pages restent dans l''ordre'+
   ' d''origine.');
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
Var
 I,P,NPos:Integer;
 S,Opt,OptVal,Pos1,Pos2,AngS:String;
 EndOpts:Boolean;
 V:Longint;
 Code:Integer;
 Dummy:TBuf;
Begin
 InName:='';OutName:='';NPos:=0;EndOpts:=False;Pos1:='';Pos2:='';
 BufInit(Dummy);
 I:=1;
 While I<=ParamCount Do Begin
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
     Else If(OptVal='generalized')or(OptVal='specialized')or(OptVal='all')Then
       DecodeOn:=True
     Else BadOpt(S);
   End
    Else
   If Opt='recompress-flate' Then RecompFlate:=True
    Else
   If Opt='optimize-jpeg' Then JpegOn:=True
    Else
   If Opt='jpeg-requant' Then Begin
    Val(OptVal,V,Code);
    If(Code<>0)or(V<100)or(V>1000)Then BadOpt(S);
    JpegOn:=True;JpegPct:=V;
   End
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
   If(Opt='verbose')or(Opt='no-original-object-ids')or(Opt='deterministic-id')
     or(Opt='static-id')Then
     Begin
    If Opt='verbose' Then Verbose:=True;
   End
    Else
   If Opt='empty' Then EmptyDoc:=True
    Else
   If Opt='remove-page-labels' Then RemoveLabels:=True
    Else
   If Opt='collate' Then Begin
    CollateOn:=True;CollateN:=1;
    If P>0 Then Begin
     CollateN:=StrNum(OptVal);
     If CollateN<1 Then BadOpt(S);
    End;
   End
    Else
   If Opt='split-pages' Then Begin
    SplitOn:=True;SplitN:=1;
    If P>0 Then Begin
     SplitN:=StrNum(OptVal);
     If SplitN<1 Then BadOpt(S);
    End;
   End
    Else
   If Opt='rotate' Then Begin
    If NRot>=8 Then BadOpt(S);
    Inc(NRot);
    P:=Pos(':',OptVal);
    If P>0 Then Begin
      AngS:=Copy(OptVal,1,P-1);RotRng[NRot]:=Copy(OptVal,P+1,255);End
           Else Begin AngS:=OptVal;RotRng[NRot]:='1-z';End;
    RotAbs[NRot]:=True;
    If(AngS<>'')and((AngS[1]='+')or(AngS[1]='-'))Then Begin
     RotAbs[NRot]:=False;
     V:=StrNum(Copy(AngS,2,255));
     If V<0 Then BadOpt(S);
     If AngS[1]='-' Then V:=-V;
    End
     Else
    Begin
     V:=StrNum(AngS);
     If V<0 Then BadOpt(S);
    End;
    If(V mod 90)<>0 Then BadOpt(S);
    RotAng[NRot]:=V;
    If Not ParseRange(RotRng[NRot],1000000,Dummy,False)Then BadOpt(S);
   End
    Else
   If Opt='pages' Then Begin
    NPgSpec:=0;
    Inc(I);
    While(I<=ParamCount)and(ParamStr(I)<>'--')Do Begin
     If NPgSpec>=MaxDocs Then BadOpt('--pages');
     Inc(NPgSpec);
     PgFile[NPgSpec]:=ParamStr(I);PgRng[NPgSpec]:='1-z';
     If(I<ParamCount)and(ParamStr(I+1)<>'--')and
       ParseRange(ParamStr(I+1),1000000,Dummy,False)Then Begin
      Inc(I);PgRng[NPgSpec]:=ParamStr(I);
     End;
     Inc(I);
    End;
    If NPgSpec=0 Then BadOpt('--pages');
   End
    Else
   If(Opt='overlay')or(Opt='underlay')Then Begin
    If NOvr>=MaxOvr Then BadOpt(S);
    Inc(I);
    If I>ParamCount Then BadOpt(S);
    Inc(NOvr);
    If Opt='overlay' Then OvrKind[NOvr]:=1 Else OvrKind[NOvr]:=0;
    OvrFile[NOvr]:=ParamStr(I);OvrFrom[NOvr]:='1-z';OvrRep[NOvr]:='';
      OvrTo[NOvr]:='1-z';
    Inc(I);
    While(I<=ParamCount)and(ParamStr(I)<>'--')Do Begin
     S:=ParamStr(I);
     P:=Pos('=',S);
     If(P>0)and(Copy(S,1,7)='--from=')Then OvrFrom[NOvr]:=Copy(S,P+1,255)
      Else
     If(P>0)and(Copy(S,1,9)='--repeat=')Then OvrRep[NOvr]:=Copy(S,P+1,255)
      Else
     If(P>0)and(Copy(S,1,5)='--to=')Then OvrTo[NOvr]:=Copy(S,P+1,255)
      Else
     BadOpt(S);
     Inc(I);
    End;
    If Not(ParseRange(OvrFrom[NOvr],1000000,Dummy,False)and
      ParseRange(OvrRep[NOvr],1000000,Dummy,False)
       and ParseRange(OvrTo[NOvr],1000000,Dummy,False))Then BadOpt('--'+Opt);
   End
    Else
   BadOpt(S);
  End
   Else
  Begin
   Inc(NPos);
   If NPos=1 Then Pos1:=S
    Else
   If NPos=2 Then Pos2:=S
    Else
   BadOpt(S);
  End;
  Inc(I);
 End;
 If EmptyDoc Then Begin
  OutName:=Pos1;
  If Pos2<>'' Then BadOpt(Pos2);
 End
  Else
 Begin
  InName:=Pos1;OutName:=Pos2;
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
 BufInit(Refs);BufInit(XRaw);BufInit(XDec);BufInit(RawX);BufInit(DecA);
   BufInit(DecB);
 BufInit(PredTmp);BufInit(XE);BufInit(OSBody);BufInit(OSHdr);BufInit(OSNums);
   BufInit(OSAll);
 BufInit(WRaw);BufInit(W1);BufInit(W2);BufInit(W3);BufInit(TB);BufInit(OB);
 WMode:=0;TopSkip:='';ExtraKind:=0;EmBuf:=NIL;
 DInit:=False;DForceStore:=False;
 CompressOn:=True;DecodeOn:=True;RecompFlate:=False;ObjMode:=1;Level:=9;
 JpegOn:=False;JpegPct:=100;BufInit(JApp);BufInit(JSof);
 CheckOnly:=False;ShowNPages:=False;KeepUnref:=False;
 MinVerMaj:=0;MinVerMin:=0;ForceMaj:=0;ForceMin:=0;
 StrChanged:=False;OutFlate:=False;OutFirst:=1;SLen:=0;
 NewRoot:=0;ForceNoTrailer:=False;
 CurDoc:=-1;NDocs:=0;SFOpen:=False;HasPrimary:=False;
 EmptyDoc:=False;RemoveLabels:=False;SplitOn:=False;CollateOn:=False;
 SplitN:=1;CollateN:=1;NPgSpec:=0;NRot:=0;NOvr:=0;
End;

Var
 N,SizeIn,SizeOut,NPages:Longint;
 SrcHasStm,UseNew:Boolean;
 R:PObjRec;
 F2:File;

BEGIN
 Init;
 If ParamCount=0 Then Begin
  ShowHelp;
  Halt(0);
 End;
 ParseArgs;
 UseNew:=EmptyDoc or(NPgSpec>0)or(NRot>0)or(NOvr>0)or SplitOn or CollateOn or
   RemoveLabels;
 If(InName='')and Not EmptyDoc Then Begin
  ErrLn('QPDF : aucun fichier d''entree. Essayez QPDF --help.');
  Halt(2);
 End;
 If(Not CheckOnly)and(Not ShowNPages)and(OutName='')Then Begin
  ErrLn('QPDF : aucun fichier de sortie. Essayez QPDF --help.');
  Halt(2);
 End;
 If(OutName<>'')and(OutName=InName)Then Begin
  ErrLn('QPDF : le fichier de sortie doit etre different du fichier'+
    ' d''entree.');
  Halt(2);
 End;
 If UseNew Then Begin
  If CheckOnly Then Fatal('--check ne peut pas etre combine avec la'+
    ' manipulation de pages.');
  RunPageOps;
 End
  Else
 Begin
  LoadStructure(InName);
  If ShowNPages Then Begin
   NPages:=CountPages;
   If NPages<0 Then Fatal('impossible de determiner le nombre de pages.');
   WriteLn(NPages);
  End
   Else
  If CheckOnly Then Begin
   CheckStreams;
   If Warnings=0 Then WriteLn('Aucune erreur de syntaxe ou d''encodage de flux'+
     ' n''a ete trouvee.')
   Else WriteLn('Des problemes ont ete trouves (',Warnings,''+
     ' avertissement(s)).');
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
     If SizeIn>=100 Then WriteLn('Gain             :'+
       ' ',(SizeIn-SizeOut)div(SizeIn div 100),' %');
     WriteLn('Objets conserves : ',NObj);
    End;
    FileMode:=2;
   End;
  End;
 End;
 CloseSource;
 If(Warnings>0)and Not WarnExit0 Then Halt(3);
END.
