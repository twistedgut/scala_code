package Test::Test::XTracker::Data::InternationalText;

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use utf8;
use Encode qw( encode );
use XTracker::DBEncode qw( encode_it decode_it );

sub startup : Test(startup => 1) {
    my $self = shift;
    use_ok 'Test::XTracker::Data::InternationalText';
    $self->{strings} = Test::XTracker::Data::InternationalText->example_strings;
    $self->{original} = Test::XTracker::Data::InternationalText->example_strings;
}

sub test_can_decode_all : Tests {
    # This is a check for bad test data - if decode_it fails, having these
    # strings in the database would break XTracker. These strings came from the
    # database...
    my $self = shift;
    while (my ($key, $string) = each( %{ $self->{strings} } ) ) {
        lives_ok sub { decode_it( $string ) }, "should decode string $key";
    }
}

sub test_encode_decode_match : Tests {
    # This checks that encoding and decoding these strings (after an initial
    # decode) results in the same string. If it doesn't, tests using Unicode
    # strings in 'set value, get value, check match' checks will fail.
    my $self = shift;
    while (my ($key, $string) = each( %{ $self->{strings} } ) ) {
        note "$key string";
        my $decoded1;
        lives_ok sub { $decoded1 = decode_it( $string ) }, "should decode initial string $key";

        my $encoded;
        my $decoded2;
        lives_ok sub {
            $encoded = encode_it( $decoded1 );
            $decoded2 = decode_it( $encoded );
        }, "should encode and decode decoded string $key";
        is $decoded1, $decoded2, "encode-decode cycle on decode string $key should result in matching string";
    }
}

sub test_decode_runaway : Tests {
    # Checks that the decode_it method only makes a limited number of attempts
    # to decode a value encoded multiple times
    my $self = shift;
    my $MAX = XTracker::DBEncode->max_decodes;
    my $value = "文字化け"; # Yes that is the word mojibake
    my $can_decode = $value;
    my $cannot_decode = $value;
    foreach (0 .. ($MAX - 1)) {
        $can_decode = encode("UTF-8", $can_decode);
    };
    $can_decode = encode_it($can_decode);
    cmp_ok(encode("UTF-8", $value), "eq", $can_decode, "Can decode multiencoded within limit");
    foreach (0 .. ($MAX + 1)) {
        $cannot_decode = encode("UTF-8", $cannot_decode);
    }
    $cannot_decode = encode_it($cannot_decode);
    cmp_ok(encode("UTF-8", $value), "ne", $cannot_decode, "Cannot decode beyond limit");
}


sub test_original_keys_still_present : Tests {
    my $self = shift;
    # This checks that the keys in the original hash are all still present
    # to ensure that they are not destroyed by the DBEncode class
    my @original_keys = sort keys %{$self->{original}};
    my $decoded = decode_it($self->{strings});
    my @decoded_keys = sort keys %$decoded;
    is_deeply(\@original_keys, \@decoded_keys, "Decoded keys are the same");
    my $encoded = encode_it($self->{strings});
    my @encoded_keys = sort keys %$encoded;
    is_deeply(\@original_keys, \@encoded_keys, "Encoded keys are the same");
}
