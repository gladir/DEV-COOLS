{$MODE OBJFPC}{$H+}
Program BuildLX;
{ Construit des executables OS/2 LX minimaux, a la main, octet par octet,  }
{ pour exercer REELLEMENT le chargeur Emu_LoadLX/Lx_ApplyPageFixups et le  }
{ dispatcher TCPIP32 (Lx_DoDosCall) de DEVENV.PAS - aucun assembleur/      }
{ linker OS/2 n'existe dans ce depot (verifie par un agent Explore), donc  }
{ construction directe du conteneur LX (en-tete 176 octets, table objets,  }
{ table pages objet, table pages de fixup, table d'enregistrements de      }
{ fixup, table noms modules importes, table noms procedures importees) +  }
{ code machine x86-32 assemble a la main (MOV/PUSH/CALL uniquement, voir   }
{ le commentaire de tete de AsmCallRel32Placeholder pour la justification  }
{ de ce choix restreint). SIMPLIFICATION ASSUMEE : chaque objet (CODE et   }
{ DATA) tient dans UNE SEULE page de 4096 octets (verifie par assertion a  }
{ l'execution) - les programmes de test sont minuscules, ca evite toute    }
{ subtilite de stride inter-pages dans le calcul des offsets fichier.      }

Uses SysUtils;

Type
 TBytes = Array Of Byte;

{ ---------- Petit assembleur de flux d'octets ---------- }

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
{ Encodages standards Intel (manuel Intel x86, non ambigus) :              }
{  PUSH imm32          = 68 id                                             }
{  PUSH r/m32 (mem)    = FF /6  (ModRM mod=00,reg=110,rm=101 + disp32)     }
{  MOV reg32, imm32    = B8+rd id  (ici seulement EAX : B8)                }
{  MOV r/m32, reg32    = 89 /r  (mem direct : mod=00,reg=000,rm=101+disp32)}
{  MOV reg32, r/m32    = 8B /r  (mem direct : mod=00,reg=000,rm=101+disp32)}
{  MOV r/m8, imm8      = C6 /0  (mod=00,reg=000,rm=101+disp32) ib          }
{  CALL rel32          = E8 id                                             }
{  ModRM "disp32 only" (acces memoire direct, sans base/index) : mod=00,   }
{  rm=101, suivi d'un disp32 ABSOLU - forme standard pour une variable      }
{  globale en 32 bits, utilisee par tout compilateur C/Pascal.             }

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

{ CALL rel32 - le disp32 est laisse a 0 ; un enregistrement de FIXUP        }
{ (TgtType=2 IMPORTNAME, SrcType=8 REL32) le corrigera au chargement (voir  }
{ Lx_ApplyPageFixups : WriteAddr=DestAddr+SrcOfs, TargetVal -= WriteAddr+4  }
{ pour SrcType=8 - exactement le calcul standard d'un CALL E8 relatif).     }
{ Retourne l'offset (dans B, = DANS L'OBJET CODE) du DEBUT du champ disp32 }
{ (l'octet juste apres E8), necessaire pour batir le fixup correspondant.  }
Function AsmCallRel32Placeholder(Var B: TByteBuf): LongInt;
Begin
 BufByte(B, $E8);
 Result := B.Len;
 BufDWord(B, 0);
End;

{ ---------- Table de fixups a construire en parallele du code ---------- }

Type
 TFixupRec = Record
  CodeOfs: LongInt;   { offset (dans l'objet CODE) du disp32 a patcher }
  ModOrd: Byte;        { 1-based, index dans la table e32_impmod        }
  ProcName: String;    { nom de la procedure importee (e32_impproc)     }
 End;
 TFixupArr = Array Of TFixupRec;

Procedure AddFixup(Var Arr: TFixupArr; CodeOfs: LongInt; ModOrd: Byte; Const ProcName: String);
Begin
 SetLength(Arr, Length(Arr) + 1);
 Arr[High(Arr)].CodeOfs := CodeOfs;
 Arr[High(Arr)].ModOrd := ModOrd;
 Arr[High(Arr)].ProcName := ProcName;
End;

{ Emet un CALL vers une fonction importee et enregistre son fixup -        }
{ raccourci utilise par tous les programmes de test ci-dessous. }
Procedure EmitCall(Var Code: TByteBuf; Var Fixups: TFixupArr; ModOrd: Byte; Const ProcName: String);
Begin
 AddFixup(Fixups, AsmCallRel32Placeholder(Code), ModOrd, ProcName);
End;

{ ---------- Constructeur generique de fichier LX (2 objets : CODE / DATA) }

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
  WriteLn('ERREUR : objet CODE > 1 page (', CodeBytes.Len, ' octets) - non supporte par ce builder simplifie.');
  Halt(1);
 End;
 If DataBytes.Len > PAGE_SIZE Then Begin
  WriteLn('ERREUR : objet DATA > 1 page (', DataBytes.Len, ' octets) - non supporte par ce builder simplifie.');
  Halt(1);
 End;

 { 1) Table des noms de procedures importees (e32_impproc) - une entree    }
 {    par fixup (pas de deduplication, simplicite > taille). }
 BufInit(ImpProcBuf);
 SetLength(ProcNameOfsOf, Length(Fixups));
 For I := 0 To High(Fixups) Do Begin
  ProcNameOfsOf[I] := ImpProcBuf.Len;
  BufByte(ImpProcBuf, Length(Fixups[I].ProcName));
  BufStr(ImpProcBuf, Fixups[I].ProcName);
 End;

 { 2) Table des noms de modules importes (e32_impmod) - chaines Pascal     }
 {    sequentielles, 1 octet longueur + N octets, PAS de table d'offsets.  }
 BufInit(ImpModBuf);
 For I := 0 To High(ImpModNames) Do Begin
  BufByte(ImpModBuf, Length(ImpModNames[I]));
  BufStr(ImpModBuf, ImpModNames[I]);
 End;

 { 3) Table des enregistrements de fixup (e32_frectab) - 1 enregistrement   }
 {    IMPORTNAME/REL32 par fixup (format verifie ligne par ligne contre     }
 {    Lx_ApplyPageFixups) :                                                 }
 {    Src=8 (SrcType=REL32, SrcList=0) ; Flg=$12 (TgtType=2 IMPORTNAME |    }
 {    TgtOfs32=$10) ; SrcOfs (Word, position du disp32 DANS LA PAGE) ;      }
 {    ModOrd (1 octet, Obj16=0) ; NameOfs (4 octets, TgtOfs32=1).           }
 {    UN SEUL objet CODE, qui tient dans 1 page (page globale #1) : tous    }
 {    les fixups appartiennent donc a la page globale 1. }
 BufInit(FRec);
 For I := 0 To High(Fixups) Do Begin
  BufByte(FRec, 8);
  BufByte(FRec, $12);
  BufWord(FRec, Word(Fixups[I].CodeOfs));
  BufByte(FRec, Fixups[I].ModOrd);
  BufDWord(FRec, LongWord(ProcNameOfsOf[I]));
 End;

 { 4) Table des pages de fixup (e32_fpagetab) - TotalPages(=2)+1 = 3        }
 {    entrees de 4 octets (offset DANS e32_frectab). Page globale 1 (CODE)  }
 {    couvre TOUS les fixups [0, FRec.Len) ; page globale 2 (DATA) n'en a   }
 {    aucun [FRec.Len, FRec.Len). }
 BufInit(FPageTab);
 BufDWord(FPageTab, 0);               { debut page 1 }
 BufDWord(FPageTab, LongWord(FRec.Len)); { fin page 1 = debut page 2 }
 BufDWord(FPageTab, LongWord(FRec.Len)); { fin page 2 (vide) }

 { ---- Calcul des offsets internes a l'en-tete (relatifs a HdrOfs) ---- }
 ObjTabOfs   := 176;
 ObjMapOfs   := ObjTabOfs + 2 * 24;      { 2 objets * 24 octets }
 FPageTabOfs := ObjMapOfs + 2 * 8;       { 2 pages globales * 8 octets }
 FRecTabOfs  := FPageTabOfs + FPageTab.Len;
 ImpModOfs   := FRecTabOfs + FRec.Len;
 ImpProcOfs  := ImpModOfs + ImpModBuf.Len;
 DataPageOfs := ImpProcOfs + ImpProcBuf.Len; { relatif a HdrOfs pour l'instant }
 { ARRONDI SUR LA VALEUR ABSOLUE (DataPageOfs+HdrOfs), PAS sur la valeur    }
 { relative : SectorOffset=FileOfs/512 doit reproduire l'offset ABSOLU      }
 { exact (e32_datapage) sans perte - arrondir seulement la valeur relative  }
 { laisserait (DataPageOfs+HdrOfs) non multiple de 512 des que HdrOfs(=$40) }
 { n'est lui-meme pas un multiple de 512, tronquant silencieusement les 64  }
 { derniers octets lors de la division entiere (BOGUE REEL trouve via       }
 { verifylx.pas : la page CODE entiere retombait, a tort, dans la zone      }
 { "avant e32_datapage" et etait donc traitee comme BSS zero-fill - le      }
 { code du programme n'etait alors JAMAIS charge en memoire). }
 If (DataPageOfs + $40) Mod 512 <> 0 Then
  DataPageOfs := DataPageOfs + (512 - (DataPageOfs + $40) Mod 512);

 { 5) Table des objets (e32_objtab) - objet #1=CODE, #2=DATA+pile }
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

 { Offsets fichier REELS (absolus depuis le debut du fichier) des 2 pages - }
 { connus seulement une fois HdrOfs fixe (= $40, voir plus bas) : calcules }
 { ici en les supposant relatifs a HdrOfs, corriges par +HdrOfs ensuite.   }
 CodePageFileOfs := DataPageOfs;
 DataPageFileOfs := DataPageOfs + PAGE_SIZE; { 1 page pleine reservee pour CODE }

 { 6) Table des pages objet (e32_objmap), 8 octets/entree - SectorOffset   }
 {    exprime en unites de 512 octets (2^e32_pageshift). }
 BufInit(ObjMap);
 BufDWord(ObjMap, LongWord((CodePageFileOfs + $40) Div 512)); { +HdrOfs, voir ci-dessous }
 BufWord(ObjMap, Word(CodeBytes.Len));
 BufWord(ObjMap, 0);
 BufDWord(ObjMap, LongWord((DataPageFileOfs + $40) Div 512));
 BufWord(ObjMap, Word(DataBytes.Len));
 BufWord(ObjMap, 0);

 { 7) En-tete LX (176 octets, ordre EXACT de TLXHeader) }
 BufInit(Hdr);
 BufByte(Hdr, Ord('L')); BufByte(Hdr, Ord('X'));
 BufByte(Hdr, 0); BufByte(Hdr, 0);
 BufDWord(Hdr, 0);
 BufWord(Hdr, 2);                                  { e32_cpu = 386 }
 BufWord(Hdr, 1);                                  { e32_os = OS/2 }
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 0);
 BufDWord(Hdr, 2);                                 { e32_mpages = 2 (1 par objet) }
 BufDWord(Hdr, 1);                                 { e32_startobj }
 BufDWord(Hdr, 0);                                 { e32_eip }
 BufDWord(Hdr, 2);                                 { e32_stackobj }
 BufDWord(Hdr, LongWord(DataBytes.Len));           { e32_esp = sommet de l'objet DATA }
 BufDWord(Hdr, PAGE_SIZE);                         { e32_pagesize }
 BufDWord(Hdr, 9);                                 { e32_pageshift }
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, LongWord(ObjTabOfs));
 BufDWord(Hdr, 2);                                 { e32_objcnt }
 BufDWord(Hdr, LongWord(ObjMapOfs));
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); { enttab,dirtab,dircnt }
 BufDWord(Hdr, LongWord(FPageTabOfs));
 BufDWord(Hdr, LongWord(FRecTabOfs));
 BufDWord(Hdr, LongWord(ImpModOfs));
 BufDWord(Hdr, LongWord(Length(ImpModNames)));     { e32_impmodcnt }
 BufDWord(Hdr, LongWord(ImpProcOfs));
 BufDWord(Hdr, 0);                                 { e32_pagesum }
 BufDWord(Hdr, LongWord(DataPageOfs + $40));        { e32_datapage, ABSOLU (+HdrOfs) }
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0); BufDWord(Hdr, 0);
 BufDWord(Hdr, 0);                                 { instdemand }
 BufDWord(Hdr, 0);                                 { e32_heapsize }
 BufDWord(Hdr, LongWord(DataBytes.Len));           { e32_stacksize }
 If Hdr.Len <> 176 Then Begin
  WriteLn('ERREUR INTERNE : en-tete LX <> 176 octets (', Hdr.Len, ')'); Halt(1);
 End;

 { ---------- Assemblage final du fichier ---------- }
 { Stub MZ minimal : 'MZ', e_crlc(offset 6-7)=0 (EXIGE par NCFindExeKind),  }
 { e_lfanew (offset $3C) = position ABSOLUE de l'en-tete LX ($40, juste     }
 { apres un stub de 64 octets). }
 BufInit(FileBuf);
 BufByte(FileBuf, Ord('M')); BufByte(FileBuf, Ord('Z'));
 BufPad(FileBuf, 6);
 BufWord(FileBuf, 0);                { e_crlc = 0, offset 6-7 EXACT }
 BufPad(FileBuf, $3C);
 BufDWord(FileBuf, $40);             { e_lfanew }
 BufPad(FileBuf, $40);
 HdrOfs := FileBuf.Len;              { = $40 }

 For I := 0 To Hdr.Len - 1 Do BufByte(FileBuf, Hdr.Data[I]);
 For I := 0 To ObjTab.Len - 1 Do BufByte(FileBuf, ObjTab.Data[I]);
 For I := 0 To ObjMap.Len - 1 Do BufByte(FileBuf, ObjMap.Data[I]);
 For I := 0 To FPageTab.Len - 1 Do BufByte(FileBuf, FPageTab.Data[I]);
 For I := 0 To FRec.Len - 1 Do BufByte(FileBuf, FRec.Data[I]);
 For I := 0 To ImpModBuf.Len - 1 Do BufByte(FileBuf, ImpModBuf.Data[I]);
 For I := 0 To ImpProcBuf.Len - 1 Do BufByte(FileBuf, ImpProcBuf.Data[I]);
 BufPad(FileBuf, DataPageOfs + HdrOfs);     { -> CodePageFileOfs + HdrOfs }
 For I := 0 To CodeBytes.Len - 1 Do BufByte(FileBuf, CodeBytes.Data[I]);
 BufPad(FileBuf, DataPageFileOfs + HdrOfs); { -> pleine page reservee pour CODE }
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
{ Programme de test 1 : TCPSOCK - cycle socket/bind/listen/connect/accept/ }
{ send/recv/closesocket en boucle locale (127.0.0.1), module TCPIP32.      }
{ =====================================================================    }
Procedure BuildTcpSock(Const OutPath: String);
Const
 { Disposition de l'objet DATA (base $20000) }
 D_RESULTS   = $00; { 8 dwords = 32 octets : resultats bruts de chaque appel }
 D_ADDR      = $20; { sockaddr_in (16 octets) reutilise pour bind/connect/accept }
 D_ADDRLEN   = $30; { dword scratch, in/out pour accept() }
 D_RECVBUF   = $40; { 4 octets, recevra "HI!" }
 D_DUMMY     = $50; { dword scratch pour pcbActual de DosWrite }
 D_END       = $60;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_RESULTS + 32);                 { 8 dwords resultats, 0 initial }
 { sockaddr_in : sin_family=2(AF_INET) sin_port=0(ephemere) sin_addr=127.0.0.1 sin_zero=0 }
 BufWord(Data, 2); BufWord(Data, 0);
 BufByte(Data, 127); BufByte(Data, 0); BufByte(Data, 0); BufByte(Data, 1);
 BufPad(Data, D_ADDRLEN);
 BufDWord(Data, 16);                           { AddrLen initial = sizeof(sockaddr_in) }
 BufPad(Data, D_RECVBUF + 4);
 BufPad(Data, D_DUMMY + 4);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);

 { Table des modules importes = ['DOSCALLS','TCPIP32'] (voir BuildLXFile   }
 { plus bas) -> ModOrd 1=DOSCALLS, ModOrd 2=TCPIP32. }

 { ListenSock := socket(AF_INET=2, SOCK_STREAM=1, IPPROTO_TCP=6) }
 AsmPushImm32(Code, 6); AsmPushImm32(Code, 1); AsmPushImm32(Code, 2);
 EmitCall(Code, Fixups, 2, 'SOCKET');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 0);

 { bind(ListenSock, &Addr, 16) }
 AsmPushImm32(Code, 16);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 2, 'BIND');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 4);

 { listen(ListenSock, 5) }
 AsmPushImm32(Code, 5);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 2, 'LISTEN');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 8);

 { getsockname(ListenSock, &Addr, &AddrLen) - recupere le port ephemere     }
 { choisi par l'hote, ecrase Addr.sin_port en place (verifie le marshaling  }
 { getsockname/Lx_WriteSockAddrIn). Le 3e argument est un POINTEUR (int*)  }
 { -> pousser l'ADRESSE immediate de AddrLen, PAS sa valeur (AsmPushImm32, }
 { pas AsmPushMem32 - erreur a ne pas refaire, voir BIND/CONNECT ou le      }
 { pointeur sockaddr est deja correctement une adresse immediate). }
 AsmPushImm32(Code, DATA_BASE + D_ADDRLEN);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 2, 'GETSOCKNAME');

 { ClientSock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) }
 AsmPushImm32(Code, 6); AsmPushImm32(Code, 1); AsmPushImm32(Code, 2);
 EmitCall(Code, Fixups, 2, 'SOCKET');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 12);

 { connect(ClientSock, &Addr, 16) - Addr contient deja le port ephemere     }
 { reel (ecrit par GETSOCKNAME ci-dessus) et 127.0.0.1 }
 AsmPushImm32(Code, 16);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 2, 'CONNECT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 16);

 { ServerSock := accept(ListenSock, NULL, NULL) }
 AsmPushImm32(Code, 0); AsmPushImm32(Code, 0);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 2, 'ACCEPT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 20);

 { send(ClientSock, "HI!", 3, 0) - reutilise Addr comme tampon source (ses  }
 { 2 premiers octets sin_family=$02,$00 ne servent pas ici, on ecrit "HI!"  }
 { directement dans RECVBUF AVANT envoi ? non : on ecrit un tampon dedie    }
 { au debut de la zone ADDR, qui n'est plus necessaire a ce stade. }
 AsmMovMem8Imm8(Code, DATA_BASE + D_ADDR + 0, Ord('H'));
 AsmMovMem8Imm8(Code, DATA_BASE + D_ADDR + 1, Ord('I'));
 AsmMovMem8Imm8(Code, DATA_BASE + D_ADDR + 2, Ord('!'));
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 3);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 2, 'SEND');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 24);

 { recv(ServerSock, &RecvBuf, 4, 0) }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_RECVBUF);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 20);
 EmitCall(Code, Fixups, 2, 'RECV');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 28);

 { closesocket x3 }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 2, 'CLOSESOCKET');
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 20);
 EmitCall(Code, Fixups, 2, 'CLOSESOCKET');
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 2, 'CLOSESOCKET');

 { DosWrite(1, &RecvBuf, 3, &Dummy) - affiche "HI!" dans le terminal si     }
 { recv() a reellement recu les octets envoyes via le vrai aller-retour     }
 { TCPIP32->Winsock. }
 AsmPushImm32(Code, DATA_BASE + D_DUMMY);
 AsmPushImm32(Code, 3);
 AsmPushImm32(Code, DATA_BASE + D_RECVBUF);
 AsmPushImm32(Code, 1);
 EmitCall(Code, Fixups, 1, 'DosWrite');

 { DosExit(0, recv_return_value) - le code de sortie EST directement le     }
 { nombre d'octets recus (3 = succes total, visible tel quel via           }
 { LX_HaltReason "DosExit(action=0, code=3)"). }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 28);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['DOSCALLS', 'TCPIP32']);
