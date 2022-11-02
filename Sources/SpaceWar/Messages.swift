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

// MARK: Message Protocols & Utils

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

/// Float values wire format - bitpattern, big-endianly
typealias FloatBE = UInt32

/// Utils to convert between `Float` and `FloatBE`
extension Float {
    init(bigEndian: FloatBE) {
        self.init(bitPattern: UInt32(bigEndian: bigEndian))
    }

    var bigEndian: FloatBE {
        self.bitPattern.bigEndian
    }
}

/// Util to convert from `FloatBE` pairs to `SIMD2`
extension SIMD2<Float> {
    init(bigEndian: (FloatBE, FloatBE)) {
        self.init(Float(bigEndian: bigEndian.0), Float(bigEndian: bigEndian.1))
    }
}

/// Utils to convert Swift `Bool` to 1-byte network format
extension Bool {
    init(bigEndian: UInt8) {
        self.init(bigEndian != 0)
    }

    var bigEndian: UInt8 {
        self ? 1 : 0
    }
}

/// Fixed-size array tuple bullshit. holy fuck.
extension Array {
    static func four<X>(_ p: UnsafeMutablePointer<X>, map: (X) -> Element) -> Array<Element>{
        let bp = UnsafeMutableBufferPointer(start: p, count: 4)
        return bp.map(map)
    }

    static func seven<X>(_ p: UnsafeMutablePointer<X>, map: (X) -> Element) -> Array<Element>{
        let bp = UnsafeMutableBufferPointer(start: p, count: 7)
        return bp.map(map)
    }

    func asFour<X>(map: (Element) -> X) -> (X, X, X, X) {
        (map(self[0]), map(self[1]), map(self[2]), map(self[3]))
    }

    func asSeven<X>(map: (Element) -> X) -> (X, X, X, X, X, X, X) {
        (map(self[0]), map(self[1]), map(self[2]), map(self[3]),
         map(self[4]), map(self[5]), map(self[6]))
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
        isVACSecure = .init(bigEndian: from.isVACSecure)
        serverName = String(cString: from.serverName_ptr)
    }
}

