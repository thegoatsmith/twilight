import SwiftUI
import MapKit
import CoreLocation

struct SettingsView: View {

    @ObservedObject var controller: AppearanceController
    let locationProvider: LocationProvider
    let loginItems: LoginItemManager

    @StateObject private var cities = CityResolver()
    @AppStorage(PreferencesKey.useAutoLocation) private var useAutoLocation: Bool = true
    @AppStorage(PreferencesKey.launchAtLogin) private var launchAtLogin: Bool = true
    @State private var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    @State private var isPickingCity: Bool = false
    @FocusState private var citySearchFocused: Bool

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
        .onAppear { locationAuthStatus = locationProvider.authorizationStatus }
    }

    private var generalTab: some View {
        Form {
            locationSection
            launchSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var aboutTab: some View {
        Form {
            permissionsSection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var locationSection: some View {
        Section {
            Picker("Source", selection: $useAutoLocation) {
                Text("Automatic").tag(true)
                Text("Manual").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: useAutoLocation) { newValue in
                if newValue {
                    locationProvider.setAutoMode()
                    exitPickingMode()
                } else if controller.location == nil {
                    enterPickingMode()
                }
            }

            if useAutoLocation {
                if controller.location != nil {
                    LabeledContent("City") {
                        Text(controller.location?.displayName ?? "Detected")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isPickingCity || controller.location == nil {
                citySearchField
                if !cities.suggestions.isEmpty {
                    suggestionsList
                }
            } else if let city = controller.location {
                LabeledContent("City") {
                    HStack(spacing: 8) {
                        Text(city.displayName ?? "Selected")
                            .foregroundStyle(.secondary)
                        Button("Change") { enterPickingMode() }
                            .buttonStyle(.link)
                    }
                }
            }
        } header: {
            Label("Location", systemImage: "location.fill")
        }
    }

    private var citySearchField: some View {
        HStack {
            TextField("Search city", text: $cities.query, prompt: Text("e.g. Bangkok"))
                .textFieldStyle(.roundedBorder)
                .focused($citySearchFocused)
            if controller.location != nil {
                Button("Cancel") { exitPickingMode() }
                    .buttonStyle(.link)
            }
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(cities.suggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                Button {
                    Task {
                        if let loc = await cities.resolve(suggestion) {
                            locationProvider.setManualLocation(loc)
                            cities.clear()
                            exitPickingMode()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < min(cities.suggestions.count, 5) - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func enterPickingMode() {
        cities.clear()
        isPickingCity = true
        DispatchQueue.main.async { citySearchFocused = true }
    }

    private func exitPickingMode() {
        cities.clear()
        citySearchFocused = false
        isPickingCity = false
    }

    private var launchSection: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch Twilight at login")
            }
            .onChange(of: launchAtLogin) { newValue in
                loginItems.setEnabled(newValue)
            }
        } header: {
            Label("Launch", systemImage: "power")
        }
    }

    private var permissionsSection: some View {
        Section {
            LabeledContent("Location") {
                permissionRow(text: locationAuthLabel,
                              granted: locationAuthStatus == .authorizedAlways || locationAuthStatus == .authorized)
            }
            LabeledContent("Automation") {
                permissionRow(text: controller.hasAutomationPermission ? "Granted" : "Required",
                              granted: controller.hasAutomationPermission) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } header: {
            Label("Permissions", systemImage: "lock.shield")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private func permissionRow(text: String, granted: Bool, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? Color.green : Color.orange)
                .imageScale(.medium)
            Text(text).foregroundStyle(.secondary)
            if !granted, let action {
                Button("Open Settings", action: action)
                    .buttonStyle(.link)
            }
        }
    }

    private var locationAuthLabel: String {
        switch locationAuthStatus {
        case .authorizedAlways, .authorized: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }
}
