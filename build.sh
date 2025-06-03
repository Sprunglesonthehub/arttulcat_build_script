#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting Arttulcat build script (Linux ONLY)..."

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

# --- START MODIFICATION for .mozconfig ---
# This section assumes you might create platform-specific mozconfigs
# For a Linux-only build, you might just ensure the one in arttulcat_configs/mozconfig/.mozconfig is Linux-compatible
# or specifically copy a 'mozconfig.linux' if you adopt that strategy.

cd arttulcat_configs/mozconfig
TARGET_MOZCONFIG_NAME=".mozconfig" # The name mach expects
SOURCE_MOZCONFIG_FILE=""

if [ -f "mozconfig.linux" ]; then
    SOURCE_MOZCONFIG_FILE="mozconfig.linux"
    echo "Found 'mozconfig.linux', using it."
elif [ -f ".mozconfig" ]; then
    SOURCE_MOZCONFIG_FILE=".mozconfig"
    echo "Found generic '.mozconfig', using it. Ensure it's Linux-compatible."
else
    echo "Error: No suitable .mozconfig or mozconfig.linux found in arttulcat_configs/mozconfig/"
    exit 1
fi

mv "$SOURCE_MOZCONFIG_FILE" "../../$TARGET_MOZCONFIG_NAME" # Move to arttulcat_browser root as .mozconfig
cd ../../ # Go back to the root of arttulcat_browser
rm -rf arttulcat_configs
# --- END MODIFICATION for .mozconfig ---


# Step 3: Set up build environment and build
echo "Running mach bootstrap, clobber, and build..."
./mach bootstrap # This must succeed. The '/msys/bin/sh' error happens here if .mozconfig is wrong.
./mach clobber
./mach build

# Create the release artifacts directory in the *original* workspace root
cd .. # Go back to the original workspace root where build.sh is

mkdir -p release_artifacts

# Find the build output directory (e.g., arttulcat_browser/obj-x86_64-pc-linux-gnu)
BUILD_DIR=$(find arttulcat_browser -maxdepth 1 -type d -name "obj-*" | head -n 1)

if [ -z "$BUILD_DIR" ]; then
    echo "Error: Could not find the build output directory (obj-*)."
    exit 1
fi
echo "Found build directory: $BUILD_DIR"
DIST_DIR="$BUILD_DIR/dist"

echo "Packaging Linux artifacts..."

# Package the main browser directory as tar.gz
if [ -d "$DIST_DIR/firefox" ]; then
    echo "Packaging Linux browser directory to arttulcat.tar.gz..."
    tar -czf release_artifacts/arttulcat.tar.gz -C "$DIST_DIR" firefox/
    echo "Created arttulcat.tar.gz"
else
    echo "Warning: Linux browser directory not found in $DIST_DIR/firefox for tar.gz packaging."
fi

# Copy .deb package if it exists
DEB_FILE_PATTERN="$DIST_DIR/arttulcat*.deb" # Adjust pattern if necessary
DEB_FILES=( $DEB_FILE_PATTERN )
if [ -f "${DEB_FILES[0]}" ]; then
    echo "Copying Linux .deb package(s) from $DIST_DIR..."
    # Use cp with the pattern to copy all matching files
    cp $DEB_FILE_PATTERN release_artifacts/
    echo "Copied .deb package(s) to release_artifacts/"
else
    echo "Warning: No .deb package found matching '$DEB_FILE_PATTERN' in $DIST_DIR. Ensure ./mach build/package creates it."
fi

# Copy .rpm package if it exists
RPM_FILE_PATTERN="$DIST_DIR/arttulcat*.rpm" # Adjust pattern if necessary
RPM_FILES=( $RPM_FILE_PATTERN )
if [ -f "${RPM_FILES[0]}" ]; then
    echo "Copying Linux .rpm package(s) from $DIST_DIR..."
    # Use cp with the pattern to copy all matching files
    cp $RPM_FILE_PATTERN release_artifacts/
    echo "Copied .rpm package(s) to release_artifacts/"
else
    echo "Warning: No .rpm package found matching '$RPM_FILE_PATTERN' in $DIST_DIR. Ensure ./mach build/package creates it."
fi

echo "Arttulcat build script (Linux ONLY) finished."
