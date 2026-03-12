-- Cerinta 4

CREATE TABLE CLIENTI (
    id_client           INT,
    nume                VARCHAR2(50) NOT NULL,
    prenume             VARCHAR2(50) NOT NULL,
    email               VARCHAR2(100) NOT NULL,
    telefon             VARCHAR2(15),
    data_inregistrare   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_clienti PRIMARY KEY (id_client),
    CONSTRAINT uq_clienti_email UNIQUE (email),
    CONSTRAINT ck_clienti_email CHECK (email LIKE '%@%.%')
);


CREATE TABLE ANGAJATI (
    id_angajat          INT,
    nume                VARCHAR2(50) NOT NULL,
    prenume             VARCHAR2(50) NOT NULL,
    email               VARCHAR2(100) NOT NULL,
    telefon             VARCHAR2(15),
    data_angajare       DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_angajati PRIMARY KEY (id_angajat),
    CONSTRAINT uq_angajati_email UNIQUE (email),
    CONSTRAINT ck_angajati_email CHECK (email LIKE '%@%.%')
);

CREATE OR REPLACE TRIGGER trg_check_data_angajare -- cerinta 11, declansat de INSERT-urile din ANGAJATI
BEFORE INSERT OR UPDATE ON ANGAJATI
FOR EACH ROW
BEGIN
    IF :NEW.data_angajare > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Data angajarii nu poate fi in viitor!');
    END IF;
END;
/

CREATE TABLE CATEGORII (
    id_categorie        INT,
    nume                VARCHAR2(50) NOT NULL,
    cod                 VARCHAR2(10) NOT NULL,
    CONSTRAINT pk_categorii PRIMARY KEY (id_categorie),
    CONSTRAINT uq_categorii_nume UNIQUE (nume),
    CONSTRAINT uq_categorii_cod UNIQUE (cod)
);


CREATE TABLE PRODUSE (
    id_produs           INT,
    id_categorie        INT NOT NULL, -- un produs trebuie sa apartina obligatoriu unei categorii
    denumire            VARCHAR2(100) NOT NULL,
    pret                NUMBER(10, 2) NOT NULL,
    stoc                INT DEFAULT 0 NOT NULL,
    CONSTRAINT pk_produse PRIMARY KEY (id_produs),
    CONSTRAINT fk_produse_categorii FOREIGN KEY (id_categorie) REFERENCES CATEGORII(id_categorie),
    CONSTRAINT ck_produse_pret CHECK (pret > 0),
    CONSTRAINT ck_produse_stoc CHECK (stoc >= 0)
);


CREATE TABLE FURNIZORI (
    id_furnizor         INT,
    denumire            VARCHAR2(100) NOT NULL,
    email               VARCHAR2(100) NOT NULL,
    telefon             VARCHAR2(15),
    data_contract       DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_furnizori PRIMARY KEY (id_furnizor),
    CONSTRAINT uq_furnizori_email UNIQUE (email),
    CONSTRAINT ck_furnizori_email CHECK (email LIKE '%@%.%')
);
/


CREATE OR REPLACE TRIGGER trg_check_data_contract
BEFORE INSERT OR UPDATE ON FURNIZORI
FOR EACH ROW
BEGIN
    IF :NEW.data_contract > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002, 'Data contractului nu poate fi in viitor!');
    END IF;
END;
/


CREATE TABLE COMENZI (
    id_comanda          INT,
    id_client           INT NOT NULL, -- o comanda trebuie sa apartina obligatoriu unui client
    data_comanda        DATE DEFAULT SYSDATE NOT NULL,
    status              VARCHAR2(20) DEFAULT 'in asteptare' NOT NULL,
    metoda_plata        VARCHAR2(20),
    CONSTRAINT pk_comenzi PRIMARY KEY (id_comanda),
    CONSTRAINT fk_comenzi_clienti FOREIGN KEY (id_client) REFERENCES CLIENTI(id_client),
    CONSTRAINT ck_comenzi_status CHECK (status IN ('in asteptare', 'livrata', 'anulata')),
    CONSTRAINT ck_comenzi_plata CHECK (metoda_plata IN ('card', 'numerar'))
);
/


CREATE OR REPLACE TRIGGER trg_check_data_comanda
BEFORE INSERT OR UPDATE ON COMENZI
FOR EACH ROW
DECLARE
    v_data_inreg DATE;
BEGIN
    -- Validare fata de timpul prezent
    IF :NEW.data_comanda > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20003, 'Eroare: Data comenzii nu poate fi in viitor!');
    END IF;

    -- Validare fata de inregistrarea clientului
    SELECT data_inregistrare INTO v_data_inreg
    FROM CLIENTI
    WHERE id_client = :NEW.id_client;

    IF :NEW.data_comanda < v_data_inreg THEN
        RAISE_APPLICATION_ERROR(-20101, 'Eroare: Clientul nu poate plasa comenzi inainte de data inregistrarii sale (' || TO_CHAR(v_data_inreg, 'DD-MM-YYYY') || ')!');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_status_comanda_stoc
AFTER UPDATE OF status ON COMENZI
FOR EACH ROW
BEGIN
    -- Comanda este anulata (returnam produsele in stoc)
    IF :NEW.status = 'anulata' AND :OLD.status != 'anulata' THEN
        FOR r_item IN (SELECT id_produs, cantitate FROM DETALII_COMANDA WHERE id_comanda = :NEW.id_comanda) LOOP
            UPDATE PRODUSE
            SET stoc = stoc + r_item.cantitate
            WHERE id_produs = r_item.id_produs;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Comanda ' || :NEW.id_comanda || ' a fost anulata. Produsele au revenit in stoc.');

    -- Comanda revine din anulare (scadem din nou produsele din stoc)
    ELSIF :OLD.status = 'anulata' AND (:NEW.status = 'in asteptare' OR :NEW.status = 'livrata') THEN
        FOR r_item IN (SELECT id_produs, cantitate FROM DETALII_COMANDA WHERE id_comanda = :NEW.id_comanda) LOOP
            UPDATE PRODUSE
            SET stoc = stoc - r_item.cantitate
            WHERE id_produs = r_item.id_produs;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Comanda ' || :NEW.id_comanda || ' a fost reactivata. Stocul a fost actualizat.');
    END IF;
END;
/


