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
          rev = "rev-${self.shortRev or self.dirtyShortRev}";
        in
        {
          devenv-up = self.devShells.${pkgs.system}.default.config.procfileScript;
          devenv-test = self.devShells.${pkgs.system}.default.config.test;
          driver-manager = pkgs.buildGoModule {
            inherit rev;

            name = "driver-manager";

            CGO_ENABLED = 0;

            src = ./.;
            subPackages = [ "tools/driver-manager" ];

            ldflags = [
              "-s"
              "-w"
              "-X main.rev=${rev}"
            ];

            vendorHash = null;
          };

          knx-group-address-generator = pkgs.buildGoModule {
            inherit rev;

            name = "knx-group-address-generator";

            CGO_ENABLED = 0;

            src = ./.;
            subPackages = [ "tools/knx-group-address-generator" ];

            ldflags = [
              "-s"
              "-w"
              "-X main.rev=${rev}"
            ];

            vendorHash = null;
          };
        }
      );

      devShells = nix.lib.forAllSystems (pkgs: {
        default = nix.lib.mkDevenvShell (
          let
            knxGroupAddressGeneratorPath = "./result-knx-group-address-generator-${pkgs.system}";
          in
          {
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
                  menu = {
                    description = "Print this menu";
                    exec = ''
                      echo "Commands:"
                      echo -n '${
                        builtins.toJSON (
                          builtins.mapAttrs (s: value: value.description) self.devShells.${pkgs.system}.default.config.scripts
                        )
                      }' | \
                      ${pkgs.jq}/bin/jq -r 'to_entries | map("  \(.key)\n" + "    - \(if .value == "" then "no description provided" else .value end)") | "" + .[]'
                    '';
                  };

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

                  tools-build = {
                    exec = ''
                      nix build -Lv .#driver-manager --out-link result-driver-manager
                      cp -f result-driver-manager/bin/driver-manager ./bin/driver-manager-${pkgs.system}
                      rm result-driver-manager

                      rm -f ${knxGroupAddressGeneratorPath}
                      nix build -Lv .#knx-group-address-generator --out-link ${knxGroupAddressGeneratorPath}
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
                      stylua ./src
                    '';
                  };

                  generate = {
                    exec = ''
                      ${nix.lib.cd_root}

                      tools-build

                      rm -rf ./src/knx/gen
                      ${knxGroupAddressGeneratorPath}/bin/knx-group-address-generator ./knx_group_addresses.csv ./src/knx/gen
                    '';
                  };

                  github-push = {
                    exec = ''
                      b=$(git rev-parse --abbrev-ref HEAD)
                      git push git@github.com:Sharsie/control4-utils.git "$b":"$b"
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

                      tools-build

                      [[ $OTP == "" ]] && npm publish --access public
                      [[ $OTP != "" ]] && npm publish --access public --otp $OTP

                      echo "Please push the new git commits and tag to the remote"
                    '';
                  };
                };
              }
            ];
          }
        );
      });
    };
}
