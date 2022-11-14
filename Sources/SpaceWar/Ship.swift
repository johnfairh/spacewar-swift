//
//  Ship.swift
//  SpaceWar
//

import MetalEngine
import simd

final class Ship: SpaceWarEntity {
    let controller: Controller
    let shipColor: Color2D
    /// Is this ship instance running inside the server (otherwise it's a client...)
    let isServerInstance: Bool

    /// Decorations from inventory - better names very possible...
    enum Decoration: Int {
        case one = 1
        case two = 2
        case three = 3
        case four = 4
    }
    /// Decoration for this ship
    private var shipDecoration: Decoration?
    /// Shield strength XXX API
    var shieldStrength: Int
    /// Ship weapon
    private var shipWeapon: Int32

    /// If server then not local; if !server then can be local OR another client's model
    var isLocalPlayer: Bool

    /// Is the ship part of the game?
    var isDisabled: Bool

    /// Is the ship exploding?
    private(set) var isExploding: Bool
    /// Debris to draw after an explosion
    private var debrisList: [ShipDebris]
    /// When we exploded
    private var explosionTickCount: TickSource.TickCount
    /// Current trigger effect state
    private var isTriggerEffectEnabled: Bool

    /// Forward and reverse thrusters
    let forwardThrusters: ForwardThrusters
    let reverseThrusters: ReverseThrusters
    private var areForwardThrustersActive: Bool
    private var areReverseThrustersActive: Bool
    private var lastThrustStartedTickCount: TickSource.TickCount
    static let MAXIMUM_SHIP_THRUST = Float(30)

    /// Photon beams
    // vector of beams we have fired (in order of firing time)
    private var photonBeams: [PhotonBeam?]
    private var lastPhotonTickCount: TickSource.TickCount

    /// Server update scheduler
    private var clientUpdateTick: Debounced

    /// This will get populated only if we are the local instance, and then
    /// sent to the server in response to each server update
    private var spaceWarClientUpdateData: ClientSpaceWarUpdateData

    /// Get the name for this ship (only really works server side)
    var playerName: String {
        spaceWarClientUpdateData.playerName
    }

    /// Key bindings - set by client...
    var vkLeft: VirtualKey?
    var vkRight: VirtualKey?
    var vkForwardThrusters: VirtualKey?
    var vkReverseThrusters: VirtualKey?
    var vkFire: VirtualKey?

    init(engine: Engine2D, controller: Controller, isServerInstance: Bool, pos: SIMD2<Float>, color: Color2D) {
        self.shipColor = color
        self.isServerInstance = isServerInstance
        self.controller = controller

        shipDecoration = nil
        shieldStrength = 0
        shipWeapon = 0
        isDisabled = false
        isLocalPlayer = false
        isExploding = false
        debrisList = []

        forwardThrusters = ForwardThrusters(engine: engine)
        reverseThrusters = ReverseThrusters(engine: engine)
        lastThrustStartedTickCount = 0
        areForwardThrustersActive = false
        areReverseThrustersActive = false
        photonBeams = .init(repeating: nil, count: Misc.MAX_PHOTON_BEAMS_PER_SHIP)
        lastPhotonTickCount = 0
        //      m_nFade = 255;
        //      m_nShipDecoration = 0;
        //      m_nShipPower = 0;
        //      m_hTextureWhite = 0;
        explosionTickCount = 0
        isTriggerEffectEnabled = false

        spaceWarClientUpdateData = ClientSpaceWarUpdateData()
        clientUpdateTick = Debounced(debounce: 1000 / Misc.CLIENT_UPDATE_SEND_RATE) { true }
        super.init(engine: engine, collisionRadius: 11, affectedByGravity: true)

        buildGeometry()

        self.pos = pos

        // Set Controller color to ship color
        controller.setColor(shipColor, flags: .setColor)
    }

    deinit {
        // Restore Controller Color
        controller.setColor(.rgb(0, 0, 0), flags: .restoreUserDefault)

        // Turn off trigger effect
        if isTriggerEffectEnabled {
            controller.setTriggerEffect(false)
        }
    }

    /// Set the initial rotation for the ship
    func setInitialRotation(_ rotation: Float) {
        accumulatedRotation = rotation
    }

