########################################################################################################
# Oreo Submodel Code 

# Contains code for all IDC categories except behavioral health, dental, pain, and other. 

########################################################################################################
library(dplyr)
library(DBI)
library(data.table)

con <- dbConnect(dbDriver("PostgreSQL"),
                 host ='acp-edw-redshift-r0-prod.accint.io', 
                 port = 5439, 
                 user = '', 
                 password = '',
                 dbname = 'acp_edw'
)

##### this query pulls in all claims data for the past 90 days
input_file_2 <- setDT(dbGetQuery(con, " WITH phone_number AS (
    SELECT pp.person_id,
           area_cd || phone_num                                                as phone_num,
           type_nm,
           ROW_NUMBER() OVER (PARTITION BY pp.person_id ORDER BY created_dt DESC) as rn_p
    FROM edw.person_phone pp
    WHERE preferred_flg IS TRUE
),

    current_mbrshp_1 AS (
        SELECT a.customer_nm AS Subcompany,
                a.customer_nm as external_id,
            b.person_id,
              b.drvd_mbrshp_covrg_id,
               b.gender_cd AS Gender,
               INITCAP(b.rln_disp) as Relationship_Type,
               b.state_cd,
               ROUND(DATEDIFF(day, b.birth_dtm, GETDATE())/365,0) AS age,
              b.zip_cd AS Zip,
              a.firstname as First_Name,
            a.lastname as Last_Name,
              b.birth_dtm AS DOB,
              b.utc_period,
              b.drvd_acct_id,
               ROW_NUMBER() OVER (PARTITION BY b.person_id ORDER BY b.created_dt DESC) AS RN
        FROM info_layer.prs_mbrshp_covrg b
        INNER JOIN mbr.mbr_elig_emo a on a.person_id = b.person_id
        WHERE b.utc_period >= TO_CHAR(getdate() - 30, 'YYYYMM')
    ),

     current_mbrshp_2 AS (
        SELECT *
        FROM current_mbrshp_1
        WHERE Relationship_Type ILIKE '%SELF%'
    ),

      current_mbrshp AS (
        SELECT a.*,
               b.person_id as Subscriber_ID,
               b.First_Name as Subscriber_First_Name,
               b.Last_Name as Subscriber_Last_Name,
               b.DOB::date as Subscriber_DOB,
               b.ZIP as Subscriber_Zip
        FROM current_mbrshp_1 a
        LEFT JOIN current_mbrshp_2 b ON a.drvd_acct_id = b.drvd_acct_id
    ),

     relevant_mbrshp AS (
        SELECT DISTINCT person_id,
               First_Name,
               Last_Name,
               Gender,
               DOB,
               Subcompany,
               state_cd, 
               external_id, 
               Relationship_Type,
               Zip,
               Subscriber_ID,
               Subscriber_First_Name,
               Subscriber_Last_Name,
               Subscriber_DOB,
               Subscriber_Zip,
               utc_period
        FROM current_mbrshp cm WHERE rn=1
    ),
 

     final_membership AS (
         SELECT rb.person_id,
                first_name,
                last_name,
                gender,
                dob,
                subcompany,
                external_id,
                relationship_type,
                zip,
                subscriber_id,
                subscriber_first_name,
                subscriber_last_name,
                subscriber_dob,
                subscriber_zip,
                phone_num,
                1 AS Has_ICD,
                1 AS Has_CPT,
                1 AS Has_NDC
         FROM relevant_mbrshp rb
         LEFT JOIN (SELECT * FROM phone_number WHERE rn_p = 1) p ON rb.person_id = p.person_id
         WHERE Subcompany NOT IN ('AMERICAN AIRLINES')
     )

   SELECT fm.person_id,
          fm.first_name,
           fm.last_name,
           fm.gender,
           fm.dob,
           fm.subcompany,
           fm.external_id,
           fm.relationship_type,
           fm.zip,
           fm.subscriber_id,
           fm.subscriber_first_name,
           fm.subscriber_last_name,
           fm.subscriber_dob,
           fm.subscriber_zip,
           fm.phone_num,
           fm.Has_ICD,
           fm.Has_CPT,
           fm.Has_NDC,
         to_char(serv_from_dt, 'YYYY-MM-DD') as start_date,
          diag_cd_1 AS ICD_1,
          diag_cd_2 as ICD_2,
          diag_cd_3 as ICD_3,
         diag_nm_1 AS ICD_desc_1,
          diag_nm_2 AS ICD_desc_2,
          diag_nm_3 AS ICD_desc_3,
          proc_cd_1 AS CPT_1,
          proc_cd_2 AS CPT_2,
          proc_cd_3 AS CPT_3,
          proc_nm_1 AS CPT_desc_1,
          proc_nm_2 as CPT_desc_2, 
          proc_nm_3 AS CPT_desc_3
           FROM info_layer.prs_med_clm_line_item_dtl clm
        INNER JOIN final_membership fm ON clm.person_id = fm.person_id
         where start_date >= '2025-11-21' AND start_date <= '2026-02-21' 
         AND clm.person_id NOT IN (SELECT DISTINCT patient_id
                           FROM edw.preferences p
                           WHERE p.do_not_contact_flg = 1) AND subcompany IN ( 'SEVEN ELEVEN', 'LOWE''S', 'ADVANTAGE SOLUTIONS',  'API GROUP',
                                                                             'AQR CAPITAL MANAGEMENT',   'ARKANSAS BLUE CROSS BLUE SHIELD', 'ARKANSAS STATE UNIVERSITY',  'BAD BOY MOWERS',  'BECTON DICKINSON AND COMPANY', 'BANYAN TREATMENT CENTERS' , 'BRIDGE INVESTMENT GROUP', 'BOX INC', 'BRYCE CORP', 'CALIBER', 
                                                                             'CETERA FINANCIAL',  'CHATSWORTH PRODUCTS INC' , 'CITY OF REDDING', 'CITY OF LOMPOC', 'CITY OF SILOAM SPRINGS' , 'COUNTY OF SANTA BARBARA',   'CITY OF SEATTLE' ,  'CITY OF YUBA CITY' ,  'COOPER STANDARD' , 'COUNTY OF LAKE'  , 'DEVRY UNIVERSITY' ,
                                                                             'DAY AND ZIMMERMANN' , 'DWYEROMEGA',  'EMPOWER HEALTHCARE SOLUTIONS', 'ENERCON',  'FIRST AMERICAN FINANCIAL', 'GE HEALTHCARE',  'GENERAL MILLS',   'GENTIVA', 
                                                                              'HUMANA',   'INTERNATIONAL PAPER','INTUITIVE SURGICAL',   'LANDRYS INC',  'LIGHTHOUSE AUTISM CENTER', 'LIFE AND SPECIALTY VENTURES', 'LEADVENTURE',  'LEXICON INC','MOOG', 'MILESTONE TECHNOLOGIES',
                                                                            'MOFFITT CANCER CENTER',  'MCKESSON', 'NEVADA GOLD MINES',  
                                                                            'OTC BRANDS', 'PAYPAL', 'PAYLOCITY', 'PEDIATRIC ASSOCIATES', 'PERATON', 'PTA PLASTICS',  'PUBLIC STORAGE',  'RAYMOND JAMES FINANCIAL', 'REVERE PLASTICS SYSTEMS', 'RED RIVER TECHNOLOGY',
                                                                                 'ROCKET SOFTWARE',  'SA RECYCLING' , 'SAN LUIS OBISPO COUNTY', 'STANDARDAERO', 'SAFRAN USA', 'SEDGWICK','SHAMROCK FOODS COMPANY', 'STATE FARM', 'SOUTH COAST AIR QUALITY MANAGEMENT DISTRICT', 'TEVA PHARMACEUTICALS', 'THE FRIEDKIN GROUP',
                                                                                'THE KNOT WORLDWIDE',  'TUTOR PERINI',  'TORY BURCH',   'UNITED MUSCULOSKELETAL PARTNERS',
                                                                              'UNITED AIRLINES',  'WASHINGTON TEAMSTERS WELFARE TRUST', 'WW GRAINGER',  'WAWA','SPECIAL DISTRICT RISK MANAGEMENT AUTHORITY', 'GOLDEN STATE RISK MANAGEMENT AUTHORITY')






     AND DATEDIFF(YEAR, dob, getdate()) >= 18;
")) 






##### first read file for the claims data (this is if you don't run the above)


input_file_2<- read_csv("~/Desktop/Oreo Run 2025/accl_claims_0226.csv")



#### EDW Eligibility Check ####
q_edw2 <-  "
select DISTINCT
       contract.subj_disp                                        as customer
     , UPPER(o.org_nm)                                           as org_nm
--     , ct.type_cd                                                as contract_type
--     , cst.sub_type_cd
     , mc.acp_mbr_flg_val
     , mc.beneficiary_id                                         as person_id
from acp_edw.edw.contract contract
         left join acp_edw.edw.contract_sub_type cst
                    on contract.contract_id = cst.contract_id
         inner join acp_edw.edw.mbrshp_covrg_contract mcc
                    on contract.contract_id = mcc.contract_id
         inner join acp_edw.edw.mbrshp_covrg mc
                    on mcc.covrg_id = mc.covrg_id
                        and mc.covrg_eff_dt <= current_date
                        and (mc.covrg_end_dt is null or current_date <= mc.covrg_end_dt)
         inner join edw.mbrshp_covrg_payor cp
                    on mc.covrg_id = cp.covrg_id
                        and cp.payor_type = 'Organization'
         inner join edw.svcs_organization o
                    on cp.payor_id = o.org_id
                        and o.org_type = 'customer'
         inner join edw.contract_type ct
                    on contract.contract_id = ct.contract_id
                        and ct.type_cd NOT IN ('terminated', 'entered-in-error')
where contract.deleted_flg != true
  and contract.start_dt <= current_date
  and (contract.end_dt is null or contract.end_dt >= current_date)
  and contract.status not in ('entered-in-error', 'deleted') 
  and sub_type_cd = 'emo'
order by contract.subj_disp, org_nm, ct.type_cd, sub_type_cd, person_id;"

EDW_elig <- GetData("EDW", q_edw2)


###filters out any members who are not eligible for EMO services 
input_file_2 <- input_file_2 %>%
  filter(person_id %in% EDW_elig$person_id)


input_file_2$subcompany <- input_file_2$external_id


# Adjust the time-frame for the period desired here.  (SO THREE MONTHS AND ONE MONTH AGO )(FROM THE DAY BEFORE TODAY"S DATE)
three_months = '2025-11-21'     # Three months from end_DoS
one_month = '2026-01-21'    # One month from end_DoS
end_DoS = '2026-02-21'           # End of time window


# Add high-cost CPT codes
hc_cpt <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/hc_cpts.csv")


unique(input_file_2$subcompany)
#### only highlight and then run the msk_only(In the function is the data source from the excel sheet )
msk_only_filter <- function(df){
  
  input_file_2 <- df[df$subcompany %in% c('THE HANOVER INSURANCE GROUP', 'COMMSCOPE' ),]
  
  msk = input_file_2 %>%
    group_by(`person_id`) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$msk_cpt )) )) %>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  msk1 = msk%>%
    subset((icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))
  
  msk2 = msk%>%
    subset(( icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))
  
  setDT(msk1)
  msk_count1 <- msk1[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk1 <- merge(msk1, msk_count1, by = c("person_id"), all = TRUE)
  
  setDT(msk2)
  msk_count2 <- msk2[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk2 <- merge(msk2, msk_count2, by = c("person_id"), all = TRUE)
  
  # Filter for chiropractor people
  chiro_codes <- c('98940', '98941', '98942', '98943')
  
  chiro1 <- msk1 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  chiro2 <- msk2 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  # If MSK member has chiropractic CPT code, divide Date_Count by 10 for them
  msk1$Date_Count = ifelse(msk1$`person_id` %in% chiro1$`person_id`, msk1$Date_Count / 10, msk1$Date_Count )
  msk2$Date_Count = ifelse(msk2$`person_id` %in% chiro2$`person_id`, msk2$Date_Count / 10, msk2$Date_Count )
  
  msk1 <- msk1 %>%
    group_by(`person_id`) %>%
    filter(Date_Count >= 8)
  # Change MDC column to 'MSK'
  msk1$MDC = 'MSK'
  
  msk2 <- msk2 %>%
    group_by(`person_id`) %>%
    filter(Date_Count >= 4)
  # Change MDC column to 'MSK'
  msk2$MDC = 'MSK'
  
  dupvals <- msk2$`person_id` %in% msk1$`person_id`
  msk_final <- rbind(msk1, msk2[!dupvals,])
  
  # Change MDC column to 'MSK'
  msk_final$MDC = 'MSK'
  
  drop <- c('Date_Count')
  msk_only <- msk_final[, !(names(msk_final) %in% drop)]
}
msk_only = msk_only_filter(input_file_2)

##################################################################################################
### companies with top 5 categories
five_only_filter <- function(df){
  input_file_2 <- df[!(df$subcompany %in%  c('THE HANOVER INSURANCE GROUP', 'COMMSCOPE', 'INTUITIVE SURGICAL', 'UNITED AIRLINES', 'HUMANA' , 'GENTIVA' ,'MOFFITT CANCER CENTER' , 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                             'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY')),]
  
  # Filter data for oncology
  
  onc1 = input_file_2%>%
    subset( (icd_1 >= 'C00' & icd_1 < 'D50')|(icd_1 >= 'Z80' & icd_1 < 'Z81')|(icd_1 >= 'Z85' & icd_1 < 'Z86')|
              (icd_2 >= 'C00' & icd_2 < 'D50')|(icd_2 >= 'Z80' & icd_2 < 'Z81')|(icd_2 >= 'Z85' & icd_2 < 'Z86')|
              (icd_3 >= 'C00' & icd_3 < 'D50')|(icd_3  >= 'Z80' & icd_3 < 'Z81')|(icd_3 >= 'Z85' & icd_3< 'Z86'))%>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  onc2 = input_file_2%>%
    subset( (icd_1 >= 'C00' & icd_1 < 'D50')|(icd_1 >= 'Z80' & icd_1 < 'Z81')|(icd_1 >= 'Z85' & icd_1 < 'Z86')|
              (icd_2 >= 'C00' & icd_2 < 'D50')|(icd_2 >= 'Z80' & icd_2 < 'Z81')|(icd_2 >= 'Z85' & icd_2 < 'Z86')|
              (icd_3 >= 'C00' & icd_3 < 'D50')|(icd_3  >= 'Z80' & icd_3 < 'Z81')|(icd_3 >= 'Z85' & icd_3< 'Z86'))%>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- onc2$person_id %in% onc1$person_id
  onc_final <- rbind(onc1, onc2[!dupvals,])
  
  # Change MDC column to 'Oncology'
  onc_final$MDC = 'Oncology'
  
  ####################################################################################
  
  # Filter data for cardiology 
  cardio = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$cardio_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  cardio1 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')|
             ( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8) 
  
  cardio2 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')
           |( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 4) 
  
  dupvals <- cardio2$`person_id` %in% cardio1$`person_id`
  cardio_final <- rbind(cardio1, cardio2[!dupvals,])
  
  cardio_final$MDC = 'Cardio'
  
  ########################################################################################################################
  
  # Filter data for GI 
  
  gi = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$gi_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  gi1 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  gi2 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- gi2$`person_id` %in% gi1$`person_id`
  gi_final <- rbind(gi1, gi2[!dupvals,])
  
  
  
  
  
  # Change MDC column to 'GI'
  gi_final$MDC = 'GI'
  
  ########################################################################################################################
  
  # Filter data for MSK
  
  
  msk = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$msk_cpt )) )) %>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  msk1 = msk%>%
    subset((icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))
  
  msk2 = msk%>%
    subset(( icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))
  
  setDT(msk1)
  msk_count1 <- msk1[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk1 <- merge(msk1, msk_count1, by = c("person_id"), all = TRUE)
  
  setDT(msk2)
  msk_count2 <- msk2[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk2 <- merge(msk2, msk_count2, by = c("person_id"), all = TRUE)
  
  # Filter for chiropractor people
  chiro_codes <- c('98940', '98941', '98942', '98943')
  
  chiro1 <- msk1 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  chiro2 <- msk2 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  # If MSK member has chiropractic CPT code, divide Date_Count by 10 for them
  msk1$Date_Count = ifelse(msk1$person_id %in% chiro1$person_id, msk1$Date_Count / 10, msk1$Date_Count )
  msk2$Date_Count = ifelse(msk2$person_id %in% chiro2$person_id, msk2$Date_Count / 10, msk2$Date_Count )
  
  msk1 <- msk1 %>%
    group_by(person_id) %>%
    filter(Date_Count >= 8)
  # Change MDC column to 'MSK'
  msk1$MDC = 'MSK'
  
  msk2 <- msk2 %>%
    group_by(person_id) %>%
    filter(Date_Count >= 4)
  # Change MDC column to 'MSK'
  msk2$MDC = 'MSK'
  
  dupvals <- msk2$person_id %in% msk1$person_id
  msk_final <- rbind(msk1, msk2[!dupvals,])
  
  # Change MDC column to 'MSK'
  msk_final$MDC = 'MSK'
  
  drop <- c('Date_Count')
  msk_final <- msk_final[, !(names(msk_final) %in% drop)]
  
  ########################################################################################################################
  
  # Filter data for women's health 
  
  wh = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$wh_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  wh1 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')|
             ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  wh2 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')|
             ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- wh2$person_id %in% wh1$person_id
  wh_final <- rbind(wh1, wh2[!dupvals,])
  
  # Change MDC column to 'Women's Health'
  wh_final$MDC = "Women's Health"
  
  #########################################################################################################################
  
  top5_final <- rbind(onc_final, cardio_final, gi_final, msk_final, wh_final)
  
}
five_only = five_only_filter (input_file_2)



################################################################
### companies with Oncology turned off

no_onc_filter <- function(df){
  input_file_2 <- df[(df$subcompany %in%  c(  'INTUITIVE SURGICAL', 'UNITED AIRLINES', 'MOFFITT CANCER CENTER', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                    'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY')),]
  
  
  # Filter data for cardiology 
  cardio = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$cardio_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  cardio1 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')|
             ( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8) 
  
  cardio2 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')|
             ( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 4) 
  
  dupvals <- cardio2$`person_id` %in% cardio1$`person_id`
  cardio_final <- rbind(cardio1, cardio2[!dupvals,])
  
  cardio_final$MDC = 'Cardio'
  
  ########################################################################################################################
  
  # Filter data for GI 
  
  gi = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$gi_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  gi1 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  gi2 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- gi2$`person_id` %in% gi1$`person_id`
  gi_final <- rbind(gi1, gi2[!dupvals,])
  
  
  
  
  
  # Change MDC column to 'GI'
  gi_final$MDC = 'GI'
  
  ########################################################################################################################
  
  # Filter data for MSK
  
  
  msk = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$msk_cpt )) )) %>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  msk1 = msk%>%
    subset((icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))
  
  msk2 = msk%>%
    subset(( icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    filter(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))
  
  setDT(msk1)
  msk_count1 <- msk1[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk1 <- merge(msk1, msk_count1, by = c("person_id"), all = TRUE)
  
  setDT(msk2)
  msk_count2 <- msk2[,.(Date_Count = uniqueN(start_date)), by = .(`person_id`)]
  msk2 <- merge(msk2, msk_count2, by = c("person_id"), all = TRUE)
  
  # Filter for chiropractor people
  chiro_codes <- c('98940', '98941', '98942', '98943')
  
  chiro1 <- msk1 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  chiro2 <- msk2 %>% 
    subset(cpt_1 %in% chiro_codes)
  
  # If MSK member has chiropractic CPT code, divide Date_Count by 10 for them
  msk1$Date_Count = ifelse(msk1$person_id %in% chiro1$person_id, msk1$Date_Count / 10, msk1$Date_Count )
  msk2$Date_Count = ifelse(msk2$person_id %in% chiro2$person_id, msk2$Date_Count / 10, msk2$Date_Count )
  
  msk1 <- msk1 %>%
    group_by(person_id) %>%
    filter(Date_Count >= 8)
  # Change MDC column to 'MSK'
  msk1$MDC = 'MSK'
  
  msk2 <- msk2 %>%
    group_by(person_id) %>%
    filter(Date_Count >= 4)
  # Change MDC column to 'MSK'
  msk2$MDC = 'MSK'
  
  dupvals <- msk2$person_id %in% msk1$person_id
  msk_final <- rbind(msk1, msk2[!dupvals,])
  
  # Change MDC column to 'MSK'
  msk_final$MDC = 'MSK'
  
  drop <- c('Date_Count')
  msk_final <- msk_final[, !(names(msk_final) %in% drop)]
  
  ########################################################################################################################
  
  # Filter data for women's health 
  
  wh = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$wh_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  wh1 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')
           | ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  wh2 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')|
             ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- wh2$person_id %in% wh1$person_id
  wh_final <- rbind(wh1, wh2[!dupvals,])
  
  # Change MDC column to 'Women's Health'
  wh_final$MDC = "Women's Health"
  
  #########################################################################################################################
  
  noonc_final <- rbind( cardio_final, gi_final, msk_final, wh_final)
  
}
no_onc_only = no_onc_filter (input_file_2)

############################################################
### companies with MSK turned off

no_msk_filter <- function(df){
  input_file_2 <- df[(df$subcompany %in%  c('HUMANA', 'GENTIVA')),]
  
  # Filter data for oncology
  
  onc1 = input_file_2%>%
    subset( (icd_1 >= 'C00' & icd_1 < 'D50')|(icd_1 >= 'Z80' & icd_1 < 'Z81')|(icd_1 >= 'Z85' & icd_1 < 'Z86')|
              (icd_2 >= 'C00' & icd_2 < 'D50')|(icd_2 >= 'Z80' & icd_2 < 'Z81')|(icd_2 >= 'Z85' & icd_2 < 'Z86')|
              (icd_3 >= 'C00' & icd_3 < 'D50')|(icd_3  >= 'Z80' & icd_3 < 'Z81')|(icd_3 >= 'Z85' & icd_3< 'Z86'))%>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  onc2 = input_file_2%>%
    subset( (icd_1 >= 'C00' & icd_1 < 'D50')|(icd_1 >= 'Z80' & icd_1 < 'Z81')|(icd_1 >= 'Z85' & icd_1 < 'Z86')|
              (icd_2 >= 'C00' & icd_2 < 'D50')|(icd_2 >= 'Z80' & icd_2 < 'Z81')|(icd_2 >= 'Z85' & icd_2 < 'Z86')|
              (icd_3 >= 'C00' & icd_3 < 'D50')|(icd_3  >= 'Z80' & icd_3 < 'Z81')|(icd_3 >= 'Z85' & icd_3< 'Z86'))%>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- onc2$person_id %in% onc1$person_id
  onc_final <- rbind(onc1, onc2[!dupvals,])
  
  # Change MDC column to 'Oncology'
  onc_final$MDC = 'Oncology'
  
  ####################################################################################
  
  # Filter data for cardiology 
  cardio = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$cardio_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  cardio1 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')|
             ( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8) 
  
  cardio2 = cardio%>%
    subset(( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')
           |( icd_2 >= 'I00' & icd_2 <= 'I99')| (icd_2 >= 'R00' & icd_2 < 'R10') | (icd_2 >= 'Z950' & icd_2 < 'Z960') | (icd_2 >= 'T8201' & icd_2 < 'T8300')|
             ( icd_3 >= 'I00' & icd_3 <= 'I99')| (icd_3 >= 'R00' & icd_3 < 'R10') | (icd_3 >= 'Z950' & icd_3 < 'Z960') | (icd_3 >= 'T8201' & icd_3 < 'T8300'))%>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 4) 
  
  dupvals <- cardio2$`person_id` %in% cardio1$`person_id`
  cardio_final <- rbind(cardio1, cardio2[!dupvals,])
  
  cardio_final$MDC = 'Cardio'
  
  ########################################################################################################################
  
  # Filter data for GI 
  
  gi = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$gi_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  gi1 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  gi2 = gi%>%
    subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
               (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
               (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- gi2$`person_id` %in% gi1$`person_id`
  gi_final <- rbind(gi1, gi2[!dupvals,])
  
  
  
  
  
  # Change MDC column to 'GI'
  gi_final$MDC = 'GI'
  

  
  ########################################################################################################################
  
  # Filter data for women's health 
  
  wh = input_file_2%>%
    group_by(person_id) %>%
    filter(! ((any(cpt_1 %in% hc_cpt$wh_cpt ))))%>%
    filter(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    ungroup
  
  wh1 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')|
             ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(three_months) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 8)
  
  wh2 = wh%>%
    subset(( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999')|
             ( icd_2 >= 'N60' & icd_2 <= 'N99')|(icd_2 >= 'N992' & icd_2 <= 'N999')|
             ( icd_3 >= 'N60' & icd_3 <= 'N99')|(icd_3 >= 'N992' & icd_3  <= 'N999')) %>%
    subset(start_date >= as.Date(one_month) & start_date <= as.Date(end_DoS))%>%
    group_by(person_id) %>%
    filter(n_distinct(start_date) >= 4)
  
  dupvals <- wh2$person_id %in% wh1$person_id
  wh_final <- rbind(wh1, wh2[!dupvals,])
  
  # Change MDC column to 'Women's Health'
  wh_final$MDC = "Women's Health"
  
  #########################################################################################################################
  
  nomsk_final <- rbind(onc_final, cardio_final, gi_final,  wh_final)
  
}
no_msk_only = no_msk_filter(input_file_2)





#########################################################################################################################


# Bind individual datasets together again and save
oreo_final_without_pilots = rbind(five_only , no_onc_only, no_msk_only)
oreo_final_without_pilots$pilot <- 'nopilots'



#######################################################################################################


# Filter for MSK pilot group
pt_cpt <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/pt_cpt.csv")
mri_cpt <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/mri_cpt.csv")




pilot_data(df){
  
  msk_pilot = input_file_2%>%
    group_by(`person_id`) %>%
    filter(! (any(cpt_1 %in% hc_cpt$msk_cpt )))%>%
    ungroup
  
  msk_pilot = msk_pilot%>%
    subset(( icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
             (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'S00' & icd_2 < 'T150') | (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
             (icd_3 >= 'M00' & icd_3 <= 'M99')| (icd_3 >= 'S00' & icd_3 < 'T150') | (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 1)
  
  msk_pilot_pt = msk_pilot %>% 
    subset(( cpt_1 %in% pt_cpt$cpt))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 10)
  
  msk_pilot_mri = msk_pilot %>%
    subset((cpt_1 %in% mri_cpt$cpt))%>%
    group_by(`person_id`) %>%
    filter(n_distinct(start_date) >= 1)
}




#Get all records for MRI and PT members
all_mskmri_records <- msk_pilot_mri
all_mskpt_records <-  msk_pilot_pt 

all_mskmri_records  <- all_mskmri_records[!(all_mskmri_records$subcompany %in% c('HUMANA', 'GENTIVA')),]

all_mskpt_records <- all_mskpt_records[!(all_mskpt_records$subcompany %in% c('HUMANA', 'GENTIVA')),]


all_mskmri_records$MDC <- 'MSK'
all_mskmri_records$pilot <-'MRI'

all_mskpt_records$MDC <-  'MSK'

all_mskpt_records$pilot <-'PT'



##########################################################################################

# Spine pilot 
spine_codes = c('M4710', 'M4711', 'M4712', 'M4713', 'M4714', 'M4715', 'M4716', 'M4720', 'M4721',
                'M4722', 'M4723', 'M4724', 'M4725', 'M4726', 'M4727', 'M4728', 'M47811',
                'M47812', 'M47813', 'M47814', 'M47815', 'M47816', 'M47817', 'M47818',
                'M47819', 'M47891', 'M47892', 'M47893', 'M47894', 'M47895', 'M47896',
                'M47897', 'M47898', 'M47899', 'M479')

spine_members = input_file_2%>%
  group_by(`person_id`) %>%
  filter(! ((any(cpt_1 %in% hc_cpt$msk_cpt ))))%>%
  ungroup

spine_pilot = spine_members %>% 
  subset(( icd_1 %in% spine_codes) | (icd_2 %in% spine_codes) | (icd_3 %in% spine_codes))%>%
  group_by(`person_id`) %>%
  filter(n_distinct(start_date) >= 1)

spine_pilot <- spine_pilot[!(spine_pilot$subcompany %in% c('HUMANA', 'GENTIVA')),] 

spine_pilot$MDC <- 'MSK'
spine_pilot$pilot <- 'Spine'

##############################################################################################


gi_cpt <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/GI_cpt_endoscopy.csv")


gi_pilot  = input_file_2 %>%
  subset(  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885')|
             (icd_2 >= 'K20' & icd_2 < 'K69')|(icd_2 >= 'K90' & icd_2 < 'K96')|(icd_2 >= 'R10' & icd_2 < 'R20') | (icd_2 >= 'Z980' & icd_2 < 'Z981')| (icd_2 >= 'Z9884' & icd_2 < 'Z9885')|
             (icd_3 >= 'K20' & icd_3 < 'K69')|(icd_3 >= 'K90' & icd_3 < 'K96')|(icd_3 >= 'R10' & icd_3 < 'R20') | (icd_3 >= 'Z980' & icd_3 < 'Z981')| (icd_3 >= 'Z9884' & icd_3 < 'Z9885')) %>%
  group_by(person_id) %>%
  filter(n_distinct(start_date) >= 2) 


gi_pilot_members = gi_pilot %>%
  subset((cpt_1 %in% gi_cpt$CPT)) %>%
  group_by(person_id) %>%
  filter(n_distinct(start_date) >= 2) 

cpt_excluded = c('44388' , '45378', '45330')
gi_pilot_final <- gi_pilot_members %>%
  mutate(age = as.numeric(difftime(start_date,ymd(dob)) / 365.25)) %>%
  filter(!(age >= 50 & ((cpt_1 %in% cpt_excluded))))

age_drop <- c('age')


gi_pilot_final <- gi_pilot_final[,!(names(gi_pilot_final) %in% age_drop)]
gi_pilot_final <- gi_pilot_final[!(gi_pilot_final$subcompany %in% c('THE HANOVER INSURANCE GROUP', 'COMMSCOPE')),]



gi_pilot_final$MDC <- 'GI'

gi_pilot_final$pilot <- 'GI_pilot'



df_combined_original <- rbind(all_mskpt_records, all_mskmri_records, spine_pilot, oreo_final_without_pilots, gi_pilot_final)


cols_to_drop <- c('ICD_4', 'ICD_5', 'ICD_6', 'ICD_7', 'ICD_8', 'ICD_9', 'icd_10', 'icd_11', 'icd_12',
                  'icd_13', 'icd_14', 'icd_15', 'icd_16', 'CPT_4', 'CPT_5', 'CPT_6', 'CPT_7', 'CPT_8', 'CPT_9',
                  'cpt_10', 'cpt_11', 'cpt_12', 'cpt_13', 'NDC_1', 'NDC_2', 'NDC_3', 'NDC_4', 'NDC_5', 'NDC_6',
                  'NDC_7', 'NDC_8', 'NDC_9', 'NDC_10', 'NDC_11', 'NDC_12', 'NDC_13', 'CPT_2', 'CPT_3', 'ICD_2', 'ICD_3' )
df_combined_original <-df_combined_original[,!(names(df_combined_original) %in% cols_to_drop)]



##remove SAIC 


df_combined_original <- df_combined_original %>%
  mutate(rank = case_when(
    pilot == 'MRI'~ 1,
    pilot == 'PT'~  2, 
    pilot == 'Spine'~ 3,
    pilot == 'GI_pilot' ~ 5,
    pilot == 'nopilots'~ 6, 
  ))


df_deduped_original <- df_combined_original %>%
  group_by(`person_id`) %>%
  filter(rank == min(rank))

### this removes any member who has been stratified in the past 6 months 

oreo_past_results = read_csv("~/Library/CloudStorage/OneDrive-Accolade,Inc/Georgina New files/Oreo 2025/Accolade Oreo/oreo_past_results2024.csv")

df_deduped_original <-df_deduped_original[!(df_deduped_original$`person_id` %in% oreo_past_results$Native_ID),] 









remove_dup <- function(strng) {
  strng <- strsplit(strng, ",")[[1]]
  strng <- unique(strng)
  return(paste(strng, collapse = ","))
}


accl_oreo_filtering <- function(file) {
  df <- file
  
  # Calculate percentiles
  unique_visits <- table(df$person_id, df$start_date)
  unique_visits <- rowSums(unique_visits > 0)
  ninety_percentile <- unique_visits[unique_visits >= quantile(unique_visits, 0.9)]
  seventy_to_ninety <- unique_visits[unique_visits >= quantile(unique_visits, 0.7) &
                                       unique_visits < quantile(unique_visits, 0.9)]
  
  # Create 'Risk_Level' column
  df$Risk_Level <- ifelse(df$person_id %in% names(ninety_percentile), "High",
                          ifelse(df$person_id %in% names(seventy_to_ninety), "Medium", "Low"))
  
  # Create 'Probability' column
  df$Probability <- ifelse(df$Risk_Level == "High", "90%",
                           ifelse(df$Risk_Level == "Medium", "50%", "10%"))
  
  # Concatenate MDC and remove repeating rows
  df <- df %>% group_by(`person_id`, MDC) %>%
    mutate(MDC_Comb = paste(MDC, collapse = ",")) %>%
    mutate(MDC_Comb = remove_dup(MDC_Comb)) %>%
    ungroup() %>%
    select(-MDC) %>%
    rename(MDC = MDC_Comb) 
  
  return(df)
}

accl_final_oreo2 <- accl_oreo_filtering(df_deduped_original)



accl_final_oreo2 <- accl_final_oreo2 %>%
  mutate(Risk_Level = case_when(
    pilot == 'MRI'~  'MSK High - MRI', 
    pilot == 'PT'~ 'MSK High - PT',
    pilot == 'Spine'~ 'MSK High - Spine',
    pilot == 'GI_pilot' ~ 'GI High - Endoscopy/Colonoscopy',
    TRUE ~ Risk_Level 
  ))

accl_final_oreo2 <- accl_final_oreo2 %>%
  mutate(Probability = case_when (
    pilot == 'MRI'~  '90%', 
    pilot == 'PT'~ '90%',
    pilot == 'Spine'~ '90%',
    pilot == 'GI_pilot' ~ '90%',
    TRUE ~ Probability,
  ))


### this do not call query is for any members who have and of these tasks already created on the Advocacy side - NO double contacts 


do_not_call <- setDT(dbGetQuery(con, "select  mc.person_id, mc.drvd_mbrshp_covrg_id, mc.full_nm, mc.birth_dtm, mc.rln_disp, mc.acp_mbr_flg, mc.work_loc, mc.group_nm
,mc.utc_period ,mc.org_nm
, Max(case when task_cd = 'outreach-rising-risk' then 1 else 0 end) as RisingRiskTasks
, Max(case when task_cd = 'outreach-case-management' then 1 else 0 end) as CMTasks
, Max(case when task_cd = 'outreach-transition-care-high' then 1 else 0 end) as TransitionCareTasks
, Max(case when rsn_cd ='pg-hcc' then 1 else 0 end) as HCCTasks
, Max(case when (rsn_cd ='care-outreach-cm' or rsn_cd = 'care-program-cm') then 1 else 0 end) as IssueCMTasks
from info_layer.task_dtl t
inner join info_layer.prs_mbrshp_covrg mc
on mc.drvd_mbrshp_covrg_id = t.drvd_mbrshp_covrg_id and mc.utc_period = 202603
where t.est_task_created_dtm >='2022-01-01'
-- and org_nm = 'STATE FARM'
and task_sts not in ('completed','entered-in-error','cancelled')
and rsn_cd not in ('provider-search','redirect','website-question','mobile-no-response','logistics','insurance-premium','id-card-request','healthplan-letter-questionnaire','family-member-access-request','complaint','benefits-question','appeal' ,'activate','research','mail','accumulator','call','message','general' ,'specialist','claim-bill-eob-question','healthcare-financial-account' ,'claim-form-submission','secure-email','consult','network-status-check','moc-tracking','happy-hour','intake')
and t.task_cd not in ('provider')
and datediff(year, mc.birth_dtm, getdate()) >= 18
group by mc.person_id, mc.drvd_mbrshp_covrg_id, mc.full_nm, mc.birth_dtm, mc.rln_disp, mc.acp_mbr_flg, mc.work_loc, mc.group_nm,mc.utc_period ,mc.org_nm
order by 1, 2, 3; "))





accl_final_oreo_original <- accl_final_oreo2 %>%
  distinct(person_id, MDC, .keep_all = TRUE)

accl_final_oreo_original <- accl_final_oreo_original %>%
  group_by(person_id) %>%
  reframe( across(everything()), MDC_Combined = paste(unique(MDC), collapse = "/")) %>%
  ungroup()

accl_final_oreo_original <- accl_final_oreo_original %>%
  mutate(cpt_desc_1 = if_else(!cpt_desc_1 %in% c('', NA), cpt_desc_1, icd_desc_1)) %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ''))) %>%
  mutate(icd_combined = ifelse((is.na(icd_desc_2) | icd_desc_2 == "") &
                                 (is.na(icd_desc_3) | icd_desc_3 == ""),
                               icd_desc_1,
                               str_c(icd_desc_1, icd_desc_2, icd_desc_3, sep = '; '))) %>%
  mutate(descrip_new_2 = str_c('Procedure Type: ', proc_type(cpt_1), ".")) %>%
  mutate(cpt_description = case_when(
    pilot == "MRI" ~ cpt_desc_1,
    pilot == "PT" ~ str_c(cpt_desc_1, ", (Physical Therapy)"),
    pilot == "GI_pilot" ~ cpt_desc_1,
    pilot == "Spine" ~ str_c(cpt_desc_1, ", (Spine)"),
    pilot == 'nopilots' ~ cpt_desc_1,
    TRUE ~ NA_character_
  )) %>%
  mutate(mdc_new = str_c("MDC: ", as.character(MDC_Combined))) %>%
  mutate(ICD_desc = paste(mdc_new, ". Diagnosis description: ", icd_combined, ". Procedure Description: ", cpt_description, ". ", descrip_new_2)) %>%
  select(person_id, ICD_desc)


accl_final_without_points_part2 <-accl_final_oreo2 %>%
  left_join(accl_final_oreo_original, by = "person_id")



#### this filter removes anyone who does not have a phone number, zip code, or subscriber information

accl_combined_filter <- function(accl_final_without_points_part2, do_not_call) {
  accl_final_without_points_part2$Data_Source <- accl_final_without_points_part2$subcompany
  now <- Sys.Date()
  accl_final_without_points_part2$dob <- as.Date(accl_final_without_points_part2$dob, origin = "1970-01-01")
  accl_final_without_points_part2$age <- (now - accl_final_without_points_part2$dob) / 365.25 
  accl_final_without_points_part2$age <- as.numeric(accl_final_without_points_part2$age)
  
  
  accl_final_without_points_part2$`2nd_MD_ID` <- ''
  accl_final_without_points_part2$Parent_ID <- ''
  accl_final_without_points_part2$Client_ID <- ''
  
  
  
  
  accl_final_without_points_part2$Has_NDC <- 1
  
  accl_final_without_points_part2$CPT_desc <- accl_final_without_points_part2$cpt_desc_1
  
  
  
  
  accl_final_without_points_part2 <- accl_final_without_points_part2[, c('2nd_MD_ID', 'Data_Source', 'subcompany', 'person_id', 'has_icd', 'has_cpt', 'Has_NDC', 'gender',
                               'age', 'zip', 'first_name', 'last_name', 'dob', 'start_date', 'icd_1', 'cpt_1', 'phone_num', 
                               'relationship_type', 'subscriber_id', 'subscriber_first_name', 'subscriber_last_name', 'subscriber_dob',
                               'subscriber_zip', 'Parent_ID', 'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc','MDC', 'external_id')]
  
  
  
  
  names(accl_final_without_points_part2) <- c('2nd_MD_ID', 'Data_Source', 'Subcompany', 'Native_ID', 'Has_ICD',
                         'Has_CPT', 'Has_NDC', 'Gender', 'Age', 'Zip', 'First_Name', 'Last_Name',
                         'DOB', 'Date_of_Service', 'ICD_1', 'CPT_1', 'PhoneNumber',
                         'Relationship_Type', 'Subscriber_ID', 'Subscriber_First_Name',
                         'Subscriber_Last_Name', 'Subscriber_DOB', 'Subscriber_Zip', 'Parent_ID',
                         'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc',
                         'MDC', 'external_id')
  
  
  
  # Limit data to only four rows per member
  accl_final_without_points_part2 <- accl_final_without_points_part2[order(accl_final_without_points_part2$Native_ID,accl_final_without_points_part2$Date_of_Service), ]  # Sort the data frame
  accl_final_without_points_part2 <- accl_final_without_points_part2[ave(seq_len(nrow(accl_final_without_points_part2)), accl_final_without_points_part2$Native_ID, accl_final_without_points_part2$Date_of_Service, FUN = seq_along) <= 4, ]
  accl_final_without_points_part2 <- as.data.frame(accl_final_without_points_part2) 
  
  accl_final_without_points_part2<- accl_final_without_points_part2[!(accl_final_without_points_part2$Native_ID %in% do_not_call$person_id), ]  # Do not call list
  
  accl_final_without_points_part2$Data_Source <- 'Accolade'
  

  
  
  accl_final_without_points_part2$id <- NULL
  
  accl_final_without_points_part2[is.na(accl_final_without_points_part2)] <- ""
  accl_final_without_points_part2$PhoneNumber <- as.character(accl_final_without_points_part2$PhoneNumber)
  accl_final_without_points_part2 <- accl_final_without_points_part2[!(accl_final_without_points_part2$PhoneNumber == ''), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!(accl_final_without_points_part2$PhoneNumber %in% c('999999999', '000000000', '0000000000', '9999999999', '1111111111')), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!grepl('-', accl_final_without_points_part2$PhoneNumber), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[nchar(accl_final_without_points_part2$PhoneNumber) == 10, ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!grepl("^1\\d{9}$", accl_final_without_points_part2$PhoneNumber), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!(accl_final_without_points_part2$PhoneNumber == '0'), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!((accl_final_without_points_part2$Relationship_Type %in% c('Child', 'Spouse', 'Disabled Child')) & (accl_final_without_points_part2$Subscriber_First_Name == '')), ]
  accl_final_without_points_part2$Zip <- as.character(accl_final_without_points_part2$Zip)
  
  accl_final_without_points_part2$Subscriber_Zip <- as.character(accl_final_without_points_part2$Subscriber_Zip)
  accl_final_without_points_part2 <- accl_final_without_points_part2[nchar(accl_final_without_points_part2$Zip) == 5, ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[nchar(accl_final_without_points_part2$Subscriber_Zip) == 5, ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[!(accl_final_without_points_part2$Zip == '00000'),]
  accl_final_without_points_part2 <- accl_final_without_points_part2[grep("^[0-9]+$", gsub(" ", "", accl_final_without_points_part2$Zip)), ]
  accl_final_without_points_part2 <- accl_final_without_points_part2[grep("^[0-9]+$", gsub(" ", "", accl_final_without_points_part2$Subscriber_Zip)), ]
  
  
  accl_final_without_points_part2$parent_id <- NULL
  accl_final_without_points_part2$DOB <- as.Date(accl_final_without_points_part2$DOB, origin = "1970-01-01")
  accl_final_without_points_part2$Date_of_Service <- format(as.Date(accl_final_without_points_part2$Date_of_Service), "%m/%d/%Y")
  accl_final_without_points_part2$Subscriber_DOB <- format(as.Date(accl_final_without_points_part2$Subscriber_DOB), "%m/%d/%Y")
  
  
  
  return(accl_final_without_points_part2)
}








accl_final_no_points <- accl_combined_filter(accl_final_without_points_part2, do_not_call)


### Gentiva does not want Reach to contact any members who have bariatric codes 

bariatric_codes <- read_csv("~/OneDrive - Accolade, Inc/Prior Auth Automation/bariatric_cpt_codes.csv")


accl_final_no_points <- accl_final_no_points %>%
  filter(!(external_id == 'GENTIVA' & CPT_1 %in% bariatric_codes))


########## This code filters out any members who has had any Requests in the past 180 days 
EMO_Dedupe <- read_csv("~/Desktop/Prior Auth Requests/Prior_Auth_03162026.csv")


EMO_Dedupe <- EMO_Dedupe %>%
  filter(request_load >= Sys.Date() - 180)

accl_final_no_points <- accl_final_no_points %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id)




  


accl_final_no_points$DOB <- format(as.Date(accl_final_no_points$DOB), "%m/%d/%Y" )



#### Oreo 3.0 

input_file_2 <- setDT(dbGetQuery(con, " WITH phone_number AS (
    SELECT pp.person_id,
           area_cd || phone_num                                                as phone_num,
           type_nm,
           ROW_NUMBER() OVER (PARTITION BY pp.person_id ORDER BY created_dt DESC) as rn_p
    FROM edw.person_phone pp
    WHERE preferred_flg IS TRUE
),

    current_mbrshp_1 AS (
        SELECT a.customer_nm AS Subcompany,
                a.customer_nm as external_id,
            b.person_id,
              b.drvd_mbrshp_covrg_id,
               b.gender_cd AS Gender,
               INITCAP(b.rln_disp) as Relationship_Type,
               b.state_cd,
               ROUND(DATEDIFF(day, b.birth_dtm, GETDATE())/365,0) AS age,
              b.zip_cd AS Zip,
              a.firstname as First_Name,
            a.lastname as Last_Name,
              b.birth_dtm AS DOB,
              b.utc_period,
              b.drvd_acct_id,
               ROW_NUMBER() OVER (PARTITION BY b.person_id ORDER BY b.created_dt DESC) AS RN
        FROM info_layer.prs_mbrshp_covrg b
        INNER JOIN mbr.mbr_elig_emo a on a.person_id = b.person_id
        WHERE b.utc_period >= TO_CHAR(getdate() - 30, 'YYYYMM')
    ),

     current_mbrshp_2 AS (
        SELECT *
        FROM current_mbrshp_1
        WHERE Relationship_Type ILIKE '%SELF%'
    ),

      current_mbrshp AS (
        SELECT a.*,
               b.person_id as Subscriber_ID,
               b.First_Name as Subscriber_First_Name,
               b.Last_Name as Subscriber_Last_Name,
               b.DOB::date as Subscriber_DOB,
               b.ZIP as Subscriber_Zip
        FROM current_mbrshp_1 a
        LEFT JOIN current_mbrshp_2 b ON a.drvd_acct_id = b.drvd_acct_id
    ),

     relevant_mbrshp AS (
        SELECT DISTINCT person_id,
               First_Name,
               Last_Name,
               Gender,
               DOB,
               Subcompany,
               state_cd, 
               external_id, 
               Relationship_Type,
               Zip,
               Subscriber_ID,
               Subscriber_First_Name,
               Subscriber_Last_Name,
               Subscriber_DOB,
               Subscriber_Zip,
               utc_period
        FROM current_mbrshp cm WHERE rn=1
    ),
 

     final_membership AS (
         SELECT rb.person_id,
                first_name,
                last_name,
                gender,
                dob,
                subcompany,
                external_id,
                relationship_type,
                zip,
                subscriber_id,
                subscriber_first_name,
                subscriber_last_name,
                subscriber_dob,
                subscriber_zip,
                phone_num,
                1 AS Has_ICD,
                1 AS Has_CPT,
                1 AS Has_NDC
         FROM relevant_mbrshp rb
         LEFT JOIN (SELECT * FROM phone_number WHERE rn_p = 1) p ON rb.person_id = p.person_id
         WHERE Subcompany NOT IN ('AMERICAN AIRLINES')
     )

   SELECT fm.person_id,
          fm.first_name,
           fm.last_name,
           fm.gender,
           fm.dob,
           fm.subcompany,
           fm.external_id,
           fm.relationship_type,
           fm.zip,
           fm.subscriber_id,
           fm.subscriber_first_name,
           fm.subscriber_last_name,
           fm.subscriber_dob,
           fm.subscriber_zip,
           fm.phone_num,
           fm.Has_ICD,
           fm.Has_CPT,
           fm.Has_NDC,
         to_char(serv_from_dt, 'YYYY-MM-DD') as start_date,
          diag_cd_1 AS ICD_1,
          diag_cd_2 as ICD_2,
          diag_cd_3 as ICD_3,
         diag_nm_1 AS ICD_desc_1,
          diag_nm_2 AS ICD_desc_2,
          diag_nm_3 AS ICD_desc_3,
          proc_cd_1 AS CPT_1,
          proc_cd_2 AS CPT_2,
          proc_cd_3 AS CPT_3,
          proc_nm_1 AS CPT_desc_1,
          proc_nm_2 as CPT_desc_2, 
          proc_nm_3 AS CPT_desc_3
           FROM info_layer.prs_med_clm_line_item_dtl clm
        INNER JOIN final_membership fm ON clm.person_id = fm.person_id
         where start_date >= '2025-10-21' AND start_date <= '2026-02-21' 
         AND clm.person_id NOT IN (SELECT DISTINCT patient_id
                           FROM edw.preferences p
                           WHERE p.do_not_contact_flg = 1) AND subcompany IN ('SEVEN ELEVEN', 'LOWE''S', 'ADVANTAGE SOLUTIONS',  'API GROUP',
                                                                             'AQR CAPITAL MANAGEMENT',   'ARKANSAS BLUE CROSS BLUE SHIELD', 'ARKANSAS STATE UNIVERSITY',  'BAD BOY MOWERS',  'BECTON DICKINSON AND COMPANY', 'BANYAN TREATMENT CENTERS' , 'BRIDGE INVESTMENT GROUP', 'BOX INC', 'BRYCE CORP', 'CALIBER', 
                                                                             'CETERA FINANCIAL',  'CHATSWORTH PRODUCTS INC' , 'CITY OF REDDING', 'CITY OF LOMPOC', 'CITY OF SILOAM SPRINGS' , 'COUNTY OF SANTA BARBARA',   'CITY OF SEATTLE' ,  'CITY OF YUBA CITY' ,  'COOPER STANDARD' , 'COUNTY OF LAKE'  , 'DEVRY UNIVERSITY' ,
                                                                             'DAY AND ZIMMERMANN' , 'DWYEROMEGA',  'EMPOWER HEALTHCARE SOLUTIONS', 'ENERCON',  'FIRST AMERICAN FINANCIAL', 'GE HEALTHCARE',  'GENERAL MILLS',   'GENTIVA', 
                                                                              'HUMANA',   'INTERNATIONAL PAPER','INTUITIVE SURGICAL',   'LANDRYS INC',  'LIGHTHOUSE AUTISM CENTER', 'LIFE AND SPECIALTY VENTURES', 'LEADVENTURE',  'LEXICON INC','MOOG', 'MILESTONE TECHNOLOGIES',
                                                                            'MOFFITT CANCER CENTER',  'MCKESSON', 'NEVADA GOLD MINES',  
                                                                            'OTC BRANDS', 'PAYPAL', 'PAYLOCITY', 'PEDIATRIC ASSOCIATES', 'PERATON', 'PTA PLASTICS',  'PUBLIC STORAGE',  'RAYMOND JAMES FINANCIAL', 'REVERE PLASTICS SYSTEMS', 'RED RIVER TECHNOLOGY',
                                                                                 'ROCKET SOFTWARE',  'SA RECYCLING' , 'SAN LUIS OBISPO COUNTY', 'STANDARDAERO', 'SAFRAN USA', 'SEDGWICK','SHAMROCK FOODS COMPANY', 'STATE FARM', 'SOUTH COAST AIR QUALITY MANAGEMENT DISTRICT', 'TEVA PHARMACEUTICALS', 'THE FRIEDKIN GROUP',
                                                                                'THE KNOT WORLDWIDE',  'TUTOR PERINI',  'TORY BURCH',   'UNITED MUSCULOSKELETAL PARTNERS',
                                                                              'UNITED AIRLINES',  'WASHINGTON TEAMSTERS WELFARE TRUST', 'WW GRAINGER',  'WAWA','SPECIAL DISTRICT RISK MANAGEMENT AUTHORITY', 'GOLDEN STATE RISK MANAGEMENT AUTHORITY')






     AND DATEDIFF(YEAR, dob, getdate()) >= 18;
")) 


input_file_3 <- input_file_2 %>%
  filter(person_id %in% EDW_elig$person_id)



new_prelim_procedure <- read_csv("~/OneDrive - Accolade, Inc/Downloads copy/new_prelim_procedures_codes.csv")


final_proc_v3_msk <- input_file_3 %>%
  left_join(new_prelim_procedure, by = "cpt_1") %>%
  subset(( icd_1 >= 'M00' & icd_1 <= 'M99')|  (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')|
           (icd_2 >= 'M00' & icd_2 <= 'M99')| (icd_2 >= 'T84' & icd_2 < 'T86')|(icd_2 >= 'R25' & icd_2 < 'R30')|
           (icd_3 >= 'M00' & icd_3 <= 'M99')|  (icd_3 >= 'T84' & icd_3 < 'T86')|(icd_3 >= 'R25' & icd_3 < 'R30'))%>%
  distinct(person_id, start_date, cpt_1, .keep_all = TRUE) 





prelim_proc_msk <-  read_csv("~/OneDrive - Accolade, Inc/Georgina New files/prelim_pointsv2.csv")


final_proc_v3_msk <- final_proc_v3_msk %>%
  filter(procedure_group %in% prelim_proc_msk$pot_type)

df_result_msk <- final_proc_v3_msk %>%
  left_join(prelim_proc_msk, by = c("procedure_group" = "pot_type")) %>%
  group_by(person_id, procedure_group, ramp, Points) %>%
  summarize(vol_pots = n_distinct(paste(person_id, start_date,  sep = "")), .groups = 'drop')





result_v2_msk <- df_result_msk %>%
  group_by(person_id, procedure_group) %>%
  mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, Points)) %>%
  select(person_id, procedure_group,  procedure_type_points)




transposed_df_msk <- pivot_wider(data = result_v2_msk, 
                                 names_from = procedure_group, 
                                 values_from = procedure_type_points)


transposed_df_msk[is.na(transposed_df_msk)] <- 0 




final_dfv3_msk <- transposed_df_msk %>%
  as_tibble() %>%
  mutate(total_points = rowSums(select(., 2:36), na.rm = TRUE))


accl_final_df_points <- final_dfv3_msk %>%
  filter(total_points >= 3)%>%
  select(person_id ,  total_points)%>%
  filter(
    !(person_id %in% oreo_past_results$Native_ID),
    !(person_id %in% EMO_Dedupe$person_id)
  )





accl_df_points_final_v2 <- accl_final_df_points %>%
  left_join(final_proc_v3_msk, by = "person_id")%>%
  filter(!external_id %in% c('HUMANA', 'GENTIVA'))







accl_df_points_final_v2$MDC <- 'MSK'
accl_df_points_final_v2$pilot <- 'Points'

##### cleaning up file now 

df_combined <- accl_df_points_final_v2

cols_to_drop <- c('ICD_4', 'ICD_5', 'ICD_6', 'ICD_7', 'ICD_8', 'ICD_9', 'icd_10', 'icd_11', 'icd_12',
                  'icd_13', 'icd_14', 'icd_15', 'icd_16', 'CPT_4', 'CPT_5', 'CPT_6', 'CPT_7', 'CPT_8', 'CPT_9',
                  'cpt_10', 'cpt_11', 'cpt_12', 'cpt_13', 'NDC_1', 'NDC_2', 'NDC_3', 'NDC_4', 'NDC_5', 'NDC_6',
                  'NDC_7', 'NDC_8', 'NDC_9', 'NDC_10', 'NDC_11', 'NDC_12', 'NDC_13', 'CPT_2', 'CPT_3', 'ICD_2', 'ICD_3' , 'icd_2', 'icd_3', 'cpt_2', 'cpt_3')
df_combined <- df_combined[,!(names(df_combined) %in% cols_to_drop)]


##remove SAIC 


df_combined<- df_combined %>%
  mutate(rank = case_when(
    pilot == 'Points' ~ 1,
    pilot == 'MRI'~ 2,
    pilot == 'PT'~ 3,
    pilot == 'Spine' ~ 4,
    pilot == 'Onc_pilot'~ 5,
    pilot == 'Cardio_pet_pilot'~ 6,
    pilot == 'GI_pilot' ~ 7, 
    pilot == 'nopilots'~ 8
  ))


df_deduped <- df_combined %>%
  group_by(person_id) %>%
  filter(rank == min(rank))











remove_dup <- function(strng) {
  strng <- strsplit(strng, ",")[[1]]
  strng <- unique(strng)
  return(paste(strng, collapse = ","))
}



accl_final_v2 <- accl_oreo_filtering(df_deduped)



accl_final_v2 <- accl_final_v2 %>%
  mutate(Risk_Level = case_when(
    pilot == 'Points'~  'MSK High - Predictive Points', 
    pilot == 'MRI'~  'MSK High - MRI', 
    pilot == 'PT'~ 'MSK High - PT',
    pilot == 'Spine'~ 'MSK High - Spine',
    pilot == 'Onc_pilot'~ 'Oncology High - Benign Tumor',
    pilot == 'Cardio_pet_pilot' ~ 'Cardio High - PET',
    pilot == 'GI_pilot' ~ 'GI High - Endoscopy/Colonoscopy', 
    TRUE ~ Risk_Level
  ))



accl_final_v2 <- accl_final_v2 %>%
  mutate(Probability = case_when (
    pilot == 'Points'~  '90%', 
    pilot == 'MRI'~  '90%', 
    pilot == 'PT'~ '90%',
    pilot == 'Spine'~ '90%',
    pilot == 'Onc_pilot'~ '90%',
    pilot == 'Cardio_pet_pilot' ~ '90%',
    pilot == 'GI_pilot' ~ ' 90%', 
    TRUE ~ Probability
  ))




accl_final_v3 <- accl_final_v2 %>%
  distinct(person_id, procedure_group,    .keep_all = TRUE)

accl_final_v3 <- accl_final_v3 %>%
  group_by(person_id) %>%
  reframe( across(everything()), procedure_group_combined = paste(unique(procedure_group), collapse = ";")) %>%
  ungroup()


accl_final <- accl_final_v3 %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ''))) %>%
  mutate(icd_combined = ifelse((is.na(icd_desc_2) | icd_desc_2 == "") &
                                 (is.na(icd_desc_3) | icd_desc_3 == ""),
                               icd_desc_1,
                               str_c(icd_desc_1, icd_desc_2, icd_desc_3, sep = '; '))) %>%
  mutate(descrip_new_2 = str_c('Procedure Type: ', proc_type, ".")) %>%
  mutate(cpt_description = case_when(
    pilot == "Points" ~ procedure_group, 
    pilot == "PT" ~ str_c(cpt_desc_1, ", (Physical Therapy)"),
    pilot == "GI_pilot" ~ cpt_desc_1,
    pilot == "Spine" ~ str_c(cpt_desc_1, ", (Spine)"),
    pilot == 'nopilots' ~ cpt_desc_1,
    TRUE ~ NA_character_
  )) %>%
  mutate(mdc_new = str_c("MDC: ", as.character(MDC))) %>%
  mutate(ICD_desc = paste(mdc_new,  ". Diagnosis description: ", icd_combined,   ". Procedure Description: ", cpt_1, procedure_group_combined, ". ", descrip_new_2 ))

### cleaning up file removing from do not call list and phone numbers 


accl_combined_filter <- function(accl_final, do_not_call) {
  accl_final$Data_Source <- accl_final$subcompany
  now <- Sys.Date()
  accl_final$dob <- as.Date(accl_final$dob, origin = "1970-01-01")
  accl_final$age <- (now - accl_final$dob) / 365.25 
  accl_final$age <- as.numeric(accl_final$age)
  
  
  accl_final$`2nd_MD_ID` <- ''
  accl_final$Parent_ID <- ''
  accl_final$Client_ID <- ''
  
  
  
  
  accl_final$Has_NDC <- 1
  accl_final$CPT_desc <- accl_final$cpt_desc_1
  
  
  
  
  
  accl_final <- accl_final[, c('2nd_MD_ID', 'Data_Source', 'subcompany', 'person_id', 'has_icd', 'has_cpt', 'Has_NDC', 'gender',
                               'age', 'zip', 'first_name', 'last_name', 'dob', 'start_date', 'icd_1', 'cpt_1', 'phone_num', 
                               'relationship_type', 'subscriber_id', 'subscriber_first_name', 'subscriber_last_name', 'subscriber_dob',
                               'subscriber_zip', 'Parent_ID', 'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc','MDC', 'total_points', 'external_id')]
  
  
  
  
  names(accl_final) <- c('2nd_MD_ID', 'Data_Source', 'Subcompany', 'Native_ID', 'Has_ICD',
                         'Has_CPT', 'Has_NDC', 'Gender', 'Age', 'Zip', 'First_Name', 'Last_Name',
                         'DOB', 'Date_of_Service', 'ICD_1', 'CPT_1', 'PhoneNumber',
                         'Relationship_Type', 'Subscriber_ID', 'Subscriber_First_Name',
                         'Subscriber_Last_Name', 'Subscriber_DOB', 'Subscriber_Zip', 'Parent_ID',
                         'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc',
                         'MDC', 'Risk Score', 'external_id')
  
  
  
  # Limit data to only four rows per member
  accl_final <- accl_final[order(accl_final$Native_ID, accl_final$Date_of_Service), ]  # Sort the data frame
  accl_final <- accl_final[ave(seq_len(nrow(accl_final)), accl_final$Native_ID, accl_final$Date_of_Service, FUN = seq_along) <= 4, ]
  accl_final <- as.data.frame(accl_final) 
  
  accl_final <- accl_final[!(accl_final$Native_ID %in% do_not_call$person_id), ]  # Do not call list
  
  accl_final$Data_Source <- 'Accolade'
  
  
  
  
  accl_final$id <- NULL
  
  accl_final[is.na(accl_final)] <- ""
  accl_final$PhoneNumber <- as.character(accl_final$PhoneNumber)
  accl_final <- accl_final[!(accl_final$PhoneNumber == ''), ]
  accl_final <- accl_final[!(accl_final$PhoneNumber %in% c('999999999', '000000000', '0000000000', '9999999999', '1111111111')), ]
  accl_final <- accl_final[!grepl('-', accl_final$PhoneNumber), ]
  accl_final <- accl_final[nchar(accl_final$PhoneNumber) == 10, ]
  accl_final <- accl_final[!grepl("^1\\d{9}$", accl_final$PhoneNumber), ]
  accl_final <- accl_final[!(accl_final$PhoneNumber == '0'), ]
  accl_final <- accl_final[!((accl_final$Relationship_Type %in% c('Child', 'Spouse', 'Disabled Child')) & (accl_final$Subscriber_First_Name == '')), ]
  accl_final$Zip <- as.character(accl_final$Zip)
  
  accl_final$Subscriber_Zip <- as.character(accl_final$Subscriber_Zip)
  accl_final <- accl_final[nchar(accl_final$Zip) == 5, ]
  accl_final <- accl_final[nchar(accl_final$Subscriber_Zip) == 5, ]
  accl_final <- accl_final[grep("^[0-9]+$", gsub(" ", "", accl_final$Zip)), ]
  accl_final <- accl_final[grep("^[0-9]+$", gsub(" ", "", accl_final$Subscriber_Zip)), ]
  
  
  accl_final$parent_id <- NULL
  accl_final$DOB <- as.Date(accl_final$DOB, origin = "1970-01-01")
  accl_final$Date_of_Service <- format(as.Date(accl_final$Date_of_Service), "%m/%d/%Y")
  accl_final$Subscriber_DOB <- format(as.Date(accl_final$Subscriber_DOB), "%m/%d/%Y")
  
  
  
  return(accl_final)
}




accl_final <- accl_combined_filter(accl_final, do_not_call)







accl_final$DOB <- format(as.Date(accl_final$DOB), "%m/%d/%Y" )
 



accl_final <- accl_final %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!external_id %in% c('HUMANA', 'GENTIVA'))





accl_final_distinct <- accl_final %>%
  distinct(Native_ID ,.keep_all = TRUE)


accl_final_without_points_distinct <- accl_final_without_points  %>%
  distinct(Native_ID, .keep_all = TRUE)






dup_value0725 <- accl_final_distinct %>%
  mutate(included_old_oreo= case_when((Native_ID %in% accl_final_without_points_distinct$Native_ID)  ~ 1,
                                      TRUE ~ 0))



accl_final_final_final0925 <- dup_value0725   %>%
  mutate(Risk_Level = case_when(included_old_oreo == 0 ~ 'MSK High - N', 
                                included_old_oreo == 1 ~ 'MSK High - B', 
                                TRUE ~ NA))










accl_final_0925_july_new <-accl_final_final_final0925[, !(names(accl_final_final_final0925) %in% c("Risk Score", 'included_old_oreo')) ]





accl_final_0925_original <- accl_final_without_points[!(accl_final_without_points$Native_ID %in% accl_final_0925_july_new$Native_ID),]



final_all_accl0925 <- rbind(accl_final_0925_july_new , accl_final_0925_original)


### making sure if they have reach enabled 

reach_enabled_oreo <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/Accolade Oreo Run/corp_enabled.csv")



final_all_accl0925<- final_all_accl0925%>%
  filter(external_id %in% reach_enabled_oreo$external_id)%>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!(external_id %in% c('HUMANA', 'GENTIVA') & MDC == 'MSK')) %>%
  filter(!(external_id == 'GENTIVA' & CPT_1 %in% bariatric_codes )) %>%
  filter(!((external_id %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES', 'MOFFITT CANCER CENTER', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                               'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY') & MDC == 'Oncology')))


original_final_msk <- final_all_accl0925



####oncology 
input_file_3_onc <- input_file_3


prelim_proc_onc <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/oncology_procedure_points.csv")
diagnosis_codes_onc <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/Accolade Oreo Run/diagnosis_codes_oncology.csv")
diagnosis_oncology <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/diagnosis_oncology.csv")

breast_had_procedure <-read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/Procedures_Oncology_after.csv")

today <- Sys.Date()


df_filtered <- input_file_3_onc %>%
  filter(start_date <= today - 14)

final_proc_v2_breast <- input_file_3_onc  %>%
  subset(
    (icd_1 >= 'C50' & icd_1 < 'C51') | (icd_2 >= 'C50' & icd_2 < 'C51') | (icd_3 >= 'C50' & icd_3 < 'C51') ) %>%
  filter(!( icd_1 == 'Z853' | icd_2 == 'Z853' | icd_3 == 'Z853')) %>%
  distinct(person_id, start_date)


final_proc_breast_v2 <- input_file_3_onc  %>%
  filter(person_id %in% final_proc_v2_breast$person_id) %>%
  filter( (icd_1 >= 'C50' & icd_1 < 'C51') | (icd_2 >= 'C50' & icd_2 < 'C51') | (icd_3 >= 'C50' & icd_3 < 'C51')|
            (icd_1 >= 'D05' & icd_1 < 'D06') | (icd_2 >= 'D05' & icd_2 < 'D06') | (icd_3 >= 'D05' & icd_3 < 'D06') |
            (icd_1 >= 'R59' & icd_1 < 'R60') | (icd_2 >= 'R59' & icd_2 < 'R60') | (icd_3 >= 'R59' & icd_3 < 'R60') |
            (icd_1 == 'C7981') | (icd_2 == 'C7981') | (icd_3 == 'C7981') | (icd_1 %in% diagnosis_oncology$icd_1) | (icd_2 %in% diagnosis_oncology$icd_1) | (icd_3 %in% diagnosis_oncology$icd_1)
  )



onc_had_breast_procedure <- input_file_3 %>%
  filter((cpt_1 %in%  breast_had_procedure$cpt_code)| (cpt_2 %in%  breast_had_procedure$cpt_code) | (cpt_3 %in%  breast_had_procedure$cpt_code) ) %>%
  distinct(person_id)






onc_proc_final <- final_proc_breast_v2 %>%
  filter(cpt_1 %in% prelim_proc_onc$cpt_code) 






df_volume <- onc_proc_final %>%
  left_join(prelim_proc_onc, by = c("cpt_1" = "cpt_code" )) %>%
  mutate(screening = case_when(cpt_1 %in% c('77067', '77063') ~ 1, TRUE ~ 0)) %>%
  mutate(diagnositic = case_when(cpt_1 %in% c('77065', '77066', 'G0279', '77061', '77062') ~ 1,  TRUE ~ 0  )) %>%
  group_by(person_id,  procedure_description,  ramp, points ,   screening ,diagnositic) %>%      
  summarize(vol_pots = n_distinct(paste(person_id, start_date,  sep = "")), .groups = 'drop') 



df_original_volume <- onc_proc_final %>%
  left_join(prelim_proc_onc, by = c("cpt_1" = "cpt_code" )) %>%
  group_by(person_id,  procedure_description,  ramp, points) %>%      
  summarize(vol_pots = n_distinct(paste(person_id, start_date,  sep = "")), .groups = 'drop') 



df_volume_screening <- df_volume %>%
  filter(screening == 1 ) %>%
  select(person_id, screening)

df_volume_diag <- df_volume %>%
  filter(diagnositic == 1) %>%
  select(person_id, diagnositic )


diag_scree <- df_volume_screening %>%
  merge(df_volume_diag, by = 'person_id') %>%
  mutate(procedure_description = 'Screening/Diagnostic') %>%
  mutate( 
    ramp =  3, 
    points = 3,
    vol_pots = 1) %>%
  distinct(person_id, .keep_all = TRUE) %>%
  select(person_id, ramp, points, vol_pots, procedure_description)


df_volume_v2 <- rbind(diag_scree, df_original_volume)

df_volume_v2$points <- as.numeric(df_volume_v2$points)
df_volume_v2$ramp <- as.numeric(df_volume_v2$ramp)

df_volume_v2$procedure_description <- as.character(df_volume_v2$procedure_description)



result_v2_onc <-df_volume_v2  %>%
  group_by(person_id, procedure_description) %>%
  mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, points)) %>% 
  mutate(procedure_type_points_sum = procedure_type_points*vol_pots )%>%
  select(person_id, procedure_description,  procedure_type_points)





transposed_df_onc <- pivot_wider(data = result_v2_onc, 
                                 names_from = procedure_description, 
                                 values_from = procedure_type_points)


transposed_df_onc[is.na(transposed_df_onc)] <- 0 






final_dfv3_onc <- transposed_df_onc %>%
  as_tibble() %>%
  mutate(total_points = rowSums(select(., 2:19), na.rm = TRUE))


accl_final_df_points_onc <- final_dfv3_onc  %>%
  filter(total_points >= 10)

df_deduped_v2_onc <- accl_final_df_points_onc %>%
  select(person_id ,  total_points) %>%
  filter(
    !(person_id %in% oreo_past_results$Native_ID),
    !(person_id %in% EMO_Dedupe$person_id), 
    !(person_id %in% onc_had_breast_procedure$person_id)
  )




accl_df_points_final_v2_onc <-df_deduped_v2_onc %>%
  left_join(onc_proc_final, by = "person_id") 









accl_df_points_final_v2_onc$MDC <- 'Oncology'
accl_df_points_final_v2_onc$pilot <- 'Breast Cancer'



df_combined_onc <- accl_df_points_final_v2_onc


df_combined_onc <- df_combined_onc[,!(names(df_combined_onc) %in% cols_to_drop)]




remove_dup <- function(strng) {
  strng <- strsplit(strng, ",")[[1]]
  strng <- unique(strng)
  return(paste(strng, collapse = ","))
}


accl_oreo_filtering <- function(file) {
  df <- file
  
  # Calculate percentiles
  unique_visits <- table(df$person_id, df$start_date)
  unique_visits <- rowSums(unique_visits > 0)
  ninety_percentile <- unique_visits[unique_visits >= quantile(unique_visits, 0.9)]
  seventy_to_ninety <- unique_visits[unique_visits >= quantile(unique_visits, 0.7) &
                                       unique_visits < quantile(unique_visits, 0.9)]
  
  # Create 'Risk_Level' column
  df$Risk_Level <- ifelse(df$person_id %in% names(ninety_percentile), "High",
                          ifelse(df$person_id %in% names(seventy_to_ninety), "Medium", "Low"))
  
  # Create 'Probability' column
  df$Probability <- ifelse(df$Risk_Level == "High", "90%",
                           ifelse(df$Risk_Level == "Medium", "50%", "10%"))
  
  # Concatenate MDC and remove repeating rows
  df <- df %>% group_by(`person_id`, MDC) %>%
    mutate(MDC_Comb = paste(MDC, collapse = ",")) %>%
    mutate(MDC_Comb = remove_dup(MDC_Comb)) %>%
    ungroup() %>%
    select(-MDC) %>%
    rename(MDC = MDC_Comb) 
  
  return(df)
}

accl_final_v2_onc <- accl_oreo_filtering(df_combined_onc)



accl_final_v2_onc  <- accl_final_v2_onc  %>%
  mutate(Risk_Level = case_when(
    pilot == 'Breast Cancer'~  'Breast Cancer High - Predictive Points', 
    pilot == 'MRI'~  'MSK High - MRI', 
    pilot == 'PT'~ 'MSK High - PT',
    pilot == 'Spine'~ 'MSK High - Spine',
    pilot == 'Onc_pilot'~ 'Oncology High - Benign Tumor',
    pilot == 'Cardio_pet_pilot' ~ 'Cardio High - PET',
    pilot == 'GI_pilot' ~ 'GI High - Endoscopy/Colonoscopy', 
    TRUE ~ Risk_Level
  ))


accl_final_v2_onc <- accl_final_v2_onc  %>%
  mutate(Probability = case_when (
    pilot == 'Breast Cancer'~  '90%', 
    pilot == 'MRI'~  '90%', 
    pilot == 'PT'~ '90%',
    pilot == 'Spine'~ '90%',
    pilot == 'Onc_pilot'~ '90%',
    pilot == 'Cardio_pet_pilot' ~ '90%',
    pilot == 'GI_pilot' ~ ' 90%', 
    TRUE ~ Probability
  ))





accl_final_v3_onc <- accl_final_v2_onc %>%
  distinct(person_id, cpt_1,    .keep_all = TRUE)

accl_final_v3_onc <- accl_final_v3_onc %>%
  group_by(person_id) %>%
  reframe( across(everything()), procedure_group_combined = paste(unique(cpt_desc_1), collapse = ";")) %>%
  ungroup()


accl_final_onc <- accl_final_v3_onc  %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ''))) %>%
  mutate(icd_combined = ifelse((is.na(icd_desc_2) | icd_desc_2 == "") &
                                 (is.na(icd_desc_3) | icd_desc_3 == ""),
                               icd_desc_1,
                               str_c(icd_desc_1, icd_desc_2, icd_desc_3, sep = '; '))) %>%
  mutate(descrip_new_2 = str_c('Procedure Type: ', cpt_desc_1, ".")) %>%
  mutate(cpt_description = case_when(
    pilot == "Breast Cancer" ~ cpt_desc_1, 
    pilot == "PT" ~ str_c(cpt_desc_1, ", (Physical Therapy)"),
    pilot == "GI_pilot" ~ cpt_desc_1,
    pilot == "Spine" ~ str_c(cpt_desc_1, ", (Spine)"),
    pilot == 'nopilots' ~ cpt_desc_1,
    TRUE ~ NA_character_
  )) %>%
  mutate(mdc_new = str_c("MDC: ", as.character(MDC))) %>%
  mutate(ICD_desc = paste(mdc_new,  ". Diagnosis description: ", icd_combined,   ". Procedure Description: ", cpt_1, procedure_group_combined, ". ", descrip_new_2 ))





