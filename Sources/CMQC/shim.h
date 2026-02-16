// CMQC Shim Header
// Provides Swift interop with IBM MQ C Client library headers
// Requires IBM MQ Client installed at /opt/mqm for full functionality
// Install: brew tap ibm-messaging/ibmmq && brew install --cask ibm-messaging/ibmmq/ibmmq

#ifndef CMQC_SHIM_H
#define CMQC_SHIM_H

// Check if IBM MQ Client is installed by looking for the header
#if __has_include("/opt/mqm/inc/cmqc.h")
    // Real IBM MQ Client headers available
    #include "/opt/mqm/inc/cmqc.h"
    #include "/opt/mqm/inc/cmqxc.h"
    #define MQ_CLIENT_AVAILABLE 1
#else
    // Use stub headers for development/compilation
    #include "mq_stubs.h"
    #define MQ_CLIENT_AVAILABLE 0
#endif

#endif
