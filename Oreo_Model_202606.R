##############################################################################################################################
# Oreo Submodel — Main Model
# Covers all MDC categories except behavioral health, dental, pain, and other.
#

##############################################################################################################################

library(dplyr)
library(data.table)
library(tidyr)
library(readr)
library(stringr)

##############################################################################################################################
# SECTION 1: FILE PATHS — update each run
##############################################################################################################################
path_claims_4m_query <- setDT(dbGetQuery(con, "SELECT *
FROM   iris.iris_table_migration_all
HAVING
(RIGHT(Date_of_Service, 4) IN ('2026') AND LEFT(Date_of_Service, 2) IN ('01'))
OR (RIGHT(Date_of_Service, 4) IN ('2026') AND LEFT(Date_of_Service, 2) IN ('02'))
    OR (RIGHT(Date_of_Service, 4) IN ('2026') AND LEFT(Date_of_Service, 2) IN ('03'))
    OR (RIGHT(Date_of_Service, 4) IN ('2026') AND LEFT(Date_of_Service, 2) IN ('04'))"))

### this has to be 180 days from the day you run 
PATH_PA_RESULTS <- setDT(dbGetQuery(con, "select distinct  r.request_id,  r.cst_request_dtm::date as request_load,
                CASE WHEN LENGTH(m.person_id) = 36
         THEN m.person_id
     ELSE REPLACE(
             SUBSTRING(CAST(
                               aes_decrypt(
                                       COALESCE(SUBSTRING(m.person_id, 45), ''), -- Handle NULLs
                                       COALESCE(c.enc_key, ''),
                                       COALESCE(SUBSTRING(m.person_id, 13, 32), '')
                               ) AS VARCHAR),
                       15, 55), '&#45;', '-')
    END AS person_id,

       m.first_nm as First_Name, m.last_nm as Last_Name,

                m.emo_unique_id,  c.corporate_id, c.org_channel, c.org_external_nm,  max(rdtm.cst_request_first_contact_dtm::date) as first_contact_dt, max(rdtm.cst_request_last_contact_dtm::date) as last_contact_date,  r.contact_made_flg, r.transfer_type,
                 m.current_elig_status,  mc.elig_mismatch_flg, m.dependent_type,
                      MAX(case when r.mbr_disassociated_at_request_flg = 'true' then 1 else 0 end) as mbr_disassociated_at_request,
                max(r.oreo_risk_detail) as oreo_risk_detail,
                r.status, max(r.caller_user_nm) as caller_user_nm,
                     max(r.nurse_user_nm) as nurse_user_nm,
                   MAX(case when r.nurse_user_id is not null
           OR CASE WHEN rna.assign_user_role IN ('mtm','careteam_superuser') then rna.cst_assigned_dtm::date end is not null
                    then 1 else 0 end) as nurse_ind,
    r.is_reach_flg,
    mc.elig_mismatch_flg



from edw.request r
left join edw.request_dtm_tracker rdtm on rdtm.request_id = r.request_id
left join edw.member m on m.emo_unique_id = r.emo_unique_id
left join edw.corporate c on c.corporate_id = r.corporate_id
left join edw.member_corp_data mc on mc.emo_unique_id = r.emo_unique_id
left join emo_edw.edw.request_schedule sched on sched.request_id = r.request_id
 left join emo_edw.edw.request_service svc on svc.request_id = r.request_id
left join emo_edw.edw.request_consult con on svc.svc_id = con.svc_id
left join emo_edw.edw.request_note_assign rna on rna.request_id = r.request_id
left join emo_edw.edw.request_cost_saving rcs on rcs.svc_id = con.svc_id  and rcs.svc_nm='consult'
where r.cst_request_dtm::date  >= '2026-01-01'
group by r.request_id, r.cst_request_dtm, r.is_reach_flg, r.transfer_type,
c.enc_key,  m.first_nm, m.last_nm, r.contact_made_flg, m.activation_status, m.emo_unique_id, 
m.person_id,  mc.elig_mismatch_flg, m.dependent_type, m.current_elig_status, c.reach_paused_flg, 
                      c.org_channel, c.reach_enabled_flg, r.status, r.nurse_user_nm, r.mbr_disassociated_at_request_flg, c.corporate_id, c.org_external_nm;"))


PATH_CLAIMS_4M       <- "~/path/to/may_oreo2026.csv"   # 4-month file — the only claims file you upload
PATH_REMOVED_ICD     <- "~/path/to/removed_icd_codes_new.csv"
PATH_REMOVED_CPT     <- "~/path/to/removed_cpt_codes.csv"
PATH_HC_CPT          <- "~/path/to/hc_cpts.csv"
PATH_PT_CPT          <- "~/path/to/pt_cpt.csv"
PATH_MRI_CPT         <- "~/path/to/mri_cpt.csv"
PATH_GI_CPT          <- "~/path/to/GI_cpt_endoscopy.csv"
PATH_ICD_LOOKUP      <- "~/path/to/lookup_icdcm.csv"
PATH_CPT_LOOKUP      <- "~/path/to/lookup_cpt.csv"
PATH_PRELIM_PROC     <- "~/path/to/prelim_pointsv2.csv"
PATH_NEW_PRELIM_PROC <- "~/path/to/new_prelim_procedures_codes.csv"
PATH_PROC_DESC       <- "~/path/to/Proc_Descriptions.csv"
PATH_ONC_PROC_PTS    <- "~/path/to/oncology_procedure_points.csv"
PATH_ONC_AFTER       <- "~/path/to/Procedures_Oncology_after.csv"
PATH_PROSTATE_PTS    <- "~/path/to/prostate_points.csv"
PATH_PROSTATE_TREAT  <- "~/path/to/Prostate_Treatment.csv"
PATH_PROSTATE_DIAG   <- "~/path/to/prostate_diagnosis.csv"
PATH_MDC_ID          <- "~/path/to/mdc_id_names.csv"
PATH_PAST_RESULTS    <- "~/path/to/direct_oreo_past_results2026mdc.csv"
PATH_PA_RESULTS      <- "~/path/to/Prior_Auth_05272026.csv"

PATH_OUT_MAIN        <- "~/path/to/oreo_202605_may_final_with_amazon.csv"
PATH_OUT_PAST_UPDATE <- "~/path/to/direct_oreo_past_results2026mdc_updated.csv"
PATH_OUT_STATS       <- "~/path/to/oreo_combined_all.csv"

# Date window — update each run
THREE_MONTHS <- "2026-02-01"
ONE_MONTH    <- "2026-04-01"
END_DOS      <- "2026-04-30"

##############################################################################################################################
# SECTION 2: EXCLUSION LISTS
##############################################################################################################################

SUBCOMPANY_DROPS <- c(
  "ACCENTURE LLP", "AECOM", "Aecom", "JABIL INC.", "ATHENAHEALTH, INC.",
  "MICHAELS STORES, INC.", "Cooper", "Fort Dodge Community School District",
  "APRIA HEALTHCARE GROUP, LLC.", "NAPA MANAGEMENT SERVICES CORPORATION",
  "HEART CENTERED COUNSELING, P.C.", "Denso", "Faurecia", "Marquette University",
  "AMICA MUTUAL INSURANCE COMPANY",
  "CHECK!! MANITOWOC PUBLIC SCHOOL DISTRICT", "CHECK!! ROGERS MEMORIAL HOSPITAL INC",
  "CHECK!! AMERITAS HOLDING COMPANY", "CHECK!! CITY OF OSHKOSH",
  "CHECK!! ELLSWORTH CORPORATION", "CHECK!! MEAD AND HUNT, INC.",
  "CHECK!! AMEREQUIP, LLC", "CHECK!! JOHN A. BIEWER COMPANY, INC.",
  "CHECK!! JACK WALTERS & SONS, CORP", "CHECK!! MIDWEST COMMUNICATIONS INC - WAUSAU",
  "CHECK!! AHEPA SENIOR LIVING", "CHECK!! WEST BEND JOINT SCHOOL DISTRICT #1",
  "CHECK!! COMMSCOPE, INC. OF NORTH CAROLINA", "CHECK!! CITY OF GREEN BAY",
  "CHECK!! WAGO CORPORATION", "CHECK!! TBC CORPORATION", "CHECK!! ATC MANAGEMENT INC",
  "CHECK!! REMINGTON LODGING & HOSPITALITY, LL", "CHECK!! REA MAGNET WIRE COMPANY, INC.",
  "CHECK!! COMMSCOPE NORTH CAROLINA, LLC", "CHECK!! NICOLET AREA TECHNICAL COLLEGE",
  "CHECK!! FHG, INC.", "CHECK!! ONEIDA NATION\r", "CHECK!! KBP BRANDS, LLC",
  "CHECK!! DERSE, INC.", "CHECK!! CYIENT, INC.",
  "CHECK!! IMPROVING CORPORATE SERVICES LLC", "CHECK!! VISTANCE NETWORKS, INC.",
  "CHECK!! LARIMER COUNTY", "CHECK!! REMINGTON HOTELS LLC",
  "CHECK!! ASHFORD HOSPITALITY ADVISORS LLC"
)

DATASOURCE_DROPS <- c(
  "GKN Auto", "Grainger - BCBS", "Grainger - UHC", "Rexel",
  "Amazon - Cigna", "Hyatt - BCBS", "Perdoceo", "USLBM", "Albertsons"
)

MDC_DROPS <- c(
  "Hepatobiliary/Pancreas", "Men's Health", "Nutrition",
  "Renal", "Toxicology", "Infectious Disease"
)

CHIRO_CODES <- c("98940", "98941", "98942", "98943")

SPINE_CODES <- c(
  "M4710","M4711","M4712","M4713","M4714","M4715","M4716",
  "M4720","M4721","M4722","M4723","M4724","M4725","M4726","M4727","M4728",
  "M47811","M47812","M47813","M47814","M47815","M47816","M47817","M47818","M47819",
  "M47891","M47892","M47893","M47894","M47895","M47896","M47897","M47898","M47899",
  "M479"
)

##############################################################################################################################
# SECTION 3: SHARED HELPER FUNCTIONS
##############################################################################################################################

#' Remove duplicate values from a comma-separated string
remove_dup <- function(x) {
  paste(unique(strsplit(x, ",")[[1]]), collapse = ",")
}

#' Build a member-level composite ID
make_member_id <- function(df) {
  # Col 4 is the original numeric 2nd_MD_ID from the CSV — already renamed to
  # fake_id before this function is called. We build a new character 2nd_MD_ID here.
  df %>%
    mutate(`2nd_MD_ID` = toupper(paste(First_Name, Last_Name, DOB, Data_Source, sep = "")))
}

#' Cast key ID columns to character to avoid type conflicts
cast_id_cols <- function(df) {
  df %>%
    mutate(
      Parent_ID      = as.character(Parent_ID),
      Client_ID      = as.character(Client_ID),
      Subscriber_Zip = as.character(Subscriber_Zip),
      PhoneNumber    = as.character(PhoneNumber)
    )
}

#' Assign Risk_Level and Probability based on visit-count percentiles
assign_risk <- function(df, id_col = "2nd_MD_ID") {
  visit_counts     <- table(df[[id_col]])
  high_ids   <- names(visit_counts[visit_counts >= quantile(visit_counts, 0.9)])
  medium_ids <- names(visit_counts[visit_counts >= quantile(visit_counts, 0.7) &
                                     visit_counts < quantile(visit_counts, 0.9)])
  df %>%
    mutate(
      Risk_Level  = case_when(
        .data[[id_col]] %in% high_ids   ~ "High",
        .data[[id_col]] %in% medium_ids ~ "Medium",
        TRUE                            ~ "Low"
      ),
      Probability = case_when(
        Risk_Level == "High"   ~ "90%",
        Risk_Level == "Medium" ~ "50%",
        TRUE                   ~ "10%"
      )
    )
}

#' Join ICD and CPT description lookups, combine MDC labels per member, fill NAs
oreo_filtering <- function(df, icd_lookup, cpt_lookup) {
  icd_map <- setNames(icd_lookup$description, icd_lookup$icd_cm)
  cpt_map <- setNames(cpt_lookup$long_description, cpt_lookup$cpt_code_new)

  df <- df %>%
    assign_risk() %>%
    mutate(
      ICD_1_desc = icd_map[ICD_1],
      ICD_2_desc = icd_map[ICD_2],
      ICD_3_desc = icd_map[ICD_3],
      CPT_1_desc = cpt_map[CPT_1],
      CPT_2_desc = cpt_map[CPT_2],
      CPT_3_desc = cpt_map[CPT_3],
      CPT_desc   = paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = ";")
    )

  df <- cast_id_cols(df)
  df[is.na(df)] <- ""

  # Concatenate and deduplicate MDC values per member
  df <- df %>%
    group_by(`2nd_MD_ID`, MDC) %>%
    mutate(MDC_Comb = remove_dup(paste(MDC, collapse = ","))) %>%
    ungroup() %>%
    select(-MDC) %>%
    rename(MDC = MDC_Comb)

  df
}

#' Apply standard company/data-source exclusions
apply_exclusions <- function(df) {
  df %>%
    filter(!Subcompany %in% SUBCOMPANY_DROPS) %>%
    filter(!Data_Source %in% DATASOURCE_DROPS) %>%
    filter(!(Data_Source == "JBS" & Subcompany %in% c("T","M","C","P")))
}

#' Core MSK filter used by every company group
#' Excludes high-cost CPT members, applies chiro date-count adjustment,
#' combines 3-month and 1-month windows.
build_msk <- function(df, hc_cpt, three_months, one_month, end_dos,
                       threshold_3m = 8, threshold_1m = 4) {
  msk_icd <- expression(
    (ICD_1 >= "M00" & ICD_1 <= "M99") | (ICD_1 >= "S00" & ICD_1 < "T150") |
    (ICD_1 >= "T84" & ICD_1 < "T86")  | (ICD_1 >= "R25" & ICD_1 < "R30")  |
    (ICD_2 >= "M00" & ICD_2 <= "M99") | (ICD_2 >= "S00" & ICD_2 < "T150") |
    (ICD_2 >= "T84" & ICD_2 < "T86")  | (ICD_2 >= "R25" & ICD_2 < "R30")  |
    (ICD_3 >= "M00" & ICD_3 <= "M99") | (ICD_3 >= "S00" & ICD_3 < "T150") |
    (ICD_3 >= "T84" & ICD_3 < "T86")  | (ICD_3 >= "R25" & ICD_3 < "R30")
  )

  # Remove members with high-cost CPT codes
  df_clean <- df %>%
    group_by(`2nd_MD_ID`) %>%
    filter(
      !(any(CPT_1 %in% hc_cpt)) | any(CPT_2 %in% hc_cpt) | any(CPT_3 %in% hc_cpt)
    ) %>%
    ungroup()

  # Helper: count unique dates per member, apply chiro adjustment, apply threshold
  filter_msk_window <- function(data, date_min, threshold) {
    base <- data %>%
      filter(eval(msk_icd)) %>%
      filter(Date_of_Service >= as.Date(date_min) & Date_of_Service <= as.Date(end_dos))

    date_counts <- setDT(base)[, .(Date_Count = uniqueN(Date_of_Service)), by = .(`2nd_MD_ID`)]
    base <- merge(setDT(base), date_counts, by = "2nd_MD_ID", all = TRUE)

    chiro_ids <- base %>%
      filter(CPT_1 %in% CHIRO_CODES | CPT_2 %in% CHIRO_CODES | CPT_3 %in% CHIRO_CODES) %>%
      pull(`2nd_MD_ID`) %>%
      unique()

    base %>%
      mutate(Date_Count = ifelse(`2nd_MD_ID` %in% chiro_ids, Date_Count / 10, Date_Count)) %>%
      group_by(`2nd_MD_ID`) %>%
      filter(Date_Count >= threshold) %>%
      ungroup() %>%
      mutate(MDC = "MSK") %>%
      select(-Date_Count)
  }

  msk_3m <- filter_msk_window(df_clean, three_months, threshold_3m)
  msk_1m <- filter_msk_window(df_clean, one_month, threshold_1m)

  # Combine: prefer 3-month window; add 1-month-only members
  ids_3m <- unique(msk_3m$`2nd_MD_ID`)
  msk_final <- rbind(msk_3m, msk_1m[!msk_1m$`2nd_MD_ID` %in% ids_3m, ])
  msk_final$MDC <- "MSK"
  msk_final
}

#' Generic MDC builder for conditions using a simple distinct-date-count threshold.
#' Optionally removes members with high-cost CPT codes first.
build_mdc <- function(df, icd_filter_fn, mdc_label,
                       three_months, one_month, end_dos,
                       threshold_3m = 8, threshold_1m = 4,
                       hc_cpt = NULL) {
  df_clean <- df
  if (!is.null(hc_cpt)) {
    df_clean <- df %>%
      group_by(`2nd_MD_ID`) %>%
      filter(!(any(CPT_1 %in% hc_cpt)) | any(CPT_2 %in% hc_cpt) | any(CPT_3 %in% hc_cpt)) %>%
      ungroup()
  }

  filter_window <- function(data, date_min, threshold) {
    icd_filter_fn(data) %>%
      filter(Date_of_Service >= as.Date(date_min) & Date_of_Service <= as.Date(end_dos)) %>%
      group_by(`2nd_MD_ID`) %>%
      filter(n_distinct(Date_of_Service) >= threshold) %>%
      ungroup()
  }

  result_3m  <- filter_window(df_clean, three_months, threshold_3m)
  result_1m  <- filter_window(df_clean, one_month,    threshold_1m)
  ids_3m     <- unique(result_3m$`2nd_MD_ID`)

  rbind(result_3m, result_1m[!result_1m$`2nd_MD_ID` %in% ids_3m, ]) %>%
    mutate(MDC = mdc_label)
}

#' De-duplicate combined pilot data by keeping the highest-priority pilot per member.
dedup_by_rank <- function(df, rank_map) {
  df %>%
    mutate(rank = rank_map[pilot]) %>%
    group_by(`2nd_MD_ID`) %>%
    filter(rank == min(rank)) %>%
    ungroup()
}

##############################################################################################################################
# SECTION 4: ICD FILTER FUNCTIONS
##############################################################################################################################

icd_oncology <- function(df) df %>% filter(
  (ICD_1 >= "C00" & ICD_1 < "D50") | (ICD_1 >= "Z80" & ICD_1 < "Z81") | (ICD_1 >= "Z85" & ICD_1 < "Z86") |
  (ICD_2 >= "C00" & ICD_2 < "D50") | (ICD_2 >= "Z80" & ICD_2 < "Z81") | (ICD_2 >= "Z85" & ICD_2 < "Z86") |
  (ICD_3 >= "C00" & ICD_3 < "D50") | (ICD_3 >= "Z80" & ICD_3 < "Z81") | (ICD_3 >= "Z85" & ICD_3 < "Z86")
)

# BUG FIX: ICD_2 >= 'R00' & ICD_1 < 'R10' was a copy-paste error — corrected to ICD_2
icd_cardio <- function(df) df %>% filter(
  (ICD_1 >= "I00" & ICD_1 <= "I99") | (ICD_1 >= "R00" & ICD_1 < "R10") | (ICD_1 >= "Z950" & ICD_1 < "Z960") | (ICD_1 >= "T8201" & ICD_1 < "T8300") |
  (ICD_2 >= "I00" & ICD_2 <= "I99") | (ICD_2 >= "R00" & ICD_2 < "R10") | (ICD_2 >= "Z950" & ICD_2 < "Z960") | (ICD_2 >= "T8201" & ICD_2 < "T8300") |
  (ICD_3 >= "I00" & ICD_3 <= "I99") | (ICD_3 >= "R00" & ICD_3 < "R10") | (ICD_3 >= "Z950" & ICD_3 < "Z960") | (ICD_3 >= "T8201" & ICD_3 < "T8300")
)

icd_gi <- function(df) df %>% filter(
  (ICD_1 >= "K20" & ICD_1 < "K69") | (ICD_1 >= "K90" & ICD_1 < "K96") | (ICD_1 >= "R10" & ICD_1 < "R20") | (ICD_1 >= "Z980" & ICD_1 < "Z981") | (ICD_1 >= "Z9884" & ICD_1 < "Z9885") |
  (ICD_2 >= "K20" & ICD_2 < "K69") | (ICD_2 >= "K90" & ICD_2 < "K96") | (ICD_2 >= "R10" & ICD_2 < "R20") | (ICD_2 >= "Z980" & ICD_2 < "Z981") | (ICD_2 >= "Z9884" & ICD_2 < "Z9885") |
  (ICD_3 >= "K20" & ICD_3 < "K69") | (ICD_3 >= "K90" & ICD_3 < "K96") | (ICD_3 >= "R10" & ICD_3 < "R20") | (ICD_3 >= "Z980" & ICD_3 < "Z981") | (ICD_3 >= "Z9884" & ICD_3 < "Z9885")
)

icd_womens_health <- function(df) df %>% filter(
  (ICD_1 >= "N60" & ICD_1 <= "N99") | (ICD_1 >= "N992" & ICD_1 <= "N999") |
  (ICD_2 >= "N60" & ICD_2 <= "N99") | (ICD_2 >= "N992" & ICD_2 <= "N999") |
  (ICD_3 >= "N60" & ICD_3 <= "N99") | (ICD_3 >= "N992" & ICD_3 <= "N999")
)

icd_id <- function(df) df %>% filter(
  (ICD_1 >= "A00" & ICD_1 <= "B99") | (ICD_2 >= "A00" & ICD_2 <= "B99") | (ICD_3 >= "A00" & ICD_3 <= "B99")
)

icd_hematology <- function(df) df %>% filter(
  (ICD_1 >= "D50" & ICD_1 < "D683") | (ICD_1 >= "D684" & ICD_1 < "D898") | (ICD_1 >= "Z67" & ICD_1 < "Z68") |
  (ICD_2 >= "D50" & ICD_2 < "D683") | (ICD_2 >= "D684" & ICD_2 < "D898") | (ICD_2 >= "Z67" & ICD_2 < "Z68") |
  (ICD_3 >= "D50" & ICD_3 < "D683") | (ICD_3 >= "D684" & ICD_3 < "D898") | (ICD_3 >= "Z67" & ICD_3 < "Z68")
)

icd_endocrine <- function(df) df %>% filter(
  (ICD_1 >= "E00" & ICD_1 < "E06") | (ICD_1 >= "E07" & ICD_1 < "E37") |
  (ICD_2 >= "E00" & ICD_2 < "E06") | (ICD_2 >= "E07" & ICD_2 < "E37") |
  (ICD_3 >= "E00" & ICD_3 < "E06") | (ICD_3 >= "E07" & ICD_3 < "E37")
)

icd_autoimmune <- function(df) df %>% filter(
  (ICD_1 >= "E063" & ICD_1 < "E064") | (ICD_1 >= "D683" & ICD_1 < "D684") | (ICD_1 >= "D898" & ICD_1 < "D899") | (ICD_1 >= "M359" & ICD_1 < "M360") |
  (ICD_2 >= "E063" & ICD_2 < "E064") | (ICD_2 >= "D683" & ICD_2 < "D684") | (ICD_2 >= "D898" & ICD_2 < "D899") | (ICD_2 >= "M359" & ICD_2 < "M360") |
  (ICD_3 >= "E063" & ICD_3 < "E064") | (ICD_3 >= "D683" & ICD_3 < "D684") | (ICD_3 >= "D898" & ICD_3 < "D899") | (ICD_3 >= "M359" & ICD_3 < "M360")
)

icd_nutrition <- function(df) df %>% filter(
  (ICD_1 >= "E40" & ICD_1 < "E90") | (ICD_2 >= "E40" & ICD_2 < "E90") | (ICD_3 >= "E40" & ICD_3 < "E90")
)

icd_nervous_system <- function(df) df %>% filter(
  (ICD_1 >= "G00" & ICD_1 < "G84") | (ICD_1 >= "G90" & ICD_1 <= "G99") | (ICD_1 >= "R25" & ICD_1 < "R28") |
  (ICD_2 >= "G00" & ICD_2 < "G84") | (ICD_2 >= "G90" & ICD_2 <= "G99") | (ICD_2 >= "R25" & ICD_2 < "R28") |
  (ICD_3 >= "G00" & ICD_3 < "G84") | (ICD_3 >= "G90" & ICD_3 <= "G99") | (ICD_3 >= "R25" & ICD_3 < "R28")
)

icd_ophthalmology <- function(df) df %>% filter(
  (ICD_1 >= "H00" & ICD_1 < "H60") | (ICD_2 >= "H00" & ICD_2 < "H60") | (ICD_3 >= "H00" & ICD_3 < "H60")
)

icd_ent <- function(df) df %>% filter(
  (ICD_1 >= "H60" & ICD_1 < "H96") | (ICD_2 >= "H60" & ICD_2 < "H96") | (ICD_3 >= "H60" & ICD_3 < "H96")
)

icd_pulmonary <- function(df) df %>% filter(
  (ICD_1 >= "J00" & ICD_1 <= "J99") | (ICD_1 >= "R04" & ICD_1 < "R10") |
  (ICD_2 >= "J00" & ICD_2 <= "J99") | (ICD_2 >= "R04" & ICD_2 < "R10") |
  (ICD_3 >= "J00" & ICD_3 <= "J99") | (ICD_3 >= "R04" & ICD_3 < "R10")
)

icd_hepatobiliary <- function(df) df %>% filter(
  (ICD_1 >= "K70" & ICD_1 < "K78") | (ICD_1 >= "K80" & ICD_1 < "K88") |
  (ICD_2 >= "K70" & ICD_2 < "K78") | (ICD_2 >= "K80" & ICD_2 < "K88") |
  (ICD_3 >= "K70" & ICD_3 < "K78") | (ICD_3 >= "K80" & ICD_3 < "K88")
)

icd_integumentary <- function(df) df %>% filter(
  (ICD_1 >= "L00" & ICD_1 <= "L99") | (ICD_1 >= "R20" & ICD_1 < "R24") |
  (ICD_2 >= "L00" & ICD_2 <= "L99") | (ICD_2 >= "R20" & ICD_2 < "R24") |
  (ICD_3 >= "L00" & ICD_3 <= "L99") | (ICD_3 >= "R20" & ICD_3 < "R24")
)

icd_renal <- function(df) df %>% filter(
  (ICD_1 >= "N00" & ICD_1 < "N23") | (ICD_2 >= "N00" & ICD_2 < "N23") | (ICD_3 >= "N00" & ICD_3 < "N23")
)

icd_urology <- function(df) df %>% filter(
  (ICD_1 >= "N25" & ICD_1 < "N40") | (ICD_1 >= "R30" & ICD_1 < "R40") | (ICD_1 >= "Z93" & ICD_1 < "Z94") |
  (ICD_2 >= "N25" & ICD_2 < "N40") | (ICD_2 >= "R30" & ICD_2 < "R40") | (ICD_2 >= "Z93" & ICD_2 < "Z94") |
  (ICD_3 >= "N25" & ICD_3 < "N40") | (ICD_3 >= "R30" & ICD_3 < "R40") | (ICD_3 >= "Z93" & ICD_3 < "Z94")
)

icd_mens_health <- function(df) df %>% filter(
  (ICD_1 >= "N40" & ICD_1 < "N54") | (ICD_1 >= "N991" & ICD_1 < "N992") | (ICD_1 >= "Z9079" & ICD_1 < "Z9080") |
  (ICD_2 >= "N40" & ICD_2 < "N54") | (ICD_2 >= "N991" & ICD_2 < "N992") | (ICD_2 >= "Z9079" & ICD_2 < "Z9080") |
  (ICD_3 >= "N40" & ICD_3 < "N54") | (ICD_3 >= "N991" & ICD_3 < "N992") | (ICD_3 >= "Z9079" & ICD_3 < "Z9080")
)

icd_neonatology <- function(df) df %>% filter(
  (ICD_1 >= "P00" & ICD_1 < "P97") | (ICD_1 >= "Q00" & ICD_1 <= "Q99") |
  (ICD_2 >= "P00" & ICD_2 < "P97") | (ICD_2 >= "Q00" & ICD_2 <= "Q99") |
  (ICD_3 >= "P00" & ICD_3 < "P97") | (ICD_3 >= "Q00" & ICD_3 <= "Q99")
)

icd_toxicology <- function(df) df %>% filter(
  (ICD_1 >= "T20" & ICD_1 < "T82") | (ICD_1 >= "T83" & ICD_1 < "T89") |
  (ICD_2 >= "T20" & ICD_2 < "T82") | (ICD_2 >= "T83" & ICD_2 < "T89") |
  (ICD_3 >= "T20" & ICD_3 < "T82") | (ICD_3 >= "T83" & ICD_3 < "T89")
)

##############################################################################################################################
# SECTION 5: LOAD DATA
##############################################################################################################################

# Load the 4-month file once — input_file_3 is the full 4-month dataset used by the
# points model. input_file_2 is simply input_file_3 filtered to the 3-month window
# used by the MDC visit-count filters. No need to upload two separate files.
input_file_3 <- read_csv(PATH_CLAIMS_4M) %>%
  mutate(Date_of_Service = as.Date(Date_of_Service, "%m/%d/%Y"))

# Rename col 4 (numeric 2nd_MD_ID from CSV) to fake_id, then build character 2nd_MD_ID
colnames(input_file_3)[4] <- "fake_id"
input_file_3 <- make_member_id(input_file_3)

removed_icd <- read_csv(PATH_REMOVED_ICD)
removed_cpt <- read_csv(PATH_REMOVED_CPT)
hc_cpt      <- read_csv(PATH_HC_CPT)
icd_lookup  <- read.csv(PATH_ICD_LOOKUP, stringsAsFactors = FALSE)
cpt_lookup  <- read.csv(PATH_CPT_LOOKUP, stringsAsFactors = FALSE)
pt_cpt      <- read.csv(PATH_PT_CPT)
mri_cpt     <- read.csv(PATH_MRI_CPT)

# Apply removed code exclusions to the full 4-month dataset
input_file_3 <- input_file_3 %>%
  filter(!((ICD_1 %in% removed_icd$icd_1) | (ICD_2 %in% removed_icd$icd_1) | (ICD_3 %in% removed_icd$icd_1))) %>%
  filter(!((CPT_1 %in% removed_cpt$cpt_1) | (CPT_2 %in% removed_cpt$cpt_1) | (CPT_3 %in% removed_cpt$cpt_1)))

# Derive the 3-month window dataset from input_file_3 — no second upload needed
input_file_2 <- input_file_3 %>%
  filter(Date_of_Service >= as.Date(THREE_MONTHS) & Date_of_Service <= as.Date(END_DOS))

oreo_past_results <- read_csv(PATH_PAST_RESULTS)
pa_past_results   <- read_csv(PATH_PA_RESULTS) %>%
  # BUG FIX: original referenced undefined 'pa_results' — corrected to 'pa_past_results'
  mutate(member_name = toupper(paste(first_name, last_name, sep = " ")))

##############################################################################################################################
# SECTION 6: COMPANY GROUP FILTER FUNCTIONS
##############################################################################################################################

# Each function filters to its company group and runs the relevant MDCs.
# All follow the same pattern: filter source → call build_mdc()/build_msk() → bind results.

msk_only_filter <- function(df) {
  df_in <- df[df$Data_Source %in% "Carters", ]
  build_msk(df_in, hc_cpt$msk_cpt, THREE_MONTHS, ONE_MONTH, END_DOS)
}

five_only_filter <- function(df) {
  df_in <- df[df$Data_Source %in% c("Cambia","MeritainHealth","Sana Benefits","Wellmark"), ]
  bind_rows(
    build_mdc(df_in, icd_oncology,      "Oncology",        THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_cardio,        "Cardio",          THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt),
    build_mdc(df_in, icd_gi,            "GI",              THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_womens_health, "Women's Health",  THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt)
  )
}

all_mdcs_filter <- function(df) {
  df_in <- df[df$Data_Source %in% c(
    "Ahlstrom","Anywhere Real Estate","BSRA","BCBSM Resell","BCBSM Resell - NB",
    "BCBSMWMHIP","Blount County","BCBSNE","CareFirst","Casella","Danone - Cigna",
    "EDH","Envision","GKN Aero","GKN PM","Global Payments","Guardian - Cigna",
    "Guardian - Centivo","Halliburton","HCSC - Aon","Heidelberg","Husqvarna","GrumaLuminaire"
  ), ]
  bind_rows(
    build_mdc(df_in, icd_id,            "Infectious Disease",       THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_oncology,      "Oncology",                 THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_hematology,    "Hematology",               THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_endocrine,     "Endocrine",                THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$endo_cpt),
    build_mdc(df_in, icd_autoimmune,    "Autoimmune",               THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_nutrition,     "Nutrition",                THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_nervous_system,"Nervous System",           THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_ophthalmology, "Ophthalmology",            THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_ent,           "Ear Nose and Throat",      THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$ento_cpt),
    build_mdc(df_in, icd_cardio,        "Cardio",                   THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt),
    build_mdc(df_in, icd_pulmonary,     "Pulmonary",                THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_gi,            "GI",                       THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt),
    build_mdc(df_in, icd_hepatobiliary, "Hepatobiliary/Pancreas",   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_integumentary, "Integumentary",            THREE_MONTHS, ONE_MONTH, END_DOS),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_renal,         "Renal",                    THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_urology,       "Urology",                  THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$urology_cpt),
    build_mdc(df_in, icd_mens_health,   "Men's Health",             THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$mh_cpt),
    build_mdc(df_in, icd_womens_health, "Women's Health",           THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt),
    build_mdc(df_in, icd_neonatology,   "Neonatology",              THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_toxicology,    "Toxicology",               THREE_MONTHS, ONE_MONTH, END_DOS)
  )
}

all_mdcs_part2_filter <- function(df) {
  df_in <- df[df$Data_Source %in% c(
    "HPE - Surest","HPE - Anthem","Caterpillar - Luminaire","Caterpillar - HCSC",
    "Jadex","JBS","JLL","Kirby","Koch","Koch Guardian","Koch Industries","Koch Infor",
    "Health at Home","Koch Molex","Michaels","Larimer","Logitech","NewellBrands",
    "NTN","NVA","Nissan - UHC","Owens Corning","Omnicom - Anthem","Omnicom - Cigna",
    "Shamrock","Shamrock Trading Corporat","TrueManufacturing","Toyota",
    "Sonic","TAMU","UGN","UMR","Waste Management"
  ), ]
  # Same full MDC set as all_mdcs_filter
  all_mdcs_filter(df_in %>% mutate(Data_Source = Data_Source))  # reuse via temp rename trick avoided — just duplicate call:
  bind_rows(
    build_mdc(df_in, icd_id,            "Infectious Disease",       THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_oncology,      "Oncology",                 THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_hematology,    "Hematology",               THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_endocrine,     "Endocrine",                THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$endo_cpt),
    build_mdc(df_in, icd_autoimmune,    "Autoimmune",               THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_nutrition,     "Nutrition",                THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_nervous_system,"Nervous System",           THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_ophthalmology, "Ophthalmology",            THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_ent,           "Ear Nose and Throat",      THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$ento_cpt),
    build_mdc(df_in, icd_cardio,        "Cardio",                   THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt),
    build_mdc(df_in, icd_pulmonary,     "Pulmonary",                THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_gi,            "GI",                       THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt),
    build_mdc(df_in, icd_hepatobiliary, "Hepatobiliary/Pancreas",   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_integumentary, "Integumentary",            THREE_MONTHS, ONE_MONTH, END_DOS),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_renal,         "Renal",                    THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_urology,       "Urology",                  THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$urology_cpt),
    build_mdc(df_in, icd_mens_health,   "Men's Health",             THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$mh_cpt),
    build_mdc(df_in, icd_womens_health, "Women's Health",           THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt),
    build_mdc(df_in, icd_neonatology,   "Neonatology",              THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_toxicology,    "Toxicology",               THREE_MONTHS, ONE_MONTH, END_DOS)
  )
}

aetna_filter <- function(df) {
  excluded <- c(
    "ACCENTURE LLP","ATHENAHEALTH, INC.","APRIA HEALTHCARE GROUP, LLC.","AECOM",
    "DELAWARE COUNTY PROFESSIONAL SERVICES, I","Faurecia","AON CORPORATION","ASURION",
    "CARMEL PSYCHOLOGICAL ASSOCIATES, P.C.","FAURECIA USA HOLDINGS, INC.",
    "CIRCLE K STORES, INC","DARDEN RESTAURANTS, INC.","FTI CONSULTING, INC.",
    "GTT AMERICAS, LLC","GUARDIAN LIFE INSURANCE COMPANY","HEART CENTERED COUNSELING, P.C.",
    "HORIZON THERAPEUTICS USA, INC","LIFESTANCE HEALTH, INC.","JABIL INC.",
    "MICHAELS STORES, INC.","NAPA MANAGEMENT SERVICES CORPORATION","QINETIQ, INC.",
    "RELX INC.","RICH PRODUCTS CORPORATION","SUNGARD AVAILABILITY SERVICES, LP.",
    "TRANSAMERICA CORPORATION","Envista","Veralto"
  )
  df_in <- df[df$Data_Source == "Aetna" & !df$Subcompany %in% excluded, ]
  bind_rows(
    build_mdc(df_in, icd_oncology,      "Oncology",            THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_autoimmune,    "Autoimmune",          THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_nervous_system,"Nervous System",      THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_ent,           "Ear Nose and Throat", THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$ento_cpt),
    build_mdc(df_in, icd_cardio,        "Cardio",              THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt),
    build_mdc(df_in, icd_gi,            "GI",                  THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt),
    build_mdc(df_in, icd_integumentary, "Integumentary",       THREE_MONTHS, ONE_MONTH, END_DOS),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_urology,       "Urology",             THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$urology_cpt),
    build_mdc(df_in, icd_womens_health, "Women's Health",      THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt)
  )
}

