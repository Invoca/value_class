# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::AbstractMysqlAdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection()
      @connection.extend(ActiveTableSet::Extensions::AbstractMysqlAdapterOverride)
    end

    context "when a row lock timeout occurs" do
      it "log the engine status when a row lock timeout exception occurs and logging is enabled" do
        timeout_exception = ActiveRecord::StatementInvalid.new("Lock wait timeout exceeded; try restarting transaction: ...")
        expect(@connection).to receive(:log).with("some sql command", any_args).and_raise(timeout_exception)
        expect(@connection).to receive(:log).with("SHOW ENGINE INNODB STATUS;", any_args)

        begin
          @connection.exec_query("some sql command")
          fail "expected exception"
        rescue ActiveRecord::StatementInvalid => ex
          expect(ex.message).to eq("Lock wait timeout exceeded; try restarting transaction: ...")
        end
      end

      it "doesn't log the engine status when a the query succeeds" do
        expect(@connection).to receive(:log).with("some sql command", any_args).and_return(Struct.new(:fields, :to_a).new([], []))
        expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;", any_args)

        @connection.exec_query("some sql command")
      end

      it "doesn't log the engine status when a different exception is raised" do
        timeout_exception = ActiveRecord::StatementInvalid.new("Got timeout reading communication packets: ...")
        expect(@connection).to receive(:log).with("some sql command", any_args).and_raise(timeout_exception)
        expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;", any_args)

        begin
          @connection.exec_query("some sql command")
          fail "expected exception"
        rescue ActiveRecord::StatementInvalid => ex
          expect(ex.message).to eq("Got timeout reading communication packets: ...")
        end
      end

      it "doesn't log the engine status when a row lock timeout exception occurs and logging is disabled" do
        timeout_exception = ActiveRecord::StatementInvalid.new("Lock wait timeout exceeded; try restarting transaction: ...")
        expect(@connection).to receive(:non_nil_connection).and_return(@connection)
        expect(@connection).to receive(:query).with("some sql command").and_raise(timeout_exception)
        expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;", any_args)

        begin
          @connection.exec_query("some sql command", :skip_logging)
          fail "expected exception"
        rescue ActiveRecord::StatementInvalid => ex
          expect(ex.message).to eq("Lock wait timeout exceeded; try restarting transaction: ...")
        end
      end
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
