package Emitter::Email;
# vim: ts=8 sts=4 et sw=4 sr sta

use Moose;

use MIME::Lite;
use Sys::Hostname;

has 'config' => (
    is          => 'ro',
    isa         => 'HashRef',
    default     => sub { {} },
);


has 'from' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has 'to' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has 'subject' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    default     => '',
);

has 'cc' => (
    is          => 'ro',
    isa         => 'Str',
);

has 'debug' => (
    is          => 'ro',
    isa         => 'Str',
);


sub emit {
    my($self,$output) = @_;
    my($config,$msg);

    my %msg_config = (
        From    => $self->from,
        To      => $self->to,
        Subject => $self->subject,

        Type    => 'TEXT',
        Data    => $output,
    );
    # add the optional Cc value
    if (defined $self->cc) {
        $msg_config{Cc} = $self->cc;
    }
    $msg = MIME::Lite->new( %msg_config );

    $self->_send_email($msg,$config);

    return;
}

sub _send_email {
    my($self,$msg,$config) = @_;

    # if there are specific send options, use them
    # this isn't handled properly yet
    if (exists $self->config->{send}{type} and exists $self->config->{send}{args}) {
        $msg->send(
            $self->config->{send}{type},
            @{ $self->config->{send}{args} }
        );
        return;
    }

    if ($self->debug) {
        warn " Sending to ". $self->to ."\n";
        warn "       with ". $msg->{Data} ."\n";
    }

    my $rv = $msg->send;

    return;
}

1;
