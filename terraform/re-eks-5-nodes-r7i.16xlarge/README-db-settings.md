# Redis Enterprise Database Settings

This document describes the Redis Enterprise Database settings that have been configured for the primary database.

## Memory-Node-Policy (MNP) Scheduling Policy

The Memory-Node-Policy (MNP) scheduling policy has been configured for the primary database. This policy ensures that Redis Enterprise places database shards on nodes based on memory availability.

### Benefits of MNP

- **Improved Memory Utilization**: MNP ensures that shards are placed on nodes with the most available memory.
- **Better Performance**: By distributing shards based on memory availability, MNP can help prevent memory-related performance issues.
- **Reduced Risk of OOM**: MNP helps reduce the risk of Out-Of-Memory (OOM) errors by balancing memory usage across nodes.

### Configuration

The scheduling policy has been changed from the default "cmp" (compare) to "mnp" (Memory-Node-Policy) using the Redis Enterprise REST API:

```bash
curl -k -X PUT -u "<username>:<password>" \
  -H "Content-Type: application/json" \
  -d '{"sched_policy":"mnp"}' \
  https://localhost:9443/v1/bdbs/<db_uid>
```

## Connections Parameter

The connections parameter has been changed from the default value of 5 to 1. This parameter controls the number of internal proxy connections per thread.

### Benefits of Reducing Connections

- **Reduced Resource Usage**: Fewer connections means less memory and CPU usage for connection management.
- **Simplified Connection Handling**: With fewer connections, the system has less overhead for connection management.
- **Improved Stability**: In some cases, reducing the number of connections can improve stability by reducing the complexity of connection handling.

### Configuration

The connections parameter has been changed from 5 to 1 using the Redis Enterprise REST API:

```bash
curl -k -X PUT -u "<username>:<password>" \
  -H "Content-Type: application/json" \
  -d '{"conns":1}' \
  https://localhost:9443/v1/bdbs/<db_uid>
```

## OSS Cluster API

The OSS Cluster API has been enabled for the primary database. This allows you to use Redis OSS cluster API commands with your Redis Enterprise Database.

### Benefits of OSS Cluster API

- **Compatibility**: Enables compatibility with Redis OSS cluster clients.
- **Scalability**: Allows for horizontal scaling using Redis OSS cluster clients.
- **Flexibility**: Provides more options for connecting to the database.

### Configuration

The OSS Cluster API has been enabled using the Redis Enterprise REST API:

```bash
curl -k -X PUT -u "<username>:<password>" \
  -H "Content-Type: application/json" \
  -d '{"oss_cluster":true,"oss_cluster_api_preferred_endpoint_type":"ip","oss_cluster_api_preferred_ip_type":"external"}' \
  https://localhost:9443/v1/bdbs/<db_uid>
```

**Note**: Enabling the OSS Cluster API requires a database restart to take effect.

## Scripts

The following scripts have been created to manage these settings:

1. **get-db-details.sh**: Gets the current database details using the Redis Enterprise REST API.
2. **update-sched-policy.sh**: Updates the scheduling policy to "mnp" (Memory-Node-Policy).
3. **update-conns.sh**: Updates the connections parameter to 1.
4. **update-db-settings.sh**: Updates the scheduling policy, connections parameter, and OSS Cluster API in a single operation.
5. **enable-oss-api.sh**: Enables the OSS Cluster API.
6. **enable-oss-api-with-restart.sh**: Enables the OSS Cluster API and restarts the database if needed.

### Usage

To update all settings at once:

```bash
./update-db-settings.sh
```

To update only the scheduling policy:

```bash
./update-db-settings.sh --sched-policy mnp
```

To update only the connections parameter:

```bash
./update-db-settings.sh --conns 1
```

To enable the OSS Cluster API:

```bash
./update-db-settings.sh --oss-api true
```

To update all settings with custom values:

```bash
./update-db-settings.sh --sched-policy mnp --conns 1 --oss-api true
```

To enable the OSS Cluster API with a database restart if needed:

```bash
./enable-oss-api-with-restart.sh
```

## References

- [Redis Enterprise Database API Reference](https://redis.io/docs/latest/operate/rs/references/rest-api/objects/bdb/)
- [Redis Enterprise Database Scheduling Policies](https://redis.io/docs/latest/operate/kubernetes/reference/redis_enterprise_database_api/)
