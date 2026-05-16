import Foundation
import Combine
import AppKit

public final class AppearanceController: ObservableObject {

    @Published public private(set) var mode: Mode = .auto
    @Published public private(set) var todaySun: SunTimes?
    @Published public private(set) var nextEventAt: Date?
    @Published public private(set) var location: Location?
    @Published public private(set) var hasAutomationPermission: Bool = true

    private let clock: Clock
    private let applier: ThemeApplier
    private let locationProvider: LocationProvider
    private let prefs: PreferencesStore
    private var bag: Set<AnyCancellable> = []
    private var timer: DispatchSourceTimer?

    public init(clock: Clock = SystemClock(),
                applier: ThemeApplier = AppleScriptThemeApplier(),
                locationProvider: LocationProvider,
                preferences: PreferencesStore = PreferencesStore()) {
        self.clock = clock
        self.applier = applier
        self.locationProvider = locationProvider
        self.prefs = preferences
        self.mode = prefs.mode
        restoreOverrideIfStillValid()
    }

    public func start() {
        locationProvider.location
            .sink { [weak self] loc in
                self?.location = loc
                self?.reevaluate()
            }
            .store(in: &bag)

        NotificationCenter.default
            .publisher(for: NSWorkspace.didWakeNotification, object: NSWorkspace.shared)
            .sink { [weak self] _ in self?.reevaluate() }
            .store(in: &bag)

        NotificationCenter.default
            .publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            .sink { [weak self] _ in self?.reevaluate() }
            .store(in: &bag)

        DistributedNotificationCenter.default
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .sink { [weak self] _ in self?.handleExternalAppearanceChange() }
            .store(in: &bag)

        reevaluate()
    }

    // MARK: - Public actions

    public func switchToLight() { setMode(.manualLight) }
    public func switchToDark()  { setMode(.manualDark) }
    public func resumeAuto()    { setMode(.auto) }

    // MARK: - Internals

    private func setMode(_ newMode: Mode) {
        mode = newMode
        prefs.mode = newMode
        if newMode == .auto {
            prefs.overrideExpiresAt = nil
        } else if let sun = todaySun {
            let tomorrowSun = tomorrowSunTimes(for: location, basedOn: sun)
            prefs.overrideExpiresAt = ScheduleStore.overrideExpiry(
                mode: newMode, now: clock.now(), today: sun, tomorrow: tomorrowSun
            )
        }
        reevaluate()
    }

    private func reevaluate() {
        let now = clock.now()

        // Expire override if past.
        if let expires = prefs.overrideExpiresAt, expires <= now {
            mode = .auto
            prefs.mode = .auto
            prefs.overrideExpiresAt = nil
        }

        // Compute sun times for current location.
        guard let loc = location else {
            return
        }
        let today = SolarCalculator.sunTimes(latitude: loc.latitude, longitude: loc.longitude, date: now)
        self.todaySun = today

        // Decide what to apply.
        let desired: Appearance
        if let today {
            desired = ScheduleStore.desired(mode: mode, now: now, today: today)
        } else {
            // polar — fall back to applier's view of system, or default light.
            desired = applier.currentSystemAppearance()
        }

        if desired != applier.currentSystemAppearance() {
            applyAppearance(desired)
        }

        // Schedule next.
        guard let today else { nextEventAt = nil; return }
        let tomorrow = tomorrowSunTimes(for: loc, basedOn: today)
        let next: Date?
        if mode == .auto {
            next = ScheduleStore.nextTransition(mode: .auto, now: now, today: today, tomorrow: tomorrow)
        } else {
            next = prefs.overrideExpiresAt
        }
        nextEventAt = next
        scheduleTimer(for: next)
    }

    private func applyAppearance(_ appearance: Appearance) {
        switch applier.apply(appearance) {
        case .success:
            hasAutomationPermission = true
        case .failure(.automationDenied):
            hasAutomationPermission = false
        case .failure(.appleScriptFailed(let msg)):
            NSLog("ThemeApplier failed: \(msg)")
        }
    }

    private func handleExternalAppearanceChange() {
        // In manual mode, no-op. In auto mode, re-enforce.
        guard mode == .auto else { return }
        reevaluate()
    }

    private func scheduleTimer(for fireDate: Date?) {
        timer?.cancel(); timer = nil
        guard let fireDate else { return }
        let interval = fireDate.timeIntervalSince(clock.now())
        guard interval > 0 else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + interval, leeway: .seconds(1))
        t.setEventHandler { [weak self] in self?.reevaluate() }
        timer = t
        t.resume()
    }

    private func restoreOverrideIfStillValid() {
        guard prefs.mode != .auto, let expires = prefs.overrideExpiresAt else { return }
        if expires <= clock.now() {
            prefs.mode = .auto
            prefs.overrideExpiresAt = nil
            mode = .auto
        }
    }

    private func tomorrowSunTimes(for location: Location?, basedOn today: SunTimes) -> SunTimes {
        guard let loc = location else { return today }
        // Anchor off today's sunset: in timezones far from UTC, today.sunrise can lie
        // in the *previous* UTC day, so adding 24h to it lands back in today's UTC day
        // and SolarCalculator would return today's times again.
        let tomorrowAnchor = today.sunset.addingTimeInterval(86_400)
        return SolarCalculator.sunTimes(latitude: loc.latitude,
                                        longitude: loc.longitude,
                                        date: tomorrowAnchor) ?? today
    }
}
