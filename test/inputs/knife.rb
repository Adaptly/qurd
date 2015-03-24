current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "foo"
client_name              "foo"
client_key               "#{current_dir}/foo.pem"
validation_client_name   "foo-validator"
validation_key           "#{current_dir}/validator.pem"
chef_server_url          "https://api.opscode.com/organizations/foo"
