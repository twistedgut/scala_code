#! /bin/bash
if [ $# -ne 4 ]
then
    echo "Error: Invalid Argument Count - "
    echo "This script requires four parameters"
    echo "[1] the absolute csv file name"
    echo "[2] DC code [DC1 DC2 or DC3]"
    echo "[3] XT shipping class id [1 = Same Day, 2 = Ground, 3 = Air]"
    echo "[4] XT shipping is express [true or false]"
    echo ""
    echo "Syntax: $0 absolute_path DCx ship_class is_express"
    echo "For example: $0 availability.csv DC1 3 true"
    exit
fi

./act "runMain scripts.GenerateNewAvailabilitySql $1 $2 $3 $4"
