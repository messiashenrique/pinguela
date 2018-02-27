{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit Pinguela;

{$warn 5023 off : no warning about unused units}
interface

uses
  pingrid, pin_register, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('pin_register', @pin_register.Register);
end;

initialization
  RegisterPackage('Pinguela', @Register);
end.
