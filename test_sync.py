#!/usr/bin/env python3
"""
Test script to verify file structure and sync logic
"""

import json
from pathlib import Path

def test_file_structure():
    """Test that all files are in the correct locations"""
    flow_dir = Path("flow")
    accounts_dir = flow_dir / "accounts"
    pkeys_dir = accounts_dir / "pkeys"
    production_file = accounts_dir / "flow-production.json"
    
    print("🔍 Testing file structure...")
    
    # Check directories exist
    if not flow_dir.exists():
        print("❌ flow/ directory not found")
        return False
    
    if not accounts_dir.exists():
        print("❌ flow/accounts/ directory not found")
        return False
    
    if not pkeys_dir.exists():
        print("❌ flow/accounts/pkeys/ directory not found")
        return False
    
    if not production_file.exists():
        print("❌ flow-production.json not found")
        return False
    
    print("✅ All directories exist")
    
    # Count pkey files
    pkey_files = list(pkeys_dir.glob("*.pkey"))
    print(f"📊 Found {len(pkey_files)} pkey files in pkeys/ directory")
    
    # Load and validate production config
    try:
        with open(production_file, 'r') as f:
            config = json.load(f)
        
        accounts = config.get('accounts', {})
        print(f"📊 Found {len(accounts)} accounts in flow-production.json")
        
        # Check that all pkey files are referenced correctly
        missing_refs = 0
        for auth_id, account_data in accounts.items():
            location = account_data.get('key', {}).get('location', '')
            if not location.startswith('pkeys/'):
                print(f"⚠️  Account {auth_id} has incorrect location: {location}")
                missing_refs += 1
            elif not (pkeys_dir / location.replace('pkeys/', '')).exists():
                print(f"⚠️  Account {auth_id} references missing pkey file: {location}")
                missing_refs += 1
        
        if missing_refs == 0:
            print("✅ All pkey file references are correct")
        else:
            print(f"⚠️  Found {missing_refs} issues with pkey file references")
        
        return missing_refs == 0
        
    except Exception as e:
        print(f"❌ Error loading flow-production.json: {e}")
        return False

def main():
    print("🧪 Testing wallet sync file structure...")
    success = test_file_structure()
    
    if success:
        print("\n🎉 File structure test passed!")
        print("The syncWallets.py script should work correctly when database is available.")
    else:
        print("\n❌ File structure test failed!")
        print("Please fix the issues before running syncWallets.py")

if __name__ == "__main__":
    main()

