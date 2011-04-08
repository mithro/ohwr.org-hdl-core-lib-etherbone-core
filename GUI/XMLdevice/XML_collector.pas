unit XML_collector;

interface

uses
  xmldom, XMLIntf, StdCtrls, ComCtrls, ExtCtrls, Menus, msxmldom,
  SysUtils, Variants, XMLDoc, Global;

type
  TXML_collector = class

  public
    { Public-Deklarationen }

  function AnalyseXMLTree   (deep1: IXMLNodeList):boolean;
  procedure ConvertData(var data:longword;BitPosL:Byte;BitPosH:Byte);

  private
    { Private-Deklarationen }
   end;


implementation


function TXML_collector.AnalyseXMLTree(deep1: IXMLNodeList):boolean;

var deep1_index:integer;
    deep2_index:integer;
    deep2      : IXMLNodeList;
    deep3_index:integer;
    deep3      : IXMLNodeList;
    BitPosL    :Byte;
    BitPosH    :Byte;
    BitPosStr  :String;
    Data       :longword;


begin
  DeviceCtrRegCount:= 0;
  DeviceDataCount  := 0;

  deep1_index:=0;
  while (deep1_index <= deep1.Count-1) do begin //deep1 hat keine daten(led/timer/signal)
    deep2:= deep1[deep1_index].ChildNodes;
    deep2_index:=0;
    while (deep2_index <= deep2.Count-1) do begin //deep 2 hat daten f. ctrl-reg.
      deep3:= deep2[deep2_index].ChildNodes;
      deep3_index:=0;

      if(deep3.Count = 0) then begin //letzte ebene nur daten
          DeviceData[DeviceDataCount]:= 0;
      end;

      while (deep3_index <= deep3.Count-1) do begin  //reine daten, keine ctr
          if(deep3[deep3_index].GetAttribute('bitpos')<>'')then begin
            BitPosStr:= VarToStr(deep3[deep3_index].GetAttribute('bitpos'));
            BitPosL:=StrToInt(BitPosStr[1]);
            BitPosH:=StrToInt(BitPosStr[3]);

            data:=  StrToInt('$'+VarToStr(deep3[deep3_index].GetAttribute('value')));
            ConvertData(data,BitPosL,BitPosH);
            DeviceData[DeviceDataCount]:= DeviceData[DeviceDataCount] OR data;
//
        end;
        deep3_index:=deep3_index + 1;
      end;//deep3
      DeviceCtrReg[DeviceCtrRegCount]:= StrToInt('$'+VarToStr(deep2[deep2_index].GetAttribute('value')));
      DeviceCtrRegCount:=DeviceCtrRegCount+1;
      DeviceDataCount:=DeviceDataCount+1;
      deep2_index:=deep2_index+1;
    end;//deep2
    deep1_index:=deep1_index+1;
  end;//deep1
end;

procedure TXML_collector.ConvertData(var data:longword;BitPosL:Byte;BitPosH:Byte);

var mask:longword;

begin
 { mask:=$FFFF;

  mask:=mask SHL (BitPosH-BitPosL);
  data:=data XOR mask;    }

  data:= data SHL BitPosL;
end;



end.
