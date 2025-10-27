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

# Bundle identifiers
set(HOST_BUNDLE_ID "org.freecad.FreeCAD.quicklook.host")
set(THUMBNAIL_BUNDLE_ID "org.freecad.FreeCAD.quicklook.thumbnail")
set(PREVIEW_BUNDLE_ID "org.freecad.FreeCAD.quicklook.preview")

# Output directories
set(BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(HOST_APP_DIR "${BUILD_DIR}/FreeCADQuickLookHost.app")
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

# Function to process Info.plist files
function(process_plist input_plist output_plist bundle_id executable_name product_name principal_class)
    add_custom_command(
        OUTPUT ${output_plist}
        COMMAND ${CMAKE_COMMAND} -E copy ${input_plist} ${output_plist}
        COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleIdentifier -string ${bundle_id} ${output_plist}
        COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleExecutable -string ${executable_name} ${output_plist}
        COMMAND ${PLUTIL_EXECUTABLE} -replace CFBundleName -string ${product_name} ${output_plist}
        COMMAND ${CMAKE_COMMAND} -E env bash -c "if [ ! -z '${principal_class}' ]\; then ${PLUTIL_EXECUTABLE} -replace 'NSExtension.NSExtensionPrincipalClass' -string '${principal_class}' '${output_plist}'\; fi"
        DEPENDS ${input_plist}
        COMMENT "Processing ${input_plist} -> ${output_plist}"
    )
endfunction()

# Create bundle directory structure
add_custom_target(create_bundle_dirs ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory ${HOST_APP_DIR}/Contents/MacOS
    COMMAND ${CMAKE_COMMAND} -E make_directory ${HOST_APP_DIR}/Contents/PlugIns
    COMMAND ${CMAKE_COMMAND} -E make_directory ${HOST_APP_DIR}/Contents/Resources
    COMMAND ${CMAKE_COMMAND} -E make_directory ${THUMBNAIL_EXT_DIR}/Contents/MacOS
    COMMAND ${CMAKE_COMMAND} -E make_directory ${THUMBNAIL_EXT_DIR}/Contents/Resources
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PREVIEW_EXT_DIR}/Contents/MacOS
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PREVIEW_EXT_DIR}/Contents/Resources
    COMMENT "Creating bundle directory structures"
)

# Process Info.plist files
process_plist(
    "${CMAKE_CURRENT_SOURCE_DIR}/FreeCADQuickLookHostInfo.plist"
    "${HOST_APP_DIR}/Contents/Info.plist"
    ${HOST_BUNDLE_ID}
    "FreeCADQuickLookHost"
    "FreeCADQuickLookHost"
    ""
)

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

# Compile Host App
add_custom_target(compile_host_app ALL
    COMMAND ${SWIFTC_EXECUTABLE}
        ${SWIFT_FLAGS}
        -module-name FreeCADQuickLookHost
        -emit-executable
        -parse-as-library
        -framework Foundation
        -framework AppKit
        -o ${HOST_APP_DIR}/Contents/MacOS/FreeCADQuickLookHost
        ${CMAKE_CURRENT_SOURCE_DIR}/FreeCADQuickLookHostApp.swift
    DEPENDS
        create_bundle_dirs
        ${CMAKE_CURRENT_SOURCE_DIR}/FreeCADQuickLookHostApp.swift
        ${HOST_APP_DIR}/Contents/Info.plist
    COMMENT "Compiling Host App"
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

# Code signing function
function(add_codesign_target target_name bundle_path entitlements_file)
    add_custom_target(sign_${target_name} ALL
        COMMAND ${CODESIGN_EXECUTABLE}
            --force
            --sign "-"
            --entitlements ${entitlements_file}
            --deep
            ${bundle_path}
        DEPENDS compile_${target_name}
        COMMENT "Code signing ${target_name}"
    )
endfunction()



# Code signing with entitlements using ad-hoc signing (like working version)
add_custom_target(sign_preview_extension ALL
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtension.entitlements
        --deep
        ${PREVIEW_EXT_DIR}
    DEPENDS compile_preview_extension
    COMMENT "Code signing preview extension with entitlements using ad-hoc signing"
)

# Sign the extensions (thumbnail with entitlements like working version)
add_custom_target(sign_thumbnail_extension ALL
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtension.entitlements
        --deep
        ${THUMBNAIL_EXT_DIR}
    DEPENDS compile_thumbnail_extension
    COMMENT "Code signing thumbnail extension with entitlements using ad-hoc signing"
)

# Preview extension signing is handled above

# Create host app entitlements (if not exists)
set(HOST_ENTITLEMENTS "${CMAKE_CURRENT_BINARY_DIR}/HostApp.entitlements")
add_custom_command(
    OUTPUT ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '<?xml version="1.0" encoding="UTF-8"?>' > ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '<plist version="1.0">' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '<dict>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '    <key>com.apple.security.app-sandbox</key>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '    <true/>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '    <key>com.apple.security.files.user-selected.read-only</key>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '    <true/>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '</dict>' >> ${HOST_ENTITLEMENTS}
    COMMAND ${CMAKE_COMMAND} -E echo '</plist>' >> ${HOST_ENTITLEMENTS}
    COMMENT "Generating host app entitlements"
)

# Sign host app
add_custom_target(sign_host_app ALL
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${HOST_ENTITLEMENTS}
        --deep
        ${HOST_APP_DIR}
    DEPENDS
        compile_host_app
        ${HOST_ENTITLEMENTS}
        sign_thumbnail_extension
        sign_preview_extension
    COMMENT "Code signing Host App"
)

# Embed extensions in host app
add_custom_target(embed_extensions ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${THUMBNAIL_EXT_DIR}
        ${HOST_APP_DIR}/Contents/PlugIns/FreeCADThumbnailExtension.appex
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${PREVIEW_EXT_DIR}
        ${HOST_APP_DIR}/Contents/PlugIns/FreeCADPreviewExtension.appex
    DEPENDS
        sign_host_app
    COMMENT "Embedding extensions in host app"
)

# Re-sign extensions after embedding to ensure entitlements are preserved
add_custom_target(resign_embedded_extensions ALL
    COMMAND ${CMAKE_COMMAND} -E echo "Re-signing embedded extensions with identity-aware approach..."
    DEPENDS embed_extensions
    COMMENT "Re-signing embedded extensions (thumbnail without entitlements, preview with entitlements if identity available)"
)

# Re-sign embedded extensions with ad-hoc signing (like working version)
add_custom_command(TARGET resign_embedded_extensions POST_BUILD
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtension.entitlements
        --deep
        ${HOST_APP_DIR}/Contents/PlugIns/FreeCADThumbnailExtension.appex
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtension.entitlements
        --deep
        ${HOST_APP_DIR}/Contents/PlugIns/FreeCADPreviewExtension.appex
    COMMENT "Re-signing embedded extensions with ad-hoc signing and entitlements"
)

# Final signing of the complete bundle (without --deep to preserve extension signatures)
add_custom_target(final_sign ALL
    COMMAND ${CODESIGN_EXECUTABLE}
        --force
        --sign "-"
        --entitlements ${HOST_ENTITLEMENTS}
        ${HOST_APP_DIR}
    DEPENDS resign_embedded_extensions
    COMMENT "Final code signing of host app only (preserving extension signatures)"
)

# Create registration script from template
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/register_quicklook.sh.in
    ${BUILD_DIR}/register_quicklook.sh
    @ONLY
)

