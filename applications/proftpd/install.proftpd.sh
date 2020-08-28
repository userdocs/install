#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
## Firewall rules
#
# ufw allow 23001
# ufw allow 23002
# ufw allow 23003:23103/tcp
#
app_pass="$(< /dev/urandom tr -dc '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' | head -c20; echo;)"
#
install_dir="$HOME/.proftpd"
file_filename="$HOME/proftpd.tar.gz"
#
sftp_port="23001"
ftps_port="23002"
#
port_range_min="23003"
port_range_max="23103"
#
jail_path="$HOME/download"
#
delete_file () {
	[[ -f "$file_filename" ]] && rm -rf {"$(tar tf "$file_filename" | grep -Eom1 "(.*)[^/]")","$file_filename"}
}
#
delete_file
#
[[ -d "$install_dir" ]] && rm -rf "$install_dir"
#
mkdir -p "$install_dir/etc/sftp/authorized_keys"
mkdir -p "$install_dir/etc/keys"
mkdir -p "$install_dir/ssl"
#
conf_proftpd="https://raw.githubusercontent.com/userdocs/install/master/applications/proftpd/conf/proftpd.conf"
conf_sftp="https://raw.githubusercontent.com/userdocs/install/master/applications/proftpd/conf/sftp.conf"
conf_ftps="https://raw.githubusercontent.com/userdocs/install/master/applications/proftpd/conf/ftps.conf"
#
wget -qO ~/proftpd.tar.gz https://github.com/proftpd/proftpd/archive/v1.3.7.tar.gz
tar xf ~/proftpd.tar.gz
cd "$(tar tf ~/proftpd.tar.gz | head -1 | cut -f1 -d"/")"
#
install_user="$(whoami)" install_group="$(whoami)" ./configure --prefix="$install_dir" --enable-openssl --enable-sodium --enable-dso --enable-nls --enable-ctrls --with-shared=mod_ratio:mod_readme:mod_sftp:mod_tls:mod_ban:mod_shaper:mod_ident
make
make install
#
##
#
ssh-keygen -q -m PEM -t rsa -f "$install_dir/etc/keys/sftp_rsa" -N ''
ssh-keygen -q -m PEM -t dsa -f "$install_dir/etc/keys/sftp_dsa" -N ''
ssh-keygen -q -m PEM -t dsa -f "$install_dir/etc/keys/sftp_ed25519" -N ''
#
openssl req -new -x509 -nodes -days 1095 -subj '/C=UK/ST=none/L=none/O=none/OU=none/CN=none' -newkey rsa:3072 -sha256 -keyout "$install_dir/ssl/proftpd.rsa.key.pem" -out "$install_dir/ssl/proftpd.rsa.cert.pem"
openssl req -new -x509 -nodes -days 1095 -subj '/C=UK/ST=none/L=none/O=none/OU=none/CN=none' -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -keyout "$install_dir/ssl/proftpd.ec.key.pem" -out "$install_dir/ssl/proftpd.ec.cert.pem"
#
## Download conf files
#
wget -qO "$install_dir/etc/proftpd.conf" "$conf_proftpd"
wget -qO "$install_dir/etc/sftp.conf" "$conf_sftp"
wget -qO "$install_dir/etc/ftps.conf" "$conf_ftps"
#
## proftpd.conf
#
sed "s|JAIL_PATH|$jail_path|g" -i "$install_dir/etc/proftpd.conf"
sed "s|PATH|$install_dir|g" -i "$install_dir/etc/proftpd.conf"
sed "s|PassivePorts 23003 23103|PassivePorts $port_range_min $port_range_max|g" -i "$install_dir/etc/proftpd.conf"
sed "s|User my_username|User $(whoami)|g" -i "$install_dir/etc/proftpd.conf"
sed "s|Group my_username|Group $(whoami)|g" -i "$install_dir/etc/proftpd.conf"
sed "s|AllowUser my_username|AllowUser $(whoami)|g" -i "$install_dir/etc/proftpd.conf"
#
## sftp.conf
#
sed "s|PATH|$install_dir|g" -i "$install_dir/etc/sftp.conf"
sed "s|Port 23001|Port $sftp_port|g" -i "$install_dir/etc/sftp.conf"
#
## ftps.conf
#
sed "s|PATH|$install_dir|g" -i "$install_dir/etc/ftps.conf"
sed "s|Port 23002|Port $ftps_port|g" -i "$install_dir/etc/ftps.conf"
#
##
#
echo "$app_pass" | "$install_dir/bin/ftpasswd" --passwd --name="$(whoami)" --file="$install_dir/etc/ftpd.passwd" --uid="$(id -u "$(whoami)")" --gid="$(id -g "$(whoami)")" --home="$HOME" --shell="/bin/false" --stdin
"$install_dir/bin/ftpasswd" --group --name="$(whoami)" --file="$install_dir/etc/ftpd.group" --gid="$(id -g "$(whoami)")" --member="$(whoami)"
#
echo -e "\n\033[31m""FTPS/SFTP Connection Settings:""\e[0m"
echo
echo -e "This is your hostname: ""\033[32m""$(curl -s4 icanhazip.com)""\e[0m"
echo
echo -e "This is your" "\033[32m""SFTP""\e[0m" "port:" "\033[32m""$(sed -nr 's/^Port (.*)/\1/p' $install_dir/etc/sftp.conf)""\e[0m"
echo
echo -e "This is your" "\033[32m""FTPS""\e[0m" "port:" "\033[32m""$(sed -nr 's/^Port (.*)/\1/p' $install_dir/etc/ftps.conf)""\e[0m"
#
echo -e "\nThis is your main username: ""\033[32m""$(whoami)""\e[0m"" and this is your password: ""\033[32m""$app_pass""\e[0m"
#
echo -e "\n$install_dir/sbin/proftpd -c $install_dir/etc/sftp.conf"
echo -e "\n$install_dir/sbin/proftpd -c $install_dir/etc/ftps.conf"
echo
#
delete_file
#
exit
