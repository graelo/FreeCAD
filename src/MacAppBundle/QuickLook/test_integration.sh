#!/bin/bash

# FreeCAD QuickLook Extensions - Integration Test Script
# This script tests the QuickLook extension integration in FreeCAD.app

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../../../build"
FREECAD_APP="${BUILD_DIR}/src/MacAppBundle/FreeCAD.app"
EXTENSIONS_DIR="${FREECAD_APP}/Contents/PlugIns"

THUMBNAIL_EXT="${EXTENSIONS_DIR}/FreeCADThumbnailExtension.appex"
PREVIEW_EXT="${EXTENSIONS_DIR}/FreeCADPreviewExtension.appex"

THUMBNAIL_BUNDLE_ID="org.freecad.FreeCAD.quicklook.thumbnail"
PREVIEW_BUNDLE_ID="org.freecad.FreeCAD.quicklook.preview"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to run test with error handling
run_test() {
    local test_name=$1
    local test_command=$2

    print_status "INFO" "Running: $test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        print_status "OK" "$test_name"
        return 0
    else
        print_status "FAIL" "$test_name"
        return 1
    fi
}

# Main test function
main() {
    echo "FreeCAD QuickLook Extensions - Integration Test"
    echo "=============================================="
    echo

    local total_tests=0
    local passed_tests=0

    # Test 1: Check if FreeCAD.app exists
    ((total_tests++))
    if [[ -d "$FREECAD_APP" ]]; then
        print_status "OK" "FreeCAD.app exists at: $FREECAD_APP"
        ((passed_tests++))
    else
        print_status "FAIL" "FreeCAD.app not found at: $FREECAD_APP"
        print_status "INFO" "Please build FreeCAD first with: make FreeCAD"
        exit 1
    fi

    # Test 2: Check if PlugIns directory exists
    ((total_tests++))
    if [[ -d "$EXTENSIONS_DIR" ]]; then
        print_status "OK" "Extensions directory exists: $EXTENSIONS_DIR"
        ((passed_tests++))
    else
        print_status "FAIL" "Extensions directory not found: $EXTENSIONS_DIR"
        print_status "INFO" "Please build QuickLook extensions with: make FreeCADQuickLook"
        exit 1
    fi

    # Test 3: Check if thumbnail extension exists
    ((total_tests++))
    if [[ -d "$THUMBNAIL_EXT" ]]; then
        print_status "OK" "Thumbnail extension exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Thumbnail extension not found: $THUMBNAIL_EXT"
    fi

    # Test 4: Check if preview extension exists
    ((total_tests++))
    if [[ -d "$PREVIEW_EXT" ]]; then
        print_status "OK" "Preview extension exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Preview extension not found: $PREVIEW_EXT"
    fi

    # Test 5: Check if thumbnail extension executable exists
    ((total_tests++))
    if [[ -f "$THUMBNAIL_EXT/Contents/MacOS/FreeCADThumbnailExtension" ]]; then
        print_status "OK" "Thumbnail extension executable exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Thumbnail extension executable not found"
    fi

    # Test 6: Check if preview extension executable exists
    ((total_tests++))
    if [[ -f "$PREVIEW_EXT/Contents/MacOS/FreeCADPreviewExtension" ]]; then
        print_status "OK" "Preview extension executable exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Preview extension executable not found"
    fi

    # Test 7: Check if thumbnail extension Info.plist exists
    ((total_tests++))
    if [[ -f "$THUMBNAIL_EXT/Contents/Info.plist" ]]; then
        print_status "OK" "Thumbnail extension Info.plist exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Thumbnail extension Info.plist not found"
    fi

    # Test 8: Check if preview extension Info.plist exists
    ((total_tests++))
    if [[ -f "$PREVIEW_EXT/Contents/Info.plist" ]]; then
        print_status "OK" "Preview extension Info.plist exists"
        ((passed_tests++))
    else
        print_status "FAIL" "Preview extension Info.plist not found"
    fi

    # Test 9: Check thumbnail extension bundle ID
    ((total_tests++))
    if [[ -f "$THUMBNAIL_EXT/Contents/Info.plist" ]]; then
        local bundle_id=$(plutil -extract CFBundleIdentifier raw "$THUMBNAIL_EXT/Contents/Info.plist" 2>/dev/null)
        if [[ "$bundle_id" == "$THUMBNAIL_BUNDLE_ID" ]]; then
            print_status "OK" "Thumbnail extension has correct bundle ID: $bundle_id"
            ((passed_tests++))
        else
            print_status "FAIL" "Thumbnail extension bundle ID incorrect: $bundle_id (expected: $THUMBNAIL_BUNDLE_ID)"
        fi
    fi

    # Test 10: Check preview extension bundle ID
    ((total_tests++))
    if [[ -f "$PREVIEW_EXT/Contents/Info.plist" ]]; then
        local bundle_id=$(plutil -extract CFBundleIdentifier raw "$PREVIEW_EXT/Contents/Info.plist" 2>/dev/null)
        if [[ "$bundle_id" == "$PREVIEW_BUNDLE_ID" ]]; then
            print_status "OK" "Preview extension has correct bundle ID: $bundle_id"
            ((passed_tests++))
        else
            print_status "FAIL" "Preview extension bundle ID incorrect: $bundle_id (expected: $PREVIEW_BUNDLE_ID)"
        fi
    fi

    # Test 11: Check code signatures
    ((total_tests++))
    if codesign -v "$THUMBNAIL_EXT" >/dev/null 2>&1; then
        print_status "OK" "Thumbnail extension is properly signed"
        ((passed_tests++))
    else
        print_status "FAIL" "Thumbnail extension signature verification failed"
    fi

    # Test 12: Check code signatures
    ((total_tests++))
    if codesign -v "$PREVIEW_EXT" >/dev/null 2>&1; then
        print_status "OK" "Preview extension is properly signed"
        ((passed_tests++))
    else
        print_status "FAIL" "Preview extension signature verification failed"
    fi

    # Optional tests (don't count toward pass/fail)
    echo
    print_status "INFO" "Additional Information:"

    # Show signing details
    if command -v codesign >/dev/null 2>&1; then
        echo
        print_status "INFO" "Signing Information:"
        echo "  Thumbnail Extension:"
        codesign -d -vv "$THUMBNAIL_EXT" 2>&1 | grep -E "(Identifier|Authority|Signature size)" | sed 's/^/    /'
        echo "  Preview Extension:"
        codesign -d -vv "$PREVIEW_EXT" 2>&1 | grep -E "(Identifier|Authority|Signature size)" | sed 's/^/    /'
    fi

    # Show current registration status (if pluginkit is available)
    if command -v pluginkit >/dev/null 2>&1; then
        echo
        print_status "INFO" "Current Registration Status:"

        if pluginkit -m -v -i "$THUMBNAIL_BUNDLE_ID" >/dev/null 2>&1; then
            print_status "OK" "Thumbnail extension is registered with system"
        else
            print_status "WARN" "Thumbnail extension not registered (normal before first FreeCAD launch)"
        fi

        if pluginkit -m -v -i "$PREVIEW_BUNDLE_ID" >/dev/null 2>&1; then
            print_status "OK" "Preview extension is registered with system"
        else
            print_status "WARN" "Preview extension not registered (normal before first FreeCAD launch)"
        fi
    fi

    # Summary
    echo
    echo "Test Results:"
    echo "============"
    echo "Passed: $passed_tests/$total_tests tests"

    if [[ $passed_tests -eq $total_tests ]]; then
        print_status "OK" "All tests passed! QuickLook extensions are properly integrated."
        echo
        echo "Next Steps:"
        echo "  1. Launch FreeCAD to trigger automatic extension registration"
        echo "  2. Test QuickLook functionality with .FCStd files in Finder"
        echo "  3. Look for system notification: 'FreeCAD added 2 Quick Look previewer extensions'"
        return 0
    else
        print_status "FAIL" "Some tests failed. Please check the build configuration."
        echo
        echo "Troubleshooting:"
        echo "  1. Ensure you're using Unix Makefiles generator: cmake -G 'Unix Makefiles'"
        echo "  2. Build QuickLook extensions: make FreeCADQuickLook"
        echo "  3. Check CMake configuration for QuickLook options"
        return 1
    fi
}

