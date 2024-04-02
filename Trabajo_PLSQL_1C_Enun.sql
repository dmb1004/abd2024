/*
  Nombre: Reservas festival
  Descripción: Se presenta el caso de uso de una empresa de eventos que organiza un festival de música y teatro
  Autor: Alvaro Marquez, David Martinez, Martin Gonzalez
  Fecha de Creación: 2024-03-26
*/
drop table clientes cascade constraints;
drop table abonos   cascade constraints;
drop table eventos  cascade constraints;
drop table reservas	cascade constraints;

drop sequence seq_abonos;
drop sequence seq_eventos;
drop sequence seq_reservas;


-- Creación de tablas y secuencias

create table clientes(
	NIF	varchar(9) primary key,
	nombre	varchar(20) not null,
	ape1	varchar(20) not null,
	ape2	varchar(20) not null
);

create sequence seq_abonos;

create table abonos(
	id_abono	integer primary key,
	cliente  	varchar(9) references clientes,
	saldo	    integer not null check (saldo>=0)
);

create sequence seq_eventos;

create table eventos(
	id_evento	integer  primary key,
	nombre_evento		varchar(20),
    fecha       date not null,
	asientos_disponibles	integer not null 
);

create sequence seq_reservas;

create table reservas(
	id_reserva	integer primary key,
	cliente  	varchar(9) references clientes,
  evento      integer references eventos,
	abono       integer references abonos,
	fecha	date not null
);

	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure reservar_evento( 
  arg_NIF_cliente varchar,
  arg_nombre_evento varchar, 
  arg_fecha date
) is

-- Excepcion Tarea 1
  evento_pasado EXCEPTION;
  PRAGMA EXCEPTION_INIT(evento_pasado, -20001);
  msg_evento_pasado CONSTANT VARCHAR2(100) := 'No se pueden reservar eventos pasados.';
-- Excepcion Tarea 2.2
  cliente_no_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(cliente_no_existe, -20002);
  msg_cliente_no_existe CONSTANT VARCHAR2(100) := 'Cliente inexistente.';
-- Excepcion Tarea 2.1
  evento_no_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(evento_no_existe, -20003);
  msg_evento_no_existe CONSTANT VARCHAR2(100) := 'El evento' ||  arg_nombre_evento || 'no existe';
  
-- Excepción Tarea 2.3
  saldo_insuficiente EXCEPTION;
  PRAGMA EXCEPTION_INIT(saldo_insuficiente, -20004);
  msg_saldo_insuficiente CONSTANT VARCHAR2(100) := 'Saldo en abono insuficiente';
-- Excepción extra añadida
  multiples_eventos EXCEPTION;
  PRAGMA EXCEPTION_INIT(multiples_eventos, -20005);
  msg_multiples_eventos CONSTANT VARCHAR2(100) := 'Hay más de un evento con ese nombre';
  
-- Excepción extra añadida
  sin_asientos EXCEPTION;
  PRAGMA EXCEPTION_INIT(sin_asientos, -20006);
  msg_sin_asientos CONSTANT VARCHAR2(100) := 'No hay asientos disponibles';
--Declaración de variables 
  v_evento_id eventos.id_evento%TYPE;
  v_fecha_evento eventos.fecha%TYPE;
  v_NIF clientes.NIF%TYPE;
  v_id_abono abonos.id_abono%TYPE;
  v_saldo abonos.saldo%TYPE;


begin
    begin
        -- Comprueba que el evento existe y no ha pasado
        select id_evento, fecha
        into v_evento_id, v_fecha_evento
        from eventos
        where nombre_evento = arg_nombre_evento;
        -- lanza excepcion si el evento ya ha pasado
        if v_fecha_evento < sysdate then
            raise_application_error(-20001, msg_evento_pasado);
        end if;
       -- lanza excepcion si hay mas de un evento con ese nombre
    exception 
        when no_data_found then
            rollback;
            raise_application_error(-20003, msg_evento_no_existe);
        when others then
            raise;
    end;
-- Comprueba que el cliente existe,Se realiza mediante un cursor implicito con la clausula for update para que el correcto funcionamiento no dependa del nivel de aislamiento. Es una estrategia intermedia ya que se utiliza un select para comprobar la existencia pero a su vez aprovecha la información para capturar la excepcion NO_DATA_FOUND.
  select clientes.NIF, abonos.id_abono, abonos.saldo
  into v_NIF, v_id_abono, v_saldo
  from clientes join abonos on clientes.NIF = abonos.cliente
  where clientes.NIF = arg_NIF_cliente
  for update;
-- Comprobamos que el cliente tiene saldo suficiente
  if v_saldo <= 0 then
    raise_application_error(-20004, msg_saldo_insuficiente);
  end if;
-- Actualizamos el saldo del abono
  UPDATE abonos SET saldo = saldo - 1 WHERE id_abono = v_id_abono;
-- Comprobamos que hay asientos disponibles
  UPDATE eventos
  SET asientos_disponibles = asientos_disponibles - 1
  WHERE id_evento = v_evento_id
  and asientos_disponibles > 0;
-- Si se ha actualizado una fila, se ha realizado la reserva, sino se lanza una excepcion por falta de asientos
  if sql%rowcount=1 then
    insert into reservas values (seq_reservas.nextval, arg_NIF_cliente, v_evento_id, v_id_abono, arg_fecha);
    commit;
  else
    rollback;
    raise_application_error(-20006, msg_sin_asientos);
  end if;

  commit;
-- Captura de excepciones y rollback
exception
  when NO_DATA_FOUND then
    rollback;
    raise_application_error(-20002, msg_cliente_no_existe);
  when TOO_MANY_ROWS then
    raise_application_error(-20005, msg_multiples_eventos);
  when others then
    raise;
