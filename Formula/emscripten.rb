require "language/node"

class Emscripten < Formula
  desc "LLVM bytecode to JavaScript compiler"
  homepage "https://emscripten.org/"

  stable do
    url "https://github.com/emscripten-core/emscripten/archive/1.39.19.tar.gz"
    sha256 "79b08df6d067eb2e00c2e228c3c965a3ae82cd395b50c3c68fa4dfc8ec977f0b"

    resource "fastcomp" do
      url "https://github.com/emscripten-core/emscripten-fastcomp/archive/1.39.19.tar.gz"
      sha256 "392c946b87c1a9c8c1566c3a10a704af3ec17f38fbada8400867774cf8c962c7"
    end

    resource "fastcomp-clang" do
      url "https://github.com/emscripten-core/emscripten-fastcomp-clang/archive/1.39.19.tar.gz"
      sha256 "e1944b483c9cc402b65b8cf5542b81dfb8e1c40867040e9ea146b590c84cd9f9"
    end
  end

  bottle do
    cellar :any
    sha256 "b6f8f53965798b8143d8ec8c094c3f1769f75130cabe0a6dfcb89fe745c54a70" => :catalina
    sha256 "288cab4671f7b2b99119e5d738cbdcd1cf685c8118364a7642a3f01739f7fbf6" => :mojave
    sha256 "66617c1989c49350c360dc4d0561ccdc4a96c409e84b289d70190ae7c65a8716" => :high_sierra
  end

  head do
    url "https://github.com/emscripten-core/emscripten.git", :branch => "incoming"

    resource "fastcomp" do
      url "https://github.com/emscripten-core/emscripten-fastcomp.git", :branch => "incoming"
    end

    resource "fastcomp-clang" do
      url "https://github.com/emscripten-core/emscripten-fastcomp-clang.git", :branch => "incoming"
    end
  end

  depends_on "cmake" => :build
  depends_on "binaryen"
  depends_on "node"
  depends_on "python@3.8"
  depends_on "yuicompressor"

  def install
    ENV.cxx11

    # All files from the repository are required as emscripten is a collection
    # of scripts which need to be installed in the same layout as in the Git
    # repository.
    libexec.install Dir["*"]

    (buildpath/"fastcomp").install resource("fastcomp")
    (buildpath/"fastcomp/tools/clang").install resource("fastcomp-clang")

    cmake_args = std_cmake_args.reject { |s| s["CMAKE_INSTALL_PREFIX"] }
    cmake_args = [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_PREFIX=#{libexec}/llvm",
      "-DLLVM_TARGETS_TO_BUILD='X86;JSBackend'",
      "-DLLVM_INCLUDE_EXAMPLES=OFF",
      "-DLLVM_INCLUDE_TESTS=OFF",
      "-DCLANG_INCLUDE_TESTS=OFF",
      "-DOCAMLFIND=/usr/bin/false",
      "-DGO_EXECUTABLE=/usr/bin/false",
    ]

    mkdir "fastcomp/build" do
      system "cmake", "..", *cmake_args
      system "make"
      system "make", "install"
    end

    cd libexec do
      system "npm", "install", *Language::Node.local_npm_install_args
      rm_f "node_modules/ws/builderror.log" # Avoid references to Homebrew shims
    end

    %w[em++ em-config emar emcc emcmake emconfigure emlink.py emmake
       emranlib emrun emscons].each do |emscript|
      (bin/emscript).write_env_script libexec/emscript, :PYTHON => Formula["python@3.8"].opt_bin/"python3"
    end
  end

  def caveats
    <<~EOS
      Manually set LLVM_ROOT to
        #{opt_libexec}/llvm/bin
      and BINARYEN_ROOT to
        #{Formula["binaryen"].opt_prefix}
      in ~/.emscripten after running `emcc` for the first time.
    EOS
  end

  test do
    system bin/"emcc"
    assert_predicate testpath/".emscripten", :exist?, "Failed to create sample config"
  end
end
