# Genere HELP\DEVENV\SQL.RTF a partir de DOC\SQL_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\SQL_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'SQL introduction;Transact-SQL;T-SQL;SQL Server;Codd;modele relationnel;ANSI SQL-86;ISO;SQL:1999;SQL:2023;Sybase'
  2  = 'SQL lexical;commentaires;identificateurs;mots reserves;litteraux;chaines;dates;NULL'
  3  = 'SQL types donnees;INT BIGINT SMALLINT TINYINT;DECIMAL NUMERIC FLOAT REAL;CHAR VARCHAR NVARCHAR;DATE DATETIME DATETIME2;BIT;UNIQUEIDENTIFIER;XML'
  4  = 'SQL expressions;CASE;COALESCE NULLIF;ISNULL;CAST CONVERT;TRY_CAST'
  5  = 'SQL operateurs;arithmetiques;comparaison;LIKE BETWEEN IN IS NULL;logiques AND OR NOT;concatenation +;bit-a-bit'
  6  = 'SQL DML;SELECT;INSERT;UPDATE;DELETE;MERGE;OUTPUT;TOP;ORDER BY;OFFSET FETCH'
  7  = 'SQL DDL;CREATE TABLE;ALTER TABLE;DROP;TRUNCATE;CREATE INDEX;CREATE VIEW;CREATE SCHEMA;contraintes PRIMARY KEY FOREIGN KEY CHECK UNIQUE DEFAULT'
  8  = 'SQL DCL;GRANT;REVOKE;DENY;permissions;roles'
  9  = 'SQL controle flux T-SQL;DECLARE;SET;IF ELSE;WHILE;BREAK CONTINUE;BEGIN END;GOTO;RETURN;WAITFOR;PRINT;variables locales'
  10 = 'SQL transactions;BEGIN TRANSACTION;COMMIT;ROLLBACK;SAVE TRANSACTION;niveaux isolation;READ COMMITTED;SERIALIZABLE;SNAPSHOT;XACT_ABORT'
  11 = 'SQL fonctions integrees;chaines LEN SUBSTRING REPLACE UPPER LOWER LTRIM RTRIM;dates GETDATE DATEADD DATEDIFF YEAR MONTH DAY;numeriques ABS ROUND CEILING FLOOR;conversion CAST CONVERT'
  12 = 'SQL agregation;COUNT SUM AVG MIN MAX;STDEV VAR;GROUP BY;HAVING;ROLLUP CUBE GROUPING SETS;DISTINCT'
  13 = 'SQL window functions;OVER PARTITION BY ORDER BY;ROW_NUMBER RANK DENSE_RANK NTILE;LEAD LAG FIRST_VALUE LAST_VALUE;ROWS RANGE BETWEEN'
  14 = 'SQL sous-requetes CTE;subquery;EXISTS;IN ANY ALL;WITH;CTE;recursive CTE;table derivee'
  15 = 'SQL jointures;INNER JOIN;LEFT OUTER JOIN;RIGHT OUTER JOIN;FULL OUTER JOIN;CROSS JOIN;CROSS APPLY;OUTER APPLY;self-join'
  16 = 'SQL ensemblistes;UNION;UNION ALL;INTERSECT;EXCEPT'
  17 = 'SQL curseurs;DECLARE CURSOR;OPEN;FETCH;CLOSE;DEALLOCATE;STATIC DYNAMIC SCROLL FORWARD_ONLY'
  18 = 'SQL procedures stockees fonctions;CREATE PROCEDURE;EXECUTE EXEC;parametres OUTPUT;CREATE FUNCTION;scalar function;table-valued function;RETURNS'
  19 = 'SQL triggers declencheurs;CREATE TRIGGER;AFTER INSTEAD OF;INSERTED DELETED;DDL trigger;LOGON trigger'
  20 = 'SQL gestion erreurs;TRY CATCH;THROW;RAISERROR;ERROR_NUMBER ERROR_MESSAGE ERROR_LINE;@@ERROR'
  21 = 'SQL XML JSON;FOR XML;PATH RAW AUTO EXPLICIT;FOR JSON;PATH AUTO;OPENJSON;OPENXML'
  22 = 'SQL exemples'
  23 = 'SQL SQLCMD limitations;SQLCMD.PAS;sous-ensemble;lecture MDF;contraintes implementation'
  24 = 'SQL projet DEV-COOLS;CSV2SQL.PAS;DBF2SQL.PAS;SQLCMD.PAS;harddisk.sql;master.mdf'
}

