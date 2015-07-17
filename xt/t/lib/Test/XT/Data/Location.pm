package Test::XT::Data::Location;

use NAP::policy "tt",     qw( test role );

requires 'dbh';
requires 'schema';

#
# Location data for the Test Framework
#
use Carp;
use XTracker::Config::Local ':DEFAULT','iws_location_name';
use Test::XTracker::Data;

use XTracker::Utilities qw(get_start_end_location);
use XTracker::Database::Attributes 'get_locations';
use XTracker::Database::Location qw(create_locations);

use XTracker::Constants::FromDB qw( :flow_status );
use NAP::DC::Location::Format;

has location => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_location',
    );

has all_location_types => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_all_location_types',
    );

############################
# Attribute default builders
############################

sub _set_all_location_types {
    my ($self) = @_;

    note "SUB _set_all_location_types";

    return [
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
        $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
        $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
        $FLOW_STATUS__CREATIVE__STOCK_STATUS,
        $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
        $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
        $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
    ];
}

sub _set_location {
    my ($self) = @_;

    note "SUB _set_location";
    my $schema  = $self->schema;

    my $loc_opts = {
        count       => 1,
        allowed_types => $self->all_location_types,
    };

    my $locs = $self->data__location__create_new_locations($loc_opts);

    note "searching for newly created location [".$locs->[0]."]";
    my ($location) = $schema->resultset('Public::Location')->search({
        location    => $locs->[0],
    });
    note "    location = [".$location->id."]";

    return $location;
}

sub data__delete_location_and_logs {
    my($self,$locs) = @_;

    note "SUB data__delete_location_and_logs";

    my $sth = $self->dbh->prepare(
        "DELETE FROM stock_count WHERE location_id = ?"
    );

    my $ctp_sth = $self->dbh->prepare(
        "DELETE FROM channel_transfer_putaway WHERE location_id = ?"
    );

    while (my $loc = $locs->next) {
        $loc->log_locations->delete;
        $loc->putaways->delete;
        $loc->putaways->delete;
        $loc->quantities->delete;
        $loc->rtv_quantities->delete;
        $loc->stock_count_variants->delete;
        $loc->location_allowed_statuses->delete;
        $sth->execute($loc->id);
        $loc->channel_transfer_picks->delete;
        $ctp_sth->execute($loc->id);
        $loc->delete;
    }
}

sub data__split_location {
    my($self,$loc) = @_;

    note "SUB data__split_location";

    my $dc = undef;
    my $floor = undef;
    my $zone = undef;
    my $location = undef;
    my $level = undef;

    if ($loc =~ /^(\d{2})(\d{1})(\w{1})-?(\d{3})(\w{1})$/) {
        $dc = $1;
        $floor = $2;
        $zone = $3;
        $location = $4;
        $level = $5;
    }
    return ($dc,$floor,$zone,$location,$level);
}


{
    my $dc_name     = Test::XTracker::Data::whatami;
    my ($dc)        = $dc_name =~ /^DC(\d+)$/;
    $dc             = '0'.$dc;
    my $floor       = 9;
    my $zone        = 'Z';
    my $location    = 999;
    my $level       = 'Z';

    # data__location__get_unused_location_names
    #   Get valid location names which are not yet used in the 'location' table
    #   Returns a reference to a list of location names.
    sub data__location__get_unused_location_names {
        my ($self, $quantity) = @_;

        note 'SUB data__location__get_unused_location_names';
        my @location_names;

        my %existing_location_names
            = map { $_->{location} => 1 } @{get_locations($self->schema)};
        while ($quantity > 0) {

            my $location_format = config_var('DistributionCentre', 'name');
            my $loc_name = NAP::DC::Location::Format::get_formatted_location_name($location_format, {
                floor       => $floor,
                zone        => $zone,
                location    => $location,
                level       => $level,
            });

            note "Got location [$loc_name] quantity=[$quantity]";
            $location--;
            if ($location == 0) {
                $location = 999;
                $level--;
                # If ever level gets below 'A' then we will have used 26000 locations!
            }
            next if $existing_location_names{$loc_name};
            push @location_names, $loc_name;
            $quantity--;
        }

        return \@location_names;
    }
}