    /// Set geometry according to decoration
    func buildGeometry() {
        clearVertexes()

        // Initialize our geometry
        addLine(xPos0: -9.0, yPos0: 12.0, xPos1: 0.0, yPos1: -12.0, color: shipColor)
        addLine(xPos0: 0.0, yPos0: -12.0, xPos1: 9.0, yPos1: 12.0, color: shipColor)
        addLine(xPos0: 9.0, yPos0: 12.0, xPos1: -9.0, yPos1: 12.0, color: shipColor)

        guard let shipDecoration else {
            return
        }
        switch shipDecoration {
        case .one:
            addLine(xPos0: 0.0, yPos0: -12.0, xPos1: -0.0, yPos1: 12.0, color: shipColor)
            addLine(xPos0: 4.5, yPos0: 0.0, xPos1: -4.5, yPos1: 0.0, color: shipColor)
        case .two:
            addLine(xPos0: 0.0, yPos0: -12.0, xPos1: -0.0, yPos1: 12.0, color: shipColor)
            addLine(xPos0: 4.5, yPos0: 0.0, xPos1: -4.5, yPos1: 0.0, color: shipColor)
            addLine(xPos0: 2.5, yPos0: -6.0, xPos1: -9.0, yPos1: 12.0, color: shipColor)
            addLine(xPos0: 9.0, yPos0: 12.0, xPos1: -2.5, yPos1: -6.0, color: shipColor)
        case .three:
            addLine(xPos0: 0.0, yPos0: -12.0, xPos1: 0.0, yPos1: 12.0, color: shipColor)
            addLine(xPos0: 2.0, yPos0: -8.0, xPos1: 2.0, yPos1: 12.0, color: shipColor)
            addLine(xPos0: -2.0, yPos0: -8.0, xPos1: -2.0, yPos1: 12.0, color: shipColor)
        case .four:
            addLine(xPos0: -12.0, yPos0: 12.0, xPos1: -3.0,yPos1: -12.0, color: shipColor)
            addLine(xPos0: -17.0,  yPos0: 4.0,xPos1: -11.0,yPos1: -10.0, color: shipColor)
            addLine(xPos0: -17.0,  yPos0: 4.0,xPos1: -10.0, yPos1: 7.0, color: shipColor)
            addLine(xPos0: -11.0,yPos0: -10.0, xPos1: -3.0,yPos1: -7.0, color: shipColor)
        }
    }

    // MARK: RunFrame

    /// Next available slot for use spawning new beams
    var nextAvailablePhotonBeamSlot: Array<PhotonBeam?>.Index? {
        photonBeams.firstIndex(where: { $0 == nil })
    }