CREATE TABLE FACTURI (
    id_factura          INT,
    id_comanda          INT NOT NULL, -- o factura trebuie sa fie emisa pentru o comanda
    data_emitere        DATE DEFAULT SYSDATE NOT NULL,
    status_plata        VARCHAR2(20) DEFAULT 'neplatita' NOT NULL,
    CONSTRAINT pk_facturi PRIMARY KEY (id_factura),
    CONSTRAINT fk_facturi_comenzi FOREIGN KEY (id_comanda) REFERENCES COMENZI(id_comanda),
    CONSTRAINT ck_facturi_status CHECK (status_plata IN ('platita', 'neplatita'))
);
/


CREATE OR REPLACE TRIGGER trg_check_data_factura
BEFORE INSERT OR UPDATE ON FACTURI
FOR EACH ROW
DECLARE
    v_data_comanda DATE;
BEGIN
    -- Validare fata de timpul prezent
    IF :NEW.data_emitere > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20004, 'Eroare: Data emiterii facturii nu poate fi in viitor!');
    END IF;

    -- Validare fata de data comenzii
    SELECT data_comanda INTO v_data_comanda
    FROM COMENZI
    WHERE id_comanda = :NEW.id_comanda;

    IF :NEW.data_emitere < v_data_comanda THEN
        RAISE_APPLICATION_ERROR(-20102, 'Eroare: Factura nu poate fi emisa inainte de plasarea comenzii (' || TO_CHAR(v_data_comanda, 'DD-MM-YYYY') || ')!');
    END IF;
END;
/


CREATE TABLE DETALII_COMANDA ( -- retine ce produse contine o comanda si in ce cantitate
    id_comanda          INT,
    id_produs           INT,
    cantitate           INT NOT NULL,
    pret_unitar         NUMBER(10, 2) NOT NULL, -- pretul produsului la momentul comenzii
    CONSTRAINT pk_detalii_comanda PRIMARY KEY (id_comanda, id_produs),
    CONSTRAINT fk_detalii_comanda_comenzi FOREIGN KEY (id_comanda) REFERENCES COMENZI(id_comanda),
    CONSTRAINT fk_detalii_comanda_produse FOREIGN KEY (id_produs) REFERENCES PRODUSE(id_produs),
    CONSTRAINT ck_detalii_cantitate CHECK (cantitate >= 1),
    CONSTRAINT ck_detalii_pret CHECK (pret_unitar > 0)
);
/

CREATE OR REPLACE TRIGGER trg_blocare_detalii_livrate
BEFORE INSERT OR UPDATE OR DELETE ON DETALII_COMANDA
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
    v_id_com_temp INT;
BEGIN
    -- Aflam ID-ul comenzii pe care se incearca operatia
    IF INSERTING OR UPDATING THEN
        v_id_com_temp := :NEW.id_comanda;
    ELSE
        v_id_com_temp := :OLD.id_comanda;
    END IF;

    -- Identificam statusul comenzii asociate din tabelul COMENZI
    SELECT status INTO v_status
    FROM COMENZI
    WHERE id_comanda = v_id_com_temp;

    -- Daca statusul este livrat, blocam orice modificare
    IF v_status = 'livrata' THEN
        RAISE_APPLICATION_ERROR(-20011, 'Eroare: Nu se pot adauga, modifica sau sterge produse dintr-o comanda care a fost deja livrata!');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20012, 'Eroare: Comanda asociata ID-ului ' || v_id_com_temp || ' nu a fost gasita!');
END;
/

-- Trigger pentru actualizarea stocului -- cerinta 11, declansat de INSERT-urile / UPDATE-urile / DELETE-urile din DETALII_COMANDA
CREATE OR REPLACE TRIGGER trg_gestiune_stoc_vanzari
BEFORE INSERT OR UPDATE OR DELETE ON DETALII_COMANDA
FOR EACH ROW
FOLLOWS trg_blocare_detalii_livrate
DECLARE
    v_stoc_curent INT;
    v_id_produs   INT;
BEGIN
    -- Identificam ID-ul produsului (cel nou la insert/update, cel vechi la delete)
    v_id_produs := CASE WHEN DELETING THEN :OLD.id_produs ELSE :NEW.id_produs END;

    -- Selectam stocul curent cu blocare (FOR UPDATE - blocam randul in situatia in care doi clienti comanda ultimul produs in acelasi timp)
    BEGIN
        SELECT stoc INTO v_stoc_curent
        FROM PRODUSE
        WHERE id_produs = v_id_produs
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006, 'Produsul cu ID ' || v_id_produs || ' nu a fost gasit!');
    END;

    IF INSERTING THEN
        -- Verificam daca avem destul stoc pentru noua vanzare
        IF v_stoc_curent < :NEW.cantitate THEN
            RAISE_APPLICATION_ERROR(-20005, 'Stoc insuficient! Disponibil: ' || v_stoc_curent);
        END IF;

        UPDATE PRODUSE SET stoc = stoc - :NEW.cantitate WHERE id_produs = v_id_produs;

    ELSIF UPDATING THEN
        -- Verificam daca noul stoc (stoc_curent + ce era deja rezervat - ce se cere acum) este suficient
        -- Ex. - Avem 10 in stoc, am comandat 5 (deci in total erau 15). Modificam la 12
        -- Verificam daca 15 >= 12
        IF (v_stoc_curent + :OLD.cantitate) < :NEW.cantitate THEN
             RAISE_APPLICATION_ERROR(-20005, 'Stoc insuficient pentru modificare! Maxim disponibil: ' || (v_stoc_curent + :OLD.cantitate));
        END IF;

        UPDATE PRODUSE SET stoc = stoc + (:OLD.cantitate - :NEW.cantitate) WHERE id_produs = v_id_produs;

    ELSIF DELETING THEN
        -- Punem produsele inapoi in stoc daca se sterge comanda
        UPDATE PRODUSE SET stoc = stoc + :OLD.cantitate WHERE id_produs = v_id_produs;
    END IF;
END;
/


