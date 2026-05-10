import numpy as np
import pandas as pd

df = CLAIMS_DATA_GROUP1_MED.copy()

svc_upper = df["SVC_CAT"].str.upper()
mr = df["MR_LINE_DESC1"]

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

df["SVC_CAT2"] = np.select(conditions, choices, default=df["SVC_CAT"])


svc2_upper = df["SVC_CAT2"].str.upper()
mr = df["MR_LINE_DESC1"]

conditions2 = [
    (mr == "OTH") & (svc2_upper.isin(["HOME HEALTH CARE", "AMBULANCE", "DME AND SUPPLIES", "PROSTHETICS"])),
    (mr == "ADDL") & (svc2_upper.isin(["BENEFITS OTHER", "BENEFITS GLASSES/CONTACTS"]))
]

choices2 = [
    "PROF",
    "PROF"
]

df["MR_LINE_DESC1_FINAL"] = np.select(conditions2, choices2, default=df["MR_LINE_DESC1"])



summary = (
    df.groupby(["MR_LINE_DESC1_FINAL", "SVC_CAT2"])
      .agg(
          Total_Claim_Count=("CLAIMID", "nunique"),
          Total_Paid_Amount=("PAID", "sum")
      )
      .reset_index()
)
