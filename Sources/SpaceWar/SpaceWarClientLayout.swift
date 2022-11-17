//
//  SpaceWarClientLayout.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

/// Routines from spacewarclient to do with drawing graphics on screen
final class SpaceWarClientLayout {
    let steam: SteamAPI
    let controller: Controller
    let engine: Engine2D
    private var textures: TextureCache

    /// Fonts
    static let HUD_FONT_HEIGHT: Float = 18
    static let INSTRUCTIONS_FONT_HEIGHT: Float = 24

    let hudFont: Font2D
    let instructionsFont: Font2D

    init(steam: SteamAPI, controller: Controller, engine: Engine2D) {
        self.steam = steam
        self.controller = controller
        self.engine = engine

        textures = TextureCache(steam: steam, engine: engine)

        hudFont = engine.createFont(style: .proportional, weight: .bold, height: Self.HUD_FONT_HEIGHT)

        instructionsFont = engine.createFont(style: .proportional, weight: .bold, height: Self.INSTRUCTIONS_FONT_HEIGHT)
    }

    /// Draws some text indicating a connection attempt is in progress
    func drawConnectionAttemptText(secondsLeft: UInt, connectingToWhat: String) {
        let timeoutString: String
        if secondsLeft < 25 {
            timeoutString = ", timeout in \(secondsLeft)..."
        } else {
            timeoutString = "..."
        }

        engine.drawText("Connecting to \(connectingToWhat)\(timeoutString)",
                        font: instructionsFont,
                        color: .rgb_i(25, 200, 25),
                        x: 0, y: 0, width: engine.viewportSize.x, height: engine.viewportSize.y,
                        align: .center, valign: .center)
    }

    /// Draws some text indicating a connection failure
    func drawConnectionFailureText(_ text: String) {
        engine.drawText(text, font: instructionsFont,
                        color: .rgb_i(25, 200, 25),
                        x: 0, y: 0, width: engine.viewportSize.x, height: engine.viewportSize.y,
                        align: .center, valign: .center)

        let lowerMsg: String

        if controller.isSteamInputDeviceActive {
            let actionOrigin = controller.getText(set: .menuControls, action: .menuCancel)

            if actionOrigin == "None" {
                lowerMsg = "Press ESC to return to the Main Menu. No controller button bound"
            } else {
                lowerMsg = "Press ESC or '\(actionOrigin)' to return the Main Menu"
            }
        } else {
            lowerMsg = "Press ESC to return to the Main Menu"
        }

        engine.drawText(lowerMsg, font: instructionsFont,
                        color: .rgb_i(25, 200, 25),
                        x: 0, y: 0.7 * engine.viewportSize.y,
                        width: engine.viewportSize.x, height: 0.3 * engine.viewportSize.y,
                        align: .center, valign: .top)
    }


    //    // Draw instructions for how to play the game
    //    void DrawInstructions();

    struct HUDInfo {
        let steamID: SteamID
        let isTalking: Bool
        let score: UInt32
    }

    /// Draws some HUD text indicating game status
    func drawHUDText(info: [HUDInfo?]) {
        // Padding from the edge of the screen for hud elements
        let hudPadding = SIMD2<Float>(15, 15)

        let size = engine.viewportSize

        let avatarSize = SIMD2<Float>(64, 64)

        let spaceBetweenAvatarAndScore = Float(6)

        let scoreWidth = (size.x - hudPadding.x * 2) / 4

        for i in 0..<Misc.MAX_PLAYERS_PER_SERVER {
            // Draw nothing in the spot for an inactive player
            guard let info = info[i] else {
                continue
            }

            // We use Steam persona names for our players in-game name.  To get these we
            // just call SteamFriends()->GetFriendPersonaName() this call will work on friends,
            // players on the same game server as us (if using the Steam game server auth API)
            // and on ourself.
            let voiceState = info.isTalking ? " (VoiceChat)" : ""
            let playerName = info.steamID.isValid ?
                steam.friends.getFriendPersonaName(friend: info.steamID) :
                "Unknown Player"

            // We also want to use the Steam Avatar image inside the HUD if it is available.
            let texture = textures.getSteamImageAsTexture(imageIndex: steam.friends.getMediumFriendAvatar(friend: info.steamID))

            func doTexture(x: Float, y: Float) {
                engine.drawTexturedRect(x0: x, y0: y, x1: x + avatarSize.x, y1: y + avatarSize.y, texture: texture!)
            }

            func doLabel(x: Float, y: Float, h: Font2D.Alignment.Horizontal, v: Font2D.Alignment.Vertical) {
                engine.drawText("\(playerName)\nScore: \(info.score)\(voiceState)",
                                font: hudFont, color: Misc.PlayerColors[i],
                                x: x, y: y,
                                width: scoreWidth, height: avatarSize.y,
                                align: h, valign: v)
            }

            switch i {
            case 0:
                var leftPos = hudPadding.x
                if texture != nil {
                    doTexture(x: leftPos, y: hudPadding.y)
                    leftPos += avatarSize.x + spaceBetweenAvatarAndScore
                }
                doLabel(x: leftPos, y: hudPadding.y, h: .left, v: .center)

            case 1:
                var leftPos = size.x - hudPadding.x - scoreWidth
                if texture != nil {
                    doTexture(x: size.x - hudPadding.x - avatarSize.x, y: hudPadding.y)
                    leftPos -= avatarSize.x + spaceBetweenAvatarAndScore
                }
                doLabel(x: leftPos, y: hudPadding.y, h: .right, v: .center)

            case 2:
                let topPos = size.y - hudPadding.y - avatarSize.y
                var leftPos = hudPadding.x
                if texture != nil {
                    doTexture(x: leftPos, y: topPos)
                    leftPos += avatarSize.x + spaceBetweenAvatarAndScore
                }
                doLabel(x: leftPos, y: topPos, h: .left, v: .bottom)

            case 3:
                let topPos = size.y - hudPadding.y - avatarSize.y
                var leftPos = size.x - hudPadding.x - scoreWidth
                if texture != nil {
                    doTexture(x: size.x - hudPadding.x - avatarSize.x, y: topPos)
                    leftPos -= avatarSize.x + spaceBetweenAvatarAndScore
                }
                doLabel(x: leftPos, y: topPos, h: .right, v: .bottom)

            default:
                preconditionFailure("Too many players!")
            }
        }

        // Draw a Steam Input tooltip
        if controller.isSteamInputDeviceActive {
            let fireOrigin = controller.getText(set: .shipControls, action: .fireLasers)
            let hint: String
            if fireOrigin == "None" {
                hint = "No Fire action bound."
            } else {
                hint = "Press '\(fireOrigin)' to Fire"
            }
            engine.drawText(hint, font: hudFont, color: .rgb(1, 1, 1),
                            x: 30, y: engine.viewportSize.y - 30,
                            width: engine.viewportSize.x - 30,
                            height: engine.viewportSize.x * 2 - 30,
                            align: .left, valign: .top)
        }
    }

