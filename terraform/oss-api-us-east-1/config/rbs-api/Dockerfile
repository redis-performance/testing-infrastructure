# Reconstructed from `docker history` of rbs-api:py311 on the host (the original build context is gone).
# The image installs redis-benchmarks-specification from the main branch, unpinned: rebuilding gets whatever
# main is then (the running image has 0.3.18 / redisbench-admin 0.11.75).
FROM python:3.11
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir "https://github.com/redis/redis-benchmarks-specification/archive/refs/heads/main.tar.gz"
ENTRYPOINT ["redis-benchmarks-spec-api"]
