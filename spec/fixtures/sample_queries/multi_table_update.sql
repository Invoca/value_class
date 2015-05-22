         update advertiser_affiliate_joins
           inner join affiliates on affiliates.id = advertiser_affiliate_joins.affiliate_id
           set advertiser_affiliate_joins.status_update_from = 'API'
           where affiliates.network_id = 1