#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;



use Test::XTracker::Data;
use XTracker::Config::Local qw<config_section_exists config_var>;


my @sections = qw<
    Database_xtracker
>;

my @config_vars = qw<
    db_host
    db_user_readonly
    db_pass_readonly
    db_user_transaction
    db_pass_transaction
>;

foreach my $section (@sections) {
    ok(
        config_section_exists($section),
        "[$section] exists"
    );

    foreach my $config_var (@config_vars) {
        ok(
            defined(config_var($section,$config_var)),
            "[$section/$config_var] exists"
        );
    }

    ok(
        not(defined(config_var($section,'AutoCommit'))),
        "[$section/AutoCommit] does not exist"
    );
}

done_testing;
