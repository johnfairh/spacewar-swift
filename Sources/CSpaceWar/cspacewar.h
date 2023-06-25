#ifndef CSPACEWAR_H

extern "C" {

#include <string.h>

typedef short int16;
typedef unsigned short uint16;
typedef int int32;
typedef unsigned int uint32;
typedef long long int64;
typedef unsigned long long uint64;
typedef unsigned char netbool;
typedef unsigned char uint8;
typedef uint32 netfloat; // network rep of single-prec floating-point

#pragma pack( push, 1 )

// MARK: Signalling

/// Msg from the server to the client which is sent right after communications are established
typedef struct {
    uint32 messageType;
    uint64 steamIDServer;
    netbool isVACSecure;
    char serverName[128];
} MsgServerSendInfo_t;

__attribute__((swift_name("getter:MsgServerSendInfo_t.serverName_ptr(self:)")))
static inline const char * _Nonnull MsgServerSendInfo_GetServerName(const MsgServerSendInfo_t * _Nonnull msg) {
    return msg->serverName;
}

__attribute__((swift_name("MsgServerSendInfo_t.setServerName(self:_:")))
static inline void MsgServerSendInfo_SetServerName(MsgServerSendInfo_t * _Nonnull msg, const char * _Nonnull name) {
    strlcpy(msg->serverName, name, sizeof(msg->serverName));
}

/// Msg from the server to the client when refusing a connection
typedef struct {
    uint32 messageType;
} MsgServerFailAuthentication_t;

/// Msg from the server to client when accepting a pending connection
typedef struct {
  uint32 messageType;
  uint32 playerPosition;
} MsgServerPassAuthentication_t;

/// Msg from server to clients when it is exiting
typedef struct {
    uint32 messageType;
} MsgServerExiting_t;

// Msg from client to server when initiating authentication
typedef struct {
    uint32 messageType;
    uint32 tokenLen;
    uint8  token[1024];
    uint64 steamID;
} MsgClientBeginAuthentication_t;

#define ARRAY_GETTER(TYPE,FIELD,FIELDTYPE) \
__attribute__((swift_name("getter:" #TYPE "." #FIELD "_ptr(self:)"))) \
static inline const FIELDTYPE * _Nonnull TYPE ## _Get ## FIELD (const TYPE * _Nonnull t) { \
    return &t->FIELD[0]; \
}

#define ARRAY_MUTABLE_GETTER(TYPE,FIELD,FIELDTYPE) \
__attribute__((swift_name("getter:" #TYPE "." #FIELD "_ptr(self:)"))) \
static inline FIELDTYPE * _Nonnull TYPE ## _Get ## FIELD (const TYPE * _Nonnull t) { \
    return const_cast<FIELDTYPE *>(&t->FIELD[0]); \
}

ARRAY_GETTER(MsgClientBeginAuthentication_t, token, uint8)

static inline void MsgClientBeginAuthentication_SetToken(MsgClientBeginAuthentication_t * _Nonnull msg, const uint8 * _Nonnull token, uint32 tokenLen) {
    memcpy(msg->token, token, tokenLen);
    // can't set len -- endian
}

// MARK: Sub-protocols

typedef struct {
  uint32 messageType;
  uint32 tokenLen;
  uint8  token[1024];
  uint64 steamID;
} MsgP2PSendingTicket_t;

ARRAY_MUTABLE_GETTER(MsgP2PSendingTicket_t, token, uint8)

typedef struct {
    uint32 messageType;
    uint32 dataLength;
    uint64 fromSteamID;
    uint8  data[1024];
} MsgVoiceChatData_t;

ARRAY_MUTABLE_GETTER(MsgVoiceChatData_t, data, uint8)

// MARK: Game, Server -> Client

typedef struct {
    // Does the photon beam exist right now?
    netbool isActive;

    // The current rotation
    netfloat currentRotation;

    // The current velocity
    netfloat xVelocity;
    netfloat yVelocity;

    // The current position
    netfloat xPosition;
    netfloat yPosition;
} ServerPhotonBeamUpdateData_t;

#define MAX_PHOTON_BEAMS_PER_SHIP 7

// This is the data that gets sent per ship in each update, see below for the full update data
typedef struct {
    // The current rotation of the ship
    netfloat currentRotation;

    // The delta in rotation for the last frame (client side interpolation will use this)
    netfloat rotationDeltaLastFrame;

    // The current thrust for the ship
    netfloat xAcceleration;
    netfloat yAcceleration;

    // The current velocity for the ship
    netfloat xVelocity;
    netfloat yVelocity;

    // The current position for the ship
    netfloat xPosition;
    netfloat yPosition;

    // Is the ship exploding?
    netbool exploding;

    // Is the ship disabled?
    netbool disabled;

    // Are the thrusters to be drawn?
    netbool forwardThrustersActive;
    netbool reverseThrustersActive;

    // Decoration for this ship
    int32 shipDecoration;

    // Weapon for this ship
    int32 shipWeapon;

    // Power for this ship
    int32 shipPower;
    int32 shieldStrength;

    // Photon beam positions and data
    ServerPhotonBeamUpdateData_t photonBeamData[MAX_PHOTON_BEAMS_PER_SHIP];

    // Thrust and rotation speed can be anlog when using a Steam Controller
    netfloat thrusterLevel;
    netfloat turnSpeed;
} ServerShipUpdateData_t;

ARRAY_GETTER(ServerShipUpdateData_t, photonBeamData, ServerPhotonBeamUpdateData_t)

/// This is the data that gets sent from the server to each client for each update
#define MAX_PLAYERS_PER_SERVER 4

/// Msg from the server to clients when updating the world state
typedef struct {
  // What state the game is in
  uint32 currentGameState;

  // Who just won the game? -- only valid when m_eCurrentGameState == k_EGameWinner
  uint32 playerWhoWonGame;

  // which player slots are in use
  netbool playersActive[MAX_PLAYERS_PER_SERVER];

  // what are the scores for each player?
  uint32 playerScores[MAX_PLAYERS_PER_SERVER];

  // array of ship data
  ServerShipUpdateData_t shipData[MAX_PLAYERS_PER_SERVER];

  // array of players steamids for each slot, serialized to uint64
  uint64 playerSteamIDs[MAX_PLAYERS_PER_SERVER];
} ServerSpaceWarUpdateData_t;

ARRAY_GETTER(ServerSpaceWarUpdateData_t, playersActive, netbool)
ARRAY_GETTER(ServerSpaceWarUpdateData_t, playerScores, uint32)
ARRAY_GETTER(ServerSpaceWarUpdateData_t, shipData, ServerShipUpdateData_t)
ARRAY_GETTER(ServerSpaceWarUpdateData_t, playerSteamIDs, uint64)

typedef struct {
    uint32 messageType;
    ServerSpaceWarUpdateData_t d;
} MsgServerUpdateWorld_t;

// MARK: Game, Client -> Server

typedef struct {
    // Key's which are done
    netbool firePressed;
    netbool turnLeftPressed;
    netbool turnRightPressed;
    netbool forwardThrustersPressed;
    netbool reverseThrustersPressed;

    // Decoration for this ship
    int32 shipDecoration;

    // Weapon for this ship
    int32 shipWeapon;

    // Power for this ship
    int32 shipPower;

    int32 shieldStrength;

    // Name of the player (needed server side to tell master server about)
    // bugbug jmccaskey - Really lame to send this every update instead of event driven...
    char playerName[64];

    // Thrust and rotation speed can be anlog when using a Steam Controller
    netfloat thrusterLevel;
    netfloat turnSpeed;
} ClientSpaceWarUpdateData_t;

ARRAY_GETTER(ClientSpaceWarUpdateData_t, playerName, const char)

__attribute__((swift_name("ClientSpaceWarUpdateData_t.setPlayerName(self:_:")))
static inline void ClientSpaceWarUpdateData_SetPlayerName(ClientSpaceWarUpdateData_t * _Nonnull msg, const char * _Nonnull name) {
    strlcpy(msg->playerName, name, sizeof(msg->playerName));
}

typedef struct {
    uint32 messageType;
    uint32 shipPosition;
    ClientSpaceWarUpdateData_t d;
} MsgClientSendLocalUpdate_t;

#pragma pack( pop )

}

#endif