    /// Run a frame for the ship
    override func runFrame() {
        guard !isDisabled else {
            return
        }

        // Look for expired photon beams
        for i in 0..<photonBeams.count {
            if let beam = photonBeams[i], beam.isBeamExpired {
                photonBeams[i] = nil
            }
        }
//        // Track next available slot for use spawning new beams below
//        let nextAvailablePhotonBeamSlot = photonBeams.firstIndex(where: { $0 == nil })

        // run all the photon beams we have outstanding
        photonBeams.forEach { $0?.runFrame() }

        // run all the space debris
        debrisList.forEach { $0.runFrame() }

        // Compute rotationTurn
        if isLocalPlayer {
            // client side
            spaceWarClientUpdateData.turnLeftPressed =
                engine.isKeyDown(vkLeft!) || controller.isActionActive(.turnLeft)

            spaceWarClientUpdateData.turnRightPressed =
                engine.isKeyDown(vkRight!) || controller.isActionActive(.turnRight)

            // The Steam Controller can also map an anlog axis to thrust and steer
            let turnSpeed = controller.getAnalogAction(.analogControls).x

            if turnSpeed > 0 {
                spaceWarClientUpdateData.turnRightPressed = true
                spaceWarClientUpdateData.turnSpeed = turnSpeed
            } else if turnSpeed < 0 {
                spaceWarClientUpdateData.turnLeftPressed = true
                spaceWarClientUpdateData.turnSpeed = turnSpeed
            }
        } else if isServerInstance {
            // Server side
            let maxTurnSpeed = (Float.pi / 2) * (Float(engine.frameDelta) / 200.0)

            var rotationDelta = Float(0)
            if spaceWarClientUpdateData.turnSpeed != 0 {
                rotationDelta = maxTurnSpeed + spaceWarClientUpdateData.turnSpeed
            } else {
                if spaceWarClientUpdateData.turnLeftPressed {
                    rotationDelta = -1.0 * maxTurnSpeed
                }
                if spaceWarClientUpdateData.turnRightPressed {
                    rotationDelta += maxTurnSpeed
                }
            }
            rotationDeltaNextFrame = rotationDelta
        }

        // Compute acceleration
        if isLocalPlayer {
            // client side
            spaceWarClientUpdateData.forwardThrustersPressed =
                engine.isKeyDown(vkForwardThrusters!) || controller.isActionActive(.forwardThrust)

            spaceWarClientUpdateData.reverseThrustersPressed =
                engine.isKeyDown(vkReverseThrusters!) || controller.isActionActive(.reverseThrust)

            // The Steam Controller can also map an analog axis to thrust and steer
            let thrusterLevel = controller.getAnalogAction(.analogControls).y

            let forwardThrustActive = spaceWarClientUpdateData.forwardThrustersPressed || thrusterLevel > 0

            if thrusterLevel > 0 {
                spaceWarClientUpdateData.forwardThrustersPressed = true
                spaceWarClientUpdateData.thrusterLevel = thrusterLevel
            } else if thrusterLevel < 0 {
                spaceWarClientUpdateData.reverseThrustersPressed = true
                spaceWarClientUpdateData.thrusterLevel = thrusterLevel
            }

            // We can activate action set layers based upon our state.
            // This allows action bindings or settings to be changed on an existing action set for contextual usage
            if forwardThrustActive {
                controller.activateActionSetLayer(.layerThrust)
            } else if controller.isActionSetLayerActive(.layerThrust) {
                controller.deactivateActionSetLayer(.layerThrust)
            }

            handleSpecialKeys()
        } else if isServerInstance {
            // Server side
            var thrust: SIMD2<Float> = [0, 0]
            areReverseThrustersActive = false
            areForwardThrustersActive = false

            if spaceWarClientUpdateData.reverseThrustersPressed || spaceWarClientUpdateData.forwardThrustersPressed {
                var sign = Float(1.0)
                if spaceWarClientUpdateData.reverseThrustersPressed {
                    areReverseThrustersActive = true
                    sign = -1.0
                } else {
                    areForwardThrustersActive = true
                }

                if spaceWarClientUpdateData.thrusterLevel != 0 {
                    sign = spaceWarClientUpdateData.thrusterLevel
                }
                if lastThrustStartedTickCount == 0 {
                    lastThrustStartedTickCount = engine.currentTickCount
                    // XXX (wtf this is the server, makes no sense...)
                    controller.triggerHaptics(pad: .left, onMicrosec: 2900, offMicrosec: 1200, repeats: 4)
                }

                // You have to hold the key for half a second to reach maximum thrust
                let factor = min(Float(engine.currentTickCount - lastThrustStartedTickCount) / 500.0 + 0.2, 1.0)

                thrust.x = sign * Self.MAXIMUM_SHIP_THRUST * factor * sin(accumulatedRotation)
                thrust.y = sign * -1.0 * Self.MAXIMUM_SHIP_THRUST * factor * cos(accumulatedRotation)
            } else {
                lastThrustStartedTickCount = 0
            }

            acceleration = thrust
        }

        // Compute fire
        // We'll use these values in a few places below to compute positions of child objects
        // appropriately given our rotation
        let sinValue = sin(accumulatedRotation)
        let cosValue = cos(accumulatedRotation)

        if isLocalPlayer {
            // client side
            spaceWarClientUpdateData.firePressed =
                engine.isKeyDown(vkFire!) || controller.isActionActive(.fireLasers)
        } else if let nextAvailablePhotonBeamSlot,
                  isServerInstance,
                  !isExploding,
                  spaceWarClientUpdateData.firePressed,
                  engine.gameTickCount.isLongerThan(Misc.PHOTON_BEAM_FIRE_INTERVAL_TICKS, since: lastPhotonTickCount) {

            lastPhotonTickCount = engine.gameTickCount

            if shipWeapon == 1 {
                let sinValue1 = sin(accumulatedRotation - 0.1)
                let cosValue1 = cos(accumulatedRotation - 0.1)
                let sinValue2 = sin(accumulatedRotation + 0.1)
                let cosValue2 = cos(accumulatedRotation + 0.1)

                photonBeams[nextAvailablePhotonBeamSlot] =
                    PhotonBeam(engine: engine,
                               // Offset 12 points up from the center of the ship, compensating for rotation
                               pos: pos + [-sinValue1 * -12.0, cosValue1 * -12.0],
                               beamColor: shipColor,
                               initialRotation: accumulatedRotation,
                               initialVelocity: velocity + [sinValue1 * 275, -cosValue1 * 275])

                if let beam2Slot = self.nextAvailablePhotonBeamSlot {
                    photonBeams[beam2Slot] =
                        PhotonBeam(engine: engine,
                                   pos: self.pos + [-sinValue2 * -12, cosValue2 * 12],
                                   beamColor: shipColor,
                                   initialRotation: accumulatedRotation,
                                   initialVelocity: self.velocity + [sinValue2 * 275, -cosValue2 * 275])
                }
            } else {
                let speed = Float(shipWeapon == 2 ? 500 : 275)
                let beamVelocity = SIMD2(velocity.x + sinValue * speed,
                                         velocity.y - cosValue * speed)

                // Offset 12 points up from the center of the ship, compensating for rotation
                let beamPos = SIMD2(pos.x - sinValue * -12,
                                    pos.y + cosValue * -12)

                photonBeams[nextAvailablePhotonBeamSlot] = PhotonBeam(engine: engine, pos: beamPos, beamColor: shipColor, initialRotation: accumulatedRotation, initialVelocity: beamVelocity)
                // XXX again this is the server...
                controller.triggerHaptics(pad: .right, onMicrosec: 1200, offMicrosec: 2500, repeats: 3)
            }
        }

        super.runFrame()

        // Finally, update the thrusters ( we do this after the base class call as they rely on our data being fully up-to-date)
        forwardThrusters.runFrame(ship: self)
        reverseThrusters.runFrame(ship: self)
    }

