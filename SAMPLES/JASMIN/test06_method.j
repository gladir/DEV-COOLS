; test06_method.j - Appel de methode statique
; Test de invokestatic, ireturn

.class public test06_method
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; Methode statique : int add(int a, int b) { return a + b; }
.method public static add(II)I
  .limit stack 2
  .limit locals 2
  iload_0
  iload_1
  iadd
  ireturn
.end method

; Methode statique : int factorial(int n)
.method public static factorial(I)I
  .limit stack 2
  .limit locals 1
  iload_0
  iconst_1
  if_icmple BaseCase
  iload_0
  iload_0
  iconst_1
  isub
  invokestatic test06_method/factorial(I)I
  imul
  ireturn
BaseCase:
  iconst_1
  ireturn
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1

  ; Afficher add(3, 7) = 10
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iconst_3
  bipush 7
  invokestatic test06_method/add(II)I
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher factorial(5) = 120
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iconst_5
  invokestatic test06_method/factorial(I)I
  invokevirtual java/io/PrintStream/println(I)V

  return
.end method
