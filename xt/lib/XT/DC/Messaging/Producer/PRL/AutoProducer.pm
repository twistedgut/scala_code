package XT::DC::Messaging::Producer::PRL::AutoProducer;

=head1 NAME

XT::DC::Messaging::Producer::PRL::AutoProducer - Lightweight producer for simple messages

=head1 DESCRIPTION

Lightweight producer for simple messages

=head1 WHAT

For making testing easier, the XT code really needs to be able to produce
messages that normally it'll be receiving. This module allows you to very easily
create light-weight Producer::PRL::* classes by adding a line to the source.

New messages are added in the code themselves, for example:

 [ advice_response => config_var('WMS_Queues', 'prl')  ],

Which adds a Producer for C<advice_response>, whose target queue is the queue
at the config value.

=cut

use NAP::policy "tt", "class";
use Moose::Meta::Class;
use Moose::Util 'apply_all_roles';
use XT::DC::Messaging::Role::Producer;
use XTracker::Config::Local qw( config_var );
use XT::DC::Messaging::Spec::PRL;

# Set up our subclasses
for (
    # Message name          Queue
    [ advice_response => config_var('WMS_Queues', 'prl')  ],
    [ stock_adjust => config_var('WMS_Queues', 'prl')  ],
    [ item_picked => config_var('WMS_Queues', 'prl')  ],
    [ container_ready => config_var('WMS_Queues', 'prl')  ],
    [ pick_complete => config_var('WMS_Queues', 'prl')  ],
) {
    my ( $message_name, $queue ) = @$_;
    my $package_name = ucfirst($message_name);
    $package_name =~ s/([_])([a-z])/uc($2)/eg;

    my $full_package_name = ('XT::DC::Messaging::Producer::PRL::' . $package_name);

    # Create the class
    my $mop_class = Moose::Meta::Class->create( $full_package_name,
        superclasses => ['Moose::Object'] );

    # Create the message_spec method
    $mop_class->add_method( message_spec => sub {
        return XT::DC::Messaging::Spec::PRL->$message_name()
    } );

    # Create the transform method
    $mop_class->add_method( transform => sub {
        my ( $self, $header, $data ) = @_;

        my $payload = {
            version => '1.0',
            %$data
        };

        return ($header, $payload);
    } );

    # applying a role changes the class and the metaclass!
    apply_all_roles($full_package_name,'XT::DC::Messaging::Role::Producer');
    $mop_class = $full_package_name->meta;

    # type attributes
    $mop_class->add_attribute( '+type' => (
        default => $message_name,
    ) );
    $mop_class->add_attribute( '+destination' => (
        default => $queue,
    ) );
}

1;
