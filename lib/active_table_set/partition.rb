#
# Partition represents a set of one leader and zero or more followers.
#

module ActiveTableSet
  class Partition
    attr_reader :index

    # must have 1 leader and can have 0..x followers
    def initialize(leader_key:, follower_keys: [], index: 0)
      @keys  = [leader_key].concat(follower_keys)
      @index = index
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

    def keys
      @keys
    end

    def leader
      keys.first
    end

    def chosen_follower
      if has_followers?
        @chosen_follower ||= keys[follower_index+1]
      else
        nil
      end
    end

    def has_followers?
      keys.count > 1
    end

    def follower_index
      $$ % (keys.count - 1)
    end
  end
end
