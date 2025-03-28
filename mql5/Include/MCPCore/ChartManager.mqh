//+------------------------------------------------------------------+
//|                                              ChartManager.mqh |
//|                                                                  |
//| Manages chart operations for the MCP Server                      |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

#include <../MCPConfig.mqh>

// Structure to store indicator information
struct SIndicator
{
   int               handle;        // Indicator handle
   string            name;          // Indicator name
   string            symbol;        // Symbol
   ENUM_TIMEFRAMES   timeframe;     // Timeframe
   datetime          lastAccess;    // Last access time
};

//+------------------------------------------------------------------+
//| CChartManager class                                               |
//+------------------------------------------------------------------+
class CChartManager
{
private:
   SIndicator        m_indicators[]; // Array of indicators
   int               m_indicatorCount; // Number of indicators
   uint              m_lastCleanupTime; // Last cleanup time
   
   // Helper methods
   string            TimeframeToString(ENUM_TIMEFRAMES timeframe);
   ENUM_TIMEFRAMES   StringToTimeframe(string timeframe);
   string            FormatErrorResponse(string requestId, string message);
   
public:
                     CChartManager();
                    ~CChartManager();
   
   bool              Initialize();
   void              Cleanup();
   void              OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   
   // Command handlers
   string            HandleGetChartData(string command, string requestId, string parameters);
   string            HandleSetTimeframe(string command, string requestId, string parameters);
   string            HandleAddIndicator(string command, string requestId, string parameters);
   string            HandleRemoveIndicator(string command, string requestId, string parameters);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CChartManager::CChartManager()
{
   m_indicatorCount = 0;
   m_lastCleanupTime = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CChartManager::~CChartManager()
{
   // Release all indicator handles
   for(int i = 0; i < m_indicatorCount; i++)
   {
      if(m_indicators[i].handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_indicators[i].handle);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize chart manager                                          |
//+------------------------------------------------------------------+
bool CChartManager::Initialize()
{
   return true;
}

//+------------------------------------------------------------------+
//| Periodic cleanup of resources                                     |
//+------------------------------------------------------------------+
void CChartManager::Cleanup()
{
   uint currentTime = GetTickCount();
   
   // Only cleanup once per minute
   if(currentTime - m_lastCleanupTime < 60000)
      return;
      
   // Check for unused indicators (not accessed for 10 minutes)
   datetime currentDateTime = TimeCurrent();
   for(int i = m_indicatorCount - 1; i >= 0; i--)
   {
      if(currentDateTime - m_indicators[i].lastAccess > 600) // 10 minutes
      {
         // Release indicator handle
         if(m_indicators[i].handle != INVALID_HANDLE)
         {
            IndicatorRelease(m_indicators[i].handle);
         }
         
         // Remove from array by shifting elements
         for(int j = i; j < m_indicatorCount - 1; j++)
         {
            m_indicators[j] = m_indicators[j + 1];
         }
         
         m_indicatorCount--;
         ArrayResize(m_indicators, m_indicatorCount);
      }
   }
   
   m_lastCleanupTime = currentTime;
}

//+------------------------------------------------------------------+
//| Process chart events                                              |
//+------------------------------------------------------------------+
void CChartManager::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Process chart events if needed
}

//+------------------------------------------------------------------+
//| Convert timeframe enum to string                                  |
//+------------------------------------------------------------------+
string CChartManager::TimeframeToString(ENUM_TIMEFRAMES timeframe)
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
ENUM_TIMEFRAMES CChartManager::StringToTimeframe(string timeframe)
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
string CChartManager::FormatErrorResponse(string requestId, string message)
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
//| Handle the get_chart_data command                                 |
//+------------------------------------------------------------------+
string CChartManager::HandleGetChartData(string command, string requestId, string parameters)
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
      
   // Prepare arrays for chart data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Get chart data
   int copied = CopyRates(symbol, timeframe, 0, bars, rates);
   
   if(copied <= 0)
      return FormatErrorResponse(requestId, "Failed to get chart data: " + IntegerToString(GetLastError()));
      
   // Format chart data as JSON
   string chartDataJson = "[";
   
   for(int i = 0; i < copied; i++)
   {
      if(i > 0)
         chartDataJson += ",";
         
      chartDataJson += "{";
      chartDataJson += "\"time\":\"" + TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS) + "\",";
      chartDataJson += "\"open\":" + DoubleToString(rates[i].open, _Digits) + ",";
      chartDataJson += "\"high\":" + DoubleToString(rates[i].high, _Digits) + ",";
      chartDataJson += "\"low\":" + DoubleToString(rates[i].low, _Digits) + ",";
      chartDataJson += "\"close\":" + DoubleToString(rates[i].close, _Digits) + ",";
      chartDataJson += "\"tick_volume\":" + IntegerToString(rates[i].tick_volume) + ",";
      chartDataJson += "\"real_volume\":" + IntegerToString(rates[i].real_volume) + ",";
      chartDataJson += "\"spread\":" + IntegerToString(rates[i].spread);
      chartDataJson += "}";
   }
   
   chartDataJson += "]";
   
   // Format complete response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"symbol\":\"" + symbol + "\",";
   response += "\"timeframe\":\"" + timeframeStr + "\",";
   response += "\"bars\":" + IntegerToString(copied) + ",";
   response += "\"chart_data\":" + chartDataJson;
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the set_timeframe command                                  |
//+------------------------------------------------------------------+
string CChartManager::HandleSetTimeframe(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   string timeframeStr = "";
   
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
         if(key == "timeframe")
            timeframeStr = value;
      }
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(timeframeStr == "")
      return FormatErrorResponse(requestId, "Timeframe not specified");
      
   // Convert timeframe string to enum
   ENUM_TIMEFRAMES timeframe = StringToTimeframe(timeframeStr);
   
   // Set chart timeframe
   bool result = ChartSetSymbolPeriod(0, Symbol(), timeframe);
   
   if(!result)
      return FormatErrorResponse(requestId, "Failed to set timeframe: " + IntegerToString(GetLastError()));
      
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"timeframe\":\"" + timeframeStr + "\"";
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the add_indicator command                                  |
//+------------------------------------------------------------------+
string CChartManager::HandleAddIndicator(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   string indicatorName = "";
   string symbol = "";
   string timeframeStr = "";
   string paramString = "";
   
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
         if(key == "indicator")
            indicatorName = value;
         else if(key == "symbol")
            symbol = value;
         else if(key == "timeframe")
            timeframeStr = value;
         else if(key == "parameters")
            paramString = value;
      }
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(indicatorName == "")
      return FormatErrorResponse(requestId, "Indicator name not specified");
      
   if(symbol == "")
      symbol = Symbol(); // Use current symbol
      
   if(timeframeStr == "")
      timeframeStr = "M1"; // Default timeframe
      
   // Convert timeframe string to enum
   ENUM_TIMEFRAMES timeframe = StringToTimeframe(timeframeStr);
   
   // Check if symbol exists
   if(!SymbolSelect(symbol, true))
      return FormatErrorResponse(requestId, "Symbol not found: " + symbol);
      
   // Create the indicator handle based on indicator name
   int handle = INVALID_HANDLE;
   
   // Parse indicator parameters
   string params[];
   int paramCount = 0;
   
   if(paramString != "")
   {
      // Split parameters by comma
      int commaPos = 0;
      while(commaPos >= 0)
      {
         commaPos = StringFind(paramString, ",");
         
         if(commaPos >= 0)
         {
            // Extract parameter
            string param = StringSubstr(paramString, 0, commaPos);
            
            // Add parameter to array
            paramCount++;
            ArrayResize(params, paramCount);
            params[paramCount - 1] = param;
            
            // Remove processed parameter
            paramString = StringSubstr(paramString, commaPos + 1);
         }
         else if(paramString != "")
         {
            // Add last parameter
            paramCount++;
            ArrayResize(params, paramCount);
            params[paramCount - 1] = paramString;
         }
      }
   }
   
   // Create indicator handle
   if(indicatorName == "MA" || indicatorName == "MovingAverage")
   {
      int period = 14;
      int maMethod = MODE_SMA;
      int appliedPrice = PRICE_CLOSE;
      
      // Parse parameters
      if(paramCount >= 1)
         period = (int)StringToInteger(params[0]);
      if(paramCount >= 2)
         maMethod = (int)StringToInteger(params[1]);
      if(paramCount >= 3)
         appliedPrice = (int)StringToInteger(params[2]);
         
      handle = iMA(symbol, timeframe, period, 0, maMethod, appliedPrice);
   }
   else if(indicatorName == "RSI" || indicatorName == "RelativeStrengthIndex")
   {
      int period = 14;
      int appliedPrice = PRICE_CLOSE;
      
      // Parse parameters
      if(paramCount >= 1)
         period = (int)StringToInteger(params[0]);
      if(paramCount >= 2)
         appliedPrice = (int)StringToInteger(params[1]);
         
      handle = iRSI(symbol, timeframe, period, appliedPrice);
   }
   else if(indicatorName == "MACD")
   {
      int fastEma = 12;
      int slowEma = 26;
      int signalPeriod = 9;
      int appliedPrice = PRICE_CLOSE;
      
      // Parse parameters
      if(paramCount >= 1)
         fastEma = (int)StringToInteger(params[0]);
      if(paramCount >= 2)
         slowEma = (int)StringToInteger(params[1]);
      if(paramCount >= 3)
         signalPeriod = (int)StringToInteger(params[2]);
      if(paramCount >= 4)
         appliedPrice = (int)StringToInteger(params[3]);
         
      handle = iMACD(symbol, timeframe, fastEma, slowEma, signalPeriod, appliedPrice);
   }
   else if(indicatorName == "Bollinger" || indicatorName == "BollingerBands")
   {
      int period = 20;
      double deviation = 2.0;
      int shift = 0;
      int appliedPrice = PRICE_CLOSE;
      
      // Parse parameters
      if(paramCount >= 1)
         period = (int)StringToInteger(params[0]);
      if(paramCount >= 2)
         deviation = StringToDouble(params[1]);
      if(paramCount >= 3)
         shift = (int)StringToInteger(params[2]);
      if(paramCount >= 4)
         appliedPrice = (int)StringToInteger(params[3]);
         
      handle = iBands(symbol, timeframe, period, shift, deviation, appliedPrice);
   }
   else if(indicatorName == "Stochastic")
   {
      int kPeriod = 5;
      int dPeriod = 3;
      int slowing = 3;
      ENUM_MA_METHOD maMethod = MODE_SMA;
      ENUM_STO_PRICE stoPrice = STO_LOWHIGH;
      
      // Parse parameters
      if(paramCount >= 1)
         kPeriod = (int)StringToInteger(params[0]);
      if(paramCount >= 2)
         dPeriod = (int)StringToInteger(params[1]);
      if(paramCount >= 3)
         slowing = (int)StringToInteger(params[2]);
      if(paramCount >= 4)
         maMethod = (ENUM_MA_METHOD)(int)StringToInteger(params[3]);
      if(paramCount >= 5)
         stoPrice = (ENUM_STO_PRICE)(int)StringToInteger(params[4]);
         
      handle = iStochastic(symbol, timeframe, kPeriod, dPeriod, slowing, maMethod, stoPrice);
   }
   else
   {
      return FormatErrorResponse(requestId, "Unsupported indicator: " + indicatorName);
   }
   
   if(handle == INVALID_HANDLE)
      return FormatErrorResponse(requestId, "Failed to create indicator: " + IntegerToString(GetLastError()));
      
   // Add indicator to the list
   int index = m_indicatorCount;
   m_indicatorCount++;
   ArrayResize(m_indicators, m_indicatorCount);
   
   m_indicators[index].handle = handle;
   m_indicators[index].name = indicatorName;
   m_indicators[index].symbol = symbol;
   m_indicators[index].timeframe = timeframe;
   m_indicators[index].lastAccess = TimeCurrent();
   
   // Format response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"indicator\":\"" + indicatorName + "\",";
   response += "\"id\":" + IntegerToString(index) + ",";
   response += "\"handle\":" + IntegerToString(handle);
   response += "}}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the remove_indicator command                               |
//+------------------------------------------------------------------+
string CChartManager::HandleRemoveIndicator(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   int indicatorId = -1;
   
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
      if(key == "id")
         indicatorId = (int)StringToInteger(value);
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(indicatorId < 0 || indicatorId >= m_indicatorCount)
      return FormatErrorResponse(requestId, "Invalid indicator ID");
      
   // Release indicator handle
   if(m_indicators[indicatorId].handle != INVALID_HANDLE)
   {
      bool result = IndicatorRelease(m_indicators[indicatorId].handle);
      
      if(!result)
         return FormatErrorResponse(requestId, "Failed to release indicator: " + IntegerToString(GetLastError()));
      
      // Remove from array by shifting elements
      for(int i = indicatorId; i < m_indicatorCount - 1; i++)
      {
         m_indicators[i] = m_indicators[i + 1];
      }
      
      m_indicatorCount--;
      ArrayResize(m_indicators, m_indicatorCount);
      
      // Format response
      string response = "{";
      response += "\"status\":\"ok\",";
      response += "\"requestId\":\"" + requestId + "\",";
      response += "\"responseToId\":\"" + requestId + "\",";
      response += "\"data\":{";
      response += "\"id\":" + IntegerToString(indicatorId);
      response += "}}";
      
      return response;
   }
   else
   {
      return FormatErrorResponse(requestId, "Indicator handle is invalid");
   }
}
