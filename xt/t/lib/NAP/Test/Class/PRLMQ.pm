package NAP::Test::Class::PRLMQ;
use NAP::policy "tt", 'test', 'role';

# Implementation for this should be trivially updateable when we have
# NAP::Messaging

=head1 NAME

NAP::Test::Class::PRLMQ - Role for easily testing PRL message handlers

=head1 SYNOPSIS

 # In your test class that consumed this role

 # Create a message directly - no checking is done until you try and send it
 my $message = $self->create_message(
    AdviceResponse => {
        foo => 'bar',
        baz => 'ban'
    }
 );

 # Or create a template and then specialize it
 my $advice_response_template = $self->message_template(
    AdviceResponse => {
        foo => 'bar'
    }
 );
 my $message2 = $advice_response_template->({ baz => 'ban' });

 # Then execute the handler for the message. Validation, lookup, etc, are all
 # done at this point. You will need to handle any exceptions thrown.
 $self->send_message( $message );

=cut

use Hash::Merge qw();
use XT::DC::Messaging::Spec::PRL;
use MooseX::Params::Validate qw/pos_validated_list/;
use Test::MockObject;
use Moose::Util 'apply_all_roles';
use Data::Dump qw/pp/;
use Module::Runtime 'require_module';


=head1 METHODS

=head2 create_message

Takes a message name in CamelCase form, and a hashref, and returns a `message`
- a black box about which you should make no assumptions - suitable for passing
in to C<send_message>.

=cut

sub create_message {
    my $self = shift;
    my ( $message_name, $payload, $overridden ) = pos_validated_list(
        \@_,
        { isa => 'Str' },     # message_name
        { isa => 'HashRef' }, # payload
        # May well be used by message_template for diagnostics in the future
        { isa => 'HashRef', default => sub {{}} }, # overridden
    );

    # This is liable to change, you are REQUIRED to treat messages as black
    # boxes
    return {
        name => $message_name,
        payload => $payload,
        overridden => $overridden,
    };
}

=head2 message_template

Takes a message name in CamelCase form, and a hashref, and returns a subref.
When executed with a hashref, that subref will merge the initial hashref and
the passed in one, and return a message, as per C<create_message> above. For
example, these are equivalent:

 ->create_message( Foo => { abc => 1, def => 2, ghi => 3 } );

 ->message_template( Foo => { abc => 1, def => 7 } )
    ->({ def => 2, ghi => 3 });

=cut

sub message_template {
    my $self = shift;
    my ( $message_name, $payload ) = pos_validated_list(
        \@_,
        { isa => 'Str' },     # message_name
        { isa => 'HashRef' }, # payload
    );

    my $merge = Hash::Merge->new( 'RIGHT_PRECEDENT' );
    return sub {
        my $overrides = shift() || {};
        my $msg = $merge->merge( $payload, $overrides );
        $self->create_message( $message_name => $msg, $overrides );
    };
}

=head2 send_message

Attempts to validate and deliver a message to the handler.

=cut

sub send_message {
    my ( $self, $message ) = @_;

    # Resolve and load the message class
    my $name = $message->{'name'} || die "Message without a name!";
    my $class = "XT::DC::Messaging::Plugins::PRL::$name";
    require_module $class;
    my $handler = $class->new();
    my $type = $handler->message_type;

    # Extract payload, and perhaps add a version
    my $payload = $message->{'payload'};
    $payload->{'version'} = '0.1' unless exists $payload->{'version'};

    NAP::Messaging::Validator->add_type_plugins('NAP::DC::PRL::Type');
    # Validation step here

    my ($ok,$errors) = NAP::Messaging::Validator->validate(
        NAP::DC::PRL::MessageSpec->$type,
        $payload,
    );
    if (!$ok) {
        die sprintf("Failed to validate message: %s \nAgainst specification: %s\n%s\nError: %s",
            pp( $message->{'payload'} ),
            $type,
            pp( NAP::DC::PRL::MessageSpec->$type ),
            $errors || 'No reason given')
    }

    my $mock_consumer = NAP::Test::Class::PRLMQ::MockedConsumer->new();
    return $handler->handler($mock_consumer,$payload,{type=>$type});
}



package NAP::Test::Class::PRLMQ::MockedConsumer { ## no critic(ProhibitMultiplePackages)
    use NAP::policy "tt", 'class';
    # Fake "context" for the AMQ handler
    use Test::More;

    has log => (
        is => 'ro',
        lazy_build => 1,
    );

    sub _build_log {
        my $logger = Test::MockObject->new();
        for my $type (qw/debug info warn error/) {
            $logger->mock( $type, sub {
                               my $self = shift;
                               note uc($type) . ': ' . $_ for @_;
                           });
        }
        return $logger;
    }

    sub model {
        my ($self, $model_name) = @_;

        if ( $model_name eq 'Schema' ) {
            return Test::XTracker::Data->get_schema();
        }
        # Allow Catalyst-type calling mechanism
        if ( $model_name =~ s/^Schema::// ) {
            return scalar $self->model('Schema')->resultset( $model_name );
        }
        # non-database models
        if ( $model_name eq 'MessageQueue' ) {
            my $msg_queue = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
            $msg_queue->transformer_args->{schema} = Test::XTracker::Data->get_schema();
            return $msg_queue;
        }
        die "Don't know how to handle model $model_name"
    }
}

1;
