//+------------------------------------------------------------------+
//|                                                  MCPServer.mq5 |
//|                             MetaTrader Connection Protocol Server |
//|                                                                  |
//| This Expert Advisor acts as a client connecting to the Python    |
//| MCP Server to enable communication between external applications |
//| and MetaTrader 5.                                               |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property version   "1.00"
#property strict

// Include required files
#include <MCPConfig.mqh>
#include <MCPCore/SocketHandler.mqh>
#include <MCPCore/CommandProcessor.mqh>
#include <MCPCore/OrderManager.mqh>
#include <MCPCore/ChartManager.mqh>
#include <MCPCore/DataManager.mqh>

// Global objects
CSocketHandler Socket;
CCommandProcessor CommandProcessor;
COrderManager OrderManager;
CChartManager ChartManager;
CDataManager DataManager;

// Global variables
bool isConnected = false;
datetime lastPingTime = 0;
int reconnectAttempts = 0;
int maxReconnectAttempts = 5;
int reconnectDelay = 5; // in seconds

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Print banner
   PrintFormat("MCP Server Expert Advisor v%s started", VERSION);
   PrintFormat("Server: %s:%d", MCP_SERVER_HOST, MCP_SERVER_PORT);
   
   // Initialize components
   if(!InitializeComponents())
   {
      Print("Failed to initialize components, check journal for details");
      return INIT_FAILED;
   }
   
   // Connect to MCP Server
   if(!ConnectToServer())
   {
      Print("Failed to connect to MCP Server, will retry on next tick");
   }
   
   // Set timer for periodic tasks
   EventSetTimer(1); // 1 second timer
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Disconnect from server
   DisconnectFromServer();
   
   // Stop timer
   EventKillTimer();
   
   Print("MCP Server Expert Advisor stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check connection status
   if(!isConnected)
   {
      // Try to reconnect if maximum attempts not reached
      if(reconnectAttempts < maxReconnectAttempts)
      {
         if(GetTickCount() - lastPingTime > reconnectDelay * 1000)
         {
            Print("Attempting to reconnect to MCP Server...");
            ConnectToServer();
         }
      }
      return;
   }
   
   // Process any received messages
   ProcessMessages();
}

//+------------------------------------------------------------------+
//| Timer event function                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Send ping to keep connection alive
   if(isConnected)
   {
      if(TimeCurrent() - lastPingTime > PING_INTERVAL)
      {
         SendPing();
         lastPingTime = TimeCurrent();
      }
   }
   
   // Clean up resources
   OrderManager.Cleanup();
   ChartManager.Cleanup();
   DataManager.Cleanup();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Forward chart events to the chart manager
   ChartManager.OnChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Initialize all components                                         |
//+------------------------------------------------------------------+
bool InitializeComponents()
{
   // Initialize all the components
   if(!CommandProcessor.Initialize())
   {
      Print("Failed to initialize CommandProcessor");
      return false;
   }
   
   if(!OrderManager.Initialize())
   {
      Print("Failed to initialize OrderManager");
      return false;
   }
   
   if(!ChartManager.Initialize())
   {
      Print("Failed to initialize ChartManager");
      return false;
   }
   
   if(!DataManager.Initialize())
   {
      Print("Failed to initialize DataManager");
      return false;
   }
   
   // Register command handlers
   RegisterCommandHandlers();
   
   return true;
}

