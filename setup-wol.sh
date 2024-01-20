#!/bin/bash

genservice() {
    local network_interface="$1"
    local script_path="/usr/local/bin"
    local bash_path=$(command -v bash)

    cat <<EOF | sudo tee /etc/systemd/system/setup-wol.service > /dev/null
[Unit]
Description=Auto activate WOL service.

[Service]
Type=simple
ExecStart=$bash_path $script_path/setup-wol.sh $network_interface
ExecStop=$bash_path $script_path/setup-wol.sh $network_interface

[Install]
WantedBy=default.target
EOF

    echo "Daemon file was created at: /etc/systemd/system/setup-wol.service"
}

install() {
    local network_interface="$1"
    local script_path="/usr/local/bin"

    sudo cp setup-wol.sh $script_path/
    genservice $network_interface

    sudo systemctl daemon-reload
    sudo systemctl enable setup-wol.service
    sudo systemctl start setup-wol.service
    echo "Installation complete."
}

uninstall() {
    sudo systemctl disable setup-wol.service
    sudo systemctl stop setup-wol.service

    sudo rm /etc/systemd/system/setup-wol.service
    sudo rm /usr/local/bin/setup-wol.sh

    sudo systemctl daemon-reload
    echo "Uninstallation complete."
}

setup_wol() {
    local network_interface="$1"
    wol_status=$(sudo ethtool $network_interface | grep "Wake-on:" | awk '{print $2}' | cut -c1 | cut -d$'\n' -f2)

    if [ "$wol_status" == "g" ]; then
        echo "Wake-on-LAN is already enabled on the $network_interface interface."
        exit 0
    else
        echo "Wake-on-LAN is not enabled. Configuring..."
        sudo ethtool -s "$network_interface" wol g

        new_wol_status=$(sudo ethtool "$network_interface" | grep "Wake-on:" | awk '{print $2}' | cut -c1 | cut -d$'\n' -f2)
        if [ "$new_wol_status" == "g" ]; then
            echo "Wake-on-LAN has been successfully configured on the $network_interface interface."
            exit 0
        else
            echo "Failed to configure Wake-on-LAN on the $network_interface interface. Check the configuration manually."
            exit 1
        fi
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 --interface <network_interface> [--run|--install|--uninstall]"
    exit 1
fi

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --interface|-i)
            shift
            interface="$1"
            ;;
        --run|-r)
            setup_wol $interface
            exit 0
            ;;
        --install|-I)
            install $interface
            ;;
        --uninstall|-ui)
            uninstall
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
    shift
done
