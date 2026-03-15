; test15_conversion.j - Test des opcodes de conversion de types (TODO 12)
; Verifie i2l/i2f/i2d, l2i/l2f/l2d, f2i/f2l/f2d, d2i/d2l/d2f, i2b/i2c/i2s.

.class public test15_conversion
.super java/lang/Object

; Constructeur standard
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test conversions int -> long/float/double ---
.method public static testIntConversions()V
  .limit stack 4
  .limit locals 3
  bipush 42
  istore_0
  iload_0
  i2l
  pop2
  iload_0
  i2f
  pop
  iload_0
  i2d
  pop2
  return
.end method

; --- Test conversions long -> int/float/double ---
.method public static testLongConversions()V
  .limit stack 4
  .limit locals 4
  lconst_1
  lstore_0
  lload_0
  l2i
  pop
  lload_0
  l2f
  pop
  lload_0
  l2d
  pop2
  return
.end method

; --- Test conversions float -> int/long/double ---
.method public static testFloatConversions()V
  .limit stack 4
  .limit locals 2
  fconst_1
  fstore_0
  fload_0
  f2i
  pop
  fload_0
  f2l
  pop2
  fload_0
  f2d
  pop2
  return
.end method

; --- Test conversions double -> int/long/float ---
.method public static testDoubleConversions()V
  .limit stack 4
  .limit locals 4
  dconst_1
  dstore_0
  dload_0
  d2i
  pop
  dload_0
  d2l
  pop2
  dload_0
  d2f
  pop
  return
.end method

; --- Test conversions de troncature int -> byte/char/short ---
.method public static testTruncations()V
  .limit stack 2
  .limit locals 2
  sipush 300
  istore_0
  iload_0
  i2b
  pop
  iload_0
  i2c
  pop
  iload_0
  i2s
  pop
  return
.end method

; --- main : point d'entree ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method
