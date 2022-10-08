//
//  Overlay.swift
//  SpaceWar
//

// MARK: C++ Overlay

//struct OverlayExample_t
//{
//    enum EOverlayExampleItem
//    {
//        k_EOverlayExampleItem_BackToMenu,
//        k_EOverlayExampleItem_Invalid,
//        k_EOverlayExampleItem_ActivateGameOverlay,
//        k_EOverlayExampleItem_ActivateGameOverlayToUser,
//        k_EOverlayExampleItem_ActivateGameOverlayToWebPage,
//        k_EOverlayExampleItem_ActivateGameOverlayToStore,
//        // k_EOverlayExampleItem_ActivateGameOverlayRemotePlayTogetherInviteDialog,
//        k_EOverlayExampleItem_ActivateGameOverlayInviteDialogConnectString
//    };
//
//    EOverlayExampleItem m_eItem;
//    const char *m_pchExtraCommandData;
//};

//    // keep track of if we opened the overlay for a gamewebcallback
//    bool m_bSentWebOpen;

//    STEAM_CALLBACK( CSpaceWarClient, OnGameOverlayActivated, GameOverlayActivated_t );

//
//    // callback when getting the results of a web call
//    STEAM_CALLBACK( CSpaceWarClient, OnGameWebCallback, GameWebCallback_t );
//

////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions when viewing Overlay Examples
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( OverlayExample_t selection )
//{
//    m_pOverlayExamples->OnMenuSelection( selection );
//}

////-----------------------------------------------------------------------------
//// Purpose: Handles notification that the Steam overlay is shown/hidden, note, this
//// doesn't mean the overlay will or will not draw, it may still draw when not active.
//// This does mean the time when the overlay takes over input focus from the game.
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnGameOverlayActivated( GameOverlayActivated_t *callback )
//{
//    if ( callback->m_bActive )
//        OutputDebugString( "Steam overlay now active\n" );
//    else
//        OutputDebugString( "Steam overlay now inactive\n" );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Handle the callback from the user clicking a steam://gamewebcallback/ link in the overlay browser
////    You can use this to add support for external site signups where you want to pop back into the browser
////  after some web page signup sequence, and optionally get back some detail about that.
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnGameWebCallback( GameWebCallback_t *callback )
//{
//    m_bSentWebOpen = false;
//    char rgchString[256];
//    sprintf_safe( rgchString, "User submitted following url: %s\n", callback->m_szURL );
//    OutputDebugString( rgchString );
//}

