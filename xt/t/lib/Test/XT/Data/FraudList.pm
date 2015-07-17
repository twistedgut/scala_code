package Test::XT::Data::FraudList;

use NAP::policy qw( test role );

requires qw(
    schema
);

=head1 NAME

Test::XT::Data::FraudList

=head1 SYNOPSIS

Used for creating Lists relating to Fraud Rules.

=head2 USAGE

    use Test::XT::Flow;
            or
    use Test::XT::Data;

    my $framework = Test::XT::(Data|Flow)->new_with_traits(
        traits => [
            'Test::XT::Data::FraudChangeLog', # <-- Only required for live lists
            'Test::XT::Data::FraudList',
        ],
    );

=cut

use Test::XTracker::Data;
use Moose::Util::TypeConstraints;

=head2 ATTRIBUTES

The following can be overridden with your own choosing before the Fraud Rule is created.

    # the following will determin how many Conditions are Created, defaults to 5

    $framework->number_of_conditions( 3 );

        or

    # this would create a Rule with 4 conditions
    $framework->conditions_to_use( [
        {
            # use DBIC Objects to specify what Methods & Operators the Conditions should use
            method   => $method_obj,
            operator => $conditional_operator_obj,
            value    => 'value to compare',
        },
        {
            # or just specify the Description of the Methods & Conditions to use
            method   => 'Description of Method in fraud.method table',
            operator => '=',
            value    => 'value to compare',
        },
        {
            # or a combination
            method   => $method_obj,
            operator => '=',
            value    => 'value to compare',
        },
        {
            # if you don't specify a 'value' a random one will be assigned
            method   => 'Description of Method in fraud.method table',
            operator => '=',
        },
    ] );

Any Other Attribute can be set to your own data as well.

=head2 fraud_list

This can't be overridden and is what is used to create the List

=cut

has fraud_list => (
    is          => 'ro',
    isa         => union( [
        class_type( 'XTracker::Schema::Result::Fraud::LiveList' ),
        class_type( 'XTracker::Schema::Result::Fraud::StagingList' ),
    ] ),
    lazy        => 1,
    builder     => '_build_fraud_list',
);

=head2 fraud_list_location

The location of the List can be either 'live' or 'staging', defaults to 'staging'.

=cut

has fraud_list_ruleset => (
    is      => 'rw',
    isa     => 'XT::FraudRules::Type::RuleSet',
    default => 'staging',
);

=head2 fraud_list_type

The type of the list, defaults to 'Test Type'.

=cut

has fraud_list_type => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Test Type',
    trigger => \&_fraud_list_type_trigger,
);

has _fraud_list_type_object => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Fraud::ListType',
    builder  => '_fraud_list_type_object_builder',
    lazy     => 1,
    init_arg => undef,
    writer   => 'set_fraud_list_type_object',
);

=head2 fraud_list_name

The name of the List, defaults to 'Test List'.

=cut

has fraud_list_name => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Test List',
);

=head2 rule_sequence

A description for the List, defaults to 'This is a Test List'.

=cut

has fraud_list_description => (
    is      => 'rw',
    isa     => 'Str',
    default => 'This is a Test List',
);

=head2 fraud_list_items

An ArrayRef of items for the list, defaults to the following five items:

    * Item 1
    * Item 2
    * Item 3
    * Item 4
    * Item 5

=cut

has fraud_list_items => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    handles => {
        all_fraud_list_items => 'elements',
    },
    default => sub { [
        'Item 1',
        'Item 2',
        'Item 3',
        'Item 4',
        'Item 5',
    ] },
);

=head2 auto_create_staging_fraud_list

Determines whether a Staging List will automatically be created for us when we ask for
a Live List.

Normally when we ask for a Live List, we'll get a Staging and Archive copy as well for
free, sometimes the Staging copy is not desired. To turn this off set this attribute
to false.

=cut

has 'auto_create_staging_fraud_list' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);


# _build_fraud_list
#
# Builder method to create a fraud list .
#

sub _build_fraud_list {
    my $self = shift;

    my $archived_list;
    my $live_list;
    my $staging_list;

    note sprintf(
        q{Creating a list called '%s' with a description of '%s' and of type '%s'},
        $self->fraud_list_name,
        $self->fraud_list_description,
        $self->fraud_list_type,
    );

    if ( $self->is_live_fraud_list ) {
    # Create the Live fraud list if required.

        # Create the Archived fraud list first.
        $archived_list = $self->_fraud_list__create_and_populate_list( 'archived', {
            change_log_id => $self->fraud_change_log->id,
        } );

        # Now create the Live fraud list.
        $live_list = $self->_fraud_list__create_and_populate_list( 'live', {
            archived_list_id => $archived_list->id
        } );


    }

    if ( $self->is_staging_fraud_list || $self->auto_create_staging_fraud_list ) {
    # Create the Staging fraud list if required.

        $staging_list = $self->_fraud_list__create_and_populate_list( 'staging', {
            live_list_id => $live_list ? $live_list->id : undef,
        } );

    }

    return $self->is_live_fraud_list
        ? $live_list
        : $staging_list;

}

=head2 DEMOLISH

Destructor method used to delete the test fraud list and its items

=cut

sub DEMOLISH {
    my $self = shift;

    $self->fraud_list->list_items->delete;
    $self->fraud_list->delete;
}

sub _fraud_list_get_list_type_object {
    my ($self,  $list_type ) = @_;

    return $self
        ->schema
        ->resultset('Fraud::ListType')
        ->find_or_create( {
            type => $list_type,
        } );

}

sub _fraud_list_type_trigger {
    my ($self,  $list_type ) = @_;

    $self->set_fraud_list_type_object(
        $self->_fraud_list_get_list_type_object( $list_type )
    );

}

sub _fraud_list_type_object_builder {
    my $self = shift;

    return $self->_fraud_list_get_list_type_object(
        $self->fraud_list_type
    );

}

sub is_staging_fraud_list { return ( lc( shift->fraud_list_ruleset ) eq 'staging' ? 1 : 0 ) }
sub is_live_fraud_list    { return ( lc( shift->fraud_list_ruleset ) eq 'live'    ? 1 : 0 ) }

sub _fraud_list__create_and_populate_list {
    my ($self,  $ruleset, $data ) = @_;

    my $resultset    = ucfirst "${ruleset}List";
    my $relationship = "${ruleset}_list_items";

    return $self->schema->resultset("Fraud::$resultset")->create( {
        list_type_id  => $self->_fraud_list_type_object->id,
        name          => $self->fraud_list_name,
        description   => $self->fraud_list_description,
        $relationship => [ map { { value => $_ } } $self->all_fraud_list_items ],
        # Now overide/add custom fields and values.
        %$data,
    } ) || die "Unable to create list for $resultset";

}

1;
