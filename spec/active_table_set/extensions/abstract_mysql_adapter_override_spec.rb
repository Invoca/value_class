# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::AbstractMysqlAdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection
      @connection.extend(ActiveTableSet::Extensions::AbstractMysqlAdapterOverride)
    end

    subject(:sql_query) { @connection.exec_query(sql_command) }
    let(:sql_command) { "some sql command" }

    context "on ActiveRecord::StatementInvalid" do
      let(:exception) { ActiveRecord::StatementInvalid.new("Got timeout reading communication packets: ...") }
      let(:raise_expected_error) { raise_error(exception.class, /#{exception.message}/) }

      context "packets out of order" do
        let(:exception) { ActiveRecord::StatementInvalid.new("Packets out of order") }
        let(:raise_expected_error) do
          message = "'Packets out of order' error was received from the database. " \
                    "Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. " \
                    "If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
          raise_error(ActiveRecord::StatementInvalid, message)
        end

        it "wraps the exception message into a more helpful update for mysql bindings" do
          expect(@connection).to receive(:log).with(sql_command, "SQL").and_raise(exception)
          expect { sql_query }.to raise_expected_error
        end

        it "handles wrapped exceptions" do
          expect(@connection).to receive(:non_nil_connection).and_return(@connection)
          expect(@connection).to receive(:query).with(sql_command).and_raise(exception)

          expect { sql_query }.to raise_expected_error
        end
      end

      context "row lock timeout" do
        let(:exception) { ActiveRecord::StatementInvalid.new("Lock wait timeout exceeded; try restarting transaction: ...") }
        let(:raise_expected_error) do
          message = "ActiveRecord::StatementInvalid: Lock wait timeout exceeded; try restarting transaction: ...: #{sql_command}\n\n" \
                    "SHOW ENGINE INNODB STATUS;\n\n" \
                    "SHOW FULL PROCESSLIST;"
          raise_error(ActiveRecord::StatementInvalid, message)
        end

        before(:each) do
          allow(@connection).to receive(:non_nil_connection).and_return(@connection)
          expect(@connection).to receive(:query).with("SHOW ENGINE INNODB STATUS;").and_return(Struct.new(:to_csv).new("SHOW ENGINE INNODB STATUS;"))
          expect(@connection).to receive(:query).with("SHOW FULL PROCESSLIST;").and_return(Struct.new(:to_csv).new("SHOW FULL PROCESSLIST;"))
        end

        it "log the mysql status context when logging is enabled" do
          expect(@connection).to receive(:log).with(sql_command, "SQL").and_call_original
          expect(@connection).to receive(:query).with(sql_command).and_raise(exception)
          expect(@connection).to receive(:log).with("SHOW ENGINE INNODB STATUS;", "SQL").and_call_original
          expect(@connection).to receive(:log).with("SHOW FULL PROCESSLIST;", "SQL").and_call_original

          expect { sql_query }.to raise_expected_error
        end

        it "handles wrapped exceptions" do
          expect(@connection).to receive(:log).with(sql_command, "SQL").and_call_original
          expect(@connection).to receive(:query).with(sql_command).and_raise(exception)
          expect(@connection).to receive(:log).with("SHOW ENGINE INNODB STATUS;", "SQL").and_call_original
          expect(@connection).to receive(:log).with("SHOW FULL PROCESSLIST;", "SQL").and_call_original

          expect { sql_query }.to raise_expected_error
        end

        context "skip logging" do
          subject(:sql_query) { @connection.exec_query(sql_command, :skip_logging) }
          let(:raise_expected_error) do
            message = "Lock wait timeout exceeded; try restarting transaction: ...\n\n" \
                    "SHOW ENGINE INNODB STATUS;\n\n" \
                    "SHOW FULL PROCESSLIST;"
            raise_error(ActiveRecord::StatementInvalid, message)
          end

          it "doesn't log the commands being run" do
            expect(@connection).to receive(:non_nil_connection).and_return(@connection)
            expect(@connection).to receive(:query).with(sql_command).and_raise(exception)
            expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
            expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

            expect { sql_query }.to raise_expected_error
          end
        end
      end

      context "other exception" do
        it "doesn't log the mysql status context" do
          expect(@connection).to receive(:log).with(sql_command, "SQL").and_raise(exception)
          expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
          expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

          expect { sql_query }.to raise_expected_error
        end
      end

      it "doesn't log the mysql status context when the query succeeds" do
        expect(@connection).to receive(:log).with(sql_command, "SQL").and_return(Struct.new(:fields, :to_a).new([], []))
        expect(@connection).to_not receive(:log).with("SHOW ENGINE INNODB STATUS;")
        expect(@connection).to_not receive(:log).with("SHOW FULL PROCESSLIST;")

        @connection.exec_query("some sql command")
      end
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
