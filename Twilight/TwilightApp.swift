import SwiftUI

@main
struct TwilightApp: App {

    @NSApplicationDelegateAdaptor(OnboardingCoordinator.self) private var onboarding
    @StateObject private var controller: AppearanceController
    private let locationProvider: LocationProvider
    private let loginItems = LoginItemManager()

    init() {
        let provider = CoreLocationProvider()
        self.locationProvider = provider
        let ctrl = AppearanceController(
            locationProvider: provider,
            preferences: PreferencesStore()
        )
        _controller = StateObject(wrappedValue: ctrl)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
                .onAppear {
                    controller.start()
                    locationProvider.requestAutoLocation()
                }
        } label: {
            MenuBarIcon(appearance: appearanceForIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller,
                         locationProvider: locationProvider,
                         loginItems: loginItems)
        }
    }

    private var appearanceForIcon: Appearance {
        switch controller.mode {
        case .manualLight: return .light
        case .manualDark:  return .dark
        case .auto:
            if let sun = controller.todaySun {
                return ScheduleStore.desired(mode: .auto, now: Date(), today: sun)
            }
            return .light
        }
    }
}
