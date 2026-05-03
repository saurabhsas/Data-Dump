import pandas as pd
import numpy as np
from scipy.stats import ttest_ind


# ---------------------------------------
# 🧠 Helper: Cohen's d (Effect Size)
# ---------------------------------------
def cohens_d(x, y):

    nx = len(x)
    ny = len(y)

    if nx < 2 or ny < 2:
        return np.nan

    mean_x = np.mean(x)
    mean_y = np.mean(y)

    var_x = np.var(x, ddof=1)
    var_y = np.var(y, ddof=1)

    pooled_std = np.sqrt(((nx - 1) * var_x + (ny - 1) * var_y) / (nx + ny - 2))

    if pooled_std == 0:
        return 0

    return (mean_x - mean_y) / pooled_std


# ---------------------------------------
# 🧠 Single Metric t-test
# ---------------------------------------
def run_ttest(g1_df, g2_df, column):

    if column not in g1_df.columns or column not in g2_df.columns:
        return None

    g1 = pd.to_numeric(g1_df[column], errors="coerce").dropna()
    g2 = pd.to_numeric(g2_df[column], errors="coerce").dropna()

    if len(g1) < 2 or len(g2) < 2:
        return {
            "metric": column,
            "g1_mean": None,
            "g2_mean": None,
            "p_value": None,
            "significant": False,
            "effect_size": None,
            "note": "Insufficient data"
        }

    # Welch’s t-test (unequal variance)
    stat, pval = ttest_ind(g1, g2, equal_var=False)

    effect = cohens_d(g1, g2)

    return {
        "metric": column,
        "g1_mean": float(np.mean(g1)),
        "g2_mean": float(np.mean(g2)),
        "p_value": float(pval),
        "significant": bool(pval < 0.05),
        "effect_size": float(effect),
        "note": ""
    }


# ---------------------------------------
# 🧠 Multiple Tests (Main Entry)
# ---------------------------------------
def run_multiple_tests(g1_df, g2_df):

    metrics = [
        "PAID",
        "MEDICAL_PAID",
        "RX_PAID",
        "EDVISITS",
        "IPVISITS"
    ]

    results = []

    for col in metrics:
        res = run_ttest(g1_df, g2_df, col)
        if res:
            results.append(res)

    return results


# ---------------------------------------
# 🧠 Optional: Convert to DataFrame
# ---------------------------------------
def results_to_dataframe(results):

    if not results:
        return pd.DataFrame()

    df = pd.DataFrame(results)

    # Formatting
    df["p_value"] = df["p_value"].apply(
        lambda x: round(x, 4) if x is not None else None
    )

    df["effect_size"] = df["effect_size"].apply(
        lambda x: round(x, 3) if x is not None else None
    )

    return df
