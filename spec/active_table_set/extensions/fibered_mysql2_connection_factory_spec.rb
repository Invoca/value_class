# frozen_string_literal: true

require 'spec_helper'
require 'active_table_set/extensions/fibered_mysql2_connection_factory'

describe ActiveTableSet::Extensions::FiberedMysql2ConnectionFactory do
  before do
    ActiveTableSet.instance_variable_set(:@manager, nil)
    ActiveRecord::Base.default_connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
  end

  context "transactions" do
    it "should work with basic nesting" do
      configure_ats_like_ringswitch
      ActiveTableSet.enable

      connection_stub = Object.new
      allow(connection_stub).to receive(:query_options) { {} }
      query_args = []
      stub_mysql_client_result = Struct.new(:fields, :to_a).new([], [])
      expect(connection_stub).to receive(:query) do |*args|
        query_args << args
        stub_mysql_client_result
      end.at_least(1).times
      allow(connection_stub).to receive(:ping) { true }
      allow(connection_stub).to receive(:close)

      allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

      connection = ActiveRecord::Base.connection
      connection.transaction do
        connection.exec_query("show tables")
      end
      expect(query_args).to eq([
        ["SET SQL_AUTO_IS_NULL=0, NAMES 'utf8', @@wait_timeout = 2147483"],
        ["BEGIN"],
        ["show tables"],
        ["COMMIT"]
      ])
    end
  end
end
