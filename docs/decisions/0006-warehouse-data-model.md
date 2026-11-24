# ADR 0006: Redshift Warehouse Data Model

**Status:** Accepted  
**Phase:** Data Modelling & Architecture

## Context

Agrolens requires a warehouse structure that separates source ingestion, data cleaning and business-facing analytical models.

## Decision

Use three Redshift schemas:

| Schema | Responsibility |
|---|---|
| `raw` | Source data loaded from S3 |
| `staging` | Cleaned and standardised dbt models |
| `analytics` | Business-ready analytical models |

### Fact tables and grain

| Fact table | Grain |
|---|---|
| `fct_prices_historical` | One WFP price observation per market, commodity, date, price type and unit |
| `fct_prices_current` | One SRID price observation per market, commodity, date and price type, retaining available source-specific attributes |
| `fct_production_annual` | One commodity, year and production measure |
| `fct_rainfall_daily` | One daily rainfall observation per selected location |

### Proposed dimensions

- `dim_date`
- `dim_market`
- `dim_commodity`
- `dim_unit`
- `dim_region`
- `dim_location`

Dimensions will provide consistent descriptive attributes and identifiers for analytical models.

Source-specific attributes will be retained where necessary.

## Consequences

**Benefits**
- Clear separation of warehouse responsibilities.
- Easier debugging and testing of transformations.
- Supports reusable dimensions and analytical models.
- Establishes explicit fact-table grains.

**Trade-offs**
- Requires additional transformation steps.
- Shared dimensions must be carefully designed to avoid misleading joins between datasets with different coverage.

