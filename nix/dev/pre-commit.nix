{inputs, ...}: {
  imports = [
    inputs.git-hooks.flakeModule
  ];
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    pre-commit = {
      check.enable = true;

      settings = {
        # Keep the committed .pre-commit-config.yaml available for non-Nix users.
        configPath = ".pre-commit-config-nix.yaml";
        hooks = {
          alejandra.enable = true;
          deadnix.enable = true;
          nil.enable = true;
          statix.enable = true;
        };
      };
    };

    apps.install-hooks = {
      type = "app";
      program = toString (pkgs.writeShellScript "install-hooks" ''
        ${config.pre-commit.installationScript}
        echo "Pre-commit hooks installed"
      '');
      meta.description = "Install pre-commit hooks";
    };
  };
}
