(*
  OsMap components for offline rendering and routing functionalities
  based on OpenStreetMap data

  Copyright (C) 2019  Sergey Bodrov

  This source is ported from libosmscout library
  Copyright (C) 2009  Tim Teulings

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA

*)
(*
StyleConfig:
  StyleResolveContext
  StyleConstant       -> TStyleConstant
  StyleConstantColor  -> TStyleConstant
  StyleConstantMag    -> TStyleConstant
  StyleConstantUInt   -> TStyleConstant
  SizeCondition
  FeatureFilterData
  StyleFilter
  StyleCriteria
  PartialStyleBase
  PartialStyle
  ConditionalStyle
  StyleSelector
  StyleConfig -> TStyleConfig )

StyleProcessor:
  FillStyleProcessor
*)
unit OsMapStyleConfig;

{$ifdef FPC}
{$mode objfpc}{$H+}
{$endif}

interface

uses
  Classes, SysUtils,
  {$ifdef FPC}
  fgl,
  {$else}
  System.Generics.Collections,
  {$endif}
  OsMapTypes, OsMapObjTypes, OsMapStyles, OsMapGeometry,
  OsMapObjFeatures, OsMapProjection, OsMapUtils;

type
  {$ifdef FPC}
  TNamedStyleMap = specialize TFPGMap<string, TStyle>;
  {$else}
  TNamedStyleMap = TDictionary<string, TStyle>;
  {$endif}
  {TNamedStyleMap = class(TStringList)
  public
    function TryGetData(AName: string; out AValue: TStyle): Boolean;
    procedure AddOrSetData(AName: string; AValue: TStyle);
  end; }

  { TODO : remove this crutch }

  { TStyleResolveContext }

  TStyleResolveContext = class
  private
    FTypeConfig: TTypeConfig;
    FFeatureReaderMap: TSimpleStringHash;
    FFeatureReaders: array of TFeatureValueReader;
    FAccessReader: TFeatureValueReader;
  public
    constructor Create(ATypeConfig: TTypeConfig);
    destructor Destroy; override;

    function GetFeatureReaderIndex(AFeature: TFeature): Integer;
    function HasFeature(AFeatureIndex: Integer; const ABuffer: TFeatureValueBuffer): Boolean;

    function GetFeatureName(AFeatureIndex: Integer): string;
    function GetFeatureValue(AFeatureIndex: Integer; const ABuffer: TFeatureValueBuffer): TFeatureValue;

    function IsOneway(const ABuffer: TFeatureValueBuffer): Boolean;
  end;

  TNamedFlagMap = TStringList;

  TStyleConstant = class
  public
    Color: TMapColor;
    Magnification: TMagnification;
    Number: Integer;
  end;

  //TNamedStyleConstantMap = specialize TFPGMapObject<string, TStyleConstant>;
  TNamedStyleConstantMap = TStringList;

  TFeatureFilterData = record
    FeatureFilterIndex: Integer;
    FlagIndex: Integer;
  end;

  { TStyleCriteria }

  TStyleCriteria = object
    Features: array of TFeatureFilterData;
    IsOneway: Boolean;
    //SizeCondition: TSizeCondition;

    function HasCriteria(): Boolean;

    function Matches(const AContext: TStyleResolveContext;
                 const ABuffer: TFeatureValueBuffer;
                 AMeterInPixel, AMeterInMM: TReal): Boolean;
  end;

  //TNamedSymbolMap = specialize TFPGMap<string, TMapSymbol>;
  TNamedSymbolMap = TStringList;

  { TFillStyleProcessor }

  TFillStyleProcessor = class
  public
    function Process(const ABuffer: TFeatureValueBuffer; AFillStyle: TFillStyle): TFillStyle; virtual; abstract;
  end;

  //TFillStyleProcessorList = specialize TFPGList<TFillStyleProcessor>;

  { TStyleConfig }
  { A complete style definition

    Internals:
    * Fastpath: Fastpath means, that we can directly return the style definition from the style sheet. This is normally
    the case, if there is excactly one match in the style sheet. If there are multiple matches a new style has to be
    allocated and composed from all matches. }
  TStyleConfig = class
  private
    // created
    FFlags: TNamedFlagMap;
    FConstants: TNamedStyleConstantMap;
    FSymbols: TNamedSymbolMap;
    FErrors: TStringList;
    FWarnings: TStringList;
    FStyleList: TStyleList;
    FNamedStyleMap: TNamedStyleMap;

    // assigned
    FTypeConfig: TTypeConfig;

    FTileLandBuffer: TFeatureValueBuffer;
    FTileSeaBuffer: TFeatureValueBuffer;
    FTileCoastBuffer: TFeatureValueBuffer;
    FTileUnknownBuffer: TFeatureValueBuffer;
    FCoastlineBuffer: TFeatureValueBuffer;
    FOsmTileBorderBuffer: TFeatureValueBuffer;
    FOsmSubTileBorderBuffer: TFeatureValueBuffer;

    //FLabelFactories // not needed

    FEmptySymbol: TMapSymbol;

    // Node
    { TODO : implement }
    // Way
    FWayPrio: array of Integer;

    FFillProcessors: array of TFillStyleProcessor;

    function GetStyleByName(const AName: string): TStyle;
    procedure AddStyleByName(const AName: string; AStyle: TStyle);

  public
    constructor Create(ATypeConfig: TTypeConfig);
    destructor Destroy; override;

    // not needed
    // function RegisterLabelProviderFactory();
    // function GetLabelProvider();

    function HasFlag(const AName: string): Boolean;
    function GetFlagByName(const AName: string): Boolean;
    procedure AddFlag(const AName: string; AValue: Boolean);

    function GetConstantByName(const AName: string): TStyleConstant;
    { Add style constant to name-value map.
      Note! Constant map become owner of values, don't need to free() value }
    procedure AddConstant(const AName: string; AValue: TStyleConstant);

    function RegisterSymbol(ASymbol: TMapSymbol): Boolean;
    function GetSymbol(const AName: string): TMapSymbol;

    procedure Postprocess();

    function GetFeatureFilterIndex(AFeature: TFeature): Integer;

    procedure SetWayPrio(ATypeInfo: TTypeInfo; APrio: Integer);
    function GetWayPrio(ATypeInfo: TTypeInfo): Integer;

    // add styles
    //procedure AddNodeTextStyle(AFilter: TStyleFilter; AStyle: TTextPartialStyle);

    // ...
    procedure AddStyle(ATypeInfo: TTypeInfo; AStyle: TStyle; const AName: string = '');

    { Methods for retrieval of styles for a given object. }
    function GetObjTypeStyle(ATypeInfo: TTypeInfo): TStyle;

    function HasNodeTextStyles(ATypeInfo: TTypeInfo;
                               const AMagnification: TMagnification): Boolean;

    procedure GetNodeTextStyles(const ABuffer: TFeatureValueBuffer;
                                const AProjection: TProjection;
                                ATextStyles: TTextStyleList);

    function GetNodeIconStyle(const ABuffer: TFeatureValueBuffer;
                              const AProjection: TProjection): TIconStyle;

    procedure GetWayLineStyles(const ABuffer: TFeatureValueBuffer;
                               const AProjection: TProjection;
                               ALineStyles: TLineStyleList);

    function GetWayPathTextStyle(const ABuffer: TFeatureValueBuffer;
                                 const AProjection: TProjection): TPathTextStyle;

    function GetWayPathSymbolStyle(const ABuffer: TFeatureValueBuffer;
                                   const AProjection: TProjection): TPathSymbolStyle;

    function GetWayPathShieldStyle(const ABuffer: TFeatureValueBuffer;
                                   const AProjection: TProjection): TPathShieldStyle;

    function GetAreaFillStyle(const ABuffer: TFeatureValueBuffer;
                              const AProjection: TProjection): TFillStyle;

    procedure GetAreaBorderStyles(const ABuffer: TFeatureValueBuffer;
                             const AProjection: TProjection;
                             ABorderStyles: TBorderStyleList);

    function HasAreaTextStyles(ATypeInfo: TTypeInfo;
                               const AMagnification: TMagnification): Boolean;

    procedure GetAreaTextStyles(const ABuffer: TFeatureValueBuffer;
                           const AProjection: TProjection;
                           ATextStyles: TTextStyleList);

    function GetAreaIconStyle(const ABuffer: TFeatureValueBuffer;
                              const AProjection: TProjection): TIconStyle;

    function GetAreaBorderTextStyle(const ABuffer: TFeatureValueBuffer;
                                    const AProjection: TProjection): TPathTextStyle;

    function GetAreaBorderSymbolStyle(const ABuffer: TFeatureValueBuffer;
                                      const AProjection: TProjection): TPathSymbolStyle;

    function GetLandFillStyle(const AProjection: TProjection): TFillStyle;
    function GetSeaFillStyle(const AProjection: TProjection): TFillStyle;
    function GetCoastFillStyle(const AProjection: TProjection): TFillStyle;
    function GetUnknownFillStyle(const AProjection: TProjection): TFillStyle;
    function GetCoastlineLineStyle(const AProjection: TProjection): TLineStyle;
    function GetOSMTileBorderLineStyle(const AProjection: TProjection): TLineStyle;
    function GetOSMSubTileBorderLineStyle(const AProjection: TProjection): TLineStyle;


    procedure RegisterFillStyleProcessor(ATypeIndex: Integer; AProcessor: TFillStyleProcessor);
    function GetFillStyleProcessor(ATypeIndex: Integer): TFillStyleProcessor;

    property TypeConfig: TTypeConfig read FTypeConfig;
    property Flags: TNamedFlagMap read FFlags;
  end;

implementation

uses Math; // eliminate "end of source not found"

const
  DEF_LINE_WIDTH = 1;
  DEF_LINE_DISPLAY_WIDTH = 1;

{ TStyleConfig }

constructor TStyleConfig.Create(ATypeConfig: TTypeConfig);
begin
  inherited Create();
  FFlags := TNamedFlagMap.Create();
  FConstants := TNamedStyleConstantMap.Create();
  FConstants.OwnsObjects := True;
  FSymbols := TNamedSymbolMap.Create();
  FErrors := TStringList.Create();
  FWarnings := TStringList.Create();
  FStyleList := TStyleList.Create();
  FNamedStyleMap := TNamedStyleMap.Create();

  //FFillProcessors := TFillStyleProcessorList.Create();

  FTypeConfig := ATypeConfig;
end;

destructor TStyleConfig.Destroy;
begin
  //FreeAndNil(FFillProcessors);
  FreeAndNil(FNamedStyleMap);
  FreeAndNil(FStyleList);
  FreeAndNil(FWarnings);
  FreeAndNil(FErrors);
  FreeAndNil(FSymbols);
  FreeAndNil(FConstants);
  FreeAndNil(FFlags);
  inherited Destroy;
end;

function TStyleConfig.HasFlag(const AName: string): Boolean;
var
  n: Integer;
begin
  Result := FFlags.Find(AName, n);
end;

function TStyleConfig.GetFlagByName(const AName: string): Boolean;
var
  n: Integer;
begin
  if FFlags.Find(AName, n) then
    Result := (FFlags.ValueFromIndex[n] <> '')
  else
    Result := False;
end;

procedure TStyleConfig.AddFlag(const AName: string; AValue: Boolean);
begin
  if AValue then
    FFlags.Values[AName] := '1'
  else
    FFlags.Values[AName] := '';
end;

function TStyleConfig.GetConstantByName(const AName: string): TStyleConstant;
var
  n: Integer;
begin
  if FConstants.Find(AName, n) then
    Result := (FConstants.Objects[n] as TStyleConstant)
  else
    Result := nil;
end;

procedure TStyleConfig.AddConstant(const AName: string; AValue: TStyleConstant);
begin
  FConstants.AddObject(AName, AValue);
end;

function TStyleConfig.RegisterSymbol(ASymbol: TMapSymbol): Boolean;
begin
  FSymbols.AddObject(ASymbol.Name, ASymbol);
  Result := True;
end;

function TStyleConfig.GetSymbol(const AName: string): TMapSymbol;
var
  n: Integer;
begin
  if FSymbols.Find(AName, n) then
    Result := (FSymbols.Objects[n] as TMapSymbol)
  else
    Result := nil;
end;

procedure TStyleConfig.Postprocess();
begin

end;

function TStyleConfig.GetFeatureFilterIndex(AFeature: TFeature): Integer;
begin

end;

procedure TStyleConfig.SetWayPrio(ATypeInfo: TTypeInfo; APrio: Integer);
begin
  if Length(FWayPrio) <= ATypeInfo.Index then
    SetLength(FWayPrio, ATypeInfo.Index+1);

  FWayPrio[ATypeInfo.Index] := APrio;
end;

function TStyleConfig.GetWayPrio(ATypeInfo: TTypeInfo): Integer;
begin
  //Assert(Length(FWayPrio) > ATypeInfo.Index);
  //Result := FWayPrio[ATypeInfo.Index];

  { TODO : remove this crutch }
  Result := 1;
end;

procedure TStyleConfig.AddStyle(ATypeInfo: TTypeInfo; AStyle: TStyle; const AName: string);
begin
  {$ifdef FPC}
  if AName <> '' then
    FNamedStyleMap.AddOrSetData(AName, AStyle)
  else
    FNamedStyleMap.AddOrSetData(AStyle.Name, AStyle);
  {$else}
  if AName <> '' then
    FNamedStyleMap.AddOrSetValue(AName, AStyle)
  else
    FNamedStyleMap.AddOrSetValue(AStyle.Name, AStyle);
  {$endif}
end;

procedure TStyleConfig.AddStyleByName(const AName: string; AStyle: TStyle);
begin
  {$ifdef FPC}
  if AName <> '' then
    FNamedStyleMap.AddOrSetData(AName, AStyle)
  {$else}
  if AName <> '' then
    FNamedStyleMap.AddOrSetValue(AName, AStyle);
  {$endif}
end;

function TStyleConfig.GetObjTypeStyle(ATypeInfo: TTypeInfo): TStyle;
begin
  Assert(Assigned(ATypeInfo));
  {$ifdef FPC}
  if not FNamedStyleMap.TryGetData(ATypeInfo.TypeName, Result) then
    Result := nil;
  {$else}
  if not FNamedStyleMap.TryGetValue(ATypeInfo.TypeName, Result) then
    Result := nil;
  {$endif}
  //case ATypeInfo.TypeName;
end;

function TStyleConfig.GetStyleByName(const AName: string): TStyle;
begin
  {$ifdef FPC}
  if not FNamedStyleMap.TryGetData(AName, Result) then
    Result := nil;
  {$else}
  if not FNamedStyleMap.TryGetValue(AName, Result) then
    Result := nil;
  {$endif}
end;

function TStyleConfig.HasNodeTextStyles(ATypeInfo: TTypeInfo;
  const AMagnification: TMagnification): Boolean;
var
  s: string;
  //Level: TMagnificationLevel;
  //n: Integer;
  //TmpStyle:
begin
  s := ATypeInfo.TypeName + '_Text';
  {$ifdef FPC}
  Result := (FNamedStyleMap.IndexOf(s) <> -1);
  {$else}
  Result := FNamedStyleMap.ContainsKey(s);
  {$endif}
  //Result := FNamedStyleMap.Find(s, n);
  (*
  Level := AMagnification.Level;
  nodeTextStyleSelectors;
  for (const auto& nodeTextStyleSelector : nodeTextStyleSelectors) {
    if (level>=nodeTextStyleSelector[type->GetIndex()].size()) {
      level=static_cast<uint32_t>(nodeTextStyleSelector[type->GetIndex()].size()-1);
    }

    if (!nodeTextStyleSelector[type->GetIndex()][level].empty()) {
      return true;
    }
  }

  return false;
  *)
end;

procedure TStyleConfig.GetNodeTextStyles(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection; ATextStyles: TTextStyleList);
begin

end;

function TStyleConfig.GetNodeIconStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TIconStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Icon';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TIconStyle) then
    Result := (TmpStyle as TIconStyle)
  else
  begin
    // create default style
    Result := TIconStyle.Create();
    Result.Name := s;
    Result.IconName := ABuffer.TypeInfo.TypeName;
    AddStyleByName(s, Result);
  end;
end;

procedure TStyleConfig.GetWayLineStyles(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection; ALineStyles: TLineStyleList);
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Line';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TLineStyle) then
  begin
    if ((TmpStyle.MinZoom <> 0) and (AProjection.Magnification.Level < TmpStyle.MinZoom))
    or ((TmpStyle.MaxZoom <> 0) and (AProjection.Magnification.Level > TmpStyle.MaxZoom)) then
      Exit;
    ALineStyles.Add(TmpStyle as TLineStyle);
  end
  else
  begin
    // create default style
    TmpStyle := TLineStyle.Create();
    TmpStyle.Name := s;
    (TmpStyle as TLineStyle).LineColor.InitRandom();
    (TmpStyle as TLineStyle).Width := DEF_LINE_WIDTH;
    (TmpStyle as TLineStyle).DisplayWidthMM := DEF_LINE_DISPLAY_WIDTH;
    AddStyleByName(s, TmpStyle);
    ALineStyles.Add(TmpStyle as TLineStyle);
  end;
end;

function TStyleConfig.GetWayPathTextStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TPathTextStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_PathText';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TPathTextStyle) then
  begin
    if ((TmpStyle.MinZoom <> 0) and (AProjection.Magnification.Level < TmpStyle.MinZoom))
    or ((TmpStyle.MaxZoom <> 0) and (AProjection.Magnification.Level > TmpStyle.MaxZoom)) then
      Result := nil
    else
      Result := (TmpStyle as TPathTextStyle);
  end
  else
  begin
    // create default style
    Result := TPathTextStyle.Create();
    Result.Name := s;
    Result.TextColor.Init(0, 0, 0, 1);
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetWayPathSymbolStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TPathSymbolStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_PathSymbol';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TPathSymbolStyle) then
    Result := (TmpStyle as TPathSymbolStyle)
  else
  begin
    // create default style
    Result := TPathSymbolStyle.Create();
    Result.Name := s;
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetWayPathShieldStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TPathShieldStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_PathShield';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TPathShieldStyle) then
    Result := (TmpStyle as TPathShieldStyle)
  else
  begin
    // create default style
    Result := TPathShieldStyle.Create();
    Result.Name := s;
    Result.ShieldStyle.FeatureType := ftName;
    Result.ShieldStyle.BgColor.InitRandom();
    Result.ShieldStyle.BorderColor.InitRandom();
    Result.ShieldStyle.TextColor.InitRandom();
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetAreaFillStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TFillStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Fill';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TFillStyle) then
  begin
    if ((TmpStyle.MinZoom <> 0) and (AProjection.Magnification.Level < TmpStyle.MinZoom))
    or ((TmpStyle.MaxZoom <> 0) and (AProjection.Magnification.Level > TmpStyle.MaxZoom)) then
      Result := nil
    else
      Result := (TmpStyle as TFillStyle);
  end
  else
  begin
    // create default style
    Result := TFillStyle.Create();
    Result.Name := s;
    Result.FillColor.InitRandom();
    AddStyleByName(s, Result);
  end;
end;

procedure TStyleConfig.GetAreaBorderStyles(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection; ABorderStyles: TBorderStyleList);
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Border';
  ABorderStyles.Clear();
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TBorderStyle) then
  begin
    if ((TmpStyle.MinZoom <> 0) and (AProjection.Magnification.Level < TmpStyle.MinZoom))
    or ((TmpStyle.MaxZoom <> 0) and (AProjection.Magnification.Level > TmpStyle.MaxZoom)) then
      Exit;
    ABorderStyles.Add(TmpStyle as TBorderStyle);
  end
  else
  begin
    // create default style
    TmpStyle := TBorderStyle.Create();
    TmpStyle.Name := s;
    (TmpStyle as TBorderStyle).Color.InitRandom();
    AddStyleByName(s, TmpStyle);
    ABorderStyles.Add(TmpStyle as TBorderStyle);
  end;
