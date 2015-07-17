#!/usr/bin/env perl

use NAP::policy "tt", qw( test );

use XTracker::Config::Local qw( config_var );
use XTracker::Utilities     qw( running_in_dave );

ok( config_var('RunningEnvironment','dave'), "Configuration value for DAVE env is present" );
ok( running_in_dave(), "running_in_dave() function returns true" );

$XTracker::Config::Local::config{RunningEnvironment}->{live} = 'n';

ok( ! running_in_dave(), "running_in_dave() is false - live is present set to N" );

$XTracker::Config::Local::config{RunningEnvironment}->{live} = 'Y';

ok( ! running_in_dave(), "running_in_dave() is now false - both dave and live are true" );

delete $XTracker::Config::Local::config{RunningEnvironment}->{dave};
ok( ! config_var('RunningEnvironment','dave'), "Configuration value for DAVE no longer present" );
ok( ! running_in_dave(), "running_in_dave() is now false" );

# Put back config!
$XTracker::Config::Local::config{RunningEnvironment}->{dave} = 'Y';
delete $XTracker::Config::Local::config{RunningEnvironment}->{live};

done_testing();
