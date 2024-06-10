-- NIVEL 1
-- Descarga los archivos CSV, estudialos y diseña una base de datos con un esquema de estrella que 
-- contenga, al menos 4 tablas de las que puedas realizar las siguientes consultas

-- Primer paso es crear un database.

CREATE DATABASE IF NOT EXISTS operaciones;
USE operaciones;

-- Segundo paso es crear las tablas de dimensiones que formaran nuestro modelo.

-- Creamos la tabla companies.

CREATE TABLE IF NOT EXISTS companies (
		company_id VARCHAR(20) NOT NULL,
        company_name VARCHAR(50) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(50),
        country VARCHAR(30),
        website VARCHAR(100)
);


-- Cargamos los datos desde el csv
-- Me da un error de permiso de acceso de MySQL (Error: secure-file_priv).
-- Para encontrar la carpeta que tiene permisos MySql para guardar los archivos ahí.

SHOW VARIABLES LIKE 'secure_file_priv';

-- La carpeta donde Mysql tiene permisos es:
-- 'secure_file_priv', 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\'

-- Guardo los archivos *.csv en esta carpeta.

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/companies.csv'
INTO TABLE companies
FIELDS TERMINATED BY ','
ENCLOSED BY ''
IGNORE 1 ROWS;

-- Definimos la PRIMARY KEY

ALTER TABLE companies MODIFY COLUMN company_id VARCHAR(20) NOT NULL PRIMARY KEY;
DESC companies;

-- Comprobamos que los datos se han cargado con existo.

SELECT * FROM companies;


-- Creamos la tabla credit_card

CREATE TABLE IF NOT EXISTS credit_card (
		id VARCHAR(50) NOT NULL PRIMARY KEY,
        user_id INT NOT NULL,
        iban VARCHAR(50),
        pan VARCHAR(100),
        pin VARCHAR(8),
        cvv VARCHAR(8),
        track1 VARCHAR(150),
        track2 VARCHAR(150),
        expiring_date VARCHAR(12)
        );






-- Cargamos los datos del csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/credit_cards.csv'
INTO TABLE credit_card
FIELDS TERMINATED BY ','
ENCLOSED BY ''
IGNORE 1 ROWS;

SELECT * FROM credit_card;

-- Una vez acabado el ejercicio, paso a cambiar los formatos de date de string a fecha.

ALTER TABLE credit_card RENAME COLUMN expiring_date to expiring_date_str;
DESC credit_card;
ALTER TABLE credit_card ADD COLUMN expiring_date date;
UPDATE credit_card 
SET expiring_date = STR_TO_DATE(expiring_date_str, '%m/%d/%Y');
ALTER TABLE credit_card DROP COLUMN expiring_date_str;


-- Creamos la tabla users
CREATE TABLE IF NOT EXISTS users (
		id INT NOT NULL PRIMARY KEY,
        name VARCHAR(20) NOT NULL,
        surname VARCHAR(50) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(50),
        birth_date  VARCHAR(20),
        country VARCHAR(50),
        city VARCHAR(40),
        postal_code VARCHAR(12),
        address VARCHAR(120)
);

-- Cargamos los datos del csv
-- Cargamos archivo users_usa.csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/users_usa.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n';

-- Cargamos archivo users_uk.csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/users_uk.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Cargamos archivo users_ca.csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/users_ca.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Una vez acabado el ejercicio, paso a cambiar los formatos de date de string a fecha.
ALTER TABLE users RENAME COLUMN birth_date to birth_date_str;
ALTER TABLE users ADD COLUMN birth_date date;
UPDATE users
SET birth_date = 
CASE WHEN birth_date_str REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$' 
		THEN STR_TO_DATE(birth_date_str, '%b %e, %Y')
        ELSE STR_TO_DATE(birth_date_str, '%m/%d/%Y') 
	END;
ALTER TABLE users DROP COLUMN birth_date_str;




-- Creamos la tabla transactions
CREATE TABLE IF NOT EXISTS transactions (
		id VARCHAR(100) NOT NULL PRIMARY KEY,
        card_id VARCHAR(50) NOT NULL,
        bussiness_id VARCHAR(20) NOT NULL,
        dia_hora TIMESTAMP,
        amount DECIMAL(9,2),
        declined  TINYINT,
        product_ids VARCHAR(100),
        user_id INT NOT NULL,
        lat DECIMAL(20, 16),
        longitude DECIMAL(20, 16)
);




-- Cargamos archivo transactions.csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ';'
ENCLOSED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;



ALTER TABLE transactions ADD
CONSTRAINT FOREIGN KEY (card_id) REFERENCES credit_card(id);
ALTER TABLE transactions ADD
CONSTRAINT FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE transactions ADD
CONSTRAINT FOREIGN KEY (bussiness_id) REFERENCES companies(company_id);
DESC companies;

-- SET FOREIGN_KEY_CHECKS = 0; (para desactivar las foreign keys)


-- Ejercicio 1
-- Realiza una subconsulta que muestre a todos los usuarios con más de 30 transacciones utilizando 
-- al menos 2 tablas.

SELECT users.id, users.name, users.surname, count(transactions.id) as numTrans
FROM users
JOIN transactions
ON users.id = transactions.user_id
GROUP BY users.id
HAVING count(transactions.id)>30;