    /// Turn on special abilities client-side -- toy inventory demo
    func handleSpecialKeys() {
        // Hardcoded keys to choose various outfits and weapon powerups which require inventory. Note that this is not
        // a "secure" multiplayer model - clients can lie about what they own. A more robust solution, if your items
        // matter enough to bother, would be to use SerializeResult / DeserializeResult to encode the fact that your
        // steamid owns certain items, and then send that encoded result to the server which decodes and verifies it.
        if engine.isKeyDown(.printable("0")) {
            shipDecoration = .none
            buildGeometry()
        } else if engine.isKeyDown(.printable("1")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration1 ) */
            shipDecoration = .one
            buildGeometry()
        } else if engine.isKeyDown(.printable("2")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration2 ) */
            shipDecoration = .two
            buildGeometry()
        } else if engine.isKeyDown(.printable("3")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration3 ) */
            shipDecoration = .three
            buildGeometry()
        } else if engine.isKeyDown(.printable("4")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration4 ) */
            shipDecoration = .four
            buildGeometry()
        } else if engine.isKeyDown(.printable("5")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipWeapon1 ) */
            shipWeapon = 1
        } else if engine.isKeyDown(.printable("6")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipWeapon2 ) */
            shipWeapon = 2
        } else if engine.isKeyDown(.printable("7")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipSpecial1 ) */
            // XXX shipPower = 1
        } else if engine.isKeyDown(.printable("8")) { /* XXX Inventory && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipSpecial2 ) */
            // XXX shipPower = 2
        }
    }

    // MARK: Render

    /// Render the ship
    override func render(overrideColor: Color2D? = nil) {
        guard !isDisabled else {
            return
        }

        // render all the photon beams we have outstanding
        photonBeams.forEach { $0?.render() }

        guard !isExploding else {
            // Don't draw actual ship, instead draw the pieces created in the explosion
            debrisList.forEach { $0.render() }
            return
        }

        // Check if we should be drawing thrusters
        if areForwardThrustersActive {
            if Int.random() % 3 == 0 {
                forwardThrusters.render()
            }
        }

        if areReverseThrustersActive {
            if Int.random() % 3 == 0 {
                reverseThrusters.render()
            }
        }

    //      DWORD actualColor = m_dwShipColor;
    //
    //        if ( m_nShipPower == 1 ) // Item#103 but need to check if the other guy has it sometimes?
    //        {
//        let beamCount = photonBeams.compactMap { $0 }.count
    //          if ( beamCount > 0 )
    //          {
    //            m_nFade = 255;
    //          }
    //          else if ( m_nFade > 0 )
    //          {
    //            m_nFade -= 5;
    //            if ( m_nFade < 0 )
    //              m_nFade = 0;
    //            if ( m_bIsLocalPlayer && m_nFade < 50 )
    //            {
    //              m_nFade = 128;
    //            }
    //          }
    //          actualColor = (actualColor & 0xffffff) | (m_nFade<<24);
    //        }
    //
    //        DWORD shieldColor = 0x00af8f00;
    //
    //        if ( m_nShipPower == 2 )
    //        {
    //          shieldColor = shieldColor | ((m_nShipShieldStrength / 4)<<24);
    //          if ( m_nShipShieldStrength < 256 )
    //            m_nShipShieldStrength++;
    //
    //          if ( !m_hTextureWhite )
    //          {
    //            byte *pRGBAData = new byte[1 * 1 * 4];
    //            memset( pRGBAData, 255, 1 * 1 * 4 );
    //            m_hTextureWhite = m_pGameEngine->HCreateTexture( pRGBAData, 1, 1 );
    //            delete[] pRGBAData;
    //          }
    //
    //          float rotationClockwise = (m_pGameEngine->GetGameTickCount() / 500.0f);
    //          float rotationCounter = -(m_pGameEngine->GetGameTickCount() / 500.0f);
    //
    //          float x1 = 28.0f * (float)cos( rotationClockwise );
    //          float y1 = 28.0f * (float)sin( rotationClockwise );
    //          float x2 = 28.0f * (float)cos( rotationCounter );
    //          float y2 = 28.0f * (float)sin( rotationCounter );
    //
    //          m_pGameEngine->BDrawTexturedQuad(
    //            this->GetXPos() - x1, this->GetYPos() - y1, this->GetXPos() + y1, this->GetYPos() - x1,
    //            this->GetXPos() - y1, this->GetYPos() + x1, this->GetXPos() + x1, this->GetYPos() + y1,
    //            0, 0, 1, 1, shieldColor, m_hTextureWhite );
    //
    //          m_pGameEngine->BDrawTexturedQuad(
    //            this->GetXPos() - x2, this->GetYPos() - y2, this->GetXPos() + y2, this->GetYPos() - x2,
    //            this->GetXPos() - y2, this->GetYPos() + x2, this->GetXPos() + x2, this->GetYPos() + y2,
    //            0, 0, 1, 1, shieldColor, m_hTextureWhite );
    //        }
    //        else
    //        {
    //          m_nShipShieldStrength = 0;
    //        }
    //
        super.render(overrideColor: nil /* actualColor XXX */)
    }

    // MARK: Client/Server data exchange

    /// 1 - SERVER: BuildServerUpdate() --- get most recent server truth and send to clients
    /// 2 - CLIENT: OnReceiveServerUpdate() --- update local state including local physics calcs from server truth
    /// 3 - CLIENT: RunFrame() --- sample user input and store in 'client update', do physics
    /// 4 - CLIENT: GetClientUpdateData() --- transfer 'client update' and current physics to server
    /// 5 - SERVER: OnReceiveClientUpdate() --- store 'client update'
    /// 6 - SERVER: RunFrame() --- use 'client update' to calculate new physics, input, update truth

    /// Update entity with updated data from the server
    func onReceiveServerUpdate(data: ServerShipUpdateData) {
        guard !isServerInstance else {
            OutputDebugString("Should not be receiving server updates on the server itself");
            return
        }

        isDisabled = data.isDisabled
        setExploding(data.isExploding)
        pos = data.position * engine.viewportSize
        velocity = data.velocity
        accumulatedRotation = data.currentRotation

    //        m_nShipPower = pUpdateData->GetPower();
        shipWeapon = data.weapon
    //        if ( m_nShipDecoration != pUpdateData->GetDecoration() )
    //        {
    //            m_nShipDecoration = pUpdateData->GetDecoration();
    //            BuildGeometry();
    //        }
        if !isLocalPlayer || data.shieldStrength == 0 {
            shieldStrength = data.shieldStrength
        }

        areForwardThrustersActive = data.areForwardThrustersActive
        areReverseThrustersActive = data.areReverseThrustersActive

        for i in 0..<Misc.MAX_PHOTON_BEAMS_PER_SHIP {
            let pdata = data.photonBeamData[i]
            if pdata.isActive {
                if let beam = photonBeams[i] {
                    beam.onReceiveServerUpdate(data: pdata)
                } else {
                    photonBeams[i] = PhotonBeam(engine: engine, pos: pdata.position,
                                                beamColor: shipColor,
                                                initialRotation: pdata.currentRotation,
                                                initialVelocity: pdata.velocity)
                }
            } else {
                photonBeams[i] = nil
            }
        }
    }

    /// Update the server model of the ship with data from a client
    func onReceiveClientUpdate(data: ClientSpaceWarUpdateData) {
        guard isServerInstance else {
            OutputDebugString("Should not be receiving client updates on non-server instances")
            return
        }

        shipDecoration = Decoration(rawValue: data.shipDecoration)
        // XXX     m_nShipPower = pUpdateData->GetPower();
        shipWeapon = data.shipWeapon
        shieldStrength = data.shieldStrength

        spaceWarClientUpdateData = data
    }

    /// Get our current client-input state to pass to the server -- return `nil` if no tick due
    func getClientUpdateData() -> ClientSpaceWarUpdateData? {
        // Limit the rate at which we send updates, even if our internal frame rate is higher
        guard clientUpdateTick.test(now: engine.gameTickCount) else {
            return nil
        }

        // Update playername before sending
        if isLocalPlayer {
            spaceWarClientUpdateData.playerName = "Walaspi" // XXX steam.friends.getPersonaName()
            spaceWarClientUpdateData.shipDecoration = shipDecoration?.rawValue ?? 0
            spaceWarClientUpdateData.shipWeapon = shipWeapon
//            spaceWarClientUpdateData.shipPower = shipPower
            spaceWarClientUpdateData.shieldStrength = shieldStrength
        }

        defer { spaceWarClientUpdateData = .init() }
        return spaceWarClientUpdateData
    }

    /// Build the update data to send from server to clients
    func buildServerUpdate() -> ServerShipUpdateData {
        ServerShipUpdateData(currentRotation: accumulatedRotation,
                             rotationDeltaLastFrame: rotationDeltaLastFrame,
                             acceleration: accelerationLastFrame,
                             velocity: velocity,
                             position: .init(pos.x / engine.viewportSize.x,
                                             pos.y / engine.viewportSize.y),
                             isExploding: isExploding,
                             isDisabled: isDisabled,
                             areForwardThrustersActive: areForwardThrustersActive,
                             areReverseThrustersActive: areReverseThrustersActive,
//                             decoration: <#T##Int#>,
                             weapon: shipWeapon,
//                             shipPower: <#T##Int#>,
                             shieldStrength: shieldStrength,
                             photonBeamData: buildServerPhotonBeamUpdate()
        )
        //      pUpdateData->SetDecoration( m_nShipDecoration );
        //      pUpdateData->SetPower( m_nShipPower );
    }

        /// Build the photon beam update data to send from the server to clients
    private func buildServerPhotonBeamUpdate() -> [ServerPhotonBeamUpdateData] {
        photonBeams.map { beam in
            guard let beam else {
                return ServerPhotonBeamUpdateData()
            }
            return ServerPhotonBeamUpdateData(isActive: true,
                                              currentRotation: beam.accumulatedRotation,
                                              velocity: beam.velocity,
                                              position: beam.pos / engine.viewportSize)
        }
    }

    // MARK: Explosion and Debris

    static let SHIP_DEBRIS_PIECES = 6

    /// Set whether the ship is exploding
    func setExploding(_ exploding: Bool) {
        defer { updateVibrationEffects() }

        // If we are already in the specified state, no need to do the below work
        guard exploding != isExploding else {
            return
        }

        Steamworks_TestSecret();

        // Track that we are exploding, and disable collision detection
        isExploding = exploding
        collisionDetectionDisabled = isExploding

        if exploding {
            explosionTickCount = engine.gameTickCount
            for _ in 0..<Self.SHIP_DEBRIS_PIECES {
                debrisList.append(ShipDebris(engine: engine, pos: pos, debrisColor: shipColor))
            }
        } else {
            explosionTickCount = 0
            debrisList = []
        }
    }

    /// Update the vibration effects for the ship
    func updateVibrationEffects() {
        if explosionTickCount > 0 {
            let vibration = min(Float(engine.gameTickCount - explosionTickCount) / 1000.0, 1.0)
            if vibration == 1.0 {
                controller.triggerVibration(leftSpeed: 0, rightSpeed: 0)
                explosionTickCount = 0
            } else {
                controller.triggerVibration(leftSpeed: UInt16((1.0 - vibration) * 48000.0),
                                            rightSpeed: UInt16((1.0 - vibration) * 24000.0))
            }
        }

        let triggerEffectEnabled = !isDisabled && !isExploding
        if triggerEffectEnabled != isTriggerEffectEnabled {
            controller.setTriggerEffect(triggerEffectEnabled)
            isTriggerEffectEnabled = triggerEffectEnabled
        }
    }

    // MARK: Photon Beams

    /// Check for photons which have hit the entity and destroy the photons
    func destroyPhotons(collidingWith target: VectorEntity) {
        for i in 0..<Misc.MAX_PHOTON_BEAMS_PER_SHIP {
            if let beam = photonBeams[i], beam.collides(with: target) {
                // Photon beam hit the entity, destroy beam
                photonBeams[i] = nil
            }
        }
    }

    /// Check whether any of the photons this ship has fired are colliding with the target
    func checkForPhotons(collidingWith target: VectorEntity) -> Bool {
        for i in 0..<Misc.MAX_PHOTON_BEAMS_PER_SHIP {
            if let beam = photonBeams[i], beam.collides(with: target) {
                return true
            }
        }
        return false
    }

    //    // Accumulate stats for this ship
    //    void AccumulateStats( CStatsAndAchievements *pStats );
    //    //-----------------------------------------------------------------------------
    //    // Purpose: Accumulate stats for this ship
    //    //-----------------------------------------------------------------------------
    //    void CShip::AccumulateStats( CStatsAndAchievements *pStats )
    //    {
    //      if ( m_bIsLocalPlayer )
    //      {
    //        pStats->AddDistanceTraveled( GetDistanceTraveledLastFrame() );
    //      }
    //    }
    //
    //  // cloak fade out
    //  int m_nFade;
    //
    //  // Power for this ship
    //  int m_nShipPower;
    //
    //    HGAMETEXTURE m_hTextureWhite;
}

