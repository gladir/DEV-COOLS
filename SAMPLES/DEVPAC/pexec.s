        text
start:  pea     msg1(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
* Pexec(0,"HELLO.PRG","",0)
        clr.l   -(sp)
        pea     cmd(pc)
        pea     name(pc)
        clr.w   -(sp)
        move.w  #$4b,-(sp)
        trap    #1
        lea     16(sp),sp
        move.l  d0,d7
        pea     msg2(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        move.l  d7,d0
        add.b   #'0',d0
        move.w  d0,-(sp)
        move.w  #2,-(sp)
        trap    #1
        addq.l  #4,sp
        clr.w   -(sp)
        trap    #1
        data
msg1:   dc.b    'Parent: launching child',13,10,0
msg2:   dc.b    13,10,'Parent: child exit code = ',0
name:   dc.b    'hello.PRG',0
cmd:    dc.b    0,0
