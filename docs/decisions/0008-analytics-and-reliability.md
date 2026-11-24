# ADR 0008: Analytical Marts and Pipeline Reliability

**Status:** Accepted  
**Phase:** Data Modelling & Architecture

## Context

AgroLens must convert cleaned warehouse data into business-ready information while ensuring that pipeline failures and data-quality problems are detectable.

## Decision

### 1. Analytical marts

Create the following proposed analytical models:

| Mart | Purpose |
|---|---|
| `mart_price_board` | Compare commodity prices across markets |
| `mart_price_anomaly` | Identify unusual prices against seasonal baselines |
| `mart_market_lead_lag` | Investigate market price movements and potential leading markets |
| `mart_rainfall_price_lag` | Analyse rainfall and subsequent price movements |
| `mart_risk_indicator` | Combine price, rainfall and production signals to investigate potential food-security risks |

### 2. Data-quality checks

Implement validation for:

- Required fields and null values.
- Data types and date ranges.
- Duplicate observations using source-appropriate business keys.
- Numeric price and production values.
- Market and commodity mappings.
- Price-unit conversions.
- Ingestion row counts.

### 3. Failure handling

- Log failed pipeline tasks with useful error information.
- Retry transient failures where appropriate.
- Do not repeatedly retry permanent data-quality failures without correction.
- Preserve invalid records for investigation.
- Fail relevant pipeline stages when critical validation checks fail.

### 4. Idempotency

Repeated pipeline execution should not introduce unintended duplicate records.

Use source identifiers and appropriate business keys to identify observations. Preserve raw ingestion snapshots and make downstream loading and transformations safe to rerun.

## Consequences

**Benefits**
- Provides clear analytical outputs.
- Improves pipeline reliability and transparency.
- Supports safe reprocessing and debugging.
- Makes data-quality problems easier to identify.

**Trade-offs**
- Additional validation and monitoring code is required.
- Analytical marts need maintenance as business requirements evolve.
- Some analyses will be limited by source coverage and data quality.

