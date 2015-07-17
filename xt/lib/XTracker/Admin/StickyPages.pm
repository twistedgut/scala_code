package XTracker::Admin::StickyPages;

use strict;
use warnings;

use DateTime;

use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Error;
use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    if ( $handler->auth_level != $AUTHORISATION_LEVEL__MANAGER ) {
        xt_warn(q{You don't have permission to access Sticky Pages in Admin});
        return $handler->redirect_to( '/Home' );
    }

    my $sticky_rs = $handler->schema->resultset('Operator::StickyPage');

    if ( grep { $_ && m{Remove} } ($handler->{param_of}{submit}) ) {
        my @operator_ids = map {
            $handler->{param_of}{$_}
        } grep { m{^remove_} } keys %{$handler->{param_of}};
        my $deleted = $sticky_rs->search({
            operator_id => { -in => \@operator_ids }
        })->delete;
        xt_success("Deleted $deleted sticky pages");
        return $handler->redirect_to( $handler->path );
    }

    $handler->{data}{content}    = 'shared/admin/sticky_pages.tt';
    $handler->{data}{section}    = 'User Admin';
    $handler->{data}{subsection} = 'Sticky Pages';

    $handler->{data}{stickies} = [$sticky_rs->search(undef, {
        join => 'operator',
        '+columns' => ['operator.name'],
        order_by => ['operator.name'],
    })->all];
    # We should always be in UTC by default for both $dts, but let's make sure
    my $yesterday = DateTime->now(time_zone => 'UTC')->subtract(days => 1);
    $handler->{data}{is_sticky_old} = {map {;
        $_->operator_id => DateTime->compare( $_->created->set_time_zone( 'UTC' ), $yesterday ) <= 0
                         ? 1 : 0
    } @{$handler->{data}{stickies}}};

    return $handler->process_template;
}

1;
