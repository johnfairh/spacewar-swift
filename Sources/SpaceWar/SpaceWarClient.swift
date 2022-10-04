//
//  SpaceWar.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

/// Top-level game control type containing steam client and everything else, corresponds
/// to SpaceWarClient and bits of Main.
///
/// SpaceWarApp holds the only reference to this and clears it when told to quit.
final class SpaceWarClient {
    let steam: SteamAPI
    let engine: Engine2D

    let starField: StarField

    init(engine: Engine2D) {
        self.engine = engine

        // Init Steam CEG
        /* XXX this needs integrating into `SteamApi` for proper sequencing; tricky because doesn't exist... */
        if !Steamworks_InitCEGLibrary() {
            Misc.Alert("Fatal Error", "Steam must be running to play this game (InitDrmLibrary() failed).");
            preconditionFailure("Steamworks_InitCEGLibrary() failed");
        }

        guard let steam = SteamAPI(appID: .spaceWar, fakeAppIdTxtFile: true) else {
            Misc.Alert("Fatal Error", "Steam must be running to play this game (SteamAPI_Init() failed).");
            preconditionFailure("SteamInit failed")
        }
        self.steam = steam

        // Debug handlers
        steam.useLoggerForSteamworksWarnings()
        steam.networkingUtils.useLoggerForDebug(detailLevel: .everything)
        SteamAPI.logger.logLevel = .debug

        // Ensure that the user has logged into Steam. This will always return true if the game is launched
        // from Steam, but if Steam is at the login prompt when you run your game from the debugger, it
        // will return false.
        if !steam.user.loggedOn() {
            Misc.Alert("Fatal Error", "Steam user must be logged in to play this game (SteamUser()->BLoggedOn() returned false).");
            preconditionFailure("Steam user is not logged in")
        }

        // If there are no params on the process command line then check in the Steam URL.
        let cmdLineParams = CmdLineParams() ??
            CmdLineParams(launchString: steam.apps.getLaunchCommandLine(commandLineSize: 1024).commandLine) /* XXX should default this */

        // do a DRM self check
        Steamworks_SelfCheck();

        // Steam Input
        if !steam.input.initialize(explicitlyCallRunFrame: false) /* XXX setting? */ {
            Misc.Alert("Fatal Error", "SteamInput()->Init failed.");
            preconditionFailure("SteamInput()->Init failed.");
        }

        /* XXX - sort out resources */
//        char rgchCWD[1024];
//        if ( !_getcwd( rgchCWD, sizeof( rgchCWD ) ) )
//        {
//          strcpy( rgchCWD, "." );
//        }
//
//        char rgchFullPath[1024];
//      #if defined(_WIN32)
//        _snprintf( rgchFullPath, sizeof( rgchFullPath ), "%s\\%s", rgchCWD, "steam_input_manifest.vdf" );
//      #elif defined(OSX)
//        // hack for now, because we do not have utility functions available for finding the resource path
//        // alternatively we could disable the SteamController init on OS X
//        _snprintf( rgchFullPath, sizeof( rgchFullPath ), "%s/steamworksexample.app/Contents/Resources/%s", rgchCWD, "steam_input_manifest.vdf" );
//      #else
//        _snprintf( rgchFullPath, sizeof( rgchFullPath ), "%s/%s", rgchCWD, "steam_input_manifest.vdf" );
//      #endif
//
//        SteamInput()->SetInputActionManifestFilePath( rgchFullPath );


        starField = StarField(engine: engine)

        engine.setBackgroundColor(.rgb(0, 0, 0))
    }

    func runFrame() {
        steam.runCallbacks()
        starField.render()
    }
}
