package Test::XTracker::Utilities;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];

use Test::More::Prefix qw/ test_prefix /;

use Test::XTracker::Mock::WebServerLayer;

use XTracker::Utilities qw(
    time_diff_in_english
    duration_from_time_of_day
    ucfirst_roman_characters
    parse_url
    parse_url_path
);


sub test_time_diff_in_english : Tests() {
    my $self = shift;
    $self->_test_duration(16);
    $self->_test_duration(61, "1 hour");

    note "Overdue stuff";
    $self->_test_duration(-600, "10 hours ago");

}

sub _test_duration {
    my ($self, $minutes, $expected_duration) = @_;
    $expected_duration ||= "$minutes minutes";

    my $test_time = DateTime->now(time_zone => "UTC")->add( minutes => $minutes );
    is(
        time_diff_in_english($test_time),
        $expected_duration,
        "Correct diff for ($minutes) minutes: ($expected_duration)",
    );
}

sub test_duration_from_time_of_day : Tests() {
    my $self = shift;
    is(
        duration_from_time_of_day("blah"),
        undef,
        "Malformed tod fails ok",
    );
    eq_or_diff(
        [ duration_from_time_of_day(
            "03:10:00",
        )->in_units("hours", "minutes") ],
        [ 3, 10 ],
        "Well formed tod parses ok",
    );


    $self->_test_out_of_range(
        "25:61:00",
        qr/\QInvalid Time of Day (25:61:00), (25) hours out of range/,
        "hours",
    );
    $self->_test_out_of_range(
        "03:61:00",
        qr/\QInvalid Time of Day (03:61:00), (61) minutes out of range/,
        "minutes",
    );
    $self->_test_out_of_range(
        "03:60:61",
        qr/\QInvalid Time of Day (03:60:61), (61) seconds out of range/,
        "seconds",
    );
}

sub _test_out_of_range {
    my ($self, $time, $error_message_rex, $part_name) = @_;
    throws_ok(
        sub {
            duration_from_time_of_day($time),
        },
        $error_message_rex,
        "Well formed but invalid $part_name tod dies",
    );
}

=head2 test_ucfirst_roman_characters()

Test the ucfirst_roman_characters method.

This takes one parameter and returns the string with just the
first character in upper case, only if it contains just roman
characters and is either all upper all lower case.

Otherwise whatever was passed is returned.

=cut

sub test_ucfirst_roman_characters : Tests() {
    my $self = shift;

    my %tests = (
        'undefined' => {
            input    => undef,
            expected => '',
        },
        'mixed case' => {
            input    => 'RoMaN',
            expected => 'RoMaN',
        },
        'all lower case' => {
            input    => 'roman',
            expected => 'Roman',
        },
        'all upper case' => {
            input    => 'ROMAN',
            expected => 'Roman',
        },
        'mixed characters' => {
            input    => 'ROMAN英国驻华大使吴思田',
            expected => 'ROMAN英国驻华大使吴思田',
        },
        'non english roman characters' => {
            input    => 'éàèùâêîôûëïüÿç',
            expected => 'Éàèùâêîôûëïüÿç',
        },
        'only non roman characters' => {
            input    => '英国驻华大使吴思田',
            expected => '英国驻华大使吴思田',
        },
    );

    while ( my ( $name, $test ) = each %tests ) {
    # Do each test.

        my $result = ucfirst_roman_characters( $test->{input} );

        # Make sure we got back what was expected.
        is( $result, $test->{expected}, "Parameter is $name" );

    }

}

=head2 test_parse_url_and_parse_url_path

Tests the two functions used to parse URLs:
    parse_url
    parse_url_path

=cut

