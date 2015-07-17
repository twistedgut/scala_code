package XT::Data::Fulfilment::GOH::Integration;

use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";

use Moose::Util::TypeConstraints;
use List::Util qw/first/;
use MooseX::Params::Validate qw( validated_list );

use NAP::DC::Barcode::Container::Tote::WithOrientation;
use XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer;
use XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku;
use XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer;
use XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty;
use XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete;
use XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch;
use XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode;
use XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane;
use XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer;

use XTracker::Constants::FromDB qw/
    :prl_delivery_destination
    :prl
/;
use XTracker::Constants::Regex ':sku';
use vars qw/
    $PRL__GOH
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

=head1 NAME

XT::Data::Fulfilment::GOH::Integration

=head1 DESCRIPTION

Encapsulate logic for GOH Integration process.

=head1 ATTRIBUTES

=head2 prl_delivery_destination_row

Mandatory parameter that indicate on which lane current process is
attached.

=cut

has prl_delivery_destination_row => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::PrlDeliveryDestination',
    required => 1,
    handles => {
        type                    => 'message_name',
        delivery_destination_id => 'id',
    },
);

=head2 rail_allocation_item_rows : \@allocation_item_rows

Data about content of rail that leads to integration point.

=cut

has rail_allocation_item_rows => (
    is   => 'ro',
    isa  => 'ArrayRef[XTracker::Schema::Result::Public::AllocationItem]',
    lazy_build => 1,
);

sub _build_rail_allocation_item_rows {
    my $self = shift;

    return [
        $self->prl_delivery_destination_row
            ->allocation_items_at_destination
            ->search(
                undef,
                {
                    prefetch => {
                        shipment_item => [
                            {
                                shipment => {
                                    allocations => 'prl'
                                },
                            },
                            {
                                variant => {
                                    product => 'product_attribute',
                                }
                            }
                        ]
                    },
                }
            )
    ];
}

=head2 get_allocation_item_by_sku($sku) : $allocation_item_row

For provided SKU return first Allocation item from rail.

=cut

sub get_allocation_item_by_sku {
    my ($self, $sku) = @_;

    my $allocation_item =
        first
            {$sku eq $_->shipment_item->get_sku}
            @{$self->rail_allocation_item_rows};

    return $allocation_item if ($allocation_item);

    # If we couldn't find any that were on the rail, look for a matching
    # one that could be on the problem rail.
    $allocation_item =
        first
            {$sku eq $_->shipment_item->get_sku}
            $self->get_non_delivered_items;

    return $allocation_item;
}

has dcd_integration_container_rs => (
    is         => 'ro',
    isa        => 'XTracker::Schema::ResultSet::Public::IntegrationContainer',
    lazy_build => 1,
);

sub _build_dcd_integration_container_rs {
    my $self = shift;

    # there is not point to have DCD containers for non-integration lane
    return $self->schema->resultset('Public::IntegrationContainer')
        ->search({ 1 => 0 })
            unless $self->is_integration_lane;

    return
        $self->schema->resultset('Public::IntegrationContainer')
            ->filter_goh
            ->filter_from_dcd
            ->filter_active
            ->search( undef, { order_by => { -asc => 'routed_at' }})
    ;
}

=head2 integration_container_row

Integration container record which holds garments that were scanned from rail.

Use "_set_integration_container_row" method to assign new value to this attribute.

Note: the attribute can hold the DBIC object that is not saved in database,
that is needed for example when we instantiated process object just when
empty container was scanned for first time, integration_container_row
record for that container is going to be added into database only after
fist item is scanned into it.

=cut

has integration_container_row => (
    is      => 'rw',
    isa     => 'Maybe[XTracker::Schema::Result::Public::IntegrationContainer]',
    writer  => '_set_integration_container_row',
    handles => {
        container_id => 'container_id',
    },
);

=head2 sku

SKU that was pulled from the rail and about to be placed into container.

=cut

has sku => (
    is  => 'rw',
    isa => 'Str',
);

=head1 METHODS

=head2 user_message : Str

User message that we need to show to end user as a prompt on the screen.

=cut