aon_five_filter <- function(df) {
  df_in <- df[df$Data_Source %in% c("Rich Products","Rich"), ]
  bind_rows(
    build_mdc(df_in, icd_oncology,      "Oncology",        THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_cardio,        "Cardio",          THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt),
    build_mdc(df_in, icd_gi,            "GI",              THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS),
    build_mdc(df_in, icd_womens_health, "Women's Health",  THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt)
  )
}

aon_exchange_filter <- function(df) {
  included <- c(
    "AECOM","AON CORPORATION","ASURION","Aecom","Aon","Asurion","Darden","FTI",
    "FTI CONSULTING, INC.","DARDEN RESTAURANTS, INC.","RELX INC.","Relx",
    "Pet Smart","Veralto","DSM-FIRMENICH","KENNAMETAL INC"
  )
  df_in <- df[df$Data_Source %in% c("Aetna","Cigna","Anthem","Priority Health") &
                df$Subcompany %in% included, ]
  all_mdcs_filter(df_in)
}

plastipak_filter <- function(df) {
  df_in <- df[df$Data_Source == "Plastipak", ]
  all_mdcs_filter(df_in)
}

princeton_filter <- function(df) {
  df_in <- df[df$Data_Source %in% c("Princeton - Aetna","Princeton - UHC"), ]
  # Princeton uses lower thresholds for some MDCs (6/3 instead of 8/4)
  bind_rows(
    all_mdcs_filter(df_in),  # most MDCs at standard thresholds
    # Overrides for Oncology, Cardio, GI, MSK, Women's Health at 6/3
    build_mdc(df_in, icd_oncology,      "Oncology",       THREE_MONTHS, ONE_MONTH, END_DOS, threshold_3m = 6, threshold_1m = 3),
    build_mdc(df_in, icd_cardio,        "Cardio",         THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$cardio_cpt, threshold_3m = 6, threshold_1m = 3),
    build_mdc(df_in, icd_gi,            "GI",             THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$gi_cpt, threshold_3m = 6, threshold_1m = 3),
    build_msk(df_in, hc_cpt$msk_cpt,   THREE_MONTHS, ONE_MONTH, END_DOS, threshold_3m = 6, threshold_1m = 3),
    build_mdc(df_in, icd_womens_health, "Women's Health", THREE_MONTHS, ONE_MONTH, END_DOS, hc_cpt = hc_cpt$wh_cpt, threshold_3m = 6, threshold_1m = 3)
  )
}

