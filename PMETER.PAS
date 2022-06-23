{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program PMETER;

{$M 8192,0,16384}

Uses DOS;

Var
 StartTime:LongInt;
 LogFile:Text;
 ModeTest:(_None,_TestFile,_TestExec);
 Count,I:Integer;
 Err:Word;
 LogName,FileName,ExecName:String;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function GetCurrTime:LongInt;
Var
 Hour,Min,Sec,Sec100:Word;
Begin
 GetTime(Hour,Min,Sec,Sec100);
 GetCurrTime:=Sec100+(Sec*100)+(Min*60*100)+(Hour*60*60*100);
End;

Procedure TestExec;
Begin
 For I:=1 to Count do Begin
  Exec(ExecName,'');
  If LogName<>''Then Begin
   WriteLn(LogFile,GetCurrTime-StartTime,' centiŠme de secondes',
           ' : Ex‚cution de ',ExecName);
   WriteLn(LogFile,'R‚sultat, Code de sortie ',
           DosExitCode,', Code d''erreur : ',DOSError);
  End;
 End;
End;

Procedure TestOpenFiles;
Var
 FileToOpen:File;
Begin
 For I:=1 to Count do Begin
  {$I-}Assign(FileToOpen,FileName);
  Reset(FileToOpen);{$I+}
  If LogName<>''Then Begin
   WriteLn(LogFile,GetCurrTime-StartTime,' centiŠme de secondes',
                   ' : Ouverture du fichier ',FileName);
   WriteLn(LogFile,'R‚sultat de l''ouverture : ',IoResult);
  End;
  Close(FileToOpen);
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('PMETER : Cette commande permet de faire des tests de charge.');
  WriteLn;
  WriteLn('Syntaxe : PMETER /FILE:nomdufichier /COUNT:nombre [/LOG:nomdufichier]');
  WriteLn('          PMETER /EXEC:nomdufichier /COUNT:nombre [/LOG:nomdufichier]');
  WriteLn;
  WriteLn(' /COUNT:nombre       Ce parametre permet d''indiquer le nombre de r‚p‚tition');
  WriteLn(' /EXEC:nomdufichier  Ce parametre permet d''indiquer le fichier ex‚cutable');
  WriteLn(' /FILE:nomdufichier  Ce parametre permet d''indiquer le fichier … ouvrir');
  WriteLn(' /LOG:nomdufichier   Ce parametre permet d''indiquer le fichier ',
                                'recevant les r‚sultats');
 End
  Else
 If ParamCount>0Then Begin
  ModeTest:=_None;
  FileName:='';
  ExecName:='';
  LogName:='';
  Count:=0;
  For I:=1 to ParamCount do Begin
   If Copy(StrToUpper(ParamStr(I)),1,7)='/COUNT:'Then Begin
    Val(Copy(ParamStr(I),8,255),Count,Err);
    If Err>0Then Begin
     WriteLn('Valeur de compteur invalide');
     Halt;
    End;
    If Count<=0Then Begin
     WriteLn('La valeur du compteur doit ˆtre sup‚rieur … 0.');
     Halt;
    End;
   End
    Else
   If Copy(StrToUpper(ParamStr(I)),1,6)='/EXEC:'Then Begin
    ModeTest:=_TestExec;
    ExecName:=Copy(ParamStr(I),7,255);
   End
    Else
   If Copy(StrToUpper(ParamStr(I)),1,6)='/FILE:'Then Begin
    ModeTest:=_TestFile;
    FileName:=Copy(ParamStr(I),7,255);
   End
    Else
   If Copy(StrToUpper(ParamStr(I)),1,5)='/LOG:'Then Begin
    LogName:=Copy(ParamStr(I),6,255);
   End
    Else
   Begin
    WriteLn('ParamŠtre inconnu');
    Halt;
   End;
  End;
  If LogName<>''Then Begin
   Assign(LogFile,LogName);
   {$I+}Rewrite(LogFile); {$I+}
   If IoResult<>0Then Begin
    WriteLn('Impossible de cr‚er le fichier de journal des op‚rations !');
    Halt;
   End;
  End;
  StartTime:=GetCurrTime;
  Case ModeTest of
   _None:WriteLn('Mode de test non-d‚fini');
   _TestFile:TestOpenFiles;
   _TestExec:TestExec;
  End;
  If LogName<>''Then Close(LogFile);
 End
  Else
 WriteLn('ParamŠtre requis');
END.