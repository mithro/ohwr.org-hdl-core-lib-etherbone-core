unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, etherbone, StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    sysmessage_ListBox: TListBox;
    Button1: TButton;
    Adress_Edit: TEdit;
    Port_Edit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    DataToWrite_Edit: TEdit;
    Open_Button: TButton;
    Close_Button: TButton;
    Lampe_Shape: TShape;
    procedure Close_ButtonClick(Sender: TObject);
    procedure Open_ButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

  const   DNSAdress = 'asl720.acc.gsi.de:8989';
          PortNumber= '400';

var
  Form1: TForm1;
  socket    :eb_socket_t;
  device    :eb_device_t;
  address   :eb_address_t;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);

var
  data      :eb_data_t ;
  status    :eb_status ;

  timout:integer;
  stop:integer;

begin
  data:= StrToInt('$'+ DataToWrite_Edit.Text);

  // daten schreiben
  eb_device_write(device, address, data);
  eb_device_flush(device);

  sysmessage_ListBox.Items.Add('Data sending:'+IntToHex(data,32));

end;

procedure TForm1.FormCreate(Sender: TObject);

begin
  Adress_Edit.Text:= DNSAdress;
  Port_Edit.Text  := PortNumber;

  socket:=0;
  device:=0;

  Lampe_Shape.Brush.Color:=clRed;
end;

procedure TForm1.Open_ButtonClick(Sender: TObject);

var
  netaddress:eb_network_address_t;
  data      :eb_data_t ;
  status    :eb_status ;

  timout:integer;
  stop:integer;

begin
  netaddress:= PChar(Adress_Edit.Text);
  address:= StrToInt('$'+ Port_Edit.Text);

  Lampe_Shape.Brush.Color:=clLime;

  // eb socket oeffnen
  status:=eb_socket_open(0, 0, @socket);
  if(status<> EB_OK) then begin
    sysmessage_ListBox.Items.Add('ERROR: Failed to open Etherbone socket');
    Lampe_Shape.Brush.Color:=clRed;
  end else sysmessage_ListBox.Items.Add('Open Etherbone socket successful');

  // etherbone device oeffnen
  status:= eb_device_open(socket, netaddress, EB_DATAX, @device);
  if(status<> EB_OK) then begin
    sysmessage_ListBox.Items.Add('ERROR: Failed to open Etherbone device');
    Lampe_Shape.Brush.Color:=clRed;
  end else sysmessage_ListBox.Items.Add('Open Etherbone device successful');
end;


procedure TForm1.Close_ButtonClick(Sender: TObject);

var   status    :eb_status ;

begin
  // etherbone device schliessen
  status:= eb_device_close(device);
  if(status<> EB_OK) then begin
    sysmessage_ListBox.Items.Add('ERROR: Failed to close Etherbone device');
    Lampe_Shape.Brush.Color:=clRed;
  end else sysmessage_ListBox.Items.Add('Close Etherbone device successful');

  // eb socket schliesen
  status:= eb_socket_close(socket);
  if(status<> EB_OK) then begin
    sysmessage_ListBox.Items.Add('ERROR: Failed to close Etherbone socket');
    Lampe_Shape.Brush.Color:=clRed;
  end else sysmessage_ListBox.Items.Add('Close Etherbone socket successful')
end;

end.
