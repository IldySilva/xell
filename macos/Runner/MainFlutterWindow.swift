import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Channel for Dock badge / Dock menu ("xell/dock"). Registered here, where
  /// the FlutterViewController is known for certain; looking it up later from
  /// AppDelegate is unreliable since window_manager 0.7 / Flutter 3.50.
  private(set) var dockChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerDockChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerDockChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "xell/dock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadge":
        NSApplication.shared.dockTile.badgeLabel = call.arguments as? String
        result(nil)
      case "setRecentHosts":
        AppDelegate.dockMenuItems = (call.arguments as? [String]) ?? []
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    dockChannel = channel
  }
}
