# Serco Global Talent & Workforce Analytics — DAX Measures Catalog

This catalog documents the core and advanced DAX measures implemented in the **`_Key Measures`** semantic table.

---

## 1. Operational & SLA Compliance Measures

### 1.1 Total Ingested Incidents
```dax
Total Incidents = 
COUNTROWS('Fact_SLATickets')
```

### 1.2 SLA Breaches
```dax
SLA Breaches = 
CALCULATE(
    COUNTROWS('Fact_SLATickets'),
    KEEPFILTERS('Fact_SLATickets'[Is_Breached] = 1)
)
```

### 1.3 Contractual SLA Compliance Rate (%)
```dax
SLA Compliance % = 
VAR _Total = [Total Incidents]
VAR _Breaches = [SLA Breaches]
RETURN
IF(
    ISBLANK(_Total) || _Total = 0,
    1.0,
    DIVIDE(_Total - _Breaches, _Total, 1.0)
)
```

### 1.4 Financial Penalty Exposure (GBP)
```dax
Financial Penalty Exposure = 
SUM('Fact_SLATickets'[Penalty_Cost_GBP])
```

### 1.5 Average Resolution Latency (Hours)
```dax
Avg Resolution Hours = 
AVERAGE('Fact_SLATickets'[Resolution_Time_Hours])
```

### 1.6 Month-over-Month (MoM) Incident Growth Rate
```dax
MoM Incident Growth % = 
VAR _CurrentMonth = [Total Incidents]
VAR _PriorMonth = 
    CALCULATE(
        [Total Incidents],
        DATEADD('Dim_Date'[Date], -1, MONTH)
    )
RETURN
DIVIDE(_CurrentMonth - _PriorMonth, _PriorMonth, 0)
```

---

## 2. Talent Acquisition & Sourcing Economics Measures

### 2.1 Total Active Operational Hires
```dax
Total Hires = 
DISTINCTCOUNT('Fact_SLATickets'[Employee_ID])
```

### 2.2 Actual Sourcing Channel Spend (GBP)
```dax
Actual Sourcing Spend = 
SUMX(
    'Fact_SLATickets',
    RELATED('Dim_Channels'[Benchmark_Cost_Per_Hire_GBP])
)
```

### 2.3 Commercial Agency Baseline Spend (GBP)
```dax
Agency Baseline Spend = 
VAR _AgencyBenchmark = 7500.00 -- Standard 3rd-party agency placement fee
RETURN
[Total Hires] * _AgencyBenchmark
```

### 2.4 Net Recruitment Cost Avoidance (Savings)
```dax
Recruitment Cost Avoidance = 
VAR _Baseline = [Agency Baseline Spend]
VAR _Actual = [Actual Sourcing Spend]
RETURN
_Baseline - _Actual
```

### 2.5 90-Day Employee Retention Rate (%)
```dax
90-Day Retention % = 
AVERAGEX(
    'Fact_SLATickets',
    RELATED('Dim_Channels'[Avg_90Day_Retention_Pct])
)
```

---

## 3. Diversity, Equity & Inclusion (EDI) Measures

### 3.1 Female Representation Rate (%)
```dax
Female Representation % = 
VAR _TotalEmployees = COUNTROWS('Dim_Employees')
VAR _FemaleEmployees = 
    CALCULATE(
        COUNTROWS('Dim_Employees'),
        KEEPFILTERS('Dim_Employees'[Gender] = "Female")
    )
RETURN
DIVIDE(_FemaleEmployees, _TotalEmployees, 0)
```

### 3.2 Ethnic Minority Representation Rate (%)
```dax
Ethnic Minority % = 
VAR _TotalEmployees = COUNTROWS('Dim_Employees')
VAR _EthnicMinority = 
    CALCULATE(
        COUNTROWS('Dim_Employees'),
        NOT('Dim_Employees'[Ethnicity] IN {"White - British", "White - Other"})
    )
RETURN
DIVIDE(_EthnicMinority, _TotalEmployees, 0)
```

### 3.3 Armed Forces Covenant & Veteran Placements
```dax
Armed Forces Veteran Hires = 
CALCULATE(
    COUNTROWS('Dim_Employees'),
    KEEPFILTERS('Dim_Employees'[Is_Veteran] = 1)
)
```

### 3.4 Female Leadership Target Parity Deficit (40% Target)
```dax
Executive Female Deficit = 
VAR _LeadershipCohort = 
    CALCULATE(
        COUNTROWS('Dim_Employees'),
        'Dim_Employees'[Tier_Hierarchy] IN {
            "4. Senior Leadership & Directors",
            "5. Executive Directorate & Board"
        }
    )
VAR _FemaleLeaders = 
    CALCULATE(
        COUNTROWS('Dim_Employees'),
        'Dim_Employees'[Gender] = "Female",
        'Dim_Employees'[Tier_Hierarchy] IN {
            "4. Senior Leadership & Directors",
            "5. Executive Directorate & Board"
        }
    )
VAR _TargetCount = CEILING(_LeadershipCohort * 0.40, 1)
RETURN
MAX(0, _TargetCount - _FemaleLeaders)
```

---

## 4. Generative HTML / SVG UI Render Architecture

The platform uses custom HTML/SVG generative measures rendered within certified Power BI HTML Content viewers. This bypasses standard native visual limitations to deliver:
1. **Dynamic Dark Theme Design System**: Built with Serco brand guidelines (`#0F172A` Slate Dark, `#0284C7` Cyan Blue, `#E01E26` Breach Crimson, `#059669` Emerald Green).
2. **Dynamic Mathematical Scaling**: Bar chart widths, donut stroke dashoffsets, and scatter coordinate plots are computed on-the-fly inside DAX variables and interpolated directly into SVG code.
3. **Responsive Slicing Integration**: Because measures read context dynamically using `CALCULATE`, whenever a user clicks a Year, Month, Sector, Role, or Gender slicer, the HTML strings re-evaluate instantly at 60fps.

### Sample Pattern: Dynamic SVG Donut Chart in DAX
```dax
HTML_Donut_Snippet = 
VAR _Pct = [SLA Compliance %]
VAR _Circumference = 2 * PI() * 32
VAR _Offset = _Circumference * (1 - _Pct)
VAR _Color = IF(_Pct >= 0.90, "#10B981", "#EF4444")
RETURN
"<svg width='80' height='80' viewBox='0 0 80 80'>" &
  "<circle cx='40' cy='40' r='32' fill='none' stroke='#334155' stroke-width='8' />" &
  "<circle cx='40' cy='40' r='32' fill='none' stroke='" & _Color & "' stroke-width='8' " &
  "stroke-dasharray='" & _Circumference & "' stroke-dashoffset='" & _Offset & "' " &
  "stroke-linecap='round' transform='rotate(-90 40 40)' />" &
  "<text x='40' y='45' text-anchor='middle' fill='#F8FAFC' font-size='14' font-weight='bold'>" &
  FORMAT(_Pct, "0.0%") & "</text>" &
"</svg>"
```
