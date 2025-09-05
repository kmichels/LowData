#!/bin/bash

echo "Testing helper rule generation..."

# Create a test rule file to see what the helper is generating
cat > /tmp/test_rule.json << 'EOF'
[{
  "type": "port",
  "port": 21,
  "protocol": "tcp"
}]
EOF

# Try to apply it directly using pfctl to see the exact error
echo "Test rule content that should be generated:"
echo "# Low Data Blocking Rules"
echo ""
echo "block drop out proto tcp from any to any port 21"

echo ""
echo "Now check what the actual helper generated:"
if [ -f /tmp/lowdata_rules.conf ]; then
    echo "=== Contents of /tmp/lowdata_rules.conf ==="
    cat -n /tmp/lowdata_rules.conf
else
    echo "Rules file doesn't exist yet"
fi

echo ""
echo "Let's see if we can find where the helper is actually running from:"
ps aux | grep -i lowdata.helper | grep -v grep

echo ""
echo "Check if there's a cached version somewhere:"
sudo find /private/var -name "*lowdata*" 2>/dev/null | head -20