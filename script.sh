#!/bin/bash

opcja=9
userid=$(id -u)
delay_time=4
system_info_file=$(tempfile)
url=http://corecontrol.cba.pl/linuxlab.tar
dl_dir=~/repository
content_dir=~/content

function print_menu {
clear

if [ $userid -eq 0 ]; then
root_opts="
3 - Utworz grupe			
4 - Utworz uzytkownika";
fi

cat <<EOF;
*************************************
1 - Zbierz informacje o systemie  
2 - Wyswietl zapisane informacje $root_opts
5 - Pobierz i przetworz plik     
6 - Wyszukaj frazy w plikach  
0 - Opuszczenie skryptu         
*************************************

Wybierz opcje [1,2,3,4,5 lub 0] >
EOF

}

my_exit () { rm $system_info_file; exit 0; }

# =================================== system info ========================================
function system_info {

    test -f $system_info_file && echo "Usuniecie istniejacego pliku ${system_info_file}";
    echo "Tworzenie pliku ${system_info_file}"

    if [ "$userid" -eq "0" ]; then
        disk="Przestrzeń katalogów domowych wszystkich użytkowników:\n$(du -sh /home/)"
    else
        disk="Przestrzen katalogu domowego uzytkownika:\n$(du -sh $HOME 2>/dev/null)"
    fi

cat <<EOF > $system_info_file
*** Informacje o systemie ***
Zalogowany uzytkownik : $USER
Katalog domowy        : $HOME
Informacje o pamieci:
----------------------------------------------------------------------
$(free)
----------------------------------------------------------------------

Calkowita przestrzen na dysku
----------------------------------------------------------------------
$(df)

----------------------------------------------------------------------
$(echo -e "$disk")
EOF

    echo "Zapisano informacje o systemie"
}

function display_info {

    if [ -f $system_info_file ]; then
        cat $system_info_file
        sleep $delay_time
    else
        echo "Nie ma pliku ${system_info_file}"
        sleep $delay_time
    fi

}
# =================================== system info ========================================

# =================================== grupa /user ========================================

function group_exists {
    awk -F: '{print $1}' /etc/group| grep -w $1 &>/dev/null
    return $?
}

function user_exists {
    awk -F: '{print $1}' /etc/passwd | grep -w $1 &>/dev/null
    return $?
}

function add_group {
    if [ $userid -ne 0 ]; then
	echo "Niewystarczajace uprawnienia"
	sleep $delay_time
	return 0
    fi

    read -p "Podaj nazwę grupy: " grupa
    group_exists $grupa && { echo "Grupa $grupa istnieje"; sleep $delay_time; return 1; }
    addgroup $grupa
    if [ $? -eq 0 ]; then
        echo "Utworzono grupę $grupa"
        sleep $delay_time
        return 0
    fi
}

function add_user {
    if [ $userid -ne 0 ]; then 
	echo "Niewystarczajace uprawnienia"
	sleep $delay_time
	return 0	
    fi
    read -p "Podaj nazwę uzytkownika: " user
    user_exists $user
    while [ $? -ne 1 ]
    do 
        echo "Uzytkownik $user istnieje"
        sleep 1
        clear
        read -p "Podaj nazwę uzytkownika: " user
        user_exists $user
    done

    read -p "Podaj nazwę grupy: " grupa
    group_exists $grupa
    while [ $? -ne 0 ]
    do 
        echo "Grupa $grupa nie istnieje"
        sleep 1
        clear
        read -p "Podaj nazwę grupy: " grupa
        group_exists $grupa
    done
    
    if [ -n "$user" ] && [ -n "$grupa" ]
    then
        useradd -m $user -g $grupa &>/dev/null
        read -p "Podaj hasło: " pass
        echo "${user}:${pass}" | chpasswd
        echo "Utworzono użytkownika $user"
        sleep $delay_time
        return 0
    else 
	echo "Niewystarczajace uprawnienia (uzyj sudo?)"
    fi

}

# =================================== grupa /user ========================================

# =================================== parsowanie pliku====================================

function dir_empty {
    
    [ -d "$1" ] || {
        echo "Tworzenie katalogu $1";
        mkdir "$1";
        return 0;
    }

    if [ "$(ls -A "$1")" ]; then
        return 1
    else
        return 0
    fi
}

function work_on_dir {

    test -d "$1" || { return 1; }

    katalogi_file="${1}/katalogi.txt"

    if [ -f $katalogi_file ]
    then
        mkdir "$content_dir" &>/dev/null
        if [ $? -ne 0 ] && [ "$(ls -A "$content_dir")" ]; then
            read -p "Katalog ${content_dir} nie jest pusty. Usunąc go? [T/N]: " wybor

            case "$wybor" in
            [tT]) rm -rf $content_dir
                echo "Tworzenie katalog $content_dir"
                mkdir $content_dir
                ;;
            *) return 1
                ;;
            esac

        fi

        katalogi=$(cat $katalogi_file | sed -e "s/\r//g")

        echo "Tworzenie struktury katalogów"

        for k in $(echo -e "$katalogi")
        do
            mkdir -p ${content_dir}/${k}
        done

        echo "Przenoszenie plików"
    
	for f in $(ls ${1}/download)
        do
            name="${f%.*}"

            katalog=$(echo -n "$katalogi" | grep -E "${name}$")
            mv ${1}/download/$f ${content_dir}/${katalog}
            echo "${1}/download/$f -> ${content_dir}/${katalog}"
        done
        sleep $delay_time
    else
        false
    fi
}

function do_file {

    dir_empty $dl_dir
    if [ $? -ne 0 ]; then
        read -p "Katalog $dl_dir nie jest pusty. Usunąc go? [Y/N]: " wybor

        case "$wybor" in
		[yY]) rm -rf $dl_dir
            echo "Tworzenie katalogu $dl_dir"
            mkdir $dl_dir
            ;;
		*) return 1
            ;;
    	esac
    fi

    output_file=${dl_dir}/plik.tar
    wget $url -O $output_file &>/dev/null
    cd $dl_dir; tar -xf $output_file
    work_on_dir "${dl_dir}/linuxlab"
}

# =================================== parsowanie pliku====================================

until [ "$opcja" -eq "0" ]; do
	case "$opcja" in
		"1") system_info 
            ;;
		"2") display_info
            ;;
		"3") add_group
            ;;
		"4") add_user
            ;;
		"5") do_file
            ;;

		"0") my_exit
            ;;

	esac
    print_menu
    read -n1 -s opcja
done

my_exit
