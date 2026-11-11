import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Set seed for reproducible synthetic data
np.random.seed(42)
n_tickets = 15000
n_staff = 500

# -----------------------------------------------------------------------------
# 1. DIMENSION: Dim_CostCenters (Sectors & Divisional Cost Centers)
# -----------------------------------------------------------------------------
cost_centers_data = {
    'Cost_Center_ID': ['CC-1010', 'CC-2020', 'CC-3030', 'CC-4040', 'CC-5050', 'CC-6060'],
    'Cost_Center_Name': [
        'CC-1010 Citizen Contact Hubs',
        'CC-2020 Defence Logistics Command',
        'CC-3030 Health Advisory & Clinical',
        'CC-4040 Facilities & Infrastructure',
        'CC-5050 Justice & Immigration Services',
        'CC-6060 Transport, Transit & Aviation'
    ],
    'Sector': [
        'Citizen Services (Contact Centre)',
        'Defence Logistics',
        'Health Advisory',
        'Facilities Management',
        'Justice & Immigration',
        'Transport & Transit'
    ],
    'Division': [
        'Citizen & Digital Services',
        'Defence & National Security',
        'Health & Complex Care',
        'Infrastructure & Estates',
        'Justice & Custodial',
        'Transport & Aviation'
    ],
    'Cost_Center_Lead': ['Sarah Jenkins', 'Col. Mark Davies', 'Dr. Rachel Patel', 'Andrew Scott', 'Marcus Vance', 'Claire Thompson'],
    'Annual_Budget_GBP': [4200000.0, 5800000.0, 3600000.0, 2900000.0, 4800000.0, 3100000.0]
}
df_cost_centers = pd.DataFrame(cost_centers_data)

# -----------------------------------------------------------------------------
# 2. DIMENSION: Dim_Sites (Serco Primary Operational Bases & Regions)
# -----------------------------------------------------------------------------
sites_data = {
    'Site_ID': [f"STE-{100 + i}" for i in range(11)],
    'Site_Name': [
        'Solihull HQ Operations', 'Portsmouth Dockyard', 'Harrogate Hub', 
        'Glasgow Operations', 'Hook Logistics Base', 'Lincoln Hub', 
        'Reading Tech Facility', 'Coventry Logistics Depot',
        'Washington Federal Center', 'Sydney Transit Control', 'Abu Dhabi Healthcare Hub'
    ],
    'Region': [
        'Midlands', 'South Coast', 'North', 
        'Scotland', 'Midlands', 'Midlands', 
        'South Coast', 'Midlands',
        'Americas', 'APAC', 'Middle East'
    ],
    'Country': ['UK', 'UK', 'UK', 'UK', 'UK', 'UK', 'UK', 'UK', 'USA', 'Australia', 'UAE'],
    'Capacity_Threshold_Daily': [600, 450, 400, 350, 500, 300, 400, 500, 450, 400, 350]
}
df_sites = pd.DataFrame(sites_data)

# -----------------------------------------------------------------------------
# 3. DIMENSION: Dim_Channels (Recruitment & Sourcing Pathways)
# -----------------------------------------------------------------------------
channels_data = {
    'Channel_ID': ['CH-01', 'CH-02', 'CH-03', 'CH-04', 'CH-05'],
    'Channel_Name': [
        'Employee Referral',
        'Direct Careers Portal',
        'LinkedIn Talent Solutions',
        'Specialist Search Agency',
        'Internal Mobility Pathway'
    ],
    'Channel_Category': [
        'Direct Sourcing',
        'Direct Sourcing',
        'Digital Sourcing',
        'Contingent Agency',
        'Internal Pipeline'
    ],
    'Channel_Cost_Benchmark_GBP': [550.0, 920.0, 1650.0, 3850.0, 420.0],
    'Retention_Benchmark_Pct': [0.94, 0.88, 0.89, 0.79, 0.92]
}
df_channels = pd.DataFrame(channels_data)

# -----------------------------------------------------------------------------
# 4. DIMENSION: Dim_Employees (Workforce, Diversity, EDI & Role Hierarchy)
# -----------------------------------------------------------------------------
male_first_names = [
    'James', 'John', 'Robert', 'Michael', 'David', 'Liam', 'Kwame', 'Tariq', 
    'Marcus', 'Andrew', 'Mark', 'Daniel', 'Christopher', 'Anthony', 'Matthew'
]
female_first_names = [
    'Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Aisha', 'Priya', 
    'Sophie', 'Sarah', 'Rachel', 'Claire', 'Emma', 'Jessica', 'Emily', 'Olivia'
]
unisex_first_names = [
    'Chen', 'Temitope', 'Alex', 'Taylor', 'Jordan', 'Morgan', 'Sam', 'Cameron'
]