end;

function TStyleConfig.HasAreaTextStyles(ATypeInfo: TTypeInfo;
  const AMagnification: TMagnification): Boolean;
begin
  {$ifdef FPC}
  Result := (FNamedStyleMap.IndexOf(ATypeInfo.TypeName) <> -1);
  {$else}
  Result := FNamedStyleMap.ContainsKey(ATypeInfo.TypeName);
  {$endif}
end;

procedure TStyleConfig.GetAreaTextStyles(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection; ATextStyles: TTextStyleList);
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Text';
  ATextStyles.Clear();
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TTextStyle) then
  begin
    if ((TmpStyle.MinZoom <> 0) and (AProjection.Magnification.Level < TmpStyle.MinZoom))
    or ((TmpStyle.MaxZoom <> 0) and (AProjection.Magnification.Level > TmpStyle.MaxZoom)) then
      Exit;

    ATextStyles.Add(TmpStyle as TTextStyle);
  end
  else
  begin
    // create default style
    TmpStyle := TTextStyle.Create();
    TmpStyle.Name := s;
    (TmpStyle as TTextStyle).TextColor.InitRandom();
    (TmpStyle as TTextStyle).IsAutoSize := True;
    AddStyleByName(s, TmpStyle);
    ATextStyles.Add(TmpStyle as TTextStyle);
  end;