// MARK: Forward Thrusters

/// Simple class for the ship thrusters
final class ForwardThrusters: VectorEntity {
    init(engine: Engine2D) {
        super.init(engine: engine, collisionRadius: 0)

        let color = Color2D.rgb_i(255, 255, 102)

        // Initialize our geometry
        addLine(xPos0: 0.0, yPos0: 12.0, xPos1: 0.0, yPos1: 19.0, color: color)
        addLine(xPos0: 1.0, yPos0: 12.0, xPos1: 6.0, yPos1: 19.0, color: color)
        addLine(xPos0: 4.0, yPos0: 12.0, xPos1: 11.0, yPos1: 19.0, color: color)
        addLine(xPos0: -1.0, yPos0: 12.0, xPos1: -6.0, yPos1: 19.0, color: color)
        addLine(xPos0: -4.0, yPos0: 12.0, xPos1: -11.0, yPos1: 19.0, color: color)
    }

    /// Run Frame, updates us to be in the same position/rotation as the ship we belong to
    func runFrame(ship: Ship) {
        accumulatedRotation = ship.accumulatedRotation
        pos = ship.pos
        runFrame()
    }
}

// MARK: Reverse Thrusters

/// Again, but in reverse
final class ReverseThrusters: VectorEntity {
    init(engine: Engine2D) {
        super.init(engine: engine, collisionRadius: 0)

        let color = Color2D.rgb_i(255, 255, 102)

        // Initialize our geometry
        addLine(xPos0: -8.875, yPos0: 10.5, xPos1: -14.85, yPos1: 10.5, color: color)
        addLine(xPos0: -8.875, yPos0: 10.5, xPos1: -13.765, yPos1: 5.61, color: color)
        addLine(xPos0: -8.875, yPos0: 10.5, xPos1: -7.85, yPos1: 3.5, color: color)

        addLine(xPos0: 8.875, yPos0: 10.5, xPos1: 14.85, yPos1: 10.5, color: color)
        addLine(xPos0: 8.875, yPos0: 10.5, xPos1: 13.765, yPos1: 5.61, color: color)
        addLine(xPos0: 8.875, yPos0: 10.5, xPos1: 7.85, yPos1: 3.5, color: color)
    }

