package Test::XTracker::Mechanize; ## no critic(ProhibitExcessMainComplexity)

use NAP::policy qw (test class);

=head1 NAME

Test::XTracker::Mechanize - Test::WWW::Mechanize subclass for testing XTracker

=head1 METHODS

=cut

use Moose;
use MooseX::NonMoose;

use Log::Log4perl ':easy';

#use Apache::TestRequest ();

use Carp;
use FindBin;

use Plack::Middleware::Session;
use Plack::Session::State::Cookie;
use Plack::Session::Store::DBI;
use Test::Builder;
use Test::Deep;
use Test::More;
use URI;
use URI::QueryParam;
use Safe::Isa;

use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use Test::XTracker::Model;
use Test::XTracker::LogSnitch;
use vars qw( $Test );
use Data::Dump qw/pp/;
use XTracker::Config::Local;
use XTracker::Config::Parameters 'sys_param';
use XTracker::Database::Product     qw( get_variant_by_sku );
use XTracker::DblSubmitToken;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/
  :renumeration_status
  :renumeration_type
  :return_item_status
  :return_status
  :shipment_class
  :shipment_item_status
  :shipment_status
  :stock_process_status
  :channel
  :variant_type
  :flow_status
  :department
  :business
  :correspondence_templates
/;
use XTracker::Database::Distribution;
use XTracker::Script::Shipment::AutoSelect;
use Test::XT::Flow;
use Test::XT::Data::Container;
use XTracker::Utilities 'fix_encoding';
use Test::XT::URLCoverage::Recorder;
use Test::NAP::Messaging::Helpers 'atleast';
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::Mechanize::Session;


extends 'Test::WWW::Mechanize', 'Test::Builder::Module', 'Test::XTracker::Data';

# Make WWW::Mechanize::TreeBuilder's DEMOLISH method account for the fact that
# the tree may already have been demolished at global cleanup
{
    require WWW::Mechanize::TreeBuilder;
    no warnings 'redefine';
    *WWW::Mechanize::TreeBuilder::DEMOLISH = sub {
        $_[0]->tree->delete if $_[0]->has_tree && defined $_[0]->tree; };
}

with 'WWW::Mechanize::TreeBuilder' => {tree_class => 'HTML::TreeBuilder::XPath'},
    'Test::XTracker::Client',
    'MooseX::Traits';

# Turn on explicit watching of the HTTP requests.
before 'request' => \&_debug_request;
after  'request' => \&_debug_request_time;
before '_modify_request' => \&_apply_overrides;

if (  $ENV{'JENKINS_TEST_UID'} || $ENV{'LOG_URL_COVERAGE'} ) {
    my $recorder = Test::XT::URLCoverage::Recorder->new();

    around 'send_request' => sub {
        my $orig = shift;
        my $self = shift;

        my $response = $self->$orig( @_ );
        $recorder->log( $response );

        $response;
    };
}

=head2 debug_http()

Attribute accepting an Int. Set it to 1 to get a summary of outgoing HTTP
requests, or 2 for the whole kaboodle.

=cut

my %overrides = (
    'datalite' => [ 'Bool', 0 ],
    'sticky_pages' => [ 'Bool', 0 ],
    # TODO: Remove: CLIVE-114
    'override_iws_phase' => [ 'Int', undef ],
);
for my $override (keys %overrides) {
    has "force_$override"   => (
        is => 'rw',
        isa => 'Maybe['.$overrides{$override}->[0].']',
        default => $overrides{$override}->[1],
    );
}

# Turn on explicit watching of the HTTP requests.
has 'debug_http'       => ( is => 'rw', isa => 'Int',  default => 0 );

=head2 errors_are_fatal

Boolean flag, checked by the Flow framework's C<note_status> method. States
that if an error message is found, it's a fatal error. Turn this off explicitly
if you're trying to find errors:

 $mech->errors_are_fatal(0);

=cut

has 'errors_are_fatal' => ( is => 'rw', isa => 'Bool', default => 1 );

has order_nr => (
    is => 'rw',
    isa => 'Int',
    trigger => sub {
        my ($self, $value, $old_value) = @_;
        $old_value ||= '';

        $self->_clear_order_view_url
          if $value ne $old_value;
    },
    predicate => 'has_order_nr',
);

has order_view_url => (
    is => 'ro',
    isa => 'Str',
    clearer => '_clear_order_view_url',
    builder => '_build_order_view_url',
    lazy => 1,
);

has amq => (
    is => 'ro',
    lazy => 1,
    default => sub { Test::XTracker::MessageQueue->new }
);

has channel => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    lazy        => 1,
    builder     => '_set_channel',
    );

has logged_in_as => (
    is   => 'rw',
    isa  => 'Str',
);

has last_request_debug_queue => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    writer  => '_set_last_request_debug_queue'
);

has log_snitch => (
    is  => 'ro',
    isa => 'Test::XTracker::LogSnitch',
    default => sub {
        # Might as well put the logsnitch here...
        my $snitch = Test::XTracker::LogSnitch->new;
        $snitch->add_file(
            $XTracker::Config::Local::APP_ROOT_DIR . 't/logs/error_log'
        );
        return $snitch;
    }
);

has session => (
    is         => 'ro',
    isa        => 'Test::XTracker::Mechanize::Session',
    lazy_build => 1,
    clearer    => 'clear_session',
);

=head2 dbl_submit_token

Generate a double submit token.

=cut

sub dbl_submit_token {
    my ( $self ) = @_;
    Carp::cluck( 'This method has been deprecated - we now use CSRF middleware' );
    return XTracker::DblSubmitToken->generate_new_dbl_submit_token(
        Test::XTracker::Data->get_schema );
}

sub add_to_last_request_debug_queue {
    my ( $self, @lines ) = @_;
    my @current_queue = @{ $self->last_request_debug_queue };
    unshift( @current_queue, \@lines );
    if ( @current_queue > 3 ) {
        splice(@current_queue, 3);
    }
    $self->_set_last_request_debug_queue( \@current_queue );
}

=head2 use_first_page_form

    $mech = $mech->use_first_page_form;

Sets the 'current_form' to be the first FORM on the page that isn't the Quick
Search form. Use this method when you want to 'tick', 'untick' or perform other
form operations on fields that are in the first FORM proper on the page but
don't want the hassle of finding out and then setting the current form.

Returns a Mech object so you can chain methods.

=cut

sub use_first_page_form {
    my $mech    = shift;

    my $form_number = 0;

    my @forms   = $mech->forms();
    FORM:
    foreach my $form ( @forms ) {
        # form numbering starts at 1
        $form_number++;

        # don't want Quick Search FORM
        next FORM   if ( ( $form->action || '' ) =~ /QuickSearch/ );

        # this will set internally the form that will be used
        $mech->form_number( $form_number );

        last FORM;      # found the first FORM proper
    }

    return $mech;
}

# Create a default channel if one is not defined
#
sub _set_channel {
    my ($self) = @_;

    my $channel = Test::XTracker::Data->get_local_channel_or_nap('nap');

    return $channel;
}

sub _build_order_view_url {
    my ($self) = @_;

    confess "order_view_url needs an order_nr set first!"
        unless $self->has_order_nr;

    my $uri = $self->order_view_url_for_order_nr($self->order_nr)
        or LOGCONFESS "Unable to find order page for order_nr " . $self->order_nr;

    return $uri->as_string;
}

sub _build_session {
    my $self    = shift;
    return Test::XTracker::Mechanize::Session->new( {
        mech => $self,
    } );
}

# applies the various overrides (datalite, sticky_pages, override_iws_phase)
sub _apply_overrides {
    my ( $self, $request ) = @_;
    return $request unless $request->uri->scheme eq 'http';

    for my $override (keys %overrides) {
        my $attribute = "force_$override";
        my $value = $self->$attribute;

        # no override set: skip
        next unless defined $value;
        # boolean override, false: skip
        next if $overrides{$override}->[0] eq 'Bool' && ! $value;
        # it's already there, probably set externally: leave it
        next if defined $request->uri->query_param( $override );

        # ok, set it
        $request->uri->query_param( $override => $value );
    }

    return $request;
}

sub _debug_request {
    my ( $self, $request ) = @_;
    my $debug_level = $self->debug_http || 0;
    $self->{'_mechanize_timer'} = time();

    my %data = (
        base_url => $request->uri->path,
        'method' => $request->method
    );

    my @debug_lines = (
        "=====",
        '> ' . $data{'method'} . ': ' . $data{'base_url'},
        ($request->uri->query ? '> Query string: ' . $request->uri->query : ()),
        ($request->content ? '> Content line: ' . $request->decoded_content : ()),
        "====="
    );

    $self->add_to_last_request_debug_queue(@debug_lines);

    # Actually display that
    if ( $debug_level == 1 ) {
        note $_ for @debug_lines;

    # Full message
    } elsif ( $debug_level > 1 ) {
        note "=====";
        note "Full request:";
        note $request->as_string;
        note "=====";
    }
}

sub _debug_request_time {
    my ( $self ) = @_;
    my $diff = time() - $self->{'_mechanize_timer'};
    if ( $diff > 5 ) {
        note "HTTP Response took $diff seconds";
    }
}

around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    # https://metacpan.org/source/PHRED/Apache-Test-1.38/lib/Apache/TestRun.pm#L1123
    # uses CORE::exit, which prevents us doing ANYTHING SENSIBLE to catch the
    # 'failed' TestRun
    #
    # Make sure people aren't sneaking mech tests into t/10 or t/20
    # - this should fix Jenkins happily passing tests that shouldn't and be
    #   helpful to devs
    Carp::confess("tests in $1 should not be using a Mechanize based object")
        if ($FindBin::RealBin =~ m{/(t/10-env|t/20-units)});

    # These are actually ignored by the Mechanize instantiation, but we pass
    # them through to 'BUILD' below.
    #$args{'base'}    ||= Apache::TestRequest::resolve_url('');
    if (not $args{'base'}) {
        my $port = $ENV{XTDC_APP_LISTEN} || $ENV{APACHE_TEST_PORT} || 8529;
        $args{base} = qq{http://localhost.localdomain:${port}/};
    }
    $args{'timeout'} ||= '600';

    return $class->$orig(
        timeout => 600,
        %args
    );
 };

sub BUILD {
    my ( $self, $args ) = @_;

    $self->timeout( $args->{'timeout'} );
    $self->{'base'} = $args->{'base'};

    note 'URL is ' . $self->base;
    return $self;
}

sub _force_new_tree {
    my $self = shift;
    $self->_set_tree(
        HTML::TreeBuilder::XPath->new_from_content($self->content)->elementify
    );
}

sub uri_without_overrides {
    my ($self) = @_;

    my $ret = $self->uri->clone;

    for my $override (keys %overrides) {
        $ret->query_param_delete($override);
    }

    return $ret;
}

#
# Check how many times a string appears in a file
#
sub find_text_in_file {
    my ($self, $filename, $text) = @_;

    my $found = 0;
    open(my $PRINTED,'<', $filename) or die "Cannot read file $filename";
    while (my $line = (<$PRINTED>)) {
        $found++ if ($line =~ /$text/);
    }

    close $PRINTED;
    return $found;
}

=head2 do_login($user='it.god') :

Log in the current user

=cut

sub do_login {
    my ( $self, $user ) = @_;

    $user //= 'it.god';

    my $schema = Test::XTracker::Data->get_schema;

    # Create our session and get the id
    my $session = Plack::Middleware::Session->new({
      store =>  Plack::Session::Store::DBI->new(
          get_dbh => sub { $schema->storage->dbh },
      ),
      state => Plack::Session::State::Cookie->new,
    });
    my $session_id = $session->generate_id({});

    my $operator = $schema->resultset('Public::Operator')->find({username => $user});

    # We can get things working with a very minimal config
    $session->store->store($session_id, {
        user_id     => $user,
        acl         => { operator_roles => undef },
        operator_id => $operator->id,
    });
    $self->cookie_jar->set_cookie(
        0,                            # cookie version
        $session->state->session_key, # key
        $session_id,                  # value
        '/',                          # path
        URI->new($self->base)->host,  # domain
        undef,                        # port
        1,                            # path_spec
        undef,                        # secure
        5400                          # maxage
    );

    $operator->update({ last_login => \'now()' });

    # This is a convenience accessor for our mechanize object
    $self->logged_in_as($user);

    return $self;
}

=head2 mech_login_ok($user, $pass, $desc) :

Login using mechanize.

=cut

sub mech_login_ok {
    my ($self, $user, $pass, $desc) = @_;
    my $tries = 5;
LOGINPROCESS:

    TRACE "Enter with $user/$pass";

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $desc = "login as '$user'" if not defined $desc;

    # In the test suite we do not want to honour the redir_to thing
    # So clear the cookie jar to force a new session
    $self->get('/Home');

    TRACE "Log out...";
    $self->get('/Logout');
    my $ok = $self->success;

    if (!$ok) {
        ERROR "Could not logout";
        $self->builder->ok($ok, $desc);
        $self->builder->diag("Failed to get /Logout");
        $self->builder->diag( $self->status );
        $self->builder->diag( $self->response->message ) if $self->response;
        return $ok;
    }
    else {
        TRACE "...logged out.";
    }

    unless ($self->find_xpath("//h1[text() = 'Login']")) {
        FATAL "Could not find xpath - $desc";
        fail($desc);
        $self->builder->diag("We don't appear to be on the login page");
        return 0;
    }

    TRACE "Get operator for $user";
    my $operator = Test::XTracker::Data->_get_operator($user);
    Test::XTracker::Data->_enable_operator($operator);

    TRACE "Logging in $user/$pass...";
    $self->submit_form(
        with_fields => {
            password => $pass,
            username => $user
        },
    );
    $ok = $self->success;

    if (!$ok) {
        FATAL "Could not login - $desc";
        $self->builder->ok($ok, $desc);
        $self->builder->diag("Failed to log in");
        $self->builder->diag( $self->status );
        $self->builder->diag( $self->response->message ) if $self->response;
        return $ok;
    }

    my ($found) = $self->find_xpath("//h1[text() = 'Login']");

    if ($found) {
        my ($err) = $self->app_error_message;
        if ( $err ) {
            $self->builder->diag("Error was $err")
        } else {
            if ( $tries ) {
                $self->builder->diag("*** Login failed, without saying why. Trying once more...");
                $tries--;
                goto LOGINPROCESS;
            } else {
                $self->builder->diag("*** RUH ROH. We couldn't log in, and it's not obvious why.");
                $self->builder->diag("*** This is when we'd normally show you the output of");
                $self->builder->diag("*** error_msg ... but there isn't one! :-/");
                $self->builder->diag("*** Content of the last page return to follow:");
                $self->builder->diag($self->content());
                fail("Couldn't log in");
                die "Couldn't login";
            }
        }
    }
    ok(!$found, $desc );

    $self->logged_in_as($user);
    return !$found;
}

