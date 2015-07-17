package XTracker::Schema::ResultSet::Public::PutawayPrepGroup;

=head1 NAME

XTracker::Schema::ResultSet::Public::PutawayPrepGroup - A group of inventory being prepared for putaway

=head1 DESCRIPTION

Each group ID should only ever have one 'active' row at any one time,
'active' is the list of statuses defined by the get_active_groups() method.

This is enforced when a group is created
in XTracker::Database::PutawayPrep::get_or_create_putaway_prep_group
and when its status is changed
in XT::DC::Messaging::Consumer::Plugins::PRL::AdviceResponse

=head1 METHODS

=cut

use NAP::policy "tt";

use base 'DBIx::Class::ResultSet';

use Carp 'confess';
use MooseX::Params::Validate qw/pos_validated_list validated_list/;

use XTracker::Constants::FromDB qw(
    :putaway_prep_group_status
    :stock_process_status
);
use XTracker::Error qw/xt_warn/;
use XTracker::Logfile qw(xt_logger);
my $logger = xt_logger(__PACKAGE__);

=head2 find_active_group

Accept a hashref containing either:
    group_id => PGID or RGID (e.g. p123 / r456)
or:
    group_id => raw ID (e.g. 123 / 456)
    id_field_name => (e.g. group_id / recode_id)

Return a single group that is "active", see list of matching statuses in the code.

Do error checking to catch multiple groups with the same ID in progress
(shouldn't be possible).

=cut

sub find_active_group {
    my ($self, $group_id, $id_field_name) = validated_list(
        \@_,
        # group_id must be passed in with leading 'p' or 'r' included
        # so we know which column to search on: 'group_id' or 'recode_id' respectively
        group_id => { isa => 'Str' }, # p123 or r456
        id_field_name => { isa => 'Str', optional => 1 }, # group_id or recode_id
    );

    # If ID format is p123, determine ID field name
    # Otherwise, id_field_name must be passed in
    $id_field_name ||= $self->id_field_name($group_id);

    # Get raw ID
    $group_id =~ s/^[a-z]\-?//;

    # Find group
    my @results = $self->search({
        $id_field_name => $group_id,
        status_id => [
            $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,
            $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        ],
    });

    NAP::XT::Exception->throw( { error => "Action failed. More than one $id_field_name"
        ." with ID $group_id in an active state." }) if @results > 1;
    return $results[0];
}

=head2 id_field_name

Determine ID field name from ID format

=cut

sub id_field_name {
    my $self = shift;
    my ($group_id) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    # Which type of group was passed?
    my ($group_type) = $group_id =~ m/^([pr])/;
    confess "Expected group ID format p123 or r456, not '$group_id'" unless $group_type;

    # Which column should we search on?
    my $id_field_lookup = {
        'p' => 'group_id',
        'r' => 'recode_id',
    };
    my $id_field_name = $id_field_lookup->{$group_type}
        or confess "unknown ID type '$group_id'";

    return $id_field_name;
}

=head2 filter_active

Groups that are 'active', i.e. still waiting to be putaway.

=cut

sub filter_active {
    my ($self) = @_;

    return $self->search({
            'me.status_id' => [ -or =>
                {'=', $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS},
                {'=', $PUTAWAY_PREP_GROUP_STATUS__PROBLEM},
            ],
        });
}

=head2 filter_ready_for_putaway

Groups that have complete 'Bag & Tag' and are ready for Putaway

=cut

sub filter_ready_for_putaway {
    my ($self) = @_;

    return $self->search({
        'stock_processes.status_id' => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
    }, {
        join => 'stock_processes',
    });
}

=head2 filter_normal_stock

Active groups associated with a stock process, i.e. normal 'Goods In' stock

No prefetch required because we don't use any data from the joined tables

=cut

sub filter_normal_stock {
    my ($self) = @_;

    return $self->search({
        'me.group_id' => { '!=' => undef }, # it's a stock_process
        'link_delivery_item__stock_order_items.stock_order_item_id' => { '!=' => undef },
    }, {
        join => { 'stock_processes' => { 'delivery_item' => 'link_delivery_item__stock_order_items' } }
    });
}

=head2 filter_returns

Active groups representing stock being returned

=cut

sub filter_returns {
    my ($self) = @_;

    return $self->search({
        'me.group_id' => { '!=' => undef }, # it's a stock_process
        'link_delivery_item__return_item.return_item_id' => { '!=' => undef },
    }, {
        join => { 'stock_processes' => { 'delivery_item' => 'link_delivery_item__return_item' } }
    });
}

=head2 filter_active_recodes

Active groups representing stock being recoded

=cut

sub filter_recodes {
    my ($self) = @_;

    return $self->search({
        recode_id => { '!=', undef },
    });
}

1;
