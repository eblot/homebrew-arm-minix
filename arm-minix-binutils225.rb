require 'formula'

class ArmMinixBinutils225 <Formula
  url 'http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.bz2'
  homepage 'http://www.gnu.org/software/binutils/'
  sha256 '22defc65cfa3ef2a3395faaea75d6331c6e62ea5dfacfed3e2ec17b08c882923'

  keg_only 'Enable installation of several binutils versions'

  depends_on 'gmp'
  depends_on 'mpfr'
  depends_on 'ppl11'
  depends_on 'cloog'

  def patches
    DATA
  end

  def install
    system "./configure", 
                "--prefix=#{prefix}", 
                "--target=arm-elf32-minix",
                "--with-gmp=#{Formula.factory('gmp').prefix}",
                "--with-mpfr=#{Formula.factory('mpfr').prefix}",
                "--with-ppl=#{Formula.factory('ppl11').prefix}",
                "--with-cloog=#{Formula.factory('cloog').prefix}",
                "--disable-shared", 
                "--disable-nls",
                "--disable-werror", 
                "--disable-debug",
                "--enable-lto",
                "--enable-plugins",
                "--enable-ld=default",
                "--enable-gold=yes",
                "--with-sysroot",
                "--with-pkgversion=SDK3-Angelina"              
    system "make"
    system "make install"
  end
end

__END__
diff --git a/bfd/config.bfd b/bfd/config.bfd
index 7bcb92a..e55ade0 100644
--- a/bfd/config.bfd
+++ b/bfd/config.bfd
@@ -338,7 +338,7 @@ case "${targ}" in
     ;;
   arm-*-elf | arm*-*-freebsd* | arm*-*-linux-* | arm*-*-conix* | \
   arm*-*-uclinux* | arm-*-kfreebsd*-gnu | \
-  arm*-*-eabi* )
+  arm*-*-eabi* | arm*-*-minix* )
     targ_defvec=arm_elf32_le_vec
     targ_selvecs=arm_elf32_be_vec
     ;;
diff --git a/config.guess b/config.guess
index 1f5c50c..60fa82f 100755
--- a/config.guess
+++ b/config.guess
@@ -880,8 +880,8 @@ EOF
 	# other systems with GNU libc and userland
 	echo ${UNAME_MACHINE}-unknown-`echo ${UNAME_SYSTEM} | sed 's,^[^/]*/,,' | tr '[A-Z]' '[a-z]'``echo ${UNAME_RELEASE}|sed -e 's/[-(].*//'`-${LIBC}
 	exit ;;
-    i*86:Minix:*:*)
-	echo ${UNAME_MACHINE}-pc-minix
+    *:Minix:*:*)
+	echo ${UNAME_MACHINE}-elf32-minix
 	exit ;;
     aarch64:Linux:*:*)
 	echo ${UNAME_MACHINE}-unknown-linux-${LIBC}
diff --git a/configure b/configure
index 87677bc..5f5193f 100755
--- a/configure
+++ b/configure
@@ -2958,7 +2958,7 @@ case "${ENABLE_GOLD}" in
       *-*-elf* | *-*-sysv4* | *-*-unixware* | *-*-eabi* | hppa*64*-*-hpux* \
       | *-*-linux* | *-*-gnu* | frv-*-uclinux* | *-*-irix5* | *-*-irix6* \
       | *-*-netbsd* | *-*-openbsd* | *-*-freebsd* | *-*-dragonfly* \
-      | *-*-solaris2* | *-*-nto* | *-*-nacl*)
+      | *-*-solaris2* | *-*-nto* | *-*-nacl* |  *-*-minix*)
         case "${target}" in
           *-*-linux*aout* | *-*-linux*oldld*)
             ;;
diff --git a/gas/configure b/gas/configure
index 76b5f20..c576396 100755
--- a/gas/configure
+++ b/gas/configure
@@ -5893,6 +5893,10 @@ freebsd* | dragonfly*)
   fi
   ;;
 
+minix*)
+  lt_cv_deplibs_check_method=pass_all
+  ;;
+ 
 gnu*)
   lt_cv_deplibs_check_method=pass_all
   ;;
diff --git a/gas/configure.tgt b/gas/configure.tgt
index d07d445..1fe7df1 100644
--- a/gas/configure.tgt
+++ b/gas/configure.tgt
@@ -473,6 +473,8 @@ case ${generic_target} in
   *-*-elf | *-*-sysv4*)			fmt=elf ;;
   *-*-solaris*)				fmt=elf em=solaris ;;
   *-*-aros*)				fmt=elf em=linux ;;
