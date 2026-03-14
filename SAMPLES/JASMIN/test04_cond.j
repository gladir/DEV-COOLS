; test04_cond.j - Branchements conditionnels
; Test de ifeq, ifne, if_icmpge, if_icmplt, goto

.class public test04_cond
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

  ; x = 10
  bipush 10
  istore_1

  ; if (x >= 5) print "x >= 5"
  iload_1
  iconst_5
  if_icmplt NotGE5
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "x >= 5"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
NotGE5:

  ; if (x == 0) print "zero" else print "non-zero"
  iload_1
  ifeq IsZero
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "non-zero"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  goto EndZeroTest
IsZero:
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "zero"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
EndZeroTest:

  return
.end method
