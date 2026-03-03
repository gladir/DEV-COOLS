PROGRAM Test;
VAR
  x, y: INTEGER;
  result: INTEGER;

BEGIN
  x := 10;
  y := 20;
  result := x;
  WRITELN(result);
  
  IF x > 5 THEN
    WRITELN(x)
  ELSE
    WRITELN(y);
    
  WHILE x > 0 DO
  BEGIN
    WRITELN(x);
    x := x - 1
  END
END.
