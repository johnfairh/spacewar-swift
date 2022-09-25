import MetalEngine
import Steamworks
import SteamworksHelpers

@main
public struct SpaceWarMain {
    public static func main() {
        guard let steam = SteamAPI() else {
            print("SteamInit failed")
            return
        }
        print("Hello world with steam persona \(steam.friends.getPersonaName())")
    }
}
