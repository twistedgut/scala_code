package XT::DC::Model::Pims;
use NAP::policy qw/class/;
extends 'Catalyst::Model';

use XTracker::Pims::API;

sub COMPONENT { XTracker::Pims::API->new; }
