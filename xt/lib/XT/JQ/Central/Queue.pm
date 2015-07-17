package XT::JQ::Central::Queue;

use Moose; # automagically gives us strict and warnings
use MooseX::FollowPBP;

use Carp;
#use XT::Central::Model::Elemental;
use XTracker::Database;
use XTracker::Config::Local qw( config_var );

extends 'XT::Common::JQ::Queue';

# our attributes
has '+pidfile'   => ( required => 0 );

sub is_valid {
     1; # We dont want to validate DC jobs when we add them in Fulcrum, mmmkay
}


sub _prepare_dsn {
    my $self    = shift;

    return {
        dsn   => config_var('Database_Central_Job_Queue', 'dsn'),
        user  => config_var('Database_Central_Job_Queue', 'user'),
        pass  => config_var('Database_Central_Job_Queue', 'pass'),
    };
}




1;
__END__