add_custom_target(create_registration_script ALL
    COMMAND chmod +x ${BUILD_DIR}/register_quicklook.sh
    DEPENDS final_sign
    COMMENT "Creating QuickLook registration script"
)

# Main target that builds everything
add_custom_target(FreeCADQuickLook ALL
    DEPENDS create_registration_script
    COMMENT "FreeCAD QuickLook extensions build complete"
)

# Install targets
install(DIRECTORY ${HOST_APP_DIR}
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook"
    COMPONENT QuickLook
    USE_SOURCE_PERMISSIONS
)

install(PROGRAMS ${BUILD_DIR}/register_quicklook.sh
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Contents/Resources"
    COMPONENT QuickLook
)

# Status messages
message(STATUS "FreeCAD QuickLook Unix Makefile Configuration:")
message(STATUS "  Generator: ${CMAKE_GENERATOR}")
message(STATUS "  Swift Compiler: ${SWIFTC_EXECUTABLE}")
message(STATUS "  Code Sign Tool: ${CODESIGN_EXECUTABLE}")
message(STATUS "  macOS SDK: ${MACOS_SDK_PATH}")
message(STATUS "  Target Architecture: ${TARGET_ARCH}")
message(STATUS "  Target: ${CMAKE_SYSTEM_NAME} ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "  Host Bundle ID: ${HOST_BUNDLE_ID}")
message(STATUS "  Thumbnail Bundle ID: ${THUMBNAIL_BUNDLE_ID}")
message(STATUS "  Preview Bundle ID: ${PREVIEW_BUNDLE_ID}")
message(STATUS "  Build Directory: ${BUILD_DIR}")
message(STATUS "  Install Path: \${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook/")

# Verification target for testing
add_custom_target(verify_build
    COMMAND test -f ${HOST_APP_DIR}/Contents/MacOS/FreeCADQuickLookHost
    COMMAND test -f ${HOST_APP_DIR}/Contents/PlugIns/FreeCADThumbnailExtension.appex/Contents/MacOS/FreeCADThumbnailExtension
    COMMAND test -f ${HOST_APP_DIR}/Contents/PlugIns/FreeCADPreviewExtension.appex/Contents/MacOS/FreeCADPreviewExtension
    COMMAND echo "All binaries built successfully"
    DEPENDS FreeCADQuickLook
    COMMENT "Verifying build completion"
)

# Test registration target
add_custom_target(test_registration
    COMMAND ${BUILD_DIR}/register_quicklook.sh
    COMMAND pluginkit -m -v -i ${THUMBNAIL_BUNDLE_ID} || echo "Thumbnail extension not found in registry"
    COMMAND pluginkit -m -v -i ${PREVIEW_BUNDLE_ID} || echo "Preview extension not found in registry"
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
