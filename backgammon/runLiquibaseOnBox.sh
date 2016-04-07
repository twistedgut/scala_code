#!/bin/bash

# Leaving this file in the project as a reference on how to run liquibase on a box that has the smcapi rpm installed:

smcapi -Dconfig.file=/etc/smcapi/application.conf -main nap.database.LiquibaseRunner