=head2 logged_in_as_object

Return the Operator row for the logged in user, via C<logged_in_as>

=cut

sub logged_in_as_object {
    my $self = shift;
    my $username = $self->logged_in_as
        || die "logged_in_as() doesn't return a username";
    return Test::XTracker::Data->_get_operator($username);
}

=head2 logged_in_as_logname

Returns the name for the logged-in user that we should expect to find in the
logs.

=cut

sub logged_in_as_logname {
    my $self = shift;
    my $user = $self->logged_in_as_object;
    return $user->name;
}

=head2 handheld_login_ok

 $mech->handheld_login_ok($user, $pass, $msg?)

Attempts to login to the Hand Held version of xTracker using the given
credentials (after hitting '/Logout?view=HandHeld').

=cut

sub handheld_login_ok {
    my ($self, $user, $pass, $desc)     = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $desc = "login as '$user'" if not defined $desc;

    $self->get('/Logout?view=HandHeld');
    my $ok = $self->success;

    if (!$ok) {
        $self->builder->ok($ok, $desc);
        $self->builder->diag("Failed to get /Logout?view=HandHeld");
        $self->builder->diag( $self->status );
        $self->builder->diag( $self->response->message ) if $self->response;
        return $ok;
    }

    unless ( $self->find_xpath("//label[text() =~ /Username/ ]") && $self->find_xpath("//label[text() =~ /Password/ ]") ) {
        fail($desc);
        $self->builder->diag("We dont appear to be on the login page");
        return 0;
    }

    $self->submit_form(
        with_fields => {
            password => $pass,
            username => $user
        },
    );
    $ok = $self->success;

    if (!$ok) {
        $self->builder->ok($ok, $desc);
        $self->builder->diag("Failed to get /Logout?view=HandHeld");
        $self->builder->diag( $self->status );
        $self->builder->diag( $self->response->message ) if $self->response;
        return $ok;
    }

    my ($found) = $self->find_xpath("//h1[text() = 'Login']");

    ok(!$found ,$desc);
    if ($found) {
      my ($err) = $self->find_xpath('//p[@class="error_msg"]');
      $self->builder->diag("Error was $err") if $err;
    }

    $self->content_contains( 'body class="handheld"', "Logged into Hand Held Version" );

    return !$found;
}

=head2 handheld_home

 $mech->handheld_home()

Goes to /HandHeld/Home

=cut

sub handheld_home {
    my ($self) = @_;

    $self->get_ok('/HandHeld/Home');

}

=head2 setup_and_login

 $mech->setup_and_login( {
    auth => $auth,
    dept => $dept,
    perms => $perms,
    roles => $roles,
} );

Applies the dept and perms/roles to the user, which defaults to it.god if not set
and then logins through mechanize

=cut

sub setup_and_login {
    my($self,$opts) = @_;
    my $auth    = delete $opts->{auth};
    my $dept    = delete $opts->{dept};
    my $perms   = delete $opts->{perms};
    my $roles   = delete $opts->{roles};

    # clear out any Session as when we
    # Log In it will be a different one
    $self->clear_session;

    $auth = $self->setup_user({
        auth    => $auth,
        dept    => $dept,
        perms   => $perms,
        roles   => $roles,
    });

    note 'Starting login';
    $self->do_login($auth->{user});
    note 'Done trying to login';

    if ( $roles ) {
        # now the user is Logged In and there is a
        # Session available, set the Operator's Roles
        my $session = $self->session->get_session;
        $session->{acl}{operator_roles} = $auth->{operator_roles};
        $self->session->save_session;

        # because setting the Session has to happen after Login need to go
        # to '/Home' so as to re-draw the page with the proper Main Nav
        $self->get('/Home');
    }

    return $self;
}

=head2 has_feedback_error_ok

 $mech->has_feedback_error_ok(qr/MESSAGE HERE/, $test_msg?);

Test for presensce of an error like C<< E<lt>p class="feedback-warning"E<gt>MESSAGE
HEREE<lt>/pE<gt> >>.

=cut

sub has_feedback_error_ok {
    shift->_test_feedback_element('error_msg', 0, @_);
}


=head2 no_feedback_error_ok

 $mech->no_feedback_error_ok($test_msg?);

Tests for lack of feedback errors. If any are found they are displayed in a
diag.

=cut

sub no_feedback_error_ok {
    my ($self, $msg) = @_;
    $msg ||= "Got no feedback errors";
    shift->_test_feedback_element('error_msg', 1, '', $msg);
}

=head2 has_feedback_success_ok

 $mech->has_feedback_success_ok(qr/MESSAGE HERE/, $test_msg?);

Like L</has_feedback_error_ok>, but tests for success message rather than
error.

=cut

sub has_feedback_success_ok {
    my $self = shift;

    $self->_test_feedback_element('display_msg', 0, @_)
    or do {
      my $err = $self->_get_feedback_element('error_msg');
      diag "Feedback Error of: $err" if $err;
      return 0;
    }
}

=head2 has_feedback_info_ok

 $mech->has_feedback_info_ok(qr/MESSAGE HERE/, $test_msg?);

Like L</has_feedback_error_ok>, but tests for info message rather than
error.

=cut

sub has_feedback_info_ok {
    my $self = shift;

    $self->_test_feedback_element('info', 0, @_)
    or do {
      my $err = $self->_get_feedback_element('error_msg');
      diag "Feedback Error of: $err" if $err;
      return 0;
    }
}

sub _get_feedback_element {
    my ($self, $css) = @_;

    my $set = $self->find_xpath("//p[\@class='$css']");
    return $self->_strip_ws($set->string_value);
}

