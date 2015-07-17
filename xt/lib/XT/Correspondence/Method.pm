package XT::Correspondence::Method;

use NAP::policy "tt",     'class';
use Safe::Isa;

=head1 XT::Correspondence::Method

This is used to send Correspondence for 'Correspondence Subject Method' records to Customers.

    my $corr_method_obj = XT::Correspondence::Method->new( {
                                                    csm_rec     => $correspondence_subject_method record
                                                    record      => The record used as a basis for sending the Correspondence
                                                    use_to_send => The Class such as 'Shipment' or 'Order' to use as a basis to find
                                                                   the correct Email or Mobile number to send the Correspondence to
                                                    body        => The body of the Message that will be sent

                                                    # there will also be Method Specific Arguments
                                                    # see relevant 'X:C::Method::*' Classes
                                            } );

This is the factory base Class used by:

    * XT::Correspondence::Method::Email
    * XT::Correspondence::Method::SMS

When being instantiated it will use the 'csm_rec' to determin which is the appropriate Class to return
and return an object of that Class. It will call that Classes 'BUILD' method to validate anything that
needs validating for that Class alone.


First done for CANDO-576.

=cut

use MooseX::Types::Moose qw( Object );
use XT::Data::Types;

use Module::Pluggable::Object;
with 'XTracker::Role::WithAMQMessageFactory';

use XTracker::Config::Local         qw( config_section_slurp config_var email_address_for_setting );
use XTracker::Utilities             qw( class_suffix_matches time_now );
use XTracker::EmailFunctions        qw( send_email );
use XTracker::XTemplate;

=head1 ATTRIBUTES

This Class has the following Attributes:

=cut

# used to find the appropriate Method Class to use
has _plugin_search_path => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub {
                    return [ qw(
                            XT::Correspondence::Method
                        ) ];
                },
    required=> 1,
);

#
# The following are Common Attributes used by the 'XT::Correspondence::Method::*' classes
#

=head2 csm_rec

the 'correspondent_subject_method' record

=cut

has csm_rec => (
    is      => 'ro',
    isa     => 'Object',
    init_arg=> 'csm_rec',
    required=> 1,
);

=head2 schema

Will be derived from the 'csm_rec' and can't be overwritten.

=cut

has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    lazy_build  => 1,
    init_arg    => undef,
);

=head2 channel

The Sales Channel record dervied from 'csm_rec' and can't be overwritten.

=cut

has channel => (
    is          => 'ro',
    isa         => 'Object',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 logger

Used for logging, will be build when needed but can also be passed to 'new()'.

=cut

has logger  => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    init_arg    => 'logger',
    lazy_build  => 1,
);

=head2 send_record

The record that will be the basis to get information about where to send the correspondence to such as
Email Address or Mobile Number, such as 'order' or 'shipment'.

Will be derived from the 'use_to_send' argument passed to 'new()' but can also be passed directly to 'new()'.

=cut

has send_record => (
    is          => 'rw',
    isa         => 'Object',
    init_arg    => 'send_record',
    required    => 1,
);

=head2 body

The body of the correspondence, Email Text or SMS Message etc.

=cut

has body => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'body',
    required    => 1,
);

=head2 base_record

The record that was being used to send the correspondence about such as 'shipment' or 'return'.

This will be taken from the 'record' argument in 'new()' but can also be passed directly to 'new()'.

=cut

has base_record => (
    is          => 'ro',
    isa         => 'Object',
    init_arg    => 'base_record',
    required    => 1,
);

=head2 need_to_copy_to_crm

Indicates whether there is a need to send any message to a 'CRM' like E-gain after the main message has been sent.

Will be derived from the 'csm_rec' but can also be passed to 'new()'.

=cut

has need_to_copy_to_crm => (
    is          => 'rw',
    isa         => 'Bool',
    init_arg    => 'copy_to_crm',
    lazy_build  => 1,
);

# this attribute is used to hold all the
# data required to notify the CRM
has _copy_to_crm_data => (
    is          => 'rw',
    isa         => 'HashRef',
    init_arg    => undef,
    default     => sub { return {}; },
);

