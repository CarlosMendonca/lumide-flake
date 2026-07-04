# Builds a single Lumide package from one data/lumide.json entry.
#
# Lumide is a prebuilt Flutter Linux GTK3 app: a dynamically linked ELF plus
# bundled lib/*.so. autoPatchelfHook rewrites the interpreter + RPATH against
# nixpkgs, and wrapGAppsHook3 sets up the GTK/GApps environment.
{
  pkgs,
  lib,
  entry,
}:

let
  inherit (entry) version url sha256;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "lumide";
  inherit version;

  src = pkgs.fetchurl { inherit url sha256; };

  # Tarball's top-level directory.
  sourceRoot = "Lumide";

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.wrapGAppsHook3
    pkgs.makeWrapper
  ];

  # autoPatchelfHook rewrites the ELF interpreter and appends these to the RPATH
  # of the main binary and every bundled lib/*.so. The bundled plugins are found
  # via the binary's `$ORIGIN/lib` runpath.
  buildInputs = [
    pkgs.gtk3
    pkgs.glib
    pkgs.pango
    pkgs.cairo
    pkgs.harfbuzz
    pkgs.atk
    pkgs.gdk-pixbuf
    pkgs.libepoxy
    pkgs.fontconfig
    pkgs.stdenv.cc.cc.lib
  ];

  # libepoxy dlopen()s libGL/libEGL at runtime; keep it on the RPATH. On NixOS the
  # actual driver still comes from /run/opengl-driver; non-NixOS users need nixGL.
  runtimeDependencies = [ pkgs.libglvnd ];

  # libdartjni.so is the Dart<->JNI bridge; it's only dlopen'd if a JNI feature is
  # used, and the `jni` package locates a JVM at runtime (not via RPATH). Don't drag
  # a whole JDK into the closure for a bridge the editor doesn't exercise.
  autoPatchelfIgnoreMissingDeps = [ "libjvm.so" ];

  dontConfigure = true;
  dontBuild = true;

  # Wrap the real binary rather than symlinking it, so the GApps/GTK environment
  # (GSettings schemas, gdk-pixbuf loaders, etc.) is set up. wrapGAppsHook3 collects
  # those args into gappsWrapperArgs; we apply them ourselves.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/lumide
    cp -r . $out/opt/lumide

    install -Dm644 $out/opt/lumide/share/applications/io.sofluffy.lumide.desktop \
      $out/share/applications/io.sofluffy.lumide.desktop
    install -Dm644 $out/opt/lumide/share/icons/hicolor/512x512/apps/io.sofluffy.lumide.png \
      $out/share/icons/hicolor/512x512/apps/io.sofluffy.lumide.png

    makeWrapper $out/opt/lumide/Lumide $out/bin/lumide \
      "''${gappsWrapperArgs[@]}"

    runHook postInstall
  '';

  passthru = { inherit version; };

  meta = {
    description = "Desktop-first, GPU-accelerated code editor built with Flutter";
    homepage = "https://lumide.dev";
    downloadPage = "https://github.com/SoFluffyOS/lumide/releases";
    # Upstream ships no LICENSE and sets no license on the repo: all rights reserved.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ entry.system ];
    mainProgram = "lumide";
  };
}