$titles = @{}
for ($k = 1; $k -lt $N - 1; $k++) {
  if ($src[$k-1] -match '^={3,}\s*$' -and
      $src[$k+1] -match '^={3,}\s*$' -and
      $src[$k]   -match '^\s*(\d+)\.\s+(.+?)\s*$') {
    $tNum = [int]$Matches[1]; $tTit = $Matches[2].Trim()
    $titles[$tNum] = $tTit
  }
}
$totalSecs = ($titles.Keys | Measure-Object -Maximum).Maximum

function EmitNav($sb, [int]$cur, [int]$total) {
  [void]$sb.AppendLine('\par')
  $parts = @()
  if ($cur -gt 1) {
    $prev = 'IDH_SQL_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_SQL_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_SQL_01}'
  }
  $parts += '{\uldb Retour aux langages}{\v IDH_LANGAGES}'
  [void]$sb.AppendLine(($parts -join '     ') + '\par')
}

function EmitTOC($sb, $titles, [int]$total) {
  [void]$sb.AppendLine('\par')
  [void]$sb.AppendLine('\b Sections suivantes : \b0\par')
  [void]$sb.AppendLine('\par')
  for ($n = 2; $n -le $total; $n++) {
    if (-not $titles.ContainsKey($n)) { continue }
    $id = 'IDH_SQL_{0:D2}' -f $n
    $lbl = ('{0,2}. {1}' -f $n, $titles[$n])
    [void]$sb.AppendLine('{\f1 ' + (Esc $lbl) + '}     {\uldb [Aller]}{\v ' + $id + '}\par')
  }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('{\rtf1\ansi\deff0')
[void]$sb.AppendLine('{\fonttbl{\f0\fswiss Helvetica;}{\f1\fmodern Courier New;}}')
[void]$sb.AppendLine('')

$i = 0
$inTopic = $false
$curSec = 0

while ($i -lt $N) {
  $line = $src[$i]

  if ($i+2 -lt $N -and
      $src[$i]   -match '^={3,}\s*$' -and
      $src[$i+2] -match '^={3,}\s*$' -and
      $src[$i+1] -match '^\s*(\d+)\.\s+(.+?)\s*$') {
    $secNum = [int]$Matches[1]
    $secTitle = $Matches[2].Trim()
    if ($inTopic) {
      if ($curSec -eq 1) { EmitTOC $sb $titles $totalSecs }
      EmitNav $sb $curSec $totalSecs
      [void]$sb.AppendLine('\page')
      [void]$sb.AppendLine('')
    }
    $id = 'IDH_SQL_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' SQL - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'SQL' }
    [void]$sb.AppendLine('{\footnote K ' + $kw + '}')
    [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
    [void]$sb.AppendLine('\par')
    $i += 3
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    $inTopic = $true
    $curSec = $secNum
    continue
  }

  if (-not $inTopic) { $i++; continue }

  if ($i+1 -lt $N -and $src[$i+1] -match '^\s*-{3,}\s*$' -and
      $line -match '^\s*(\d+\.\d+)\s+(.+?)\s*$') {
    [void]$sb.AppendLine('\par')
    [void]$sb.AppendLine('\b ' + (Esc $line.Trim()) + ' \b0\par')
    [void]$sb.AppendLine('\par')
    $i += 2
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    continue
  }

  if ($line -match '^\s*-{3,}\s*$' -or $line -match '^\s*={3,}\s*$') {
    $i++; continue
  }

  if ($line.Trim() -eq '') {
    [void]$sb.AppendLine('\par')
    $i++; continue
  }

  if ($line -match '^\s+\S') {
    $txt = $line -replace "`t", '    '
    $txt = Esc $txt
    [void]$sb.AppendLine('{\f1 ' + $txt + '}\par')
  } else {
    [void]$sb.AppendLine((Esc $line) + '\par')
  }
  $i++
}

[void]$sb.AppendLine('')
if ($inTopic) { EmitNav $sb $curSec $totalSecs }
[void]$sb.AppendLine('}')

$outPath = Join-Path $PSScriptRoot 'SQL.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