has _failure_code => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => undef,
);


# translate the Args passed in
# to the above attributes
around BUILDARGS => sub {
    my ( $orig, $class, $args ) = @_;

    if ( ref( $args ) ne 'HASH' ) {
        croak "No Arguments or Arguments not a Hash Ref. passed to '" . __PACKAGE__ . "'";
    }

    # change some arguments passed in so
    # that they are for the Class Attributes

    if ( exists( $args->{record} ) ) {
        if ( !$args->{record} || !ref( $args->{record} ) ) {
            croak "Argument 'record' must be an object like a DBIC Class for '" . __PACKAGE__ . "'";
        }
        $args->{base_record}    = delete $args->{record};
    }

    if ( exists( $args->{use_to_send} ) ) {
        if ( !$args->{use_to_send} ) {
            croak "Argument 'use_to_send' has been passed but not defined for '" . __PACKAGE__ . "'";
        }
        if ( $args->{use_to_send}->$_can('isa') ) {
            $args->{send_record}    = delete $args->{use_to_send};
        }
        else {
            if ( !$args->{base_record}->$_can('isa') || !$args->{base_record}->$_can('next_in_hierarchy_from_class') ) {
                croak "Argument 'base_record' or 'record' - '" . ref( $args->{base_record} ) . "', must have 'Schema::Role::Hierarchy' or pass the record in directly in the 'use_to_send' Argument for '" . __PACKAGE__ . "'";
            }
            my $use_to_send = ucfirst( delete $args->{use_to_send} );
            $args->{send_record}    = $args->{base_record}->next_in_hierarchy_from_class( $use_to_send, { stop_if_me => 1 } );
            if ( !$args->{send_record} ) {
                croak "Couldn't find a record for Class '$use_to_send' passed in 'use_to_send' Argument for '" . __PACKAGE__ . "'";
            }
        }
    }

    return $class->$orig( $args );
};

# used to figure out which Class should actually
# be instantiated based on the 'csm_rec'
sub BUILD {
    my ( $self, $args ) = @_;

    # only do this for XT::Correspondence::Method, not the Plugins
    my $class   = ref( $self );
    if ( __PACKAGE__ eq $class ) {
        my $finder  = Module::Pluggable::Object->new(
                                search_path     => $self->_plugin_search_path,
                                require         => 1,
                                inner           => 0,
                            );
        my $method_class    = "${class}::" . $self->csm_rec->correspondence_method->method;

        my @method_type = grep { m/^${method_class}$/ } $finder->plugins;
        if ( !@method_type ) {
            croak "Couldn't Find a Method Class '$method_class' when building '" . __PACKAGE__ . "'";
        }
        elsif ( @method_type > 1 ) {
            croak "Found more than one class for Method Class '$method_class' when building '" . __PACKAGE__ . "'";
        }

        # Re-Bless $self so that it is now the Plugin's Class, BUILD & BUILDARGS
        # won't be called but Attributes will be populated with contents of %{ $args }
        $method_class->meta->rebless_instance( $self, %{ $args } );
        $self->BUILD( $args );      # call the BUILD on the new object, to cleanup anything that needs it
    }

    return $self;
};

=head1 METHODS

Here are the Methods for this Class.

=cut

=head2 copy_to_crm

    $boolean    = $self->copy_to_crm;

Use this method to send information to the CRM (such as E-gain) about any correspondence that has been sent.

This will use the '_copy_to_crm_data' attribute to send a message to the CRM. Each 'XT::Correspondence::Method::*'
Class should have a 'before' version that should be used to build up the '_copy_to_crm_data' hash.

=cut

