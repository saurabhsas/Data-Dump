# core/matched_data_loader.py

def load_matched_datasets(df, matched):

    # Ensure consistent type
    df["MEMBER_ID"] = df["MEMBER_ID"].astype(str)

    # Extract matched IDs
    g1_ids = matched["G1_MEMBER_ID"].astype(str).unique()
    g2_ids = matched["G2_MEMBER_ID"].astype(str).unique()

    # ---------------------------------------
    # 🔥 KEEP ONLY IDs PRESENT IN FINAL DATA
    # ---------------------------------------
    valid_ids = set(df["MEMBER_ID"])

    g1_ids = list(set(g1_ids) & valid_ids)
    g2_ids = list(set(g2_ids) & valid_ids)

    # ---------------------------------------
    # 🔥 ENSURE STRICT 1:1 AFTER FILTER
    # ---------------------------------------
    min_count = min(len(g1_ids), len(g2_ids))

    g1_ids = g1_ids[:min_count]
    g2_ids = g2_ids[:min_count]

    # ---------------------------------------
    # CREATE DATASETS
    # ---------------------------------------
    g1 = df[df["MEMBER_ID"].isin(g1_ids)].copy()
    g2 = df[df["MEMBER_ID"].isin(g2_ids)].copy()

    g1["GROUP"] = "Group1"
    g2["GROUP"] = "Group2"

    return g1, g2
