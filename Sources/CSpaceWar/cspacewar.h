#ifndef CSPACEWAR_H

#include <string.h>

typedef short int16;
typedef unsigned short uint16;
typedef int int32;
typedef unsigned int uint32;
typedef long long int64;
typedef unsigned long long uint64;
typedef unsigned char bool;
typedef unsigned char uint8;

#pragma pack( push, 1 )

// Msg from the server to the client which is sent right after communications are established
typedef struct {
    uint32 messageType;
    uint64 steamIDServer;
    bool isVACSecure;
    char serverName[128];
} MsgServerSendInfo_t;

__attribute__((swift_name("getter:MsgServerSendInfo_t.serverName_ptr(self:)")))
static inline const char * _Nonnull MsgServerSendInfo_GetServerName(const MsgServerSendInfo_t * _Nonnull msg) {
    return msg->serverName;
}

static inline void MsgServerSendInfo_SetServerName(MsgServerSendInfo_t * _Nonnull msg, const char * _Nonnull name) {
    strlcpy(msg->serverName, name, sizeof(msg->serverName));
}

// Msg from client to server when initiating authentication
typedef struct {
    uint32 messageType;
    uint32 tokenLen;
    uint8  token[1024];
    uint64 steamID;
} MsgClientBeginAuthentication_t;

__attribute__((swift_name("getter:MsgClientBeginAuthentication_t.token_ptr(self:)")))
static inline uint8 * _Nonnull MsgClientBeginAuthentication_GetToken(const MsgClientBeginAuthentication_t * _Nonnull msg) {
    return msg->token;
}

static inline void MsgClientBeginAuthentication_SetToken(MsgClientBeginAuthentication_t * _Nonnull msg, const uint8 * _Nonnull token, uint32 tokenLen) {
    memcpy(msg->token, token, tokenLen);
    // can't set len -- endian
}

#pragma pack( pop )

#endif
