package Test::XTracker::Artifacts::RAVNI;

=head1 NAME

Test::XTracker::Artifacts::RAVNI

=head2 DESCRIPTION

Monitor RAVNI's receipt directory for new messages

=head2 SYNOPSIS

 # Start monitoring
 my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new();

 ... do some stuff ...

 # See what's been added - returns Test::XTracker::Artifacts::RAVNI::Receipt objects
 my @receipts = $receipt_directory->new_files;

 # Those have some useful methods
 for my $receipt ( @receipts ) {
    print "Path        : " . $receipt->path    . "\n"; # Path name
    print "Payload     : " . $receipt->payload . "\n"; # JSON data
    print "Payload Data: " . Dumper( $receipt->payload_parsed ); # JSON data parsed
 }

=cut

use Moose;
extends 'Test::XTracker::Artifacts';
use Test::XTracker::MessageQueue;

use File::Slurp;
use JSON;
use Carp qw(confess);
use Scalar::Util qw/reftype/;
use Data::Dump qw(dump pp);

use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local qw/config_var/;

use Test::More;
use Test::XTracker::Overlay;
use Test::XTracker::Data;
use Net::Stomp::MooseHelpers::ReadTrace;

=head1 Test::XTracker::Artifacts::RAVNI METHODS

=head2 new

 my $dir = Test::XTracker::Artifacts::RAVNI->new(
    read_directory => $messaging_config->{'Consumer::XTWMS'}->{receipt_dir},
 );

Instantiate our monitor. All existing files in the print directory are counted
as 'seen', so that only new files are returned by C<new_files>.

B<Unlike most other subclasses of Artifacts::, there is no sensible default
read_directory set - it's a required attribute.> Most likely you'll be wanting
to look in one of two receipt directories:

 $messaging_config->{'Consumer::XTWMS'}->{receipt_dir},
 $messaging_config->{'Consumer::PRL'}->{receipt_dir},

(where C<$messaging_config> is what you get from C<<
Test::XTracker::Config->messaging_config >>)

B<NOTE FROM PETE:> I finally snapped because of all the cargo-culting repeat
shit we ended up doing for invoking these things involving "what phase am I in?"
etc. I am as a guilty as anyone for that. But also irritated by it. SO, you can
also just ignore all the bullshit above and pass in one of the following:
C<xt_to_wms> or C<wms_to_xt>. This will set up the other arguments sensibly and
in a phase-dependent way.

=cut

my $messaging_config = Test::XTracker::Config->messaging_config;

our %simple_configs = (
    # There is always an XT, so we point at the receipts directory for it.
    # Simples.
    'wms_to_xt' => {
        read_directory => $messaging_config->{'Consumer::XTWMS'}->{receipt_dir},
        filter_regex   => qr/xt_wms_(?:fulfilment|inventory|printing)$/,
        title          => 'WMS-to-XT',
    },
    'stock_topic' => {
        read_directory => config_var('Model::MessageQueue', 'args')->{trace_basedir}.'/_topic_stock_updates',
        title          => 'Stock Updates',
    },
    'prls_to_xt' => {
        read_directory => $messaging_config->{'Consumer::PRL'}->{receipt_dir},
        filter_regex   => qr/dc\d_xt_prl$/,
        title          => 'PRL-to-XT',
    },
    'xt_to_prls' => {
        read_directory => [
            @Test::XTracker::Data::prl_queue_dirs
        ],
        title          => 'XT to PRLs',
    },
);

# IWS-phase
if ( config_var('IWS', 'rollout_phase') ) {
    # As we don't actually talk to the IWS, there are no receipts for messages
    # send to IWS. Instead we look at the dump directory, where XT will have
    # deposited the messages, for messages that were attempted to the IWS
    # queues.
    $simple_configs{'xt_to_wms'} = {
        read_directory => [
            @Test::XTracker::Data::iws_queue_dirs
        ],
        title          => 'XT-to-WMS (Phase 1/2)',
    };

# Phase 0
} else {
    # RAVNI actually reads and writes receipts for every message it receives
    # (and RAVNI not IWS is the target WMS in Phase 0) so we can just use the
    # RAVNI receipts directory here
    $simple_configs{'xt_to_wms'} = {
        read_directory => $messaging_config->{'Consumer::RavniWMS'}->{receipt_dir},
        filter_regex   => $Test::XTracker::Data::iws_queue_dir_regex,
        title          => 'XT-to-WMS (Phase 0)',
    };
}

