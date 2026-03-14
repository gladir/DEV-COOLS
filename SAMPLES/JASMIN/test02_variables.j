; test02_variables.j - Variables locales int
; Test de iconst, istore, iload, bipush, sipush

.class public test02_variables
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 4

  ; var1 = 42
  bipush 42
  istore_1

  ; var2 = 100
  bipush 100
  istore_2

  ; var3 = var1 + var2
  iload_1
  iload_2
  iadd
  istore_3

  ; Afficher var3 (142)
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_3
  invokevirtual java/io/PrintStream/println(I)V

  return
.end method
