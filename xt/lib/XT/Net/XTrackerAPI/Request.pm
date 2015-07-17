package XT::Net::XTrackerAPI::Request;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";

=head1 NAME

XT::Net::XTrackerAPI::Request - Base class for Request endpoints

=cut

use XTracker::Schema::Result::Public::Operator;
use XT::Net::XTrackerAPI::Request::Authorization;

=head1 ATTRIBUTES

=cut

has operator => (
    is       => "ro",
    isa      => "XTracker::Schema::Result::Public::Operator",
    required => 1,
);

has authorization => (
    is      => "ro",
    isa     => "XT::Net::XTrackerAPI::Request::Authorization",
    default => sub { XT::Net::XTrackerAPI::Request::Authorization->new() },
);

1;
