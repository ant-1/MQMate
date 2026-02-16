// IBM MQ Stub Headers for Development
// These stubs allow compilation without IBM MQ client installed
// Real MQ client will be used at runtime when available
// Install: brew tap ibm-messaging/ibmmq && brew install --cask ibm-messaging/ibmmq/ibmmq

#ifndef MQ_STUBS_H
#define MQ_STUBS_H

#include <stdint.h>

// MARK: - Basic MQ Types

typedef int32_t MQLONG;
typedef uint8_t MQBYTE;
typedef char MQCHAR;
typedef MQLONG MQHCONN;
typedef MQLONG MQHOBJ;

// MARK: - Connection Handle Constants

#define MQHC_UNUSABLE_HCONN (-1)
#define MQHO_UNUSABLE_HOBJ (-1)

// MARK: - Completion Codes

#define MQCC_OK 0
#define MQCC_WARNING 1
#define MQCC_FAILED 2

// MARK: - Reason Codes

#define MQRC_NONE 0
#define MQRC_NO_MSG_AVAILABLE 2033
#define MQRC_TRUNCATED_MSG_ACCEPTED 2079
#define MQRC_TRUNCATED_MSG_FAILED 2080
#define MQRC_NOT_AUTHORIZED 2035
#define MQRC_Q_MGR_NOT_AVAILABLE 2059
#define MQRC_CONNECTION_BROKEN 2009
#define MQRC_HOST_NOT_AVAILABLE 2538
#define MQRC_CHANNEL_NOT_AVAILABLE 2537
#define MQRC_UNKNOWN_CHANNEL_NAME 2540
#define MQRC_UNKNOWN_Q_MGR 2058
#define MQRC_Q_FULL 2053
#define MQRC_PUT_INHIBITED 2051
#define MQRC_GET_INHIBITED 2016
#define MQRC_OBJECT_IN_USE 2042
#define MQRC_OBJECT_CHANGED 2041

// MARK: - Field Length Constants

#define MQ_Q_MGR_NAME_LENGTH 48
#define MQ_Q_NAME_LENGTH 48
#define MQ_CHANNEL_NAME_LENGTH 20
#define MQ_CONN_NAME_LENGTH 264
#define MQ_MSG_ID_LENGTH 24
#define MQ_CORREL_ID_LENGTH 24
#define MQ_FORMAT_LENGTH 8
#define MQ_PUT_APPL_NAME_LENGTH 28
#define MQ_PUT_DATE_LENGTH 8
#define MQ_PUT_TIME_LENGTH 8

// MARK: - Queue Type Constants

#define MQQT_LOCAL 1
#define MQQT_MODEL 2
#define MQQT_ALIAS 3
#define MQQT_REMOTE 6
#define MQQT_CLUSTER 7
#define MQQT_ALL 1001

// MARK: - Object Type Constants

#define MQOT_Q 1
#define MQOT_Q_MGR 5

// MARK: - Open Options

#define MQOO_INPUT_SHARED 2
#define MQOO_INPUT_EXCLUSIVE 4
#define MQOO_BROWSE 8
#define MQOO_OUTPUT 16
#define MQOO_INQUIRE 32
#define MQOO_SET 64
#define MQOO_FAIL_IF_QUIESCING 8192

// MARK: - Close Options

#define MQCO_NONE 0
#define MQCO_DELETE 1
#define MQCO_DELETE_PURGE 2

// MARK: - Get Message Options

#define MQGMO_WAIT 1
#define MQGMO_NO_WAIT 0
#define MQGMO_SYNCPOINT 2
#define MQGMO_NO_SYNCPOINT 4
#define MQGMO_BROWSE_FIRST 16
#define MQGMO_BROWSE_NEXT 32
#define MQGMO_ACCEPT_TRUNCATED_MSG 64
#define MQGMO_FAIL_IF_QUIESCING 8192
#define MQGMO_CONVERT 16384

// MARK: - Put Message Options

#define MQPMO_SYNCPOINT 2
#define MQPMO_NO_SYNCPOINT 4
#define MQPMO_NEW_MSG_ID 64
#define MQPMO_NEW_CORREL_ID 128

// MARK: - Match Options

#define MQMO_NONE 0
#define MQMO_MATCH_MSG_ID 1
#define MQMO_MATCH_CORREL_ID 2

// MARK: - Message Types

#define MQMT_REQUEST 1
#define MQMT_REPLY 2
#define MQMT_DATAGRAM 8
#define MQMT_REPORT 4

// MARK: - Persistence

#define MQPER_NOT_PERSISTENT 0
#define MQPER_PERSISTENT 1
#define MQPER_PERSISTENCE_AS_Q_DEF 2

// MARK: - Channel Descriptor Constants

