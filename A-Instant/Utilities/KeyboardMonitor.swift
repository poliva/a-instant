import AppKit
import Carbon

enum TriggerKey: String, CaseIterable, Identifiable {
    case rightShift = "Right Shift"
    case leftShift = "Left Shift"
    case rightCommand = "Right Command"
    case leftCommand = "Left Command"
    case rightOption = "Right Option"
    case leftOption = "Left Option"
    case rightControl = "Right Control"
    case leftControl = "Left Control"
    case capsLock = "Caps Lock"
    case tab = "Tab"
    case commandShiftP = "Command+Shift+P"
    case commandShiftSpace = "Command+Shift+Space"
    case optionSpace = "Option+Space"
    case commandP = "Command+P"
    case f1 = "F1"
    case f12 = "F12"
    
    var id: String { self.rawValue }
    
    var keyCode: UInt16 {
        switch self {
        case .rightShift: return 0x3C
        case .leftShift: return 0x38
        case .rightCommand: return 0x3E
        case .leftCommand: return 0x37
        case .rightOption: return 0x3D
        case .leftOption: return 0x3A
        case .rightControl: return 0x3E
        case .leftControl: return 0x3B
        case .capsLock: return 0x39
        case .tab: return 0x30
        case .commandShiftP: return 0x23  // P key
        case .commandShiftSpace: return 0x31  // Space key
        case .optionSpace: return 0x31  // Space key
        case .commandP: return 0x23  // P key
        case .f1: return 0x7A
        case .f12: return 0x6F
        }
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .rightShift, .leftShift:
            return .shift
        case .rightCommand, .leftCommand:
            return .command
        case .rightOption, .leftOption:
            return .option
        case .rightControl, .leftControl:
            return .control
        case .commandShiftP:
            return [.command, .shift]
        case .commandShiftSpace:
            return [.command, .shift]
        case .optionSpace:
            return .option
        case .commandP:
            return .command
        case .capsLock, .tab, .f1, .f12:
            return []
        }
    }
    
    var isComboKey: Bool {
        switch self {
        case .commandShiftP, .commandShiftSpace, .optionSpace, .commandP:
            return true
        default:
            return false
        }
    }
}

enum KeyboardMonitorError: Error {
    case monitoringAlreadyActive
    case monitoringFailed(String)
}

class KeyboardMonitor {
    var onTriggerKeyDetected: (() -> Void)?
    
    private var flagsChangedMonitor: Any?
    private var keyDownMonitor: Any?
    private var lastKeyPressTime: TimeInterval = 0
    private var isMonitoring = false
    private var lastTriggerActivation: TimeInterval = 0
    private let cooldownPeriod: TimeInterval = 1.0 // Prevent multiple rapid activations
    
    private var triggerKey: TriggerKey {
        let keyString = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerKey) ?? TriggerKey.rightShift.rawValue
        return TriggerKey.allCases.first { $0.rawValue == keyString } ?? .rightShift
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Monitor for modifier key changes (like Shift, Command, etc.)
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            self.handleFlagsChanged(event)
        }
        
        // Monitor for regular key down events (for non-modifier keys like Tab)
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            self.handleKeyDown(event)
        }
        
        isMonitoring = true
        print("Keyboard monitoring started successfully")
    }
    
    func stopMonitoring() {
        if let flagsMonitor = flagsChangedMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            flagsChangedMonitor = nil
        }
        
        if let keyMonitor = keyDownMonitor {
            NSEvent.removeMonitor(keyMonitor)
            keyDownMonitor = nil
        }
        
        isMonitoring = false
        print("Keyboard monitoring stopped")
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        // Only process modifier keys
        guard isModifierKey(triggerKey) else { return }
        
        let keyCode = event.keyCode
        
        // Check if the pressed key is our trigger key
        guard keyCode == triggerKey.keyCode else { return }
        
        // Determine if key was pressed or released by checking modifier flags
        let isKeyDown = event.modifierFlags.contains(triggerKey.modifierFlags)
        
        // Only process key down events for double-tap detection
        if isKeyDown {
            // Check for double press
            let currentTime = NSDate().timeIntervalSince1970
            let timeDiff = currentTime - lastKeyPressTime
            
            // If key was pressed within 0.5 seconds of the last press, it's a double press
            if timeDiff < 0.5 && timeDiff > 0.05 { // Avoid accidental triggers if too quick
                // Check cooldown period
                if currentTime - lastTriggerActivation > cooldownPeriod {
                    lastTriggerActivation = currentTime
                    DispatchQueue.main.async { [weak self] in
                        self?.onTriggerKeyDetected?()
                    }
                }
            }
            
            lastKeyPressTime = currentTime
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        
        if triggerKey.isComboKey {
            // For combo keys (like Cmd+Shift+P), check for exact match
            if keyCode == triggerKey.keyCode && modifiers.contains(triggerKey.modifierFlags) {
                // Trigger immediately for combo keys
                let currentTime = NSDate().timeIntervalSince1970
                
                // Check cooldown period
                if currentTime - lastTriggerActivation > cooldownPeriod {
                    lastTriggerActivation = currentTime
                    DispatchQueue.main.async { [weak self] in
                        self?.onTriggerKeyDetected?()
                    }
                }
            }
            return
        }
        
        // Only process non-modifier keys for non-combo triggers
        guard !isModifierKey(triggerKey) else { return }
        
        // Check if the pressed key is our trigger key
        guard keyCode == triggerKey.keyCode else { return }
        
        // Check for double press
        let currentTime = NSDate().timeIntervalSince1970
        let timeDiff = currentTime - lastKeyPressTime
        
        // If key was pressed within 0.5 seconds of the last press, it's a double press
        if timeDiff < 0.5 && timeDiff > 0.05 { // Avoid accidental triggers if too quick
            // Check cooldown period
            if currentTime - lastTriggerActivation > cooldownPeriod {
                lastTriggerActivation = currentTime
                DispatchQueue.main.async { [weak self] in
                    self?.onTriggerKeyDetected?()
                }
            }
        }
        
        lastKeyPressTime = currentTime
    }
    
    private func isModifierKey(_ key: TriggerKey) -> Bool {
        switch key {
        case .rightShift, .leftShift, .rightCommand, .leftCommand, 
             .rightOption, .leftOption, .rightControl, .leftControl, .capsLock:
            return true
        case .tab, .commandShiftP, .commandShiftSpace, .optionSpace, .commandP, .f1, .f12:
            return false
        }
    }
} 