//+------------------------------------------------------------------+
//| Register command handlers with the command processor               |
//+------------------------------------------------------------------+
void RegisterCommandHandlers()
{
   // Register order-related command handlers
   CommandProcessor.RegisterHandler("open_order", OrderManager.HandleOpenOrder);
   CommandProcessor.RegisterHandler("modify_order", OrderManager.HandleModifyOrder);
   CommandProcessor.RegisterHandler("close_order", OrderManager.HandleCloseOrder);
   CommandProcessor.RegisterHandler("get_orders", OrderManager.HandleGetOrders);
   
   // Register chart-related command handlers
   CommandProcessor.RegisterHandler("get_chart_data", ChartManager.HandleGetChartData);
   CommandProcessor.RegisterHandler("set_timeframe", ChartManager.HandleSetTimeframe);
   CommandProcessor.RegisterHandler("add_indicator", ChartManager.HandleAddIndicator);
   CommandProcessor.RegisterHandler("remove_indicator", ChartManager.HandleRemoveIndicator);
   
   // Register data-related command handlers
   CommandProcessor.RegisterHandler("get_price", DataManager.HandleGetPrice);
   CommandProcessor.RegisterHandler("get_history", DataManager.HandleGetHistory);
   CommandProcessor.RegisterHandler("get_indicator_value", DataManager.HandleGetIndicatorValue);
   
   // Register account-related command handlers
   CommandProcessor.RegisterHandler("get_account_info", DataManager.HandleGetAccountInfo);
   CommandProcessor.RegisterHandler("get_balance", DataManager.HandleGetBalance);
   CommandProcessor.RegisterHandler("get_equity", DataManager.HandleGetEquity);
   CommandProcessor.RegisterHandler("get_margin", DataManager.HandleGetMargin);
   
   Print("Command handlers registered");
}

//+------------------------------------------------------------------+
//| Connect to the MCP Server                                         |
//+------------------------------------------------------------------+
bool ConnectToServer()
{
   // Initialize socket
   if(!Socket.Initialize())
   {
      Print("Failed to initialize socket");
      return false;
   }
   
   // Connect to server
   if(!Socket.Connect(MCP_SERVER_HOST, MCP_SERVER_PORT))
   {
      Print("Failed to connect to MCP Server");
      reconnectAttempts++;
      return false;
   }
   
   // Send identification message
   string identMessage = "{\"identity\":\"MT5_EA\",\"version\":\"" + VERSION + "\",\"account\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "}";
   
   if(!Socket.Send(identMessage))
   {
      Print("Failed to send identification message");
      Socket.Disconnect();
      reconnectAttempts++;
      return false;
   }
   
   // Wait for response
   string response = "";
   if(!Socket.Receive(response, 5000)) // 5 second timeout
   {
      Print("Timeout waiting for server response");
      Socket.Disconnect();
      reconnectAttempts++;
      return false;
   }
   
   // Check if valid response
   if(StringFind(response, "connected") >= 0)
   {
      Print("Successfully connected to MCP Server");
      isConnected = true;
      reconnectAttempts = 0;
      lastPingTime = TimeCurrent();
      return true;
   }
   else
   {
      Print("Invalid response from server: ", response);
      Socket.Disconnect();
      reconnectAttempts++;
      return false;
   }
}

//+------------------------------------------------------------------+
//| Disconnect from the MCP Server                                    |
//+------------------------------------------------------------------+
void DisconnectFromServer()
{
   if(isConnected)
   {
      Socket.Disconnect();
      isConnected = false;
      Print("Disconnected from MCP Server");
   }
}

//+------------------------------------------------------------------+
//| Process messages received from the server                          |
//+------------------------------------------------------------------+
void ProcessMessages()
{
   string message = "";
   
   // Check if there are any messages to receive
   if(!Socket.IsReadable())
   {
      return;
   }
   
   // Receive and process message
   if(Socket.Receive(message))
   {
      if(message != "")
      {
         // Process the command
         string response = CommandProcessor.ProcessCommand(message);
         
         // Send response back to server
         if(response != "")
         {
            Socket.Send(response);
         }
      }
   }
   else
   {
      // Check if socket is still connected
      if(!Socket.IsConnected())
      {
         Print("Lost connection to MCP Server");
         isConnected = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Send ping to keep connection alive                                |
//+------------------------------------------------------------------+
void SendPing()
{
   string pingMessage = "{\"command\":\"ping\",\"requestId\":\"ping_" + IntegerToString(GetTickCount()) + "\"}";
   
   if(!Socket.Send(pingMessage))
   {
      Print("Failed to send ping, connection may be lost");
      
      // Check if socket is still connected
      if(!Socket.IsConnected())
      {
         Print("Lost connection to MCP Server");
         isConnected = false;
      }
   }
}
