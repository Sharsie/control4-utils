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
          ];
        };
      });
    };
}
