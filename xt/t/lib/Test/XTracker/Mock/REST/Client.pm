package Test::XTracker::Mock::REST::Client;

use NAP::policy "tt",     qw( class test );

use Test::MockObject;

=head1 NAME

Test::XTracker::Mock::REST::Client - A Mock  for REST::Client Module

=cut

sub setup_mock {
    my $self = shift;

    # Mock REST Client
    my $restclient = Test::MockObject->new;
    $restclient->fake_module(
        'REST::Client',
        new             => \&_new,
        setHost         => \&_setHost,
        buildQuery      => \&_buildQuery,
        GET             => \&_GET,
        setTimeout      => \&_setTimeout,
        responseContent => \&_responseContent,
        responseCode    => \&_responseCode,
    );

    return $restclient;
}

sub _new {
    return $_[0];
}

sub _setHost {
    return 1;
}

sub _GET {
    return 1;
}

sub _buildQuery {
    return 1;
}

sub _setTimeout {
    return 1;
}
my $responsecontent = '';

sub set_responseContent {
    my $self    = shift;
    my $data    = shift;

    $responsecontent = $data;
    return;
}

sub _responseContent {
    return $responsecontent;
}

my $responsecode = 200;

sub set_responseCode {
    my ( $self, $code ) = @_;
    $responsecode = $code;
    return;
}

sub _responseCode {
    return $responsecode;

}
