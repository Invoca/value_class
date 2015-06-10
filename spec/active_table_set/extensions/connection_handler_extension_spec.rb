require 'spec_helper'

describe ActiveTableSet::Extensions::ConnectionHandlerExtension do
  context "connection handler extension" do

    it "has thread variables when prepended"
    it "returns the thread connection spec when set"
    it "overwrites the connection classes"
    it "can return the pool for a spec"
    it "can return the current config"
    # TODO - move to connection handler extension test
    # it "adds the access policy to the class" do
    #   connection = connection_handler.connection
    #   expect(connection.respond_to?(:access_policy)).to eq(true)
    #
    #   expect(connection.access_policy.disallow_read).to eq("cf_%")
    # end

    # # TODO - now a method on connection_handler_extension
    # it "adds the using method to the connection class" do
    #   connection_manager
    #   connection = connection_handler.connection
    #   expect(connection.respond_to?(:using)).to eq(true)
    #
    #   @called_block = false
    #   expect(ActiveTableSet).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
    #   connection.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
    #     @called_block = true
    #   end
    #
    #   expect(@called_block).to eq(true)
    # end


  end
end
