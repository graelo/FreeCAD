cmake_minimum_required(VERSION 3.22)
project(FreeCADQuickLookSwift)

# Check generator and set approach
if(CMAKE_GENERATOR STREQUAL "Xcode")
    message(STATUS "Using Xcode generator - falling back to legacy Swift approach")
    set(USE_UNIX_MAKEFILES_APPROACH OFF)
elseif(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
    message(STATUS "Using Unix Makefiles generator - using direct swiftc approach")
    set(USE_UNIX_MAKEFILES_APPROACH ON)
else()
    message(WARNING "Unsupported generator: ${CMAKE_GENERATOR}. QuickLook extensions may not build correctly.")
    set(USE_UNIX_MAKEFILES_APPROACH OFF)
endif()

# Only proceed with Unix Makefiles approach if using that generator
if(USE_UNIX_MAKEFILES_APPROACH)

# Configuration options
option(FREECAD_QUICKLOOK_USE_PRODUCTION_SIGNING "Use FreeCAD's production certificate for QuickLook extensions" OFF)
set(FREECAD_CODESIGN_IDENTITY "" CACHE STRING "Code signing identity for production builds (e.g., 'Developer ID Application: FreeCAD Team (289DJRF23X)')")

# Check for required tools
find_program(SWIFTC_EXECUTABLE swiftc REQUIRED)
find_program(CODESIGN_EXECUTABLE codesign REQUIRED)
find_program(PLUTIL_EXECUTABLE plutil REQUIRED)

# Find macOS SDK
execute_process(
    COMMAND xcrun --show-sdk-path --sdk macosx
    OUTPUT_VARIABLE MACOS_SDK_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE SDK_RESULT
)

if(NOT SDK_RESULT EQUAL 0 OR NOT EXISTS "${MACOS_SDK_PATH}")
    message(FATAL_ERROR "macOS SDK not found. Please install Xcode Command Line Tools.")
endif()

message(STATUS "Using macOS SDK: ${MACOS_SDK_PATH}")

# macOS version requirements
set(MACOS_DEPLOYMENT_TARGET "15.0")
set(CMAKE_OSX_DEPLOYMENT_TARGET ${MACOS_DEPLOYMENT_TARGET})

# Bundle identifiers - use FreeCAD's main bundle ID hierarchy
set(FREECAD_BUNDLE_ID "org.freecad.FreeCAD")
set(THUMBNAIL_BUNDLE_ID "${FREECAD_BUNDLE_ID}.quicklook.thumbnail")
set(PREVIEW_BUNDLE_ID "${FREECAD_BUNDLE_ID}.quicklook.preview")

# Target main FreeCAD app instead of separate host
set(TARGET_APP_BUNDLE "${CMAKE_BINARY_DIR}/src/MacAppBundle/FreeCAD.app")
set(EXTENSIONS_DIR "${TARGET_APP_BUNDLE}/Contents/PlugIns")

# Output directories for extensions
set(BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(THUMBNAIL_EXT_DIR "${BUILD_DIR}/FreeCADThumbnailExtension.appex")
set(PREVIEW_EXT_DIR "${BUILD_DIR}/FreeCADPreviewExtension.appex")

# Detect target architecture
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64" OR CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    set(TARGET_ARCH "arm64")
else()
    set(TARGET_ARCH "x86_64")
endif()

# Swift compilation flags
set(SWIFT_FLAGS
    -target ${TARGET_ARCH}-apple-macosx${MACOS_DEPLOYMENT_TARGET}
    -sdk ${MACOS_SDK_PATH}
    -O
    -whole-module-optimization
    -enable-library-evolution
    -swift-version 5
)

# Determine signing identity
if(FREECAD_QUICKLOOK_USE_PRODUCTION_SIGNING AND FREECAD_CODESIGN_IDENTITY)
    set(SIGNING_IDENTITY "${FREECAD_CODESIGN_IDENTITY}")
    message(STATUS "Using production signing identity: ${SIGNING_IDENTITY}")
else()
    set(SIGNING_IDENTITY "-")
    message(STATUS "Using ad-hoc signing for development")
endif()

# Function to process Info.plist files
function(process_plist input_plist output_plist bundle_id executable_name product_name principal_class)
    if(principal_class)
        # For extensions with principal class
        add_custom_command(
            OUTPUT ${output_plist}
            COMMAND ${CMAKE_COMMAND} -E copy ${input_plist} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleIdentifier -string ${bundle_id} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleExecutable -string ${executable_name} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleName -string ${product_name} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace NSExtension.NSExtensionPrincipalClass -string ${principal_class} ${output_plist}
            DEPENDS ${input_plist}
            COMMENT "Processing extension ${input_plist} -> ${output_plist}"
        )
    else()
        # For regular apps without principal class
        add_custom_command(
            OUTPUT ${output_plist}
            COMMAND ${CMAKE_COMMAND} -E copy ${input_plist} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleIdentifier -string ${bundle_id} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleExecutable -string ${executable_name} ${output_plist}
            COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleName -string ${product_name} ${output_plist}
            DEPENDS ${input_plist}
            COMMENT "Processing ${input_plist} -> ${output_plist}"
        )
    endif()
endfunction()

# Create bundle directory structure and extensions directory in main FreeCAD.app
add_custom_target(create_bundle_dirs ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory ${EXTENSIONS_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${THUMBNAIL_EXT_DIR}/Contents/MacOS
    COMMAND ${CMAKE_COMMAND} -E make_directory ${THUMBNAIL_EXT_DIR}/Contents/Resources
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PREVIEW_EXT_DIR}/Contents/MacOS
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PREVIEW_EXT_DIR}/Contents/Resources
    COMMENT "Creating extensions directory in main FreeCAD.app and local build directories"
)

# Ensure extensions are built after main FreeCAD app if it's available as a target
if(TARGET FreeCAD)
    add_dependencies(create_bundle_dirs FreeCAD)
endif()

# Process Info.plist files
process_plist(
    "${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtensionInfo.plist"
    "${THUMBNAIL_EXT_DIR}/Contents/Info.plist"
    ${THUMBNAIL_BUNDLE_ID}
    "FreeCADThumbnailExtension"
    "FreeCADThumbnailExtension"
    "FreeCADThumbnailExtension.ThumbnailProvider"
)

process_plist(
    "${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtensionInfo.plist"
    "${PREVIEW_EXT_DIR}/Contents/Info.plist"
    ${PREVIEW_BUNDLE_ID}
    "FreeCADPreviewExtension"
    "FreeCADPreviewExtension"
    "FreeCADPreviewExtension.PreviewProvider"
)

# Compile Thumbnail Extension
add_custom_target(compile_thumbnail_extension ALL
    COMMAND ${SWIFTC_EXECUTABLE}
        ${SWIFT_FLAGS}
        -emit-executable
        -module-name FreeCADThumbnailExtension
        -parse-as-library
        -Xlinker -e -Xlinker _NSExtensionMain
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks
        -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks
        -framework Foundation
        -framework CoreGraphics
        -framework ImageIO
        -framework QuickLookThumbnailing
        -framework AppKit
        -lcompression
        -o ${THUMBNAIL_EXT_DIR}/Contents/MacOS/FreeCADThumbnailExtension
        ${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailProvider.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/ZipExtractor.swift
    DEPENDS
        create_bundle_dirs
        ${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailProvider.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/ZipExtractor.swift
        ${THUMBNAIL_EXT_DIR}/Contents/Info.plist
    COMMENT "Compiling Thumbnail Extension"
)

# Compile Preview Extension
add_custom_target(compile_preview_extension ALL
    COMMAND ${SWIFTC_EXECUTABLE}
        ${SWIFT_FLAGS}
        -emit-executable
        -module-name FreeCADPreviewExtension
        -parse-as-library
        -Xlinker -e -Xlinker _NSExtensionMain
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks
        -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks
        -framework Foundation
        -framework CoreGraphics
        -framework ImageIO
        -framework Quartz
        -framework Cocoa
        -framework UniformTypeIdentifiers
        -lcompression
        -o ${PREVIEW_EXT_DIR}/Contents/MacOS/FreeCADPreviewExtension
        ${CMAKE_CURRENT_SOURCE_DIR}/PreviewProvider.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/ZipExtractor.swift
    DEPENDS
        create_bundle_dirs
        ${CMAKE_CURRENT_SOURCE_DIR}/PreviewProvider.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/ZipExtractor.swift
        ${PREVIEW_EXT_DIR}/Contents/Info.plist
    COMMENT "Compiling Preview Extension"
)

# Sign Thumbnail Extension
# Embed unsigned extensions in main FreeCAD.app
add_custom_target(embed_extensions_in_freecad ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${THUMBNAIL_EXT_DIR}
        ${EXTENSIONS_DIR}/FreeCADThumbnailExtension.appex
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${PREVIEW_EXT_DIR}
        ${EXTENSIONS_DIR}/FreeCADPreviewExtension.appex
    DEPENDS
        compile_thumbnail_extension
        compile_preview_extension
    COMMENT "Embedding unsigned extensions in main FreeCAD.app"
)

# Main target that builds everything
add_custom_target(FreeCADQuickLook ALL
    DEPENDS embed_extensions_in_freecad
    COMMENT "FreeCAD QuickLook extensions integrated into main app"
)

# Install targets for QuickLook extensions
# Extensions are installed as part of the main app bundle, so we install from the signed app
install(DIRECTORY ${EXTENSIONS_DIR}/FreeCADThumbnailExtension.appex
    DESTINATION "${CMAKE_INSTALL_PREFIX}/PlugIns"
    COMPONENT QuickLook
    USE_SOURCE_PERMISSIONS
)

install(DIRECTORY ${EXTENSIONS_DIR}/FreeCADPreviewExtension.appex
    DESTINATION "${CMAKE_INSTALL_PREFIX}/PlugIns"
    COMPONENT QuickLook
    USE_SOURCE_PERMISSIONS
)

# Post-install signing handled by main MacAppBundle/CMakeLists.txt using AppSigning component
# This ensures signing runs after bundle fixup and all file installations

# Status messages
message(STATUS "FreeCAD QuickLook Production Integration Configuration:")
message(STATUS "  Generator: ${CMAKE_GENERATOR}")
message(STATUS "  Swift Compiler: ${SWIFTC_EXECUTABLE}")
message(STATUS "  Code Sign Tool: ${CODESIGN_EXECUTABLE}")
message(STATUS "  macOS SDK: ${MACOS_SDK_PATH}")
message(STATUS "  Target Architecture: ${TARGET_ARCH}")
message(STATUS "  Target: ${CMAKE_SYSTEM_NAME} ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "  FreeCAD Bundle ID: ${FREECAD_BUNDLE_ID}")
message(STATUS "  Thumbnail Bundle ID: ${THUMBNAIL_BUNDLE_ID}")
message(STATUS "  Preview Bundle ID: ${PREVIEW_BUNDLE_ID}")
message(STATUS "  Target FreeCAD.app: ${TARGET_APP_BUNDLE}")
message(STATUS "  Extensions Directory: ${EXTENSIONS_DIR}")
message(STATUS "  Signing Identity: ${SIGNING_IDENTITY}")
message(STATUS "  Production Signing: ${FREECAD_QUICKLOOK_USE_PRODUCTION_SIGNING}")

# Verification target for testing
add_custom_target(verify_build
    COMMAND test -f ${EXTENSIONS_DIR}/FreeCADThumbnailExtension.appex/Contents/MacOS/FreeCADThumbnailExtension
    COMMAND test -f ${EXTENSIONS_DIR}/FreeCADPreviewExtension.appex/Contents/MacOS/FreeCADPreviewExtension
    COMMAND echo "Extensions successfully embedded in FreeCAD.app"
    DEPENDS FreeCADQuickLook
    COMMENT "Verifying QuickLook extension integration"
)

# Test registration target (for development testing)
add_custom_target(test_registration
    COMMAND pluginkit -a ${EXTENSIONS_DIR}/FreeCADThumbnailExtension.appex
    COMMAND pluginkit -a ${EXTENSIONS_DIR}/FreeCADPreviewExtension.appex
    COMMAND pluginkit -e use -i ${THUMBNAIL_BUNDLE_ID}
    COMMAND pluginkit -e use -i ${PREVIEW_BUNDLE_ID}
    COMMAND pluginkit -m -v -i ${THUMBNAIL_BUNDLE_ID} || echo "Thumbnail extension registration status unknown"
    COMMAND pluginkit -m -v -i ${PREVIEW_BUNDLE_ID} || echo "Preview extension registration status unknown"
    DEPENDS FreeCADQuickLook
    COMMENT "Testing QuickLook extension registration"
)

else()
    # For Xcode generator, create placeholder targets
    message(STATUS "QuickLook extensions will use legacy Xcode-based build (if available)")
    add_custom_target(FreeCADQuickLook
        COMMAND ${CMAKE_COMMAND} -E echo "QuickLook extensions require Unix Makefiles generator for this implementation"
        COMMENT "QuickLook placeholder target"
    )
endif()
