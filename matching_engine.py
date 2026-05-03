# core/query_router.py

import pandas as pd


# ---------------------------------------
# Helper: Month preparation
# ---------------------------------------
def prepare_month(df):
    if "ELIGIBILITYYEARANDMONTH" in df.columns:
        df["MONTH"] = df["ELIGIBILITYYEARANDMONTH"].astype(int)
    return df


# ---------------------------------------
# Main router
# ---------------------------------------
def run_prompt(prompt, df):

    df = prepare_month(df)

    # ---------------------------------------
    # GROUP MODE
    # ---------------------------------------
    if "GROUP" in df.columns:

        # -----------------------------------
        # Monthly Total Cost Trend
        # -----------------------------------
        if prompt == "Monthly Total Cost Trend":
            return (
                df.groupby(["MONTH", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={"PAID": "Value"})
                .sort_values("MONTH")
            )

        # -----------------------------------
        # Cost by Line of Business
        # -----------------------------------
        if prompt == "Total Cost by Line of Business":
            return (
                df.groupby(["LINEOFBUSINESS", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "LINEOFBUSINESS": "Dimension",
                    "PAID": "Value"
                })
                .sort_values("Value", ascending=False)
            )

        # -----------------------------------
        # Cost by County
        # -----------------------------------
        if prompt == "Total Cost by County":
            return (
                df.groupby(["COUNTY", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "COUNTY": "Dimension",
                    "PAID": "Value"
                })
            )

        # -----------------------------------
        # Cost by Age
        # -----------------------------------
        if prompt == "Total Cost by Age Category":
            return (
                df.groupby(["AGE_CATEGORY", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "AGE_CATEGORY": "Dimension",
                    "PAID": "Value"
                })
            )

        # -----------------------------------
        # Cost by Gender
        # -----------------------------------
        if prompt == "Total Cost by Gender":
            return (
                df.groupby(["GENDER", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "GENDER": "Dimension",
                    "PAID": "Value"
                })
            )

        # -----------------------------------
        # ED vs IP Utilization Trend
        # -----------------------------------
        if prompt == "ED vs IP Utilization Trend":
            return (
                df.groupby(["MONTH", "GROUP"])[["EDVISITS", "IPVISITS"]]
                .sum()
                .reset_index()
                .sort_values("MONTH")
            )

        # -----------------------------------
        # Cost by Product
        # -----------------------------------
        if prompt == "Cost by Product":
            return (
                df.groupby(["FSPRODUCT", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "FSPRODUCT": "Dimension",
                    "PAID": "Value"
                })
            )

        # -----------------------------------
        # Cost by Product Type
        # -----------------------------------
        if prompt == "Cost by Product Type":
            return (
                df.groupby(["PRODUCTTYPEDESCR", "GROUP"])["PAID"]
                .sum()
                .reset_index()
                .rename(columns={
                    "PRODUCTTYPEDESCR": "Dimension",
                    "PAID": "Value"
                })
            )

        # -----------------------------------
        # Product-wise Utilization
        # -----------------------------------
        if prompt == "Product-wise Utilization":
            return (
                df.groupby(["FSPRODUCT", "GROUP"])["EDVISITS"]
                .sum()
                .reset_index()
                .rename(columns={
                    "FSPRODUCT": "Dimension",
                    "EDVISITS": "Value"
                })
            )

        # -----------------------------------
        # County-wise PMPM
        # -----------------------------------
        if prompt == "County-wise PMPM":
            res = (
                df.groupby(["COUNTY", "GROUP"])
                .agg({
                    "PAID": "sum",
                    "MEMBERID": "nunique"
                })
                .reset_index()
            )
            res["Value"] = res["PAID"] / res["MEMBERID"]
            return res.rename(columns={"COUNTY": "Dimension"})

        # -----------------------------------
        # Pareto Top 5%
        # -----------------------------------
        if prompt == "Pareto Cost Analysis (Top 5%)":

            agg = (
                df.groupby(["MEMBERID", "GROUP"])["PAID"]
                .sum()
                .reset_index()
            )

            agg = agg.sort_values("PAID", ascending=False)

            cutoff = max(1, int(len(agg) * 0.05))

            return agg.head(cutoff).rename(columns={
                "MEMBERID": "Dimension",
                "PAID": "Value"
            })

    # ---------------------------------------
    # SINGLE MODE (fallback)
    # ---------------------------------------

    if prompt == "Monthly Total Cost Trend":
        return (
            df.groupby("MONTH")["PAID"]
            .sum()
            .reset_index()
            .rename(columns={"PAID": "Value"})
        )

    if prompt == "Total Cost by Line of Business":
        return (
            df.groupby("LINEOFBUSINESS")["PAID"]
            .sum()
            .reset_index()
            .rename(columns={
                "LINEOFBUSINESS": "Dimension",
                "PAID": "Value"
            })
        )

    # Default fallback
    return df
