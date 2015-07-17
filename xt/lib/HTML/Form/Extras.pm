
package HTML::Form::Extras;
use strict;
use warnings;

# Monkeying with the HTML::Form internals, so putting it in that
# package
sub HTML::Form::force_field {
    my ($self, $name, $value) = @_;


    if ($self->find_input($name)) {
        $self->{inputs} = [ grep { $_->name ne $name } @{$self->{inputs}} ];
    }

    $self->push_input( text => { name => $name, value => $value } );
}

1;
