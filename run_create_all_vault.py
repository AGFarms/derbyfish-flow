#!/usr/bin/env python3
"""
Script to run the createAllVault Flow transaction
"""

import subprocess
import sys
from pathlib import Path

def run_create_all_vault():
    """Run the createAllVault Flow transaction"""
    
    # Flow command to execute
    cmd = [
        "/home/mattricks/.local/bin/flow",
        "transactions",
        "send",
        "cadence/transactions/createAllVault.cdc",
        "0x823640ec5e100cc4",
        "--proposer", "derbyfish",
        "--authorizer", "derbyfish", 
        "--payer", "mainnet-agfarms",
        "--network", "mainnet"
    ]
    
    # Set working directory to flow folder
    flow_dir = Path("flow")
    
    print("🚀 Running createAllVault transaction...")
    print(f"Command: {' '.join(cmd)}")
    print(f"Working directory: {flow_dir.absolute()}")
    
    try:
        # Run the command
        result = subprocess.run(
            cmd,
            cwd=flow_dir,
            capture_output=True,
            text=True,
            timeout=120  # 2 minute timeout
        )
        
        # Print results
        print(f"\n📊 Return code: {result.returncode}")
        
        if result.stdout:
            print(f"\n📤 STDOUT:\n{result.stdout}")
        
        if result.stderr:
            print(f"\n📥 STDERR:\n{result.stderr}")
        
        if result.returncode == 0:
            print("\n✅ Transaction completed successfully!")
        else:
            print("\n❌ Transaction failed!")
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("\n⏰ Transaction timed out after 2 minutes")
        return False
    except Exception as e:
        print(f"\n❌ Error running transaction: {e}")
        return False

def main():
    """Main function"""
    print("🎣 DerbyFish Flow Transaction Runner")
    print("=" * 50)
    
    # Check if flow directory exists
    flow_dir = Path("flow")
    if not flow_dir.exists():
        print("❌ Error: flow directory not found")
        print("Please run this script from the project root directory")
        sys.exit(1)
    
    # Run the transaction
    success = run_create_all_vault()
    
    if success:
        print("\n🎉 Transaction executed successfully!")
        sys.exit(0)
    else:
        print("\n💥 Transaction failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
