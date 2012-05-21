#
# Cookbook Name:: openmeetings-mysql
# Recipe:: default
#
# Copyright 2012, Apache
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# assume that the mysql recipe has been executed.
include_recipe "mysql::server"
include_recipe "database"

mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}

# create a mysql user
mysql_database_user node['openmeetings_mysql']['username'] do
  connection mysql_connection_info
  password node['openmeetings_mysql']['password']
  database_name node['openmeetings_mysql']['database']
  action :grant
end

# same create commands, connection info as an external hash
mysql_database node['openmeetings_mysql']['database'] do
  connection mysql_connection_info
  action :create
end

