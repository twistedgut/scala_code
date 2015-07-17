package XT::Service::My::Messages;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
#use Data::FormValidator;
#use Data::FormValidator::Constraints qw(:closures);
use JSON;

use XT::Domain::Messages;
use XTracker::Constants::FromDB qw( :promotion_status );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Session;

use base qw/ XT::Service /;
use base qw/ XT::AjaxService /;

use Class::Std;
{

    # object attributes
    my %message_domain_of   :ATTR( get => 'message_domain',                     set => 'message_domain'     );

    sub START {
        my($self) = @_;
        my $schema = $self->get_schema;

        $self->set_message_domain(
             XT::Domain::Messages->new({ schema => $schema })
        );

        return;
    }

    sub process {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $schema = $handler->{schema};

        $handler->{data}{section}       = 'Messages';
        $handler->{data}{subsection}    = $handler->{session}{operator_name};


        # create objects that provide access to the tiers we want
        my $messages = $self->get_message_domain;

        # having the left-nav is always useful
        #construct_left_nav($handler);

        $handler->{data}{message_list} = $messages->message_list(
            $handler->operator_id
        );
        $handler->{data}{messages}{total} = $messages->message_count(
            $handler->operator_id
        );
        $handler->{data}{messages}{read} = $messages->read_message_count(
            $handler->operator_id
        );
        $handler->{data}{messages}{unread} = $messages->unread_message_count(
            $handler->operator_id
        );

        # deal with POST requests
        if (
            defined $handler->{param_of}{'do_action'}
                and
            q{POST} eq $handler->{request}->method
        ) {
            # get a specific message
            if (q{retrieve_message} eq $handler->{param_of}{'do_action'}) {
                my $response = $self->get_response; # ajaxy response data

                # get the message and populate stuff
                my $message = $messages->get_message( $handler->{param_of}{msg_id} );
                # flag the message as read
                $message->update( { viewed => 1 } );
                # set the data to be used by YUI
                $response->{message} = {
                    id          => $message->id,
                    body        => $message->body,
                    subject     => $message->subject,
                };

                # return the ajaxy respone
                return $self->return_response;
            }
            # delete a message
            elsif (q{delete_message} eq $handler->{param_of}{'do_action'}) {
                my $response = $self->get_response; # ajaxy response data

                # get the message and populate stuff
                my $message = $messages->get_message( $handler->{param_of}{msg_id} );
                # flag the message as deleted
                $message->update( { deleted => 1 } );
                # set the data to be ignored by YUI
                $response->{message} = {
                    id          => $message->id,
                    body        => $message->body,
                    subject     => $message->subject,
                    deleted     => $message->deleted,
                };

                # return the ajaxy respone
                return $self->return_response;
            }
            # deal with unknown actions
            else {
                xt_warn(qq{Unknown POST action: $handler->{param_of}{'do_action'}});
                return '/My/Messages';
            }
        }

        return;
    }
}

1;
