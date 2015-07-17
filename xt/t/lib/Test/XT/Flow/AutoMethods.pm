package Test::XT::Flow::AutoMethods;

use NAP::policy "tt", qw( test role );

use Carp qw(croak carp shortmess);
use Data::Dump qw(dump);
use URI;

=head1 NAME

Test::XT::Flow::AutoMethods - Easily create simple methods for Flow libraries

=head1 DESCRIPTION

Easily create simple methods for Flow libraries

=head1 SYNOPSIS

 package Test::XT::Flow::MyLibrary;
 ...
 with 'Test::XT::Flow::AutoMethods';

 ...

 __PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__mylibrary__foo_bar_baz',
    page_description => 'Foo Bar Baz page',
    page_url         => '/foo/bar/baz?product_id=',
    required_param   => 'Product ID',
 );

 # You now have a flow_mech__mylibrary__foo_bar_baz method which retrieves
 # /foo/bar/baz?product_id= and enforces an argument. See docs below for more
 # details

=head1 WHY

Many of the flow methods are very simple and repetitive. Not all, but many. If
you pull this role in to your Flow library, it gives you helper methods to
create some of the more boring methods.

=head1 HELPER METHODS

=head2 const

Looks up and returns a constant from XTracker::Constants::FromDB. Useful for use
in C<transform_fields>-esque anon subs. ie:

 transform_fields => sub {
    { cancel_reason_id => $_[0]->const('CUSTOMER_ISSUE_TYPE__8__OTHER') }
 }

This is fatal if the constant you're after is undefined.

=cut

sub const {
    my ( $class, $constant ) = @_;

    $constant = "XTracker::Constants::FromDB::$constant";
    # Nasty soft-ref lookup
    my $value;
    { no strict 'refs'; $value = ${$constant}; } ## no critic (ProhibitNoStrict)
    # Get upset if we couldn't find it
    die "Can't find $constant" unless defined $value;
    # Give it back!
    return $value;
}

=head1 METHOD CREATION METHODS

=head2 create_fetch_method

 __PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__inventory_stockquarantine',
    page_description => 'Stock Quarantine Page',
    page_url         => '/StockControl/Inventory/StockQuarantine?product_id=',
    required_param   => 'Product ID',
    use_referer_work_around => 1,
 );

Creates a method that retrieves a URL - and all the other nice testing gubbings
around that. Arguments:

B<Required:>

C<method_name> - name of the method to create

C<page_description> - what's the page called? Used for diagnostics

C<page_url> - the page to fetch

B<Optional:>

C<assert_location> - Argument to pass to L<Test::XT::Flow>'s C<assert_location>

C<required_param> - If your URL needs a trailing atom to complete it, set
this to a true value. The user of the method will be required to provide an
argument, and it'll be named (in diagnostic output) to the value you assigned
it.

C<use_referer_work_around> - There is a BUG in WWW::Mechanize that doesn't set
the 'Referer' Header correctly with some requests, if this is a problem use this
to work around the bug.

That means, in the value above, when you call the method, you also must provide
an argument:

 $framework->flow_mech__stockcontrol__inventory_stockquarantine( 1234 );

There will be a diagnostic method printed:

 # Product ID is [1234]

And the following URL will be retrieved:

 C</StockControl/Inventory/StockQuarantine?product_id=1234>

C<params> - If you instead of a single atom need multiple key/value
pairs, provide a list of param names here, and then pass a hashref to
the flow method:

 $framework->flow_mech__customercare__edit_shipment({ order_id => 23, shipment_id => 42 }});

 C</CustomerCare/OrderSearch/EditShipment?order_id=23&shipment_id=42>

Note that you can use either of required_param or params, not both
(since it changes how the first argument to the flow method is used).

=cut

sub create_fetch_method {
    my ( $class, %args ) = @_;

    # This is a good place to check a user is using it correctly...
    $class->_auto_methods_check_params(\%args,
        {
            required => [qw/method_name page_description page_url/],
            optional => [qw/assert_location
                            assert_login_page
                            required_param
                            params
                            use_referer_work_around
                        /],
        });
    if($args{'required_param'} && $args{'params'}) {
        croak("You can only provide either of 'required_param' or 'params', but not both");
    }

    $class->meta->add_method(
        $args{'method_name'} => sub {
            my ( $self, $atom ) = @_;
            $self->show_method_name( $args{'method_name'}, $atom );
            croak("You must provide a $args{'required_param'}")
                if ( $args{'required_param'} && (! defined($atom) ) );
            my $timer = Test::XT::Flow::TimedGuard->new;
            $self->assert_location( $args{'assert_location'} ) if
                defined $args{'assert_location'};
            $self->assert_login_page if defined $args{'assert_login_page'};
            $self->indent_note("Retrieving the $args{'page_description'}");

            my $target_url = $args{'page_url'};
            if($args{'required_param'}) {
                $target_url .= $atom if defined $atom;
            }
            if($args{'params'}) {
                my $uri = URI->new($target_url);
                $uri->query_form(%$atom);
                $target_url = $uri->as_string;
            }

            if ( $args{'use_referer_work_around'} ) {
                $self->_referer_work_around( sub {
                    $self->mech->get( $target_url );
                } );
            }
            else {
                $self->mech->get( $target_url );
            }

            $self->note_status();
            $self->indent_note("Retrieved the $args{'page_description'}");
            return $self;
        }
    );
}

