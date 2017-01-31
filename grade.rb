#!/usr/bin/ruby

require 'optparse'

target = nil

OptionParser.new do |o|
  o.banner = <<-HERE
Usage grade.rb [options]
  HERE


  o.on('-o', '--origin', 'Generate report on origin migration test server') { |x| target = 'origin' }
  o.on('-d', '--destination', 'Generate report on destination migration test server') { |x| target = 'destination' }
  o.on('-h', '--help', 'Prints this help') { puts o; exit }

  if ARGV.length != 1
    puts "Please specifiy one option"
    puts o; exit
  end

  o.parse!
end

nginx_run = 'N'
nginx_correct_user = 'N'
php_run = 'N'
php_config = 'N'
eaccel = 'N'
suhosin = 'N'
mysql_run ='N'
mysql_config = 'N'
db_present = 'N'
db_correct_own = 'N'
mysql_correct_user = 'N'
mycnf = 'N'
proftpd_run = 'N'
cyrus_run = 'N'
sasl_run = 'N'
nrpe_run = 'N'
snmpd_run = 'N'
ntpd_run = 'N'
denyhost_run = 'N'
mcollective_run = 'N'
postfix_run = 'N'
emails_copied = 'N'
user_migrated = 'N'
group_migrated = 'N'
copy_perms = 'N'
hosts_copied = 'N'

`ps auxww`.each do |process|
  if process =~ /nginx: worker/
    nginx_run = 'Y'
    if process =~ /^nobody/
      nginx_correct_user = 'Y'
    end
  end

  if process =~ /\/usr\/libexec\/mysqld/
    mysql_run = 'Y'
    if process =~ /^mysql/
      mysql_correct_user = 'Y'
    end
  end

  php_run = 'Y' if process =~ /php-cgi/
  proftpd_run = 'Y' if process =~ /proftpd/
  cyrus_run = 'Y' if process =~ /cyrus-master/
  sasl_run = 'Y' if process =~ /saslauthd/
  nrpe_run = 'Y' if process =~ /nrpe/
  snmpd_run = 'Y' if process =~ /snmpd/
  ntpd_run = 'Y' if process =~ /ntpd/
  denyhost_run = 'Y' if process =~ /denyhosts.py/
  mcollective_run = 'Y' if process =~ /mcollectived/
  postfix_run = 'Y' if process =~ /\/usr\/libexec\/postfix\/master/
end

php_config = 'Y' if `grep 'PHP_CGI_OPTIONS="-a 127.0.0.1 -p 9000 -u nobody -g nobody -C 16"' /etc/sysconfig/spawn-fcgi` && $? == 0
mysql_config = 'Y' if `grep "max_heap_table_size = 512M" /etc/my.cnf` && $? == 0
mycnf = 'Y' if `grep "password=8euhzKrkq2" /root/.my.cnf` && $? == 0
mycnf_perms = "Y" if `stat -c %a /root/.my.cnf` =~ /600/
emails_copied = 'Y' if `grep 'katieweb@gmail.com' /etc/postfix/virtual` && $? == 0
user_migrated = 'Y' if `grep 'celebitchy:x:1000' /etc/passwd` && $? == 0
group_migrated = 'Y' if `grep 'celebitchy:x:1001:bedhead' /etc/group` && $? == 0
copy_perms = 'Y' if `ls -l /home/celebitchy/celebitchy.com/public_html/wp-config.php` =~ /-rw-r--r-- 1 celebitchy celebitchy/
hosts_copied = 'Y' if `grep '127.0.0.1.*db.celebitchy' /etc/hosts` && $? == 0

`php -v`.each do |phpline|
  eaccel = 'Y' if phpline =~ /eAccelerator/
  suhosin = 'Y' if phpline =~ /Suhosin/
end

if File.exists?('/var/lib/mysql/wrdp1/wp_posts.MYD')
  db_present = 'Y'
  if `ls -l /var/lib/mysql/wrdp1/wp_posts.MYD` =~ /mysql mysql/
    db_correct_own = 'Y'
  end
end


if target == 'destination'
  puts <<REPORT
Migration Checklist

1. Migration of running processes:
[#{nginx_run}] nginx
[#{php_run}] php-cgi (spawn-fcgi)
[#{eaccel}] eaccelartor
[#{suhosin}] suhosin
[#{mysql_run}] mysqld
[#{proftpd_run}] proftpd
[#{cyrus_run}] cyrus-imapd
[#{sasl_run}] saslauthd
[#{nrpe_run}] nrpe
[#{snmpd_run}] snmpd
[#{ntpd_run}] ntpd
[#{denyhost_run}] denyhosts (python)
[#{mcollective_run}] mcollectived (ruby)

2. Major service verification

Nginx
[#{nginx_run}] Running
[#{nginx_correct_user}] Running under correct user

MySQLD
[#{mysql_run}] Running
[#{mysql_config}] Verified Config and /etc/my.cnf
[#{db_present}] Databases present
[#{db_correct_own}] Databases have correct ownership
[#{mysql_correct_user}] Running as correct user
[#{mycnf}] Copied over /root/.my.cnf

PHP (w/spawn-fcgi eaccelartor suhosin)
[#{php_run}] Running
[#{php_config}] Verified Config

Mail
[#{postfix_run}] Running
[#{emails_copied}] Verified Config Emails Copied

3. Content and Users
[#{user_migrated}] Users migrated preserving permissions and UIDs and passwds
[#{group_migrated}] Groups migrated preserving permissions and GIDs
[#{copy_perms}] Content copied perserving permissions
[#{hosts_copied}] Copied over /etc/hosts

4. Sanity Checks
[ ] Website loads
[ ] Content looks correct
[ ] Subpages work

Details:
REPORT
end

lineno = 1
puts
puts "==== #{target} :: root ===="
File.open("/root/.bash_history").each_line do |line|
  puts lineno.to_s + "\t" + line
  lineno += 1
end

lineno = 1
puts
puts "==== #{target} :: rcn2migrate ===="
File.open("/home/rcn2migrate/.bash_history").each_line do |line|
  puts lineno.to_s + "\t" + line
  lineno += 1
end
