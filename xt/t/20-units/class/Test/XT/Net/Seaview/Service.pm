package Test::XT::Net::Seaview::Service;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Net::Seaview::Service

=head1 DESCRIPTION

Tests the L<XT::Net::Seaview::Service> class.

=head1 SETUP

Test the class can be use'd OK.

=cut

sub test__setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->SUPER::setup;

    use_ok 'XT::Net::Seaview::Service';

}

=head1 TESTS

=head2 test__urn_lookup

Test the C<urn_lookup> method.

Using various URNs, ensure the method either returns the correct URL or the
expected exception is thrown.

=cut

sub test__urn_lookup : Tests {
    my $self = shift;

    my $guid    = 'e53ef6d8-34c5-11e3-9f14-b4b52f51d098';
    my $service = XT::Net::Seaview::Service->new;

    my %test = (
        # Failure (Missing Information)
        "urn"                                       => qr/\[Error\] Lookup failed for URN \(no matches found\): urn/,
        "urn:nap"                                   => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap/,
        "urn:nap:customer"                          => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:customer/,
        "urn:nap:account"                           => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account/,
        "urn:nap:account:$guid:bosh"                => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:bosh/,
        "urn:nap:account::cardToken"                => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account::cardToken/,
        "urn:nap:address"                           => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:address/,
        # Failure (Broken Information)
        "urn:"                                      => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:/,
        "urn:nap:"                                  => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:/,
        "urn:nap:customer:"                         => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:customer:/,
        "urn:nap:account:"                          => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:/,
        "urn:nap:account:$guid:bosh:mykey:"         => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:bosh:mykey:/,
        "urn:nap:account:$guid:cardToken:"          => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:cardToken:/,
        "urn:nap:account:cardToken:"                => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:cardToken:/,
        "urn:nap:address:"                          => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:address:/,
        # Failure (Too Much Information)
        "urn:nap:customer:$guid:extra"              => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:customer:$guid:extra/,
        "urn:nap:account:$guid:extra"               => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:extra/,
        "urn:nap:account:$guid:bosh:mykey:extra"    => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:bosh:mykey:extra/,
        "urn:nap:account:$guid:cardToken:extra"     => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:$guid:cardToken:extra/,
        "urn:nap:account:cardToken:$guid:extra"     => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:account:cardToken:$guid:extra/,
        "urn:nap:address:$guid:extra"               => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:address:$guid:extra/,
        # Failure (Malformed Information)
        "urn:nap:$guid:customer"                    => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:$guid:customer/,
        "urn:nap:$guid:account"                     => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:$guid:account/,
        "urn:nap:$guid:account:bosh:mykey"          => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:$guid:account:bosh:mykey/,
        "urn:nap:$guid:account:cardToken"           => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:$guid:account:cardToken/,
        "urn:nap:cardToken:account:$guid"           => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:cardToken:account:$guid/,
        "urn:nap:$guid:address"                     => qr/\[Error\] Lookup failed for URN \(no matches found\): urn:nap:$guid:address/,
        # Success
        "urn:nap:customer:$guid"                    => $service->service_url . "/customers/$guid",
        "urn:nap:account:$guid"                     => $service->service_url . "/accounts/$guid",
        "urn:nap:account:$guid:bosh:mykey"          => $service->service_url . "/bosh/account/$guid/mykey",
        "urn:nap:account:$guid:cardToken"           => $service->service_url . "/accounts/$guid/cardToken",
        "urn:nap:account:cardToken:$guid"           => $service->service_url . "/accounts/$guid/cardToken",
        "urn:nap:address:$guid"                     => $service->service_url . "/addresses/$guid",
    );

    while ( my ( $urn, $expected ) = each %test ) {

        subtest( $urn, sub {

            if ( ref( $expected ) eq 'Regexp' ) {
            # A RegEx indicates the test is expected to fail and the exception
            # thrown must match the RegEx.

                throws_ok( sub { $service->urn_lookup( $urn ) },
                    $expected,
                    'call to urn_lookup dies as expected' );

            } else {
            # Otherwise, the test is expected to pass, with the method
            # returning the given result.

                my $got;

                lives_ok( sub { $got = $service->urn_lookup( $urn ) },
                    'call to urn_lookup lives' );

                cmp_ok( $got, 'eq', $expected, "$urn -> $expected" );

            }

        } );

    }

}

