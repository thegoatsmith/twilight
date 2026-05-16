import Foundation

public protocol Clock {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

public final class FakeClock: Clock {
    public var current: Date
    public init(_ initial: Date) { self.current = initial }
    public func now() -> Date { current }
    public func advance(by interval: TimeInterval) { current.addTimeInterval(interval) }
}
