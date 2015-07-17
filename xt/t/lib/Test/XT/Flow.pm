package Test::XT::Flow;

use NAP::policy     qw( test );
use Moose;
extends 'Test::XT::Data';

=head1 NAME

Test::XT::Flow

=cut

use Carp qw(croak confess);


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Data::Dump qw(dump);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw();
use Storable qw(dclone);

with 'MooseX::Traits';

sub BUILD {
    my $self = shift;
    $self->tabs->{'Default'} = $self->mech;

    return $self;
}

=head1 NEW FLOW METHODS

In which we walk you through how we added the Fulfilment Picking steps.

=head2 CREATING THE ROLE

Fulfilment is the top-level URL Atom, so that makes a sensible package name

 package Test::XT::Flow::Fulfilment;

 use strict;
 use warnings;

You'll probably want the 'note' that's exported by L<Test::More> in your
namespace so you can print useful diagnostics

If you'll be monitoring the print queue, you'll want to pull in
L<Test::XTracker::PrintDocs>.

 use Test::XTracker::PrintDocs;

We need to make ourselves consumable, and require anything that consumes us to
have some methods we rely on.

 use Moose::Role;

 requires 'mech';
 requires 'note_status';
 requires 'config_var';

We can seriously simplify method creation using L<Test::XT::Flow::AutoMethods>.

 with 'Test::XT::Flow::AutoMethods';

=head2 ANATOMY OF A SIMPLE REQUEST

Coming soon...

=head1 ATTRIBUTES

This Class extends 'Test::XT::Data' so also look in that module for inherited Attributes.

=head2 mech

A C<Test::XTracker::Mechanize> object. Will create one on the fly at
instantiation if you don't specify one.

=cut

has 'mech' => (
    is       => 'rw',
    isa      => 'Test::XTracker::Mechanize',
    default  => sub { return Test::XTracker::Mechanize->new() },
    handles  => ['force_datalite', 'force_sticky_pages', 'debug_http', 'errors_are_fatal', 'logged_in_as']
);

=head2 squeeze_log_snitch

Set to 1 to have the log snitch's complain method called after every request.
This is definitely only for debugging.

=cut

has 'squeeze_log_snitch' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

=head2 permissions_history

An arrayref containing sets of permissions we've used to log in. Useful if
you need to change permissions, don't know where you were called from, and want
to change them back afterwards... Arrayref of the hashrefs you've passed to
C<login_with_permissions>.

FIFO LIST!!

=cut

has 'permissions_history' => (
    is  => 'rw',
    isa => 'ArrayRef[HashRef]',
    default => sub { [] }
);

=head2 note_success_status

Boolean switch used to turn on/off (default on) the commenting of the xTracker
Status messages when a request is successful by the 'note_status' method.

Use this if you're making a request that doesn't return HTML as not being able
to parse a document tree causes problems with that method. Useful for making
requests that return JSON.

Use the following traits to set/unset the flag:

=head2 turn_note_success_status_on

Trait used to turn ON the 'note_success_status' flag (default).

=head2 turn_note_success_status_off

Trait used to turn OFF the 'note_success_status' flag.

=cut

has note_success_status => (
    is      => 'rw',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 1,
    handles => {
        turn_note_success_status_on  => 'set',
        turn_note_success_status_off => 'unset',
    },
);

=head1 METHODS

This Class extends 'Test::XT::Data' so also look in that module for inherited Methods.

=head2 inline_force_datalite

Like a call to the force_datalite method, but returns self.

=cut

sub inline_force_datalite {
    my ( $self, $arg ) = @_;
    $self->force_datalite( $arg );
    return $self;
}

=head2 inline_force_sticky-pages

Like a call to the force_sticky_pages method, but returns self.

=cut

sub inline_force_sticky_pages {
    my ( $self, $arg ) = @_;
    $self->force_sticky_pages( $arg );
    return $self;
}

=head2 clear_sticky_pages

Forcibly remove any existing sticky page rows.

=cut

sub clear_sticky_pages {
    my ( $self ) = @_;
    $self->schema->resultset('Operator::StickyPage')->delete;
    return $self;
}

