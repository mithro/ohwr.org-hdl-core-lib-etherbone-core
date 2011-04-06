object Form1: TForm1
  Left = 0
  Top = 0
  Width = 512
  Height = 601
  AutoSize = True
  Caption = 'whiterabbit'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 19
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 353
    Height = 385
    BevelInner = bvLowered
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 7
      Width = 66
      Height = 19
      Caption = 'XML Tree'
    end
    object TreeView1: TTreeView
      Left = 15
      Top = 31
      Width = 313
      Height = 338
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Tahoma'
      Font.Style = []
      Indent = 19
      ParentFont = False
      TabOrder = 0
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 384
    Width = 504
    Height = 163
    BevelInner = bvLowered
    TabOrder = 1
    object messages_ListBox: TListBox
      Left = 8
      Top = 8
      Width = 487
      Height = 129
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Tahoma'
      Font.Style = []
      ItemHeight = 18
      ParentFont = False
      TabOrder = 0
    end
    object Clear_Button: TButton
      Left = 429
      Top = 140
      Width = 65
      Height = 17
      Caption = 'Clear'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = Clear_ButtonClick
    end
  end
  object Panel3: TPanel
    Left = 351
    Top = 0
    Width = 153
    Height = 385
    BevelInner = bvLowered
    TabOrder = 2
    object Panel4: TPanel
      Left = 0
      Top = 0
      Width = 153
      Height = 49
      BevelInner = bvLowered
      TabOrder = 0
      object Label2: TLabel
        Left = 8
        Top = 13
        Width = 91
        Height = 19
        Caption = 'Device active'
      end
      object DeviceActiv_Shape: TShape
        Left = 108
        Top = 11
        Width = 33
        Height = 25
        Brush.Color = clRed
        Shape = stCircle
      end
    end
    object Panel5: TPanel
      Left = 0
      Top = 102
      Width = 153
      Height = 122
      BevelInner = bvLowered
      TabOrder = 1
      object Label3: TLabel
        Left = 8
        Top = 8
        Width = 46
        Height = 19
        Caption = 'Device'
      end
      object SendData_Button: TButton
        Left = 23
        Top = 39
        Width = 105
        Height = 25
        Caption = 'Send Data'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
      end
      object Button1: TButton
        Left = 24
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Read Data'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 1
        OnClick = Button1Click
      end
    end
    object Panel6: TPanel
      Left = 0
      Top = 47
      Width = 153
      Height = 57
      BevelInner = bvLowered
      TabOrder = 2
      object ShowXML_Button: TButton
        Left = 23
        Top = 16
        Width = 105
        Height = 25
        Caption = 'Analyse XML'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
      end
    end
  end
  object Timer1: TTimer
    Interval = 100
    OnTimer = Timer1Timer
    Left = 360
    Top = 232
  end
  object OpenDialog1: TOpenDialog
    Left = 360
    Top = 264
  end
  object MainMenu1: TMainMenu
    Left = 360
    Top = 296
    object D1: TMenuItem
      Caption = 'Datei'
      object XMLLaden1: TMenuItem
        Caption = 'XML-Laden'
      end
      object Exit1: TMenuItem
        Caption = 'Exit'
      end
    end
    object Device1: TMenuItem
      Caption = 'Device'
      object Setup1: TMenuItem
        Caption = 'Setup'
        OnClick = Setup1Click
      end
      object ConnectDevice1: TMenuItem
        Caption = 'Connect  Device'
        OnClick = ConnectDevice1Click
      end
      object DisconnectDevice1: TMenuItem
        Caption = 'Disconnect Device'
        OnClick = DisconnectDevice1Click
      end
    end
    object Extras1: TMenuItem
      Caption = 'Extras'
      object SendManual1: TMenuItem
        Caption = 'Send Manual'
        OnClick = SendManual1Click
      end
    end
  end
  object XMLDocument1: TXMLDocument
    Left = 360
    Top = 336
    DOMVendorDesc = 'MSXML'
  end
end
