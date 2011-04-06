program WR;

uses
  Forms,
  XML_WR in 'XML_WR.pas' {Form1},
  wrdevice_unit in 'wrdevice_unit.pas',
  etherbone in '..\..\..\etherbone-core\api\etherbone.pas',
  device_setup in 'device_setup.pas' {DevSet_Form},
  Global in 'Global.pas',
  UserSendData in 'UserSendData.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDevSet_Form, DevSet_Form);
  Application.Run;
end.
