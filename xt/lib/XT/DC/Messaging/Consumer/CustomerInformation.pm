package XT::DC::Messaging::Consumer::CustomerInformation;
use NAP::policy "tt", 'class';
use Data::Dump qw(pp);
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::CustomerInformation;
use XTracker::Config::Local         qw( config_var );

sub routes {
    return {
        destination => {
            CustomerInformation => {
                code => \&CustomerInformation,
                spec => XT::DC::Messaging::Spec::CustomerInformation->CustomerInformation(),
            },
        },
    };
}

=head1 Consumer::Controller::CustomerInformation

=cut

sub CustomerInformation {
    my ($self, $message, $header)  = @_;

    return try {
        # At present, the only customer information we expect is
        # the language attribute.  Check for that before even bothering
        # to hit the DB for anything.

        my $language_attribute = $message->{attributes}{language};

        # NOTE: this code checks the attribute first, so it can
        # quit before it does any DB interactions in the case where the
        # attribute is missing or empty.
        #
        # It actually uses the attribute much later in this code, and
        # without checking to see if it has a value, because that check
        # has been done here.
        #
        # However, once additional attributes are added, it will probably
        # become necessary to add a test in front of the use, because that
        # code might be reached when another attribute is present, but not
        # the language attribute.
        #

        # Do we have a language attribute in the message?
        unless ($language_attribute) {
            $self->log->debug(pp($message));
            $self->log->fatal('Message received without language attribute');

            return;
        }

        # Is this message for the right DC?
        my $local = lc(config_var('XTracker', 'instance'));

        # Incorrect DC
        unless ($message->{channel} =~ m/$local/i) {
            $self->log->debug(pp($message));
            $self->log->fatal('Message received for incorrect channel '.$message->{channel}.' in '.$local);

            return;
        }

        my $schema  = $self->model('Schema');

        # Find channel
        my $channel = $schema->resultset('Public::Channel')->find_by_pws_name(uc($message->{channel}));

        # Channel not found
        unless ($channel) {
            $self->log->debug(pp($message));
            $self->log->fatal('Channel '.$message->{channel}.' not found');

            return;
        }

        # Find customer based on PWS number
        my $customer = $schema->resultset('Public::Customer')->search({
            is_customer_number => $message->{cust_id},
            channel_id         => $channel->id,
        })->first;

        # Customer not found
        unless ($customer) {
            $self->log->debug(pp($message));
            $self->log->fatal('PWS customer #'.$message->{cust_id}.' not found');

            return;
        }

        # See NOTE above -- once additional attributes are handled, it
        # will probably become necessary to wrap this call to
        # ->set_language_preference() with
        #
        #    if ($language_attribute) { ... }
        #
        # or equivalent.

        $customer->set_language_preference($language_attribute);
        return 1;
    }
    catch {
        $self->log->debug(pp($message));
        $self->log->fatal($_);

        return;
    };
}
