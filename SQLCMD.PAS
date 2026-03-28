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

  TODO 02 - LECTURE DU FORMAT DE FICHIER MDF (EN-TETE) [IMPLEMENTE]
            Ouvrir le fichier .MDF en mode binaire (BlockRead)
            Lire le File Header (page 0) : signature, version,
              taille de page (8 Ko par defaut), nombre de pages
            Decoder le Boot Page (page 9) : nom de la base,
              DBID, status, compatibilite, collation par defaut
            Valider la signature MDF et la version du format
            Supporter les tailles de page 8192 octets (standard)

  TODO 03 - GESTIONNAIRE DE PAGES ET ALLOCATION MAP [IMPLEMENTE]
            Lire les pages par numero (SeekPage / ReadPage)
            Decoder les types de pages : Data (1), Index (2),
              Text/Image (3), GAM (8), SGAM (9), IAM (10),
              PFS (11), Boot (13), File Header (15)
            Lire le Global Allocation Map (GAM) pour les extents
            Lire le Shared GAM (SGAM) pour les extents mixtes
            Lire le Page Free Space (PFS) pour l espace libre
            Naviguer dans les IAM chains pour chaque objet

  TODO 04 - LECTURE DES PAGES DE DONNEES (DATA PAGES) [IMPLEMENTE]
            Decoder le Page Header : pageId, type, level,
              flagBits, indexId, objectId, prevPage, nextPage,
              slotCnt, freeData, freeCnt, reservedCnt, lsn
            Lire le Slot Array (tableau d offsets en fin de page)
            Extraire les enregistrements (rows) par slot offset
            Decoder le format d enregistrement :
              StatusBits A/B, longueur fixe, nombre de colonnes,
              bitmap NULL, nombre de colonnes variables,
              tableau d offsets variables, donnees variables

  TODO 05 - CATALOGUE SYSTEME (METADATA) [IMPLEMENTE]
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

  TODO 06 - DECODAGE DES TYPES DE DONNEES SQL SERVER [IMPLEMENTE]
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

  TODO 07 - TOKENISEUR SQL (LEXER) [IMPLEMENTE]
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

  TODO 08 - RECONNAISSANCE DES MOTS-CLES SQL SERVER [IMPLEMENTE]
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

  TODO 09 - PARSEUR D EXPRESSIONS SQL [IMPLEMENTE]
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

  TODO 10 - PARSEUR SELECT (REQUETES DE LECTURE) [IMPLEMENTE]
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

  TODO 11 - PARSEUR INSERT / UPDATE / DELETE / MERGE [IMPLEMENTE]
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

  TODO 12 - PARSEUR DDL (CREATE / ALTER / DROP) [IMPLEMENTE]
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

  TODO 13 - PARSEUR DES INSTRUCTIONS DE CONTROLE T-SQL [IMPLEMENTE]
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

  TODO 14 - PARSEUR DCL (GRANT / REVOKE / DENY) [IMPLEMENTE]
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

  TODO 15 - MOTEUR D EXECUTION DES REQUETES (QUERY ENGINE) [IMPLEMENTE]
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

  TODO 16 - JOINTURES ET OPERATEURS ENSEMBLISTES [IMPLEMENTE]
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

  TODO 17 - FONCTIONS D AGREGATION ET GROUP BY [IMPLEMENTE]
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

  TODO 18 - FONCTIONS DE FENETRE (WINDOW FUNCTIONS) [IMPLEMENTE]
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

  TODO 19 - FONCTIONS SCALAIRES BUILT-IN : CHAINES [IMPLEMENTE]
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

  TODO 20 - FONCTIONS SCALAIRES BUILT-IN : DATES ET HEURES [IMPLEMENTE]
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

  TODO 21 - FONCTIONS SCALAIRES BUILT-IN : MATHEMATIQUES [IMPLEMENTE]
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

  TODO 22 - FONCTIONS SCALAIRES BUILT-IN : CONVERSION ET SYSTEME [IMPLEMENTE]
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

  { ---- Constantes MDF (TODO 02) ------------------------------ }
  MDF_PAGE_SIZE      = 8192;   { taille d une page MDF en octets     }
  MDF_PAGE_HDR_SIZE  = 96;     { taille de l en-tete de page         }
  MDF_FILE_HDR_PAGE  = 0;      { numero de la page File Header       }
  MDF_BOOT_PAGE      = 9;      { numero de la page Boot              }

  { Types de pages MDF }
  MDF_PT_DATA        = 1;      { Data Page                           }
  MDF_PT_INDEX       = 2;      { Index Page                          }
  MDF_PT_TEXTIMAGE   = 3;      { Text/Image (LOB) Page               }
  MDF_PT_TEXTTREE    = 4;      { Text Tree Page                      }
  MDF_PT_SORT        = 7;      { Sort Page                           }
  MDF_PT_GAM         = 8;      { Global Allocation Map               }
  MDF_PT_SGAM        = 9;      { Shared GAM                          }
  MDF_PT_IAM         = 10;     { Index Allocation Map                }
  MDF_PT_PFS         = 11;     { Page Free Space                     }
  MDF_PT_BOOT        = 13;     { Boot Page                           }
  MDF_PT_FILEHDR     = 15;     { File Header Page                    }
  MDF_PT_DCM         = 16;     { Differential Changed Map            }
  MDF_PT_BCM         = 17;     { Bulk Changed Map                    }

  { Offsets dans l en-tete de page (96 octets) }
  MDF_HDR_HEADERVER  = 0;      { 1 oct : version en-tete (=1)        }
  MDF_HDR_TYPE       = 1;      { 1 oct : type de page                }
  MDF_HDR_TYPEFLAG   = 2;      { 1 oct : drapeaux de type            }
  MDF_HDR_LEVEL      = 3;      { 1 oct : niveau B-Tree (0=feuille)   }
  MDF_HDR_FLAGBITS   = 4;      { 2 oct : drapeaux de page            }
  MDF_HDR_INDEXID    = 6;      { 2 oct : ID index (deprecated)       }
  MDF_HDR_PREVPAGE   = 8;      { 4 oct : page precedente (PageID)    }
  MDF_HDR_PREVFILE   = 12;     { 2 oct : FileID page precedente      }
  MDF_HDR_PMINLEN    = 14;     { 2 oct : taille fixe min record      }
  MDF_HDR_NEXTPAGE   = 16;     { 4 oct : page suivante (PageID)      }
  MDF_HDR_NEXTFILE   = 20;     { 2 oct : FileID page suivante        }
  MDF_HDR_SLOTCNT    = 22;     { 2 oct : nombre de slots             }
  MDF_HDR_OBJID      = 24;     { 4 oct : Object ID (deprecated)      }
  MDF_HDR_FREECNT    = 28;     { 2 oct : octets libres               }
  MDF_HDR_FREEDATA   = 30;     { 2 oct : offset 1er octet libre      }
  MDF_HDR_RESERVEDCNT= 32;     { 2 oct : octets reserves             }

  { Taille max du nom de base dans la Boot Page }
  MDF_DBNAME_MAX     = 128;

  { ---- Constantes gestionnaire de pages (TODO 03) ------------ }
  MDF_PAGES_PER_EXTENT = 8;    { pages par extent                    }
  MDF_GAM_PAGE       = 2;      { premiere page GAM                   }
  MDF_SGAM_PAGE      = 3;      { premiere page SGAM                  }
  MDF_PFS_PAGE       = 1;      { premiere page PFS                   }
  MDF_GAM_INTERVAL   = 511232; { intervalle entre pages GAM          }
  MDF_PFS_INTERVAL   = 8088;   { intervalle entre pages PFS          }
  MDF_GAM_BITMAP_OFS = 96;     { debut du bitmap dans la page GAM    }
  MDF_GAM_BITMAP_SZ  = 8000;   { taille du bitmap GAM en octets      }
  MDF_GAM_MAX_EXTENTS= 64000;  { extents couverts par une page GAM   }
  MDF_PFS_DATA_OFS   = 96;     { debut des octets PFS dans la page   }
  MDF_PFS_COVERAGE   = 8088;   { pages couvertes par une page PFS    }

  { Offsets dans le corps de la page IAM (apres en-tete 96 oct.)  }
  MDF_IAM_SEQNUM     = 96;     { 4 oct. : sequenceNumber             }
  MDF_IAM_STATUS     = 100;    { 4 oct. : status                     }
  MDF_IAM_NEXTPG     = 104;    { 4+2 oct.: PageID + FileID du next   }
  MDF_IAM_STARTPG    = 110;    { 4+2 oct.: start_pg premier extent   }
  MDF_IAM_SLOTS      = 116;    { 8*6=48 oct.: pages mixtes initiales }
  MDF_IAM_BITMAP     = 148;    { 8000 oct.: bitmap d extents         }
  MDF_IAM_SLOT_COUNT = 8;      { nombre de slots de pages mixtes     }
  MDF_IAM_SLOT_SIZE  = 6;      { taille d un slot (PageID+FileID)    }

  { Masques PFS }
  MDF_PFS_FULLNESS   = $07;    { bits 0-2 : taux de remplissage      }
  MDF_PFS_GHOST      = $08;    { bit 3 : ghost records               }
  MDF_PFS_IAM_PG     = $10;    { bit 4 : page IAM                    }
  MDF_PFS_MIXED_EXT  = $20;    { bit 5 : extent mixte                }
  MDF_PFS_ALLOCATED  = $40;    { bit 6 : page allouee                }

  { ---- Constantes pages de donnees (TODO 04) ----------------- }
  MDF_SLOT_ENTRY_SIZE = 2;      { taille d un slot (2 octets)         }
  MDF_ROW_STATUSBITS  = 0;      { offset StatusBits A dans le row     }
  MDF_ROW_STATUSB     = 1;      { offset StatusBits B dans le row     }
  MDF_ROW_FIXEDLEN    = 2;      { offset taille fixe (2 oct.)         }

  { Masques StatusBits A }
  MDF_REC_TYPE_MASK   = $0E;    { bits 1-3 : type d enregistrement    }
  MDF_REC_HAS_NULL    = $10;    { bit 4 : bitmap NULL present         }
  MDF_REC_HAS_VAR     = $20;    { bit 5 : colonnes variables          }
  MDF_REC_HAS_VERSION = $40;    { bit 6 : versioning tag              }

  { Types d enregistrement (bits 1-3 de StatusBits A, decales) }
  MDF_RECTYPE_PRIMARY    = 0;   { enregistrement principal            }
  MDF_RECTYPE_FORWARDED  = 1;   { forwarded record                    }
  MDF_RECTYPE_FWDSTUB    = 2;   { forwarding stub                     }
  MDF_RECTYPE_INDEX      = 3;   { index record                        }
  MDF_RECTYPE_BLOB       = 4;   { blob fragment                       }
  MDF_RECTYPE_GHOST_IDX  = 5;   { ghost index record                  }
  MDF_RECTYPE_GHOST_DATA = 6;   { ghost data record                   }
  MDF_RECTYPE_GHOST_VER  = 7;   { ghost version record                }

  { Nombre maximum de slots par page }
  MDF_MAX_SLOTS      = 1000;    { max theorique de slots par page     }

  { ---- Constantes catalogue systeme (TODO 05) ---------------- }
  { Object IDs des tables systeme internes SQL Server }
  MDF_SYSOBJ_SYSSCHOBJS = 34;   { sys.sysschobjs - objets          }
  MDF_SYSOBJ_SYSCOLPARS = 41;   { sys.syscolpars - colonnes        }
  MDF_SYSOBJ_SYSIDXSTATS= 54;   { sys.sysidxstats - index          }
  MDF_SYSOBJ_SYSISCOLS  = 55;   { sys.sysiscols - colonnes index   }
  MDF_SYSOBJ_SYSROWSETS = 5;    { sys.sysrowsets - rowsets          }

  { Offsets partie fixe du row sysschobjs (apres StatusBits) }
  MDF_SCHOBJ_ID      = 4;       { object_id (4 oct. LongInt)       }
  MDF_SCHOBJ_NSID    = 8;       { schema namespace ID (4 oct.)     }
  MDF_SCHOBJ_NSCLASS = 12;      { namespace class (1 oct.)         }
  MDF_SCHOBJ_STATUS  = 13;      { status (4 oct.)                  }
  MDF_SCHOBJ_TYPE    = 17;      { type code (2 oct. char)          }
  MDF_SCHOBJ_PID     = 19;      { parent object_id (4 oct.)        }

  { Offsets partie fixe du row syscolpars }
  MDF_COLPAR_ID      = 4;       { parent object_id (4 oct.)        }
  MDF_COLPAR_NUMBER  = 8;       { parameter number (2 oct.)        }
  MDF_COLPAR_COLID   = 10;      { column_id (4 oct.)               }
  MDF_COLPAR_XTYPE   = 14;      { system type ID (1 oct.)          }
  MDF_COLPAR_UTYPE   = 15;      { user type (4 oct.)               }
  MDF_COLPAR_LENGTH  = 19;      { max length (2 oct.)              }
  MDF_COLPAR_PREC    = 21;      { precision (1 oct.)               }
  MDF_COLPAR_SCALE   = 22;      { scale (1 oct.)                   }
  MDF_COLPAR_COLLID  = 23;      { collation ID (4 oct.)            }
  MDF_COLPAR_STATUS  = 27;      { status bits (4 oct.)             }

  { Offsets partie fixe du row sysidxstats }
  MDF_IDXST_ID       = 4;       { object_id (4 oct.)               }
  MDF_IDXST_INDID    = 8;       { index_id (4 oct.)                }
  MDF_IDXST_STATUS   = 12;      { status (4 oct.)                  }
  MDF_IDXST_TYPE     = 20;      { index type (1 oct.)              }

  { Offsets partie fixe du row sysiscols }
  MDF_ISCOL_IDMAJOR  = 4;       { object_id (4 oct.)               }
  MDF_ISCOL_IDMINOR  = 8;       { index_id (4 oct.)                }
  MDF_ISCOL_SUBID    = 12;      { ordinal dans l index (4 oct.)    }
  MDF_ISCOL_STATUS   = 16;      { status (4 oct.)                  }
  MDF_ISCOL_INTPROP  = 20;      { column_id reference (4 oct.)     }

  { Offsets partie fixe du row sysrowsets }
  MDF_ROWSET_RSLO    = 4;       { rowset_id low (4 oct.)           }
  MDF_ROWSET_RSHI    = 8;       { rowset_id high (4 oct.)          }
  MDF_ROWSET_OWNERID = 12;      { owner HOBT (4 oct.)              }
  MDF_ROWSET_IDMAJOR = 16;      { object_id (4 oct.)               }
  MDF_ROWSET_IDMINOR = 20;      { index_id (4 oct.)                }

  { Taille max du nom dans les tables systeme }
  MAX_CATNAME = 60;

  { Taille max des tableaux catalogue }
  MAX_SYS_OBJECTS = {$IFDEF FPC}200{$ELSE}30{$ENDIF};
  MAX_SYS_COLUMNS = {$IFDEF FPC}500{$ELSE}60{$ENDIF};
  MAX_SYS_INDEXES = {$IFDEF FPC}200{$ELSE}30{$ENDIF};
  MAX_SYS_IDXCOLS = {$IFDEF FPC}500{$ELSE}60{$ENDIF};
  MAX_SYS_ROWSETS = {$IFDEF FPC}200{$ELSE}30{$ENDIF};

  { ---- Constantes types de donnees SQL Server (TODO 06) ------ }
  { xtype IDs des types systeme SQL Server                        }
  XT_IMAGE           = 34;     { IMAGE                             }
  XT_TEXT            = 35;     { TEXT                              }
  XT_UNIQUEID        = 36;     { UNIQUEIDENTIFIER (16 octets)      }
  XT_DATE            = 40;     { DATE (3 octets)                   }
  XT_TIME            = 41;     { TIME (3-5 octets selon scale)     }
  XT_DATETIME2       = 42;     { DATETIME2 (6-8 oct. selon scale)  }
  XT_DATETIMEOFFSET  = 43;     { DATETIMEOFFSET (8-10 oct.)        }
  XT_TINYINT         = 48;     { TINYINT (1 octet)                 }
  XT_SMALLINT        = 52;     { SMALLINT (2 octets)               }
  XT_INT             = 56;     { INT (4 octets)                    }
  XT_SMALLDATETIME   = 58;     { SMALLDATETIME (4 octets)          }
  XT_REAL            = 59;     { REAL (4 octets)                   }
  XT_MONEY           = 60;     { MONEY (8 octets)                  }
  XT_DATETIME        = 61;     { DATETIME (8 octets)               }
  XT_FLOAT           = 62;     { FLOAT (8 octets)                  }
  XT_SQL_VARIANT     = 98;     { SQL_VARIANT (variable)            }
  XT_NTEXT           = 99;     { NTEXT (variable LOB)              }
  XT_BIT             = 104;    { BIT (1 octet)                     }
  XT_DECIMAL         = 106;    { DECIMAL(p,s) (5-17 oct.)          }
  XT_NUMERIC         = 108;    { NUMERIC(p,s) (5-17 oct.)          }
  XT_SMALLMONEY      = 122;    { SMALLMONEY (4 octets)             }
  XT_BIGINT          = 127;    { BIGINT (8 octets)                 }
  XT_HIERARCHYID     = 128;    { HIERARCHYID (variable)            }
  XT_VARBINARY       = 165;    { VARBINARY(n) (variable)           }
  XT_VARCHAR         = 167;    { VARCHAR(n) (variable)             }
  XT_BINARY          = 173;    { BINARY(n) (fixe)                  }
  XT_CHAR            = 175;    { CHAR(n) (fixe)                    }
  XT_TIMESTAMP       = 189;    { TIMESTAMP/ROWVERSION (8 oct.)     }
  XT_NVARCHAR        = 231;    { NVARCHAR(n) (variable)            }
  XT_NCHAR           = 239;    { NCHAR(n) (fixe)                   }
  XT_CLR             = 240;    { CLR types (GEOGRAPHY,GEOMETRY)    }
  XT_XML             = 241;    { XML (variable LOB)                }

  { Categories de types de donnees }
  SQLCAT_UNKNOWN     = 0;      { type inconnu                      }
  SQLCAT_INTEGER     = 1;      { entiers : TINYINT..BIGINT, BIT    }
  SQLCAT_DECIMAL     = 2;      { decimaux : DECIMAL, NUMERIC,      }
                               {   FLOAT, REAL, MONEY, SMALLMONEY  }
  SQLCAT_STRING      = 3;      { chaines : CHAR, VARCHAR, NCHAR,   }
                               {   NVARCHAR, TEXT, NTEXT            }
  SQLCAT_DATETIME    = 4;      { date/heure : DATE, TIME,          }
                               {   DATETIME, DATETIME2, etc.       }
  SQLCAT_BINARY      = 5;      { binaires : BINARY, VARBINARY,     }
                               {   IMAGE, TIMESTAMP                }
  SQLCAT_SPECIAL     = 6;      { speciaux : UNIQUEIDENTIFIER, XML, }
                               {   SQL_VARIANT, CLR, HIERARCHYID   }

  { Taille max d une valeur SQL decodee en chaine }
  MAX_SQL_VALUE_STR = 120;

  { ---- Constantes tokeniseur SQL (TODO 07) -------------------- }
  { Types de tokens }
  TOK_EOF         = 0;       { fin de flux                        }
  TOK_IDENT       = 1;       { identificateur simple              }
  TOK_NUMBER      = 2;       { nombre entier                      }
  TOK_FLOAT       = 3;       { nombre flottant                    }
  TOK_STRING      = 4;       { chaine 'texte'                     }
  TOK_NSTRING     = 5;       { chaine Unicode N'texte'            }
  TOK_HEX         = 6;       { hexadecimal 0x1A2B                 }
  TOK_VARIABLE    = 7;       { variable @nom                      }
  TOK_TEMPOBJ     = 8;       { objet temporaire #nom              }
  TOK_PARAM       = 9;       { parametre ?                        }
  TOK_PLUS        = 10;      { +                                  }
  TOK_MINUS       = 11;      { -                                  }
  TOK_STAR        = 12;      { *                                  }
  TOK_SLASH       = 13;      { /                                  }
  TOK_PERCENT     = 14;      { %                                  }
  TOK_EQ          = 15;      { =                                  }
  TOK_NE          = 16;      { <> ou !=                           }
  TOK_LT          = 17;      { <                                  }
  TOK_GT          = 18;      { >                                  }
  TOK_LE          = 19;      { <=                                 }
  TOK_GE          = 20;      { >=                                 }
  TOK_LPAREN      = 21;      { (                                  }
  TOK_RPAREN      = 22;      { )                                  }
  TOK_COMMA       = 23;      { ,                                  }
  TOK_DOT         = 24;      { .                                  }
  TOK_SEMICOL     = 25;      { ;                                  }
  TOK_AT          = 26;      { @ (seul, sans suite)               }
  TOK_COLON       = 27;      { ::                                 }
  TOK_AMPERSAND   = 28;      { &                                  }
  TOK_PIPE        = 29;      { |                                  }
  TOK_CARET       = 30;      { ^                                  }
  TOK_TILDE       = 31;      { ~                                  }
  TOK_BANG_LT     = 32;      { !<                                 }
  TOK_BANG_GT     = 33;      { !>                                 }
  TOK_PLUS_EQ     = 34;      { +=                                 }
  TOK_MINUS_EQ    = 35;      { -=                                 }
  TOK_STAR_EQ     = 36;      { *=                                 }
  TOK_SLASH_EQ    = 37;      { /=                                 }
  TOK_PERCENT_EQ  = 38;      { %=                                 }
  TOK_AMP_EQ      = 39;      { &=                                 }
  TOK_PIPE_EQ     = 40;      { |=                                 }
  TOK_CARET_EQ    = 41;      { ^=                                 }
  TOK_DELIM_IDENT = 42;      { identificateur delimite [nom]      }
  TOK_KEYWORD     = 43;      { mot-cle SQL Server reconnu          }

  { Taille max du texte d un token }
  MAX_TOK_LEN     = 255;

  { ---- Constantes mots-cles SQL Server (TODO 08) -------------- }
  { Nombre total de mots-cles }
  MAX_KEYWORDS    = 110;

  { IDs des mots-cles SQL Server (base 1) }
  { -- DML -- }
  KW_SELECT       = 1;
  KW_INSERT       = 2;
  KW_UPDATE       = 3;
  KW_DELETE       = 4;
  KW_MERGE        = 5;
  KW_TRUNCATE     = 6;
  KW_BULK         = 7;
  { -- DDL -- }
  KW_CREATE       = 8;
  KW_ALTER        = 9;
  KW_DROP         = 10;
  KW_TABLE        = 11;
  KW_VIEW         = 12;
  KW_INDEX        = 13;
  KW_PROCEDURE    = 14;
  KW_FUNCTION     = 15;
  KW_TRIGGER      = 16;
  KW_DATABASE     = 17;
  KW_SCHEMA       = 18;
  KW_SEQUENCE     = 19;
  KW_TYPE         = 20;
  KW_SYNONYM      = 21;
  { -- Clauses -- }
  KW_FROM         = 22;
  KW_WHERE        = 23;
  KW_GROUP        = 24;
  KW_HAVING       = 25;
  KW_ORDER        = 26;
  KW_BY           = 27;
  KW_JOIN         = 28;
  KW_INNER        = 29;
  KW_LEFT         = 30;
  KW_RIGHT        = 31;
  KW_FULL         = 32;
  KW_OUTER        = 33;
  KW_CROSS        = 34;
  KW_ON           = 35;
  KW_AS           = 36;
  KW_INTO         = 37;
  KW_VALUES       = 38;
  KW_SET          = 39;
  KW_TOP          = 40;
  KW_DISTINCT     = 41;
  KW_ALL          = 42;
  KW_UNION        = 43;
  KW_INTERSECT    = 44;
  KW_EXCEPT       = 45;
  KW_WITH         = 46;
  KW_OVER         = 47;
  KW_PARTITION    = 48;
  KW_ROWS         = 49;
  KW_RANGE        = 50;
  KW_BETWEEN      = 51;
  KW_AND          = 52;
  KW_OR           = 53;
  KW_NOT          = 54;
  KW_IN           = 55;
  KW_EXISTS       = 56;
  KW_LIKE         = 57;
  KW_IS           = 58;
  KW_NULL         = 59;
  KW_CASE         = 60;
  KW_WHEN         = 61;
  KW_THEN         = 62;
  KW_ELSE         = 63;
  KW_END          = 64;
  KW_CAST         = 65;
  KW_CONVERT      = 66;
  KW_COLLATE      = 67;
  KW_PIVOT        = 68;
  KW_UNPIVOT      = 69;
  KW_APPLY        = 70;
  KW_OFFSET       = 71;
  KW_FETCH        = 72;
  KW_NEXT         = 73;
  KW_ONLY         = 74;
  KW_PERCENT      = 75;
  KW_TIES         = 76;
  { -- Controle -- }
  KW_BEGIN        = 77;
  KW_IF           = 78;
  KW_WHILE        = 79;
  KW_BREAK        = 80;
  KW_CONTINUE     = 81;
  KW_GOTO         = 82;
  KW_RETURN       = 83;
  KW_WAITFOR      = 84;
  KW_THROW        = 85;
  KW_TRY          = 86;
  KW_CATCH        = 87;
  KW_RAISERROR    = 88;
  KW_PRINT        = 89;
  KW_EXEC         = 90;
  KW_EXECUTE      = 91;
  KW_DECLARE      = 92;
  KW_USE          = 93;
  KW_GO           = 94;
  { -- Transaction -- }
  KW_COMMIT       = 95;
  KW_ROLLBACK     = 96;
  KW_SAVE         = 97;
  KW_TRANSACTION  = 98;
  { -- DCL -- }
  KW_GRANT        = 99;
  KW_REVOKE       = 100;
  KW_DENY         = 101;

  { -- Mots-cles supplementaires (TODO 11) -- }
  KW_OUTPUT       = 102;
  KW_USING        = 103;

  { -- DDL (TODO 12) -- }
  KW_COLUMN       = 104;
  KW_PRIMARY      = 105;
  KW_KEY          = 106;
  KW_FOREIGN      = 107;
  KW_REFERENCES   = 108;
  KW_UNIQUE       = 109;
  KW_CLUSTERED    = 110;
  KW_NONCLUSTERED = 111;
  KW_IDENTITY     = 112;
  KW_CHECK        = 113;
  KW_CONSTRAINT   = 114;
  KW_DEFAULT      = 115;
  KW_ADD          = 116;
  KW_INCLUDE      = 117;
  KW_REBUILD      = 118;
  KW_REORGANIZE   = 119;
  KW_DISABLE      = 120;
  KW_ENABLE       = 121;
  KW_SCHEMABINDING = 122;
  KW_AFTER        = 123;
  KW_INSTEAD      = 124;
  KW_FOR          = 125;
  KW_RETURNS      = 126;
  KW_ASC          = 127;
  KW_DESC         = 128;
  KW_OF           = 129;
  KW_OPTION       = 130;
  KW_FILLFACTOR   = 131;
  KW_PAD_INDEX    = 132;
  KW_NORECOMPUTE  = 133;
  KW_NO           = 134;
  KW_LOGIN        = 135;
  KW_USER         = 136;
  KW_ROLE         = 137;
  KW_MEMBER       = 138;

  { -- Controle T-SQL (TODO 13) -- }
  KW_DELAY        = 139;
  KW_TIME         = 140;

  { -- DCL (TODO 14) -- }
  KW_TO           = 141;
  KW_CONTROL      = 142;
  KW_DEFINITION   = 143;
  KW_TAKE         = 144;
  KW_OWNERSHIP    = 145;
  KW_PUBLIC       = 146;

  { -- Window Functions (TODO 18) -- }
  KW_UNBOUNDED    = 147;
  KW_PRECEDING    = 148;
  KW_FOLLOWING    = 149;
  KW_CURRENT_ROW  = 150;

  KW_COUNT        = 150;     { nombre total de mots-cles definis  }

  { ---- Constantes AST noeud parseur SQL (TODO 09) ------------- }
  { Types de noeuds dans l arbre d expression }
  ND_NONE         = 0;       { noeud vide / invalide                }
  ND_INT_LIT      = 1;       { litteral entier : 42                 }
  ND_FLOAT_LIT    = 2;       { litteral flottant : 3.14             }
  ND_STR_LIT      = 3;       { litteral chaine : 'texte'            }
  ND_NSTR_LIT     = 4;       { litteral Unicode : N'texte'          }
  ND_HEX_LIT      = 5;       { litteral hexa : 0x1A2B               }
  ND_NULL_LIT     = 6;       { NULL                                 }
  ND_DEFAULT_LIT  = 7;       { DEFAULT                              }
  ND_VARIABLE     = 8;       { @variable ou @@variable              }
  ND_IDENT        = 9;       { identificateur simple (colonne)      }
  ND_DELIM_IDENT  = 10;      { identificateur delimite [nom]        }
  ND_STAR         = 11;      { *  (dans SELECT *)                   }
  ND_PARAM        = 12;      { parametre ?                          }
  ND_BINOP        = 13;      { operation binaire (+,-,*,/,%,&,|,^)  }
  ND_UNARY        = 14;      { operation unaire (+,-,~,NOT)          }
  ND_COMPARE      = 15;      { comparaison (=,<>,<,>,<=,>=,!=,!<,!>)}
  ND_AND          = 16;      { AND logique                          }
  ND_OR           = 17;      { OR logique                           }
  ND_NOT          = 18;      { NOT logique                          }
  ND_BETWEEN      = 19;      { expr BETWEEN lo AND hi               }
  ND_IN           = 20;      { expr IN (liste)                      }
  ND_LIKE         = 21;      { expr LIKE pattern                    }
  ND_IS_NULL      = 22;      { expr IS NULL                         }
  ND_IS_NOT_NULL  = 23;      { expr IS NOT NULL                     }
  ND_EXISTS       = 24;      { EXISTS (sous-requete)                }
  ND_FUNC_CALL    = 25;      { fonction(args...)                    }
  ND_CASE_WHEN    = 26;      { CASE WHEN c THEN r [ELSE e] END     }
  ND_CASE_EXPR    = 27;      { CASE expr WHEN v THEN r [ELSE e] END}
  ND_CAST         = 28;      { CAST(expr AS type)                   }
  ND_CONVERT      = 29;      { CONVERT(type, expr [,style])         }
  ND_COLLATE      = 30;      { expr COLLATE collation_name          }
  ND_SUBQUERY     = 31;      { (SELECT ...) sous-requete scalaire   }
  ND_WHEN_ITEM    = 32;      { paire WHEN/THEN dans un CASE         }
  ND_ARG_LIST     = 33;      { liste d arguments (IN, fonctions)    }
  ND_DOT_REF      = 34;      { reference pointee (a.b.c)            }
  ND_TYPE_REF     = 35;      { reference de type pour CAST/CONVERT  }

  { ---- Constantes AST noeud parseur SELECT (TODO 10) ----------- }
  ND_SELECT_STMT  = 36;      { requete SELECT complete              }
  ND_SELECT_ITEM  = 37;      { item de la liste SELECT (expr AS al) }
  ND_FROM_CLAUSE  = 38;      { clause FROM                          }
  ND_TABLE_REF    = 39;      { reference de table (nom [AS alias])  }
  ND_JOIN         = 40;      { jointure (type, table, ON condition) }
  ND_WHERE_CLAUSE = 41;      { clause WHERE                         }
  ND_GROUP_BY     = 42;      { clause GROUP BY                      }
  ND_HAVING       = 43;      { clause HAVING                        }
  ND_ORDER_BY     = 44;      { clause ORDER BY                      }
  ND_ORDER_ITEM   = 45;      { item ORDER BY (expr ASC|DESC)        }
  ND_TOP_CLAUSE   = 46;      { TOP n [PERCENT] [WITH TIES]          }
  ND_OFFSET       = 47;      { OFFSET n ROWS FETCH NEXT m ROWS ONLY }
  ND_UNION        = 48;      { UNION [ALL]                          }
  ND_INTERSECT_OP = 49;      { INTERSECT                            }
  ND_EXCEPT_OP    = 50;      { EXCEPT                               }
  ND_CTE          = 51;      { WITH cte AS (SELECT ...)             }
  ND_SELECT_INTO  = 52;      { SELECT INTO table                    }
  ND_TABLE_HINT   = 53;      { WITH (NOLOCK|...)                    }
  ND_APPLY        = 54;      { CROSS/OUTER APPLY                    }
  ND_FOR_XML      = 55;      { FOR XML PATH|RAW|AUTO|EXPLICIT       }
  ND_FOR_JSON     = 56;      { FOR JSON PATH|AUTO                   }
  ND_ALIAS        = 57;      { alias de colonne ou table             }

  { ---- Constantes AST noeud parseur DML (TODO 11) -------------- }
  ND_INSERT_STMT  = 58;      { INSERT [INTO] table ...              }
  ND_COL_LIST     = 59;      { liste de colonnes (col1, col2, ...)  }
  ND_VALUES_CLAUSE= 60;      { VALUES (v1,...) [,(v1,...)]           }
  ND_VALUES_ROW   = 61;      { une rangee de valeurs (v1, v2, ...)  }
  ND_UPDATE_STMT  = 62;      { UPDATE table SET ...                 }
  ND_SET_CLAUSE   = 63;      { SET col=expr, col=expr, ...          }
  ND_SET_ITEM     = 64;      { col = expr                           }
  ND_DELETE_STMT  = 65;      { DELETE [FROM] table [WHERE ...]      }
  ND_TRUNCATE_STMT= 66;      { TRUNCATE TABLE table                 }
  ND_MERGE_STMT   = 67;      { MERGE INTO target USING source ON ...}
  ND_MERGE_WHEN   = 68;      { WHEN MATCHED/NOT MATCHED THEN ...    }
  ND_OUTPUT_CLAUSE= 69;      { OUTPUT INSERTED.*, DELETED.*         }
  ND_OUTPUT_ITEM  = 70;      { item dans la clause OUTPUT            }
  ND_DEFAULT_VALUES = 71;    { DEFAULT VALUES                       }
  ND_EXEC_INSERT  = 72;      { INSERT ... EXEC procedure            }

  { -- DDL nodes (TODO 12) -- }
  ND_CREATE_TABLE = 73;      { CREATE TABLE                         }
  ND_COL_DEF      = 74;      { colonne dans CREATE TABLE            }
  ND_PK_CONSTRAINT = 75;     { PRIMARY KEY                          }
  ND_FK_CONSTRAINT = 76;     { FOREIGN KEY REFERENCES               }
  ND_UNIQUE_CONSTR = 77;     { UNIQUE                               }
  ND_CHECK_CONSTR  = 78;     { CHECK (expression)                   }
  ND_DEFAULT_CONSTR = 79;    { DEFAULT expression                   }
  ND_IDENTITY_SPEC = 80;     { IDENTITY(seed,increment)             }
  ND_TABLE_CONSTR  = 81;     { contrainte de table (niveau table)   }
  ND_CREATE_INDEX  = 82;     { CREATE INDEX                         }
  ND_INDEX_COL     = 83;     { colonne dans index (ASC/DESC)        }
  ND_INCLUDE_COLS  = 84;     { INCLUDE (colonnes)                   }
  ND_CREATE_VIEW   = 85;     { CREATE VIEW                          }
  ND_CREATE_PROC   = 86;     { CREATE PROCEDURE                     }
  ND_CREATE_FUNC   = 87;     { CREATE FUNCTION                      }
  ND_CREATE_TRIGGER = 88;    { CREATE TRIGGER                       }
  ND_CREATE_SCHEMA = 89;     { CREATE SCHEMA                        }
  ND_CREATE_SEQ    = 90;     { CREATE SEQUENCE                      }
  ND_CREATE_TYPE   = 91;     { CREATE TYPE                          }
  ND_CREATE_DB     = 92;     { CREATE DATABASE                      }
  ND_ALTER_TABLE   = 93;     { ALTER TABLE                          }
  ND_ALTER_INDEX   = 94;     { ALTER INDEX                          }
  ND_DROP_STMT     = 95;     { DROP TABLE/VIEW/INDEX/...            }
  ND_PARAM_DEF     = 96;     { @param type dans proc/func           }
  ND_BODY_BLOCK    = 97;     { BEGIN ... END bloc de corps          }
  ND_WITH_OPTION   = 98;     { WITH (option = value)                }

  { -- T-SQL control flow nodes (TODO 13) -- }
  ND_DECLARE_VAR   = 99;     { DECLARE @var type [= expr]           }
  ND_DECLARE_TABLE = 100;    { DECLARE @var TABLE (cols...)          }
  ND_SET_VAR       = 101;    { SET @var = expr                      }
  ND_SELECT_VAR    = 102;    { SELECT @var = expr                   }
  ND_IF_STMT       = 103;    { IF cond BEGIN...END [ELSE ...]       }
  ND_WHILE_STMT    = 104;    { WHILE cond BEGIN...END               }
  ND_BREAK_STMT    = 105;    { BREAK                                }
  ND_CONTINUE_STMT = 106;    { CONTINUE                             }
  ND_BLOCK_STMT    = 107;    { BEGIN ... END bloc autonome          }
  ND_GOTO_STMT     = 108;    { GOTO label                           }
  ND_LABEL_STMT    = 109;    { label:                               }
  ND_RETURN_STMT   = 110;    { RETURN [valeur]                      }
  ND_WAITFOR_STMT  = 111;    { WAITFOR DELAY/TIME 'hh:mm:ss'       }
  ND_TRY_CATCH     = 112;    { BEGIN TRY...END TRY BEGIN CATCH...   }
  ND_THROW_STMT    = 113;    { THROW [num, msg, state]              }
  ND_RAISERROR_STMT = 114;   { RAISERROR (msg, sev, state)          }
  ND_PRINT_STMT    = 115;    { PRINT expression                     }
  ND_EXEC_STMT     = 116;    { EXEC/EXECUTE procedure               }
  ND_EXEC_SQL      = 117;    { EXEC('sql dynamique')                }
  ND_USE_STMT      = 118;    { USE database                         }
  ND_GO_STMT       = 119;    { GO separateur de batch               }

  { -- DCL nodes (TODO 14) -- }
  ND_GRANT_STMT    = 120;    { GRANT permission ON obj TO principal }
  ND_REVOKE_STMT   = 121;    { REVOKE permission ON obj FROM princ  }
  ND_DENY_STMT     = 122;    { DENY permission ON obj TO principal  }
  ND_PERMISSION    = 123;    { permission node (SELECT, INSERT...)  }
  ND_PRINCIPAL     = 124;    { principal (user/role/login/public)    }
  ND_CREATE_LOGIN  = 125;    { CREATE LOGIN                         }
  ND_CREATE_USER   = 126;    { CREATE USER                          }
  ND_ALTER_LOGIN   = 127;    { ALTER LOGIN                          }
  ND_ALTER_USER    = 128;    { ALTER USER                           }
  ND_ALTER_ROLE    = 129;    { ALTER ROLE ... ADD MEMBER             }
  ND_DROP_LOGIN    = 130;    { DROP LOGIN                           }
  ND_DROP_USER     = 131;    { DROP USER                            }

  { -- Window Functions (TODO 18) -- }
  ND_OVER_CLAUSE   = 132;    { OVER (PARTITION BY... ORDER BY...)    }
  ND_PARTITION_BY  = 133;    { PARTITION BY colonnes                 }
  ND_WINDOW_FRAME  = 134;    { ROWS/RANGE BETWEEN ... AND ...        }
  ND_FRAME_BOUND   = 135;    { borne de cadre (UNBOUNDED PRECEDING)  }

  { Taille max du pool de noeuds AST }
  MAX_AST_NODES   = 1024;

  { Taille max des enfants par noeud }
  MAX_AST_CHILDREN = 16;

  { ---- Constantes du moteur d execution (TODO 15) -------------- }
  MAX_QE_COLS     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
                                   { colonnes max par result set    }
  MAX_QE_ROWS     = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
                                   { lignes max en memoire          }
  MAX_QE_COLWIDTH = 40;            { largeur max affichage colonne  }
  MAX_QE_PAGES    = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};
                                   { pages max par table scan       }

  { ---- Constantes du moteur de jointure (TODO 16) -------------- }
  MAX_QE_HASH     = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
                                   { taille table de hachage        }

  { ---- Constantes du moteur d agregation (TODO 17) ------------- }
  MAX_QE_GROUPS   = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};
                                   { groupes max pour GROUP BY      }

  { ---- Constantes du moteur de fenetre (TODO 18) --------------- }
  MAX_QE_PARTITIONS = {$IFDEF FPC}512{$ELSE}32{$ENDIF};
                                   { partitions max pour OVER       }

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Buffer d une page MDF --------------------------------- }
  TMdfPageBuf = Array[0..MDF_PAGE_SIZE - 1] Of Byte;

  { ---- En-tete de page MDF decode (96 octets) ---------------- }
  TMdfPageHeader = Record
    HeaderVer   : Byte;        { +0  : version (toujours 1)          }
    PageType    : Byte;        { +1  : type de page                  }
    TypeFlagBits: Byte;        { +2  : drapeaux de type              }
    Level       : Byte;        { +3  : niveau B-Tree                 }
    FlagBits    : Word;        { +4  : drapeaux de page              }
    IndexId     : Word;        { +6  : ID index                      }
    PrevPage    : LongInt;     { +8  : page precedente               }
    PrevFile    : Word;        { +12 : FileID page precedente        }
    PMinLen     : Word;        { +14 : taille fixe min               }
    NextPage    : LongInt;     { +16 : page suivante                 }
    NextFile    : Word;        { +20 : FileID page suivante          }
    SlotCnt     : Word;        { +22 : nombre de slots               }
    ObjId       : LongInt;     { +24 : Object ID                     }
    FreeCnt     : Word;        { +28 : octets libres                 }
    FreeData    : Word;        { +30 : offset 1er libre              }
    ReservedCnt : Word;        { +32 : octets reserves               }
  End;

  { ---- Informations de la Boot Page (page 9) ----------------- }
  TMdfBootInfo = Record
    DbName       : String[MDF_DBNAME_MAX]; { nom de la base          }
    DBID         : Word;       { Database ID                          }
    Status       : LongInt;    { status de la base                    }
    CompatLevel  : Word;       { niveau de compatibilite              }
    CreateDate   : LongInt;    { date de creation (raw)               }
    Valid        : Boolean;    { True si boot page lue avec succes    }
  End;

  { ---- Informations PFS decodees (TODO 03) -------------------- }
  TMdfPFSInfo = Record
    Fullness    : Byte;        { 0-4 : taux de remplissage           }
    HasGhost    : Boolean;     { bit 3 : ghost records presents       }
    IsIAM       : Boolean;     { bit 4 : page IAM                    }
    IsMixedExt  : Boolean;     { bit 5 : extent mixte                }
    IsAllocated : Boolean;     { bit 6 : page allouee                }
  End;

  { ---- Reference de page (PageID + FileID) -------------------- }
  TMdfPageRef = Record
    PageId      : LongInt;     { numero de page                       }
    FileId      : Word;        { ID du fichier                        }
  End;

  { ---- Page IAM decodee (TODO 03) ----------------------------- }
  TMdfIAMInfo = Record
    SeqNum      : LongInt;     { sequenceNumber                       }
    Status      : LongInt;     { status                               }
    NextPage    : TMdfPageRef; { page IAM suivante dans la chaine     }
    StartPg     : TMdfPageRef; { premier extent couvert               }
    SinglePages : Array[0..MDF_IAM_SLOT_COUNT - 1] Of TMdfPageRef;
                               { pages individuelles (extent mixte)   }
    Valid       : Boolean;     { True si page IAM lue avec succes     }
  End;

  { ---- Slot Array d une page de donnees (TODO 04) ------------- }
  TMdfSlotArray = Array[0..MDF_MAX_SLOTS - 1] Of Word;

  { ---- En-tete d enregistrement decode (TODO 04) -------------- }
  TMdfRowHeader = Record
    StatusA     : Byte;        { StatusBits A                         }
    StatusB     : Byte;        { StatusBits B                         }
    RecType     : Byte;        { type d enregistrement (bits 1-3)     }
    HasNullBmp  : Boolean;     { bit 4 : bitmap NULL present          }
    HasVarCols  : Boolean;     { bit 5 : colonnes variables           }
    HasVersion  : Boolean;     { bit 6 : versioning tag               }
    FixedLen    : Word;        { taille donnees fixes (incl. status)  }
    ColCount    : Word;        { nombre de colonnes                   }
    NullBmpSize : Word;        { taille du bitmap NULL en octets      }
    VarColCount : Word;        { nombre de colonnes variables         }
    RowSize     : Word;        { taille totale de l enregistrement    }
    Valid       : Boolean;     { True si decode avec succes           }
  End;

  { ---- Information d une page de donnees (TODO 04) ------------ }
  TMdfDataPageInfo = Record
    Header      : TMdfPageHeader; { en-tete de page                  }
    SlotCnt     : Word;        { nombre de slots                      }
    Slots       : TMdfSlotArray; { offsets des enregistrements        }
    Valid       : Boolean;     { True si page lue avec succes         }
  End;

  { ---- Nom catalogue systeme (TODO 05) ------------------------ }
  TCatName = String[MAX_CATNAME];

  { ---- Objet systeme (sys.sysschobjs) (TODO 05) -------------- }
  TSysObject = Record
    ObjectId  : LongInt;       { object_id                            }
    Name      : TCatName;      { nom de l objet                       }
    ObjType   : String[2];     { type (U,V,P,FN,TR,C,D,S,IT...)      }
    ParentId  : LongInt;       { parent object_id                     }
    SchemaId  : LongInt;       { schema namespace ID                  }
    Status    : LongInt;       { status                               }
    Valid     : Boolean;
  End;

  { ---- Colonne systeme (sys.syscolpars) (TODO 05) ------------- }
  TSysColumn = Record
    ObjectId  : LongInt;       { parent object_id                     }
    ColumnId  : LongInt;       { column_id                            }
    ColNum    : Word;          { numero de colonne                    }
    Name      : TCatName;      { nom de la colonne                    }
    XType     : Byte;          { system type ID                       }
    MaxLen    : Word;          { longueur maximale                    }
    Prec      : Byte;          { precision                            }
    Scale     : Byte;          { echelle                              }
    CollId    : LongInt;       { collation ID                         }
    Status    : LongInt;       { status bits                          }
    Nullable  : Boolean;       { True si nullable                     }
    Valid     : Boolean;
  End;

  { ---- Index systeme (sys.sysidxstats) (TODO 05) -------------- }
  TSysIndex = Record
    ObjectId  : LongInt;       { object_id                            }
    IndexId   : LongInt;       { index_id                             }
    Name      : TCatName;      { nom de l index                       }
    IdxType   : Byte;          { 0=heap, 1=clustered, 2=nonclust      }
    Status    : LongInt;       { status                               }
    Valid     : Boolean;
  End;

  { ---- Colonne d index (sys.sysiscols) (TODO 05) -------------- }
  TSysIdxCol = Record
    ObjectId  : LongInt;       { object_id                            }
    IndexId   : LongInt;       { index_id                             }
    SubId     : LongInt;       { ordinal dans l index                 }
    ColumnId  : LongInt;       { column_id reference                  }
    Status    : LongInt;       { status                               }
    Valid     : Boolean;
  End;

  { ---- Rowset (sys.sysrowsets) (TODO 05) ---------------------- }
  TSysRowSet = Record
    RowSetLo  : LongInt;       { rowset_id (partie basse)             }
    RowSetHi  : LongInt;       { rowset_id (partie haute)             }
    OwnerId   : LongInt;       { owner HOBT                           }
    ObjectId  : LongInt;       { object_id                            }
    IndexId   : LongInt;       { index_id                             }
    Valid     : Boolean;
  End;

  { ---- Chaine valeur SQL decodee (TODO 06) -------------------- }
  TSqlValueStr = String[MAX_SQL_VALUE_STR];

  { ---- Valeur SQL decodee (TODO 06) --------------------------- }
  { Represente une valeur extraite d un enregistrement MDF         }
  { apres decodage du type de donnees SQL Server.                  }
  TSqlValue = Record
    IsNull    : Boolean;       { True si la valeur est NULL            }
    Category  : Byte;          { SQLCAT_xxx                            }
    XType     : Byte;          { type systeme original                 }
    IntVal    : LongInt;       { valeur entiere (TINYINT..INT)         }
    HiVal     : LongInt;       { partie haute (BIGINT, MONEY)          }
    FloatVal  : Real;          { valeur flottante (FLOAT, REAL)        }
    StrVal    : TSqlValueStr;  { valeur chaine (CHAR, VARCHAR, etc.)   }
    BinLen    : Word;          { longueur donnees binaires             }
    Year      : Word;          { annee (pour DATE/DATETIME)            }
    Month     : Byte;          { mois                                  }
    Day       : Byte;          { jour                                  }
    Hour      : Byte;          { heure                                 }
    Minute    : Byte;          { minute                                }
    Second    : Byte;          { seconde                               }
    Frac      : LongInt;       { fractions de seconde                  }
    Scale     : Byte;          { echelle (pour TIME, DATETIME2)        }
    Prec      : Byte;          { precision (pour DECIMAL, NUMERIC)     }
    Sign      : Byte;          { signe (0=negatif, 1=positif)          }
    Valid     : Boolean;       { True si decode avec succes            }
  End;

  { ---- Token SQL (TODO 07) ------------------------------------ }
  TTokenText = String[MAX_TOK_LEN];

  TToken = Record
    Kind   : Byte;             { TOK_xxx                              }
    Text   : TTokenText;       { texte brut du token                  }
    Line   : Integer;          { numero de ligne (base 1)             }
    Col    : Integer;          { numero de colonne (base 1)           }
    KwId   : Integer;          { KW_xxx si Kind=TOK_KEYWORD, 0 sinon }
  End;

  { ---- Noeud AST expressions SQL (TODO 09) ------------------- }
  TASTNode = Record
    Kind     : Byte;           { ND_xxx                               }
    Text     : TTokenText;     { texte du token (litteral, ident, op) }
    Children : Array[0..MAX_AST_CHILDREN - 1] Of Integer;
                               { indices enfants dans ASTPool (-1=nil)}
    ChildCnt : Integer;        { nombre d enfants utilises            }
    Line     : Integer;        { ligne source (pour messages erreur)  }
    Col      : Integer;        { colonne source                       }
  End;

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

  { ---- Colonne d un result set (TODO 15) --------------------- }
  TQEColName = String[MAX_QE_COLWIDTH];

  TQEColumn = Record
    Name     : TQEColName;     { nom de la colonne                    }
    XType    : Byte;           { type systeme SQL Server               }
    MaxLen   : Word;           { longueur max                          }
    Prec     : Byte;           { precision                             }
    Scale    : Byte;           { echelle                               }
    ColIdx   : Integer;        { index dans SysColumns (source)        }
    Width    : Integer;        { largeur d affichage                   }
  End;

  { ---- Ligne d un result set (TODO 15) ----------------------- }
  TQERow = Record
    Vals     : Array[0..MAX_QE_COLS - 1] Of TSqlValue;
    ColCnt   : Integer;
  End;

  { ---- Result set complet (TODO 15) -------------------------- }
  TQEResultPtr = ^TQEResult;
  TQEResult = Record
    Cols     : Array[0..MAX_QE_COLS - 1] Of TQEColumn;
    ColCnt   : Integer;
    Rows     : Array[0..MAX_QE_ROWS - 1] Of TQERow;
    RowCnt   : Integer;
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
  { ---- MDF (TODO 02) ----------------------------------------- }
  MdfF       : File;           { fichier MDF ouvert en binaire       }
  MdfOpen    : Boolean;        { True si fichier MDF ouvert          }
  MdfPageCnt : LongInt;        { nombre total de pages dans le MDF   }
  PageBuf    : TMdfPageBuf;    { buffer de lecture d une page         }
  BootInfo   : TMdfBootInfo;   { infos extraites de la Boot Page     }
  { ---- Catalogue systeme (TODO 05) ----------------------------- }
  SysObjects  : Array[0..MAX_SYS_OBJECTS - 1] Of TSysObject;
  SysObjCount : Integer;
  SysColumns  : Array[0..MAX_SYS_COLUMNS - 1] Of TSysColumn;
  SysColCount : Integer;
  SysIndexes  : Array[0..MAX_SYS_INDEXES - 1] Of TSysIndex;
  SysIdxCount : Integer;
  SysIdxCols  : Array[0..MAX_SYS_IDXCOLS - 1] Of TSysIdxCol;
  SysIcCount  : Integer;
  SysRowSets  : Array[0..MAX_SYS_ROWSETS - 1] Of TSysRowSet;
  SysRsCount  : Integer;
  CatalogValid : Boolean;
  { ---- Lexer SQL (TODO 07) ------------------------------------- }
  LexSrc      : TString;        { source SQL en cours d analyse       }
  LexPos      : Integer;        { position courante dans LexSrc (1..) }
  LexLen      : Integer;        { longueur de LexSrc                  }
  LexLine     : Integer;        { ligne courante (base 1)             }
  LexCol      : Integer;        { colonne courante (base 1)           }
  LexCurTok   : TToken;         { dernier token lu                    }
  { ---- AST expressions SQL (TODO 09) --------------------------- }
  ASTPool     : Array[0..MAX_AST_NODES - 1] Of TASTNode;
  ASTCount    : Integer;         { nombre de noeuds alloues             }
  ParseOk     : Boolean;         { False si erreur de syntaxe           }
  { ---- Moteur d execution (TODO 15) ----------------------------- }
  QERes       : TQEResultPtr;    { result set courant (alloue New/Dispose) }

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

{ ============================================================
  TODO 02 - LECTURE DU FORMAT MDF (EN-TETE) [IMPLEMENTE]
  ============================================================ }

{ ---- Utilitaires de lecture Little-Endian -------------------- }

Function ReadWord(Const Buf : TMdfPageBuf; Ofs : Integer) : Word;
Begin
  ReadWord := Buf[Ofs] Or (Word(Buf[Ofs + 1]) Shl 8);
End;

Function ReadLong(Const Buf : TMdfPageBuf; Ofs : Integer) : LongInt;
Begin
  ReadLong := LongInt(Buf[Ofs])
           Or (LongInt(Buf[Ofs + 1]) Shl 8)
           Or (LongInt(Buf[Ofs + 2]) Shl 16)
           Or (LongInt(Buf[Ofs + 3]) Shl 24);
End;

{ ---- Decoder l en-tete de page (96 octets) ------------------- }

Procedure ParsePageHeader(Const Buf : TMdfPageBuf;
                          Var Hdr : TMdfPageHeader);
Begin
  Hdr.HeaderVer    := Buf[MDF_HDR_HEADERVER];
  Hdr.PageType     := Buf[MDF_HDR_TYPE];
  Hdr.TypeFlagBits := Buf[MDF_HDR_TYPEFLAG];
  Hdr.Level        := Buf[MDF_HDR_LEVEL];
  Hdr.FlagBits     := ReadWord(Buf, MDF_HDR_FLAGBITS);
  Hdr.IndexId      := ReadWord(Buf, MDF_HDR_INDEXID);
  Hdr.PrevPage     := ReadLong(Buf, MDF_HDR_PREVPAGE);
  Hdr.PrevFile     := ReadWord(Buf, MDF_HDR_PREVFILE);
  Hdr.PMinLen      := ReadWord(Buf, MDF_HDR_PMINLEN);
  Hdr.NextPage     := ReadLong(Buf, MDF_HDR_NEXTPAGE);
  Hdr.NextFile     := ReadWord(Buf, MDF_HDR_NEXTFILE);
  Hdr.SlotCnt      := ReadWord(Buf, MDF_HDR_SLOTCNT);
  Hdr.ObjId        := ReadLong(Buf, MDF_HDR_OBJID);
  Hdr.FreeCnt      := ReadWord(Buf, MDF_HDR_FREECNT);
  Hdr.FreeData     := ReadWord(Buf, MDF_HDR_FREEDATA);
  Hdr.ReservedCnt  := ReadWord(Buf, MDF_HDR_RESERVEDCNT);
End;

{ ---- Nom de type de page (pour affichage) -------------------- }

Function PageTypeName(PT : Byte) : TString;
Begin
  Case PT Of
    MDF_PT_DATA      : PageTypeName := 'Data';
    MDF_PT_INDEX     : PageTypeName := 'Index';
    MDF_PT_TEXTIMAGE : PageTypeName := 'Text/Image';
    MDF_PT_TEXTTREE  : PageTypeName := 'TextTree';
    MDF_PT_SORT      : PageTypeName := 'Sort';
    MDF_PT_GAM       : PageTypeName := 'GAM';
    MDF_PT_SGAM      : PageTypeName := 'SGAM';
    MDF_PT_IAM       : PageTypeName := 'IAM';
    MDF_PT_PFS       : PageTypeName := 'PFS';
    MDF_PT_BOOT      : PageTypeName := 'Boot';
    MDF_PT_FILEHDR   : PageTypeName := 'FileHeader';
    MDF_PT_DCM       : PageTypeName := 'DCM';
    MDF_PT_BCM       : PageTypeName := 'BCM';
  Else
    PageTypeName := 'Unknown(' + IntToStr(PT) + ')';
  End;
End;

{ ---- Lire une page par numero -------------------------------- }

Function ReadPage(PageNum : LongInt;
                  Var Buf : TMdfPageBuf) : Boolean;
Var
  BytesRead : {$IFDEF FPC}LongInt{$ELSE}Word{$ENDIF};
  TargetOfs : LongInt;
Begin
  ReadPage := False;
  If Not MdfOpen Then Exit;

  TargetOfs := PageNum * MDF_PAGE_SIZE;
  Seek(MdfF, TargetOfs);
  If IOResult <> 0 Then Exit;

  FillChar(Buf, SizeOf(Buf), 0);
  BlockRead(MdfF, Buf, MDF_PAGE_SIZE, BytesRead);
  If IOResult <> 0 Then Exit;

  ReadPage := (BytesRead = MDF_PAGE_SIZE);
End;

{ ---- Ouvrir le fichier MDF ----------------------------------- }

Procedure OpenMdfFile(Const FileName : TString);
Var
  Hdr     : TMdfPageHeader;
  FileSz  : LongInt;
Begin
  MdfOpen := False;

  Assign(MdfF, FileName);
  Reset(MdfF, 1);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier MDF: ' + FileName);
  MdfOpen := True;

  { Determiner la taille du fichier et le nombre de pages }
  FileSz := FileSize(MdfF);
  If IOResult <> 0 Then
    FatalError('impossible de lire la taille du fichier MDF');
  MdfPageCnt := FileSz Div MDF_PAGE_SIZE;

  If Opts.Verbose Then
  Begin
    WriteLn('  Taille fichier : ', FileSz, ' octets');
    WriteLn('  Nombre de pages: ', MdfPageCnt);
  End;

  { Verifier taille minimale : au moins 10 pages (0..9) pour
    contenir le File Header (0) et la Boot Page (9) }
  If MdfPageCnt < 10 Then
    FatalError('fichier MDF trop petit (' + IntToStr(MdfPageCnt) +
               ' pages, minimum 10)');

  { Lire la page 0 (File Header Page) et valider }
  If Not ReadPage(MDF_FILE_HDR_PAGE, PageBuf) Then
    FatalError('impossible de lire la page 0 (File Header)');

  ParsePageHeader(PageBuf, Hdr);

  If Hdr.PageType <> MDF_PT_FILEHDR Then
    FatalError('page 0 : type attendu ' +
               IntToStr(MDF_PT_FILEHDR) + ' (FileHeader), obtenu ' +
               IntToStr(Hdr.PageType) + ' (' +
               PageTypeName(Hdr.PageType) + ')');

  If Opts.Verbose Then
  Begin
    WriteLn('  Page 0 (File Header) :');
    WriteLn('    headerVer  = ', Hdr.HeaderVer);
    WriteLn('    type       = ', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType), ')');
    WriteLn('    flagBits   = $', IntToStr(Hdr.FlagBits));
    WriteLn('    slotCnt    = ', Hdr.SlotCnt);
    WriteLn('    objId      = ', Hdr.ObjId);
    WriteLn('    freeCnt    = ', Hdr.FreeCnt);
    WriteLn('    freeData   = ', Hdr.FreeData);
  End;
End;

{ ---- Extraire une chaine Unicode (UTF-16 LE) depuis le buf --- }

Function ExtractUnicodeStr(Const Buf : TMdfPageBuf;
                           Ofs, MaxChars : Integer) : TString;
Var
  I   : Integer;
  Lo  : Byte;
  S   : TString;
Begin
  S := '';
  For I := 0 To MaxChars - 1 Do
  Begin
    Lo := Buf[Ofs + I * 2];
    { Ignorer l octet haut (ASCII seulement) }
    If Lo = 0 Then Break;      { fin de chaine }
    If Length(S) < MAX_STR Then
      S := S + Chr(Lo);
  End;
  ExtractUnicodeStr := S;
End;

{ ---- Lire la Boot Page (page 9, type 13) --------------------- }

Procedure ReadBootPage;
Var
  Hdr : TMdfPageHeader;
Begin
  BootInfo.Valid := False;
  BootInfo.DbName := '';
  BootInfo.DBID := 0;
  BootInfo.Status := 0;
  BootInfo.CompatLevel := 0;
  BootInfo.CreateDate := 0;

  If Not MdfOpen Then Exit;

  If Not ReadPage(MDF_BOOT_PAGE, PageBuf) Then
  Begin
    WarnMsg('impossible de lire la page 9 (Boot Page)');
    Exit;
  End;

  ParsePageHeader(PageBuf, Hdr);

  If Hdr.PageType <> MDF_PT_BOOT Then
  Begin
    WarnMsg('page 9 : type attendu ' + IntToStr(MDF_PT_BOOT) +
            ' (Boot), obtenu ' + IntToStr(Hdr.PageType));
    Exit;
  End;

  { Le corps de la Boot Page commence a l offset 96.
    Les offsets ci-dessous sont des offsets typiques observes
    dans les fichiers MDF de SQL Server 2005+.

    Offset 96+0  : dbi_version (4 octets)
    Offset 96+4  : dbi_createVersion (4 octets)
    Offset 96+24 : dbi_status (4 octets)
    Offset 96+100: dbi_dbname (128 caracteres Unicode = 256 octets)
    Offset 96+356: dbi_dbid (2 octets)
    Offset 96+396: dbi_cmptlevel (2 octets)
  }

  { Version du moteur de stockage }
  { BootInfo.EngineVer := ReadLong(PageBuf, 96); }

  { Status de la base }
  BootInfo.Status := ReadLong(PageBuf, 96 + 24);

  { Nom de la base de donnees (Unicode UTF-16 LE) }
  BootInfo.DbName := ExtractUnicodeStr(PageBuf, 96 + 100,
                                        MDF_DBNAME_MAX);

  { Database ID }
  BootInfo.DBID := ReadWord(PageBuf, 96 + 356);

  { Niveau de compatibilite }
  BootInfo.CompatLevel := ReadWord(PageBuf, 96 + 396);

  BootInfo.Valid := True;

  If Opts.Verbose Then
  Begin
    WriteLn('  Page 9 (Boot Page) :');
    WriteLn('    type       = ', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType), ')');
    WriteLn('    slotCnt    = ', Hdr.SlotCnt);
    WriteLn('    dbName     = ', BootInfo.DbName);
    WriteLn('    dbId       = ', BootInfo.DBID);
    WriteLn('    status     = $', IntToStr(BootInfo.Status));
    WriteLn('    cmptLevel  = ', BootInfo.CompatLevel);
  End;
End;

{ ---- Fermer le fichier MDF ----------------------------------- }

Procedure CloseMdfFile;
Begin
  If MdfOpen Then
  Begin
    Close(MdfF);
    If IOResult <> 0 Then ; { ignorer les erreurs a la fermeture }
    MdfOpen := False;
  End;
End;

{ ============================================================
  TODO 03 - GESTIONNAIRE DE PAGES ET ALLOCATION MAP [IMPLEMENTE]
  ============================================================ }

{ ---- SeekPage : lire une page avec validation ---------------- }

Function SeekPage(PageNum : LongInt;
                  Var Buf : TMdfPageBuf) : Boolean;
Begin
  SeekPage := False;
  If Not MdfOpen Then Exit;
  If (PageNum < 0) Or (PageNum >= MdfPageCnt) Then Exit;
  SeekPage := ReadPage(PageNum, Buf);
End;

{ ---- Lire un bit du GAM pour un extent donne ----------------- }
{  GAM page = 2 + (Ext / 64000) * 511232                        }
{  Offset octet = 96 + (Ext mod 64000) / 8                      }
{  Bit = (Ext mod 64000) mod 8                                   }
{  Bit=1 => extent libre, Bit=0 => extent alloue                }

Function ReadGAMBit(ExtentNum : LongInt) : Integer;
Var
  GamPageNum : LongInt;
  LocalExt   : LongInt;
  ByteOfs    : Integer;
  BitPos     : Byte;
  TmpBuf     : TMdfPageBuf;
Begin
  ReadGAMBit := -1;
  GamPageNum := MDF_GAM_PAGE +
                (ExtentNum Div MDF_GAM_MAX_EXTENTS) * MDF_GAM_INTERVAL;
  If Not SeekPage(GamPageNum, TmpBuf) Then Exit;

  LocalExt := ExtentNum Mod MDF_GAM_MAX_EXTENTS;
  ByteOfs  := MDF_GAM_BITMAP_OFS + (LocalExt Div 8);
  BitPos   := LocalExt Mod 8;

  If (TmpBuf[ByteOfs] And (1 Shl BitPos)) <> 0 Then
    ReadGAMBit := 1
  Else
    ReadGAMBit := 0;
End;

{ ---- Lire un bit du SGAM pour un extent donne ---------------- }
{  SGAM page = 3 + (Ext / 64000) * 511232                       }
{  Bit=1 => extent mixte avec page(s) libre(s)                  }
{  Bit=0 => extent uniforme ou mixte plein ou non alloue         }

Function ReadSGAMBit(ExtentNum : LongInt) : Integer;
Var
  SgamPageNum : LongInt;
  LocalExt    : LongInt;
  ByteOfs     : Integer;
  BitPos      : Byte;
  TmpBuf      : TMdfPageBuf;
Begin
  ReadSGAMBit := -1;
  SgamPageNum := MDF_SGAM_PAGE +
                 (ExtentNum Div MDF_GAM_MAX_EXTENTS) * MDF_GAM_INTERVAL;
  If Not SeekPage(SgamPageNum, TmpBuf) Then Exit;

  LocalExt := ExtentNum Mod MDF_GAM_MAX_EXTENTS;
  ByteOfs  := MDF_GAM_BITMAP_OFS + (LocalExt Div 8);
  BitPos   := LocalExt Mod 8;

  If (TmpBuf[ByteOfs] And (1 Shl BitPos)) <> 0 Then
    ReadSGAMBit := 1
  Else
    ReadSGAMBit := 0;
End;

{ ---- Verifier si un extent est libre (GAM=1) ----------------- }

Function IsExtentFree(ExtentNum : LongInt) : Boolean;
Begin
  IsExtentFree := (ReadGAMBit(ExtentNum) = 1);
End;

{ ---- Verifier si un extent est alloue (GAM=0) ---------------- }

Function IsExtentAllocated(ExtentNum : LongInt) : Boolean;
Begin
  IsExtentAllocated := (ReadGAMBit(ExtentNum) = 0);
End;

{ ---- Verifier si un extent est mixte (GAM=0, SGAM=1) --------- }

Function IsExtentMixed(ExtentNum : LongInt) : Boolean;
Begin
  IsExtentMixed := (ReadGAMBit(ExtentNum) = 0) And
                   (ReadSGAMBit(ExtentNum) = 1);
End;

{ ---- Lire l octet PFS pour une page donnee ------------------- }
{  PFS page = 1 + (PageNum / 8088) * 8088                       }
{  Offset   = 96 + (PageNum mod 8088)                            }

Function ReadPFSByte(PageNum : LongInt) : Integer;
Var
  PfsPageNum : LongInt;
  LocalPage  : LongInt;
  ByteOfs    : Integer;
  TmpBuf     : TMdfPageBuf;
Begin
  ReadPFSByte := -1;
  PfsPageNum := MDF_PFS_PAGE +
                (PageNum Div MDF_PFS_COVERAGE) * MDF_PFS_COVERAGE;
  If Not SeekPage(PfsPageNum, TmpBuf) Then Exit;

  LocalPage := PageNum Mod MDF_PFS_COVERAGE;
  ByteOfs   := MDF_PFS_DATA_OFS + LocalPage;

  If ByteOfs >= MDF_PAGE_SIZE Then Exit;
  ReadPFSByte := TmpBuf[ByteOfs];
End;

{ ---- Decoder un octet PFS en informations lisibles ----------- }

Procedure DecodePFS(PfsByte : Byte; Var Info : TMdfPFSInfo);
Begin
  Info.Fullness    := PfsByte And MDF_PFS_FULLNESS;
  Info.HasGhost    := (PfsByte And MDF_PFS_GHOST) <> 0;
  Info.IsIAM       := (PfsByte And MDF_PFS_IAM_PG) <> 0;
  Info.IsMixedExt  := (PfsByte And MDF_PFS_MIXED_EXT) <> 0;
  Info.IsAllocated := (PfsByte And MDF_PFS_ALLOCATED) <> 0;
End;

{ ---- Texte du taux de remplissage PFS ------------------------ }

Function PFSFullnessStr(F : Byte) : TString;
Begin
  Case F Of
    0 : PFSFullnessStr := 'vide (0%)';
    1 : PFSFullnessStr := '1-50%';
    2 : PFSFullnessStr := '51-80%';
    3 : PFSFullnessStr := '81-95%';
    4 : PFSFullnessStr := '96-100%';
  Else
    PFSFullnessStr := '?(' + IntToStr(F) + ')';
  End;
End;

{ ---- Decoder une page IAM ------------------------------------ }

Procedure ParseIAMPage(Const Buf : TMdfPageBuf;
                       Var IAM : TMdfIAMInfo);
Var
  I, Ofs : Integer;
  Hdr    : TMdfPageHeader;
Begin
  IAM.Valid := False;
  ParsePageHeader(Buf, Hdr);

  If Hdr.PageType <> MDF_PT_IAM Then Exit;

  IAM.SeqNum     := ReadLong(Buf, MDF_IAM_SEQNUM);
  IAM.Status     := ReadLong(Buf, MDF_IAM_STATUS);
  IAM.NextPage.PageId := ReadLong(Buf, MDF_IAM_NEXTPG);
  IAM.NextPage.FileId := ReadWord(Buf, MDF_IAM_NEXTPG + 4);
  IAM.StartPg.PageId  := ReadLong(Buf, MDF_IAM_STARTPG);
  IAM.StartPg.FileId  := ReadWord(Buf, MDF_IAM_STARTPG + 4);

  For I := 0 To MDF_IAM_SLOT_COUNT - 1 Do
  Begin
    Ofs := MDF_IAM_SLOTS + I * MDF_IAM_SLOT_SIZE;
    IAM.SinglePages[I].PageId := ReadLong(Buf, Ofs);
    IAM.SinglePages[I].FileId := ReadWord(Buf, Ofs + 4);
  End;

  IAM.Valid := True;
End;

{ ---- Tester si un extent est alloue dans le bitmap IAM ------- }

Function IAMBitmapBit(Const Buf : TMdfPageBuf;
                      ExtentIndex : LongInt) : Boolean;
Var
  ByteOfs : Integer;
  BitPos  : Byte;
Begin
  IAMBitmapBit := False;
  If (ExtentIndex < 0) Or (ExtentIndex >= MDF_GAM_MAX_EXTENTS) Then
    Exit;
  ByteOfs := MDF_IAM_BITMAP + (ExtentIndex Div 8);
  BitPos  := ExtentIndex Mod 8;
  If ByteOfs >= MDF_PAGE_SIZE Then Exit;
  IAMBitmapBit := (Buf[ByteOfs] And (1 Shl BitPos)) <> 0;
End;

{ ---- Suivre la chaine IAM depuis une page IAM donnee --------- }
{  Appelle une callback conceptuelle (ici : affichage verbose)   }
{  Retourne le nombre d extents trouves pour l objet             }

Function FollowIAMChain(FirstIAMPage : LongInt) : LongInt;
Var
  IAM       : TMdfIAMInfo;
  TmpBuf    : TMdfPageBuf;
  CurrPage  : LongInt;
  Count     : LongInt;
  ExtIdx    : LongInt;
  I         : Integer;
  MaxIter   : Integer;
Begin
  FollowIAMChain := 0;
  Count := 0;
  CurrPage := FirstIAMPage;
  MaxIter := 100;  { protection contre boucle infinie }

  While (CurrPage > 0) And (MaxIter > 0) Do
  Begin
    Dec(MaxIter);
    If Not SeekPage(CurrPage, TmpBuf) Then Break;

    ParseIAMPage(TmpBuf, IAM);
    If Not IAM.Valid Then Break;

    If Opts.Verbose Then
    Begin
      WriteLn('    IAM page ', CurrPage, ' :');
      WriteLn('      seqNum   = ', IAM.SeqNum);
      WriteLn('      startPg  = ', IAM.StartPg.FileId,
              ':', IAM.StartPg.PageId);
      WriteLn('      nextPage = ', IAM.NextPage.FileId,
              ':', IAM.NextPage.PageId);
    End;

    { Compter les pages individuelles (slots mixtes) }
    For I := 0 To MDF_IAM_SLOT_COUNT - 1 Do
    Begin
      If IAM.SinglePages[I].PageId <> 0 Then
      Begin
        Inc(Count);
        If Opts.Verbose Then
          WriteLn('      slot[', I, '] = ',
                  IAM.SinglePages[I].FileId, ':',
                  IAM.SinglePages[I].PageId);
      End;
    End;

    { Compter les extents dans le bitmap }
    For ExtIdx := 0 To MDF_GAM_MAX_EXTENTS - 1 Do
    Begin
      If IAMBitmapBit(TmpBuf, ExtIdx) Then
        Inc(Count, MDF_PAGES_PER_EXTENT);
    End;

    { Suivre la chaine }
    If IAM.NextPage.PageId > 0 Then
      CurrPage := IAM.NextPage.PageId
    Else
      CurrPage := 0;
  End;

  FollowIAMChain := Count;
End;

{ ---- Afficher les informations d une page (mode verbose) ----- }

Procedure DumpPageInfo(PageNum : LongInt);
Var
  Hdr     : TMdfPageHeader;
  TmpBuf  : TMdfPageBuf;
  PfsByte : Integer;
  PfsInfo : TMdfPFSInfo;
  ExtNum  : LongInt;
  GamBit  : Integer;
  SgamBit : Integer;
Begin
  If Not SeekPage(PageNum, TmpBuf) Then
  Begin
    WriteLn('  Page ', PageNum, ' : impossible a lire');
    Exit;
  End;

  ParsePageHeader(TmpBuf, Hdr);
  ExtNum  := PageNum Div MDF_PAGES_PER_EXTENT;
  GamBit  := ReadGAMBit(ExtNum);
  SgamBit := ReadSGAMBit(ExtNum);
  PfsByte := ReadPFSByte(PageNum);

  WriteLn('  Page ', PageNum, ' :');
  WriteLn('    type       = ', Hdr.PageType,
          ' (', PageTypeName(Hdr.PageType), ')');
  WriteLn('    level      = ', Hdr.Level);
  WriteLn('    flagBits   = $', IntToStr(Hdr.FlagBits));
  WriteLn('    slotCnt    = ', Hdr.SlotCnt);
  WriteLn('    objId      = ', Hdr.ObjId);
  WriteLn('    prevPage   = ', Hdr.PrevFile, ':', Hdr.PrevPage);
  WriteLn('    nextPage   = ', Hdr.NextFile, ':', Hdr.NextPage);
  WriteLn('    freeCnt    = ', Hdr.FreeCnt);
  WriteLn('    freeData   = ', Hdr.FreeData);
  WriteLn('    extent     = ', ExtNum);

  If GamBit >= 0 Then
  Begin
    Write('    GAM        = ', GamBit);
    If GamBit = 1 Then WriteLn(' (libre)')
    Else WriteLn(' (alloue)');
  End;
  If SgamBit >= 0 Then
  Begin
    Write('    SGAM       = ', SgamBit);
    If SgamBit = 1 Then WriteLn(' (mixte, pages libres)')
    Else WriteLn(' (uniforme/plein)');
  End;

  If PfsByte >= 0 Then
  Begin
    DecodePFS(Byte(PfsByte), PfsInfo);
    WriteLn('    PFS        = $', IntToStr(PfsByte));
    WriteLn('      fullness   = ', PfsInfo.Fullness,
            ' (', PFSFullnessStr(PfsInfo.Fullness), ')');
    WriteLn('      allocated  = ', PfsInfo.IsAllocated);
    WriteLn('      mixedExt   = ', PfsInfo.IsMixedExt);
    WriteLn('      isIAM      = ', PfsInfo.IsIAM);
    WriteLn('      hasGhost   = ', PfsInfo.HasGhost);
  End;
End;

{ ---- Lire et afficher les allocation maps (mode verbose) ------ }

Procedure ReadAllocationMaps;
Var
  TmpBuf  : TMdfPageBuf;
  Hdr     : TMdfPageHeader;
  NumExt  : LongInt;
  AllocCnt: LongInt;
  FreeCnt : LongInt;
  MixedCnt: LongInt;
  I       : LongInt;
  G, S    : Integer;
  PByte   : Integer;
  PfsInfo : TMdfPFSInfo;
  AllocPg : LongInt;
Begin
  If Not MdfOpen Then Exit;

  NumExt := MdfPageCnt Div MDF_PAGES_PER_EXTENT;

  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('  Allocation Maps (TODO 03) :');
    WriteLn('    Nombre total d''extents : ', NumExt);
  End;

  { Verifier que la page GAM (2) et SGAM (3) existent }
  If Not SeekPage(MDF_GAM_PAGE, TmpBuf) Then
  Begin
    WarnMsg('impossible de lire la page GAM (page 2)');
    Exit;
  End;
  ParsePageHeader(TmpBuf, Hdr);
  If Opts.Verbose Then
    WriteLn('    Page 2 (GAM)  : type=', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType), ')');

  If Not SeekPage(MDF_SGAM_PAGE, TmpBuf) Then
  Begin
    WarnMsg('impossible de lire la page SGAM (page 3)');
    Exit;
  End;
  ParsePageHeader(TmpBuf, Hdr);
  If Opts.Verbose Then
    WriteLn('    Page 3 (SGAM) : type=', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType), ')');

  { Scanner les extents avec GAM et SGAM }
  AllocCnt := 0;
  FreeCnt  := 0;
  MixedCnt := 0;

  For I := 0 To NumExt - 1 Do
  Begin
    G := ReadGAMBit(I);
    S := ReadSGAMBit(I);
    If G = 1 Then
      Inc(FreeCnt)
    Else
    Begin
      Inc(AllocCnt);
      If S = 1 Then
        Inc(MixedCnt);
    End;
  End;

  If Opts.Verbose Then
  Begin
    WriteLn('    Extents alloues : ', AllocCnt);
    WriteLn('    Extents libres  : ', FreeCnt);
    WriteLn('    Extents mixtes  : ', MixedCnt);
  End;

  { Scanner la page PFS pour les pages allouees }
  If Opts.Verbose Then
  Begin
    If Not SeekPage(MDF_PFS_PAGE, TmpBuf) Then
    Begin
      WarnMsg('impossible de lire la page PFS (page 1)');
      Exit;
    End;
    ParsePageHeader(TmpBuf, Hdr);
    WriteLn('    Page 1 (PFS)  : type=', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType), ')');

    AllocPg := 0;
    For I := 0 To MdfPageCnt - 1 Do
    Begin
      PByte := ReadPFSByte(I);
      If PByte >= 0 Then
      Begin
        DecodePFS(Byte(PByte), PfsInfo);
        If PfsInfo.IsAllocated Then
          Inc(AllocPg);
      End;
    End;
    WriteLn('    Pages allouees (PFS) : ', AllocPg, ' / ', MdfPageCnt);
  End;
End;

{ ============================================================
  TODO 04 - LECTURE DES PAGES DE DONNEES (DATA PAGES) [IMPLEMENTE]
  ============================================================ }

{ ---- Conversion d un octet en hexadecimal -------------------- }

Function ByteToHex(B : Byte) : TString;
Const
  HexDigits : Array[0..15] Of Char = '0123456789ABCDEF';
Begin
  ByteToHex := HexDigits[B Shr 4] + HexDigits[B And $0F];
End;

{ ---- Nom du type d enregistrement (StatusBits A bits 1-3) ---- }

Function RecTypeName(RT : Byte) : TString;
Begin
  Case RT Of
    MDF_RECTYPE_PRIMARY    : RecTypeName := 'Primary';
    MDF_RECTYPE_FORWARDED  : RecTypeName := 'Forwarded';
    MDF_RECTYPE_FWDSTUB    : RecTypeName := 'FwdStub';
    MDF_RECTYPE_INDEX      : RecTypeName := 'Index';
    MDF_RECTYPE_BLOB       : RecTypeName := 'Blob';
    MDF_RECTYPE_GHOST_IDX  : RecTypeName := 'GhostIdx';
    MDF_RECTYPE_GHOST_DATA : RecTypeName := 'GhostData';
    MDF_RECTYPE_GHOST_VER  : RecTypeName := 'GhostVer';
  Else
    RecTypeName := 'Unknown(' + IntToStr(RT) + ')';
  End;
End;

{ ---- Lire le slot array d une page de donnees ---------------- }
{ Le slot array est situe en fin de page, croissant vers le      }
{ debut. Slot[0] est a offset PageSize-2, Slot[1] a PageSize-4. }
{ Chaque entree est un Word (2 octets, Little Endian) indiquant  }
{ l offset du debut de l enregistrement dans la page.            }

Procedure ReadSlotArray(Const Buf : TMdfPageBuf;
                        SlotCnt : Word;
                        Var Slots : TMdfSlotArray);
Var
  I   : Integer;
  Ofs : Integer;
  SC  : Word;
Begin
  FillChar(Slots, SizeOf(Slots), 0);
  SC := SlotCnt;
  If SC > MDF_MAX_SLOTS Then
    SC := MDF_MAX_SLOTS;
  For I := 0 To SC - 1 Do
  Begin
    Ofs := MDF_PAGE_SIZE - MDF_SLOT_ENTRY_SIZE * (I + 1);
    If (Ofs >= MDF_PAGE_HDR_SIZE) And (Ofs + 1 < MDF_PAGE_SIZE) Then
      Slots[I] := ReadWord(Buf, Ofs)
    Else
      Slots[I] := 0;
  End;
End;

{ ---- Decoder l en-tete d un enregistrement -------------------- }
{ Lit les StatusBits, la taille fixe, le nombre de colonnes,     }
{ le bitmap NULL, et les informations sur les colonnes variables. }

Procedure ParseRowHeader(Const Buf : TMdfPageBuf;
                          RowOfs : Word;
                          Var RH : TMdfRowHeader);
Var
  NullBmpOfs : Word;
  VarOfs     : Word;
  LastVarEnd : Word;
Begin
  RH.Valid       := False;
  RH.StatusA     := 0;
  RH.StatusB     := 0;
  RH.RecType     := 0;
  RH.HasNullBmp  := False;
  RH.HasVarCols  := False;
  RH.HasVersion  := False;
  RH.FixedLen    := 0;
  RH.ColCount    := 0;
  RH.NullBmpSize := 0;
  RH.VarColCount := 0;
  RH.RowSize     := 0;

  { Verifier les limites minimales : 4 octets min }
  If RowOfs + 4 > MDF_PAGE_SIZE Then Exit;

  { StatusBits A et B }
  RH.StatusA := Buf[RowOfs + MDF_ROW_STATUSBITS];
  RH.StatusB := Buf[RowOfs + MDF_ROW_STATUSB];

  { Type d enregistrement (bits 1-3 de StatusA, decales a droite) }
  RH.RecType := (RH.StatusA And MDF_REC_TYPE_MASK) Shr 1;

  { Drapeaux de l enregistrement }
  RH.HasNullBmp := (RH.StatusA And MDF_REC_HAS_NULL) <> 0;
  RH.HasVarCols := (RH.StatusA And MDF_REC_HAS_VAR) <> 0;
  RH.HasVersion := (RH.StatusA And MDF_REC_HAS_VERSION) <> 0;

  { Taille des donnees fixes (offset de fin de zone fixe) }
  RH.FixedLen := ReadWord(Buf, RowOfs + MDF_ROW_FIXEDLEN);

  { Validation : FixedLen minimum = 4 (status + fixedlen) }
  If RH.FixedLen < 4 Then
    RH.FixedLen := 4;
  If RowOfs + RH.FixedLen > MDF_PAGE_SIZE Then Exit;

  { Apres les donnees fixes : nombre de colonnes (2 octets) }
  NullBmpOfs := RowOfs + RH.FixedLen;
  If NullBmpOfs + 2 > MDF_PAGE_SIZE Then
  Begin
    RH.RowSize := RH.FixedLen;
    RH.Valid := True;
    Exit;
  End;

  RH.ColCount := ReadWord(Buf, NullBmpOfs);

  { Bitmap NULL : ceil(ColCount / 8) octets }
  If RH.HasNullBmp And (RH.ColCount > 0) Then
    RH.NullBmpSize := (RH.ColCount + 7) Div 8
  Else
    RH.NullBmpSize := 0;

  { Taille de base : fixe + colcount(2) + null bitmap }
  RH.RowSize := RH.FixedLen + 2 + RH.NullBmpSize;

  { Colonnes a longueur variable }
  If RH.HasVarCols Then
  Begin
    VarOfs := NullBmpOfs + 2 + RH.NullBmpSize;
    If VarOfs + 2 <= MDF_PAGE_SIZE Then
    Begin
      RH.VarColCount := ReadWord(Buf, VarOfs);
      { Ajouter 2 octets pour le compteur de colonnes variables }
      RH.RowSize := RH.FixedLen + 2 + RH.NullBmpSize + 2;

      If (RH.VarColCount > 0) And
         (VarOfs + 2 + LongInt(RH.VarColCount) * 2 <=
          MDF_PAGE_SIZE) Then
      Begin
        { Le dernier offset variable donne la taille totale du row }
        LastVarEnd := ReadWord(Buf,
          VarOfs + 2 + (RH.VarColCount - 1) * 2);
        { Masquer le bit de poids fort (indicateur complexe) }
        LastVarEnd := LastVarEnd And $7FFF;
        If LastVarEnd > RH.RowSize Then
          RH.RowSize := LastVarEnd;
      End
      Else
      Begin
        { Ajouter l espace du tableau d offsets variables }
        RH.RowSize := RH.RowSize + RH.VarColCount * 2;
      End;
    End;
  End;

  RH.Valid := True;
End;

{ ---- Extraire les donnees brutes d un enregistrement ---------- }
{ Copie les octets d un row dans un buffer de sortie.            }
{ Retourne la taille effective copiee.                            }

Function ExtractRow(Const SrcBuf : TMdfPageBuf;
                     RowOfs : Word;
                     RowSize : Word;
                     Var RowBuf : TMdfPageBuf) : Word;
Var
  CopyLen : Word;
  I       : Word;
Begin
  ExtractRow := 0;
  FillChar(RowBuf, SizeOf(RowBuf), 0);
  If RowOfs >= MDF_PAGE_SIZE Then Exit;

  CopyLen := RowSize;
  If RowOfs + CopyLen > MDF_PAGE_SIZE Then
    CopyLen := MDF_PAGE_SIZE - RowOfs;

  For I := 0 To CopyLen - 1 Do
    RowBuf[I] := SrcBuf[RowOfs + I];

  ExtractRow := CopyLen;
End;

{ ---- Lire une page de donnees --------------------------------- }
{ Lit la page, verifie le type Data (1), extrait le slot array.  }

Function ReadDataPage(PageNum : LongInt;
                       Var DPI : TMdfDataPageInfo) : Boolean;
Var
  TmpBuf : TMdfPageBuf;
Begin
  ReadDataPage := False;
  DPI.Valid := False;
  DPI.SlotCnt := 0;
  FillChar(DPI.Slots, SizeOf(DPI.Slots), 0);

  If Not SeekPage(PageNum, TmpBuf) Then Exit;

  ParsePageHeader(TmpBuf, DPI.Header);

  If DPI.Header.PageType <> MDF_PT_DATA Then Exit;

  DPI.SlotCnt := DPI.Header.SlotCnt;
  If DPI.SlotCnt > MDF_MAX_SLOTS Then
    DPI.SlotCnt := MDF_MAX_SLOTS;

  ReadSlotArray(TmpBuf, DPI.SlotCnt, DPI.Slots);

  DPI.Valid := True;
  ReadDataPage := True;
End;

{ ---- Afficher les donnees d une page (mode verbose) ----------- }
{ Affiche l en-tete, le slot array et decode chaque row.         }

Procedure DumpDataPage(PageNum : LongInt);
Var
  TmpBuf   : TMdfPageBuf;
  Hdr      : TMdfPageHeader;
  Slots    : TMdfSlotArray;
  RH       : TMdfRowHeader;
  SC       : Word;
  I        : Integer;
  J        : Integer;
  RowOfs   : Word;
  HexStr   : TString;
  MaxDump  : Integer;
Begin
  If Not SeekPage(PageNum, TmpBuf) Then
  Begin
    WriteLn('  Page ', PageNum, ' : impossible a lire');
    Exit;
  End;

  ParsePageHeader(TmpBuf, Hdr);

  If Hdr.PageType <> MDF_PT_DATA Then
  Begin
    WriteLn('  Page ', PageNum, ' : type=', Hdr.PageType,
            ' (', PageTypeName(Hdr.PageType),
            '), pas une page de donnees');
    Exit;
  End;

  SC := Hdr.SlotCnt;
  If SC > MDF_MAX_SLOTS Then SC := MDF_MAX_SLOTS;

  WriteLn('  Page ', PageNum, ' (Data Page) :');
  WriteLn('    type       = ', Hdr.PageType,
          ' (', PageTypeName(Hdr.PageType), ')');
  WriteLn('    level      = ', Hdr.Level);
  WriteLn('    flagBits   = $', IntToStr(Hdr.FlagBits));
  WriteLn('    indexId    = ', Hdr.IndexId);
  WriteLn('    objId      = ', Hdr.ObjId);
  WriteLn('    prevPage   = ', Hdr.PrevFile, ':', Hdr.PrevPage);
  WriteLn('    nextPage   = ', Hdr.NextFile, ':', Hdr.NextPage);
  WriteLn('    slotCnt    = ', SC);
  WriteLn('    pMinLen    = ', Hdr.PMinLen);
  WriteLn('    freeCnt    = ', Hdr.FreeCnt);
  WriteLn('    freeData   = ', Hdr.FreeData);
  WriteLn('    reservedCnt= ', Hdr.ReservedCnt);

  { Lire le slot array }
  ReadSlotArray(TmpBuf, SC, Slots);

  WriteLn('    Slot Array (', SC, ' enregistrements) :');
  For I := 0 To SC - 1 Do
  Begin
    RowOfs := Slots[I];
    Write('      Slot[', I, '] offset=', RowOfs);

    { Decoder l en-tete de l enregistrement }
    If (RowOfs >= MDF_PAGE_HDR_SIZE) And
       (RowOfs < MDF_PAGE_SIZE) Then
    Begin
      ParseRowHeader(TmpBuf, RowOfs, RH);
      If RH.Valid Then
      Begin
        WriteLn(' recType=', RH.RecType,
                '(', RecTypeName(RH.RecType), ')',
                ' fixLen=', RH.FixedLen,
                ' cols=', RH.ColCount,
                ' varCols=', RH.VarColCount,
                ' rowSz=', RH.RowSize);
        WriteLn('        statusA=$', ByteToHex(RH.StatusA),
                ' statusB=$', ByteToHex(RH.StatusB),
                ' hasNull=', RH.HasNullBmp,
                ' hasVar=', RH.HasVarCols,
                ' hasVer=', RH.HasVersion,
                ' nullBmp=', RH.NullBmpSize, 'o');

        { Afficher les premiers octets bruts en hexadecimal }
        MaxDump := RH.RowSize;
        If MaxDump > 32 Then MaxDump := 32;
        If MaxDump > 0 Then
        Begin
          HexStr := '';
          For J := 0 To MaxDump - 1 Do
          Begin
            If RowOfs + J < MDF_PAGE_SIZE Then
              HexStr := HexStr + ByteToHex(TmpBuf[RowOfs + J])
                        + ' ';
          End;
          WriteLn('        hex: ', HexStr);
        End;
      End
      Else
      Begin
        WriteLn;
        WriteLn('        (enregistrement invalide)');
      End;
    End
    Else
    Begin
      WriteLn;
      WriteLn('        (offset hors limites)');
    End;
  End;
End;

{ ---- Scanner les pages de donnees ----------------------------- }
{ Parcourt les pages du fichier MDF pour identifier les pages    }
{ de donnees (type 1) et afficher leurs details en mode verbose. }

Procedure ScanDataPages;
Var
  TmpBuf    : TMdfPageBuf;
  Hdr       : TMdfPageHeader;
  I         : LongInt;
  DataCount : LongInt;
  MaxDetail : LongInt;
Begin
  If Not MdfOpen Then Exit;

  DataCount := 0;

  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('  Data Pages (TODO 04) :');
  End;

  { Limiter l affichage detaille aux 10 premieres pages }
  MaxDetail := 10;

  For I := 0 To MdfPageCnt - 1 Do
  Begin
    If SeekPage(I, TmpBuf) Then
    Begin
      ParsePageHeader(TmpBuf, Hdr);
      If Hdr.PageType = MDF_PT_DATA Then
      Begin
        Inc(DataCount);
        If Opts.Verbose And (DataCount <= MaxDetail) Then
          DumpDataPage(I);
      End;
    End;
  End;

  If Opts.Verbose Then
  Begin
    WriteLn('    Total pages de donnees : ', DataCount);
    If DataCount > MaxDetail Then
      WriteLn('    (affichage limite aux ', MaxDetail,
              ' premieres pages)');
  End;
End;

{ ============================================================
  TODO 05 - CATALOGUE SYSTEME (METADATA) [IMPLEMENTE]
  ============================================================ }

{ ---- Extraire une colonne variable Unicode d un row ----------- }
{ Lit la colonne variable a l index VarIdx (base 0) et la        }
{ convertit de UTF-16 LE en chaine ASCII (octets bas uniquement) }

Function ExtractRowVarUnicode(Const Buf : TMdfPageBuf;
                               RowOfs : Word;
                               VarIdx : Integer) : TCatName;
Var
  StatusA    : Byte;
  HasNull    : Boolean;
  HasVar     : Boolean;
  FixedLen   : Word;
  ColCount   : Word;
  NullBmpSz  : Word;
  VarCnt     : Word;
  VarOfs     : Word;
  OfsArrOfs  : Word;
  OfsEnd     : Word;
  DataStart  : Word;
  DataEnd    : Word;
  PrevEnd    : Word;
  I          : Integer;
  Lo         : Byte;
  S          : TCatName;
Begin
  S := '';
  ExtractRowVarUnicode := S;

  If RowOfs + 4 > MDF_PAGE_SIZE Then Exit;

  StatusA := Buf[RowOfs];
  HasNull := (StatusA And MDF_REC_HAS_NULL) <> 0;
  HasVar  := (StatusA And MDF_REC_HAS_VAR) <> 0;
  If Not HasVar Then Exit;

  FixedLen := ReadWord(Buf, RowOfs + 2);
  If FixedLen < 4 Then FixedLen := 4;
  If RowOfs + FixedLen + 2 > MDF_PAGE_SIZE Then Exit;

  ColCount := ReadWord(Buf, RowOfs + FixedLen);
  If HasNull And (ColCount > 0) Then
    NullBmpSz := (ColCount + 7) Div 8
  Else
    NullBmpSz := 0;

  VarOfs := RowOfs + FixedLen + 2 + NullBmpSz;
  If VarOfs + 2 > MDF_PAGE_SIZE Then Exit;

  VarCnt := ReadWord(Buf, VarOfs);
  If VarIdx >= VarCnt Then Exit;

  OfsArrOfs := VarOfs + 2;
  If OfsArrOfs + LongInt(VarCnt) * 2 > MDF_PAGE_SIZE Then Exit;

  OfsEnd := ReadWord(Buf, OfsArrOfs + VarIdx * 2) And $7FFF;

  If VarIdx = 0 Then
    DataStart := OfsArrOfs + VarCnt * 2
  Else
  Begin
    PrevEnd := ReadWord(Buf, OfsArrOfs + (VarIdx - 1) * 2) And $7FFF;
    DataStart := RowOfs + PrevEnd;
  End;

  DataEnd := RowOfs + OfsEnd;
  If DataStart >= DataEnd Then Exit;
  If DataEnd > MDF_PAGE_SIZE Then DataEnd := MDF_PAGE_SIZE;

  { Convertir UTF-16 LE en ASCII (octets bas) }
  I := 0;
  While (DataStart + I * 2 + 1 < DataEnd) And
        (Length(S) < MAX_CATNAME) Do
  Begin
    Lo := Buf[DataStart + I * 2];
    If Lo = 0 Then Break;
    S := S + Chr(Lo);
    Inc(I);
  End;

  ExtractRowVarUnicode := S;
End;

{ ---- Nom du type d objet SQL Server -------------------------- }

Function ObjTypeName(Const T : String) : TCatName;
Var
  U : String[2];
Begin
  U := '';
  If Length(T) >= 1 Then
  Begin
    U := T[1];
    If (Length(T) >= 2) And (T[2] <> ' ') Then
      U := U + T[2];
  End;

  If U = 'U' Then ObjTypeName := 'User Table'
  Else If U = 'V' Then ObjTypeName := 'View'
  Else If U = 'P' Then ObjTypeName := 'Procedure'
  Else If U = 'C' Then ObjTypeName := 'Check Constraint'
  Else If U = 'D' Then ObjTypeName := 'Default'
  Else If U = 'S' Then ObjTypeName := 'System Table'
  Else If U = 'FN' Then ObjTypeName := 'Scalar Function'
  Else If U = 'IF' Then ObjTypeName := 'Inline Function'
  Else If U = 'TF' Then ObjTypeName := 'Table Function'
  Else If U = 'TR' Then ObjTypeName := 'Trigger'
  Else If U = 'IT' Then ObjTypeName := 'Internal Table'
  Else If U = 'PK' Then ObjTypeName := 'Primary Key'
  Else If U = 'UQ' Then ObjTypeName := 'Unique Constraint'
  Else If U = 'F' Then ObjTypeName := 'Foreign Key'
  Else If U = 'SQ' Then ObjTypeName := 'Service Queue'
  Else ObjTypeName := 'Type(' + U + ')';
End;

{ ---- Nom d un type systeme SQL Server (xtype) ---------------- }

Function XTypeName(XT : Byte) : TCatName;
Begin
  Case XT Of
    34  : XTypeName := 'IMAGE';
    35  : XTypeName := 'TEXT';
    36  : XTypeName := 'UNIQUEIDENTIFIER';
    40  : XTypeName := 'DATE';
    41  : XTypeName := 'TIME';
    42  : XTypeName := 'DATETIME2';
    43  : XTypeName := 'DATETIMEOFFSET';
    48  : XTypeName := 'TINYINT';
    52  : XTypeName := 'SMALLINT';
    56  : XTypeName := 'INT';
    58  : XTypeName := 'SMALLDATETIME';
    59  : XTypeName := 'REAL';
    60  : XTypeName := 'MONEY';
    61  : XTypeName := 'DATETIME';
    62  : XTypeName := 'FLOAT';
    98  : XTypeName := 'SQL_VARIANT';
    99  : XTypeName := 'NTEXT';
    104 : XTypeName := 'BIT';
    106 : XTypeName := 'DECIMAL';
    108 : XTypeName := 'NUMERIC';
    122 : XTypeName := 'SMALLMONEY';
    127 : XTypeName := 'BIGINT';
    165 : XTypeName := 'VARBINARY';
    167 : XTypeName := 'VARCHAR';
    173 : XTypeName := 'BINARY';
    175 : XTypeName := 'CHAR';
    189 : XTypeName := 'TIMESTAMP';
    231 : XTypeName := 'NVARCHAR';
    239 : XTypeName := 'NCHAR';
    240 : XTypeName := 'CLR/GEOGRAPHY';
    241 : XTypeName := 'XML';
  Else
    XTypeName := 'xtype(' + IntToStr(XT) + ')';
  End;
End;

{ ---- Nom d un type d index ----------------------------------- }

Function IdxTypeName(IT : Byte) : TCatName;
Begin
  Case IT Of
    0 : IdxTypeName := 'Heap';
    1 : IdxTypeName := 'Clustered';
    2 : IdxTypeName := 'Nonclustered';
    3 : IdxTypeName := 'XML';
    4 : IdxTypeName := 'Spatial';
    5 : IdxTypeName := 'Clustered Columnstore';
    6 : IdxTypeName := 'Nonclustered Columnstore';
    7 : IdxTypeName := 'Nonclustered Hash';
  Else
    IdxTypeName := 'idxtype(' + IntToStr(IT) + ')';
  End;
End;

{ ---- Trouver le nom d un objet par son object_id ------------- }

Function FindObjectName(ObjId : LongInt) : TCatName;
Var
  I : Integer;
Begin
  For I := 0 To SysObjCount - 1 Do
  Begin
    If SysObjects[I].ObjectId = ObjId Then
    Begin
      FindObjectName := SysObjects[I].Name;
      Exit;
    End;
  End;
  FindObjectName := '(obj#' + IntToStr(ObjId) + ')';
End;

{ ---- Parser un row sysschobjs -------------------------------- }

Procedure ParseSysSchObjRow(Const Buf : TMdfPageBuf;
                            RowOfs : Word);
Var
  ObjId   : LongInt;
  SchId   : LongInt;
  ParId   : LongInt;
  Status  : LongInt;
  ObjType : String[2];
  ObjName : TCatName;
Begin
  If SysObjCount >= MAX_SYS_OBJECTS Then Exit;
  If RowOfs + MDF_SCHOBJ_PID + 4 > MDF_PAGE_SIZE Then Exit;

  ObjId  := ReadLong(Buf, RowOfs + MDF_SCHOBJ_ID);
  SchId  := ReadLong(Buf, RowOfs + MDF_SCHOBJ_NSID);
  Status := ReadLong(Buf, RowOfs + MDF_SCHOBJ_STATUS);

  ObjType := Chr(Buf[RowOfs + MDF_SCHOBJ_TYPE]);
  If RowOfs + MDF_SCHOBJ_TYPE + 1 < MDF_PAGE_SIZE Then
    ObjType := ObjType + Chr(Buf[RowOfs + MDF_SCHOBJ_TYPE + 1]);

  ParId := ReadLong(Buf, RowOfs + MDF_SCHOBJ_PID);

  { Extraire le nom (premiere colonne variable, UTF-16 LE) }
  ObjName := ExtractRowVarUnicode(Buf, RowOfs, 0);

  If ObjId <> 0 Then
  Begin
    SysObjects[SysObjCount].ObjectId  := ObjId;
    SysObjects[SysObjCount].Name      := ObjName;
    SysObjects[SysObjCount].ObjType   := ObjType;
    SysObjects[SysObjCount].ParentId  := ParId;
    SysObjects[SysObjCount].SchemaId  := SchId;
    SysObjects[SysObjCount].Status    := Status;
    SysObjects[SysObjCount].Valid     := True;
    Inc(SysObjCount);
  End;
End;

{ ---- Parser un row syscolpars -------------------------------- }

Procedure ParseSysColParRow(Const Buf : TMdfPageBuf;
                            RowOfs : Word);
Var
  ObjId   : LongInt;
  ColId   : LongInt;
  ColNum  : Word;
  XType   : Byte;
  MaxLen  : Word;
  Prec    : Byte;
  Scale   : Byte;
  CollId  : LongInt;
  Status  : LongInt;
  ColName : TCatName;
Begin
  If SysColCount >= MAX_SYS_COLUMNS Then Exit;
  If RowOfs + MDF_COLPAR_STATUS + 4 > MDF_PAGE_SIZE Then Exit;

  ObjId  := ReadLong(Buf, RowOfs + MDF_COLPAR_ID);
  ColNum := ReadWord(Buf, RowOfs + MDF_COLPAR_NUMBER);
  ColId  := ReadLong(Buf, RowOfs + MDF_COLPAR_COLID);
  XType  := Buf[RowOfs + MDF_COLPAR_XTYPE];
  MaxLen := ReadWord(Buf, RowOfs + MDF_COLPAR_LENGTH);
  Prec   := Buf[RowOfs + MDF_COLPAR_PREC];
  Scale  := Buf[RowOfs + MDF_COLPAR_SCALE];
  CollId := ReadLong(Buf, RowOfs + MDF_COLPAR_COLLID);
  Status := ReadLong(Buf, RowOfs + MDF_COLPAR_STATUS);

  { Extraire le nom (premiere colonne variable) }
  ColName := ExtractRowVarUnicode(Buf, RowOfs, 0);

  If ObjId <> 0 Then
  Begin
    SysColumns[SysColCount].ObjectId  := ObjId;
    SysColumns[SysColCount].ColumnId  := ColId;
    SysColumns[SysColCount].ColNum    := ColNum;
    SysColumns[SysColCount].Name      := ColName;
    SysColumns[SysColCount].XType     := XType;
    SysColumns[SysColCount].MaxLen    := MaxLen;
    SysColumns[SysColCount].Prec      := Prec;
    SysColumns[SysColCount].Scale     := Scale;
    SysColumns[SysColCount].CollId    := CollId;
    SysColumns[SysColCount].Status    := Status;
    { Bit 0 du status indique nullable }
    SysColumns[SysColCount].Nullable  := (Status And 1) <> 0;
    SysColumns[SysColCount].Valid     := True;
    Inc(SysColCount);
  End;
End;

{ ---- Parser un row sysidxstats ------------------------------- }

Procedure ParseSysIdxStatRow(Const Buf : TMdfPageBuf;
                             RowOfs : Word);
Var
  ObjId   : LongInt;
  IndId   : LongInt;
  Status  : LongInt;
  IdxType : Byte;
  IdxName : TCatName;
Begin
  If SysIdxCount >= MAX_SYS_INDEXES Then Exit;
  If RowOfs + MDF_IDXST_TYPE + 1 > MDF_PAGE_SIZE Then Exit;

  ObjId   := ReadLong(Buf, RowOfs + MDF_IDXST_ID);
  IndId   := ReadLong(Buf, RowOfs + MDF_IDXST_INDID);
  Status  := ReadLong(Buf, RowOfs + MDF_IDXST_STATUS);
  IdxType := Buf[RowOfs + MDF_IDXST_TYPE];

  { Extraire le nom (premiere colonne variable) }
  IdxName := ExtractRowVarUnicode(Buf, RowOfs, 0);

  If ObjId <> 0 Then
  Begin
    SysIndexes[SysIdxCount].ObjectId := ObjId;
    SysIndexes[SysIdxCount].IndexId  := IndId;
    SysIndexes[SysIdxCount].Name     := IdxName;
    SysIndexes[SysIdxCount].IdxType  := IdxType;
    SysIndexes[SysIdxCount].Status   := Status;
    SysIndexes[SysIdxCount].Valid    := True;
    Inc(SysIdxCount);
  End;
End;

{ ---- Parser un row sysiscols --------------------------------- }

Procedure ParseSysIsColRow(Const Buf : TMdfPageBuf;
                           RowOfs : Word);
Var
  ObjId   : LongInt;
  IndId   : LongInt;
  SubId   : LongInt;
  ColId   : LongInt;
  Status  : LongInt;
Begin
  If SysIcCount >= MAX_SYS_IDXCOLS Then Exit;
  If RowOfs + MDF_ISCOL_INTPROP + 4 > MDF_PAGE_SIZE Then Exit;

  ObjId  := ReadLong(Buf, RowOfs + MDF_ISCOL_IDMAJOR);
  IndId  := ReadLong(Buf, RowOfs + MDF_ISCOL_IDMINOR);
  SubId  := ReadLong(Buf, RowOfs + MDF_ISCOL_SUBID);
  Status := ReadLong(Buf, RowOfs + MDF_ISCOL_STATUS);
  ColId  := ReadLong(Buf, RowOfs + MDF_ISCOL_INTPROP);

  If ObjId <> 0 Then
  Begin
    SysIdxCols[SysIcCount].ObjectId := ObjId;
    SysIdxCols[SysIcCount].IndexId  := IndId;
    SysIdxCols[SysIcCount].SubId    := SubId;
    SysIdxCols[SysIcCount].ColumnId := ColId;
    SysIdxCols[SysIcCount].Status   := Status;
    SysIdxCols[SysIcCount].Valid    := True;
    Inc(SysIcCount);
  End;
End;

{ ---- Parser un row sysrowsets -------------------------------- }

Procedure ParseSysRowSetRow(Const Buf : TMdfPageBuf;
                            RowOfs : Word);
Var
  RsLo    : LongInt;
  RsHi    : LongInt;
  OwnId   : LongInt;
  ObjId   : LongInt;
  IndId   : LongInt;
Begin
  If SysRsCount >= MAX_SYS_ROWSETS Then Exit;
  If RowOfs + MDF_ROWSET_IDMINOR + 4 > MDF_PAGE_SIZE Then Exit;

  RsLo  := ReadLong(Buf, RowOfs + MDF_ROWSET_RSLO);
  RsHi  := ReadLong(Buf, RowOfs + MDF_ROWSET_RSHI);
  OwnId := ReadLong(Buf, RowOfs + MDF_ROWSET_OWNERID);
  ObjId := ReadLong(Buf, RowOfs + MDF_ROWSET_IDMAJOR);
  IndId := ReadLong(Buf, RowOfs + MDF_ROWSET_IDMINOR);

  If (RsLo <> 0) Or (RsHi <> 0) Then
  Begin
    SysRowSets[SysRsCount].RowSetLo := RsLo;
    SysRowSets[SysRsCount].RowSetHi := RsHi;
    SysRowSets[SysRsCount].OwnerId  := OwnId;
    SysRowSets[SysRsCount].ObjectId := ObjId;
    SysRowSets[SysRsCount].IndexId  := IndId;
    SysRowSets[SysRsCount].Valid    := True;
    Inc(SysRsCount);
  End;
End;

{ ---- Afficher le catalogue systeme (mode verbose) ------------- }
{ Affiche les objets, leurs colonnes et leurs index.             }

Procedure DumpCatalog;
Var
  I, J   : Integer;
  ObjId  : LongInt;
  ColStr : TCatName;
  OType  : String[2];
Begin
  WriteLn;
  WriteLn('  Schema de la base de donnees :');
  WriteLn('  =============================');

  For I := 0 To SysObjCount - 1 Do
  Begin
    If SysObjects[I].Valid Then
    Begin
      OType := SysObjects[I].ObjType;
      WriteLn;
      Write('    [');
      { Afficher le type sans espaces de fin }
      If Length(OType) >= 1 Then Write(OType[1]);
      If (Length(OType) >= 2) And (OType[2] <> ' ') Then
        Write(OType[2]);
      Write('] ', SysObjects[I].Name);
      WriteLn(' (id=', SysObjects[I].ObjectId,
              ', ', ObjTypeName(OType), ')');

      ObjId := SysObjects[I].ObjectId;

      { Colonnes pour les tables (U) et tables systeme (S) }
      If (Length(OType) >= 1) And
         ((OType[1] = 'U') Or (OType[1] = 'S')) Then
      Begin
        For J := 0 To SysColCount - 1 Do
        Begin
          If SysColumns[J].Valid And
             (SysColumns[J].ObjectId = ObjId) Then
          Begin
            ColStr := XTypeName(SysColumns[J].XType);
            Write('      col[', SysColumns[J].ColumnId, '] ',
                  SysColumns[J].Name, ' : ', ColStr);
            If SysColumns[J].MaxLen > 0 Then
              Write('(', SysColumns[J].MaxLen, ')');
            If SysColumns[J].Prec > 0 Then
              Write(' prec=', SysColumns[J].Prec);
            If SysColumns[J].Scale > 0 Then
              Write(' scale=', SysColumns[J].Scale);
            If SysColumns[J].Nullable Then
              Write(' NULL')
            Else
              Write(' NOT NULL');
            WriteLn;
          End;
        End;

        { Index de l objet }
        For J := 0 To SysIdxCount - 1 Do
        Begin
          If SysIndexes[J].Valid And
             (SysIndexes[J].ObjectId = ObjId) Then
          Begin
            WriteLn('      idx[', SysIndexes[J].IndexId, '] ',
                    SysIndexes[J].Name,
                    ' (', IdxTypeName(SysIndexes[J].IdxType), ')');
          End;
        End;
      End;
    End;
  End;
  WriteLn;
End;

{ ---- Lire le catalogue systeme complet ------------------------ }
{ Scan unique de toutes les pages pour extraire les metadata      }
{ des 5 tables systeme internes.                                  }

Procedure ReadSystemCatalog;
Var
  TmpBuf    : TMdfPageBuf;
  Hdr       : TMdfPageHeader;
  Slots     : TMdfSlotArray;
  I         : LongInt;
  J         : Integer;
  RowOfs    : Word;
  SC        : Word;
  IsSysPg   : Boolean;
Begin
  SysObjCount  := 0;
  SysColCount  := 0;
  SysIdxCount  := 0;
  SysIcCount   := 0;
  SysRsCount   := 0;
  CatalogValid := False;

  If Not MdfOpen Then Exit;

  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('  Catalogue systeme (TODO 05) :');
  End;

  { Scanner toutes les pages pour trouver les pages systeme }
  For I := 0 To MdfPageCnt - 1 Do
  Begin
    If SeekPage(I, TmpBuf) Then
    Begin
      ParsePageHeader(TmpBuf, Hdr);

      If Hdr.PageType = MDF_PT_DATA Then
      Begin
        { Verifier si la page appartient a une table systeme }
        IsSysPg := (Hdr.ObjId = MDF_SYSOBJ_SYSSCHOBJS) Or
                   (Hdr.ObjId = MDF_SYSOBJ_SYSCOLPARS) Or
                   (Hdr.ObjId = MDF_SYSOBJ_SYSIDXSTATS) Or
                   (Hdr.ObjId = MDF_SYSOBJ_SYSISCOLS) Or
                   (Hdr.ObjId = MDF_SYSOBJ_SYSROWSETS);

        If IsSysPg Then
        Begin
          SC := Hdr.SlotCnt;
          If SC > MDF_MAX_SLOTS Then SC := MDF_MAX_SLOTS;
          ReadSlotArray(TmpBuf, SC, Slots);

          For J := 0 To SC - 1 Do
          Begin
            RowOfs := Slots[J];
            If (RowOfs >= MDF_PAGE_HDR_SIZE) And
               (RowOfs < MDF_PAGE_SIZE - 4) Then
            Begin
              If Hdr.ObjId = MDF_SYSOBJ_SYSSCHOBJS Then
                ParseSysSchObjRow(TmpBuf, RowOfs)
              Else If Hdr.ObjId = MDF_SYSOBJ_SYSCOLPARS Then
                ParseSysColParRow(TmpBuf, RowOfs)
              Else If Hdr.ObjId = MDF_SYSOBJ_SYSIDXSTATS Then
                ParseSysIdxStatRow(TmpBuf, RowOfs)
              Else If Hdr.ObjId = MDF_SYSOBJ_SYSISCOLS Then
                ParseSysIsColRow(TmpBuf, RowOfs)
              Else If Hdr.ObjId = MDF_SYSOBJ_SYSROWSETS Then
                ParseSysRowSetRow(TmpBuf, RowOfs);
            End;
          End;
        End;
      End;
    End;
  End;

  CatalogValid := (SysObjCount > 0);

  If Opts.Verbose Then
  Begin
    WriteLn('    Objets trouves   : ', SysObjCount);
    WriteLn('    Colonnes trouvees: ', SysColCount);
    WriteLn('    Index trouves    : ', SysIdxCount);
    WriteLn('    Index cols       : ', SysIcCount);
    WriteLn('    Rowsets trouves  : ', SysRsCount);
  End;

  { Afficher le schema si le catalogue est valide }
  If CatalogValid And Opts.Verbose Then
    DumpCatalog;
End;

{ ============================================================
  TODO 06 - DECODAGE DES TYPES DE DONNEES SQL SERVER [IMPLEMENTE]
  ============================================================ }

{ ---- Categorie d un type SQL Server par xtype ---------------- }

Function SqlTypeCategory(XT : Byte) : Byte;
Begin
  Case XT Of
    XT_TINYINT, XT_SMALLINT, XT_INT, XT_BIGINT, XT_BIT :
      SqlTypeCategory := SQLCAT_INTEGER;
    XT_DECIMAL, XT_NUMERIC, XT_FLOAT, XT_REAL,
    XT_MONEY, XT_SMALLMONEY :
      SqlTypeCategory := SQLCAT_DECIMAL;
    XT_CHAR, XT_VARCHAR, XT_NCHAR, XT_NVARCHAR,
    XT_TEXT, XT_NTEXT :
      SqlTypeCategory := SQLCAT_STRING;
    XT_DATE, XT_TIME, XT_DATETIME, XT_DATETIME2,
    XT_DATETIMEOFFSET, XT_SMALLDATETIME :
      SqlTypeCategory := SQLCAT_DATETIME;
    XT_BINARY, XT_VARBINARY, XT_IMAGE, XT_TIMESTAMP :
      SqlTypeCategory := SQLCAT_BINARY;
    XT_UNIQUEID, XT_XML, XT_SQL_VARIANT,
    XT_CLR, XT_HIERARCHYID :
      SqlTypeCategory := SQLCAT_SPECIAL;
  Else
    SqlTypeCategory := SQLCAT_UNKNOWN;
  End;
End;

{ ---- Taille fixe d un type SQL Server (0 si variable) -------- }

Function SqlTypeFixedSize(XT : Byte) : Word;
Begin
  Case XT Of
    XT_BIT         : SqlTypeFixedSize := 1;
    XT_TINYINT     : SqlTypeFixedSize := 1;
    XT_SMALLINT    : SqlTypeFixedSize := 2;
    XT_INT         : SqlTypeFixedSize := 4;
    XT_BIGINT      : SqlTypeFixedSize := 8;
    XT_REAL        : SqlTypeFixedSize := 4;
    XT_FLOAT       : SqlTypeFixedSize := 8;
    XT_SMALLMONEY  : SqlTypeFixedSize := 4;
    XT_MONEY       : SqlTypeFixedSize := 8;
    XT_SMALLDATETIME : SqlTypeFixedSize := 4;
    XT_DATETIME    : SqlTypeFixedSize := 8;
    XT_DATE        : SqlTypeFixedSize := 3;
    XT_UNIQUEID    : SqlTypeFixedSize := 16;
    XT_TIMESTAMP   : SqlTypeFixedSize := 8;
  Else
    SqlTypeFixedSize := 0;  { variable ou depend de precision }
  End;
End;

{ ---- Type a longueur variable ? ------------------------------ }

Function SqlTypeIsVariable(XT : Byte) : Boolean;
Begin
  Case XT Of
    XT_VARCHAR, XT_NVARCHAR, XT_VARBINARY,
    XT_TEXT, XT_NTEXT, XT_IMAGE, XT_XML,
    XT_SQL_VARIANT, XT_HIERARCHYID, XT_CLR :
      SqlTypeIsVariable := True;
  Else
    SqlTypeIsVariable := False;
  End;
End;

{ ---- Initialiser une valeur SQL a NULL ----------------------- }

Procedure InitSqlValue(Var V : TSqlValue);
Begin
  V.IsNull   := True;
  V.Category := SQLCAT_UNKNOWN;
  V.XType    := 0;
  V.IntVal   := 0;
  V.HiVal    := 0;
  V.FloatVal := 0.0;
  V.StrVal   := '';
  V.BinLen   := 0;
  V.Year     := 0;
  V.Month    := 0;
  V.Day      := 0;
  V.Hour     := 0;
  V.Minute   := 0;
  V.Second   := 0;
  V.Frac     := 0;
  V.Scale    := 0;
  V.Prec     := 0;
  V.Sign     := 1;
  V.Valid    := False;
End;

{ ---- Decoder un type entier ---------------------------------- }
{ TINYINT (1o), SMALLINT (2o), INT (4o), BIGINT (8o), BIT       }

Procedure DecodeInt(Const Buf : TMdfPageBuf;
                    Ofs : Word; XT : Byte;
                    Var V : TSqlValue);
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_INTEGER;

  Case XT Of
    XT_BIT :
    Begin
      If Ofs >= MDF_PAGE_SIZE Then Exit;
      V.IntVal := Buf[Ofs] And 1;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_TINYINT :
    Begin
      If Ofs >= MDF_PAGE_SIZE Then Exit;
      V.IntVal := Buf[Ofs];
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_SMALLINT :
    Begin
      If Ofs + 1 >= MDF_PAGE_SIZE Then Exit;
      V.IntVal := SmallInt(ReadWord(Buf, Ofs));
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_INT :
    Begin
      If Ofs + 3 >= MDF_PAGE_SIZE Then Exit;
      V.IntVal := ReadLong(Buf, Ofs);
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_BIGINT :
    Begin
      If Ofs + 7 >= MDF_PAGE_SIZE Then Exit;
      { BIGINT = 8 octets : partie basse dans IntVal,           }
      {                      partie haute dans HiVal             }
      V.IntVal := ReadLong(Buf, Ofs);
      V.HiVal  := ReadLong(Buf, Ofs + 4);
      V.IsNull := False;
      V.Valid  := True;
    End;
  End;
End;

{ ---- Decoder un type decimal/flottant ------------------------ }
{ DECIMAL(p,s), NUMERIC(p,s), FLOAT, REAL, MONEY, SMALLMONEY   }

Procedure DecodeDecimal(Const Buf : TMdfPageBuf;
                        Ofs : Word; XT : Byte;
                        ColPrec, ColScale : Byte;
                        Var V : TSqlValue);
Var
  Money4  : LongInt;
  MoneyLo : LongInt;
  MoneyHi : LongInt;
  FloatRec : Record
    Case Byte Of
      0: (S : Single);
      1: (D : Double);
      2: (B : Array[0..7] Of Byte);
  End;
  I : Integer;
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_DECIMAL;
  V.Prec     := ColPrec;
  V.Scale    := ColScale;

  Case XT Of
    XT_REAL :
    Begin
      If Ofs + 3 >= MDF_PAGE_SIZE Then Exit;
      For I := 0 To 3 Do
        FloatRec.B[I] := Buf[Ofs + I];
      V.FloatVal := FloatRec.S;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_FLOAT :
    Begin
      If Ofs + 7 >= MDF_PAGE_SIZE Then Exit;
      For I := 0 To 7 Do
        FloatRec.B[I] := Buf[Ofs + I];
      V.FloatVal := FloatRec.D;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_SMALLMONEY :
    Begin
      If Ofs + 3 >= MDF_PAGE_SIZE Then Exit;
      Money4 := ReadLong(Buf, Ofs);
      { SMALLMONEY = entier / 10000 }
      V.IntVal := Money4;
      V.Scale  := 4;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_MONEY :
    Begin
      If Ofs + 7 >= MDF_PAGE_SIZE Then Exit;
      { MONEY = 8 octets (hi:lo en format special SQL Server) }
      MoneyHi := ReadLong(Buf, Ofs);
      MoneyLo := ReadLong(Buf, Ofs + 4);
      V.IntVal := MoneyLo;
      V.HiVal  := MoneyHi;
      V.Scale  := 4;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_DECIMAL, XT_NUMERIC :
    Begin
      { DECIMAL/NUMERIC : 1 octet signe + 4/8/12/16 octets val }
      If Ofs >= MDF_PAGE_SIZE Then Exit;
      V.Sign := Buf[Ofs];
      If Ofs + 4 >= MDF_PAGE_SIZE Then Exit;
      V.IntVal := ReadLong(Buf, Ofs + 1);
      If ColPrec > 9 Then
      Begin
        If Ofs + 8 < MDF_PAGE_SIZE Then
          V.HiVal := ReadLong(Buf, Ofs + 5);
      End;
      V.Prec   := ColPrec;
      V.Scale  := ColScale;
      V.IsNull := False;
      V.Valid  := True;
    End;
  End;
End;

{ ---- Decoder un type chaine ---------------------------------- }
{ CHAR(n), VARCHAR(n), NCHAR(n), NVARCHAR(n), TEXT, NTEXT       }
{ Pour CHAR/NCHAR la longueur est fixe (MaxLen).                 }
{ Pour VARCHAR/NVARCHAR la longueur est donnee par DataLen.      }

Procedure DecodeString(Const Buf : TMdfPageBuf;
                       Ofs : Word; DataLen : Word;
                       XT : Byte;
                       Var V : TSqlValue);
Var
  I   : Integer;
  Len : Word;
  Lo  : Byte;
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_STRING;

  If Ofs >= MDF_PAGE_SIZE Then Exit;
  If DataLen = 0 Then
  Begin
    V.StrVal := '';
    V.IsNull := False;
    V.Valid  := True;
    Exit;
  End;

  Len := DataLen;
  If Ofs + Len > MDF_PAGE_SIZE Then
    Len := MDF_PAGE_SIZE - Ofs;

  Case XT Of
    XT_CHAR, XT_VARCHAR, XT_TEXT :
    Begin
      { Chaines ASCII (1 octet par caractere) }
      V.StrVal := '';
      I := 0;
      While (I < Len) And (Length(V.StrVal) < MAX_SQL_VALUE_STR) Do
      Begin
        V.StrVal := V.StrVal + Chr(Buf[Ofs + I]);
        Inc(I);
      End;
      { Supprimer les espaces de fin pour CHAR }
      If XT = XT_CHAR Then
      Begin
        While (Length(V.StrVal) > 0) And
              (V.StrVal[Length(V.StrVal)] = ' ') Do
          Dec(V.StrVal[0]);
      End;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_NCHAR, XT_NVARCHAR, XT_NTEXT :
    Begin
      { Chaines Unicode UTF-16 LE (2 octets par caractere) }
      V.StrVal := '';
      I := 0;
      While (I * 2 + 1 < Len) And
            (Length(V.StrVal) < MAX_SQL_VALUE_STR) Do
      Begin
        Lo := Buf[Ofs + I * 2];
        If Lo = 0 Then Break;
        V.StrVal := V.StrVal + Chr(Lo);
        Inc(I);
      End;
      { Supprimer les espaces de fin pour NCHAR }
      If XT = XT_NCHAR Then
      Begin
        While (Length(V.StrVal) > 0) And
              (V.StrVal[Length(V.StrVal)] = ' ') Do
          Dec(V.StrVal[0]);
      End;
      V.IsNull := False;
      V.Valid  := True;
    End;
  End;
End;

{ ---- Decoder un type date/heure ------------------------------ }
{ DATE, TIME, DATETIME, DATETIME2, DATETIMEOFFSET, SMALLDATETIME}

Procedure DecodeDateTime(Const Buf : TMdfPageBuf;
                         Ofs : Word; XT : Byte;
                         ColScale : Byte;
                         Var V : TSqlValue);
Var
  Days     : LongInt;
  TimeTicks: LongInt;
  DateVal  : LongInt;
  TimeVal  : LongInt;
  Y, M, D  : Word;
  TotalDays: LongInt;
  DaysInM  : Word;
  Leap     : Boolean;
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_DATETIME;
  V.Scale    := ColScale;

  Case XT Of
    XT_DATETIME :
    Begin
      { DATETIME = 8 octets : 4 oct. jours depuis 1900-01-01      }
      {            + 4 oct. ticks de 1/300e de seconde depuis minuit}
      If Ofs + 7 >= MDF_PAGE_SIZE Then Exit;
      Days      := ReadLong(Buf, Ofs);
      TimeTicks := ReadLong(Buf, Ofs + 4);

      { Convertir les jours en Y/M/D depuis 1900-01-01 }
      TotalDays := Days;
      Y := 1900;
      While TotalDays > 0 Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        If Leap Then
        Begin
          If TotalDays >= 366 Then
          Begin Dec(TotalDays, 366); Inc(Y); End
          Else Break;
        End
        Else
        Begin
          If TotalDays >= 365 Then
          Begin Dec(TotalDays, 365); Inc(Y); End
          Else Break;
        End;
      End;

      M := 1;
      While (M <= 12) And (TotalDays > 0) Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        Case M Of
          1, 3, 5, 7, 8, 10, 12 : DaysInM := 31;
          4, 6, 9, 11            : DaysInM := 30;
          2 : If Leap Then DaysInM := 29 Else DaysInM := 28;
        Else DaysInM := 30;
        End;
        If TotalDays >= DaysInM Then
        Begin Dec(TotalDays, DaysInM); Inc(M); End
        Else Break;
      End;
      D := TotalDays + 1;

      V.Year   := Y;
      V.Month  := M;
      V.Day    := D;

      { Convertir les ticks en H:M:S (1 tick = 1/300 sec) }
      V.Second := (TimeTicks Div 300) Mod 60;
      V.Minute := ((TimeTicks Div 300) Div 60) Mod 60;
      V.Hour   := (TimeTicks Div 300) Div 3600;
      V.Frac   := (TimeTicks Mod 300) * 3333;  { ~millisecondes }

      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_SMALLDATETIME :
    Begin
      { SMALLDATETIME = 4 octets : 2 oct. jours depuis 1900-01-01 }
      {                 + 2 oct. minutes depuis minuit              }
      If Ofs + 3 >= MDF_PAGE_SIZE Then Exit;
      Days := ReadWord(Buf, Ofs);
      TimeTicks := ReadWord(Buf, Ofs + 2);

      TotalDays := Days;
      Y := 1900;
      While TotalDays > 0 Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        If Leap Then
        Begin
          If TotalDays >= 366 Then
          Begin Dec(TotalDays, 366); Inc(Y); End
          Else Break;
        End
        Else
        Begin
          If TotalDays >= 365 Then
          Begin Dec(TotalDays, 365); Inc(Y); End
          Else Break;
        End;
      End;

      M := 1;
      While (M <= 12) And (TotalDays > 0) Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        Case M Of
          1, 3, 5, 7, 8, 10, 12 : DaysInM := 31;
          4, 6, 9, 11            : DaysInM := 30;
          2 : If Leap Then DaysInM := 29 Else DaysInM := 28;
        Else DaysInM := 30;
        End;
        If TotalDays >= DaysInM Then
        Begin Dec(TotalDays, DaysInM); Inc(M); End
        Else Break;
      End;
      D := TotalDays + 1;

      V.Year   := Y;
      V.Month  := M;
      V.Day    := D;
      V.Hour   := TimeTicks Div 60;
      V.Minute := TimeTicks Mod 60;
      V.Second := 0;

      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_DATE :
    Begin
      { DATE = 3 octets : jours depuis 0001-01-01 }
      If Ofs + 2 >= MDF_PAGE_SIZE Then Exit;
      DateVal := LongInt(Buf[Ofs])
              Or (LongInt(Buf[Ofs + 1]) Shl 8)
              Or (LongInt(Buf[Ofs + 2]) Shl 16);

      TotalDays := DateVal;
      Y := 1;
      While TotalDays > 0 Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        If Leap Then
        Begin
          If TotalDays >= 366 Then
          Begin Dec(TotalDays, 366); Inc(Y); End
          Else Break;
        End
        Else
        Begin
          If TotalDays >= 365 Then
          Begin Dec(TotalDays, 365); Inc(Y); End
          Else Break;
        End;
      End;

      M := 1;
      While (M <= 12) And (TotalDays > 0) Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        Case M Of
          1, 3, 5, 7, 8, 10, 12 : DaysInM := 31;
          4, 6, 9, 11            : DaysInM := 30;
          2 : If Leap Then DaysInM := 29 Else DaysInM := 28;
        Else DaysInM := 30;
        End;
        If TotalDays >= DaysInM Then
        Begin Dec(TotalDays, DaysInM); Inc(M); End
        Else Break;
      End;
      D := TotalDays + 1;

      V.Year  := Y;
      V.Month := M;
      V.Day   := D;

      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_TIME :
    Begin
      { TIME = 3-5 octets selon scale (ticks depuis minuit) }
      If Ofs + 2 >= MDF_PAGE_SIZE Then Exit;
      TimeVal := LongInt(Buf[Ofs])
              Or (LongInt(Buf[Ofs + 1]) Shl 8)
              Or (LongInt(Buf[Ofs + 2]) Shl 16);

      { Pour scale 0-2, les ticks sont en fractions de seconde }
      { Simplification : on divise par 10^scale pour obtenir sec }
      V.Scale  := ColScale;
      V.Frac   := TimeVal;
      { Convertir en H:M:S approximatif }
      If ColScale <= 2 Then
      Begin
        V.Second := TimeVal Mod 60;
        V.Minute := (TimeVal Div 60) Mod 60;
        V.Hour   := TimeVal Div 3600;
      End
      Else
      Begin
        { Valeur brute stockee, conversion approx }
        V.Second := (TimeVal Div 10000000) Mod 60;
        V.Minute := ((TimeVal Div 10000000) Div 60) Mod 60;
        V.Hour   := (TimeVal Div 10000000) Div 3600;
      End;

      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_DATETIME2 :
    Begin
      { DATETIME2 = time (3-5 oct.) + date (3 oct.) }
      { Simplification : lire les 3 derniers octets comme DATE }
      If Ofs + 5 >= MDF_PAGE_SIZE Then Exit;
      { Les 3 derniers octets sont la partie date }
      DateVal := LongInt(Buf[Ofs + 3])
              Or (LongInt(Buf[Ofs + 4]) Shl 8)
              Or (LongInt(Buf[Ofs + 5]) Shl 16);

      TotalDays := DateVal;
      Y := 1;
      While TotalDays > 0 Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        If Leap Then
        Begin
          If TotalDays >= 366 Then
          Begin Dec(TotalDays, 366); Inc(Y); End
          Else Break;
        End
        Else
        Begin
          If TotalDays >= 365 Then
          Begin Dec(TotalDays, 365); Inc(Y); End
          Else Break;
        End;
      End;

      M := 1;
      While (M <= 12) And (TotalDays > 0) Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        Case M Of
          1, 3, 5, 7, 8, 10, 12 : DaysInM := 31;
          4, 6, 9, 11            : DaysInM := 30;
          2 : If Leap Then DaysInM := 29 Else DaysInM := 28;
        Else DaysInM := 30;
        End;
        If TotalDays >= DaysInM Then
        Begin Dec(TotalDays, DaysInM); Inc(M); End
        Else Break;
      End;
      D := TotalDays + 1;

      V.Year  := Y;
      V.Month := M;
      V.Day   := D;

      { Partie temps (3 premiers octets) }
      TimeVal := LongInt(Buf[Ofs])
              Or (LongInt(Buf[Ofs + 1]) Shl 8)
              Or (LongInt(Buf[Ofs + 2]) Shl 16);
      V.Frac   := TimeVal;
      V.Scale  := ColScale;

      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_DATETIMEOFFSET :
    Begin
      { DATETIMEOFFSET = time + date + 2 oct. offset en minutes }
      If Ofs + 7 >= MDF_PAGE_SIZE Then Exit;
      { Similaire a DATETIME2 + 2 oct. offset }
      DateVal := LongInt(Buf[Ofs + 3])
              Or (LongInt(Buf[Ofs + 4]) Shl 8)
              Or (LongInt(Buf[Ofs + 5]) Shl 16);

      TotalDays := DateVal;
      Y := 1;
      While TotalDays > 0 Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        If Leap Then
        Begin
          If TotalDays >= 366 Then
          Begin Dec(TotalDays, 366); Inc(Y); End
          Else Break;
        End
        Else
        Begin
          If TotalDays >= 365 Then
          Begin Dec(TotalDays, 365); Inc(Y); End
          Else Break;
        End;
      End;

      M := 1;
      While (M <= 12) And (TotalDays > 0) Do
      Begin
        Leap := ((Y Mod 4 = 0) And (Y Mod 100 <> 0)) Or
                (Y Mod 400 = 0);
        Case M Of
          1, 3, 5, 7, 8, 10, 12 : DaysInM := 31;
          4, 6, 9, 11            : DaysInM := 30;
          2 : If Leap Then DaysInM := 29 Else DaysInM := 28;
        Else DaysInM := 30;
        End;
        If TotalDays >= DaysInM Then
        Begin Dec(TotalDays, DaysInM); Inc(M); End
        Else Break;
      End;
      D := TotalDays + 1;

      V.Year  := Y;
      V.Month := M;
      V.Day   := D;

      TimeVal := LongInt(Buf[Ofs])
              Or (LongInt(Buf[Ofs + 1]) Shl 8)
              Or (LongInt(Buf[Ofs + 2]) Shl 16);
      V.Frac  := TimeVal;
      V.Scale := ColScale;

      V.IsNull := False;
      V.Valid  := True;
    End;
  End;
End;

{ ---- Decoder un type binaire --------------------------------- }
{ BINARY(n), VARBINARY(n), IMAGE, TIMESTAMP                     }

Procedure DecodeBinary(Const Buf : TMdfPageBuf;
                       Ofs : Word; DataLen : Word;
                       XT : Byte;
                       Var V : TSqlValue);
Var
  I   : Integer;
  Len : Word;
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_BINARY;

  If Ofs >= MDF_PAGE_SIZE Then Exit;

  Len := DataLen;
  If Ofs + Len > MDF_PAGE_SIZE Then
    Len := MDF_PAGE_SIZE - Ofs;
  V.BinLen := Len;

  { Convertir en representation hexadecimale dans StrVal }
  V.StrVal := '0x';
  I := 0;
  While (I < Len) And (Length(V.StrVal) + 2 <= MAX_SQL_VALUE_STR) Do
  Begin
    V.StrVal := V.StrVal + ByteToHex(Buf[Ofs + I]);
    Inc(I);
  End;
  If I < Len Then
    V.StrVal := V.StrVal + '...';

  V.IsNull := False;
  V.Valid  := True;
End;

{ ---- Decoder un type special --------------------------------- }
{ UNIQUEIDENTIFIER, XML, SQL_VARIANT, TIMESTAMP, CLR            }

Procedure DecodeSpecial(Const Buf : TMdfPageBuf;
                        Ofs : Word; DataLen : Word;
                        XT : Byte;
                        Var V : TSqlValue);
Var
  I : Integer;
Begin
  InitSqlValue(V);
  V.XType    := XT;
  V.Category := SQLCAT_SPECIAL;

  If Ofs >= MDF_PAGE_SIZE Then Exit;

  Case XT Of
    XT_UNIQUEID :
    Begin
      { UNIQUEIDENTIFIER = 16 octets (GUID)                      }
      { Format : DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD           }
      { Octets 0-3 en Little-Endian, 4-5 LE, 6-7 LE,            }
      { 8-9 Big-Endian, 10-15 Big-Endian                         }
      If Ofs + 15 >= MDF_PAGE_SIZE Then Exit;
      V.StrVal :=
        ByteToHex(Buf[Ofs + 3]) + ByteToHex(Buf[Ofs + 2]) +
        ByteToHex(Buf[Ofs + 1]) + ByteToHex(Buf[Ofs + 0]) + '-' +
        ByteToHex(Buf[Ofs + 5]) + ByteToHex(Buf[Ofs + 4]) + '-' +
        ByteToHex(Buf[Ofs + 7]) + ByteToHex(Buf[Ofs + 6]) + '-' +
        ByteToHex(Buf[Ofs + 8]) + ByteToHex(Buf[Ofs + 9]) + '-' +
        ByteToHex(Buf[Ofs + 10]) + ByteToHex(Buf[Ofs + 11]) +
        ByteToHex(Buf[Ofs + 12]) + ByteToHex(Buf[Ofs + 13]) +
        ByteToHex(Buf[Ofs + 14]) + ByteToHex(Buf[Ofs + 15]);
      V.BinLen := 16;
      V.IsNull := False;
      V.Valid  := True;
    End;
    XT_XML, XT_SQL_VARIANT, XT_CLR, XT_HIERARCHYID :
    Begin
      { Types speciaux : representation hexadecimale brute }
      If DataLen = 0 Then
      Begin
        V.StrVal := '(empty)';
        V.IsNull := False;
        V.Valid  := True;
        Exit;
      End;
      V.BinLen := DataLen;
      V.StrVal := '0x';
      I := 0;
      While (I < DataLen) And (Ofs + I < MDF_PAGE_SIZE) And
            (Length(V.StrVal) + 2 <= MAX_SQL_VALUE_STR) Do
      Begin
        V.StrVal := V.StrVal + ByteToHex(Buf[Ofs + I]);
        Inc(I);
      End;
      If I < DataLen Then
        V.StrVal := V.StrVal + '...';
      V.IsNull := False;
      V.Valid  := True;
    End;
  Else
    { Type inconnu : hex dump }
    V.BinLen := DataLen;
    V.StrVal := '0x';
    I := 0;
    While (I < DataLen) And (Ofs + I < MDF_PAGE_SIZE) And
          (Length(V.StrVal) + 2 <= MAX_SQL_VALUE_STR) Do
    Begin
      V.StrVal := V.StrVal + ByteToHex(Buf[Ofs + I]);
      Inc(I);
    End;
    V.IsNull := False;
    V.Valid  := True;
  End;
End;

{ ---- Dispatch principal de decodage d une valeur SQL ---------- }
{ Decode les octets bruts a l offset Ofs dans Buf selon le type   }
{ xtype. DataLen est la longueur pour les types variables.        }
{ ColPrec et ColScale proviennent du catalogue systeme.           }

Procedure DecodeSqlValue(Const Buf : TMdfPageBuf;
                         Ofs : Word; DataLen : Word;
                         XT : Byte;
                         ColPrec, ColScale : Byte;
                         Var V : TSqlValue);
Begin
  Case SqlTypeCategory(XT) Of
    SQLCAT_INTEGER :
      DecodeInt(Buf, Ofs, XT, V);
    SQLCAT_DECIMAL :
      DecodeDecimal(Buf, Ofs, XT, ColPrec, ColScale, V);
    SQLCAT_STRING :
      DecodeString(Buf, Ofs, DataLen, XT, V);
    SQLCAT_DATETIME :
      DecodeDateTime(Buf, Ofs, XT, ColScale, V);
    SQLCAT_BINARY :
      DecodeBinary(Buf, Ofs, DataLen, XT, V);
    SQLCAT_SPECIAL :
      DecodeSpecial(Buf, Ofs, DataLen, XT, V);
  Else
    Begin
      InitSqlValue(V);
      V.XType    := XT;
      V.Category := SQLCAT_UNKNOWN;
      V.StrVal   := '(unknown xtype ' + IntToStr(XT) + ')';
      V.Valid    := True;
    End;
  End;
End;

{ ---- Convertir une valeur SQL en chaine Pascal --------------- }
{ Retourne la representation textuelle de la valeur.             }

Function SqlValueToStr(Const V : TSqlValue) : TSqlValueStr;
Var
  S     : TSqlValueStr;
  Ms, Md : String[4];
  Ds     : String[2];
  Whole  : LongInt;
  Frac4  : LongInt;
  FStr   : String[4];
Begin
  If V.IsNull Then
  Begin
    SqlValueToStr := 'NULL';
    Exit;
  End;

  If Not V.Valid Then
  Begin
    SqlValueToStr := '(invalid)';
    Exit;
  End;

  Case V.Category Of
    SQLCAT_INTEGER :
    Begin
      If V.XType = XT_BIT Then
      Begin
        If V.IntVal = 0 Then S := '0'
        Else S := '1';
      End
      Else If V.XType = XT_BIGINT Then
      Begin
        { BIGINT : afficher HiVal:IntVal si HiVal <> 0 }
        If V.HiVal <> 0 Then
          S := IntToStr(V.HiVal) + ':' + IntToStr(V.IntVal)
        Else
          S := IntToStr(V.IntVal);
      End
      Else
        S := IntToStr(V.IntVal);
    End;
    SQLCAT_DECIMAL :
    Begin
      Case V.XType Of
        XT_REAL, XT_FLOAT :
        Begin
          Str(V.FloatVal:0:6, S);
          { Supprimer les zeros de fin }
          While (Length(S) > 1) And (S[Length(S)] = '0') And
                (S[Length(S) - 1] <> '.') Do
            Dec(S[0]);
        End;
        XT_SMALLMONEY :
        Begin
          { SMALLMONEY = IntVal / 10000 }
          If V.IntVal < 0 Then
          Begin
            Whole := -(V.IntVal Div 10000);
            Frac4 := -(V.IntVal Mod 10000);
            Str(Frac4:4, FStr);
            While (Length(FStr) > 0) And (FStr[1] = ' ') Do
              Delete(FStr, 1, 1);
            While Length(FStr) < 4 Do FStr := '0' + FStr;
            S := '-' + IntToStr(Whole) + '.' + FStr;
          End
          Else
          Begin
            Whole := V.IntVal Div 10000;
            Frac4 := V.IntVal Mod 10000;
            Str(Frac4:4, FStr);
            While (Length(FStr) > 0) And (FStr[1] = ' ') Do
              Delete(FStr, 1, 1);
            While Length(FStr) < 4 Do FStr := '0' + FStr;
            S := IntToStr(Whole) + '.' + FStr;
          End;
        End;
        XT_MONEY :
        Begin
          { MONEY = HiVal:IntVal combine / 10000 }
          If V.HiVal <> 0 Then
            S := IntToStr(V.HiVal) + ':' + IntToStr(V.IntVal)
          Else
          Begin
            Whole := V.IntVal Div 10000;
            Frac4 := V.IntVal Mod 10000;
            If Frac4 < 0 Then Frac4 := -Frac4;
            Str(Frac4:4, FStr);
            While (Length(FStr) > 0) And (FStr[1] = ' ') Do
              Delete(FStr, 1, 1);
            While Length(FStr) < 4 Do FStr := '0' + FStr;
            S := IntToStr(Whole) + '.' + FStr;
          End;
        End;
        XT_DECIMAL, XT_NUMERIC :
        Begin
          If V.Sign = 0 Then S := '-'
          Else S := '';
          If V.HiVal <> 0 Then
            S := S + IntToStr(V.HiVal) + ':' + IntToStr(V.IntVal)
          Else
            S := S + IntToStr(V.IntVal);
          If V.Scale > 0 Then
            S := S + ' (scale=' + IntToStr(V.Scale) + ')';
        End;
      Else
        S := IntToStr(V.IntVal);
      End;
    End;
    SQLCAT_STRING :
      S := V.StrVal;
    SQLCAT_DATETIME :
    Begin
      { Formater YYYY-MM-DD HH:MM:SS }
      Str(V.Year:4, S);
      While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
      While Length(S) < 4 Do S := '0' + S;

      Str(V.Month:2, Ms);
      If Ms[1] = ' ' Then Ms[1] := '0';
      Str(V.Day:2, Ds);
      If Ds[1] = ' ' Then Ds[1] := '0';

      S := S + '-' + Ms + '-' + Ds;

      If (V.XType <> XT_DATE) Then
      Begin
        Str(V.Hour:2, Ms);
        If Ms[1] = ' ' Then Ms[1] := '0';
        Str(V.Minute:2, Md);
        If Md[1] = ' ' Then Md[1] := '0';
        Str(V.Second:2, Ds);
        If Ds[1] = ' ' Then Ds[1] := '0';
        S := S + ' ' + Ms + ':' + Md + ':' + Ds;
      End;
    End;
    SQLCAT_BINARY :
      S := V.StrVal;  { deja en format 0xHEX }
    SQLCAT_SPECIAL :
      S := V.StrVal;  { deja en format texte }
  Else
    S := V.StrVal;
  End;

  SqlValueToStr := S;
End;

{ ============================================================
  TODO 07 - TOKENISEUR SQL (LEXER) [IMPLEMENTE]
  ============================================================ }

{ ---- Initialiser le lexer depuis une chaine SQL -------------- }

Procedure LexInit(Const SQL : TString);
Begin
  LexSrc  := SQL;
  LexLen  := Length(SQL);
  LexPos  := 1;
  LexLine := 1;
  LexCol  := 1;
  LexCurTok.Kind := TOK_EOF;
  LexCurTok.Text := '';
  LexCurTok.Line := 1;
  LexCurTok.Col  := 1;
  LexCurTok.KwId := 0;
End;

{ ---- Caractere courant (ou #0 si fin) ----------------------- }

Function LexPeek : Char;
Begin
  If LexPos <= LexLen Then
    LexPeek := LexSrc[LexPos]
  Else
    LexPeek := #0;
End;

{ ---- Caractere suivant (LexPos+1, ou #0) -------------------- }

Function LexPeek2 : Char;
Begin
  If LexPos + 1 <= LexLen Then
    LexPeek2 := LexSrc[LexPos + 1]
  Else
    LexPeek2 := #0;
End;

{ ---- Avancer d un caractere ---------------------------------- }

Procedure LexAdvance;
Begin
  If LexPos <= LexLen Then
  Begin
    If LexSrc[LexPos] = #10 Then
    Begin
      Inc(LexLine);
      LexCol := 1;
    End
    Else
      Inc(LexCol);
    Inc(LexPos);
  End;
End;

{ ---- Sauter les espaces blancs ------------------------------- }

Procedure LexSkipWhite;
Var
  C : Char;
Begin
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else
      Break;
  End;
End;

{ ---- Sauter un commentaire ligne (-- ...) -------------------- }

Function LexSkipLineComment : Boolean;
Begin
  LexSkipLineComment := False;
  If (LexPeek = '-') And (LexPeek2 = '-') Then
  Begin
    LexAdvance; LexAdvance;  { sauter -- }
    While (LexPos <= LexLen) And (LexSrc[LexPos] <> #10) Do
      LexAdvance;
    LexSkipLineComment := True;
  End;
End;

{ ---- Sauter un commentaire bloc (* ... *) ------------------- }

Function LexSkipBlockComment : Boolean;
Var
  Depth : Integer;
Begin
  LexSkipBlockComment := False;
  If (LexPeek = '/') And (LexPeek2 = '*') Then
  Begin
    LexAdvance; LexAdvance;  { sauter /* }
    Depth := 1;
    While (LexPos <= LexLen) And (Depth > 0) Do
    Begin
      If (LexSrc[LexPos] = '/') And
         (LexPos + 1 <= LexLen) And (LexSrc[LexPos + 1] = '*') Then
      Begin
        Inc(Depth);
        LexAdvance; LexAdvance;
      End
      Else If (LexSrc[LexPos] = '*') And
              (LexPos + 1 <= LexLen) And (LexSrc[LexPos + 1] = '/') Then
      Begin
        Dec(Depth);
        LexAdvance; LexAdvance;
      End
      Else
        LexAdvance;
    End;
    LexSkipBlockComment := True;
  End;
End;

{ ---- Sauter espaces et commentaires -------------------------- }

Procedure LexSkipWhiteAndComments;
Var
  Again : Boolean;
Begin
  Repeat
    LexSkipWhite;
    Again := False;
    If LexSkipLineComment Then Again := True;
    If LexSkipBlockComment Then Again := True;
  Until Not Again;
End;

{ ---- Scanner un identificateur ------------------------------- }
{ [a-zA-Z_][a-zA-Z0-9_@#$]*                                      }

Procedure LexScanIdent;
Var
  C : Char;
Begin
  LexCurTok.Kind := TOK_IDENT;
  LexCurTok.Text := '';
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Or (C = '@') Or (C = '#') Or (C = '$') Then
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End
    Else
      Break;
  End;
End;

{ ---- Scanner un identificateur delimite [nom] ou "nom" ------- }

Procedure LexScanDelimIdent(Delim : Char);
Var
  CloseC : Char;
  C      : Char;
Begin
  LexCurTok.Kind := TOK_DELIM_IDENT;
  LexCurTok.Text := '';
  If Delim = '[' Then
    CloseC := ']'
  Else
    CloseC := Delim;  { " ... " }

  LexAdvance;  { sauter le delimiteur ouvrant }
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If C = CloseC Then
    Begin
      { Double delimiteur = echappement }
      If (LexPos + 1 <= LexLen) And (LexSrc[LexPos + 1] = CloseC) Then
      Begin
        If Length(LexCurTok.Text) < MAX_TOK_LEN Then
          LexCurTok.Text := LexCurTok.Text + C;
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexAdvance;  { sauter le delimiteur fermant }
        Break;
      End;
    End
    Else
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End;
  End;
End;

{ ---- Scanner un nombre (entier, flottant, hex) --------------- }
{ 123, 1.5, 1E3, 1.5E-2, 0x1A2B                                 }

Procedure LexScanNumber;
Var
  C      : Char;
  HasDot : Boolean;
  HasExp : Boolean;
Begin
  LexCurTok.Kind := TOK_NUMBER;
  LexCurTok.Text := '';
  HasDot := False;
  HasExp := False;

  { Cas special : 0x... (hexadecimal) }
  If (LexSrc[LexPos] = '0') And
     (LexPos + 1 <= LexLen) And
     ((LexSrc[LexPos + 1] = 'x') Or (LexSrc[LexPos + 1] = 'X')) Then
  Begin
    LexCurTok.Kind := TOK_HEX;
    LexCurTok.Text := '0x';
    LexAdvance; LexAdvance;  { sauter 0x }
    While LexPos <= LexLen Do
    Begin
      C := LexSrc[LexPos];
      If ((C >= '0') And (C <= '9')) Or
         ((C >= 'A') And (C <= 'F')) Or
         ((C >= 'a') And (C <= 'f')) Then
      Begin
        If Length(LexCurTok.Text) < MAX_TOK_LEN Then
          LexCurTok.Text := LexCurTok.Text + C;
        LexAdvance;
      End
      Else
        Break;
    End;
    Exit;
  End;

  { Nombre decimal normal }
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If (C >= '0') And (C <= '9') Then
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End
    Else If (C = '.') And (Not HasDot) And (Not HasExp) Then
    Begin
      { Verifier que c est un point decimal, pas un separateur }
      If (LexPos + 1 <= LexLen) And
         (LexSrc[LexPos + 1] >= '0') And (LexSrc[LexPos + 1] <= '9') Then
      Begin
        HasDot := True;
        LexCurTok.Kind := TOK_FLOAT;
        If Length(LexCurTok.Text) < MAX_TOK_LEN Then
          LexCurTok.Text := LexCurTok.Text + C;
        LexAdvance;
      End
      Else
        Break;
    End
    Else If ((C = 'E') Or (C = 'e')) And (Not HasExp) Then
    Begin
      HasExp := True;
      LexCurTok.Kind := TOK_FLOAT;
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
      { Signe optionnel apres E }
      If (LexPos <= LexLen) And
         ((LexSrc[LexPos] = '+') Or (LexSrc[LexPos] = '-')) Then
      Begin
        If Length(LexCurTok.Text) < MAX_TOK_LEN Then
          LexCurTok.Text := LexCurTok.Text + LexSrc[LexPos];
        LexAdvance;
      End;
    End
    Else
      Break;
  End;
End;

{ ---- Scanner une chaine 'texte' ------------------------------ }
{ Apostrophe doublee '' = echappement                              }

Procedure LexScanString;
Var
  C : Char;
Begin
  LexCurTok.Kind := TOK_STRING;
  LexCurTok.Text := '';
  LexAdvance;  { sauter le ' ouvrant }
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If C = '''' Then
    Begin
      { Apostrophe doublee ? }
      If (LexPos + 1 <= LexLen) And (LexSrc[LexPos + 1] = '''') Then
      Begin
        If Length(LexCurTok.Text) < MAX_TOK_LEN Then
          LexCurTok.Text := LexCurTok.Text + '''';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexAdvance;  { sauter le ' fermant }
        Break;
      End;
    End
    Else
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End;
  End;
End;

{ ---- Scanner une variable @nom ou @@nom --------------------- }

Procedure LexScanVariable;
Var
  C : Char;
Begin
  LexCurTok.Kind := TOK_VARIABLE;
  LexCurTok.Text := '@';
  LexAdvance;  { sauter le premier @ }
  { Double @@ pour les variables globales }
  If (LexPos <= LexLen) And (LexSrc[LexPos] = '@') Then
  Begin
    LexCurTok.Text := '@@';
    LexAdvance;
  End;
  { Lire le nom de la variable }
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Or (C = '#') Or (C = '$') Then
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End
    Else
      Break;
  End;
  { Si seul @ sans nom, c est TOK_AT }
  If LexCurTok.Text = '@' Then
    LexCurTok.Kind := TOK_AT;
End;

{ ---- Scanner un objet temporaire #nom ou ##nom --------------- }

Procedure LexScanTempObj;
Var
  C : Char;
Begin
  LexCurTok.Kind := TOK_TEMPOBJ;
  LexCurTok.Text := '#';
  LexAdvance;  { sauter le premier # }
  { Double ## pour les tables temporaires globales }
  If (LexPos <= LexLen) And (LexSrc[LexPos] = '#') Then
  Begin
    LexCurTok.Text := '##';
    LexAdvance;
  End;
  While LexPos <= LexLen Do
  Begin
    C := LexSrc[LexPos];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Then
    Begin
      If Length(LexCurTok.Text) < MAX_TOK_LEN Then
        LexCurTok.Text := LexCurTok.Text + C;
      LexAdvance;
    End
    Else
      Break;
  End;
End;

{ ---- Declaration forward de IsKeyword (TODO 08) -------------- }

Function IsKeyword(Const S : TString) : Integer; Forward;

{ ---- Lire le prochain token SQL ------------------------------ }

Procedure LexNextToken;
Var
  C, C2 : Char;
  KwId  : Integer;
Begin
  LexSkipWhiteAndComments;

  LexCurTok.Line := LexLine;
  LexCurTok.Col  := LexCol;
  LexCurTok.Text := '';
  LexCurTok.Kind := TOK_EOF;
  LexCurTok.KwId := 0;

  If LexPos > LexLen Then Exit;

  C := LexSrc[LexPos];
  If LexPos + 1 <= LexLen Then
    C2 := LexSrc[LexPos + 1]
  Else
    C2 := #0;

  { Identificateur ou mot-cle }
  If ((C >= 'A') And (C <= 'Z')) Or
     ((C >= 'a') And (C <= 'z')) Or (C = '_') Then
  Begin
    { N'...' = chaine Unicode }
    If ((C = 'N') Or (C = 'n')) And (C2 = '''') Then
    Begin
      LexAdvance;  { sauter le N }
      LexScanString;
      LexCurTok.Kind := TOK_NSTRING;
    End
    Else
    Begin
      LexScanIdent;
      { Verifier si l identificateur est un mot-cle SQL Server }
      KwId := IsKeyword(LexCurTok.Text);
      If KwId > 0 Then
      Begin
        LexCurTok.Kind := TOK_KEYWORD;
        LexCurTok.KwId := KwId;
      End;
    End;
    Exit;
  End;

  { Nombre }
  If (C >= '0') And (C <= '9') Then
  Begin
    LexScanNumber;
    Exit;
  End;

  { Chaine simple 'texte' }
  If C = '''' Then
  Begin
    LexScanString;
    Exit;
  End;

  { Identificateur delimite [nom] }
  If C = '[' Then
  Begin
    LexScanDelimIdent('[');
    Exit;
  End;

  { Identificateur delimite "nom" }
  If C = '"' Then
  Begin
    LexScanDelimIdent('"');
    Exit;
  End;

  { Variable @nom ou @@nom }
  If C = '@' Then
  Begin
    LexScanVariable;
    Exit;
  End;

  { Objet temporaire #nom ou ##nom }
  If C = '#' Then
  Begin
    LexScanTempObj;
    Exit;
  End;

  { Parametre ? }
  If C = '?' Then
  Begin
    LexCurTok.Kind := TOK_PARAM;
    LexCurTok.Text := '?';
    LexAdvance;
    Exit;
  End;

  { Operateurs composes et simples }
  Case C Of
    '+' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_PLUS_EQ;
        LexCurTok.Text := '+=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_PLUS;
        LexCurTok.Text := '+';
        LexAdvance;
      End;
    End;
    '-' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_MINUS_EQ;
        LexCurTok.Text := '-=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_MINUS;
        LexCurTok.Text := '-';
        LexAdvance;
      End;
    End;
    '*' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_STAR_EQ;
        LexCurTok.Text := '*=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_STAR;
        LexCurTok.Text := '*';
        LexAdvance;
      End;
    End;
    '/' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_SLASH_EQ;
        LexCurTok.Text := '/=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_SLASH;
        LexCurTok.Text := '/';
        LexAdvance;
      End;
    End;
    '%' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_PERCENT_EQ;
        LexCurTok.Text := '%=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_PERCENT;
        LexCurTok.Text := '%';
        LexAdvance;
      End;
    End;
    '=' :
    Begin
      LexCurTok.Kind := TOK_EQ;
      LexCurTok.Text := '=';
      LexAdvance;
    End;
    '<' :
    Begin
      If C2 = '>' Then
      Begin
        LexCurTok.Kind := TOK_NE;
        LexCurTok.Text := '<>';
        LexAdvance; LexAdvance;
      End
      Else If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_LE;
        LexCurTok.Text := '<=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_LT;
        LexCurTok.Text := '<';
        LexAdvance;
      End;
    End;
    '>' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_GE;
        LexCurTok.Text := '>=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_GT;
        LexCurTok.Text := '>';
        LexAdvance;
      End;
    End;
    '!' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_NE;
        LexCurTok.Text := '!=';
        LexAdvance; LexAdvance;
      End
      Else If C2 = '<' Then
      Begin
        LexCurTok.Kind := TOK_BANG_LT;
        LexCurTok.Text := '!<';
        LexAdvance; LexAdvance;
      End
      Else If C2 = '>' Then
      Begin
        LexCurTok.Kind := TOK_BANG_GT;
        LexCurTok.Text := '!>';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        { ! seul - traiter comme erreur, avancer }
        LexCurTok.Kind := TOK_EOF;
        LexCurTok.Text := '!';
        LexAdvance;
      End;
    End;
    '&' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_AMP_EQ;
        LexCurTok.Text := '&=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_AMPERSAND;
        LexCurTok.Text := '&';
        LexAdvance;
      End;
    End;
    '|' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_PIPE_EQ;
        LexCurTok.Text := '|=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_PIPE;
        LexCurTok.Text := '|';
        LexAdvance;
      End;
    End;
    '^' :
    Begin
      If C2 = '=' Then
      Begin
        LexCurTok.Kind := TOK_CARET_EQ;
        LexCurTok.Text := '^=';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_CARET;
        LexCurTok.Text := '^';
        LexAdvance;
      End;
    End;
    '~' :
    Begin
      LexCurTok.Kind := TOK_TILDE;
      LexCurTok.Text := '~';
      LexAdvance;
    End;
    '(' :
    Begin
      LexCurTok.Kind := TOK_LPAREN;
      LexCurTok.Text := '(';
      LexAdvance;
    End;
    ')' :
    Begin
      LexCurTok.Kind := TOK_RPAREN;
      LexCurTok.Text := ')';
      LexAdvance;
    End;
    ',' :
    Begin
      LexCurTok.Kind := TOK_COMMA;
      LexCurTok.Text := ',';
      LexAdvance;
    End;
    '.' :
    Begin
      { .123 = nombre flottant commencant par point }
      If (C2 >= '0') And (C2 <= '9') Then
      Begin
        LexCurTok.Kind := TOK_FLOAT;
        LexCurTok.Text := '.';
        LexAdvance;  { sauter le point }
        While (LexPos <= LexLen) And
              (LexSrc[LexPos] >= '0') And (LexSrc[LexPos] <= '9') Do
        Begin
          If Length(LexCurTok.Text) < MAX_TOK_LEN Then
            LexCurTok.Text := LexCurTok.Text + LexSrc[LexPos];
          LexAdvance;
        End;
        { Exposant optionnel }
        If (LexPos <= LexLen) And
           ((LexSrc[LexPos] = 'E') Or (LexSrc[LexPos] = 'e')) Then
        Begin
          If Length(LexCurTok.Text) < MAX_TOK_LEN Then
            LexCurTok.Text := LexCurTok.Text + LexSrc[LexPos];
          LexAdvance;
          If (LexPos <= LexLen) And
             ((LexSrc[LexPos] = '+') Or (LexSrc[LexPos] = '-')) Then
          Begin
            If Length(LexCurTok.Text) < MAX_TOK_LEN Then
              LexCurTok.Text := LexCurTok.Text + LexSrc[LexPos];
            LexAdvance;
          End;
          While (LexPos <= LexLen) And
                (LexSrc[LexPos] >= '0') And (LexSrc[LexPos] <= '9') Do
          Begin
            If Length(LexCurTok.Text) < MAX_TOK_LEN Then
              LexCurTok.Text := LexCurTok.Text + LexSrc[LexPos];
            LexAdvance;
          End;
        End;
      End
      Else
      Begin
        LexCurTok.Kind := TOK_DOT;
        LexCurTok.Text := '.';
        LexAdvance;
      End;
    End;
    ';' :
    Begin
      LexCurTok.Kind := TOK_SEMICOL;
      LexCurTok.Text := ';';
      LexAdvance;
    End;
    ':' :
    Begin
      If C2 = ':' Then
      Begin
        LexCurTok.Kind := TOK_COLON;
        LexCurTok.Text := '::';
        LexAdvance; LexAdvance;
      End
      Else
      Begin
        { : seul - avancer }
        LexCurTok.Kind := TOK_COLON;
        LexCurTok.Text := ':';
        LexAdvance;
      End;
    End;
  Else
    { Caractere inconnu : avancer }
    LexCurTok.Kind := TOK_EOF;
    LexCurTok.Text := C;
    LexAdvance;
  End;
End;

{ ---- Nom textuel d un type de token (debug) ------------------ }

Function TokKindName(K : Byte) : TString;
Begin
  Case K Of
    TOK_EOF         : TokKindName := 'EOF';
    TOK_IDENT       : TokKindName := 'IDENT';
    TOK_NUMBER      : TokKindName := 'NUMBER';
    TOK_FLOAT       : TokKindName := 'FLOAT';
    TOK_STRING      : TokKindName := 'STRING';
    TOK_NSTRING     : TokKindName := 'NSTRING';
    TOK_HEX         : TokKindName := 'HEX';
    TOK_VARIABLE    : TokKindName := 'VARIABLE';
    TOK_TEMPOBJ     : TokKindName := 'TEMPOBJ';
    TOK_PARAM       : TokKindName := 'PARAM';
    TOK_PLUS        : TokKindName := '+';
    TOK_MINUS       : TokKindName := '-';
    TOK_STAR        : TokKindName := '*';
    TOK_SLASH       : TokKindName := '/';
    TOK_PERCENT     : TokKindName := '%';
    TOK_EQ          : TokKindName := '=';
    TOK_NE          : TokKindName := '<>';
    TOK_LT          : TokKindName := '<';
    TOK_GT          : TokKindName := '>';
    TOK_LE          : TokKindName := '<=';
    TOK_GE          : TokKindName := '>=';
    TOK_LPAREN      : TokKindName := '(';
    TOK_RPAREN      : TokKindName := ')';
    TOK_COMMA       : TokKindName := ',';
    TOK_DOT         : TokKindName := '.';
    TOK_SEMICOL     : TokKindName := ';';
    TOK_AT          : TokKindName := '@';
    TOK_COLON       : TokKindName := '::';
    TOK_AMPERSAND   : TokKindName := '&';
    TOK_PIPE        : TokKindName := '|';
    TOK_CARET       : TokKindName := '^';
    TOK_TILDE       : TokKindName := '~';
    TOK_BANG_LT     : TokKindName := '!<';
    TOK_BANG_GT     : TokKindName := '!>';
    TOK_PLUS_EQ     : TokKindName := '+=';
    TOK_MINUS_EQ    : TokKindName := '-=';
    TOK_STAR_EQ     : TokKindName := '*=';
    TOK_SLASH_EQ    : TokKindName := '/=';
    TOK_PERCENT_EQ  : TokKindName := '%=';
    TOK_AMP_EQ      : TokKindName := '&=';
    TOK_PIPE_EQ     : TokKindName := '|=';
    TOK_CARET_EQ    : TokKindName := '^=';
    TOK_DELIM_IDENT : TokKindName := 'DELIM_IDENT';
    TOK_KEYWORD     : TokKindName := 'KEYWORD';
  Else
    TokKindName := '?';
  End;
End;

{ ============================================================
  TODO 08 - RECONNAISSANCE DES MOTS-CLES SQL SERVER [IMPLEMENTE]
  ============================================================ }

{ ---- Table des mots-cles SQL Server -------------------------- }
{ Retourne l ID du mot-cle (KW_xxx, >= 1) ou 0 si non reconnu.   }
{ La comparaison est insensible a la casse.                       }

Function IsKeyword(Const S : TString) : Integer;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  { -- DML -- }
  If U = 'SELECT'       Then Begin IsKeyword := KW_SELECT;      Exit; End;
  If U = 'INSERT'       Then Begin IsKeyword := KW_INSERT;      Exit; End;
  If U = 'UPDATE'       Then Begin IsKeyword := KW_UPDATE;      Exit; End;
  If U = 'DELETE'       Then Begin IsKeyword := KW_DELETE;      Exit; End;
  If U = 'MERGE'        Then Begin IsKeyword := KW_MERGE;       Exit; End;
  If U = 'TRUNCATE'     Then Begin IsKeyword := KW_TRUNCATE;    Exit; End;
  If U = 'BULK'         Then Begin IsKeyword := KW_BULK;        Exit; End;
  { -- DDL -- }
  If U = 'CREATE'       Then Begin IsKeyword := KW_CREATE;      Exit; End;
  If U = 'ALTER'        Then Begin IsKeyword := KW_ALTER;       Exit; End;
  If U = 'DROP'         Then Begin IsKeyword := KW_DROP;        Exit; End;
  If U = 'TABLE'        Then Begin IsKeyword := KW_TABLE;       Exit; End;
  If U = 'VIEW'         Then Begin IsKeyword := KW_VIEW;        Exit; End;
  If U = 'INDEX'        Then Begin IsKeyword := KW_INDEX;       Exit; End;
  If U = 'PROCEDURE'    Then Begin IsKeyword := KW_PROCEDURE;   Exit; End;
  If U = 'FUNCTION'     Then Begin IsKeyword := KW_FUNCTION;    Exit; End;
  If U = 'TRIGGER'      Then Begin IsKeyword := KW_TRIGGER;     Exit; End;
  If U = 'DATABASE'     Then Begin IsKeyword := KW_DATABASE;    Exit; End;
  If U = 'SCHEMA'       Then Begin IsKeyword := KW_SCHEMA;      Exit; End;
  If U = 'SEQUENCE'     Then Begin IsKeyword := KW_SEQUENCE;    Exit; End;
  If U = 'TYPE'         Then Begin IsKeyword := KW_TYPE;        Exit; End;
  If U = 'SYNONYM'      Then Begin IsKeyword := KW_SYNONYM;     Exit; End;
  { -- Clauses -- }
  If U = 'FROM'         Then Begin IsKeyword := KW_FROM;        Exit; End;
  If U = 'WHERE'        Then Begin IsKeyword := KW_WHERE;       Exit; End;
  If U = 'GROUP'        Then Begin IsKeyword := KW_GROUP;       Exit; End;
  If U = 'HAVING'       Then Begin IsKeyword := KW_HAVING;      Exit; End;
  If U = 'ORDER'        Then Begin IsKeyword := KW_ORDER;       Exit; End;
  If U = 'BY'           Then Begin IsKeyword := KW_BY;          Exit; End;
  If U = 'JOIN'         Then Begin IsKeyword := KW_JOIN;        Exit; End;
  If U = 'INNER'        Then Begin IsKeyword := KW_INNER;       Exit; End;
  If U = 'LEFT'         Then Begin IsKeyword := KW_LEFT;        Exit; End;
  If U = 'RIGHT'        Then Begin IsKeyword := KW_RIGHT;       Exit; End;
  If U = 'FULL'         Then Begin IsKeyword := KW_FULL;        Exit; End;
  If U = 'OUTER'        Then Begin IsKeyword := KW_OUTER;       Exit; End;
  If U = 'CROSS'        Then Begin IsKeyword := KW_CROSS;       Exit; End;
  If U = 'ON'           Then Begin IsKeyword := KW_ON;          Exit; End;
  If U = 'AS'           Then Begin IsKeyword := KW_AS;          Exit; End;
  If U = 'INTO'         Then Begin IsKeyword := KW_INTO;        Exit; End;
  If U = 'VALUES'       Then Begin IsKeyword := KW_VALUES;      Exit; End;
  If U = 'SET'          Then Begin IsKeyword := KW_SET;         Exit; End;
  If U = 'TOP'          Then Begin IsKeyword := KW_TOP;         Exit; End;
  If U = 'DISTINCT'     Then Begin IsKeyword := KW_DISTINCT;    Exit; End;
  If U = 'ALL'          Then Begin IsKeyword := KW_ALL;         Exit; End;
  If U = 'UNION'        Then Begin IsKeyword := KW_UNION;       Exit; End;
  If U = 'INTERSECT'    Then Begin IsKeyword := KW_INTERSECT;   Exit; End;
  If U = 'EXCEPT'       Then Begin IsKeyword := KW_EXCEPT;      Exit; End;
  If U = 'WITH'         Then Begin IsKeyword := KW_WITH;        Exit; End;
  If U = 'OVER'         Then Begin IsKeyword := KW_OVER;        Exit; End;
  If U = 'PARTITION'    Then Begin IsKeyword := KW_PARTITION;   Exit; End;
  If U = 'ROWS'         Then Begin IsKeyword := KW_ROWS;        Exit; End;
  If U = 'RANGE'        Then Begin IsKeyword := KW_RANGE;       Exit; End;
  { Window functions (TODO 18) }
  If U = 'UNBOUNDED'    Then Begin IsKeyword := KW_UNBOUNDED;   Exit; End;
  If U = 'PRECEDING'    Then Begin IsKeyword := KW_PRECEDING;   Exit; End;
  If U = 'FOLLOWING'    Then Begin IsKeyword := KW_FOLLOWING;    Exit; End;
  If U = 'BETWEEN'      Then Begin IsKeyword := KW_BETWEEN;     Exit; End;
  If U = 'AND'          Then Begin IsKeyword := KW_AND;         Exit; End;
  If U = 'OR'           Then Begin IsKeyword := KW_OR;          Exit; End;
  If U = 'NOT'          Then Begin IsKeyword := KW_NOT;         Exit; End;
  If U = 'IN'           Then Begin IsKeyword := KW_IN;          Exit; End;
  If U = 'EXISTS'       Then Begin IsKeyword := KW_EXISTS;      Exit; End;
  If U = 'LIKE'         Then Begin IsKeyword := KW_LIKE;        Exit; End;
  If U = 'IS'           Then Begin IsKeyword := KW_IS;          Exit; End;
  If U = 'NULL'         Then Begin IsKeyword := KW_NULL;        Exit; End;
  If U = 'CASE'         Then Begin IsKeyword := KW_CASE;        Exit; End;
  If U = 'WHEN'         Then Begin IsKeyword := KW_WHEN;        Exit; End;
  If U = 'THEN'         Then Begin IsKeyword := KW_THEN;        Exit; End;
  If U = 'ELSE'         Then Begin IsKeyword := KW_ELSE;        Exit; End;
  If U = 'END'          Then Begin IsKeyword := KW_END;         Exit; End;
  If U = 'CAST'         Then Begin IsKeyword := KW_CAST;        Exit; End;
  If U = 'CONVERT'      Then Begin IsKeyword := KW_CONVERT;     Exit; End;
  If U = 'COLLATE'      Then Begin IsKeyword := KW_COLLATE;     Exit; End;
  If U = 'PIVOT'        Then Begin IsKeyword := KW_PIVOT;       Exit; End;
  If U = 'UNPIVOT'      Then Begin IsKeyword := KW_UNPIVOT;     Exit; End;
  If U = 'APPLY'        Then Begin IsKeyword := KW_APPLY;       Exit; End;
  If U = 'OFFSET'       Then Begin IsKeyword := KW_OFFSET;      Exit; End;
  If U = 'FETCH'        Then Begin IsKeyword := KW_FETCH;       Exit; End;
  If U = 'NEXT'         Then Begin IsKeyword := KW_NEXT;        Exit; End;
  If U = 'ONLY'         Then Begin IsKeyword := KW_ONLY;        Exit; End;
  If U = 'PERCENT'      Then Begin IsKeyword := KW_PERCENT;     Exit; End;
  If U = 'TIES'         Then Begin IsKeyword := KW_TIES;        Exit; End;
  { -- Controle -- }
  If U = 'BEGIN'        Then Begin IsKeyword := KW_BEGIN;       Exit; End;
  If U = 'IF'           Then Begin IsKeyword := KW_IF;          Exit; End;
  If U = 'WHILE'        Then Begin IsKeyword := KW_WHILE;       Exit; End;
  If U = 'BREAK'        Then Begin IsKeyword := KW_BREAK;       Exit; End;
  If U = 'CONTINUE'     Then Begin IsKeyword := KW_CONTINUE;    Exit; End;
  If U = 'GOTO'         Then Begin IsKeyword := KW_GOTO;        Exit; End;
  If U = 'RETURN'       Then Begin IsKeyword := KW_RETURN;      Exit; End;
  If U = 'WAITFOR'      Then Begin IsKeyword := KW_WAITFOR;     Exit; End;
  If U = 'THROW'        Then Begin IsKeyword := KW_THROW;       Exit; End;
  If U = 'TRY'          Then Begin IsKeyword := KW_TRY;         Exit; End;
  If U = 'CATCH'        Then Begin IsKeyword := KW_CATCH;       Exit; End;
  If U = 'RAISERROR'    Then Begin IsKeyword := KW_RAISERROR;   Exit; End;
  If U = 'PRINT'        Then Begin IsKeyword := KW_PRINT;       Exit; End;
  If U = 'EXEC'         Then Begin IsKeyword := KW_EXEC;        Exit; End;
  If U = 'EXECUTE'      Then Begin IsKeyword := KW_EXECUTE;     Exit; End;
  If U = 'DECLARE'      Then Begin IsKeyword := KW_DECLARE;     Exit; End;
  If U = 'USE'          Then Begin IsKeyword := KW_USE;         Exit; End;
  If U = 'GO'           Then Begin IsKeyword := KW_GO;          Exit; End;
  { -- Transaction -- }
  If U = 'COMMIT'       Then Begin IsKeyword := KW_COMMIT;      Exit; End;
  If U = 'ROLLBACK'     Then Begin IsKeyword := KW_ROLLBACK;    Exit; End;
  If U = 'SAVE'         Then Begin IsKeyword := KW_SAVE;        Exit; End;
  If U = 'TRANSACTION'  Then Begin IsKeyword := KW_TRANSACTION; Exit; End;
  { -- DCL -- }
  If U = 'GRANT'        Then Begin IsKeyword := KW_GRANT;       Exit; End;
  If U = 'REVOKE'       Then Begin IsKeyword := KW_REVOKE;      Exit; End;
  If U = 'DENY'         Then Begin IsKeyword := KW_DENY;        Exit; End;
  { TODO 11 }
  If U = 'OUTPUT'       Then Begin IsKeyword := KW_OUTPUT;      Exit; End;
  If U = 'USING'        Then Begin IsKeyword := KW_USING;       Exit; End;

  { -- DDL (TODO 12) -- }
  If U = 'COLUMN'       Then Begin IsKeyword := KW_COLUMN;       Exit; End;
  If U = 'PRIMARY'      Then Begin IsKeyword := KW_PRIMARY;      Exit; End;
  If U = 'KEY'          Then Begin IsKeyword := KW_KEY;          Exit; End;
  If U = 'FOREIGN'      Then Begin IsKeyword := KW_FOREIGN;      Exit; End;
  If U = 'REFERENCES'   Then Begin IsKeyword := KW_REFERENCES;   Exit; End;
  If U = 'UNIQUE'       Then Begin IsKeyword := KW_UNIQUE;       Exit; End;
  If U = 'CLUSTERED'    Then Begin IsKeyword := KW_CLUSTERED;    Exit; End;
  If U = 'NONCLUSTERED' Then Begin IsKeyword := KW_NONCLUSTERED; Exit; End;
  If U = 'IDENTITY'     Then Begin IsKeyword := KW_IDENTITY;     Exit; End;
  If U = 'CHECK'        Then Begin IsKeyword := KW_CHECK;        Exit; End;
  If U = 'CONSTRAINT'   Then Begin IsKeyword := KW_CONSTRAINT;   Exit; End;
  If U = 'DEFAULT'      Then Begin IsKeyword := KW_DEFAULT;      Exit; End;
  If U = 'ADD'          Then Begin IsKeyword := KW_ADD;          Exit; End;
  If U = 'INCLUDE'      Then Begin IsKeyword := KW_INCLUDE;      Exit; End;
  If U = 'REBUILD'      Then Begin IsKeyword := KW_REBUILD;      Exit; End;
  If U = 'REORGANIZE'   Then Begin IsKeyword := KW_REORGANIZE;   Exit; End;
  If U = 'DISABLE'      Then Begin IsKeyword := KW_DISABLE;      Exit; End;
  If U = 'ENABLE'       Then Begin IsKeyword := KW_ENABLE;       Exit; End;
  If U = 'SCHEMABINDING' Then Begin IsKeyword := KW_SCHEMABINDING; Exit; End;
  If U = 'AFTER'        Then Begin IsKeyword := KW_AFTER;        Exit; End;
  If U = 'INSTEAD'      Then Begin IsKeyword := KW_INSTEAD;      Exit; End;
  If U = 'FOR'          Then Begin IsKeyword := KW_FOR;          Exit; End;
  If U = 'RETURNS'      Then Begin IsKeyword := KW_RETURNS;      Exit; End;
  If U = 'ASC'          Then Begin IsKeyword := KW_ASC;          Exit; End;
  If U = 'DESC'         Then Begin IsKeyword := KW_DESC;         Exit; End;
  If U = 'OF'           Then Begin IsKeyword := KW_OF;           Exit; End;
  If U = 'OPTION'       Then Begin IsKeyword := KW_OPTION;       Exit; End;
  If U = 'FILLFACTOR'   Then Begin IsKeyword := KW_FILLFACTOR;   Exit; End;
  If U = 'PAD_INDEX'    Then Begin IsKeyword := KW_PAD_INDEX;    Exit; End;
  If U = 'NORECOMPUTE'  Then Begin IsKeyword := KW_NORECOMPUTE;  Exit; End;
  If U = 'NO'           Then Begin IsKeyword := KW_NO;           Exit; End;
  If U = 'LOGIN'        Then Begin IsKeyword := KW_LOGIN;        Exit; End;
  If U = 'USER'         Then Begin IsKeyword := KW_USER;         Exit; End;
  If U = 'ROLE'         Then Begin IsKeyword := KW_ROLE;         Exit; End;
  If U = 'MEMBER'       Then Begin IsKeyword := KW_MEMBER;       Exit; End;

  { -- T-SQL controle (TODO 13) -- }
  If U = 'DELAY'        Then Begin IsKeyword := KW_DELAY;        Exit; End;
  If U = 'TIME'         Then Begin IsKeyword := KW_TIME;         Exit; End;

  { -- DCL (TODO 14) -- }
  If U = 'TO'           Then Begin IsKeyword := KW_TO;           Exit; End;
  If U = 'CONTROL'      Then Begin IsKeyword := KW_CONTROL;      Exit; End;
  If U = 'DEFINITION'   Then Begin IsKeyword := KW_DEFINITION;   Exit; End;
  If U = 'TAKE'         Then Begin IsKeyword := KW_TAKE;         Exit; End;
  If U = 'OWNERSHIP'    Then Begin IsKeyword := KW_OWNERSHIP;    Exit; End;
  If U = 'PUBLIC'       Then Begin IsKeyword := KW_PUBLIC;       Exit; End;

  IsKeyword := 0;
End;

{ ---- Nom textuel d un mot-cle (debug) ----------------------- }

Function KeywordName(KwId : Integer) : TString;
Begin
  Case KwId Of
    KW_SELECT       : KeywordName := 'SELECT';
    KW_INSERT       : KeywordName := 'INSERT';
    KW_UPDATE       : KeywordName := 'UPDATE';
    KW_DELETE       : KeywordName := 'DELETE';
    KW_MERGE        : KeywordName := 'MERGE';
    KW_TRUNCATE     : KeywordName := 'TRUNCATE';
    KW_BULK         : KeywordName := 'BULK';
    KW_CREATE       : KeywordName := 'CREATE';
    KW_ALTER        : KeywordName := 'ALTER';
    KW_DROP         : KeywordName := 'DROP';
    KW_TABLE        : KeywordName := 'TABLE';
    KW_VIEW         : KeywordName := 'VIEW';
    KW_INDEX        : KeywordName := 'INDEX';
    KW_PROCEDURE    : KeywordName := 'PROCEDURE';
    KW_FUNCTION     : KeywordName := 'FUNCTION';
    KW_TRIGGER      : KeywordName := 'TRIGGER';
    KW_DATABASE     : KeywordName := 'DATABASE';
    KW_SCHEMA       : KeywordName := 'SCHEMA';
    KW_SEQUENCE     : KeywordName := 'SEQUENCE';
    KW_TYPE         : KeywordName := 'TYPE';
    KW_SYNONYM      : KeywordName := 'SYNONYM';
    KW_FROM         : KeywordName := 'FROM';
    KW_WHERE        : KeywordName := 'WHERE';
    KW_GROUP        : KeywordName := 'GROUP';
    KW_HAVING       : KeywordName := 'HAVING';
    KW_ORDER        : KeywordName := 'ORDER';
    KW_BY           : KeywordName := 'BY';
    KW_JOIN         : KeywordName := 'JOIN';
    KW_INNER        : KeywordName := 'INNER';
    KW_LEFT         : KeywordName := 'LEFT';
    KW_RIGHT        : KeywordName := 'RIGHT';
    KW_FULL         : KeywordName := 'FULL';
    KW_OUTER        : KeywordName := 'OUTER';
    KW_CROSS        : KeywordName := 'CROSS';
    KW_ON           : KeywordName := 'ON';
    KW_AS           : KeywordName := 'AS';
    KW_INTO         : KeywordName := 'INTO';
    KW_VALUES       : KeywordName := 'VALUES';
    KW_SET          : KeywordName := 'SET';
    KW_TOP          : KeywordName := 'TOP';
    KW_DISTINCT     : KeywordName := 'DISTINCT';
    KW_ALL          : KeywordName := 'ALL';
    KW_UNION        : KeywordName := 'UNION';
    KW_INTERSECT    : KeywordName := 'INTERSECT';
    KW_EXCEPT       : KeywordName := 'EXCEPT';
    KW_WITH         : KeywordName := 'WITH';
    KW_OVER         : KeywordName := 'OVER';
    KW_PARTITION    : KeywordName := 'PARTITION';
    KW_ROWS         : KeywordName := 'ROWS';
    KW_RANGE        : KeywordName := 'RANGE';
    { Window functions (TODO 18) }
    KW_UNBOUNDED    : KeywordName := 'UNBOUNDED';
    KW_PRECEDING    : KeywordName := 'PRECEDING';
    KW_FOLLOWING    : KeywordName := 'FOLLOWING';
    KW_CURRENT_ROW  : KeywordName := 'CURRENT ROW';
    KW_BETWEEN      : KeywordName := 'BETWEEN';
    KW_AND          : KeywordName := 'AND';
    KW_OR           : KeywordName := 'OR';
    KW_NOT          : KeywordName := 'NOT';
    KW_IN           : KeywordName := 'IN';
    KW_EXISTS       : KeywordName := 'EXISTS';
    KW_LIKE         : KeywordName := 'LIKE';
    KW_IS           : KeywordName := 'IS';
    KW_NULL         : KeywordName := 'NULL';
    KW_CASE         : KeywordName := 'CASE';
    KW_WHEN         : KeywordName := 'WHEN';
    KW_THEN         : KeywordName := 'THEN';
    KW_ELSE         : KeywordName := 'ELSE';
    KW_END          : KeywordName := 'END';
    KW_CAST         : KeywordName := 'CAST';
    KW_CONVERT      : KeywordName := 'CONVERT';
    KW_COLLATE      : KeywordName := 'COLLATE';
    KW_PIVOT        : KeywordName := 'PIVOT';
    KW_UNPIVOT      : KeywordName := 'UNPIVOT';
    KW_APPLY        : KeywordName := 'APPLY';
    KW_OFFSET       : KeywordName := 'OFFSET';
    KW_FETCH        : KeywordName := 'FETCH';
    KW_NEXT         : KeywordName := 'NEXT';
    KW_ONLY         : KeywordName := 'ONLY';
    KW_PERCENT      : KeywordName := 'PERCENT';
    KW_TIES         : KeywordName := 'TIES';
    KW_BEGIN        : KeywordName := 'BEGIN';
    KW_IF           : KeywordName := 'IF';
    KW_WHILE        : KeywordName := 'WHILE';
    KW_BREAK        : KeywordName := 'BREAK';
    KW_CONTINUE     : KeywordName := 'CONTINUE';
    KW_GOTO         : KeywordName := 'GOTO';
    KW_RETURN       : KeywordName := 'RETURN';
    KW_WAITFOR      : KeywordName := 'WAITFOR';
    KW_THROW        : KeywordName := 'THROW';
    KW_TRY          : KeywordName := 'TRY';
    KW_CATCH        : KeywordName := 'CATCH';
    KW_RAISERROR    : KeywordName := 'RAISERROR';
    KW_PRINT        : KeywordName := 'PRINT';
    KW_EXEC         : KeywordName := 'EXEC';
    KW_EXECUTE      : KeywordName := 'EXECUTE';
    KW_DECLARE      : KeywordName := 'DECLARE';
    KW_USE          : KeywordName := 'USE';
    KW_GO           : KeywordName := 'GO';
    KW_COMMIT       : KeywordName := 'COMMIT';
    KW_ROLLBACK     : KeywordName := 'ROLLBACK';
    KW_SAVE         : KeywordName := 'SAVE';
    KW_TRANSACTION  : KeywordName := 'TRANSACTION';
    KW_GRANT        : KeywordName := 'GRANT';
    KW_REVOKE       : KeywordName := 'REVOKE';
    KW_DENY         : KeywordName := 'DENY';
    KW_OUTPUT       : KeywordName := 'OUTPUT';
    KW_USING        : KeywordName := 'USING';
    { DCL (TODO 14) }
    KW_TO           : KeywordName := 'TO';
    KW_CONTROL      : KeywordName := 'CONTROL';
    KW_DEFINITION   : KeywordName := 'DEFINITION';
    KW_TAKE         : KeywordName := 'TAKE';
    KW_OWNERSHIP    : KeywordName := 'OWNERSHIP';
    KW_PUBLIC       : KeywordName := 'PUBLIC';
  Else
    KeywordName := '?';
  End;
End;

{ ============================================================
  TODO 09 - PARSEUR D EXPRESSIONS SQL [IMPLEMENTE]
  ============================================================ }

{ ---- Initialisation du pool de noeuds AST -------------------- }

Procedure ASTInit;
Var
  I : Integer;
Begin
  ASTCount := 0;
  ParseOk  := True;
  For I := 0 To MAX_AST_NODES - 1 Do
  Begin
    ASTPool[I].Kind     := ND_NONE;
    ASTPool[I].Text     := '';
    ASTPool[I].ChildCnt := 0;
    ASTPool[I].Line     := 0;
    ASTPool[I].Col      := 0;
  End;
End;

{ ---- Allouer un nouveau noeud AST ---------------------------- }

Function NewNode(Kind : Byte; Const Txt : TTokenText;
                 Ln, Co : Integer) : Integer;
Var
  I : Integer;
Begin
  If ASTCount >= MAX_AST_NODES Then
  Begin
    ParseOk := False;
    NewNode := -1;
    Exit;
  End;
  NewNode := ASTCount;
  ASTPool[ASTCount].Kind     := Kind;
  ASTPool[ASTCount].Text     := Txt;
  ASTPool[ASTCount].ChildCnt := 0;
  ASTPool[ASTCount].Line     := Ln;
  ASTPool[ASTCount].Col      := Co;
  For I := 0 To MAX_AST_CHILDREN - 1 Do
    ASTPool[ASTCount].Children[I] := -1;
  Inc(ASTCount);
End;

{ ---- Ajouter un enfant a un noeud AST ----------------------- }

Procedure AddChild(Parent, Child : Integer);
Begin
  If (Parent < 0) Or (Parent >= ASTCount) Then Exit;
  If Child < 0 Then Exit;
  If ASTPool[Parent].ChildCnt >= MAX_AST_CHILDREN Then Exit;
  ASTPool[Parent].Children[ASTPool[Parent].ChildCnt] := Child;
  Inc(ASTPool[Parent].ChildCnt);
End;

{ ---- Nom textuel d un type de noeud AST ---------------------- }

Function NodeKindName(K : Byte) : TString;
Begin
  Case K Of
    ND_NONE        : NodeKindName := 'NONE';
    ND_INT_LIT     : NodeKindName := 'INT_LIT';
    ND_FLOAT_LIT   : NodeKindName := 'FLOAT_LIT';
    ND_STR_LIT     : NodeKindName := 'STR_LIT';
    ND_NSTR_LIT    : NodeKindName := 'NSTR_LIT';
    ND_HEX_LIT     : NodeKindName := 'HEX_LIT';
    ND_NULL_LIT    : NodeKindName := 'NULL_LIT';
    ND_DEFAULT_LIT : NodeKindName := 'DEFAULT_LIT';
    ND_VARIABLE    : NodeKindName := 'VARIABLE';
    ND_IDENT       : NodeKindName := 'IDENT';
    ND_DELIM_IDENT : NodeKindName := 'DELIM_IDENT';
    ND_STAR        : NodeKindName := 'STAR';
    ND_PARAM       : NodeKindName := 'PARAM';
    ND_BINOP       : NodeKindName := 'BINOP';
    ND_UNARY       : NodeKindName := 'UNARY';
    ND_COMPARE     : NodeKindName := 'COMPARE';
    ND_AND         : NodeKindName := 'AND';
    ND_OR          : NodeKindName := 'OR';
    ND_NOT         : NodeKindName := 'NOT';
    ND_BETWEEN     : NodeKindName := 'BETWEEN';
    ND_IN          : NodeKindName := 'IN';
    ND_LIKE        : NodeKindName := 'LIKE';
    ND_IS_NULL     : NodeKindName := 'IS_NULL';
    ND_IS_NOT_NULL : NodeKindName := 'IS_NOT_NULL';
    ND_EXISTS      : NodeKindName := 'EXISTS';
    ND_FUNC_CALL   : NodeKindName := 'FUNC_CALL';
    ND_CASE_WHEN   : NodeKindName := 'CASE_WHEN';
    ND_CASE_EXPR   : NodeKindName := 'CASE_EXPR';
    ND_CAST        : NodeKindName := 'CAST';
    ND_CONVERT     : NodeKindName := 'CONVERT';
    ND_COLLATE     : NodeKindName := 'COLLATE';
    ND_SUBQUERY    : NodeKindName := 'SUBQUERY';
    ND_WHEN_ITEM   : NodeKindName := 'WHEN_ITEM';
    ND_ARG_LIST    : NodeKindName := 'ARG_LIST';
    ND_DOT_REF     : NodeKindName := 'DOT_REF';
    ND_TYPE_REF    : NodeKindName := 'TYPE_REF';
    ND_SELECT_STMT : NodeKindName := 'SELECT_STMT';
    ND_SELECT_ITEM : NodeKindName := 'SELECT_ITEM';
    ND_FROM_CLAUSE : NodeKindName := 'FROM_CLAUSE';
    ND_TABLE_REF   : NodeKindName := 'TABLE_REF';
    ND_JOIN        : NodeKindName := 'JOIN';
    ND_WHERE_CLAUSE: NodeKindName := 'WHERE_CLAUSE';
    ND_GROUP_BY    : NodeKindName := 'GROUP_BY';
    ND_HAVING      : NodeKindName := 'HAVING';
    ND_ORDER_BY    : NodeKindName := 'ORDER_BY';
    ND_ORDER_ITEM  : NodeKindName := 'ORDER_ITEM';
    ND_TOP_CLAUSE  : NodeKindName := 'TOP_CLAUSE';
    ND_OFFSET      : NodeKindName := 'OFFSET';
    ND_UNION       : NodeKindName := 'UNION';
    ND_INTERSECT_OP: NodeKindName := 'INTERSECT';
    ND_EXCEPT_OP   : NodeKindName := 'EXCEPT';
    ND_CTE         : NodeKindName := 'CTE';
    ND_SELECT_INTO : NodeKindName := 'SELECT_INTO';
    ND_TABLE_HINT  : NodeKindName := 'TABLE_HINT';
    ND_APPLY       : NodeKindName := 'APPLY';
    ND_FOR_XML     : NodeKindName := 'FOR_XML';
    ND_FOR_JSON    : NodeKindName := 'FOR_JSON';
    ND_ALIAS       : NodeKindName := 'ALIAS';
    ND_INSERT_STMT : NodeKindName := 'INSERT_STMT';
    ND_COL_LIST    : NodeKindName := 'COL_LIST';
    ND_VALUES_CLAUSE:NodeKindName := 'VALUES_CLAUSE';
    ND_VALUES_ROW  : NodeKindName := 'VALUES_ROW';
    ND_UPDATE_STMT : NodeKindName := 'UPDATE_STMT';
    ND_SET_CLAUSE  : NodeKindName := 'SET_CLAUSE';
    ND_SET_ITEM    : NodeKindName := 'SET_ITEM';
    ND_DELETE_STMT : NodeKindName := 'DELETE_STMT';
    ND_TRUNCATE_STMT:NodeKindName := 'TRUNCATE_STMT';
    ND_MERGE_STMT  : NodeKindName := 'MERGE_STMT';
    ND_MERGE_WHEN  : NodeKindName := 'MERGE_WHEN';
    ND_OUTPUT_CLAUSE:NodeKindName := 'OUTPUT_CLAUSE';
    ND_OUTPUT_ITEM : NodeKindName := 'OUTPUT_ITEM';
    ND_DEFAULT_VALUES:NodeKindName:= 'DEFAULT_VALUES';
    ND_EXEC_INSERT : NodeKindName := 'EXEC_INSERT';
    ND_CREATE_TABLE: NodeKindName := 'CREATE_TABLE';
    ND_COL_DEF     : NodeKindName := 'COL_DEF';
    ND_PK_CONSTRAINT: NodeKindName := 'PK_CONSTRAINT';
    ND_FK_CONSTRAINT: NodeKindName := 'FK_CONSTRAINT';
    ND_UNIQUE_CONSTR: NodeKindName := 'UNIQUE_CONSTR';
    ND_CHECK_CONSTR : NodeKindName := 'CHECK_CONSTR';
    ND_DEFAULT_CONSTR: NodeKindName := 'DEFAULT_CONSTR';
    ND_IDENTITY_SPEC: NodeKindName := 'IDENTITY_SPEC';
    ND_TABLE_CONSTR : NodeKindName := 'TABLE_CONSTR';
    ND_CREATE_INDEX : NodeKindName := 'CREATE_INDEX';
    ND_INDEX_COL    : NodeKindName := 'INDEX_COL';
    ND_INCLUDE_COLS : NodeKindName := 'INCLUDE_COLS';
    ND_CREATE_VIEW  : NodeKindName := 'CREATE_VIEW';
    ND_CREATE_PROC  : NodeKindName := 'CREATE_PROC';
    ND_CREATE_FUNC  : NodeKindName := 'CREATE_FUNC';
    ND_CREATE_TRIGGER: NodeKindName := 'CREATE_TRIGGER';
    ND_CREATE_SCHEMA : NodeKindName := 'CREATE_SCHEMA';
    ND_CREATE_SEQ   : NodeKindName := 'CREATE_SEQ';
    ND_CREATE_TYPE  : NodeKindName := 'CREATE_TYPE';
    ND_CREATE_DB    : NodeKindName := 'CREATE_DB';
    ND_ALTER_TABLE  : NodeKindName := 'ALTER_TABLE';
    ND_ALTER_INDEX  : NodeKindName := 'ALTER_INDEX';
    ND_DROP_STMT    : NodeKindName := 'DROP_STMT';
    ND_PARAM_DEF    : NodeKindName := 'PARAM_DEF';
    ND_BODY_BLOCK   : NodeKindName := 'BODY_BLOCK';
    ND_WITH_OPTION  : NodeKindName := 'WITH_OPTION';
    { -- T-SQL control flow (TODO 13) -- }
    ND_DECLARE_VAR  : NodeKindName := 'DECLARE_VAR';
    ND_DECLARE_TABLE: NodeKindName := 'DECLARE_TABLE';
    ND_SET_VAR      : NodeKindName := 'SET_VAR';
    ND_SELECT_VAR   : NodeKindName := 'SELECT_VAR';
    ND_IF_STMT      : NodeKindName := 'IF_STMT';
    ND_WHILE_STMT   : NodeKindName := 'WHILE_STMT';
    ND_BREAK_STMT   : NodeKindName := 'BREAK_STMT';
    ND_CONTINUE_STMT: NodeKindName := 'CONTINUE_STMT';
    ND_BLOCK_STMT   : NodeKindName := 'BLOCK_STMT';
    ND_GOTO_STMT    : NodeKindName := 'GOTO_STMT';
    ND_LABEL_STMT   : NodeKindName := 'LABEL_STMT';
    ND_RETURN_STMT  : NodeKindName := 'RETURN_STMT';
    ND_WAITFOR_STMT : NodeKindName := 'WAITFOR_STMT';
    ND_TRY_CATCH    : NodeKindName := 'TRY_CATCH';
    ND_THROW_STMT   : NodeKindName := 'THROW_STMT';
    ND_RAISERROR_STMT: NodeKindName := 'RAISERROR_STMT';
    ND_PRINT_STMT   : NodeKindName := 'PRINT_STMT';
    ND_EXEC_STMT    : NodeKindName := 'EXEC_STMT';
    ND_EXEC_SQL     : NodeKindName := 'EXEC_SQL';
    ND_USE_STMT     : NodeKindName := 'USE_STMT';
    ND_GO_STMT      : NodeKindName := 'GO_STMT';
    { DCL (TODO 14) }
    ND_GRANT_STMT   : NodeKindName := 'GRANT_STMT';
    ND_REVOKE_STMT  : NodeKindName := 'REVOKE_STMT';
    ND_DENY_STMT    : NodeKindName := 'DENY_STMT';
    ND_PERMISSION   : NodeKindName := 'PERMISSION';
    ND_PRINCIPAL    : NodeKindName := 'PRINCIPAL';
    ND_CREATE_LOGIN : NodeKindName := 'CREATE_LOGIN';
    ND_CREATE_USER  : NodeKindName := 'CREATE_USER';
    ND_ALTER_LOGIN  : NodeKindName := 'ALTER_LOGIN';
    ND_ALTER_USER   : NodeKindName := 'ALTER_USER';
    ND_ALTER_ROLE   : NodeKindName := 'ALTER_ROLE';
    ND_DROP_LOGIN   : NodeKindName := 'DROP_LOGIN';
    ND_DROP_USER    : NodeKindName := 'DROP_USER';
    { Window functions (TODO 18) }
    ND_OVER_CLAUSE  : NodeKindName := 'OVER_CLAUSE';
    ND_PARTITION_BY : NodeKindName := 'PARTITION_BY';
    ND_WINDOW_FRAME : NodeKindName := 'WINDOW_FRAME';
    ND_FRAME_BOUND  : NodeKindName := 'FRAME_BOUND';
  Else
    NodeKindName := '?';
  End;
End;

{ ---- Helpers du parseur -------------------------------------- }

Function TokIs(K : Byte) : Boolean;
Begin
  TokIs := (LexCurTok.Kind = K);
End;

Function KwIs(K : Integer) : Boolean;
Begin
  KwIs := (LexCurTok.Kind = TOK_KEYWORD) And (LexCurTok.KwId = K);
End;

Procedure Advance;
Begin
  LexNextToken;
End;

Procedure ParseError(Const Msg : TString);
Begin
  If ParseOk Then
  Begin
    WarnMsg('ligne ' + IntToStr(LexCurTok.Line) + ' col ' +
            IntToStr(LexCurTok.Col) + ': ' + Msg);
    ParseOk := False;
  End;
End;

{ ---- Declarations forward du parseur d expressions ----------- }

Function ParseSqlExpr : Integer; Forward;

{ ---- ParseTypeRef : reference de type (pour CAST/CONVERT) ---- }
{ Formes supportees : INT, VARCHAR(50), DECIMAL(18,2), NVARCHAR(MAX) }

Function ParseTypeRef : Integer;
Var
  N, Arg : Integer;
Begin
  ParseTypeRef := -1;
  If Not ParseOk Then Exit;
  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) Then
  Begin
    ParseError('type attendu');
    Exit;
  End;
  N := NewNode(ND_TYPE_REF, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
  Advance;
  { Parametres optionnels : (n) ou (n,m) ou (MAX) }
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_NUMBER) Or (LexCurTok.Kind = TOK_IDENT) Or
       (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      Arg := NewNode(ND_INT_LIT, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
      AddChild(N, Arg);
      Advance;
      If TokIs(TOK_COMMA) Then
      Begin
        Advance;
        If LexCurTok.Kind = TOK_NUMBER Then
        Begin
          Arg := NewNode(ND_INT_LIT, LexCurTok.Text, LexCurTok.Line,
                         LexCurTok.Col);
          AddChild(N, Arg);
          Advance;
        End;
      End;
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres type');
  End;
  ParseTypeRef := N;
End;

{ ---- ParseOverClause : OVER (PARTITION BY.. ORDER BY.. frame) (TODO 18) }
{ Enveloppe un noeud ND_FUNC_CALL dans un ND_OVER_CLAUSE.                }
{ Syntaxe : OVER ( [PARTITION BY expr, ...]                               }
{                  [ORDER BY expr [ASC|DESC], ...]                        }
{                  [ROWS|RANGE BETWEEN borne AND borne] )                 }

Function ParseOverClause(FuncNode : Integer) : Integer;
Var
  N, P, O, F, B, E, Item : Integer;
  Dir, BndTxt : TTokenText;
Begin
  ParseOverClause := FuncNode;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_OVER) Then Exit;

  N := NewNode(ND_OVER_CLAUSE, 'OVER', LexCurTok.Line, LexCurTok.Col);
  AddChild(N, FuncNode);
  Advance; { skip OVER }

  If TokIs(TOK_LPAREN) Then
    Advance
  Else
  Begin
    ParseError('( attendu apres OVER');
    ParseOverClause := N;
    Exit;
  End;

  { PARTITION BY expr, expr, ... }
  If KwIs(KW_PARTITION) Then
  Begin
    P := NewNode(ND_PARTITION_BY, 'PARTITION BY',
                 LexCurTok.Line, LexCurTok.Col);
    Advance; { skip PARTITION }
    If KwIs(KW_BY) Then
      Advance
    Else
      ParseError('BY attendu apres PARTITION');
    E := ParseSqlExpr;
    AddChild(P, E);
    While TokIs(TOK_COMMA) And ParseOk Do
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(P, E);
    End;
    AddChild(N, P);
  End;

  { ORDER BY expr [ASC|DESC], ... }
  If KwIs(KW_ORDER) Then
  Begin
    O := NewNode(ND_ORDER_BY, 'ORDER BY', LexCurTok.Line, LexCurTok.Col);
    Advance; { skip ORDER }
    If KwIs(KW_BY) Then
      Advance
    Else
      ParseError('BY attendu apres ORDER');
    E := ParseSqlExpr;
    Dir := 'ASC';
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      If StrUpperCase(LexCurTok.Text) = 'ASC' Then
      Begin Dir := 'ASC'; Advance; End
      Else If StrUpperCase(LexCurTok.Text) = 'DESC' Then
      Begin Dir := 'DESC'; Advance; End;
    End;
    Item := NewNode(ND_ORDER_ITEM, Dir, LexCurTok.Line, LexCurTok.Col);
    AddChild(Item, E);
    AddChild(O, Item);
    While TokIs(TOK_COMMA) And ParseOk Do
    Begin
      Advance;
      E := ParseSqlExpr;
      Dir := 'ASC';
      If (LexCurTok.Kind = TOK_IDENT) Or
         (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        If StrUpperCase(LexCurTok.Text) = 'ASC' Then
        Begin Dir := 'ASC'; Advance; End
        Else If StrUpperCase(LexCurTok.Text) = 'DESC' Then
        Begin Dir := 'DESC'; Advance; End;
      End;
      Item := NewNode(ND_ORDER_ITEM, Dir, LexCurTok.Line, LexCurTok.Col);
      AddChild(Item, E);
      AddChild(O, Item);
    End;
    AddChild(N, O);
  End;

  { Frame : ROWS|RANGE BETWEEN borne AND borne }
  If KwIs(KW_ROWS) Or KwIs(KW_RANGE) Then
  Begin
    If KwIs(KW_ROWS) Then
      F := NewNode(ND_WINDOW_FRAME, 'ROWS',
                   LexCurTok.Line, LexCurTok.Col)
    Else
      F := NewNode(ND_WINDOW_FRAME, 'RANGE',
                   LexCurTok.Line, LexCurTok.Col);
    Advance;
    If KwIs(KW_BETWEEN) Then
    Begin
      Advance; { skip BETWEEN }
      { Borne inferieure }
      BndTxt := '';
      If KwIs(KW_UNBOUNDED) Then
      Begin BndTxt := 'UNBOUNDED PRECEDING'; Advance;
        If KwIs(KW_PRECEDING) Then Advance; End
      Else If StrUpperCase(LexCurTok.Text) = 'CURRENT' Then
      Begin BndTxt := 'CURRENT ROW'; Advance;
        If KwIs(KW_ROWS) Or
           (StrUpperCase(LexCurTok.Text) = 'ROW') Then Advance; End
      Else
      Begin
        BndTxt := LexCurTok.Text;
        Advance;
        If KwIs(KW_PRECEDING) Then
        Begin BndTxt := BndTxt + ' PRECEDING'; Advance; End
        Else If KwIs(KW_FOLLOWING) Then
        Begin BndTxt := BndTxt + ' FOLLOWING'; Advance; End;
      End;
      B := NewNode(ND_FRAME_BOUND, BndTxt, LexCurTok.Line, LexCurTok.Col);
      AddChild(F, B);
      { AND }
      If KwIs(KW_AND) Then Advance
      Else ParseError('AND attendu dans specification de cadre');
      { Borne superieure }
      BndTxt := '';
      If KwIs(KW_UNBOUNDED) Then
      Begin BndTxt := 'UNBOUNDED FOLLOWING'; Advance;
        If KwIs(KW_FOLLOWING) Then Advance; End
      Else If StrUpperCase(LexCurTok.Text) = 'CURRENT' Then
      Begin BndTxt := 'CURRENT ROW'; Advance;
        If KwIs(KW_ROWS) Or
           (StrUpperCase(LexCurTok.Text) = 'ROW') Then Advance; End
      Else
      Begin
        BndTxt := LexCurTok.Text;
        Advance;
        If KwIs(KW_PRECEDING) Then
        Begin BndTxt := BndTxt + ' PRECEDING'; Advance; End
        Else If KwIs(KW_FOLLOWING) Then
        Begin BndTxt := BndTxt + ' FOLLOWING'; Advance; End;
      End;
      B := NewNode(ND_FRAME_BOUND, BndTxt, LexCurTok.Line, LexCurTok.Col);
      AddChild(F, B);
    End
    Else
    Begin
      { Forme sans BETWEEN : ROWS UNBOUNDED PRECEDING }
      BndTxt := '';
      If KwIs(KW_UNBOUNDED) Then
      Begin BndTxt := 'UNBOUNDED PRECEDING'; Advance;
        If KwIs(KW_PRECEDING) Then Advance; End
      Else If StrUpperCase(LexCurTok.Text) = 'CURRENT' Then
      Begin BndTxt := 'CURRENT ROW'; Advance;
        If KwIs(KW_ROWS) Or
           (StrUpperCase(LexCurTok.Text) = 'ROW') Then Advance; End
      Else
      Begin
        BndTxt := LexCurTok.Text;
        Advance;
        If KwIs(KW_PRECEDING) Then
        Begin BndTxt := BndTxt + ' PRECEDING'; Advance; End;
      End;
      B := NewNode(ND_FRAME_BOUND, BndTxt, LexCurTok.Line, LexCurTok.Col);
      AddChild(F, B);
    End;
    AddChild(N, F);
  End;

  If TokIs(TOK_RPAREN) Then
    Advance
  Else
    ParseError(') attendu apres clause OVER');

  ParseOverClause := N;
End;

{ ---- ParseAtom : atomes de l expression SQL ------------------ }
{ nombre, chaine, N'...', variable, NULL, DEFAULT, ?, *,         }
{ (sous-expression), (SELECT ...), fonction(args),               }
{ CASE WHEN ... END, CASE expr WHEN ... END,                     }
{ CAST(expr AS type), CONVERT(type, expr [, style]),             }
{ EXISTS(SELECT ...)                                             }

Function ParseAtom : Integer;
Var
  N, E, W, C, T : Integer;
  FnName : TTokenText;
Begin
  ParseAtom := -1;
  If Not ParseOk Then Exit;

  { Litteral entier }
  If TokIs(TOK_NUMBER) Then
  Begin
    N := NewNode(ND_INT_LIT, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Litteral flottant }
  If TokIs(TOK_FLOAT) Then
  Begin
    N := NewNode(ND_FLOAT_LIT, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Litteral chaine }
  If TokIs(TOK_STRING) Then
  Begin
    N := NewNode(ND_STR_LIT, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Litteral Unicode N'...' }
  If TokIs(TOK_NSTRING) Then
  Begin
    N := NewNode(ND_NSTR_LIT, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Litteral hexa 0x... }
  If TokIs(TOK_HEX) Then
  Begin
    N := NewNode(ND_HEX_LIT, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Variable @nom ou @@nom }
  If TokIs(TOK_VARIABLE) Then
  Begin
    N := NewNode(ND_VARIABLE, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { Parametre ? }
  If TokIs(TOK_PARAM) Then
  Begin
    N := NewNode(ND_PARAM, '?', LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { * (pour SELECT * ou table.*) }
  If TokIs(TOK_STAR) Then
  Begin
    N := NewNode(ND_STAR, '*', LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { NULL }
  If KwIs(KW_NULL) Then
  Begin
    N := NewNode(ND_NULL_LIT, 'NULL', LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { DEFAULT }
  If (LexCurTok.Kind = TOK_IDENT) And
     (StrUpperCase(LexCurTok.Text) = 'DEFAULT') Then
  Begin
    N := NewNode(ND_DEFAULT_LIT, 'DEFAULT', LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseAtom := N;
    Exit;
  End;

  { EXISTS (sous-requete) }
  If KwIs(KW_EXISTS) Then
  Begin
    N := NewNode(ND_EXISTS, 'EXISTS', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      { Sous-requete simplifiee : on consomme tout jusqu a ')' }
      E := NewNode(ND_SUBQUERY, 'SELECT', LexCurTok.Line, LexCurTok.Col);
      While (Not TokIs(TOK_RPAREN)) And (Not TokIs(TOK_EOF)) And ParseOk Do
        Advance;
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres EXISTS');
      AddChild(N, E);
    End
    Else
      ParseError('( attendu apres EXISTS');
    ParseAtom := N;
    Exit;
  End;

  { CASE WHEN ... END / CASE expr WHEN ... END }
  If KwIs(KW_CASE) Then
  Begin
    Advance;
    { CASE WHEN form vs CASE expr WHEN form }
    If KwIs(KW_WHEN) Then
    Begin
      { Searched CASE : CASE WHEN cond THEN result ... END }
      N := NewNode(ND_CASE_WHEN, 'CASE', LexCurTok.Line, LexCurTok.Col);
      While KwIs(KW_WHEN) And ParseOk Do
      Begin
        Advance; { skip WHEN }
        W := NewNode(ND_WHEN_ITEM, 'WHEN', LexCurTok.Line, LexCurTok.Col);
        C := ParseSqlExpr;
        AddChild(W, C);
        If KwIs(KW_THEN) Then
          Advance
        Else
          ParseError('THEN attendu');
        E := ParseSqlExpr;
        AddChild(W, E);
        AddChild(N, W);
      End;
      If KwIs(KW_ELSE) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(N, E);
      End;
      If KwIs(KW_END) Then
        Advance
      Else
        ParseError('END attendu');
    End
    Else
    Begin
      { Simple CASE : CASE expr WHEN val THEN result ... END }
      N := NewNode(ND_CASE_EXPR, 'CASE', LexCurTok.Line, LexCurTok.Col);
      E := ParseSqlExpr;
      AddChild(N, E); { expression de test }
      While KwIs(KW_WHEN) And ParseOk Do
      Begin
        Advance; { skip WHEN }
        W := NewNode(ND_WHEN_ITEM, 'WHEN', LexCurTok.Line, LexCurTok.Col);
        C := ParseSqlExpr;
        AddChild(W, C);
        If KwIs(KW_THEN) Then
          Advance
        Else
          ParseError('THEN attendu');
        E := ParseSqlExpr;
        AddChild(W, E);
        AddChild(N, W);
      End;
      If KwIs(KW_ELSE) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(N, E);
      End;
      If KwIs(KW_END) Then
        Advance
      Else
        ParseError('END attendu');
    End;
    ParseAtom := N;
    Exit;
  End;

  { CAST(expr AS type) }
  If KwIs(KW_CAST) Then
  Begin
    N := NewNode(ND_CAST, 'CAST', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres CAST');
    E := ParseSqlExpr;
    AddChild(N, E);
    If KwIs(KW_AS) Then
      Advance
    Else
      ParseError('AS attendu dans CAST');
    T := ParseTypeRef;
    AddChild(N, T);
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres CAST');
    ParseAtom := N;
    Exit;
  End;

  { CONVERT(type, expr [, style]) }
  If KwIs(KW_CONVERT) Then
  Begin
    N := NewNode(ND_CONVERT, 'CONVERT', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres CONVERT');
    T := ParseTypeRef;
    AddChild(N, T);
    If TokIs(TOK_COMMA) Then
      Advance
    Else
      ParseError(', attendu dans CONVERT');
    E := ParseSqlExpr;
    AddChild(N, E);
    { Style optionnel }
    If TokIs(TOK_COMMA) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres CONVERT');
    ParseAtom := N;
    Exit;
  End;

  { ===== TODO 22 : TRY_CAST, TRY_CONVERT, PARSE, TRY_PARSE ===== }

  { TRY_CAST(expr AS type) }
  If (LexCurTok.Kind = TOK_IDENT) And
     (StrUpperCase(LexCurTok.Text) = 'TRY_CAST') Then
  Begin
    N := NewNode(ND_CAST, 'TRY_CAST', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres TRY_CAST');
    E := ParseSqlExpr;
    AddChild(N, E);
    If KwIs(KW_AS) Then
      Advance
    Else
      ParseError('AS attendu dans TRY_CAST');
    T := ParseTypeRef;
    AddChild(N, T);
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres TRY_CAST');
    ParseAtom := N;
    Exit;
  End;

  { TRY_CONVERT(type, expr [, style]) }
  If (LexCurTok.Kind = TOK_IDENT) And
     (StrUpperCase(LexCurTok.Text) = 'TRY_CONVERT') Then
  Begin
    N := NewNode(ND_CONVERT, 'TRY_CONVERT', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres TRY_CONVERT');
    T := ParseTypeRef;
    AddChild(N, T);
    If TokIs(TOK_COMMA) Then
      Advance
    Else
      ParseError(', attendu dans TRY_CONVERT');
    E := ParseSqlExpr;
    AddChild(N, E);
    { Style optionnel }
    If TokIs(TOK_COMMA) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres TRY_CONVERT');
    ParseAtom := N;
    Exit;
  End;

  { PARSE(string AS type [USING culture]) }
  If (LexCurTok.Kind = TOK_IDENT) And
     (StrUpperCase(LexCurTok.Text) = 'PARSE') Then
  Begin
    N := NewNode(ND_CAST, 'PARSE', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres PARSE');
    E := ParseSqlExpr;
    AddChild(N, E);
    If KwIs(KW_AS) Then
      Advance
    Else
      ParseError('AS attendu dans PARSE');
    T := ParseTypeRef;
    AddChild(N, T);
    { USING culture optionnel : ignorer }
    If (LexCurTok.Kind = TOK_IDENT) And
       (StrUpperCase(LexCurTok.Text) = 'USING') Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or
         (LexCurTok.Kind = TOK_STRING) Then
        Advance;
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres PARSE');
    ParseAtom := N;
    Exit;
  End;

  { TRY_PARSE(string AS type [USING culture]) }
  If (LexCurTok.Kind = TOK_IDENT) And
     (StrUpperCase(LexCurTok.Text) = 'TRY_PARSE') Then
  Begin
    N := NewNode(ND_CAST, 'TRY_PARSE', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_LPAREN) Then
      Advance
    Else
      ParseError('( attendu apres TRY_PARSE');
    E := ParseSqlExpr;
    AddChild(N, E);
    If KwIs(KW_AS) Then
      Advance
    Else
      ParseError('AS attendu dans TRY_PARSE');
    T := ParseTypeRef;
    AddChild(N, T);
    { USING culture optionnel : ignorer }
    If (LexCurTok.Kind = TOK_IDENT) And
       (StrUpperCase(LexCurTok.Text) = 'USING') Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or
         (LexCurTok.Kind = TOK_STRING) Then
        Advance;
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres TRY_PARSE');
    ParseAtom := N;
    Exit;
  End;

  { Sous-expression parenthesee ou sous-requete scalaire }
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    { Sous-requete scalaire : (SELECT ...) }
    If KwIs(KW_SELECT) Then
    Begin
      N := NewNode(ND_SUBQUERY, 'SELECT', LexCurTok.Line, LexCurTok.Col);
      { Consomme tout jusqu a la parenthese fermante }
      T := 1; { profondeur parentheses }
      While (T > 0) And (Not TokIs(TOK_EOF)) And ParseOk Do
      Begin
        If TokIs(TOK_LPAREN) Then
          Inc(T)
        Else If TokIs(TOK_RPAREN) Then
          Dec(T);
        If T > 0 Then
          Advance;
      End;
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres sous-requete');
      ParseAtom := N;
      Exit;
    End;
    { Sous-expression parenthesee normale }
    N := ParseSqlExpr;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu');
    ParseAtom := N;
    Exit;
  End;

  { Identificateur delimite [nom] }
  If TokIs(TOK_DELIM_IDENT) Then
  Begin
    N := NewNode(ND_DELIM_IDENT, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance;
    { Reference pointee : [schema].[table].[col] }
    While TokIs(TOK_DOT) And ParseOk Do
    Begin
      E := N;
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        C := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
        If LexCurTok.Kind = TOK_DELIM_IDENT Then
          ASTPool[C].Kind := ND_DELIM_IDENT;
        Advance;
      End
      Else If TokIs(TOK_STAR) Then
      Begin
        C := NewNode(ND_STAR, '*', LexCurTok.Line, LexCurTok.Col);
        Advance;
      End
      Else
      Begin
        ParseError('identificateur attendu apres .');
        C := -1;
      End;
      N := NewNode(ND_DOT_REF, '.', ASTPool[E].Line, ASTPool[E].Col);
      AddChild(N, E);
      AddChild(N, C);
    End;
    ParseAtom := N;
    Exit;
  End;

  { Identificateur ou mot-cle utilise comme nom + appel de fonction }
  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    FnName := LexCurTok.Text;
    N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    Advance;
    { Reference pointee : schema.table.colonne ou table.* }
    While TokIs(TOK_DOT) And ParseOk Do
    Begin
      E := N;
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        C := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
        If LexCurTok.Kind = TOK_DELIM_IDENT Then
          ASTPool[C].Kind := ND_DELIM_IDENT;
        FnName := LexCurTok.Text;
        Advance;
      End
      Else If TokIs(TOK_STAR) Then
      Begin
        C := NewNode(ND_STAR, '*', LexCurTok.Line, LexCurTok.Col);
        Advance;
      End
      Else
      Begin
        ParseError('identificateur attendu apres .');
        C := -1;
      End;
      N := NewNode(ND_DOT_REF, '.', ASTPool[E].Line, ASTPool[E].Col);
      AddChild(N, E);
      AddChild(N, C);
    End;
    { Appel de fonction : nom(...) }
    If TokIs(TOK_LPAREN) Then
    Begin
      E := N;
      N := NewNode(ND_FUNC_CALL, FnName, ASTPool[E].Line, ASTPool[E].Col);
      AddChild(N, E); { nom de la fonction }
      Advance; { skip ( }
      If Not TokIs(TOK_RPAREN) Then
      Begin
        C := ParseSqlExpr;
        AddChild(N, C);
        While TokIs(TOK_COMMA) And ParseOk Do
        Begin
          Advance;
          C := ParseSqlExpr;
          AddChild(N, C);
        End;
      End;
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres arguments');
      { Clause OVER pour fonctions de fenetre (TODO 18) }
      If KwIs(KW_OVER) Then
      Begin
        N := ParseOverClause(N);
      End;
    End;
    ParseAtom := N;
    Exit;
  End;

  { Rien de reconnu }
  ParseError('expression attendue, trouve: ' + LexCurTok.Text);
End;

{ ---- ParseUnary : operateurs unaires +, -, ~, NOT ----------- }

Function ParseUnary : Integer;
Var
  N, E : Integer;
  Op   : TTokenText;
Begin
  ParseUnary := -1;
  If Not ParseOk Then Exit;

  { NOT expr }
  If KwIs(KW_NOT) Then
  Begin
    Op := 'NOT';
    Advance;
    E := ParseUnary;
    N := NewNode(ND_NOT, Op, LexCurTok.Line, LexCurTok.Col);
    AddChild(N, E);
    ParseUnary := N;
    Exit;
  End;

  { + expr (unaire positif) }
  If TokIs(TOK_PLUS) Then
  Begin
    Advance;
    ParseUnary := ParseUnary;
    Exit;
  End;

  { - expr (unaire negatif) }
  If TokIs(TOK_MINUS) Then
  Begin
    Op := '-';
    Advance;
    E := ParseUnary;
    N := NewNode(ND_UNARY, Op, LexCurTok.Line, LexCurTok.Col);
    AddChild(N, E);
    ParseUnary := N;
    Exit;
  End;

  { ~ expr (bitwise NOT) }
  If TokIs(TOK_TILDE) Then
  Begin
    Op := '~';
    Advance;
    E := ParseUnary;
    N := NewNode(ND_UNARY, Op, LexCurTok.Line, LexCurTok.Col);
    AddChild(N, E);
    ParseUnary := N;
    Exit;
  End;

  ParseUnary := ParseAtom;
End;

{ ---- ParseMulExpr : *, /, %, & ------------------------------- }

Function ParseMulExpr : Integer;
Var
  Left, Right, BinNode : Integer;
  Op : TTokenText;
Begin
  ParseMulExpr := -1;
  If Not ParseOk Then Exit;
  Left := ParseUnary;
  While ParseOk And
        (TokIs(TOK_STAR) Or TokIs(TOK_SLASH) Or TokIs(TOK_PERCENT) Or
         TokIs(TOK_AMPERSAND)) Do
  Begin
    Op := LexCurTok.Text;
    Advance;
    Right := ParseUnary;
    BinNode := NewNode(ND_BINOP, Op, ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(BinNode, Left);
    AddChild(BinNode, Right);
    Left := BinNode;
  End;
  ParseMulExpr := Left;
End;

Function ParseAddExpr : Integer;
Var
  Left, Right, BinNode : Integer;
  Op : TTokenText;
Begin
  ParseAddExpr := -1;
  If Not ParseOk Then Exit;
  Left := ParseMulExpr;
  While ParseOk And
        (TokIs(TOK_PLUS) Or TokIs(TOK_MINUS) Or TokIs(TOK_PIPE) Or
         TokIs(TOK_CARET)) Do
  Begin
    Op := LexCurTok.Text;
    Advance;
    Right := ParseMulExpr;
    BinNode := NewNode(ND_BINOP, Op, ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(BinNode, Left);
    AddChild(BinNode, Right);
    Left := BinNode;
  End;
  ParseAddExpr := Left;
End;

{ ---- ParseCompare : operateurs de comparaison ---------------- }

Function ParseCompare : Integer;
Var
  Left, Right, CmpNode : Integer;
  Op : TTokenText;
Begin
  ParseCompare := -1;
  If Not ParseOk Then Exit;
  Left := ParseAddExpr;
  If ParseOk And (TokIs(TOK_EQ) Or TokIs(TOK_NE) Or TokIs(TOK_LT) Or
     TokIs(TOK_GT) Or TokIs(TOK_LE) Or TokIs(TOK_GE) Or
     TokIs(TOK_BANG_LT) Or TokIs(TOK_BANG_GT)) Then
  Begin
    Op := LexCurTok.Text;
    Advance;
    Right := ParseAddExpr;
    CmpNode := NewNode(ND_COMPARE, Op, ASTPool[Left].Line,
                       ASTPool[Left].Col);
    AddChild(CmpNode, Left);
    AddChild(CmpNode, Right);
    Left := CmpNode;
  End;
  ParseCompare := Left;
End;

{ ---- ParseLogical : AND, OR, BETWEEN, IN, LIKE, IS [NOT] NULL, }
{      COLLATE, NOT                                               }

Function ParseLogical : Integer;
Var
  Left, Right, N, Lo, Hi, ListNode : Integer;
  Negated : Boolean;
Begin
  ParseLogical := -1;
  If Not ParseOk Then Exit;
  Left := ParseCompare;
  If Not ParseOk Then Begin ParseLogical := Left; Exit; End;

  { Postfix : expr IS [NOT] NULL }
  If KwIs(KW_IS) Then
  Begin
    Advance;
    If KwIs(KW_NOT) Then
    Begin
      Advance;
      If KwIs(KW_NULL) Then
        Advance
      Else
        ParseError('NULL attendu apres IS NOT');
      N := NewNode(ND_IS_NOT_NULL, 'IS NOT NULL', ASTPool[Left].Line,
                   ASTPool[Left].Col);
      AddChild(N, Left);
      Left := N;
    End
    Else
    Begin
      If KwIs(KW_NULL) Then
        Advance
      Else
        ParseError('NULL attendu apres IS');
      N := NewNode(ND_IS_NULL, 'IS NULL', ASTPool[Left].Line,
                   ASTPool[Left].Col);
      AddChild(N, Left);
      Left := N;
    End;
  End;

  { Postfix : [NOT] BETWEEN lo AND hi }
  Negated := False;
  If KwIs(KW_NOT) Then
  Begin
    { Regarder si BETWEEN, IN ou LIKE suit }
    Negated := True;
    Advance;
  End;

  If KwIs(KW_BETWEEN) And ParseOk Then
  Begin
    Advance;
    Lo := ParseAddExpr;
    If KwIs(KW_AND) Then
      Advance
    Else
      ParseError('AND attendu dans BETWEEN');
    Hi := ParseAddExpr;
    N := NewNode(ND_BETWEEN, 'BETWEEN', ASTPool[Left].Line,
                 ASTPool[Left].Col);
    AddChild(N, Left);
    AddChild(N, Lo);
    AddChild(N, Hi);
    If Negated Then
    Begin
      Left := NewNode(ND_NOT, 'NOT', ASTPool[N].Line, ASTPool[N].Col);
      AddChild(Left, N);
    End
    Else
      Left := N;
    Negated := False;
  End;

  { Postfix : [NOT] IN (liste | sous-requete) }
  If KwIs(KW_IN) And ParseOk Then
  Begin
    Advance;
    N := NewNode(ND_IN, 'IN', ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(N, Left);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      { Sous-requete ou liste de valeurs }
      If KwIs(KW_SELECT) Then
      Begin
        Right := NewNode(ND_SUBQUERY, 'SELECT', LexCurTok.Line,
                         LexCurTok.Col);
        While (Not TokIs(TOK_RPAREN)) And (Not TokIs(TOK_EOF)) And
              ParseOk Do
          Advance;
        AddChild(N, Right);
      End
      Else
      Begin
        ListNode := NewNode(ND_ARG_LIST, 'IN_LIST', LexCurTok.Line,
                            LexCurTok.Col);
        Right := ParseSqlExpr;
        AddChild(ListNode, Right);
        While TokIs(TOK_COMMA) And ParseOk Do
        Begin
          Advance;
          Right := ParseSqlExpr;
          AddChild(ListNode, Right);
        End;
        AddChild(N, ListNode);
      End;
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres IN');
    End
    Else
      ParseError('( attendu apres IN');
    If Negated Then
    Begin
      Left := NewNode(ND_NOT, 'NOT', ASTPool[N].Line, ASTPool[N].Col);
      AddChild(Left, N);
    End
    Else
      Left := N;
    Negated := False;
  End;

  { Postfix : [NOT] LIKE pattern }
  If KwIs(KW_LIKE) And ParseOk Then
  Begin
    Advance;
    Right := ParseAddExpr;
    N := NewNode(ND_LIKE, 'LIKE', ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(N, Left);
    AddChild(N, Right);
    If Negated Then
    Begin
      Left := NewNode(ND_NOT, 'NOT', ASTPool[N].Line, ASTPool[N].Col);
      AddChild(Left, N);
    End
    Else
      Left := N;
    Negated := False;
  End;

  { Si NOT a ete consomme mais pas utilise, envelopper }
  If Negated Then
  Begin
    N := NewNode(ND_NOT, 'NOT', ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(N, Left);
    Left := N;
  End;

  { COLLATE collation_name }
  If KwIs(KW_COLLATE) And ParseOk Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      N := NewNode(ND_COLLATE, LexCurTok.Text, ASTPool[Left].Line,
                   ASTPool[Left].Col);
      AddChild(N, Left);
      Advance;
      Left := N;
    End
    Else
      ParseError('nom de collation attendu');
  End;

  ParseLogical := Left;
End;

{ ---- ParseAndExpr : AND -------------------------------------- }

Function ParseAndExpr : Integer;
Var
  Left, Right, N : Integer;
Begin
  ParseAndExpr := -1;
  If Not ParseOk Then Exit;
  Left := ParseLogical;
  While KwIs(KW_AND) And ParseOk Do
  Begin
    Advance;
    Right := ParseLogical;
    N := NewNode(ND_AND, 'AND', ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(N, Left);
    AddChild(N, Right);
    Left := N;
  End;
  ParseAndExpr := Left;
End;

{ ---- ParseOrExpr : OR ---------------------------------------- }

Function ParseOrExpr : Integer;
Var
  Left, Right, N : Integer;
Begin
  ParseOrExpr := -1;
  If Not ParseOk Then Exit;
  Left := ParseAndExpr;
  While KwIs(KW_OR) And ParseOk Do
  Begin
    Advance;
    Right := ParseAndExpr;
    N := NewNode(ND_OR, 'OR', ASTPool[Left].Line, ASTPool[Left].Col);
    AddChild(N, Left);
    AddChild(N, Right);
    Left := N;
  End;
  ParseOrExpr := Left;
End;

{ ---- ParseSqlExpr : point d entree principal ----------------- }

Function ParseSqlExpr : Integer;
Begin
  ParseSqlExpr := ParseOrExpr;
End;

{ ---- DumpExpr : affichage recursif de l AST d expression ----- }

Procedure DumpExpr(Idx : Integer; Indent : Integer);
Var
  I  : Integer;
  Sp : TString;
Begin
  If Idx < 0 Then Exit;
  If Idx >= ASTCount Then Exit;
  Sp := '';
  For I := 1 To Indent Do
    Sp := Sp + '  ';
  WriteLn(Sp, NodeKindName(ASTPool[Idx].Kind), ' [', ASTPool[Idx].Text, ']');
  For I := 0 To ASTPool[Idx].ChildCnt - 1 Do
    DumpExpr(ASTPool[Idx].Children[I], Indent + 1);
End;

{ ============================================================
  TODO 10 - PARSEUR SELECT (REQUETES DE LECTURE) [IMPLEMENTE]
  ============================================================ }

{ ---- Forward declaration ------------------------------------- }

Function ParseSelectStmt : Integer; Forward;

{ ---- ParseSelectItem : expression [AS alias] | * ------------- }

Function ParseSelectItem : Integer;
Var
  N, E, A : Integer;
Begin
  ParseSelectItem := -1;
  If Not ParseOk Then Exit;

  N := NewNode(ND_SELECT_ITEM, '', LexCurTok.Line, LexCurTok.Col);
  E := ParseSqlExpr;
  AddChild(N, E);

  { Alias optionnel : AS alias | alias (sans AS) }
  If KwIs(KW_AS) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Or (LexCurTok.Kind = TOK_STRING)
    Then
    Begin
      A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
      AddChild(N, A);
      Advance;
    End
    Else
      ParseError('alias attendu apres AS');
  End
  Else If (LexCurTok.Kind = TOK_IDENT) And (Not KwIs(KW_FROM)) And
          (Not KwIs(KW_WHERE)) And (Not KwIs(KW_GROUP)) And
          (Not KwIs(KW_HAVING)) And (Not KwIs(KW_ORDER)) And
          (Not KwIs(KW_UNION)) And (Not KwIs(KW_INTERSECT)) And
          (Not KwIs(KW_EXCEPT)) And (Not KwIs(KW_INTO)) And
          (Not TokIs(TOK_COMMA)) And (Not TokIs(TOK_EOF)) Then
  Begin
    { Alias implicite (sans AS) - seulement si c est un identifiant simple }
    A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
    AddChild(N, A);
    Advance;
  End;

  ParseSelectItem := N;
End;

{ ---- ParseTableHint : WITH (NOLOCK | READUNCOMMITTED | ...) - }

Function ParseTableHint : Integer;
Var
  N : Integer;
Begin
  ParseTableHint := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_WITH) Then Exit;
  Advance;
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      N := NewNode(ND_TABLE_HINT, LexCurTok.Text, LexCurTok.Line,
                   LexCurTok.Col);
      Advance;
      { Consommer les hints supplementaires separes par virgule }
      While TokIs(TOK_COMMA) And ParseOk Do
      Begin
        Advance;
        If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD)
        Then
          Advance;
      End;
    End
    Else
    Begin
      N := NewNode(ND_TABLE_HINT, '', LexCurTok.Line, LexCurTok.Col);
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres table hint');
    ParseTableHint := N;
  End
  Else
    ParseError('( attendu apres WITH');
End;

{ ---- ParseTableRef : nom_table [AS alias] [WITH (...)] ------- }

Function ParseTableRef : Integer;
Var
  N, A, H, Sub : Integer;
  Depth : Integer;
Begin
  ParseTableRef := -1;
  If Not ParseOk Then Exit;

  { Sous-requete derivee : (SELECT ...) [AS alias] }
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    If KwIs(KW_SELECT) Then
    Begin
      Sub := ParseSelectStmt;
      N := NewNode(ND_TABLE_REF, '(subquery)', LexCurTok.Line,
                   LexCurTok.Col);
      AddChild(N, Sub);
    End
    Else
    Begin
      { Simple parenthesage de table ref }
      N := NewNode(ND_TABLE_REF, '()', LexCurTok.Line, LexCurTok.Col);
      { Consommer jusqu a ) }
      Depth := 1;
      While (Depth > 0) And (Not TokIs(TOK_EOF)) And ParseOk Do
      Begin
        If TokIs(TOK_LPAREN) Then Inc(Depth)
        Else If TokIs(TOK_RPAREN) Then Dec(Depth);
        If Depth > 0 Then Advance;
      End;
    End;
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres sous-requete');
    { Alias optionnel }
    If KwIs(KW_AS) Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
        AddChild(N, A);
        Advance;
      End;
    End
    Else If (LexCurTok.Kind = TOK_IDENT) And (Not KwIs(KW_ON)) And
            (Not KwIs(KW_WHERE)) And (Not KwIs(KW_JOIN)) And
            (Not KwIs(KW_INNER)) And (Not KwIs(KW_LEFT)) And
            (Not KwIs(KW_RIGHT)) And (Not KwIs(KW_FULL)) And
            (Not KwIs(KW_CROSS)) And (Not KwIs(KW_GROUP)) And
            (Not KwIs(KW_ORDER)) And (Not KwIs(KW_HAVING)) And
            (Not KwIs(KW_UNION)) Then
    Begin
      A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line,
                   LexCurTok.Col);
      AddChild(N, A);
      Advance;
    End;
    ParseTableRef := N;
    Exit;
  End;

  { Table simple : [schema.]table ou [delimited] }
  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) And
     (LexCurTok.Kind <> TOK_DELIM_IDENT) And (LexCurTok.Kind <> TOK_TEMPOBJ)
  Then
  Begin
    ParseError('nom de table attendu');
    Exit;
  End;

  N := NewNode(ND_TABLE_REF, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
  Advance;

  { References pointees : schema.table ou database.schema.table }
  While TokIs(TOK_DOT) And ParseOk Do
  Begin
    ASTPool[N].Text := ASTPool[N].Text + '.';
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      ASTPool[N].Text := ASTPool[N].Text + LexCurTok.Text;
      Advance;
    End;
  End;

  { Alias optionnel : AS alias ou alias implicite }
  If KwIs(KW_AS) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line,
                   LexCurTok.Col);
      AddChild(N, A);
      Advance;
    End;
  End
  Else If (LexCurTok.Kind = TOK_IDENT) And (Not KwIs(KW_ON)) And
          (Not KwIs(KW_WHERE)) And (Not KwIs(KW_JOIN)) And
          (Not KwIs(KW_INNER)) And (Not KwIs(KW_LEFT)) And
          (Not KwIs(KW_RIGHT)) And (Not KwIs(KW_FULL)) And
          (Not KwIs(KW_CROSS)) And (Not KwIs(KW_GROUP)) And
          (Not KwIs(KW_ORDER)) And (Not KwIs(KW_HAVING)) And
          (Not KwIs(KW_UNION)) And (Not KwIs(KW_WITH)) And
          (Not KwIs(KW_SET)) And (Not KwIs(KW_APPLY)) And
          (Not KwIs(KW_PIVOT)) And (Not KwIs(KW_UNPIVOT)) Then
  Begin
    A := NewNode(ND_ALIAS, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    AddChild(N, A);
    Advance;
  End;

  { Table hint : WITH (NOLOCK) }
  If KwIs(KW_WITH) Then
  Begin
    H := ParseTableHint;
    If H >= 0 Then
      AddChild(N, H);
  End;

  ParseTableRef := N;
End;

{ ---- ParseJoinType : retourne le texte du type de jointure --- }

Function ParseJoinType : TTokenText;
Var
  JT : TTokenText;
Begin
  JT := '';
  If KwIs(KW_INNER) Then
  Begin
    JT := 'INNER';
    Advance;
  End
  Else If KwIs(KW_LEFT) Then
  Begin
    JT := 'LEFT';
    Advance;
    If KwIs(KW_OUTER) Then
    Begin
      JT := 'LEFT OUTER';
      Advance;
    End;
  End
  Else If KwIs(KW_RIGHT) Then
  Begin
    JT := 'RIGHT';
    Advance;
    If KwIs(KW_OUTER) Then
    Begin
      JT := 'RIGHT OUTER';
      Advance;
    End;
  End
  Else If KwIs(KW_FULL) Then
  Begin
    JT := 'FULL';
    Advance;
    If KwIs(KW_OUTER) Then
    Begin
      JT := 'FULL OUTER';
      Advance;
    End;
  End
  Else If KwIs(KW_CROSS) Then
  Begin
    JT := 'CROSS';
    Advance;
    { CROSS APPLY }
    If KwIs(KW_APPLY) Then
    Begin
      ParseJoinType := 'CROSS APPLY';
      Advance;
      Exit;
    End;
  End;
  { JOIN keyword }
  If KwIs(KW_JOIN) Then
  Begin
    If JT = '' Then JT := 'INNER';
    Advance;
  End;
  ParseJoinType := JT;
End;

{ ---- IsJoinKeyword : verifie si le token courant debute un JOIN }

Function IsJoinKeyword : Boolean;
Begin
  IsJoinKeyword := KwIs(KW_JOIN) Or KwIs(KW_INNER) Or KwIs(KW_LEFT) Or
                   KwIs(KW_RIGHT) Or KwIs(KW_FULL) Or KwIs(KW_CROSS);
End;

{ ---- ParseFromClause : FROM table_refs [joins ...] ----------- }

Function ParseFromClause : Integer;
Var
  N, T, J, Cond : Integer;
  JType : TTokenText;
Begin
  ParseFromClause := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_FROM) Then Exit;

  N := NewNode(ND_FROM_CLAUSE, 'FROM', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip FROM }

  { Premiere reference de table }
  T := ParseTableRef;
  AddChild(N, T);

  { Tables supplementaires separees par virgule }
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance;
    T := ParseTableRef;
    AddChild(N, T);
  End;

  { Jointures }
  While IsJoinKeyword And ParseOk Do
  Begin
    JType := ParseJoinType;

    { CROSS/OUTER APPLY }
    If (JType = 'CROSS APPLY') Or (JType = 'OUTER APPLY') Then
    Begin
      J := NewNode(ND_APPLY, JType, LexCurTok.Line, LexCurTok.Col);
      T := ParseTableRef;
      AddChild(J, T);
      AddChild(N, J);
    End
    Else
    Begin
      J := NewNode(ND_JOIN, JType, LexCurTok.Line, LexCurTok.Col);
      T := ParseTableRef;
      AddChild(J, T);

      { ON condition (sauf pour CROSS JOIN) }
      If KwIs(KW_ON) Then
      Begin
        Advance;
        Cond := ParseSqlExpr;
        AddChild(J, Cond);
      End;

      AddChild(N, J);
    End;
  End;

  { OUTER APPLY }
  If KwIs(KW_OUTER) Then
  Begin
    Advance;
    If KwIs(KW_APPLY) Then
    Begin
      Advance;
      J := NewNode(ND_APPLY, 'OUTER APPLY', LexCurTok.Line, LexCurTok.Col);
      T := ParseTableRef;
      AddChild(J, T);
      AddChild(N, J);
    End;
  End;

  ParseFromClause := N;
End;

{ ---- ParseWhereClause : WHERE condition ---------------------- }

Function ParseWhereClause : Integer;
Var
  N, Cond : Integer;
Begin
  ParseWhereClause := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_WHERE) Then Exit;

  N := NewNode(ND_WHERE_CLAUSE, 'WHERE', LexCurTok.Line, LexCurTok.Col);
  Advance;
  Cond := ParseSqlExpr;
  AddChild(N, Cond);
  ParseWhereClause := N;
End;

{ ---- ParseGroupBy : GROUP BY col1, col2 ... ------------------ }

Function ParseGroupBy : Integer;
Var
  N, E : Integer;
Begin
  ParseGroupBy := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_GROUP) Then Exit;

  N := NewNode(ND_GROUP_BY, 'GROUP BY', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip GROUP }
  If KwIs(KW_BY) Then
    Advance
  Else
    ParseError('BY attendu apres GROUP');

  E := ParseSqlExpr;
  AddChild(N, E);
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance;
    E := ParseSqlExpr;
    AddChild(N, E);
  End;

  { WITH ROLLUP | WITH CUBE (ignorer pour le moment) }
  If KwIs(KW_WITH) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      ASTPool[N].Text := ASTPool[N].Text + ' WITH ' +
                         StrUpperCase(LexCurTok.Text);
      Advance;
    End;
  End;

  ParseGroupBy := N;
End;

{ ---- ParseHaving : HAVING condition -------------------------- }

Function ParseHaving : Integer;
Var
  N, Cond : Integer;
Begin
  ParseHaving := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_HAVING) Then Exit;

  N := NewNode(ND_HAVING, 'HAVING', LexCurTok.Line, LexCurTok.Col);
  Advance;
  Cond := ParseSqlExpr;
  AddChild(N, Cond);
  ParseHaving := N;
End;

{ ---- ParseOrderBy : ORDER BY expr [ASC|DESC], ... ------------ }

Function ParseOrderBy : Integer;
Var
  N, Item, E : Integer;
  Dir : TTokenText;
Begin
  ParseOrderBy := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_ORDER) Then Exit;

  N := NewNode(ND_ORDER_BY, 'ORDER BY', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip ORDER }
  If KwIs(KW_BY) Then
    Advance
  Else
    ParseError('BY attendu apres ORDER');

  E := ParseSqlExpr;
  Dir := 'ASC'; { defaut }
  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'ASC' Then
    Begin
      Dir := 'ASC';
      Advance;
    End
    Else If StrUpperCase(LexCurTok.Text) = 'DESC' Then
    Begin
      Dir := 'DESC';
      Advance;
    End;
  End;
  Item := NewNode(ND_ORDER_ITEM, Dir, LexCurTok.Line, LexCurTok.Col);
  AddChild(Item, E);
  AddChild(N, Item);
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance;
    E := ParseSqlExpr;
    Dir := 'ASC';
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      If StrUpperCase(LexCurTok.Text) = 'ASC' Then
      Begin
        Dir := 'ASC';
        Advance;
      End
      Else If StrUpperCase(LexCurTok.Text) = 'DESC' Then
      Begin
        Dir := 'DESC';
        Advance;
      End;
    End;
    Item := NewNode(ND_ORDER_ITEM, Dir, LexCurTok.Line, LexCurTok.Col);
    AddChild(Item, E);
    AddChild(N, Item);
  End;

  { OFFSET n ROWS FETCH NEXT m ROWS ONLY }
  If KwIs(KW_OFFSET) Then
  Begin
    Advance;
    E := ParseSqlExpr;
    Item := NewNode(ND_OFFSET, 'OFFSET', LexCurTok.Line, LexCurTok.Col);
    AddChild(Item, E);
    { ROWS }
    If KwIs(KW_ROWS) Then Advance;
    { FETCH NEXT m ROWS ONLY }
    If KwIs(KW_FETCH) Then
    Begin
      Advance;
      If KwIs(KW_NEXT) Then Advance;
      E := ParseSqlExpr;
      AddChild(Item, E);
      If KwIs(KW_ROWS) Then Advance;
      If KwIs(KW_ONLY) Then Advance;
    End;
    AddChild(N, Item);
  End;

  ParseOrderBy := N;
End;

{ ---- ParseSelectStmt : SELECT complet ------------------------ }

Function ParseSelectStmt : Integer;
Var
  Sel, Item, T, N, Sub, CteNode : Integer;
Begin
  ParseSelectStmt := -1;
  If Not ParseOk Then Exit;

  { WITH cte_name AS (SELECT ...) ... SELECT ... }
  If KwIs(KW_WITH) Then
  Begin
    Sel := NewNode(ND_SELECT_STMT, 'WITH', LexCurTok.Line, LexCurTok.Col);
    While KwIs(KW_WITH) And ParseOk Do
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        CteNode := NewNode(ND_CTE, LexCurTok.Text, LexCurTok.Line,
                           LexCurTok.Col);
        Advance;
        If KwIs(KW_AS) Then
          Advance
        Else
          ParseError('AS attendu dans CTE');
        If TokIs(TOK_LPAREN) Then
        Begin
          Advance;
          Sub := ParseSelectStmt;
          AddChild(CteNode, Sub);
          If TokIs(TOK_RPAREN) Then
            Advance
          Else
            ParseError(') attendu apres CTE');
        End;
        AddChild(Sel, CteNode);
      End;
      If TokIs(TOK_COMMA) Then
        Advance { CTE supplementaire }
      Else
        Break; { sortir de la boucle WITH }
    End;
    { Le SELECT principal suit }
    If KwIs(KW_SELECT) Then
    Begin
      Sub := ParseSelectStmt;
      AddChild(Sel, Sub);
    End
    Else
      ParseError('SELECT attendu apres WITH ... AS (...)');
    ParseSelectStmt := Sel;
    Exit;
  End;

  { SELECT }
  If Not KwIs(KW_SELECT) Then
  Begin
    ParseError('SELECT attendu');
    Exit;
  End;

  Sel := NewNode(ND_SELECT_STMT, 'SELECT', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip SELECT }

  { ALL | DISTINCT }
  If KwIs(KW_ALL) Then
  Begin
    ASTPool[Sel].Text := 'SELECT ALL';
    Advance;
  End
  Else If KwIs(KW_DISTINCT) Then
  Begin
    ASTPool[Sel].Text := 'SELECT DISTINCT';
    Advance;
  End;

  { TOP n [PERCENT] [WITH TIES] }
  If KwIs(KW_TOP) Then
  Begin
    Advance;
    T := NewNode(ND_TOP_CLAUSE, 'TOP', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      N := ParseSqlExpr;
      AddChild(T, N);
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres TOP(n)');
    End
    Else
    Begin
      N := ParseSqlExpr;
      AddChild(T, N);
    End;
    If KwIs(KW_PERCENT) Then
    Begin
      ASTPool[T].Text := 'TOP PERCENT';
      Advance;
    End;
    If KwIs(KW_WITH) Then
    Begin
      Advance;
      If KwIs(KW_TIES) Then
      Begin
        ASTPool[T].Text := ASTPool[T].Text + ' WITH TIES';
        Advance;
      End;
    End;
    AddChild(Sel, T);
  End;

  { Liste de colonnes SELECT }
  Item := ParseSelectItem;
  AddChild(Sel, Item);
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance;
    Item := ParseSelectItem;
    AddChild(Sel, Item);
  End;

  { INTO table (SELECT INTO) }
  If KwIs(KW_INTO) Then
  Begin
    Advance;
    N := NewNode(ND_SELECT_INTO, '', LexCurTok.Line, LexCurTok.Col);
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_TEMPOBJ) Or (LexCurTok.Kind = TOK_DELIM_IDENT)
    Then
    Begin
      ASTPool[N].Text := LexCurTok.Text;
      Advance;
    End;
    AddChild(Sel, N);
  End;

  { FROM }
  If KwIs(KW_FROM) Then
  Begin
    N := ParseFromClause;
    AddChild(Sel, N);
  End;

  { WHERE }
  If KwIs(KW_WHERE) Then
  Begin
    N := ParseWhereClause;
    AddChild(Sel, N);
  End;

  { GROUP BY }
  If KwIs(KW_GROUP) Then
  Begin
    N := ParseGroupBy;
    AddChild(Sel, N);
  End;

  { HAVING }
  If KwIs(KW_HAVING) Then
  Begin
    N := ParseHaving;
    AddChild(Sel, N);
  End;

  { ORDER BY }
  If KwIs(KW_ORDER) Then
  Begin
    N := ParseOrderBy;
    AddChild(Sel, N);
  End;

  { FOR XML | FOR JSON }
  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'FOR' Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        If StrUpperCase(LexCurTok.Text) = 'XML' Then
        Begin
          N := NewNode(ND_FOR_XML, 'FOR XML', LexCurTok.Line,
                       LexCurTok.Col);
          Advance;
          { Mode : PATH, RAW, AUTO, EXPLICIT }
          If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD)
          Then
          Begin
            ASTPool[N].Text := 'FOR XML ' + StrUpperCase(LexCurTok.Text);
            Advance;
          End;
          AddChild(Sel, N);
        End
        Else If StrUpperCase(LexCurTok.Text) = 'JSON' Then
        Begin
          N := NewNode(ND_FOR_JSON, 'FOR JSON', LexCurTok.Line,
                       LexCurTok.Col);
          Advance;
          If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD)
          Then
          Begin
            ASTPool[N].Text := 'FOR JSON ' + StrUpperCase(LexCurTok.Text);
            Advance;
          End;
          AddChild(Sel, N);
        End;
      End;
    End;
  End;

  { UNION [ALL] / INTERSECT / EXCEPT }
  If KwIs(KW_UNION) Then
  Begin
    Advance;
    N := NewNode(ND_UNION, 'UNION', LexCurTok.Line, LexCurTok.Col);
    If KwIs(KW_ALL) Then
    Begin
      ASTPool[N].Text := 'UNION ALL';
      Advance;
    End;
    AddChild(N, Sel);
    Sub := ParseSelectStmt;
    AddChild(N, Sub);
    ParseSelectStmt := N;
    Exit;
  End;
  If KwIs(KW_INTERSECT) Then
  Begin
    Advance;
    N := NewNode(ND_INTERSECT_OP, 'INTERSECT', LexCurTok.Line,
                 LexCurTok.Col);
    AddChild(N, Sel);
    Sub := ParseSelectStmt;
    AddChild(N, Sub);
    ParseSelectStmt := N;
    Exit;
  End;
  If KwIs(KW_EXCEPT) Then
  Begin
    Advance;
    N := NewNode(ND_EXCEPT_OP, 'EXCEPT', LexCurTok.Line, LexCurTok.Col);
    AddChild(N, Sel);
    Sub := ParseSelectStmt;
    AddChild(N, Sub);
    ParseSelectStmt := N;
    Exit;
  End;

  ParseSelectStmt := Sel;
End;

{ ============================================================
  TODO 11 - PARSEUR INSERT / UPDATE / DELETE / MERGE [IMPLEMENTE]
  ============================================================ }

{ ---- Forward declarations ------------------------------------ }

Function ParseInsertStmt : Integer; Forward;
Function ParseUpdateStmt : Integer; Forward;
Function ParseDeleteStmt : Integer; Forward;
Function ParseTruncateStmt : Integer; Forward;
Function ParseMergeStmt : Integer; Forward;

{ ---- ParseOutputClause : OUTPUT INSERTED.*, DELETED.* -------- }
{ OUTPUT col1, INSERTED.col2, DELETED.col3 [INTO @table|table]   }

Function ParseOutputClause : Integer;
Var
  N, Item, E : Integer;
  Prefix     : TString;
Begin
  ParseOutputClause := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_OUTPUT) Then Exit;

  N := NewNode(ND_OUTPUT_CLAUSE, 'OUTPUT', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip OUTPUT }

  { Liste d items OUTPUT }
  Repeat
    Item := NewNode(ND_OUTPUT_ITEM, '', LexCurTok.Line, LexCurTok.Col);
    { INSERTED.col, DELETED.col, ou expression }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      Prefix := StrUpperCase(LexCurTok.Text);
      If (Prefix = 'INSERTED') Or (Prefix = 'DELETED') Then
      Begin
        ASTPool[Item].Text := Prefix;
        Advance;
        If TokIs(TOK_DOT) Then
        Begin
          Advance;
          If TokIs(TOK_STAR) Then
          Begin
            ASTPool[Item].Text := Prefix + '.*';
            Advance;
          End
          Else If (LexCurTok.Kind = TOK_IDENT) Or
                  (LexCurTok.Kind = TOK_KEYWORD) Or
                  (LexCurTok.Kind = TOK_DELIM_IDENT) Then
          Begin
            ASTPool[Item].Text := Prefix + '.' + LexCurTok.Text;
            Advance;
          End;
        End;
      End
      Else
      Begin
        E := ParseSqlExpr;
        AddChild(Item, E);
      End;
    End
    Else
    Begin
      E := ParseSqlExpr;
      AddChild(Item, E);
    End;

    { Alias optionnel : AS alias }
    If KwIs(KW_AS) Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        ASTPool[Item].Text := ASTPool[Item].Text + ' AS ' + LexCurTok.Text;
        Advance;
      End;
    End;

    AddChild(N, Item);

    If TokIs(TOK_COMMA) Then
      Advance
    Else
      Break;
  Until Not ParseOk;

  { INTO @table_var | table optionnel }
  If KwIs(KW_INTO) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_VARIABLE) Or (LexCurTok.Kind = TOK_IDENT) Or
       (LexCurTok.Kind = TOK_KEYWORD) Or (LexCurTok.Kind = TOK_TEMPOBJ) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      ASTPool[N].Text := 'OUTPUT INTO ' + LexCurTok.Text;
      Advance;
      { Liste de colonnes optionnelle }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And (Not TokIs(TOK_RPAREN)) And
              (Not TokIs(TOK_EOF)) Do
        Begin
          Advance;
          If TokIs(TOK_COMMA) Then Advance;
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
    End;
  End;

  ParseOutputClause := N;
End;

{ ---- ParseColList : (col1, col2, col3) ----------------------- }

Function ParseColList : Integer;
Var
  N, C : Integer;
Begin
  ParseColList := -1;
  If Not ParseOk Then Exit;
  If Not TokIs(TOK_LPAREN) Then Exit;

  N := NewNode(ND_COL_LIST, '', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip ( }

  While ParseOk And (Not TokIs(TOK_RPAREN)) And (Not TokIs(TOK_EOF)) Do
  Begin
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      C := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line, LexCurTok.Col);
      AddChild(N, C);
      Advance;
    End
    Else
    Begin
      ParseError('nom de colonne attendu');
      Exit;
    End;
    If TokIs(TOK_COMMA) Then
      Advance
    Else
      Break;
  End;

  If TokIs(TOK_RPAREN) Then
    Advance
  Else
    ParseError(') attendu apres liste de colonnes');

  ParseColList := N;
End;

{ ---- ParseTableName : nom de table (dotted) ------------------ }
{ Supporte: table, schema.table, db.schema.table, server.db.schema.table }

Function ParseTableName : Integer;
Var
  N    : Integer;
  Name : TString;
Begin
  ParseTableName := -1;
  If Not ParseOk Then Exit;

  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) And
     (LexCurTok.Kind <> TOK_DELIM_IDENT) And
     (LexCurTok.Kind <> TOK_TEMPOBJ) And
     (LexCurTok.Kind <> TOK_VARIABLE) Then
  Begin
    ParseError('nom de table attendu');
    Exit;
  End;

  Name := LexCurTok.Text;
  N := NewNode(ND_TABLE_REF, Name, LexCurTok.Line, LexCurTok.Col);
  Advance;

  { Dotted name: schema.table, db.schema.table }
  While TokIs(TOK_DOT) And ParseOk Do
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      Name := Name + '.' + LexCurTok.Text;
      ASTPool[N].Text := Name;
      Advance;
    End
    Else
      Break;
  End;

  { Alias optionnel }
  If KwIs(KW_AS) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      ASTPool[N].Text := ASTPool[N].Text + ' AS ' + LexCurTok.Text;
      Advance;
    End;
  End;

  ParseTableName := N;
End;

{ ---- ParseInsertStmt ----------------------------------------- }
{ INSERT [INTO] table [(cols)] VALUES (...) | SELECT ... |       }
{ DEFAULT VALUES | EXEC procedure                                }

Function ParseInsertStmt : Integer;
Var
  Ins, Tbl, Cols, Vals, Row, E, Sub, N : Integer;
Begin
  ParseInsertStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_INSERT) Then
  Begin
    ParseError('INSERT attendu');
    Exit;
  End;

  Ins := NewNode(ND_INSERT_STMT, 'INSERT', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip INSERT }

  { TOP (n) optionnel }
  If KwIs(KW_TOP) Then
  Begin
    Advance;
    N := NewNode(ND_TOP_CLAUSE, 'TOP', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres TOP(n)');
    End
    Else
    Begin
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    If KwIs(KW_PERCENT) Then
    Begin
      ASTPool[N].Text := 'TOP PERCENT';
      Advance;
    End;
    AddChild(Ins, N);
  End;

  { INTO optionnel }
  If KwIs(KW_INTO) Then
    Advance;

  { Nom de la table cible }
  Tbl := ParseTableName;
  AddChild(Ins, Tbl);

  { Table hint WITH (...) optionnel }
  If KwIs(KW_WITH) Then
  Begin
    Advance;
    If TokIs(TOK_LPAREN) Then
    Begin
      N := NewNode(ND_TABLE_HINT, '', LexCurTok.Line, LexCurTok.Col);
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        ASTPool[N].Text := StrUpperCase(LexCurTok.Text);
        Advance;
      End;
      If TokIs(TOK_RPAREN) Then Advance;
      AddChild(Ins, N);
    End;
  End;

  { Liste de colonnes optionnelle (col1, col2, ...) }
  If TokIs(TOK_LPAREN) Then
  Begin
    { Attention: on doit distinguer (col_list) de VALUES (...) }
    { Si le token apres ( est un ident suivi de , ou ), c est une col list }
    { On utilise ParseColList }
    Cols := ParseColList;
    AddChild(Ins, Cols);
  End;

  { OUTPUT clause optionnelle }
  If KwIs(KW_OUTPUT) Then
  Begin
    N := ParseOutputClause;
    AddChild(Ins, N);
  End;

  { VALUES (...) | SELECT ... | DEFAULT VALUES | EXEC procedure }
  If KwIs(KW_VALUES) Then
  Begin
    Vals := NewNode(ND_VALUES_CLAUSE, 'VALUES', LexCurTok.Line,
                    LexCurTok.Col);
    Advance; { skip VALUES }

    { Supporter plusieurs rangees : VALUES (v1,v2),(v3,v4) }
    Repeat
      If TokIs(TOK_LPAREN) Then
      Begin
        Row := NewNode(ND_VALUES_ROW, '', LexCurTok.Line, LexCurTok.Col);
        Advance; { skip ( }
        { Liste de valeurs }
        While ParseOk And (Not TokIs(TOK_RPAREN)) And
              (Not TokIs(TOK_EOF)) Do
        Begin
          If (LexCurTok.Kind = TOK_IDENT) And
             (StrUpperCase(LexCurTok.Text) = 'DEFAULT') Then
          Begin
            E := NewNode(ND_DEFAULT_LIT, 'DEFAULT', LexCurTok.Line,
                         LexCurTok.Col);
            Advance;
          End
          Else
            E := ParseSqlExpr;
          AddChild(Row, E);
          If TokIs(TOK_COMMA) Then
            Advance
          Else
            Break;
        End;
        If TokIs(TOK_RPAREN) Then
          Advance
        Else
          ParseError(') attendu apres VALUES (...)');
        AddChild(Vals, Row);
      End
      Else
        Break;

      If TokIs(TOK_COMMA) Then
        Advance
      Else
        Break;
    Until Not ParseOk;

    AddChild(Ins, Vals);
  End
  Else If (LexCurTok.Kind = TOK_IDENT) And
          (StrUpperCase(LexCurTok.Text) = 'DEFAULT') Then
  Begin
    { DEFAULT VALUES }
    Advance;
    If KwIs(KW_VALUES) Then
      Advance
    Else
      ParseError('VALUES attendu apres DEFAULT');
    N := NewNode(ND_DEFAULT_VALUES, 'DEFAULT VALUES', LexCurTok.Line,
                 LexCurTok.Col);
    AddChild(Ins, N);
  End
  Else If KwIs(KW_SELECT) Or KwIs(KW_WITH) Then
  Begin
    { INSERT INTO table SELECT ... }
    Sub := ParseSelectStmt;
    AddChild(Ins, Sub);
  End
  Else If KwIs(KW_EXEC) Or KwIs(KW_EXECUTE) Then
  Begin
    { INSERT INTO table EXEC procedure }
    N := NewNode(ND_EXEC_INSERT, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance; { skip EXEC/EXECUTE }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      ASTPool[N].Text := 'EXEC ' + LexCurTok.Text;
      Advance;
      { Arguments optionnels }
      While ParseOk And (Not TokIs(TOK_SEMICOL)) And
            (Not TokIs(TOK_EOF)) And (Not KwIs(KW_OUTPUT)) Do
      Begin
        E := ParseSqlExpr;
        AddChild(N, E);
        If TokIs(TOK_COMMA) Then
          Advance
        Else
          Break;
      End;
    End
    Else If TokIs(TOK_LPAREN) Then
    Begin
      { EXEC('dynamic SQL') }
      ASTPool[N].Text := 'EXEC';
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
      If TokIs(TOK_RPAREN) Then Advance;
    End;
    AddChild(Ins, N);
  End;

  { OUTPUT clause finale optionnelle (si pas deja parsee) }
  If KwIs(KW_OUTPUT) Then
  Begin
    N := ParseOutputClause;
    AddChild(Ins, N);
  End;

  ParseInsertStmt := Ins;
End;

{ ---- ParseUpdateStmt ----------------------------------------- }
{ UPDATE [TOP(n)] table SET col=expr,... [OUTPUT ...] [FROM ...] }
{   [WHERE ...] }

Function ParseUpdateStmt : Integer;
Var
  Upd, Tbl, SetC, Item, E, N, Sub : Integer;
Begin
  ParseUpdateStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_UPDATE) Then
  Begin
    ParseError('UPDATE attendu');
    Exit;
  End;

  Upd := NewNode(ND_UPDATE_STMT, 'UPDATE', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip UPDATE }

  { TOP (n) optionnel }
  If KwIs(KW_TOP) Then
  Begin
    Advance;
    N := NewNode(ND_TOP_CLAUSE, 'TOP', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres TOP(n)');
    End
    Else
    Begin
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    If KwIs(KW_PERCENT) Then
    Begin
      ASTPool[N].Text := 'TOP PERCENT';
      Advance;
    End;
    AddChild(Upd, N);
  End;

  { Nom de la table cible }
  Tbl := ParseTableName;
  AddChild(Upd, Tbl);

  { SET clause }
  If Not KwIs(KW_SET) Then
  Begin
    ParseError('SET attendu apres UPDATE table');
    ParseUpdateStmt := Upd;
    Exit;
  End;
  Advance; { skip SET }

  SetC := NewNode(ND_SET_CLAUSE, 'SET', LexCurTok.Line, LexCurTok.Col);

  Repeat
    { colonne = expression }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Or
       (LexCurTok.Kind = TOK_VARIABLE) Then
    Begin
      Item := NewNode(ND_SET_ITEM, LexCurTok.Text, LexCurTok.Line,
                      LexCurTok.Col);
      Advance;
      { dotted : table.col }
      If TokIs(TOK_DOT) Then
      Begin
        Advance;
        If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
           (LexCurTok.Kind = TOK_DELIM_IDENT) Then
        Begin
          ASTPool[Item].Text := ASTPool[Item].Text + '.' + LexCurTok.Text;
          Advance;
        End;
      End;
      { Operateurs d assignation : =, +=, -=, *=, /=, %=, &=, |=, ^= }
      If TokIs(TOK_EQ) Then
        Advance
      Else
      Begin
        { Supporter +=, -=, etc. (combines en un seul token ou 2) }
        If (LexCurTok.Kind = TOK_PLUS) Or (LexCurTok.Kind = TOK_MINUS) Or
           (LexCurTok.Kind = TOK_STAR) Or (LexCurTok.Kind = TOK_SLASH) Or
           (LexCurTok.Kind = TOK_PERCENT) Then
        Begin
          ASTPool[Item].Text := ASTPool[Item].Text + ' ' + LexCurTok.Text;
          Advance;
          If TokIs(TOK_EQ) Then
            Advance;
        End
        Else
          ParseError('= attendu dans SET colonne = expression');
      End;
      { Valeur }
      E := ParseSqlExpr;
      AddChild(Item, E);
      AddChild(SetC, Item);
    End
    Else
    Begin
      ParseError('colonne attendue dans SET');
      Break;
    End;

    If TokIs(TOK_COMMA) Then
      Advance
    Else
      Break;
  Until Not ParseOk;

  AddChild(Upd, SetC);

  { OUTPUT clause optionnelle }
  If KwIs(KW_OUTPUT) Then
  Begin
    N := ParseOutputClause;
    AddChild(Upd, N);
  End;

  { FROM clause optionnelle (UPDATE ... SET ... FROM ...) }
  If KwIs(KW_FROM) Then
  Begin
    Advance;
    Sub := NewNode(ND_FROM_CLAUSE, 'FROM', LexCurTok.Line, LexCurTok.Col);
    N := ParseTableName;
    AddChild(Sub, N);

    { Jointures optionnelles dans FROM }
    While ParseOk And
          (KwIs(KW_JOIN) Or KwIs(KW_INNER) Or KwIs(KW_LEFT) Or
           KwIs(KW_RIGHT) Or KwIs(KW_FULL) Or KwIs(KW_CROSS)) Do
    Begin
      Item := NewNode(ND_JOIN, '', LexCurTok.Line, LexCurTok.Col);
      { Determiner le type de jointure }
      If KwIs(KW_INNER) Then
      Begin
        ASTPool[Item].Text := 'INNER JOIN';
        Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_LEFT) Then
      Begin
        ASTPool[Item].Text := 'LEFT JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_RIGHT) Then
      Begin
        ASTPool[Item].Text := 'RIGHT JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_FULL) Then
      Begin
        ASTPool[Item].Text := 'FULL JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_CROSS) Then
      Begin
        ASTPool[Item].Text := 'CROSS JOIN';
        Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_JOIN) Then
      Begin
        ASTPool[Item].Text := 'JOIN';
        Advance;
      End;
      { Table de jointure }
      N := ParseTableName;
      AddChild(Item, N);
      { ON condition }
      If KwIs(KW_ON) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(Item, E);
      End;
      AddChild(Sub, Item);
    End;

    AddChild(Upd, Sub);
  End;

  { WHERE clause optionnelle }
  If KwIs(KW_WHERE) Then
  Begin
    Advance;
    N := NewNode(ND_WHERE_CLAUSE, 'WHERE', LexCurTok.Line, LexCurTok.Col);
    E := ParseSqlExpr;
    AddChild(N, E);
    AddChild(Upd, N);
  End;

  ParseUpdateStmt := Upd;
End;

{ ---- ParseDeleteStmt ----------------------------------------- }
{ DELETE [TOP(n)] [FROM] table [OUTPUT ...] [FROM ...] [WHERE ...] }

Function ParseDeleteStmt : Integer;
Var
  Del, Tbl, N, E, Sub, Item : Integer;
Begin
  ParseDeleteStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_DELETE) Then
  Begin
    ParseError('DELETE attendu');
    Exit;
  End;

  Del := NewNode(ND_DELETE_STMT, 'DELETE', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip DELETE }

  { TOP (n) optionnel }
  If KwIs(KW_TOP) Then
  Begin
    Advance;
    N := NewNode(ND_TOP_CLAUSE, 'TOP', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres TOP(n)');
    End
    Else
    Begin
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    If KwIs(KW_PERCENT) Then
    Begin
      ASTPool[N].Text := 'TOP PERCENT';
      Advance;
    End;
    AddChild(Del, N);
  End;

  { FROM optionnel (DELETE FROM table ou DELETE table) }
  If KwIs(KW_FROM) Then
    Advance;

  { Nom de la table cible }
  Tbl := ParseTableName;
  AddChild(Del, Tbl);

  { Table hint WITH (...) optionnel }
  If KwIs(KW_WITH) Then
  Begin
    Advance;
    If TokIs(TOK_LPAREN) Then
    Begin
      N := NewNode(ND_TABLE_HINT, '', LexCurTok.Line, LexCurTok.Col);
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        ASTPool[N].Text := StrUpperCase(LexCurTok.Text);
        Advance;
      End;
      If TokIs(TOK_RPAREN) Then Advance;
      AddChild(Del, N);
    End;
  End;

  { OUTPUT clause optionnelle }
  If KwIs(KW_OUTPUT) Then
  Begin
    N := ParseOutputClause;
    AddChild(Del, N);
  End;

  { FROM clause optionnelle (DELETE ... FROM ... JOIN ...) }
  If KwIs(KW_FROM) Then
  Begin
    Advance;
    Sub := NewNode(ND_FROM_CLAUSE, 'FROM', LexCurTok.Line, LexCurTok.Col);
    N := ParseTableName;
    AddChild(Sub, N);

    { Jointures dans FROM }
    While ParseOk And
          (KwIs(KW_JOIN) Or KwIs(KW_INNER) Or KwIs(KW_LEFT) Or
           KwIs(KW_RIGHT) Or KwIs(KW_FULL) Or KwIs(KW_CROSS)) Do
    Begin
      Item := NewNode(ND_JOIN, '', LexCurTok.Line, LexCurTok.Col);
      If KwIs(KW_INNER) Then
      Begin
        ASTPool[Item].Text := 'INNER JOIN';
        Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_LEFT) Then
      Begin
        ASTPool[Item].Text := 'LEFT JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_RIGHT) Then
      Begin
        ASTPool[Item].Text := 'RIGHT JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_FULL) Then
      Begin
        ASTPool[Item].Text := 'FULL JOIN';
        Advance;
        If KwIs(KW_OUTER) Then Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_CROSS) Then
      Begin
        ASTPool[Item].Text := 'CROSS JOIN';
        Advance;
        If KwIs(KW_JOIN) Then Advance;
      End
      Else If KwIs(KW_JOIN) Then
      Begin
        ASTPool[Item].Text := 'JOIN';
        Advance;
      End;
      N := ParseTableName;
      AddChild(Item, N);
      If KwIs(KW_ON) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(Item, E);
      End;
      AddChild(Sub, Item);
    End;

    AddChild(Del, Sub);
  End;

  { WHERE clause optionnelle }
  If KwIs(KW_WHERE) Then
  Begin
    Advance;
    N := NewNode(ND_WHERE_CLAUSE, 'WHERE', LexCurTok.Line, LexCurTok.Col);
    E := ParseSqlExpr;
    AddChild(N, E);
    AddChild(Del, N);
  End;

  ParseDeleteStmt := Del;
End;

{ ---- ParseTruncateStmt --------------------------------------- }
{ TRUNCATE TABLE table_name                                       }

Function ParseTruncateStmt : Integer;
Var
  N, Tbl : Integer;
Begin
  ParseTruncateStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_TRUNCATE) Then
  Begin
    ParseError('TRUNCATE attendu');
    Exit;
  End;

  N := NewNode(ND_TRUNCATE_STMT, 'TRUNCATE TABLE', LexCurTok.Line,
               LexCurTok.Col);
  Advance; { skip TRUNCATE }

  { TABLE optionnel (TRUNCATE TABLE est la syntaxe standard) }
  If KwIs(KW_TABLE) Then
    Advance;

  { Nom de la table }
  Tbl := ParseTableName;
  AddChild(N, Tbl);

  ParseTruncateStmt := N;
End;

{ ---- ParseMergeStmt ------------------------------------------ }
{ MERGE [INTO] target [AS alias]                                   }
{   USING source [AS alias] ON condition                           }
{   WHEN MATCHED [AND condition] THEN UPDATE SET ...               }
{   WHEN NOT MATCHED [BY TARGET] [AND cond] THEN INSERT ...       }
{   WHEN NOT MATCHED BY SOURCE [AND cond] THEN DELETE              }
{   [OUTPUT ...]                                                   }

Function ParseMergeStmt : Integer;
Var
  Mrg, Tbl, Src, W, N, E, Sub, SetC, Item, Vals, Row : Integer;
  WhenText : TString;
Begin
  ParseMergeStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_MERGE) Then
  Begin
    ParseError('MERGE attendu');
    Exit;
  End;

  Mrg := NewNode(ND_MERGE_STMT, 'MERGE', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip MERGE }

  { TOP (n) optionnel }
  If KwIs(KW_TOP) Then
  Begin
    Advance;
    N := NewNode(ND_TOP_CLAUSE, 'TOP', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(N, E);
      If TokIs(TOK_RPAREN) Then
        Advance
      Else
        ParseError(') attendu apres TOP(n)');
    End
    Else
    Begin
      E := ParseSqlExpr;
      AddChild(N, E);
    End;
    AddChild(Mrg, N);
  End;

  { INTO optionnel }
  If KwIs(KW_INTO) Then
    Advance;

  { Table cible }
  Tbl := ParseTableName;
  AddChild(Mrg, Tbl);

  { USING source }
  If Not KwIs(KW_USING) Then
  Begin
    ParseError('USING attendu apres MERGE INTO table');
    ParseMergeStmt := Mrg;
    Exit;
  End;
  Advance; { skip USING }

  { Source : table ou sous-requete }
  If TokIs(TOK_LPAREN) Then
  Begin
    { Sous-requete comme source }
    Advance;
    Sub := ParseSelectStmt;
    Src := NewNode(ND_SUBQUERY, 'USING', LexCurTok.Line, LexCurTok.Col);
    AddChild(Src, Sub);
    If TokIs(TOK_RPAREN) Then
      Advance
    Else
      ParseError(') attendu apres sous-requete USING');
    { Alias optionnel }
    If KwIs(KW_AS) Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        ASTPool[Src].Text := 'USING AS ' + LexCurTok.Text;
        Advance;
      End;
    End
    Else If (LexCurTok.Kind = TOK_IDENT) And (Not KwIs(KW_ON)) Then
    Begin
      ASTPool[Src].Text := 'USING AS ' + LexCurTok.Text;
      Advance;
    End;
    AddChild(Mrg, Src);
  End
  Else
  Begin
    Src := ParseTableName;
    AddChild(Mrg, Src);
  End;

  { ON condition }
  If Not KwIs(KW_ON) Then
  Begin
    ParseError('ON attendu apres MERGE ... USING ...');
    ParseMergeStmt := Mrg;
    Exit;
  End;
  Advance; { skip ON }
  E := ParseSqlExpr;
  N := NewNode(ND_COMPARE, 'ON', LexCurTok.Line, LexCurTok.Col);
  AddChild(N, E);
  AddChild(Mrg, N);

  { WHEN clauses (une ou plusieurs) }
  While KwIs(KW_WHEN) And ParseOk Do
  Begin
    W := NewNode(ND_MERGE_WHEN, '', LexCurTok.Line, LexCurTok.Col);
    Advance; { skip WHEN }

    WhenText := 'WHEN ';

    { MATCHED | NOT MATCHED [BY TARGET|SOURCE] }
    If KwIs(KW_NOT) Then
    Begin
      WhenText := WhenText + 'NOT ';
      Advance;
    End;

    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      If StrUpperCase(LexCurTok.Text) = 'MATCHED' Then
      Begin
        WhenText := WhenText + 'MATCHED';
        Advance;
        { BY TARGET | BY SOURCE }
        If KwIs(KW_BY) Then
        Begin
          Advance;
          If (LexCurTok.Kind = TOK_IDENT) Or
             (LexCurTok.Kind = TOK_KEYWORD) Then
          Begin
            WhenText := WhenText + ' BY ' + StrUpperCase(LexCurTok.Text);
            Advance;
          End;
        End;
      End
      Else
      Begin
        WhenText := WhenText + StrUpperCase(LexCurTok.Text);
        Advance;
      End;
    End;

    ASTPool[W].Text := WhenText;

    { AND condition optionnelle }
    If KwIs(KW_AND) Then
    Begin
      Advance;
      E := ParseSqlExpr;
      AddChild(W, E);
    End;

    { THEN action }
    If KwIs(KW_THEN) Then
      Advance
    Else
      ParseError('THEN attendu dans clause WHEN');

    { Action : UPDATE SET ... | INSERT [(cols)] VALUES (...) | DELETE }
    If KwIs(KW_UPDATE) Then
    Begin
      Advance; { skip UPDATE }
      If KwIs(KW_SET) Then
        Advance; { skip SET }
      SetC := NewNode(ND_SET_CLAUSE, 'UPDATE SET', LexCurTok.Line,
                      LexCurTok.Col);
      Repeat
        If (LexCurTok.Kind = TOK_IDENT) Or
           (LexCurTok.Kind = TOK_KEYWORD) Or
           (LexCurTok.Kind = TOK_DELIM_IDENT) Or
           (LexCurTok.Kind = TOK_VARIABLE) Then
        Begin
          Item := NewNode(ND_SET_ITEM, LexCurTok.Text, LexCurTok.Line,
                          LexCurTok.Col);
          Advance;
          { dotted reference }
          If TokIs(TOK_DOT) Then
          Begin
            Advance;
            If (LexCurTok.Kind = TOK_IDENT) Or
               (LexCurTok.Kind = TOK_KEYWORD) Or
               (LexCurTok.Kind = TOK_DELIM_IDENT) Then
            Begin
              ASTPool[Item].Text := ASTPool[Item].Text + '.' +
                                    LexCurTok.Text;
              Advance;
            End;
          End;
          If TokIs(TOK_EQ) Then Advance;
          E := ParseSqlExpr;
          AddChild(Item, E);
          AddChild(SetC, Item);
        End
        Else
          Break;
        If TokIs(TOK_COMMA) Then
          Advance
        Else
          Break;
      Until Not ParseOk;
      AddChild(W, SetC);
    End
    Else If KwIs(KW_INSERT) Then
    Begin
      Advance; { skip INSERT }
      Sub := NewNode(ND_INSERT_STMT, 'MERGE INSERT', LexCurTok.Line,
                     LexCurTok.Col);
      { Liste de colonnes optionnelle }
      If TokIs(TOK_LPAREN) Then
      Begin
        N := ParseColList;
        AddChild(Sub, N);
      End;
      { VALUES (...) }
      If KwIs(KW_VALUES) Then
      Begin
        Advance;
        If TokIs(TOK_LPAREN) Then
        Begin
          Vals := NewNode(ND_VALUES_CLAUSE, 'VALUES', LexCurTok.Line,
                          LexCurTok.Col);
          Row := NewNode(ND_VALUES_ROW, '', LexCurTok.Line, LexCurTok.Col);
          Advance; { skip ( }
          While ParseOk And (Not TokIs(TOK_RPAREN)) And
                (Not TokIs(TOK_EOF)) Do
          Begin
            If (LexCurTok.Kind = TOK_IDENT) And
               (StrUpperCase(LexCurTok.Text) = 'DEFAULT') Then
            Begin
              E := NewNode(ND_DEFAULT_LIT, 'DEFAULT', LexCurTok.Line,
                           LexCurTok.Col);
              Advance;
            End
            Else
              E := ParseSqlExpr;
            AddChild(Row, E);
            If TokIs(TOK_COMMA) Then
              Advance
            Else
              Break;
          End;
          If TokIs(TOK_RPAREN) Then Advance;
          AddChild(Vals, Row);
          AddChild(Sub, Vals);
        End;
      End
      Else If (LexCurTok.Kind = TOK_IDENT) And
              (StrUpperCase(LexCurTok.Text) = 'DEFAULT') Then
      Begin
        Advance;
        If KwIs(KW_VALUES) Then Advance;
        N := NewNode(ND_DEFAULT_VALUES, 'DEFAULT VALUES', LexCurTok.Line,
                     LexCurTok.Col);
        AddChild(Sub, N);
      End;
      AddChild(W, Sub);
    End
    Else If KwIs(KW_DELETE) Then
    Begin
      N := NewNode(ND_DELETE_STMT, 'MERGE DELETE', LexCurTok.Line,
                   LexCurTok.Col);
      Advance; { skip DELETE }
      AddChild(W, N);
    End;

    AddChild(Mrg, W);
  End;

  { OUTPUT clause optionnelle }
  If KwIs(KW_OUTPUT) Then
  Begin
    N := ParseOutputClause;
    AddChild(Mrg, N);
  End;

  { Point-virgule optionnel (MERGE requiert ; en SQL Server) }
  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseMergeStmt := Mrg;
End;

{ ---- TODO 12 : Parseur DDL (CREATE / ALTER / DROP) ------------- }

{ Helper : lire un nom d objet (potentiellement qualifie schema.nom) }
Function ParseObjectName : Integer;
Var
  N    : Integer;
  Name : TString;
Begin
  ParseObjectName := -1;
  If Not ParseOk Then Exit;
  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) And
     (LexCurTok.Kind <> TOK_DELIM_IDENT) And
     (LexCurTok.Kind <> TOK_TEMPOBJ) Then
  Begin
    ParseError('nom d''objet attendu');
    Exit;
  End;
  Name := LexCurTok.Text;
  N := NewNode(ND_IDENT, Name, LexCurTok.Line, LexCurTok.Col);
  Advance;
  While TokIs(TOK_DOT) And ParseOk Do
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      Name := Name + '.' + LexCurTok.Text;
      ASTPool[N].Text := Name;
      Advance;
    End
    Else
      Break;
  End;
  ParseObjectName := N;
End;

{ Helper : sauter un bloc BEGIN ... END (pour corps de proc/func/trigger) }
Function ParseBodyBlock : Integer;
Var
  Blk   : Integer;
  Depth : Integer;
Begin
  ParseBodyBlock := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_BEGIN) Then
  Begin
    ParseError('BEGIN attendu');
    Exit;
  End;
  Blk := NewNode(ND_BODY_BLOCK, 'BEGIN...END', LexCurTok.Line,
                 LexCurTok.Col);
  Advance; { skip BEGIN }
  Depth := 1;
  While ParseOk And (Depth > 0) Do
  Begin
    If KwIs(KW_BEGIN) Then
    Begin
      Inc(Depth);
      Advance;
    End
    Else If KwIs(KW_END) Then
    Begin
      Dec(Depth);
      Advance;
    End
    Else If LexCurTok.Kind = TOK_EOF Then
    Begin
      ParseError('END attendu pour fermer le bloc BEGIN');
      Break;
    End
    Else
      Advance;
  End;
  ParseBodyBlock := Blk;
End;

{ Helper : parser les parametres d une proc/func (@p1 type, ...) }
Function ParseParamList : Integer;
Var
  PList, P, T : Integer;
Begin
  ParseParamList := -1;
  If Not ParseOk Then Exit;
  PList := NewNode(ND_ARG_LIST, 'PARAMS', LexCurTok.Line, LexCurTok.Col);
  { Parenthese ouvrante optionnelle }
  If TokIs(TOK_LPAREN) Then
    Advance;
  While ParseOk And (LexCurTok.Kind = TOK_VARIABLE) Do
  Begin
    P := NewNode(ND_PARAM_DEF, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance; { skip @param }
    { Type du parametre }
    T := ParseTypeRef;
    AddChild(P, T);
    { Valeur par defaut optionnelle : = expr }
    If TokIs(TOK_EQ) Then
    Begin
      Advance;
      T := ParseSqlExpr;
      AddChild(P, T);
    End;
    { OUTPUT optionnel }
    If KwIs(KW_OUTPUT) Then
      Advance;
    AddChild(PList, P);
    If TokIs(TOK_COMMA) Then
      Advance
    Else
      Break;
  End;
  If TokIs(TOK_RPAREN) Then
    Advance;
  ParseParamList := PList;
End;

{ Helper : parser une colonne d index (nom [ASC|DESC]) }
Function ParseIndexCol : Integer;
Var
  IC   : Integer;
  Dir  : TString;
Begin
  ParseIndexCol := -1;
  If Not ParseOk Then Exit;
  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) And
     (LexCurTok.Kind <> TOK_DELIM_IDENT) Then
  Begin
    ParseError('nom de colonne attendu dans l''index');
    Exit;
  End;
  Dir := 'ASC';
  IC := NewNode(ND_INDEX_COL, LexCurTok.Text, LexCurTok.Line,
                LexCurTok.Col);
  Advance;
  If KwIs(KW_ASC) Then
  Begin
    Dir := 'ASC';
    Advance;
  End
  Else If KwIs(KW_DESC) Then
  Begin
    Dir := 'DESC';
    Advance;
  End;
  ASTPool[IC].Text := ASTPool[IC].Text + ' ' + Dir;
  ParseIndexCol := IC;
End;

{ Helper : parser WITH (options) pour index }
Function ParseWithOptions : Integer;
Var
  W, Opt : Integer;
  OptName : TString;
Begin
  ParseWithOptions := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_WITH) Then Exit;
  Advance; { skip WITH }
  W := NewNode(ND_WITH_OPTION, 'WITH', LexCurTok.Line, LexCurTok.Col);
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    While ParseOk And Not TokIs(TOK_RPAREN) Do
    Begin
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        OptName := LexCurTok.Text;
        Advance;
        If TokIs(TOK_EQ) Then
        Begin
          Advance;
          OptName := OptName + '=' + LexCurTok.Text;
          Advance;
        End;
        Opt := NewNode(ND_IDENT, OptName, LexCurTok.Line, LexCurTok.Col);
        AddChild(W, Opt);
      End
      Else
        Advance;
      If TokIs(TOK_COMMA) Then
        Advance;
    End;
    If TokIs(TOK_RPAREN) Then
      Advance;
  End;
  ParseWithOptions := W;
End;

{ ---- CREATE TABLE ---------------------------------------------- }

Function ParseColumnDef : Integer;
Var
  CD, T, E, N : Integer;
  ColName     : TString;
Begin
  ParseColumnDef := -1;
  If Not ParseOk Then Exit;

  { Contrainte de niveau table ? }
  If KwIs(KW_CONSTRAINT) Or KwIs(KW_PRIMARY) Or KwIs(KW_UNIQUE) Or
     KwIs(KW_FOREIGN) Or KwIs(KW_CHECK) Then
  Begin
    CD := NewNode(ND_TABLE_CONSTR, '', LexCurTok.Line, LexCurTok.Col);
    { CONSTRAINT nom optionnel }
    If KwIs(KW_CONSTRAINT) Then
    Begin
      Advance;
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        ASTPool[CD].Text := LexCurTok.Text;
        Advance;
      End;
    End;
    If KwIs(KW_PRIMARY) Then
    Begin
      ASTPool[CD].Kind := ND_PK_CONSTRAINT;
      Advance; { skip PRIMARY }
      If KwIs(KW_KEY) Then
        Advance; { skip KEY }
      If KwIs(KW_CLUSTERED) Then
        Advance
      Else If KwIs(KW_NONCLUSTERED) Then
        Advance;
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) Do
        Begin
          N := ParseIndexCol;
          AddChild(CD, N);
          If TokIs(TOK_COMMA) Then Advance;
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
    End
    Else If KwIs(KW_UNIQUE) Then
    Begin
      ASTPool[CD].Kind := ND_UNIQUE_CONSTR;
      Advance; { skip UNIQUE }
      If KwIs(KW_CLUSTERED) Then
        Advance
      Else If KwIs(KW_NONCLUSTERED) Then
        Advance;
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) Do
        Begin
          N := ParseIndexCol;
          AddChild(CD, N);
          If TokIs(TOK_COMMA) Then Advance;
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
    End
    Else If KwIs(KW_FOREIGN) Then
    Begin
      ASTPool[CD].Kind := ND_FK_CONSTRAINT;
      Advance; { skip FOREIGN }
      If KwIs(KW_KEY) Then Advance;
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) Do
        Begin
          If (LexCurTok.Kind = TOK_IDENT) Or
             (LexCurTok.Kind = TOK_KEYWORD) Or
             (LexCurTok.Kind = TOK_DELIM_IDENT) Then
          Begin
            N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                         LexCurTok.Col);
            AddChild(CD, N);
            Advance;
          End;
          If TokIs(TOK_COMMA) Then Advance;
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
      If KwIs(KW_REFERENCES) Then
      Begin
        Advance;
        N := ParseObjectName;
        AddChild(CD, N);
        If TokIs(TOK_LPAREN) Then
        Begin
          Advance;
          While ParseOk And Not TokIs(TOK_RPAREN) Do
          Begin
            If (LexCurTok.Kind = TOK_IDENT) Or
               (LexCurTok.Kind = TOK_KEYWORD) Or
               (LexCurTok.Kind = TOK_DELIM_IDENT) Then
            Begin
              N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                           LexCurTok.Col);
              AddChild(CD, N);
              Advance;
            End;
            If TokIs(TOK_COMMA) Then Advance;
          End;
          If TokIs(TOK_RPAREN) Then Advance;
        End;
      End;
    End
    Else If KwIs(KW_CHECK) Then
    Begin
      ASTPool[CD].Kind := ND_CHECK_CONSTR;
      Advance; { skip CHECK }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(CD, E);
        If TokIs(TOK_RPAREN) Then Advance;
      End;
    End;
    ParseColumnDef := CD;
    Exit;
  End;

  { Colonne normale : nom type [contraintes de colonne] }
  If (LexCurTok.Kind <> TOK_IDENT) And (LexCurTok.Kind <> TOK_KEYWORD) And
     (LexCurTok.Kind <> TOK_DELIM_IDENT) Then
  Begin
    ParseError('nom de colonne attendu');
    Exit;
  End;

  ColName := LexCurTok.Text;
  CD := NewNode(ND_COL_DEF, ColName, LexCurTok.Line, LexCurTok.Col);
  Advance; { skip column name }

  { Type de donnees }
  T := ParseTypeRef;
  AddChild(CD, T);

  { Contraintes de colonne inline }
  While ParseOk And Not TokIs(TOK_COMMA) And Not TokIs(TOK_RPAREN) And
        (LexCurTok.Kind <> TOK_EOF) Do
  Begin
    If KwIs(KW_CONSTRAINT) Then
    Begin
      Advance; { skip CONSTRAINT }
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
        Advance; { skip constraint name }
    End;

    If KwIs(KW_NOT) Then
    Begin
      Advance; { skip NOT }
      If KwIs(KW_NULL) Then
      Begin
        N := NewNode(ND_IDENT, 'NOT NULL', LexCurTok.Line, LexCurTok.Col);
        AddChild(CD, N);
        Advance;
      End;
    End
    Else If KwIs(KW_NULL) Then
    Begin
      N := NewNode(ND_IDENT, 'NULL', LexCurTok.Line, LexCurTok.Col);
      AddChild(CD, N);
      Advance;
    End
    Else If KwIs(KW_PRIMARY) Then
    Begin
      N := NewNode(ND_PK_CONSTRAINT, 'PRIMARY KEY', LexCurTok.Line,
                   LexCurTok.Col);
      Advance; { skip PRIMARY }
      If KwIs(KW_KEY) Then Advance; { skip KEY }
      If KwIs(KW_CLUSTERED) Then
        Advance
      Else If KwIs(KW_NONCLUSTERED) Then
        Advance;
      AddChild(CD, N);
    End
    Else If KwIs(KW_UNIQUE) Then
    Begin
      N := NewNode(ND_UNIQUE_CONSTR, 'UNIQUE', LexCurTok.Line,
                   LexCurTok.Col);
      Advance;
      If KwIs(KW_CLUSTERED) Then
        Advance
      Else If KwIs(KW_NONCLUSTERED) Then
        Advance;
      AddChild(CD, N);
    End
    Else If KwIs(KW_DEFAULT) Then
    Begin
      Advance; { skip DEFAULT }
      N := NewNode(ND_DEFAULT_CONSTR, 'DEFAULT', LexCurTok.Line,
                   LexCurTok.Col);
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(N, E);
        If TokIs(TOK_RPAREN) Then Advance;
      End
      Else
      Begin
        E := ParseSqlExpr;
        AddChild(N, E);
      End;
      AddChild(CD, N);
    End
    Else If KwIs(KW_CHECK) Then
    Begin
      N := NewNode(ND_CHECK_CONSTR, 'CHECK', LexCurTok.Line,
                   LexCurTok.Col);
      Advance; { skip CHECK }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        AddChild(N, E);
        If TokIs(TOK_RPAREN) Then Advance;
      End;
      AddChild(CD, N);
    End
    Else If KwIs(KW_REFERENCES) Then
    Begin
      N := NewNode(ND_FK_CONSTRAINT, 'REFERENCES', LexCurTok.Line,
                   LexCurTok.Col);
      Advance; { skip REFERENCES }
      E := ParseObjectName;
      AddChild(N, E);
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) Do
        Begin
          If (LexCurTok.Kind = TOK_IDENT) Or
             (LexCurTok.Kind = TOK_KEYWORD) Or
             (LexCurTok.Kind = TOK_DELIM_IDENT) Then
          Begin
            E := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                         LexCurTok.Col);
            AddChild(N, E);
            Advance;
          End;
          If TokIs(TOK_COMMA) Then Advance;
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
      AddChild(CD, N);
    End
    Else If KwIs(KW_IDENTITY) Then
    Begin
      N := NewNode(ND_IDENTITY_SPEC, 'IDENTITY', LexCurTok.Line,
                   LexCurTok.Col);
      Advance; { skip IDENTITY }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        E := ParseSqlExpr; { seed }
        AddChild(N, E);
        If TokIs(TOK_COMMA) Then
        Begin
          Advance;
          E := ParseSqlExpr; { increment }
          AddChild(N, E);
        End;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
      AddChild(CD, N);
    End
    Else If KwIs(KW_COLLATE) Then
    Begin
      Advance; { skip COLLATE }
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        N := NewNode(ND_COLLATE, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
        AddChild(CD, N);
        Advance;
      End;
    End
    Else
      Break;
  End;

  ParseColumnDef := CD;
End;

Function ParseCreateTable : Integer;
Var
  CT, N : Integer;
Begin
  ParseCreateTable := -1;
  If Not ParseOk Then Exit;

  CT := NewNode(ND_CREATE_TABLE, 'CREATE TABLE', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de la table }
  N := ParseObjectName;
  AddChild(CT, N);

  { Liste de colonnes }
  If Not TokIs(TOK_LPAREN) Then
  Begin
    ParseError('( attendu apres nom de table dans CREATE TABLE');
    ParseCreateTable := CT;
    Exit;
  End;
  Advance; { skip ( }

  While ParseOk And Not TokIs(TOK_RPAREN) And
        (LexCurTok.Kind <> TOK_EOF) Do
  Begin
    N := ParseColumnDef;
    AddChild(CT, N);
    If TokIs(TOK_COMMA) Then
      Advance
    Else
      Break;
  End;

  If TokIs(TOK_RPAREN) Then
    Advance;

  { Point-virgule optionnel }
  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateTable := CT;
End;

{ ---- CREATE INDEX ---------------------------------------------- }

Function ParseCreateIndex(IsUnique : Boolean) : Integer;
Var
  CI, N, W : Integer;
  Lbl      : TString;
Begin
  ParseCreateIndex := -1;
  If Not ParseOk Then Exit;

  If IsUnique Then
    Lbl := 'CREATE UNIQUE INDEX'
  Else
    Lbl := 'CREATE INDEX';

  CI := NewNode(ND_CREATE_INDEX, Lbl, LexCurTok.Line, LexCurTok.Col);

  { CLUSTERED / NONCLUSTERED optionnel }
  If KwIs(KW_CLUSTERED) Then
  Begin
    N := NewNode(ND_IDENT, 'CLUSTERED', LexCurTok.Line, LexCurTok.Col);
    AddChild(CI, N);
    Advance;
  End
  Else If KwIs(KW_NONCLUSTERED) Then
  Begin
    N := NewNode(ND_IDENT, 'NONCLUSTERED', LexCurTok.Line, LexCurTok.Col);
    AddChild(CI, N);
    Advance;
  End;

  { Nom de l index }
  If Not KwIs(KW_INDEX) Then
  Begin
    ParseError('INDEX attendu');
    ParseCreateIndex := CI;
    Exit;
  End;
  Advance; { skip INDEX }

  N := ParseObjectName;
  AddChild(CI, N);

  { ON table (colonnes) }
  If Not KwIs(KW_ON) Then
  Begin
    ParseError('ON attendu apres nom d''index');
    ParseCreateIndex := CI;
    Exit;
  End;
  Advance; { skip ON }

  N := ParseObjectName;
  AddChild(CI, N);

  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    While ParseOk And Not TokIs(TOK_RPAREN) Do
    Begin
      N := ParseIndexCol;
      AddChild(CI, N);
      If TokIs(TOK_COMMA) Then Advance;
    End;
    If TokIs(TOK_RPAREN) Then Advance;
  End;

  { INCLUDE (cols) optionnel }
  If KwIs(KW_INCLUDE) Then
  Begin
    Advance; { skip INCLUDE }
    W := NewNode(ND_INCLUDE_COLS, 'INCLUDE', LexCurTok.Line, LexCurTok.Col);
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance;
      While ParseOk And Not TokIs(TOK_RPAREN) Do
      Begin
        If (LexCurTok.Kind = TOK_IDENT) Or
           (LexCurTok.Kind = TOK_KEYWORD) Or
           (LexCurTok.Kind = TOK_DELIM_IDENT) Then
        Begin
          N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                       LexCurTok.Col);
          AddChild(W, N);
          Advance;
        End;
        If TokIs(TOK_COMMA) Then Advance;
      End;
      If TokIs(TOK_RPAREN) Then Advance;
    End;
    AddChild(CI, W);
  End;

  { WHERE filtre optionnel }
  If KwIs(KW_WHERE) Then
  Begin
    Advance;
    N := ParseSqlExpr;
    W := NewNode(ND_WHERE_CLAUSE, 'WHERE', LexCurTok.Line, LexCurTok.Col);
    AddChild(W, N);
    AddChild(CI, W);
  End;

  { WITH (options) optionnel }
  If KwIs(KW_WITH) Then
  Begin
    W := ParseWithOptions;
    AddChild(CI, W);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateIndex := CI;
End;

{ ---- CREATE VIEW ----------------------------------------------- }

Function ParseCreateView : Integer;
Var
  CV, N, Sub : Integer;
Begin
  ParseCreateView := -1;
  If Not ParseOk Then Exit;

  CV := NewNode(ND_CREATE_VIEW, 'CREATE VIEW', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de la vue }
  N := ParseObjectName;
  AddChild(CV, N);

  { Liste de colonnes optionnelle }
  If TokIs(TOK_LPAREN) Then
  Begin
    Advance;
    While ParseOk And Not TokIs(TOK_RPAREN) Do
    Begin
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
        AddChild(CV, N);
        Advance;
      End;
      If TokIs(TOK_COMMA) Then Advance;
    End;
    If TokIs(TOK_RPAREN) Then Advance;
  End;

  { WITH SCHEMABINDING optionnel }
  If KwIs(KW_WITH) Then
  Begin
    Advance;
    If KwIs(KW_SCHEMABINDING) Then
    Begin
      N := NewNode(ND_IDENT, 'SCHEMABINDING', LexCurTok.Line,
                   LexCurTok.Col);
      AddChild(CV, N);
      Advance;
    End;
  End;

  { AS }
  If Not KwIs(KW_AS) Then
  Begin
    ParseError('AS attendu dans CREATE VIEW');
    ParseCreateView := CV;
    Exit;
  End;
  Advance; { skip AS }

  { SELECT ... }
  Sub := ParseSelectStmt;
  AddChild(CV, Sub);

  { WITH CHECK OPTION optionnel }
  If KwIs(KW_WITH) Then
  Begin
    Advance;
    If KwIs(KW_CHECK) Then
    Begin
      Advance;
      If KwIs(KW_OPTION) Then
      Begin
        N := NewNode(ND_IDENT, 'CHECK OPTION', LexCurTok.Line,
                     LexCurTok.Col);
        AddChild(CV, N);
        Advance;
      End;
    End;
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateView := CV;
End;

{ ---- CREATE PROCEDURE ------------------------------------------ }

Function ParseCreateProc : Integer;
Var
  CP, N, PL, Blk : Integer;
Begin
  ParseCreateProc := -1;
  If Not ParseOk Then Exit;

  CP := NewNode(ND_CREATE_PROC, 'CREATE PROCEDURE', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de la procedure }
  N := ParseObjectName;
  AddChild(CP, N);

  { Parametres optionnels }
  If (LexCurTok.Kind = TOK_VARIABLE) Or TokIs(TOK_LPAREN) Then
  Begin
    PL := ParseParamList;
    AddChild(CP, PL);
  End;

  { AS }
  If KwIs(KW_AS) Then
    Advance;

  { Corps : BEGIN ... END }
  If KwIs(KW_BEGIN) Then
  Begin
    Blk := ParseBodyBlock;
    AddChild(CP, Blk);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateProc := CP;
End;

{ ---- CREATE FUNCTION ------------------------------------------- }

Function ParseCreateFunc : Integer;
Var
  CF, N, PL, T, Blk : Integer;
Begin
  ParseCreateFunc := -1;
  If Not ParseOk Then Exit;

  CF := NewNode(ND_CREATE_FUNC, 'CREATE FUNCTION', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de la fonction }
  N := ParseObjectName;
  AddChild(CF, N);

  { Parametres }
  If TokIs(TOK_LPAREN) Or (LexCurTok.Kind = TOK_VARIABLE) Then
  Begin
    PL := ParseParamList;
    AddChild(CF, PL);
  End;

  { RETURNS type }
  If KwIs(KW_RETURNS) Then
  Begin
    Advance; { skip RETURNS }
    { TABLE est un cas special pour les fonctions tabulaires }
    If KwIs(KW_TABLE) Then
    Begin
      N := NewNode(ND_TYPE_REF, 'TABLE', LexCurTok.Line, LexCurTok.Col);
      Advance;
      { Definition de table optionnelle ( ... ) }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) And
              (LexCurTok.Kind <> TOK_EOF) Do
          Advance;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
      AddChild(CF, N);
    End
    Else
    Begin
      T := ParseTypeRef;
      AddChild(CF, T);
    End;
  End;

  { AS optionnel }
  If KwIs(KW_AS) Then
    Advance;

  { Corps : BEGIN ... END }
  If KwIs(KW_BEGIN) Then
  Begin
    Blk := ParseBodyBlock;
    AddChild(CF, Blk);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateFunc := CF;
End;

{ ---- CREATE TRIGGER -------------------------------------------- }

Function ParseCreateTrigger : Integer;
Var
  CTr, N, Blk : Integer;
  EvtText     : TString;
Begin
  ParseCreateTrigger := -1;
  If Not ParseOk Then Exit;

  CTr := NewNode(ND_CREATE_TRIGGER, 'CREATE TRIGGER', LexCurTok.Line,
                 LexCurTok.Col);

  { Nom du trigger }
  N := ParseObjectName;
  AddChild(CTr, N);

  { ON table }
  If KwIs(KW_ON) Then
  Begin
    Advance;
    N := ParseObjectName;
    AddChild(CTr, N);
  End;

  { FOR / AFTER / INSTEAD OF }
  If KwIs(KW_FOR) Then
  Begin
    N := NewNode(ND_IDENT, 'FOR', LexCurTok.Line, LexCurTok.Col);
    AddChild(CTr, N);
    Advance;
  End
  Else If KwIs(KW_AFTER) Then
  Begin
    N := NewNode(ND_IDENT, 'AFTER', LexCurTok.Line, LexCurTok.Col);
    AddChild(CTr, N);
    Advance;
  End
  Else If KwIs(KW_INSTEAD) Then
  Begin
    Advance; { skip INSTEAD }
    If KwIs(KW_OF) Then
      Advance; { skip OF }
    N := NewNode(ND_IDENT, 'INSTEAD OF', LexCurTok.Line, LexCurTok.Col);
    AddChild(CTr, N);
  End;

  { INSERT, UPDATE, DELETE (liste d evenements) }
  EvtText := '';
  While ParseOk And (KwIs(KW_INSERT) Or KwIs(KW_UPDATE) Or
        KwIs(KW_DELETE)) Do
  Begin
    If EvtText <> '' Then
      EvtText := EvtText + ',';
    EvtText := EvtText + LexCurTok.Text;
    Advance;
    If TokIs(TOK_COMMA) Then Advance;
  End;
  If EvtText <> '' Then
  Begin
    N := NewNode(ND_IDENT, EvtText, LexCurTok.Line, LexCurTok.Col);
    AddChild(CTr, N);
  End;

  { AS }
  If KwIs(KW_AS) Then
    Advance;

  { Corps : BEGIN ... END }
  If KwIs(KW_BEGIN) Then
  Begin
    Blk := ParseBodyBlock;
    AddChild(CTr, Blk);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseCreateTrigger := CTr;
End;

{ ---- CREATE SCHEMA / SEQUENCE / TYPE / DATABASE ---------------- }

Function ParseCreateSchema : Integer;
Var
  CS, N : Integer;
Begin
  ParseCreateSchema := -1;
  If Not ParseOk Then Exit;
  CS := NewNode(ND_CREATE_SCHEMA, 'CREATE SCHEMA', LexCurTok.Line,
                LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CS, N);
  { AUTHORIZATION optionnel }
  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'AUTHORIZATION' Then
    Begin
      Advance;
      N := ParseObjectName;
      AddChild(CS, N);
    End;
  End;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateSchema := CS;
End;

Function ParseCreateSequence : Integer;
Var
  CSq, N, E : Integer;
Begin
  ParseCreateSequence := -1;
  If Not ParseOk Then Exit;
  CSq := NewNode(ND_CREATE_SEQ, 'CREATE SEQUENCE', LexCurTok.Line,
                 LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CSq, N);
  { Options : AS type, START WITH n, INCREMENT BY n, etc. }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
  Begin
    If KwIs(KW_AS) Then
    Begin
      Advance;
      E := ParseTypeRef;
      AddChild(CSq, E);
    End
    Else If (LexCurTok.Kind = TOK_IDENT) Or
            (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      N := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                   LexCurTok.Col);
      Advance;
      { Si suivi d une valeur }
      If (LexCurTok.Kind = TOK_NUMBER) Or (LexCurTok.Kind = TOK_FLOAT) Or
         (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      Begin
        ASTPool[N].Text := ASTPool[N].Text + ' ' + LexCurTok.Text;
        Advance;
      End;
      AddChild(CSq, N);
    End
    Else
      Break;
  End;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateSequence := CSq;
End;

Function ParseCreateType : Integer;
Var
  CTy, N : Integer;
Begin
  ParseCreateType := -1;
  If Not ParseOk Then Exit;
  CTy := NewNode(ND_CREATE_TYPE, 'CREATE TYPE', LexCurTok.Line,
                 LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CTy, N);
  { FROM type ou AS TABLE ( ... ) }
  If KwIs(KW_AS) Then
  Begin
    Advance;
    If KwIs(KW_TABLE) Then
    Begin
      Advance; { skip TABLE }
      N := NewNode(ND_IDENT, 'TABLE', LexCurTok.Line, LexCurTok.Col);
      AddChild(CTy, N);
      { Sauter la definition de table }
      If TokIs(TOK_LPAREN) Then
      Begin
        Advance;
        While ParseOk And Not TokIs(TOK_RPAREN) And
              (LexCurTok.Kind <> TOK_EOF) Do
          Advance;
        If TokIs(TOK_RPAREN) Then Advance;
      End;
    End
    Else
    Begin
      N := ParseTypeRef;
      AddChild(CTy, N);
    End;
  End
  Else If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'FROM' Then
    Begin
      Advance;
      N := ParseTypeRef;
      AddChild(CTy, N);
    End;
  End;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateType := CTy;
End;

Function ParseCreateDatabase : Integer;
Var
  CDb, N : Integer;
Begin
  ParseCreateDatabase := -1;
  If Not ParseOk Then Exit;
  CDb := NewNode(ND_CREATE_DB, 'CREATE DATABASE', LexCurTok.Line,
                 LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CDb, N);
  { Sauter les options restantes jusqu au ; ou EOF }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
    Advance;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateDatabase := CDb;
End;

{ ---- TODO 14 : Parseur DCL (GRANT / REVOKE / DENY) ----------- }

{ ---- ParsePermission ------------------------------------------- }
{ Analyse un nom de permission SQL.                                 }
{ Permissions : SELECT, INSERT, UPDATE, DELETE, EXECUTE, ALTER,     }
{ CONTROL, VIEW DEFINITION, REFERENCES, TAKE OWNERSHIP             }

Function ParsePermission : Integer;
Var
  PermName : TString;
Begin
  ParsePermission := -1;
  If Not ParseOk Then Exit;
  PermName := '';
  If KwIs(KW_SELECT) Then
    PermName := 'SELECT'
  Else If KwIs(KW_INSERT) Then
    PermName := 'INSERT'
  Else If KwIs(KW_UPDATE) Then
    PermName := 'UPDATE'
  Else If KwIs(KW_DELETE) Then
    PermName := 'DELETE'
  Else If KwIs(KW_EXECUTE) Or KwIs(KW_EXEC) Then
    PermName := 'EXECUTE'
  Else If KwIs(KW_ALTER) Then
    PermName := 'ALTER'
  Else If KwIs(KW_CONTROL) Then
    PermName := 'CONTROL'
  Else If KwIs(KW_VIEW) Then
  Begin
    Advance; { skip VIEW }
    If KwIs(KW_DEFINITION) Then
    Begin
      PermName := 'VIEW DEFINITION';
    End
    Else
    Begin
      ParseError('DEFINITION attendu apres VIEW');
      Exit;
    End;
  End
  Else If KwIs(KW_REFERENCES) Then
    PermName := 'REFERENCES'
  Else If KwIs(KW_TAKE) Then
  Begin
    Advance; { skip TAKE }
    If KwIs(KW_OWNERSHIP) Then
    Begin
      PermName := 'TAKE OWNERSHIP';
    End
    Else
    Begin
      ParseError('OWNERSHIP attendu apres TAKE');
      Exit;
    End;
  End
  Else
  Begin
    { permission as identifier }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
      PermName := StrUpperCase(LexCurTok.Text)
    Else
    Begin
      ParseError('permission attendue');
      Exit;
    End;
  End;
  ParsePermission := NewNode(ND_PERMISSION, PermName, LexCurTok.Line,
                             LexCurTok.Col);
  Advance; { skip permission keyword }
End;

{ ---- ParsePrincipal -------------------------------------------- }
{ Analyse un nom de principal (user, role, login, public).          }

Function ParsePrincipal : Integer;
Var
  PName : TString;
Begin
  ParsePrincipal := -1;
  If Not ParseOk Then Exit;
  If KwIs(KW_PUBLIC) Then
  Begin
    ParsePrincipal := NewNode(ND_PRINCIPAL, 'PUBLIC', LexCurTok.Line,
                              LexCurTok.Col);
    Advance;
    Exit;
  End;
  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    PName := LexCurTok.Text;
    ParsePrincipal := NewNode(ND_PRINCIPAL, PName, LexCurTok.Line,
                              LexCurTok.Col);
    Advance;
  End
  Else If LexCurTok.Kind = TOK_DELIM_IDENT Then
  Begin
    ParsePrincipal := ParseObjectName;
  End
  Else
    ParseError('nom de principal attendu');
End;

{ ---- ParseGrantStmt -------------------------------------------- }
{ GRANT permission [ON objet] TO principal                          }
{ GRANT permission TO role (sans ON)                                }

Function ParseGrantStmt : Integer;
Var
  GS, Perm, Obj, Princ : Integer;
Begin
  ParseGrantStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_GRANT) Then
  Begin
    ParseError('GRANT attendu');
    Exit;
  End;
  GS := NewNode(ND_GRANT_STMT, 'GRANT', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip GRANT }

  { Parse permission }
  Perm := ParsePermission;
  AddChild(GS, Perm);

  { ON objet (optionnel) }
  If KwIs(KW_ON) Then
  Begin
    Advance; { skip ON }
    Obj := ParseObjectName;
    AddChild(GS, Obj);
  End;

  { TO principal }
  If KwIs(KW_TO) Then
  Begin
    Advance; { skip TO }
    Princ := ParsePrincipal;
    AddChild(GS, Princ);
  End
  Else
    ParseError('TO attendu');

  If TokIs(TOK_SEMICOL) Then Advance;
  ParseGrantStmt := GS;
End;

{ ---- ParseRevokeStmt ------------------------------------------- }
{ REVOKE permission [ON objet] FROM principal                       }

Function ParseRevokeStmt : Integer;
Var
  RS, Perm, Obj, Princ : Integer;
Begin
  ParseRevokeStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_REVOKE) Then
  Begin
    ParseError('REVOKE attendu');
    Exit;
  End;
  RS := NewNode(ND_REVOKE_STMT, 'REVOKE', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip REVOKE }

  { Parse permission }
  Perm := ParsePermission;
  AddChild(RS, Perm);

  { ON objet (optionnel) }
  If KwIs(KW_ON) Then
  Begin
    Advance; { skip ON }
    Obj := ParseObjectName;
    AddChild(RS, Obj);
  End;

  { FROM principal }
  If KwIs(KW_FROM) Then
  Begin
    Advance; { skip FROM }
    Princ := ParsePrincipal;
    AddChild(RS, Princ);
  End
  Else
    ParseError('FROM attendu');

  If TokIs(TOK_SEMICOL) Then Advance;
  ParseRevokeStmt := RS;
End;

{ ---- ParseDenyStmt --------------------------------------------- }
{ DENY permission [ON objet] TO principal                           }

Function ParseDenyStmt : Integer;
Var
  DS, Perm, Obj, Princ : Integer;
Begin
  ParseDenyStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_DENY) Then
  Begin
    ParseError('DENY attendu');
    Exit;
  End;
  DS := NewNode(ND_DENY_STMT, 'DENY', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip DENY }

  { Parse permission }
  Perm := ParsePermission;
  AddChild(DS, Perm);

  { ON objet (optionnel) }
  If KwIs(KW_ON) Then
  Begin
    Advance; { skip ON }
    Obj := ParseObjectName;
    AddChild(DS, Obj);
  End;

  { TO principal }
  If KwIs(KW_TO) Then
  Begin
    Advance; { skip TO }
    Princ := ParsePrincipal;
    AddChild(DS, Princ);
  End
  Else
    ParseError('TO attendu');

  If TokIs(TOK_SEMICOL) Then Advance;
  ParseDenyStmt := DS;
End;

{ ---- ParseCreateLogin ------------------------------------------ }
{ CREATE LOGIN name ... (options sautees)                           }

Function ParseCreateLogin : Integer;
Var
  CL, N : Integer;
Begin
  ParseCreateLogin := -1;
  If Not ParseOk Then Exit;
  CL := NewNode(ND_CREATE_LOGIN, 'CREATE LOGIN', LexCurTok.Line,
                LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CL, N);
  { Sauter les options restantes jusqu au ; ou EOF }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
    Advance;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateLogin := CL;
End;

{ ---- ParseCreateUser ------------------------------------------- }
{ CREATE USER name ... (options sautees)                            }

Function ParseCreateUser : Integer;
Var
  CU, N : Integer;
Begin
  ParseCreateUser := -1;
  If Not ParseOk Then Exit;
  CU := NewNode(ND_CREATE_USER, 'CREATE USER', LexCurTok.Line,
                LexCurTok.Col);
  N := ParseObjectName;
  AddChild(CU, N);
  { Sauter les options restantes jusqu au ; ou EOF }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
    Advance;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseCreateUser := CU;
End;

{ ---- ParseAlterLogin ------------------------------------------- }
{ ALTER LOGIN name ... (options sautees)                            }

Function ParseAlterLogin : Integer;
Var
  AL, N : Integer;
Begin
  ParseAlterLogin := -1;
  If Not ParseOk Then Exit;
  AL := NewNode(ND_ALTER_LOGIN, 'ALTER LOGIN', LexCurTok.Line,
                LexCurTok.Col);
  N := ParseObjectName;
  AddChild(AL, N);
  { Sauter les options restantes jusqu au ; ou EOF }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
    Advance;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseAlterLogin := AL;
End;

{ ---- ParseAlterUser -------------------------------------------- }
{ ALTER USER name ... (options sautees)                             }

Function ParseAlterUser : Integer;
Var
  AU, N : Integer;
Begin
  ParseAlterUser := -1;
  If Not ParseOk Then Exit;
  AU := NewNode(ND_ALTER_USER, 'ALTER USER', LexCurTok.Line,
                LexCurTok.Col);
  N := ParseObjectName;
  AddChild(AU, N);
  { Sauter les options restantes jusqu au ; ou EOF }
  While ParseOk And Not TokIs(TOK_SEMICOL) And
        (LexCurTok.Kind <> TOK_EOF) Do
    Advance;
  If TokIs(TOK_SEMICOL) Then Advance;
  ParseAlterUser := AU;
End;

{ ---- ParseAlterRole -------------------------------------------- }
{ ALTER ROLE rolename ADD MEMBER username                           }

Function ParseAlterRole : Integer;
Var
  AR, N : Integer;
Begin
  ParseAlterRole := -1;
  If Not ParseOk Then Exit;
  AR := NewNode(ND_ALTER_ROLE, 'ALTER ROLE', LexCurTok.Line,
                LexCurTok.Col);
  { Nom du role }
  N := ParseObjectName;
  AddChild(AR, N);

  { ADD MEMBER username }
  If KwIs(KW_ADD) Then
  Begin
    Advance; { skip ADD }
    If KwIs(KW_MEMBER) Then
    Begin
      Advance; { skip MEMBER }
      N := ParsePrincipal;
      AddChild(AR, N);
    End
    Else
      ParseError('MEMBER attendu apres ADD');
  End
  Else
  Begin
    { Sauter les options restantes jusqu au ; ou EOF }
    While ParseOk And Not TokIs(TOK_SEMICOL) And
          (LexCurTok.Kind <> TOK_EOF) Do
      Advance;
  End;

  If TokIs(TOK_SEMICOL) Then Advance;
  ParseAlterRole := AR;
End;

{ ---- Dispatch CREATE ------------------------------------------- }

Function ParseCreateStmt : Integer;
Var
  IsUnique : Boolean;
Begin
  ParseCreateStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_CREATE) Then
  Begin
    ParseError('CREATE attendu');
    Exit;
  End;
  Advance; { skip CREATE }

  IsUnique := False;

  If KwIs(KW_TABLE) Then
  Begin
    Advance; { skip TABLE }
    ParseCreateStmt := ParseCreateTable;
  End
  Else If KwIs(KW_UNIQUE) Then
  Begin
    Advance; { skip UNIQUE }
    IsUnique := True;
    { CLUSTERED/NONCLUSTERED INDEX ... }
    ParseCreateStmt := ParseCreateIndex(IsUnique);
  End
  Else If KwIs(KW_CLUSTERED) Or KwIs(KW_NONCLUSTERED) Then
  Begin
    { CLUSTERED/NONCLUSTERED INDEX ... }
    ParseCreateStmt := ParseCreateIndex(False);
  End
  Else If KwIs(KW_INDEX) Then
  Begin
    { INDEX deja consomme par ParseCreateIndex }
    ParseCreateStmt := ParseCreateIndex(False);
  End
  Else If KwIs(KW_VIEW) Then
  Begin
    Advance; { skip VIEW }
    ParseCreateStmt := ParseCreateView;
  End
  Else If KwIs(KW_PROCEDURE) Then
  Begin
    Advance; { skip PROCEDURE }
    ParseCreateStmt := ParseCreateProc;
  End
  Else If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'PROC' Then
    Begin
      Advance; { skip PROC }
      ParseCreateStmt := ParseCreateProc;
    End
    Else
    Begin
      { Continuer avec les autres CREATE }
      If KwIs(KW_FUNCTION) Then
      Begin
        Advance; { skip FUNCTION }
        ParseCreateStmt := ParseCreateFunc;
      End
      Else If KwIs(KW_TRIGGER) Then
      Begin
        Advance; { skip TRIGGER }
        ParseCreateStmt := ParseCreateTrigger;
      End
      Else If KwIs(KW_SCHEMA) Then
      Begin
        Advance; { skip SCHEMA }
        ParseCreateStmt := ParseCreateSchema;
      End
      Else If KwIs(KW_SEQUENCE) Then
      Begin
        Advance; { skip SEQUENCE }
        ParseCreateStmt := ParseCreateSequence;
      End
      Else If KwIs(KW_TYPE) Then
      Begin
        Advance; { skip TYPE }
        ParseCreateStmt := ParseCreateType;
      End
      Else If KwIs(KW_DATABASE) Then
      Begin
        Advance; { skip DATABASE }
        ParseCreateStmt := ParseCreateDatabase;
      End
      Else If KwIs(KW_LOGIN) Then
      Begin
        Advance; { skip LOGIN }
        ParseCreateStmt := ParseCreateLogin;
      End
      Else If KwIs(KW_USER) Then
      Begin
        Advance; { skip USER }
        ParseCreateStmt := ParseCreateUser;
      End
      Else
      Begin
        ParseError('type d''objet CREATE inconnu: ' + LexCurTok.Text);
      End;
    End;
  End
  Else If KwIs(KW_FUNCTION) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateFunc;
  End
  Else If KwIs(KW_TRIGGER) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateTrigger;
  End
  Else If KwIs(KW_SCHEMA) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateSchema;
  End
  Else If KwIs(KW_SEQUENCE) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateSequence;
  End
  Else If KwIs(KW_TYPE) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateType;
  End
  Else If KwIs(KW_DATABASE) Then
  Begin
    Advance;
    ParseCreateStmt := ParseCreateDatabase;
  End
  Else If KwIs(KW_LOGIN) Then
  Begin
    Advance; { skip LOGIN }
    ParseCreateStmt := ParseCreateLogin;
  End
  Else If KwIs(KW_USER) Then
  Begin
    Advance; { skip USER }
    ParseCreateStmt := ParseCreateUser;
  End
  Else
    ParseError('type d''objet CREATE inconnu: ' + LexCurTok.Text);
End;

{ ---- ALTER TABLE ----------------------------------------------- }

Function ParseAlterTable : Integer;
Var
  AT, N, CD, T : Integer;
Begin
  ParseAlterTable := -1;
  If Not ParseOk Then Exit;

  AT := NewNode(ND_ALTER_TABLE, 'ALTER TABLE', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de la table }
  N := ParseObjectName;
  AddChild(AT, N);

  { ADD / ALTER COLUMN / DROP COLUMN }
  If KwIs(KW_ADD) Then
  Begin
    Advance; { skip ADD }
    { CONSTRAINT ou colonne }
    If KwIs(KW_CONSTRAINT) Or KwIs(KW_PRIMARY) Or KwIs(KW_UNIQUE) Or
       KwIs(KW_FOREIGN) Or KwIs(KW_CHECK) Then
    Begin
      CD := ParseColumnDef;
      N := NewNode(ND_IDENT, 'ADD', LexCurTok.Line, LexCurTok.Col);
      AddChild(N, CD);
      AddChild(AT, N);
    End
    Else
    Begin
      { ADD colonne type [contraintes] }
      CD := ParseColumnDef;
      N := NewNode(ND_IDENT, 'ADD', LexCurTok.Line, LexCurTok.Col);
      AddChild(N, CD);
      AddChild(AT, N);
    End;
  End
  Else If KwIs(KW_ALTER) Then
  Begin
    Advance; { skip ALTER }
    If KwIs(KW_COLUMN) Then
      Advance; { skip COLUMN }
    N := NewNode(ND_IDENT, 'ALTER COLUMN', LexCurTok.Line, LexCurTok.Col);
    { nom de la colonne }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      CD := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                    LexCurTok.Col);
      Advance;
      T := ParseTypeRef;
      AddChild(CD, T);
      { NOT NULL / NULL optionnel }
      If KwIs(KW_NOT) Then
      Begin
        Advance;
        If KwIs(KW_NULL) Then
        Begin
          T := NewNode(ND_IDENT, 'NOT NULL', LexCurTok.Line, LexCurTok.Col);
          AddChild(CD, T);
          Advance;
        End;
      End
      Else If KwIs(KW_NULL) Then
      Begin
        T := NewNode(ND_IDENT, 'NULL', LexCurTok.Line, LexCurTok.Col);
        AddChild(CD, T);
        Advance;
      End;
      AddChild(N, CD);
    End;
    AddChild(AT, N);
  End
  Else If KwIs(KW_DROP) Then
  Begin
    Advance; { skip DROP }
    N := NewNode(ND_IDENT, 'DROP', LexCurTok.Line, LexCurTok.Col);
    If KwIs(KW_COLUMN) Then
      Advance; { skip COLUMN }
    If KwIs(KW_CONSTRAINT) Then
      Advance; { skip CONSTRAINT }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
       (LexCurTok.Kind = TOK_DELIM_IDENT) Then
    Begin
      CD := NewNode(ND_IDENT, LexCurTok.Text, LexCurTok.Line,
                    LexCurTok.Col);
      AddChild(N, CD);
      Advance;
    End;
    AddChild(AT, N);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseAlterTable := AT;
End;

{ ---- ALTER INDEX ----------------------------------------------- }

Function ParseAlterIndex : Integer;
Var
  AI, N, W : Integer;
Begin
  ParseAlterIndex := -1;
  If Not ParseOk Then Exit;

  AI := NewNode(ND_ALTER_INDEX, 'ALTER INDEX', LexCurTok.Line,
                LexCurTok.Col);

  { Nom de l index ou ALL }
  If KwIs(KW_ALL) Then
  Begin
    N := NewNode(ND_IDENT, 'ALL', LexCurTok.Line, LexCurTok.Col);
    Advance;
  End
  Else
    N := ParseObjectName;
  AddChild(AI, N);

  { ON table }
  If KwIs(KW_ON) Then
  Begin
    Advance;
    N := ParseObjectName;
    AddChild(AI, N);
  End;

  { REBUILD / REORGANIZE / DISABLE }
  If KwIs(KW_REBUILD) Then
  Begin
    N := NewNode(ND_IDENT, 'REBUILD', LexCurTok.Line, LexCurTok.Col);
    AddChild(AI, N);
    Advance;
  End
  Else If KwIs(KW_REORGANIZE) Then
  Begin
    N := NewNode(ND_IDENT, 'REORGANIZE', LexCurTok.Line, LexCurTok.Col);
    AddChild(AI, N);
    Advance;
  End
  Else If KwIs(KW_DISABLE) Then
  Begin
    N := NewNode(ND_IDENT, 'DISABLE', LexCurTok.Line, LexCurTok.Col);
    AddChild(AI, N);
    Advance;
  End;

  { WITH (options) optionnel }
  If KwIs(KW_WITH) Then
  Begin
    W := ParseWithOptions;
    AddChild(AI, W);
  End;

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseAlterIndex := AI;
End;

{ ---- Dispatch ALTER -------------------------------------------- }

Function ParseAlterStmt : Integer;
Begin
  ParseAlterStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_ALTER) Then
  Begin
    ParseError('ALTER attendu');
    Exit;
  End;
  Advance; { skip ALTER }

  If KwIs(KW_TABLE) Then
  Begin
    Advance; { skip TABLE }
    ParseAlterStmt := ParseAlterTable;
  End
  Else If KwIs(KW_INDEX) Then
  Begin
    Advance; { skip INDEX }
    ParseAlterStmt := ParseAlterIndex;
  End
  Else If KwIs(KW_LOGIN) Then
  Begin
    Advance; { skip LOGIN }
    ParseAlterStmt := ParseAlterLogin;
  End
  Else If KwIs(KW_USER) Then
  Begin
    Advance; { skip USER }
    ParseAlterStmt := ParseAlterUser;
  End
  Else If KwIs(KW_ROLE) Then
  Begin
    Advance; { skip ROLE }
    ParseAlterStmt := ParseAlterRole;
  End
  Else
  Begin
    { Pour les autres ALTER (DATABASE, PROCEDURE, etc), }
    { on cree un noeud generique et on saute jusqu au ; }
    ParseAlterStmt := NewNode(ND_ALTER_TABLE, 'ALTER ' + LexCurTok.Text,
                              LexCurTok.Line, LexCurTok.Col);
    While ParseOk And Not TokIs(TOK_SEMICOL) And
          (LexCurTok.Kind <> TOK_EOF) Do
      Advance;
    If TokIs(TOK_SEMICOL) Then Advance;
  End;
End;

{ ---- DROP ------------------------------------------------------ }

Function ParseDropStmt : Integer;
Var
  DS, N : Integer;
  ObjType : TString;
Begin
  ParseDropStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_DROP) Then
  Begin
    ParseError('DROP attendu');
    Exit;
  End;
  Advance; { skip DROP }

  ObjType := '';
  If KwIs(KW_TABLE) Then
    ObjType := 'TABLE'
  Else If KwIs(KW_VIEW) Then
    ObjType := 'VIEW'
  Else If KwIs(KW_INDEX) Then
    ObjType := 'INDEX'
  Else If KwIs(KW_PROCEDURE) Then
    ObjType := 'PROCEDURE'
  Else If KwIs(KW_FUNCTION) Then
    ObjType := 'FUNCTION'
  Else If KwIs(KW_TRIGGER) Then
    ObjType := 'TRIGGER'
  Else If KwIs(KW_DATABASE) Then
    ObjType := 'DATABASE'
  Else If KwIs(KW_SCHEMA) Then
    ObjType := 'SCHEMA'
  Else If KwIs(KW_SEQUENCE) Then
    ObjType := 'SEQUENCE'
  Else If KwIs(KW_TYPE) Then
    ObjType := 'TYPE'
  Else If KwIs(KW_LOGIN) Then
    ObjType := 'LOGIN'
  Else If KwIs(KW_USER) Then
    ObjType := 'USER'
  Else If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
  Begin
    If StrUpperCase(LexCurTok.Text) = 'PROC' Then
      ObjType := 'PROCEDURE'
    Else
      ObjType := StrUpperCase(LexCurTok.Text);
  End
  Else
  Begin
    ParseError('type d''objet attendu apres DROP');
    Exit;
  End;

  DS := NewNode(ND_DROP_STMT, 'DROP ' + ObjType, LexCurTok.Line,
                LexCurTok.Col);
  Advance; { skip object type }

  { IF EXISTS optionnel }
  If KwIs(KW_IF) Then
  Begin
    Advance; { skip IF }
    If KwIs(KW_EXISTS) Then
    Begin
      N := NewNode(ND_IDENT, 'IF EXISTS', LexCurTok.Line, LexCurTok.Col);
      AddChild(DS, N);
      Advance; { skip EXISTS }
    End;
  End;

  { Nom de l objet }
  N := ParseObjectName;
  AddChild(DS, N);

  If TokIs(TOK_SEMICOL) Then
    Advance;

  ParseDropStmt := DS;
End;

{ ---- TODO 13 : Parseur des instructions de controle T-SQL ------ }

{ ---- ParseDeclareStmt ------------------------------------------ }
{ DECLARE @var type [= expr]                                        }
{ DECLARE @var TABLE (col type, ...)                                }

Function ParseDeclareStmt : Integer;
Var
  N, VN, T, E, ColD : Integer;
  VarName            : TString;
Begin
  ParseDeclareStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_DECLARE) Then
  Begin
    ParseError('DECLARE attendu');
    Exit;
  End;
  Advance; { skip DECLARE }

  If LexCurTok.Kind <> TOK_VARIABLE Then
  Begin
    ParseError('variable @nom attendue apres DECLARE');
    Exit;
  End;
  VarName := LexCurTok.Text;
  Advance; { skip @variable }

  { DECLARE @var TABLE (...) }
  If KwIs(KW_TABLE) Then
  Begin
    N := NewNode(ND_DECLARE_TABLE, VarName, LexCurTok.Line, LexCurTok.Col);
    Advance; { skip TABLE }
    If TokIs(TOK_LPAREN) Then
    Begin
      Advance; { skip ( }
      While ParseOk And Not TokIs(TOK_RPAREN) And
            (LexCurTok.Kind <> TOK_EOF) Do
      Begin
        { Lire nom de colonne }
        If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
           (LexCurTok.Kind = TOK_DELIM_IDENT) Then
        Begin
          ColD := NewNode(ND_COL_DEF, LexCurTok.Text, LexCurTok.Line,
                          LexCurTok.Col);
          Advance;
          { Lire le type }
          T := ParseTypeRef;
          If T >= 0 Then
            AddChild(ColD, T);
          AddChild(N, ColD);
        End
        Else
        Begin
          ParseError('nom de colonne attendu dans TABLE');
          Break;
        End;
        If TokIs(TOK_COMMA) Then
          Advance
        Else
          Break;
      End;
      If TokIs(TOK_RPAREN) Then
        Advance;
    End;
    ParseDeclareStmt := N;
    Exit;
  End;

  { DECLARE @var type [= expr] }
  N := NewNode(ND_DECLARE_VAR, VarName, LexCurTok.Line, LexCurTok.Col);
  { Type de la variable }
  T := ParseTypeRef;
  If T >= 0 Then
    AddChild(N, T);
  { Initialisation optionnelle }
  If TokIs(TOK_EQ) Then
  Begin
    Advance; { skip = }
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;
  { Declarations multiples separees par virgule }
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance; { skip , }
    If LexCurTok.Kind = TOK_VARIABLE Then
    Begin
      VN := NewNode(ND_DECLARE_VAR, LexCurTok.Text, LexCurTok.Line,
                     LexCurTok.Col);
      Advance; { skip @var }
      T := ParseTypeRef;
      If T >= 0 Then
        AddChild(VN, T);
      If TokIs(TOK_EQ) Then
      Begin
        Advance;
        E := ParseSqlExpr;
        If E >= 0 Then
          AddChild(VN, E);
      End;
      AddChild(N, VN);
    End
    Else
    Begin
      ParseError('variable @nom attendue');
      Break;
    End;
  End;

  ParseDeclareStmt := N;
End;

{ ---- ParseSetStmt ---------------------------------------------- }
{ SET @variable = expression                                        }

Function ParseSetStmt : Integer;
Var
  N, E   : Integer;
  VarName : TString;
Begin
  ParseSetStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_SET) Then
  Begin
    ParseError('SET attendu');
    Exit;
  End;
  Advance; { skip SET }

  If LexCurTok.Kind <> TOK_VARIABLE Then
  Begin
    ParseError('variable @nom attendue apres SET');
    Exit;
  End;
  VarName := LexCurTok.Text;
  Advance; { skip @variable }

  N := NewNode(ND_SET_VAR, VarName, LexCurTok.Line, LexCurTok.Col);

  If TokIs(TOK_EQ) Then
    Advance { skip = }
  Else If TokIs(TOK_PLUS_EQ) Or TokIs(TOK_MINUS_EQ) Or
          TokIs(TOK_STAR_EQ) Or TokIs(TOK_SLASH_EQ) Or
          TokIs(TOK_PERCENT_EQ) Then
  Begin
    ASTPool[N].Text := VarName + ' ' + LexCurTok.Text;
    Advance;
  End
  Else
  Begin
    ParseError('= attendu apres variable');
    Exit;
  End;

  E := ParseSqlExpr;
  If E >= 0 Then
    AddChild(N, E);

  ParseSetStmt := N;
End;

{ ---- ParseIfStmt ----------------------------------------------- }
{ IF condition instruction | BEGIN...END [ELSE instruction | BEGIN...END] }

Function ParseStatement : Integer; Forward;

Function ParseIfStmt : Integer;
Var
  N, Cond, Body, ElseBody : Integer;
Begin
  ParseIfStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_IF) Then
  Begin
    ParseError('IF attendu');
    Exit;
  End;
  N := NewNode(ND_IF_STMT, 'IF', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip IF }

  { Condition }
  Cond := ParseSqlExpr;
  If Cond >= 0 Then
    AddChild(N, Cond);

  { Corps du IF : bloc ou instruction simple }
  Body := ParseStatement;
  If Body >= 0 Then
    AddChild(N, Body);

  { ELSE optionnel }
  If KwIs(KW_ELSE) Then
  Begin
    Advance; { skip ELSE }
    ElseBody := ParseStatement;
    If ElseBody >= 0 Then
      AddChild(N, ElseBody);
  End;

  ParseIfStmt := N;
End;

{ ---- ParseWhileStmt -------------------------------------------- }
{ WHILE condition instruction | BEGIN...END                         }

Function ParseWhileStmt : Integer;
Var
  N, Cond, Body : Integer;
Begin
  ParseWhileStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_WHILE) Then
  Begin
    ParseError('WHILE attendu');
    Exit;
  End;
  N := NewNode(ND_WHILE_STMT, 'WHILE', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip WHILE }

  Cond := ParseSqlExpr;
  If Cond >= 0 Then
    AddChild(N, Cond);

  Body := ParseStatement;
  If Body >= 0 Then
    AddChild(N, Body);

  ParseWhileStmt := N;
End;

{ ---- ParseBlockStmt -------------------------------------------- }
{ BEGIN ... END (bloc autonome)                                     }
{ BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH                   }

Function ParseBlockStmt : Integer;
Var
  N, S, TryBlk, CatchBlk : Integer;
  IsTry                   : Boolean;
Begin
  ParseBlockStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_BEGIN) Then
  Begin
    ParseError('BEGIN attendu');
    Exit;
  End;
  Advance; { skip BEGIN }

  { Detecter BEGIN TRY }
  IsTry := KwIs(KW_TRY);
  If IsTry Then
  Begin
    Advance; { skip TRY }
    N := NewNode(ND_TRY_CATCH, 'TRY_CATCH', LexCurTok.Line, LexCurTok.Col);

    { Corps du TRY : lire les instructions jusqu a END TRY }
    TryBlk := NewNode(ND_BLOCK_STMT, 'TRY', LexCurTok.Line, LexCurTok.Col);
    While ParseOk And Not (KwIs(KW_END)) And
          (LexCurTok.Kind <> TOK_EOF) Do
    Begin
      S := ParseStatement;
      If S >= 0 Then
        AddChild(TryBlk, S)
      Else
        Break;
    End;
    AddChild(N, TryBlk);

    { END TRY }
    If KwIs(KW_END) Then
    Begin
      Advance; { skip END }
      If KwIs(KW_TRY) Then
        Advance; { skip TRY }
    End;

    { BEGIN CATCH }
    If KwIs(KW_BEGIN) Then
    Begin
      Advance; { skip BEGIN }
      If KwIs(KW_CATCH) Then
        Advance; { skip CATCH }

      CatchBlk := NewNode(ND_BLOCK_STMT, 'CATCH', LexCurTok.Line,
                           LexCurTok.Col);
      While ParseOk And Not (KwIs(KW_END)) And
            (LexCurTok.Kind <> TOK_EOF) Do
      Begin
        S := ParseStatement;
        If S >= 0 Then
          AddChild(CatchBlk, S)
        Else
          Break;
      End;
      AddChild(N, CatchBlk);

      { END CATCH }
      If KwIs(KW_END) Then
      Begin
        Advance; { skip END }
        If KwIs(KW_CATCH) Then
          Advance; { skip CATCH }
      End;
    End;

    ParseBlockStmt := N;
    Exit;
  End;

  { BEGIN ... END bloc normal }
  N := NewNode(ND_BLOCK_STMT, 'BEGIN...END', LexCurTok.Line, LexCurTok.Col);
  While ParseOk And Not KwIs(KW_END) And
        (LexCurTok.Kind <> TOK_EOF) Do
  Begin
    S := ParseStatement;
    If S >= 0 Then
      AddChild(N, S)
    Else
      Break;
  End;
  If KwIs(KW_END) Then
    Advance { skip END }
  Else
    ParseError('END attendu pour fermer le bloc BEGIN');

  ParseBlockStmt := N;
End;

{ ---- ParseReturnStmt ------------------------------------------- }
{ RETURN [valeur]                                                   }

Function ParseReturnStmt : Integer;
Var
  N, E : Integer;
Begin
  ParseReturnStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_RETURN) Then
  Begin
    ParseError('RETURN attendu');
    Exit;
  End;
  N := NewNode(ND_RETURN_STMT, 'RETURN', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip RETURN }

  { Valeur de retour optionnelle }
  If (LexCurTok.Kind <> TOK_EOF) And Not TokIs(TOK_SEMICOL) And
     Not KwIs(KW_END) And Not KwIs(KW_GO) Then
  Begin
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  ParseReturnStmt := N;
End;

{ ---- ParseWaitforStmt ------------------------------------------ }
{ WAITFOR DELAY 'hh:mm:ss'                                         }
{ WAITFOR TIME 'hh:mm:ss'                                          }

Function ParseWaitforStmt : Integer;
Var
  N, E : Integer;
  Mode : TString;
Begin
  ParseWaitforStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_WAITFOR) Then
  Begin
    ParseError('WAITFOR attendu');
    Exit;
  End;
  Advance; { skip WAITFOR }

  Mode := 'DELAY';
  If KwIs(KW_DELAY) Then
  Begin
    Mode := 'DELAY';
    Advance; { skip DELAY }
  End
  Else If KwIs(KW_TIME) Then
  Begin
    Mode := 'TIME';
    Advance; { skip TIME }
  End
  Else
  Begin
    ParseError('DELAY ou TIME attendu apres WAITFOR');
    Exit;
  End;

  N := NewNode(ND_WAITFOR_STMT, Mode, LexCurTok.Line, LexCurTok.Col);
  E := ParseSqlExpr;
  If E >= 0 Then
    AddChild(N, E);

  ParseWaitforStmt := N;
End;

{ ---- ParseThrowStmt -------------------------------------------- }
{ THROW [numero, message, state]                                    }

Function ParseThrowStmt : Integer;
Var
  N, E : Integer;
Begin
  ParseThrowStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_THROW) Then
  Begin
    ParseError('THROW attendu');
    Exit;
  End;
  N := NewNode(ND_THROW_STMT, 'THROW', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip THROW }

  { THROW sans arguments (re-throw dans CATCH) }
  If TokIs(TOK_SEMICOL) Or TokIs(TOK_EOF) Or KwIs(KW_END) Then
  Begin
    ParseThrowStmt := N;
    Exit;
  End;

  { numero }
  E := ParseSqlExpr;
  If E >= 0 Then
    AddChild(N, E);

  { , message }
  If TokIs(TOK_COMMA) Then
  Begin
    Advance;
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  { , state }
  If TokIs(TOK_COMMA) Then
  Begin
    Advance;
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  ParseThrowStmt := N;
End;

{ ---- ParseRaiserrorStmt ---------------------------------------- }
{ RAISERROR (message, severity, state)                              }

Function ParseRaiserrorStmt : Integer;
Var
  N, E : Integer;
Begin
  ParseRaiserrorStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_RAISERROR) Then
  Begin
    ParseError('RAISERROR attendu');
    Exit;
  End;
  N := NewNode(ND_RAISERROR_STMT, 'RAISERROR', LexCurTok.Line,
               LexCurTok.Col);
  Advance; { skip RAISERROR }

  { ( }
  If TokIs(TOK_LPAREN) Then
    Advance
  Else
  Begin
    ParseError('( attendu apres RAISERROR');
    Exit;
  End;

  { message }
  E := ParseSqlExpr;
  If E >= 0 Then
    AddChild(N, E);

  { , severity }
  If TokIs(TOK_COMMA) Then
  Begin
    Advance;
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  { , state }
  If TokIs(TOK_COMMA) Then
  Begin
    Advance;
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  { Arguments supplementaires optionnels }
  While TokIs(TOK_COMMA) And ParseOk Do
  Begin
    Advance;
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
  End;

  { ) }
  If TokIs(TOK_RPAREN) Then
    Advance
  Else
    ParseError(') attendu pour fermer RAISERROR');

  ParseRaiserrorStmt := N;
End;

{ ---- ParsePrintStmt -------------------------------------------- }
{ PRINT expression                                                  }

Function ParsePrintStmt : Integer;
Var
  N, E : Integer;
Begin
  ParsePrintStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_PRINT) Then
  Begin
    ParseError('PRINT attendu');
    Exit;
  End;
  N := NewNode(ND_PRINT_STMT, 'PRINT', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip PRINT }

  E := ParseSqlExpr;
  If E >= 0 Then
    AddChild(N, E);

  ParsePrintStmt := N;
End;

{ ---- ParseExecStmt --------------------------------------------- }
{ EXEC / EXECUTE procedure [@ret =] proc @p1, @p2                  }
{ EXEC('chaine SQL dynamique')                                      }
{ sp_executesql N'requete', N'@p1 type', @p1=val                    }

Function ParseExecStmt : Integer;
Var
  N, E, A : Integer;
  ProcName : TString;
Begin
  ParseExecStmt := -1;
  If Not ParseOk Then Exit;
  If Not (KwIs(KW_EXEC) Or KwIs(KW_EXECUTE)) Then
  Begin
    ParseError('EXEC ou EXECUTE attendu');
    Exit;
  End;
  Advance; { skip EXEC/EXECUTE }

  { EXEC('chaine SQL dynamique') }
  If TokIs(TOK_LPAREN) Then
  Begin
    N := NewNode(ND_EXEC_SQL, 'EXEC_SQL', LexCurTok.Line, LexCurTok.Col);
    Advance; { skip ( }
    E := ParseSqlExpr;
    If E >= 0 Then
      AddChild(N, E);
    { Concatenation avec + }
    While TokIs(TOK_PLUS) And ParseOk Do
    Begin
      Advance;
      E := ParseSqlExpr;
      If E >= 0 Then
        AddChild(N, E);
    End;
    If TokIs(TOK_RPAREN) Then
      Advance;
    ParseExecStmt := N;
    Exit;
  End;

  { EXEC [@ret =] procedure @p1, @p2 }
  { Verifier @ret = proc }
  If (LexCurTok.Kind = TOK_VARIABLE) Then
  Begin
    ProcName := LexCurTok.Text;
    { Regarder si c est @ret = proc_name ou proc directement }
    { Pour simplifier, on regarde si le prochain token est = }
    N := NewNode(ND_EXEC_STMT, '', LexCurTok.Line, LexCurTok.Col);
    Advance;
    If TokIs(TOK_EQ) Then
    Begin
      { @ret = proc }
      ASTPool[N].Text := ProcName; { stocker var de retour }
      Advance; { skip = }
      { Nom de la procedure }
      If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
         (LexCurTok.Kind = TOK_DELIM_IDENT) Then
      Begin
        E := ParseObjectName;
        If E >= 0 Then
          AddChild(N, E);
      End;
    End
    Else
    Begin
      { La variable est en fait un parametre ou on a une erreur }
      { Traiter comme nom de proc stocke dans une variable }
      ASTPool[N].Text := ProcName;
    End;
  End
  Else If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
          (LexCurTok.Kind = TOK_DELIM_IDENT) Then
  Begin
    N := NewNode(ND_EXEC_STMT, '', LexCurTok.Line, LexCurTok.Col);
    E := ParseObjectName;
    If E >= 0 Then
      AddChild(N, E);
  End
  Else
  Begin
    ParseError('nom de procedure attendu');
    Exit;
  End;

  { Parametres : @p1 = val, @p2 = val, val, ... }
  If (LexCurTok.Kind <> TOK_EOF) And Not TokIs(TOK_SEMICOL) And
     Not KwIs(KW_END) And Not KwIs(KW_GO) Then
  Begin
    A := NewNode(ND_ARG_LIST, 'ARGS', LexCurTok.Line, LexCurTok.Col);
    Repeat
      E := ParseSqlExpr;
      If E >= 0 Then
        AddChild(A, E);
      If TokIs(TOK_COMMA) Then
        Advance
      Else
        Break;
    Until Not ParseOk Or (LexCurTok.Kind = TOK_EOF);
    AddChild(N, A);
  End;

  ParseExecStmt := N;
End;

{ ---- ParseUseStmt ---------------------------------------------- }
{ USE database                                                      }

Function ParseUseStmt : Integer;
Var
  N : Integer;
Begin
  ParseUseStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_USE) Then
  Begin
    ParseError('USE attendu');
    Exit;
  End;
  Advance; { skip USE }

  If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Or
     (LexCurTok.Kind = TOK_DELIM_IDENT) Then
  Begin
    N := NewNode(ND_USE_STMT, LexCurTok.Text, LexCurTok.Line,
                 LexCurTok.Col);
    Advance;
  End
  Else
  Begin
    ParseError('nom de base de donnees attendu');
    Exit;
  End;

  ParseUseStmt := N;
End;

{ ---- ParseGoStmt ----------------------------------------------- }
{ GO (separateur de batch)                                          }

Function ParseGoStmt : Integer;
Var
  N : Integer;
Begin
  ParseGoStmt := -1;
  If Not ParseOk Then Exit;
  If Not KwIs(KW_GO) Then
  Begin
    ParseError('GO attendu');
    Exit;
  End;
  N := NewNode(ND_GO_STMT, 'GO', LexCurTok.Line, LexCurTok.Col);
  Advance; { skip GO }

  ParseGoStmt := N;
End;

{ ---- ParseStatement -------------------------------------------- }
{ Dispatcher une instruction T-SQL unique                           }

Function ParseStatement : Integer;
Var
  N       : Integer;
Begin
  ParseStatement := -1;
  If Not ParseOk Then Exit;
  If LexCurTok.Kind = TOK_EOF Then Exit;

  { Point-virgule optionnel entre instructions }
  If TokIs(TOK_SEMICOL) Then
  Begin
    Advance;
    If LexCurTok.Kind = TOK_EOF Then Exit;
  End;

  { SELECT : verifier SELECT @var = expr (affectation) ou SELECT normal }
  If KwIs(KW_SELECT) Then
  Begin
    { Tester si c est SELECT @var = ... (variable assignment) }
    { On regarde le token apres SELECT : si c est @variable suivi de = }
    { Sauvegarder position puis regarder }
    ParseStatement := ParseSelectStmt;
    Exit;
  End;

  If KwIs(KW_INSERT) Then
  Begin
    ParseStatement := ParseInsertStmt;
    Exit;
  End;

  If KwIs(KW_UPDATE) Then
  Begin
    ParseStatement := ParseUpdateStmt;
    Exit;
  End;

  If KwIs(KW_DELETE) Then
  Begin
    ParseStatement := ParseDeleteStmt;
    Exit;
  End;

  If KwIs(KW_TRUNCATE) Then
  Begin
    ParseStatement := ParseTruncateStmt;
    Exit;
  End;

  If KwIs(KW_MERGE) Then
  Begin
    ParseStatement := ParseMergeStmt;
    Exit;
  End;

  If KwIs(KW_CREATE) Then
  Begin
    ParseStatement := ParseCreateStmt;
    Exit;
  End;

  If KwIs(KW_ALTER) Then
  Begin
    ParseStatement := ParseAlterStmt;
    Exit;
  End;

  If KwIs(KW_DROP) Then
  Begin
    ParseStatement := ParseDropStmt;
    Exit;
  End;

  { DCL (TODO 14) }
  If KwIs(KW_GRANT) Then
  Begin
    ParseStatement := ParseGrantStmt;
    Exit;
  End;

  If KwIs(KW_REVOKE) Then
  Begin
    ParseStatement := ParseRevokeStmt;
    Exit;
  End;

  If KwIs(KW_DENY) Then
  Begin
    ParseStatement := ParseDenyStmt;
    Exit;
  End;

  { T-SQL control flow (TODO 13) }
  If KwIs(KW_DECLARE) Then
  Begin
    ParseStatement := ParseDeclareStmt;
    Exit;
  End;

  If KwIs(KW_SET) Then
  Begin
    { SET @var = ... (pas SET NOCOUNT etc. pour l instant) }
    ParseStatement := ParseSetStmt;
    Exit;
  End;

  If KwIs(KW_IF) Then
  Begin
    ParseStatement := ParseIfStmt;
    Exit;
  End;

  If KwIs(KW_WHILE) Then
  Begin
    ParseStatement := ParseWhileStmt;
    Exit;
  End;

  If KwIs(KW_BEGIN) Then
  Begin
    ParseStatement := ParseBlockStmt;
    Exit;
  End;

  If KwIs(KW_BREAK) Then
  Begin
    N := NewNode(ND_BREAK_STMT, 'BREAK', LexCurTok.Line, LexCurTok.Col);
    Advance;
    ParseStatement := N;
    Exit;
  End;

  If KwIs(KW_CONTINUE) Then
  Begin
    N := NewNode(ND_CONTINUE_STMT, 'CONTINUE', LexCurTok.Line,
                 LexCurTok.Col);
    Advance;
    ParseStatement := N;
    Exit;
  End;

  If KwIs(KW_GOTO) Then
  Begin
    Advance; { skip GOTO }
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      N := NewNode(ND_GOTO_STMT, LexCurTok.Text, LexCurTok.Line,
                   LexCurTok.Col);
      Advance;
    End
    Else
    Begin
      ParseError('label attendu apres GOTO');
      Exit;
    End;
    ParseStatement := N;
    Exit;
  End;

  If KwIs(KW_RETURN) Then
  Begin
    ParseStatement := ParseReturnStmt;
    Exit;
  End;

  If KwIs(KW_WAITFOR) Then
  Begin
    ParseStatement := ParseWaitforStmt;
    Exit;
  End;

  If KwIs(KW_THROW) Then
  Begin
    ParseStatement := ParseThrowStmt;
    Exit;
  End;

  If KwIs(KW_RAISERROR) Then
  Begin
    ParseStatement := ParseRaiserrorStmt;
    Exit;
  End;

  If KwIs(KW_PRINT) Then
  Begin
    ParseStatement := ParsePrintStmt;
    Exit;
  End;

  If KwIs(KW_EXEC) Or KwIs(KW_EXECUTE) Then
  Begin
    ParseStatement := ParseExecStmt;
    Exit;
  End;

  If KwIs(KW_USE) Then
  Begin
    ParseStatement := ParseUseStmt;
    Exit;
  End;

  If KwIs(KW_GO) Then
  Begin
    ParseStatement := ParseGoStmt;
    Exit;
  End;

  { Label : ident suivi de : (traite comme expression) }
  If (LexCurTok.Kind = TOK_IDENT) Then
  Begin
    ParseStatement := ParseSqlExpr;
    Exit;
  End;

  { Expression par defaut }
  ParseStatement := ParseSqlExpr;
End;

{ ============================================================
  TODO 15 - MOTEUR D EXECUTION DES REQUETES [IMPLEMENTE]
  ============================================================ }

{ ---- Chercher un objet table par nom dans le catalogue ------- }
{ Retourne l index dans SysObjects ou -1 si introuvable.         }

Function QEFindTable(Const TblName : TTokenText) : Integer;
Var
  I   : Integer;
  U, N : TString;
Begin
  QEFindTable := -1;
  U := StrUpperCase(TblName);
  For I := 0 To SysObjCount - 1 Do
    If SysObjects[I].Valid Then
    Begin
      N := StrUpperCase(SysObjects[I].Name);
      If (N = U) And ((SysObjects[I].ObjType = 'U ') Or
         (SysObjects[I].ObjType = 'U') Or
         (SysObjects[I].ObjType = 'S ') Or
         (SysObjects[I].ObjType = 'S')) Then
      Begin
        QEFindTable := I;
        Exit;
      End;
    End;
End;

{ ---- Collecter les colonnes d une table ---------------------- }
{ Remplit le result set avec les definitions de colonnes.         }
{ Retourne le nombre de colonnes trouvees.                        }

Function QEGetTableCols(ObjId : LongInt;
                         Var Res : TQEResult) : Integer;
Var
  I, Cnt : Integer;
Begin
  Cnt := 0;
  For I := 0 To SysColCount - 1 Do
    If SysColumns[I].Valid And (SysColumns[I].ObjectId = ObjId) And
       (Cnt < MAX_QE_COLS) Then
    Begin
      Res.Cols[Cnt].Name   := SysColumns[I].Name;
      Res.Cols[Cnt].XType  := SysColumns[I].XType;
      Res.Cols[Cnt].MaxLen := SysColumns[I].MaxLen;
      Res.Cols[Cnt].Prec   := SysColumns[I].Prec;
      Res.Cols[Cnt].Scale  := SysColumns[I].Scale;
      Res.Cols[Cnt].ColIdx := I;
      Res.Cols[Cnt].Width  := Length(SysColumns[I].Name);
      If Res.Cols[Cnt].Width < 4 Then
        Res.Cols[Cnt].Width := 4;
      If Res.Cols[Cnt].Width > MAX_QE_COLWIDTH Then
        Res.Cols[Cnt].Width := MAX_QE_COLWIDTH;
      Inc(Cnt);
    End;
  Res.ColCnt := Cnt;
  QEGetTableCols := Cnt;
End;

{ ---- Tester si une colonne est NULL dans le bitmap ----------- }

Function QEColIsNull(Const Buf : TMdfPageBuf;
                      RowOfs : Word; FixedLen : Word;
                      ColNum : Integer) : Boolean;
Var
  NullBmpOfs : Word;
  ByteIdx    : Integer;
  BitIdx     : Integer;
Begin
  QEColIsNull := False;
  NullBmpOfs := RowOfs + FixedLen + 2;
  If NullBmpOfs >= MDF_PAGE_SIZE Then Exit;
  ByteIdx := ColNum Div 8;
  BitIdx  := ColNum Mod 8;
  If NullBmpOfs + ByteIdx >= MDF_PAGE_SIZE Then Exit;
  QEColIsNull := (Buf[NullBmpOfs + ByteIdx] And (1 Shl BitIdx)) <> 0;
End;

{ ---- Decoder les valeurs d une ligne d une page -------------- }
{ Lit les colonnes fixes et variables d un enregistrement         }
{ en utilisant les metadonnees du catalogue.                       }

Procedure QEDecodeRow(Const Buf : TMdfPageBuf;
                       RowOfs : Word;
                       Const Res : TQEResult;
                       Var Row : TQERow);
Var
  RH       : TMdfRowHeader;
  I        : Integer;
  ColXt    : Byte;
  FixOfs   : Word;
  FixSz    : Word;
  DataLen  : Word;
  VarOfs   : Word;
  VarCnt   : Word;
  OfsArr   : Word;
  VarStart : Word;
  VarEnd   : Word;
  PrevEnd  : Word;
  VarIdx   : Integer;
  CurFixed : Word;
Begin
  Row.ColCnt := Res.ColCnt;
  For I := 0 To Res.ColCnt - 1 Do
    InitSqlValue(Row.Vals[I]);

  ParseRowHeader(Buf, RowOfs, RH);
  If Not RH.Valid Then Exit;

  { Calculer les offsets des colonnes variables }
  VarOfs := 0;
  VarCnt := 0;
  OfsArr := 0;
  If RH.HasVarCols Then
  Begin
    VarOfs := RowOfs + RH.FixedLen + 2 + RH.NullBmpSize;
    If VarOfs + 2 <= MDF_PAGE_SIZE Then
    Begin
      VarCnt := ReadWord(Buf, VarOfs);
      OfsArr := VarOfs + 2;
    End;
  End;

  { Decoder chaque colonne }
  CurFixed := 4; { apres StatusA(1) + StatusB(1) + FixedLen(2) }
  VarIdx := 0;
  For I := 0 To Res.ColCnt - 1 Do
  Begin
    ColXt := Res.Cols[I].XType;

    { Verifier NULL }
    If RH.HasNullBmp And QEColIsNull(Buf, RowOfs, RH.FixedLen, I) Then
    Begin
      Row.Vals[I].IsNull := True;
      Row.Vals[I].Valid  := True;
      Row.Vals[I].XType  := ColXt;
      If SqlTypeIsVariable(ColXt) Then
        Inc(VarIdx);
      If Not SqlTypeIsVariable(ColXt) Then
      Begin
        FixSz := SqlTypeFixedSize(ColXt);
        If FixSz = 0 Then
        Begin
          If Res.Cols[I].MaxLen > 0 Then
            FixSz := Res.Cols[I].MaxLen
          Else
            FixSz := 1;
        End;
        CurFixed := CurFixed + FixSz;
      End;
      Continue;
    End;

    If SqlTypeIsVariable(ColXt) Then
    Begin
      { Colonne a longueur variable }
      If (VarIdx < VarCnt) And (OfsArr > 0) And
         (OfsArr + LongInt(VarCnt) * 2 <= MDF_PAGE_SIZE) Then
      Begin
        VarEnd := ReadWord(Buf, OfsArr + VarIdx * 2) And $7FFF;
        If VarIdx = 0 Then
          VarStart := OfsArr + VarCnt * 2 - RowOfs
        Else
        Begin
          PrevEnd := ReadWord(Buf, OfsArr + (VarIdx - 1) * 2) And $7FFF;
          VarStart := PrevEnd;
        End;
        If VarEnd > VarStart Then
          DataLen := VarEnd - VarStart
        Else
          DataLen := 0;
        If (RowOfs + VarStart < MDF_PAGE_SIZE) And (DataLen > 0) Then
          DecodeSqlValue(Buf, RowOfs + VarStart, DataLen,
                         ColXt, Res.Cols[I].Prec, Res.Cols[I].Scale,
                         Row.Vals[I])
        Else
        Begin
          Row.Vals[I].IsNull := True;
          Row.Vals[I].Valid  := True;
          Row.Vals[I].XType  := ColXt;
        End;
      End
      Else
      Begin
        Row.Vals[I].IsNull := True;
        Row.Vals[I].Valid  := True;
        Row.Vals[I].XType  := ColXt;
      End;
      Inc(VarIdx);
    End
    Else
    Begin
      { Colonne a longueur fixe }
      FixSz := SqlTypeFixedSize(ColXt);
      If FixSz = 0 Then
      Begin
        If Res.Cols[I].MaxLen > 0 Then
          FixSz := Res.Cols[I].MaxLen
        Else
          FixSz := 1;
      End;
      FixOfs := RowOfs + CurFixed;
      If FixOfs + FixSz <= MDF_PAGE_SIZE Then
        DecodeSqlValue(Buf, FixOfs, FixSz,
                       ColXt, Res.Cols[I].Prec, Res.Cols[I].Scale,
                       Row.Vals[I])
      Else
      Begin
        Row.Vals[I].IsNull := True;
        Row.Vals[I].Valid  := True;
        Row.Vals[I].XType  := ColXt;
      End;
      CurFixed := CurFixed + FixSz;
    End;
  End;
End;

{ ---- Comparer deux valeurs SQL ------------------------------- }
{ Retourne <0, 0, >0 comme une comparaison standard.             }

Function QECompareValues(Const A, B : TSqlValue) : Integer;
Var
  SA, SB : TSqlValueStr;
Begin
  { NULL en premier }
  If A.IsNull And B.IsNull Then Begin QECompareValues := 0; Exit; End;
  If A.IsNull Then Begin QECompareValues := -1; Exit; End;
  If B.IsNull Then Begin QECompareValues := 1; Exit; End;

  Case A.Category Of
    SQLCAT_INTEGER :
    Begin
      If A.IntVal < B.IntVal Then QECompareValues := -1
      Else If A.IntVal > B.IntVal Then QECompareValues := 1
      Else QECompareValues := 0;
    End;
    SQLCAT_DECIMAL :
    Begin
      If A.FloatVal < B.FloatVal Then QECompareValues := -1
      Else If A.FloatVal > B.FloatVal Then QECompareValues := 1
      Else QECompareValues := 0;
    End;
  Else
    Begin
      SA := SqlValueToStr(A);
      SB := SqlValueToStr(B);
      If SA < SB Then QECompareValues := -1
      Else If SA > SB Then QECompareValues := 1
      Else QECompareValues := 0;
    End;
  End;
End;

{ ---- Evaluer une expression AST contre une ligne ------------- }
{ Evaluation simplifiee : supporte colonnes, litteraux,           }
{ comparaisons, AND, OR, NOT, IS NULL, IS NOT NULL, BETWEEN,     }
{ LIKE (prefixe simple), IN.                                      }

Function QEEvalExpr(Node : Integer;
                     Const Row : TQERow;
                     Const Res : TQEResult) : TSqlValue; Forward;

Function QEEvalBool(Node : Integer;
                     Const Row : TQERow;
                     Const Res : TQEResult) : Boolean;
Var
  V : TSqlValue;
Begin
  V := QEEvalExpr(Node, Row, Res);
  QEEvalBool := (V.Valid) And (Not V.IsNull) And (V.IntVal <> 0);
End;

Function QEFindColByName(Const ColName : TTokenText;
                          Const Res : TQEResult) : Integer;
Var
  I    : Integer;
  U, N : TString;
Begin
  QEFindColByName := -1;
  U := StrUpperCase(ColName);
  For I := 0 To Res.ColCnt - 1 Do
  Begin
    N := StrUpperCase(Res.Cols[I].Name);
    If N = U Then
    Begin
      QEFindColByName := I;
      Exit;
    End;
  End;
End;

Function QESimpleLike(Const S, Pattern : TSqlValueStr) : Boolean;
Var
  PLen, SLen : Integer;
  PI, SI     : Integer;
Begin
  QESimpleLike := False;
  PLen := Length(Pattern);
  SLen := Length(S);
  If PLen = 0 Then
  Begin
    QESimpleLike := (SLen = 0);
    Exit;
  End;
  PI := 1;
  SI := 1;
  While (PI <= PLen) And (SI <= SLen) Do
  Begin
    If Pattern[PI] = '%' Then
    Begin
      { % au milieu ou fin : match le reste }
      If PI = PLen Then
      Begin
        QESimpleLike := True;
        Exit;
      End;
      { Chercher le caractere suivant }
      Inc(PI);
      While SI <= SLen Do
      Begin
        If UpCase(S[SI]) = UpCase(Pattern[PI]) Then Break;
        Inc(SI);
      End;
      If SI > SLen Then Exit;
    End
    Else If Pattern[PI] = '_' Then
    Begin
      Inc(PI);
      Inc(SI);
    End
    Else
    Begin
      If UpCase(S[SI]) <> UpCase(Pattern[PI]) Then Exit;
      Inc(PI);
      Inc(SI);
    End;
  End;
  { Ignorer les % restants dans le pattern }
  While (PI <= PLen) And (Pattern[PI] = '%') Do Inc(PI);
  QESimpleLike := (PI > PLen) And (SI > SLen);
End;

Function QEEvalExpr(Node : Integer;
                     Const Row : TQERow;
                     Const Res : TQEResult) : TSqlValue;
Var
  V, VL, VR, VT : TSqlValue;
  CI         : Integer;
  Op         : TTokenText;
  Child0, Child1, Child2 : Integer;
  I, J       : Integer;
  STmp       : TSqlValueStr;
Begin
  InitSqlValue(V);
  V.IsNull := True;

  If (Node < 0) Or (Node >= ASTCount) Then
  Begin
    QEEvalExpr := V;
    Exit;
  End;

  Child0 := -1; Child1 := -1; Child2 := -1;
  If ASTPool[Node].ChildCnt > 0 Then Child0 := ASTPool[Node].Children[0];
  If ASTPool[Node].ChildCnt > 1 Then Child1 := ASTPool[Node].Children[1];
  If ASTPool[Node].ChildCnt > 2 Then Child2 := ASTPool[Node].Children[2];

  Case ASTPool[Node].Kind Of
    ND_INT_LIT :
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      Val(ASTPool[Node].Text, V.IntVal, CI);
    End;
    ND_FLOAT_LIT :
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_DECIMAL;
      V.XType    := XT_FLOAT;
      V.Valid    := True;
      Val(ASTPool[Node].Text, V.FloatVal, CI);
    End;
    ND_STR_LIT, ND_NSTR_LIT :
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_STRING;
      V.XType    := XT_VARCHAR;
      V.StrVal   := ASTPool[Node].Text;
      V.Valid    := True;
    End;
    ND_NULL_LIT :
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End;
    ND_IDENT, ND_DELIM_IDENT :
    Begin
      CI := QEFindColByName(ASTPool[Node].Text, Res);
      If (CI >= 0) And (CI < Row.ColCnt) Then
        V := Row.Vals[CI]
      Else
      Begin
        V.IsNull := True;
        V.Valid  := True;
      End;
    End;
    ND_DOT_REF :
    Begin
      { table.colonne : utiliser le dernier enfant (nom de colonne) }
      If ASTPool[Node].ChildCnt > 0 Then
      Begin
        I := ASTPool[Node].Children[ASTPool[Node].ChildCnt - 1];
        If (I >= 0) And (I < ASTCount) Then
        Begin
          CI := QEFindColByName(ASTPool[I].Text, Res);
          If (CI >= 0) And (CI < Row.ColCnt) Then
            V := Row.Vals[CI]
          Else
          Begin
            V.IsNull := True;
            V.Valid  := True;
          End;
        End;
      End;
    End;
    ND_STAR :
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.IntVal   := 1;
      V.Valid    := True;
    End;
    ND_COMPARE :
    Begin
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        Op := ASTPool[Node].Text;
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        If VL.IsNull Or VR.IsNull Then
        Begin
          V.IsNull := True;
        End
        Else
        Begin
          CI := QECompareValues(VL, VR);
          If Op = '=' Then V.IntVal := Ord(CI = 0)
          Else If (Op = '<>') Or (Op = '!=') Then V.IntVal := Ord(CI <> 0)
          Else If Op = '<' Then V.IntVal := Ord(CI < 0)
          Else If Op = '>' Then V.IntVal := Ord(CI > 0)
          Else If Op = '<=' Then V.IntVal := Ord(CI <= 0)
          Else If Op = '>=' Then V.IntVal := Ord(CI >= 0)
          Else V.IntVal := 0;
        End;
      End;
    End;
    ND_AND :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        If QEEvalBool(Child0, Row, Res) And
           QEEvalBool(Child1, Row, Res) Then
          V.IntVal := 1
        Else
          V.IntVal := 0;
      End
      Else
        V.IntVal := 0;
    End;
    ND_OR :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        If QEEvalBool(Child0, Row, Res) Or
           QEEvalBool(Child1, Row, Res) Then
          V.IntVal := 1
        Else
          V.IntVal := 0;
      End
      Else
        V.IntVal := 0;
    End;
    ND_NOT :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If Child0 >= 0 Then
        V.IntVal := Ord(Not QEEvalBool(Child0, Row, Res))
      Else
        V.IntVal := 0;
    End;
    ND_IS_NULL :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If Child0 >= 0 Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.IntVal := Ord(VL.IsNull);
      End
      Else
        V.IntVal := 0;
    End;
    ND_IS_NOT_NULL :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If Child0 >= 0 Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.IntVal := Ord(Not VL.IsNull);
      End
      Else
        V.IntVal := 0;
    End;
    ND_BETWEEN :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      If (Child0 >= 0) And (Child1 >= 0) And (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.IntVal := 0;
        If (Not VL.IsNull) And (Not VR.IsNull) Then
        Begin
          If QECompareValues(VL, VR) >= 0 Then
          Begin
            VR := QEEvalExpr(Child2, Row, Res);
            If (Not VR.IsNull) And (QECompareValues(VL, VR) <= 0) Then
              V.IntVal := 1;
          End;
        End;
      End
      Else
        V.IntVal := 0;
    End;
    ND_IN :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      V.IntVal   := 0;
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        If Not VL.IsNull Then
        Begin
          { Child1 est un ND_ARG_LIST }
          If (Child1 >= 0) And (Child1 < ASTCount) Then
            For I := 0 To ASTPool[Child1].ChildCnt - 1 Do
            Begin
              VR := QEEvalExpr(ASTPool[Child1].Children[I], Row, Res);
              If (Not VR.IsNull) And (QECompareValues(VL, VR) = 0) Then
              Begin
                V.IntVal := 1;
                Break;
              End;
            End;
        End;
      End;
    End;
    ND_LIKE :
    Begin
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.Valid    := True;
      V.IsNull   := False;
      V.IntVal   := 0;
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        If (Not VL.IsNull) And (Not VR.IsNull) Then
        Begin
          If QESimpleLike(SqlValueToStr(VL), SqlValueToStr(VR)) Then
            V.IntVal := 1;
        End;
      End;
    End;
    ND_BINOP :
    Begin
      If (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        Op := ASTPool[Node].Text;
        V.Valid  := True;
        V.IsNull := False;
        If VL.IsNull Or VR.IsNull Then
          V.IsNull := True
        Else If (VL.Category = SQLCAT_INTEGER) And
                (VR.Category = SQLCAT_INTEGER) Then
        Begin
          V.Category := SQLCAT_INTEGER;
          V.XType    := XT_INT;
          If Op = '+' Then V.IntVal := VL.IntVal + VR.IntVal
          Else If Op = '-' Then V.IntVal := VL.IntVal - VR.IntVal
          Else If Op = '*' Then V.IntVal := VL.IntVal * VR.IntVal
          Else If (Op = '/') And (VR.IntVal <> 0) Then
            V.IntVal := VL.IntVal Div VR.IntVal
          Else If (Op = '%') And (VR.IntVal <> 0) Then
            V.IntVal := VL.IntVal Mod VR.IntVal
          Else V.IntVal := 0;
        End
        Else
        Begin
          V.Category := SQLCAT_DECIMAL;
          V.XType    := XT_FLOAT;
          If Op = '+' Then V.FloatVal := VL.FloatVal + VR.FloatVal
          Else If Op = '-' Then V.FloatVal := VL.FloatVal - VR.FloatVal
          Else If Op = '*' Then V.FloatVal := VL.FloatVal * VR.FloatVal
          Else If (Op = '/') And (VR.FloatVal <> 0) Then
            V.FloatVal := VL.FloatVal / VR.FloatVal
          Else V.FloatVal := 0;
        End;
      End;
    End;
    ND_UNARY :
    Begin
      If Child0 >= 0 Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V  := VL;
        Op := ASTPool[Node].Text;
        If Op = '-' Then
        Begin
          If V.Category = SQLCAT_INTEGER Then
            V.IntVal := -V.IntVal
          Else If V.Category = SQLCAT_DECIMAL Then
            V.FloatVal := -V.FloatVal;
        End;
      End;
    End;
    ND_FUNC_CALL :
    Begin
      { Fonctions scalaires simples }
      Op := StrUpperCase(ASTPool[Node].Text);
      If (Op = 'UPPER') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V := VL;
        If Not V.IsNull Then
          V.StrVal := StrUpperCase(V.StrVal);
      End
      Else If (Op = 'LOWER') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V := VL;
        If Not V.IsNull Then
          V.StrVal := StrLowerCase(V.StrVal);
      End
      Else If (Op = 'LEN') Or (Op = 'DATALENGTH') Then
      Begin
        If Child0 >= 0 Then VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        If VL.IsNull Then V.IsNull := True
        Else V.IntVal := Length(SqlValueToStr(VL));
      End
      Else If Op = 'ISNULL' Then
      Begin
        If (Child0 >= 0) And (Child1 >= 0) Then
        Begin
          VL := QEEvalExpr(Child0, Row, Res);
          If VL.IsNull Then
            V := QEEvalExpr(Child1, Row, Res)
          Else
            V := VL;
        End;
      End
      Else If Op = 'COALESCE' Then
      Begin
        V.IsNull := True;
        V.Valid  := True;
        For I := 0 To ASTPool[Node].ChildCnt - 1 Do
        Begin
          VL := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
          If Not VL.IsNull Then
          Begin
            V := VL;
            Break;
          End;
        End;
      End
      Else If Op = 'ABS' Then
      Begin
        If Child0 >= 0 Then
        Begin
          V := QEEvalExpr(Child0, Row, Res);
          If Not V.IsNull Then
          Begin
            If (V.Category = SQLCAT_INTEGER) And (V.IntVal < 0) Then
              V.IntVal := -V.IntVal
            Else If (V.Category = SQLCAT_DECIMAL) And
                    (V.FloatVal < 0) Then
              V.FloatVal := -V.FloatVal;
          End;
        End;
      End
      { ===== TODO 19 : Fonctions scalaires chaines ===== }
      Else If (Op = 'LEFT') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else V.StrVal := Copy(SqlValueToStr(VL), 1, VR.IntVal);
      End
      Else If (Op = 'RIGHT') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          If VR.IntVal >= Length(Op) Then V.StrVal := Op
          Else V.StrVal := Copy(Op, Length(Op) - VR.IntVal + 1, VR.IntVal);
          Op := 'RIGHT';
        End;
      End
      Else If (Op = 'SUBSTRING') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          I := VR.IntVal;
          If Child2 >= 0 Then Begin
            VR := QEEvalExpr(Child2, Row, Res);
            If VR.IsNull Then V.IsNull := True
            Else V.StrVal := Copy(Op, I, VR.IntVal);
          End
          Else V.StrVal := Copy(Op, I, Length(Op));
          Op := 'SUBSTRING';
        End;
      End
      Else If (Op = 'LTRIM') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          I := 1;
          While (I <= Length(Op)) And (Op[I] = ' ') Do Inc(I);
          V.StrVal := Copy(Op, I, Length(Op) - I + 1);
          Op := 'LTRIM';
        End;
      End
      Else If (Op = 'RTRIM') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          I := Length(Op);
          While (I > 0) And (Op[I] = ' ') Do Dec(I);
          V.StrVal := Copy(Op, 1, I);
          Op := 'RTRIM';
        End;
      End
      Else If (Op = 'TRIM') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          I := 1;
          While (I <= Length(Op)) And (Op[I] = ' ') Do Inc(I);
          Op := Copy(Op, I, Length(Op) - I + 1);
          I := Length(Op);
          While (I > 0) And (Op[I] = ' ') Do Dec(I);
          V.StrVal := Copy(Op, 1, I);
          Op := 'TRIM';
        End;
      End
      Else If (Op = 'REPLACE') And (Child0 >= 0) And (Child1 >= 0) And
              (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          VT := QEEvalExpr(Child2, Row, Res);
          V.StrVal := '';
          VR.StrVal := SqlValueToStr(VR);
          STmp := SqlValueToStr(VT);
          I := 1;
          While I <= Length(Op) Do
          Begin
            If (Length(VR.StrVal) > 0) And
               (Copy(Op, I, Length(VR.StrVal)) = VR.StrVal) Then
            Begin
              V.StrVal := V.StrVal + STmp;
              I := I + Length(VR.StrVal);
            End
            Else Begin
              If Length(V.StrVal) < MAX_SQL_VALUE_STR Then
                V.StrVal := V.StrVal + Op[I];
              Inc(I);
            End;
          End;
          Op := 'REPLACE';
        End;
      End
      Else If (Op = 'REPLICATE') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          V.StrVal := '';
          For I := 1 To VR.IntVal Do
          Begin
            If Length(V.StrVal) + Length(SqlValueToStr(VL)) <=
               MAX_SQL_VALUE_STR Then
              V.StrVal := V.StrVal + SqlValueToStr(VL)
            Else Break;
          End;
        End;
      End
      Else If (Op = 'REVERSE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          V.StrVal := '';
          For I := Length(Op) DownTo 1 Do
            If Length(V.StrVal) < MAX_SQL_VALUE_STR Then
              V.StrVal := V.StrVal + Op[I];
          Op := 'REVERSE';
        End;
      End
      Else If (Op = 'CHARINDEX') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          I := 1;
          If Child2 >= 0 Then Begin
            VT := QEEvalExpr(Child2, Row, Res);
            If Not VT.IsNull Then I := VT.IntVal;
          End;
          Op := SqlValueToStr(VR);
          VL.StrVal := SqlValueToStr(VL);
          If I > 1 Then
          Begin
            J := Pos(VL.StrVal, Copy(Op, I, Length(Op) - I + 1));
            If J > 0 Then V.IntVal := J + I - 1
            Else V.IntVal := 0;
          End
          Else
            V.IntVal := Pos(VL.StrVal, Op);
          Op := 'CHARINDEX';
        End;
      End
      Else If (Op = 'PATINDEX') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IntVal   := 0;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          { Simplified: treat %pattern% as substring search }
          Op := SqlValueToStr(VL);
          VR.StrVal := SqlValueToStr(VR);
          { Strip leading/trailing % }
          If (Length(Op) >= 2) And (Op[1] = '%') And
             (Op[Length(Op)] = '%') Then
            Op := Copy(Op, 2, Length(Op) - 2);
          If Length(Op) > 0 Then
            V.IntVal := Pos(Op, VR.StrVal);
          Op := 'PATINDEX';
        End;
      End
      Else If (Op = 'STUFF') And (Child0 >= 0) And (Child1 >= 0) And
              (Child2 >= 0) And (ASTPool[Node].ChildCnt >= 4) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          VR := QEEvalExpr(Child1, Row, Res);
          VL := QEEvalExpr(Child2, Row, Res);
          VT := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          If VR.IsNull Or VL.IsNull Then V.IsNull := True
          Else Begin
            I := VR.IntVal; { start }
            V.StrVal := Copy(Op, 1, I - 1) + SqlValueToStr(VT) +
                         Copy(Op, I + VL.IntVal, Length(Op));
          End;
          Op := 'STUFF';
        End;
      End
      Else If Op = 'CONCAT' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := '';
        For I := 0 To ASTPool[Node].ChildCnt - 1 Do
        Begin
          VL := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
          If Not VL.IsNull Then
            V.StrVal := V.StrVal + SqlValueToStr(VL);
        End;
      End
      Else If Op = 'CONCAT_WS' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := '';
        If Child0 >= 0 Then
        Begin
          VR := QEEvalExpr(Child0, Row, Res);
          If VR.IsNull Then V.IsNull := True
          Else Begin
            CI := 0;
            For I := 1 To ASTPool[Node].ChildCnt - 1 Do
            Begin
              VL := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
              If Not VL.IsNull Then
              Begin
                If CI > 0 Then V.StrVal := V.StrVal + SqlValueToStr(VR);
                V.StrVal := V.StrVal + SqlValueToStr(VL);
                Inc(CI);
              End;
            End;
          End;
        End;
      End
      Else If Op = 'FORMAT' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        If (Child0 >= 0) And (Child1 >= 0) Then
        Begin
          VL := QEEvalExpr(Child0, Row, Res);
          If VL.IsNull Then V.IsNull := True
          Else V.StrVal := SqlValueToStr(VL);
        End
        Else V.IsNull := True;
      End
      Else If Op = 'QUOTENAME' Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          If Child1 >= 0 Then Begin
            VR := QEEvalExpr(Child1, Row, Res);
            If (Not VR.IsNull) And (Length(SqlValueToStr(VR)) > 0) Then
            Begin
              CI := Ord(SqlValueToStr(VR)[1]);
              If Chr(CI) = '''' Then
                V.StrVal := '''' + Op + ''''
              Else If Chr(CI) = '"' Then
                V.StrVal := '"' + Op + '"'
              Else If Chr(CI) = '(' Then
                V.StrVal := '(' + Op + ')'
              Else
                V.StrVal := '[' + Op + ']';
            End
            Else V.StrVal := '[' + Op + ']';
          End
          Else V.StrVal := '[' + Op + ']';
          Op := 'QUOTENAME';
        End;
      End
      Else If (Op = 'CHAR') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_CHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else If (VL.IntVal >= 0) And (VL.IntVal <= 255) Then
          V.StrVal := Chr(VL.IntVal)
        Else V.IsNull := True;
      End
      Else If (Op = 'NCHAR') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else If (VL.IntVal >= 0) And (VL.IntVal <= 255) Then
          V.StrVal := Chr(VL.IntVal)
        Else V.IsNull := True;
      End
      Else If ((Op = 'ASCII') Or (Op = 'UNICODE')) And
              (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          If Length(Op) > 0 Then V.IntVal := Ord(Op[1])
          Else V.IsNull := True;
          Op := 'ASCII';
        End;
      End
      Else If (Op = 'SPACE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.StrVal := '';
          I := VL.IntVal;
          If I > MAX_SQL_VALUE_STR Then I := MAX_SQL_VALUE_STR;
          If I < 0 Then I := 0;
          While Length(V.StrVal) < I Do
            V.StrVal := V.StrVal + ' ';
        End;
      End
      Else If (Op = 'STR') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          If VL.Category = SQLCAT_INTEGER Then
            Str(VL.IntVal, V.StrVal)
          Else
            Str(VL.FloatVal:10:0, V.StrVal);
        End;
      End
      Else If (Op = 'SOUNDEX') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := StrUpperCase(SqlValueToStr(VL));
          V.StrVal := '';
          If Length(Op) > 0 Then
          Begin
            V.StrVal := Op[1];
            CI := 0;
            For I := 2 To Length(Op) Do
            Begin
              Case Op[I] Of
                'B','F','P','V'                 : CI := Ord('1');
                'C','G','J','K','Q','S','X','Z' : CI := Ord('2');
                'D','T'                         : CI := Ord('3');
                'L'                             : CI := Ord('4');
                'M','N'                         : CI := Ord('5');
                'R'                             : CI := Ord('6');
              Else CI := 0;
              End;
              If (CI > 0) And (Length(V.StrVal) < 4) Then
              Begin
                If (Length(V.StrVal) < 1) Or
                   (V.StrVal[Length(V.StrVal)] <> Chr(CI)) Then
                  V.StrVal := V.StrVal + Chr(CI);
              End;
            End;
            While Length(V.StrVal) < 4 Do V.StrVal := V.StrVal + '0';
          End;
          Op := 'SOUNDEX';
        End;
      End
      Else If (Op = 'DIFFERENCE') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IntVal   := 0;
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          { Compare SOUNDEX codes character by character }
          V.IntVal := 0;
          For I := 1 To 4 Do
          Begin
            If (I <= Length(VL.StrVal)) And (I <= Length(VR.StrVal)) Then
              If VL.StrVal[I] = VR.StrVal[I] Then Inc(V.IntVal);
          End;
        End;
      End
      Else If (Op = 'TRANSLATE') And (Child0 >= 0) And (Child1 >= 0) And
              (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          VT := QEEvalExpr(Child2, Row, Res);
          Op := SqlValueToStr(VL);
          VR.StrVal := SqlValueToStr(VR);
          STmp := SqlValueToStr(VT);
          V.StrVal := '';
          For I := 1 To Length(Op) Do
          Begin
            J := Pos(Op[I], VR.StrVal);
            If (J > 0) And (J <= Length(STmp)) Then
            Begin
              If Length(V.StrVal) < MAX_SQL_VALUE_STR Then
                V.StrVal := V.StrVal + STmp[J];
            End
            Else Begin
              If Length(V.StrVal) < MAX_SQL_VALUE_STR Then
                V.StrVal := V.StrVal + Op[I];
            End;
          End;
          Op := 'TRANSLATE';
        End;
      End
      Else If (Op = 'STRING_ESCAPE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          V.StrVal := '';
          For I := 1 To Length(Op) Do
          Begin
            If Length(V.StrVal) < MAX_SQL_VALUE_STR - 1 Then
            Case Op[I] Of
              '"'  : V.StrVal := V.StrVal + '\"';
              '\'  : V.StrVal := V.StrVal + '\\';
              '/'  : V.StrVal := V.StrVal + '\/';
              #8   : V.StrVal := V.StrVal + '\b';
              #12  : V.StrVal := V.StrVal + '\f';
              #10  : V.StrVal := V.StrVal + '\n';
              #13  : V.StrVal := V.StrVal + '\r';
              #9   : V.StrVal := V.StrVal + '\t';
            Else
              V.StrVal := V.StrVal + Op[I];
            End;
          End;
          Op := 'STRING_ESCAPE';
        End;
      End
      { ===== TODO 19 suite : STRING_SPLIT ===== }
      Else If (Op = 'STRING_SPLIT') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_VARCHAR;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          Op := SqlValueToStr(VL);
          STmp := SqlValueToStr(VR);
          { Return the first split element }
          If Length(STmp) > 0 Then
          Begin
            I := Pos(STmp, Op);
            If I > 0 Then
              V.StrVal := Copy(Op, 1, I - 1)
            Else
              V.StrVal := Op;
          End
          Else V.StrVal := Op;
          Op := 'STRING_SPLIT';
        End;
      End
      { ===== TODO 20 : Fonctions scalaires dates et heures ===== }
      Else If (Op = 'GETDATE') Or (Op = 'SYSDATETIME') Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIME;
        V.Valid    := True;
        V.IsNull   := False;
        V.Year     := 2026;
        V.Month    := 1;
        V.Day      := 1;
        V.Hour     := 0;
        V.Minute   := 0;
        V.Second   := 0;
        V.Frac     := 0;
        { Format as string for display }
        Str(V.Year:4, STmp);
        V.StrVal := STmp + '-';
        Str(V.Month:2, STmp);
        If V.Month < 10 Then V.StrVal := V.StrVal + '0';
        Str(V.Month, STmp);
        V.StrVal := V.StrVal + STmp + '-';
        If V.Day < 10 Then V.StrVal := V.StrVal + '0';
        Str(V.Day, STmp);
        V.StrVal := V.StrVal + STmp + ' ';
        If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
        Str(V.Hour, STmp);
        V.StrVal := V.StrVal + STmp + ':';
        If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
        Str(V.Minute, STmp);
        V.StrVal := V.StrVal + STmp + ':';
        If V.Second < 10 Then V.StrVal := V.StrVal + '0';
        Str(V.Second, STmp);
        V.StrVal := V.StrVal + STmp + '.000';
      End
      Else If (Op = 'GETUTCDATE') Or (Op = 'SYSUTCDATETIME') Or
              (Op = 'SYSDATETIMEOFFSET') Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIME;
        V.Valid    := True;
        V.IsNull   := False;
        V.Year     := 2026;
        V.Month    := 1;
        V.Day      := 1;
        V.Hour     := 0;
        V.Minute   := 0;
        V.Second   := 0;
        V.Frac     := 0;
        Str(V.Year:4, STmp);
        V.StrVal := STmp + '-01-01 00:00:00.000';
      End
      Else If (Op = 'YEAR') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else If VL.Category = SQLCAT_DATETIME Then
          V.IntVal := VL.Year
        Else Begin
          { Try to parse from string YYYY-MM-DD }
          Op := SqlValueToStr(VL);
          Val(Copy(Op, 1, 4), V.IntVal, CI);
          Op := 'YEAR';
        End;
      End
      Else If (Op = 'MONTH') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else If VL.Category = SQLCAT_DATETIME Then
          V.IntVal := VL.Month
        Else Begin
          Op := SqlValueToStr(VL);
          If (Length(Op) >= 7) And (Op[5] = '-') Then
            Val(Copy(Op, 6, 2), V.IntVal, CI)
          Else V.IntVal := 0;
          Op := 'MONTH';
        End;
      End
      Else If (Op = 'DAY') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else If VL.Category = SQLCAT_DATETIME Then
          V.IntVal := VL.Day
        Else Begin
          Op := SqlValueToStr(VL);
          If (Length(Op) >= 10) And (Op[8] = '-') Then
            Val(Copy(Op, 9, 2), V.IntVal, CI)
          Else V.IntVal := 0;
          Op := 'DAY';
        End;
      End
      Else If (Op = 'DATEPART') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VR.IsNull Then V.IsNull := True
        Else Begin
          Op := StrUpperCase(SqlValueToStr(VL));
          If (Op = 'YEAR') Or (Op = 'YY') Or (Op = 'YYYY') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Year
            Else Begin Val(Copy(SqlValueToStr(VR), 1, 4), V.IntVal, CI); End;
          End
          Else If (Op = 'MONTH') Or (Op = 'MM') Or (Op = 'M') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Month
            Else Begin
              STmp := SqlValueToStr(VR);
              If (Length(STmp) >= 7) And (STmp[5] = '-') Then
                Val(Copy(STmp, 6, 2), V.IntVal, CI)
              Else V.IntVal := 0;
            End;
          End
          Else If (Op = 'DAY') Or (Op = 'DD') Or (Op = 'D') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Day
            Else Begin
              STmp := SqlValueToStr(VR);
              If (Length(STmp) >= 10) And (STmp[8] = '-') Then
                Val(Copy(STmp, 9, 2), V.IntVal, CI)
              Else V.IntVal := 0;
            End;
          End
          Else If (Op = 'HOUR') Or (Op = 'HH') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Hour
            Else V.IntVal := 0;
          End
          Else If (Op = 'MINUTE') Or (Op = 'MI') Or (Op = 'N') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Minute
            Else V.IntVal := 0;
          End
          Else If (Op = 'SECOND') Or (Op = 'SS') Or (Op = 'S') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Second
            Else V.IntVal := 0;
          End
          Else If (Op = 'QUARTER') Or (Op = 'QQ') Or (Op = 'Q') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then
              V.IntVal := ((VR.Month - 1) Div 3) + 1
            Else V.IntVal := 0;
          End
          Else If (Op = 'WEEK') Or (Op = 'WK') Or (Op = 'WW') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then
              V.IntVal := ((VR.Day - 1) Div 7) + 1
            Else V.IntVal := 0;
          End
          Else If (Op = 'MILLISECOND') Or (Op = 'MS') Then
          Begin
            If VR.Category = SQLCAT_DATETIME Then V.IntVal := VR.Frac
            Else V.IntVal := 0;
          End
          Else V.IntVal := 0;
          Op := 'DATEPART';
        End;
      End
      Else If (Op = 'DATENAME') And (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        If VR.IsNull Then V.IsNull := True
        Else Begin
          Op := StrUpperCase(SqlValueToStr(VL));
          If (Op = 'MONTH') Or (Op = 'MM') Or (Op = 'M') Then
          Begin
            CI := 0;
            If VR.Category = SQLCAT_DATETIME Then CI := VR.Month
            Else Begin
              STmp := SqlValueToStr(VR);
              If (Length(STmp) >= 7) And (STmp[5] = '-') Then
                Val(Copy(STmp, 6, 2), CI, J);
            End;
            Case CI Of
              1  : V.StrVal := 'January';
              2  : V.StrVal := 'February';
              3  : V.StrVal := 'March';
              4  : V.StrVal := 'April';
              5  : V.StrVal := 'May';
              6  : V.StrVal := 'June';
              7  : V.StrVal := 'July';
              8  : V.StrVal := 'August';
              9  : V.StrVal := 'September';
              10 : V.StrVal := 'October';
              11 : V.StrVal := 'November';
              12 : V.StrVal := 'December';
            Else   V.StrVal := '';
            End;
          End
          Else If (Op = 'WEEKDAY') Or (Op = 'DW') Then
            V.StrVal := 'Monday'
          Else Begin
            { For other parts, return numeric as string }
            Str(0, V.StrVal);
          End;
          Op := 'DATENAME';
        End;
      End
      Else If (Op = 'DATEADD') And (Child0 >= 0) And (Child1 >= 0) And
              (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        VT := QEEvalExpr(Child2, Row, Res);
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIME;
        V.Valid    := True;
        If VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VT.Category = SQLCAT_DATETIME Then
          Begin
            V.Year   := VT.Year;
            V.Month  := VT.Month;
            V.Day    := VT.Day;
            V.Hour   := VT.Hour;
            V.Minute := VT.Minute;
            V.Second := VT.Second;
            V.Frac   := VT.Frac;
          End
          Else Begin
            { Parse YYYY-MM-DD from string }
            STmp := SqlValueToStr(VT);
            Val(Copy(STmp, 1, 4), I, CI);
            V.Year := I;
            If (Length(STmp) >= 7) And (STmp[5] = '-') Then
            Begin Val(Copy(STmp, 6, 2), I, CI); V.Month := I; End
            Else V.Month := 1;
            If (Length(STmp) >= 10) And (STmp[8] = '-') Then
            Begin Val(Copy(STmp, 9, 2), I, CI); V.Day := I; End
            Else V.Day := 1;
            V.Hour := 0; V.Minute := 0; V.Second := 0; V.Frac := 0;
          End;
          Op := StrUpperCase(SqlValueToStr(VL));
          I := VR.IntVal;
          If (Op = 'YEAR') Or (Op = 'YY') Or (Op = 'YYYY') Then
            V.Year := V.Year + I
          Else If (Op = 'MONTH') Or (Op = 'MM') Or (Op = 'M') Then
          Begin
            J := V.Month + I - 1;
            If J >= 0 Then
            Begin
              V.Year := V.Year + (J Div 12);
              V.Month := (J Mod 12) + 1;
            End
            Else Begin
              V.Year := V.Year + ((J + 1) Div 12) - 1;
              V.Month := 12 + ((J + 1) Mod 12);
              If V.Month = 0 Then Begin V.Month := 12; Dec(V.Year); End;
            End;
          End
          Else If (Op = 'DAY') Or (Op = 'DD') Or (Op = 'D') Then
            V.Day := V.Day + I
          Else If (Op = 'HOUR') Or (Op = 'HH') Then
            V.Hour := V.Hour + I
          Else If (Op = 'MINUTE') Or (Op = 'MI') Or (Op = 'N') Then
            V.Minute := V.Minute + I
          Else If (Op = 'SECOND') Or (Op = 'SS') Or (Op = 'S') Then
            V.Second := V.Second + I
          Else If (Op = 'QUARTER') Or (Op = 'QQ') Or (Op = 'Q') Then
          Begin
            J := V.Month + (I * 3) - 1;
            If J >= 0 Then
            Begin
              V.Year := V.Year + (J Div 12);
              V.Month := (J Mod 12) + 1;
            End
            Else Begin
              V.Year := V.Year + ((J + 1) Div 12) - 1;
              V.Month := 12 + ((J + 1) Mod 12);
            End;
          End
          Else If (Op = 'WEEK') Or (Op = 'WK') Or (Op = 'WW') Then
            V.Day := V.Day + (I * 7);
          { Format result as string }
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp + ' ';
          If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Second < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Second, STmp);
          V.StrVal := V.StrVal + STmp + '.000';
          Op := 'DATEADD';
        End;
      End
      Else If ((Op = 'DATEDIFF') Or (Op = 'DATEDIFF_BIG')) And
              (Child0 >= 0) And (Child1 >= 0) And (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        VT := QEEvalExpr(Child2, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          Op := StrUpperCase(SqlValueToStr(VL));
          { Extract year/month/day from both dates }
          If VR.Category = SQLCAT_DATETIME Then
          Begin I := VR.Year; J := VR.Month; CI := VR.Day; End
          Else Begin
            STmp := SqlValueToStr(VR);
            Val(Copy(STmp, 1, 4), I, CI);
            If (Length(STmp) >= 7) And (STmp[5] = '-') Then
              Val(Copy(STmp, 6, 2), J, CI)
            Else J := 1;
            If (Length(STmp) >= 10) And (STmp[8] = '-') Then
              Val(Copy(STmp, 9, 2), CI, CI)
            Else CI := 1;
          End;
          { I=startYear, J=startMonth, CI=startDay }
          If VT.Category = SQLCAT_DATETIME Then
          Begin
            { endYear in V.IntVal temp }
            If (Op = 'YEAR') Or (Op = 'YY') Or (Op = 'YYYY') Then
              V.IntVal := VT.Year - I
            Else If (Op = 'MONTH') Or (Op = 'MM') Or (Op = 'M') Then
              V.IntVal := (VT.Year - I) * 12 + (VT.Month - J)
            Else If (Op = 'DAY') Or (Op = 'DD') Or (Op = 'D') Then
              V.IntVal := (VT.Year - I) * 365 + (VT.Month - J) * 30 +
                          (VT.Day - CI)
            Else If (Op = 'QUARTER') Or (Op = 'QQ') Or (Op = 'Q') Then
              V.IntVal := ((VT.Year - I) * 12 + (VT.Month - J)) Div 3
            Else If (Op = 'WEEK') Or (Op = 'WK') Or (Op = 'WW') Then
              V.IntVal := ((VT.Year - I) * 365 + (VT.Month - J) * 30 +
                          (VT.Day - CI)) Div 7
            Else If (Op = 'HOUR') Or (Op = 'HH') Then
              V.IntVal := ((VT.Year - I) * 365 + (VT.Month - J) * 30 +
                          (VT.Day - CI)) * 24 + (VT.Hour - VR.Hour)
            Else If (Op = 'MINUTE') Or (Op = 'MI') Or (Op = 'N') Then
              V.IntVal := (((VT.Year - I) * 365 + (VT.Month - J) * 30 +
                          (VT.Day - CI)) * 24 + (VT.Hour - VR.Hour)) *
                          60 + (VT.Minute - VR.Minute)
            Else If (Op = 'SECOND') Or (Op = 'SS') Or (Op = 'S') Then
              V.IntVal := ((((VT.Year - I) * 365 + (VT.Month - J) * 30 +
                          (VT.Day - CI)) * 24 + (VT.Hour - VR.Hour)) *
                          60 + (VT.Minute - VR.Minute)) *
                          60 + (VT.Second - VR.Second)
            Else V.IntVal := 0;
          End
          Else Begin
            { Parse end date from string }
            STmp := SqlValueToStr(VT);
            Val(Copy(STmp, 1, 4), V.IntVal, J);
            If (Op = 'YEAR') Or (Op = 'YY') Or (Op = 'YYYY') Then
              V.IntVal := V.IntVal - I
            Else V.IntVal := 0;
          End;
          Op := 'DATEDIFF';
        End;
      End
      Else If (Op = 'DATEFROMPARTS') And (Child0 >= 0) And
              (Child1 >= 0) And (Child2 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        VT := QEEvalExpr(Child2, Row, Res);
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATE;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          V.Year  := VL.IntVal;
          V.Month := VR.IntVal;
          V.Day   := VT.IntVal;
          V.Hour  := 0; V.Minute := 0; V.Second := 0; V.Frac := 0;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp;
        End;
      End
      Else If (Op = 'DATETIMEFROMPARTS') And (ASTPool[Node].ChildCnt >= 7) Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIME;
        V.Valid    := True;
        V.IsNull   := False;
        VL := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        VR := QEEvalExpr(ASTPool[Node].Children[1], Row, Res);
        VT := QEEvalExpr(ASTPool[Node].Children[2], Row, Res);
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.Year  := VL.IntVal;
          V.Month := VR.IntVal;
          V.Day   := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[4], Row, Res);
          VT := QEEvalExpr(ASTPool[Node].Children[5], Row, Res);
          If VL.IsNull Then V.Hour := 0 Else V.Hour := VL.IntVal;
          If VR.IsNull Then V.Minute := 0 Else V.Minute := VR.IntVal;
          If VT.IsNull Then V.Second := 0 Else V.Second := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[6], Row, Res);
          If VL.IsNull Then V.Frac := 0 Else V.Frac := VL.IntVal;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp + ' ';
          If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Second < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Second, STmp);
          V.StrVal := V.StrVal + STmp + '.';
          Str(V.Frac:3, STmp);
          For I := 1 To Length(STmp) Do
            If STmp[I] = ' ' Then STmp[I] := '0';
          V.StrVal := V.StrVal + STmp;
        End;
      End
      Else If (Op = 'DATETIME2FROMPARTS') And
              (ASTPool[Node].ChildCnt >= 8) Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIME2;
        V.Valid    := True;
        V.IsNull   := False;
        VL := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        VR := QEEvalExpr(ASTPool[Node].Children[1], Row, Res);
        VT := QEEvalExpr(ASTPool[Node].Children[2], Row, Res);
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.Year  := VL.IntVal;
          V.Month := VR.IntVal;
          V.Day   := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[4], Row, Res);
          VT := QEEvalExpr(ASTPool[Node].Children[5], Row, Res);
          If VL.IsNull Then V.Hour := 0 Else V.Hour := VL.IntVal;
          If VR.IsNull Then V.Minute := 0 Else V.Minute := VR.IntVal;
          If VT.IsNull Then V.Second := 0 Else V.Second := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[6], Row, Res);
          If VL.IsNull Then V.Frac := 0 Else V.Frac := VL.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[7], Row, Res);
          If VL.IsNull Then V.Scale := 0 Else V.Scale := VL.IntVal;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp + ' ';
          If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Second < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Second, STmp);
          V.StrVal := V.StrVal + STmp;
        End;
      End
      Else If (Op = 'SMALLDATETIMEFROMPARTS') And
              (ASTPool[Node].ChildCnt >= 5) Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_SMALLDATETIME;
        V.Valid    := True;
        V.IsNull   := False;
        VL := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        VR := QEEvalExpr(ASTPool[Node].Children[1], Row, Res);
        VT := QEEvalExpr(ASTPool[Node].Children[2], Row, Res);
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.Year  := VL.IntVal;
          V.Month := VR.IntVal;
          V.Day   := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[4], Row, Res);
          If VL.IsNull Then V.Hour := 0 Else V.Hour := VL.IntVal;
          If VR.IsNull Then V.Minute := 0 Else V.Minute := VR.IntVal;
          V.Second := 0; V.Frac := 0;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp + ' ';
          If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':00';
        End;
      End
      Else If (Op = 'TIMEFROMPARTS') And
              (ASTPool[Node].ChildCnt >= 5) Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_TIME;
        V.Valid    := True;
        V.IsNull   := False;
        VL := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        VR := QEEvalExpr(ASTPool[Node].Children[1], Row, Res);
        VT := QEEvalExpr(ASTPool[Node].Children[2], Row, Res);
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.Hour := VL.IntVal;
          V.Minute := VR.IntVal;
          V.Second := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[4], Row, Res);
          If VL.IsNull Then V.Frac := 0 Else V.Frac := VL.IntVal;
          If VR.IsNull Then V.Scale := 0 Else V.Scale := VR.IntVal;
          V.Year := 0; V.Month := 0; V.Day := 0;
          If V.Hour < 10 Then V.StrVal := '0' Else V.StrVal := '';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Second < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Second, STmp);
          V.StrVal := V.StrVal + STmp;
        End;
      End
      Else If (Op = 'DATETIMEOFFSETFROMPARTS') And
              (ASTPool[Node].ChildCnt >= 10) Then
      Begin
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIMEOFFSET;
        V.Valid    := True;
        V.IsNull   := False;
        VL := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        VR := QEEvalExpr(ASTPool[Node].Children[1], Row, Res);
        VT := QEEvalExpr(ASTPool[Node].Children[2], Row, Res);
        If VL.IsNull Or VR.IsNull Or VT.IsNull Then V.IsNull := True
        Else Begin
          V.Year  := VL.IntVal;
          V.Month := VR.IntVal;
          V.Day   := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[3], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[4], Row, Res);
          VT := QEEvalExpr(ASTPool[Node].Children[5], Row, Res);
          If VL.IsNull Then V.Hour := 0 Else V.Hour := VL.IntVal;
          If VR.IsNull Then V.Minute := 0 Else V.Minute := VR.IntVal;
          If VT.IsNull Then V.Second := 0 Else V.Second := VT.IntVal;
          VL := QEEvalExpr(ASTPool[Node].Children[6], Row, Res);
          If VL.IsNull Then V.Frac := 0 Else V.Frac := VL.IntVal;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp + ' ';
          If V.Hour < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Hour, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Minute < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Minute, STmp);
          V.StrVal := V.StrVal + STmp + ':';
          If V.Second < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Second, STmp);
          V.StrVal := V.StrVal + STmp;
          { Offset }
          VL := QEEvalExpr(ASTPool[Node].Children[7], Row, Res);
          VR := QEEvalExpr(ASTPool[Node].Children[8], Row, Res);
          If (Not VL.IsNull) And (Not VR.IsNull) Then
          Begin
            If VL.IntVal >= 0 Then V.StrVal := V.StrVal + ' +'
            Else V.StrVal := V.StrVal + ' -';
            I := VL.IntVal;
            If I < 0 Then I := -I;
            If I < 10 Then V.StrVal := V.StrVal + '0';
            Str(I, STmp);
            V.StrVal := V.StrVal + STmp + ':';
            I := VR.IntVal;
            If I < 0 Then I := -I;
            If I < 10 Then V.StrVal := V.StrVal + '0';
            Str(I, STmp);
            V.StrVal := V.StrVal + STmp;
          End;
        End;
      End
      Else If (Op = 'EOMONTH') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATE;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_DATETIME Then
          Begin
            V.Year  := VL.Year;
            V.Month := VL.Month;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            Val(Copy(STmp, 1, 4), I, CI);
            V.Year := I;
            If (Length(STmp) >= 7) And (STmp[5] = '-') Then
            Begin Val(Copy(STmp, 6, 2), I, CI); V.Month := I; End
            Else V.Month := 1;
          End;
          { Optional offset argument }
          If Child1 >= 0 Then
          Begin
            VR := QEEvalExpr(Child1, Row, Res);
            If Not VR.IsNull Then
            Begin
              J := V.Month + VR.IntVal - 1;
              If J >= 0 Then
              Begin
                V.Year := V.Year + (J Div 12);
                V.Month := (J Mod 12) + 1;
              End
              Else Begin
                V.Year := V.Year + ((J + 1) Div 12) - 1;
                V.Month := 12 + ((J + 1) Mod 12);
              End;
            End;
          End;
          { Determine last day of month }
          Case V.Month Of
            1,3,5,7,8,10,12 : V.Day := 31;
            4,6,9,11         : V.Day := 30;
            2 : Begin
                  If ((V.Year Mod 4 = 0) And (V.Year Mod 100 <> 0)) Or
                     (V.Year Mod 400 = 0) Then
                    V.Day := 29
                  Else
                    V.Day := 28;
                End;
          Else V.Day := 30;
          End;
          V.Hour := 0; V.Minute := 0; V.Second := 0; V.Frac := 0;
          Str(V.Year:4, STmp);
          V.StrVal := STmp + '-';
          If V.Month < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Month, STmp);
          V.StrVal := V.StrVal + STmp + '-';
          If V.Day < 10 Then V.StrVal := V.StrVal + '0';
          Str(V.Day, STmp);
          V.StrVal := V.StrVal + STmp;
        End;
      End
      Else If (Op = 'ISDATE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        If VL.IsNull Then V.IntVal := 0
        Else If VL.Category = SQLCAT_DATETIME Then V.IntVal := 1
        Else Begin
          { Try to validate YYYY-MM-DD format }
          Op := SqlValueToStr(VL);
          V.IntVal := 0;
          If (Length(Op) >= 10) And (Op[5] = '-') And (Op[8] = '-') Then
          Begin
            Val(Copy(Op, 1, 4), I, CI);
            If CI = 0 Then
            Begin
              Val(Copy(Op, 6, 2), J, CI);
              If (CI = 0) And (J >= 1) And (J <= 12) Then
              Begin
                Val(Copy(Op, 9, 2), I, CI);
                If (CI = 0) And (I >= 1) And (I <= 31) Then
                  V.IntVal := 1;
              End;
            End;
          End;
          Op := 'ISDATE';
        End;
      End
      Else If ((Op = 'SWITCHOFFSET') Or (Op = 'TODATETIMEOFFSET')) And
              (Child0 >= 0) And (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DATETIME;
        V.XType    := XT_DATETIMEOFFSET;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          V := VL;
          V.XType := XT_DATETIMEOFFSET;
          V.Category := SQLCAT_DATETIME;
          { Append offset from second argument }
          VR := QEEvalExpr(Child1, Row, Res);
          If Not VR.IsNull Then
          Begin
            STmp := SqlValueToStr(VR);
            If Length(V.StrVal) + Length(STmp) + 1 <=
               MAX_SQL_VALUE_STR Then
              V.StrVal := SqlValueToStr(VL) + ' ' + STmp;
          End;
        End;
      End
      { ===== TODO 21 : Fonctions scalaires mathematiques ===== }
      Else If (Op = 'SIGN') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
          Begin
            If VL.IntVal > 0 Then V.IntVal := 1
            Else If VL.IntVal < 0 Then V.IntVal := -1
            Else V.IntVal := 0;
          End
          Else If VL.Category = SQLCAT_DECIMAL Then
          Begin
            If VL.FloatVal > 0 Then V.IntVal := 1
            Else If VL.FloatVal < 0 Then V.IntVal := -1
            Else V.IntVal := 0;
          End
          Else V.IntVal := 0;
        End;
      End
      Else If (Op = 'CEILING') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Valid := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V := VL
          Else If VL.Category = SQLCAT_DECIMAL Then
          Begin
            V.Category := SQLCAT_INTEGER;
            V.XType    := XT_INT;
            If VL.FloatVal >= 0 Then
            Begin
              V.IntVal := Trunc(VL.FloatVal);
              If Frac(VL.FloatVal) > 0 Then
                Inc(V.IntVal);
            End
            Else
              V.IntVal := Trunc(VL.FloatVal);
          End
          Else Begin
            V.Category := SQLCAT_INTEGER;
            V.XType    := XT_INT;
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI = 0 Then
            Begin
              V.IntVal := Trunc(V.FloatVal);
              If (V.FloatVal >= 0) And (Frac(V.FloatVal) > 0) Then
                Inc(V.IntVal);
            End
            Else V.IntVal := 0;
          End;
        End;
      End
      Else If (Op = 'FLOOR') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Valid := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V := VL
          Else If VL.Category = SQLCAT_DECIMAL Then
          Begin
            V.Category := SQLCAT_INTEGER;
            V.XType    := XT_INT;
            If VL.FloatVal >= 0 Then
              V.IntVal := Trunc(VL.FloatVal)
            Else Begin
              V.IntVal := Trunc(VL.FloatVal);
              If Frac(VL.FloatVal) <> 0 Then
                Dec(V.IntVal);
            End;
          End
          Else Begin
            V.Category := SQLCAT_INTEGER;
            V.XType    := XT_INT;
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI = 0 Then
            Begin
              If V.FloatVal >= 0 Then
                V.IntVal := Trunc(V.FloatVal)
              Else Begin
                V.IntVal := Trunc(V.FloatVal);
                If Frac(V.FloatVal) <> 0 Then
                  Dec(V.IntVal);
              End;
            End
            Else V.IntVal := 0;
          End;
        End;
      End
      Else If (Op = 'ROUND') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          { Extract value as float }
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          { Get decimal places }
          I := VR.IntVal;
          { Compute ROUND: multiply, round, divide }
          If I >= 0 Then
          Begin
            VR.FloatVal := 1.0;
            For J := 1 To I Do
              VR.FloatVal := VR.FloatVal * 10.0;
            V.FloatVal := Round(V.FloatVal * VR.FloatVal) /
                          VR.FloatVal;
          End
          Else Begin
            { Negative d: round to left of decimal }
            VR.FloatVal := 1.0;
            For J := 1 To -I Do
              VR.FloatVal := VR.FloatVal * 10.0;
            V.FloatVal := Round(V.FloatVal / VR.FloatVal) *
                          VR.FloatVal;
          End;
        End;
      End
      Else If (Op = 'POWER') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          If VR.Category = SQLCAT_INTEGER Then
            VR.FloatVal := VR.IntVal * 1.0
          Else If VR.Category <> SQLCAT_DECIMAL Then
          Begin
            Val(SqlValueToStr(VR), VR.FloatVal, CI);
            If CI <> 0 Then VR.FloatVal := 0;
          End;
          If V.FloatVal = 0 Then
          Begin
            If VR.FloatVal = 0 Then V.FloatVal := 1
            Else V.FloatVal := 0;
          End
          Else If V.FloatVal > 0 Then
            V.FloatVal := Exp(VR.FloatVal * Ln(V.FloatVal))
          Else Begin
            { Negative base: only valid for integer exponents }
            I := Trunc(VR.FloatVal);
            If Frac(VR.FloatVal) = 0 Then
            Begin
              V.FloatVal := Exp(VR.FloatVal * Ln(-V.FloatVal));
              If Odd(I) Then V.FloatVal := -V.FloatVal;
            End
            Else
              V.FloatVal := 0;
          End;
        End;
      End
      Else If (Op = 'SQRT') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          If V.FloatVal >= 0 Then
            V.FloatVal := Sqrt(V.FloatVal)
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'SQUARE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := V.FloatVal * V.FloatVal;
        End;
      End
      Else If (Op = 'EXP') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := Exp(V.FloatVal);
        End;
      End
      Else If (Op = 'LOG') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          If V.FloatVal > 0 Then
          Begin
            V.FloatVal := Ln(V.FloatVal);
            { Optional base argument: LOG(x, base) }
            If Child1 >= 0 Then
            Begin
              VR := QEEvalExpr(Child1, Row, Res);
              If Not VR.IsNull Then
              Begin
                If VR.Category = SQLCAT_INTEGER Then
                  VR.FloatVal := VR.IntVal * 1.0
                Else If VR.Category <> SQLCAT_DECIMAL Then
                Begin
                  Val(SqlValueToStr(VR), VR.FloatVal, CI);
                  If CI <> 0 Then VR.FloatVal := 0;
                End;
                If (VR.FloatVal > 0) And (VR.FloatVal <> 1.0) Then
                  V.FloatVal := V.FloatVal / Ln(VR.FloatVal)
                Else
                  V.FloatVal := 0;
              End;
            End;
          End
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'LOG10') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          If V.FloatVal > 0 Then
            V.FloatVal := Ln(V.FloatVal) / Ln(10.0)
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'SIN') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := Sin(V.FloatVal);
        End;
      End
      Else If (Op = 'COS') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := Cos(V.FloatVal);
        End;
      End
      Else If (Op = 'TAN') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          VR.FloatVal := Cos(V.FloatVal);
          If VR.FloatVal <> 0 Then
            V.FloatVal := Sin(V.FloatVal) / VR.FloatVal
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'COT') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          VR.FloatVal := Sin(V.FloatVal);
          If VR.FloatVal <> 0 Then
            V.FloatVal := Cos(V.FloatVal) / VR.FloatVal
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'ASIN') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          { ASIN(x) = ATAN(x / SQRT(1 - x*x)) }
          If (V.FloatVal >= -1.0) And (V.FloatVal <= 1.0) Then
          Begin
            If V.FloatVal = 1.0 Then
              V.FloatVal := Pi / 2.0
            Else If V.FloatVal = -1.0 Then
              V.FloatVal := -Pi / 2.0
            Else
              V.FloatVal := ArcTan(V.FloatVal /
                            Sqrt(1.0 - V.FloatVal * V.FloatVal));
          End
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'ACOS') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          { ACOS(x) = PI/2 - ASIN(x) }
          If (V.FloatVal >= -1.0) And (V.FloatVal <= 1.0) Then
          Begin
            If V.FloatVal = 1.0 Then
              V.FloatVal := 0
            Else If V.FloatVal = -1.0 Then
              V.FloatVal := Pi
            Else
              V.FloatVal := Pi / 2.0 - ArcTan(V.FloatVal /
                            Sqrt(1.0 - V.FloatVal * V.FloatVal));
          End
          Else
            V.FloatVal := 0;
        End;
      End
      Else If (Op = 'ATAN') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := ArcTan(V.FloatVal);
        End;
      End
      Else If (Op = 'ATN2') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Or VR.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          { Extract Y }
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          { Extract X }
          If VR.Category = SQLCAT_INTEGER Then
            VR.FloatVal := VR.IntVal * 1.0
          Else If VR.Category <> SQLCAT_DECIMAL Then
          Begin
            Val(SqlValueToStr(VR), VR.FloatVal, CI);
            If CI <> 0 Then VR.FloatVal := 0;
          End;
          { ATN2(y, x) }
          If VR.FloatVal > 0 Then
            V.FloatVal := ArcTan(V.FloatVal / VR.FloatVal)
          Else If (VR.FloatVal < 0) And (V.FloatVal >= 0) Then
            V.FloatVal := ArcTan(V.FloatVal / VR.FloatVal) + Pi
          Else If (VR.FloatVal < 0) And (V.FloatVal < 0) Then
            V.FloatVal := ArcTan(V.FloatVal / VR.FloatVal) - Pi
          Else If (VR.FloatVal = 0) And (V.FloatVal > 0) Then
            V.FloatVal := Pi / 2.0
          Else If (VR.FloatVal = 0) And (V.FloatVal < 0) Then
            V.FloatVal := -Pi / 2.0
          Else
            V.FloatVal := 0;
        End;
      End
      Else If Op = 'PI' Then
      Begin
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        V.IsNull   := False;
        V.FloatVal := Pi;
      End
      Else If (Op = 'DEGREES') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := V.FloatVal * 180.0 / Pi;
        End;
      End
      Else If (Op = 'RADIANS') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            Val(SqlValueToStr(VL), V.FloatVal, CI);
            If CI <> 0 Then V.FloatVal := 0;
          End;
          V.FloatVal := V.FloatVal * Pi / 180.0;
        End;
      End
      Else If Op = 'RAND' Then
      Begin
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_FLOAT;
        V.Valid    := True;
        V.IsNull   := False;
        If Child0 >= 0 Then
        Begin
          VL := QEEvalExpr(Child0, Row, Res);
          If Not VL.IsNull Then
            RandSeed := VL.IntVal;
        End;
        V.FloatVal := Random;
      End
      Else If (Op = 'CHOOSE') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Valid  := True;
        V.IsNull := True;
        If Not VL.IsNull Then
        Begin
          I := VL.IntVal;
          { CHOOSE is 1-based: index 1 = Children[1] }
          If (I >= 1) And (I < ASTPool[Node].ChildCnt) Then
            V := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
        End;
      End
      Else If (Op = 'IIF') And (Child0 >= 0) And
              (Child1 >= 0) And (Child2 >= 0) Then
      Begin
        V.Valid := True;
        If QEEvalBool(Child0, Row, Res) Then
          V := QEEvalExpr(Child1, Row, Res)
        Else
          V := QEEvalExpr(Child2, Row, Res);
      End
      Else If (Op = 'GREATEST') And
              (ASTPool[Node].ChildCnt >= 2) Then
      Begin
        V := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        V.Valid := True;
        For I := 1 To ASTPool[Node].ChildCnt - 1 Do
        Begin
          VL := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
          If VL.IsNull Then Continue;
          If V.IsNull Then
          Begin
            V := VL;
            Continue;
          End;
          { Compare values }
          If (V.Category = SQLCAT_INTEGER) And
             (VL.Category = SQLCAT_INTEGER) Then
          Begin
            If VL.IntVal > V.IntVal Then V := VL;
          End
          Else If (V.Category = SQLCAT_DECIMAL) Or
                  (VL.Category = SQLCAT_DECIMAL) Then
          Begin
            If V.Category = SQLCAT_INTEGER Then
              V.FloatVal := V.IntVal * 1.0;
            If VL.Category = SQLCAT_INTEGER Then
              VL.FloatVal := VL.IntVal * 1.0;
            If VL.FloatVal > V.FloatVal Then V := VL;
          End
          Else Begin
            If SqlValueToStr(VL) > SqlValueToStr(V) Then V := VL;
          End;
        End;
      End
      Else If (Op = 'LEAST') And
              (ASTPool[Node].ChildCnt >= 2) Then
      Begin
        V := QEEvalExpr(ASTPool[Node].Children[0], Row, Res);
        V.Valid := True;
        For I := 1 To ASTPool[Node].ChildCnt - 1 Do
        Begin
          VL := QEEvalExpr(ASTPool[Node].Children[I], Row, Res);
          If VL.IsNull Then Continue;
          If V.IsNull Then
          Begin
            V := VL;
            Continue;
          End;
          { Compare values }
          If (V.Category = SQLCAT_INTEGER) And
             (VL.Category = SQLCAT_INTEGER) Then
          Begin
            If VL.IntVal < V.IntVal Then V := VL;
          End
          Else If (V.Category = SQLCAT_DECIMAL) Or
                  (VL.Category = SQLCAT_DECIMAL) Then
          Begin
            If V.Category = SQLCAT_INTEGER Then
              V.FloatVal := V.IntVal * 1.0;
            If VL.Category = SQLCAT_INTEGER Then
              VL.FloatVal := VL.IntVal * 1.0;
            If VL.FloatVal < V.FloatVal Then V := VL;
          End
          Else Begin
            If SqlValueToStr(VL) < SqlValueToStr(V) Then V := VL;
          End;
        End;
      End
      { ===== TODO 22 : Fonctions de conversion et systeme ===== }
      Else If (Op = 'NULLIF') And (Child0 >= 0) And
              (Child1 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        VR := QEEvalExpr(Child1, Row, Res);
        V.Valid := True;
        If VL.IsNull And VR.IsNull Then
          V.IsNull := True
        Else If VL.IsNull Or VR.IsNull Then
          V := VL
        Else If SqlValueToStr(VL) = SqlValueToStr(VR) Then
          V.IsNull := True
        Else
          V := VL;
      End
      Else If (Op = 'ISNUMERIC') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        If VL.IsNull Then V.IntVal := 0
        Else If VL.Category = SQLCAT_INTEGER Then V.IntVal := 1
        Else If VL.Category = SQLCAT_DECIMAL Then V.IntVal := 1
        Else Begin
          Val(SqlValueToStr(VL), V.FloatVal, CI);
          If CI = 0 Then V.IntVal := 1
          Else V.IntVal := 0;
        End;
      End
      Else If Op = 'SCOPE_IDENTITY' Then
      Begin
        V.IsNull := True;
        V.Valid  := True;
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_DECIMAL;
      End
      Else If (Op = 'IDENT_CURRENT') And (Child0 >= 0) Then
      Begin
        V.IsNull := True;
        V.Valid  := True;
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_DECIMAL;
      End
      Else If Op = 'NEWID' Then
      Begin
        V.IsNull   := False;
        V.Valid    := True;
        V.Category := SQLCAT_SPECIAL;
        V.XType    := XT_UNIQUEID;
        V.StrVal   := '00000000-0000-0000-0000-000000000000';
      End
      Else If Op = 'NEWSEQUENTIALID' Then
      Begin
        V.IsNull   := False;
        V.Valid    := True;
        V.Category := SQLCAT_SPECIAL;
        V.XType    := XT_UNIQUEID;
        V.StrVal   := '00000000-0000-0000-0000-000000000001';
      End
      Else If (Op = 'OBJECT_ID') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          V.IntVal := 0;
        End;
      End
      Else If (Op = 'OBJECT_NAME') And (Child0 >= 0) Then
      Begin
        VL := QEEvalExpr(Child0, Row, Res);
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        If VL.IsNull Then V.IsNull := True
        Else Begin
          V.IsNull := False;
          V.StrVal := '';
        End;
      End
      Else If (Op = 'DB_ID') Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        V.IntVal   := 1;
      End
      Else If (Op = 'DB_NAME') Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'master';
      End
      Else If (Op = 'SCHEMA_ID') Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        V.IntVal   := 1;
      End
      Else If (Op = 'SCHEMA_NAME') Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'dbo';
      End
      Else If (Op = 'USER_ID') Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;
        V.IntVal   := 1;
      End
      Else If (Op = 'USER_NAME') Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'dbo';
      End
      Else If Op = 'HOST_NAME' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'localhost';
      End
      Else If Op = 'APP_NAME' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'SQLCMD';
      End
      Else If Op = 'SUSER_SNAME' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'sa';
      End
      Else If Op = 'ORIGINAL_LOGIN' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'sa';
      End
      Else If Op = 'CURRENT_USER' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'dbo';
      End
      Else If Op = 'SESSION_USER' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'dbo';
      End
      Else If Op = 'SYSTEM_USER' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := False;
        V.StrVal   := 'sa';
      End
      Else If Op = 'ERROR_NUMBER' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'ERROR_MESSAGE' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'ERROR_SEVERITY' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'ERROR_STATE' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'ERROR_LINE' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'ERROR_PROCEDURE' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.Valid    := True;
        V.IsNull   := True;
      End
      Else If Op = 'XACT_STATE' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_SMALLINT;
        V.Valid    := True;
        V.IsNull   := False;
        V.IntVal   := 0;
      End
      Else
      Begin
        { Fonction inconnue, retourner NULL }
        V.IsNull := True;
        V.Valid  := True;
      End;
    End;
    ND_CASE_WHEN :
    Begin
      V.IsNull := True;
      V.Valid  := True;
      I := 0;
      While I < ASTPool[Node].ChildCnt Do
      Begin
        CI := ASTPool[Node].Children[I];
        If (CI >= 0) And (CI < ASTCount) And
           (ASTPool[CI].Kind = ND_WHEN_ITEM) Then
        Begin
          If (ASTPool[CI].ChildCnt >= 2) Then
          Begin
            If QEEvalBool(ASTPool[CI].Children[0], Row, Res) Then
            Begin
              V := QEEvalExpr(ASTPool[CI].Children[1], Row, Res);
              Break;
            End;
          End;
        End
        Else
        Begin
          { ELSE branch }
          V := QEEvalExpr(CI, Row, Res);
          Break;
        End;
        Inc(I);
      End;
    End;
    { ===== TODO 22 : Evaluation CAST/TRY_CAST/PARSE/TRY_PARSE ===== }
    ND_CAST :
    Begin
      V.Valid := True;
      If Child0 >= 0 Then
        VL := QEEvalExpr(Child0, Row, Res)
      Else Begin
        InitSqlValue(VL);
        VL.IsNull := True;
        VL.Valid  := True;
      End;
      If VL.IsNull Then
        V.IsNull := True
      Else Begin
        V.IsNull := False;
        Op := '';
        If (Child1 >= 0) And (Child1 < ASTCount) Then
          Op := StrUpperCase(ASTPool[Child1].Text);
        If (Op = 'INT') Or (Op = 'INTEGER') Or
           (Op = 'BIGINT') Or (Op = 'SMALLINT') Or
           (Op = 'TINYINT') Then
        Begin
          V.Category := SQLCAT_INTEGER;
          V.XType    := XT_INT;
          If VL.Category = SQLCAT_INTEGER Then
            V.IntVal := VL.IntVal
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.IntVal := Trunc(VL.FloatVal)
          Else Begin
            STmp := SqlValueToStr(VL);
            Val(STmp, V.FloatVal, CI);
            If CI = 0 Then
              V.IntVal := Trunc(V.FloatVal)
            Else If (StrUpperCase(ASTPool[Node].Text) = 'TRY_CAST') Or
                    (StrUpperCase(ASTPool[Node].Text) = 'TRY_PARSE') Then
              V.IsNull := True
            Else
              V.IntVal := 0;
          End;
        End
        Else If (Op = 'BIT') Then
        Begin
          V.Category := SQLCAT_INTEGER;
          V.XType    := XT_BIT;
          If VL.Category = SQLCAT_INTEGER Then
          Begin
            If VL.IntVal <> 0 Then V.IntVal := 1
            Else V.IntVal := 0;
          End
          Else If VL.Category = SQLCAT_DECIMAL Then
          Begin
            If VL.FloatVal <> 0.0 Then V.IntVal := 1
            Else V.IntVal := 0;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            If (STmp = '0') Or (STmp = '') Or
               (STmp = 'false') Or (STmp = 'FALSE') Then
              V.IntVal := 0
            Else
              V.IntVal := 1;
          End;
        End
        Else If (Op = 'FLOAT') Or (Op = 'REAL') Or
                (Op = 'DECIMAL') Or (Op = 'NUMERIC') Or
                (Op = 'MONEY') Or (Op = 'SMALLMONEY') Then
        Begin
          V.Category := SQLCAT_DECIMAL;
          If (Op = 'MONEY') Or (Op = 'SMALLMONEY') Then
            V.XType := XT_MONEY
          Else If Op = 'REAL' Then
            V.XType := XT_REAL
          Else If (Op = 'DECIMAL') Or (Op = 'NUMERIC') Then
            V.XType := XT_DECIMAL
          Else
            V.XType := XT_FLOAT;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            STmp := SqlValueToStr(VL);
            Val(STmp, V.FloatVal, CI);
            If CI <> 0 Then
            Begin
              If (StrUpperCase(ASTPool[Node].Text) = 'TRY_CAST') Or
                 (StrUpperCase(ASTPool[Node].Text) = 'TRY_PARSE') Then
                V.IsNull := True
              Else
                V.FloatVal := 0.0;
            End;
          End;
        End
        Else If (Op = 'VARCHAR') Or (Op = 'CHAR') Or
                (Op = 'NVARCHAR') Or (Op = 'NCHAR') Or
                (Op = 'TEXT') Or (Op = 'NTEXT') Then
        Begin
          V.Category := SQLCAT_STRING;
          If (Op = 'NVARCHAR') Or (Op = 'NCHAR') Or
             (Op = 'NTEXT') Then
            V.XType := XT_NVARCHAR
          Else
            V.XType := XT_VARCHAR;
          V.StrVal := SqlValueToStr(VL);
        End
        Else If (Op = 'DATE') Then
        Begin
          V.Category := SQLCAT_DATETIME;
          V.XType    := XT_DATE;
          If VL.Category = SQLCAT_DATETIME Then
          Begin
            V.Year  := VL.Year;
            V.Month := VL.Month;
            V.Day   := VL.Day;
            V.Hour  := 0;
            V.Minute := 0;
            V.Second := 0;
            V.Frac  := 0;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            V.Year := 0; V.Month := 0; V.Day := 0;
            If (Length(STmp) >= 10) And
               (STmp[5] = '-') And (STmp[8] = '-') Then
            Begin
              Val(Copy(STmp, 1, 4), I, CI);
              If CI = 0 Then V.Year := I;
              Val(Copy(STmp, 6, 2), I, CI);
              If CI = 0 Then V.Month := I;
              Val(Copy(STmp, 9, 2), I, CI);
              If CI = 0 Then V.Day := I;
            End
            Else If (StrUpperCase(ASTPool[Node].Text) = 'TRY_CAST') Or
                    (StrUpperCase(ASTPool[Node].Text) = 'TRY_PARSE') Then
              V.IsNull := True;
          End;
        End
        Else If (Op = 'DATETIME') Or (Op = 'DATETIME2') Or
                (Op = 'SMALLDATETIME') Then
        Begin
          V.Category := SQLCAT_DATETIME;
          If Op = 'DATETIME2' Then
            V.XType := XT_DATETIME2
          Else If Op = 'SMALLDATETIME' Then
            V.XType := XT_SMALLDATETIME
          Else
            V.XType := XT_DATETIME;
          If VL.Category = SQLCAT_DATETIME Then
            V := VL
          Else Begin
            STmp := SqlValueToStr(VL);
            V.Year := 0; V.Month := 0; V.Day := 0;
            V.Hour := 0; V.Minute := 0; V.Second := 0;
            V.Frac := 0;
            If (Length(STmp) >= 10) And
               (STmp[5] = '-') And (STmp[8] = '-') Then
            Begin
              Val(Copy(STmp, 1, 4), I, CI);
              If CI = 0 Then V.Year := I;
              Val(Copy(STmp, 6, 2), I, CI);
              If CI = 0 Then V.Month := I;
              Val(Copy(STmp, 9, 2), I, CI);
              If CI = 0 Then V.Day := I;
              If (Length(STmp) >= 19) And
                 (STmp[11] = ' ') And (STmp[14] = ':') And
                 (STmp[17] = ':') Then
              Begin
                Val(Copy(STmp, 12, 2), I, CI);
                If CI = 0 Then V.Hour := I;
                Val(Copy(STmp, 15, 2), I, CI);
                If CI = 0 Then V.Minute := I;
                Val(Copy(STmp, 18, 2), I, CI);
                If CI = 0 Then V.Second := I;
              End;
            End
            Else If (StrUpperCase(ASTPool[Node].Text) = 'TRY_CAST') Or
                    (StrUpperCase(ASTPool[Node].Text) = 'TRY_PARSE') Then
              V.IsNull := True;
          End;
          V.Category := SQLCAT_DATETIME;
        End
        Else If Op = 'TIME' Then
        Begin
          V.Category := SQLCAT_DATETIME;
          V.XType    := XT_TIME;
          If VL.Category = SQLCAT_DATETIME Then
          Begin
            V.Year := 0; V.Month := 0; V.Day := 0;
            V.Hour := VL.Hour; V.Minute := VL.Minute;
            V.Second := VL.Second; V.Frac := VL.Frac;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            V.Hour := 0; V.Minute := 0; V.Second := 0;
            V.Frac := 0;
            If (Length(STmp) >= 8) And
               (STmp[3] = ':') And (STmp[6] = ':') Then
            Begin
              Val(Copy(STmp, 1, 2), I, CI);
              If CI = 0 Then V.Hour := I;
              Val(Copy(STmp, 4, 2), I, CI);
              If CI = 0 Then V.Minute := I;
              Val(Copy(STmp, 7, 2), I, CI);
              If CI = 0 Then V.Second := I;
            End
            Else If (StrUpperCase(ASTPool[Node].Text) = 'TRY_CAST') Or
                    (StrUpperCase(ASTPool[Node].Text) = 'TRY_PARSE') Then
              V.IsNull := True;
          End;
        End
        Else If Op = 'UNIQUEIDENTIFIER' Then
        Begin
          V.Category := SQLCAT_SPECIAL;
          V.XType    := XT_UNIQUEID;
          V.StrVal   := SqlValueToStr(VL);
        End
        Else If (Op = 'BINARY') Or (Op = 'VARBINARY') Then
        Begin
          V.Category := SQLCAT_BINARY;
          V.XType    := XT_VARBINARY;
          V.StrVal   := SqlValueToStr(VL);
        End
        Else If Op = 'XML' Then
        Begin
          V.Category := SQLCAT_SPECIAL;
          V.XType    := XT_XML;
          V.StrVal   := SqlValueToStr(VL);
        End
        Else Begin
          { Type inconnu : conversion en chaine }
          V.Category := SQLCAT_STRING;
          V.XType    := XT_VARCHAR;
          V.StrVal   := SqlValueToStr(VL);
        End;
      End;
    End;
    { ===== TODO 22 : Evaluation CONVERT/TRY_CONVERT ===== }
    ND_CONVERT :
    Begin
      V.Valid := True;
      { Child0 = type reference, Child1 = expression, Child2 = style }
      Op := '';
      If (Child0 >= 0) And (Child0 < ASTCount) Then
        Op := StrUpperCase(ASTPool[Child0].Text);
      If Child1 >= 0 Then
        VL := QEEvalExpr(Child1, Row, Res)
      Else Begin
        InitSqlValue(VL);
        VL.IsNull := True;
        VL.Valid  := True;
      End;
      If VL.IsNull Then
        V.IsNull := True
      Else Begin
        V.IsNull := False;
        If (Op = 'INT') Or (Op = 'INTEGER') Or
           (Op = 'BIGINT') Or (Op = 'SMALLINT') Or
           (Op = 'TINYINT') Then
        Begin
          V.Category := SQLCAT_INTEGER;
          V.XType    := XT_INT;
          If VL.Category = SQLCAT_INTEGER Then
            V.IntVal := VL.IntVal
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.IntVal := Trunc(VL.FloatVal)
          Else Begin
            STmp := SqlValueToStr(VL);
            Val(STmp, V.FloatVal, CI);
            If CI = 0 Then
              V.IntVal := Trunc(V.FloatVal)
            Else If StrUpperCase(ASTPool[Node].Text) = 'TRY_CONVERT' Then
              V.IsNull := True
            Else
              V.IntVal := 0;
          End;
        End
        Else If Op = 'BIT' Then
        Begin
          V.Category := SQLCAT_INTEGER;
          V.XType    := XT_BIT;
          If VL.Category = SQLCAT_INTEGER Then
          Begin
            If VL.IntVal <> 0 Then V.IntVal := 1
            Else V.IntVal := 0;
          End
          Else If VL.Category = SQLCAT_DECIMAL Then
          Begin
            If VL.FloatVal <> 0.0 Then V.IntVal := 1
            Else V.IntVal := 0;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            If (STmp = '0') Or (STmp = '') Then V.IntVal := 0
            Else V.IntVal := 1;
          End;
        End
        Else If (Op = 'FLOAT') Or (Op = 'REAL') Or
                (Op = 'DECIMAL') Or (Op = 'NUMERIC') Or
                (Op = 'MONEY') Or (Op = 'SMALLMONEY') Then
        Begin
          V.Category := SQLCAT_DECIMAL;
          V.XType    := XT_FLOAT;
          If VL.Category = SQLCAT_INTEGER Then
            V.FloatVal := VL.IntVal * 1.0
          Else If VL.Category = SQLCAT_DECIMAL Then
            V.FloatVal := VL.FloatVal
          Else Begin
            STmp := SqlValueToStr(VL);
            Val(STmp, V.FloatVal, CI);
            If CI <> 0 Then
            Begin
              If StrUpperCase(ASTPool[Node].Text) = 'TRY_CONVERT' Then
                V.IsNull := True
              Else
                V.FloatVal := 0.0;
            End;
          End;
        End
        Else If (Op = 'VARCHAR') Or (Op = 'CHAR') Or
                (Op = 'NVARCHAR') Or (Op = 'NCHAR') Or
                (Op = 'TEXT') Or (Op = 'NTEXT') Then
        Begin
          V.Category := SQLCAT_STRING;
          V.XType    := XT_VARCHAR;
          V.StrVal   := SqlValueToStr(VL);
        End
        Else If Op = 'DATE' Then
        Begin
          V.Category := SQLCAT_DATETIME;
          V.XType    := XT_DATE;
          If VL.Category = SQLCAT_DATETIME Then
          Begin
            V.Year  := VL.Year;
            V.Month := VL.Month;
            V.Day   := VL.Day;
          End
          Else Begin
            STmp := SqlValueToStr(VL);
            V.Year := 0; V.Month := 0; V.Day := 0;
            If (Length(STmp) >= 10) And
               (STmp[5] = '-') And (STmp[8] = '-') Then
            Begin
              Val(Copy(STmp, 1, 4), I, CI);
              If CI = 0 Then V.Year := I;
              Val(Copy(STmp, 6, 2), I, CI);
              If CI = 0 Then V.Month := I;
              Val(Copy(STmp, 9, 2), I, CI);
              If CI = 0 Then V.Day := I;
            End
            Else If StrUpperCase(ASTPool[Node].Text) = 'TRY_CONVERT' Then
              V.IsNull := True;
          End;
        End
        Else If (Op = 'DATETIME') Or (Op = 'DATETIME2') Or
                (Op = 'SMALLDATETIME') Then
        Begin
          V.Category := SQLCAT_DATETIME;
          V.XType    := XT_DATETIME;
          If VL.Category = SQLCAT_DATETIME Then
            V := VL
          Else Begin
            STmp := SqlValueToStr(VL);
            V.Year := 0; V.Month := 0; V.Day := 0;
            V.Hour := 0; V.Minute := 0; V.Second := 0;
            If (Length(STmp) >= 10) And
               (STmp[5] = '-') And (STmp[8] = '-') Then
            Begin
              Val(Copy(STmp, 1, 4), I, CI);
              If CI = 0 Then V.Year := I;
              Val(Copy(STmp, 6, 2), I, CI);
              If CI = 0 Then V.Month := I;
              Val(Copy(STmp, 9, 2), I, CI);
              If CI = 0 Then V.Day := I;
              If (Length(STmp) >= 19) And
                 (STmp[11] = ' ') And (STmp[14] = ':') And
                 (STmp[17] = ':') Then
              Begin
                Val(Copy(STmp, 12, 2), I, CI);
                If CI = 0 Then V.Hour := I;
                Val(Copy(STmp, 15, 2), I, CI);
                If CI = 0 Then V.Minute := I;
                Val(Copy(STmp, 18, 2), I, CI);
                If CI = 0 Then V.Second := I;
              End;
            End
            Else If StrUpperCase(ASTPool[Node].Text) = 'TRY_CONVERT' Then
              V.IsNull := True;
          End;
          V.Category := SQLCAT_DATETIME;
        End
        Else Begin
          { Type inconnu : conversion en chaine }
          V.Category := SQLCAT_STRING;
          V.XType    := XT_VARCHAR;
          V.StrVal   := SqlValueToStr(VL);
        End;
      End;
    End;
    { ===== TODO 22 : Evaluation des variables @@ ===== }
    ND_VARIABLE :
    Begin
      Op := StrUpperCase(ASTPool[Node].Text);
      V.Valid := True;
      If Op = '@@ROWCOUNT' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.IsNull   := False;
        V.IntVal   := 0;
      End
      Else If Op = '@@ERROR' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.IsNull   := False;
        V.IntVal   := 0;
      End
      Else If Op = '@@IDENTITY' Then
      Begin
        V.Category := SQLCAT_DECIMAL;
        V.XType    := XT_DECIMAL;
        V.IsNull   := True;
      End
      Else If Op = '@@TRANCOUNT' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.IsNull   := False;
        V.IntVal   := 0;
      End
      Else If Op = '@@VERSION' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.IsNull   := False;
        V.StrVal   := 'SQLCMD Emulator 1.0';
      End
      Else If Op = '@@SERVERNAME' Then
      Begin
        V.Category := SQLCAT_STRING;
        V.XType    := XT_NVARCHAR;
        V.IsNull   := False;
        V.StrVal   := 'localhost';
      End
      Else If Op = '@@SPID' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_SMALLINT;
        V.IsNull   := False;
        V.IntVal   := 1;
      End
      Else If Op = '@@FETCH_STATUS' Then
      Begin
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.IsNull   := False;
        V.IntVal   := -1;
      End
      Else Begin
        { Variable utilisateur ou inconnue }
        V.IsNull := True;
      End;
    End;
  Else
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End;
  End;

  QEEvalExpr := V;
End;

{ ---- Scanner une table et collecter les lignes --------------- }
{ Parcourt toutes les pages de donnees du MDF dont l ObjId        }
{ correspond a la table demandee. Retourne le nombre de lignes.   }

Function QETableScan(ObjId : LongInt;
                      Var Res : TQEResult) : Integer;
Var
  TmpBuf    : TMdfPageBuf;
  Hdr       : TMdfPageHeader;
  RH        : TMdfRowHeader;
  I, J      : LongInt;
  RowOfs    : Word;
  SC        : Word;
  Slots     : TMdfSlotArray;
  PageCount : LongInt;
Begin
  Res.RowCnt := 0;
  PageCount := 0;

  For I := 0 To MdfPageCnt - 1 Do
  Begin
    If Res.RowCnt >= MAX_QE_ROWS Then Break;
    If PageCount >= MAX_QE_PAGES Then Break;

    If Not SeekPage(I, TmpBuf) Then Continue;
    ParsePageHeader(TmpBuf, Hdr);

    { Filtrer : pages de donnees (type 1) avec le bon ObjId }
    If Hdr.PageType <> MDF_PT_DATA Then Continue;
    If Hdr.ObjId <> ObjId Then Continue;

    Inc(PageCount);
    SC := Hdr.SlotCnt;
    If SC > MDF_MAX_SLOTS Then SC := MDF_MAX_SLOTS;
    ReadSlotArray(TmpBuf, SC, Slots);

    For J := 0 To SC - 1 Do
    Begin
      If Res.RowCnt >= MAX_QE_ROWS Then Break;
      RowOfs := Slots[J];
      If (RowOfs < MDF_PAGE_HDR_SIZE) Or
         (RowOfs >= MDF_PAGE_SIZE) Then Continue;

      ParseRowHeader(TmpBuf, RowOfs, RH);
      If Not RH.Valid Then Continue;
      { Ignorer les ghost records (bit 0 de StatusA) }
      If (RH.StatusA And $01) <> 0 Then Continue;

      QEDecodeRow(TmpBuf, RowOfs, Res, Res.Rows[Res.RowCnt]);
      Inc(Res.RowCnt);
    End;
  End;

  QETableScan := Res.RowCnt;
End;

{ ---- Tri QuickSort des lignes -------------------------------- }
{ Trie le result set en memoire par les colonnes d ORDER BY.      }

Var
  QESortCol   : Integer;         { index colonne de tri                 }
  QESortDesc  : Boolean;         { True si DESC                         }

Procedure QEQuickSort(Var Res : TQEResult; Lo, Hi : Integer);
Var
  I, J    : Integer;
  Pivot   : TQERow;
  TmpRow  : TQERow;
Begin
  If Lo >= Hi Then Exit;
  I := Lo;
  J := Hi;
  Pivot := Res.Rows[(Lo + Hi) Div 2];
  Repeat
    If QESortDesc Then
    Begin
      While QECompareValues(Res.Rows[I].Vals[QESortCol],
                             Pivot.Vals[QESortCol]) > 0 Do Inc(I);
      While QECompareValues(Res.Rows[J].Vals[QESortCol],
                             Pivot.Vals[QESortCol]) < 0 Do Dec(J);
    End
    Else
    Begin
      While QECompareValues(Res.Rows[I].Vals[QESortCol],
                             Pivot.Vals[QESortCol]) < 0 Do Inc(I);
      While QECompareValues(Res.Rows[J].Vals[QESortCol],
                             Pivot.Vals[QESortCol]) > 0 Do Dec(J);
    End;
    If I <= J Then
    Begin
      TmpRow := Res.Rows[I];
      Res.Rows[I] := Res.Rows[J];
      Res.Rows[J] := TmpRow;
      Inc(I);
      Dec(J);
    End;
  Until I > J;
  If Lo < J Then QEQuickSort(Res, Lo, J);
  If I < Hi Then QEQuickSort(Res, I, Hi);
End;

{ ---- Eliminer les doublons (DISTINCT) ------------------------ }
{ Supprime les lignes identiques dans un result set trie.         }

Procedure QEDistinct(Var Res : TQEResult);
Var
  I, J, K  : Integer;
  IsDup    : Boolean;
Begin
  If Res.RowCnt <= 1 Then Exit;
  I := 1;
  While I < Res.RowCnt Do
  Begin
    IsDup := True;
    For K := 0 To Res.ColCnt - 1 Do
      If QECompareValues(Res.Rows[I].Vals[K],
                          Res.Rows[I - 1].Vals[K]) <> 0 Then
      Begin
        IsDup := False;
        Break;
      End;
    If IsDup Then
    Begin
      { Supprimer la ligne I }
      For J := I To Res.RowCnt - 2 Do
        Res.Rows[J] := Res.Rows[J + 1];
      Dec(Res.RowCnt);
    End
    Else
      Inc(I);
  End;
End;

{ ---- Formater et afficher un result set ---------------------- }
{ Affiche les colonnes avec separateurs et largeurs ajustees.     }

Procedure QEFormatResult(Var Res : TQEResult);
Var
  I, J     : Integer;
  S, Cell  : TString;
  W        : Integer;
  Len      : Integer;
Begin
  If Res.ColCnt = 0 Then
  Begin
    OutputLine('(0 colonnes)');
    Exit;
  End;

  { Ajuster les largeurs selon les donnees }
  For I := 0 To Res.RowCnt - 1 Do
    For J := 0 To Res.ColCnt - 1 Do
    Begin
      Len := Length(SqlValueToStr(Res.Rows[I].Vals[J]));
      If Len > Res.Cols[J].Width Then
      Begin
        If Len > MAX_QE_COLWIDTH Then
          Res.Cols[J].Width := MAX_QE_COLWIDTH
        Else
          Res.Cols[J].Width := Len;
      End;
    End;

  { En-tete des colonnes }
  S := '';
  For J := 0 To Res.ColCnt - 1 Do
  Begin
    If J > 0 Then S := S + ' ';
    Cell := Res.Cols[J].Name;
    W := Res.Cols[J].Width;
    While Length(Cell) < W Do Cell := Cell + ' ';
    If Length(Cell) > W Then Cell[0] := Chr(W);
    S := S + Cell;
  End;
  OutputLine(S);

  { Ligne de separation }
  S := '';
  For J := 0 To Res.ColCnt - 1 Do
  Begin
    If J > 0 Then S := S + ' ';
    W := Res.Cols[J].Width;
    Cell := '';
    For I := 1 To W Do Cell := Cell + '-';
    S := S + Cell;
  End;
  OutputLine(S);

  { Lignes de donnees }
  For I := 0 To Res.RowCnt - 1 Do
  Begin
    S := '';
    For J := 0 To Res.ColCnt - 1 Do
    Begin
      If J > 0 Then S := S + ' ';
      Cell := SqlValueToStr(Res.Rows[I].Vals[J]);
      W := Res.Cols[J].Width;
      While Length(Cell) < W Do Cell := Cell + ' ';
      If Length(Cell) > W Then Cell[0] := Chr(W);
      S := S + Cell;
    End;
    OutputLine(S);
  End;

  { Compteur de lignes }
  OutputLine('');
  OutputLine('(' + IntToStr(Res.RowCnt) + ' ligne(s) affectee(s))');
End;

{ ============================================================
  TODO 16 - JOINTURES ET OPERATEURS ENSEMBLISTES [IMPLEMENTE]
  ============================================================ }

{ ---- Charger une table par nom ------------------------------- }
{ Recherche la table dans le catalogue, charge les colonnes et    }
{ effectue un table scan. Retourne True si succes.                }

Function QELoadTable(Const TblName : TTokenText;
                      Var Res : TQEResult) : Boolean;
Var
  TblIdx : Integer;
  ObjId  : LongInt;
Begin
  QELoadTable := False;
  FillChar(Res, SizeOf(Res), 0);
  If Not CatalogValid Then Exit;
  TblIdx := QEFindTable(TblName);
  If TblIdx < 0 Then Exit;
  ObjId := SysObjects[TblIdx].ObjectId;
  QEGetTableCols(ObjId, Res);
  If Res.ColCnt = 0 Then Exit;
  QETableScan(ObjId, Res);
  QELoadTable := True;
End;

{ ---- Fusionner les colonnes de deux result sets -------------- }
{ Cree un result set avec les colonnes de Left puis de Right.     }
{ Les lignes ne sont pas copiees ; seuls les Cols/ColCnt sont     }
{ initialises.                                                    }

Procedure QEMergeCols(Const Left, Right : TQEResult;
                       Var Merged : TQEResult);
Var
  I, C : Integer;
Begin
  C := 0;
  For I := 0 To Left.ColCnt - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Merged.Cols[C] := Left.Cols[I];
      Inc(C);
    End;
  For I := 0 To Right.ColCnt - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Merged.Cols[C] := Right.Cols[I];
      Inc(C);
    End;
  Merged.ColCnt := C;
  Merged.RowCnt := 0;
End;

{ ---- Construire une ligne fusionnee -------------------------- }
{ Concatene les valeurs de la ligne gauche et droite dans Dest.   }

Procedure QEMergeRow(Const LR : TQERow; LCols : Integer;
                      Const RR : TQERow; RCols : Integer;
                      Var Dest : TQERow);
Var
  J, C : Integer;
Begin
  C := 0;
  For J := 0 To LCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Dest.Vals[C] := LR.Vals[J];
      Inc(C);
    End;
  For J := 0 To RCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Dest.Vals[C] := RR.Vals[J];
      Inc(C);
    End;
  Dest.ColCnt := C;
End;

{ ---- Construire une ligne avec NULLs a droite ---------------- }

Procedure QEMergeRowNullRight(Const LR : TQERow; LCols : Integer;
                               RCols : Integer;
                               Var Dest : TQERow);
Var
  J, C : Integer;
Begin
  C := 0;
  For J := 0 To LCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Dest.Vals[C] := LR.Vals[J];
      Inc(C);
    End;
  For J := 0 To RCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      InitSqlValue(Dest.Vals[C]);
      Dest.Vals[C].IsNull := True;
      Dest.Vals[C].Valid  := True;
      Inc(C);
    End;
  Dest.ColCnt := C;
End;

{ ---- Construire une ligne avec NULLs a gauche ---------------- }

Procedure QEMergeRowNullLeft(LCols : Integer;
                              Const RR : TQERow; RCols : Integer;
                              Var Dest : TQERow);
Var
  J, C : Integer;
Begin
  C := 0;
  For J := 0 To LCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      InitSqlValue(Dest.Vals[C]);
      Dest.Vals[C].IsNull := True;
      Dest.Vals[C].Valid  := True;
      Inc(C);
    End;
  For J := 0 To RCols - 1 Do
    If C < MAX_QE_COLS Then
    Begin
      Dest.Vals[C] := RR.Vals[J];
      Inc(C);
    End;
  Dest.ColCnt := C;
End;

{ ---- CROSS JOIN (produit cartesien) -------------------------- }
{ Pour chaque ligne de Left, genere une ligne pour chaque ligne   }
{ de Right. Complexite O(n*m).                                    }

Procedure QECrossJoin(Const Left, Right : TQEResult;
                       Var Res : TQEResult);
Var
  I, J : Integer;
Begin
  QEMergeCols(Left, Right, Res);
  Res.RowCnt := 0;
  For I := 0 To Left.RowCnt - 1 Do
    For J := 0 To Right.RowCnt - 1 Do
    Begin
      If Res.RowCnt >= MAX_QE_ROWS Then Break;
      QEMergeRow(Left.Rows[I], Left.ColCnt,
                  Right.Rows[J], Right.ColCnt,
                  Res.Rows[Res.RowCnt]);
      Inc(Res.RowCnt);
    End;
End;

{ ---- Nested Loop Join ---------------------------------------- }
{ Pour chaque ligne de Left, scanner Right et tester la condition }
{ ON. Gere INNER, LEFT, RIGHT, FULL OUTER.                       }

Procedure QENestedLoopJoin(Const Left, Right : TQEResult;
                            OnNode : Integer;
                            JoinType : TTokenText;
                            Var Res : TQEResult);
Var
  I, J       : Integer;
  Matched    : Boolean;
  Row        : TQERow;
  RMatched   : Array[0..MAX_QE_ROWS - 1] Of Boolean;
  IsLeft     : Boolean;
  IsRight    : Boolean;
  IsFull     : Boolean;
Begin
  QEMergeCols(Left, Right, Res);
  Res.RowCnt := 0;

  IsLeft  := (Pos('LEFT', JoinType) > 0);
  IsRight := (Pos('RIGHT', JoinType) > 0);
  IsFull  := (Pos('FULL', JoinType) > 0);
  If IsFull Then
  Begin
    IsLeft  := True;
    IsRight := True;
  End;

  { Initialiser le suivi des lignes droites matchees }
  If IsRight Then
    For J := 0 To Right.RowCnt - 1 Do
      RMatched[J] := False;

  For I := 0 To Left.RowCnt - 1 Do
  Begin
    Matched := False;
    For J := 0 To Right.RowCnt - 1 Do
    Begin
      If Res.RowCnt >= MAX_QE_ROWS Then Break;
      { Construire la ligne fusionnee pour evaluer ON }
      QEMergeRow(Left.Rows[I], Left.ColCnt,
                  Right.Rows[J], Right.ColCnt, Row);

      { Evaluer la condition ON }
      If (OnNode < 0) Or QEEvalBool(OnNode, Row, Res) Then
      Begin
        Res.Rows[Res.RowCnt] := Row;
        Inc(Res.RowCnt);
        Matched := True;
        If IsRight Then RMatched[J] := True;
      End;
    End;

    { LEFT JOIN : si aucune correspondance, emettre avec NULLs }
    If IsLeft And (Not Matched) Then
    Begin
      If Res.RowCnt < MAX_QE_ROWS Then
      Begin
        QEMergeRowNullRight(Left.Rows[I], Left.ColCnt,
                             Right.ColCnt, Res.Rows[Res.RowCnt]);
        Inc(Res.RowCnt);
      End;
    End;
  End;

  { RIGHT JOIN : emettre les lignes droites non matchees }
  If IsRight Then
    For J := 0 To Right.RowCnt - 1 Do
      If (Not RMatched[J]) And (Res.RowCnt < MAX_QE_ROWS) Then
      Begin
        QEMergeRowNullLeft(Left.ColCnt,
                            Right.Rows[J], Right.ColCnt,
                            Res.Rows[Res.RowCnt]);
        Inc(Res.RowCnt);
      End;
End;

{ ---- Fonction de hachage simple ------------------------------ }
{ Hache une TSqlValue pour la table de hachage du Hash Join.      }

Function QEHashValue(Const V : TSqlValue) : LongInt;
Var
  H : LongInt;
  I : Integer;
  S : TSqlValueStr;
Begin
  H := 0;
  If V.IsNull Then
    H := 0
  Else If V.Category = SQLCAT_INTEGER Then
    H := V.IntVal
  Else If V.Category = SQLCAT_DECIMAL Then
    H := Round(V.FloatVal * 1000)
  Else
  Begin
    S := V.StrVal;
    For I := 1 To Length(S) Do
      H := H * 31 + Ord(S[I]);
  End;
  If H < 0 Then H := -H;
  QEHashValue := H Mod MAX_QE_HASH;
End;

{ ---- Hash Join ----------------------------------------------- }
{ Construit une table de hachage sur la colonne de jointure de    }
{ la table interne (Right), puis probe avec la table externe      }
{ (Left). Les colonnes de jointure sont determinees a partir de   }
{ la condition ON (egal simple colL = colR).                      }

Procedure QEHashJoin(Const Left, Right : TQEResult;
                      OnNode : Integer;
                      JoinType : TTokenText;
                      Var Res : TQEResult);
Var
  HashTab    : Array[0..MAX_QE_HASH - 1] Of Integer;
  HashNext   : Array[0..MAX_QE_ROWS - 1] Of Integer;
  LeftCol    : Integer;
  RightCol   : Integer;
  H          : LongInt;
  I, J, Idx  : Integer;
  Matched    : Boolean;
  RMatched   : Array[0..MAX_QE_ROWS - 1] Of Boolean;
  IsLeft     : Boolean;
  IsRight    : Boolean;
  IsFull     : Boolean;
  LColName   : TTokenText;
  RColName   : TTokenText;
  Child0     : Integer;
  Child1     : Integer;
Begin
  { Determiner les colonnes de jointure depuis ON (colL = colR) }
  LeftCol  := -1;
  RightCol := -1;
  If (OnNode >= 0) And (OnNode < ASTCount) And
     (ASTPool[OnNode].Kind = ND_COMPARE) And
     (ASTPool[OnNode].Text = '=') And
     (ASTPool[OnNode].ChildCnt >= 2) Then
  Begin
    Child0 := ASTPool[OnNode].Children[0];
    Child1 := ASTPool[OnNode].Children[1];
    If (Child0 >= 0) And (Child0 < ASTCount) And
       (Child1 >= 0) And (Child1 < ASTCount) Then
    Begin
      { Extraire le nom de colonne gauche }
      If ASTPool[Child0].Kind = ND_DOT_REF Then
      Begin
        If ASTPool[Child0].ChildCnt > 0 Then
        Begin
          I := ASTPool[Child0].Children[ASTPool[Child0].ChildCnt - 1];
          If (I >= 0) And (I < ASTCount) Then
            LColName := ASTPool[I].Text;
        End;
      End
      Else
        LColName := ASTPool[Child0].Text;
      { Extraire le nom de colonne droite }
      If ASTPool[Child1].Kind = ND_DOT_REF Then
      Begin
        If ASTPool[Child1].ChildCnt > 0 Then
        Begin
          I := ASTPool[Child1].Children[ASTPool[Child1].ChildCnt - 1];
          If (I >= 0) And (I < ASTCount) Then
            RColName := ASTPool[I].Text;
        End;
      End
      Else
        RColName := ASTPool[Child1].Text;

      LeftCol  := QEFindColByName(LColName, Left);
      RightCol := QEFindColByName(RColName, Right);
      { Si pas trouve, essayer en inversant }
      If (LeftCol < 0) Or (RightCol < 0) Then
      Begin
        LeftCol  := QEFindColByName(RColName, Left);
        RightCol := QEFindColByName(LColName, Right);
      End;
    End;
  End;

  { Si on ne peut pas determiner les colonnes, fallback NL join }
  If (LeftCol < 0) Or (RightCol < 0) Then
  Begin
    QENestedLoopJoin(Left, Right, OnNode, JoinType, Res);
    Exit;
  End;

  QEMergeCols(Left, Right, Res);
  Res.RowCnt := 0;

  IsLeft  := (Pos('LEFT', JoinType) > 0);
  IsRight := (Pos('RIGHT', JoinType) > 0);
  IsFull  := (Pos('FULL', JoinType) > 0);
  If IsFull Then
  Begin
    IsLeft  := True;
    IsRight := True;
  End;

  { Initialiser la table de hachage }
  For I := 0 To MAX_QE_HASH - 1 Do
    HashTab[I] := -1;

  { Construire la table de hachage sur la table Right }
  For J := 0 To Right.RowCnt - 1 Do
  Begin
    H := QEHashValue(Right.Rows[J].Vals[RightCol]);
    HashNext[J] := HashTab[H];
    HashTab[H]  := J;
  End;

  If IsRight Then
    For J := 0 To Right.RowCnt - 1 Do
      RMatched[J] := False;

  { Probe avec la table Left }
  For I := 0 To Left.RowCnt - 1 Do
  Begin
    Matched := False;
    H := QEHashValue(Left.Rows[I].Vals[LeftCol]);
    Idx := HashTab[H];
    While Idx >= 0 Do
    Begin
      If Res.RowCnt >= MAX_QE_ROWS Then Break;
      If QECompareValues(Left.Rows[I].Vals[LeftCol],
                          Right.Rows[Idx].Vals[RightCol]) = 0 Then
      Begin
        QEMergeRow(Left.Rows[I], Left.ColCnt,
                    Right.Rows[Idx], Right.ColCnt,
                    Res.Rows[Res.RowCnt]);
        Inc(Res.RowCnt);
        Matched := True;
        If IsRight Then RMatched[Idx] := True;
      End;
      Idx := HashNext[Idx];
    End;

    If IsLeft And (Not Matched) Then
    Begin
      If Res.RowCnt < MAX_QE_ROWS Then
      Begin
        QEMergeRowNullRight(Left.Rows[I], Left.ColCnt,
                             Right.ColCnt, Res.Rows[Res.RowCnt]);
        Inc(Res.RowCnt);
      End;
    End;
  End;

  If IsRight Then
    For J := 0 To Right.RowCnt - 1 Do
      If (Not RMatched[J]) And (Res.RowCnt < MAX_QE_ROWS) Then
      Begin
        QEMergeRowNullLeft(Left.ColCnt,
                            Right.Rows[J], Right.ColCnt,
                            Res.Rows[Res.RowCnt]);
        Inc(Res.RowCnt);
      End;
End;

{ ---- Selection automatique de l algorithme de jointure ------- }
{ Choisit Hash Join quand la condition ON est un egal simple,     }
{ sinon utilise Nested Loop Join. Merge Join est utilise quand     }
{ les deux tables sont petites et triees.                         }

Procedure QEExecJoin(Const Left, Right : TQEResult;
                      OnNode : Integer;
                      JoinType : TTokenText;
                      Var Res : TQEResult);
Var
  UT : TString;
Begin
  UT := StrUpperCase(JoinType);
  { CROSS JOIN : pas de condition ON }
  If Pos('CROSS', UT) > 0 Then
  Begin
    QECrossJoin(Left, Right, Res);
    Exit;
  End;

  { Hash Join pour les egalites simples (colA = colB) }
  If (OnNode >= 0) And (OnNode < ASTCount) And
     (ASTPool[OnNode].Kind = ND_COMPARE) And
     (ASTPool[OnNode].Text = '=') Then
    QEHashJoin(Left, Right, OnNode, UT, Res)
  Else
    QENestedLoopJoin(Left, Right, OnNode, UT, Res);
End;

{ ---- Verifier compatibilite de colonnes pour UNION ----------- }
{ Les deux result sets doivent avoir le meme nombre de colonnes.  }

Function QESetOpCompatible(Const A, B : TQEResult) : Boolean;
Begin
  QESetOpCompatible := (A.ColCnt > 0) And (A.ColCnt = B.ColCnt);
End;

{ ---- UNION [ALL] --------------------------------------------- }
{ Concatene les lignes des deux result sets. UNION elimine les    }
{ doublons ; UNION ALL les conserve.                              }

Procedure QEExecUnion(Const Left, Right : TQEResult;
                       IsAll : Boolean;
                       Var Res : TQEResult);
Var
  I, J : Integer;
Begin
  { Copier les colonnes du premier result set }
  Res.ColCnt := Left.ColCnt;
  For J := 0 To Left.ColCnt - 1 Do
    Res.Cols[J] := Left.Cols[J];
  Res.RowCnt := 0;

  { Copier les lignes de Left }
  For I := 0 To Left.RowCnt - 1 Do
    If Res.RowCnt < MAX_QE_ROWS Then
    Begin
      Res.Rows[Res.RowCnt] := Left.Rows[I];
      Res.Rows[Res.RowCnt].ColCnt := Left.ColCnt;
      Inc(Res.RowCnt);
    End;

  { Copier les lignes de Right }
  For I := 0 To Right.RowCnt - 1 Do
    If Res.RowCnt < MAX_QE_ROWS Then
    Begin
      Res.Rows[Res.RowCnt].ColCnt := Left.ColCnt;
      For J := 0 To Left.ColCnt - 1 Do
      Begin
        If J < Right.ColCnt Then
          Res.Rows[Res.RowCnt].Vals[J] := Right.Rows[I].Vals[J]
        Else
        Begin
          InitSqlValue(Res.Rows[Res.RowCnt].Vals[J]);
          Res.Rows[Res.RowCnt].Vals[J].IsNull := True;
          Res.Rows[Res.RowCnt].Vals[J].Valid  := True;
        End;
      End;
      Inc(Res.RowCnt);
    End;

  { UNION (sans ALL) : eliminer les doublons }
  If (Not IsAll) And (Res.RowCnt > 1) Then
  Begin
    If Res.ColCnt > 0 Then
    Begin
      QESortCol  := 0;
      QESortDesc := False;
      QEQuickSort(Res, 0, Res.RowCnt - 1);
    End;
    QEDistinct(Res);
  End;
End;

{ ---- INTERSECT ----------------------------------------------- }
{ Retourne les lignes presentes dans les deux result sets.        }
{ Utilise un tri + scan pour detecter les correspondances.        }

Procedure QEExecIntersect(Const Left, Right : TQEResult;
                           Var Res : TQEResult);
Var
  I, J, K    : Integer;
  Found      : Boolean;
  AllMatch   : Boolean;
Begin
  Res.ColCnt := Left.ColCnt;
  For J := 0 To Left.ColCnt - 1 Do
    Res.Cols[J] := Left.Cols[J];
  Res.RowCnt := 0;

  For I := 0 To Left.RowCnt - 1 Do
  Begin
    Found := False;
    For J := 0 To Right.RowCnt - 1 Do
    Begin
      AllMatch := True;
      For K := 0 To Left.ColCnt - 1 Do
      Begin
        If K >= Right.ColCnt Then
        Begin
          AllMatch := False;
          Break;
        End;
        If QECompareValues(Left.Rows[I].Vals[K],
                            Right.Rows[J].Vals[K]) <> 0 Then
        Begin
          AllMatch := False;
          Break;
        End;
      End;
      If AllMatch Then
      Begin
        Found := True;
        Break;
      End;
    End;
    If Found And (Res.RowCnt < MAX_QE_ROWS) Then
    Begin
      Res.Rows[Res.RowCnt] := Left.Rows[I];
      Res.Rows[Res.RowCnt].ColCnt := Left.ColCnt;
      Inc(Res.RowCnt);
    End;
  End;

  { Eliminer les doublons }
  If Res.RowCnt > 1 Then
  Begin
    If Res.ColCnt > 0 Then
    Begin
      QESortCol  := 0;
      QESortDesc := False;
      QEQuickSort(Res, 0, Res.RowCnt - 1);
    End;
    QEDistinct(Res);
  End;
End;

{ ---- EXCEPT -------------------------------------------------- }
{ Retourne les lignes de Left absentes de Right.                  }

Procedure QEExecExcept(Const Left, Right : TQEResult;
                        Var Res : TQEResult);
Var
  I, J, K    : Integer;
  Found      : Boolean;
  AllMatch   : Boolean;
Begin
  Res.ColCnt := Left.ColCnt;
  For J := 0 To Left.ColCnt - 1 Do
    Res.Cols[J] := Left.Cols[J];
  Res.RowCnt := 0;

  For I := 0 To Left.RowCnt - 1 Do
  Begin
    Found := False;
    For J := 0 To Right.RowCnt - 1 Do
    Begin
      AllMatch := True;
      For K := 0 To Left.ColCnt - 1 Do
      Begin
        If K >= Right.ColCnt Then
        Begin
          AllMatch := False;
          Break;
        End;
        If QECompareValues(Left.Rows[I].Vals[K],
                            Right.Rows[J].Vals[K]) <> 0 Then
        Begin
          AllMatch := False;
          Break;
        End;
      End;
      If AllMatch Then
      Begin
        Found := True;
        Break;
      End;
    End;
    If (Not Found) And (Res.RowCnt < MAX_QE_ROWS) Then
    Begin
      Res.Rows[Res.RowCnt] := Left.Rows[I];
      Res.Rows[Res.RowCnt].ColCnt := Left.ColCnt;
      Inc(Res.RowCnt);
    End;
  End;

  { Eliminer les doublons }
  If Res.RowCnt > 1 Then
  Begin
    If Res.ColCnt > 0 Then
    Begin
      QESortCol  := 0;
      QESortDesc := False;
      QEQuickSort(Res, 0, Res.RowCnt - 1);
    End;
    QEDistinct(Res);
  End;
End;

{ ---- Executer un operateur ensembliste ----------------------- }
{ Dispatche UNION [ALL], INTERSECT, EXCEPT. Chaque branche est   }
{ executee via QEExecSelect puis les resultats sont combines.     }

Procedure QEExecSetOp(Root : Integer); Forward;

Procedure QEExecSelect(Root : Integer); Forward;

Procedure QEExecSetOp(Root : Integer);
Var
  LeftChild  : Integer;
  RightChild : Integer;
  LeftRes    : TQEResultPtr;
  RightRes   : TQEResultPtr;
  SavedQERes : TQEResultPtr;
Begin
  If (Root < 0) Or (Root >= ASTCount) Then
  Begin
    OutputLine('-- Erreur : noeud operateur ensembliste invalide');
    Exit;
  End;

  If ASTPool[Root].ChildCnt < 2 Then
  Begin
    OutputLine('-- Erreur : operateur ensembliste necessite 2 operandes');
    Exit;
  End;

  LeftChild  := ASTPool[Root].Children[0];
  RightChild := ASTPool[Root].Children[1];

  { Executer la branche gauche }
  New(LeftRes);
  FillChar(LeftRes^, SizeOf(TQEResult), 0);
  SavedQERes := QERes;
  QERes := LeftRes;
  If ASTPool[LeftChild].Kind = ND_SELECT_STMT Then
    QEExecSelect(LeftChild)
  Else If (ASTPool[LeftChild].Kind = ND_UNION) Or
          (ASTPool[LeftChild].Kind = ND_INTERSECT_OP) Or
          (ASTPool[LeftChild].Kind = ND_EXCEPT_OP) Then
    QEExecSetOp(LeftChild);
  LeftRes := QERes;
  QERes := SavedQERes;

  { Executer la branche droite }
  New(RightRes);
  FillChar(RightRes^, SizeOf(TQEResult), 0);
  SavedQERes := QERes;
  QERes := RightRes;
  If ASTPool[RightChild].Kind = ND_SELECT_STMT Then
    QEExecSelect(RightChild)
  Else If (ASTPool[RightChild].Kind = ND_UNION) Or
          (ASTPool[RightChild].Kind = ND_INTERSECT_OP) Or
          (ASTPool[RightChild].Kind = ND_EXCEPT_OP) Then
    QEExecSetOp(RightChild);
  RightRes := QERes;
  QERes := SavedQERes;

  { Verifier compatibilite }
  If Not QESetOpCompatible(LeftRes^, RightRes^) Then
  Begin
    OutputLine('-- Erreur : nombre de colonnes incompatible pour ' +
               ASTPool[Root].Text);
    Dispose(LeftRes);
    Dispose(RightRes);
    Exit;
  End;

  { Combiner les resultats }
  If QERes = Nil Then New(QERes);
  FillChar(QERes^, SizeOf(TQEResult), 0);

  Case ASTPool[Root].Kind Of
    ND_UNION :
      QEExecUnion(LeftRes^, RightRes^,
                   Pos('ALL', StrUpperCase(ASTPool[Root].Text)) > 0,
                   QERes^);
    ND_INTERSECT_OP :
      QEExecIntersect(LeftRes^, RightRes^, QERes^);
    ND_EXCEPT_OP :
      QEExecExcept(LeftRes^, RightRes^, QERes^);
  End;

  Dispose(LeftRes);
  Dispose(RightRes);

  { Afficher le result set }
  QEFormatResult(QERes^);
End;

{ ---- Fonctions d agregation et GROUP BY (TODO 17) ------------ }
{ Detecte si un nom de fonction est un agregat SQL.                }

Function QEIsAggrFunc(Const FnName : TTokenText) : Boolean;
Var
  U : TTokenText;
Begin
  U := StrUpperCase(FnName);
  QEIsAggrFunc := (U = 'COUNT') Or (U = 'SUM') Or (U = 'AVG') Or
                  (U = 'MIN') Or (U = 'MAX') Or
                  (U = 'STDEV') Or (U = 'STDEVP') Or
                  (U = 'VAR') Or (U = 'VARP') Or
                  (U = 'STRING_AGG') Or
                  (U = 'GROUPING') Or (U = 'GROUPING_ID');
End;

{ Detecte si un noeud AST contient un appel a une fonction agregat }

Function QEHasAggregate(Node : Integer) : Boolean;
Var
  I, C : Integer;
Begin
  QEHasAggregate := False;
  If (Node < 0) Or (Node >= ASTCount) Then Exit;
  If (ASTPool[Node].Kind = ND_FUNC_CALL) And
     QEIsAggrFunc(ASTPool[Node].Text) Then
  Begin
    QEHasAggregate := True;
    Exit;
  End;
  For I := 0 To ASTPool[Node].ChildCnt - 1 Do
  Begin
    C := ASTPool[Node].Children[I];
    If QEHasAggregate(C) Then
    Begin
      QEHasAggregate := True;
      Exit;
    End;
  End;
End;

{ Evalue une fonction agregat sur un ensemble de lignes.           }
{ StartR..EndR definissent la plage de lignes dans SrcRes.         }

Function QEEvalAggregate(Node : Integer;
                          Const SrcRes : TQEResult;
                          StartR, EndR : Integer) : TSqlValue;
Var
  Op          : TTokenText;
  V, AV       : TSqlValue;
  I, ArgNode  : Integer;
  Cnt         : LongInt;
  SumF        : Real;
  SumI        : LongInt;
  MinV, MaxV  : TSqlValue;
  HasMin      : Boolean;
  HasMax      : Boolean;
  UseFloat    : Boolean;
  CmpR        : Integer;
  Sep         : TSqlValueStr;
  Concat      : TSqlValueStr;
  FirstConcat : Boolean;
  DistKeys    : Array[0..MAX_QE_ROWS - 1] Of TSqlValueStr;
  DistCnt     : Integer;
  Found       : Boolean;
  J           : Integer;
  SumSq       : Real;
  MeanF       : Real;
  IsDistinct  : Boolean;
  DistNode    : Integer;
Begin
  V.IsNull   := True;
  V.Valid    := True;
  V.Category := SQLCAT_INTEGER;
  V.XType    := XT_INT;
  V.IntVal   := 0;
  V.FloatVal := 0.0;
  V.StrVal   := '';
  V.HiVal    := 0;
  QEEvalAggregate := V;

  If (Node < 0) Or (Node >= ASTCount) Then Exit;
  If ASTPool[Node].Kind <> ND_FUNC_CALL Then Exit;

  Op := StrUpperCase(ASTPool[Node].Text);

  { Determiner le noeud argument (enfant[1], car enfant[0] est le nom) }
  ArgNode := -1;
  If ASTPool[Node].ChildCnt > 1 Then
    ArgNode := ASTPool[Node].Children[1];

  { Verifier COUNT(DISTINCT ...) }
  IsDistinct := False;
  If (Op = 'COUNT') And (ArgNode >= 0) And (ArgNode < ASTCount) And
     (StrUpperCase(ASTPool[ArgNode].Text) = 'DISTINCT') Then
  Begin
    IsDistinct := True;
    { L argument reel est le suivant }
    If ASTPool[Node].ChildCnt > 2 Then
      ArgNode := ASTPool[Node].Children[2]
    Else
      ArgNode := -1;
  End;

  { COUNT(*) }
  If Op = 'COUNT' Then
  Begin
    { Verifier si c est COUNT(*) }
    If (ArgNode >= 0) And (ArgNode < ASTCount) And
       (ASTPool[ArgNode].Kind = ND_STAR) Then
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.IntVal   := (EndR - StartR) + 1;
      QEEvalAggregate := V;
      Exit;
    End;

    { COUNT(col) ou COUNT(DISTINCT col) }
    Cnt := 0;
    DistCnt := 0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
      Begin
        AV.IsNull := False;
        AV.Valid := True;
      End;
      If Not AV.IsNull Then
      Begin
        If IsDistinct Then
        Begin
          { Verifier l unicite }
          Sep := SqlValueToStr(AV);
          Found := False;
          For J := 0 To DistCnt - 1 Do
          Begin
            If DistKeys[J] = Sep Then
            Begin
              Found := True;
              Break;
            End;
          End;
          If Not Found Then
          Begin
            If DistCnt < MAX_QE_ROWS Then
            Begin
              DistKeys[DistCnt] := Sep;
              Inc(DistCnt);
            End;
            Inc(Cnt);
          End;
        End
        Else
          Inc(Cnt);
      End;
    End;
    V.IsNull   := False;
    V.Category := SQLCAT_INTEGER;
    V.XType    := XT_INT;
    V.IntVal   := Cnt;
    QEEvalAggregate := V;
    Exit;
  End;

  { SUM(col) }
  If Op = 'SUM' Then
  Begin
    SumF := 0.0;
    SumI := 0;
    UseFloat := False;
    Cnt := 0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        Inc(Cnt);
        If AV.Category = SQLCAT_DECIMAL Then
        Begin
          UseFloat := True;
          SumF := SumF + AV.FloatVal;
        End
        Else
        Begin
          SumI := SumI + AV.IntVal;
          SumF := SumF + AV.IntVal;
        End;
      End;
    End;
    If Cnt = 0 Then
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End
    Else If UseFloat Then
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_DECIMAL;
      V.XType    := XT_FLOAT;
      V.FloatVal := SumF;
    End
    Else
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_INTEGER;
      V.XType    := XT_INT;
      V.IntVal   := SumI;
    End;
    QEEvalAggregate := V;
    Exit;
  End;

  { AVG(col) }
  If Op = 'AVG' Then
  Begin
    SumF := 0.0;
    Cnt := 0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        Inc(Cnt);
        If AV.Category = SQLCAT_DECIMAL Then
          SumF := SumF + AV.FloatVal
        Else
          SumF := SumF + AV.IntVal;
      End;
    End;
    If Cnt = 0 Then
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End
    Else
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_DECIMAL;
      V.XType    := XT_FLOAT;
      V.FloatVal := SumF / Cnt;
    End;
    QEEvalAggregate := V;
    Exit;
  End;

  { MIN(col) }
  If Op = 'MIN' Then
  Begin
    HasMin := False;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        If Not HasMin Then
        Begin
          MinV := AV;
          HasMin := True;
        End
        Else
        Begin
          CmpR := QECompareValues(AV, MinV);
          If CmpR < 0 Then MinV := AV;
        End;
      End;
    End;
    If HasMin Then
      V := MinV
    Else
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End;
    QEEvalAggregate := V;
    Exit;
  End;

  { MAX(col) }
  If Op = 'MAX' Then
  Begin
    HasMax := False;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        If Not HasMax Then
        Begin
          MaxV := AV;
          HasMax := True;
        End
        Else
        Begin
          CmpR := QECompareValues(AV, MaxV);
          If CmpR > 0 Then MaxV := AV;
        End;
      End;
    End;
    If HasMax Then
      V := MaxV
    Else
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End;
    QEEvalAggregate := V;
    Exit;
  End;

  { STDEV(col) - ecart-type d echantillon }
  If (Op = 'STDEV') Or (Op = 'STDEVP') Then
  Begin
    SumF := 0.0;
    Cnt := 0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        Inc(Cnt);
        If AV.Category = SQLCAT_DECIMAL Then
          SumF := SumF + AV.FloatVal
        Else
          SumF := SumF + AV.IntVal;
      End;
    End;
    If ((Op = 'STDEV') And (Cnt < 2)) Or
       ((Op = 'STDEVP') And (Cnt < 1)) Then
    Begin
      V.IsNull := True;
      V.Valid  := True;
      QEEvalAggregate := V;
      Exit;
    End;
    MeanF := SumF / Cnt;
    SumSq := 0.0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        If AV.Category = SQLCAT_DECIMAL Then
          SumSq := SumSq + (AV.FloatVal - MeanF) * (AV.FloatVal - MeanF)
        Else
          SumSq := SumSq + (AV.IntVal - MeanF) * (AV.IntVal - MeanF);
      End;
    End;
    V.IsNull   := False;
    V.Category := SQLCAT_DECIMAL;
    V.XType    := XT_FLOAT;
    If Op = 'STDEVP' Then
      V.FloatVal := Sqrt(SumSq / Cnt)
    Else
      V.FloatVal := Sqrt(SumSq / (Cnt - 1));
    QEEvalAggregate := V;
    Exit;
  End;

  { VAR(col), VARP(col) - variance }
  If (Op = 'VAR') Or (Op = 'VARP') Then
  Begin
    SumF := 0.0;
    Cnt := 0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        Inc(Cnt);
        If AV.Category = SQLCAT_DECIMAL Then
          SumF := SumF + AV.FloatVal
        Else
          SumF := SumF + AV.IntVal;
      End;
    End;
    If ((Op = 'VAR') And (Cnt < 2)) Or
       ((Op = 'VARP') And (Cnt < 1)) Then
    Begin
      V.IsNull := True;
      V.Valid  := True;
      QEEvalAggregate := V;
      Exit;
    End;
    MeanF := SumF / Cnt;
    SumSq := 0.0;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        If AV.Category = SQLCAT_DECIMAL Then
          SumSq := SumSq + (AV.FloatVal - MeanF) * (AV.FloatVal - MeanF)
        Else
          SumSq := SumSq + (AV.IntVal - MeanF) * (AV.IntVal - MeanF);
      End;
    End;
    V.IsNull   := False;
    V.Category := SQLCAT_DECIMAL;
    V.XType    := XT_FLOAT;
    If Op = 'VARP' Then
      V.FloatVal := SumSq / Cnt
    Else
      V.FloatVal := SumSq / (Cnt - 1);
    QEEvalAggregate := V;
    Exit;
  End;

  { STRING_AGG(col, separateur) }
  If Op = 'STRING_AGG' Then
  Begin
    Sep := ',';
    { Le separateur est l argument 2 (enfant[2]) }
    If ASTPool[Node].ChildCnt > 2 Then
    Begin
      DistNode := ASTPool[Node].Children[2];
      If (DistNode >= 0) And (DistNode < ASTCount) Then
      Begin
        AV := QEEvalExpr(DistNode, SrcRes.Rows[StartR], SrcRes);
        If Not AV.IsNull Then
          Sep := AV.StrVal;
        If Length(Sep) = 0 Then Sep := SqlValueToStr(AV);
      End;
    End;
    Concat := '';
    FirstConcat := True;
    For I := StartR To EndR Do
    Begin
      If ArgNode >= 0 Then
        AV := QEEvalExpr(ArgNode, SrcRes.Rows[I], SrcRes)
      Else
        AV.IsNull := True;
      If Not AV.IsNull Then
      Begin
        If Not FirstConcat Then
          Concat := Concat + Sep;
        Concat := Concat + SqlValueToStr(AV);
        FirstConcat := False;
      End;
    End;
    If FirstConcat Then
    Begin
      V.IsNull := True;
      V.Valid  := True;
    End
    Else
    Begin
      V.IsNull   := False;
      V.Category := SQLCAT_STRING;
      V.XType    := XT_VARCHAR;
      V.StrVal   := Concat;
    End;
    QEEvalAggregate := V;
    Exit;
  End;

  { GROUPING(col) - retourne 1 si super-agregate, 0 sinon }
  If (Op = 'GROUPING') Or (Op = 'GROUPING_ID') Then
  Begin
    V.IsNull   := False;
    V.Category := SQLCAT_INTEGER;
    V.XType    := XT_INT;
    V.IntVal   := 0;
    QEEvalAggregate := V;
    Exit;
  End;

  { Aggregat inconnu }
  V.IsNull := True;
  V.Valid  := True;
  QEEvalAggregate := V;
End;

{ Evalue une expression en remplacant les appels aux agregate      }
{ par leur valeur calculee sur le groupe (StartR..EndR).           }

Function QEEvalExprAggr(Node : Integer;
                         Const Row : TQERow;
                         Const Res : TQEResult;
                         StartR, EndR : Integer) : TSqlValue;
Var
  V : TSqlValue;
Begin
  V.IsNull := True;
  V.Valid  := True;
  If (Node < 0) Or (Node >= ASTCount) Then
  Begin
    QEEvalExprAggr := V;
    Exit;
  End;

  { Si c est un appel a une fonction agregat, l evaluer sur le groupe }
  If (ASTPool[Node].Kind = ND_FUNC_CALL) And
     QEIsAggrFunc(ASTPool[Node].Text) Then
  Begin
    QEEvalExprAggr := QEEvalAggregate(Node, Res, StartR, EndR);
    Exit;
  End;

  { Sinon, evaluation normale sur la ligne representante }
  QEEvalExprAggr := QEEvalExpr(Node, Row, Res);
End;

{ Construit la cle de groupe pour une ligne, en concatenant les    }
{ valeurs des colonnes GROUP BY separees par un delimiteur.        }

Function QEGroupKey(Const Row : TQERow;
                     Const Res : TQEResult;
                     GroupNode : Integer) : TSqlValueStr;
Var
  I, C   : Integer;
  V      : TSqlValue;
  Key    : TSqlValueStr;
Begin
  Key := '';
  If (GroupNode < 0) Or (GroupNode >= ASTCount) Then
  Begin
    QEGroupKey := '';
    Exit;
  End;
  For I := 0 To ASTPool[GroupNode].ChildCnt - 1 Do
  Begin
    C := ASTPool[GroupNode].Children[I];
    If (C >= 0) And (C < ASTCount) Then
    Begin
      V := QEEvalExpr(C, Row, Res);
      If I > 0 Then Key := Key + #1;
      If V.IsNull Then
        Key := Key + #0
      Else
        Key := Key + SqlValueToStr(V);
    End;
  End;
  QEGroupKey := Key;
End;

{ Effectue le GROUP BY + agregation sur SrcRes.                    }
{ GroupNode = noeud ND_GROUP_BY (-1 si pas de GROUP BY mais avec   }
{ des agregats => un seul groupe sur toutes les lignes).           }
{ HavingNode = noeud ND_HAVING (-1 si pas de HAVING).             }
{ Root = noeud ND_SELECT_STMT.                                     }
{ Resultat ecrit dans QERes^.                                      }

Procedure QEExecGroupBy(Const SrcRes : TQEResult;
                         Root, GroupNode, HavingNode : Integer);
Var
  I, J, K, N      : Integer;
  GrpKeys          : Array[0..MAX_QE_GROUPS - 1] Of TSqlValueStr;
  GrpCnt           : Integer;
  Key              : TSqlValueStr;
  Found            : Boolean;
  Sorted           : TQEResult;
  NbCols           : Integer;
  CI               : Integer;
  V                : TSqlValue;
  ProjNames        : Array[0..MAX_QE_COLS - 1] Of TQEColName;
Begin
  If QERes = Nil Then New(QERes);
  QERes^.ColCnt := 0;
  QERes^.RowCnt := 0;

  { Phase 1 : Identifier les groupes }
  GrpCnt := 0;

  If GroupNode < 0 Then
  Begin
    { Pas de GROUP BY : un seul groupe = toutes les lignes }
    GrpCnt := 1;
    GrpKeys[0] := '';
  End
  Else
  Begin
    { Hacher chaque ligne pour trouver son groupe }
    For I := 0 To SrcRes.RowCnt - 1 Do
    Begin
      Key := QEGroupKey(SrcRes.Rows[I], SrcRes, GroupNode);
      Found := False;
      For J := 0 To GrpCnt - 1 Do
      Begin
        If GrpKeys[J] = Key Then
        Begin
          Found := True;
          Break;
        End;
      End;
      If Not Found Then
      Begin
        If GrpCnt < MAX_QE_GROUPS Then
        Begin
          GrpKeys[GrpCnt] := Key;
          Inc(GrpCnt);
        End;
      End;
    End;
  End;

  { Phase 2 : Determiner les colonnes de sortie (SELECT items) }
  NbCols := 0;
  For I := 0 To ASTPool[Root].ChildCnt - 1 Do
  Begin
    N := ASTPool[Root].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    If ASTPool[N].Kind = ND_SELECT_ITEM Then
    Begin
      If NbCols >= MAX_QE_COLS Then Break;
      ProjNames[NbCols] := '(expr)';
      If ASTPool[N].ChildCnt > 0 Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) Then
        Begin
          If ASTPool[CI].Kind = ND_IDENT Then
            ProjNames[NbCols] := ASTPool[CI].Text
          Else If (ASTPool[CI].Kind = ND_FUNC_CALL) Then
            ProjNames[NbCols] := ASTPool[CI].Text;
        End;
        { Chercher alias }
        For K := 0 To ASTPool[N].ChildCnt - 1 Do
        Begin
          J := ASTPool[N].Children[K];
          If (J >= 0) And (J < ASTCount) And
             (ASTPool[J].Kind = ND_ALIAS) Then
            ProjNames[NbCols] := ASTPool[J].Text;
        End;
      End;
      Inc(NbCols);
    End;
  End;

  { Configurer les colonnes du result set }
  QERes^.ColCnt := NbCols;
  For J := 0 To NbCols - 1 Do
  Begin
    QERes^.Cols[J].Name   := ProjNames[J];
    QERes^.Cols[J].XType  := 0;
    QERes^.Cols[J].MaxLen := 0;
    QERes^.Cols[J].Prec   := 0;
    QERes^.Cols[J].Scale  := 0;
    QERes^.Cols[J].ColIdx := -1;
    QERes^.Cols[J].Width  := Length(ProjNames[J]);
  End;

  { Phase 3 : Pour chaque groupe, evaluer les expressions SELECT }
  { avec les agregate calcules sur le groupe.                      }
  For I := 0 To GrpCnt - 1 Do
  Begin
    If QERes^.RowCnt >= MAX_QE_ROWS Then Break;

    { Construire la copie temporaire du sous-ensemble pour les       }
    { groupes non contigus. On passe la plage originale.             }
    { Pour GROUP BY, les lignes ne sont pas forcement contigues.     }
    { On collecte les indices des lignes du groupe.                  }
    Sorted.ColCnt := SrcRes.ColCnt;
    For J := 0 To SrcRes.ColCnt - 1 Do
      Sorted.Cols[J] := SrcRes.Cols[J];
    Sorted.RowCnt := 0;
    If GroupNode < 0 Then
    Begin
      { Un seul groupe = toutes les lignes }
      Sorted := SrcRes;
    End
    Else
    Begin
      For J := 0 To SrcRes.RowCnt - 1 Do
      Begin
        Key := QEGroupKey(SrcRes.Rows[J], SrcRes, GroupNode);
        If Key = GrpKeys[I] Then
        Begin
          If Sorted.RowCnt < MAX_QE_ROWS Then
          Begin
            Sorted.Rows[Sorted.RowCnt] := SrcRes.Rows[J];
            Inc(Sorted.RowCnt);
          End;
        End;
      End;
    End;

    If Sorted.RowCnt = 0 Then Continue;

    { Evaluer chaque colonne SELECT pour ce groupe }
    QERes^.Rows[QERes^.RowCnt].ColCnt := NbCols;
    K := 0;
    For J := 0 To ASTPool[Root].ChildCnt - 1 Do
    Begin
      N := ASTPool[Root].Children[J];
      If (N < 0) Or (N >= ASTCount) Then Continue;
      If ASTPool[N].Kind <> ND_SELECT_ITEM Then Continue;
      If K >= NbCols Then Break;

      If ASTPool[N].ChildCnt > 0 Then
      Begin
        CI := ASTPool[N].Children[0];
        QERes^.Rows[QERes^.RowCnt].Vals[K] :=
          QEEvalExprAggr(CI, Sorted.Rows[0], Sorted,
                          0, Sorted.RowCnt - 1);
      End
      Else
      Begin
        V.IsNull := True;
        V.Valid  := True;
        QERes^.Rows[QERes^.RowCnt].Vals[K] := V;
      End;
      Inc(K);
    End;

    Inc(QERes^.RowCnt);
  End;

  { Phase 4 : Appliquer le filtre HAVING }
  If (HavingNode >= 0) And (ASTPool[HavingNode].ChildCnt > 0) Then
  Begin
    { HAVING fonctionne sur le result set agrege }
    { On re-evalue la condition HAVING pour chaque ligne de resultat }
    J := 0;
    For I := 0 To QERes^.RowCnt - 1 Do
    Begin
      { Evaluer la condition HAVING avec les valeurs de la ligne }
      N := ASTPool[HavingNode].Children[0];
      V := QEEvalExpr(N, QERes^.Rows[I], QERes^);
      If (Not V.IsNull) And V.Valid And
         ((V.Category = SQLCAT_INTEGER) And (V.IntVal <> 0)) Then
      Begin
        If J <> I Then
          QERes^.Rows[J] := QERes^.Rows[I];
        Inc(J);
      End
      Else If (Not V.IsNull) And V.Valid And
              (V.Category = SQLCAT_STRING) And
              (StrUpperCase(V.StrVal) = 'TRUE') Then
      Begin
        If J <> I Then
          QERes^.Rows[J] := QERes^.Rows[I];
        Inc(J);
      End;
    End;
    QERes^.RowCnt := J;
  End;
End;

{ ---- Executer un SELECT ------------------------------------- }
{ Pipeline : Scan -> Join -> Filter(WHERE) -> GroupBy/Aggregate   }
{            -> Having -> Project -> Window -> Sort -> Distinct    }
{            -> Top -> Output                                      }

{ ---- Fonctions de fenetre (Window Functions) (TODO 18) ------- }
{ Detecte et evalue les fonctions de fenetre (ROW_NUMBER, RANK,    }
{ DENSE_RANK, NTILE, LAG, LEAD, FIRST_VALUE, LAST_VALUE,          }
{ PERCENT_RANK, CUME_DIST) avec clause OVER (PARTITION BY,         }
{ ORDER BY, frame). Supporte aussi les agregats en fenetre :       }
{ SUM/AVG/COUNT/MIN/MAX OVER (...).                                }

Var
  QEWinIdx      : Array[0..MAX_QE_ROWS - 1] Of Integer;
  QEWinOverNode : Integer;
  QEWinResPtr   : TQEResultPtr;

Function QEIsWindowFunc(Const FnName : TTokenText) : Boolean;
Var U : TTokenText;
Begin
  U := StrUpperCase(FnName);
  QEIsWindowFunc :=
    (U = 'ROW_NUMBER') Or (U = 'RANK') Or (U = 'DENSE_RANK') Or
    (U = 'NTILE') Or (U = 'LAG') Or (U = 'LEAD') Or
    (U = 'FIRST_VALUE') Or (U = 'LAST_VALUE') Or
    (U = 'PERCENT_RANK') Or (U = 'CUME_DIST');
End;

Function QEHasWindowFunc(Node : Integer) : Boolean;
Var I : Integer;
Begin
  QEHasWindowFunc := False;
  If (Node < 0) Or (Node >= ASTCount) Then Exit;
  If ASTPool[Node].Kind = ND_OVER_CLAUSE Then
  Begin
    QEHasWindowFunc := True;
    Exit;
  End;
  For I := 0 To ASTPool[Node].ChildCnt - 1 Do
    If QEHasWindowFunc(ASTPool[Node].Children[I]) Then
    Begin
      QEHasWindowFunc := True;
      Exit;
    End;
End;

{ Construit la cle de partition pour une ligne }
Function QEWinPartKey(RowIdx : Integer) : TTokenText;
Var
  I, PNode, E : Integer;
  V           : TSqlValue;
  Key         : TTokenText;
Begin
  Key := '';
  If (QEWinOverNode < 0) Or (QEWinOverNode >= ASTCount) Then
  Begin
    QEWinPartKey := '';
    Exit;
  End;
  PNode := -1;
  For I := 0 To ASTPool[QEWinOverNode].ChildCnt - 1 Do
  Begin
    E := ASTPool[QEWinOverNode].Children[I];
    If (E >= 0) And (E < ASTCount) And
       (ASTPool[E].Kind = ND_PARTITION_BY) Then
    Begin
      PNode := E;
      Break;
    End;
  End;
  If PNode < 0 Then
  Begin
    QEWinPartKey := '';
    Exit;
  End;
  For I := 0 To ASTPool[PNode].ChildCnt - 1 Do
  Begin
    E := ASTPool[PNode].Children[I];
    V := QEEvalExpr(E, QEWinResPtr^.Rows[RowIdx], QEWinResPtr^);
    If Key <> '' Then Key := Key + '|';
    If V.IsNull Then Key := Key + '<NULL>'
    Else Key := Key + SqlValueToStr(V);
  End;
  QEWinPartKey := Key;
End;

{ Compare deux lignes par partition + ORDER BY }
Function QEWinCompare(A, B : Integer) : Integer;
Var
  KA, KB    : TTokenText;
  I, E, N   : Integer;
  ONode     : Integer;
  VA, VB    : TSqlValue;
  Cmp       : Integer;
  IsDesc    : Boolean;
Begin
  QEWinCompare := 0;
  KA := QEWinPartKey(A);
  KB := QEWinPartKey(B);
  If KA < KB Then Begin QEWinCompare := -1; Exit; End;
  If KA > KB Then Begin QEWinCompare := 1; Exit; End;
  ONode := -1;
  For I := 0 To ASTPool[QEWinOverNode].ChildCnt - 1 Do
  Begin
    E := ASTPool[QEWinOverNode].Children[I];
    If (E >= 0) And (E < ASTCount) And
       (ASTPool[E].Kind = ND_ORDER_BY) Then
    Begin
      ONode := E;
      Break;
    End;
  End;
  If ONode < 0 Then Exit;
  For I := 0 To ASTPool[ONode].ChildCnt - 1 Do
  Begin
    N := ASTPool[ONode].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    If ASTPool[N].Kind <> ND_ORDER_ITEM Then Continue;
    IsDesc := (StrUpperCase(ASTPool[N].Text) = 'DESC');
    If ASTPool[N].ChildCnt > 0 Then
    Begin
      E := ASTPool[N].Children[0];
      VA := QEEvalExpr(E, QEWinResPtr^.Rows[A], QEWinResPtr^);
      VB := QEEvalExpr(E, QEWinResPtr^.Rows[B], QEWinResPtr^);
      Cmp := QECompareValues(VA, VB);
      If IsDesc Then Cmp := -Cmp;
      If Cmp <> 0 Then
      Begin
        QEWinCompare := Cmp;
        Exit;
      End;
    End;
  End;
End;

{ Tri rapide de l index de fenetre }
Procedure QEWinQuickSort(Lo, Hi : Integer);
Var
  I, J, Pivot, Tmp : Integer;
Begin
  If Lo >= Hi Then Exit;
  I := Lo;
  J := Hi;
  Pivot := QEWinIdx[(Lo + Hi) Div 2];
  Repeat
    While QEWinCompare(QEWinIdx[I], Pivot) < 0 Do Inc(I);
    While QEWinCompare(QEWinIdx[J], Pivot) > 0 Do Dec(J);
    If I <= J Then
    Begin
      Tmp := QEWinIdx[I];
      QEWinIdx[I] := QEWinIdx[J];
      QEWinIdx[J] := Tmp;
      Inc(I);
      Dec(J);
    End;
  Until I > J;
  If Lo < J Then QEWinQuickSort(Lo, J);
  If I < Hi Then QEWinQuickSort(I, Hi);
End;

{ Construit la cle ORDER BY pour une ligne (pour detection egalites) }
Function QEWinOrdKey(RowIdx : Integer) : TTokenText;
Var
  I, E, N   : Integer;
  ONode     : Integer;
  V         : TSqlValue;
  Key       : TTokenText;
Begin
  Key := '';
  ONode := -1;
  For I := 0 To ASTPool[QEWinOverNode].ChildCnt - 1 Do
  Begin
    E := ASTPool[QEWinOverNode].Children[I];
    If (E >= 0) And (E < ASTCount) And
       (ASTPool[E].Kind = ND_ORDER_BY) Then
    Begin
      ONode := E;
      Break;
    End;
  End;
  If ONode < 0 Then Begin QEWinOrdKey := ''; Exit; End;
  For I := 0 To ASTPool[ONode].ChildCnt - 1 Do
  Begin
    N := ASTPool[ONode].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    If ASTPool[N].Kind <> ND_ORDER_ITEM Then Continue;
    If ASTPool[N].ChildCnt > 0 Then
    Begin
      E := ASTPool[N].Children[0];
      V := QEEvalExpr(E, QEWinResPtr^.Rows[RowIdx], QEWinResPtr^);
      If Key <> '' Then Key := Key + '|';
      If V.IsNull Then Key := Key + '<NULL>'
      Else Key := Key + SqlValueToStr(V);
    End;
  End;
  QEWinOrdKey := Key;
End;

{ Applique les fonctions de fenetre sur le result set }
Procedure QEApplyWindowFuncs(Var Res : TQEResult; Root : Integer);
Var
  I, J, K, N, CI  : Integer;
  ColIdx          : Integer;
  FuncNode        : Integer;
  FnName          : TTokenText;
  OverNode        : Integer;
  PrevPartKey     : TTokenText;
  CurPartKey      : TTokenText;
  RowNum          : LongInt;
  RankVal         : LongInt;
  DenseVal        : LongInt;
  PartSize        : Integer;
  PartStart       : Integer;
  V               : TSqlValue;
  NtileN          : LongInt;
  Bucket          : LongInt;
  BucketSize      : LongInt;
  BucketRem       : LongInt;
  PrevOrdKey      : TTokenText;
  CurOrdKey       : TTokenText;
  ArgNode         : Integer;
  LagOffset       : LongInt;
  DefaultVal      : TSqlValue;
  TargetIdx       : Integer;
  ArgExpr         : Integer;
  SumVal          : Real;
  CntVal          : LongInt;
  MinVal, MaxVal  : TSqlValue;
  TmpVal          : TSqlValue;
  LastTie         : Integer;
  IsAggr          : Boolean;
Begin
  If Res.RowCnt <= 0 Then Exit;

  ColIdx := 0;
  For I := 0 To ASTPool[Root].ChildCnt - 1 Do
  Begin
    N := ASTPool[Root].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    If ASTPool[N].Kind <> ND_SELECT_ITEM Then Continue;

    OverNode := -1;
    If ASTPool[N].ChildCnt > 0 Then
    Begin
      CI := ASTPool[N].Children[0];
      If (CI >= 0) And (CI < ASTCount) And
         (ASTPool[CI].Kind = ND_OVER_CLAUSE) Then
        OverNode := CI;
    End;

    If OverNode >= 0 Then
    Begin
      FuncNode := -1;
      If ASTPool[OverNode].ChildCnt > 0 Then
      Begin
        FuncNode := ASTPool[OverNode].Children[0];
        If (FuncNode >= 0) And (FuncNode < ASTCount) And
           (ASTPool[FuncNode].Kind = ND_FUNC_CALL) Then
          FnName := StrUpperCase(ASTPool[FuncNode].Text)
        Else
        Begin
          FnName := '';
          FuncNode := -1;
        End;
      End;

      If FuncNode < 0 Then
      Begin
        Inc(ColIdx);
        Continue;
      End;

      { Configurer le contexte de tri }
      QEWinOverNode := OverNode;
      QEWinResPtr   := @Res;

      { Initialiser le tableau d index }
      For J := 0 To Res.RowCnt - 1 Do
        QEWinIdx[J] := J;

      { Trier par partition + order }
      If Res.RowCnt > 1 Then
        QEWinQuickSort(0, Res.RowCnt - 1);

      { Detecter si c est un agregat en fenetre }
      IsAggr := (FnName = 'SUM') Or (FnName = 'AVG') Or
                (FnName = 'COUNT') Or (FnName = 'MIN') Or
                (FnName = 'MAX');

      { Expression argument pour LAG/LEAD/FIRST_VALUE/LAST_VALUE/agregats }
      ArgExpr := -1;
      If ASTPool[FuncNode].ChildCnt > 0 Then
        ArgExpr := ASTPool[FuncNode].Children[0];

      { Parcourir les lignes triees et calculer les valeurs }
      PrevPartKey := #1;
      PartStart := 0;
      PartSize := 0;
      RowNum := 0;
      RankVal := 1;
      DenseVal := 0;
      PrevOrdKey := #1;

      For J := 0 To Res.RowCnt - 1 Do
      Begin
        CurPartKey := QEWinPartKey(QEWinIdx[J]);

        { Detecter une nouvelle partition }
        If CurPartKey <> PrevPartKey Then
        Begin
          RowNum := 0;
          RankVal := 1;
          DenseVal := 0;
          PrevOrdKey := #1;
          PartStart := J;
          PartSize := 0;
          For K := J To Res.RowCnt - 1 Do
          Begin
            If QEWinPartKey(QEWinIdx[K]) = CurPartKey Then
              Inc(PartSize)
            Else
              Break;
          End;
          PrevPartKey := CurPartKey;
        End;

        Inc(RowNum);

        { Cle ORDER BY pour detection des egalites }
        CurOrdKey := QEWinOrdKey(QEWinIdx[J]);

        If CurOrdKey <> PrevOrdKey Then
        Begin
          RankVal := RowNum;
          Inc(DenseVal);
          PrevOrdKey := CurOrdKey;
        End;

        { Calculer la valeur de la fonction de fenetre }
        InitSqlValue(V);
        V.Category := SQLCAT_INTEGER;
        V.XType    := XT_INT;
        V.Valid    := True;
        V.IsNull   := False;

        If FnName = 'ROW_NUMBER' Then
          V.IntVal := RowNum
        Else If FnName = 'RANK' Then
          V.IntVal := RankVal
        Else If FnName = 'DENSE_RANK' Then
          V.IntVal := DenseVal
        Else If FnName = 'NTILE' Then
        Begin
          NtileN := 1;
          If ASTPool[FuncNode].ChildCnt > 0 Then
          Begin
            ArgNode := ASTPool[FuncNode].Children[0];
            If (ArgNode >= 0) And (ArgNode < ASTCount) Then
              Val(ASTPool[ArgNode].Text, NtileN, K);
          End;
          If NtileN < 1 Then NtileN := 1;
          BucketSize := PartSize Div NtileN;
          BucketRem  := PartSize Mod NtileN;
          K := RowNum;
          Bucket := 0;
          While K > 0 Do
          Begin
            Inc(Bucket);
            If Bucket <= BucketRem Then
              Dec(K, BucketSize + 1)
            Else
              Dec(K, BucketSize);
          End;
          V.IntVal := Bucket;
        End
        Else If FnName = 'PERCENT_RANK' Then
        Begin
          V.Category := SQLCAT_DECIMAL;
          V.XType    := XT_FLOAT;
          If PartSize <= 1 Then
            V.FloatVal := 0.0
          Else
            V.FloatVal := (RankVal - 1) / (PartSize - 1);
        End
        Else If FnName = 'CUME_DIST' Then
        Begin
          V.Category := SQLCAT_DECIMAL;
          V.XType    := XT_FLOAT;
          { Trouver la derniere ligne avec la meme cle d ordre }
          LastTie := J;
          While (LastTie + 1 < PartStart + PartSize) And
                (QEWinOrdKey(QEWinIdx[LastTie + 1]) = CurOrdKey) Do
            Inc(LastTie);
          If PartSize > 0 Then
            V.FloatVal := (LastTie - PartStart + 1) / PartSize
          Else
            V.FloatVal := 1.0;
        End
        Else If FnName = 'LAG' Then
        Begin
          LagOffset := 1;
          InitSqlValue(DefaultVal);
          DefaultVal.IsNull := True;
          DefaultVal.Valid := True;
          If ASTPool[FuncNode].ChildCnt > 1 Then
          Begin
            ArgNode := ASTPool[FuncNode].Children[1];
            If (ArgNode >= 0) And (ArgNode < ASTCount) Then
              Val(ASTPool[ArgNode].Text, LagOffset, K);
          End;
          If ASTPool[FuncNode].ChildCnt > 2 Then
          Begin
            ArgNode := ASTPool[FuncNode].Children[2];
            If (ArgNode >= 0) And (ArgNode < ASTCount) Then
              DefaultVal := QEEvalExpr(ArgNode,
                Res.Rows[QEWinIdx[J]], Res);
          End;
          TargetIdx := J - LagOffset;
          If (TargetIdx >= PartStart) And
             (TargetIdx < PartStart + PartSize) And
             (ArgExpr >= 0) Then
            V := QEEvalExpr(ArgExpr,
              Res.Rows[QEWinIdx[TargetIdx]], Res)
          Else
            V := DefaultVal;
        End
        Else If FnName = 'LEAD' Then
        Begin
          LagOffset := 1;
          InitSqlValue(DefaultVal);
          DefaultVal.IsNull := True;
          DefaultVal.Valid := True;
          If ASTPool[FuncNode].ChildCnt > 1 Then
          Begin
            ArgNode := ASTPool[FuncNode].Children[1];
            If (ArgNode >= 0) And (ArgNode < ASTCount) Then
              Val(ASTPool[ArgNode].Text, LagOffset, K);
          End;
          If ASTPool[FuncNode].ChildCnt > 2 Then
          Begin
            ArgNode := ASTPool[FuncNode].Children[2];
            If (ArgNode >= 0) And (ArgNode < ASTCount) Then
              DefaultVal := QEEvalExpr(ArgNode,
                Res.Rows[QEWinIdx[J]], Res);
          End;
          TargetIdx := J + LagOffset;
          If (TargetIdx >= PartStart) And
             (TargetIdx < PartStart + PartSize) And
             (ArgExpr >= 0) Then
            V := QEEvalExpr(ArgExpr,
              Res.Rows[QEWinIdx[TargetIdx]], Res)
          Else
            V := DefaultVal;
        End
        Else If FnName = 'FIRST_VALUE' Then
        Begin
          If (ArgExpr >= 0) And (PartSize > 0) Then
            V := QEEvalExpr(ArgExpr,
              Res.Rows[QEWinIdx[PartStart]], Res)
          Else
          Begin V.IsNull := True; V.Valid := True; End;
        End
        Else If FnName = 'LAST_VALUE' Then
        Begin
          If (ArgExpr >= 0) And (PartSize > 0) Then
            V := QEEvalExpr(ArgExpr,
              Res.Rows[QEWinIdx[PartStart + PartSize - 1]], Res)
          Else
          Begin V.IsNull := True; V.Valid := True; End;
        End
        Else If IsAggr Then
        Begin
          { Agregats en fenetre sur la partition entiere }
          SumVal := 0.0;
          CntVal := 0;
          InitSqlValue(MinVal); MinVal.IsNull := True;
          InitSqlValue(MaxVal); MaxVal.IsNull := True;
          For K := PartStart To PartStart + PartSize - 1 Do
          Begin
            If ArgExpr >= 0 Then
              TmpVal := QEEvalExpr(ArgExpr,
                Res.Rows[QEWinIdx[K]], Res)
            Else
            Begin
              InitSqlValue(TmpVal);
              TmpVal.IsNull := False;
              TmpVal.IntVal := 1;
              TmpVal.Category := SQLCAT_INTEGER;
            End;
            If Not TmpVal.IsNull Then
            Begin
              Inc(CntVal);
              If TmpVal.Category = SQLCAT_DECIMAL Then
                SumVal := SumVal + TmpVal.FloatVal
              Else
                SumVal := SumVal + TmpVal.IntVal;
              If MinVal.IsNull Then MinVal := TmpVal
              Else If QECompareValues(TmpVal, MinVal) < 0 Then
                MinVal := TmpVal;
              If MaxVal.IsNull Then MaxVal := TmpVal
              Else If QECompareValues(TmpVal, MaxVal) > 0 Then
                MaxVal := TmpVal;
            End;
          End;
          If FnName = 'COUNT' Then
          Begin
            V.Category := SQLCAT_INTEGER;
            V.XType := XT_INT;
            V.IntVal := CntVal;
          End
          Else If FnName = 'SUM' Then
          Begin
            V.Category := SQLCAT_DECIMAL;
            V.XType := XT_FLOAT;
            V.FloatVal := SumVal;
            If CntVal = 0 Then V.IsNull := True;
          End
          Else If FnName = 'AVG' Then
          Begin
            V.Category := SQLCAT_DECIMAL;
            V.XType := XT_FLOAT;
            If CntVal > 0 Then
              V.FloatVal := SumVal / CntVal
            Else
              V.IsNull := True;
          End
          Else If FnName = 'MIN' Then
            V := MinVal
          Else If FnName = 'MAX' Then
            V := MaxVal;
        End
        Else
        Begin
          { Fonction non reconnue }
          V.IsNull := True;
          V.Valid := True;
        End;

        { Stocker la valeur dans la ligne originale }
        If ColIdx < Res.ColCnt Then
          Res.Rows[QEWinIdx[J]].Vals[ColIdx] := V;
      End;
    End;

    Inc(ColIdx);
  End;
End;

{ ---- Executer un SELECT ------------------------------------- }

Procedure QEExecSelect(Root : Integer);
Var
  N          : Integer;
  TblNode    : Integer;
  WhereNode  : Integer;
  OrderNode  : Integer;
  TopNode    : Integer;
  GroupNode  : Integer;
  HavingNode : Integer;
  HasDistinct: Boolean;
  HasAggr    : Boolean;
  I, J, K    : Integer;
  TblName    : TTokenText;
  CI         : Integer;
  Row        : TQERow;
  V          : TSqlValue;
  TopN       : Integer;
  IsPercent  : Boolean;
  NbCols     : Integer;
  ProjCols   : Array[0..MAX_QE_COLS - 1] Of Integer;
  ProjNames  : Array[0..MAX_QE_COLS - 1] Of TQEColName;
  ProjAll    : Boolean;
  OrdCol     : Integer;
  OrdDesc    : Boolean;
  SrcRes     : TQEResult;
  JoinRes    : TQEResult;
  TmpRes     : TQEResult;
  OnNode     : Integer;
Begin
  If QERes = Nil Then New(QERes);
  QERes^.ColCnt := 0;
  QERes^.RowCnt := 0;

  If (Root < 0) Or (Root >= ASTCount) Then
  Begin
    OutputLine('-- Erreur : noeud SELECT invalide');
    Exit;
  End;

  If ASTPool[Root].Kind <> ND_SELECT_STMT Then
  Begin
    OutputLine('-- Erreur : noeud n''est pas un SELECT');
    Exit;
  End;

  { Extraire les sous-noeuds du SELECT }
  TblNode    := -1;
  WhereNode  := -1;
  OrderNode  := -1;
  TopNode    := -1;
  GroupNode  := -1;
  HavingNode := -1;
  HasDistinct := False;
  HasAggr    := False;

  { Verifier DISTINCT dans le texte du noeud SELECT }
  If StrUpperCase(ASTPool[Root].Text) = 'DISTINCT' Then
    HasDistinct := True;

  { Parcourir les enfants du SELECT }
  For I := 0 To ASTPool[Root].ChildCnt - 1 Do
  Begin
    N := ASTPool[Root].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    Case ASTPool[N].Kind Of
      ND_FROM_CLAUSE  : TblNode    := N;
      ND_WHERE_CLAUSE : WhereNode  := N;
      ND_ORDER_BY     : OrderNode  := N;
      ND_TOP_CLAUSE   : TopNode    := N;
      ND_GROUP_BY     : GroupNode  := N;
      ND_HAVING       : HavingNode := N;
    End;
  End;

  { Verifier qu on a un FROM }
  If TblNode < 0 Then
  Begin
    { SELECT sans FROM : evaluer les expressions directement }
    QERes^.ColCnt := 0;
    QERes^.RowCnt := 1;
    Row.ColCnt := 0;
    J := 0;
    For I := 0 To ASTPool[Root].ChildCnt - 1 Do
    Begin
      N := ASTPool[Root].Children[I];
      If (N < 0) Or (N >= ASTCount) Then Continue;
      If ASTPool[N].Kind = ND_SELECT_ITEM Then
      Begin
        If J < MAX_QE_COLS Then
        Begin
          V := QEEvalExpr(N, Row, QERes^);
          { Chercher alias }
          If ASTPool[N].ChildCnt > 0 Then
          Begin
            CI := ASTPool[N].Children[0];
            V := QEEvalExpr(CI, Row, QERes^);
          End;
          QERes^.Cols[J].Name := '(expr)';
          { Chercher un alias dans les enfants }
          For K := 0 To ASTPool[N].ChildCnt - 1 Do
          Begin
            CI := ASTPool[N].Children[K];
            If (CI >= 0) And (CI < ASTCount) And
               (ASTPool[CI].Kind = ND_ALIAS) Then
              QERes^.Cols[J].Name := ASTPool[CI].Text;
          End;
          QERes^.Cols[J].Width := Length(QERes^.Cols[J].Name);
          If QERes^.Cols[J].Width < 4 Then
            QERes^.Cols[J].Width := 4;
          QERes^.Rows[0].Vals[J] := V;
          Inc(J);
        End;
      End;
    End;
    QERes^.ColCnt := J;
    QERes^.Rows[0].ColCnt := J;
    QEFormatResult(QERes^);
    Exit;
  End;

  { Trouver le nom de la premiere table dans le FROM }
  TblName := '';
  For I := 0 To ASTPool[TblNode].ChildCnt - 1 Do
  Begin
    N := ASTPool[TblNode].Children[I];
    If (N >= 0) And (N < ASTCount) And
       (ASTPool[N].Kind = ND_TABLE_REF) Then
    Begin
      TblName := ASTPool[N].Text;
      { Si le nom est vide, chercher dans les enfants }
      If (TblName = '') And (ASTPool[N].ChildCnt > 0) Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) Then
          TblName := ASTPool[CI].Text;
      End;
      Break;
    End;
  End;

  If TblName = '' Then
  Begin
    OutputLine('-- Erreur : table introuvable dans le FROM');
    Exit;
  End;

  { Chercher la table dans le catalogue }
  If Not CatalogValid Then
  Begin
    OutputLine('-- Erreur : catalogue systeme non charge');
    Exit;
  End;

  { Charger la premiere table }
  If Not QELoadTable(TblName, SrcRes) Then
  Begin
    OutputLine('-- Erreur : table ''' + TblName + ''' introuvable');
    Exit;
  End;

  If Opts.Verbose Then
    OutputLine('-- Table scan : ' + IntToStr(SrcRes.RowCnt) +
               ' ligne(s) trouvee(s) dans ' + TblName);

  { ---- Traitement des JOINs (TODO 16) ---- }
  { Parcourir les enfants du FROM pour les jointures et les        }
  { tables supplementaires (virgule = CROSS JOIN implicite).       }
  For I := 0 To ASTPool[TblNode].ChildCnt - 1 Do
  Begin
    N := ASTPool[TblNode].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;

    { Tables supplementaires separees par virgule (CROSS JOIN) }
    If (ASTPool[N].Kind = ND_TABLE_REF) And (I > 0) Then
    Begin
      TblName := ASTPool[N].Text;
      If (TblName = '') And (ASTPool[N].ChildCnt > 0) Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) Then
          TblName := ASTPool[CI].Text;
      End;
      If TblName <> '' Then
      Begin
        If QELoadTable(TblName, JoinRes) Then
        Begin
          If Opts.Verbose Then
            OutputLine('-- Cross join avec ' + TblName +
                       ' (' + IntToStr(JoinRes.RowCnt) + ' ligne(s))');
          QECrossJoin(SrcRes, JoinRes, TmpRes);
          SrcRes := TmpRes;
        End;
      End;
    End;

    { Jointures explicites (INNER, LEFT, RIGHT, FULL, CROSS JOIN) }
    If ASTPool[N].Kind = ND_JOIN Then
    Begin
      { La table a joindre est le premier enfant du ND_JOIN }
      If ASTPool[N].ChildCnt > 0 Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) And
           (ASTPool[CI].Kind = ND_TABLE_REF) Then
        Begin
          TblName := ASTPool[CI].Text;
          If (TblName = '') And (ASTPool[CI].ChildCnt > 0) Then
          Begin
            K := ASTPool[CI].Children[0];
            If (K >= 0) And (K < ASTCount) Then
              TblName := ASTPool[K].Text;
          End;
          If (TblName <> '') And QELoadTable(TblName, JoinRes) Then
          Begin
            { Determiner la condition ON (deuxieme enfant) }
            OnNode := -1;
            If ASTPool[N].ChildCnt > 1 Then
            Begin
              OnNode := ASTPool[N].Children[1];
              If (OnNode < 0) Or (OnNode >= ASTCount) Then
                OnNode := -1;
            End;
            If Opts.Verbose Then
              OutputLine('-- ' + ASTPool[N].Text + ' avec ' + TblName +
                         ' (' + IntToStr(JoinRes.RowCnt) + ' ligne(s))');
            QEExecJoin(SrcRes, JoinRes, OnNode, ASTPool[N].Text, TmpRes);
            SrcRes := TmpRes;
          End;
        End;
      End;
    End;

    { CROSS APPLY / OUTER APPLY }
    If ASTPool[N].Kind = ND_APPLY Then
    Begin
      If ASTPool[N].ChildCnt > 0 Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) And
           (ASTPool[CI].Kind = ND_TABLE_REF) Then
        Begin
          TblName := ASTPool[CI].Text;
          If (TblName = '') And (ASTPool[CI].ChildCnt > 0) Then
          Begin
            K := ASTPool[CI].Children[0];
            If (K >= 0) And (K < ASTCount) Then
              TblName := ASTPool[K].Text;
          End;
          If (TblName <> '') And QELoadTable(TblName, JoinRes) Then
          Begin
            If Opts.Verbose Then
              OutputLine('-- ' + ASTPool[N].Text + ' avec ' + TblName +
                         ' (' + IntToStr(JoinRes.RowCnt) + ' ligne(s))');
            If Pos('OUTER', StrUpperCase(ASTPool[N].Text)) > 0 Then
              QENestedLoopJoin(SrcRes, JoinRes, -1, 'LEFT', TmpRes)
            Else
              QECrossJoin(SrcRes, JoinRes, TmpRes);
            SrcRes := TmpRes;
          End;
        End;
      End;
    End;
  End;

  { Appliquer le filtre WHERE }
  If WhereNode >= 0 Then
  Begin
    If ASTPool[WhereNode].ChildCnt > 0 Then
    Begin
      N := ASTPool[WhereNode].Children[0];
      J := 0;
      For I := 0 To SrcRes.RowCnt - 1 Do
      Begin
        If QEEvalBool(N, SrcRes.Rows[I], SrcRes) Then
        Begin
          If J <> I Then
            SrcRes.Rows[J] := SrcRes.Rows[I];
          Inc(J);
        End;
      End;
      SrcRes.RowCnt := J;
    End;
  End;

  { Detecter si des agregats sont utilises dans les SELECT items }
  If GroupNode < 0 Then
  Begin
    For I := 0 To ASTPool[Root].ChildCnt - 1 Do
    Begin
      N := ASTPool[Root].Children[I];
      If (N >= 0) And (N < ASTCount) And
         (ASTPool[N].Kind = ND_SELECT_ITEM) Then
      Begin
        If ASTPool[N].ChildCnt > 0 Then
        Begin
          If QEHasAggregate(ASTPool[N].Children[0]) Then
          Begin
            HasAggr := True;
            Break;
          End;
        End;
      End;
    End;
  End
  Else
    HasAggr := True;

  { GROUP BY / Agregation (TODO 17) }
  If (GroupNode >= 0) Or HasAggr Then
  Begin
    QEExecGroupBy(SrcRes, Root, GroupNode, HavingNode);
    { QEExecGroupBy a ecrit dans QERes^, continuer avec ORDER BY etc. }
    { Copier le resultat dans SrcRes pour la suite du pipeline }
    SrcRes.ColCnt := QERes^.ColCnt;
    For J := 0 To QERes^.ColCnt - 1 Do
      SrcRes.Cols[J] := QERes^.Cols[J];
    SrcRes.RowCnt := QERes^.RowCnt;
    For I := 0 To QERes^.RowCnt - 1 Do
      SrcRes.Rows[I] := QERes^.Rows[I];

    { Copier directement dans QERes pour la suite }
    { (pas besoin de reprojeter, QEExecGroupBy l a deja fait) }

    { ORDER BY : trier le result set }
    If OrderNode >= 0 Then
    Begin
      If ASTPool[OrderNode].ChildCnt > 0 Then
      Begin
        N := ASTPool[OrderNode].Children[0];
        If (N >= 0) And (N < ASTCount) And
           (ASTPool[N].Kind = ND_ORDER_ITEM) Then
        Begin
          OrdDesc := (StrUpperCase(ASTPool[N].Text) = 'DESC');
          OrdCol := -1;
          If ASTPool[N].ChildCnt > 0 Then
          Begin
            CI := ASTPool[N].Children[0];
            If (CI >= 0) And (CI < ASTCount) Then
              OrdCol := QEFindColByName(ASTPool[CI].Text, QERes^);
          End;
          If (OrdCol >= 0) And (QERes^.RowCnt > 1) Then
          Begin
            QESortCol  := OrdCol;
            QESortDesc := OrdDesc;
            QEQuickSort(QERes^, 0, QERes^.RowCnt - 1);
          End;
        End;
      End;
    End;

    { DISTINCT : eliminer les doublons }
    If HasDistinct And (QERes^.RowCnt > 1) Then
    Begin
      If QERes^.ColCnt > 0 Then
      Begin
        QESortCol  := 0;
        QESortDesc := False;
        QEQuickSort(QERes^, 0, QERes^.RowCnt - 1);
      End;
      QEDistinct(QERes^);
    End;

    { TOP n : limiter le nombre de lignes }
    If TopNode >= 0 Then
    Begin
      TopN := 0;
      IsPercent := (StrUpperCase(ASTPool[TopNode].Text) = 'PERCENT');
      If ASTPool[TopNode].ChildCnt > 0 Then
      Begin
        N := ASTPool[TopNode].Children[0];
        If (N >= 0) And (N < ASTCount) Then
          Val(ASTPool[N].Text, TopN, CI);
      End
      Else
        Val(ASTPool[TopNode].Text, TopN, CI);
      If IsPercent Then
        TopN := (QERes^.RowCnt * TopN + 99) Div 100;
      If (TopN >= 0) And (TopN < QERes^.RowCnt) Then
        QERes^.RowCnt := TopN;
    End;

    { Afficher le result set }
    QEFormatResult(QERes^);
    Exit;
  End;

  { Determiner la projection (colonnes SELECT) }
  NbCols := 0;
  ProjAll := False;
  For I := 0 To ASTPool[Root].ChildCnt - 1 Do
  Begin
    N := ASTPool[Root].Children[I];
    If (N < 0) Or (N >= ASTCount) Then Continue;
    If ASTPool[N].Kind = ND_SELECT_ITEM Then
    Begin
      If NbCols >= MAX_QE_COLS Then Break;
      { Verifier si c est un * (SELECT *) }
      If (ASTPool[N].ChildCnt > 0) Then
      Begin
        CI := ASTPool[N].Children[0];
        If (CI >= 0) And (CI < ASTCount) And
           (ASTPool[CI].Kind = ND_STAR) Then
        Begin
          ProjAll := True;
          Break;
        End;
        { Chercher le nom de la colonne }
        If ASTPool[CI].Kind = ND_IDENT Then
        Begin
          ProjCols[NbCols] := QEFindColByName(ASTPool[CI].Text, SrcRes);
          ProjNames[NbCols] := ASTPool[CI].Text;
          { Chercher alias }
          For K := 0 To ASTPool[N].ChildCnt - 1 Do
          Begin
            J := ASTPool[N].Children[K];
            If (J >= 0) And (J < ASTCount) And
               (ASTPool[J].Kind = ND_ALIAS) Then
              ProjNames[NbCols] := ASTPool[J].Text;
          End;
          Inc(NbCols);
        End
        Else If ASTPool[CI].Kind = ND_DOT_REF Then
        Begin
          { table.colonne : utiliser le dernier enfant }
          If ASTPool[CI].ChildCnt > 0 Then
          Begin
            J := ASTPool[CI].Children[ASTPool[CI].ChildCnt - 1];
            If (J >= 0) And (J < ASTCount) Then
            Begin
              ProjCols[NbCols] := QEFindColByName(ASTPool[J].Text,
                                                    SrcRes);
              ProjNames[NbCols] := ASTPool[J].Text;
            End;
          End
          Else
          Begin
            ProjCols[NbCols] := -1;
            ProjNames[NbCols] := '(expr)';
          End;
          Inc(NbCols);
        End
        Else
        Begin
          { Expression calculee }
          ProjCols[NbCols] := -1;
          ProjNames[NbCols] := '(expr)';
          { Chercher alias }
          For K := 0 To ASTPool[N].ChildCnt - 1 Do
          Begin
            J := ASTPool[N].Children[K];
            If (J >= 0) And (J < ASTCount) And
               (ASTPool[J].Kind = ND_ALIAS) Then
              ProjNames[NbCols] := ASTPool[J].Text;
          End;
          Inc(NbCols);
        End;
      End
      Else
      Begin
        { SELECT item sans enfant, essayer le texte du noeud }
        If ASTPool[N].Text = '*' Then
        Begin
          ProjAll := True;
          Break;
        End;
        ProjCols[NbCols] := QEFindColByName(ASTPool[N].Text, SrcRes);
        ProjNames[NbCols] := ASTPool[N].Text;
        Inc(NbCols);
      End;
    End;
  End;

  { Construire le result set projete }
  If ProjAll Then
  Begin
    { SELECT * : copier toutes les colonnes }
    QERes^.ColCnt := SrcRes.ColCnt;
    For J := 0 To SrcRes.ColCnt - 1 Do
      QERes^.Cols[J] := SrcRes.Cols[J];
    QERes^.RowCnt := SrcRes.RowCnt;
    For I := 0 To SrcRes.RowCnt - 1 Do
      QERes^.Rows[I] := SrcRes.Rows[I];
  End
  Else If NbCols > 0 Then
  Begin
    QERes^.ColCnt := NbCols;
    For J := 0 To NbCols - 1 Do
    Begin
      If ProjCols[J] >= 0 Then
        QERes^.Cols[J] := SrcRes.Cols[ProjCols[J]]
      Else
      Begin
        QERes^.Cols[J].Name   := ProjNames[J];
        QERes^.Cols[J].XType  := 0;
        QERes^.Cols[J].MaxLen := 0;
        QERes^.Cols[J].Prec   := 0;
        QERes^.Cols[J].Scale  := 0;
        QERes^.Cols[J].ColIdx := -1;
        QERes^.Cols[J].Width  := Length(ProjNames[J]);
      End;
      QERes^.Cols[J].Name := ProjNames[J];
    End;
    QERes^.RowCnt := SrcRes.RowCnt;
    For I := 0 To SrcRes.RowCnt - 1 Do
    Begin
      QERes^.Rows[I].ColCnt := NbCols;
      For J := 0 To NbCols - 1 Do
      Begin
        If ProjCols[J] >= 0 Then
          QERes^.Rows[I].Vals[J] := SrcRes.Rows[I].Vals[ProjCols[J]]
        Else
        Begin
          { Evaluer l expression }
          N := ASTPool[Root].Children[0]; { premier SELECT_ITEM }
          K := 0;
          For CI := 0 To ASTPool[Root].ChildCnt - 1 Do
          Begin
            N := ASTPool[Root].Children[CI];
            If (N >= 0) And (N < ASTCount) And
               (ASTPool[N].Kind = ND_SELECT_ITEM) Then
            Begin
              If K = J Then
              Begin
                If ASTPool[N].ChildCnt > 0 Then
                  QERes^.Rows[I].Vals[J] :=
                    QEEvalExpr(ASTPool[N].Children[0],
                               SrcRes.Rows[I], SrcRes);
                Break;
              End;
              Inc(K);
            End;
          End;
        End;
      End;
    End;
  End
  Else
  Begin
    { Pas de colonnes trouvees, copier tout }
    QERes^.ColCnt := SrcRes.ColCnt;
    For J := 0 To SrcRes.ColCnt - 1 Do
      QERes^.Cols[J] := SrcRes.Cols[J];
    QERes^.RowCnt := SrcRes.RowCnt;
    For I := 0 To SrcRes.RowCnt - 1 Do
      QERes^.Rows[I] := SrcRes.Rows[I];
  End;

  { ORDER BY : trier le result set }
  If OrderNode >= 0 Then
  Begin
    If ASTPool[OrderNode].ChildCnt > 0 Then
    Begin
      N := ASTPool[OrderNode].Children[0];
      If (N >= 0) And (N < ASTCount) And
         (ASTPool[N].Kind = ND_ORDER_ITEM) Then
      Begin
        OrdDesc := (StrUpperCase(ASTPool[N].Text) = 'DESC');
        OrdCol := -1;
        If ASTPool[N].ChildCnt > 0 Then
        Begin
          CI := ASTPool[N].Children[0];
          If (CI >= 0) And (CI < ASTCount) Then
            OrdCol := QEFindColByName(ASTPool[CI].Text, QERes^);
        End;
        If (OrdCol >= 0) And (QERes^.RowCnt > 1) Then
        Begin
          QESortCol  := OrdCol;
          QESortDesc := OrdDesc;
          QEQuickSort(QERes^, 0, QERes^.RowCnt - 1);
        End;
      End;
    End;
  End;

  { DISTINCT : eliminer les doublons }
  If HasDistinct And (QERes^.RowCnt > 1) Then
  Begin
    { Trier d abord par la premiere colonne pour grouper les doublons }
    If QERes^.ColCnt > 0 Then
    Begin
      QESortCol  := 0;
      QESortDesc := False;
      QEQuickSort(QERes^, 0, QERes^.RowCnt - 1);
    End;
    QEDistinct(QERes^);
  End;

  { TOP n : limiter le nombre de lignes }
  If TopNode >= 0 Then
  Begin
    TopN := 0;
    IsPercent := (StrUpperCase(ASTPool[TopNode].Text) = 'PERCENT');
    If ASTPool[TopNode].ChildCnt > 0 Then
    Begin
      N := ASTPool[TopNode].Children[0];
      If (N >= 0) And (N < ASTCount) Then
        Val(ASTPool[N].Text, TopN, CI);
    End
    Else
      Val(ASTPool[TopNode].Text, TopN, CI);
    If IsPercent Then
      TopN := (QERes^.RowCnt * TopN + 99) Div 100;
    If (TopN >= 0) And (TopN < QERes^.RowCnt) Then
      QERes^.RowCnt := TopN;
  End;

  { Afficher le result set }
  QEFormatResult(QERes^);
End;

{ ---- Execution d une requete SQL ----------------------------- }

Procedure ExecuteQuery(Const SQL : TString);
Var
  Root : Integer;
Begin
  LexInit(SQL);
  LexNextToken;
  ASTInit;
  { Detecter le type d instruction }
  If KwIs(KW_SELECT) Or KwIs(KW_WITH) Then
    Root := ParseSelectStmt
  Else If KwIs(KW_INSERT) Then
    Root := ParseInsertStmt
  Else If KwIs(KW_UPDATE) Then
    Root := ParseUpdateStmt
  Else If KwIs(KW_DELETE) Then
    Root := ParseDeleteStmt
  Else If KwIs(KW_TRUNCATE) Then
    Root := ParseTruncateStmt
  Else If KwIs(KW_MERGE) Then
    Root := ParseMergeStmt
  Else If KwIs(KW_CREATE) Then
    Root := ParseCreateStmt
  Else If KwIs(KW_ALTER) Then
    Root := ParseAlterStmt
  Else If KwIs(KW_DROP) Then
    Root := ParseDropStmt
  { DCL (TODO 14) }
  Else If KwIs(KW_GRANT) Then
    Root := ParseGrantStmt
  Else If KwIs(KW_REVOKE) Then
    Root := ParseRevokeStmt
  Else If KwIs(KW_DENY) Then
    Root := ParseDenyStmt
  { T-SQL control flow (TODO 13) }
  Else If KwIs(KW_DECLARE) Then
    Root := ParseDeclareStmt
  Else If KwIs(KW_SET) Then
    Root := ParseSetStmt
  Else If KwIs(KW_IF) Then
    Root := ParseIfStmt
  Else If KwIs(KW_WHILE) Then
    Root := ParseWhileStmt
  Else If KwIs(KW_BEGIN) Then
    Root := ParseBlockStmt
  Else If KwIs(KW_RETURN) Then
    Root := ParseReturnStmt
  Else If KwIs(KW_WAITFOR) Then
    Root := ParseWaitforStmt
  Else If KwIs(KW_THROW) Then
    Root := ParseThrowStmt
  Else If KwIs(KW_RAISERROR) Then
    Root := ParseRaiserrorStmt
  Else If KwIs(KW_PRINT) Then
    Root := ParsePrintStmt
  Else If KwIs(KW_EXEC) Or KwIs(KW_EXECUTE) Then
    Root := ParseExecStmt
  Else If KwIs(KW_USE) Then
    Root := ParseUseStmt
  Else If KwIs(KW_GO) Then
    Root := ParseGoStmt
  Else If KwIs(KW_BREAK) Then
  Begin
    Root := NewNode(ND_BREAK_STMT, 'BREAK', LexCurTok.Line, LexCurTok.Col);
    Advance;
  End
  Else If KwIs(KW_CONTINUE) Then
  Begin
    Root := NewNode(ND_CONTINUE_STMT, 'CONTINUE', LexCurTok.Line,
                    LexCurTok.Col);
    Advance;
  End
  Else If KwIs(KW_GOTO) Then
  Begin
    Advance;
    If (LexCurTok.Kind = TOK_IDENT) Or (LexCurTok.Kind = TOK_KEYWORD) Then
    Begin
      Root := NewNode(ND_GOTO_STMT, LexCurTok.Text, LexCurTok.Line,
                      LexCurTok.Col);
      Advance;
    End
    Else
      Root := -1;
  End
  Else
    Root := ParseSqlExpr;
  If ParseOk And (Root >= 0) Then
  Begin
    If Opts.Verbose Then
    Begin
      OutputLine('-- AST :');
      DumpExpr(Root, 0);
    End;
    { Executer le SELECT via le moteur de requetes (TODO 15) }
    If ASTPool[Root].Kind = ND_SELECT_STMT Then
      QEExecSelect(Root);
    { Executer les operateurs ensemblistes (TODO 16) }
    If (ASTPool[Root].Kind = ND_UNION) Or
       (ASTPool[Root].Kind = ND_INTERSECT_OP) Or
       (ASTPool[Root].Kind = ND_EXCEPT_OP) Then
      QEExecSetOp(Root);
  End
  Else
    OutputLine('-- Erreur de syntaxe dans : ' + SQL);
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
  CloseMdfFile;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  If QERes <> Nil Then
  Begin
    Dispose(QERes);
    QERes := Nil;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  OutFOpen   := False;
  MdfOpen    := False;
  MdfPageCnt := 0;
  BootInfo.Valid := False;
  SysObjCount  := 0;
  SysColCount  := 0;
  SysIdxCount  := 0;
  SysIcCount   := 0;
  SysRsCount   := 0;
  CatalogValid := False;
  QERes        := Nil;

  ParseArgs;

  If Opts.Verbose Then
    ShowBanner;

  If Opts.Verbose Then
    WriteLn('  Fichier MDF : ', Opts.MdfFile);

  { Ouvrir et lire l en-tete du fichier MDF (TODO 02) }
  OpenMdfFile(Opts.MdfFile);
  ReadBootPage;

  If BootInfo.Valid Then
  Begin
    If Opts.Verbose Then
      WriteLn('  Base de donnees : ', BootInfo.DbName);
  End
  Else
    WarnMsg('boot page non valide, fonctionnement degrade');

  { Lire les allocation maps (TODO 03) }
  ReadAllocationMaps;

  { Scanner les pages de donnees (TODO 04) }
  ScanDataPages;

  { Lire le catalogue systeme (TODO 05) }
  ReadSystemCatalog;

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
