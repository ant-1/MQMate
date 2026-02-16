#!/bin/bash
# MQMate Build Script
# Builds the MQMate application using Swift Package Manager
#
# Usage: ./scripts/build.sh [release]
#   - No arguments: Build debug version
#   - release: Build optimized release version

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MQMate Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"
echo -e "${GREEN}Project root:${NC} $PROJECT_ROOT"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift is not installed or not in PATH${NC}"
    echo "Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

SWIFT_VERSION=$(swift --version 2>&1 | head -1)
echo -e "${GREEN}Swift version:${NC} $SWIFT_VERSION"

# Check for IBM MQ Client installation
MQ_LIB_PATH="/opt/mqm/lib64"
MQ_INC_PATH="/opt/mqm/inc"

if [ -d "$MQ_LIB_PATH" ] && [ -f "$MQ_LIB_PATH/libmqic_r.dylib" ]; then
    echo -e "${GREEN}IBM MQ Client:${NC} Found at /opt/mqm"

    # Set up environment for MQ library
    export DYLD_LIBRARY_PATH="$MQ_LIB_PATH:$DYLD_LIBRARY_PATH"
else
    echo -e "${YELLOW}Warning: IBM MQ Client not found at /opt/mqm${NC}"
    echo "The build will proceed in mock mode (UI only, no MQ connectivity)"
    echo ""
    echo "To install IBM MQ Client:"
    echo "  brew tap ibm-messaging/ibmmq"
    echo "  brew install --cask ibm-messaging/ibmmq/ibmmq"
    echo ""
fi

# Determine build configuration
BUILD_CONFIG="debug"
SWIFT_FLAGS=""

if [ "$1" == "release" ]; then
    BUILD_CONFIG="release"
    SWIFT_FLAGS="-c release"
    echo -e "${GREEN}Build config:${NC} Release (optimized)"
else
    echo -e "${GREEN}Build config:${NC} Debug"
fi

echo ""
echo -e "${BLUE}Building MQMate...${NC}"
echo ""

# Run the build
swift build $SWIFT_FLAGS

# Check build result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Build complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    BINARY_PATH=".build/$BUILD_CONFIG/MQMate"
    if [ -f "$BINARY_PATH" ]; then
        echo -e "${GREEN}Binary:${NC} $PROJECT_ROOT/$BINARY_PATH"
        echo ""
        echo "To run the application:"
        echo "  $BINARY_PATH"
        echo ""
        echo "Or use the run script:"
        echo "  ./scripts/run.sh"
    fi
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  Build failed!${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
