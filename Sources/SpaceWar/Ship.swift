//
//  Ship.swift
//  SpaceWar
//

import MetalEngine
import simd

final class Ship: SpaceWarEntity {
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
    /// Shield strength
    var shieldStrength: Int

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
    static let MAXIMUM_SHIP_THRUST = Float(150)

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

    init(engine: Engine2D, isServerInstance: Bool, pos: SIMD2<Float>, color: Color2D) {

        shipColor = color
        self.isServerInstance = isServerInstance
        shipDecoration = nil
        shieldStrength = 0
        isDisabled = false
        isLocalPlayer = false
        isExploding = false
        debrisList = []

        forwardThrusters = ForwardThrusters(engine: engine)
        reverseThrusters = ReverseThrusters(engine: engine)
        lastThrustStartedTickCount = 0
        areForwardThrustersActive = false
        areReverseThrustersActive = false
        //      m_nFade = 255;
        //      m_ulLastPhotonTickCount = 0;
        //      m_nShipDecoration = 0;
        //      m_nShipPower = 0;
        //      m_nShipWeapon = 0;
        //      m_hTextureWhite = 0;
        explosionTickCount = 0
        isTriggerEffectEnabled = false

        spaceWarClientUpdateData = ClientSpaceWarUpdateData()
        //
        //      for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
        //      {
        //        m_rgPhotonBeams[i] = NULL;
        //      }
        clientUpdateTick = Debounced(debounce: 1000 / Misc.CLIENT_UPDATE_SEND_RATE) { true }
        super.init(engine: engine, collisionRadius: 11, affectedByGravity: false/* true*/)

        buildGeometry()

        self.pos = pos

        // Set Controller color to ship color
        // XXX SteamInput m_pGameEngine->SetControllerColor( m_dwShipColor >> 16 & 255, m_dwShipColor >> 8 & 255, m_dwShipColor & 255, k_ESteamControllerLEDFlag_SetColor );
    }

