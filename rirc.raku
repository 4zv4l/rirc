#!/usr/bin/env raku

use lib "{$*PROGRAM.dirname}";
use lib::IRC;
use lib::UI;
use Terminal::UI 'ui';

unit sub MAIN(
    :$nick   = 'foobar',            #= Nickname to use
    :$server = 'irc.libera.chat',   #= IRC server to connect to
    :$port   = 6697,                #= Port used by the IRC server
    :$tls    = True,                #= Use TLS?
);

# protect the upper pane showing messages
my $lock = Lock.new;

# IRC
setup-irc($nick, $server, $port, $tls, $lock);

# UI
my $ui = setup-ui($nick, $lock);
$ui.interact;
$ui.shutdown;
