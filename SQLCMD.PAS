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
  MAX_KEYWORDS    = 100;

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

  KW_COUNT        = 101;     { nombre total de mots-cles definis  }

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

  { Taille max du pool de noeuds AST }
  MAX_AST_NODES   = 512;

  { Taille max des enfants par noeud }
  MAX_AST_CHILDREN = 8;

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

{ ---- Execution d une requete SQL ----------------------------- }

Procedure ExecuteQuery(Const SQL : TString);
Var
  Root : Integer;
Begin
  LexInit(SQL);
  LexNextToken;
  ASTInit;
  Root := ParseSqlExpr;
  If ParseOk And (Root >= 0) Then
  Begin
    If Opts.Verbose Then
    Begin
      OutputLine('-- AST de l''expression :');
      DumpExpr(Root, 0);
    End;
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
