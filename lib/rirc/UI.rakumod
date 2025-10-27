use Terminal::UI 'ui';
use Terminal::ANSI::OO 't';

unit class rirc::UI;

has $.irc is rw;
has $.ui is rw;
has $.message-pane is rw;
has $.channels-pane is rw;
has $.input-pane is rw;
has $.focused-channel is rw = '*';

my @channels;
my %chan-msg;

# create UI
# TODO: find a pretty way to show channels
# and to switch between them with key bindings
method setup-design {
    ui.setup: heights => [ fr => 1, 1, 1 ];
    ($!message-pane, $!channels-pane, $!input-pane) = ui.panes;
    ui.focus(pane => 2);
    return ui;
}

method line-handling {
    # message line handling
    my $contents;
    sub edit-line($c) {
        my \pane := $!input-pane;
        given $c {
            $contents = pane.meta[0]<contents> // '';
            when 'Enter' {
                if $contents.chars > 0 {
                    $!irc.handle-input($contents);
                    $contents = "";
                    pane.update( :0line, '█', meta => %( :$contents ) );
                }
            }
            when 'Delete' {
                if $contents.chars > 0 {
                    $contents .= substr(0, $contents.chars - 1) ;
                    pane.update( :0line, $contents ~ "█", meta => %( :$contents ) );
                }
            }
            when 'Esc' { # scroll in upper pane
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
                pane.update( :0line, $contents ~ "█", meta => %( :$contents ) );
            }
        }
    }

    # bind Tab for upper pane to switch to bottom pane in edit mode
    ui.bind: 'Esc' => {
        ui.focus(pane => 2);
        ui.mode = 'input';
        my $content = 
        $!input-pane.update(:0line, $contents ~ '█', meta => %( :$contents ))
    }
    # unbind q and bind Esc to quit
    $!input-pane.on: input => &edit-line;
    ui.bind: 'Unknown' => 'quit'; # crashes without a quit binding it seems
    ui.ui-bindings<q>:delete;
    ui.ui-bindings<h>:delete;
    ui.ui-bindings<Untab>:delete;
}

method setup-finalize {
    $!input-pane.update(:0line, '█');
    ui.mode = 'input';
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

# only update channels-pane on new channel
method update-chan($chan, :$force = False) {
    my $to-add = not @channels (cont) $chan;
    @channels.push($chan) if $to-add;
    %chan-msg{$chan} = [] if $to-add;

    if $to-add or $force {
        my $channels = @channels.join(' ').subst($.focused-channel, "\e[1m\e[3m" ~ $.focused-channel ~ "\e[0m");
        $.channels-pane.update(:0line, $channels);
    }
}

method clear-current-chan() {
    %chan-msg{$.focused-channel} = ();
    $!message-pane.clear;
}

sub nickColor(Str $nick --> Str) {
    my @colors = <black red green yellow blue magenta cyan>;
    my $color = @colors[$nick.split('', :skip-empty)>>.ord.sum % @colors.elems];
    t."$color"() ~ $nick ~ t.text-reset
}

# only show new messages on focused-channel
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
    self.setup-finalize;
    $.ui.interact;
    $.ui.shutdown;
}

method quit {
    ui.shutdown;
    exit;
}
