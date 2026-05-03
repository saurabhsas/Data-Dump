import pandas as pd
import streamlit as st


@st.cache_data(show_spinner=False)
def load_data(path="data/final_monthly.csv"):
    df = pd.read_csv(path)

    # Standardize
    df.columns = df.columns.str.upper()

    # Important type fixes
    if "MEMBERID" in df.columns:
        df["MEMBERID"] = df["MEMBERID"].astype(str)

    if "ELIGIBILITYYEARANDMONTH" in df.columns:
        df["ELIGIBILITYYEARANDMONTH"] = df["ELIGIBILITYYEARANDMONTH"].astype(int)

    return df
