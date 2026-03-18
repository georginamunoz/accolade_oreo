select distinct  r.request_id,  r.cst_request_dtm::date as request_load,
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
                    then 1 else 0 end) as nurse_ind



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
where r.cst_request_dtm::date  >= '2025-08-29'
group by r.request_id, r.cst_request_dtm,  r.transfer_type, c.enc_key,  m.first_nm, m.last_nm, r.contact_made_flg, m.activation_status, m.emo_unique_id, m.person_id,  mc.elig_mismatch_flg, m.dependent_type, m.current_elig_status, c.reach_paused_flg, c.org_channel, c.reach_enabled_flg, r.status, r.nurse_user_nm, r.mbr_disassociated_at_request_flg, c.corporate_id, c.org_external_nm;