has '+important_events' => (
    required => 0,
    default => sub { ['create'] },
);

has frame_reader => (
    is => 'ro',
    lazy_build => 1,
);
sub _build_frame_reader {
    my ($self) = @_;

    return Net::Stomp::MooseHelpers::ReadTrace->new({
        trace_basedir => '/tmp', # not actually used
    });
}


# Multiply out the simple config
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0] ) {
        my $config = $simple_configs{ $_[0] };
        die "Unknown config option " . $_[0] unless $config;
        return $class->$orig($config);

    } else {
        return $class->$orig(@_);
    }
};

=head2 new_files

 my @docs = $dir->new_files;

Returns a list representing new files in the monitored directory since you last
called this method (or since the object was instantiated). Only files that look
like receipts will be returned (that is, they match: C</__queue_/>)
and files will be returned as C<Test::XTracker::Artifacts::RAVNI::File> objects.

=head2 wait_for_new_files

 my @docs = $dir->wait_for_new_files(
    seconds      => 5, # How many seconds to wait for
    files        => 2, # How many new files we're looking for
 );

This method is for dealing with test race-conditions that could occur due to
two different processes communicating asynchronously. This method loops around
C<new_files>, and returns whatever it found when either condition is true.

Why two conditions? Because a naïve implementation would just return when it
had found a file, and we might be expecting more than one file. We also don't
want to wait forever (or longer than we have to) for files.

C<seconds> defaults to 30, and C<files> defaults to 1.

=cut

# Turn a filename in to a Test::XTracker::Artifacts::RAVNI::File object
sub process_file {
    my ( $self, $event_type, $full_path, $rel_path ) = @_;

    my $parse_tries = 3;

PARSEFILE:
    my $frame;
    while (!$frame && $parse_tries) {
        $frame = $self->frame_reader
            ->read_frame_from_filename($full_path);
        if (!$frame) {
            diag "Failed to load the contents of $full_path via JSON";
            if ( --$parse_tries ) {
                diag "Trying again in one second...";
                sleep 1;
            } else {
                diag "That's a show stopper, so bailing out";
                confess "Unable to parse RAVNI receipt";
            }
        }
    }

    my $frame_body = NAP::Messaging::Serialiser->deserialise($frame->body);

    my %receipt = ( filename => $rel_path, full_path => $full_path );

    $receipt{'path'}    = $frame->headers->{'destination'};
    $receipt{'payload'} = $frame_body;
    $receipt{'status'}  = $frame_body->{'response_status'}
        if exists $frame_body->{'response_status'};
    $receipt{'errors'}  = $frame_body->{'errors'}
        if exists $frame_body->{'errors'};
    $receipt{'headers'} = $frame->headers;
    $receipt{'payload_parsed'} = $frame_body->{body} // $frame_body;

    return Test::XTracker::Artifacts::RAVNI::Receipt->new(%receipt);
}

=head2 expect_messages

Await and consume one or more messages, according to the specification given.
If any messages are found that are not accounted for, complain.

All messages specified must already be in the queue, or must arrive during
the timeout period, or it's a fail.  Each matching message produces an ok-type result.

Messages can arrive in any order -- if you want to impose an ordering, chain together
calls to C<expect_messages> in the order you want.