CREATE TABLE PRODUSE_FURNIZORI ( -- ce furnizor a livrat ce produs, cand si in ce cantitate
    id_produs           INT,
    id_furnizor         INT,
    data_inceput        DATE DEFAULT SYSDATE NOT NULL, -- marcheaza data achizitiei/inceput contract
    data_sfarsit        DATE,
    stoc_achizitie      INT NOT NULL, -- cantitatea de produs aprovizionata de la furnizor
    pret_achizitie      NUMBER(10, 2) NOT NULL, -- pretul de achizitie al produsului de la furnizor
    CONSTRAINT pk_produse_furnizori PRIMARY KEY (id_produs, id_furnizor, data_inceput),
    CONSTRAINT fk_pf_produse FOREIGN KEY (id_produs) REFERENCES PRODUSE(id_produs),
    CONSTRAINT fk_pf_furnizori FOREIGN KEY (id_furnizor) REFERENCES FURNIZORI(id_furnizor),
    CONSTRAINT ck_pf_stoc CHECK (stoc_achizitie >= 1),
    CONSTRAINT ck_pf_pret CHECK (pret_achizitie >= 0),
    CONSTRAINT ck_pf_perioada CHECK (data_sfarsit IS NULL OR data_sfarsit >= data_inceput)
);
/


CREATE OR REPLACE TRIGGER trg_check_dates_pf
BEFORE INSERT OR UPDATE ON PRODUSE_FURNIZORI
FOR EACH ROW
DECLARE
    v_data_contract DATE;
BEGIN
    -- Validare fata de timpul prezent
    IF :NEW.data_inceput > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20007, 'Eroare: Data de inceput a aprovizionarii nu poate fi in viitor!');
    END IF;

    -- Validare fata de data contractului
    SELECT data_contract INTO v_data_contract
    FROM FURNIZORI
    WHERE id_furnizor = :NEW.id_furnizor;

    IF :NEW.data_inceput < v_data_contract THEN
        RAISE_APPLICATION_ERROR(-20105, 'Eroare: Nu se pot receptiona produse inainte de semnarea contractului cu furnizorul!');
    END IF;

    -- Validare consistenta perioada (daca exista data_sfarsit)
    IF :NEW.data_sfarsit IS NOT NULL THEN
        IF :NEW.data_sfarsit > SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20008, 'Eroare: Data de sfarsit nu poate fi in viitor!');
        ELSIF :NEW.data_sfarsit < :NEW.data_inceput THEN
            RAISE_APPLICATION_ERROR(-20106, 'Eroare: Data de sfarsit trebuie sa fie dupa data de inceput!');
        END IF;
    END IF;
END;
/

-- Trigger pentru actualizarea stocului (aprovizionare) - cerinta 11, declansat de INSERT-urile / UPDATE-urile / DELETE-urile din PRODUSE_FURNIZORI
CREATE OR REPLACE TRIGGER trg_gestiune_stoc_furnizor
AFTER INSERT OR UPDATE OR DELETE ON PRODUSE_FURNIZORI
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- Adaugam intreaga cantitate noua
        UPDATE PRODUSE
        SET stoc = stoc + :NEW.stoc_achizitie
        WHERE id_produs = :NEW.id_produs;

    ELSIF UPDATING THEN
        -- Adaugam diferenta (Nou - Vechi)
        -- Daca Nou > Vechi, stocul creste. Daca Nou < Vechi, stocul scade automat.
        UPDATE PRODUSE
        SET stoc = stoc + (:NEW.stoc_achizitie - :OLD.stoc_achizitie)
        WHERE id_produs = :NEW.id_produs;

    ELSIF DELETING THEN
        -- Daca stergem o achizitie, scadem cantitatea din stoc
        UPDATE PRODUSE
        SET stoc = stoc - :OLD.stoc_achizitie
        WHERE id_produs = :OLD.id_produs;
    END IF;
END;
/



CREATE TABLE PROCESARE_COMENZI ( -- pastreaza istoricul procesarii
    id_angajat          INT,
    id_comanda          INT,
    data_proc           DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_procesare_comenzi PRIMARY KEY (id_angajat, id_comanda),
    CONSTRAINT fk_proc_angajati FOREIGN KEY (id_angajat) REFERENCES ANGAJATI(id_angajat),
    CONSTRAINT fk_proc_comenzi FOREIGN KEY (id_comanda) REFERENCES COMENZI(id_comanda)
);
/

CREATE OR REPLACE TRIGGER trg_check_data_proc
BEFORE INSERT OR UPDATE ON PROCESARE_COMENZI
FOR EACH ROW
DECLARE
    v_data_angajare DATE;
    v_data_comanda   DATE;
BEGIN
    -- Validare fata de timpul prezent
    IF :NEW.data_proc > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20009, 'Eroare: Data procesarii nu poate fi in viitor!');
    END IF;

    -- Validare fata de data angajarii
    SELECT data_angajare INTO v_data_angajare
    FROM ANGAJATI
    WHERE id_angajat = :NEW.id_angajat;

    IF :NEW.data_proc < v_data_angajare THEN
        RAISE_APPLICATION_ERROR(-20103, 'Eroare: Angajatul nu putea procesa comenzi inainte de a fi angajat!');
    END IF;

    -- Validare fata de data comenzii
    SELECT data_comanda INTO v_data_comanda
    FROM COMENZI
    WHERE id_comanda = :NEW.id_comanda;

    IF :NEW.data_proc < v_data_comanda THEN
        RAISE_APPLICATION_ERROR(-20104, 'Eroare: Procesarea nu poate avea loc inainte de plasarea comenzii!');
    END IF;
END;
/

-- Cerinta 5

-- SECVENTE
-- Stergem secventele vechi daca exista
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_categorii';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_produse';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_furnizori';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_clienti';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_angajati';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_comenzi';
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_facturi';
EXCEPTION
  WHEN OTHERS THEN NULL; -- Ignora eroarea daca secventele nu exista
END;
/

-- Creare Secvente
CREATE SEQUENCE seq_categorii START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_produse   START WITH 101 INCREMENT BY 1;
CREATE SEQUENCE seq_furnizori START WITH 10 INCREMENT BY 10; -- Furnizorii vor fi 10, 20, 30...
CREATE SEQUENCE seq_clienti   START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE seq_angajati  START WITH 501 INCREMENT BY 1;
CREATE SEQUENCE seq_comenzi   START WITH 2001 INCREMENT BY 1;
CREATE SEQUENCE seq_facturi   START WITH 3001 INCREMENT BY 1;


-- Tabele independente


