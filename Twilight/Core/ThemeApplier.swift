import Foundation
import AppKit

public protocol ThemeApplier {
    /// Applies the appearance, returning `.success` or a specific failure.
    func apply(_ appearance: Appearance) -> Result<Void, ThemeApplyError>

    /// Returns the system's currently-applied appearance.
    func currentSystemAppearance() -> Appearance
}

public enum ThemeApplyError: Error, Equatable {
    case automationDenied
    case appleScriptFailed(message: String)
}

public final class AppleScriptThemeApplier: ThemeApplier {

    public init() {}

    public func apply(_ appearance: Appearance) -> Result<Void, ThemeApplyError> {
        let isDark = (appearance == .dark)
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(isDark)
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            return .failure(.appleScriptFailed(message: "could not compile script"))
        }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
        if let err = errorDict {
            let number = (err[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = (err[NSAppleScript.errorMessage] as? String) ?? "unknown"
            // -1743 errAEEventNotPermitted, -600/-609 various permission issues
            if number == -1743 || number == -600 || number == -609 {
                return .failure(.automationDenied)
            }
            return .failure(.appleScriptFailed(message: "\(number): \(message)"))
        }
        return .success(())
    }

    public func currentSystemAppearance() -> Appearance {
        // `Dark` if AppleInterfaceStyle is set; missing/Light otherwise.
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style == "Dark" ? .dark : .light
    }
}
