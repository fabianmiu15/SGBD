# Online Store Database – Advanced Version (Oracle SQL / PL-SQL)

This project represents an **advanced implementation of a relational database for an online store**.

Compared to the previous database project, this version introduces significantly more complex database logic, including **PL/SQL subprograms, cursors, packages, advanced triggers and automated business rules**.

The system models the internal operations of an e-commerce platform, managing customers, products, orders, suppliers, employees and invoices while ensuring strong **data integrity and automated stock management**.

---

# Database Model

The database simulates the behavior of a real online store where customers can purchase products supplied by multiple vendors, employees process orders and the system automatically manages stock and invoices.

## Main functionalities modeled in the database

- product catalog and category management  
- supplier and supply chain management  
- customer registration and order history  
- order processing and employee assignment  
- automatic invoice generation  
- inventory management and automatic stock updates  
- order validation and business rule enforcement  

---

# Database Design

The database follows a structured database design process similar to the previous project, but extended with advanced database mechanisms.


# Technologies Used

- **SQL (Oracle SQL dialect)**
- **PL/SQL**
- **Oracle Database 21c**
- Relational Database Design
- Entity–Relationship Modeling
- Data Normalization (1NF – 3NF)
- SQL Constraints
- Triggers
- Sequences
- Stored Procedures and Functions
- Packages and Collections
- Cursors

---

# Implemented Features

## Database Structure

- creation of relational tables with **primary and foreign keys**
- advanced integrity constraints (`NOT NULL`, `UNIQUE`, `CHECK`)
- associative tables for **many-to-many relationships**
- automatic key generation using **sequences**

Example:

```sql
CREATE SEQUENCE seq_clienti START WITH 1001 INCREMENT BY 1;
```

---

# Advanced Data Integrity

The database enforces complex business rules through triggers that validate:

- employee hiring dates  
- order placement validity  
- invoice generation constraints  
- supplier contract dates  

Example rule: preventing orders before a client registration date or invoices issued before the order date.

---

# Automatic Stock Management

Triggers automatically maintain product stock levels when:

- orders are created  
- order details are modified  
- orders are cancelled or reactivated  
- new products are supplied by vendors  

Example logic:

```sql
UPDATE PRODUSE
SET stoc = stoc - :NEW.cantitate
WHERE id_produs = v_id_produs;
```

This ensures inventory consistency without requiring manual updates.

---

# PL/SQL Subprograms

The project includes multiple **PL/SQL subprograms** implementing advanced database logic:

- stored procedures
- stored functions
- cursor-based processing
- nested cursors
- parameterized cursors

These subprograms solve complex database queries and automate business workflows.

---

# Exception Handling

PL/SQL subprograms handle multiple error cases using:

- predefined exceptions
- custom exceptions
- explicit error messages

Examples include:

- missing data
- invalid input values
- incorrect query results

---

# Triggers

The system implements several types of triggers:

- **row-level triggers** for data validation
- triggers that update stock automatically
- triggers that block modifications for delivered orders
- triggers that validate relationships between tables

These triggers ensure that database rules are enforced automatically.

---

# Packages and Complex Data Types

The database also implements **PL/SQL packages** containing:

- custom data types
- multiple procedures and functions
- encapsulated business logic

This allows complex workflows to be executed directly inside the database layer.

---

# Example Database Entities

- **CLIENTI** – customer information  
- **ANGAJATI** – employees responsible for order processing  
- **PRODUSE** – products sold by the store  
- **CATEGORII** – product categories  
- **FURNIZORI** – suppliers  
- **COMENZI** – customer orders  
- **FACTURI** – invoices issued for orders  
- **DETALII_COMANDA** – products contained in each order  
- **PRODUSE_FURNIZORI** – supplier-product relationships  
- **PROCESARE_COMENZI** – employees processing orders  

