import streamlit as st
import pandas as pd

from core.data_loader import load_data
from core.filters import render_filter_ui, apply_filters_cached
from core.query_router import run_prompt
from core.insights_engine import generate_insights

from core.group_match_loader import load_group_match_data
from core.matching_engine import multi_caliper_matching
from core.matched_data_loader import load_matched_datasets

from visualization.chart_router import build_chart
from utils.constants import PROMPTS


# -----------------------------------
# PAGE CONFIG
# -----------------------------------
st.set_page_config(layout="wide")
st.title("🏥 Matched Cohort Analytics Dashboard")


# -----------------------------------
# STYLE FIX (BLUE SELECTION)
# -----------------------------------
st.markdown("""
<style>
div[data-baseweb="tag"] {
    background-color: #1f77b4 !important;
    color: white !important;
}
div[data-baseweb="tag"] span {
    color: white !important;
    font-weight: 500;
}
</style>
""", unsafe_allow_html=True)


# -----------------------------------
# CACHE MATCHING
# -----------------------------------
@st.cache_data(show_spinner=False)
def get_matched():
    g1, g2 = load_group_match_data()
    return multi_caliper_matching(g1, g2)


# -----------------------------------
# LOAD DATA
# -----------------------------------
df = load_data()
matched = get_matched()


# ===================================
# 🎛 MATCHING QUALITY
# ===================================
st.markdown("## 🎛 Matching Quality")

CALIPER_DESC = {
    "1e-05": "Very Strict (5 decimal precision match)",
    "0.0001": "Strict (4 decimal precision)",
    "0.001": "Moderate (3 decimal precision)",
    "0.02": "Loose match (broader similarity)",
    "no_caliper": "Fallback match (ensures full coverage)"
}

available_calipers = ["ALL"] + sorted(matched["caliper_used"].unique())


# -----------------------------------
# SESSION STATE
# -----------------------------------
if "selected_calipers" not in st.session_state:
    st.session_state.selected_calipers = ["ALL"]


# -----------------------------------
# FORM (MULTI + APPLY)
# -----------------------------------
with st.form("caliper_form"):

    selected = st.multiselect(
        "Select Matching Precision Levels",
        options=available_calipers,
        default=st.session_state.selected_calipers
    )

    apply_btn = st.form_submit_button("Apply")

    if apply_btn:
        st.session_state.selected_calipers = selected


selected_values = st.session_state.selected_calipers


# -----------------------------------
# APPLY FILTER
# -----------------------------------
if "ALL" in selected_values or len(selected_values) == 0:
    filtered_matched = matched
else:
    filtered_matched = matched[
        matched["caliper_used"].isin(selected_values)
    ]


# -----------------------------------
# 📘 PRECISION DESCRIPTION WITH COUNTS
# -----------------------------------
st.markdown("### 📘 Precision Levels Description")

# Calculate counts per caliper
caliper_counts = matched["caliper_used"].value_counts().to_dict()

for key, val in CALIPER_DESC.items():
    count = caliper_counts.get(key, 0)
    st.markdown(f"**{key}** — {val}  _(Matches: {count})_")


# -----------------------------------
# SHOW SELECTED
# -----------------------------------
if "ALL" in selected_values or len(selected_values) == 0:
    st.caption("Showing all calipers combined")
else:
    st.caption(f"Selected: {', '.join(selected_values)}")


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
# KPI DISPLAY
# -----------------------------------
st.markdown("## 📊 Key Metrics Overview")


def render_kpis(title, kpis1, kpis2):

    st.markdown(f"### {title}")
    cols = st.columns(4)

    for i, key in enumerate(kpis1.keys()):

        v1 = kpis1[key]
        v2 = kpis2[key]
        pct = ((v1 - v2) / v2 * 100) if v2 else 0

        if "Cost" in key or key == "PMPM":
            value = f"${v1:,.0f}"
        else:
            value = f"{int(v1):,}"

        cols[i % 4].metric(
            key,
            value,
            f"{pct:+.1f}%"
        )


render_kpis("Group1", k1, k2)
st.markdown("---")
render_kpis("Group2", k2, k1)


# -----------------------------------
# ANALYSIS
# -----------------------------------
st.markdown("## 📈 Analysis")

selected_prompt = st.selectbox("Select Analysis", PROMPTS)


# -----------------------------------
# CHART
# -----------------------------------
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

for col in display_df.columns:
    if display_df[col].dtype in ["int64", "float64"] and col != "MONTH":
        display_df[col] = display_df[col].apply(
            lambda x: f"${x:,.0f}" if pd.notnull(x) else x
        )

st.dataframe(display_df.head(50))