accl_final_onc <- as.data.frame(accl_final_onc)


accl_combined_filter <- function(accl_final_onc, do_not_call) {
  accl_final_onc$Data_Source <- accl_final_onc$subcompany
  now <- Sys.Date()
  accl_final_onc$dob <- as.Date(accl_final_onc$dob, origin = "1970-01-01")
  accl_final_onc$age <- (now - accl_final_onc$dob) / 365.25 
  accl_final_onc$age <- as.numeric(accl_final_onc$age)
  
  
  accl_final_onc$`2nd_MD_ID` <- ''
  accl_final_onc$Parent_ID <- ''
  accl_final_onc$Client_ID <- ''
  
  accl_final_onc$Data_Source <- 'Accolade'
  
  
  accl_final_onc$Has_NDC <- 1
  accl_final_onc$CPT_desc <- accl_final_onc$cpt_desc_1
  
  
  
  
  
  accl_final_onc <- accl_final_onc[, c('2nd_MD_ID',  'Data_Source', 'subcompany', 'person_id', 'has_icd', 'has_cpt', 'Has_NDC', 'gender',
                                       'age', 'zip', 'first_name', 'last_name', 'dob', 'start_date', 'icd_1', 'cpt_1', 'phone_num', 
                                       'relationship_type', 'subscriber_id', 'subscriber_first_name', 'subscriber_last_name', 'subscriber_dob',
                                       'subscriber_zip', 'Parent_ID', 'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc','MDC',  'total_points', 'external_id')]
  
  
  
  
  names(accl_final_onc) <- c('2nd_MD_ID', 'Data_Source', 'Subcompany', 'Native_ID', 'Has_ICD',
                             'Has_CPT', 'Has_NDC', 'Gender', 'Age', 'Zip', 'First_Name', 'Last_Name',
                             'DOB', 'Date_of_Service', 'ICD_1', 'CPT_1', 'PhoneNumber',
                             'Relationship_Type', 'Subscriber_ID', 'Subscriber_First_Name',
                             'Subscriber_Last_Name', 'Subscriber_DOB', 'Subscriber_Zip', 'Parent_ID',
                             'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc',
                             'MDC', 'Risk Score', 'external_id')
  
  
  
  # Limit data to only four rows per member
  accl_final_onc <-accl_final_onc[order(accl_final_onc$Native_ID,accl_final_onc$Date_of_Service), ]  # Sort the data frame
  accl_final_onc <- accl_final_onc[ave(seq_len(nrow(accl_final_onc)), accl_final_onc$Native_ID, accl_final_onc$Date_of_Service, FUN = seq_along) <= 4, ]
  accl_final_onc <- as.data.frame(accl_final_onc)
  
  accl_final_onc <-accl_final_onc[!(accl_final_onc$Native_ID %in% do_not_call$person_id), ]  # Do not call list
  
  
  
  
  
  
  accl_final_onc$id <- NULL
  
  accl_final_onc[is.na(accl_final_onc)] <- ""
  accl_final_onc$PhoneNumber <- as.character(accl_final_onc$PhoneNumber)
  accl_final_onc  <- accl_final_onc[!(accl_final_onc$PhoneNumber == ''),]
  accl_final_onc <- accl_final_onc[!(accl_final_onc$PhoneNumber %in% c('999999999', '000000000', '0000000000', '9999999999', '1111111111')), ]
  accl_final_onc <- accl_final_onc[!grepl('-',accl_final_onc$PhoneNumber), ]
  accl_final_onc  <- accl_final_onc[nchar(accl_final_onc$PhoneNumber) == 10, ]
  accl_final_onc <- accl_final_onc[!grepl("^1\\d{9}$", accl_final_onc$PhoneNumber), ]
  accl_final_onc <- accl_final_onc[!(accl_final_onc$PhoneNumber == '0'), ]
  accl_final_onc <- accl_final_onc[!((accl_final_onc$Relationship_Type %in% c('Child', 'Spouse', 'Disabled Child')) & (accl_final_onc$Subscriber_First_Name == '')), ]
  accl_final_onc$Zip <- as.character(accl_final_onc$Zip)
  
  accl_final_onc$Subscriber_Zip <- as.character(accl_final_onc$Subscriber_Zip)
  accl_final_onc<- accl_final_onc[nchar(accl_final_onc$Zip) == 5, ]
  accl_final_onc<- accl_final_onc[nchar(accl_final_onc$Subscriber_Zip) == 5, ]
  accl_final_onc<- accl_final_onc[!(accl_final_onc$Zip == '00000'),]
  accl_final_onc<- accl_final_onc[grep("^[0-9]+$", gsub(" ", "", accl_final_onc$Zip)), ]
  accl_final_onc<- accl_final_onc[grep("^[0-9]+$", gsub(" ", "", accl_final_onc$Subscriber_Zip)), ]
  
  
  accl_final_onc$parent_id <- NULL
  accl_final_onc$DOB <- as.Date(accl_final_onc$DOB, origin = "1970-01-01")
  accl_final_onc$Date_of_Service <- format(as.Date(accl_final_onc$Date_of_Service), "%m/%d/%Y")
  accl_final_onc$Subscriber_DOB <- format(as.Date(accl_final_onc$Subscriber_DOB), "%m/%d/%Y")
  
  
  
  return(accl_final_onc)
}




