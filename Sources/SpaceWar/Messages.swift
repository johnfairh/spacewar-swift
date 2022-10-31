//
//  Messages.swift
//  SpaceWar
//

/// Network layer
///
/// Network byte format is BIG ENDIAN
/// 'bool' C++ types are 1 byte wide
///
/// We form the serialized messages using a C header file to define the fixed-layout structs and
/// laboriously shuffle data in and out of them.
///
/// All of a sudden I yearn for text-based interchange formats.

import Steamworks
import Foundation
import CSpaceWar

/// Disconnect reason - bit of a disaster with the types, raw enum values a bit broken
enum DisconnectReason {
    static let clientDisconnect = Int(SteamNetConnectionEnd.appMin.rawValue + 1)
    static let serverClosed = Int(SteamNetConnectionEnd.appMin.rawValue + 2)
    static let serverReject = Int(SteamNetConnectionEnd.appMin.rawValue + 3)
    static let serverFull = Int(SteamNetConnectionEnd.appMin.rawValue + 4)
    static let clientKicked = Int(SteamNetConnectionEnd.appMin.rawValue + 5)
}

/// Network message types
enum Msg: UInt32 {
    // Server messages
    case serverBegin = 0
    case serverSendInfo = 1
    case serverFailAuthentication = 2
    case serverPassAuthentication = 3
    case serverUpdateWorld = 4
    case serverExiting = 5

    // Client messages
    case clientBegin = 500
    case clientBeginAuthentication = 502
    case clientSendLocalUpdate = 503

    // P2P authentication messages
    case P2PBegin = 600
    case P2PSendingTicket = 601

    // voice chat messages
    case voiceChatBegin = 700
    case voiceChatData = 702
}

// MARK: Message Common Protocols

protocol ConstructableFrom {
    associatedtype From
    init(from: From)
}

protocol SpaceWarMsg: ConstructableFrom {
    associatedtype CType where CType == From, CType: ConstructableFrom, CType.From == Self
}

extension SpaceWarMsg {
    /// The number of bytes we expect to receive to be able to decode this message
    static var networkSize: Int {
        MemoryLayout<CType>.size
    }

    /// Construct the wire-format (packed, endian) of this message and pass to the callback
    func inWireFormat<T>(_ call: (UnsafeRawPointer, Int) -> T) -> T {
        let copy = CType(from: self)
        return withUnsafeBytes(of: copy) { urbp in
            call(urbp.baseAddress!, urbp.count)
        }
    }

    /// Deserialize a wire-format version of this message
    init(data: UnsafeMutableRawPointer) {
        let bound = data.bindMemory(to: From.self, capacity: 1)
        self.init(from: bound.pointee)
    }
}

/// Utilities for mangling data buffers
enum Unpack {
    /// Grab the first 32-bit value of the data, says what the message is
    static func msgDword(_ data: UnsafeMutableRawPointer) -> Msg? {
        data.withMemoryRebound(to: UInt32.self, capacity: 1) {
            Msg(rawValue: UInt32(bigEndian: $0.pointee))
        }
    }
}

// MARK: MsgServerSendInfo

/// Msg from the server to the client which is sent right after communications are established
/// and tells the client what SteamID the game server is using as well as whether the server is secure
struct MsgServerSendInfo: SpaceWarMsg {
    typealias CType = MsgServerSendInfo_t

    let steamIDServer: SteamID
    let isVACSecure: Bool
    let serverName: String

    /// Server - sender - init
    init(steamID: SteamID, isVACSecure: Bool, serverName: String) {
        self.steamIDServer = steamID
        self.isVACSecure = isVACSecure
        self.serverName = serverName
    }

    /// Client - receiver - init
    init(from: MsgServerSendInfo_t) {
        steamIDServer = SteamID(UInt64(bigEndian: from.steamIDServer))
        isVACSecure = from.isVACSecure == 1
        serverName = String(cString: from.serverName_ptr)
    }
}

extension MsgServerSendInfo_t: ConstructableFrom {
    /// Serializer - sender-side
    init(from: MsgServerSendInfo) {
        self.init()
        messageType = Msg.serverSendInfo.rawValue.bigEndian
        steamIDServer = from.steamIDServer.asUInt64.bigEndian
        isVACSecure = from.isVACSecure ? 1 : 0
        withUnsafeMutablePointer(to: &self) { p in
            MsgServerSendInfo_SetServerName(p, from.serverName)
        }
    }
}

// MARK: MsgServerFailAuthentication

/// Msg from the server to the client when refusing a connection
struct MsgServerFailAuthentication: SpaceWarMsg {
    typealias CType = MsgServerFailAuthentication_t

    init() {}
    init(from: MsgServerFailAuthentication_t) {}
}

extension MsgServerFailAuthentication_t: ConstructableFrom {
    init(from: MsgServerFailAuthentication) {
        self.init()
        messageType = Msg.serverFailAuthentication.rawValue.bigEndian
    }
}

// MARK: MsgServerPassAuthentication

/// Msg from the server to the client when accepting a pending connection
struct MsgServerPassAuthentication: SpaceWarMsg {
    typealias CType = MsgServerPassAuthentication_t

    let playerPosition: UInt32

    init(playerPosition: UInt32) {
        self.playerPosition = playerPosition
    }