end;

function TStyleConfig.GetAreaIconStyle(const ABuffer: TFeatureValueBuffer;
  const AProjection: TProjection): TIconStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_Icon';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TIconStyle) then
    Result := (TmpStyle as TIconStyle)
  else
  begin
    // create default style
    Result := TIconStyle.Create();
    Result.Name := s;
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetAreaBorderTextStyle
  (const ABuffer: TFeatureValueBuffer; const AProjection: TProjection): TPathTextStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_PathText';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TPathTextStyle) then
    Result := (TmpStyle as TPathTextStyle)
  else
  begin
    // create default style
    Result := TPathTextStyle.Create();
    Result.Name := s;
    Result.TextColor.Init(0, 0, 0, 1);
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetAreaBorderSymbolStyle
  (const ABuffer: TFeatureValueBuffer; const AProjection: TProjection): TPathSymbolStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := ABuffer.TypeInfo.TypeName + '_PathSymbol';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TPathSymbolStyle) then
    Result := (TmpStyle as TPathSymbolStyle)
  else
  begin
    // create default style
    Result := TPathSymbolStyle.Create();
    Result.Name := s;
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetLandFillStyle(const AProjection: TProjection): TFillStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'land_fill';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TFillStyle) then
    Result := (TmpStyle as TFillStyle)
  else
  begin
    // create default style
    Result := TFillStyle.Create();
    Result.Name := s;
    Result.FillColor.InitFromBytes(254, 254, 229, 255);
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetSeaFillStyle(const AProjection: TProjection): TFillStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'sea_fill';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TFillStyle) then
    Result := (TmpStyle as TFillStyle)
  else
  begin
    // create default style
    Result := TFillStyle.Create();
    Result.FillColor.InitFromBytes(169, 210, 222, 255);
    AddStyleByName(s, Result);
  end;
