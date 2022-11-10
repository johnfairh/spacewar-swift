//
//  Controller.swift
//  SpaceWar
//

import Steamworks

// The platform-independent part of 'engine' to do with wrangling SteamInput

enum ControllerDigitalAction: Int {
    case turnLeft = 0
    case turnRight = 1
    case forwardThrust = 2
    case reverseThrust = 3
    case fireLasers = 4
    case pauseMenu = 5

    case menuUp = 6
    case menuDown = 7
    case menuLeft = 8
    case menuRight = 9
    case menuSelect = 10
    case menuCancel = 11
}

enum ControllerAnalogAction: Int {
    case analogControls = 0
}

enum ControllerActionSet: Int {
    case shipControls = 0
    case menuControls = 1
    case layerThrust = 2
}

final class Controller {
    let steam: SteamAPI

    /// An array of handles to Steam Controller events that player can bind to controls
    let controllerDigitalActionHandles: [InputDigitalActionHandle]

    /// An array of handles to Steam Controller events that player can bind to controls
    let controllerAnalogActionHandles: [InputAnalogActionHandle]

    /// An array of handles to different Steam Controller action set configurations
    let controllerActionSetHandles: [InputActionSetHandle]

    /// A handle to the currently active Steam Controller.
    private var activeControllerHandle: InputHandle?

    init(steam: SteamAPI) {
        self.steam = steam

        // Cache handles for input vdf strings

        // Digital game actions
        controllerDigitalActionHandles = [
            steam.input.getDigitalActionHandle(actionName: "turn_left"),
            steam.input.getDigitalActionHandle(actionName: "turn_right"),
            steam.input.getDigitalActionHandle(actionName: "forward_thrust"),
            steam.input.getDigitalActionHandle(actionName: "backward_thrust"),
            steam.input.getDigitalActionHandle(actionName: "fire_lasers"),
            steam.input.getDigitalActionHandle(actionName: "pause_menu"),
            steam.input.getDigitalActionHandle(actionName: "menu_up"),
            steam.input.getDigitalActionHandle(actionName: "menu_down"),
            steam.input.getDigitalActionHandle(actionName: "menu_left"),
            steam.input.getDigitalActionHandle(actionName: "menu_right"),
            steam.input.getDigitalActionHandle(actionName: "menu_select"),
            steam.input.getDigitalActionHandle(actionName: "menu_cancel")
        ]

        // Analog game actions
        controllerAnalogActionHandles = [
            steam.input.getAnalogActionHandle(actionName: "analog_controls")
        ]

        // Action set + layer handles
        controllerActionSetHandles = [
            steam.input.getActionSetHandle(actionSetName: "ship_controls"),
            steam.input.getActionSetHandle(actionSetName: "menu_controls"),
            steam.input.getActionSetHandle(actionSetName: "thrust_action_layer")
        ]
    }

    func runFrame() {
        findActiveSteamInputDevice()
        steam.input.runFrame()
    }

    /// Find an active SteamInput controller.
    /// Use the first available steam controller for all interaction. We can call this each frame to handle
    /// a controller disconnecting and a different one reconnecting. Handles are guaranteed to be unique for
    /// a given controller, even across power cycles.
    private func findActiveSteamInputDevice() {
        let active = steam.input.getConnectedControllers()

        // If there's an active controller, and if we're not already using it, select the first one.
        if let controller = active.handles.first {
            if activeControllerHandle == nil {
                OutputDebugString("Found SteamInput controller, using")
                activeControllerHandle = controller
            } else if let activeControllerHandle, activeControllerHandle != controller {
                OutputDebugString("Found different SteamInput controller, switching")
                self.activeControllerHandle = controller
            }
        } else if activeControllerHandle != nil {
            OutputDebugString("Lost SteamInput controller")
            activeControllerHandle = nil
        } else if !reportedNoController {
            reportedNoController = true
            OutputDebugString("No SteamInput controller detected")
        }
    }
    private var reportedNoController = false

//    /// Return true if there is an active Steam Controller
//    var isSteamInputDeviceActive: Bool {
//        false
//    }
//
//    // Get the current state of a controller action
//    virtual bool BIsControllerActionActive( ECONTROLLERDIGITALACTION dwAction ) = 0;
//
//
//    // Get the current state of a controller analog action
//    virtual void GetControllerAnalogAction( ECONTROLLERANALOGACTION dwAction, float *x, float *y ) = 0;
//
//    // Set the current Steam Controller Action set
//    virtual void SetSteamControllerActionSet( ECONTROLLERACTIONSET dwActionSet ) = 0;
//
//    // Set an Action Set Layer for Steam Input
//    virtual void ActivateSteamControllerActionSetLayer( ECONTROLLERACTIONSET dwActionSet ) = 0;
//    virtual void DeactivateSteamControllerActionSetLayer( ECONTROLLERACTIONSET dwActionSet ) = 0;
//
//    // Returns whether a given action set layer is active
//    virtual bool BIsActionSetLayerActive( ECONTROLLERACTIONSET dwActionSetLayer ) = 0;
//
//    // These calls return a string describing which controller button the action is currently bound to
//    virtual const char *GetTextStringForControllerOriginDigital( ECONTROLLERACTIONSET dwActionSet, ECONTROLLERDIGITALACTION dwDigitalAction ) = 0;
//    virtual const char *GetTextStringForControllerOriginAnalog( ECONTROLLERACTIONSET dwActionSet, ECONTROLLERANALOGACTION dwDigitalAction ) = 0;
//
//    virtual void SetControllerColor( uint8 nColorR, uint8 nColorG, uint8 nColorB, unsigned int nFlags ) = 0;
//    virtual void SetTriggerEffect( bool bEnabled ) = 0;
//    virtual void TriggerControllerVibration( unsigned short nLeftSpeed, unsigned short nRightSpeed ) = 0;
//    virtual void TriggerControllerHaptics( ESteamControllerPad ePad, unsigned short usOnMicroSec, unsigned short usOffMicroSec, unsigned short usRepeat ) = 0;
}
