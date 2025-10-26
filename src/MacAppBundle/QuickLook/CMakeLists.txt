cmake_minimum_required(VERSION 3.22)
project(FreeCADQuickLookSwift)

# Enable Swift language support
enable_language(Swift)

# Swift compiler flags for consistency with Xcode defaults
set(CMAKE_Swift_FLAGS "")
set(CMAKE_Swift_FLAGS_DEBUG "-Onone -g")
set(CMAKE_Swift_FLAGS_RELEASE "-O -whole-module-optimization")
set(CMAKE_Swift_COMPILER_VERSION 5.0)

# Function to set common properties for both extensions
function(set_extension_properties target_name bundle_identifier)
    set_target_properties(${target_name} PROPERTIES
        BUNDLE TRUE
        BUNDLE_EXTENSION "appex"
        MACOSX_DEPLOYMENT_TARGET "15.0"
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_EXECUTABLE_NAME ${target_name}
        MACOSX_BUNDLE_BUNDLE_NAME "FreeCAD ${target_name} Extension"
        MACOSX_BUNDLE_GUI_IDENTIFIER ${bundle_identifier}
        # App Extension specific settings
        XCODE_ATTRIBUTE_APPLICATION_EXTENSION_API_ONLY "YES"
        XCODE_ATTRIBUTE_SKIP_INSTALL "YES"
        XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "YES"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
        "XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY[sdk=macosx*]" "-"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "YES"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
        XCODE_ATTRIBUTE_PRODUCT_TYPE "com.apple.product-type.app-extension"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER ${bundle_identifier}
        # Sandbox settings like FreeCADCompanion
        XCODE_ATTRIBUTE_ENABLE_APP_SANDBOX "YES"
        XCODE_ATTRIBUTE_ENABLE_USER_SELECTED_FILES "readonly"
        # Performance optimizations
        XCODE_ATTRIBUTE_SWIFT_OPTIMIZATION_LEVEL "-O"
    )
endfunction()

# Define the QuickLook Thumbnail Extension target
add_library(FreeCADThumbnailExtension MODULE
    ThumbnailProvider.swift
    ZipExtractor.swift
)

