import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Enforce minimum native window bounds on macOS (1150 x 570) while allowing expansion and zoom
    let minSize = NSSize(width: 1150, height: 570)
    var windowFrame = self.frame
    windowFrame.size = minSize
    self.setFrame(windowFrame, display: true)
    self.minSize = minSize
    self.setContentSize(minSize)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
