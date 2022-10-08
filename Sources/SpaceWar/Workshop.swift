//
//  Workshop.swift
//  SpaceWar
//

// MARK: C++ Workshop

//#define MAX_WORKSHOP_ITEMS 16
//
//// a Steam Workshop item
//class CWorkshopItem : public CVectorEntity
//{
//public:
//
//    CWorkshopItem( IGameEngine *pGameEngine, uint32 uCollisionRadius ) : CVectorEntity( pGameEngine, uCollisionRadius )
//    {
//        memset( &m_ItemDetails, 0, sizeof(m_ItemDetails) );
//    }
//
//    void OnUGCDetailsResult(SteamUGCRequestUGCDetailsResult_t *pCallback, bool bIOFailure)
//    {
//        m_ItemDetails = pCallback->m_details;
//    }
//
//    SteamUGCDetails_t m_ItemDetails; // meta data
//    CCallResult<CWorkshopItem, SteamUGCRequestUGCDetailsResult_t> m_SteamCallResultUGCDetails;
//};

//    // Draw description for all subscribed workshop items
//    void DrawWorkshopItems();
//
//    // load subscribed workshop items
//    void LoadWorkshopItems();

//    // load a workshop item from file
//    bool LoadWorkshopItem( PublishedFileId_t workshopItemID );
//    CWorkshopItem *LoadWorkshopItemFromFile( const char *pszFileName );
//    // Steam Workshop items
//    CWorkshopItem *m_rgpWorkshopItems[ MAX_WORKSHOP_ITEMS ];
//    int m_nNumWorkshopItems; // items in m_rgpWorkshopItems

//    // callback when new Workshop item was installed
//    STEAM_CALLBACK(CSpaceWarClient, OnWorkshopItemInstalled, ItemInstalled_t);

////-----------------------------------------------------------------------------
//// Purpose: parse CWorkshopItem from text file
////-----------------------------------------------------------------------------
//CWorkshopItem *CSpaceWarClient::LoadWorkshopItemFromFile( const char *pszFileName )
//{
//    FILE *file = fopen( pszFileName, "rt");
//    if (!file)
//        return NULL;
//
//    CWorkshopItem *pItem = NULL;
//
//    char szLine[1024];
//
//    if ( fgets(szLine, sizeof(szLine), file) )
//    {
//        float flXPos, flYPos, flXVelocity, flYVelocity;
//        // initialize object
//        if ( sscanf(szLine, "%f %f %f %f", &flXPos, &flYPos, &flXVelocity, &flYVelocity) )
//        {
//            pItem = new CWorkshopItem( m_pGameEngine, 0 );
//
//            pItem->SetPosition( flXPos, flYPos );
//            pItem->SetVelocity( flXVelocity, flYVelocity );
//
//            while (!feof(file))
//            {
//                float xPos0, yPos0, xPos1, yPos1;
//                DWORD dwColor;
//                if ( fgets(szLine, sizeof(szLine), file) &&
//                     sscanf(szLine, "%f %f %f %f %x", &xPos0, &yPos0, &xPos1, &yPos1, &dwColor) >= 5 )
//                {
//                    // Add a line to the entity
//                    pItem->AddLine(xPos0, yPos0, xPos1, yPos1, dwColor);
//                }
//            }
//        }
//    }
//
//    fclose(file);
//
//    return pItem;
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: load a Workshop item by PublishFileID
////-----------------------------------------------------------------------------
//bool CSpaceWarClient::LoadWorkshopItem( PublishedFileId_t workshopItemID )
//{
//    if ( m_nNumWorkshopItems == MAX_WORKSHOP_ITEMS )
//        return false; // too much
//
//    uint32 unItemState = SteamUGC()->GetItemState( workshopItemID );
//
//    if ( !(unItemState & k_EItemStateInstalled) )
//        return false;
//
//    uint32 unTimeStamp = 0;
//    uint64 unSizeOnDisk = 0;
//    char szItemFolder[1024] = { 0 };
//
//    if ( !SteamUGC()->GetItemInstallInfo( workshopItemID, &unSizeOnDisk, szItemFolder, sizeof(szItemFolder), &unTimeStamp ) )
//        return false;
//
//    char szFile[1024];
//    if( unItemState & k_EItemStateLegacyItem )
//    {
//        // szItemFolder just points directly to the item for legacy items that were published with the RemoteStorage API.
//        _snprintf( szFile, sizeof( szFile ), "%s", szItemFolder );
//    }
//    else
//    {
//        _snprintf( szFile, sizeof( szFile ), "%s/workshopitem.txt", szItemFolder );
//    }
//
//    CWorkshopItem *pItem = LoadWorkshopItemFromFile( szFile );
//
//    if ( !pItem )
//        return false;
//
//    pItem->m_ItemDetails.m_nPublishedFileId = workshopItemID;
//    m_rgpWorkshopItems[m_nNumWorkshopItems++] = pItem;
//
//    // get Workshop item details
//    SteamAPICall_t hSteamAPICall = SteamUGC()->RequestUGCDetails( workshopItemID, 60 );
//    pItem->m_SteamCallResultUGCDetails.Set(hSteamAPICall, pItem, &CWorkshopItem::OnUGCDetailsResult);
//
//    return true;
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: load all subscribed workshop items
////-----------------------------------------------------------------------------
//void CSpaceWarClient::LoadWorkshopItems()
//{
//    // reset workshop Items
//    for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
//    {
//        if ( m_rgpWorkshopItems[i] )
//        {
//            delete m_rgpWorkshopItems[i];
//            m_rgpWorkshopItems[i] = NULL;
//        }
//    }
//
//    m_nNumWorkshopItems = 0; // load default test item
//
//    PublishedFileId_t vecSubscribedItems[MAX_WORKSHOP_ITEMS];
//
//    int numSubscribedItems = SteamUGC()->GetSubscribedItems( vecSubscribedItems, MAX_WORKSHOP_ITEMS );
//
//    if ( numSubscribedItems > MAX_WORKSHOP_ITEMS )
//        numSubscribedItems = MAX_WORKSHOP_ITEMS; // crop
//
//    // load all subscribed workshop items
//    for ( int iSubscribedItem=0; iSubscribedItem<numSubscribedItems; iSubscribedItem++ )
//    {
//        PublishedFileId_t workshopItemID = vecSubscribedItems[iSubscribedItem];
//        LoadWorkshopItem( workshopItemID );
//    }
//
//    // load local test item
//    if ( m_nNumWorkshopItems < MAX_WORKSHOP_ITEMS )
//    {
//        CWorkshopItem *pItem = LoadWorkshopItemFromFile("workshop/workshopitem.txt");
//
//        if ( pItem )
//        {
//            strncpy( pItem->m_ItemDetails.m_rgchTitle, "Test Item", k_cchPublishedDocumentTitleMax );
//            strncpy( pItem->m_ItemDetails.m_rgchDescription, "This is a local test item for debugging", k_cchPublishedDocumentDescriptionMax );
//            m_rgpWorkshopItems[m_nNumWorkshopItems++] = pItem;
//        }
//    }
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: new Workshop was installed, load it instantly
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnWorkshopItemInstalled( ItemInstalled_t *pParam )
//{
//    if ( pParam->m_unAppID == SteamUtils()->GetAppID() )
//        LoadWorkshopItem( pParam->m_nPublishedFileId );
//}


