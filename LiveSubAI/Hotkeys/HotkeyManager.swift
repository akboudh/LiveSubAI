import Carbon
import Foundation

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var subtitleHotKeyRef: EventHotKeyRef?
    private var translationHotKeyRef: EventHotKeyRef?
    private var toggleHandler: (() -> Void)?
    private var translationModeHandler: (() -> Void)?

    func registerHotkeys(toggleSubtitles: @escaping () -> Void, toggleTranslationMode: @escaping () -> Void) {
        unregisterAll()
        toggleHandler = toggleSubtitles
        translationModeHandler = toggleTranslationMode

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if hotKeyID.id == 1 {
                manager.toggleHandler?()
            } else if hotKeyID.id == 2 {
                manager.translationModeHandler?()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let subtitleHotKeyID = EventHotKeyID(signature: fourCharacterCode("LSAI"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | optionKey),
            subtitleHotKeyID,
            GetApplicationEventTarget(),
            0,
            &subtitleHotKeyRef
        )

        let translationHotKeyID = EventHotKeyID(signature: fourCharacterCode("LSAI"), id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(cmdKey | optionKey),
            translationHotKeyID,
            GetApplicationEventTarget(),
            0,
            &translationHotKeyRef
        )
    }

    func unregisterAll() {
        if let subtitleHotKeyRef {
            UnregisterEventHotKey(subtitleHotKeyRef)
            self.subtitleHotKeyRef = nil
        }
        if let translationHotKeyRef {
            UnregisterEventHotKey(translationHotKeyRef)
            self.translationHotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        toggleHandler = nil
        translationModeHandler = nil
    }

    private func fourCharacterCode(_ code: String) -> OSType {
        code.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
