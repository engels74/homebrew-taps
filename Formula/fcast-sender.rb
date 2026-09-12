class FcastSender < Formula
  desc "Cast media and mirror your screen to FCast receivers"
  homepage "https://fcast.org/"
  url "https://github.com/futo-org/fcast/archive/09c67f7f5621f2c865facbe75f5ed77a41e6f973.tar.gz"
  version "0.0.3"
  sha256 "d03cdc979bb730b2b7fa9fb4c573b7984d6b94bc31b82fca610717b68a017761"
  license all_of: ["MIT", "GPL-3.0-only"]

  depends_on "cmake" => :build
  depends_on "pkgconf" => :build
  depends_on "protobuf" => :build
  depends_on "rust" => :build
  depends_on "alsa-lib"
  depends_on "edbfi/taps/pipewire-gstreamer"
  depends_on "fontconfig"
  depends_on "glib"
  depends_on "gstreamer"
  depends_on "libx11"
  depends_on "libxcb"
  depends_on "libxkbcommon"
  depends_on "libxrandr"
  depends_on :linux
  depends_on "mesa"
  depends_on "openssl@3"
  depends_on "pulseaudio"
  depends_on "wayland"
  depends_on "yt-dlp"

  def install
    system "cargo", "install", *std_cargo_args(path: "senders/desktop", root: libexec)
    plugins = "#{formula_opt_lib("edbfi/taps/pipewire-gstreamer")}/gstreamer-1.0"
    (bin/"fcast-sender").write_env_script libexec/"bin/desktop-sender",
                                        PATH:            "#{HOMEBREW_PREFIX}/bin:$PATH",
                                        GST_PLUGIN_PATH: "#{plugins}:$GST_PLUGIN_PATH"
    (share/"applications/org.fcast.Sender.desktop").write <<~EOS
      [Desktop Entry]
      Type=Application
      Name=FCast Sender
      Exec=#{opt_bin}/fcast-sender
      Icon=org.fcast.Sender
      Categories=AudioVideo;Network;
      Terminal=false
    EOS
    [128, 256, 512].each do |size|
      (share/"icons/hicolor/#{size}x#{size}/apps").install "senders/extra/fcast_#{size}.png" => "org.fcast.Sender.png"
    end
    (share/"licenses/fcast-sender").install "LICENSE", "senders/extra/LICENSE-GPL"
  end

  def caveats
    <<~EOS
      Launch with fcast-sender, or add #{HOMEBREW_PREFIX}/share to your desktop session's XDG_DATA_DIRS.
      Screen sharing requires your desktop's PipeWire service and a compatible ScreenCast portal.
      Audio capture requires PulseAudio or PipeWire's PulseAudio compatibility service.
      These user-session services are not started by this formula. Uninstall preserves settings.
      Support FCast: https://github.com/futo-org/fcast
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/fcast-sender --version")
    ENV["GST_PLUGIN_PATH"] = "#{formula_opt_lib("edbfi/taps/pipewire-gstreamer")}/gstreamer-1.0"
    ENV["GST_REGISTRY"] = (testpath/"registry.bin").to_s
    %w[pipewiresrc ximagesrc pulsesrc vp8enc opusenc webrtcbin].each do |element|
      system formula_opt_bin("gstreamer")/"gst-inspect-1.0", element
    end
    system formula_opt_bin("gstreamer")/"gst-launch-1.0", "-q",
           "videotestsrc", "num-buffers=2", "!", "video/x-raw,width=32,height=32,framerate=1/1",
           "!", "videoconvert", "!", "vp8enc", "!", "rtpvp8pay", "!", "fakesink"
  end
end
