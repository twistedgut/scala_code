package XT::JQ::DC::Receive::Operator::Import;

use Moose;

use Data::Dump qw/pp/;

use MooseX::Types::Moose qw( Str Int Bool );
use MooseX::Types::Structured qw( Dict Optional );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        id => Int,
        name => Str,
        username => Str,
        auto_login => Optional[Int],
        disabled => Optional[Int],
        email_address => Optional[Str],
        phone_ddi => Optional[Str],
        use_ldap => Optional[Bool],
    ],
    required => 1
);


sub do_the_task {
    my ($self, $job) = @_;

    my $error = "";

    my $operator= $self->schema->resultset('Public::Operator');
    my %cols = %{$self->payload};

    $self->schema->txn_do(
        sub {
            my $oper_rec = $operator->find( $self->payload->{id} );

            if ( defined $oper_rec ) {
                delete $cols{id};
                $oper_rec->update( \%cols );
            } else {
                $cols{password} = 'new';
                $operator->create( \%cols );
            }
        }
    );
    if ($@) {
        $error = "Couldn't Create/Update User: ".$@;
    }

    return ($error);
}

sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Receive::Operator::Import - Create/Update an Operator

=head1 DESCRIPTION

This message is sent via the Fulcrum system when a User is either
created or updated.

Expected Payload should look like:

{
 id => 12345
 name => 'John Smith',
 username => 'j.smith',
 auto_login => 0,   # This field and the ones below are optional
 disabled => 0,
 email_address => 'k.smith@net-a-porter.com',
 phone_ddi => '01234 123456',
 use_ldap => 1
}
