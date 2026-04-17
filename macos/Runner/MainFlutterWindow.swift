import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Native context menu channel
    let channel = FlutterMethodChannel(
      name: "bolan/context_menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "show" {
        guard let args = call.arguments as? [String: Any],
              let items = args["items"] as? [[String: Any]] else {
          result(nil)
          return
        }
        let selectedId = self.showNativeContextMenu(items: items)
        result(selectedId)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func showNativeContextMenu(items: [[String: Any]]) -> String? {
    let menu = NSMenu()
    menu.autoenablesItems = false

    for item in items {
      let isSeparator = item["isSeparator"] as? Bool ?? false
      if isSeparator {
        menu.addItem(NSMenuItem.separator())
        continue
      }

      let label = item["label"] as? String ?? ""
      let id = item["id"] as? String ?? ""
      let enabled = item["enabled"] as? Bool ?? true
      let shortcut = item["shortcut"] as? String ?? ""

      let menuItem = NSMenuItem(
        title: label,
        action: enabled ? #selector(contextMenuItemClicked(_:)) : nil,
        keyEquivalent: shortcut
      )
      menuItem.representedObject = id
      menuItem.target = self
      menuItem.isEnabled = enabled
      menu.addItem(menuItem)
    }

    // Show the menu at the current mouse position.
    // NSMenu.popUpContextMenu blocks until the user selects or dismisses.
    let mouseLocation = NSEvent.mouseLocation
    let event = NSEvent.mouseEvent(
      with: .rightMouseDown,
      location: self.convertPoint(fromScreen: mouseLocation),
      modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: self.windowNumber,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1.0
    )!

    _selectedMenuItemId = nil
    NSMenu.popUpContextMenu(menu, with: event, for: self.contentView!)
    return _selectedMenuItemId
  }

  private var _selectedMenuItemId: String?

  @objc private func contextMenuItemClicked(_ sender: NSMenuItem) {
    _selectedMenuItemId = sender.representedObject as? String
  }
}