extension MsgServerSendInfo_t: ConstructableFrom {
    /// Serializer - sender-side
    init(from: MsgServerSendInfo) {
        self.init()
        messageType = Msg.serverSendInfo.rawValue.bigEndian
        steamIDServer = from.steamIDServer.asUInt64.bigEndian
        isVACSecure = from.isVACSecure.bigEndian
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

/// Data sent per photon beam from the server to update clients photon beam positions
struct ServerPhotonBeamUpdateData {
    let isActive: Bool
    let currentRotation: Float
    let velocity: SIMD2<Float>
    let position: SIMD2<Float>

    internal init(isActive: Bool = false,
                  currentRotation: Float = 0,
                  velocity: SIMD2<Float> = .zero,
                  position: SIMD2<Float> = .zero) {
        self.isActive = isActive
        self.currentRotation = currentRotation
        self.velocity = velocity
        self.position = position
    }

    init(_ from: ServerPhotonBeamUpdateData_t) {
        self.isActive = .init(bigEndian: from.isActive)
        self.currentRotation = Float(bigEndian: from.currentRotation)
        self.velocity = .init(bigEndian: (from.xVelocity, from.yVelocity))
        self.position = .init(bigEndian: (from.xPosition, from.yPosition))
    }
}

extension ServerPhotonBeamUpdateData_t {
    init(from: ServerPhotonBeamUpdateData) {
        self.init()
        isActive = from.isActive.bigEndian
        currentRotation = from.currentRotation.bigEndian
        xVelocity = from.velocity.x.bigEndian
        yVelocity = from.velocity.y.bigEndian
        xPosition = from.position.x.bigEndian
        yPosition = from.position.y.bigEndian
    }
}

/// This is the data that gets sent per ship in each update, see below for the full update data
struct ServerShipUpdateData {
    let currentRotation: Float
    let rotationDeltaLastFrame: Float
    let acceleration: SIMD2<Float>
    let velocity: SIMD2<Float>
    let position: SIMD2<Float>
    let isExploding: Bool
    let isDisabled: Bool
    let areForwardThrustersActive: Bool
    let areReverseThrustersActive: Bool
    let decoration: Int
    let weapon: Int
    let shipPower: Int
    let shieldStrength: Int
    let photonBeamData: [ServerPhotonBeamUpdateData]
    let thrusterLevel: Float
    let turnSpeed: Float

    init(currentRotation: Float = 0,
         rotationDeltaLastFrame: Float = 0,
         acceleration: SIMD2<Float> = .zero,
         velocity: SIMD2<Float> = .zero,
         position: SIMD2<Float> = .zero,
         isExploding: Bool = false,
         isDisabled: Bool = false,
         areForwardThrustersActive: Bool = false,
         areReverseThrustersActive: Bool = false,
         decoration: Int = 0,
         weapon: Int = 0,
         shipPower: Int = 0,
         shieldStrength: Int = 0,
         photonBeamData: [ServerPhotonBeamUpdateData] = .init(repeating: .init(), count: Misc.MAX_PHOTON_BEAMS_PER_SHIP),
         thrusterLevel: Float = 0,
         turnSpeed: Float = 0) {
        self.currentRotation = currentRotation
        self.rotationDeltaLastFrame = rotationDeltaLastFrame
        self.acceleration = acceleration
        self.velocity = velocity
        self.position = position
        self.isExploding = isExploding
        self.isDisabled = isDisabled
        self.areForwardThrustersActive = areForwardThrustersActive
        self.areReverseThrustersActive = areReverseThrustersActive
        self.decoration = decoration
        self.weapon = weapon
        self.shipPower = shipPower
        self.shieldStrength = shieldStrength
        self.photonBeamData = photonBeamData
        self.thrusterLevel = thrusterLevel
        self.turnSpeed = turnSpeed
    }

    init(_ from: ServerShipUpdateData_t) {
        currentRotation = Float(bigEndian: from.currentRotation)
        rotationDeltaLastFrame = Float(bigEndian: from.rotationDeltaLastFrame)
        acceleration = .init(bigEndian: (from.xAcceleration, from.yAcceleration))
        velocity = .init(bigEndian: (from.xVelocity, from.yVelocity))
        position = .init(bigEndian: (from.xPosition, from.yPosition))
        isExploding = .init(bigEndian: from.exploding)
        isDisabled = .init(bigEndian: from.disabled)
        areForwardThrustersActive = .init(bigEndian: from.forwardThrustersActive)
        areReverseThrustersActive = .init(bigEndian: from.reverseThrustersActive)
        decoration = Int(Int32(bigEndian: from.shipDecoration))
        weapon = Int(Int32(bigEndian: from.shipWeapon))
        shipPower = Int(Int32(bigEndian: from.shipPower))
        shieldStrength = Int(Int32(bigEndian: from.shieldStrength))
        photonBeamData = .seven(from.photonBeamData_ptr) { ServerPhotonBeamUpdateData($0) }
        thrusterLevel = Float(bigEndian: from.thrusterLevel)
        turnSpeed = Float(bigEndian: from.turnSpeed)
    }
}

extension ServerShipUpdateData_t {
    init(from: ServerShipUpdateData) {
        self.init()
        currentRotation = from.currentRotation.bigEndian
        rotationDeltaLastFrame = from.rotationDeltaLastFrame.bigEndian
        xAcceleration = from.acceleration.x.bigEndian
        yAcceleration = from.acceleration.y.bigEndian
        xVelocity = from.velocity.x.bigEndian
        yVelocity = from.velocity.y.bigEndian
        xPosition = from.position.x.bigEndian
        yPosition = from.position.y.bigEndian
        exploding = from.isExploding.bigEndian
        disabled = from.isDisabled.bigEndian
        forwardThrustersActive = from.areForwardThrustersActive.bigEndian
        reverseThrustersActive = from.areReverseThrustersActive.bigEndian
        shipDecoration = Int32(from.decoration).bigEndian
        shipWeapon = Int32(from.weapon).bigEndian
        shipPower = Int32(from.shipPower).bigEndian
        shieldStrength = Int32(from.shieldStrength).bigEndian
        photonBeamData = from.photonBeamData.asSeven() { .init(from: $0) }
        thrusterLevel = from.thrusterLevel.bigEndian
        turnSpeed = from.turnSpeed.bigEndian
    }
}

/// Msg from the server to clients when updating the world state
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
        playersActive = .four(from.d.playersActive_ptr ) { .init(bigEndian: $0) }
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
        d.playersActive = from.playersActive.asFour { $0.bigEndian }
        d.playerScores = from.playerScores.asFour { $0.bigEndian }
        d.shipData = from.shipData.asFour { .init(from: $0) }
        d.playerSteamIDs = from.playerSteamIDs.asFour { $0.asUInt64.bigEndian }
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

// MARK: MsgClientSendLocalUpdate

struct ClientSpaceWarUpdateData {
    var firePressed: Bool
    var turnLeftPressed: Bool
    var turnRightPressed: Bool
    var forwardThrustersPressed: Bool
    var reverseThrustersPressed: Bool
    var shipDecoration: Int
    var shipWeapon: Int
    var shipPower: Int
    var shieldStrength: Int
    var playerName: String
    var thrusterLevel: Float
    var turnSpeed: Float

    init(firePressed: Bool = false,
         turnLeftPressed: Bool = false,
         turnRightPressed: Bool = false,
         forwardThrustersPressed: Bool = false,
         reverseThrustersPressed: Bool = false,
         shipDecoration: Int = 0,
         shipWeapon: Int = 0,
         shipPower: Int = 0,
         shieldStrength: Int = 0,
         playerName: String = "",
         thrusterLevel: Float = 0,
         turnSpeed: Float = 0) {
        self.firePressed = firePressed
        self.turnLeftPressed = turnLeftPressed
        self.turnRightPressed = turnRightPressed
        self.forwardThrustersPressed = forwardThrustersPressed
        self.reverseThrustersPressed = reverseThrustersPressed
        self.shipDecoration = shipDecoration
        self.shipWeapon = shipWeapon
        self.shipPower = shipPower
        self.shieldStrength = shieldStrength
        self.playerName = playerName
        self.thrusterLevel = thrusterLevel
        self.turnSpeed = turnSpeed
    }

    init(from: ClientSpaceWarUpdateData_t) {
        firePressed = Bool(bigEndian: from.firePressed)
        turnLeftPressed = Bool(bigEndian: from.turnLeftPressed)
        turnRightPressed = Bool(bigEndian: from.turnRightPressed)
        forwardThrustersPressed = Bool(bigEndian: from.forwardThrustersPressed)
        reverseThrustersPressed = Bool(bigEndian: from.reverseThrustersPressed)
        shipDecoration = Int(Int32(bigEndian: from.shipDecoration))
        shipWeapon = Int(Int32(bigEndian: from.shipWeapon))
        shipPower = Int(Int32(bigEndian: from.shipPower))
        shieldStrength = Int(Int32(bigEndian: from.shieldStrength))
        playerName = String(cString: from.playerName_ptr)
        thrusterLevel = Float(bigEndian: from.thrusterLevel)
        turnSpeed = Float(bigEndian: from.turnSpeed)
    }
}

extension ClientSpaceWarUpdateData_t {
    init(from: ClientSpaceWarUpdateData) {
        self.init()
        firePressed = from.firePressed.bigEndian
        turnLeftPressed = from.turnLeftPressed.bigEndian
        turnRightPressed = from.turnRightPressed.bigEndian
        forwardThrustersPressed = from.forwardThrustersPressed.bigEndian
        reverseThrustersPressed = from.reverseThrustersPressed.bigEndian
        shipDecoration = Int32(from.shipDecoration.bigEndian)
        shipWeapon = Int32(from.shipWeapon.bigEndian)
        shipPower = Int32(from.shipPower.bigEndian)
        shieldStrength = Int32(from.shieldStrength.bigEndian)
        ClientSpaceWarUpdateData_SetPlayerName(&self, from.playerName)
        thrusterLevel = from.thrusterLevel.bigEndian
        turnSpeed = from.turnSpeed.bigEndian
    }
}

/// Msg from client to server when sending state update
/// Msg from the server to clients when updating the world state
struct MsgClientSendLocalUpdate: SpaceWarMsg {
    typealias CType = MsgClientSendLocalUpdate_t

    let shipPosition: PlayerIndex
    let update: ClientSpaceWarUpdateData

    /// Client - sender - init
    init(shipPosition: PlayerIndex, update: ClientSpaceWarUpdateData) {
        self.shipPosition = shipPosition
        self.update = update
    }

    /// Server - receiver - init
    init(from: MsgClientSendLocalUpdate_t) {
        self.shipPosition = PlayerIndex(UInt32(bigEndian: from.shipPosition))
        self.update = ClientSpaceWarUpdateData(from: from.d)
    }
}

extension MsgClientSendLocalUpdate_t: ConstructableFrom {
    init(from: MsgClientSendLocalUpdate) {
        self.init()
        messageType = Msg.clientSendLocalUpdate.rawValue.bigEndian
        shipPosition = UInt32(from.shipPosition).bigEndian
        d = ClientSpaceWarUpdateData_t(from: from.update)
    }
}
