# Flow CLI Wrapper

A production-ready Python wrapper for Flow CLI operations with comprehensive error handling, logging, rate limiting, and metrics collection.

## Overview

The Flow CLI Wrapper provides a standardized, thread-safe interface for interacting with the Flow blockchain through the Flow CLI. It replaces direct subprocess calls with a robust system that includes:

- **Standardized Error Handling**: Consistent error reporting and recovery mechanisms
- **JSON Output Parsing**: Automatic parsing of Flow CLI JSON responses
- **Rate Limiting**: Built-in rate limiting to respect Flow network limits
- **Retry Logic**: Exponential backoff retry mechanism for transient failures
- **Comprehensive Logging**: Detailed logging for debugging and monitoring
- **Metrics Collection**: Performance and success rate tracking
- **Thread Safety**: Safe for use in multi-threaded environments

## Features

### Core Functionality
- Execute Flow scripts with automatic JSON parsing
- Send transactions with proper signing and error handling
- Get account information
- Get transaction status and wait for sealing
- Comprehensive metrics and monitoring

### Production Features
- Rate limiting (configurable delays between requests)
- Retry logic with exponential backoff
- Timeout handling
- Thread-safe operations
- Comprehensive error categorization
- Performance metrics collection

## Installation

The Flow wrapper is included in the derbyfish-flow project. Ensure you have the Flow CLI installed and available in your PATH.

```bash
# Install Flow CLI (if not already installed)
# See: https://docs.onflow.org/flow-cli/install/
```

## Quick Start

### Basic Usage

```python
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork

# Create a wrapper instance
wrapper = FlowWrapper(FlowConfig(
    network=FlowNetwork.MAINNET,
    flow_dir=Path("flow"),
    timeout=300,
    max_retries=3,
    rate_limit_delay=0.2,
    json_output=True
))

# Execute a script
result = wrapper.execute_script(
    script_path="cadence/scripts/checkBaitBalance.cdc",
    args=["0x1234567890abcdef"]
)

if result.success:
    print(f"Script result: {result.data}")
else:
    print(f"Error: {result.error_message}")
```

### Convenience Functions

```python
from flowWrapper import execute_script, send_transaction

# Execute a script with a temporary wrapper
result = execute_script(
    script_path="cadence/scripts/checkBaitBalance.cdc",
    args=["0x1234567890abcdef"],
    network="mainnet"
)

# Send a transaction
result = send_transaction(
    transaction_path="cadence/transactions/sendBait.cdc",
    args=["0x1234567890abcdef", "100.0"],
    signer="mainnet-agfarms",
    network="mainnet"
)
```

## Configuration

### FlowConfig

The `FlowConfig` class allows you to customize the wrapper behavior:

```python
@dataclass
class FlowConfig:
    network: FlowNetwork = FlowNetwork.MAINNET
    flow_dir: Path = Path("flow")
    timeout: int = 300  # 5 minutes
    max_retries: int = 3
    retry_delay: float = 1.0
    rate_limit_delay: float = 0.2  # 200ms between requests
    json_output: bool = True
    log_level: str = "INFO"
```

### Configuration Options

- **network**: Flow network to use (mainnet, testnet, emulator)
- **flow_dir**: Directory containing Flow configuration files
- **timeout**: Default timeout for operations in seconds
- **max_retries**: Maximum number of retry attempts
- **retry_delay**: Base delay between retries (exponential backoff)
- **rate_limit_delay**: Minimum delay between requests to respect rate limits
- **json_output**: Whether to request JSON output from Flow CLI
- **log_level**: Logging level (DEBUG, INFO, WARNING, ERROR)

## API Reference

### FlowWrapper Class

#### Constructor
```python
FlowWrapper(config: Optional[FlowConfig] = None)
```

#### Methods

##### execute_script
Execute a Flow script and return parsed results.

```python
def execute_script(
    script_path: str, 
    args: List[str] = None, 
    timeout: Optional[int] = None
) -> FlowResult
```

**Parameters:**
- `script_path`: Path to the Cadence script file
- `args`: List of arguments to pass to the script
- `timeout`: Override default timeout

