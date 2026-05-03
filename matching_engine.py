import streamlit as st


def apply_filters(df):

    filtered = df

    st.sidebar.header("🔍 Filters")

    def multi_filter(col, label):
        nonlocal filtered

        if col not in df.columns:
            return

        options = sorted(df[col].dropna().unique())

        selected = st.sidebar.multiselect(
            label,
            options,
            default=[]
        )

        if selected:
            filtered = filtered[filtered[col].isin(selected)]

    multi_filter("LINEOFBUSINESS", "Line of Business")
    multi_filter("COUNTY", "County")
    multi_filter("GENDER", "Gender")
    multi_filter("AGE_CATEGORY", "Age Category")

    return filtered
