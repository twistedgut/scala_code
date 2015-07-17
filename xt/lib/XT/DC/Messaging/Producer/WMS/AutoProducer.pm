package XT::DC::Messaging::Producer::WMS::AutoProducer;
use NAP::policy "tt";
use Moose::Meta::Class;
use Moose::Util 'apply_all_roles';
use XT::DC::Messaging::Role::Producer;
use XTracker::Config::Local qw( config_var );

=head1 NAME

XT::DC::Messaging::Producer::WMS::AutoProducer

=head1 DESCRIPTION

Instantiate a number of light-weight Producer::WMS classes

=head1 SYNOPSIS

None. To add new classes, patch the code.

=head1 WHY

To make testing easier, it's helpful if we can produce messages we want to
receive. This involves creating Producer classes for those messages. Where we
usually want to provide some helper code for producing the messages we'll be
sending in production, for testing we largely just need to be able to pass in
the payload.

Inside this class is a for-loop which specifies some messages and their target
queues, and spins up lightweight producer classes for these.

=cut

use XT::DC::Messaging::Spec::WMS;

# Set up our subclasses
for (
    # Message name          Queue
    [ ready_for_printing => config_var('WMS_Queues', 'xt_wms_printing')  ],
    [ inventory_adjust   => config_var('WMS_Queues', 'xt_wms_inventory')  ],
    [ printing_done      => config_var('WMS_Queues', 'wms_printing') ],
    [ shipment_refused   => config_var('WMS_Queues', 'xt_wms_fulfilment')  ]
) {
    my ( $method_name, $queue ) = @$_;

    # Put together a sensible class name
    my $package_name = ucfirst($method_name);
    $package_name =~ s/([_])([a-z])/uc($2)/eg;
    my $full_package_name = ('XT::DC::Messaging::Producer::WMS::' . $package_name);

    # Create the class
    my $mop_class = Moose::Meta::Class->create( $full_package_name,
        superclasses => ['Moose::Object'] );

    # Create the message_spec method
    my $spec = XT::DC::Messaging::Spec::WMS->$method_name;
    $mop_class->add_method(
        message_spec => sub {
            return $spec;
        }
    );

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

    # type attribute
    $mop_class->add_attribute( '+type' => (
        default => $method_name,
    ) );

    # destination attribute
    $mop_class->add_attribute( '+destination' => (
        default => $queue,
    ) );
}

1;
