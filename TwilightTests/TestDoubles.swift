import Foundation
import Combine
import CoreLocation
@testable import Twilight

final class SpyThemeApplier: ThemeApplier {
    var applied: [Appearance] = []
    var current: Appearance = .light
    var nextResult: Result<Void, ThemeApplyError> = .success(())

    func apply(_ appearance: Appearance) -> Result<Void, ThemeApplyError> {
        applied.append(appearance)
        if case .success = nextResult { current = appearance }
        return nextResult
    }
    func currentSystemAppearance() -> Appearance { current }
}

final class StubLocationProvider: LocationProvider {
    private let subject: CurrentValueSubject<Location?, Never>
    var location: AnyPublisher<Location?, Never> { subject.eraseToAnyPublisher() }
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways

    init(initial: Location?) { self.subject = .init(initial) }
    func requestAutoLocation() {}
    func setManualLocation(_ location: Location) { subject.send(location) }
    func setAutoMode() {}

    func emit(_ location: Location?) { subject.send(location) }
}
