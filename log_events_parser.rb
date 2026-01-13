# encoding: UTF-8
# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module PokerNight
  class LogEvent
    attr_reader :event_type, :udt, :iso8601, :player_name, :old_player_id,
      :player_id, :admin_name, :admin_id, :chips, :hand, :hand_id, :game_type,
      :dealer_name, :dealer_id, :cards, :combo, :old_stack, :stack,
      :old_big_blind, :big_blind, :old_small_blind, :small_blind, :old_ante,
      :ante, :player_stacks
    
    CARD_P = /[0-9JQKA]{1,2}[♦♥♣♠]/
    # CARD_P = /[0-9JQKA]{1,2}[♦♥♣♠dhcs]/
    PLAYER_P = /"(.+?) @ (.+?)"/
    
    def initialize(row_hash, debug)
      event_string = row_hash[:entry]
      @iso8601 = row_hash[:at]
      @udt = row_hash[:order]
      
      if match_data = event_string.match(/^#{PLAYER_P} folds$/) then
        @player_name, @player_id = match_data.captures
        @event_type = :fold
      elsif match_data = event_string.match(/^#{PLAYER_P} checks$/) then
        @player_name, @player_id = match_data.captures
        @event_type = :check
      elsif match_data = event_string.match(/^#{PLAYER_P} calls (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :call
      elsif match_data = event_string.match(/^#{PLAYER_P} bets (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :bet
      elsif match_data = event_string.match(/^#{PLAYER_P} raises to (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :raise
      elsif match_data = event_string.match(/^-- starting hand #(\d+?) \(id: (.+?)\)  \((.+?)\) \(dealer: #{PLAYER_P}\) --$/) then
        @hand, @hand_id, @game_type, @dealer_name, @dealer_id = match_data.captures
        @event_type = :hand_start
      elsif match_data = event_string.match(/^-- starting hand #(\d+?) \(id: (.+?)\)  \((.+?)\) \(dead button\) --$/) then
        @hand, @hand_id, @game_type = match_data.captures
        @event_type = :hand_start_dead
      elsif match_data = event_string.match(/^-- ending hand #(\d+?) --$/) then
        @hand, = match_data.captures
        @event_type = :hand_end
      elsif match_data = event_string.match(/^Your hand is (#{CARD_P}, #{CARD_P})$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :your_hand
      elsif match_data = event_string.match(/^Player stacks: (?:#(\d+?) #{PLAYER_P} \((\d+?)\)(?: \| )?)+$/) then
        @player_stacks = process_stacks_string(event_string)
        @event_type = :player_stacks
      elsif match_data = event_string.match(/^#{PLAYER_P} posts a small blind of (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :small_blind
      elsif match_data = event_string.match(/^Dead Small Blind$/) then
        @event_type = :small_blind_dead
      elsif match_data = event_string.match(/^#{PLAYER_P} posts a big blind of (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :big_blind
      elsif match_data = event_string.match(/^Flop:  (\[#{CARD_P}, #{CARD_P}, #{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :flop
      elsif match_data = event_string.match(/^Flop \(second run\):  (\[#{CARD_P}, #{CARD_P}, #{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :flop_second
      elsif match_data = event_string.match(/^Turn: (#{CARD_P}, #{CARD_P}, #{CARD_P} \[#{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :turn
      elsif match_data = event_string.match(/^Turn \(second run\): (#{CARD_P}, #{CARD_P}, #{CARD_P} \[#{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :turn_second
      elsif match_data = event_string.match(/^River: (#{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P} \[#{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :river
      elsif match_data = event_string.match(/^River \(second run\): (#{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P} \[#{CARD_P}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :river_second
      elsif match_data = event_string.match(/^Uncalled bet of (\d+?) returned to #{PLAYER_P}$/) then
        @chips, @player_name, @player_id = match_data.captures
        @event_type = :bet_return
      elsif match_data = event_string.match(/^#{PLAYER_P} collected (\d+?) from pot$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :collect_pot
      elsif match_data = event_string.match(/^#{PLAYER_P} collected (\d+?) from pot with (.+?) \(combination: (#{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P})\)$/) then
        @player_name, @player_id, @chips, @combo, @cards = match_data.captures
        process_cards(@cards)
        @event_type = :collect_combo
      elsif match_data = event_string.match(/^#{PLAYER_P} shows a (#{CARD_P}(?:, #{CARD_P})?)\.$/) then
        @player_name, @player_id, @cards = match_data.captures
        process_cards(@cards)
        @event_type = :show_hand
      elsif match_data = event_string.match(/^Undealt cards:  ?((?:(?:, )?#{CARD_P} ?){0,4}\[(?:(?:, )?#{CARD_P}){1,5}\])$/) then
        @cards, = match_data.captures
        process_cards(@cards)
        @event_type = :undealt_cards
      elsif match_data = event_string.match(/^The player #{PLAYER_P} requested a seat\.$/) then
        @player_name, @player_id = match_data.captures
        @event_type = :seat_request
      elsif match_data = event_string.match(/^The admin approved the player #{PLAYER_P} participation with a stack of (\d+?)\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :stack_approved
      elsif match_data = event_string.match(/^The player #{PLAYER_P} joined the game with a stack of (\d+?)\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :join
      elsif match_data = event_string.match(/^The player #{PLAYER_P} quits the game with a stack of (\d+?)\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :quit
      elsif match_data = event_string.match(/^The player #{PLAYER_P} stand up with the stack of (\d+?)\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :stand_up
      elsif match_data = event_string.match(/^The player #{PLAYER_P} sit back with the stack of (\d+?)\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :sit_down
      elsif match_data = event_string.match(/^#{PLAYER_P} posts a missing small blind of (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :missed_small_blind
      elsif match_data = event_string.match(/^#{PLAYER_P} posts a missed big blind of (\d+?)$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :missed_big_blind
      elsif match_data = event_string.match(/^#{PLAYER_P} posts a big blind of (\d+?) and go all in $/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :big_blind_all_in
      elsif match_data = event_string.match(/^#{PLAYER_P} calls (\d+?) and go all in$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :call_all_in
      elsif match_data = event_string.match(/^#{PLAYER_P} bets (\d+?) and go all in$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :bet_all_in
      elsif match_data = event_string.match(/^#{PLAYER_P} raises to (\d+?) and go all in$/) then
        @player_name, @player_id, @chips = match_data.captures
        @event_type = :raise_all_in
      elsif match_data = event_string.match(/^The player #{PLAYER_P} changed the ID from (.+?) to (.+?) because authenticated login\.$/) then
        @player_name, @player_id, @old_player_id, @player_id = match_data.captures
        @event_type = :login_id_change
      elsif event_string.match(/^Remaining players decide whether to run it twice\.$/) then
        @event_type = :deciding_run_it_twice
      elsif match_data = event_string.match(/^#{PLAYER_P} chooses to not run it twice\.$/) then
        @player_name, @player_id = match_data.captures
        @event_type = :reject_run_it_twice
      elsif match_data = event_string.match(/^#{PLAYER_P} chooses to  run it twice\.$/) then
        @player_name, @player_id = match_data.captures
        @event_type = :accept_run_it_twice
      elsif event_string.match(/^Some players choose to not run it twice\.$/) then
        @event_type = :some_reject_run_it_twice
      elsif event_string.match(/^All players in hand choose to run it twice\.$/) then
        @event_type = :all_accept_run_it_twice
      elsif match_data = event_string.match(/^WARNING: the admin queued the stack change for the player #{PLAYER_P} reseting to (\d+?) chips in the next hand\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :stack_reset_warning
      elsif match_data = event_string.match(/^WARNING: the admin queued the stack change for the player #{PLAYER_P} adding (\d+?) chips in the next hand\.$/) then
        @player_name, @player_id, @stack = match_data.captures
        @event_type = :stack_add_warning
      elsif match_data = event_string.match(/^The admin updated the player #{PLAYER_P} stack from (\d+?) to (\d+?)\.$/) then
        @player_name, @player_id, @old_stack, @stack = match_data.captures
        @event_type = :stack_change
      elsif match_data = event_string.match(/^The game's big blind was changed from (\d+?) to (\d+?)\.$/) then
        @old_big_blind, @big_blind = match_data.captures
        @event_type = :big_blind_change
      elsif match_data = event_string.match(/^The game's small blind was changed from (\d+?) to (\d+?)\.$/) then
        @old_small_blind, @small_blind = match_data.captures
        @event_type = :small_blind_change
      elsif match_data = event_string.match(/^The game's ante was changed from (\d+?) to (\d+?)\.$/) then
        @old_ante, @ante = match_data.captures
        @event_type = :ante_change
      elsif match_data = event_string.match(/^The admin #{PLAYER_P} forced the player #{PLAYER_P} to away mode in the next hand\.$/) then
        @admin_name, @admin_id, @player_name, @player_id = match_data.captures
        @event_type = :forced_away
      elsif match_data = event_string.match(/^Game Config Changes$/) then
        process_config(event_string)
        @event_type = :config_change
      elsif match_data = event_string.match(/^#{PLAYER_P} collected (\d+?) from pot with (.+?) \(combination: (#{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P}, #{CARD_P})\)$/) then
        if debug == :abort || debug == :warn then
          warn("Illegal log entry ignored!\n#{event_string}")
        end
        @event_type = :illegal_collect_combo
      else
        if debug == :abort then
          abort("Unrecognized log entry!\n#{event_string}")
        elsif debug == :warn then
          warn("Unrecognized log entry!\n#{event_string}")
        end
        
        @event_type = :unrecognized
      end
      
      return self
    end
    
    def process_stacks_string(stacks_string)
      player_stacks = Hash.new
      stacks_string.sub(/^Player stacks: /, '').split(' | ').each do |player_substring|
        seat, player_name, player_id, stack = player_substring.match(/#(\d+?) #{PLAYER_P} \((\d+?)\)/).captures
        player_stacks[player_id] = {seat:, player_name:, stack:}
      end
      
      return player_stacks
    end
    
    def process_config(log_entry)
      
    end
    
    def process_cards(log_entry)
      
    end
  end
end