    func runFrame(ship: Ship) {
        accumulatedRotation = ship.accumulatedRotation
        pos = ship.pos
        runFrame()
    }
}

// MARK: Ship Debris

/// Class to represent debris after explosion
final class ShipDebris: SpaceWarEntity {
    /// We keep the debris spinning
    private let rotationPerInterval: Float

    static let LENGTH = Float(16)

    init(engine: Engine2D, pos: SIMD2<Float>, debrisColor: Color2D) {
        // Rotation to apply per second
        rotationPerInterval = Float.random(in: -.pi/2...(.pi/2))

        super.init(engine: engine, collisionRadius: 0, affectedByGravity: true)

        // Geometry
        addLine(xPos0: 0.0, yPos0: 0.0, xPos1: ShipDebris.LENGTH, yPos1: 0.0, color: debrisColor)

        // Random [initial] rotation between 0 and 360 degrees (6.28 radians)
        let rotation = Float.random(in: 0.0...(2 * .pi))
        let rotationMatrix = matrix_float2x2(rotation: rotation)
        rotationDeltaNextFrame = rotation

        // Set velocity
        velocity.x = rotationMatrix.columns.0.y /*sinValue*/ * 80
        velocity.y = rotationMatrix.columns.0.x /*cosValue*/ * 80

        // Offset out a bit from the center of the ship compensating for rotation
        let offset = Float.random(in: -6...6)
        // Set position
        self.pos = pos - rotationMatrix * simd_make_float2(offset, offset)
    }

