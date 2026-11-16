#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT/config/ngiwix.env"
WG_NIC=$(grep -oP '^SERVER_WG_NIC=\K\S+' /etc/wireguard/params 2>/dev/null || echo wg0)
cd "$ROOT" || exit 1



set_env() {   # usage: set_env API_TOKEN "$api_key"
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"
    grep -v "^$1=" "$ENV_FILE" > "$ENV_FILE.tmp" || true
    echo "$1=$2" >> "$ENV_FILE.tmp"
    mv "$ENV_FILE.tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

configure_en_v(){
    echo ""
    echo "Select an option to configure"
    echo ""
    echo "1. Configure access API KEY"
    echo "2. Configure MAX WIREGUARD TUNNEL LIMIT"
    echo "3. Configure MAX NGINIX TUNNEL LIMIT"
    echo ""
    read -p "Enter a number (default: 1): " number3
    number3=${number3:-1}

    if ! [[ "$number3" =~ ^[1-3]$ ]]; then
        echo "invalid choice"
        exit 1
    fi

    if [ "$number3" -eq "1" ]; then
        read -p "Enter the new API key: " api_key
        if [[ -z "$api_key" ]]; then
            echo "Empty api key!"
            exit 1
        fi
        set_env API_TOKEN "$api_key"
    
    elif [ "$number3" -eq "2" ]; then
        read -p "Enter a tunnel limit(1-253): " wireguard_t_limit
        if ! [[ $wireguard_t_limit =~ ^[0-9]+$ ]] || [ "$wireguard_t_limit" -lt 1 ] || [ "$wireguard_t_limit" -gt 253 ]; then
            echo "Invalid Tunnel limit!"
            exit 1
        fi
        set_env MAX_WG_TUNNELS "$wireguard_t_limit"

    elif [ "$number3" -eq "3" ]; then
        read -p "Enter a nginix config limit: " nginix_conf_limit
        if ! [[ $nginix_conf_limit =~ ^[0-9]+$ ]] || [ "$nginix_conf_limit" -lt 1 ]; then
            echo "Invalid config limit!"
            exit 1
        fi
        set_env MAX_NGINX_CONFIGS "$nginix_conf_limit"

    fi
}

automaticInstall(){
    echo "Automatic installer running"

    echo "Installing nginx..."
    bash "$SCRIPT_DIR"/nginx/installNginix.sh

    echo "Installing Wireguard..."
    bash "$SCRIPT_DIR"/wireguard/installWireguard.sh

    echo "Installing PYthon-Api..."
    bash "$SCRIPT_DIR"/pyapi/pyApiInstall.sh

    echo "Configuring environment variables..."
    configure_en_v

    echo ""
    echo "installed successfully"
    exit 0
}


maninMenu(){
    echo "======================================================"
    echo "            Welcome to Ngiwix installer               "
    echo "======================================================"
    echo "Choose an option to continue:"
    echo ""
    echo "1. Automatic installer"
    echo "2. Manual Installer"
    echo "3. Configure Python-Api variables"
    echo "4. Start services"
    echo "5. Stop services"
    echo "6. Uninstall Ngiwix"
    echo ""
    read -p "Enter a number (default: 1): " number1
    number1=${number1:-1}

    if ! [[ "$number1" =~ ^[1-6]$ ]]; then
        echo "invalid choice"
        exit 1
    fi
    
    if [ "$number1" -eq "1" ]; then
        automaticInstall

    elif [ "$number1" -eq "2" ]; then
        echo ""
        echo "Select install options"
        echo ""
        echo "1. Install docker-Nginx only"
        echo "2. Install Wireguard only"
        echo "3. Add Python-Api interface"
        echo ""
        read -p "Enter a number (default: 1): " number2
        number2=${number2:-1}

        if ! [[ "$number2" =~ ^[1-3]$ ]]; then
            echo "invalid choice"
            exit 1
        fi

        if [ "$number2" -eq "1" ]; then
            echo "Installing Nginx..."
            bash "$SCRIPT_DIR"/nginx/installNginix.sh
            echo ""
            echo "installed successfully"
            exit 0

        elif [ "$number2" -eq "2" ]; then
            echo "Installing Wireguard..."
            bash "$SCRIPT_DIR"/wireguard/installWireguard.sh
            echo ""
            echo "installed successfully"
            exit 0

        elif [ "$number2" -eq "3" ]; then
            echo "Installing Python-Api..."
            bash "$SCRIPT_DIR"/pyapi/pyApiInstall.sh
            echo "Configuring environment variables..."
            echo ""
            configure_en_v
            echo ""
            echo "installed successfully"
            exit 0
        fi


    elif [ "$number1" -eq "3" ]; then
        configure_en_v


    elif [ "$number1" -eq "4" ]; then
        echo ""
        echo "Select a service to start: "
        echo ""
        echo "0. All Ngiwix services"
        echo "1. nginx"
        echo "2. wireguard"
        echo "3. Python Api"
        echo ""
        read -p "Enter a number (default: 0): " number4
        number4=${number4:-0}

        if ! [[ "$number4" =~ ^[0-3]$ ]]; then
            echo "invalid choice"
            exit 1
        fi

        if [ "$number4" -eq "0" ]; then
            echo ""
            echo "Starting Nginx..."
            docker compose start nginx
            echo "nginx started!"
            echo "Starting Wireguard..."
            sudo wg-quick up "$WG_NIC"
            echo "Wireguard started!"
            echo "Starting Python-Api..."
            docker compose start python-api
            echo "Python-Api started!"
        
        elif [ "$number4" -eq "1" ]; then
            echo ""
            echo "Starting Nginx..."
            docker compose start nginx
            echo "nginx started!"
            echo ""
            exit 0

        elif [ "$number4" -eq "2" ]; then
            echo ""
            echo "Starting Wireguard..."
            sudo wg-quick up "$WG_NIC"
            echo "Wireguard started!"
            echo ""
            exit 0

        elif [ "$number4" -eq "3" ]; then
            echo ""
            echo "Starting Python-Api..."
            docker compose start python-api
            echo "Python-Api started!"
            echo ""
            exit 0
        fi


    elif [ "$number1" -eq "5" ]; then
        echo ""
        echo "Select a service to stop: "
        echo ""
        echo "0. All Ngiwix services"
        echo "1. nginx"
        echo "2. wireguard"
        echo "3. Python Api"
        echo ""
        read -p "Enter a number (default: 0): " number5
        number5=${number5:-0}

        if ! [[ "$number5" =~ ^[0-3]$ ]]; then
            echo "invalid choice"
            exit 1
        fi

        if [ "$number5" -eq "0" ]; then
            echo ""
            echo "Stopping Nginx..."
            docker compose stop nginx
            echo "nginx stopped!"
            echo "Stopping Wireguard..."
            sudo wg-quick down "$WG_NIC"
            echo "Wireguard stopped!"
            echo "Stopping Python-Api..."
            docker compose stop python-api
            echo "Python-Api stopped!"
        
        elif [ "$number5" -eq "1" ]; then
            echo ""
            echo "Stopping Nginx..."
            docker compose stop nginx
            echo "nginx stopped!"
            echo ""
            exit 0

        elif [ "$number5" -eq "2" ]; then
            echo ""
            echo "Stopping Wireguard..."
            sudo wg-quick down "$WG_NIC"
            echo "Wireguard stopped!"
            echo ""
            exit 0

        elif [ "$number5" -eq "3" ]; then
            echo ""
            echo "Stopping Python-Api..."
            docker compose stop python-api
            echo "Python-Api stopped!"
            echo ""
            exit 0
        fi


    elif [ "$number1" -eq "6" ]; then
        read -r -p "This removes all Ngiwix services. Continue? [y/N]: " yn
        [[ $yn =~ ^[Yy]$ ]] || { echo "Cancelled"; exit 0; }
        echo "Running uninstaller...."

        echo "Uninstalling Nginix container..."
        bash "$SCRIPT_DIR"/nginx/uninstallNginix.sh

        echo "Uninstalling Wireguard..."
        bash "$SCRIPT_DIR"/wireguard/uninstallWireguard.sh

        echo "Uninstalling Python-Api..."
        bash "$SCRIPT_DIR"/pyapi/pyApiInstall.sh --uninstall

        echo "Removing environment variables..."
        rm -rf "$ROOT/config"

        echo ""
        echo "All services uninstalled successfully"
        exit 0
            
    fi


}



maninMenu