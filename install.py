#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
MetaTrader Connection Protocol (MCP) Server Installer
This script installs and configures the MCP Server components.
"""

import os
import sys
import shutil
import platform
import subprocess
import configparser
from pathlib import Path
import uuid

def clear_screen():
    """Clear the console screen"""
    os.system('cls' if os.name == 'nt' else 'clear')

def print_banner():
    """Print installer banner"""
    clear_screen()
    print("=" * 80)
    print(" " * 25 + "MCP SERVER INSTALLER")
    print("=" * 80)
    print("\nThis installer will set up the MetaTrader Connection Protocol (MCP) Server.\n")

def get_mt5_path():
    """Try to locate MetaTrader 5 installation directory"""
    possible_paths = []
    
    if platform.system() == "Windows":
        # Common MT5 installation locations on Windows
        program_files = os.environ.get("ProgramFiles", "C:\\Program Files")
        program_files_x86 = os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")
        
        possible_paths = [
            Path(program_files) / "MetaTrader 5",
            Path(program_files_x86) / "MetaTrader 5",
            Path("C:\\Program Files") / "MetaTrader 5",
            Path("C:\\Program Files (x86)") / "MetaTrader 5"
        ]
    
    # Add custom paths if needed for other operating systems
    
    # Check which paths exist
    valid_paths = [str(p) for p in possible_paths if p.exists()]
    
    return valid_paths

def get_mt5_data_path():
    """Try to locate MetaTrader 5 data directory"""
    possible_paths = []
    
    if platform.system() == "Windows":
        # Common MT5 data locations on Windows
        appdata = os.environ.get("APPDATA", "")
        documents = os.path.expanduser("~/Documents")
        
        possible_paths = [
            Path(appdata) / "MetaQuotes" / "Terminal",
            Path(documents) / "MetaQuotes" / "Terminal"
        ]
    
    # Check which paths exist
    valid_dirs = []
    
    for base_path in possible_paths:
        if base_path.exists():
            # Look for MQL5 directories in subfolders
            for subdir in base_path.iterdir():
                if subdir.is_dir() and (subdir / "MQL5").exists():
                    valid_dirs.append(str(subdir))
    
    return valid_dirs

def install_python_components(install_dir):
    """Install Python components"""
    print("\nInstalling Python components...")
    
    # Create directories
    python_dir = os.path.join(install_dir, "python")
    os.makedirs(python_dir, exist_ok=True)
    
    # Copy Python files
    source_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Copy server file
    shutil.copy2(
        os.path.join(source_dir, "python", "mcp_server.py"), 
        os.path.join(python_dir, "mcp_server.py")
    )
    
    # Copy client file
    shutil.copy2(
        os.path.join(source_dir, "python", "mcp_client.py"), 
        os.path.join(python_dir, "mcp_client.py")
    )
    
    # Copy requirements file
    shutil.copy2(
        os.path.join(source_dir, "python", "requirements.txt"), 
        os.path.join(python_dir, "requirements.txt")
    )
    
    # Create config file
    config = configparser.ConfigParser()
    config["SERVER"] = {
        "host": "127.0.0.1",
        "port": "5555",
        "auth_enabled": "true",
        "max_clients": "10"
    }
    
    # Generate default auth token
    default_token = str(uuid.uuid4())
    config["AUTH_TOKENS"] = {
        default_token: "all"
    }
    
    with open(os.path.join(python_dir, "mcp_config.ini"), "w") as config_file:
        config.write(config_file)
    
    print("Python components installed successfully.")
    print(f"Default authentication token: {default_token}")
    print("Please keep this token secure, it will be needed to connect to the server.")
    
    return True

def install_mql5_components(install_dir, mt5_data_dir=None):
    """Install MQL5 components"""
    print("\nInstalling MQL5 components...")
    
    # Source directory is the current installation directory
    source_dir = os.path.dirname(os.path.abspath(__file__))
    mql5_dir = os.path.join(source_dir, "mql5")
    
    # If MetaTrader 5 data directory is provided, copy files there
    if mt5_data_dir:
        mt5_mql5_dir = os.path.join(mt5_data_dir, "MQL5")
        
        # Create directories
        os.makedirs(os.path.join(mt5_mql5_dir, "Experts"), exist_ok=True)
        os.makedirs(os.path.join(mt5_mql5_dir, "Include"), exist_ok=True)
        os.makedirs(os.path.join(mt5_mql5_dir, "Include", "MCPCore"), exist_ok=True)
        os.makedirs(os.path.join(mt5_mql5_dir, "Scripts"), exist_ok=True)
        
        # Copy files to MT5 data directory
        shutil.copy2(
            os.path.join(mql5_dir, "Experts", "MCPServer.mq5"), 
            os.path.join(mt5_mql5_dir, "Experts", "MCPServer.mq5")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPConfig.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPConfig.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPCore", "CommandProcessor.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPCore", "CommandProcessor.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPCore", "SocketHandler.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPCore", "SocketHandler.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPCore", "OrderManager.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPCore", "OrderManager.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPCore", "ChartManager.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPCore", "ChartManager.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Include", "MCPCore", "DataManager.mqh"), 
            os.path.join(mt5_mql5_dir, "Include", "MCPCore", "DataManager.mqh")
        )
        
        shutil.copy2(
            os.path.join(mql5_dir, "Scripts", "InstallMCPServer.mq5"), 
            os.path.join(mt5_mql5_dir, "Scripts", "InstallMCPServer.mq5")
        )
        
        print(f"MQL5 components installed to MetaTrader 5 directory: {mt5_data_dir}")
    
    print("MQL5 components installed successfully.")
    return True

def install_documentation(install_dir):
    """Install documentation"""
    print("\nInstalling documentation...")
    
    # Create docs directory
    docs_dir = os.path.join(install_dir, "docs")
    os.makedirs(docs_dir, exist_ok=True)
    
    # Copy README file
    source_dir = os.path.dirname(os.path.abspath(__file__))
    
    shutil.copy2(
        os.path.join(source_dir, "docs", "README.md"), 
        os.path.join(docs_dir, "README.md")
    )
    
    # Create COMMANDS.md file
    with open(os.path.join(docs_dir, "COMMANDS.md"), "w") as commands_file:
        commands_file.write("# MCP Server Command Reference\n\n")
        commands_file.write("This document provides a reference for all commands supported by the MCP Server.\n\n")
        
        # Trading Operations
        commands_file.write("## Trading Operations\n\n")
        commands_file.write("### open_order\n")
        commands_file.write("Opens a new position or pending order.\n\n")
        commands_file.write("**Parameters:**\n")
        commands_file.write("- `symbol` (string): Symbol name (e.g., 'EURUSD')\n")
        commands_file.write("- `order_type` (string): Order type ('BUY', 'SELL', 'BUY_LIMIT', 'SELL_LIMIT', etc.)\n")
        commands_file.write("- `volume` (double): Order volume in lots\n")
        commands_file.write("- `price` (double, optional): Order price (required for pending orders)\n")
        commands_file.write("- `sl` (double, optional): Stop Loss level\n")
        commands_file.write("- `tp` (double, optional): Take Profit level\n")
        commands_file.write("- `comment` (string, optional): Order comment\n\n")
        
        # Add other commands documentation...
    
    # Create INSTALLATION.md file
    with open(os.path.join(docs_dir, "INSTALLATION.md"), "w") as install_file:
        install_file.write("# MCP Server Installation Guide\n\n")
        install_file.write("This document provides detailed installation instructions for the MCP Server.\n\n")
        
        install_file.write("## Prerequisites\n\n")
        install_file.write("- MetaTrader 5 platform installed\n")
        install_file.write("- Python 3.6 or higher\n")
        install_file.write("- Required Python packages: `socket`, `json`, `threading`, `time`, `uuid`, `logging`\n\n")
        
        install_file.write("## Installation Steps\n\n")
        install_file.write("1. Run the installer script: `python install.py`\n")
        install_file.write("2. Follow the on-screen instructions\n")
        install_file.write("3. Start the Python MCP Server\n")
        install_file.write("4. Load the MCP Expert Advisor in MetaTrader 5\n\n")
        
        # Add more installation details...
    
    print("Documentation installed successfully.")
    return True

def main():
    """Main installer function"""
    print_banner()
    
    # Get installation directory
    default_install_dir = "C:\\metatrader_mcp"
    install_dir = input(f"Enter installation directory [{default_install_dir}]: ").strip()
    if not install_dir:
        install_dir = default_install_dir
    
    # Create installation directory
    os.makedirs(install_dir, exist_ok=True)
    
    # Install Python components
    if not install_python_components(install_dir):
        print("Failed to install Python components.")
        return False
    
    # Look for MetaTrader 5 installation
    mt5_paths = get_mt5_path()
    mt5_data_paths = get_mt5_data_path()
    
    mt5_data_dir = None
    if mt5_paths:
        print("\nFound MetaTrader 5 installations:")
        for i, path in enumerate(mt5_paths):
            print(f"{i+1}. {path}")
    
    if mt5_data_paths:
        print("\nFound MetaTrader 5 data directories:")
        for i, path in enumerate(mt5_data_paths):
            print(f"{i+1}. {path}")
        
        choice = input("\nSelect MetaTrader 5 data directory (enter number or 0 to skip): ").strip()
        if choice and choice.isdigit() and 1 <= int(choice) <= len(mt5_data_paths):
            mt5_data_dir = mt5_data_paths[int(choice) - 1]
    
    # Install MQL5 components
    if not install_mql5_components(install_dir, mt5_data_dir):
        print("Failed to install MQL5 components.")
        return False
    
    # Install documentation
    if not install_documentation(install_dir):
        print("Failed to install documentation.")
        return False
    
    print("\n" + "=" * 80)
    print(" " * 25 + "INSTALLATION COMPLETE")
    print("=" * 80)
    
    print(f"\nMCP Server has been installed to: {install_dir}")
    print("\nTo start the server:")
    print(f"1. Run: python {os.path.join(install_dir, 'python', 'mcp_server.py')}")
    print("2. Open MetaTrader 5 and attach the MCPServer Expert Advisor to any chart")
    
    if mt5_data_dir:
        print(f"\nMQL5 components have been installed to: {mt5_data_dir}")
        print("You can now compile and use the Expert Advisor directly.")
    else:
        print("\nMQL5 components have been installed to the local directory.")
        print("You will need to manually copy them to your MetaTrader 5 data directory.")
    
    print("\nSee the documentation in the 'docs' directory for more information.")
    
    return True

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInstallation cancelled by user.")
    except Exception as e:
        print(f"\nInstallation failed: {str(e)}")
