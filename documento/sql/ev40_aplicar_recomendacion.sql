-- 4. Aplicacion de la recomendacion INDICE SIN USO: idx_emp_email no lo usa ninguna de las
--    consultas de la carga de trabajo y solo agrega costo de escritura y 3 MB de espacio
DROP INDEX rrhh.idx_emp_email;
