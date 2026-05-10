import pandas as pd
import numpy as np
import nzpy

Group1_df = pd.read_csv("data/Group1.csv", dtype=str)
Group2_df = pd.read_csv("data/Group2.csv", dtype=str)

member_ids_g1 = tuple(Group1_df["Member_ID"].unique())
member_ids_g2 = tuple(Group2_df["Member_ID"].unique())

# ----------------------------------------------------------------
# Processing for Group1
# ---------------------------------------------------------------- 

conn = nzpy.connect(
user='ssingh6',
password='Sasis@555',
host='npsaas_dev_db',
port=5480,
database='IRADW_UAT'
)

# SQL query
query = f"""
SELECT DISTINCT
            MEMBERID as MEMBER_ID
			, ACCOUNTID
			, CLAIMID
			, FINAL_PAID_CLAIM
			, MR_LINE_CASE as HCG_SVC_CAT_LINE
			, MR_LINE as HCG_SVC_CAT
			, MR_LINE_DESC1
            , MR_LINE_DESC2
            , MR_LINE_DESC3
            , PAID
			, SVC_STRT_DT
			, MR_ALLOWED
FROM IRADW_UAT.DM_M360.CUDA_CLAIMS MAIN
WHERE MAIN.SVC_STRT_DT BETWEEN '20250101' AND '20251231'
AND CLAIM_STATUS = 'FINAL'
AND FINAL_PAID_CLAIM = 'Y'
AND MEMBERID IN {member_ids_g1}
"""

# Load into DataFrame
CLAIMS_DATA_GROUP1_MED = pd.read_sql(query, conn)

# Optional: close connection
conn.close()

CLAIMS_DATA_GROUP1_MED["PAID"] = pd.to_numeric(CLAIMS_DATA_GROUP1_MED["PAID"], errors="coerce")
CLAIMS_DATA_GROUP1_MED["MR_ALLOWED"] = pd.to_numeric(CLAIMS_DATA_GROUP1_MED["MR_ALLOWED"], errors="coerce")
CLAIMS_DATA_GROUP1_MED["SVC_STRT_DT"] = pd.to_datetime(CLAIMS_DATA_GROUP1_MED["SVC_STRT_DT"]).dt.normalize()

CLAIMS_DATA_GROUP1_MED["SVC_CAT"] = CLAIMS_DATA_GROUP1_MED[["MR_LINE_DESC2", "MR_LINE_DESC3"]].apply(
    lambda x: '-'.join(x.dropna(). astype(str)), axis=1)



svc_upper = CLAIMS_DATA_GROUP1_MED["SVC_CAT"].str.upper()
mr = CLAIMS_DATA_GROUP1_MED["MR_LINE_DESC1"]

