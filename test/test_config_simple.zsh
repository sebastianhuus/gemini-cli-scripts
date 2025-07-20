#!/usr/bin/env zsh

# Simple Configuration System Test
echo "Testing configuration system..."

# Get script directory
TEST_DIR="${0:A:h}"
PROJECT_ROOT="${TEST_DIR:h}"

# Test 1: Basic loading
echo "Test 1: Basic configuration loading"
source "${PROJECT_ROOT}/config/config_loader.zsh"
load_gemini_config

if [ "$CONFIG_GEMINI_MODEL" = "gemini-2.5-flash" ]; then
    echo "✓ Default model loaded correctly: $CONFIG_GEMINI_MODEL"
else
    echo "✗ Default model incorrect: $CONFIG_GEMINI_MODEL"
    exit 1
fi

# Test 2: Helper functions  
echo "Test 2: Helper functions"
model=$(get_gemini_model)
if [ "$model" = "gemini-2.5-flash" ]; then
    echo "✓ get_gemini_model() works: $model"
else
    echo "✗ get_gemini_model() failed: $model"
    exit 1
fi

# Test 3: Branch prefix
echo "Test 3: Branch prefix function"
prefix=$(get_branch_prefix "feat")
if [ "$prefix" = "feat/" ]; then
    echo "✓ get_branch_prefix() works: $prefix"
else
    echo "✗ get_branch_prefix() failed: $prefix"
    exit 1
fi

# Test 4: Boolean helper
echo "Test 4: Boolean helper"
if is_config_true "true"; then
    echo "✓ is_config_true('true') works"
else
    echo "✗ is_config_true('true') failed"
    exit 1
fi

if ! is_config_true "false"; then
    echo "✓ is_config_true('false') works"
else
    echo "✗ is_config_true('false') failed"
    exit 1
fi

# Test 5: Custom config file
echo "Test 5: Custom configuration file"
TEMP_DIR=$(mktemp -d)
cat > "$TEMP_DIR/.gemini-config" << 'EOF'
GEMINI_MODEL=custom-model
AUTO_STAGE=true
EOF

cd "$TEMP_DIR"

# Clear existing config
unset CONFIG_GEMINI_MODEL CONFIG_AUTO_STAGE

# Reload config
source "${PROJECT_ROOT}/config/config_loader.zsh"
load_gemini_config

if [ "$CONFIG_GEMINI_MODEL" = "custom-model" ]; then
    echo "✓ Custom model loaded: $CONFIG_GEMINI_MODEL"
else
    echo "✗ Custom model failed: $CONFIG_GEMINI_MODEL"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if [ "$CONFIG_AUTO_STAGE" = "true" ]; then
    echo "✓ Custom auto_stage loaded: $CONFIG_AUTO_STAGE"
else
    echo "✗ Custom auto_stage failed: $CONFIG_AUTO_STAGE"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"
cd "$PROJECT_ROOT"

echo ""
echo "🎉 All configuration tests passed!"