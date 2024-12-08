#!/bin/bash
usage="$(basename "$0") [-h] [-p package_name] [-d deb-file] [-m mode]
Verify the contents and file permissions (file security attributes) of the installed deb-packages,
where:
    -h  show this help text
    -p  package name - for example 'mc'
    -d  deb-file name - for example 'mc_3%3a4.8.29-2_amd64.deb'
    -m  mode (optional) - 'f' (files, default), 'd' (directories), 'l' (symlinks)
    -q  quiet operation (optional), only show errors
    
Please note that usrmerge may cause inaccurate results, this will be fixed later."

compare_mode="f"
be_quiet=0

while getopts ":hp:d:m:q" opt; do
  case "$opt" in
    h) echo "$usage"; exit;;
    p) pkg_name=$OPTARG;;
    d) pkg_file=$OPTARG;;
    m) compare_mode=$OPTARG;;
    q) be_quiet=1;;
    \?) echo "Error: unimplemented option chosen!"; echo "$usage" >&2; exit 1;;
  esac
done

if [ ! "$pkg_name" ] || [ ! "$pkg_file" ]; then
    echo "Error: arguments -p and -f must be provided!"
    echo "For example: deb-verify.sh -p mc -d mc_3%3a4.8.29-2_amd64.deb"
    echo "$usage" >&2; exit 1
fi

if [ $be_quiet == 0 ]; then
    echo -n "Working with package '$pkg_name' with deb-file '$pkg_file' and compare-mode '$compare_mode': "
fi
# permissions   user/group  size    date time   object (->) link_target
# 1                 2         3      4    5       6      7       8

if [ "$compare_mode" == "f" ]; then
    pkg_filelist_files=$(mktemp)
    dpkg -c "$pkg_file" | awk '{print $1" "$2" "$3" "$6" "$7" "$8}' | sed "s| \.\/| /|g" | grep -vE "^d|^l|^h" > "$pkg_filelist_files"
    fs_filelist_files=$(mktemp)
fi

if [ "$compare_mode" == "l" ]; then
    pkg_filelist_links=$(mktemp)
    dpkg -c "$pkg_file" | awk '{print $1" "$2" "$6" "$7" "$8}' | sed "s| \.\/| /|g" | grep "^l" > "$pkg_filelist_links"
    fs_filelist_links=$(mktemp)
fi

if [ "$compare_mode" == "d" ]; then
    pkg_filelist_dirs=$(mktemp)
    dpkg -c "$pkg_file" | awk '{print $1" "$2" "$6" "$7" "$8}' | sed "s| \.\/| /|g" | grep "^d" > "$pkg_filelist_dirs"
    fs_filelist_dirs=$(mktemp)
fi

# permissions   user/group  size    date time   'object' (->) 'link_target'

if dpkg -L "$pkg_name" | grep " " -q ; then
    # safe way to handle filenames with spaces (slower)
    dpkg -L "$pkg_name" | while IFS= read -r file; 
    do
        if [ "$compare_mode" == "f" ]; then
            stat "$file" --printf "%A %U/%G\t%s %y %N\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$7" "$8" "$9}' | grep -vE "^d|^l|^h" >> "$fs_filelist_files"; 
        fi
        if [ "$compare_mode" == "l" ]; then
            stat "$file" --printf "%A %U/%G\t%N\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$4" "$5}' | grep "^l" >> "$fs_filelist_links"
        fi
        if [ "$compare_mode" == "d" ]; then
            stat "$file" --printf "%A %U/%G\t%N/\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$4" "$5}' | grep "^d" | sed 's|\/\.||' >> "$fs_filelist_dirs"
        fi
    done
else
    # we have no spaces in filenames, will run faster
    if [ "$compare_mode" == "f" ]; then
        stat $(dpkg -L "$pkg_name" | grep -v " ") --printf "%A %U/%G\t%s %y %N\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$7" "$8" "$9}' | grep -vE "^d|^l|^h" > "$fs_filelist_files"
    fi
    if [ "$compare_mode" == "l" ]; then
        stat $(dpkg -L "$pkg_name" | grep -v " ") --printf "%A %U/%G\t%N\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$4" "$5}' | grep "^l" > "$fs_filelist_links"
    fi
    if [ "$compare_mode" == "d" ]; then
        stat $(dpkg -L "$pkg_name" | grep -v " ") --printf "%A %U/%G\t%N/\n" 2>/dev/null | sed "s/'//g" | awk '{print $1" "$2" "$3" "$4" "$5}' | grep "^d" | sed 's|\/\.||' > "$fs_filelist_dirs"
    fi
fi

if [ "$compare_mode" == "f" ]; then
    diff_files=$(mktemp)
    diff --color -y --suppress-common-lines -W $COLUMNS "$fs_filelist_files" "$pkg_filelist_files" 2> /dev/null > "$diff_files"
fi

if [ "$compare_mode" == "l" ]; then
    diff_links=$(mktemp)
    diff --color -y --suppress-common-lines -W $COLUMNS "$fs_filelist_links" "$pkg_filelist_links" 2> /dev/null > "$diff_links"
fi

if [ "$compare_mode" == "d" ]; then
    diff_dirs=$(mktemp)
    diff --color -y --suppress-common-lines -W $COLUMNS "$fs_filelist_dirs" "$pkg_filelist_dirs" 2> /dev/null > "$diff_dirs"
fi

ret_code=0

if [ ! -s "$diff_files" ] && [ ! -s "$diff_links" ] && [ ! -s "$diff_dirs" ] ; then
    if [ $be_quiet == 0 ]; then
        echo "OK"
        ret_code=0
    fi
else
    if [ $be_quiet == 1 ]; then
        echo -n "Package '$pkg_name' with deb-file '$pkg_file' and compare-mode '$compare_mode': "
    fi
    echo "NOK (see below)"
    if [ "$compare_mode" == "f" ]; then
        if [ -s "$diff_files" ]; then
            echo "Files (local vs expected):"
            cat "$diff_files"
            ret_code=2
        fi
    fi

    if [ "$compare_mode" == "l" ]; then    
        if [ -s "$diff_links" ]; then
            echo "Symlinks:"
            cat "$diff_links"
            ret_code=3
        fi
    fi

    if [ "$compare_mode" == "d" ]; then
        if [ -s "$diff_dirs" ]; then
            echo "Directories:"
            cat "$diff_dirs"
            ret_code=4
        fi
    fi
fi

exit "$ret_code"