##############################################################################################################################
# SECTION 7: RUN COMPANY GROUP FILTERS
##############################################################################################################################

msk_only     <- msk_only_filter(input_file_2)
five_only    <- five_only_filter(input_file_2)
all_mdcs     <- all_mdcs_filter(input_file_2)
all_mdcs_p2  <- all_mdcs_part2_filter(input_file_2)
aetna_10     <- aetna_filter(input_file_2)
aon_5        <- aon_five_filter(input_file_2)
aon_exchange <- aon_exchange_filter(input_file_2)
plastipak    <- plastipak_filter(input_file_2)
princeton    <- princeton_filter(input_file_2)

oreo_no_pilots <- bind_rows(
  msk_only, five_only, all_mdcs, all_mdcs_p2,
  aetna_10, aon_5, aon_exchange, plastipak, princeton
) %>%
  mutate(pilot = "nopilots")

##############################################################################################################################
# SECTION 8: PILOT GROUPS (MRI, PT, SPINE, GI)
##############################################################################################################################

# BUG FIX: original had pilot_data(df){ without 'function' keyword
build_pilot_data <- function(df) {
  msk_icd_expr <- quote(
    (ICD_1 >= "M00" & ICD_1 <= "M99") | (ICD_1 >= "S00" & ICD_1 < "T150") | (ICD_1 >= "T84" & ICD_1 < "T86") | (ICD_1 >= "R25" & ICD_1 < "R30") |
    (ICD_2 >= "M00" & ICD_2 <= "M99") | (ICD_2 >= "S00" & ICD_2 < "T150") | (ICD_2 >= "T84" & ICD_2 < "T86") | (ICD_2 >= "R25" & ICD_2 < "R30") |
    (ICD_3 >= "M00" & ICD_3 <= "M99") | (ICD_3 >= "S00" & ICD_3 < "T150") | (ICD_3 >= "T84" & ICD_3 < "T86") | (ICD_3 >= "R25" & ICD_3 < "R30")
  )

  msk_base <- df %>%
    group_by(`2nd_MD_ID`) %>%
    filter(!(any(CPT_1 %in% hc_cpt$msk_cpt)) | any(CPT_2 %in% hc_cpt$msk_cpt) | any(CPT_3 %in% hc_cpt$msk_cpt)) %>%
    ungroup() %>%
    filter(eval(msk_icd_expr)) %>%
    group_by(`2nd_MD_ID`) %>%
    filter(n_distinct(Date_of_Service) >= 1) %>%
    ungroup()

  msk_pilot_pt <- msk_base %>%
    filter(CPT_1 %in% pt_cpt$cpt | CPT_2 %in% pt_cpt$cpt | CPT_3 %in% pt_cpt$cpt) %>%
    group_by(`2nd_MD_ID`) %>%
    filter(n_distinct(Date_of_Service) >= 10) %>%
    ungroup()

  msk_pilot_mri <- msk_base %>%
    filter(CPT_1 %in% mri_cpt$cpt | CPT_2 %in% mri_cpt$cpt | CPT_3 %in% mri_cpt$cpt) %>%
    group_by(`2nd_MD_ID`) %>%
    filter(n_distinct(Date_of_Service) >= 1) %>%
    ungroup()

  list(mri = msk_pilot_mri, pt = msk_pilot_pt)
}

