import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  private var dockMenuItems: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    setupDockChannel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // MARK: - Dock menu

  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let newItem = NSMenuItem(
      title: "New Connection",
      action: #selector(openNewConnection),
      keyEquivalent: ""
    )
    menu.addItem(newItem)
    if !dockMenuItems.isEmpty {
      menu.addItem(NSMenuItem.separator())
      for label in dockMenuItems.prefix(5) {
        let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
      }
    }
    return menu
  }

  @objc private func openNewConnection() {
    NSApp.activate(ignoringOtherApps: true)
    guard let window = mainFlutterWindow else { return }
    window.makeKeyAndOrderFront(nil)
    // Notify Flutter to open the command palette.
    if let controller = window.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "xell/dock",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.invokeMethod("openCommandPalette", arguments: nil)
    }
  }

  // MARK: - Dock channel setup

  private func setupDockChannel() {
    guard
      let window = mainFlutterWindow,
      let controller = window.contentViewController as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: "xell/dock",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "setBadge":
        let label = call.arguments as? String
        NSApplication.shared.dockTile.badgeLabel = label
        result(nil)
      case "setRecentHosts":
        self.dockMenuItems = (call.arguments as? [String]) ?? []
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
