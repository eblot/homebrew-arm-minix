class MinixHostTools < Formula
  homepage "https://github.com/eblot/minix-host-tools"
  url "https://github.com/eblot/minix-host-tools.git", :branch => "master"

  depends_on "cmake" => :build

  def install
    system "cmake", "tools", *std_cmake_args
    system "make", "install" # if this fails, try separate make/make install steps
  end

end
