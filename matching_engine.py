import plotly.express as px


def build_chart(df, prompt):

    # -----------------------------------
    # 🚫 Empty Data Safety
    # -----------------------------------
    if df is None or df.empty:
        return px.bar(title="No Data Available")

    # -----------------------------------
    # 📈 MONTHLY TREND (Single or Group)
    # -----------------------------------
    if "MONTH" in df.columns:

        # Case 1: Single metric (Value)
        if "Value" in df.columns:
            if "GROUP" in df.columns:
                return px.line(
                    df,
                    x="MONTH",
                    y="Value",
                    color="GROUP",
                    markers=True,
                    title=prompt
                )
            else:
                return px.line(
                    df,
                    x="MONTH",
                    y="Value",
                    markers=True,
                    title=prompt
                )

        # Case 2: Multi-metric (ED/IP etc.)
        y_cols = [c for c in df.columns if c not in ["MONTH", "GROUP"]]

        if "GROUP" in df.columns:
            # Melt for safe plotting
            df_melt = df.melt(id_vars=["MONTH", "GROUP"], value_vars=y_cols)

            return px.line(
                df_melt,
                x="MONTH",
                y="value",
                color="variable",
                line_dash="GROUP",
                markers=True,
                title=prompt
            )
        else:
            df_melt = df.melt(id_vars=["MONTH"], value_vars=y_cols)

            return px.line(
                df_melt,
                x="MONTH",
                y="value",
                color="variable",
                markers=True,
                title=prompt
            )

    # -----------------------------------
    # 📊 BAR CHARTS (Dimension based)
    # -----------------------------------
    if "Dimension" in df.columns:

        if "GROUP" in df.columns:
            return px.bar(
                df,
                x="Dimension",
                y="Value",
                color="GROUP",
                barmode="group",
                title=prompt
            )
        else:
            return px.bar(
                df,
                x="Dimension",
                y="Value",
                title=prompt
            )

    # -----------------------------------
    # 📊 UTILIZATION (ED vs IP)
    # -----------------------------------
    if set(["EDVISITS", "IPVISITS"]).issubset(df.columns):

        if "GROUP" in df.columns:
            df_melt = df.melt(id_vars="GROUP")

            return px.bar(
                df_melt,
                x="GROUP",
                y="value",
                color="variable",
                barmode="group",
                title=prompt
            )
        else:
            df_melt = df.melt()

            return px.bar(
                df_melt,
                x="variable",
                y="value",
                title=prompt
            )

    # -----------------------------------
    # 📊 PARETO / MEMBER BASED
    # -----------------------------------
    if "Value" in df.columns and "Dimension" in df.columns:

        return px.bar(
            df,
            x="Dimension",
            y="Value",
            title=prompt
        )

    # -----------------------------------
    # 🔁 FALLBACK
    # -----------------------------------
    return px.bar(df, title="Fallback Chart")
