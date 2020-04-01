# CHANGELOG for `active_table_set`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1]

### Changed

- Improved access error message to include current settings, including current table set.
  For example:
    ```ruby
  Query denied by Active Table Set access_policy: (are you using the correct table set?)
            
            Current settings: {"table_set"=>:common, "access"=>:leader, "partition_key"=>nil, "timeout"=>110, "net_read_timeout"=>nil, "net_write_timeout"=>nil, "test_scenario"=>nil}
    ```

[0.5.1]: https://github.com/Invoca/active-table-set/compare/v0.5.0...v0.5.1