accl_final_onc <- accl_combined_filter(accl_final_onc, do_not_call)



accl_final_onc$DOB <- format(as.Date(accl_final_onc$DOB), "%m/%d/%Y" )



accl_final_onc <- accl_final_onc %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!Subcompany %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES', 'MOFFITT CANCER CENTER', 'THE HANOVER INSURANCE GROUP', 'COMMSCOPE', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                    'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY' ))







accl_final_0925_onc <- accl_final_onc %>%
  distinct(Native_ID ,.keep_all = TRUE)


final_0925_original_distinct  <- original_final_msk  %>%
  distinct(Native_ID, .keep_all = TRUE)





dup_value0925_onc <-accl_final_0925_onc  %>%
  mutate(included_old_oreo= case_when((Native_ID %in% final_0925_original_distinct$Native_ID)  ~ 1,
                                      TRUE ~ 0))




accl_final_final_final0925_onc <-dup_value0925_onc %>%
  mutate(Risk_Level = case_when(included_old_oreo == 0 ~ 'Breast Cancer High - N', 
                                included_old_oreo == 1 ~ 'Breast Cancer High - B', 
                                TRUE ~ NA))










all_onc_0925 <-accl_final_final_final0925_onc[, !(names (accl_final_final_final0925_onc) %in% c("Risk Score", 'included_old_oreo')) ]




