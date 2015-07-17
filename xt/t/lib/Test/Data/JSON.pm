package Test::Data::JSON;
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :customer_category );
use XTracker::Config::Local         qw( config_var );

use English qw( -no_match_vars ) ;
use IO::File;
use JSON::Any;
use File::Find::Rule;
use File::Slurp;

=head1 METHODS

=head2 find_json_in_dir($class,$dir,$filter)

Go and find .json files in the directory and return the paths to them.

Defaults to any json files - C<*.json> - if $filter is undefined.

Returns a sorted (by name) arrayref of matching files.

    # slurp two test json order payload files
    my $files = Test::Data::JSON->find_json_in_dir(
        "$ENV{XTDC_BASE_DIR}/t/data/order/napgroup",
        'mrp-intl-00[12].json'
    );

=cut

sub find_json_in_dir {
    my($self,$dir_name,$filter) = @_;

    # default to finding /any/ .json files
    $filter //= '*.json';

    # if the filter doesn't look like a 'json' file, we're not really being
    # true to the intention of the sub
    if ($filter !~ m{json}i) {
        die qq{filter '$filter' doesn't seem to be restricting to JSON files};
    }

    my @files = sort
        File::Find::Rule->new
            ->file()
            ->name($filter)
            ->in( $dir_name );
    return \@files;
}

my $index = 1;

=head2 slurp_json_order_file($class,$file)

Slurp a file and give it a nice fresh order number (so that there's no conflict
in the database)

B<Assumes> that your slurped data has a top-level key called C<o_id>.

=cut
sub slurp_json_order_file {
    my ($self, $file, $args) = @_;

    my $slurp = $self->slurp_json_file($file);
    foreach my $order (@{$slurp->{orders}}) {
        $self->make_order_test_safe( $order, $args );
    }

    return $slurp;
}

sub make_order_test_safe {
    my ($self, $order, $args) = @_;

    $order->{o_id} = sprintf('%d%d%d', $PROCESS_ID, time(), $index++);

    if( $args->{alpha_order_nr} ) {
        $order->{o_id} = "JC".$order->{o_id};
    }
    foreach my $tender (@{$order->{tender_lines}}) {
        # JCHOO FORMAT
        if (     exists $tender->{card_detail}->{auth_code}
            and defined $tender->{card_detail}->{auth_code}
        ) {
            $tender->{card_detail}->{auth_code}
                = sprintf('%d%d%d',
                    $tender->{card_detail}->{auth_code},
                    time(),
                    $index++
                );
        }
        # NAPGROUP FORMAT
        if (     exists $tender->{payment_details}{pre_auth_code}
            and defined $tender->{payment_details}{pre_auth_code}
        ) {
            $tender->{payment_details}{pre_auth_code}
                = sprintf('%d%d%d',
                    $tender->{payment_details}{pre_auth_code},
                    time(),
                    $index++
                );
        }
    }

    # if it's a Staff Order then create the Customer record
    # and update its Category as Staff as the Staff Category
    # is no longer got from the Email address ending in a
    # NAP Group domain

    # work out if the Order is for Jimmy Choo or NAP Group
    # as there is a difference in Payload structure, JC
    # doesn't have a channel in the root node
    my $order_details;
    if ( exists( $order->{channel} ) ) {
        $order_details = {
            channel => $order->{channel},
            cust_id => $order->{cust_id},
            email   => $order->{billing_details}{contact_details}{email},
            name    => $order->{billing_details}{name},
        };
    }
    else {
        $order_details = {
            channel => 'JC-' . config_var( 'XTracker', 'instance' ),
            cust_id => $order->{orders}[0]{cust_id},
            email   => $order->{orders}[0]{billing_detail}{contact_detail}{email},
            name    => $order->{orders}[0]{billing_detail}{name},
        };
    }

    # use the email address to determine a Staff Order
    if ( ( $order_details->{email} // '' ) =~ /^staff\.customer\@/i ) {
        my $schema  = Test::XTracker::Data->get_schema();
        my $channel = $schema->resultset('Public::Channel')
                                ->find_by_web_name( uc( $order_details->{channel} ) );
        die "Couldn't find 'channel' rec for: " . $order_details->{channel}     if ( !$channel );

        # see if the Customer already exists
        my $customer = $schema->resultset('Public::Customer')->find( {
            is_customer_number => $order_details->{cust_id},
            channel_id         => $channel->id,
        } );

        if ( $customer ) {
            $customer->update( { category_id => $CUSTOMER_CATEGORY__STAFF } );
        }
        else {
            my $cust_name = $order_details->{name};
            $customer = Test::XTracker::Data->create_dbic_customer( {
                title       => $cust_name->{title},
                first_name  => $cust_name->{first_name},
                last_name   => $cust_name->{last_name},
                category_id => $CUSTOMER_CATEGORY__STAFF,
                email       => $order_details->{email},
                channel_id  => $channel->id,
            } );
            # as the above method always gets a new
            # Customer Number it needs to be corrected
            $customer->discard_changes->update( { is_customer_number => $order_details->{cust_id} } );
        }
    }

    return $order;
}

=head2 slurp_json_file($class,$file)

Given a filename for a file containing a JSON string return the perl object
representing that string

=cut
sub slurp_json_file {
    my $class = shift;
    my $file = shift
        or croak(q{no filename passed});

    my $j = JSON::Any->new;
    my $jsondata = read_file( $file )
        or die $file . ': failed to parse file: ' . $!;
    my $obj = $j->from_json($jsondata);

    return $obj;
}


sub __deprecated_by_chisel__slurp_file {
    my($self,$file) = @_;

    return if ($file->isa('Path::Class::Dir'));
    return if ($file->basename =~ /^\./);

    my $fh = IO::File->new;
    if ($fh->open("< ". $file->absolute)) {
        $fh->binmode(':utf8');
        my $out = undef;

        while (my $line = <$fh>) {
            $out .= $line;
        }
        return $out;
    }
    return;
}

1;
