# core/filters.py

import streamlit as st
import ast


# -----------------------------------
# FILTER UI (NO CACHE)
# -----------------------------------
def render_filter_ui(df):

    st.sidebar.header("🔍 Filters")

    filters = {}

    if "LINEOFBUSINESS" in df.columns:
        filters["LINEOFBUSINESS"] = st.sidebar.multiselect(
            "Line of Business",
            sorted(df["LINEOFBUSINESS"].dropna().unique())
        )

    if "COUNTY" in df.columns:
        filters["COUNTY"] = st.sidebar.multiselect(
            "County",
            sorted(df["COUNTY"].dropna().unique())
        )

    if "GENDER" in df.columns:
        filters["GENDER"] = st.sidebar.multiselect(
            "Gender",
            sorted(df["GENDER"].dropna().unique())
        )

    if "AGE_CATEGORY" in df.columns:
        filters["AGE_CATEGORY"] = st.sidebar.multiselect(
            "Age Category",
            sorted(df["AGE_CATEGORY"].dropna().unique())
        )

    return filters


# -----------------------------------
# CACHED FILTER APPLICATION
# -----------------------------------
@st.cache_data(show_spinner=False)
def apply_filters_cached(df, filters):

    # 🔥 Handle string case (if passed accidentally)
    if isinstance(filters, str):
        filters = ast.literal_eval(filters)

    filtered = df

    for col, vals in filters.items():
        if vals:
            filtered = filtered[filtered[col].isin(vals)]

    return filtered
