select number_pools.id
 from
 (
 select calls.called_national_number,
 calls.called_country_code
 from calls
 where start_time > '2015-03-22 21:33:03' and call_source = 'Direct' and call_treatment != 'BlacklistedCaller'
 group by called_national_number, called_country_code
 having count(*) > 3
 ) as calls
 join number_pools on number_pools.national_number = calls.called_national_number and number_pools.country_code = calls.called_country_code
 where state = 'Unassigned'