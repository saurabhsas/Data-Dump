# core/metrics.py

def get_kpis(df):

    members = df["MEMBERID"].nunique()
    total_cost = df["PAID"].sum()

    return {
        "Members": members,

        # Costs
        "Total Cost": total_cost,
        "Medical Cost": df["MEDICAL_PAID"].sum(),
        "Pharmacy Cost": df["RX_PAID"].sum(),
        "MR Allowed": df["MR_ALLOWED"].sum(),

        # Avoidable
        "Avoidable ED": df["AVOIDED"].sum(),
        "Avoidable IP": df["AVOIDIP"].sum(),

        # Utilization
        "ED Visits": df["EDVISITS"].sum(),
        "IP Visits": df["IPVISITS"].sum(),

        # Cost buckets
        "Professional": df["PROF"].sum(),
        "Outpatient": df["FOP"].sum(),
        "Inpatient": df["FIP"].sum(),
        "Others": df["OTH"].sum(),

        # Derived
        "PMPM": total_cost / members if members else 0
    }
