//+------------------------------------------------------------------+
//|                                              DataManager.mqh |
//|                                                                  |
//| Manages market data operations for the MCP Server                |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

#include <../MCPConfig.mqh>

//+------------------------------------------------------------------+
//| CDataManager class                                                |
//+------------------------------------------------------------------+
class CDataManager
{
private:
   uint              m_lastCleanupTime; // Last cleanup time
   
   // Helper methods
   string            TimeframeToString(ENUM_TIMEFRAMES timeframe);
   ENUM_TIMEFRAMES   StringToTimeframe(string timeframe);
   string            FormatErrorResponse(string requestId, string message);
   
public:
                     CDataManager();
                    ~CDataManager();
   
   bool              Initialize();
   void              Cleanup();
   
   // Command handlers
   string            HandleGetPrice(string command, string requestId, string parameters);
   string            HandleGetHistory(string command, string requestId, string parameters);
   string            HandleGetIndicatorValue(string command, string requestId, string parameters);
   string            HandleGetAccountInfo(string command, string requestId, string parameters);
   string            HandleGetBalance(string command, string requestId, string parameters);
   string            HandleGetEquity(string command, string requestId, string parameters);
   string            HandleGetMargin(string command, string requestId, string parameters);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDataManager::CDataManager()
{
   m_lastCleanupTime = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDataManager::~CDataManager()
{
   // No specific cleanup needed
}

//+------------------------------------------------------------------+
//| Initialize data manager                                           |
//+------------------------------------------------------------------+
bool CDataManager::Initialize()
{
   return true;
}

//+------------------------------------------------------------------+
//| Periodic cleanup of resources                                     |
//+------------------------------------------------------------------+
void CDataManager::Cleanup()
{
   uint currentTime = GetTickCount();
   
   // Only cleanup once per minute
   if(currentTime - m_lastCleanupTime < 60000)
      return;
      
   // Perform cleanup tasks here if needed
   
   m_lastCleanupTime = currentTime;
}

//+------------------------------------------------------------------+
//| Convert timeframe enum to string                                  |
//+------------------------------------------------------------------+
string CDataManager::TimeframeToString(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:     return "M1";
      case PERIOD_M2:     return "M2";
      case PERIOD_M3:     return "M3";
      case PERIOD_M4:     return "M4";
      case PERIOD_M5:     return "M5";
      case PERIOD_M6:     return "M6";
      case PERIOD_M10:    return "M10";
      case PERIOD_M12:    return "M12";
      case PERIOD_M15:    return "M15";
      case PERIOD_M20:    return "M20";
      case PERIOD_M30:    return "M30";
      case PERIOD_H1:     return "H1";
      case PERIOD_H2:     return "H2";
      case PERIOD_H3:     return "H3";
      case PERIOD_H4:     return "H4";
      case PERIOD_H6:     return "H6";
      case PERIOD_H8:     return "H8";
      case PERIOD_H12:    return "H12";
      case PERIOD_D1:     return "D1";
      case PERIOD_W1:     return "W1";
      case PERIOD_MN1:    return "MN1";
      default:            return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Convert string to timeframe enum                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CDataManager::StringToTimeframe(string timeframe)
{
   if(timeframe == "M1")   return PERIOD_M1;
   if(timeframe == "M2")   return PERIOD_M2;
   if(timeframe == "M3")   return PERIOD_M3;
   if(timeframe == "M4")   return PERIOD_M4;
   if(timeframe == "M5")   return PERIOD_M5;
   if(timeframe == "M6")   return PERIOD_M6;
   if(timeframe == "M10")  return PERIOD_M10;
   if(timeframe == "M12")  return PERIOD_M12;
   if(timeframe == "M15")  return PERIOD_M15;
   if(timeframe == "M20")  return PERIOD_M20;
   if(timeframe == "M30")  return PERIOD_M30;
   if(timeframe == "H1")   return PERIOD_H1;
   if(timeframe == "H2")   return PERIOD_H2;
   if(timeframe == "H3")   return PERIOD_H3;
   if(timeframe == "H4")   return PERIOD_H4;
   if(timeframe == "H6")   return PERIOD_H6;
   if(timeframe == "H8")   return PERIOD_H8;
   if(timeframe == "H12")  return PERIOD_H12;
   if(timeframe == "D1")   return PERIOD_D1;
   if(timeframe == "W1")   return PERIOD_W1;
   if(timeframe == "MN1")  return PERIOD_MN1;
   
   // Default to M1 if unknown
   return PERIOD_M1;
}

//+------------------------------------------------------------------+
//| Format error response                                             |
//+------------------------------------------------------------------+
string CDataManager::FormatErrorResponse(string requestId, string message)
{
   string response = "{";
   response += "\"status\":\"error\",";
   
   if(requestId != "")
   {
      response += "\"requestId\":\"" + requestId + "\",";
      response += "\"responseToId\":\"" + requestId + "\",";
   }
   
   response += "\"message\":\"" + message + "\"";
   response += "}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_price command                                      |
//+------------------------------------------------------------------+
string CDataManager::HandleGetPrice(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   string symbol = "";
   
   // Parse parameters
   int pos = 0;
   while(pos < StringLen(parameters))
   {
      int colonPos = StringFind(parameters, ":", pos);
      if(colonPos < 0)
         break;
         
      // Extract key (removing quotes and spaces)
      string key = "";
      for(int i = pos + 1; i < colonPos - 1; i++)
      {
         string ch = StringSubstr(parameters, i, 1);
         if(ch != "\"" && ch != " ")
            key += ch;
      }
      
      // Find value end position
      int valueEndPos = -1;
      if(StringSubstr(parameters, colonPos + 1, 1) == "\"")
      {
         // String value
         valueEndPos = StringFind(parameters, "\"", colonPos + 2);
         if(valueEndPos < 0)
            break;
            
         // Extract string value
         string value = StringSubstr(parameters, colonPos + 2, valueEndPos - colonPos - 2);
         
         // Assign value to appropriate parameter
         if(key == "symbol")
            symbol = value;
      }
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(symbol == "")
      return FormatErrorResponse(requestId, "Symbol not specified");
      
   // Check if symbol exists
   if(!SymbolSelect(symbol, true))
      return FormatErrorResponse(requestId, "Symbol not found: " + symbol);
      
   // Get price data
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double last = SymbolInfoDouble(symbol, SYMBOL_LAST);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"symbol\":\"" + symbol + "\",";
   response += "\"bid\":" + DoubleToString(bid, digits) + ",";
   response += "\"ask\":" + DoubleToString(ask, digits) + ",";
   response += "\"last\":" + DoubleToString(last, digits) + ",";
   response += "\"point\":" + DoubleToString(point, digits) + ",";
   response += "\"digits\":" + IntegerToString(digits) + ",";
   response += "\"spread\":" + DoubleToString(spread, 1) + ",";
   response += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_history command                                    |
//+------------------------------------------------------------------+
string CDataManager::HandleGetHistory(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   string symbol = "";
   string timeframeStr = "";
   int bars = 100;
   
   // Parse parameters
   int pos = 0;
   while(pos < StringLen(parameters))
   {
      int colonPos = StringFind(parameters, ":", pos);
      if(colonPos < 0)
         break;
         
      // Extract key (removing quotes and spaces)
      string key = "";
      for(int i = pos + 1; i < colonPos - 1; i++)
      {
         string ch = StringSubstr(parameters, i, 1);
         if(ch != "\"" && ch != " ")
            key += ch;
      }
      
      // Find value end position
      int valueEndPos = -1;
      if(StringSubstr(parameters, colonPos + 1, 1) == "\"")
      {
         // String value
         valueEndPos = StringFind(parameters, "\"", colonPos + 2);
         if(valueEndPos < 0)
            break;
            
         // Extract string value
         string value = StringSubstr(parameters, colonPos + 2, valueEndPos - colonPos - 2);
         
         // Assign value to appropriate parameter
         if(key == "symbol")
            symbol = value;
         else if(key == "timeframe")
            timeframeStr = value;
      }
      else
      {
         // Numeric value
         valueEndPos = StringFind(parameters, ",", colonPos);
         if(valueEndPos < 0)
            valueEndPos = StringFind(parameters, "}", colonPos);
         if(valueEndPos < 0)
            break;
            
         // Extract numeric value
         string value = StringSubstr(parameters, colonPos + 1, valueEndPos - colonPos - 1);
         value = StringTrimLeft(StringTrimRight(value));
         
         // Assign value to appropriate parameter
         if(key == "bars")
            bars = (int)StringToInteger(value);
      }
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(symbol == "")
      return FormatErrorResponse(requestId, "Symbol not specified");
      
   if(timeframeStr == "")
      timeframeStr = "M1"; // Default timeframe
      
   if(bars <= 0 || bars > MAX_BARS_REQUEST)
      bars = 100; // Default number of bars
      
   // Convert timeframe string to enum
   ENUM_TIMEFRAMES timeframe = StringToTimeframe(timeframeStr);
   
   // Check if symbol exists
   if(!SymbolSelect(symbol, true))
      return FormatErrorResponse(requestId, "Symbol not found: " + symbol);
      
   // Prepare arrays for historical data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Get historical data
   int copied = CopyRates(symbol, timeframe, 0, bars, rates);
   
   if(copied <= 0)
      return FormatErrorResponse(requestId, "Failed to get historical data: " + IntegerToString(GetLastError()));
      
   // Format historical data as JSON
   string historyDataJson = "[";
   
   for(int i = 0; i < copied; i++)
   {
      if(i > 0)
         historyDataJson += ",";
         
      historyDataJson += "{";
      historyDataJson += "\"time\":\"" + TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS) + "\",";
      historyDataJson += "\"open\":" + DoubleToString(rates[i].open, _Digits) + ",";
      historyDataJson += "\"high\":" + DoubleToString(rates[i].high, _Digits) + ",";
      historyDataJson += "\"low\":" + DoubleToString(rates[i].low, _Digits) + ",";
      historyDataJson += "\"close\":" + DoubleToString(rates[i].close, _Digits) + ",";
      historyDataJson += "\"tick_volume\":" + IntegerToString(rates[i].tick_volume) + ",";
      historyDataJson += "\"real_volume\":" + IntegerToString(rates[i].real_volume) + ",";
      historyDataJson += "\"spread\":" + IntegerToString(rates[i].spread);
      historyDataJson += "}";
   }
   
   historyDataJson += "]";
   
   // Format complete response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"symbol\":\"" + symbol + "\",";
   response += "\"timeframe\":\"" + timeframeStr + "\",";
   response += "\"bars\":" + IntegerToString(copied) + ",";
   response += "\"history_data\":" + historyDataJson;
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_indicator_value command                            |
//+------------------------------------------------------------------+
string CDataManager::HandleGetIndicatorValue(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   int indicatorHandle = INVALID_HANDLE;
   int bufferIndex = 0;
   int bars = 1;
   
   // Parse parameters
   int pos = 0;
   while(pos < StringLen(parameters))
   {
      int colonPos = StringFind(parameters, ":", pos);
      if(colonPos < 0)
         break;
         
      // Extract key (removing quotes and spaces)
      string key = "";
      for(int i = pos + 1; i < colonPos - 1; i++)
      {
         string ch = StringSubstr(parameters, i, 1);
         if(ch != "\"" && ch != " ")
            key += ch;
      }
      
      // Find value end position
      int valueEndPos = -1;
      valueEndPos = StringFind(parameters, ",", colonPos);
      if(valueEndPos < 0)
         valueEndPos = StringFind(parameters, "}", colonPos);
      if(valueEndPos < 0)
         break;
         
      // Extract numeric value
      string value = StringSubstr(parameters, colonPos + 1, valueEndPos - colonPos - 1);
      value = StringTrimLeft(StringTrimRight(value));
      
      // Assign value to appropriate parameter
      if(key == "handle")
         indicatorHandle = (int)StringToInteger(value);
      else if(key == "buffer")
         bufferIndex = (int)StringToInteger(value);
      else if(key == "bars")
         bars = (int)StringToInteger(value);
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(indicatorHandle == INVALID_HANDLE)
      return FormatErrorResponse(requestId, "Invalid indicator handle");
      
   if(bufferIndex < 0)
      return FormatErrorResponse(requestId, "Invalid buffer index");
      
   if(bars <= 0 || bars > MAX_BARS_REQUEST)
      bars = 1; // Default number of bars
      
   // Prepare arrays for indicator values
   double values[];
   ArraySetAsSeries(values, true);
   ArrayResize(values, bars);
   
   // Get indicator values
   int copied = CopyBuffer(indicatorHandle, bufferIndex, 0, bars, values);
   
   if(copied <= 0)
      return FormatErrorResponse(requestId, "Failed to get indicator values: " + IntegerToString(GetLastError()));
      
   // Format indicator values as JSON
   string valuesJson = "[";
   
   for(int i = 0; i < copied; i++)
   {
      if(i > 0)
         valuesJson += ",";
         
      valuesJson += DoubleToString(values[i], 8);
   }
   
   valuesJson += "]";
   
   // Format complete response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"handle\":" + IntegerToString(indicatorHandle) + ",";
   response += "\"buffer\":" + IntegerToString(bufferIndex) + ",";
   response += "\"bars\":" + IntegerToString(copied) + ",";
   response += "\"values\":" + valuesJson;
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_account_info command                               |
//+------------------------------------------------------------------+
string CDataManager::HandleGetAccountInfo(string command, string requestId, string parameters)
{
   // Get account information
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   string name = AccountInfoString(ACCOUNT_NAME);
   string server = AccountInfoString(ACCOUNT_SERVER);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   string company = AccountInfoString(ACCOUNT_COMPANY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"login\":" + IntegerToString(login) + ",";
   response += "\"name\":\"" + name + "\",";
   response += "\"server\":\"" + server + "\",";
   response += "\"currency\":\"" + currency + "\",";
   response += "\"company\":\"" + company + "\",";
   response += "\"balance\":" + DoubleToString(balance, 2) + ",";
   response += "\"equity\":" + DoubleToString(equity, 2) + ",";
   response += "\"margin\":" + DoubleToString(margin, 2) + ",";
   response += "\"free_margin\":" + DoubleToString(freeMargin, 2) + ",";
   response += "\"profit\":" + DoubleToString(profit, 2) + ",";
   response += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_balance command                                    |
//+------------------------------------------------------------------+
string CDataManager::HandleGetBalance(string command, string requestId, string parameters)
{
   // Get balance information
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"balance\":" + DoubleToString(balance, 2) + ",";
   response += "\"currency\":\"" + currency + "\",";
   response += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_equity command                                     |
//+------------------------------------------------------------------+
string CDataManager::HandleGetEquity(string command, string requestId, string parameters)
{
   // Get equity information
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"equity\":" + DoubleToString(equity, 2) + ",";
   response += "\"currency\":\"" + currency + "\",";
   response += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the get_margin command                                     |
//+------------------------------------------------------------------+
string CDataManager::HandleGetMargin(string command, string requestId, string parameters)
{
   // Get margin information
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double marginStopOut = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"margin\":" + DoubleToString(margin, 2) + ",";
   response += "\"free_margin\":" + DoubleToString(marginFree, 2) + ",";
   response += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   response += "\"margin_stop_out\":" + DoubleToString(marginStopOut, 2) + ",";
   response += "\"currency\":\"" + currency + "\",";
   response += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   response += "}}";
   
   return response;
}
