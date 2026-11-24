# ADR 0003: Price Sources and Commodity Scope

**Status:** Accepted  
**Phase:** Data Modelling & Architecture

## Context

Agrolens uses two price datasets:

- WFP historical food prices (2006–July 2023).
- SRID / MoFA weekly market prices (April–October 2025).

The datasets differ in date coverage, geographic coverage and available attributes. There is also a 21-month gap between their available periods.

Agrolens also requires a defined commodity scope for its agricultural market analysis.

## Decision

Maintain two separate price fact tables:

- `fct_prices_historical` for WFP.
- `fct_prices_current` for SRID.

Adopt the following six commodities as the overall project scope:

1. Rice
2. Maize
3. Cocoa beans
4. Groundnuts
5. Cassava
6. Yam

Only include a commodity in a particular price analysis when the relevant source contains usable observations.

## Consequences

**Benefits**
- Preserves source-specific characteristics.
- Prevents misleading assumptions about continuous price coverage.
- Allows independent validation and transformation of each source.
- Establishes a clear agricultural commodity scope.

**Trade-offs**
- Some analytical queries will need to combine separate fact tables.
- Not all six commodities will be available in every dataset.

