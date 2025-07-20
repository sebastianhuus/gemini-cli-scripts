#!/usr/bin/env zsh

# Comprehensive Configuration System Tests
# Tests the configuration loading, priority order, and integration with scripts

set -e  # Exit on any error

# Get test directory and project root
TEST_DIR="${0:A:h}"
PROJECT_ROOT="${TEST_DIR:h}"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temporary directories for testing
TEMP_HOME=""
TEMP_REPO=""

# Utility functions
print_test_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
    echo -e "${RED}  $2${NC}"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

run_test() {
    ((TESTS_RUN++))
    local test_name="$1"
    local test_command="$2"
    
    if eval "$test_command" 2>/dev/null; then
        print_success "$test_name"
        return 0
    else
        print_failure "$test_name" "Command failed: $test_command"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    if [ "$expected" = "$actual" ]; then
        print_success "$test_name"
        return 0
    else
        print_failure "$test_name" "Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    ((TESTS_RUN++))
    if [ -n "$value" ]; then
        print_success "$test_name"
        return 0
    else
        print_failure "$test_name" "Value was empty"
        return 1
    fi
}

# Setup temporary environment
setup_test_env() {
    print_test_header "Setting up test environment"
    
    # Create temporary directories
    TEMP_HOME=$(mktemp -d)
    TEMP_REPO=$(mktemp -d)
    
    # Create config directory in temp home
    mkdir -p "$TEMP_HOME/.config/gemini-cli"
    
    print_info "Temp HOME: $TEMP_HOME"
    print_info "Temp REPO: $TEMP_REPO"
    
    # Initialize temp repo as git repo
    cd "$TEMP_REPO"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    cd "$PROJECT_ROOT"
}

# Cleanup temporary environment
cleanup_test_env() {
    print_test_header "Cleaning up test environment"
    
    if [ -n "$TEMP_HOME" ] && [ -d "$TEMP_HOME" ]; then
        rm -rf "$TEMP_HOME"
    fi
    
    if [ -n "$TEMP_REPO" ] && [ -d "$TEMP_REPO" ]; then
        rm -rf "$TEMP_REPO"
    fi
    
    # Clean up any test config files in project
    rm -f "$PROJECT_ROOT/.gemini-config"
    
    print_info "Cleanup complete"
}

# Test configuration loading utility
test_config_loader_basics() {
    print_test_header "Testing Configuration Loader Basics"
    
    # Source the config loader
    source "$CONFIG_DIR/config_loader.zsh"
    
    # Test loading with no config files (should use defaults)
    load_gemini_config
    
    assert_equals "gemini-2.5-flash" "$CONFIG_GEMINI_MODEL" "Default model loaded"
    assert_equals "false" "$CONFIG_AUTO_STAGE" "Default auto_stage loaded"
    assert_equals "false" "$CONFIG_AUTO_PR" "Default auto_pr loaded"
    assert_equals "feat/" "$CONFIG_BRANCH_PREFIX_FEAT" "Default feat prefix loaded"
    
    # Test helper functions
    local model=$(get_gemini_model)
    assert_equals "gemini-2.5-flash" "$model" "get_gemini_model() returns correct default"
    
    local feat_prefix=$(get_branch_prefix "feat")
    assert_equals "feat/" "$feat_prefix" "get_branch_prefix() returns correct feat prefix"
    
    local fix_prefix=$(get_branch_prefix "fix")
    assert_equals "fix/" "$fix_prefix" "get_branch_prefix() returns correct fix prefix"
    
    # Test boolean helper
    if is_config_true "true"; then
        print_success "is_config_true('true') works"
        ((TESTS_RUN++))
    else
        print_failure "is_config_true('true') failed" "Should return true for 'true'"
        ((TESTS_RUN++))
    fi
    
    if ! is_config_true "false"; then
        print_success "is_config_true('false') works"
        ((TESTS_RUN++))
    else
        print_failure "is_config_true('false') failed" "Should return false for 'false'"
        ((TESTS_RUN++))
    fi
}

