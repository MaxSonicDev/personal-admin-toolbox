password=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n 1 )
    echo $password
    echo $password
