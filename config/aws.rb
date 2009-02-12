SDB_CONNECTION = AwsSdb::Service.new(
  :access_key_id => Panda::Config[:access_key_id],
  :secret_access_key => Panda::Config[:secret_access_key],
  :url => Panda::Config[:sdb_base_url]
)