    init(from: MsgServerPassAuthentication_t) {
        playerPosition = UInt32(bigEndian: from.playerPosition)
    }
}

extension MsgServerPassAuthentication_t: ConstructableFrom {
    init(from: MsgServerPassAuthentication) {
        self.init()
        messageType = Msg.serverPassAuthentication.rawValue.bigEndian
        playerPosition = from.playerPosition.bigEndian
    }
}

// MARK: MsgServerUpdateWorld

struct ServerShipUpdateData {
    init() {}
    init(_ from: ServerShipUpdateData_t) {
    }
}

/// Msg from the server to the client when refusing a connection
struct MsgServerUpdateWorld: SpaceWarMsg {
    typealias CType = MsgServerUpdateWorld_t

    /// Current state of the server state machine (!)
    let currentGameState: SpaceWarServer.State

    /// Who just won the game? -- only valid when m_eCurrentGameState == k_EGameWinner
    let playerWhoWonGame: PlayerIndex

    /// Which player slots are in use
    var playersActive: [Bool]

    /// What are the scores for each player?
    var playerScores: [UInt32]

    /// Detailed player data
    var shipData: [ServerShipUpdateData]

    /// Array of players steamids for each slot
    var playerSteamIDs: [SteamID]

    init(gameState: SpaceWarServer.State, playerWhoWonGame: PlayerIndex) {
        self.currentGameState = gameState
        self.playerWhoWonGame = playerWhoWonGame
        self.playersActive = .init(repeating: false, count: Misc.MAX_PLAYERS_PER_SERVER)
        self.playerScores = .init(repeating: 0, count: Misc.MAX_PLAYERS_PER_SERVER)
        self.shipData = .init(repeating: .init(), count: Misc.MAX_PLAYERS_PER_SERVER)
        self.playerSteamIDs = .init(repeating: .nil, count: Misc.MAX_PLAYERS_PER_SERVER)
    }

    init(from: MsgServerUpdateWorld_t) {
        currentGameState = .init(rawValue: UInt32(bigEndian: from.d.currentGameState))!
        playerWhoWonGame = PlayerIndex(bigEndian: Int(from.d.playerWhoWonGame))
        playersActive = .four(from.d.playersActive_ptr ) { $0 != 0 }
        playerScores = .four(from.d.playerScores_ptr) { .init(bigEndian: $0) }
        shipData = .four(from.d.shipData_ptr) { ServerShipUpdateData($0) }
        playerSteamIDs = .four(from.d.playerSteamIDs_ptr) { .init(UInt64(bigEndian: $0)) }
    }
}

extension MsgServerUpdateWorld_t: ConstructableFrom {
    init(from: MsgServerUpdateWorld) {
        self.init()
        messageType = Msg.serverUpdateWorld.rawValue.bigEndian
        d.currentGameState = from.currentGameState.rawValue.bigEndian
        d.playerWhoWonGame = UInt32(from.playerWhoWonGame).bigEndian
        d.playersActive = from.playersActive.asFour { $0 ? 1 : 0 }
        d.playerScores = from.playerScores.asFour { $0.bigEndian }
        d.shipData = from.shipData.asFour { _ in .init() }
        d.playerSteamIDs = from.playerSteamIDs.asFour { $0.asUInt64.bigEndian }
    }
}

// holy fuck
extension Array {
    static func four<X>(_ p: UnsafeMutablePointer<X>, map: (X) -> Element) -> Array<Element>{
        let bp = UnsafeMutableBufferPointer(start: p, count: 4)
        return bp.map(map)
    }

    func asFour<X>(map: (Element) -> X) -> (X, X, X, X) {
        (map(self[0]), map(self[1]), map(self[2]), map(self[3]))
    }
}

// MARK: MsgServerExiting

/// Msg from the server to the client when refusing a connection
struct MsgServerExiting: SpaceWarMsg {
    typealias CType = MsgServerExiting_t

    init() {}
    init(from: MsgServerExiting_t) {}
}

extension MsgServerExiting_t: ConstructableFrom {
    init(from: MsgServerExiting) {
        self.init()
        messageType = Msg.serverExiting.rawValue.bigEndian
    }
}

// MARK: MsgClientBeginAuthentication

/// Msg from client to server when initiating authentication
struct MsgClientBeginAuthentication: SpaceWarMsg {
    typealias CType = MsgClientBeginAuthentication_t

    let token: [UInt8]
    let steamID: UInt64

    /// Client - sender - init
    init(token: [UInt8]) {
        self.token = token
        self.steamID = 0 // uh this isn't filled in or used...
    }

    /// Server - receiver - init
    init(from: MsgClientBeginAuthentication_t) {
        token = Array(UnsafeRawBufferPointer(start: from.token_ptr, count: Int(UInt32(bigEndian: from.tokenLen))))
        steamID = from.steamID
    }
}

extension MsgClientBeginAuthentication_t: ConstructableFrom {
    /// Serializer - sender-side
    init(from: MsgClientBeginAuthentication) {
        self.init()
        messageType = Msg.clientBeginAuthentication.rawValue.bigEndian
        withUnsafeMutablePointer(to: &self) { p in
            MsgClientBeginAuthentication_SetToken(p, from.token, UInt32(from.token.count))
        }
        tokenLen = UInt32(from.token.count).bigEndian
        steamID = 0
    }
}