# Disable Qt automoc for Swift targets
set_target_properties(FreeCADThumbnailExtension PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

# Set common properties for Thumbnail Extension
set_extension_properties(FreeCADThumbnailExtension "org.freecad.FreeCAD.quicklook.thumbnail")

# Set specific properties for Thumbnail Extension
set_target_properties(FreeCADThumbnailExtension PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtensionInfo.plist"
    XCODE_ATTRIBUTE_INFOPLIST_FILE "${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtensionInfo.plist"
    CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtension.entitlements"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/ThumbnailExtension.entitlements"
    Swift_MODULE_NAME "FreeCADThumbnailExtension"
    Swift_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/swift_modules"
)

# Link required frameworks for Swift QuickLook extension
target_link_libraries(FreeCADThumbnailExtension
    "-framework Foundation"
    "-framework CoreGraphics"
    "-framework ImageIO"
    "-framework QuickLookThumbnailing"
    "-framework AppKit"
    "-lcompression"
)

# Set Swift language version
set_property(TARGET FreeCADThumbnailExtension PROPERTY Swift_LANGUAGE_VERSION 5.0)

# Define the QuickLook Preview Extension target
add_library(FreeCADPreviewExtension MODULE
    PreviewProvider.swift
    ZipExtractor.swift
)

# Disable Qt automoc for Swift targets
set_target_properties(FreeCADPreviewExtension PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

# Set common properties for Preview Extension
set_extension_properties(FreeCADPreviewExtension "org.freecad.FreeCAD.quicklook.preview")

# Set specific properties for Preview Extension
set_target_properties(FreeCADPreviewExtension PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtensionInfo.plist"
    XCODE_ATTRIBUTE_INFOPLIST_FILE "${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtensionInfo.plist"
    CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtension.entitlements"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/PreviewExtension.entitlements"
    Swift_MODULE_NAME "FreeCADPreviewExtension"
    Swift_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/swift_modules_preview"
)

# Link required frameworks for Swift Preview extension
target_link_libraries(FreeCADPreviewExtension
    "-framework Foundation"
    "-framework CoreGraphics"
    "-framework ImageIO"
    "-framework Quartz"
    "-framework Cocoa"
    "-framework UniformTypeIdentifiers"
    "-lcompression"
)

# Set Swift language version for Preview Extension
set_property(TARGET FreeCADPreviewExtension PROPERTY Swift_LANGUAGE_VERSION 5.0)

# Host app target (minimal container for FreeCAD integration)
add_executable(FreeCADQuickLookHost
    FreeCADQuickLookHostApp.swift
)

# Disable Qt automoc for Swift targets
set_target_properties(FreeCADQuickLookHost PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

set_target_properties(FreeCADQuickLookHost
    PROPERTIES
    BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/FreeCADQuickLookHostInfo.plist"
    MACOSX_DEPLOYMENT_TARGET "15.0"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_EXECUTABLE_NAME "FreeCADQuickLookHost"
    Swift_MODULE_NAME "FreeCADQuickLookHost"
    Swift_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/swift_modules_host"
    # Bundle identifier
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.freecad.FreeCAD.quicklook.host"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    "XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY[sdk=macosx*]" "-"
)

target_link_libraries(FreeCADQuickLookHost
    "-framework Foundation"
    "-framework AppKit"
)

# Embed the extension in the host app
# Embed extensions in host app
add_custom_command(TARGET FreeCADQuickLookHost POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_BUNDLE_DIR:FreeCADQuickLookHost>/Contents/PlugIns"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<TARGET_BUNDLE_DIR:FreeCADThumbnailExtension>"
        "$<TARGET_BUNDLE_DIR:FreeCADQuickLookHost>/Contents/PlugIns/FreeCADThumbnailExtension.appex"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<TARGET_BUNDLE_DIR:FreeCADPreviewExtension>"
        "$<TARGET_BUNDLE_DIR:FreeCADQuickLookHost>/Contents/PlugIns/FreeCADPreviewExtension.appex"
    COMMENT "Embedding QuickLook thumbnail and preview extensions in host app"
)

# Ensure the extensions are built before the host app
add_dependencies(FreeCADQuickLookHost FreeCADThumbnailExtension FreeCADPreviewExtension)

# Install QuickLook host app directly into FreeCAD.app bundle
install(TARGETS FreeCADQuickLookHost
    BUNDLE DESTINATION "${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook"
    COMPONENT QuickLook
)

# Install a registration script for post-install QuickLook registration
install(CODE "
    # Register QuickLook extensions with the system
    set(QUICKLOOK_HOST_PATH \"${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook/FreeCADQuickLookHost.app\")

    # Create a registration script that FreeCAD can call on first launch
    file(WRITE \"${CMAKE_INSTALL_PREFIX}/Contents/Resources/register_quicklook.sh\"
        \"#!/bin/bash\\n\"
        \"# FreeCAD QuickLook Registration Script\\n\"
        \"QUICKLOOK_HOST=\\\"${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook/FreeCADQuickLookHost.app\\\"\\n\"
        \"if [ -d \\\"\\$QUICKLOOK_HOST\\\" ]; then\\n\"
        \"    echo \\\"Registering FreeCAD QuickLook extensions...\\\"\\n\"
        \"    pluginkit -a \\\"\\$QUICKLOOK_HOST\\\" 2>/dev/null || true\\n\"
        \"    qlmanage -r 2>/dev/null || true\\n\"
        \"    echo \\\"FreeCAD QuickLook extensions registered.\\\"\\n\"
        \"else\\n\"
        \"    echo \\\"QuickLook host app not found at \\$QUICKLOOK_HOST\\\"\\n\"
        \"fi\\n\"
    )

    # Make the script executable
    execute_process(COMMAND chmod +x \"${CMAKE_INSTALL_PREFIX}/Contents/Resources/register_quicklook.sh\")

    message(STATUS \"FreeCAD QuickLook extensions installed to: \\${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook/FreeCADQuickLookHost.app\")
    message(STATUS \"Registration script created at: \\${CMAKE_INSTALL_PREFIX}/Contents/Resources/register_quicklook.sh\")
" COMPONENT QuickLook)

# Print build information
message(STATUS "FreeCAD Swift QuickLook Configuration:")
message(STATUS "  Integration Mode: Embedded in FreeCAD.app (Option 1)")
message(STATUS "  Swift Version: ${CMAKE_Swift_COMPILER_VERSION}")
message(STATUS "  Target: ${CMAKE_SYSTEM_NAME} ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Swift Flags: ${CMAKE_Swift_FLAGS}")
message(STATUS "  Extensions: Thumbnail + Preview (.appex)")
message(STATUS "  Pure Swift: No external dependencies")
message(STATUS "  Install Path: \${CMAKE_INSTALL_PREFIX}/Contents/Library/QuickLook/")
message(STATUS "  Bundle ID: org.freecad.FreeCAD.quicklook.host")

# Verify Swift compiler is available
if(NOT CMAKE_Swift_COMPILER)
    message(FATAL_ERROR "Swift compiler not found. Please install Xcode with Swift support.")
endif()

# Verify minimum deployment target
if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "15.0")
    message(WARNING "Swift QuickLook extensions require macOS 15.0+. Current target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()
