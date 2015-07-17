package Lyris::Schema;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::Schema';

use XTracker::Logfile qw(xt_logger);
__PACKAGE__->exception_action(
    sub{
        __PACKAGE__->stacktrace(1);
        xt_logger->warn(@_);
        __PACKAGE__->stacktrace(0);
    }
);

__PACKAGE__->load_classes();

1;
