#!/usr/bin/env python3

"""
Prepare the helper tool for SMJobBless embedding.
This script sets up the proper structure for the helper tool to be embedded in the app.
"""

import os
import subprocess
import plistlib
import shutil

# Configuration
HELPER_ID = "com.lowdata.helper"
APP_ID = "com.tonalphoto.tech.LowData"
TEAM_ID = "85QL287QYW"
HELPER_SOURCE = "LowDataHelper/main.swift"
BUILD_DIR = "build"

def run_command(cmd):
    """Run a shell command and return output."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        exit(1)
    return result.stdout.strip()

def main():
    print("Preparing helper tool for SMJobBless...")
    
    # Create build directory
    os.makedirs(BUILD_DIR, exist_ok=True)
    
    # Build the helper
    print("Building helper tool...")
    run_command(f"swiftc {HELPER_SOURCE} -o {BUILD_DIR}/{HELPER_ID} -O")
    
    # Sign the helper
    print("Signing helper...")
    run_command(f'codesign --force --sign "Developer ID Application: Konrad Michels ({TEAM_ID})" '
                f'--identifier {HELPER_ID} --options runtime {BUILD_DIR}/{HELPER_ID}')
    
    # Create the LaunchServices directory structure
    helper_path = f"{BUILD_DIR}/{HELPER_ID}"
    
    # The helper needs to be in the app bundle at:
    # LowData.app/Contents/Library/LaunchServices/com.lowdata.helper
    
    print("\nHelper tool prepared successfully!")
    print(f"Helper location: {helper_path}")
    print("\nNext steps:")
    print("1. In Xcode, add a 'Copy Files' build phase")
    print("2. Set destination to 'Wrapper' with subpath 'Contents/Library/LaunchServices'")
    print(f"3. Add {helper_path} to this build phase")
    print("4. Build and run the app")
    print("\nThe app will use SMJobBless to install the helper to /Library/PrivilegedHelperTools/")

if __name__ == "__main__":
    main()