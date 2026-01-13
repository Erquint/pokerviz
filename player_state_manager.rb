# encoding: UTF-8
# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module PokerNight
  class PlayerState
    attr_accessor :player_id, :player_name
    attr_reader :stack, :net
    
    def initialize(hand:, player_id:, player_name:, buy: nil, sell: nil, stack: nil, net: nil)
      @hand = hand.to_i
      @player_id = player_id.to_s
      @player_name = player_name.to_s
      @buy = buy.to_i
      @sell = sell.to_i
      @stack = stack.to_i
      @net = net.to_i
      
      return self
    end
    
    def buy(stack = nil, old_stack = nil)
      return @buy unless stack
      stack_i = stack.to_i
      @buy += stack_i - old_stack.to_i
      @stack = stack_i
      update_net()
      
      return @buy
    end
    
    def sell(stack = nil)
      return @sell unless stack
      @sell += stack.to_i
      @stack = 0
      update_net()
      
      return @sell
    end
    
    def stack=(stack)
      @stack = stack.to_i
      update_net()
      
      return @stack
    end
    
    private def update_net
      return @net = @stack + @sell - @buy
    end
  end
  
  class Player
    attr_reader :player_ids, :player_names
    
    def initialize(player_id:, player_name:)
      @player_ids = Set.new
      @player_names = Set.new
      self.player_id = player_id
      self.player_name = player_name
      
      return self
    end
    
    def player_id=(player_id)
      @player_ids.add(player_id)
      
      return player_id
    end
    
    def player_name=(player_name)
      @player_names.add(player_name)
      
      return player_name
    end
    
    def full_player_name()
      return @player_names.join(', ')
    end
  end
  
  class Players < Set
    def find_by_id(player_id)
      return self.find{_1.player_ids.include?(player_id)}
    end
    
    def find_by_name(player_name)
      return self.find{_1.player_names.include?(player_name)}
    end
    
    def add_player(player_id, player_name)
      if player = self.find_by_id(player_id) then
        player.player_name = player_name
      else
        self.add(player = Player.new(player_id:, player_name:))
      end
      
      return player
    end
    
    def add_player_id(old_player_id, new_player_id)
      return self.find_by_id(old_player_id).player_id = new_player_id
    end
  end
end
