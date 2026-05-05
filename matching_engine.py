def load_matched_datasets(df, matched):

    df["MEMBER_ID"] = df["MEMBER_ID"].astype(str)

    valid_ids = set(df["MEMBER_ID"])

    # 🔥 KEEP ONLY VALID MATCHES
    matched = matched[
        matched["G1_MEMBER_ID"].isin(valid_ids) &
        matched["G2_MEMBER_ID"].isin(valid_ids)
    ]

    # 🔥 DO NOT TRIM AGAIN (IMPORTANT)
    g1_ids = matched["G1_MEMBER_ID"].unique()
    g2_ids = matched["G2_MEMBER_ID"].unique()

    g1 = df[df["MEMBER_ID"].isin(g1_ids)].copy()
    g2 = df[df["MEMBER_ID"].isin(g2_ids)].copy()

    g1["GROUP"] = "Group1"
    g2["GROUP"] = "Group2"

    return g1, g2, matched
