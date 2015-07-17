package Test::XT::Domain::Payment::Form;
use NAP::policy qw( tt class test );

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

Test::XT::Domain::Payment:Form

=head1 DESCRIPTION

Tests the 'XT::Domain::Payment::Form' Class.

=cut

sub test__startup_01_classes : Tests( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup();

    use_ok 'Test::XTracker::Mock::Handler';
    use_ok 'Test::XTracker::Mock::WebServerLayer';
    use_ok 'Test::XTracker::Mock::PSP';
    use_ok 'XTracker::Config::Local';
    use_ok 'XT::Domain::Payment::Form';
    use_ok 'Test::XT::Data';
    use_ok 'URI::URL';

}

sub test__startup_02_configuration : Tests( startup => no_plan ) {
    my $self = shift;

    $self->{data} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
    );

    $self->{mock_psp}           = Test::XTracker::Mock::PSP->new;
    $self->{customer}           = $self->data->customer;
    $self->{fake_session_id}    = 'TEST-PAYMENT-SESSION';
    $self->{fake_url}           = 'http://www.test.com';

    # get the PSP Mock in a known state
    Test::XTracker::Mock::PSP->use_all_mocked_methods();

}

sub test__startup_03_initialisation : Tests( startup => no_plan ) {
    my $self = shift;

    Test::XTracker::Mock::WebServerLayer->set_url_to_use(
        $self->fake_url );

}

sub test__setup_01_mock_psp : Tests( setup => no_plan ) {
    my $self = shift;

    # Start with some known states.
    $self->mock_psp->set__get_card_details_status__response__success;
    $self->mock_psp->set__create_new_payment_session__response(
        $self->fake_session_id );

}

sub test_teardown_01_mock_psp : Tests( teardown => no_plan ) {
    my $self = shift;

    # Clear up after ourselves, by making sure that we always return success
    # for the methods we've used.
    $self->mock_psp->set__get_card_details_status__response__success;
    $self->mock_psp->set__create_new_payment_session__response__success;

}

sub test__shutdown_mock_psp : Tests( shutdown => no_plan ) {
    my $self = shift;

    # stop the mocking of the PSP
    $self->mock_psp->disable_mock_lwp();
    Test::XTracker::Mock::PSP->use_all_original_methods();
}

=head1 TEST OBJECT INSTANTIATION

=head2 test__instantiation_success

Make sure instantiation succeeds with all the required attribites.

=cut

sub test__instantiation_success : Tests {
    my $self = shift;

    $self->new_object_ok;

}

=head2 test__instantiation_missing_handler

Test that instantiating the object with a missing handler attribute fails.

=cut

sub test__instantiation_missing_handler : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object(
            customer => $self->customer,
        );
    }, qr/Attribute \(handler\) is required at/,
    'Correct exception is thrown for a missing handler' );

}

=head2 test__instantiation_incorrect_handler

Test that instantiating the object with an incorrect handler attribute fails.

=cut

sub test__instantiation_incorrect_handler : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object(
            handler  => 'Should be an XTracker::Handler',
            customer => $self->customer,
        );
    }, qr/Attribute \(handler\) does not pass the type constraint/,
    'Correct exception is thrown for an incorrect handler' );

}

=head2 test__instantiation_missing_customer

Test that instantiating the object with a missing customer attribute fails.

=cut

sub test__instantiation_missing_customer : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object(
            handler => $self->new_mock_handler_ok,
        );
    }, qr/Attribute \(customer\) is required at/,
    'Correct exception is thrown for a missing customer' );

}

=head2 test__instantiation_incorrect_customer

Test that instantiating the object with an incorrect customer attribute fails.

=cut

sub test__instantiation_incorrect_customer : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object(
            handler  => $self->new_mock_handler_ok,
            customer => 'Should be an XTracker::Schema::Result::Public::Customer',
        );
    }, qr/Attribute \(customer\) does not pass the type constraint/,
    'Correct exception is thrown for an incorrect customer' );

}

=head2 test__instantiation_incorrect_log

Test that instantiating the object with an incorrect log attribute fails.

=cut

sub test__instantiation_incorrect_log : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object(
            handler  => $self->new_mock_handler_ok,
            customer => $self->customer,
            log      => 'Should be a Log::Log4perl::Logger',
        );
    }, qr/Attribute \(log\) does not pass the type constraint/,
    'Correct exception is thrown for an incorrect log' );

}

