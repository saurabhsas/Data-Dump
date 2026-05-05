import streamlit as st
import pandas as pd

from core.data_loader import load_data
from core.filters import render_filter_ui, apply_filters_cached
from core.query_router import run_prompt
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import caliper_matching_sas
from core.matched_data_loader import load_matched_datasets

from visualization.chart_router import build_chart


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
    font-size: 30px !important;
    font-weight: 700;
}
</style>
""", unsafe_allow_html=True)


# -----------------------------------
# CACHE MATCHING
# -----------------------------------
@st.cache_data(show_spinner=False)
def get_matched():
    g1, g2 = load_group_match_data()
    return caliper_matching_sas(g1, g2, caliper=0.01)


# -----------------------------------
# LOAD DATA
# -----------------------------------
df = load_data()

matched = get_matched()

g1_data, g2_data, matched = load_matched_datasets(df, matched)

combined = pd.concat([g1_data, g2_data])


# -----------------------------------
# FILTERS (FAST + FIXED)
# -----------------------------------
filters = render_filter_ui(combined)

filtered = apply_filters_cached(combined, filters)


# -----------------------------------
# KPI CALCULATION
# -----------------------------------
def compute_kpis(df):

    members = df["MEMBER_ID"].nunique()
    total = df["PAID"].sum()

    return members, total


g1_members, g1_cost = compute_kpis(filtered[filtered["GROUP"] == "Group1"])
g2_members, g2_cost = compute_kpis(filtered[filtered["GROUP"] == "Group2"])


# -----------------------------------
# KPI DISPLAY
# -----------------------------------
col1, col2 = st.columns(2)

col1.metric("👥 Group1 Members", g1_members)
col2.metric("👥 Group2 Members", g2_members)


# -----------------------------------
# PROMPTS
# -----------------------------------
PROMPTS = [
    "Monthly Total Cost Trend",
    "Medical vs Pharmacy Cost Split",
    "Total Cost by Line of Business",
    "Total Cost by County",
    "Total Cost by Age Category",
    "Total Cost by Gender",
    "Top 10 High Cost Members",
    "ED vs IP Utilization Trend",
    "High Utilization Members",
    "Avoidable Cost Analysis",
    "Avoidable Cost by County",
    "Cost by Product",
    "Cost by Product Type",
    "Product-wise Utilization",
    "County-wise PMPM",
    "Pareto Cost Analysis (Top 5%)"
]

selected_prompt = st.selectbox("Select Analysis", PROMPTS)


# -----------------------------------
# QUERY + CHART
# -----------------------------------
result = run_prompt(selected_prompt, filtered)

fig = build_chart(result, selected_prompt)
st.plotly_chart(fig, use_container_width=True)


# -----------------------------------
# INSIGHTS
# -----------------------------------
st.subheader("🧠 Insights")

insights = generate_insights(selected_prompt, result)

for ins in insights:
    st.write("•", ins)


# -----------------------------------
# DATA SAMPLE
# -----------------------------------
st.subheader("📄 Data Sample")
st.dataframe(result.head(50))
