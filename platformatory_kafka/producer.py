import time
import requests
import logging
from confluent_kafka import Producer as ConfluentProducer

logging.basicConfig(level=logging.DEBUG)

class Producer:
    def __init__(self, config):
        self.service_discovery_uri = config.get('service_discovery_uri')
        self.basic_auth = config.get('basic_auth')
        self.client_id = config.get('client_id')
        self.config_profile = config.get('config_profile')
        self.ttl = config.get('ttl', 300)
        self.cache = {}
        self.cache_time = {}

        if not self.config_profile:
            raise ValueError("Config profile must be set in the configuration")

        self.producer_config = self._get_initial_config()
        self.producer = ConfluentProducer(self.producer_config)

    def _is_cache_valid(self, key):
        return key in self.cache and (time.time() - self.cache_time[key]) < self.ttl

    def _fetch_service_config(self, channel):
        if not self._is_cache_valid(channel):
            try:
                logging.debug(f"Fetching service config for channel: {channel}")
                response = requests.get(
                    f"{self.service_discovery_uri}?config_profile={self.config_profile}&channel={channel}",
                    auth=self.basic_auth
                )
                response.raise_for_status()
                self.cache[channel] = response.json()
                self.cache_time[channel] = time.time()
                logging.debug(f"Fetched config: {self.cache[channel]}")
            except requests.exceptions.RequestException as e:
                logging.error(f"Failed to fetch service config for channel {channel}: {e}")
                raise
        else:
            time_left = self.ttl - (time.time() - self.cache_time[channel])
            logging.debug(f"Using cached config for channel: {channel}. Time left for cache refresh: {time_left:.2f} seconds")
        return self.cache[channel]

    def _get_initial_config(self):
        # Fetching initial config using a default channel
        default_channel = 'kafka://example.com/bar'
        config = self._fetch_service_config(default_channel)
        initial_config = {
            'bootstrap.servers': config['connection']['bootstrap_servers'],
            'sasl.username': config['credentials']['sasl.username'],
            'sasl.mechanisms': config['credentials']['sasl.mechanisms'],
            'sasl.password': config['credentials']['sasl.password'],
            'security.protocol': config['credentials']['security.protocol'],
            'client.id': self.client_id,
            'retries': config['configuration']['retries'],
            'acks': config['configuration']['acks'],
        }
        return initial_config

    def produce(self, channel, value, key=None, partition=None, on_delivery=None, *args, **kwargs):
        service_config = self._fetch_service_config(channel)
        topic = service_config['channel_mapping'][channel.split('/')[-1]]

        logging.debug(f"Producing message to topic: {topic}")
        logging.debug(f"Parameters - value: {value}, key: {key}, partition: {partition}, on_delivery: {on_delivery}, args: {args}, kwargs: {kwargs}")
        
        try:
            if partition is None:
                self.producer.produce(
                    topic=topic, value=value, key=key, callback=on_delivery, *args, **kwargs
                )
            else:
                self.producer.produce(
                    topic=topic, value=value, key=key, partition=partition, callback=on_delivery, *args, **kwargs
                )
        except Exception as e:
            logging.error(f"Error in producing message: {e}")
            raise

        logging.debug(f"Message produced to topic: {topic}")

    def poll(self, timeout):
        self.producer.poll(timeout)

    def flush(self):
        self.producer.flush()