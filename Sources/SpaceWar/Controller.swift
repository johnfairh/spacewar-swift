//
//  Controller.swift
//  SpaceWar
//

import Steamworks
import struct MetalEngine.Color2D

// The platform-independent part of 'engine' to do with wrangling SteamInput

final class Controller {
    let steam: SteamAPI

    // MARK: Button bindings

    enum DigitalAction: Int {
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

    enum AnalogAction: Int {
        case analogControls = 0
    }

    enum ActionSet: Int {
        case shipControls = 0
        case menuControls = 1
        case layerThrust = 2
    }

    /// An array of handles to Steam Controller events that player can bind to controls
    let digitalActionHandles: [InputDigitalActionHandle]

    /// An array of handles to Steam Controller events that player can bind to controls
    let analogActionHandles: [InputAnalogActionHandle]

    /// An array of handles to different Steam Controller action set configurations
    let actionSetHandles: [InputActionSetHandle]

    /// A handle to the currently active Steam Controller.
    private var activeControllerHandle: InputHandle

    init(steam: SteamAPI) {
        self.steam = steam

        // Cache handles for input vdf strings

        // Digital game actions
        digitalActionHandles = [
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
        analogActionHandles = [
            steam.input.getAnalogActionHandle(actionName: "analog_controls")
        ]

        // Action set + layer handles
        actionSetHandles = [
            steam.input.getActionSetHandle(actionSetName: "ship_controls"),
            steam.input.getActionSetHandle(actionSetName: "menu_controls"),
            steam.input.getActionSetHandle(actionSetName: "thrust_action_layer")
        ]

        activeControllerHandle = .invalid
    }

    // MARK: Lifecycle

    func runFrame() {
        findActiveSteamInputDevice()
    }

    /// Find an active SteamInput controller.
    /// Use the first available steam controller for all interaction. We can call this each frame to handle
    /// a controller disconnecting and a different one reconnecting. Handles are guaranteed to be unique for
    /// a given controller, even across power cycles.
    private func findActiveSteamInputDevice() {
        let active = steam.input.getConnectedControllers()

        // If there's an active controller, and if we're not already using it, select the first one.
        if let controller = active.handles.first {
            let type = steam.input.getInputTypeForHandle(handle: controller)
            if activeControllerHandle == .invalid {
                OutputDebugString("Found SteamInput controller \(type), using")
                activeControllerHandle = controller
            } else if activeControllerHandle != .invalid && activeControllerHandle != controller {
                OutputDebugString("Found different SteamInput controller \(type), switching")
                activeControllerHandle = controller
            }
        } else if activeControllerHandle != .invalid {
            OutputDebugString("Lost SteamInput controller")
            activeControllerHandle = .invalid
        } else if !reportedNoController {
            reportedNoController = true
            OutputDebugString("No SteamInput controller detected")
        }
    }
    private var reportedNoController = false

    /// Return true if there is an active Steam Controller
    var isSteamInputDeviceActive: Bool {
        activeControllerHandle != .invalid
    }

    // MARK: Action queries

    /// Get the current state of a controller action
    func isActionActive(_ action: DigitalAction) -> Bool {
        let data = steam.input.getDigitalActionData(handle: activeControllerHandle,
                                                    actionHandle: digitalActionHandles[action.rawValue])
        // Actions are only 'active' when they're assigned to a control in an action set, and that action set is active.
        return data.active && data.state
    }

    /// Get the current state of a controller analog action
    func getAnalogAction(_ action: AnalogAction) -> SIMD2<Float> {
        let data = steam.input.getAnalogActionData(handle: activeControllerHandle,
                                                   actionHandle: analogActionHandles[action.rawValue])
        // Actions are only 'active' when they're assigned to a control in an action set, and that action set is active.
        guard data.active else {
            return .zero
        }
        return .init(data.x, data.y)
    }

    // MARK: Button names

    // These are human-readable names for each of the origin enumerations. It is preferred to
    // show the supplied icons in-game, but for a simple application these strings can be useful.

    /// For a given in-game action in a given action set, return a human-reaadable string to use as a prompt.
    func getText(set: ActionSet, action: DigitalAction) -> String {
        let origins = steam.input.getDigitalActionOrigins(handle: activeControllerHandle,
                                                          setHandle: actionSetHandles[set.rawValue],
                                                          actionHandle: digitalActionHandles[action.rawValue])
        // We should handle the case where this action is bound to multiple buttons, but
        // here we just grab the first.
        return steam.input.getStringForActionOrigin(origin: origins.origins.first ?? .none)
    }

    /// For a given in-game action in a given action set, return a human-reaadable string to use as a prompt.
    func getText(set: ActionSet, action: AnalogAction) -> String {
        let origins = steam.input.getAnalogActionOrigins(handle: activeControllerHandle,
                                                         setHandle: actionSetHandles[set.rawValue],
                                                         actionHandle: analogActionHandles[action.rawValue])
        // We should handle the case where this action is bound to multiple buttons, but
        // here we just grab the first.
        return steam.input.getStringForActionOrigin(origin: origins.origins.first ?? .none)
    }

    // MARK: Action Sets

    /// Put the controller into a specific action set. Action sets are collections of game-context actions ie "walking", "flying" or "menu"
    func setActionSet(_ set: ActionSet) {
        if activeControllerHandle != .invalid {
            // This call is low-overhead and can be called repeatedly from game code that is active in a specific mode.
            steam.input.activateActionSet(handle: activeControllerHandle, setHandle: actionSetHandles[set.rawValue])
        }
    }

    /// Put the controller into a specific action set layer. Action sets layers apply modifications to an existing action set.
    func activateActionSetLayer(_ layer: ActionSet) {
        if activeControllerHandle != .invalid {
            // This call is low-overhead and can be called repeatedly from game code that is active in a specific mode.
            steam.input.activateActionSetLayer(handle: activeControllerHandle, setLayerHandle: actionSetHandles[layer.rawValue])
        }
    }

    /// Deactivate an existing action set layer
    func deactivateActionSetLayer(_ layer: ActionSet) {
        if activeControllerHandle != .invalid {
            // This call is low-overhead and can be called repeatedly from game code that is active in a specific mode.
            steam.input.deactivateActionSetLayer(handle: activeControllerHandle, setLayerHandle: actionSetHandles[layer.rawValue])
        }
    }

    /// Determine whether an action set layer is currently active
    func isActionSetLayerActive(_ layer: ActionSet) -> Bool {
        guard activeControllerHandle != .invalid else {
            return false
        }

        let activeLayers = steam.input.getActiveActionSetLayers(handle: activeControllerHandle)

        return activeLayers.handles.first(where: { actionSetHandles.contains($0) }) != nil
    }

    // MARK: Effects

    /// Set the LED color on the controller, if supported by controller
    func setColor(_ color: Color2D, flags: SteamControllerLEDFlag) {
        let channels = color.integerChannels
        steam.input.setLEDColor(handle: activeControllerHandle,
                                colorR: UInt8(channels.r),
                                colorG: UInt8(channels.g),
                                colorB: UInt8(channels.b),
                                flags: flags)
    }

    /// Trigger vibration on the controller, if supported by controller
    func triggerVibration(leftSpeed: UInt16, rightSpeed: UInt16) {
        steam.input.triggerVibration(handle: activeControllerHandle, leftSpeed: leftSpeed, rightSpeed: rightSpeed)
    }

    /// Trigger haptics on the controller, if supported by controller
    func triggerHaptics(pad: SteamControllerPad, onMicrosec: UInt16, offMicrosec: UInt16, repeats: UInt16) {
        steam.input.legacyTriggerRepeatedHapticPulse(handle: activeControllerHandle, targetPad: pad, durationMicroSec: onMicrosec, offMicroSec: offMicrosec, repeat: repeats)
    }

    /// Set the trigger effect on DualSense controllers
    func setTriggerEffect(_ enabled: Bool) {
        // XXX DualSense
//      ScePadTriggerEffectParam param;
//
//      memset( &param, 0, sizeof( param ) );
//      param.triggerMask = SCE_PAD_TRIGGER_EFFECT_TRIGGER_MASK_R2;
//
//      // Clear any existing effect
//      param.command[ SCE_PAD_TRIGGER_EFFECT_PARAM_INDEX_FOR_R2 ].mode = SCE_PAD_TRIGGER_EFFECT_MODE_OFF;
//      SteamInput()->SetDualSenseTriggerEffect( m_ActiveControllerHandle, &param );
//
//      if ( bEnabled )
//      {
//        param.command[ SCE_PAD_TRIGGER_EFFECT_PARAM_INDEX_FOR_R2 ].mode = SCE_PAD_TRIGGER_EFFECT_MODE_VIBRATION;
//        param.command[ SCE_PAD_TRIGGER_EFFECT_PARAM_INDEX_FOR_R2 ].commandData.vibrationParam.position = 5;
//        param.command[ SCE_PAD_TRIGGER_EFFECT_PARAM_INDEX_FOR_R2 ].commandData.vibrationParam.amplitude = 5;
//        param.command[ SCE_PAD_TRIGGER_EFFECT_PARAM_INDEX_FOR_R2 ].commandData.vibrationParam.frequency = 8;
//        SteamInput()->SetDualSenseTriggerEffect( m_ActiveControllerHandle, &param );
//      }
    }
}
