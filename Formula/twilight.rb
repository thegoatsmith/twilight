class Twilight < Formula
  desc "Menu-bar utility that switches macOS Light/Dark mode at sunrise/sunset"
  homepage "https://github.com/thegoatsmith/twilight"
  url "https://github.com/thegoatsmith/twilight/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "REPLACE_WITH_SHA256_AFTER_PUSHING_v0.1.1"
  license "MIT"
  head "https://github.com/thegoatsmith/twilight.git", branch: "main"

  depends_on "xcodegen" => :build
  depends_on xcode: ["14.0", :build]
  depends_on macos: :ventura

  def install
    system "xcodegen", "generate"
    system "xcodebuild",
           "-project", "Twilight.xcodeproj",
           "-scheme", "Twilight",
           "-configuration", "Release",
           "-derivedDataPath", "build",
           "MACOSX_DEPLOYMENT_TARGET=13.0"
    prefix.install "build/Build/Products/Release/Twilight.app"
  end

  def caveats
    <<~EOS
      Twilight is a .app bundle. To put it in /Applications:
        ln -sfn #{opt_prefix}/Twilight.app /Applications/Twilight.app

      Or copy it:
        cp -R #{opt_prefix}/Twilight.app /Applications/

      On first launch, grant Location and Automation (System Events) when prompted.
    EOS
  end

  test do
    assert_predicate prefix/"Twilight.app/Contents/MacOS/Twilight", :exist?
  end
end
