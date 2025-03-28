//+------------------------------------------------------------------+
//|                                          CommandProcessor.mqh |
//|                                                                  |
//| Processes commands received from the MCP Server                  |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

#include <../MCPConfig.mqh>

// Define command handler function type
typedef string (*CommandHandlerFunc)(string command, string requestId, string parameters);

//+------------------------------------------------------------------+
//| Command handler structure                                         |
//+------------------------------------------------------------------+
struct SCommandHandler
{
   string            command;       // Command name
   CommandHandlerFunc handler;      // Handler function
};

//+------------------------------------------------------------------+
//| CCommandProcessor class                                           |
//+------------------------------------------------------------------+
class CCommandProcessor
{
private:
   SCommandHandler   m_handlers[];  // Array of command handlers
   int               m_handlerCount; // Number of registered handlers
   
   // Helper methods
   string            ExtractJsonValue(string json, string key);
   string            FormatResponse(string requestId, string status, string data);
   
public:
                     CCommandProcessor();
                    ~CCommandProcessor();
   
   bool              Initialize();
   string            ProcessCommand(string commandJson);
   bool              RegisterHandler(string command, CommandHandlerFunc handler);
   
   // Static handlers for basic commands
   static string     HandlePing(string command, string requestId, string parameters);
   static string     HandleEcho(string command, string requestId, string parameters);
   static string     HandleUnknown(string command, string requestId, string parameters);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CCommandProcessor::CCommandProcessor()
{
   m_handlerCount = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CCommandProcessor::~CCommandProcessor()
{
   // No specific cleanup needed
}

//+------------------------------------------------------------------+
//| Initialize command processor                                      |
//+------------------------------------------------------------------+
bool CCommandProcessor::Initialize()
{
   // Register basic command handlers
   RegisterHandler("ping", HandlePing);
   RegisterHandler("echo", HandleEcho);
   
   return true;
}

//+------------------------------------------------------------------+
//| Process a command received from the server                        |
//+------------------------------------------------------------------+
string CCommandProcessor::ProcessCommand(string commandJson)
{
   if(commandJson == "")
      return "";
      
   if(LOG_COMMANDS)
      Print("Processing command: ", commandJson);
      
   // Extract command name and request ID
   string command = ExtractJsonValue(commandJson, "command");
   string requestId = ExtractJsonValue(commandJson, "requestId");
   string parameters = ExtractJsonValue(commandJson, "parameters");
   
   if(command == "")
   {
      Print("Invalid command format: ", commandJson);
      return FormatResponse(requestId, "error", "{\"message\":\"Invalid command format\"}");
   }
   
   // Find handler for the command
   for(int i = 0; i < m_handlerCount; i++)
   {
      if(m_handlers[i].command == command)
      {
         // Execute handler
         string response = m_handlers[i].handler(command, requestId, parameters);
         
         if(LOG_COMMANDS)
            Print("Command response: ", response);
            
         return response;
      }
   }
   
   // Command not found
   Print("Unknown command: ", command);
   return HandleUnknown(command, requestId, parameters);
}

//+------------------------------------------------------------------+
//| Register a command handler                                        |
//+------------------------------------------------------------------+
bool CCommandProcessor::RegisterHandler(string command, CommandHandlerFunc handler)
{
   // Check if handler already exists
   for(int i = 0; i < m_handlerCount; i++)
   {
      if(m_handlers[i].command == command)
      {
         m_handlers[i].handler = handler;
         return true;
      }
   }
   
   // Add new handler
   int index = m_handlerCount;
   m_handlerCount++;
   
   ArrayResize(m_handlers, m_handlerCount);
   m_handlers[index].command = command;
   m_handlers[index].handler = handler;
   
   return true;
}

//+------------------------------------------------------------------+
//| Extract a value from a JSON string                                |
//+------------------------------------------------------------------+
string CCommandProcessor::ExtractJsonValue(string json, string key)
{
   // This is a simple JSON parser for basic command processing
   // For more complex JSON handling, a full JSON parser should be used
   
   // Look for the key in the json
   string searchStr = "\"" + key + "\":";
   int pos = StringFind(json, searchStr);
   
   if(pos < 0)
      return "";
      
   pos += StringLen(searchStr);
   
   // Skip whitespace
   while(pos < StringLen(json) && StringSubstr(json, pos, 1) == " ")
      pos++;
      
   // Check value type
   string valueChar = StringSubstr(json, pos, 1);
   
   if(valueChar == "\"")
   {
      // String value
      pos++;
      int endPos = pos;
      
      bool escaped = false;
      while(endPos < StringLen(json))
      {
         string ch = StringSubstr(json, endPos, 1);
         
         if(ch == "\\")
         {
            escaped = !escaped;
         }
         else if(ch == "\"" && !escaped)
         {
            break;
         }
         else
         {
            escaped = false;
         }
         
         endPos++;
      }
      
      return StringSubstr(json, pos, endPos - pos);
   }
   else if(valueChar == "{")
   {
      // Object value
      int openBraces = 1;
      int endPos = pos + 1;
      
      while(endPos < StringLen(json) && openBraces > 0)
      {
         string ch = StringSubstr(json, endPos, 1);
         
         if(ch == "{")
            openBraces++;
         else if(ch == "}")
            openBraces--;
            
         endPos++;
      }
      
      return StringSubstr(json, pos, endPos - pos);
   }
   else if(valueChar == "[")
   {
      // Array value
      int openBrackets = 1;
      int endPos = pos + 1;
      
      while(endPos < StringLen(json) && openBrackets > 0)
      {
         string ch = StringSubstr(json, endPos, 1);
         
         if(ch == "[")
            openBrackets++;
         else if(ch == "]")
            openBrackets--;
            
         endPos++;
      }
      
      return StringSubstr(json, pos, endPos - pos);
   }
   else
   {
      // Number, boolean, or null value
      int endPos = pos;
      
      while(endPos < StringLen(json))
      {
         string ch = StringSubstr(json, endPos, 1);
         
         if(ch == "," || ch == "}" || ch == "]" || ch == " ")
            break;
            
         endPos++;
      }
      
      return StringSubstr(json, pos, endPos - pos);
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Format a response in JSON format                                  |
//+------------------------------------------------------------------+
string CCommandProcessor::FormatResponse(string requestId, string status, string data)
{
   string response = "{";
   
   response += "\"status\":\"" + status + "\"";
   
   if(requestId != "")
      response += ",\"requestId\":\"" + requestId + "\"";
      
   if(requestId != "")
      response += ",\"responseToId\":\"" + requestId + "\"";
      
   if(data != "")
      response += "," + data;
      
   response += "}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handler for the ping command                                      |
//+------------------------------------------------------------------+
string CCommandProcessor::HandlePing(string command, string requestId, string parameters)
{
   return FormatResponse(requestId, "ok", "\"data\":{\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}");
}

//+------------------------------------------------------------------+
//| Handler for the echo command                                      |
//+------------------------------------------------------------------+
string CCommandProcessor::HandleEcho(string command, string requestId, string parameters)
{
   return FormatResponse(requestId, "ok", "\"data\":" + parameters);
}

//+------------------------------------------------------------------+
//| Handler for unknown commands                                      |
//+------------------------------------------------------------------+
string CCommandProcessor::HandleUnknown(string command, string requestId, string parameters)
{
   return FormatResponse(requestId, "error", "\"message\":\"Unknown command: " + command + "\"");
}
