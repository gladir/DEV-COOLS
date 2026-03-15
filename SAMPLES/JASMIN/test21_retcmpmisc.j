; test21_retcmpmisc.j - Test des opcodes de retour, comparaison et divers (TODO 18)
; Teste ireturn, lreturn, freturn, dreturn, areturn, return,
; athrow, monitorenter, monitorexit, wide.

.class public test21_retcmpmisc
.super java/lang/Object

; --- Champ statique pour test ---
.field public static counter I

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 1
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  return
.end method

; --- Test ireturn : retourner un int ---
.method public static getInt()I
  .limit stack 1
  .limit locals 0
  bipush 42
  ireturn
.end method

; --- Test lreturn : retourner un long ---
.method public static getLong()J
  .limit stack 2
  .limit locals 0
  lconst_1
  lreturn
.end method

; --- Test freturn : retourner un float ---
.method public static getFloat()F
  .limit stack 1
  .limit locals 0
  fconst_2
  freturn
.end method

; --- Test dreturn : retourner un double ---
.method public static getDouble()D
  .limit stack 2
  .limit locals 0
  dconst_1
  dreturn
.end method

; --- Test areturn : retourner une reference ---
.method public static getString()Ljava/lang/String;
  .limit stack 1
  .limit locals 0
  ldc "hello"
  areturn
.end method

; --- Test return : retourner void ---
.method public static doNothing()V
  .limit stack 0
  .limit locals 0
  return
.end method

; --- Test athrow : lancer une exception ---
.method public static throwException()V
  .limit stack 2
  .limit locals 1
  new java/lang/RuntimeException
  dup
  invokespecial java/lang/RuntimeException/<init>()V
  athrow
.end method

; --- Test monitorenter / monitorexit : synchronisation ---
.method public static syncBlock()V
  .limit stack 2
  .limit locals 2
  new java/lang/Object
  dup
  invokespecial java/lang/Object/<init>()V
  astore_0
  ; Entrer dans le moniteur
  aload_0
  monitorenter
  ; Section critique
  bipush 1
  putstatic test21_retcmpmisc/counter I
  ; Sortir du moniteur
  aload_0
  monitorexit
  return
.end method

; --- Test wide iload : charger une variable locale avec index > 255 ---
.method public static testWideLoad()I
  .limit stack 2
  .limit locals 300
  bipush 77
  wide istore 256
  wide iload 256
  ireturn
.end method

; --- Test wide iinc : incrementer une variable avec index > 255 ---
.method public static testWideIinc()I
  .limit stack 2
  .limit locals 300
  bipush 10
  wide istore 260
  wide iinc 260 5
  wide iload 260
  ireturn
.end method

; --- Test wide avec d'autres types ---
.method public static testWideAload()Ljava/lang/Object;
  .limit stack 2
  .limit locals 300
  aconst_null
  wide astore 270
  wide aload 270
  areturn
.end method

; --- Test lcmp, fcmpl, fcmpg, dcmpl, dcmpg (deja dans TODO 13) ---
; Inclus ici pour verification de non-regression
.method public static testComparisons()I
  .limit stack 4
  .limit locals 2
  ; Test lcmp : comparer deux longs
  lconst_1
  lconst_0
  lcmp
  istore_0
  ; Test fcmpl : comparer deux floats
  fconst_1
  fconst_2
  fcmpl
  istore_1
  ; Test fcmpg : comparer deux floats
  fconst_2
  fconst_1
  fcmpg
  pop
  ; Test dcmpl : comparer deux doubles
  dconst_1
  dconst_0
  dcmpl
  pop
  ; Test dcmpg : comparer deux doubles
  dconst_0
  dconst_1
  dcmpg
  pop
  iload_0
  ireturn
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 2
  .limit locals 1
  ; Appeler les differentes methodes de test
  invokestatic test21_retcmpmisc/getInt()I
  pop
  invokestatic test21_retcmpmisc/getLong()J
  pop2
  invokestatic test21_retcmpmisc/getFloat()F
  pop
  invokestatic test21_retcmpmisc/getDouble()D
  pop2
  invokestatic test21_retcmpmisc/getString()Ljava/lang/String;
  pop
  invokestatic test21_retcmpmisc/doNothing()V
  invokestatic test21_retcmpmisc/syncBlock()V
  invokestatic test21_retcmpmisc/testWideLoad()I
  pop
  invokestatic test21_retcmpmisc/testWideIinc()I
  pop
  invokestatic test21_retcmpmisc/testWideAload()Ljava/lang/Object;
  pop
  invokestatic test21_retcmpmisc/testComparisons()I
  pop
  return
.end method