last_names = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 
    'Davis', 'Rodriguez', 'Martinez', 'Khan', 'Adeyemi', 'Patel', 'Zhang', 
    'Okonkwo', 'Wilson', 'Anderson', 'Taylor', 'Scott', 'Jenkins'
]

ethnicities = [
    'White British', 
    'Asian / Asian British', 
    'Black / African / Caribbean', 
    'Mixed / Multiple Ethnic Groups', 
    'Other Ethnic Group'
]
ethnicity_weights = [0.70, 0.14, 0.08, 0.05, 0.03]

veteran_statuses = ['Non-Forces', 'Armed Forces Veteran', 'Military Reservist', 'Forces Family / Spouse']
veteran_weights = [0.86, 0.08, 0.04, 0.02]

disability_statuses = ['No Declared Disability', 'Declared Disability / Neurodivergent']
disability_weights = [0.88, 0.12]

hierarchy_tiers = [
    '1. Frontline Operative', 
    '2. First-Line Supervisor', 
    '3. Operational Manager', 
    '4. Senior Leader', 
    '5. Executive Directorate'
]
hierarchy_weights = [0.58, 0.22, 0.14, 0.04, 0.02]

roles = [
    'Service Desk Analyst', 
    'Field Logistics Lead', 
    'Case Handler', 
    'Operations Shift Manager',
    'Talent Acquisition Specialist',
    'Continuous Improvement Lead'
]
role_weights = [0.35, 0.25, 0.20, 0.10, 0.05, 0.05]

# Generate employee roster with 100% strictly matched names and genders
staff_ids = [f"EMP-{5000 + i}" for i in range(n_staff)]
staff_names = []
staff_genders = []

for _ in range(n_staff):
    # Choose gender first
    g = np.random.choice(['Female', 'Male', 'Non-Binary'], p=[0.48, 0.50, 0.02])
    if g == 'Male':
        fn = np.random.choice(male_first_names)
    elif g == 'Female':
        fn = np.random.choice(female_first_names)
    else:
        fn = np.random.choice(unisex_first_names)
    ln = np.random.choice(last_names)
    staff_names.append(f"{fn} {ln}")
    staff_genders.append(g)

staff_roles = np.random.choice(roles, n_staff, p=role_weights)

# Map tier from role
role_to_tier = {
    'Operations Shift Manager': '3. Operational Manager',
    'Continuous Improvement Lead': '3. Operational Manager',
    'Field Logistics Lead': '2. First-Line Supervisor',
    'Talent Acquisition Specialist': '2. First-Line Supervisor',
    'Service Desk Analyst': '1. Frontline Operative',
    'Case Handler': '1. Frontline Operative'
}
staff_tiers = [role_to_tier.get(r, '1. Frontline Operative') for r in staff_roles]

staff_data = {
    'Employee_ID': staff_ids,
    'Employee_Name': staff_names,
    'Gender': staff_genders,
    'Ethnicity': np.random.choice(ethnicities, n_staff, p=ethnicity_weights),
    'Veteran_Status': np.random.choice(veteran_statuses, n_staff, p=veteran_weights),
    'Disability_Status': np.random.choice(disability_statuses, n_staff, p=disability_weights),
    'Hierarchy_Tier': staff_tiers,
    'Role': staff_roles,
    'Site_ID': np.random.choice(df_sites['Site_ID'], n_staff),
    'Cost_Center_ID': np.random.choice(df_cost_centers['Cost_Center_ID'], n_staff),
    'Channel_ID': np.random.choice(df_channels['Channel_ID'], n_staff, p=[0.21, 0.28, 0.28, 0.15, 0.08]),
    'Hourly_Rate_GBP': np.random.choice([18.50, 22.00, 26.50, 34.00, 42.00, 55.00], n_staff, p=[0.35, 0.25, 0.20, 0.10, 0.06, 0.04]),
    'Tenure_Years': np.random.choice([1, 2, 3, 4, 5, 7, 10, 15], n_staff, p=[0.25, 0.20, 0.18, 0.12, 0.10, 0.08, 0.05, 0.02])
}
df_employees = pd.DataFrame(staff_data)

