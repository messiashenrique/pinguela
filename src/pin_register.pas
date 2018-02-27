unit pin_register;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, pingrid;

procedure Register;

implementation

procedure Register;
begin
  {.$I pinauthorize_icon.lrs}
  //RegisterComponents('Pinguela Components',[TPinAuthorize]);
  {$I pingrid_icon.lrs}
  RegisterComponents('Pinguela Components', [TPinGrid]);
  {.$I pinprogress_icon.lrs}
  //RegisterComponents('Pinguela Components',[TPinProgress]);
  {.$I pinappupdate_icon.lrs}
  //RegisterComponents('Pinguela Components', [TPinAppUpdate]);
  {.$I pingif_icon.lrs}
  //RegisterComponents('Pinguela Components',[TPinGif]);
  //RegisterComponents('Pinguela Components',[TPinGrid2]);
end;

end.

