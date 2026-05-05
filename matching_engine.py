# visualization/chart_router.py

import plotly.express as px


def build_chart(df, prompt):

    if df is None or df.empty:
        return px.scatter(title="No data available")

    # -------------------------------
    if prompt == "Monthly Total Cost Trend":
        return px.line(df, x="MONTH", y="Value", color="GROUP", markers=True)

    if prompt == "Medical vs Pharmacy Cost Split":
        return px.bar(df, x="Dimension", y="Value", color="GROUP", barmode="group")

    if "Trend" in prompt and "MONTH" in df.columns:
        return px.line(df, x="MONTH", y=df.columns[-1], color="GROUP")

    if "ED vs IP" in prompt:
        return px.line(df, x="MONTH", y=["EDVISITS", "IPVISITS"], color="GROUP")

    if "Avoidable Cost Analysis" in prompt:
        return px.bar(df, x="GROUP", y=["AVOIDED", "AVOIDIP"], barmode="group")

    if "Dimension" in df.columns:
        return px.bar(df, x="Dimension", y="Value", color="GROUP", barmode="group")

    return px.bar(df)