=head2 login_with_permissions

    Log-In using old Authorisation Section/Sub Section permissions:
    $framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__??? => [
                # 'Section/Sub-Section'
                'Customer Care/Customer Search',
                'Fulfilment/Packing',
                ...
            ],
            $AUTHORISATION_LEVEL__??? => [
                'Finance/Credit Hold',
            ],
            ...
        },
        dept => 'Customer Care',    # optional
    } );
            or
    Log-In using ACL Role Permissions:
    $framework->login_with_permissions( {
        roles => {
            See 'login_with_roles' for what can go here and
            as the preferred method to Log-In using ACL Roles
        },
        # using 'roles' will mean any other 'dept'
        # setting other than 'undef' will be ignored
        dept => undef,  # optional
    } );

    # and to Log-In with NO Roles and no Permissions:
    $framework->login_with_permissions( {
        roles => { },
    } );

Will Log-In to the App. as 'it.god' assigning the Permissions specified in
either the 'perms' key or the 'roles' key.

=head3 perms

Use 'perms' to specifiy a list of Main Nav options that the Operator should
be-able to access, also use the optional 'dept' key to set the Operator's
Department. This will use the old Authorisation Section/Sub-Section way of
giving permissions to the Operator.

=head3 roles

The preferred way to Log-In using Roles is to use the C<login_with_roles> method
but if you need to use this method to do it then you still can (for now!).

Use 'roles' to use ACL protection by assigning a list of ACL Roles to the
Operator. Using the 'roles' key will override any use of the 'perms' key.
You can assign Roles in various different ways. When using 'roles' the
'dept' setting will be ignored unless it's set with 'undef' in which case
it will explictly set the Operator's Department to be undefined.

See C<login_with_roles> on what can be set in the 'roles' key (ignore what
it says about 'dept' see above on how to use that with 'roles').

=cut

