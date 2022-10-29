//
//  FakeNet.swift
//  SpaceWar
//

import Steamworks

/// Bringup/whatever network substitute
///
let FAKE_NET_USE = true

struct FakeConnectMsg {
    let from: SteamID
    let connectNotDisconnect: Bool
}

struct FakeClientMsg {
    let data: UnsafeMutableRawPointer
    let size: Int

    /// Take a copy of a byte-buffer
    init(data: UnsafeRawPointer, size: Int) {
        self.data = .allocate(byteCount: size, alignment: MemoryLayout<UInt64>.alignment)
        self.data.copyMemory(from: data, byteCount: size)
        self.size = size
    }

    func release() {
        data.deallocate()
    }
}

final class FakeMsgQueue<M> {
    private var queue = Array<M>()
    init() {}

    func send(msg: M) {
        queue.append(msg)
    }

    func recv() -> M? {
        queue.isEmpty ? nil : queue.removeFirst()
    }
}

struct FakeMsgEndpoint {
    var connections = FakeMsgQueue<FakeConnectMsg>()
    var messages = FakeMsgQueue<FakeClientMsg>()
}

class FakeNet {
    private static var endpoints: [SteamID : FakeMsgEndpoint] = [:]

    static func allocateEndpoint(for steamID: SteamID) {
        precondition(endpoints[steamID] == nil, "Endpoint already exists for \(steamID)")
        endpoints[steamID] = FakeMsgEndpoint()
    }

    static func freeEndpoint(for steamID: SteamID) {
        endpoints[steamID] = nil
    }

    static func recv(at steamID: SteamID) -> FakeClientMsg? {
        precondition(endpoints[steamID] != nil, "Can't receive, no endpoint")
        return endpoints[steamID]?.messages.recv()
    }

    static func send(to steamID: SteamID, msg: FakeClientMsg) {
        endpoints[steamID]?.messages.send(msg: msg)
    }

    private static var listeners: Set<SteamID> = []

    static func startListening(at steamID: SteamID) {
        precondition(endpoints[steamID] != nil)
        listeners.insert(steamID)
    }

    static func stopListening(at steamID: SteamID) {
        listeners.remove(steamID)
    }

    static func connect(client: SteamID, server: SteamID) {
        precondition(endpoints[client] != nil, "Can't connect if no way back")
        if listeners.contains(server) {
            endpoints[server]?.connections.send(msg: FakeConnectMsg(from: client, connectNotDisconnect: true))
        } else {
            OutputDebugString("FakeNet connect - attempt to connect to \(server) but not listening?")
        }
    }

    static func disconnect(client: SteamID, server: SteamID) {
        if listeners.contains(server) {
            endpoints[server]?.connections.send(msg: FakeConnectMsg(from: client, connectNotDisconnect: false))
        } else {
            OutputDebugString("FakeNet connect - attempt to disconnect from \(server) but not listening?")
        }
    }

    static func acceptConnection(at steamID: SteamID) -> FakeConnectMsg? {
        precondition(listeners.contains(steamID), "Attempt to accept connection on non-listening endpoint")
        return endpoints[steamID]?.connections.recv()
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

    /// `FAKE_NET_USE`-aware recv-msgs function
    func receiveMessagesOnConnection(conn: HSteamNetConnection?, steamID: SteamID, maxMessages: Int) -> (rc: Int, messages: [SteamMsgProtocol]) {
        if FAKE_NET_USE {
            var msgs = [FakeClientMsg]()
            while msgs.count < maxMessages, let nextMsg = FakeNet.recv(at: steamID) {
                msgs.append(nextMsg)
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
