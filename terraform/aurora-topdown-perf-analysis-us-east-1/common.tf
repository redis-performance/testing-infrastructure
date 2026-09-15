terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/aurora-topdown-perf-analysis-us-east-1.tfstate"
    region = "us-east-1"
  }
}
