#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
MetaTrader Connection Protocol (MCP) Client
This module provides a client interface to connect to the MCP Server and interact with MetaTrader 5.
"""

import socket
import json
import time
import uuid
import logging
import threading
import sys
from typing import Dict, List, Any, Union, Tuple, Optional, Callable

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mcp_client.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('MCPClient')

class MCPClient:
    """
    Client for connecting to the MCP Server and sending commands to MetaTrader 5
    """
    def __init__(self, host: str = '127.0.0.1', port: int = 5555, 
                 auth_token: Optional[str] = None) -> None:
        """
        Initialize the MCP Client
        
        Args:
            host: MCP Server hostname or IP
            port: MCP Server port
            auth_token: Authentication token (if required by server)
        """
        self.host = host
        self.port = port
        self.auth_token = auth_token
        self.socket = None
        self.connected = False
        self.authenticated = False
        self.receive_thread = None
        self.running = False
        self.callbacks = {}  # Callbacks for request IDs
        self.default_callback = None  # Default callback for all responses
        self.response_lock = threading.Lock()
        self.response_event = threading.Event()
        self.last_response = None
        
        logger.info(f"MCP Client initialized with host={host}, port={port}")
        
    def connect(self, timeout: int = 10) -> bool:
        """
        Connect to the MCP Server
        
        Args:
            timeout: Connection timeout in seconds
            
        Returns:
            True if connection successful, False otherwise
        """
        if self.connected:
            logger.warning("Already connected to MCP Server")
            return True
            
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(timeout)
            self.socket.connect((self.host, self.port))
            self.connected = True
            self.running = True
            
            # Start receive thread
            self.receive_thread = threading.Thread(target=self._receive_messages)
            self.receive_thread.daemon = True
            self.receive_thread.start()
            
            logger.info(f"Connected to MCP Server at {self.host}:{self.port}")
            
            # Authenticate if token provided
            if self.auth_token:
                return self.authenticate()
            
            return True
            
        except Exception as e:
            logger.error(f"Error connecting to MCP Server: {str(e)}")
            self.disconnect()
            return False
            
    def disconnect(self) -> None:
        """
        Disconnect from the MCP Server
        """
        self.running = False
        self.connected = False
        self.authenticated = False
        
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
            self.socket = None
            
        logger.info("Disconnected from MCP Server")
        
    def authenticate(self) -> bool:
        """
        Authenticate with the MCP Server using the provided token
        
        Returns:
            True if authentication successful, False otherwise
        """
        if not self.connected:
            logger.error("Not connected to MCP Server")
            return False
            
        if not self.auth_token:
            logger.error("No authentication token provided")
            return False
            
        try:
            # Send authentication request
            auth_message = json.dumps({
                'auth': self.auth_token
            })
            
            self.socket.sendall(auth_message.encode('utf-8'))
            
            # Wait for response
            self.response_event.clear()
            if not self.response_event.wait(timeout=10):
                logger.error("Authentication timeout")
                return False
                
            # Check response
            response = self.last_response
            if response and response.get('status') == 'authenticated':
                self.authenticated = True
                logger.info("Authentication successful")
                return True
            else:
                logger.error(f"Authentication failed: {response.get('message', 'Unknown error')}")
                return False
                
        except Exception as e:
            logger.error(f"Error during authentication: {str(e)}")
            return False
            
    def send_command(self, command: str, parameters: Dict[str, Any] = None, 
                     callback: Optional[Callable] = None, timeout: int = 30) -> Dict[str, Any]:
        """
        Send a command to the MCP Server and wait for response
        
        Args:
            command: Command name
            parameters: Command parameters
            callback: Optional callback function for asynchronous response handling
            timeout: Timeout for synchronous response in seconds
            
        Returns:
            Response data dictionary (for synchronous calls) or request ID (for async calls)
        """
        if not self.connected:
            logger.error("Not connected to MCP Server")
            return {'status': 'error', 'message': 'Not connected to MCP Server'}
            
        if self.auth_token and not self.authenticated:
            logger.error("Not authenticated with MCP Server")
            return {'status': 'error', 'message': 'Not authenticated with MCP Server'}
            
        # Generate request ID
        request_id = str(uuid.uuid4())
        
        # Prepare command message
        message = {
            'command': command,
            'requestId': request_id,
            'parameters': parameters or {}
        }
        
        # Add auth token if available
        if self.auth_token:
            message['auth'] = self.auth_token
            
        try:
            # Register callback if provided
            if callback:
                with self.response_lock:
                    self.callbacks[request_id] = callback
                
                # Send message
                self.socket.sendall(json.dumps(message).encode('utf-8'))
                logger.debug(f"Command '{command}' sent with request ID {request_id} (async)")
                
                # Return request ID for async tracking
                return {'status': 'sent', 'requestId': request_id}
                
            else:
                # For synchronous calls, set up response waiting
                self.response_event.clear()
                
                # Clear previous response
                self.last_response = None
                
                # Register temporary callback
                with self.response_lock:
                    self.callbacks[request_id] = self._sync_response_callback
                
                # Send message
                self.socket.sendall(json.dumps(message).encode('utf-8'))
                logger.debug(f"Command '{command}' sent with request ID {request_id} (sync)")
                
                # Wait for response with timeout
                if not self.response_event.wait(timeout=timeout):
                    logger.warning(f"Timeout waiting for response to command '{command}'")
                    
                    # Remove callback
                    with self.response_lock:
                        if request_id in self.callbacks:
                            del self.callbacks[request_id]
                            
                    return {'status': 'error', 'message': 'Response timeout'}
                    
                # Return the response
                response = self.last_response
                if response:
                    return response
                else:
                    return {'status': 'error', 'message': 'Empty response'}
                    
        except Exception as e:
            logger.error(f"Error sending command '{command}': {str(e)}")
            return {'status': 'error', 'message': str(e)}
            
    def _receive_messages(self) -> None:
        """
        Background thread for receiving messages from the server
        """
        buffer_size = 4096
        
        while self.running and self.socket:
            try:
                data = self.socket.recv(buffer_size)
                if not data:
                    logger.warning("Server closed connection")
                    self.disconnect()
                    break
                    
                # Process received data
                message = data.decode('utf-8')
                self._process_response(message)
                
            except socket.timeout:
                # Just a timeout, continue
                continue
                
            except Exception as e:
                if self.running:
                    logger.error(f"Error receiving data: {str(e)}")
                    self.disconnect()
                break
                
    def _process_response(self, message: str) -> None:
        """
        Process a response message from the server
        
        Args:
            message: Response message string
        """
        try:
            # Parse JSON response
            response = json.loads(message)
            
            # Get request ID if available
            request_id = response.get('requestId')
            
            if request_id:
                # Find and call the appropriate callback
                callback = None
                with self.response_lock:
                    if request_id in self.callbacks:
                        callback = self.callbacks[request_id]
                        
                        # Remove one-time callbacks (not sync callback)
                        if callback != self._sync_response_callback:
                            del self.callbacks[request_id]
                            
                if callback:
                    try:
                        callback(response)
                    except Exception as e:
                        logger.error(f"Error in callback for request {request_id}: {str(e)}")
                        
            # Call default callback if set
            if self.default_callback:
                try:
                    self.default_callback(response)
                except Exception as e:
                    logger.error(f"Error in default callback: {str(e)}")
                    
        except json.JSONDecodeError:
            logger.error("Invalid JSON response from server")
            
        except Exception as e:
            logger.error(f"Error processing response: {str(e)}")
            
    def _sync_response_callback(self, response: Dict[str, Any]) -> None:
        """
        Callback for synchronous command responses
        
        Args:
            response: Response data
        """
        self.last_response = response
        self.response_event.set()
        
    def set_default_callback(self, callback: Callable) -> None:
        """
        Set a default callback for all responses
        
        Args:
            callback: Callback function
        """
        self.default_callback = callback
        
    def remove_callback(self, request_id: str) -> bool:
        """
        Remove a callback for a specific request ID
        
        Args:
            request_id: Request ID
            
        Returns:
            True if callback was removed, False otherwise
        """
        with self.response_lock:
            if request_id in self.callbacks:
                del self.callbacks[request_id]
                return True
        return False
        
    def is_connected(self) -> bool:
        """
        Check if client is connected to the server
        
        Returns:
            True if connected, False otherwise
        """
        return self.connected
        
    def is_authenticated(self) -> bool:
        """
        Check if client is authenticated with the server
        
        Returns:
            True if authenticated, False otherwise
        """
        return self.authenticated
        
    # Convenience methods for common MetaTrader operations
    
    def get_account_info(self) -> Dict[str, Any]:
        """
        Get account information
        
        Returns:
            Account information dictionary
        """
        return self.send_command('get_account_info')
        
    def get_price(self, symbol: str) -> Dict[str, Any]:
        """
        Get current price for a symbol
        
        Args:
            symbol: Symbol name (e.g. 'EURUSD')
            
        Returns:
            Price information dictionary
        """
        return self.send_command('get_price', {'symbol': symbol})
        
    def open_order(self, symbol: str, order_type: str, volume: float, 
                   price: Optional[float] = None, sl: Optional[float] = None, 
                   tp: Optional[float] = None, comment: str = '') -> Dict[str, Any]:
        """
        Open a new order
        
        Args:
            symbol: Symbol name (e.g. 'EURUSD')
            order_type: Order type ('BUY', 'SELL', 'BUY_LIMIT', 'SELL_LIMIT', etc.)
            volume: Order volume in lots
            price: Order price (for limit and stop orders)
            sl: Stop Loss level
            tp: Take Profit level
            comment: Order comment
            
        Returns:
            Order result dictionary
        """
        parameters = {
            'symbol': symbol,
            'order_type': order_type,
            'volume': volume,
            'comment': comment
        }
        
        if price is not None:
            parameters['price'] = price
            
        if sl is not None:
            parameters['sl'] = sl
            
        if tp is not None:
            parameters['tp'] = tp
            
        return self.send_command('open_order', parameters)
        
    def close_order(self, ticket: int) -> Dict[str, Any]:
        """
        Close an existing order
        
        Args:
            ticket: Order ticket number
            
        Returns:
            Close result dictionary
        """
        return self.send_command('close_order', {'ticket': ticket})
        
    def modify_order(self, ticket: int, price: Optional[float] = None, 
                     sl: Optional[float] = None, tp: Optional[float] = None) -> Dict[str, Any]:
        """
        Modify an existing order
        
        Args:
            ticket: Order ticket number
            price: New order price (for pending orders)
            sl: New Stop Loss level
            tp: New Take Profit level
            
        Returns:
            Modification result dictionary
        """
        parameters = {'ticket': ticket}
        
        if price is not None:
            parameters['price'] = price
            
        if sl is not None:
            parameters['sl'] = sl
            
        if tp is not None:
            parameters['tp'] = tp
            
        return self.send_command('modify_order', parameters)
        
    def get_orders(self) -> Dict[str, Any]:
        """
        Get list of open orders
        
        Returns:
            Dictionary with list of open orders
        """
        return self.send_command('get_orders')
        
    def get_history(self, symbol: str, timeframe: str, bars: int = 100) -> Dict[str, Any]:
        """
        Get historical data for a symbol
        
        Args:
            symbol: Symbol name (e.g. 'EURUSD')
            timeframe: Timeframe (e.g. 'M1', 'M5', 'H1', 'D1')
            bars: Number of bars to get
            
        Returns:
            Dictionary with historical data
        """
        parameters = {
            'symbol': symbol,
            'timeframe': timeframe,
            'bars': bars
        }
        
        return self.send_command('get_history', parameters)
        

# Example usage
if __name__ == '__main__':
    # Example callback function
    def on_response(response):
        print(f"Received: {json.dumps(response, indent=2)}")
        
    # Create client and connect
    client = MCPClient(host='127.0.0.1', port=5555)
    
    if client.connect():
        # Set default callback for all responses
        client.set_default_callback(on_response)
        
        # Example commands
        print("Getting account info...")
        client.get_account_info()
        
        print("Getting EURUSD price...")
        client.get_price('EURUSD')
        
        # Wait a bit for responses
        time.sleep(2)
        
        # Disconnect
        client.disconnect()
    else:
        print("Failed to connect to MCP Server")
