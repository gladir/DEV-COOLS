{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  @description: Clone de SQL Server lisant directement les fichiers .MDF
  @license: MIT
}

(* ============================================================
  SQLCMD.PAS - Clone SQL Server en ligne de commande
  Turbo Pascal 7 / Free Pascal (-Mtp)

  Lit directement les fichiers .MDF de SQL Server sans
  necessiter d instance SQL Server.
  Supporte les instructions SQL Server built-in.

  TODO 01 - INFRASTRUCTURE ET OPTIONS DE LA LIGNE DE COMMANDE [IMPLEMENTE]
            ParseArgs : analyser argv
              sqlcmd -S fichier.mdf [-d database] [-q "requete"]
              [-i script.sql] [-o sortie.txt] [-v] [-h]
            TOptions (MdfFile, Database, Query, ScriptFile,
              OutputFile, Verbose, Interactive)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Boucle REPL interactive (mode par defaut si pas de -q/-i)
            Affichage de l aide (-h) et version

  TODO 02 - LECTURE DU FORMAT DE FICHIER MDF (EN-TETE)
            Ouvrir le fichier .MDF en mode binaire (BlockRead)
            Lire le File Header (page 0) : signature, version,
              taille de page (8 Ko par defaut), nombre de pages
            Decoder le Boot Page (page 9) : nom de la base,
              DBID, status, compatibilite, collation par defaut
            Valider la signature MDF et la version du format
            Supporter les tailles de page 8192 octets (standard)

  TODO 03 - GESTIONNAIRE DE PAGES ET ALLOCATION MAP
            Lire les pages par numero (SeekPage / ReadPage)
            Decoder les types de pages : Data (1), Index (2),
              Text/Image (3), GAM (8), SGAM (9), IAM (10),
              PFS (11), Boot (13), File Header (15)
            Lire le Global Allocation Map (GAM) pour les extents
            Lire le Shared GAM (SGAM) pour les extents mixtes
            Lire le Page Free Space (PFS) pour l espace libre
            Naviguer dans les IAM chains pour chaque objet

  TODO 04 - LECTURE DES PAGES DE DONNEES (DATA PAGES)
            Decoder le Page Header : pageId, type, level,
              flagBits, indexId, objectId, prevPage, nextPage,
              slotCnt, freeData, freeCnt, reservedCnt, lsn
            Lire le Slot Array (tableau d offsets en fin de page)
            Extraire les enregistrements (rows) par slot offset
            Decoder le format d enregistrement :
              StatusBits A/B, longueur fixe, nombre de colonnes,
              bitmap NULL, nombre de colonnes variables,
              tableau d offsets variables, donnees variables

  TODO 05 - CATALOGUE SYSTEME (METADATA)
            Lire sys.sysschobjs (page 1:34) : object_id, name,
              type (U=table, V=vue, P=procedure, FN=fonction,
              TR=trigger, C=contrainte, D=default)
            Lire sys.syscolpars : column_id, name, xtype,
              length, prec, scale, collationid, status (nullable)
            Lire sys.sysidxstats : index_id, name, type
              (0=heap, 1=clustered, 2=nonclustered)
            Lire sys.sysiscols : colonnes des index
            Lire sys.sysrowsets : allocation_unit, partition
            Reconstruire le schema complet de chaque table

  TODO 06 - DECODAGE DES TYPES DE DONNEES SQL SERVER
            Types entiers : TINYINT (1o), SMALLINT (2o),
              INT (4o), BIGINT (8o), BIT
            Types decimaux : DECIMAL(p,s), NUMERIC(p,s),
              FLOAT, REAL, MONEY, SMALLMONEY
            Types chaines : CHAR(n), VARCHAR(n), VARCHAR(MAX),
              NCHAR(n), NVARCHAR(n), NVARCHAR(MAX), TEXT, NTEXT
            Types date/heure : DATE, TIME, DATETIME, DATETIME2,
              DATETIMEOFFSET, SMALLDATETIME
            Types binaires : BINARY(n), VARBINARY(n),
              VARBINARY(MAX), IMAGE
            Types speciaux : UNIQUEIDENTIFIER (GUID 16 octets),
              XML, SQL_VARIANT, HIERARCHYID, GEOGRAPHY, GEOMETRY
            Conversion interne vers representation Pascal

  TODO 07 - TOKENISEUR SQL (LEXER)
            LexInit : ouvrir le flux SQL (chaine ou fichier)
            LexNextToken : reconnaitre les tokens SQL Server :
              - Identificateurs : [a-zA-Z_][a-zA-Z0-9_@#$]*
              - Identificateurs delimites : [nom] ou "nom"
              - Nombres : 123, 1.5, 1E3, 0x1A2B
              - Chaines : 'texte' (apostrophe doublee '')
              - Chaines Unicode : N'texte'
              - Commentaires ligne : -- commentaire
              - Commentaires bloc : /* ... */
              - Operateurs : + - * / % = <> != !< !> < > <= >=
                += -= *= /= %= &= |= ^=
              - Separateurs : , . ; ( ) :: @
            TOK_IDENT, TOK_NUMBER, TOK_FLOAT, TOK_STRING,
              TOK_NSTRING, TOK_HEX, TOK_VARIABLE, TOK_TEMPOBJ,
              TOK_PARAM, TOK_PLUS, TOK_MINUS, TOK_STAR,
              TOK_SLASH, TOK_PERCENT, TOK_EQ, TOK_NE,
              TOK_LT, TOK_GT, TOK_LE, TOK_GE, TOK_LPAREN,
              TOK_RPAREN, TOK_COMMA, TOK_DOT, TOK_SEMICOL,
              TOK_AT, TOK_EOF

  TODO 08 - RECONNAISSANCE DES MOTS-CLES SQL SERVER
            Function IsKeyword(Const s: String): Integer
            Mots-cles DML : SELECT, INSERT, UPDATE, DELETE,
              MERGE, TRUNCATE, BULK INSERT
            Mots-cles DDL : CREATE, ALTER, DROP, TABLE, VIEW,
              INDEX, PROCEDURE, FUNCTION, TRIGGER, DATABASE,
              SCHEMA, SEQUENCE, TYPE, SYNONYM
            Mots-cles clauses : FROM, WHERE, GROUP BY, HAVING,
              ORDER BY, JOIN, INNER, LEFT, RIGHT, FULL, OUTER,
              CROSS, ON, AS, INTO, VALUES, SET, TOP, DISTINCT,
              ALL, UNION, INTERSECT, EXCEPT, WITH, OVER,
              PARTITION BY, ROWS, RANGE, BETWEEN, AND, OR, NOT,
              IN, EXISTS, LIKE, IS, NULL, CASE, WHEN, THEN,
              ELSE, END, CAST, CONVERT, COLLATE, PIVOT, UNPIVOT,
              APPLY, CROSS APPLY, OUTER APPLY, OFFSET, FETCH,
              NEXT, ONLY, PERCENT, TIES
            Mots-cles controle : BEGIN, END, IF, ELSE, WHILE,
              BREAK, CONTINUE, GOTO, RETURN, WAITFOR, THROW,
              TRY, CATCH, RAISERROR, PRINT, EXEC, EXECUTE,
              DECLARE, SET, USE, GO
            Mots-cles transaction : BEGIN TRAN, COMMIT, ROLLBACK,
              SAVE, TRANSACTION
            Mots-cles DCL : GRANT, REVOKE, DENY

  TODO 09 - PARSEUR D EXPRESSIONS SQL
            ParseExpr : expressions arithmetiques (+, -, *, /, %)
            ParseCompare : =, <>, <, >, <=, >=, !=, !<, !>
            ParseLogical : AND, OR, NOT, BETWEEN, IN, EXISTS,
              LIKE, IS NULL, IS NOT NULL
            ParseUnary : +expr, -expr, ~expr, NOT expr
            ParseAtom : nombre, chaine, N'...', variable @v,
              NULL, DEFAULT, (sous-expression), fonction(...)
            CASE WHEN expr THEN expr [ELSE expr] END
            CASE expr WHEN val THEN expr [ELSE expr] END
            CAST(expr AS type), CONVERT(type, expr [, style])
            expr COLLATE collation_name
            Sous-requetes scalaires : (SELECT ...)
            Operateur LIKE avec wildcards %, _, [abc], [^abc]

  TODO 10 - PARSEUR SELECT (REQUETES DE LECTURE)
            SELECT [ALL|DISTINCT] [TOP n [PERCENT] [WITH TIES]]
              liste_colonnes | *
            FROM table [AS alias] [WITH (NOLOCK|...)]
            Jointures : INNER/LEFT/RIGHT/FULL OUTER/CROSS JOIN
              table ON condition
            CROSS APPLY / OUTER APPLY (sous-requete | fonction)
            PIVOT / UNPIVOT
            WHERE condition
            GROUP BY liste_colonnes [WITH ROLLUP|CUBE]
            HAVING condition
            ORDER BY liste [ASC|DESC] [NULLS FIRST|LAST]
            OFFSET n ROWS FETCH NEXT m ROWS ONLY
            UNION [ALL] / INTERSECT / EXCEPT
            WITH cte_name AS (SELECT ...) - Common Table Expr.
            SELECT INTO #temp / nouvelle_table
            FOR XML PATH|RAW|AUTO|EXPLICIT
            FOR JSON PATH|AUTO
            OPTION (query hints)

  TODO 11 - PARSEUR INSERT / UPDATE / DELETE / MERGE
            INSERT [INTO] table [(colonnes)] VALUES (v1,..)
            INSERT INTO table SELECT ...
            INSERT INTO table DEFAULT VALUES
            INSERT INTO table EXEC procedure
            OUTPUT INSERTED.*, DELETED.*
            UPDATE table SET col=expr [FROM ...] [WHERE ...]
            UPDATE TOP(n) table SET ...
            DELETE [FROM] table [WHERE ...]
            DELETE TOP(n) FROM table
            TRUNCATE TABLE table
            MERGE INTO target USING source ON condition
              WHEN MATCHED THEN UPDATE SET ...
              WHEN NOT MATCHED THEN INSERT ...
              WHEN NOT MATCHED BY SOURCE THEN DELETE
            OUTPUT clause pour INSERT/UPDATE/DELETE/MERGE

  TODO 12 - PARSEUR DDL (CREATE / ALTER / DROP)
            CREATE TABLE nom (col type [contraintes], ...)
              Contraintes : PRIMARY KEY, UNIQUE, NOT NULL,
              DEFAULT, CHECK, FOREIGN KEY REFERENCES,
              IDENTITY(seed,increment), CLUSTERED/NONCLUSTERED
            CREATE INDEX / CREATE UNIQUE INDEX
              [CLUSTERED|NONCLUSTERED] ON table(cols)
              INCLUDE (cols), WHERE filtre, WITH (options)
            CREATE VIEW nom AS SELECT ...
              WITH SCHEMABINDING, WITH CHECK OPTION
            CREATE PROCEDURE nom @params AS BEGIN ... END
            CREATE FUNCTION nom (@params) RETURNS type
              AS BEGIN ... RETURN expr END
            CREATE TRIGGER nom ON table FOR/AFTER/INSTEAD OF
              INSERT/UPDATE/DELETE AS BEGIN ... END
            CREATE SCHEMA, CREATE SEQUENCE, CREATE TYPE
            CREATE DATABASE nom
            ALTER TABLE ADD/ALTER/DROP COLUMN
            ALTER INDEX REBUILD/REORGANIZE/DISABLE
            DROP TABLE/VIEW/INDEX/PROCEDURE/FUNCTION/TRIGGER
              [IF EXISTS]

  TODO 13 - PARSEUR DES INSTRUCTIONS DE CONTROLE T-SQL
            DECLARE @variable type [= valeur]
            DECLARE @table_var TABLE (col type, ...)
            SET @variable = expression
            SELECT @variable = expression
            IF condition BEGIN ... END [ELSE BEGIN ... END]
            WHILE condition BEGIN ... END
            BREAK, CONTINUE
            BEGIN ... END (blocs)
            GOTO label, label:
            RETURN [valeur]
            WAITFOR DELAY 'hh:mm:ss'
            WAITFOR TIME 'hh:mm:ss'
            BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH
            THROW [numero, message, state]
            RAISERROR (message, severity, state)
            PRINT expression
            EXEC / EXECUTE procedure [@ret =] proc @p1, @p2
            EXEC('chaine SQL dynamique')
            sp_executesql N'requete', N'@p1 type', @p1=val
            USE database
            GO (separateur de batch)

  TODO 14 - PARSEUR DCL (GRANT / REVOKE / DENY)
            GRANT permission ON objet TO principal
            REVOKE permission ON objet FROM principal
            DENY permission ON objet TO principal
            Permissions : SELECT, INSERT, UPDATE, DELETE,
              EXECUTE, ALTER, CONTROL, VIEW DEFINITION,
              REFERENCES, TAKE OWNERSHIP
            Types de principal : user, role, login, public
            GRANT permission TO role
            ALTER ROLE role ADD MEMBER user
            CREATE LOGIN / CREATE USER
            ALTER LOGIN / ALTER USER
            DROP LOGIN / DROP USER

  TODO 15 - MOTEUR D EXECUTION DES REQUETES (QUERY ENGINE)
            Architecture pipeline :
              Parse -> Bind -> Optimize -> Execute
            Scan sequentiel (Table Scan) sur les pages de donnees
            Filtrage WHERE (evaluation d expressions booleennes)
            Projection (selection des colonnes demandees)
            Tri en memoire pour ORDER BY (algorithme QuickSort)
            Elimination des doublons pour DISTINCT (tri + merge)
            Calcul TOP n avec ou sans PERCENT
            Sous-requetes correlees et non correlees
            Materialisation des resultats intermediaires
            Gestion du buffer pool (cache de pages en memoire)
            Limite memoire configurable pour les tris

  TODO 16 - JOINTURES ET OPERATEURS ENSEMBLISTES
            Nested Loop Join : pour chaque ligne de la table
              externe, scanner la table interne
            Hash Join : construire une table de hachage sur la
              table interne, probe avec la table externe
            Merge Join : scanner les deux tables triees en
              parallele (necessite index ou tri prealable)
            Selection automatique de l algorithme de jointure
              selon la taille des tables et les index disponibles
            CROSS JOIN (produit cartesien)
            LEFT/RIGHT/FULL OUTER JOIN avec gestion des NULLs
            UNION [ALL] : concatenation avec/sans doublons
            INTERSECT : intersection des ensembles
            EXCEPT : difference des ensembles
            CROSS APPLY / OUTER APPLY

  TODO 17 - FONCTIONS D AGREGATION ET GROUP BY
            COUNT(etoile), COUNT(col), COUNT(DISTINCT col)
            SUM(col), AVG(col), MIN(col), MAX(col)
            STDEV(col), STDEVP(col), VAR(col), VARP(col)
            STRING_AGG(col, separateur) [WITHIN GROUP ORDER BY]
            GROUPING(col), GROUPING_ID(col1, col2, ...)
            GROUP BY colonnes
            GROUP BY ROLLUP(colonnes)
            GROUP BY CUBE(colonnes)
            GROUP BY GROUPING SETS((col1),(col2),())
            HAVING condition (filtre post-agregation)
            Gestion des NULLs dans les agregats (ignores)
            Hash Aggregate vs Stream Aggregate

  TODO 18 - FONCTIONS DE FENETRE (WINDOW FUNCTIONS)
            ROW_NUMBER() OVER (ORDER BY ...)
            RANK() OVER (ORDER BY ...)
            DENSE_RANK() OVER (ORDER BY ...)
            NTILE(n) OVER (ORDER BY ...)
            OVER (PARTITION BY ... ORDER BY ...)
            Fonctions d agregat en fenetre :
              SUM/AVG/COUNT/MIN/MAX OVER (...)
            LAG(col, offset, defaut) OVER (ORDER BY ...)
            LEAD(col, offset, defaut) OVER (ORDER BY ...)
            FIRST_VALUE(col) OVER (ORDER BY ...)
            LAST_VALUE(col) OVER (ORDER BY ...)
            PERCENT_RANK() OVER (ORDER BY ...)
            CUME_DIST() OVER (ORDER BY ...)
            PERCENTILE_CONT / PERCENTILE_DISC
            Frame : ROWS/RANGE BETWEEN ... AND ...
              UNBOUNDED PRECEDING, n PRECEDING,
              CURRENT ROW, n FOLLOWING, UNBOUNDED FOLLOWING

  TODO 19 - FONCTIONS SCALAIRES BUILT-IN : CHAINES
            LEN(s), DATALENGTH(s)
            LEFT(s,n), RIGHT(s,n), SUBSTRING(s,start,len)
            LTRIM(s), RTRIM(s), TRIM(s)
            UPPER(s), LOWER(s)
            REPLACE(s, chercher, remplacer)
            REPLICATE(s, n)
            REVERSE(s)
            CHARINDEX(sous, s [,start])
            PATINDEX(pattern, s)
            STUFF(s, start, len, insertion)
            CONCAT(s1, s2, ...), CONCAT_WS(sep, s1, s2, ...)
            FORMAT(valeur, format [, culture])
            STRING_SPLIT(s, separateur)
            QUOTENAME(s [, delimiteur])
            CHAR(n), ASCII(s), UNICODE(s), NCHAR(n)
            SPACE(n), STR(float [,len [,dec]])
            SOUNDEX(s), DIFFERENCE(s1, s2)
            TRANSLATE(s, from_chars, to_chars)
            STRING_ESCAPE(s, type)

  TODO 20 - FONCTIONS SCALAIRES BUILT-IN : DATES ET HEURES
            GETDATE(), GETUTCDATE(), SYSDATETIME(),
              SYSUTCDATETIME(), SYSDATETIMEOFFSET()
            DATEADD(part, n, date)
            DATEDIFF(part, start, end)
            DATEDIFF_BIG(part, start, end)
            DATEPART(part, date), DATENAME(part, date)
            YEAR(date), MONTH(date), DAY(date)
            EOMONTH(date [, offset])
            DATEFROMPARTS(y,m,d)
            DATETIME2FROMPARTS(y,m,d,h,mi,s,frac,prec)
            DATETIMEFROMPARTS(y,m,d,h,mi,s,ms)
            SMALLDATETIMEFROMPARTS(y,m,d,h,mi)
            TIMEFROMPARTS(h,mi,s,frac,prec)
            DATETIMEOFFSETFROMPARTS(y,m,d,h,mi,s,frac,
              h_offset, m_offset, prec)
            ISDATE(expression)
            SWITCHOFFSET(datetimeoffset, timezone)
            TODATETIMEOFFSET(datetime, timezone)
            Parties de date : year, quarter, month, dayofyear,
              day, week, weekday, hour, minute, second,
              millisecond, microsecond, nanosecond

  TODO 21 - FONCTIONS SCALAIRES BUILT-IN : MATHEMATIQUES
            ABS(n), SIGN(n), CEILING(n), FLOOR(n), ROUND(n,d)
            POWER(x, y), SQRT(x), SQUARE(x), EXP(x), LOG(x),
              LOG(x, base), LOG10(x)
            SIN(x), COS(x), TAN(x), COT(x),
              ASIN(x), ACOS(x), ATAN(x), ATN2(y, x)
            PI(), DEGREES(x), RADIANS(x)
            RAND([seed])
            CHOOSE(index, val1, val2, ...)
            IIF(condition, val_true, val_false)
            GREATEST(val1, val2, ...), LEAST(val1, val2, ...)

  TODO 22 - FONCTIONS SCALAIRES BUILT-IN : CONVERSION ET SYSTEME
            CAST(expr AS type)
            CONVERT(type, expr [, style])
            TRY_CAST(expr AS type)
            TRY_CONVERT(type, expr [, style])
            PARSE(string AS type [USING culture])
            TRY_PARSE(string AS type [USING culture])
            ISNULL(expr, remplacement)
            ISNUMERIC(expr), ISDATE(expr)
            COALESCE(expr1, expr2, ...)
            NULLIF(expr1, expr2)
            @@IDENTITY, SCOPE_IDENTITY(), IDENT_CURRENT(table)
            @@ROWCOUNT, @@ERROR, @@TRANCOUNT
            @@VERSION, @@SERVERNAME, @@SPID
            NEWID(), NEWSEQUENTIALID()
            OBJECT_ID(name), OBJECT_NAME(id)
            DB_ID(name), DB_NAME(id)
            SCHEMA_ID(name), SCHEMA_NAME(id)
            USER_ID(name), USER_NAME(id)
            HOST_NAME(), APP_NAME(), SUSER_SNAME()
            ORIGINAL_LOGIN(), CURRENT_USER, SESSION_USER,
              SYSTEM_USER
            @@FETCH_STATUS (pour curseurs)
            ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_SEVERITY(),
              ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE()
            XACT_STATE()

  TODO 23 - FONCTIONS SCALAIRES BUILT-IN : JSON ET XML
            JSON : ISJSON(s), JSON_VALUE(s, path),
              JSON_QUERY(s, path), JSON_MODIFY(s, path, val),
              OPENJSON(s [, path]) WITH (schema),
              FOR JSON PATH, FOR JSON AUTO
            XML : query(xquery), value(xquery, type),
              exist(xquery), modify(xml_dml),
              nodes(xquery) AS table(col),
              OPENXML(handle, rowpattern) WITH (schema),
              FOR XML PATH, FOR XML RAW, FOR XML AUTO,
              FOR XML EXPLICIT
            sp_xml_preparedocument, sp_xml_removedocument

  TODO 24 - LECTURE DES INDEX (B-TREE)
            Decoder les pages d index (type 2) : structure B-Tree
            Lire la page racine de l index (sys.sysidxstats)
            Parcourir les niveaux intermediaires (non-leaf)
            Lire les pages feuilles (leaf level) :
              - Index clustered : les feuilles sont les donnees
              - Index non-clustered : les feuilles contiennent
                les cles + RID ou cle clustered
            Index Seek : recherche par cle dans le B-Tree
            Index Scan : parcours sequentiel des feuilles
            Utiliser les index pour accelerer WHERE, JOIN,
              ORDER BY et GROUP BY
            Index couvrants (INCLUDE columns) : eviter le
              Key Lookup en lisant les colonnes directement
            Index filtres (WHERE dans CREATE INDEX)

  TODO 25 - OPTIMISEUR DE REQUETES (QUERY OPTIMIZER)
            Statistiques de base : nombre de lignes par table,
              nombre de pages, densite des index
            Estimation de cardinalite pour les filtres WHERE
            Selection du plan d acces : Table Scan vs Index Seek
              vs Index Scan vs Key Lookup
            Selection de l algorithme de jointure :
              Nested Loop vs Hash vs Merge
            Ordre de jointure optimal (heuristique gloutonne)
            Transformation des sous-requetes en jointures
            Elimination des expressions constantes
            Pushdown des predicats (pousser les filtres au
              plus pres de la source des donnees)
            Plan d execution textuel (SET SHOWPLAN_TEXT ON)
            SET STATISTICS IO ON : afficher les I/O par table

  TODO 26 - CURSEURS ET VARIABLES TABLE
            DECLARE nom CURSOR FOR SELECT ...
            OPEN nom, FETCH NEXT FROM nom INTO @vars
            CLOSE nom, DEALLOCATE nom
            @@FETCH_STATUS : 0 (succes), -1 (fin), -2 (manquant)
            Types de curseur : FORWARD_ONLY, SCROLL,
              STATIC, KEYSET, DYNAMIC, FAST_FORWARD
            FETCH FIRST/LAST/PRIOR/NEXT/ABSOLUTE n/RELATIVE n
            Curseurs imbriques
            DECLARE @t TABLE (col type, ...) : variables table
            INSERT INTO @t, SELECT FROM @t, UPDATE @t, DELETE @t
            Passage de variables table en parametre (READONLY)

  TODO 27 - PROCEDURES STOCKEES ET FONCTIONS UTILISATEUR
            Stockage des corps de procedures dans un catalogue
              interne (texte SQL)
            EXEC / EXECUTE procedure @param1, @param2
            Parametres INPUT, OUTPUT, DEFAULT
            RETURN code_retour
            Fonctions scalaires : RETURNS type
            Fonctions table : RETURNS TABLE AS RETURN (SELECT...)
            Fonctions table multi-instructions :
              RETURNS @t TABLE (...) AS BEGIN ... RETURN END
            Recursion (procedures/fonctions s appelant elles-memes)
            Procedures systeme : sp_help, sp_helptext,
              sp_columns, sp_tables, sp_databases,
              sp_who, sp_lock, sp_spaceused
            Fonctions systeme : OBJECT_ID, OBJECT_NAME,
              COL_NAME, TYPE_NAME, INDEX_COL

  TODO 28 - TRANSACTIONS ET VERROUILLAGE
            BEGIN TRANSACTION [nom]
            COMMIT TRANSACTION [nom]
            ROLLBACK TRANSACTION [nom | savepoint]
            SAVE TRANSACTION savepoint
            @@TRANCOUNT
            Niveaux d isolation :
              READ UNCOMMITTED, READ COMMITTED,
              REPEATABLE READ, SERIALIZABLE, SNAPSHOT
            SET TRANSACTION ISOLATION LEVEL ...
            Hints de table : WITH (NOLOCK), WITH (HOLDLOCK),
              WITH (UPDLOCK), WITH (TABLOCK), WITH (ROWLOCK)
            Journal de transactions basique (write-ahead log)
              en memoire pour supporter ROLLBACK dans un batch
            XACT_STATE() dans les blocs CATCH
            Transactions imbriquees (semantique SQL Server :
              seul le COMMIT externe valide reellement)

  TODO 29 - FORMATAGE DE LA SORTIE ET COMPATIBILITE SQLCMD
            Affichage tabulaire des resultats (colonnes alignees
              avec en-tetes et separateurs)
            SET NOCOUNT ON/OFF : masquer/afficher le compteur
              de lignes affectees
            SET QUOTED_IDENTIFIER ON/OFF
            SET ANSI_NULLS ON/OFF
            SET DATEFORMAT mdy/dmy/ymd
            SET LANGUAGE francais/english/...
            Redirection de la sortie vers fichier (-o)
            Mode separateur : -s caractere (defaut: espace)
            Mode CSV : -W (supprimer les espaces de fin)
            Mode vertical : afficher chaque colonne sur une ligne
            Messages d erreur et de diagnostic (severity levels)
            Compteur de lignes affectees (n rows affected)
            Codes de retour SQLCMD (0=succes, 1=erreur)

  TODO 30 - TESTS ET COMPATIBILITE SQL SERVER
            Suite de tests unitaires pour le lexer
            Tests du parseur sur des requetes simples/complexes
            Tests de lecture MDF : fichiers MDF de reference
              generes par SQL Server (bases AdventureWorks,
              Northwind, ou bases de test minimales)
            Tests des fonctions scalaires (chaines, dates, math)
            Tests des jointures (toutes variantes)
            Tests des fonctions d agregation et GROUP BY
            Tests des fonctions de fenetre
            Tests des CTE recursives et non recursives
            Tests du MERGE statement
            Tests de compatibilite T-SQL :
              DECLARE, IF/ELSE, WHILE, TRY/CATCH
            Tests de performance : tables avec >10000 lignes
            Comparaison des resultats avec SQL Server de ref.
            Script de test automatise (batch .BAT / .SH)
   ============================================================ *)

Program SQLCMD;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  SQLCMD_VERSION = '1.0';
  SQLCMD_DATE    = '2026-03-21';

  MAX_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ERRORS = {$IFDEF FPC}30{$ELSE}3{$ENDIF};

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Taille de ligne REPL }
  MAX_INPUT  = 4096;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de la ligne de commande ---------------------- }
  TOptions = Record
    MdfFile    : TString;   { -S : fichier .MDF principal          }
    Database   : TString;   { -d : base de donnees                 }
    Query      : TString;   { -q : requete SQL a executer          }
    ScriptFile : TString;   { -i : fichier script SQL en entree    }
    OutputFile : TString;   { -o : fichier de sortie               }
    Verbose    : Boolean;   { -v : mode verbeux                    }
    Interactive: Boolean;   { REPL interactif (si pas -q/-i)       }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts       : TOptions;
  ErrorCount : Integer;
  WarnCount  : Integer;
  OutF       : Text;
  OutFOpen   : Boolean;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Utilitaires chaines ------------------------------------ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ ---- Messages d erreur et d avertissement -------------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('SQLCMD: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  WriteLn('SQLCMD:warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere et aide ---------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('SQLCMD v', SQLCMD_VERSION, ' (', SQLCMD_DATE, ')');
  WriteLn('Clone SQL Server - lecture directe des fichiers .MDF');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: SQLCMD -S <fichier.mdf> [options]');
  WriteLn;
  WriteLn('  -S fichier.mdf : fichier MDF a ouvrir (obligatoire)');
  WriteLn('  -d database    : nom de la base de donnees');
  WriteLn('  -q "requete"   : executer une requete et quitter');
  WriteLn('  -i script.sql  : executer un script SQL et quitter');
  WriteLn('  -o sortie.txt  : rediriger la sortie vers un fichier');
  WriteLn('  -v             : mode verbeux');
  WriteLn('  -h             : afficher cette aide');
  WriteLn;
  WriteLn('Mode interactif (REPL) par defaut si -q et -i absents.');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  WriteLn('SQLCMD v', SQLCMD_VERSION,
          ' - Clone SQL Server en ligne de commande');
  WriteLn;
  ShowUsage;
End;

{ ---- Initialisation des options ------------------------------ }

Procedure InitOptions;
Begin
  Opts.MdfFile    := '';
  Opts.Database   := '';
  Opts.Query      := '';
  Opts.ScriptFile := '';
  Opts.OutputFile := '';
  Opts.Verbose    := False;
  Opts.Interactive := False;
End;

{ ---- Analyse des arguments de la ligne de commande ----------- }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-S') Or (Arg = '-s') Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -S requiert un argument (fichier .MDF)');
      Opts.MdfFile := ParamStr(I);
    End
    Else If (Arg = '-d') Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -d requiert un argument (nom de base)');
      Opts.Database := ParamStr(I);
    End
    Else If (Arg = '-q') Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -q requiert un argument (requete SQL)');
      Opts.Query := ParamStr(I);
    End
    Else If (Arg = '-i') Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -i requiert un argument (fichier .SQL)');
      Opts.ScriptFile := ParamStr(I);
    End
    Else If (Arg = '-o') Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -o requiert un argument (fichier sortie)');
      Opts.OutputFile := ParamStr(I);
    End
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('SQLCMD: option inconnue: ', Arg);
      ShowUsage;
    End
    Else
    Begin
      { Argument positionnel : traiter comme fichier .MDF }
      If Opts.MdfFile = '' Then
        Opts.MdfFile := Arg
      Else
      Begin
        WriteLn('SQLCMD: argument inattendu: ', Arg);
        ShowUsage;
      End;
    End;

    Inc(I);
  End;

  { Valider le fichier MDF obligatoire }
  If Opts.MdfFile = '' Then
  Begin
    WriteLn('SQLCMD: fichier .MDF manquant (option -S)');
    ShowUsage;
  End;

  { Verifier l extension }
  Ext := ExtractExt(Opts.MdfFile);
  If (Ext <> '.mdf') Then
    WarnMsg('extension attendue .mdf, obtenu ' + Ext);

  { Determiner le mode interactif }
  If (Opts.Query = '') And (Opts.ScriptFile = '') Then
    Opts.Interactive := True;

  { Ouvrir le fichier de sortie si specifie }
  If Opts.OutputFile <> '' Then
  Begin
    Assign(OutF, Opts.OutputFile);
    Rewrite(OutF);
    If IOResult <> 0 Then
      FatalError('impossible d''ouvrir le fichier de sortie: '
                  + Opts.OutputFile);
    OutFOpen := True;
  End;