conditions = [
    # FIP
    (mr == "FIP") & (svc_upper.isin(["ALCOHOL AND DRUG ABUSE-HOSPITAL", "ALCOHOL AND DRUG ABUSE-RESIDENTIAL"])),
    (mr == "FIP") & (svc_upper.isin(["MAT NORM DELIVERY", "MAT NORM DELIVERY-MOM\\BABY CMBND"])),
    (mr == "FIP") & (svc_upper.isin(["MAT CSECT DELIVERY", "MAT CSECT DELIVERY-MOM\\BABY CMBND"])),
    (mr == "FIP") & (svc_upper.isin(["PSYCHIATRIC-HOSPITAL", "PSYCHIATRIC-RESIDENTIAL"])),
    (mr == "FIP") & (svc_upper.isin(["WELL NEWBORN-CSECT DELIVERY", "WELL NEWBORN-UNKNOWN DELIVERY"])),

    # FOP
    (mr == "FOP") & (svc_upper.isin(["RADIOLOGY GENERAL-DIAGNOSTIC", "RADIOLOGY GENERAL-THERAPEUTIC"])),
    (mr == "FOP") & (svc_upper.isin(["RADIOLOGY - CT/MRI/PET-CT SCAN", "RADIOLOGY - CT/MRI/PET-MRI", "RADIOLOGY - CT/MRI/PET-PET"])),
    (mr == "FOP") & (svc_upper.isin(["ALCOHOL & DRUG ABUSE-INTENSIVE OUTPATIENT", "ALCOHOL & DRUG ABUSE-PARTIAL HOSPITALIZATION"])),
    (mr == "FOP") & (svc_upper.isin(["PSYCHIATRIC-INTENSIVE OUTPATIENT", "PSYCHIATRIC-PARTIAL HOSPITALIZATION"])),
    (mr == "FOP") & (svc_upper.isin(["PREVENTIVE-COLONOSCOPY", "PREVENTIVE-GENERAL", "PREVENTIVE-LAB", "PREVENTIVE-MAMMOGRAPHY"])),
    (mr == "FOP") & (svc_upper.isin(["OTHER-BLOOD", "OTHER-CLINIC", "OTHER-DME/SUPPLIES", "OTHER-DIAGNOSTIC",
                                    "OTHER-DIALYSIS", "OTHER-GENERAL", "OTHER-PULMONARY", "OTHER-TRTMT/SPCLTYSVCS"])),

    # PROF (sample subset shown; pattern continues same way)
    (mr == "PROF") & (svc_upper.isin(["INPATIENT VISITS-ALCOHOL AND DRUG ABUSE", "INPATIENT VISITS-MEDICAL", "INPATIENT VISITS-PSYCHIATRIC"])),
    (mr == "PROF") & (svc_upper.isin(["MATERNITY-ANCILLARY", "MATERNITY-ANESTHESIA", "MATERNITY-CESAREAN DELIVERIES",
                                     "MATERNITY-NON-DELIVERIES", "MATERNITY-NORMAL DELIVERIES"])),

    # OTH
    (mr == "OTH") & (svc_upper.isin(["HOME HEALTH CARE-HH", "HOME HEALTH CARE-HOSPICE"])),

    # ADDL
    (mr == "ADDL") & (svc_upper.isin(["BENEFITS OTHER-ACUPUNCTURE", "BENEFITS OTHER-DENTAL",
                                     "BENEFITS OTHER-DOCUMENTATION/UNCLASSIFIED", "BENEFITS OTHER-GENERAL",
                                     "BENEFITS OTHER-HEARING AIDS", "BENEFITS OTHER-NON-EMERGENCY TRANSPORTATION",
                                     "BENEFITS OTHER-REPRODUCTIVE MEDICINE", "BENEFITS OTHER-TEMPORARY CODES"]))
]

choices = [
    "Alcohol and Drug Abuse",
    "Mat Norm Delivery",
    "Mat Csect Delivery",
    "Psychiatric",
    "Well Newborn",
    "Radiology General",
    "Radiology - CT/MRI/PET",
    "Alcohol & Drug Abuse",
    "Psychiatric",
    "Preventive",
    "Other",
    "Inpatient Visits",
    "Maternity",
    "Home Health Care",
    "Benefits Other"
]

CLAIMS_DATA_GROUP1_MED["SVC_CAT2"] = np.select(conditions, choices, default=CLAIMS_DATA_GROUP1_MED["SVC_CAT"])



svc2_upper = CLAIMS_DATA_GROUP1_MED["SVC_CAT2"].str.upper()
mr = CLAIMS_DATA_GROUP1_MED["MR_LINE_DESC1"]

conditions2 = [
    (mr == "OTH") & (svc2_upper.isin(["HOME HEALTH CARE", "AMBULANCE", "DME AND SUPPLIES", "PROSTHETICS"])),
    (mr == "ADDL") & (svc2_upper.isin(["BENEFITS OTHER", "BENEFITS GLASSES/CONTACTS"]))
]

choices2 = [
    "PROF",
    "PROF"
]
CLAIMS_DATA_GROUP1_MED["MR_LINE_DESC1_FINAL"] = np.select(conditions2, choices2, default=CLAIMS_DATA_GROUP1_MED["MR_LINE_DESC1"])