# Test registration functionality (optional)
test_registration() {
    if [[ "$1" == "--test-registration" ]]; then
        echo
        print_status "INFO" "Testing extension registration..."

        if command -v pluginkit >/dev/null 2>&1; then
            print_status "INFO" "Attempting to register extensions..."

            pluginkit -a "$THUMBNAIL_EXT" >/dev/null 2>&1 || print_status "WARN" "Thumbnail registration command failed (may already be registered)"
            pluginkit -a "$PREVIEW_EXT" >/dev/null 2>&1 || print_status "WARN" "Preview registration command failed (may already be registered)"

            pluginkit -e use -i "$THUMBNAIL_BUNDLE_ID" >/dev/null 2>&1 || print_status "WARN" "Thumbnail activation command failed"
            pluginkit -e use -i "$PREVIEW_BUNDLE_ID" >/dev/null 2>&1 || print_status "WARN" "Preview activation command failed"

            sleep 1

            if pluginkit -m -v -i "$THUMBNAIL_BUNDLE_ID" >/dev/null 2>&1; then
                print_status "OK" "Thumbnail extension successfully registered"
            else
                print_status "FAIL" "Thumbnail extension registration failed"
            fi

            if pluginkit -m -v -i "$PREVIEW_BUNDLE_ID" >/dev/null 2>&1; then
                print_status "OK" "Preview extension successfully registered"
            else
                print_status "FAIL" "Preview extension registration failed"
            fi
        else
            print_status "WARN" "pluginkit not available for registration testing"
        fi
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [--test-registration] [--help]"
    echo
    echo "Options:"
    echo "  --test-registration  Also test extension registration with pluginkit"
    echo "  --help              Show this help message"
    echo
    echo "This script tests the QuickLook extension integration in FreeCAD.app."
    echo "Run this after building FreeCAD with QuickLook extensions enabled."
}

# Handle command line arguments
case "${1:-}" in
    --help)
        show_usage
        exit 0
        ;;
    --test-registration)
        main
        test_registration "$1"
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
