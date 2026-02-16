#!/bin/bash
# MQMate Run Script
# Runs the MQMate application with proper environment setup
#
# Usage: ./scripts/run.sh [release]
#   - No arguments: Run debug version
#   - release: Run optimized release version

set -e

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (for running from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

# Determine build configuration
BUILD_CONFIG="debug"
if [ "$1" == "release" ]; then
    BUILD_CONFIG="release"
fi

BINARY_PATH=".build/$BUILD_CONFIG/MQMate"

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: MQMate binary not found at $BINARY_PATH${NC}"
    echo ""
    echo "Please build the application first:"
    if [ "$BUILD_CONFIG" == "release" ]; then
        echo "  ./scripts/build.sh release"
    else
        echo "  ./scripts/build.sh"
    fi
    exit 1
fi

# Set up IBM MQ Client environment
MQ_LIB_PATH="/opt/mqm/lib64"

if [ -d "$MQ_LIB_PATH" ] && [ -f "$MQ_LIB_PATH/libmqic_r.dylib" ]; then
    export DYLD_LIBRARY_PATH="$MQ_LIB_PATH:$DYLD_LIBRARY_PATH"
    echo -e "${GREEN}IBM MQ Client:${NC} Environment configured"
else
    echo -e "${YELLOW}Warning: IBM MQ Client not found at /opt/mqm${NC}"
    echo "Running in mock mode (UI only, no MQ connectivity)"
    echo ""
fi

echo -e "${BLUE}Starting MQMate ($BUILD_CONFIG)...${NC}"
echo ""

# Run the application
exec "$BINARY_PATH"
