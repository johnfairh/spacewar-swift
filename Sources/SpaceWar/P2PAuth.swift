//
//  P2PAuth.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

/// Just a draft holding the bits that crept into SpaceWarClient, doesn't do anything useful.
final class P2PAuthedGame {
    let steam: SteamAPI
    let tickSource: TickSource
    let connection: SpaceWarClientConnection

    init(steam: SteamAPI, tickSource: TickSource, connection: SpaceWarClientConnection) {
        self.steam = steam
        self.tickSource = tickSource
        self.connection = connection
    }

    /// Check for P2P authentication work.  Return true means OK to keep playing, otherwise the server has been identified as bad.
    func runFrame(server: SpaceWarServer?) -> Bool {
        true
        //    if ( m_pP2PAuthedGame )
        //    {
        //        if ( m_pServer )
        //        {
        //            // Now if we are the owner of the game, lets make sure all of our players are legit.
        //            // if they are not, we tell the server to kick them off
        //            // Start at 1 to skip myself
        //            for ( int i = 1; i < MAX_PLAYERS_PER_SERVER; i++ )
        //            {
        //                if ( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i] && !m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i]->BIsAuthOk() )
        //                {
        //                    m_pServer->KickPlayerOffServer( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i]->m_steamID );
        //                }
        //            }
        //        }
        //        else
        //        {
        //            // If we are not the owner of the game, lets make sure the game owner is legit
        //            // if he is not, we leave the game
        //            if ( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[0] )
        //            {
        //                if ( !m_pP2PAuthedGame->m_rgpP2PAuthPlayer[0]->BIsAuthOk() )
        //                {
        //                    // leave the game
        //                    frameRc = .mainMenu
        //                }
        //            }
        //        }
        //    }
    }

    func onReceive(serverUpdate: Int /* XXX ServerSpaceWarUpdateData*/, isOwner: Bool, gameState: SpaceWarClient.GameState) {
        //    if ( m_pP2PAuthedGame )
        //    {
        //        // has the player list changed?
        //        if ( m_pServer )
        //        {
        //            // if i am the server owner i need to auth everyone who wants to play
        //            // assume i am in slot 0, so start at slot 1
        //            for( uint32 i=1; i < MAX_PLAYERS_PER_SERVER; ++i )
        //            {
        //                CSteamID steamIDNew( pUpdateData->GetPlayerSteamID(i) );
        //                if ( steamIDNew == SteamUser()->GetSteamID() )
        //                {
        //                    OutputDebugString( "Server player slot 0 is not server owner.\n" );
        //                }
        //                else if ( steamIDNew != m_rgSteamIDPlayers[i] )
        //                {
        //                    if ( m_rgSteamIDPlayers[i].IsValid() )
        //                    {
        //                        m_pP2PAuthedGame->PlayerDisconnect( i );
        //                    }
        //                    if ( steamIDNew.IsValid() )
        //                    {
        //                        m_pP2PAuthedGame->RegisterPlayer( i, steamIDNew );
        //                    }
        //                }
        //            }
        //        }
        //        else
        //        {
        //            // i am just a client, i need to auth the game owner ( slot 0 )
        //            CSteamID steamIDNew( pUpdateData->GetPlayerSteamID( 0 ) );
        //            if ( steamIDNew == SteamUser()->GetSteamID() )
        //            {
        //                OutputDebugString( "Server player slot 0 is not server owner.\n" );
        //            }
        //            else if ( steamIDNew != m_rgSteamIDPlayers[0] )
        //            {
        //                if ( m_rgSteamIDPlayers[0].IsValid() )
        //                {
        //                    OutputDebugString( "Server player slot 0 has disconnected - but thats the server owner.\n" );
        //                    m_pP2PAuthedGame->PlayerDisconnect( 0 );
        //                }
        //                if ( steamIDNew.IsValid() )
        //                {
        //                    m_pP2PAuthedGame->StartAuthPlayer( 0, steamIDNew );
        //                }
        //            }
        //        }
        //    }
    }

    func endGame() {
    }
}
