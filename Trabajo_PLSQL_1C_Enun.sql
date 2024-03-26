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
	asientos_disponibles	integer  not null
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

  evento_pasado EXCEPTION;
  PRAGMA EXCEPTION_INIT(evento_pasado, -20001);
  msg_evento_pasado CONSTANT VARCHAR2(100) := "No se pueden reservar eventos pasados.";

  evento_no_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(evento_no_existe, -20003);
  msg_evento_no_existe CONSTANT VARCHAR2(100) := "El evento" ||  arg_nombre_evento || "no existe";

  multiples_eventos EXCEPTION;
  PRAGMA EXCEPTION_INIT(multiples_eventos, -20002);
  msg_multiples_eventos CONSTANT VARCHAR2(100) := "Hay más de un evento con ese nombre";

  v_evento_id eventos.id_evento%TYPE;
  v_fecha_evento eventos.fecha%TYPE;


begin

  select id_evento, fecha
  into v_evento_id, v_fecha_evento
  from eventos
  where nombre_evento = arg_nombre_evento;

  if v_fecha_evento < sysdate then
    raise_application_error(-20001, msg_evento_pasado);
  end if;

  select clientes.NIF, abonos.id_abono, abonos.saldo
  into v_NIF, v_id_abono, v_saldo
  from clientes join abonos on clientes.NIF = abonos.cliente
  where clientes.NIF = arg_NIF_cliente;
  for update;

  if v_saldo <= 0 then
    raise_application_error(-20004, msg_saldo_insuficiente);
  end if;

  insert into reservas values (seq_reservas.nextval, arg_NIF_cliente, v_evento_id, v_id_abono, arg_fecha);

  commit;

exception
  when NO_DATA_FOUND then
    raise_application_error(-20003, msg_evento_no_existe);
  when TOO_MANY_ROWS then
    raise_application_error(-20002, msg_multiples_eventos);
  when others then
    raise;
end;
/

  
/*
exception
  when NO_DATA_FOUND then
    if sqlcode = -20002 then
        raise_application_error(-20002, 'Cliente inexistente.');
    else
        raise_application_error(-20003, 'El evento ' || arg_nombre_evento || ' no existe');
    end if;
  when TOO_MANY_ROWS then
    raise_application_error(-20003, 'Error de datos: múltiples eventos con el mismo nombre.');
end;
/
*/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- * P4.1
--
-- * P4.2
--
-- * P4.3
--
-- * P4.4
--
-- * P4.5
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

    commit;
end;
/

exec inicializa_test;

-- Completa el test

create or replace procedure test_reserva_evento is
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
    dbms_output.put_line('Caso 3: La reserva de un evento pasado no debería ser posible.');
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
  end;

  
  --caso 5 El cliente no tiene saldo suficiente
  begin
    inicializa_test;
  end;

  
end;
/


set serveroutput on;
exec test_reserva_evento;