=head2 create_scan_method

 __PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__picking_submit',
    scan_description => 'shipment id',
    assert_location  => '/Fulfilment/Picking'
 );

Creates a method that wraps L<Test::XT::Flow>'s scan method, and places a value
in the first box it finds, and hits submit.

Arguments:

B<Required:>

C<method_name> - name of the method to create

C<scan_description> - what are you scanning? Used for diagnostics

B<Optional:>

C<assert_location> - Argument to pass to L<Test::XT::Flow>'s C<assert_location>

The above example, when called as below, checks we're on a page with the URL
C</Fulfilment/Picking>, displays the message "Scanning the shipment id", and
places the supplied value (1234) in to the first text box on the page, and
submits the form it belonged to:

 $framework->flow_mech__fulfilment__picking_submit( 1234 );

=cut

sub create_scan_method {
    my ( $class, %args ) = @_;

    # This is a good place to check a user is using it correctly...
    $class->_auto_methods_check_params(\%args,
        {
            required => [qw/method_name scan_description/],
            optional => [qw/assert_location/],
        });

    $class->meta->add_method(
        $args{'method_name'} => sub {
            my ( $self, $value ) = @_;

            # Automatically have Barcode objects represent themselves
            # as the fully scanned barcode value
            if(blessed($value) && $value->can("as_barcode")) {
                $value = $value->as_barcode;
            }

            $self->show_method_name( $args{'method_name'}, $value );
            my $timer = Test::XT::Flow::TimedGuard->new;
            $self->assert_location( $args{'assert_location'} )
                if defined $args{'assert_location'};

            {
                local $Carp::CarpLevel = 1;
                diag shortmess("Scanning a blank value - that's unusual")
                    unless defined $value;
            }

            $self->indent_note("Scanning the $args{'scan_description'}");
            $self->scan( $value );

            return $self;
        }
    );
}

=head2 create_form_method

 __PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packingexception_comment',
    form_name         => 'add_comments',
    form_description  => 'comment form',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
    transform_fields  => sub {
        my $note_text = $_[1];
        note "\tnote_text: [$note_text]";
        return { note_text => $note_text }
    },
 );

For great justice! Finds a form on a page and submits it.

Arguments:

B<Required:>

C<method_name> - name of the method to create

C<form_name> - the name attribute of the target form. Passed to
L<WWW::Mechanize>'s C<form_name()> method. You can pass in a coderef
here, which will get called just like C<transform_fields> and should
return a string.

C<form_description> - the human-readable description of the form you're
submitting. You don't need to append the word 'form' to this.

C<assert_location> - argument to pass to L<Test::XT::Flow>'s C<assert_location>

B<Optional:>

C<transform_fields> - a code-ref. Will receive $self and the methods arguments,
and expects you to return a hash-ref suitable for passing to L<WWW::Mechanize>'s
C<set_fields> method. This is a great place to put in default arguments, and
also a great place to use C<note()> to tell the test output reader what's going
on.

C<form_button> - argument to pass to L<WWW::Mechanize>'s C<submit_form> value
as C<button>. Used for specifying which button to use to submit a form. This is
a string of the button name. You can pass in a coderef here, which will get
called just like C<transform_fields> and should return a string.

The above example, called as:

 $flow->flow_mech__fulfilment__packingexception_comment( "Comment text" );

will check we're on the right page, find a form with the name C<comment_form>,
and submit it, with the field C<note_text> set to "Comment text".

=cut

