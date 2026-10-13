{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: SELECT vers FetchXML, INSERT/UPDATE/DELETE vers HTTP Dataverse.
  @license: MIT
}

Program SQL4CDS(Input,Output);

{ SQL4CDS - SELECT vers FetchXML, INSERT/UPDATE/DELETE vers HTTP Dataverse.
  Implementation autonome; aucune dependance .NET ni connexion reseau.
  Reference fonctionnelle : https://github.com/MarkMpn/Sql4Cds
  Target: Turbo Pascal 7 / Free Pascal (-Mtp). License: MIT.

  SQL4CDS source.sql [sortie.xml]
  SQL4CDS -q "SELECT name FROM account" [-o sortie.xml]
  Sans arguments : lecture de l'entree standard jusqu'a EOF.

  SELECT [DISTINCT] [TOP n] colonnes FROM [dbo.]entite [AS alias]
  INNER/LEFT/RIGHT JOIN entite alias ON alias.colonne = alias.colonne
  ON accepte des conditions AND supplementaires sur la table liee.
  RIGHT JOIN est limite a une jointure entre deux tables.
  WHERE : AND, OR, parentheses, =, <>, !=, <, <=, >, >=,
          [NOT] LIKE, [NOT] IN, [NOT] BETWEEN, IS [NOT] NULL.
  ORDER BY colonnes [ASC|DESC]; GROUP BY colonnes;
  COUNT(colonne), COUNT(DISTINCT colonne), SUM, AVG, MIN, MAX.
  COUNT(*) exige les metadonnees de la cle primaire : utiliser COUNT(id).
  Les noms sont les noms logiques Dataverse, pas les libelles affiches.
  INSERT INTO [dbo.]entite (colonnes) VALUES (valeurs), (valeurs), ...;
  INSERT INTO entite DEFAULT VALUES;
  INSERT genere un fichier HTTP avec JSON, pas du FetchXML.
  --entity-set collection : EntitySetName Dataverse pour INSERT/UPDATE/DELETE.
  Sans cette option : variable HTTP entitySet a renseigner.
  Variables HTTP orgUrl et accessToken a renseigner pour l'envoi.
  Valeurs INSERT : chaines, nombres, NULL, DEFAULT, CAST(0|1 AS BIT).
  DEFAULT omet la propriete pour laisser Dataverse appliquer sa valeur.
  UPDATE [dbo.]entite [AS alias] SET colonne=valeur, ... WHERE cle='GUID';
  DELETE FROM [dbo.]entite [AS alias] WHERE cle='GUID';
  WHERE UPDATE/DELETE : egalites/IN sur la cle primaire, combinees par OR.
  --primary-key colonne : cle UPDATE/DELETE (accountid/contactid connus).
  UPDATE genere un PATCH par GUID avec If-Match: * (pas d'upsert).
  DEFAULT dans SET non supporte sans metadonnees de la valeur par defaut.
  DELETE genere une requete HTTP DELETE par GUID, sans corps JSON.
  Un seul SELECT, INSERT, UPDATE ou DELETE. Pas de sous-requetes, HAVING, fonctions scalaires,
  expressions calculees, UNION, parametres ou negation d'un groupe.
  ON : egalite entre colonnes qualifiees, puis AND (filtres table liee).
  Pas de FULL/CROSS JOIN, ni de cle de jointure composite.
  Les colonnes non qualifiees designent l'entite principale.
  Limites verifiees : SQL/XML 30000 octets, 1024 jetons, 255 octets
  par jeton, 16 entites (15 jointures), 128 projections/tris, 256 noeuds WHERE/ON.
  Les buffers et jetons sont alloues sur le tas pour Turbo Pascal.
  Arguments limites a 254 octets; utiliser -i pour les requetes longues.
  Fichiers UTF-8 (avec ou sans BOM); octets UTF-8 preserves.
  Les erreurs vont sur stderr sous FPC, sur stdout sous Turbo Pascal.
  Codes retour : 0 succes, 1 erreur SQL/IO, 2 syntaxe de commande.
}

{$IFDEF FPC}{$MODE TP}{$ENDIF}
{$M 32768,0,655360}
{$R+}
Uses DOS;
Const MaxBuf=30000; MaxTok=1024; MaxEntity=16; MaxField=128;
      MaxNode=256;
Type
 PStr=^String;
 TBuffer=Array[1..MaxBuf] of Char;
 PBuffer=^TBuffer;
 TToken=Record S:PStr; Kind:Char; Pos:Integer End;
 TTokens=Array[1..MaxTok] of TToken;
 PTokens=^TTokens;
 TEntity=Record Name,AliasName,FromCol,ToCol:String[80];
                Parent,FilterRoot:Integer; OuterJoin:Boolean End;
 TField=Record Qual,Name,AliasName:String[80]; Agg:String[16];
               Ent:Integer; Grouped,DistinctValue,Descending:Boolean End;
 TFields=Array[1..MaxField] of TField;
 PFields=^TFields;
 TNode=Record Kind:Char; L,R,FirstValue,LastValue:Integer;
              Name:String[80]; Ent:Integer; Op:String[16] End;
 TNodes=Array[1..MaxNode] of TNode;
 PNodes=^TNodes;
 TAssignment=Record Name:String[80]; Value:String; Kind:Char End;
 TAssignments=Array[1..MaxField] of TAssignment;
 PAssignments=^TAssignments;
 TIDs=Array[1..MaxTok] of String[36];
 PIDs=^TIDs;
Var Source,XML:PBuffer; Tokens:PTokens; Nodes:PNodes;
    SourceLen,XMLLen,TokenCount,AtToken,EntityCount,FieldCount,
    OrderCount,NodeCount,Root,Depth,BaseEntity:Integer;
    Entities:Array[1..MaxEntity] of TEntity;
    Fields,Orders:PFields;
    DistinctRows,AggregateQuery,InJoinCondition:Boolean;
    TopValue,InputName,OutputName,Query,EntitySet,PrimaryKey:String;
    F:Text;

Procedure Fail(S:String);
Begin
 {$IFDEF FPC}WriteLn(StdErr,'SQL4CDS: ',S);
 {$ELSE}WriteLn('SQL4CDS: ',S);{$ENDIF}
 Halt(1);
End;

Function Upper(S:String):String;
Var I:Integer;
Begin For I:=1 to Length(S) do S[I]:=UpCase(S[I]); Upper:=S End;

Function Lower(S:String):String;
Var I:Integer;
Begin
 For I:=1 to Length(S) do If S[I] in ['A'..'Z'] Then
  S[I]:=Chr(Ord(S[I])+32);
 Lower:=S;
End;

Function Num(I:Integer):String;
Var S:String;
Begin Str(I,S); Num:=S End;

Function Tok:String;
Begin If AtToken>TokenCount Then Tok:='' Else Tok:=Tokens^[AtToken].S^ End;

Function IsWord(S:String):Boolean;
Begin
 IsWord:=False;
 If AtToken<=TokenCount Then
  IsWord:=(Tokens^[AtToken].Kind='I')and(Upper(Tok)=S);
End;

Procedure Syntax(S:String);
Var P:Integer;
Begin
 P:=SourceLen+1;
 If AtToken<=TokenCount Then P:=Tokens^[AtToken].Pos;
 Fail(S+' (position '+Num(P)+', jeton "'+Tok+'")');
End;

Procedure Need(S:String);
Begin
 If AtToken>TokenCount Then Syntax('Attendu : '+S);
 If S[1] in ['A'..'Z'] Then Begin
  If Not IsWord(S) Then Syntax('Attendu : '+S);
 End Else
  If (Tok<>S)or(Tokens^[AtToken].Kind<>'P') Then Syntax('Attendu : '+S);
 Inc(AtToken);
End;

Procedure AddSource(C:Char);
Begin
 If SourceLen=MaxBuf Then Fail('SQL trop long');
 Inc(SourceLen); Source^[SourceLen]:=C;
End;

Procedure AddToken(S:String; K:Char; P:Integer);
Begin
 If TokenCount=MaxTok Then Fail('Trop de jetons');
 Inc(TokenCount); New(Tokens^[TokenCount].S);
 Tokens^[TokenCount].S^:=S; Tokens^[TokenCount].Kind:=K;
 Tokens^[TokenCount].Pos:=P;
End;

Procedure Lex;
Var I,P:Integer; C,Q,K:Char; S:String; Closed:Boolean;
 Procedure Put(C:Char);
 Begin
  If Length(S)=255 Then Fail('Jeton trop long a '+Num(P));
  S:=S+C;
 End;
Begin
 I:=1;
 If SourceLen>=3 Then
  If (Source^[1]=#239)and(Source^[2]=#187)and(Source^[3]=#191) Then I:=4;
 While I<=SourceLen do Begin
  C:=Source^[I]; P:=I; S:='';
  If C in [#9,#10,#13,' '] Then Inc(I)
  Else If (C='-')and(I<SourceLen)and(Source^[I+1]='-') Then Begin
   While (I<=SourceLen)and(Source^[I]<>#10) do Inc(I);
  End
  Else If (C='/')and(I<SourceLen)and(Source^[I+1]='*') Then Begin
   Inc(I,2); Closed:=False;
   While I<SourceLen do Begin
    If (Source^[I]='*')and(Source^[I+1]='/') Then Begin
     Inc(I,2); Closed:=True; Break;
    End;
    Inc(I);
   End;
   If Not Closed Then Fail('Commentaire non termine a '+Num(P));
  End
  Else If (C in ['''','[','"'])or
    ((UpCase(C)='N')and(I<SourceLen)and(Source^[I+1]='''')) Then Begin
   If UpCase(C)='N' Then Begin Inc(I); C:='''' End;
   Q:=C; If C='[' Then Q:=']';
   K:='I'; If C='''' Then K:='S';
   Inc(I); Closed:=False;
   While I<=SourceLen do Begin
    C:=Source^[I]; Inc(I);
    If C=Q Then Begin
     If (I<=SourceLen)and(Source^[I]=Q) Then Begin Put(Q); Inc(I) End
     Else Begin Closed:=True; Break End;
    End Else Put(C);
   End;
   If Not Closed Then Fail('Chaine/identifiant non termine a '+Num(P));
   AddToken(S,K,P);
  End
  Else If C in ['A'..'Z','a'..'z','_'] Then Begin
   While (I<=SourceLen)and
    (Source^[I] in ['A'..'Z','a'..'z','0'..'9','_']) do Begin
    Put(Source^[I]); Inc(I);
   End;
   AddToken(S,'I',P);
  End
  Else If C in ['0'..'9'] Then Begin
   While (I<=SourceLen)and(Source^[I] in ['0'..'9']) do Begin
    Put(Source^[I]); Inc(I);
   End;
   If (I<=SourceLen)and(Source^[I]='.') Then Begin
    Put('.'); Inc(I);
    If (I>SourceLen)or Not(Source^[I] in ['0'..'9']) Then
     Fail('Nombre decimal invalide a '+Num(P));
    While (I<=SourceLen)and(Source^[I] in ['0'..'9']) do Begin
     Put(Source^[I]); Inc(I);
    End;
   End;
   AddToken(S,'V',P);
  End Else Begin
   S:=C; Inc(I);
   If (C in ['<','>','!'])and(I<=SourceLen) Then
    If (Source^[I]='=')or((C='<')and(Source^[I]='>')) Then Begin
     S:=S+Source^[I]; Inc(I);
    End;
   AddToken(S,'P',P);
  End;
 End;
End;

Function Ident:String;
Var S:String; I:Integer;
Begin
 If (AtToken>TokenCount)or(Tokens^[AtToken].Kind<>'I') Then
  Syntax('Identifiant attendu');
 S:=Lower(Tok);
 If (Length(S)=0)or(Length(S)>80) Then Syntax('Nom invalide (1..80 caracteres)');
 For I:=1 to Length(S) do
  If Not(S[I] in ['a'..'z','0'..'9','_']) Then Syntax('Nom logique invalide');
 Ident:=S; Inc(AtToken);
End;

Function Clause:Boolean;
Begin
 Clause:=IsWord('FROM')or IsWord('WHERE')or IsWord('ORDER')or
  IsWord('GROUP')or IsWord('INNER')or IsWord('LEFT')or IsWord('JOIN')or
  IsWord('ON')or IsWord('RIGHT')or IsWord('FULL')or IsWord('CROSS')or
  IsWord('HAVING')or IsWord('UNION')or IsWord('OFFSET')or IsWord('SET');
End;

Procedure ReadField(Var A:TField);
Begin
 FillChar(A,SizeOf(A),0);
 If Tok='*' Then Begin A.Name:='*'; Inc(AtToken) End
 Else A.Name:=Ident;
 If Tok='.' Then Begin
  Inc(AtToken); A.Qual:=A.Name;
  If Tok='*' Then Begin A.Name:='*'; Inc(AtToken) End Else A.Name:=Ident;
 End;
End;

Function EntityIndex(S:String):Integer;
Var I,N:Integer;
Begin
 N:=0;
 For I:=1 to EntityCount do
  If Entities[I].AliasName=S Then N:=I;
 If N=0 Then Syntax('Alias inconnu : '+S);
 EntityIndex:=N;
End;

Procedure Resolve(Var A:TField);
Begin
 A.Ent:=1;
 If A.Qual<>'' Then A.Ent:=EntityIndex(A.Qual);
End;

Procedure ReadEntity;
Var S:String; I:Integer;
Begin
 If EntityCount=MaxEntity Then Syntax('FetchXML accepte au maximum 15 jointures');
 Inc(EntityCount); FillChar(Entities[EntityCount],SizeOf(TEntity),0);
 S:=Ident;
 If Tok='.' Then Begin
  If S<>'dbo' Then Syntax('Seul le schema dbo est supporte');
  Inc(AtToken); S:=Ident;
 End;
 Entities[EntityCount].Name:=S;
 If IsWord('AS') Then Begin Inc(AtToken); S:=Ident End
 Else If (AtToken<=TokenCount)and(Tokens^[AtToken].Kind='I')and
  Not Clause Then S:=Ident;
 For I:=1 to EntityCount-1 do
  If Entities[I].AliasName=S Then Syntax('Alias d''entite duplique : '+S);
 Entities[EntityCount].AliasName:=S;
End;

Function NewNode(K:Char; L,R:Integer):Integer;
Begin
 If NodeCount=MaxNode Then Syntax('Filtre trop complexe');
 Inc(NodeCount); FillChar(Nodes^[NodeCount],SizeOf(TNode),0);
 Nodes^[NodeCount].Kind:=K; Nodes^[NodeCount].L:=L; Nodes^[NodeCount].R:=R;
 NewNode:=NodeCount;
End;

Function Literal:Integer;
Var N:Integer; S:String;
Begin
 N:=AtToken;
 If (Tok='-')or(Tok='+') Then Begin
  S:=Tok; Inc(AtToken);
  If (AtToken>TokenCount)or(Tokens^[AtToken].Kind<>'V') Then
   Syntax('Nombre attendu apres le signe');
  If Length(Tok)=255 Then Syntax('Nombre signe trop long');
  Tokens^[AtToken].S^:=S+Tok; N:=AtToken;
 End;
 If AtToken>TokenCount Then Syntax('Valeur attendue');
 If Not(Tokens^[AtToken].Kind in ['S','V']) Then
  Syntax('Valeur litterale attendue (NULL exige IS NULL)');
 Inc(AtToken); Literal:=N;
End;

Function ParseOr:Integer; Forward;

Function Predicate:Integer;
Var N,L,V:Integer; Neg:Boolean; O:String; A:TField;
Begin
 Inc(Depth); If Depth>64 Then Syntax('Parentheses trop profondes');
 If Tok='(' Then Begin
  Inc(AtToken); N:=ParseOr; Need(')');
 End Else Begin
  ReadField(A); Resolve(A);
  If InJoinCondition and(A.Qual='') Then
   Syntax('Qualifier les colonnes des conditions ON');
  If A.Name='*' Then Syntax('Colonne attendue dans WHERE');
  N:=NewNode('C',0,0); Nodes^[N].Name:=A.Name; Nodes^[N].Ent:=A.Ent;
  Neg:=False;
  If IsWord('IS') Then Begin
   Inc(AtToken);
   If IsWord('NOT') Then Begin Neg:=True; Inc(AtToken) End;
   Need('NULL'); O:='null'; If Neg Then O:='not-null';
  End Else Begin
   If IsWord('NOT') Then Begin Neg:=True; Inc(AtToken) End;
   If IsWord('IN') Then Begin
    Inc(AtToken); Need('('); O:='in'; If Neg Then O:='not-in';
    L:=Literal; Nodes^[N].FirstValue:=L;
    While Tok=',' do Begin Inc(AtToken); V:=Literal End;
    Nodes^[N].LastValue:=AtToken-1; Need(')');
   End Else If IsWord('BETWEEN') Then Begin
    Inc(AtToken); O:='between'; If Neg Then O:='not-between';
    Nodes^[N].FirstValue:=Literal; Need('AND');
    Nodes^[N].LastValue:=Literal;
   End Else Begin
    If IsWord('LIKE') Then Begin
     O:='like'; If Neg Then O:='not-like';
    End Else Begin
     If Neg Then Syntax('NOT exige IN, LIKE ou BETWEEN');
     O:='';
     If Tok='=' Then O:='eq';
     If (Tok='<>')or(Tok='!=') Then O:='ne';
     If Tok='<' Then O:='lt'; If Tok='<=' Then O:='le';
     If Tok='>' Then O:='gt'; If Tok='>=' Then O:='ge';
     If O='' Then Syntax('Operateur de comparaison attendu');
    End;
    Inc(AtToken); V:=Literal;
    If (O='like')or(O='not-like') Then
     If Tokens^[V].Kind<>'S' Then Syntax('LIKE exige une chaine');
    Nodes^[N].FirstValue:=V;
   End;
  End;
  Nodes^[N].Op:=O;
 End;
 Dec(Depth); Predicate:=N;
End;

Function ParseAnd:Integer;
Var N,R:Integer;
Begin
 N:=Predicate;
 While IsWord('AND') do Begin
  Inc(AtToken); R:=Predicate; N:=NewNode('A',N,R);
 End;
 ParseAnd:=N;
End;

Function ParseOr:Integer;
Var N,R:Integer;
Begin
 N:=ParseAnd;
 While IsWord('OR') do Begin
  Inc(AtToken); R:=ParseAnd; N:=NewNode('O',N,R);
 End;
 ParseOr:=N;
End;

Procedure CheckJoinFilter(N,E:Integer);
Begin
 If Nodes^[N].Kind='C' Then Begin
  If Nodes^[N].Ent<>E Then
   Syntax('Conditions ON supplementaires : colonnes de la table liee seulement');
 End Else Begin
  CheckJoinFilter(Nodes^[N].L,E); CheckJoinFilter(Nodes^[N].R,E);
 End;
End;

Procedure Parse;
Var A,B:TField; I,J,E,Linked,Code:Integer; S:String;
    OuterJ,RightJ,RightJoined,Paren,Found:Boolean;
    TopN:LongInt;
Begin
 AtToken:=1; Need('SELECT'); RightJoined:=False;
 If IsWord('DISTINCT') Then Begin DistinctRows:=True; Inc(AtToken) End;
 If IsWord('TOP') Then Begin
  Inc(AtToken); Found:=Tok='('; If Found Then Inc(AtToken);
  TopValue:=Tok; Val(TopValue,TopN,Code);
  If (Code<>0)or(TopN<1) Then Syntax('TOP exige un entier positif');
  Inc(AtToken); If Found Then Need(')');
 End;
 Repeat
  If FieldCount=MaxField Then Syntax('Trop de colonnes');
  FillChar(A,SizeOf(A),0); S:=Upper(Tok);
  If (S='COUNT')or(S='SUM')or(S='AVG')or(S='MIN')or(S='MAX') Then Begin
   Inc(AtToken); Need('('); Found:=IsWord('DISTINCT');
   If Found Then Inc(AtToken);
   ReadField(A); A.DistinctValue:=Found;
   If A.Name='*' Then Syntax('COUNT(*) : utiliser la cle primaire explicite');
   A.Agg:=Lower(S);
   If S='COUNT' Then A.Agg:='countcolumn';
   If Found and(S<>'COUNT') Then Syntax('DISTINCT agrege exige COUNT');
   Need(')'); AggregateQuery:=True;
  End Else ReadField(A);
  If IsWord('AS') Then Begin Inc(AtToken); A.AliasName:=Ident End
  Else If (AtToken<=TokenCount)and(Tokens^[AtToken].Kind='I')and
   Not Clause Then A.AliasName:=Ident;
  If (A.Name='*')and(A.AliasName<>'') Then Syntax('Alias interdit sur *');
  Inc(FieldCount); Fields^[FieldCount]:=A;
  Found:=Tok=','; If Found Then Inc(AtToken);
 Until Not Found;
 Need('FROM'); ReadEntity;
 While IsWord('JOIN')or IsWord('INNER')or IsWord('LEFT')or IsWord('RIGHT') do Begin
  If RightJoined Then Syntax('RIGHT JOIN limite a deux tables');
  RightJ:=IsWord('RIGHT'); OuterJ:=IsWord('LEFT')or RightJ;
  If RightJ and(EntityCount<>1) Then Syntax('RIGHT JOIN limite a deux tables');
  If Not IsWord('JOIN') Then Begin
   Inc(AtToken); If OuterJ and IsWord('OUTER') Then Inc(AtToken);
  End;
  Need('JOIN'); ReadEntity; E:=EntityCount; Need('ON');
  Paren:=Tok='('; If Paren Then Inc(AtToken);
  ReadField(A); Resolve(A); Need('='); ReadField(B); Resolve(B);
  If Paren and(Tok=')') Then Begin Need(')'); Paren:=False End;
  If (A.Qual='')or(B.Qual='')or(A.Name='*')or(B.Name='*') Then
   Syntax('ON exige deux colonnes qualifiees');
  If B.Ent=E Then Begin
   S:=A.Name; I:=A.Ent; A:=B; B.Name:=S; B.Ent:=I;
  End;
  If (A.Ent<>E)or(B.Ent>=E) Then
   Syntax('ON doit relier la nouvelle entite a une entite precedente');
  Linked:=E;
  If RightJ Then Begin
   BaseEntity:=E; RightJoined:=True; Linked:=1;
   Entities[1].Parent:=E; Entities[1].FromCol:=B.Name;
   Entities[1].ToCol:=A.Name; Entities[1].OuterJoin:=True;
  End Else Begin
   Entities[E].Parent:=B.Ent; Entities[E].FromCol:=A.Name;
   Entities[E].ToCol:=B.Name; Entities[E].OuterJoin:=OuterJ;
  End;
  If IsWord('AND') Then Begin
   Inc(AtToken); InJoinCondition:=True;
   Entities[Linked].FilterRoot:=ParseAnd; InJoinCondition:=False;
   CheckJoinFilter(Entities[Linked].FilterRoot,Linked);
  End;
  If Paren Then Need(')');
  I:=B.Ent;
  While I>1 do Begin
   { Une jointure INNER dependante exige des lignes dans ses ancetres.
     Leurs LEFT deviennent INNER; les branches independantes restent LEFT. }
   If Not OuterJ Then Entities[I].OuterJoin:=False;
   I:=Entities[I].Parent;
  End;
 End;
 For I:=1 to FieldCount do Resolve(Fields^[I]);
 If IsWord('WHERE') Then Begin Inc(AtToken); Root:=ParseOr End;
 If IsWord('GROUP') Then Begin
  Inc(AtToken); Need('BY'); AggregateQuery:=True;
  Repeat
   ReadField(A); Resolve(A); Found:=False;
   For I:=1 to FieldCount do
    If (Fields^[I].Name=A.Name)and(Fields^[I].Ent=A.Ent)and
     (Fields^[I].Agg='') Then Begin Fields^[I].Grouped:=True; Found:=True End;
   If Not Found Then Syntax('GROUP BY doit figurer dans SELECT');
   Found:=Tok=','; If Found Then Inc(AtToken);
  Until Not Found;
 End;
 If AggregateQuery Then Begin
  If DistinctRows Then Syntax('DISTINCT global avec agregats non supporte');
  For I:=1 to FieldCount do Begin
   If (Fields^[I].Agg='')and Not Fields^[I].Grouped Then
    Syntax('Colonne SELECT absente du GROUP BY');
   If Fields^[I].AliasName='' Then Fields^[I].AliasName:='column'+Num(I);
  End;
 End;
 For I:=1 to FieldCount do
  If Fields^[I].AliasName<>'' Then
   For J:=1 to I-1 do
    If Fields^[I].AliasName=Fields^[J].AliasName Then Syntax('Alias SELECT duplique');
 If IsWord('ORDER') Then Begin
  Inc(AtToken); Need('BY');
  Repeat
   ReadField(A); Found:=False;
   If A.Qual='' Then For I:=1 to FieldCount do
    If (Fields^[I].AliasName<>'')and(Fields^[I].AliasName=A.Name) Then Begin
     A:=Fields^[I]; Found:=True;
    End;
   If Not Found Then Resolve(A);
   If A.Name='*' Then Syntax('ORDER BY * interdit');
   If AggregateQuery and Not Found Then Begin
    Found:=False;
    For I:=1 to FieldCount do
     If (Fields^[I].Name=A.Name)and(Fields^[I].Ent=A.Ent)and
      (Fields^[I].Agg=A.Agg) Then Begin A:=Fields^[I]; Found:=True End;
    If Not Found Then Syntax('Tri agrege exige une colonne SELECT');
   End;
   A.Descending:=IsWord('DESC');
   If IsWord('DESC')or IsWord('ASC') Then Inc(AtToken);
   If OrderCount=MaxField Then Syntax('Trop de tris');
   Inc(OrderCount); Orders^[OrderCount]:=A;
   Found:=Tok=','; If Found Then Inc(AtToken);
  Until Not Found;
 End;
 If Tok=';' Then Inc(AtToken);
 If AtToken<=TokenCount Then Syntax('Construction SQL non supportee');
End;

Procedure Emit(S:String);
Var I:Integer;
Begin
 If XMLLen+Length(S)>MaxBuf Then Fail('Sortie trop longue');
 For I:=1 to Length(S) do Begin Inc(XMLLen); XML^[XMLLen]:=S[I] End;
End;

Procedure Escape(S:String);
Var I:Integer;
Begin
 For I:=1 to Length(S) do Case S[I] of
  '&':Emit('&amp;'); '<':Emit('&lt;'); '>':Emit('&gt;');
  '"':Emit('&quot;'); '''':Emit('&apos;');
  #9:Emit('&#9;'); #10:Emit('&#10;'); #13:Emit('&#13;');
  Else Begin
   If Ord(S[I])<32 Then Fail('Caractere interdit en XML');
   Emit(S[I]);
  End;
 End;
End;

Procedure Attr(Name,Value:String);
Begin Emit(' '+Name+'="'); Escape(Value); Emit('"') End;

Procedure Line;
Begin Emit(#13#10) End;

Procedure Indent(N:Integer);
Var I:Integer;
Begin For I:=1 to N do Emit('  ') End;

Procedure EmitFilter(N,Level,Scope:Integer);
Var I:Integer;
Begin
 If N=0 Then Exit;
 Indent(Level);
 If Nodes^[N].Kind='C' Then Begin
  Emit('<condition'); Attr('attribute',Nodes^[N].Name);
  If Nodes^[N].Ent<>Scope Then
   Attr('entityname',Entities[Nodes^[N].Ent].AliasName);
  Attr('operator',Nodes^[N].Op);
  If Nodes^[N].FirstValue=0 Then Emit(' />')
  Else If Nodes^[N].LastValue=0 Then Begin
   Attr('value',Tokens^[Nodes^[N].FirstValue].S^); Emit(' />');
  End Else Begin
   Emit('>');
   For I:=Nodes^[N].FirstValue to Nodes^[N].LastValue do
    If Tokens^[I].Kind in ['S','V'] Then Begin
     Emit('<value>'); Escape(Tokens^[I].S^); Emit('</value>');
    End;
   Emit('</condition>');
  End;
  Line;
 End Else Begin
  Emit('<filter');
  If Nodes^[N].Kind='A' Then Attr('type','and') Else Attr('type','or');
  Emit('>'); Line;
  EmitFilter(Nodes^[N].L,Level+1,Scope); EmitFilter(Nodes^[N].R,Level+1,Scope);
  Indent(Level); Emit('</filter>'); Line;
 End;
End;

Procedure EmitEntity(E,Level:Integer);
Var I:Integer; A:TField;
Begin
 Indent(Level);
 If E=BaseEntity Then Emit('<entity') Else Emit('<link-entity');
 Attr('name',Entities[E].Name);
 If E<>BaseEntity Then Begin
  Attr('alias',Entities[E].AliasName); Attr('from',Entities[E].FromCol);
  Attr('to',Entities[E].ToCol);
  If Entities[E].OuterJoin Then Attr('link-type','outer')
  Else Attr('link-type','inner');
 End;
 Emit('>'); Line;
 For I:=1 to FieldCount do
  If (Fields^[I].Ent=E)or((Fields^[I].Name='*')and(Fields^[I].Qual='')) Then Begin
  A:=Fields^[I]; Indent(Level+1);
  If A.Name='*' Then Emit('<all-attributes />') Else Begin
   Emit('<attribute'); Attr('name',A.Name);
   If A.AliasName<>'' Then Attr('alias',A.AliasName);
   If A.Agg<>'' Then Attr('aggregate',A.Agg);
   If A.Grouped Then Attr('groupby','true');
   If A.DistinctValue Then Attr('distinct','true');
   Emit(' />');
  End;
  Line;
 End;
 If Entities[E].FilterRoot<>0 Then Begin
  Indent(Level+1); Emit('<filter type="and">'); Line;
  EmitFilter(Entities[E].FilterRoot,Level+2,E);
  Indent(Level+1); Emit('</filter>'); Line;
 End;
 If E=BaseEntity Then Begin
  For I:=1 to OrderCount do Begin
   A:=Orders^[I]; Indent(Level+1); Emit('<order');
   If A.AliasName<>'' Then Attr('alias',A.AliasName)
   Else Begin
    Attr('attribute',A.Name);
    If A.Ent<>BaseEntity Then Attr('entityname',Entities[A.Ent].AliasName);
   End;
   If A.Descending Then Attr('descending','true')
   Else Attr('descending','false');
   Emit(' />'); Line;
  End;
  If Root<>0 Then Begin
   Indent(Level+1); Emit('<filter type="and">'); Line;
   EmitFilter(Root,Level+2,BaseEntity);
   Indent(Level+1); Emit('</filter>'); Line;
  End;
 End;
 For I:=1 to EntityCount do If Entities[I].Parent=E Then EmitEntity(I,Level+1);
 Indent(Level);
 If E=BaseEntity Then Emit('</entity>') Else Emit('</link-entity>'); Line;
End;

{ INSERT/UPDATE utilisent le meme analyseur lexical, avec sortie JSON HTTP.
  Aucune requete HTTP n'est executee par le convertisseur. }
Procedure JSONString(S:String);
Const Hex='0123456789abcdef';
Var I,C:Integer;
Begin
 Emit('"');
 For I:=1 to Length(S) do Begin
  C:=Ord(S[I]);
  Case S[I] of
   '"':Emit('\"'); '\':Emit('\\');
   Else If C<32 Then Begin
    Emit('\u00'); Emit(Hex[(C div 16)+1]); Emit(Hex[(C mod 16)+1]);
   End Else Emit(S[I]);
  End;
 End;
 Emit('"');
End;

Function JSONNumber(S:String):String;
Var Negative:Boolean;
Begin
 Negative:=False;
 If S[1] in ['+','-'] Then Begin
  Negative:=S[1]='-'; Delete(S,1,1);
 End;
 While (Length(S)>1)and(S[1]='0')and(S[2]<>'.') do Delete(S,1,1);
 If Negative Then S:='-'+S;
 JSONNumber:=S;
End;

Procedure InsertValue(Var K:Char; Var S:String);
Var V:Integer; CastBit:Boolean;
Begin
 K:=#0; S:=''; CastBit:=IsWord('CAST');
 If CastBit Then Begin Inc(AtToken); Need('(') End;
 If IsWord('NULL') Then Begin K:='N'; Inc(AtToken) End
 Else If IsWord('DEFAULT') Then Begin K:='D'; Inc(AtToken) End
 Else Begin
  V:=Literal; K:=Tokens^[V].Kind; S:=Tokens^[V].S^;
  If K='V' Then S:=JSONNumber(S);
 End;
 If CastBit Then Begin
  Need('AS'); Need('BIT'); Need(')');
  If K<>'N' Then Begin
   If (K<>'V')or((S<>'0')and(S<>'1')and(S<>'-0')) Then
    Syntax('CAST AS BIT exige 0, 1 ou NULL');
   K:='B'; If S='1' Then S:='true' Else S:='false';
  End;
 End;
End;

Procedure InsertHeader(Row:Integer);
Begin
 Emit('### INSERT '); Emit(Entities[1].Name); Emit(' - ligne '); Emit(Num(Row)); Line;
 Emit('POST {{orgUrl}}/api/data/v9.2/');
 If EntitySet='' Then Emit('{{entitySet}}') Else Emit(EntitySet);
 Line;
 Emit('Authorization: Bearer {{accessToken}}'); Line;
 Emit('Content-Type: application/json; charset=utf-8'); Line;
 Emit('Accept: application/json'); Line;
 Emit('OData-MaxVersion: 4.0'); Line;
 Emit('OData-Version: 4.0'); Line;
 Line;
End;

Procedure ParseInsert;
Var I,J,Row:Integer; K:Char; S:String; More,Written:Boolean;
Begin
 AtToken:=1; Need('INSERT'); Need('INTO');
 EntityCount:=1; FillChar(Entities[1],SizeOf(TEntity),0);
 S:=Ident;
 If Tok='.' Then Begin
  If S<>'dbo' Then Syntax('Seul le schema dbo est supporte');
  Inc(AtToken); S:=Ident;
 End;
 Entities[1].Name:=S;
 If IsWord('DEFAULT') Then Begin
  Inc(AtToken); Need('VALUES'); InsertHeader(1); Emit('{}'); Line;
 End Else Begin
  Need('(');
  Repeat
   If FieldCount=MaxField Then Syntax('Trop de colonnes INSERT');
   S:=Ident;
   For J:=1 to FieldCount do
    If Fields^[J].Name=S Then Syntax('Colonne INSERT dupliquee : '+S);
   Inc(FieldCount); FillChar(Fields^[FieldCount],SizeOf(TField),0);
   Fields^[FieldCount].Name:=S;
   More:=Tok=','; If More Then Inc(AtToken);
  Until Not More;
  Need(')'); Need('VALUES'); Row:=0;
  Repeat
   Inc(Row); Need('('); InsertHeader(Row); Emit('{'); Written:=False;
   For I:=1 to FieldCount do Begin
    If I>1 Then Need(',');
    InsertValue(K,S);
    If K<>'D' Then Begin
     If Written Then Emit(','); Line; Indent(1);
     JSONString(Fields^[I].Name); Emit(': ');
     Case K of
      'N':Emit('null'); 'S':JSONString(S); 'V','B':Emit(S);
     End;
     Written:=True;
    End;
   End;
   Need(')'); If Written Then Line; Emit('}'); Line;
   More:=Tok=','; If More Then Begin Inc(AtToken); Line End;
  Until Not More;
 End;
 If Tok=';' Then Inc(AtToken);
 If AtToken<=TokenCount Then Syntax('Construction INSERT non supportee');
End;

Function GUIDValue(S:String):String;
Var I:Integer;
Begin
 If Length(S)<>36 Then Syntax('GUID attendu au format 8-4-4-4-12');
 For I:=1 to 36 do Begin
  If (I=9)or(I=14)or(I=19)or(I=24) Then Begin
   If S[I]<>'-' Then Syntax('GUID invalide');
  End Else If Not(S[I] in ['0'..'9','a'..'f','A'..'F']) Then Syntax('GUID invalide');
 End;
 GUIDValue:=Lower(S);
End;

{ Analyse commune : UPDATE et DELETE partagent le ciblage par cle primaire. }
Procedure ParseModification(IsDelete:Boolean);
Var Assignments:PAssignments; Count,I,J,N:Integer;
    A:TField; K:Char; S:String; More:Boolean;
    IDs:PIDs; IDCount:Integer;
    Operation:String[6];

 Procedure CollectIDs(Node:Integer);
 Var T,X,Y,Z:Integer; G:String[36]; Seen:Boolean;
 Begin
  If Nodes^[Node].Kind='O' Then Begin
   CollectIDs(Nodes^[Node].L); CollectIDs(Nodes^[Node].R);
  End Else Begin
   If (Nodes^[Node].Kind<>'C')or(Nodes^[Node].Name<>PrimaryKey)or
    ((Nodes^[Node].Op<>'eq')and(Nodes^[Node].Op<>'in')) Then
     Syntax('WHERE '+Operation+' exige egalite/IN sur la cle primaire, ou OR');
   X:=Nodes^[Node].FirstValue; Y:=Nodes^[Node].LastValue;
   If Y=0 Then Y:=X;
   For T:=X to Y do Begin
    If Tokens^[T].Kind<>'P' Then Begin
     If Tokens^[T].Kind<>'S' Then Syntax('La cle primaire exige un GUID entre apostrophes');
     G:=GUIDValue(Tokens^[T].S^); Seen:=False;
     For Z:=1 to IDCount do If IDs^[Z]=G Then Seen:=True;
     If Not Seen Then Begin
      If IDCount=MaxTok Then Syntax('Trop de GUID');
      Inc(IDCount); IDs^[IDCount]:=G;
     End;
    End;
   End;
  End;
 End;

Begin
 If IsDelete Then Operation:='DELETE' Else Operation:='UPDATE';
 AtToken:=1; Need(Operation);
 If IsDelete Then Need('FROM');
 ReadEntity;
 If PrimaryKey='' Then Begin
  If Entities[1].Name='account' Then PrimaryKey:='accountid';
  If Entities[1].Name='contact' Then PrimaryKey:='contactid';
  If PrimaryKey='' Then Syntax('Fournir --primary-key avec PrimaryIdAttribute de la table');
 End;
 New(IDs); Assignments:=Nil; Count:=0; IDCount:=0;
 If Not IsDelete Then Begin
  Need('SET'); New(Assignments);
  Repeat
  ReadField(A); Resolve(A);
  If (A.Name='*')or(A.Name=PrimaryKey) Then Syntax('Colonne SET invalide ou cle primaire non modifiable');
  For J:=1 to Count do
   If Assignments^[J].Name=A.Name Then Syntax('Colonne SET dupliquee : '+A.Name);
  If Count=MaxField Then Syntax('Trop de colonnes SET');
  Need('='); InsertValue(K,S);
  If K='D' Then Syntax('DEFAULT dans UPDATE exige les metadonnees de la valeur par defaut');
  Inc(Count); Assignments^[Count].Name:=A.Name;
  Assignments^[Count].Kind:=K; Assignments^[Count].Value:=S;
  More:=Tok=','; If More Then Inc(AtToken);
  Until Not More;
 End;
 Need('WHERE'); N:=ParseOr;
 If Tok=';' Then Inc(AtToken);
 If AtToken<=TokenCount Then Syntax('Construction '+Operation+' non supportee');
 CollectIDs(N);
 For I:=1 to IDCount do Begin
  If I>1 Then Line;
  Emit('### '+Operation+' '); Emit(Entities[1].Name); Emit(' - '); Emit(IDs^[I]); Line;
  If IsDelete Then Emit('DELETE') Else Emit('PATCH');
  Emit(' {{orgUrl}}/api/data/v9.2/');
  If EntitySet='' Then Emit('{{entitySet}}') Else Emit(EntitySet);
  Emit('('); Emit(IDs^[I]); Emit(')'); Line;
  Emit('Authorization: Bearer {{accessToken}}'); Line;
  Emit('Content-Type: application/json; charset=utf-8'); Line;
  Emit('Accept: application/json'); Line;
  Emit('OData-MaxVersion: 4.0'); Line;
  Emit('OData-Version: 4.0'); Line;
  If Not IsDelete Then Begin Emit('If-Match: *'); Line End;
  Line;
  If Not IsDelete Then Begin
   Emit('{'); Line;
   For J:=1 to Count do Begin
   Indent(1); JSONString(Assignments^[J].Name); Emit(': ');
   Case Assignments^[J].Kind of
    'N':Emit('null'); 'S':JSONString(Assignments^[J].Value);
    'V','B':Emit(Assignments^[J].Value);
   End;
   If J<Count Then Emit(','); Line;
   End;
   Emit('}'); Line;
  End;
 End;
 Dispose(IDs); If Assignments<>Nil Then Dispose(Assignments);
End;

Procedure Help;
Begin
 WriteLn('SQL4CDS - SELECT vers FetchXML, INSERT/UPDATE/DELETE vers HTTP (Dataverse)');
 WriteLn;
 WriteLn('Syntaxe : SQL4CDS source.sql [sortie.xml]');
 WriteLn('          SQL4CDS -q "SELECT name FROM account" [-o sortie.xml]');
 WriteLn('          SQL4CDS -i source.sql [-o sortie.xml]');
 WriteLn;
 WriteLn('  -h, --help, /?       Affiche cette aide');
 WriteLn('  -q "SQL"             Requete SQL a convertir');
 WriteLn('  -i source.sql        Fichier SQL source');
 WriteLn('  -o fichier           Sortie FetchXML (SELECT) ou HTTP (INSERT/UPDATE/DELETE)');
 WriteLn('  --entity-set nom     Collection Web API pour INSERT/UPDATE/DELETE');
 WriteLn('  --primary-key nom    PrimaryIdAttribute pour UPDATE/DELETE');
 WriteLn;
 WriteLn('Sans arguments : entree standard. Sans -o : sortie standard.');
 WriteLn('SELECT, DISTINCT, TOP, INNER/LEFT/RIGHT JOIN, WHERE, GROUP BY, ORDER BY.');
 WriteLn('ON : egalite de colonnes, puis AND (filtres de la table liee).');
 WriteLn('RIGHT JOIN : deux tables seulement. Limite FetchXML : 15 jointures.');
 WriteLn('Agregats : COUNT(col), COUNT(DISTINCT col), SUM, AVG, MIN, MAX.');
 WriteLn('Utiliser les noms logiques et qualifier les colonnes des jointures.');
 WriteLn('INSERT INTO entite (colonnes) VALUES (...), (...) ou DEFAULT VALUES.');
 WriteLn('INSERT produit du HTTP/JSON; renseigner orgUrl, accessToken, entitySet.');
 WriteLn('UPDATE entite SET col=valeur,... WHERE cle=''GUID'' ou cle IN (...).');
 WriteLn('DELETE FROM entite WHERE cle=''GUID'' ou cle IN (...).');
 WriteLn('WHERE UPDATE/DELETE : cle primaire seulement, OR accepte, WHERE obligatoire.');
 WriteLn('Un seul SELECT/INSERT/UPDATE/DELETE; aucune requete reseau executee.');
 WriteLn('COUNT(*) et les expressions ne sont pas supportes.');
End;

Procedure Args;
Var I:Integer; S:String;
 Function Argument(N:Integer):String;
 Var V:String;
 Begin
  V:=ParamStr(N);
  If Length(V)>=255 Then Fail('Argument trop long : utiliser un fichier SQL (-i)');
  Argument:=V;
 End;
Begin
 I:=1;
 While I<=ParamCount do Begin
  S:=Argument(I);
  If (S='-h')or(S='--help')or(S='/?') Then Begin Help; Halt(0) End;
  If (S='-q')or(S='-i')or(S='-o')or(S='--entity-set')or(S='--primary-key') Then Begin
   Inc(I); If I>ParamCount Then Begin Help; Halt(2) End;
   If S='-q' Then Begin
    If (Query<>'')or(InputName<>'') Then Begin Help; Halt(2) End;
    Query:=Argument(I);
    If Query='' Then Begin Help; Halt(2) End;
   End;
   If S='-i' Then Begin
    If (Query<>'')or(InputName<>'') Then Begin Help; Halt(2) End;
    InputName:=Argument(I);
   End;
   If S='-o' Then Begin
    If OutputName<>'' Then Begin Help; Halt(2) End;
    OutputName:=Argument(I);
   End;
   If S='--entity-set' Then Begin
    If EntitySet<>'' Then Begin Help; Halt(2) End;
    EntitySet:=Argument(I);
    If EntitySet='' Then Fail('EntitySetName vide');
   End;
   If S='--primary-key' Then Begin
    If PrimaryKey<>'' Then Begin Help; Halt(2) End;
    PrimaryKey:=Lower(Argument(I));
    If (Length(PrimaryKey)=0)or(Length(PrimaryKey)>80) Then Fail('PrimaryIdAttribute invalide');
   End;
  End Else If (Length(S)>0)and(S[1]='-') Then Begin Help; Halt(2) End
  Else If (InputName='')and(Query='') Then InputName:=S
  Else If (OutputName='')and(Query='') Then OutputName:=S
  Else Begin Help; Halt(2) End;
  Inc(I);
 End;
 For I:=1 to Length(EntitySet) do
  If Not(EntitySet[I] in ['A'..'Z','a'..'z','0'..'9','_']) Then
   Fail('EntitySetName invalide');
 For I:=1 to Length(PrimaryKey) do
  If Not(PrimaryKey[I] in ['a'..'z','0'..'9','_']) Then
   Fail('PrimaryIdAttribute invalide');
 If (InputName<>'')and(OutputName<>'')and
  (Upper(FExpand(InputName))=Upper(FExpand(OutputName))) Then
   Fail('Source et cible identiques');
End;

Procedure ReadSQL(Var T:Text);
Var C:Char; Err:Integer;
Begin
 {$I-}
 While Not EOF(T) do Begin
  Read(T,C); Err:=IOResult;
  If Err<>0 Then Fail('Erreur de lecture '+Num(Err));
  AddSource(C);
 End;
 Err:=IOResult;
 {$I+}
 If Err<>0 Then Fail('Erreur de lecture '+Num(Err));
End;

Procedure WriteXML(Var T:Text);
Var I,Err:Integer;
Begin
 {$I-}
 For I:=1 to XMLLen do Begin
  Write(T,XML^[I]); Err:=IOResult;
  If Err<>0 Then Fail('Erreur d''ecriture '+Num(Err));
 End;
 Flush(T); Err:=IOResult;
 {$I+}
 If Err<>0 Then Fail('Erreur d''ecriture '+Num(Err));
End;

Var I,Err:Integer;
Begin
 New(Source); New(XML); New(Tokens); New(Nodes); New(Fields); New(Orders);
 SourceLen:=0; XMLLen:=0; TokenCount:=0; EntityCount:=0;
 FieldCount:=0; OrderCount:=0; NodeCount:=0; Root:=0; Depth:=0;
 BaseEntity:=1; InJoinCondition:=False;
 DistinctRows:=False; AggregateQuery:=False;
 TopValue:=''; InputName:=''; OutputName:=''; Query:=''; EntitySet:=''; PrimaryKey:='';
 Args;
 If Query<>'' Then For I:=1 to Length(Query) do AddSource(Query[I])
 Else If InputName='' Then ReadSQL(Input)
 Else Begin
  Assign(F,InputName); {$I-}Reset(F); Err:=IOResult;{$I+}
  If Err<>0 Then Fail('Impossible d''ouvrir '+InputName);
  ReadSQL(F); Close(F);
 End;
 Lex; AtToken:=1;
 If IsWord('UPDATE') Then ParseModification(False)
 Else If IsWord('DELETE') Then ParseModification(True)
 Else If IsWord('INSERT') Then Begin
  If PrimaryKey<>'' Then Fail('--primary-key est reserve a UPDATE/DELETE');
  ParseInsert;
 End Else Begin
  If EntitySet<>'' Then Fail('--entity-set est reserve a INSERT/UPDATE/DELETE');
  If PrimaryKey<>'' Then Fail('--primary-key est reserve a UPDATE/DELETE');
  Parse;
  Emit('<fetch mapping="logical"');
  If TopValue<>'' Then Attr('top',TopValue);
  If DistinctRows Then Attr('distinct','true');
  If AggregateQuery Then Attr('aggregate','true');
  Emit('>'); Line; EmitEntity(BaseEntity,1); Emit('</fetch>'); Line;
 End;
 If OutputName='' Then WriteXML(Output) Else Begin
  Assign(F,OutputName); {$I-}Rewrite(F); Err:=IOResult;{$I+}
  If Err<>0 Then Fail('Impossible de creer '+OutputName);
  WriteXML(F); {$I-}Close(F); Err:=IOResult;{$I+}
  If Err<>0 Then Fail('Erreur de fermeture du fichier');
 End;
 For I:=1 to TokenCount do Dispose(Tokens^[I].S);
 Dispose(Orders); Dispose(Fields);
 Dispose(Nodes); Dispose(Tokens); Dispose(XML); Dispose(Source);
End.
