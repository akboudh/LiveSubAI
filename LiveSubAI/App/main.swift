import AppKit

let app = NSApplication.shared
let delegate = LiveSubAIApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
