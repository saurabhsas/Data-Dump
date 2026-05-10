import streamlit as st
import pandas as pd
import plotly.express as px
import os

from core.data_loader import load_data
from core.filters import render_filter_ui, apply_filters_cached
from core.query_router import run_prompt
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import multi_caliper_matching
from core.matched_data_loader import load_matched_datasets

from core.summary_loader import load_summary_data

from visualization.chart_router import build_chart
from utils.constants import PROMPTS


# -----------------------------------
# PAGE CONFIG
# -----------------------------------
st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")


# -----------------------------------
# KPI FONT SIZE
# -----------------------------------
st.markdown("""
<style>
div[data-testid="stMetricValue"] {
    font-size: 18px !important;
    font-weight: 600;
}
</style>
""", unsafe_allow_html=True)


# -----------------------------------
# NAVIGATION
# -----------------------------------
page = st.sidebar.radio(
    "Navigation",
    ["📊 Matched Cohort Dashboard", "📈 Utilization & Cost Comparison"]
)


# ============================================================
# 📊 PAGE 1
# ============================================================
if page == "📊 Matched Cohort Dashboard":

    @st.cache_data(show_spinner=False)
    def get_matched():
        g1, g2 = load_group_match_data()
        matched = multi_caliper_matching(g1, g2)

        os.makedirs("data", exist_ok=True)
        matched[["G1_MEMBER_ID", "G2_MEMBER_ID"]].to_csv(
            "data/matched_members.csv",
            index=False
        )

        return matched

    df = load_data()
    matched = get_matched()

    # -----------------------------------
    # MATCH SUMMARY
    # -----------------------------------
    colA, colB, colC = st.columns(3)

    colA.metric("Total Matches", len(matched))
    colB.metric("Group1 Members", matched["G1_MEMBER_ID"].nunique())
    colC.metric("Group2 Members", matched["G2_MEMBER_ID"].nunique())

    # -----------------------------------
    # KPI FIX
    # -----------------------------------
    g1_data, g2_data, _ = load_matched_datasets(df, matched)

    def compute_kpis(df, matched_df, group):

        members = matched_df["G1_MEMBER_ID"].nunique() if group == "Group1" else matched_df["G2_MEMBER_ID"].nunique()
        total = df["PAID"].sum()

        return {
            "Members": members,
            "Total Cost": total,
            "Medical Cost": df["MEDICAL_PAID"].sum(),
            "Pharmacy Cost": df["RX_PAID"].sum(),
            "ED Visits": df["EDVISITS"].sum(),
            "IP Visits": df["IPVISITS"].sum(),
            "PMPM": total / members if members else 0
        }

    k1 = compute_kpis(g1_data, matched, "Group1")
    k2 = compute_kpis(g2_data, matched, "Group2")

    st.markdown("## 📊 Key Metrics Overview")

    col1, col2 = st.columns(2)

    def render_kpis(title, kpi):
        st.markdown(f"### {title}")
        cols = st.columns(4)

        for i, (key, val) in enumerate(kpi.items()):
            if "Cost" in key or key == "PMPM":
                value = f"${val:,.0f}"
            else:
                value = f"{int(val):,}"

            cols[i % 4].metric(key, value)

    with col1:
        render_kpis("Group1", k1)

    with col2:
        render_kpis("Group2", k2)


# ============================================================
# 📈 PAGE 2 (COMPARISON VIEW RESTORED)
# ============================================================
elif page == "📈 Utilization & Cost Comparison":

    st.header("📈 Utilization & Cost Comparison")

    df = load_summary_data()

    summary = (
        df.groupby(["MR_LINE_DESC1_FINAL", "SVC_CAT2", "GROUP"])
        .agg({
            "Total_Paid_Amount": "sum",
            "Total_Claim_Count": "sum"
        })
        .reset_index()
    )

    pivot = summary.pivot(
        index=["MR_LINE_DESC1_FINAL", "SVC_CAT2"],
        columns="GROUP",
        values=["Total_Paid_Amount", "Total_Claim_Count"]
    ).fillna(0)

    pivot.columns = [f"{m}_{g}" for m, g in pivot.columns]
    pivot = pivot.reset_index()

    # -----------------------------------
    # DELTAS
    # -----------------------------------
    def pct_diff(a, b):
        return ((a - b) / b * 100) if b != 0 else 0

    pivot["Cost Δ%"] = pivot.apply(
        lambda x: pct_diff(
            x.get("Total_Paid_Amount_Group1", 0),
            x.get("Total_Paid_Amount_Group2", 0)
        ),
        axis=1
    )

    pivot["Utilization Δ%"] = pivot.apply(
        lambda x: pct_diff(
            x.get("Total_Claim_Count_Group1", 0),
            x.get("Total_Claim_Count_Group2", 0)
        ),
        axis=1
    )

    # -----------------------------------
    # FORMAT + RENAME
    # -----------------------------------
    pivot = pivot.rename(columns={
        "Total_Paid_Amount_Group1": "G1 Paid",
        "Total_Paid_Amount_Group2": "G2 Paid",
        "Total_Claim_Count_Group1": "G1 Claim Count",
        "Total_Claim_Count_Group2": "G2 Claim Count"
    })

    for col in ["G1 Paid", "G2 Paid"]:
        pivot[col] = pivot[col].apply(lambda x: f"${x:,.0f}")

    for col in ["G1 Claim Count", "G2 Claim Count"]:
        pivot[col] = pivot[col].apply(lambda x: f"{int(x):,}")

    pivot["Cost Δ%"] = pivot["Cost Δ%"].apply(lambda x: f"{x:+.1f}%")
    pivot["Utilization Δ%"] = pivot["Utilization Δ%"].apply(lambda x: f"{x:+.1f}%")

    pivot = pivot[[
        "MR_LINE_DESC1_FINAL",
        "SVC_CAT2",
        "G1 Paid",
        "G2 Paid",
        "G1 Claim Count",
        "G2 Claim Count",
        "Cost Δ%",
        "Utilization Δ%"
    ]]

    pivot.columns = [
        "Category",
        "Subcategory",
        "G1 Paid",
        "G2 Paid",
        "G1 Claims",
        "G2 Claims",
        "Cost Δ%",
        "Utilization Δ%"
    ]

    # -----------------------------------
    # SEGMENTS
    # -----------------------------------
    segments = {
        "🏥 Inpatient (FIP)": "FIP",
        "🏥 Outpatient (FOP)": "FOP",
        "👨‍⚕️ Professional (PROF)": "PROF",
        "📦 Others (OTH)": "OTH",
        "➕ Additional (ADDL)": "ADDL"
    }

    for title, code in segments.items():
        st.markdown(f"## {title}")

        seg_df = pivot[pivot["Category"] == code]

        if not seg_df.empty:
            st.dataframe(seg_df, use_container_width=True)
        else:
            st.info(f"No data available for {title}")
