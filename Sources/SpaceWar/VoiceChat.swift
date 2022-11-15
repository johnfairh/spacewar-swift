//
//  VoiceChat.swift
//  SpaceWar
//

import Steamworks

// stub

final class VoiceChat {
    let steam: SteamAPI

    init(steam: SteamAPI) {
        self.steam = steam
    }

    func startVoiceChat(connection: SpaceWarClientConnection) {
    }

    func endGame() {
    }

    func runFrame() {
    }

    func handleVoiceChatData(msg: MsgVoiceChatData) {
    }

    func markAllPlayersInactive() {
    }

    func markPlayerAsActive(steamID: SteamID) {
    }
}
