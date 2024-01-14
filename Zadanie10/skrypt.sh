#!/bin/bash

#14.01.2024
#Aby wywołać skrypt należy wpisać w konsoli Linux, znajdując się w katalopgu ze skryptem, linijkę: sudo bash skrypt.sh
#Parametry można zmieniać w samym już skrypcie pod zmiennymi:
#url - link do pobieranego pliku
#my_index - indeks studenta
#DB_HOST - adres bazy danych
#DB_PORT - port, na którym jest połączenie z bazą danych
#DB_USER - nazwa użytkownika bazy danych
#DB_PASS - hasło użytkownika bazy danych
#DB_NAME - nazwa bazy danych
#password - hasło do rozpakowania pliku (jeśli takie jest)

timestamp() {
  date +"%m%d%Y"
}

now() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Adres URL pliku do pobrania
url="http://home.agh.edu.pl/~wsarlej/dyd/bdp2/materialy/cw10/InternetSales_new.zip"
katalog="PROCESSED"

if [ ! -d "$katalog" ]; then
    mkdir -p "$katalog"
    if [ $? -ne 0 ]; then
        echo "Pobieranie pliku nie powiodło się."
        exit 1
    fi
fi

# Nazwa pliku ZIP i pliku CSV
zip_file="InternetSales_new.zip"
csv_file="InternetSales_new.txt"
log_file="$katalog/$0_$(timestamp).log"
my_index="400140"


DB_HOST="mysql.agh.edu.pl"
DB_PORT="3306"
DB_USER="janwinni"  # Zmień na swój aktualny login
DB_PASS="JWE4wHX98Xq0a5EJ"  # Zmień na swoje aktualne hasło
DB_NAME="janwinni"

# Zapytanie SQL do utworzenia nowej tabeli
SQL="CREATE TABLE IF NOT EXISTS CUSTOMERS_${my_index} (ProductKey INT, CurrencyAlternateKey VARCHAR(10), FIRST_NAME VARCHAR(255),LAST_NAME VARCHAR(255), OrderDateKey DATE, OrderQuantity INT, UnitPrice DECIMAL(10,2), SecretCode VARCHAR(50));"
SQL2="LOAD DATA LOCAL INFILE '"$csv_file"' INTO TABLE CUSTOMERS_${my_index} FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n' IGNORE 1 LINES (ProductKey, CurrencyAlternateKey, FIRST_NAME, LAST_NAME, OrderDateKey, OrderQuantity, UnitPrice, SecretCode);"
SQL3="UPDATE CUSTOMERS_${my_index} SET SecretCode=LEFT(MD5(RAND()), 10);"
SQL4="SELECT *  FROM CUSTOMERS_${my_index};"

# Hasło do rozpakowania pliku
password="bdp2agh"

# Funkcja do uzyskania aktualnej daty w formacie MMDDYYYY


# Sprawdzenie, czy plik ZIP już istnieje
if [ -f "$zip_file" ]; then
    echo "Plik $zip_file już istnieje. Usuwam..."

    # Usunięcie pliku ZIP
    rm "$zip_file" > /dev/null

    # Usunięcie zawartości pliku ZIP, jeśli została wcześniej wypakowana
    if [ -d "${zip_file%.zip}" ]; then
        echo "Usuwanie wypakowanej zawartości..."
        rm -r "${zip_file%.zip}" > /dev/null
    fi
fi

# Pobranie pliku
wget "$url" -O "$zip_file" > /dev/null 2>&1

# Sprawdzenie, czy pobieranie się powiodło
if [ $? -ne 0 ]; then
    echo "$(now) Pobieranie pliku nie powiodło się." | tee -a $log_file
    exit 1
fi
echo "$(now) File obtained!" | tee -a $log_file

# Rozpakowanie pliku z hasłem
unzip -o -P "$password" "$zip_file" > /dev/null 2>&1

# Sprawdzenie, czy rozpakowanie się powiodło
if [ $? -ne 0 ]; then
    echo "$(now) Rozpakowanie pliku nie powiodło się." | tee -a $log_file
    exit 1
fi

echo "$(now) File unziped!" | tee -a $log_file

# Przetwarzanie pliku CSV
bad_records_file="InternetSales_new.bad_$(timestamp)"

awk -F'|' 'NR == 1 {
    header = $0; num_cols = NF; next
}
NF != num_cols || $0 == "" || seen[$0]++ || $5 > 100 || $7 != "" || !match($3, /[A-Za-z]+,[A-Za-z]+/) {
    # Usunięcie wartości z kolumny SecretCode (kolumna 7)
    $7 = ""
    print $0 > "'$bad_records_file'"
    next
}
{
    print $0
}' "$csv_file" > tmp && mv tmp "$csv_file"

if [ $? -ne 0 ]; then
    echo "$(now) Usuwanie niepoprawnych rekordow nie powiodlo sie!" | tee -a $log_file
    exit 1
fi

awk -F'|' 'BEGIN {OFS="|"}
NR == 1 {
    print $1, $2, "FIRST_NAME", "LAST_NAME", $4, $5, $6, $7
    next
}
{
    split($3, name, ",")
    gsub(/"/, "", name[1])
    gsub(/"/, "", name[2])
    print $1, $2, name[2], name[1], $4, $5, $6, $7
}' "$csv_file" > temp_file && mv temp_file "$csv_file"

if [ $? -ne 0 ]; then
    echo "$(now) Validacja pliku nie powiodła się." | tee -a $log_file
    exit 1
fi

echo "$(now) File validated!" | tee -a $log_file

mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASS" "$DB_NAME" -e "$SQL" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "$(now) Utworzenie tabeli nie powiodło się." | tee -a $log_file
    exit 1
fi
echo "$(now) Created mysql table!" | tee -a $log_file

mysql --local-infile=1 --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASS" "$DB_NAME" -e "$SQL2" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "$(now) Wczytanie danych z pliku do tabeli nie powiodło się." | tee -a $log_file
    exit 1
fi
echo "$(now) Data loaded into SQL table" | tee -a $log_file

mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASS" "$DB_NAME" -e "$SQL3" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "$(now) Generowanie SecretCode nie powiodło się." | tee -a $log_file
    exit 1
fi

echo "$(now) Created random SecretCodes for data in table" | tee -a $log_file

# Przeniesienie pliku do katalogu
mv "$csv_file" "$katalog/$(timestamp)_$csv_file"
    if [ $? -ne 0 ]; then
        echo "$(now) Przeniesienie pliku nie powiodło się." | tee -a $log_file
        exit 1
    fi
echo "$(now) Moving preapared csv to PROCESSED catalog" | tee -a $log_file



csv_dump="CUSTOMERS_${my_index}.csv"
compressed_file="CUSTOMERS_${my_index}.csv.gz"

# Eksportowanie tabeli do pliku CSV
mysql -h 149.156.96.20 -P"$DB_PORT" --protocol=TCP --user="$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$SQL4" -B | sed 's/\t/,/g' > $csv_dump

    if [ $? -ne 0 ]; then
        echo "$(now) Dumping pliku nie powiódł się." | tee -a $log_file
        exit 1
    fi
echo "$(now) Dumping table to CSV" | tee -a $log_file

# Kompresowanie pliku CSV
gzip -f "$csv_dump"
    if [ $? -ne 0 ]; then
        echo "$(now) Kompresowanie pliku nie powiodło się." | tee -a $log_file
        exit 1
    fi
echo "$(now) Compressing csv" | tee -a $log_file

echo "$(now) Plik został pobrany, rozpakowany i przetworzony. Wadliwe rekordy znajdują się w pliku $bad_records_file" | tee -a $log_file
