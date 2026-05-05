def generate_insights(prompt, df):

    if df is None or df.empty:
        return ["No insights available"]

    insights = []

    # -------------------------------
    # Monthly Trend
    # -------------------------------
    if prompt == "Monthly Total Cost Trend":

        df = df.sort_values("MONTH")

        for g in df["GROUP"].unique():

            temp = df[df["GROUP"] == g]

            first = temp.iloc[0]["Value"]
            last = temp.iloc[-1]["Value"]

            change = ((last - first) / first * 100) if first != 0 else 0

            insights.append(
                f"{g} cost changed by {change:.1f}% over time "
                f"(${first:,.0f} → ${last:,.0f})."
            )

    # -------------------------------
    # LOB
    # -------------------------------
    elif prompt == "Total Cost by Line of Business":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"Highest cost LOB: {top['Dimension']} "
            f"(${top['Value']:,.0f})."
        )

        for g in df["GROUP"].unique():
            total = df[df["GROUP"] == g]["Value"].sum()
            insights.append(f"{g} total cost: ${total:,.0f}")

    # -------------------------------
    # County
    # -------------------------------
    elif prompt == "Total Cost by County":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"Top cost county: {top['Dimension']} "
            f"(${top['Value']:,.0f})."
        )

    # -------------------------------
    # Age
    # -------------------------------
    elif prompt == "Total Cost by Age Category":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"Highest cost age group: {top['Dimension']} "
            f"(${top['Value']:,.0f})."
        )

    # -------------------------------
    # Gender
    # -------------------------------
    elif prompt == "Total Cost by Gender":

        totals = df.groupby("Dimension")["Value"].sum()

        for g in totals.index:
            insights.append(f"{g}: ${totals[g]:,.0f}")

    # -------------------------------
    # Utilization
    # -------------------------------
    elif prompt == "ED vs IP Utilization Trend":

        totals = df.groupby("GROUP")[["EDVISITS", "IPVISITS"]].sum()

        for g in totals.index:
            insights.append(
                f"{g}: ED={int(totals.loc[g,'EDVISITS'])}, "
                f"IP={int(totals.loc[g,'IPVISITS'])}"
            )

    # -------------------------------
    # Pareto
    # -------------------------------
    elif prompt == "Pareto Cost Analysis (Top 5%)":

        total = df["Value"].sum()

        insights.append(
            f"Top 5% members contribute ${total:,.0f} of total cost."
        )

    else:
        insights.append("Compare cost and utilization across groups.")

    return insights
