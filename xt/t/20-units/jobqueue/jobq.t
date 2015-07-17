#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

# evil globals
our ($schema);


BEGIN {
    plan tests => 14;

    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Handler');
}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'jobqueue_schema',
    }
);
isa_ok($schema, 'JobQueue::Schema',"Schema Created");

my $rec;
my $rs = $schema->resultset('Job')->search({ 'func.funcname' => { 'not like' => '%FailedJob' } }, { prefetch => 'func', order_by => 'jobid DESC' } );
isa_ok($rs,"DBIx::Class::ResultSet","Not Failed Job Search");

SKIP: {
    skip "Not Failed Job Search",2 if ( !$rs->count );
    $rec = $rs->next();
    isa_ok($rec,"JobQueue::Schema::Job","Not Failed Job Record");
    unlike($rec->func->funcname,qr/.*FailedJob/,"Not Failed Job");
};

$rs = $schema->resultset('Job')->search({ 'func.funcname' => { 'like' => '%FailedJob' } }, { prefetch => 'func', order_by => 'jobid DESC' } );
isa_ok($rs,"DBIx::Class::ResultSet","Failed Job Search");

SKIP: {
    skip "Failed Job Search",2 if ( !$rs->count );
    $rec = $rs->next();
    isa_ok($rec,"JobQueue::Schema::Job","Failed Job Record");
    like($rec->func->funcname,qr/.*FailedJob/,"Failed Job");
};

SKIP: { skip "Failed Job search",2 if ( !$rs->count ); $rs =
    $schema->resultset('FuncMap')->search( { funcname => {
    'not like' => '%::Send::%' }, 'me.funcname' => { 'not like' =>
    '%::Receive::%' } }, { order_by => 'funcid' } );

    isa_ok($rs,"DBIx::Class::ResultSet","Func Map Search");
    $rec = $rs->next();
    isa_ok($rec,"JobQueue::Schema::FuncMap","Func Map Record");
};

SKIP: {
    skip "Failed Job search",2 if ( !$rs->count );
    $rs = $schema->resultset('ExitStatus')->search( undef, { prefetch => 'func', order_by => 'completion_time DESC', rows => '50' } );
    isa_ok($rs,"DBIx::Class::ResultSet","Exit Status Search");
    $rec = $rs->next();
    isa_ok($rec,"JobQueue::Schema::ExitStatus","Exit Status Record");
};
