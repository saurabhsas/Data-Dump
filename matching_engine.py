import pandas as pd
import streamlit as st


@st.cache_data(show_spinner=False)
def load_data(path="data/final_monthly.csv"):

    df = pd.read_csv(path)

    # Standardize column names
    df.columns = df.columns.str.strip().str.upper()

    # Normalize naming
    if "MEMBERID" in df.columns:
        df.rename(columns={"MEMBERID": "MEMBER_ID"}, inplace=True)

    if "MEMBERUCI" in df.columns:
        df.rename(columns={"MEMBERUCI": "MEMBER_UCI"}, inplace=True)

    # Data types
    df["MEMBER_ID"] = df["MEMBER_ID"].astype(str)

    # Optimize memory
    for col in ["COUNTY", "LINEOFBUSINESS", "GENDER", "AGE_CATEGORY"]:
        if col in df.columns:
            df[col] = df[col].astype("category")

    return df
