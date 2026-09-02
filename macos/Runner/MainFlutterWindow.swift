import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // FIRApp configure is an NSException (not Swift Error). Catch it in ObjC
    // so a bad GoogleService-Info.plist cannot abort the process at launch.
    FirebaseLaunchGuardRun {
      RegisterGeneratedPlugins(registry: flutterViewController)
    }

    super.awakeFromNib()
  }
}
