; test15_conversion.j - Test des opcodes de conversion de types (TODO 12)
; Verifie i2l/i2f/i2d, l2i/l2f/l2d, f2i/f2l/f2d, d2i/d2l/d2f, i2b/i2c/i2s.

.class public test15_conversion
.super java/lang/Object

; Constructeur standard
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  return
.end method

; --- Test conversions int -> long/float/double ---
.method public static testIntConversions()V
  .limit stack 4
  .limit locals 3
  iload_0
  i2l
  iload_0
  i2f
  iload_0
  i2d
  return
.end method

; --- Test conversions long -> int/float/double ---
.method public static testLongConversions()V
  .limit stack 4
  .limit locals 4
  lload_0
  l2i
  lload_0
  l2f
  lload_0
  l2d
  return
.end method

; --- Test conversions float -> int/long/double ---
.method public static testFloatConversions()V
  .limit stack 4
  .limit locals 2
  fload_0
  f2i
  fload_0
  f2l
  fload_0
  f2d
  return
.end method

; --- Test conversions double -> int/long/float ---
.method public static testDoubleConversions()V
  .limit stack 4
  .limit locals 4
  dload_0
  d2i
  dload_0
  d2l
  dload_0
  d2f
  return
.end method

; --- Test conversions de troncature int -> byte/char/short ---
.method public static testTruncations()V
  .limit stack 2
  .limit locals 2
  iload_0
  i2b
  iload_0
  i2c
  iload_0
  i2s
  return
.end method

; --- main : point d'entree ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  return
.end method
