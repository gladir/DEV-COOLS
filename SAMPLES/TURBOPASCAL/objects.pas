{ objects.pas - OBJECT, CONSTRUCTOR, VIRTUAL, INHERITED (TODO 25) }
program ObjectsDemo;

type
  PShape = ^TShape;
  TShape = object
    X, Y: Integer;
    constructor Init(AX, AY: Integer);
    function GetX: Integer;
    function GetY: Integer;
    function Area: Real; virtual;
    procedure Show; virtual;
  end;

  PCircle = ^TCircle;
  TCircle = object(TShape)
    Radius: Integer;
    constructor Init(AX, AY, ARadius: Integer);
    function Area: Real; virtual;
    procedure Show; virtual;
  end;

  PRectangle = ^TRectangle;
  TRectangle = object(TShape)
    Width, Height: Integer;
    constructor Init(AX, AY, AW, AH: Integer);
    function Area: Real; virtual;
    procedure Show; virtual;
  end;

constructor TShape.Init(AX, AY: Integer);
begin
  X := AX;
  Y := AY;
end;

function TShape.GetX: Integer;
begin
  GetX := X;
end;

function TShape.GetY: Integer;
begin
  GetY := Y;
end;

function TShape.Area: Real;
begin
  Area := 0.0;
end;

procedure TShape.Show;
begin
  WriteLn('Shape at (', X, ', ', Y, ')');
end;

constructor TCircle.Init(AX, AY, ARadius: Integer);
begin
  inherited Init(AX, AY);
  Radius := ARadius;
end;

function TCircle.Area: Real;
begin
  Area := 3.14159 * Radius * Radius;
end;

procedure TCircle.Show;
begin
  WriteLn('Circle at (', X, ', ', Y, ') R=', Radius,
          ' Area=', Area:8:2);
end;

constructor TRectangle.Init(AX, AY, AW, AH: Integer);
begin
  inherited Init(AX, AY);
  Width := AW;
  Height := AH;
end;

function TRectangle.Area: Real;
begin
  Area := Width * Height;
end;

procedure TRectangle.Show;
begin
  WriteLn('Rectangle at (', X, ', ', Y, ') ',
          Width, 'x', Height, ' Area=', Area:8:2);
end;

var
  C: TCircle;
  R: TRectangle;

begin
  C.Init(10, 20, 5);
  C.Show;

  R.Init(0, 0, 10, 20);
  R.Show;

  WriteLn('Circle area = ', C.Area:8:2);
  WriteLn('Rectangle area = ', R.Area:8:2);

  WriteLn('Done.');
end.
