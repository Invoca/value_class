# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::Mysql2AdapterOverride do
  context "Mysql2AdapterOverride" do
    let(:config) { {} }

    before :each do
      small_table_set
      ActiveTableSet.enable
      conf = StubDbAdaptor::SAMPLE_CONFIG.merge(config)
      @connection = StubDbAdaptor.stub_db_connection(conf)
    end

    it "responds to attr reader config" do
      expect(@connection).to respond_to(:config)
    end

    describe "wait_timeout variable" do
      context "is not defined in config" do
        it "sets a default wait_timeout in MySQL" do
          commands = @connection.instance_variable_get(:@connection).called_commands
          expect(commands.count).to eq(1)
          _command, command_args, _ = commands.first
          arg = command_args.first
          expect(arg).to match(/@@wait_timeout = 2147483/)
        end
      end

      context "is defined in config" do
        let(:config) { { wait_timeout: 28800 } }

        it "sets a MySQL wait_timeout from config value" do
          commands = @connection.instance_variable_get(:@connection).called_commands
          expect(commands.count).to eq(1)
          _command, command_args, _ = commands.first
          arg = command_args.first
          expect(arg).to match(/@@wait_timeout = 28800/)
        end
      end
    end

    describe "net_read_timeout variable" do
      context "is not defined in config" do
        it "is not set in MySQL" do
          commands = @connection.instance_variable_get(:@connection).called_commands
          expect(commands.count).to eq(1)
          _command, command_args, _ = commands.first
          arg = command_args.first
          expect(arg).not_to match(/@@net_read_timeout =/)
        end
      end

      context "is defined in config" do
        let(:config) { { net_read_timeout: 1800 } }

        it "is set in MySQL" do
          commands = @connection.instance_variable_get(:@connection).called_commands
          expect(commands.count).to eq(1)
          _command, command_args, _ = commands.first
          arg = command_args.first
          expect(arg).to match(/@@net_read_timeout = 1800/)
        end
      end
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
