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
    let sender: SteamID
    let data: UnsafeMutableRawPointer
    let size: Int

    /// Take a copy of a byte-buffer
    init(sender: SteamID, data: UnsafeRawPointer, size: Int) {
        self.sender = sender
        self.data = .allocate(byteCount: size, alignment: MemoryLayout<UInt64>.alignment)
        self.data.copyMemory(from: data, byteCount: size)
        self.size = size
    }

    func release() {
        data.deallocate()
    }
}

final class FakeMsgQueue<M>: CustomStringConvertible {
    private var queue = Array<M>()
    init() {}

    func send(msg: M) {
        queue.append(msg)
    }

    func recv() -> M? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    var description: String {
        "\(queue.count)"
    }
}

final class FakeMsgEndpoint: CustomStringConvertible {
    var connections = FakeMsgQueue<FakeConnectMsg>()
    var messages = FakeMsgQueue<FakeClientMsg>()

    var description: String {
        "[c:\(connections) m: \(messages)]"
    }
}

class FakeNet {
    private static var endpoints: [SteamID : FakeMsgEndpoint] = [:]

    static var enableReporting = 0

    static func reportHook() {
        if enableReporting > 0 {
            enableReporting -= 1
            report()
        }
    }

    static func report(_ count: Int? = nil) {
        print("FakeEndpoints:")
        endpoints.forEach { kv in
            print(" \(kv.key): \(kv.value)")
        }
        if let count {
            enableReporting = count
        }
    }

    static func allocateEndpoint(for steamID: SteamID) {
        precondition(endpoints[steamID] == nil, "Endpoint already exists for \(steamID)")
        endpoints[steamID] = FakeMsgEndpoint()
    }

    static func freeEndpoint(for steamID: SteamID) {
        endpoints[steamID] = nil
    }

    static func recv(at steamID: SteamID) -> FakeClientMsg? {
        reportHook()
        precondition(endpoints[steamID] != nil, "Can't receive, no endpoint")
        return endpoints[steamID]?.messages.recv()
    }

    static func send(from: SteamID, to: SteamID, data: UnsafeRawPointer, size: Int) {
        reportHook()
        // debug       precondition(endpoints[to] != nil, "FakeSend to endpoint that doesn't exist \(to)")
        endpoints[to]?.messages.send(msg: FakeClientMsg(sender: from, data: data, size: size))
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

/// Trial abstraction over real/fake-net
enum FakeNetToken: Hashable {
    case steamID(SteamID)
    case netConnection(HSteamNetConnection)
}

/// Common protocol to abstract fake_net and real messages on the receive side
protocol SteamMsgProtocol {
    var size: Int { get }
    var data: UnsafeMutableRawPointer { get }
    func release()
    var sender: SteamID { get }
    var token: FakeNetToken { get }
}

extension FakeClientMsg : SteamMsgProtocol {
    var token: FakeNetToken {
        .steamID(sender)
    }
}

extension SteamNetworkingMessage : SteamMsgProtocol {
    var sender: SteamID {
        peerIdentity.steamID
    }

    var token: FakeNetToken {
        .netConnection(conn)
    }
}

/// Versions of send/receive that are `FAKE_NET` aware
extension SteamNetworkingSockets {
    /// `FAKE_NET_USE`-aware send-msg function
    func sendMessageToConnection(conn: HSteamNetConnection?, from: SteamID, to: SteamID, data: UnsafeRawPointer, dataSize: Int, sendFlags: SteamNetworkingSendFlags) -> (rc: Result, messageNumber: Int) {
        if FAKE_NET_USE {
            FakeNet.send(from: from, to: to, data: data, size: dataSize)
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
