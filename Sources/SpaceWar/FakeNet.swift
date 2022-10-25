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
    let body: UnsafeMutableRawPointer
    let size: Int
    func release() {
        body.deallocate()
    }

    init<S>(from: S) {
        body = .allocate(byteCount: MemoryLayout<S>.size, alignment: MemoryLayout<S>.alignment)
        let bound = body.bindMemory(to: S.self, capacity: 1)
        bound.initialize(to: from)
        size = MemoryLayout<S>.size
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
