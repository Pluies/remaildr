#!/bin/bash

echo "receivr:"
ps -elf|grep receivr|grep -v grep

echo "sendr:"
ps -elf|grep sendr|grep -v grep

