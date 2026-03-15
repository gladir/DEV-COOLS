; test03_arith.j - Operations arithmetiques
; Test de iadd, isub, imul, idiv, irem, ineg

.class public test03_arith
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 3
  .limit locals 3

  ; a = 20, b = 6
  bipush 20
  istore_1
  bipush 6
  istore_2

  ; Afficher a + b = 26
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  iload_2
  iadd
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher a - b = 14
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  iload_2
  isub
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher a * b = 120
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  iload_2
  imul
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher a / b = 3
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  iload_2
  idiv
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher a % b = 2
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  iload_2
  irem
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher -a = -20
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  ineg
  invokevirtual java/io/PrintStream/println(I)V

  return
.end method