sub create_form_method {
    my ( $class, %args ) = @_;

    # This is a good place to check a user is using it correctly...
    $class->_auto_methods_check_params(\%args,
        {
            required => [qw/
                method_name form_name form_description assert_location
            /],
            optional => ['form_button', 'transform_fields'],
        });

    $class->meta->add_method(
        $args{'method_name'} => sub {
            my ( $self, @user_options ) = @_;
            $self->show_method_name( $args{'method_name'}, @user_options );
            my $timer = Test::XT::Flow::TimedGuard->new;

            $self->assert_location( $args{'assert_location'} )
                if defined $args{'assert_location'};

            my $transformed_fields = $args{'transform_fields'} ?
                $args{'transform_fields'}->( $self, @user_options ) : {};

            $self->indent_note("Searching for the $args{'form_description'} form");

            my $name = ref($args{'form_name'}) eq 'CODE' ?
                $args{'form_name'}->( $self, @user_options ) :
                $args{'form_name'};
            my $form = $self->mech->form_name( $name );

            unless ( $form ) {
                croak "Couldn't find a form with name $name";
            }

            $self->mech->set_fields( %$transformed_fields );

            my $button = ref($args{'form_button'}) eq 'CODE' ?
                $args{'form_button'}->( $self, @user_options ) :
                $args{'form_button'};

            $self->indent_note("Submitting $args{'form_description'} form");
            $self->mech->submit_form(
                fields => $transformed_fields,
                $button ? ( button => $button ) : ()
            );

            $self->note_status;
            return $self;
        }
    );
}

=head2 create_link_method

 __PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__picking_incompletepick',
    link_description => 'Incomplete Pick',
    find_link        => { text => 'Incomplete Pick' },
    assert_location  => '/Fulfilment/Picking/PickShipment',
    use_referer_work_around => 1,
 );

Creates a method that finds a link on the current page and clicks it.

Arguments:

B<Required:>

C<method_name> - name of the method to create

C<link_description> - what are you clicking? Human-readable, and used for
diagnostics only

B<Optional:>

C<assert_location> - Argument to pass to L<Test::XT::Flow>'s C<assert_location>

C<find_link> - what we pass to L<WWW::Mechanize>'s C<find_link> method to
identify the link we want to click.

C<transform_fields> - a code-ref. Will receive $self and the methods arguments,
and expects you to return a hash-ref suitable for passing to L<WWW::Mechanize>'s
C<find_link> method. If you want to search for a link more specifically, and
allow people to pass in, say, a shipment_id, this would be a good way of doing
it.

C<use_referer_work_around> - There is a BUG in WWW::Mechanize that doesn't set
the 'Referer' Header correctly with some requests, if this is a problem use this
to work around the bug.

B<<One, and only one, of C<find_link> and C<transform_fields> must be set>>

The above example, when called checks we're on
C</Fulfilment/Picking/PickShipment>, and finds and clicks a link with the text
'Incomplete Pick'.

Alternatively, the following example finds and clicks on some link on
the page C</Fulfilment/OnHold>, whose specific details must be defined at run-time:

 __PACKAGE__->create_link_method(
     method_name      => 'flow_mech__fulfilment__on_hold__select_incomplete_pick_shipment',
     link_description => 'Select Shipment On Hold',
     assert_location  => qr!^/Fulfilment/OnHold!
 );

Then, to click on a link on that page whose text matches a specific shipment id,
and that links to the OrderView page with the corresponding order id, do:

 $framework->flow_mech__fulfilment__on_hold__select_incomplete_pick_shipment( {
     text      => $shipment_id,
     url_regex => qr!^/Fulfilment/OnHold/OrderView\?order_id=\d+!
 } );


=cut

sub create_link_method {
    my ( $class, %args ) = @_;

    # This is a good place to check a user is using it correctly...
    $class->_auto_methods_check_params(\%args,
        {
            required => [qw/method_name link_description/],
            optional => [qw/assert_location find_link transform_fields use_referer_work_around/],
        });

    croak("Either find_link or transform_fields must be set")
        unless ( $args{'find_link'} || $args{'transform_fields'} );

    croak("Only one of find_link or transform_fields may be set")
        if ( $args{'find_link'} && $args{'transform_fields'} );

    $class->meta->add_method(
        $args{'method_name'} => sub {
            my ( $self, @user_options ) = @_;
            $self->show_method_name( $args{'method_name'}, @user_options );
            my $timer = Test::XT::Flow::TimedGuard->new;
            $self->assert_location( $args{'assert_location'} )
                if defined $args{'assert_location'};

            $self->indent_note("Searching for the $args{'link_description'} link");
            my $link_options = $args{'find_link'} ||
                $args{'transform_fields'}->( $self, @user_options );
            my $link = $self->mech->find_link( %{ $link_options } );

            unless ( $link ) {
                croak "Couldn't find a link matching your description: " .
                    dump( $link_options );
            }
            my $url = $link->url;

            if ( $args{'use_referer_work_around'} ) {
                $self->_referer_work_around( sub {
                    $self->mech->get( $url );
                } );
            }
            else {
                $self->mech->get( $url );
            }

            $self->note_status;

            return $self;
        }
    );
}

