use IRC::Client;

unit class rirc::IRC;

has $.nick is rw;
has $.server;
has $.port;
has $.tls;
has $.ui is rw;
has $.lock is rw;
has $.irc is rw;
has $.last-channel-joined is rw = "#foo";

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
        :channels(),
        :host($.server),
        :$.port,
        :ssl($.tls),
        :plugins(BasicClient.new(:$.lock, :$.ui));
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
        $!ui.message-pane.put: "{$.last-channel-joined} {$!nick}: " ~ $msg, :wrap<hard>;
        $.irc.send(:where($.last-channel-joined), :text($msg));
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
            $.last-channel-joined = @msg[1];
            $.irc.join: (@msg[1..*]);
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
