; test05_loop.j - Boucles avec goto et comparaison
; Test de goto, if_icmplt, iinc

.class public test05_loop
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
  .limit locals 2

  ; for (i = 0; i < 5; i++) print(i)
  iconst_0
  istore_1
LoopStart:
  iload_1
  iconst_5
  if_icmpge LoopEnd
  getstatic java/lang/System/out Ljava/io/PrintStream;
  iload_1
  invokevirtual java/io/PrintStream/println(I)V
  iinc 1 1
  goto LoopStart
LoopEnd:

  ; Afficher "Boucle terminee"
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Boucle terminee"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V

  return
.end method
