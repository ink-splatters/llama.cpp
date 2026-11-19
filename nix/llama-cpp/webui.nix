top @ {lib, ...}: {
  perSystem = {pkgs, ...}: {
    options.mkLlamaWebUI = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
    };

    config.mkLlamaWebUI = _: let
      inherit (top.config) src version;
      inherit (pkgs) stdenvNoCC bun;
    in
      stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "llama-webui";
        inherit version;
        src = lib.cleanSource (src + "/ui/lib/ui");
        nativeBuildInputs = [bun];
        npmDeps = pkgs.importNpmLock {
          npmRoot = finalAttrs.src;
        };
        configurePhase = ''
          runHook preConfigure
          cp "$npmDeps/package.json" package.json
          cp "$npmDeps/package-lock.json" package-lock.json
          bun pm migrate
          bun install --offline --frozen-lockfile --ignore-scripts --cache-dir "$TMPDIR/bun-cache"
          bun --bun --no-install run svelte-kit sync
          runHook postConfigure
        '';
        installPhase = ''
          runHook preInstall
          LLAMA_UI_OUT_DIR="$out" bun --bun --no-install run build
          runHook postInstall
        '';
      });
  };
}
