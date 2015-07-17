#!/usr/bin/perl

=head1 NAME

CloneUserAuths.t - Test cloning users on the User Admin screen

=head1 DESCRIPTION

Clone an admin user

* Verify authorisation remains same when user clones itself

* Verify Admin Section is not cloned, when cloning an admin user

#TAGS useradmin candoandwhm misc

=cut

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::Data::Operator;
use Test::XTracker::Mock::Handler;
use XTracker::Admin::AJAX::CloneUserAuths;
use XTracker::Constants::FromDB   qw(
    :department
    :authorisation_level
    :authorisation_section
);
use XTracker::Constants qw/:application/;
use JSON::PP;
use Test::XT::Flow;


sub startup :Tests(startup => 1) {
     my ($self) = @_;

    $self->SUPER::startup();

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Admin',
        ],
    );

    $self->{flow}->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Admin/User Admin',
        ]},
        dept => 'Customer Care',
    });

    $self->{schema}                 = Test::XTracker::Data->get_schema();

    #Create an admin user
    my $admin_subsection_id = $self->{schema}->resultset('Public::AuthorisationSubSection')->search({
        authorisation_section_id => $AUTHORISATION_SECTION__ADMIN
    })->first->id;

    $self->{admin_user} = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $admin_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__MANAGER,
        department_id                => $DEPARTMENT__PERSONAL_SHOPPING,
    })->id;

    #create a non-admin user
    my $subsection_id = $self->{schema}->resultset('Public::AuthorisationSubSection')->search({
        authorisation_section_id => $AUTHORISATION_SECTION__CUSTOMER_CARE
    })->first->id;

    $self->{normal_user} = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__MANAGER,
        department_id                => $DEPARTMENT__CUSTOMER_CARE,
    })->id;


}

sub test_cloning_same_user : Tests() {
    my $self = shift;

    note " Test :Application user trying to clone itself";

    my $mech = $self->{flow}->mech;
    $mech->get_ok( "/Admin/UserAdmin/AJAX/CloneUserAuths?clone_operator_id=".$APPLICATION_OPERATOR_ID."&page_operator_id=".$self->{admin_user}," Got OK : AJAX GET request" );

    # Decode response as JSON.
    my $data = eval { JSON::PP->new->allow_singlequote->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;
    isa_ok( $data, 'HASH', "Data returned is a HASH" );

    $mech->get_ok( "/Admin/UserAdmin/AJAX/CloneUserAuths?clone_operator_id=".$APPLICATION_OPERATOR_ID."&revert=1"," Got OK : AJAX GET request" );
    my $data2 = eval { JSON::PP->new->allow_singlequote->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;
    isa_ok( $data2, 'HASH', "Data returned is a HASH" );

     #get all ids where authlevel is non zero
     my @array1  = grep {$_} map {$_->{'auth_id'} }grep{ $_->{'auth_level'} !=0} @{$data->{auths}};
     my @array2  = grep {$_} map {$_->{'auth_id'} }grep{ $_->{'auth_level'} !=0} @{$data2->{auths}};

     is_deeply(\@array1, \@array2, "Authorisation remains same when user clones itself");

}

sub test_cloning_admin_user :Tests() {
    my $self = shift;

    note " Test :Application user  trying to clone admin user";
    my $mech = $self->{flow}->mech;

    #clone admin user
    $mech->get_ok( "/Admin/UserAdmin/AJAX/CloneUserAuths?clone_operator_id=".$self->{'normal_user'}."&page_operator_id=".$self->{'admin_user'}," Got OK : AJAX GET request" );
    my $data = eval { JSON::PP->new->allow_singlequote->decode( $mech->content ) } || diag $@ . "\n" . $mech->content;
    isa_ok( $data, 'HASH', "Data returned is a HASH" );

    #get admin authorisation ids
    my @all_auths = $self->{schema}->resultset('Public::AuthorisationSubSection')->search( {
        'section.id' =>  $AUTHORISATION_SECTION__ADMIN,
    },
    {
        join => 'section',
    })->all;

    # check admins ids are not in the cloned set
    my @admin_ids = map{$_->id } @all_auths;
    my @got_id  =
        grep {$_}
        map {$_->{'auth_id'} }
        grep{ $_->{'auth_level'} !=0}
        @{$data->{auths}};

    my %tmp  = map  { $_ => 1 } @admin_ids;
    my @same = grep { exists $tmp{$_} } @got_id;

    cmp_ok(scalar(@same) ,'==', 0, 'Admin Section is Not cloned as expected');

}


sub rollback : Test(shutdown) {
    my $self = shift;

}

Test::Class->runtests;
