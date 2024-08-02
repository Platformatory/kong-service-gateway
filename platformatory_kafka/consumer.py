import time
import requests
import logging
from urllib.parse import urlencode, quote_plus
from confluent_kafka import Consumer as ConfluentConsumer, KafkaException, KafkaError

logging.basicConfig(level=logging.DEBUG)

class Consumer:
    def __init__(self, config):
        self.service_gateway_uri = config.get('service_gateway_uri')
        self.basic_auth = config.get('basic_auth')
        self.client_id = config.get('client_id')
        self.config_profile = config.get('config_profile')
        self.ttl = config.get('ttl', 300)
        self.additional_params = config.get('additional_params', {})
        self.cache = {}
        self.cache_time = {}
        self.current_channels = []

        if not self.service_gateway_uri:
            raise ValueError("Service gateway URI must be set in the configuration")
        if not self.config_profile:
            raise ValueError("Config profile must be set in the configuration")

        self.consumer_config = None
        self.consumer = None

    def _is_cache_valid(self, key):
        return key in self.cache and (time.time() - self.cache_time[key]) < self.ttl

    def _encode_nested_params(self, params, prefix=''):
        """Encode nested query parameters."""
        encoded_params = {}
        for k, v in params.items():
            if isinstance(v, dict):
                encoded_params.update(self._encode_nested_params(v, prefix=f'{prefix}{k}.'))
            else:
                encoded_params[f'{prefix}{k}'] = v
        return encoded_params

    def _fetch_service_config(self, channels):
        channels_key = ','.join(channels)
        if not self._is_cache_valid(channels_key):
            try:
                logging.debug(f"Fetching service config for channels: {channels}")
                query_params = {
                    'config_profile': self.config_profile,
                }
                if len(channels) > 1:
                    for i, channel in enumerate(channels):
                        query_params[f'channel[{i}]'] = channel
                else:
                    query_params['channel'] = channels[0]

                # Encode additional parameters
                encoded_params = self._encode_nested_params(self.additional_params)
                query_params.update(encoded_params)
                query_string = urlencode(query_params, quote_via=quote_plus)
                response = requests.get(
                    f"{self.service_gateway_uri}?{query_string}",
                    auth=self.basic_auth
                )
                response.raise_for_status()
                self.cache[channels_key] = response.json()
                self.cache_time[channels_key] = time.time()
                logging.debug(f"Fetched config: {self.cache[channels_key]}")
            except requests.exceptions.RequestException as e:
                logging.error(f"Failed to fetch service config for channels {channels}: {e}")
                raise
        else:
            time_left = self.ttl - (time.time() - self.cache_time[channels_key])
            logging.debug(f"Using cached config for channels: {channels}. Time left for cache refresh: {time_left:.2f} seconds")
        return self.cache[channels_key]

    def _get_initial_config(self, channels):
        config = self._fetch_service_config(channels)
        initial_config = {
            'bootstrap.servers': config['connection']['bootstrap_servers'],
            'sasl.username': config['credentials']['sasl.username'],
            'sasl.mechanisms': config['credentials']['sasl.mechanisms'],
            'sasl.password': config['credentials']['sasl.password'],
            'security.protocol': config['credentials']['security.protocol'],
            'client.id': self.client_id,
            'group.id': config['configuration']['group.id'],  # Include group.id from the fetched configuration
        }
        return initial_config

    def subscribe(self, channels, **kwargs):
        if not channels:
            raise ValueError("At least one channel must be provided for subscription")
        
        self.current_channels = channels
        self.consumer_config = self._get_initial_config(channels)
        self.consumer = ConfluentConsumer(self.consumer_config)

        topic_mappings = self._get_topic_mappings(channels)
        topics = list(topic_mappings.values())
        
        logging.debug(f"Subscribing to topics: {topics}")
        self.consumer.subscribe(topics, **kwargs)

    def _get_topic_mappings(self, channels):
        config = self._fetch_service_config(channels)
        return {channel: config['channel_mapping'][channel.split('/')[-1]] for channel in channels}

    def poll(self, timeout=None):
        # Check for channel mapping updates
        self._check_for_updates()
        msg = self.consumer.poll(timeout=timeout)

        # Log time remaining for cache refresh
        channels_key = ','.join(self.current_channels)
        if channels_key in self.cache_time:
            time_left = self.ttl - (time.time() - self.cache_time[channels_key])
            logging.debug(f"Time left for cache refresh: {time_left:.2f} seconds")

        if msg is None:
            logging.debug("No message received")
            return None
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                logging.debug("End of partition reached {0}/{1}".format(msg.topic(), msg.partition()))
                return None
            else:
                raise KafkaException(msg.error())
        logging.debug(f"Message received from topic {msg.topic()}: {msg.value().decode('utf-8')}")
        return msg

    def consume(self, num_messages=1, timeout=-1):
        # Check for channel mapping updates
        self._check_for_updates()
        msgs = self.consumer.consume(num_messages=num_messages, timeout=timeout)
        if not msgs:
            logging.debug("No messages received")
            return []
        for msg in msgs:
            logging.debug(f"Message received from topic {msg.topic()}: {msg.value().decode('utf-8')}")
        return msgs

    def _check_for_updates(self):
        if not self._is_cache_valid(','.join(self.current_channels)):
            logging.debug("Cache expired, refreshing channel mappings")
            self.subscribe(self.current_channels)

    def close(self):
        if self.consumer:
            self.consumer.close()

