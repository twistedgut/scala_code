#! /bin/bash
if [ $# -ne 2 ]
then
    echo "Error: Invalid Argument Count - enter absolute file name followed by DC code [DC1 DC2 or DC3]"
    echo "Syntax: $0 absolute_path DCx"
    exit
fi

./act "runMain scripts.GenerateNewCopySql $1 $2"
