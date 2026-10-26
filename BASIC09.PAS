{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Clone de BASIC09 (Microware / Motorola) pour OS-9.
                Analyseur lexical et syntaxique, compilateur I-code, "binder",
                module binaire BASIC09 (type $22, format PACK) et machine
                virtuelle (RunB) executant les I-codes sous DOS.
                Syntaxe : basic09 [options] [fichier ...]  (voir DOC/BASIC09.txt)
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE (suit l'organisation des sources Microware)           }
{ ---------------------------------------------------------------------------- }
{  1. Lexeur / analyseur (COMPIL) : une ligne source est analysee symbole par  }
{     symbole (INSYM) et convertie en I-code "non lie" (notation polonaise     }
{     inversee, jetons $00-$55 pour les instructions, $80-$F9 pour les         }
{     operandes et operateurs). Les variables sont representees par un         }
{     decalage dans la table des symboles de la procedure.                     }
{  2. Binder (BIND) : resolution des types, insertion des conversions          }
{     FIX/FLOAT, allocation du stockage, tables de description (tableaux,      }
{     chaines, enregistrements), structures de controle (IF/WHILE/FOR...),     }
{     numeros de ligne -> decalages. Les jetons d'operateurs sont specialises  }
{     (entier / reel / chaine / booleen) : GT, GT+1, GT+2 ...                  }
{  3. Module (PACK) : module OS-9 de type/langage $22 (Subroutine + I-code),   }
{     attributs $81, en-tete $87CD, parite et CRC-24 ($800063), suivi de la    }
{     zone I-code, de la zone de description et de la table des symboles.      }
{  4. Machine virtuelle (RunB) : interprete les I-codes lies. Memoire de       }
{     donnees de 64 Ko, paquets de parametres (adresse,taille) passes par      }
{     reference, pile d'operandes, GOSUB, DATA/READ, ON ERROR, fichiers.       }
{  5. Interface : commandes B: (DIR EDIT LIST RUN KILL SAVE LOAD RENAME PACK   }
{     MEM CHD CHX BYE), editeur E: et debogueur D:.                            }
{ ---------------------------------------------------------------------------- }

{$mode objfpc}
Program BASIC09;

{$A-}
{$IOCHECKS OFF}
{$RANGECHECKS OFF}
{$OVERFLOWCHECKS OFF}
{$H+}

Uses DOS,Crt;

Const
 B09_VERSION = '1.00';

  { Jetons d'instructions, operandes et operateurs de l'I-code BASIC09 }
 T_GLOB=$00; T_PRAM=$01; T_TYPE=$02; T_DIM=$03; T_DATA=$04; T_STOP=$05;
 T_BYE=$06; T_TRON=$07; T_TROF=$08; T_PAUS=$09; T_DEG=$0A; T_RAD=$0B;
 T_RETN=$0C; T_LET=$0D; T_CXAS=$0E; T_POKE=$0F; T_IF=$10; T_ELSE=$11;
 T_EIF=$12; T_FOR=$13; T_NEXT=$14; T_WHIL=$15; T_EWHL=$16; T_REPT=$17;
 T_UNTL=$18; T_LOOP=$19; T_ELOP=$1A; T_EXIF=$1B; T_EEXT=$1C; T_ON=$1D;
 T_EROR=$1E; T_GOTO=$1F; T_GTBD=$20; T_GOSB=$21; T_GSBD=$22; T_RUN=$23;
 T_KILL=$24; T_INPT=$25; T_PRNT=$26; T_CHD=$27; T_CHX=$28; T_CRET=$29;
 T_OPEN=$2A; T_SEEK=$2B; T_READ=$2C; T_WRIT=$2D; T_GET=$2E; T_PUT=$2F;
 T_CLOS=$30; T_REST=$31; T_DELT=$32; T_CHIN=$33; T_SYS=$34; T_BAS0=$35;
 T_BAS1=$36; T_REM1=$37; T_REM2=$38; T_END=$39; T_LREF=$3A; T_LRBD=$3B;
 T_DEXC=$3C; T_ERRL=$3D; T_BKSL=$3E; T_EOL=$3F; T_LSTM=$40; T_BYTE=$40;
 T_INT=$41; T_REAL=$42; T_BOOL=$43; T_STR=$44; T_THEN=$45; T_TO=$46;
 T_STEP=$47; T_DO=$48; T_USNG=$49; T_MODE=$4A; T_COMA=$4B; T_COL=$4C;
 T_LPAR=$4D; T_RPAR=$4E; T_LBKT=$4F; T_RBKT=$50; T_SCOL=$51; T_ASGN=$52;
 T_ASG1=$53; T_CNUM=$54; T_LBNE=$55; T_SBYT=$80; T_SINT=$81; T_SRL=$82;
 T_SBL=$83; T_SSTR=$84; T_VREF=$85; T_VR1D=$86; T_VR2D=$87; T_VR3D=$88;
 T_PERD=$89; T_P1D=$8A; T_P2D=$8B; T_P3D=$8C; T_BLIT=$8D; T_ILIT=$8E;
 T_RLIT=$8F; T_SLIT=$90; T_HLIT=$91; T_ADDR=$92; T_LENG=$94; T_POS=$96;
 T_ERR=$97; T_MOD=$98; T_RND=$9A; T_PI=$9B; T_SUBS=$9C; T_SGN=$9D;
 T_SIN=$9F; T_COS=$A0; T_TAN=$A1; T_ASN=$A2; T_ACS=$A3; T_ATN=$A4;
 T_EXP=$A5; T_ABS=$A6; T_LN=$A8; T_LOG=$A9; T_SQR=$AA; T_INTF=$AC;
 T_FIX=$AE; T_FLOT=$B0; T_SQ=$B2; T_PEEK=$B4; T_NNOT=$B5; T_VAL=$B6;
 T_LEN=$B7; T_ASC=$B8; T_NAND=$B9; T_NOR=$BA; T_NXOR=$BB; T_TRUE=$BC;
 T_FALS=$BD; T_EOF=$BE; T_TRIM=$BF; T_MID=$C0; T_LEFT=$C1; T_RGHT=$C2;
 T_CHR=$C3; T_STRF=$C4; T_DATE=$C6; T_TAB=$C7; T_FIX1=$C8; T_FIX2=$C9;
 T_FIX3=$CA; T_FLT1=$CB; T_FLT2=$CC; T_NOT=$CD; T_NEG=$CE; T_AND=$D0;
 T_OR=$D1; T_XOR=$D2; T_GT=$D3; T_LT=$D6; T_NE=$D9; T_EQ=$DD;
 T_GE=$E1; T_LE=$E4; T_PLUS=$E7; T_MINS=$EA; T_MUL=$EC; T_DIV=$EE;
 T_POWR=$F0; T_AREF=$F2; T_AR1D=$F3; T_AR2D=$F4; T_AR3D=$F5; T_APRD=$F6;
 T_AP1D=$F7; T_AP2D=$F8; T_AP3D=$F9; T_UPDT=$F7; T_EXEC=$F8; T_DIR=$F9;

  { Types de symboles : bits 0-2 type, bits 3-4 forme, bits 5-7 definition }
 S_DEFM = $E0;  S_SHPM = $18;  S_TYPM = $07;
 S_DEF1 = $20;  S_SHP1 = $08;  S_TYP1 = $01;
 S_UNDF = $00;  S_TYPD = $20;  S_FLDD = $40;  S_VAR = $60;
 S_PARM = $80;  S_PROC = $A0;
 S_SIMP = 0;    S_1DIM = 8;    S_2DIM = 16;   S_3DIM = 24;
 S_BYTE = 0;    S_INT = 1;     S_REAL = 2;    S_BOOL = 3;
 S_STR = 4;     S_RCRD = 5;

  { Types de symboles du compilateur (SYMTYP) }
 K_VARIAB = 0;  K_STMBEG = 1;  K_STMEND = 2;  K_RESRVD = 3;
 K_FNCREF = 4;  K_OPRTR = 5;   K_LITRAL = 6;  K_PROCDR = 7;
 K_ASGN = 8;    K_EQULTY = 9;  K_RELATN = 10; K_CNLREF = 11;
 K_SEPRTR = 12;

  { Descripteur de la table de decompilation }
 Z_GARB = $80;  Z_SUB = $20;   Z_1CH = $40;   Z_STSK = $60;
 Z_BCTL = 1;    Z_ECTL = 2;    Z_CCTL = 3;    Z_FREF = $10;
 Z_OPTR = $08;  Z_LIT = $04;

  { Constantes de valeur }
 V_CR = 13;  V_LF = 10;  V_SPAC = 32;  V_TRUE = $FF;  V_FALS = 0;
 V_ESTR = $FF;

  { Variables temporaires d'invocation (taille avant les variables) }
 U_SIZE = 22;

  { Modes d'acces OS-9 }
 MODE_READ = 1;  MODE_WRITE = 2;  MODE_UPDAT = 3;  MODE_EXEC = 4;
 MODE_DIR = $80;

  { Codes d'erreur BASIC09 }
 M_BSYM = 10;  M_EVRB = 11;  M_ICON = 12;  M_ICOV = 13;  M_ILCH = 14;
 M_IMOD = 15;  M_INUM = 16;  M_IPFX = 17;  M_IOPD = 18;  M_IOPR = 19;
 M_IRFN = 20;  M_IDIM = 21;  M_ILIT = 22;  M_IREL = 23;  M_ITYP = 24;
 M_LDIM = 25;  M_LREF = 26;  M_MASS = 27;  M_MCHL = 28;  M_MCOM = 29;
 M_MDIM = 30;  M_MDO = 31;   M_MFUL = 32;  M_MGTO = 33;  M_MLPR = 34;
 M_MLRF = 35;  M_MOPD = 36;  M_MRPR = 37;  M_MTHN = 38;  M_MTO = 39;
 M_MVAR = 40;  M_NOQU = 41;  M_SUBS = 42;  M_UPRC = 43;  M_MDPC = 44;
 M_ZDIV = 45;  M_TYPM = 46;  M_STOV = 47;  M_UNIM = 48;  M_UDVR = 49;
 M_FPOV = 50;  M_ERST = 51;  M_ORNG = 52;  M_SBOV = 53;  M_SBUN = 54;
 M_SORG = 55;  M_PRER = 56;  M_SSOV = 57;  M_INTM = 58;  M_NFMT = 59;
 M_NRNG = 60;  M_IFMT = 61;  M_FRPT = 62;  M_FSYN = 63;  M_IPN = 64;
 M_IES = 65;   M_NRTO = 66;  M_IARG = 67;  M_ICS = 68;   M_UCS = 69;
 M_IFV = 70;   M_IET = 71;   M_IDS = 72;   M_ASO = 73;   M_ULN = 74;
 M_MDLN = 75;  M_MDV = 76;   M_IIV = 77;   M_SOR = 78;   M_MDAT = 79;
 M_IOVF = 80;
  { Codes d'erreur OS-9 les plus courants }
 E_BPNUM = 201; E_BMODE = 203; E_EOF = 211; E_FNA = 214; E_BPNAM = 215;
 E_PNNF = 216; E_CEF = 218; E_MNF = 221; E_PRCABT = 227; E_BMID = 205;
 E_WP = 242;   E_READ = 244; E_WRITE = 245; E_FULL = 248; E_BMCRC = 231;
 E_NES = 212;  E_SHARE = 253; E_DELSP = 222;

 MAXPROC = 255;
 MEMSIZE = 65536;
 MAXOPS = 512;
 MAXPATH = 31;

Type
 PByteArr = ^TByteArr;
 TByteArr = Array[0..65534] of Byte;

 TBuf = Record
  D:Array of Byte;
  Len:Longint;
 End;

 TSymTab = Record
  B:TBuf;          { entrees : type(1) donnee(2) nom (dernier octet | $80) }
  Cnt:Word;        { nombre d'entrees }
 End;

 TB5 = Array[0..4] of Byte;

 TBound = Record
  Code:TBuf;       { I-code lie }
  Dsc:TBuf;        { zone de description }
  Sym:TSymTab;     { table des symboles }
  VarC:Word;       { P.VARC : stockage des variables + liens de procedures }
  PrcS:Word;       { P.PRCS : debut des liens de procedures }
  DataOfs:Word;    { P.DATA : premiere instruction DATA }
  ExecOfs:Word;    { P.EXEC : premiere instruction executable }
  Stat:Byte;       { P.STAT : bit 0 = erreurs, bit 7 = compile }
  NLines:Longint;
  LineOfs:Array of Longint;  { decalage lie de chaque ligne source }
 End;

 PProc = ^TProc;
 TProc = Record
  Name:String[63];
  Src:TBuf;        { I-code non lie }
  Sym:TSymTab;     { table des symboles du source }
  Bnd:TBound;      { forme liee }
  HasBnd:Boolean;
  IsMod:Boolean;   { charge depuis un module compile }
  EdtPtr:Longint;  { pointeur d'edition (debut d'une ligne) }
 End;

Var
 Procs:Array[1..MAXPROC] of PProc;
 NProcs:Integer;
 ActProc:PProc;           { procedure active }
 StdOut:Text;

Const
 JK_COMP = 1;  JK_BIND = 2;  JK_STMT = 3;  JK_ABORT = 4;

Type
 TJump = Class(TObject)
  Kind:Integer;
  Code:Integer;
  Constructor Make(K,C:Integer);
 End;

Constructor TJump.Make(K,C:Integer);
Begin
 Inherited Create;
 Kind:=K;
 Code:=C;
End;

{ Sortie non locale (compilation, liaison, instruction, abandon) }
Procedure Throw(K,C:Integer);
Begin
 Raise TJump.Make(K,C);
End;

{ ---------------------------------------------------------------------------- }
{  Utilitaires                                                                 }
{ ---------------------------------------------------------------------------- }

Function Hex2(V:Byte):String;
Const H:String[16]='0123456789ABCDEF';
Begin
 Hex2:=H[(V shr 4)+1]+H[(V and 15)+1];
End;

Function Hex4(V:Word):String;
Begin
 Hex4:=Hex2(V shr 8)+Hex2(V and $FF);
End;

Function UpStr(Const S:String):String;
Var I:Integer;R:String;
Begin
 R:=S;
 For I:=1 to Length(R)do If R[I]in['a'..'z']Then R[I]:=Chr(Ord(R[I])-32);
 UpStr:=R;
End;

Function IStr(V:Longint):String;
Var S:String;
Begin
 Str(V,S);
 IStr:=S;
End;

Function Spaces(N:Integer):String;
Var S:String;
Begin
 S:='';
 While N>0 do Begin S:=S+' ';Dec(N);End;
 Spaces:=S;
End;

Function UpCh(C:Char):Char;
Begin
 If C in['a'..'z']Then UpCh:=Chr(Ord(C)-32)Else UpCh:=C;
End;

{ Compare de noms sans tenir compte de la casse }
Function NameEq(Const A,B:String):Boolean;
Var I:Integer;
Begin
 NameEq:=False;
 If Length(A)<>Length(B)Then Exit;
 For I:=1 to Length(A)do If UpCh(A[I])<>UpCh(B[I])Then Exit;
 NameEq:=True;
End;

{ ---------------------------------------------------------------------------- }
{  Tampons d'octets                                                            }
{ ---------------------------------------------------------------------------- }

Procedure BClear(Var B:TBuf);
Begin
 SetLength(B.D,0);
 B.Len:=0;
End;

Procedure BReserve(Var B:TBuf;N:Longint);
Var C:Longint;
Begin
 C:=Length(B.D);
 If C<N Then Begin
  If C<64 Then C:=64;
  While C<N do C:=C*2;
  SetLength(B.D,C);
 End;
End;

Procedure BAdd(Var B:TBuf;V:Byte);
Begin
 BReserve(B,B.Len+1);
 B.D[B.Len]:=V;
 Inc(B.Len);
End;

Procedure BAddW(Var B:TBuf;V:Word);
Begin
 BAdd(B,V shr 8);
 BAdd(B,V and $FF);
End;

{ Ouvre un trou de N octets a la position P }
Procedure BInsert(Var B:TBuf;P,N:Longint);
Var I:Longint;
Begin
 If N<=0 Then Exit;
 BReserve(B,B.Len+N);
 For I:=B.Len-1 downto P do B.D[I+N]:=B.D[I];
 For I:=0 to N-1 do B.D[P+I]:=0;
 Inc(B.Len,N);
End;

Procedure BDelete(Var B:TBuf;P,N:Longint);
Var I:Longint;
Begin
 If N<=0 Then Exit;
 If P+N>B.Len Then N:=B.Len-P;
 If N<=0 Then Exit;
 For I:=P to B.Len-N-1 do B.D[I]:=B.D[I+N];
 Dec(B.Len,N);
End;

Procedure BCopy(Const S:TBuf;Var D:TBuf);
Var I:Longint;
Begin
 BClear(D);
 BReserve(D,S.Len);
 For I:=0 to S.Len-1 do D.D[I]:=S.D[I];
 D.Len:=S.Len;
End;

Function BGetW(Const B:TBuf;P:Longint):Word;
Begin
 BGetW:=(Word(B.D[P])shl 8)or B.D[P+1];
End;

Procedure BPutW(Var B:TBuf;P:Longint;V:Word);
Begin
 B.D[P]:=V shr 8;
 B.D[P+1]:=V and $FF;
End;

{ ---------------------------------------------------------------------------- }
{  Nombres reels BASIC09 : 5 octets, exposant (complement a 2) puis mantisse   }
{  de 32 bits normalisee (bit 31 = 1); le bit 0 de la mantisse est le signe.   }
{  Valeur = 0.mantisse * 2^exposant ; zero = mantisse nulle.                   }
{ ---------------------------------------------------------------------------- }

Type
 TDbl = Record
  Case Byte of
   0:(D:Double);
   1:(B:Array[0..7] of Byte);
   2:(Q:QWord);
 End;

Var
 FpOverflow:Boolean;

Function Pw2(E:Integer):Double;
Var T:TDbl;
Begin
 If E>1023 Then Begin Pw2:=1E308;Exit;End;
 If E<-1022 Then Begin Pw2:=0;Exit;End;
 T.Q:=QWord(E+1023)shl 52;
 Pw2:=T.D;
End;

Procedure RealToB5(X:Double;Var R:TB5);
Var T:TDbl;E:Integer;M53,M31:QWord;Neg:Boolean;
Begin
 FillChar(R,5,0);
 If X=0 Then Exit;
 T.D:=X;
 Neg:=(T.Q shr 63)<>0;
 E:=Integer((T.Q shr 52)and $7FF);
 If E=0 Then Exit;                        { denormalise : zero }
 If E=$7FF Then Begin FpOverflow:=True;R[0]:=127;R[1]:=$FF;R[2]:=$FF;R[3]:=$FF;R[4]:=$FE;Exit;End;
 M53:=(T.Q and $000FFFFFFFFFFFFF)or $0010000000000000;
 E:=E-1022;                               { |X| = 0.1xxx * 2^E }
 M31:=(M53+(QWord(1)shl 21))shr 22;       { 31 bits arrondis }
 If M31>=(QWord(1)shl 31)Then Begin
  M31:=QWord(1)shl 30;
  Inc(E);
 End;
 If E>127 Then Begin
  FpOverflow:=True;
  E:=127;M31:=(QWord(1)shl 31)-1;
 End;
 If E<-128 Then Exit;
 M31:=M31 shl 1;
 If Neg Then M31:=M31 or 1;
 R[0]:=Byte(ShortInt(E));
 R[1]:=(M31 shr 24)and $FF;
 R[2]:=(M31 shr 16)and $FF;
 R[3]:=(M31 shr 8)and $FF;
 R[4]:=M31 and $FF;
End;

Function B5ToReal(Const R:TB5):Double;
Var M:QWord;E:Integer;X:Double;
Begin
 If R[1]=0 Then Begin B5ToReal:=0;Exit;End;
 M:=(QWord(R[1])shl 24)or(QWord(R[2])shl 16)or(QWord(R[3])shl 8)or R[4];
 E:=ShortInt(R[0]);
 X:=(M and $FFFFFFFE)*Pw2(E-32);
 If(M and 1)<>0 Then X:=-X;
 B5ToReal:=X;
End;

{ Arrondit a la precision BASIC09 (31 bits de mantisse) }
Function QReal(X:Double):Double;
Var R:TB5;
Begin
 RealToB5(X,R);
 QReal:=B5ToReal(R);
End;

{ ---------------------------------------------------------------------------- }
{  Messages d'erreur                                                           }
{ ---------------------------------------------------------------------------- }

Function ErrText(C:Integer):String;
Begin
 Case C of
  M_BSYM:ErrText:='Unrecognized symbol';
  M_EVRB:ErrText:='Excessive verbage';
  M_ICON:ErrText:='Illegal statement construction';
  M_ICOV:ErrText:='I-code overflow';
  M_ILCH:ErrText:='Illegal channel reference';
  M_IMOD:ErrText:='Illegal mode';
  M_INUM:ErrText:='Illegal number';
  M_IPFX:ErrText:='Illegal prefix';
  M_IOPD:ErrText:='Illegal operand';
  M_IOPR:ErrText:='Illegal operator';
  M_IRFN:ErrText:='Illegal record field name';
  M_IDIM:ErrText:='Illegal dimension';
  M_ILIT:ErrText:='Illegal literal';
  M_IREL:ErrText:='Illegal relational';
  M_ITYP:ErrText:='Illegal type suffix';
  M_LDIM:ErrText:='Too large dimension';
  M_LREF:ErrText:='Too large line number';
  M_MASS:ErrText:='Missing assignment statement';
  M_MCHL:ErrText:='Missing path number';
  M_MCOM:ErrText:='Missing comma';
  M_MDIM:ErrText:='Missing dimension';
  M_MDO:ErrText:='Missing DO statement';
  M_MFUL:ErrText:='Memory full';
  M_MGTO:ErrText:='Missing GOTO';
  M_MLPR:ErrText:='Missing left parenthesis';
  M_MLRF:ErrText:='Missing line reference';
  M_MOPD:ErrText:='Missing operand';
  M_MRPR:ErrText:='Missing right parenthesis';
  M_MTHN:ErrText:='Missing THEN statement';
  M_MTO:ErrText:='Missing TO';
  M_MVAR:ErrText:='Missing variable';
  M_NOQU:ErrText:='No ending quote';
  M_SUBS:ErrText:='Too many subscripts';
  M_UPRC:ErrText:='Unknown procedure';
  M_MDPC:ErrText:='Multiply defined procedure';
  M_ZDIV:ErrText:='Divide by zero';
  M_TYPM:ErrText:='Operand type mismatch';
  M_STOV:ErrText:='String stack overflow';
  M_UNIM:ErrText:='Unimplemented routine';
  M_UDVR:ErrText:='Undefined variable';
  M_FPOV:ErrText:='Floating overflow or underflow';
  M_ERST:ErrText:='Line with compiler error';
  M_ORNG:ErrText:='Value out of range for destination';
  M_SBOV:ErrText:='Subroutine stack overflow';
  M_SBUN:ErrText:='Subroutine stack underflow';
  M_SORG:ErrText:='Subscript out of range';
  M_PRER:ErrText:='Parameter error';
  M_SSOV:ErrText:='System stack overflow';
  M_INTM:ErrText:='I/O type mismatch';
  M_NFMT:ErrText:='I/O numeric input format bad';
  M_NRNG:ErrText:='I/O conversion: number out of range';
  M_IFMT:ErrText:='Illegal input format';
  M_FRPT:ErrText:='I/O format repeat error';
  M_FSYN:ErrText:='I/O format syntax error';
  M_IPN:ErrText:='Illegal path number';
  M_IES:ErrText:='Insufficient or excessive subscripts';
  M_NRTO:ErrText:='Non-record type operand';
  M_IARG:ErrText:='Illegal argument';
  M_ICS:ErrText:='Illegal control structure';
  M_UCS:ErrText:='Unmatched control structure';
  M_IFV:ErrText:='Illegal FOR variable';
  M_IET:ErrText:='Illegal expression type';
  M_IDS:ErrText:='Illegal declarative statement';
  M_ASO:ErrText:='Array size overflow';
  M_ULN:ErrText:='Undefined line number';
  M_MDLN:ErrText:='Multiply defined line number';
  M_MDV:ErrText:='Multiply defined variable';
  M_IIV:ErrText:='Illegal input variable';
  M_SOR:ErrText:='Seek out of range';
  M_MDAT:ErrText:='Missing DATA statement';
  M_IOVF:ErrText:='I/O buffer overflow';
  E_BPNUM:ErrText:='Bad path number';
  E_BMODE:ErrText:='Bad mode';
  E_EOF:ErrText:='End of file';
  E_FNA:ErrText:='File not accessible';
  E_BPNAM:ErrText:='Bad path name';
  E_PNNF:ErrText:='Path name not found';
  E_CEF:ErrText:='Creating existing file';
  E_MNF:ErrText:='Module not found';
  E_PRCABT:ErrText:='Process aborted';
  E_BMID:ErrText:='Bad module ID';
  E_BMCRC:ErrText:='Bad module CRC';
  E_WP:ErrText:='Write protect';
  E_READ:ErrText:='Read error';
  E_WRITE:ErrText:='Write error';
  E_FULL:ErrText:='Media full';
  E_NES:ErrText:='Null string';
  E_SHARE:ErrText:='Non-sharable file busy';
 Else ErrText:='';
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Tables des jetons : table de decompilation et table de saut                 }
{ ---------------------------------------------------------------------------- }

Var
 DDesc:Array[0..255] of Byte;       { descripteur (voir Z_xxx) }
 DText:Array[0..255] of String[12]; { mot-cle ou caracteres litteraux }
 SkipCl:Array[0..255] of Byte;      { classe de saut des jetons }

 { classes de saut : 0=0 octet 1=1 2=2 3=5 4=NEXT(9) 5=chaine 7=remarque }

Procedure SD(T,D:Byte;Const S:String);
Begin
 DDesc[T]:=D;
 DText[T]:=S;
End;

Procedure InitTokens;
Var I:Integer;
Begin
 For I:=0 to 255 do Begin DDesc[I]:=0;DText[I]:='';SkipCl[I]:=0;End;
 SD(T_GLOB,Z_1CH,'');
 SD(T_PRAM,0,'PARAM');
 SD(T_TYPE,0,'TYPE');
 SD(T_DIM,0,'DIM');
 SD(T_DATA,0,'DATA');
 SD(T_STOP,0,'STOP');
 SD(T_BYE,0,'BYE');
 SD(T_TRON,0,'TRON');
 SD(T_TROF,0,'TROFF');
 SD(T_PAUS,0,'PAUSE');
 SD(T_DEG,0,'DEG');
 SD(T_RAD,0,'RAD');
 SD(T_RETN,0,'RETURN');
 SD(T_LET,0,'LET');
 SD(T_CXAS,Z_1CH,'');
 SD(T_POKE,0,'POKE');
 SD(T_IF,0,'IF');
 SD(T_ELSE,Z_STSK+Z_CCTL,'ELSE');
 SD(T_EIF,Z_ECTL,'ENDIF');
 SD(T_FOR,Z_BCTL,'FOR');
 SD(T_NEXT,Z_SUB+Z_ECTL,'NEXT');
 SD(T_WHIL,Z_BCTL,'WHILE');
 SD(T_EWHL,Z_STSK+Z_ECTL,'ENDWHILE');
 SD(T_REPT,Z_BCTL,'REPEAT');
 SD(T_UNTL,Z_ECTL,'UNTIL');
 SD(T_LOOP,Z_BCTL,'LOOP');
 SD(T_ELOP,Z_STSK+Z_ECTL,'ENDLOOP');
 SD(T_EXIF,Z_ECTL,'EXITIF');
 SD(T_EEXT,Z_STSK+Z_CCTL,'ENDEXIT');
 SD(T_ON,0,'ON');
 SD(T_EROR,0,'ERROR');
 SD(T_GOTO,Z_SUB,'');
 SD(T_GTBD,Z_SUB,'');
 SD(T_GOSB,Z_SUB,'');
 SD(T_GSBD,Z_SUB,'');
 SD(T_RUN,Z_SUB,'');
 SD(T_KILL,0,'KILL');
 SD(T_INPT,0,'INPUT');
 SD(T_PRNT,0,'PRINT');
 SD(T_CHD,0,'CHD');
 SD(T_CHX,0,'CHX');
 SD(T_CRET,0,'CREATE');
 SD(T_OPEN,0,'OPEN');
 SD(T_SEEK,0,'SEEK');
 SD(T_READ,0,'READ');
 SD(T_WRIT,0,'WRITE');
 SD(T_GET,0,'GET');
 SD(T_PUT,0,'PUT');
 SD(T_CLOS,0,'CLOSE');
 SD(T_REST,0,'RESTORE');
 SD(T_DELT,0,'DELETE');
 SD(T_CHIN,0,'CHAIN');
 SD(T_SYS,0,'SHELL');
 SD(T_BAS0,Z_SUB,'');
 SD(T_BAS1,Z_SUB,'');
 SD(T_REM1,Z_SUB,'');
 SD(T_REM2,Z_SUB,'');
 SD(T_END,0,'END');
 SD(T_LREF,Z_SUB,'');
 SD(T_LRBD,Z_SUB,'');
 SD(T_DEXC,Z_1CH,'');
 SD(T_ERRL,Z_SUB,'');
 SD(T_BKSL,Z_1CH,' \');
 SD(T_EOL,Z_SUB,'');
 SD(T_BYTE,Z_FREF,'BYTE');
 SD(T_INT,Z_FREF,'INTEGER');
 SD(T_REAL,Z_FREF,'REAL');
 SD(T_BOOL,Z_FREF,'BOOLEAN');
 SD(T_STR,Z_FREF,'STRING');
 SD(T_THEN,Z_SUB,'');
 SD(T_TO,Z_STSK,'TO');
 SD(T_STEP,Z_STSK,'STEP');
 SD(T_DO,0,'DO');
 SD(T_USNG,0,'USING');
 SD(T_MODE,Z_SUB,'');
 SD(T_COMA,Z_1CH,',');
 SD(T_COL,Z_1CH,':');
 SD(T_LPAR,Z_1CH,'(');
 SD(T_RPAR,Z_1CH,')');
 SD(T_LBKT,Z_1CH,'[');
 SD(T_RBKT,Z_1CH,']');
 SD(T_SCOL,Z_1CH,'; ');
 SD(T_ASGN,Z_1CH,':=');
 SD(T_ASG1,Z_1CH,'=');
 SD(T_CNUM,Z_1CH,'#');
 SD(T_LBNE,Z_SUB,'');
  { Operandes }
 For I:=T_SBYT to T_SSTR do SD(I,Z_SUB,'');
 SD(T_VREF,Z_SUB,'');
 SD(T_VR1D,Z_SUB+1,'');
 SD(T_VR2D,Z_SUB+2,'');
 SD(T_VR3D,Z_SUB+3,'');
 SD(T_PERD,Z_SUB,'');
 SD(T_P1D,Z_SUB+1,'');
 SD(T_P2D,Z_SUB+2,'');
 SD(T_P3D,Z_SUB+3,'');
 SD(T_BLIT,Z_SUB+Z_LIT+2,'');
 SD(T_ILIT,Z_SUB+Z_LIT+3,'');
 SD(T_RLIT,Z_SUB+Z_LIT+0,'');
 SD(T_SLIT,Z_SUB+Z_LIT,'');
 SD(T_HLIT,Z_SUB+Z_LIT+3,'');
 SD(T_ADDR,Z_FREF+1,'ADDR');
 SD(T_ADDR+1,Z_GARB,'');
 SD(T_LENG,Z_FREF+1,'SIZE');
 SD(T_LENG+1,Z_GARB,'');
 SD(T_POS,Z_FREF,'POS');
 SD(T_ERR,Z_FREF,'ERR');
 SD(T_MOD,Z_FREF+2,'MOD');
 SD(T_MOD+1,Z_FREF+2,'MOD');
 SD(T_RND,Z_FREF+1,'RND');
 SD(T_PI,Z_FREF,'PI');
 SD(T_SUBS,Z_FREF+2,'SUBSTR');
 SD(T_SGN,Z_FREF+1,'SGN');
 SD(T_SGN+1,Z_FREF+1,'SGN');
 SD(T_SIN,Z_FREF+1,'SIN');
 SD(T_COS,Z_FREF+1,'COS');
 SD(T_TAN,Z_FREF+1,'TAN');
 SD(T_ASN,Z_FREF+1,'ASN');
 SD(T_ACS,Z_FREF+1,'ACS');
 SD(T_ATN,Z_FREF+1,'ATN');
 SD(T_EXP,Z_FREF+1,'EXP');
 SD(T_ABS,Z_FREF+1,'ABS');
 SD(T_ABS+1,Z_FREF+1,'ABS');
 SD(T_LN,Z_FREF+1,'LOG');
 SD(T_LOG,Z_FREF+1,'LOG10');
 SD(T_SQR,Z_FREF+1,'SQRT');
 SD(T_SQR+1,Z_FREF+1,'SQRT');
 SD(T_INTF,Z_FREF+1,'INT');
 SD(T_INTF+1,Z_FREF+1,'INT');
 SD(T_FIX,Z_FREF+1,'FIX');
 SD(T_FIX+1,Z_FREF+1,'FIX');
 SD(T_FLOT,Z_FREF+1,'FLOAT');
 SD(T_FLOT+1,Z_FREF+1,'FLOAT');
 SD(T_SQ,Z_FREF+1,'SQ');
 SD(T_SQ+1,Z_FREF+1,'SQ');
 SD(T_PEEK,Z_FREF+1,'PEEK');
 SD(T_NNOT,Z_FREF+1,'LNOT');
 SD(T_VAL,Z_FREF+1,'VAL');
 SD(T_LEN,Z_FREF+1,'LEN');
 SD(T_ASC,Z_FREF+1,'ASC');
 SD(T_NAND,Z_FREF+2,'LAND');
 SD(T_NOR,Z_FREF+2,'LOR');
 SD(T_NXOR,Z_FREF+2,'LXOR');
 SD(T_TRUE,Z_FREF,'TRUE');
 SD(T_FALS,Z_FREF,'FALSE');
 SD(T_EOF,Z_FREF+1,'EOF');
 SD(T_TRIM,Z_FREF+1,'TRIM$');
 SD(T_MID,Z_FREF+3,'MID$');
 SD(T_LEFT,Z_FREF+2,'LEFT$');
 SD(T_RGHT,Z_FREF+2,'RIGHT$');
 SD(T_CHR,Z_FREF+1,'CHR$');
 SD(T_STRF,Z_FREF+1,'STR$');
 SD(T_STRF+1,Z_FREF+1,'STR$');
 SD(T_DATE,Z_FREF,'DATE$');
 SD(T_TAB,Z_FREF+1,'TAB');
 For I:=T_FIX1 to T_FLT2 do SD(I,Z_GARB,'');
  { Operateurs }
 SD(T_NOT,Z_FREF+1,'NOT');
 SD(T_NEG,Z_1CH+Z_FREF+1,'-');
 SD(T_NEG+1,Z_1CH+Z_FREF+1,'-');
 SD(T_AND,Z_OPTR+2,'AND');
 SD(T_OR,Z_OPTR+1,'OR');
 SD(T_XOR,Z_OPTR+1,'XOR');
 For I:=0 to 2 do Begin
  SD(T_GT+I,Z_1CH+Z_OPTR+3,'>');
  SD(T_LT+I,Z_1CH+Z_OPTR+3,'<');
 End;
 For I:=0 to 3 do Begin
  SD(T_NE+I,Z_1CH+Z_OPTR+3,'<>');
  SD(T_EQ+I,Z_1CH+Z_OPTR+3,'=');
 End;
 For I:=0 to 2 do Begin
  SD(T_GE+I,Z_1CH+Z_OPTR+3,'>=');
  SD(T_LE+I,Z_1CH+Z_OPTR+3,'<=');
 End;
 For I:=0 to 2 do SD(T_PLUS+I,Z_1CH+Z_OPTR+4,'+');
 For I:=0 to 1 do SD(T_MINS+I,Z_1CH+Z_OPTR+4,'-');
 For I:=0 to 1 do SD(T_MUL+I,Z_1CH+Z_OPTR+5,'*');
 For I:=0 to 1 do SD(T_DIV+I,Z_1CH+Z_OPTR+5,'/');
 SD(T_POWR,Z_1CH+Z_OPTR+6,'^');
 SD(T_POWR+1,Z_1CH+Z_OPTR+6,'**');
  { References d'adresse }
 SD(T_AREF,Z_SUB,'');
 SD(T_AR1D,Z_SUB+1,'');
 SD(T_AR2D,Z_SUB+2,'');
 SD(T_AR3D,Z_SUB+3,'');
 SD(T_APRD,Z_SUB,'');
 SD(T_AP1D,Z_SUB+1,'');
 SD(T_AP2D,Z_SUB+2,'');
 SD(T_AP3D,Z_SUB+3,'');
  { classes de saut }
 SkipCl[T_ELSE]:=2;  SkipCl[T_NEXT]:=4;  SkipCl[T_EWHL]:=2;
 SkipCl[T_ELOP]:=2;  SkipCl[T_EEXT]:=2;  SkipCl[T_GOTO]:=2;
 SkipCl[T_GTBD]:=2;  SkipCl[T_GOSB]:=2;  SkipCl[T_GSBD]:=2;
 SkipCl[T_RUN]:=2;   SkipCl[T_REM1]:=7;  SkipCl[T_REM2]:=7;
 SkipCl[T_LREF]:=2;  SkipCl[T_LRBD]:=2;  SkipCl[T_DEXC]:=7;
 SkipCl[T_ERRL]:=7;  SkipCl[T_TO]:=2;    SkipCl[T_STEP]:=2;
 SkipCl[T_MODE]:=1;  SkipCl[T_LBNE]:=2;
 For I:=T_SBYT to T_P3D do SkipCl[I]:=2;
 SkipCl[T_BLIT]:=1;  SkipCl[T_ILIT]:=2;  SkipCl[T_RLIT]:=3;
 SkipCl[T_SLIT]:=5;  SkipCl[T_HLIT]:=2;
 For I:=T_AREF to T_AP3D do SkipCl[I]:=2;
End;

{ ---------------------------------------------------------------------------- }
{  Table des symboles                                                          }
{  Chaque entree : type(1) donnee(2) nom (dernier caractere avec bit 7)        }
{ ---------------------------------------------------------------------------- }

Procedure SymClear(Var S:TSymTab);
Begin
 BClear(S.B);
 S.Cnt:=0;
End;

Procedure SymCopy(Const S:TSymTab;Var D:TSymTab);
Begin
 BCopy(S.B,D.B);
 D.Cnt:=S.Cnt;
End;

{ Longueur du nom de l'entree O }
Function SymNameEnd(Const S:TSymTab;O:Longint):Longint;
Var P:Longint;
Begin
 P:=O+3;
 While(P<S.B.Len)and((S.B.D[P]and $80)=0)do Inc(P);
 SymNameEnd:=P+1;
End;

Function SymName(Const S:TSymTab;O:Longint):String;
Var P,E:Longint;R:String;
Begin
 R:='';
 E:=SymNameEnd(S,O);
 For P:=O+3 to E-1 do R:=R+Chr(S.B.D[P]and $7F);
 SymName:=R;
End;

Function SymFind(Const S:TSymTab;Const Nm:String;Var Off:Longint):Boolean;
Var I:Integer;O:Longint;
Begin
 SymFind:=False;
 O:=0;
 For I:=1 to S.Cnt do Begin
  If NameEq(SymName(S,O),Nm)Then Begin
   Off:=O;SymFind:=True;Exit;
  End;
  O:=SymNameEnd(S,O);
 End;
End;

Function SymAdd(Var S:TSymTab;Const Nm:String;Typ:Byte):Longint;
Var I:Integer;
Begin
 SymAdd:=S.B.Len;
 BAdd(S.B,Typ);
 BAdd(S.B,0);
 BAdd(S.B,0);
 For I:=1 to Length(Nm)do Begin
  If I=Length(Nm)Then BAdd(S.B,Ord(Nm[I])or $80)
  Else BAdd(S.B,Ord(Nm[I]));
 End;
 Inc(S.Cnt);
End;

{ ---------------------------------------------------------------------------- }
{  Table des mots-cles                                                         }
{ ---------------------------------------------------------------------------- }

Type
 TKw = Record
  N:String[8];
  T:Byte;
  K:Byte;
 End;

Var
 Kw:Array[1..130] of TKw;
 NKw:Integer;

Procedure AddKw(Const N:String;T,K:Byte);
Begin
 Inc(NKw);
 Kw[NKw].N:=N;
 Kw[NKw].T:=T;
 Kw[NKw].K:=K;
End;

Procedure InitKeywords;
Begin
 NKw:=0;
 AddKw('PARAM',T_PRAM,K_STMBEG);  AddKw('TYPE',T_TYPE,K_STMBEG);
 AddKw('DIM',T_DIM,K_STMBEG);     AddKw('DATA',T_DATA,K_STMBEG);
 AddKw('STOP',T_STOP,K_STMBEG);   AddKw('BYE',T_BYE,K_STMBEG);
 AddKw('TRON',T_TRON,K_STMBEG);   AddKw('TROFF',T_TROF,K_STMBEG);
 AddKw('PAUSE',T_PAUS,K_STMBEG);  AddKw('DEG',T_DEG,K_STMBEG);
 AddKw('RAD',T_RAD,K_STMBEG);     AddKw('RETURN',T_RETN,K_STMBEG);
 AddKw('LET',T_LET,K_STMBEG);     AddKw('POKE',T_POKE,K_STMBEG);
 AddKw('IF',T_IF,K_STMBEG);       AddKw('ELSE',T_ELSE,K_STMBEG);
 AddKw('ENDIF',T_EIF,K_STMBEG);   AddKw('FOR',T_FOR,K_STMBEG);
 AddKw('NEXT',T_NEXT,K_STMBEG);   AddKw('WHILE',T_WHIL,K_STMBEG);
 AddKw('ENDWHILE',T_EWHL,K_STMBEG);AddKw('REPEAT',T_REPT,K_STMBEG);
 AddKw('UNTIL',T_UNTL,K_STMBEG);  AddKw('LOOP',T_LOOP,K_STMBEG);
 AddKw('ENDLOOP',T_ELOP,K_STMBEG);AddKw('EXITIF',T_EXIF,K_STMBEG);
 AddKw('ENDEXIT',T_EEXT,K_STMBEG);AddKw('ON',T_ON,K_STMBEG);
 AddKw('ERROR',T_EROR,K_STMBEG);  AddKw('GOTO',T_GOTO,K_STMBEG);
 AddKw('GOSUB',T_GOSB,K_STMBEG);  AddKw('RUN',T_RUN,K_STMBEG);
 AddKw('KILL',T_KILL,K_STMBEG);   AddKw('INPUT',T_INPT,K_STMBEG);
 AddKw('PRINT',T_PRNT,K_STMBEG);  AddKw('CHD',T_CHD,K_STMBEG);
 AddKw('CHX',T_CHX,K_STMBEG);     AddKw('CREATE',T_CRET,K_STMBEG);
 AddKw('OPEN',T_OPEN,K_STMBEG);   AddKw('SEEK',T_SEEK,K_STMBEG);
 AddKw('READ',T_READ,K_STMBEG);   AddKw('WRITE',T_WRIT,K_STMBEG);
 AddKw('GET',T_GET,K_STMBEG);     AddKw('PUT',T_PUT,K_STMBEG);
 AddKw('CLOSE',T_CLOS,K_STMBEG);  AddKw('RESTORE',T_REST,K_STMBEG);
 AddKw('DELETE',T_DELT,K_STMBEG); AddKw('CHAIN',T_CHIN,K_STMBEG);
 AddKw('SHELL',T_SYS,K_STMBEG);   AddKw('BASE',T_BAS0,K_STMBEG);
 AddKw('REM',T_REM1,K_STMBEG);    AddKw('END',T_END,K_STMBEG);
 AddKw('BYTE',T_BYTE,K_RESRVD);   AddKw('INTEGER',T_INT,K_RESRVD);
 AddKw('REAL',T_REAL,K_RESRVD);   AddKw('BOOLEAN',T_BOOL,K_RESRVD);
 AddKw('STRING',T_STR,K_RESRVD);  AddKw('THEN',T_THEN,K_RESRVD);
 AddKw('TO',T_TO,K_RESRVD);       AddKw('STEP',T_STEP,K_RESRVD);
 AddKw('DO',T_DO,K_RESRVD);       AddKw('USING',T_USNG,K_RESRVD);
 AddKw('PROCEDURE',T_ERRL,K_RESRVD);
 AddKw('ADDR',T_ADDR,K_FNCREF);   AddKw('SIZE',T_LENG,K_FNCREF);
 AddKw('POS',T_POS,K_FNCREF);     AddKw('ERR',T_ERR,K_FNCREF);
 AddKw('MOD',T_MOD,K_FNCREF);     AddKw('RND',T_RND,K_FNCREF);
 AddKw('SUBSTR',T_SUBS,K_FNCREF); AddKw('PI',T_PI,K_FNCREF);
 AddKw('SIN',T_SIN,K_FNCREF);     AddKw('COS',T_COS,K_FNCREF);
 AddKw('TAN',T_TAN,K_FNCREF);     AddKw('ASN',T_ASN,K_FNCREF);
 AddKw('ACS',T_ACS,K_FNCREF);     AddKw('ATN',T_ATN,K_FNCREF);
 AddKw('EXP',T_EXP,K_FNCREF);     AddKw('LOG',T_LN,K_FNCREF);
 AddKw('LOG10',T_LOG,K_FNCREF);   AddKw('SGN',T_SGN,K_FNCREF);
 AddKw('ABS',T_ABS,K_FNCREF);     AddKw('SQRT',T_SQR,K_FNCREF);
 AddKw('SQR',T_SQR,K_FNCREF);     AddKw('INT',T_INTF,K_FNCREF);
 AddKw('FIX',T_FIX,K_FNCREF);     AddKw('FLOAT',T_FLOT,K_FNCREF);
 AddKw('SQ',T_SQ,K_FNCREF);       AddKw('PEEK',T_PEEK,K_FNCREF);
 AddKw('LNOT',T_NNOT,K_FNCREF);   AddKw('VAL',T_VAL,K_FNCREF);
 AddKw('LEN',T_LEN,K_FNCREF);     AddKw('ASC',T_ASC,K_FNCREF);
 AddKw('LAND',T_NAND,K_FNCREF);   AddKw('LOR',T_NOR,K_FNCREF);
 AddKw('LXOR',T_NXOR,K_FNCREF);   AddKw('TRUE',T_TRUE,K_FNCREF);
 AddKw('FALSE',T_FALS,K_FNCREF);  AddKw('EOF',T_EOF,K_FNCREF);
 AddKw('TRIM$',T_TRIM,K_FNCREF);  AddKw('MID$',T_MID,K_FNCREF);
 AddKw('LEFT$',T_LEFT,K_FNCREF);  AddKw('RIGHT$',T_RGHT,K_FNCREF);
 AddKw('CHR$',T_CHR,K_FNCREF);    AddKw('STR$',T_STRF,K_FNCREF);
 AddKw('DATE$',T_DATE,K_FNCREF);  AddKw('TAB',T_TAB,K_FNCREF);
 AddKw('NOT',T_NOT,K_OPRTR);      AddKw('AND',T_AND,K_OPRTR);
 AddKw('OR',T_OR,K_OPRTR);        AddKw('XOR',T_XOR,K_OPRTR);
 AddKw('UPDATE',T_UPDT,K_RESRVD); AddKw('EXEC',T_EXEC,K_RESRVD);
 AddKw('DIR',T_DIR,K_RESRVD);
End;

{ ---------------------------------------------------------------------------- }
{  Etat du compilateur (COMPIL)                                                }
{ ---------------------------------------------------------------------------- }

Type
 PSymTab = ^TSymTab;

Var
 CSymP:PSymTab;           { table des symboles utilisee (I.SYMT) }
 CDebug:Byte;             { DEBUGGER : 0 normal, 1 pas de nouvelle variable, 128 aucune }
 CSrc:String;             { ligne source }
 CPos:Integer;            { SRCPTR : indice du prochain caractere (base 1) }
 CSrcBeg:Integer;         { SRCBUF : debut de la ligne apres le numero }
 CErrPos:Integer;         { ERRPTR }
 CTok,CSymTyp:Byte;       { TOKEN, SYMTYP }
 CSymPt:Word;             { SYMPT : decalage du symbole courant }
 CNamTyp:Byte;
 CNtAss:Byte;             { CNTASS }
 CIcd:TBuf;               { I-code de la ligne }
 CPrv:Longint;            { ICDPRV }
 CIBuf:Longint;           { IBUF }
 COps:Array[0..MAXOPS] of Word;
 COpTop:Integer;
 CErrCode:Byte;           { dernier code d'erreur du compilateur }
 CQuiet:Boolean;          { n'affiche pas les messages }
 CErrLine:Boolean;        { la ligne compilee est une ligne d'erreur }

Procedure ConLine(Const S:String);Forward;
Procedure PrtError(Code:Integer);Forward;
Procedure CExprsn(A:Byte);Forward;
Procedure CStatem;Forward;
Procedure CNode;Forward;
Procedure CFunRef;Forward;
Procedure CVarRef;Forward;
Function CAsNum(Const S:String;Var P:Integer;Sep:Byte;Var Typ:Byte;Var IV:Longint;Var RV:Double):Integer;Forward;

Function SrcCh(P:Integer):Char;
Begin
 If(P>=1)and(P<=Length(CSrc))Then SrcCh:=CSrc[P]Else SrcCh:=#13;
End;

Function IsDigit(C:Char):Boolean;
Begin
 IsDigit:=C in['0'..'9'];
End;

Function IsAlpha(C:Char):Boolean;
Begin
 IsAlpha:=(C in['A'..'Z'])or(C in['a'..'z'])or(C='_');
End;

Function IsAlNum(C:Char):Boolean;
Begin
 IsAlNum:=IsAlpha(C)or IsDigit(C);
End;

Procedure OpPush(D:Word);
Begin
 If COpTop<MAXOPS Then Begin
  COps[COpTop]:=D;
  Inc(COpTop);
 End;
End;

Function OpPop:Word;
Begin
 If COpTop>0 Then Begin
  Dec(COpTop);
  OpPop:=COps[COpTop];
 End
  Else
 OpPop:=0;
End;

{ ERRDIE : affiche la ligne et le message, la ligne devient une ligne d'erreur }
Procedure CErr(Code:Byte);
Var I,N:Integer;T:String;
Begin
 CErrCode:=Code;
 If Not CQuiet Then Begin
  T:=Copy(CSrc,CSrcBeg,Length(CSrc));
  ConLine(T);
  N:=CErrPos-CSrcBeg;
  If N<0 Then N:=0;
  ConLine(Spaces(N)+'^');
  PrtError(Code);
 End;
  { la ligne devient une remarque d'erreur }
 CIcd.Len:=CIBuf;
 BAdd(CIcd,T_ERRL);
 T:=Copy(CSrc,CSrcBeg,Length(CSrc));
 I:=1;
 While(I<=Length(T))and(T[I]=' ')do Inc(I);
 N:=Length(T)-I+1;
 If N<0 Then N:=0;
 BAdd(CIcd,N+1);
 While I<=Length(T)do Begin
  BAdd(CIcd,Ord(T[I]));
  Inc(I);
 End;
 BAdd(CIcd,T_EOL);
 CErrLine:=True;
 Throw(JK_COMP,1);
End;

Procedure OutCod(A:Byte);
Begin
 BAdd(CIcd,A);
 If(CIcd.Len and $FF)>=$FF Then CErr(M_ICOV);
End;

Procedure OutW(W:Word);
Begin
 OutCod(W shr 8);
 OutCod(W and $FF);
End;

Procedure State8;
Begin
 If CIcd.Len>0 Then Dec(CIcd.Len);
End;

Procedure Stop1;
Begin
 CIcd.Len:=CPrv;
End;

Procedure SkipSp;
Begin
 While(CPos<=Length(CSrc))and((CSrc[CPos]=' ')or(CSrc[CPos]=#10))do Inc(CPos);
End;

{ Recherche un nom a la position courante (NAMSYM) }
Function NamSym(Var Nm:String):Boolean;
Var P:Integer;
Begin
 NamSym:=False;
 Nm:='';
 SkipSp;
 CNamTyp:=S_REAL;
 If Not IsAlpha(SrcCh(CPos))Then Exit;
 P:=CPos;
 While IsAlNum(SrcCh(P))do Begin
  Nm:=Nm+SrcCh(P);
  Inc(P);
 End;
 If SrcCh(P)='$' Then Begin
  Nm:=Nm+'$';
  CNamTyp:=S_STR;
 End;
 NamSym:=True;
End;

Function FindKw(Const Nm:String):Integer;
Var I:Integer;
Begin
 FindKw:=0;
 If Length(Nm)>8 Then Exit;
 For I:=1 to NKw do If NameEq(Kw[I].N,Nm)Then Begin FindKw:=I;Exit;End;
End;

{ ---------------------------------------------------------------------------- }
{  Conversion ASCII -> numerique (ASCNUM)                                      }
{  Retourne 0 si correct ou un code d'erreur. S_INT : IV ; S_REAL : RV         }
{ ---------------------------------------------------------------------------- }

Function CAsNum(Const S:String;Var P:Integer;Sep:Byte;Var Typ:Byte;Var IV:Longint;Var RV:Double):Integer;
Var Ch:Char;M:QWord;DCnt,DExp:Integer;DPFl,Neg,ESgn:Boolean;V:Int64;Hx:Integer;
    X:Extended;K,EV:Integer;
 Function Cc(Q:Integer):Char;
 Begin
  If(Q>=1)and(Q<=Length(S))Then Cc:=S[Q]Else Cc:=#13;
 End;
 Function IsDelim(C:Char):Boolean;
 Begin
  IsDelim:=(Ord(C)=Sep)or(C=#13)or(C=#255);
 End;
Label Real1;
Begin
 CAsNum:=0;
 M:=0;DCnt:=0;DExp:=0;DPFl:=False;Neg:=False;ESgn:=False;
 While Cc(P)=' ' do Inc(P);
 Ch:=Cc(P);
 If IsDelim(Ch)Then Begin
  If Ch=',' Then Begin
   Inc(P);Typ:=S_INT;IV:=0;Exit;
  End;
  CAsNum:=M_NFMT;Exit;
 End;
 If Ch='$' Then Begin
  Inc(P);
  Hx:=0;V:=0;
  While True do Begin
   Ch:=Cc(P);
   If Ch in['0'..'9']Then K:=Ord(Ch)-48
   Else If Ch in['a'..'f']Then K:=Ord(Ch)-87
   Else If Ch in['A'..'F']Then K:=Ord(Ch)-55
   Else Break;
   V:=V*16+K;
   If V>$FFFF Then Begin CAsNum:=M_NRNG;Exit;End;
   Inc(Hx);Inc(P);
  End;
  If Hx=0 Then Begin CAsNum:=M_NFMT;Exit;End;
  Typ:=S_INT;
  IV:=SmallInt(Word(V));
  Exit;
 End;
 If Ch='+' Then Inc(P)
 Else If Ch='-' Then Begin Neg:=True;Inc(P);End;
 While True do Begin
  Ch:=Cc(P);
  If Ch='.' Then Begin
   If DPFl Then Begin CAsNum:=M_NFMT;Exit;End;
   DPFl:=True;Inc(P);
  End
  Else If IsDigit(Ch)Then Begin
   Inc(DCnt);
   M:=M*10+(Ord(Ch)-48);
   If M>$FFFFFFFF Then Begin CAsNum:=M_NRNG;Exit;End;
   If DPFl Then Inc(DExp);
   Inc(P);
  End
  Else Break;
 End;
 If(Ch='E')or(Ch='e')Then Begin
  Inc(P);
  Ch:=Cc(P);
  If Ch='+' Then Inc(P)
  Else If Ch='-' Then Begin ESgn:=True;Inc(P);End;
  If Not IsDigit(Cc(P))Then Begin CAsNum:=M_NFMT;Exit;End;
  EV:=Ord(Cc(P))-48;Inc(P);
  If IsDigit(Cc(P))Then Begin EV:=EV*10+Ord(Cc(P))-48;Inc(P);End;
  If ESgn Then DExp:=DExp+EV Else DExp:=DExp-EV;
  Goto Real1;
 End;
 If DCnt=0 Then Begin CAsNum:=M_NFMT;Exit;End;
 If Not DPFl Then Begin
  If M<=32767 Then Begin
   Typ:=S_INT;
   If Neg Then IV:=-Longint(M)Else IV:=M;
   Exit;
  End;
 End;
Real1:
 Typ:=S_REAL;
 If M=0 Then RV:=0
  Else
 Begin
  X:=M;
  If DExp>0 Then Begin
   For K:=1 to DExp do X:=X/10;
  End
  Else If DExp<0 Then Begin
   For K:=1 to -DExp do X:=X*10;
  End;
  If Neg Then X:=-X;
  If(Abs(X)>1.7014118E38)or((X<>0)and(Abs(X)<1.4693680E-39))Then Begin CAsNum:=M_NRNG;Exit;End;
  RV:=QReal(X);
 End;
End;

{ Lit un nombre dans le source : retourne le type (S_REAL ou S_INT) }
Procedure GetNum(Var Typ:Byte;Var IV:Longint;Var RV:Double);
Var R:Integer;
Begin
 SkipSp;
 R:=CAsNum(CSrc,CPos,0,Typ,IV,RV);
 If R<>0 Then CErr(M_ILIT);
End;

Procedure PrsNum;
Var Typ:Byte;IV:Longint;RV:Double;B:TB5;I:Integer;
Begin
 GetNum(Typ,IV,RV);
 If Typ=S_REAL Then Begin
  CTok:=T_RLIT;
  RealToB5(RV,B);
  OutCod(T_RLIT);
  For I:=0 to 4 do OutCod(B[I]);
 End
  Else
 Begin
  If(IV and $FF00)<>0 Then Begin
   If(IV<0)or(IV>255)Then Begin
    CTok:=T_ILIT;
    OutCod(T_ILIT);
    OutW(Word(SmallInt(IV)));
   End;
  End
   Else
  Begin
   CTok:=T_BLIT;
   OutCod(T_BLIT);
   OutCod(IV and $FF);
  End;
 End;
 CSymTyp:=K_LITRAL;
End;

Procedure PrsHex;
Var Typ:Byte;IV:Longint;RV:Double;
Begin
 Dec(CPos);
 GetNum(Typ,IV,RV);
 CTok:=T_HLIT;
 OutCod(T_HLIT);
 OutW(Word(SmallInt(IV)));
 CSymTyp:=K_LITRAL;
End;

Procedure PrsStr;
Var C:Char;
Begin
 CTok:=T_SLIT;CSymTyp:=K_LITRAL;
 OutCod(T_SLIT);
 While True do Begin
  C:=SrcCh(CPos);
  If(CPos>Length(CSrc))or(C=#13)Then CErr(M_NOQU);
  Inc(CPos);
  If C='"' Then Begin
   If SrcCh(CPos)='"' Then Begin
    Inc(CPos);
    OutCod(Ord('"'));
   End
    Else
   Break;
  End
   Else
  OutCod(Ord(C)and $FF);
 End;
 OutCod(V_ESTR);
End;

Procedure InSym2(T,K:Byte);
Begin
 CTok:=T;CSymTyp:=K;
 OutCod(T);
End;

Procedure PrsNam(Const Nm:String);
Var K:Integer;Off:Longint;
Begin
 K:=FindKw(Nm);
 If K<>0 Then Begin
  Inc(CPos,Length(Nm));
  CTok:=Kw[K].T;CSymTyp:=Kw[K].K;
  OutCod(CTok);
  Exit;
 End;
 If CDebug>=128 Then Begin
  Inc(CPos,Length(Nm));
  CErr(M_UDVR);
 End;
 If SymFind(CSymP^,Nm,Off)Then CSymPt:=Off
  Else
 Begin
  If CDebug<>0 Then Begin Inc(CPos,Length(Nm));CErr(M_UDVR);End;
  CSymPt:=SymAdd(CSymP^,Nm,CNamTyp);
 End;
 Inc(CPos,Length(Nm));
 CTok:=T_VREF;CSymTyp:=K_VARIAB;
 OutCod(T_VREF);
 OutW(CSymPt);
End;

{ INSYM : analyse le symbole suivant }
Procedure InSym;
Var Nm:String;C,C2:Char;
Begin
 CPrv:=CIcd.Len;
 SkipSp;
 CErrPos:=CPos;
 If NamSym(Nm)Then Begin PrsNam(Nm);Exit;End;
 C:=SrcCh(CPos);
 C2:=SrcCh(CPos+1);
 If IsDigit(C)Then Begin PrsNum;Exit;End;
  { symboles de deux caracteres }
 If(CPos<=Length(CSrc))Then Begin
  If(C='<')and(C2='>')Then Begin Inc(CPos,2);InSym2(T_NE,K_RELATN);Exit;End;
  If(C='>')and(C2='<')Then Begin Inc(CPos,2);InSym2(T_NE,K_RELATN);Exit;End;
  If(C='<')and(C2='=')Then Begin Inc(CPos,2);InSym2(T_LE,K_RELATN);Exit;End;
  If(C='=')and(C2='<')Then Begin Inc(CPos,2);InSym2(T_LE,K_RELATN);Exit;End;
  If(C='>')and(C2='=')Then Begin Inc(CPos,2);InSym2(T_GE,K_RELATN);Exit;End;
  If(C='=')and(C2='>')Then Begin Inc(CPos,2);InSym2(T_GE,K_RELATN);Exit;End;
  If(C=':')and(C2='=')Then Begin Inc(CPos,2);InSym2(T_ASGN,K_ASGN);Exit;End;
  If(C='*')and(C2='*')Then Begin Inc(CPos,2);InSym2(T_POWR+1,K_OPRTR);Exit;End;
  If(C='(')and(C2='*')Then Begin Inc(CPos,2);InSym2(T_REM2,K_STMBEG);Exit;End;
 End;
 If CPos>Length(CSrc)Then Begin InSym2(T_EOL,K_STMEND);Exit;End;
 Inc(CPos);
 Case C of
  '\':InSym2(T_BKSL,K_STMEND);
  '>':InSym2(T_GT,K_RELATN);
  '<':InSym2(T_LT,K_RELATN);
  '=':InSym2(T_EQ,K_EQULTY);
  '+':InSym2(T_PLUS,K_OPRTR);
  '-':InSym2(T_MINS,K_OPRTR);
  '*':InSym2(T_MUL,K_OPRTR);
  '/':InSym2(T_DIV,K_OPRTR);
  '^':InSym2(T_POWR,K_OPRTR);
  ':':InSym2(T_COL,K_SEPRTR);
  '[':InSym2(T_LBKT,K_SEPRTR);
  ']':InSym2(T_RBKT,K_SEPRTR);
  ';':InSym2(T_SCOL,K_SEPRTR);
  '#':InSym2(T_CNUM,K_CNLREF);
  '?':InSym2(T_PRNT,K_STMBEG);
  '!':InSym2(T_REM1,K_STMBEG);
  ',':InSym2(T_COMA,K_SEPRTR);
  '(':InSym2(T_LPAR,K_SEPRTR);
  ')':InSym2(T_RPAR,K_SEPRTR);
  '.':Begin
       If IsDigit(SrcCh(CPos))Then Begin Dec(CPos);PrsNum;End
        Else
       InSym2(T_PERD,K_SEPRTR);
      End;
  '"':PrsStr;
  '$':PrsHex;
  #13:InSym2(T_EOL,K_STMEND);
 Else Begin
   Dec(CPos);
   CErr(M_BSYM);
  End;
 End;
End;

Procedure Stop;
Begin
 InSym;
 Stop1;
End;

{ ---------------------------------------------------------------------------- }
{  Expressions                                                                 }
{ ---------------------------------------------------------------------------- }

Procedure ChkVar;
Begin
 If CSymTyp<>K_VARIAB Then CErr(M_ICON);
End;

Procedure ChkRpr;
Begin
 If CTok<>T_RPAR Then CErr(M_MRPR);
End;

Procedure ChkLpr;
Begin
 If CTok<>T_LPAR Then CErr(M_MLPR);
End;

Function IsComma:Boolean;
Begin
 IsComma:=CTok=T_COMA;
End;

Procedure CkComa;
Begin
 If CTok<>T_COMA Then CErr(M_MCOM);
End;

Procedure CkCass;
Begin
 If CNtAss<>0 Then Begin
  CNtAss:=0;
  OutCod(T_CXAS);
 End;
End;

{ OPRATR : traite l'operateur courant. True = operateur trouve }
Function COpratr:Boolean;
Var A,B,Prec,TP:Byte;D:Word;
Label Again;
Begin
Again:
 A:=0;B:=CTok;
 If B=T_RPAR Then Prec:=0
 Else If(B>=$80)and((DDesc[B]and Z_OPTR)<>0)Then Prec:=DDesc[B]and 7
 Else Begin
   { pas un operateur : vider la pile jusqu'a la marque }
  Repeat
   D:=OpPop;A:=D shr 8;B:=D and $FF;
   If A=T_LPAR Then CErr(M_MRPR);
   OutCod(A);
  Until B=0;
  If A=T_END Then State8;
  COpratr:=False;
  Exit;
 End;
 While True do Begin
  If COpTop=0 Then TP:=0 Else TP:=COps[COpTop-1]and $FF;
  If Prec<TP Then Begin
   D:=OpPop;
   OutCod(D shr 8);
  End
  Else If Prec>TP Then Break
  Else If Prec=6 Then Break
  Else If Prec<>0 Then Begin
   D:=OpPop;
   OutCod(D shr 8);
  End
   Else
  Begin
   D:=OpPop;A:=D shr 8;
   If A=T_LPAR Then Begin
    Stop;
    Goto Again;
   End;
   If A=T_END Then CErr(M_MLPR);
   OutCod(A);
   COpratr:=False;
   Exit;
  End;
 End;
 OpPush((Word(CTok)shl 8)or Prec);
 COpratr:=True;
End;

Function CPrefix:Byte;
Var C:Char;
Begin
 If CTok=T_NOT Then Begin
  OpPush((Word(T_NOT)shl 8)or 7);
  Stop1;
  InSym;
  CPrefix:=CTok;
 End
  Else
 If CTok=T_MINS Then Begin
  C:=SrcCh(CPos);
  If IsDigit(C)or(C='.')Then Begin
   Dec(CPos);
   State8;
   PrsNum;
   CPrefix:=CTok;
  End
   Else
  Begin
   OpPush((Word(T_NEG)shl 8)or 7);
   Stop1;
   InSym;
   CPrefix:=CTok;
  End;
 End
  Else
 CPrefix:=CTok;
End;

Procedure CNode;
Var A:Byte;
Begin
 While True do Begin
  InSym;
  A:=CPrefix;
  If A=T_LPAR Then Begin
   OpPush(Word(T_LPAR)shl 8);
   Stop1;
  End
   Else
  Begin
   If CSymTyp=K_LITRAL Then Begin Stop;Exit;End;
   If CSymTyp=K_FNCREF Then Begin CFunRef;Exit;End;
   ChkVar;
   CVarRef;
   Exit;
  End;
 End;
End;

Procedure CExprsn(A:Byte);
Begin
 OpPush(Word(A)shl 8);
 Repeat
  CNode;
 Until Not COpratr;
End;

Procedure Assig9;
Begin
 CExprsn(T_END);
End;

Procedure Farg11;
Begin
 CExprsn(0);
 State8;
End;

Procedure Farg1;
Begin
 ChkLpr;
 Farg11;
End;

Procedure EmitVar(B:Integer);
Var D:Word;
Begin
 CNtAss:=0;
 D:=OpPop;
 OutCod(B+(D shr 8));
 D:=OpPop;
 OutW(D);
End;

Procedure CVarRef;
Var Base:Byte;B:Integer;
Begin
 Base:=T_VREF;
 While True do Begin
  OpPush(CSymPt);
  OpPush(Word(Base)shl 8);
  Stop1;
  Stop;
  B:=0;
  If CTok=T_LPAR Then Begin
   CkCass;
   Repeat
    Inc(B);
    Farg11;
    If CTok<>T_COMA Then Begin
     ChkRpr;
     Stop;
     Break;
    End;
    If B>=3 Then CErr(M_SUBS);
    CkCass;
   Until False;
  End;
  If CTok<>T_PERD Then Begin
   EmitVar(B);
   Exit;
  End;
  CkCass;
  EmitVar(B);
  InSym;
  ChkVar;
  Base:=T_PERD;
 End;
End;

Procedure PrsVar;
Begin
 InSym;
 ChkVar;
 CVarRef;
End;

Procedure CFunRef;
Var F:Byte;Dm:Byte;
Begin
 State8;
 F:=CTok;
 Stop;
 Dm:=DDesc[F]and 3;
 Case Dm of
  0:Begin
     OutCod(F);
     Exit;
    End;
  1:Begin
     If(F=T_ADDR)or(F=T_LENG)Then Begin
      ChkLpr;
      OutCod(F+1);
      PrsVar;
     End
      Else
     If F=T_EOF Then Begin
      ChkLpr;
      Stop;
      If CTok<>T_CNUM Then CErr(M_MCHL);
      Farg11;
     End
      Else
     Farg1;
    End;
  2:Begin
     Farg1;
     CkComa;
     Farg11;
    End;
  3:Begin
     Farg1;
     CkComa;
     Farg11;
     CkComa;
     Farg11;
    End;
 End;
 ChkRpr;
 OutCod(F);
 Stop;
End;

{ ---------------------------------------------------------------------------- }
{  Instructions                                                                }
{ ---------------------------------------------------------------------------- }

Procedure Iffals;
Begin
 OutCod(0);
 OutCod(0);
End;

Procedure Tlbne;
Begin
 OutCod(T_LBNE);
 Iffals;
End;

Procedure Until_;
Begin
 Assig9;
 Tlbne;
End;

Procedure LinRef(A:Byte);
Var Typ:Byte;IV:Longint;RV:Double;
Begin
 OutCod(A);
 GetNum(Typ,IV,RV);
 If(Typ=S_REAL)or(IV<=0)Then CErr(M_INUM);
 OutW(IV);
End;

Function OptLrf:Boolean;
Begin
 SkipSp;
 If IsDigit(SrcCh(CPos))Then Begin
  LinRef(T_LREF);
  OptLrf:=True;
 End
  Else
 OptLrf:=False;
End;

Procedure ArrNam;
Begin
 InSym;
 ChkVar;
 InSym;
End;

Procedure RepFct;
Begin
 LinRef(T_ILIT);
 InSym;
End;

Procedure CDim;
Var Done:Boolean;
Begin
 Done:=False;
 While Not Done do Begin
  ArrNam;
  If CTok=T_LPAR Then Begin
   RepFct;
   If CTok=T_COMA Then Begin
    RepFct;
    If CTok=T_COMA Then RepFct;
   End;
   ChkRpr;
   InSym;
  End;
  If CTok<>T_COMA Then Begin
   If CTok=T_COL Then Begin
    InSym;
    If CSymTyp<>K_VARIAB Then Begin
     If CSymTyp<>K_RESRVD Then CErr(M_ITYP);
     If CTok=T_STR Then Begin
      InSym;
      If CTok=T_LBKT Then Begin
       RepFct;
       If CTok<>T_RBKT Then CErr(M_ITYP);
       InSym;
      End;
     End
      Else
     InSym;
    End
     Else
    InSym;
   End;
   If CTok<>T_SCOL Then Begin
    State8;
    Done:=True;
   End;
  End;
 End;
End;

Procedure CTypes;
Begin
 ArrNam;
 If CTok<>T_EQ Then CErr(M_MASS);
 State8;
 OutCod(T_ASG1);
 CDim;
End;

Procedure CData;
Begin
 Repeat
  Assig9;
  If CTok<>T_COMA Then Break;
  OutCod(T_COMA);
 Until False;
 Tlbne;
End;

Procedure CPoke;
Begin
 Assig9;
 CkComa;
 OutCod(T_COMA);
 Assig9;
End;

Procedure CIf;
Begin
 Until_;
 If CTok<>T_THEN Then CErr(M_MTHN);
 OutCod(T_THEN);
 If OptLrf Then Stop
  Else
 CStatem;
End;

Procedure CElse;
Begin
 Iffals;
 CStatem;
End;

Procedure ForVar;
Begin
 InSym;
 ChkVar;
 Stop;
End;

Procedure CFor;
Begin
 ForVar;
 If CTok=T_ASGN Then OutCod(T_ASGN)
 Else If CTok=T_EQ Then OutCod(T_ASG1)
 Else CErr(M_MASS);
 Assig9;
 If CTok<>T_TO Then CErr(M_MTO);
 OutCod(T_TO);Iffals;
 Assig9;
 If CTok=T_STEP Then Begin
  OutCod(T_STEP);Iffals;
  Assig9;
 End;
 Tlbne;
End;

Procedure CNext;
Begin
 ForVar;
 Iffals;Iffals;Iffals;
End;

Procedure CWhile;
Begin
 Until_;
 If CTok<>T_DO Then CErr(M_MDO);
 OutCod(T_DO);
 CStatem;
End;

Procedure CUntil;
Begin
 Until_;
End;

Procedure CEndLup;
Begin
 Iffals;
 Stop;
End;

Procedure CExitif;
Begin
 Until_;
 If CTok<>T_THEN Then CErr(M_MTHN);
 OutCod(T_THEN);
 CStatem;
End;

Procedure CGoto1;
Begin
 Stop1;
 LinRef(CTok);
 Stop;
End;

Procedure COn;
Var SavePos,SaveLen:Longint;SavePrv:Longint;CntPos:Longint;
Begin
 SaveLen:=CIcd.Len;
 SavePos:=CPos;
 InSym;
 If CTok=T_EROR Then Begin
  Stop;
  If CTok=T_GOTO Then Begin
   LinRef(T_GOTO);
   Stop;
  End;
  Exit;
 End;
 CIcd.Len:=SaveLen;
 CPos:=SavePos;
 Until_;
 CntPos:=CIcd.Len-1;
 If(CTok<>T_GOTO)and(CTok<>T_GOSB)Then CErr(M_MGTO);
 Repeat
  Inc(CIcd.D[CntPos]);
  LinRef(CTok);
  Stop;
  If CTok<>T_COMA Then Break;
  OutCod(T_COMA);
  CTok:=T_LREF;
 Until False;
End;

Procedure CRemark;
Var CntPos:Longint;C:Char;
Begin
 CntPos:=CIcd.Len;
 SkipSp;
 OutCod(0);
 Inc(CIcd.D[CntPos]);
 While CPos<=Length(CSrc)do Begin
  C:=CSrc[CPos];
  If C=#13 Then Break;
  Inc(CPos);
  OutCod(Ord(C));
  Inc(CIcd.D[CntPos]);
 End;
 InSym;
 Stop1;
End;

Procedure CStop;
Begin
 Stop;
End;

Procedure CChlRef(Var Found:Boolean);
Begin
 Stop;
 Found:=CTok=T_CNUM;
 If Found Then Begin
  OutCod(T_CNUM);
  Assig9;
 End;
End;

Procedure CPrint;
Var Found:Boolean;SavePos:Integer;C:Char;Skip:Boolean;
Begin
 SavePos:=CPos;
 CChlRef(Found);
 Skip:=False;
 If Found Then Begin
  If CTok=T_USNG Then Begin
   OutCod(T_USNG);
   Assig9;
  End;
 End
  Else
 If CTok=T_USNG Then Begin
  OutCod(T_USNG);
  Assig9;
 End
  Else
 Begin
  CPos:=SavePos;
  Skip:=True;
 End;
 If Skip Then Begin
  SkipSp;C:=SrcCh(CPos);
  If(C=#13)or(C='\')Then Begin Stop;Exit;End;
  Assig9;
 End;
 While(CTok=T_COMA)or(CTok=T_SCOL)do Begin
  OutCod(CTok);
  SkipSp;C:=SrcCh(CPos);
  If(C=#13)or(C='\')Then Begin Stop;Exit;End;
  Assig9;
 End;
End;

Procedure CChkSep;
Begin
 If(CTok<>T_SCOL)and(CTok<>T_COMA)Then CErr(M_MCOM);
End;

Procedure CInput;
Var Found:Boolean;SavePos:Integer;
Begin
 SavePos:=CPos;
 CChlRef(Found);
 If Found Then Begin
  SavePos:=CPos;
  CChkSep;
  OutCod(CTok);
  Stop;
 End;
 CPos:=SavePos;
 If CTok=T_SLIT Then Begin
  InSym;
  Stop;
  CChkSep;
  OutCod(T_COMA);
 End;
 Repeat
  CNtAss:=1;
  PrsVar;
  If(CTok<>T_SCOL)and(CTok<>T_COMA)Then Break;
  OutCod(T_COMA);
 Until False;
End;

Procedure CRead;
Var Found:Boolean;SavePos:Integer;
Begin
 SavePos:=CPos;
 CChlRef(Found);
 If Found Then Begin
  CChkSep;
  OutCod(T_COMA);
 End
  Else
 CPos:=SavePos;
 Repeat
  CNtAss:=1;
  PrsVar;
  If(CTok<>T_SCOL)and(CTok<>T_COMA)Then Break;
  OutCod(T_COMA);
 Until False;
End;

Procedure CWrite;
Var Found:Boolean;SavePos:Integer;C:Char;
Begin
 SavePos:=CPos;
 CChlRef(Found);
 If Not Found Then Begin
  CPos:=SavePos;
  SkipSp;C:=SrcCh(CPos);
  If(C=#13)or(C='\')Then Begin Stop;Exit;End;
  Assig9;
 End;
 While(CTok=T_COMA)or(CTok=T_SCOL)do Begin
  OutCod(CTok);
  SkipSp;C:=SrcCh(CPos);
  If(C=#13)or(C='\')Then Begin Stop;Exit;End;
  Assig9;
 End;
End;

Procedure CPut0;
Var Found:Boolean;
Begin
 CChlRef(Found);
 If Not Found Then CErr(M_MCHL);
 CkComa;
 OutCod(T_COMA);
End;

Procedure CGet;
Begin
 CPut0;
 CNtAss:=1;
 PrsVar;
End;

Procedure CSeek;
Begin
 CPut0;
 Assig9;
End;

Procedure COpen;
Var M,K:Byte;
Begin
 InSym;
 If CTok<>T_CNUM Then CErr(M_MCHL);
 CNtAss:=1;
 PrsVar;
 CkComa;
 OutCod(T_COMA);
 Assig9;
 If CTok<>T_COL Then Exit;
 OutCod(T_MODE);
 M:=0;
 Repeat
  Stop;
  Case CTok of
   T_READ:K:=MODE_READ;
   T_WRIT:K:=MODE_WRITE;
   T_UPDT:K:=MODE_UPDAT;
   T_EXEC:K:=MODE_EXEC;
   T_DIR:K:=MODE_DIR;
  Else Begin K:=0;CErr(M_IMOD);End;
  End;
  M:=M or K;
  Stop;
 Until CTok<>T_PLUS;
 If M=0 Then CErr(M_IMOD);
 OutCod(M);
End;

Procedure CClose;
Var Found:Boolean;
Begin
 Repeat
  CChlRef(Found);
  If Not Found Then CErr(M_MCHL);
  If CTok<>T_COMA Then Break;
  OutCod(T_COMA);
 Until False;
End;

Procedure CRestor;
Begin
 OptLrf;
 Stop;
End;

Procedure CBase;
Var C:Char;
Begin
 SkipSp;
 C:=SrcCh(CPos);
 Inc(CPos);
 If C='0' Then Begin Stop;Exit;End;
 If C<>'1' Then Begin CErrPos:=CPos-1;CErr(M_IOPD);End;
 Stop1;
 OutCod(T_BAS1);
 Stop;
End;

Procedure CLet1;
Begin
 ChkVar;
 Inc(CNtAss);
 CVarRef;
 If CTok=T_ASGN Then OutCod(T_ASGN)
 Else If CTok=T_EQ Then OutCod(T_ASG1)
 Else CErr(M_MASS);
 Assig9;
End;

Procedure CLet;
Begin
 InSym;
 CLet1;
End;


Procedure CGoto;
Begin
 Stop1;
 LinRef(CTok);
 Stop;
End;

Procedure CRunParams;
Var SaveLen:Longint;SavePos:Integer;
Begin
 If CTok<>T_LPAR Then Exit;
 Repeat
  OutCod(CTok);
  SaveLen:=CIcd.Len;
  SavePos:=CPos;
  InSym;
  If CSymTyp=K_VARIAB Then Begin
   ChkVar;
   CVarRef;
  End
   Else
  CSymTyp:=K_OPRTR;
  CIcd.Len:=SaveLen;
  CPos:=SavePos;
  If Not(CSymTyp in[K_OPRTR,K_RELATN,K_EQULTY])Then OutCod(T_CXAS);
  Farg11;
 Until CTok<>T_COMA;
 ChkRpr;
 OutCod(T_RPAR);
 Stop;
End;

Procedure CRun;
Var P:Longint;
Begin
 Stop1;
 P:=CIcd.Len;
 ForVar;
 CIcd.D[P]:=T_RUN;
 CRunParams;
End;

Procedure CStatem;
Begin
 InSym;
 If CSymTyp=K_STMBEG Then Begin
  Case CTok of
   T_PRAM,T_DIM:CDim;
   T_TYPE:CTypes;
   T_DATA:CData;
   T_STOP,T_PAUS,T_END,T_PRNT:CPrint;
   T_BYE,T_TRON,T_TROF,T_DEG,T_RAD,T_RETN,T_EIF,T_REPT,T_LOOP:CStop;
   T_LET:CLet;
   T_POKE:CPoke;
   T_IF:CIf;
   T_ELSE:CElse;
   T_FOR:CFor;
   T_NEXT:CNext;
   T_WHIL:CWhile;
   T_EWHL,T_ELOP,T_EEXT:CEndLup;
   T_UNTL:CUntil;
   T_EXIF:CExitif;
   T_ON:COn;
   T_EROR,T_KILL,T_CHD,T_CHX,T_DELT,T_CHIN,T_SYS:Assig9;
   T_GOTO,T_GOSB:CGoto;
   T_RUN:CRun;
   T_INPT:CInput;
   T_CRET,T_OPEN:COpen;
   T_SEEK:CSeek;
   T_READ:CRead;
   T_WRIT:CWrite;
   T_GET,T_PUT:CGet;
   T_CLOS:CClose;
   T_REST:CRestor;
   T_BAS0,T_BAS1:CBase;
   T_REM1,T_REM2:CRemark;
  Else CErr(M_ICON);
  End;
 End
  Else
 If CSymTyp=K_STMEND Then State8
  Else
 CLet1;
End;

{ Compile une ligne source en I-code non lie. Retourne False si erreur. }
Function CompileLine(SymT:PSymTab;Const Line:String;Dbg:Byte;Quiet:Boolean;Var Code:TBuf):Boolean;
Begin
 CSymP:=SymT;
 CDebug:=Dbg;
 CQuiet:=Quiet;
 CSrc:=Line;
 CPos:=1;CSrcBeg:=1;CErrPos:=1;
 CErrLine:=False;CErrCode:=0;COpTop:=0;CNtAss:=0;
 CIBuf:=0;CPrv:=0;
 BClear(CIcd);
 Try
  OptLrf;
  CSrcBeg:=CPos;
  CIBuf:=CIcd.Len;
  Repeat
   CStatem;
   OutCod(CTok);
  Until CTok<>T_BKSL;
  If CTok<>T_EOL Then CErr(M_EVRB);
 Except
  On E:TJump Do If E.Kind<>JK_COMP Then Raise;
 End;
 BCopy(CIcd,Code);
 CompileLine:=Not CErrLine;
End;

{ Compile la liste de parametres d'une commande RUN : "(p1,p2,...)" }
Function CompileRunParams(SymT:PSymTab;Const Line:String;Quiet:Boolean;Var Code:TBuf):Boolean;
Begin
 CSymP:=SymT;
 CDebug:=1;
 CQuiet:=Quiet;
 CSrc:=Line;
 CPos:=1;CSrcBeg:=1;CErrPos:=1;
 CErrLine:=False;CErrCode:=0;COpTop:=0;CNtAss:=0;
 CIBuf:=0;CPrv:=0;
 BClear(CIcd);
 Try
  Stop;
  CRunParams;
  If CTok<>T_EOL Then CErr(M_EVRB);
  OutCod(T_EOL);
 Except
  On E:TJump Do If E.Kind<>JK_COMP Then Raise;
 End;
 BCopy(CIcd,Code);
 CompileRunParams:=Not CErrLine;
End;

{ ---------------------------------------------------------------------------- }
{  Saut de jetons dans l'I-code                                                }
{ ---------------------------------------------------------------------------- }

{ Retourne la position suivant le jeton situe en Ip }
Function NxTok(Const Cb:TBuf;Ip:Longint):Longint;
Var T:Byte;
Begin
 T:=Cb.D[Ip];
 Inc(Ip);
 Case SkipCl[T] of
  0:;
  1:Inc(Ip,1);
  2:Inc(Ip,2);
  3:Inc(Ip,5);
  4:Inc(Ip,9);
  5:Begin
     While(Ip<Cb.Len)and(Cb.D[Ip]<>V_ESTR)do Inc(Ip);
     Inc(Ip);
    End;
  7:Begin
     If Ip<Cb.Len Then Inc(Ip,Cb.D[Ip]);
    End;
 End;
 If Ip>Cb.Len Then Ip:=Cb.Len;
 NxTok:=Ip;
End;

{ Position du debut de la ligne suivante (apres T_EOL) }
Function NxLine(Const Cb:TBuf;Ip:Longint):Longint;
Begin
 While Ip<Cb.Len do Begin
  If Cb.D[Ip]=T_EOL Then Begin NxLine:=Ip+1;Exit;End;
  Ip:=NxTok(Cb,Ip);
 End;
 NxLine:=Cb.Len;
End;

{ ---------------------------------------------------------------------------- }
{  Decompilateur                                                               }
{ ---------------------------------------------------------------------------- }

Const
 MARGIN = 65;

Var
 IoBuf:String;        { tampon de sortie du decompilateur }
 IoCt:Integer;        { I.IOCT : numero de colonne }
 DcPretty:Boolean;    { mise en forme (indentation) }
 DcOcnt:Integer;      { I.OCNT : niveau d'indentation global }
 DcSym:TSymTab;       { table des symboles du decompilateur }

Function FmtRealFree(X:Double):String;Forward;

Procedure PutCh(C:Char);
Begin
 IoBuf:=IoBuf+C;
 Inc(IoCt);
End;

Procedure DcTab(Col:Integer);
Begin
 While IoCt<Col do PutCh(' ');
End;

{ DCLF : saut de ligne si la marge est depassee. True = saut effectue }
Function DcLf:Boolean;
Begin
 DcLf:=False;
 If IoCt<MARGIN Then Exit;
 PutCh(#10);
 IoCt:=0;
 If DcPretty Then DcTab((DcOcnt+3)*2+6);
 DcLf:=True;
End;

Procedure OutSpc;
Begin
 If DcLf Then Exit;
 If Length(IoBuf)=0 Then Exit;
 If IoBuf[Length(IoBuf)]=' ' Then Exit;
 PutCh(' ');
End;

Procedure CpyStr(Const S:String);
Var I:Integer;
Begin
 For I:=1 to Length(S)do PutCh(S[I]);
End;

Procedure StrSpc(Const S:String);
Begin
 CpyStr(S);
 OutSpc;
End;

Procedure SpcStr(Const S:String);
Begin
 OutSpc;
 StrSpc(S);
End;

Function SymNameAt(Off:Longint):String;
Begin
 If(Off>=0)and(Off<DcSym.B.Len)Then SymNameAt:=SymName(DcSym,Off)
 Else SymNameAt:='?';
End;

{ Un morceau de la sortie d'une expression }
Type
 TPiece = Record
  Tok:Byte;          { jeton a afficher par PRTOKE, 0 = texte }
  Txt:String;
 End;
 TPieces = Array of TPiece;

Procedure PcAdd(Var P:TPieces;Tok:Byte;Const Txt:String);
Var N:Integer;
Begin
 N:=Length(P);
 SetLength(P,N+1);
 P[N].Tok:=Tok;
 P[N].Txt:=Txt;
End;

Procedure PcCat(Var P:TPieces;Const Q:TPieces);
Var I:Integer;
Begin
 For I:=0 to Length(Q)-1 do PcAdd(P,Q[I].Tok,Q[I].Txt);
End;

{ Affiche un jeton d'instruction ou d'operateur d'apres sa description }
Procedure PrToke(T:Byte);
Var D:Byte;S:String;
Begin
 D:=DDesc[T];
 S:=DText[T];
 Case D and $60 of
  0,$60:Begin
     If(D and $18)=$10 Then CpyStr(S)Else SpcStr(S);
    End;
  $40:Begin
       DcLf;
       If Length(S)>=1 Then PutCh(S[1]);
       If Length(S)>=2 Then PutCh(S[2]);
      End;
 End;
End;

Procedure PrPieces(Const P:TPieces);
Var I:Integer;
Begin
 For I:=0 to Length(P)-1 do Begin
  If P[I].Tok=0 Then CpyStr(P[I].Txt)
  Else PrToke(P[I].Tok);
 End;
End;

Function HexLit(V:Word):String;
Begin
 If(V shr 8)=0 Then HexLit:='$'+Hex2(V)Else HexLit:='$'+Hex4(V);
End;

Function StrLitText(Const Cb:TBuf;Var Ip:Longint):String;
Var R:String;C:Byte;
Begin
 R:='"';
 While(Ip<Cb.Len)and(Cb.D[Ip]<>V_ESTR)do Begin
  C:=Cb.D[Ip];
  R:=R+Chr(C);
  If C=Ord('"')Then R:=R+'"';
  Inc(Ip);
 End;
 Inc(Ip);
 StrLitText:=R+'"';
End;

{ Decompile une expression en notation polonaise a partir de Ip (premier jeton $80+) }
Procedure DcExprsn(Const Cb:TBuf;Var Ip:Longint);
Type
 TSt = Record
  P:TPieces;
  Prec:Integer;
 End;
Var
 St:Array[0..63] of TSt;
 Sp:Integer;
 T,D:Byte;
 I,N:Integer;
 Off:Longint;
 Args:Array[0..3] of TSt;
 Nm:String;
 L,R:TSt;
 Pr:Integer;
 TP:TPieces;
 Rv:TB5;

 Procedure Push(Var X:TSt);
 Begin
  If Sp<63 Then Begin St[Sp]:=X;Inc(Sp);End;
 End;

 Function Pop:TSt;
 Var E:TSt;
 Begin
  If Sp>0 Then Begin Dec(Sp);Pop:=St[Sp];End
  Else Begin
   E.Prec:=99;SetLength(E.P,0);PcAdd(E.P,0,'?');Pop:=E;
  End;
 End;

Begin
 Sp:=0;
 While(Ip<Cb.Len)and(Cb.D[Ip]>=$80)do Begin
  T:=Cb.D[Ip];
  Inc(Ip);
  D:=DDesc[T];
  If(D and Z_GARB)<>0 Then Continue;
  If(D and(Z_OPTR))<>0 Then Begin
   R:=Pop;L:=Pop;
   Pr:=D and 7;
   SetLength(TP,0);
   If(L.Prec<Pr)or((Pr=6)and(L.Prec=Pr))Then Begin
    PcAdd(TP,T_LPAR,'');PcCat(TP,L.P);PcAdd(TP,T_RPAR,'');
   End
    Else
   PcCat(TP,L.P);
   PcAdd(TP,T,'');
   If(R.Prec<Pr)or((R.Prec=Pr)and(Pr<>6))Then Begin
    PcAdd(TP,T_LPAR,'');PcCat(TP,R.P);PcAdd(TP,T_RPAR,'');
   End
    Else
   PcCat(TP,R.P);
   L.P:=TP;L.Prec:=Pr;
   Push(L);
  End
   Else
  If(D and Z_FREF)<>0 Then Begin
   N:=D and 3;
   For I:=N-1 downto 0 do Args[I]:=Pop;
   SetLength(TP,0);
   PcAdd(TP,T,'');
   If N>0 Then Begin
    PcAdd(TP,T_LPAR,'');
    If T=T_EOF Then PcAdd(TP,T_CNUM,'');
    For I:=0 to N-1 do Begin
     If I>0 Then PcAdd(TP,T_COMA,'');
     PcCat(TP,Args[I].P);
    End;
    PcAdd(TP,T_RPAR,'');
   End;
   L.P:=TP;L.Prec:=99;
   Push(L);
  End
   Else
  If(D and Z_LIT)<>0 Then Begin
   SetLength(TP,0);
   Case T of
    T_BLIT:Begin
            PcAdd(TP,0,IStr(Cb.D[Ip]));
            Inc(Ip);
           End;
    T_ILIT:Begin
            PcAdd(TP,0,IStr(SmallInt(BGetW(Cb,Ip))));
            Inc(Ip,2);
           End;
    T_HLIT:Begin
            PcAdd(TP,0,HexLit(BGetW(Cb,Ip)));
            Inc(Ip,2);
           End;
    T_RLIT:Begin
            For I:=0 to 4 do Rv[I]:=Cb.D[Ip+I];
            Inc(Ip,5);
            PcAdd(TP,0,FmtRealFree(B5ToReal(Rv)));
           End;
    T_SLIT:PcAdd(TP,0,StrLitText(Cb,Ip));
   End;
   L.P:=TP;L.Prec:=99;
   Push(L);
  End
   Else
  Begin
    { reference de variable ou de champ }
   N:=D and 3;
   Off:=BGetW(Cb,Ip);
   Inc(Ip,2);
   For I:=N-1 downto 0 do Args[I]:=Pop;
   SetLength(TP,0);
   Nm:=SymNameAt(Off);
   If(T=T_PERD)or((T>=T_P1D)and(T<=T_P3D))or(T=T_APRD)or((T>=T_AP1D)and(T<=T_AP3D))Then Begin
    L:=Pop;
    PcCat(TP,L.P);
    PcAdd(TP,0,'.'+Nm);
   End
    Else
   PcAdd(TP,0,Nm);
   If N>0 Then Begin
    PcAdd(TP,T_LPAR,'');
    For I:=0 to N-1 do Begin
     If I>0 Then PcAdd(TP,T_COMA,'');
     PcCat(TP,Args[I].P);
    End;
    PcAdd(TP,T_RPAR,'');
   End;
   L.P:=TP;L.Prec:=99;
   Push(L);
  End;
 End;
 If Sp>0 Then Begin
  L:=St[Sp-1];
  PrPieces(L.P);
 End;
End;

{ Niveau d'indentation (INDCHK) }
Function IndChk(D:Byte;B:Integer):Integer;
Var A:Integer;
Begin
 IndChk:=B;
 If(D and $80)<>0 Then Exit;
 A:=D and 3;
 If A=0 Then Exit;
 If A=1 Then Begin
  Inc(DcOcnt);
  Exit;
 End;
 Dec(B);
 If B<0 Then B:=0;
 If A<>3 Then Begin
  Dec(DcOcnt);
  If DcOcnt<0 Then DcOcnt:=0;
 End;
 IndChk:=B;
End;

{ Decompile une ligne d'I-code non lie. Ip est avance apres T_EOL. }
Function DcLine(Const Cb:TBuf;Var Ip:Longint;Const Sym:TSymTab;Pretty:Boolean):String;
Var T,D:Byte;B,I,N,Save:Integer;Off:Longint;M:Byte;First:Boolean;V:Word;S:String;
    Done:Boolean;
Begin
 DcSym:=Sym;
 DcPretty:=Pretty;
 IoBuf:='';
 IoCt:=1;
 Done:=False;
 If Ip>=Cb.Len Then Begin DcLine:='';Exit;End;
 T:=Cb.D[Ip];
 If T=T_LREF Then Begin
  Inc(Ip);
  CpyStr(IStr(BGetW(Cb,Ip)));
  Inc(Ip,2);
  OutSpc;
  T:=Cb.D[Ip];
 End;
 If Pretty Then Begin
  D:=DDesc[T];
  If T>=$80 Then D:=0;
  Save:=DcOcnt;
  B:=IndChk(D,DcOcnt);
  DcOcnt:=Save;
  DcTab((B*2)+6);
 End;
 While Not Done and(Ip<Cb.Len)do Begin
  T:=Cb.D[Ip];
  Inc(Ip);
  If T>=$80 Then Begin
   Dec(Ip);
   DcExprsn(Cb,Ip);
  End
   Else
  Begin
   D:=DDesc[T];
   IndChk(D,0);
   Case T of
    T_EOL:Done:=True;
    T_NEXT:Begin
            StrSpc('NEXT');
            Inc(Ip);
            Off:=BGetW(Cb,Ip);Inc(Ip,2);
            CpyStr(SymNameAt(Off));
            Inc(Ip,6);
           End;
    T_RUN:Begin
           StrSpc('RUN');
           Off:=BGetW(Cb,Ip);Inc(Ip,2);
           CpyStr(SymNameAt(Off));
          End;
    T_GOTO,T_GTBD,T_GOSB,T_GSBD:Begin
           If(T=T_GOTO)or(T=T_GTBD)Then SpcStr('GOTO')Else SpcStr('GOSUB');
           CpyStr(IStr(SmallInt(BGetW(Cb,Ip))));
           Inc(Ip,2);
          End;
    T_LREF,T_LRBD:Begin
           CpyStr(IStr(SmallInt(BGetW(Cb,Ip))));
           Inc(Ip,2);
          End;
    T_BAS0,T_BAS1:Begin
           StrSpc('BASE');
           PutCh(Chr(48+(T-T_BAS0)));
          End;
    T_REM1,T_REM2:Begin
           If T=T_REM1 Then StrSpc('REM')Else StrSpc('(*');
           N:=Cb.D[Ip];Inc(Ip);
           While N>1 do Begin
            PutCh(Chr(Cb.D[Ip]));
            Inc(Ip);Dec(N);
           End;
          End;
    T_ERRL,T_DEXC:Begin
           N:=Cb.D[Ip];Inc(Ip);
           While N>1 do Begin
            PutCh(Chr(Cb.D[Ip]));
            Inc(Ip);Dec(N);
           End;
          End;
    T_THEN:Begin
            SpcStr('THEN');
            If Cb.D[Ip]<>T_LREF Then Inc(DcOcnt);
           End;
    T_MODE:Begin
            M:=Cb.D[Ip];Inc(Ip);
            PutCh(':');
            First:=True;
            If(M and 3)=3 Then Begin
             CpyStr('UPDATE');M:=M and(Not 3);First:=False;
            End;
            If(M and 1)<>0 Then Begin
             If Not First Then PutCh('+');
             CpyStr('READ');First:=False;
            End;
            If(M and 2)<>0 Then Begin
             If Not First Then PutCh('+');
             CpyStr('WRITE');First:=False;
            End;
            If(M and 4)<>0 Then Begin
             If Not First Then PutCh('+');
             CpyStr('EXEC');First:=False;
            End;
            If(M and $80)<>0 Then Begin
             If Not First Then PutCh('+');
             CpyStr('DIR');
            End;
           End;
    T_LBNE:Inc(Ip,2);
   Else Begin
     If(D and $60)=$60 Then Inc(Ip,2);
     PrToke(T);
    End;
   End;
  End;
 End;
 DcLine:=IoBuf;
End;

{ ---------------------------------------------------------------------------- }
{  Console                                                                     }
{ ---------------------------------------------------------------------------- }

Procedure ConLine(Const S:String);
Begin
 WriteLn(S);
End;

Procedure PrtError(Code:Integer);
Var S:String;
Begin
 S:=IStr(Code);
 While Length(S)<3 do S:='0'+S;
 If ErrText(Code)<>'' Then ConLine('ERROR #'+S+'  '+ErrText(Code))
 Else ConLine('ERROR #'+S);
End;

Procedure BPrtErr(Code:Integer);
Begin
 PrtError(Code);
End;

{ ---------------------------------------------------------------------------- }
{  Binder (BIND) : transforme l'I-code non lie en I-code executable            }
{ ---------------------------------------------------------------------------- }

Const
 ARG_NONE=0;  ARG_1INT=1;  ARG_2INT=2;  ARG_1RL=3;   ARG_2RL=4;
 ARG_1NUM=5;  ARG_2NUM=6;  ARG_1STR=7;  ARG_2STR=8;  ARG_STRINT=9;
 ARG_STRIN2=10; ARG_1BL=11; ARG_2BL=12; ARG_2SN=13;  ARG_2BSN=14;
 OUTTOK=7;
 OPLAST=T_POS;
 MAXLN=2048;

Type
 TLnEnt = Record
  Line:Word;
  Def:Boolean;
  F:Word;           { decalage (defini) ou tete de la liste des references }
 End;
 TCtl = Record
  Tok:Byte;
  Ptr:Longint;      { position de la case de saut }
  FType:Byte;       { pour FOR : type du compteur }
  FSym:Word;        { decalage du symbole du compteur }
  FTerm,FStep:Word; { stockage du terminal et du pas }
 End;

Var
 BC:TBuf;                    { I-code en cours de liaison }
 BS:TSymTab;                 { table des symboles }
 BD:TBuf;                    { zone de description }
 BY:Longint;                 { pointeur d'I-code (registre Y) }
 BSmash:Boolean;             { True : mode PACK (SMASH=0) }
 BPrint:Boolean;             { affiche les erreurs }
 BErrs:Boolean;              { des erreurs ont ete rencontrees }
 NexAlc,NexPrm,NexRun:Word;
 PExecu:Boolean;
 PExec:Word;
 Dat1st:Word;
 DatPtr:Longint;
 DefNas,DefInt,Shape,TypeV:Byte;
 SymPtr:Longint;             { decalage du symbole courant }
 DscPtr:Word;                { decalage de la description d'enregistrement }
 RcdDsc:Word;
 ElmSiz:Word;
 CnvTok:Byte;
 LnTab:Array[0..MAXLN-1] of TLnEnt;
 NLn:Integer;
 Ctl:Array[0..255] of TCtl;
 NCtl:Integer;
 OTyp:Array[0..255] of Byte;
 ODsc:Array[0..255] of Word;
 OTop:Integer;
 LastDsc:Word;
 CL:Array[0..8191] of Byte;  { liste des composants (PCOMPT) }
 PComp:Integer;
 BLineMap:Array of Longint;
 BNLines:Longint;

Procedure BError(Code:Byte);
Begin
 BErrs:=True;
 If BPrint Then Begin
  Write(Hex4(BY),' ');
  BPrtErr(Code);
 End;
End;

Procedure QuitBind;
Begin
 BError(M_MFUL);
 Throw(JK_BIND,1);
End;

Function BW(P:Longint):Word;
Begin
 BW:=(Word(BC.D[P])shl 8)or BC.D[P+1];
End;

Procedure BPW(P:Longint;V:Word);
Begin
 BC.D[P]:=V shr 8;
 BC.D[P+1]:=V and $FF;
End;

Function DW(P:Longint):Word;
Begin
 DW:=(Word(BD.D[P])shl 8)or BD.D[P+1];
End;

Procedure DPW(P:Longint;V:Word);
Begin
 BD.D[P]:=V shr 8;
 BD.D[P+1]:=V and $FF;
End;

Function SW(P:Longint):Word;
Begin
 SW:=(Word(BS.B.D[P])shl 8)or BS.B.D[P+1];
End;

Procedure SPW(P:Longint;V:Word);
Begin
 BS.B.D[P]:=V shr 8;
 BS.B.D[P+1]:=V and $FF;
End;

{ Insere un octet a la position Y (INSTOK) ; Y suit le jeton decale }
Procedure InsTok(A:Byte);
Begin
 BInsert(BC,BY,1);
 BC.D[BY]:=A;
 Inc(BY);
End;

Procedure DelTok;
Begin
 BDelete(BC,BY,1);
End;

{ Pile d'operandes (types) }
Procedure PushOp(A:Byte);
Begin
 If A=S_BYTE Then A:=S_INT;
 If OTop<255 Then Begin
  OTyp[OTop]:=A;
  ODsc[OTop]:=DscPtr;
  Inc(OTop);
 End;
End;

Function PopOp:Byte;
Begin
 If OTop>0 Then Begin
  Dec(OTop);
  PopOp:=OTyp[OTop];
  LastDsc:=ODsc[OTop];
 End
  Else
 Begin
  PopOp:=S_INT;LastDsc:=$FFFF;
 End;
End;

Function GetVSz(A:Byte):Word;
Begin
 Case A of
  S_BYTE:GetVSz:=1;
  S_INT:GetVSz:=2;
  S_REAL:GetVSz:=5;
  S_BOOL:GetVSz:=1;
  S_STR:GetVSz:=32;
 Else GetVSz:=0;
 End;
End;

{ Allonge la zone de description de N octets ; retourne le decalage }
Function ExpDsc(N:Longint):Longint;
Begin
 ExpDsc:=BD.Len;
 BInsert(BD,BD.Len,N);
End;

Procedure GetTyp;
Begin
 SymPtr:=BW(BY+1);
 DefInt:=BS.B.D[SymPtr]and S_DEFM;
 Shape:=BS.B.D[SymPtr]and S_SHPM;
 TypeV:=BS.B.D[SymPtr]and S_TYPM;
End;

Procedure GetTyAt(Off:Longint);
Begin
 DefInt:=BS.B.D[Off]and S_DEFM;
 Shape:=BS.B.D[Off]and S_SHPM;
 TypeV:=BS.B.D[Off]and S_TYPM;
End;

{ ---------------------------------------------------------------------------- }
{  Allocation de stockage                                                      }
{ ---------------------------------------------------------------------------- }

Procedure AlcSto(X:Longint);
Var Def,Typ:Byte;Sh:Byte;Par:Boolean;Dp:Longint;D:Word;
Begin
 Typ:=BS.B.D[X];
 Def:=Typ and S_DEFM;
 Par:=False;
 If(Def<>S_VAR)and(Def<>S_FLDD)Then Begin
  If Def<>S_PARM Then Exit;
  Par:=True;
 End;
 Sh:=Typ and S_SHPM;
 If Sh<>0 Then Begin
   { tableau }
  Dp:=SW(X+1);
  D:=DW(Dp+2);
  If Par Then Begin DPW(Dp,NexPrm);Inc(NexPrm,4);End
  Else Begin DPW(Dp,NexAlc);NexAlc:=NexAlc+D;End;
  Exit;
 End;
 Typ:=Typ and S_TYPM;
 If Typ<S_STR Then Begin
  If Par Then Begin SPW(X+1,NexPrm);Inc(NexPrm,4);End
  Else Begin
   D:=GetVSz(Typ);
   SPW(X+1,NexAlc);
   NexAlc:=NexAlc+D;
  End;
 End
  Else
 Begin
   { chaine ou enregistrement : description de 4 octets }
  Dp:=ExpDsc(4);
  D:=SW(X+1);
  DPW(Dp+2,D);
  SPW(X+1,Dp);
  If Typ=S_RCRD Then Begin
   D:=DW(D);                      { taille totale de l'enregistrement }
  End;
  If Par Then Begin DPW(Dp,NexPrm);Inc(NexPrm,4);End
  Else Begin DPW(Dp,NexAlc);NexAlc:=NexAlc+D;End;
 End;
End;

Procedure ChkDef;
Begin
 If DefInt=S_UNDF Then Begin
  Shape:=S_SIMP;
  DefInt:=S_VAR;
  BS.B.D[SymPtr]:=S_VAR+S_SIMP+TypeV;
  If TypeV=S_STR Then SPW(SymPtr+1,32);
  AlcSto(SymPtr);
 End;
End;

{ Table des numeros de ligne }
Function SrhLin(Line:Word;Var Idx:Integer):Boolean;
Var I:Integer;
Begin
 For I:=NLn-1 downto 0 do Begin
  If LnTab[I].Line=Line Then Begin
   Idx:=I;
   SrhLin:=LnTab[I].Def;
   Exit;
  End;
 End;
 If NLn>=MAXLN Then QuitBind;
 LnTab[NLn].Line:=Line;
 LnTab[NLn].Def:=False;
 LnTab[NLn].F:=0;
 Idx:=NLn;
 Inc(NLn);
 SrhLin:=False;
End;

{ ---------------------------------------------------------------------------- }
{  Pile de controle                                                            }
{ ---------------------------------------------------------------------------- }

Procedure PushCn(A:Byte);
Begin
 If NCtl<255 Then Begin
  Ctl[NCtl].Tok:=A;
  Ctl[NCtl].Ptr:=BY;
  Inc(NCtl);
 End;
End;

{ CONCHK : trouve la structure de controle de type A ; Idx = entree }
Function ConChk(A:Byte;Skip:Integer;Var Idx:Integer):Boolean;
Var I:Integer;
Begin
 ConChk:=False;
 I:=NCtl-1;
 While(I>=0)and(Ctl[I].Tok=T_EEXT)do Dec(I);
 If(I<0)or(Ctl[I].Tok<>A)Then Begin
  BError(M_UCS);
  Inc(BY,Skip);
  If(BY<BC.Len)and((BC.D[BY]=T_EOL)or(BC.D[BY]=T_BKSL))Then Inc(BY);
  Exit;
 End;
 Idx:=I;
 ConChk:=True;
End;

Procedure PopCn;
Begin
 While(NCtl>0)and(Ctl[NCtl-1].Tok=T_EEXT)do Begin
  BPW(Ctl[NCtl-1].Ptr,BY);
  Dec(NCtl);
 End;
 If NCtl>0 Then Dec(NCtl);
End;

{ ---------------------------------------------------------------------------- }
{  Expressions                                                                 }
{ ---------------------------------------------------------------------------- }

Var
 ExRes:Array[0..255] of Byte;     { type du resultat (0 = type de l'argument) }
 ExArg:Array[0..255] of Byte;     { code d'argument }

Procedure ExDef(T,R,A:Byte);
Begin
 ExRes[T]:=R;
 ExArg[T]:=A;
End;

Procedure InitBindTables;
Var I:Integer;
Begin
 For I:=0 to 255 do Begin ExRes[I]:=0;ExArg[I]:=255;End;
 ExDef(T_POS,S_INT,0);   ExDef(T_ERR,S_INT,0);
 ExDef(T_MOD,0,ARG_2NUM);
 ExDef(T_RND,S_REAL,ARG_1RL);  ExDef(T_PI,S_REAL,0);
 ExDef(T_SUBS,S_INT,ARG_2STR); ExDef(T_SGN,S_INT,ARG_1NUM);
 ExDef(T_SIN,S_REAL,ARG_1RL);  ExDef(T_COS,S_REAL,ARG_1RL);
 ExDef(T_TAN,S_REAL,ARG_1RL);  ExDef(T_ASN,S_REAL,ARG_1RL);
 ExDef(T_ACS,S_REAL,ARG_1RL);  ExDef(T_ATN,S_REAL,ARG_1RL);
 ExDef(T_EXP,S_REAL,ARG_1RL);  ExDef(T_ABS,0,ARG_1NUM);
 ExDef(T_LN,S_REAL,ARG_1RL);   ExDef(T_LOG,S_REAL,ARG_1RL);
 ExDef(T_SQR,S_REAL,ARG_1RL);  ExDef(T_INTF,S_REAL,ARG_1NUM);
 ExDef(T_FIX,S_INT,ARG_1NUM);  ExDef(T_FLOT,S_REAL,ARG_1NUM);
 ExDef(T_SQ,0,ARG_1NUM);       ExDef(T_PEEK,S_INT,ARG_1INT);
 ExDef(T_NNOT,S_INT,ARG_1INT); ExDef(T_VAL,S_REAL,ARG_1STR);
 ExDef(T_LEN,S_INT,ARG_1STR);  ExDef(T_ASC,S_INT,ARG_1STR);
 ExDef(T_NAND,S_INT,ARG_2INT); ExDef(T_NOR,S_INT,ARG_2INT);
 ExDef(T_NXOR,S_INT,ARG_2INT); ExDef(T_TRUE,S_BOOL,0);
 ExDef(T_FALS,S_BOOL,0);       ExDef(T_EOF,S_BOOL,ARG_1INT);
 ExDef(T_TRIM,S_STR,ARG_1STR); ExDef(T_MID,S_STR,ARG_STRIN2);
 ExDef(T_LEFT,S_STR,ARG_STRINT);ExDef(T_RGHT,S_STR,ARG_STRINT);
 ExDef(T_CHR,S_STR,ARG_1INT);  ExDef(T_STRF,S_STR,ARG_1NUM);
 ExDef(T_DATE,S_STR,0);        ExDef(T_TAB,S_STR,ARG_1INT);
 For I:=T_FIX1 to T_FLT2 do ExDef(I,OUTTOK,0);
 ExDef(T_NOT,S_BOOL,ARG_1BL);  ExDef(T_NEG,0,ARG_1NUM);
 ExDef(T_AND,S_BOOL,ARG_2BL);  ExDef(T_OR,S_BOOL,ARG_2BL);
 ExDef(T_XOR,S_BOOL,ARG_2BL);
 ExDef(T_GT,S_BOOL,ARG_2SN);   ExDef(T_LT,S_BOOL,ARG_2SN);
 ExDef(T_NE,S_BOOL,ARG_2BSN);  ExDef(T_EQ,S_BOOL,ARG_2BSN);
 ExDef(T_GE,S_BOOL,ARG_2SN);   ExDef(T_LE,S_BOOL,ARG_2SN);
 ExDef(T_PLUS,0,ARG_2SN);      ExDef(T_MINS,0,ARG_2NUM);
 ExDef(T_MUL,0,ARG_2NUM);      ExDef(T_DIV,0,ARG_2NUM);
 ExDef(T_POWR,S_REAL,ARG_2RL); ExDef(T_POWR+1,S_REAL,ARG_2RL);
End;

Procedure ComErr;
Begin
 BY:=BC.Len;
 BError(M_UNIM);
End;

Function PInt(B:Byte):Byte;
Var A:Byte;
Begin
 A:=PopOp;
 If A<S_REAL Then Begin PInt:=A;Exit;End;
 If A=S_REAL Then InsTok(B)
 Else BError(M_IARG);
 PInt:=S_INT;
End;

Function P1Int:Byte;
Begin
 P1Int:=PInt(T_FIX1);
End;

Function PReal(B:Byte):Byte;
Var A:Byte;
Begin
 A:=PopOp;
 If A<S_REAL Then InsTok(B)
 Else If A>S_REAL Then BError(M_IARG);
 PReal:=S_REAL;
End;

Function PNum:Byte;
Var A:Byte;
Begin
 A:=PopOp;
 If A>S_REAL Then Begin
  BError(M_IARG);
  A:=S_REAL;
 End;
 PNum:=A;
End;

Function P1Num:Byte;
Var A:Byte;
Begin
 A:=PNum;
 If A=S_REAL Then Inc(BC.D[BY]);
 P1Num:=A;
End;

Function P2Num:Byte;
Var R,L,T:Byte;
Begin
 R:=PNum;
 L:=PNum;
 If L=R Then Begin
  If L=S_REAL Then Inc(BC.D[BY]);
  P2Num:=L;
  Exit;
 End;
 If L>=R Then T:=T_FLT1 Else T:=T_FLT2;
 InsTok(T);
 Inc(BC.D[BY]);
 P2Num:=S_REAL;
End;

Function P1Str:Byte;
Var A:Byte;
Begin
 A:=PopOp;
 If A<>S_STR Then BError(M_IARG);
 P1Str:=S_STR;
End;

Function P1Bool:Byte;
Var A:Byte;
Begin
 A:=PopOp;
 If A<>S_BOOL Then BError(M_IARG);
 P1Bool:=S_BOOL;
End;

{ P2ARG : les deux operandes du dessus sont-ils du type A ? (les depile si oui) }
Function P2Arg(A:Byte):Boolean;
Begin
 P2Arg:=False;
 If OTop<2 Then Exit;
 If(OTyp[OTop-1]<>A)or(OTyp[OTop-2]<>A)Then Exit;
 Dec(OTop,2);
 P2Arg:=True;
End;

Function P2SN:Byte;
Begin
 If P2Arg(S_STR)Then Begin
  Inc(BC.D[BY],2);
  P2SN:=S_STR;
 End
  Else
 P2SN:=P2Num;
End;

Function P2BSN:Byte;
Begin
 If P2Arg(S_BOOL)Then Begin
  Inc(BC.D[BY],3);
  P2BSN:=S_BOOL;
 End
  Else
 P2BSN:=P2SN;
End;

Function PArgs(Code:Byte):Byte;
Var A:Byte;
Begin
 A:=0;
 Case Code of
  ARG_1INT:A:=P1Int;
  ARG_2INT:Begin P1Int;A:=PInt(T_FIX2);End;
  ARG_1RL:A:=PReal(T_FLT1);
  ARG_2RL:Begin PReal(T_FLT1);A:=PReal(T_FLT2);End;
  ARG_1NUM:A:=P1Num;
  ARG_2NUM:A:=P2Num;
  ARG_1STR:A:=P1Str;
  ARG_2STR:Begin P1Str;A:=P1Str;End;
  ARG_STRINT:Begin P1Int;A:=P1Str;End;
  ARG_STRIN2:Begin P1Int;PInt(T_FIX2);A:=P1Str;End;
  ARG_1BL:A:=P1Bool;
  ARG_2BL:Begin P1Bool;A:=P1Bool;End;
  ARG_2SN:A:=P2SN;
  ARG_2BSN:A:=P2BSN;
 Else ComErr;
 End;
 PArgs:=A;
End;

Procedure PExprn;Forward;

Procedure ChkVarB(Base:Byte;X:Longint;Var A:Byte);
Var B:Integer;D:Word;U:Longint;
Begin
 B:=BC.D[BY]-Base;
 If B=0 Then Begin
  If Shape<>0 Then Begin
   TypeV:=S_RCRD;
   DscPtr:=$FFFF;
   A:=TypeV;
   Exit;
  End;
 End
  Else
 Begin
  If(B*8)<>Shape Then BError(M_IES);
  CnvTok:=T_FIX1;
  While B>0 do Begin
   A:=PopOp;
   If A=S_REAL Then InsTok(CnvTok)
   Else If A>S_REAL Then BError(M_IET);
   Inc(CnvTok);
   Dec(B);
  End;
 End;
 If TypeV=S_RCRD Then Begin
  U:=SW(X+1);
  If Shape=0 Then D:=DW(U+2)
  Else D:=DW(U+(Shape shr 2)+4);
  DscPtr:=D;
 End;
 A:=TypeV;
End;

Procedure PVRef;
Var A,B:Byte;
Begin
 GetTyp;
 ChkDef;
 If(DefInt=S_VAR)or(DefInt=S_PARM)Then Begin
  ChkVarB(T_VREF,SymPtr,A);
  If(BC.D[BY]=T_VREF)and(DefInt=S_VAR)and(A<S_RCRD)Then Begin
   BC.D[BY]:=A+T_SBYT;
   BPW(BY+1,SW(SymPtr+1));
  End;
 End
  Else
 BError(M_IOPD);
 PushOp(TypeV);
 Inc(BY,3);
End;

Procedure PFRef;
Var A:Byte;RcdD:Word;Cnt,I:Integer;Sy:Word;P:Longint;Found:Boolean;
Begin
 GetTyp;
 ChkVarB(T_PERD,SymPtr,A);
 A:=PopOp;
 If A=S_RCRD Then RcdD:=LastDsc Else RcdD:=$FFFF;
 Sy:=SymPtr;
 PushOp(TypeV);
 Inc(BY,3);
 If RcdD=$FFFF Then BError(M_NRTO)
  Else
 Begin
  Cnt:=BD.D[RcdD+2];
  P:=RcdD+3;
  Found:=False;
  For I:=1 to Cnt do Begin
   If DW(P)=Sy Then Begin Found:=True;Break;End;
   Inc(P,2);
  End;
  If Not Found Then BError(M_IRFN);
 End;
End;

Procedure PAsg00;
Var A:Byte;
Begin
 A:=BC.D[BY-3];
 If A<T_VREF Then Begin
  BPW(BY-2,SymPtr);
  A:=T_VREF;
 End;
 BC.D[BY-3]:=A+(T_AREF-T_VREF);
End;

Procedure PExSub(B:Byte);
Var A:Byte;
Begin
 If B<T_VREF Then Begin ComErr;Exit;End;
 If B<T_PERD Then Begin PVRef;Exit;End;
 If B<T_BLIT Then Begin PFRef;Exit;End;
 Case B of
  T_BLIT:Begin PushOp(S_INT);Inc(BY,2);End;
  T_ILIT:Begin PushOp(S_INT);Inc(BY,3);End;
  T_RLIT:Begin PushOp(S_REAL);Inc(BY,6);End;
  T_SLIT:Begin
          Inc(BY);
          While(BY<BC.Len)and(BC.D[BY]<>V_ESTR)do Inc(BY);
          Inc(BY);
          PushOp(S_STR);
         End;
  T_HLIT:Begin PushOp(S_INT);Inc(BY,3);End;
  T_ADDR,T_LENG:Begin
          PAsg00;
          PopOp;
          PushOp(S_INT);
          Inc(BY);
         End;
  T_ADDR+1,T_LENG+1:Inc(BY);
 Else ComErr;
 End;
End;

Procedure PExprn;
Var B,C,A:Byte;
Begin
 While(BY<BC.Len)and(BC.D[BY]>=$80)do Begin
  B:=BC.D[BY];
  If B<OPLAST Then Begin
   PExSub(B);
   If BY>=BC.Len Then Exit;
   Continue;
  End;
  If B>=T_AREF Then Begin ComErr;Exit;End;
  If ExArg[B]=255 Then Begin ComErr;Exit;End;
  A:=0;
  If ExArg[B]<>0 Then A:=PArgs(ExArg[B]);
  If BY>=BC.Len Then Exit;
  If ExRes[B]<>0 Then Begin
   A:=ExRes[B];
   If A=OUTTOK Then Begin
    DelTok;
    Continue;
   End;
  End;
  PushOp(A);
  Inc(BY);
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Instructions                                                                }
{ ---------------------------------------------------------------------------- }

Function EolTst(B:Byte):Boolean;
Begin
 EolTst:=(B=T_EOL)or(B=T_BKSL);
End;

Procedure SkpEol;
Begin
 If(BY<BC.Len)and EolTst(BC.D[BY])Then Inc(BY);
End;

Procedure SkpOne;
Begin
 Inc(BY);
End;

Procedure PEol;
Begin
 SkpEol;
End;

Procedure PErrLn;
Begin
 BErrs:=True;
 Inc(BY);
 Inc(BY,Longint(BC.D[BY-1]));
End;

Procedure PRemrk;
Var N:Integer;
Begin
 N:=BC.D[BY];
 Inc(BY);
 Inc(BY,N);
End;

Procedure PIExpr;
Var A:Byte;
Begin
 PExprn;
 A:=PopOp;
 If A=S_REAL Then InsTok(T_FIX1)
 Else If A>S_REAL Then BError(M_IET);
End;

Procedure PPok20;
Begin
 PIExpr;
 Inc(BY);
End;

Procedure PBExpr;
Var A:Byte;
Begin
 PExprn;
 A:=PopOp;
 If A<>S_BOOL Then BError(M_IET);
 Inc(BY);
End;

Procedure PSExpr;
Var A:Byte;
Begin
 PExprn;
 A:=PopOp;
 If A<>S_STR Then BError(M_IET);
End;

Procedure PGoto;
Var Idx:Integer;D:Word;
Begin
 D:=BW(BY);
 If SrhLin(D,Idx)Then Begin
  BPW(BY,LnTab[Idx].F);
 End
  Else
 Begin
  BPW(BY,LnTab[Idx].F);
  LnTab[Idx].F:=BY;
 End;
 Inc(BC.D[BY-1]);
 Inc(BY,3);
End;

Procedure PStmt;Forward;

Procedure PLRef;
Var D:Word;Idx:Integer;L,Nx:Word;
Begin
 D:=BW(BY);
 If BSmash Then Begin
  BDelete(BC,BY-1,3);
  Dec(BY);
 End
  Else
 Inc(BY,2);
 If Not SrhLin(D,Idx)Then Begin
  LnTab[Idx].Def:=True;
  L:=LnTab[Idx].F;
  LnTab[Idx].F:=BY;
  While L<>0 do Begin
   Nx:=BW(L);
   BPW(L,BY);
   L:=Nx;
  End;
 End
  Else
 BError(M_MDLN);
 PStmt;
End;

Procedure PAsgVr;
Begin
 If BC.D[BY]<>T_CXAS Then Begin
  PExprn;
  Exit;
 End;
 Inc(BY);
 PExprn;
 PAsg00;
End;

Procedure PLet;
Var Ty,Dest:Byte;
Begin
 PAsgVr;
 Inc(BY);
 PExprn;
 Ty:=PopOp;
 Dest:=PopOp;
 If Dest<>Ty Then Begin
  If Dest>S_REAL Then BError(M_IET)
  Else Begin
   If Ty>S_REAL Then BError(M_IET)
   Else If Dest=S_REAL Then InsTok(T_FLT1)
   Else InsTok(T_FIX1);
  End;
 End;
 SkpEol;
End;

Procedure PAssgn;
Begin
 Dec(BY);
 PLet;
End;

Procedure PPoke;
Begin
 PPok20;
 PPok20;
End;

Procedure PGetSiz(Var D:Word);
Var T:Byte;
Begin
 T:=BC.D[BY];Inc(BY);
 D:=0;
 If T<>T_BLIT Then Begin
  D:=Word(BC.D[BY])shl 8;
  Inc(BY);
 End;
 D:=D or BC.D[BY];
 Inc(BY);
End;

{ PID : traite un identificateur de variable dans une declaration }
Procedure PId;
Var N,D:Word;Dm:Word;
Begin
 GetTyp;
 If DefInt<>0 Then Begin
  BError(M_MDV);
  Inc(BY,3);
  If BC.D[BY]=T_LPAR Then Begin
   Inc(BY);
   Repeat
    PGetSiz(Dm);
    N:=BC.D[BY];Inc(BY);
   Until N<>T_COMA;
  End;
  Exit;
 End;
 If PComp>8100 Then QuitBind;
 CL[PComp]:=SymPtr shr 8;CL[PComp+1]:=SymPtr and $FF;
 Inc(PComp,2);
 Inc(BY,3);
 N:=PComp;
 CL[PComp]:=0;Inc(PComp);
 If BC.D[BY]=T_LPAR Then Begin
  Inc(BY);
  Repeat
   PGetSiz(Dm);
   CL[PComp]:=Dm shr 8;CL[PComp+1]:=Dm and $FF;
   Inc(PComp,2);
   Inc(CL[N]);
   D:=BC.D[BY];Inc(BY);
  Until D<>T_COMA;
 End;
End;

Procedure PVType;
Var T:Byte;Dm:Word;
Begin
 T:=BC.D[BY];Inc(BY);
 If T=T_VREF Then Begin
  Dec(BY);
  GetTyp;
  Inc(BY,3);
  If DefInt<>S_TYPD Then Begin
   BError(M_ITYP);
   Exit;
  End;
  RcdDsc:=SW(SymPtr+1);
  ElmSiz:=DW(RcdDsc);
  Exit;
 End;
 TypeV:=T-T_BYTE;
 If TypeV=S_STR Then Begin
  If BC.D[BY]=T_LBKT Then Begin
   Inc(BY);
   PGetSiz(Dm);
   ElmSiz:=Dm;
   Inc(BY);
  End
   Else
  ElmSiz:=GetVSz(TypeV);
 End
  Else
 ElmSiz:=GetVSz(TypeV);
End;

Procedure DimMul(Dp:Longint;D:Word);
Var T:Longint;
Begin
 T:=Longint(DW(Dp+2))*D;
 If T>65535 Then Begin
  BError(M_ASO);
  T:=T and $FFFF;
 End;
 DPW(Dp+2,T);
End;

{ DEFVAR : definit la variable du symbole U ; X pointe sur le nombre d'indices }
Procedure DefVar(Var X:Integer;U:Longint);
Var N,I:Integer;Dp,Q:Longint;Sz:Integer;Dm:Word;SaveSh:Byte;
Begin
 N:=CL[X];Inc(X);
 If N=0 Then Begin
  Shape:=0;
  If TypeV>S_STR Then SPW(U+1,RcdDsc)Else SPW(U+1,ElmSiz);
 End
  Else
 Begin
  Shape:=N*8;
  Q:=X;
  Inc(X,N*2);
  Sz:=4+N*2;
  If TypeV>=S_STR Then Inc(Sz,2);
  Dp:=ExpDsc(Sz);
  DPW(Dp+2,1);
  For I:=0 to N-1 do Begin
   Dm:=(Word(CL[Q+(N-1-I)*2])shl 8)or CL[Q+(N-1-I)*2+1];
   DPW(Dp+4+I*2,Dm);
   DimMul(Dp,Dm);
  End;
  If TypeV>S_STR Then DPW(Dp+4+N*2,RcdDsc)
  Else If TypeV=S_STR Then DPW(Dp+4+N*2,ElmSiz);
  DimMul(Dp,ElmSiz);
  SPW(U+1,Dp);
 End;
 BS.B.D[U]:=TypeV or Shape or DefNas;
 AlcSto(U);
 CL[PComp]:=U shr 8;CL[PComp+1]:=U and $FF;
 Inc(PComp,2);
End;

Procedure PDeclr;
Var Cur,EndP,ReadP:Integer;Flag:Boolean;T:Byte;Sy:Longint;Save:Integer;
Begin
 PComp:=0;
 Cur:=0;
 Repeat
  Repeat
   PId;
   T:=BC.D[BY];Inc(BY);
  Until T<>T_COMA;
  If T=T_COL Then Begin
   PVType;
   Flag:=False;
  End
   Else
  Begin
   Dec(BY);
   Flag:=True;
  End;
  EndP:=PComp;
  ReadP:=Cur;
  PComp:=Cur;
  While ReadP<EndP do Begin
   Sy:=(Longint(CL[ReadP])shl 8)or CL[ReadP+1];
   Inc(ReadP,2);
   If Flag Then Begin
    TypeV:=BS.B.D[Sy]and S_TYPM;
    ElmSiz:=GetVSz(TypeV);
   End;
   DefVar(ReadP,Sy);
  End;
  Cur:=PComp;
  T:=BC.D[BY];Inc(BY);
 Until T<>T_SCOL;
End;

Procedure PType;
Var TSym:Longint;Saved,N,I:Integer;Dp:Longint;Sy:Word;
Begin
 GetTyp;
 If DefInt<>0 Then BError(M_MDV);
 TSym:=SymPtr;
 Inc(BY,4);
 DefNas:=S_FLDD;
 Saved:=NexAlc;
 NexAlc:=0;
 PDeclr;
 N:=PComp div 2;
 If N>0 Then Begin
  Dp:=ExpDsc(N*2+3);
  DPW(Dp,NexAlc);
  BD.D[Dp+2]:=N;
  For I:=0 to N-1 do Begin
   BD.D[Dp+3+I*2]:=CL[I*2];
   BD.D[Dp+3+I*2+1]:=CL[I*2+1];
  End;
  SPW(TSym+1,Dp);
  BS.B.D[TSym]:=S_TYPD+S_RCRD;
 End;
 NexAlc:=Saved;
End;

Procedure PDim;
Begin
 DefNas:=S_VAR;
 PDeclr;
End;

Procedure PParam;
Begin
 DefNas:=S_PARM;
 PDeclr;
End;

Procedure PData;
Begin
 If DatPtr<0 Then Dat1st:=BY
 Else BPW(DatPtr,BY);
 Repeat
  PExprn;
  PopOp;
  OTop:=0;
  Inc(BY);
 Until BC.D[BY-1]<>T_COMA;
 DatPtr:=BY;
 BPW(BY,Dat1st);
 Inc(BY,2);
 SkpOne;
End;

Procedure PIf;
Var S:Longint;
Begin
 PBExpr;
 If BC.D[BY+3]=T_LREF Then Begin
  S:=BY;
  Inc(BY,4);
  PGoto;
  BPW(S,BY);
 End
  Else
 Begin
  PushCn(T_IF);
  Inc(BY,3);
  SkpEol;
 End;
End;

Procedure PElse;
Var I:Integer;U:Longint;
Begin
 If Not ConChk(T_IF,2,I)Then Exit;
 U:=Ctl[I].Ptr;
 Ctl[I].Ptr:=BY;
 Inc(BY,2);
 SkpEol;
 BPW(U,BY);
End;

Procedure PEif;
Var I:Integer;
Begin
 If Not ConChk(T_IF,1,I)Then Exit;
 Inc(BY);
 BPW(Ctl[I].Ptr,BY);
 PopCn;
End;

Procedure ForTyp(CType:Byte);
Var A:Byte;
Begin
 PExprn;
 A:=PopOp;
 If A<>CType Then Begin
  If A<S_REAL Then InsTok(T_FLT1)
  Else If A=S_REAL Then InsTok(T_FIX1)
  Else BError(M_IET);
 End;
End;

Function ForSub(CType:Byte):Word;
Var D:Word;
Begin
 D:=NexAlc;
 BPW(BY+1,D);
 NexAlc:=NexAlc+GetVSz(CType);
 Inc(BY,3);
 ForTyp(CType);
 ForSub:=D;
End;

Procedure PFor;
Var E:TCtl;Ok:Boolean;
Begin
 GetTyp;
 ChkDef;
 Ok:=False;
 If DefInt=S_VAR Then Begin
  If(TypeV=S_INT)or(TypeV=S_REAL)Then Begin
   If Shape=0 Then Begin
    BC.D[BY]:=TypeV+T_SBYT;
    BPW(BY+1,SW(SymPtr+1));
    Ok:=True;
   End;
  End;
 End;
 If Not Ok Then Begin
  BError(M_IFV);
  SymPtr:=$FFFF;
 End;
 E.FType:=TypeV;
 E.FSym:=SymPtr;
 E.FTerm:=0;E.FStep:=0;
 Inc(BY,4);
 ForTyp(E.FType);
 E.FTerm:=ForSub(E.FType);
 If BC.D[BY]=T_STEP Then E.FStep:=ForSub(E.FType);
 Inc(BY);
 E.Tok:=T_FOR;
 E.Ptr:=BY;
 If NCtl<255 Then Begin
  Ctl[NCtl]:=E;
  Inc(NCtl);
 End;
 Inc(BY,3);
End;

Procedure PNext;
Var I:Integer;E:TCtl;S:Word;
Begin
 Dec(BY);
 If Not ConChk(T_FOR,11,I)Then Exit;
 E:=Ctl[I];
 If BW(BY+2)<>E.FSym Then Begin
  BError(M_IFV);
 End
  Else
 Begin
  S:=SW(BW(BY+2)+1);
  BPW(BY+2,S);
  BC.D[BY+1]:=E.FType and 2;
  BPW(BY+4,E.FTerm);
  BPW(BY+6,E.FStep);
  If E.FStep<>0 Then Inc(BC.D[BY+1]);
  BPW(E.Ptr,BY+1);
  BPW(BY+8,E.Ptr+3);
 End;
 Inc(BY,11);
 PopCn;
End;

Procedure PWhile;
Var U:Longint;
Begin
 U:=BY-1;
 PBExpr;
 BPW(BY,U);
 PushCn(T_WHIL);
 Inc(BY,3);
 SkpEol;
End;

Procedure PEwhl;
Var I:Integer;X:Longint;
Begin
 If Not ConChk(T_WHIL,3,I)Then Exit;
 X:=Ctl[I].Ptr;
 BPW(BY,BW(X));
 Inc(BY,3);
 BPW(X,BY);
 PopCn;
End;

Procedure PRept;
Begin
 SkpOne;
 PushCn(T_REPT);
End;

Procedure PUnt10(A:Byte);
Var I:Integer;
Begin
 Dec(BY);
 If Not ConChk(A,3,I)Then Exit;
 BPW(BY+1,Ctl[I].Ptr);
 Inc(BY,4);
 PopCn;
End;

Procedure PUntil;
Begin
 PBExpr;
 PUnt10(T_REPT);
End;

Procedure PLoop;
Begin
 SkpOne;
 PushCn(T_LOOP);
End;

Procedure PELoop;
Begin
 PUnt10(T_LOOP);
End;

Procedure PExif;
Begin
 PBExpr;
 PushCn(T_EXIF);
 Inc(BY,3);
 SkpEol;
End;

Procedure PEExt;
Var I:Integer;U:Longint;
Begin
 If Not ConChk(T_EXIF,3,I)Then Exit;
 U:=BY;
 Inc(BY,3);
 BPW(Ctl[I].Ptr,BY);
 PopCn;
 If NCtl<255 Then Begin
  Ctl[NCtl].Tok:=T_EEXT;
  Ctl[NCtl].Ptr:=U;
  Inc(NCtl);
 End;
End;

Procedure PGotoSt;
Begin
 PGoto;
End;

Procedure PErrorSt;
Begin
 PIExpr;
End;

Procedure POn;
Var T:Byte;Cnt:Word;
Begin
 T:=BC.D[BY];Inc(BY);
 If T=T_EROR Then Begin
  T:=BC.D[BY];Inc(BY);
  If EolTst(T)Then Exit;
  PGoto;
  Exit;
 End;
 Dec(BY);
 PPok20;
 Cnt:=BW(BY);
 Inc(BY,2);
 While Cnt>0 do Begin
  Inc(BY);
  PGoto;
  Dec(Cnt);
 End;
End;

Procedure PRPram;
Var T:Byte;
Begin
 T:=BC.D[BY];Inc(BY);
 If T<>T_LPAR Then Exit;
 Repeat
  PAsgVr;
  PopOp;
  T:=BC.D[BY];Inc(BY);
 Until T<>T_COMA;
 Inc(BY);
End;

Procedure PRun;
Var D:Byte;
Begin
 Dec(BY);
 GetTyp;
 D:=DefInt;
 If D=S_UNDF Then Begin
  BS.B.D[SymPtr]:=S_PROC;
  SPW(SymPtr+1,NexRun);
  Inc(NexRun,2);
 End
  Else
 If D<>S_PROC Then Begin
  If(D<S_VAR)or(Shape<>0)or(TypeV<>S_STR)Then BError(M_MDV);
 End;
 Inc(BY,3);
 PRPram;
End;

Procedure PChlNm(Var B:Byte);
Begin
 B:=BC.D[BY];Inc(BY);
 If B<>T_CNUM Then Exit;
 PIExpr;
 Repeat
  B:=BC.D[BY];Inc(BY);
 Until(B<>T_COMA)and(B<>T_SCOL);
End;

Procedure PInput;
Var B,A,T:Byte;
Begin
 PChlNm(B);
 Dec(BY);
 If B=T_SLIT Then Begin
  PSExpr;
  Inc(BY);
 End;
 Repeat
  PAsgVr;
  A:=PopOp;
  If A>=S_RCRD Then BError(M_IIV);
  T:=BC.D[BY];Inc(BY);
 Until T<>T_COMA;
End;

Procedure PPrint;
Var B,A:Byte;
Begin
 PChlNm(B);
 If B=T_USNG Then Begin
  PSExpr;
  B:=BC.D[BY];Inc(BY);
 End;
 While True do Begin
  If(B=T_COMA)or(B=T_SCOL)Then Begin
   B:=BC.D[BY];Inc(BY);
   Continue;
  End;
  If EolTst(B)Then Exit;
  Dec(BY);
  PExprn;
  A:=PopOp;
  If A>=S_RCRD Then BError(M_IET);
  B:=BC.D[BY];Inc(BY);
 End;
End;

Procedure POpen;
Var A:Byte;T:Byte;
Begin
 Inc(BY);
 PAsgVr;
 A:=PopOp;
 If A<>S_INT Then BError(M_IET);
 Inc(BY);
 PSExpr;
 T:=BC.D[BY];Inc(BY);
 If T=T_MODE Then Inc(BY,2);
End;

Procedure PIoBgn;
Begin
 Inc(BY);
 PPok20;
End;

Procedure PSeek;
Var A:Byte;
Begin
 PIoBgn;
 PExprn;
 A:=PopOp;
 If A>S_REAL Then BError(M_IET)
 Else PEol;
End;

Procedure PGet;
Begin
 PIoBgn;
 PAsgVr;
 PopOp;
 PEol;
End;

Procedure PClose;
Begin
 Repeat
  PIoBgn;
 Until BC.D[BY-1]<>T_COMA;
 PEol;
End;

Procedure PSExprSt;
Begin
 PSExpr;
 PEol;
End;

Procedure PRest;
Var T:Byte;
Begin
 T:=BC.D[BY];Inc(BY);
 If T=T_LREF Then Begin
  PGoto;
  Exit;
 End;
 PEol;
End;

Procedure PNull;
Begin
 PEol;
End;

Function IsExecTok(T:Byte):Boolean;
Begin
 Case T of
  T_PRAM,T_TYPE,T_DIM,T_DATA,T_REM1,T_REM2,T_LREF,T_ERRL,T_BKSL,T_EOL:IsExecTok:=False;
 Else IsExecTok:=True;
 End;
End;

Procedure PStmt;
Var T:Byte;
Begin
 T:=BC.D[BY];Inc(BY);
 If(T>=$80)Then Begin
  If Not PExecu Then Begin PExecu:=True;PExec:=BY-1;End;
  Dec(BY);
  PLet;
  Exit;
 End;
 If IsExecTok(T)And Not PExecu Then Begin
  PExecu:=True;
  PExec:=BY-1;
 End;
 Case T of
  T_PRAM:PParam;
  T_TYPE:PType;
  T_DIM:PDim;
  T_DATA:PData;
  T_STOP,T_PAUS,T_PRNT,T_WRIT,T_END:PPrint;
  T_BYE,T_TRON,T_TROF,T_DEG,T_RAD,T_RETN,T_BAS0,T_BAS1:PNull;
  T_LET:PLet;
  T_CXAS:PAssgn;
  T_POKE:PPoke;
  T_IF:PIf;
  T_ELSE:PElse;
  T_EIF:PEif;
  T_FOR:PFor;
  T_NEXT:PNext;
  T_WHIL:PWhile;
  T_EWHL:PEwhl;
  T_REPT:PRept;
  T_UNTL:PUntil;
  T_LOOP:PLoop;
  T_ELOP:PELoop;
  T_EXIF:PExif;
  T_EEXT:PEExt;
  T_ON:POn;
  T_EROR:PErrorSt;
  T_GOTO,T_GOSB:PGotoSt;
  T_RUN:PRun;
  T_KILL,T_CHD,T_CHX,T_DELT,T_CHIN,T_SYS,T_GLOB:PSExprSt;
  T_INPT,T_READ:PInput;
  T_CRET,T_OPEN:POpen;
  T_SEEK:PSeek;
  T_GET,T_PUT:PGet;
  T_CLOS:PClose;
  T_REST:PRest;
  T_REM1,T_REM2:PRemrk;
  T_LREF:PLRef;
  T_ERRL:PErrLn;
  T_BKSL,T_EOL:PEol;
 Else ComErr;
 End;
End;

{ Verifie les structures non fermees, les lignes non definies et finalise }
Procedure BindDone;
Var I,K:Integer;L,Nx:Word;O:Longint;Def,Sh,Ty:Byte;X:Longint;Dp:Longint;B:Word;
Begin
  { lignes non definies }
 For I:=0 to NLn-1 do Begin
  If Not LnTab[I].Def Then Begin
   L:=LnTab[I].F;
   While L<>0 do Begin
    Nx:=BW(L);
    BPW(L,LnTab[I].Line);
    Dec(BC.D[L-1]);
    BY:=L;
    BError(M_ULN);
    L:=Nx;
   End;
  End;
 End;
  { structures non fermees }
 While NCtl>0 do Begin
  BY:=Ctl[NCtl-1].Ptr;
  BError(M_UCS);
  Dec(NCtl);
 End;
 NexRun:=NexAlc+NexRun;
  { ajustement des symboles }
 O:=0;
 For I:=1 to BS.Cnt do Begin
  GetTyAt(O);
  If DefInt>=S_VAR Then Begin
   If DefInt=S_PROC Then Begin
    SPW(O+1,SW(O+1)+NexAlc);
   End
   Else If DefInt=S_PARM Then Begin
    If(Shape<>0)or(TypeV>=S_STR)Then X:=SW(O+1)Else X:=-1;
    If X>=0 Then DPW(X,DW(X)+NexRun)
    Else SPW(O+1,SW(O+1)+NexRun);
   End;
  End;
  If(TypeV=S_RCRD)and(DefInt<>S_TYPD)and(DefInt<>S_UNDF)Then Begin
   Dp:=SW(O+1);
   If Shape=0 Then K:=2 Else K:=(Shape shr 2)+4;
   B:=DW(Dp+K);
   If B<>$FFFF Then DPW(Dp+K,DW(B));
  End;
  O:=SymNameEnd(BS,O);
 End;
End;

Procedure ResetSyms(Var S:TSymTab);
Var I:Integer;O:Longint;
Begin
 O:=0;
 For I:=1 to S.Cnt do Begin
  If S.B.D[SymNameEnd(S,O)-1]=(Ord('$')or $80)Then S.B.D[O]:=S_STR Else S.B.D[O]:=S_REAL;
  S.B.D[O+1]:=0;S.B.D[O+2]:=0;
  O:=SymNameEnd(S,O);
 End;
End;

{ Lie la procedure Src/Sym dans la structure Bnd.
  Smash=True : mode PACK (supprime lignes inutiles, commentaires, numeros de ligne). }
Procedure BindProc(Pr:PProc;Smash:Boolean;Print:Boolean;Var Res:TBound);
Var Start:Longint;T:Byte;I:Integer;Pad:Integer;SrcLS:Array of Longint;NLs,K:Longint;P:Longint;
 Function InDel(T:Byte):Boolean;
 Begin
  InDel:=(T=T_PRAM)or(T=T_TYPE)or(T=T_DIM)or(T=T_TRON)or(T=T_TROF)or(T=T_PAUS)or
         (T=T_REM1)or(T=T_REM2)or(T=T_BKSL)or(T=T_EOL);
 End;
Begin
 InitBindTables;
 BCopy(Pr^.Src,BC);
 SymCopy(Pr^.Sym,BS);
 ResetSyms(BS);
 BClear(BD);
 BSmash:=Smash;
 BPrint:=Print;
 BErrs:=False;
 NexAlc:=U_SIZE;NexPrm:=0;NexRun:=0;
 PExecu:=False;PExec:=0;Dat1st:=0;DatPtr:=-1;
 NLn:=0;NCtl:=0;OTop:=0;PComp:=0;
 DefNas:=0;LastDsc:=$FFFF;DscPtr:=$FFFF;
 BNLines:=0;
 SetLength(BLineMap,0);
 NLs:=0;
 P:=0;
 While P<Pr^.Src.Len do Begin
  SetLength(SrcLS,NLs+1);
  SrcLS[NLs]:=P;
  Inc(NLs);
  P:=NxLine(Pr^.Src,P);
 End;
 SetLength(BLineMap,NLs);
 K:=0;
 For Pad:=1 to 32 do BAdd(BC,0);
 BC.Len:=BC.Len-32;
 BY:=0;
 Try
  While BY<BC.Len do Begin
   Start:=BY;
   If(Not Smash)and(K<NLs)Then Begin
    If Pr^.Src.Len-(BC.Len-Start)=SrcLS[K]Then Begin
     BLineMap[K]:=Start;
     Inc(K);
    End;
   End;
   OTop:=0;
   PStmt;
   If Smash Then Begin
    T:=BC.D[Start];
    If InDel(T)Then Begin
     BDelete(BC,Start,BY-Start);
     BY:=Start;
    End;
   End;
  End;
  BindDone;
 Except
  On E:TJump Do If E.Kind<>JK_BIND Then Raise;
 End;
  { copie dans la structure liee }
 BCopy(BC,Res.Code);
 BCopy(BD,Res.Dsc);
 SymCopy(BS,Res.Sym);
 Res.PrcS:=NexAlc;
 Res.VarC:=NexRun;
 Res.DataOfs:=Dat1st;
 Res.ExecOfs:=PExec;
 If BErrs Then Res.Stat:=1 Else Res.Stat:=0;
 Res.NLines:=NLs;
 SetLength(Res.LineOfs,NLs);
 For I:=0 to NLs-1 do Begin
  If I<K Then Res.LineOfs[I]:=BLineMap[I]Else Res.LineOfs[I]:=BC.Len;
 End;
End;

{ Lie une instruction isolee (mode debogueur) dans le contexte d'une procedure liee }
Function BindStmt(Const Code:TBuf;Const B:TBound;Var Res:TBuf):Boolean;
Var Pad:Integer;
Begin
 InitBindTables;
 BCopy(Code,BC);
 SymCopy(B.Sym,BS);
 BCopy(B.Dsc,BD);
 BSmash:=False;
 BPrint:=True;
 BErrs:=False;
 NexAlc:=B.PrcS;NexPrm:=0;NexRun:=0;
 PExecu:=True;PExec:=0;Dat1st:=0;DatPtr:=-1;
 NLn:=0;NCtl:=0;OTop:=0;PComp:=0;
 DefNas:=0;LastDsc:=$FFFF;DscPtr:=$FFFF;
 For Pad:=1 to 32 do BAdd(BC,0);
 BC.Len:=BC.Len-32;
 BY:=0;
 Try
  While BY<BC.Len do Begin
   OTop:=0;
   PStmt;
  End;
 Except
  On E:TJump Do If E.Kind<>JK_BIND Then Raise;
 End;
 BCopy(BC,Res);
 BindStmt:=Not BErrs;
End;

{ Lie la liste de parametres d'une commande RUN (expressions constantes seulement) }
Procedure BindParams(Var Code:TBuf);
Var Pad:Integer;
Begin
 InitBindTables;
 BCopy(Code,BC);
 SymClear(BS);
 BClear(BD);
 BSmash:=False;
 BPrint:=True;
 BErrs:=False;
 NexAlc:=U_SIZE;NexPrm:=0;NexRun:=0;
 PExecu:=True;PExec:=0;Dat1st:=0;DatPtr:=-1;
 NLn:=0;NCtl:=0;OTop:=0;PComp:=0;
 DefNas:=0;LastDsc:=$FFFF;DscPtr:=$FFFF;
 For Pad:=1 to 32 do BAdd(BC,0);
 BC.Len:=BC.Len-32;
 BY:=0;
 Try
  PRPram;
 Except
  On E:TJump Do If E.Kind<>JK_BIND Then Raise;
 End;
 BCopy(BC,Code);
End;

{ ---------------------------------------------------------------------------- }
{  Module binaire BASIC09 (format PACK) : type/langage $22 (Subroutine+I-code) }
{                                                                              }
{   $00 $87CD   $02 taille   $04 decalage du nom ($19)   $06 type $22          }
{   $07 attributs $81   $08 parite   $09 P.PGMB   $0B P.VARC   $0D P.SYMB      }
{   $0F P.DSCB  $11 P.PRCS   $13 P.DATA   $15 P.EXEC   $17 P.STAT  $18 P.NAMS  }
{   $19 nom (dernier caractere avec bit 7), I-code, zone de description,       }
{   compteur de symboles (2 octets) + octet de saut (3), symboles, CRC-24.     }
{ ---------------------------------------------------------------------------- }

Const
 P_NAME = 25;
 MOD_SYNC = $87CD;
 MOD_TYPE = $22;
 MOD_ATTR = $81;

{ CRC-24 d'OS-9 (polynome $800063, initial $FFFFFF) }
Function Crc24(Const B:TBuf;N:Longint):Longint;
Var Crc:Longint;I,J:Longint;
Begin
 Crc:=$FFFFFF;
 For I:=0 to N-1 do Begin
  Crc:=Crc xor(Longint(B.D[I])shl 16);
  For J:=1 to 8 do Begin
   Crc:=Crc shl 1;
   If(Crc and $1000000)<>0 Then Crc:=Crc xor $800063;
   Crc:=Crc and $FFFFFF;
  End;
 End;
 Crc24:=Crc xor $FFFFFF;
End;

Function IsRefTok(T:Byte):Boolean;
Begin
 IsRefTok:=(T=T_RUN)or((T>=T_VREF)and(T<=T_P3D))or((T>=T_AREF)and(T<=T_AP3D));
End;

{ Construit l'image du module a partir de la procedure Pr }
Function PackProc(Pr:PProc;Var Img:TBuf):Boolean;
Var
 B:TBound;
 Map:Array of Longint;      { ancien decalage -> nouveau }
 Used:Array of Boolean;
 NewSym:TBuf;
 Ip,O,NO:Longint;
 I,K:Integer;
 T:Byte;
 Nm:String;
 Old:Longint;
 NamS:Integer;
 PGMB,DSCB,SYMB,Sz:Longint;
 Crc:Longint;
 X:Byte;
Begin
 PackProc:=False;
 BindProc(Pr,True,False,B);
 If(B.Stat and 1)<>0 Then Exit;
  { symboles references par l'I-code }
 SetLength(Map,B.Sym.B.Len+1);
 SetLength(Used,B.Sym.B.Len+1);
 For I:=0 to B.Sym.B.Len do Begin Map[I]:=-1;Used[I]:=False;End;
 Ip:=0;
 While Ip<B.Code.Len do Begin
  T:=B.Code.D[Ip];
  If IsRefTok(T)Then Begin
   O:=BGetW(B.Code,Ip+1);
   If O<B.Sym.B.Len Then Used[O]:=True;
  End;
  Ip:=NxTok(B.Code,Ip);
 End;
  { nouvelle table des symboles }
 BClear(NewSym);
 O:=0;
 For I:=1 to B.Sym.Cnt do Begin
  NO:=SymNameEnd(B.Sym,O);
  If Used[O]Then Begin
   Map[O]:=NewSym.Len;
   BAdd(NewSym,B.Sym.B.D[O]);
   BAdd(NewSym,B.Sym.B.D[O+1]);
   BAdd(NewSym,B.Sym.B.D[O+2]);
   If B.Sym.B.D[O]=S_PROC Then
    For K:=O+3 to NO-1 do BAdd(NewSym,B.Sym.B.D[K]);
  End;
  O:=NO;
 End;
  { renumerotation des references }
 Ip:=0;
 While Ip<B.Code.Len do Begin
  T:=B.Code.D[Ip];
  If IsRefTok(T)Then Begin
   O:=BGetW(B.Code,Ip+1);
   If(O<B.Sym.B.Len)and(Map[O]>=0)Then BPutW(B.Code,Ip+1,Map[O]);
  End;
  Ip:=NxTok(B.Code,Ip);
 End;
  { en-tete }
 Nm:=Pr^.Name;
 NamS:=Length(Nm);
 PGMB:=P_NAME+NamS;
 DSCB:=PGMB+B.Code.Len;
 SYMB:=DSCB+B.Dsc.Len+3;
 Sz:=SYMB+NewSym.Len+3;
 BClear(Img);
 BAddW(Img,MOD_SYNC);
 BAddW(Img,Sz);
 BAddW(Img,P_NAME);
 BAdd(Img,MOD_TYPE);
 BAdd(Img,MOD_ATTR);
 BAdd(Img,0);                    { parite }
 BAddW(Img,PGMB);
 BAddW(Img,B.VarC);
 BAddW(Img,SYMB);
 BAddW(Img,DSCB);
 BAddW(Img,B.PrcS);
 BAddW(Img,B.DataOfs);
 BAddW(Img,B.ExecOfs);
 BAdd(Img,$80);
 BAdd(Img,NamS);
 For I:=1 to NamS do Begin
  If I=NamS Then BAdd(Img,Ord(Nm[I])or $80)Else BAdd(Img,Ord(Nm[I]));
 End;
 For I:=0 to B.Code.Len-1 do BAdd(Img,B.Code.D[I]);
 For I:=0 to B.Dsc.Len-1 do BAdd(Img,B.Dsc.D[I]);
 BAddW(Img,B.Sym.Cnt);
 BAdd(Img,3);
 For I:=0 to NewSym.Len-1 do BAdd(Img,NewSym.D[I]);
 BAdd(Img,0);BAdd(Img,0);BAdd(Img,0);
  { parite : complement du OU exclusif des 8 premiers octets }
 X:=0;
 For I:=0 to 7 do X:=X xor Img.D[I];
 Img.D[8]:=X xor $FF;
  { CRC }
 Crc:=Crc24(Img,Sz-3);
 Img.D[Sz-3]:=(Crc shr 16)and $FF;
 Img.D[Sz-2]:=(Crc shr 8)and $FF;
 Img.D[Sz-1]:=Crc and $FF;
 PackProc:=True;
End;

{ Verifie un module et en extrait la procedure. Retourne 0 si correct, sinon code d'erreur OS-9 }
Function ModToProc(Const Img:TBuf;Var Pr:PProc):Integer;
Var Sz,PGMB,DSCB,SYMB,NameOfs,I:Longint;X:Byte;Crc:Longint;Nm:String;
Begin
 ModToProc:=E_BMID;
 If Img.Len<27 Then Exit;
 If BGetW(Img,0)<>MOD_SYNC Then Exit;
 Sz:=BGetW(Img,2);
 If Sz>Img.Len Then Exit;
 X:=0;
 For I:=0 to 8 do X:=X xor Img.D[I];
 If X<>$FF Then Exit;
 If(Img.D[6]<>MOD_TYPE)Then Begin ModToProc:=E_BMID;Exit;End;
 Crc:=Crc24(Img,Sz-3);
 If(Img.D[Sz-3]<>((Crc shr 16)and $FF))or(Img.D[Sz-2]<>((Crc shr 8)and $FF))or
   (Img.D[Sz-1]<>(Crc and $FF))Then Begin ModToProc:=E_BMCRC;Exit;End;
 NameOfs:=BGetW(Img,4);
 PGMB:=BGetW(Img,9);
 SYMB:=BGetW(Img,13);
 DSCB:=BGetW(Img,15);
 If(PGMB>DSCB)or(DSCB>SYMB)or(SYMB>Sz)Then Exit;
 Nm:='';
 I:=NameOfs;
 While I<Sz do Begin
  Nm:=Nm+Chr(Img.D[I]and $7F);
  If(Img.D[I]and $80)<>0 Then Break;
  Inc(I);
 End;
 New(Pr);
 FillChar(Pr^,SizeOf(TProc),0);
 Pr^.Name:=Nm;
 Pr^.IsMod:=True;
 Pr^.HasBnd:=True;
 BClear(Pr^.Src);
 SymClear(Pr^.Sym);
 BClear(Pr^.Bnd.Code);BClear(Pr^.Bnd.Dsc);SymClear(Pr^.Bnd.Sym);
 For I:=PGMB to DSCB-1 do BAdd(Pr^.Bnd.Code,Img.D[I]);
 For I:=DSCB to SYMB-4 do BAdd(Pr^.Bnd.Dsc,Img.D[I]);
 For I:=SYMB to Sz-4 do BAdd(Pr^.Bnd.Sym.B,Img.D[I]);
 Pr^.Bnd.Sym.Cnt:=BGetW(Img,SYMB-3);
 Pr^.Bnd.VarC:=BGetW(Img,11);
 Pr^.Bnd.PrcS:=BGetW(Img,17);
 Pr^.Bnd.DataOfs:=BGetW(Img,19);
 Pr^.Bnd.ExecOfs:=BGetW(Img,21);
 Pr^.Bnd.Stat:=Img.D[23];
 Pr^.Bnd.NLines:=0;
 ModToProc:=0;
End;

{ ---------------------------------------------------------------------------- }
{  Conversions et formats (CNVIO)                                              }
{ ---------------------------------------------------------------------------- }

Function Pw10(N:Integer):Extended;
Var R,B:Extended;Neg:Boolean;
Begin
 Neg:=N<0;
 If Neg Then N:=-N;
 R:=1;B:=10;
 While N>0 do Begin
  If(N and 1)<>0 Then R:=R*B;
  B:=B*B;
  N:=N shr 1;
 End;
 If Neg Then Pw10:=1/R Else Pw10:=R;
End;

{ RLASC : 9 chiffres decimaux (0.DDDDDDDDD) et exposant decimal }
Procedure RlAsc(X:Double;Var Dig:String;Var DExp:Integer;Var Neg:Boolean);
Var A,M:Extended;E:Integer;N:Int64;S:String;
Begin
 Neg:=X<0;
 A:=Abs(X);
 If A=0 Then Begin
  Dig:='000000000';
  DExp:=0;
  Exit;
 End;
 E:=Trunc(Ln(A)/Ln(10))+1;
 M:=A/Pw10(E);
 While M>=1 do Begin M:=M/10;Inc(E);End;
 While M<0.1 do Begin M:=M*10;Dec(E);End;
 N:=Round(M*1E9);
 If N>=1000000000 Then Begin N:=N div 10;Inc(E);End;
 Str(N,S);
 While Length(S)<9 do S:='0'+S;
 Dig:=S;
 DExp:=E;
End;

{ Format libre d'un reel (OUTRL) }
Function FmtRealFree(X:Double):String;
Var Dig:String;DExp,Nd,I,Z:Integer;Neg:Boolean;S:String;
 Function ExpStr(E:Integer):String;
 Var T:String;
 Begin
  If E<0 Then Begin T:='-';E:=-E;End Else T:='+';
  If E<10 Then T:=T+'0';
  ExpStr:='E'+T+IStr(E);
 End;
Begin
 RlAsc(X,Dig,DExp,Neg);
 If X=0 Then Begin FmtRealFree:='.0';Exit;End;
 Nd:=9;
 While(Nd>1)and(Dig[Nd]='0')do Dec(Nd);
 S:='';
 If Neg Then S:='-';
 If DExp>0 Then Begin
  If DExp<=9 Then Begin
   S:=S+Copy(Dig,1,DExp)+'.';
   If Nd-DExp>0 Then S:=S+Copy(Dig,DExp+1,Nd-DExp);
   FmtRealFree:=S;
   Exit;
  End;
 End
  Else
 Begin
  Z:=-DExp;
  If(Z<=9)and(Z+Nd<=9)Then Begin
   S:=S+'.';
   For I:=1 to Z do S:=S+'0';
   S:=S+Copy(Dig,1,Nd);
   FmtRealFree:=S;
   Exit;
  End;
 End;
  { format exponentiel }
 S:=S+Dig[1]+'.';
 If Nd>1 Then S:=S+Copy(Dig,2,Nd-1)Else S:=S+'0';
 FmtRealFree:=S+ExpStr(DExp-1);
End;

Function FmtIntFree(V:Longint):String;
Begin
 FmtIntFree:=IStr(V);
End;

Function FmtBoolFree(B:Boolean):String;
Begin
 If B Then FmtBoolFree:='True' Else FmtBoolFree:='False';
End;

{ ---------------------------------------------------------------------------- }
{  Formats fixes de PRINT USING                                                }
{ ---------------------------------------------------------------------------- }

Function Stars(W:Integer):String;
Var S:String;I:Integer;
Begin
 S:='';
 For I:=1 to W do S:=S+'*';
 Stars:=S;
End;

Function Fill(C:Char;N:Integer):String;
Var S:String;I:Integer;
Begin
 S:='';
 For I:=1 to N do S:=S+C;
 Fill:=S;
End;

{ Justification : 0 gauche, 1 droite, -1 centre / zeros }
Function FmtIntFix(V:Longint;W,J:Integer):String;
Var S,Sg:String;Pad:Integer;
Begin
 If V<0 Then Begin Sg:='-';S:=IStr(-V);End
 Else Begin Sg:=' ';S:=IStr(V);End;
 Pad:=W-1-Length(S);
 If Pad<0 Then Begin FmtIntFix:=Stars(W);Exit;End;
 Case J of
  0:FmtIntFix:=Sg+S+Fill(' ',Pad);
  1:FmtIntFix:=Fill(' ',Pad)+Sg+S;
 Else FmtIntFix:=Sg+Fill('0',Pad)+S;
 End;
End;

Function FmtStrFix(Const S:String;W,J:Integer):String;
Var T:String;F,L:Integer;
Begin
 T:=S;
 If Length(T)>W Then T:=Copy(T,1,W);
 F:=W-Length(T);
 Case J of
  0:FmtStrFix:=T+Fill(' ',F);
  1:FmtStrFix:=Fill(' ',F)+T;
 Else Begin
   L:=F div 2;
   If(F and 1)<>0 Then Inc(L,0);
   FmtStrFix:=Fill(' ',F div 2)+T+Fill(' ',F-(F div 2));
  End;
 End;
End;

Function FmtHexFix(Const Bytes:String;W,J:Integer):String;
Var H:String;I:Integer;F,L:Integer;
Begin
 H:='';
 For I:=1 to Length(Bytes)do H:=H+Hex2(Ord(Bytes[I]));
 If Length(H)>W Then H:=Copy(H,Length(H)-W+1,W);
 F:=W-Length(H);
 Case J of
  0:FmtHexFix:=H+Fill(' ',F);
  1:FmtHexFix:=Fill(' ',F)+H;
 Else FmtHexFix:=Fill(' ',F div 2)+H+Fill(' ',F-(F div 2));
 End;
End;

{ R.FMT et E.FMT : formats reels a decimales fixes ou exponentiel }
Function FmtRealFix(X:Double;W,FSiz,J:Integer;Expo:Boolean):String;
Var Dig:String;DExp,ICnt,FCnt,Fl,I,A,SaveExp,K:Integer;Neg:Boolean;Num,Sg,Ex,R:String;
 Procedure Rnd;
 Var A,P,I:Integer;
 Begin
  A:=DExp+FSiz;
  If A=0 Then Begin
   If Dig[1]>='5' Then Begin
    Dig:='1'+Copy(Dig,1,8);
    Inc(DExp);
   End;
  End
   Else
  Begin
   P:=A-1;
   If(P<0)or(P>7)Then Exit;
   If Dig[P+2]<'5' Then Exit;
   I:=P+1;
   While I>=1 do Begin
    If Dig[I]<'9' Then Begin Dig[I]:=Chr(Ord(Dig[I])+1);Break;End;
    Dig[I]:='0';
    Dec(I);
   End;
   If I<1 Then Begin
    Dig:='1'+Copy(Dig,1,8);
    Inc(DExp);
   End;
  End;
 End;
Begin
 RlAsc(X,Dig,DExp,Neg);
 If Neg Then Sg:='-' Else Sg:=' ';
 Ex:='';
 If Expo Then Begin
  If X<>0 Then Begin
   SaveExp:=DExp;
   DExp:=1;
   Rnd;
   If DExp<>1 Then Inc(SaveExp);
   DExp:=SaveExp;
  End;
  ICnt:=1;
  If FSiz>8 Then FCnt:=8 Else FCnt:=FSiz;
  If FSiz+1>9 Then FCnt:=8;
  K:=DExp-1;
  If X=0 Then K:=0;
  If K<0 Then Ex:='E-' Else Ex:='E+';
  If Abs(K)<10 Then Ex:=Ex+'0';
  Ex:=Ex+IStr(Abs(K));
  A:=W-6-FSiz-ICnt;
  If(W-6<0)or(A<0)Then Begin FmtRealFix:=Stars(W);Exit;End;
  Fl:=A;
  Num:=Dig[1]+'.';
  I:=2;
  For K:=1 to FSiz do Begin
   If(I<=9)Then Num:=Num+Dig[I]Else Num:=Num+'0';
   Inc(I);
  End;
  Case J of
   0:R:=Sg+Num+Ex+Fill(' ',Fl);
   1:R:=Fill(' ',Fl)+Sg+Num+Ex;
  Else R:=Fill(' ',Fl)+Sg+Num+Ex;
  End;
  FmtRealFix:=R;
  Exit;
 End;
  { format reel fixe }
 If DExp>9 Then Begin FmtRealFix:=Stars(W);Exit;End;
 If X<>0 Then Rnd;
 If DExp>=0 Then ICnt:=DExp Else ICnt:=0;
 FCnt:=9-ICnt;
 If FCnt<0 Then FCnt:=0;
 If FCnt>FSiz Then FCnt:=FSiz;
 A:=W-2-FSiz-ICnt;
 If(W-2<0)or(A<0)Then Begin FmtRealFix:=Stars(W);Exit;End;
 Fl:=A;
  { corps du nombre }
 Num:=Copy(Dig,1,ICnt)+'.';
 If DExp<0 Then Begin
  K:=-DExp;
  If K>FSiz Then K:=FSiz;
  Num:=Num+Fill('0',K);
  A:=FSiz-K;
  If FCnt>A Then FCnt:=A;
  Num:=Num+Copy(Dig,1,FCnt);
  If A-FCnt>0 Then Num:=Num+Fill('0',A-FCnt);
 End
  Else
 Begin
  Num:=Num+Copy(Dig,ICnt+1,FCnt);
  If FSiz-FCnt>0 Then Num:=Num+Fill('0',FSiz-FCnt);
 End;
 Case J of
  0:R:=Sg+Num+Fill(' ',Fl);
  1:R:=Fill(' ',Fl)+Sg+Num;
 Else R:=Fill(' ',Fl)+Num+Sg;
 End;
 FmtRealFix:=R;
End;

{ ---------------------------------------------------------------------------- }
{  Memoire de travail, chemins d'acces (I/O) et console                        }
{ ---------------------------------------------------------------------------- }

Const
 FILEEOL = {$IFDEF UNIX}#10{$ELSE}#13#10{$ENDIF};
 BADVAL = -1;

Type
 TPath = Record
  Used:Boolean;
  Kind:Byte;                 { 0 fichier, 1 console, 2 repertoire, 3 nul }
  Mode:Byte;
  F:File;
  RB:Array[0..511] of Byte;
  RPos,RLen:Integer;
  Name:String;
  Dir:TBuf;
  DPos:Longint;
 End;

Var
 Mem:Array[0..65535] of Byte;
 Paths:Array[0..MAXPATH] of TPath;
 OsErr:Integer;             { dernier code d'erreur OS-9 }
 ConCol:Integer;            { colonne de la console }

Function MapIoErr(R:Integer):Integer;
Begin
 Case R of
  0:MapIoErr:=0;
  2,3:MapIoErr:=E_PNNF;
  5:MapIoErr:=E_FNA;
  4:MapIoErr:=207;
  100:MapIoErr:=E_EOF;
  101:MapIoErr:=E_FULL;
  150:MapIoErr:=E_WP;
 Else MapIoErr:=E_FNA;
 End;
End;

{ Convertit un chemin OS-9 en chemin DOS }
Function DosPath(Const S:String):String;
Var R:String;I:Integer;P:Integer;
Begin
 R:=S;
 If(Length(R)>=4)and(R[1]='/')Then Begin
  P:=Pos('/',Copy(R,2,Length(R)));
  If P>0 Then Begin
   If NameEq(Copy(R,2,P-1),'dd')or NameEq(Copy(R,2,P-1),'d0')or NameEq(Copy(R,2,P-1),'d1')or
      NameEq(Copy(R,2,P-1),'h0')or NameEq(Copy(R,2,P-1),'h1')Then Delete(R,1,P+1);
  End;
 End;
 {$IFNDEF UNIX}
 For I:=1 to Length(R)do If R[I]='/' Then R[I]:='\';
 {$ENDIF}
 DosPath:=R;
End;

Function FindFreePath:Integer;
Var I:Integer;
Begin
 FindFreePath:=-1;
 For I:=3 to MAXPATH do If Not Paths[I].Used Then Begin FindFreePath:=I;Exit;End;
End;

Procedure InitPaths;
Var I:Integer;
Begin
 For I:=0 to MAXPATH do Begin
  Paths[I].Used:=False;
  Paths[I].RPos:=0;Paths[I].RLen:=0;
  BClear(Paths[I].Dir);
 End;
 For I:=0 to 2 do Begin Paths[I].Used:=True;Paths[I].Kind:=1;End;
End;

{ Ouvre un chemin. Retourne 0 ou un code d'erreur OS-9. }
Function PathOpen(Const Nm:String;Mode:Byte;Creat:Boolean;Var Num:Integer):Integer;
Var N:Integer;P:String;SR:SearchRec;Rec:String;I:Integer;R:Integer;Exists:Boolean;FM:Byte;
Begin
 PathOpen:=0;
 Num:=-1;
 If Nm='' Then Begin PathOpen:=E_BPNAM;Exit;End;
 N:=FindFreePath;
 If N<0 Then Begin PathOpen:=200;Exit;End;
 P:=DosPath(Nm);
 FillChar(Paths[N].F,SizeOf(File),0);
 Paths[N].RPos:=0;Paths[N].RLen:=0;
 Paths[N].Mode:=Mode;
 Paths[N].Name:=Nm;
 BClear(Paths[N].Dir);
 Paths[N].DPos:=0;
 If NameEq(Nm,'/term')or NameEq(Nm,'/t1')or NameEq(Nm,'/w')or NameEq(Nm,'/w1')Then Begin
  Paths[N].Kind:=1;Paths[N].Used:=True;Num:=N;Exit;
 End;
 If NameEq(Nm,'/null')Then Begin
  Paths[N].Kind:=3;Paths[N].Used:=True;Num:=N;Exit;
 End;
 If(Mode and MODE_DIR)<>0 Then Begin
  Paths[N].Kind:=2;
  If P='.' Then P:='';
  If(P<>'')and(P[Length(P)]<>'/')and(P[Length(P)]<>'\')Then P:=P+'/';
  FindFirst(P+'*',AnyFile,SR);
  While DosError=0 do Begin
   If(SR.Name<>'.')Then Begin
    Rec:=SR.Name;
    If Length(Rec)>28 Then Rec:=Copy(Rec,1,28);
    Rec[Length(Rec)]:=Chr(Ord(Rec[Length(Rec)])or $80);
    For I:=1 to Length(Rec)do BAdd(Paths[N].Dir,Ord(Rec[I]));
    For I:=Length(Rec)+1 to 32 do BAdd(Paths[N].Dir,0);
   End;
   FindNext(SR);
  End;
  Paths[N].Used:=True;Num:=N;Exit;
 End;
 Paths[N].Kind:=0;
 Assign(Paths[N].F,P);
 If Creat Then Begin
  FM:=FileMode;
  FileMode:=0;
  Reset(Paths[N].F,1);
  R:=IOResult;
  FileMode:=FM;
  Exists:=R=0;
  If Exists Then Begin
   Close(Paths[N].F);R:=IOResult;
   PathOpen:=E_CEF;Exit;
  End;
  FileMode:=2;
  Rewrite(Paths[N].F,1);
  R:=IOResult;
  FileMode:=FM;
  If R<>0 Then Begin PathOpen:=MapIoErr(R);Exit;End;
 End
  Else
 Begin
  FM:=FileMode;
  Case Mode and 3 of
   1:FileMode:=0;
   2:FileMode:=1;
  Else FileMode:=2;
  End;
  Reset(Paths[N].F,1);
  R:=IOResult;
  If(R<>0)and(FileMode=2)Then Begin
   FileMode:=0;
   Reset(Paths[N].F,1);
   R:=IOResult;
  End;
  FileMode:=FM;
  If R<>0 Then Begin PathOpen:=MapIoErr(R);Exit;End;
 End;
 Paths[N].Used:=True;
 Num:=N;
End;

Procedure PathFlushRd(N:Integer);
Begin
 If Paths[N].Kind<>0 Then Exit;
 If Paths[N].RLen>0 Then Begin
  Seek(Paths[N].F,FilePos(Paths[N].F)-(Paths[N].RLen-Paths[N].RPos));
  IOResult;
 End;
 Paths[N].RPos:=0;Paths[N].RLen:=0;
End;

Function PathClose(N:Integer):Integer;
Begin
 PathClose:=0;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathClose:=E_BPNUM;Exit;End;
 If N<3 Then Begin Paths[N].Used:=N<3;Exit;End;
 If Paths[N].Kind=0 Then Begin
  Close(Paths[N].F);
  IOResult;
 End;
 BClear(Paths[N].Dir);
 Paths[N].Used:=False;
End;

Procedure PathCloseAll;
Var I:Integer;
Begin
 For I:=3 to MAXPATH do If Paths[I].Used Then PathClose(I);
End;

{ Lit un octet ; False si fin de fichier }
Function PathGetByte(N:Integer;Var B:Byte):Boolean;
Var R:Integer;Got:Integer;
Begin
 PathGetByte:=False;
 Case Paths[N].Kind of
  2:Begin
     If Paths[N].DPos<Paths[N].Dir.Len Then Begin
      B:=Paths[N].Dir.D[Paths[N].DPos];
      Inc(Paths[N].DPos);
      PathGetByte:=True;
     End;
    End;
  0:Begin
     If Paths[N].RPos>=Paths[N].RLen Then Begin
      BlockRead(Paths[N].F,Paths[N].RB,512,Got);
      R:=IOResult;
      Paths[N].RPos:=0;
      Paths[N].RLen:=Got;
      If(Got<=0)or(R<>0)Then Begin Paths[N].RLen:=0;Exit;End;
     End;
     B:=Paths[N].RB[Paths[N].RPos];
     Inc(Paths[N].RPos);
     PathGetByte:=True;
    End;
 End;
End;

Function ConReadLine(Var S:String):Boolean;
Begin
 ConReadLine:=False;
 S:='';
 If Eof(Input)Then Exit;
 ReadLn(S);
 ConReadLine:=True;
End;

{ Lit une ligne (terminee par CR, LF ou CRLF). Retourne 0 ou code d'erreur }
Function PathReadLine(N:Integer;Var S:String):Integer;
Var B:Byte;Got:Boolean;Any:Boolean;
Begin
 PathReadLine:=0;
 S:='';
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathReadLine:=E_BPNUM;Exit;End;
 If Paths[N].Kind=1 Then Begin
  If(N=0)or(N=1)or(N=2)Then Begin
   If Not ConReadLine(S)Then PathReadLine:=E_EOF;
   Exit;
  End;
 End;
 If Paths[N].Kind=3 Then Begin PathReadLine:=E_EOF;Exit;End;
 Any:=False;
 While True do Begin
  Got:=PathGetByte(N,B);
  If Not Got Then Begin
   If Not Any Then PathReadLine:=E_EOF;
   Exit;
  End;
  Any:=True;
  If B=13 Then Begin
   If PathGetByte(N,B)Then Begin
    If B<>10 Then Begin
     If Paths[N].Kind=0 Then Dec(Paths[N].RPos)Else Dec(Paths[N].DPos);
    End;
   End;
   Exit;
  End;
  If B=10 Then Exit;
  S:=S+Chr(B);
 End;
End;

Function PathEof(N:Integer):Boolean;
Var B:Byte;
Begin
 PathEof:=True;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Exit;
 Case Paths[N].Kind of
  0:Begin
     If PathGetByte(N,B)Then Begin
      Dec(Paths[N].RPos);
      PathEof:=False;
     End;
    End;
  1:PathEof:=(N=0)and Eof(Input);
  2:PathEof:=Paths[N].DPos>=Paths[N].Dir.Len;
 End;
End;

Procedure ConWrite(Const S:String);
Var I:Integer;C:Char;
Begin
 For I:=1 to Length(S)do Begin
  C:=S[I];
  Case C of
   #13:Begin WriteLn;ConCol:=0;End;
   #12:ClrScr;
  Else Write(C);
  End;
 End;
End;

{ Ecrit une chaine sur un chemin (CR devient la fin de ligne) }
Function PathWriteStr(N:Integer;Const S:String):Integer;
Var I:Integer;T:String;R:Integer;
Begin
 PathWriteStr:=0;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathWriteStr:=E_BPNUM;Exit;End;
 Case Paths[N].Kind of
  1:ConWrite(S);
  3:;
  2:PathWriteStr:=E_BMODE;
  0:Begin
     If(Paths[N].Mode and 2)=0 Then Begin PathWriteStr:=E_BMODE;Exit;End;
     PathFlushRd(N);
     T:='';
     For I:=1 to Length(S)do Begin
      If S[I]=#13 Then T:=T+FILEEOL Else T:=T+S[I];
     End;
     If Length(T)>0 Then BlockWrite(Paths[N].F,T[1],Length(T));
     R:=IOResult;
     If R<>0 Then PathWriteStr:=MapIoErr(R);
    End;
 End;
End;

Function PathReadBytes(N:Integer;Addr,Cnt:Longint):Integer;
Var I:Longint;B:Byte;
Begin
 PathReadBytes:=0;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathReadBytes:=E_BPNUM;Exit;End;
 If Paths[N].Kind=1 Then Begin
  For I:=0 to Cnt-1 do Begin
   If KeyPressed Then B:=Ord(ReadKey)Else B:=0;
   Mem[(Addr+I)and $FFFF]:=B;
  End;
  Exit;
 End;
 For I:=0 to Cnt-1 do Begin
  If Not PathGetByte(N,B)Then Begin
   If I=0 Then PathReadBytes:=E_EOF;
   Exit;
  End;
  Mem[(Addr+I)and $FFFF]:=B;
 End;
End;

Function PathWriteBytes(N:Integer;Addr,Cnt:Longint):Integer;
Var I:Longint;T:String;R:Integer;
Begin
 PathWriteBytes:=0;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathWriteBytes:=E_BPNUM;Exit;End;
 If Paths[N].Kind=1 Then Begin
  T:='';
  For I:=0 to Cnt-1 do T:=T+Chr(Mem[(Addr+I)and $FFFF]);
  ConWrite(T);
  Exit;
 End;
 If Paths[N].Kind<>0 Then Exit;
 If(Paths[N].Mode and 2)=0 Then Begin PathWriteBytes:=E_BMODE;Exit;End;
 PathFlushRd(N);
 For I:=0 to Cnt-1 do Begin
  BlockWrite(Paths[N].F,Mem[(Addr+I)and $FFFF],1);
 End;
 R:=IOResult;
 If R<>0 Then PathWriteBytes:=MapIoErr(R);
End;

Function PathSeek(N:Integer;Pos:Longint):Integer;
Begin
 PathSeek:=0;
 If(N<0)or(N>MAXPATH)or Not Paths[N].Used Then Begin PathSeek:=E_BPNUM;Exit;End;
 If Paths[N].Kind=0 Then Begin
  PathFlushRd(N);
  Seek(Paths[N].F,Pos);
  If IOResult<>0 Then PathSeek:=E_FNA;
 End
  Else
 If Paths[N].Kind=2 Then Paths[N].DPos:=Pos;
End;

Function PathSize(N:Integer):Longint;
Begin
 PathSize:=0;
 If(N>=0)and(N<=MAXPATH)and Paths[N].Used and(Paths[N].Kind=0)Then PathSize:=FileSize(Paths[N].F);
End;

{ ---------------------------------------------------------------------------- }
{  Machine virtuelle (RunB) : interpreteur d'I-code lie                        }
{ ---------------------------------------------------------------------------- }

Type
 TVal = Record
  Typ:Byte;
  I:Longint;
  R:Double;
  S:String;
  A:Longint;
  Z:Longint;
 End;

 PAct = ^TAct;
 TAct = Record
  Prc:PProc;
  U:Longint;               { base du stockage dans Mem }
  Parent:PAct;
  Sub:Array[0..255] of Longint;
  SubN:Integer;
  Base:Integer;            { base des tableaux : 0 ou 1 }
  Deg:Boolean;
  ErrA:Longint;
  ErrS:Boolean;
  Data:Longint;
  Prlm:Longint;
  SaveSP:Longint;
 End;

Const
 MEMLOW = 256;
 SIZETAB:Array[0..4] of Byte=(1,2,5,1,32);

Var
 Act:PAct;
 Cd:Array of Byte;
 CdLen:Longint;
 IP:Longint;
 CurB:^TBound;
 Ops:Array[0..MAXOPS] of TVal;
 Sp:Integer;
 IErr:Integer;
 AbortSet:Boolean;
 RunDone:Boolean;
 MemSP:Longint;
 RTyp:Byte;               { resultat d'une reference d'adresse }
 RAddr,RSize:Longint;
 OBuf:String;             { tampon de sortie (I.IOPT) }
 OCt:Integer;             { I.IOCT }
 CnCh:Integer;            { I.CNCH : chemin courant }
 InPth,OutPth:Integer;
 InBuf:String;            { ligne d'entree }
 InPos:Integer;
 InSep:Byte;
 RndSeed:LongWord;
 RunTrace:Boolean;
 StepCnt:Longint;
 ExitReq:Boolean;
 CurLine:Longint;
 DirectMode:Boolean;
 LastRunErr:Integer;
 TopProc:PProc;
 StepOn:Boolean;
 StepRem:Longint;

Procedure RunAbort(Code:Integer);Forward;
Procedure DebugEnter(Msg:Boolean);Forward;
Function FindProcByName(Const Nm:String):PProc;Forward;
Procedure TraceLine;Forward;
Procedure ShowCurLine(Marker:Char);Forward;
Procedure ByeExit;Forward;

Procedure RunErr(Code:Integer);
Begin
 IErr:=Code;
 Throw(JK_STMT,1);
End;

Function CW(P:Longint):Word;
Begin
 CW:=(Word(Cd[P])shl 8)or Cd[P+1];
End;

Function MW(A:Longint):Word;
Begin
 A:=A and $FFFF;
 MW:=(Word(Mem[A])shl 8)or Mem[(A+1)and $FFFF];
End;

Procedure SetMW(A:Longint;V:Word);
Begin
 A:=A and $FFFF;
 Mem[A]:=V shr 8;
 Mem[(A+1)and $FFFF]:=V and $FF;
End;

Function MR(A:Longint):Double;
Var B:TB5;I:Integer;
Begin
 For I:=0 to 4 do B[I]:=Mem[(A+I)and $FFFF];
 MR:=B5ToReal(B);
End;

Procedure SetMR(A:Longint;X:Double);
Var B:TB5;I:Integer;
Begin
 RealToB5(X,B);
 For I:=0 to 4 do Mem[(A+I)and $FFFF]:=B[I];
End;

Function CdReal(P:Longint):Double;
Var B:TB5;I:Integer;
Begin
 For I:=0 to 4 do B[I]:=Cd[P+I];
 CdReal:=B5ToReal(B);
End;

Function DscW(O:Longint):Word;
Begin
 DscW:=(Word(CurB^.Dsc.D[O])shl 8)or CurB^.Dsc.D[O+1];
End;

Function SymTb(O:Longint):Byte;
Begin
 SymTb:=CurB^.Sym.B.D[O];
End;

Function SymWd(O:Longint):Word;
Begin
 SymWd:=(Word(CurB^.Sym.B.D[O])shl 8)or CurB^.Sym.B.D[O+1];
End;

Function MemAlloc(N:Longint):Longint;
Begin
 If MemSP-N<MEMLOW Then RunErr(M_MFUL);
 MemSP:=MemSP-N;
 MemAlloc:=MemSP;
End;

{ Lit une chaine stockee en memoire (taille maximale Sz) }
Function ReadStr(Addr,Sz:Longint):String;
Var R:String;I:Longint;B:Byte;
Begin
 R:='';
 For I:=0 to Sz-1 do Begin
  B:=Mem[(Addr+I)and $FFFF];
  If(B=V_ESTR)or(B=0)Then Break;
  R:=R+Chr(B);
 End;
 ReadStr:=R;
End;

Procedure WriteStr(Addr,Sz:Longint;Const S:String);
Var I,N:Longint;
Begin
 N:=Length(S);
 If N>Sz Then N:=Sz;
 For I:=0 to N-1 do Mem[(Addr+I)and $FFFF]:=Ord(S[I+1]);
 If N<Sz Then Mem[(Addr+N)and $FFFF]:=V_ESTR;
End;

{ ---------------------------------------------------------------------------- }
{  Pile d'operandes                                                            }
{ ---------------------------------------------------------------------------- }

Procedure PushInt(V:Longint);
Begin
 If Sp>=MAXOPS-2 Then RunErr(M_STOV);
 Ops[Sp].Typ:=S_INT;
 Ops[Sp].I:=SmallInt(Word(V and $FFFF));
 Inc(Sp);
End;

Procedure PushBool(B:Boolean);
Begin
 If Sp>=MAXOPS-2 Then RunErr(M_STOV);
 Ops[Sp].Typ:=S_BOOL;
 If B Then Ops[Sp].I:=V_TRUE Else Ops[Sp].I:=0;
 Inc(Sp);
End;

Function ChkR(X:Double):Double;
Var A:Double;
Begin
 A:=Abs(X);
 If(X<>X)or(A>=1.7014118E38)Then RunErr(M_FPOV);
 If A<2.9387359E-39 Then X:=0;
 ChkR:=QReal(X);
End;

Procedure PushReal(X:Double);
Begin
 If Sp>=MAXOPS-2 Then RunErr(M_STOV);
 Ops[Sp].Typ:=S_REAL;
 Ops[Sp].R:=ChkR(X);
 Inc(Sp);
End;

Procedure PushStr(Const S:String);
Begin
 If Sp>=MAXOPS-2 Then RunErr(M_STOV);
 Ops[Sp].Typ:=S_STR;
 Ops[Sp].S:=S;
 Inc(Sp);
End;

Procedure PushRcd(A,Z:Longint);
Begin
 If Sp>=MAXOPS-2 Then RunErr(M_STOV);
 Ops[Sp].Typ:=S_RCRD;
 Ops[Sp].A:=A;
 Ops[Sp].Z:=Z;
 Inc(Sp);
End;

Function PopVal:Longint;
Begin
 Dec(Sp);
 PopVal:=Ops[Sp].I;
End;

Function PopReal:Double;
Begin
 Dec(Sp);
 PopReal:=Ops[Sp].R;
End;

Function PopStr:String;
Begin
 Dec(Sp);
 PopStr:=Ops[Sp].S;
End;

{ ---------------------------------------------------------------------------- }
{  References de variables (VARREF)                                            }
{ ---------------------------------------------------------------------------- }

Procedure VarRef(Base:Byte;Fld:Boolean);
Var Tok:Byte;Sym,Dp,Offs,Eo,Idx,Pk,Dm,S:Longint;TB,Df,Sh:Byte;NSub,K:Integer;Prm:Boolean;
    D:Longint;RecA:Longint;ElmSz:Longint;Typ:Byte;
Begin
 Tok:=Cd[IP-1];
 NSub:=Tok-Base;
 Sym:=CW(IP);
 Inc(IP,2);
 TB:=SymTb(Sym);
 Df:=TB and S_DEFM;
 Prm:=Df=S_PARM;
 Typ:=TB and S_TYPM;
 Sh:=TB and S_SHPM;
 RSize:=0;
 If Sh=0 Then Begin
  D:=SymWd(Sym+1);
  If Typ>=S_STR Then Begin
   Dp:=D;
   RSize:=DscW(Dp+2);
   D:=DscW(Dp);
  End;
  If Fld Then Begin
   Dec(Sp);
   RecA:=Ops[Sp].A;
   RAddr:=RecA+D;
  End
   Else
  Begin
   RAddr:=Act^.U+D;
   If Prm Then Begin
    Pk:=RAddr;
    If Pk>=Act^.Prlm Then RunErr(M_PRER);
    If Typ>=S_STR Then Begin
     If RSize>MW(Pk+2)Then RSize:=MW(Pk+2);
    End;
    RAddr:=MW(Pk);
   End;
  End;
 End
  Else
 Begin
  Dp:=SymWd(Sym+1);
  Offs:=DscW(Dp);
  If NSub=0 Then Begin
   Typ:=S_RCRD;
   RSize:=DscW(Dp+2);
   Eo:=0;
  End
   Else
  Begin
   Idx:=0;
   For K:=0 to NSub-1 do Begin
    Dec(Sp);
    S:=Ops[Sp].I-Act^.Base;
    Dm:=DscW(Dp+4+2*K);
    If(S<0)or(S>=Dm)Then RunErr(M_SORG);
    If K=0 Then Idx:=S Else Idx:=Idx*Dm+S;
   End;
   Case Typ of
    S_BYTE,S_BOOL:Eo:=Idx;
    S_INT:Eo:=Idx*2;
    S_REAL:Eo:=Idx*5;
   Else Begin
     ElmSz:=DscW(Dp+4+2*NSub);
     RSize:=ElmSz;
     Eo:=Idx*ElmSz;
    End;
   End;
  End;
  If Prm Then Begin
   Pk:=Act^.U+Offs;
   If Pk>=Act^.Prlm Then RunErr(M_PRER);
   If Eo>MW(Pk+2)Then RunErr(M_PRER);
   RAddr:=MW(Pk)+Eo;
  End
   Else
  Begin
   Eo:=Eo+Offs;
   If Fld Then Begin
    Dec(Sp);
    RAddr:=Eo+Ops[Sp].A;
   End
    Else
   RAddr:=Eo+Act^.U;
  End;
 End;
 RTyp:=Typ;
End;

Procedure LoadVar(Typ:Byte;Addr,Sz:Longint);
Begin
 Case Typ of
  S_BYTE:PushInt(Mem[Addr and $FFFF]);
  S_INT:PushInt(SmallInt(MW(Addr)));
  S_REAL:Begin
          If Sp>=MAXOPS-2 Then RunErr(M_STOV);
          Ops[Sp].Typ:=S_REAL;
          Ops[Sp].R:=MR(Addr);
          Inc(Sp);
         End;
  S_BOOL:PushBool(Mem[Addr and $FFFF]<>0);
  S_STR:PushStr(ReadStr(Addr,Sz));
 Else PushRcd(Addr,Sz);
 End;
End;

{ Stocke la valeur du dessus de pile a l'adresse Addr }
Procedure StoreVal(Typ:Byte;Addr,Sz:Longint);
Var I,N:Longint;
Begin
 Dec(Sp);
 Case Typ of
  S_BYTE:Mem[Addr and $FFFF]:=Ops[Sp].I and $FF;
  S_BOOL:Mem[Addr and $FFFF]:=Ops[Sp].I and $FF;
  S_INT:SetMW(Addr,Word(Ops[Sp].I and $FFFF));
  S_REAL:SetMR(Addr,Ops[Sp].R);
  S_STR:WriteStr(Addr,Sz,Ops[Sp].S);
 Else Begin
   N:=Sz;
   If Ops[Sp].Z<N Then N:=Ops[Sp].Z;
   If Addr<Ops[Sp].A Then
    For I:=0 to N-1 do Mem[(Addr+I)and $FFFF]:=Mem[(Ops[Sp].A+I)and $FFFF]
   Else
    For I:=N-1 downto 0 do Mem[(Addr+I)and $FFFF]:=Mem[(Ops[Sp].A+I)and $FFFF];
  End;
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Evaluation d'expressions (EVAL)                                             }
{ ---------------------------------------------------------------------------- }

Function RndNext:Double;
Begin
 RndSeed:=LongWord(Int64(RndSeed)*3141592621+907633385);
 RndNext:=(RndSeed and $FFFFFFFE)/4294967296.0;
End;

Function DivInt(A,B:Longint;Var Rem:Longint):Longint;
Var Neg:Boolean;MA,MB,Q:Longint;
Begin
 If B=0 Then RunErr(M_ZDIV);
 Neg:=(A<0)<>(B<0);
 MA:=Abs(A);MB:=Abs(B);
 Q:=MA div MB;
 Rem:=MA mod MB;
 If Neg Then Begin Q:=-Q;Rem:=-Rem;End;
 DivInt:=Q;
End;

Function ToRad(X:Double):Double;
Begin
 If Act^.Deg Then ToRad:=X*(Pi/180)Else ToRad:=X;
End;

Function FromRad(X:Double):Double;
Begin
 If Act^.Deg Then FromRad:=X*(180/Pi)Else FromRad:=X;
End;

Function StrCmp(Const A,B:String):Integer;
Var I,N:Integer;
Begin
 N:=Length(A);
 If Length(B)<N Then N:=Length(B);
 For I:=1 to N do Begin
  If A[I]<B[I]Then Begin StrCmp:=-1;Exit;End;
  If A[I]>B[I]Then Begin StrCmp:=1;Exit;End;
 End;
 If Length(A)<Length(B)Then StrCmp:=-1
 Else If Length(A)>Length(B)Then StrCmp:=1
 Else StrCmp:=0;
End;

Function DateStr:String;
Var Y,M,D,DW,H,Mi,S,S100:Word;
 Function T2(V:Word):String;
 Begin
  If V<10 Then T2:='0'+IStr(V)Else T2:=IStr(V);
 End;
Begin
 GetDate(Y,M,D,DW);
 GetTime(H,Mi,S,S100);
 DateStr:=T2(Y mod 100)+'/'+T2(M)+'/'+T2(D)+' '+T2(H)+':'+T2(Mi)+':'+T2(S);
End;

Function FixReal(X:Double):Longint;
Var R:Double;
Begin
 If X>=0 Then R:=Int(X+0.5)Else R:=Int(X-0.5);
 If(R>32767)or(R<-32768)Then RunErr(M_ORNG);
 FixReal:=Trunc(R);
End;

Function RealOfVal(Const V:TVal):Double;
Begin
 If V.Typ=S_REAL Then RealOfVal:=V.R Else RealOfVal:=V.I;
End;

Procedure ValFn(Const S:String);
Var P,R:Integer;Typ:Byte;IV:Longint;RV:Double;
Begin
 P:=1;
 R:=CAsNum(S,P,Ord(','),Typ,IV,RV);
 If R<>0 Then RunErr(M_IARG);
 If Typ=S_INT Then RV:=IV;
 While(P<=Length(S))and(S[P]=' ')do Inc(P);
 If(P<=Length(S))and(S[P]<>',')Then RunErr(M_IARG);
 PushReal(RV);
End;

Procedure EvalCont;Forward;

Procedure EvalOne(T:Byte);
Var A,B:Longint;X,Y:Double;S,S2:String;I,N,K:Integer;Cmp:Integer;Rem:Longint;Addr,Sz:Longint;
    Bt:Byte;Neg:Boolean;
Begin
 Case T of
  T_SBYT:Begin
          Addr:=Act^.U+CW(IP);Inc(IP,2);
          PushInt(Mem[Addr and $FFFF]);
         End;
  T_SINT:Begin
          Addr:=Act^.U+CW(IP);Inc(IP,2);
          PushInt(SmallInt(MW(Addr)));
         End;
  T_SRL:Begin
         Addr:=Act^.U+CW(IP);Inc(IP,2);
         If Sp>=MAXOPS-2 Then RunErr(M_STOV);
         Ops[Sp].Typ:=S_REAL;Ops[Sp].R:=MR(Addr);Inc(Sp);
        End;
  T_SBL:Begin
         Addr:=Act^.U+CW(IP);Inc(IP,2);
         PushBool(Mem[Addr and $FFFF]<>0);
        End;
  T_SSTR:Begin
          A:=CW(IP);Inc(IP,2);
          Addr:=Act^.U+DscW(A);
          Sz:=DscW(A+2);
          PushStr(ReadStr(Addr,Sz));
         End;
  T_VREF,T_VR1D,T_VR2D,T_VR3D:Begin
          VarRef(T_VREF,False);
          LoadVar(RTyp,RAddr,RSize);
         End;
  T_PERD,T_P1D,T_P2D,T_P3D:Begin
          VarRef(T_PERD,True);
          LoadVar(RTyp,RAddr,RSize);
         End;
  T_BLIT:Begin PushInt(Cd[IP]);Inc(IP);End;
  T_ILIT,T_HLIT:Begin PushInt(SmallInt(CW(IP)));Inc(IP,2);End;
  T_RLIT:Begin
          If Sp>=MAXOPS-2 Then RunErr(M_STOV);
          Ops[Sp].Typ:=S_REAL;
          Ops[Sp].R:=CdReal(IP);
          Inc(Sp);
          Inc(IP,5);
         End;
  T_SLIT:Begin
          S:='';
          While(IP<CdLen)and(Cd[IP]<>V_ESTR)do Begin S:=S+Chr(Cd[IP]);Inc(IP);End;
          Inc(IP);
          PushStr(S);
         End;
  T_ADDR,T_ADDR+1:Begin
          EvalCont;
          PushInt(RAddr);
          Inc(IP);
         End;
  T_LENG,T_LENG+1:Begin
          EvalCont;
          If RTyp<S_STR Then PushInt(SIZETAB[RTyp])Else PushInt(RSize);
          Inc(IP);
         End;
  T_POS:PushInt(OCt);
  T_ERR:Begin PushInt(IErr);IErr:=0;End;
  T_MOD:Begin
         B:=PopVal;A:=PopVal;
         DivInt(A,B,Rem);
         PushInt(Rem);
        End;
  T_MOD+1:Begin
           Y:=PopReal;X:=PopReal;
           If Y=0 Then RunErr(M_ZDIV);
           PushReal(X-Y*Int(X/Y));
          End;
  T_RND:Begin
         X:=PopReal;
         If X=0 Then PushReal(RndNext)
         Else Begin
          If X<0 Then Begin
           RndSeed:=LongWord(Round(Abs(X)*2147483648.0))and $FFFFFFFE;
           PushReal(RndNext);
          End
           Else
          PushReal(RndNext*X);
         End;
        End;
  T_PI:PushReal(Pi);
  T_SUBS:Begin
          S2:=PopStr;S:=PopStr;
          I:=Pos(S,S2);
          PushInt(I);
         End;
  T_SGN:Begin
         A:=PopVal;
         If A<0 Then PushInt(-1)Else If A>0 Then PushInt(1)Else PushInt(0);
        End;
  T_SGN+1:Begin
           X:=PopReal;
           If X<0 Then PushInt(-1)Else If X>0 Then PushInt(1)Else PushInt(0);
          End;
  T_SIN:Begin X:=PopReal;PushReal(Sin(ToRad(X)));End;
  T_COS:Begin X:=PopReal;PushReal(Cos(ToRad(X)));End;
  T_TAN:Begin
         X:=ToRad(PopReal);
         If Abs(Cos(X))<1E-12 Then PushReal(1.7014E38)Else PushReal(Sin(X)/Cos(X));
        End;
  T_ASN:Begin
         X:=PopReal;
         If Abs(X)>1 Then RunErr(M_IARG);
         If Abs(X)=1 Then PushReal(FromRad(Pi/2*X))
         Else PushReal(FromRad(ArcTan(X/Sqrt(1-X*X))));
        End;
  T_ACS:Begin
         X:=PopReal;
         If Abs(X)>1 Then RunErr(M_IARG);
         If X=0 Then PushReal(FromRad(Pi/2))
         Else Begin
          Y:=ArcTan(Sqrt(1-X*X)/X);
          If X<0 Then Y:=Y+Pi;
          PushReal(FromRad(Y));
         End;
        End;
  T_ATN:Begin X:=PopReal;PushReal(FromRad(ArcTan(X)));End;
  T_EXP:Begin
         X:=PopReal;
         If X>88.7 Then RunErr(M_FPOV);
         If X<-88 Then PushReal(0)Else PushReal(Exp(X));
        End;
  T_ABS:Begin A:=PopVal;PushInt(Abs(A));End;
  T_ABS+1:Begin X:=PopReal;PushReal(Abs(X));End;
  T_LN:Begin
        X:=PopReal;
        If X<=0 Then RunErr(M_IARG);
        PushReal(Ln(X));
       End;
  T_LOG:Begin
         X:=PopReal;
         If X<=0 Then RunErr(M_IARG);
         PushReal(Ln(X)/Ln(10));
        End;
  T_SQR:Begin
         X:=PopReal;
         If X<0 Then RunErr(M_IARG);
         PushReal(Sqrt(X));
        End;
  T_INTF:Begin A:=PopVal;PushReal(A);End;
  T_INTF+1:Begin X:=PopReal;PushReal(Int(X));End;
  T_FIX:Begin A:=PopVal;PushInt(A);End;
  T_FIX+1:Begin X:=PopReal;PushInt(FixReal(X));End;
  T_FLOT:Begin A:=PopVal;PushReal(A);End;
  T_FLOT+1:;
  T_SQ:Begin A:=PopVal;PushInt(A*A);End;
  T_SQ+1:Begin X:=PopReal;PushReal(X*X);End;
  T_PEEK:Begin A:=PopVal;PushInt(Mem[A and $FFFF]);End;
  T_NNOT:Begin A:=PopVal;PushInt(Not A);End;
  T_VAL:Begin S:=PopStr;ValFn(S);End;
  T_LEN:Begin S:=PopStr;PushInt(Length(S));End;
  T_ASC:Begin
         S:=PopStr;
         If S='' Then PushInt(255)Else PushInt(Ord(S[1]));
        End;
  T_NAND:Begin B:=PopVal;A:=PopVal;PushInt(A and B);End;
  T_NOR:Begin B:=PopVal;A:=PopVal;PushInt(A or B);End;
  T_NXOR:Begin B:=PopVal;A:=PopVal;PushInt(A xor B);End;
  T_TRUE:PushBool(True);
  T_FALS:PushBool(False);
  T_EOF:Begin
         A:=PopVal;
         PushBool(PathEof(A));
        End;
  T_TRIM:Begin
          S:=PopStr;
          While(Length(S)>0)and(S[Length(S)]=' ')do Delete(S,Length(S),1);
          PushStr(S);
         End;
  T_MID:Begin
         B:=PopVal;A:=PopVal;S:=PopStr;
         If B<=0 Then PushStr('')
         Else Begin
          If A<1 Then A:=1;
          If A>Length(S)Then PushStr('')Else PushStr(Copy(S,A,B));
         End;
        End;
  T_LEFT:Begin
          A:=PopVal;S:=PopStr;
          If A<=0 Then PushStr('')Else PushStr(Copy(S,1,A));
         End;
  T_RGHT:Begin
          A:=PopVal;S:=PopStr;
          If A<=0 Then PushStr('')
          Else If A>=Length(S)Then PushStr(S)
          Else PushStr(Copy(S,Length(S)-A+1,A));
         End;
  T_CHR:Begin
         A:=PopVal;
         If(A<0)or(A>255)Then RunErr(M_IARG);
         PushStr(Chr(A));
        End;
  T_STRF:Begin A:=PopVal;PushStr(FmtIntFree(A));End;
  T_STRF+1:Begin X:=PopReal;PushStr(FmtRealFree(X));End;
  T_DATE:PushStr(DateStr);
  T_TAB:Begin
         A:=PopVal;
         If A<0 Then RunErr(M_IARG);
         S:='';
         While A>OCt do Begin S:=S+' ';Dec(A);End;
         PushStr(S);
        End;
  T_FIX1:Begin Ops[Sp-1].I:=FixReal(Ops[Sp-1].R);Ops[Sp-1].Typ:=S_INT;End;
  T_FIX2:Begin Ops[Sp-2].I:=FixReal(Ops[Sp-2].R);Ops[Sp-2].Typ:=S_INT;End;
  T_FIX3:Begin Ops[Sp-3].I:=FixReal(Ops[Sp-3].R);Ops[Sp-3].Typ:=S_INT;End;
  T_FLT1:Begin Ops[Sp-1].R:=Ops[Sp-1].I;Ops[Sp-1].Typ:=S_REAL;End;
  T_FLT2:Begin Ops[Sp-2].R:=Ops[Sp-2].I;Ops[Sp-2].Typ:=S_REAL;End;
  T_NOT:Begin
         A:=PopVal;
         PushBool(A=0);
        End;
  T_NEG:Begin A:=PopVal;PushInt(-A);End;
  T_NEG+1:Begin X:=PopReal;PushReal(-X);End;
  T_AND:Begin B:=PopVal;A:=PopVal;PushBool((A<>0)and(B<>0));End;
  T_OR:Begin B:=PopVal;A:=PopVal;PushBool((A<>0)or(B<>0));End;
  T_XOR:Begin B:=PopVal;A:=PopVal;PushBool((A<>0)<>(B<>0));End;
  T_GT..T_LE+2:Begin
          { comparaisons : base GT D3 LT D6 NE D9 EQ DD GE E1 LE E4 }
          Bt:=0;
          If T<T_LT Then Begin Bt:=T-T_GT;N:=1;End
          Else If T<T_NE Then Begin Bt:=T-T_LT;N:=2;End
          Else If T<T_EQ Then Begin Bt:=T-T_NE;N:=3;End
          Else If T<T_GE Then Begin Bt:=T-T_EQ;N:=4;End
          Else If T<T_LE Then Begin Bt:=T-T_GE;N:=5;End
          Else Begin Bt:=T-T_LE;N:=6;End;
          Case Bt of
           0:Begin B:=PopVal;A:=PopVal;Cmp:=0;If A<B Then Cmp:=-1 Else If A>B Then Cmp:=1;End;
           1:Begin Y:=PopReal;X:=PopReal;Cmp:=0;If X<Y Then Cmp:=-1 Else If X>Y Then Cmp:=1;End;
           2:Begin S2:=PopStr;S:=PopStr;Cmp:=StrCmp(S,S2);End;
          Else Begin
            B:=PopVal;A:=PopVal;
            If((A<>0)=(B<>0))Then Cmp:=0 Else Cmp:=1;
           End;
          End;
          Case N of
           1:PushBool(Cmp>0);
           2:PushBool(Cmp<0);
           3:PushBool(Cmp<>0);
           4:PushBool(Cmp=0);
           5:PushBool(Cmp>=0);
          Else PushBool(Cmp<=0);
          End;
         End;
  T_PLUS:Begin B:=PopVal;A:=PopVal;PushInt(A+B);End;
  T_PLUS+1:Begin Y:=PopReal;X:=PopReal;PushReal(X+Y);End;
  T_PLUS+2:Begin S2:=PopStr;S:=PopStr;PushStr(S+S2);End;
  T_MINS:Begin B:=PopVal;A:=PopVal;PushInt(A-B);End;
  T_MINS+1:Begin Y:=PopReal;X:=PopReal;PushReal(X-Y);End;
  T_MUL:Begin B:=PopVal;A:=PopVal;PushInt(A*B);End;
  T_MUL+1:Begin Y:=PopReal;X:=PopReal;PushReal(X*Y);End;
  T_DIV:Begin B:=PopVal;A:=PopVal;PushInt(DivInt(A,B,Rem));End;
  T_DIV+1:Begin
           Y:=PopReal;X:=PopReal;
           If Y=0 Then RunErr(M_ZDIV);
           PushReal(X/Y);
          End;
  T_POWR,T_POWR+1:Begin
           Y:=PopReal;X:=PopReal;
           If X=0 Then PushReal(0)
           Else If Y=0 Then PushReal(1)
           Else Begin
            Neg:=False;
            If X<0 Then Begin
             If Frac(Y)<>0 Then RunErr(M_IARG);
             Neg:=Odd(Round(Y));
             X:=-X;
            End;
            Y:=Y*Ln(X);
            If Y>88.7 Then RunErr(M_FPOV);
            If Y<-88 Then PushReal(0)
            Else If Neg Then PushReal(-Exp(Y))
            Else PushReal(Exp(Y));
           End;
          End;
 Else RunErr(M_UNIM);
 End;
End;

Procedure AddrRef(T:Byte);
Begin
 If T<T_APRD Then VarRef(T_AREF,False)Else VarRef(T_APRD,True);
End;

Procedure EvalCont;
Var T:Byte;
Begin
 While True do Begin
  T:=Cd[IP];
  Inc(IP);
  If T<$80 Then Exit;
  If(T>=T_AREF)and(T<=T_AP3D)Then Begin
   AddrRef(T);
   Exit;
  End;
  EvalOne(T);
 End;
End;

{ Evalue une expression ; retourne le type du resultat }
Function Eval:Byte;
Begin
 Sp:=0;
 EvalCont;
 If Sp>0 Then Eval:=Ops[Sp-1].Typ Else Eval:=RTyp;
End;

{ ---------------------------------------------------------------------------- }
{  Sortie formatee : PRINT, PRINT USING                                        }
{ ---------------------------------------------------------------------------- }

Procedure OutChr(C:Char);
Begin
 OBuf:=OBuf+C;
 Inc(OCt);
End;

Procedure OutStrB(Const S:String);
Var I:Integer;
Begin
 For I:=1 to Length(S)do OutChr(S[I]);
End;

Procedure OutCr;
Begin
 OBuf:=OBuf+#13;
 OCt:=0;
End;

Procedure SkipZone;
Begin
 OutChr(' ');
 While(OCt and $0F)<>1 do OutChr(' ');
End;

Procedure OutLin;
Var R:Integer;
Begin
 If Length(OBuf)>0 Then Begin
  R:=PathWriteStr(CnCh,OBuf);
  OBuf:='';
  If R<>0 Then RunErr(R);
 End;
End;

Procedure PrintItem;
Begin
 Dec(Sp);
 Case Ops[Sp].Typ of
  S_BYTE,S_INT:OutStrB(FmtIntFree(Ops[Sp].I));
  S_REAL:OutStrB(FmtRealFree(Ops[Sp].R));
  S_BOOL:OutStrB(FmtBoolFree(Ops[Sp].I<>0));
  S_STR:OutStrB(Ops[Sp].S);
 Else RunErr(M_TYPM);
 End;
End;

Var
 LastTk:Byte;

Procedure SetChl(Def:Integer);
Var T:Byte;
Begin
 CnCh:=Def;
 LastTk:=0;
 T:=Cd[IP];
 If T=T_CNUM Then Begin
  Inc(IP);
  Eval;
  CnCh:=Ops[Sp-1].I;
  LastTk:=Cd[IP-1];
  If LastTk<>T_COMA Then Dec(IP);
 End;
End;

{ ---------------------------------------------------------------------------- }
{  PRINT USING : analyse de la chaine de format                                }
{ ---------------------------------------------------------------------------- }

Var
 FmtS:String;
 FmtP:Integer;
 FmtRep:Array[0..15] of Record Cnt:Integer;Beg:Integer;End;
 FmtRN:Integer;
 FmtCnt:Integer;          { I.FRCT }
 FmtBeg:Integer;          { I.FRBG }
 FmtFlag:Integer;         { I.FRFL }
 FmtTyp,FmtWth,FmtJst,FmtSiz:Integer;
 FmtRescan:Boolean;

Function FmtCh(P:Integer):Char;
Begin
 If(P>=1)and(P<=Length(FmtS))Then FmtCh:=FmtS[P]Else FmtCh:=#255;
End;

{ FMTNUM : lit jusqu'a 3 chiffres. P est avance. Retourne True si un nombre a ete lu. }
Function FmtNum(Var P:Integer;Var N:Integer):Boolean;
Var C:Char;K:Integer;
Begin
 FmtNum:=False;
 N:=0;
 C:=FmtCh(P);
 If Not(C in['0'..'9'])Then Exit;
 K:=0;
 While(K<3)and(FmtCh(P)in['0'..'9'])do Begin
  N:=N*10+Ord(FmtCh(P))-48;
  Inc(P);Inc(K);
 End;
 If N>255 Then N:=0;
 FmtNum:=True;
End;

Procedure FmtError(Code:Integer);
Begin
 RunErr(Code);
End;

{ FDELIM : delimiteur de specification ; P pointe sur le caractere courant }
Procedure FDelim(Var P:Integer);
Var C:Char;
Begin
 While True do Begin
  C:=FmtCh(P);
  If C=',' Then Begin Inc(P);FmtP:=P;Exit;End;
  If C=#255 Then Begin
   If FmtFlag<>0 Then Begin
    { fin de bloc de repetition implicite }
    Dec(FmtCnt);
    If FmtCnt<>0 Then Begin P:=FmtBeg;FmtP:=P;Exit;End;
    Dec(FmtRN);
    FmtCnt:=FmtRep[FmtRN].Cnt;FmtBeg:=FmtRep[FmtRN].Beg;
    Dec(FmtFlag);
    Continue;
   End;
   P:=1;
   If Not FmtRescan Then FmtError(M_FSYN);
   FmtRescan:=False;
   FmtP:=P;
   Exit;
  End;
  If C=')' Then Begin
   If FmtFlag=0 Then FmtError(M_FSYN);
   Inc(P);
   Dec(FmtCnt);
   If FmtCnt<>0 Then Begin P:=FmtBeg;FmtP:=P;Exit;End;
   Dec(FmtRN);
   FmtCnt:=FmtRep[FmtRN].Cnt;FmtBeg:=FmtRep[FmtRN].Beg;
   Dec(FmtFlag);
   Continue;
  End;
  FmtError(M_FSYN);
 End;
End;

Procedure PrsJst(Var P:Integer);
Begin
 FmtJst:=0;
 Case FmtCh(P)of
  '<':Begin FmtJst:=0;Inc(P);End;
  '>':Begin FmtJst:=1;Inc(P);End;
  '^':Begin FmtJst:=-1;Inc(P);End;
 End;
End;

{ NXTFMT : decode la specification suivante ; execute T, X et litteraux immediatement.
  Au retour FmtTyp contient le type de format de donnee (0 I,1 H,2 R,3 E,4 S,5 B). }
Procedure NxtFmt;
Var P,N,K:Integer;C:Char;Ty:Integer;Got:Boolean;
Begin
 FmtRescan:=True;
 While True do Begin
  P:=FmtP;
  Got:=FmtNum(P,N);
  If Got Then Begin
   If FmtCh(P)<>'(' Then FmtError(M_FRPT);
   If N=0 Then FmtError(M_FRPT);
   If FmtRN>=15 Then FmtError(M_FRPT);
   FmtRep[FmtRN].Cnt:=FmtCnt;FmtRep[FmtRN].Beg:=FmtBeg;
   Inc(FmtRN);
   FmtCnt:=N;
   Inc(FmtFlag);
   Inc(P);
   FmtBeg:=P;
  End;
  C:=UpCh(FmtCh(P));
  Inc(P);
  Ty:=-1;
  Case C of
   'I':Ty:=0;
   'H':Ty:=1;
   'R':Ty:=2;
   'E':Ty:=3;
   'S':Ty:=4;
   'B':Ty:=5;
   'T':Ty:=6;
   'X':Ty:=7;
   '''':Ty:=8;
  Else FmtError(M_FSYN);
  End;
  If Ty=8 Then Begin
   While True do Begin
    C:=FmtCh(P);
    If C=#255 Then FmtError(M_FSYN);
    Inc(P);
    If C='''' Then Break;
    OutChr(C);
   End;
   FDelim(P);
   Continue;
  End;
  If Not FmtNum(P,N)Then N:=1;
  FmtWth:=N;
  If(Ty=6)or(Ty=7)Then Begin
   FDelim(P);
   If Ty=6 Then Begin
    While OCt<FmtWth do OutChr(' ');
   End
    Else
   For K:=1 to FmtWth do OutChr(' ');
   Continue;
  End;
  FmtTyp:=Ty;
  If(Ty=2)or(Ty=3)Then Begin
   If FmtCh(P)<>'.' Then FmtError(M_FSYN);
   Inc(P);
   If Not FmtNum(P,N)Then FmtError(M_FSYN);
   FmtSiz:=N;
  End;
  PrsJst(P);
  FDelim(P);
  FmtRescan:=True;
  Exit;
 End;
End;

Procedure ExcFmt;
Var T:Byte;S:String;X:Double;V:Longint;H:String;I:Integer;Rb:TB5;
Begin
 T:=Eval;
 Case FmtTyp of
  0:Begin
     If T=S_REAL Then V:=FixReal(Ops[Sp-1].R)
     Else If T<S_REAL Then V:=Ops[Sp-1].I
     Else RunErr(M_INTM);
     OutStrB(FmtIntFix(V,FmtWth,FmtJst));
    End;
  1:Begin
     H:='';
     Case T of
      S_STR:H:=Ops[Sp-1].S;
      S_REAL:Begin
              RealToB5(Ops[Sp-1].R,Rb);
              For I:=0 to 4 do H:=H+Chr(Rb[I]);
             End;
      S_INT:Begin
             If(FmtWth<=2)or(((Ops[Sp-1].I shr 8)and $FF)=0)Then H:=Chr(Ops[Sp-1].I and $FF)
             Else H:=Chr((Ops[Sp-1].I shr 8)and $FF)+Chr(Ops[Sp-1].I and $FF);
            End;
     Else H:=Chr(Ops[Sp-1].I and $FF);
     End;
     OutStrB(FmtHexFix(H,FmtWth,FmtJst));
    End;
  2,3:Begin
       If T=S_REAL Then X:=Ops[Sp-1].R
       Else If T<S_REAL Then X:=Ops[Sp-1].I
       Else RunErr(M_INTM);
       OutStrB(FmtRealFix(X,FmtWth,FmtSiz,FmtJst,FmtTyp=3));
      End;
  4:Begin
     If T<>S_STR Then RunErr(M_INTM);
     OutStrB(FmtStrFix(Ops[Sp-1].S,FmtWth,FmtJst));
    End;
 Else Begin
   If T<>S_BOOL Then RunErr(M_INTM);
   OutStrB(FmtStrFix(FmtBoolFree(Ops[Sp-1].I<>0),FmtWth,FmtJst));
  End;
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Instructions d'entree/sortie                                                }
{ ---------------------------------------------------------------------------- }

Function EolTk(B:Byte):Boolean;
Begin
 EolTk:=(B=T_EOL)or(B=T_BKSL);
End;

Procedure StPrint;
Var B:Byte;T:Byte;Eol:Boolean;
Begin
 SetChl(OutPth);
 OBuf:='';
 B:=Cd[IP];Inc(IP);
 If B=T_USNG Then Begin
  Eval;
  FmtS:=Ops[Sp-1].S;
  FmtP:=1;FmtRN:=0;FmtCnt:=0;FmtBeg:=1;FmtFlag:=0;
  Repeat
   B:=Cd[IP-1];
   If EolTk(B)Then Begin
    OutCr;
    OutLin;
    Exit;
   End;
   B:=Cd[IP];Inc(IP);
   If EolTk(B)Then Begin
    OutLin;
    Exit;
   End;
   Dec(IP);
   NxtFmt;
   ExcFmt;
  Until False;
 End;
 While True do Begin
  If EolTk(B)Then Begin
   OutCr;
   OutLin;
   Exit;
  End;
  If B=T_COMA Then Begin
   SkipZone;
   B:=Cd[IP];Inc(IP);
   If EolTk(B)Then Begin OutLin;Exit;End;
   Continue;
  End;
  If B=T_SCOL Then Begin
   B:=Cd[IP];Inc(IP);
   If EolTk(B)Then Begin OutLin;Exit;End;
   Continue;
  End;
  Dec(IP);
  Eval;
  PrintItem;
  B:=Cd[IP-1];
 End;
End;

Procedure StWrite;
Var B:Byte;
Begin
 SetChl(OutPth);
 OBuf:='';
 B:=Cd[IP];Inc(IP);
 If EolTk(B)Then Begin OutCr;OutLin;Exit;End;
 If B<>T_COMA Then Dec(IP);
 Repeat
  Eval;
  PrintItem;
  B:=Cd[IP-1];
  If EolTk(B)Then Break;
  OutChr(#0);
 Until False;
 OutCr;
 OutLin;
End;

{ Lit une ligne dans le tampon d'entree (V$INLN) }
Procedure InpLin;
Var R:Integer;
Begin
 R:=PathReadLine(CnCh,InBuf);
 If R<>0 Then RunErr(R);
 InPos:=1;
 OCt:=1;
End;

Function InCh(P:Integer):Char;
Begin
 If(P>=1)and(P<=Length(InBuf))Then InCh:=InBuf[P]Else InCh:=#13;
End;

{ SKPDEL : apres une valeur, il faut un delimiteur }
Function SkpDel:Boolean;
Begin
 While InCh(InPos)=' ' do Inc(InPos);
 If Ord(InCh(InPos))=InSep Then Begin Inc(InPos);SkpDel:=True;Exit;End;
 If(InCh(InPos)=#13)Then Begin SkpDel:=True;Exit;End;
 SkpDel:=False;
End;

{ Convertit le champ d'entree selon le type ; retourne un code d'erreur ou 0 }
Function InpConv(Typ:Byte):Integer;
Var R:Integer;T:Byte;IV:Longint;RV:Double;S:String;C:Char;
Begin
 InpConv:=0;
 Case Typ of
  S_STR:Begin
         S:='';
         While True do Begin
          C:=InCh(InPos);
          If C=#13 Then Break;
          Inc(InPos);
          If Ord(C)=InSep Then Break;
          S:=S+C;
         End;
         PushStr(S);
        End;
  S_BOOL:Begin
          While InCh(InPos)=' ' do Inc(InPos);
          C:=InCh(InPos);
          If(Ord(C)=InSep)or(C=#13)Then Begin
           If Ord(C)=InSep Then Inc(InPos);
           PushBool(False);
          End
          Else If(C='T')or(C='t')Then Begin
           PushBool(True);
           While Not((Ord(InCh(InPos))=InSep)or(InCh(InPos)=#13))do Inc(InPos);
           If Ord(InCh(InPos))=InSep Then Inc(InPos);
          End
          Else If(C='F')or(C='f')Then Begin
           PushBool(False);
           While Not((Ord(InCh(InPos))=InSep)or(InCh(InPos)=#13))do Inc(InPos);
           If Ord(InCh(InPos))=InSep Then Inc(InPos);
          End
          Else InpConv:=M_INTM;
         End;
 Else Begin
   R:=CAsNum(InBuf,InPos,InSep,T,IV,RV);
   If R<>0 Then Begin InpConv:=R;Exit;End;
   If Typ=S_REAL Then Begin
    If T=S_INT Then RV:=IV;
    If Not SkpDel Then Begin InpConv:=M_IFMT;Exit;End;
    PushReal(RV);
   End
    Else
   Begin
    If T<>S_INT Then Begin InpConv:=M_INTM;Exit;End;
    If(Typ=S_BYTE)and((IV<0)or(IV>255))Then Begin InpConv:=M_INTM;Exit;End;
    If Not SkpDel Then Begin InpConv:=M_IFMT;Exit;End;
    PushInt(IV);
   End;
  End;
 End;
End;

{ Obtient l'adresse/type d'une variable a affecter (ASGVAR) }
Procedure AsgVar(Var Typ:Byte;Var Addr,Sz:Longint);
Var T:Byte;A:Longint;
Begin
 T:=Cd[IP];Inc(IP);
 If T=T_CXAS Then Begin
  EvalCont;
  Typ:=RTyp;Addr:=RAddr;Sz:=RSize;
  Exit;
 End;
 If T<T_SBYT Then RunErr(M_UNIM);
 A:=T-T_SBYT;
 If A<S_STR Then Begin
  Addr:=Act^.U+CW(IP);Inc(IP,2);
  Typ:=A;Sz:=SIZETAB[A];
 End
  Else
 If A=S_STR Then Begin
  A:=CW(IP);Inc(IP,2);
  Sz:=DscW(A+2);
  Addr:=Act^.U+DscW(A);
  Typ:=S_STR;
 End
  Else
 Begin
  VarRef(T_VREF,False);
  Typ:=RTyp;Addr:=RAddr;Sz:=RSize;
 End;
End;

Procedure StInput;
Var Prompt:String;Start:Longint;B:Byte;Typ:Byte;Addr,Sz:Longint;Ok:Boolean;R:Integer;First:Boolean;
    Explicit:Boolean;
Begin
 SetChl(OutPth);
 Explicit:=CnCh<>OutPth;
 InSep:=Ord(',');
 Start:=IP;
 While True do Begin
  IP:=Start;
  If Cd[IP]=T_SLIT Then Begin
   Eval;
   Prompt:=Ops[Sp-1].S;
  End
   Else
  Prompt:='? ';
  If Not Explicit or(Paths[CnCh].Kind=1)Then PathWriteStr(CnCh,Prompt);
  OBuf:='';
  If Not Explicit Then CnCh:=InPth;
  InpLin;
  Ok:=True;
  First:=True;
  Repeat
   AsgVar(Typ,Addr,Sz);
   R:=InpConv(Typ);
   If R<>0 Then Begin Ok:=False;Break;End;
   StoreVal(Typ,Addr,Sz);
   B:=Cd[IP];Inc(IP);
  Until B<>T_COMA;
  If Ok Then Begin
   If Not Explicit Then CnCh:=OutPth;
   Exit;
  End;
  If Not Explicit Then CnCh:=OutPth;
  PathWriteStr(OutPth,'** Input error - reenter **'+#13);
 End;
End;

Procedure StRead;
Var B:Byte;Typ:Byte;Addr,Sz:Longint;R:Integer;DT:Byte;P:Longint;SaveIP:Longint;T2:Byte;V:Longint;X:Double;
Begin
 B:=Cd[IP];
 If B=T_CNUM Then Begin
  SetChl(InPth);
  InSep:=0;
  If Cd[IP-1]=T_COMA Then Dec(IP);
  InpLin;
  Repeat
   B:=Cd[IP];Inc(IP);
   If B<>T_COMA Then Break;
   AsgVar(Typ,Addr,Sz);
   R:=InpConv(Typ);
   If R<>0 Then RunErr(R);
   StoreVal(Typ,Addr,Sz);
  Until False;
  Exit;
 End;
  { READ depuis les instructions DATA }
 Repeat
  AsgVar(Typ,Addr,Sz);
  If Act^.Data<=0 Then RunErr(M_MDAT);
  SaveIP:=IP;
  IP:=Act^.Data;
  DT:=Eval;
  B:=Cd[IP-1];
  P:=IP;
  If B<>T_COMA Then P:=CW(IP);
  Act^.Data:=P;
  IP:=SaveIP;
  If Typ=S_BYTE Then Typ:=S_INT;
  If Typ=S_BOOL Then Begin
   If DT<>S_BOOL Then RunErr(M_IET);
  End
   Else
  If Typ=S_INT Then Begin
   If DT=S_REAL Then Begin
    Ops[Sp-1].I:=FixReal(Ops[Sp-1].R);Ops[Sp-1].Typ:=S_INT;
   End
   Else If DT<>S_INT Then RunErr(M_IET);
  End
   Else
  If Typ=S_REAL Then Begin
   If DT=S_INT Then Begin Ops[Sp-1].R:=Ops[Sp-1].I;Ops[Sp-1].Typ:=S_REAL;End
   Else If DT<>S_REAL Then RunErr(M_IET);
  End
   Else
  If Typ=S_STR Then Begin
   If DT<>S_STR Then RunErr(M_IET);
  End
   Else RunErr(M_IET);
  StoreVal(Typ,Addr,Sz);
  B:=Cd[IP];Inc(IP);
 Until B<>T_COMA;
End;

Procedure StGetPut(IsPut:Boolean);
Var Typ:Byte;Addr,Sz:Longint;R:Integer;
Begin
 SetChl(InPth);
 AsgVar(Typ,Addr,Sz);
 If IsPut Then R:=PathWriteBytes(CnCh,Addr,Sz)Else R:=PathReadBytes(CnCh,Addr,Sz);
 If R<>0 Then RunErr(R);
End;

Procedure StOpen(Creat:Boolean);
Var Typ:Byte;Addr,Sz:Longint;Nm:String;Mode:Byte;N:Integer;R:Integer;
Begin
 Inc(IP);
 AsgVar(Typ,Addr,Sz);
 Inc(IP);
 Eval;
 Nm:=Ops[Sp-1].S;
 Mode:=MODE_UPDAT;
 If Cd[IP-1]=T_MODE Then Begin
  Mode:=Cd[IP];Inc(IP,2);
 End;
 R:=PathOpen(Nm,Mode,Creat,N);
 If R<>0 Then RunErr(R);
 If Typ=S_INT Then SetMW(Addr,N)Else Mem[Addr and $FFFF]:=N;
End;

Procedure StClose;
Var R:Integer;
Begin
 Repeat
  SetChl(OutPth);
  R:=PathClose(CnCh);
  If R<>0 Then RunErr(R);
 Until LastTk<>T_COMA;
End;

Procedure StSeek;
Var R:Integer;P:Longint;
Begin
 SetChl(OutPth);
 Eval;
 If Ops[Sp-1].Typ=S_REAL Then Begin
  If Ops[Sp-1].R<0 Then P:=0 Else P:=Trunc(Ops[Sp-1].R);
 End
  Else
 P:=Ops[Sp-1].I and $FFFF;
 R:=PathSeek(CnCh,P);
 If R<>0 Then RunErr(R);
End;

{ ---------------------------------------------------------------------------- }
{  Instructions de controle, appels de procedures, boucle d'execution          }
{ ---------------------------------------------------------------------------- }

Var ChainReq:String;

Procedure CallProc(Pr:PProc;PktBase,PktEnd:Longint);Forward;
Function LoadModuleByName(Const Nm:String):PProc;Forward;
Function EnsureBound(P:PProc;Print:Boolean):Boolean;Forward;

Procedure SkipStmt;
Var T:Byte;
Begin
 While IP<CdLen do Begin
  T:=Cd[IP];
  IP:=NxTok(CurB^.Code,IP);
  If EolTk(T)Then Exit;
 End;
End;

Procedure GoTo_;
Begin
 IP:=CW(IP);
End;

Procedure StAssign(Typ:Byte;Addr,Sz:Longint);
Begin
 Eval;
 StoreVal(Typ,Addr,Sz);
End;

{ Affectation complexe : T_CXAS adresse := expression }
Procedure StCxas;
Var Typ:Byte;Addr,Sz:Longint;
Begin
 Sp:=0;
 EvalCont;
 Typ:=RTyp;Addr:=RAddr;Sz:=RSize;
 Inc(IP);
 StAssign(Typ,Addr,Sz);
End;

Procedure StSimpleAssign(T:Byte);
Var A:Longint;Typ:Byte;Sz:Longint;D:Longint;
Begin
 Typ:=T-T_SBYT;
 Case Typ of
  S_STR:Begin
         D:=CW(IP);Inc(IP,3);
         A:=Act^.U+DscW(D);
         Sz:=DscW(D+2);
         StAssign(S_STR,A,Sz);
        End;
  S_BYTE,S_INT,S_REAL,S_BOOL:Begin
         A:=Act^.U+CW(IP);Inc(IP,3);
         StAssign(Typ,A,SIZETAB[Typ]);
        End;
 Else Begin
   VarRef(T_VREF,False);
   Inc(IP);
   StAssign(RTyp,RAddr,RSize);
  End;
 End;
End;

Procedure StIf;
Begin
 Eval;
 If Ops[Sp-1].I=0 Then Begin GoTo_;Exit;End;
 Inc(IP,3);
 If Cd[IP]=T_LRBD Then Begin
  Inc(IP);
  GoTo_;
 End;
End;

Procedure StWhile;
Begin
 Eval;
 If Ops[Sp-1].I=0 Then GoTo_
 Else Inc(IP,3);
End;

Function CntInt(Off:Longint):Longint;
Begin
 CntInt:=SmallInt(MW(Act^.U+Off));
End;

Procedure ForTest(Typ:Byte;Incr:Boolean);
Var Base,CntA,TermA:Longint;SV,CV,TV:Longint;Loop:Boolean;SR,CR,TR:Double;
Begin
 Base:=IP;
 CntA:=Act^.U+CW(Base);
 TermA:=Act^.U+CW(Base+2);
 Loop:=False;
 Case Typ of
  0:Begin
     If Incr Then SetMW(CntA,Word((MW(CntA)+1)and $FFFF));
     Loop:=SmallInt(MW(TermA))>=SmallInt(MW(CntA));
    End;
  1:Begin
     SV:=SmallInt(MW(Act^.U+CW(Base+4)));
     If Incr Then SetMW(CntA,Word((MW(CntA)+SV)and $FFFF));
     CV:=SmallInt(MW(CntA));
     TV:=SmallInt(MW(TermA));
     If SV>=0 Then Loop:=TV>=CV Else Loop:=TV<=CV;
    End;
  2:Begin
     CR:=MR(CntA);
     If Incr Then Begin CR:=ChkR(CR+1);SetMR(CntA,CR);End;
     Loop:=CR<=MR(TermA);
    End;
 Else Begin
   SR:=MR(Act^.U+CW(Base+4));
   CR:=MR(CntA);
   If Incr Then Begin CR:=ChkR(CR+SR);SetMR(CntA,CR);End;
   TR:=MR(TermA);
   If SR>=0 Then Loop:=CR<=TR Else Loop:=CR>=TR;
  End;
 End;
 If Loop Then IP:=CW(Base+6)Else IP:=Base+9;
End;

Procedure StFor;
Var T:Byte;A,Off:Longint;Typ:Byte;
Begin
 T:=Cd[IP];Inc(IP);
 If T=T_SRL Then Begin
  A:=Act^.U+CW(IP);Inc(IP,3);
  Eval;
  SetMR(A,Ops[Sp-1].R);
  Off:=CW(IP);Inc(IP,2);
  Eval;
  SetMR(Act^.U+Off,Ops[Sp-1].R);
  If Cd[IP-1]=T_STEP Then Begin
   Off:=CW(IP);Inc(IP,2);
   Eval;
   SetMR(Act^.U+Off,Ops[Sp-1].R);
  End;
 End
  Else
 Begin
  A:=Act^.U+CW(IP);Inc(IP,3);
  Eval;
  SetMW(A,Word(Ops[Sp-1].I and $FFFF));
  Off:=CW(IP);Inc(IP,2);
  Eval;
  SetMW(Act^.U+Off,Word(Ops[Sp-1].I and $FFFF));
  If Cd[IP-1]=T_STEP Then Begin
   Off:=CW(IP);Inc(IP,2);
   Eval;
   SetMW(Act^.U+Off,Word(Ops[Sp-1].I and $FFFF));
  End;
 End;
 IP:=CW(IP);
 Typ:=Cd[IP];Inc(IP);
 ForTest(Typ,False);
End;

Procedure StNext;
Var Typ:Byte;
Begin
 Typ:=Cd[IP];Inc(IP);
 ForTest(Typ,True);
End;

Procedure StGosub(Dest:Longint);
Begin
 If Act^.SubN>=255 Then RunErr(M_SBOV);
 Act^.Sub[Act^.SubN]:=IP;
 Inc(Act^.SubN);
 IP:=Dest;
End;

Procedure StReturn;
Begin
 If Act^.SubN<=0 Then RunErr(M_SBUN);
 Dec(Act^.SubN);
 IP:=Act^.Sub[Act^.SubN];
End;

Procedure StOn;
Var T:Byte;V,Cnt,Nx,Pos:Longint;
Begin
 T:=Cd[IP];
 If T=T_EROR Then Begin
  If Cd[IP+1]=T_GTBD Then Begin
   Act^.ErrA:=CW(IP+2);
   Act^.ErrS:=True;
   Inc(IP,5);
  End
   Else
  Begin
   Act^.ErrS:=False;
   Inc(IP,2);
  End;
  Exit;
 End;
 Eval;
 V:=Ops[Sp-1].I;
 Cnt:=CW(IP);
 Nx:=IP+2+Cnt*4;
 If(V<=0)or(V>Cnt)Then Begin IP:=Nx;Exit;End;
 Pos:=IP+2+(V-1)*4;
 If Cd[IP+2]=T_GSBD Then Begin
  IP:=Nx;
  StGosub(CW(Pos+1));
 End
  Else
 IP:=CW(Pos+1);
End;

Procedure StPoke;
Var A:Longint;
Begin
 Eval;
 A:=Ops[Sp-1].I;
 Eval;
 Mem[A and $FFFF]:=Ops[Sp-1].I and $FF;
End;

{ Fait une chaine a partir d'une expression de type chaine pour les commandes systeme }
Function EvalStrArg:String;
Begin
 Eval;
 EvalStrArg:=Ops[Sp-1].S;
End;

Procedure StDelete;
Var F:File;S:String;R:Integer;
Begin
 S:=DosPath(EvalStrArg);
 Assign(F,S);
 Erase(F);
 R:=IOResult;
 If R<>0 Then RunErr(MapIoErr(R));
End;

Procedure StChd;
Var S:String;
Begin
 S:=DosPath(EvalStrArg);
 ChDir(S);
 If IOResult<>0 Then RunErr(E_PNNF);
End;

Function ShellCmd(Const Cmd:String):Integer;
Begin
 SwapVectors;
 {$IFDEF UNIX}
 Exec('/bin/sh','-c "'+Cmd+'"');
 {$ELSE}
 Exec(GetEnv('COMSPEC'),'/C '+Cmd);
 {$ENDIF}
 SwapVectors;
 ShellCmd:=DosError;
End;

Procedure StShell;
Var S:String;
Begin
 S:=EvalStrArg;
 ShellCmd(S);
End;

Procedure KillProcName(Const Nm:String;Var Ok:Boolean);Forward;

Procedure StKill;
Var S:String;Ok:Boolean;
Begin
 S:=EvalStrArg;
 KillProcName(S,Ok);
 If Not Ok Then RunErr(M_UPRC);
End;

{ ---------------------------------------------------------------------------- }
{  RUN : appel de procedure avec passage des parametres par paquets            }
{ ---------------------------------------------------------------------------- }

Procedure CallBuiltin(Const Nm:String;PktBase:Longint;Var Done:Boolean);
Var C:Char;S:String;
Begin
 Done:=False;
 If NameEq(Nm,'INKEY')Then Begin
  Done:=True;
  If KeyPressed Then Begin
   C:=ReadKey;
   If C=#0 Then Begin If KeyPressed Then C:=ReadKey;S:=''; End
   Else S:=C;
  End
  Else S:='';
  WriteStr(MW(PktBase),MW(PktBase+2),S);
 End;
End;

{ Lit la liste de parametres d'un appel et construit les paquets (adresse,taille).
  IP pointe sur le jeton suivant le nom de la procedure. }
Procedure ReadParams(Var PktBase,PktEnd:Longint);
Var N,K:Integer;T:Byte;
    Ptr:Array[0..31] of Longint;Siz:Array[0..31] of Longint;A:Longint;
    V:TVal;Sz:Longint;
Begin
 N:=0;
 T:=Cd[IP];Inc(IP);
 If T=T_LPAR Then Begin
  Repeat
   If Cd[IP]=T_CXAS Then Begin
    Inc(IP);
    Sp:=0;
    EvalCont;
    Ptr[N]:=RAddr;Siz[N]:=RSize;
    If RTyp<S_STR Then Siz[N]:=SIZETAB[RTyp];
   End
    Else
   Begin
    Eval;
    Dec(IP);
    V:=Ops[Sp-1];
    Case V.Typ of
     S_REAL:Begin A:=MemAlloc(5);SetMR(A,V.R);Ptr[N]:=A;Siz[N]:=5;End;
     S_STR:Begin
            Sz:=Length(V.S)+1;
            A:=MemAlloc(Sz);
            WriteStr(A,Sz,V.S);
            Ptr[N]:=A;Siz[N]:=Sz;
           End;
     S_BOOL:Begin A:=MemAlloc(1);Mem[A]:=V.I and $FF;Ptr[N]:=A;Siz[N]:=1;End;
     S_RCRD:Begin Ptr[N]:=V.A;Siz[N]:=V.Z;End;
    Else Begin A:=MemAlloc(2);SetMW(A,Word(V.I and $FFFF));Ptr[N]:=A;Siz[N]:=2;End;
    End;
   End;
   Inc(N);
   If N>=31 Then RunErr(M_PRER);
   T:=Cd[IP];Inc(IP);
  Until T<>T_COMA;
  Inc(IP);
 End;
 PktBase:=MemAlloc(N*4);
 PktEnd:=PktBase+N*4;
 For K:=0 to N-1 do Begin
  SetMW(PktBase+K*4,Word(Ptr[K]));
  SetMW(PktBase+K*4+2,Word(Siz[K]));
 End;
End;

Procedure StRun;
Var Sym:Longint;TB,Df:Byte;Nm:String;Pr:PProc;LinkA:Longint;Idx:Integer;
    K:Integer;SaveSP:Longint;PktBase,PktEnd:Longint;Done:Boolean;
Begin
 Sym:=CW(IP);
 TB:=SymTb(Sym);
 Df:=TB and S_DEFM;
 LinkA:=-1;
 If Df=S_PROC Then Begin
  Nm:=SymName(CurB^.Sym,Sym);
  LinkA:=Act^.U+SymWd(Sym+1);
  Inc(IP,2);
 End
  Else
 Begin
  VarRef(T_VREF,False);
  Nm:=ReadStr(RAddr,RSize);
 End;
 Pr:=Nil;
 If LinkA>=0 Then Begin
  Idx:=MW(LinkA);
  If(Idx>=1)and(Idx<=NProcs)Then Pr:=Procs[Idx];
 End;
 If Pr=Nil Then Begin
  Pr:=FindProcByName(Nm);
  If Pr=Nil Then Pr:=LoadModuleByName(Nm);
  If(Pr<>Nil)and(LinkA>=0)Then Begin
   For K:=1 to NProcs do If Procs[K]=Pr Then SetMW(LinkA,K);
  End;
 End;
 If(Pr<>Nil)and Not EnsureBound(Pr,True)Then RunErr(M_ERST);
 SaveSP:=MemSP;
 ReadParams(PktBase,PktEnd);
 If Pr=Nil Then Begin
  CallBuiltin(Nm,PktBase,Done);
  MemSP:=SaveSP;
  If Done Then Exit;
  RunErr(M_UPRC);
 End;
 CallProc(Pr,PktBase,PktEnd);
 MemSP:=SaveSP;
End;

{ ---------------------------------------------------------------------------- }
{  Boucle d'instructions                                                       }
{ ---------------------------------------------------------------------------- }

Procedure StepStmt;
Var T:Byte;GDest:Longint;
Begin
 CurLine:=IP;
 If StepOn Then Begin
  If StepRem<=0 Then Begin
   ShowCurLine('*');
   DebugEnter(False);
   CurLine:=IP;
  End;
  Dec(StepRem);
 End;
 If RunTrace Then TraceLine;
 T:=Cd[IP];
 Inc(IP);
 Case T of
  T_PRAM,T_TYPE,T_DIM,T_DATA,T_GLOB:SkipStmt;
  T_STOP:Begin
          StPrint;
          PathWriteStr(OutPth,'STOP Encountered'+#13);
          RunAbort(0);
         End;
  T_BYE:ByeExit;
  T_TRON:RunTrace:=True;
  T_TROF:RunTrace:=False;
  T_PAUS:Begin
          StPrint;
          DebugEnter(False);
         End;
  T_DEG:Begin Act^.Deg:=True;Inc(IP);End;
  T_RAD:Begin Act^.Deg:=False;Inc(IP);End;
  T_RETN:Begin StReturn;End;
  T_LET:;
  T_CXAS:StCxas;
  T_POKE:StPoke;
  T_IF:StIf;
  T_ELSE:GoTo_;
  T_EIF:Inc(IP);
  T_FOR:StFor;
  T_NEXT:StNext;
  T_WHIL:StWhile;
  T_EWHL:GoTo_;
  T_REPT:;
  T_UNTL:StWhile;
  T_LOOP:;
  T_ELOP:GoTo_;
  T_EXIF:StWhile;
  T_EEXT:GoTo_;
  T_ON:StOn;
  T_EROR:Begin
          Eval;
          RunErr(Ops[Sp-1].I and $FF);
         End;
  T_GOTO,T_GOSB:RunErr(M_ERST);
  T_GTBD:GoTo_;
  T_GSBD:Begin
          GDest:=CW(IP);
          Inc(IP,3);
          StGosub(GDest);
         End;
  T_RUN:StRun;
  T_KILL:StKill;
  T_INPT:StInput;
  T_PRNT:StPrint;
  T_CHD,T_CHX:StChd;
  T_CRET:StOpen(True);
  T_OPEN:StOpen(False);
  T_SEEK:StSeek;
  T_READ:StRead;
  T_WRIT:StWrite;
  T_GET:StGetPut(False);
  T_PUT:StGetPut(True);
  T_CLOS:StClose;
  T_REST:Begin
          If Cd[IP]=T_LRBD Then Begin
           Inc(IP);
           Act^.Data:=CW(IP)+1;
           Inc(IP,3);
          End
           Else
          Begin
           Act^.Data:=CurB^.DataOfs;
           Inc(IP);
          End;
         End;
  T_DELT:StDelete;
  T_CHIN:Begin
          ChainReq:=EvalStrArg;
          ByeExit;
         End;
  T_SYS:StShell;
  T_BAS0:Begin Act^.Base:=0;Inc(IP);End;
  T_BAS1:Begin Act^.Base:=1;Inc(IP);End;
  T_REM1,T_REM2:Inc(IP,Cd[IP]+1);
  T_END:Begin
         If Not EolTk(Cd[IP])Then StPrint;
         RunDone:=True;
        End;
  T_LREF,T_LRBD:Inc(IP,2);
  T_DEXC,T_ERRL:RunErr(M_ERST);
  T_BKSL,T_EOL:;
  T_SBYT..T_SSTR,T_VREF:StSimpleAssign(T);
 Else RunErr(M_UNIM);
 End;
End;

{ Une erreur non interceptee remonte-t-elle vers un appelant qui a un ON ERROR ? }
Function HandlerAbove:Boolean;
Var A:PAct;
Begin
 HandlerAbove:=False;
 A:=Act^.Parent;
 While(A<>Nil)do Begin
  If A^.Prc=TopProc Then Exit;
  If A^.ErrS Then Begin HandlerAbove:=True;Exit;End;
  A:=A^.Parent;
 End;
End;

Procedure ExecBody;
Var Again:Boolean;
Begin
 RunDone:=False;
 Repeat
  Again:=False;
  Try
   While(Not RunDone)and(IP<CdLen)do StepStmt;
   RunDone:=True;
  Except
   On E:TJump Do Begin
    If E.Kind<>JK_STMT Then Raise;
    Sp:=0;
    If Act^.ErrS Then Begin
     IP:=Act^.ErrA;
     Again:=True;
    End
    Else If HandlerAbove Then RunErr(IErr)
    Else RunAbort(IErr);
   End;
  End;
 Until(RunDone)and Not Again;
End;

Procedure CallProc(Pr:PProc;PktBase,PktEnd:Longint);
Var A:PAct;SaveAct:PAct;SaveCd:Array of Byte;SaveLen,SaveIP:Longint;SaveB:^TBound;
    U,SaveSP:Longint;I:Longint;
Begin
 If(Pr^.Bnd.Stat and 1)<>0 Then RunErr(M_ERST);
 SaveSP:=MemSP;
 U:=MemSP-Pr^.Bnd.VarC;
 If U<MEMLOW Then RunErr(M_MFUL);
 For I:=U to MemSP-1 do Mem[I]:=0;
 MemSP:=U;
 New(A);
 A^.Prc:=Pr;
 A^.U:=U;
 A^.Parent:=Act;
 A^.SubN:=0;
 A^.Base:=1;
 A^.Deg:=False;
 A^.ErrA:=0;
 A^.ErrS:=False;
 If Pr^.Bnd.DataOfs<>0 Then A^.Data:=Pr^.Bnd.DataOfs Else A^.Data:=0;
 A^.Prlm:=PktEnd;
 A^.SaveSP:=SaveSP;
 SaveAct:=Act;SaveCd:=Cd;SaveLen:=CdLen;SaveIP:=IP;SaveB:=CurB;
 Act:=A;
 CurB:=@Pr^.Bnd;
 Cd:=CurB^.Code.D;
 CdLen:=CurB^.Code.Len;
 IP:=CurB^.ExecOfs;
 Try
  ExecBody;
 Finally
  RunDone:=False;
  Act:=SaveAct;Cd:=SaveCd;CdLen:=SaveLen;IP:=SaveIP;CurB:=SaveB;
  MemSP:=SaveSP;
  Dispose(A);
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Espace de travail : directory de procedures                                 }
{ ---------------------------------------------------------------------------- }

Type
 TLongArr = Array of Longint;

Var
 Active:PProc;
 WspSize:Longint;
 OutRedir:Boolean;
 OutF:Text;
 BatchMode:Boolean;
 TraceLast:Longint;
 TopAct:PAct;
 TopB:TBound;
 EmptySym:TSymTab;

Procedure ShOut(Const S:String);
Begin
 If OutRedir Then WriteLn(OutF,S)Else WriteLn(S);
End;

Function IdxOfProc(P:PProc):Integer;
Var I:Integer;
Begin
 IdxOfProc:=0;
 For I:=1 to NProcs do If Procs[I]=P Then Begin IdxOfProc:=I;Exit;End;
End;

Function FindProcByName(Const Nm:String):PProc;
Var I:Integer;
Begin
 FindProcByName:=Nil;
 For I:=1 to NProcs do If NameEq(Procs[I]^.Name,Nm)Then Begin FindProcByName:=Procs[I];Exit;End;
End;

Function NewProcRec(Const Nm:String):PProc;
Var P:PProc;
Begin
 New(P);
 FillChar(P^,SizeOf(TProc),0);
 P^.Name:=Nm;
 SymClear(P^.Sym);
 BClear(P^.Src);
 P^.HasBnd:=False;
 P^.IsMod:=False;
 NewProcRec:=P;
End;

Function AddProc(Const Nm:String):PProc;
Var P:PProc;
Begin
 AddProc:=Nil;
 If NProcs>=MAXPROC Then Exit;
 P:=NewProcRec(Nm);
 Inc(NProcs);
 Procs[NProcs]:=P;
 AddProc:=P;
End;

Procedure RemoveProcIdx(I:Integer);
Var K:Integer;P:PProc;
Begin
 P:=Procs[I];
 For K:=I to NProcs-1 do Procs[K]:=Procs[K+1];
 Dec(NProcs);
 If Active=P Then Active:=Nil;
 Dispose(P);
End;

Procedure KillProcName(Const Nm:String;Var Ok:Boolean);
Var I:Integer;
Begin
 Ok:=False;
 If Nm='*' Then Begin
  While NProcs>0 do RemoveProcIdx(NProcs);
  Active:=Nil;
  Ok:=True;
  Exit;
 End;
 For I:=1 to NProcs do If NameEq(Procs[I]^.Name,Nm)Then Begin
  RemoveProcIdx(I);
  Ok:=True;
  Exit;
 End;
End;

Function ReadFileToBuf(Const Fn:String;Var B:TBuf):Boolean;
Var F:File;N,R:Longint;
Begin
 ReadFileToBuf:=False;
 Assign(F,Fn);
 FileMode:=0;
 Reset(F,1);
 If IOResult<>0 Then Exit;
 N:=FileSize(F);
 BClear(B);
 If N>0 Then Begin
  BReserve(B,N);
  BlockRead(F,B.D[0],N,R);
  B.Len:=R;
 End;
 Close(F);
 IOResult;
 ReadFileToBuf:=True;
End;

Function WriteBufToFile(Const Fn:String;Const B:TBuf;Append:Boolean):Boolean;
Var F:File;
Begin
 WriteBufToFile:=False;
 Assign(F,Fn);
 If Append Then Begin
  FileMode:=2;
  Reset(F,1);
  If IOResult<>0 Then Begin Rewrite(F,1);IOResult;End
  Else Seek(F,FileSize(F));
 End
  Else
 Rewrite(F,1);
 If IOResult<>0 Then Exit;
 If B.Len>0 Then BlockWrite(F,B.D[0],B.Len);
 Close(F);
 If IOResult=0 Then WriteBufToFile:=True;
End;

{ Ajoute un module charge a l'espace de travail (remplace l'ancien du meme nom) }
Function AddLoaded(P:PProc):Boolean;
Var Old:PProc;R:Integer;
Begin
 AddLoaded:=False;
 Old:=FindProcByName(P^.Name);
 If Old<>Nil Then Begin
  R:=IdxOfProc(Old);
  Procs[R]:=P;
  If Active=Old Then Active:=P;
  Dispose(Old);
 End
  Else
 Begin
  If NProcs>=MAXPROC Then Begin Dispose(P);Exit;End;
  Inc(NProcs);
  Procs[NProcs]:=P;
 End;
 AddLoaded:=True;
End;

{ Charge tous les modules d'une image (fichier) ; retourne le premier }
Function LoadImage(Const Img:TBuf;Var First:PProc;Quiet:Boolean):Integer;
Var Rest:TBuf;P:PProc;R:Integer;Sz,Pos:Longint;
Begin
 First:=Nil;
 Pos:=0;
 LoadImage:=0;
 While Pos<Img.Len do Begin
  BClear(Rest);
  BReserve(Rest,Img.Len-Pos);
  Move(Img.D[Pos],Rest.D[0],Img.Len-Pos);
  Rest.Len:=Img.Len-Pos;
  R:=ModToProc(Rest,P);
  If R<>0 Then Begin LoadImage:=R;Exit;End;
  Sz:=BGetW(Rest,2);
  If Sz<=0 Then Sz:=Rest.Len;
  If Not AddLoaded(P)Then Begin LoadImage:=M_MFUL;Exit;End;
  If First=Nil Then First:=P;
  If Not Quiet Then ShOut(P^.Name);
  Pos:=Pos+Sz;
 End;
End;

Function LoadModuleByName(Const Nm:String):PProc;
Var Img:TBuf;P:PProc;R,I:Integer;Cand:Array[0..4] of String;Fn:String;
Begin
 LoadModuleByName:=Nil;
 If Nm='' Then Exit;
 Fn:=DosPath(Nm);
 Cand[0]:=Fn;Cand[1]:=Fn+'.mod';Cand[2]:=Fn+'.MOD';
 Cand[3]:=LowerCase(Fn)+'.mod';Cand[4]:=UpStr(Fn)+'.MOD';
 For I:=0 to 4 do Begin
  If ReadFileToBuf(Cand[I],Img)Then Begin
   R:=LoadImage(Img,P,True);
   If R<>0 Then Begin
    If R<>E_BMID Then PrtError(R);
    Continue;
   End;
   LoadModuleByName:=P;
   Exit;
  End;
 End;
End;

{ Lie la procedure si necessaire ; retourne True si aucune erreur }
Function EnsureBound(P:PProc;Print:Boolean):Boolean;
Begin
 If P^.IsMod Then Begin EnsureBound:=True;Exit;End;
 If Not P^.HasBnd Then Begin
  BindProc(P,False,Print,P^.Bnd);
  P^.HasBnd:=True;
 End;
 EnsureBound:=(P^.Bnd.Stat and 1)=0;
End;

Function ProcSize(P:PProc):Longint;
Begin
 EnsureBound(P,False);
 ProcSize:=P_NAME+Length(P^.Name)+P^.Bnd.Code.Len+P^.Bnd.Dsc.Len+3+P^.Bnd.Sym.B.Len+3;
End;

Function FreeSpace:Longint;
Var I:Integer;T:Longint;
Begin
 T:=WspSize-1024;
 For I:=1 to NProcs do T:=T-ProcSize(Procs[I]);
 If T<0 Then T:=0;
 FreeSpace:=T;
End;

{ ---------------------------------------------------------------------------- }
{  Listes de lignes de code source (I-code non lie)                            }
{ ---------------------------------------------------------------------------- }

Procedure LineStarts(P:PProc;Var A:TLongArr;Var N:Longint);
Var Ip:Longint;
Begin
 N:=0;
 SetLength(A,0);
 Ip:=0;
 While Ip<P^.Src.Len do Begin
  SetLength(A,N+1);
  A[N]:=Ip;
  Inc(N);
  Ip:=NxLine(P^.Src,Ip);
 End;
End;

Function IsErrLine(P:PProc;Pos:Longint):Boolean;
Var T:Byte;
Begin
 IsErrLine:=False;
 If Pos>=P^.Src.Len Then Exit;
 T:=P^.Src.D[Pos];
 If T=T_LREF Then Begin
  If Pos+3<P^.Src.Len Then T:=P^.Src.D[Pos+3]Else Exit;
 End;
 IsErrLine:=T=T_ERRL;
End;

Function LineNumOf(P:PProc;Pos:Longint):Longint;
Begin
 LineNumOf:=-1;
 If(Pos<P^.Src.Len)and(P^.Src.D[Pos]=T_LREF)Then LineNumOf:=BGetW(P^.Src,Pos+1);
End;

Function LineText(P:PProc;Pos:Longint;Pretty:Boolean):String;
Var Ip:Longint;
Begin
 Ip:=Pos;
 LineText:=DcLine(P^.Src,Ip,P^.Sym,Pretty);
End;

{ Affiche la ligne de code source en position Pos }
Procedure ShowLine(P:PProc;Pos:Longint;Marker:Char;Ofs:Longint;Pretty:Boolean);
Var S:String;
Begin
 S:=LineText(P,Pos,Pretty);
 If Pretty Then Begin
  If IsErrLine(P,Pos)Then S:=Marker+Hex4(Ofs)+' ERR'+S
  Else S:=Marker+Hex4(Ofs)+' '+S;
 End;
 ShOut(S);
End;

Function LineIdxOfOfs(Const B:TBound;Ofs:Longint):Longint;
Var K:Longint;
Begin
 LineIdxOfOfs:=0;
 For K:=0 to B.NLines-1 do Begin
  If B.LineOfs[K]<=Ofs Then LineIdxOfOfs:=K Else Break;
 End;
End;

{ Liste une procedure liee (commande LIST / SAVE) }
Procedure ListProc(P:PProc;Save:Boolean);
Var Ip:Longint;K:Longint;S:String;I:Integer;
Begin
 ShOut('PROCEDURE '+P^.Name);
 If P^.IsMod Then Exit;
 EnsureBound(P,Not Save);
 DcOcnt:=0;
 Ip:=0;K:=0;
 While Ip<P^.Src.Len do Begin
  S:=LineText(P,Ip,Not Save);
  If Save Then Begin
   For I:=1 to Length(S)do If S[I]=#10 Then S[I]:=' ';
   ShOut(S);
  End
   Else
  Begin
   If IsErrLine(P,Ip)Then S:=' '+Hex4(P^.Bnd.LineOfs[K])+' ERR'+S
   Else S:=' '+Hex4(P^.Bnd.LineOfs[K])+' '+S;
   ShOut(S);
  End;
  Inc(K);
  Ip:=NxLine(P^.Src,Ip);
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Insertion d'une ligne compilee dans une procedure (INSERT)                  }
{ ---------------------------------------------------------------------------- }

Function InsertCode(P:PProc;Const Code:TBuf;Var EPtr:Longint):Boolean;
Var NewNum,Y,Y2,Yn,Del:Longint;SeqErr,Exact:Boolean;I:Longint;Err:Boolean;
 Function NumAt(Pos:Longint):Longint;
 Begin
  If(Pos<P^.Src.Len)and(P^.Src.D[Pos]=T_LREF)Then NumAt:=BGetW(P^.Src,Pos+1)Else NumAt:=-1;
 End;
Begin
 InsertCode:=True;
 NewNum:=-1;
 Del:=0;
 If(Code.Len>0)and(Code.D[0]=T_LREF)Then NewNum:=BGetW(Code,1);
 If EPtr>P^.Src.Len Then EPtr:=P^.Src.Len;
 If NewNum>=0 Then Begin
  Yn:=EPtr;
  While(Yn<P^.Src.Len)and(NumAt(Yn)<0)do Yn:=NxLine(P^.Src,Yn);
  SeqErr:=(Yn<P^.Src.Len)and(NewNum>NumAt(Yn));
  Y2:=0;
  While(Y2<P^.Src.Len)do Begin
   If(NumAt(Y2)>=0)and(NumAt(Y2)>=NewNum)Then Break;
   Y2:=NxLine(P^.Src,Y2);
  End;
  Exact:=(Y2<P^.Src.Len)and(NumAt(Y2)=NewNum);
  If SeqErr or Exact or(Y2<EPtr)Then Begin
   EPtr:=Y2;
   If Exact Then Del:=NxLine(P^.Src,Y2)-Y2;
  End;
 End;
 If Del>0 Then BDelete(P^.Src,EPtr,Del);
 BInsert(P^.Src,EPtr,Code.Len);
 For I:=0 to Code.Len-1 do P^.Src.D[EPtr+I]:=Code.D[I];
 Err:=IsErrLine(P,EPtr);
 If Not Err Then EPtr:=EPtr+Code.Len;
 P^.HasBnd:=False;
 InsertCode:=Not Err;
End;

Procedure InsertSource(P:PProc;Const Line:String;Var EPtr:Longint);
Var Code:TBuf;
Begin
 CompileLine(@P^.Sym,Line,0,False,Code);
 InsertCode(P,Code,EPtr);
End;

{ ---------------------------------------------------------------------------- }
{  Lecture de lignes de commande                                               }
{ ---------------------------------------------------------------------------- }

Function GetLine(Const Prompt:String;Var S:String):Boolean;
Begin
 Write(Prompt);
 GetLine:=ConReadLine(S);
 If Not Eof(Input)Then;
End;

Function SkipBl(Const S:String;I:Integer):Integer;
Begin
 While(I<=Length(S))and(S[I]=' ')do Inc(I);
 SkipBl:=I;
End;

{ Lit un nom (lettres, chiffres, _ . $ -) }
Function ParseName(Const S:String;Var I:Integer;Var Nm:String):Boolean;
Begin
 Nm:='';
 I:=SkipBl(S,I);
 While(I<=Length(S))and(S[I]in['A'..'Z','a'..'z','0'..'9','_','$','.'])do Begin
  Nm:=Nm+S[I];Inc(I);
 End;
 ParseName:=Nm<>'';
End;

Function ConfirmRewrite(Const Fn:String):Boolean;
Var F:File;S:String;
Begin
 ConfirmRewrite:=True;
 FileMode:=0;
 Assign(F,DosPath(Fn));
 Reset(F,1);
 If IOResult=0 Then Begin
  Close(F);IOResult;
  Write('Rewrite?: ');
  If ConReadLine(S)Then Begin
   ConfirmRewrite:=(S<>'')and(UpCh(S[1])='Y');
  End
  Else ConfirmRewrite:=False;
 End;
End;

Procedure OpenRedir(Const Fn:String;Var Ok:Boolean);
Begin
 Ok:=True;
 OutRedir:=False;
 If Fn='' Then Exit;
 If Not ConfirmRewrite(Fn)Then Begin Ok:=False;Exit;End;
 Assign(OutF,DosPath(Fn));
 Rewrite(OutF);
 If IOResult<>0 Then Begin PrtError(E_FNA);Ok:=False;Exit;End;
 OutRedir:=True;
End;

Procedure CloseRedir;
Begin
 If OutRedir Then Begin
  Close(OutF);
  IOResult;
  OutRedir:=False;
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Traces, erreurs d'execution et debogueur                                    }
{ ---------------------------------------------------------------------------- }

Procedure ShowCurLine(Marker:Char);
Var K:Longint;Pos:Longint;A:TLongArr;N:Longint;
Begin
 If Act=Nil Then Exit;
 If Act^.Prc^.IsMod Then Exit;
 If Not Act^.Prc^.HasBnd Then Exit;
 K:=LineIdxOfOfs(Act^.Prc^.Bnd,CurLine);
 LineStarts(Act^.Prc,A,N);
 If K>=N Then Exit;
 DcOcnt:=0;
 ShowLine(Act^.Prc,A[K],Marker,Act^.Prc^.Bnd.LineOfs[K],True);
End;

Procedure TraceLine;
Var K:Longint;
Begin
 If Act^.Prc^.IsMod Then Exit;
 K:=LineIdxOfOfs(Act^.Prc^.Bnd,CurLine);
 If K=TraceLast Then Exit;
 TraceLast:=K;
 ShowCurLine(' ');
End;

Procedure DirectExec(Const Line:String);
Var Code,Out:TBuf;SaveCd:Array of Byte;SaveLen,SaveIP:Longint;SaveDone:Boolean;
    SaveSp:Integer;
Begin
 If Not CompileLine(@CurB^.Sym,Line,1,False,Code)Then Exit;
 If Not BindStmt(Code,CurB^,Out)Then Exit;
 SaveCd:=Cd;SaveLen:=CdLen;SaveIP:=IP;SaveDone:=RunDone;SaveSp:=Sp;
 Try
  Cd:=Out.D;CdLen:=Out.Len;IP:=0;
  RunDone:=False;
  Try
   While(Not RunDone)and(IP<CdLen)do StepStmt;
  Except
   On E:TJump Do Begin
    If E.Kind<>JK_STMT Then Raise;
    PrtError(IErr);
   End;
  End;
 Finally
  Cd:=SaveCd;CdLen:=SaveLen;IP:=SaveIP;RunDone:=SaveDone;Sp:=SaveSp;
 End;
End;

Procedure ShowState;
Var A:PAct;First:Boolean;
Begin
 A:=Act;First:=True;
  While(A<>Nil)and(A^.Prc<>TopProc)do Begin
  If First Then WriteLn('PROCEDURE '+A^.Prc^.Name)Else WriteLn('called by '+A^.Prc^.Name);
  First:=False;
  A:=A^.Parent;
 End;
End;

Procedure DebugEnter(Msg:Boolean);
Var S:String;I:Integer;W:String;Done:Boolean;N:Longint;Code:Integer;
Begin
 If BatchMode Then Exit;
 If Msg Then Begin
  WriteLn('BREAK: PROCEDURE '+Act^.Prc^.Name);
  ShowCurLine('*');
 End;
 Done:=False;
 While Not Done do Begin
  If Not GetLine('D:',S)Then Begin Done:=True;Break;End;
  I:=1;
  If S='' Then Begin
   StepOn:=True;StepRem:=1;
   Done:=True;
  End
   Else
  Begin
   I:=SkipBl(S,I);
   If(I<=Length(S))and(S[I]='$')Then Begin
    ShellCmd(Copy(S,I+1,Length(S)));
    Continue;
   End;
   ParseName(S,I,W);
   W:=UpStr(W);
   If W='CONT' Then Begin StepOn:=False;Done:=True;End
   Else If W='Q' Then Begin
    Throw(JK_ABORT,1);
   End
   Else If W='DIR' Then Begin
    For N:=1 to NProcs do WriteLn(Procs[N]^.Name);
   End
   Else If W='LIST' Then Begin
    ListProc(Act^.Prc,False);
   End
   Else If W='STATE' Then ShowState
   Else If W='STEP' Then Begin
    I:=SkipBl(S,I);
    N:=1;
    If I<=Length(S)Then Val(Copy(S,I,Length(S)),N,Code);
    If N<1 Then N:=1;
    StepOn:=True;StepRem:=N;
    Done:=True;
   End
   Else If(W='PRINT')or(W='LET')or(W='TRON')or(W='TROFF')or(W='DEG')or(W='RAD')Then
    DirectExec(S)
   Else If W='BREAK' Then WriteLn('ok')
   Else WriteLn('What?');
  End;
 End;
End;

Procedure RunAbort(Code:Integer);
Begin
 If Code<>0 Then Begin
  If(Act<>Nil)and Not Act^.Prc^.IsMod Then ShowCurLine('*');
  PrtError(Code);
  If(Act<>Nil)and Not BatchMode and Not Act^.Prc^.IsMod Then DebugEnter(False);
 End;
 LastRunErr:=Code;
 Throw(JK_ABORT,1);
End;

Procedure ByeExit;
Begin
 ExitReq:=True;
 Throw(JK_ABORT,2);
End;

{ ---------------------------------------------------------------------------- }
{  Editeur de procedures (commande EDIT)                                       }
{ ---------------------------------------------------------------------------- }

Function EdCur(P:PProc;Const A:TLongArr;N:Longint):Longint;
Var K:Longint;
Begin
 EdCur:=N;
 For K:=0 to N-1 do If A[K]>=P^.EdtPtr Then Begin EdCur:=K;Exit;End;
End;

Function EdPosOf(P:PProc;Const A:TLongArr;N,K:Longint):Longint;
Begin
 If(K>=N)or(K<0)Then EdPosOf:=P^.Src.Len Else EdPosOf:=A[K];
End;

Procedure EdList(P:PProc;From,Upto:Longint);
Var A:TLongArr;N,Cur,K:Longint;Mk:Char;
Begin
 LineStarts(P,A,N);
 Cur:=EdCur(P,A,N);
 DcOcnt:=0;
 For K:=From to Upto-1 do Begin
  If(K>=N)or(K<0)Then Break;
  If K=Cur Then Mk:='*' Else Mk:=' ';
  ShowLine(P,A[K],Mk,A[K],True);
 End;
 If(Cur>=N)and(Upto>=N)and(From<=N)Then ShOut('*');
End;

Procedure EdMove1(P:PProc);
Var A:TLongArr;N,Cur:Longint;
Begin
 LineStarts(P,A,N);
 Cur:=EdCur(P,A,N);
 P^.EdtPtr:=EdPosOf(P,A,N,Cur);
 EdList(P,Cur,Cur+1);
End;

Procedure What;
Begin
 ShOut('What?');
End;

{ Lit un entier positif non nul ; False si absent ou nul }
Function GetNum(Const S:String;Var I:Integer;Var V:Longint):Boolean;
Begin
 V:=0;
 GetNum:=False;
 I:=SkipBl(S,I);
 If(I>Length(S))or Not(S[I]in['0'..'9'])Then Exit;
 While(I<=Length(S))and(S[I]in['0'..'9'])do Begin
  V:=V*10+Ord(S[I])-48;
  If V>65535 Then Begin V:=0;Exit;End;
  Inc(I);
 End;
 GetNum:=V>0;
End;

{ Cible d'une commande : signe optionnel, nombre de lignes ou * }
Function EdTarget(Const S:String;Var I:Integer;Cur,N:Longint;Var Dest:Longint):Boolean;
Var Fwd:Boolean;Cnt:Longint;
Begin
 EdTarget:=True;
 Fwd:=True;
 If(I<=Length(S))and(S[I]in['+','-'])Then Begin
  Fwd:=S[I]='+';
  Inc(I);
  If(I<=Length(S))and(S[I]='*')Then Begin
   Inc(I);
   If Fwd Then Dest:=N Else Dest:=0;
   Exit;
  End;
 End;
 Cnt:=1;
 If(I<=Length(S))and(S[I]in['0'..'9'])Then Begin
  If Not GetNum(S,I,Cnt)Then Begin EdTarget:=False;Exit;End;
 End;
 If Fwd Then Begin
  Dest:=Cur+Cnt;
  If Dest>N Then Dest:=N;
 End
  Else
 Begin
  Dest:=Cur-Cnt;
  If Dest<0 Then Dest:=0;
 End;
End;

{ Limites d'une commande L ou D : bas (inclus), haut (exclus) }
Function EdLimits(Const S:String;Var I:Integer;Cur,N:Longint;Var Lo,Hi:Longint):Boolean;
Var Dest:Longint;
Begin
 EdLimits:=False;
 I:=SkipBl(S,I);
 If(I<=Length(S))and(S[I]='*')Then Begin
  Inc(I);
  Lo:=0;Hi:=N;
 End
  Else
 Begin
  If Not EdTarget(S,I,Cur,N,Dest)Then Exit;
  If Dest<Cur Then Begin Lo:=Dest;Hi:=Cur;End Else Begin Lo:=Cur;Hi:=Dest;End;
 End;
 I:=SkipBl(S,I);
 If I<=Length(S)Then Exit;
 EdLimits:=True;
End;

Procedure EdDelete(P:PProc;Lo,Hi:Longint);
Var A:TLongArr;N:Longint;B,E:Longint;
Begin
 LineStarts(P,A,N);
 If Hi>N Then Hi:=N;
 If Lo>=Hi Then Exit;
 B:=A[Lo];
 If Hi>=N Then E:=P^.Src.Len Else E:=A[Hi];
 BDelete(P^.Src,B,E-B);
 P^.EdtPtr:=B;
 P^.HasBnd:=False;
End;

{ Numero de la ligne en position Pos (-1 si non numerotee) }
Function EdNumAt(P:PProc;Pos:Longint):Longint;
Begin
 If(Pos<P^.Src.Len)and(P^.Src.D[Pos]=T_LREF)Then EdNumAt:=BGetW(P^.Src,Pos+1)Else EdNumAt:=-1;
End;

Procedure EdSearch(P:PProc;Const S:String;I:Integer;Change:Boolean);
Var Cont:Boolean;Dl:Char;Sch,Chg,Txt,New:String;A:TLongArr;N,K,Cur:Longint;
    Found,Any:Boolean;Last:Longint;Q,Skip:Integer;Code:TBuf;EP:Longint;LPos:Longint;
Begin
 Cont:=False;
 If(I<=Length(S))and(S[I]='*')Then Begin Cont:=True;Inc(I);End;
 I:=SkipBl(S,I);
 If I>Length(S)Then Begin What;Exit;End;
 Dl:=S[I];Inc(I);
 Sch:='';
 While(I<=Length(S))and(S[I]<>Dl)do Begin Sch:=Sch+S[I];Inc(I);End;
 If I<=Length(S)Then Inc(I);
 Chg:='';
 If Change Then Begin
  While(I<=Length(S))and(S[I]<>Dl)do Begin Chg:=Chg+S[I];Inc(I);End;
  If I<=Length(S)Then Inc(I);
 End;
 If(Sch='')or(I<=Length(S))Then Begin What;Exit;End;
 LineStarts(P,A,N);
 Cur:=EdCur(P,A,N);
 K:=Cur;
 Any:=False;
 Last:=EdPosOf(P,A,N,Cur);
 While K<N do Begin
  LPos:=A[K];
  DcOcnt:=0;
  Txt:=LineText(P,LPos,False);
  Skip:=5;
  If Length(Txt)<Skip Then Skip:=Length(Txt);
  Found:=False;
  Q:=Pos(Sch,Copy(Txt,Skip+1,Length(Txt)));
  If Q>0 Then Begin
   Found:=True;Any:=True;
   If Change Then Begin
    New:=Copy(Txt,1,Skip);
    Txt:=Copy(Txt,Skip+1,Length(Txt));
    Repeat
     New:=New+Copy(Txt,1,Q-1)+Chg;
     Txt:=Copy(Txt,Q+Length(Sch),Length(Txt));
     Q:=0;
     If Cont Then Q:=Pos(Sch,Txt);
    Until Q=0;
    New:=New+Txt;
   End
    Else
   New:=Txt;
  End;
  If Found Then Begin
   Last:=LPos;
   If Not Change and Not Cont Then Begin
    P^.EdtPtr:=LPos;
    EdMove1(P);
    Exit;
   End;
   ShOut(New);
   If Change Then Begin
    EP:=LPos;
    EdDelete(P,K,K+1);
    CompileLine(@P^.Sym,New,0,False,Code);
    EP:=P^.EdtPtr;
    InsertCode(P,Code,EP);
    P^.EdtPtr:=EP;
    LineStarts(P,A,N);
    Last:=P^.EdtPtr;
    If Not Cont Then Break;
    { poursuit apres la ligne remplacee }
    K:=EdCur(P,A,N);
    If(K<N)and(A[K]=EP)Then Else Begin
     K:=0;
     While(K<N)and(A[K]<EP)do Inc(K);
    End;
    Continue;
   End;
  End;
  Inc(K);
 End;
 If Not Any Then ShOut('can''t find: "'+Sch+'"');
 LineStarts(P,A,N);
 P^.EdtPtr:=Last;
End;

Procedure EdReseq(P:PProc;Const S:String;I:Integer);
Var A:TLongArr;N,Cur,From,K,First,Inc_,V,Nx:Longint;Whole,Bad:Boolean;
Begin
 First:=100;Inc_:=10;
 LineStarts(P,A,N);
 Cur:=EdCur(P,A,N);
 From:=Cur;
 If(I<=Length(S))and(S[I]='*')Then Begin Whole:=True;From:=0;Inc(I);End;
 I:=SkipBl(S,I);
 If I<=Length(S)Then Begin
  If Not GetNum(S,I,First)Then Begin What;Exit;End;
  I:=SkipBl(S,I);
  If(I<=Length(S))and(S[I]in[',',' '])Then Begin
   Inc(I);
   If Not GetNum(S,I,Inc_)Then Begin What;Exit;End;
  End;
  I:=SkipBl(S,I);
  If I<=Length(S)Then Begin What;Exit;End;
 End;
 Bad:=False;
 { aucune ligne precedente ne doit porter un numero >= au premier }
 For K:=0 to From-1 do If EdNumAt(P,A[K])>=First Then Bad:=True;
 Nx:=First;
 For K:=From to N-1 do If EdNumAt(P,A[K])>=0 Then Begin
  If Nx>32767 Then Bad:=True;
  Nx:=Nx+Inc_;
 End;
 If Bad Then Begin ShOut('RANGE');Exit;End;
 V:=First;
 For K:=From to N-1 do If EdNumAt(P,A[K])>=0 Then Begin
  BPutW(P^.Src,A[K]+1,V);
  V:=V+Inc_;
 End;
 P^.HasBnd:=False;
End;

{ Execute une commande de l'editeur ; retourne False pour quitter }
Function EdCommand(P:PProc;Const S:String):Boolean;
Var A:TLongArr;N,Cur,Lo,Hi,Num:Longint;I:Integer;W:String;C:Char;EP:Longint;Code:TBuf;K:Longint;
Begin
 EdCommand:=True;
 LineStarts(P,A,N);
 Cur:=EdCur(P,A,N);
 If S='' Then C:=#13 Else C:=S[1];
 I:=2;
 Case C of
  #13:Begin
       I:=1;
       If Not EdTarget('',I,Cur,N,Lo)Then Begin What;Exit;End;
       P^.EdtPtr:=EdPosOf(P,A,N,Lo);
       EdMove1(P);
      End;
  '+','-':Begin
           I:=1;
           If Not EdTarget(S,I,Cur,N,Lo)Then Begin What;Exit;End;
           If SkipBl(S,I)<=Length(S)Then Begin What;Exit;End;
           P^.EdtPtr:=EdPosOf(P,A,N,Lo);
           EdMove1(P);
          End;
  'L','l':Begin
           If Not EdLimits(S,I,Cur,N,Lo,Hi)Then Begin What;Exit;End;
           If Lo=0 Then ShOut('PROCEDURE '+P^.Name);
           EdList(P,Lo,Hi);
          End;
  'D','d':Begin
           If Not EdLimits(S,I,Cur,N,Lo,Hi)Then Begin What;Exit;End;
           EdDelete(P,Lo,Hi);
           EdMove1(P);
          End;
  ' ':Begin
      EP:=EdPosOf(P,A,N,Cur);
      CompileLine(@P^.Sym,S,0,False,Code);
      InsertCode(P,Code,EP);
      P^.EdtPtr:=EP;
      EdMove1(P);
     End;
  '0'..'9':Begin
            I:=1;
            If Not GetNum(S,I,Num)Then Begin What;Exit;End;
            If SkipBl(S,I)>Length(S)Then Begin
             K:=0;
             While K<N do Begin
              If EdNumAt(P,A[K])>=Num Then Break;
              Inc(K);
             End;
             P^.EdtPtr:=EdPosOf(P,A,N,K);
             EdMove1(P);
            End
             Else
            Begin
             EP:=EdPosOf(P,A,N,Cur);
             CompileLine(@P^.Sym,S,0,False,Code);
             InsertCode(P,Code,EP);
             P^.EdtPtr:=EP;
             EdMove1(P);
            End;
           End;
 Else
  Begin
   I:=1;
   If Not ParseName(S,I,W)Then Begin What;Exit;End;
   W:=UpStr(W);
   If W='Q' Then Begin
    If SkipBl(S,I)<=Length(S)Then Begin What;Exit;End;
    EdCommand:=False;
   End
   Else If W='S' Then EdSearch(P,S,I,False)
   Else If W='C' Then EdSearch(P,S,I,True)
   Else If W='R' Then EdReseq(P,S,I)
   Else What;
  End;
 End;
End;

Procedure CmdEdit(Const R:String);
Var I:Integer;Nm,S:String;P:PProc;
Begin
 I:=1;
 If Not ParseName(R,I,Nm)Then Begin
  If Active<>Nil Then Nm:=Active^.Name Else Nm:='Program';
 End;
 P:=FindProcByName(Nm);
 If P=Nil Then P:=AddProc(Nm);
 If P=Nil Then Begin PrtError(M_MFUL);Exit;End;
 If P^.IsMod Then Begin What;Exit;End;
 Active:=P;
 P^.HasBnd:=False;
 P^.EdtPtr:=0;
 ShOut('PROCEDURE '+P^.Name);
 EdMove1(P);
 While True do Begin
  If Not GetLine('E:',S)Then Break;
  If Not EdCommand(P,S)Then Break;
 End;
 EnsureBound(P,True);
End;

{ ---------------------------------------------------------------------------- }
{  Execution de haut niveau (commande RUN)                                     }
{ ---------------------------------------------------------------------------- }

Function RunTop(Pr:PProc;Const Args:String):Integer;
Var Code:TBuf;PktBase,PktEnd:Longint;A,B:PAct;Rc:Integer;
Begin
 RunTop:=0;
 If Not EnsureBound(Pr,True)Then Begin PrtError(M_ERST);RunTop:=1;Exit;End;
 If Not CompileRunParams(@EmptySym,Args,False,Code)Then Begin RunTop:=1;Exit;End;
 BindParams(Code);
 LastRunErr:=0;
 StepOn:=False;
 RunTrace:=False;
 MemSP:=65536;
 Sp:=0;
 Rc:=0;
 Try
  TopAct^.U:=MemSP;
  TopAct^.Prlm:=MemSP;
  Act:=TopAct;
  CurB:=@TopProc^.Bnd;
  Cd:=Code.D;CdLen:=Code.Len;IP:=0;
  Try
   ReadParams(PktBase,PktEnd);
   CallProc(Pr,PktBase,PktEnd);
  Except
   On E:TJump Do Begin
    If E.Kind<>JK_STMT Then Raise;
    RunAbort(IErr);
   End;
  End;
 Except
  On E:TJump Do Begin
   If E.Kind<>JK_ABORT Then Raise;
   Rc:=E.Code;
  End;
 End;
 { nettoyage des activations restantes }
 A:=Act;
 While(A<>Nil)and(A<>TopAct)do Begin
  B:=A^.Parent;
  Dispose(A);
  A:=B;
 End;
 Act:=Nil;
 PathCloseAll;
 MemSP:=65536;
 If Rc=2 Then RunTop:=2
 Else If(Rc=1)and(LastRunErr<>0)Then RunTop:=1;
 CloseRedir;
End;

{ ---------------------------------------------------------------------------- }
{  Chargement et sauvegarde de procedures                                      }
{ ---------------------------------------------------------------------------- }

Function TrimS(Const S:String):String;
Var B,E:Integer;
Begin
 B:=1;E:=Length(S);
 While(B<=E)and(S[B]in[' ',#9])do Inc(B);
 While(E>=B)and(S[E]in[' ',#9])do Dec(E);
 TrimS:=Copy(S,B,E-B+1);
End;

Function IsBlankStr(Const S:String):Boolean;
Var I:Integer;
Begin
 IsBlankStr:=False;
 For I:=1 to Length(S)do If Not(S[I]in[' ',#9])Then Exit;
 IsBlankStr:=True;
End;

{ Charge un fichier source (liste de PROCEDURE ...) }
Function LoadSourceBuf(Const B:TBuf):Integer;
Var I,J:Longint;L:String;Cur:PProc;Nm:String;K:Integer;EP:Longint;Ok:Boolean;
Begin
 LoadSourceBuf:=0;
 Cur:=Nil;
 I:=0;
 While I<B.Len do Begin
  L:='';
  While(I<B.Len)and(B.D[I]<>10)and(B.D[I]<>13)do Begin
   If Length(L)<255 Then L:=L+Chr(B.D[I]);
   Inc(I);
  End;
  If(I<B.Len)and(B.D[I]=13)Then Inc(I);
  If(I<B.Len)and(B.D[I]=10)Then Inc(I);
  K:=SkipBl(L,1);
  If(UpStr(Copy(L,K,9))='PROCEDURE')and((Length(L)<K+9)or(L[K+9]in[' ',#9]))Then Begin
   K:=K+9;
   If Not ParseName(L,K,Nm)Then Begin
    LoadSourceBuf:=M_UPRC;
    If Cur<>Nil Then EnsureBound(Cur,True);
    Exit;
   End;
   If Cur<>Nil Then EnsureBound(Cur,True);
   KillProcName(Nm,Ok);
   Cur:=AddProc(Nm);
   If Cur=Nil Then Begin LoadSourceBuf:=M_MFUL;Exit;End;
   Active:=Cur;
   ShOut(Cur^.Name);
  End
  Else If IsBlankStr(L)Then
  Else Begin
   If Cur=Nil Then Begin LoadSourceBuf:=M_UPRC;Exit;End;
   EP:=Cur^.Src.Len;
   InsertSource(Cur,L,EP);
  End;
 End;
 If Cur<>Nil Then EnsureBound(Cur,True);
End;

{ Charge un fichier : module compile ou source }
Function LoadAnyFile(Const Nm:String):Integer;
Var B:TBuf;Fn:String;Cand:Array[0..4] of String;I:Integer;P:PProc;R:Integer;
Begin
 LoadAnyFile:=E_PNNF;
 Fn:=DosPath(Nm);
 Cand[0]:=Fn;Cand[1]:=Fn+'.bas';Cand[2]:=Fn+'.BAS';Cand[3]:=Fn+'.mod';Cand[4]:=Fn+'.MOD';
 For I:=0 to 4 do Begin
  If ReadFileToBuf(Cand[I],B)Then Begin
   If(B.Len>=2)and(B.D[0]=$87)and(B.D[1]=$CD)Then Begin
    R:=LoadImage(B,P,False);
    If(R=0)and(P<>Nil)Then Active:=P;
    LoadAnyFile:=R;
   End
    Else
   LoadAnyFile:=LoadSourceBuf(B);
   Exit;
  End;
 End;
End;

{ Separe une liste de procedures suivie d'un chemin facultatif }
Function ParseProcs(Const S:String;Var L:Array of PProc;Var N:Integer;Var Path:String;PathOk:Boolean):Boolean;
Var I,J:Integer;Nm:String;P:PProc;Stop:Boolean;
Begin
 ParseProcs:=False;
 N:=0;Path:='';
 I:=1;
 I:=SkipBl(S,I);
 If(I<=Length(S))and(S[I]=',')Then I:=SkipBl(S,I+1);
 If(I<=Length(S))and(S[I]='*')Then Begin
  For J:=1 to NProcs do L[J-1]:=Procs[J];
  N:=NProcs;
  Inc(I);
  I:=SkipBl(S,I);
  If(I<=Length(S))and(S[I]=',')Then I:=SkipBl(S,I+1);
 End
  Else
 Begin
  Stop:=False;
  While(I<=Length(S))and Not Stop do Begin
   J:=I;
   If ParseName(S,J,Nm)Then Begin
    P:=FindProcByName(Nm);
    If P<>Nil Then Begin
     L[N]:=P;Inc(N);
     I:=SkipBl(S,J);
     If(I<=Length(S))and(S[I]=',')Then I:=SkipBl(S,I+1);
    End
     Else
    Begin
     If(Not PathOk)and(Pos('.',Nm)=0)Then Begin PrtError(M_UPRC);Exit;End;
     Stop:=True;
    End;
   End
    Else
   Stop:=True;
  End;
 End;
 If N=0 Then Begin
  If Active=Nil Then Begin PrtError(M_UPRC);Exit;End;
  L[0]:=Active;N:=1;
 End;
 Path:=Copy(S,I,Length(S));
 While(Path<>'')and(Path[Length(Path)]in[' ',#9])do Delete(Path,Length(Path),1);
 ParseProcs:=True;
End;

{ ---------------------------------------------------------------------------- }
{  Commandes du niveau B:                                                      }
{ ---------------------------------------------------------------------------- }

Procedure PadTo(Var S:String;Col:Integer);
Begin
 While Length(S)<Col do S:=S+' ';
End;

Procedure CmdDir(Const R:String);
Var Ok:Boolean;I,K:Integer;S:String;P:PProc;Path:String;
Begin
 Path:=TrimS(R);
 OpenRedir(Path,Ok);
 If Not Ok Then Exit;
 ShOut('');
 ShOut('  Name      Proc-Size  Data-Size');
 For K:=1 to NProcs do Begin
  P:=Procs[K];
  EnsureBound(P,False);
  S:='';
  If P^.IsMod Then S:='-' Else S:=' ';
  If P=Active Then S:=S+'*' Else S:=S+' ';
  S:=S+P^.Name+' ';
  PadTo(S,17);
  S:=S+IStr(ProcSize(P));
  PadTo(S,28);
  S:=S+IStr(P^.Bnd.VarC);
  If P^.Bnd.VarC+64>=FreeSpace Then S:=S+'?';
  ShOut(S);
 End;
 ShOut(IStr(FreeSpace)+' free');
 CloseRedir;
End;

Procedure CmdList(Const R:String;Save:Boolean);
Var L:Array[0..MAXPROC] of PProc;N,K:Integer;Path:String;Ok:Boolean;
Begin
 If Not ParseProcs(R,L,N,Path,Save)Then Exit;
 If Save And(Path='')Then Path:=L[0]^.Name+'.bas';
 OpenRedir(Path,Ok);
 If Not Ok Then Exit;
 For K:=0 to N-1 do Begin
  Active:=L[K];
  ListProc(L[K],Save);
 End;
 CloseRedir;
End;

Procedure CmdKill(Const R:String);
Var L:Array[0..MAXPROC] of PProc;N,K:Integer;Path:String;Ok:Boolean;
Begin
 If Not ParseProcs(R,L,N,Path,False)Then Exit;
 For K:=0 to N-1 do KillProcName(L[K]^.Name,Ok);
End;

Procedure CmdPack(Const R:String);
Var L:Array[0..MAXPROC] of PProc;N,K,I:Integer;Path:String;Img,All:TBuf;
Begin
 If Not ParseProcs(R,L,N,Path,True)Then Exit;
 If Path='' Then Path:=L[0]^.Name+'.mod';
 BClear(All);
 For K:=0 to N-1 do Begin
  If L[K]^.IsMod Then Begin PrtError(M_ERST);Exit;End;
  If(Not EnsureBound(L[K],True))Then Begin PrtError(M_ERST);Exit;End;
  If Not PackProc(L[K],Img)Then Begin PrtError(M_ERST);Exit;End;
  For I:=0 to Img.Len-1 do BAdd(All,Img.D[I]);
 End;
 If Not ConfirmRewrite(Path)Then Exit;
 If Not WriteBufToFile(DosPath(Path),All,False)Then PrtError(E_FNA);
End;


{ Affiche la structure binaire d'une procedure (I-code lie, description, symboles) }
Procedure HexDump(Const B:TBuf);
Var I,J:Longint;S,A:String;C:Byte;
Begin
 I:=0;
 While I<B.Len do Begin
  S:=' '+Hex4(I)+' ';
  A:='';
  For J:=0 to 15 do Begin
   If I+J<B.Len Then Begin
    C:=B.D[I+J];
    S:=S+Hex2(C)+' ';
    If(C>=32)and(C<127)Then A:=A+Chr(C)Else A:=A+'.';
   End
    Else S:=S+'   ';
  End;
  ShOut(S+' '+A);
  Inc(I,16);
 End;
End;

Procedure CmdDump(Const R:String);
Var L:Array[0..MAXPROC] of PProc;N,K:Integer;Path:String;P:PProc;Ok:Boolean;
Begin
 If Not ParseProcs(R,L,N,Path,False)Then Exit;
 OpenRedir(Path,Ok);
 For K:=0 to N-1 do Begin
  P:=L[K];
  EnsureBound(P,False);
  ShOut('PROCEDURE '+P^.Name);
  ShOut('  Variable storage : '+IStr(P^.Bnd.VarC)+' bytes');
  ShOut('  Prologue size    : '+IStr(P^.Bnd.PrcS)+' bytes');
  ShOut('  DATA offset      : '+Hex4(P^.Bnd.DataOfs));
  ShOut('  Exec offset      : '+Hex4(P^.Bnd.ExecOfs));
  ShOut('  Status           : '+Hex2(P^.Bnd.Stat));
  ShOut('  I-code           : '+IStr(P^.Bnd.Code.Len)+' bytes');
  HexDump(P^.Bnd.Code);
  ShOut('  Descriptions     : '+IStr(P^.Bnd.Dsc.Len)+' bytes');
  HexDump(P^.Bnd.Dsc);
  ShOut('  Symbol table     : '+IStr(P^.Bnd.Sym.B.Len)+' bytes');
  HexDump(P^.Bnd.Sym.B);
 End;
 CloseRedir;
End;

Procedure CmdRename(Const R:String);
Var I:Integer;Old,New:String;P,Q:PProc;
Begin
 I:=1;
 If Not ParseName(R,I,Old)Then Begin
  If Active<>Nil Then Old:=Active^.Name Else Old:='Program';
 End;
 P:=FindProcByName(Old);
 If(P=Nil)or P^.IsMod Then Begin PrtError(M_UPRC);Exit;End;
 I:=SkipBl(R,I);
 If(I>Length(R))or Not(R[I]in[',',' '])Then Begin
  If I>Length(R)Then Begin What;Exit;End;
 End;
 If(I<=Length(R))and(R[I]=',')Then Inc(I);
 If Not ParseName(R,I,New)Then Begin What;Exit;End;
 Q:=FindProcByName(New);
 If(Q<>Nil)and(Q<>P)Then Begin PrtError(M_MDPC);Exit;End;
 P^.Name:=New;
 P^.HasBnd:=False;
End;

Procedure CmdMem(Const R:String);
Var I:Integer;V:Longint;Need:Longint;K:Integer;
Begin
 I:=1;
 I:=SkipBl(R,I);
 If I<=Length(R)Then Begin
  If Not GetNum(R,I,V)Then Begin What;Exit;End;
  Need:=1024;
  For K:=1 to NProcs do Need:=Need+ProcSize(Procs[K]);
  If V<Need Then Begin What;Exit;End;
  WspSize:=V;
 End;
 ShOut(IStr(WspSize));
End;

Procedure CmdChd(Const R:String;Exec:Boolean);
Var P:String;
Begin
 P:=TrimS(R);
 {$IOCHECKS OFF}
 ChDir(DosPath(P));
 {$IOCHECKS ON}
 If IOResult<>0 Then PrtError(E_PNNF);
End;

Var
 RunFailed:Boolean;

Procedure CmdRun(Const R:String);
Var I:Integer;Nm,Args:String;P:PProc;Rc:Integer;
Begin
 I:=1;
 If Not ParseName(R,I,Nm)Then Begin
  If Active<>Nil Then Nm:=Active^.Name Else Nm:='Program';
 End;
 Args:=TrimS(Copy(R,I,Length(R)));
 P:=FindProcByName(Nm);
 If P=Nil Then P:=LoadModuleByName(Nm);
 If P=Nil Then Begin PrtError(M_UPRC);Exit;End;
 Active:=P;
 Rc:=RunTop(P,Args);
 If Rc=2 Then ExitReq:=True;
 If Rc=1 Then RunFailed:=True;
End;

Procedure CmdLoad(Const R:String);
Var Path:String;Rc:Integer;
Begin
 Path:=TrimS(R);
 If Path='' Then Begin What;Exit;End;
 Rc:=LoadAnyFile(Path);
 If(Rc<>0)and(Rc<>E_EOF)Then PrtError(Rc);
End;

{ Interprete une ligne de commande de niveau B: }
Procedure ExecCommand(Const Line:String);
Var I:Integer;W,R:String;
Begin
 I:=SkipBl(Line,1);
 If I>Length(Line)Then Begin CmdDir('');Exit;End;
 If Line[I]='$' Then Begin
  ShellCmd(Copy(Line,I+1,Length(Line)));
  Exit;
 End;
 W:='';
 While(I<=Length(Line))and(Line[I]in['A'..'Z','a'..'z'])do Begin W:=W+Line[I];Inc(I);End;
 R:=Copy(Line,I,Length(Line));
 W:=UpStr(W);
 If W='BYE' Then ExitReq:=True
 Else If W='DIR' Then CmdDir(R)
 Else If(W='EDIT')or(W='E')Then CmdEdit(R)
 Else If W='LIST' Then CmdList(R,False)
 Else If W='RUN' Then CmdRun(R)
 Else If W='KILL' Then CmdKill(R)
 Else If W='SAVE' Then CmdList(R,True)
 Else If W='LOAD' Then CmdLoad(R)
 Else If W='RENAME' Then CmdRename(R)
 Else If W='PACK' Then CmdPack(R)
 Else If W='DUMP' Then CmdDump(R)
 Else If W='MEM' Then CmdMem(R)
 Else If W='CHD' Then CmdChd(R,False)
 Else If W='CHX' Then CmdChd(R,True)
 Else What;
End;

Procedure CommandLoop;
Var S:String;
Begin
 While Not ExitReq do Begin
  ShOut('Ready');
  If Not GetLine('B:',S)Then Begin ExitReq:=True;Break;End;
  ExecCommand(S);
 End;
End;

{ ---------------------------------------------------------------------------- }
{  Initialisation et programme principal                                       }
{ ---------------------------------------------------------------------------- }

Procedure InitAll;
Begin
 InitTokens;
 InitKeywords;
 InitPaths;
 NProcs:=0;
 Active:=Nil;
 MemSP:=65536;
 RndSeed:=$0E1214A2;
 WspSize:=32768;
 OutRedir:=False;
 BatchMode:=False;
 StepOn:=False;
 ExitReq:=False;
 RunTrace:=False;
 SymClear(EmptySym);
 TopProc:=NewProcRec('');
 TopProc^.IsMod:=True;
 TopProc^.HasBnd:=True;
 SymClear(TopProc^.Bnd.Sym);
 New(TopAct);
 FillChar(TopAct^,SizeOf(TAct),0);
 TopAct^.Prc:=TopProc;
 TopAct^.Base:=1;
 Act:=Nil;
 InPth:=0;OutPth:=1;CnCh:=1;
 RunFailed:=False;
End;

Procedure Banner;
Begin
 WriteLn('            BASIC09');
 WriteLn('   Clone for DOS - Free Pascal');
 WriteLn;
End;

Procedure Usage;
Begin
 WriteLn('BASIC09 - Cette commande permet de lancer un clone du BASIC09.');
 WriteLn;
 WriteLn('Syntaxe : BASIC09 [options] [fichier ...]');
 WriteLn;
 WriteLn('  -r spec   Execute la procedure ''spec'' (nom[(parametres)]) puis quitte');
 WriteLn('  -x cmd    Execute la commande B: ''cmd''');
 WriteLn('  -l        Liste les procedures chargees puis quitte');
 WriteLn('  -d        Vide la structure binaire (I-code, tables) puis quitte');
 WriteLn('  -p        Compresse les procedures chargees vers <nom>.mod puis quitte');
 WriteLn('  -q        Aucune banniere');
 WriteLn('  -h, /?    Cette aide');
 WriteLn('Les fichiers sont des modules I-code ou des fichiers source (PROCEDURE ...).');
End;

Var
 ArgI:Integer;
 ArgS:String;
 RunSpec:String;
 DoRun,DoList,DoPack,DoDump,Quiet:Boolean;
 Cmds:Array[0..15] of String;
 NCmds,CI,ExitCode:Integer;
 LErr:Integer;

Begin
 InitAll;
 DoRun:=False;DoList:=False;DoPack:=False;DoDump:=False;Quiet:=False;NCmds:=0;ExitCode:=0;
 RunSpec:='';
 ArgI:=1;
 While ArgI<=ParamCount do Begin
  ArgS:=ParamStr(ArgI);
  If(Length(ArgS)>1)and(ArgS[1]in['-','/'])and(ArgS[2]in['A'..'Z','a'..'z','?'])Then Begin
   Case UpCase(ArgS[2])of
    'R':Begin
         DoRun:=True;
         If ArgI<ParamCount Then Begin Inc(ArgI);RunSpec:=ParamStr(ArgI);End;
        End;
    'X':Begin
         If(ArgI<ParamCount)and(NCmds<16)Then Begin
          Inc(ArgI);
          Cmds[NCmds]:=ParamStr(ArgI);
          Inc(NCmds);
         End;
        End;
    'L':DoList:=True;
    'D':DoDump:=True;
    'P':DoPack:=True;
    'Q':Quiet:=True;
   Else Begin Usage;Halt(0);End;
   End;
  End
   Else
  Begin
   LErr:=LoadAnyFile(ArgS);
   If LErr<>0 Then Begin
    WriteLn(ArgS+': ');
    PrtError(LErr);
    ExitCode:=1;
   End;
  End;
  Inc(ArgI);
 End;
 If DoRun or DoList or DoPack or DoDump or(NCmds>0)Then Begin
  BatchMode:=True;
  For CI:=0 to NCmds-1 do Begin
   ExecCommand(Cmds[CI]);
   If ExitReq Then Break;
  End;
  If DoList and Not ExitReq Then CmdList('*',False);
  If DoDump and Not ExitReq Then CmdDump('*');
  If DoPack and Not ExitReq Then CmdPack('*');
  If DoRun and Not ExitReq Then Begin
   If RunSpec='' Then CmdRun('')Else CmdRun(RunSpec);
   If RunFailed Then ExitCode:=1;
  End;
 End
  Else
 Begin
  If Not Quiet Then Banner;
  CommandLoop;
 End;
 Halt(ExitCode);
End.