sub _test_feedback_element {
    my ($self, $css, $negate, $test, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 2;

    $msg ||= "Got feedback $css of '$test'";
    my $set = $self->find_xpath("//p[\@class='$css']");

    if (!$negate && $set->size == 0) {
        Test::More::diag("Unable to find a single HTML P element with CSS class of '$css'");
        Test::More::diag("This usually means you were looking for feedback, and it wasn't produced");
        Test::More::diag("Test was looking for: [$test] in [" . $self->uri . "]");
        Test::More::fail($msg);
        return 0;
    }
    my $value = $set->to_literal;

    my $func;
    if (ref($test) && ref($test) eq 'Regexp') {
        $func = Test::More->can($negate ? 'unlike' : 'like');
    }
    elsif ($test eq '' && $negate) {
        $func = Test::More->can('is');
    }
    else {
        $func = Test::More->can($negate ? 'isnt' : 'is');
    }

    my $test_result = $func->($value, $test, $msg);

    if (!$test_result) {
        $self->builder->diag("Expected: $test\n    Got: $value");
    }

    return $test_result;
}

=head2 order_view_url_for_order_nr

Given an order_nr (not an order B<id>) will search for the order via the order
search page, and return the uri of the order status page.

=cut

sub order_view_url_for_order_nr {
    my ($self, $order_nr) = @_;

    $self->get_ok('/CustomerCare/OrderSearch');

    $self->submit_form_ok({
      form_name => 'searchForm',
      with_fields => {
        search_term => $order_nr,
        search_type => 'order_number'
      }
    }, "search for order");
    TRACE "About to follow link to order num $order_nr";
    $self->follow_link_ok({text => $order_nr}, "Found link to order");
    return $self->uri;
}

=head2 order_search_by_any_type

 $mech  = $mech->order_search_by_any_type( $search_type, $search_term );

This will search for an order based on any search type in the 'Free Search'
section on the 'Customer Care -> Order Search' page. It will return the search
results page and wont follow any links to the order.

=cut

sub order_search_by_any_type {
    my ( $self, $type, $term )  = @_;

    $self->get_ok('/CustomerCare/OrderSearch');

    $self->submit_form_ok({
      form_name => 'searchForm',
      with_fields => {
        search_type => $type,
        search_term => $term,
      }
    }, "Search for an Order By: Type - $type, Value - $term");
    $self->no_feedback_error_ok;

    return $self;
}

=head2 test_select_order

 $mech->test_select_order($section = 'Staff', $shipment_id)

Test. Look for the given shipment on the Fulfilment -> Selection page, in the
given C<$section>, send it for picking, and check that the order status (on the
page) has changed to Processing.

=cut

sub test_select_order {
    my($self,$category,$ship_nr) = @_;

#    LOGCONFESS "Not sure where order category '$category' is"
#      unless $category eq 'Staff';

    #
    # Get the link to the ticky box for 'Send for Picking'
    $self->test_check_and_submit_shipment($ship_nr);

    #
    # Check that (Shipment) Status: (not Order Status:) changes to Processing
    #
    $self->get_ok($self->order_view_url);
    is($self->get_table_value('Status:'), "Processing", "Shipment is now being processed");

    return $self;
}

=head2 test_direct_select_shipment

    $mech->test_direct_select_shipment( $ship_nr );

This selects a shipment by skipping the initial selection screen and going to
the screen with the list of shipment id's and then selects the shipment from
there.

=cut

sub test_direct_select_shipment {

    my ( $self, $ship_nr )  = @_;


    #
    # Get the link to the ticky box for 'Send for Picking' and submit
    #
    $self->test_check_and_submit_shipment($ship_nr);

    #
    # Check that (Shipment) Status: (not Order Status:) changes to Processing
    #
    $self->get_ok($self->order_view_url);

    # Then find the table for the shipment we want, so we dont barf then there
    # are 2 shipments on this order (original + exchange for example)
    my $xpath_context = $self->find_xpath(
        qq{//*[contains(text(),'Shipment Number')]/ancestor::table/descendant::td[contains(text(), '$ship_nr')]/ancestor::table}
    )->get_node(0);

    is($self->get_table_value('Status:', $xpath_context), "Processing", "Shipment is now being processed");

    return $self;
}

sub test_check_and_submit_shipment {

    my ( $self, $ship_nr )  = @_;

    my $previous_datalite = $self->force_datalite();
    $self->force_datalite(0);

    if ( config_var('PRL', 'rollout_phase') > 0 ) {
        # Make sure shipment is allocated ready for selection
        my $shipment = Test::XTracker::Data->get_schema->resultset('Public::Shipment')
            ->find( $ship_nr );
        Test::XTracker::Data::Order->allocate_shipment($shipment);
    }

    # if auto-selection is enabled, we can't use the form
    my $auto_select = sys_param('fulfilment/selection/enable_auto_selection');
    if ($auto_select) {
        # auto_selection - invoke the script code directly
        my $auto_select_result = XTracker::Script::Shipment::AutoSelect->new->invoke(
            shipment_ids => [ $ship_nr ],
        );
        ok !$auto_select_result, "should auto-select shipment $ship_nr";
    } else {
        # manual selection
        $self->get_ok('/Fulfilment/Selection');

        $self->content_like( qr{Shipment Number} )
            or die 'You probably forgot to give your user access to Fulfilment/Selection';

        # new shipment most likely to be on first or last page
        my $input = $self->find_xpath( qq{
                //a[contains(text(), '$ship_nr')]/ancestor::tr//input
            })->get_node(0);

        unless ($input) {
            $self->follow_link( text => 'Last');

            while (!$input) {
                $input = $self->find_xpath( qq{
                    //a[contains(text(), '$ship_nr')]/ancestor::tr//input
                })->get_node(0);
                unless ($input) {
                    last unless $self->find_link( text => 'Previous');
                    note "Getting previous page of shipments";
                    $self->follow_link( text => 'Previous');
                } else { note "Found checkbox for shipment_id $ship_nr"; }
            }
        }

        ok($input, "Found checkbox for selecting shipment number $ship_nr") or exit;

        $self->force_datalite( $previous_datalite );

        my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
        $self->submit_form_ok({
            with_fields => { $input->attr('name') => 1, },
            button => 'submit'
        }, "Select shipment");
        $xt_to_wms->expect_messages({
            messages => [ { type => 'shipment_request'}, ]
        });
        $self->has_feedback_success_ok( qr/\d+ shipment successfully selected/ );
    }

    #
    # Check that (Shipment) Status: (not Order Status:) changes to Processing
    #
    $self->get_ok($self->order_view_url);

    # Then find the table for the shipment we want, so we dont barf then there
    # are 2 shipments on this order (original + exchange for example)
    my $xpath_context = $self->find_xpath(
        qq{//*[contains(text(),'Shipment Number')]/ancestor::table/descendant::td[contains(text(), '$ship_nr')]/ancestor::table}
    )->get_node(0);
    # Note: the old xpath was shorter, but didn't work (you got the statuses for all
    # shipments on the page), it looked like this:
    # qq{//tr[td[.='Shipment Number:'] and td[trim(.) = '$ship_nr']]/ancestor::table}
    #
    # The old old xpath did work, but (I'm guessing this was why it was changed) not
    # with the blank db, it looked like this:
    # q{//*[contains(text(), '$ship_nr')]/ancestor::table}
    #
    # You may find the above versions useful to work from when it turns out that my
    # attempt is also broken in some new and exciting way.

    is($self->get_table_value('Status:', $xpath_context), "Processing", "Shipment is now being processed");

    return $self;

}

sub _get_table_value_set {
    my ($self, $context, $xpath_fmt, $heading) = @_;

    my $find_on = $context || $self;

    my $set = $find_on->find_xpath(sprintf($xpath_fmt, $heading));

    # Not found, try replacing ' ' with &nbsp (\u00a0);
    if ($set->size == 0) {
      $heading =~ s/ /\xA0/g;
      $set = $find_on->find_xpath(sprintf($xpath_fmt, $heading));
    }
    return $set;
}

# Helper method to examine DC's tables
sub get_table_value {
    my ($self,$heading, $context) = @_;

    my $xpath_fmt = qq{
      .//*[starts-with(text(), '%s')]
      /ancestor::td
      /following-sibling::td[1]
    };

    my $set = $self->_get_table_value_set($context, $xpath_fmt, $heading);

    my $value = $set->to_literal;
    return $self->_strip_ws($value);
}

# As get_table_value above, but expects/copes with more than
# one match, returns arrayref of values
sub get_table_values {
    my ($self,$heading, $context) = @_;

    my $xpath_fmt = qq{
      .//*[starts-with(text(), '%s')]
      /ancestor::td
      /following-sibling::td[1]
    };

    my $set = $self->_get_table_value_set($context, $xpath_fmt, $heading);

    my @values;
    while (my $node = $set->shift) {
        my $value = $node->as_text;
        push @values, $self->_strip_ws($value);
    }
    return \@values;
}

=head2 get_table_row

    my @arr = $mech->get_table_row( $value );

This gets all following columns in a table to the one that contains the 'value'.
Used to get information out of a table where an id maybe the first column will
return all other columns data in that row.

=cut

sub get_table_row {
    my ( $self, $value )    = @_;

    my $xpath_fmt = qq{
      .//td[. =~ '%s']
      /following-sibling::td
    };

    my $row = $self->_get_table_value_set($self, $xpath_fmt, $value);

    if ( defined $row ) {
        return fix_encoding($row->string_values())
    }
    else {
        return;
    }
}

sub get_table_row_by_xpath {
    my ( $self, $xpath, $value )    = @_;

    my $row = $self->_get_table_value_set($self, $xpath, $value);

    if ( defined $row ) {
        return fix_encoding($row->string_values())
    }
    else {
        return;
    }
}

=head2 table_to_hashref

    my $table = $mech->table_to_hashref('//table[@class = "someclass"]');

This returns table data as an array of hashes. Strips out divider rows.

=cut

sub table_to_hashref {
    my ($self, $table) = @_;

    unless (ref $table) {
        ($table) = $self->find_xpath( $table )->get_nodelist;
    }

    my $set = $table->find_xpath( q{//thead//td[@class =~ 'tableHeader']|//thead//th} );

    my %map = ();
    for my $n ( $set->get_nodelist ) {
        $map{$n->pindex} = $self->_strip_ws( $n->as_text );
    }

    my $ret = [];
    $set = $table->find_xpath( q{//tbody/tr} );
    for my $r ( $set->get_nodelist ) {
        my $row = {};
        for my $td ( $r->find_xpath('.//td[not(contains(@class, "divider"))]')->get_nodelist ) {
            $row->{ $map{$td->pindex} } = $self->_strip_ws( $td->as_text );
        }
        push @$ret, $row if keys %$row;
    }

    return $ret;
}

=head2 get_order_skus

 $mech->get_order_skus;

Will hit the url returned by L</order_view_url_for_order_nr> and extract the
SKUs that are part of the order.

Returns a hash of

 { $sku1 => {}, $sku2 => {} }

=cut

sub get_order_skus {
    my($self) = @_;
    $self->get_ok($self->order_view_url)
      if ($self->uri ne $self->order_view_url);

    my $set = $self->find_xpath(q{
      //*[text() = 'Shipment Items']
       /following-sibling::table[1]
      //td[text() =~ /\d+-\d+/]
    });

    # Eventually we'll want other info in this hash, for now its empty
    return {
      map { $self->_strip_ws($_) => {} } fix_encoding($set->string_values)
    };
}

=head2 get_info_from_picklist

 $skus = $mech->get_order_skus(
    $test_xtracker_printdocs,
    {
        '0123456-123' => {},
        '2345678-456' => {}
    }
 );

Accepts a L<Test::XTracker::PrintDocs> object, and a hashref of keys which are
SKUs, and values which are hashrefs. Returns the hashref with a 'location' key
for each SKU:

 {
   $sku1 => { location = "some location" }
   $sku2 => { location = "other location" }
 }

=cut

# We now (2010-Oct-04) require a PrintDocs object incoming on this method. This
# method was an Ash original from back in the day, and makes the now incorrect
# assumption that a request that generates a printer document does so instantly.
# In fact, we may have to wait. We do that waiting using
# Test::XTracker::PrintDocs's wait_for_new_files() method. If you're porting an
# old routine over to this, set up the PrintDocs object BEFORE the request that
# generates the picking list.

sub get_info_from_picklist {
    my ($self, $print_docs, $skus) = @_;

    if ( config_var('IWS', 'rollout_phase') > 0 ) {
        return { map { $_ => 'IWS' } keys %$skus }
    }

    unless ( $print_docs &&
        $print_docs->$_isa('Test::XTracker::PrintDocs') ) {
        confess "This function now requires a Test::XTracker::PrintDocs"
              . "object. See the documentation in Test::XTracker::Mechanize"
              . "near get_info_from_picklist() for details";
    }


    my ($picking_sheet) = grep {
        $_->file_type eq 'pickinglist'
    } $print_docs->wait_for_new_files();
    croak "No picking sheet found" unless $picking_sheet;

    # Map SKUs to location
    my %location_by_sku = map { $_->{'SKU'} => $_->{'Location'} }
        # Reverse so we're bug-compliant with how this used to work...
        reverse @{ $picking_sheet->as_data->{'item_list'} };

    for my $sku (keys %$skus) {

        ok( $location_by_sku{ $sku }, "Got a location row for $sku ($location_by_sku{ $sku })");
        $skus->{$sku}->{'location'} = $location_by_sku{ $sku };

    }

    return $skus;
}

=head2 get_info_from_sticker

Accepts a L<Test::XTracker::PrintDocs> object, and a sticker text value.
Returns sticker or nothing;

=cut

sub check_sticker {
    my ($self, $print_docs, $text ) = @_;

    unless ( $print_docs &&
        $print_docs->$_isa('Test::XTracker::PrintDocs') ) {
        confess "This function now requires a Test::XTracker::PrintDocs"
              . "object. See the documentation in Test::XTracker::Mechanize"
              . "near get_info_from_picklist() for details";
    }

    my ($sticker) = grep {
        $_->file_type eq 'sticker'
    } $print_docs->wait_for_new_files();

    croak "No sticker found" unless $sticker;

    note $sticker;

    contains($sticker,$text,"Sticker text contains orders sticker text");

    return $sticker;
}

=head2 test_pick_shipment

 $Mech->test_pick_shipment($shipment_id, \%skus)

Tests the Fulfilment -> Picking workflow. C<\%skus> is populated by
L</get_order_skus>.

=cut

sub test_pick_shipment {
    my ($self, $ship_nr, $skus) = @_;

    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 });

    if ( config_var('IWS', 'rollout_phase') ) {
        my $framework = Test::XT::Flow->new_with_traits(
            traits => ['Test::XT::Flow::WMS'],
            mech   => $self
        );

        $framework->flow_wms__send_picking_commenced(
            Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find($ship_nr)
        );

        # Fake a ShipmentReady from IWS emulating what previously was picking
        $framework->flow_wms__send_shipment_ready(
            shipment_id => $ship_nr,
            container => { $container_id => [ map { $_ } keys %$skus ] },
        );
        return $self;
    }

    if ( config_var('PRL', 'rollout_phase') > 0 ) {
        my $framework = Test::XT::Flow->new_with_traits(
            traits => ['Test::XT::Flow::PRL'],
            mech   => $self
        );

        # Fake a ShipmentReady from IWS emulating what previously was picking
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $ship_nr,
            container => {
                $container_id => [ map { $_ } keys %$skus ]
            },
        );
        $framework->flow_msg__prl__induct_shipment( shipment_id => $ship_nr );
        return $self;
    }

    $self->get_ok('/Fulfilment/Picking');
    note "shipment_id: $ship_nr";
    note $self->uri;
    $self->submit_form_ok({
        form_name => 'pickShipment',
        with_fields => {
        shipment_id => $ship_nr,
        },
        button => 'submit'
    }, "Pick shipment");

    for my $sku ( keys %$skus) {
        note $self->uri;
        $self->submit_form_ok({
        with_fields => {
            location => $skus->{$sku}{location}
        },
        button => 'submit'
        }, "Location for $sku:" . $skus->{$sku}{location});

        if ( my $error = $self->app_error_message ) {
        die $error;
        }

        $self->submit_form_ok({
        with_fields => {
            sku => $sku
        },
        button => 'submit'
        }, "Sku $sku");

        $self->submit_form_ok({
        with_fields => {
            container_id => $container_id->as_barcode
        },
        button => 'submit'
        }, "Picked into container " . $container_id->as_barcode);

        # Perpertual inventory! - fill it out.
        # The while is here because if the count doesn't match it asks you to count again
        my $perp_count=0;
        note $self->uri;
        while ( scalar $self->find_all_inputs(name=>'input_value') ) {
            $self->submit_form_ok({
                with_fields => { input_value => 1 },
                button => 'submit'
            }, sprintf 'Perpertual Inventory for location %s - loop %i',
                $skus->{$sku}{location}, ++$perp_count
            );
        }
    }
    return $self;
}

=head2 test_pack_shipment

 $Mech->test_pack_shipment($shipment_id, \%skus, \@voucher_codes?)

Tests the Fulfilment -> Packing workflow. C<\%skus> is populated by
L</get_order_skus>.

Will pack the shipment into "Black Box New 3" and will generate a random airway
bill number.

If DC2 also ensures that a print station is assigned

If \@voucher_codes is passed, expect there to be physical vouchers
that need scanning before going on to packing.

=cut

sub test_pack_shipment {
    my ($self, $shipment_id, $skus, $voucher_codes) = @_;

    # I have killed this with fire, and out of the ashes rises a beautiful and
    # considerably less fragile phoenix! -PS
    my $framework = Test::XT::Flow->new_with_traits(
        traits => ['Test::XT::Flow::Fulfilment'],
        mech   => $self
    );
    my $former_datalite = $framework->force_datalite();
    $framework->force_datalite(1);

    # Start packing the shipment
    # Packing page
    $framework->flow_mech__fulfilment__packing;

    my $channel = Test::XTracker::Data->get_schema->resultset('Public::Shipment')
        ->find( $shipment_id )->get_channel;

    # check we have a packing station selected if required
    my $packing_station_link = $self->find_link( text_regex => qr/Set Packing Station/ );

    if ($packing_station_link){
        # Taking in consideration that the dropdown contains all the
        # packing stations for all channels, we need to select the
        # packing station for the current channel
        my $packing_station = XTracker::Config::Local::get_packing_stations( $self->schema, $channel->id )->[0]
            or die (sprintf('Packing stations missing for channel: %s', $channel->name) );

        $self->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station'" );
        $self->form_name("setPackingStation");
        $self->select('ps_name', $packing_station);
        $self->submit_form_ok({ form_number => 2, button => 'submit', }, 'Select a Packing Station');
    }

    if($voucher_codes) {
        # If packing physical vouchers, choose this shipment
        # ... but expect to need to scan the voucher codes first
        $framework->flow_mech__fulfilment__packing_with_physical_vouchers_submit(
            $shipment_id,
        );

        for my $voucher_code (sort @$voucher_codes) {
            $framework->flow_mech__fulfilment__packqc_voucher_code_submit(
                $voucher_code,
            );
            $framework->mech->content =~ /QC'ing Now Complete/ and last;
        }
        $framework->mech->content =~ /QC'ing Now Complete/ or die("After scanning all (" . scalar(@$voucher_codes) . ") provided voucher codes, the QC is still not Complete. You probably need to provide more voucher codes.\n");
        $framework->flow_mech__fulfilment__packing_packqc_continue();
    }
    else {
        # No vouchers, just choose this shipment
        $framework->flow_mech__fulfilment__packing_submit( $shipment_id );
    }

    # QC pass the items
    $framework->flow_mech__fulfilment__packing_checkshipment_submit();

    # Pack the items
    my @voucher_codes = @{ $voucher_codes || [] };
    for my $sku (sort keys %$skus) {
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );

        # If "Gift Card Code" on the page, find a voucher code and
        # submit it
        if($self->content =~ /Gift Card Code:/sm) {
            $framework->flow_mech__fulfilment__packing_packshipment__submit_gift_card_code(
                shift(@voucher_codes),
            );
        }
    }

    my $box_ids = Test::XTracker::Data->get_inner_outer_box( $channel->id );
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            inner => $box_ids->{inner_box_id},
            outer => $box_ids->{outer_box_id},
        );

    # Choose if we need an airway bill. Lifted from previous code, that had
    # comment "don't need airway bill for UPS shipments (which are on DC2)"
    Test::XT::Rules::Solve->solve(
        'XTracker::Mechanize::AirwayBill' => {
            framework => $framework,
            mechanize => $self
        }
    );

    $framework->flow_mech__fulfilment__packing_packshipment_complete;
    $framework->force_datalite( $former_datalite );
    return $self;
}

=head2 test_cancel_order

 $mech->test_cancel_order

=cut

sub test_cancel_order {
    my ($self) = @_;

    $self->get_ok($self->order_view_url);

    $self->follow_link_ok({ text_regex => qr/Cancel Order/ }, "Going to cancel order");


    $self->submit_form_ok({
        with_fields => {
            cancel_reason_id => 25, # found item somewhere else cheaper
        },
        button => 'submit'
    }, 'Select reason');
    $self->no_feedback_error_ok;


    $self->submit_form_ok({
        with_fields => {
            send_email => "yes",
        },
        button => 'submit'
    }, 'Cancel it!');

    $self->no_feedback_error_ok;


    is($self->get_table_value('Order Status:'), "Cancelled", "Order is cancelled");

    return $self;
}


=head2 test_size_change_order

 $mech->test_size_change_order

=cut

sub test_size_change_order {
    my ($self,$order) = @_;

    $self->get_ok($self->order_view_url);

    $self->follow_link_ok({ text_regex => qr/Size Change/ }, "Going to change size order");


    my $shipment = undef;
    ok( $shipment = $order->shipments->first, "order has a shipment");

    my $item = $shipment->shipment_items->first;
    my $name = 'exch-'. $item->id;
    my $current_sku = $item->variant->sku;

    $self->form_with_fields($name);

    # Find possible replacements
    my @poss = grep {
            my ( $variant_id, $desc, $sku ) = split(/_/, $_);
            $sku ne $current_sku;
        }
        # I have no idea why this interpolates "0"s in to the list, but we need
        # to nuke them...
        grep { $_ ne "0" }
        $self->current_form->find_input($name)->possible_values;

    die "No alternative variants we can use to change size for, in " .
        "test_size_change_order. As of 30-Oct-2012, this method has been " .
        "to actually work. If your calling test is failing, make sure your " .
        "call to grab_products includes something like: how_many_variants => 2, " .
        "ensure_stock_all_variants => 1"
        unless @poss;

    my $fields = {
        'exch-'. $item->id => $poss[0], #variant_id
        'item-'. $item->id => 1,
    };

    $self->submit_form_ok({
        with_fields => $fields,
    }, 'Select size change');


    $self->submit_form_ok({
        with_fields => {
            'send_email' => 'yes',
        },
        button => 'submit',
    }, 'Send email');

    $self->has_feedback_success_ok( qr/Size change completed successfully/,
    'Found success message');

    return $self;
}

=head2 test_exchange_size_change_order

 $mech->test_exchange_size_change_order

=cut

sub test_exchange_size_change_order {
    my ($self,$order,$return) = @_;

    $self->get_ok($self->order_view_url);

    $self->follow_link_ok({ text_regex => qr/Size Change/ }, "Going to change size order");


    my $shipment = undef;
    ok( $shipment = $order->shipments->search( { 'me.shipment_id' => $return->exchange_shipment_id } )->first, "Exchange shipment found");
    my $exch_ship_id    = $shipment->id;

    my $ship_items_rs   = $shipment->shipment_items->search( undef, { order_by => 'me.id DESC' } );
    my $item_to_change  = $return->return_items->first->exchange_shipment_item;
    note "Shipment Item Id to Change: ".$item_to_change->id;

    $self->follow_link_ok({ text_regex => qr/$exch_ship_id/ }, "Picking Exchange Shipment to Change Size for" );

    my $name = 'exch-'. $item_to_change->id;
    $self->form_with_fields($name);
    my @poss = grep {
        $_ ne "0"
    } $self->current_form->find_input($name)->possible_values;

    my $fields = {
        'exch-'. $item_to_change->id => $poss[0], #variant_id
        'item-'. $item_to_change->id => 1,
    };

    $self->submit_form_ok({
        with_fields => $fields,
    }, 'Select size change');


    $self->submit_form_ok({
        with_fields => {
            'send_email' => 'yes',
        },
        button => 'submit',
    }, 'Send email');

    $self->no_feedback_error_ok;
    $self->has_feedback_success_ok( qr/Size change completed successfully/ );

    #
    # check the DB side is ok
    #
    $return->discard_changes;
    $shipment->discard_changes;
    $item_to_change->discard_changes;
    $ship_items_rs->reset();

    # item changed should be cancelled
    cmp_ok( $item_to_change->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Item that was changed is now 'Cancelled'" );

    # should have a new item diff from previous and status set to new
    my $new_item    = $ship_items_rs->first;
    note "New Shipment Item Id: ".$new_item->id;
    cmp_ok( $new_item->id, '>', $item_to_change->id, "New Shipment Item found" );
    cmp_ok( $new_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW, "New Item Status is 'New'" );

    # check that the 'exchange_item_id' field on the return item record now points
    # to the new shipment item.
    my $exch_item   = $return->return_items->first->exchange_shipment_item;
    cmp_ok( $exch_item->id, '==', $new_item->id, "Original Returned Item's Exchange Id now points to New Shipment Item" );

    # count that the value in the 'exchange_shipment_item_id' field
    # is only present in one record because there was a bug once
    # where it populated all the records with a null value
    my $schema  = $return->result_source->schema;
    my $chk     = $schema->resultset('Public::ReturnItem')->count( { 'me.exchange_shipment_item_id' => $new_item->id } );
    cmp_ok( $chk, '==', 1, "Value in 'exchange_shipment_item_id' field only appears in one record" );

    return $self;
}


=head2 test_cancel_order_item

 $mech->test_cancel_order_item

=cut

sub test_cancel_order_item {
    my ( $self, $order, $expect_cancel_pending, $si_id ) = @_;

    $self->get_ok($self->order_view_url);

    $self->follow_link_ok({ text_regex => qr/Cancel Shipment Item/ }, "Going to cancel shipment item");


    my $shipment = undef;
    ok( $shipment = $order->shipments->first, "order has a shipment");

    my $items = $shipment->shipment_items;
    my $item = undef;

    if ($si_id and $items) {
        do {
            $item = $items->next;
        } while (defined $item and $item->id != $si_id);
        note "shipment_item_id: ". $si_id;
    } else {
        $item = $items->next;
    }

    ok($item , "we have the shipment item");

    $item->discard_changes;

    my $name = 'reason-'. $item->id;
#    $self->form_with_fields($name);
#    my @poss = grep {
#        $_ ne "0"
#    } $self->current_form->find_input($name)->possible_values;
#

    my $fields = {
        'reason-'. $item->id    => 25, # customer found it cheaper elsewhere
        'item-'. $item->id      => 1, # select it
        'refund_type_id'        => $RENUMERATION_TYPE__STORE_CREDIT,
    };

    $self->submit_form_ok({
        with_fields => $fields,
        button => 'submit',
    }, 'Select item to cancel');
    $self->no_feedback_error_ok;

    $self->submit_form_ok({
        with_fields => { 'send_email' => 'yes', },
        button => 'submit',
    }, 'Send email');

    $self->no_feedback_error_ok;

    $item->discard_changes;

    if ($expect_cancel_pending) {
        ok( $item->is_cancel_pending, 'Item status changed to cancel pending')
            or diag sprintf q{item '%i' status changed to %s},
                $item->id, $item->shipment_item_status->status;
    } else {
        ok( $item->is_cancelled, 'Item status changed to cancelled')
            or diag sprintf q{item '%i' status changed to %s},
                $item->id, $item->shipment_item_status->status;
    }

    return $self;
}

=head2 test_assign_airway_bill

 $mech->test_assign_airway_bill($shipment_id)

Tests that the Fulfilment -> Allocate Airwaybill works by generating a random
AWB number.

=cut

sub test_assign_airway_bill {
    my ($self,$ship_nr) = @_;

    my $dc_name = config_var('DistributionCentre','name');
    my $shipment    = Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find( $ship_nr );

    # Select a printer so we don't get redirected here and cause a test
    # failure when we try and get '/Fulfilment/Airwaybill'
    $self->get_ok('/Fulfilment/Airwaybill');

    $self->select_printer_station()
        if $self->find_xpath(q{//form[@name='SelectPrinterStation']})->size;

    $self->submit_form_ok({
      with_fields => {
        shipment_id => $ship_nr,
      },
      button => 'submit'
    }, "Adding airway bill");
    $self->no_feedback_error_ok;

    # This *would* normally try to print the dispatch note.
    # Its been stubbed out by the test server
    my ( $out_awb ) = Test::XTracker::Data->generate_air_waybills;

    my $form = $self->form_with_fields('out_airway');

    # Fill in which ever of the AWBs are needed.
    my $fields;
    $fields->{out_airway} = $out_awb unless $form->value('out_airway');
    if ( !$shipment->display_shipping_input_warning ) {
        $fields->{ret_airway} = $out_awb unless $form->value('ret_airway');
    }

    $self->submit_form_ok({
      with_fields => $fields,
      button => 'submit'
    }, "Added airway bill");
    $self->no_feedback_error_ok;
    $self->has_feedback_success_ok(qr/Shipping paperwork printed\./) or do {

      $form = $self->form_with_fields('out_airway');
      map { note "$_: " . $form->value($_)} qw/out_airway ret_airway/;
    };
    return $self;
}

=head2 test_labelling

 $mech->test_labelling($shipment_id)

Tests that the Fulfilment -> Labelling works using the box id created
from test_pack_shipment.

=cut

sub test_labelling {
    my ($self,$ship_nr) = @_;

    # Don't bother with this if the DC doesn't have this section enabled
    return $self unless config_var('Fulfilment', 'labelling_subsection');

    my $shipment    = Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find( $ship_nr );
    my $box_id      = $shipment->shipment_boxes->first->id;

    $self->get_ok('/Fulfilment/Labelling');

    $self->submit_form_ok({
      with_fields => {
        box_number => $box_id,
      },
      button => 'submit'
    }, "Printing Labels for box $box_id");
    $self->no_feedback_error_ok;

    ok( $self->content =~ qr/Box Number:.*$box_id/,
        "Shipment Labelled for box $box_id");

    return $self;
}

=head2 test_label_without_dhl_code

 $mech->test_label_without_dhl_code($shipment_id)

Tests that the Fulfilment -> Labelling does not work when trying to dispatch
a shipment without a valid DHL code.

Only useful for DC1

=cut

sub test_label_without_dhl_code {
    my ($self,$ship_nr) = @_;

    # Don't bother with this if the DC doesn't have this section enabled
    return $self unless config_var('Fulfilment', 'labelling_subsection');

    my $shipment    = Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find( $ship_nr );
    my $box_id      = $shipment->shipment_boxes->first->id;

    $self->get_ok('/Fulfilment/Labelling');

    $self->submit_form_ok({
      with_fields => {
        box_number => $box_id,
      },
      button => 'submit'
    }, "Printing Labels with no DHL code");
    $self->has_feedback_error_ok(qr/does not have a valid DHL Destination Code/);

    return $self;
}

=head2 test_labelling_with_no_return_docs

 $mech->test_labelling_with_no_return_docs($shipment_id)

Tests that the Fulfilment -> Labelling works using the box id created
and that the correct no returns documentation banner is displayed
because the shipment is non-returnable.

Only useful for DC1

=cut

sub test_labelling_with_no_return_docs {
    my ($self,$ship_nr) = @_;

    my $shipment    = Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find( $ship_nr );
    my $box_id      = $shipment->shipment_boxes->first->id;

    $self->get_ok('/Fulfilment/Labelling');

    $self->submit_form_ok({
      with_fields => {
        box_number => $box_id,
      },
      button => 'submit'
    }, "Printing Labels for box $box_id for non-returnable shipment");
    $self->no_feedback_error_ok;

    ok( $self->content =~ qr/Box Number:.*$box_id/,
        "Shipment Labelled for box $box_id");

    ok( $self->content =~ qr/Returns documentation will not be printed for this shipment as all shipment items are non-returnable/,
         "Displayed message that no returns documentation will be printed" );

    return $self;
}

=head2 create_manifest

 $manifest_id = $mech->create_manifest( $carrier, { check_feedback_error => 1 } );

This creates a manifest for a carrier and returns the newly created
Manifest Id.

If check_feedback_error is true, check no_feedback_error_ok.

=cut

sub create_manifest {
    my ( $self, $carrier, $option )  = @_;
    $option //= {};
    $option->{check_feedback_error} //= 1;

    my $schema  = Test::XTracker::Data->get_schema;
    my $carrier_id = $schema->resultset('Public::Carrier')
                                ->search( { name => $carrier } )
                                    ->first->id;
    my @channel_ids = $schema->resultset('Public::Channel')
                                ->search()
                                    ->get_column('id')->all();

    $self->get_ok('/Fulfilment/Manifest');

    # This is the only way to set the channel_id field with multiple values
    $self->form_name('manifestForm');
    $self->field('channel_id', \@channel_ids);

    $self->submit_form_ok({
        with_fields => {
            cutoff_hour     => '23',
            cutoff_minute   => '59',
            carrier_id      => $carrier_id,
        },
        button  => 'submit'
    }, "Submit manifest form with carrier id $carrier_id");
    if($option->{check_feedback_error}) {
        $self->no_feedback_error_ok;
    }
    else {
        note "Not checking for feedback errors";
    }

    # get the manifest id
    return $self->as_data->{manifest_details}{'Manifest Number'};
}

=head2 cancel_manifest

 $mech->cancel_manifest( $manifest_id );

This cancels a manifest for a given Manifest Id.

=cut

sub cancel_manifest {
    my ( $self, $manifest_id )  = @_;

    $self->get_ok('/Fulfilment/Manifest');
    $self->follow_link_ok({ text => $manifest_id },'Selecting Manifest to Cancel: '.$manifest_id);

    $self->submit_form_ok({
        form_name   => 'manifestForm',
        with_fields => { status => 'Cancelled' },
        button      => 'submit',
    }, "Cancelling Manifest: ".$manifest_id);
    $self->no_feedback_error_ok;
    $self->has_feedback_success_ok( qr/Manifest status updated to Cancelled/ );

    return;
}

=head2 test_dispatch

 $mech->test_dispatch($shipment_id)

Tests that the Fulfilment -> Dispatch claims to dispatch the shipment.

=cut

sub test_dispatch {
    my ($self,$ship_nr) = @_;

    $self->get_ok('/Fulfilment/Dispatch');

    $self->submit_form_ok({
      with_fields => {
        shipment_id => $ship_nr,
      },
      button => 'submit'
    }, "Dispatch shipment");
    $self->no_feedback_error_ok;

    $self->has_feedback_success_ok(qr/The shipment was successfully dispatched\./);
    return $self;
}

=head2 test_create_rma

 $mech->test_create_rma($shipment_row, $make_exchange)

Test we can create an RMA through the web interface. C<$make_exchange> is a
boolean. The return will be created with the first shipment item from
C<$shipment_row>.

=cut

sub test_create_rma {
    my ($self, $shipment, $make_exchange,$reason_return, $un_allocate, $args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $schema  = Test::XTracker::Data->get_schema;

    $shipment->discard_changes;
    my $line_item = $shipment->shipment_items->order_by_sku->first;
    my $line_item_id = $line_item->id;

    $reason_return ||= 'Price';
    note "Reason For Return: $reason_return";

    my $submit_values = {
        "selected-$line_item_id" => 1,
        "reason_id-$line_item_id" => $reason_return,
        "type-$line_item_id" => 'Return',
        "refund_id" => $RENUMERATION_TYPE__CARD_REFUND,
    };

    my $other_var_id;
    if ($make_exchange) {
      # We need to get a size to return. Fun!
      $other_var_id = $self->_get_var_to_exchange($line_item, $un_allocate);
    }

    $self->get_ok($self->order_view_url);
    $self->follow_link_ok({text_regex => qr/^Returns[\s\xA0]*$/})
      or LOGCONFESS $self->uri . "\n" . join '', $self->content ;
    $self->follow_link_ok({text_regex => qr/^Create Return\s*/})
      or LOGCONFESS $self->uri . "\n" . join '', $self->content ;

    is($shipment->returns->count, 0, "Shipment doesn't have a return yet (precondition)");

    $self->_enable_rma_fields($line_item_id);
    $self->_check_for_correct_rma_reasons($line_item_id);

    my $is_creating_an_exchange = 0;
    my $pws_stock_log_rs;
    my $org_pws_stock_log_id;

    if ($make_exchange && $self->current_form->find_input("exchange-$line_item_id")) {
      my ($size_option) = grep {
          /^$other_var_id\b/
      } $self->current_form->find_input("exchange-$line_item_id")->possible_values;

      $submit_values->{"exchange-$line_item_id"} = $size_option;
      $submit_values->{"type-$line_item_id"} = 'Exchange';

      # get the most recent PWS Stock Log records for the Exchange Variant
      # to compare with later to make sure that a new record has been created
      $pws_stock_log_rs     = $schema->resultset('Public::Variant')->find( $other_var_id )
                                        ->log_pws_stocks
                                            ->search( {}, { order_by => 'me.id DESC' } );
      my $org_pws_stock_log = $pws_stock_log_rs->first;
      $org_pws_stock_log_id = ( defined $org_pws_stock_log ? $org_pws_stock_log->id : 0 );
      $is_creating_an_exchange  = 1;
      note "ORIGINAL VARIANT PWS STOCK LOG ID: ".$org_pws_stock_log_id;
    }

    # clear the AMQ Message Queue
    $self->_clear_AMQ_order_message_queue();

    #get the depatment_id
    my $operator = $self->logged_in_as
        ? $schema->resultset('Public::Operator')->find({ username => $self->logged_in_as })
        : $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );
    my $department_id  =  $operator->department_id;

    # Email Template dropdown should not be shown for Distribution Management dept
    if( $department_id != $DEPARTMENT__DISTRIBUTION_MANAGEMENT ) {
        $self->has_tag_like( 'label', qr{Select Email Template}i, "Email Template  appears on the page" );
    } else {
        $self->content_unlike( qr{Select Email Template}i, "Email Template does NOT appear on the page" );
    }

    #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_update_correspodence_table($args);
    }

    $self->submit_form_ok({
      with_fields => $submit_values,
      button => "submit"
    }, "RMA created (step 1/2)");
    $self->no_feedback_error_ok;

    my $fields;
    # cando-790 : for Distribution management we have dropped Email Template dropdown and template
    if( $department_id != $DEPARTMENT__DISTRIBUTION_MANAGEMENT ) {

        $self->has_tag_like( 'span', qr{Email Template}i, "Email Template heading is on the page" );
        # Check that all the email fields are pre-populated. The content of these
        # fields are tested in t/returns/email_create.t.
        my $form = $self->form_with_fields('send_email');
        for my $n (qw/subject body replyto from to content_type/) {
            my $p = $form->param("email_$n");
            cmp_ok(length($p), '>', 0, "email_$n field has content") or diag $self->content;
        }
        $fields = ({ with_fields => { send_email => "yes"},
                    button => "submit"
                  });

        #TODO : cando-1282 test stuff here
        if(exists $args->{update_content} && $args->{update_content}){
           $self->_test_email_data($form, $args);
        }
    } else {
        $self->content_unlike( qr{Email Template}i, "Email Template heading is NOT on the page" );
        $fields = ({ form_number => 2, button => "submit" });
    }

    # CANDO-180: check there were no order status AMQ messages sent, this is checking that
    #            the 'called_in_preview_create_mode' flag has been passed to the Returns
    #            Domain in the Create Return Handler when previewing the RMA prior to
    #            confirming the Return (Step 2 see below)
    $self->_expected_AMQ_order_messages_sent( 0, "No Order Status AMQ Messages were sent (possible stock discrepancy bug if this fails)");

    $self->submit_form_ok($fields, "RMA created (step 2/2)");
    $self->no_feedback_error_ok;

    # TODO: This seems to sporadically fail. Confusing :/
    $self->has_feedback_success_ok(qr/Return created successfully/)
        or diag $self->content;

    $shipment->discard_changes;
    $line_item->discard_changes;

    isnt(my $return = $shipment->returns->first,
         undef,
         "Shipment now has a return");

    is($return->return_status->id,
       $RETURN_STATUS__AWAITING_RETURN,
       "Status is awaiting return");

    is($line_item->shipment_item_status_id,
       $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
       "Line item is awaiting return");

    # test the Exchange Variant had a new PWS Stock Log created for it
    if ( $is_creating_an_exchange ) {
        my $new_pws_stock_log   = $pws_stock_log_rs->reset->first;
        ok( defined $new_pws_stock_log, "Got a PWS Stock Log for the Exchange Variant" );
        note "NEW VARIANT PWS STOCK LOG ID: ".$new_pws_stock_log->id;
        cmp_ok( $new_pws_stock_log->id, '>', $org_pws_stock_log_id, "PWS Stock Log Id is greater than original log" );
        cmp_ok( $new_pws_stock_log->quantity, '==', -1, "PWS Stock Log Quantity is '-1'" );
        is( $new_pws_stock_log->notes, "Exchange on ".$shipment->id, "PWS Stock Log notes as expected: 'Exhange on ".$shipment->id."'" );
    }

    $self->_test_AMQ_order_message_sent($shipment->order, "AMQ message sent on create RMA");
    #%template_data_to_save
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_restore_correspodence_table($args->{template_id});
    }

    return $self;
}




# this was in t/order/rma_cancel.t for some reason
sub test_cancel_rma {
    my ($mech, $return, $exchange, $args) = @_;

    $mech->_clear_AMQ_order_message_queue();

    $mech->get_ok($mech->order_view_url);
    my $rma_nr = $return->rma_number;
    $mech->follow_link_ok({text_regex => qr/$rma_nr/});

    #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $mech->_update_correspodence_table($args);
    }

    $mech->follow_link_ok({text_regex => qr/Cancel Return/});

    # Check that all the email fields are pre-populated. The content of these
    # fields are tested in t/returns/email_cancel.t.
    my $form = $mech->form_with_fields('send_email');
    for my $n (qw/subject body replyto from to content_type/) {
        cmp_ok(length($form->param("email_$n")), '>', 0,
               "email_$n field has content");
    }

    #TODO : cando-1282 test stuff here
    if(exists $args->{update_content} && $args->{update_content}){
           $mech->_test_email_data($form, $args);
    }

    $mech->submit_form_ok({
      with_fields => {
        send_email => "yes"
      },
    }, "Cancel Return");
    $mech->no_feedback_error_ok;

    $mech->has_feedback_success_ok(qr/Return cancelled successfully\./);

    $return->discard_changes;

    is ($return->return_status_id, $RETURN_STATUS__CANCELLED, "Return is cancelled");

    cmp_ok($return->return_items->not_cancelled->count, '==', 0,
           "All return items are cancelled");

    if ($exchange) {
      my $rs = $return->renumerations->not_cancelled;

      cmp_ok($rs->count, '==', 0, "Return has no un-cancelled renumerations");
    }

    if(exists $args->{update_content} && $args->{update_content}){
        $mech->_restore_correspodence_table($args->{template_id});
    }

}

sub nap_order_update_queue_name {
    my ($self,  $channel ) = @_;

    # Get the default channel of NAP if none was specified.
    $channel ||= Test::XTracker::Data
        ->get_schema
        ->resultset('Public::Channel')
        ->net_a_porter;

    # If we've got a channel object (we should have!) and it's not
    # Jimmy Choo (this was not defined prior to APAC).
    if ( defined $channel && $channel->business_id != $BUSINESS__JC ) {

        return '/queue/'.lc( $channel->web_name ) . '-orders';

    } else {

        die 'Queue name not set';

    }

}

sub _test_AMQ_order_message_sent {
    my ($self, $order, $msg) = @_;

    my $queue   = $self->nap_order_update_queue_name( $order->channel );
    $self->amq->assert_messages( {
        destination => $queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            '@type' => 'order',
            orderNumber => $order->order_nr,
        }),
        assert_count => atleast(1),
    }, $msg );
}
sub _clear_AMQ_order_message_queue {
    my $self    = shift;
    $self->amq->clear_destination( $self->nap_order_update_queue_name() );
    return;
}
sub _expected_AMQ_order_messages_sent {
    my ( $self, $number, $msg ) = @_;
    $self->amq->assert_messages({
        destination => $self->nap_order_update_queue_name(),
        assert_count => $number,
    }, $msg);
}