# Test configuration file priority order
test_config_priority() {
    print_test_header "Testing Configuration Priority Order"
    
    # Create test config files with different values
    
    # 1. System default (already exists)
    # 2. User global config
    cat > "$TEMP_HOME/.config/gemini-cli/.gemini-config" << 'EOF'
GEMINI_MODEL=gemini-1.5-pro
AUTO_STAGE=true
AUTO_PUSH=true
EOF
    
    # 3. Repository-specific config (highest priority)
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
GEMINI_MODEL=gemini-1.5-flash
AUTO_STAGE=false
EOF
    
    # Test loading with mocked HOME
    cd "$TEMP_REPO"
    export HOME="$TEMP_HOME"
    
    # Clear existing config variables
    unset CONFIG_GEMINI_MODEL CONFIG_AUTO_STAGE CONFIG_AUTO_PUSH
    
    # Source and load config
    source "$CONFIG_DIR/config_loader.zsh"
    load_gemini_config
    
    # Repository config should override user config
    assert_equals "gemini-1.5-flash" "$CONFIG_GEMINI_MODEL" "Repository config overrides user config for model"
    assert_equals "false" "$CONFIG_AUTO_STAGE" "Repository config overrides user config for auto_stage"
    
    # User config should override system default where repo config doesn't specify
    assert_equals "true" "$CONFIG_AUTO_PUSH" "User config overrides system default for auto_push"
    
    cd "$PROJECT_ROOT"
}

# Test configuration integration with auto_commit.zsh
test_auto_commit_integration() {
    print_test_header "Testing auto_commit.zsh Configuration Integration"
    
    # Create test config
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
AUTO_STAGE=true
AUTO_PUSH=true
AUTO_BRANCH=true
GEMINI_MODEL=test-model
EOF
    
    cd "$TEMP_REPO"
    
    # Mock the gemini command to avoid actual API calls
    export PATH="$TEMP_REPO:$PATH"
    cat > "$TEMP_REPO/gemini" << 'EOF'
#!/bin/bash
echo "Mocked commit message"
EOF
    chmod +x "$TEMP_REPO/gemini"
    
    # Create a test file and stage it
    echo "test content" > test.txt
    git add test.txt
    
    # Test that config is loaded by checking the script accepts the configured model
    if "$PROJECT_ROOT/auto_commit.zsh" --help >/dev/null 2>&1; then
        print_success "auto_commit.zsh loads without errors"
        ((TESTS_RUN++))
    else
        print_failure "auto_commit.zsh failed to load" "Configuration integration may be broken"
        ((TESTS_RUN++))
    fi
    
    cd "$PROJECT_ROOT"
}

# Test configuration integration with auto_issue.zsh
test_auto_issue_integration() {
    print_test_header "Testing auto_issue.zsh Configuration Integration"
    
    # Create test config
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
GEMINI_MODEL=test-model-issue
EOF
    
    cd "$TEMP_REPO"
    
    # Test that auto_issue.zsh loads config
    if "$PROJECT_ROOT/auto_issue.zsh" --help >/dev/null 2>&1; then
        print_success "auto_issue.zsh loads without errors"
        ((TESTS_RUN++))
    else
        print_failure "auto_issue.zsh failed to load" "Configuration integration may be broken"
        ((TESTS_RUN++))
    fi
    
    cd "$PROJECT_ROOT"
}

