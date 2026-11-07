top @ {lib, ...}: let
  inherit
    (lib)
    cmakeBool
    cmakeFeature
    optionals
    optionalString
    ;
  inherit (builtins) toString;
in {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit
      (pkgs)
      autoAddDriverRunpath
      cmakeMinimal
      cudaPackages
      darwinMinVersionHook
      gitMinimal
      ninja
      openssl
      rocmPackages
      shaderc
      spirv-headers
      vulkan-headers
      vulkan-loader
      ;
    llvm = pkgs.llvmPackages_22;
    inherit
      (pkgs.stdenv.hostPlatform)
      isStatic
      isx86
      isDarwin
      isLinux
      ;

    available = lib.meta.availableOn pkgs.stdenv.hostPlatform;
    cudaSupported =
      isLinux
      && cudaPackages ? backendStdenv
      && cudaPackages ? cccl
      && cudaPackages ? cuda_cudart
      && cudaPackages ? cuda_nvcc
      && cudaPackages ? libcublas
      && builtins.all available (with cudaPackages; [
        cccl
        cuda_cudart
        cuda_nvcc
        libcublas
      ]);
    rocmSupported =
      isLinux
      && rocmPackages ? clr
      && rocmPackages ? hipblas
      && rocmPackages ? llvm
      && rocmPackages.llvm ? llvm
      && rocmPackages ? rocblas
      && builtins.all available (
        [rocmPackages.llvm.llvm]
        ++ (with rocmPackages; [
          clr
          hipblas
          rocblas
        ])
      );
    vulkanSupported =
      isLinux
      && builtins.all available [
        shaderc
        spirv-headers
        vulkan-headers
        vulkan-loader
      ];
  in {
    options.mkLlama = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
    };

    config.mkLlama = {nativeSupport ? false}: let
      cudaEnabled = top.config.cudaSupport && cudaSupported;
      rocmEnabled = top.config.rocmSupport && rocmSupported && !cudaEnabled;
      metalEnabled = top.config.metalSupport && isDarwin;
      vulkanEnabled =
        top.config.vulkanSupport
        && vulkanSupported
        && !(cudaEnabled || rocmEnabled);

      stdenv =
        if cudaEnabled
        then cudaPackages.backendStdenv
        else if isDarwin
        then llvm.stdenv
        else pkgs.stdenv;

      compileFlags =
        ["-pipe"]
        ++ optionals metalEnabled ["-D__ARM_FEATURE_DOTPROD=1"]
        ++ optionals nativeSupport [
          (
            if isx86
            then "-march=native"
            else "-mcpu=native"
          )
        ]
        ++ optionals (isDarwin && !nativeSupport) ["-mcpu=apple-m1"];

      rocmGpuTargets = rocmPackages.clr.localGpuTargets or rocmPackages.clr.gpuTargets;
    in
      stdenv.mkDerivation {
        pname = "llama-cpp";
        inherit (top.config) src version;

        nativeBuildInputs =
          [
            cmakeMinimal
            gitMinimal
            ninja
          ]
          ++ optionals isDarwin (with llvm; [
            bintools
            clang
          ])
          ++ optionals cudaEnabled (
            [autoAddDriverRunpath]
            ++ (with cudaPackages; [cuda_nvcc])
          )
          ++ optionals vulkanEnabled [shaderc];

        buildInputs =
          [openssl]
          ++ optionals cudaEnabled (with cudaPackages; [
            cccl
            cuda_cudart
            libcublas
          ])
          ++ optionals rocmEnabled (with rocmPackages; [
            clr
            hipblas
            rocblas
          ])
          ++ optionals vulkanEnabled [
            spirv-headers
            vulkan-headers
            vulkan-loader
          ]
          ++ optionals isDarwin [
            pkgs.apple-sdk_15
            llvm.openmp
            (darwinMinVersionHook "15.2")
          ];

        postPatch = optionalString top.config.webUISupport (
          let
            webUI = config.mkLlamaWebUI {};
          in ''
            cp -r ${webUI} tools/ui/dist
            chmod -R u+w tools/ui/dist
          ''
        );

        cmakeFlags =
          [
            (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
            (cmakeBool "LLAMA_BUILD_TESTS" false)
            (cmakeBool "LLAMA_BUILD_TOOLS" true)
            (cmakeBool "LLAMA_BUILD_SERVER" true)
            (cmakeBool "LLAMA_BUILD_APP" true)
            (cmakeBool "LLAMA_TOOLS_INSTALL" true)
            (cmakeBool "LLAMA_OPENSSL" true)
            (cmakeBool "LLAMA_BUILD_UI" false)
            (cmakeBool "LLAMA_USE_PREBUILT_UI" false)
            (cmakeBool "GGML_CUDA" cudaEnabled)
            (cmakeBool "GGML_HIP" rocmEnabled)
            (cmakeBool "GGML_VULKAN" vulkanEnabled)
            (cmakeBool "GGML_LTO" true)
            (cmakeBool "GGML_NATIVE" nativeSupport)
            (cmakeBool "GGML_CCACHE" false)
            (cmakeBool "BUILD_SHARED_LIBS" (!isStatic))
          ]
          ++ optionals (isx86 && !isStatic && !nativeSupport) [
            (cmakeBool "GGML_BACKEND_DL" true)
            (cmakeBool "GGML_CPU_ALL_VARIANTS" true)
            (cmakeFeature "GGML_BACKEND_DIR" "${placeholder "out"}/bin")
          ]
          ++ optionals cudaEnabled [
            (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
          ]
          ++ optionals rocmEnabled [
            (cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.clr.hipClangPath}/clang++")
            (cmakeFeature "CMAKE_HIP_ARCHITECTURES" (builtins.concatStringsSep ";" rocmGpuTargets))
          ]
          ++ optionals metalEnabled [
            (cmakeBool "GGML_METAL" true)
            (cmakeBool "GGML_METAL_EMBED_LIBRARY" true)
          ];

        preConfigure =
          ''
            cmakeFlagsArray+=(
              "-DCMAKE_C_FLAGS=${toString compileFlags}"
              "-DCMAKE_CXX_FLAGS=${toString compileFlags}"
          ''
          + optionalString isDarwin ''
            "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -Wl,-dead_strip"
          ''
          + ''
            )
          '';

        hardeningDisable = [
          "zerocallusedregs"
          "stackprotector"
          "libcxxhardeningfast"
          "strictoverflow"
        ];
        enableParallelBuilding = true;

        NIX_ENFORCE_NO_NATIVE =
          if nativeSupport
          then 0
          else 1;

        meta = {
          description = "Inference of LLaMA and other models in C/C++";
          homepage = "https://github.com/ggml-org/llama.cpp";
          license = lib.licenses.mit;
          mainProgram = "llama";
          platforms = lib.platforms.darwin ++ lib.platforms.linux;
        };
      };
  };
}