pilots        <- build_pilot_data(input_file_2)
msk_pilot_mri <- pilots$mri %>% mutate(MDC = "MSK", pilot = "MRI")
msk_pilot_pt  <- pilots$pt  %>% mutate(MDC = "MSK", pilot = "PT")

# Spine pilot
spine_members <- input_file_2 %>%
  group_by(`2nd_MD_ID`) %>%
  filter(!(any(CPT_1 %in% hc_cpt$msk_cpt)) | any(CPT_2 %in% hc_cpt$msk_cpt) | any(CPT_3 %in% hc_cpt$msk_cpt)) %>%
  ungroup()
spine_pilot <- spine_members %>%
  filter(ICD_1 %in% SPINE_CODES | ICD_2 %in% SPINE_CODES | ICD_3 %in% SPINE_CODES) %>%
  group_by(`2nd_MD_ID`) %>%
  filter(n_distinct(Date_of_Service) >= 1) %>%
  ungroup() %>%
  mutate(MDC = "MSK", pilot = "Spine")

# GI endoscopy pilot
gi_cpt_df  <- read_csv(PATH_GI_CPT)
CPT_GI_EXCL <- c("44388","45378","45330")

gi_pilot_final <- icd_gi(input_file_2) %>%
  group_by(`2nd_MD_ID`) %>%
  filter(n_distinct(Date_of_Service) >= 2) %>%
  ungroup() %>%
  filter(CPT_1 %in% gi_cpt_df$CPT | CPT_2 %in% gi_cpt_df$CPT | CPT_3 %in% gi_cpt_df$CPT) %>%
  group_by(`2nd_MD_ID`) %>%
  filter(n_distinct(Date_of_Service) >= 1) %>%
  ungroup() %>%
  filter(!(Age >= 50 & (CPT_1 %in% CPT_GI_EXCL | CPT_2 %in% CPT_GI_EXCL | CPT_3 %in% CPT_GI_EXCL))) %>%
  filter(Data_Source != "Carters") %>%
  mutate(MDC = "GI", pilot = "GI_pilot")

