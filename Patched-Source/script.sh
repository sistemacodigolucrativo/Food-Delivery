#!/bin/bash
(crontab -l | grep -v "/usr/bin/php /var/www/html/food-delivery/artisan dm:disbursement") | crontab -
(crontab -l ; echo "00 11 * * 5 /usr/bin/php /var/www/html/food-delivery/artisan dm:disbursement") | crontab -
(crontab -l | grep -v "/usr/bin/php /var/www/html/food-delivery/artisan restaurant:disbursement") | crontab -
(crontab -l ; echo "00 11 * * 3 /usr/bin/php /var/www/html/food-delivery/artisan restaurant:disbursement") | crontab -
