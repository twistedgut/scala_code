package XT::DC::Messaging::Consumer::PRL;

=head1 NAME

XT::DC::Messaging::Consumer::PRL - Receive and dispatch messages from PRLs

=cut

use NAP::policy "tt", 'class';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
with 'XT::DC::Messaging::ConsumerBase::LogReceipt';

use XT::DC::Messaging::Spec::PRL;
use Module::Pluggable # provides 'plugins()'
    search_path => 'XT::DC::Messaging::Plugins::PRL',
    instantiate => 'new';

=head1 OVERVIEW

We'll create a handler in this class for each of the message types we find
searching for C<XT::DC::Messaging::Consumer::PRL::*>. These are required to
support C<message_type>, which returns a string corresponding to
L<NAP::DC::PRL::MessageSpec>, and C<handler>, which actually deals with the
message, and receives its own package name, the context, and the message
payload already validated.

If you'd like a simple way of creating Producer classes for the PRLs, consider
L<XT::DC::Messaging::Producer::PRL::AutoProducer>.

=cut

sub routes {
    state $routes;
    return $routes if $routes;

    $routes = { destination => my $types = {} };
    # plugins() gets imported by Module::Pluggable
    for my $plugin_obj ( plugins() ) {
        my $name = $plugin_obj->message_type;
        $types->{$name} = {
            spec => XT::DC::Messaging::Spec::PRL->$name,
            code => sub {
                my ($consumer,$message,$header) = @_;
                $consumer->timer->add_details(
                    message_content => $message,
                );
                $plugin_obj->handler($consumer,$message,$header)
            },
        };
    };

    return $routes;
}
