# ADR 0005: Rainfall Linkage and Production Data

**Status:** Accepted  
**Phase:** Data Modelling & Architecture

## Context

Agrolens combines market prices, weather observations and agricultural production data to investigate potential relationships between rainfall patterns and food-price movements.

SRID has no usable market coordinates, while WFP provides market coordinates.

FAOSTAT provides annual production observations with different reporting flags.

## Decision

### 1. Rainfall linkage

Use regional-level rainfall linkage for the first version.

- Associate markets with their administrative regions.
- Select representative rainfall coordinates for the relevant regions.
- Retrieve daily weather observations from Open-Meteo.
- Analyse rainfall and price movements at different time lags.

Regional rainfall is an approximation and must not be treated as a direct measurement of rainfall in specific farming communities.

Rainfall-price relationships will be interpreted as associations, not proof of causation.

### 2. FAOSTAT production data

Preserve all available production observations and their original reporting flags.

Retain:
- `Flag`
- `Flag Description`

Use official observations (`A`) by default for indicators that specifically require official production figures.

The production fact table will support:
- Production quantity.
- Area harvested.
- Yield.

## Consequences

**Benefits**
- Establishes a consistent rainfall-linkage approach across price sources.
- Preserves potentially useful production information.
- Allows analysts to distinguish official and estimated observations.

**Trade-offs**
- Regional rainfall may hide local variations.
- Different production flags have different reliability levels.
- Annual production data cannot independently explain short-term price movements.