has user_message_scan_container => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;

        my $scan_empty_msg = 'Please scan an empty tote';

        # for direct lane we use empty tote for all cases
        return $scan_empty_msg if $self->is_direct_lane;

        # there is no container in Dematic queue to be scanned
        return $scan_empty_msg unless $self->next_container_id_to_scan;

        return sprintf 'Please scan %s from Dematic queue',
            $self->next_container_id_to_scan;
    },
);

=head2 next_container_id_to_scan : $container_id |

Determine if at current stage user needs to have specific container
to scan and return its ID.

If new empty Tote is needed - returns nothing.

=cut

has next_container_id_to_scan => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub {
        my $self = shift;

        unless (@{$self->rail_allocation_item_rows}) {
            # When there is nothing on incomming rail,
            # have a look on the containers from DCD
            my $container_to_scan = $self->dcd_integration_container_rs->first;
            return unless $container_to_scan;
            return $container_to_scan->container_id;
        }

        # Get a list of Dematic allocations that relate to first garment
        # on the rail and that are expected to be integrated with it
        my @dcd_sibling_allocations = $self
            ->rail_allocation_item_rows->[0]
            ->shipment_item
            ->shipment
            ->allocations
            ->filter_in_prl('Dematic');

        # first garment on incoming rail does need to be integrated
        return unless @dcd_sibling_allocations;

        my $next_container = $self->dcd_integration_container_rs
            ->search({
                'allocation_item.allocation_id' =>
                    [map { $_->id } @dcd_sibling_allocations],
            },{
                join => {integration_container_items => 'allocation_item'}
            })
            ->first;

        return undef unless $next_container;

        return $next_container->container_id;
    },
);

has user_message_scan_sku => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_user_message_scan_sku {
    my $self = shift;

    my $message;


    # Nothing from the rail is expected to be scanned
    # and current container is not empty
    my $ask_to_close_container =
        !$self->next_sku_to_scan &&
        $self->integration_container_row
             ->integration_container_items
             ->count;

    if ($ask_to_close_container) {
       $message = sprintf
            'Please mark container %s as complete',
            $self->container_id;
    } elsif ( $self->prompt_to_check_problem_rail ) {

        $message = sprintf
            'Please check if %s SKU is on Problem rail',
            $self->next_sku_to_scan;

    } else {
        # system expects user to scan certain SKU from the rail
        $message = sprintf(
            'Please scan %s SKU from the %s rail',
            $self->next_sku_to_scan,
            $self->prl_delivery_destination_row->name
        );
    }

    # In case when current container was resumed occasionally or
    # by intentionally at previous step - make user aware of it
    $message = sprintf(
        "You just resumed container %s.<br/> %s",
        $self->container_id,
        $message
    ) if $self->is_container_resumed;

    return $message;
}

=head2 next_sku_to_scan : $sku_string | ''

String with a SKU that is expected to be scanned next.

Empty string if nothing is expected.

=cut

has next_sku_to_scan => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_next_sku_to_scan {
    my $self = shift;

    my $next_item = $self->rail_allocation_item_rows->[0];

    return '' unless $next_item;

    # out current container
    my $container = $self->integration_container_row;

    # Current container has nothing: use first SKU from the rail
    return $next_item->shipment_item->get_sku
        unless $container;

    # number of items in current container
    my $container_item_count = $container
        ->integration_container_items->count;

    return $next_item->shipment_item->get_sku
        unless $container_item_count;


    my $next_item_mix_group = $next_item
        ->allocation
        ->integration_mix_group;

    # For case when current container has stock check that
    # there is stock for container mix group on the rail
    # and if it exists - prompt user to scan it into
    return $next_item->shipment_item->get_sku
        if  $container->mix_group eq $next_item_mix_group;

    # As a last resort - check if we need to check Problem rail
    # for known missing items (those that we are aware that are
    # missing): if it is good day and they appeared to be there
    if ($self->sku_to_check_on_problem_rail) {
        $self->prompt_to_check_problem_rail(1);
        return $self->sku_to_check_on_problem_rail;
    }

    return '';
}

=head2 prompt_to_check_problem_rail