-- CATEGORII (ID-urile generate vor fi 1, 2, 3, 4, 5)
INSERT INTO CATEGORII (id_categorie, nume, cod) VALUES (seq_categorii.NEXTVAL, 'Telefoane Mobile', 'TEL');
INSERT INTO CATEGORII (id_categorie, nume, cod) VALUES (seq_categorii.NEXTVAL, 'Laptopuri & IT', 'LAP');
INSERT INTO CATEGORII (id_categorie, nume, cod) VALUES (seq_categorii.NEXTVAL, 'Televizoare & Audio', 'TV');
INSERT INTO CATEGORII (id_categorie, nume, cod) VALUES (seq_categorii.NEXTVAL, 'Electrocasnice Mici', 'ELECTRO');
INSERT INTO CATEGORII (id_categorie, nume, cod) VALUES (seq_categorii.NEXTVAL, 'Gaming', 'GAME');

-- PRODUSE (ID-urile generate vor fi 101, 102 ... 110)
-- la id_categorie folosim valorile 1-5 generate mai sus.
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 1, 'Samsung Galaxy S23', 3999.99, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 1, 'iPhone 15 Pro', 5400.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 2, 'Laptop ASUS TUF Gaming', 4500.50, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 2, 'MacBook Air M2', 5999.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 3, 'Televizor LG OLED', 6200.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 4, 'Espresor Philips LatteGo', 2100.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 4, 'Aspirator Robot Roborock', 1850.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 5, 'Consola PlayStation 5', 2699.99, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 2, 'Mouse Logitech MX Master', 450.00, 0);
INSERT INTO PRODUSE (id_produs, id_categorie, denumire, pret, stoc) VALUES (seq_produse.NEXTVAL, 3, 'Soundbar Samsung', 899.00, 0);

-- FURNIZORI (ID-urile generate vor fi 10, 20, 30, 40, 50)
INSERT INTO FURNIZORI (id_furnizor, denumire, email, telefon, data_contract) VALUES (seq_furnizori.NEXTVAL, 'Tech Distribution SRL', 'contact@techdist.ro', '0722111222', TO_DATE('10-01-2023', 'DD-MM-YYYY'));
INSERT INTO FURNIZORI (id_furnizor, denumire, email, telefon, data_contract) VALUES (seq_furnizori.NEXTVAL, 'Global Electro Import', 'sales@globalelectro.com', '0733444555', TO_DATE('15-03-2023', 'DD-MM-YYYY'));
INSERT INTO FURNIZORI (id_furnizor, denumire, email, telefon, data_contract) VALUES (seq_furnizori.NEXTVAL, 'IT Solutions West', 'office@itsolutions.ro', '0744777888', TO_DATE('20-05-2023', 'DD-MM-YYYY'));
INSERT INTO FURNIZORI (id_furnizor, denumire, email, telefon, data_contract) VALUES (seq_furnizori.NEXTVAL, 'Home & Deco Logistics', 'livrari@homedeco.ro', '0755999000', TO_DATE('01-08-2023', 'DD-MM-YYYY'));
INSERT INTO FURNIZORI (id_furnizor, denumire, email, telefon, data_contract) VALUES (seq_furnizori.NEXTVAL, 'Smart Gadgets Hub', 'partners@smartgadgets.ro', '0766123123', TO_DATE('10-11-2023', 'DD-MM-YYYY'));

-- CLIENTI (ID-urile generate vor fi 1001 ... 1005)
INSERT INTO CLIENTI (id_client, nume, prenume, email, telefon, data_inregistrare) VALUES (seq_clienti.NEXTVAL, 'Popescu', 'Andrei', 'andrei.popescu90@gmail.com', '0720123456', TO_DATE('01-02-2024', 'DD-MM-YYYY'));
INSERT INTO CLIENTI (id_client, nume, prenume, email, telefon, data_inregistrare) VALUES (seq_clienti.NEXTVAL, 'Ionescu', 'Maria', 'maria.ionescu@yahoo.com', '0730987654', TO_DATE('15-02-2024', 'DD-MM-YYYY'));
INSERT INTO CLIENTI (id_client, nume, prenume, email, telefon, data_inregistrare) VALUES (seq_clienti.NEXTVAL, 'Radu', 'Mihai', 'mihai.radu.dev@outlook.com', '0740555666', TO_DATE('20-03-2024', 'DD-MM-YYYY'));
INSERT INTO CLIENTI (id_client, nume, prenume, email, telefon, data_inregistrare) VALUES (seq_clienti.NEXTVAL, 'Dumitrescu', 'Elena', 'elena.d@gmail.com', '0750111222', TO_DATE('05-04-2024', 'DD-MM-YYYY'));
INSERT INTO CLIENTI (id_client, nume, prenume, email, telefon, data_inregistrare) VALUES (seq_clienti.NEXTVAL, 'Stan', 'George', 'george.stan88@gmail.com', '0760333444', TO_DATE('10-05-2024', 'DD-MM-YYYY'));

-- ANGAJATI (ID-urile generate vor fi 501 ... 505)
INSERT INTO ANGAJATI (id_angajat, nume, prenume, email, telefon, data_angajare) VALUES (seq_angajati.NEXTVAL, 'Marinescu', 'Vlad', 'vlad.marinescu@firma.ro', '0799000111', TO_DATE('10-01-2022', 'DD-MM-YYYY'));
INSERT INTO ANGAJATI (id_angajat, nume, prenume, email, telefon, data_angajare) VALUES (seq_angajati.NEXTVAL, 'Gheorghe', 'Ana', 'ana.gheorghe@firma.ro', '0799000222', TO_DATE('15-06-2022', 'DD-MM-YYYY'));
INSERT INTO ANGAJATI (id_angajat, nume, prenume, email, telefon, data_angajare) VALUES (seq_angajati.NEXTVAL, 'Dobre', 'Claudiu', 'claudiu.dobre@firma.ro', '0799000333', TO_DATE('01-09-2023', 'DD-MM-YYYY'));
INSERT INTO ANGAJATI (id_angajat, nume, prenume, email, telefon, data_angajare) VALUES (seq_angajati.NEXTVAL, 'Nistor', 'Ioana', 'ioana.nistor@firma.ro', '0799000444', TO_DATE('20-01-2024', 'DD-MM-YYYY'));
INSERT INTO ANGAJATI (id_angajat, nume, prenume, email, telefon, data_angajare) VALUES (seq_angajati.NEXTVAL, 'Voicu', 'Alexandru', 'alex.voicu@firma.ro', '0799000555', TO_DATE('10-03-2024', 'DD-MM-YYYY'));



-- Tabele asociative / dependente


