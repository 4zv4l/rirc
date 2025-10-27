use Terminal::UI 'ui';
use Terminal::ANSI::OO 't';

unit class rirc::UI;

has $.irc is rw;
has $.ui is rw;
has $.nick is rw;
has $.message-pane is rw;
has $.channels-pane is rw;
has $.input-pane is rw;
has $.focused-channel is rw = '*';

my @channels;   # currently connected channels
my %chan-msg;   # channels => { @messages }

# create UI
method setup-design {
    ui.setup: heights => [ fr => 1, 1, 1 ];
    ($!message-pane, $!channels-pane, $!input-pane) = ui.panes;
    ui.focus(pane => 2);
    $.nick = nickColor($.nick);
    $!input-pane.update(:0line, "$.nick: █");
    ui.mode = 'input';
    return ui;
}

# input handling
method line-handling {
    my $contents;
    sub edit-line($c) {
        my \pane := $!input-pane;
        given $c {
            $contents = pane.meta[0]<contents> // '';
            when 'Enter' {
                if $contents.chars > 0 {
                    $!irc.handle-input($contents);
                    $.nick = nickColor($.irc.irc.servers.first.value.current-nick);
                    $contents = "";
                    pane.update( :0line, "$.nick: █", meta => %( :$contents ) );
                }
            }
            when 'Delete' {
                if $contents.chars > 0 {
                    $contents .= substr(0, $contents.chars - 1) ;
                    pane.update( :0line, "$.nick: $contents█", meta => %( :$contents ) );
                }
            }
            # switch to messages pane to scroll messages
            when 'Esc' {
                ui.mode = 'command';
                ui.focus(pane => 0);
            }
            # channels navigation
            when 'Tab' {
                if @channels.elems > 1 {
                    my $current-idx   = @channels.first(* eq $.focused-channel, :k);
                    my $next-chan     = @channels[($current-idx+1) % @channels.elems];
                    self.switch-chan($next-chan);
                }
            }
            when 'Untab' {
                if @channels.elems > 1 {
                    my $current-idx   = @channels.first(* eq $.focused-channel, :k);
                    my $next-chan     = @channels[($current-idx-1) % @channels.elems];
                    $.focused-channel = $next-chan;
                    self.switch-chan($next-chan);
                }
            }
            default {
                $contents ~= $c;
                pane.update( :0line, "$.nick: $contents█", meta => %( :$contents ) );
            }
        }
    }

    # bind Esc for message-pane to switch back to input-pane
    ui.bind: 'Esc' => {
        ui.focus(pane => 2);
        ui.mode = 'input';
        my $content = 
        $!input-pane.update(:0line, "$.nick: $contents█", meta => %( :$contents ))
    }
    $!input-pane.on: input => &edit-line;
    # Terminal::UI needs a binding to 'quit'
    ui.bind: 'Unknown' => 'quit';
    ui.ui-bindings<q>:delete;
    ui.ui-bindings<h>:delete;
    ui.ui-bindings<Untab>:delete;
}

# switch to focused-channel
method switch-chan($chan) {
    # clear current messages
    $!message-pane.clear;
    # change current channel
    $.focused-channel = $chan;
    # update-channel bar
    self.update-chan($.focused-channel, :force);
    # add all the messages
    if %chan-msg{$.focused-channel}:exists {
        for %chan-msg{$.focused-channel} -> $msgs {
            for $msgs[] -> $nick, $msg {
                self.show-msg($.focused-channel, $nick, $msg, :!append);
            }
        }
    }
}

# add new channels to the channels-pane
# with the $force, update the channels-pane even if
# the channel was already in the @channels
method update-chan($chan, :$force = False) {
    my $to-add = not @channels (cont) $chan;
    @channels.push($chan) if $to-add;
    %chan-msg{$chan} = [] if $to-add;

    if $to-add or $force {
        my $channels = @channels.join(' ').subst($.focused-channel, "\e[1m\e[3m" ~ $.focused-channel ~ "\e[0m");
        $.channels-pane.update(:0line, $channels);
    }
}

# delete messages from channel chan-msg
# clear the channel screen
method clear-current-chan() {
    %chan-msg{$.focused-channel} = ();
    $!message-pane.clear;
}

# use very silly algorithm to get a color for a nickname
# the color will be the same for a same nickname
sub nickColor(Str $nick --> Str) {
    my @colors = <red green yellow blue magenta cyan>;
    my $color = @colors[$nick.split('', :skip-empty)>>.ord.sum % @colors.elems];
    t."$color"() ~ $nick ~ t.text-reset
}

# print messages to the UI only if the channel matches the currently focused one
# append message to chan-msg for later switch-chan if $append is True
method show-msg($chan, $nick, $msg, :$append = True) {
    %chan-msg{$chan}.append([$nick, $msg]) if $append;
    return unless $chan eq $.focused-channel;

    my $time = t.black ~ DateTime.now.hh-mm-ss ~ t.text-reset;
    $nick.chars > 0 ??
    $.message-pane.put: "$time {nickColor($nick)}: $msg", :wrap<hard>
    !!
    $.message-pane.put: "$time $msg", :wrap<hard>;

}

method start($irc) is export {
    $.irc = $irc;
    self.ui  = self.setup-design;
    self.line-handling;
    $.ui.interact;
    $.ui.shutdown;
}

method quit {
    ui.shutdown;
    exit;
}
