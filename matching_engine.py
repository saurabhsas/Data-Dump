# core/matched_data_loader.py

import pandas as pd
import streamlit as st


@st.cache_data(show_spinner=False)
def load_matched_datasets(df, matched):
    """
    Create Group1 and Group2 datasets from matched pairs.

    Ensures:
    - MEMBER_ID consistency
    - Only valid IDs present in df are used
    - Strict 1:1 alignment preserved
    """

    # -----------------------------------
    # STANDARDIZE TYPES
    # -----------------------------------
    df = df.copy()
    df["MEMBER_ID"] = df["MEMBER_ID"].astype(str)

    matched = matched.copy()
    matched["G1_MEMBER_ID"] = matched["G1_MEMBER_ID"].astype(str)
    matched["G2_MEMBER_ID"] = matched["G2_MEMBER_ID"].astype(str)

    # -----------------------------------
    # FILTER VALID IDS (VERY IMPORTANT)
    # -----------------------------------
    valid_ids = set(df["MEMBER_ID"])

    matched = matched[
        matched["G1_MEMBER_ID"].isin(valid_ids) &
        matched["G2_MEMBER_ID"].isin(valid_ids)
    ]

    # -----------------------------------
    # ENSURE UNIQUE (STRICT 1:1 SAFETY)
    # -----------------------------------
    matched = matched.drop_duplicates(subset=["G1_MEMBER_ID"])
    matched = matched.drop_duplicates(subset=["G2_MEMBER_ID"])

    # -----------------------------------
    # EXTRACT FINAL ID LIST
    # -----------------------------------
    g1_ids = matched["G1_MEMBER_ID"].unique()
    g2_ids = matched["G2_MEMBER_ID"].unique()

    # -----------------------------------
    # BUILD DATASETS
    # -----------------------------------
    g1 = df[df["MEMBER_ID"].isin(g1_ids)].copy()
    g2 = df[df["MEMBER_ID"].isin(g2_ids)].copy()

    g1["GROUP"] = "Group1"
    g2["GROUP"] = "Group2"

    # -----------------------------------
    # FINAL VALIDATION (CRITICAL)
    # -----------------------------------
    g1_count = g1["MEMBER_ID"].nunique()
    g2_count = g2["MEMBER_ID"].nunique()

    if g1_count != g2_count:
        st.warning(
            f"⚠️ Mismatch after loading: Group1={g1_count}, Group2={g2_count}"
        )

    return g1, g2, matched
