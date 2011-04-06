object Form1: TForm1
  Left = 0
  Top = 0
  Width = 816
  Height = 428
  Caption = 'first etherbone test'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 19
  object Label6: TLabel
    Left = 299
    Top = 8
    Width = 127
    Height = 19
    Caption = 'System  Messages'
  end
  object sysmessage_ListBox: TListBox
    Left = 301
    Top = 29
    Width = 492
    Height = 353
    ItemHeight = 19
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = -1
    Top = 230
    Width = 290
    Height = 90
    BevelInner = bvLowered
    TabOrder = 1
    object Label3: TLabel
      Left = 8
      Top = 14
      Width = 133
      Height = 19
      Caption = 'Data to write (hex)'
    end
    object DataToWrite_Edit: TEdit
      Left = 8
      Top = 38
      Width = 145
      Height = 27
      TabOrder = 0
    end
    object Button1: TButton
      Left = 168
      Top = 38
      Width = 89
      Height = 25
      Caption = 'Send'
      TabOrder = 1
      OnClick = Button1Click
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 127
    Width = 289
    Height = 105
    BevelInner = bvLowered
    TabOrder = 2
    object Lampe_Shape: TShape
      Left = 165
      Top = 39
      Width = 33
      Height = 25
      Brush.Color = clRed
      Shape = stCircle
    end
    object Label4: TLabel
      Left = 200
      Top = 41
      Width = 43
      Height = 19
      Caption = 'Status'
    end
    object Open_Button: TButton
      Left = 8
      Top = 20
      Width = 113
      Height = 25
      Caption = 'Open Device'
      TabOrder = 0
      OnClick = Open_ButtonClick
    end
    object Close_Button: TButton
      Left = 8
      Top = 60
      Width = 113
      Height = 25
      Caption = 'Close Device'
      TabOrder = 1
      OnClick = Close_ButtonClick
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 0
    Width = 289
    Height = 129
    BevelInner = bvLowered
    TabOrder = 3
    object Label1: TLabel
      Left = 16
      Top = 8
      Width = 99
      Height = 19
      Caption = 'Device Adress'
    end
    object Label2: TLabel
      Left = 16
      Top = 70
      Width = 98
      Height = 19
      Caption = 'Port Nr. (hex)'
    end
    object Adress_Edit: TEdit
      Left = 16
      Top = 32
      Width = 257
      Height = 27
      TabOrder = 0
    end
    object Port_Edit: TEdit
      Left = 16
      Top = 90
      Width = 153
      Height = 27
      TabOrder = 1
    end
  end
  object Panel4: TPanel
    Left = -1
    Top = 318
    Width = 290
    Height = 65
    BevelInner = bvLowered
    TabOrder = 4
    object Read_Button: TButton
      Left = 106
      Top = 20
      Width = 89
      Height = 25
      Caption = 'Read Data'
      TabOrder = 0
      OnClick = Read_ButtonClick
    end
  end
  object CallBack: TTimer
    Interval = 100
    OnTimer = CallBackTimer
    Left = 608
  end
end
