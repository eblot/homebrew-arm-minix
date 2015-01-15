class ArmMinixClang35 <Formula
  homepage  'http://llvm.org/'

  # keg_only 'Enable installation of several clang versions'

  stable do
    url 'http://llvm.org/releases/3.5.1/llvm-3.5.1.src.tar.xz'
    sha1 '79638cf00584b08fd6eeb1e73ea69b331561e7f6'

    resource 'clang' do
      url 'http://llvm.org/releases/3.5.1/cfe-3.5.1.src.tar.xz'
      sha1 '39d79c0b40cec548a602dcac3adfc594b18149fe'
    end

    resource 'clang-tools-extra' do
      url 'http://llvm.org/releases/3.5.1/clang-tools-extra-3.5.1.src.tar.xz'
      sha1 '7a0dd880d7d8fe48bdf0f841eca318337d27a345'
    end
  end

  resource 'isl' do
    url 'http://isl.gforge.inria.fr/isl-0.13.tar.bz2'
    sha1 '3904274c84fb3068e4f59b6a6b0fe29e7a2b7010'
  end

  resource 'cloog' do
    url 'http://repo.or.cz/w/cloog.git/snapshot/22643c94eba7b010ae4401c347289f4f52b9cd2b.tar.gz'
    sha1 '5409629e2fbe38035e8071c81601317a1a699309'
  end

  # required to build cloog
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool"  => :build
  depends_on "pkg-config" => :build

  depends_on 'gmp'
  depends_on 'libffi' => :recommended

  def ver; '3.5.1'; end # version suffix

  # LLVM installs its own standard library which confuses stdlib checking.
  cxxstdlib_check :skip

  def install

    clang_buildpath = buildpath/"tools/clang"

    clang_buildpath.install resource("clang")

    (buildpath/"tools/clang/tools/extra").install resource("clang-tools-extra")

    install_prefix = lib/"llvm-#{ver}"

    gmp_prefix = Formula["gmp"].opt_prefix
    isl_prefix = install_prefix/'libexec/isl'
    cloog_prefix = install_prefix/'libexec/cloog'

    resource('isl').stage do
      system "./configure", "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--prefix=#{isl_prefix}",
                            "--with-gmp=system",
                            "--with-gmp-prefix=#{gmp_prefix}"
      system "make"
      system "make", "install"
    end

    resource('cloog').stage do
      system "./autogen.sh"
      system "./configure", "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--prefix=#{cloog_prefix}",
                            "--with-gmp-prefix=#{gmp_prefix}",
                            "--with-isl-prefix=#{isl_prefix}"
      system "make"
      system "make", "install"
    end

    args = [
      "--prefix=#{install_prefix}",
      "--program-prefix=arm-elf32-minix-",
      "--enable-targets=arm",
      "--enable-optimized",
      "--disable-bindings",
      "--disable-debug-symbols",
      "--disable-debug-runtime",
      "--with-gmp=#{gmp_prefix}",
      "--with-isl=#{isl_prefix}",
      "--with-cloog=#{cloog_prefix}"
    ]

    args << "--enable-libffi" if build.with? 'libffi'

    system './configure', *args

    # crappy way to patch resource files.
    # waiting for https://github.com/Homebrew/homebrew/issues/31508 to be
    # addressed - or any better way to patch a sub-archive
    p = Patch.create(:p1, :DATA)
    p.path = Pathname.new(__FILE__).expand_path
    p.apply

    system 'pwd'
    system 'make'
    system 'make', 'install'

    (share/"clang-#{ver}/tools").install Dir["tools/clang/tools/scan-{build,view}"]

    (lib/"python2.7/site-packages").install "bindings/python/llvm" => "llvm-#{ver}",
      clang_buildpath/"bindings/python/clang" => "clang-#{ver}"

    Dir.glob(install_prefix/'bin/*') do |exec_path|
      basename = File.basename(exec_path)
      bin.install_symlink exec_path => "#{basename}"
    end

    Dir.glob(install_prefix/'share/man/man1/*') do |manpage|
      basename = File.basename(manpage, ".1")
      man1.install_symlink manpage => "#{basename}.1"
    end
  end
