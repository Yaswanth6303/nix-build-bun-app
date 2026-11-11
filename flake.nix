{
  description = "A Nix flake to build cross-architecture OCI container images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      # Supported development platforms (Linux and macOS)
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      # Helper to generate outputs for all supported systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Docker requires Linux images. If you are on a Mac, you still want to build a Linux container.
      # We map development systems to their native Linux architecture for Docker.
      linuxSystemMap = {
        "x86_64-linux" = "x86_64-linux";
        "aarch64-linux" = "aarch64-linux";
        "x86_64-darwin" = "x86_64-linux";
        "aarch64-darwin" = "aarch64-linux";
      };

      # Function to generate a Docker image for a specific Linux architecture natively
      makeDockerImage = buildSystem: targetSystem:
        let
          # The packages for the machine doing the building (e.g. your Mac)
          buildPkgs = import nixpkgs { system = buildSystem; };
          
          # The packages for the container runtime (Linux)
          targetPkgs = import nixpkgs { system = targetSystem; };
          
          # Package our app. Since this just copies text files, we can build it 
          # using the native Mac builder! This avoids needing a Linux VM to run `cp`.
          app = buildPkgs.stdenv.mkDerivation {
            name = "bun-express-app";
            src = ./.;
            installPhase = ''
              mkdir -p $out/app
              cp -r package.json bun.lock src $out/app/
            '';
          };

          # Determine the OCI architecture string based on the target system
          ociArch = if targetSystem == "aarch64-linux" then "arm64" else "amd64";
        in 
          # We use the build platform's dockerTools so the build runs natively on your Mac
          buildPkgs.dockerTools.buildLayeredImage {
            name = "nix-bun-app-${targetSystem}";
            tag = "latest";
            
            # Explicitly set the architecture for the image metadata
            architecture = ociArch;
            
            # The runtime dependencies MUST be targetPkgs (Linux binaries)
            # The app itself is just text files, so the Mac-built derivation works fine
            contents = [ targetPkgs.bun targetPkgs.coreutils targetPkgs.bash app ];

            config = {
              Cmd = [ "${targetPkgs.bun}/bin/bun" "run" "src/index.ts" ];
              WorkingDir = "${app}/app";
              ExposedPorts = {
                "3000/tcp" = {};
              };
            };
          };
    in
    {
      # 1. Development Shell (nix develop)
      # This provides 'bun' natively on your current machine (Mac or Linux)
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            buildInputs = [ pkgs.bun ];
          };
        }
      );

      # 2. Container Images (nix build)
      packages = forAllSystems (system: 
        let
          targetLinuxSystem = linuxSystemMap.${system};
        in {
          # Default package: build the container for your machine's equivalent Linux architecture
          # (e.g. M1 Mac will default to building an ARM Linux image)
          default = makeDockerImage system targetLinuxSystem;
          
          # Explicit architectures (Cross-Architecture Builds)
          # You can build these from any machine natively
          x86_64-linux = makeDockerImage system "x86_64-linux";
          aarch64-linux = makeDockerImage system "aarch64-linux";
        }
      );
    };
}

