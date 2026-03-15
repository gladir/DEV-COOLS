; Hello.j - Hello World en assembleur Jasmin
; Assemblable par JASMIN.PAS ou jasmin.jar

.class public Hello
.super java/lang/Object

; Constructeur par defaut
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; Point d'entree
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  getstatic java/lang/System/out Ljava/io/PrintStream;
  ldc "Hello, World!"
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  return
.end method