#define MQCD_VERSION_11 11
#define MQCHT_CLNTCONN 6
#define MQXPT_TCP 2

// MARK: - Connection Options

#define MQCNO_VERSION_5 5
#define MQCNO_HANDLE_SHARE_BLOCK 32

// MARK: - Security Parameters

#define MQCSP_VERSION_1 1
#define MQCSP_AUTH_USER_ID_AND_PWD 1

// MARK: - Object Descriptor

#define MQOD_VERSION_4 4

// MARK: - Message Descriptor

#define MQMD_VERSION_2 2

// MARK: - Get Message Options Version

#define MQGMO_VERSION_2 2

// MARK: - Put Message Options Version

#define MQPMO_VERSION_2 2

// MARK: - Queue Attribute Selectors (Integer)

#define MQIA_Q_TYPE 20
#define MQIA_CURRENT_Q_DEPTH 3
#define MQIA_MAX_Q_DEPTH 15
#define MQIA_OPEN_INPUT_COUNT 17
#define MQIA_OPEN_OUTPUT_COUNT 18
#define MQIA_INHIBIT_GET 8
#define MQIA_INHIBIT_PUT 10

// MARK: - Queue Attribute Selectors (Character)

#define MQCA_Q_NAME 2016

// MARK: - Inhibit Status

#define MQQA_GET_INHIBITED 1
#define MQQA_PUT_INHIBITED 1
#define MQQA_GET_ALLOWED 0
#define MQQA_PUT_ALLOWED 0

// MARK: - Coded Character Set

#define MQCCSI_DEFAULT 0

// MARK: - PCF Constants

#define MQCFT_COMMAND 1
#define MQCFT_RESPONSE 2
#define MQCFT_INTEGER 3
#define MQCFT_STRING 4
#define MQCFT_INTEGER_LIST 5
#define MQCFT_STRING_LIST 6

#define MQCFH_VERSION_1 1
#define MQCFH_STRUC_LENGTH 36

#define MQCFIN_STRUC_LENGTH 16
#define MQCFST_STRUC_LENGTH_FIXED 20

#define MQCFC_LAST 1
#define MQCFC_NOT_LAST 0

#define MQCMD_INQUIRE_Q 13
#define MQCMD_CREATE_Q 5
#define MQCMD_DELETE_Q 6
#define MQCMD_CHANGE_Q 8

// MARK: - Additional Reason Codes

#define MQRC_UNEXPECTED_ERROR 2195
#define MQRC_OBJECT_ALREADY_EXISTS 2041

// MARK: - Structures

// Channel Descriptor (MQCD)
typedef struct tagMQCD {
    MQCHAR ChannelName[20];
    MQLONG Version;
    MQLONG ChannelType;
    MQLONG TransportType;
    MQCHAR Desc[64];
    MQCHAR QMgrName[48];
    MQCHAR XmitQName[48];
    MQCHAR ShortConnectionName[20];
    MQCHAR MCAName[20];
    MQCHAR ModeName[8];
    MQCHAR TpName[64];
    MQLONG BatchSize;
    MQLONG DiscInterval;
    MQLONG ShortRetryCount;
    MQLONG ShortRetryInterval;
    MQLONG LongRetryCount;
    MQLONG LongRetryInterval;
    MQCHAR SecurityExit[128];
    MQCHAR MsgExit[128];
    MQCHAR SendExit[128];
    MQCHAR ReceiveExit[128];
    MQLONG SeqNumberWrap;
    MQLONG MaxMsgLength;
    MQLONG PutAuthority;
    MQLONG DataConversion;
    MQCHAR SecurityUserData[32];
    MQCHAR MsgUserData[32];
    MQCHAR SendUserData[32];
    MQCHAR ReceiveUserData[32];
    MQCHAR UserIdentifier[12];
    MQCHAR Password[12];
    MQCHAR MCAUserIdentifier[12];
    MQLONG MCAType;
    MQCHAR ConnectionName[264];
    MQCHAR RemoteUserIdentifier[12];
    MQCHAR RemotePassword[12];
    // Additional fields for higher versions
    MQCHAR MsgRetryExit[128];
    MQCHAR MsgRetryUserData[32];
    MQLONG MsgRetryCount;
    MQLONG MsgRetryInterval;
    MQLONG HeartbeatInterval;
    MQLONG BatchInterval;
    MQLONG NonPersistentMsgSpeed;
    MQLONG StrucLength;
    MQLONG ExitNameLength;
    MQLONG ExitDataLength;
    MQLONG MsgExitsDefined;
    MQLONG SendExitsDefined;
    MQLONG ReceiveExitsDefined;
    void* MsgExitPtr;
    void* MsgUserDataPtr;
    void* SendExitPtr;
    void* SendUserDataPtr;
    void* ReceiveExitPtr;
    void* ReceiveUserDataPtr;
    void* ClusterPtr;
    MQLONG ClustersDefined;
    MQLONG NetworkPriority;
    MQLONG LongMCAUserIdLength;
    MQLONG LongRemoteUserIdLength;
    void* LongMCAUserIdPtr;
    void* LongRemoteUserIdPtr;
    MQBYTE MCASecurityId[40];
    MQBYTE RemoteSecurityId[40];
    MQCHAR SSLCipherSpec[32];
    void* SSLPeerNamePtr;
    MQLONG SSLPeerNameLength;
    MQLONG SSLClientAuth;
    MQLONG KeepAliveInterval;
    MQCHAR LocalAddress[48];
    MQLONG BatchHeartbeat;
    MQLONG HdrCompList[2];
    MQLONG MsgCompList[16];
    MQLONG CLWLChannelRank;
    MQLONG CLWLChannelPriority;
    MQLONG CLWLChannelWeight;
    MQLONG ChannelMonitoring;
    MQLONG ChannelStatistics;
    MQLONG SharingConversations;
    MQLONG PropertyControl;
    MQLONG MaxInstances;
    MQLONG MaxInstancesPerClient;
    MQLONG ClientChannelWeight;
    MQLONG ConnectionAffinity;
    MQLONG BatchDataLimit;
    MQLONG UseDLQ;
    MQLONG DefReconnect;
    MQCHAR CertificateLabel[64];
} MQCD;