end;
/

  
------ Deja aquí tus respuestas a las preguntas del enunciado:
-- * P4.1  El resultado de la comprobación del paso 2 ¿sigue siendo fiable en el paso 3?:
--
-- No sigue siendo fiable en el paso 3, ya que en el paso 3 se puede haber modificado el estado de la base de datos.
-- siendo posible que el evento ya no exista o el evento ya haya pasado debido a que otra sesion haya modificado el estado de estos valores de la base de datos simultaneamente.
--
-- * P4.2 2 En el paso 3, la ejecución concurrente del mismo procedimiento reservar_evento con, quizás
-- otros o los mimos argumentos, ¿podría habernos añadido una reserva no recogida en esa SELECT
-- que fuese incompatible con nuestra reserva?, ¿por qué?:
--
-- Una sesion concurrente no puede añadir una nueva reserva que afecte al select ya que hemos utililzado una estrategia pesismista con el uso de la clausula FOR UPDATE en la consulta, lo que bloquea la fila seleccionada hasta que se realice un commit o un rollback. Aunque no afecta a los datos recogigos por la SELECT, si que puede darse el caso de que otra sesion concurrente haya hecho una reserva en el mismo evento y haya agotado los asientos disponibles, lo que provocaria que la reserva actual falle por falta de asientos disponibles. Aunque este error se pueda producir en reducidas ocasiones, hemos ganado eficiencia al no tener que bloquear la tabla eventos para evitar que se realicen reservas en el mismo evento simultaneamente.
--
-- * P4.3 ¿Qué estrategia de programación has utilizado?
-- 
-- Se ha utilizado una estrategia defensiva en la que se comprueban los datos antes de realizar la reserva, sin embargo, manteniendo la linea defensiva hemos implementado tambien caracteristicas tipicas de las estrategias agresivas.
--
-- * P4.4 ¿Cómo puede verse este hecho en tu código?
--
-- Como hemos dicho anteriormente, para utilizar una estrategia defensiva pero con caracteristicas agresivas hemos utilizado lo siguiente: Por ejemplo a la hora de utilizar la informacion dada por las excepciones como NO_DATA_FOUND o TOO_MANY_ROWS para ahorrar consultas. Tambien se ha utlizado para evitar un select, un update + condicion, para comprobar que hay asientos disponibles. La implementación sigue siendo defensiva, pero la comprobación de si se puede hacer el UPDATE se traslada al propio UPDATE.
--
-- * P4.5  ¿De qué otro modo crees que podrías resolver el problema propuesto? Incluye el
-- pseudocódigo.
-- 
-- 
--


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';
end;
/


create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_abonos' );
  reset_seq( 'seq_eventos' );
  reset_seq( 'seq_reservas' );
        
  
    delete from reservas;
    delete from eventos;
    delete from abonos;
    delete from clientes;
    
       
		
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez');
    
    insert into abonos values (seq_abonos.nextval, '12345678A',10);
    insert into abonos values (seq_abonos.nextval, '11111111B',0);
    
    insert into eventos values ( seq_eventos.nextval, 'concierto_la_moda', date '2023-6-27', 200);
    insert into eventos values ( seq_eventos.nextval, 'teatro_impro', date '2023-7-1', 50);
    insert into eventos values ( seq_eventos.nextval, 'concierto_bisbal', date '2024-12-12', 50);
    insert into eventos values ( seq_eventos.nextval, 'concierto_m_escobar', date '2024-01-01', 10);
    insert into eventos values ( seq_eventos.nextval, 'concierto_chichos', date '2024-10-10', 100);

    commit;
end;
/

exec inicializa_test;

-- Completa el test

create or replace procedure test_reserva_evento is
    l_error_msg VARCHAR2(4000);
begin
	 
  --caso 1 Reserva correcta, se realiza
  begin
    inicializa_test;
    reservar_evento('12345678A', 'concierto_bisbal', TO_DATE('12/12/2024', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 1: Reserva correcta completada.');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 1: Fallo en la reserva correcta - ' || l_error_msg);
  end;
  
  --caso 2 Evento pasado
  begin
    inicializa_test;
    reservar_evento('12345678A', 'concierto_la_moda', TO_DATE('27/06/2023', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 2: La reserva de un evento pasado no debería ser posible.');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 2: Excepción esperada - ' || l_error_msg);
  end;
  
  --caso 3 Evento inexistente
  begin
    inicializa_test;
    reservar_evento('12345678A', 'concierto_cali_yeldandy', TO_DATE('27/06/2023', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 3: La reserva de un evento inexistente no debería ser posible.');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 3: Excepción esperada - ' || l_error_msg);
  end;

   --caso 4 Cliente inexistente  
  begin
    inicializa_test;
    reservar_evento('11111111C', 'concierto_bisbal', TO_DATE('12/12/2024', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 4: El cliente no debería existir');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 4: Excepción esperada - ' || l_error_msg);
  end;
  
  --caso 5 El cliente no tiene saldo suficiente
  begin
    inicializa_test;
    reservar_evento('11111111B', 'concierto_bisbal', TO_DATE('12/12/2024', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 5: El cliente no debería tener suficiente saldo');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 5: Excepción esperada - ' || l_error_msg);
  end;
  
   --caso extra El evento no tiene asientos disponibles
  begin
    inicializa_test;
    reservar_evento('12345678A', 'concierto_chichos', TO_DATE('12/12/2024', 'DD/MM/YYYY'));
    dbms_output.put_line('Caso 6: El cliente no podría reservar un concierto sin asientos');
  exception
    when others then
      l_error_msg := SQLERRM;
      dbms_output.put_line('Caso 6: Excepción esperada - ' || l_error_msg);
  end;

  
end;
/


set serveroutput on;
exec test_reserva_evento;