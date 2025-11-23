Laboratorio 4 – Base de Datos
Programación Declarativa / Técnico de Programación

Estudiante: Karelyn Caicedo Vélez
Año: 2025

Descripción

Este repositorio contiene la solución al Examen / Laboratorio 4 del curso de Programación Declarativa, donde se trabaja con bases de datos en PostgreSQL bajo un enfoque declarativo.

El objetivo del laboratorio es aplicar:

Conceptos algorítmicos

Lógica declarativa

Uso de SQL

Validación e inserción de datos

Manejo de excepciones en PL/pgSQL

Contenido del repositorio
cambios.sql

Este archivo contiene todo el código necesario para:

Crear las tablas moneda y cambio
Insertar 4 monedas si no existen (USD, EUR, COP, MXN)
Generar automáticamente los cambios diarios de los últimos 2 meses
Validar si el cambio ya existe para actualizarlo
Insertar el cambio si no existe
Utilizar PL/pgSQL con manejo de excepciones
Mantener integridad y consistencia de datos

El script se ejecuta completamente en PostgreSQL.

Cómo ejecutar el script

Puedes correr cambios.sql de estas dos maneras:

1️. pgAdmin 4

Abrir pgAdmin

Crear o seleccionar una base de datos

Botón Query Tool

Copiar y pegar el contenido del archivo

Ejecutar

2️. Visual Studio Code (SQLTools)

Instalar extensiones:

SQLTools

SQLTools PostgreSQL Driver

Crear una conexión a PostgreSQL

Abrir cambios.sql

Ejecutarlo con Run Selected Query

Estado del proyecto

Finalizado y funcionando correctamente.