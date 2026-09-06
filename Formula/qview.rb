class Qview < Formula
  desc "Practical and minimal image viewer"
  homepage "https://interversehq.com/qview/"
  url "https://github.com/jurplel/qView/archive/0ec246b78c310d5c842836a91566db24037c75c2.tar.gz"
  version "7.1"
  sha256 "ec166f6078e13fa16df587a9d100ee326104070ded14491dea95a7a1dbc734c8"
  license "GPL-3.0-only"

  depends_on "qttools" => :build
  depends_on "libx11"
  depends_on :linux
  depends_on "qtbase"
  depends_on "qtimageformats"
  depends_on "qtsvg"
  depends_on "qtwayland"

  def install
    system "qmake", "qView.pro", "PREFIX=#{prefix}", "CONFIG+=release", "CONFIG+=qv_disable_online_version_check"
    system "make"
    system "make", "install"
    inreplace share/"applications/com.interversehq.qView.desktop", "Exec=qview", "Exec=#{opt_bin}/qview"
  end

  def caveats
    <<~EOS
      Launch with qview, or add #{HOMEBREW_PREFIX}/share to your desktop session's XDG_DATA_DIRS.
      A running X11 or Wayland session is required. Uninstall preserves your settings.
      Support qView: https://github.com/jurplel/qView
    EOS
  end

  test do
    ENV["QT_QPA_PLATFORM"] = "offscreen"
    assert_match version.to_s, shell_output("#{bin}/qview --version")
    assert_path_exists share/"applications/com.interversehq.qView.desktop"
  end
end