Summary_Group1 = (
    CLAIMS_DATA_GROUP1_MED.groupby(["MR_LINE_DESC1_FINAL", "SVC_CAT2"])
      .agg(
          Total_Claim_Count=("CLAIMID", "nunique"),
          Total_Paid_Amount=("PAID", "sum")
      )
      .reset_index()
)


# ----------------------------------------------------------------
# Processing for Group2
# ---------------------------------------------------------------- 

conn = nzpy.connect(
user='ssingh6',
password='Sasis@555',
host='npsaas_dev_db',
port=5480,
database='IRADW_UAT'
)

# SQL query
query = f"""
SELECT DISTINCT
            MEMBERID as MEMBER_ID
			, ACCOUNTID
			, CLAIMID
			, FINAL_PAID_CLAIM
			, MR_LINE_CASE as HCG_SVC_CAT_LINE
			, MR_LINE as HCG_SVC_CAT
			, MR_LINE_DESC1
            , MR_LINE_DESC2
            , MR_LINE_DESC3
            , PAID
			, SVC_STRT_DT
			, MR_ALLOWED
FROM IRADW_UAT.DM_M360.CUDA_CLAIMS MAIN
WHERE MAIN.SVC_STRT_DT BETWEEN '20250101' AND '20251231'
AND CLAIM_STATUS = 'FINAL'
AND FINAL_PAID_CLAIM = 'Y'
AND MEMBERID IN {member_ids_g2}
"""

# Load into DataFrame
CLAIMS_DATA_GROUP2_MED = pd.read_sql(query, conn)

# Optional: close connection
conn.close()

CLAIMS_DATA_GROUP2_MED["PAID"] = pd.to_numeric(CLAIMS_DATA_GROUP2_MED["PAID"], errors="coerce")
CLAIMS_DATA_GROUP2_MED["MR_ALLOWED"] = pd.to_numeric(CLAIMS_DATA_GROUP2_MED["MR_ALLOWED"], errors="coerce")
CLAIMS_DATA_GROUP2_MED["SVC_STRT_DT"] = pd.to_datetime(CLAIMS_DATA_GROUP2_MED["SVC_STRT_DT"]).dt.normalize()

CLAIMS_DATA_GROUP2_MED["SVC_CAT"] = CLAIMS_DATA_GROUP2_MED[["MR_LINE_DESC2", "MR_LINE_DESC3"]].apply(
    lambda x: '-'.join(x.dropna(). astype(str)), axis=1)



svc_upper = CLAIMS_DATA_GROUP2_MED["SVC_CAT"].str.upper()
mr = CLAIMS_DATA_GROUP2_MED["MR_LINE_DESC1"]

