//
//  Leftovers.swift
//  SpaceWar
//

// MARK: C++ Music Player

//    void OnMenuSelection( MusicPlayerMenuItem_t selection ) { m_pMusicPlayer->OnMenuSelection( selection ); }

// MARK: C++ Achievements

//    // Scale screen size to "real" size
//    float PixelsToFeet( float flPixels );

//
////-----------------------------------------------------------------------------
//// Purpose: Scale pixel sizes to "real" sizes
////-----------------------------------------------------------------------------
//float CSpaceWarClient::PixelsToFeet( float flPixels )
//{
//    // This game is actual size! (at 72dpi) LOL
//    // Those are very tiny ships, and an itty bitty neutron star
//
//    float flReturn = ( flPixels / 72 ) / 12;
//
//    return flReturn;
//}


// MARK: C++ Rich Presence

//    // Updates what we show to friends about what we're doing and how to connect
//    void UpdateRichPresenceConnectionInfo();
//
//    // Set appropriate rich presence keys for a player who is currently in-game and
//    // return the value that should go in steam_display
//    const char *SetInGameRichPresence() const;

////-----------------------------------------------------------------------------
//// Purpose: For a player in game, set the appropriate rich presence keys for display
//// in the Steam friends list and return the value for steam_display
////-----------------------------------------------------------------------------
//const char *CSpaceWarClient::SetInGameRichPresence() const
//{
//    const char *pchStatus;
//
//    bool bWinning = false;
//    uint32 cWinners = 0;
//    uint32 uHighScore = m_rguPlayerScores[0];
//    uint32 uMyScore = 0;
//    for ( uint32 i = 0; i < MAX_PLAYERS_PER_SERVER; ++i )
//    {
//        if ( m_rguPlayerScores[i] > uHighScore )
//        {
//            uHighScore = m_rguPlayerScores[i];
//            cWinners = 0;
//            bWinning = false;
//        }
//
//        if ( m_rguPlayerScores[i] == uHighScore )
//        {
//            cWinners++;
//            bWinning = bWinning || (m_rgSteamIDPlayers[i] == m_SteamIDLocalUser);
//        }
//
//        if ( m_rgSteamIDPlayers[i] == m_SteamIDLocalUser )
//        {
//            uMyScore = m_rguPlayerScores[i];
//        }
//    }
//
//    if ( bWinning && cWinners > 1 )
//    {
//        pchStatus = "Tied";
//    }
//    else if ( bWinning )
//    {
//        pchStatus = "Winning";
//    }
//    else
//    {
//        pchStatus = "Losing";
//    }
//
//    char rgchBuffer[32];
//    sprintf_safe( rgchBuffer, "%2u", uMyScore );
//    SteamFriends()->SetRichPresence( "score", rgchBuffer );
//
//    return pchStatus;
//}

////-----------------------------------------------------------------------------
//// Purpose: Updates what we show to friends about what we're doing and how to connect
////-----------------------------------------------------------------------------
//void CSpaceWarClient::UpdateRichPresenceConnectionInfo()
//{
//    // connect string that will come back to us on the command line    when a friend tries to join our game
//    char rgchConnectString[128];
//    rgchConnectString[0] = 0;
//
//    if ( m_eConnectedStatus == k_EClientConnectedAndAuthenticated && m_unServerIP && m_usServerPort )
//    {
//        // game server connection method
//        sprintf_safe( rgchConnectString, "+connect %d:%d", m_unServerIP, m_usServerPort );
//    }
//    else if ( m_steamIDLobby.IsValid() )
//    {
//        // lobby connection method
//        sprintf_safe( rgchConnectString, "+connect_lobby %llu", m_steamIDLobby.ConvertToUint64() );
//    }
//
//    SteamFriends()->SetRichPresence( "connect", rgchConnectString );
//}

// MARK: C++ Leaderboard

//// a leaderboard item
//struct LeaderboardMenuItem_t
//{
//    bool m_bBack;
//    bool m_bNextLeaderboard;
//};

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing a leaderboard
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( LeaderboardMenuItem_t selection )
//{
//    m_pLeaderboards->OnMenuSelection( selection );
//}

// MARK: C++ Friends

//// a friends list item
//struct FriendsListMenuItem_t
//{
//    CSteamID m_steamIDFriend;
//};

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing a leaderboard
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( FriendsListMenuItem_t selection )
//{
//    m_pFriendsList->OnMenuSelection( selection );
//}


// MARK: C++ Remote Play (wossat)

//// a Remote Play session list item
//struct RemotePlayListMenuItem_t
//{
//    uint32 m_unSessionID;
//};

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing the Remote Play session list
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( RemotePlayListMenuItem_t selection )
//{
//    m_pRemotePlayList->OnMenuSelection( selection );
//}

// MARK: C++ Remote Sync

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing the remote storage sync screen
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( ERemoteStorageSyncMenuCommand selection )
//{
//    m_pRemoteStorage->OnMenuSelection( selection );
//}


// MARK: C++ ItemStore

//struct PurchaseableItem_t
//{
//    SteamItemDef_t m_nItemDefID;
//    uint64 m_ulPrice;
//};

//    // draw the in-game store
//    void DrawInGameStore();

//    // Font handle for drawing the in-game store
//    HGAMEFONT m_hInGameStoreFont;
//

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing the Item Store
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( PurchaseableItem_t selection )
//{
//    m_pItemStore->OnMenuSelection( selection );
//}
//
//

