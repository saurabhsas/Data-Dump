# core/query_router.py

import pandas as pd


def prepare_month(df):
    if "ELIGIBILITYYEARANDMONTH" in df.columns:
        df["MONTH"] = df["ELIGIBILITYYEARANDMONTH"].astype(int)
    return df


def run_prompt(prompt, df):

    df = prepare_month(df)

    # -------------------------------
    # Monthly Total Cost Trend
    # -------------------------------
    if prompt == "Monthly Total Cost Trend":
        return (
            df.groupby(["MONTH", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"PAID": "Value"})
            .sort_values("MONTH")
        )

    # -------------------------------
    # Medical vs Pharmacy
    # -------------------------------
    if prompt == "Medical vs Pharmacy Cost Split":
        res = (
            df.groupby(["GROUP"])[["MEDICAL_PAID", "RX_PAID"]]
            .sum()
            .reset_index()
        )
        return res.melt(id_vars="GROUP", var_name="Dimension", value_name="Value")

    # -------------------------------
    if prompt == "Total Cost by Line of Business":
        return (
            df.groupby(["LINEOFBUSINESS", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"LINEOFBUSINESS": "Dimension", "PAID": "Value"})
        )

    if prompt == "Total Cost by County":
        return (
            df.groupby(["COUNTY", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"COUNTY": "Dimension", "PAID": "Value"})
        )

    if prompt == "Total Cost by Age Category":
        return (
            df.groupby(["AGE_CATEGORY", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"AGE_CATEGORY": "Dimension", "PAID": "Value"})
        )

    if prompt == "Total Cost by Gender":
        return (
            df.groupby(["GENDER", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"GENDER": "Dimension", "PAID": "Value"})
        )

    # -------------------------------
    if prompt == "Top 10 High Cost Members":
        return (
            df.groupby(["MEMBER_ID", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .sort_values("PAID", ascending=False)
            .head(10)
            .rename(columns={"MEMBER_ID": "Dimension", "PAID": "Value"})
        )

    # -------------------------------
    if prompt == "ED vs IP Utilization Trend":
        return (
            df.groupby(["MONTH", "GROUP"])[["EDVISITS", "IPVISITS"]]
            .sum()
            .reset_index()
        )

    # -------------------------------
    if prompt == "High Utilization Members":
        return (
            df.groupby(["MEMBER_ID", "GROUP"])["EDVISITS"]
            .sum()
            .reset_index()
            .sort_values("EDVISITS", ascending=False)
            .head(10)
            .rename(columns={"MEMBER_ID": "Dimension", "EDVISITS": "Value"})
        )

    # -------------------------------
    if prompt == "Avoidable Cost Analysis":
        return (
            df.groupby("GROUP")[["AVOIDED", "AVOIDIP"]]
            .sum()
            .reset_index()
        )

    if prompt == "Avoidable Cost by County":
        return (
            df.groupby(["COUNTY", "GROUP"])["AVOIDED"]
            .sum()
            .reset_index()
            .rename(columns={"COUNTY": "Dimension", "AVOIDED": "Value"})
        )

    # -------------------------------
    if prompt == "Cost by Product":
        return (
            df.groupby(["FSPRODUCT", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"FSPRODUCT": "Dimension", "PAID": "Value"})
        )

    if prompt == "Cost by Product Type":
        return (
            df.groupby(["PRODUCTTYPEDESCR", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"PRODUCTTYPEDESCR": "Dimension", "PAID": "Value"})
        )

    if prompt == "Product-wise Utilization":
        return (
            df.groupby(["FSPRODUCT", "GROUP"])["EDVISITS"]
            .sum()
            .reset_index()
            .rename(columns={"FSPRODUCT": "Dimension", "EDVISITS": "Value"})
        )

    # -------------------------------
    if prompt == "County-wise PMPM":
        res = df.groupby(["COUNTY", "GROUP"]).agg(
            {"PAID": "sum", "MEMBER_ID": "nunique"}
        ).reset_index()

        res["Value"] = res["PAID"] / res["MEMBER_ID"]

        return res.rename(columns={"COUNTY": "Dimension"})

    # -------------------------------
    if prompt == "Pareto Cost Analysis (Top 5%)":
        agg = (
            df.groupby(["MEMBER_ID", "GROUP"])["PAID"]
            .sum()
            .reset_index()
            .sort_values("PAID", ascending=False)
        )

        cutoff = max(1, int(len(agg) * 0.05))
        return agg.head(cutoff).rename(columns={"MEMBER_ID": "Dimension", "PAID": "Value"})

    return df
