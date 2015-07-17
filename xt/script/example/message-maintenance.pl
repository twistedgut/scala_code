#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

=head1 NAME

message-maintenance.pl - let active users know about impending downtime

=pod DESCRIPTION

This script demonstrates how to let everyone know about xt downtime

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

use DateTime;

# how long you think it will take
my $downtime_minutes = 15;

# when the maintenance is anticipated to commence
my $date = DateTime->new(
    year        => '2008',
    month       => '08',
    day         => '21',
    hour        => '11',
    minute      => '00',
);

# sanity check a few things as we go along
use Test::More tests => 3;

# use the relevant library path and library
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use XT::Domain::Messages;
use XTracker::Database qw( :common );

# if you haven't already got a $schema object ..
my $schema = get_database_handle(
    {
        name    => 'xtracker_schema',
        type    => 'transaction',
    }
);
isa_ok($schema, 'XTracker::Schema');

# create a new domain object
my $messages = XT::Domain::Messages->new({ schema => $schema });
isa_ok($messages, 'XT::Domain::Messages');
isa_ok($messages->get_schema, 'XTracker::Schema');

my $subject =
      q{Planned maintenance: }
    . $date->day_abbr
    . q{ }
    . $date->day
    . q{ }
    . $date->month_abbr
    . q{ }
    . $date->year
    . q{ at }
    . $date->strftime('%r')
;

my $message = 
      q{<html><body><p><b>Planned Maintenance:</b></p>}
    . q{<p>xTracker will be unavailable for approximately }
    . ($downtime_minutes || 15)
    . q{ minutes for scheduled maintenance.</p>}
    . q{<p>The IT Team would like to apologise for any inconvenience this may cause.</p>}
;

# send to all active users
$messages->send_message(
    {
        all             => 1,
        subject         => $subject,
        message         => $message,
    }
);
