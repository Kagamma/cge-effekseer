{ AUTO-GENERATED PROGRAM FILE.

  Used to to build and run the application on desktop (standalone) platforms,
  from Lazarus or the build tool.

  You should not modify this file manually.
  Regenerate it using CGE editor "Regenerate Program" menu item
  (or command-line: "castle-engine generate-program").
  Along with this file, we also generate CastleAutoGenerated unit. }

{ Do not specify program name below.
  It is not used anyway, and this way allows developer
  to change standalone_source in CastleEngineManifest.xml easier. }
// program TestEffekseer_standalone;

{$ifdef MSWINDOWS}{$endif}

{ This adds icons and version info for Windows,
  automatically created by "castle-engine compile". }
{$ifdef CASTLE_AUTO_GENERATED_RESOURCES} {$R castle-auto-generated-resources.res} {$endif}

uses
  {$ifndef CASTLE_DISABLE_THREADS}
    {$info Thread support enabled.}
    {$ifdef UNIX} CThreads, {$endif}
  {$endif}
  CastleWindow, GameInitialize;

begin
  Application.MainWindow.OpenAndRun;
end.
