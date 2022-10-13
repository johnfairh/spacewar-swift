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

    /// How long to wait for a response from the server before resending our connection attempt
    static let SERVER_CONNECTION_RETRY_MILLISECONDS = 350

    /// How long to wait for a client to send an update before we drop its connection server side
    static let SERVER_TIMEOUT_MILLISECONDS = 5000

    /// Maximum packet size in bytes
    static let MAX_SPACEWAR_PACKET_SIZE = 1024*512

    /// Maximum number of players who can join a server and play simultaneously
    static let MAX_PLAYERS_PER_SERVER = 4

    /// Time to pause wait after a round ends before starting a new one
    static let MILLISECONDS_BETWEEN_ROUNDS = 4000

    /// How long photon beams live before expiring
    static let PHOTON_BEAM_LIFETIME_IN_TICKS = 1750

    /// How fast can photon beams be fired?
    static let PHOTON_BEAM_FIRE_INTERVAL_TICKS = 250

    /// Amount of space needed for beams per ship
    static let MAX_PHOTON_BEAMS_PER_SHIP = PHOTON_BEAM_LIFETIME_IN_TICKS / PHOTON_BEAM_FIRE_INTERVAL_TICKS

    /// Time to timeout a connection attempt in
    static let MILLISECONDS_CONNECTION_TIMEOUT = 30000

    /// How many times a second does the server send world updates to clients
    static let SERVER_UPDATE_SEND_RATE = 60

    /// How many times a second do we send our updated client state to the server
    static let CLIENT_UPDATE_SEND_RATE = 30

    /// How fast does the server internally run at?
    static let X_CLIENT_AND_SERVER_FPS = 86

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

/// Enum for possible game states on the client
enum MainGameState {
    case gameMenu
    case gameExiting
    case gameInstructions

    // so, the menu item can be 'startserver' say
    // then the 'start server' part goes in 'onstatechanged'
    // and the 'runninggame' part goes in 'runFrame'
    case startServer
    case runningGame

    case findInternetServers
    case statsAchievements

    // ditto for these three, should collapse to two
    case createLobby
    case joinLobby
    case doingLobby

    case findLANServers
    case remoteStorage
    case leaderboards
    case friendsList
    case connectingToSteam
    case clanChatRoom
    case webCallback
    case music
    case workshop
    case htmlSurface
    case inGameStore
    case remotePlay
    case overlayAPI
}

/// Enum for possible game states on the server
enum ServerGameState {
  case waitingForPlayers
  case active
  case draw
  case winner
  case exiting
}