final_0925_with_onc <- all_onc_0925[!(all_onc_0925$Native_ID %in% original_final_msk$Native_ID),]



final_all_accl0925_onc<- rbind(final_0925_with_onc, original_final_msk)




onc_final_v2 <- final_all_accl0925_onc %>%
  filter(external_id %in% reach_enabled_oreo$external_id) %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!(external_id %in% c('HUMANA', 'GENTIVA') & MDC == 'MSK')) %>%
  filter(!(external_id %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES', 'THE HANOVER INSURANCE GROUP', 'COMMSCOPE' , 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                              'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY' ) & MDC == 'Oncology'))





###### prostate 


prostate_points <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/prostate_points.csv")
###treatment file 
had_procedure <-read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/Accolade Oreo Run/Prostate_Treatment.csv")


prostate_diagnosis <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/prostate_diagnosis.csv")

###removing  members with prostate cancer history
final_proc_prostate_history <- input_file_3 %>%
  filter(( icd_1 == 'Z8546' | icd_2 == 'Z8546' |  icd_3 == 'Z8546')) %>%
  distinct(person_id)


onc_had_pro_procedure <- input_file_3 %>%
  filter((cpt_1 %in%  had_procedure$cpt_code)| (cpt_2 %in%  had_procedure$cpt_code) | (cpt_3 %in%  had_procedure$cpt_code) ) %>%
  distinct(person_id)

onc_proc_final_proc <- input_file_3  %>%
  filter((icd_1 %in% prostate_diagnosis$dx1) | (icd_2 %in% prostate_diagnosis$dx1) | (icd_3 %in% prostate_diagnosis$dx1)) %>%
  filter((cpt_1 %in% prostate_points$proc1)) %>%
  distinct(person_id, start_date , cpt_1, .keep_all =  TRUE)



onc_prost_final_final <- onc_proc_final_proc %>%
  filter(!(person_id %in% final_proc_prostate_history$person_id))




df_original_volume_prost <-onc_prost_final_final %>%
  left_join(prostate_points, by = c("cpt_1" = "proc1" )) %>%
  group_by(person_id, description,  ramp, points) %>%      
  summarize(vol_pots = n_distinct(paste(person_id, start_date ,  sep = "")), .groups = 'drop') 


##### creating procedure_type_points based on their volume. If they have more than 2 visits then use ramp 

result_v2_prost <- df_original_volume_prost %>%
  group_by(person_id, description) %>%
  mutate(procedure_type_points = if_else(vol_pots >= 2, ramp, points)) %>% 
  select(person_id, description,  procedure_type_points)



###transposing table to add points 

transposed_df_prost <- pivot_wider(data = result_v2_prost, 
                                   names_from = description, 
                                   values_from = procedure_type_points)


transposed_df_prost[is.na(transposed_df_prost)] <- 0 




#### here you need to change the column (3:16) to however columns you have 

final_dfv3_prost <- transposed_df_prost %>%
  as_tibble() %>%
  mutate(total_points = rowSums(select(., 2:15), na.rm = TRUE))


df_deduped_v2_prost <- final_dfv3_prost  %>%
  filter(total_points >= 3)%>%
  select(person_id,   total_points) %>%
  filter(
    !(person_id %in% oreo_past_results$Native_ID),
    !(person_id %in% EMO_Dedupe$person_id), 
    !(person_id %in% onc_had_pro_procedure$person_id)
  )


df_deduped_v2_prost<- df_deduped_v2_prost[!(df_deduped_v2_prost$person_id %in% onc_had_pro_procedure$person_id),] 

df_deduped_v2_prost<-df_deduped_v2_prost[!(df_deduped_v2_prost$person_id %in% oreo_past_results$Native_ID),] 



df_orignal_volume_proc_description <- df_original_volume_prost %>%
  distinct(person_id , description)


accl_df_points_final_v2_prost  <- df_deduped_v2_prost %>%
  left_join(onc_proc_final_proc, by = "person_id" ) %>%
  left_join(df_orignal_volume_proc_description, by = "person_id")





accl_df_points_final_v2_prost$MDC <- 'Oncology'

accl_df_points_final_v2_prost$pilot <- 'Prostate Cancer'


df_combined_prost <- accl_df_points_final_v2_prost

df_combined_prost <- df_combined_prost[,!(names(df_combined_prost) %in% cols_to_drop)]






remove_dup <- function(strng) {
  strng <- strsplit(strng, ",")[[1]]
  strng <- unique(strng)
  return(paste(strng, collapse = ","))
}


accl_oreo_filtering <- function(file) {
  df <- file
  
  # Calculate percentiles
  unique_visits <- table(df$person_id, df$start_date)
  unique_visits <- rowSums(unique_visits > 0)
  ninety_percentile <- unique_visits[unique_visits >= quantile(unique_visits, 0.9)]
  seventy_to_ninety <- unique_visits[unique_visits >= quantile(unique_visits, 0.7) &
                                       unique_visits < quantile(unique_visits, 0.9)]
  
  # Create 'Risk_Level' column
  df$Risk_Level <- ifelse(df$person_id %in% names(ninety_percentile), "High",
                          ifelse(df$person_id %in% names(seventy_to_ninety), "Medium", "Low"))
  
  # Create 'Probability' column
  df$Probability <- ifelse(df$Risk_Level == "High", "90%",
                           ifelse(df$Risk_Level == "Medium", "50%", "10%"))
  
  # Concatenate MDC and remove repeating rows
  df <- df %>% group_by(`person_id`, MDC) %>%
    mutate(MDC_Comb = paste(MDC, collapse = ",")) %>%
    mutate(MDC_Comb = remove_dup(MDC_Comb)) %>%
    ungroup() %>%
    select(-MDC) %>%
    rename(MDC = MDC_Comb) 
  
  return(df)
}

accl_final_v2_prost <- accl_oreo_filtering(df_combined_prost)



accl_final_v2_prost <- accl_final_v2_prost  %>%
  mutate(Risk_Level = case_when(
    pilot == 'Prostate Cancer'~  'Prostate Cancer - Predictive Points', 
    pilot == 'MRI'~  'MSK High - MRI', 
    pilot == 'PT'~ 'MSK High - PT',
    pilot == 'Spine'~ 'MSK High - Spine',
    pilot == 'Onc_pilot'~ 'Oncology High - Benign Tumor',
    pilot == 'Cardio_pet_pilot' ~ 'Cardio High - PET',
    pilot == 'GI_pilot' ~ 'GI High - Endoscopy/Colonoscopy', 
    TRUE ~ Risk_Level
  ))


accl_final_v2_prost <- accl_final_v2_prost %>%
  mutate(Probability = case_when (
    pilot == 'Prostate Cancer'~  '90%', 
    pilot == 'MRI'~  '90%', 
    pilot == 'PT'~ '90%',
    pilot == 'Spine'~ '90%',
    pilot == 'Onc_pilot'~ '90%',
    pilot == 'Cardio_pet_pilot' ~ '90%',
    pilot == 'GI_pilot' ~ ' 90%', 
    TRUE ~ Probability
  ))





accl_final_v2_prost <- accl_final_v2_prost %>%
  distinct(person_id, cpt_1,    .keep_all = TRUE)

accl_final_v3_prost <- accl_final_v2_prost %>%
  group_by(person_id) %>%
  reframe( across(everything()), procedure_group_combined = paste(unique(cpt_desc_1), collapse = ";")) %>%
  ungroup()


accl_final_prost <- accl_final_v3_prost  %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ''))) %>%
  mutate(icd_combined = ifelse((is.na(icd_desc_2) | icd_desc_2 == "") &
                                 (is.na(icd_desc_3) | icd_desc_3 == ""),
                               icd_desc_1,
                               str_c(icd_desc_1, icd_desc_2, icd_desc_3, sep = '; '))) %>%
  mutate(descrip_new_2 = str_c('Procedure Type: ', cpt_desc_1, ".")) %>%
  mutate(cpt_description = case_when(
    pilot == "Prostate" ~ cpt_desc_1, 
    pilot == "PT" ~ str_c(cpt_desc_1, ", (Physical Therapy)"),
    pilot == "GI_pilot" ~ cpt_desc_1,
    pilot == "Spine" ~ str_c(cpt_desc_1, ", (Spine)"),
    pilot == 'nopilots' ~ cpt_desc_1,
    TRUE ~ NA_character_
  )) %>%
  mutate(mdc_new = str_c("MDC: ", as.character(MDC))) %>%
  mutate(ICD_desc = paste(mdc_new,  ". Diagnosis description: ", icd_combined,   ". Procedure Description: ", cpt_1, procedure_group_combined, ". ", descrip_new_2 ))



