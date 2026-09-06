class PipewireGstreamer < Formula
  desc "PipeWire source and sink plugins for Homebrew GStreamer"
  homepage "https://pipewire.org"
  url "https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/b741e0c74f5436f0c925f7741140db0efd32cf4e/pipewire-b741e0c74f5436f0c925f7741140db0efd32cf4e.tar.gz"
  version "1.6.8"
  sha256 "a78762e007a604846fc16c83979ef15bbb69dba1a2923c32bb6e2f18fafa343f"
  license "MIT"

  depends_on "pkgconf" => :build
  depends_on "gstreamer"
  depends_on :linux
  depends_on "pipewire"

  def install
    # Build only src/gst against the installed PipeWire. Do not install another daemon.
    (buildpath/"config.h").write <<~EOS
      #define PACKAGE "pipewire"
      #define PACKAGE_VERSION "#{version}"
      #define HAVE_GSTREAMER_DEVICE_PROVIDER 1
      #define HAVE_GSTREAMER_DMA_DRM 1
      #define HAVE_GSTREAMER_SHM_ALLOCATOR 1
    EOS
    flags = Utils.safe_popen_read("pkgconf", "--cflags", "--libs", "libpipewire-0.3",
                                 "gstreamer-video-1.0", "gstreamer-audio-1.0", "gstreamer-allocators-1.0").split
    system ENV.cc, "-shared", "-fPIC", "-O2", "-D_GNU_SOURCE", "-I.", "-Isrc",
           *Dir["src/gst/*.c"], "-o", "libgstpipewire.so", *flags, "-lm"
    (lib/"gstreamer-1.0").install "libgstpipewire.so"
    (share/"licenses/pipewire-gstreamer").install "COPYING", "LICENSE"
  end

  test do
    ENV["GST_PLUGIN_PATH"] = (lib/"gstreamer-1.0").to_s
    ENV["GST_REGISTRY"] = (testpath/"registry.bin").to_s
    assert_match "PipeWire", shell_output("#{formula_opt_bin("gstreamer")}/gst-inspect-1.0 pipewiresrc")
    assert_match "PipeWire", shell_output("#{formula_opt_bin("gstreamer")}/gst-inspect-1.0 pipewiresink")
  end
end