sub _get_var_to_exchange {
    my ($self, $to_return, $un_allocate) = @_;

    my $var = $to_return->variant;
    my $prod = $var->product;
    my $other_var = $prod->variants->search(
        {
            id      => { '!=' => $var->id },
            type_id => $VARIANT_TYPE__STOCK,
        },
        { order_by => 'me.id' }
    )->slice(0, 0)->single;
    Test::XTracker::Data->set_product_stock({
      product_id   => $prod->id,
      size_id      => $other_var->size_id,
      quantity     => 1000,
      stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
    if (!$un_allocate){
        note "move all allocated stock to picked to un-allocate it";
        my $schema  = Test::XTracker::Data->get_schema;
        $schema->resultset('Public::ShipmentItem')->search_by_sku($other_var->sku)->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED });
    }

    return $other_var->id;
}

sub _enable_rma_fields {
    my ($self, $line_item_id) = @_;

    # Hate. The select is disabled by default, so need to find it, enable it sot
    # that Mech will set a value for it
    my $name = "reason_id-$line_item_id";
    $self->form_with_fields($name);

    $self->current_form->find_input($name)->disabled(0);
    $self->current_form->find_input("type-$line_item_id")->disabled(0);
    my $exch=$self->current_form->find_input("exchange-$line_item_id");
    if (defined $exch) { $exch->disabled(0) }
}

