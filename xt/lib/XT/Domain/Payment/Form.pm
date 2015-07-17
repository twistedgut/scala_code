package XT::Domain::Payment::Form;
use NAP::policy 'class', 'tt';

use URI;
use URI::URL;
use URI::QueryParam;

use XT::Domain::Payment;
use XTracker::Config::Local 'config_var';
use NAP::Logging::JSON;

=head1 NAME

XT::Domain::Payment::Form

=head1 DESCRIPTION

Handles interactions with the PSP regarding redirects when making a payment.

When instantiated at the beginning of a handler, this simplifies generating
an HTML form and processing the redirect that is returned from the PSP. It
also preserves data between page requests.

The sequence of events is:

1. The object is instantiated for the initial page request.
2. The object is used to generate an appropriate form to submit data to the PSP.
3. The user submits the payment form.
4. The PSP redirects the user back to the same page as in step 1.
5. The object is instantiated again for the redirected request.
6. The object makes a call to the PSP to determine the outcome of step 3.
7. The object can be inspected for the results.

=head1 SYNOPSIS

B<IN THE HANDLER>

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $payment_form = XT::Domain::Payment::Form->new(
        handler  => $handler,
    );

    if ( $payment_form->is_initial_request ) {

        # ...

    } elsif ( $payment_form->is_redirect_request ) {

        if ( $payment_form->payment_success ) {

            # ...

        } else {

            xt_warn( $payment_form->raw_payment_errors );
            # ...

        }

    }

B<IN THE TEMPLATE>

    [% payment_form.header %]
        <input type="text" name="issueNumber" />
        <input type="text" name="startMonth" />
        <input type="text" name="cardType" />
        <input type="text" name="startYear" />
        <input type="text" name="expiryMonth" />
        <input type="text" name="expiryYear" />
        <input type="text" name="cVSNumber" />
        <input type="text" name="cardNumber" />
        <input type="text" name="cardHoldersName" />
        <input type="text" name="keepCard" />
        <input type="text" name="savedCard" />
        <input type="text" name="customerId" />
        <input type="text" name="last4Digits" />
        <input type="submit" name="Make Payment" />
    [% payment_form.footer %]

All the required form inputs are automatically injected by the
C<payment_form.header> call, you only need to insert the above ones.

}

=head1 ATTRIBUTES

=head2 handler

Required:   Yes
Read Only:  Yes
Type:       XTracker::Handler

=cut

has handler => (
    is          => 'ro',
    isa         => 'XTracker::Handler',
    required    => 1,
);

=head2 customer

Required:   Yes
Read Only:  No
Type:       XTracker::Schema::Result::Public::Customer

=cut

has customer => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::Customer',
    required    => 1,
);

=head2 redirect_url

Required:   No
Read Only:  No
Type:       URI::URL

This will default to the URL used to get to the current page, including all
the parameters. It will also add a C<payment_session_id> parameter, to
signify that we've been redirected.

This is used when generating the form.

=cut

has redirect_url => (
    is          => 'rw',
    isa         => 'Object',
    lazy_build  => 1,
);

sub _build_redirect_url {
    my $self = shift;

    # Get the full URI used to retrieve the page.
    my $url = $self->handler->{request}->parsed_uri;

    # Fetch all the GET/POST parameters.
    my $parameters = $self->handler->{param_of};

    while ( my ( $param, $value ) = each %$parameters ) {

        # We want a list of all the values for a parameter.
        my $values = ref( $value ) eq 'ARRAY'
            ? $value
            : [ $value ];

        # .. so they can be injected into the new URL.
        $url->query_param( $param => $values );

    }

    # Add the payment session ID.
    $url->query_param( payment_session_id =>
        $self->current_payment_session_id );

    $url->query_param( is_redirect_url => 1 );

    $self->log->debug( logmsg 'redirect url built',
        url => $url );

    return $url;

}

=head2 domain_payment

Required:   No
Read Only:  Yes
Type:       XT::Domain::Payment

Defaults to a new XT::Domain::Payment object.

=cut

has domain_payment => (
    is          => 'ro',
    isa         => 'XT::Domain::Payment',
    default     => sub { XT::Domain::Payment->new },
);

=head2 log

Required:   No
Read Only:  Yes
Type:       Log::Log4perl

The logger to use. Defaults to the C<domain_payment> logger:

    $self->domain_payment->logger;

=cut

has log => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    lazy        => 1,
    default     => sub { shift->domain_payment->logger },
);

