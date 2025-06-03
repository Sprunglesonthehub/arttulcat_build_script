#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting Arttulcat build script (macOS ONLY)..."

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
echo "Cloning configs repository..."
git clone https://github.com/Sprunglesonthehub/arttulcat_configs.git

cd arttulcat_configs/mozconfig
TARGET_MOZCONFIG_NAME=".mozconfig" # The name mach expects
SOURCE_MOZCONFIG_FILE=""

# For macOS, you should specifically look for a macOS-compatible .mozconfig
# or ensure the generic one is suitable.
if [ -f "mozconfig.macos" ]; then
    SOURCE_MOZCONFIG_FILE="mozconfig.macos"
    echo "Found 'mozconfig.macos', using it."
elif [ -f ".mozconfig" ]; then
    SOURCE_MOZCONFIG_FILE=".mozconfig"
    echo "Found generic '.mozconfig', using it. Ensure it's macOS-compatible."
else
    echo "Error: No suitable .mozconfig or mozconfig.macos found in arttulcat_configs/mozconfig/"
    exit 1
fi

mv "$SOURCE_MOZCONFIG_FILE" "../../$TARGET_MOZCONFIG_NAME" # Move to arttulcat_browser root as .mozconfig
cd ../../ # Go back to the root of arttulcat_browser
rm -rf arttulcat_configs

# Step 3: Set up build environment and build
echo "Running mach bootstrap, clobber, and build..."
# For macOS, mach bootstrap might require Xcode Command Line Tools.
# Ensure they are installed on your buildarttulcatformacos runner machine.
./mach bootstrap
./mach clobber
./mach build

# Create the release artifacts directory in the *original* workspace root
cd .. # Go back to the original workspace root where build.sh is

mkdir -p release_artifacts

# Find the build output directory (e.g., arttulcat_browser/obj-x86_64-apple-darwin)
BUILD_DIR=$(find arttulcat_browser -maxdepth 1 -type d -name "obj-*" | head -n 1)

if [ -z "$BUILD_DIR" ]; then
    echo "Error: Could not find the build output directory (obj-*)."
    exit 1
fi
echo "Found build directory: $BUILD_DIR"
DIST_DIR="$BUILD_DIR/dist"

echo "Packaging macOS artifacts..."

# --- macOS DMG Creation ---
# This part assumes your 'mach build' creates the .app bundle in $DIST_DIR/Arttulcat.app
# You'll need `hdiutil` which is available on macOS.

APP_NAME="Arttulcat" # Adjust if your .app bundle has a different name
APP_BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
DMG_NAME="Arttulcat-macOS-$(date +%Y%m%d%H%M%S).dmg" # Dynamic DMG name

if [ -d "$APP_BUNDLE_PATH" ]; then
    echo "Creating .dmg image for $APP_NAME.app..."

    # Define a temporary volume name for the DMG
    VOLUME_NAME="Arttulcat Installer"

    # Create a temporary read/write disk image
    hdiutil create -ov -volname "$VOLUME_NAME" -fs HFS+ -size 500m -layout SPUD -o "$DMG_NAME"
    # Attach the disk image
    MOUNT_POINT=$(hdiutil attach "$DMG_NAME" | grep "disk" | sed 's/.*\/Volumes\/\(.*\)/\1/')
    echo "Mounted DMG at /Volumes/$MOUNT_POINT"

    # Copy the application bundle to the mounted DMG
    cp -R "$APP_BUNDLE_PATH" "/Volumes/$MOUNT_POINT/"

    # Create a symlink to Applications folder
    ln -s /Applications "/Volumes/$MOUNT_POINT/Applications"

    # Set DMG background (optional, requires a .png file)
    # cp /path/to/your/dmg_background.png "/Volumes/$MOUNT_POINT/.background.png"
    # Add a .DS_Store file for custom icon positions if desired
    # (This is more advanced and often managed by build tools or specific scripts)

    # Unmount the disk image
    hdiutil detach "/Volumes/$MOUNT_POINT"

    # Convert the disk image to a compressed, read-only .dmg
    hdiutil convert "$DMG_NAME" -format UDZO -o "release_artifacts/$DMG_NAME" -reserve -ov

    # Clean up the temporary .dmg
    rm "$DMG_NAME"

    echo "Created release_artifacts/$DMG_NAME"
else
    echo "Error: macOS application bundle ($APP_BUNDLE_PATH) not found for DMG creation."
    exit 1
fi

echo "Arttulcat build script (macOS ONLY) finished."
