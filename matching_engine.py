def generate_insights(prompt, df):

    if df is None or df.empty:
        return ["No insights available"]

    insights = []

    # -----------------------------------
    # Monthly Trend
    # -----------------------------------
    if prompt == "Monthly Total Cost Trend":

        latest = df.sort_values("MONTH").groupby("GROUP").tail(1)

        for _, row in latest.iterrows():
            insights.append(
                f"{row['GROUP']} latest month cost: ${row['Value']:,.0f}"
            )

        trend = df.groupby("GROUP")["Value"].pct_change().mean()

        for g, v in trend.items():
            if v is not None:
                insights.append(
                    f"{g} average trend change: {v:.2%}"
                )

    # -----------------------------------
    # LOB
    # -----------------------------------
    elif prompt == "Total Cost by Line of Business":

        top = df.sort_values("Value", ascending=False).head(1)

        insights.append(
            f"Top LOB: {top.iloc[0]['Dimension']} "
            f"(${top.iloc[0]['Value']:,.0f})"
        )

    # -----------------------------------
    # Utilization
    # -----------------------------------
    elif prompt == "ED vs IP Utilization Trend":

        totals = df.groupby("GROUP")[["EDVISITS", "IPVISITS"]].sum()

        for g in totals.index:
            insights.append(
                f"{g}: ED {int(totals.loc[g,'EDVISITS'])}, "
                f"IP {int(totals.loc[g,'IPVISITS'])}"
            )

    # -----------------------------------
    # Default
    # -----------------------------------
    else:
        insights.append("Explore differences between Group1 and Group2.")

    return insights