# checks the Reasons people can give for Returning an Item are
# the Expected List - 'Dispatch/Return' shouldn't be one of them
sub _check_for_correct_rma_reasons {
    my ( $self, $line_item_id ) = @_;

    my $expected    = Test::XTracker::Data->get_schema
                            ->resultset('Public::CustomerIssueType')
                                ->return_reasons_for_rma_pages;

    my $reason_tag_id   = "returnReason-${line_item_id}";
    my ( $reason )      = $self->grep_inputs( {
                                            type    => qr/^option$/,
                                            id      => qr/^$reason_tag_id$/,
                                        } );

    ok( defined $reason, "found list of Return Reasons for Item" );

    # get the options for $reason, then delete any with
    # values of '0' and end up with a Hash of 'value => name'
    my %options;
    @options{ $reason->value_names }    = $reason->possible_values;
    my %got = map { $options{ $_ } => $_ }
                    grep { $options{ $_ } }
                        keys %options;
    is_deeply( \%got, $expected, "and the Return Reasons are as Expected" );

    return;
}

sub get_rma_page {
    my($self,$return) = @_;

    $self->get_ok($self->order_view_url);

    my $rma_nr = $return->rma_number;
    $self->follow_link_ok({text_regex => qr/$rma_nr/});
}

# tests the RMA Page got from calling 'get_rma_page', please
# add more tests as you see fit.
sub test_rma_page {
    my ( $self, $return )   = @_;

    note "Testing RMA Page";

    $return->discard_changes;
    my $page    = $self->as_data;

    note "checking 'Return Details'";
    is( $page->{return_details}{RMA}, $return->rma_number, "RMA Found" );
    is( $page->{return_details}{Status}, $return->return_status->status, "Status Found" );

    note "checking 'Return Items'";
    cmp_ok( @{ $page->{return_items} }, '==', $return->return_items->count, "Found Correct Number of Items" );

    note "checking 'Return Log'";
    cmp_ok( @{ $page->{return_log} }, '==', $return->return_status_logs->count, "Found Correct Number of Status Entires" );

    note "checking 'Return Items Log'";
    cmp_ok( @{ $page->{return_items_log} }, '==', $return->return_items->search_related('return_item_status_logs')->count,
                            "Found Correct Number of Item Status Entires" );


    # the following tables are optional

    note "checking 'Return Notes'";
    if ( $return->return_notes->count ) {
        ok( exists( $page->{return_notes} ), "Found Notes" );
        cmp_ok( @{ $page->{return_notes} }, '==', $return->return_notes->count, "Found Correct Number of Notes" );
    }
    else {
        ok( !exists( $page->{return_notes} ), "Couldn't find any Notes" );
    }

    note "checking 'Return Email Log'";
    if ( $return->return_email_logs->count ) {
        ok( exists( $page->{return_email_log} ), "Found Log" );
        cmp_ok( @{ $page->{return_email_log} }, '==', $return->return_email_logs->count, "Found Correct Number of Logs" );
        my @logs    = $return->return_email_logs->search( {}, { order_by => 'id' } );
        my $pg_logs = $page->{return_email_log};
        foreach my $idx ( 0..$#logs ) {
            my $row_label   = 'Row: ' . ( $idx + 1 );
            is( $pg_logs->[$idx]{'Type'}, $logs[$idx]->correspondence_template->name, "${row_label}, Correct Template Found" );
            is( $pg_logs->[$idx]{'Sent By'}, $logs[$idx]->operator->name, "${row_label}, Correct Operator Name Found" );
            # the RMA column should NOT be shown on this page
            ok( !exists( $pg_logs->[$idx]->{'RMA'} ), "${row_label}, 'RMA' Column NOT Found in Row" );
        }
    }
    else {
        ok( !exists( $page->{return_email_log} ), "Couldn't find any Logs" );
    }

    note "END Testing RMA Page";

    return $self;
}

