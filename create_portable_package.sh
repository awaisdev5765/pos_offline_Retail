#!/bin/bash

echo "Creating portable package for Windows build..."
echo "=============================================="

# Create a clean package directory
PACKAGE_DIR="offline_pos_windows_package"
echo "Creating package directory: $PACKAGE_DIR"

# Remove existing package if it exists
if [ -d "$PACKAGE_DIR" ]; then
    rm -rf "$PACKAGE_DIR"
fi

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy essential files
echo "Copying project files..."
cp -r lib "$PACKAGE_DIR/"
cp -r assets "$PACKAGE_DIR/" 2>/dev/null || echo "No assets directory found"
cp pubspec.yaml "$PACKAGE_DIR/"
cp pubspec.lock "$PACKAGE_DIR/" 2>/dev/null || echo "No pubspec.lock found"
cp analysis_options.yaml "$PACKAGE_DIR/" 2>/dev/null || echo "No analysis_options.yaml found"

# Copy build scripts
cp build_windows.bat "$PACKAGE_DIR/"
cp WINDOWS_BUILD_INSTRUCTIONS.md "$PACKAGE_DIR/"

# Create a README for the package
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# Offline POS System - Windows Build Package

This package contains all the necessary files to build the Offline POS System for Windows.

## Quick Start

1. **Install Prerequisites:**
   - Flutter SDK (https://flutter.dev/docs/get-started/install/windows)
   - Visual Studio 2022 with C++ workload
   - Git for Windows

2. **Build the Application:**
   - Double-click `build_windows.bat` to automatically build
   - Or follow the detailed instructions in `WINDOWS_BUILD_INSTRUCTIONS.md`

3. **Run the Application:**
   - After build, find the executable at: `build\windows\x64\runner\Release\offline_pos_system.exe`

## Features

- Complete POS system with inventory management
- Customer and supplier management with payment tracking
- Banking system with enhanced delete functionality
- Professional UI with confirmation dialogs
- SQLite database for offline operation

## Support

If you encounter issues, check `WINDOWS_BUILD_INSTRUCTIONS.md` for troubleshooting steps.
EOF

# Create a zip file
echo "Creating zip package..."
zip -r "offline_pos_windows_package.zip" "$PACKAGE_DIR"

echo ""
echo "✅ Package created successfully!"
echo ""
echo "📦 Package location: offline_pos_windows_package.zip"
echo "📁 Unpacked directory: $PACKAGE_DIR"
echo ""
echo "To transfer to Windows:"
echo "1. Copy 'offline_pos_windows_package.zip' to your Windows 10 laptop"
echo "2. Extract the zip file"
echo "3. Follow the instructions in WINDOWS_BUILD_INSTRUCTIONS.md"
echo "4. Run build_windows.bat to build the application"
echo ""
echo "The built application will be at: build\\windows\\x64\\runner\\Release\\offline_pos_system.exe"