=head1 TEST OBJECT ATTRIBUTES

=head2 test__attribute_redirect_url

Test the redirect_url attribute has the correct default.

=cut

sub test__attribute_redirect_url : Tests {
    my $self = shift;

    my $object = $self->new_object_ok;

    my $expected = sprintf( '%s?payment_session_id=%s&is_redirect_url=1',
        $self->fake_url,
        $self->fake_session_id );

    cmp_ok( $object->redirect_url->as_string,
        'eq',
        $expected,
        'The URL attribute has the correct default' );

}

=head2 test__attribute_domain_payment

Test the domain_payment attribute has the correct default and is mocked.

=cut

sub test__attribute_domain_payment : Tests {
    my $self = shift;

    my $object = $self->new_object_ok;

    isa_ok( $object->domain_payment,
        'XT::Domain::Payment',
        'Domain Payment Attribute');

    ok( $object->domain_payment->is_mocked,
        ' ... and it is mocked' );

}

=head2 test__attribute_requested_payment_session_id

Test the requested_payment_session_id attribute has the correct default when
the payment_session_id parameter is passed in the handler and when it's not.

=cut

sub test__attribute_requested_payment_session_id : Tests {
    my $self = shift;

    my $object;

    # First test that we get undef when no parameter was present.

    $object = $self->new_object_ok;

    is( $object->requested_payment_session_id,
        undef,
        'The attribute is undefined when the parameter is not present' );

    # Then test that when the parameter is passed to the handler, the
    # attribute is correct.

    $object = $self->new_object_ok(
        handler => {
            payment_session_id => $self->fake_session_id,
        },
    );

    ok( defined $object->requested_payment_session_id,
        'The attribute is defined when the parameter is present' );

    cmp_ok( $object->requested_payment_session_id,
        'eq',
        $self->fake_session_id,
        '  ... and is correct' );

}

=head2 test__attribute_current_payment_session_id

Test the current_payment_session_id attribute has the correct default.

=cut

