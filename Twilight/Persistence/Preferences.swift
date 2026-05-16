import Foundation
import SwiftUI

public enum PreferencesKey {
    public static let mode = "mode"
    public static let overrideExpiresAt = "overrideExpiresAt"
    public static let useAutoLocation = "useAutoLocation"
    public static let manualLocation = "manualLocation"          // JSON-encoded Location
    public static let lastKnownLocation = "lastKnownLocation"    // JSON-encoded Location
    public static let launchAtLogin = "launchAtLogin"
    public static let didFinishOnboarding = "didFinishOnboarding"
}

/// Tiny non-SwiftUI accessor for use by `AppearanceController` (which is not a View).
public struct PreferencesStore {

    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var mode: Mode {
        get {
            let raw = defaults.string(forKey: PreferencesKey.mode) ?? Mode.auto.rawValue
            return Mode(rawValue: raw) ?? .auto
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: PreferencesKey.mode) }
    }

    public var overrideExpiresAt: Date? {
        get { defaults.object(forKey: PreferencesKey.overrideExpiresAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: PreferencesKey.overrideExpiresAt) }
    }

    public var useAutoLocation: Bool {
        get { defaults.object(forKey: PreferencesKey.useAutoLocation) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: PreferencesKey.useAutoLocation) }
    }

    public var manualLocation: Location? {
        get { Self.decode(defaults.data(forKey: PreferencesKey.manualLocation)) }
        nonmutating set { defaults.set(Self.encode(newValue), forKey: PreferencesKey.manualLocation) }
    }

    public var lastKnownLocation: Location? {
        get { Self.decode(defaults.data(forKey: PreferencesKey.lastKnownLocation)) }
        nonmutating set { defaults.set(Self.encode(newValue), forKey: PreferencesKey.lastKnownLocation) }
    }

    public var launchAtLogin: Bool {
        get { defaults.object(forKey: PreferencesKey.launchAtLogin) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: PreferencesKey.launchAtLogin) }
    }

    public var didFinishOnboarding: Bool {
        get { defaults.bool(forKey: PreferencesKey.didFinishOnboarding) }
        nonmutating set { defaults.set(newValue, forKey: PreferencesKey.didFinishOnboarding) }
    }

    private static func encode(_ loc: Location?) -> Data? {
        guard let loc else { return nil }
        return try? JSONEncoder().encode(loc)
    }
    private static func decode(_ data: Data?) -> Location? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Location.self, from: data)
    }
}
