#!/bin/bash

# FreeCAD QuickLook Build Environment Validation Script
# This script checks that all required tools and dependencies are available
# for building QuickLook extensions with the Unix Makefiles approach

# Note: Not using set -e to allow graceful error handling

echo "=== FreeCAD QuickLook Environment Validation ==="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Function to check if a command exists
check_command() {
    local cmd=$1
    local description=$2
    local required=${3:-true}

    if command -v "$cmd" >/dev/null 2>&1; then
        local cmd_path=$(command -v "$cmd" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} $description: $cmd_path"
        if $required; then
            ((CHECKS_PASSED++))
        fi
    else
        if $required; then
            echo -e "${RED}✗${NC} $description: NOT FOUND"
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}⚠${NC} $description: NOT FOUND (optional)"
            ((WARNINGS++))
        fi
    fi
}

# Function to check version requirements
check_version() {
    local cmd=$1
    local min_version=$2
    local description=$3

    if command -v "$cmd" >/dev/null 2>&1; then
        local version_output=$($cmd --version 2>/dev/null | head -1 || echo "version unknown")
        echo -e "${GREEN}✓${NC} $description version: $version_output"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description: NOT FOUND"
        ((CHECKS_FAILED++))
    fi
}

# Function to check file/directory exists
check_path() {
    local path=$1
    local description=$2
    local required=${3:-true}

    if [ -e "$path" ]; then
        echo -e "${GREEN}✓${NC} $description: $path"
        if $required; then
            ((CHECKS_PASSED++))
        fi
    else
        if $required; then
            echo -e "${RED}✗${NC} $description: NOT FOUND"
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}⚠${NC} $description: NOT FOUND (optional)"
            ((WARNINGS++))
        fi
    fi
}

echo "Checking required tools..."
echo

# Check for essential build tools
check_command "swiftc" "Swift Compiler"
check_command "codesign" "Code Signing Tool"
check_command "plutil" "Property List Utility"
check_command "cmake" "CMake Build System"
check_command "make" "Make Build Tool"
check_command "xcrun" "Xcode Command Line Tools"

echo
echo "Checking tool versions..."
echo

# Check versions
check_version "swiftc" "5.0" "Swift Compiler"
check_version "cmake" "3.22" "CMake"

echo
echo "Checking macOS SDK..."
echo

