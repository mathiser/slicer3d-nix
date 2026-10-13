{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  makeDesktopItem,
  glibcLocales,
  libx11,
  libxext,
  libsm,
  libice,
  libxcb,
  libxrender,
  libxi,
  libxrandr,
  libxcursor,
  libxfixes,
  libxcomposite,
  libxdamage,
  libxtst,
  libxscrnsaver,
  libxcb-util,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,
  libxcb-cursor,
  libxkbcommon,
  glib,
  zlib,
  pcre2,
  fontconfig,
  freetype,
  dbus,
  nspr,
  nss,
  at-spi2-core,
  at-spi2-atk,
  atk,
  cairo,
  pango,
  cups,
  expat,
  mesa,
  libGL,
  libGLU,
  libdrm,
  alsa-lib,
  libpulseaudio,
  udev,
}:

let
  pname = "slicer3d";
  version = "5.12.4";

  # download.slicer.org's "bitstream" links are stable, content-addressed
  # Girder item IDs, not version-named URLs, so the URL alone doesn't
  # change when the version does. To update: open https://download.slicer.org,
  # pick Stable Release -> Linux, and read the real ID off the resulting
  # download redirect (curl -sIL <bitstream-url>, look at Location).
  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://download.slicer.org/bitstream/6aa1beb7ce9de556d3010204";
      name = "Slicer-${version}-linux-amd64.tar.gz";
      sha256 = "0w53daf8g8gfjm9dsqa9rmrpnzcp5lisfq618i638sq4a8m3s6ii";
    };

    dontBuild = true;
    dontConfigure = true;
    # This is a complete, self-contained prebuilt Qt/VTK/ITK/Python tree.
    # In particular several vendored manylinux-wheel libs (scipy.libs,
    # numpy.libs) carry their own RPATH pointing at sibling libs (e.g.
    # libgfortran -> libquadmath); the default fixup phase's
    # `patchelf --shrink-rpath` wipes those out and breaks numpy/scipy/DICOM
    # imports at runtime. Skip ELF fixup entirely and ship the tree
    # byte-for-byte as Kitware built it.
    dontStrip = true;
    dontPatchShebangs = true;
    dontPatchELF = true;
    dontFixup = true;

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    exec = "slicer3d %F";
    icon = pname;
    desktopName = "3D Slicer";
    genericName = "Medical Image Analysis";
    comment = "Open-source platform for medical image informatics, image processing, and three-dimensional visualization";
    categories = [
      "Science"
      "MedicalSoftware"
    ];
    mimeTypes = [
      "application/x-nrrd"
      "image/x-nrrd"
      "application/dicom"
    ];
    keywords = [
      "DICOM"
      "MRI"
      "CT"
      "PET"
      "NIfTI"
      "segmentation"
      "registration"
    ];
    startupWMClass = "Slicer";
    startupNotify = true;
  };

  # Slicer's icon isn't bundled in the Linux tarball; pull it from upstream,
  # same source Slicer's own Flatpak (org.slicer.Slicer) uses.
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Slicer/Slicer/main/Applications/SlicerApp/Resources/Icons/XXLarge/Slicer-DesktopIcon.png";
    sha256 = "3e76e0da124634ada5db5e1149b2b30edffa9018744aef201631e27c1e676c33";
  };

  meta = {
    description = "Platform for medical image informatics, image processing, and three-dimensional visualization";
    longDescription = ''
      3D Slicer is a free, open source software package for visualization
      and image analysis. Slicer is built on top of a flexible, modular
      and extensible platform, and relies on community support and
      contribution to further its capabilities. Slicer is used in a
      variety of medical, biomedical, and related imaging research
      applications, including DICOM/NRRD/NIfTI image viewing, image
      registration and segmentation, and 3D visualization.
    '';
    homepage = "https://www.slicer.org/";
    license = {
      fullName = "3D Slicer Contribution and Software License Agreement";
      url = "https://github.com/Slicer/Slicer/blob/main/License.txt";
      free = true;
    };
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };

