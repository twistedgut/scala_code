package Test::XTracker::Mock::Service::Seaview;
use NAP::policy     qw( tt test );

=head1 NAME

Test::XTracker::Mock::Service::Seaview - Allows Mocking of Seaview calls

=head1 DESCRIPTION

Use to mock calls to the Seaview Service, contains various methods to
set up responses you'd like to have Seaview return for your tests.

This uses the 'XT::Net::Seaview::TestUserAgent' class which is the
User Agent used by Seaview when running tests.

=cut

use Test::XTracker::Data;
use XT::Net::Seaview::TestUserAgent;

use JSON;


=head1 METHODS

=head2 make_up_resource_urn

    my $string = __PACKAGE__->make_up_resource_urn( 'resource', $guid );
        or
    my $string = __PACKAGE__->make_up_resource_urn( 'account', '50cfa81bbf8eccc73fcc0447' );

Will return a URN with the appropriate prefix for the Resource that you want it to be for.

=cut

sub make_up_resource_urn {
    my ( $self, $resource, $guid ) = @_;

    my %resources = (
        account => 'urn:nap:account:',
    );

    if ( !$resources{ $resource } ) {
        croak "Don't know what to do with Resource: '" . ( $resource // 'undef' ) . "'";
    }

    return $resources{ $resource } . $guid;
}

=head2 set_welcome_pack_flag

    __PACKAGE__->set_welcome_pack_flag( 1 or 0 );

Sets the value of the 'welcomePackSent' field that will be returned when the
account is requested.

=cut

sub set_welcome_pack_flag {
    my ( $self, $value ) = @_;

    return XT::Net::Seaview::TestUserAgent->change_account_respsone( {
        welcomePackSent => $self->_return_JSON_true_false( $value ),
    } );
}

=head2 set_customer_category

    __PACKAGE__->set_customer_category( 'Customer Category' );

Sets the value of the 'category' field that will be returned when the
account is requested.

=cut

sub set_customer_category {
    my ( $self, $category ) = @_;

    $category = lc( $category );
    $category =~ s/[^a-z0-9\s]//g;
    $category =~ s/\s{2}/ /g;
    $category =~ s/\s/_/g;

    return XT::Net::Seaview::TestUserAgent->change_account_respsone( {
        category => "urn:nap:${category}",
    } );
}

# helper to return JSON 'true' or 'false'
sub _return_JSON_true_false {
    my ( $self, $value ) = @_;

    return 'false'      if ( !defined $value );

    return 'true'       if ( $value =~ m/^[TY1]/i );
    return 'false'      if ( $value =~ m/^[FN0]/i );

    return;
}

=head2 clear_get_account_response

    __PACKAGE__->clear_get_account_response;

Makes sure then next Account request will use the Defaults
when returning a Response.

=cut

sub clear_get_account_response {
    XT::Net::Seaview::TestUserAgent->clear_account_GET_response;
    return;
}

=head2 get_recent_account_update

    $hash_ref = __PACKAGE__->get_recent_account_update;

Get the payload of the most recent Account update.

=cut

sub get_recent_account_update {
    my $self = shift;

    my $request = XT::Net::Seaview::TestUserAgent->get_most_recent_account_POST_request;

    return      if ( !$request );
    return JSON->new->utf8->decode( $request->content );
}

=head2 clear_recent_account_update_request

    __PACKAGE__->clear_recent_account_update_request;

Clears the most recent Account Update request.

=cut

sub clear_recent_account_update_request {
    XT::Net::Seaview::TestUserAgent->clear_recent_account_POST_request;
    return;
}


1;
