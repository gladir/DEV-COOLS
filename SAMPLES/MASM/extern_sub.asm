; extern_sub.asm - module secondaire pour extern.asm
; Exporte sub_add(arg1, arg2) -> AX = arg1 + arg2

        .MODEL  SMALL

        .CODE

sub_add PROC    NEAR
        PUBLIC  sub_add       ; declare PUBLIC apres la definition du label
        PUSH    BP
        MOV     BP, SP
        MOV     AX, [BP+4]   ; arg1
        ADD     AX, [BP+6]   ; arg2
        POP     BP
        RET
sub_add ENDP

        END
