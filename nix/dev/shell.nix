{
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit (config) pre-commit;
  in {
    devShells.default = pkgs.mkShell.override {stdenv = pkgs.llvmPackages_22.stdenv;} {
      inputsFrom = [config.packages.llama-native];
      packages = pre-commit.settings.enabledPackages;

      shellHook = pre-commit.installationScript;
    };
  };
}