# -----------------------------------------------------------------------------
# 5. FACT TABLE: Fact_SLATickets (30,000 Incidents across FY2025 & FY2026)
# -----------------------------------------------------------------------------
contract_types = ['Fixed Price KPI', 'Cost Plus SLA', 'Gainshare Operations']
priority_levels = ['P1 - Critical', 'P2 - High', 'P3 - Medium', 'P4 - Low']

n_tickets_2025 = 15000  # Prior Year Baseline (Full 2025)
n_tickets_2026 = 15000  # Active Year (Q1 2026)
total_tickets = n_tickets_2025 + n_tickets_2026

start_2025 = datetime(2025, 1, 1)
start_2026 = datetime(2026, 1, 1)

days_2025 = np.random.randint(0, 365, n_tickets_2025)
minutes_2025 = np.random.randint(0, 1440, n_tickets_2025)
timestamps_2025 = [start_2025 + timedelta(days=int(d), minutes=int(m)) for d, m in zip(days_2025, minutes_2025)]

days_2026 = np.random.randint(0, 90, n_tickets_2026)
minutes_2026 = np.random.randint(0, 1440, n_tickets_2026)
timestamps_2026 = [start_2026 + timedelta(days=int(d), minutes=int(m)) for d, m in zip(days_2026, minutes_2026)]

timestamps = timestamps_2025 + timestamps_2026
dates = [t.date() for t in timestamps]

# Assign Cost Centers (with associated Sectors)
assigned_cc_ids = np.random.choice(
    df_cost_centers['Cost_Center_ID'], 
    total_tickets, 
    p=[0.38, 0.24, 0.18, 0.12, 0.05, 0.03]
)
cc_to_sector = dict(zip(df_cost_centers['Cost_Center_ID'], df_cost_centers['Sector']))
assigned_sectors = [cc_to_sector[cid] for cid in assigned_cc_ids]

assigned_site_ids = np.random.choice(df_sites['Site_ID'], total_tickets)
site_to_region = dict(zip(df_sites['Site_ID'], df_sites['Region']))
assigned_regions = [site_to_region[sid] for sid in assigned_site_ids]

sla_targets = []
for sec in assigned_sectors:
    if 'Health' in sec:
        sla_targets.append(4)      # 4-hour SLA
    elif 'Citizen' in sec:
        sla_targets.append(12)     # 12-hour SLA
    elif 'Defence' in sec:
        sla_targets.append(48)     # 48-hour SLA
    elif 'Justice' in sec:
        sla_targets.append(8)      # 8-hour SLA
    elif 'Transport' in sec:
        sla_targets.append(6)      # 6-hour SLA
    else:
        sla_targets.append(24)     # 24-hour SLA

# Simulate Resolution Time & SLA Breaches (~14.1% breach rate)
actual_resolutions = []
for target in sla_targets:
    if np.random.rand() < 0.141:
        # Breached: 1.2x to 2.8x of target SLA
        actual_resolutions.append(round(target * np.random.uniform(1.2, 2.8), 2))
    else:
        # On-Time: 0.15x to 0.95x of target SLA
        actual_resolutions.append(round(target * np.random.uniform(0.15, 0.95), 2))

statuses = ['SLA Breached' if act > tgt else 'Resolved On-Time' for act, tgt in zip(actual_resolutions, sla_targets)]

op_costs = np.round(np.random.uniform(35.0, 950.0, total_tickets), 2)
penalties = [round(cost * 0.20, 2) if status == 'SLA Breached' else 0.00 for cost, status in zip(op_costs, statuses)]
csat_scores = [np.random.choice([1, 2], p=[0.6, 0.4]) if status == 'SLA Breached' else np.random.choice([3, 4, 5], p=[0.15, 0.50, 0.35]) for status in statuses]

assigned_staff_ids = np.random.choice(df_employees['Employee_ID'], total_tickets)
emp_lookup = df_employees.set_index('Employee_ID')

