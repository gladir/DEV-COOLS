PROGRAM test_records(OUTPUT);

{ Test TODO 15 - RECORDS : types record, WITH, variant records,
  field attributes, acces aux champs }

TYPE
  { Record simple }
  TPoint = RECORD
    x : INTEGER;
    y : INTEGER;
  END;

  { Record imbrique }
  TRect = RECORD
    TopLeft : TPoint;
    BottomRight : TPoint;
    Color : INTEGER;
  END;

  { PACKED RECORD }
  TPackedRec = PACKED RECORD
    Flag : BOOLEAN;
    Value : INTEGER;
  END;

  { Variant record avec CASE }
  TShape = RECORD
    Kind : INTEGER;
    Name : INTEGER;
    CASE tag : INTEGER OF
      1 : (Radius : INTEGER);
      2 : (Width : INTEGER; Height : INTEGER);
      3 : (Side : INTEGER);
  END;

  { Variant record avec OTHERS }
  TVariant = RECORD
    Code : INTEGER;
    CASE sel : INTEGER OF
      0 : (IntVal : INTEGER);
      1 : (CharVal : CHAR);
      OTHERS : (RawVal : INTEGER);
  END;

  { Record avec attributs VAX }
  TAligned = RECORD
    [ALIGNED(2)] First : INTEGER;
    [READONLY] Status : INTEGER;
    Data : INTEGER;
  END;

VAR
  p1, p2 : TPoint;
  r : TRect;
  pk : TPackedRec;
  sh : TShape;
  v : TVariant;
  al : TAligned;

BEGIN
  { Affectation champ simple }
  p1.x := 10;
  p1.y := 20;
  WriteLn('p1.x = ', p1.x);
  WriteLn('p1.y = ', p1.y);

  { Copie champ a champ }
  p2.x := p1.x;
  p2.y := p1.y;
  WriteLn('p2.x = ', p2.x);

  { Record imbrique }
  r.Color := 7;
  WriteLn('r.Color = ', r.Color);

  { PACKED RECORD }
  pk.Value := 42;
  WriteLn('pk.Value = ', pk.Value);

  { WITH simple }
  WITH p1 DO BEGIN
    x := 100;
    y := 200;
  END;
  WriteLn('After WITH: p1.x = ', p1.x);
  WriteLn('After WITH: p1.y = ', p1.y);

  { WITH multiple }
  WITH p1, p2 DO BEGIN
    x := 50;
    y := 60;
  END;

  { Variant record }
  sh.Kind := 1;
  WriteLn('sh.Kind = ', sh.Kind);

  { Record avec attributs }
  al.First := 1;
  al.Status := 0;
  al.Data := 99;
  WriteLn('al.Data = ', al.Data);

  WriteLn('Records test OK');
END.
