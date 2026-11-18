import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  /// Recent hosts for the Dock menu; set from Flutter via MainFlutterWindow.
  static var dockMenuItems: [String] = []

  private var flutterWindow: MainFlutterWindow? {
    NSApp.windows.compactMap { $0 as? MainFlutterWindow }.first
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
    if !AppDelegate.dockMenuItems.isEmpty {
      menu.addItem(NSMenuItem.separator())
      for label in AppDelegate.dockMenuItems.prefix(5) {
        let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
      }
    }
    return menu
  }

  @objc private func openNewConnection() {
    NSApp.activate(ignoringOtherApps: true)
    guard let window = flutterWindow else { return }
    window.makeKeyAndOrderFront(nil)
    // Notify Flutter to open the command palette.
    window.dockChannel?.invokeMethod("openCommandPalette", arguments: nil)
  }
}
