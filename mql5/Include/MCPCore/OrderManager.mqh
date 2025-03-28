//+------------------------------------------------------------------+
//|                                              OrderManager.mqh |
//|                                                                  |
//| Manages trading operations for the MCP Server                    |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property strict

#include <../MCPConfig.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| COrderManager class                                               |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   CTrade            m_trade;             // Trade object for executing orders
   uint              m_lastCleanupTime;   // Last cleanup time
   
   // Helper methods
   string            OrderTypeToString(ENUM_ORDER_TYPE type);
   ENUM_ORDER_TYPE   StringToOrderType(string type);
   string            FormatOrderJson(ulong ticket);
   string            FormatPositionJson(ulong ticket);
   string            FormatErrorResponse(string requestId, int errorCode);
   
public:
                     COrderManager();
                    ~COrderManager();
   
   bool              Initialize();
   void              Cleanup();
   
   // Command handlers
   string            HandleOpenOrder(string command, string requestId, string parameters);
   string            HandleModifyOrder(string command, string requestId, string parameters);
   string            HandleCloseOrder(string command, string requestId, string parameters);
   string            HandleGetOrders(string command, string requestId, string parameters);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
COrderManager::COrderManager()
{
   m_lastCleanupTime = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
{
   // No specific cleanup needed
}

//+------------------------------------------------------------------+
//| Initialize order manager                                          |
//+------------------------------------------------------------------+
bool COrderManager::Initialize()
{
   // Configure trade object
   m_trade.SetDeviationInPoints(DEFAULT_SLIPPAGE);
   m_trade.SetExpertMagicNumber(DEFAULT_MAGIC);
   m_trade.LogLevel(LOG_COMMANDS ? LOG_LEVEL_ALL : LOG_LEVEL_ERRORS);
   
   return true;
}

//+------------------------------------------------------------------+
//| Periodic cleanup of resources                                     |
//+------------------------------------------------------------------+
void COrderManager::Cleanup()
{
   uint currentTime = GetTickCount();
   
   // Only cleanup once per minute
   if(currentTime - m_lastCleanupTime < 60000)
      return;
      
   // Perform cleanup tasks here if needed
   
   m_lastCleanupTime = currentTime;
}

//+------------------------------------------------------------------+
//| Convert order type enum to string                                 |
//+------------------------------------------------------------------+
string COrderManager::OrderTypeToString(ENUM_ORDER_TYPE type)
{
   switch(type)
   {
      case ORDER_TYPE_BUY:             return "BUY";
      case ORDER_TYPE_SELL:            return "SELL";
      case ORDER_TYPE_BUY_LIMIT:       return "BUY_LIMIT";
      case ORDER_TYPE_SELL_LIMIT:      return "SELL_LIMIT";
      case ORDER_TYPE_BUY_STOP:        return "BUY_STOP";
      case ORDER_TYPE_SELL_STOP:       return "SELL_STOP";
      case ORDER_TYPE_BUY_STOP_LIMIT:  return "BUY_STOP_LIMIT";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
      default:                         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Convert string to order type enum                                 |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE COrderManager::StringToOrderType(string type)
{
   if(type == "BUY")              return ORDER_TYPE_BUY;
   if(type == "SELL")             return ORDER_TYPE_SELL;
   if(type == "BUY_LIMIT")        return ORDER_TYPE_BUY_LIMIT;
   if(type == "SELL_LIMIT")       return ORDER_TYPE_SELL_LIMIT;
   if(type == "BUY_STOP")         return ORDER_TYPE_BUY_STOP;
   if(type == "SELL_STOP")        return ORDER_TYPE_SELL_STOP;
   if(type == "BUY_STOP_LIMIT")   return ORDER_TYPE_BUY_STOP_LIMIT;
   if(type == "SELL_STOP_LIMIT")  return ORDER_TYPE_SELL_STOP_LIMIT;
   
   // Default to market buy if unknown
   return ORDER_TYPE_BUY;
}

//+------------------------------------------------------------------+
//| Format an order as JSON                                           |
//+------------------------------------------------------------------+
string COrderManager::FormatOrderJson(ulong ticket)
{
   if(!OrderSelect(ticket))
      return "{}";
      
   string json = "{";
   json += "\"ticket\":" + IntegerToString(ticket) + ",";
   json += "\"symbol\":\"" + OrderGetString(ORDER_SYMBOL) + "\",";
   json += "\"type\":\"" + OrderTypeToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)) + "\",";
   json += "\"volume\":" + DoubleToString(OrderGetDouble(ORDER_VOLUME_INITIAL), 2) + ",";
   json += "\"price\":" + DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN), _Digits) + ",";
   json += "\"sl\":" + DoubleToString(OrderGetDouble(ORDER_SL), _Digits) + ",";
   json += "\"tp\":" + DoubleToString(OrderGetDouble(ORDER_TP), _Digits) + ",";
   json += "\"time\":\"" + TimeToString((datetime)OrderGetInteger(ORDER_TIME_SETUP), TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"comment\":\"" + OrderGetString(ORDER_COMMENT) + "\",";
   json += "\"state\":\"" + EnumToString((ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE)) + "\"";
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Format a position as JSON                                         |
//+------------------------------------------------------------------+
string COrderManager::FormatPositionJson(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return "{}";
      
   string json = "{";
   json += "\"ticket\":" + IntegerToString(ticket) + ",";
   json += "\"symbol\":\"" + PositionGetString(POSITION_SYMBOL) + "\",";
   json += "\"type\":\"" + OrderTypeToString((ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE)) + "\",";
   json += "\"volume\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + ",";
   json += "\"price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits) + ",";
   json += "\"sl\":" + DoubleToString(PositionGetDouble(POSITION_SL), _Digits) + ",";
   json += "\"tp\":" + DoubleToString(PositionGetDouble(POSITION_TP), _Digits) + ",";
   json += "\"time\":\"" + TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + ",";
   json += "\"comment\":\"" + PositionGetString(POSITION_COMMENT) + "\"";
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Format error response                                             |
//+------------------------------------------------------------------+
string COrderManager::FormatErrorResponse(string requestId, int errorCode)
{
   string errorMsg = "Error " + IntegerToString(errorCode) + ": " + ErrorDescription(errorCode);
   
   string response = "{";
   response += "\"status\":\"error\",";
   
   if(requestId != "")
   {
      response += "\"requestId\":\"" + requestId + "\",";
      response += "\"responseToId\":\"" + requestId + "\",";
   }
   
   response += "\"message\":\"" + errorMsg + "\"";
   response += "}";
   
   return response;
}

//+------------------------------------------------------------------+
//| Handle the open_order command                                     |
//+------------------------------------------------------------------+
string COrderManager::HandleOpenOrder(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   string symbol = "";
   string orderTypeStr = "";
   double volume = 0.0;
   double price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   string comment = "";
   
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
         else if(key == "order_type")
            orderTypeStr = value;
         else if(key == "comment")
            comment = value;
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
         if(key == "volume")
            volume = StringToDouble(value);
         else if(key == "price")
            price = StringToDouble(value);
         else if(key == "sl")
            sl = StringToDouble(value);
         else if(key == "tp")
            tp = StringToDouble(value);
      }
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(symbol == "")
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Symbol not specified\"}";
      
   if(orderTypeStr == "")
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Order type not specified\"}";
      
   if(volume <= 0 || volume > MAX_TRADE_VOLUME)
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Invalid volume\"}";
      
   // Convert order type string to enum
   ENUM_ORDER_TYPE orderType = StringToOrderType(orderTypeStr);
   
   // Normalize symbol
   symbol = StringTrimRight(StringTrimLeft(symbol));
   
   // Check if symbol exists
   if(!SymbolSelect(symbol, true))
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Symbol not found: " + symbol + "\"}";
      
   // Prepare trade object
   m_trade.SetDeviationInPoints(DEFAULT_SLIPPAGE);
   m_trade.SetExpertMagicNumber(DEFAULT_MAGIC);
   
   bool result = false;
   ulong ticket = 0;
   
   // Execute order based on type
   switch(orderType)
   {
      case ORDER_TYPE_BUY:
         result = m_trade.Buy(volume, symbol, 0, sl, tp, comment);
         break;
         
      case ORDER_TYPE_SELL:
         result = m_trade.Sell(volume, symbol, 0, sl, tp, comment);
         break;
         
      case ORDER_TYPE_BUY_LIMIT:
         if(price <= 0)
            return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Price must be specified for limit orders\"}";
         result = m_trade.BuyLimit(volume, price, symbol, sl, tp, 0, 0, comment);
         break;
         
      case ORDER_TYPE_SELL_LIMIT:
         if(price <= 0)
            return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Price must be specified for limit orders\"}";
         result = m_trade.SellLimit(volume, price, symbol, sl, tp, 0, 0, comment);
         break;
         
      case ORDER_TYPE_BUY_STOP:
         if(price <= 0)
            return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Price must be specified for stop orders\"}";
         result = m_trade.BuyStop(volume, price, symbol, sl, tp, 0, 0, comment);
         break;
         
      case ORDER_TYPE_SELL_STOP:
         if(price <= 0)
            return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Price must be specified for stop orders\"}";
         result = m_trade.SellStop(volume, price, symbol, sl, tp, 0, 0, comment);
         break;
         
      default:
         return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Unsupported order type: " + orderTypeStr + "\"}";
   }
   
   // Check result
   if(result)
   {
      // Get the ticket of the new order
      ticket = m_trade.ResultOrder();
      
      // Format response
      string json = "";
      
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL)
      {
         // Market order becomes a position
         json = FormatPositionJson(ticket);
      }
      else
      {
         // Pending order
         json = FormatOrderJson(ticket);
      }
      
      return "{\"status\":\"ok\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"data\":" + json + "}";
   }
   else
   {
      // Get error code
      int errorCode = m_trade.ResultRetcode();
      return FormatErrorResponse(requestId, errorCode);
   }
}

