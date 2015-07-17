package Helper::Class::Schema;

use strict;
use warnings;
use Class::Std;

use Helper::Class;

use base qw/ Helper::Class /;

{
    my %schema_of
        :ATTR( get => 'schema', set => 'schema', init_arg => 'schema' );
}

1;
__END__

=head1 NAME

Helper::Class::Schema - a simple class to provide common useful db stuff

=head1 SYNOPSIS

use Helper::Class::Schema;

use base qw/ Helper::Class::Schema /;

# provides

$schema->get_schema;

$schema->set_schema( $blah );

=head1 AUTHOR

Jason Tang

=cut


