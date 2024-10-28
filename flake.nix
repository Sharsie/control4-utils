{
  inputs = {
    nix.url = "git+ssh://git@git.c3c.cz/C3C/nix";
  };

  outputs =
    { self, nix }:
    {
      formatter = nix.formatter;

      packages = nix.lib.forAllSystems (
        pkgs:
        let
          version = "rev-${self.shortRev or self.dirtyShortRev}";
        in
        {
          devenv-up = self.devShells.${pkgs.system}.default.config.procfileScript;
          devenv-test = self.devShells.${pkgs.system}.default.config.test;
          driver-manager = pkgs.buildGoModule {
            inherit version;

            pname = "driver-manager";

            CGO_ENABLED = 0;

            src = ./.;
            subPackages = [ "tools/driver-manager" ];

            ldflags = [
              "-s"
              "-w"
              "-X main.version=${version}"
            ];

            vendorHash = null;
          };
        }
      );

      devShells = nix.lib.forAllSystems (pkgs: {
        default = nix.lib.mkDevenvShell {
          inherit pkgs;

          inputs = {
            self = self;
            nixpkgs = pkgs;
          };

          modules = [
            {
              packages = [
                pkgs.go
                nix.lib.control4_env.${pkgs.system}
              ];

              scripts = {
                # Override golangci-lint for vscode, because the extension incorrectly assumes usage of global binaries is preferred
                golangci-lint = {
                  exec = ''
                    CMD=''${1:-}
                    if [[ "$CMD" == "run" ]]; then
                      shift
                      ${pkgs.golangci-lint}/bin/golangci-lint run --config ${nix.lib.golangci-config-file} $@
                    else
                      ${pkgs.golangci-lint}/bin/golangci-lint $@
                    fi
                  '';
                };

                tools-buils = {
                  exec = ''
                    nix build -Lv .#driver-manager
                    cp -f result/bin/driver-manager ./bin/driver-manager-${pkgs.system}
                  '';
                };

                lint = {
                  exec = ''
                    ${nix.lib.cd_root}
                    ${pkgs.golangci-lint}/bin/golangci-lint run --sort-results --out-format tab --config ${nix.lib.golangci-config-file} ./...
                  '';
                };

                fix = {
                  exec = ''
                    ${nix.lib.cd_root}
                    nix fmt ./*.nix
                    ${pkgs.golangci-lint}/bin/golangci-lint run --sort-results --out-format tab --config ${nix.lib.golangci-config-file} --fix --issues-exit-code 0 ./...
                  '';
                };

                generate = {
                  exec = ''
                    ${nix.lib.cd_root}
                    rm -rf ./src/knx/gen
                    go run ./tools/knx-group-address-generator ./knx_group_addresses.csv ./src/knx/gen
                  '';
                };

                publish = {
                  exec = ''
                    ${nix.lib.cd_root}
                    [[ $# -eq 0 ]] && echo "Please provide a tag as the first parameter" && exit 1
                    TAG=$1
                    OTP=''${2:-}

                    ${nix.lib.cd_root}

                    [[ $(git tag -l "$TAG") ]] && echo "Tag already exists" && exit 1

                    npm version $TAG --allow-same-version=true --git-tag-version=false
                    git add package.json
                    git add package-lock.json
                    git commit -m "Update package to version $TAG"
                    git tag -a $TAG -m ""

                    tools-buils

                    [[ $OTP == "" ]] && npm publish --access public
                    [[ $OTP != "" ]] && npm publish --access public --otp $OTP

                    echo "Please push the new git commits and tag to the remote"
                  '';
                };
              };
            }
          ];
        };
      });
    };
}
