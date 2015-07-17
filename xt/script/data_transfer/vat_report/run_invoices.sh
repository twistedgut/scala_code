#!/bin/sh

EXCHANGE_RATE=1.24
FILE_PATH=/opt/xt/deploy/xtracker/script/data_transfer/vat_report

echo "Generating Invoices..."
${FILE_PATH}/country_reports/greece_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/romania_vat_report.pl --exchange_rate=${EXCHANGE_RATE}
${FILE_PATH}/country_reports/get_romanian_customer.pl

${FILE_PATH}/country_reports/estonia_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/lithuania_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/malta_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/slovakia_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/luxembourg_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

${FILE_PATH}/country_reports/spain_vat_report.pl --exchange_rate=${EXCHANGE_RATE}
${FILE_PATH}/country_reports/get_spain_customer.pl
${FILE_PATH}/country_reports/get_product_list.pl

${FILE_PATH}/country_reports/bulgaria_vat_report.pl --exchange_rate=${EXCHANGE_RATE}

zip ${FILE_PATH}/EU_VAT_REPORTS ${FILE_PATH}/output/*

cp ${FILE_PATH}/EU_VAT_REPORTS.zip /var/data/xt_static/export/.

${FILE_PATH}/send_report_email.pl