//+------------------------------------------------------------------+
//| Handle the modify_order command                                   |
//+------------------------------------------------------------------+
string COrderManager::HandleModifyOrder(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   ulong ticket = 0;
   double price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   
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
      if(key == "ticket")
         ticket = StringToInteger(value);
      else if(key == "price")
         price = StringToDouble(value);
      else if(key == "sl")
         sl = StringToDouble(value);
      else if(key == "tp")
         tp = StringToDouble(value);
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(ticket <= 0)
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Invalid ticket number\"}";
      
   // Check if it's a pending order or open position
   bool isPendingOrder = false;
   bool isPosition = false;
   string symbol = "";
   
   // Check if it's a pending order
   if(OrderSelect(ticket))
   {
      isPendingOrder = true;
      symbol = OrderGetString(ORDER_SYMBOL);
   }
   
   // Check if it's an open position
   if(PositionSelectByTicket(ticket))
   {
      isPosition = true;
      symbol = PositionGetString(POSITION_SYMBOL);
   }
   
   if(!isPendingOrder && !isPosition)
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Order or position not found: " + IntegerToString(ticket) + "\"}";
      
   bool result = false;
   
   // Modify order or position
   if(isPendingOrder)
   {
      // Modify pending order
      double currentPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      if(price <= 0)
         price = currentPrice;
         
      double currentSL = OrderGetDouble(ORDER_SL);
      if(sl <= 0)
         sl = currentSL;
         
      double currentTP = OrderGetDouble(ORDER_TP);
      if(tp <= 0)
         tp = currentTP;
         
      result = m_trade.OrderModify(ticket, price, sl, tp, ORDER_TIME_GTC, 0);
   }
   else if(isPosition)
   {
      // Modify position
      double currentSL = PositionGetDouble(POSITION_SL);
      if(sl <= 0)
         sl = currentSL;
         
      double currentTP = PositionGetDouble(POSITION_TP);
      if(tp <= 0)
         tp = currentTP;
         
      result = m_trade.PositionModify(ticket, sl, tp);
   }
   
   // Check result
   if(result)
   {
      // Format response
      string json = "";
      
      if(isPendingOrder)
      {
         json = FormatOrderJson(ticket);
      }
      else
      {
         json = FormatPositionJson(ticket);
      }
      
      return "{\"status\":\"ok\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"data\":" + json + "}";
   }
   else
   {
      // Get error code
      int errorCode = m_trade.ResultRetcode();
      return FormatErrorResponse(requestId, errorCode);
   }
}

