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
# KPI STYLE (SAFE)
# -----------------------------------
st.markdown("""
<style>
div[data-testid="stMetric"] {
    background-color: #ffffff;
    padding: 12px;
    border-radius: 12px;
    box-shadow: 0px 2px 8px rgba(0,0,0,0.05);
}

div[data-testid="stMetricValue"] {
    font-size: 30px !important;
    font-weight: 700;
}

div[data-testid="stMetricLabel"] {
    font-size: 14px;
    font-weight: 600;
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
# FILTERS
# -----------------------------------
filters = render_filter_ui(combined)
filtered = apply_filters_cached(combined, filters)


# -----------------------------------
# KPI CALCULATION
# -----------------------------------
def compute_kpis(df):

    members = df["MEMBER_ID"].nunique()
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
# KPI ICONS
# -----------------------------------
ICON_MAP = {
    "Members": "👥",
    "Total Cost": "💰",
    "Medical Cost": "🏥",
    "Pharmacy Cost": "💊",
    "ED Visits": "🚑",
    "IP Visits": "🛏️",
    "PMPM": "📊"
}


def format_val(k, v):
    if "Cost" in k or k == "PMPM":
        return f"${v:,.0f}"
    return f"{int(v):,}"


# -----------------------------------
# KPI RENDER (UPDATED)
# -----------------------------------
def render_kpis(title, kpis1, kpis2):

    st.markdown(f"### {title}")

    cols = st.columns(4)

    for i, key in enumerate(kpis1.keys()):

        v1 = float(kpis1[key])
        v2 = float(kpis2[key])

        pct = ((v1 - v2) / v2 * 100) if v2 != 0 else 0

        # 🔥 Arrow logic
        if pct > 0:
            arrow = "↑"
        elif pct < 0:
            arrow = "↓"
        else:
            arrow = "→"

        delta = f"{arrow} {abs(pct):.1f}%"

        cols[i % 4].metric(
            label=f"{ICON_MAP.get(key, '📊')} {key}",
            value=format_val(key, v1),
            delta=delta
        )


# -----------------------------------
# KPI SECTION
# -----------------------------------
st.markdown("## 📊 Key Metrics Overview")

col1, col2 = st.columns(2)

with col1:
    render_kpis("Group1", k1, k2)

with col2:
    render_kpis("Group2", k2, k1)


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
st.markdown("## 🧠 Insights")

insights = generate_insights(selected_prompt, result)

for ins in insights:
    st.write("•", ins)


# -----------------------------------
# DATA SAMPLE
# -----------------------------------
st.markdown("## 📄 Data Sample")
st.dataframe(result.head(50))
