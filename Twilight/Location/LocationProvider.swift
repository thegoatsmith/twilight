import Foundation
import CoreLocation
import Combine

public protocol LocationProvider {
    /// Stream of the latest known location (auto or manual). `nil` until first resolved.
    var location: AnyPublisher<Location?, Never> { get }

    /// Permission state for auto location.
    var authorizationStatus: CLAuthorizationStatus { get }

    /// Asks the system to prompt for permission and start updating.
    func requestAutoLocation()

    /// Switches to manual mode and persists the choice.
    func setManualLocation(_ location: Location)

    /// Switches back to auto mode (re-uses previously-granted permission).
    func setAutoMode()
}

public final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {

    public var location: AnyPublisher<Location?, Never> { subject.eraseToAnyPublisher() }
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let subject = CurrentValueSubject<Location?, Never>(nil)
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let prefs: PreferencesStore

    public init(preferences: PreferencesStore = PreferencesStore()) {
        self.prefs = preferences
        super.init()
        manager.delegate = self
        // Sunrise/sunset only needs city-level precision; request the coarsest
        // useful accuracy for privacy.
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        authorizationStatus = manager.authorizationStatus

        // Boot with whatever is stored.
        if prefs.useAutoLocation, let cached = prefs.lastKnownLocation {
            subject.send(cached)
        } else if !prefs.useAutoLocation, let manual = prefs.manualLocation {
            subject.send(manual)
        }
    }

    public func requestAutoLocation() {
        prefs.useAutoLocation = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    public func setManualLocation(_ location: Location) {
        prefs.useAutoLocation = false
        prefs.manualLocation = location
        manager.stopUpdatingLocation()
        subject.send(location)
    }

    public func setAutoMode() { requestAutoLocation() }

    // MARK: CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        // Round to ~11km — sunrise/sunset don't need more, and storing coarser
        // coordinates limits what's persisted on disk.
        let lat = (last.coordinate.latitude * 10).rounded() / 10
        let lon = (last.coordinate.longitude * 10).rounded() / 10
        let initial = Location(latitude: lat, longitude: lon, displayName: nil)
        prefs.lastKnownLocation = initial
        subject.send(initial)
        manager.stopUpdatingLocation()

        geocoder.reverseGeocodeLocation(last) { [weak self] placemarks, _ in
            guard let self else { return }
            let name = placemarks?.first?.locality
                    ?? placemarks?.first?.subAdministrativeArea
                    ?? placemarks?.first?.administrativeArea
            let updated = Location(latitude: lat, longitude: lon, displayName: name)
            self.prefs.lastKnownLocation = updated
            self.subject.send(updated)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("LocationProvider: \(error.localizedDescription)")
    }
}