end;

function TStyleConfig.GetCoastFillStyle(const AProjection: TProjection): TFillStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'coast_fill';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TFillStyle) then
    Result := (TmpStyle as TFillStyle)
  else
  begin
    // create default style
    Result := TFillStyle.Create();
    Result.FillColor.InitFromBytes(141, 174, 183, 255);
    AddStyleByName('coast_fill', Result);
  end;
end;

function TStyleConfig.GetUnknownFillStyle(const AProjection: TProjection): TFillStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'unknown_fill';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TFillStyle) then
    Result := (TmpStyle as TFillStyle)
  else
  begin
    // create default style
    Result := TFillStyle.Create();
    Result.FillColor.InitFromBytes(250, 250, 250, 255);
    AddStyleByName('unknown_fill', Result);
  end;
end;

function TStyleConfig.GetCoastlineLineStyle(const AProjection: TProjection): TLineStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'coast_line';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TLineStyle) then
    Result := (TmpStyle as TLineStyle)
  else
  begin
    // create default style
    Result := TLineStyle.Create();
    Result.Width := DEF_LINE_WIDTH;
    Result.LineColor.InitFromBytes(141, 174, 183, 255);
    AddStyleByName('coast_line', Result);
  end;
end;

function TStyleConfig.GetOSMTileBorderLineStyle(const AProjection: TProjection): TLineStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'osm_tile_border';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TLineStyle) then
    Result := (TmpStyle as TLineStyle)
  else
  begin
    // create default style
    Result := TLineStyle.Create();
    Result.Name := 'osm_tile_border';
    Result.Width := DEF_LINE_WIDTH;
    Result.LineColor.InitFromBytes(172, 172, 172, 255);
    AddStyleByName('osm_tile_border', Result);
  end;
