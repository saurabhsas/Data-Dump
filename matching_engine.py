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

        # EXPORT MATCHED FILE
        os.makedirs("data", exist_ok=True)
        matched[["G1_MEMBER_ID", "G2_MEMBER_ID"]].to_csv(
            "data/matched_members.csv",
            index=False
        )

        return matched

    df = load_data()
    matched = get_matched()

    # -----------------------------------
    # MATCHING QUALITY
    # -----------------------------------
    st.markdown("## 🎛 Matching Quality")

    caliper_counts = matched["caliper_used"].value_counts().to_dict()

    CALIPER_DESC = {
        "1e-05": f"Very Strict (5 decimal precision) — {caliper_counts.get('1e-05',0)}",
        "0.0001": f"Strict (4 decimal precision) — {caliper_counts.get('0.0001',0)}",
        "0.001": f"Moderate (3 decimal precision) — {caliper_counts.get('0.001',0)}",
        "0.02": f"Loose match — {caliper_counts.get('0.02',0)}",
        "no_caliper": f"Fallback — {caliper_counts.get('no_caliper',0)}"
    }

    available_calipers = ["ALL"] + sorted(matched["caliper_used"].unique())

    selected = st.multiselect(
        "Select Matching Precision Levels",
        options=available_calipers,
        default=["ALL"],
        format_func=lambda x: "ALL" if x == "ALL" else f"{x} → {CALIPER_DESC.get(x,'')}"
    )

    if "ALL" in selected:
        filtered_matched = matched
    else:
        filtered_matched = matched[
            matched["caliper_used"].isin(selected)
        ]

    # -----------------------------------
    # MATCH SUMMARY
    # -----------------------------------
    colA, colB, colC = st.columns(3)

    colA.metric("Total Matches", len(filtered_matched))
    colB.metric("Group1 Members", filtered_matched["G1_MEMBER_ID"].nunique())
    colC.metric("Group2 Members", filtered_matched["G2_MEMBER_ID"].nunique())

    # -----------------------------------
    # LOAD MATCHED DATA
    # -----------------------------------
    g1_data, g2_data, _ = load_matched_datasets(df, filtered_matched)
    combined = pd.concat([g1_data, g2_data])

    filters = render_filter_ui(combined)
    filtered = apply_filters_cached(combined, filters)

    # -----------------------------------
    # KPI FIX
    # -----------------------------------
    def compute_kpis(df, matched_df, group):

        if group == "Group1":
            members = matched_df["G1_MEMBER_ID"].nunique()
        else:
            members = matched_df["G2_MEMBER_ID"].nunique()

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

    k1 = compute_kpis(
        filtered[filtered["GROUP"] == "Group1"],
        filtered_matched,
        "Group1"
    )

    k2 = compute_kpis(
        filtered[filtered["GROUP"] == "Group2"],
        filtered_matched,
        "Group2"
    )

    # -----------------------------------
    # KPI DISPLAY
    # -----------------------------------
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

    # -----------------------------------
    # ANALYSIS
    # -----------------------------------
    st.markdown("## 📈 Analysis")

    selected_prompt = st.selectbox("Select Analysis", PROMPTS)

    result = run_prompt(selected_prompt, filtered)

    fig = build_chart(result, selected_prompt)
    st.plotly_chart(fig, use_container_width=True)

    # -----------------------------------
    # INSIGHTS
    # -----------------------------------
    st.markdown("## 🧠 Insights")

    for ins in generate_insights(selected_prompt, result):
        st.write("•", ins)

    # -----------------------------------
    # DATA TABLE
    # -----------------------------------
    st.markdown("## 📄 Data Sample")

    display_df = result.copy()

    if "MEMBER_ID" in display_df.columns:
        display_df = display_df.drop(columns=["MEMBER_ID"])

    for col in display_df.columns:
        if display_df[col].dtype in ["int64", "float64"] and col != "MONTH":
            display_df[col] = display_df[col].apply(
                lambda x: f"${x:,.0f}" if pd.notnull(x) else x
            )

    st.dataframe(display_df.head(50))


# ============================================================
# 📈 PAGE 2 (NO TOTALS)
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

    segments = {
        "🏥 Inpatient (FIP)": "FIP",
        "🏥 Outpatient (FOP)": "FOP",
        "👨‍⚕️ Professional (PROF)": "PROF",
        "📦 Others (OTH)": "OTH",
        "➕ Additional (ADDL)": "ADDL"
    }

    for title, code in segments.items():
        st.markdown(f"## {title}")

        seg_df = pivot[pivot["MR_LINE_DESC1_FINAL"] == code]

        if not seg_df.empty:
            st.dataframe(seg_df, use_container_width=True)
        else:
            st.info(f"No data available for {title}")