-- PRODUSE_FURNIZORI
-- Declanseaza triggerul 'trg_gestiune_stoc_furnizor'. Folosim ID-urile pe care stim ca secventele le-au generat mai sus.

INSERT INTO PRODUSE_FURNIZORI VALUES (101, 10, TO_DATE('01-02-2024', 'DD-MM-YYYY'), NULL, 50, 3200.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (102, 10, TO_DATE('01-02-2024', 'DD-MM-YYYY'), NULL, 30, 4500.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (103, 30, TO_DATE('05-02-2024', 'DD-MM-YYYY'), NULL, 20, 3800.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (104, 20, TO_DATE('10-02-2024', 'DD-MM-YYYY'), NULL, 15, 5100.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (105, 20, TO_DATE('12-02-2024', 'DD-MM-YYYY'), NULL, 10, 5000.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (106, 40, TO_DATE('15-02-2024', 'DD-MM-YYYY'), NULL, 40, 1600.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (107, 40, TO_DATE('15-02-2024', 'DD-MM-YYYY'), NULL, 25, 1400.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (108, 50, TO_DATE('20-02-2024', 'DD-MM-YYYY'), NULL, 50, 2200.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (109, 30, TO_DATE('25-02-2024', 'DD-MM-YYYY'), NULL, 100, 300.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (110, 20, TO_DATE('28-02-2024', 'DD-MM-YYYY'), NULL, 30, 600.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (101, 20, TO_DATE('01-03-2024', 'DD-MM-YYYY'), NULL, 20, 3150.00);
INSERT INTO PRODUSE_FURNIZORI VALUES (103, 10, TO_DATE('05-03-2024', 'DD-MM-YYYY'), NULL, 10, 3850.00);


-- COMENZI (ID-urile generate vor fi 2001 ... 2010)
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1001, TO_DATE('10-03-2024', 'DD-MM-YYYY'), 'anulata', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1002, TO_DATE('12-03-2024', 'DD-MM-YYYY'), 'anulata', 'numerar');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1003, TO_DATE('20-03-2024', 'DD-MM-YYYY'), 'in asteptare', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1001, TO_DATE('20-03-2024', 'DD-MM-YYYY'), 'in asteptare', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1004, TO_DATE('05-04-2024', 'DD-MM-YYYY'), 'anulata', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1005, TO_DATE('10-05-2024', 'DD-MM-YYYY'), 'in asteptare', 'numerar');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1002, TO_DATE('05-04-2024', 'DD-MM-YYYY'), 'in asteptare', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1003, TO_DATE('10-04-2024', 'DD-MM-YYYY'), 'in asteptare', 'card');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1005, TO_DATE('10-05-2024', 'DD-MM-YYYY'), 'in asteptare', 'numerar');
INSERT INTO COMENZI (id_comanda, id_client, data_comanda, status, metoda_plata) VALUES (seq_comenzi.NEXTVAL, 1001, TO_DATE('15-04-2024', 'DD-MM-YYYY'), 'in asteptare', 'card');


-- DETALII_COMANDA
-- Declanseaza triggerul 'trg_gestiune_stoc_vanzari'. Folosim ID-urile generate de secvente mai sus.

-- Comanda 2001
INSERT INTO DETALII_COMANDA VALUES (2001, 101, 1, 3999.99);
INSERT INTO DETALII_COMANDA VALUES (2001, 109, 1, 450.00);

-- Comanda 2002
INSERT INTO DETALII_COMANDA VALUES (2002, 106, 1, 2100.00);

-- Comanda 2003
INSERT INTO DETALII_COMANDA VALUES (2003, 108, 1, 2699.99);
INSERT INTO DETALII_COMANDA VALUES (2003, 105, 1, 6200.00);

-- Comanda 2004
INSERT INTO DETALII_COMANDA VALUES (2004, 104, 1, 5999.00);

-- Comanda 2005
INSERT INTO DETALII_COMANDA VALUES (2005, 107, 1, 1850.00);

-- Comanda 2006
INSERT INTO DETALII_COMANDA VALUES (2006, 102, 1, 5400.00);

-- Comanda 2007
INSERT INTO DETALII_COMANDA VALUES (2007, 110, 2, 899.00);

-- Comanda 2008
INSERT INTO DETALII_COMANDA VALUES (2008, 103, 1, 4500.50);

-- Comanda 2009
INSERT INTO DETALII_COMANDA VALUES (2009, 109, 2, 450.00);

-- Comanda 2010
INSERT INTO DETALII_COMANDA VALUES (2010, 101, 1, 3999.99);


-- FACTURI
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2001, TO_DATE('10-03-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2002, TO_DATE('12-03-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2003, TO_DATE('20-03-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2004, TO_DATE('20-03-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2005, TO_DATE('05-04-2024', 'DD-MM-YYYY'), 'neplatita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2006, TO_DATE('10-05-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2007, TO_DATE('05-06-2024', 'DD-MM-YYYY'), 'neplatita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2008, TO_DATE('10-06-2024', 'DD-MM-YYYY'), 'platita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2009, TO_DATE('12-06-2024', 'DD-MM-YYYY'), 'neplatita');
INSERT INTO FACTURI (id_factura, id_comanda, data_emitere, status_plata) VALUES (seq_facturi.NEXTVAL, 2010, TO_DATE('15-06-2024', 'DD-MM-YYYY'), 'platita');


-- PROCESARE_COMENZI
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (501, 2001, TO_DATE('10-03-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (502, 2002, TO_DATE('12-03-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (501, 2003, TO_DATE('15-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (503, 2004, TO_DATE('20-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (502, 2005, TO_DATE('25-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (504, 2006, TO_DATE('01-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (503, 2007, TO_DATE('05-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (501, 2008, TO_DATE('10-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (505, 2009, TO_DATE('12-06-2024', 'DD-MM-YYYY'));
INSERT INTO PROCESARE_COMENZI (id_angajat, id_comanda, data_proc) VALUES (504, 2010, TO_DATE('15-06-2024', 'DD-MM-YYYY'));

COMMIT;


-- Cerinta 6


-- Determinati cat au cheltuit in total clientii care au cumparat produse din 3 categorii specifice, numite „categorii premium”.
-- a) Definiti o lista fixa cu 3 categorii „premium” pentru care se va face analiza.
-- b) Identificati toti clientii care au cumparat produse ce fac parte din aceste categorii tinta.
-- c) Pentru fiecare client identificat in lista de mai sus, calculati valoarea totala a tuturor comenzilor sale.



CREATE OR REPLACE PROCEDURE raport_vanzari_categorii IS
    -- a) Definim lista „categoriilor premium” (dimensiune fixa => Varray)
    TYPE t_vector_categorii IS VARRAY(3) OF VARCHAR2(50);
    v_categorii_tinta t_vector_categorii := t_vector_categorii('Laptopuri & IT', 'Telefoane Mobile', 'Gaming');

    -- b) Lista ID-urilor clientilor gasiti (nu stim cati vor fi gasiti => Nested Table)
    TYPE t_lista_clienti IS TABLE OF NUMBER;
    v_clienti_gasiti t_lista_clienti := t_lista_clienti();

    -- Asocierea ID_Client -> Suma Totala (Index-By Table)
    TYPE t_statistica_vanzari IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    v_totaluri_clienti t_statistica_vanzari;

    -- Variabile auxiliare
    v_total_temp NUMBER;
    v_idx        BINARY_INTEGER; -- Indexul pentru parcurgere
    v_cat_curent VARCHAR2(50);
BEGIN

    -- Populam Nested Table
    FOR i IN 1..v_categorii_tinta.COUNT LOOP
        v_cat_curent := v_categorii_tinta(i);

        FOR r_client IN ( -- selecteaza toti clientii care au cumparat produse din v_cat_curent
            SELECT DISTINCT c.id_client
            FROM CLIENTI c, COMENZI com, DETALII_COMANDA dc, PRODUSE p, CATEGORII cat
            WHERE c.id_client = com.id_client
              AND com.id_comanda = dc.id_comanda
              AND dc.id_produs = p.id_produs
              AND p.id_categorie = cat.id_categorie
              AND cat.nume = v_cat_curent
        ) LOOP
            v_clienti_gasiti.EXTEND;
            v_clienti_gasiti(v_clienti_gasiti.LAST) := r_client.id_client;
        END LOOP;
    END LOOP;

    -- Verificam daca am gasit clienti
    IF v_clienti_gasiti.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Nu au fost gssiti clienti.');
        RETURN;
    END IF;

    -- Populam Index-By Table
    FOR i IN v_clienti_gasiti.FIRST .. v_clienti_gasiti.LAST LOOP

        SELECT NVL(SUM(dc.cantitate * dc.pret_unitar), 0)
        INTO v_total_temp
        FROM COMENZI com, DETALII_COMANDA dc
        WHERE com.id_comanda = dc.id_comanda
          AND com.id_client = v_clienti_gasiti(i);

        v_totaluri_clienti(v_clienti_gasiti(i)) := v_total_temp;
    END LOOP;

    -- Afisare
    DBMS_OUTPUT.PUT_LINE('--- Clientii Premium ---');
    v_idx := v_totaluri_clienti.FIRST;
    WHILE v_idx IS NOT NULL LOOP
        DBMS_OUTPUT.PUT_LINE('Client ID: ' || v_idx ||
                             ' | Valoare Totala Achizitii: ' || v_totaluri_clienti(v_idx) || ' RON');
        v_idx := v_totaluri_clienti.NEXT(v_idx);
    END LOOP;
-- Ordinea clientilor este garantata crescator dupa ID deoarece Index-By Table cu cheie numerica stocheaza elementele sortate automat dupa index
END;
/

BEGIN
    raport_vanzari_categorii;
END;
/

-- Cerinta 7
-- Pentru fiecare categorie de produse, sa se afiseze lista produselor apartinand acelei categorii.
-- a) Se parcurge lista tuturor categoriilor existente.
-- b) Pentru fiecare categorie gasita, se afiseaza numele acesteia.
-- c) Imediat sub nume, se afiseaza lista produselor apartinand acelei categorii.

CREATE OR REPLACE PROCEDURE raport_detaliat_categorii IS

    -- Cursor Explicit Parametrizat
    -- Asteapta un parametru (p_id_cat) pentru a functiona
    CURSOR c_produse (p_id_cat NUMBER) IS
        SELECT denumire, pret, stoc
        FROM PRODUSE
        WHERE id_categorie = p_id_cat
        ORDER BY pret DESC;

    -- Variabile locale pentru a stoca datele din cursorul parametrizat
    v_denumire PRODUSE.denumire%TYPE;
    v_pret     PRODUSE.pret%TYPE;
    v_stoc     PRODUSE.stoc%TYPE;

BEGIN
    -- Ciclu Cursor
    -- Cursorul "Parinte"
    FOR r_cat IN (
        SELECT id_categorie, nume
        FROM CATEGORII
        ORDER BY id_categorie
        ) LOOP

        DBMS_OUTPUT.PUT_LINE('CATEGORIA: ' || r_cat.nume);

        -- Deschidem cursorul parametrizat (Copil), trimitand ID-ul din cursorul Parinte
        OPEN c_produse(r_cat.id_categorie);

        LOOP
            -- Incarcam datele
            FETCH c_produse INTO v_denumire, v_pret, v_stoc;

            -- Verificam iesirea din bucla
            EXIT WHEN c_produse%NOTFOUND;

            -- Afisam datele produsului
            DBMS_OUTPUT.PUT_LINE('   * Produs: ' || v_denumire ||
                                 ' | Pret: ' || v_pret || ' RON' ||
                                 ' | Stoc: ' || v_stoc || ' buc.');
        END LOOP;

        -- Verificam daca categoria a avut produse (folosind %ROWCOUNT)
        IF c_produse%ROWCOUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   -> (Nu exista produse asociate acestei categorii)');
        END IF;


        CLOSE c_produse;

    END LOOP;
END;
/


BEGIN
    raport_detaliat_categorii;
END;
/



--- Cerinta 8
--- Identificati numarul facturii emise pentru un anumit client intr-o anumita luna.
--- a) Definiti o functie care va primi ca parametri numele de familie al clientului si luna/anul de interes.
--- b) Functia va returna un mesaj text care sa indice fie ID-ul facturii gasite, fie un mesaj de eroare specific in care:
---    i) Nu exista nicio factura pentru acel client in luna respectiva (NO_DATA_FOUND)
---    ii) Exista mai multe facturi pentru acel client in luna respectiva (clientul a facut mai multe comenzi in acea luna) -> (TOO_MANY_ROWS).

CREATE OR REPLACE FUNCTION gaseste_factura_client (
    p_nume_client VARCHAR2,
    p_luna_an     VARCHAR2 -- format asteptat 'MM-YYYY'
)
RETURN VARCHAR2
IS
    v_id_factura FACTURI.id_factura%TYPE;
    v_rezultat   VARCHAR2(200);
BEGIN
    -- Selectam ID-ul facturii. Aceasta comanda uneste 3 tabele
    -- Daca selectul returneaza exact 1 rand, merge mai departe
    -- Daca returneaza 0 sau >1, sare direct in zona de EXCEPTION
    SELECT f.id_factura
    INTO v_id_factura
    FROM FACTURI f
    JOIN COMENZI c ON f.id_comanda = c.id_comanda
    JOIN CLIENTI cl ON c.id_client = cl.id_client
    WHERE UPPER(cl.nume) = UPPER(p_nume_client)
      AND TO_CHAR(c.data_comanda, 'MM-YYYY') = p_luna_an;

    -- S-a gasit exact o factura
    v_rezultat := 'Factura identificata are ID-ul ' || v_id_factura;
    RETURN v_rezultat;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Eroare: Nu exista facturi pentru clientul ' || p_nume_client || ' in luna ' || p_luna_an;

    WHEN TOO_MANY_ROWS THEN
        RETURN 'Eroare: Clientul ' || p_nume_client || ' are mai multe facturi in luna ' || p_luna_an;

    WHEN OTHERS THEN
        RETURN 'Alta eroare: ' || SQLERRM;
END;
/



DECLARE
    v_mesaj VARCHAR2(200);
BEGIN
    -- TOO_MANY_ROWS
    -- Popescu are 2 comenzi in luna 03-2024 (ID 2001 si 2004)
    v_mesaj := gaseste_factura_client('Popescu', '03-2024');
    DBMS_OUTPUT.PUT_LINE('   >> ' || v_mesaj);
    DBMS_OUTPUT.NEW_LINE;

    -- Succes
    -- Radu are o singura comanda in luna 04-2024 (ID 2008)
    v_mesaj := gaseste_factura_client('Radu', '04-2024');
    DBMS_OUTPUT.PUT_LINE('   >> ' || v_mesaj);
    DBMS_OUTPUT.NEW_LINE;

    -- NO_DATA_FOUND
    -- Popescu nu are comenzi in luna 12-2024
    v_mesaj := gaseste_factura_client('Popescu', '12-2024');
    DBMS_OUTPUT.PUT_LINE('   >> ' || v_mesaj);

END;
/

-- Cerinta 9
-- Verificati daca un client (specificat prin nume) este eligibil pentru un „Bonus de fidelitate” acordat pentru achizitiile dintr-o anumita categorie de produse (specificata prin nume). Un
-- client este eligibil pentru acordarea bonusului daca valoarea totala a produselor cumparate de acel client din categoria respectiva depaseste 2000 RON.
-- a) Calculati valoarea totala a produselor cumparate de acel client din categoria respectiva.
-- b) Tratati urmatoarele exceptii:
--    i) ex_fara_achizitii - In cazul in care clientul nu a cumparat niciun produs din categoria specificata (suma este 0 sau NULL)
--    ii) ex_bonus_neeligibil - Daca clientul a cumparat produse, dar valoarea totala este sub pragul minim de 2000 RON necesar pentru acordarea bonusului.

