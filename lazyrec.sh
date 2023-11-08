#!/bin/bash


display_banner() {
    echo "====================================================="
    figlet -f slant LAZYREC
    echo "====================================================="
    echo "Versão: 1.0"
    echo "Desenvolvido por Gabriel Jehnen"
    echo -e "=====================================================\n"
}

display_banner
TARGETS_LIST=$1

#if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
#    echo "Usage: $0 <targets_file.txt> [foldername (optional)]"
#    exit 1
#elif ! test -f "$TARGETS_LIST" -o -r "$TARGETS_LIST"; then
#  echo "The first argument must be a text file."
#  echo "Usage: $0 <targets_file.txt> [foldername (optional)]"
#  exit 1
#fi

FOLDER_NAME=${2:-"lazyrec"}
USERNAME=$(whoami)
FOLDER_PATH=/home/$USERNAME/$FOLDER_NAME

echo $1
cat $1

mkdir $FOLDER_PATH
cp $1 $FOLDER_PATH
cd $FOLDER_PATH

pwd

download_patterns(){
    cd ~; mkdir .gf; cd .gf;
    git clone https://github.com/1ndianl33t/Gf-Patterns.git;
    cd Gf-Patterns; mv * ..; rm -r Gf-Patterns;
    cd $FOLDER_PATH;
}

install_tools(){
    author="$1"
    shift
    for tool in "$@"; do
        tool_name=$(echo $tool | awk -F/ '{print $NF}')
        echo $tool_name
        if ! command -v "$tool_name" &> /dev/null; then
            if $tool_name == "naabu"; then
                sudo apt install -y libcap-dev
            fi
            echo "$tool_name não está instalado. Instalando..."
            go install -v "github.com/$author/$tool@latest"
        fi
	if ! ls ~/.gf 1> /dev/null 2>&1; then
	    download_patterns
	fi
    done
    pwd
}

subdomain_enum(){
    echo -e "Starting Subdomain Enumeration (1/6)\n"
    meg /.well-known/security.txt --savestatus 200 $TARGETS_LIST &
    subfinder -dL $TARGETS_LIST -o subfinder.txt &
    cat $TARGETS_LIST | assetfinder --subs-only > assetfinder.txt &
    wait
    sort -u -o all_subs.txt subfinder.txt assetfinder.txt
    cat all_subs.txt | httprobe > active_urls.txt
    rm assetfinder.txt; rm subfinder.txt; rm all_subs.txt
    echo -e "Finished Subdomain Enumeration\n"
}

verify_subtakeover(){
    echo -e "Verifying Urls vulnerable to Subdomain Takeover (2/6)\n"
    subzy run --targets active_urls.txt
    echo -e "Finished Verifying Subs Takeover\n"
}

gather_urls(){
    echo -e "Gathering Url's... This may take a while (\n"
    cat active_urls.txt | gau --threads 5 > gau.txt
}

port_scan(){
    echo -e "Starting Port Scanning (3/6)\n"
    sed 's~^https://~~' active_urls.txt > raw_active_urls.txt
    naabu -list raw_active_urls.txt -exclude-ports 80,443 -v -o ports.txt 
    rm raw_active_urls.txt
    echo -e "Finished Port Scanning\n"
}

gf(){
    mkdir patterns
    cat gau.txt | gf xss > patterns/xss.txt
    cat gau.txt | gf sqli > patterns/sqli.txt
    cat gau.txt | gf redirect > patterns/redirect.txt
    cat gau.txt | gf idor > patterns/idor.txt
    cat gau.txt | gf lfi > patterns/lfi.txt
}


# Instale as ferramentas de diferentes autores
install_tools "tomnomnom" "assetfinder" "httprobe" "gf" "waybackurls"
install_tools "projectdiscovery" "subfinder/v2/cmd/subfinder" "naabu/v2/cmd/naabu" "katana/cmd/katana"
install_tools "lc" "gau/v2/cmd/gau"
install_tools "PentestPad" "subzy"

subdomain_enum
verify_subtakeover
port_scan
gather_urls
gf

