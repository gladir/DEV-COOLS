{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program DISOBJ;

Const
 RecBufSize=8192;
 LangText=0;
 LangTurboPascal=1;

var
 FileInput:File of byte;
 FileOutput:text;
 FileNameOBJ:String;
 FileNameOutput:String;
 Arg:String;
 OutputLanguage:Byte;
 i,rlen,rleft,dum:integer;
 chk,rect,d:byte;
 lname,sname,gname,ename:Array[0..100]of string[12];
 pname:Array[0..100]of string[64];
 pseg,pofs:Array[0..100]of Integer;
 si,gi,ei:integer;
 pi:Integer;
 RecBuf:array[1..RecBufSize] of byte;
 bufp:integer;

Function UpperStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 UpperStr:=S;
End;

Function StartsLanguageOption(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpperStr(S);
 StartsLanguageOption:=(Copy(U,1,10)='/LANGUAGE:') Or (Copy(U,1,10)='-LANGUAGE:');
End;

Procedure SetOutputLanguage(S:String);
Var
 U:String;
Begin
 U:=UpperStr(Copy(S,11,Length(S)-10));
 If (U='TURBOPASCAL') Or (U='TP') Then OutputLanguage:=LangTurboPascal Else
 If (U='TEXT') Or (U='TXT') Then OutputLanguage:=LangText Else Begin
  WriteLn('Langage de sortie inconnu : ',U);
  Halt;
 End;
End;

Function ToPascalIdent(S:String):String;
Var
 I:Integer;
 C:Char;
 R:String;
Begin
 R:='';
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If ((C>='A')And(C<='Z'))Or((C>='a')And(C<='z'))Or((C>='0')And(C<='9'))Or(C='_') Then R:=R+C
                            Else R:=R+'_';
 End;
 If R='' Then R:='ObjCode';
 C:=R[1];
 If Not(((C>='A')And(C<='Z'))Or((C>='a')And(C<='z'))) Then R:='Obj_'+R;
 If Length(R)>63 Then R:=Copy(R,1,63);
 ToPascalIdent:=R;
End;

Function FindPublic(Seg,Ofs:Integer):Integer;
Var
 I:Integer;
Begin
 FindPublic:=0;
 For I:=1 To pi Do If (pseg[I]=Seg)And(pofs[I]=Ofs) Then FindPublic:=I;
End;

Procedure Error(S:String);Begin
 WriteLn(FileOutput);
 WriteLn(FileOutput,'Erreur :',S);
 Close(FileInput);
 Close(FileOutput);
 Halt;
End;

Function ByteHex2Str(value:Byte):String;
Const
 matrix:Array[0..15]of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Begin
 ByteHex2Str:=matrix[(value shr 4) and $0F]+matrix[value and $F];
End;

Function HexWord2Str(value:Word):String;Begin
 HexWord2Str:=ByteHex2Str(Hi(value))+ByteHex2Str(Lo(value));
End;

Function GeneratedProcName(Seg,Ofs:Integer):String;
Var
 P:Integer;
Begin
 P:=FindPublic(Seg,Ofs);
 If P<>0 Then GeneratedProcName:=ToPascalIdent(pname[P])
   Else GeneratedProcName:='ObjCode_'+HexWord2Str(Seg)+'_'+HexWord2Str(Ofs);
End;

Function GetB:Byte;
Var
 d:Byte;
Begin
 d:=RecBuf[bufp];
 bufp:=bufp+1;
 chk:=(chk+d) and 255;
 getb:=d;
 RLeft:=RLeft-1
End;

Function GetName:String;
Var
 I:Byte;
 S:String;
Begin
 S:='';
 For I:=1 to GetB do S:=S+Char(GetB);
 GetName:=S;
End;

Function GetI:Integer;
Var
 D:Integer;
Begin
 D:=GetB;
 GetI:=D+GetB*256;
End;

Function GetX:Integer;
Var d:Integer;
Begin
 d:=getb;
 If d<=127 Then getx:=d
           Else getx:=(d and $7F)*256+getb
End;

Procedure ChkSum;Begin
 dum:=getb;
 If chk<>0 Then Write('..mauvaise sommation de v'+#130+'rification..',chk)
End;

Procedure SkipRecord;
Begin
 RLen:=GetI;
 RLeft:=RLen;
 While RLeft>1 Do Dum:=GetB;
End;

Function Bit(D,N:byte):Boolean;Begin
 Bit:=Boolean((D shr (N-1)) and 1);
End;

Function Fld(d,n,l:byte):Byte;Begin
 Fld:=d shr (n-1) and ((1 shl l)-1)
End;

Procedure LogicalRef;
Var
 p:Boolean;
Begin
 d:=getb;
 If bit(d,8)Then Write(FileOutput,'  FR:THREAD #',fld(d,5,3))
  Else
 Begin
  Write(FileOutput,'  FR: ');
  Case fld(d,5,3) of  { Seulement F0..F5 est autoris� }
   0:Write(FileOutput,'SEG(',sname[getx],')');
   1:Write(FileOutput,'GRP(',gname[getx],')');
   2:Write(FileOutput,'EXT(',ename[getx],')');
   3:Write(FileOutput,'AT ',HexWord2Str(getx));
   4:Write(FileOutput,'LOCATION');
   5:Write(FileOutput,'TARGET  ');
   6:Write(FileOutput,'  NONE  ')
   Else Error('Mauvais cadre')
  End
 End;
 If bit(d,4)Then Begin
  Write(FileOutput,'   TG:THREAD #',fld(d,1,2));
  If not bit(d,3)Then Write(FileOutput,' ,',HexWord2Str(geti))
 End
  Else
 Begin
  Write(FileOutput,'   TG: ');
  Case fld(d,1,3) of
   0:write(FileOutput,'SEG(',sname[getx],'),',HexWord2Str(geti));
   1:write(FileOutput,'GRP(',gname[getx],'),',HexWord2Str(geti));
   2:write(FileOutput,'EXT(',ename[getx],'),',HexWord2Str(geti));
   3:write(FileOutput,'AT ',HexWord2Str(getx));
   4:write(FileOutput,'SEG(',sname[getx],')');
   5:write(FileOutput,'GRP(',gname[getx],')');
   6:write(FileOutput,'EXT(',ename[getx],')');
   Else Error('Mauvaise destination');
  End
 End
End;

Procedure RHEADR;
Var
 S:String;
Begin
 RLen:=GetI;
 RLeft:=RLen;
 S:=GetName;
 If OutputLanguage<>LangTurboPascal Then Begin
  Write(FileOutput,rlen:6,' R-MODULE: ':15);
  Write(FileOutput,S);
  While RLeft>1 Do Write(FileOutput,ByteHex2Str(GetB):4);
 End
  Else
 While RLeft>1 Do Dum:=GetB;
End;

Procedure REGINT;Begin
 RLen:=GetI;
 RLeft:=RLen;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,rlen:6,' REGINT: ');
 While RLeft>1 Do Begin
  D:=GetB;
  If OutputLanguage<>LangTurboPascal Then Write(FileOutput,ByteHex2Str(D):4);
 End;
End;

Procedure REDATA;Begin
 RLen:=GetI;
 RLeft:=RLen;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,rlen:6,' REDATA: ');
 While RLeft>1 Do Begin
  D:=GetB;
  If OutputLanguage<>LangTurboPascal Then Write(FileOutput,ByteHex2Str(D):4);
 End;
End;

Procedure RIDATA;Begin
 Error('Balise RIDATA non impl'+#130+'ment'+#130+'.');
End;

Procedure OVLDEF;Begin
 Error('Balise OVLDEF non impl'+#130+'ment'+#130+'.');
End;

Procedure ENDREC;Begin
 Error('Balise ENDREC non impl'+#130+'ment'+#130+'.');
End;

Procedure BLKREC;
Var
 sg,gr:Integer;
Begin
 rlen:=geti;
 rleft:=rlen;
 WriteLn(FileOutput,rlen:6,' BLKREC: ');
 gr:=getx; sg:=getx;
 Write(FileOutput,getname);
 If(gr=0)and(sg<>0)Then Write(FileOutput,'  dans SEG( ',sname[sg],' )  ')
                   Else Error('Combinaison de groupe et de segment invalide pour le BLOC');
 Write(' '+#133+' ', HexWord2Str(geti),' longueur= ',HexWord2Str(geti),'    ');
 While rleft>1 do Write(FileOutput,ByteHex2Str(getb):4)
End;

Procedure BLKEND;Begin
 rlen:=geti;
 rleft:=rlen;
 Writeln(FileOutput,rlen:6,' BLKEND');
 If rlen<>1 Then Error( 'Bloc de fin n''est pas d''une longueur d''un octet');
End;

Procedure DEBSYM;Begin
 Error('Balise DEBSYM non impl'+#130+'ment'+#130+'.');
End;

Procedure THEADR;
Var
 S:String;
Begin
 RLen:=GetI;
 RLeft:=RLen;
 S:=GetName;
 If OutputLanguage<>LangTurboPascal Then Begin
  Write(FileOutput,rlen:6,' T-MODULE: ':15);
  Write(FileOutput,S);
 End;
End;

Procedure LHEADR;Begin
 Error('Balise LHEADR non impl'+#130+'ment'+#130+'.');
End;

Procedure PEDATA;Begin
 Error('Balise PEDATA non impl'+#130+'ment'+#130+'.');
End;

Procedure PIDATA;Begin
 Error('Balise PIDATA non impl'+#130+'ment'+#130+'.');
End;

Procedure COMENT;Begin
 rlen:=geti;
 Write(FileOutput,rlen:6,' COMMENTAIRE, ':15);
 d:=getb;
 If($80 and d)<>0 Then Write(FileOutput,'NoPurge, ');
 If($40 and d)<>0 Then Write(FileOutput,'NoList, ');
 Write(FileOutput,'Class=',getb,': ');
 For i:=4 to rlen do Write(FileOutput,char(getb))
End;

Procedure MODEND;Begin
 Write(FileOutput,geti:6,' MODEND:');
 d:=getb;
 If bit(d,8)Then Write(FileOutput,'PRINCIPAL, ')
            Else Write(FileOutput,'NON_PRINCIPAL');
 If fld(d,2,5)<>0 Then Error('Erreur de format de type de module');
 If bit(d,7) Then Begin
  If bit(d,1)Then LogicalRef
             Else Error('Adresse de d'+#130+'but physique');
 End;
End;

Procedure MODENDL;Begin
 rlen:=GetI;
 rleft:=rlen;
 Write(FileOutput,rlen:6,' EXTERNE:');
 While rleft>2 do Begin
  ei:=ei+1;
  EName[ei]:=GetName;
  WriteLn(FileOutput);
  Write(FileOutput,'"'+EName[ei]+'"':10,' , type #',GetX)
 End
End;

Procedure TYPDEF;
Var
 v:Real;
Begin
 RLen:=GetI;
 RLeft:=rlen;
 Write(FileOutput,rlen:6,' TYPDEF:',GetName);
 While rleft>1 do Begin
  WriteLn(FileOutput);
  Write(FileOutput,ByteHex2Str(getb),':');
  i:=1;
  Repeat
   i:=i+1;
   d:=GetB;
   v:=0;
   Case d of
    0..128: write(FileOutput,d);
    129:write(FileOutput,HexWord2Str(geti));
    132:Begin
     v:=GetB;
     v:=GetB*256+v;
     v:=GetB*65536.0+v;
     write(FileOutput,v:8:0)
    End;
    136:Begin
     v:=GetB;
     v:=GetB*256+v;
     v:=GetB*65536.0+v;
     v:=GetB*16777216.0+v;
     write(FileOutput,v:8:0)
    End;
    Else Error('Mauvaise feuille de champ de descripteur');
   End;
   Write(FileOutput,' ');
  Until (i>8)or(RLeft<=1);
 End;
End;

Procedure PUBDEF;
Var
 gr,sg:Integer;
 PublicName:String;
 PublicOfs,PublicType:Integer;
Begin
 rlen:=geti;
 rleft:=rlen;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,rlen:6,' PUBLICS  ');
 gr:=getx;
 sg:=getx;
 If(gr=0)and(sg=0)Then Begin
  PublicOfs:=GetI;
  If OutputLanguage<>LangTurboPascal Then Write(FileOutput,' CADRE=',HexWord2Str(PublicOfs));
 End
  Else
 If OutputLanguage<>LangTurboPascal Then Begin
  If gr<>0 Then Write(FileOutput,'pour Gr= ',gname[gr],' Seg=',sname[sg])
           Else Write(FileOutput,'pour Seg= ',sname[sg]);
 End;
 While rleft>1 do Begin
  PublicName:=GetName;
  PublicOfs:=GetI;
  PublicType:=GetX;
  If pi<100 Then Begin
   pi:=pi+1;
   pname[pi]:=PublicName;
   pseg[pi]:=sg;
   pofs[pi]:=PublicOfs;
  End;
  If OutputLanguage<>LangTurboPascal Then Begin
   WriteLn(FileOutput);
   Write(FileOutput,PublicName:30,' '+#133+' ',HexWord2Str(PublicOfs),' , type=',PublicType)
  End;
 End;
End;

Procedure PUBDEFL;Begin
 Error('Balise PUBDEFL non impl'+#130+'ment'+#130+'.');
End;

Procedure LOCSYM;Begin
 Error('Balise LOCSYM non impl'+#130+'ment'+#130+'.');
End;

Procedure LINNUM;Begin
 rlen:=geti;
 rleft:=rlen;
 Writeln(FileOutput,rlen:6,' Num'+#130+'ro de lignes:' );
 dum:=getx;
 Write(FileOutput,{' Gr:',gname[getx],}' Seg:',sname[getx]);
 While rleft>1 do Begin
  WriteLn(FileOutput);
  Write(FileOutput,'LIGNE: ',geti:6,' '+#133+' ',HexWord2Str(geti));
 End;
End;

Procedure LNAMES;
Var
 ni:Integer;
Begin
 rlen:=geti;
 If OutputLanguage<>LangTurboPascal Then WriteLn(FileOutput,rlen:6,'LNAMES:':15);
 rleft:=rlen;i:=1;ni:=1; lname[0]:='????';
 Repeat
  lname[ni]:=getname;
  If OutputLanguage<>LangTurboPascal Then Write(FileOutput,i:6,': ',lname[ni]:12);
  i:=i+1;ni:=ni+1
 Until rleft<=1;
End;

Procedure SEGDEF;
Var
 fr,ofs,len,w,SegName,ClassName:Integer;
Begin
 fr:=0; ofs:=0;
 RLen:=GetI;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,rlen:6);
 d:=getb;
 If(d and 1)<>0 then Error('Page resident bit=1');
 If fld(d,6,3)=0 then Begin
  fr:=geti;
  ofs:=getb
 End;
 Len:=GetI;
 si:=si+1;
 SegName:=GetX;
 sname[si]:=lname[SegName];
 If OutputLanguage<>LangTurboPascal Then Begin
  Write(FileOutput,' SEGM(',sname[si]:12,' )   ');
  Case fld(d,6,3) of
   0:Write(FileOutput,' '+#133+' ',HexWord2Str(fr):4,':',HexWord2Str(ofs):2);
   1:Write(FileOutput,'BYTE');
   2:Write(FileOutput,'WORD');
   3:Write(FileOutput,'PARA');
   4:Write(FileOutput,'PAGE')
  End;
  Case fld(d,3,3) of
   0:If(d shr 5)<>0 Then Write(FileOutput,' NOCOMB');
   1,3:Error('Mauvaise combination de type');
   2,4,7:Write(FileOutput,' PUBLIC');
   5:    Write(FileOutput,'  STACK');
   6:    Write(FileOutput,' COMMON')
  End;
  Write(FileOutput,' SIZE=');
  If bit(d,2)Then Write(FileOutput,'10000')
             Else Write(FileOutput,HexWord2Str(len));
 End
  Else
 Begin
  Case fld(d,3,3) of
   1,3:Error('Mauvaise combination de type');
  End;
 End;
 ClassName:=GetX;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,' Class:',lname[ClassName]:8);
 w:=GetX;
 If (OutputLanguage<>LangTurboPascal)And(lname[w]<>'') then Write(FileOutput,' Recouvrement:',lname[w]:8);
End;

Procedure SEGDEFL;Begin
 Error('Balise SEGDEFL non impl'+#130+'ment'+#130+'.');
End;

Procedure GRPDEF;Begin
 rlen:=geti;
 rleft:=rlen;
 gi:=gi+1;
 gname[gi]:=lname[getx];
 Write(FileOutput, rlen:6,' GROUPE: ',gname[gi],' de ');
 While rleft>1 do If getb<>$FF Then Error('Mauvais descripteur de groupe')
                               Else Write(FileOutput,sname[getx],' ');
End;

Procedure FIXUPP;
Var
 Fr,P:Boolean;
 M:Byte;
 Dro:Integer;
Begin
 RLen:=GetI;
 RLeft:=RLen;
 Write(FileOutput,rlen:6,' FIXUPP: ');
 While rleft>1 do Begin
  WriteLn(FileOutput);
  d:=getb;
  If Not bit(d,8) Then Begin
   m:=fld(d,3,3);
   fr:=bit(d,7);
   If bit(d,6)Then Error('Processus l'+#130+'ger Z_bit=1');
   Write(FileOutput,'     TRD #',fld(d,1,2),'   ');
   If fr Then Begin
    Case m of
     0:write(FileOutput,'FR:SEG(',sname[getx],')');
     1:write(FileOutput,'FR:GRP(',gname[getx],')');
     2:write(FileOutput,'FR:EXT(',ename[getx],')');
     3:write(FileOutput,'FR:AT ',HexWord2Str(getx));
     4:write(FileOutput,'LOCATION');
     5:write(FileOutput,'TARGET  ');
     6:write(FileOutput,'  NONE  ')
     Else Error('Mauvais cadre')
   End;
   End
    Else
   Begin
    Case m of
     0:write(FileOutput,'TG:SEG(',sname[getx],'), xxxx');
     1:write(FileOutput,'TG:GRP(',gname[getx],'), xxxx');
     2:write(FileOutput,'TG:EXT(',ename[getx],'), xxxx');
     3:write(FileOutput,'TG:AT ',HexWord2Str(getx));
     4:write(FileOutput,'TG:SEG(',sname[getx],')');
     5:write(FileOutput,'TG:GRP(',gname[getx],')');
     6:write(FileOutput,'TG:EXT(',ename[getx],')');
     Else Error('Mauvaise destination');
    End;
   End;
  End
   Else
  Begin
   Write(FileOutput,' FIXUP: ');
   If bit(d,7)Then Write(FileOutput,' SEGM-REL,')
              Else Write(FileOutput,' SELF-REL,');
   If bit(d,6) then Error('Mauvaise longueur de destination ou mal-plac'+#130+'');
   Case fld(d,3,3) of
    0:write(FileOutput,'LOBYTE ,');
    1:write(FileOutput,'OFFSET ,');
    2:write(FileOutput,'BASE   ,');
    3:write(FileOutput,'POINTER,');
    4:write(FileOutput,'HIBYTE ,')
    Else Error('Type d''emplacement invalide')
   End;
   Write(FileOutput,'DRO=',HexWord2Str(256*fld(d,1,2)+getb):4,'  ');
   LogicalRef;
  End
 End
End;

Procedure WriteTurboPascalData(Seg,Ofs:Integer);
Var
 Cn:Byte;
Begin
 WriteLn(FileOutput,'Function ',GeneratedProcName(Seg,Ofs),':Boolean;Assembler;');
 WriteLn(FileOutput,'ASM');
 While RLeft<>1 Do Begin
  Write(FileOutput,' DB ');
  Cn:=0;
  While (Cn<12) And (RLeft<>1) Do Begin
   d:=GetB;
   If Cn<>0 Then Write(FileOutput,',');
   Write(FileOutput,'$',ByteHex2Str(d));
   Cn:=Cn+1;
  End;
  WriteLn(FileOutput);
 End;
 WriteLn(FileOutput,'END;');
End;

Procedure LEDATA;
Var
 cn,I:byte;
 ofs,Seg:Integer;
 St:String[16];
Begin
 rlen:=GetI;
 rleft:=rlen;
 Seg:=GetX;
 If OutputLanguage<>LangTurboPascal Then Write(FileOutput,rlen:6,' ENUMERATION DE DONNEES pour ',sname[Seg],' DEPLACEMENT=');
 ofs:=(geti);
 If OutputLanguage=LangTurboPascal Then Begin
  WriteTurboPascalData(Seg,Ofs);
  Exit;
 End;
 writeln(FileOutput,HexWord2Str(ofs));
 Repeat
 cn:=0;st:='';
 Write(FileOutput,HexWord2Str(ofs),': ');
 ofs:=ofs+16;
 While (cn<16) and (rleft<>1) do Begin
  D:=GetB;
  Write(FileOutput,ByteHex2Str(d),' ');
  If cn=7 Then Write(FileOutput,'- ');
  d:=d and $7F;
  If d<32 Then st:=st+'.'
          Else st:=st+chr(d);
   cn:=cn+1;
  End;
  For i:=cn to 16 do Write(FileOutput,'   ');
  WriteLn(FileOutput,st);
 Until rleft=1;
End;

Procedure LEDATAL;Begin
 Error('Balise LEDATAL non impl'+#130+'ment'+#130+'.');
End;

Procedure LIDATA;

 Procedure IteratedBlock;
 Var
  blc,i,j:Integer;
 Begin
  Write(FileOutput,GetI,'*/');
  blc:=geti;
  If blc=0 Then For i:=1 to getb do Write(FileOutput,ByteHex2Str(getb):3)
           Else For j:=1 to blc do IteratedBlock;
  Write(FileOutput,'/')
 End;

Begin
 rlen:=geti;
 rleft:=rlen;
 WriteLn(FileOutput,rlen:6,' DONNEES ITERATIVE pour ',sname[getx],' DEPLACEMENT=',HexWord2Str(geti));
 While rleft>1 do IteratedBlock
End;

Procedure LIDATAL;Begin
 Error('Balise LIDATAL non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBHED;Begin
 Error('Balise LIBHED non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBNAM;Begin
 Error('Balise LIDATAL non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBLOC;Begin
 Error('Balise LIDATAL non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBDIC;Begin
 Error('Balise LIDATAL non impl'+#130+'ment'+#130+'.');
End;

Procedure COMDEF;Begin
 rlen:=geti;
 rleft:=rlen;
 Write(FileOutput,rlen:6,' COMDEF:');
 While rleft>2 do Begin
  ei:=ei+1; ename[ei]:=getname;
  WriteLn(FileOutput);
  Write(FileOutput,'"'+ename[ei]+'"':10,' , type #',getx,'  ',ByteHex2Str(getb),ByteHex2Str(getb));
 End;
End;

Procedure LEXTDEF;Begin
 Error('Balise LEXTDEF non impl'+#130+'ment'+#130+'.');
End;

Procedure LPUBDEF;Begin
 Error('Balise LPUBDEF non impl'+#130+'ment'+#130+'.');
End;

Procedure LPUBDF2;Begin
 Error('Balise LPUBDF2 non impl'+#130+'ment'+#130+'.');
End;

Procedure LCOMDEF;Begin
 Error('Balise LCOMDEF non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBHDR;Begin
 Error('Balise LIBHDR non impl'+#130+'ment'+#130+'.');
End;

Procedure LIBEND;Begin
 Error('Balise LIBEND non impl'+#130+'ment'+#130+'.');
End;

Procedure GetRecordToBuffer;
Var
 i,rlen:Integer;
 chk:byte;
Begin
 bufp:=1; chk:=0;
 Read(FileInput,RecBuf[1]);
 Read(FileInput,RecBuf[2]);
 Read(FileInput,RecBuf[3]);
 rlen:=RecBuf[2]+256*RecBuf[3]+3;
 chk:=(RecBuf[1]+RecBuf[2]+RecBuf[3]) and 255;
 If rlen<RecBufSize Then For I:=4 to rlen do Begin
  If Not EOF(FileInput)Then Begin
   Read(FileInput,RecBuf[i]);
   chk:=(chk+RecBuf[i]) and 255;
  End
   Else
  Error('Fin du fichier -- Pas d''enregistrement')
 End
  else
 Error('Enregistrement trop long');
 If chk<>0 Then WriteLn('Sommation de v�rification du tampon : ',chk);
End;

Procedure ProcessRecord;Begin
 chk:=0;
 GetRecordToBuffer;
 Rect:=GetB;
 If OutputLanguage=LangTurboPascal Then Begin
  Case rect of
   $6E:RHEADR;
    $70:REGINT;
  $72:REDATA;
   $74:SkipRecord;
   $76:SkipRecord;
   $78:SkipRecord;
   $7A:SkipRecord;
   $7C:SkipRecord;
   $7E:SkipRecord;
   $80:THEADR;
   $82:SkipRecord;
   $84:SkipRecord;
   $86:SkipRecord;
   $88:SkipRecord;
   $8A:SkipRecord;
   $8C:SkipRecord;
   $8E:SkipRecord;
   $90:PUBDEF;
   $91:SkipRecord;
   $92:SkipRecord;
   $94:SkipRecord;
   $96:LNAMES;
   $98:SEGDEF;
   $99:SkipRecord;
   $9A:SkipRecord;
   $9C:SkipRecord;
   $9D:SkipRecord;
   $A0:LEDATA;
   $A1:SkipRecord;
   $A2:SkipRecord;
   $A3:SkipRecord;
   $A4:SkipRecord;
   $A6:SkipRecord;
   $A8:SkipRecord;
   $AA:SkipRecord;
   $B0:SkipRecord;
   $B4:SkipRecord;
   $B6:SkipRecord;
   $B7:SkipRecord;
   $B8:SkipRecord;
   $F0:SkipRecord;
   $F1:SkipRecord;
   Else SkipRecord;
  End;
 End
  Else
 Begin
  Case rect of
   $6E:RHEADR;
   $70:REGINT;
   $72:REDATA;
   $74:RIDATA;
   $76:OVLDEF;
   $78:ENDREC;
   $7A:BLKREC;
   $7C:BLKEND;
   $7E:DEBSYM;
   $80:THEADR;
   $82:LHEADR;
   $84:PEDATA;
   $86:PIDATA;
   $88:COMENT;
   $8A:MODEND;
   $8C:MODENDL;
   $8E:TYPDEF;
   $90:PUBDEF;
   $91:PUBDEFL;
   $92:LOCSYM;
   $94:LINNUM;
   $96:LNAMES;
   $98:SEGDEF;
   $99:SEGDEFL;
   $9A:GRPDEF;
   $9C:FIXUPP;
   $9D:{FIXUPP};
   $A0:LEDATA;
   $A1:LEDATAL;
   $A2:LIDATA;
   $A3:LIDATAL;
   $A4:LIBHED;
   $A6:LIBNAM;
   $A8:LIBLOC;
   $AA:LIBDIC;
   $B0:COMDEF;
   $B4:LEXTDEF;
   $B6:LPUBDEF;
   $B7:LPUBDF2;
   $B8:LCOMDEF;
   $F0:LIBHDR;
   $F1:LIBEND;
   Else Begin
    RLen:=GetI;
    RLeft:=RLen;
    WriteLn(FileOutput,rlen:6,' Inconnu:',ByteHex2Str(Rect));
    While rleft>1 do Write(FileOutput,ByteHex2Str(GetB):4);
   End;
  End;
 End;
 ChkSum;
 If OutputLanguage<>LangTurboPascal Then WriteLn(FileOutput)
                                  Else If Rect=$A0 Then WriteLn(FileOutput);
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('DISOBJ : Cette commande permet d''analyser et ',
                  ' de d'+#130+'sassembler un fichier .OBJ');
  WriteLn;
  WriteLn('Syntaxe : DISOBJ [fichier-obj] [sortie] [/LANGUAGE:TEXT|TURBOPASCAL|TP] ');
 End
  Else
 Begin
  FileNameOutput:='';
  OutputLanguage:=LangText;
  If ParamCount=0 Then Begin
    Write('Entr'+#130+'e :');
    ReadLn(FileNameOBJ);
    If Pos('.',FileNameOBJ)=0 Then FileNameOBJ:=FileNameOBJ+'.OBJ';
    Assign(FileInput,FileNameOBJ);
    Write('Sortie :');
    ReadLn(FileNameOutput);
    If FileNameOutput='' Then FileNameOutput:='CON';
    Assign(FileOutput,FileNameOutput)
  End
   Else
  Begin
   FileNameOBJ:='';
   For i:=1 To ParamCount Do Begin
    Arg:=ParamStr(i);
    If StartsLanguageOption(Arg) Then SetOutputLanguage(Arg) Else
    If FileNameOBJ='' Then FileNameOBJ:=Arg Else
    If FileNameOutput='' Then FileNameOutput:=Arg Else Begin
     WriteLn('Param'+#138+'tre invalide');
     Halt;
    End;
   End;
   If FileNameOBJ='' Then Begin
    WriteLn('Param'+#138+'tre invalide');
    Halt;
   End;
    If FileNameOutput='' Then Assign(FileOutput,'CON')
     Else Begin
     If (OutputLanguage=LangTurboPascal)And(Pos('.',FileNameOutput)=0)And(UpperStr(FileNameOutput)<>'CON') Then FileNameOutput:=FileNameOutput+'.PAS';
     Assign(FileOutput,FileNameOutput);
    End;
  End;
  If Pos('.',FileNameOBJ)=0 Then FileNameOBJ:=FileNameOBJ+'.OBJ';
  Assign(FileInput,FileNameOBJ);
  {$I-} Reset(FileInput);{$I+}
  If IoResult<>0 Then Begin
   WriteLn('Le fichier .OBJ ',FileNameOBJ, ' est introuvable');
   Halt;
  End;
  Rewrite(FileOutput);
  si:=0;gi:=0;ei:=0;pi:=0;
  SName[0]:='????';
  GName[0]:='';
  EName[0]:='????';
  While Not Eof(FileInput) do ProcessRecord;
  Close(FileInput);
  Close(FileOutput);
 End;
END.