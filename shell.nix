{
  lib,
  apple-sdk_15,
  cmakeMinimal,
  fetchFromGitHub,
  llvmPackages_latest,
  pkg-config,
  curl,
  ninja,
  mkShell,
  ccache,
}: let
  inherit (llvmPackages_latest) stdenv clang bintools openmp;
  inherit
    (lib)
    cmakeBool
    cmakeFeature
    optionals
    optionalString
    ;
in
  mkShell.override {inherit stdenv;} {
    nativeBuildInputs = [
      cmakeMinimal
      ninja
      pkg-config
      clang
      bintools
      ccache
    ];

    buildInputs = [
      apple-sdk_15
      curl
      openmp
    ];

    # the below stuff is useless in shell
    # use ./build.sh to build when shell is active
    #
    # preConfigure = ''
    #   cmakeFlagsArray+=(
    #     "-DCMAKE_C_FLAGS=-O3 -mcpu=native -pipe"
    #   )
    # '';

    # cmakeFlags = [
    #   (cmakeBool "GGML_NATIVE" true)
    #   (cmakeBool "GGML_LTO" true)
    #   (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    #   (cmakeBool "LLAMA_BUILD_SERVER" true)
    #   (cmakeBool "LLAMA_BUILD_TESTS" false)
    #   (cmakeBool "LLAMA_CURL" true)
    #   (cmakeBool "BUILD_SHARED_LIBS" true)
    #   (cmakeBool "GGML_METAL" true)
    #   (cmakeFeature "LLAMA_BUILD_NUMBER" "dev")
    #   (cmakeFeature "LLAMA_BUILD_COMMIT" "dev")
    #   (cmakeFeature "CMAKE_EXE_LINKER_FLAGS" "-fuse-ld=lld")
    #   (cmakeBool "GGML_METAL_EMBED_LIBRARY" true)
    # ];

    shellHook = ''
      unset SOURCE_DATE_EPOCH
    '';

    NIX_ENFORCE_NO_NATIVE = 0;
    enableParallelBuilding = true;

    hardeningDisable = ["all"];
  }
