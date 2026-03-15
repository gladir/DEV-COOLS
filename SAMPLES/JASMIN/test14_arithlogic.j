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
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test arithmetique entiere (int) ---
.method public static testIntArith()V
  .limit stack 4
  .limit locals 2
  bipush 10
  istore_0
  bipush 3
  istore_1
  iload_0
  iload_1
  iadd
  pop
  iload_0
  iload_1
  isub
  pop
  iload_0
  iload_1
  imul
  pop
  iload_0
  iload_1
  idiv
  pop
  iload_0
  iload_1
  irem
  pop
  iload_0
  ineg
  pop
  return
.end method

; --- Test arithmetique longue (long) ---
.method public static testLongArith()V
  .limit stack 8
  .limit locals 4
  lconst_1
  lstore_0
  ldc2_w 2
  lstore_2
  lload_0
  lload_2
  ladd
  pop2
  lload_0
  lload_2
  lsub
  pop2
  lload_0
  lload_2
  lmul
  pop2
  lload_0
  lload_2
  ldiv
  pop2
  lload_0
  lload_2
  lrem
  pop2
  lload_0
  lneg
  pop2
  return
.end method

; --- Test arithmetique flottante (float) ---
.method public static testFloatArith()V
  .limit stack 4
  .limit locals 2
  fconst_1
  fstore_0
  fconst_2
  fstore_1
  fload_0
  fload_1
  fadd
  pop
  fload_0
  fload_1
  fsub
  pop
  fload_0
  fload_1
  fmul
  pop
  fload_0
  fload_1
  fdiv
  pop
  fload_0
  fload_1
  frem
  pop
  fload_0
  fneg
  pop
  return
.end method

; --- Test arithmetique double (double) ---
.method public static testDoubleArith()V
  .limit stack 8
  .limit locals 4
  dconst_1
  dstore_0
  dconst_0
  dstore_2
  dload_0
  dload_2
  dadd
  pop2
  dload_0
  dload_2
  dsub
  pop2
  dload_0
  dload_2
  dmul
  pop2
  dload_0
  dload_2
  ddiv
  pop2
  dload_0
  dload_2
  drem
  pop2
  dload_0
  dneg
  pop2
  return
.end method

; --- Test operations sur les bits (int) ---
.method public static testIntBitOps()V
  .limit stack 4
  .limit locals 2
  bipush 15
  istore_0
  iconst_2
  istore_1
  iload_0
  iload_1
  ishl
  pop
  iload_0
  iload_1
  ishr
  pop
  iload_0
  iload_1
  iushr
  pop
  iload_0
  iload_1
  iand
  pop
  iload_0
  iload_1
  ior
  pop
  iload_0
  iload_1
  ixor
  pop
  return
.end method

; --- Test operations sur les bits (long) ---
.method public static testLongBitOps()V
  .limit stack 6
  .limit locals 5
  lconst_1
  lstore_0
  ldc2_w 2
  lstore_2
  iconst_1
  istore 4
  lload_0
  iload 4
  lshl
  pop2
  lload_0
  iload 4
  lshr
  pop2
  lload_0
  iload 4
  lushr
  pop2
  lload_0
  lload_2
  land
  pop2
  lload_0
  lload_2
  lor
  pop2
  lload_0
  lload_2
  lxor
  pop2
  return
.end method

; --- Test iinc ---
.method public static testIinc()V
  .limit stack 2
  .limit locals 3
  iconst_0
  istore_0
  iconst_0
  istore_1
  iconst_0
  istore_2
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