Flag that indicate whether to ask user to check C<sku_to_check_on_problem_rail>
on Problem rail.

=cut

has prompt_to_check_problem_rail => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

=head2 sku_to_check_on_problem_rail() : Str

=cut

has sku_to_check_on_problem_rail => (
    isa        => 'Str',
    is         => 'ro',
    lazy_build => 1,
);

sub _build_sku_to_check_on_problem_rail {
    my $self = shift;

    # For current container
    # check if for item that was added very last time there is a peer item
    # that was not delivered but it is worth to check
    # Problem rail for it
    my $last_allocation_item = $self
        ->integration_container_row
        ->allocation_items
        ->first;

    unless ( $last_allocation_item ) {
        # In case when current container is empty,
        # check if there are allocations that are in Delivered
        # status but for some reasons their entire items were
        # not delivered (according to XT).

        my $non_delivered_item = $self->get_non_delivered_items->first;

        return $non_delivered_item->shipment_item->get_sku
            if $non_delivered_item;

        return '';
    }

    my $allocation_item_to_check = $last_allocation_item
        ->allocation
        ->allocation_items
        ->filter_expected_on_problem_rail
        ->first;

    return $allocation_item_to_check->shipment_item->get_sku
        if $allocation_item_to_check;

    return '';
}

=head2 get_non_delivered_items : $allocation_items_rs

Get a resultset with allocation items that are expected to be at
integration at some point but were not delivered correctly.

=cut

sub get_non_delivered_items {
    my $self = shift;

    return $self->schema
        ->resultset('Public::AllocationItem')
        ->filter_expected_on_problem_rail;
}

=head2 is_container_resumed : Bool

Flag that show if current container was resumed at the previous step

=cut

has is_container_resumed => (
    isa     => 'Bool',
    is      => 'rw',
    default => 0
);

sub user_message {
    my $self = shift;

    my $user_message;

    if ($self->next_scan eq $self->next_scan_container) {
        $user_message = $self->user_message_scan_container;
    } elsif ($self->next_scan eq $self->next_scan_sku) {
        $user_message = $self->user_message_scan_sku;
    }

    return $user_message;
}

=head2 next_scan : ('sku'|'container')

String with entity name that should be scanned next. Could be
either 'sku' or 'container'.

=cut

sub next_scan {
    my $self = shift;

    my $next_scan = $self->next_scan_container;

    $next_scan = $self->next_scan_sku if $self->integration_container_row;

    return $next_scan;
}

=head2 next_scan_container : 'container'

Name of next scanning action in case of container. That is if
it is container that should be scanned next, "next_action"
should have the same value as current attribute.

=cut

has next_scan_container => (
    is      => 'ro',
    isa     => 'Str',
    default => 'container',
);

=head2 next_scan_sku : 'sku'

Name of next scanning action in case of SKU.

=cut

has next_scan_sku => (
    is      => 'ro',
    isa     => 'Str',
    default => 'sku',
);

=head2 next_scan_action : Str

Name of the next scanning action (default) to be run after current one.
E.g. if we just scanned container, next default action is 'scan SKU'.
Though it is not mandatory.

=cut

sub next_scan_action {
    my $self = shift;

    return 'scan_' . $self->next_scan;
}

=head2 next_missing_action : Str

Name of action to run if user press Missing button.

=cut

sub next_missing_action {
    my $self = shift;

    return 'missing_' . $self->next_scan;
}

=head2 next_action_args : \@captured_args, \%query_values

Arguments to be supplied with next action. This method is used in
conjunction with 'next_*_action' while building URL for next action.

Return consists of two items:

    * array ref of captured parameters - those that are parts of URL
    * hash ref query parameters - ones to go as query parameters

For more details please see https://metacpan.org/pod/Catalyst#c-uri_for-path-args-query_values

=cut

sub next_action_args {
    my $self = shift;

    my %action_to_captures = (
        container => [qw/delivery_destination_id/],
        sku       => [qw/delivery_destination_id container_id/],
    );

    my %action_to_query_values = (
        sku       => { $self->is_container_resumed ? (is_container_resumed => 1) : ()  },
        container => {},
    );

    return (
        [map {$self->$_} @{ $action_to_captures{$self->next_scan}}],
        $action_to_query_values{ $self->next_scan }
    );
}

