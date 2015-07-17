package XT::JQ::DC::Receive::Product::UploadDate;

use Moose;

use Data::Dump qw/pp/;

use MooseX::Types::Moose qw(Str Int Undef ArrayRef);
use MooseX::Types::Structured qw(Dict );


use namespace::clean -except => 'meta';
use XTracker::Database::Product         qw( set_upload_date );
use XTracker::Database::Channel         qw( get_channels );

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    required => 1,
    isa => ArrayRef[
            Dict[
             channel_id     => Int,
             product_id     => Int,
             upload_date    => Str|Undef,
            ]
    ]
);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub do_the_task {
    my ($self, $job) = @_;

    my $schema = $self->schema;
    my $guard = $schema->txn_scope_guard;
    my $channels    = get_channels( $self->dbh );

    foreach my $record ( @{ $self->payload } ) {

        if ( !exists $channels->{ $record->{channel_id} } ) {
            next;
        }

        # set update date for product/channel
        set_upload_date(
            $self->dbh,
            {
                product_id  => $record->{product_id},
                channel_id  => $record->{channel_id},
                date        => $record->{upload_date},
            }
        );
    }
    $guard->commit;
}

sub check_job_payload {
    my ($self, $job) = @_;

    foreach my $record ( @{ $self->payload } ) {
        if ( defined $record->{upload_date} ) {
            unless ( $record->{upload_date} =~ m/\d{4}-\d{2}-\d{2}/ ) {
                return (
                    'Upload date for product_id '
                    .$record->{product_id}
                    .', channel_id '.$record->{channel_id}
                    .' does not match expected format YYYY-MM-DD : '
                    . $record->{upload_date}
                );
            }
        }
    }

    return ();
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::UploadDate - Notification of product upload date for
a given channel received from Fulcrum

=head1 DESCRIPTION

This message contains the upload date for (a given product and channel, if a product has been
 removed from an upload then the date sent could genuinely be undefined.