# data__location__create_new_locations
#   Create new locations in the 'location' table using a method that does not
#   rely on there already being data in the database
#   Returns a reference to a list of location names.
#
sub data__location__create_new_locations {
    my ($self, $args) = @_;

    note 'SUB data__location__create_new_locations';

    my $quantity        = $args->{quantity} || 1;
    my $allowed_types   = $args->{allowed_types} || $self->all_location_types;

    my $location_names = $self->data__location__get_unused_location_names($quantity);

    $self->data__create_locations($location_names, $allowed_types);
    return $location_names;
}

# data__location__destroy_test_locations
#   Destroy all test locations, i.e. all those on floor 9
#
sub data__location__destroy_test_locations {
    my ($self) = @_;

    note "SUB data__location__destroy_test_locations (on floor 9)";
    my $dc = Test::XTracker::Data->whatami_as_location;
    my $locations = $self->schema->resultset('Public::Location')->search({
        location    => {like => "${dc}9%"},
    });

    $self->data__delete_location_and_logs($locations);
}

# data__create_locations
#   given a set of location names, create entries in the locations table
#   the 'types' gives an array of allowable location types
#
sub data__create_locations  {
    my($self,$locs,$types) = @_;

    note "SUB data__create_locations";

    $types = ref $types ? $types : [$types];
    foreach my $loc (ref $locs ? @$locs : $locs) {
        my($dc,$floor,$zone,$location,$level) = $self->data__split_location($loc);
        my($start,$end) = get_start_end_location({
            start_floor     => $floor,
            start_zone      => $zone,
            start_location  => $location,
            start_level     => $level,

            end_floor       => $floor,
            end_zone        => $zone,
            end_location    => $location,
            end_level       => $level,
        });

        note "data__create_locations: start [$start] end [$end] types [".join('-', @$types)."]";
        my $changes = create_locations($self->dbh,$start,$end,$types);
    }
}

sub data__location__get_invar_location {
    my $self = shift;

    return $self->data__location__get_named_location( iws_location_name() );
}

sub data__location__get_named_location {
    my ($self, $name) = @_;

    my $loc_rs = $self->schema->resultset('Public::Location');
    my $loc_s_rs = $self->schema->resultset('Public::LocationAllowedStatus');

    # create it if it doesn't exist yet
    my $location = $loc_rs->find_or_create({
        location => $name
    });
    for my $s (
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
        $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
        $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        # XXX are these correct?
    ) {
        $loc_s_rs->find_or_create({
            location_id => $location->id,
            status_id=>$s,
        });
    }

    return $location;
}

# This should probably be in a Test::XT::Data::Quantity module
#
sub data__insert_quantity {
    my($self,$loc) = @_;

    note "SUB data__insert_quantity";

    my $variant = $self->stock_order->stock_order_items->first->variant;
    my $location = $self->schema->resultset('Public::Location')->search({
        'location' => $loc,
    })->first;
die "Can't find location $loc" unless $location;
    my $quantity = $self->schema->resultset('Public::Quantity')->create({
        quantity    => 5,
        location_id => $location->id,
        variant_id  => $variant->id,
        channel_id  => $variant->current_channel->id,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });

    note "inserted quantity [".$quantity->id."] for variant [".$variant->id."]";

    return $self;
}

# Set quantity.quantity to 0 for our variant
# We need this to test final pick
sub data__location__set_zero_quantity {
    my($self) = @_;
    note 'SUB data__location__set_zero_quantity';

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;

    # This will probably die if there's no matching quantity, but that's
    # ok because it means something is already wrong.
    my $quantity = $self->schema->resultset('Public::Quantity')->search({
        'variant_id' => $variant_id,
    })->update({
        'quantity'  => 0,
    });
    note "set quantity.quantity to 0 for variant_id $variant_id";

    return $self;
}



