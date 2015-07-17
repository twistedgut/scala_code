#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

=head1 NAME

message.pl - insert messages into the internal xt-mailbox

=pod DESCRIPTION

This script demonstrates how to send various xt-messages

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

# sanity check a few things as we go along
use Test::More tests => 3;

BEGIN {
    use FindBin::libs;
    use FindBin::libs qw( base=lib_dynamic );
    use XTracker::Constants::FromDB qw( :department );
    use XTracker::Database qw( schema_handle );
    use XT::Domain::Messages;
}
my $schema = schema_handle;
isa_ok($schema, 'XTracker::Schema');

# create a new domain object
my $messages = XT::Domain::Messages->new({ schema => $schema });
isa_ok($messages, 'XT::Domain::Messages');
isa_ok($messages->get_schema, 'XTracker::Schema');

# send a message to a single user
$messages->send_message(
    {
        operators   => [ 399 ],
        subject     => q{Scripted Message},
        message     => q{This message was created by a script},
    }
);

# send a message to a list of users
$messages->send_message(
    {
        operators   => [ 399, 547, 613 ],
        subject     => q{There can be more than one},
        message     => q{This message was sent to multiple people},
    }
);

# send to a department
$messages->send_message(
    {
        department_id   => $DEPARTMENT__IT,
        subject         => q{Dear IT Team},
        message         => q{You are wonderful people. Thank you for being who
        you are.},
    }
);

# send to all active users
use XTracker::Constants::FromDB qw( :department );
$messages->send_message(
    {
        all             => 1,
        subject         => q{Dear Everyone},
        message         => q{PUB!!!!!},
    }
);

# send a message from a non "Application" sender
$messages->send_message(
    {
        operators       => [ 399 ],
        sender          => 10,
        subject         => q{Does anyone have ...},
        message         => q{... some headphones that I could borrow?},
    }
);
