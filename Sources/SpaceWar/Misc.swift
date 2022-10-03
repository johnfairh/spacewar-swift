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
        .rgbai(255, 150, 150), // red
        .rgbai(200, 200, 255), // blue
        .rgbai(255, 204, 102), // orange
        .rgbai(153, 255, 153), // green
    ]
}

extension Color2D {
    /// Helper to allow color spec using integer 0-255
    static func rgbai(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 255) -> Color2D {
        .rgba(Float(r)/255.0, Float(g)/255.0, Float(b)/255.0, Float(a)/255.0)
    }
}

/// Enum for possible game states on the client
enum ClientGameState {
  case gameStartServer
  case gameActive
  case gameWaitingForPlayers
  case gameMenu
  case gameQuitMenu
  case gameExiting
  case gameInstructions
  case gameDraw
  case gameWinner
  case gameConnecting
  case gameConnectionFailure
  case findInternetServers
  case statsAchievements
  case creatingLobby
  case inLobby
  case findLobby
  case joiningLobby
  case findLANServers
  case remoteStorage
  case leaderboards
  case friendsList
  case minidump
  case connectingToSteam
  case linkSteamAccount
  case autoCreateAccount
  case retrySteamConnection
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

import Darwin
import Dispatch
import AppKit

func OutputDebugString(_ msg: String) {
    fputs(msg, stderr)
}

/// Helper to display critical errors
@discardableResult
func Alert(caption: String, text: String) -> Int {
    OutputDebugString("ALERT: \(caption): \(text)\n")
    let alert = NSAlert.init()
    alert.messageText = caption
    alert.informativeText = text
    alert.addButton(withTitle: "OK")
    alert.runModal()
    return 0 // apparently
}

func GetUserSaveDataPath() -> String {
    preconditionFailure("This is supposed to be PS3-only")
}

/// CEG -- don't think this exists on macOS, we don't have it at any rate
func Steamworks_InitCEGLibrary() -> Bool { true }
func Steamworks_TermCEGLibrary() {}
func Steamworks_TestSecret() {}
func Steamworks_SelfCheck() {}