sub test_add_rma_items {
    my ($self, $return, $make_exchange, $un_allocate, $args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->_clear_AMQ_order_message_queue();

    $self->get_rma_page( $return );

    # Work out what item we are going to add.

    my $cur_return_line = $return->return_items->first->shipment_item;
    my $to_return = $return->shipment->shipment_items->search(
        {
            id => { '!=' => $cur_return_line->id }
        },
        { order_by => [ "shipment_item_status_id", "id" ] },
    )->first;
    my $line_item_id = $to_return->id;

    my $submit_values = {
        "selected-$line_item_id" => 1,
        "reason_id-$line_item_id" => "Price",
        "type-$line_item_id" => 'Return',
    };

    my $other_var_id;
    if ($make_exchange) {
      # We need to get a size to return. Fun!
      $other_var_id = $self->_get_var_to_exchange($to_return, $un_allocate);
    }

    $self->follow_link_ok({text_regex => qr/Add Item/});

    $self->_enable_rma_fields($line_item_id);
    $self->_check_for_correct_rma_reasons($line_item_id);

    if ($make_exchange) {
      my ($size_option) = grep {
          /^$other_var_id\b/
      } $self->current_form->find_input("exchange-$line_item_id")->possible_values;

      $submit_values->{"exchange-$line_item_id"} = $size_option;
      $submit_values->{"type-$line_item_id"} = 'Exchange';
    }

    #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_update_correspodence_table($args);
    }

    $self->submit_form_ok({
      with_fields => $submit_values,
      button => "submit"
    }, "Added item to RMA (step 1/2)");
    $self->no_feedback_error_ok;

    # Check that all the email fields are pre-populated. The content of these
    # fields are tested in t/returns/email_add_item.t.
    my $form = $self->form_with_fields('send_email');
    for my $n (qw/subject body replyto from to content_type/) {
        cmp_ok(length($form->param("email_$n")), '>', 0,
               "email_$n field has content");
    }

    $self->submit_form_ok({
      with_fields => {
        send_email => "yes"
      },
      button => "submit"
    }, "Added item to RMA (step 2/2)");
    $self->no_feedback_error_ok;

    $self->has_feedback_success_ok(qr/Items? added successfully/);

    #TODO : cando-1282 test stuff here
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_test_email_data($form, $args);
    }


    my (@line_items) = $return->shipment->shipment_items->slice(0,1);

    cmp_ok(scalar @line_items, '==', 2, "Got two line items (sanity check)");


    is($line_items[0]->shipment_item_status_id,
       $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
       "Line item 1 is awaiting return");

    is($line_items[1]->shipment_item_status_id,
       $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
       "Line item 2 is awaiting return");

    # We're done adding an item, so no go and remove the item we just added

    $self->_test_AMQ_order_message_sent($return->shipment->order, "AMQ message sent on add rma items");

    if(exists $args->{update_content} && $args->{update_content}){
        $self->_restore_correspodence_table($args->{template_id});
    }


    return $self;
}

sub test_remove_rma_items {
    my ($self, $return_item, $args) = @_;

    $self->_clear_AMQ_order_message_queue();

    $self->get_ok($self->order_view_url);
    my $return = $return_item->return;

    my $rma_nr = $return->rma_number;

    # sort shipment items by id to ensure consistent test results
    my (@line_items) = $return->shipment->shipment_items->search({},{ order_by => { -desc => 'id' } })->slice(0,1);

    cmp_ok(scalar @line_items, '>', 1, "Got more then 1 line items (sanity check)");


    $self->follow_link_ok({text_regex => qr/$rma_nr/});

    $self->follow_link_ok({text_regex => qr/Remove Item/});

    # Remove item form uses return_item.id, not shipment_item.id
    my $return_item_id = $return_item->id;

     #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_update_correspodence_table($args);
    }


    $self->submit_form_ok({
      with_fields => {
        "selected-$return_item_id" => 1,
      },
      button => "subbutton"
    }, "Removed item from RMA (step 1/2)");
    $self->no_feedback_error_ok;


    # Check that all the email fields are pre-populated. The content of these
    # fields are tested in t/returns/email_remove_item.t.
    my $form = $self->form_with_fields('send_email');
    for my $n (qw/subject body replyto from to content_type/) {
        cmp_ok(length($form->param("email_$n")), '>', 0,
               "email_$n field has content");
    }

    $self->submit_form_ok({
      with_fields => {
        send_email => "yes"
      },
      button => "subbutton"
    }, "Removed item from RMA (step 2/2)");
    $self->no_feedback_error_ok;

    $self->has_feedback_success_ok(qr/Items? removed successfully/);

    #TODO : cando-1282 test stuff here
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_test_email_data($form, $args);
    }


    $_->discard_changes for (@line_items);
    $return_item->discard_changes;

    is($return_item->return_item_status_id,
       $RETURN_ITEM_STATUS__CANCELLED,
       "Return item is cancelled");

    $self->_test_AMQ_order_message_sent($return->shipment->order, "AMQ message sent on remove RMA items");

    if(exists $args->{update_content} && $args->{update_content}){
        $self->_restore_correspodence_table($args->{template_id});
    }


    return $self;
}

sub select_printer_station {
    my ( $self ) = @_;
    my $printers = $self->as_data->{stations};
    # Let's avoid the empty string - all other options should be valid

    my ($printer_name) = grep { $_ } map { $_->{value} } @$printers;

    $self->submit_form_ok({
        with_fields => { 'ps_name' => $printer_name },
        button => 'submit',
    }, "Selected printer station [$printer_name]");
}

