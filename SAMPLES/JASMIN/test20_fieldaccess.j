; test20_fieldaccess.j - Test des opcodes d'acces aux champs (TODO 17)
; Teste getstatic, putstatic, getfield, putfield.

.class public test20_fieldaccess
.super java/lang/Object

; --- Champs statiques ---
.field public static compteur I
.field public static message Ljava/lang/String;

; --- Champs d'instance ---
.field public valeur I
.field public nom Ljava/lang/String;

; --- Constructeur par defaut ---
.method public <init>()V
  .limit stack 2
  .limit locals 1
  aload_0
  invokespecial java/lang/Object/<init>()V
  ; Initialiser champ d'instance valeur a 42
  aload_0
  bipush 42
  putfield test20_fieldaccess/valeur I
  ; Initialiser champ d'instance nom
  aload_0
  ldc "Objet"
  putfield test20_fieldaccess/nom Ljava/lang/String;
  return
.end method

; --- Test getstatic/putstatic : acces aux champs statiques ---
.method public static testStaticFields()V
  .limit stack 2
  .limit locals 1
  ; Ecrire un entier dans le champ statique compteur
  bipush 10
  putstatic test20_fieldaccess/compteur I
  ; Lire le champ statique compteur
  getstatic test20_fieldaccess/compteur I
  istore_0
  ; Ecrire une chaine dans le champ statique message
  ldc "Bonjour"
  putstatic test20_fieldaccess/message Ljava/lang/String;
  ; Lire le champ statique message
  getstatic test20_fieldaccess/message Ljava/lang/String;
  pop
  ; Utiliser System.out (champ statique d'une autre classe)
  getstatic java/lang/System/out Ljava/io/PrintStream;
  pop
  return
.end method

; --- Test getfield/putfield : acces aux champs d'instance ---
.method public static testInstanceFields()V
  .limit stack 3
  .limit locals 2
  ; Creer un objet
  new test20_fieldaccess
  dup
  invokespecial test20_fieldaccess/<init>()V
  astore_0
  ; Lire le champ d'instance valeur (initialise a 42 par le constructeur)
  aload_0
  getfield test20_fieldaccess/valeur I
  istore_1
  ; Modifier le champ d'instance valeur
  aload_0
  bipush 99
  putfield test20_fieldaccess/valeur I
  ; Relire le champ d'instance valeur
  aload_0
  getfield test20_fieldaccess/valeur I
  pop
  ; Lire le champ d'instance nom
  aload_0
  getfield test20_fieldaccess/nom Ljava/lang/String;
  pop
  ; Modifier le champ d'instance nom
  aload_0
  ldc "NouveauNom"
  putfield test20_fieldaccess/nom Ljava/lang/String;
  return
.end method

; --- Test acces aux champs d'autres classes ---
.method public static testExternalFields()V
  .limit stack 2
  .limit locals 1
  ; Lire System.out (PrintStream)
  getstatic java/lang/System/out Ljava/io/PrintStream;
  astore_0
  ; Lire System.err (PrintStream)
  getstatic java/lang/System/err Ljava/io/PrintStream;
  pop
  return
.end method

; --- Methode main ---
.method public static main([Ljava/lang/String;)V
  .limit stack 1
  .limit locals 1
  invokestatic test20_fieldaccess/testStaticFields()V
  invokestatic test20_fieldaccess/testInstanceFields()V
  invokestatic test20_fieldaccess/testExternalFields()V
  return
.end method
