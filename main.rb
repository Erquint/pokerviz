# encoding: UTF-8
# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

<<HINT
Made for parsing and charting PokerNow session logs with CRuby v3.2.2 and Gnuplot v6.0.4.
Example download hyperlink to an input file with mock ID follows.
https://www.pokernow.com/games/pglaJpG5HaabwUprNa2rbacub/poker_now_log_pglaJpG5HaabwUprNa2rbacub.csv
Example CLI usage pattern follows.
ruby ~/git_clone_zoo/pokerviz/main.rb ./poker_now_log_pglaJpG5HaabwUprNa2rbacub.csv
Example filepaths of outputs written to the working directory follow.
./pglaJpG5HaabwUprNa2rbacub.svg
./pglaJpG5HaabwUprNa2rbacub.jpg
A Gnuplot preview window will open along with file writing.
Nothing much is configurable at this point in development.
Resolution is hardcoded at 1366×768 but this really only affects the JPEG output as SVG is losslessly scalable.
Input files are not modified.
I may try bundling Gnuplot binaries along in the repository for portability, but CRuby of any modern version will still be an environmental dependency.
HINT

require 'csv'
require 'time'
require_relative 'log_events_parser'
require_relative 'player_state_manager'
require_relative 'session_processor'

def session_tsv(session)
  alphabetical_players = session.players.sort_by(&:full_player_name)
  rows = Array.new
  
  session.hands.each_with_index do |player_states, hand_index|
    hand = hand_index + 1
    row = [hand]
    
    alphabetical_players.each do |player|
      player_state = nil
      player.player_ids.each do |player_id|
        break player_state = player_states[player_id] if player_states.key?(player_id)
      end
      
      row.push(player_state&.net || 0)
    end
    
    rows.push(row.join(?\t))
  end
  
  full_player_names = alphabetical_players.map(&:full_player_name)
  
  return full_player_names, rows.join(?\n)
end

POKER_NIGHT_SESSION = PokerNight::Session.new(File.read(ARGV.first)).freeze
FULL_PLAYER_NAMES, TSV_TABLE = session_tsv(POKER_NIGHT_SESSION)
LOG_BASENAME = File.basename(ARGV.first, '.*').sub(/^poker_now_log_/, '')

IO.popen('gnuplot -persist', 'w') do |gnuplot_stream|
  gnuplot_stream.puts(<<~GNUPLOT_INPUT)
    set title 'Poker night net PNL' font ',12'
    set xlabel 'Hand' font ',9'
    set ylabel 'Net chips' font ',9'
    set label "Started: #{POKER_NIGHT_SESSION.datetime.iso8601}" at screen 0.015,0.985 left
    set label "Filename: #{LOG_BASENAME}" at screen 0.015,0.965 left
    set key inside right top
    set border lw 1.5
    set mxtics 2
    set mytics 2
    set xtics 20 nomirror
    set ytics 2000 nomirror
    set grid xtics mxtics ytics mytics lw 1.6 lc rgb '#e0e0e0' behind
    set terminal qt noenhanced size 1366,768
    plot #{FULL_PLAYER_NAMES.each_with_index.map{|player_name, i| "'-' using 1:#{i + 2} with lines lw 1.5 title '#{player_name}'"}.join(', ')}
    #{"#{TSV_TABLE}\ne\n" * FULL_PLAYER_NAMES.size}
    set terminal svg noenhanced size 1366,768
    set output '#{LOG_BASENAME}.svg'
    replot
    set terminal jpeg interlace noenhanced size 1366,768
    set output '#{LOG_BASENAME}.jpg'
    replot
  GNUPLOT_INPUT
end