# Set quantity.quantity to non-zero for our variant where it's 0
# To restore things back to a sensible state
sub data__location__set_non_zero_quantity {
    my($self) = @_;
    note 'SUB data__location__set_non_zero_quantity';

    my $variant_id = $self->stock_order->stock_order_items->first->variant_id;

    my $quantity = $self->schema->resultset('Public::Quantity')->search({
        'variant_id' => $variant_id,
        'quantity'   => 0,
    })->first;

    if ($quantity) {
        $quantity->update({
            'quantity'  => 23,
        });
    }

    return $self;
}

=head2 data__location__initialise_non_iws_test_locations

Build some default locations on each floor (currently 21..24) in non-IWS
instances of XTracker for tests if there aren't any. Returns the output of
L<XTracker::Database::Location::create_locations>.

=head3 NOTE

This method was originally written for DC2.5, and apparently we still fucking
use it for DC2 (at least for RTV stock, 0-based and on floor 4... in most
cases), so while we probably shouldn't need it, we still do. Oh and we also
need it for DC3 - not because the logic is correct, but because it creates a
bunch of locations.

=cut

sub data__location__initialise_non_iws_test_locations {
    my ( $self ) = @_;
    if ( XTracker::Config::Local::config_var(qw/IWS rollout_phase/) ) {
        Carp::carp( 'This method should only be run on non-IWS instances of XT' );
        return;
    }

    my @locations = (
        {
            floor => 1,
            allowed_statuses => [ $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ],
        },
        {
            floor => 2,
            allowed_statuses => [ $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ],
        },
        {
            floor => 3,
            allowed_statuses => [
                $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                $FLOW_STATUS__SAMPLE__STOCK_STATUS,
            ],
        },
        {
            floor => 4,
            allowed_statuses => [
                $FLOW_STATUS__CREATIVE__STOCK_STATUS,
                $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
                $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
                $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
                $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
                $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
                $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
                $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            ],
        },
    );
    my %created_locations;
    for ( @locations ) {
        next if $self->schema
                     ->resultset('Public::Location')
                     ->get_locations({ floor => $_->{floor} })
                     ->count;
        my $changes = $self->data__location__create_test_locations({
            floor => $_->{floor},
            allowed_statuses => $_->{allowed_statuses},
        });
        @created_locations{keys %$changes} = values %$changes;
    }
    return \%created_locations;
}

=head2 data__location__create_test_locations(\%args)

This method is a thin wrapper around
L<XTracker::Database::Location::create_locations> with some extra parameter
validation. It will create locations for the given floor/unit in the given
range or will default to creating locations from C<${floor}A-0001A> to
C<${floor}A-0099H>.

It accepts a hashref with values for C<floor>, and optionally C<unit>,
C<from>, C<to>, C<allowed_statuses>.

=head3 NOTE

These locations are created in the DC2 format as opposed to the obsolete DC1
format.

=cut

sub data__location__create_test_locations {
    my ( $self, $args ) = @_;
    my ( $floor, $unit, $from, $to, $allowed_statuses )
        = @{$args}{qw<floor unit from to allowed_statuses>};

    croak "Invalid floor $floor - must be a digit"
        unless $floor =~ m{^\d+$};

    $unit //= 'A';
    croak "Invalid unit $unit - must be an upper case character" unless $unit =~ m{^[A-Z]$};

    $from //= '0001A';
    $to //= '0099H';
    for ( $from, $to ) {
        croak "Invalid location ($_)" unless m{^\d{4}[A-H]$};
    }

    my $dc_loc = Test::XTracker::Data->whatami_as_location;

    return XTracker::Database::Location::create_locations(
        $self->schema,
        (map { sprintf( '%s%s%s-%s', $dc_loc, $floor, $unit, $_) } ( $from, $to )),
        $allowed_statuses,
    );
}

=head2 locations_by_allowed_status( $flow_status_id )

Return a resultset of locations by their allowed status

=cut

sub locations_by_allowed_status {
    my ( $self, $status_id ) = @_;
    return $self->schema->resultset('Public::Location')->search(
        { 'location_allowed_statuses.status_id' => $status_id },
        { join => 'location_allowed_statuses', },
    );
}

1;
