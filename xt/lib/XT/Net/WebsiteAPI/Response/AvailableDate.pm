package XT::Net::WebsiteAPI::Response::AvailableDate;
use NAP::policy "tt", "class";
extends "XT::Net::Response::Object";

=head1 NAME

XT::Net::WebsiteAPI::Response::AvailableDate - Value object returned by call to nominatedday/availabledates

=cut

use XT::Data::Types;

has delivery_date => (is => "ro", isa => "XT::Data::Types::DateStamp", coerce => 1, required => 1);
has dispatch_date => (is => "ro", isa => "XT::Data::Types::DateStamp", coerce => 1, required => 0);

=head2 as_data() : $data_structure

In addition to the normal data structure, add *_human keys for the
dates.

=cut

sub _as_human {
    my ($self, $datestamp) = @_;
    $datestamp // return $datestamp;
    return $datestamp->human;
}

my $ymd_template = "%d-%m-%Y";
sub as_data {
    my $self = shift;
    return {
        %{$self->SUPER::as_data(@_)},
        delivery_date_human => $self->_as_human($self->delivery_date),
        dispatch_date_human => $self->_as_human($self->dispatch_date),
    };
}