=head2 create_custom_method

 __PACKAGE__->create_custom_method(
    method_name       => 'flow_mech__fulfilment__packingexception_comment',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
    handler           => sub {
        my $note_text = $_[1];
        note "\tnote_text: [$note_text]";
        return { note_text => $note_text }
    },
 );

You almost certainly DO NO NEED TO USE THIS. Instead, work out how to use
C<create_form_method> or simplify your method. That said:

Arguments:

B<Required:>

C<method_name> - name of the method to create

C<handler> - sub ref we hand off to

B<Optional:>

C<assert_location> - argument to pass to L<Test::XT::Flow>'s C<assert_location>

=cut

sub create_custom_method {
    my ( $class, %args ) = @_;

    # This is a good place to check a user is using it correctly...
    $class->_auto_methods_check_params(\%args,
        {
            required => [qw/method_name handler/],
            optional => [qw/assert_location/],
        });

    $class->meta->add_method(
        $args{'method_name'} => sub {
            my ( $self, @args ) = @_;
            $self->show_method_name( $args{'method_name'}, @args );
            my $timer = Test::XT::Flow::TimedGuard->new;
            $self->assert_location( $args{'assert_location'} )
                if defined $args{'assert_location'};

            return $args{'handler'}->( $self, @args );
        }
    );
}

sub _auto_methods_check_params {
    my ( $class, $args, $spec ) = @_;
    for my $key ( @{$spec->{'required'}} ) {
        unless ( defined $args->{$key} ) {
            croak("You must provide a [$key]");
        }
    }
    my %all_keys = map {$_ => 1}
        (@{$spec->{'required'}}, @{$spec->{'optional'}});
    for my $key ( keys %{$args} ) {
        unless ( $all_keys{ $key } ) {
            croak("Unknown option [$key]");
        }
    }
}

# This works round a bug in WWW::Mechanize where the
# 'Referer' Header is not set correctly, this method
# will use the current URI as the Referer and then
# make a request, it will then Remove the Header or
# set it back to its previous value if it had been
# previously set by a prior test.
#
# Pass in a code ref which will be called to actually
# make the request.
sub _referer_work_around {
    my ( $self, $request_code_ref ) = @_;

    my $referer_header;
    # Bad Practice: WWW::Mechanize doesn't provide a method to get the Headers
    # so I have to delve into its internal 'headers' hash where it stores them
    my $referer_header_exists = exists( $self->mech->{headers}{Referer} );
    $referer_header = $self->mech->{headers}{Referer}   if ( $referer_header_exists );

    $self->indent_note( "Setting 'Referer' Header for Request to be: '" . $self->mech->uri . "'" );
    $self->mech->add_header( Referer => $self->mech->uri );

    # make what ever request has been asked for
    my $retval = $request_code_ref->();

    # either restore the Header or remove it
    if ( $referer_header_exists ) {
        $self->mech->add_header( Referer => $referer_header );
    }
    else {
        $self->mech->delete_header('Referer');
    }

    return $retval;
}


package Test::XT::Flow::TimedGuard; ## no critic(ProhibitMultiplePackages)

=head1 NAME

Test::XT::Flow::TimedGuard - simple elapsed time logger

=head1 SYNOPSIS

  use Test::XT::Flow::TimedGuard;

  sub some_slow_method {
    my $timer = Test::XT::Flow::TimedGuard->new;
    # do something...
  }

=head1 DESCRIPTION

This is a tiny class to make logging time spent in a method easy. Instances of
the object record the time at which they are instantiated and then log the
elapsed time when they go out of scope, along with the name of the sub in which
they were created.

=cut

use Time::HiRes 'gettimeofday';
use Readonly;

Readonly my $XT_FLOW_TIMING_LOG => $ENV{XT_FLOW_TIMING_LOG} || 't/tmp/flow_timing.log';

sub new {
    my $start_time = gettimeofday;
    my $caller_name = ( caller(1) )[3];
    return bless {
        start_time => $start_time,
        method_name => $caller_name,
    }, __PACKAGE__;
}

sub DESTROY {
    my $self = shift;
    my $end_time = gettimeofday;
    # log flow method time to file
    if ( open( my $fh, '>>', $XT_FLOW_TIMING_LOG ) ) {
        print $fh $self->{method_name}.','.( $end_time - $self->{start_time} )."\n";
        close $fh;
    }
}

1;
