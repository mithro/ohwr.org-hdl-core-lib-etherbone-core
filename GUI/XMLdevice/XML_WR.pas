unit XML_WR;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, xmldom, XMLIntf, Menus, msxmldom, XMLDoc, ComCtrls, ExtCtrls,
  StdCtrls,wrdevice_unit, device_setup,etherbone,Global,UserSendData;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    TreeView1: TTreeView;
    Label1: TLabel;
    Panel2: TPanel;
    messages_ListBox: TListBox;
    Clear_Button: TButton;
    Panel3: TPanel;
    Panel4: TPanel;
    Label2: TLabel;
    DeviceActiv_Shape: TShape;
    Panel5: TPanel;
    SendData_Button: TButton;
    Button1: TButton;
    Panel6: TPanel;
    ShowXML_Button: TButton;
    Label3: TLabel;
    Timer1: TTimer;
    OpenDialog1: TOpenDialog;
    MainMenu1: TMainMenu;
    D1: TMenuItem;
    XMLLaden1: TMenuItem;
    Exit1: TMenuItem;
    Device1: TMenuItem;
    ConnectDevice1: TMenuItem;
    DisconnectDevice1: TMenuItem;
    Setup1: TMenuItem;
    XMLDocument1: TXMLDocument;
    Extras1: TMenuItem;
    SendManual1: TMenuItem;
    procedure SendManual1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    //procedure myCallback(var user: eb_user_data_t; var status: eb_status_t; var data:eb_data_t );
    procedure Timer1Timer(Sender: TObject);
    procedure Clear_ButtonClick(Sender: TObject);
    procedure DisconnectDevice1Click(Sender: TObject);
    procedure ConnectDevice1Click(Sender: TObject);
    procedure Setup1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  Form1        :TForm1;
  myStatus     :string;

implementation

{$R *.dfm}

procedure myCallback(var user: eb_user_data_t; var status: eb_status_t; var data:eb_data_t );

begin
  Form1.messages_ListBox.Items.Add('Data receive: '+IntToHex(data,32));
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  myDevice:= Twrdevice.Create;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  myDevice.DeviceClose(myStatus);
  myDevice.Free;
end;

procedure TForm1.Setup1Click(Sender: TObject);
begin
  DevSet_Form.Show;
end;

procedure TForm1.ConnectDevice1Click(Sender: TObject);
begin
  messages_ListBox.Items.Add('Try to Open: '+ myDNSAdress+
                             ' Port:'+IntTohex(myAddress,4));

   if(myDevice.DeviceOpen(Pchar(myDNSAdress), myAddress, myStatus)) then
      DeviceActiv_Shape.Brush.Color:=clLime
   else DeviceActiv_Shape.Brush.Color:=clRed;

   messages_ListBox.Items.Add('Device Open: '+myStatus);
end;

procedure TForm1.DisconnectDevice1Click(Sender: TObject);
begin
  if(myDevice.DeviceClose(myStatus)) then
    DeviceActiv_Shape.Brush.Color:= clRed
  else DeviceActiv_Shape.Brush.Color:=clYellow;

  messages_ListBox.Items.Add('Device Close: '+myStatus);
end;

procedure TForm1.Clear_ButtonClick(Sender: TObject);
begin
   messages_ListBox.Items.Clear;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  myDevice.DevicePoll();
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if not(myDevice.DeviceRead(@myCallback, myAddress, myStatus))  then
    messages_ListBox.Items.Add('Device Read: '+myStatus);
end;

procedure TForm1.SendManual1Click(Sender: TObject);
begin
  SendUserdata_Form.Show();
end;

end.
