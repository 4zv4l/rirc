use IRC::Client;
use Terminal::ANSI::OO 't';

unit class rirc::IRC;

has $.nick is rw;
has @.channels is rw;
has $.server;
has $.port;
has $.tls;
has $.ui is rw;             # ref to rirc::UI
has $.irc is rw;            # ref to IRC::Client

# used when getting message right after changing nick
my $old-nick;

# incoming message part
class BasicClient does IRC::Client::Plugin {
    has $.ui;
    has $.server;

    method irc-all($_) {
        given $_ {
            my $nick = try { .nick } // '*';
            my $chan = try { .channel } // ($.server ~~ /:i $nick/ ?? '*' !! $nick);
            # when renaming with /nick
            $chan = '*' if $nick eq $old-nick or $nick eq .irc.servers.first.value.current-nick;
            my $msg  = .Str;
            $!ui.update-chan($chan);
            $!ui.show-msg($chan, $nick, $msg);
        }
        Nil
    }
}

# outgoing message part
method handle-input($msg) {
    # sending simple message
    if $msg !~~ /^'/'/ {
        $.ui.show-msg($!ui.focused-channel, $.nick, $msg);
        $.irc.send(:where($!ui.focused-channel), :text($msg));
        return;
    }

    # user command
    my $socket = $.irc.servers.first.value.socket;
    my @msg = $msg.split(' ');
    given @msg[0] {
        when '/nick' {
            $old-nick = $.irc.servers.first.value.current-nick;
            $.irc.nick: (|@msg[1..*]);
            $.nick = $.irc.servers.first.value.current-nick;
        }
        when '/join' {
            $.irc.join: (@msg[1]);
            $.ui.switch-chan(@msg[1]);
        }
        when '/msg' {
            $.irc.send(:where(@msg[1]), :text(@msg[2..*].join(' ')));
        }
        when '/clear' {
            $.ui.clear-current-chan;
        }
        when '/quit' {
            $.irc.quit;
            $.ui.quit;
        }
        default {
            # send command raw
            my $action = @msg[0].subst('/');
            $!ui.message-pane.put: t.black ~ "sending raw message: $action" ~ t.text-reset, :wrap<hard>;
            $socket.say: "{$action.uc} {@msg[1..*].join(' ')}";
        }
    }
}

method start {
    $.irc = IRC::Client.new:
    :$.nick,
    :alias($.nick, /rirc.../),
    :@.channels,
    :host($.server),
    :$.port,
    :ssl($.tls),
    :plugins(BasicClient.new(:$.nick, :$.server, :$.ui));

    $old-nick = $.nick;

    $.irc.run;
}
