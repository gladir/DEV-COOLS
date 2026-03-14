; test10_stack.j - Manipulation de la pile
; Test de dup, dup_x1, swap, pop, iconst, ldc

.class public test10_stack
.super java/lang/Object

.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

.method public static main([Ljava/lang/String;)V
  .limit stack 4
  .limit locals 2

  ; Test dup : dupliquer 42, stocker deux fois
  bipush 42
  dup
  istore_1
  ; pile: 42 ; local1 = 42
  getstatic java/lang/System/out Ljava/io/PrintStream;
  swap
  ; pile: PrintStream, 42
  invokevirtual java/io/PrintStream/println(I)V

  ; Afficher local1 = 42
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  invokevirtual java/io/PrintStream/println(I)V

  ; Test pop : empiler puis depiler
  iconst_5
  pop

  ; Test swap : echanger deux valeurs
  bipush 10
  bipush 20
  swap
  ; pile: 20, 10
  istore_1
  ; local1 = 10
  pop
  ; 20 depile
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  invokevirtual java/io/PrintStream/println(I)V

  ; Test ldc avec differents types
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Fin du test pile"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

  return
.end method
