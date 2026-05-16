import Foundation
import MapKit
import Combine

public final class CityResolver: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published public var query: String = ""
    @Published public var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var bag: Set<AnyCancellable> = []

    public override init() {
        super.init()
        completer.resultTypes = [.address]
        completer.delegate = self
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] q in
                self?.completer.queryFragment = q
            }
            .store(in: &bag)
    }

    /// Clears the query and any pending suggestions without firing another search.
    public func clear() {
        completer.cancel()
        completer.queryFragment = ""
        suggestions = []
        query = ""
    }

    /// Resolves a completion into a coordinate-bearing `Location`.
    public func resolve(_ completion: MKLocalSearchCompletion) async -> Location? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let name = [item.placemark.locality, item.placemark.country]
                .compactMap { $0 }.joined(separator: ", ")
            return Location(latitude: coord.latitude,
                            longitude: coord.longitude,
                            displayName: name.isEmpty ? completion.title : name)
        } catch {
            return nil
        }
    }

    // MARK: MKLocalSearchCompleterDelegate

    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
}