sub test_parse_url_and_parse_url_path : Tests() {
    my $self    = shift;

    my @tests   = (
        {
            url     => undef,
            expect  => {
                parse_url      => [ undef, undef, undef ],
                parse_url_path => {
                    section     => undef,
                    sub_section => undef,
                    levels      => [],
                    short_url   => undef,
                },
            },
        },
        {
            url     => '',
            expect  => {
                parse_url      => [ undef, undef, undef ],
                parse_url_path => {
                    section     => undef,
                    sub_section => undef,
                    levels      => [],
                    short_url   => undef,
                },
            },
        },
        {
            url     => '/Home',
            expect  => {
                parse_url      => [ 'Home', undef, '/Home' ],
                parse_url_path => {
                    section     => 'Home',
                    sub_section => undef,
                    levels      => [ qw( Home ) ],
                    short_url   => '/Home',
                },
            },
        },
        {
            url     => 'Fulfilment/Packing',
            expect  => {
                parse_url      => [ 'Fulfilment', 'Packing', '/Fulfilment/Packing' ],
                parse_url_path => {
                    section     => 'Fulfilment',
                    sub_section => 'Packing',
                    levels      => [ qw( Fulfilment Packing ) ],
                    short_url   => '/Fulfilment/Packing',
                },
            },
        },
        {
            url     => '/GoodsIn/VendorSampleIn',
            expect  => {
                parse_url      => [ 'Goods In', 'Vendor Sample In', '/GoodsIn/VendorSampleIn' ],
                parse_url_path => {
                    section     => 'Goods In',
                    sub_section => 'Vendor Sample In',
                    levels      => [ qw( GoodsIn VendorSampleIn ) ],
                    short_url   => '/GoodsIn/VendorSampleIn',
                },
            },
        },
        {
            url     => 'GoodsIn/VendorSampleIn/Some/thing/eXTRa',
            expect  => {
                parse_url      => [ 'Goods In', 'Vendor Sample In', '/GoodsIn/VendorSampleIn' ],
                parse_url_path => {
                    section     => 'Goods In',
                    sub_section => 'Vendor Sample In',
                    levels      => [ qw( GoodsIn VendorSampleIn Some thing eXTRa ) ],
                    short_url   => '/GoodsIn/VendorSampleIn',
                },
            },
        },
        {
            url     => 'Fulfilment/DDU',
            expect  => {
                parse_url      => [ 'Fulfilment', 'DDU', '/Fulfilment/DDU' ],
                parse_url_path => {
                    section     => 'Fulfilment',
                    sub_section => 'DDU',
                    levels      => [ qw( Fulfilment DDU ) ],
                    short_url   => '/Fulfilment/DDU',
                },
            },
        },
        {
            url     => '/NAPEvents/InTheBox',
            expect  => {
                parse_url      => [ 'NAP Events', 'In The Box', '/NAPEvents/InTheBox' ],
                parse_url_path => {
                    section     => 'NAP Events',
                    sub_section => 'In The Box',
                    levels      => [ qw( NAPEvents InTheBox ) ],
                    short_url   => '/NAPEvents/InTheBox',
                },
            },
        },
        {
            url     => '/Admin/ACLAdmin',
            expect  => {
                parse_url      => [ 'Admin', 'ACL Admin', '/Admin/ACLAdmin' ],
                parse_url_path => {
                    section     => 'Admin',
                    sub_section => 'ACL Admin',
                    levels      => [ qw( Admin ACLAdmin ) ],
                    short_url   => '/Admin/ACLAdmin',
                },
            },
        },
    );

    note "check that both 'parse_url' & 'parse_url_path' return as expected for different URLs";

    my $web_layer   = Test::XTracker::Mock::WebServerLayer->setup_mock;

    foreach my $test ( @tests ) {
        my $url = $test->{url} // 'undef';
        note "using URL: '${url}'";

        Test::XTracker::Mock::WebServerLayer->set_url_to_use( $test->{url} );
        my @got = parse_url( $web_layer );
        is_deeply( \@got, $test->{expect}{parse_url}, "'parse_url' returned as expected" );

        my $got = parse_url_path( $test->{url} );
        is_deeply( $got, $test->{expect}{parse_url_path}, "'parse_url_path' returned as expected" );
    }

    note "now check ALL Sub-Sections to make sure they get parsed correctly by both functions";
    my @sub_sections = $self->rs('Public::AuthorisationSubSection')->search( {},
        {
            join     => 'section',
            order_by => 'section.section, me.sub_section',
        }
    )->all;

    # loop round doing all of them and then do one big
    # deep check so that there aren't hundreds of tests
    my @got;
    my @expect;
    foreach my $sub_section ( @sub_sections ) {
        my $section     = $sub_section->section->section;
        my $sub_section = $sub_section->sub_section;
        my $url_path    = "/${section}/${sub_section}";

        my $level1      = $section;
        my $level2      = $sub_section;
        $level1         =~ s/ //g;
        $level2         =~ s/ //g;
        $url_path       =~ s/ //g;

        push @expect, {
            parse_url       => [ $section, $sub_section, $url_path ],
            parse_url_path  => {
                section     => $section,
                sub_section => $sub_section,
                levels      => [ $level1, $level2 ],
                short_url   => $url_path,
            },
        };

        Test::XTracker::Mock::WebServerLayer->set_url_to_use( $url_path );
        push @got, {
            parse_url       => [ parse_url( $web_layer ) ],
            parse_url_path  => parse_url_path( $url_path ),
        };
    }
    is_deeply( \@got, \@expect, "ALL Sub-Sections were Parsed correctly" );
}

1;
