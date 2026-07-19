#!/usr/bin/env bash

while true
do

clear

echo "=========================================="
echo "      BugBountyOS Professional"
echo "=========================================="

echo

echo "1) Install Everything"

echo "2) Update Everything"

echo "3) Verify Installation"

echo "4) System Doctor"

echo "5) Exit"

echo

read -p "Choose: " opt

case $opt in

1)

bash install.sh

;;

2)

bash update.sh

;;

3)

bash verify.sh

;;

4)

bash doctor.sh

;;

5)

exit

;;

*)

echo "Invalid"

;;

esac

done