+  i*-*-minix*)        fmt=elf em=minix ;;
+  arm*-*-minix*)        fmt=elf em=armeabi ;;
   *-*-vxworks* | *-*-windiss)		fmt=elf em=vxworks ;;
   *-*-netware)				fmt=elf em=netware ;;
 esac
diff --git a/gold/binary.cc b/gold/binary.cc
index 4dab52c..77a78f0 100644
--- a/gold/binary.cc
+++ b/gold/binary.cc
@@ -24,10 +24,10 @@
 
 #include <cerrno>
 #include <cstring>
+#include "stringpool.h"
 #include "safe-ctype.h"
 
 #include "elfcpp.h"
-#include "stringpool.h"
 #include "fileread.h"
 #include "output.h"
 #include "binary.h"
diff --git a/ld/Makefile.in b/ld/Makefile.in
index 9f56ca1..81fb29b 100644
--- a/ld/Makefile.in
+++ b/ld/Makefile.in
@@ -471,6 +471,7 @@ ALL_EMULATION_SOURCES = \
 	earmelf_fbsd.c \
 	earmelf_linux.c \
 	earmelf_linux_eabi.c \
+    earmelf_minix.c \
 	earmelf_nacl.c \
 	earmelf_nbsd.c \
 	earmelf_vxworks.c \
@@ -2156,6 +2157,10 @@ earmelf_linux_eabi.c: $(srcdir)/emulparams/armelf_linux_eabi.sh \
   $(ELF_DEPS) $(srcdir)/emultempl/armelf.em \
   $(srcdir)/scripttempl/elf.sc ${GEN_DEPENDS}
 
+earmelf_minix.c: $(srcdir)/emulparams/armelf_minix.sh \
+  $(srcdir)/emulparams/armelf.sh \
+  $(srcdir)/emultempl/elf32.em $(srcdir)/scripttempl/elf.sc ${GEN_DEPENDS}
+
 earmelf_nacl.c: $(srcdir)/emulparams/armelf_nacl.sh \
   $(srcdir)/emulparams/armelf_linux_eabi.sh \
   $(srcdir)/emulparams/armelf_linux.sh \
diff --git a/ld/configure.tgt b/ld/configure.tgt
index 24e36d1..54106e7 100644
--- a/ld/configure.tgt
+++ b/ld/configure.tgt
@@ -99,6 +99,8 @@ armeb-*-elf | armeb-*-eabi*)
 			targ_emul=armelfb ;;
 arm-*-elf | arm*-*-eabi*)
 	  		targ_emul=armelf ;;
+arm*-*-minix*)	targ_emul=armelf_minix
+			targ_extra_emuls="armelf" ;;
 arm*-*-symbianelf*)     targ_emul=armsymbian;;
 arm-*-kaos*)		targ_emul=armelf ;;
 arm9e-*-elf)		targ_emul=armelf ;;
diff --git a/gas/config/te-minix.h b/gas/config/te-minix.h
new file mode 100644
index 0000000..5d938e7
--- /dev/null
+++ b/gas/config/te-minix.h
@@ -0,0 +1,9 @@
+#define TE_MINIX 1
+
+/* Added these, because if we don't know what we're targeting we may
+   need an assembler version of libgcc, and that will use local
+   labels.  */
+#define LOCAL_LABELS_DOLLAR 1
+#define LOCAL_LABELS_FB 1
+
+#include "obj-format.h"
diff --git a/ld/emulparams/armelf_minix.sh b/ld/emulparams/armelf_minix.sh
new file mode 100644
index 0000000..f52c1c3
--- /dev/null
+++ b/ld/emulparams/armelf_minix.sh
@@ -0,0 +1,15 @@
+. ${srcdir}/emulparams/armelf.sh
+. ${srcdir}/emulparams/elf_minix.sh
+OUTPUT_FORMAT="elf32-littlearm"
+MAXPAGESIZE="CONSTANT (MAXPAGESIZE)"
+COMMONPAGESIZE="CONSTANT (COMMONPAGESIZE)"
+
+DATA_START_SYMBOLS='PROVIDE (__data_start = .);';
+
+# Dynamic libraries support
+GENERATE_SHLIB_SCRIPT=yes
+TARGET2_TYPE=got-rel
+
+GENERATE_PIE_SCRIPT=yes
+
+unset EMBEDDED
diff --git a/ld/emulparams/elf_minix.sh b/ld/emulparams/elf_minix.sh
new file mode 100644
index 0000000..a9b834f
--- /dev/null
+++ b/ld/emulparams/elf_minix.sh
@@ -0,0 +1 @@
+ELF_INTERPRETER_NAME=\"/libexec/ld-elf.so.1\"
