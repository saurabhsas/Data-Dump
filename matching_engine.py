import pandas as pd


def caliper_matching(group1_df, group2_df, caliper=0.01):

    g1 = group1_df.copy()
    g2 = group2_df.copy()

    # Ensure numeric
    g1["MATCH_SCORE"] = pd.to_numeric(g1["MATCH_SCORE"], errors="coerce")
    g2["MATCH_SCORE"] = pd.to_numeric(g2["MATCH_SCORE"], errors="coerce")

    g1 = g1.dropna(subset=["MATCH_SCORE"]).reset_index(drop=True)
    g2 = g2.dropna(subset=["MATCH_SCORE"]).reset_index(drop=True)

    # -----------------------------------
    # 🔗 CREATE ALL POSSIBLE MATCHES
    # -----------------------------------
    g1["key"] = 1
    g2["key"] = 1

    pairs = g1.merge(g2, on="key", suffixes=("_G1", "_G2")).drop("key", axis=1)

    # Compute difference
    pairs["diff"] = abs(pairs["MATCH_SCORE_G1"] - pairs["MATCH_SCORE_G2"])

    # Apply caliper
    pairs = pairs[pairs["diff"] <= caliper]

    if pairs.empty:
        print("No matches found within caliper")
        return pd.DataFrame()

    # -----------------------------------
    # 🎯 SORT BY BEST MATCHES
    # -----------------------------------
    pairs = pairs.sort_values("diff")

    # -----------------------------------
    # 🚫 NO REPLACEMENT MATCHING
    # -----------------------------------
    used_g1 = set()
    used_g2 = set()

    final_matches = []

    for _, row in pairs.iterrows():

        g1_id = row["MEMBER_UCI_G1"]
        g2_id = row["MEMBER_UCI_G2"]

        if g1_id in used_g1 or g2_id in used_g2:
            continue

        final_matches.append({
            "G1_MEMBER_UCI": g1_id,
            "G1_SCORE": row["MATCH_SCORE_G1"],
            "G2_MEMBER_UCI": g2_id,
            "G2_SCORE": row["MATCH_SCORE_G2"],
            "SCORE_DIFF": row["diff"]
        })

        used_g1.add(g1_id)
        used_g2.add(g2_id)

    matched_df = pd.DataFrame(final_matches)

    print(f"Total matches found: {len(matched_df)}")

    return matched_df
