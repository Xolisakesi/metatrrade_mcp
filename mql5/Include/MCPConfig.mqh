//+------------------------------------------------------------------+
//|                                                  MCPConfig.mqh |
//|                                                                  |
//| Configuration settings for the MCP Server Expert Advisor         |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

// Version
#define VERSION "1.0.0"

// Server connection settings
#define MCP_SERVER_HOST "127.0.0.1"  // MCP Server hostname or IP
#define MCP_SERVER_PORT 5555         // MCP Server port
#define SOCKET_TIMEOUT 30            // Socket timeout in seconds
#define PING_INTERVAL 60             // Ping interval in seconds

// Debug settings
#define DEBUG_MODE true              // Enable debug mode
#define LOG_COMMANDS true            // Log all commands

// Security settings
#define REQUIRE_AUTH true            // Require authentication

// Performance settings
#define MAX_BARS_REQUEST 5000        // Maximum number of bars to request
#define MAX_COMMAND_SIZE 65536       // Maximum command size in bytes
#define SOCKET_BUFFER_SIZE 8192      // Socket buffer size

// Trade settings
#define DEFAULT_SLIPPAGE 3           // Default slippage in points
#define DEFAULT_MAGIC 12345          // Default magic number for orders
#define MAX_TRADE_VOLUME 100.0       // Maximum trade volume
