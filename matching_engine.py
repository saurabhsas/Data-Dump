import pandas as pd


def caliper_matching_sas(g1_df, g2_df, caliper=0.01):

    # -----------------------------------
    # 1️⃣ Create distinct datasets
    # -----------------------------------
    g1 = g1_df[["MEMBER_UCI", "MATCH_SCORE", "LOB"]].drop_duplicates().copy()
    g2 = g2_df[["MEMBER_UCI", "MATCH_SCORE", "LOB"]].drop_duplicates().copy()

    # Ensure numeric
    g1["MATCH_SCORE"] = pd.to_numeric(g1["MATCH_SCORE"], errors="coerce")
    g2["MATCH_SCORE"] = pd.to_numeric(g2["MATCH_SCORE"], errors="coerce")

    g1 = g1.dropna(subset=["MATCH_SCORE"])
    g2 = g2.dropna(subset=["MATCH_SCORE"])

    # -----------------------------------
    # 2️⃣ Create all valid pairs (CROSS JOIN)
    # -----------------------------------
    g1["key"] = 1
    g2["key"] = 1

    pairs = g1.merge(g2, on="key", suffixes=("_G1", "_G2")).drop("key", axis=1)

    # Apply SAS conditions
    pairs["diff"] = abs(pairs["MATCH_SCORE_G1"] - pairs["MATCH_SCORE_G2"])

    pairs = pairs[
        (pairs["diff"] < caliper) &
        (pairs["MEMBER_UCI_G1"] != pairs["MEMBER_UCI_G2"]) &
        (pairs["LOB_G1"] == pairs["LOB_G2"])
    ].copy()

    if pairs.empty:
        print("No pairs found within caliper")
        return pd.DataFrame()

    # -----------------------------------
    # 3️⃣ SORT (SAS equivalent)
    # -----------------------------------
    pairs = pairs.sort_values(["MEMBER_UCI_G2", "diff"]).reset_index(drop=True)

    # -----------------------------------
    # 4️⃣ MATCH WITHOUT REUSE (HASH LOGIC)
    # -----------------------------------
    used_g2 = set()  # treated
    used_g1 = set()  # control

    final_matches = []

    for _, row in pairs.iterrows():

        g2_id = row["MEMBER_UCI_G2"]
        g1_id = row["MEMBER_UCI_G1"]

        lob_g2 = row["LOB_G2"]
        lob_g1 = row["LOB_G1"]

        # mimic SAS hash check (no reuse + LOB consistency)
        if (g2_id, lob_g2) not in used_g2 and (g1_id, lob_g1) not in used_g1:

            final_matches.append({
                "G1_MEMBER_UCI": g1_id,
                "G2_MEMBER_UCI": g2_id,
                "G1_SCORE": row["MATCH_SCORE_G1"],
                "G2_SCORE": row["MATCH_SCORE_G2"],
                "SCORE_DIFF": row["diff"],
                "LOB": lob_g1
            })

            used_g2.add((g2_id, lob_g2))
            used_g1.add((g1_id, lob_g1))

    matched_df = pd.DataFrame(final_matches)

    # -----------------------------------
    # 5️⃣ COUNT (SAS equivalent)
    # -----------------------------------
    print("\n📊 MATCH SUMMARY")
    print("Unique G1:", matched_df["G1_MEMBER_UCI"].nunique())
    print("Unique G2:", matched_df["G2_MEMBER_UCI"].nunique())
    print("Total Matches:", len(matched_df))

    return matched_df
