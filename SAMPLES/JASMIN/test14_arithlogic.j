; test14_arithlogic.j - Test des opcodes arithmetiques et logiques (TODO 11)
; Verifie iadd/isub/imul/idiv/irem/ineg, ladd..lneg, fadd..fneg, dadd..dneg,
; ishl/ishr/iushr/iand/ior/ixor, lshl/lshr/lushr/land/lor/lxor, iinc.

.class public test14_arithlogic
.super java/lang/Object

; Constructeur standard
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  return
.end method

; --- Test arithmetique entiere (int) ---
.method public static testIntArith()V
  .limit stack 4
  .limit locals 2
  iload_0
  iload_1
  iadd
  iload_0
  iload_1
  isub
  iload_0
  iload_1
  imul
  iload_0
  iload_1
  idiv
  iload_0
  iload_1
  irem
  iload_0
  ineg
  return
.end method

; --- Test arithmetique longue (long) ---
.method public static testLongArith()V
  .limit stack 8
  .limit locals 4
  lload_0
  lload_2
  ladd
  lload_0
  lload_2
  lsub
  lload_0
  lload_2
  lmul
  lload_0
  lload_2
  ldiv
  lload_0
  lload_2
  lrem
  lload_0
  lneg
  return
.end method

; --- Test arithmetique flottante (float) ---
.method public static testFloatArith()V
  .limit stack 4
  .limit locals 2
  fload_0
  fload_1
  fadd
  fload_0
  fload_1
  fsub
  fload_0
  fload_1
  fmul
  fload_0
  fload_1
  fdiv
  fload_0
  fload_1
  frem
  fload_0
  fneg
  return
.end method

; --- Test arithmetique double (double) ---
.method public static testDoubleArith()V
  .limit stack 8
  .limit locals 4
  dload_0
  dload_2
  dadd
  dload_0
  dload_2
  dsub
  dload_0
  dload_2
  dmul
  dload_0
  dload_2
  ddiv
  dload_0
  dload_2
  drem
  dload_0
  dneg
  return
.end method

; --- Test operations sur les bits (int) ---
.method public static testIntBitOps()V
  .limit stack 4
  .limit locals 2
  iload_0
  iload_1
  ishl
  iload_0
  iload_1
  ishr
  iload_0
  iload_1
  iushr
  iload_0
  iload_1
  iand
  iload_0
  iload_1
  ior
  iload_0
  iload_1
  ixor
  return
.end method

; --- Test operations sur les bits (long) ---
.method public static testLongBitOps()V
  .limit stack 6
  .limit locals 5
  lload_0
  iload 4
  lshl
  lload_0
  iload 4
  lshr
  lload_0
  iload 4
  lushr
  lload_0
  lload_2
  land
  lload_0
  lload_2
  lor
  lload_0
  lload_2
  lxor
  return
.end method

; --- Test iinc ---
.method public static testIinc()V
  .limit stack 2
  .limit locals 3
  iinc 0 1
  iinc 1 10
  iinc 2 -1
  iinc 0 127
  iinc 1 -128
  return
.end method

; --- main : point d'entree ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method
