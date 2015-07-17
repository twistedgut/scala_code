package XT::DC::Messaging::ConsumerBase::Order;
use NAP::policy "tt", 'class';
use XT::Order::Importer;
use IO::File;
use IO::Interactive;
use File::Copy;
use XT::Order::Parser;
use XTracker::Database                  qw( get_database_handle  get_schema_using_dbh);
use XT::DC::Messaging::Spec::Order;
use NAP::Messaging::Serialiser;

extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';

use Data::Dump qw/pp/; # used for errors; not a debugging throwback

sub routes {
    return {
        destination => {
            'com.netaporter.services.payment.exportOrder.domain.Order' => {
                code => \&order,
                spec => XT::DC::Messaging::Spec::Order->order(),
            },
            order => {
                code => \&order,
                spec => XT::DC::Messaging::Spec::Order->order(),
            }
        }
    };
}

use XTracker::Utilities 'ff_deeply';


=head1 NAME

XT::DC::Messaging::ConsumerBase::Order - base class for Order import consumer

=head1 DESCRIPTION

This base class exists so that we can have muiltiple controllers, one for each
queue without needing to duplicate any code.


=head2 order

Pulls every order off the queue
and writes the json into var/data/tpi/waiting/
in case things die, we know where it's at!

Turns the json into a hash

Parses the hash:
    - success - move the file to tmp/var/data/tpi/proc
    - failure - move the file to tmp/var/data/tpi/problem

=cut

sub order {
    my ($self, $message, $header) = @_;
    my $error;
    my $json_message = NAP::Messaging::Serialiser->serialise($message);

    my $wait_filename = XT::Order::Parser->full_backup_pathname('waiting', $message);
    my $fh = IO::File->new;
    unless ($fh->open($wait_filename,'>',':raw'))  {
        die "Failed to open the file $wait_filename";
    }
    print $fh $json_message."\n";
    $fh->close;

    my $schema = $self->model('Schema');
    $message = ff_deeply($message);
    my $success;
    try {
        $success = XT::Order::Importer->import_orders({
            data        => $message,
        });
    }
    catch {
        $error = $_; # so we can use it in process_failure()
        $self->log->error(
            "failed order import for: "
            . pp($message)
            . "\nwith error: $error"
        );

        # if we're running manually, or testing it's useful to not have to
        # hunt down the log file for errors ... esp. as the log->error() call
        # seems to go to /dev/null or equivalent
        if (IO::Interactive::is_interactive || exists $ENV{HARNESS_ACTIVE} && $ENV{HARNESS_ACTIVE}) {
            warn $_;
        }
    };

    if ($success) {
        move ($wait_filename, XT::Order::Parser->full_backup_pathname('processed', $message));
        if ($self->can('process_success')) {
            $self->process_success($message,$header);
        }
    }
    else {
        move ($wait_filename, XT::Order::Parser->full_backup_pathname('problem', $message));
        if ($self->can('process_failure')) {
            $self->process_failure($message,$header,$error);
        }
    }
}
