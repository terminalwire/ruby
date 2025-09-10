# Terminalwire Test Suite

This directory contains the complete test suite for Terminalwire, organized by test type and scope.

## Test Organization

### Unit Tests (`gem/*/spec/`)
- **Location**: Individual gem directories (e.g., `gem/terminalwire-server/spec/`)
- **Purpose**: Test individual classes and methods in isolation
- **Speed**: Very fast
- **Scope**: Single class/method functionality

### Integration Tests (`spec/integration/`)
- **Location**: `spec/integration/`
- **Purpose**: Test server-client resource communication using sync adapter
- **Speed**: Fast
- **Scope**: Cross-component interaction without network

### Fullstack Tests (`spec/fullstack/`)
- **Location**: `spec/fullstack/`
- **Purpose**: End-to-end testing with real servers and network
- **Speed**: Slow
- **Scope**: Complete system testing

### Package Tests (`spec/package/`)
- **Location**: `spec/package/`
- **Purpose**: Test built packages and distribution
- **Speed**: Very slow
- **Scope**: Installation and deployment

## Test Types Explained

### Integration Tests (Recommended for Development)

Integration tests use a `SyncAdapter` to directly connect server and client resources:

```ruby
# Fast, reliable testing of server-client communication
sync_adapter = SyncAdapter.new
server_file = Terminalwire::Server::Resource::File.new("file", sync_adapter)
result = server_file.read("/tmp/test.txt")  # Tests full communication path
```

**Benefits:**
- ✅ Fast execution (no network/server startup)
- ✅ Tests actual server-client communication
- ✅ No flaky network issues
- ✅ Easy to debug

**Use For:**
- Resource functionality testing
- Business logic validation
- Rapid development feedback
- CI/CD pipelines

### Fullstack Tests (For Release Validation)

Fullstack tests boot real servers and use actual WebSocket connections:

**Benefits:**
- ✅ Tests complete production path
- ✅ Catches network/async issues
- ✅ Real environment conditions

**Drawbacks:**
- ❌ Slow (server startup overhead)
- ❌ Can be flaky (network timeouts)
- ❌ Complex setup (Docker, containers)

**Use For:**
- End-to-end workflow validation
- Release testing
- Performance testing
- Production readiness verification

## Running Tests

### Development Workflow

```bash
# Fast feedback during development
bundle exec rake spec:integration

# Individual resource testing
bundle exec rspec spec/integration/server_client_resources_spec.rb

# Specific resource method
bundle exec rspec spec/integration/server_client_resources_spec.rb -e "File#read"
```

### Pre-commit Testing

```bash
# Run unit and integration tests (fast)
bundle exec rake spec:isolate spec:integration

# Skip slow fullstack tests during development
bundle exec rspec --exclude-pattern="spec/fullstack/**/*"
```

### Release Testing

```bash
# Run everything including heavy tests
bundle exec rake spec

# Just fullstack tests
bundle exec rake spec:fullstack

# Complete test suite with packages
bundle exec rake default
```

### Focused Testing

```bash
# Test specific gem
cd gem/terminalwire-server && bundle exec rspec

# Test specific integration
bundle exec rspec spec/integration/server_client_resources_spec.rb

# Test specific fullstack workflow
bundle exec rspec spec/fullstack/example_usage_spec.rb
```

## Test Strategy

### The Testing Pyramid

```
    /\     Package Tests (Very Slow)
   /  \    - Installation testing
  /____\   - Distribution validation
 /      \
/________\  Fullstack Tests (Slow)
           - End-to-end workflows
           - Real servers & network

Integration Tests (Fast) ← **Primary development testing**
- Server-client communication
- Resource functionality
- Business logic

Unit Tests (Very Fast)
- Individual methods
- Class functionality
- Edge cases
```

### Primary Development Flow

1. **Unit Tests**: Test individual methods and classes
2. **Integration Tests**: Test server-client communication (**most important**)
3. **Fullstack Tests**: Validate complete workflows (pre-release)
4. **Package Tests**: Test distribution (CI/release only)

## Key Files

### Integration Tests
- `spec/integration/server_client_resources_spec.rb` - Core resource testing
- `spec/support/sync_adapter.rb` - Synchronous adapter implementation

### Fullstack Tests  
- `spec/fullstack/example_usage_spec.rb` - Complete workflow examples
- `spec/fullstack/handler_integration_spec.rb` - Full handler communication
- `spec/fullstack/rails_spec.rb` - Rails integration with Docker

### Support Files
- `spec/support/` - Shared test utilities
- `spec/spec_helper.rb` - Global test configuration

## Best Practices

### For Development
1. **Start with integration tests** - They provide the best feedback
2. **Use unit tests for edge cases** - Complex logic and error conditions  
3. **Keep fullstack tests for workflows** - Not individual method testing
4. **Mock external dependencies** - In unit and integration tests

### For CI/CD
1. **Run integration tests on every commit** - Fast feedback
2. **Run fullstack tests on main branch** - Catch integration issues
3. **Run package tests on releases** - Validate distribution
4. **Parallel execution** - Split test suites across workers

### Writing Tests
1. **Integration tests per resource** - One describe block per resource class
2. **Method-level testing** - Test each public method individually  
3. **Clear test names** - Describe the behavior being tested
4. **Proper cleanup** - Clean up files, processes, containers

## Debugging Tests

### Integration Test Issues
```bash
# Run with verbose output
bundle exec rspec spec/integration/ --format documentation

# Debug specific resource
bundle exec rspec spec/integration/server_client_resources_spec.rb -e "File" --format documentation

# Check sync adapter behavior
# Add puts statements to spec/support/sync_adapter.rb
```

### Fullstack Test Issues
```bash
# Run with detailed output
bundle exec rspec spec/fullstack/ --format documentation

# Check server logs
# Tests that boot servers will show startup logs

# Debug Docker issues  
docker ps -a  # Check container status
docker logs <container_id>  # Check container logs
```

This organization provides fast development feedback while ensuring comprehensive release validation.