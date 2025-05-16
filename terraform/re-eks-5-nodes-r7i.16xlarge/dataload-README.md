# Dataload Script for Redis Enterprise Database

This README documents the changes made to the `dataload.py` script to ensure deterministic random data generation.

## Overview

The `dataload.py` script generates sample telemetry data and loads it into a Redis Enterprise Database. The script has been modified to:

1. Use a fixed random seed for deterministic data generation
2. Handle cases where RediSearch and RedisJSON modules are not available
3. Provide command-line arguments for customization

## Usage

```bash
python dataload.py --seed 42 --count 10000
```

### Command-line Arguments

- `--seed`: Random seed for deterministic data generation (default: 42)
- `--count`: Number of documents to generate (default: 100000)

### Environment Variables

- `REDIS_HOST`: Redis host (default: localhost)
- `REDIS_PORT`: Redis port (default: 6379)
- `REDIS_PASSWORD`: Redis password (default: None)
- `CLUSTER_ENABLED`: Whether Redis is in cluster mode (default: 0)
- `RUN_QUERIES`: Whether to run example queries (default: 0)

## Deterministic Data Generation

The script now uses a fixed random seed to ensure that the same data is generated each time the script is run with the same seed value. This is important for testing and reproducibility.

The following components now use the random seed:

1. Random module initialization: `random.seed(RANDOM_SEED)`
2. Faker initialization: `Faker.seed(RANDOM_SEED)`
3. UUID generation: Custom deterministic UUID function
4. Partner ID assignment: Deterministic based on device index
5. Device telemetry generation: Deterministic based on device index

## Module Availability Handling

The script now checks if the RediSearch and RedisJSON modules are available and adapts its behavior accordingly:

1. If RediSearch is not available:
   - Skips search index creation
   - Skips example queries
   - Provides appropriate warning messages

2. If RedisJSON is not available:
   - Stores data as serialized JSON strings instead of native JSON
   - Provides appropriate warning messages

## Example Output

```
Using random seed: 42 for deterministic data generation

Redis module availability:
- RediSearch: Not available
- RedisJSON: Not available

Generating 10 documents with random seed 42
Generating 10 sample telemetry documents...
Warning: RedisJSON module is not available.
Data will be stored as serialized JSON strings instead of native JSON.
Sample data generation complete!

Sample data generation complete!
Data was generated with random seed: 42
To regenerate the exact same data, use the same seed value:
python dataload.py --seed 42 --count 10
```

## Note

The `dataload.py` file is excluded from Git using a specific `.gitignore` file in this directory. This is because it's a data generation script that doesn't need to be version-controlled.
