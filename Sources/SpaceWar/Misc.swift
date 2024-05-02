//
//  Misc.swift
//  SpaceWar
//

import MetalEngine

/// Misc stuff from top-level header files `SpaceWar.h` and `stdafx.h` -- expect to move elsewhere
enum Misc {
    static let SPACEWAR_SERVER_VERSION = "1.0.0.0"

    /// UDP port for the spacewar server to listen on
    static let SPACEWAR_SERVER_PORT = UInt16(27015)

    /// UDP port for the master server updater to listen on
    static let SPACEWAR_MASTER_SERVER_UPDATER_PORT = UInt16(27016)

    /// How long to wait for a client to send an update before we drop its connection server side
    static let SERVER_TIMEOUT_MILLISECONDS = UInt(5000)

    /// Maximum number of players who can join a server and play simultaneously
    static let MAX_PLAYERS_PER_SERVER = 4

    /// Time to pause wait after a round ends before starting a new one
    static let MILLISECONDS_BETWEEN_ROUNDS = UInt(4000)

    /// How long photon beams live before expiring
    static let PHOTON_BEAM_LIFETIME_IN_TICKS = UInt(1750)

    /// How fast can photon beams be fired?
    static let PHOTON_BEAM_FIRE_INTERVAL_TICKS = UInt(250)

    /// Amount of space needed for beams per ship
    static let MAX_PHOTON_BEAMS_PER_SHIP = Int(PHOTON_BEAM_LIFETIME_IN_TICKS / PHOTON_BEAM_FIRE_INTERVAL_TICKS)

    /// Time to timeout a connection attempt in
    static let MILLISECONDS_CONNECTION_TIMEOUT = UInt(30000)

    /// How many times a second does the server send world updates to clients
    static let SERVER_UPDATE_SEND_RATE = UInt(60)

    /// How many times a second do we send our updated client state to the server
    static let CLIENT_UPDATE_SEND_RATE = UInt(30)

    /// How fast does the server internally run at?
    static let MAX_CLIENT_AND_SERVER_FPS = 86

    /// Leaderboard names
    static let LEADERBOARD_QUICKEST_WIN = "Quickest Win"
    static let LEADERBOARD_FEET_TRAVELED = "Feet Traveled"

    /// Player colors
    static let PlayerColors: [Color2D] = [
        .rgb_i(255, 150, 150), // red
        .rgb_i(200, 200, 255), // blue
        .rgb_i(255, 204, 102), // orange
        .rgb_i(153, 255, 153), // green
    ]
}

/// Helper to debounce events eg. to avoid one 'esc' press jumping through layers of menus
struct Debounced {
    let sample: () -> Bool
    let debounce: TickSource.TickCount

    private(set) var lastPress: TickSource.TickCount

    /// Wrap a predicate so it returns `true` only once every `debounce` milliseconds
    init(debounce: TickSource.TickCount, sample: @escaping () -> Bool) {
        self.sample = sample
        self.debounce = debounce
        self.lastPress = 0
    }

    mutating func test(now: TickSource.TickCount) -> Bool {
        guard sample(), now.isLongerThan(debounce, since: lastPress) else {
            return false
        }
        lastPress = now
        return true
    }
}

/// Gadget to wrap up the 'state' pattern that gets split three ways in this port.
///
/// Record time of state change
/// Provide call to execute code first time made in new state
/// Provide setter to nop if already there and execute code if not
@MainActor
final class MonitoredState<ActualState: Equatable> {
    let tickSource: TickSource
    let name: String

    init(tickSource: TickSource, initial: ActualState, name: String) {
        self.tickSource = tickSource
        self.name = name
        self.state = initial
        self.transitioned = false
        self.transitionTime = 0
    }

    private(set) var state: ActualState

    func set(_ newState: ActualState, call: () -> Void = {}) {
        guard newState != state else {
            return
        }
        OutputDebugString("\(name) \(state) -> \(newState)")
        state = newState
        transitioned = true
        transitionTime = tickSource.currentTickCount
        call()
    }

    private(set) var transitioned: Bool
    private(set) var transitionTime: TickSource.TickCount

    func onTransition(call: () -> Void) {
        if transitioned {
            transitioned = false
            call()
        }
    }
}
