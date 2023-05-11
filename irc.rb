#!/bin/ruby

require 'socket'

class IRC
  def initialize(server, channel, nickname, verbose = false)
    puts "[+] Connecting to #{server}:6667" if verbose
    @irc = TCPSocket.new server, 6667
    @irc.puts "USER #{nickname} #{nickname} #{nickname} :This is a fun bot"
    @irc.puts "NICK #{nickname}"
    until (msg = text) =~ /MODE #{nickname}/ do puts msg if verbose end
    @irc.puts "JOIN #{channel}"
    3.times { text } # skip JOIN motd
  end

  def send(channel, msg)
    @irc.puts "PRIVMSG #{channel} :#{msg}"
  end

  def text
    msg = @irc.gets
    @irc.puts "PONG #{msg.split[1][1..]}" if msg =~ /PING/
    msg
  end
end

channel = '#testit'
server = 'irc.freenode.net'
nickname = 'rbot'

irc = IRC.new(server, channel, nickname)

loop do
  puts msg = irc.text
  irc.send channel, "Hello #{$1} !" if msg =~ /:(.+)!.+PRIVMSG #{channel} :hello/
end
