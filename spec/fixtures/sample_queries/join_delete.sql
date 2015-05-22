DELETE * FROM advertiser_campaigns INNER JOIN advertisers
WHERE advertiser_campaigns.adverisers_id=advertisers.id AND advertisers.id_from_network = '121'