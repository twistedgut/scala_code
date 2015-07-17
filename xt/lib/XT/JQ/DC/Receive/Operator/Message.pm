package XT::JQ::DC::Receive::Operator::Message;

use Moose;

use MooseX::Types::Moose        qw( Str Int ArrayRef );
use MooseX::Types::Structured   qw( Dict );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => ArrayRef[
        Dict[
            recipient_id    => Int,
            sender_id       => Int,
            subject         => Str,
            body            => Str,
        ]
    ],
    required => 1
);


sub do_the_task {
    my ( $self, $job )  = @_;

    my $error   = "";

    my $message = $self->schema->resultset('Operator::Message');

    $self->schema->txn_do( sub {

        foreach my $msg ( @{ $self->payload } ) {
            $message->create( $msg );
        }

    } );
    if ($@) {
        $error  = "Couldn't Create Messages: ".$@;
    }

    return ($error);
}

sub check_job_payload {
    my ( $self, $job )  = @_;

    my @ids = map { $_->{recipient_id} } @{ $self->payload };

    my $found   = $self->schema->resultset('Public::Operator')->count( { 'id' => { 'in' =>  \@ids } } );

    if ( $found != @ids ) {
        return ("Couldn't Find All the Recipient Operator Id's, found ".$found." out of ".@ids);
    }

    return ();
}

1;


=head1 NAME

XT::JQ::DC::Send::Receive::Message - Receive a Message for an Operator

=head1 DESCRIPTION

This receives message for operators from Fulcrum.

[
    {
        recipient_id    => 904,
        sender_id       => 56,
        subject         => 'Subject of Message',
        body            => 'Message Body'
    }
]