SELECT users.id, users.name, users.surname, countmas30.numeroTrans
FROM users 
JOIN (SELECT user_id, count(id) as numeroTrans
		FROM transactions
		GROUP BY user_id
        HAVING numeroTrans>30) as countmas30
ON users.id = countmas30.user_id;





-- Ejercicio 2
-- Muestra la media de amount por IBAN de las tarjetas de crédito a la compañía Donec Ltd, utiliza
-- al menos 2 tablas.
USE operaciones;
SELECT 	companies.company_id, 
		companies.company_name, 
		credit_card.iban,
        truncate(avg(transactions.amount),2)
FROM credit_card
JOIN transactions
ON transactions.card_id = credit_card.id
JOIN companies
ON companies.company_id = transactions.bussiness_id
WHERE company_name = 'Donec Ltd'
GROUP BY companies.company_id, companies.company_name, credit_card.iban;

-- NIVEL 2
-- Crea una nueva tabla que refleje el estado de las tarjetas de crédito basado en si las últimas 
-- tres transacciones fueron declinadas, y genera la siguiente consulta:

CREATE TABLE estado_tarjeta
SELECT card_id, CASE WHEN sum(declined)<3 THEN 'ACTIVA'
					ELSE 'NO ACTIVA'	
				END as estado_tarjeta
FROM 	(SELECT card_id, dia_hora, declined
		FROM 	(SELECT card_id, dia_hora, declined,
					ROW_NUMBER() OVER (PARTITION BY card_id ORDER BY dia_hora DESC) as row_num
					FROM transactions) as numtranstarjetas
		WHERE row_num <= 3 
		ORDER BY card_id, dia_hora DESC) ordenfecha
GROUP BY card_id;



-- Ejercicio 1
-- ¿Cuántas tarjetas están activas?

SELECT count(*) AS tarjetas_activas
FROM estado_tarjeta
WHERE estado_tarjeta = 'ACTIVA';


-- NIVEL 3
-- Crea una tabla con la que podamos unir los datos del nuevo archivo products.csv con la base de 
-- datos creada, teniendo en cuenta que desde transaction tienes product_ids. Genera la siguiente 
-- consulta:

-- Creamos la tabla que servirá para unir la tabla products con transactions. La relación entre 
-- las dos tablas es de N:M.
-- Esta nueva tabla se llamará tiquets.
-- Primero, en la tabla transaction se añadió una columna llamada tiquet con valor entero (INT) 
-- y auto-incrementable. Esta columna nos relacionará la transacción con cada uno de los productos
-- que existen en cada transacción.


-- En el archivo csv, modifico el formato del precio, y elimino el símbolo de la moneda.

CREATE TABLE IF NOT EXISTS products (
			id INT NOT NULL PRIMARY KEY,
            product_name VARCHAR(50),
            price DECIMAL(8,2),
            colour VARCHAR(15),
            weight DECIMAL(5,1),
            warehouse_id VARCHAR(10)
			);

            
-- Cargamos archivo products.csv
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

					                       
-- Creamos una tabla intermedia llamada tiquets_juntos
-- Añadimos los datos a la tabla, importando dos columnas desde la tabla transactions.
-- La tabla contiene tres columnas. La primera es el id_transactions, la segunda es la columna 
-- con los product_ids, y la tercera es el número de ids de la columna 2.

-- CREATE TABLE tiquets_juntos
SELECT 	id, 
		product_ids,
		LENGTH(product_ids) - LENGTH( REPLACE (product_ids, ",", "")) + 1 AS NumIds
from transactions;

-- Vemos como queda la tabla.
SELECT * FROM tiquets_juntos;





-- Tengo que separar los diferentes ids, una fila por id. Obtengo la tabla con la que trabajaré.

CREATE TABLE tiquets
SELECT id,
       SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ', ', n.digit), ', ', -1) AS product
FROM tiquets_juntos
JOIN (
    SELECT 1 AS digit UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4
) AS n
ON NumIds >= n.digit;

-- Acontinuación una segunda manera de obtener la tabla, pero menos dinámica.

CREATE TABLE tiquets
SELECT id, SUBSTRING_INDEX(product_ids, ', ', 1) AS product
FROM tiquets_juntos
UNION
SELECT id, SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ', ', 1), ',',-1) AS product
FROM tiquets_juntos
UNION
SELECT id, SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ', ', 2), ',',-1) AS product
FROM tiquets_juntos
UNION
SELECT id, SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ', ', 3), ',',-1) AS product
FROM tiquets_juntos
UNION
SELECT id, SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ', ', 4), ',',-1) AS product
FROM tiquets_juntos;


-- Modificamos el tipo de dato de product, de VARCHAR a INTEGER.

ALTER TABLE tiquets MODIFY COLUMN product INT NOT NULL;

-- Creamos las FOREIGN KEYS para relacionar la tabla de tiquets con la tabla de 
-- transactions y products.

ALTER TABLE tiquets ADD
CONSTRAINT FOREIGN KEY (id) REFERENCES transactions(id);
ALTER TABLE tiquets ADD
CONSTRAINT FOREIGN KEY (product) REFERENCES products(id);


-- Ejercicio 1
-- Necesitamos conocer el número de veces que se ha vendido cada producto.

SELECT tiquets.product, products.product_name, count(tiquets.product) AS num
FROM tiquets
JOIN products
ON products.id = tiquets.product
JOIN transactions
ON transactions.id = tiquets.id
WHERE transactions.declined = 0 
GROUP BY tiquets.product, products.product_name
ORDER BY num DESC;




