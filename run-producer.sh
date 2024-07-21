#!/bin/bash
docker-compose exec producer sh -c "
  pip install -r requirements.txt &&
  python producertest.py
"

