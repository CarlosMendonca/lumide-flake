{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  gtk3,
  glib,
  pango,
  cairo,
  harfbuzz,
  atk,
  gdk-pixbuf,
  libepoxy,
  fontconfig,
  libglvnd,
}:

let
  # Per-system release assets. Adding a platform is a data change here plus a
  # matching entry in `supportedSystems` in flake.nix, with no code changes needed.
  # Note the asset naming quirk: upstream calls the arm build "arm64", not "aarch64".
  sources = {
    "x86_64-linux" = {
      arch = "x86_64";
      hash = "sha256-yZak1katWrwgEjf43pAPXl2L6Kkjhed4ktzsUI3DHbE=";
    };
    # "aarch64-linux" = {
    #   arch = "arm64";
    #   hash = "sha256-...";  # fill in once upstream publishes a Linux arm64 asset
    # };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "lumide: no prebuilt asset for ${stdenv.hostPlatform.system} yet");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lumide";
  version = "0.14.0";

  src = fetchurl {
    url = "https://github.com/SoFluffyOS/lumide/releases/download/${finalAttrs.version}/Lumide-Linux-${finalAttrs.version}-${source.arch}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = "Lumide";

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  # autoPatchelfHook rewrites the ELF interpreter and appends these to the RPATH of
  # the main binary and every bundled lib/*.so. The bundled plugins themselves are
  # already found via the binary's `$ORIGIN/lib` runpath.
  buildInputs = [
    gtk3
    glib
    pango
    cairo
    harfbuzz
    atk
    gdk-pixbuf
    libepoxy
    fontconfig
    stdenv.cc.cc.lib
  ];

  # libepoxy dlopen()s libGL/libEGL at runtime; keep it on the RPATH. On NixOS the
  # actual driver still comes from /run/opengl-driver; non-NixOS users need nixGL.
  runtimeDependencies = [ libglvnd ];

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

  meta = {
    description = "Desktop-first, GPU-accelerated code editor built with Flutter";
    homepage = "https://lumide.dev";
    downloadPage = "https://github.com/SoFluffyOS/lumide/releases";
    # Upstream ships no LICENSE and sets no license on the repo: all rights reserved.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "lumide";
  };
})
