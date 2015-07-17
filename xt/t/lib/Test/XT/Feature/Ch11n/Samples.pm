package Test::XT::Feature::Ch11n::Samples;

use Moose::Role;

#
# Tests for pages in the samples workflow
# Mostly they just check headings and tabs have the right classes
#
use XTracker::Config::Local;
use Test::XTracker::Data;


sub test_mech__samples__stock_control_sample_requests_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_title_ch11n([
        'Pending Stock Requests',
        'Approved Stock Requests',
    ]);
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__samples__stock_control_sample_goodsin_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_title_ch11n([
        'Stock Transfer',
    ]);
    $self->mech_tab_ch11n;

    return $self;
}


1;
