//
//  FakeNet.swift
//  SpaceWar
//

import Steamworks

/// Bringup/whatever network substitute
///
let FAKE_NET_USE = true

enum FakeMsgType {
    case connect
    case client
}

protocol FakeMsg {
    var type: FakeMsgType { get }
}

struct FakeConnectMsg: FakeMsg {
    var type: FakeMsgType { .connect }
    let from: SteamID
}

struct FakeClientMsg: FakeMsg {
    var type: FakeMsgType { .client }
    let data: UnsafeMutableRawPointer
    let size: Int
    func release() {
        data.deallocate()
    }

    init<S>(from: S) {
        data = .allocate(byteCount: MemoryLayout<S>.size, alignment: MemoryLayout<S>.alignment)
        let bound = data.bindMemory(to: S.self, capacity: 1)
        bound.initialize(to: from)
        size = MemoryLayout<S>.size
    }

    /// Take a copy of a byte-buffer
    init(data: UnsafeRawPointer, size: Int) {
        self.data = .allocate(byteCount: size, alignment: MemoryLayout<UInt64>.alignment)
        self.data.copyMemory(from: data, byteCount: size)
        self.size = size
    }
}

final class FakeMsgQueue {
    private var queue = Array<any FakeMsg>()
    init() {}

    func send(msg: any FakeMsg) {
        queue.append(msg)
    }

    func recv() -> (any FakeMsg)? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    func peek() -> (any FakeMsg)? {
        queue.first
    }
}

class FakeNet {
    private static var endpoints: [SteamID : FakeMsgQueue] = [:]

    static func allocateEndpoint(for steamID: SteamID) {
        precondition(endpoints[steamID] == nil)
        endpoints[steamID] = FakeMsgQueue()
    }

    static func freeEndpoint(for steamID: SteamID) {
        precondition(endpoints[steamID] != nil)
        endpoints[steamID] = nil
    }

    static func recv(at steamID: SteamID) -> (any FakeMsg)? {
        endpoints[steamID]?.recv()
    }

    static func peek(at steamID: SteamID) -> (any FakeMsg)? {
        endpoints[steamID]?.peek()
    }

    static func send(to steamID: SteamID, msg: any FakeMsg) {
        endpoints[steamID]?.send(msg: msg)
    }

    private static var listeners: Set<SteamID> = []

    static func acceptConnections(for steamID: SteamID) {
        precondition(endpoints[steamID] != nil)
        listeners.insert(steamID)
    }

    static func connect(to: SteamID, from: SteamID) {
        if listeners.contains(to) {
            send(to: to, msg: FakeConnectMsg(from: from))
        }
    }
}

// MARK: Steam shims

/// Common protocol to abstract fake_net and real messages on the receive side
protocol SteamMsgProtocol {
    var size: Int { get }
    var data: UnsafeMutableRawPointer { get }
    func release()
}

extension FakeClientMsg : SteamMsgProtocol {}
extension SteamNetworkingMessage : SteamMsgProtocol {}

/// Versions of send/receive that are `FAKE_NET` aware
extension SteamNetworkingSockets {
    /// `FAKE_NET_USE`-aware send-msg function
    func sendMessageToConnection(conn: HSteamNetConnection?, steamID: SteamID, data: UnsafeRawPointer, dataSize: Int, sendFlags: SteamNetworkingSendFlags) -> (rc: Result, messageNumber: Int) {
        if FAKE_NET_USE {
            let msg = FakeClientMsg(data: data, size: dataSize)
            FakeNet.send(to: steamID, msg: msg)
            return (.ok, 0)
        } else {
            guard let conn else {
                preconditionFailure("No net connection in !FAKE_NET_USE mode")
            }
            return sendMessageToConnection(conn: conn, data: data, dataSize: dataSize, sendFlags: sendFlags)
        }
    }

    /// `FAKE_NET_USE`-aware recv-msgs function -- stalls though if the next `FAKE_MSG` is a connect, TBD.
    func receiveMessagesOnConnection(conn: HSteamNetConnection?, steamID: SteamID, maxMessages: Int) -> (rc: Int, messages: [SteamMsgProtocol]) {
        if FAKE_NET_USE {
            var msgs = [FakeClientMsg]()
            while msgs.count < maxMessages {
                guard let nextMsg = FakeNet.peek(at: steamID), nextMsg.type == .client else {
                    break
                }
                msgs.append(nextMsg as! FakeClientMsg)
            }
            return (msgs.count, msgs)
        } else {
            guard let conn else {
                preconditionFailure("No net connection in !FAKE_NET_USE mode")
            }
            return receiveMessagesOnConnection(conn: conn, maxMessages: maxMessages)
        }
    }
}
