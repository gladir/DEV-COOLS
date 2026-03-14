; test23_codeattr.j - Test de l'attribut Code : generation binaire (TODO 20)
; Teste les composantes de l'attribut Code pour chaque methode :
; max_stack, max_locals, code[] (bytecode), exception_table (vide pour
; l'instant), sous-attributs (LineNumberTable via .line).

.class public test23_codeattr
.super java/lang/Object

; --- Constructeur par defaut ---
; Verifie l'emission d'un Code attribute simple avec peu d'octets
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Methode simple sans .line ---
; Code attribute avec max_stack=2, max_locals=1, code vide de .line
.method public static simpleAdd()I
  .limit stack 2
  .limit locals 1
  bipush 10
  bipush 20
  iadd
  ireturn
.end method

; --- Methode avec .line (LineNumberTable) ---
; Verifie que le sous-attribut LineNumberTable est correctement genere
.method public static withLineNumbers(I)I
  .limit stack 2
  .limit locals 2
  .line 10
  iload_0
  .line 11
  bipush 5
  iadd
  .line 12
  istore_1
  .line 13
  iload_1
  ireturn
.end method

; --- Methode avec plus de .line entries ---
; Test avec de multiples entrees LineNumberTable
.method public static manyLines(II)I
  .limit stack 2
  .limit locals 3
  .line 20
  iload_0
  iload_1
  .line 21
  iadd
  istore_2
  .line 22
  iload_2
  .line 23
  bipush 100
  .line 24
  if_icmpgt BigValue
  .line 25
  iload_2
  ireturn
BigValue:
  .line 27
  bipush 100
  ireturn
.end method

; --- Methode avec max_stack et max_locals eleves ---
; Verifie l'emission de valeurs max_stack/max_locals > 1 octet
.method public static largeLocals(IIIIII)I
  .limit stack 10
  .limit locals 7
  iload_0
  iload_1
  iadd
  iload_2
  iadd
  iload_3
  iadd
  iload 4
  iadd
  iload 5
  iadd
  ireturn
.end method

; --- Methode avec code lineaire (pas de branchement) ---
; Verifie l'emission du bytecode brut
.method public static linearCode()I
  .limit stack 3
  .limit locals 3
  iconst_1
  istore_0
  iconst_2
  istore_1
  iload_0
  iload_1
  iadd
  istore_2
  iload_2
  ireturn
.end method

; --- Methode avec branchements resolus ---
; Verifie que les labels sont resolus avant l'emission du Code attribute
.method public static withBranches(I)I
  .limit stack 1
  .limit locals 2
  .line 40
  iload_0
  ifge Positive
  .line 42
  iload_0
  ineg
  ireturn
Positive:
  .line 45
  iload_0
  ireturn
.end method

; --- Methode abstraite (pas de Code attribute) ---
; abstract ne doit pas generer d'attribut Code

; --- Methode void avec .line ---
; Teste un retour void avec des entrees LineNumberTable
.method public static voidWithLines()V
  .limit stack 2
  .limit locals 1
  .line 50
  getstatic java/lang/System/out Ljava/io/PrintStream;
  .line 51
  ldc "Hello from voidWithLines"
  .line 52
  invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
  .line 53
  return
.end method

; --- Methode avec auto-locals et auto-stack ---
; .limit absents : les valeurs sont calculees automatiquement
.method public static autoLimits(I)I
  iload_0
  iconst_1
  iadd
  ireturn
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 4
  .limit locals 1
  .line 100
  ; Test simpleAdd
  invokestatic test23_codeattr/simpleAdd()I
  pop
  .line 102
  ; Test withLineNumbers
  bipush 7
  invokestatic test23_codeattr/withLineNumbers(I)I
  pop
  .line 104
  ; Test manyLines
  bipush 30
  bipush 40
  invokestatic test23_codeattr/manyLines(II)I
  pop
  .line 106
  ; Test largeLocals
  iconst_1
  iconst_2
  iconst_3
  iconst_4
  iconst_5
  bipush 6
  invokestatic test23_codeattr/largeLocals(IIIIII)I
  pop
  .line 108
  ; Test linearCode
  invokestatic test23_codeattr/linearCode()I
  pop
  .line 110
  ; Test withBranches
  bipush -5
  invokestatic test23_codeattr/withBranches(I)I
  pop
  .line 112
  ; Test voidWithLines
  invokestatic test23_codeattr/voidWithLines()V
  .line 114
  ; Test autoLimits
  bipush 99
  invokestatic test23_codeattr/autoLimits(I)I
  pop
  .line 116
  return
.end method
