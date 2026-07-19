#!/usr/bin/env bash

echo "========== System Doctor =========="

echo "OS:"
uname -a

echo
echo "Go:"
go version || true

echo
echo "Python:"
python3 --version || true

echo
echo "Node:"
node -v || true

echo
echo "Java:"
java -version || true

echo
echo "Disk:"
df -h

echo
echo "Memory:"
free -h
