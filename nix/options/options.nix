{lib, ...}: {
  options = {
    version = lib.mkOption {
      type = lib.types.str;
    };
    src = lib.mkOption {
      type = lib.types.path;
    };
    cudaSupport = lib.mkOption {
      type = lib.types.bool;
    };
    metalSupport = lib.mkOption {
      type = lib.types.bool;
    };
    rocmSupport = lib.mkOption {
      type = lib.types.bool;
    };
    vulkanSupport = lib.mkOption {
      type = lib.types.bool;
    };
    webUISupport = lib.mkOption {
      type = lib.types.bool;
    };
  };
}
