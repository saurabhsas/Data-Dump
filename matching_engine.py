import pandas as pd
import streamlit as st


def prepare_month(df):
    if "ELIGIBILITYYEARANDMONTH" in df.columns:
        df["MONTH"] = df["ELIGIBILITYYEARANDMONTH"].astype(int)
    return df


@st.cache_data(show_spinner=False)
def run_prompt(prompt, df):

    df = prepare_month(df)

    if prompt == "Monthly Total Cost Trend":
        return (
            df.groupby(["MONTH", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"PAID": "Value"})
        )

    if prompt == "Total Cost by Line of Business":
        return (
            df.groupby(["LINEOFBUSINESS", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={
                "LINEOFBUSINESS": "Dimension",
                "PAID": "Value"
            })
        )

    return df
