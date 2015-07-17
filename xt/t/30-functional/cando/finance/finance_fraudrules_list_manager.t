#!/usr/bin/env perl
use NAP::policy 'test';
use parent 'NAP::Test::Class';

BEGIN {

    use_ok 'XTracker::Constants::FromDB', qw(
        :authorisation_level
    );

}

=head1 NAME

t/30-functional/cando/finance/finance_fraudrules_list_manager.t

=head1 DESCRIPTION

Tests around the list manager in CONRAD / Fraud Rules.

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok 'Test::XT::Flow';

    # Get a framework.
    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );

    # Put us in the Finance department.
    Test::XTracker::Data->set_department( 'it.god', 'Finance' );

    # Log in.
    $self->{framework}->login_with_permissions( {
       perms => {
           $AUTHORISATION_LEVEL__OPERATOR => [
               'Finance/Fraud Rules',
           ]
       }
    } );

    $self->{list_number} = 1;

}

sub test_create_list_ok : Tests {
    my $self = shift;

    $self->test_list_exists( $self->create_list );

}

sub test_create_list_with_missing_info : Tests {
    my $self = shift;

    my $framework = $self->{framework};
    my $list_type = $self->get_list_type;
    my %values    = %{ $list_type->get_values_from_helper_methods };

    $framework
        ->flow_mech__finance__fraud_rules__list_manager

        # With a missing name.
        ->catch_error(
            'You must provide a list name',
            'List creation fails when the name is ommited',
            flow_mech__finance__fraud_rules__list_manager__submit_form => {
                list_name        => undef,
                list_description => 'Some Description',
                list_type_id     => $list_type->id,
                list_type_values => [ ( keys %values )[ 0 .. 1 ] ],
            }
        )

        # With a missing description.
        ->catch_error(
            'You must provide a list description',
            'List creation fails when the description is ommited',
            flow_mech__finance__fraud_rules__list_manager__submit_form => {
                list_name        => "$$ Test - Create List with Missing Description",
                list_description => undef,
                list_type_id     => $list_type->id,
                list_type_values => [ ( keys %values )[ 0 .. 1 ] ],
            }
        );

}

=head2 test_update_list

Tests functionality to update an existing list.

=cut

sub test_update_list : Tests {
    my $self = shift;

    my $framework       = $self->{framework};
    my $list            = $self->create_list;
    my $old_name        = $list->name;
    my $old_description = $list->description;
    my $other_list_type = $self->get_list_type( $list->list_type );
    my %other_values    = %{ $other_list_type->get_values_from_helper_methods };

    $self->test_list_exists( $list );

    $framework
        ->flow_mech__finance__fraud_rules__list_manager
        ->flow_mech__finance__fraud_rules__list_manager__edit_list( $list->id )
        ->flow_mech__finance__fraud_rules__list_manager__submit_form( {
            list_name        => $list->name . ' - updated',
            list_description => $list->description . ' - updated',
            list_type_id     => $other_list_type->id,
            list_type_values => [ ( keys %other_values )[ 0 .. 1 ] ],
        } );

    $list->discard_changes;

    cmp_deeply( $list, methods(
        name         => $old_name . ' - updated',
        description  => $old_description . ' - updated',
        list_type_id => $other_list_type->id,
    ) );

    # TODO test values

    $self->test_list_exists( $list );

}

=head2 test_delete_list

Tests "delete list" function.

=cut

sub test_delete_list : Tests {
    my $self = shift;

    my $framework = $self->{framework};
    my $list      = $self->create_list;

    $self->test_list_exists( $list );

    $framework
        ->flow_mech__finance__fraud_rules__list_manager
        ->flow_mech__finance__fraud_rules__list_manager__delete_list( $list->id );

    ok( !defined $self->find_list_item( $list->name ), 'List has been deleted' );

}

########################################################################

sub get_list_type {
    my ($self,  $not_this ) = @_;

    my $fraud_method = $self
        ->schema
        ->resultset('Fraud::Method')
        ->search( {
            rule_action_helper_method => { '!=' => undef },
            list_type_id    => { '>' => 0 },
            $not_this ? ( list_type_id => { '!=' => $not_this->id } ) : (),
        } )
        ->first;

    isa_ok( $fraud_method, 'XTracker::Schema::Result::Fraud::Method' );

    return $fraud_method->list_type;

}

sub find_list_item {
    my ($self,  $list_name ) = @_;

    my $lists   = $self->{framework}->mech->as_data->{lists};
    my @matches = grep { $_->{Name} eq $list_name } @$lists;

    return @matches
        ? $matches[0]
        : undef;

}

sub create_list {
    my ($self,  $name ) = @_;

    my $framework   = $self->{framework};
    my $list_number = $self->{list_number}++;
    my $list_type   = $self->get_list_type;
    my %values      = %{ $list_type->get_values_from_helper_methods };

    $name //= "Test List " . $list_number;
    $name = "[$$] $name";

    $framework
        ->flow_mech__finance__fraud_rules__list_manager
        ->flow_mech__finance__fraud_rules__list_manager__submit_form( {
            list_name        => $name,
            list_description => 'Some Description',
            list_type_id     => $list_type->id,
            list_type_values => [ ( keys %values )[ 0 .. 1 ] ],
        } );

    return $self->schema->resultset('Fraud::StagingList')->find( { name => $name } );

}

sub test_list_exists {
    my ($self,  $list ) = @_;

    cmp_deeply(
        $self->find_list_item( $list->name ),
        superhashof( {
            'Name'        => $list->name,
            'Description' => $list->description,
            'Type'        => $list->list_type->type,
        } )
    );

    # TODO test values

}

Test::Class->runtests;