CREATE OR REPLACE PROCEDURE verificare_eligibilitate_bonus (
    p_nume_client    IN VARCHAR2,
    p_nume_categorie IN VARCHAR2
) IS
    -- Variabila pentru stocarea sumei
    v_total_achizitii NUMBER := 0;

    -- Constanta pentru pragul de bonus
    c_prag_bonus      CONSTANT NUMBER := 2000;

    -- Definirea exceptiilor proprii
    ex_fara_achizitii   EXCEPTION;
    ex_bonus_neeligibil EXCEPTION;

BEGIN
    -- Comanda  pe 5 tabele
    -- Folosim NVL pentru a transforma NULL in 0 daca nu exista potriviri
    SELECT NVL(SUM(dc.cantitate * dc.pret_unitar), 0)
    INTO v_total_achizitii
    FROM CLIENTI c
    JOIN COMENZI com ON c.id_client = com.id_client
    JOIN DETALII_COMANDA dc ON com.id_comanda = dc.id_comanda
    JOIN PRODUSE p ON dc.id_produs = p.id_produs
    JOIN CATEGORII cat ON p.id_categorie = cat.id_categorie
    WHERE UPPER(c.nume) = UPPER(p_nume_client)
      AND UPPER(cat.nume) = UPPER(p_nume_categorie);



    -- Nu a cumparat nimic din acea categorie
    IF v_total_achizitii = 0 THEN
        RAISE ex_fara_achizitii;
    END IF;

    -- A cumparat, dar suma e prea mica
    IF v_total_achizitii < c_prag_bonus THEN
        RAISE ex_bonus_neeligibil;
    END IF;

    -- Succes
    DBMS_OUTPUT.PUT_LINE('Clientul ' || p_nume_client ||
                         ' este eligibil pentru bonus! Total achizitii in categoria ' ||
                         p_nume_categorie || ': ' || v_total_achizitii || ' RON.');