    ////-----------------------------------------------------------------------------
    //// Purpose: Draws some instructions on how to play the game
    ////-----------------------------------------------------------------------------
    //void CSpaceWarClient::DrawInstructions()
    //{
    //    const int32 width = m_pGameEngine->GetViewportWidth();
    //
    //    RECT rect;
    //    rect.top = 0;
    //    rect.bottom = m_pGameEngine->GetViewportHeight();
    //    rect.left = 0;
    //    rect.right = width;
    //
    //    char rgchBuffer[256];
    //#ifdef _PS3
    //    sprintf_safe( rgchBuffer, "Turn Ship Left: 'Left'\nTurn Ship Right: 'Right'\nForward Thrusters: 'R2'\nReverse Thrusters: 'L2'\nFire Photon Beams: 'Cross'" );
    //#else
    //    sprintf_safe( rgchBuffer, "Turn Ship Left: 'A'\nTurn Ship Right: 'D'\nForward Thrusters: 'W'\nReverse Thrusters: 'S'\nFire Photon Beams: 'Space'" );
    //#endif
    //
    //    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
    //
    //
    //    rect.left = 0;
    //    rect.right = width;
    //    rect.top = LONG(m_pGameEngine->GetViewportHeight() * 0.7);
    //    rect.bottom = m_pGameEngine->GetViewportHeight();
    //
    //    if ( m_pGameEngine->BIsSteamInputDeviceActive() )
    //    {
    //        const char *rgchActionOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_MenuControls, eControllerDigitalAction_MenuCancel );
    //
    //        if ( strcmp( rgchActionOrigin, "None" ) == 0 )
    //        {
    //            sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu. No controller button bound\n Build ID:%d", SteamApps()->GetAppBuildId() );
    //        }
    //        else
    //        {
    //            sprintf_safe( rgchBuffer, "Press ESC or '%s' to return the Main Menu\n Build ID:%d", rgchActionOrigin, SteamApps()->GetAppBuildId() );
    //        }
    //    }
    //    else
    //    {
    //        sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu\n Build ID:%d", SteamApps()->GetAppBuildId() );
    //    }
    //
    //    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_TOP, rgchBuffer );
    //
    //}

    /// Draws some text about who just won (or that there was a draw)
    func drawWinnerDrawOrWaitingText(state: MonitoredState<SpaceWarClient.State>, winner: SteamID) {
        let elapsed = engine.gameTickCount - state.transitionTime
        let secondsToRestart: UInt
        if elapsed > Misc.MILLISECONDS_BETWEEN_ROUNDS {
            secondsToRestart = 0
        } else {
            secondsToRestart = (Misc.MILLISECONDS_BETWEEN_ROUNDS - elapsed) / 1000
        }

        let msg: String

        switch state.state {
        case .waitingForPlayers:
            msg = "Server is waiting for players.\n\nStarting in \(secondsToRestart) seconds..."
        case .draw:
            msg = "The round is a draw!\n\nStarting again in \(secondsToRestart) seconds..."
        case .winner:
            let winnerName = winner.isValid ? steam.friends.getFriendPersonaName(friend: winner) : "Unknown Player"
            msg = "\(winnerName) wins!\n\nStarting again in \(secondsToRestart) seconds..."
        default:
            preconditionFailure("Unexpected game state \(state.state)")
        }

        engine.drawText(msg, font: instructionsFont, color: .rgb_i(25, 200, 25),
                        x: 0, y: 0, width: engine.viewportSize.x, height: engine.viewportSize.y * 0.6,
                        align: .center, valign: .center)

        // Note: GetLastDroppedItem is the result of an async function, this will not render the reward right away.
        // Could wait for it.
        if let item = SpaceWarLocalInventory.instance.lastDroppedItem {
            // (We're not really bothering to localize everything else, this is just an example.)
            engine.drawText("You won a brand new \(item.localizedName)!",
                            font: instructionsFont, color: .rgb_i(25, 200, 25),
                            x: 0, y: 0, width: engine.viewportSize.x, height: engine.viewportSize.y * 0.4,
                            align: .center, valign: .center)
        }
    }
}
