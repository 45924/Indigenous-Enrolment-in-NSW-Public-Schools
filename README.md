# Indigenous Enrolment in NSW Public Schools

**The rate is remote, the numbers are urban.** An analysis of how Aboriginal and Torres Strait Islander enrolment is distributed across every open NSW government school — built three ways (R, Excel, Power BI) so the same story lands for three different audiences.

> Across 2,210 NSW public schools, the *percentage* of Indigenous enrolment is highest in the bush, but the *number* of Indigenous students is overwhelmingly urban. Roughly **85%** of the state's Indigenous public‑school students attend Major‑City and Inner‑Regional schools. Rate and count point to different places — and both matter for how schools are resourced.

<!-- Add screenshots here once exported -->
<!-- ![Power BI — Overview](images/powerbi_overview.png) -->
<!-- ![Power BI — Factors](images/powerbi_factors.png) -->
<!-- ![Excel — Dashboard](images/excel_dashboard.png) -->

---

## Contents

- [Key findings](#key-findings)
- [Repository structure](#repository-structure)
- [The Power BI dashboard](#the-power-bi-dashboard)
- [The Excel artifact](#the-excel-artifact)
- [Data](#data)
- [Method and measures](#method-and-measures)
- [Analytical caveats](#analytical-caveats)
- [Reproducing the results](#reproducing-the-results)
- [Skills demonstrated](#skills-demonstrated)

---

## Key findings

1. **A clean remoteness gradient.** Enrolment‑weighted Indigenous share rises from **6% in Major Cities** to **72% in Very Remote** schools.
2. **The concentration paradox (the headline).** The highest percentages are remote, but ~**85%** of all Indigenous students attend Major‑City and Inner‑Regional schools — because that is where enrolment volume sits. A policy chasing only the high‑percentage remote schools would miss five out of six Indigenous students.
3. **Enrolment tracks disadvantage.** Schools in the most disadvantaged ICSEA band average **~42%** Indigenous enrolment versus **~2%** in the most advantaged. The relationship holds against FOEI (r ≈ **+0.69**), an index that — unlike ICSEA — does not embed Aboriginality.
4. **Regional hubs carry the load.** In absolute terms, the Hunter and Metropolitan West AECG regions hold the largest Indigenous cohorts; western regions carry the highest shares (30%+).

### Headline numbers

| Metric | Value |
|---|---:|
| Schools analysed | 2,210 |
| Total enrolment (FTE) | 772,482 |
| Estimated Indigenous enrolment (FTE) | 77,023 |
| Indigenous share of enrolment (weighted) | 10.0% |
| Share in Major Cities | 6.1% |
| Share in Very Remote schools | 72.1% |
| Indigenous students in city + inner‑regional | ~85% |
| Schools with suppressed Indigenous data (≤5 students) | 501 (22.7%) |

---

## Repository structure

```
nsw-schools-indigenous-enrolment/
├── README.md
├── data/
│   └── NSW_government_school_locations_and_student_enrolment_numbers.csv
├── powerbi/
│   └── NSW_School_Indigenous_Dashboard.pbix
├── excel/
│   └── NSW_Schools_Indigenous_Analysis.xlsx
├── r/
│   └── indigenous_enrolment_visualisation.R
└── images/
    ├── powerbi_overview.png
    ├── powerbi_factors.png
    └── excel_dashboard.png
```

---

## The Power BI dashboard

`powerbi/NSW_School_Indigenous_Dashboard.pbix` — an interactive two‑page report with a full DAX model, insight‑driven chart titles, drill‑ready slicers, and a bubble map.

**Page 1 — Overview**
KPI cards (schools, students, Indigenous students, Indigenous share, % suppressed); a bubble **map** of Indigenous enrolment by location and remoteness; and the **concentration‑paradox** chart contrasting each remoteness band's share of *all* students with its share of *all Indigenous* students.

**Page 2 — Factors**
Slicers (remoteness, level of schooling, data status, ICSEA band) driving: the **remoteness rate gradient**; a school‑level **scatter** of Indigenous % vs FOEI disadvantage (sized by enrolment, coloured by remoteness); the **ICSEA‑band** column chart; and an **AECG‑region** matrix of absolute cohorts and shares.

Chart titles state the finding, not the field names — e.g. *"Indigenous share of enrolment climbs from 6% in Major Cities to 72% in Very Remote schools."*

---

## The Excel artifact

`excel/NSW_Schools_Indigenous_Analysis.xlsx` — a self‑contained, PivotTable‑driven workbook.

| Sheet | What it contains |
|---|---|
| **README** | Project overview, data dictionary, and insight summary. |
| **Data** | Cleaned dataset as an Excel Table (`tblSchools`), PivotTable‑ and slicer‑ready, with derived fields (Indigenous FTE estimate, ICSEA/enrolment bands, remoteness sort key, suppression flag). |
| **PT_Remoteness / PT_Paradox / PT_ICSEA / PT_Level** | Native PivotTables behind each panel. |
| **Dashboard** | One‑page interactive dashboard: 2×2 PivotCharts driven by shared slicers (remoteness, level, selective, size), with a title banner and headline callout. |
| **Summary** | Formula‑built reference tables (`SUMIFS` / `COUNTIFS` / `AVERAGEIFS`) that verify the PivotTables. |

The workbook deliberately distinguishes **enrolment‑weighted %** (`SUM(Indigenous FTE) / SUM(Total FTE)`) from a **simple average of school percentages** — the two answer different questions, and mixing them is the most common error in this kind of analysis.

---

## Data

- **Source:** *NSW government school locations and student enrolment numbers*, NSW Department of Education, published via [Data NSW](https://data.nsw.gov.au/).
- **Licence:** Creative Commons Attribution (CC‑BY).
- **Grain:** one row per open NSW government school.
- **Extract date:** May 2026.

### Data dictionary (key fields)

| Field | Meaning |
|---|---|
| `Enrolment_FTE` | Full‑time‑equivalent enrolment. |
| `Indigenous_pct` | % of FTE identifying as Aboriginal/Torres Strait Islander. Suppressed (`np`) where ≤5 students. |
| `ICSEA_value` | National socio‑educational **advantage** index (mean 1000, higher = more advantaged). Incorporates parental education/occupation, remoteness, and student Aboriginality. |
| `FOEI_value` | NSW socio‑educational **disadvantage** index (mean 100, higher = more disadvantaged). Built from parental education and occupation only. |
| `ASGS_remoteness` | ABS remoteness class (Major Cities → Very Remote). |
| `AECG_region` | Aboriginal Education Consultative Group region. |

---

## Method and measures

Cleaning: `np` suppression converted to null; numeric types enforced; derived bands and an estimated Indigenous‑FTE column added. In Power BI this is done in Power Query; in Excel via helper columns on `tblSchools`.

Core DAX measures in the Power BI model:

```DAX
Total FTE            = SUM ( Schools[Enrolment_FTE] )
Est Indigenous FTE   = SUMX ( Schools, DIVIDE ( Schools[Indigenous_pct], 100 ) * Schools[Enrolment_FTE] )
School Count         = COUNTROWS ( Schools )
% Suppressed         = DIVIDE ( [School Count] - CALCULATE ( [School Count], NOT ISBLANK ( Schools[Indigenous_pct] ) ), [School Count] )

-- Enrolment-weighted share (headline metric)
Indigenous % of Enrolment = DIVIDE ( [Est Indigenous FTE], [Total FTE] )

-- The concentration paradox
Share of All Students  = DIVIDE ( [Total FTE], CALCULATE ( [Total FTE], ALL ( Schools ) ) )
Share of All Indigenous = DIVIDE ( [Est Indigenous FTE], CALCULATE ( [Est Indigenous FTE], ALL ( Schools ) ) )
```

---

## Analytical caveats

- **Suppression.** Indigenous and LBOTE percentages are withheld where ≤5 students, so 501 schools (mostly small and remote) have no published figure. Suppressed schools are excluded from averages but their enrolment still counts in totals.
- **Weighted vs simple percentages.** The headline share is enrolment‑weighted; a naïve average of school percentages over‑weights tiny schools and is used only for the per‑school distribution view.
- **ICSEA circularity.** ICSEA embeds student Aboriginality in its formula, so the ICSEA–Indigenous relationship is partly definitional. The scatter therefore uses **FOEI**, which does not, as the independent measure of disadvantage.
- **Estimated headcounts.** Indigenous FTE is reconstructed as `Indigenous_pct × Enrolment_FTE`; it is an estimate, not a reported count.

---

## Reproducing the results

- **Power BI:** open the `.pbix` in Power BI Desktop (the CSV is embedded in the model; re‑point the source under *Transform data* if needed).
- **Excel:** open the `.xlsx`; the `Data` sheet is the live Table — refresh PivotTables from *PivotTable Analyze → Refresh*.
- **R:** the original visualisation script in `r/` regenerates the source charts with `ggplot2`.

Every artifact reconciles to the same headline numbers in the table above.

---

## Skills demonstrated

Data cleaning and modelling (Power Query, Excel Tables) · DAX (weighted measures, `ALL`/`CALCULATE` context, share‑of‑total) · PivotTables, slicers and dashboard design · interactive reporting and insight‑driven data storytelling · R / `ggplot2` visualisation · careful treatment of suppression, weighting, and index circularity.

---

*Author: Thanh Phong (Johnny) Phung · Master of Business Analytics, Macquarie University. Data © State of New South Wales (Department of Education), reused under CC‑BY.*