=head2 next_action_captures : \@captured_args

Convenient method to return captured arguments for next action.

=cut

sub next_action_captures {
    my $self = shift;

    return ($self->next_action_args)[0];
}

=head2 next_action_query_values : \%query_values

Convenient method to return query arguments for next action.

=cut

sub next_action_query_values {
    my $self = shift;

    return ($self->next_action_args)[1];
}

=head2 set_container( $container_id ) : ()

Validate provided container ID and set integration_container_row attribute.

=cut

sub set_container {
    my ($self, $container_id, $at_scanning) = @_;

    # check that provided ID is Container barcode
    $container_id = NAP::DC::Barcode::Container::Tote::WithOrientation->new_from_id(
        $container_id
    );

    # In case there is a specific container that is needed to process
    # now check that provided ID is that one's
    if (
        $at_scanning &&
        $self->next_container_id_to_scan &&
        $self->next_container_id_to_scan ne $container_id
    ) {
        XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer->throw({
            container_id          => $container_id,
            required_container_id => $self->next_container_id_to_scan,
        });
    }

    my $integration_container_rs = $self->schema
        ->resultset('Public::IntegrationContainer');

    # try to find active container
    my $container = $integration_container_rs
        ->get_active_container_row( $container_id );

    if ($container) {

        # prevent users to use DCD container at Direct lane
        XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane->throw({
            container_id => $container_id,
        }) if $at_scanning && $self->is_direct_lane && $container->from_prl_id;

        return $self->_set_integration_container_row($container);

    } else {
        # When no active integration container exists,
        # check whether provided container ID is one for
        # just finished container, but not placed onto conveyor
        $container = $integration_container_rs
            ->get_last_routed_but_not_arrived_container_row_for(
                $container_id
            );


        XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer->throw({
            container_id => $container_id,
        }) if $container;
    }

    # if there is not an active container for the provided ID create
    # integration_container_row row object but do not add it into
    # database
    return $self->_set_integration_container_row(
        $integration_container_rs->new_result({
            container_id => $container_id,
            prl_id       => $PRL__GOH,
        })
    );
}

=head2 set_sku( $sku ) : ()

Validate and set SKU.

=cut

sub set_sku {
    my ($self, $sku) = @_;

    XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode
        ->throw({
            sku => $sku,
        })
            if $sku !~ $SKU_REGEX;

    my $allocation_item = $self->get_allocation_item_by_sku($sku);

    # Validate SKU: make sure it comes form current lane
    # as a special case it could come from Problem rail
    # (but it should be expected)
    XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku
        ->throw({
            prl_delivery_destination_row => $self->prl_delivery_destination_row,
            sku                          => $sku,
        })
            if !$allocation_item;

    # Check if SKU has the same mix group as stock in container
    my $mix_group_mismatch =
        $self->integration_container_row->integration_container_items->count
            &&
        ($self->integration_container_row->mix_group
            ne
        $allocation_item->allocation->integration_mix_group);

    XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch
        ->throw({
            container_id => $self->container_id,
            sku          => $sku,
        })
            if $mix_group_mismatch;

    $self->sku($sku);
}

=head2 commit_scan

Save changes done as a result of current scan. It matters only for
scanning skus as sku's movements from rail to contained are tracked
in database.

=cut

sub commit_scan {
    my $self = shift;

    unless ($self->sku) {

        # If there is not SKU on current process instance it means
        # it was container scan

        # In case when scanned container appeared to be non-empty
        # set corresponding flag, so it is possible to convey this
        # to next step
        $self->is_container_resumed(1)
            if $self->integration_container_row
                    ->integration_container_items
                    ->count;

        return;
    }

    my $allocation_item = $self->get_allocation_item_by_sku($self->sku);
    $allocation_item->add_to_integration_container({
        integration_container => $self->integration_container_row,
    });
}

=head2 show_missing_button() : bool

Indicated whether 'Missing' button is shown.

=cut

