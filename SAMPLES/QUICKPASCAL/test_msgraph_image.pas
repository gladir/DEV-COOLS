{ test_msgraph_image.pas - Test MSGraph image functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_image.pas }
{ Teste : _GetImage, _GetImage_w, _GetImage_wxy, _PutImage,  }
{         _PutImage_w, _ImageSize, _ImageSize_w, _ImageSize_wxy }

Program TestMSGraphImage;

Uses MSGraph;

Var
  R : Integer;
  Buf : Integer;

Begin
  { _ImageSize(x1,y1,x2,y2) }
  R := _ImageSize(0, 0, 100, 100);
  WriteLn('_ImageSize(0,0,100,100)=', R);

  { _ImageSize_w - stub }
  R := _ImageSize_w(0, 0, 100, 100);
  WriteLn('_ImageSize_w=', R);

  { _ImageSize_wxy - stub }
  R := _ImageSize_wxy(0, 0, 100, 100);
  WriteLn('_ImageSize_wxy=', R);

  { _GetImage(x1,y1,x2,y2,var image) }
  _GetImage(0, 0, 10, 10, Buf);
  WriteLn('_GetImage done');

  { _GetImage_w(x1,y1,x2,y2,var image) }
  _GetImage_w(0, 0, 10, 10, Buf);
  WriteLn('_GetImage_w done');

  { _GetImage_wxy(x1,y1,x2,y2,var image) }
  _GetImage_wxy(0, 0, 10, 10, Buf);
  WriteLn('_GetImage_wxy done');

  { _PutImage(x,y,var image,action) }
  _PutImage(0, 0, Buf, _GPSet);
  WriteLn('_PutImage done');

  { _PutImage_w(wx,wy,var image,action) }
  _PutImage_w(0, 0, Buf, _GPSet);
  WriteLn('_PutImage_w done');

  WriteLn('OK');
End.
