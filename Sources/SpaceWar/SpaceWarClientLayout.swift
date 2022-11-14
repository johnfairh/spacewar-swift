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

    /// Fonts
    static let HUD_FONT_HEIGHT: Float = 18
    static let INSTRUCTIONS_FONT_HEIGHT: Float = 24

    let hudFont: Font2D
    let instructionsFont: Font2D

    init(steam: SteamAPI, controller: Controller, engine: Engine2D) {
        self.steam = steam
        self.controller = controller
        self.engine = engine

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


    //    // Draw the HUD text (should do this after drawing all the objects)
    //    void DrawHUDText();
    //
    //    // Draw instructions for how to play the game
    //    void DrawInstructions();

    ////-----------------------------------------------------------------------------
    //// Purpose: Draws some HUD text indicating game status
    ////-----------------------------------------------------------------------------
    //void CSpaceWarClient::DrawHUDText()
    //{
    //    // Padding from the edge of the screen for hud elements
    //#ifdef _PS3
    //    // Larger padding on PS3, since many of our test HDTVs truncate
    //    // edges of the screen and can't be calibrated properly.
    //    const int32 nHudPaddingVertical = 20;
    //    const int32 nHudPaddingHorizontal = 35;
    //#else
    //    const int32 nHudPaddingVertical = 15;
    //    const int32 nHudPaddingHorizontal = 15;
    //#endif
    //
    //
    //    const int32 width = m_pGameEngine->GetViewportWidth();
    //    const int32 height = m_pGameEngine->GetViewportHeight();
    //
    //    const int32 nAvatarWidth = 64;
    //    const int32 nAvatarHeight = 64;
    //
    //    const int32 nSpaceBetweenAvatarAndScore = 6;
    //
    //    LONG scorewidth = LONG((m_pGameEngine->GetViewportWidth() - nHudPaddingHorizontal*2.0f)/4.0f);
    //
    //    char rgchBuffer[256];
    //    for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
    //    {
    //        // Draw nothing in the spot for an inactive player
    //        if ( !m_rgpShips[i] )
    //            continue;
    //
    //
    //        // We use Steam persona names for our players in-game name.  To get these we
    //        // just call SteamFriends()->GetFriendPersonaName() this call will work on friends,
    //        // players on the same game server as us (if using the Steam game server auth API)
    //        // and on ourself.
    //        char rgchPlayerName[128];
    //        CSteamID playerSteamID( m_rgSteamIDPlayers[i] );
    //
    //        const char *pszVoiceState = m_pVoiceChat->IsPlayerTalking( playerSteamID ) ? "(VoiceChat)" : "";
    //
    //        if ( m_rgSteamIDPlayers[i].IsValid() )
    //        {
    //            sprintf_safe( rgchPlayerName, "%s", SteamFriends()->GetFriendPersonaName( playerSteamID ) );
    //        }
    //        else
    //        {
    //            sprintf_safe( rgchPlayerName, "Unknown Player" );
    //        }
    //
    //        // We also want to use the Steam Avatar image inside the HUD if it is available.
    //        // We look it up via GetMediumFriendAvatar, which returns an image index we use
    //        // to look up the actual RGBA data below.
    //        int iImage = SteamFriends()->GetMediumFriendAvatar( playerSteamID );
    //        HGAMETEXTURE hTexture = 0;
    //        if ( iImage != -1 )
    //            hTexture = GetSteamImageAsTexture( iImage );
    //
    //        RECT rect;
    //        switch( i )
    //        {
    //        case 0:
    //            rect.top = nHudPaddingVertical;
    //            rect.bottom = rect.top+nAvatarHeight;
    //            rect.left = nHudPaddingHorizontal;
    //            rect.right = rect.left + scorewidth;
    //
    //            if ( hTexture )
    //            {
    //                m_pGameEngine->BDrawTexturedRect( (float)rect.left, (float)rect.top, (float)rect.left+nAvatarWidth, (float)rect.bottom,
    //                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
    //                rect.left += nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //                rect.right += nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //            }
    //
    //            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
    //            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_LEFT|TEXTPOS_VCENTER, rgchBuffer );
    //            break;
    //        case 1:
    //
    //            rect.top = nHudPaddingVertical;
    //            rect.bottom = rect.top+nAvatarHeight;
    //            rect.left = width-nHudPaddingHorizontal-scorewidth;
    //            rect.right = width-nHudPaddingHorizontal;
    //
    //            if ( hTexture )
    //            {
    //                m_pGameEngine->BDrawTexturedRect( (float)rect.right - nAvatarWidth, (float)rect.top, (float)rect.right, (float)rect.bottom,
    //                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
    //                rect.right -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //                rect.left -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //            }
    //
    //            sprintf_safe( rgchBuffer, "%s\nScore: %2u ", rgchPlayerName, m_rguPlayerScores[i] );
    //            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_RIGHT|TEXTPOS_VCENTER, rgchBuffer );
    //            break;
    //        case 2:
    //            rect.top = height-nHudPaddingVertical-nAvatarHeight;
    //            rect.bottom = rect.top+nAvatarHeight;
    //            rect.left = nHudPaddingHorizontal;
    //            rect.right = rect.left + scorewidth;
    //
    //            if ( hTexture )
    //            {
    //                m_pGameEngine->BDrawTexturedRect( (float)rect.left, (float)rect.top, (float)rect.left+nAvatarWidth, (float)rect.bottom,
    //                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
    //                rect.right += nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //                rect.left += nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //            }
    //
    //            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
    //            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_LEFT|TEXTPOS_BOTTOM, rgchBuffer );
    //            break;
    //        case 3:
    //            rect.top = height-nHudPaddingVertical-nAvatarHeight;
    //            rect.bottom = rect.top+nAvatarHeight;
    //            rect.left = width-nHudPaddingHorizontal-scorewidth;
    //            rect.right = width-nHudPaddingHorizontal;
    //
    //            if ( hTexture )
    //            {
    //                m_pGameEngine->BDrawTexturedRect( (float)rect.right - nAvatarWidth, (float)rect.top, (float)rect.right, (float)rect.bottom,
    //                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
    //                rect.right -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //                rect.left -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
    //            }
    //
    //            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
    //            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_RIGHT|TEXTPOS_BOTTOM, rgchBuffer );
    //            break;
    //        default:
    //            OutputDebugString( "DrawHUDText() needs updating for more players\n" );
    //            break;
    //        }
    //    }
    //
    //    // Draw a Steam Input tooltip
    //    if ( m_pGameEngine->BIsSteamInputDeviceActive( ) )
    //    {
    //        char rgchHint[128];
    //        const char *rgchFireOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_ShipControls, eControllerDigitalAction_FireLasers );
    //
    //        if ( strcmp( rgchFireOrigin, "None" ) == 0 )
    //        {
    //            sprintf_safe( rgchHint, "No Fire action bound." );
    //        }
    //        else
    //        {
    //            sprintf_safe( rgchHint, "Press '%s' to Fire", rgchFireOrigin );
    //        }
    //
    //        RECT rect;
    //        int nBorder = 30;
    //        rect.top = m_pGameEngine->GetViewportHeight( ) - nBorder;
    //        rect.bottom = m_pGameEngine->GetViewportHeight( )*2;
    //        rect.left = nBorder;
    //        rect.right = m_pGameEngine->GetViewportWidth( );
    //        m_pGameEngine->BDrawString( m_hHUDFont, rect, D3DCOLOR_ARGB( 255, 255, 255, 255 ), TEXTPOS_LEFT | TEXTPOS_TOP, rgchHint );
    //    }
    //
    //}
    //
    //
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
        // XXX Inventory
//        if let item = SpaceWarLocalInventory().lastDroppedItem {
//            // (We're not really bothering to localize everything else, this is just an example.)
//            engine.drawText("You won a brand new \(item.localizedName)!",
//                            font: instructionsFont, color: .rgb_i(25, 200, 25),
//                            x: 0, y: 0, width: engine.viewportSize.x, height: engine.viewportSize.y * 0.4,
//                            align: .center, valign: .center)
//        }
    }
}
