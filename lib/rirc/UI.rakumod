unit module rirc::UI;

use Terminal::UI 'ui';

sub setup-ui($nick, $lock) is export {
    # create UI
    # TODO: find a pretty way to show channels
    # and to switch between them with key bindings
    ui.setup: heights => [ fr => 1, 1 ];
    my (\upper, \b) = ui.panes;
    ui.focus(pane => 1);

    # message line handling
    my $contents;
    sub edit-line($c) {
        my \pane := b;
        given $c {
            $contents = pane.meta[0]<contents> // '';
            when 'Enter' {
                if $contents.chars > 0 {
                    $lock.protect: {
                        upper.put: "$nick: " ~ $contents;
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
            when 'Tab' { # scroll in upper pane
                ui.mode = 'command';
                ui.focus(pane => 0);
            }
            default {
                $contents ~= $c;
                pane.update( :0line, $contents ~ "█", meta => %( :$contents ) );
            }
        }
    }

    # unbind q and bind Esc to quit
    b.on: input => &edit-line;
    ui.bind: 'Esc' => 'quit';
    ui.ui-bindings<q>:delete;
    ui.ui-bindings<h>:delete;
    ui.ui-bindings<Untab>:delete;

    # bind Tab for upper pane to switch to bottom pane in edit mode
    ui.bind: 'Tab' => {
        ui.focus(pane => 1);
        ui.mode = 'input';
        b.update(:0line, $contents ~ '█', meta => %( :$contents ))
    }

    b.update(:0line, '█');
    ui.mode = 'input';
    return ui;
}
