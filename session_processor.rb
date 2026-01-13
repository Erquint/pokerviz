# encoding: UTF-8
# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module PokerNight
  class Session
    attr_reader :log_csv_table, :datetime, :events, :hands, :players
    
    CSV_OPTIONS = {
      row_sep: ?\n, col_sep: ?,, quote_char: ?", max_field_size: nil,
      headers: true, header_converters: :symbol,
      converters: proc do |field, field_info|
        if field_info.header == :at then
          next Time.parse(field)
        elsif field_info.header == :order then
          next Time.at(field.to_i.quo(10**5), in: ?Z)
        else
          next field
        end
      end
    }.freeze
    
    def initialize(full_log_string)
      @log_csv_table = CSV.parse(full_log_string, **CSV_OPTIONS)
      @log_csv_table.push(*@log_csv_table.delete(*@log_csv_table.size.pred.downto(0))).freeze # Mutative inversion of data row order.
      @datetime = @log_csv_table[:at][0]
      @events = @log_csv_table.map{|csv_row| LogEvent.new(csv_row, :abort)}.freeze
      @players = Players.new
      @hands = Array.new
      current_hand = 0
      @hands[current_hand] ||= Hash.new
      
      @events.each do |event|
        if event.event_type == :login_id_change then
          @players.add_player_id(event.old_player_id, event.player_id) if @players.find_by_id(event.old_player_id)
        elsif event.event_type == :hand_start || event.event_type == :hand_start_dead then
          current_hand = event.hand.to_i
          
          if @hands[current_hand - 1] then
            @hands[current_hand] ||= @hands[current_hand - 1].transform_values(&:dup)
          else
            @hands[current_hand] ||= Hash.new
          end
        elsif event.event_type == :stack_approved || event.event_type == :stack_change then
          @players.add_player(event.player_id, event.player_name)
          
          if @hands[current_hand - 1][event.player_id] then
            @hands[current_hand][event.player_id] ||= @hands[current_hand - 1][event.player_id].dup
          else
            @hands[current_hand][event.player_id] ||= PlayerState.new(hand: current_hand, player_id: event.player_id, player_name: event.player_name)
          end
          
          @hands[current_hand][event.player_id].buy(event.stack, event.old_stack)
        elsif event.event_type == :quit then
          if @hands[current_hand - 1][event.player_id] then
            @hands[current_hand][event.player_id] ||= @hands[current_hand - 1][event.player_id].dup
          else
            @hands[current_hand][event.player_id] ||= PlayerState.new(hand: current_hand, player_id: event.player_id, player_name: event.player_name)
          end
          
          @hands[current_hand][event.player_id].sell(event.stack)
        elsif event.event_type == :player_stacks then
          event.player_stacks.each do |player_id, data|
            player = @players.find_by_id(player_id)
            state_key = player.player_ids.find{@hands[current_hand].key?(_1)} || player_id
            @hands[current_hand][state_key] ||= PlayerState.new(hand: current_hand, player_id: state_key, player_name: player.full_player_name)
            @hands[current_hand][state_key].stack = data[:stack]
          end
        end
      end
      
      puts(<<~SUMMARY)
        Log begins at #{@datetime.strftime('%FT%T.%5NZ')}.
        #{@events.size} log entries processed.
        #{@hands.size} hands played in total.
        #{@players.size} players actively participated.
      SUMMARY
      
      return self
    end
  end
end
