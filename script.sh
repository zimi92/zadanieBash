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

wyjdz () { rm $system_info_file; exit 0; }

# =================================== system info ========================================
function informacjeOSystemie {

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

function wyswietlInformacje {

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

function instniejacaGrupa {
    awk -F: '{print $1}' /etc/group| grep -w $1 &>/dev/null
    return $?
}

function instniejacyUser {
    awk -F: '{print $1}' /etc/passwd | grep -w $1 &>/dev/null
    return $?
}

function dodajGrupe {
    if [ $userid -ne 0 ]; then
	    echo "Niewystarczajace uprawnienia"
	    sleep $delay_time
	    return 0
    fi

    read -p "Podaj nazwę grupy: " grupa
    instniejacaGrupa $grupa && { echo "Grupa $grupa istnieje"; sleep $delay_time; return 1; }
    addgroup $grupa
    if [ $? -eq 0 ]; then
        echo "Utworzono grupę $grupa"
        sleep $delay_time
        return 0
    fi
}

function dodajUsera {
    if [ $userid -ne 0 ]; then 
	echo "Niewystarczajace uprawnienia"
	sleep $delay_time
	return 0	
    fi
    read -p "Podaj nazwę uzytkownika: " user
    instniejacyUser $user
    while [ $? -ne 1 ]
    do 
        echo "Uzytkownik $user istnieje"
        sleep 1
        clear
        read -p "Podaj nazwę uzytkownika: " user
        instniejacyUser $user
    done

    read -p "Podaj nazwę grupy: " grupa
    instniejacaGrupa $grupa
    while [ $? -ne 0 ]
    do 
        echo "Grupa $grupa nie istnieje"
        sleep 1
        clear
        read -p "Podaj nazwę grupy: " grupa
        instniejacaGrupa $grupa
    done
    
    if [ -n "$user" ] && [ -n "$grupa" ]
    then
        useradd -m $user -g $grupa &>/dev/null
        read -p "Podaj hasło: " pass
        echo "${user}:${pass}" | chpasswd
        echo "Utworzono użytkownika $user"
        sleep $delay_time
        return 0
    fi

}

# =================================== grupa /user ========================================

# =================================== parsowanie pliku====================================

function pustaScierzka {
    
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

function pracujWKatalgou {

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

function stworzKatalog {

    pustaScierzka $dl_dir
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
    pracujWKatalgou "${dl_dir}/linuxlab"
}

# =================================== parsowanie pliku====================================

until [ "$opcja" -eq "0" ]; do
	case "$opcja" in
case "$opcja" in
		"1") clear 
			 system_info
            ;;
		"2") clear
			 display_info
            ;;
		"3") clear
			 add_group
            ;;
		"4") clear
			 add_user
            ;;
		"5") clear
			 do_file
            ;;
		"0") wyjdz
            ;;

	esac
    print_menu
    read -n1 -s opcja
done

wyjdz
