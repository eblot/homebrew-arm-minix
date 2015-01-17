class NoExpatFramework < Requirement
  def expat_framework
    "/Library/Frameworks/expat.framework"
  end

  satisfy :build_env => false do
    not File.exist? expat_framework
  end

  def message; <<-EOS.undent
    Detected #{expat_framework}

    This will be picked up by CMake's build system and likely cause the
    build to fail, trying to link to a 32-bit version of expat.

    You may need to move this file out of the way to compile CMake.
    EOS
  end
end

class Cmake31 < Formula
  homepage "http://www.cmake.org/"
  url "http://www.cmake.org/files/v3.1/cmake-3.1.0.tar.gz"
  sha1 "cc20c40f5480c83a0204f516a490b470bd3a963a"
  head "http://cmake.org/cmake.git"

  option "without-docs", "Don't build man pages"
  depends_on :python => :build if MacOS.version <= :snow_leopard && build.with?("docs")
  depends_on "xz" # For LZMA

  # The `with-qt` GUI option was removed due to circular dependencies if
  # CMake is built with Qt support and Qt is built with MySQL support as MySQL uses CMake.
  # For the GUI application please instead use brew install caskroom/cask/cmake.

  # Sublime Text support: single build process, use current path for tools
  patch :DATA

  resource "sphinx" do
    url "https://pypi.python.org/packages/source/S/Sphinx/Sphinx-1.2.3.tar.gz"
    sha1 "3a11f130c63b057532ca37fe49c8967d0cbae1d5"
  end

  resource "docutils" do
    url "https://pypi.python.org/packages/source/d/docutils/docutils-0.12.tar.gz"
    sha1 "002450621b33c5690060345b0aac25bc2426d675"
  end

  resource "pygments" do
    url "https://pypi.python.org/packages/source/P/Pygments/Pygments-2.0.1.tar.gz"
    sha1 "b9e9236693ccf6e86414e8578bf8874181f409de"
  end

  resource "jinja2" do
    url "https://pypi.python.org/packages/source/J/Jinja2/Jinja2-2.7.3.tar.gz"
    sha1 "25ab3881f0c1adfcf79053b58de829c5ae65d3ac"
  end

  resource "markupsafe" do
    url "https://pypi.python.org/packages/source/M/MarkupSafe/MarkupSafe-0.23.tar.gz"
    sha1 "cd5c22acf6dd69046d6cb6a3920d84ea66bdf62a"
  end

  depends_on NoExpatFramework

  def install
    if build.with? "docs"
      ENV.prepend_create_path "PYTHONPATH", buildpath+"sphinx/lib/python2.7/site-packages"
      resources.each do |r|
        r.stage do
          system "python", *Language::Python.setup_install_args(buildpath/"sphinx")
        end
      end

      # There is an existing issue around OS X & Python locale setting
      # See http://bugs.python.org/issue18378#msg215215 for explanation
      ENV["LC_ALL"] = "en_US.UTF-8"
    end

    args = %W[
      --prefix=#{prefix}
      --system-libs
      --parallel=#{ENV.make_jobs}
      --no-system-libarchive
      --datadir=/share/cmake
      --docdir=/share/doc/cmake
      --mandir=/share/man
    ]

    if build.with? "docs"
      args << "--sphinx-man" << "--sphinx-build=#{buildpath}/sphinx/bin/sphinx-build"
    end

    system "./bootstrap", *args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"CMakeLists.txt").write("find_package(Ruby)")
    system "#{bin}/cmake", "."
  end
end
__END__
diff -ur a/Source/cmExtraSublimeTextGenerator.cxx b/Source/cmExtraSublimeTextGenerator.cxx
--- a/Source/cmExtraSublimeTextGenerator.cxx	2014-12-15 21:07:43.000000000 +0100
+++ b/Source/cmExtraSublimeTextGenerator.cxx	2015-01-17 22:21:29.000000000 +0100
@@ -24,6 +24,7 @@
 #include "cmXMLSafe.h"
 
 #include <cmsys/SystemTools.hxx>
+#include <stdlib.h>
 
 /*
 Sublime Text 2 Generator
@@ -309,7 +310,8 @@
           this->BuildMakeCommand(make, makefileName.c_str(), targetName) <<
           "],\n";
   fout << "\t\t\t\"working_dir\": \"${project_path}\",\n";
-  fout << "\t\t\t\"file_regex\": \"^(..[^:]*):([0-9]+):?([0-9]+)?:? (.*)$\"\n";
+  fout << "\t\t\t\"file_regex\": \"^(..[^:]*):([0-9]+):?([0-9]+)?:? (.*)$\",\n";
+  fout << "\t\t\t\"path\": \"" << getenv("PATH") << "\"\n";
   fout << "\t\t}";
 }
 
@@ -336,7 +338,7 @@
     std::string makefileName = cmSystemTools::ConvertToOutputPath(makefile);
     command += ", \"-f\", \"";
     command += makefileName + "\"";
-    command += ", \"-v\", \"";
+    command += ", \"-j1\", \"";
     command += target;
     command += "\"";
     }
