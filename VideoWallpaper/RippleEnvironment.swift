import SwiftUI

private struct PopoverRippleTriggerKey: EnvironmentKey {
    static let defaultValue: ((Color) -> Void)? = nil
}

private struct ButtonRippleFXEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var popoverRippleTrigger: ((Color) -> Void)? {
        get { self[PopoverRippleTriggerKey.self] }
        set { self[PopoverRippleTriggerKey.self] = newValue }
    }

    var buttonRippleFXEnabled: Bool {
        get { self[ButtonRippleFXEnabledKey.self] }
        set { self[ButtonRippleFXEnabledKey.self] = newValue }
    }
}
