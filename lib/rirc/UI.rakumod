use Terminal::UI 'ui';

unit class rirc::UI;

has $.irc is rw;
has $.lock is rw;
has $.ui is rw;
has $.message-pane is rw;
has $.channels-pane is rw;
has $.input-pane is rw;

# create UI
# TODO: find a pretty way to show channels
# and to switch between them with key bindings
method setup-design {
    ui.setup: heights => [ fr => 1, 1, 1 ];
    ($!message-pane, $!channels-pane, $!input-pane) = ui.panes;
    $!channels-pane.update(:0line, "\e[1mDefault\e[21m");
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
                    $!lock.protect: {
                        $!irc.handle-input($contents);
                    }
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
            when 'Tab' {}
            when 'Untab' {}
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

method start($irc) is export {
    $.irc = $irc;
    self.ui  = self.setup-design;
    self.line-handling;
    self.setup-finalize;
    $.ui.interact;
    $.ui.shutdown;
}
