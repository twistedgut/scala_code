#!/usr/bin/env perl

use NAP::policy 'test';
use File::Copy;
use File::Temp;
use PRL::Migration::Utils;

my $original_config_file    = 't/data/xt_dc_messaging_XTDC2.conf';
my $backup_config_file      = File::Temp->new->filename;
my $expected_instance_count = <<'COUNT';
1
COUNT

# backup the config file
copy( $original_config_file, $backup_config_file ) or die "Copy failed: $!";

# re-write the config file
ok(
    PRL::Migration::Utils->rewrite_amq_config_file($original_config_file),
    "re-wrote the config file: $original_config_file",
);

# check we only have one instance
is(
    qx(grep -c '<instances>' $original_config_file),
    $expected_instance_count,
    'updated to correct number of instances',
);

# restore the original file
copy( $backup_config_file,  $original_config_file ) or die "Copy failed: $!";

done_testing;