**Returns:** `FlowResult` object with success status and parsed data

##### send_transaction
Send a Flow transaction with proper signing.

```python
def send_transaction(
    transaction_path: str,
    args: List[str] = None,
    signer: Optional[str] = None,
    payer: Optional[str] = None,
    proposer: Optional[str] = None,
    authorizer: Optional[str] = None,
    timeout: Optional[int] = None
) -> FlowResult
```

**Parameters:**
- `transaction_path`: Path to the Cadence transaction file
- `args`: List of arguments to pass to the transaction
- `signer`: Account to sign the transaction
- `payer`: Account to pay for the transaction
- `proposer`: Account to propose the transaction
- `authorizer`: Account to authorize the transaction
- `timeout`: Override default timeout

**Returns:** `FlowResult` object with transaction ID and status

##### get_account
Get account information from the Flow blockchain.

```python
def get_account(address: str, timeout: Optional[int] = None) -> FlowResult
```

##### get_transaction
Get transaction information by ID.

```python
def get_transaction(transaction_id: str, timeout: Optional[int] = None) -> FlowResult
```

##### wait_for_transaction_seal
Wait for a transaction to be sealed on the blockchain.

```python
def wait_for_transaction_seal(transaction_id: str, timeout: int = 300) -> FlowResult
```

##### get_metrics
Get performance and success metrics.

```python
def get_metrics() -> Dict[str, Any]
```

**Returns:** Dictionary containing:
- `total_operations`: Total number of operations performed
- `successful_operations`: Number of successful operations
- `failed_operations`: Number of failed operations
- `success_rate_percent`: Success rate as a percentage
- `average_execution_time`: Average execution time in seconds
- `total_retries`: Total number of retries performed
- `rate_limited_operations`: Number of rate-limited operations
- `timeout_operations`: Number of timeout operations
- `operation_types`: Breakdown by operation type
- `networks`: Breakdown by network

##### reset_metrics
Reset all collected metrics.

```python
def reset_metrics()
```

##### update_config
Update configuration parameters.

```python
def update_config(**kwargs)
```

### FlowResult Class

The `FlowResult` class represents the result of a Flow CLI operation:

```python
@dataclass
class FlowResult:
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
```

**Fields:**
- `success`: Whether the operation succeeded
- `data`: Parsed JSON data (if available)
- `raw_output`: Raw stdout from Flow CLI
- `error_message`: Error message from stderr
- `execution_time`: Time taken to execute the command
- `command`: The actual command that was executed
- `network`: Network the command was executed on
- `operation_type`: Type of operation (script, transaction, account, block)
- `transaction_id`: Transaction ID (for transactions)
- `retry_count`: Number of retries performed

## Rate Limiting

The wrapper includes built-in rate limiting to respect Flow network limits:

- **Scripts**: 5 RPS limit (200ms between requests)
- **Transactions**: 50 RPS limit (20ms between requests)

Rate limiting is applied automatically and is thread-safe.

## Error Handling

The wrapper provides comprehensive error handling:

### Error Categories
- **Rate Limited**: Operations that hit rate limits
- **Timeout**: Operations that exceed timeout limits
- **Network Errors**: Connection or network-related issues
- **Validation Errors**: Invalid parameters or data
- **Authentication Errors**: Signing or authorization issues

### Retry Logic
- Automatic retry with exponential backoff
- Configurable maximum retry attempts
- Non-retryable errors (invalid, not found, unauthorized, insufficient) are not retried

## Logging

The wrapper uses Python's standard logging module with configurable levels:

```python
import logging

# Set log level
logging.getLogger('flowWrapper').setLevel(logging.DEBUG)
```

Log messages include:
- Command execution details
- Rate limiting information
- Retry attempts
- Error details
- Performance metrics

## Thread Safety

The Flow wrapper is fully thread-safe and can be used in multi-threaded environments:

- Rate limiting is thread-safe
- Metrics collection is thread-safe
- Multiple wrapper instances can be used simultaneously

## Integration Examples

### Flask API Integration

