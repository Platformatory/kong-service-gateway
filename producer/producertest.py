import time
import random
from datetime import datetime
from platformatory_kafka.producer import Producer

producer_config = {
    'service_discovery_uri': 'http://kong:8000/servicegw',
    'basic_auth': ('user1', 'password1'),
    'client_id': 'foo',
    'ttl': 300  # TTL set to 5 minutes (300 seconds)
}

# Initialize the producer
producer = Producer(producer_config)

def delivery_report(err, msg):
    """Called once for each message produced to indicate delivery result.
    Triggered by poll() or flush()."""
    if err is not None:
        print(f'Message delivery failed: {err}')
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}]')

sequence_number = 0

while True:
    # Generate a random message with a sequence number and a human-readable timestamp
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    service_config = producer._fetch_service_config('kafka://example.com/bar')
    topic = service_config['channel_mapping']['bar']
    message = f"Message {sequence_number}: {random.randint(1, 100)} | Topic: {topic} | Time: {current_time}"

    # Trigger any available delivery report callbacks from previous produce() calls
    producer.poll(0)

    # Asynchronously produce a message. The delivery report callback will
    # be triggered from the call to poll() above, or flush() below, when the
    # message has been successfully delivered or failed permanently.
    producer.produce(channel='kafka://example.com/bar', value=message.encode('utf-8'), on_delivery=delivery_report)

    # Wait for any outstanding messages to be delivered and delivery report
    # callbacks to be triggered.
    producer.flush()

    # Increment the sequence number
    sequence_number += 1

    # Sleep for a while to simulate a slow producer
    time.sleep(5)  # Adjust the sleep duration as needed
