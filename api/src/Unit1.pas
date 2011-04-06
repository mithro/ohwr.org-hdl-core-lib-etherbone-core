unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, etherbone, StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    sysmessage_ListBox: TListBox;
    Panel1: TPanel;
    Label3: TLabel;
    DataToWrite_Edit: TEdit;
    Button1: TButton;
    Panel2: TPanel;
    Open_Button: TButton;
    Close_Button: TButton;
    Lampe_Shape: TShape;
    Panel3: TPanel;
    Label1: TLabel;
    Adress_Edit: TEdit;
    Label2: TLabel;
    Port_Edit: TEdit;
    Label4: TLabel;
    Panel4: TPanel;
    Read_Button: TButton;
    Label6: TLabel;
    CallBack: TTimer;
    procedure CallBackTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Read_ButtonClick(Sender: TObject);
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
  socket     :eb_socket_t;
  device     :eb_device_t;
  address    :eb_address_t;
  device_open: boolean;

implementation

{$R *.dfm}

procedure set_stop(var user: eb_user_data_t; var status: eb_status_t; var data:eb_data_t );

begin
  Form1.sysmessage_ListBox.Items.Add('Data receive: '+IntToHex(data,32));
end;

procedure test(myCallback:eb_read_callback_t);
begin
 Form1.sysmessage_ListBox.Items.Add('Super');
end;


procedure TForm1.Button1Click(Sender: TObject);

var
  data      :eb_data_t ;
  status    :eb_status ;

  timout:integer;
  stop:integer;

begin
  if(device_open) then begin

    try
      data:= StrToInt('$'+ DataToWrite_Edit.Text);
    except
      data:=0;
    end;

    // daten schreiben
    eb_device_write(device, address, data);
    eb_device_flush(device);

    sysmessage_ListBox.Items.Add('Data sending:'+IntToHex(data,32));
  end else sysmessage_ListBox.Items.Add('Device/socket not open yet');
end;

procedure TForm1.FormCreate(Sender: TObject);

begin
  Adress_Edit.Text:= DNSAdress;
  Port_Edit.Text  := PortNumber;

  socket:=0;
  device:=0;

  device_open:=false;

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
  if not(device_open)then begin

    netaddress:= PChar(Adress_Edit.Text);
    address:= StrToInt('$'+ Port_Edit.Text);

    Lampe_Shape.Brush.Color:=clLime;
    device_open:= true;

    // eb socket oeffnen
    status:=eb_socket_open(0, 0, @socket);
    if(status<> EB_OK) then begin
      sysmessage_ListBox.Items.Add('ERROR: Failed to open Etherbone socket');
      Lampe_Shape.Brush.Color:=clRed;
      device_open:=false;
    end else sysmessage_ListBox.Items.Add('Open Etherbone socket successful');

    // etherbone device oeffnen
    if(device_open) then begin
      status:= eb_device_open(socket, netaddress, EB_DATAX, @device);
      if(status<> EB_OK) then begin
        sysmessage_ListBox.Items.Add('ERROR: Failed to open Etherbone device');
        Lampe_Shape.Brush.Color:=clRed;
        device_open:=false;
      end else sysmessage_ListBox.Items.Add('Open Etherbone device successful');
    end;
   end else sysmessage_ListBox.Items.Add('Device/socket allready open');
end;


procedure TForm1.Close_ButtonClick(Sender: TObject);

var   status:eb_status ;

begin
    if(device_open) then begin
      // etherbone device schliessen
      status:= eb_device_close(device);
      if(status<> EB_OK) then sysmessage_ListBox.Items.Add('ERROR: Failed to close Etherbone device')
      else begin
        sysmessage_ListBox.Items.Add('Close Etherbone device successful');
        device_open:=false;
        Lampe_Shape.Brush.Color:=clRed;
      end;

    // eb socket schliesen
    status:= eb_socket_close(socket);
    if(status<> EB_OK) then sysmessage_ListBox.Items.Add('ERROR: Failed to close Etherbone socket')
    else begin
      sysmessage_ListBox.Items.Add('Close Etherbone socket successful');
      device_open:=false;
      Lampe_Shape.Brush.Color:=clRed;
    end;
  end else sysmessage_ListBox.Items.Add('Nothing to close here');
end;

procedure TForm1.Read_ButtonClick(Sender: TObject);

var  stop:integer;

begin
  if(device_open) then begin
    eb_device_read(device, address, @stop, @set_stop);
//    eb_device_read(device, address, @stop, @test);
    eb_device_flush(device);
  end else sysmessage_ListBox.Items.Add('Device/socket not open, buddy');
end;


procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Form1.Close_Button.Click;
end;

procedure TForm1.CallBackTimer(Sender: TObject);
begin
  if(device_open) then eb_socket_poll(socket);
end;

end.
