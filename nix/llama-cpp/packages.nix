{
  perSystem = {config, ...}: let
    inherit (config) mkLlama;
    llama = mkLlama {};
  in {
    packages = {
      inherit llama;
      default = llama;
      llama-native = mkLlama {nativeSupport = true;};
    };
  };
}
