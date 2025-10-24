use IRC::Client;

unit class rirc::IRC;

has $.nick is rw;
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
            $!ui.message-pane.put: "=> {$_}", :wrap<hard>;
        }
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
# TODO /join       - Joins a channel           - Usage: `/join <chan...>`
# TODO /me         - Sends emote message       - Usage: `/me <message>`
# TODO /msg        - Sends a message to a user - Usage: `/msg <nick> <message>`
# TODO /names      - Shows users in channel    - Usage: `/names`
# TODO /nick       - Sets your nick            - Usage: `/nick <nick>`
# TODO /help       - Displays this message     - Usage: `/help`
method handle-input($msg) {
    # simple message
    if $msg !~~ /^'/'/ {
        $!ui.message-pane.put: "{$!nick}: " ~ $msg, :wrap<hard>;
        $.irc.send(:where($.server), :text($msg));
        return;
    }

    # command
    my @msg = $msg.split(' ');
    given @msg {
        when '/nick' {
            $.irc.nick: (|@msg[1..*]);
        }
        when '/join' {
            $.irc.join: (@msg[1..*]);
        }
        when '/me' {

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
            $.irc.print: "{$action.uc} {@msg[1..*].join(' ')}";
        }
    }
}
