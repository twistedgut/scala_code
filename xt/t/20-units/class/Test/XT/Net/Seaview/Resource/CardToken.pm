package Test::XT::Net::Seaview::Resource::CardToken;

use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 DESCRIPTION

Tests the basic methods of the Seaview CardToken resource

=cut

sub test_startup : Test( startup => 5 ) {
    my $self = shift;

    use_ok 'Test::XTracker::Data';
    use_ok 'Test::XTracker::Session';
    use_ok 'XT::Net::Seaview::TestUserAgent';
    use_ok 'XT::Net::Seaview::Service';
    use_ok 'XT::Net::Seaview::Resource::CardToken';

    $self->{schema}   = Test::XTracker::Data->get_schema;
    $self->{ua}       = XT::Net::Seaview::TestUserAgent->new;
    $self->{service}  = XT::Net::Seaview::Service->new;
    $self->{resource} = XT::Net::Seaview::Resource::CardToken->new( {
        schema        => $self->{schema},
        useragent     => $self->{ua},
        session_class => 'Test::XTracker::Session',
        service       => $self->{service},
    } );

    $self->{url} = 'http://mock.seaview/accounts/test/cardToken';

}

sub get : Tests {
    my $self = shift;

    my $rep;
    lives_ok sub { $rep = $self->{resource}->get( $self->{url} ) },
             'Representation can be built';

    isa_ok($rep, 'XT::Net::Seaview::Representation::CardToken');

}