=head2 requested_payment_session_id

Required:   No
Read Only:  Yes
Type:       Undef OR Str

Defaults to the URL C<payment_session_id> parameter if passed in.

=cut

has requested_payment_session_id => (
    is          => 'ro',
    isa         => 'Undef|Str',
    default     => sub { delete shift->handler->{param_of}->{payment_session_id} },
);

=head2 current_payment_session_id

Required:   No
Read Only:  Yes
Type:       Str

Defaults to either C<requested_payment_session_id> or if that's not present,
then it will request a new payment session id from the payment service.

=cut

has current_payment_session_id => (
    is          => 'rw',
    isa         => 'Str',
    lazy_build  => 1,
);

sub _build_current_payment_session_id {
    my $self = shift;

    $self->log->debug( logmsg 'building payment session id' );

    my $result;

    try {

        $result =
            $self->requested_payment_session_id ||
            $self->domain_payment->create_new_payment_session(
                $self->handler->session->{_session_id},
                $self->customer->get_or_create_card_token );

        $self->log->debug( logmsg 'payment session id built',
            url => $result );

    } catch {

        my $error = $_;
        $self->log->warn( logmsg 'problem building payment session id',
            error => $error );

    };

    return $result // '';

}

=head2 payment_success

Required:   No
Read Only:  Yes
Type:       Undef OR Bool

Returns TRUE or FALSE depending on whether the previous call the C<payment>
method on the payment service was sucessfull or not.

See also C<raw_payment_errors>.

If this is first call (i.e. not a redirect) it will return Undef, as it is
meaningless to call it in this scenario.

=cut

has payment_success => (
    is          => 'ro',
    isa         => 'Undef|Bool',
    init_arg    => undef,
    default     => undef,
    writer      => '_set_payment_success'
);

=head2 raw_payment_errors

Required:   No
Read Only:  Yes
Type:       Undef OR HashRef

Returns a HashRef of error codes and descriptions if the payment failed.

See also C<payment_success>.

If this is first call (i.e. not a redirect) it will return Undef, as it is
meaningless to call it in this scenario.

=cut

has raw_payment_errors => (
    is          => 'ro',
    isa         => 'Undef|HashRef',
    init_arg    => undef,
    writer      => '_set_raw_payment_errors',
);

=head2 site

Required:   No
Read Only:  Yes
Type:       Str

Returns a valid site name for the PSP to use, based on the C<web_name> of the
C<channel> associated with the C<customer>.

At the time of writing, the valid sites are:

    XT
    mrp_am
    mrp_apac
    mrp_intl
    mrp_test
    nap_am
    nap_apac
    nap_intl
    nap_test
    outnet_am
    outnet_apac
    outnet_intl
    outnet_test

=cut

has site => (
    is          => 'ro',
    isa         => 'Str',
    init_arg    => undef,
    lazy_build  => 1,
);

sub _build_site {
    my $self = shift;

    my $site = $self->customer->channel->web_name;

    # The PSP expects underscores instead of hyphens and it must all be
    # lowercase.
    $site =~ s/\A(.+)-(.+)\Z/\U$1_$2/;

    $self->log->debug( logmsg 'site built',
        site => $site );

    return lc $site;

}

=head2 default_form_name

Required:   No
Read Only:  No
Type:       Str

The name (and id) that will be used for the payment form.

Defaults to 'psp_post_form'.

=cut

has default_form_name => (
    is          => 'rw',
    isa         => 'Str',
    default     => 'psp_post_form',
);

=head2 payment_service_endpoint

Required:   No
Read Only:  No
Type:       URI::URL

The URL for the Payment Service.

Defaults to the config entry 'PaymentService' -> 'service_url'.

=cut

has payment_service_endpoint => (
    is          => 'rw',
    isa         => 'URI::URL',
    lazy_build  => 1,
);

sub _build_payment_service_endpoint {
    my $self = shift;

    my $url = URI::URL->new(
        config_var( 'PaymentService', 'payment_form_url' ) );

    # Remove the last segment if it's empty (this is normal behaviour, as '/'
    # is treated as a segment when either at the beginning or the end of the URL).
    my @segments = $url->path_segments;
    pop @segments unless $segments[-1];

    # Now append the endpoint for the call.
    $url->path_segments( @segments, 'payment' );

    $self->log->debug( logmsg 'payment service endpoint built',
        url => $url );

    return $url;

}

