def generate_insights(prompt, df):

    if df is None or df.empty:
        return ["No insights available"]

    insights = []

    # -----------------------------------
    # Monthly Trend
    # -----------------------------------
    if prompt == "Monthly Total Cost Trend":

        df = df.sort_values("MONTH")

        latest = df.groupby("GROUP").tail(1)
        first = df.groupby("GROUP").head(1)

        for g in df["GROUP"].unique():
            latest_val = latest[latest["GROUP"] == g]["Value"].values[0]
            first_val = first[first["GROUP"] == g]["Value"].values[0]

            change = ((latest_val - first_val) / first_val * 100) if first_val != 0 else 0

            insights.append(
                f"{g} total cost changed by {change:.1f}% over the period "
                f"(${first_val:,.0f} → ${latest_val:,.0f})."
            )

        # volatility
        vol = df.groupby("GROUP")["Value"].std()
        for g in vol.index:
            insights.append(
                f"{g} shows volatility of ${vol[g]:,.0f} indicating variability in monthly spend."
            )

    # -----------------------------------
    # LOB
    # -----------------------------------
    elif prompt == "Total Cost by Line of Business":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"Highest cost Line of Business is {top['Dimension']} "
            f"with ${top['Value']:,.0f}."
        )

        share = df.groupby("GROUP")["Value"].sum()
        for g in share.index:
            insights.append(f"{g} total cost across LOBs: ${share[g]:,.0f}")

    # -----------------------------------
    # County
    # -----------------------------------
    elif prompt == "Total Cost by County":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"{top['Dimension']} is the highest cost county at ${top['Value']:,.0f}."
        )

        insights.append("Geographic variation suggests concentration of healthcare utilization.")

    # -----------------------------------
    # Age
    # -----------------------------------
    elif prompt == "Total Cost by Age Category":

        top = df.sort_values("Value", ascending=False).iloc[0]

        insights.append(
            f"Highest cost age segment: {top['Dimension']} "
            f"(${top['Value']:,.0f})."
        )

        insights.append("Older age groups typically drive higher utilization and costs.")

    # -----------------------------------
    # Gender
    # -----------------------------------
    elif prompt == "Total Cost by Gender":

        totals = df.groupby("Dimension")["Value"].sum()

        for g in totals.index:
            insights.append(f"{g} total cost: ${totals[g]:,.0f}")

        insights.append("Differences may reflect utilization patterns or population mix.")

    # -----------------------------------
    # Utilization
    # -----------------------------------
    elif prompt == "ED vs IP Utilization Trend":

        totals = df.groupby("GROUP")[["EDVISITS", "IPVISITS"]].sum()

        for g in totals.index:
            ed = totals.loc[g, "EDVISITS"]
            ip = totals.loc[g, "IPVISITS"]

            insights.append(
                f"{g}: ED visits = {int(ed):,}, IP visits = {int(ip):,}."
            )

        insights.append("Higher ED usage may indicate gaps in primary care access.")

    # -----------------------------------
    # Pareto
    # -----------------------------------
    elif prompt == "Pareto Cost Analysis (Top 5%)":

        total = df["Value"].sum()
        insights.append(
            f"Top 5% members contribute ${total:,.0f}, indicating strong cost concentration."
        )

        insights.append("This aligns with typical healthcare Pareto distribution (few drive majority cost).")

    # -----------------------------------
    # Default
    # -----------------------------------
    else:
        insights.append("Compare cost and utilization patterns across Group1 and Group2.")

    return insights
