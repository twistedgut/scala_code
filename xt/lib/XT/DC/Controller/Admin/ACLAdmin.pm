package XT::DC::Controller::Admin::ACLAdmin;
# vim: set ts=4 sw=4 sts=4:

use Moose;

BEGIN { extends 'Catalyst::Controller' };

use XTracker::Config::Local         qw( use_acl_to_build_main_nav );
use XTracker::Logfile               qw( xt_logger );

use Try::Tiny;
use Carp;


=head1 NAME

XT::DC::Controller::Admin::ACLAdmin

=head1 DESCRIPTION

Controller for /Admin/ACLAdmin which maintains the settings in the
Global System Config Group 'ACL'.

=head1 METHODS

=over

=item B<root>

Beginning of the chain for Admin/ACLAdmin, containing common tasks for all actions.

=cut

# ----- common -----

sub root : Chained('/') PathPart('Admin/ACLAdmin') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->check_access('Admin', 'ACL Admin');

    $c->stash->{logger} = xt_logger();
}

# ----- ACL Admin -----

=item B<acl_admin>

Action for Admin/ACLAdmin

=cut

sub acl_admin : Chained('root') PathPart('') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    $c->stash->{template} = 'shared/admin/acl_admin.tt';

    $c->stash->{acl_config_group} = $c->model('DB::SystemConfig::ConfigGroup')->search( {
        name => 'ACL',
    } )->first;
}

=item B<acl_admin_GET>

GET REST action for Admin/ACLAdmin

=cut

sub acl_admin_GET {
    my ($self, $c) = @_;

    my $schema = $c->model('DB')->schema;

    $c->stash->{settings} = {
        build_main_nav => use_acl_to_build_main_nav( $schema ),
    };

    return;
}

=item B<acl_admin_POST>

POST REST action for Admin/ACLAdmin

Updates the Settings.

=cut

sub acl_admin_POST {
    my ($self, $c) = @_;

    my $schema          = $c->model('DB')->schema;
    my $logger          = $c->stash->{logger};

    my $acl_group       = $c->stash->{acl_config_group};
    my $acl_settings_rs = $acl_group->search_related('config_group_settings');

    # define a list of fields that are checkboxes on the page
    # specifying for each one the values to be used when On & Off
    my %checkboxes  = (
        build_main_nav  => { on => 'On', off => 'Off' },
    );

    # only get relvant fields from posted
    my $fields = $self->_get_setting_params( $c, \%checkboxes );

    try {
        $schema->txn_do( sub {
            my $changes_made = 0;

            while ( my ( $field, $value ) = each %{ $fields } ) {

                my $setting = $acl_settings_rs->find( { setting => $field } );
                croak "Couldn't find a setting for '${field}'"      if ( !$setting );

                if ( my $checkbox = $checkboxes{ $field } ) {
                    # get the On/Off value for the setting and
                    # update the record if there's been a change
                    my $update_value = ( $value ? $checkbox->{on} : $checkbox->{off} );
                    if ( $setting->value ne $update_value ) {
                        $setting->update( { value => $update_value } );
                        $changes_made++;
                        # log the change
                        $logger->info(
                            "Setting '${field}' changed to: '${update_value}'" .
                            " by: '" . $c->session->{operator_id} . " - " . $c->session->{operator_name} . "'"
                        );
                    }
                }
                else {
                    # when there are other fields
                    # to cope with then do that here
                }
            }

            $c->feedback_success( "Settings Updated" )      if ( $changes_made );
        } );
    }
    catch {
        my $error = $_;

        $logger->error( $error );
        $c->feedback_warn( "Error trying to save settings: ${error}" );
    };

    # re-direct to the '_GET' part so the page is drawn properly with all the changes
    return $c->response->redirect( $c->uri_for( $self->action_for('acl_admin') ) );
}

#-------------------------------------------------------------------

# return in a Hash Ref. parameters passed
# to the handler that start with 'setting_'
sub _get_setting_params {
    my ( $self, $c, $checkboxes ) = @_;

    # because checkbox fields don't return anything
    # when they're not checked they need to be specified
    # here and set to 'undef' so if they were returned
    # they will be overriden later on
    my %fields = (
        map { $_ => undef } keys %{ $checkboxes }
    );

    FIELD:
    foreach my $field ( $c->request->param ) {
        next FIELD  if ( $field !~ m/^setting_/ );

        my $value   = $c->request->param( $field );

        # remove the prefix
        $field  =~ s/^setting_//;

        $fields{ $field } = $value;
    }

    return \%fields;
}

1;
