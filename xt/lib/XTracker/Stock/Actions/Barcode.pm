package XTracker::Stock::Actions::Barcode;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Perl6::Export::Attrs;

use XTracker::Database       qw( read_handle );
use XTracker::PrintFunctions qw( print_label );

sub handler {
    my $handler = XTracker::Handler->new( shift );
    my $department_id = $handler->department_id;
    my $referer = $handler->{referer};
    my $dbh = read_handle();

    print_label( $dbh, { department_id => ( $department_id ),
                         type          => ( $handler->{param_of}{'type'}             ),
                         id            => ( $handler->{param_of}{'id'}          || 0 ),
                         print_small   => ( $handler->{param_of}{'print_small'} || 0 ),
                         num_small     => ( $handler->{param_of}{'num_small'}   || 0 ),
                         print_large   => ( $handler->{param_of}{'print_large'} || 0 ),
                         num_large     => ( $handler->{param_of}{'num_large'}   || 0 ),
    } );

    return $handler->redirect_to( $referer );
}

1;
