cask "roomcad" do
  version "0.1.0"
  sha256 "400aeb6f47a6ad1dabaecb4694f64ee4c4d33625611ea785edd766129e4be543"

  url "https://github.com/emmettl/bombcad/releases/download/roomcad-v#{version}/RoomCAD-#{version}-macos-arm64.zip"
  name "RoomCAD"
  desc "Room acoustics modelling and impulse response generation"
  homepage "https://github.com/emmettl/RoomCAD"

  livecheck do
    skip "Historical release; later releases are published in emmettl/RoomCAD"
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "RoomCAD.app"

  zap trash: [
    "~/Library/Caches/RoomCAD",
    "~/Library/Preferences/dev.roomcad.RoomCAD.plist",
  ]
end
