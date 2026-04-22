# Tight Norms Index (TNI): Construction Notes

## 1. Definition

The **Tight Norms Index (TNI)** is a composite county-level measure of social norm tightness, constructed via **Principal Component Analysis (PCA)** using three non-binary family-related variables observable in historical censuses. A lower coefficient of variance in any of these variables implies tighter norms within that county.

---

## 2. Input Variables

For each census year, the **county-level coefficient of variation (CV)** is computed for the following three variables:

| # | Variable | Description |
|---|---------|-------------|
| 1 | Mother's age at first birth | Age at which the mother had her first child |
| 2 | Total number of children | Total fertility count per mother |
| 3 | Number of distinct families residing in the same house | Measure of household composition |

> **Key intuition**: A lower CV indicates less dispersion around the county mean — i.e., individuals conform more closely to a common norm.

---

## 3. Data Source

- **Dataset**: U.S. Full Count Censuses
- **Time Coverage**: 1850 – 1940 (census years)
- **Reference**: Ruggles et al., 2020

---

## 4. Sample Selection

### 4.1 Inclusion Criteria

- Households with **married mothers** aged **35–44** at the time of the census
- Mothers who are either the **head of household** or the **wife of the head of household**

> **Rationale**: Restricting to ages 35–44 ensures that fertility is largely completed, minimizing variation driven by differences in age composition across counties rather than true norm differences.

### 4.2 Exclusion Criteria

- Exclude individuals living in **group quarters**

### 4.3 Baseline Sample

- **White native-born mothers** only

### 4.4 Alternative Samples

| Alternative Sample | Added Group |
|-------------------|------------|
| Alternative (i) | Foreign-born individuals |
| Alternative (ii) | Non-white individuals |
| Alternative (iii) | Both foreign-born and non-white individuals |

---

## 5. Construction Workflow

```
Raw census data (1850–1940)
        ↓
Apply sample restrictions
  - Married mothers aged 35–44
  - Head of household or wife of head
  - Exclude group quarters residents
  - Baseline: white native-born only
        ↓
For each census year & county, compute the
coefficient of variation (CV) for each of the 3 input variables:
  (1) Mother's age at first birth
  (2) Total number of children
  (3) Number of distinct families in the same house
        ↓
Run Principal Component Analysis (PCA) at the county level
using the 3 CVs as inputs — separately for each census year
        ↓
Extract the first eigenvector → Tight Norms Index (TNI)
        ↓
Standardize TNI into z-scores within each census year
```

---

## 6. PCA Results & Validation

| Property | Value |
|---------|-------|
| Variance explained by first component | 42% – 56% (varies by year and sample) |
| Eigenvalue of first component | 1.26 – 1.73 (always > 1 across all years and samples) |
| Sign of loadings on the 3 variables | Always the same sign across all years and samples |

- The first eigenvector is the **only component with an eigenvalue > 1** in all years and samples, satisfying the Kaiser criterion and justifying its use as the sole composite measure.
- Consistent loading signs confirm that all three variables capture a **common underlying dimension** of norm tightness.

---

## 7. Standardization

Because the TNI has no natural unit of interpretation, it is **standardized into z-scores within each census year**:

$$
\text{TNI}^{z}_{c,t} = \frac{\text{TNI}_{c,t} - \overline{\text{TNI}}_{t}}{\sigma_{\text{TNI},t}}
$$

where $c$ denotes county and $t$ denotes census year. This allows estimated effects to be interpreted in terms of standard deviation changes.

---

## 8. Notes

1. **Age restriction (35–44)** is critical to ensure the CV reflects norm conformity rather than lifecycle differences in fertility across counties.
2. **CV as the input** (rather than raw means) captures the *dispersion* of behavior, which is the theoretically relevant measure of norm tightness.
3. **Year-specific PCA** is conducted separately for each census year, so TNI loadings may vary across years — the consistent sign pattern provides reassurance of comparability over time.
4. **Z-score standardization** is applied within year, so cross-year comparisons of TNI levels should be made with caution.