# Check for macOS SDK
if command -v xcrun >/dev/null 2>&1; then
    SDK_PATH=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || echo "")
    SDK_RESULT=$?
    if [ $SDK_RESULT -eq 0 ] && [ -d "$SDK_PATH" ] && [ -n "$SDK_PATH" ]; then
        echo -e "${GREEN}✓${NC} macOS SDK: $SDK_PATH"
        ((CHECKS_PASSED++))

        # Check SDK version
        SDK_VERSION=$(xcrun --show-sdk-version --sdk macosx 2>/dev/null || echo "")
        VERSION_RESULT=$?
        if [ $VERSION_RESULT -eq 0 ] && [ -n "$SDK_VERSION" ]; then
            echo -e "${GREEN}✓${NC} macOS SDK Version: $SDK_VERSION"
            ((CHECKS_PASSED++))

            # Check if SDK version is sufficient for macOS 15.0 target
            # Note: SDK version 26.x corresponds to macOS 15.x
            if command -v awk >/dev/null 2>&1; then
                SDK_MAJOR=$(echo "$SDK_VERSION" | awk -F. '{print $1}' 2>/dev/null || echo "0")
                if [ "$SDK_MAJOR" -ge 26 ] 2>/dev/null; then
                    echo -e "${GREEN}✓${NC} SDK supports macOS 15.0+ deployment target (SDK $SDK_VERSION)"
                    ((CHECKS_PASSED++))
                elif [ "$SDK_MAJOR" -ge 15 ] 2>/dev/null; then
                    echo -e "${GREEN}✓${NC} SDK supports macOS 15.0+ deployment target"
                    ((CHECKS_PASSED++))
                else
                    echo -e "${YELLOW}⚠${NC} SDK version $SDK_VERSION may not fully support macOS 15.0 target"
                    ((WARNINGS++))
                fi
            else
                echo -e "${YELLOW}⚠${NC} Cannot verify SDK version compatibility (awk command not available)"
                ((WARNINGS++))
            fi
        else
            echo -e "${RED}✗${NC} Could not determine SDK version"
            ((CHECKS_FAILED++))
        fi
    else
        echo -e "${RED}✗${NC} macOS SDK not found or not accessible"
        ((CHECKS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} xcrun not available - install Xcode Command Line Tools"
    ((CHECKS_FAILED++))
fi

echo
echo "Checking system requirements..."
echo

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
if [ "$MACOS_VERSION" != "unknown" ]; then
    echo -e "${GREEN}✓${NC} macOS Version: $MACOS_VERSION"
    ((CHECKS_PASSED++))

    # Check if running on macOS 15.0+
    # Note: macOS version 26.x is actually macOS 15.x (Sequoia)
    if command -v awk >/dev/null 2>&1; then
        MACOS_MAJOR=$(echo "$MACOS_VERSION" | awk -F. '{print $1}' 2>/dev/null || echo "0")
        if [ "$MACOS_MAJOR" -ge 26 ] 2>/dev/null; then
            echo -e "${GREEN}✓${NC} macOS version supports QuickLook extensions (macOS 15.x/Sequoia)"
            ((CHECKS_PASSED++))
        elif [ "$MACOS_MAJOR" -ge 15 ] 2>/dev/null; then
            echo -e "${GREEN}✓${NC} macOS version supports QuickLook extensions"
            ((CHECKS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} macOS $MACOS_VERSION - QuickLook extensions require 15.0+ for full functionality"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} Cannot verify macOS version compatibility (awk command not available)"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Could not determine macOS version"
    ((CHECKS_FAILED++))
fi

# Check architecture
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [ "$ARCH" != "unknown" ]; then
    echo -e "${GREEN}✓${NC} Architecture: $ARCH"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Could not determine system architecture"
    ((CHECKS_FAILED++))
fi

echo
echo "Checking Xcode installation..."
echo

# Check Xcode installation
if command -v xcode-select >/dev/null 2>&1; then
    XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
    XCODE_RESULT=$?
    if [ $XCODE_RESULT -eq 0 ] && [ -d "$XCODE_PATH" ] && [ -n "$XCODE_PATH" ]; then
        echo -e "${GREEN}✓${NC} Xcode Developer Tools: $XCODE_PATH"
        ((CHECKS_PASSED++))

        # Check if full Xcode is installed (optional)
        if [ -d "/Applications/Xcode.app" ]; then
            XCODE_VERSION=$(defaults read /Applications/Xcode.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "")
            if [ -n "$XCODE_VERSION" ]; then
                echo -e "${GREEN}✓${NC} Full Xcode installation: $XCODE_VERSION"
            else
                echo -e "${YELLOW}⚠${NC} Full Xcode installed but version unreadable"
                ((WARNINGS++))
            fi
        else
            echo -e "${YELLOW}⚠${NC} Full Xcode not installed (Command Line Tools sufficient)"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} Xcode Developer Tools not properly configured"
        echo "Run: xcode-select --install"
        ((CHECKS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} xcode-select not found"
    ((CHECKS_FAILED++))
fi

echo
echo "Checking project files..."
echo

# Check that we're in the right directory
if [ -f "CMakeLists.txt" ]; then
    echo -e "${GREEN}✓${NC} CMakeLists.txt found"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} CMakeLists.txt not found - run from QuickLook directory"
    ((CHECKS_FAILED++))
fi

# Check source files
SOURCE_FILES=(
    "FreeCADQuickLookHostApp.swift"
    "ThumbnailProvider.swift"
    "PreviewProvider.swift"
    "ZipExtractor.swift"
)

for file in "${SOURCE_FILES[@]}"; do
    check_path "$file" "Source file: $file"
done

# Check configuration files
CONFIG_FILES=(
    "FreeCADQuickLookHostInfo.plist"
    "ThumbnailExtensionInfo.plist"
    "PreviewExtensionInfo.plist"
    "ThumbnailExtension.entitlements"
    "PreviewExtension.entitlements"
)

for file in "${CONFIG_FILES[@]}"; do
    check_path "$file" "Config file: $file"
done

echo
echo "Checking optional tools..."
echo

# Optional but useful tools
check_command "pluginkit" "Plugin Kit (for extension management)" false
check_command "qlmanage" "QuickLook Manager" false
check_command "log" "System Log Tool" false

echo
echo "=== Validation Summary ==="
echo -e "${GREEN}Checks Passed: $CHECKS_PASSED${NC}"
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}Checks Failed: $CHECKS_FAILED${NC}"
fi
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
echo

# Final verdict
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Environment validation PASSED${NC}"
    echo "Your system is ready to build FreeCAD QuickLook extensions!"
    echo
    echo "Next steps:"
    echo "1. Run ./test_build.sh to test the build"
    echo "2. Or manually run: mkdir build && cd build && cmake -G \"Unix Makefiles\" .. && make"
    exit 0
else
    echo -e "${RED}✗ Environment validation FAILED${NC}"
    echo "Please resolve the failed checks before attempting to build."
    echo
    echo "Common solutions:"
    echo "- Install Xcode Command Line Tools: xcode-select --install"
    echo "- Install CMake: brew install cmake"
    echo "- Ensure you're in the correct directory (QuickLook/)"
    exit 1
fi
