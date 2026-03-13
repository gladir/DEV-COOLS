PROGRAM TestStrings;
VAR
  s1, s2, s3: STRING;
  n: INTEGER;
  c: CHAR;
BEGIN
  { Test Length }
  s1 := 'Hello';
  WriteLn('Length test:');
  n := Length(s1);
  WriteLn(n);

  { Test Concatenation with + }
  WriteLn('Concat test:');
  s2 := 'Hello' + ' ' + 'World';
  WriteLn(s2);

  { Test Copy }
  WriteLn('Copy test:');
  s1 := 'ABCDEF';
  s3 := Copy(s1, 2, 3);
  WriteLn(s3);

  { Test Pos }
  WriteLn('Pos test:');
  s1 := 'Hello World';
  n := Pos('World', s1);
  WriteLn(n);

  { Test Upcase }
  WriteLn('Upcase test:');
  c := Upcase('a');
  Write(c);
  WriteLn;

  { Test Concat function }
  WriteLn('Concat func:');
  s1 := Concat('AB', 'CD', 'EF');
  WriteLn(s1);

  { Test string comparison }
  WriteLn('Compare test:');
  s1 := 'ABC';
  s2 := 'ABC';
  IF s1 = s2 THEN
    WriteLn('Equal')
  ELSE
    WriteLn('Not equal');

  s2 := 'DEF';
  IF s1 < s2 THEN
    WriteLn('Less')
  ELSE
    WriteLn('Not less');

  { Test Str and Val }
  WriteLn('Str/Val test:');
  Str(42, s1);
  WriteLn(s1);
  Val(s1, n, n);
  WriteLn(n);

  WriteLn('Done');
END.