##############################################################################################################################
# SECTION 9: COMBINE & DEDUPLICATE
##############################################################################################################################

EXTRA_COLS <- c(
  paste0("ICD_",  4:16),
  paste0("CPT_",  4:13),
  paste0("NDC_",  1:13)
)

PILOT_RANK <- c(MRI = 1, PT = 3, Spine = 2, GI_pilot = 4, nopilots = 5)

df_combined <- bind_rows(
  oreo_no_pilots, msk_pilot_mri, msk_pilot_pt, gi_pilot_final, spine_pilot
) %>%
  select(-any_of(EXTRA_COLS))

df_deduped <- dedup_by_rank(df_combined, PILOT_RANK) %>%
  filter(!`2nd_MD_ID` %in% oreo_past_results$`2nd_MD_ID`) %>%
  mutate(member_name = toupper(paste(First_Name, Last_Name, sep = " "))) %>%
  filter(!member_name %in% pa_past_results$member_name) %>%
  cast_id_cols()

##############################################################################################################################
# SECTION 10: APPLY OREO FILTERING & BUILD NARRATIVE
##############################################################################################################################

oreo_final_v2 <- oreo_filtering(df_deduped, icd_lookup, cpt_lookup) %>%
  mutate(
    Risk_Level = case_when(
      pilot == "MRI"      ~ "MSK High - MRI",
      pilot == "PT"       ~ "MSK High - PT",
      pilot == "Spine"    ~ "MSK High - Spine",
      pilot == "GI_pilot" ~ "GI High - Endoscopy/Colonoscopy",
      TRUE                ~ Risk_Level
    ),
    Probability = case_when(
      pilot %in% c("MRI","PT","Spine","GI_pilot") ~ "90%",
      TRUE                                         ~ Probability
    )
  ) %>%
  filter(!MDC %in% MDC_DROPS)

