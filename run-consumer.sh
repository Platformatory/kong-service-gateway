#!/bin/bash
docker-compose exec consumer sh -c "
  pip install -r requirements.txt &&
  python consumertest.py
"

