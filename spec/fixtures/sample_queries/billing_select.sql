 SELECT *
      from (
        SELECT
          advertisers.id as id,
          advertisers.name as name,
          advertisers.id_from_network as id_from_network,
          ifnull(charge_count,0) as stats_charge_count,
          ifnull(sum_total_charges,0.0) as stats_sum_total_charges,
          ifnull(sum_advertiser_promo_number,0.0) as stats_sum_advertiser_promo_number,
          ifnull(count_advertiser_promo_number,0.0) as stats_count_advertiser_promo_number,
          ifnull(sum_tv_duplication_request,0.0) as stats_sum_tv_duplication_request,
          ifnull(count_tv_duplication_request,0.0) as stats_count_tv_duplication_request,
          ifnull(sum_radio_duplication_request,0.0) as stats_sum_radio_duplication_request,
          ifnull(count_radio_duplication_request,0.0) as stats_count_radio_duplication_request,
          ifnull(sum_voice_prompt_order,0.0) as stats_sum_voice_prompt_order,
          ifnull(count_voice_prompt_order,0.0) as stats_count_voice_prompt_order,
          ifnull(sum_voice_prompt,0.0) as stats_sum_voice_prompt,
          ifnull(count_voice_prompt,0.0) as stats_count_voice_prompt,
          ifnull(sum_advertiser_search_number,0.0) as stats_sum_advertiser_search_number,
          ifnull(count_advertiser_search_number,0.0) as stats_count_advertiser_search_number,
          ifnull(CALLSTATS.call_count,0) as stats_call_count,
          ifnull(CALLSTATS.sum_affiliate_payout,0.0) as stats_sum_affiliate_payout,
          ifnull(CALLSTATS.sum_advertiser_payin,0.0) as stats_sum_advertiser_payin,
          ifnull(CALLSTATS.sum_margin,0.0) as stats_sum_margin,
          ifnull(CALLSTATS.sum_call_fees,0.0) as stats_sum_call_fees,
          ifnull(CALLSTATS.sum_call_duration,0.0) as stats_sum_call_duration
        from
        (
        select
            advertisers.*,
            count(invoice_line_item_details.id) as charge_count,
            sum( invoice_line_item_details.charge_amount ) as sum_total_charges,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserPromoNumber' then invoice_line_item_details.charge_amount end ) as sum_advertiser_promo_number,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserPromoNumber' then 1 else 0 end ) as count_advertiser_promo_number,
            sum( case when invoice_line_item_details.charge_type = 'TvDuplicationRequest' then invoice_line_item_details.charge_amount end ) as sum_tv_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'TvDuplicationRequest' then 1 else 0 end ) as count_tv_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'RadioDuplicationRequest' then invoice_line_item_details.charge_amount end ) as sum_radio_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'RadioDuplicationRequest' then 1 else 0 end ) as count_radio_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'VoicePromptOrder' then invoice_line_item_details.charge_amount end ) as sum_voice_prompt_order,
            sum( case when invoice_line_item_details.charge_type = 'VoicePromptOrder' then 1 else 0 end ) as count_voice_prompt_order,
            sum( case when invoice_line_item_details.charge_type = 'VoicePrompt' then invoice_line_item_details.charge_amount end ) as sum_voice_prompt,
            sum( case when invoice_line_item_details.charge_type = 'VoicePrompt' then 1 else 0 end ) as count_voice_prompt,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserSearchNumber' then invoice_line_item_details.charge_amount end ) as sum_advertiser_search_number,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserSearchNumber' then 1 else 0 end ) as count_advertiser_search_number
        FROM `advertisers`
        LEFT OUTER JOIN invoice_line_item_details FORCE INDEX ( invoice_foreign_key )
          on invoice_line_item_details.organization_type = 'Advertiser'
          AND invoice_line_item_details.organization_id = advertisers.id
          AND invoice_id = #{id}
          GROUP BY advertisers.id
          ) as advertisers
        LEFT OUTER JOIN (
          SELECT
            ad.network_id,
            ad.advertiser_id,
            sum(ada.call_call_count_#{tz}) as call_count,
            sum(ada.call_affiliate_payout_#{currency}_#{tz}) as sum_affiliate_payout,
            sum(ada.call_advertiser_payin_#{currency}_#{tz}) as sum_advertiser_payin,
            sum(ada.call_margin_#{currency}_#{tz}) as sum_margin,
            sum(ada.call_fee_#{currency}_#{tz}  ) as sum_call_fees,
            sum(ada.call_duration_in_seconds_#{tz}  ) as sum_call_duration
          FROM cf_advertiser_date_aggregate_#{tz}s as ada
          INNER JOIN cf_advertiser_dimensions as ad on ada.advertiser_dimension_id = ad.id
          WHERE ada.date_dimension_id >= #{date_range.begin_id}
            and ada.date_dimension_id < #{date_range.end_id}
            and ad.network_id = #{network.id}
          GROUP BY ad.network_id,ad.advertiser_id
        ) as CALLSTATS ON CALLSTATS.network_id = advertisers.network_id AND CALLSTATS.advertiser_id = advertisers.id
        WHERE (
                (
                  (
                    (advertisers.approval_status = 'Approved' and advertisers.created_at < '#{ends_at.to_s(:db)}' )
                    OR ifnull(CALLSTATS.sum_affiliate_payout,0.0) != 0.0
                    OR ifnull(CALLSTATS.sum_advertiser_payin,0.0) != 0.0
                    OR ifnull(CALLSTATS.sum_call_fees,0.0) != 0.0
                    OR ifnull(charge_count,0) != 0
                  )
                  AND (`advertisers`.network_id = #{network.id})
                )
                AND (`advertisers`.network_id = #{network.id})
             )
      union all
        SELECT
          null as id,
          null as name,
          '' as id_from_network,
          ifnull(charge_count,0) as stats_charge_count,
          ifnull(sum_total_charges,0.0) as stats_sum_total_charges,
          ifnull(sum_advertiser_promo_number,0.0) as stats_sum_advertiser_promo_number,
          ifnull(count_advertiser_promo_number,0.0) as stats_count_advertiser_promo_number,
          ifnull(sum_tv_duplication_request,0.0) as stats_sum_tv_duplication_request,
          ifnull(count_tv_duplication_request,0.0) as stats_count_tv_duplication_request,
          ifnull(sum_radio_duplication_request,0.0) as stats_sum_radio_duplication_request,
          ifnull(count_radio_duplication_request,0.0) as stats_count_radio_duplication_request,
          ifnull(sum_voice_prompt_order,0.0) as stats_sum_voice_prompt_order,
          ifnull(count_voice_prompt_order,0.0) as stats_count_voice_prompt_order,
          ifnull(sum_voice_prompt,0.0) as stats_sum_voice_prompt,
          ifnull(count_voice_prompt,0.0) as stats_count_voice_prompt,
          ifnull(sum_advertiser_search_number,0.0) as stats_sum_advertiser_search_number,
          ifnull(count_advertiser_search_number,0.0) as stats_count_advertiser_search_number,
          0 as stats_call_count,
          0.0 as stats_sum_affiliate_payout,
          0.0 as stats_sum_advertiser_payin,
          0.0 as stats_sum_margin,
          0.0 as stats_sum_call_fees,
          0.0 as stats_sum_call_duration
        from
        (
          select
            count(invoice_line_item_details.id) as charge_count,
            sum( invoice_line_item_details.charge_amount ) as sum_total_charges,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserPromoNumber' then invoice_line_item_details.charge_amount end ) as sum_advertiser_promo_number,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserPromoNumber' then 1 else 0 end ) as count_advertiser_promo_number,
            sum( case when invoice_line_item_details.charge_type = 'TvDuplicationRequest' then invoice_line_item_details.charge_amount end ) as sum_tv_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'TvDuplicationRequest' then 1 else 0 end ) as count_tv_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'RadioDuplicationRequest' then invoice_line_item_details.charge_amount end ) as sum_radio_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'RadioDuplicationRequest' then 1 else 0 end ) as count_radio_duplication_request,
            sum( case when invoice_line_item_details.charge_type = 'VoicePromptOrder' then invoice_line_item_details.charge_amount end ) as sum_voice_prompt_order,
            sum( case when invoice_line_item_details.charge_type = 'VoicePromptOrder' then 1 else 0 end ) as count_voice_prompt_order,
            sum( case when invoice_line_item_details.charge_type = 'VoicePrompt' then invoice_line_item_details.charge_amount end ) as sum_voice_prompt,
            sum( case when invoice_line_item_details.charge_type = 'VoicePrompt' then 1 else 0 end ) as count_voice_prompt,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserSearchNumber' then invoice_line_item_details.charge_amount end ) as sum_advertiser_search_number,
            sum( case when invoice_line_item_details.charge_type = 'AdvertiserSearchNumber' then 1 else 0 end ) as count_advertiser_search_number
          from invoice_line_item_details
          where invoice_line_item_details.invoice_id = #{id}
            and invoice_line_item_details.organization_type != 'Advertiser'
            and invoice_line_item_details.charge_type != 'LicenseFeeSummary'
          GROUP BY null
        ) as charge_summary
        where charge_count > 0
      ) as a
      order by name