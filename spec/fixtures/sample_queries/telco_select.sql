select zip1, time_zone_hours, states.state_short, states.state_long, city, country, lata, mobile, latitude, longitude
 from telco.lerg_melissa_prefixes
 left outer join telco.states on states.state_short = lerg_melissa_prefixes.state_short
 left outer join telco.melissa_counties on melissa_counties.fips_code = lerg_melissa_prefixes.fips_code
 where npa = '805' AND nxx = '708' AND block in ('_', '3')
 limit 1