# Build MDC-combined narrative column
oreo_final_v3 <- oreo_final_v2 %>%
  distinct(`2nd_MD_ID`, MDC, .keep_all = TRUE) %>%
  group_by(`2nd_MD_ID`) %>%
  reframe(across(everything()), MDC_Combined = paste(unique(MDC), collapse = "/")) %>%
  ungroup() %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ""))) %>%
  mutate(
    icd_combined = if_else(
      (is.na(ICD_2_desc) | ICD_2_desc == "") & (is.na(ICD_3_desc) | ICD_3_desc == ""),
      ICD_1_desc,
      str_c(ICD_1_desc, ICD_2_desc, ICD_3_desc, sep = "; ")
    ),
    cpt_description = case_when(
      pilot == "MRI"      ~ str_c(paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = "; "), " (MRI)"),
      pilot == "PT"       ~ str_c(paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = "; "), ", (Physical Therapy)"),
      pilot == "GI_pilot" ~ str_c(paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = "; "), ", (GI Endoscopy/Colonoscopy)"),
      pilot == "Spine"    ~ str_c(paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = "; "), ", (Spine)"),
      TRUE                ~ paste(CPT_1_desc, CPT_2_desc, CPT_3_desc, sep = "; ")
    ),
    mdc_new  = str_c("MDC: ", MDC_Combined),
    ICD_desc = paste(mdc_new, ". Diagnosis description: ", icd_combined,
                     ". Procedure Description: ", cpt_description, ".")
  ) %>%
  select(`2nd_MD_ID`, ICD_desc)

