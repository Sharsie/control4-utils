{
  inputs = {
    nix.url = "git+ssh://git@git.c3c.cz/C3C/nix";
  };

  outputs =
    { self, nix }:
    {
      formatter = nix.formatter;

      devShells = nix.lib.forAllSystems (pkgs: {
        default = pkgs.devshell.mkShell {
          name = "control4-library";

          packages = [
            pkgs.go
            nix.lib.control4_env.${pkgs.system}
          ];

          commands = [
            {
              name = "lint";
              help = "run linters";
              command = ''
                ${nix.lib.cd_root}
                ${pkgs.golangci-lint}/bin/golangci-lint run --sort-results --out-format tab --config ${nix.lib.golangci-config-file} ./...
              '';
            }
            {
              name = "fix";
              help = "format & fix found issues";
              command = ''
                ${nix.lib.cd_root}
                nix fmt .
                ${pkgs.golangci-lint}/bin/golangci-lint run --sort-results --out-format tab --config ${nix.lib.golangci-config-file} --fix --issues-exit-code 0 ./...
              '';
            }
            {
              name = "publish";
              command = ''
                [[ $# -eq 0 ]] && echo "Please provide a tag as the first parameter" && exit 1
                TAG=$1

                OTP=''${2:-}

                ${nix.lib.cd_root}

                [[ $(git tag -l "$TAG") ]] && echo "Tag already exists" && exit 1

                npm version $TAG --allow-same-version=true --git-tag-version=false
                git add package.json
                git commit -m "Update package to version $TAG"
                git tag -a $TAG -m ""
                [[ $OTP == "" ]] && npm publish --access public
                [[ $OTP != "" ]] && npm publish --access public --otp $OTP

                echo "Please push the new git commits and tag to the remote"
              '';
            }
          ];
        };
      });
    };
}
