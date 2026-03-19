{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

{ TODO - Liste des 25 points a implementer pour l'emulateur DPMI :

  1.  Creer le fichier d'echange de 16 Mo (EMUDPMI.$$$) servant de
      memoire lineaire pour l'espace d'adressage en mode protege,
      similaire au SwapFileMemory d'EMU8086.PAS mais avec un espace
      de 16 777 216 octets (16 Mo) au lieu de 1 Mo.

  2.  Definir les registres 32 bits du 80386 : EAX, EBX, ECX, EDX,
      ESI, EDI, EBP, ESP avec un acces aux sous-parties 16 bits
      (AX, BX, ...) et 8 bits (AL, AH, ...) par des records variants.

  3.  Definir les registres de segment en mode protege : CS, DS, ES,
      SS, FS, GS comme des selecteurs (16 bits) et non comme des
      adresses reelles de paragraphe.

  4.  Implementer la table des descripteurs (LDT - Local Descriptor
      Table) contenant au minimum 256 entrees, chaque descripteur
      stockant : adresse de base 32 bits, limite, type d'acces, et
      granularite (bit G pour pages 4 Ko).

  5.  Implementer la conversion d'adresse selecteur:offset en adresse
      lineaire 32 bits a l'aide de la LDT, en remplacement de la
      formule segment*16+offset du mode reel.

  6.  Implementer les procedures ReadByte/ReadWord/ReadDWord et
      WriteByte/WriteWord/WriteDWord pour l'acces a la memoire
      lineaire 32 bits via le fichier de 16 Mo.

  7.  Implementer la pile 32 bits (PUSH/POP en mode 32 bits) avec
      ESP et SS pouvant adresser tout l'espace 16 Mo.

  8.  Implementer les instructions de transfert de donnees 32 bits :
      MOV reg32,reg32 / MOV reg32,imm32 / MOV reg32,[mem] /
      MOV [mem],reg32 avec le prefixe de taille d'operande (66h).

  9.  Implementer les instructions arithmetiques 32 bits : ADD, SUB,
      ADC, SBB, CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des
      operandes 32 bits avec mise a jour correcte des drapeaux
      (CF, ZF, SF, OF, AF, PF).

  10. Implementer les instructions logiques et de decalage 32 bits :
      AND, OR, XOR, NOT, TEST, SHL, SHR, SAR, ROL, ROR, RCL, RCR
      sur des operandes 32 bits.

  11. Implementer les instructions de chaines 32 bits : MOVSD, STOSD,
      LODSD, CMPSD, SCASD ainsi que le prefixe REP/REPE/REPNE
      utilisant ECX comme compteur.

  12. Implementer les instructions de saut conditionnel 32 bits (Jcc
      near avec deplacement 32 bits, prefixe 0Fh) et les sauts
      inconditionnels JMP near/far en mode protege.

  13. Implementer CALL near/far et RET/RETF en mode protege 32 bits,
      avec empilement/depilement de EIP et CS sur la pile 32 bits.

  14. Implementer les prefixes de remplacement de segment (ES:, CS:,
      SS:, DS:, FS:, GS:) et le prefixe de taille d'adresse (67h).

  15. Implementer l'INT 31h fonction 0000h (Allocate LDT Descriptors)
      pour allouer des selecteurs dans la LDT.

  16. Implementer l'INT 31h fonction 0001h (Free LDT Descriptor) pour
      liberer un selecteur precedemment alloue.

  17. Implementer l'INT 31h fonctions 0007h/0008h (Set/Get Segment
      Base Address) pour modifier et lire l'adresse de base d'un
      descripteur.

  18. Implementer l'INT 31h fonctions 0009h/000Ah (Set/Get Segment
      Limit et Set/Get Descriptor Access Rights) pour modifier la
      limite et les droits d'acces d'un descripteur.

  19. Implementer l'INT 31h fonction 0501h (Allocate Memory Block)
      pour allouer un bloc de memoire lineaire dans l'espace de
      16 Mo, retournant l'adresse lineaire et un handle.

  20. Implementer l'INT 31h fonction 0502h (Free Memory Block) et
      la fonction 0503h (Resize Memory Block) pour liberer et
      redimensionner un bloc memoire.

  21. Implementer l'INT 21h (services DOS) en mode protege DPMI :
      les appels DOS classiques ($02, $09, $3C-$40, $4Ch, ...) en
      traduisant les adresses selecteur:offset en adresses lineaires
      pour l'acces aux tampons.

  22. Implementer le chargeur de programme binaire plat (flat binary)
      qui charge un fichier executable dans la memoire lineaire,
      initialise les selecteurs CS/DS/ES/SS avec des descripteurs
      couvrant tout l'espace 16 Mo, et fixe EIP au point d'entree.

  23. Implementer la boucle principale d'execution (Procedure Run)
      avec decodage du flux d'instructions, gestion des prefixes
      (66h, 67h, segments, REP) et dispatch vers les procedures
      d'emulation de chaque opcode.

  24. Implementer les options de ligne de commande : /DEBUG pour le
      mode debogage avec affichage de l'etat des registres a chaque
      instruction, /VERBOSE pour les messages informatifs, et
      /READONLY pour interdire les ecritures sur disque.

  25. Implementer la procedure de nettoyage (Procedure Done) qui
      ferme et supprime le fichier d'echange de 16 Mo, et libere
      toutes les ressources (handles de fichiers ouverts).
}

