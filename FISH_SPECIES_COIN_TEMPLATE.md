# Fish Species Coin Contract Template

## Overview

This document defines the standardized template for creating individual fungible token contracts for each fish species in the DerbyFish ecosystem. Each species gets its own unique coin contract following these standards to ensure consistency and prevent conflicts.

## Metadata Standards

### Naming Convention

**Species Code Format**: `{GENUS}_{SPECIES}_{VARIANT?}`
- Use scientific genus and species names
- All uppercase with underscores
- Add variant suffix for subspecies if needed
- Maximum 20 characters

**Examples**:
- `MICROPTERUS_SALMOIDES` (Largemouth Bass)
- `SALMO_TRUTTA` (Brown Trout)
- `ESOX_LUCIUS` (Northern Pike)
- `PERCA_FLAVESCENS` (Yellow Perch)

### Ticker Symbol Standards

**Format**: `{GENUS_ABBREV}{SPECIES_ABBREV}`
- First 2-3 letters of genus + first 2-3 letters of species
- Maximum 6 characters
- All uppercase
- Must be globally unique

**Examples**:
- `MICSAL` (Micropterus salmoides - Largemouth Bass)
- `SALTR` (Salmo trutta - Brown Trout) 
- `ESLUC` (Esox lucius - Northern Pike)
- `PERFLA` (Perca flavescens - Yellow Perch)

### Display Name Standards

**Format**: `{Common Name} Coin`
- Use widely recognized common name
- Add "Coin" suffix
- Title case

**Examples**:
- "Largemouth Bass Coin"
- "Brown Trout Coin"
- "Northern Pike Coin"
- "Yellow Perch Coin"