End;

{ =====================================================================    }
{ Programme de test 2 : TCPNAME - gethostbyname/getservbyname/             }
{ getservbyport (resolution reelle de noms, marshaling de structures       }
{ pointees hostent/servent en memoire invite). }
{ =====================================================================    }
Procedure BuildTcpName(Const OutPath: String);
Const
 D_HOSTSTR   = $00;  { "one.one.one.one"+0 = 16 octets (Cloudflare DNS,     }
                      { adresse publique stable 1.0.0.1/1.1.1.1 - meme      }
                      { choix que le harnais os2tcptest.pas deja verifie }
 D_HTTPSTR   = $10;  { "http"+0 = 5 octets }
 D_TCPSTR    = $18;  { "tcp"+0 = 4 octets }
 D_HE_PTR    = $20;  { dword : pointeur hostent* retourne }
 D_IP_COPY   = $24;  { 4 octets : copie de h_addr_list[0]^ (l'IP resolue) }
 D_SE1_PTR   = $28;  { dword : servent* de getservbyname }
 D_SE1_PORT  = $2C;  { dword : s_port copie (sign-extended) de getservbyname }
 D_SE2_PTR   = $30;  { dword : servent* de getservbyport }
 D_END       = $40;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufStr(Data, 'one.one.one.one'); BufByte(Data, 0);
 BufPad(Data, D_HTTPSTR);
 BufStr(Data, 'http'); BufByte(Data, 0);
 BufPad(Data, D_TCPSTR);
 BufStr(Data, 'tcp'); BufByte(Data, 0);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);

 { Table des modules importes = ['TCPIP32','DOSCALLS'] (voir BuildLXFile   }
 { plus bas) -> ModOrd 1=TCPIP32, ModOrd 2=DOSCALLS. }

 { he := gethostbyname("one.one.one.one") }
 AsmPushImm32(Code, DATA_BASE + D_HOSTSTR);
 EmitCall(Code, Fixups, 1, 'GETHOSTBYNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_HE_PTR);

 { Deref manuel (pas de ModRM base+index dans notre sous-ensemble           }
 { d'encodeurs) : he^.h_addr_list est a he+12 (voir layout TMdbcHostEnt      }
 { marshale par Lx_DoDosCall : h_name@0 h_aliases@4 h_addrtype@8 h_length@10}
 { h_addr_list@12), et h_addr_list pointe lui-meme vers une liste dont le    }
 { 1er element (@+0) est l'adresse de l'IP effective. Comme l'adresse de    }
 { HE_PTR est connue seulement a l'EXECUTION (allocateur bump LX_HeapNext), }
 { il faut un VRAI dereferencement en 2 temps : EAX := [HE_PTR] (= he)      }
 { n'est PAS suffisant avec notre encodeur "disp32 only" (pas de ModRM      }
 { [EAX+12]) - on utilise donc une sequence 8B 05 (mov eax,[HE_PTR]) suivie }
 { d'un ModRM [EAX+disp8] encode a la main (8B 40 0C = MOV EAX,[EAX+12]).   }
 AsmMovEaxMem32(Code, DATA_BASE + D_HE_PTR);        { EAX := he }
 BufByte(Code, $8B); BufByte(Code, $40); BufByte(Code, 12); { MOV EAX,[EAX+12] = h_addr_list }
 BufByte(Code, $8B); BufByte(Code, $00);                     { MOV EAX,[EAX]    = h_addr_list[0] (ptr IP) }
 BufByte(Code, $8B); BufByte(Code, $00);                     { MOV EAX,[EAX]    = *ptr = l'IP elle-meme }
 AsmMovMem32Eax(Code, DATA_BASE + D_IP_COPY);

 { se1 := getservbyname("http", "tcp") }
 AsmPushImm32(Code, DATA_BASE + D_TCPSTR);
 AsmPushImm32(Code, DATA_BASE + D_HTTPSTR);
 EmitCall(Code, Fixups, 1, 'GETSERVBYNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_SE1_PTR);
 { se1^.s_port (Word @ offset 8 de TMdbcServEnt : s_name@0 s_aliases@4      }
 { s_port@8 s_proto@10) - copie de 4 octets a partir de cette adresse       }
 { (lecture volontairement large : les 2 octets de poids fort recus sont    }
 { les 2 premiers octets du pointeur s_proto qui suit immediatement a +10,  }
 { sans consequence puisque seul le mot de poids faible (s_port) est        }
 { interprete lors de la verification). }
 AsmMovEaxMem32(Code, DATA_BASE + D_SE1_PTR);
 BufByte(Code, $8B); BufByte(Code, $40); BufByte(Code, 8); { MOV EAX,[EAX+8] }
 AsmMovMem32Eax(Code, DATA_BASE + D_SE1_PORT);

 { se2 := getservbyport(htons(80)=0x5000, "tcp") - htons(80) calcule a la   }
 { compilation (80=$0050 -> octets inverses $5000), aucun appel htons()     }
 { necessaire. }
 AsmPushImm32(Code, DATA_BASE + D_TCPSTR);
 AsmPushImm32(Code, $00005000);
 EmitCall(Code, Fixups, 1, 'GETSERVBYPORT');
 AsmMovMem32Eax(Code, DATA_BASE + D_SE2_PTR);

 { DosExit(0, IP resolue en entier, 4 octets bruts [a,b,c,d] relus comme un }
 { LongInt little-endian = a + b*256 + c*65536 + d*16777216) - pour         }
 { 1.0.0.1 ou 1.1.1.1 (Cloudflare, adresse publique stable), l'octet de     }
 { poids FORT du code de sortie (= le DERNIER octet reseau de l'IP) vaut    }
 { toujours 1 dans les 2 cas - signal simple a verifier via LX_HaltReason   }
 { (rend 16777217 en decimal pour 1.0.0.1) ou via LXDUMP pour les octets    }
 { bruts. }
 AsmPushMem32(Code, DATA_BASE + D_IP_COPY);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['TCPIP32', 'DOSCALLS']);
End;

{ =====================================================================    }
{ Programme de test 3 : TCPOPT - getpeername/shutdown/ioctl(FIONBIO)/      }
{ setsockopt+getsockopt(SO_REUSEADDR)/gethostbyaddr/select - complete la   }
{ couverture des 20 fonctions MPTS (avec TCPSOCK+TCPNAME) a l'exception    }
{ des seuls ALIAS de nom (SOCLOSE=meme gestionnaire que CLOSESOCKET,        }
{ TCP32DLL/SO32DLL/TCPIPDLL=meme gestionnaire que TCPIP32), deliberement   }
{ non redondes ici. }
{ =====================================================================    }
Procedure BuildTcpOpt(Const OutPath: String);
Const
 D_RESULTS    = $00;  { 13 dwords = 52 octets : resultats bruts }
 D_ADDR       = $38;  { sockaddr_in scratch (16), reutilise bind/connect/getpeername }
 D_ADDRLEN    = $48;  { dword scratch, in/out namelen }
 D_RAWIP      = $4C;  { 4 octets : 127.0.0.1 brut (entree gethostbyaddr) }
 D_NONBLOCK   = $50;  { dword : valeur FIONBIO (in/out) }
 D_OPTVAL     = $54;  { dword : valeur SO_REUSEADDR a ecrire }
 D_OPTOUT     = $58;  { dword : valeur SO_REUSEADDR relue }
 D_OPTOUTLEN  = $5C;  { dword : longueur in/out de getsockopt }
 D_FDSET      = $60;  { 8 octets : fd_count(4)+fd_array[0](4) }
 D_TIMEVAL    = $68;  { 8 octets : tv_sec(4)=1 + tv_usec(4)=0 }
 D_END        = $70;
 SOL_SOCKET    = $0000FFFF;
 SO_REUSEADDR  = $00000004;
 FIONBIO       = LongWord($8004667E);
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_RESULTS + 52);
 BufWord(Data, 2); BufWord(Data, 0);                 { sockaddr_in : family=2 port=0 }
 BufByte(Data, 127); BufByte(Data, 0); BufByte(Data, 0); BufByte(Data, 1); { 127.0.0.1 }
 BufPad(Data, D_ADDRLEN);
 BufDWord(Data, 16);
 BufByte(Data, 127); BufByte(Data, 0); BufByte(Data, 0); BufByte(Data, 1); { D_RAWIP }
 BufPad(Data, D_NONBLOCK); BufDWord(Data, 1);
 BufPad(Data, D_OPTVAL); BufDWord(Data, 1);
 BufPad(Data, D_OPTOUT); BufDWord(Data, 0);
 BufPad(Data, D_OPTOUTLEN); BufDWord(Data, 4);
 BufPad(Data, D_FDSET); BufDWord(Data, 1); BufDWord(Data, 0); { fd_count=1, fd_array[0]=rempli au vol }
 BufPad(Data, D_TIMEVAL); BufDWord(Data, 1); BufDWord(Data, 0); { tv_sec=1 tv_usec=0 }
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);
 { Table des modules importes = ['TCPIP32','DOSCALLS'] -> ModOrd 1=TCPIP32, }
 { ModOrd 2=DOSCALLS (meme convention que BuildTcpName). }

 { ListenSock := socket(2,1,6) ; bind ; listen ; getsockname (meme          }
 { sequence deja verifiee dans TCPSOCK ci-dessus). }
 AsmPushImm32(Code, 6); AsmPushImm32(Code, 1); AsmPushImm32(Code, 2);
 EmitCall(Code, Fixups, 1, 'SOCKET');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 0);

 AsmPushImm32(Code, 16); AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'BIND');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 4);

 AsmPushImm32(Code, 5); AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'LISTEN');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 8);

 AsmPushImm32(Code, DATA_BASE + D_ADDRLEN);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'GETSOCKNAME');

 { ClientSock := socket(2,1,6) ; connect ; ServerSock := accept(NULL,NULL) }
 AsmPushImm32(Code, 6); AsmPushImm32(Code, 1); AsmPushImm32(Code, 2);
 EmitCall(Code, Fixups, 1, 'SOCKET');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 12);

 AsmPushImm32(Code, 16); AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 1, 'CONNECT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 16);

 AsmPushImm32(Code, 0); AsmPushImm32(Code, 0);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'ACCEPT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 20);

 { getpeername(ClientSock, &Addr, &AddrLen) - re-ecrit AddrLen=16 avant     }
 { l'appel (hygiene explicite, meme si deja 16 a ce stade - jamais supposer}
 { l'etat residuel d'une variable reutilisee sans le reaffirmer). }
 AsmMovEaxImm32(Code, 16);
 AsmMovMem32Eax(Code, DATA_BASE + D_ADDRLEN);
 AsmPushImm32(Code, DATA_BASE + D_ADDRLEN);
 AsmPushImm32(Code, DATA_BASE + D_ADDR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 1, 'GETPEERNAME');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 24);

 { shutdown(ClientSock, 2 /*SD_BOTH*/) }
 AsmPushImm32(Code, 2);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 1, 'SHUTDOWN');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 28);

 { ioctl(ListenSock, FIONBIO, &NonBlock) - NonBlock deja initialise a 1     }
 { dans les donnees (mode non bloquant demande). }
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_NONBLOCK);
 AsmPushImm32(Code, LongWord(FIONBIO));
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'IOCTL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 32);

 { setsockopt(ListenSock, SOL_SOCKET, SO_REUSEADDR, &OptVal(=1), 4) }
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_OPTVAL);
 AsmPushImm32(Code, SO_REUSEADDR);
 AsmPushImm32(Code, LongWord(SOL_SOCKET));
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'SETSOCKOPT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 36);

 { getsockopt(ListenSock, SOL_SOCKET, SO_REUSEADDR, &OptOut, &OptOutLen) }
 AsmPushImm32(Code, DATA_BASE + D_OPTOUTLEN);
 AsmPushImm32(Code, DATA_BASE + D_OPTOUT);
 AsmPushImm32(Code, SO_REUSEADDR);
 AsmPushImm32(Code, LongWord(SOL_SOCKET));
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'GETSOCKOPT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 40);

 { gethostbyaddr(&RawIP(127.0.0.1), 4, AF_INET=2) }
 AsmPushImm32(Code, 2);
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_RAWIP);
 EmitCall(Code, Fixups, 1, 'GETHOSTBYADDR');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 44);

 { select(0, &FdSet[count=1,array0=ServerSock], NULL, NULL, &TimeVal)      }
 { - ServerSock ecrit dans fd_array[0] juste avant l'appel (valeur connue   }
 { seulement a l'execution, voir accept() ci-dessus). }
 AsmMovEaxMem32(Code, DATA_BASE + D_RESULTS + 20);
 AsmMovMem32Eax(Code, DATA_BASE + D_FDSET + 4);
 AsmPushImm32(Code, DATA_BASE + D_TIMEVAL);
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, DATA_BASE + D_FDSET);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'SELECT');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + 48);

 { closesocket x3 }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 12);
 EmitCall(Code, Fixups, 1, 'CLOSESOCKET');
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 20);
 EmitCall(Code, Fixups, 1, 'CLOSESOCKET');
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + 0);
 EmitCall(Code, Fixups, 1, 'CLOSESOCKET');

 { DosExit(0, OptOut) - la valeur SO_REUSEADDR relue par getsockopt APRES  }
 { un aller-retour complet setsockopt->getsockopt : 1 = succes total (la    }
 { valeur ecrite est bien celle relue), signal plus deterministe que        }
 { select() (dont le resultat 0/1 depend legitimement de l'etat reel du     }
 { socket - stocke neanmoins dans D_RESULTS+48 pour inspection future). }
 AsmPushMem32(Code, DATA_BASE + D_OPTOUT);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['TCPIP32', 'DOSCALLS']);