conditions = [
    # FIP
    (mr == "FIP") & (svc_upper.isin(["ALCOHOL AND DRUG ABUSE-HOSPITAL", "ALCOHOL AND DRUG ABUSE-RESIDENTIAL"])),
    (mr == "FIP") & (svc_upper.isin(["MAT NORM DELIVERY", "MAT NORM DELIVERY-MOM\\BABY CMBND"])),
    (mr == "FIP") & (svc_upper.isin(["MAT CSECT DELIVERY", "MAT CSECT DELIVERY-MOM\\BABY CMBND"])),
    (mr == "FIP") & (svc_upper.isin(["PSYCHIATRIC-HOSPITAL", "PSYCHIATRIC-RESIDENTIAL"])),
    (mr == "FIP") & (svc_upper.isin(["WELL NEWBORN-CSECT DELIVERY", "WELL NEWBORN-UNKNOWN DELIVERY"])),

    # FOP
    (mr == "FOP") & (svc_upper.isin(["RADIOLOGY GENERAL-DIAGNOSTIC", "RADIOLOGY GENERAL-THERAPEUTIC"])),
    (mr == "FOP") & (svc_upper.isin(["RADIOLOGY - CT/MRI/PET-CT SCAN", "RADIOLOGY - CT/MRI/PET-MRI", "RADIOLOGY - CT/MRI/PET-PET"])),
    (mr == "FOP") & (svc_upper.isin(["ALCOHOL & DRUG ABUSE-INTENSIVE OUTPATIENT", "ALCOHOL & DRUG ABUSE-PARTIAL HOSPITALIZATION"])),
    (mr == "FOP") & (svc_upper.isin(["PSYCHIATRIC-INTENSIVE OUTPATIENT", "PSYCHIATRIC-PARTIAL HOSPITALIZATION"])),
    (mr == "FOP") & (svc_upper.isin(["PREVENTIVE-COLONOSCOPY", "PREVENTIVE-GENERAL", "PREVENTIVE-LAB", "PREVENTIVE-MAMMOGRAPHY"])),
    (mr == "FOP") & (svc_upper.isin(["OTHER-BLOOD", "OTHER-CLINIC", "OTHER-DME/SUPPLIES", "OTHER-DIAGNOSTIC",
                                    "OTHER-DIALYSIS", "OTHER-GENERAL", "OTHER-PULMONARY", "OTHER-TRTMT/SPCLTYSVCS"])),

    # PROF (sample subset shown; pattern continues same way)
    (mr == "PROF") & (svc_upper.isin(["INPATIENT VISITS-ALCOHOL AND DRUG ABUSE", "INPATIENT VISITS-MEDICAL", "INPATIENT VISITS-PSYCHIATRIC"])),
    (mr == "PROF") & (svc_upper.isin(["MATERNITY-ANCILLARY", "MATERNITY-ANESTHESIA", "MATERNITY-CESAREAN DELIVERIES",
                                     "MATERNITY-NON-DELIVERIES", "MATERNITY-NORMAL DELIVERIES"])),

    # OTH
    (mr == "OTH") & (svc_upper.isin(["HOME HEALTH CARE-HH", "HOME HEALTH CARE-HOSPICE"])),

    # ADDL
    (mr == "ADDL") & (svc_upper.isin(["BENEFITS OTHER-ACUPUNCTURE", "BENEFITS OTHER-DENTAL",
                                     "BENEFITS OTHER-DOCUMENTATION/UNCLASSIFIED", "BENEFITS OTHER-GENERAL",
                                     "BENEFITS OTHER-HEARING AIDS", "BENEFITS OTHER-NON-EMERGENCY TRANSPORTATION",
                                     "BENEFITS OTHER-REPRODUCTIVE MEDICINE", "BENEFITS OTHER-TEMPORARY CODES"]))
]

choices = [
    "Alcohol and Drug Abuse",
    "Mat Norm Delivery",
    "Mat Csect Delivery",
    "Psychiatric",
    "Well Newborn",
    "Radiology General",
    "Radiology - CT/MRI/PET",
    "Alcohol & Drug Abuse",
    "Psychiatric",
    "Preventive",
    "Other",
    "Inpatient Visits",
    "Maternity",
    "Home Health Care",
    "Benefits Other"
]

CLAIMS_DATA_GROUP2_MED["SVC_CAT2"] = np.select(conditions, choices, default=CLAIMS_DATA_GROUP2_MED["SVC_CAT"])



svc2_upper = CLAIMS_DATA_GROUP2_MED["SVC_CAT2"].str.upper()
mr = CLAIMS_DATA_GROUP2_MED["MR_LINE_DESC1"]

conditions2 = [
    (mr == "OTH") & (svc2_upper.isin(["HOME HEALTH CARE", "AMBULANCE", "DME AND SUPPLIES", "PROSTHETICS"])),
    (mr == "ADDL") & (svc2_upper.isin(["BENEFITS OTHER", "BENEFITS GLASSES/CONTACTS"]))
]

choices2 = [
    "PROF",
    "PROF"
]
CLAIMS_DATA_GROUP2_MED["MR_LINE_DESC1_FINAL"] = np.select(conditions2, choices2, default=CLAIMS_DATA_GROUP2_MED["MR_LINE_DESC1"])


Summary_Group2 = (
    CLAIMS_DATA_GROUP2_MED.groupby(["MR_LINE_DESC1_FINAL", "SVC_CAT2"])
      .agg(
          Total_Claim_Count=("CLAIMID", "nunique"),
          Total_Paid_Amount=("PAID", "sum")
      )
      .reset_index()
)
