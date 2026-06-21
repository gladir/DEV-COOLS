{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: COMMENT parcourt un fichier source Pascal, C ou C# et
    ajoute des commentaires en francais la ou il n y en a pas : pour
    les constantes, les champs d enregistrement/structure/classe, les
    procedures/fonctions/methodes (bloc @description/@param/@return)
    et, en complement, les @param manquants d une procedure/fonction
    deja commentee.

    La signification d un nom est cherchee dans un dictionnaire
    Nom -> Description (tableau interne d amorce, complete au
    demarrage par le fichier texte COMMENT.DIC du repertoire courant
    s il existe : une entree par ligne, au format Nom=Description).
    Si le nom exact n est pas dans le dictionnaire, il est decoupe en
    mots (limites CamelCase / underscore) et chaque mot est cherche a
    son tour ; pour les fonctions/procedures, un prefixe ou suffixe
    "verbe" connu (Init, Get, Draw, Exists, ...) sert a batir une
    phrase. A defaut de toute correspondance, un commentaire generique
    honnete est insere (ex: "Champ NomDuChamp") plutot que d inventer
    une signification.

    Le fichier source est modifie sur place (relecture/ecriture
    complete en memoire, donc tout ou rien : aucune ecriture partielle
    en cas d erreur).
}

Program COMMENT;

{$A-}
{$R-}

Const
 MaxLines      = 60000;     { nombre maximal de lignes du fichier source }
 MaxDict       = 4000;      { taille maximale du dictionnaire Nom->Description }
 MaxVerbs      = 120;       { taille maximale des tables de verbes prefixe/suffixe }
 MaxWords      = 16;        { nombre maximal de mots dans un nom decoupe }
 MaxParams     = 32;        { nombre maximal de parametres d une fonction/procedure }
 DictFileName  = 'COMMENT.DIC'; { dictionnaire externe (repertoire courant) }

 { Modes de fonctionnement (correspondent aux options /ALL /PROC ... ) }
 MD_PROC       = 1;         { commenter les procedures              }
 MD_FUNC       = 2;         { commenter les fonctions               }
 MD_FIELD      = 4;         { commenter les champs/variables        }
 MD_RECORD     = 8;         { commenter les types enregistrement/structure/classe }
 MD_PARAM      = 16;        { ajouter les @param manquants          }
 MD_CONST      = 32;        { commenter les constantes              }
 MD_ALL        = MD_PROC + MD_FUNC + MD_FIELD + MD_RECORD +
                 MD_PARAM + MD_CONST;

Type
 String120 = String[120];
 String40  = String[40];

 { Une entree du dictionnaire Nom -> Description francaise }
 TDictEntry = Record
  Nom : String40;           { identificateur (insensible a la casse) }
  Desc: String120;          { description francaise associee        }
 End;

 { Une entree de la table des verbes (prefixe ou suffixe d un nom de
   fonction/procedure, ex: "Init" -> "initialiser") }
 TVerbEntry = Record
  Mot   : String40;         { prefixe ou suffixe (ex: 'Init', 'Exists') }
  Phrase: String120;        { tournure verbale francaise associee   }
 End;

 { Langage source detecte d apres l extension du fichier }
 TSrcLang = (LangPascal, LangC, LangCSharp, LangUnknown);

Const
 MaxReturnDict = 200;       { taille de la table des @return connus }

Var
 Dict     : Array[1..MaxDict] Of TDictEntry;
 DictCount: Integer;
 ReturnDict     : Array[1..MaxReturnDict] Of TDictEntry;
 ReturnDictCount: Integer;
 PrefixVerbs : Array[1..MaxVerbs] Of TVerbEntry;
 PrefixCount : Integer;
 SuffixVerbs : Array[1..MaxVerbs] Of TVerbEntry;
 SuffixCount : Integer;

 Lines    : Array[1..MaxLines] Of String;
 LineCount: Integer;

 OutF     : Text;           { fichier temporaire de sortie }
 OutName  : String;
 SrcName  : String;
 Lang     : TSrcLang;
 Mode     : Integer;        { combinaison de MD_xxx selon l option }

 NbConst, NbField, NbProc, NbFunc, NbRecord, NbParam: LongInt;
                            { compteurs de commentaires ajoutes, pour le bilan }

{ ============================================================
  UTILITAIRES CHAINES
  ============================================================ }

{ @description: Convertit une chaine en majuscules.
  @param S Chaine a convertir
  @return Chaine convertie en majuscules }
Function UpStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If S[I] In ['a'..'z'] Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

{ @description: Convertit une chaine en minuscules.
  @param S Chaine a convertir
  @return Chaine convertie en minuscules }
Function LowStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If S[I] In ['A'..'Z'] Then S[I] := Chr(Ord(S[I]) + 32);
 LowStr := S;
End;

{ @description: Met en majuscule la premiere lettre d une chaine.
  @param S Chaine a transformer
  @return Chaine dont la premiere lettre est en majuscule }
Function CapStr(S: String): String;
Begin
 If (Length(S) > 0) And (S[1] In ['a'..'z']) Then
  S[1] := Chr(Ord(S[1]) - 32);
 CapStr := S;
End;

{ @description: Supprime les espaces et tabulations au debut et a la
    fin d une chaine.
  @param S Chaine a nettoyer
  @return Chaine sans espaces ni tabulations en bordure }
Function TrimStr(S: String): String;
Begin
 While (Length(S) > 0) And (S[1] In [' ', #9]) Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] In [' ', #9, #13]) Do
  Delete(S, Length(S), 1);
 TrimStr := S;
End;

{ @description: Indique si un caractere peut faire partie d un
    identificateur Pascal/C/C# (lettre, chiffre ou underscore).
  @param C Caractere a tester
  @return Vrai si le caractere est valide dans un identificateur }
Function IsIdentChar(C: Char): Boolean;
Begin
 IsIdentChar := (C In ['A'..'Z', 'a'..'z', '0'..'9', '_']);
End;

{ @description: Indique si un caractere peut demarrer un
    identificateur (lettre ou underscore, jamais un chiffre).
  @param C Caractere a tester
  @return Vrai si le caractere peut demarrer un identificateur }
Function IsIdentStart(C: Char): Boolean;
Begin
 IsIdentStart := (C In ['A'..'Z', 'a'..'z', '_']);
End;

{ @description: Indique si Sub apparait dans S, sans tenir compte de
    la casse.
  @param S Chaine dans laquelle chercher
  @param Sub Sous-chaine recherchee
  @return Vrai si Sub est trouve dans S }
Function ContainsStr(S, Sub: String): Boolean;
Begin
 ContainsStr := (Pos(UpStr(Sub), UpStr(S)) > 0);
End;

{ @description: Indique si S commence par Prefix, sans tenir compte
    de la casse.
  @param S Chaine a tester
  @param Prefix Prefixe recherche
  @return Vrai si S commence par Prefix }
Function StartsWithStr(S, Prefix: String): Boolean;
Begin
 StartsWithStr := (UpStr(Copy(S, 1, Length(Prefix))) = UpStr(Prefix));
End;

{ @description: Indique si S se termine par Suffix, sans tenir compte
    de la casse.
  @param S Chaine a tester
  @param Suffix Suffixe recherche
  @return Vrai si S se termine par Suffix }
Function EndsWithStr(S, Suffix: String): Boolean;
Begin
 EndsWithStr := (Length(S) >= Length(Suffix)) And
  (UpStr(Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix))) =
   UpStr(Suffix));
End;

{ @description: Extrait l extension (sans le point, en majuscules)
    d un nom de fichier.
  @param FName Nom du fichier
  @return Extension en majuscules, sans le point initial }
Function ExtractExtUp(FName: String): String;
Var
 I: Integer;
