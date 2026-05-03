import streamlit as st
import pandas as pd

# Core modules
from core.data_loader import load_data
from core.filters import apply_filters
from core.query_router import run_prompt
from core.metrics import get_kpis
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import caliper_matching_sas
from core.matched_data_loader import load_matched_datasets
from core.pre_post_analysis import build_pre_post_dataset
from core.statistical_tests import run_multiple_tests

from visualization.chart_router import build_chart


# -----------------------------------
# PAGE CONFIG
# -----------------------------------
st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")


# -----------------------------------
# LOAD DATA
# -----------------------------------
df = load_data()

g1, g2 = load_group_match_data()
matched = caliper_matching_sas(g1, g2, caliper=0.01)

g1_data, g2_data = load_matched_datasets(df, matched)

combined = pd.concat([g1_data, g2_data])


# -----------------------------------
# FILTERS
# -----------------------------------
filtered = apply_filters(combined)


# -----------------------------------
# KPI SECTION
# -----------------------------------
st.subheader("📊 Key Metrics")

col1, col2 = st.columns(2)

kpi_g1 = get_kpis(filtered[filtered["GROUP"] == "Group1"])
kpi_g2 = get_kpis(filtered[filtered["GROUP"] == "Group2"])

with col1:
    st.markdown("### Group1")
    for k, v in kpi_g1.items():
        st.metric(k, v)

with col2:
    st.markdown("### Group2")
    for k, v in kpi_g2.items():
        st.metric(k, v)


# -----------------------------------
# PROMPTS
# -----------------------------------
st.subheader("📊 Analysis")

prompts = [
    "Monthly Total Cost Trend",
    "Total Cost by Line of Business",
    "Total Cost by County",
    "Total Cost by Age Category",
    "Total Cost by Gender",
    "ED vs IP Utilization Trend",
    "Cost by Product",
    "Cost by Product Type",
    "Product-wise Utilization",
    "County-wise PMPM",
    "Pareto Cost Analysis (Top 5%)"
]

selected_prompt = st.selectbox("Select Analysis", prompts)


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

for i in insights:
    st.write("- " + i)


# -----------------------------------
# PRE vs POST MATCHING
# -----------------------------------
st.subheader("📊 Pre vs Post Matching")

pre_post = build_pre_post_dataset(df, matched)

pre_post_summary = (
    pre_post.groupby("COHORT")["PAID"]
    .mean()
    .reset_index()
)

st.dataframe(pre_post_summary)


# -----------------------------------
# STATISTICAL TESTS
# -----------------------------------
st.subheader("📊 Statistical Significance (t-test)")

test_results = run_multiple_tests(g1_data, g2_data)

for res in test_results:
    st.write(
        f"{res['metric']} → p-value: {res['p_value']:.4f} "
        f"{'✅ Significant' if res['significant'] else '❌ Not Significant'}"
    )


# -----------------------------------
# DATA VIEW
# -----------------------------------
st.subheader("📄 Data Sample")

st.dataframe(result.head(50))
