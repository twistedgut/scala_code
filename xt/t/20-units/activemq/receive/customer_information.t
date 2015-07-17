#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local qw( config_var );

sub startup : Tests(startup => 1) {
    my $self = shift;

    $self->SUPER::startup;

    ($self->{amq},$self->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $self->{schema} = Test::XTracker::Data->get_schema();

    $self->{all_channels} = [$self->{schema}->resultset('Public::Channel')->all];
    $self->{test_channel} = @{$self->{all_channels}}[0];

    $self->{queue_name}   = XT::DC::Messaging->config->{'Consumer::CustomerInformation'}{routes_map}{destination};

    $self->{default_language}    = $self->{schema}->resultset('Public::Language')->get_default_language_preference();
    $self->{all_languages}       = [$self->{schema}->resultset('Public::Language')->all];
    $self->{language_preference} = 'de';

    $self->{default_datetime}    = '2012-09-01T10:00:00Z';
}

sub setup : Tests(setup => 4) {
    my $self = shift;

    $self->SUPER::setup;

    # New customer for each test
    foreach my $channel (@{$self->{all_channels}}) {
        $self->{test_customers}{$channel->web_queue_name_part} = Test::XTracker::Data->create_dbic_customer({
            channel_id => $channel->id
        });
        ok($self->{test_customers}{$channel->web_queue_name_part}->get_language_preference->{is_default}, 'new customer has language default');
    }

    $self->{amq}->clear_destination($self->{queue_name});
}


=head2 test_successful_language_update

Send an AMQ message with all correct values. Consumer must succeed and language must upadate.

=cut

sub test_successful_language_update : Tests() {
    my $self = shift;

    # Test for each channel
    foreach my $channel (@{$self->{all_channels}}) {

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        # Test for each language
        foreach my $language (@{$self->{all_languages}}) {

            note 'Testing Language '.$language->code.' for channel '.$channel->web_queue_name_part;

            # Make request
            my $res = $self->{amq}->request(
                $self->{app},
                $self->{queue_name},
                {
                    cust_id    => $customer->is_customer_number,
                    channel    => $channel->web_queue_name_part,
                    timestamp  => $self->{default_datetime},
                    attributes => {
                        language => $language->code
                    }
                },
                { type => 'CustomerInformation' },
            );

            # Reload the customer object
            $customer->discard_changes;

            # Run tests for language attribute
            ok($res->is_success, 'message consumed');
            ok(!$customer->get_language_preference->{is_default}, 'language is not default');
            is($customer->get_language_preference->{language}->code, $language->code, 'language code has been updated');
        }
    }
}


=head2 test_language_update_with_unknown_code

Send an AMQ message with an unknown language code. Consumer must succeed but language must not upadate.

=cut

sub test_language_update_with_unknown_code : Tests() {
    my $self = shift;

    foreach my $channel (@{$self->{all_channels}}) {

        note 'Testing channel '.$channel->web_queue_name_part;

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        my $fake_language_code = 'xx';

        # Make request
        my $res = $self->{amq}->request(
            $self->{app},
            $self->{queue_name},
            {
                cust_id    => $customer->is_customer_number,
                channel    => $channel->web_queue_name_part,
                timestamp  => $self->{default_datetime},
                attributes => {
                    language => $fake_language_code
                }
            },
            { type => 'CustomerInformation' },
        );
        # Reload the customer object
        $customer->discard_changes;

        # Run tests for language attribute
        ok($res->is_success, 'message consumed');
        ok($customer->get_language_preference->{is_default}, 'language is default');
        is($customer->get_language_preference->{language}->code, $self->{default_language}->code, 'language code is default');
    }
}

=head2 test_language_update_with_no_code

Send an AMQ message with no language code. Consumer must succeed but language must not upadate.

=cut

sub test_language_update_with_no_code : Tests() {
    my $self = shift;

    foreach my $channel (@{$self->{all_channels}}) {

        note 'Testing channel '.$channel->web_queue_name_part;

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        # Make request
        my $res = $self->{amq}->request(
            $self->{app},
            $self->{queue_name},
            {
                cust_id    => $customer->is_customer_number,
                channel    => $channel->web_queue_name_part,
                timestamp  => $self->{default_datetime},
                attributes => {
                }
            },
            { type => 'CustomerInformation' },
        );

        # Reload the customer object
        $customer->discard_changes;

        # Run tests for language attribute
        ok($res->is_success, 'message consumed');
        ok($customer->get_language_preference->{is_default}, 'language is default');
        is($customer->get_language_preference->{language}->code, $self->{default_language}->code, 'language code is default');
    }
}


=head2 test_language_update_with_invalid_code

Send an AMQ message with an invalid language code. Consumer must fail.

=cut

sub test_language_update_with_invalid_code : Tests() {
    my $self = shift;

    foreach my $channel (@{$self->{all_channels}}) {

        note 'Testing channel '.$channel->web_queue_name_part;

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        my $fake_language_code = 'xx123';

        # Make request
        my $res = $self->{amq}->request(
            $self->{app},
            $self->{queue_name},
            {
                cust_id    => $customer->is_customer_number,
                channel    => $channel->web_queue_name_part,
                timestamp  => $self->{default_datetime},
                attributes => {
                    language => $fake_language_code
                }
            },
            { type => 'CustomerInformation' },
        );
        # Test for failed message consumption
        ok($res->is_error, 'message not consumed');
    }
}


=head2 test_language_update_with_wrong_channel

Send an AMQ message with the wrong channel. Consumer must fail.

=cut

sub test_language_update_with_wrong_channel : Tests() {
    my $self = shift;

    foreach my $channel (@{$self->{all_channels}}) {

        note 'Testing channel '.$channel->web_queue_name_part;

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        # Make request
        my $res = $self->{amq}->request(
            $self->{app},
            $self->{queue_name},
            {
                cust_id    => $customer->is_customer_number,
                channel    => 'ANOTHER-CHANNEL',
                timestamp  => $self->{default_datetime},
                attributes => {
                    language => @{$self->{all_languages}}[0]->code
                }
            },
            { type => 'CustomerInformation' },
        );
        # Test for failed message consumption
        ok($res->is_error, 'message not consumed');
    }
}


=head2 test_language_update_in_wrong_dc

Send an AMQ message for the wrong DC. Consumer must succeed but language must not upadate.

=cut

sub test_language_update_in_wrong_dc : Tests() {
    my $self = shift;

    my $local = lc(config_var('XTracker', 'instance'));

    my $other_dc;

    if ($local eq 'intl') {
        $other_dc = 'am';
    }
    else {
        $other_dc = 'intl';
    }

    foreach my $channel (@{$self->{all_channels}}) {

        # Swap locale ident
        my $wrong_chname = $channel->web_queue_name_part;
           $wrong_chname =~ s/$local/$other_dc/;

        note 'Testing '.$channel->web_queue_name_part.' in '.$wrong_chname;

        my $customer = $self->{test_customers}{$channel->web_queue_name_part};

        # Make request
        my $res = $self->{amq}->request(
            $self->{app},
            $self->{queue_name},
            {
                cust_id    => $customer->is_customer_number,
                channel    => $wrong_chname,
                timestamp  => $self->{default_datetime},
                attributes => {
                    language => @{$self->{all_languages}}[0]->code
                }
            },
            { type => 'CustomerInformation', },
        );
        # Reload the customer object
        $customer->discard_changes;

        # Run tests for language attribute
        ok($res->is_success, 'message consumed');
        ok($customer->get_language_preference->{is_default}, 'language is default');
        is($customer->get_language_preference->{language}->code, $self->{default_language}->code, 'language code is default');
    }
}

Test::Class->runtests;
