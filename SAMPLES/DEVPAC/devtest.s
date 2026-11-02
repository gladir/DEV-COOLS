* DEVTEST.S - peripheriques emules : imprimante, serie, MIDI, disquettes
*
* Preparation (dans le dossier de travail) :
*   - une image de disquette 720 Ko vide :  dd if=/dev/zero of=DISKA.ST bs=512 count=1440
*     (ou n'importe quelle image, avec  DEVPAC /FLA:image.st)
*   - AUX.IN  (octets lus sur la serie, par ex. xyz) et MIDI.IN (premier octet $90)
* Execution :  DEVPAC /B /X DEVTEST.S      -> affiche  DEVPAC DEVICE TEST ALL OK
* Les sorties du programme sont ecrites dans PRINTER.OUT, AUX.OUT et MIDI.OUT.
        text
start:
        clr.w   d7
* --- sorties ---
        move.w  #0,d0
        move.w  #'P',d1
        bsr     bco
        move.w  #1,d0
        move.w  #'A',d1
        bsr     bco
        move.w  #3,d0
        move.w  #'M',d1
        bsr     bco
* --- entree serie : AUX.IN contient xyz ---
        move.w  #1,-(sp)
        move.w  #1,-(sp)
        trap    #13             ; Bconstat(1)
        addq.l  #4,sp
        tst.l   d0
        bne.s   ok1
        lea     m1(pc),a0
        bsr     fail
ok1:
        move.w  #1,-(sp)
        move.w  #2,-(sp)
        trap    #13             ; Bconin(1)
        addq.l  #4,sp
        cmp.b   #'x',d0
        beq.s   ok2
        lea     m2(pc),a0
        bsr     fail
ok2:
* MIDI in : 0x90
        move.w  #3,-(sp)
        move.w  #2,-(sp)
        trap    #13
        addq.l  #4,sp
        cmp.b   #$90,d0
        beq.s   ok3
        lea     m3(pc),a0
        bsr     fail
ok3:
* --- Getbpb(0) ---
        clr.w   -(sp)
        move.w  #7,-(sp)
        trap    #13
        addq.l  #4,sp
        tst.l   d0
        bne.s   ok4
        lea     m4(pc),a0
        bsr     fail
        bra.s   ok5
ok4:
        move.l  d0,a0
        cmp.w   #512,(a0)
        bne.s   bad5
        cmp.w   #2,2(a0)
        beq.s   ok5
bad5:
        lea     m5(pc),a0
        bsr     fail
ok5:
* --- Flopwr : ecrit un motif sur piste 0 face 0 secteur 8 (lsn 7) ---
        lea     buf2,a0
        move.w  #127,d0
fill0:  move.l  #$12345678,(a0)+
        dbra    d0,fill0
        move.w  #1,-(sp)
        clr.w   -(sp)           ; side 0
        clr.w   -(sp)           ; track 0
        move.w  #8,-(sp)        ; sector 8
        clr.w   -(sp)
        clr.l   -(sp)
        pea     buf2
        move.w  #9,-(sp)
        trap    #14
        lea     20(sp),sp
        tst.w   d0
        beq.s   okw0
        lea     m10(pc),a0
        bsr     fail
okw0:
* --- Rwabs lecture du secteur 7 (rwflag=0) ---
        move.l  #7,-(sp)        ; lrecno
        clr.w   -(sp)           ; dev
        move.w  #-1,-(sp)       ; recno
        move.w  #1,-(sp)        ; count
        pea     buf1
        clr.w   -(sp)           ; rwflag
        move.w  #4,-(sp)
        trap    #13
        lea     18(sp),sp
        tst.l   d0
        beq.s   ok6
        lea     m6(pc),a0
        bsr     fail
ok6:
        cmp.l   #$12345678,buf1
        beq.s   ok7
        lea     m7(pc),a0
        bsr     fail
ok7:
* --- Floprd piste 0 face 0 secteur 8 ---
        lea     buf2,a0
        clr.l   (a0)
        move.w  #1,-(sp)        ; count
        clr.w   -(sp)           ; side 0
        clr.w   -(sp)           ; track 0
        move.w  #8,-(sp)        ; sector 8 => lsn 7
        clr.w   -(sp)           ; dev
        clr.l   -(sp)           ; filler
        pea     buf2
        move.w  #8,-(sp)
        trap    #14
        lea     20(sp),sp
        tst.w   d0
        beq.s   ok8
        lea     m8(pc),a0
        bsr     fail
ok8:
        cmp.l   #$12345678,buf2
        beq.s   ok9
        lea     m9(pc),a0
        bsr     fail
ok9:
* --- Flopwr : ecrit un motif sur piste 3 face 1 secteur 4 ---
        lea     buf2,a0
        move.w  #127,d0
fill:   move.l  #$12345678,(a0)+
        dbra    d0,fill
        move.w  #1,-(sp)
        move.w  #1,-(sp)        ; side 1
        move.w  #3,-(sp)        ; track 3
        move.w  #4,-(sp)        ; sector 4
        clr.w   -(sp)
        clr.l   -(sp)
        pea     buf2
        move.w  #9,-(sp)
        trap    #14
        lea     20(sp),sp
        tst.w   d0
        beq.s   ok10
        lea     m10(pc),a0
        bsr     fail
ok10:
* relecture par Rwabs : lsn = (3*2+1)*9+3 = 66
        move.l  #66,-(sp)
        clr.w   -(sp)
        move.w  #-1,-(sp)
        move.w  #1,-(sp)
        pea     buf1
        clr.w   -(sp)
        move.w  #4,-(sp)
        trap    #13
        lea     18(sp),sp
        cmp.l   #$12345678,buf1
        beq.s   ok11
        lea     m11(pc),a0
        bsr     fail
ok11:
* --- Flopfmt piste 5 face 0 : remplit avec $E5E5 ---
        move.w  #$E5E5,-(sp)    ; virgin
        move.l  #$87654321,-(sp) ; magic
        move.w  #1,-(sp)        ; interleave
        clr.w   -(sp)           ; side
        move.w  #5,-(sp)        ; track
        move.w  #9,-(sp)        ; spt
        clr.w   -(sp)           ; dev
        clr.l   -(sp)           ; filler
        pea     buf2
        move.w  #10,-(sp)
        trap    #14
        lea     26(sp),sp
        tst.l   d0
        bpl.s   ok12
        lea     m12(pc),a0
        bsr     fail
ok12:
* lsn piste 5 face 0 = 5*2*9=90
        move.l  #90,-(sp)
        clr.w   -(sp)
        move.w  #-1,-(sp)
        move.w  #1,-(sp)
        pea     buf1
        clr.w   -(sp)
        move.w  #4,-(sp)
        trap    #13
        lea     18(sp),sp
        cmp.l   #$E5E5E5E5,buf1
        beq.s   ok13
        lea     m13(pc),a0
        bsr     fail
ok13:
* --- Midiws : 2 octets ---
        pea     midd
        move.w  #1,-(sp)
        move.w  #12,-(sp)
        trap    #14
        addq.l  #8,sp
* --- Rsconf ---
        move.w  #-2,-(sp)
        move.w  #-1,-(sp)
        move.w  #-1,-(sp)
        move.w  #-1,-(sp)
        move.w  #-1,-(sp)
        move.w  #-1,-(sp)
        move.w  #15,-(sp)
        trap    #14
        lea     14(sp),sp
* --- Random : deux valeurs distinctes ---
        move.w  #17,-(sp)
        trap    #14
        addq.l  #2,sp
        move.l  d0,d6
        move.w  #17,-(sp)
        trap    #14
        addq.l  #2,sp
        cmp.l   d0,d6
        bne.s   ok14
        lea     m14(pc),a0
        bsr     fail
ok14:
        tst.w   d7
        bne.s   done
        lea     mok(pc),a0
        bsr     puts
done:
        clr.w   -(sp)
        trap    #1

fail:   addq.w  #1,d7
puts:   move.l  a0,-(sp)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        rts
bco:    move.w  d1,-(sp)
        move.w  d0,-(sp)
        move.w  #3,-(sp)
        trap    #13
        addq.l  #6,sp
        rts

        data
midd:   dc.b    $90,$40
mok:    dc.b    'DEVPAC DEVICE TEST ALL OK',13,10,0
m1:     dc.b    'FAIL Bconstat AUX',13,10,0
m2:     dc.b    'FAIL Bconin AUX',13,10,0
m3:     dc.b    'FAIL Bconin MIDI',13,10,0
m4:     dc.b    'FAIL Getbpb null',13,10,0
m5:     dc.b    'FAIL Getbpb values',13,10,0
m6:     dc.b    'FAIL Rwabs read',13,10,0
m7:     dc.b    'FAIL Rwabs data',13,10,0
m8:     dc.b    'FAIL Floprd',13,10,0
m9:     dc.b    'FAIL Floprd data',13,10,0
m10:    dc.b    'FAIL Flopwr',13,10,0
m11:    dc.b    'FAIL Flopwr data',13,10,0
m12:    dc.b    'FAIL Flopfmt',13,10,0
m13:    dc.b    'FAIL Flopfmt data',13,10,0
m14:    dc.b    'FAIL Random',13,10,0
        even
        bss
buf1:   ds.b    512
buf2:   ds.b    512
