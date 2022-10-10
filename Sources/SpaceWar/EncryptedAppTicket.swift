//
//  EncryptedAppTicket.swift
//  SpaceWar
//

// MARK: C++ Encrypted App Ticket

extension SpaceWarMain {
    func retrieveEncryptedAppTicket() {
    }
}

//    void RetrieveEncryptedAppTicket();
//    // Called when SteamUser()->RequestEncryptedAppTicket() returns asynchronously
//    void OnRequestEncryptedAppTicket( EncryptedAppTicketResponse_t *pEncryptedAppTicketResponse, bool bIOFailure );
//    CCallResult< CSpaceWarClient, EncryptedAppTicketResponse_t > m_SteamCallResultEncryptedAppTicket;

////-----------------------------------------------------------------------------
//// Purpose: Request an encrypted app ticket
////-----------------------------------------------------------------------------
//uint32 k_unSecretData = 0x5444;
//void CSpaceWarClient::RetrieveEncryptedAppTicket()
//{
//    SteamAPICall_t hSteamAPICall = SteamUser()->RequestEncryptedAppTicket( &k_unSecretData, sizeof( k_unSecretData ) );
//    m_SteamCallResultEncryptedAppTicket.Set( hSteamAPICall, this, &CSpaceWarClient::OnRequestEncryptedAppTicket );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Called when requested app ticket asynchronously completes
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnRequestEncryptedAppTicket( EncryptedAppTicketResponse_t *pEncryptedAppTicketResponse, bool bIOFailure )
//{
//    if ( bIOFailure )
//        return;
//
//    if ( pEncryptedAppTicketResponse->m_eResult == k_EResultOK )
//    {
//        uint8 rgubTicket[1024];
//        uint32 cubTicket;
//        SteamUser()->GetEncryptedAppTicket( rgubTicket, sizeof( rgubTicket), &cubTicket );
//
//
//#ifdef _WIN32
//        // normally at this point you transmit the encrypted ticket to the service that knows the decryption key
//        // this code is just to demonstrate the ticket cracking library
//
//        // included is the "secret" key for spacewar. normally this is secret
//        const uint8 rgubKey[k_nSteamEncryptedAppTicketSymmetricKeyLen] = { 0xed, 0x93, 0x86, 0x07, 0x36, 0x47, 0xce, 0xa5, 0x8b, 0x77, 0x21, 0x49, 0x0d, 0x59, 0xed, 0x44, 0x57, 0x23, 0xf0, 0xf6, 0x6e, 0x74, 0x14, 0xe1, 0x53, 0x3b, 0xa3, 0x3c, 0xd8, 0x03, 0xbd, 0xbd };
//
//        uint8 rgubDecrypted[1024];
//        uint32 cubDecrypted = sizeof( rgubDecrypted );
//        if ( !SteamEncryptedAppTicket_BDecryptTicket( rgubTicket, cubTicket, rgubDecrypted, &cubDecrypted, rgubKey, sizeof( rgubKey ) ) )
//        {
//            OutputDebugString( "Ticket failed to decrypt\n" );
//            return;
//        }
//
//        if ( !SteamEncryptedAppTicket_BIsTicketForApp( rgubDecrypted, cubDecrypted, SteamUtils()->GetAppID() ) )
//            OutputDebugString( "Ticket for wrong app id\n" );
//
//        CSteamID steamIDFromTicket;
//        SteamEncryptedAppTicket_GetTicketSteamID( rgubDecrypted, cubDecrypted, &steamIDFromTicket );
//        if ( steamIDFromTicket != SteamUser()->GetSteamID() )
//            OutputDebugString( "Ticket for wrong user\n" );
//
//        uint32 cubData;
//        uint32 *punSecretData = (uint32 *)SteamEncryptedAppTicket_GetUserVariableData( rgubDecrypted, cubDecrypted, &cubData );
//        if ( cubData != sizeof( uint32 ) || *punSecretData != k_unSecretData )
//            OutputDebugString( "Failed to retrieve secret data\n" );
//#endif
//    }
//    else if ( pEncryptedAppTicketResponse->m_eResult == k_EResultLimitExceeded )
//    {
//        OutputDebugString( "Calling RequestEncryptedAppTicket more than once per minute returns this error\n" );
//    }
//    else if ( pEncryptedAppTicketResponse->m_eResult == k_EResultDuplicateRequest )
//    {
//        OutputDebugString( "Calling RequestEncryptedAppTicket while there is already a pending request results in this error\n" );
//    }
//    else if ( pEncryptedAppTicketResponse->m_eResult == k_EResultNoConnection )
//    {
//        OutputDebugString( "Calling RequestEncryptedAppTicket while not connected to steam results in this error\n" );
//    }
//}
