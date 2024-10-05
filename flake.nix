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
                # [[ $(git status --porcelain) != "" ]] && echo "Please commit or discard your latest changes" && exit 1
                [[ $# -eq 0 ]] && echo "Please provide a tag as the first parameter" && exit 1
                TAG=$1

                ${nix.lib.cd_root}

                npm version $TAG --allow-same-version=true --git-tag-version=false
                git add package.json package-lock.json
                git commit -m "Update package to version $TAG"
                git tag -a $TAG -m ""
                npm publish --access public
                echo "Please push the new git commits and tag to the remote"
              '';
            }
          ];
        };
      });
    };
}