// Connection Options (MQCNO)
typedef struct tagMQCNO {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG Options;
    MQLONG ClientConnOffset;
    void* ClientConnPtr;
    MQBYTE ConnTag[128];
    void* SSLConfigPtr;
    MQLONG SSLConfigOffset;
    MQBYTE ConnectionId[24];
    MQLONG SecurityParmsOffset;
    void* SecurityParmsPtr;
    void* CCDTUrlPtr;
    MQLONG CCDTUrlOffset;
    MQLONG CCDTUrlLength;
    MQLONG Reserved[4];
} MQCNO;

// Security Parameters (MQCSP)
typedef struct tagMQCSP {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG AuthenticationType;
    MQBYTE Reserved1[4];
    void* CSPUserIdPtr;
    MQLONG CSPUserIdOffset;
    MQLONG CSPUserIdLength;
    MQBYTE Reserved2[8];
    void* CSPPasswordPtr;
    MQLONG CSPPasswordOffset;
    MQLONG CSPPasswordLength;
} MQCSP;

// Object Descriptor (MQOD)
typedef struct tagMQOD {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG ObjectType;
    MQCHAR ObjectName[48];
    MQCHAR ObjectQMgrName[48];
    MQCHAR DynamicQName[48];
    MQCHAR AlternateUserId[12];
    MQLONG RecsPresent;
    MQLONG KnownDestCount;
    MQLONG UnknownDestCount;
    MQLONG InvalidDestCount;
    MQLONG ObjectRecOffset;
    MQLONG ResponseRecOffset;
    void* ObjectRecPtr;
    void* ResponseRecPtr;
    MQBYTE AlternateSecurityId[40];
    MQCHAR ResolvedQName[48];
    MQCHAR ResolvedQMgrName[48];
    MQCHAR ObjectString[256];
    MQCHAR SelectionString[256];
    MQCHAR ResObjectString[256];
    MQLONG ResolvedType;
} MQOD;

// Message Descriptor (MQMD)
typedef struct tagMQMD {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG Report;
    MQLONG MsgType;
    MQLONG Expiry;
    MQLONG Feedback;
    MQLONG Encoding;
    MQLONG CodedCharSetId;
    MQCHAR Format[8];
    MQLONG Priority;
    MQLONG Persistence;
    MQBYTE MsgId[24];
    MQBYTE CorrelId[24];
    MQLONG BackoutCount;
    MQCHAR ReplyToQ[48];
    MQCHAR ReplyToQMgr[48];
    MQCHAR UserIdentifier[12];
    MQBYTE AccountingToken[32];
    MQCHAR ApplIdentityData[32];
    MQLONG PutApplType;
    MQCHAR PutApplName[28];
    MQCHAR PutDate[8];
    MQCHAR PutTime[8];
    MQCHAR ApplOriginData[4];
    MQBYTE GroupId[24];
    MQLONG MsgSeqNumber;
    MQLONG Offset;
    MQLONG MsgFlags;
    MQLONG OriginalLength;
} MQMD;