accl_final_prost <- as.data.frame(accl_final_prost)


accl_combined_filter <- function(accl_final_prost, do_not_call) {
  accl_final_prost$Data_Source <- accl_final_prost$subcompany
  now <- Sys.Date()
  accl_final_prost$dob <- as.Date(accl_final_prost$dob, origin = "1970-01-01")
  accl_final_prost$age <- (now - accl_final_prost$dob) / 365.25 
  accl_final_prost$age <- as.numeric(accl_final_prost$age)
  
  
  accl_final_prost$`2nd_MD_ID` <- ''
  accl_final_prost$Parent_ID <- ''
  accl_final_prost$Client_ID <- ''
  
  accl_final_prost$Data_Source <- 'Accolade'
  
  
  accl_final_prost$Has_NDC <- 1
  accl_final_prost$CPT_desc <- accl_final_prost$cpt_desc_1
  
  
  
  
  
  accl_final_prost <- accl_final_prost[, c('2nd_MD_ID',  'Data_Source', 'subcompany', 'person_id', 'has_icd', 'has_cpt', 'Has_NDC', 'gender',
                                           'age', 'zip', 'first_name', 'last_name', 'dob', 'start_date', 'icd_1', 'cpt_1', 'phone_num', 
                                           'relationship_type', 'subscriber_id', 'subscriber_first_name', 'subscriber_last_name', 'subscriber_dob',
                                           'subscriber_zip', 'Parent_ID', 'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc','MDC',  'total_points', 'external_id')]
  
  
  
  
  names(accl_final_prost) <- c('2nd_MD_ID', 'Data_Source', 'Subcompany', 'Native_ID', 'Has_ICD',
                               'Has_CPT', 'Has_NDC', 'Gender', 'Age', 'Zip', 'First_Name', 'Last_Name',
                               'DOB', 'Date_of_Service', 'ICD_1', 'CPT_1', 'PhoneNumber',
                               'Relationship_Type', 'Subscriber_ID', 'Subscriber_First_Name',
                               'Subscriber_Last_Name', 'Subscriber_DOB', 'Subscriber_Zip', 'Parent_ID',
                               'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc',
                               'MDC', 'Risk Score', 'external_id')
  
  
  
  # Limit data to only four rows per member
  accl_final_prost <-accl_final_prost[order(accl_final_prost$Native_ID,accl_final_prost$Date_of_Service), ]  # Sort the data frame
  accl_final_prost <- accl_final_prost[ave(seq_len(nrow(accl_final_prost)), accl_final_prost$Native_ID, accl_final_prost$Date_of_Service, FUN = seq_along) <= 4, ]
  accl_final_prost <- as.data.frame(accl_final_prost)
  
  accl_final_prost <-accl_final_prost[!(accl_final_prost$Native_ID %in% do_not_call$person_id), ]  # Do not call list
  
  
  
  
  
  
  accl_final_prost$id <- NULL
  
  accl_final_prost[is.na(accl_final_prost)] <- ""
  accl_final_prost$PhoneNumber <- as.character(accl_final_prost$PhoneNumber)
  accl_final_prost  <- accl_final_prost[!(accl_final_prost$PhoneNumber == ''),]
  accl_final_prost <- accl_final_prost[!(accl_final_prost$PhoneNumber %in% c('999999999', '000000000', '0000000000', '9999999999', '1111111111')), ]
  accl_final_prost <- accl_final_prost[!grepl('-',accl_final_prost$PhoneNumber), ]
  accl_final_prost  <- accl_final_prost[nchar(accl_final_prost$PhoneNumber) == 10, ]
  accl_final_prost <- accl_final_prost[!grepl("^1\\d{9}$", accl_final_prost$PhoneNumber), ]
  accl_final_prost <- accl_final_prost[!(accl_final_prost$PhoneNumber == '0'), ]
  accl_final_prost <- accl_final_prost[!((accl_final_prost$Relationship_Type %in% c('Child', 'Spouse', 'Disabled Child')) & (accl_final_prost$Subscriber_First_Name == '')), ]
  accl_final_prost$Zip <- as.character(accl_final_prost$Zip)
  
  accl_final_prost$Subscriber_Zip <- as.character(accl_final_prost$Subscriber_Zip)
  accl_final_prost<- accl_final_prost[nchar(accl_final_prost$Zip) == 5, ]
  accl_final_prost<- accl_final_prost[nchar(accl_final_prost$Subscriber_Zip) == 5, ]
  accl_final_prost<- accl_final_prost[!(accl_final_prost$Zip == '00000'),]
  accl_final_prost<- accl_final_prost[grep("^[0-9]+$", gsub(" ", "", accl_final_prost$Zip)), ]
  accl_final_prost<- accl_final_prost[grep("^[0-9]+$", gsub(" ", "", accl_final_prost$Subscriber_Zip)), ]
  
  
  accl_final_prost$parent_id <- NULL
  accl_final_prost$DOB <- as.Date(accl_final_prost$DOB, origin = "1970-01-01")
  accl_final_prost$Date_of_Service <- format(as.Date(accl_final_prost$Date_of_Service), "%m/%d/%Y")
  accl_final_prost$Subscriber_DOB <- format(as.Date(accl_final_prost$Subscriber_DOB), "%m/%d/%Y")
  
  
  
  return(accl_final_prost)
}