end

__END__
Index: lib/Basic/Targets.cpp
===================================================================
diff --git a/tools/clang/lib/Basic/Targets.cpp b/tools/clang/lib/Basic/Targets.cpp
--- a/tools/clang/lib/Basic/Targets.cpp	(revision 224697)
+++ b/tools/clang/lib/Basic/Targets.cpp	(working copy)
@@ -329,6 +329,7 @@
     // Minix defines
 
     Builder.defineMacro("__minix", "3");
+    Builder.defineMacro("__minix__", "3");
     Builder.defineMacro("_EM_WSIZE", "4");
     Builder.defineMacro("_EM_PSIZE", "4");
     Builder.defineMacro("_EM_SSIZE", "2");
@@ -335,8 +336,11 @@
     Builder.defineMacro("_EM_LSIZE", "4");
     Builder.defineMacro("_EM_FSIZE", "4");
     Builder.defineMacro("_EM_DSIZE", "8");
+    Builder.defineMacro("__unix__");
     Builder.defineMacro("__ELF__");
     DefineStd(Builder, "unix", Opts);
+    if (Opts.POSIXThreads)
+      Builder.defineMacro("_POSIX_THREADS");  
   }
 public:
   MinixTargetInfo(const llvm::Triple &Triple) : OSTargetInfo<Target>(Triple) {
@@ -3672,7 +3676,14 @@
     // FIXME: Should we just treat this as a feature?
     IsThumb = getTriple().getArchName().startswith("thumb");
 
-    setABI("aapcs-linux");
+    switch (getTriple().getOS()) {
+    case llvm::Triple::Minix:
+      setABI("aapcs");
+      break;
+    default:
+      setABI("aapcs-linux");
+      break;
+    }
 
     // ARM targets default to using the ARM C++ ABI.
     TheCXXABI.set(TargetCXXABI::GenericARM);
@@ -6067,6 +6078,8 @@
       return new FreeBSDTargetInfo<ARMleTargetInfo>(Triple);
     case llvm::Triple::NetBSD:
       return new NetBSDTargetInfo<ARMleTargetInfo>(Triple);
+    case llvm::Triple::Minix:
+      return new MinixTargetInfo<ARMleTargetInfo>(Triple);
     case llvm::Triple::OpenBSD:
       return new OpenBSDTargetInfo<ARMleTargetInfo>(Triple);
     case llvm::Triple::Bitrig:
Index: lib/Driver/ToolChains.cpp
===================================================================
diff --git a/tools/clang/lib/Driver/ToolChains.cpp b/tools/clang/lib/Driver/ToolChains.cpp
--- a/tools/clang/lib/Driver/ToolChains.cpp	(revision 224697)
+++ b/tools/clang/lib/Driver/ToolChains.cpp	(working copy)
@@ -2714,8 +2714,9 @@
 
 Minix::Minix(const Driver &D, const llvm::Triple& Triple, const ArgList &Args)
   : Generic_ELF(D, Triple, Args) {
-  getFilePaths().push_back(getDriver().Dir + "/../lib");
-  getFilePaths().push_back("/usr/lib");
+    if (getDriver().UseStdLib) {
+      getFilePaths().push_back("=/usr/lib");
+    }
 }
 
 Tool *Minix::buildAssembler() const {
@@ -2726,6 +2727,42 @@
   return new tools::minix::Link(*this);
 }
 
+ToolChain::CXXStdlibType
+Minix::GetCXXStdlibType(const ArgList &Args) const {
+  if (Arg *A = Args.getLastArg(options::OPT_stdlib_EQ)) {
+    StringRef Value = A->getValue();
+    if (Value == "libstdc++")
+      return ToolChain::CST_Libstdcxx;
+    if (Value == "libc++")
+      return ToolChain::CST_Libcxx;
+
+    getDriver().Diag(diag::err_drv_invalid_stdlib_name)
+      << A->getAsString(Args);
+  }
+
+  return ToolChain::CST_Libcxx;
+}
+
+void Minix::AddClangCXXStdlibIncludeArgs(const ArgList &DriverArgs,
+                                          ArgStringList &CC1Args) const {
+  if (DriverArgs.hasArg(options::OPT_nostdlibinc) ||
+      DriverArgs.hasArg(options::OPT_nostdincxx))
+    return;
+
+  switch (GetCXXStdlibType(DriverArgs)) {
+  case ToolChain::CST_Libcxx:
+    addSystemInclude(DriverArgs, CC1Args,
+                     getDriver().SysRoot + "/usr/include/c++/");
+    break;
+  case ToolChain::CST_Libstdcxx:
+    addSystemInclude(DriverArgs, CC1Args,
+                     getDriver().SysRoot + "/usr/include/g++");
+    addSystemInclude(DriverArgs, CC1Args,
+                     getDriver().SysRoot + "/usr/include/g++/backward");
+    break;
+  }
+}
+
 /// AuroraUX - AuroraUX tool chain which can call as(1) and ld(1) directly.
 
 AuroraUX::AuroraUX(const Driver &D, const llvm::Triple& Triple,
Index: lib/Driver/ToolChains.h
===================================================================
diff --git a/tools/clang/lib/Driver/ToolChains.h b/tools/clang/lib/Driver/ToolChains.h
--- a/tools/clang/lib/Driver/ToolChains.h	(revision 224697)
+++ b/tools/clang/lib/Driver/ToolChains.h	(working copy)
@@ -637,6 +637,18 @@
   Minix(const Driver &D, const llvm::Triple &Triple,
         const llvm::opt::ArgList &Args);
 
+  bool IsMathErrnoDefault() const override { return false; }
+  bool IsObjCNonFragileABIDefault() const override { return true; }
+
+  CXXStdlibType GetCXXStdlibType(const llvm::opt::ArgList &Args) const override;
+
+  void
+  AddClangCXXStdlibIncludeArgs(const llvm::opt::ArgList &DriverArgs,
+                              llvm::opt::ArgStringList &CC1Args) const override;
+  bool IsUnwindTablesDefault() const override {
+    return true;
+  }
+
 protected:
   Tool *buildAssembler() const override;
   Tool *buildLinker() const override;
Index: lib/Driver/Tools.cpp
===================================================================
diff --git a/tools/clang/lib/Driver/Tools.cpp b/tools/clang/lib/Driver/Tools.cpp
--- a/tools/clang/lib/Driver/Tools.cpp	(revision 224697)
+++ b/tools/clang/lib/Driver/Tools.cpp	(working copy)
@@ -7526,6 +7526,25 @@
   const Driver &D = getToolChain().getDriver();
   ArgStringList CmdArgs;
 
+  if (!D.SysRoot.empty())
+    CmdArgs.push_back(Args.MakeArgString("--sysroot=" + D.SysRoot));
+
+  if (Args.hasArg(options::OPT_static)) {
+    CmdArgs.push_back("-Bstatic");
+  } else {
+    if (Args.hasArg(options::OPT_rdynamic))
+      CmdArgs.push_back("-export-dynamic");
+    CmdArgs.push_back("--eh-frame-hdr");
+    if (Args.hasArg(options::OPT_shared)) {
+      CmdArgs.push_back("-Bshareable");
+    } else {
+      CmdArgs.push_back("-dynamic-linker");
+      // LSC: Small deviation from the NetBSD version.
+      //      Use the same linker path as gcc.
+      CmdArgs.push_back("/usr/libexec/ld.elf_so");
+    }
+  }
+
   if (Output.isFilename()) {
     CmdArgs.push_back("-o");
     CmdArgs.push_back(Output.getFilename());
@@ -7535,39 +7554,58 @@
 
   if (!Args.hasArg(options::OPT_nostdlib) &&
       !Args.hasArg(options::OPT_nostartfiles)) {
-      CmdArgs.push_back(Args.MakeArgString(getToolChain().GetFilePath("crt1.o")));
-      CmdArgs.push_back(Args.MakeArgString(getToolChain().GetFilePath("crti.o")));
-      CmdArgs.push_back(Args.MakeArgString(getToolChain().GetFilePath("crtbegin.o")));
-      CmdArgs.push_back(Args.MakeArgString(getToolChain().GetFilePath("crtn.o")));
+      if (!Args.hasArg(options::OPT_shared)) {
+        CmdArgs.push_back(Args.MakeArgString(
+          getToolChain().GetFilePath("crt0.o")));
+        CmdArgs.push_back(Args.MakeArgString(
+          getToolChain().GetFilePath("crti.o")));
+        CmdArgs.push_back(Args.MakeArgString(
+          getToolChain().GetFilePath("crtbegin.o")));
+      } else {
+        CmdArgs.push_back(Args.MakeArgString(
+          getToolChain().GetFilePath("crti.o")));
+        CmdArgs.push_back(Args.MakeArgString(
+          getToolChain().GetFilePath("crtbeginS.o")));
+      }
   }
 
   Args.AddAllArgs(CmdArgs, options::OPT_L);
   Args.AddAllArgs(CmdArgs, options::OPT_T_Group);
   Args.AddAllArgs(CmdArgs, options::OPT_e);
+  Args.AddAllArgs(CmdArgs, options::OPT_s);
+  Args.AddAllArgs(CmdArgs, options::OPT_t);
+  Args.AddAllArgs(CmdArgs, options::OPT_Z_Flag);
+  Args.AddAllArgs(CmdArgs, options::OPT_r);
 
   AddLinkerInputs(getToolChain(), Inputs, Args, CmdArgs);
 
-  addProfileRT(getToolChain(), Args, CmdArgs);
-
   if (!Args.hasArg(options::OPT_nostdlib) &&
       !Args.hasArg(options::OPT_nodefaultlibs)) {
     if (D.CCCIsCXX()) {
       getToolChain().AddCXXStdlibLibArgs(Args, CmdArgs);
       CmdArgs.push_back("-lm");
+      /* LSC: Hack as lc++ is linked against mthread. */
+      CmdArgs.push_back("-lmthread");
     }
+    if (Args.hasArg(options::OPT_pthread))
+      CmdArgs.push_back("-lpthread");
+    CmdArgs.push_back("-lc");
   }
 
   if (!Args.hasArg(options::OPT_nostdlib) &&
       !Args.hasArg(options::OPT_nostartfiles)) {
-    if (Args.hasArg(options::OPT_pthread))
-      CmdArgs.push_back("-lpthread");
-    CmdArgs.push_back("-lc");
-    CmdArgs.push_back("-lCompilerRT-Generic");
-    CmdArgs.push_back("-L/usr/pkg/compiler-rt/lib");
-    CmdArgs.push_back(
-         Args.MakeArgString(getToolChain().GetFilePath("crtend.o")));
+    if (!Args.hasArg(options::OPT_shared))
+      CmdArgs.push_back(Args.MakeArgString(
+        getToolChain().GetFilePath("crtend.o")));
+    else
+      CmdArgs.push_back(Args.MakeArgString(
+        getToolChain().GetFilePath("crtendS.o")));
+   CmdArgs.push_back(Args.MakeArgString(
+        getToolChain().GetFilePath("crtn.o")));
   }
 
+  addProfileRT(getToolChain(), Args, CmdArgs);
+
   const char *Exec = Args.MakeArgString(getToolChain().GetLinkerPath());
   C.addCommand(new Command(JA, *this, Exec, CmdArgs));
 }
Index: lib/Frontend/InitHeaderSearch.cpp
===================================================================
diff --git a/tools/clang/lib/Frontend/InitHeaderSearch.cpp b/tools/clang/lib/Frontend/InitHeaderSearch.cpp
--- a/tools/clang/lib/Frontend/InitHeaderSearch.cpp	(revision 224697)
+++ b/tools/clang/lib/Frontend/InitHeaderSearch.cpp	(working copy)
@@ -230,6 +230,7 @@
     case llvm::Triple::FreeBSD:
     case llvm::Triple::NetBSD:
     case llvm::Triple::OpenBSD:
+    case llvm::Triple::Minix:
     case llvm::Triple::Bitrig:
       break;
     default:
