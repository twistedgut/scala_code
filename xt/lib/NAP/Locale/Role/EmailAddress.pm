package NAP::Locale::Role::EmailAddress;

use NAP::policy "tt", qw( role );

with 'NAP::Locale::Role';

=head1 NAME

NAP::Locale::Role::EmailAddress

=head1 DESCRIPTION

Locale implementation for Email Addresses. Given an Email Address it will give the localised
version back if one can be found else it will give back what was given.

=cut

=head1 METHODS

=head2 email_address( $email_address )

    $email_address  = $locale->email_address( 'test@net-a-porter.com' );

Given an Email Address will return a Localised version of it, if one can be found,
if not it will return what was given.

This is essentially a wrapper around the 'XTracker::EmailFunctions::localised_email_address'
function.

=cut

sub email_address {
    my ( $self, $email_address )    = @_;

    return ''       if ( !$email_address );

    # using the explicit call to 'localised_email_address' because there ends
    # up being a circular reference to 'NAP::Locale' in 'XTracker::EmailFunctions'
    ## no critic(ProhibitAmpersandSigils)
    return &XTracker::EmailFunctions::localised_email_address( $self->schema, $self->locale, $email_address );
}

