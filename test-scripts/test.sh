#!/bin/bash

KONG_API_URL="http://localhost:8000"
LISTENER_PATH="/kong-service-gw"  # Replace with your actual path
curl -X GET 'http://localhost:8000/kafka-service-gw/configuration_profiles?profile_name=profile1' -u user1:password1
