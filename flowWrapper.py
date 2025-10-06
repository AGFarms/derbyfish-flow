#!/usr/bin/env python3
"""
Flow CLI Wrapper

A production-ready wrapper for Flow CLI operations with:
- Standardized error handling and logging
- JSON output parsing
- Rate limiting and retry logic
- Comprehensive monitoring and metrics
- Thread-safe operations
"""

import subprocess
import json
import os
import sys
import time
import logging
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from enum import Enum
import functools

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FlowOperationType(Enum):
    SCRIPT = "script"
    TRANSACTION = "transaction"
    ACCOUNT = "account"
    BLOCK = "block"

class FlowNetwork(Enum):
    MAINNET = "mainnet"
    TESTNET = "testnet"
    EMULATOR = "emulator"

@dataclass
class FlowResult:
    """Standardized result from Flow CLI operations"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    raw_output: str = ""
    error_message: str = ""
    execution_time: float = 0.0
    command: str = ""
    network: str = ""
    operation_type: str = ""
    transaction_id: Optional[str] = None
    retry_count: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

@dataclass
class FlowConfig:
    """Configuration for Flow CLI operations"""
    network: FlowNetwork = FlowNetwork.MAINNET
    flow_dir: Path = Path("flow")
    timeout: int = 300  # 5 minutes
    max_retries: int = 3
    retry_delay: float = 1.0
    rate_limit_delay: float = 0.2  # 200ms between requests
    json_output: bool = True
    log_level: str = "INFO"

class FlowRateLimiter:
    """Thread-safe rate limiter for Flow CLI operations"""
    
    def __init__(self, delay: float = 0.2):
        self.delay = delay
        self.last_request_time = 0.0
        self.lock = threading.Lock()
    
    def wait_if_needed(self):
        """Wait if necessary to respect rate limits"""
        with self.lock:
            current_time = time.time()
            time_since_last = current_time - self.last_request_time
            
            if time_since_last < self.delay:
                sleep_time = self.delay - time_since_last
                logger.debug(f"Rate limiting: sleeping {sleep_time:.3f}s")
                time.sleep(sleep_time)
            
            self.last_request_time = time.time()

class FlowMetrics:
    """Metrics collection for Flow operations"""
    
    def __init__(self):
        self.lock = threading.Lock()
        self.reset()
    
    def reset(self):
        """Reset all metrics"""
        with self.lock:
            self.total_operations = 0
            self.successful_operations = 0
            self.failed_operations = 0
            self.total_execution_time = 0.0
            self.retry_count = 0
            self.rate_limited_operations = 0
            self.timeout_operations = 0
            self.operation_types = {}
            self.networks = {}
    
    def record_operation(self, result: FlowResult):
        """Record operation metrics"""
        with self.lock:
            self.total_operations += 1
            self.total_execution_time += result.execution_time
            self.retry_count += result.retry_count
            
            # Count by operation type
            op_type = result.operation_type
            if op_type not in self.operation_types:
                self.operation_types[op_type] = {"total": 0, "success": 0, "failed": 0}
            self.operation_types[op_type]["total"] += 1
            
            # Count by network
            network = result.network
            if network not in self.networks:
                self.networks[network] = {"total": 0, "success": 0, "failed": 0}
            self.networks[network]["total"] += 1
            
            if result.success:
                self.successful_operations += 1
                self.operation_types[op_type]["success"] += 1
                self.networks[network]["success"] += 1
            else:
                self.failed_operations += 1
                self.operation_types[op_type]["failed"] += 1
                self.networks[network]["failed"] += 1
                
                # Categorize failures
                if "rate limited" in result.error_message.lower():
                    self.rate_limited_operations += 1
                if "timeout" in result.error_message.lower():
                    self.timeout_operations += 1
    
    def get_summary(self) -> Dict[str, Any]:
        """Get metrics summary"""
        with self.lock:
            avg_execution_time = (
                self.total_execution_time / self.total_operations 
                if self.total_operations > 0 else 0.0
            )
            success_rate = (
                self.successful_operations / self.total_operations * 100 
                if self.total_operations > 0 else 0.0
            )
            
            return {
                "total_operations": self.total_operations,
                "successful_operations": self.successful_operations,
                "failed_operations": self.failed_operations,
                "success_rate_percent": round(success_rate, 2),
                "average_execution_time": round(avg_execution_time, 3),
                "total_retries": self.retry_count,
                "rate_limited_operations": self.rate_limited_operations,
                "timeout_operations": self.timeout_operations,
                "operation_types": self.operation_types.copy(),
                "networks": self.networks.copy()
            }

class FlowWrapper:
    """Production-ready Flow CLI wrapper"""
    
    def __init__(self, config: Optional[FlowConfig] = None):
        self.config = config or FlowConfig()
        self.rate_limiter = FlowRateLimiter(self.config.rate_limit_delay)
        self.metrics = FlowMetrics()
        self.flow_binary = None
        self._initialize_flow_binary()
        
        # Set up logging
        logging.getLogger(__name__).setLevel(getattr(logging, self.config.log_level))
    
    def _initialize_flow_binary(self):
        """Initialize Flow CLI binary path"""
        try:
            result = subprocess.run(
                ['which', 'flow'], 
                capture_output=True, 
                text=True, 
                timeout=10
            )
            if result.returncode == 0:
                self.flow_binary = result.stdout.strip()
                logger.info(f"Flow CLI binary found: {self.flow_binary}")
            else:
                raise RuntimeError("Flow CLI not found in PATH")
        except Exception as e:
            logger.error(f"Failed to find Flow CLI binary: {e}")
            raise
    
    def _build_base_command(self, operation: str, args: List[str] = None) -> List[str]:
        """Build base Flow CLI command"""
        if not self.flow_binary:
            raise RuntimeError("Flow CLI binary not initialized")
        
        cmd = [self.flow_binary] + operation.split()
        if args:
            cmd.extend(args)
        
        # Add configuration files - both flow.json and flow-production.json
        # Since we run from flow/ directory, paths are relative to that
        cmd.extend(['-f', 'flow.json'])
        cmd.extend(['-f', 'accounts/flow-production.json'])
        
        # Add --no-config flag to prevent automatic signer detection
        # cmd.extend(['--no-config'])  # Commented out for now, but this might be needed
        
        # Add network if not already specified
        if '--network' not in cmd and '--net' not in cmd:
            cmd.extend(['--network', self.config.network.value])
        
        # Add JSON output for scripts and transactions
        if (operation.startswith('scripts') or operation.startswith('transactions')) and self.config.json_output:
            if '--output' not in cmd and '-o' not in cmd:
                cmd.extend(['--output', 'json'])
        
        return cmd
    
    def _execute_command(self, cmd: List[str], timeout: Optional[int] = None) -> FlowResult:
        """Execute Flow CLI command with comprehensive error handling"""
        start_time = time.time()
        timeout = timeout or self.config.timeout
        cmd_str = ' '.join(cmd)
        
        # COMPREHENSIVE DEBUG OUTPUT
        print("=" * 80)
        print("🔍 FLOWWRAPPER DEBUG - SUBPROCESS EXECUTION")
        print("=" * 80)
        print(f"📋 Command array: {cmd}")
        print(f"📋 Command string: {cmd_str}")
        print(f"📋 Command length: {len(cmd)}")
        print(f"📋 Contains '--signer': {'--signer' in cmd}")
        print(f"📋 Contains '--proposer': {'--proposer' in cmd}")
        print(f"📋 Contains '--authorizer': {'--authorizer' in cmd}")
        print(f"📋 Contains '--payer': {'--payer' in cmd}")
        print()
        
        # Environment debugging
        print("🌍 ENVIRONMENT DEBUG:")
        print(f"   Current working directory: {os.getcwd()}")
        print(f"   Flow directory (cwd): {self.config.flow_dir}")
        flow_dir_path = Path(self.config.flow_dir)
        print(f"   Flow directory exists: {flow_dir_path.exists()}")
        print(f"   Flow directory absolute: {flow_dir_path.absolute()}")
        print(f"   Python executable: {sys.executable}")
        print(f"   Python version: {sys.version}")
        print(f"   Process ID: {os.getpid()}")
        print(f"   Parent process ID: {os.getppid()}")
        print()
        
        # File system debugging
        print("📁 FILE SYSTEM DEBUG:")
        try:
            flow_dir_path = Path(self.config.flow_dir)
            flow_dir_contents = list(flow_dir_path.iterdir())
            print(f"   Flow directory contents: {[f.name for f in flow_dir_contents]}")
            print(f"   flow.json exists: {(flow_dir_path / 'flow.json').exists()}")
            print(f"   flow-production.json exists: {(flow_dir_path / 'accounts' / 'flow-production.json').exists()}")
        except Exception as e:
            print(f"   Error listing flow directory: {e}")
        print()
        
        # Flow CLI debugging
        print("⚡ FLOW CLI DEBUG:")
        print(f"   Flow binary: {self.flow_binary}")
        print(f"   Flow binary exists: {Path(self.flow_binary).exists() if self.flow_binary else False}")
        try:
            # Test flow version
            version_result = subprocess.run(
                [self.flow_binary, 'version'],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.config.flow_dir
            )
            print(f"   Flow version: {version_result.stdout.strip()}")
            print(f"   Flow version command success: {version_result.returncode == 0}")
        except Exception as e:
            print(f"   Error getting Flow version: {e}")
        print()
        
        logger.debug(f"Executing Flow command: {cmd_str}")
        print(f"🚀 EXECUTING FLOW COMMAND: {cmd_str}")
        
        try:
            # Apply rate limiting
            self.rate_limiter.wait_if_needed()
            
            # Execute command from the flow directory
            print(f"🎯 About to execute subprocess.run with:")
            print(f"   cmd: {cmd}")
            print(f"   cwd: {self.config.flow_dir}")
            print(f"   timeout: {timeout}")
            print("=" * 80)
            
            result = subprocess.run(
                cmd,
                cwd=self.config.flow_dir,
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=False,
                env=os.environ.copy()
            )
            
            execution_time = time.time() - start_time
            
            # SUBPROCESS RESULT DEBUG
            print("📊 SUBPROCESS RESULT DEBUG:")
            print(f"   Return code: {result.returncode}")
            print(f"   Execution time: {execution_time:.3f}s")
            print(f"   STDOUT length: {len(result.stdout)}")
            print(f"   STDERR length: {len(result.stderr)}")
            print(f"   STDOUT preview: {result.stdout[:200]}...")
            print(f"   STDERR preview: {result.stderr[:200]}...")
            print()
            
            # Parse output
            data = None
            if result.returncode == 0 and result.stdout.strip():
                try:
                    data = json.loads(result.stdout.strip())
                    print("✅ Successfully parsed JSON output")
                except json.JSONDecodeError:
                    # Not JSON output, use raw text
                    data = {"raw_output": result.stdout.strip()}
                    print("⚠️  Could not parse JSON, using raw output")
            
            # Extract transaction ID if present
            transaction_id = None
            if result.stdout and 'Transaction ID:' in result.stdout:
                for line in result.stdout.split('\n'):
                    if 'Transaction ID:' in line:
                        parts = line.split(':')
                        if len(parts) > 1:
                            transaction_id = parts[1].strip()
                            break
            
            flow_result = FlowResult(
                success=result.returncode == 0,
                data=data,
                raw_output=result.stdout,
                error_message=result.stderr,
                execution_time=execution_time,
                command=cmd_str,
                network=self.config.network.value,
                operation_type=self._determine_operation_type(cmd),
                transaction_id=transaction_id
            )
            
            # Record metrics
            self.metrics.record_operation(flow_result)
            
            print("🎯 FINAL RESULT:")
            print(f"   Success: {flow_result.success}")
            print(f"   Transaction ID: {flow_result.transaction_id}")
            print(f"   Error message: {flow_result.error_message}")
            print("=" * 80)
            
            if flow_result.success:
                logger.debug(f"Flow command succeeded in {execution_time:.3f}s")
            else:
                logger.warning(f"Flow command failed: {result.stderr}")
            
            return flow_result
            
        except subprocess.TimeoutExpired:
            execution_time = time.time() - start_time
            error_msg = f"Command timed out after {timeout} seconds"
            logger.error(f"Flow command timeout: {cmd_str}")
            
            flow_result = FlowResult(
                success=False,
                error_message=error_msg,
                execution_time=execution_time,
                command=cmd_str,
                network=self.config.network.value,
                operation_type=self._determine_operation_type(cmd)
            )
            
            self.metrics.record_operation(flow_result)
            return flow_result
            
        except Exception as e:
            execution_time = time.time() - start_time
            error_msg = f"Unexpected error: {str(e)}"
            logger.error(f"Flow command error: {cmd_str} - {error_msg}")
            
            flow_result = FlowResult(
                success=False,
                error_message=error_msg,
                execution_time=execution_time,
                command=cmd_str,
                network=self.config.network.value,
                operation_type=self._determine_operation_type(cmd)
            )
            
            self.metrics.record_operation(flow_result)
            return flow_result
    
    def _determine_operation_type(self, cmd: List[str]) -> str:
        """Determine operation type from command"""
        cmd_str = ' '.join(cmd).lower()
        if 'scripts' in cmd_str:
            return FlowOperationType.SCRIPT.value
        elif 'transactions' in cmd_str:
            return FlowOperationType.TRANSACTION.value
        elif 'accounts' in cmd_str:
            return FlowOperationType.ACCOUNT.value
        elif 'blocks' in cmd_str:
            return FlowOperationType.BLOCK.value
        else:
            return "unknown"
    
    def _retry_operation(self, operation_func, *args, **kwargs) -> FlowResult:
        """Retry operation with exponential backoff"""
        last_result = None
        
        for attempt in range(self.config.max_retries + 1):
            if attempt > 0:
                delay = self.config.retry_delay * (2 ** (attempt - 1))
                logger.info(f"Retrying operation (attempt {attempt + 1}/{self.config.max_retries + 1}) after {delay}s")
                time.sleep(delay)
            
            result = operation_func(*args, **kwargs)
            result.retry_count = attempt
            
            if result.success:
                return result
            
            last_result = result
            
            # Don't retry on certain errors
            if any(error in result.error_message.lower() for error in [
                'invalid', 'not found', 'unauthorized', 'insufficient'
            ]):
                logger.warning(f"Non-retryable error: {result.error_message}")
                break
        
        return last_result
    
    def execute_script(self, script_path: str, args: List[str] = None, timeout: Optional[int] = None) -> FlowResult:
        """Execute a Flow script"""
        def _execute():
            cmd = self._build_base_command(f'scripts execute {script_path}', args)
            return self._execute_command(cmd, timeout)
        
        return self._retry_operation(_execute)
    
    def send_transaction(self, transaction_path: str, args: List[str] = None, 
                        signer: Optional[str] = None, payer: Optional[str] = None,
                        proposer: Optional[str] = None, authorizer: Optional[str] = None,
                        authorizers: Optional[List[str]] = None, timeout: Optional[int] = None) -> FlowResult:
        """Send a Flow transaction"""
        def _execute():
            cmd = self._build_base_command(f'transactions send {transaction_path}', args)
            
            # Always use individual role flags: --proposer, --authorizer, --payer
            # Never use --signer flag
            # Always hardcode proposer to mainnet-agfarms
            
            cmd.extend(['--proposer', 'mainnet-agfarms'])  # Always hardcode proposer
            
            # Handle authorizers - always include mainnet-agfarms and any additional authorizers
            authorizer_list = ['mainnet-agfarms']  # Always include mainnet-agfarms
            if authorizers:
                authorizer_list.extend(authorizers)
            elif authorizer:
                authorizer_list.append(authorizer)
            
            # Add authorizers as comma-separated list
            authorizer_string = ','.join(authorizer_list)
            cmd.extend(['--authorizer', authorizer_string])
            
            if payer:
                cmd.extend(['--payer', payer])
            
            return self._execute_command(cmd, timeout)
        
        return self._retry_operation(_execute)
    
    def get_account(self, address: str, timeout: Optional[int] = None) -> FlowResult:
        """Get account information"""
        def _execute():
            cmd = self._build_base_command(f'accounts get {address}')
            return self._execute_command(cmd, timeout)
        
        return self._retry_operation(_execute)
    
    def get_transaction(self, transaction_id: str, timeout: Optional[int] = None) -> FlowResult:
        """Get transaction information"""
        def _execute():
            cmd = self._build_base_command(f'transactions get {transaction_id}')
            return self._execute_command(cmd, timeout)
        
        return self._retry_operation(_execute)
    
    def wait_for_transaction_seal(self, transaction_id: str, timeout: int = 300) -> FlowResult:
        """Wait for a transaction to be sealed"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            result = self.get_transaction(transaction_id)
            
            if result.success and result.data:
                status = result.data.get('status', '').upper()
                if status == 'SEALED':
                    logger.info(f"Transaction {transaction_id} sealed successfully")
                    return result
                elif status == 'FAILED':
                    logger.error(f"Transaction {transaction_id} failed")
                    return FlowResult(
                        success=False,
                        error_message=f"Transaction {transaction_id} failed",
                        command=f"transactions get {transaction_id}",
                        network=self.config.network.value,
                        operation_type=FlowOperationType.TRANSACTION.value
                    )
            
            time.sleep(5)  # Wait 5 seconds before checking again
        
        # Timeout
        return FlowResult(
            success=False,
            error_message=f"Transaction {transaction_id} did not seal within {timeout} seconds",
            command=f"transactions get {transaction_id}",
            network=self.config.network.value,
            operation_type=FlowOperationType.TRANSACTION.value
        )
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get operation metrics"""
        return self.metrics.get_summary()
    
    def reset_metrics(self):
        """Reset operation metrics"""
        self.metrics.reset()
    
    def update_config(self, **kwargs):
        """Update configuration"""
        for key, value in kwargs.items():
            if hasattr(self.config, key):
                setattr(self.config, key, value)
                logger.info(f"Updated config: {key} = {value}")

# Convenience functions for common operations
def create_flow_wrapper(network: str = "mainnet", **kwargs) -> FlowWrapper:
    """Create a Flow wrapper with specified configuration"""
    config = FlowConfig(
        network=FlowNetwork(network),
        **kwargs
    )
    return FlowWrapper(config)

def execute_script(script_path: str, args: List[str] = None, network: str = "mainnet", **kwargs) -> FlowResult:
    """Execute a script using a temporary wrapper"""
    wrapper = create_flow_wrapper(network, **kwargs)
    return wrapper.execute_script(script_path, args)

def send_transaction(transaction_path: str, args: List[str] = None, network: str = "mainnet", **kwargs) -> FlowResult:
    """Send a transaction using a temporary wrapper"""
    wrapper = create_flow_wrapper(network, **kwargs)
    return wrapper.send_transaction(transaction_path, args, **kwargs)

# Decorator for automatic error handling and logging
def flow_operation(operation_type: FlowOperationType):
    """Decorator for Flow operations with automatic error handling"""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger.info(f"Starting {operation_type.value} operation: {func.__name__}")
            try:
                result = func(*args, **kwargs)
                if hasattr(result, 'success') and result.success:
                    logger.info(f"Completed {operation_type.value} operation: {func.__name__}")
                else:
                    logger.warning(f"Failed {operation_type.value} operation: {func.__name__}")
                return result
            except Exception as e:
                logger.error(f"Error in {operation_type.value} operation {func.__name__}: {e}")
                raise
        return wrapper
    return decorator
