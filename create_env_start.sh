#!/bin/bash
file=".env"
echo "Creating .env file"
touch .env
echo "#.env file for managing enviornment variable'" > $file
echo "Adding DISABLE_FEATURE_API= 'false' to .env file"
echo "DISABLE_FEATURE_API='false'" >> $file
echo "Adding DISABLE_FEATURE_API= 'false' to .env file"
echo "ENABLE_NEW_FEATURE='false'" >> $file
echo "Creating DB Config"
echo "DB_HOST='localhost'" >> $file
echo "DB_PORT=5433" >> $file
echo "DB_DATABASE='feature_flag'" >> $file
echo "DB_USER='postgres'" >> $file
echo "DB_PASSWORD='my_password'" >> $file
echo "DB_FEATURE_AUDIT_DATABASE='feature_flag_audit'" >> $file