sub login_with_permissions {
    my ( $self, $opts ) = @_;
    my $auth = $opts->{perms} || { };
    unshift( @{ $self->permissions_history }, dclone $auth );

    # Prepare permission items:
    # [ username, main section, minor section, auth_level ]
    my @auths;
    for my $level ( keys %{$auth} ) {
        my @paths = @{$auth->{$level}};
        push(@auths, map {
            [ 'it.god', split(/\//, $_), $level ]
        } @paths );
    }

    my $args = \%{$opts};
    $args->{perms} = \@auths;

    # if using Roles, then don't use any of the old
    # 'operator_authorisation' way of giving access to
    # pages, including setting the Operator's Department
    if ( $args->{roles} ) {
        delete $args->{perms};
        # remove 'dept' unless it's been explictly asked to be 'undef'
        delete $args->{dept}    unless ( exists( $args->{dept} ) && !defined $args->{dept} );
        if ( !scalar( keys %{ $args->{roles} // {} } ) ) {
            note "NO ACL Roles have been Specified";
        }
    }

    # Execute permission items
    note "User setup and login";
    $self->mech->setup_and_login( $args );

    return $self;
}

=head2 login_with_roles

This is the preferred way to Log-In using ACL Roles.

    $framework->login_with_roles( {
        #
        # use 1 or more of the following:
        #
        # will assign these list of Roles to the Operator's session
        names => [
            'app_canDoPacking',
            ...
        ],
        # will assign all the Roles to the Operator
        # that have been assigned to these URL paths
        paths => [
            '/Finance/CreditHold',
            '/Finance/FraudHotlist%',   # using '%' will act as a wildcard
                                        # in a SQL LIKE condition
            '/Some/Other/URL',
            ...
        ],
        # will assign all the Roles to the Operator that
        # have been assigned to these Main Nav options
        main_nav => [
            'Customer Care/Order Search',
            'Finance/Credit Check',
            ...
        ],

        # optional
        setup_fallback_perms => 1,

        # logging in using roles will mean any other 'dept'
        # setting other than 'undef' will be ignored
        dept => undef,  # optional
    } );

    # and to Log-In with NO Roles and no Permissions:
    $framework->login_with_roles();
        or, to unset the department as well:
    $framework->login_with_roles( { dept => undef } );

Will Log-In to the App. as 'it.god' and assigning the ACL Roles specified
to use ACL protection in the App.

You can assign Roles in various different ways. The 'dept' setting will be
ignored unless it's set with 'undef' in which case it will explictly set
the Operator's Department to be undefined.

All or one of the following can be passed in to this method:

=head4 names

Use 'names' to just specify a list of Roles to assign to the Operator.

=head4 paths

Use 'paths' to specify a list of URL paths that have been assigned Roles
in the 'acl.url_path' table. This will get all the Roles assigned to
the paths and then assign them to the Operator. In specifying a path you
can use the '%' SQL LIKE wildcard character so that you can get Roles
for all matching Paths without having to specify them individually.

=head4 main_nav

Use 'main_nav' to specify 'Section/Sub-Section' Main Nav options that you
want the Operator to have access to. The table that links Main Nav options
to Roles ('acl.link_authorisation__authorisation_sub_section') will be used
to get a list of Roles required and then assign to the Operator.

=head4 setup_fallback_perms

Use the optional 'setup_fallback_perms' flag to have old style Authorisation
Section/Sub-Section permissions set-up for all the Main Nav options that the
Roles asked for give access to. This will always use 'Operator' as the Auth
Level.

This should be used whilst the XT Access Controls project is still incomplete
as we will need to set old style permissions for Main Nav options where some
URLs that share the same Section & Sub-Section will still need to function such
as 'Finance/CreditHold' & 'Finance/CreditHold/ChangeOrderStatus' the latter if
un-protected still needs to be set-up in the old way even if the former has
been protected. This is mainly used for the 'Order View' page which can be reached
from many different places - that might have been ACL protected - but have many
Left Hand Menu options that use the same Section/Sub-Section but haven't
been ACL protected yet.

=cut

sub login_with_roles {
    my ( $self, $args ) = @_;

    # work out if 'dept' had actually been specified
    my $exist_dept = exists( $args->{dept} );
    my $dept       = delete $args->{dept};

    # just pass everything through the 'roles' key
    return $self->login_with_permissions( {
        roles => $args // {},
        ( $exist_dept ? ( dept => $dept ) : () ),
    } );
}

=head2 note_status

Comments on the success of the last mech request, and C<note>s any XTracker
error or status messages.

=cut

sub note_status {
    my ($self, %options) = @_;
    my $displayed_url = 0;

    my $url    = $self->mech->uri->path_query;
    my $die_flag = 0;

    # Yay, that worked, parse the page and let's GO!
    if ( $self->mech->success ) {
        $self->indent_note("URL $url retrieved successfully via HTTP");

        if ( $self->note_success_status ) {
            # note_status fails with seemingly bizarre errors when the document
            # tree could not be parsed. Dumping the content here makes the problem
            # much easier to trace and fix...
            if ( $self->mech->content && !$self->mech->tree ) {
                croak "Content has not been parsed into tree: \n",
                    '<' x 70, "\n",
                    $self->mech->content, "\n",
                    '>' x 70, "\n";
            }

            my $msg_found = 0;

            for my $type (qw(error warning status info)) {
                my $method  = "app_${type}_message";
                my $message = $self->mech->$method;
                if ( $message ) {
                    $self->indent_note( ucfirst($type) . " message: $message" );
                    $msg_found++;
                }
            }

            if ( my $err_msg = $self->mech->app_error_message ) {
                if ( $self->mech->errors_are_fatal ) {
                    diag "**** XTracker HTML Error Message";
                    diag "***";
                    diag "***     errors_are_fatal : [" . $self->mech->errors_are_fatal . "]";
                    diag "***     app_error_message: [" . $err_msg . "]";
                    diag "***     Error type       : [HTML; HTTP request was fine]";
                    $die_flag++;
                }
            }
            $self->indent_note( "No status message shown" ) unless $msg_found;
        }
    } else {
        if ( $self->mech->errors_are_fatal ) {
            diag "*** XTracker HTTP Error Message";
            diag "***";
            diag "***     URL              : [$url]";
            diag "***     Error type       : [HTTP; " . $self->mech->response->status_line . "]";
            diag "***     errors_are_fatal : [" . $self->mech->errors_are_fatal . "]";
            # FOR GREAT JUSTICE! This is /far/ from guaranteed to work or be a
            # good idea ... but just imagine if it did!
            eval {
                my @error_log = `tail -n5 t/logs/error_log`; ## no critic(ProhibitBacktickOperators)
                my $out_count = 1;
                if ( @error_log ) {
                    diag "***";
                    diag "*** Here's the result of: [tail -n5 t/logs/error_log]";
                    diag "***";
                    for my $line ( @error_log ) {
                        chomp($line);
                        diag "***     $out_count: $line";
                        $out_count++;
                    }
                }
            };
            $die_flag++;
        } else {
            note "URL $url retrieval FAILED";
        }
    }

    if ( $die_flag ) {
        diag '***';
        diag "*** Here are the last three requests, most recent first:";
        diag '***    ' . $_ for map { @$_ } @{ $self->mech->last_request_debug_queue };
        diag '***';
        diag '*** If you were expecting this error message, you can turn off';
        diag '*** the \'errors_are_fatal\' flag around your method call using';
        diag '***';
        diag '***    $mech->errors_are_fatal(0) OR';
        diag '***    $flow->errors_are_fatal(0)';
        diag '***';
        diag '*** This message (and the die that\'s coming) are generated as a';
        diag '*** result of calling $flow->note_status()';
        fail("Test died; see diag output");
        confess 'Refusing to continue after action failed. See diag output.';
    }

    if ( $self->squeeze_log_snitch ) {
        $self->mech->log_snitch->complain;
    }
}

=head2 scan

Find the first text box on a field, insert the supplied value in it, and submit
the form it was in.

 $framework->scan("0123456789");

The idea is to pretend to be a barcode scanner, and make writing simple methods
simpler.

We specifically ignore text boxes called I<quick_search> form, to
prevent any quick search box on the page (likely to be at the top of
the page) from being scanned into.

=cut

sub scan {
    my ( $self, $barcode ) = @_;
    my $first_text_element =
      eval { $self->mech->find_xpath('//input[@type="text" and @name!="quick_search"]')
               ->get_node(1)->attr('name') };
    croak "Can't find a box to scan in to" if $@;

    $self->indent_note("Scanned [$barcode] into form element [$first_text_element]");

    $self->mech->submit_form( with_fields => {
        $first_text_element => $barcode
    });
    $self->note_status;

    return $self;
}

=head2 assert_location

Checks that the URL our Mechanize object is on matches a specification, or
croaks.

 $framework->assert_location( '/Exact/URL/' );

OR

 $framework->assert_location( qr!^/Less/Exact/URL/.*!$ );

Sometimes you want to be able to say several different URLs would be ok:

 $framework->assert_location([ '/Exact/URL/', qr!^/Less/Exact/URL/.*!$ ]);

Note that the login page may be hard to match with this so use the
assert_login_page method instead.

=cut

sub assert_location {
    my ( $self, $assertions ) = @_;

    # Sanity-test the obvious stuff
    my $url = (
        $self->mech->can('uri_without_overrides') ?
            $self->mech->uri_without_overrides
          : $self->mech->uri )->path_query;

    croak
        "Can't find a URL, which means your location assertion fails by default"
        unless $url;
    croak "No acceptable locations provided" unless $assertions;

    # Force an array-ref for assertions if there wasn't one (as we also accept
    # a single-argument Regexp).
    $assertions = [$assertions] unless ref($assertions) eq 'ARRAY';

    # Return if we found a match
    for my $assertion (@$assertions) {
        my $matched = 0;

        if ( $url =~ qr{\A/login}i ) {
            diag "You are matching the login page via assert_location. Use assert_login_page instead";
        }

        if ( ref($assertion) eq 'Regexp' ) {
            $matched++ if $url =~ $assertion;
        } else {
            if ( $url eq $assertion ) {
                $matched++ if $url eq $assertion;
            }
        }

        if ( $matched ) {
             $self->indent_note("URL [$url] matched assertion");
            return $self;
        }
    }

    # If we're here, no match
    diag "*** Location assertion failed, so we're about to bail out";
    diag "*** Current mech URL is: $url";
    diag "*** Allowable URL matches:";
    diag "*** \t$_" for @$assertions;
    if ( my $page_error_message = $self->mech->app_error_message ) {
        diag "*** Error message in last retrieved page - usually relevant:";
        diag "*** \t$page_error_message";
    } elsif ( my $page_status_message = $self->mech->app_status_message ) {
        diag "*** Status message in last retrieved page - might be relevant:";
        diag "*** \t$page_status_message";
    } else {
        diag "*** No Error or Status message apparent on page";
    }
    diag "*** Croaking...";
    fail("Test died; see diag output");
    confess "Location assertion failed. See diag() output for details";
}

=head2 assert_login_page

The login page can be displayed even if the url in the request path is not
for /login so the assertion for login needs to be based upon the page
content rather than the url.

=cut

sub assert_login_page {
    my $self = shift;

    if ($self->mech->find_xpath("//h1[text() = 'Login']")) {
        $self->indent_note( "Login page assertion matched" );
        return $self;
    } else {
        fail( "Test died: Should be on login page but we're not" );
        confess( "assert_login_page failed to match login page" );
    }
}

=head2 assert_sticky

Checks that the URL our Mechanize object is on is sticky, or croaks.

 $framework->assert_sticky;
 $framework->assert_sticky( no_exit => [ '/', '/StockControl/Inventory' ] );

If sticky pages are not enabled, nothing is tested and the method just returns.

If a no_exit arrayref is supplied, those particular URLs are checked to ensure they
are not visited and the sticky page is served again in response instead.

=cut

sub assert_sticky {
    my ( $self, $assertions ) = @_;

    return $self unless $self->force_sticky_pages;

    $assertions //= {};
    $assertions->{no_exit} //= [ '/' ];

    my $mech = $self->mech;

    # get current URL
    my $url = (
        $mech->can('uri_without_overrides')
            ? $self->mech->uri_without_overrides
            : $self->mech->uri)->path_query;

    note "Sticky page check for URL [$url]";

    # check each no_exit URL to ensure it's blocked by the sticky page
    for my $no_exit (@{$assertions->{no_exit}}) {
        $self->indent_note("Checking sticky page traps URL [$no_exit]");
        $mech->get( $no_exit );
        $self->assert_location($url);
    }

    # force HTML::TreeBuilder reparse :(
    $mech->_force_new_tree();

    return $self;
}

=head2 indent_note

Wraps Test::More's C<note> so that low-priority debug output is easier to
discern from more important stuff

=cut

sub indent_note {
    my ( $self, $note ) = @_;
    note "\t\t$note";
}

=head2 show_method_name

Pass in a method name (string) and the options the method received to
pretty-print it

=cut

sub show_method_name {
    my ($self, $name, @options) = @_;

    my $output = "\t->$name(";

    if ( grep { defined $_ } @options ) {
        $output .= ' ' . dump( @options ) . ' ';
    }

    $output .= ')';
    note $output;
}

=head2 without_datalite

Turn off datalite for a method call, and execute it, and then restore datalite
to its previous mode:

 $framework->without_datalite(
    flow_mech__customercare__orderview => ( $product_data->{order_object}->id )
 );

=cut

sub without_datalite {
    my ( $self, $method_name, @args ) = @_;

    if ( $self->force_datalite() ) {
        $self->force_datalite(0);
        note "Disabling datalite";
        $self->$method_name( @args );
        $self->force_datalite(1);
        note "Re-enabling datalite";
    } else {
        $self->$method_name( @args );
    }
    return $self;
}

=head2 without_sticky_pages

Turn off sticky_pages for a method call, and execute it, and then restore
sticky_pages to its previous mode:

 $framework->without_sticky_pages(
    flow_mech__customercare__orderview => ( $product_data->{order_object}->id )
 );

=cut

sub without_sticky_pages {
    my ( $self, $method_name, @args ) = @_;

    if ( $self->force_sticky_pages() ) {
        $self->force_sticky_pages(0);
        note 'Disabling sticky pages';
        $self->$method_name( @args );
        $self->force_sticky_pages(1);
        note 'Re-enabling sticky pages';
    } else {
        $self->$method_name( @args );
    }
    return $self;
}

=head2 with_iws_phase

Overrides the 'iws_phase' for a method call, and execute it, and then
restore the phase to its previous value:

 $framework->with_iws_phase(
    1,
    'flow_mech__fulfilment__packingexception__viewcontainer_putaway_ready'
 );

=cut

# TODO: Remove: CLIVE-114
sub with_iws_phase {
    my ( $self, $phase, $method_name, @args ) = @_;

    my $old_phase = $self->mech->force_override_iws_phase();

    $self->mech->force_override_iws_phase($phase);
    note "Setting phase to $phase";
    $self->$method_name( @args );
    $self->mech->force_override_iws_phase($old_phase);
    note sprintf 'Re-setting phase to %s',
        (defined $phase ? $phase : 'default');

    return $self;
}

=head2 catch_error

 $framework->catch_error(
    qr/Some error, or a string instead if you like/,
    "Name of this test",
    flow_mech__customercare__orderview => ( $product_data->{order_object}->id )
 );

Turns off errors_are_fatal, runs your method, and checks the output, turns
errors_are_fatal back on.

=cut

sub catch_error {
    my ( $self, $condition, $test_name, $method_name, @args ) = @_;
    die "You must provide a condition and a test name" unless
        $condition && $test_name;
    $self->errors_are_fatal(0);
    $self->$method_name( @args );
    $self->errors_are_fatal(1);

    my $error_message = $self->mech->app_error_message();
    unless ( $error_message ) {
        my ($package, $filename, $line) = caller;
        fail("No application error message returned at $filename line $line,"
            ." expected to see: $condition");
        return $self;
    }

    if ( ref($condition) eq 'Regexp' ) {
        like( $error_message, $condition, $test_name );
    } else {
        is( $error_message, $condition, $test_name );
    }

    return $self;
}

=head2 test_for_no_permissions

 $framework->test_for_no_permissions(
    "Name of this test",
    flow_mech__flow_method_to_call => ( @any_method_params ),
 );

Test that when the Flow Method is called that it fails
because the Operator doesn't have Permissions to access it.

=cut

sub test_for_no_permissions {
    my ( $self, $test_name, $method_name, @params ) = @_;

    return $self->catch_error(
        qr/don't have permission to/i,
        $test_name,
        $method_name => ( @params ),
    );
}

=head2 test_for_info_message

    $framework = $framework->test_for_info_message(
        qr/Some pattern to match against the message, or a string instead if you like/,
        "Name of this test",
        flow_mech__method__name => ( @param_list ),
    );

Will call the 'flow_mech__method__name' and then check that there was an
'info' message shown on the page that matches the pattern/string passed in.

Returns the 'framework' so can be used in a 'chain' of Flow methods.

=cut

sub test_for_info_message {
    my ( $self, @params ) = @_;
    return $self->_test_for_message_in_flow( 'info', @params );
}

=head2 test_for_status_message

    $framework = $framework->test_for_status_message(
        qr/Some pattern to match against the message, or a string instead if you like/,
        "Name of this test",
        flow_mech__method__name => ( @param_list ),
    );

Will call the 'flow_mech__method__name' and then check that there was a
'status' message shown on the page that matches the pattern/string passed in.

Returns the 'framework' so can be used in a 'chain' of Flow methods.

=cut

sub test_for_status_message {
    my ( $self, @params ) = @_;
    return $self->_test_for_message_in_flow( 'status', @params );
}

#
# private method to call a 'flow' method and then check
# the page for one of the following message types shown:
#
#       app_warning_message
#       app_status_message
#       app_info_message
#

sub _test_for_message_in_flow {
    my ( $self, $msg_type, $condition, $test_name, $method_name, @args ) = @_;

    $self->$method_name( @args );

    # '$msg_type' should be one of 'warning', 'status' or 'info'
    my $msg_to_get = "app_${msg_type}_message";

    my $message = $self->mech->$msg_to_get;

    if ( ref($condition) eq 'Regexp' ) {
        like( $message, $condition, $test_name );
    } else {
        is( $message, $condition, $test_name );
    }

    return $self;
}


=head1 TABS

For when you need some MORE CRACK RIGHT NOW, we have the concept of tabs.
Sometimes you're in the middle of one process, and you need to go do something
else, and you don't want to lose the page you were on.

Tabs are different underlying Mechanize objects that can be swapped in and out.
They share the same Cookie jar, so C<can't have tabs logged in as different
users>.

The default tab is called "Default". Tabs are identified by strings...

=cut

has 'tabs' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has 'current_tab' => ( is => 'rw', isa => 'Str', default => 'Default' );

sub _describe_tab_change {
    my ( $self, $from, $to ) = @_;
    note "Tab change: [$from]->[$to]";
    my $path_query
        = map { $_->status ? $_->uri->path_query : 'No open page' } $self->tabs->{$to};
    note "You are now on: [$path_query]";
    $self->show_tabs;
    return $self;
}

=head2 open_tab

 $framework->open_tab("Foo");

Clone the current tab you're on in to a new tab, and switch to it. You must use
a unique string for the new tab name

=cut

sub open_tab {
    my ( $self, $name ) = @_;
    croak "Tab [$name] already exists" if $self->tabs->{$name};

    $self->tabs->{$name} = $self->mech->clone();
    $self->tabs->{$name}->_force_new_tree() if $self->tabs->{$name}->status;

    note "Created tab [$name]";
    $self->switch_tab( $name );
    return $self;
}

=head2 switch_tab

 $framework->switch_tab("Default");

Switch from your current tab to an existing tab.

=cut

sub switch_tab {
    my ( $self, $name )  = @_;
    croak "Tab [$name] does not exist" unless $self->tabs->{$name};
    my $old_tab_name = $self->current_tab;

    $self->mech( $self->tabs->{$name} );
    $self->current_tab( $name );
    $self->_describe_tab_change( $old_tab_name, $name );
    return $self;
}

=head2 close_tab

 $framework->close_tab("Foo");

Removes a tab. If you're currently on it, switches you to "Default". If you
don't specify a tab, closes the current one, unless it's default...

=cut

sub close_tab {
    my ( $self, $name ) = @_;
    $name ||= $self->current_tab;

    croak "Tab [$name] does not exist" unless $self->tabs->{$name};
    croak "You can't delete the default tab" if $name eq 'Default';

    $self->switch_tab('Default') if $self->current_tab eq $name;
    delete $self->tabs->{$name};
    note "Closed tab [$name]";
    return $self;
}

=head2 current_tab

Returns the name of the current tab. Useful for debugging only.

=head2 show_tabs

Prints, using 'note', the current tabs. Useful for debugging only.

=cut

sub show_tabs {
    my $self = shift;
    my @tabs = sort {
        $a eq 'Default' ? -1 : (
            $b eq 'Default' ? 1 : (
                lc($a) cmp lc($b) ) )
    } keys %{ $self->tabs };

    note @tabs . " tabs:";

    for my $tab (@tabs) {
        my $string = "\t   ";
        $string =~ s/  /* / if $tab eq $self->current_tab;

        $string .= $tab . ': ';
        my $mech = $self->tabs->{$tab};
        $string .= $mech->status ? $mech->uri->path_query : 'No open page';
        note $string;
    }

    return $self;
}

sub def {
    my($self,$defined,$default) = @_;

    return defined $defined ? $defined : $default;
}

=head2 announce_method() :

Announce the caller's method name in the form "SUB some_method_name". I don't
know why we do this throughout the Flow tests in the first place but at least
doing it this way removes all the hard-coded method names in strings.

=cut

sub announce_method {
    my ($self) = @_;
    my $caller_name = (caller(1))[3];
    $caller_name =~ s/.*:://;
    note "SUB $caller_name";
}

1;
