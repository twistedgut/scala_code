package DBIx::Class::InflateColumn::Interval;

# This code was mercilessly pinched from DBIx::Class::InflateColumn::Time and fiddled abit

use strict;
use warnings;

use base qw/DBIx::Class/;

use DateTime::Duration;
use namespace::autoclean;

our $VERSION = '0.0.1'; # VERSION
# ABSTRACT: Automagically inflates interval columns into DateTime::Duration objects

=pod

=encoding utf8

=head1 NAME

DBIx::Class::InflateColumn::Interval - Inflate and Deflate "interval" columns
    into DateTime::Duration Objects

=head1 DESCRIPTION

This module can be used to automagically inflate database columns of data type "interval" into
DateTime::Duration objects.  It is used similiar to other InflateColumn DBIx modules.

Once your Result is properly defined you can now pass DateTime::Duration objects into columns
of data_type time and retrieve DateTime::Duration objects from these columns as well

=head1 METHODS

Strictly speaking, you don't actually call any of these methods yourself.  DBIx handles the magic
provided you have included the InflateColumn::Time component in your Result.

Therefore, there are no public methods to be consumed.

=cut

sub register_column {
    my ($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return unless $info->{data_type} eq 'interval';

    $self->inflate_column(
        $column => {
            inflate => \&_inflate,
            deflate => \&_deflate,
        }
    );
}

sub _inflate {
    my $value = shift;

    my ($sign, $hours, $minutes, $seconds) = $value =~ m/(-?)0?(\d+):0?(\d+):0?(\d+)/g;

    ### Sign: (defined $sign ? "-" : "+")
    ### Hours: $hours
    ### Minutes: $minutes
    ### Seconds: $seconds

    my $duration = DateTime::Duration->new({
        hours   => $hours,
        minutes => $minutes,
        seconds => $seconds,
    });

    if($sign) {
        return $duration->inverse;
    }

    return $duration;
}

sub _deflate {
    my $value = shift;

    # For time purposes we'll always assume that a day is 24 hours.
    my $hours = $value->hours + ($value->days * 24);

    my $time = ($value->is_negative ? '-' : '')
               . sprintf( $hours >= 100 ? "%03d" : "%02d" , $hours)   . ':'
               . sprintf( "%02d", $value->minutes) . ':'
               . sprintf( "%02d", $value->seconds);

    return $time;
}

1;
