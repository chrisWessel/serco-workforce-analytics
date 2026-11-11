# Serco Global Talent & Workforce Analytics — Power BI Data Model Architecture

## 1. Executive Summary & Semantic Model Design
The Serco Global Talent & Workforce Analytics semantic data model is architected as an **Enterprise Star Schema** optimized for high-concurrency executive querying, sub-second cross-filtering, and dynamic Generative HTML/SVG visual rendering.

The model unifies two core business domains:
1. **Contractual Operations & SLA Performance**: Incident velocity, resolution times, crown commercial SLA thresholds, and liquidated financial penalty exposure across 6 operational sectors and 11 global facilities.
2. **Global Talent Acquisition & Workforce Intelligence (Belong at Serco)**: 5-tier organizational hierarchy, gender parity benchmarks, ethnic diversity progression, armed forces veteran commitments, social mobility apprenticeships, and sourcing channel cost avoidance.

```
                           +-------------------+
                           |     Dim_Date      |
                           +-------------------+
                                     | 1
                                     | 
                                     | * (Active, Single)
                                     v
+-------------------+      +-------------------+      +-------------------+
|  Dim_CostCenters  | 1    |  Fact_SLATickets  |    1 |   Dim_Employees   |
|-------------------|----->|-------------------|----->|-------------------|
| Cost_Center_Code  |  *   | Ticket_ID (PK)    |  *   | Employee_ID (PK)  |
| Sector            | <--- | Created_Date (FK) | <--- | Gender            |
| Lead_Recruiter    | (Bi) | Cost_Center (FK)  | (Bi) | Ethnicity         |
+-------------------+      | Employee_ID (FK)  |      | Tier_Hierarchy    |
                           | Site_Code (FK)    |      | Role              |
+-------------------+      | Channel (FK)      |      +-------------------+
|    Dim_Channels   | 1    | Penalty_Cost_GBP  |
|-------------------|----->| Resolution_Hours  |      +-------------------+
| Channel_Name (PK) |  *   | Is_Breached       | 1    |     Dim_Sites     |
| Channel_Type      | <--- +-------------------+----->|-------------------|
| Benchmark_Cost    | (Bi)           | 1        * (Bi)| Site_Code (PK)    |
+-------------------+                |                | Facility_Name     |
                                     | 1              | Region            |
                                     v                +-------------------+
                           +-------------------+
                           | Fact_PowerApps_   |
                           | Remediation_Audit |
                           +-------------------+
```

---

## 2. Table Catalog & Granularity

| Table Name | Type | Primary / Unique Key | Granularity | Active Records | Role in Analytics |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`Fact_SLATickets`** | Fact (Central) | `Ticket_ID` | 1 row per incident / operational requisition | 30,000+ | Measures ticket latency, resolution duration, contractual breach flags, and financial penalties. |
| **`Fact_PowerApps_Remediation_Audit`** | Fact (Sub-domain) | `Remediation_ID` | 1 row per automated remediation trigger | 500+ | Tracks Power Automate and Power Apps workflow intervention success rates and manual vs automated MTTR. |
| **`Dim_Date`** | Dimension (Conformed) | `Date` | 1 row per calendar day (2024–2027) | 1,461 | Serves as the primary enterprise time-intelligence anchor. Explicitly marked as a **Date Table** in Power BI. |
| **`Dim_Employees`** | Dimension (SCD Type 2) | `Employee_ID` | 1 row per employee profile | 500 | Contains demographic attributes (Gender, Ethnicity, Social Mobility, Armed Forces Veteran status, Organizational Tier, Job Role). |
| **`Dim_CostCenters`** | Dimension | `Cost_Center_Code` | 1 row per operational cost center | 6 | Maps budget ownership, Sector divisions (Citizen Services, Defence, Health, FM, Justice, Transport), and Lead Recruiters. |
| **`Dim_Channels`** | Dimension | `Channel_Name` | 1 row per sourcing channel | 5 | Stores recruitment channel economics (Internal Mobility, Direct Sourcing, Veteran Programme, Graduate, Commercial Agency). |
| **`Dim_Sites`** | Dimension | `Site_Code` | 1 row per physical Serco facility | 11 | Geographic cluster mapping (Midlands HQ, South Coast Dockyard, North Harrogate, Scotland Glasgow). |

---

## 3. Relationship Architecture & Cross-Filtering Logic

### Why Bidirectional Filtering is Enabled on Dimensions
In standard one-to-many single-direction filtering (`Dim` $\rightarrow$ `Fact`), selecting an attribute from one dimension (e.g., `Dim_Employees[Gender] = 'Female'`) will filter `Fact_SLATickets`, but will **not** filter related dimensions like `Dim_CostCenters[Sector]` or `Dim_Channels[Channel]`. 

To enable executive drill-down across arbitrary slicing dimensions (e.g. filtering by **Gender**, **Ethnicity**, **Role**, or **Sector** in top slicers and having every KPI card, generative SVG chart, and ranked table update dynamically without blank cards), cross-filtering is configured as:
- **`Dim_Employees` $\leftrightarrow$ `Fact_SLATickets`**: Both directions (`CrossFilteringBehavior.BothDirections`).
- **`Dim_CostCenters` $\leftrightarrow$ `Fact_SLATickets`**: Both directions (`CrossFilteringBehavior.BothDirections`).
- **`Dim_Channels` $\leftrightarrow$ `Fact_SLATickets`**: Both directions (`CrossFilteringBehavior.BothDirections`).
- **`Dim_Sites` $\leftrightarrow$ `Fact_SLATickets`**: Both directions (`CrossFilteringBehavior.BothDirections`).
- **`Dim_Date` $\rightarrow$ `Fact_SLATickets`**: Single direction (`Dim_Date[Date]` 1 $\rightarrow$ * `Fact_SLATickets[Created_Date]`).

---

## 4. Date Table Configuration & Time Intelligence
- **Marked as Date Table**: `Dim_Date` is designated as the official date table using `Dim_Date[Date]` as the unique date key.
- **Sorting Consistency**:
  - `Month_Name` (e.g., "Jan", "Feb", "Mar") is explicitly sorted by `Month_Number` (1 to 12).
  - `Quarter` (e.g., "Q1", "Q2") is sorted by `Quarter_Number`.
  - Fiscal year calendars align with Crown Commercial contract quarters starting April 1st.
- **Time Intelligence Safety**: Slicers referencing `Dim_Date[Year]` and `Dim_Date[Month_Name]` maintain contiguous ranges, preventing calculation errors in `SAMEPERIODLASTYEAR`, `DATEADD`, and trailing moving averages.

---

## 5. Storage Engine Optimization
- **Columnstore Encoding**: Integer surrogate keys (`Cost_Center_Code`, `Site_Code`, `Employee_ID`) utilize run-length encoding (RLE) and dictionary compression.
- **Cardinality Reduction**: High-cardinality GUIDs and non-essential transaction logs are omitted from memory resident structures.
- **Memory Footprint**: Full VertiPaq compressed model resides under 45 MB in memory, allowing instant sub-second visual renders and seamless deployment to Power BI Service / Premium capacities.
