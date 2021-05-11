unit effekseer;

{$macro on}
{$mode delphi}
{$ifdef windows}
  {$define EFKCALL:=cdecl}
  {$define EFKLIB:='libeffekseer.dll'}
{$else}
  {$define EFKCALL:=cdecl}
  {$define EFKLIB:='libeffekseer.so'}
{$endif}

interface

uses
  Classes,
  ctypes, dynlibs;

type
  TEfkMatrix44Ptr = ^cfloat;
  TEfkOpenGLDeviceType = (
    edtOpenGL2,
    edtOpenGL3,
    edtOpenGLES2,
    edtOpenGLES3
  );

var
  // ----- Loader -----
  { FileName: PWideChar; var PasObj, Data: Pointer; var Size: cuint32 }
  EFK_Loader_RegisterLoadRoutine: procedure(Func: Pointer); EFKCALL;
  { FileName: PWideChar; var PasObj, Data: Pointer; var Width, Height, Bpp: cuint32 }
  EFK_Loader_RegisterLoadImageFromFileRoutine: procedure(Func: Pointer); EFKCALL;
  { PasObj: Pointer }
  EFK_Loader_RegisterFreeRoutine: procedure(Func: Pointer); EFKCALL;

  // ----- Manager -----

  EFK_Manager_Create: function(MaxInstance: cint): Pointer; EFKCALL;
  EFK_Manager_Destroy: procedure(Manager: Pointer); EFKCALL;
  EFK_Manager_SetDefaultRenders: procedure(Manager, Renderer: Pointer); EFKCALL;
  EFK_Manager_SetDefaultLoaders: procedure(Manager, Renderer: Pointer); EFKCALL;
  EFK_Manager_Update: procedure(Manager: Pointer; Delta: cfloat); EFKCALL;
  EFK_Manager_Play: function(Manager, Effect: Pointer; X, Y, Z: cfloat): cint32; EFKCALL;
  EFK_Manager_StopEffect: procedure(Manager: Pointer; Handle: cint32); EFKCALL;
  EFK_Manager_Exists: function(Manager: Pointer; Handle: cint32): cbool; EFKCALL;
  EFK_Manager_SetMatrix: procedure(Manager: Pointer; Handle: cint32; M: TEfkMatrix44Ptr); EFKCALL;

// ----- Renderer -----

  EFK_Renderer_Create: function(SquareMaxCount: cint; DeviceType: TEfkOpenGLDeviceType; IsExtensionsEnabled: cbool): Pointer; EFKCALL;
  EFK_Renderer_Destroy: procedure(Renderer: Pointer); EFKCALL;
  EFK_Renderer_SetViewMatrix: procedure(Renderer: Pointer; M: TEfkMatrix44Ptr); EFKCALL;
  EFK_Renderer_SetProjectionMatrix: procedure(Renderer: Pointer; M: TEfkMatrix44Ptr); EFKCALL;
  EFK_Renderer_Render: procedure(Renderer, Manager: Pointer); EFKCALL;
  EFK_Renderer_GetDrawCallCount: function(Renderer: Pointer): LongWord; EFKCALL;

// ----- Effect -----

  EFK_Effect_CreateWithFile: function(Manager: Pointer; FileName, MaterialPath: PWideChar): Pointer; EFKCALL;
  EFK_Effect_CreateWithMemory: function(Manager: Pointer; Data: Pointer; Size: cuint32; MaterialPath: PWideChar): Pointer; EFKCALL;
  EFK_Effect_Destroy: procedure(Effect: Pointer); EFKCALL;

function EFK_Load: Boolean;

implementation

function EFK_Load: Boolean;
var
  Lib: TLibHandle = dynlibs.NilHandle;
begin;
  Lib := LoadLibrary(EFKLIB);
  if Lib = dynlibs.NilHandle then Exit(False);

  EFK_Loader_RegisterLoadRoutine := GetProcedureAddress(Lib, 'EFK_Loader_RegisterLoadRoutine');
  EFK_Loader_RegisterLoadImageFromFileRoutine := GetProcedureAddress(Lib, 'EFK_Loader_RegisterLoadImageFromFileRoutine');
  EFK_Loader_RegisterFreeRoutine := GetProcedureAddress(Lib, 'EFK_Loader_RegisterFreeRoutine');

  EFK_Manager_Create := GetProcedureAddress(Lib, 'EFK_Manager_Create');
  EFK_Manager_Destroy := GetProcedureAddress(Lib, 'EFK_Manager_Destroy');
  EFK_Manager_SetDefaultRenders := GetProcedureAddress(Lib, 'EFK_Manager_SetDefaultRenders');
  EFK_Manager_SetDefaultLoaders := GetProcedureAddress(Lib, 'EFK_Manager_SetDefaultLoaders');
  EFK_Manager_Update := GetProcedureAddress(Lib, 'EFK_Manager_Update');
  EFK_Manager_Play := GetProcedureAddress(Lib, 'EFK_Manager_Play');
  EFK_Manager_StopEffect := GetProcedureAddress(Lib, 'EFK_Manager_StopEffect');
  EFK_Manager_Exists := GetProcedureAddress(Lib, 'EFK_Manager_Exists');
  EFK_Manager_SetMatrix := GetProcedureAddress(Lib, 'EFK_Manager_SetMatrix');

  EFK_Renderer_Create := GetProcedureAddress(Lib, 'EFK_Renderer_Create');
  EFK_Renderer_Destroy := GetProcedureAddress(Lib, 'EFK_Renderer_Destroy');
  EFK_Renderer_SetViewMatrix := GetProcedureAddress(Lib, 'EFK_Renderer_SetViewMatrix');
  EFK_Renderer_SetProjectionMatrix := GetProcedureAddress(Lib, 'EFK_Renderer_SetProjectionMatrix');
  EFK_Renderer_Render := GetProcedureAddress(Lib, 'EFK_Renderer_Render');
  EFK_Renderer_GetDrawCallCount := GetProcedureAddress(Lib, 'EFK_Renderer_GetDrawCallCount');

  EFK_Effect_CreateWithFile := GetProcedureAddress(Lib, 'EFK_Effect_CreateWithFile');
  EFK_Effect_CreateWithMemory := GetProcedureAddress(Lib, 'EFK_Effect_CreateWithMemory');
  EFK_Effect_Destroy := GetProcedureAddress(Lib, 'EFK_Effect_Destroy');

  Exit(True);
end;

end.
