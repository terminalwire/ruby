# Terminalwire Integration Testing Framework

This directory contains integration tests that verify client-server communication without the complexity of async networking or WebSocket connections.

## Overview

The integration testing framework allows you to test the core message-passing logic between Terminalwire client and server handlers directly, using a simple test adapter that captures messages in memory.

## Key Components

### Test Adapter

The `Terminalwire::Adapter::Test` class provides a simple in-memory message queue that both client and server handlers can use:

```ruby
test_adapter = Terminalwire::Adapter::Test.new
```

### Server Handler

The `Terminalwire::Server::Handler` class provides methods for:
- Handling client initialization messages
- Sending commands to clients (file operations, stdout/stderr, etc.)
- Managing client exit

### Client Handler

The `Terminalwire::Client::Handler` class processes server commands and executes them on the client side.

## Basic Usage

```ruby
# Set up the test adapter (shared between client and server)
test_adapter = Terminalwire::Adapter::Test.new

# Create server handler
server_handler = Terminalwire::Server::Handler.new(test_adapter)

# Create client handler with test endpoint
endpoint = double('endpoint', authority: 'test.example.com', to_url: 'ws://test.example.com')
client_handler = Terminalwire::Client::Handler.new(
  test_adapter,
  arguments: ['test', 'args'],
  program_name: 'test_program',
  endpoint: endpoint
) do |handler|
  handler.entitlement = create_test_entitlement
end

# 1. Client sends initialization
initialization_message = {
  event: "initialization",
  protocol: { version: Terminalwire::VERSION },
  entitlement: client_handler.entitlement.serialize,
  program: { name: 'test_program', arguments: ['test', 'args'] }
}
server_handler.handle_message(initialization_message)

# 2. Server sends a command
server_handler.print_line_to_stdout("Hello from server!")

# 3. Get the command from adapter
command = test_adapter.response
# => { event: "resource", action: "command", name: "stdout", command: "print_line", parameters: { data: "Hello from server!" } }

# 4. Client handles the command
client_handler.handle(command)

# 5. Get the client's response
response = test_adapter.response
# => { event: "resource", name: "stdout", status: "success", response: nil }
```

## Entitlements Setup

For testing, you'll want to create permissive entitlements:

```ruby
def create_test_entitlement
  policy = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com')
  
  # Allow all file operations
  paths = Terminalwire::Client::Entitlement::Paths.new
  paths.permit("**/*")
  policy.instance_variable_set(:@paths, paths)
  
  # Allow specific environment variables
  env_vars = Terminalwire::Client::Entitlement::EnvironmentVariables.new
  env_vars.permit("TEST_VAR")
  env_vars.permit("TERMINALWIRE_HOME")
  policy.instance_variable_set(:@environment_variables, env_vars)
  
  # Allow URL schemes
  schemes = Terminalwire::Client::Entitlement::Schemes.new
  schemes.permit("http")
  schemes.permit("https")
  policy.instance_variable_set(:@schemes, schemes)
  
  policy
end
```

## Server Handler Methods

The server handler provides convenient methods for common operations:

### Output Operations
```ruby
server_handler.print_to_stdout("message")
server_handler.print_line_to_stdout("message")
server_handler.print_to_stderr("error")
```

### File Operations
```ruby
server_handler.read_file("/path/to/file")
server_handler.write_file("/path/to/file", "content", mode: 0o644)
server_handler.file_exists?("/path/to/file")
```

### Directory Operations
```ruby
server_handler.create_directory("/path/to/dir")
server_handler.directory_exists?("/path/to/dir")
```

### Environment Variables
```ruby
server_handler.read_env_var("VARIABLE_NAME")
```

### Client Control
```ruby
server_handler.send_exit(status: 0)
```

## Message Flow

1. **Initialization**: Client sends initialization message with protocol version, entitlements, and program info
2. **Commands**: Server sends resource commands to client via `send_command`
3. **Responses**: Client processes commands and sends back success/failure responses
4. **Exit**: Server can terminate client with `send_exit`

## Response Format

Client responses follow this format:

### Success Response
```ruby
{
  event: "resource",
  name: "resource_name",
  status: "success", 
  response: result_data  # The actual result (file contents, boolean, etc.)
}
```

### Failure Response
```ruby
{
  event: "resource",
  name: "resource_name", 
  status: "failure",
  response: "Error message",
  command: "original_command",
  parameters: { original: "parameters" }
}
```

## Error Handling

The client handler may raise exceptions for certain operations (like file not found). These are expected behaviors and should be handled in tests:

```ruby
expect { client_handler.handle(command) }.to raise_error(Errno::ENOENT)

# The error response is still sent to the adapter before the exception
response = test_adapter.response
expect(response[:status]).to eq("failure")
```

## Running Tests

```bash
# Run all integration tests
bundle exec rspec spec/integration/

# Run specific test file
bundle exec rspec spec/integration/handler_integration_spec.rb

# Run with verbose output to see the actual stdout/stderr output
bundle exec rspec spec/integration/handler_integration_spec.rb --format documentation
```

## Examples

See `spec/integration/example_usage_spec.rb` for comprehensive examples of:
- Complete client-server workflows
- Error handling scenarios
- Batch operations
- Permission testing

See `spec/integration/handler_integration_spec.rb` for detailed tests of individual resource operations.