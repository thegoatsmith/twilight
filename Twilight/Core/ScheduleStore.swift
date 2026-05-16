import Foundation

public enum ScheduleStore {

    /// What appearance the controller should apply right now.
    public static func desired(mode: Mode, now: Date, today: SunTimes) -> Appearance {
        switch mode {
        case .manualLight: return .light
        case .manualDark:  return .dark
        case .auto:
            return (now >= today.sunrise && now < today.sunset) ? .light : .dark
        }
    }

    /// When to next re-evaluate in `.auto` mode. Nil for manual modes (use `overrideExpiry`).
    public static func nextTransition(mode: Mode, now: Date, today: SunTimes, tomorrow: SunTimes) -> Date? {
        guard mode == .auto else { return nil }
        if now < today.sunrise { return today.sunrise }
        if now < today.sunset  { return today.sunset }
        return tomorrow.sunrise
    }

    /// When a manual override should expire (return to auto). Nil for `.auto`.
    /// Rule: override expires the next time the auto rule would *disagree* with the override.
    /// - manualLight expires at the next sunset.
    /// - manualDark expires at the next sunrise.
    public static func overrideExpiry(mode: Mode, now: Date, today: SunTimes, tomorrow: SunTimes) -> Date? {
        switch mode {
        case .auto: return nil
        case .manualLight:
            return now < today.sunset ? today.sunset : tomorrow.sunset
        case .manualDark:
            return now < today.sunrise ? today.sunrise : tomorrow.sunrise
        }
    }
}