Program EMUDPMI;

{$A-}

Uses DOS;

Const
  { TODO 1 : Fichier d'echange de 16 Mo pour la memoire lineaire }
 SwapFileMemory='EMUDPMI.$$$';

  { Taille totale de la memoire lineaire : 16 Mo }
 MemorySize=16*1024*1024;  { 16 777 216 octets }

  { Taille du tampon de nettoyage pour l'initialisation }
 ClearBufferSize=1024;

  { Nombre de blocs de 1 Ko pour couvrir 16 Mo }
 ClearBlockCount=MemorySize div ClearBufferSize;  { 16384 }

Type
  { TODO 2 : Registres 32 bits du 80386 }
 LongRec=Record
  Lo,Hi:Word;
 End;

Var
  { TODO 1 : Fichier d'echange }
 Memory:File;
 ClrBuffer:Array[0..ClearBufferSize-1]of Byte;

  { TODO 2 : Registres generaux 32 bits du 80386 avec acces aux
    sous-parties 16 bits (AX, BX, ...) et 8 bits (AL, AH, ...) }
 Regs:Record Case Byte of
  0:(EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI:LongInt);
  1:(AX,EAH,CX,ECH,DX,EDH,BX,EBH,SP,SPH,BP,BPH,SI,SIH,DI,DIH:Word);
  2:(AL,AH,HAL,HAH,CL,CH,HCL,HCH,DL,DH,HDL,HDH,BL,BH,HBL,HBH:Byte);
  3:(Abs:Array[0..7]of LongInt);
  4:(AbsWord:Array[0..7]of LongRec);
 End;

  { Pointeur d'instruction 32 bits }
 EIP:LongInt;

  { Drapeaux du processeur }
 EFlags:Record Case Byte of
  0:(s:Set of(CF,bit1,PF,bit3,AF,bit5,ZF,SF,TF,_IF,DF,_OF));
  1:(Base:Word);
  2:(Abs:LongInt);
  3:(DataByte:Byte);
 End;

Procedure Init;
Var
 J:LongInt;
 ByteWrited:Word;
Begin
 {$I-}Assign(Memory,SwapFileMemory);
 Rewrite(Memory,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer un fichier temporaire pour la memoire');
  Halt(1);
 End;
 WriteLn('Creation du fichier d''echange de 16 Mo...');
 FillChar(ClrBuffer,SizeOf(ClrBuffer),0);
 For J:=0 to ClearBlockCount-1 do Begin
  Seek(Memory,J*LongInt(ClearBufferSize));
  BlockWrite(Memory,ClrBuffer,ClearBufferSize,ByteWrited);
  If ByteWrited<>ClearBufferSize Then Begin
   WriteLn('Erreur d''ecriture lors de l''initialisation de la memoire');
   Close(Memory);
   Halt(1);
  End;
 End;
 WriteLn('Fichier d''echange de 16 Mo cree avec succes.');
End;

Procedure Done;Begin
 Close(Memory);
 {$I-}Assign(Memory,SwapFileMemory);
 Erase(Memory);{$I+}
End;

BEGIN
 Init;
 WriteLn('EMUDPMI : Memoire lineaire de 16 Mo initialisee.');
 Done;
 WriteLn('EMUDPMI : Fichier d''echange supprime.');
END.
