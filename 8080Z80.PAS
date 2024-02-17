{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program _8080Z80;

Var
 Source8080:Text;
 CurrLine:String;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function Space(L:Byte):String;
Var
 S:String;
Begin
 If(L=0)Then Space:=''
  else
 Begin
  FillChar(S[1],L,' ');
  S[0]:=Char(L);
  Space:=S;
 End;
End;

Function ProcessLine:String;
Var
 I:Integer;
 CellPos:Byte;
 SpaceLeft:Byte;
 Cells:Array[0..3]of String;
 Rem:String;
Begin
 CellPos:=0;
 FillChar(Cells,SizeOf(Cells),0);
 Rem:='';
 SpaceLeft:=0;
 For I:=1 to Length(CurrLine)do Begin
  If CurrLine[I]=#9 Then Inc(SpaceLeft,8)
   Else
  Begin
   If CurrLine[I]<>' 'Then Break;
   Inc(SpaceLeft);
  End;
 End;
 For I:=1 to Length(CurrLine)do Begin
  If CurrLine[I]=';'Then Begin
   Rem:=' '+Copy(CurrLine,I,255);
   Break;
  End;
  If CurrLine[I] in[#9,' ',',']Then Begin
   If Cells[CellPos]<>''Then Begin
    If CellPos<=3 Then Inc(CellPos);
   End;
  End
   Else
  Cells[CellPos]:=Cells[CellPos]+CurrLine[I];
 End;
 If StrToUpper(Cells[0])='ACI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'ADC A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ADC'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'ADC A,(HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'ADC A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ADD'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'ADD A,(HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'ADD A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ADI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'ADD A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ANA'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'AND (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'AND '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ANI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'AND '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL C,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CM'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL M,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CMA'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CPL'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CMC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CCF'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CMP'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'CP (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'CP '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CNC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL NC,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CNZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL NZ,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CP'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL P,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CPE'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL PE,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CPI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CP '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CPO'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL PO,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='CZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'CALL Z,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='DAD'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'ADD HL,BC'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'ADD HL,DE'+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'ADD HL,HL'+Rem Else
  If StrToUpper(Cells[1])='SP'Then ProcessLine:=Space(SpaceLeft)+'ADD HL,SP'+Rem
                              Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='DCR'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'DEC (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'DEC '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='DCX'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'DEC BC'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'DEC DE,'+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'DEC HL,'+Rem Else
  If StrToUpper(Cells[1])='SP'Then ProcessLine:=Space(SpaceLeft)+'DEC SP,'+Rem
                              Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='IN'Then Begin
  ProcessLine:=Space(SpaceLeft)+'IN A,('+Cells[1]+')'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='INR'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'INC (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'INC '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='INX'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'INC BC'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'INC DE,'+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'INC HL,'+Rem Else
  If StrToUpper(Cells[1])='SP'Then ProcessLine:=Space(SpaceLeft)+'INC SP,'+Rem
                              Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='JC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP C,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JM'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP M,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JMP'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JNC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP NC,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JNZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP NZ,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JP'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP P,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JPE'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP PE,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JPO'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP PO,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='JZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP Z,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='LHLD'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD HL,('+Cells[1]+')'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='LXI'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'LD BC,'+Cells[2]+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'LD DE,'+Cells[2]+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'LD HL,'+Cells[2]+Rem Else
  If StrToUpper(Cells[1])='SP'Then ProcessLine:=Space(SpaceLeft)+'LD SP,'+Cells[2]+Rem
                              Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='MOV'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD '+Cells[1]+','+Cells[2]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='MVI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD '+Cells[1]+','+Cells[2]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ORA'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'OR (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'OR '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='ORI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'OR '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='OUT'Then Begin
  ProcessLine:=Space(SpaceLeft)+'OUT ('+Cells[1]+'),A'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='PCHL'Then Begin
  ProcessLine:=Space(SpaceLeft)+'JP (HL)'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='POP'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'POP BC'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'POP DE'+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'POP HL'+Rem Else
  If StrToUpper(Cells[1])='PSW'Then ProcessLine:=Space(SpaceLeft)+'POP AF'+Rem
                               Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='PUSH'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'PUSH BC'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'PUSH DE'+Rem Else
  If StrToUpper(Cells[1])='H'Then ProcessLine:=Space(SpaceLeft)+'PUSH HL'+Rem Else
  If StrToUpper(Cells[1])='PSW'Then ProcessLine:=Space(SpaceLeft)+'PUSH AF'+Rem
                               Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='RAL'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RLA'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RAR'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RRA'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET C'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RLC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RLCA'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RM'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET M'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RNC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET NC'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RNZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET NZ'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RP'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET P'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RPE'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET PE'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RPO'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET PO'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RRC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RRCA'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='RST'Then Begin
  If Cells[1]='0'Then ProcessLine:=Space(SpaceLeft)+'RST 0'+Rem Else
  If Cells[1]='1'Then ProcessLine:=Space(SpaceLeft)+'RST 8'+Rem Else
  If Cells[1]='2'Then ProcessLine:=Space(SpaceLeft)+'RST 10H'+Rem Else
  If Cells[1]='3'Then ProcessLine:=Space(SpaceLeft)+'RST 18H'+Rem Else
  If Cells[1]='4'Then ProcessLine:=Space(SpaceLeft)+'RST 20H'+Rem Else
  If Cells[1]='5'Then ProcessLine:=Space(SpaceLeft)+'RST 28H'+Rem Else
  If Cells[1]='6'Then ProcessLine:=Space(SpaceLeft)+'RST 30H'+Rem Else
  If Cells[1]='7'Then ProcessLine:=Space(SpaceLeft)+'RST 38H'+Rem
                 Else ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='RZ'Then Begin
  ProcessLine:=Space(SpaceLeft)+'RET Z'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='SHLD'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD ('+Cells[1]+'),HL';
 End
  Else
 If StrToUpper(Cells[0])='SPHL'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD SP,HL';
 End
  Else
 If StrToUpper(Cells[0])='STA'Then Begin
  ProcessLine:=Space(SpaceLeft)+'LD ('+Cells[1]+'),A'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='STAX'Then Begin
  If StrToUpper(Cells[1])='B'Then ProcessLine:=Space(SpaceLeft)+'LD (BC),A'+Rem Else
  If StrToUpper(Cells[1])='D'Then ProcessLine:=Space(SpaceLeft)+'LD (DE),A'+Rem
   Else
  ProcessLine:=CurrLine;
 End
  Else
 If StrToUpper(Cells[0])='SBB'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'SBC A,(HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'SBC A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='SBI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'SBC A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='STC'Then Begin
  ProcessLine:=Space(SpaceLeft)+'SCF'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='SUB'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'SUB A,(HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'SUB A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='SUI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'SUB A,'+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='XCHG'Then Begin
  ProcessLine:=Space(SpaceLeft)+'EX DE,HL'+Rem;
 End
  Else
 If StrToUpper(Cells[0])='XRA'Then Begin
  If StrToUpper(Cells[1])='M'Then ProcessLine:=Space(SpaceLeft)+'XOR (HL)'+Rem
                             Else ProcessLine:=Space(SpaceLeft)+'XOR '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='XRI'Then Begin
  ProcessLine:=Space(SpaceLeft)+'XOR '+Cells[1]+Rem;
 End
  Else
 If StrToUpper(Cells[0])='XTHL'Then Begin
  ProcessLine:=Space(SpaceLeft)+'EX (SP),HL'+Rem;
 End
  Else
 ProcessLine:=CurrLine;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('8080Z80 : Cette commande permet de convertir un code source ',
                     'assembleur de microprocesseur 8080 en code source ',
                     'Z80.');
  WriteLn;
  WriteLn('Syntaxe : 8080Z80 source.asm');
  WriteLn;
  WriteLn(' source.asm       Ce paramŠtre permet d''indiquer le fichier … convertir');
 End
  Else
 If ParamCount>0Then Begin
  {$I-}Assign(Source8080,ParamStr(1));
  Reset(Source8080);{$I+}
  While Not EOF(Source8080)do Begin
   ReadLn(Source8080,CurrLine);
   WriteLn(ProcessLine);
  End;
  Close(Source8080);
 End;
END.