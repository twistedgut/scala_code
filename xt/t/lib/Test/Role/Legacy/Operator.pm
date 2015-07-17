package Test::Role::Legacy::Operator;

use NAP::policy qw( test role tt );

requires 'get_schema';

=head1 NAME

Test::Role::Legacy::Operator

=head1 DESCRIPTION

Legacy methods used to set-up an Operator and an Operator's
Permissions.

When the XT Access Controls project is finished this file
can be removed.

=cut

=head1 METHODS

=head2 delete_all_permissions

=head2 grant_permissions

=head2 set_department

    __PACKAGE__->set_department( $user, $dept );

Updates the database so that the operator specified by C<$user>
is linked to the department specified by C<$dept>.

=cut

sub delete_all_permissions {
    my ($class, $user) = @_;

    $user = $class->_get_operator($user);

    $user->permissions->delete;
}


sub grant_permissions {
    my ($class, $user, $section, $sub, $level, $args ) = @_;

    $user = $class->_get_operator($user);

    my $rs = $class->get_schema->resultset('Public::AuthorisationSection')
        ->search({ section => $section })->related_resultset('sub_section');

    my $sub_sec = $rs->search({ sub_section => $sub },{rows=>1})->first
        or die "Unable to find auth section $section/$sub";

    # Enables it.god user for auto log in
    $class->_enable_user($user)     unless ( $args->{dont_enable_user} );

    if ($level) {
        my $curr = $user->permissions->search(
            {authorisation_sub_section_id => $sub_sec->id},{rows=>1})->first;
        if ($curr) {
            $curr->update({authorisation_level_id => $level});
        } else {
            $user->permissions->create({
                authorisation_sub_section_id => $sub_sec->id,
                authorisation_level_id => $level
            });
        }
    }
}

sub set_department {
    my ($class, $user, $department) = @_;
    $user = $class->_get_operator($user);

    my $dept = $class->get_schema->resultset('Public::Department')->find(
        { department => $department },
        { key => 'department' }
    ) or die "Unable to find department '$department'";

    $user->update({ department_id => $dept->id });
}

sub _enable_user {
    my ( $class, $user, $args ) = @_;

    $user->auto_login(1);
    $user->disabled(0);
    $user->use_acl_for_main_nav( $args->{use_acl_for_main_nav} // 0 );
    $user->update;
}

sub _get_operator {
    my ($class, $user) = @_;

    unless ($user =~ /^[0-9]+$/) {
        my $rs = $class->get_schema->resultset('Public::Operator');
        return $rs->find({username => $user}, {key => 'username'})
        || die "Unable to find operator $_[1]";
    }
    return $class->get_schema->resultset('Public::Operator')->find($user)
    || die "Unable to find operator $_[1]";
}
