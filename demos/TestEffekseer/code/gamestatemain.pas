{ Main state, where most of the application logic takes place.

  Feel free to use this code as a starting point for your own projects.
  (This code is in public domain, unlike most other CGE code which
  is covered by the LGPL license variant, see the COPYING.txt file.) }
unit GameStateMain;

interface

uses Classes,
  CastleUIState, CastleComponentSerialize, CastleUIControls, CastleControls,
  CastleKeysMouse, CastleViewport, CastleVectors, CastleEffekseer;

type
  { Main state, where most of the application logic takes place. }
  TStateMain = class(TUIState)
  private
    { Components designed using CGE editor, loaded from gamestatemain.castle-user-interface. }
    LabelFps: TCastleLabel;
    Viewport: TCastleViewport;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure Render; override;
  end;

var
  StateMain: TStateMain;

implementation

uses SysUtils;

{ TStateMain ----------------------------------------------------------------- }

constructor TStateMain.Create(AOwner: TComponent);
begin
  inherited;
  Self.DesignUrl := 'castle-data:/gamestatemain.castle-user-interface';
end;

procedure TStateMain.Start;
var
  I: Integer;
  Emitter: TCastleEffekseer;
begin
  inherited;

  { Find components, by name, that we need to access from code }
  Self.LabelFps := Self.DesignedComponent('LabelFps') as TCastleLabel;
  Self.Viewport := Self.DesignedComponent('Viewport') as TCastleViewport;
  { Note: do not add with I = 0, as it would overlap with TCastleEffekseer
    present already in designed castle-data:/gamestatemain.castle-user-interface }
  for I := 1 to 3 do
  begin
    Emitter := TCastleEffekseer.Create(Self);
    Emitter.URL := 'castle-data:/efk/Laser01.efk';
    Emitter.Translation := Vector3(I * 15, 0, 0);
    Emitter.Rotation := Vector4(0, 1, 0, PI / 4 * I);
    Emitter.Loop := True;
    Viewport.Items.Add(Emitter);
  end;
end;

procedure TStateMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  { This virtual method is executed every frame.}
  Self.LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
end;

procedure TStateMain.Render;
begin
  inherited;
end;

end.
