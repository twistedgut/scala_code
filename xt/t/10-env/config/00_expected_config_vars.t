#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::Differences;

use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local qw<config_section_exists config_var>;
use Test::XTracker::Utils;
use File::Temp qw/ tempfile /;
use File::Copy;
use JSON;
use List::Compare;

use Data::Dump qw/pp/;


# PURPOSE:
# With our configuration being generated this test is to test that we have
# the sections and elements we're expecting. If you want to do more than
# just testing it is defined then you need to write it yourself.
#
# It takes its test data from a file in a JSON file
#
# There's a few other tests in 10-env similar to this that needs bringing into
# this to avoid duplication of the same effort

my $base_filename = 't/data/expected_config_vars';
my $fail_unexpected = 0;



my $file = Path::Class::File->new("$base_filename.json");
my $sections = Test::XTracker::Utils->slurp_json_file($file);
test_config($sections->{expected_config_vars});

done_testing;

sub test_config {
    my($data) = @_;

    test_expected_cases($data);
    test_unexpected_sections($data);
}

sub test_unexpected_sections {
    my($data) = @_;
    my $config = \%XTracker::Config::Local::config;
    my $expected = make_expected_structure($data);

    my @fails;
    foreach my $section_name (keys %{$config}) {
        # the whole section doesn't exist
        if (!$expected->{$section_name}) {
            push @fails, $section_name;
            next;
        }

        # check inside section
        my $section = $config->{$section_name};
        my @existing_keys = keys %{$section};
        my $compare = List::Compare->new(
            \@existing_keys,
            $expected->{$section_name} || [],
        );
        my @missing = $compare->get_Lonly;
        push @fails, {
            section => $section_name,
            missing => \@missing,
        } if (scalar @missing);
    }

    foreach my $fail (sort @fails) {
        if ($fail_unexpected) {
            if (ref($fail) eq 'HASH') {
                eq_or_diff($fail->{missing},[],
                    "[SECTION $fail->{section}] missing keys");
            } else {
                ok(!defined $fail, "section exists - $fail");
            }
        } else {
            if (ref($fail) eq 'HASH') {
                diag "[SECTION $fail->{section}] missing keys - "
                    . join(',',@{$fail->{missing}});
            } else {
                diag "[SECTION] missing - $fail";
            }
        }
    }
    if (scalar @fails) {
        diag '
To fix the above do the following to add it to the test cases

1. open the json file t/data/expected_config_vars.json
2. decide if this belongs across all configs (add to \'base\') or it is specific to a DC (add to the \'DC1\' etc - DC2/3 do not exist currently

3 defining a section with keys expected in this section
    "Database_Fulcrum" : [
        "PrintError",
        "RaiseError",
        "db_host",
        "db_name",
        "db_pass_readonly",
        "db_pass_transaction",
        "db_type",
        "db_user_readonly",
        "db_user_transaction"
    ]

NOTE: it\'s JSON so no trailing comma on the last element!!!!!';

    }
}

sub make_expected_structure {
    my($data) = @_;
    my @sets = ('base', Test::XTracker::Data->whatami);
    my $struct;

    foreach my $key (@sets) {
        my $sections = $data->{$key} || undef;

        if (!$sections) {
            note "  Nothing for $key";
            next;
        }

        foreach my $section (sort keys %{$sections}) {
            $struct->{$section} = $sections->{$section};
        }
    }

    return $struct;
}

sub test_expected_cases {
    my($data) = @_;
    # there should be at least 'base' - later when we have DC specific we
    # can add in more sets
    my @sets = ('base', Test::XTracker::Data->whatami);

    foreach my $key (@sets) {
        my $sections = $data->{$key} || undef;
        note "Testing $key";

        if (!$sections) {
            note "  Nothing for $key";
            next;
        }

        foreach my $section (sort keys %{$sections}) {
            ok(
                config_section_exists($section),
                "[$section] exists"
            );

            my $all_fields = $sections->{$section};

            if (defined $all_fields) {
                foreach my $field (@{$all_fields}) {
                    ok(defined(config_var($section,$field)),
                        "[$section] $field is defined");
                }
            }
        }
    }
}

