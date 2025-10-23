#!/usr/bin/env raku

use Terminal::UI 'ui';

sub setup-ui($nick, $lock) is export {
    # create UI
    # TODO: find a pretty way to show channels
    # and to switch between them with key bindings
    ui.setup: heights => [ fr => 1, 1 ];
    my (\upper, \b) = ui.panes;
    upper.selectable = False;
    b.selectable = False;
    ui.focus(pane => 1);

    # message line handling
    my $line = b.current-line-index; # always 0, only one line
    sub edit-line($c) {
        my \pane := b;
        given $c {
            my $contents = pane.meta[$line]<contents> // '';
            when 'Enter' {
                if $contents.chars > 0 {
                    $lock.protect: { upper.put: "$nick: " ~ $contents; }
                    $contents = "";
                    pane.update( :$line, $contents, meta => %( :$contents ) );
                }
            }
            when 'Delete' {
                if $contents.chars > 0 {
                    $contents .= substr(0, $contents.chars - 1) ;
                    pane.update( :$line, $contents ~ "█", meta => %( :$contents ) );
                }
            }
            default {
                $contents ~= $c;
                pane.update( :$line, $contents ~ "█", meta => %( :$contents ) );
            }
        }
    }

    # unbind q and bind Esc to quit
    b.on: input => &edit-line;
    ui.bind: 'Esc' => 'quit';
    ui.ui-bindings<q>:delete;

    ui.mode = 'input';
    return ui;
}
