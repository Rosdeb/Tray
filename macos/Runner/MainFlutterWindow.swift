import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Enforce fixed native window bounds on macOS (1020 x 565) to prevent AppKit auto-collapsing
    let targetSize = NSSize(width: 1020, height: 565)
    var windowFrame = self.frame
    windowFrame.size = targetSize
    self.setFrame(windowFrame, display: true)
    self.minSize = targetSize
    self.maxSize = targetSize
    self.setContentSize(targetSize)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
