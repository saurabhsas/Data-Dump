# core/matching_engine.py

import pandas as pd
import numpy as np


def caliper_matching_sas(g1, g2, caliper=0.01):

    # ---------------------------------------
    # STEP 1: CLEAN INPUT
    # ---------------------------------------
    g1 = g1[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBER_ID"]].drop_duplicates()
    g2 = g2[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBER_ID"]].drop_duplicates()

    g1["MATCH_SCORE"] = pd.to_numeric(g1["MATCH_SCORE"], errors="coerce")
    g2["MATCH_SCORE"] = pd.to_numeric(g2["MATCH_SCORE"], errors="coerce")

    g1 = g1.dropna(subset=["MATCH_SCORE"])
    g2 = g2.dropna(subset=["MATCH_SCORE"])

    # ---------------------------------------
    # STEP 2: CROSS JOIN
    # ---------------------------------------
    g1["key"] = 1
    g2["key"] = 1

    pairs = g1.merge(g2, on="key", suffixes=("_G1", "_G2")).drop("key", axis=1)

    # ---------------------------------------
    # STEP 3: CALCULATE DIFF
    # ---------------------------------------
    pairs["diff"] = np.abs(pairs["MATCH_SCORE_G1"] - pairs["MATCH_SCORE_G2"])

    # ---------------------------------------
    # STEP 4: APPLY CALIPER + LOB
    # ---------------------------------------
    pairs = pairs[
        (pairs["diff"] < caliper) &
        (pairs["LOB_G1"] == pairs["LOB_G2"]) &
        (pairs["MEMBER_UCI_G1"] != pairs["MEMBER_UCI_G2"])
    ]

    if pairs.empty:
        return pd.DataFrame()

    # ---------------------------------------
    # STEP 5: GLOBAL SORT (IMPORTANT)
    # ---------------------------------------
    pairs = pairs.sort_values("diff")

    # ---------------------------------------
    # STEP 6: STRICT 1:1 MATCH
    # ---------------------------------------
    used_g1 = set()
    used_g2 = set()

    matched_rows = []

    for _, row in pairs.iterrows():

        g1_uci = row["MEMBER_UCI_G1"]
        g2_uci = row["MEMBER_UCI_G2"]

        if g1_uci not in used_g1 and g2_uci not in used_g2:

            matched_rows.append({
                "G1_MEMBER_UCI": g1_uci,
                "G2_MEMBER_UCI": g2_uci,
                "G1_MEMBER_ID": str(row["MEMBER_ID_G1"]),
                "G2_MEMBER_ID": str(row["MEMBER_ID_G2"]),
                "SCORE_DIFF": row["diff"]
            })

            used_g1.add(g1_uci)
            used_g2.add(g2_uci)

    matched_df = pd.DataFrame(matched_rows)

    # ---------------------------------------
    # FINAL VALIDATION
    # ---------------------------------------
    if not matched_df.empty:
        assert matched_df["G1_MEMBER_UCI"].nunique() == matched_df["G2_MEMBER_UCI"].nunique(), \
            "Matching imbalance detected"

    return matched_df
