# core/matching_engine.py

import pandas as pd
import numpy as np


def caliper_matching_sas(g1, g2, caliper=0.01):
    """
    Perform 1:1 matching using caliper on match_score
    with strict no-reuse logic (SAS equivalent).
    """

    # ---------------------------------------
    # STEP 1: CLEAN INPUT
    # ---------------------------------------
    g1 = g1[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBERID"]].drop_duplicates()
    g2 = g2[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBERID"]].drop_duplicates()

    # Convert types
    g1["MATCH_SCORE"] = pd.to_numeric(g1["MATCH_SCORE"], errors="coerce")
    g2["MATCH_SCORE"] = pd.to_numeric(g2["MATCH_SCORE"], errors="coerce")

    # Drop null scores
    g1 = g1.dropna(subset=["MATCH_SCORE"])
    g2 = g2.dropna(subset=["MATCH_SCORE"])

    # ---------------------------------------
    # STEP 2: CREATE ALL POSSIBLE PAIRS
    # ---------------------------------------
    g1["key"] = 1
    g2["key"] = 1

    pairs = g1.merge(g2, on="key", suffixes=("_G1", "_G2")).drop("key", axis=1)

    # ---------------------------------------
    # STEP 3: CALCULATE DIFFERENCE
    # ---------------------------------------
    pairs["diff"] = np.abs(pairs["MATCH_SCORE_G1"] - pairs["MATCH_SCORE_G2"])

    # ---------------------------------------
    # STEP 4: APPLY CALIPER + CONDITIONS
    # ---------------------------------------
    pairs = pairs[
        (pairs["diff"] < caliper) &
        (pairs["LOB_G1"] == pairs["LOB_G2"]) &
        (pairs["MEMBER_UCI_G1"] != pairs["MEMBER_UCI_G2"])
    ]

    if pairs.empty:
        return pd.DataFrame(columns=[
            "G1_MEMBER_UCI",
            "G2_MEMBER_UCI",
            "G1_MEMBERID",
            "G2_MEMBERID",
            "SCORE_DIFF"
        ])

    # ---------------------------------------
    # STEP 5: GLOBAL SORT (IMPORTANT FIX)
    # ---------------------------------------
    pairs = pairs.sort_values("diff")   # 🔥 key improvement

    # ---------------------------------------
    # STEP 6: STRICT 1:1 MATCHING
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
                "G1_MEMBERID": str(row["MEMBERID_G1"]),
                "G2_MEMBERID": str(row["MEMBERID_G2"]),
                "SCORE_DIFF": row["diff"],
                "LOB": row["LOB_G1"]
            })

            used_g1.add(g1_uci)
            used_g2.add(g2_uci)

    matched_df = pd.DataFrame(matched_rows)

    # ---------------------------------------
    # STEP 7: FINAL SAFETY ENFORCEMENT
    # ---------------------------------------
    if not matched_df.empty:

        matched_df = matched_df.drop_duplicates(subset=["G1_MEMBER_UCI"])
        matched_df = matched_df.drop_duplicates(subset=["G2_MEMBER_UCI"])

        # Force equal counts (absolute safety)
        min_count = min(
            matched_df["G1_MEMBER_UCI"].nunique(),
            matched_df["G2_MEMBER_UCI"].nunique()
        )

        matched_df = matched_df.head(min_count)

    # ---------------------------------------
    # STEP 8: VALIDATION (CRITICAL)
    # ---------------------------------------
    if not matched_df.empty:
        assert matched_df["G1_MEMBER_UCI"].nunique() == matched_df["G2_MEMBER_UCI"].nunique(), \
            "❌ Matching imbalance detected"

    return matched_df
