#!/usr/bin/env raku

use lib "{$*PROGRAM.dirname}/lib";
use rirc::IRC;
use rirc::UI;

unit sub MAIN(
    Str  :$nick   = 'ano',               #= Nickname to use
    Str  :$server = 'irc.libera.chat',   #= IRC server to connect to
    UInt :$port   = 6697,                #= Port used by the IRC server
    Bool :$tls    = True,                #= Use TLS?
    :@channels    = (),                  #= Channels to auto-join
);

# UI
my $ui = rirc::UI.new();

# IRC
my $irc = rirc::IRC.new(:$nick, :@channels, :$server, :$port, :$tls, :$ui);

# event loop
start $irc.start;
$ui.start($irc);
