package XT::JQ::DC::Receive::Product::Comment;

use Moose;

use Data::Dump qw/pp/;

use MooseX::Types::Moose      qw( Str Int Maybe );
use MooseX::Types::Structured qw( Dict );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Database::Operator qw( :common );
use XTracker::Database::Product  qw(
    create_product_comment
    delete_product_comment
    search_product_comments
);


has payload => (
    is => 'ro',
    isa => Dict[
        username   => Str,
        product_id => Int,
        comment    => Str,
        action     => Str
    ],
    required => 1
);


sub do_the_task {
    my ($self, $job) = @_;

    my $error       = "";

    eval { $self->schema->txn_do(sub{
        if ( $self->payload->{action} eq "add" ) {
            create_product_comment( $self->dbh, {
                comment       => $self->payload->{comment},
                operator_id   => $self->data->{operator}{id},
                department_id => $self->data->{operator}{department_id},
                product_id    => $self->payload->{product_id}
            } );
        }
        if ( $self->payload->{action} eq "delete" ) {
            my $comment_list = search_product_comments( $self->dbh, {
                user_id    => $self->data->{operator}{id},
                product_id => $self->payload->{product_id},
                comment    => $self->payload->{comment}
            } );

            if ( @{$comment_list} ) {
                foreach my $comment ( @{$comment_list} ) {
                    delete_product_comment( $self->dbh, $comment->{id} );
                }
            }
        }
    })};
    if ($@) {
        $error  = $@;
    }

    return ($error);
}

sub check_job_payload {
    my ($self, $job) = @_;

        if ( $self->payload->{action} ne "add" && $self->payload->{action} ne "delete" ) {
                return ("Action: ".$self->payload->{action}.", is not known");
        }

        my $operator= get_operator_by_username( $self->dbh, $self->payload->{username} );
        if ( !defined $operator ) {
                $operator       = get_operator_by_username( $self->dbh, 'appuser' );
                if ( !defined $operator ) {
                        return ("Can't Find Operator for Operator Id or 'appuser' user: ".$self->payload->{operator_id});
                }
        }
        $self->data->{operator} = $operator;

    my $product_id = $self->payload->{product_id};
    return ("Can't Find Product for Product Id: $product_id")
        unless $self->schema->resultset('Public::Product')->find($product_id);

    return ();
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::Comment - Add/Delete Product Comments
product

=head1 DESCRIPTION

This message is sent via the Fulcrum system when a comment is either
created or deleted for a product.

Expected Payload should look like:

{
        product_id      => 12345
        username        => 'a.user',
        comment         => 'comment goes here',
        action          => 'add' or 'delete'
}
