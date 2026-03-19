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

BEGIN
 WriteLn('EMUDPMI : Programme non encore implemente.');
 WriteLn('Consultez la liste TODO dans le code source.');
END.
