; ============================================================
; DISSYS v1.0 - Desassemblage de TESTS/DOSEMU/CPUDETECT.COM
; Format detecte/force : COM
; Origine (ORG)        : 0100h
; Point d'entree       : 0100h
; DOS cible            : 6.22
; Genere le 2026-10-03
; ============================================================

0100h      PUSHF
0101h      POP AX
0102h      AND AX,0FFFh
0105h      PUSH AX
0106h      POPF
0107h      PUSHF
0108h      POP AX
0109h      AND AX,F000h
010Ch      CMP AX,F000h
010Fh      JZ 0119h
0111h      CMP AX,0000h
0114h      JZ 0142h
0116h      JMP 0147h
0119h      MOV CX,21h
011Bh      MOV AX,0001h
011Eh      SHL AX,CL
0120h      CMP AX,0000h
0123h      JZ 012Ah
0125h      MOV AX,02h
0127h      JMP 0183h
012Ah      MOV AX,0001h
012Dh      CMP AX,0000h
0130h      MOV AX,00h
0132h      MOV BX,05h
0134h      MUL BL
0136h      JZ 013Dh
0138h      MOV AX,00h
013Ah      JMP 0183h
013Dh      MOV AX,01h
013Fh      JMP 0183h
0142h      MOV AX,03h
0144h      JMP 0183h
0147h      MOV BX,1234h
014Ah      MOV CX,1234h
014Dh      MOV DX,1234h
0150h      XOR EAX,EAX
0153h      CPUID
0155h      CMP BX,1234h
0159h      JNZ 016Ch
015Bh      CMP CX,1234h
015Fh      JNZ 016Ch
0161h      CMP DX,1234h
0165h      JNZ 016Ch
0167h      MOV AX,04h
0169h      JMP 0183h
016Ch      CPUID
016Eh      MOV BX,AX
0170h      MOV CX,08h
0172h      SHR BX,CL
0174h      AND BX,000Fh
0177h      CMP BX,0005h
017Ah      JZ 0181h
017Ch      MOV AX,05h
017Eh      JMP 0183h
0181h      MOV AX,06h
0183h      MOV SP,4Ch
0185h      INT 21h
