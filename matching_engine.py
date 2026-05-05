import streamlit as st


def render_filter_ui(df):

    st.sidebar.header("🔍 Filters")

    selected = {}

    if "LINEOFBUSINESS" in df:
        selected["LINEOFBUSINESS"] = st.sidebar.multiselect(
            "LOB", df["LINEOFBUSINESS"].unique()
        )

    if "COUNTY" in df:
        selected["COUNTY"] = st.sidebar.multiselect(
            "County", df["COUNTY"].unique()
        )

    if "GENDER" in df:
        selected["GENDER"] = st.sidebar.multiselect(
            "Gender", df["GENDER"].unique()
        )

    if "AGE_CATEGORY" in df:
        selected["AGE_CATEGORY"] = st.sidebar.multiselect(
            "Age Category", df["AGE_CATEGORY"].unique()
        )

    return selected


@st.cache_data(show_spinner=False)
def apply_filters_cached(df, filters):

    filtered = df

    for col, vals in filters.items():
        if vals:
            filtered = filtered[filtered[col].isin(vals)]

    return filtered
