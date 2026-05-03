import streamlit as st


def apply_filters(df):

    filtered = df.copy()

    st.sidebar.header("🔍 Filters")

    # -----------------------------------
    # Line of Business
    # -----------------------------------
    if "LINEOFBUSINESS" in df.columns:
        lob = st.sidebar.multiselect(
            "Line of Business",
            sorted(df["LINEOFBUSINESS"].dropna().unique())
        )
        if lob:
            filtered = filtered[filtered["LINEOFBUSINESS"].isin(lob)]

    # -----------------------------------
    # County
    # -----------------------------------
    if "COUNTY" in df.columns:
        county = st.sidebar.multiselect(
            "County",
            sorted(df["COUNTY"].dropna().unique())
        )
        if county:
            filtered = filtered[filtered["COUNTY"].isin(county)]

    # -----------------------------------
    # Gender
    # -----------------------------------
    if "GENDER" in df.columns:
        gender = st.sidebar.multiselect(
            "Gender",
            sorted(df["GENDER"].dropna().unique())
        )
        if gender:
            filtered = filtered[filtered["GENDER"].isin(gender)]

    # -----------------------------------
    # Age Category
    # -----------------------------------
    if "AGE_CATEGORY" in df.columns:
        age = st.sidebar.multiselect(
            "Age Category",
            sorted(df["AGE_CATEGORY"].dropna().unique())
        )
        if age:
            filtered = filtered[filtered["AGE_CATEGORY"].isin(age)]

    return filtered