sub test_bookin_rma {
    my ($self, $return, $args ) = @_;

    $self->get_ok('/GoodsIn/ReturnsIn');

    $self->select_printer_station
        if $self->find_xpath(q{//form[@name='SelectPrinterStation']})->size;

    $self->submit_form_ok({
      with_fields => { search_string => $return->rma_number },
      button => 'submit'
    }, "Found RMA");
    $self->no_feedback_error_ok;

    # Get the variants in the order
    my @variants = $return->return_items
                          ->not_cancelled
                          ->related_resultset('variant')
                          ->all;

    for my $variant ( @variants ) {
      # Book the products in.
      $self->submit_form_ok({
        with_fields => { return_sku => $variant->sku, },
        button => 'submit'
      }, "Booked in " . $variant->sku);
      $self->no_feedback_error_ok;
    }

    my ( $ret_awb ) = Test::XTracker::Data->generate_air_waybills;

    my $shipment            = $return->discard_changes->shipment;
    my $ship_email_log_rs   = $shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
    my $last_email_log_id   = ( # get the last Log Id to see if any
                                # new ones are created later on
                                $ship_email_log_rs->count
                                ? $ship_email_log_rs->first->id
                                : 0
                            );

    my $send_email  = 'no';
    if ( $args->{test_send_email} ) {
        $send_email = 'yes';
    }

    $self->submit_form_ok({
      with_fields => { airwaybill => $ret_awb, email => $send_email },
      button => 'submit'
    }, "Book in completed");
    $self->no_feedback_error_ok;

    my @r_items = $return->return_items->not_cancelled->all;

    is(@r_items, @variants,
        sprintf( 'Got %d uncancelled return item%s',
            scalar @variants,
            scalar @variants == 1 ? q{} : q{s} )
    );

    is($_->return_item_status_id, $RETURN_ITEM_STATUS__BOOKED_IN,
       sprintf( q{Return item %d has a status of 'Booked In'}, $_->id )
    ) for @r_items;

    $return->discard_changes;
    is ($return->return_status_id, $RETURN_STATUS__PROCESSING,
        "Return is now 'Processing'");

    if ( $args->{test_send_email} ) {
        note "testing 'Return Received' Email WAS Sent";
        my $log = $ship_email_log_rs->reset->first;
        isa_ok( $log, 'XTracker::Schema::Result::Public::ShipmentEmailLog', "Found a Shipment Email Log record" );
        cmp_ok( $log->id, '>', $last_email_log_id, "and it's new" );
        cmp_ok( $log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__RETURN_RECEIVED,
                                            "and it's for the 'Return Received' Email" );
    }
    else {
        note "testing 'Return Received' Email was NOT Sent";
        my $latest_email_log_id = ( $ship_email_log_rs->reset->count ? $ship_email_log_rs->first->id : 0 );
        cmp_ok( $latest_email_log_id, '==', $last_email_log_id, "No New Emails have been Logged against the Shipment" );
    }

    return $self;
}

sub test_returns_qc_pass {
    my ($self, $return ) = @_;

    $self->_clear_AMQ_order_message_queue();

    $self->_test_returns_qc($return);

    $return->discard_changes;
    is ($return->return_status_id, $RETURN_STATUS__COMPLETE,
        "Return status is now 'Complete'");

    my @r_items = $return->return_items->not_cancelled->all;

    is($_->return_item_status_id, $RETURN_ITEM_STATUS__PASSED_QC,
       sprintf(q{Return item %d has a status of 'Passed QC'}, $_->id)
   ) for @r_items;

    $self->_test_AMQ_order_message_sent($return->shipment->order, "AMQ message sent on returns QC");

    return $self;
}

sub test_returns_qc_faulty {
    my ($self, $return ) = @_;

    $self->_test_returns_qc($return, {fail => 1});

    $self->get_ok('/GoodsIn/ReturnsFaulty');

    $self->select_printer_station
        if $self->find_xpath(q{//form[@name='SelectPrinterStation']})->size;

    $self->submit_form_ok({
      with_fields => { process_group_id => $return->rma_number },
      button => 'submit'
    }, "Found RMA");
    $self->no_feedback_error_ok;

    $self->submit_form_ok({
      with_fields => { decision => "reject", },
      button => "submit"
    }, "Returns QC Faulty rejected");
    $self->no_feedback_error_ok;
    $self->has_feedback_success_ok( qr{PGID \d+ rejected} );

    my @r_items = $return->return_items->not_cancelled->all;

    is($_->return_item_status_id,
       $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
       sprintf(q{Return item %d has a status of 'Failed QC - Rejected'}, $_->id)
   ) for @r_items;

    return $self;
}

sub _test_returns_qc {
    my ($self, $return, $args ) = @_;

    $self->get_ok('/GoodsIn/ReturnsQC');

    $self->select_printer_station
        if $self->find_xpath(q{//form[@name='SelectPrinterStation']})->size;

    $self->submit_form_ok({
      with_fields => { delivery_id => $return->rma_number },
      button => 'submit'
    }, "Found RMA");
    $self->no_feedback_error_ok;

    # The ReturnsQC page has Pass/Fail radio buttons based on the stock_process id
    my $return_items = $return->return_items->not_cancelled;
    my $stock_processes
        = $return_items->related_resultset('link_delivery_item__return_items')
                       ->related_resultset('delivery_item')
                       ->related_resultset('stock_processes');

    is( scalar $return_items->all,
        scalar $stock_processes->get_column('group_id')->func_rs('DISTINCT')->all,
        'each return item has its own process group id' );

    $self->submit_form_ok({
      with_fields => { map {;
        "qc_$_" => $args->{fail} ? 'fail' : 'pass'
      } $stock_processes->get_column('id')->all, },
      button => "submit"
    }, sprintf 'Returns QC %s', $args->{fail} ? 'failed' : 'passed' );
    $self->no_feedback_error_ok;
    $self->has_feedback_success_ok(qr/Quality control check completed successfully/);
    return $self;
}

sub test_refund_pending {
    my ($self, $return) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $rs = $return->renumerations->not_cancelled;

    cmp_ok($rs->count, '==', 1, "Return has a renumeration");
    my $renum = $rs->first;

    my $amount = $renum->renumeration_items->get_column('unit_price')->sum;

    cmp_ok($amount, '==', 250, "Ammount on renumeration is right");

    is($renum->renumeration_status_id, $RENUMERATION_STATUS__PENDING,
       "Refund is pending");

    return $self;
}

sub test_refund_amount {
    my ($self, $return, $wanted) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $return->discard_changes;
    if ( $return->renumerations->not_cancelled > 1 ) {
        diag "Found too many renumerations returned - test may be unstable";
    }
    my $renum = $return->renumerations->not_cancelled->first;

    my $amount = $renum->renumeration_items->get_column('unit_price')->sum;

    cmp_ok($amount, '==', $wanted, "Amount on renumeration is $wanted");

    return $self;
}

sub test_refund_released {
    my ($self, $return) = @_;

    my $renum = $return->renumerations->not_cancelled->first;

    cmp_ok( $renum->discard_changes->sent_to_psp, '==', 0, "Sent To PSP Flag NOT Set" );

    is($renum->renumeration_status_id, $RENUMERATION_STATUS__AWAITING_ACTION,
       "Refund now Released");

    return $self;
}

sub test_refund_complete {
    my ($self, $return) = @_;

    my $renum = $return->renumerations->not_cancelled->first;

    cmp_ok( $renum->discard_changes->sent_to_psp, '==', 1, "Sent To PSP Flag Set" );

    is($renum->renumeration_status_id, $RENUMERATION_STATUS__COMPLETED,
       "Refund now Completed");

    return $self;
}

sub release_refund_ok {
    my ($self, $return, $args)  = @_;

    my $check_cancel_rma    = $args->{check_cancel_rma} || 0;

    Test::XTracker::Data->grant_permissions('it.god', 'Finance', 'Active Invoices', 2);

    my $suffix = $return->shipment->get_channel->business->config_section;

    my $force_datalite_state = $self->force_datalite() || 0;
    $self->force_datalite(0);

    $self->get_ok('/Finance/ActiveInvoices');
    my $renum = $return->renumerations->not_cancelled->first;

    if ( $check_cancel_rma ) {
        # if required check when printing/completing a
        # refund with a cancelled RMA, fails
        my $tmp         = $return->return_status_id;
        my $rma_number  = $return->rma_number;
        my $err_msg     = qr/Error processing order.*RMA \($rma_number\) linked to the invoice has been Cancelled, please investigate and then manually Complete or Cancel the Invoice/;

        # cancel the RMA
        $return->update( { return_status_id => $RETURN_STATUS__CANCELLED } );

        # check Print action
        my $id  = $renum->id;
        $self->submit_form_ok({
            form_name => "activeInvoiceForm-$suffix",
            fields => { "print-$id" => 1 },
            button => 'submit'
        }, "Print Invoice ($id) for Cancelled RMA (".$return->id.")" );
        $self->has_feedback_error_ok( $err_msg );

        # check Complete action
        $id = $renum->id;
        $self->submit_form_ok({
            form_name => "activeInvoiceForm-$suffix",
            fields => { "complete-$id" => 1 },
            button => 'submit'
        }, "Complete Invoice ($id) for Cancelled RMA (".$return->id.")" );
        $self->has_feedback_error_ok( $err_msg );

        # check Refund and Complete action
        $id = $renum->id;
        $self->submit_form_ok({
            form_name => "activeInvoiceForm-$suffix",
            fields => { "refund_and_complete-$id" => 1 },
            button => 'submit'
        }, "Refund and Complete Invoice ($id) for Cancelled RMA (".$return->id.")" );
        $self->has_feedback_error_ok( $err_msg );

        # restore the original Return Status
        $return->update( { return_status_id => $tmp } );
    }

    $self->force_datalite($force_datalite_state);

    # Since refunds now go back to the same way they were paid, this might
    # break if we ever place an order which isn't a store credit order.
    my $id = $renum->id;
    $self->submit_form_ok({
        form_name => "activeInvoiceForm-$suffix",
        with_fields => { "refund_and_complete-$id" => 1 },
        button => 'submit'
    }, "Refund invoice printed");
    $self->no_feedback_error_ok;

    $self->test_refund_complete( $return );

    return $self;
}

sub test_exchange_pending {
    my ($self, $return) = @_;

    ok(my $ex_shipment = $return->exchange_shipment, "Return has an exchange_shipment");

    is($ex_shipment->shipment_class_id, $SHIPMENT_CLASS__EXCHANGE, "  ... which is an exchange");

    # Shipment Statuses:
    # - RETURN_HOLD means we are waiting for the goods to be returned
    # - EXCHANGE_HOLD means we are *also* waiting for some extra debit to happen (duties etc.)

    ok($ex_shipment->is_awaiting_return, "  ... and it is in 'Exchange Hold' or 'Return Hold' state")
      or diag("   got: " . $ex_shipment->shipment_status_id);

    return $self;
}

sub test_exchange_item_added {
    my ($self, $return) = @_;

    my $shipment = $return->exchange_shipment;

    my (@line_items) = $shipment->shipment_items->all;

    cmp_ok(scalar @line_items, '==', 2, "Got two line items for exchange shipment");

    # The status of the shipment items isn't anything special, so don't bother checking it

    return $self;
}

sub test_exchange_item_removed {
    my ($self, $return) = @_;

    my $shipment = $return->exchange_shipment;


    cmp_ok($shipment->shipment_items->not_cancelled->count,
           '==',
           1,
           "Got one un-canceled line item for exchange shipment");

    cmp_ok($shipment->shipment_items->cancelled->count,
           '==',
           1,
           "Got one canceled line item for exchange shipment");

    return $self;
}

sub test_exchange_released {
    my ($self, $return) = @_;

    my $ex_shipment = $return->exchange_shipment;
    is($ex_shipment->shipment_status_id, $SHIPMENT_STATUS__PROCESSING, "Exchange shipment is now being processed");

    return $self;
}


=head2 test_returns_putaway

This test is only good enought for aa RMA of an item.
Please feel free to extend it if you need. This is the phase +0
way of doing the test_returns_putaway_x stuff below

=cut

sub test_returns_putaway {
    my ( $self, $return ) = @_;

    my $variant = $return->return_items
        ->not_cancelled
        ->first
        ->variant;

    my $previous_var_quantity = $variant
        ->quantities
        ->get_column('quantity')->sum;

    my $framework = Test::XT::Flow->new_with_traits(
        traits => ['Test::XT::Flow::WMS'],
        mech   => $self
    );
    my $sp_rs = $return->return_items
                  ->not_cancelled
                  ->first
                  ->uncancelled_delivery_item
                  ->stock_processes;

    $framework->flow_wms__send_stock_received(
        sp_group_rs => $sp_rs,
        ($self->logged_in_as ? (operator => $self->logged_in_as_object) : ()),
    );

    $variant->discard_changes;
    my $new_stock_quantity = $variant->quantities->get_column('quantity')->sum;
    is($new_stock_quantity,$previous_var_quantity + $sp_rs->first->quantity,"New stock quantities match what was received");

    return $self;
}

# These two methods support the phase 0 method of putaway
sub test_returns_putaway_phase_0 {
    my ( $self, $return, $args ) = @_;

    my @stock_processes
        = $return->return_items
                 ->not_cancelled
                 ->related_resultset('link_delivery_item__return_items')
                 ->related_resultset('delivery_item')
                 ->related_resultset('stock_processes')
                 ->all;

    # Try to input a sku
    if ( $args->{test_sku} ) {
        $self->get_ok('/GoodsIn/Putaway');
        my $sku = $stock_processes[0]->variant->sku;
        $self->submit_form_ok({
            with_fields => { process_group_id => $sku, },
            button => 'submit',
        }, sprintf('Submit return sku %s', $sku));
        $self->has_feedback_error_ok(qr{Process Group ID $sku is not valid});
        $self->base_like( qr{/GoodsIn/Putaway}, 'on putaway page' );
        my $node = $self->find_xpath(q{//div[@id='pageTitle']/h3})->pop;
        isnt(
            ($node ? $node->content_list : ())[0],
            'Process Item',
            'not on process item page' );
    }

    # Follow the normal procedure submitting process group ids
    for my $stock_process ( @stock_processes ) {
        $self->get_ok('/GoodsIn/Putaway');

        $self->submit_form_ok({
            with_fields => { process_group_id => $stock_process->group_id },
            button => 'submit'
        }, "Found Return to Putaway");
        $self->no_feedback_error_ok;

        $self->form_name('putawayForm');
        my $location_suggestion = $self->current_form
                                       ->find_input('location_suggestion')
                                       ->value();

        # get locations to submit to form later
        my ( $location_ok, $location_notok )
            = $self->_get_locations( $location_suggestion );

        my $location = 'location_' . $stock_process->id;
        # test giving it an incorrect location - should return an error
        if ( $args->{ignore_suggestion} ) {
            $self->submit_form_ok({
                with_fields => { $location => $location_notok },
                button => 'submit'
            }, "Submit Location to Putaway");
            $self->has_feedback_error_ok(qr/Ignored Suggested Location/);
            $self->has_feedback_error_ok(
                qr/The location you have chosen does not match the location or location zone shown on the page/
            );
        }

        # test submitting a location - should now return ok and update stock_process row
        $self->submit_form_ok({
            with_fields => { $location => $location_ok },
            button => 'submit'
        }, "Submit Succesful Location to Putaway");
        $self->has_feedback_success_ok(qr/Process Group \d+ has been put away successfully/);

        is( $stock_process->discard_changes->status_id, $STOCK_PROCESS_STATUS__PUTAWAY,
            sprintf( q{Stock process %d has a status of 'Putaway'}, $stock_process->id )
        );
    }
}

sub test_convert_from_exchange {
    my($self, $return, $args) = @_;

    $self->get_rma_page( $return );
    $self->follow_link_ok({text_regex => qr/Convert From Exchange/});
    my $item = $return->return_items->not_cancelled->search( {}, { order_by => 'me.id ASC' } )->first;

    #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_update_correspodence_table($args);
    }

    $self->submit_form_ok({
      with_fields => {
        "item-". $item->id  => 1,
      },
    }, "select return item");
    diag $self->app_error_message if $self->app_error_message;

    # Check that all the email fields are pre-populated. The content of these
    # fields are tested in t/returns/email_*.t
    my $form = $self->form_with_fields('send_email');
    for my $n (qw/subject body replyto from to content_type/) {
        cmp_ok(length($form->param("email_$n")), '>', 0,
               "email_$n field has content");
    }

    my $should_send_email = $args->{should_send_email} // 'yes';

    $self->submit_form_ok({
      with_fields => {
        send_email => $should_send_email,
      },
    }, "confirm and setting send email to $should_send_email");
    diag $self->app_error_message if $self->app_error_message;

    ok(my $return_item = $return->return_items->search( {}, { order_by => 'me.id DESC' } )->first, "We have a return item");

    #TODO : cando-1282 test stuff here
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_test_email_data($form, $args);
    }

    is($return_item->is_refund, 1, "  ... which is a refund");

    if(exists $args->{update_content} && $args->{update_content}){
        $self->_restore_correspodence_table($args->{template_id});
    }

    return $self;
}

sub test_convert_to_exchange {
    my($self, $return, $args) = @_;

    $self->get_rma_page( $return );

    $self->follow_link_ok({text_regex => qr/Convert to Exchange/});
    my $item    = $return->return_items->search( {}, { order_by => 'me.id DESC' } )->first;
    my $order   = $return->shipment->order;
    my $ship_rs = $order->shipments->search( undef, { order_by => 'me.shipment_id DESC' } );

    ok( !defined $item->exchange_shipment_item_id, "Return Item: ".$item->id.", 'exchange_shipment_item_id' field is NULL" );

    my ($size_option) = grep {
        $_ ne "0"
    } $self->form_name("cancelForm")->find_input("exch-". $item->id )->possible_values;

    my $submit_values = {
        "item-". $item->id  => 1,
        "exch-". $item->id  => $size_option,
    };

    #cando-1282 : check email content renders correctly
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_update_correspodence_table($args);
    }

    $self->submit_form_ok({
      with_fields => $submit_values,
    }, "select return item");
    diag $self->app_error_message if $self->app_error_message;

    # Check that all the email fields are pre-populated. The content of these
    # fields are tested in t/returns/email_*.t
    my $form = $self->form_with_fields('send_email');
    for my $n (qw/subject body replyto from to content_type/) {
        cmp_ok(length($form->param("email_$n")), '>', 0,
               "email_$n field has content");
    }

    my $should_send_email = $args->{should_send_email} // 'yes';

    $self->submit_form_ok({
      with_fields => {
        send_email => $should_send_email,
      },
    }, "confirm and setting send email to $should_send_email");
    note $self->uri;
    diag $self->app_error_message if $self->app_error_message;

    $return->discard_changes;
    ok(my $return_item = $return->return_items->search( {}, { order_by => 'me.id DESC' } )->first, "We have a return item");

    #TODO : cando-1282 test stuff here
    if(exists $args->{update_content} && $args->{update_content}){
        $self->_test_email_data($form, $args);
    }


    # check that the 'exchange_shipment_item_id' field on the return item rec
    # has been populated with the new shipment item id
    $ship_rs->reset();
    my $ship_item   = $ship_rs->first->shipment_items->not_cancelled->order_by_sku->first;
    cmp_ok( $ship_item->id, '==', $return_item->exchange_shipment_item_id, "Return Item: ".$return_item->id.", Exhange Ship Item Id populated with New Ship Item Id" );

    # count that the value in the 'exchange_shipment_item_id' field
    # is only present in one record because there was a bug once
    # where it populated all the records with a null value
    my $schema  = $return->result_source->schema;
    my $chk     = $schema->resultset('Public::ReturnItem')->count( { 'me.exchange_shipment_item_id' => $ship_item->id } );
    cmp_ok( $chk, '==', 1, "Value in 'exchange_shipment_item_id' field only appears in one record" );

    is($return_item->is_exchange, 1, "  ... which is an exchange");

    if(exists $args->{update_content} && $args->{update_content}){
        $self->_restore_correspodence_table($args->{template_id});
    }

    return $self;
}

=head2 test_edit_shipment

This takes you to the Edit Shipment page for a shipment id.

=cut

sub test_edit_shipment {
    my ($self, $ship_id)    = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $order_rs= $schema->resultset('Public::Shipment')->find($ship_id)->order;

    $self->get_ok('/CustomerCare/OrderSearch/EditShipment?order_id='.$order_rs->id.'&shipment_id='.$ship_id);
    $self->has_tag('span','Shipment Details','Shipment Details Have Appeared');

    return $self;
}

=head2 test_create_sample_request

  $mech = $mech->test_create_sample_request( \@skus );

This will create a Sample Request Stock for a Given list of SKUs that will then
be ready to be approved. The SKU list is the same list that is generated by
L<Test::XTracker::Data>->find_products.

This will also update the SKU HASH in the Array with the Stock Transfer ID for
the request.

NOTE: You need to be in the 'Sample' department to do this.

=cut

sub test_create_sample_request {
    my $self    = shift;
    my $skus    = shift;
    my $info    = shift;
    my $schema  = Test::XTracker::Data->get_schema;

    # get the id for Sample Request type of 'Sample'
    my $sample_type_id  = $schema->resultset('Public::StockTransferType')
                                    ->search( { 'me.type' => 'Sample' } )
                                        ->first->id;

    foreach my $sku ( @{ $skus } ) {
        my $stck_xfer_id= 0;
        my $variant_id  = get_variant_by_sku( $schema->storage->dbh, $sku->{sku} );
        $self->get_ok( '/StockControl/Inventory/Overview?variant_id='.$variant_id );
        $self->follow_link_ok( { text_regex => qr/Request Stock/ } );
        $self->submit_form_ok( {
            form_name   => 'search',
            with_fields => {
                type_id => $sample_type_id,
                info    => $info,
            },
            button => 'submit',
        }, "Request Stock Transfer for: ".$sku->{sku} );
        $self->no_feedback_error_ok;

        # get the most recent Stock Transfer Id for the variant and type
        $stck_xfer_id    = $schema->resultset('Public::StockTransfer')
                                    ->search( {
                                                'me.variant_id' => $variant_id,
                                                'me.type_id'    => $sample_type_id,
                                              },
                                              {
                                                order_by    => 'me.id DESC',
                                              } )->first->id;
        # store the id in the HASH for later use
        $sku->{stock_transfer_id}   = $stck_xfer_id;
    }

    return $self;
}

=head2 test_approve_sample_request

  $mech = $mech->test_approve_sample_request( \@skus );

This will approve Sample Stock Requests for a Given list of SKUs. The SKU list
is the same list that is generated by L<Test::XTracker::Data>->find_products
and has been through $mech->test_create_sample_request which would have assigned
each SKU with a Stock Transfer Id.

This function will also update the SKU HASH in the Array with the Shipment Id
for the Stock Transfer once it has been approved.

NOTE: You need to be in the 'Stock Control' department to do this.

=cut

sub test_approve_sample_request {
    my $self    = shift;
    my $skus    = shift;

    my $schema  = Test::XTracker::Data->get_schema;

    $self->get_ok( '/StockControl/Sample' );

    foreach my $sku ( @{ $skus } ) {
        my $shipment_id = 0;

        $self->submit_form_ok( {
            form_name   => 'search_1',
            with_fields => {
                'approve-'.$sku->{stock_transfer_id} => 1,
            },
            button => 'submit',
        }, "Approve Stock Transfer Request for: ".$sku->{stock_transfer_id}.": ".$sku->{sku} );
        $self->no_feedback_error_ok;

        # get the Shipment Id for the Stock Transfer
        $shipment_id    = $schema->resultset('Public::LinkStockTransferShipment')
                                    ->search( {
                                                'me.stock_transfer_id' => $sku->{stock_transfer_id},
                                              },
                                              {
                                                order_by    => 'me.shipment_id DESC',
                                              } )->first->shipment_id;
        # store the id in the HASH for later use
        $sku->{shipment_id} = $shipment_id;
    }

    return $self;
}


sub _get_locations {
    my ( $self, $location_suggestion )  = @_;

    my $location_notok  = '';
    my $location_rs     = Test::XTracker::Data->get_schema->resultset('Public::Location');
    my $location_ok     = $location_rs->search({ location => $location_suggestion })->first;
    # is the suggested location a zone or a full location name?
    if ( length($location_suggestion) > 4 ) {
        # full location supplied, so just get other locations
        # get notok resultset
        my $location_notok_rs = $location_rs->search(
                    {
                        location    => { '!=' => $location_suggestion },
                        'location_allowed_statuses.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                    },{
                        rows=>1,
                        join => [ 'location_allowed_statuses' ],
                    }
                );

        # Returns either original $location_notok_rs, or new one.
        $location_notok_rs = Test::XT::Rules::Solve->solve(
            'XTracker::Mechanize::OtherLocations' => {
                location  => $location_ok,
                locations => $location_notok_rs
            }
        );

        # get first matching location
        $location_notok = $location_notok_rs->first();
    }
    else {
        # only a zone supplied, so find a suitable location first
        $location_ok = $location_rs->search(
                    {
                        location    => { '-like' => $location_suggestion.'%' },
                        'location_allowed_statuses.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                    },{
                        rows=>1,
                        join => [ 'location_allowed_statuses' ],
                    }
                )->first();
        # then find other locations
        my $location_notok_rs = $location_rs->search(
                    {
                        location    => { '-not_like' => $location_suggestion.'%' },
                        'location_allowed_statuses.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                    },{
                        rows=>1,
                        join => [ 'location_allowed_statuses' ],
                    }
                );

        # Returns either original $location_notok_rs, or new one.
        $location_notok_rs = Test::XT::Rules::Solve->solve(
            'XTracker::Mechanize::OtherLocations' => {
                location  => $location_ok,
                locations => $location_notok_rs
            }
        );

        # get first matching location
        $location_notok = $location_notok_rs->first();
    }

    # we need only the location names
    $location_ok = $location_ok->location if ref($location_ok);
    $location_notok = $location_notok->location if ref($location_notok);

    return ( $location_ok, $location_notok );
}

sub _strip_ws {
    my($self,$value) = @_;
  # Trim and sanitize
  # 0xA0 is &nbsp;
  $value =~ s/\xA0//g;
  $value =~ s/^\s*(.*?)\s*$/$1/g;
  return $value;
}

# The default WWW::Mechanize just does "There is no form with the requested fields".
# This is really annoying
before submit_form => sub {
    my ($self, %args) = @_;

    if ($args{with_fields}) {
        # Do it the long winded way to avoid the warning from WWW::Mech
        my @fields = sort keys %{$args{with_fields}};
        my @forms = $self->forms;
        my @matches;
        FORMS: for my $form (@forms) {
            my @fields_in_form = $form->param();
            for my $field (@fields) {
                next FORMS unless grep { $_ eq $field } @fields_in_form;
            }
            return; # Found a matching form
        }

        diag "We wanted a form with: " . join(", ", @fields);
        diag "\n The following forms were found:";
        diag "\n  " .  join(", ", sort $_->param ) foreach @forms;
        diag;

    }
    elsif ( my $form_name = $args{form_name} ) {
        # Do it the long winded way to avoid the warning from WWW::Mech
        my $temp;
        return if grep {defined($temp = $_->attr('name')) and ($temp eq $form_name) } $self->forms;

        diag "Form names found:";
        diag "  " . ($_->attr("name") || "<unnamed>") foreach $self->forms;
    }

};

=head2 test_display_product_info

 $mech->test_display_product_info($voucher_or_product)

Tests various elements of the page_elements/display_product.tt template are
populated correctly. This test does not fetch any new pages, so call it once
you are on a page that includes the common product info.

We will want to add more thnigs to be tested here later I imagine.

=cut

sub test_common_product_info {
    my ($self, $what) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is($self->find_xpath( "//a[. = '@{[$what->id]}'")->size, 1, "Link to inventory page");
    # TODO: Test other relevant parts of the template (live, arrival date and what not)
}

# FIXME: icydee was going to make this a role. I moved it out of PurchaseOrder
#
# Do all the checks on a channel select box on a page
# DODO - Now superceeded. See Test::XTracker::Page::TraitFor::Channelisation
#
sub ok_channel_select_box {
    my ($self, $name, $opts) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $no_all = $opts->{no_all} || 0;

    my $select = $self->look_down('name', $name);
    is(ref($select), 'HTML::Element', 'found channel select box')
        or diag $self->uri;
    my @options = $select->find('option');

    my $channel_data = Test::XTracker::Model->get_channel_order;

    if (!$no_all) {
        unshift(@$channel_data, {id => '', name => 'All', enabled => 1 });
    }

    # Ensure there are the correct number of options
    my @enabled = grep { $_->{enabled} } @{$channel_data};
    is( scalar(@options), scalar(@enabled), 'correct number of options - '
        . scalar @enabled ) or diag pp(\@enabled);

    my $index = 0;
    while ($index < scalar(@enabled)) {
        my $option = $options[$index];
        my $channel = $enabled[$index];

        if ($channel->{enabled}) {
            is($option->string_value,   $channel->{name},  "option name at index $index");
            is($option->attr('value'),  $channel->{id},    "option value at index $index");
        } else {
            is($option, undef,  "option name not found");
            is($option, undef,  "option value not found");
        }
        $index++;
    }
}

#
# Check that a titles on a page are displayed with the correct channelisation style
# these are normally displayed as follows
#   <span class="title title-MRP">Stock Orders</span><br />
#
# pass a channel object and a list of titles.
#
sub ok_title_channelisation {
    my ($self, $channel, $title_ref) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $title_seen;
    my $title_class = "title title-".$channel->business->config_section;

    my @titles  = $self->look_down('class', $title_class);
    my $reg_exp = join('|', @$title_ref);

    for my $title (@titles) {
        my @content = $title->content_list;
        my $html = $content[0];
        if (my ($found_title) = $html =~ m/($reg_exp)/) {
            $title_seen->{$found_title} = 1;
        }
    }
    for my $title (@$title_ref) {
        is($title_seen->{$title}, 1, "title ($title) is channelised correctly");
    }
}

#
# Check that the logo is correct for the channel
#
sub ok_logo_channelisation {
    my ($self, $channel) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $logo = $channel->name;
    $logo =~ s/ /_/g;
    $logo =~ s/\.com//gi;

    # This algorithm must match that used in root/base/shared/layout/page
    $logo = "logo_${logo}_".config_var('XTracker','instance').'.gif';

    my $image_src = $self->look_down('src', "/images/$logo");
    isnt($image_src, undef, 'channel has a logo');
}

#
# Check that there is a tab for the channel
#
sub ok_tab_channelisation {
    my ($self, $channel) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $class_name = "contentTab-". $channel->business->config_section;
    my @titles  = $self->look_down('class', $class_name);
    is(scalar @titles, 1, "found tab for '$class_name'");
}

=head2 has_sidenav_options

    $mech->has_sidenav_options( [
        'Accept Order',
        'Edit Shipping Address',
        ...
    ], "optional test message" );

Will run tests in a sub-test that will check to see if the current
page HAS the provided Sidenav options.

=cut

sub has_sidenav_options {
    my ( $self, $options, $test_msg ) = @_;

    subtest $test_msg // "Checking Sidenav HAS Options" => sub {
        $self->test_for_sidenav_options( {
            has => $options,
        } );
    };

    return;
}

=head2 hasnt_sidenav_options

    $mech->hasnt_sidenav_options( [
        'Accept Order',
        'Edit Shipping Address',
        ...
    ], "optional test message" );

Will run tests in a sub-test that will check to see if the current
page does NOT have the provided Sidenav options.

=cut

sub hasnt_sidenav_options {
    my ( $self, $options, $test_msg ) = @_;

    subtest $test_msg // "Checking Sidenav DOESN'T have Options" => sub {
        $self->test_for_sidenav_options( {
            has_not => $options,
        } );
    };

    return;
}

=head2 test_for_sidenav_options

    $mech->test_for_sidenav_options( {
        has => [
            'Accept Order',
            ...
        ],
        has_not => [
            'Edit Shipping Address',
            ...
        ],
    } );

Will run a series of tests to see whether the current page HAS
a list of Sidenav options and/or whether it does NOT have a list
of Sidenav options.

=cut

sub test_for_sidenav_options {
    my ( $self, $args ) = @_;

    my $options = $self->parse_sidenav;

    # check for options that are expected to be there
    if ( my $has = $args->{has} ) {
        ok( $self->_find_sidenav_option( $options, $_ ), "Found '${_}'" )
                                foreach ( @{ $has } );
    }

    # check for options that should not be present
    if ( my $has_not = $args->{has_not} ) {
        ok( !$self->_find_sidenav_option( $options, $_ ), "Did NOT Find '${_}'" )
                                foreach ( @{ $has_not } );
    }

    return;
}

# helper that will check to see if a Sidenav
# option can be found in the list provided
sub _find_sidenav_option {
    my ( $self, $options, $to_find ) = @_;

    foreach my $link ( keys %{ $options } ) {
        my $url = $options->{ $link };
        # check to see if the $url is a reference, if
        # it is then this is a section and drill down
        if ( ref( $url ) ) {
            # recursive call to drill down
            return 1    if ( $self->_find_sidenav_option( $options->{ $link }, $to_find ) );
        }
        else {
            return 1    if ( lc( $to_find ) eq lc( $link ) );
        }
    }

    return 0;
}

my %template_data_to_save;
sub _update_correspodence_table {
    my ($self, $args ) = @_;

    my $schema = Test::XTracker::Data->get_schema;
    my $cms    = $schema->resultset('Public::CorrespondenceTemplate')->find($args->{template_id});

    if( $cms && exists $args->{content} ){
        # save data to restore latter
        $template_data_to_save{$cms->id}{content}      = $cms->content;
        $template_data_to_save{$cms->id}{cms_id}       = $cms->id_for_cms;
        $template_data_to_save{$cms->id}{content_type} = $cms->content_type;

        $cms->update( {
            content      => $args->{content},
            id_for_cms   => $cms->{id_for_cms}|| '',
            content_type => $args->{content_type},
         });
    }

    return $cms;

}

sub _restore_correspodence_table {
    my ( $self, $template_id ) = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $template    = $schema->resultset('Public::CorrespondenceTemplate')->find( $template_id );

    if( exists($template_data_to_save{$template_id}) ) {
        $template->update({
            content      => $template_data_to_save{$template_id}{content},
            id_for_cms   => $template_data_to_save{$template_id}{cms_id} || undef,
            content_type => $template_data_to_save{$template_id}{content_type},
        });
        delete $template_data_to_save{$template_id};
    }

    $template->discard_changes();
}

sub _test_email_data {
    my $self = shift;
    my $form = shift;
    my $args = shift;

    return if ( $args->{should_send_email} // 'yes' ) eq 'no';  # Do not do anything unless we're sending an email

    is($form->param("email_body") , $args->{content}, "Email body is as expected");
    is($form->param("email_content_type"), $args->{content_type}, "Email 'Content Type' is as expected");

    # test any other email params that have been asked for
    my @other_to_test   = grep { m/^email_/ } keys %{ $args };
    foreach my $param ( @other_to_test ) {
        is( $form->param( $param ), $args->{ $param }, "Email '${param}' is as expected: '$args->{$param}'" );
    }
}

=head2 set_session_roles( \@paths )

Set the Roles in the Current Session that are required to access the given
C<@paths>.

=cut

sub set_session_roles {
    my ( $self, $paths ) = @_;

    # make it an Array Ref if it's not already
    $paths = ( ref( $paths ) ? $paths : [ $paths ] );

    $self->session->replace_acl_roles(
        $self->get_roles_for_url_paths( $paths ),
    );

    return;

}

no Moose::Exporter;
no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
