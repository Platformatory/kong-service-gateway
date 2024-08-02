from platformatory_kafka.consumer import Consumer, KafkaException

consumer_config = {
    'service_gateway_uri': 'http://kong:8000/servicegw',
    'basic_auth': ('user1', 'password1'),
    'client_id': 'foo',
    'config_profile': 'highThroughputConsumer',  # Config profile from user code
    'ttl': 60,  # TTL set to 5 minutes (300 seconds)
    'additional_params': {  # Additional query parameters
        'kafka': {'env': 'prod'},
        'config_profile': {'type': 'consumer', 'env': 'prod'}
    }
}

consumer = Consumer(consumer_config)

# Subscribe to multiple channels
channels = ['kafka://example.com/bar', 'kafka://example.com/baz']

# Initial subscription
consumer.subscribe(channels)

while True:
    try:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"Consumer error: {msg.error()}")
            continue

        print(f"Received message from topic {msg.topic()}: {msg.value().decode('utf-8')}")
            
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error: {e}")
        break

consumer.close()

