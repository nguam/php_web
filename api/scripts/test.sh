#!/bin/bash
# 测试脚本

echo "Hello from test script!"
echo "Current time: $(date)"
echo "Arguments received: $@"

# 如果有参数，输出参数
if [ $# -gt 0 ]; then
    echo "Argument 1: $1"
    if [ $# -gt 1 ]; then
        echo "Argument 2: $2"
    fi
fi

exit 0
