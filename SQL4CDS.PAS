{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Conversion SQL SELECT vers FetchXML pour Dataverse.
  @license: MIT
}

Program SQL4CDS(Input,Output);

{ SQL4CDS - Conversion SQL SELECT vers FetchXML pour Dataverse.
  Implementation autonome; aucune dependance .NET ni connexion reseau.
  Reference fonctionnelle : https://github.com/MarkMpn/Sql4Cds
  Target: Turbo Pascal 7 / Free Pascal (-Mtp). License: MIT.

  SQL4CDS source.sql [sortie.xml]
  SQL4CDS -q "SELECT name FROM account" [-o sortie.xml]
  Sans arguments : lecture de l'entree standard jusqu'a EOF.

  SELECT [DISTINCT] [TOP n] colonnes FROM [dbo.]entite [AS alias]
  INNER/LEFT JOIN entite alias ON alias.colonne = alias.colonne
  WHERE : AND, OR, parentheses, =, <>, !=, <, <=, >, >=,
          [NOT] LIKE, [NOT] IN, [NOT] BETWEEN, IS [NOT] NULL.
  ORDER BY colonnes [ASC|DESC]; GROUP BY colonnes;
  COUNT(colonne), COUNT(DISTINCT colonne), SUM, AVG, MIN, MAX.
  COUNT(*) exige les metadonnees de la cle primaire : utiliser COUNT(id).
  Les noms sont les noms logiques Dataverse, pas les libelles affiches.
  Un seul SELECT. Pas de DML, sous-requetes, HAVING, fonctions scalaires,
  expressions calculees, UNION, parametres ou negation d'un groupe.
  Les jointures ON sont une egalite entre colonnes, sans autre predicat.
  Les colonnes non qualifiees designent l'entite principale.
  Limites verifiees : SQL/XML 30000 octets, 1024 jetons, 255 octets
  par jeton, 32 entites, 128 projections/tris, 256 noeuds WHERE.
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
Const MaxBuf=30000; MaxTok=1024; MaxEntity=32; MaxField=128;
      MaxNode=256;
Type
 PStr=^String;
 TBuffer=Array[1..MaxBuf] of Char;
 PBuffer=^TBuffer;
 TToken=Record S:PStr; Kind:Char; Pos:Integer End;
 TTokens=Array[1..MaxTok] of TToken;
 PTokens=^TTokens;
 TEntity=Record Name,AliasName,FromCol,ToCol:String[80];
                Parent:Integer; OuterJoin:Boolean End;
 TField=Record Qual,Name,AliasName:String[80]; Agg:String[16];
               Ent:Integer; Grouped,DistinctValue,Descending:Boolean End;
 TFields=Array[1..MaxField] of TField;
 PFields=^TFields;
 TNode=Record Kind:Char; L,R,FirstValue,LastValue:Integer;
              Name:String[80]; Ent:Integer; Op:String[16] End;
 TNodes=Array[1..MaxNode] of TNode;
 PNodes=^TNodes;
Var Source,XML:PBuffer; Tokens:PTokens; Nodes:PNodes;
    SourceLen,XMLLen,TokenCount,AtToken,EntityCount,FieldCount,
    OrderCount,NodeCount,Root,Depth:Integer;
    Entities:Array[1..MaxEntity] of TEntity;
    Fields,Orders:PFields;
    DistinctRows,AggregateQuery:Boolean;
    TopValue,InputName,OutputName,Query:String;
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
 If Upper(Tok)<>S Then Syntax('Attendu : '+S);
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
  IsWord('HAVING')or IsWord('UNION')or IsWord('OFFSET');
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
 If EntityCount=MaxEntity Then Syntax('Trop d''entites');
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

Procedure Parse;
Var A,B:TField; I,J,E,Code:Integer; S:String; OuterJ,Found:Boolean;
    TopN:LongInt;
Begin
 AtToken:=1; Need('SELECT');
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
 While IsWord('JOIN')or IsWord('INNER')or IsWord('LEFT') do Begin
  OuterJ:=IsWord('LEFT');
  If Not IsWord('JOIN') Then Begin
   Inc(AtToken); If OuterJ and IsWord('OUTER') Then Inc(AtToken);
  End;
  Need('JOIN'); ReadEntity; E:=EntityCount; Need('ON');
  ReadField(A); Resolve(A); Need('='); ReadField(B); Resolve(B);
  If (A.Qual='')or(B.Qual='')or(A.Name='*')or(B.Name='*') Then
   Syntax('ON exige deux colonnes qualifiees');
  If B.Ent=E Then Begin
   S:=A.Name; I:=A.Ent; A:=B; B.Name:=S; B.Ent:=I;
  End;
  If (A.Ent<>E)or(B.Ent>=E) Then
   Syntax('ON doit relier la nouvelle entite a une entite precedente');
  Entities[E].Parent:=B.Ent; Entities[E].FromCol:=A.Name;
  Entities[E].ToCol:=B.Name; Entities[E].OuterJoin:=OuterJ;
  I:=B.Ent;
  While I>1 do Begin
   If (Not OuterJ)and Entities[I].OuterJoin Then
    Syntax('INNER JOIN sous une LEFT JOIN non supporte');
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
 If XMLLen+Length(S)>MaxBuf Then Fail('FetchXML trop long');
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

Procedure EmitFilter(N,Level:Integer);
Var I:Integer;
Begin
 If N=0 Then Exit;
 Indent(Level);
 If Nodes^[N].Kind='C' Then Begin
  Emit('<condition'); Attr('attribute',Nodes^[N].Name);
  If Nodes^[N].Ent<>1 Then
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
  EmitFilter(Nodes^[N].L,Level+1); EmitFilter(Nodes^[N].R,Level+1);
  Indent(Level); Emit('</filter>'); Line;
 End;
End;

Procedure EmitEntity(E,Level:Integer);
Var I:Integer; A:TField;
Begin
 Indent(Level);
 If E=1 Then Emit('<entity') Else Emit('<link-entity');
 Attr('name',Entities[E].Name);
 If E<>1 Then Begin
  Attr('alias',Entities[E].AliasName); Attr('from',Entities[E].FromCol);
  Attr('to',Entities[E].ToCol);
  If Entities[E].OuterJoin Then Attr('link-type','outer')
  Else Attr('link-type','inner');
 End;
 Emit('>'); Line;
 For I:=1 to FieldCount do If Fields^[I].Ent=E Then Begin
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
 If E=1 Then Begin
  For I:=1 to OrderCount do Begin
   A:=Orders^[I]; Indent(Level+1); Emit('<order');
   If A.AliasName<>'' Then Attr('alias',A.AliasName)
   Else Begin
    Attr('attribute',A.Name);
    If A.Ent<>1 Then Attr('entityname',Entities[A.Ent].AliasName);
   End;
   If A.Descending Then Attr('descending','true')
   Else Attr('descending','false');
   Emit(' />'); Line;
  End;
  If Root<>0 Then Begin
   Indent(Level+1); Emit('<filter type="and">'); Line;
   EmitFilter(Root,Level+2);
   Indent(Level+1); Emit('</filter>'); Line;
  End;
 End;
 For I:=2 to EntityCount do If Entities[I].Parent=E Then EmitEntity(I,Level+1);
 Indent(Level);
 If E=1 Then Emit('</entity>') Else Emit('</link-entity>'); Line;
End;

Procedure Help;
Begin
 WriteLn('SQL4CDS - Cette commande permet de lancer le convertisseur SQL SELECT vers FetchXML (Dataverse)');
 WriteLn;
 WriteLn('Syntaxe : SQL4CDS source.sql [sortie.xml]');
 WriteLn('          SQL4CDS -q "SELECT name FROM account" [-o sortie.xml]');
 WriteLn('          SQL4CDS -i source.sql [-o sortie.xml]');
 WriteLn;
 WriteLn('  -h, --help, /?       Affiche cette aide');
 WriteLn('  -q "SQL"             Requete SQL a executer');
 WriteLn('  -i source.sql        Fichier SQL source');
 WriteLn('  -o sortie.xml        Fichier XML de sortie');
 WriteLn;
 WriteLn('Sans arguments : entree standard. Sans -o : sortie standard.');
 WriteLn('SELECT, DISTINCT, TOP, INNER/LEFT JOIN, WHERE, GROUP BY, ORDER BY.');
 WriteLn('Agregats : COUNT(col), COUNT(DISTINCT col), SUM, AVG, MIN, MAX.');
 WriteLn('Utiliser les noms logiques et qualifier les colonnes des jointures.');
 WriteLn('Un seul SELECT; COUNT(*) et les expressions ne sont pas supportes.');
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
  If (S='-q')or(S='-i')or(S='-o') Then Begin
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
  End Else If (Length(S)>0)and(S[1]='-') Then Begin Help; Halt(2) End
  Else If (InputName='')and(Query='') Then InputName:=S
  Else If (OutputName='')and(Query='') Then OutputName:=S
  Else Begin Help; Halt(2) End;
  Inc(I);
 End;
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
 DistinctRows:=False; AggregateQuery:=False;
 TopValue:=''; InputName:=''; OutputName:=''; Query:='';
 Args;
 If Query<>'' Then For I:=1 to Length(Query) do AddSource(Query[I])
 Else If InputName='' Then ReadSQL(Input)
 Else Begin
  Assign(F,InputName); {$I-}Reset(F); Err:=IOResult;{$I+}
  If Err<>0 Then Fail('Impossible d''ouvrir '+InputName);
  ReadSQL(F); Close(F);
 End;
 Lex; Parse;
 Emit('<fetch mapping="logical"');
 If TopValue<>'' Then Attr('top',TopValue);
 If DistinctRows Then Attr('distinct','true');
 If AggregateQuery Then Attr('aggregate','true');
 Emit('>'); Line; EmitEntity(1,1); Emit('</fetch>'); Line;
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
