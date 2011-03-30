object Form1: TForm1
  Left = 0
  Top = 0
  Width = 655
  Height = 409
  Caption = 'first etherbone test'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 19
  object Label1: TLabel
    Left = 16
    Top = 8
    Width = 48
    Height = 19
    Caption = 'Adress'
  end
  object Label2: TLabel
    Left = 16
    Top = 72
    Width = 67
    Height = 19
    Caption = 'Port Nr. :'
  end
  object Label3: TLabel
    Left = 16
    Top = 144
    Width = 102
    Height = 19
    Caption = 'Data to write :'
  end
  object Lampe_Shape: TShape
    Left = 112
    Top = 272
    Width = 33
    Height = 25
    Brush.Color = clRed
    Shape = stCircle
  end
  object sysmessage_ListBox: TListBox
    Left = 192
    Top = 5
    Width = 441
    Height = 353
    ItemHeight = 19
    TabOrder = 0
  end
  object Button1: TButton
    Left = 16
    Top = 200
    Width = 89
    Height = 25
    Caption = 'Send'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Adress_Edit: TEdit
    Left = 16
    Top = 32
    Width = 161
    Height = 27
    TabOrder = 2
  end
  object Port_Edit: TEdit
    Left = 16
    Top = 96
    Width = 145
    Height = 27
    TabOrder = 3
  end
  object DataToWrite_Edit: TEdit
    Left = 16
    Top = 168
    Width = 145
    Height = 27
    TabOrder = 4
  end
  object Open_Button: TButton
    Left = 16
    Top = 272
    Width = 81
    Height = 25
    Caption = 'Open'
    TabOrder = 5
    OnClick = Open_ButtonClick
  end
  object Close_Button: TButton
    Left = 16
    Top = 312
    Width = 81
    Height = 25
    Caption = 'Close'
    TabOrder = 6
    OnClick = Close_ButtonClick
  end
end
