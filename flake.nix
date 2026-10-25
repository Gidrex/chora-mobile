{
  description = "chora-mobile dev environment: real FVM + JDK 17 + Rust + Android SDK wiring";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAll (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            # Flutter itself stays with FVM (pinned in .fvmrc); nix owns the toolchain around it.
            packages = with pkgs; [
              fvm
              jdk17
              just
              android-tools
              rustup
            ];
            shellHook = ''
              export JAVA_HOME=${pkgs.jdk17}
              # Reuse the host Android SDK (platforms, emulator, NDK already there): no re-downloads.
              if [ -d "$HOME/Android/Sdk" ]; then
                export ANDROID_HOME="''${ANDROID_HOME:-$HOME/Android/Sdk}"
                export ANDROID_SDK_ROOT="$ANDROID_HOME"
                export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
                ndk=$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -n 1)
                [ -n "$ndk" ] && export ANDROID_NDK_HOME="''${ANDROID_NDK_HOME:-$ndk}"
              fi
              # One-time Rust toolchain (targets for cargokit): rustup toolchain install stable
            '';
          };
        }
      );
    };
}