// Get Message Options (MQGMO)
typedef struct tagMQGMO {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG Options;
    MQLONG WaitInterval;
    MQLONG Signal1;
    MQLONG Signal2;
    MQCHAR ResolvedQName[48];
    MQLONG MatchOptions;
    MQCHAR GroupStatus;
    MQCHAR SegmentStatus;
    MQCHAR Segmentation;
    MQCHAR Reserved1;
    MQBYTE MsgToken[16];
    MQLONG ReturnedLength;
    MQLONG Reserved2;
    MQLONG MsgHandle;
} MQGMO;

// Put Message Options (MQPMO)
typedef struct tagMQPMO {
    MQCHAR StrucId[4];
    MQLONG Version;
    MQLONG Options;
    MQLONG Timeout;
    MQHOBJ Context;
    MQLONG KnownDestCount;
    MQLONG UnknownDestCount;
    MQLONG InvalidDestCount;
    MQCHAR ResolvedQName[48];
    MQCHAR ResolvedQMgrName[48];
    MQLONG RecsPresent;
    MQLONG PutMsgRecFields;
    MQLONG PutMsgRecOffset;
    MQLONG ResponseRecOffset;
    void* PutMsgRecPtr;
    void* ResponseRecPtr;
    MQLONG OriginalMsgHandle;
    MQLONG NewMsgHandle;
    MQLONG Action;
    MQLONG PubLevel;
} MQPMO;

// PCF Header (MQCFH)
typedef struct tagMQCFH {
    MQLONG Type;
    MQLONG StrucLength;
    MQLONG Version;
    MQLONG Command;
    MQLONG MsgSeqNumber;
    MQLONG Control;
    MQLONG CompCode;
    MQLONG Reason;
    MQLONG ParameterCount;
} MQCFH;

// PCF Integer Parameter (MQCFIN)
typedef struct tagMQCFIN {
    MQLONG Type;
    MQLONG StrucLength;
    MQLONG Parameter;
    MQLONG Value;
} MQCFIN;

// PCF String Parameter (MQCFST)
typedef struct tagMQCFST {
    MQLONG Type;
    MQLONG StrucLength;
    MQLONG Parameter;
    MQLONG CodedCharSetId;
    MQLONG StringLength;
    MQCHAR String[1];
} MQCFST;

// MARK: - MQ API Function Declarations (Stubs)

// Note: These are stub declarations. The real implementations come from the MQ client library.

static inline void MQCONNX(
    MQCHAR* QMgrName,
    MQCNO* pConnectOpts,
    MQHCONN* pHconn,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation - always fail with "not available"
    *pHconn = MQHC_UNUSABLE_HCONN;
    *pCompCode = MQCC_FAILED;
    *pReason = MQRC_Q_MGR_NOT_AVAILABLE;
}

static inline void MQDISC(
    MQHCONN* pHconn,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pHconn = MQHC_UNUSABLE_HCONN;
    *pCompCode = MQCC_OK;
    *pReason = MQRC_NONE;
}

static inline void MQOPEN(
    MQHCONN Hconn,
    MQOD* pObjDesc,
    MQLONG Options,
    MQHOBJ* pHobj,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pHobj = MQHO_UNUSABLE_HOBJ;
    *pCompCode = MQCC_FAILED;
    *pReason = MQRC_Q_MGR_NOT_AVAILABLE;
}

static inline void MQCLOSE(
    MQHCONN Hconn,
    MQHOBJ* pHobj,
    MQLONG Options,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pHobj = MQHO_UNUSABLE_HOBJ;
    *pCompCode = MQCC_OK;
    *pReason = MQRC_NONE;
}

static inline void MQGET(
    MQHCONN Hconn,
    MQHOBJ Hobj,
    MQMD* pMsgDesc,
    MQGMO* pGetMsgOpts,
    MQLONG BufferLength,
    void* pBuffer,
    MQLONG* pDataLength,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pDataLength = 0;
    *pCompCode = MQCC_FAILED;
    *pReason = MQRC_Q_MGR_NOT_AVAILABLE;
}

static inline void MQPUT(
    MQHCONN Hconn,
    MQHOBJ Hobj,
    MQMD* pMsgDesc,
    MQPMO* pPutMsgOpts,
    MQLONG BufferLength,
    void* pBuffer,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pCompCode = MQCC_FAILED;
    *pReason = MQRC_Q_MGR_NOT_AVAILABLE;
}

static inline void MQINQ(
    MQHCONN Hconn,
    MQHOBJ Hobj,
    MQLONG SelectorCount,
    MQLONG* pSelectors,
    MQLONG IntAttrCount,
    MQLONG* pIntAttrs,
    MQLONG CharAttrLength,
    MQCHAR* pCharAttrs,
    MQLONG* pCompCode,
    MQLONG* pReason
) {
    // Stub implementation
    *pCompCode = MQCC_FAILED;
    *pReason = MQRC_Q_MGR_NOT_AVAILABLE;
}

#endif /* MQ_STUBS_H */