    /// Run frame for debris (keep it spinning)
    override func runFrame() {
        // JF: Moved these around, was overwriting RDNF set in ctor...
        super.runFrame()
        rotationDeltaNextFrame = rotationPerInterval * (min(Float(engine.frameDelta), 400.0) / 400.0)
    }
}

// MARK: Photon Beam

final class PhotonBeam: SpaceWarEntity {
    private let tickCountToDieAt: TickSource.TickCount

    init(engine: Engine2D, pos: SIMD2<Float>, beamColor: Color2D, initialRotation: Float, initialVelocity: SIMD2<Float>) {
        // Beams only have a lifetime of 1 second
        tickCountToDieAt = engine.gameTickCount + Misc.PHOTON_BEAM_LIFETIME_IN_TICKS

        // Set a really high max velocity for photon beams
        super.init(engine: engine, collisionRadius: 3, affectedByGravity: true, maximumVelocity: 50)

        addLine( xPos0: -2.0, yPos0: -3.0, xPos1: -2.0, yPos1: 3.0, color: beamColor)
        addLine( xPos0: 2.0, yPos0: -3.0, xPos1: 2.0, yPos1: 3.0, color: beamColor)
        self.pos = pos
        self.rotationDeltaNextFrame = initialRotation
        self.velocity = initialVelocity
    }

    var isBeamExpired: Bool {
        engine.gameTickCount > tickCountToDieAt
    }

    /// Update with data from server
    func onReceiveServerUpdate(data: ServerPhotonBeamUpdateData) {
        pos = data.position * engine.viewportSize
        velocity = data.velocity
        accumulatedRotation = data.currentRotation
    }
}

extension Int {
    static func random() -> Int {
        Int.random(in: 0..<Int.max)
    }
}