End;

{ ---- Ecriture vers sortie (ecran ou fichier) ----------------- }

Procedure OutputLine(Const S : String);
Begin
  If OutFOpen Then
    WriteLn(OutF, S)
  Else
    WriteLn(S);
End;

{ ---- Execution d une requete SQL ----------------------------- }

Procedure ExecuteQuery(Const SQL : TString);
Begin
  { TODO 07..15 : tokeniser, parser, executer la requete }
  OutputLine('-- Requete recue : ' + SQL);
  OutputLine('-- (moteur non encore implemente)');
End;

{ ---- Execution d un script SQL ------------------------------- }

Procedure ExecuteScript(Const FileName : TString);
Var
  F    : Text;
  Line : TString;
  Buf  : TString;
Begin
  Assign(F, FileName);
  Reset(F);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le script: ' + FileName);

  Buf := '';
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    { GO = separateur de batch }
    If StrUpperCase(Line) = 'GO' Then
    Begin
      If Buf <> '' Then
      Begin
        ExecuteQuery(Buf);
        Buf := '';
      End;
    End
    Else
    Begin
      If Buf <> '' Then
        Buf := Buf + ' ';
      Buf := Buf + Line;
    End;
  End;
  Close(F);

  { Executer le dernier batch s il reste du contenu }
  If Buf <> '' Then
    ExecuteQuery(Buf);