//+------------------------------------------------------------------+
//| Handle the close_order command                                    |
//+------------------------------------------------------------------+
string COrderManager::HandleCloseOrder(string command, string requestId, string parameters)
{
   // Extract parameters from JSON
   ulong ticket = 0;
   double volume = 0.0; // Optional parameter for partial close
   
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
      if(key == "ticket")
         ticket = StringToInteger(value);
      else if(key == "volume")
         volume = StringToDouble(value);
      
      // Move to next parameter
      pos = valueEndPos + 1;
   }
   
   // Validate parameters
   if(ticket <= 0)
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Invalid ticket number\"}";
      
   // Check if it's a pending order or open position
   bool isPendingOrder = false;
   bool isPosition = false;
   
   // Check if it's a pending order
   if(OrderSelect(ticket))
   {
      isPendingOrder = true;
   }
   
   // Check if it's an open position
   if(PositionSelectByTicket(ticket))
   {
      isPosition = true;
   }
   
   if(!isPendingOrder && !isPosition)
      return "{\"status\":\"error\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"message\":\"Order or position not found: " + IntegerToString(ticket) + "\"}";
      
   bool result = false;
   
   // Close order or position
   if(isPendingOrder)
   {
      // Delete pending order
      result = m_trade.OrderDelete(ticket);
   }
   else if(isPosition)
   {
      // Get position volume if needed
      if(volume <= 0)
      {
         volume = PositionGetDouble(POSITION_VOLUME);
      }
      
      // Validate volume
      double positionVolume = PositionGetDouble(POSITION_VOLUME);
      if(volume > positionVolume)
      {
         volume = positionVolume;
      }
      
      // Close position (full or partial)
      result = m_trade.PositionClose(ticket, volume);
   }
   
   // Check result
   if(result)
   {
      return "{\"status\":\"ok\",\"requestId\":\"" + requestId + "\",\"responseToId\":\"" + requestId + "\",\"data\":{\"ticket\":" + IntegerToString(ticket) + "}}";
   }
   else
   {
      // Get error code
      int errorCode = m_trade.ResultRetcode();
      return FormatErrorResponse(requestId, errorCode);
   }
}