oreo_final_original <- oreo_final_v2 %>%
  left_join(oreo_final_v3, by = "2nd_MD_ID") %>%
  filter(!member_name %in% pa_past_results$member_name) %>%
  select(-c(rank, pilot, member_name, ICD_1_desc, ICD_2_desc, ICD_3_desc,
            ICD_2, ICD_3, CPT_2, CPT_1_desc, CPT_3, CPT_2_desc, CPT_3_desc)) %>%
  mutate(Date_of_Service = format(as.Date(Date_of_Service), "%m/%d/%Y"))

##############################################################################################################################
# SECTION 11: MSK POINTS MODEL (OREO 3.0)
##############################################################################################################################

# BUG FIX: original overwrote new_prelim_procedure right after filtering it — reordered
new_prelim_procedure <- read_csv(PATH_NEW_PRELIM_PROC) %>%
  filter(!(cpt_1 %in% removed_cpt$cpt_1))

prelim_proc  <- read_csv(PATH_PRELIM_PROC)
proc_desc_df <- read_csv(PATH_PROC_DESC) %>% rename_with(tolower)

# input_file_3 (4-month dataset) was already loaded and cleaned in Section 5 above

final_proc_v3 <- input_file_3 %>%
  left_join(new_prelim_procedure, by = c("CPT_1" = "cpt_1")) %>%
  filter(
    (ICD_1 >= "M00" & ICD_1 <= "M99") | (ICD_1 >= "R25" & ICD_1 < "R30") |
    (ICD_2 >= "M00" & ICD_2 <= "M99") | (ICD_2 >= "R25" & ICD_2 < "R30") |
    (ICD_3 >= "M00" & ICD_3 <= "M99") | (ICD_3 >= "R25" & ICD_3 < "R30")
  ) %>%
  filter(procedure_group %in% prelim_proc$pot_type) %>%
  distinct(`2nd_MD_ID`, Date_of_Service, CPT_1, .keep_all = TRUE)

df_result <- final_proc_v3 %>%
  left_join(prelim_proc, by = c("procedure_group" = "pot_type")) %>%
  group_by(`2nd_MD_ID`, procedure_group, ramp, Points) %>%
  summarize(vol_pots = n_distinct(paste(`2nd_MD_ID`, Date_of_Service, sep = "")), .groups = "drop")

result_points <- df_result %>%
  group_by(`2nd_MD_ID`, procedure_group) %>%
  mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, Points)) %>%
  select(`2nd_MD_ID`, procedure_group, procedure_type_points)

transposed_df <- pivot_wider(result_points,
                             names_from  = procedure_group,
                             values_from = procedure_type_points) %>%
  replace(is.na(.), 0) %>%
  as_tibble() %>%
  mutate(total_points = rowSums(select(., 2:last_col()), na.rm = TRUE))

oreo_pts_members <- transposed_df %>%
  filter(total_points >= 3) %>%
  select(`2nd_MD_ID`, total_points)

points_final <- oreo_pts_members %>%
  left_join(final_proc_v3, by = "2nd_MD_ID") %>%
  mutate(
    member_name = toupper(paste(First_Name, Last_Name, sep = " ")),
    MDC         = "MSK",
    pilot       = "Points"
  ) %>%
  filter(!member_name %in% pa_past_results$member_name)

# Remove members already handled in the non-points pipeline
points_only  <- points_final %>%
  filter(!`2nd_MD_ID` %in% df_deduped$`2nd_MD_ID`)

POINTS_RANK <- c(Points = 1, MRI = 2, PT = 3, Spine = 4,
                 Onc_pilot = 5, Cardio_pet_pilot = 6, GI_pilot = 7, nopilots = 8)

df_pts_combined <- points_only %>%
  select(-any_of(EXTRA_COLS)) %>%
  dedup_by_rank(POINTS_RANK) %>%
  filter(!`2nd_MD_ID` %in% oreo_past_results$`2nd_MD_ID`) %>%
  cast_id_cols()

oreo_final_points <- oreo_filtering(df_pts_combined, icd_lookup, cpt_lookup) %>%
  mutate(
    Risk_Level = case_when(
      pilot == "Points" ~ "MSK High - Predictive Points",
      pilot == "MRI"    ~ "MSK High - MRI",
      pilot == "PT"     ~ "MSK High - PT",
      pilot == "Spine"  ~ "MSK High - Spine",
      TRUE              ~ Risk_Level
    ),
    Probability = case_when(
      pilot %in% c("Points","MRI","PT","Spine") ~ "90%",
      TRUE                                      ~ Probability
    )
  ) %>%
  filter(!MDC %in% MDC_DROPS)

# Build points narrative 
oreo_pts_v3 <- oreo_final_points %>%
  distinct(`2nd_MD_ID`, procedure_group, .keep_all = TRUE) %>%
  group_by(`2nd_MD_ID`) %>%
  summarize(
    across(-procedure_group, first),
    procedure_group_combined = paste(unique(procedure_group), collapse = "; "),
    .groups = "drop"
  ) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ""))) %>%
  mutate(
    icd_combined = if_else(
      (ICD_2_desc == "") & (ICD_3_desc == ""), ICD_1_desc,
      str_c(ICD_1_desc, ICD_2_desc, ICD_3_desc, sep = "; ")
    ),
    ICD_desc = paste("MDC:", MDC,
                     ". Diagnosis description:", icd_combined,
                     ". Procedure Description:", CPT_1, procedure_group_combined, ".")
  )



oreo_pts_final  <- oreo_pts_v3 %>%
  filter(as.numeric(total_points) >= 3) %>%
  distinct(`2nd_MD_ID`, .keep_all = TRUE) %>%
  filter(!`2nd_MD_ID` %in% oreo_past_results$`2nd_MD_ID`) %>%
  filter(!member_name %in% pa_past_results$member_name) %>%
  mutate(
    Risk_Level = if_else(
      `2nd_MD_ID` %in% oreo_final_original$`2nd_MD_ID`,
      "MSK High - B", "MSK High - N"
    )
  ) %>%
  select(-c(rank, pilot, member_name, ICD_1_desc, ICD_2_desc, ICD_3_desc,
            ICD_2, ICD_3, CPT_2, CPT_1_desc, mdc_new, proc_type,
            procedure_group_combined, descrip_new_2, icd_combined))

# Remove points members from the main pipeline output
oreo_final_original <- oreo_final_original %>%
  filter(!`2nd_MD_ID` %in% oreo_pts_final$`2nd_MD_ID`)

##############################################################################################################################
# SECTION 12: ONCOLOGY POINTS MODEL
##############################################################################################################################

