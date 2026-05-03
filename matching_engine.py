import streamlit as st
import pandas as pd

from core.data_loader import load_data
from core.filters import apply_filters
from core.query_router import run_prompt
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import caliper_matching_sas
from core.matched_data_loader import load_matched_datasets

from visualization.chart_router import build_chart


# -----------------------------------
# CONFIG
# -----------------------------------
st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")


# -----------------------------------
# LOAD + CACHE MATCHING
# -----------------------------------
@st.cache_data(show_spinner=False)
def get_matched():
    g1, g2 = load_group_match_data()
    return caliper_matching_sas(g1, g2, caliper=0.01)


df = load_data()
matched = get_matched()

g1, g2 = load_group_match_data()
g1_data, g2_data = load_matched_datasets(df, matched)

combined = pd.concat([g1_data, g2_data])


# -----------------------------------
# FILTERS
# -----------------------------------
filtered = apply_filters(combined)


# -----------------------------------
# KPI CALCULATION
# -----------------------------------
def compute_kpis(df):

    members = df["MEMBERID"].nunique()
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


k1 = compute_kpis(filtered[filtered["GROUP"] == "Group1"])
k2 = compute_kpis(filtered[filtered["GROUP"] == "Group2"])


# -----------------------------------
# KPI UI (LARGER + CLEAN)
# -----------------------------------
def format_val(k, v):
    if "Cost" in k or k == "PMPM":
        return f"${v:,.0f}"
    return f"{int(v):,}"


def render_kpis(title, kpis1, kpis2):

    st.markdown(f"### {title}")

    cols = st.columns(4)

    for i, key in enumerate(kpis1.keys()):

        v1 = kpis1[key]
        v2 = kpis2[key]

        pct = ((v1 - v2) / v2 * 100) if v2 != 0 else 0

        cols[i % 4].markdown(
            f"""
            <div style="
                background:#f0f4f8;
                padding:14px;
                border-radius:12px;
                text-align:center;
            ">
                <div style="font-size:13px; font-weight:600;">{key}</div>
                <div style="font-size:22px; font-weight:bold;">
                    {format_val(key, v1)}
                </div>
                <div style="font-size:12px; color:#555;">
                    {pct:+.1f}% vs G2
                </div>
            </div>
            """,
            unsafe_allow_html=True
        )


st.subheader("📊 Key Metrics")

col1, col2 = st.columns(2)

with col1:
    render_kpis("Group1", k1, k2)

with col2:
    render_kpis("Group2", k2, k1)


# -----------------------------------
# PROMPTS
# -----------------------------------
prompts = [
    "Monthly Total Cost Trend",
    "Total Cost by Line of Business",
    "Total Cost by County",
    "Total Cost by Age Category",
    "Total Cost by Gender",
    "ED vs IP Utilization Trend",
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

for ins in insights:
    st.write("•", ins)


# -----------------------------------
# DATA VIEW
# -----------------------------------
st.subheader("📄 Data Sample")
st.dataframe(result.head(50))
