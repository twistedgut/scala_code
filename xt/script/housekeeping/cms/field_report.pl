#!/opt/xt/xt-perl/bin/perl -w

use strict;

use Data::Dump qw(pp);
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Moose;

use XTracker::Database ':common';
use XTracker::Comms::DataTransfer ':transfer_handles';

has dbh => (
    is => 'ro',
    isa => 'DBI::db',
    default => sub {
        get_database_handle({ name => 'xtracker', type => 'readonly' });
    },
);
has web_dbh => (
    is => 'ro',
    isa => 'DBI::db',
);

sub xt_fields {
    my ( $self ) = @_;
    my $qry = 'SELECT * FROM web_content.field';
    my $sth = $self->dbh->prepare($qry);
    $sth->execute;
    my $fields;
    while ( my $row = $sth->fetchrow_hashref ) {
        $fields->{$row->{id}} = $row->{name};
    }
    return $fields;
}

sub webapp_fields {
    my ( $self ) = @_;
    my $qry = 'SELECT * FROM field';
    my $sth = $self->web_dbh->prepare($qry);
    $sth->execute;
    my $fields;
    while ( my $row = $sth->fetchrow_hashref ) {
        $fields->{$row->{id}} = $row->{name};
    }
    return $fields;
}

sub compare_fields {
    my ( $self, $xt_fields, $webapp_fields ) = @_;
    my %missing_from_xt = %$webapp_fields;
    my %missing_from_web = %$xt_fields;
    my %mismatch;
    foreach my $id ( keys %$xt_fields ) {
        next unless exists $webapp_fields->{$id};
        if ( $xt_fields->{$id} ne $webapp_fields->{$id} ) {
            $mismatch{$id} = {
                xt => $xt_fields->{$id},
                webapp => $webapp_fields->{$id},
            };
        }
        delete $missing_from_xt{$id};
        delete $missing_from_web{$id};
    }
    return {
        mismatch => \%mismatch,
        missing_from_xt => \%missing_from_xt,
        missing_from_web => \%missing_from_web,
    };
}

sub DEMOLISH {
    my ( $self ) = @_;
    $self->web_dbh->disconnect;
}

# Get channel from user
my $channel = q{};
my $info = q{};
GetOptions( 'channel=s' => \$channel,
            'info' => \$info, );

my $usage = "Usage: field_report.pl --channel nap|outnet|mrp'";
die "Run this script to compare the contents of XT's 'web_content.field' "
  . " and the given frontend's 'field' tables.\n$usage\n"
    if $info;
die "$usage\n"
    unless defined $channel and $channel =~ m{^(?:nap|outnet|mrp)$};

# Instantiate the object and get the fields
my $web_dbh = get_transfer_sink_handle({
    environment => 'live',
    channel => uc $channel,
})->{dbh_sink};

my $cms = __PACKAGE__->new( web_dbh => $web_dbh );

my $xt_fields = $cms->xt_fields;
die "No fields found for XT\n" unless keys %$xt_fields;

my $web_fields = $cms->webapp_fields;
die "No fields found for web db on @{[uc $channel]}\n" unless keys %$web_fields;

# Compare the fields
my $results = $cms->compare_fields( $xt_fields, $web_fields );

# Print report
print "\n " . '*'x6 . ' CMS Field Error Report ' . '*'x6 . "\n";
print "\n " . '*'x12 . " XT vs. @{[uc $channel]} " . '*'x12 . "\n";
print "\n " . '*'x14 . ' Round 1 ' . '*'x13 . "\n";
print "\n " . '*'x14 . ' Fight! ' . '*'x14 . "\n";

print "\nMismatches\n";
print pp ( $results->{mismatch} ) . "\n";

print "\nMissing from @{[uc $channel]}\n";
print pp ( $results->{missing_from_web} ) . "\n";

print "\nMissing from XT\n";
print pp ( $results->{missing_from_xt} ) . "\n";
print "\nDone\n";
