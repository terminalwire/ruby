# Fullstack Testing

This directory contains **heavy fullstack tests** that boot real servers and test the complete Terminalwire system end-to-end.

## Test Organization

- **Integration Tests** (`spec/integration/`) - Lightweight tests using sync adapter
- **Fullstack Tests** (`spec/fullstack/`) - Heavy tests that boot real servers (this directory)

## Fullstack Tests (This Directory)

Fullstack tests provide complete end-to-end testing of the Terminalwire system:

- Real WebSocket connections
- Actual server processes
- Docker containers
- Network communication
- Complete authentication flows
- Production-like environment

### What Gets Tested

- **Complete workflows**: From client connection to command execution
- **Network layer**: WebSocket communication, connection handling
- **Authentication**: License verification, entitlement checking
- **Error propagation**: How errors flow through the full stack
- **Performance**: Real-world timing and resource usage
- **Integration**: How all components work together

### Files

- `example_usage_spec.rb` - Complete workflow examples and use cases
- `handler_integration_spec.rb` - Full server-client handler communication
- `license_verification_spec.rb` - License and authentication testing  
- `rails_spec.rb` - Rails integration testing with Docker

## Trade-offs

### Fullstack Tests
- ✅ **Complete coverage**: Tests the actual production path
- ✅ **Real environment**: Catches issues integration tests miss
- ✅ **Network testing**: WebSocket, async, connection handling
- ❌ **Slow**: Server startup, network overhead
- ❌ **Complex**: Docker, containers, more setup
- ❌ **Flaky**: Network timeouts, timing issues

### Integration Tests  
- ✅ **Fast**: No server boot, no network
- ✅ **Reliable**: No network timeouts or timing issues
- ✅ **Simple**: Direct resource testing
- ❌ **Limited scope**: Misses network/async issues
- ❌ **Mocked environment**: Not production-like

## When to Use Each

### Use Integration Tests For:
- Individual resource functionality
- Business logic testing  
- Rapid development feedback
- CI/CD pipeline (fast feedback)

### Use Fullstack Tests For:
- End-to-end workflows
- Release validation
- Network/WebSocket functionality
- Performance testing
- Production readiness

## Running Tests

```bash
# Run all fullstack tests (slow)
bundle exec rspec spec/fullstack/

# Run specific fullstack test
bundle exec rspec spec/fullstack/example_usage_spec.rb

# Run with verbose output
bundle exec rspec spec/fullstack/ --format documentation

# Skip fullstack tests during development
bundle exec rspec --exclude-pattern="spec/fullstack/**/*"
```

## Test Environment

Fullstack tests may require:

- Docker (for Rails integration tests)
- Network access
- Adequate system resources
- Longer timeouts

## Examples

### Example Usage (`example_usage_spec.rb`)
- Complete client-server workflows
- File operations, environment variables
- Error handling scenarios
- Batch operations

### Handler Integration (`handler_integration_spec.rb`) 
- WebSocket communication
- Message passing
- Client initialization
- Server command handling

### Rails Integration (`rails_spec.rb`)
- Docker container testing
- Rails application integration
- Web server interaction

## Best Practices

1. **Keep fullstack tests focused** - Test complete workflows, not individual methods
2. **Use appropriate timeouts** - Account for server startup and network latency
3. **Clean up resources** - Ensure containers and processes are properly terminated
4. **Group related functionality** - Batch related tests to amortize setup costs
5. **Consider test isolation** - Fullstack tests may interfere with each other

## Development Workflow

```bash
# During active development - use integration tests
bundle exec rspec spec/integration/

# Before commits - run subset of fullstack  
bundle exec rspec spec/fullstack/example_usage_spec.rb

# Before releases - run all tests
bundle exec rspec
```

This organization allows for fast feedback during development while ensuring comprehensive testing before releases.