accl_final_prost <- accl_combined_filter(accl_final_prost, do_not_call)







accl_final_prost$DOB <- format(as.Date(accl_final_prost$DOB), "%m/%d/%Y" )



accl_final_prost <- accl_final_prost %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!Subcompany %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES', 'MOFFITT CANCER CENTER', 'THE HANOVER INSURANCE GROUP', 'COMMSCOPE', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                    'ADVANTAGE SOLUTIONS', 'BECTON DICKINSON AND COMPANY' ))







accl_final_0925_prost <- accl_final_prost %>%
  distinct(Native_ID ,.keep_all = TRUE)


final_onc_0925 <- onc_final_v2  %>%
  distinct(Native_ID, .keep_all = TRUE)






dup_value0925_prost <-accl_final_0925_prost   %>%
  mutate(included_old_oreo= case_when((Native_ID %in% final_onc_0925$Native_ID)  ~ 1,
                                      TRUE ~ 0))




accl_final_final_final0925_pros <- dup_value0925_prost  %>%
  mutate(Risk_Level = case_when(included_old_oreo == 0 ~ 'Prostate Cancer High - N', 
                                included_old_oreo == 1 ~ 'Prostate Cancer High - B', 
                                TRUE ~ NA))









all_prost_0925 <-accl_final_final_final0925_pros[, !(names (accl_final_final_final0925_pros) %in% c("Risk Score", 'included_old_oreo')) ]




