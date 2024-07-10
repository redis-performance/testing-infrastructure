#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install python3-pip -y
sudo DEBIAN_FRONTEND=noninteractive pip3 install --upgrade pip 
sudo pip3 install stopit numpy redis typer dataclasses tqdm h5py elasticsearch==8.12.1 pymilvus backoff opensearch-py qdrant-client psycopg[binary] weaviate-client==4.5.4 pgvector
sudo git clone https://github.com/redis-performance/vector-db-benchmark --branch update.redisearch