EXCEPTION
    WHEN ex_fara_achizitii THEN
        DBMS_OUTPUT.PUT_LINE('Clientul ' || p_nume_client ||
                             ' nu a efectuat nicio achizitie in categoria ' || p_nume_categorie || '.');

    WHEN ex_bonus_neeligibil THEN
        DBMS_OUTPUT.PUT_LINE('Clientul ' || p_nume_client ||
                             ' are achizitii de doar ' || v_total_achizitii ||
                             ' RON in categoria ' || p_nume_categorie ||
                             '. Pragul necesar este ' || c_prag_bonus || ' RON.');

    -- Tratarea erorilor neprevazute
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('EROARE: A aparut o problema tehnica: ' || SQLERRM);
END;
/



BEGIN
    -- Succes
    verificare_eligibilitate_bonus('Popescu', 'Telefoane Mobile');
    DBMS_OUTPUT.NEW_LINE;

    -- Fara achizitii
    verificare_eligibilitate_bonus('Popescu', 'Electrocasnice Mici');
    DBMS_OUTPUT.NEW_LINE;

    -- Suma mica
    verificare_eligibilitate_bonus('Ionescu', 'Televizoare & Audio');
END;
/



-- Cerinta 10
-- Definim un trigger LMD la nivel de comanda care sa monitorizeze activitatea asupra tabelului PRODUSE, astfel incat dupa executarea oricarei comenzi de
-- INSERT, UPDATE sau DELETE asupra acestui tabel sa se afiseze un mesaj informativ care sa precizeze tipul operatiei efectuate
-- si data/ora la care a avut loc.

