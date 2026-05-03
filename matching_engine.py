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

/*----------------------------------------------------------------------------------*/
/*Add a Caliper: restrict matches with diff 0.01, 0.001 & 0.0001*/
/*----------------------------------------------------------------------------------*/
/*153 rows and 3 columns*/
Proc SQL;
Create Table Group1_member_score as 
Select Distinct MEMBER_UCI, match_score, LOB
From Member_match_score_Group1;
Quit;
/*526 rows and 3 columns*/
Proc SQL;
Create Table Group2_member_score as 
Select Distinct MEMBER_UCI, match_score, LOB
From Member_match_score_Group2;
Quit;

/*94 rows and 7 columns*/
Proc SQL;
Create Table scored_paris_2 as
Select a.MEMBER_UCI as Group1_MEMBERUCI,
	   b.MEMBER_UCI as Group2_MEMBERUCI,
	   a.match_score as Group1_match_score,
	   b.match_score as Group2_match_score,
	   abs(b.match_score - a.match_score) as diff,
	   a.LOB as LOB_G1,
	   b.LOB as LOB_G2
From Group1_member_score as a, Group2_member_score as b
where abs(a.match_score - b.match_score) < 0.01 /*Caliper*/
		and abs(a.match_score - b.match_score) is not null
		and Group1_MEMBERUCI ne Group2_MEMBERUCI
		and a.lob = b.lob;
Run;
Proc Sort data=scored_paris_2;
By Group2_MEMBERUCI diff;
Run;

/*66, 80*/
Proc SQL;
Select count(distinct Group1_MEMBERUCI) , count(distinct Group2_MEMBERUCI)
From scored_paris_2;
Quit;


/*Match Without Reuse of Base Group Memberuci : 1:1 matching only*/
Data Match_Pairs;
Declare hash used_treat();
	rc1 = used_treat.definekey('Group2_MEMBERUCI');
	rc1 = used_treat.definekey('LOB_G2');
	rc1 = used_treat.defineDone();
Declare hash used_ctrl();
	rc2 = used_ctrl.definekey('Group1_MEMBERUCI');
	rc1 = used_ctrl.definekey('LOB_G1');
	rc2 = used_ctrl.defineDone();

	Do Until (done);
		set scored_paris_2 end=done;
		if used_treat.check() ne 0 and used_ctrl.check() ne 0 then do;
			output;
			rc1 = used_treat.add();
			rc2 = used_ctrl.add();
		end;
	end;
Drop rc1 rc2;
Run;

Proc SQL;
Select LOB_G1,count(distinct Group1_MEMBERUCI) , count(distinct Group2_MEMBERUCI)
From Match_Pairs
gROUP BY LOB_G1;
Quit;
Proc SQL;
Select count(distinct Group1_MEMBERUCI) , count(distinct Group2_MEMBERUCI)
From Match_Pairs;
Quit;