end;

function TStyleConfig.GetOSMSubTileBorderLineStyle(const AProjection: TProjection): TLineStyle;
var
  TmpStyle: TStyle;
  s: string;
begin
  s := 'osm_sub_tile_border';
  TmpStyle := GetStyleByName(s);
  if Assigned(TmpStyle) and (TmpStyle is TLineStyle) then
    Result := (TmpStyle as TLineStyle)
  else
  begin
    // create default style
    Result := TLineStyle.Create();
    Result.Name := 'osm_sub_tile_border';
    Result.Width := DEF_LINE_WIDTH;
    Result.LineColor.InitFromBytes(172, 172, 172, 255);
    AddStyleByName('osm_sub_tile_border', Result);
  end;
end;

procedure TStyleConfig.RegisterFillStyleProcessor(ATypeIndex: Integer;
  AProcessor: TFillStyleProcessor);
begin
  if Length(FFillProcessors) <= ATypeIndex then
    SetLength(FFillProcessors, ATypeIndex+1);
  FFillProcessors[ATypeIndex] := AProcessor;
end;

function TStyleConfig.GetFillStyleProcessor(ATypeIndex: Integer): TFillStyleProcessor;
begin
  //Assert(ATypeIndex < Length(FFillProcessors));
  if ATypeIndex < Length(FFillProcessors) then
    Result := FFillProcessors[ATypeIndex]
  else
    Result := nil;
