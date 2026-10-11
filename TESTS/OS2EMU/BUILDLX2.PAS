{$MODE OBJFPC}{$H+}
Program BuildLX2;
{ Construit des executables OS/2 LX minimaux, a la main, octet par octet,  }
{ pour exercer REELLEMENT les 20 NOUVELLES fonctions BSD Sockets d'OS/2    }
{ (2026-10-11, demande explicite - liste complete de 41 entrees, les 20    }
{ 1eres deja couvertes par TESTS/OS2EMU/TCPSOCK+TCPNAME+TCPOPT.EXE) via le }
{ vrai chargeur LX (Emu_LoadLX/Lx_ApplyPageFixups/Lx_Step/Lx_DoDosCall) de  }
{ DEVENV.PAS - MEME infrastructure generique que BUILDLX.PAS (voir         }
{ TESTS/OS2EMU/BUILDLX.PAS pour la documentation complete du format        }
{ conteneur LX construit a la main - recopiee ici telle quelle, aucun      }
{ changement, pour que ce 2e lot de tests reste autonome dans son propre   }
{ dossier TESTS/EMUOS2/). }

Uses SysUtils;

Type
 TBytes = Array Of Byte;

{ ---------- Petit assembleur de flux d'octets (identique a BUILDLX.PAS) --}

Type
 TByteBuf = Record
  Data: TBytes;
  Len: LongInt;
 End;

Procedure BufInit(Var B: TByteBuf);
Begin
 SetLength(B.Data, 65536);
 B.Len := 0;
End;

Procedure BufByte(Var B: TByteBuf; V: Byte);
Begin
 If B.Len >= Length(B.Data) Then SetLength(B.Data, Length(B.Data) * 2);
 B.Data[B.Len] := V;
 Inc(B.Len);
End;

Procedure BufWord(Var B: TByteBuf; V: Word);
Begin
 BufByte(B, Byte(V And $FF));
 BufByte(B, Byte((V Shr 8) And $FF));
End;

Procedure BufDWord(Var B: TByteBuf; V: LongWord);
Begin
 BufByte(B, Byte(V And $FF));
 BufByte(B, Byte((V Shr 8) And $FF));
 BufByte(B, Byte((V Shr 16) And $FF));
 BufByte(B, Byte((V Shr 24) And $FF));
End;

Procedure BufStr(Var B: TByteBuf; Const S: String);
Var I: Integer;
Begin
 For I := 1 To Length(S) Do BufByte(B, Ord(S[I]));
End;

Procedure BufPad(Var B: TByteBuf; UpTo: LongInt);
Begin
 While B.Len < UpTo Do BufByte(B, 0);
End;

{ ---------- Encodeurs d'instructions x86-32 (sous-ensemble MOV/PUSH/CALL) }

Procedure AsmPushImm32(Var B: TByteBuf; V: LongWord);
Begin
 BufByte(B, $68); BufDWord(B, V);
End;

Procedure AsmPushMem32(Var B: TByteBuf; Addr: LongWord);
Begin
 BufByte(B, $FF); BufByte(B, $35); BufDWord(B, Addr);
End;

Procedure AsmMovEaxImm32(Var B: TByteBuf; V: LongWord);
Begin
 BufByte(B, $B8); BufDWord(B, V);
End;

Procedure AsmMovMem32Eax(Var B: TByteBuf; Addr: LongWord);
Begin
 BufByte(B, $89); BufByte(B, $05); BufDWord(B, Addr);
End;

Procedure AsmMovEaxMem32(Var B: TByteBuf; Addr: LongWord);
Begin
 BufByte(B, $8B); BufByte(B, $05); BufDWord(B, Addr);
End;

Procedure AsmMovMem8Imm8(Var B: TByteBuf; Addr: LongWord; V: Byte);
Begin
 BufByte(B, $C6); BufByte(B, $05); BufDWord(B, Addr); BufByte(B, V);
End;

Function AsmCallRel32Placeholder(Var B: TByteBuf): LongInt;
Begin
 BufByte(B, $E8);
 Result := B.Len;
 BufDWord(B, 0);
End;

{ ---------- Table de fixups a construire en parallele du code ---------- }

Type
 TFixupRec = Record
  CodeOfs: LongInt;
  ModOrd: Byte;
  ProcName: String;
 End;
 TFixupArr = Array Of TFixupRec;

Procedure AddFixup(Var Arr: TFixupArr; CodeOfs: LongInt; ModOrd: Byte; Const ProcName: String);
Begin
 SetLength(Arr, Length(Arr) + 1);
 Arr[High(Arr)].CodeOfs := CodeOfs;
 Arr[High(Arr)].ModOrd := ModOrd;
 Arr[High(Arr)].ProcName := ProcName;
End;

Procedure EmitCall(Var Code: TByteBuf; Var Fixups: TFixupArr; ModOrd: Byte; Const ProcName: String);
Begin
 AddFixup(Fixups, AsmCallRel32Placeholder(Code), ModOrd, ProcName);
End;

{ ---------- Constructeur generique de fichier LX (2 objets : CODE / DATA) }
{ (identique a BuildLXFile dans TESTS/OS2EMU/BUILDLX.PAS - voir ce fichier }
{ pour la documentation complete de chaque section, y compris les 2        }
{ bogues reels deja trouves+corriges dans cette logique : en-tete a 168    }
{ au lieu de 176 octets, et arrondi de e32_datapage sur la valeur relative }
{ au lieu de la valeur absolue.) }

Const
 PAGE_SIZE  = 4096;
 CODE_BASE  = $00010000;
 DATA_BASE  = $00020000;

 LXOBJ_READABLE   = $0001;
 LXOBJ_WRITABLE   = $0002;
 LXOBJ_EXECUTABLE = $0004;
 LXOBJ_BIG32      = $2000;

Procedure BuildLXFile(Const OutPath: String; Const CodeBytes, DataBytes: TByteBuf;
 Const Fixups: TFixupArr; Const ImpModNames: Array Of String);
Var
 F: File;
 HdrOfs: LongInt;
 ObjTabOfs, ObjMapOfs, FPageTabOfs, FRecTabOfs, ImpModOfs, ImpProcOfs, DataPageOfs: LongInt;
 CodePageFileOfs, DataPageFileOfs: LongInt;
 FRec, FPageTab, ImpModBuf, ImpProcBuf, Hdr, ObjTab, ObjMap, FileBuf: TByteBuf;
 I: LongInt;
 ProcNameOfsOf: Array Of LongInt;
Begin
 If CodeBytes.Len > PAGE_SIZE Then Begin
  WriteLn('ERREUR : objet CODE > 1 page (', CodeBytes.Len, ' octets).'); Halt(1);
 End;
 If DataBytes.Len > PAGE_SIZE Then Begin
  WriteLn('ERREUR : objet DATA > 1 page (', DataBytes.Len, ' octets).'); Halt(1);
 End;

 BufInit(ImpProcBuf);
 SetLength(ProcNameOfsOf, Length(Fixups));
 For I := 0 To High(Fixups) Do Begin
  ProcNameOfsOf[I] := ImpProcBuf.Len;
  BufByte(ImpProcBuf, Length(Fixups[I].ProcName));
  BufStr(ImpProcBuf, Fixups[I].ProcName);
 End;

 BufInit(ImpModBuf);
 For I := 0 To High(ImpModNames) Do Begin
  BufByte(ImpModBuf, Length(ImpModNames[I]));
  BufStr(ImpModBuf, ImpModNames[I]);
 End;

 BufInit(FRec);
 For I := 0 To High(Fixups) Do Begin
  BufByte(FRec, 8);
  BufByte(FRec, $12);
  BufWord(FRec, Word(Fixups[I].CodeOfs));
  BufByte(FRec, Fixups[I].ModOrd);
  BufDWord(FRec, LongWord(ProcNameOfsOf[I]));
 End;

 BufInit(FPageTab);
 BufDWord(FPageTab, 0);
 BufDWord(FPageTab, LongWord(FRec.Len));
 BufDWord(FPageTab, LongWord(FRec.Len));

 ObjTabOfs   := 176;
 ObjMapOfs   := ObjTabOfs + 2 * 24;
 FPageTabOfs := ObjMapOfs + 2 * 8;
 FRecTabOfs  := FPageTabOfs + FPageTab.Len;
 ImpModOfs   := FRecTabOfs + FRec.Len;
 ImpProcOfs  := ImpModOfs + ImpModBuf.Len;
 DataPageOfs := ImpProcOfs + ImpProcBuf.Len;
 If (DataPageOfs + $40) Mod 512 <> 0 Then
  DataPageOfs := DataPageOfs + (512 - (DataPageOfs + $40) Mod 512);

 BufInit(ObjTab);
 BufDWord(ObjTab, LongWord(CodeBytes.Len));
 BufDWord(ObjTab, LongWord(CODE_BASE));
 BufDWord(ObjTab, LongWord(LXOBJ_READABLE Or LXOBJ_EXECUTABLE Or LXOBJ_BIG32));
 BufDWord(ObjTab, 1);
 BufDWord(ObjTab, 1);
 BufDWord(ObjTab, 0);
 BufDWord(ObjTab, LongWord(DataBytes.Len));
 BufDWord(ObjTab, LongWord(DATA_BASE));
 BufDWord(ObjTab, LongWord(LXOBJ_READABLE Or LXOBJ_WRITABLE Or LXOBJ_BIG32));
 BufDWord(ObjTab, 2);
 BufDWord(ObjTab, 1);
 BufDWord(ObjTab, 0);

 CodePageFileOfs := DataPageOfs;
 DataPageFileOfs := DataPageOfs + PAGE_SIZE;

 BufInit(ObjMap);
 BufDWord(ObjMap, LongWord((CodePageFileOfs + $40) Div 512));
 BufWord(ObjMap, Word(CodeBytes.Len));
 BufWord(ObjMap, 0);
 BufDWord(ObjMap, LongWord((DataPageFileOfs + $40) Div 512));
 BufWord(ObjMap, Word(DataBytes.Len));
 BufWord(ObjMap, 0);

 BufInit(Hdr);
 BufByte(Hdr, Ord('L')); BufByte(Hdr, Ord('X'));
 BufByte(Hdr, 0); BufByte(Hdr, 0);
 BufDWord(Hdr, 0);
 BufWord(Hdr, 2);
 BufWord(Hdr, 1);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 2);
 BufDWord(Hdr, 1);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 2);
 BufDWord(Hdr, LongWord(DataBytes.Len));
 BufDWord(Hdr, PAGE_SIZE);
 BufDWord(Hdr, 9);
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, LongWord(ObjTabOfs));
 BufDWord(Hdr, 2);
 BufDWord(Hdr, LongWord(ObjMapOfs));
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, LongWord(FPageTabOfs));
 BufDWord(Hdr, LongWord(FRecTabOfs));
 BufDWord(Hdr, LongWord(ImpModOfs));
 BufDWord(Hdr, LongWord(Length(ImpModNames)));
 BufDWord(Hdr, LongWord(ImpProcOfs));
 BufDWord(Hdr, 0);
 BufDWord(Hdr, LongWord(DataPageOfs + $40));
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, LongWord(DataBytes.Len));
 If Hdr.Len <> 176 Then Begin
  WriteLn('ERREUR INTERNE : en-tete LX <> 176 octets (', Hdr.Len, ')'); Halt(1);
 End;

 BufInit(FileBuf);
 BufByte(FileBuf, Ord('M')); BufByte(FileBuf, Ord('Z'));
 BufPad(FileBuf, 6);
 BufWord(FileBuf, 0);
 BufPad(FileBuf, $3C);
 BufDWord(FileBuf, $40);
 BufPad(FileBuf, $40);
 HdrOfs := FileBuf.Len;

 For I := 0 To Hdr.Len - 1 Do BufByte(FileBuf, Hdr.Data[I]);
 For I := 0 To ObjTab.Len - 1 Do BufByte(FileBuf, ObjTab.Data[I]);
 For I := 0 To ObjMap.Len - 1 Do BufByte(FileBuf, ObjMap.Data[I]);
 For I := 0 To FPageTab.Len - 1 Do BufByte(FileBuf, FPageTab.Data[I]);
 For I := 0 To FRec.Len - 1 Do BufByte(FileBuf, FRec.Data[I]);
 For I := 0 To ImpModBuf.Len - 1 Do BufByte(FileBuf, ImpModBuf.Data[I]);
 For I := 0 To ImpProcBuf.Len - 1 Do BufByte(FileBuf, ImpProcBuf.Data[I]);
 BufPad(FileBuf, DataPageOfs + HdrOfs);
 For I := 0 To CodeBytes.Len - 1 Do BufByte(FileBuf, CodeBytes.Data[I]);
 BufPad(FileBuf, DataPageFileOfs + HdrOfs);
 For I := 0 To DataBytes.Len - 1 Do BufByte(FileBuf, DataBytes.Data[I]);

 Assign(F, OutPath);
 Rewrite(F, 1);
 BlockWrite(F, FileBuf.Data[0], FileBuf.Len);
 Close(F);
 WriteLn('Ecrit : ', OutPath, ' (', FileBuf.Len, ' octets, ', Length(Fixups),
  ' fixups, datapage=$', HexStr(DataPageOfs + HdrOfs, 8),
  ', code@$', HexStr(CODE_BASE, 8), ', data@$', HexStr(DATA_BASE, 8), ')');