////-----------------------------------------------------------------------------
//// Purpose: Draws PublishFileID, title & description for each subscribed Workshop item
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawWorkshopItems()
//{
//    const int32 width = m_pGameEngine->GetViewportWidth();
//
//    RECT rect;
//    rect.top = 0;
//    rect.bottom = 64;
//    rect.left = 0;
//    rect.right = width;
//
//    char rgchBuffer[1024];
//    sprintf_safe(rgchBuffer, "Subscribed Workshop Items");
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB(255, 25, 200, 25), TEXTPOS_CENTER |TEXTPOS_VCENTER, rgchBuffer);
//
//    rect.left = 32;
//    rect.top = 64;
//    rect.bottom = 96;
//
//    for (int iSubscribedItem = 0; iSubscribedItem < MAX_WORKSHOP_ITEMS; iSubscribedItem++)
//    {
//        CWorkshopItem *pItem = m_rgpWorkshopItems[ iSubscribedItem ];
//
//        if ( !pItem )
//            continue;
//
//        rect.top += 32;
//        rect.bottom += 32;
//
//        sprintf_safe( rgchBuffer, "%u. \"%s\" (%llu) : %s", iSubscribedItem+1,
//            pItem->m_ItemDetails.m_rgchTitle, pItem->m_ItemDetails.m_nPublishedFileId, pItem->m_ItemDetails.m_rgchDescription );
//
//        m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB(255, 25, 200, 25), TEXTPOS_LEFT |TEXTPOS_VCENTER, rgchBuffer);
//    }
//
//    rect.left = 0;
//    rect.right = width;
//    rect.top = LONG(m_pGameEngine->GetViewportHeight() * 0.8);
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//
//    if ( m_pGameEngine->BIsSteamInputDeviceActive() )
//    {
//        const char *rgchActionOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_MenuControls, eControllerDigitalAction_MenuCancel );
//
//        if ( strcmp( rgchActionOrigin, "None" ) == 0 )
//        {
//            sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu. No controller button bound" );
//        }
//        else
//        {
//            sprintf_safe( rgchBuffer, "Press ESC or '%s' to return the Main Menu", rgchActionOrigin );
//        }
//    }
//    else
//    {
//        sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu" );
//    }
//    m_pGameEngine->BDrawString(m_hInstructionsFont, rect, D3DCOLOR_ARGB(255, 25, 200, 25), TEXTPOS_CENTER | TEXTPOS_TOP, rgchBuffer);
//}