    deinit {
        // Restore Controller Color
        // XXX SteamInput m_pGameEngine->SetControllerColor( 0, 0, 0, k_ESteamControllerLEDFlag_RestoreUserDefault );

        // Turn off trigger effect
        if isTriggerEffectEnabled {
            // XXX SteamInput m_pGameEngine->SetTriggerEffect(false)
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

    /// Run a frame for the ship
    override func runFrame() {
        guard !isDisabled else {
            return
        }
    //
    //      const uint64 ulCurrentTickCount = m_pGameEngine->GetGameTickCount();
    //
    //      // Look for expired photon beams
    //      int nNextAvailablePhotonBeamSlot = -1;  // Track next available slot for use spawning new beams below
    //      for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //      {
    //        if ( m_rgPhotonBeams[i] )
    //        {
    //          if ( m_rgPhotonBeams[i]->BIsBeamExpired() )
    //          {
    //            delete m_rgPhotonBeams[i];
    //            m_rgPhotonBeams[i] = NULL;
    //          }
    //        }
    //
    //        if ( !m_rgPhotonBeams[i] && nNextAvailablePhotonBeamSlot == -1 )
    //          nNextAvailablePhotonBeamSlot = i;
    //      }
    //
    //      // run all the photon beams we have outstanding
    //      for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //      {
    //        if ( m_rgPhotonBeams[i] )
    //          m_rgPhotonBeams[i]->RunFrame();
    //      }
    //
        // run all the space debris
        debrisList.forEach { $0.runFrame() }

        // Compute rotationTurn
        if isLocalPlayer {
            // client side
            spaceWarClientUpdateData.turnLeftPressed =
                engine.isKeyDown(vkLeft!) /* XXX SteamInput ||
                engine.isControllerActionActive(eControllerDigitalAction_TurnLeft)*/

            spaceWarClientUpdateData.turnRightPressed =
                engine.isKeyDown(vkRight!) /* XXX SteamInput ||
                engine.isControllerActionActive(eControllerDigitalAction_TurnRight)*/

    //          // The Steam Controller can also map an anlog axis to thrust and steer
    //          float fTurnSpeed, fUnused;
    //          m_pGameEngine->GetControllerAnalogAction( eControllerAnalogAction_AnalogControls, &fTurnSpeed, &fUnused );
    //
    //          if ( fTurnSpeed > 0.0f )
    //          {
    //            m_SpaceWarClientUpdateData.SetTurnRightPressed( true );
    //            m_SpaceWarClientUpdateData.SetTurnSpeed( fTurnSpeed );
    //          }
    //          else if ( fTurnSpeed < 0.0f )
    //          {
    //            m_SpaceWarClientUpdateData.SetTurnLeftPressed( true );
    //            m_SpaceWarClientUpdateData.SetTurnSpeed( fTurnSpeed );
    //          }
        } else if isServerInstance {
            // Server side
            let maxTurnSpeed = (Float.pi / 2) * (Float(engine.frameDelta) / 400.0)

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
                engine.isKeyDown(vkForwardThrusters!) /* XXX SteamInput ||
                m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_ForwardThrust ) */

            spaceWarClientUpdateData.reverseThrustersPressed =
                engine.isKeyDown(vkReverseThrusters!) /* XXX SteamInput ||
                m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_ReverseThrust ) */

            let forwardThrustActive = spaceWarClientUpdateData.forwardThrustersPressed

    //          // The Steam Controller can also map an analog axis to thrust and steer
    //          float fThrusterLevel, fUnused;
    //          m_pGameEngine->GetControllerAnalogAction( eControllerAnalogAction_AnalogControls, &fUnused, &fThrusterLevel );
    //
    //          if ( fThrusterLevel > 0.0f )
    //          {
    //            m_SpaceWarClientUpdateData.SetForwardThrustersPressed( true );
    //            m_SpaceWarClientUpdateData.SetThrustersLevel( fThrusterLevel );
    //            bForwardThrustActive = true;
    //          }
    //          else if ( fThrusterLevel < 0.0f )
    //          {
    //            m_SpaceWarClientUpdateData.SetReverseThrustersPressed( true );
    //            m_SpaceWarClientUpdateData.SetThrustersLevel( fThrusterLevel );
    //          }
    //
    //          // We can activate action set layers based upon our state.
    //          // This allows action bindings or settings to be changed on an existing action set for contextual usage
    //          if ( bForwardThrustActive )
    //          {
    //            m_pGameEngine->ActivateSteamControllerActionSetLayer( eControllerActionSet_Layer_Thrust );
    //          }
    //          else if ( m_pGameEngine->BIsActionSetLayerActive( eControllerActionSet_Layer_Thrust ) )
    //          {
    //            m_pGameEngine->DeactivateSteamControllerActionSetLayer( eControllerActionSet_Layer_Thrust );
    //          }
    //            // Hardcoded keys to choose various outfits and weapon powerups which require inventory. Note that this is not
    //            // a "secure" multiplayer model - clients can lie about what they own. A more robust solution, if your items
    //            // matter enough to bother, would be to use SerializeResult / DeserializeResult to encode the fact that your
    //            // steamid owns certain items, and then send that encoded result to the server which decodes and verifies it.
    //            if ( m_pGameEngine->BIsKeyDown( 0x30 ) )
    //            {
    //              m_nShipDecoration = 0;
    //              BuildGeometry();
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x31 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration1 ) )
    //            {
    //              m_nShipDecoration = 1;
    //              BuildGeometry();
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x32 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration2 ) )
    //            {
    //              m_nShipDecoration = 2;
    //              BuildGeometry();
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x33 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration3 ) )
    //            {
    //              m_nShipDecoration = 3;
    //              BuildGeometry();
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x34 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipDecoration4 ) )
    //            {
    //              m_nShipDecoration = 4;
    //              BuildGeometry();
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x35 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipWeapon1 ) )
    //            {
    //              m_nShipWeapon = 1;
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x36 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipWeapon2 ) )
    //            {
    //              m_nShipWeapon = 2;
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x37 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipSpecial1 ) )
    //            {
    //              m_nShipPower = 1;
    //            }
    //            else if ( m_pGameEngine->BIsKeyDown( 0x38 ) && SpaceWarLocalInventory()->HasInstanceOf( k_SpaceWarItem_ShipSpecial2 ) )
    //            {
    //              m_nShipPower = 2;
    //            }
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

                //            float fThrusterLevel = m_SpaceWarClientUpdateData.GetThrustersLevel();
                //            if ( fThrusterLevel != 0.0f ) {
                //              flSign = fThrusterLevel;
                //            } XXX SteamInput
                if lastThrustStartedTickCount == 0 {
                    lastThrustStartedTickCount = engine.currentTickCount
                    // XXX SteamInput (wtf this is the server, makes no sense...)
                    //              m_pGameEngine->TriggerControllerHaptics( k_ESteamControllerPad_Left, 2900, 1200, 4 );
                }

                // You have to hold the key for a second to reach maximum thrust
                let factor = min(Float(engine.currentTickCount - lastThrustStartedTickCount) / 500.0 + 0.2, 1.0)

                thrust.x = sign * Self.MAXIMUM_SHIP_THRUST * factor * sin(accumulatedRotation)
                thrust.y = sign * -1.0 * Self.MAXIMUM_SHIP_THRUST * factor * cos(accumulatedRotation)
            } else {
                lastThrustStartedTickCount = 0
            }

            acceleration = thrust
        }

    //        // We'll use these values in a few places below to compute positions of child objects
    //        // appropriately given our rotation
    //        float sinvalue = (float)sin( GetAccumulatedRotation() );
    //        float cosvalue = (float)cos( GetAccumulatedRotation() );
    //
    //        if ( m_bIsLocalPlayer )
    //        {
    //          // client side
    //          if ( m_pGameEngine->BIsKeyDown( m_dwVKFire ) ||
    //            m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_FireLasers ) )
    //          {
    //            m_SpaceWarClientUpdateData.SetFirePressed( true );
    //          }
    //        }
    //        else if ( m_bIsServerInstance )
    //        {
    //          // server side
    //          if ( nNextAvailablePhotonBeamSlot != -1 && !m_bExploding && m_SpaceWarClientUpdateData.GetFirePressed() && ulCurrentTickCount - PHOTON_BEAM_FIRE_INTERVAL_TICKS > m_ulLastPhotonTickCount )
    //          {
    //            m_ulLastPhotonTickCount = ulCurrentTickCount;
    //
    //            if ( m_nShipWeapon == 1 ) // Item#101
    //            {
    //              float sinvalue1 = (float)sin( GetAccumulatedRotation() - .1f );
    //              float cosvalue1 = (float)cos( GetAccumulatedRotation() - .1f );
    //              float sinvalue2 = (float)sin( GetAccumulatedRotation() + .1f );
    //              float cosvalue2 = (float)cos( GetAccumulatedRotation() + .1f );
    //
    //              float xVelocity = GetXVelocity() + ( sinvalue1 * 275 );
    //              float yVelocity = GetYVelocity() - ( cosvalue1 * 275 );
    //
    //              // Offset 12 points up from the center of the ship, compensating for rotation
    //              float xPos = GetXPos() - sinvalue1*-12.0f;
    //              float yPos = GetYPos() + cosvalue1*-12.0f;
    //
    //              m_rgPhotonBeams[nNextAvailablePhotonBeamSlot] = new CPhotonBeam( m_pGameEngine, xPos, yPos, m_dwShipColor, GetAccumulatedRotation(), xVelocity, yVelocity );
    //
    //              nNextAvailablePhotonBeamSlot = -1;  // Track next available slot for use spawning new beams below
    //              for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //              {
    //                if ( !m_rgPhotonBeams[i] && nNextAvailablePhotonBeamSlot == -1 )
    //                  nNextAvailablePhotonBeamSlot = i;
    //              }
    //
    //              if ( nNextAvailablePhotonBeamSlot != -1 )
    //              {
    //                xVelocity = GetXVelocity() + ( sinvalue2 * 275 );
    //                yVelocity = GetYVelocity() - ( cosvalue2 * 275 );
    //
    //                // Offset 12 points up from the center of the ship, compensating for rotation
    //                xPos = GetXPos() - sinvalue2*-12.0f;
    //                yPos = GetYPos() + cosvalue2*-12.0f;
    //
    //                m_rgPhotonBeams[nNextAvailablePhotonBeamSlot] = new CPhotonBeam( m_pGameEngine, xPos, yPos, m_dwShipColor, GetAccumulatedRotation(), xVelocity, yVelocity );
    //                m_pGameEngine->TriggerControllerHaptics( k_ESteamControllerPad_Right, 1000, 1500, 2 );
    //              }
    //            }
    //              else
    //              {
    //                float speed = 275;
    //                if ( m_nShipWeapon == 2 ) // Item#102
    //                {
    //                  speed = 500;
    //                }
    //                float xVelocity = GetXVelocity() + ( sinvalue * speed );
    //                float yVelocity = GetYVelocity() - ( cosvalue * speed );
    //
    //                // Offset 12 points up from the center of the ship, compensating for rotation
    //                float xPos = GetXPos() - sinvalue*-12.0f;
    //                float yPos = GetYPos() + cosvalue*-12.0f;
    //
    //                m_rgPhotonBeams[nNextAvailablePhotonBeamSlot] = new CPhotonBeam( m_pGameEngine, xPos, yPos, m_dwShipColor, GetAccumulatedRotation(), xVelocity, yVelocity );
    //                m_pGameEngine->TriggerControllerHaptics( k_ESteamControllerPad_Right, 1200, 2500, 3 );
    //              }
    //            }
    //          }
    //
        super.runFrame()

        // Finally, update the thrusters ( we do this after the base class call as they rely on our data being fully up-to-date)
        forwardThrusters.runFrame(ship: self)
        reverseThrusters.runFrame(ship: self)
    }

    // MARK: Render

    /// Render the ship
    override func render(overrideColor: Color2D? = nil) {
    //      int beamCount = 0;
    //
        guard !isDisabled else {
            return
        }

    //      // render all the photon beams we have outstanding
    //      for ( int i = 0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //      {
    //        if ( m_rgPhotonBeams[i] )
    //        {
    //          m_rgPhotonBeams[i]->Render();
    //          beamCount++;
    //        }
    //      }
    //
    //
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
    //        m_nShipWeapon = pUpdateData->GetWeapon();
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

    //        // Update the photon beams
    //        for ( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //        {
    //            ServerPhotonBeamUpdateData_t *pPhotonUpdate = pUpdateData->AccessPhotonBeamData( i );
    //            if ( pPhotonUpdate->GetActive() )
    //            {
    //                if ( !m_rgPhotonBeams[i] )
    //                {
    //                    m_rgPhotonBeams[i] = new CPhotonBeam( m_pGameEngine,
    //                                                          pPhotonUpdate->GetXPosition(), pPhotonUpdate->GetYPosition(),
    //                                                          m_dwShipColor, pPhotonUpdate->GetRotation(),
    //                                                          pPhotonUpdate->GetXVelocity(), pPhotonUpdate->GetYVelocity() );
    //                }
    //                else
    //                {
    //                    m_rgPhotonBeams[i]->OnReceiveServerUpdate( pPhotonUpdate );
    //                }
    //            }
    //            else
    //            {
    //                if ( m_rgPhotonBeams[i] )
    //                {
    //                    delete m_rgPhotonBeams[i];
    //                    m_rgPhotonBeams[i] = NULL;
    //                }
    //            }
    //        }
    }

    /// Update the server model of the ship with data from a client
    func onReceiveClientUpdate(data: ClientSpaceWarUpdateData) {
        guard isServerInstance else {
            OutputDebugString("Should not be receiving client updates on non-server instances")
            return
        }

        shipDecoration = Decoration(rawValue: data.shipDecoration)
        // XXX     m_nShipPower = pUpdateData->GetPower();
        //      m_nShipWeapon = pUpdateData->GetWeapon();
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
//  XXX          spaceWarClientUpdateData.shipWeapon = shipWeapon
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
//                             weapon: <#T##Int#>,
//                             shipPower: <#T##Int#>,
                             shieldStrength: shieldStrength
//                             photonBeamData: <#T##[ServerPhotonBeamUpdateData]#>,
//                             thrusterLevel: <#T##Float#>,
//                             turnSpeed: <#T##Float#>
        )
        //      pUpdateData->SetDecoration( m_nShipDecoration );
        //      pUpdateData->SetWeapon( m_nShipWeapon );
        //      pUpdateData->SetPower( m_nShipPower );
        //
        //      BuildServerPhotonBeamUpdate( pUpdateData );
    }

    //  // Build update data for photon beams to send to clients
    //  void BuildServerPhotonBeamUpdate( ServerShipUpdateData_t *pUpdateData );
    //    //-----------------------------------------------------------------------------
    //    // Purpose: Build the photon beam update data to send from the server to clients
    //    //-----------------------------------------------------------------------------
    //    void CShip::BuildServerPhotonBeamUpdate( ServerShipUpdateData_t *pUpdateData )
    //    {
    //      for( int i = 0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //      {
    //        ServerPhotonBeamUpdateData_t *pPhotonUpdate = pUpdateData->AccessPhotonBeamData( i );
    //        if ( m_rgPhotonBeams[i] )
    //        {
    //          pPhotonUpdate->SetActive( true );
    //          pPhotonUpdate->SetXPosition( m_rgPhotonBeams[i]->GetXPos()/(float)m_pGameEngine->GetViewportWidth() );
    //          pPhotonUpdate->SetYPosition( m_rgPhotonBeams[i]->GetYPos()/(float)m_pGameEngine->GetViewportHeight() );
    //          pPhotonUpdate->SetXVelocity( m_rgPhotonBeams[i]->GetXVelocity() );
    //          pPhotonUpdate->SetYVelocity( m_rgPhotonBeams[i]->GetYVelocity() );
    //          pPhotonUpdate->SetRotation( m_rgPhotonBeams[i]->GetAccumulatedRotation() );
    //        }
    //        else
    //        {
    //          pPhotonUpdate->SetActive( false );
    //        }
    //      }
    //    }

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
                //  XXX steaminput        m_pGameEngine->TriggerControllerVibration( 0, 0 );
                explosionTickCount = 0
            } else {
                // XXX steaminput
                //          m_pGameEngine->TriggerControllerVibration( (unsigned short)( ( 1.0f - flVibration ) * 48000.0f), (unsigned short)( ( 1.0f - flVibration ) * 24000.0f) );
            }
        }

        let triggerEffectEnabled = !isDisabled && !isExploding
        if triggerEffectEnabled != isTriggerEffectEnabled {
            // XXX SteamInput engine.SetTriggerEffect(triggerEffectEnabled)
            isTriggerEffectEnabled = triggerEffectEnabled
        }
    }

    // MARK: Photon Beams

    /// Check for photons which have hit the entity and destroy the photons
    func destroyPhotons(collidingWith target: VectorEntity) {
    //      for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
    //      {
    //        if ( !m_rgPhotonBeams[i] )
    //          continue;
    //
    //        if ( m_rgPhotonBeams[i]->BCollidesWith( pTarget ) )
    //        {
    //          // Photon beam hit the entity, destroy beam
    //          delete m_rgPhotonBeams[i];
    //          m_rgPhotonBeams[i] = NULL;
    //        }
    //      }
        }

    /// Check whether any of the photons this ship has fired are colliding with the target
    func checkForPhotons(collidingWith target: VectorEntity) -> Bool {
        //    {
        //      for( int i=0; i < MAX_PHOTON_BEAMS_PER_SHIP; ++i )
        //      {
        //        if ( !m_rgPhotonBeams[i] )
        //          continue;
        //
        //        if ( m_rgPhotonBeams[i]->BCollidesWith( pTarget ) )
        //        {
        //          return true;
        //        }
        //      }
        //
        //      return false;
        //    }
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
    //
    //private:
    //
    //  // Last time we fired a photon
    //  uint64 m_ulLastPhotonTickCount;
    //
    //  // cloak fade out
    //  int m_nFade;
    //
    //  // vector of beams we have fired (in order of firing time)
    //  CPhotonBeam * m_rgPhotonBeams[MAX_PHOTON_BEAMS_PER_SHIP];
    //

    //  // Weapon for this ship
    //  int m_nShipWeapon;
    //
    //  // Power for this ship
    //  int m_nShipPower;
    //
    //    HGAMETEXTURE m_hTextureWhite;
    //
    //    // Thrust and rotation speed can be anlog when using a Steam Controller
    //    float m_fThrusterLevel;
    //    float m_fTurnSpeed;
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

extension Int {
    static func random() -> Int {
        Int.random(in: 0..<Int.max)
    }
}
