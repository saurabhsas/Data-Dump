import streamlit as st
import pandas as pd

# Core modules
from core.data_loader import load_data
from core.filters import apply_filters
from core.query_router import run_prompt
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import caliper_matching_sas
from core.matched_data_loader import load_matched_datasets

from visualization.chart_router import build_chart


# -----------------------------------
# PAGE CONFIG + STYLE
# -----------------------------------
st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")

st.markdown("""
<style>
body { background-color: #f7f9fc; }
.kpi-card:hover {
    transform: translateY(-3px);
    box-shadow: 0px 6px 18px rgba(0,0,0,0.12);
}
</style>
""", unsafe_allow_html=True)


# -----------------------------------
# CACHE MATCHING (IMPORTANT)
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

g1, g2 = load_group_match_data()
g1_data, g2_data = load_matched_datasets(df, matched)

combined = pd.concat([g1_data, g2_data])


# -----------------------------------
# FILTERS
# -----------------------------------
filtered = apply_filters(combined)


# -----------------------------------
# KPI CALCULATION (IMPORTANT: NUMERIC ONLY)
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


# -----------------------------------
# FORMAT VALUES (DISPLAY ONLY)
# -----------------------------------
def format_val(k, v):
    if "Cost" in k or k == "PMPM":
        return f"${v:,.0f}"
    return f"{int(v):,}"


# -----------------------------------
# KPI CARD RENDER
# -----------------------------------
def render_kpis(title, kpis1, kpis2):

    st.markdown(f"### {title}")

    cols = st.columns(4)

    for i, key in enumerate(kpis1.keys()):

        v1 = float(kpis1[key])
        v2 = float(kpis2[key])

        # Safe % diff
        pct = ((v1 - v2) / v2 * 100) if v2 != 0 else 0

        # Color logic
        if "Cost" in key or key == "PMPM":
            color = "#e74c3c" if pct > 0 else "#2ecc71"
        else:
            color = "#2ecc71" if pct > 0 else "#e74c3c"

        icon = ICON_MAP.get(key, "📊")

        cols[i % 4].markdown(
            f"""
            <div class="kpi-card" style="
                background: white;
                padding: 16px;
                border-radius: 14px;
                box-shadow: 0px 2px 10px rgba(0,0,0,0.08);
                text-align: center;
            ">
                <div style="font-size:26px;">{icon}</div>

                <div style="
                    font-size:14px;
                    font-weight:600;
                    color:#555;
                    margin-top:6px;
                ">
                    {key}
                </div>

                <div style="
                    font-size:26px;
                    font-weight:bold;
                    margin-top:6px;
                    color:#2c3e50;
                ">
                    {format_val(key, v1)}
                </div>

                <div style="
                    font-size:13px;
                    margin-top:6px;
                    color:{color};
                    font-weight:600;
                ">
                    {pct:+.1f}% vs G2
                </div>
            </div>
            """,
            unsafe_allow_html=True
        )


# -----------------------------------
# KPI DISPLAY
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
st.markdown("## 📈 Analysis")

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
st.markdown("## 🧠 Insights")

insights = generate_insights(selected_prompt, result)

for ins in insights:
    st.write("•", ins)


# -----------------------------------
# DATA VIEW
# -----------------------------------
st.markdown("## 📄 Data Sample")
st.dataframe(result.head(50))