df_tickets = pd.DataFrame({
    'Ticket_ID': [f"SER-{100000 + i}" for i in range(total_tickets)],
    'Created_Timestamp': timestamps,
    'Created_Date': dates,
    'Cost_Center_ID': assigned_cc_ids,
    'Sector': assigned_sectors,
    'Contract_Type': np.random.choice(contract_types, total_tickets, p=[0.5, 0.3, 0.2]),
    'Priority': np.random.choice(priority_levels, total_tickets, p=[0.1, 0.25, 0.45, 0.2]),
    'Site_ID': assigned_site_ids,
    'Region': assigned_regions,
    'Assigned_Employee_ID': assigned_staff_ids,
    'Staff_Name': [emp_lookup.loc[eid, 'Employee_Name'] for eid in assigned_staff_ids],
    'Role': [emp_lookup.loc[eid, 'Role'] for eid in assigned_staff_ids],
    'Gender': [emp_lookup.loc[eid, 'Gender'] for eid in assigned_staff_ids],
    'Ethnicity': [emp_lookup.loc[eid, 'Ethnicity'] for eid in assigned_staff_ids],
    'Channel_ID': np.random.choice(df_channels['Channel_ID'], total_tickets, p=[0.21, 0.28, 0.28, 0.15, 0.08]),
    'SLA_Target_Hours': sla_targets,
    'Actual_Resolution_Hours': actual_resolutions,
    'SLA_Status': statuses,
    'Operational_Cost_GBP': op_costs,
    'Penalty_Cost_GBP': penalties,
    'CSAT_Score': csat_scores
})

# -----------------------------------------------------------------------------
# 6. AUDIT & WORKFLOW LOG: Fact_PowerApps_Remediation_Audit (Dataverse Sync)
# -----------------------------------------------------------------------------
breached_tickets = df_tickets[df_tickets['SLA_Status'] == 'SLA Breached']['Ticket_ID'].values
sample_audit_size = min(500, len(breached_tickets))
audit_tickets = np.random.choice(breached_tickets, sample_audit_size, replace=False)

audit_timestamps = [start_2026 + timedelta(days=int(np.random.randint(1, 90)), hours=int(np.random.randint(1, 24))) for _ in range(sample_audit_size)]
audit_dates = [t.date() for t in audit_timestamps]

df_audit = pd.DataFrame({
    'Audit_ID': [f"AUD-{80000 + i}" for i in range(sample_audit_size)],
    'Ticket_ID': audit_tickets,
    'Remediated_By_Employee_ID': np.random.choice(df_employees['Employee_ID'], sample_audit_size),
    'Remediation_Action': np.random.choice(
        ['Shift Reassigned', 'Priority Escalation', 'Third-Party Contractor Dispatched', 'Penalty Waived by Client', 'Automated Flow Workaround'], 
        sample_audit_size
    ),
    'Action_Timestamp': audit_timestamps,
    'Action_Date': audit_dates,
    'PowerAutomate_Triggered': np.random.choice([True, False], sample_audit_size, p=[0.78, 0.22])
})

# -----------------------------------------------------------------------------
# 7. EXPORT ALL TABLES TO CSV (Handles locked files gracefully)
# -----------------------------------------------------------------------------
def safe_to_csv(df, filename):
    try:
        df.to_csv(filename, index=False)
        print(f"Saved: {filename} ({len(df)} rows)")
    except PermissionError:
        alt_name = filename.replace('.csv', '_Updated.csv')
        df.to_csv(alt_name, index=False)
        print(f"Notice: {filename} is open in Excel or another program. Saved to {alt_name} ({len(df)} rows)")

safe_to_csv(df_cost_centers, 'Dim_CostCenters.csv')
safe_to_csv(df_sites, 'Dim_Sites.csv')
safe_to_csv(df_channels, 'Dim_Channels.csv')
safe_to_csv(df_employees, 'Dim_Employees.csv')
safe_to_csv(df_tickets, 'Fact_SLATickets_15k.csv')
safe_to_csv(df_audit, 'Fact_PowerApps_Remediation_Audit.csv')

print("\nSerco Enterprise Data Generation Complete:")
print(f" - Dim_CostCenters: {len(df_cost_centers)} cost centers & sectors")
print(f" - Dim_Sites: {len(df_sites)} operational bases across 7 global regions")
print(f" - Dim_Channels: {len(df_channels)} sourcing channels")
print(f" - Dim_Employees: {len(df_employees)} staff with 100% matched gender-to-name & EDI")
print(f" - Fact_SLATickets_15k: {len(df_tickets)} records linked to CostCenter, Sector, Region, Channel, Staff & Role")
print(f" - Fact_PowerApps_Remediation_Audit: {len(df_audit)} audit remediation records")
