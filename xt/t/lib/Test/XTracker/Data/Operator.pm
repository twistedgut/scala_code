package Test::XTracker::Data::Operator;

use strict;
use warnings;

use Test::XTracker::Data;

=head2 get_first_operator
=cut

sub get_all_operators_for_section_and_authority {
    my ($self, $args) = @_;

    my $schema = Test::XTracker::Data->get_schema;

    return $schema->resultset('Public::Operator')->by_authorisation($args->{section}, $args->{subsection})->search({
        department_id                        => $args->{department},
        'permissions.authorisation_level_id' => $args->{level}
    }, {
        'join' => 'permissions',
        order_by => 'name'
    });
}

sub create_new_operator_with_authorisation {
    my ($self, $args) = @_;

    my $op = $self->create_new_operator({
        department_id => $args->{department_id}
    });

    $self->give_operator_authorisation({
        authorisation_sub_section_id => $args->{authorisation_sub_section_id},
        authorisation_level_id       => $args->{authorisation_level_id},
        operator_id                  => $op->id
    });

    return $op;
}
sub create_new_operator {
    my ($self, $args) = @_;

    my $schema = Test::XTracker::Data->get_schema;


    # Reset the Sequence Id on operator table
    $schema->storage->dbh->do("SELECT SETVAL('operator_id_seq', (SELECT max(id) FROM operator))");
    my $uniq = $schema->resultset('Public::Operator')->get_column('id')->max();

    # Create Operator
    return $schema->resultset('Public::Operator')->create({
        name          => $args->{name} || 'John Smith',
        username      => $args->{username} || 'js'.$uniq,
        password      => 'ps'.$uniq,
        email_address => $args->{email} || 'john.smith@example.com',
        disabled      => $args->{disabled} || 0,
        department_id => $args->{department_id}
    });
}

sub give_operator_authorisation {
    my ($self, $args) = @_;

    my $schema = Test::XTracker::Data->get_schema;

    return $schema->resultset('Public::OperatorAuthorisation')->create({
        operator_id                  => $args->{operator_id},
        authorisation_level_id       => $args->{authorisation_level_id},
        authorisation_sub_section_id => $args->{authorisation_sub_section_id}
    });
}

1;
