package XT::Domain::Messages;

use strict;
use warnings;

use base qw/ XT::Domain /;
use Carp;
use Data::Dump qw(pp);
use Time::HiRes qw/ gettimeofday /;

use XTracker::Logfile qw(xt_logger);
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;

use Class::Std;
{
    sub get_message {
        my ($self, $msg_id) = @_;
        my $schema = $self->get_schema;

        my $message = $schema->resultset('Operator::Message')->find(
            { id => $msg_id }
        );
        return $message;
    }

    sub message_list {
        my ($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Operator::Message')->message_list(
            { recipient_id => $id }
        );
    }

    sub message_count {
        my ($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Operator::Message')->message_count(
            {
                recipient_id    => $id,
            }
        );
    }

    sub read_message_count {
        my ($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Operator::Message')->read_message_count(
            {
                recipient_id    => $id,
            }
        );
    }

    sub send_message {
        my ($self, $attr) = @_;
        my $schema = $self->get_schema;
        $self->check_params([qw/ message /], $attr);

        my $cond;

        # list of operators
        if (
            defined $attr->{operators}
                and
            'ARRAY' eq ref($attr->{operators})
        ) {
            $cond->{id} = { 'IN', $attr->{operators} };
        }

        # by department
        elsif (defined $attr->{department_id}) {
            $cond->{department_id} = $attr->{department_id};
        }

        # active users (not disabled)
        elsif (defined $attr->{all}) {
            $cond->{disabled} = 0;
        }

        # um, we don't know who to send to
        else {
            warn q{no criteria specified for recipient list};
            return;
        }

        # get the list of operators that we want to message
        my $operator_rs = $schema->resultset('Public::Operator')->search(
            $cond
        );

        # loop through the operators and send them an xt-message
        while (my $operator = $operator_rs->next) {
            $operator->send_message(
                {
                    subject     => ($attr->{subject} || 'Red leader to base'),
                    message     => $attr->{message},
                    sender      => ($attr->{sender} || $APPLICATION_OPERATOR_ID),
                }
            );
        }
    }

    sub unread_message_count {
        my ($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Operator::Message')->unread_message_count(
            {
                recipient_id    => $id,
            }
        );
    }
}

1;

__END__

=head1 NAME

XT::Domain::Messages - work with XT messaging system

=head1 SYNOPSIS

  # if you haven't already got a $schema object ...
  use XTracker::Database 'xtracker_schema';
  my $schema = xtracker_schema;

  # use the relevant library path and library
  use lib $whatever;
  use XT::Domain::Messages;

  # create a new domain object
  my $messages = XT::Domain::Messages->new({ schema => $schema });

  # send a message to a single user
  $messages->send_message(
    {
      operators       => [ 399 ],
      subject         => q{Scripted Message},
      message         => q{This message was created by a script},
    }
  );

  # send a message to a list of users
  $messages->send_message(
    {
      operators       => [ 399, 547, 613 ],
      subject         => q{There can be more than one},
      message         => q{This message was sent to multiple people},
    }
  );

  # send to a department
  use XTracker::Constants::FromDB qw( :department );
  $messages->send_message(
    {
      department_id   => $DEPARTMENT__IT,
      subject         => q{Dear IT Team},
      message         => q{You are wonderful people. Thank you for being who you are.},
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

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut
