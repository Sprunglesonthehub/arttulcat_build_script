#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting Arttulcat build script..."

# The workflow's 'Checkout code' step already clones the repository
# where this build.sh script resides.
# We need to clone arttulcat_browser into this workspace.

echo "Cloning main browser repository: arttulcat_browser..."
git clone https://github.com/Sprunglesonthehub/arttulcat_browser.git

# Navigate into the main browser repository
cd arttulcat_browser

# Step 1: Clone branding repository and move branding assets
echo "Cloning and moving branding assets..."
cd browser/branding/
git clone https://github.com/Sprunglesonthehub/arttulcat_branding.git
cd arttulcat_branding
mv arttulcat/ ../ # Moves 'arttulcat' directory from arttulcat_branding to browser/branding/
cd ../
rm -rf arttulcat_branding
cd ../../ # Go back to the root of arttulcat_browser (which is now in the workspace)

# Step 2: Clone configs repository and move .mozconfig
echo "Cloning and moving .mozconfig..."
git clone https://github.com/Sprunglesonthehub/arttulcat_configs.git
cd arttulcat_configs/mozconfig
mv .mozconfig ../../ # Move .mozconfig to the root of arttulcat_browser
cd ../../ # Go back to the root of arttulcat_browser
rm -rf arttulcat_configs

# Step 3: Set up build environment and build
echo "Running mach bootstrap, clobber, and build..."
./mach bootstrap
./mach clobber
./mach build

# Determine the platform for naming conventions
PLATFORM=""
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    CYGWIN*|MINGW32*|MSYS*|MINGW*) PLATFORM="windows";;
    *)          PLATFORM="unknown"
esac

# Create the release artifacts directory in the *original* workspace root
# So, first go back to the original workspace root where the build.sh script is
cd ..

mkdir -p release_artifacts

# Find the build output directory (e.g., arttulcat_browser/obj-x86_64-pc-linux-gnu)
# This finds the 'obj-*' directory directly within the cloned 'arttulcat_browser' directory
BUILD_DIR=$(find arttulcat_browser -maxdepth 1 -type d -name "obj-*" | head -n 1)

if [ -z "$BUILD_DIR" ]; then
    echo "Error: Could not find the build output directory (obj-*)."
    exit 1
fi

echo "Found build directory: $BUILD_DIR"

# Copy the final build artifact to release_artifacts with a standardized name
# This part is CRITICAL and needs to be adjusted based on the actual output of your 'mach build'
# For Firefox-based builds, 'mach package' or 'mach build installer' is often used to get final installers.
# If 'mach build' just creates the browser directory, you might need to tar/zip it.

case "$PLATFORM" in
    linux)
        # Assuming mach build creates a 'dist' directory with the browser executable/files
        # and you want to tar.gz it. Or if it creates a .deb/.rpm directly.
        if [ -d "$BUILD_DIR/dist/firefox" ]; then
            echo "Packaging Linux build to arttulcat.tar.gz..."
            tar -czf release_artifacts/arttulcat.tar.gz -C "$BUILD_DIR/dist" firefox/
            # If your build produces .deb or .rpm, uncomment and adjust:
            # cp "$BUILD_DIR/dist/arttulcat.deb" release_artifacts/arttulcat.deb || true
            # cp "$BUILD_DIR/dist/arttulcat.rpm" release_artifacts/arttulcat.rpm || true
        else
            echo "Warning: Linux build output not found in expected locations ($BUILD_DIR/dist/firefox). Attempting generic copy of dist directory."
            cp -r "$BUILD_DIR/dist/"* release_artifacts/ || true # Copy all, allow failure if empty
        fi
        ;;
    macos)
        if [ -d "$BUILD_DIR/dist/Firefox.app" ]; then
            echo "Packaging macOS build to arttulcat.dmg..."
            # Basic DMG creation. For a robust browser, consider a more advanced script or 'mach package'.
            DMG_NAME="arttulcat.dmg"
            APP_PATH="$BUILD_DIR/dist/Firefox.app"
            TEMP_DMG="temp.dmg"
            FINAL_DMG="release_artifacts/$DMG_NAME"

            # Create a temporary disk image
            hdiutil create -ov -fs HFS+ -volname "Arttulcat" -size 500m "$TEMP_DMG" # Increased size
            # Mount the image
            MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | grep -o '/Volumes/Arttulcat')
            # Copy the app
            cp -r "$APP_PATH" "$MOUNT_POINT/"
            # Create a symlink to Applications (optional, common for DMGs)
            ln -s /Applications "$MOUNT_POINT/Applications"
            # Unmount
            hdiutil detach "$MOUNT_POINT"
            # Convert to a compressed, read-only DMG
            hdiutil convert "$TEMP_DMG" -format UDRW -o "$FINAL_DMG"
            rm "$TEMP_DMG"
            echo "Created DMG at $FINAL_DMG"
        else
            echo "Warning: macOS .app bundle not found in expected locations ($BUILD_DIR/dist/Firefox.app). Attempting generic copy of dist directory."
            cp -r "$BUILD_DIR/dist/"* release_artifacts/ || true # Copy all, allow failure if empty
        fi
        ;;
    windows)
        # Assuming mach build creates a 'dist' directory with the browser or an installer
        if [ -d "$BUILD_DIR/dist/firefox" ]; then
            echo "Packaging Windows build to arttulcat.zip..."
            # Use 7zip for compression on Windows runners
            # Ensure 7zip is available in PATH, or specify full path
            /c/Program\ Files/7-Zip/7z.exe a release_artifacts/arttulcat.zip "$BUILD_DIR/dist/firefox/*"
        elif [ -f "$BUILD_DIR/dist/arttulcat-installer.exe" ]; then # Example if mach creates an installer
            echo "Copying Windows installer to arttulcat.exe..."
            cp "$BUILD_DIR/dist/arttulcat-installer.exe" release_artifacts/arttulcat.exe
        else
            echo "Warning: Windows build output not found in expected locations. Attempting generic copy of dist directory."
            cp -r "$BUILD_DIR/dist/"* release_artifacts/ || true # Copy all, allow failure if empty
        fi
        ;;
    *)
        echo "Unknown platform: $PLATFORM. Attempting generic copy of dist directory."
        if [ -d "$BUILD_DIR/dist" ]; then
            cp -r "$BUILD_DIR/dist/"* release_artifacts/ || true
        else
            echo "Error: Could not find '$BUILD_DIR/dist' for unknown platform. Manual intervention needed."
            exit 1
        fi
        ;;
esac

echo "Arttulcat build script finished."