end;

{ TStyleResolveContext }

constructor TStyleResolveContext.Create(ATypeConfig: TTypeConfig);
begin
  inherited Create();
  FTypeConfig := ATypeConfig;
  FFeatureReaderMap.Init();
  FAccessReader.Init(ATypeConfig, ftAccess);
end;

destructor TStyleResolveContext.Destroy;
begin
  FreeAndNil(FFeatureReaderMap);
  inherited Destroy;
end;

function TStyleResolveContext.GetFeatureReaderIndex(AFeature: TFeature): Integer;
var
  n: Integer;
begin
  if not FFeatureReaderMap.FindValue(AFeature.GetName(), n) then
  begin
    n := Length(FFeatureReaders);
    SetLength(FFeatureReaders, n+1);
    FFeatureReaders[n].Init(FTypeConfig, AFeature.FeatureType);

    FFeatureReaderMap.Add(AFeature.GetName(), n);
  end;
  Result := n;
end;

function TStyleResolveContext.HasFeature(AFeatureIndex: Integer;
  const ABuffer: TFeatureValueBuffer): Boolean;
begin
  Result := FFeatureReaders[AFeatureIndex].IsSet(ABuffer);
end;

function TStyleResolveContext.GetFeatureName(AFeatureIndex: Integer): string;
begin
  Result := FFeatureReaders[AFeatureIndex].FeatureName;