in
buildFHSEnv {
  inherit pname version meta;

  targetPkgs = _: [
    libx11
    libxext
    libsm
    libice
    libxcb
    libxrender
    libxi
    libxrandr
    libxcursor
    libxfixes
    libxcomposite
    libxdamage
    libxtst
    libxscrnsaver
    libxcb-util
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    libxcb-cursor
    libxkbcommon
    glib
    zlib
    pcre2
    fontconfig
    freetype
    dbus
    nspr
    nss
    at-spi2-core
    at-spi2-atk
    atk
    cairo
    pango
    cups
    expat
    mesa
    libGL
    libGLU
    libdrm
    alsa-lib
    libpulseaudio
    stdenv.cc.cc.lib
    glibcLocales
    # QtWebEngine's bundled Chromium dlopen()s libudev for device
    # enumeration (confirmed via strace: searches every lib dir in the
    # tree for libudev.so.1 and .so.0, finds neither, then crashes).
    # Nothing in Slicer's own tree ships it.
    udev
  ];

  # The host's locale (anything beyond plain C/en_US) needs glibc's locale
  # archive; LOCALE_ARCHIVE inherited from outside this environment points
  # at a host path that isn't bind-mounted inside it, so point it at the
  # archive built into this environment instead. Also disable QtWebEngine's
  # sandbox (it conflicts with running inside another sandbox) and force
  # the XCB platform plugin (Slicer's bundled Qt has no Wayland plugin).
  profile = ''
    export LOCALE_ARCHIVE="${glibcLocales}/lib/locale/locale-archive"
    export QTWEBENGINE_RESOURCES_PATH="${unwrapped}/resources"
    export QTWEBENGINE_LOCALES_PATH="${unwrapped}/share/QtTranslations/qtwebengine_locales"
    export QTWEBENGINE_DISABLE_SANDBOX=1
    export QT_QPA_PLATFORM=xcb
  '';

  # Slicer (Slicer_STORE_SETTINGS_IN_APPLICATION_HOME_DIR) always
  # reads/writes extension settings relative to SLICER_HOME:
  #   extension settings: $SLICER_HOME/slicer.org/Slicer-<rev>.ini
  #   default ext dir:    $SLICER_HOME/slicer.org/Extensions-<rev>
  # SLICER_HOME here is the read-only Nix store, so build a writable
  # SLICER_HOME that is a thin shell over the real install -- symlinks for
  # bin/, lib/, share/, etc. pointing back into the store, with only
  # slicer.org/ as a real writable directory -- and point SlicerApp-real at
  # it via --launcher-additional-settings. Same technique (and same
  # underlying problem) as Slicer's own Flatpak build:
  # https://github.com/mathiser/org.slicer.Slicer/blob/master/slicer.sh
  runScript = writeShellScript "${pname}-wrapper" ''
    SLICER_INSTALL="${unwrapped}"
    LAUNCHER_SETTINGS="$SLICER_INSTALL/bin/SlicerLauncherSettings.ini"
    REVISION=$(grep "^revision=" "$LAUNCHER_SETTINGS" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    REVISION="${"\${REVISION:-unknown}"}"

    SLICER_HOME_OVERRIDE="${"\${XDG_DATA_HOME:-$HOME/.local/share}"}/Slicer"
    SETTINGS_DIR="$SLICER_HOME_OVERRIDE/slicer.org"
    EXTENSIONS_DIR="$SETTINGS_DIR/Extensions-$REVISION"

    mkdir -p "$SLICER_HOME_OVERRIDE"
    for item in bin include lib libexec resources share Slicer; do
      link="$SLICER_HOME_OVERRIDE/$item"
      target="$SLICER_INSTALL/$item"
      if [ ! -e "$link" ] && [ -e "$target" ]; then
        ln -sf "$target" "$link"
      fi
    done

    mkdir -p "$SETTINGS_DIR" "$EXTENSIONS_DIR"

    SLICER_INI="$SETTINGS_DIR/Slicer.ini"
    XDG_INI="${"\${XDG_CONFIG_HOME:-$HOME/.config}"}/slicer.org/Slicer.ini"
    if [ ! -f "$SLICER_INI" ]; then
      if [ -f "$XDG_INI" ]; then cp "$XDG_INI" "$SLICER_INI"
      else touch "$SLICER_INI"; fi
    fi

    REV_INI="$SETTINGS_DIR/Slicer-$REVISION.ini"
    touch "$REV_INI"
    if ! awk '/^\[Extensions\]/{f=1;next}/^\[/{f=0}f&&/^InstallPath=/{exit 0}END{exit 1}' \
            "$REV_INI" 2>/dev/null; then
      if grep -q '^\[Extensions\]' "$REV_INI" 2>/dev/null; then
        sed -i "/^\[Extensions\]$/a InstallPath=$EXTENSIONS_DIR" "$REV_INI"
      else
        printf '\n[Extensions]\nInstallPath=%s\n' "$EXTENSIONS_DIR" >> "$REV_INI"
      fi
    fi

    OVERRIDE_INI="$(mktemp /tmp/slicer-launcher-XXXXXX.ini)"
    printf '[EnvironmentVariables]\nSLICER_HOME=%s\n' "$SLICER_HOME_OVERRIDE" > "$OVERRIDE_INI"
    trap "rm -f '$OVERRIDE_INI'" EXIT

    exec "$SLICER_INSTALL/Slicer" --launcher-additional-settings "$OVERRIDE_INI" "$@"
  '';

  extraInstallCommands = ''
    ln -s ${pname} $out/bin/Slicer

    install -Dm644 ${desktopItem}/share/applications/*.desktop $out/share/applications/${pname}.desktop
    install -Dm644 ${icon} $out/share/icons/hicolor/256x256/apps/${pname}.png
  '';

  passthru = {
    inherit unwrapped;
  };
}