#' Generic oncology points runner (used for breast cancer and prostate).
run_oncology_points <- function(df, proc_points_df, had_proc_df,
                                 personal_history_icd, points_threshold = 10,
                                 label = "Breast Cancer") {
  history_ids <- df %>%
    filter(ICD_1 == personal_history_icd | ICD_2 == personal_history_icd | ICD_3 == personal_history_icd) %>%
    pull(`2nd_MD_ID`) %>% unique()

  treated_ids <- df %>%
    filter(CPT_1 %in% had_proc_df$cpt_code | CPT_2 %in% had_proc_df$cpt_code | CPT_3 %in% had_proc_df$cpt_code) %>%
    pull(`2nd_MD_ID`) %>% unique()

  proc_codes <- proc_points_df$cpt_code
  candidates <- df %>%
    filter(CPT_1 %in% proc_codes | CPT_2 %in% proc_codes | CPT_3 %in% proc_codes) %>%
    distinct(`2nd_MD_ID`, Date_of_Service, CPT_1, .keep_all = TRUE) %>%
    filter(!`2nd_MD_ID` %in% history_ids)

  vol <- candidates %>%
    left_join(proc_points_df, by = c("CPT_1" = "cpt_code")) %>%
    group_by(`2nd_MD_ID`, procedure_description, ramp, points) %>%
    summarize(vol_pots = n_distinct(paste(`2nd_MD_ID`, Date_of_Service, sep = "")), .groups = "drop")

  scored <- vol %>%
    mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, points)) %>%
    select(`2nd_MD_ID`, procedure_description, procedure_type_points)

  transposed <- pivot_wider(scored, names_from = procedure_description, values_from = procedure_type_points) %>%
    replace(is.na(.), 0) %>%
    as_tibble() %>%
    mutate(total_points = rowSums(select(., 2:last_col()), na.rm = TRUE))

  qualified_ids <- transposed %>%
    filter(total_points >= points_threshold) %>%
    filter(!`2nd_MD_ID` %in% treated_ids) %>%
    select(`2nd_MD_ID`, total_points)



  proc_desc_map  <- vol %>% distinct(`2nd_MD_ID`, procedure_description)

  qualified <- qualified_ids %>%
    left_join(candidates, by = "2nd_MD_ID") %>%
    left_join(proc_desc_map, by = "2nd_MD_ID") %>%
    mutate(MDC = "Oncology", pilot = label)



  list(qualified = qualified)
}

prelim_proc_onc <- read_csv(PATH_ONC_PROC_PTS)
had_procedure   <- read_csv(PATH_ONC_AFTER)

breast  <- run_oncology_points(input_file_3, prelim_proc_onc, had_procedure, "Z853",  points_threshold = 10, label = "Breast Cancer")
breast_qualified  <- breast$qualified


# Prostate
prostate_pts  <- read_csv(PATH_PROSTATE_PTS)
prostate_diag <- read_csv(PATH_PROSTATE_DIAG)
prostate_treat<- read_csv(PATH_PROSTATE_TREAT)

prostate_candidates <- input_file_3 %>%
  filter(ICD_1 %in% prostate_diag$dx1 | ICD_2 %in% prostate_diag$dx1 | ICD_3 %in% prostate_diag$dx1) %>%
  filter(CPT_1 %in% prostate_pts$proc1 | CPT_2 %in% prostate_pts$proc1 | CPT_3 %in% prostate_pts$proc1) %>%
  filter(!ICD_1 %in% "Z8546" & !ICD_2 %in% "Z8546" & !ICD_3 %in% "Z8546") %>%
  distinct(`2nd_MD_ID`, Date_of_Service, CPT_1, .keep_all = TRUE)

prostate_vol <- prostate_candidates %>%
  left_join(prostate_pts, by = c("CPT_1" = "proc1")) %>%
  group_by(`2nd_MD_ID`, description, ramp, points) %>%
  summarize(vol_pots = n_distinct(paste(`2nd_MD_ID`, Date_of_Service, sep = "")), .groups = "drop")

prostate_scored <- prostate_vol %>%
  mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, points)) %>%
  select(`2nd_MD_ID`, description, procedure_type_points)

prostate_transposed <- pivot_wider(prostate_scored, names_from = description, values_from = procedure_type_points) %>%
  replace(is.na(.), 0) %>%
  mutate(total_points = rowSums(select(., 2:last_col()), na.rm = TRUE))

prostate_qual_ids   <- prostate_transposed %>% filter(total_points >= 3) %>% select(`2nd_MD_ID`, total_points)


prostate_desc <- prostate_vol %>% distinct(`2nd_MD_ID`, description)
prostate_qualified <- prostate_qual_ids %>%
  left_join(prostate_candidates, by = "2nd_MD_ID") %>%
  left_join(prostate_desc, by = "2nd_MD_ID") %>%
  mutate(MDC = "Oncology", pilot = "Prostate Cancer")


##############################################################################################################################
# SECTION 13: ASSEMBLE FINAL OUTPUT
##############################################################################################################################

# Columns that come in as numeric in some dataframes and character in others.
# Cast them all to character before binding so bind_rows() doesn't throw a type error.
COERCE_TO_CHAR <- c("Native_ID", "Subscriber_ID", "Parent_ID", "Client_ID",
                    "PhoneNumber", "Subscriber_Zip", "Zip", "Age",
                    "Has_ICD", "Has_CPT", "Has_NDC", "fake_id", "total_points", "Subcompany", "Date_of_Service")


coerce_for_bind <- function(df) {
  df %>% mutate(across(any_of(COERCE_TO_CHAR), as.character))
}

final_combined <- bind_rows(
  coerce_for_bind(oreo_pts_final),
  coerce_for_bind(oreo_final_original),
  coerce_for_bind(breast_qualified),
  coerce_for_bind(prostate_qualified)
) %>%
  filter(!Data_Source %in% c("Amazon - Cigna","Albertsons")) %>%
  filter(!(Data_Source == "JBS" & Subcompany %in% c("T","M","C","P"))) %>%
  filter(!(MDC == "Oncology" & Data_Source == "Carters")) %>%
  apply_exclusions() %>%
  mutate(
    PhoneNumber = na_if(PhoneNumber, "null"),
    PhoneNumber = na_if(PhoneNumber, "Novalidphone"),
    PhoneNumber = coalesce(PhoneNumber, "")
  ) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., "")))

# Attach MDC IDs, then enforce final column order
mdc_id_df      <- read_csv(PATH_MDC_ID)
final_combined <- final_combined %>%
  left_join(mdc_id_df, by = c("MDC" = "category")) %>%
  mutate(mdc_id = if_else(is.na(mdc_id), 293L, mdc_id)) %>%
  select(
    Data_Source,
    Subcompany,
    Native_ID,
    fake_id, 
    `2nd_MD_ID`,
    Has_ICD,
    Has_CPT,
    Has_NDC,
    Gender,
    Age,
    Zip,
    First_Name,
    Last_Name,
    DOB,
    Date_of_Service,
    ICD_1,
    CPT_1,
    PhoneNumber,
    Relationship_Type,
    Subscriber_ID,
    Subscriber_First_Name,
    Subscriber_Last_Name,
    Subscriber_DOB,
    Subscriber_Zip,
    Parent_ID,
    Client_ID,
    Risk_Level,
    Probability,
    ICD_desc,
    CPT_desc,
    MDC,
    mdc_id
  )



##############################################################################################################################
# SECTION 15: SAVE OUTPUTS
##############################################################################################################################

# Restore original column name for data engineer:
# drop character 2nd_MD_ID, rename fake_id back to 2nd_MD_ID
restore_id <- function(df) {
  df %>%
    select(-`2nd_MD_ID`) %>%
    rename(`2nd_MD_ID` = fake_id)
}

write_csv(restore_id(final_combined), PATH_OUT_MAIN)


# Update past results tracker
new_past <- final_combined %>%
  distinct(`2nd_MD_ID`) %>%
  mutate(filedate = "current_run")
write_csv(new_past, PATH_OUT_PAST_UPDATE)

# Summary stats
stats <- final_combined %>%
  distinct(`2nd_MD_ID`, .keep_all = TRUE) %>%
  group_by(Data_Source, MDC, Risk_Level) %>%
  summarise(n = n_distinct(`2nd_MD_ID`), .groups = "drop")
write_csv(stats, PATH_OUT_STATS)

cat("Main output members: ", n_distinct(final_combined$`2nd_MD_ID`), "\n")
