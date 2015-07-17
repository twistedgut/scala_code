package XT::DC::Messaging::Consumer::SeaviewNotification;
use NAP::policy 'class', 'tt';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::SeaviewNotification;

use XT::Net::Seaview::Client;

=head1 NAME

XT::DC::Messaging::Consumer::SeaviewNotification

=head1 DESCRIPTION

Consume a Seaview customer update notification and update the matching local
XT record

=cut

sub routes {
    return {
        seaview_notification => {
            CustomerUpdatePublished => {
                code => \&process,
                spec => XT::DC::Messaging::Spec::SeaviewNotification->seaview_notification(),
            }
        }
    }
}


sub process {
    my ($self, $message, $headers) = @_;

    # Setup
    my $urn = $message->{object}->{id};
    my $schema = $self->model('Schema');

    # Query Seaview for customer
    my $sv = XT::Net::Seaview::Client->new({schema => $schema});

    if( my $sv_account = $sv->account($urn) ){

        # Determine differences
        my $diff = $sv_account->compare_with_storage();

        try{
            # Update fields taking Seaview data as correct
            $sv_account->update_local_storage({fields => $diff});
        }
        catch {
            # Database update problem
            $self->log->info(
                'Failed to update the XT database for customer account: '
                . $urn );
        }
    }
    else {
        # Can't access Seaview account
        $self->log->info( 'Failed to access the Seaview account: ' . $urn );
     }
}
