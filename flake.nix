{
  description = "Hivemind infrastructure challenge greeter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      greeter = pkgs.stdenv.mkDerivation {
        pname = "greeter";
        version = "0.1.0";

        src = ./.;

        nativeBuildInputs = [ pkgs.go ];

        buildPhase = ''
          runHook preBuild

          export CGO_ENABLED=0
          export GOCACHE="$TMPDIR/go-cache"
          go build -trimpath -ldflags="-s -w" -o greeter ./greeter.go

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          install -Dm755 greeter "$out/bin/greeter"

          runHook postInstall
        '';

        meta = {
          mainProgram = "greeter";
        };
      };

      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "greeter";
        tag = "latest";

        config = {
          Cmd = [ "${greeter}/bin/greeter" ];
          ExposedPorts = {
            "8080/tcp" = { };
          };
        };
      };
    in
    {
      packages.${system} = {
        inherit greeter dockerImage;
        default = greeter;
      };

      apps.${system}.default = {
        type = "app";
        program = "${greeter}/bin/greeter";
        meta = {
          description = "Run the greeter service";
        };
      };

      checks.${system} = {
        inherit greeter dockerImage;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          awscli2
          opentofu
          just
          pre-commit
          treefmt
          nixfmt-rfc-style
          yamlfmt
          mdformat
          yamllint
          tflint
          trivy
          k3d
          kubectl
          kubernetes-helm
          kubeconform
          go
          jq
          bash
        ];

        shellHook = ''
          if ! helm plugin list 2>/dev/null | grep -q unittest; then
            helm plugin install https://github.com/helm-unittest/helm-unittest >/dev/null 2>&1 || true
          fi
        '';
      };
    };
}
