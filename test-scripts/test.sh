#!/bin/bash
echo "Single channel test...."
curl -u user1:password1 "http://localhost:8000/servicegw?config_profile=durableWrite&channel=kafka://example.com/bar" | jq
echo "Multi-channel test...."
curl -u user1:password1 "http://localhost:8000/servicegw?config_profile=durableWrite&channel[]=kafka://example.com/bar&channel[]=kafka://example.com/baz" | jq
