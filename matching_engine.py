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


st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")

# KPI Font
st.markdown("""
<style>
div[data-testid="stMetricValue"] {
    font-size: 30px !important;
}
</style>
""", unsafe_allow_html=True)


@st.cache_data
def get_matched():
    g1, g2 = load_group_match_data()
    return caliper_matching_sas(g1, g2, caliper=0.01)


df = load_data()

matched = get_matched()

g1_data, g2_data, matched = load_matched_datasets(df, matched)

combined = pd.concat([g1_data, g2_data])


# Filters
filters = render_filter_ui(combined)
filtered = apply_filters_cached(combined, str(filters))


# KPI
def compute(df):
    return df["MEMBER_ID"].nunique(), df["PAID"].sum()


g1_m, g1_c = compute(filtered[filtered["GROUP"] == "Group1"])
g2_m, g2_c = compute(filtered[filtered["GROUP"] == "Group2"])

c1, c2 = st.columns(2)
c1.metric("👥 Group1 Members", g1_m)
c2.metric("👥 Group2 Members", g2_m)


# Prompts
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

prompt = st.selectbox("Select Analysis", PROMPTS)

result = run_prompt(prompt, filtered)

fig = build_chart(result, prompt)
st.plotly_chart(fig, use_container_width=True)


# Insights
st.subheader("Insights")
for i in generate_insights(prompt, result):
    st.write("•", i)
