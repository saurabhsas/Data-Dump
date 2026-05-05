import pandas as pd
import streamlit as st

@st.cache_data
def load_data(path="data/final_monthly.csv"):
    df = pd.read_csv(path)

    # 🔥 CRITICAL FIX
    df.columns = df.columns.str.strip().str.upper()

    # Standardize naming
    if "MEMBERID" in df.columns:
        df.rename(columns={"MEMBERID": "MEMBER_ID"}, inplace=True)

    if "MEMBERUCI" in df.columns:
        df.rename(columns={"MEMBERUCI": "MEMBER_UCI"}, inplace=True)

    df["MEMBER_ID"] = df["MEMBER_ID"].astype(str)

    return df
