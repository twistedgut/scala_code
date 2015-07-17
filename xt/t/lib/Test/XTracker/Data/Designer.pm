package Test::XTracker::Data::Designer;
use NAP::policy "tt", 'class';

use Test::XTracker::Data;

=head1 NAME

=head1 DESCRIPTION

=cut

use XTracker::Constants::FromDB     qw( :designer_website_state );


=head1 METHODS

=head2 grab_designer

    my $designer = Test::XTracker::Data::Designer->grab_designer;

Returns a data structure containing one designer. See L</grab_designers>
for the specification.

=cut

sub grab_designer {
    return shift->grab_designers;
}

=head2 grab_designers

    my $designers
        = Test::XTracker::Data::Designer->grab_designers( {
            how_many => ?,
            # optional
            channel => $channel_obj,    # will populate 'designer_channel' table
            want_dbic_recs => 1,        # will return a list of DBIC Records instead of a list of Hash Refs.
            force_create => 1,          # will force the Creation of all the Designers requested
        } );

Retuns a list of hash-refs containing:

    {
        designer_id => '12345',
        designer => XTracker::Schema::Result::Public::Designer,
    }

=cut

{

my $schema = Test::XTracker::Data->get_schema;

sub grab_designers {
    my ( $class, $args ) = @_;

    my $limit = delete $args->{how_many} // 1;

    $class->_find_or_create_designers( {
        %{ $args },
        limit => $limit,
    } );
}

sub _find_or_create_designers {
    my ( $class, $args ) = @_;

    my $limit   = $args->{limit};
    my $channel = $args->{channel};

    my @designers;
    unless ( $args->{force_create} ) {
        # Try and find the specified number of Designers
        my $rs = $schema->resultset('Public::Designer')->search(
            {},
            {
                order_by => { -desc => 'id' },
                rows => $limit,
            }
        );

        while ( my $designer = $rs->next ) {
            push @designers, {
                designer_id => $designer->id,
                designer => $designer,
            };
            $limit--;
        }
    }

    # Create designers if we couldn't find enough
    @designers = $class->_create_designers({
        limit => $limit,
        designers => \@designers
    });

    # get DBIC records for the Designers
    my $designer_rs     = $schema->resultset('Public::Designer');
    my @designer_recs   = map {
        $designer_rs->find( $_->{designer_id} )
    } @designers;

    # if a Sales Channel has been passed, then populate the
    # 'designer_channel' table to assign a Channel to the Designers
    if ( $channel ) {
        foreach my $designer ( @designer_recs ) {
            my $designer_channel = $designer->designer_channels->search(
                { channel_id => $channel->id }
            )->first;
            if ( !$designer_channel ) {
                $designer_channel = $designer->create_related( 'designer_channels', {
                    channel_id      => $channel->id,
                    website_state_id=> $DESIGNER_WEBSITE_STATE__VISIBLE,
                } );
            }
        }
    }

    return ( $args->{want_dbic_recs} ? @designer_recs : @designers );
}

sub _create_designers {
    my ( $class, $args ) = @_;

    my @designers = @{$args->{designers}};
    my $limit = $args->{limit};

    # We found all the designers required
    return @designers unless $limit > 0;

    # bump the sequence on the Designer table
    # because it can get behind the records
    # and lead to duplicate key issues
    Test::XTracker::Data->bump_sequence('designer');

    my $rs      = $schema->resultset('Public::Designer');
    my $counter = ( $rs->count // 0 ) + 1;

    for (0..$limit) {
        my $designer = $rs->create({
            designer => "Cruella de Vil ${counter}",
            url_key => "dalmationcreations${counter}",
        });

        push @designers, {
            designer_id => $designer->id,
            designer => $designer,
        };

        $counter++;
    }

    return @designers;
}

=head2 grab_products_for_designer

    ( $channel, $products_arr_ref ) = __PACKAGE__->grab_products_for_designer( $designer_rec, {
        # same options as you would pass for:
        #       Test::XTracker::Data->grab_products()
    } );

Given a Designer Record WILL ALWAYS CREATE new products and then set them to be
for that Designer. It Returns the Channel and an Array Ref. of Product Details in
the same structure as 'Test::XTracker::Data->grab_products' does.

=cut

sub grab_products_for_designer {
    my ( $self, $designer, $args ) = @_;

    my ( $channel, $products ) = Test::XTracker::Data->grab_products( $args );

    foreach my $pid ( @{ $products } ) {
        $pid->{product}->discard_changes->update( {
            designer_id => $designer->id,
        } );
    }

    return ( $channel, $products );
}

=head2 create_orders_with_products_for_the_same_designer

    @orders_array     = __PACKAGE__->create_orders_with_products_for_the_same_designer( $how_many_orders, { ... } );
                or
    $orders_array_ref = __PACKAGE__->create_orders_with_products_for_the_same_designer( $how_many_orders, {
        # all are optional
        channel       => $channel_rec,      # if not specified then a Channel will be chosen for all Orders
        designer      => $designer_rec,     # if not specified then a Random Designer will be chosen
        customer      => $customer_rec,     # the Customer record to use for all Orders, if not
                                            # specified then a new Customer will be used for each Order

        create_customer_args => $hash_ref,  # arguments passed straight through to creating a
                                            # Customer if 'customer' hasn't been specified
        create_order_args    => $hash_ref,  # arguments passed straight through to creating each Order
    } );

Will create X many Orders all of which will contain an Item for the same Designer.

The 'create_customer_args' argument will be passed straight through to the 'Test::XTracker::Data->create_dbic_customer'
method.

The 'create_order_args' argument will be passed straight through to the 'Test::XT::Data::Order->new_order' method.

=cut

sub create_orders_with_products_for_the_same_designer {
    my ( $self, $how_many, $args ) = @_;

    my $customer_for_all_orders = $args->{customer};

    my $designer = $args->{designer};
    my $channel  = $args->{channel};

    unless ( $designer ) {
        $designer = $schema->resultset('Public::Designer')
                            ->search( { id => { '!=' => 0 } } )
                                ->first;
    }
    unless ( $channel ) {
        if ( $customer_for_all_orders ) {
            $channel = $customer_for_all_orders->channel;
        }
        else {
            $channel = Test::XTracker::Data->any_channel();
        }
    }

    # grab some Products and then set them to be for the same Designer
    my ( undef, $products ) = Test::XTracker::Data->grab_products( {
        how_many     => 3,
        force_create => 1,
        channel      => $channel,
    } );
    foreach my $pid ( @{ $products } ) {
        $pid->{product}->discard_changes->update( {
            designer_id => $designer->id,
        } );
    }

    #
    # create the Orders
    #
    my $data = Test::XT::Data->new_with_traits( {
        traits => [
            'Test::XT::Data::Order',
        ],
    } );
    my %create_order_args = %{ $args->{create_order_args} // {} };

    my @orders;
    foreach ( 1..$how_many ) {
        my $customer = $customer_for_all_orders;
        unless ( $customer ) {
            $customer = Test::XTracker::Data->create_dbic_customer( {
                channel_id => $channel->id,
                %{ $args->{create_customer_args} // {} },
            } );
        }

        my $order_details = $data->new_order(
            channel  => $channel,
            customer => $customer,
            products => $products,
            %create_order_args,
        );

        push @orders, $order_details->{order_object}->discard_changes;
    }

    return ( wantarray ? @orders : \@orders );
}

}
