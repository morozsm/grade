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
php_config = 'N'
eaccel = 'N'
mysql_run ='N'
mysql_config = 'N'
db_present = 'N'
db_correct_own = 'N'
mysql_correct_user = 'N'
mycnf = 'N'
mycnf_perms = "N"
proftpd_run = 'N'
cyrus_run = 'N'
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
apache_run = 'N'
apache_mod_rpaf = 'N'
custom_script_migrated = 'N'
cron_migrated = 'N'
fw_rules_migrated = 'N'
fw_rules_applied = 'N'

`ps auxww`.each do |process|
  if process =~ /nginx: worker/
    nginx_run = 'Y'
    if process =~ /^nobody/
      nginx_correct_user = 'Y'
    end
  end

  if process =~ /\/usr\/sbin\/mysqld/
    mysql_run = 'Y'
    if process =~ /^mysql/
      mysql_correct_user = 'Y'
    end
  end

  apache_run = 'Y' if process =~ /httpd/
  proftpd_run = 'Y' if process =~ /proftpd/
  cyrus_run = 'Y' if process =~ /cyrus-master/
  nrpe_run = 'Y' if process =~ /nrpe/
  snmpd_run = 'Y' if process =~ /snmpd/
  ntpd_run = 'Y' if process =~ /ntpd/
  denyhost_run = 'Y' if process =~ /denyhosts.py/
  mcollective_run = 'Y' if process =~ /mcollectived/
  postfix_run = 'Y' if process =~ /\/usr\/libexec\/postfix\/master/
end

php_config = 'Y' if `rpm -qa|grep php` && $? == 0
mysql_config = 'Y' if `grep "max_heap_table_size = 8192M" /etc/my.cnf` && $? == 0
mycnf = 'Y' if `grep "password=8euhzKrkq2" /root/.my.cnf` && $? == 0
mycnf_perms = "Y" if `stat -c %a /root/.my.cnf` =~ /600/
emails_copied = 'Y' if (`grep 'support@serverstack.com' /etc/postfix/virtual` && $? == 0) && (`sasldblistusers2 |grep support@serverstack.com` && $? == 0)
user_migrated = 'Y' if `grep 'serverstack:x:500' /etc/passwd` && $? == 0
group_migrated = 'Y' if `grep 'serverstack:x:500' /etc/group` && $? == 0
copy_perms = 'Y' if `ls -l /home/serverstack/blog.serverstack.com/public_html/wp-config.php` =~ /-rw-r--r-- 1 serverstack serverstack/
hosts_copied = 'Y' if `grep 'db.origin-2.0' /etc/hosts` && $? == 0
apache_mod_rpaf = 'Y' if `httpd -M|grep rpaf_module` =~ /rpaf_module/
cron_migrated = 'Y' if `crontab -l` =~ /custom_script.sh/

`php -v`.each do |phpline|
  eaccel = 'Y' if phpline =~ /eAccelerator/
end

custom_script_migrated = 'Y' if File.exists?('/usr/local/bin/custom_script.sh')
fw_rules_migrated = 'Y' if File.exists?('/etc/sysconfig/iptables') && (`grep '10.15.252.102/32 -j ACCEPT' /etc/sysconfig/iptables` && $? == 0)
fw_rules_applied = 'Y' if `iptables -L -n|grep 'ACCEPT     all  --  10.15.252.102'` && $? == 0


if File.exists?('/var/lib/mysql/serverstack/wp_posts.MYD')
  db_present = 'Y'
  if `ls -l /var/lib/mysql/serverstack/wp_posts.MYD` =~ /mysql mysql/
    db_correct_own = 'Y'
  end
end

if target == 'destination'
  puts <<REPORT
Migration Checklist

1. Migration of running processes:
[#{nginx_run}] nginx
[#{eaccel}] eaccelartor
[#{mysql_run}] mysqld
[#{proftpd_run}] proftpd
[#{cyrus_run}] cyrus-imapd
[#{nrpe_run}] nrpe
[#{snmpd_run}] snmpd
[#{ntpd_run}] ntpd
[#{denyhost_run}] denyhosts (python)
[#{mcollective_run}] mcollectived (ruby)

2. Major service verification

Nginx
[#{nginx_run}] Running
[#{nginx_correct_user}] Running under correct user

Apache
[#{apache_run}] Is apache running?
[#{apache_mod_rpaf}] mod_rpaf installed?

MySQLD
[#{mysql_run}] Running
[#{mysql_config}] Verified Config and /etc/my.cnf
[#{db_present}] Databases present
[#{db_correct_own}] Databases have correct ownership
[#{mysql_correct_user}] Running as correct user
[#{mycnf}] Copied over /root/.my.cnf
[#{mycnf_perms}] Hardened my.cnf permissions

PHP (eaccelartor)
[#{php_config}] Verified Config

Mail
[#{postfix_run}] Running
[#{emails_copied}] Verified Config Emails Copied

Firewall
[#{fw_rules_migrated}] Firewall rules migrated
[#{fw_rules_applied}] Firewall rules applied

3. Content and Users
[#{user_migrated}] Users migrated preserving permissions and UIDs and passwds
[#{group_migrated}] Groups migrated preserving permissions and GIDs
[#{copy_perms}] Content copied perserving permissions
[#{hosts_copied}] Copied over /etc/hosts
[#{custom_script_migrated}] Custom script migrated.
[#{cron_migrated}] Cron job migrated

4. Sanity Checks
[ ] Website loads
[ ] Content looks correct
[ ] Subpages work

Details:
REPORT
end

=begin
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
=end