sub test__attribute_current_payment_session_id : Tests {
    my $self = shift;

    my %tests = (
        'Parameter Passed' => {
            handler     => { payment_session_id => 'BY_PARAMETER' },
            psp_success => 1,
            expected    => { result => 'BY_PARAMETER' },
        },
        'No Parameter Passed (PSP Success)' => {
            handler     => {},
            psp_success => 1,
            expected    => { result => $self->fake_session_id },
        },
        'No Parameter Passed (PSP Failure)' => {
            handler     => {},
            psp_success => 0,
            expected    => {
                result  => '',
                log     => qr/Problem building current_payment_session_id/ },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest( $name, sub {

            if ( $test->{psp_success} ) {
                $self->mock_psp->set__create_new_payment_session__response(
                    $self->fake_session_id );
            } else {
                $self->mock_psp->set__create_new_payment_session__response__die;
            }

            my $object = $self->new_object_ok(
                handler => $test->{handler}
            );

            ok( defined $object->current_payment_session_id,
                'The attribute is always defined' );

            cmp_ok( $object->current_payment_session_id,
                'eq',
                $test->{expected}->{result},
                '  ... and it is correct' );

            # TODO: Check the log got the error message.

        } );

    }

}

=head2 test__attribute_site

Test the site attribute.

=cut

sub test__attribute_site : Tests {
    my $self = shift;

    my $object   = $self->new_object_ok;
    my $expected = $self->customer->channel->web_name;
    $expected    =~ s/\A(.+)-(.+)\Z/\U$1_$2/;

    ok( $object->site,
        'The attribute is defined' );

    cmp_ok( $object->site,
        'eq',
        lc( $expected ),
        '  ... and is correct' );

}

=head2 test__attribute_default_form_name

Test the default_form_name attribute.

=cut

sub test__attribute_default_form_name {
    my $self = shift;

    my $object = $self->new_object_ok;

    ok( $object->default_form_name,
        'The attribute is defined' );

    cmp_ok( $object->default_form_name,
        'eq',
        'psp_post_form',
        '  ... and is correct' );

}

=head2 test__attribute_payment_service_endpoint

Test the payment_service_endpoint attribute.

=cut

sub test__attribute_payment_service_endpoint : Tests {
    my $self = shift;

    local $XTracker::Config::Local::config{PaymentService}->{payment_form_url} =
        'http://psp.domain';

    my $object = $self->new_object_ok;

    ok( $object->payment_service_endpoint,
        'The attribute is defined' );

    cmp_ok( $object->payment_service_endpoint,
        'eq',
        'http://psp.domain/payment',
        '  ... and is correct' );

}

=head2 test__attribute_log

Test the log attribute.

=cut

sub test__attribute_log : Tests {
    my $self = shift;

    my $object = $self->new_object_ok;

    ok( $object->log,
        'The attribute is defined' );

    isa_ok( $object->log,
        'Log::Log4perl::Logger',
        '  ... and is' );

}

=head1 TEST OBJECT METHODS

=head2 test__attribute_redirect_and_initial_request

Test the C<is_redirect_request> and C<is_initial_request> methods.

=cut

sub test__attribute_redirect_and_initial_request : Tests {
    my $self = shift;

    my $object;

    # First test the initial request.

    $object = $self->new_object_ok;

    ok( $object->is_initial_request, 'For initial request: is_initial_request is true' );
    ok( !$object->is_redirect_request, 'For initial request: is_redirect_request is false' );

    # Now test for the redirect request.

    $object = $self->new_object_ok(
        handler => {
            payment_session_id => $self->fake_session_id,
            is_redirect_url =>1,
        },
    );

    ok( !$object->is_initial_request, 'For redirect request: is_initial_request is false' );
    ok( $object->is_redirect_request, 'For redirect request: is_redirect_request is true' );

}

=head2 test__handle_redirect_request

Test the _handle_redirect_request method.

=cut

sub test__handle_redirect_request : Tests {
    my $self = shift;

    subtest 'Testing with Success' => sub {

        my $object = $self->new_object_ok;

        $self->mock_psp->set__get_card_details_status__response__success;
        $object->_handle_redirect_request;

        ok( $object->payment_success,
            'payment_success method returns TRUE' );

        ok( !defined $object->raw_payment_errors,
            'raw_payment_errors is undefined' );

        isa_ok( $object->payment_errors,
            'ARRAY', 'payment_errors' );

        cmp_ok( scalar @{ $object->payment_errors },
            '==',
            0,
            '  ... and it is empty' );

    };

    subtest 'Testing with Failure' => sub {

        my $object = $self->new_object_ok;

        $self->mock_psp->set__get_card_details_status__response__failure;

        # Set a known "different" payment session id
        $self->mock_psp->set__create_new_payment_session__response( 'TEST8901234' );
        $object->_handle_redirect_request;

        ok( !$object->payment_success,
            'payment_success method returns FALSE' );

        ok( defined $object->raw_payment_errors,
            'raw_payment_errors is defined' );

        is_deeply( $object->raw_payment_errors, {
            54007 => 'Card Number too long or too short',
            54008 => 'Invalid Card Number i.e failed luhn check',
        }, 'raw_payment_errors contains the correct data' );

        isa_ok( $object->payment_errors,
            'ARRAY', 'payment_errors' );

        cmp_deeply( $object->payment_errors, bag(
            'Card Number too long or too short (54007)',
            'Invalid Card Number i.e failed luhn check (54008)',
        ), 'payment_errors contains the correct data' );

        cmp_ok( $object->current_payment_session_id,
                'eq',
                'TEST8901234',
                'Has correct new payment session id'
              );

    };

}

=head2 test__form_header

Test the form_header method.

=cut

sub test__form_header : Tests {
    my $self = shift;

    my $object       = $self->new_object_ok;
    my $endpoint     = $object->payment_service_endpoint( URI::URL->new( 'http://test.endpoint' ) );
    my $redirect_url = $object->redirect_url( URI::URL->new( 'http://test.redirect.url' ) );
    my $session_id   = $object->current_payment_session_id;
    my $site         = $object->site;
    my $customer_id  = $self->customer->id;
    my $admin_id     = 0;

    subtest 'Test with Form Name Passed in' => sub {

        my $got      = $object->form_header( 'TEST_FORM_NAME' );
        my $expected = qq[
        <form id="TEST_FORM_NAME" name="TEST_FORM_NAME" method="POST" action="$endpoint">
            <input type="hidden" name="paymentSessionId" value="$session_id" />
            <input type="hidden" name="redirectUrl"      value="$redirect_url" />
            <input type="hidden" name="customerId"       value="$customer_id" />
            <input type="hidden" name="site"             value="$site" />
            <input type="hidden" name="adminId"          value="$admin_id" />
    ];

        cmp_ok( $got, 'eq', $expected, 'form_header returns the correct value' );

    };

    subtest 'Test with Form Name NOT Passed in' => sub {

        my $form_name = $object->default_form_name( 'DEFAULT_FORM_NAME' );

        my $got      = $object->form_header;
        my $expected = qq[
        <form id="DEFAULT_FORM_NAME" name="DEFAULT_FORM_NAME" method="POST" action="$endpoint">
            <input type="hidden" name="paymentSessionId" value="$session_id" />
            <input type="hidden" name="redirectUrl"      value="$redirect_url" />
            <input type="hidden" name="customerId"       value="$customer_id" />
            <input type="hidden" name="site"             value="$site" />
            <input type="hidden" name="adminId"          value="$admin_id" />
    ];

        cmp_ok( $got, 'eq', $expected, 'form_header returns the correct value' );

    };

}

=head2 test__form_footer

Test the form_footer method.

=cut

sub test__form_footer : Tests {
    my $self = shift;

    my $object = $self->new_object_ok;

    my $got = $object->form_footer;
    my $expected = q[
        </form>
    ];

}

=head2 test__populate_stash

Test the populate_stash method.

=cut

sub test__populate_stash : Tests {
    my $self = shift;

    my $object = $self->new_object_ok;
    $object->populate_stash;

    my $data = $self->{last_handler}->{data};

    ok( exists $data->{payment_form},
        'The payment_form element exists' );

    isa_ok( $data->{payment_form}->{header},
        'CODE', 'payment_form header' );

    isa_ok( $data->{payment_form}->{footer},
        'CODE', 'payment_form footer' );

}

=head1 HELPER METHODS

=head2 new_mock_handler_ok( \%param_of )

Returns a new instance of L<Test::XTracker::Mock::Handler>, checking it's the
correct type before returning it.

Any parameters you want to pass to the handler can be passed in via C<%param_of>.

=cut

sub new_mock_handler_ok {
    my ($self,  $param_of ) = @_;

    $self->{last_handler} = Test::XTracker::Mock::Handler
        ->new( { param_of => $param_of } );

    isa_ok( $self->{last_handler},
        'Test::MockObject',
        'Mock Handler' );

    return $self->{last_handler};

}

=head2 new_object( %arguments )

Returns a new instance of L<XT::Domain::Payment::Form>, with no defaults, so
you must pass any C<%arguments> that you require.

=cut

sub new_object {
    my ($self,  %arguments ) = @_;

    return XT::Domain::Payment::Form->new(
        %arguments );

}

=head2 new_object_ok( %arguments )

Returns a new instance of an L<XT::Domain::Payment::Form>, making sure it is
of the correct type and that the C<new> method lives ok.

A default handler is created for the object and the test customer in
C<customer> is used.

Accepts the following key/value C<%arguments>:

    handler
    object

The C<handler> option is a HashRef of options to pass the Handlers param_of
HashRef entry. This is optional.

The C<object> option is a HashRef of options to pass to the new object. This
is optional as well.

=cut

sub new_object_ok {
    my ($self,  %arguments ) = @_;

    my %object_arguments = (
        handler     => $self->new_mock_handler_ok( $arguments{handler} ),
        customer    => $self->customer,
        ref( $arguments{object} ) eq 'HASH'
            ? %{ $arguments{object} }
            : (),
    );

    my $object;

    lives_ok( sub { $object = $self->new_object( %object_arguments ) },
        'Domain Payment does not die when being instantiated' );

    isa_ok( $object, 'XT::Domain::Payment::Form',
        'Domain Payment' );

    return $object;

}

=head1 ATTRIBUTES

=head2 Accessors

    customer
    mock_psp
    data
    fake_session_id
    fake_url

=cut

sub customer        { return shift->{customer} }
sub mock_psp        { return shift->{mock_psp} }
sub data            { return shift->{data} }
sub fake_session_id { return shift->{fake_session_id} }
sub fake_url        { return shift->{fake_url} }

