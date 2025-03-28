#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
MetaTrader Connection Protocol (MCP) Server
This script provides a socket server that acts as a bridge between external applications
and MetaTrader 5 via a connected MQL5 Expert Advisor.
"""

import os
import sys
import json
import socket
import logging
import threading
import time
import uuid
import argparse
import configparser
from datetime import datetime
from typing import Dict, List, Any, Union, Tuple, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mcp_server.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('MCPServer')

class MCPServer:
    """
    Main MCP Server class that handles socket connections from clients and the MetaTrader EA.
    """
    def __init__(self, host: str = '127.0.0.1', port: int = 5555, 
                 auth_enabled: bool = True, max_clients: int = 10) -> None:
        """
        Initialize the MCP Server with specified parameters
        
        Args:
            host: Hostname or IP to bind the server to
            port: Port number to listen on
            auth_enabled: Whether authentication is required
            max_clients: Maximum number of simultaneous client connections
        """
        self.host = host
        self.port = port
        self.auth_enabled = auth_enabled
        self.max_clients = max_clients
        self.server_socket = None
        self.running = False
        self.clients = {}  # Dictionary to store client connections
        self.mt5_connection = None  # Connection to the MetaTrader EA
        self.command_queue = []  # Queue of commands to be processed
        self.response_cache = {}  # Cache of responses from MT5
        self.auth_tokens = self._load_auth_tokens()  # Load auth tokens from config
        
        # Create locks for thread safety
        self.clients_lock = threading.Lock()
        self.queue_lock = threading.Lock()
        self.cache_lock = threading.Lock()
        
        logger.info(f"MCP Server initialized with host={host}, port={port}")
        
    def _load_auth_tokens(self) -> Dict[str, Dict[str, Any]]:
        """
        Load authentication tokens from configuration file
        
        Returns:
            Dictionary of auth tokens and their permissions
        """
        tokens = {}
        config = configparser.ConfigParser()
        config_file = os.path.join(os.path.dirname(__file__), 'mcp_config.ini')
        
        if os.path.exists(config_file):
            try:
                config.read(config_file)
                if 'AUTH_TOKENS' in config:
                    for token, permissions in config['AUTH_TOKENS'].items():
                        tokens[token] = {
                            'permissions': permissions.split(','),
                            'created_at': datetime.now().isoformat()
                        }
                logger.info(f"Loaded {len(tokens)} auth tokens from config")
            except Exception as e:
                logger.error(f"Error loading auth tokens: {str(e)}")
        else:
            # Create default token if no config exists
            default_token = str(uuid.uuid4())
            tokens[default_token] = {
                'permissions': ['all'],
                'created_at': datetime.now().isoformat()
            }
            
            # Save default token to config
            config['AUTH_TOKENS'] = {default_token: 'all'}
            try:
                os.makedirs(os.path.dirname(config_file), exist_ok=True)
                with open(config_file, 'w') as f:
                    config.write(f)
                logger.info(f"Created default auth token: {default_token}")
            except Exception as e:
                logger.error(f"Error saving default auth token: {str(e)}")
                
        return tokens
    
    def start(self) -> None:
        """
        Start the MCP Server and begin listening for connections
        """
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(self.max_clients)
            self.running = True
            
            logger.info(f"MCP Server started on {self.host}:{self.port}")
            
            # Start command processor thread
            command_thread = threading.Thread(target=self._process_command_queue)
            command_thread.daemon = True
            command_thread.start()
            
            # Main server loop
            while self.running:
                try:
                    client_socket, address = self.server_socket.accept()
                    client_thread = threading.Thread(
                        target=self._handle_client,
                        args=(client_socket, address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                except Exception as e:
                    if self.running:
                        logger.error(f"Error accepting connection: {str(e)}")
                        time.sleep(0.1)
                        
        except Exception as e:
            logger.error(f"Error starting server: {str(e)}")
        finally:
            self.stop()
            
    def stop(self) -> None:
        """
        Stop the MCP Server and close all connections
        """
        self.running = False
        
        # Close all client connections
        with self.clients_lock:
            for client_id, client_info in self.clients.items():
                try:
                    client_info['socket'].close()
                except:
                    pass
            self.clients.clear()
        
        # Close MetaTrader connection if exists
        if self.mt5_connection:
            try:
                self.mt5_connection.close()
            except:
                pass
            self.mt5_connection = None
            
        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
            self.server_socket = None
            
        logger.info("MCP Server stopped")
        
    def _handle_client(self, client_socket: socket.socket, address: Tuple[str, int]) -> None:
        """
        Handle client connection and process incoming messages
        
        Args:
            client_socket: Socket object for client connection
            address: Client address (IP, port)
        """
        client_id = str(uuid.uuid4())
        client_type = 'unknown'
        authenticated = not self.auth_enabled
        
        logger.info(f"New connection from {address[0]}:{address[1]}, assigned ID: {client_id}")
        
        try:
            # Set socket timeout
            client_socket.settimeout(60)
            
            # Add to clients dictionary
            with self.clients_lock:
                self.clients[client_id] = {
                    'socket': client_socket,
                    'address': address,
                    'type': client_type,
                    'authenticated': authenticated,
                    'last_activity': time.time()
                }
            
            # Receive data from client
            buffer_size = 4096
            while self.running:
                try:
                    data = client_socket.recv(buffer_size)
                    if not data:
                        logger.info(f"Client {client_id} disconnected")
                        break
                    
                    # Update last activity time
                    with self.clients_lock:
                        if client_id in self.clients:
                            self.clients[client_id]['last_activity'] = time.time()
                    
                    # Process received data
                    message = data.decode('utf-8')
                    self._process_message(client_id, message)
                    
                except socket.timeout:
                    # Check if client is still active
                    with self.clients_lock:
                        if client_id in self.clients:
                            if time.time() - self.clients[client_id]['last_activity'] > 120:
                                logger.info(f"Client {client_id} timed out")
                                break
                            
                except Exception as e:
                    logger.error(f"Error receiving data from client {client_id}: {str(e)}")
                    break
                    
        except Exception as e:
            logger.error(f"Error handling client {client_id}: {str(e)}")
            
        finally:
            # Close connection and remove from clients
            try:
                client_socket.close()
            except:
                pass
                
            with self.clients_lock:
                if client_id in self.clients:
                    del self.clients[client_id]
                    
            logger.info(f"Connection closed for client {client_id}")
            
    def _process_message(self, client_id: str, message: str) -> None:
        """
        Process message received from client
        
        Args:
            client_id: Client identifier
            message: Message received from client
        """
        try:
            # Parse JSON message
            data = json.loads(message)
            
            # Check if identification message (from MT5 EA)
            if 'identity' in data and data['identity'] == 'MT5_EA':
                with self.clients_lock:
                    if client_id in self.clients:
                        self.clients[client_id]['type'] = 'mt5_ea'
                        self.mt5_connection = self.clients[client_id]['socket']
                        
                        # Send acknowledgment
                        self._send_to_client(client_id, json.dumps({
                            'status': 'connected',
                            'server_time': datetime.now().isoformat()
                        }))
                        
                        logger.info(f"Client {client_id} identified as MT5 EA")
                        return
                        
            # Check if authentication message
            if 'auth' in data and not self._is_client_authenticated(client_id):
                auth_token = data['auth']
                if self._authenticate_client(client_id, auth_token):
                    # Send successful authentication response
                    self._send_to_client(client_id, json.dumps({
                        'status': 'authenticated',
                        'message': 'Authentication successful'
                    }))
                    logger.info(f"Client {client_id} authenticated successfully")
                else:
                    # Send authentication failure response
                    self._send_to_client(client_id, json.dumps({
                        'status': 'error',
                        'message': 'Authentication failed'
                    }))
                    logger.warning(f"Authentication failed for client {client_id}")
                return
                
            # Check if client is authenticated for command processing
            if not self._is_client_authenticated(client_id):
                self._send_to_client(client_id, json.dumps({
                    'status': 'error',
                    'message': 'Not authenticated'
                }))
                logger.warning(f"Unauthenticated command attempt from client {client_id}")
                return
                
            # Process command
            if 'command' in data:
                command = data['command']
                request_id = data.get('requestId', str(uuid.uuid4()))
                parameters = data.get('parameters', {})
                
                # Handle command processing based on client type
                client_type = self._get_client_type(client_id)
                
                if client_type == 'mt5_ea':
                    # Handle response from MT5 EA
                    if 'responseToId' in data:
                        response_to = data['responseToId']
                        with self.cache_lock:
                            self.response_cache[response_to] = {
                                'data': data,
                                'timestamp': time.time()
                            }
                            logger.debug(f"Cached response for request {response_to}")
                    
                else:
                    # Add command to processing queue
                    with self.queue_lock:
                        self.command_queue.append({
                            'client_id': client_id,
                            'command': command,
                            'parameters': parameters,
                            'request_id': request_id,
                            'timestamp': time.time()
                        })
                        logger.debug(f"Added command '{command}' to queue (request_id: {request_id})")
                    
                    # Send acknowledgment to client
                    self._send_to_client(client_id, json.dumps({
                        'status': 'queued',
                        'requestId': request_id,
                        'message': f"Command '{command}' queued for processing"
                    }))
                    
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON received from client {client_id}")
            self._send_to_client(client_id, json.dumps({
                'status': 'error',
                'message': 'Invalid JSON format'
            }))
            
        except Exception as e:
            logger.error(f"Error processing message from client {client_id}: {str(e)}")
            
    def _process_command_queue(self) -> None:
        """
        Process the command queue in a separate thread
        """
        while self.running:
            try:
                command_item = None
                
                # Get next command from queue
                with self.queue_lock:
                    if self.command_queue:
                        command_item = self.command_queue.pop(0)
                
                if command_item:
                    self._execute_command(command_item)
                else:
                    # No commands to process, sleep a bit
                    time.sleep(0.1)
                    
            except Exception as e:
                logger.error(f"Error in command processing thread: {str(e)}")
                time.sleep(1)  # Prevent CPU spinning on errors
                
    def _execute_command(self, command_item: Dict[str, Any]) -> None:
        """
        Execute a command from the queue
        
        Args:
            command_item: Command information dictionary
        """
        client_id = command_item['client_id']
        command = command_item['command']
        parameters = command_item['parameters']
        request_id = command_item['request_id']
        
        logger.info(f"Executing command '{command}' (request_id: {request_id})")
        
        # Check if MT5 EA is connected
        if not self.mt5_connection:
            error_msg = "MetaTrader EA not connected"
            logger.error(f"{error_msg} - cannot execute command '{command}'")
            self._send_to_client(client_id, json.dumps({
                'status': 'error',
                'requestId': request_id,
                'message': error_msg
            }))
            return
            
        try:
            # Forward command to MT5 EA
            mt5_message = json.dumps({
                'command': command,
                'parameters': parameters,
                'requestId': request_id,
                'timestamp': datetime.now().isoformat()
            })
            
            self.mt5_connection.sendall(mt5_message.encode('utf-8'))
            logger.debug(f"Command '{command}' sent to MT5 EA")
            
            # Wait for response with timeout
            max_wait_time = 30  # seconds
            start_time = time.time()
            
            while time.time() - start_time < max_wait_time:
                # Check if response is in cache
                with self.cache_lock:
                    if request_id in self.response_cache:
                        response_data = self.response_cache[request_id]['data']
                        del self.response_cache[request_id]
                        
                        # Forward response to client
                        self._send_to_client(client_id, json.dumps(response_data))
                        logger.debug(f"Response for request {request_id} forwarded to client")
                        return
                        
                # Sleep a bit before checking again
                time.sleep(0.1)
                
            # Timeout occurred
            logger.warning(f"Timeout waiting for response to command '{command}' (request_id: {request_id})")
            self._send_to_client(client_id, json.dumps({
                'status': 'error',
                'requestId': request_id,
                'message': 'Timeout waiting for response from MetaTrader'
            }))
            
        except Exception as e:
            logger.error(f"Error executing command '{command}': {str(e)}")
            self._send_to_client(client_id, json.dumps({
                'status': 'error',
                'requestId': request_id,
                'message': f"Error executing command: {str(e)}"
            }))
            
    def _send_to_client(self, client_id: str, message: str) -> bool:
        """
        Send message to a specific client
        
        Args:
            client_id: Client identifier
            message: Message to send
            
        Returns:
            True if successful, False otherwise
        """
        try:
            with self.clients_lock:
                if client_id in self.clients:
                    client_socket = self.clients[client_id]['socket']
                    client_socket.sendall(message.encode('utf-8'))
                    return True
                else:
                    logger.warning(f"Attempted to send message to non-existent client {client_id}")
            return False
        except Exception as e:
            logger.error(f"Error sending message to client {client_id}: {str(e)}")
            return False
            
    def _is_client_authenticated(self, client_id: str) -> bool:
        """
        Check if client is authenticated
        
        Args:
            client_id: Client identifier
            
        Returns:
            True if authenticated or auth disabled, False otherwise
        """
        if not self.auth_enabled:
            return True
            
        with self.clients_lock:
            if client_id in self.clients:
                return self.clients[client_id]['authenticated']
        return False
        
    def _authenticate_client(self, client_id: str, token: str) -> bool:
        """
        Authenticate a client using the provided token
        
        Args:
            client_id: Client identifier
            token: Authentication token
            
        Returns:
            True if authentication successful, False otherwise
        """
        if not self.auth_enabled:
            return True
            
        if token in self.auth_tokens:
            with self.clients_lock:
                if client_id in self.clients:
                    self.clients[client_id]['authenticated'] = True
                    return True
                    
        return False
        
    def _get_client_type(self, client_id: str) -> str:
        """
        Get client type
        
        Args:
            client_id: Client identifier
            
        Returns:
            Client type ('mt5_ea', 'client', or 'unknown')
        """
        with self.clients_lock:
            if client_id in self.clients:
                return self.clients[client_id].get('type', 'unknown')
        return 'unknown'
        
    def _clean_expired_cache(self) -> None:
        """
        Clean expired items from response cache
        """
        current_time = time.time()
        expired_keys = []
        
        with self.cache_lock:
            for key, value in self.response_cache.items():
                if current_time - value['timestamp'] > 600:  # 10 minutes expiration
                    expired_keys.append(key)
                    
            for key in expired_keys:
                del self.response_cache[key]
                
        if expired_keys:
            logger.debug(f"Cleaned {len(expired_keys)} expired cache entries")


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='MetaTrader Connection Protocol (MCP) Server')
    parser.add_argument('--host', default='127.0.0.1', help='Host address to bind')
    parser.add_argument('--port', type=int, default=5555, help='Port to listen on')
    parser.add_argument('--no-auth', action='store_true', help='Disable authentication')
    parser.add_argument('--max-clients', type=int, default=10, help='Maximum number of clients')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()
    
    # Set debug level if requested
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        
    # Create and start server
    server = MCPServer(
        host=args.host,
        port=args.port,
        auth_enabled=not args.no_auth,
        max_clients=args.max_clients
    )
    
    try:
        server.start()
    except KeyboardInterrupt:
        server.stop()
        logger.info("Server stopped by user")
    except Exception as e:
        server.stop()
        logger.error(f"Server stopped due to error: {str(e)}")
