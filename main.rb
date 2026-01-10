# encoding: BINARY
# frozen_string_literal: true
Encoding.default_external = Encoding::BINARY
Encoding.default_internal = Encoding::BINARY

POKER_LOG_ARRAY = File.readlines(ARGV.first).map{_1.split(',').first}.reverse
RICH_DATA_PLAYERS = Hash.new
RICH_DATA_LOG = [{}]

turn_index = 0

POKER_LOG_ARRAY.each_with_index do |log_line, line_index|
  if log_line.match(/^"Player stacks: /) then
    turn_index += 1
    RICH_DATA_LOG[turn_index] = RICH_DATA_LOG[turn_index - 1].transform_values(&:dup)
    
    RICH_DATA_LOG[turn_index - 1].each_value do |player|
      player[:stack] ||= player[:buy].dup
    end
    
    log_line.split(' | ').each do |stack_string|
      id, stack = stack_string.match(/#\d+ "".+?@ (.+?)"" \((\d+?)\)/).captures
      RICH_DATA_LOG[turn_index][id][:stack] = stack.to_i
    end
  elsif match_data = log_line.match(/""(.+?) @ (.+?)"" (joined the game) with a stack of (\d+?)\."/) ||
        match_data = log_line.match(/""(.+?) @ (.+?)"" (sit back) with the stack of (\d+?)\."/) then
    player_name, id, mode, buy = match_data.captures
    RICH_DATA_LOG[turn_index][id] ||= Hash.new
    
    if mode == 'joined the game'
      if RICH_DATA_PLAYERS[id] then
        unless RICH_DATA_PLAYERS[id][:aliases].include?(player_name)
          RICH_DATA_PLAYERS[id][:aliases] << player_name
          RICH_DATA_PLAYERS[id][:full_name] = RICH_DATA_PLAYERS[id][:aliases].join(', ')
        end
      else
        RICH_DATA_PLAYERS[id] = {aliases: [player_name], full_name: player_name}
      end
      
      if RICH_DATA_LOG[turn_index][id][:returning] then
        RICH_DATA_LOG[turn_index][id][:returning] = false
        # The game prints asymmetric buy-in join upon returning from being away and we ignore it, because it is not matched with a leave and is duplicating the sitback.
      else
        RICH_DATA_LOG[turn_index][id][:buy] = RICH_DATA_LOG[turn_index - 1].dig(id, :buy).to_i + buy.to_i
        RICH_DATA_LOG[turn_index][id][:stack] = buy.to_i
      end
    elsif mode == 'sit back' then
      RICH_DATA_LOG[turn_index][id][:returning] = true
      RICH_DATA_LOG[turn_index][id][:buy] = RICH_DATA_LOG[turn_index - 1].dig(id, :buy).to_i + buy.to_i
      RICH_DATA_LOG[turn_index][id][:stack] = buy.to_i
    end
  elsif match_data = log_line.match(/ @ (.+?)"" quits the game with a stack of (\d+?)\."/) ||
        match_data = log_line.match(/ @ (.+?)"" stand up with the stack of (\d+?)\."/) then
    id, sell = match_data.captures
    RICH_DATA_LOG[turn_index][id] ||= Hash.new
    RICH_DATA_LOG[turn_index][id][:buy] = RICH_DATA_LOG[turn_index - 1].dig(id, :buy).to_i - sell.to_i
    RICH_DATA_LOG[turn_index][id][:stack] = 0
  elsif match_data = log_line.match(/^"The admin updated the player "".+? @ (.+?)"" stack from (\d+?) to (\d+?)\."/) then
    id, old_stack, new_stack = match_data.captures
    RICH_DATA_LOG[turn_index][id] ||= Hash.new
    RICH_DATA_LOG[turn_index][id][:buy] = RICH_DATA_LOG[turn_index - 1].dig(id, :buy).to_i + (new_stack.to_i - old_stack.to_i)
    RICH_DATA_LOG[turn_index][id][:stack] = new_stack.to_i
  end
end

SIMPLE_DATA_PLAYERS = RICH_DATA_PLAYERS.map{_1.last[:full_name]}
SIMPLE_DATA_NET_PNL = [{}]

RICH_DATA_LOG.each_with_index do |turn_data, turn_index|
  SIMPLE_DATA_NET_PNL[turn_index] = Hash.new
  
  RICH_DATA_PLAYERS.each do |player_id, player_record|
    if turn_data[player_id]
      SIMPLE_DATA_NET_PNL[turn_index][player_record[:full_name]] = turn_data[player_id][:stack] - turn_data[player_id][:buy]
    else
      SIMPLE_DATA_NET_PNL[turn_index][player_record[:full_name]] = 0
    end
  end
end

# Build TSV: "1\t150\t-50\t0\n2\t125\t25\t-25\n3\t175\t-75\t50"
DATA_STR = SIMPLE_DATA_NET_PNL.each_with_index.map do |hand, hand_index|
  [hand_index + 1, *SIMPLE_DATA_PLAYERS.map{|player| hand[player]}].join(?\t)
end.join(?\n)

# Plot with explicit titles, no columnhead()
PLOT_SEGMENTS = SIMPLE_DATA_PLAYERS.each_with_index.map do |player_name, player_index|
  "'-' using 1:#{player_index + 2} with lines lw 1.5 title '#{player_name}'"
end

LOG_BASENAME = File.basename(ARGV.first, '.*').sub(/^poker_now_log_/, '')
LOG_START_TIME = File.readlines(ARGV.first).last.split(',')[1]

IO.popen('gnuplot -persist', 'w') do |gp|
  gp.puts <<~GP
    set title 'Poker night net PNL' font ',12'
    set xlabel 'Hand' font ',9'
    set ylabel 'Net chips' font ',9'
    set label "Started: #{LOG_START_TIME}" at screen 0.015,0.985 left
    set label "Filename: #{LOG_BASENAME}" at screen 0.015,0.965 left
    set key inside right top
    set border lw 1.5
    set mxtics 2
    set mytics 2
    set xtics 20 nomirror
    set ytics 2000 nomirror
    set grid xtics mxtics ytics mytics lw 1.6 lc rgb '#e0e0e0' behind
    set terminal qt noenhanced size 1366,768
    plot #{PLOT_SEGMENTS.join(', ')}
  GP
  
  SIMPLE_DATA_PLAYERS.size.times do
    gp.puts(DATA_STR)
    gp.puts(?e)
  end
  
  gp.puts <<~GP
    set terminal svg noenhanced size 1366,768
    set output '#{LOG_BASENAME}.svg'
    replot
    set output
    set terminal jpeg interlace noenhanced size 1366,768
    set output '#{LOG_BASENAME}.jpg'
    replot
    set output
  GP
end
