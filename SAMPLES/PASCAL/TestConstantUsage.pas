PROGRAM TestConstantUsage;
CONST
  MAX_SIZE = 100;
  DEBUG_MODE = TRUE;
VAR
  Size: INTEGER;
  IsEnabled: BOOLEAN;
BEGIN
  Size := MAX_SIZE;
  IsEnabled := DEBUG_MODE;
  Write(Size);
  Write(IsEnabled);
END.