# Intra-Community Marriage (ICM) Indicator: Construction Notes

## 1. Definition

**Individual-level ICM** is a binary dummy variable:

$$
\text{ICM}_{i} =
\begin{cases}
1 & \text{if a married couple shares a common birthplace} \\
0 & \text{otherwise}
\end{cases}
$$

**County-level ICM** is defined as:

$$
\text{ICM}_{\text{county}} = \frac{\text{Number of ICM couples in the county}}{\text{Total number of couples in the county}}
$$

---

## 2. Birthplace Classification Rules

| Individual Type | Unit of Birthplace |
|----------------|-------------------|
| Native-born | State of birth |
| Foreign-born | Country of birth |

> **Matching logic**: A couple is coded ICM = 1 only if both spouses share the same birthplace unit (same state or same country).

---

## 3. Data Source

- **Dataset**: U.S. Full Count Censuses
- **Time Coverage**: 1850 – 1940
- **Missing Year**: 1890 data is unavailable and must be excluded
- **Reference**: Ruggles et al., 2020

---

## 4. Sample Selection

### 4.1 Exclusion Criteria (applied to all samples)

- Exclude individuals living in **group quarters**
- Exclude married individuals with **missing spouse information**

### 4.2 Baseline Sample

Restricted to:
- **White**
- **Native-born** couples only

### 4.3 Alternative Samples

Each alternative sample adds the following groups on top of the baseline:

| Alternative Sample | Added Group |
|-------------------|------------|
| Alternative (i) | Foreign-born individuals |
| Alternative (ii) | Non-white individuals |
| Alternative (iii) | Both foreign-born and non-white individuals |

---

## 5. Construction Workflow

```
Raw census data (1850–1940, excluding 1890)
        ↓
Exclude group quarters residents & observations with missing spouse data
        ↓
Identify married couples
        ↓
Assign birthplace unit by nativity (native-born → state; foreign-born → country)
        ↓
Compare birthplaces of both spouses → generate individual-level ICM (0/1)
        ↓
Aggregate to county level: ICM_county = # ICM couples / # total couples
        ↓
Construct baseline sample (white native-born) + three alternative samples
```

---

## 6. Notes

1. **1890 data is missing** — this gap must be accounted for explicitly in any time-series analysis.
2. **Asymmetric birthplace granularity** — native-born individuals are matched at the state level while foreign-born are matched at the country level. This difference in geographic resolution should be considered carefully in mixed samples that include foreign-born individuals.
3. **County-level ICM is a proportion** (ranging from 0 to 1) — appropriate transformations or weighting may be warranted in regression analyses.
