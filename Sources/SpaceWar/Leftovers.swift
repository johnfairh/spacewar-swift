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

//    m_hInGameStoreFont = pGameEngine->HCreateFont( INSTRUCTIONS_FONT_HEIGHT, FW_BOLD, false, "Courier New" );
//    if ( !m_hInGameStoreFont )
//        OutputDebugString( "in-game store font was not created properly, text won't draw\n" );
//
