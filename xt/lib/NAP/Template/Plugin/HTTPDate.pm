package NAP::Template::Plugin::HTTPDate;

use strict;
use warnings;
use true;

use base qw{ Template::Plugin };

use DateTime;
use DateTime::Format::HTTP;
use DateTime::Format::Pg;
use Time::ParseDate;

=head1 NAME

NAP::Template::Plugin::HTTPDate

=head1 DESCRIPTION

TT wrapper for DateTime::Format::HTTP

=cut

sub new {
    my ($class, $context, @args) = @_;
    my $obj = bless {}, $class;
    return $obj;
}

=head1 METHODS

=head2 from_pg

=cut

sub from_pg {
    my ($self, $dt_str) = @_;

    my $dt = DateTime::Format::Pg->parse_datetime($dt_str);
    return DateTime::Format::HTTP->format_datetime($dt);
}

=head2 from_zulu

=cut

sub from_zulu {
    my ($self, $dt_str) = @_;

    my $epoch = parsedate($dt_str);
    my $dt = DateTime->from_epoch(epoch => scalar $epoch );

    return DateTime::Format::HTTP->format_datetime($dt);
}

=head2 now

=cut

sub now {
    my $self = shift;

    return DateTime::Format::HTTP->format_datetime(
               DateTime->now()
           );
}
