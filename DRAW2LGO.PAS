{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program Draw2Logo;

Var
 SourceBASIC,TargetLOGO:Text;
 CurrLine:String;
 DrawS:Integer;
 XL:Integer;
 YL:Integer;
 I:Byte;
 Mode:(_None_,_NoTrace_,_UnMove_);
 a,b:Integer;
 xc,yc:(NoMove,Add,Sub);

Function ExtractNm(S:String):Integer;
Var
 N:String;
 a,b:Integer;
Begin
 N:='';
 While(I<=Length(S))and(S[I] in ['0'..'9'])do Begin
  N:=N+S[I];
  Inc(I);
 End;
 If N=''Then a:=1
        Else Val(N,a,b);
 ExtractNm:=a;
End;

Function ExtractNmV(S:String):Integer;Begin
 ExtractNmV:=ExtractNm(S)*(DrawS shr 2)
End;

Procedure DrawString2Logo(S:String);Begin
 I:=1;Mode:=_None_;
 WriteLn(TargetLOGO,'PENDOWN');
 While I<=Length(S)do Begin
  Inc(I);
  Case S[I-1]of
   'B':Begin
    Mode:=_NoTrace_;
    WriteLn(TargetLOGO,'PENUP');
   End;
   'C':Begin
    WriteLn(TargetLOGO,'COLOR ',ExtractNm(S));
   End;
   'D':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 270');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -270');
   End;
   'E':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 45');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -45');
   End;
   'F':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 315');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -315');
   End;
   'G':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 225');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -225');
   End;
   'H':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 135');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -135');
   End;
   'L':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'LEFT ',a);
    WriteLn(TargetLOGO,'ANGLE 90');
   End;
   'M':Begin
    If S[I]in['+','-']Then Begin
     If S[I]='+'Then xc:=Add else xc:=Sub;
     Inc(I);
    End;
    a:=ExtractNm(S);
    If S[I]=','Then Begin
     Inc(I);
     If S[I]in['+','-']Then Begin
      If S[I]='+'Then yc:=Add else yc:=Sub;
      Inc(I);
     End;
     b:=ExtractNm(S);
    End
     Else
    b:=YL;
    WriteLn(TargetLOGO,'SETPOSITION ',a,' ',b);
    If(Mode=_NoTrace_)Then Begin
     WriteLn(TargetLOGO,'PENDOWN');
     Mode:=_None_;
    End;
   End;
   'N':Mode:=_UnMove_;
   'R':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'RIGHT ',a);
    WriteLn(TargetLOGO,'ANGLE -90');
   End;
   'U':Begin
    a:=ExtractNmV(S);
    WriteLn(TargetLOGO,'ANGLE 90');
    WriteLn(TargetLOGO,'FORWARD ',a);
    WriteLn(TargetLOGO,'ANGLE -90');
   End;
   ' ',';':;{C'est 2 caractŠres ne change rien en soit, donc...pas d'arrˆt!}
   Else Exit;
  End
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('DRAW2LGO : Cette commande permet de convertir les chaŒnes de ',
          'caractŠres DRAW du langage de programmation BASIC en ',
          'instruction du langage de programmation LOGO.');
  WriteLn;
  WriteLn('Syntaxe : DRAW2LGO nomdufichier.BAS nomdufichier.LGO');
 End
  Else
 If ParamCount>0Then Begin
  DrawS:=4;
  XL:=160;
  YL:=100;
  Assign(SourceBASIC,ParamStr(1));
  {$I-}Reset(SourceBASIC);{$I+}
  If IoResult<>0Then Begin
   WriteLn('Fichier BASIC introuvable !');
   Halt;
  End;
  Assign(TargetLOGO,ParamStr(2));
  {$I+}Rewrite(TargetLOGO); {$I+}
  If IoResult<>0Then Begin
   WriteLn('Impossible de cr‚er le fichier LOGO !');
   Close(SourceBASIC);
   Halt;
  End;
  While Not EOF(SourceBASIC)do Begin
   ReadLn(SourceBASIC,CurrLine);
   DrawString2Logo(CurrLine);
  End;
  Close(TargetLOGO);
  Close(SourceBASIC);
 End;
END.