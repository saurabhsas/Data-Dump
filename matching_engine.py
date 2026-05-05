# core/insights_engine.py

def generate_insights(prompt, df):

    if df is None or df.empty:
        return ["No insights available"]

    insights = []

    if "Monthly" in prompt:
        for g in df["GROUP"].unique():
            temp = df[df["GROUP"] == g]
            change = (temp["Value"].iloc[-1] - temp["Value"].iloc[0])
            insights.append(f"{g} change: {change:,.0f}")

    elif "Line of Business" in prompt:
        top = df.sort_values("Value", ascending=False).iloc[0]
        insights.append(f"Top LOB: {top['Dimension']}")

    elif "Top 10" in prompt:
        insights.append("Top members drive majority cost.")

    elif "Pareto" in prompt:
        insights.append("Top 5% contributing highest cost.")

    else:
        insights.append("Compare Group1 vs Group2 patterns.")

    return insights
