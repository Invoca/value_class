#
# Partition represents a set of one leader and zero or more followers.
#

module ActiveTableSet
  class Partition
    include ValueClass::Constructable

    value_attr      :partition_key
    value_attr      :leader,    class_name: 'ActiveTableSet::DatabaseConfig'
    value_list_attr :followers, class_name: 'ActiveTableSet::DatabaseConfig', insert_method: 'follower'

    def initialize(options={})
      super

      leader or raise ArgumentError, "must provide a leader"

      @keys = [leader] + followers
    end

    def leader_key
      leader
    end

    def follower_keys
      followers
    end


    def connection_key(access_mode: :write)
      case access_mode
      when :write, :read
        leader
      when :balanced
        chosen_follower
      else
        raise ArgumentError, "unknown access_mode"
      end
    end

    private


    # TODO - master and slave are all potential followers.
    #      - Want to be able to mark a partition as no for read.
    def chosen_follower
      if has_followers?
        @chosen_follower ||= @keys[follower_index+1]
      else
# TODO - Nil doesn't seem right here.
        nil
#        leader.key
      end
    end

    def has_followers?
      followers.count > 1
    end

    ## TODO - I want to keep this as a immutable value object,
    ##   I would prefer that this be passed in.
    def follower_index
      $$ % (@keys.count - 1)
    end
  end
end
