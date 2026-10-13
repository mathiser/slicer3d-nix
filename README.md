# slicer3d-nix

A Nix package for [3D Slicer](https://www.slicer.org/), wrapping Kitware's
prebuilt Linux tarball in a `buildFHSEnv` sandbox. Not in nixpkgs yet (see
[NixOS/nixpkgs#355116](https://github.com/NixOS/nixpkgs/pull/355116) for a
stalled attempt); this package fixes the issues that stalled it:

- Vendored manylinux-wheel libs (scipy/numpy) carry their own RPATH that
  nixpkgs' default ELF fixup strips, breaking DICOM import — fixed via
  `dontFixup`.
- QtWebEngine's bundled Chromium needs `libudev`, which nothing in Slicer's
  own tree ships — crashes on opening the Extensions Manager otherwise.
- Slicer hardcodes extension settings relative to `SLICER_HOME`, which is
  read-only here (the Nix store) — fixed with a writable-`SLICER_HOME`
  symlink farm, the same technique used in this package's companion
  Flatpak build, [org.slicer.Slicer](https://github.com/mathiser/org.slicer.Slicer).

## Usage

Standalone build:

```sh
nix-build
./result/bin/slicer3d
```

Or add the overlay to your NixOS configuration for `pkgs.slicer3d`:

```nix
nixpkgs.overlays = [ (import /path/to/slicer3d-nix/overlay.nix) ];
environment.systemPackages = [ pkgs.slicer3d ];
```

## Updating

`download.slicer.org`'s "bitstream" links are stable, content-addressed
Girder item IDs, not version-named URLs — there's no `nix-update` support.
To bump the version:

1. Open <https://download.slicer.org>, pick the release, find the real
   bitstream ID: `curl -sIL <bitstream-url>` and read the `Location` header.
2. Prefetch the hash: `nix-prefetch-url --type sha256 <bitstream-url>`.
3. Update `version`, `url`, and `sha256` in `package.nix`.
4. `nix-build` and smoke-test, including opening the Extensions Manager.