sub copy_to_crm {
    my ( $self, @args )     = @_;

    my $data    = $self->_copy_to_crm_data;

    if ( !$data->{sales_channel} ) {
        # work out the Sales Channel including Instance
        my $instance    = $self->channel->web_name;
        $instance       =~ s/.*-//g;
        $data->{sales_channel}  = $self->channel->name . ", " . $instance;
    }
    if ( !$data->{message_body} ) {
        $data->{message_body}   = $self->body;
    }

    $data->{template_type}  = 'email'       if ( !exists( $data->{template_type} ) );
    my $email_to    = email_address_for_setting( 'crm_email', $self->channel );
    my $email_from  = delete $data->{email_from};
    my $subject     = $self->csm_rec->correspondence_subject->description . " " .
                      $self->csm_rec->correspondence_method->description . " for " .
                      "$data->{sales_channel} order";

    my $result  = 0;
    if ( $email_to && $email_from ) {
        eval {
            my $template    = XTracker::XTemplate->template;
            my $message;
            $template->process( 'email/internal/' . delete $data->{template}, $data, \$message );
            $result = $self->send_an_email( {
                            from    => $email_from,
                            replyto => $email_from,
                            to      => $email_to,
                            subject => $subject,
                            body    => $message,
                            email_args => { no_bcc => 1 },
                        } );
        };
        if ( my $err = $@ ) {
            $self->logger->warn( "Failed to Copy Message to CRM for '$email_from' in '" . __PACKAGE__ . "' with the following error:\n$err" );
        }
    }

    return $result;
}

=head2 send_an_email

    $status = $self->send_an_email( {
                                    from    => $from_addr,
                                    replyto => $replyto_addr,
                                    to      => $to_addr,
                                    subject => $subject,
                                    body    => $body,
                                    type    => 'plain' or 'html'    # will default to plain if not present
                                    attachments => { ... },
                                    email_args  => { ... },
                                } );

This is just a wrapper for the 'XTracker::EmailFunctions::send_email' function but because various
things actually do send email for failure Alerts as well as for Correspondence Emails then this
acts as a central place to call that function, should it ever be superseded.

=cut

sub send_an_email {
    my ( $self, $args ) = @_;

    return send_email(
                $args->{from},
                $args->{replyto},
                $args->{to},
                $args->{subject},
                $args->{body},
                $args->{type} || "",
                $args->{attachments},
                $args->{email_args},
            );
}

=head2 _ok_to_send

    $boolean    = $self->_ok_to_send;

This will return TRUE or FALSE based on various checks if it is ok to send using the Correspondence Method.

Any failure Codes will be put in '$self->_failure_code'.

Each 'Correspondence::Method::*' can have it's own version that goes 'around' in a Moose way this one.

=cut

sub _ok_to_send {
    my $self    = shift;

    if ( !$self->csm_rec->correspondence_method->enabled ) {
        $self->_failure_code('METHOD_RECORD_DISABLED');
        return 0;
    }

    if ( !$self->csm_rec->enabled ) {
        $self->_failure_code('METHOD_DISABLED_ON_CSM_RECORD');
        return 0;
    }

    if ( !$self->csm_rec->correspondence_subject->enabled ) {
        $self->_failure_code('SUBJECT_RECORD_DISABLED');
        return 0;
    }

    if ( !$self->channel->can_communicate_to_customer_by( $self->csm_rec->correspondence_method->method ) ) {
        $self->_failure_code('METHOD_DISABLED_FOR_CHANNEL');
        return 0;
    }

    if ( !$self->csm_rec->window_open_to_send( time_now ) ) {
        $self->_failure_code('WINDOW_CLOSED');
        return 0;
    }

    return 1;
}


# get a Schema out of the 'csm_rec'
sub _build_schema {
    my $self    = shift;
    return $self->csm_rec->result_source->schema;
}

# get a Sales Channel base on the 'csm_rec'
sub _build_channel {
    my $self    = shift;
    return $self->csm_rec->correspondence_subject->channel;
}

# helper method to check what Class something is
# using not just the Full Class name, I.e. 'Shipment'
# instead of 'XTracker::Schema::Result::Public::Shipment'
sub _class_isa {
    my ( $self, $obj, $class )  = @_;

    return 0        if ( !$obj || !$class );
    return class_suffix_matches( $obj, $class );
}

# set the 'need_to_copy_to_crm' flag
sub _build_need_to_copy_to_crm {
    my $self    = shift;
    return $self->csm_rec->copy_to_crm;
}

sub _build_logger {
    my $self    = shift;
    require XTracker::Logfile;
    return XTracker::Logfile::xt_logger();
}

1;