```python
from flask import Flask, jsonify
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork

app = Flask(__name__)

# Initialize wrapper
flow_wrapper = FlowWrapper(FlowConfig(
    network=FlowNetwork.MAINNET,
    flow_dir=Path("flow")
))

@app.route('/check-balance/<address>')
def check_balance(address):
    result = flow_wrapper.execute_script(
        script_path="cadence/scripts/checkBaitBalance.cdc",
        args=[address]
    )
    
    return jsonify({
        'success': result.success,
        'data': result.data,
        'error': result.error_message,
        'execution_time': result.execution_time
    })

@app.route('/metrics')
def get_metrics():
    return jsonify(flow_wrapper.get_metrics())
```

### Background Processing

```python
import threading
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork

class FlowProcessor:
    def __init__(self):
        self.wrapper = FlowWrapper(FlowConfig(
            network=FlowNetwork.MAINNET,
            rate_limit_delay=0.1  # Faster rate limiting for background processing
        ))
    
    def process_wallet(self, address):
        # Check balance
        balance_result = self.wrapper.execute_script(
            script_path="cadence/scripts/checkBaitBalance.cdc",
            args=[address]
        )
        
        if balance_result.success:
            # Process based on balance
            pass
        
        return balance_result

# Use in multiple threads
processor = FlowProcessor()
threads = []

for address in addresses:
    thread = threading.Thread(target=processor.process_wallet, args=(address,))
    threads.append(thread)
    thread.start()

for thread in threads:
    thread.join()
```

## Best Practices

### Configuration
- Use appropriate rate limiting delays for your use case
- Set reasonable timeouts for different operation types
- Configure logging level based on environment (DEBUG for development, INFO for production)

### Error Handling
- Always check the `success` field of `FlowResult`
- Handle rate limiting gracefully (operations will be retried automatically)
- Log errors for debugging and monitoring

### Performance
- Use the metrics endpoint to monitor performance
- Consider using multiple wrapper instances for high-throughput scenarios
- Monitor retry rates to identify potential issues

### Security
- Never log private keys or sensitive data
- Use appropriate signing accounts for different operations
- Validate all inputs before passing to Flow CLI

## Troubleshooting

### Common Issues

#### Flow CLI Not Found
```
RuntimeError: Flow CLI not found in PATH
```
**Solution**: Ensure Flow CLI is installed and available in your system PATH.

#### Rate Limiting
```
⚠️ Rate limited for 0x123..., will retry later
```
**Solution**: This is normal behavior. The wrapper will automatically retry. Consider increasing `rate_limit_delay` if you're hitting limits frequently.

#### Timeout Errors
```
Command timed out after 300 seconds
```
**Solution**: Increase the timeout value or check network connectivity.

#### JSON Parsing Errors
```
Error parsing JSON for 0x123...
```
**Solution**: Check that the script is returning valid JSON. Some scripts may return non-JSON output.

### Debug Mode

Enable debug logging to see detailed information:

```python
import logging
logging.getLogger('flowWrapper').setLevel(logging.DEBUG)
```

This will show:
- Exact commands being executed
- Rate limiting delays
- Retry attempts
- Detailed error information

## Migration from Direct Subprocess Calls

### Before (Direct subprocess)
```python
import subprocess

def check_balance(address):
    cmd = f"flow scripts execute cadence/scripts/checkBaitBalance.cdc {address} --network mainnet --output json"
    result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    
    if result.returncode == 0:
        data = json.loads(result.stdout)
        return data
    else:
        raise Exception(result.stderr)
```

### After (Using Flow Wrapper)
```python
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork

wrapper = FlowWrapper(FlowConfig(network=FlowNetwork.MAINNET))

def check_balance(address):
    result = wrapper.execute_script(
        script_path="cadence/scripts/checkBaitBalance.cdc",
        args=[address]
    )
    
    if result.success:
        return result.data
    else:
        raise Exception(result.error_message)
```

## Contributing

When contributing to the Flow wrapper:

1. Follow the existing code style
2. Add appropriate logging
3. Include error handling
4. Update tests if applicable
5. Update this documentation

## License

This wrapper is part of the derbyfish-flow project and follows the same license terms.