Begin
 ExtractExtUp := '';
 For I := Length(FName) DownTo 1 Do Begin
  If FName[I] = '.' Then Begin
   ExtractExtUp := UpStr(Copy(FName, I + 1, Length(FName) - I));
   Exit;
  End;
  If (FName[I] = '\') Or (FName[I] = '/') Then Exit;
 End;
End;

{ ============================================================
  DICTIONNAIRE NOM -> DESCRIPTION
  ============================================================ }

{ @description: Ajoute une entree au dictionnaire Nom -> Description
    si la table n est pas pleine.
  @param Nom Identificateur (insensible a la casse)
  @param Desc Description francaise associee }
Procedure DictAdd(Nom, Desc: String);
Begin
 If DictCount < MaxDict Then Begin
  Inc(DictCount);
  Dict[DictCount].Nom  := Nom;
  Dict[DictCount].Desc := Desc;
 End;
End;

{ @description: Cherche un identificateur dans le dictionnaire
    (comparaison insensible a la casse, premiere entree trouvee).
  @param Nom Identificateur recherche
  @return Description trouvee, ou chaine vide si absente }
Function DictFind(Nom: String): String;
Var
 I: Integer;
 U: String40;
Begin
 DictFind := '';
 U := UpStr(Nom);
 For I := 1 To DictCount Do
  If UpStr(Dict[I].Nom) = U Then Begin
   DictFind := Dict[I].Desc;
   Exit;
  End;
End;

{ @description: Ajoute une entree a la table des @return connus pour
    des noms de fonctions specifiques (ex: 'FileExists' -> phrase
    decrivant precisement vrai/faux).
  @param Nom Nom de la fonction (insensible a la casse)
  @param Desc Phrase decrivant la valeur de retour }
Procedure ReturnAdd(Nom, Desc: String);
Begin
 If ReturnDictCount < MaxReturnDict Then Begin
  Inc(ReturnDictCount);
  ReturnDict[ReturnDictCount].Nom  := Nom;
  ReturnDict[ReturnDictCount].Desc := Desc;
 End;
End;

{ @description: Cherche le nom d une fonction dans la table des
    @return connus.
  @param Nom Nom de la fonction recherche
  @return Phrase de retour trouvee, ou chaine vide si absente }
Function ReturnDictFind(Nom: String): String;
Var
 I: Integer;
 U: String40;
Begin
 ReturnDictFind := '';
 U := UpStr(Nom);
 For I := 1 To ReturnDictCount Do
  If UpStr(ReturnDict[I].Nom) = U Then Begin
   ReturnDictFind := ReturnDict[I].Desc;
   Exit;
  End;
End;

{ @description: Construit la phrase @return d une fonction : reprend
    la phrase connue pour ce nom si elle existe, sinon une phrase
    generique honnete (on ne devine pas la valeur de retour exacte
    d une fonction inconnue).
  @param Name Nom de la fonction
  @return Phrase decrivant la valeur de retour }
Function BuildReturnPhrase(Name: String): String;
Var
 D: String;
Begin
 D := ReturnDictFind(Name);
 If D = '' Then D := 'Resultat de l operation.';
 BuildReturnPhrase := D;
End;

{ @description: Remplit la table des @return connus pour les
    fonctions standards les plus courantes. }
Procedure InitReturnDict;
Begin
 ReturnDictCount := 0;
 ReturnAdd('FileExists', 'Faux = le fichier n existe pas, Vrai = le fichier existe.');
 ReturnAdd('DirectoryExists', 'Faux = le repertoire n existe pas, Vrai = le repertoire existe.');
 ReturnAdd('Eof', 'Vrai si la fin du fichier est atteinte.');
 ReturnAdd('Eoln', 'Vrai si la fin de la ligne est atteinte.');
 ReturnAdd('IOResult', 'Code d erreur de la derniere operation d entree/sortie (0 = aucune erreur).');
 ReturnAdd('FileSize', 'Taille du fichier en octets.');
 ReturnAdd('FilePos', 'Position courante dans le fichier.');
 ReturnAdd('Length', 'Longueur de la chaine ou du tableau.');
 ReturnAdd('Pos', 'Position de la sous-chaine trouvee, ou 0 si absente.');
 ReturnAdd('ParamCount', 'Nombre d arguments passes sur la ligne de commande.');
 ReturnAdd('ParamStr', 'Argument demande de la ligne de commande.');
End;

{ @description: Ajoute une entree a la table des verbes prefixes de
    nom de fonction/procedure (ex: 'Init' -> 'initialiser').
  @param Mot Prefixe (sans tenir compte de la casse)
  @param Phrase Tournure verbale francaise associee }
Procedure PrefixAdd(Mot, Phrase: String);
Begin
 If PrefixCount < MaxVerbs Then Begin
  Inc(PrefixCount);
  PrefixVerbs[PrefixCount].Mot    := Mot;
  PrefixVerbs[PrefixCount].Phrase := Phrase;
 End;
End;

{ @description: Ajoute une entree a la table des verbes suffixes de
    nom de fonction/procedure (ex: 'Exists' -> 'verifie si ... existe').
  @param Mot Suffixe (sans tenir compte de la casse)
  @param Phrase Tournure verbale francaise associee }
Procedure SuffixAdd(Mot, Phrase: String);
Begin
 If SuffixCount < MaxVerbs Then Begin
  Inc(SuffixCount);
  SuffixVerbs[SuffixCount].Mot    := Mot;
  SuffixVerbs[SuffixCount].Phrase := Phrase;
 End;
End;

{ @description: Cherche si Name commence par un prefixe verbe connu
    sur une frontiere de mot propre (la lettre suivante est en
    majuscule, ou il ne reste rien apres le prefixe).
  @param Name Nom complet a analyser
  @param Rest Partie de Name suivant le prefixe trouve (sortie)
  @return Tournure verbale francaise, ou chaine vide si aucun prefixe
    connu ne correspond }
Function FindPrefixVerb(Name: String; Var Rest: String): String;
Var
 I, L: Integer;
Begin
 FindPrefixVerb := '';
 Rest := Name;
 For I := 1 To PrefixCount Do Begin
  L := Length(PrefixVerbs[I].Mot);
  If (Length(Name) >= L) And
     (UpStr(Copy(Name, 1, L)) = UpStr(PrefixVerbs[I].Mot)) And
     ((Length(Name) = L) Or (Name[L + 1] In ['A'..'Z', '_'])) Then Begin
   FindPrefixVerb := PrefixVerbs[I].Phrase;
   Rest := Copy(Name, L + 1, Length(Name) - L);
   If (Length(Rest) > 0) And (Rest[1] = '_') Then Delete(Rest, 1, 1);
   Exit;
  End;
 End;
End;

{ @description: Cherche si Name se termine par un suffixe verbe connu
    sur une frontiere de mot propre.
  @param Name Nom complet a analyser
  @param Rest Partie de Name precedant le suffixe trouve (sortie)
  @return Tournure verbale francaise, ou chaine vide si aucun suffixe
    connu ne correspond }
Function FindSuffixVerb(Name: String; Var Rest: String): String;
Var
 I, L: Integer;
Begin
 FindSuffixVerb := '';
 Rest := Name;
 For I := 1 To SuffixCount Do Begin
  L := Length(SuffixVerbs[I].Mot);
  If (Length(Name) > L) And
     (UpStr(Copy(Name, Length(Name) - L + 1, L)) =
      UpStr(SuffixVerbs[I].Mot)) Then Begin
   FindSuffixVerb := SuffixVerbs[I].Phrase;
   Rest := Copy(Name, 1, Length(Name) - L);
   Exit;
  End;
 End;
End;

{ ============================================================
  DECOUPAGE D UN IDENTIFICATEUR EN MOTS (CamelCase / underscore)
  ============================================================ }

{ @description: Decoupe un identificateur en mots simples, sur les
    underscores et les frontieres minuscule->majuscule (CamelCase).
  @param Name Identificateur a decouper
  @param Words Tableau recevant les mots trouves (sortie)
  @param WCount Nombre de mots places dans Words (sortie) }
Procedure SplitWords(Name: String; Var Words: Array Of String;
 Var WCount: Integer);
Var
 I, Start: Integer;
Begin
 WCount := 0;
 Start := 1;
 I := 1;
 While I <= Length(Name) Do Begin
  If Name[I] = '_' Then Begin
   If (I > Start) And (WCount <= High(Words)) Then Begin
    Words[WCount] := Copy(Name, Start, I - Start);
    Inc(WCount);
   End;
   Start := I + 1;
  End Else If (I > Start) And (Name[I] In ['A'..'Z']) And
   (Name[I - 1] In ['a'..'z', '0'..'9']) Then Begin
   If WCount <= High(Words) Then Begin
    Words[WCount] := Copy(Name, Start, I - Start);
    Inc(WCount);
   End;
   Start := I;
  End;
  Inc(I);
 End;
 If (Start <= Length(Name)) And (WCount <= High(Words)) Then Begin
  Words[WCount] := Copy(Name, Start, Length(Name) - Start + 1);
  Inc(WCount);
 End;
End;

{ @description: Decompose un identificateur inconnu en mots et
    assemble les significations trouvees dans le dictionnaire pour
    chacun d eux.
  @param Name Identificateur a decomposer
  @return Phrase assemblee, ou chaine vide si aucun mot n est connu }
Function DecomposeToPhrase(Name: String): String;
Var
 Words: Array[0..MaxWords - 1] Of String;
 WCount, I: Integer;
 D, Res: String;
Begin
 SplitWords(Name, Words, WCount);
 Res := '';
 For I := 0 To WCount - 1 Do Begin
  D := DictFind(Words[I]);
  If D <> '' Then Begin
   If Res <> '' Then Res := Res + ' ';
   Res := Res + D;
  End;
 End;
 DecomposeToPhrase := Res;
End;

{ @description: Trouve ou deduit la signification d un identificateur
    simple (champ, constante, parametre, variable) : recherche
    exacte, puis decomposition en mots, puis description generique
    honnete si rien n est trouve.
  @param Name Identificateur a decrire
  @param Generic Libelle generique a utiliser en dernier recours
    (ex: 'Champ', 'Constante', 'Parametre')
  @return Description francaise pour ce nom }
Function DescribeSimple(Name, Generic: String): String;
Var
 D: String;
Begin
 D := DictFind(Name);
 If D = '' Then D := DecomposeToPhrase(Name);
 If D = '' Then D := Generic + ' ' + Name;
 DescribeSimple := D;
End;

{ @description: Trouve ou deduit la signification d un champ ou d une
    variable : recherche exacte du nom, puis decomposition en mots,
    puis repli sur le type declare (utile pour les noms courts et
    opaques comme F, S ou P, dont le sens vient du type, ex: F:File).
  @param Name Identificateur a decrire
  @param TypeText Texte du type declare (entre les deux points et le
    point-virgule), utilise en dernier recours avant le repli
    generique
  @return Description francaise pour ce champ ou cette variable }
Function DescribeField(Name, TypeText: String): String;
Var
 D, BaseType: String;
 P: Integer;
Begin
 D := DictFind(Name);
 If D = '' Then D := DecomposeToPhrase(Name);
 If D = '' Then Begin
  BaseType := TrimStr(TypeText);
  P := Length(BaseType);
  While (P >= 1) And (BaseType[P] <> ' ') Do Dec(P);
  BaseType := Copy(BaseType, P + 1, Length(BaseType) - P);
  D := DictFind(BaseType);
 End;
 If D = '' Then D := 'Variable ' + Name;
 DescribeField := D;
End;

{ @description: Construit la phrase d action d une fonction ou
    procedure a partir de son nom : recherche exacte dans le
    dictionnaire, puis verbe en prefixe, puis verbe en suffixe, puis
    decomposition generique.
  @param Name Nom de la fonction ou procedure
  @return Phrase decrivant l action realisee }
Function BuildActionPhrase(Name: String): String;
Var
 D, VerbPhrase, Rest, Tail: String;
Begin
 D := DictFind(Name);
 If D <> '' Then Begin
  BuildActionPhrase := D;
  Exit;
 End;
 VerbPhrase := FindPrefixVerb(Name, Rest);
 If VerbPhrase = '' Then VerbPhrase := FindSuffixVerb(Name, Rest);
 If VerbPhrase <> '' Then Begin
  Tail := DictFind(Rest);
  If Tail = '' Then Tail := DecomposeToPhrase(Rest);
  If Tail <> '' Then
   BuildActionPhrase := VerbPhrase + ' ' + LowStr(Tail)
  Else
   BuildActionPhrase := VerbPhrase;
  Exit;
 End;
 D := DecomposeToPhrase(Name);
 If D <> '' Then
  BuildActionPhrase := 'la fonctionnalite ' + LowStr(D)
 Else
  BuildActionPhrase := 'l operation ' + Name;
End;

{ ============================================================
  CHARGEMENT DU DICTIONNAIRE (amorce interne + fichier externe)
  ============================================================ }

{ @description: Remplit la table des verbes-prefixes les plus
    courants dans les noms de fonctions/procedures Pascal, C et C#. }
Procedure InitPrefixVerbs;
Begin
 PrefixCount := 0;
 PrefixAdd('Init', 'initialise');
 PrefixAdd('Initialize', 'initialise');
 PrefixAdd('Create', 'cree');
 PrefixAdd('Destroy', 'detruit');
 PrefixAdd('Free', 'libere');
 PrefixAdd('Dispose', 'libere');
 PrefixAdd('Alloc', 'alloue');
 PrefixAdd('Allocate', 'alloue');
 PrefixAdd('Get', 'obtient');
 PrefixAdd('Set', 'definit');
 PrefixAdd('Draw', 'dessine');
 PrefixAdd('Paint', 'dessine');
 PrefixAdd('Render', 'affiche');
 PrefixAdd('Show', 'affiche');
 PrefixAdd('Hide', 'cache');
 PrefixAdd('Handle', 'traite');
 PrefixAdd('Process', 'traite');
 PrefixAdd('Load', 'charge');
 PrefixAdd('Save', 'enregistre');
 PrefixAdd('Read', 'lit');
 PrefixAdd('Write', 'ecrit');
 PrefixAdd('Open', 'ouvre');
 PrefixAdd('Close', 'ferme');
 PrefixAdd('Mount', 'monte');
 PrefixAdd('Unmount', 'demonte');
 PrefixAdd('Find', 'recherche');
 PrefixAdd('Search', 'recherche');
 PrefixAdd('Check', 'verifie');
 PrefixAdd('Validate', 'valide');
 PrefixAdd('Verify', 'verifie');
 PrefixAdd('Update', 'met a jour');
 PrefixAdd('Refresh', 'rafraichit');
 PrefixAdd('Clear', 'efface');
 PrefixAdd('Reset', 'reinitialise');
 PrefixAdd('Build', 'construit');
 PrefixAdd('Parse', 'analyse');
 PrefixAdd('Scan', 'analyse');
 PrefixAdd('Convert', 'convertit');
 PrefixAdd('Compute', 'calcule');
 PrefixAdd('Calculate', 'calcule');
 PrefixAdd('Execute', 'execute');
 PrefixAdd('Run', 'execute');
 PrefixAdd('Start', 'demarre');
 PrefixAdd('Stop', 'arrete');
 PrefixAdd('Pause', 'met en pause');
 PrefixAdd('Resume', 'reprend');
 PrefixAdd('Add', 'ajoute');
 PrefixAdd('Append', 'ajoute a la fin de');
 PrefixAdd('Remove', 'retire');
 PrefixAdd('Delete', 'supprime');
 PrefixAdd('Erase', 'efface');
 PrefixAdd('Insert', 'insere');
 PrefixAdd('Copy', 'copie');
 PrefixAdd('Move', 'deplace');
 PrefixAdd('Send', 'envoie');
 PrefixAdd('Receive', 'recoit');
 PrefixAdd('Format', 'formate');
 PrefixAdd('Resolve', 'resout');
 PrefixAdd('Detect', 'detecte');
 PrefixAdd('Toggle', 'bascule');
 PrefixAdd('Enable', 'active');
 PrefixAdd('Disable', 'desactive');
 PrefixAdd('Switch', 'bascule');
 PrefixAdd('Compare', 'compare');
 PrefixAdd('Sort', 'trie');
 PrefixAdd('Extract', 'extrait');
 PrefixAdd('Encode', 'encode');
 PrefixAdd('Decode', 'decode');
 PrefixAdd('Translate', 'traduit');
 PrefixAdd('Apply', 'applique');
 PrefixAdd('Register', 'enregistre');
 PrefixAdd('Unregister', 'retire l enregistrement de');
 PrefixAdd('Is', 'indique si');
 PrefixAdd('Has', 'indique si');
 PrefixAdd('Can', 'indique si');
 PrefixAdd('Show', 'affiche');
 PrefixAdd('New', 'cree');
 PrefixAdd('Make', 'cree');
 PrefixAdd('Term', 'termine');
 PrefixAdd('Begin', 'demarre');
 PrefixAdd('End', 'termine');
 PrefixAdd('Push', 'empile');
 PrefixAdd('Pop', 'depile');
 PrefixAdd('Wait', 'attend');
 PrefixAdd('Lock', 'verrouille');
 PrefixAdd('Unlock', 'deverrouille');
 PrefixAdd('Bind', 'associe');
 PrefixAdd('Unbind', 'dissocie');
 PrefixAdd('Connect', 'connecte');
 PrefixAdd('Disconnect', 'deconnecte');
 PrefixAdd('Open', 'ouvre');
 PrefixAdd('Test', 'teste');
End;

{ @description: Remplit la table des verbes-suffixes les plus
    courants dans les noms de fonctions/procedures (souvent des noms
    de fonctions booleennes, ex: FileExists). }
Procedure InitSuffixVerbs;
Begin
 SuffixCount := 0;
 SuffixAdd('Exists', 'verifie si existe :');
 SuffixAdd('Changed', 'indique si a change :');
 SuffixAdd('Found', 'indique si a ete trouve :');
 SuffixAdd('Valid', 'indique si est valide :');
 SuffixAdd('Ready', 'indique si est pret :');
 SuffixAdd('Done', 'indique si est termine :');
 SuffixAdd('Failed', 'indique si a echoue :');
 SuffixAdd('Visible', 'indique si est visible :');
 SuffixAdd('Enabled', 'indique si est active :');
 SuffixAdd('Active', 'indique si est actif :');
 SuffixAdd('Open', 'indique si est ouvert :');
 SuffixAdd('Mounted', 'indique si est monte :');
 SuffixAdd('Empty', 'indique si est vide :');
 SuffixAdd('Equal', 'compare l egalite de :');
 SuffixAdd('Supported', 'indique si est pris en charge :');
End;

{ @description: Remplit le dictionnaire interne d amorce (mots-cles,
    types, fonctions standards Pascal/C/C# et abreviations de
    variables les plus courantes). Cette table est completee par le
    fichier externe COMMENT.DIC s il existe (voir LoadExternalDict). }
Procedure InitBuiltinDict;
Begin
 DictCount := 0;

 { --- Types et mots-cles courants --- }
 DictAdd('Integer',  'Entier signe');
 DictAdd('LongInt',  'Entier long signe (32 bits)');
 DictAdd('ShortInt', 'Entier court signe (8 bits)');
 DictAdd('SmallInt', 'Entier signe (16 bits)');
 DictAdd('Word',     'Entier non signe (16 bits)');
 DictAdd('Byte',     'Entier non signe (8 bits)');
 DictAdd('Cardinal', 'Entier non signe (32 bits)');
 DictAdd('Boolean',  'Valeur logique (vrai ou faux)');
 DictAdd('Char',     'Caractere');
 DictAdd('String',   'Chaine de caracteres');
 DictAdd('PChar',    'Pointeur sur une chaine terminee par zero');
 DictAdd('Real',     'Nombre reel');
 DictAdd('Double',   'Nombre reel double precision');
 DictAdd('Single',   'Nombre reel simple precision');
 DictAdd('Pointer',  'Pointeur generique');
 DictAdd('File',     'Descripteur de fichier');
 DictAdd('Text',     'Fichier texte');
 DictAdd('Array',    'Tableau');
 DictAdd('Record',   'Enregistrement');
 DictAdd('Set',      'Ensemble');
 DictAdd('Object',   'Objet');
 DictAdd('Class',    'Classe');

 { --- Fonctions/procedures standards Pascal/TP/FPC --- }
 DictAdd('FileExists', 'Cette fonction permet de verifier si le fichier existe.');
 DictAdd('DirectoryExists', 'Cette fonction permet de verifier si le repertoire existe.');
 DictAdd('Assign',   'Cette procedure permet d associer un descripteur de fichier a un nom de fichier sur le disque.');
 DictAdd('Reset',    'Cette procedure permet d ouvrir un fichier existant en lecture (ou lecture/ecriture).');
 DictAdd('Rewrite',  'Cette procedure permet de creer un nouveau fichier (vide) et de l ouvrir en ecriture.');
 DictAdd('Append',   'Cette procedure permet d ouvrir un fichier texte en ajout, a la fin du contenu existant.');
 DictAdd('Close',    'Cette procedure permet de fermer un fichier ouvert.');
 DictAdd('Erase',    'Cette procedure permet de supprimer un fichier du disque.');
 DictAdd('Rename',   'Cette procedure permet de renommer un fichier sur le disque.');
 DictAdd('BlockRead',  'Cette procedure permet de lire un bloc d octets depuis un fichier.');
 DictAdd('BlockWrite', 'Cette procedure permet d ecrire un bloc d octets dans un fichier.');
 DictAdd('Seek',     'Cette procedure permet de deplacer la position courante dans un fichier.');
 DictAdd('FileSize', 'Cette fonction permet d obtenir la taille en octets d un fichier ouvert.');
 DictAdd('FilePos',  'Cette fonction permet d obtenir la position courante dans un fichier ouvert.');
 DictAdd('Eof',      'Cette fonction permet de verifier si la fin du fichier est atteinte.');
 DictAdd('Eoln',     'Cette fonction permet de verifier si la fin de la ligne courante est atteinte.');
 DictAdd('ReadLn',   'Cette procedure permet de lire une ligne de texte.');
 DictAdd('WriteLn',  'Cette procedure permet d ecrire une ligne de texte.');
 DictAdd('GetMem',   'Cette procedure permet d allouer un bloc de memoire.');
 DictAdd('FreeMem',  'Cette procedure permet de liberer un bloc de memoire alloue.');
 DictAdd('New',      'Cette procedure permet d allouer dynamiquement une nouvelle instance.');
 DictAdd('Dispose',  'Cette procedure permet de liberer une instance allouee dynamiquement.');
 DictAdd('Move',     'Cette procedure permet de copier un bloc d octets en memoire.');
 DictAdd('FillChar', 'Cette procedure permet de remplir un bloc memoire avec un octet donne.');
 DictAdd('Length',   'Cette fonction permet d obtenir la longueur d une chaine ou d un tableau.');
 DictAdd('Copy',     'Cette fonction permet d extraire une sous-chaine ou une portion d un tableau.');
 DictAdd('Pos',      'Cette fonction permet de trouver la position d une sous-chaine.');
 DictAdd('Delete',   'Cette procedure permet de retirer une partie d une chaine.');
 DictAdd('Insert',   'Cette procedure permet d inserer une chaine dans une autre.');
 DictAdd('UpCase',   'Cette fonction permet de convertir un caractere en majuscule.');
 DictAdd('Chr',      'Cette fonction permet d obtenir le caractere correspondant a un code ASCII.');
 DictAdd('Ord',      'Cette fonction permet d obtenir le code ordinal d une valeur.');
 DictAdd('Val',      'Cette procedure permet de convertir une chaine en valeur numerique.');
 DictAdd('Str',      'Cette procedure permet de convertir une valeur numerique en chaine.');
 DictAdd('IntToStr', 'Cette fonction permet de convertir un entier en chaine de caracteres.');
 DictAdd('StrToInt', 'Cette fonction permet de convertir une chaine de caracteres en entier.');
 DictAdd('ParamStr', 'Cette fonction permet d obtenir un argument de la ligne de commande.');
 DictAdd('ParamCount', 'Cette fonction permet d obtenir le nombre d arguments de la ligne de commande.');
 DictAdd('Halt',     'Cette procedure permet d arreter immediatement le programme.');
 DictAdd('GetDir',   'Cette procedure permet d obtenir le repertoire courant.');
 DictAdd('ChDir',    'Cette procedure permet de changer de repertoire courant.');
 DictAdd('MkDir',    'Cette procedure permet de creer un repertoire.');
 DictAdd('RmDir',    'Cette procedure permet de supprimer un repertoire.');
 DictAdd('FindFirst', 'Cette procedure permet de demarrer une recherche de fichiers.');
 DictAdd('FindNext', 'Cette procedure permet de poursuivre une recherche de fichiers.');
 DictAdd('FindClose', 'Cette procedure permet de terminer une recherche de fichiers.');
 DictAdd('IOResult', 'Cette fonction permet d obtenir le code d erreur de la derniere operation d entree/sortie.');
 DictAdd('Random',   'Cette fonction permet d obtenir un nombre aleatoire.');
 DictAdd('Randomize', 'Cette procedure permet d initialiser le generateur de nombres aleatoires.');
 DictAdd('Sqrt',     'Cette fonction permet de calculer la racine carree.');
 DictAdd('Abs',      'Cette fonction permet d obtenir la valeur absolue.');
 DictAdd('Trunc',    'Cette fonction permet de tronquer un nombre reel en entier.');
 DictAdd('Round',    'Cette fonction permet d arrondir un nombre reel en entier.');

 { --- Abreviations et noms de variables/champs courants --- }
 DictAdd('I', 'Compteur de boucle');
 DictAdd('J', 'Compteur de boucle (boucle imbriquee)');
 DictAdd('K', 'Compteur de boucle (boucle imbriquee)');
 DictAdd('Idx', 'Index');
 DictAdd('Index', 'Index');
 DictAdd('Cnt', 'Compteur');
 DictAdd('Count', 'Compteur');
 DictAdd('Buf', 'Tampon');
 DictAdd('Buffer', 'Tampon');
 DictAdd('Ptr', 'Pointeur');
 DictAdd('Tmp', 'Variable temporaire');
 DictAdd('Temp', 'Variable temporaire');
 DictAdd('Flag', 'Indicateur');
 DictAdd('Size', 'Taille');
 DictAdd('Len', 'Longueur');
 DictAdd('Name', 'Nom');
 DictAdd('FileName', 'Nom du fichier');
 DictAdd('DirName', 'Nom du repertoire');
 DictAdd('PathName', 'Nom du chemin');
 DictAdd('SrcName', 'Nom du fichier source');
 DictAdd('DestName', 'Nom du fichier destination');
 DictAdd('ErrorMsg', 'Message d erreur');
 DictAdd('ErrMsg', 'Message d erreur');
 DictAdd('UserName', 'Nom d utilisateur');
 DictAdd('Path', 'Chemin');
 DictAdd('Dir', 'Repertoire');
 DictAdd('Directory', 'Repertoire');
 DictAdd('Drive', 'Lecteur');
 DictAdd('Disk', 'Disque');
 DictAdd('Result', 'Resultat');
 DictAdd('Res', 'Resultat');
 DictAdd('Err', 'Erreur');
 DictAdd('Error', 'Erreur');
 DictAdd('Msg', 'Message');
 DictAdd('Message', 'Message');
 DictAdd('Val', 'Valeur');
 DictAdd('Value', 'Valeur');
 DictAdd('Pos', 'Position');
 DictAdd('Position', 'Position');
 DictAdd('Start', 'Debut');
 DictAdd('Stop', 'Fin');
 DictAdd('Max', 'Valeur maximale');
 DictAdd('Min', 'Valeur minimale');
 DictAdd('Total', 'Total');
 DictAdd('Sum', 'Somme');
 DictAdd('List', 'Liste');
 DictAdd('Item', 'Element');
 DictAdd('Node', 'Noeud');
 DictAdd('Next', 'Element suivant');
 DictAdd('Prev', 'Element precedent');
 DictAdd('Head', 'Tete de liste');
 DictAdd('Tail', 'Queue de liste');
 DictAdd('Data', 'Donnees');
 DictAdd('Info', 'Information');
 DictAdd('Kind', 'Genre/type');
 DictAdd('Mode', 'Mode');
 DictAdd('State', 'Etat');
 DictAdd('Status', 'Statut');
 DictAdd('Color', 'Couleur');
 DictAdd('Width', 'Largeur');
 DictAdd('Height', 'Hauteur');
 DictAdd('Top', 'Position haute');
 DictAdd('Left', 'Position gauche');
 DictAdd('Right', 'Position droite');
 DictAdd('Bottom', 'Position basse');
 DictAdd('Row', 'Ligne');
 DictAdd('Col', 'Colonne');
 DictAdd('Column', 'Colonne');
 DictAdd('Line', 'Ligne');
 DictAdd('Bit', 'Bit');
 DictAdd('Mask', 'Masque');
 DictAdd('Offset', 'Decalage');
 DictAdd('Base', 'Base');
 DictAdd('Addr', 'Adresse');
 DictAdd('Address', 'Adresse');
 DictAdd('Handle', 'Descripteur (handle)');
 DictAdd('Id', 'Identifiant');
 DictAdd('Code', 'Code');
 DictAdd('Key', 'Cle');
 DictAdd('Table', 'Table');
 DictAdd('Sector', 'Secteur');
 DictAdd('Cluster', 'Cluster');
 DictAdd('Track', 'Piste');
 DictAdd('Block', 'Bloc');
 DictAdd('Page', 'Page');
 DictAdd('Segment', 'Segment');
 DictAdd('Memory', 'Memoire');
 DictAdd('Stack', 'Pile');
 DictAdd('Heap', 'Tas');
 DictAdd('Window', 'Fenetre');
 DictAdd('Dialog', 'Boite de dialogue');
 DictAdd('Button', 'Bouton');
 DictAdd('Menu', 'Menu');
 DictAdd('Form', 'Formulaire');
 DictAdd('Panel', 'Panneau');
 DictAdd('Field', 'Champ');
 DictAdd('Param', 'Parametre');
 DictAdd('Parameter', 'Parametre');
 DictAdd('Arg', 'Argument');
 DictAdd('Argument', 'Argument');
 DictAdd('Source', 'Source');
 DictAdd('Src', 'Source');
 DictAdd('Dest', 'Destination');
 DictAdd('Destination', 'Destination');
 DictAdd('Target', 'Cible');
 DictAdd('Input', 'Entree');
 DictAdd('Output', 'Sortie');
 DictAdd('Old', 'Ancienne valeur');
 DictAdd('Cur', 'Valeur courante');
 DictAdd('Current', 'Valeur courante');
 DictAdd('Last', 'Derniere valeur');
 DictAdd('First', 'Premiere valeur');
 DictAdd('Default', 'Valeur par defaut');
 DictAdd('User', 'Utilisateur');
 DictAdd('Host', 'Hote');
 DictAdd('Client', 'Client');
 DictAdd('Server', 'Serveur');
 DictAdd('Request', 'Requete');
 DictAdd('Response', 'Reponse');
 DictAdd('Reply', 'Reponse');
 DictAdd('Version', 'Version');
 DictAdd('Date', 'Date');
 DictAdd('Time', 'Heure');
 DictAdd('Timestamp', 'Horodatage');
 DictAdd('Duration', 'Duree');
 DictAdd('Timeout', 'Delai d expiration');
 DictAdd('Delay', 'Delai');
 DictAdd('Speed', 'Vitesse');
 DictAdd('Rate', 'Taux');
 DictAdd('Ratio', 'Ratio');
 DictAdd('Percent', 'Pourcentage');
 DictAdd('Level', 'Niveau');
 DictAdd('Depth', 'Profondeur');
 DictAdd('Priority', 'Priorite');
 DictAdd('Order', 'Ordre');
 DictAdd('Width', 'Largeur');
 DictAdd('Scroll', 'Defilement');
 DictAdd('Top', 'Sommet/haut');
 DictAdd('Visible', 'Visibilite');
 DictAdd('Enabled', 'Etat actif/inactif');
 DictAdd('Active', 'Etat actif');
 DictAdd('Selected', 'Element selectionne');
 DictAdd('Focus', 'Focus (element actif)');
 DictAdd('Title', 'Titre');
 DictAdd('Caption', 'Legende/texte affiche');
 DictAdd('Label', 'Etiquette');
 DictAdd('Text', 'Texte');
 DictAdd('Char', 'Caractere');
 DictAdd('Str', 'Chaine de caracteres');
 DictAdd('Ext', 'Extension de fichier');
 DictAdd('Filter', 'Filtre');
 DictAdd('Type', 'Type');
 DictAdd('Class', 'Classe');
 DictAdd('Tag', 'Etiquette/marqueur numerique');
 DictAdd('Attr', 'Attribut');
 DictAdd('Attribute', 'Attribut');
End;

{ @description: Charge le dictionnaire externe COMMENT.DIC (s il
    existe dans le repertoire courant) et l ajoute au dictionnaire
    deja charge. Format attendu : une entree par ligne "Nom=Description",
    les lignes vides ou commencant par ';' ou '#' sont ignorees. }
Procedure LoadExternalDict;
Var
 F: Text;
 S, Nom, Desc: String;
 P: Integer;
 IOErr: Integer;
Begin
 {$I-}
 Assign(F, DictFileName);
 Reset(F);
 IOErr := IOResult;
 {$I+}
 If IOErr <> 0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F, S);
  S := TrimStr(S);
  If (S = '') Or (S[1] = ';') Or (S[1] = '#') Then Continue;
  P := Pos('=', S);
  If P > 1 Then Begin
   Nom  := TrimStr(Copy(S, 1, P - 1));
   Desc := TrimStr(Copy(S, P + 1, Length(S) - P));
   If (Nom <> '') And (Desc <> '') Then DictAdd(Nom, Desc);
  End;
 End;
 Close(F);
End;

{ ============================================================
  ANALYSE D UNE LIGNE SOURCE (commentaires existants, type de
  declaration). Ces fonctions sont utilisees pour les trois langages.
  ============================================================ }

{ @description: Indique si une ligne, une fois nettoyee des espaces,
    est entierement vide.
  @param S Ligne a tester
  @return Vrai si la ligne ne contient que des espaces }
Function IsBlankLine(S: String): Boolean;
Begin
 IsBlankLine := (TrimStr(S) = '');
End;

{ @description: Indique si une ligne (deja nettoyee) ressemble a la
    fin d un commentaire deja present, pour les trois styles
    rencontres (accolades Pascal, /* */ C/C++/C# et //).
  @param S Ligne nettoyee a tester
  @return Vrai si la ligne se termine par un commentaire }
Function LooksLikeCommentEnd(S: String): Boolean;
Begin
 LooksLikeCommentEnd :=
  EndsWithStr(S, '}') Or EndsWithStr(S, '*/') Or
  StartsWithStr(S, '//') Or StartsWithStr(S, '{') Or
  StartsWithStr(S, '(*') Or StartsWithStr(S, '*');
End;

{ @description: Indique si la declaration commencant a la ligne
    LineIdx est deja precedee d un commentaire (en remontant au-dela
    des lignes vides, et des lignes d attributs/directives qui
    n empechent pas de retrouver un commentaire plus haut).
  @param LineIdx Numero (1-based) de la ligne de la declaration
  @return Vrai si une ligne de commentaire precede la declaration }
Function HasPrecedingComment(LineIdx: Integer): Boolean;
Var
 K: Integer;
 S: String;
Begin
 HasPrecedingComment := False;
 K := LineIdx - 1;
 While (K >= 1) And IsBlankLine(Lines[K]) Do Dec(K);
 If K < 1 Then Exit;
 S := TrimStr(Lines[K]);
 HasPrecedingComment := LooksLikeCommentEnd(S);
End;

{ @description: Indique si une ligne contient deja un commentaire en
    fin de ligne (apres le dernier point-virgule), pour les trois
    styles de commentaire rencontres.
  @param S Ligne a tester
  @return Vrai si un commentaire de fin de ligne est present }
Function HasTrailingComment(S: String): Boolean;
Begin
 HasTrailingComment :=
  (Pos('{', S) > 0) Or (Pos('//', S) > 0) Or (Pos('/*', S) > 0);
End;

{ ============================================================
  GENERATION DES BLOCS DE COMMENTAIRE
  ============================================================ }

{ @description: Decoupe une liste de noms separes par des virgules
    (ex: "A, B, C" provenant d un champ "A, B, C: Integer;") en
    identificateurs individuels.
  @param NamesPart Texte contenant les noms separes par des virgules
  @param Names Tableau recevant les noms trouves (sortie)
  @param NCount Nombre de noms places dans Names (sortie) }
Procedure SplitNameList(NamesPart: String; Var Names: Array Of String;
 Var NCount: Integer);
Var
 J: Integer;
 Cur: String;
Begin
 NCount := 0;
 Cur := '';
 For J := 1 To Length(NamesPart) Do Begin
  If NamesPart[J] = ',' Then Begin
   Cur := TrimStr(Cur);
   If (Cur <> '') And (NCount <= High(Names)) Then Begin
    Names[NCount] := Cur;
    Inc(NCount);
   End;
   Cur := '';
  End Else
   Cur := Cur + NamesPart[J];
 End;
 Cur := TrimStr(Cur);
 If (Cur <> '') And (NCount <= High(Names)) Then Begin
  Names[NCount] := Cur;
  Inc(NCount);
 End;
End;

{ @description: Extrait les noms de parametres d une liste de
    parametres Pascal (entre parentheses), en ignorant les mots-cles
    Var/Const/Out et les types. Les groupes "A, B: Integer" sont
    decomposes en plusieurs noms.
  @param ParamList Texte de la liste de parametres (sans les
    parentheses)
  @param Names Tableau recevant les noms trouves (sortie)
  @param NCount Nombre de noms places dans Names (sortie) }
Procedure ExtractPascalParamNames(ParamList: String;
 Var Names: Array Of String; Var NCount: Integer);
Var
 Groups: Array[0..MaxParams - 1] Of String;
 GCount, I, P: Integer;
 G, NamesPart, Cur: String;
Begin
 NCount := 0;
 GCount := 0;
 G := '';
 For I := 1 To Length(ParamList) Do Begin
  If ParamList[I] = ';' Then Begin
   If GCount <= High(Groups) Then Begin
    Groups[GCount] := G;
    Inc(GCount);
   End;
   G := '';
  End Else
   G := G + ParamList[I];
 End;
 If TrimStr(G) <> '' Then Begin
  If GCount <= High(Groups) Then Begin
   Groups[GCount] := G;
   Inc(GCount);
  End;
 End;
 For I := 0 To GCount - 1 Do Begin
  G := TrimStr(Groups[I]);
  P := Pos(':', G);
  If P > 0 Then NamesPart := Copy(G, 1, P - 1) Else NamesPart := G;
  If StartsWithStr(NamesPart, 'Var ') Then Delete(NamesPart, 1, 4);
  If StartsWithStr(NamesPart, 'Const ') Then Delete(NamesPart, 1, 6);
  If StartsWithStr(NamesPart, 'Out ') Then Delete(NamesPart, 1, 4);
  Cur := '';
  For P := 1 To Length(NamesPart) Do Begin
   If NamesPart[P] = ',' Then Begin
    Cur := TrimStr(Cur);
    If (Cur <> '') And (NCount <= High(Names)) Then Begin
     Names[NCount] := Cur;
     Inc(NCount);
    End;
    Cur := '';
   End Else
    Cur := Cur + NamesPart[P];
  End;
  Cur := TrimStr(Cur);
  If (Cur <> '') And (NCount <= High(Names)) Then Begin
   Names[NCount] := Cur;
   Inc(NCount);
  End;
 End;
End;

{ @description: Extrait les noms de parametres d une liste de
    parametres C ou C# (entre parentheses), un type suivi d un nom par
    groupe separe par des virgules.
  @param ParamList Texte de la liste de parametres (sans les
    parentheses)
  @param Names Tableau recevant les noms trouves (sortie)
  @param NCount Nombre de noms places dans Names (sortie) }
Procedure ExtractCParamNames(ParamList: String;
 Var Names: Array Of String; Var NCount: Integer);
Var
 Groups: Array[0..MaxParams - 1] Of String;
 GCount, I, P: Integer;
 G, Nm: String;
Begin
 NCount := 0;
 GCount := 0;
 G := '';
 For I := 1 To Length(ParamList) Do Begin
  If ParamList[I] = ',' Then Begin
   If GCount <= High(Groups) Then Begin
    Groups[GCount] := G;
    Inc(GCount);
   End;
   G := '';
  End Else
   G := G + ParamList[I];
 End;
 If TrimStr(G) <> '' Then Begin
  If GCount <= High(Groups) Then Begin
   Groups[GCount] := G;
   Inc(GCount);
  End;
 End;
 For I := 0 To GCount - 1 Do Begin
  G := TrimStr(Groups[I]);
  { Retirer un eventuel '=valeur_par_defaut' ou '*'/'&' final }
  P := Pos('=', G);
  If P > 0 Then G := TrimStr(Copy(G, 1, P - 1));
  { Le nom du parametre est le dernier "mot" identificateur de G }
  Nm := '';
  P := Length(G);
  While (P >= 1) And IsIdentChar(G[P]) Do Begin
   Nm := G[P] + Nm;
   Dec(P);
  End;
  If (Nm <> '') And (NCount <= High(Names)) Then Begin
   Names[NCount] := Nm;
   Inc(NCount);
  End;
 End;
End;

{ @description: Ecrit dans le fichier de sortie un bloc de
    commentaire Pascal "@description/@param/@return" pour une
    fonction ou procedure.
  @param Name Nom de la fonction ou procedure
  @param ParamNames Tableau des noms de parametres
  @param ParamCnt Nombre de parametres dans ParamNames
  @param IsFunc Vrai s il s agit d une fonction (ajoute @return),
    faux pour une procedure }
Procedure EmitPascalDocBlock(Name: String;
 Var ParamNames: Array Of String; ParamCnt: Integer; IsFunc: Boolean);
Var
 I: Integer;
 Kind, Action, DescLine: String;
Begin
 If IsFunc Then Kind := 'fonction' Else Kind := 'procedure';
 Action := BuildActionPhrase(Name);
 { Si BuildActionPhrase a trouve une phrase complete toute faite dans
   le dictionnaire (entree commencant par "Cette "), l utiliser telle
   quelle plutot que de l envelopper une deuxieme fois. }
 If StartsWithStr(Action, 'Cette ') Then
  DescLine := Action
 Else Begin
  DescLine := 'Cette ' + Kind + ' permet de ' + Action;
  If Not EndsWithStr(DescLine, '.') Then DescLine := DescLine + '.';
 End;
 WriteLn(OutF, '{ @description: ', DescLine);
 For I := 0 To ParamCnt - 1 Do Begin
  WriteLn(OutF, '  @param ', ParamNames[I], ' ',
   CapStr(DescribeSimple(ParamNames[I], 'Parametre')));
  Inc(NbParam);
 End;
 If IsFunc Then
  WriteLn(OutF, '  @return ', BuildReturnPhrase(Name), ' }')
 Else
  WriteLn(OutF, '  }');
End;

{ ============================================================
  ANALYSE ET TRAITEMENT D UN FICHIER SOURCE PASCAL
  ============================================================ }

{ @description: Compte le nombre d occurrences d un caractere dans une
    chaine.
  @param S Chaine a analyser
  @param C Caractere a compter
  @return Nombre d occurrences de C dans S }
Function CountChar(S: String; C: Char): Integer;
Var
 I, N: Integer;
Begin
 N := 0;
 For I := 1 To Length(S) Do If S[I] = C Then Inc(N);
 CountChar := N;
End;

{ @description: Cherche, a partir de la ligne Start, la ligne complete
    d une declaration de fonction/procedure Pascal (qui peut s etendre
    sur plusieurs lignes lorsque la liste de parametres est repartie
    sur plusieurs lignes) et renvoie son texte concatene ainsi que la
    derniere ligne qui la compose.
  @param Start Numero (1-based) de la ligne de depart
  @param FullText Texte complet de la declaration (sortie)
  @param LastLine Numero de la derniere ligne de la declaration (sortie) }
Procedure CollectPascalHeader(Start: Integer; Var FullText: String;
 Var LastLine: Integer);
Var
 K: Integer;
 S: String;
Begin
 FullText := '';
 K := Start;
 Repeat
  S := Lines[K];
  FullText := FullText + ' ' + S;
  Inc(K);
 Until (K > LineCount) Or
  ((Pos(';', S) > 0) And
   ((Pos('(', FullText) = 0) Or
    (CountChar(FullText, '(') <= CountChar(FullText, ')'))));
 LastLine := K - 1;
End;

{ @description: A partir du texte complet (une ligne ou plus) d une
    declaration Pascal "Function/Procedure Nom(params): Type;",
    extrait le nom, la liste de parametres et indique s il s agit
    d une fonction.
  @param FullText Texte complet de la declaration
  @param Name Nom de la fonction/procedure (sortie)
  @param ParamList Texte de la liste de parametres, sans les
    parentheses (sortie)
  @param IsFunc Vrai si la declaration commence par "Function" (sortie) }
Procedure ParsePascalHeader(FullText: String; Var Name: String;
 Var ParamList: String; Var IsFunc: Boolean);
Var
 S: String;
 P1, P2, I: Integer;
Begin
 S := TrimStr(FullText);
 IsFunc := StartsWithStr(S, 'Function');
 If IsFunc Then Delete(S, 1, 8) Else Delete(S, 1, 9); { "Procedure" }
 S := TrimStr(S);
 Name := '';
 I := 1;
 While (I <= Length(S)) And IsIdentChar(S[I]) Do Begin
  Name := Name + S[I];
  Inc(I);
 End;
 P1 := Pos('(', S);
 P2 := Pos(')', S);
 { Trouver la parenthese fermante correspondant a P1 (gestion des
   parametres de type procedural eventuels, simplifiee). }
 If (P1 > 0) And (P2 > P1) Then Begin
  P2 := Length(S);
  While (P2 > P1) And (S[P2] <> ')') Do Dec(P2);
  ParamList := Copy(S, P1 + 1, P2 - P1 - 1);
 End Else
  ParamList := '';
End;

{ @description: Traite un fichier source Pascal ligne par ligne et
    ecrit, dans le fichier de sortie deja ouvert, le contenu original
    complete des commentaires manquants selon le mode actif (Mode). }
Procedure ProcessPascalFile;
Var
 I, J, LastLine: Integer;
 S, Trimmed, Up: String;
 InRecord: Boolean;
 RecordTypeName: String;
 FullText, Name, ParamList: String;
 IsFunc: Boolean;
 ParamNames: Array[0..MaxParams - 1] Of String;
 ParamCnt: Integer;
 EqPos, ColonPos, SemiPos: Integer;
 FieldNamesPart, TypeText: String;
 FieldNames: Array[0..7] Of String;
 FNCount: Integer;
 Desc: String;
Begin
 InRecord := False;
 RecordTypeName := '';
 I := 1;
 While I <= LineCount Do Begin
  S := Lines[I];
  Trimmed := TrimStr(S);
  Up := UpStr(Trimmed);

  { ----- Detection d une fonction/procedure ----- }
  If (StartsWithStr(Trimmed, 'Function ') Or
      StartsWithStr(Trimmed, 'Procedure ')) And
     (((Mode And MD_FUNC) <> 0) Or ((Mode And MD_PROC) <> 0) Or
      ((Mode And MD_PARAM) <> 0)) Then Begin
   CollectPascalHeader(I, FullText, LastLine);
   ParsePascalHeader(FullText, Name, ParamList, IsFunc);
   ExtractPascalParamNames(ParamList, ParamNames, ParamCnt);
   If Not HasPrecedingComment(I) Then Begin
    If (IsFunc And ((Mode And MD_FUNC) <> 0)) Or
       ((Not IsFunc) And ((Mode And MD_PROC) <> 0)) Then Begin
     EmitPascalDocBlock(Name, ParamNames, ParamCnt, IsFunc);
     If IsFunc Then Inc(NbFunc) Else Inc(NbProc);
    End;
   End;
   For J := I To LastLine Do WriteLn(OutF, Lines[J]);
   I := LastLine + 1;
   Continue;
  End;

  { ----- Detection du debut d un enregistrement ----- }
  EqPos := Pos('=', Trimmed);
  If (Not InRecord) And (EqPos > 1) And
     (EndsWithStr(UpStr(TrimStr(Copy(Trimmed, EqPos + 1,
       Length(Trimmed) - EqPos))), 'RECORD')) And
     ((Mode And (MD_RECORD Or MD_FIELD)) <> 0) Then Begin
   RecordTypeName := TrimStr(Copy(Trimmed, 1, EqPos - 1));
   If ((Mode And MD_RECORD) <> 0) And (Not HasPrecedingComment(I)) Then Begin
    Desc := DescribeSimple(RecordTypeName, 'Structure');
    WriteLn(OutF, '{ ', CapStr(Desc), ' }');
    Inc(NbRecord);
   End;
   WriteLn(OutF, S);
   InRecord := True;
   Inc(I);
   Continue;
  End;

  { ----- Fin d un enregistrement ----- }
  If InRecord And (Up = 'END;') Then Begin
   InRecord := False;
   WriteLn(OutF, S);
   Inc(I);
   Continue;
  End;

  { ----- Champ d enregistrement ----- }
  ColonPos := Pos(':', Trimmed);
  SemiPos := Pos(';', Trimmed);
  If InRecord And (ColonPos > 0) And (SemiPos > ColonPos) And
     ((Mode And MD_FIELD) <> 0) And (Not HasTrailingComment(S)) Then Begin
   FieldNamesPart := Copy(Trimmed, 1, ColonPos - 1);
   TypeText := Copy(Trimmed, ColonPos + 1, SemiPos - ColonPos - 1);
   SplitNameList(FieldNamesPart, FieldNames, FNCount);
   If FNCount > 0 Then Begin
    Desc := DescribeField(FieldNames[0], TypeText);
    WriteLn(OutF, S, ' { ', Desc, ' }');
    Inc(NbField);
    Inc(I);
    Continue;
   End;
  End;

  { ----- Constante (en dehors d un enregistrement) -----
    Trimmed[EqPos-1]<>':' exclut une affectation "X:=valeur;" sans
    espace, ou EqPos pointerait sur le '=' de ':='. }
  If (Not InRecord) And (EqPos > 1) And (SemiPos > EqPos) And
     IsIdentStart(Trimmed[1]) And ((Mode And MD_CONST) <> 0) And
     (Not HasTrailingComment(S)) And (Trimmed[EqPos - 1] <> ':') And
     (Not ContainsStr(Copy(Trimmed, 1, EqPos - 1), ' ')) Then Begin
   Name := TrimStr(Copy(Trimmed, 1, EqPos - 1));
   Desc := DescribeSimple(Name, 'Constante');
   WriteLn(OutF, S, ' { ', Desc, ' }');
   Inc(NbConst);
   Inc(I);
   Continue;
  End;

  { ----- Variable/champ simple (Var globale ou locale) -----
    Trimmed[ColonPos+1]<>'=' exclut une affectation "X:=valeur;" sans
    espace, ou ColonPos pointerait sur le ':' de ':='. Plusieurs noms
    separes par des virgules (ex: "Size, I, J: Word;") sont
    decomposes via SplitNameList ; seul le premier nom est utilise
    pour deduire la description (les noms suivants partagent le meme
    type et la meme ligne). }
  If (Not InRecord) And (ColonPos > 0) And (SemiPos > ColonPos) And
     IsIdentStart(Trimmed[1]) And ((Mode And MD_FIELD) <> 0) And
     (Not HasTrailingComment(S)) And
     (Trimmed[ColonPos + 1] <> '=') And
     (Not ContainsStr(Trimmed, '(')) Then Begin
   FieldNamesPart := Copy(Trimmed, 1, ColonPos - 1);
   TypeText := Copy(Trimmed, ColonPos + 1, SemiPos - ColonPos - 1);
   SplitNameList(FieldNamesPart, FieldNames, FNCount);
   If FNCount > 0 Then Begin
    Desc := DescribeField(FieldNames[0], TypeText);
    WriteLn(OutF, S, ' { ', Desc, ' }');
    Inc(NbField);
    Inc(I);
    Continue;
   End;
  End;

  WriteLn(OutF, S);
  Inc(I);
 End;
End;

{ ============================================================
  ANALYSE ET TRAITEMENT D UN FICHIER SOURCE C / C++ / C#
  ============================================================ }

{ @description: Indique si une ligne C/C++/C# ressemble a un en-tete
    de fonction ou methode : "[modificateurs] Type Nom(parametres)"
    suivi (sur la meme ligne ou une suivante) de ouvrir accollade ou ';'.
  @param S Ligne nettoyee a tester
  @param Name Nom de la fonction trouve (sortie)
  @param ParamList Liste de parametres trouvee, sans les parentheses
    (sortie)
  @return Vrai si la ligne ressemble a un en-tete de fonction }
Function LooksLikeCFunction(S: String; Var Name: String;
 Var ParamList: String): Boolean;
Var
 P1, P2, I: Integer;
Begin
 LooksLikeCFunction := False;
 P1 := Pos('(', S);
 If P1 <= 1 Then Exit;
 P2 := Length(S);
 While (P2 > P1) And (S[P2] <> ')') Do Dec(P2);
 If P2 <= P1 Then Exit;
 { Le nom est l identificateur juste avant '(' }
 I := P1 - 1;
 While (I >= 1) And (S[I] = ' ') Do Dec(I);
 Name := '';
 While (I >= 1) And IsIdentChar(S[I]) Do Begin
  Name := S[I] + Name;
  Dec(I);
 End;
 If Name = '' Then Exit;
 If (I >= 1) And Not (S[I] In [' ', '*', '&']) Then Exit; { ex: "if (" }
 { Rejeter les mots-cles de controle de flux }
 If (UpStr(Name) = 'IF') Or (UpStr(Name) = 'FOR') Or
    (UpStr(Name) = 'WHILE') Or (UpStr(Name) = 'SWITCH') Or
    (UpStr(Name) = 'CATCH') Or (UpStr(Name) = 'RETURN') Then
  Exit;
 ParamList := Copy(S, P1 + 1, P2 - P1 - 1);
 LooksLikeCFunction := True;
End;

{ @description: Ecrit dans le fichier de sortie un bloc de
    commentaire C/C++/C# (style "/* ... */") pour une fonction ou
    methode.
  @param Name Nom de la fonction ou methode
  @param ParamNames Tableau des noms de parametres
  @param ParamCnt Nombre de parametres dans ParamNames }
Procedure EmitCDocBlock(Name: String; Var ParamNames: Array Of String;
 ParamCnt: Integer; HasReturnValue: Boolean);
Var
 I: Integer;
 Action, DescLine, Kind: String;
Begin
 Action := BuildActionPhrase(Name);
 If HasReturnValue Then Kind := 'fonction' Else Kind := 'methode';
 { Si BuildActionPhrase a trouve une phrase complete toute faite dans
   le dictionnaire (entree commencant par "Cette "), l utiliser telle
   quelle plutot que de l envelopper une deuxieme fois. }
 If StartsWithStr(Action, 'Cette ') Then
  DescLine := Action
 Else Begin
  DescLine := 'Cette ' + Kind + ' permet de ' + Action;
  If Not EndsWithStr(DescLine, '.') Then DescLine := DescLine + '.';
 End;
 WriteLn(OutF, '/* ', DescLine);
 For I := 0 To ParamCnt - 1 Do Begin
  WriteLn(OutF, ' * @param ', ParamNames[I], ' ',
   CapStr(DescribeSimple(ParamNames[I], 'Parametre')));
  Inc(NbParam);
 End;
 If HasReturnValue Then
  WriteLn(OutF, ' * @return ', BuildReturnPhrase(Name));
 WriteLn(OutF, ' */');
End;

{ @description: Traite un fichier source C, C++ ou C# ligne par ligne
    et ecrit, dans le fichier de sortie deja ouvert, le contenu
    original complete des commentaires manquants selon le mode actif
    (Mode). Prend en charge les fonctions/methodes, les constantes
    (#define et "const Type Nom ="), et les champs simples
    "Type Nom;" a l interieur d une structure/classe. }
Procedure ProcessCFile;
Var
 I: Integer;
 S, Trimmed, UpTrim: String;
 Name, ParamList: String;
 ParamNames: Array[0..MaxParams - 1] Of String;
 ParamCnt: Integer;
 Desc, FieldName, TypeWord: String;
 P, SemiPos, Q: Integer;
 BraceDepth: Integer;
 InStruct: Boolean;
 StructEnterDepth: Integer;
Begin
 I := 1;
 BraceDepth := 0;
 InStruct := False;
 StructEnterDepth := 0;
 While I <= LineCount Do Begin
  S := Lines[I];
  Trimmed := TrimStr(S);
  UpTrim := UpStr(Trimmed);

  { ----- Suivi (approximatif) de la profondeur d accolades et des
    structures/classes, pour ne traiter "Type Nom;" comme un champ
    que lorsqu on est directement dans le corps d une structure ou
    d une classe (et non dans le corps d une fonction ou d une
    structure imbriquee, plus profonde). ----- }
  If (Not InStruct) And
     (StartsWithStr(UpTrim, 'STRUCT ') Or StartsWithStr(UpTrim, 'STRUCT{') Or
      (UpTrim = 'STRUCT') Or StartsWithStr(UpTrim, 'CLASS ') Or
      StartsWithStr(UpTrim, 'TYPEDEF STRUCT')) And
     (Pos('(', Trimmed) = 0) And (Pos(';', Trimmed) = 0) Then Begin
   InStruct := True;
   StructEnterDepth := BraceDepth + 1;
  End;
  Inc(BraceDepth, CountChar(Trimmed, '{'));
  Dec(BraceDepth, CountChar(Trimmed, '}'));
  If InStruct And (BraceDepth < StructEnterDepth) Then InStruct := False;

  { ----- #define NOM valeur ----- }
  If StartsWithStr(Trimmed, '#define') And ((Mode And MD_CONST) <> 0) And
     (Not HasTrailingComment(S)) Then Begin
   P := 8;
   While (P <= Length(Trimmed)) And (Trimmed[P] = ' ') Do Inc(P);
   Name := '';
   While (P <= Length(Trimmed)) And IsIdentChar(Trimmed[P]) Do Begin
    Name := Name + Trimmed[P];
    Inc(P);
   End;
   If Name <> '' Then Begin
    Desc := DescribeSimple(Name, 'Constante');
    WriteLn(OutF, S, ' /* ', Desc, ' */');
    Inc(NbConst);
    Inc(I);
    Continue;
   End;
  End;

  { ----- Fonction/methode ----- }
  If LooksLikeCFunction(Trimmed, Name, ParamList) And
     ((Mode And (MD_FUNC Or MD_PROC Or MD_PARAM)) <> 0) Then Begin
   ExtractCParamNames(ParamList, ParamNames, ParamCnt);
   If (Not HasPrecedingComment(I)) And
      ((Mode And (MD_FUNC Or MD_PROC)) <> 0) Then Begin
    EmitCDocBlock(Name, ParamNames, ParamCnt,
     Not StartsWithStr(UpTrim, 'VOID '));
    Inc(NbFunc);
   End;
   WriteLn(OutF, S);
   Inc(I);
   Continue;
  End;

  { ----- Champ simple "Type Nom;" dans une structure/classe, ou
    constante "const Type Nom = valeur;". Les instructions du corps
    d une fonction (ex: "return 1;") sont ecartees : le nom capture
    ne doit pas commencer par un chiffre (litteral numerique), et le
    mot qui le precede ne doit pas etre un mot-cle d instruction. Les
    champs simples exigent en plus d etre directement dans le corps
    d une structure/classe (InStruct), pas dans une fonction. ----- }
  SemiPos := Pos(';', Trimmed);
  If (SemiPos > 1) And (Pos('(', Trimmed) = 0) And
     (Not HasTrailingComment(S)) Then Begin
   FieldName := '';
   P := SemiPos - 1;
   While (P >= 1) And (Trimmed[P] = ' ') Do Dec(P);
   While (P >= 1) And IsIdentChar(Trimmed[P]) Do Begin
    FieldName := Trimmed[P] + FieldName;
    Dec(P);
   End;
   TypeWord := '';
   Q := P;
   While (Q >= 1) And (Trimmed[Q] = ' ') Do Dec(Q);
   While (Q >= 1) And IsIdentChar(Trimmed[Q]) Do Begin
    TypeWord := Trimmed[Q] + TypeWord;
    Dec(Q);
   End;
   If (FieldName <> '') And (P >= 1) And (Trimmed[P] = ' ') And
      (Not (FieldName[1] In ['0'..'9'])) And
      (UpStr(TypeWord) <> 'RETURN') And (UpStr(TypeWord) <> 'BREAK') And
      (UpStr(TypeWord) <> 'CONTINUE') And (UpStr(TypeWord) <> 'GOTO') And
      (UpStr(TypeWord) <> 'ELSE') And (UpStr(TypeWord) <> 'CASE') And
      (UpStr(TypeWord) <> 'NEW') And (UpStr(TypeWord) <> 'DELETE') Then Begin
    If ContainsStr(Trimmed, 'const ') And ((Mode And MD_CONST) <> 0) Then
     Begin
      Desc := DescribeField(FieldName, TypeWord);
      WriteLn(OutF, S, ' /* ', Desc, ' */');
      Inc(NbConst);
      Inc(I);
      Continue;
     End
    Else If ((Mode And MD_FIELD) <> 0) And InStruct And
            (BraceDepth = StructEnterDepth) And
            (Not ContainsStr(Trimmed, '=')) Then Begin
     Desc := DescribeField(FieldName, TypeWord);
     WriteLn(OutF, S, ' /* ', Desc, ' */');
     Inc(NbField);
     Inc(I);
     Continue;
    End;
   End;
  End;

  WriteLn(OutF, S);
  Inc(I);
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

{ @description: Affiche l aide d utilisation de la commande COMMENT. }
Procedure Help;
Begin
 WriteLn('COMMENT : Cette commande permet d ajouter des commentaires ',
         'en francais');
 WriteLn('          dans un fichier source Pascal, C ou C# (champs, ',
         'constantes,');
 WriteLn('          fonctions/procedures et leurs parametres) lorsqu ',
         'il n y en a pas.');
 WriteLn;
 WriteLn('Syntaxe : COMMENT fichiersource [option]');
 WriteLn;
 WriteLn('fichiersource  Code source Pascal (.PAS), C/C++ (.C, .CPP, .H) ',
         'ou C# (.CS)');
 WriteLn('/ALL    Ajout des commentaires partout ou il y en pas : ',
         'constantes, champs,');
 WriteLn('        fonctions, procedures, ... et les parametres ',
         '(option par defaut)');
 WriteLn('/PROC   Ajout uniquement des commentaires pour les procedures');
 WriteLn('/FUNC   Ajout uniquement des commentaires pour les fonctions');
 WriteLn('/FIELD  Ajout uniquement des commentaires pour les champs/variables');
 WriteLn('/RECORD Ajout uniquement des commentaires pour les enregistrements/');
 WriteLn('        structures/classes');
 WriteLn('/PARAM  Ajout uniquement des @param manquants des procedures/fonctions');
 WriteLn('/?      Aide sur cette commande');
 WriteLn;
 WriteLn('Le dictionnaire interne (noms anglais courants -> description ',
         'francaise)');
 WriteLn('peut etre complete sans recompilation via un fichier ',
         DictFileName, ' dans le');
 WriteLn('repertoire courant (une entree par ligne : Nom=Description).');
End;

{ @description: Charge le fichier source entier dans le tableau Lines.
  @param FName Nom du fichier a charger
  @return Vrai si le chargement a reussi }
Function LoadSourceFile(FName: String): Boolean;
Var
 F: Text;
 IOErr: Integer;
Begin
 LoadSourceFile := False;
 LineCount := 0;
 {$I-}
 Assign(F, FName);
 Reset(F);
 IOErr := IOResult;
 {$I+}
 If IOErr <> 0 Then Exit;
 While (Not Eof(F)) And (LineCount < MaxLines) Do Begin
  Inc(LineCount);
  ReadLn(F, Lines[LineCount]);
 End;
 Close(F);
 LoadSourceFile := True;
End;

{ @description: Determine le langage source d apres l extension du
    nom de fichier.
  @param FName Nom du fichier source
  @return Langage detecte (Pascal, C ou C#), ou LangUnknown }
Function DetectLang(FName: String): TSrcLang;
Var
 Ext: String;
Begin
 Ext := ExtractExtUp(FName);
 If (Ext = 'PAS') Or (Ext = 'PP') Or (Ext = 'INC') Then
  DetectLang := LangPascal
 Else If (Ext = 'C') Or (Ext = 'CPP') Or (Ext = 'H') Or (Ext = 'HPP') Or
         (Ext = 'CC') Then
  DetectLang := LangC
 Else If Ext = 'CS' Then
  DetectLang := LangCSharp
 Else
  DetectLang := LangUnknown;
End;

Var
 Opt: String;
 I: Integer;
 IOErr: Integer;
 BakName: String;
BEGIN
 If (ParamCount = 0) Or (UpStr(ParamStr(1)) = '/?') Or
    (UpStr(ParamStr(1)) = '-H') Or (UpStr(ParamStr(1)) = '--HELP') Then
 Begin
  Help;
  Halt(0);
 End;
 SrcName := ParamStr(1);
 {$I-}
 Assign(OutF, SrcName);
 Reset(Text(OutF));
 IOErr := IOResult;
 {$I+}
 If IOErr <> 0 Then Begin
  WriteLn('Fichier introuvable: ', SrcName);
  Halt(1);
 End;
 Close(OutF);

 Mode := MD_ALL;
 For I := 2 To ParamCount Do Begin
  Opt := UpStr(ParamStr(I));
  If Opt = '/ALL' Then Mode := MD_ALL
  Else If Opt = '/PROC' Then Mode := MD_PROC
  Else If Opt = '/FUNC' Then Mode := MD_FUNC
  Else If Opt = '/FIELD' Then Mode := MD_FIELD
  Else If Opt = '/RECORD' Then Mode := MD_RECORD
  Else If Opt = '/PARAM' Then Mode := MD_PARAM
  Else Begin
   WriteLn('Option inconnue: ', ParamStr(I));
   Halt(2);
  End;
 End;

 Lang := DetectLang(SrcName);
 If Lang = LangUnknown Then Begin
  WriteLn('Type de fichier non reconnu (attendu : .PAS, .C, .CPP, .H, .CS) : ',
   SrcName);
  Halt(2);
 End;

 If Not LoadSourceFile(SrcName) Then Begin
  WriteLn('Impossible de lire le fichier source : ', SrcName);
  Halt(1);
 End;

 InitBuiltinDict;
 InitReturnDict;
 InitPrefixVerbs;
 InitSuffixVerbs;
 LoadExternalDict;

 NbConst := 0; NbField := 0; NbProc := 0; NbFunc := 0;
 NbRecord := 0; NbParam := 0;

 OutName := SrcName + '.tmp';
 Assign(OutF, OutName);
 {$I-} Rewrite(OutF); {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Impossible de creer le fichier temporaire : ', OutName);
  Halt(1);
 End;

 If Lang = LangPascal Then ProcessPascalFile
 Else ProcessCFile;

 Close(OutF);

 { Remplacer le fichier source par le resultat, sans jamais perdre
   l original : on le met d abord de cote (.bak), on installe le
   resultat a sa place, et on ne supprime la sauvegarde qu une fois
   ce remplacement confirme. En cas d echec du renommage du resultat,
   l original est restaure depuis la sauvegarde. }
 BakName := SrcName + '.bak';
 {$I-}
 Assign(OutF, SrcName);
 Rename(OutF, BakName);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de sauvegarder l original avant remplacement.');
  WriteLn('Le resultat se trouve dans : ', OutName);
  Halt(1);
 End;
 {$I-}
 Assign(OutF, OutName);
 Rename(OutF, SrcName);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur lors de l installation du resultat : restauration ',
   'de l original.');
  {$I-}
  Assign(OutF, BakName);
  Rename(OutF, SrcName);
  {$I+}
  WriteLn('Le resultat (non installe) se trouve dans : ', OutName);
  Halt(1);
 End;
 {$I-}
 Assign(OutF, BakName);
 Erase(OutF);
 {$I+}
 If IOResult <> 0 Then ;

 WriteLn('Termine : ', SrcName);
 WriteLn(' Procedures commentees  : ', NbProc);
 WriteLn(' Fonctions commentees   : ', NbFunc);
 WriteLn(' Parametres documentes  : ', NbParam);
 WriteLn(' Enregistrements/structures commentes : ', NbRecord);
 WriteLn(' Champs/variables commentes : ', NbField);
 WriteLn(' Constantes commentees  : ', NbConst);
END.
