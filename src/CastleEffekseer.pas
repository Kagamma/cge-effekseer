{
  Copyright (c) 2021-2021 Trung Le (Kagamma).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
}

unit CastleEffekseer;

{$mode delphi}

interface

uses
  Classes, SysUtils, Generics.Collections,
  Effekseer,
  CastleVectors, CastleSceneCore, CastleApplicationProperties, CastleTransform, CastleComponentSerialize,
  CastleBoxes, CastleUtils, CastleLog, CastleRenderContext, CastleGLShaders, CastleDownload, CastleURIUtils,
  CastleImages;

type
  TEfkEffectRef = record
    RefCount: LongWord;
    Effect: Pointer;
  end;
  PEfkEffectRef = ^TEfkEffectRef;

  TEfkEffectCacheBase = TDictionary<String, PEfkEffectRef>;

  TEfkEffectCache = class(TEfkEffectCacheBase)
  public
    destructor Destroy; override;
    // Safely clear the cache while cheking effect refcount
    procedure ClearSafe;
    // Clear the cache regarding the effects is being used or not
    procedure Clear; override;
  end;

  TCastleEffekseer = class(TCastleSceneCore)
  strict private
    FURL: String;
    FIsNeedRefresh: Boolean;
    { Bypass GLContext problem }
    FIsGLContextInitialized: Boolean;
    EfkEffect: Pointer;
    EfkHandle: Integer;
    FSecondsPassed: Single;
    FTimePlayingSpeed: Single;
    { If true, repeat the emitter, by creating a new one to replace the "dead" one }
    FLoop: Boolean;
    { True if the emitter (handle) exists in manager }
    FIsExistsInManager: Boolean;
    { If true, free the scene once the emitter is done emitting }
    FReleaseWhenDone: Boolean;
    { Create Effekseer's global Manager and Renderer }
    procedure GLContextOpen;
    procedure InternalRefreshEffect;
    procedure SetPlayingSpeed(V: Single);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure GLContextClose; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure LocalRender(const Params: TRenderParams); override;
    procedure RefreshEffect;
    procedure LoadEffect(const AURL: String);
    { If true, and Loop is false, remove this scene when emitter is "dead" }
    property ReleaseWhenDone: Boolean read FReleaseWhenDone write FReleaseWhenDone;
  published
    property TimePlayingSpeed: Single read FTimePlayingSpeed write SetPlayingSpeed default 1.0;
    { URL of an effekseer file. This will call LoadEffect to load particle effect }
    property URL: String read FURL write LoadEffect;
    { URL of an effekseer file. This will call LoadEffect to load particle effect }
    property Loop: Boolean read FLoop write FLoop default False;
  end;

var
  { Maximum number of sprites }
  EfkMaximumNumberOfSprites: Integer = 8192;
  { Set graphics backend for desktop platform }
  EfkDesktopRenderBackend: TEfkOpenGLDeviceType = edtOpenGL2;
  { Set graphics backend for mobile platform }
  EfkMobileRenderBackend: TEfkOpenGLDeviceType = edtOpenGLES2;
  { Use CGE's own image loader. If set to false then it will fallback to use stb as loader }
  EfkUseCGEImageLoader: Boolean = True;
  // Catch effect
  EfkEffectCache: TEfkEffectCache;

implementation

var
  EfkManager: Pointer = nil;
  EfkRenderer: Pointer;
  IsManagerUpdated: Boolean = False;

{ Call when OpenGL context is closed }
procedure FreeEfkContext;
begin
  if EfkManager <> nil then
  begin
    EFK_Manager_Destroy(EfkManager);
    EFK_Renderer_Destroy(EfkRenderer);
    EfkManager := nil;
    EfkRenderer := nil;
  end;
end;

{ Provide loader function for Effekseer }
procedure LoaderLoad(FileName: PWideChar; var MS: TMemoryStream; var Data: Pointer; var Size: LongWord); cdecl;
var
  S: String;
begin
  try
    S := FileName;
    // In case it load a material, force it to load .efkmat instead of .efkmatd
    if LowerCase(ExtractFileExt(FileName)) = '.efkmatd' then
      Delete(S, Length(S), 1);
    MS := Download(S, [soForceMemoryStream]) as TMemoryStream;
    Data := MS.Memory;
    Size := MS.Size;
  except
    // We ignore exception, and return null instead
    on E: Exception do
    begin
      WritelnLog('Error', 'LoaderLoad: ' + E.Message + ' while loading ' + S);
      MS := nil;
      Data := nil;
      Size := 0;
    end;
  end;
end;

{ Provide image loader function for Effekseer }
procedure LoaderLoadImageFromFile(FileName: PWideChar; var Image: TCastleImage; var Data: Pointer; var Width, Height, Bpp: LongWord); cdecl;
begin
  try
    Image := LoadImage(FileName);
    Data := Image.RawPixels;
    Width := Image.Width;
    Height := Image.Height;
    Bpp := Image.PixelSize;
  except
    // We ignore exception, and return null instead
    on E: Exception do
    begin
      WritelnLog('Error', 'LoadImageFromFile: ' + E.Message + ' while loading ' + FileName);
      Image := nil;
      Data := nil;
    end;
  end;
end;

{ Free FP's Stream object }
procedure LoaderFree(MS: TMemoryStream); cdecl;
begin
  FreeAndNil(MS);
end;

{ ----- TEfkEffectCache ----- }

destructor TEfkEffectCache.Destroy;
begin
  inherited;
end;

procedure TEfkEffectCache.ClearSafe;
var
  Key: String;
  I: Integer;
  EffectRef: PEfkEffectRef;
begin
  for I := Self.Count - 1 downto 0 do
  begin
    Key := Self.Keys.ToArray[I];
    EffectRef := Self[Key];
    if EffectRef^.RefCount <= 0 then
    begin
      EFK_Effect_Destroy(EffectRef^.Effect);
      Dispose(EffectRef);
      Self.Remove(Key);
    end;
  end;
end;

procedure TEfkEffectCache.Clear;
var
  Key: String;
  EffectRef: PEfkEffectRef;
begin
  for Key in Self.Keys do
  begin
    EffectRef := Self[Key];
    EFK_Effect_Destroy(EffectRef^.Effect);
    Dispose(EffectRef);
  end;
  inherited;
end;

{ ----- TCastleEffekseer ----- }

procedure TCastleEffekseer.GLContextOpen;
var
  RenderBackend: TEfkOpenGLDeviceType;
  RenderBackendName: String;
begin
  // Safeguard
  if not ApplicationProperties.IsGLContextOpen then Exit;
  if Self.FIsGLContextInitialized then Exit;

  if EfkManager = nil then
  begin
    if EFK_Load then
    begin
      {$if defined(ANDROID) or defined(IOS)}
        RenderBackend := EfkMobileRenderBackend;
      {$else}
        RenderBackend := EfkDesktopRenderBackend;
      {$endif}
      WriteStr(RenderBackendName, RenderBackend);
      WritelnLog('Effekseer''s render backend: ' + RenderBackendName);
      EfkManager := EFK_Manager_Create(EfkMaximumNumberOfSprites);
      EfkRenderer := EFK_Renderer_Create(EfkMaximumNumberOfSprites, RenderBackend, True);

      EFK_Loader_RegisterLoadRoutine(@LoaderLoad);
      EFK_Loader_RegisterFreeRoutine(@LoaderFree);
      if EfkUseCGEImageLoader then
        EFK_Loader_RegisterLoadImageFromFileRoutine(@LoaderLoadImageFromFile);

      EFK_Manager_SetDefaultRenders(EfkManager, EfkRenderer);
      EFK_Manager_SetDefaultLoaders(EfkManager, EfkRenderer);

      ApplicationProperties.OnGLContextClose.Add(@FreeEfkContext);
    end else
      WritelnWarning('Effekseer', 'Could not load the Effekseer library.  Make sure you placed the relevant libraries (libeffekseer.dll, libeffekseer.so...) inside the project. On Unix, also make sure you run with LD_LIBRARY_PATH pointing to these libraries.');
  end;

  Self.FIsGLContextInitialized := True;
end;

procedure TCastleEffekseer.InternalRefreshEffect;
var
  P: array[0..2047] of WideChar;
  I: Integer;
  Path: String;
  MS: TMemoryStream;
  EffectRef: PEfkEffectRef;
  Key: String;
  M: TMatrix4;
begin
  if EfkManager <> nil then
  begin
    for I := 0 to High(P) do
      P[I] := #0;
    if EFK_Manager_Exists(EfkManager, Self.EfkHandle) then
      EFK_Manager_StopEffect(EfkManager, Self.EfkHandle);
    // Take care of old effect
    if Self.EfkEffect <> nil then
      for Key in EfkEffectCache.Keys do
      begin
        EffectRef := EfkEffectCache[Key];
        if EffectRef^.Effect = Self.EfkEffect then
        begin
          Dec(EffectRef^.RefCount);
          Break;
        end;
      end;
    // Extract material path from file path, assuming textures and materials are in
    // the same place as .efk file
    Path := ExtractURIPath(Self.FURL);
    StringToWideChar(Path, P, Length(Path) + 1);
    if not CastleDesignMode then
    begin
      if not EfkEffectCache.ContainsKey(Self.FURL) then
      begin
        // We use Download to create a TMemoryStream, then pass the pointer to EFK loader
        MS := Download(Self.FURL, [soForceMemoryStream]) as TMemoryStream;
        Self.EfkEffect := EFK_Effect_CreateWithMemory(EfkManager, MS.Memory, MS.Size, P);
        FreeAndNil(MS);
        New(EffectRef);
        EffectRef^.RefCount := 1;
        EffectRef^.Effect := Self.EfkEffect;
        EfkEffectCache.Add(Self.FURL, EffectRef);
      end else
      begin
        EffectRef := EfkEffectCache[Self.FURL];
        Inc(EffectRef^.RefCount);
        Self.EfkEffect := EffectRef^.Effect;
      end;
    end else
    // We dont cache effect in design mode
    begin
      // We use Download to create a TMemoryStream, then pass the pointer to EFK loader
      MS := Download(Self.FURL, [soForceMemoryStream]) as TMemoryStream;
      Self.EfkEffect := EFK_Effect_CreateWithMemory(EfkManager, MS.Memory, MS.Size, P);
      FreeAndNil(MS);
    end;
    M := Self.WorldTransform;
    Self.EfkHandle := EFK_Manager_Play(EfkManager, Self.EfkEffect, @M.Data[3,0], 0);
    EFK_Manager_SetSpeed(EfkManager, Self.EfkHandle, Self.TimePlayingSpeed);
    Self.FIsNeedRefresh := False;
  end;
end;

procedure TCastleEffekseer.SetPlayingSpeed(V: Single);
begin
  Self.FTimePlayingSpeed := V;
  if Self.FIsExistsInManager and (EfkManager <> nil) then
    EFK_Manager_SetSpeed(EfkManager, Self.EfkHandle, Self.TimePlayingSpeed);
end;

constructor TCastleEffekseer.Create(AOwner: TComponent);
begin
  inherited;
  Self.FIsGLContextInitialized := False;
  Self.FIsNeedRefresh := False;
  Self.EfkEffect := nil;
  Self.EfkHandle := -1;
  Self.FReleaseWhenDone := False;
  Self.FTimePlayingSpeed := 1;
end;

destructor TCastleEffekseer.Destroy;
begin
  // EfkManager may be destroyed when OpenGL context closes first
  if (Self.EfkEffect <> nil) and (EfkManager <> nil) then
  begin
    if EFK_Manager_Exists(EfkManager, Self.EfkHandle) then
      EFK_Manager_StopEffect(EfkManager, Self.EfkHandle);
  end;
  inherited;
end;

procedure TCastleEffekseer.GLContextClose;
var
  EffectRef: PEfkEffectRef;
begin
  // We dont cache effect in design mode, so we free it here
  if Self.FIsGLContextInitialized then
  begin
    if Self.EfkEffect <> nil then
    begin
      if CastleDesignMode then
        EFK_Effect_Destroy(Self.EfkEffect)
      else
      // There're chances EfkEffectCache get freed first, which called Clear, render this useless
      if EfkEffectCache <> nil then
      begin
        EffectRef := EfkEffectCache[Self.FURL];
        Dec(EffectRef^.RefCount);
      end;
    end;
  end;
  inherited;
end;

procedure TCastleEffekseer.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  M: TMatrix4;
begin
  inherited;
  Self.GLContextOpen;

  if Self.FIsNeedRefresh then
    Self.InternalRefreshEffect;

  RemoveMe := rtNone;
  if (Self.FIsGLContextInitialized) and (Self.EfkEffect <> nil) then
  begin
    // Emitter is considered "not exists" only when all of it's nodes is dead
    Self.FIsExistsInManager := EFK_Manager_Exists(EfkManager, Self.EfkHandle);
    if Self.FLoop and (not Self.FIsExistsInManager) then
    begin
      M := Self.WorldTransform;
      Self.EfkHandle := EFK_Manager_Play(EfkManager, Self.EfkEffect, @M.Data[3,0], 0);
      EFK_Manager_SetSpeed(EfkManager, Self.EfkHandle, Self.TimePlayingSpeed);
      Self.FIsExistsInManager := True;
    end;

    IsManagerUpdated := True;
    Self.FSecondsPassed := SecondsPassed;

    // Yes we dont want this happen while in design mode...
    if Self.FReleaseWhenDone and (not Self.FIsExistsInManager) and (not CastleDesignMode) then
    begin
      RemoveMe := rtRemoveAndFree;
    end;
  end;
end;

procedure TCastleEffekseer.LocalRender(const Params: TRenderParams);
var
  PreviousProgram: TGLSLProgram;
  DrawCalls: LongWord;
begin
  inherited;
  if Self.EfkEffect = nil then
    Exit;
  if not Self.FIsGLContextInitialized then
    Exit;
  if (not Self.Visible) or Params.InShadow or (not Params.Transparent) or (Params.StencilTest > 0) then
    Exit;
  if Self.FIsExistsInManager then
  begin
    EFK_Manager_SetMatrix(EfkManager, Self.EfkHandle, TEfkMatrix44Ptr(@Params.Transform^.Data));
    // Since Effekseer has it's own culling, and there's a lack of information on which handle is visible,
    // these statistics are not accurate when represent TCastleEffekseer
    Inc(Params.Statistics.ScenesVisible);
    Inc(Params.Statistics.ScenesRendered);
  end;
  if not IsManagerUpdated then
    Exit;

  PreviousProgram := RenderContext.CurrentProgram;

  EFK_Manager_Update(EfkManager, FSecondsPassed / (1 / 60));
  EFK_Manager_SetMatrix(EfkManager, Self.EfkHandle, TEfkMatrix44Ptr(@Params.Transform^.Data));
  EFK_Renderer_SetViewMatrix(EfkRenderer, TEfkMatrix44Ptr(@Params.RenderingCamera.Matrix.Data));
  EFK_Renderer_SetProjectionMatrix(EfkRenderer, TEfkMatrix44Ptr(@RenderContext.ProjectionMatrix.Data));
  EFK_Renderer_Render(EfkRenderer, EfkManager);

  // DrawCalls is considered as "ShapesRendered" at the moment
  DrawCalls := EFK_Renderer_GetDrawCallCount(EfkRenderer);
  Inc(Params.Statistics.ShapesVisible, DrawCalls);
  Inc(Params.Statistics.ShapesRendered, DrawCalls);

  IsManagerUpdated := False;

  if PreviousProgram <> nil then
  begin
    PreviousProgram.Disable;
    PreviousProgram.Enable;
  end;
end;

procedure TCastleEffekseer.RefreshEffect;
begin
  Self.FIsNeedRefresh := True;
end;

procedure TCastleEffekseer.LoadEffect(const AURL: String);
begin
  Self.FURL := AURL;
  Self.RefreshEffect;
end;

initialization
  RegisterSerializableComponent(TCastleEffekseer, 'Effekseer Emitter');
  EfkEffectCache := TEfkEffectCache.Create;

finalization
  FreeAndNil(EfkEffectCache);

end.