sub BUILD {
    my $self = shift;

    $self->log->debug( logmsg 'object instantiated' );

    $self->_handle_redirect_request
        if $self->is_redirect_request;

    $self->populate_stash;

    return $self;

}

=head1 METHODS

=head2 is_redirect_request

Returns TRUE if this is the redirect back from the Payment Service, FALSE if
not.

=cut

sub is_redirect_request {
    my $self = shift;

    my $parameters = $self->handler->{param_of};
    return defined $parameters->{is_redirect_url}
        ? 1
        : 0;

}

=head2 is_initial_request

Returns FALSE if this is the redirect back from the Payment Service, TRUE if
not.

=cut

sub is_initial_request {
    my $self = shift;

    return ! $self->is_redirect_request;

}

=head2 payment_errors

Returns an ArrayRef of C<raw_payment_errors> stringified into the error
message and code in brackets.

For example:

    my $errors = $payment_form->payment_errors;

    # $errors will now contain something like:
    # [
    #   'The server is getting hot (666)',
    #   'The server is on fire (999)',
    # ]

=cut

sub payment_errors {
    my $self = shift;

    my $errors = $self->raw_payment_errors;

    return $errors
        ? [ map { "$errors->{$_} ($_)" } keys %$errors ]
        : [];

}

=head1 INTERNAL METHODS

=head2 form_header

Generates the opening <form> tag that includes all the required hidden inputs.

=cut

sub form_header {
    my ($self, $form_name ) = @_;

    $form_name //= $self->default_form_name;

    my $data = $self->handler->{data}->{payment_forms}->{ $form_name } = {
        admin_id        => 0,
        customer_id     => $self->customer->id,
        form_action     => $self->payment_service_endpoint,
        form_id         => $form_name,
        form_name       => $form_name,
        redirect_url    => $self->redirect_url,
        session_id      => $self->current_payment_session_id,
        site            => $self->site,
    };

    $self->log->debug(
        logmsg 'data used to generate form header',
        data => $data );

    return qq[
        <form id="$data->{form_id}" name="$data->{form_name}" method="POST" action="$data->{form_action}">
            <input type="hidden" name="paymentSessionId" value="$data->{session_id}" />
            <input type="hidden" name="redirectUrl"      value="$data->{redirect_url}" />
            <input type="hidden" name="customerId"       value="$data->{customer_id}" />
            <input type="hidden" name="site"             value="$data->{site}" />
            <input type="hidden" name="adminId"          value="$data->{admin_id}" />
    ];

}

=head2 form_footer

Generates the closing <form> tag.

Currently all this returns is '</form>', but please use this for consistency
and in case this ever changes.

=cut

sub form_footer {
    my $self = shift;

    return q[
        </form>
    ];

}

=head2 populate_stash

Populates the handler C<data> attribute with the Hash C<payment_form>, which
contains two references to the methods above:

 * form_header (called header)
 * form_footer (called footer)

See SYNOPSIS for details.

=cut

sub populate_stash {
    my $self = shift;

    $self->handler->{data}->{payment_form} = {
        header => sub { $self->form_header( @_ ) },
        footer => sub { $self->form_footer( @_ ) },
    };

}

=head1 PRIVATE METHODS

=head2 _handle_redirect_request

This makes a call to the Payment service C<get_card_details_status> method to
determine if the previous payment was successfull or not. It then updates the
C<payment_success> and C<raw_payment_errors> attributes.

=cut

sub _handle_redirect_request {
    my $self = shift;

    $self->log->debug(
        logmsg 'calling get_card_details_status' );

    my $psp_result = $self->domain_payment->get_card_details_status(
        $self->current_payment_session_id );

    if ( $psp_result->{valid} ) {

        $self->_set_payment_success( 1 );

        $self->log->debug(
            logmsg 'get_card_details_status response indicates card details are valid',
            response => $psp_result );

    } else {

        $self->_set_payment_success( 0 );
        $self->_set_raw_payment_errors( $psp_result->{errors} );

        # Get a new payment session as the existing one is no longer valid
        try {
            my $new_session_id = $self->domain_payment->create_new_payment_session(
                $self->handler->session->{_session_id},
                $self->customer->get_or_create_card_token
            );

            $self->current_payment_session_id( $new_session_id );
        } catch {
            $self->log->warn(
                logmsg 'Cannot get a new payment session ID.',
                error => $_
            );
        };


        $self->log->info(
            logmsg 'get_card_details_status response indicates card details are invalid',
            response => $psp_result );

    }

}
