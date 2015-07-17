package Test::XTracker::DBEncode;

use NAP::policy     qw( tt test );
use Test::XTracker::Data;
use XTracker::Config::Local qw( config_var );
use Encode;
use XTracker::DBEncode  qw( encode_db encode_it decode_it decode_db );
use Test::XTracker::Data::InternationalText;
use Unicode::Normalize  qw( NFC );
use JSON;

use parent "NAP::Test::Class";

sub start : Test( startup => no_plan ) {
    my $self = shift;

    $self->{unicode_strings} = Test::XTracker::Data::InternationalText->safe_strings();
    ok( $self->{unicode_strings}->{chinese}, "I have a chinese string" );

    use_ok( "XTracker::DBEncode" );
}

=head2 test_decode_db

Tests the decode_db function. Should decode whatever is thrown at it including
decoding double encoded data.

=cut

sub test_decode_db : Tests {
    my $self = shift;

    foreach my $test ( keys %{ $self->{unicode_strings} } ) {
        note "Testing $test";
        my $encoded = encode('UTF-8', $self->{unicode_strings}->{$test});

        ok( $encoded, "I have an encoded string" );

        my $decoded = decode_db($encoded);
        ok( $decoded, "I have a decoded string from decode_db" );

        ok( NFC($decoded) eq NFC($self->{unicode_strings}->{$test}),
            "decoded string is the same as original");

        note "Testing double encoding with $test";

        my $double_encoded = encode('UTF-8', $encoded);
        $decoded = decode_db($double_encoded);
        ok( $decoded, "I have a decoded string from decode_db" );
        ok( NFC($decoded) eq NFC($self->{unicode_strings}->{$test}),
            "decoded string is the same as original");
    }

    # Test that data structure is decoded properly
}

sub test_decode_it : Tests {
    my $self = shift;
    return $self->test_decode_db;
}

sub test_encode_db : Tests {
    my $self = shift;

    # TODO write something to test that encode_db works as expected

    ok( 1 );
}

=head2 test_encode_it

Tests the encode_it method. For now just run the encode_db test

=cut

sub test_encode_it : Tests {
    my $self = shift;
    return $self->test_encode_db;
}

sub test__decode_db_single : Test {
    my $self = shift;

    # TODO write test

    ok( 1 );
}

sub test__encode_db_single : Tests {
    my $self = shift;

    # TODO write test

    ok( 1 );
}

=head2 test__deeply

Test the _deeply function, which should recurse over a give piece of data and,
if it is a scalar or a reference to a hash or array, should do something
and return them or if not a scalar, hashref or array ref should return the data
unchanged.

=cut

sub test__deeply : Tests {
    my $self = shift;

    my $data = {
        scalar  => "Simple Text",
        hash    => {
            key1    => "Simple Text",
            key2    => "Simple Text",
        },
        array   => [ qw ( Simple Text ) ],
        code    => sub { return 1; },
        object  => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
        undefined   => undef,
    };

    my $action = sub { return shift; };

    # We need to ensure that _deeply always returns the value passed in.

    foreach my $test ( keys %$data ) {
        note "Testing $test";
        my $return = XTracker::DBEncode::_deeply( $action, $data->{$test} );
        ok( $return, "_deeply returned something" ) unless $test eq 'undefined';
        is_deeply( $return, $data->{$test},
            "What it returned is the same as what was passed in" );

        # and now test that this does not cause an infinite loop. This while
        # loop should execute only so many times as there are things _deeply
        # can validly recurse to and should then cleanly end.
        if ( $test eq 'undefined' ) {
            my $return = XTracker::DBEncode::_deeply( $action, $data->{$test} );
            ok( ! $return, "undef in gets undef out" );
        }
        else {
            # Literally just testing that if you do something as stupid as
            # starting an infinite loop depending upon the output from
            # _deeply to get you out of it the fault wont be with _deeply
            # THIS IS NOT AN EXCUSE TO ACTUALLY DO THIS!!!
            my $count = 0;
            while ( ! $count ) {
                $count = XTracker::DBEncode::_deeply( $action, $data->{$test} );
            }
            ok( $count, "_deeply recursion cleanly ended" );
        }
    }
}

sub test_is_utf8 : Tests {
    my $self = shift;

    my $encoded = Encode::encode('UTF-8',  $self->{unicode_strings}->{chinese} );
    ok( XTracker::DBEncode::_is_utf8( $encoded ), "encoded chinese is UTF-8" );
}

sub test_looks_like_double_encoded_utf8 : Tests {
    my $self = shift;

    my $unicode_characters = $self->{unicode_strings}->{chinese};
    my $encoded = Encode::encode('UTF-8', $unicode_characters);
    my $double_encoded = Encode::encode('UTF-8', $encoded);

    ok( ! XTracker::DBEncode::_looks_like_double_encoded_utf8( $unicode_characters ),
        "unencoded characters are not double encoded" );

    ok( ! XTracker::DBEncode::_looks_like_double_encoded_utf8( $encoded ).
        "normal UTF-8 encoded data is not double encoded" );

    ok( XTracker::DBEncode::_looks_like_double_encoded_utf8( $double_encoded ),
        "double encoded data is recognised as such" );
}

sub test__get_logger : Tests {
    my $self = shift;

    my $logger = XTracker::DBEncode::_get_logger();
    isa_ok( $logger, 'Log::Log4perl::Logger');
}
