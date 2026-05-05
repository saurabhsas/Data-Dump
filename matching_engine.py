def caliper_matching_sas(g1, g2, caliper=0.01):

    import pandas as pd
    import numpy as np

    g1 = g1[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBER_ID"]].drop_duplicates()
    g2 = g2[["MEMBER_UCI", "MATCH_SCORE", "LOB", "MEMBER_ID"]].drop_duplicates()

    g1["MATCH_SCORE"] = pd.to_numeric(g1["MATCH_SCORE"], errors="coerce")
    g2["MATCH_SCORE"] = pd.to_numeric(g2["MATCH_SCORE"], errors="coerce")

    g1 = g1.dropna(subset=["MATCH_SCORE"])
    g2 = g2.dropna(subset=["MATCH_SCORE"])

    # Cross join
    g1["key"] = 1
    g2["key"] = 1

    pairs = g1.merge(g2, on="key", suffixes=("_G1", "_G2")).drop("key", axis=1)

    # Diff
    pairs["diff"] = abs(pairs["MATCH_SCORE_G1"] - pairs["MATCH_SCORE_G2"])

    # Apply filters
    pairs = pairs[
        (pairs["diff"] < caliper) &
        (pairs["LOB_G1"] == pairs["LOB_G2"])
    ]

    # 🔥 GLOBAL SORT
    pairs = pairs.sort_values("diff")

    used_g1 = set()
    used_g2 = set()
    out = []

    for _, row in pairs.iterrows():

        g1_uci = row["MEMBER_UCI_G1"]
        g2_uci = row["MEMBER_UCI_G2"]

        if g1_uci not in used_g1 and g2_uci not in used_g2:

            out.append({
                "G1_MEMBER_ID": str(row["MEMBER_ID_G1"]),
                "G2_MEMBER_ID": str(row["MEMBER_ID_G2"]),
                "diff": row["diff"]
            })

            used_g1.add(g1_uci)
            used_g2.add(g2_uci)

    matched = pd.DataFrame(out)

    # ✅ VALIDATION
    print("Matched G1:", matched["G1_MEMBER_ID"].nunique())
    print("Matched G2:", matched["G2_MEMBER_ID"].nunique())

    return matched