End;

{ ---- Boucle REPL interactive --------------------------------- }

Procedure RunREPL;
Var
  Line : TString;
  Buf  : TString;
Begin
  WriteLn('SQLCMD v', SQLCMD_VERSION,
          ' - tapez vos requetes SQL, GO pour executer, EXIT pour quitter.');
  WriteLn;

  Buf := '';
  Repeat
    If Buf = '' Then
      Write('1> ')
    Else
      Write(IntToStr(Length(Buf) Div 40 + 2), '> ');

    ReadLn(Line);
    If IOResult <> 0 Then
    Begin
      WriteLn;
      Exit;  { Ctrl+Z / EOF }
    End;

    { Commande EXIT / QUIT }
    If (StrUpperCase(Line) = 'EXIT') Or
       (StrUpperCase(Line) = 'QUIT') Then
      Exit;

    { GO = executer le batch accumule }
    If StrUpperCase(Line) = 'GO' Then
    Begin
      If Buf <> '' Then
      Begin
        ExecuteQuery(Buf);
        Buf := '';
      End;
    End
    Else
    Begin
      If Buf <> '' Then
        Buf := Buf + ' ';
      Buf := Buf + Line;
    End;
  Until False;
End;

{ ---- Nettoyage ----------------------------------------------- }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  OutFOpen   := False;

  ParseArgs;

  If Opts.Verbose Then
    ShowBanner;

  If Opts.Verbose Then
    WriteLn('  Fichier MDF : ', Opts.MdfFile);

  { Executer selon le mode }
  If Opts.Query <> '' Then
  Begin
    { Mode requete unique (-q) }
    ExecuteQuery(Opts.Query);
  End
  Else If Opts.ScriptFile <> '' Then
  Begin
    { Mode script (-i) }
    ExecuteScript(Opts.ScriptFile);
  End
  Else If Opts.Interactive Then
  Begin
    { Mode REPL interactif }
    RunREPL;
  End;

  Cleanup;

  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
