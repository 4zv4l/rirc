use IRC::Client;

unit class rirc::IRC;

has $.nick is rw;
has @.channels is rw;
has $.focused-channel is rw = "Default";
has $.server;
has $.port;
has $.tls;
has $.ui is rw;
has $.lock is rw;
has $.irc is rw;

class BasicClient does IRC::Client::Plugin {
    has $.lock;
    has $.ui;

    method irc-all($_) {
        $.lock.protect: {
            given $_ {
                $!ui.message-pane.put:
                    .nick ?? "{.args[0]} {.nick}: {.Str}" !! "{.Str}",
                    :wrap<hard>;
            }
        }
        Nil
    }
}

method start {
    $.irc = IRC::Client.new:
        :$.nick,
        :alias($.nick, /foo.../),
        :@.channels,
        :host($.server),
        :$.port,
        :ssl($.tls),
        :plugins(BasicClient.new(:$.lock, :$.ui));
    @.channels.push: "Default";
    $.irc.run;
}

# Target is to handle at least those commands
#
# /quit            - Quit                      - Usage: `/quit`
# /clear           - Clears current tab        - Usage: `/clear`
# TODO /switch     - Switches to tab           - Usage: `/switch <tab name>`
# TODO /close      - Closes current tab        - Usage: `/close`
# /join            - Joins a channel           - Usage: `/join <chan...>`
# TODO /me         - Sends emote message       - Usage: `/me <message>`
# /msg             - Sends a message to a user - Usage: `/msg <nick> <message>`
# TODO /names      - Shows users in channel    - Usage: `/names`
# /nick            - Sets your nick            - Usage: `/nick <nick>`
# TODO /help       - Displays this message     - Usage: `/help`
method handle-input($msg) {
    # simple message
    if $msg !~~ /^'/'/ {
        $!ui.message-pane.put: "{@.channels[0]} {$!nick}: " ~ $msg, :wrap<hard>;
        $.irc.send(:where(@.channels[0]), :text($msg));
        return;
    }

    # command
    my $socket = $.irc.servers.first.value.socket;
    my @msg = $msg.split(' ');
    given @msg[0] {
        when '/nick' {
            $.irc.nick: (|@msg[1..*]);
        }
        when '/join' {
            $.irc.join: (@msg[1]);
            @.channels.push(@msg[1]) unless @.channels (cont) @msg[1];
            $.focused-channel = @msg[1];
            my $channels = @.channels.join(' ').subst($.focused-channel, "\e[1m" ~ $.focused-channel ~ "\e[21m");
            $.ui.channels-pane.update(:0line, $channels);
        }
        when '/msg' {
            $.irc.send(:where(@msg[1]), :text(@msg[2..*].join(' ')));
        }
        when '/clear' {
            $.lock.protect: { 
                $.ui.message-pane.clear;
            }
        }
        when '/quit' {
            $.lock.protect: {
                $.irc.quit;
                $.ui.ui.shutdown;
                exit;
            }
        }
        default {
            # send command raw
            my $action = @msg[0].subst('/');
            $!ui.message-pane.put: "sending raw message: " ~ $action, :wrap<hard>;
            $socket.say: "{$action.uc} {@msg[1..*].join(' ')}";
        }
    }
}
