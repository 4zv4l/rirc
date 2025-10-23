#!/usr/bin/env raku

use lib "{$*PROGRAM.dirname}/lib";
use rirc::IRC;
use rirc::UI;
use Terminal::UI 'ui';

unit sub MAIN(
    Str  :$nick   = 'ano',               #= Nickname to use
    Str  :$server = 'irc.libera.chat',   #= IRC server to connect to
    UInt :$port   = 6697,                #= Port used by the IRC server
    Bool :$tls    = True,                #= Use TLS?
);

# protect the upper pane showing messages
my $lock = Lock.new;

# UI
my $ui = setup-ui($nick, $lock);

# IRC
setup-irc($nick, $server, $port, $tls, $ui, $lock);

# event loop
$ui.interact;
$ui.shutdown;
