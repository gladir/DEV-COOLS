program test_overlay;
uses Overlay;
var
  buf_size: longint;
begin
  OvrInit('MYPROG.OVR');
  if OvrResult <> ovrOk then
    writeln('Overlay init failed')
  else
    writeln('Overlay initialized');
  OvrInitEMS;
  buf_size := OvrGetBuf;
  writeln('Buffer size: ', buf_size);
  OvrSetBuf(4096);
  OvrSetRetry(2048);
  OvrClearBuf;
  writeln('OvrResult = ', OvrResult);
  writeln('ovrOk = ', ovrOk);
  writeln('ovrError = ', ovrError);
  writeln('ovrNotFound = ', ovrNotFound);
  writeln('ovrNoMemory = ', ovrNoMemory);
  writeln('ovrIOError = ', ovrIOError);
  writeln('ovrNoEMSDriver = ', ovrNoEMSDriver);
  writeln('ovrNoEMSMemory = ', ovrNoEMSMemory);
end.