//+------------------------------------------------------------------+
//| Handle the get_orders command                                     |
//+------------------------------------------------------------------+
string COrderManager::HandleGetOrders(string command, string requestId, string parameters)
{
   string symbol = "";
   
   // Parse parameters to extract symbol if specified
   int symbolPos = StringFind(parameters, "\"symbol\":");
   if(symbolPos >= 0)
   {
      int valueStart = StringFind(parameters, "\"", symbolPos + 9) + 1;
      int valueEnd = StringFind(parameters, "\"", valueStart);
      
      if(valueStart > 0 && valueEnd > 0)
      {
         symbol = StringSubstr(parameters, valueStart, valueEnd - valueStart);
      }
   }
   
   // Format orders and positions as JSON arrays
   string ordersJson = "[";
   string positionsJson = "[";
   
   // Get pending orders
   int totalOrders = OrdersTotal();
   bool firstOrder = true;
   
   for(int i = 0; i < totalOrders; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0)
         continue;
         
      // Filter by symbol if specified
      if(symbol != "" && OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
         
      // Add comma if not first item
      if(!firstOrder)
         ordersJson += ",";
      else
         firstOrder = false;
         
      // Add order to JSON array
      ordersJson += FormatOrderJson(ticket);
   }
   
   ordersJson += "]";
   
   // Get open positions
   int totalPositions = PositionsTotal();
   bool firstPosition = true;
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
         
      // Filter by symbol if specified
      if(symbol != "" && PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
         
      // Add comma if not first item
      if(!firstPosition)
         positionsJson += ",";
      else
         firstPosition = false;
         
      // Add position to JSON array
      positionsJson += FormatPositionJson(ticket);
   }
   
   positionsJson += "]";
   
   // Format complete response
   string response = "{";
   response += "\"status\":\"ok\",";
   response += "\"requestId\":\"" + requestId + "\",";
   response += "\"responseToId\":\"" + requestId + "\",";
   response += "\"data\":{";
   response += "\"orders\":" + ordersJson + ",";
   response += "\"positions\":" + positionsJson;
   response += "}}";
   
   return response;
}