sub show_missing_button {
    my $self = shift;

    if (
        $self->is_direct_lane &&
        $self->integration_container_row &&
        $self->next_sku_to_scan
    ) {
        # For Direct lane show "Missing" button only when
        # there is expected SKU
        return !! $self->next_sku_to_scan;

    } elsif ( $self->is_integration_lane ) {
        # For Integration lane show "Missing" button in case when
        #   - it is about to scan container and there is
        #     particular one expected to be scanned
        #   - it is about to scan expected SKU
        return
            !!($self->integration_container_row && $self->next_sku_to_scan)
                ||
            !! $self->next_container_id_to_scan;
    }

    return !! 0;
}

=head2 mark_container_full( :operator_id? )

Mark current container as full.

=cut

sub mark_container_full {
    my $self = shift;
    my ($operator_id) = validated_list(\@_,
        operator_id => {
            isa      => 'Int',
            optional => 1,
            default  => $self->schema->operator_id,
        },
    );

    my $integration_container_row = $self->integration_container_row;

    # assert that current process object has SKU and Container ID
    XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer->throw
         unless $integration_container_row;

    XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty->throw({
        container_id => $integration_container_row->container_id,
    }) unless $integration_container_row->in_storage;

    # check the integration container isn't already complete
    #   if it is, give them an appropriate message about putting it on the conveyor anyway
    XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete->throw({
        container_id => $integration_container_row->container_id,
    }) if $integration_container_row->is_complete;

    $integration_container_row->mark_as_complete({
        operator_id => $operator_id,
    });
}

=head2 transform_missing_container_into_empty( $missing_container_id, $empty_container_id) :

Move content from container into empty one and mark former as
completed.

=cut

sub transform_missing_container_into_empty {
    my ($self, $missing_container_id, $empty_container_id) = validated_list(\@_,
        missing_container_id => {
            isa => 'NAP::DC::Barcode::Container::Tote::WithOrientation',
        },
        empty_container_id => {
            isa => 'NAP::DC::Barcode::Container::Tote::WithOrientation',
        },
    );

    my $integration_container_rs = $self->schema->resultset('Public::IntegrationContainer');

    # try to find active container
    my $missing_container_row = $integration_container_rs
        ->get_active_container_row( $missing_container_id );

    # try to get existing active integration container record
    # first: in case user scanned non-empty one
    my $empty_container_row = $integration_container_rs
        ->get_active_container_row(
            $empty_container_id
        )
            ||
        # and create new record is there is no active records
        $integration_container_rs->new_result({
            container_id => $empty_container_id,
            prl_id       => $PRL__GOH,
        });

    $empty_container_row->move_items_from_missing_container({
        source_container_row => $missing_container_row,
    });
}

=head2 mark_missing_sku

Indicated that current SKU is not on the rail.

=cut

sub mark_missing_sku {
    my ($self, $sku) = @_;

    my $allocation_item = $self->get_allocation_item_by_sku($self->sku);
    $allocation_item->add_to_integration_container({
        integration_container => $self->integration_container_row,
        is_missing            => 1,
    });
}

sub is_integration_lane {
    my $self = shift;

    return $self->prl_delivery_destination_row->id == $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION;
}

sub is_direct_lane {
    my $self = shift;

    return $self->prl_delivery_destination_row->id == $PRL_DELIVERY_DESTINATION__GOH_DIRECT;
}

=head2 remove_sku_from_container( $sku ) : bool

Remove provided SKU from current integration container.
Returns true in case of success, and false otherwise.

If the provided SKU is not valid SKU barcode or there is no
current integration container, throw an corresponding exception.

=cut

sub remove_sku_from_container {
    my ($self, $sku) = @_;

    XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode
        ->throw({
            sku => $sku,
        })
            if $sku !~ $SKU_REGEX;

    my $integration_container_row = $self->integration_container_row;

    # assert that current process object has valid Container ID
    XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer->throw
         unless $integration_container_row;

    XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty->throw({
        container_id => $integration_container_row->container_id,
    }) unless $integration_container_row->in_storage;

    return $integration_container_row->remove_sku($sku);
}