End;

{ =====================================================================    }
{ Programme de test 4 : RPCTEST - IBM TCP/IP, client ONC/Sun RPC            }
{ (RPC32DLL.DLL, 2026-10-11, demande explicite - 11 fonctions) : exerce     }
{ callrpc/clnt_create/clnt_control(x3)/clnt_call/clnt_geterr/clnt_perrno/   }
{ clnt_sperrno/clnt_sperror/clnt_freeres/clnt_destroy contre le PORTMAPPER  }
{ (programme RPC 100000, le service RPC le plus basique qui soit) de        }
{ 127.0.0.1 - AUCUNE dependance envers un service RPC applicatif tiers,     }
{ juste le portmapper/rpcbind lui-meme. Sur un hote Windows typique (SANS   }
{ portmapper par defaut), le resultat HONNETE attendu est RPC_TIMEDOUT(5)   }
{ sur callrpc/clnt_call - PAS un bogue, voir README_MPTS.txt. }
Procedure BuildRpcTest(Const OutPath: String);
Const
 D_RESULTS   = $00; { 10 dwords : R0..R9 }
 D_HOSTSTR   = $30; { "127.0.0.1"+0 }
 D_PROTOSTR  = $40; { "udp"+0 }
 D_ADDRBUF   = $50; { 16 octets : sockaddr_in rempli par CLGET_SERVER_ADDR }
 D_TOBUF     = $60; { 8 octets : struct timeval (tv_sec/tv_usec) }
 D_ERRBUF    = $70; { 16 octets : struct rpc_err (seul re_status a un sens) }
 D_PREFIXSTR = $80; { "TEST"+0 }
 D_END       = $90;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_RESULTS + 40);
 BufStr(Data, '127.0.0.1'); BufByte(Data, 0);
 BufPad(Data, D_PROTOSTR);
 BufStr(Data, 'udp'); BufByte(Data, 0);
 BufPad(Data, D_ADDRBUF + 16);
 BufDWord(Data, 3); BufDWord(Data, 0); { D_TOBUF : tv_sec=3 tv_usec=0 }
 BufPad(Data, D_ERRBUF + 16);
 BufStr(Data, 'TEST'); BufByte(Data, 0);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);
 { Modules importes = ['RPC32DLL','DOSCALLS'] -> ModOrd 1=RPC32DLL, 2=DOSCALLS}

 { R0 := callrpc("127.0.0.1", 100000, 2, 0/*PMAPPROC_NULL*/, 0,0,0,0) }
 AsmPushImm32(Code, 0); AsmPushImm32(Code, 0); AsmPushImm32(Code, 0); AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);     { procnum = 0, PMAPPROC_NULL }
 AsmPushImm32(Code, 2);     { versnum }
 AsmPushImm32(Code, 100000); { prognum = PMAPPROG }
 AsmPushImm32(Code, DATA_BASE + D_HOSTSTR);
 EmitCall(Code, Fixups, 1, 'CALLRPC');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $00);

 { R1 := clnt_create("127.0.0.1", 100000, 2, "udp") }
 AsmPushImm32(Code, DATA_BASE + D_PROTOSTR);
 AsmPushImm32(Code, 2);
 AsmPushImm32(Code, 100000);
 AsmPushImm32(Code, DATA_BASE + D_HOSTSTR);
 EmitCall(Code, Fixups, 1, 'CLNT_CREATE');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $04);

 { R2 := clnt_control(R1, 1/*CLGET_SERVER_ADDR*/, &D_ADDRBUF) }
 AsmPushImm32(Code, DATA_BASE + D_ADDRBUF);
 AsmPushImm32(Code, 1);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_CONTROL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $08);

 { R3 := clnt_control(R1, 4/*CLSET_TIMEOUT*/, &D_TOBUF) - D_TOBUF deja       }
 { prerempli tv_sec=3/tv_usec=0 dans les donnees du fichier. }
 AsmPushImm32(Code, DATA_BASE + D_TOBUF);
 AsmPushImm32(Code, 4);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_CONTROL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $0C);

 { R4 := clnt_control(R1, 5/*CLGET_TIMEOUT*/, &D_TOBUF) - ecrase D_TOBUF    }
 { avec la valeur RELUE : doit redonner EXACTEMENT 3/0 (aller-retour pur). }
 AsmPushImm32(Code, DATA_BASE + D_TOBUF);
 AsmPushImm32(Code, 5);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_CONTROL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $10);

 { R5 := clnt_call(R1, 0/*PMAPPROC_NULL*/, 0,0,0,0, tv_sec=3, tv_usec=0) }
 AsmPushImm32(Code, 0); AsmPushImm32(Code, 3);
 AsmPushImm32(Code, 0); AsmPushImm32(Code, 0); AsmPushImm32(Code, 0); AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_CALL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $14);

 { clnt_geterr(R1, &D_ERRBUF) puis R6 := [D_ERRBUF] (re_status) - doit      }
 { redonner EXACTEMENT R5 (aller-retour pur, meme donnee relue 2 fois). }
 AsmPushImm32(Code, DATA_BASE + D_ERRBUF);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_GETERR');
 AsmMovEaxMem32(Code, DATA_BASE + D_ERRBUF);
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $18);

 { clnt_perrno(R5) - imprime DIRECTEMENT dans le Terminal (cote emulateur,  }
 { aucun DosWrite necessaire ici) le texte correspondant a R5 ("RPC:        }
 { Success" ou "RPC: Timed out" etc. - voir Os2Rpc_StatusMsg). }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $14);
 EmitCall(Code, Fixups, 1, 'CLNT_PERRNO');

 { R7 := clnt_sperrno(R5) - pointeur invite (chaine allouee dans le tas),   }
 { inspectable via LXDUMP, non imprime ici (longueur variable inconnue a    }
 { la construction - voir README). }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $14);
 EmitCall(Code, Fixups, 1, 'CLNT_SPERRNO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $1C);

 { R8 := clnt_sperror(R1, "TEST") - idem, pointeur invite stocke, non       }
 { imprime. }
 AsmPushImm32(Code, DATA_BASE + D_PREFIXSTR);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_SPERROR');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $20);

 { R9 := clnt_freeres(R1, 0, 0) - doit TOUJOURS valoir 1 (TRUE), voir la    }
 { disclosure dans DEVENV.PAS. }
 AsmPushImm32(Code, 0); AsmPushImm32(Code, 0);
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_FREERES');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $24);

 { clnt_destroy(R1) }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $04);
 EmitCall(Code, Fixups, 1, 'CLNT_DESTROY');

 { DosExit(0, R5) - le VRAI clnt_stat de l'appel PMAPPROC_NULL : 0          }
 { (RPC_SUCCESS) si un portmapper repond reellement sur cette machine, 5    }
 { (RPC_TIMEDOUT) sinon - LES DEUX sont des resultats honnetes attendus,    }
 { voir README_MPTS.txt. }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $14);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['RPC32DLL', 'DOSCALLS']);
End;

{ =====================================================================    }
{ Programme de test 5 : LANTEST - LAN (NETAPI.DLL, 2026-10-11, demande     }
{ explicite - 33 fonctions "LAN Server") : exerce les 11 fonctions          }
{ LECTURE SEULE reellement pontees vers le vrai netapi32.dll de la          }
{ machine hote (NetWkstaGetInfo/NetServerGetInfo/NetShareEnum/              }
{ NetShareGetInfo/NetUserEnum/NetUserGetInfo/NetGroupEnum/                  }
{ NetGroupGetInfo/NetSessionEnum/NetUseEnum/NetRemoteTOD) PUIS 2 des 22     }
{ fonctions MUTATRICES deliberement REFUSEES (NetShareDel, NetUserAdd) -    }
{ preuve directe que le garde-fou de securite fonctionne (ERROR_NOT_        }
{ SUPPORTED=50 a chaque fois, JAMAIS une fausse reussite qui laisserait     }
{ croire qu'un partage/utilisateur reel a ete modifie sur la machine hote). }
{ =====================================================================    }
Procedure BuildLanTest(Const OutPath: String);
Const
 D_RESULTS   = $000; { 16 dwords : R0..R15 }
 D_NEEDED    = $040; { scratch pcBytesNeeded, reutilise entre appels }
 D_READ      = $044; { scratch pcEntriesRead }
 D_TOTAL     = $048; { scratch pcTotalEntries }
 D_WKSTABUF  = $050; { 20 octets }
 D_SERVERBUF = $070; { 8 octets }
 D_SHAREBUF  = $080; { 240 octets = 20 entrees * 12 }
 D_SHAREGET  = $170; { 12 octets }
 D_USERBUF   = $180; { 200 octets = 50 entrees * 4 }
 D_USERGET   = $250; { 4 octets }
 D_GROUPBUF  = $260; { 200 octets }
 D_GROUPGET  = $330; { 4 octets }
 D_SESSBUF   = $340; { 200 octets }
 D_USEBUF    = $420; { 160 octets = 20 entrees * 8 }
 D_TODBUF    = $4C0; { 48 octets }
 D_IPCSTR    = $4F0; { "IPC$"+0 - partage administratif quasi universel }
 D_END       = $500;
Var
 Code, Data: TByteBuf;
 Fixups: TFixupArr;
Begin
 BufInit(Data);
 BufPad(Data, D_END); { tout le reste est du scratch/sortie, zero-initialise }
 BufPad(Data, D_IPCSTR);
 BufStr(Data, 'IPC$'); BufByte(Data, 0);
 BufPad(Data, D_END);

 BufInit(Code);
 SetLength(Fixups, 0);
 { Modules importes = ['NETAPI','DOSCALLS'] -> ModOrd 1=NETAPI, 2=DOSCALLS }

 { R0 := NetWkstaGetInfo(0, &D_WKSTABUF, 20, &D_NEEDED) }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 20);
 AsmPushImm32(Code, DATA_BASE + D_WKSTABUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETWKSTAGETINFO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $00);

 { R1 := NetServerGetInfo(0, &D_SERVERBUF, 8, &D_NEEDED) }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 8);
 AsmPushImm32(Code, DATA_BASE + D_SERVERBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETSERVERGETINFO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $04);

 { R2 := NetShareEnum(0, &D_SHAREBUF, 240, &D_READ, &D_TOTAL) ; R3 := [D_READ] }
 AsmPushImm32(Code, DATA_BASE + D_TOTAL);
 AsmPushImm32(Code, DATA_BASE + D_READ);
 AsmPushImm32(Code, 240);
 AsmPushImm32(Code, DATA_BASE + D_SHAREBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETSHAREENUM');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $08);
 AsmMovEaxMem32(Code, DATA_BASE + D_READ);
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $0C);

 { R4 := NetShareGetInfo(0, "IPC$", &D_SHAREGET, 12, &D_NEEDED) }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 12);
 AsmPushImm32(Code, DATA_BASE + D_SHAREGET);
 AsmPushImm32(Code, DATA_BASE + D_IPCSTR);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETSHAREGETINFO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $10);

 { R5 := NetUserEnum(0, &D_USERBUF, 200, &D_READ, &D_TOTAL) ; R6 := [D_READ] }
 AsmPushImm32(Code, DATA_BASE + D_TOTAL);
 AsmPushImm32(Code, DATA_BASE + D_READ);
 AsmPushImm32(Code, 200);
 AsmPushImm32(Code, DATA_BASE + D_USERBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETUSERENUM');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $14);
 AsmMovEaxMem32(Code, DATA_BASE + D_READ);
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $18);

 { R7 := NetUserGetInfo(0, [D_USERBUF+0] (1er nom enumere), &D_USERGET, 4,  }
 { &D_NEEDED) - reutilise directement le pointeur invite deja ecrit par     }
 { NETUSERENUM ci-dessus (pas besoin de connaitre un nom d'utilisateur a    }
 { la construction). }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_USERGET);
 AsmPushMem32(Code, DATA_BASE + D_USERBUF + 0);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETUSERGETINFO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $1C);

 { R8 := NetGroupEnum(0, &D_GROUPBUF, 200, &D_READ, &D_TOTAL) ; R9 := [D_READ] }
 AsmPushImm32(Code, DATA_BASE + D_TOTAL);
 AsmPushImm32(Code, DATA_BASE + D_READ);
 AsmPushImm32(Code, 200);
 AsmPushImm32(Code, DATA_BASE + D_GROUPBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETGROUPENUM');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $20);
 AsmMovEaxMem32(Code, DATA_BASE + D_READ);
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $24);

 { R10 := NetGroupGetInfo(0, [D_GROUPBUF+0], &D_GROUPGET, 4, &D_NEEDED) }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 4);
 AsmPushImm32(Code, DATA_BASE + D_GROUPGET);
 AsmPushMem32(Code, DATA_BASE + D_GROUPBUF + 0);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETGROUPGETINFO');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $28);

 { R11 := NetSessionEnum(0, &D_SESSBUF, 200, &D_READ, &D_TOTAL) - peut       }
 { honnetement echouer ERROR_ACCESS_DENIED(5) sans privilege eleve. }
 AsmPushImm32(Code, DATA_BASE + D_TOTAL);
 AsmPushImm32(Code, DATA_BASE + D_READ);
 AsmPushImm32(Code, 200);
 AsmPushImm32(Code, DATA_BASE + D_SESSBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETSESSIONENUM');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $2C);

 { R12 := NetUseEnum(0, &D_USEBUF, 160, &D_READ, &D_TOTAL) }
 AsmPushImm32(Code, DATA_BASE + D_TOTAL);
 AsmPushImm32(Code, DATA_BASE + D_READ);
 AsmPushImm32(Code, 160);
 AsmPushImm32(Code, DATA_BASE + D_USEBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETUSEENUM');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $30);

 { R13 := NetRemoteTOD(0, &D_TODBUF, 48, &D_NEEDED) }
 AsmPushImm32(Code, DATA_BASE + D_NEEDED);
 AsmPushImm32(Code, 48);
 AsmPushImm32(Code, DATA_BASE + D_TODBUF);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETREMOTETOD');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $34);

 { R14 := NetShareDel(0, "IPC$", 0) - MUTATEUR REFUSE : doit TOUJOURS       }
 { valoir 50 (ERROR_NOT_SUPPORTED), quel que soit l'etat reel de la         }
 { machine hote - JAMAIS de suppression reelle de partage. }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, DATA_BASE + D_IPCSTR);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETSHAREDEL');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $38);

 { R15 := NetUserAdd(0, 0, 0, 0) - MUTATEUR REFUSE : doit TOUJOURS valoir   }
 { 50 (ERROR_NOT_SUPPORTED) - JAMAIS de creation reelle de compte           }
 { utilisateur sur la machine hote. SIGNAL PRINCIPAL de ce test (voir       }
 { DosExit ci-dessous) : contrairement aux 11 appels reels precedents       }
 { (dont le resultat depend legitimement de l'etat de la machine hote),     }
 { celui-ci est garanti IDENTIQUE partout - la preuve la plus simple et la  }
 { plus deterministe que le garde-fou de securite fonctionne reellement. }
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 1, 'NETUSERADD');
 AsmMovMem32Eax(Code, DATA_BASE + D_RESULTS + $3C);

 { DosExit(0, R15) - doit TOUJOURS valoir 50. }
 AsmPushMem32(Code, DATA_BASE + D_RESULTS + $3C);
 AsmPushImm32(Code, 0);
 EmitCall(Code, Fixups, 2, 'DosExit');

 BuildLXFile(OutPath, Code, Data, Fixups, ['NETAPI', 'DOSCALLS']);
End;

Var
 OutDir: String;
Begin
 If ParamCount >= 1 Then OutDir := ParamStr(1) Else OutDir := '.';
 BuildTcpSock(OutDir + '\TCPSOCK.EXE');
 BuildTcpName(OutDir + '\TCPNAME.EXE');
 BuildTcpOpt(OutDir + '\TCPOPT.EXE');
 BuildRpcTest(OutDir + '\RPCTEST.EXE');
 BuildLanTest(OutDir + '\LANTEST.EXE');
 WriteLn('Termine.');
End.