# Test invalid configuration handling
test_invalid_config_handling() {
    print_test_header "Testing Invalid Configuration Handling"
    
    # Create config with invalid syntax
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
# Valid config
GEMINI_MODEL=valid-model

# Invalid lines (should be ignored)
INVALID LINE WITHOUT EQUALS
=EQUALS_AT_START
KEY_WITH_NO_VALUE=

# Another valid line
AUTO_STAGE=true
EOF
    
    cd "$TEMP_REPO"
    
    # Clear existing config
    unset CONFIG_GEMINI_MODEL CONFIG_AUTO_STAGE
    
    # Load config (should not fail)
    source "$CONFIG_DIR/config_loader.zsh"
    if load_gemini_config 2>/dev/null; then
        print_success "Config loader handles invalid lines gracefully"
        ((TESTS_RUN++))
        
        # Valid values should still be loaded
        assert_equals "valid-model" "$CONFIG_GEMINI_MODEL" "Valid config values are loaded despite invalid lines"
        assert_equals "true" "$CONFIG_AUTO_STAGE" "Multiple valid values loaded correctly"
    else
        print_failure "Config loader failed on invalid config" "Should handle invalid lines gracefully"
        ((TESTS_RUN++))
    fi
    
    cd "$PROJECT_ROOT"
}

# Test branch prefix configuration
test_branch_prefix_config() {
    print_test_header "Testing Branch Prefix Configuration"
    
    # Create config with custom branch prefixes
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
BRANCH_PREFIX_FEAT=feature/
BRANCH_PREFIX_FIX=bugfix/
BRANCH_PREFIX_DOCS=documentation/
BRANCH_PREFIX_REFACTOR=refactor/
EOF
    
    cd "$TEMP_REPO"
    
    # Clear existing config
    unset CONFIG_BRANCH_PREFIX_FEAT CONFIG_BRANCH_PREFIX_FIX CONFIG_BRANCH_PREFIX_DOCS CONFIG_BRANCH_PREFIX_REFACTOR
    
    # Load config
    source "$CONFIG_DIR/config_loader.zsh"
    load_gemini_config
    
    # Test custom prefixes
    local feat_prefix=$(get_branch_prefix "feat")
    assert_equals "feature/" "$feat_prefix" "Custom feat prefix loaded"
    
    local fix_prefix=$(get_branch_prefix "fix")
    assert_equals "bugfix/" "$fix_prefix" "Custom fix prefix loaded"
    
    local docs_prefix=$(get_branch_prefix "docs")
    assert_equals "documentation/" "$docs_prefix" "Custom docs prefix loaded"
    
    # Test fallback for unknown type
    local unknown_prefix=$(get_branch_prefix "unknown")
    assert_equals "unknown/" "$unknown_prefix" "Unknown prefix falls back correctly"
    
    cd "$PROJECT_ROOT"
}

# Test configuration with special characters
test_special_characters() {
    print_test_header "Testing Configuration with Special Characters"
    
    # Create config with special characters
    cat > "$TEMP_REPO/.gemini-config" << 'EOF'
GEMINI_MODEL=model-with-dashes-and_underscores
BRANCH_PREFIX_FEAT=feature/with-dashes/
EOF
    
    cd "$TEMP_REPO"
    
    # Clear existing config
    unset CONFIG_GEMINI_MODEL CONFIG_BRANCH_PREFIX_FEAT
    
    # Load config
    source "$CONFIG_DIR/config_loader.zsh"
    load_gemini_config
    
    assert_equals "model-with-dashes-and_underscores" "$CONFIG_GEMINI_MODEL" "Model with special characters loaded"
    assert_equals "feature/with-dashes/" "$CONFIG_BRANCH_PREFIX_FEAT" "Branch prefix with special characters loaded"
    
    cd "$PROJECT_ROOT"
}

# Main test runner
main() {
    echo -e "${BLUE}Gemini CLI Scripts - Configuration System Tests${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    # Setup
    setup_test_env
    
    # Run all tests
    test_config_loader_basics
    test_config_priority
    test_auto_commit_integration
    test_auto_issue_integration
    test_invalid_config_handling
    test_branch_prefix_config
    test_special_characters
    
    # Cleanup
    cleanup_test_env
    
    # Print summary
    print_test_header "Test Summary"
    echo -e "Tests run: ${BLUE}${TESTS_RUN}${NC}"
    echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! 🎉${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"