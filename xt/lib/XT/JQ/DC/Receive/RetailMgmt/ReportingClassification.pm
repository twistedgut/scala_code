package XT::JQ::DC::Receive::RetailMgmt::ReportingClassification;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str Int ArrayRef );
use MooseX::Types::Structured           qw( Dict Optional );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            action      => enum([qw/add delete update/]),
            name        => Str,
            level       => Int,
            classification => Optional[Str],  # But required at level 2 or 3
            product_type   => Optional[Str],  # But required at level 3
            update_name    => Optional[Str],  # for updates only
        ],
    ],
    required => 1,
);

sub check_job_payload {
    return ();
}

sub do_the_task {
    my ($self, $job)    = @_;

    my $schema      = $self->schema;

    $schema->txn_do( sub {
        foreach my $set ( @{ $self->payload } ) {

            # find the reporting item we want to operate on
            my $levelmap = [['Public::Classification',  'classification'],
                            ['Public::ProductType',     'product_type'],
                            ['Public::SubType',         'sub_type']];
            my ($rs_name, $colname) = @{ $levelmap->[($set->{level} - 1)] };
            my $item = $schema->resultset( $rs_name )->search({ $colname => $set->{name} })->first;
            if ($item){
                if ($set->{action} eq 'delete'){
                    $item->delete;
                } elsif ($set->{action} eq 'update' && defined $set->{update_name}){
                    $item->update({$colname => $set->{update_name}});
                }
                # if action eq 'update' and we don't have an update_name, ignore
                # if action eq 'add' and it already exists, ignore
            } else {
                if ($set->{action} eq 'add'){
                    $schema->resultset( $rs_name )->find_or_create({$colname => $set->{name}});
                } elsif ($set->{action} eq 'update' && defined $set->{update_name}) {
                    $schema->resultset( $rs_name )->find_or_create({ $colname => $set->{update_name} });
                }

                # if action eq 'delete' and it doesn't exist, ignore
            }

        }
        $job->completed;
    });
}

1;


=head1 NAME

XT::JQ::DC::Receive::RetailMgmt::ReportingClassification - Add/remove/edit reporting categories

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::RetailMgmt::ReportingClassification when categories are added/removed/edited

Expected Payload should look like:

ArrayRef[
    Dict[
        action      => enum([qw/add delete update/]),
        name        => Str,
        level       => Int,
        classification => Optional[Str],  # But required at level 2 or 3
        product_type   => Optional[Str],  # But required at level 3
        update_name    => Optional[Str],  # for updates only
    ],
],