end;

function TStyleResolveContext.GetFeatureValue(AFeatureIndex: Integer;
  const ABuffer: TFeatureValueBuffer): TFeatureValue;
begin
  Result := FFeatureReaders[AFeatureIndex].GetValue(ABuffer);
end;

function TStyleResolveContext.IsOneway(const ABuffer: TFeatureValueBuffer): Boolean;
begin
  Result := TAccessFeature.IsOneway(FAccessReader.GetValueByte(ABuffer));
end;

{ TStyleCriteria }

function TStyleCriteria.HasCriteria(): Boolean;
begin

end;

function TStyleCriteria.Matches(const AContext: TStyleResolveContext;
  const ABuffer: TFeatureValueBuffer; AMeterInPixel, AMeterInMM: TReal
  ): Boolean;
begin

end;

{ TNamedStyleMap }

{procedure TNamedStyleMap.AddOrSetData(AName: string; AValue: TStyle);
var
  n: Integer;
begin
  n := IndexOf(AName);
  if n <> -1 then
    Objects[n] := AValue
  else
    AddObject(AName, AValue);
end;

function TNamedStyleMap.TryGetData(AName: string; out AValue: TStyle): Boolean;
var
  n: Integer;
begin
  n := IndexOf(AName);
  Result := (n <> -1);
  if Result then
    AValue := Objects[n] as TStyle;
end;  }

end.

