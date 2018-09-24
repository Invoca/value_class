# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::AbstractMysqlAdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection
      @connection.extend(ActiveTableSet::Extensions::AbstractMysqlAdapterOverride)
    end

    subject(:sql_query) { @connection.exec_query("some sql command") }

    context "on ActiveRecord::StatementInvalid" do
      let(:timeout_exception) { ActiveRecord::StatementInvalid.new("Got timeout reading communication packets: ...") }
      let(:raise_expected_error) do
        raise_error(timeout_exception.class, timeout_exception.message)
      end

      context "packets out of order" do
        let(:timeout_exception) { ActiveRecord::StatementInvalid.new("Packets out of order") }
        let(:raise_expected_error) do
          error = "'Packets out of order' error was received from the database. " \
                  "Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. " \
                  "If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
          raise_error(ActiveRecord::StatementInvalid, error)
        end

        it "wraps the exception message into a more helpful update for mysql bindings" do
          expect(@connection).to receive(:log).with("some sql command", "SQL").and_raise(timeout_exception)
          expect { sql_query }.to raise_expected_error
        end
      end

      context "row lock timeout" do
        let(:timeout_exception) { ActiveRecord::StatementInvalid.new("Lock wait timeout exceeded; try restarting transaction: ...") }

        it "log the mysql status context when logging is enabled" do
          expect(@connection).to receive(:log).with("some sql command", "SQL").and_raise(timeout_exception)
          expect(@connection).to receive(:log).with("SHOW ENGINE INNODB STATUS;")
          expect(@connection).to receive(:log).with("SHOW FULL PROCESSLIST;")

          expect { sql_query }.to raise_expected_error
        end

        it "doesn't log the mysql status context when the query succeeds" do
          expect(@connection).to receive(:log).with("some sql command", "SQL").and_return(Struct.new(:fields, :to_a).new([], []))
          expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
          expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

          @connection.exec_query("some sql command")
        end

        context "skip logging" do
          subject(:sql_query) { @connection.exec_query("some sql command", :skip_logging) }

          it "doesn't log the engine status" do
            expect(@connection).to receive(:non_nil_connection).and_return(@connection)
            expect(@connection).to receive(:query).with("some sql command").and_raise(timeout_exception)
            expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
            expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

            expect { sql_query }.to raise_expected_error
          end
        end
      end

      context "other exception" do
        it "doesn't log the mysql status context" do
          expect(@connection).to receive(:log).with("some sql command", "SQL").and_raise(timeout_exception)
          expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
          expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

          expect { sql_query }.to raise_expected_error
        end
      end
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
