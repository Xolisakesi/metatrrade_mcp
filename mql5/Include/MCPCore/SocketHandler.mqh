//+------------------------------------------------------------------+
//|                                              SocketHandler.mqh |
//|                                                                  |
//| Handles socket communication with the MCP Server                 |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

#include <../MCPConfig.mqh>

//+------------------------------------------------------------------+
//| CSocketHandler class                                              |
//+------------------------------------------------------------------+
class CSocketHandler
{
private:
   int               m_socket;           // Socket handle
   bool              m_initialized;      // Initialization flag
   bool              m_connected;        // Connection flag
   datetime          m_lastActivity;     // Last activity time
   
   // Private methods
   bool              IsSocketValid();    // Check if socket is valid
   
public:
                     CSocketHandler();
                    ~CSocketHandler();
   
   // Initialization methods
   bool              Initialize();
   void              Shutdown();
   
   // Connection methods
   bool              Connect(string host, int port);
   void              Disconnect();
   bool              IsConnected();
   
   // Send/Receive methods
   bool              Send(string data);
   bool              Receive(string &data, int timeout = 0);
   bool              IsReadable();
   bool              IsWritable();
   
   // Utility methods
   int               GetLastError();
   string            GetLastErrorMessage();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSocketHandler::CSocketHandler()
{
   m_socket = INVALID_HANDLE;
   m_initialized = false;
   m_connected = false;
   m_lastActivity = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSocketHandler::~CSocketHandler()
{
   Shutdown();
}

//+------------------------------------------------------------------+
//| Initialize socket handler                                         |
//+------------------------------------------------------------------+
bool CSocketHandler::Initialize()
{
   if(m_initialized)
      return true;
   
   // Create socket
   m_socket = SocketCreate(SOCKET_DEFAULT);
   if(m_socket == INVALID_HANDLE)
   {
      Print("Socket creation failed with error: ", GetLastErrorMessage());
      return false;
   }
   
   // Set socket timeout
   if(!SocketTimeouts(m_socket, SOCKET_TIMEOUT * 1000, SOCKET_TIMEOUT * 1000))
   {
      Print("Failed to set socket timeouts: ", GetLastErrorMessage());
      SocketClose(m_socket);
      m_socket = INVALID_HANDLE;
      return false;
   }
   
   m_initialized = true;
   
   if(DEBUG_MODE)
      Print("Socket initialized successfully");
      
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown socket handler                                           |
//+------------------------------------------------------------------+
void CSocketHandler::Shutdown()
{
   Disconnect();
   
   if(m_socket != INVALID_HANDLE)
   {
      SocketClose(m_socket);
      m_socket = INVALID_HANDLE;
   }
   
   m_initialized = false;
   
   if(DEBUG_MODE)
      Print("Socket handler shutdown");
}

//+------------------------------------------------------------------+
//| Connect to the server                                             |
//+------------------------------------------------------------------+
bool CSocketHandler::Connect(string host, int port)
{
   if(!m_initialized)
   {
      Print("Socket handler not initialized");
      return false;
   }
   
   if(m_connected)
   {
      Print("Already connected, disconnecting first");
      Disconnect();
   }
   
   // Attempt to connect
   if(!SocketConnect(m_socket, host, port))
   {
      Print("Socket connection failed to ", host, ":", IntegerToString(port), " with error: ", GetLastErrorMessage());
      return false;
   }
   
   m_connected = true;
   m_lastActivity = TimeCurrent();
   
   if(DEBUG_MODE)
      Print("Socket connected to ", host, ":", IntegerToString(port));
      
   return true;
}

//+------------------------------------------------------------------+
//| Disconnect from the server                                        |
//+------------------------------------------------------------------+
void CSocketHandler::Disconnect()
{
   if(m_connected && m_socket != INVALID_HANDLE)
   {
      SocketClose(m_socket);
      m_connected = false;
      
      // Recreate socket for future use
      m_socket = SocketCreate(SOCKET_DEFAULT);
      if(m_socket != INVALID_HANDLE)
      {
         SocketTimeouts(m_socket, SOCKET_TIMEOUT * 1000, SOCKET_TIMEOUT * 1000);
      }
      
      if(DEBUG_MODE)
         Print("Socket disconnected");
   }
}

//+------------------------------------------------------------------+
//| Check if socket is connected                                      |
//+------------------------------------------------------------------+
bool CSocketHandler::IsConnected()
{
   if(!m_connected || m_socket == INVALID_HANDLE)
      return false;
      
   return SocketIsConnected(m_socket);
}

//+------------------------------------------------------------------+
//| Send data through the socket                                      |
//+------------------------------------------------------------------+
bool CSocketHandler::Send(string data)
{
   if(!IsSocketValid())
   {
      Print("Cannot send: Socket not valid");
      return false;
   }
   
   // Convert string to byte array
   uchar bytes[];
   int len = StringToCharArray(data, bytes);
   if(len <= 0)
   {
      Print("Failed to convert string to bytes");
      return false;
   }
   
   // Add null terminator
   ArrayResize(bytes, len + 1);
   bytes[len] = 0;
   
   // Send data
   int bytesSent = SocketSend(m_socket, bytes, len);
   if(bytesSent <= 0)
   {
      Print("Socket send failed with error: ", GetLastErrorMessage());
      return false;
   }
   
   m_lastActivity = TimeCurrent();
   
   if(DEBUG_MODE)
      Print("Sent data: ", data);
      
   return true;
}

//+------------------------------------------------------------------+
//| Receive data from the socket                                      |
//+------------------------------------------------------------------+
bool CSocketHandler::Receive(string &data, int timeout = 0)
{
   data = "";
   
   if(!IsSocketValid())
   {
      Print("Cannot receive: Socket not valid");
      return false;
   }
   
   // Check if there's data to read
   if(!IsReadable())
   {
      if(timeout > 0)
      {
         // Wait for data with timeout
         uint startTime = GetTickCount();
         while(GetTickCount() - startTime < (uint)timeout)
         {
            if(IsReadable())
               break;
               
            Sleep(10); // Short sleep to prevent CPU spinning
         }
         
         // Check again after waiting
         if(!IsReadable())
            return false;
      }
      else
      {
         return false;
      }
   }
   
   // Receive data
   uchar buffer[];
   ArrayResize(buffer, SOCKET_BUFFER_SIZE);
   
   int bytesRead = SocketReceive(m_socket, buffer, SOCKET_BUFFER_SIZE);
   if(bytesRead <= 0)
   {
      int error = GetLastError();
      if(error != 4060) // WSAETIMEDOUT - not really an error in this context
         Print("Socket receive failed with error: ", GetLastErrorMessage());
      return false;
   }
   
   // Convert bytes to string
   buffer[bytesRead] = 0; // Ensure null termination
   data = CharArrayToString(buffer, 0, bytesRead);
   
   m_lastActivity = TimeCurrent();
   
   if(DEBUG_MODE)
      Print("Received data: ", data);
      
   return true;
}

//+------------------------------------------------------------------+
//| Check if socket has data to read                                  |
//+------------------------------------------------------------------+
bool CSocketHandler::IsReadable()
{
   if(!IsSocketValid())
      return false;
      
   return SocketIsReadable(m_socket);
}

//+------------------------------------------------------------------+
//| Check if socket can be written to                                 |
//+------------------------------------------------------------------+
bool CSocketHandler::IsWritable()
{
   if(!IsSocketValid())
      return false;
      
   return SocketIsWritable(m_socket);
}

//+------------------------------------------------------------------+
//| Get last socket error code                                        |
//+------------------------------------------------------------------+
int CSocketHandler::GetLastError()
{
   return ::GetLastError();
}

//+------------------------------------------------------------------+
//| Get last socket error message                                     |
//+------------------------------------------------------------------+
string CSocketHandler::GetLastErrorMessage()
{
   int error = GetLastError();
   return "Error " + IntegerToString(error) + ": " + ErrorDescription(error);
}

//+------------------------------------------------------------------+
//| Check if socket is valid                                          |
//+------------------------------------------------------------------+
bool CSocketHandler::IsSocketValid()
{
   if(!m_initialized || m_socket == INVALID_HANDLE || !m_connected)
      return false;
      
   return true;
}