CREATE OR REPLACE TRIGGER trg_audit_operatii_produse
    AFTER INSERT OR UPDATE OR DELETE ON PRODUSE
DECLARE
    v_tip_operatie VARCHAR2(20);
BEGIN
    IF INSERTING THEN
        v_tip_operatie := 'INSERARE';
    ELSIF UPDATING THEN
        v_tip_operatie := 'ACTUALIZARE';
    ELSIF DELETING THEN
        v_tip_operatie := 'STERGERE';
    END IF;

    DBMS_OUTPUT.PUT_LINE('S-a executat o operatie de ' || v_tip_operatie ||
                         ' asupra tabelului PRODUSE la data de ' ||
                         TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
END;
/

BEGIN
    -- Declansam trigger-ul printr-un UPDATE
    -- Vom scumpi produsele din categoria 1 cu 1 RON
    UPDATE PRODUSE
    SET pret = pret + 1
    WHERE id_categorie = 1;

    ROLLBACK;
END;
/

-- Cerinta 12
-- Definim un trigger care sa protejeze baza de date, blocand operatia de stergere a unui tabel.

CREATE OR REPLACE TRIGGER trg_blocare_drop_tabel
    BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' THEN
        RAISE_APPLICATION_ERROR(-20900, 'Nu aveti permisiunea sa stergeti tabelul ' ||
                                        ORA_DICT_OBJ_NAME || '. Dezactivati trigger-ul trg_blocare_drop_tabel.');
    END IF;
END;
/


BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE tabel_test_ldd (id NUMBER)';
    DBMS_OUTPUT.NEW_LINE;
    EXECUTE IMMEDIATE 'DROP TABLE tabel_test_ldd';
END;
/

DROP TRIGGER trg_blocare_drop_tabel;
DROP TABLE tabel_test_ldd;

SELECT trigger_name,
       table_name,
       triggering_event,
       status
FROM user_triggers
WHERE status = 'ENABLED'
ORDER BY trigger_name;


-- Cerinta 13
-- Definiti un pachet care sa gestioneze un cos de cumparaturi. Pachetul trebuie sa permita adaugarea produselor in cos pe baza ID-ului acestora,
-- preluarea automata a numelui si a pretului produsului din PRODUSE, precum si afisarea bonului fiscal cu lista produselor adaugate si
-- valoarea de plata. Cosul de cumparaturi se va goli dupa afisare.

CREATE OR REPLACE PACKAGE pachet_cos_cumparaturi AS

    -- Tip Record (Structura unui produs in cos)
    TYPE r_produs IS RECORD (
        nume_p VARCHAR2(100),
        pret_p NUMBER
    );

    -- Tip Nested Table (Lista de produse)
    TYPE t_lista_produse IS TABLE OF r_produs;

    -- Cosul de cumparaturi
    g_cos t_lista_produse := t_lista_produse();

    -- Functii
    FUNCTION get_pret_produs(p_id NUMBER) RETURN NUMBER;
    FUNCTION get_nume_produs(p_id NUMBER) RETURN VARCHAR2;

    -- Proceduri
    PROCEDURE adauga_produs(p_id NUMBER);
    PROCEDURE afiseaza_bon_fiscal;

END pachet_cos_cumparaturi;
/

CREATE OR REPLACE PACKAGE BODY pachet_cos_cumparaturi AS

    -- Functia 1 - Cauta pretul in baza de date
    FUNCTION get_pret_produs(p_id NUMBER) RETURN NUMBER IS
        v_pret NUMBER;
    BEGIN
        SELECT pret INTO v_pret FROM PRODUSE WHERE id_produs = p_id;
        RETURN v_pret;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END get_pret_produs;

    -- Functia 2 - Cauta numele in baza de date
    FUNCTION get_nume_produs(p_id NUMBER) RETURN VARCHAR2 IS
        v_nume VARCHAR2(100);
    BEGIN
        SELECT denumire INTO v_nume FROM PRODUSE WHERE id_produs = p_id;
        RETURN v_nume;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 'Produs Inexistent';
    END get_nume_produs;

    -- Procedura 1 - Adauga in lista
    PROCEDURE adauga_produs(p_id NUMBER) IS
        v_produs_nou r_produs; -- Variabila de tipul Record
    BEGIN
        -- Construim produsul
        v_produs_nou.nume_p := get_nume_produs(p_id);
        v_produs_nou.pret_p := get_pret_produs(p_id);

        -- Il adaugam in cos
        g_cos.EXTEND;
        g_cos(g_cos.LAST) := v_produs_nou;

        DBMS_OUTPUT.PUT_LINE('Adaugat in cos: ' || v_produs_nou.nume_p);
    END adauga_produs;

    -- Procedura 2 - Afiseaza tot ce am strans in lista
    PROCEDURE afiseaza_bon_fiscal IS
        v_total NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.NEW_LINE;
        DBMS_OUTPUT.PUT_LINE('BONUL FISCAL');

        IF g_cos.COUNT > 0 THEN
            FOR i IN g_cos.FIRST .. g_cos.LAST LOOP
                DBMS_OUTPUT.PUT_LINE(i || '. ' || g_cos(i).nume_p || ' ..... ' || g_cos(i).pret_p || ' RON');
                v_total := v_total + g_cos(i).pret_p;
            END LOOP;

            DBMS_OUTPUT.PUT_LINE('TOTAL DE PLATA: ' || v_total || ' RON');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Cosul este gol.');
        END IF;


        g_cos.DELETE;
    END afiseaza_bon_fiscal;

END pachet_cos_cumparaturi;
/



BEGIN
    pachet_cos_cumparaturi.adauga_produs(101); -- Samsung S23
    pachet_cos_cumparaturi.adauga_produs(109); -- Mouse
    pachet_cos_cumparaturi.adauga_produs(105); -- Televizor LG

    pachet_cos_cumparaturi.afiseaza_bon_fiscal;
END;
/

