# Religious Homogeneity Index (RHI): Construction Notes

## 1. Definition

The **Religious Homogeneity Index (RHI)** is a county-level measure of religious concentration, defined as:

$$
\text{Religious Homogeneity Index}_{ct} = \sum_{j} s_{cjt}^{2}
$$

where $s_{cjt}$ is the share of members of religious denomination $j$, in county $c$, in year $t$, out of the total number of members in religious institutions in county $c$ in year $t$.

---

## 2. Interpretation

- The RHI is equivalent to the **Herfindahl–Hirschman Index (HHI)** applied to the shares of religious denomination membership.
- Intuitively, it measures the **probability that two randomly drawn individuals** from the population of religious institution members in a county **belong to the same denomination**.
- A **higher RHI** indicates greater religious homogeneity (concentration in fewer denominations).
- A **lower RHI** indicates greater religious diversity (membership spread across many denominations).

---

## 3. Data Source

- **Unit of observation**: County-level membership counts by religious denomination
- **Years covered**: 1850, 1860, 1870, 1890, 1906, 1916, 1926, 1936
- **Reference**: Manson et al., 2020

> **Note**: The list of religious denominations for which data is collected **varies across years**, which affects cross-year comparability of raw RHI values.

---

## 4. Construction Workflow

```
County-level data on religious institution membership by denomination
(Manson et al., 2020) for years: 1850, 1860, 1870, 1890, 1906, 1916, 1926, 1936
        ↓
For each county c and year t, compute the membership share
for each denomination j:
  s_cjt = (members of denomination j in county c, year t)
          / (total religious members in county c, year t)
        ↓
Square each share: s²_cjt
        ↓
Sum squared shares across all denominations j within each county-year:
  RHI_ct = Σ_j s²_cjt
        ↓
Standardize RHI into z-scores within each year
```

---

## 5. Standardization

Because the set of denominations tracked varies across years, the raw RHI is not directly comparable across census years. To ease interpretation, the RHI is **standardized into z-scores within each year**:

$$
\text{RHI}^{z}_{ct} = \frac{\text{RHI}_{ct} - \overline{\text{RHI}}_{t}}{\sigma_{\text{RHI},t}}
$$

where $c$ denotes county and $t$ denotes year. This allows estimated effects to be interpreted as responses to a one-standard-deviation change in religious homogeneity.

---

## 6. Notes

1. **Varying denomination coverage**: Because the denominations recorded differ across years, within-year standardization is essential before making any cross-year comparisons.
2. **Relationship to HHI**: The RHI is mathematically identical to the Herfindahl–Hirschman Index — a well-established measure of market (or group) concentration — applied here to religious membership shares.
3. **Range**: The raw RHI lies between $\frac{1}{J}$ (perfectly equal distribution across $J$ denominations) and $1$ (complete concentration in a single denomination).
4. **Data coverage**: Note that 1880 and years after 1936 are not included in the available religious census data.