final_0925_with_pros <- all_prost_0925[!(all_prost_0925$Native_ID %in% onc_final_v2$Native_ID),]



final_all_accl0925_prost <- rbind(final_0925_with_pros, onc_final_v2)



 



prost_final_v2 <- final_all_accl0925_prost %>%
  filter(external_id %in% reach_enabled_oreo$external_id)%>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!(external_id %in% c('HUMANA', 'GENTIVA') & MDC == 'MSK')) %>%
  filter(!(external_id == 'GENTIVA' & CPT_1 %in% bariatric_codes )) %>%
  filter(!(external_id %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES',  'THE HANOVER INSURANCE GROUP', 'COMMSCOPE' , 'MOFFITT CANCER CENTER', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                              'ADVANTAGE SOLUTIONS', "BECTON DICKINSON AND COMPANY" ) & MDC == 'Oncology'))



unique(sort(prost_final_v2$Subcompany))

length(unique(prost_final_v2$Native_ID))





accl_final_v2_box <- prost_final_v2 %>%
  group_by(Subcompany)%>%
  summarize(n=n_distinct(Native_ID))

#### new ml model 

ml_oreo <- read_csv("~/Downloads/ml_model0326.csv")

ml_oreo_new <- input_file_2 %>%
  merge(ml_oreo, by = "person_id")
 

ml_oreo_official  <- ml_oreo_new %>%
  filter(!person_id %in% EMO_Dedupe$person_id) %>%
  filter(!person_id %in% oreo_past_results$Native_ID)%>%
  filter(person_id %in% EDW_elig$person_id) %>%
  filter(!(subcompany %in% c('HUMANA',  'GENTIVA') & MDC == 'MSK')) %>%
  filter(!(external_id %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES',  'THE HANOVER INSURANCE GROUP', 'COMMSCOPE' , 'MOFFITT CANCER CENTER' ,'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                    'ADVANTAGE SOLUTIONS' , "BECTON DICKINSON AND COMPANY") & MDC == 'Oncology'))



### only filtering to the top 8000


top_ids <- ml_oreo_official %>%
  arrange(desc(pred_proba)) %>%
  distinct(person_id) %>%
  slice_head(n = 8000) %>%
  pull(person_id)

result_ml <- ml_oreo_official %>%
  filter(person_id %in% top_ids)


result_ml_final <- result_ml


remove_dup <- function(strng) {
  strng <- strsplit(strng, ",")[[1]]
  strng <- unique(strng)
  return(paste(strng, collapse = ","))
}


accl_oreo_filtering <- function(file) {
  df <- file
  
  # Calculate percentiles
  unique_visits <- table(df$person_id, df$start_date)
  unique_visits <- rowSums(unique_visits > 0)
  ninety_percentile <- unique_visits[unique_visits >= quantile(unique_visits, 0.9)]
  seventy_to_ninety <- unique_visits[unique_visits >= quantile(unique_visits, 0.7) &
                                       unique_visits < quantile(unique_visits, 0.9)]
  
  # Create 'Risk_Level' column
  df$Risk_Level <- ifelse(df$person_id %in% names(ninety_percentile), "High",
                          ifelse(df$person_id %in% names(seventy_to_ninety), "Medium", "Low"))
  
  # Create 'Probability' column
  df$Probability <- ifelse(df$Risk_Level == "High", "90%",
                           ifelse(df$Risk_Level == "Medium", "50%", "10%"))
  
  # Concatenate MDC and remove repeating rows
  df <- df %>% group_by(`person_id`, MDC) %>%
    mutate(MDC_Comb = paste(MDC, collapse = ",")) %>%
    mutate(MDC_Comb = remove_dup(MDC_Comb)) %>%
    ungroup() %>%
    select(-MDC) %>%
    rename(MDC = MDC_Comb) 
  
  return(df)
}

accl_final_v2_ml <- accl_oreo_filtering(result_ml_final)




accl_final_v2_ml <- accl_final_v2_ml %>%
  -select(-c(Risk_level, risk_level))






accl_final_ml  <- accl_final_v2_ml  %>%
  mutate(Risk_Level = 'High - ML') %>%
  mutate(Probability =  paste0(round(pred_proba * 100), "%"))


accl_final_ml <- accl_final_ml %>%
  mutate(MDC = case_when(MDC == 'Cardiology' ~ 'Cardio',
                         TRUE ~ MDC)) %>%
  filter(!MDC == 'Other')



accl_final_ml <- accl_final_ml %>%
  filter( (MDC == 'MSK' & ((icd_1 >= 'M00' & icd_1 <= 'M99')| (icd_1 >= 'S00' & icd_1 < 'T150') | (icd_1 >= 'T84' & icd_1 < 'T86')|(icd_1 >= 'R25' & icd_1 < 'R30')))| 
            (MDC == 'Cardio' & (( icd_1 >= 'I00' & icd_1 <= 'I99')| (icd_1 >= 'R00' & icd_1 < 'R10') | (icd_1 >= 'Z950' & icd_1 < 'Z960') | (icd_1 >= 'T8201' & icd_1 < 'T8300')))|
  (MDC == 'GI' &  (  (icd_1 >= 'K20' & icd_1 < 'K69')|(icd_1 >= 'K90' & icd_1 < 'K96')|(icd_1 >= 'R10' & icd_1 < 'R20') | (icd_1 >= 'Z980' & icd_1 < 'Z981')| (icd_1 >= 'Z9884' & icd_1 < 'Z9885'))) | 
  (MDC == 'Oncology' & ( (icd_1 >= 'C00' & icd_1 < 'D50')|(icd_1 >= 'Z80' & icd_1 < 'Z81')|(icd_1 >= 'Z85' & icd_1 < 'Z86'))) |
  (MDC == "Women's Health" &  (( icd_1 >= 'N60' & icd_1 <= 'N99')|(icd_1 >= 'N992' & icd_1 <= 'N999') )))%>%
  select(-c(risk_level ))

accl_final_ml <- accl_final_ml  %>%
  distinct(person_id, icd_1, cpt_1,    .keep_all = TRUE)

accl_final_v3_ml <- accl_final_ml %>%
  group_by(person_id) %>%
  reframe( across(everything()), procedure_group_combined = paste(unique(cpt_desc_1), collapse = ";")) %>%
  ungroup()


accl_final_ml_2 <- accl_final_v3_ml  %>%
  mutate(across(everything(), as.character)) %>%
  mutate(across(everything(), ~replace_na(., ''))) %>%
  mutate(icd_combined = ifelse((is.na(icd_desc_2) | icd_desc_2 == "") &
                                 (is.na(icd_desc_3) | icd_desc_3 == ""),
                               icd_desc_1,
                               str_c(icd_desc_1, icd_desc_2, icd_desc_3, sep = '; '))) %>%
  mutate(descrip_new_2 = str_c('Procedure Type: ', cpt_desc_1, ".")) %>%
  mutate(cpt_description = cpt_desc_1) %>%
  mutate(mdc_new = str_c("MDC: ", as.character(MDC))) %>%
  mutate(ICD_desc = paste(mdc_new,  ". Diagnosis description: ", icd_combined, MDC_features,   ". Procedure Description: ", cpt_1, procedure_group_combined, ". ", descrip_new_2 ))




accl_final_ml_2 <- as.data.frame(accl_final_ml_2)


accl_combined_filter <- function(accl_final_ml_2, do_not_call) {
  accl_final_ml_2$Data_Source <- accl_final_ml_2$subcompany
  now <- Sys.Date()
  accl_final_ml_2$dob <- as.Date(accl_final_ml_2$dob, origin = "1970-01-01")
  accl_final_ml_2$age <- (now - accl_final_ml_2$dob) / 365.25 
  accl_final_ml_2$age <- as.numeric(accl_final_ml_2$age)
  
  
  accl_final_ml_2$`2nd_MD_ID` <- ''
  accl_final_ml_2$Parent_ID <- ''
  accl_final_ml_2$Client_ID <- ''
  
  accl_final_ml_2$Data_Source <- 'Accolade'
  
  
  accl_final_ml_2$Has_NDC <- 1
  accl_final_ml_2$CPT_desc <- accl_final_ml_2$cpt_desc_1
  
  
  
  

  
  
  
  accl_final_ml_2 <- accl_final_ml_2[, c(
    '2nd_MD_ID', 'Data_Source', 'subcompany', 'person_id', 'has_icd', 'has_cpt', 'has_ndc', 'gender',
    'age', 'zip', 'first_name', 'last_name', 'dob', 'start_date', 'icd_1', 'cpt_1', 'phone_num', 
    'relationship_type', 'subscriber_id', 'subscriber_first_name', 'subscriber_last_name', 'subscriber_dob',
    'subscriber_zip', 'Parent_ID', 'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc','MDC', 'external_id')]
  
  
  
  
  names(accl_final_ml_2) <- c('2nd_MD_ID', 'Data_Source', 'Subcompany', 'Native_ID', 'Has_ICD',
                               'Has_CPT', 'Has_NDC', 'Gender', 'Age', 'Zip', 'First_Name', 'Last_Name',
                               'DOB', 'Date_of_Service', 'ICD_1', 'CPT_1', 'PhoneNumber',
                               'Relationship_Type', 'Subscriber_ID', 'Subscriber_First_Name',
                               'Subscriber_Last_Name', 'Subscriber_DOB', 'Subscriber_Zip', 'Parent_ID',
                               'Client_ID', 'Risk_Level', 'Probability', 'ICD_desc', 'CPT_desc',
                               'MDC',  'external_id')
  
  
  # Limit data to only four rows per member
  accl_final_ml_2 <-accl_final_ml_2[order(accl_final_ml_2$Native_ID,accl_final_ml_2$Date_of_Service), ]  # Sort the data frame
  accl_final_ml_2 <- accl_final_ml_2[ave(seq_len(nrow(accl_final_ml_2)), accl_final_ml_2$Native_ID, accl_final_ml_2$Date_of_Service, FUN = seq_along) <= 4, ]
  accl_final_ml_2 <- as.data.frame(accl_final_ml_2)
  
  accl_final_ml_2 <-accl_final_ml_2[!(accl_final_ml_2$Native_ID %in% do_not_call$person_id), ]  # Do not call list
  
  
  
  
  
  
  accl_final_ml_2$id <- NULL
  
  accl_final_ml_2[is.na(accl_final_ml_2)] <- ""
  accl_final_ml_2$PhoneNumber <- as.character(accl_final_ml_2$PhoneNumber)
  accl_final_ml_2  <- accl_final_ml_2[!(accl_final_ml_2$PhoneNumber == ''),]
  accl_final_ml_2 <- accl_final_ml_2[!(accl_final_ml_2$PhoneNumber %in% c('999999999', '000000000', '0000000000', '9999999999', '1111111111')), ]
  accl_final_ml_2 <- accl_final_ml_2[!grepl('-',accl_final_ml_2$PhoneNumber), ]
  accl_final_ml_2  <- accl_final_ml_2[nchar(accl_final_ml_2$PhoneNumber) == 10, ]
  accl_final_ml_2 <- accl_final_ml_2[!grepl("^1\\d{9}$", accl_final_ml_2$PhoneNumber), ]
  accl_final_ml_2 <- accl_final_ml_2[!(accl_final_ml_2$PhoneNumber == '0'), ]
  accl_final_ml_2 <- accl_final_ml_2[!((accl_final_ml_2$Relationship_Type %in% c('Child', 'Spouse', 'Disabled Child')) & (accl_final_ml_2$Subscriber_First_Name == '')), ]
  accl_final_ml_2$Zip <- as.character(accl_final_ml_2$Zip)
  
  accl_final_ml_2$Subscriber_Zip <- as.character(accl_final_ml_2$Subscriber_Zip)
  accl_final_ml_2<- accl_final_ml_2[nchar(accl_final_ml_2$Zip) == 5, ]
  accl_final_ml_2<- accl_final_ml_2[nchar(accl_final_ml_2$Subscriber_Zip) == 5, ]
  accl_final_ml_2<- accl_final_ml_2[!(accl_final_ml_2$Zip == '00000'),]
  accl_final_ml_2<- accl_final_ml_2[grep("^[0-9]+$", gsub(" ", "", accl_final_ml_2$Zip)), ]
  accl_final_ml_2<- accl_final_ml_2[grep("^[0-9]+$", gsub(" ", "", accl_final_ml_2$Subscriber_Zip)), ]
  
  
  accl_final_ml_2$parent_id <- NULL
  accl_final_ml_2$DOB <- as.Date(accl_final_ml_2$DOB, origin = "1970-01-01")
  accl_final_ml_2$Date_of_Service <- format(as.Date(accl_final_ml_2$Date_of_Service), "%m/%d/%Y")
  accl_final_ml_2$Subscriber_DOB <- format(as.Date(accl_final_ml_2$Subscriber_DOB), "%m/%d/%Y")
  
  
  
  return(accl_final_ml_2)
}




accl_final_ml_2 <- accl_combined_filter(accl_final_ml_2, do_not_call)









accl_final_ml_2  <- accl_final_ml_2 %>%
  filter(!Native_ID  %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID)%>%
  filter(Native_ID %in% EDW_elig$person_id)


accl_final_ml_2$DOB <- format(as.Date(accl_final_ml_2$DOB), "%m/%d/%Y" )


accl_final_distinct_ml <- accl_final_ml_2   %>%
  distinct(Native_ID ,.keep_all = TRUE)

accl_final_distinct_pros <- prost_final_v2 %>%
  distinct(Native_ID, .keep_all = TRUE)






dup_value_ml <- accl_final_distinct_ml  %>%
  mutate(included_old_oreo= case_when((Native_ID %in% accl_final_distinct_pros$Native_ID)  ~ 1,
                                      TRUE ~ 0))



accl_final_final_final_ml <-dup_value_ml  %>%
  mutate(Risk_Level = case_when(included_old_oreo == 0 ~ 'High - ML', 
                                included_old_oreo == 1 ~ 'High - ML - B', 
                                TRUE ~ NA))

final_ml_0925 <-accl_final_final_final_ml[, !(names(accl_final_final_final_ml) %in% c( 'included_old_oreo')) ]





accl_final_0925_original <- prost_final_v2[!(prost_final_v2$Native_ID %in% final_ml_0925$Native_ID),]



final_all_accl0925 <- rbind(final_ml_0925 , accl_final_0925_original)




reach_enabled_oreo <- read_csv("~/OneDrive - Accolade, Inc/Desktop/Oreo 2024/Accolade Oreo Run/corp_enabled.csv")

final_all_accl0925 <-final_all_accl0925 %>%
  filter(external_id %in% reach_enabled_oreo$external_id)

final_all_accl0925$Subcompany <- final_all_accl0925$external_id

final_all_accl0925 <-final_all_accl0925%>%
  filter(!Native_ID %in% EMO_Dedupe$person_id) %>%
  filter(!Native_ID %in% oreo_past_results$Native_ID) %>%
  filter(!(external_id %in% c('HUMANA', 'GENTIVA') & MDC == 'MSK')) %>%
  filter(!(external_id == 'GENTIVA' & CPT_1 %in% bariatric_codes )) %>%
  filter(!((external_id %in% c('INTUITIVE SURGICAL', 'UNITED AIRLINES', 'MOFFITT CANCER CENTER', 'STANDARDAERO', 'DAY AND ZIMMERMANN' , 
                                    'ADVANTAGE SOLUTIONS') & MDC == 'Oncology')))

### this is in case I don't get to finish it off the same day 
EMO_Dedupe <- read_csv("~/Desktop/Prior Auth Requests/Prior_Auth_03052026.csv")
EMO_Dedupe <- EMO_Dedupe %>%
  filter(request_load >= Sys.Date() - 180)


### remove any vip_members 
vip_members <- read_csv("~/Desktop/vip_members.csv")

final_all_accl0925_new <- final_all_accl0925 %>%
  filter(!(Native_ID %in% vip_members$person_id)) %>%
  filter(!Native_ID %in% EMO_Dedupe$person_id)




length(unique(final_all_accl0925$Native_ID))
write_csv(final_all_accl0925_new, "accl_final_oreo_0226_extra.csv")



# Function definitions
accl_pivot_table <- function(df) {
  df %>%
    distinct(Native_ID, .keep_all = TRUE) %>%
    group_by(external_id, MDC, Risk_Level) %>%
    summarise(Native_ID_Count = n_distinct(Native_ID)) %>%
    pivot_wider(names_from = MDC, values_from = Native_ID_Count)
}

accl_stats_files <- function(df) {
  df %>%
    distinct(Native_ID, .keep_all = TRUE) %>%
    group_by(external_id, MDC) %>%
    summarise(Native_ID_Count = n_distinct(Native_ID)) %>%
    pivot_wider(names_from = MDC, values_from = Native_ID_Count) %>%
    pivot_longer(cols = -Subcompany, names_to = "MDC", values_to = "Native_ID_Count", values_drop_na = FALSE)
}

# Calling the functions with accl_final DataFrame
accl_pivot_table_result <- accl_pivot_table((final_all_accl0925))

accl_stats_files_result <- accl_stats_files(accl_final)

# Save the results to CSV files
write.csv(accl_pivot_table_result, file = "accl_oreo_pivot_0226.csv", row.names = FALSE)
write.csv(accl_stats_files_result, file = "accl_stats_files_0124_points.csv", row.names = FALSE)





