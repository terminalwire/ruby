# Integration Testing

This directory contains **lightweight integration tests** that verify server-client resource communication using a synchronous adapter.

## Test Organization

- **Integration Tests** (`spec/integration/`) - Lightweight tests using sync adapter
- **Fullstack Tests** (`spec/fullstack/`) - Heavy tests that boot real servers

## Integration Tests (This Directory)

Integration tests use a `SyncAdapter` to directly connect server and client resources without WebSocket/async complexity:

```ruby
# Create sync adapter
sync_adapter = SyncAdapter.new

# Setup client resources
client_handler = Terminalwire::Client::Resource::Handler.new do |handler|
  handler << Terminalwire::Client::Resource::File.new("file", sync_adapter.client_adapter, entitlement: entitlement)
  # ... other resources
end

sync_adapter.connect_client(client_handler)

# Create server resources
server_file = Terminalwire::Server::Resource::File.new("file", sync_adapter)

# Test direct communication
result = server_file.read("/tmp/test.txt")  # Goes through sync adapter to client
expect(result).to eq("file contents")
```

### Benefits

- **Fast**: No network, no async, no server booting
- **Direct**: Tests actual server-client resource communication  
- **Simple**: Easy setup, no complex mocking
- **Reliable**: No flaky network timeouts

### Files

- `resources/` directory - Individual specs for each resource type
- `resources/file_spec.rb` - File resource integration tests
- `resources/stdout_spec.rb` - STDOUT resource integration tests  
- `resources/stderr_spec.rb` - STDERR resource integration tests
- `resources/stdin_spec.rb` - STDIN resource integration tests
- `resources/directory_spec.rb` - Directory resource integration tests
- `resources/environment_variable_spec.rb` - Environment variable resource tests
- `resources/browser_spec.rb` - Browser resource integration tests
- `resources/shared_setup.rb` - Shared test setup and configuration

## Fullstack Tests (`spec/fullstack/`)

Fullstack tests boot actual servers and test the complete system:

- WebSocket connections
- Real network communication
- Docker containers
- End-to-end workflows

These are slower but test the complete production path.

## Running Tests

```bash
# Run lightweight integration tests (fast)
bundle exec rspec spec/integration/

# Run heavy fullstack tests (slow)  
bundle exec rspec spec/fullstack/

# Run specific resource tests
bundle exec rspec spec/integration/resources/file_spec.rb
bundle exec rspec spec/integration/resources/stdout_spec.rb

# Run all resource tests
bundle exec rspec spec/integration/resources/
```

## SyncAdapter

The `SyncAdapter` creates a direct pipe between server and client resources:

1. Server resource calls method (e.g., `file.read(path)`)
2. SyncAdapter passes message to client handler
3. Client resource executes operation
4. Response flows back through SyncAdapter
5. Server resource returns result

No WebSockets, no async, just direct synchronous communication for testing.