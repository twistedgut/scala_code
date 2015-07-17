package Test::XTracker::Mock::WebServerLayer;

use NAP::policy     qw( test );

=head1 NAME

Test::XTracker::Mock::WebServerLayer

=head1 SYNOPSYS

    use Test::XTracker::Mock::WebServerLayer;
    use XTracker::Handler;

    my $handler = XTracker::Handler->new(
        Test::XTracker::Mock::WebServerLayer->setup_mock
    );

=head1 DESCRIPTION

Used to Mock the Web Server Layer for the purposes of testing 'XTracker::Handler' by giving
it something so that it can be instantiated and allow testing of some of the functionality.

This is very basic at the moment please build upon this as required.

Currently this mocks 'Plack::App::FakeModPerl1'.

=cut

use Test::MockObject::Extends;
use URI;

use Plack::Util;        # required for 'Plack::App::FakeModPerl1'
use Plack::App::FakeModPerl1;

use XTracker::Session;

use XTracker::Constants         qw( :application );


=head1 METHODS

=head2 setup_mock

    $mocked_weblayer_object = Test::XTracker::Mock::WebServerLayer->setup_mock;

This will return a Mocked 'WebServerLayer' object which can then be passed
to 'XTracker::Handler'.

=cut

sub setup_mock {
    my ( $self, $args ) = @_;

    # get the URL to use in the mock
    my $url_to_use = delete $args->{url_to_use};

    if ( my $with_session = delete $args->{with_session} ) {
        # set-up a basic session if asked for
        $XTracker::Session::SESSION = {
            operator_id => $APPLICATION_OPERATOR_ID,
            ( ref( $with_session ) eq 'HASH' ? %{ $with_session } : () ),
        };
    }

    local %ENV;
    %ENV = (
        %ENV,
        ( $args->{env} ? %{ $args->{env} } : () ),
        $self->_get_query_string( $args->{get_params} ),
    );

    # < ilmari> in 5.18 %ENV stringifies on assignment
    # so we can no longer: env => \%ENV
    my $plack = Plack::App::FakeModPerl1->new( env => { %ENV } );

    my $mock = Test::MockObject::Extends->new( $plack );
    $mock->mock( 'parsed_uri', \&_parsed_uri );

    $self->set_url_to_use( $url_to_use )    if ( $url_to_use );

    return $mock;
}

=head2 setup_mock_with_get_params

    $mocked_weblayer_object = __PACKAGE__->setup_mock_with_get_params(
        '/CustomerCare/OrderSearch/OrderView',
        {   # key/value pairs that will be turned
            # into a Query String - '?key=value&...'
            order_id => 21313,
        },
        # optional:
        {
            # other args to pass to 'setup_mock'
            some => value,
        }
    );

Returns the same as 'setup_mock' but will set the URI to the first
parameter and also get 'setup_mock' to create a Query String using
the Hash Ref. passed as the second parameter. The Query String should
then be parsed by 'XTracker::Handler' and be available in the
'param_of' Key.

This will also setup the Mock with a basic session, in the optional
$args you can specify more things to put in the session by assigning
a Hash Ref. of options to the 'with_session' Key.

=cut

sub setup_mock_with_get_params {
    my ( $self, $uri, $get_params, $args ) = @_;

    $args //= {};

    # strip off any leading '/' on $uri
    $uri =~ s{^/}{};

    return $self->setup_mock( {
        url_to_use   => "http://www.example.com/${uri}",
        with_session => delete $args->{with_session} // 1,
        get_params   => $get_params,
        %{ $args },
    } );
}

=head2 get_xt_session

    $session = __PACKAGE__->get_xt_session();

Returns the Session.

=cut

sub get_xt_session {
    return XTracker::Session->session();
}

=head2 check_success_message_like

=head2 check_success_message_unlike

    __PACKAGE__->check_success_message_like( $what_to_expect, $test_message );
                    or
    __PACKAGE__->check_success_message_unlike( $what_to_expect, $test_message );

Will check the 'success' message that will be put in the Session when a page
wants to communicate to the Operator that an operation has been successful.

Use the appropriate method for the Test you want to perform.

=cut

sub check_success_message_like {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'SUCCESS', 'like', @params );
}

sub check_success_message_unlike {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'SUCCESS', 'unlike', @params );
}

=head2 check_info_message_like

=head2 check_info_message_unlike

    __PACKAGE__->check_info_message_like( $what_to_expect, $test_message );
                    or
    __PACKAGE__->check_info_message_unlike( $what_to_expect, $test_message );

Will check the 'info' message that will be put in the Session when a page
wants to communicate information to the Operator.

Use the appropriate method for the Test you want to perform.

=cut

sub check_info_message_like {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'INFO', 'like', @params );
}

sub check_info_message_unlike {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'INFO', 'unlike', @params );
}

=head2 check_warning_message_like

=head2 check_warning_message_unlike

    __PACKAGE__->check_warning_message_like( $what_to_expect, $test_message );
                    or
    __PACKAGE__->check_warning_message_unlike( $what_to_expect, $test_message );

Will check the 'warning' message that will be put in the Session when a page
wants to communicate to the Operator that an operation has been unsuccessful.

Use the appropriate method for the Test you want to perform.

=cut

sub check_warning_message_like {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'WARN', 'like', @params );
}

sub check_warning_message_unlike {
    my ( $self, @params ) = @_;
    return $self->_check_session_message( 'WARN', 'unlike', @params );
}


sub _check_session_message {
    my ( $self, $message_type, $check_type, $expect, $test_message ) = @_;

    $test_message ||= "${message_type} as Expected: '${expect}'";

    my $session = $self->get_xt_session();
    my $message = $session->{xt_error}{message}{ $message_type };

    if ( $check_type eq 'like' ) {
        like( $message, qr/${expect}/i, $test_message );
    }
    else {
        unlike( $message, qr/${expect}/i, $test_message );
    }

    return;
}

sub _get_query_string {
    my ( $self, $params ) = @_;

    return ()       if ( !$params );

    my $query_string = '';
    my $separator    = '';

    while ( my ( $key, $value ) = each %{ $params } ) {
        $value       //= '';
        $query_string .= "${separator}${key}=${value}";
        $separator     = '&';
    }

    return (
        QUERY_STRING => $query_string,
    );
}

#
# mocking Methods
#

my $_url_to_use = 'http://www.example.com';
sub set_url_to_use {
    my $self     = shift;
    $_url_to_use = shift;
    return;
}

sub _parsed_uri {
    my $self    = shift;

    my $uri      = URI->new( $_url_to_use );
    my $mock_uri = Test::MockObject::Extends->new( $uri );

    # add an 'unparse' method
    $mock_uri->mock( 'unparse', \&_unparse );

    return $mock_uri;
}

sub _unparse {
    my $uri = shift;
    return $uri->path . ( $uri->query ? '?' . $uri->query : '' );
}


1;
