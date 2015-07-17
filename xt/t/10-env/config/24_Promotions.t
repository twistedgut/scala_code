#!/usr/bin/env perl

use NAP::policy "tt", "test";
use FindBin::libs;


use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local;
use Test::XTracker::RunCondition dc => 'DC1';

# do we have an alert address?
ok(
    defined(config_var('Email', 'promotion_alert')),
    '[Email/promotion_alert] is defined'
);

# INTL
ok(
    defined(config_var('Database_pws_schema_Intl', 'connect_object')),
    '[Database_pws_schema_Intl]/connect_object is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_name')),
    '[Database_pws_schema_Intl]/db_name is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_type')),
    '[Database_pws_schema_Intl]/db_type is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_host')),
    '[Database_pws_schema_Intl]/db_host is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_user_readonly')),
    '[Database_pws_schema_Intl]/db_user_readonly is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_pass_readonly')),
    '[Database_pws_schema_Intl]/db_pass_readonly is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_user_transaction')),
    '[Database_pws_schema_Intl]/db_user_transaction is defined'
);
ok(
    defined(config_var('Database_pws_schema_Intl', 'db_pass_transaction')),
    '[Database_pws_schema_Intl]/db_pass_transaction is defined'
);


# AM
ok(
    defined(config_var('Database_pws_schema_AM', 'connect_object')),
    '[Database_pws_schema_AM]/connect_object is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_name')),
    '[Database_pws_schema_AM]/db_name is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_type')),
    '[Database_pws_schema_AM]/db_type is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_host')),
    '[Database_pws_schema_AM]/db_host is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_user_readonly')),
    '[Database_pws_schema_AM]/db_user_readonly is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_pass_readonly')),
    '[Database_pws_schema_AM]/db_pass_readonly is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_user_transaction')),
    '[Database_pws_schema_AM]/db_user_transaction is defined'
);
ok(
    defined(config_var('Database_pws_schema_AM', 'db_pass_transaction')),
    '[Database_pws_schema_AM]/db_pass_transaction is defined'
);

done_testing;
