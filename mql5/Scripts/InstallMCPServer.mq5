//+------------------------------------------------------------------+
//|                                           InstallMCPServer.mq5 |
//|                                                                  |
//| Installation script for the MCP Server Expert Advisor            |
//+------------------------------------------------------------------+
#property copyright "MCP Server"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("Starting MCP Server installation...");
   
   // Create necessary directories
   string mqlDataPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\";
   
   // Paths for different components
   string expertsPath = mqlDataPath + "\\Experts\\";
   string includePath = mqlDataPath + "\\Include\\";
   string mcpCorePath = includePath + "\\MCPCore\\";
   string scriptsPath = mqlDataPath + "\\Scripts\\";
   
   // Create directories if they don't exist
   if(!DirectoryExists(mcpCorePath))
   {
      if(!CreateDirectory(mcpCorePath))
      {
         Print("Failed to create directory: " + mcpCorePath);
         return;
      }
   }
   
   // Check if EA is already installed
   if(FileExists(expertsPath + "MCPServer.ex5"))
   {
      // Ask user for confirmation to overwrite
      if(!ConfirmOverwrite("MCP Server EA is already installed. Overwrite?"))
      {
         Print("Installation cancelled by user");
         return;
      }
   }
   
   // Copy files from installation directory to appropriate locations
   string installDir = "C:\\metatrader_mcp\\mql5\\";
   
   // Copy Expert Advisor
   if(!CopyFile(installDir + "\\Experts\\MCPServer.mq5", expertsPath + "MCPServer.mq5"))
   {
      Print("Failed to copy MCPServer.mq5 to " + expertsPath);
      return;
   }
   
   // Copy configuration file
   if(!CopyFile(installDir + "\\Include\\MCPConfig.mqh", includePath + "MCPConfig.mqh"))
   {
      Print("Failed to copy MCPConfig.mqh to " + includePath);
      return;
   }
   
   // Copy core files
   if(!CopyFile(installDir + "\\Include\\MCPCore\\CommandProcessor.mqh", mcpCorePath + "CommandProcessor.mqh"))
   {
      Print("Failed to copy CommandProcessor.mqh to " + mcpCorePath);
      return;
   }
   
   if(!CopyFile(installDir + "\\Include\\MCPCore\\SocketHandler.mqh", mcpCorePath + "SocketHandler.mqh"))
   {
      Print("Failed to copy SocketHandler.mqh to " + mcpCorePath);
      return;
   }
   
   if(!CopyFile(installDir + "\\Include\\MCPCore\\OrderManager.mqh", mcpCorePath + "OrderManager.mqh"))
   {
      Print("Failed to copy OrderManager.mqh to " + mcpCorePath);
      return;
   }
   
   if(!CopyFile(installDir + "\\Include\\MCPCore\\ChartManager.mqh", mcpCorePath + "ChartManager.mqh"))
   {
      Print("Failed to copy ChartManager.mqh to " + mcpCorePath);
      return;
   }
   
   if(!CopyFile(installDir + "\\Include\\MCPCore\\DataManager.mqh", mcpCorePath + "DataManager.mqh"))
   {
      Print("Failed to copy DataManager.mqh to " + mcpCorePath);
      return;
   }
   
   // Copy this installation script
   if(!CopyFile(installDir + "\\Scripts\\InstallMCPServer.mq5", scriptsPath + "InstallMCPServer.mq5"))
   {
      Print("Failed to copy InstallMCPServer.mq5 to " + scriptsPath);
      return;
   }
   
   // Compile files
   if(!CompileFile(expertsPath + "MCPServer.mq5"))
   {
      Print("Failed to compile MCPServer.mq5");
      return;
   }
   
   if(!CompileFile(scriptsPath + "InstallMCPServer.mq5"))
   {
      Print("Failed to compile InstallMCPServer.mq5");
      return;
   }
   
   // Display success message
   Print("MCP Server installation completed successfully!");
   Print("To use the MCP Server:");
   Print("1. Attach the MCPServer.ex5 expert advisor to any chart");
   Print("2. Make sure the Python MCP Server is running");
   Print("3. Connect to the MCP Server using the Python client");
   MessageBox("MCP Server installation completed successfully!", "Installation Complete", MB_OK|MB_ICONINFORMATION);
}

//+------------------------------------------------------------------+
//| Check if directory exists                                         |
//+------------------------------------------------------------------+
bool DirectoryExists(string path)
{
   return FileIsExist(path + "\\dummy.tmp", FILE_COMMON) || !FileIsExist(path, FILE_COMMON);
}

//+------------------------------------------------------------------+
//| Create directory                                                  |
//+------------------------------------------------------------------+
bool CreateDirectory(string path)
{
   return FolderCreate(path);
}

//+------------------------------------------------------------------+
//| Copy file from source to destination                              |
//+------------------------------------------------------------------+
bool CopyFile(string source, string destination)
{
   // Check if source file exists
   if(!FileIsExist(source))
   {
      Print("Source file not found: " + source);
      return false;
   }
   
   // Open source file for reading
   int sourceHandle = FileOpen(source, FILE_READ|FILE_BIN);
   if(sourceHandle == INVALID_HANDLE)
   {
      Print("Failed to open source file: " + source);
      return false;
   }
   
   // Get source file size
   ulong fileSize = FileSize(sourceHandle);
   
   // Read source file content
   uchar fileContent[];
   ArrayResize(fileContent, (int)fileSize);
   FileReadArray(sourceHandle, fileContent, 0, (int)fileSize);
   
   // Close source file
   FileClose(sourceHandle);
   
   // Open destination file for writing
   int destHandle = FileOpen(destination, FILE_WRITE|FILE_BIN);
   if(destHandle == INVALID_HANDLE)
   {
      Print("Failed to open destination file: " + destination);
      return false;
   }
   
   // Write content to destination file
   FileWriteArray(destHandle, fileContent, 0, (int)fileSize);
   
   // Close destination file
   FileClose(destHandle);
   
   Print("File copied successfully from " + source + " to " + destination);
   return true;
}

//+------------------------------------------------------------------+
//| Compile MQL5 file                                                 |
//+------------------------------------------------------------------+
bool CompileFile(string path)
{
   // MetaTrader doesn't provide a direct API for compiling files
   // We'll just display a message asking the user to compile manually
   Print("Please compile the following file manually: " + path);
   return true;
}

//+------------------------------------------------------------------+
//| Display confirmation dialog                                       |
//+------------------------------------------------------------------+
bool ConfirmOverwrite(string message)
{
   int result = MessageBox(message, "Confirmation", MB_YESNO|MB_ICONQUESTION);
   return result == IDYES;
}
