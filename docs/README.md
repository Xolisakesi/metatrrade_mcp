# MetaTrader Connection Protocol (MCP) Server

## Overview

The MetaTrader Connection Protocol (MCP) Server provides a bridge between external applications and the MetaTrader 5 platform. This solution uses MQL5 as the primary programming language, with Python for supporting functionality.

## Components

1. **Python MCP Server**: Socket server that handles communication between clients and MetaTrader 5
2. **MQL5 Expert Advisor**: Runs inside MetaTrader 5 and connects to the Python MCP Server
3. **Python Client Library**: Allows external applications to connect to the MCP Server

## Installation

### Prerequisites

- MetaTrader 5 platform installed
- Python 3.6 or higher
- Required Python packages: `socket`, `json`, `threading`, `time`, `uuid`, `logging`

### Installation Steps

1. **Install Python Components**:
   ```
   cd C:\metatrader_mcp
   pip install -r requirements.txt
   ```

2. **Install MQL5 Components**:
   - In MetaTrader 5, navigate to File > Open Data Folder
   - Copy the contents of the `mql5` folder to the appropriate locations:
     - `mql5/Experts/MCPServer.mq5` → `[MT5 Data Folder]/MQL5/Experts/`
     - `mql5/Include/MCPConfig.mqh` → `[MT5 Data Folder]/MQL5/Include/`
     - `mql5/Include/MCPCore/*.mqh` → `[MT5 Data Folder]/MQL5/Include/MCPCore/`
     - `mql5/Scripts/InstallMCPServer.mq5` → `[MT5 Data Folder]/MQL5/Scripts/`
   - Alternatively, run the installation script in MetaTrader 5:
     - Open MetaTrader 5
     - In the Navigator, go to Scripts
     - Double-click on `InstallMCPServer` (you may need to compile it first)

3. **Configure Settings**:
   - Edit `C:\metatrader_mcp\python\mcp_config.ini` to configure server settings
   - Edit `[MT5 Data Folder]/MQL5/Include/MCPConfig.mqh` to configure EA settings

## Starting the Server

1. **Start the Python MCP Server**:
   ```
   cd C:\metatrader_mcp\python
   python mcp_server.py
   ```
   
   Optional command-line arguments:
   - `--host`: Host address to bind (default: 127.0.0.1)
   - `--port`: Port to listen on (default: 5555)
   - `--no-auth`: Disable authentication
   - `--max-clients`: Maximum number of clients (default: 10)
   - `--debug`: Enable debug logging

2. **Load the MCP Expert Advisor**:
   - Open MetaTrader 5
   - Open any chart
   - Drag and drop the `MCPServer` EA onto the chart
   - Configure any EA settings and click OK

## Using the MCP Client

```python
from mcp_client import MCPClient

# Create client and connect
client = MCPClient(host='127.0.0.1', port=5555)

if client.connect():
    # Get account info
    result = client.get_account_info()
    print(f"Account info: {result}")
    
    # Get current price
    result = client.get_price('EURUSD')
    print(f"EURUSD price: {result}")
    
    # Open order
    result = client.open_order('EURUSD', 'BUY', 0.1, sl=1.1000, tp=1.2000)
    print(f"Order result: {result}")
    
    # Disconnect
    client.disconnect()
```

## Supported Commands

### Trading Operations
- `open_order`: Open a new position
- `modify_order`: Modify an existing position
- `close_order`: Close an existing position
- `get_orders`: Get list of open positions

### Chart Operations
- `get_chart_data`: Get chart data for a symbol
- `set_timeframe`: Change chart timeframe
- `add_indicator`: Add indicator to chart
- `remove_indicator`: Remove indicator from chart

### Account Operations
- `get_account_info`: Get account information
- `get_balance`: Get account balance
- `get_equity`: Get account equity
- `get_margin`: Get account margin

### Market Data Operations
- `get_price`: Get current price for a symbol
- `get_history`: Get historical data for a symbol
- `get_indicator_value`: Get indicator value

## Security Considerations

- The MCP Server supports token-based authentication
- Default configuration only allows connections from localhost
- All commands are validated before execution
- Input parameters are sanitized to prevent malicious commands

## Troubleshooting

1. **Connection Issues**:
   - Verify that the Python MCP Server is running
   - Check that the EA is attached to a chart and initialized
   - Ensure firewall settings allow connections on the configured port
   - Check IP address and port settings in both components

2. **Authentication Issues**:
   - Verify that the authentication token is correct
   - Check if authentication is enabled/disabled consistently on both ends

3. **Command Execution Issues**:
   - Enable debug logging to see detailed error messages
   - Check journal logs in MetaTrader 5 for EA errors
   - Verify that command parameters are correctly formatted

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- MetaQuotes for the MetaTrader 5 platform and MQL5 language
- MQL5 community for reference implementations and documentation
