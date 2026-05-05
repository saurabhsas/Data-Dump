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
# 🎨 PREMIUM KPI STYLE
# -----------------------------------
st.markdown("""
<style>
.kpi-card {
    padding: 18px;
    border-radius: 16px;
    height: 140px;
    box-shadow: 0px 4px 12px rgba(0,0,0,0.08);
    display: flex;
    flex-direction: column;
    justify-content: center;
    text-align: center;
    transition: 0.2s ease;
}

.kpi-card:hover {
    transform: translateY(-3px);
    box-shadow: 0px 6px 18px rgba(0,0,0,0.12);
}

.kpi-title {
    font-size: 14px;
    color: #555;
    font-weight: 600;
}

.kpi-value {
    font-size: 26px;
    font-weight: 700;
    margin-top: 6px;
}

.kpi-delta {
    font-size: 13px;
    margin-top: 6px;
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
# ICON MAP
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
# KPI RENDER (PREMIUM)
# -----------------------------------
def render_kpis(title, kpis1, kpis2):

    st.markdown(f"### {title}")
    cols = st.columns(4)

    for i, key in enumerate(kpis1.keys()):

        v1 = float(kpis1[key])
        v2 = float(kpis2[key])

        pct = ((v1 - v2) / v2 * 100) if v2 != 0 else 0

        # 🎯 Color logic
        if "Cost" in key or key == "PMPM":
            bg_color = "#fdecea" if pct > 0 else "#eafaf1"
            text_color = "#e74c3c" if pct > 0 else "#2ecc71"
        else:
            bg_color = "#eafaf1" if pct > 0 else "#fdecea"
            text_color = "#2ecc71" if pct > 0 else "#e74c3c"

        arrow = "↑" if pct > 0 else "↓"

        html = f"""
        <div class="kpi-card" style="background:{bg_color};">

            <div class="kpi-title">
                {ICON_MAP.get(key, '📊')} {key}
            </div>

            <div class="kpi-value">
                {format_val(key, v1)}
            </div>

            <div class="kpi-delta" style="color:{text_color};">
                {arrow} {abs(pct):.1f}% vs other
            </div>

        </div>
        """

        cols[i % 4].markdown(html, unsafe_allow_html=True)


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