End;

{ =====================================================================    }
{ Programme de test 1 : TCPCONV - fonctions de conversion/traduction PURES }
{ (htonl/htons/ntohl/ntohs, inet_addr/inet_ntoa/inet_network/inet_lnaof/   }
{ inet_netof/inet_makeaddr) + nom d'hote/domaine simules (gethostname/     }
{ sethostname/getdomainname/setdomainname) + protocoles (getprotobyname/   }
{ getprotobynumber) - 16 des 20 nouvelles fonctions. }
{ =====================================================================    }
Procedure BuildTcpConv(Const OutPath: String);
Const
 D_RESULTS   = $00; { 18 dwords = 0x48 octets, R0..R17 }
 D_IPSTR     = $50; { "127.0.0.1"+0 }
 D_HOSTNAME2 = $60; { "unit-test-host"+0 (14+1=15 octets) }
 D_DOMAIN2   = $70; { "example.test"+0 (12+1=13 octets) }
 D_NAMEBUF   = $90; { 48 octets scratch, reutilise gethostname/getdomainname }
 D_PROTOSTR  = $C0; { "tcp"+0 }
 D_DUMMY     = $C8; { pcbActual de DosWrite }
 D_END       = $D0;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_RESULTS + $48);
 BufStr(Data, '127.0.0.1'); BufByte(Data, 0);
 BufPad(Data, D_HOSTNAME2);
 BufStr(Data, 'unit-test-host'); BufByte(Data, 0);
 BufPad(Data, D_DOMAIN2);
 BufStr(Data, 'example.test'); BufByte(Data, 0);
 BufPad(Data, D_NAMEBUF + 48);
 BufStr(Data, 'tcp'); BufByte(Data, 0);
 BufPad(Data, D_DUMMY + 4);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);
 { Modules importes = ['TCPIP32','DOSCALLS'] -> ModOrd 1=TCPIP32, 2=DOSCALLS}

 { R0 := htonl($01020304) }
 AsmPushImm32(Code, $01020304);
 EmitCall(Code, Fixups, 1, 'HTONL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $00);

 { R1 := htons($1234) }
 AsmPushImm32(Code, $00001234);
 EmitCall(Code, Fixups, 1, 'HTONS');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $04);

 { R2 := ntohl(R0) - doit redonner EXACTEMENT $01020304 (aller-retour pur) }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $00);
 EmitCall(Code, Fixups, 1, 'NTOHL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $08);

 { R3 := ntohs(R1) - doit redonner $1234 (mot de poids faible) }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'NTOHS');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $0C);

 { R4 := inet_addr("127.0.0.1") }
 AsmPushImm32(Code, DATA_BASE + D_IPSTR);
 EmitCall(Code, Fixups, 1, 'INET_ADDR');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $10);

 { R5 := inet_ntoa(R4) - pointeur invite vers "127.0.0.1" fraichement       }
 { alloue (bump allocator), affiche plus bas via DosWrite. }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $10);
 EmitCall(Code, Fixups, 1, 'INET_NTOA');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $14);

 { R6 := inet_network("127.0.0.1") }
 AsmPushImm32(Code, DATA_BASE + D_IPSTR);
 EmitCall(Code, Fixups, 1, 'INET_NETWORK');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $18);

 { R7 := inet_lnaof(R4) }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $10);
 EmitCall(Code, Fixups, 1, 'INET_LNAOF');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $1C);

 { R8 := inet_netof(R4) }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $10);
 EmitCall(Code, Fixups, 1, 'INET_NETOF');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $20);

 { R9 := inet_makeaddr(127, 1) - doit redonner EXACTEMENT R4 (meme aller-   }
 { retour que R2, sur les fonctions d'adresse cette fois). }
 AsmPushImm32(Code, 1);   { host }
 AsmPushImm32(Code, 127); { net }
 EmitCall(Code, Fixups, 1, 'INET_MAKEADDR');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $24);

 { R10 := gethostname(&D_NAMEBUF, 48) - vrai nom d'hote de la machine }
 AsmPushImm32(Code, 48);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 EmitCall(Code, Fixups, 1, 'GETHOSTNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $28);

 { R11 := sethostname(&D_HOSTNAME2, 14) - simule, ne touche jamais au vrai  }
 { systeme hote (voir la disclosure dans DEVENV.PAS). }
 AsmPushImm32(Code, 14);
 AsmPushImm32(Code, DATA_BASE + D_HOSTNAME2);
 EmitCall(Code, Fixups, 1, 'SETHOSTNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $2C);

 { R12 := gethostname(&D_NAMEBUF, 48) de nouveau - doit maintenant refleter }
 { le sethostname() simule ci-dessus (prevue de "unit-test-host"). }
 AsmPushImm32(Code, 48);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 EmitCall(Code, Fixups, 1, 'GETHOSTNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $30);

 { DosWrite(1, &D_NAMEBUF, 14, &D_DUMMY) - affiche "unit-test-host" dans le }
 { terminal si l'aller-retour sethostname->gethostname a reellement marche.}
 AsmPushImm32(Code, DATA_BASE + D_DUMMY);
 AsmPushImm32(Code, 14);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 2, 'DosWrite');

 { R13 := getdomainname(&D_NAMEBUF, 48) - vide avant tout setdomainname() }
 AsmPushImm32(Code, 48);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 EmitCall(Code, Fixups, 1, 'GETDOMAINNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $34);

 { R14 := setdomainname(&D_DOMAIN2, 12) - simule, meme disclosure que       }
 { SETHOSTNAME ci-dessus. }
 AsmPushImm32(Code, 12);
 AsmPushImm32(Code, DATA_BASE + D_DOMAIN2);
 EmitCall(Code, Fixups, 1, 'SETDOMAINNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $38);

 { R15 := getdomainname(&D_NAMEBUF, 48) de nouveau - doit refleter          }
 { "example.test". }
 AsmPushImm32(Code, 48);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 EmitCall(Code, Fixups, 1, 'GETDOMAINNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $3C);

 { DosWrite(1, &D_NAMEBUF, 12, &D_DUMMY) - affiche "example.test". }
 AsmPushImm32(Code, DATA_BASE + D_DUMMY);
 AsmPushImm32(Code, 12);
 AsmPushImm32(Code, DATA_BASE + D_NAMEBUF);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 2, 'DosWrite');

 { R16 := getprotobyname("tcp") - pointeur non nul attendu }
 AsmPushImm32(Code, DATA_BASE + D_PROTOSTR);
 EmitCall(Code, Fixups, 1, 'GETPROTOBYNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $40);

 { R17 := getprotobynumber(6) - IPPROTO_TCP=6, doit aussi resoudre "tcp" }
 AsmPushImm32(Code, 6);
 EmitCall(Code, Fixups, 1, 'GETPROTOBYNUMBER');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $44);

 { DosWrite(1, R5(valeur=pointeur invite), 9, &D_DUMMY) - affiche            }
 { "127.0.0.1" tel que redonne par inet_ntoa (preuve visuelle du marshaling }
 { de chaine vers le tas invite). }
 AsmPushImm32(Code, DATA_BASE + D_DUMMY);
 AsmPushImm32(Code, 9);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $14);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 2, 'DosWrite');

 { DosExit(0, R2) - R2=ntohl(htonl($01020304)) doit valoir EXACTEMENT        }
 { $01020304 = 16909060 decimal (aller-retour pur, sans aucune dependance   }
 { reseau/hote - le signal le plus simple et le plus deterministe de ce     }
 { fichier de test). }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $08);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['TCPIP32', 'DOSCALLS']);
End;

{ =====================================================================    }
{ Programme de test 2 : TCPEXT - socketpair/fcntl/sendmsg/recvmsg (les 4   }
{ dernieres des 20 nouvelles fonctions) - boucle locale REELLE (une VRAIE   }
{ paire de sockets 127.0.0.1 connectes entre eux, voir la disclosure         }
{ SOCKETPAIR dans DEVENV.PAS). }
{ =====================================================================    }
Procedure BuildTcpExt(Const OutPath: String);
Const
 D_RESULTS = $00; { 5 dwords = R0..R4 }
 D_SV      = $20; { 2 dwords : sv[0], sv[1] (remplis par SOCKETPAIR) }
 D_MSGHDR  = $30; { 28 octets : msghdr pour SENDMSG }
 D_IOVEC   = $50; { 8 octets : iovec pour SENDMSG }
 D_SENDBUF = $60; { "HI!" = 3 octets, prerempli }
 D_MSGHDR2 = $70; { 28 octets : msghdr pour RECVMSG }
 D_IOVEC2  = $90; { 8 octets : iovec pour RECVMSG }
 D_RECVBUF = $A0; { 4 octets scratch }
 D_DUMMY   = $B0; { pcbActual de DosWrite }
 D_END     = $C0;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_RESULTS + 20);
 BufPad(Data, D_SV + 8);
 { D_MSGHDR : msg_name=0 msg_namelen=0 msg_iov=&D_IOVEC msg_iovlen=1        }
 { msg_control=0 msg_controllen=0 msg_flags=0 - layout verifie champ par    }
 { champ contre le branchement SENDMSG de Lx_DoDosCall. }
 BufDWord(Data, 0); BufDWord(Data, 0);
 BufDWord(Data, DATA_BASE + D_IOVEC); BufDWord(Data, 1);
 BufDWord(Data, 0); BufDWord(Data, 0); BufDWord(Data, 0);
 BufPad(Data, D_IOVEC);
 BufDWord(Data, DATA_BASE + D_SENDBUF); BufDWord(Data, 3);
 BufPad(Data, D_SENDBUF);
 BufByte(Data, Ord('H')); BufByte(Data, Ord('I')); BufByte(Data, Ord('!'));
 BufPad(Data, D_MSGHDR2);
 BufDWord(Data, 0); BufDWord(Data, 0);
 BufDWord(Data, DATA_BASE + D_IOVEC2); BufDWord(Data, 1);
 BufDWord(Data, 0); BufDWord(Data, 0); BufDWord(Data, 0);
 BufPad(Data, D_IOVEC2);
 BufDWord(Data, DATA_BASE + D_RECVBUF); BufDWord(Data, 4);
 BufPad(Data, D_RECVBUF + 4);
 BufPad(Data, D_DUMMY + 4);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);
 { Modules importes = ['TCPIP32','DOSCALLS'] -> ModOrd 1=TCPIP32, 2=DOSCALLS}

 { R0 := socketpair(AF_UNIX(nominal, IGNORE), SOCK_STREAM=1, 0, &D_SV) -     }
 { emule via une VRAIE paire TCP 127.0.0.1 connectee (voir la disclosure    }
 { dans DEVENV.PAS - aucun domaine AF_UNIX natif sous Winsock). }
 AsmPushImm32(Code, DATA_BASE + D_SV);
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 1);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 1, 'SOCKETPAIR');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $00);

 { R1 := fcntl(sv[0], F_SETFL=4, O_NONBLOCK=$0004) }
 AsmPushImm32(Code, $00000004);
 AsmPushImm32(Code, 4);
 AsmPushMem32(Code, DATA_BASE + D_SV + 0);
 EmitCall(Code, Fixups, 1, 'FCNTL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $04);

 { R2 := fcntl(sv[0], F_GETFL=3, 0) - doit redonner EXACTEMENT $0004,        }
 { preuve que l'etat non bloquant pose ci-dessus est bien relu (table        }
 { Os2FcntlNbSock/Flag, seule source cote emulateur - Winsock lui-meme ne    }
 { permet PAS de relire cet etat). }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 3);
 AsmPushMem32(Code, DATA_BASE + D_SV + 0);
 EmitCall(Code, Fixups, 1, 'FCNTL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $08);

 { R3 := sendmsg(sv[0], &D_MSGHDR, 0) - envoie "HI!" (3 octets) via UN       }
 { SEUL iovec, a travers le VRAI socket connecte par SOCKETPAIR. }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, DATA_BASE + D_MSGHDR);
 AsmPushMem32(Code, DATA_BASE + D_SV + 0);
 EmitCall(Code, Fixups, 1, 'SENDMSG');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $0C);

 { R4 := recvmsg(sv[1], &D_MSGHDR2, 0) - recoit depuis l'AUTRE bout de la    }
 { meme paire reelle. }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, DATA_BASE + D_MSGHDR2);
 AsmPushMem32(Code, DATA_BASE + D_SV + 4);
 EmitCall(Code, Fixups, 1, 'RECVMSG');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $10);

 { DosWrite(1, &D_RECVBUF, 3, &D_DUMMY) - affiche "HI!" tel que recu, preuve }
 { visuelle que sendmsg/recvmsg transportent reellement les octets a         }
 { travers la paire de sockets (pas une simple copie locale simulee). }
 AsmPushImm32(Code, DATA_BASE + D_DUMMY);
 AsmPushImm32(Code, 3);
 AsmPushImm32(Code, DATA_BASE + D_RECVBUF);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 2, 'DosWrite');

 { closesocket(sv[0]) ; closesocket(sv[1]) }
 AsmPushMem32(Code, DATA_BASE + D_SV + 0);
 EmitCall(Code, Fixups, 1, 'CLOSESOCKET');
 AsmPushMem32(Code, DATA_BASE + D_SV + 4);
 EmitCall(Code, Fixups, 1, 'CLOSESOCKET');

 { DosExit(0, R4) - R4 = nombre d'octets reellement recus par recvmsg        }
 { (3 = succes total de toute la chaine socketpair->fcntl->sendmsg->         }
 { recvmsg). }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $10);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['TCPIP32', 'DOSCALLS']);
End;

Var
 OutDir: String;
Begin
 If ParamCount >= 1 Then OutDir := ParamStr(1) Else OutDir := '.';
 BuildTcpConv(OutDir + '\TCPCONV.EXE');
 BuildTcpExt(OutDir + '\TCPEXT.EXE');
 WriteLn('Termine.');
End.
