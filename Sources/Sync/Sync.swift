
import Foundation

/// A delegate protocol for `Sync` class to communicate clock updates.
public protocol SyncDelegate: AnyObject {
    func didUpdateClock()
}

/// A class responsible for syncing time to musical measures.
public class Sync {
    public typealias TimeSignature = (beatsPerBar: Int, noteValue: Int)
    
    public var bpm: Int
    public var signature: TimeSignature
    
    public weak var delegate: SyncDelegate?
    public var clockCallback: (() -> Void)?
    
    public init(
        bpm: Int,
        signature: TimeSignature,
        delegate: SyncDelegate? = nil,
        clockCallback: (() -> Void)? = nil
    ) {
        self.bpm = bpm
        self.signature = signature
        self.delegate = delegate
    }
    
    private var timer: DispatchSourceTimer?

    /// Starts sync clock.
    public func start() {
        let divisor = signature.beatsPerBar
        let interval = (60.0 / (Double(bpm * divisor)))
        let queue = DispatchQueue(label: "metro-queue", attributes: .concurrent)
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval, leeway: .nanoseconds(0))
        timer?.setEventHandler { [weak self] in
            self?.next()
        }
        timer?.resume()
    }

    /// Triggers the delegate's clock update.
    private func next() {
        delegate?.didUpdateClock()
        clockCallback?()
    }

    /// Stops the synchronization process.
    public func stop() {
        timer?.cancel()
        timer = nil
    }
}

extension Sync {
    /// Calculates the percentage until the next synchronization point from a given position.
    public func percentageUntilSync(_ position: Double, speed: Double, beatCount: Double) -> Double {
        let syncUnitLength = timeUntilSync(at: .zero, speed: speed, beatCount: beatCount)
        let timeUntilNextSyncUnit = timeUntilSync(at: position, speed: speed, beatCount: beatCount)
        return (syncUnitLength - timeUntilNextSyncUnit) / syncUnitLength
    }
    
    /// Calculates the time until the next synchronization point from a given position.
    func timeUntilSync(at position: Double, speed: Double, beatCount multiplier: Double) -> Double {
        let len = beatLength() * multiplier
        let duration = len - (position.truncatingRemainder(dividingBy: len))
        return duration / speed
    }

    /// Returns the current beat index based on the position in time.
    public func currentBeat(from position: Double) -> Int {
        Int(position / (60.0 / Double(bpm))) % signature.beatsPerBar
    }
    
    /// Calculates the length of a beat given the BPM and time signature.
    public func beatLength() -> Double {
        (60.0 / Double(bpm)) * (Double(signature.beatsPerBar) / Double(signature.noteValue))
    }
    
    /// Calculates the length of a bar given the BPM and time signature.
    public func barLength() -> Double {
        let beatLength = beatLength()
        return beatLength * Double(signature.beatsPerBar)
    }
}
