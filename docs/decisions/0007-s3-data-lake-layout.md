# ADR 0007: S3 Data Lake Organisation

**Status:** Accepted  
**Phase:** Data Modelling & Architecture

## Context

Agrolens receives data from multiple sources and requires a predictable storage structure that supports historical retention, traceability and reprocessing.

## Decision

Organise S3 objects using source, dataset and ingestion-date prefixes.

```text
agrolens-data-lake/
├── source=srid/
│   └── dataset=market_prices/
│       └── ingested_at=YYYY-MM-DD/
├── source=wfp/
│   └── dataset=historical_prices/
│       └── ingested_at=YYYY-MM-DD/
├── source=faostat/
│   └── dataset=production/
│       └── ingested_at=YYYY-MM-DD/
└── source=open_meteo/
    └── dataset=rainfall/
        └── ingested_at=YYYY-MM-DD/
```

These represent logical S3 prefixes, not physical directories.

Raw source files will be preserved unchanged.

New ingestion runs should use separate ingestion-date prefixes rather than silently overwriting existing raw snapshots.

## Consequences

**Benefits**
- Clear source identification.
- Easier retrieval of specific datasets and ingestion runs.
- Supports historical snapshots and reprocessing.
- Simplifies organisation as additional sources are introduced.

**Trade-offs**
- Requires consistent naming conventions.
- Additional processing layers may require separate prefixes as the platform grows.