The sole argument is a ref to a hash with the following contents:

    $ARG => {
        seconds => 5,
        messages => [
            {   name => 'Nice name for test reporting',
                path => '/queue-foo',
                type  => 'some_type',
                details => {
                    key1 => 'literal-value',
                    key2 => qr/regex-value/,
                    ...
                }
            },
            {   path => qr/regex-bar-path/,
                type  => 'some_other_type',
                details => {
                    bleem => 'literal-bleem',
                    floob => { quux => 'Underpants Gnomes' }
                    ...
                }
            },
            ...
        ],
        unexpected => [
            {   name => 'Nice name for test reporting',
                path => '/queue-baz',
                type  => 'some_unwanted_type',
                details => {
                    oh_no => 'this-cant-be-happening',
                    i_dont => qr/believe-it/,
                    ...
                }
            },

    }

The I<seconds> argument is optional, and is defined as with wait_for_new_files.

I<type> _must_ be provided, and must match the C<@type> attribute of the message.
(I<@type> is allowed as an alias for C<type>).

If provided, I<path> must match the I<path> attribute in the message.

If the I<details> hash is provided, then each of its keys must match a corresponding
key in the message's parsed payload, and the value provided in I<details> must
match the corresponding payload key's value.

Each value provided for any of I<details>' keys, or for I<type> or I<path>, may be
either a literal, a regex, or a list- or hash-ref.  Literals and regexes are matched
against the value directly, while refs to a list or a hash are matched using
I<Test::XTracker::Overlay::overlay>.

(Talk me into allowing them to be subroutines too, why not?)

The way this operates is slightly clunky, but probably acceptable.  We count
the number of elements in the I<message> array, and invoke C<wait_for_new_files>
for that number of files, and with the optional I<seconds> argument provided. We then
apply the rules in the I<details> array to the captured messages; the I<details> rules
are applied in order, and each rule is applied exactly once.

In addition to specifying the messages you expect to see in C<messages>, you may
also optionally specify messages you do I<not> want to see, using
the C<unexpected> hash element.  Messages in C<unexpected> do
not count towards the total number of expected messages, but if
any of them are in the queue, or show up while unreceived
expected messages are being waited for, then they represent
immediate C<fail>s.

C<expect_messages> returns a list of the messages it found in the order it found them.
Note that this order will reflect the order of rules in the I<details> array, and, as
such, may not reflect the order of arrival of the messages.

Note that there is presently no way to wait for unexpected messages only.

=cut


=head2 _matches

Cheep'n'cheerful smart-matchey doohickey to help expect_messages do its thang.

=cut

# Works out if a given message matches a reference
my %reasonable_keys = ( map { $_ => 1 } ('@type', qw(type path details) ) );
sub _message_matches {
    my ($self,  $ref, $found ) = @_;

    for my $key ( keys %$ref ) {
        next if $reasonable_keys{ $key };
        diag "HEY! expect_messages doesn't work like that!";
        diag "If you're trying to match message details (which is what I assume [$key] is)";
        diag "then it needs to be in a details hash";
    }

    # Let's deal directly with the payload
    my $found_pp = $found->{'payload_parsed'};

    # Check at least a type has been specified in the ref
    my $ref_type = $ref->{'type'} || $ref->{'@type'};
    confess "No type specified" unless $ref_type;

    # Match the type
    return unless $self->_matches( $found->{headers}{type}, $ref_type );

    # Match the path if specified
    if ( exists $ref->{'path'} ) {
        return unless $self->_matches( $found->{'path'}, $ref->{'path'} );
    }

    # Match the response status
    if ( exists $ref->{'status'} ) {
        return unless $self->_matches( $found->{'status'}, $ref->{'status'} );
    }

    # Match the details if specified
    if (exists $ref->{details} && %{$ref->{details}}) {
        foreach my $detail (keys %{$ref->{details}}) {
            unless (
                exists $found_pp->{$detail} &&
                $self->_matches( $found_pp->{$detail}, $ref->{details}->{$detail} )
            ) {
                return;
            }
        }
    }

    return 1;
}

sub _matches {
    my ($self, $left,$right) = @_;

    # Normalize the data structures according to how AMQ message
    # payloads are rendered.
    my $preprocessor = Test::XTracker::MessageQueue->preprocessor;
    $left  = $preprocessor->visit($left);
    $right = $preprocessor->visit($right);

    # policy decision -- undef does not match undef
    return unless defined $left && defined $right;

    if    (ref $left  eq ref qr//)       { $right =~ $left; }
    elsif (ref $right eq ref qr//)       { $left =~ $right; }
    elsif (!defined reftype($right))     { $left eq $right; }
    else  {Test::XTracker::Overlay::overlay($left, $right);}
}

sub _simple_message_summary {
    my $msg = shift;
    my $summary = pp $msg;
    return $summary;
}

=head2 expect_no_messages

Checks that no messages have been sent. Only use this test if you're checking
for files created in-process, as it doesn't wait for new files so is liable to
fail with timing issues.

=cut

sub expect_no_messages {
    my $self = shift;

    my @messages_queued = $self->new_files;

    is( scalar(@messages_queued), 0, "Found 0 messages, as expected" )
        or map { fail "Found a message matching: " . dump( $_ ) } @messages_queued;
}

sub expect_messages {
    my ($self,$args) = @_;

    # Take a count of how many we're looking for
    my $expected_message_count   = @{$args->{'messages'}||[]};
    my $unexpected_message_count = @{$args->{'unexpected'}||[]};

    die "Must provide some expected or unexpected message details"
        unless $expected_message_count + $unexpected_message_count;

    # If we're only checking for unexpected messages, just wait for one. If you
    # do this (AND PLEASE DON'T) it's the equivalent of putting a sleep 60 in
    # your code.
    my $message_count = $expected_message_count;

    if (! $expected_message_count) {
        unless ( $args->{'seconds'} ) {
            diag "If you search for unexpected messages only, it's like having";
            diag "a gratuitous 60 seconds sleep in your file. Please don't do";
            diag "this.";
        }

        $message_count = $unexpected_message_count;
    }

    # wait_for_new_files()
    my @messages_queued = $self->wait_for_new_files(
        files  => $message_count,
        no_die => 1,
        # Set seconds if specified
        ( exists $args->{'seconds'} ? (seconds => $args->{'seconds'}) : () ),
    );

    # Check we received the right number back
    is( scalar(@messages_queued), $expected_message_count,
        "Found $expected_message_count messages, as expected" );

    # Simple step-through looking for unexpected messages
    for my $message (@messages_queued) {
        my @unexpected_matches = grep { $self->_message_matches( $_, $message ) }
            @{$args->{unexpected}};
        if ( @unexpected_matches ) {
            diag "*** '".$self->title."' Messages you had explicitly said";
            diag "*** shouldn't appear have appeared!";
            diag "***";
            diag "*** Here was the message that was matched:";
            diag "***";
            diag dump( $message );
            diag "***";
            diag "*** This is the forbidden specification it matched:";
            diag "***";
            diag dump( $unexpected_matches[0] );
            fail "Specifically forbidden message found";
            return;
        }
    }

    # Sort the expected message by specificity
    my @expected_messages = sort {
        # Sort by type first
        ( ($b->{'type'} || $b->{'@type'}) cmp ($a->{'type'} || $a->{'@type'}) ) ||
        # Try sorting by path
        ( ($b->{'path'}||'') cmp ($a->{'path'}||'') ) ||
        # Number of details keys?
        ( scalar(keys( %{$b->{'detail'}||{}} ) ) <=> scalar(keys( %{$a->{'detail'}||{}} ) ) )
    } @{$args->{messages}||[]};

    my @correctly_found;

    # Look for each message
    for my $expected ( @expected_messages ) {
        my $found = 0;
        @messages_queued = grep {
            my $msg = $_;
            # Does the message match?
            if ( $self->_message_matches( $expected, $msg ) ) {
                # It does, but we've already found one on this iteration, so let
                # it go
                if ( $found ) {
                    1;
                # No, and this is the first match, so use it.
                } else {
                    $found++;
                    push(@correctly_found, $msg);
                    0;
                }
            # Message doesn't match, let it through
            } else {
                1;
            }
        } @messages_queued;
        if ( $found ) {
            pass "Found a '".$self->title."' message matching: " . _simple_message_summary( $expected );
        } else {
            fail "Found a '".$self->title."' message matching: " . dump( $expected );
        }
    }

    for (@messages_queued) {
        fail "Found a '".$self->title."' message we weren't expecting: " . dump( $_ );
    }

    return @correctly_found;
}

package Test::XTracker::Artifacts::RAVNI::Receipt; ## no critic(ProhibitMultiplePackages)

use strict;
use warnings;
use HTML::TreeBuilder::XPath;
use Moose;

=head1 Test::XTracker::Artifacts::RAVNI::Receipt ATTRIBUTES

=head2 path

C<destination> from the message

=head2 payload

C<body> from the message

=head2 payload_parsed

C<body> from the message, parsed as JSON

=cut

has 'filename' => ( is => 'ro', isa => 'Str' );
has 'path' => ( is => 'ro', isa => 'Str' );
has 'full_path' => ( is => 'ro', isa => 'Str' );
has 'headers' => ( is => 'ro', isa => 'Ref' );
has 'payload' => ( is => 'ro', isa => 'Ref' );
has 'payload_parsed' => ( is => 'ro', isa => 'Ref' );
has 'status' => ( is => 'ro', isa => 'Int' );
has 'errors' => ( is => 'ro', isa => 'ArrayRef' );

1;
